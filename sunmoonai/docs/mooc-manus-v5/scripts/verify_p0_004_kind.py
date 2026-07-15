#!/usr/bin/env python3
"""Repeatable KIND compatibility matrix for V5-P0-004.

The verifier exercises the committed Research KnowledgePort against the real
Knowledge API and RAGFlow, then temporarily replaces only the Knowledge
provider transport with an in-cluster protocol double for timeout, unmapped
chunk and token-budget cases.  It never prints query/evidence text, provider
IDs, access tokens, client secrets or signing material.  All explicit
Deployment overrides and the provider double are removed in ``finally``.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any


class VerificationError(RuntimeError):
    pass


def kubectl(
    args: list[str],
    *,
    kubeconfig: str,
    capture: bool = False,
    input_text: str | None = None,
) -> str:
    result = subprocess.run(
        ["kubectl", "--kubeconfig", kubeconfig, *args],
        input=input_text,
        check=True,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
        timeout=240,
    )
    return result.stdout if capture else ""


def deployment_marker(
    *,
    kubeconfig: str,
    namespace: str,
    deployment: str,
    program: str,
    args: list[str],
    marker: str,
    label: str,
) -> Any:
    result = subprocess.run(
        [
            "kubectl",
            "--kubeconfig",
            kubeconfig,
            "exec",
            "-n",
            namespace,
            f"deploy/{deployment}",
            "--",
            ".venv/bin/python",
            "-c",
            program,
            *args,
        ],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=180,
    )
    if result.returncode != 0:
        raise VerificationError(f"{label} exited {result.returncode}")
    prefix = f"{marker}="
    for line in result.stdout.splitlines():
        if line.startswith(prefix):
            return json.loads(line.removeprefix(prefix))
    raise VerificationError(f"{label} did not emit its safe marker")


def verify_contract_lock(contract_dir: Path, lock_path: Path) -> dict[str, str]:
    import hashlib

    manifest = json.loads((contract_dir / "contract-manifest.json").read_text())
    lock = json.loads(lock_path.read_text())
    if manifest.get("major") != 1 or lock.get("major") != 1:
        raise VerificationError("retrieval contract major is not v1")
    files = manifest.get("files")
    locked_schemas = lock.get("schemas")
    if not isinstance(files, dict) or not isinstance(locked_schemas, dict):
        raise VerificationError("retrieval contract manifest or Research lock is invalid")
    if any(files.get(name) != digest for name, digest in locked_schemas.items()):
        raise VerificationError("Research provider lock differs from Knowledge manifest")
    if set(locked_schemas) != {
        "knowledge-retrieval-request.schema.json",
        "knowledge-retrieval-response.schema.json",
        "citation.schema.json",
    }:
        raise VerificationError("Research provider lock does not pin all v1 schemas")
    for relative, expected in files.items():
        actual = hashlib.sha256((contract_dir / relative).read_bytes()).hexdigest()
        if actual != expected:
            raise VerificationError(f"contract digest mismatch: {relative}")
    return {str(name): str(digest) for name, digest in files.items()}


def assert_no_managed_overrides(*, kubeconfig: str, namespace: str) -> None:
    raw = kubectl(
        [
            "get",
            "deployment/knowledge-admin-backend",
            "-n",
            namespace,
            "-o",
            "json",
        ],
        kubeconfig=kubeconfig,
        capture=True,
    )
    deployment = json.loads(raw)
    env = deployment["spec"]["template"]["spec"]["containers"][0].get("env", [])
    managed = {
        "RAGFLOW_API_BASE",
        "RETRIEVAL_DATASET_ALLOWLIST",
        "RETRIEVAL_PROVIDER_TIMEOUT_SECONDS",
    }
    conflicts = sorted(
        item.get("name") for item in env if item.get("name") in managed
    )
    if conflicts:
        raise VerificationError(
            "refusing to overwrite explicit Knowledge env: " + ", ".join(conflicts)
        )


def set_knowledge_env(
    *, kubeconfig: str, namespace: str, assignments: list[str]
) -> None:
    kubectl(
        [
            "set",
            "env",
            "deployment/knowledge-admin-backend",
            "-n",
            namespace,
            *assignments,
        ],
        kubeconfig=kubeconfig,
    )
    kubectl(
        [
            "rollout",
            "status",
            "deployment/knowledge-admin-backend",
            "-n",
            namespace,
            "--timeout=180s",
        ],
        kubeconfig=kubeconfig,
    )


def remove_knowledge_overrides(*, kubeconfig: str, namespace: str) -> None:
    set_knowledge_env(
        kubeconfig=kubeconfig,
        namespace=namespace,
        assignments=[
            "RAGFLOW_API_BASE-",
            "RETRIEVAL_DATASET_ALLOWLIST-",
            "RETRIEVAL_PROVIDER_TIMEOUT_SECONDS-",
        ],
    )


def assert_candidate_images(
    *,
    kubeconfig: str,
    namespace: str,
    knowledge_image: str,
    research_image: str,
) -> dict[str, str]:
    expected = {
        "knowledge-admin-backend": knowledge_image,
        "celeryworker-research-admin-backend": research_image,
    }
    image_ids: dict[str, str] = {}
    for deployment, expected_image in expected.items():
        raw = kubectl(
            ["get", f"deployment/{deployment}", "-n", namespace, "-o", "json"],
            kubeconfig=kubeconfig,
            capture=True,
        )
        item = json.loads(raw)
        actual = item["spec"]["template"]["spec"]["containers"][0]["image"]
        if actual != expected_image:
            raise VerificationError(
                f"{deployment} image mismatch: expected {expected_image}, got {actual}"
            )
        pods = json.loads(
            kubectl(
                ["get", "pods", "-n", namespace, "-l", f"app={deployment}", "-o", "json"],
                kubeconfig=kubeconfig,
                capture=True,
            )
        ).get("items", [])
        ready = [
            pod
            for pod in pods
            if pod.get("status", {}).get("phase") == "Running"
            and pod.get("status", {}).get("containerStatuses")
            and pod["status"]["containerStatuses"][0].get("ready") is True
        ]
        if len(ready) != 1:
            raise VerificationError(
                f"expected one ready {deployment} pod, got {len(ready)}"
            )
        image_id = ready[0]["status"]["containerStatuses"][0].get("imageID")
        if not isinstance(image_id, str) or "@sha256:" not in image_id:
            raise VerificationError(f"{deployment} has no pulled digest")
        image_ids[deployment] = image_id
    return image_ids


def verify_workload_binding(*, kubeconfig: str, namespace: str) -> dict[str, bool]:
    raw = kubectl(
        [
            "get",
            "deployment/research-admin-backend",
            "deployment/celeryworker-research-admin-backend",
            "deployment/knowledge-admin-backend",
            "deployment/celeryworker-info-admin-backend",
            "-n",
            namespace,
            "-o",
            "json",
        ],
        kubeconfig=kubeconfig,
        capture=True,
    )
    items = {item["metadata"]["name"]: item for item in json.loads(raw)["items"]}

    def spec(name: str) -> dict[str, Any]:
        return items[name]["spec"]["template"]["spec"]

    def secrets(name: str) -> set[str]:
        return {
            item["secretRef"]["name"]
            for item in spec(name)["containers"][0].get("envFrom", [])
            if "secretRef" in item
        }

    research_worker = spec("celeryworker-research-admin-backend")
    checks = {
        "caller_secret_only_on_research_worker": (
            "research-knowledge-retrieval-client"
            in secrets("celeryworker-research-admin-backend")
            and "research-knowledge-retrieval-client"
            not in secrets("research-admin-backend")
            and "research-knowledge-retrieval-client"
            not in secrets("celeryworker-info-admin-backend")
        ),
        "resource_binding_only_on_knowledge_api": (
            "knowledge-research-retrieval-service-binding"
            in secrets("knowledge-admin-backend")
        ),
        "dedicated_service_account": (
            research_worker.get("serviceAccountName")
            == "research-knowledge-retrieval-worker"
        ),
        "service_account_token_not_mounted": (
            research_worker.get("automountServiceAccountToken") is False
        ),
    }
    if not all(checks.values()):
        raise VerificationError("retrieval workload binding violates the contract")

    secret_json = kubectl(
        [
            "get",
            "secret/research-knowledge-retrieval-client",
            "secret/info-knowledge-ingest-client",
            "-n",
            namespace,
            "-o",
            "json",
        ],
        kubeconfig=kubeconfig,
        capture=True,
    )
    secret_items = {item["metadata"]["name"]: item for item in json.loads(secret_json)["items"]}
    retrieve = secret_items["research-knowledge-retrieval-client"]["data"]
    ingest = secret_items["info-knowledge-ingest-client"]["data"]
    checks["independent_client_id"] = (
        retrieve.get("KNOWLEDGE_RETRIEVAL_SERVICE_CLIENT_ID")
        != ingest.get("KNOWLEDGE_APP_SERVICE_CLIENT_ID")
    )
    checks["independent_client_secret"] = (
        retrieve.get("KNOWLEDGE_RETRIEVAL_SERVICE_CLIENT_SECRET")
        != ingest.get("KNOWLEDGE_APP_SERVICE_CLIENT_SECRET")
    )
    if not checks["independent_client_id"] or not checks["independent_client_secret"]:
        raise VerificationError("ingestion and retrieval credentials are not independent")
    return checks


_READ_KNOWLEDGE_STATE = r"""
import asyncio
import json

from sqlalchemy import func, select, text

from app.infrastructure.models.knowledge import (
    KnowledgeDocument,
    KnowledgeDocumentVersion,
    KnowledgeIngestionJob,
)
from app.infrastructure.storage.postgres import get_postgres

async def main():
    postgres = get_postgres()
    await postgres.init()
    try:
        async with postgres.session_factory() as session:
            version = (await session.execute(
                select(KnowledgeDocumentVersion)
                .where(KnowledgeDocumentVersion.status == "indexed")
                .order_by(KnowledgeDocumentVersion.indexed_at.desc())
                .limit(1)
            )).scalar_one_or_none()
            indexed = int((await session.scalar(
                select(func.count(KnowledgeDocumentVersion.id)).where(
                    KnowledgeDocumentVersion.status == "indexed"
                )
            )) or 0)
            legacy = int((await session.scalar(
                select(func.count(KnowledgeIngestionJob.id)).where(
                    KnowledgeIngestionJob.status == "legacy_binding_missing"
                )
            )) or 0)
            head = await session.scalar(text("SELECT version_num FROM alembic_version"))
            if version is None:
                raise RuntimeError("no indexed Knowledge version exists")
            document = await session.get(KnowledgeDocument, version.knowledge_document_id)
            if document is None:
                raise RuntimeError("Knowledge document is missing")
            result = {
                "alembic_head": str(head),
                "indexed_count": indexed,
                "legacy_binding_missing_count": legacy,
                "dataset_key": version.dataset_key,
                "query_hint": version.title or "RAGFlow embedding smoke",
                "knowledge_document_id": str(version.knowledge_document_id),
                "knowledge_document_version_id": str(version.id),
                "source_document_id": str(version.source_document_id),
                "source_document_version_id": str(version.source_document_version_id),
                "content_hash": version.content_hash,
                "stable_identity": (
                    document.source_document_id == version.source_document_id
                    and document.dataset_key == version.dataset_key
                    and len(str(version.id)) == 36
                ),
            }
            print("P0_KNOWLEDGE_STATE=" + json.dumps(result, sort_keys=True))
    finally:
        await postgres.shutdown()

asyncio.run(main())
"""


def read_knowledge_state(*, kubeconfig: str, namespace: str) -> dict[str, Any]:
    state = deployment_marker(
        kubeconfig=kubeconfig,
        namespace=namespace,
        deployment="knowledge-admin-backend",
        program=_READ_KNOWLEDGE_STATE,
        args=[],
        marker="P0_KNOWLEDGE_STATE",
        label="Knowledge migration and lineage reader",
    )
    if state.get("alembic_head") != "20260715_0003":
        raise VerificationError(f"unexpected Knowledge migration head: {state.get('alembic_head')}")
    if not state.get("stable_identity") or state.get("indexed_count", 0) < 1:
        raise VerificationError("stable Knowledge identity was not backfilled")
    return state


_RESEARCH_MATRIX = r"""
import asyncio
import json
import sys
import uuid

import httpx

from app.domain.agent.knowledge import (
    Citation,
    KnowledgeFilters,
    KnowledgeQuery,
    RetrievalSecurityContext,
)
from app.infrastructure.external.knowledge_retrieval import (
    KnowledgeRetrievalAuthorizationError,
    KnowledgeRetrievalUnavailableError,
    get_knowledge_retrieval_client,
)
from core.config import get_settings

async def main():
    mode, dataset_key, query_hint = sys.argv[1:4]
    filters = KnowledgeFilters()
    if mode == "empty":
        filters = KnowledgeFilters(source_document_version_ids=[uuid.uuid4()])
    query = KnowledgeQuery(
        request_id=uuid.uuid4(),
        query=query_hint,
        dataset_keys=["p0-unknown-dataset"] if mode == "unknown" else [dataset_key],
        filters=filters,
        top_k=5,
        token_budget=1 if mode == "budget" else 4000,
        security_context=RetrievalSecurityContext(
            tenant_id="sunmoonai",
            actor_id=uuid.uuid4(),
            actor_type="service",
            policy_version="p0-004",
        ),
    )
    client = get_knowledge_retrieval_client()
    if mode == "identity":
        provider = client._token_provider
        if provider is None or not client._retrieval_url:
            raise RuntimeError("retrieval relation is not configured")
        token = await provider.get_token()
        retrieval_url = client._retrieval_url
        ingestion_url = retrieval_url.rsplit("/", 1)[0] + "/ingestions"
        async with httpx.AsyncClient(timeout=15) as http:
            valid = await http.post(
                retrieval_url,
                json={},
                headers={"Authorization": f"Bearer {token}"},
            )
            cross = await http.post(
                ingestion_url,
                json={},
                headers={"Authorization": f"Bearer {token}"},
            )
            anonymous = await http.post(retrieval_url, json={})
        if (valid.status_code, cross.status_code, anonymous.status_code) != (422, 401, 401):
            raise RuntimeError("service identity boundary returned unexpected statuses")
        result = {
            "valid_retrieval_control": valid.status_code,
            "retrieval_token_on_ingestion": cross.status_code,
            "anonymous_retrieval": anonymous.status_code,
            "token_printed": False,
        }
    elif mode == "unknown":
        try:
            await client.retrieve(query)
        except KnowledgeRetrievalAuthorizationError:
            result = {"unknown_dataset": 403}
        else:
            raise RuntimeError("unknown dataset was not denied")
    elif mode == "timeout":
        try:
            await client.retrieve(query)
        except KnowledgeRetrievalUnavailableError as exc:
            if "HTTP 504" not in str(exc):
                raise RuntimeError("provider timeout did not preserve the 504 class") from None
            result = {"provider_timeout": 504}
        else:
            raise RuntimeError("provider timeout unexpectedly succeeded")
    else:
        response = await client.retrieve(query)
        if mode == "real":
            if not response.evidence:
                raise RuntimeError("real RAGFlow retrieval returned no governed evidence")
            evidence = response.evidence[0]
            citation = Citation.from_evidence(evidence)
            raw = citation.model_dump(mode="json")
            if {"source_uri", "provider_metadata"}.intersection(raw):
                raise RuntimeError("citation leaked provider evidence fields")
            if "ragflow" in json.dumps(raw).lower():
                raise RuntimeError("citation leaked provider identity")
            result = {
                "evidence_count": len(response.evidence),
                "evidence_id": str(evidence.evidence_id),
                "knowledge_document_id": str(evidence.knowledge_document_id),
                "knowledge_document_version_id": str(evidence.knowledge_document_version_id),
                "source_document_id": str(evidence.source_document_id),
                "source_document_version_id": str(evidence.source_document_version_id),
                "content_hash": evidence.content_hash,
                "citation_source_href": citation.source_href,
                "citation_provider_fields_absent": True,
                "content_printed": False,
            }
        elif mode == "empty":
            if response.evidence or response.total_candidates != 0:
                raise RuntimeError("filtered empty retrieval was not empty")
            result = {"empty_result": True}
        elif mode == "unmapped":
            if response.evidence or response.total_candidates != 0:
                raise RuntimeError("unmapped provider chunk was not discarded")
            result = {"unmapped_chunk_dropped": True}
        elif mode == "budget":
            if len(response.evidence) != 1:
                raise RuntimeError("budget control did not return one mapped evidence item")
            evidence = response.evidence[0]
            if evidence.token_estimate != 1 or len(evidence.content) != 1:
                raise RuntimeError("token budget was not enforced")
            if not evidence.truncated or not response.truncated:
                raise RuntimeError("token budget truncation was not marked")
            result = {
                "token_budget": 1,
                "token_estimate": evidence.token_estimate,
                "truncated": True,
                "content_printed": False,
            }
        else:
            raise RuntimeError("unsupported matrix mode")
    print("P0_RESEARCH_RESULT=" + json.dumps(result, sort_keys=True))

asyncio.run(main())
"""


def research_case(
    *,
    kubeconfig: str,
    namespace: str,
    mode: str,
    dataset_key: str,
    query_hint: str,
) -> dict[str, Any]:
    return deployment_marker(
        kubeconfig=kubeconfig,
        namespace=namespace,
        deployment="celeryworker-research-admin-backend",
        program=_RESEARCH_MATRIX,
        args=[mode, dataset_key, query_hint],
        marker="P0_RESEARCH_RESULT",
        label=f"Research KnowledgePort {mode} case",
    )


_INFO_CROSS_RELATION = r"""
import asyncio
import json

import httpx

from app.infrastructure.external.knowledge_app import get_knowledge_app_client

async def main():
    client = get_knowledge_app_client()
    if client.token_provider is None or not client.ingest_url:
        raise RuntimeError("ingestion relation is not configured")
    token = await client.token_provider.get_token()
    retrieval_url = client.ingest_url.rsplit("/", 1)[0] + "/retrievals"
    async with httpx.AsyncClient(timeout=15) as http:
        response = await http.post(
            retrieval_url,
            json={},
            headers={"Authorization": f"Bearer {token}"},
        )
    if response.status_code != 401:
        raise RuntimeError("ingestion credential crossed into retrieval relation")
    print("P0_INFO_CROSS=" + json.dumps({
        "ingestion_token_on_retrieval": response.status_code,
        "token_printed": False,
    }, sort_keys=True))

asyncio.run(main())
"""


def verify_info_cross_relation(*, kubeconfig: str, namespace: str) -> dict[str, Any]:
    return deployment_marker(
        kubeconfig=kubeconfig,
        namespace=namespace,
        deployment="celeryworker-info-admin-backend",
        program=_INFO_CROSS_RELATION,
        args=[],
        marker="P0_INFO_CROSS",
        label="Info ingestion credential cross-relation denial",
    )


_VERIFY_LINEAGE = r"""
import asyncio
import json
import sys
import uuid

from app.infrastructure.models.knowledge import KnowledgeDocumentVersion
from app.infrastructure.storage.postgres import get_postgres

async def main():
    version_id = uuid.UUID(sys.argv[1])
    expected = sys.argv[2:7]
    postgres = get_postgres()
    await postgres.init()
    try:
        async with postgres.session_factory() as session:
            version = await session.get(KnowledgeDocumentVersion, version_id)
            if version is None:
                raise RuntimeError("citation Knowledge version does not exist")
            actual = [
                str(version.knowledge_document_id),
                str(version.source_document_id),
                str(version.source_document_version_id),
                version.content_hash,
                version.status,
            ]
            if actual != expected:
                raise RuntimeError("citation lineage differs from Knowledge source of truth")
            print("P0_LINEAGE=" + json.dumps({
                "citation_to_knowledge_version": True,
                "knowledge_version_to_info_version": True,
                "provider_ids_printed": False,
            }, sort_keys=True))
    finally:
        await postgres.shutdown()

asyncio.run(main())
"""


def verify_lineage(
    *, kubeconfig: str, namespace: str, retrieval: dict[str, Any]
) -> dict[str, Any]:
    return deployment_marker(
        kubeconfig=kubeconfig,
        namespace=namespace,
        deployment="knowledge-admin-backend",
        program=_VERIFY_LINEAGE,
        args=[
            retrieval["knowledge_document_version_id"],
            retrieval["knowledge_document_id"],
            retrieval["source_document_id"],
            retrieval["source_document_version_id"],
            retrieval["content_hash"],
            "indexed",
        ],
        marker="P0_LINEAGE",
        label="citation lineage verifier",
    )


_PROVIDER_DOUBLE = r"""
import json
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        return

    def do_GET(self):
        body = b"ok"
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        request = json.loads(self.rfile.read(length) or b"{}")
        question = request.get("question")
        if question == "p0-timeout":
            time.sleep(10)
        datasets = request.get("dataset_ids") or ["missing"]
        documents = request.get("document_ids") or ["missing"]
        chunks = []
        if question == "p0-unmapped":
            chunks = [{
                "id": "private-unmapped-chunk",
                "dataset_id": "wrong-dataset-binding",
                "document_id": documents[0],
                "content": "must never surface",
                "similarity": 1.0,
            }]
        elif question == "p0-budget":
            chunks = [{
                "id": "private-budget-chunk",
                "dataset_id": datasets[0],
                "document_id": documents[0],
                "content": "abcdefghijklmnopqrstuvwxyz",
                "similarity": 0.9,
            }]
        payload = json.dumps({
            "code": 0,
            "data": {"chunks": chunks, "total": len(chunks)},
        }).encode()
        try:
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        except BrokenPipeError:
            pass

ThreadingHTTPServer(("0.0.0.0", 8000), Handler).serve_forever()
"""


def provider_double_yaml(*, namespace: str, image: str) -> str:
    encoded = base64.b64encode(_PROVIDER_DOUBLE.encode()).decode()
    return f"""apiVersion: apps/v1
kind: Deployment
metadata:
  name: p0-004-provider-double
  namespace: {namespace}
  labels:
    sunmoonai.com/task: v5-p0-004
spec:
  replicas: 1
  selector:
    matchLabels:
      app: p0-004-provider-double
  template:
    metadata:
      labels:
        app: p0-004-provider-double
        sunmoonai.com/task: v5-p0-004
    spec:
      automountServiceAccountToken: false
      imagePullSecrets:
      - name: harbor-registry-secret
      containers:
      - name: provider-double
        image: {image}
        imagePullPolicy: Always
        command: ["/bin/sh", "-ec"]
        args:
        - exec .venv/bin/python -c 'import base64, os; exec(base64.b64decode(os.environ["P0_PROGRAM"]))'
        env:
        - name: P0_PROGRAM
          value: {json.dumps(encoded)}
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 1
          periodSeconds: 1
---
apiVersion: v1
kind: Service
metadata:
  name: p0-004-provider-double
  namespace: {namespace}
spec:
  selector:
    app: p0-004-provider-double
  ports:
  - port: 8000
    targetPort: 8000
"""


def create_provider_double(
    *, kubeconfig: str, namespace: str, image: str
) -> None:
    kubectl(
        ["apply", "-f", "-"],
        kubeconfig=kubeconfig,
        input_text=provider_double_yaml(namespace=namespace, image=image),
    )
    kubectl(
        [
            "rollout",
            "status",
            "deployment/p0-004-provider-double",
            "-n",
            namespace,
            "--timeout=180s",
        ],
        kubeconfig=kubeconfig,
    )


def delete_provider_double(*, kubeconfig: str, namespace: str) -> None:
    kubectl(
        [
            "delete",
            "deployment/p0-004-provider-double",
            "service/p0-004-provider-double",
            "-n",
            namespace,
            "--ignore-not-found=true",
            "--wait=false",
        ],
        kubeconfig=kubeconfig,
    )


def run_negative_matrix(
    *, kubeconfig: str, namespace: str, knowledge_image: str
) -> None:
    script = Path(__file__).with_name("verify_p0_005_service_negative_matrix.sh")
    subprocess.run(
        [
            "bash",
            str(script),
            "--run",
            "--relation",
            "retrieve",
            "--kubeconfig",
            kubeconfig,
            "--namespace",
            namespace,
            "--probe-image",
            knowledge_image,
        ],
        check=True,
        timeout=240,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--knowledge-image", required=True)
    parser.add_argument("--research-image", required=True)
    parser.add_argument(
        "--kubeconfig",
        default=os.environ.get("KUBECONFIG", str(Path.home() / ".kube/kind-config")),
    )
    parser.add_argument("--namespace", default="app-platform-dev")
    parser.add_argument(
        "--knowledge-contract-dir",
        default="/home/zymun/knowledge-app/contracts/retrieval/v1",
    )
    parser.add_argument(
        "--research-contract-lock",
        default="/home/zymun/research-app/contracts/knowledge-retrieval-provider-lock.json",
    )
    args = parser.parse_args()

    kubeconfig = str(Path(args.kubeconfig).expanduser())
    overrides_active = False
    provider_active = False
    summary: dict[str, Any] = {"task": "V5-P0-004", "result": "failed"}
    try:
        digests = verify_contract_lock(
            Path(args.knowledge_contract_dir), Path(args.research_contract_lock)
        )
        assert_no_managed_overrides(kubeconfig=kubeconfig, namespace=args.namespace)
        image_ids = assert_candidate_images(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            knowledge_image=args.knowledge_image,
            research_image=args.research_image,
        )
        workload = verify_workload_binding(
            kubeconfig=kubeconfig, namespace=args.namespace
        )
        state = read_knowledge_state(kubeconfig=kubeconfig, namespace=args.namespace)
        dataset_key = str(state["dataset_key"])
        query_hint = str(state["query_hint"])

        overrides_active = True
        set_knowledge_env(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            assignments=[f"RETRIEVAL_DATASET_ALLOWLIST={dataset_key}"],
        )

        identity = research_case(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            mode="identity",
            dataset_key=dataset_key,
            query_hint="identity-control",
        )
        info_cross = verify_info_cross_relation(
            kubeconfig=kubeconfig, namespace=args.namespace
        )
        unknown = research_case(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            mode="unknown",
            dataset_key=dataset_key,
            query_hint="unknown-dataset-control",
        )
        empty = research_case(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            mode="empty",
            dataset_key=dataset_key,
            query_hint=query_hint,
        )
        real = research_case(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            mode="real",
            dataset_key=dataset_key,
            query_hint=query_hint,
        )
        lineage = verify_lineage(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            retrieval=real,
        )

        run_negative_matrix(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            knowledge_image=args.knowledge_image,
        )

        provider_active = True
        create_provider_double(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            image=args.knowledge_image,
        )
        set_knowledge_env(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            assignments=[
                "RAGFLOW_API_BASE=http://p0-004-provider-double:8000/api/v1",
                "RETRIEVAL_PROVIDER_TIMEOUT_SECONDS=1",
            ],
        )
        unmapped = research_case(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            mode="unmapped",
            dataset_key=dataset_key,
            query_hint="p0-unmapped",
        )
        budget = research_case(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            mode="budget",
            dataset_key=dataset_key,
            query_hint="p0-budget",
        )
        timeout = research_case(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            mode="timeout",
            dataset_key=dataset_key,
            query_hint="p0-timeout",
        )

        summary = {
            "task": "V5-P0-004",
            "result": "passed",
            "contract_major": 1,
            "contract_digests": digests,
            "candidate_image_ids": image_ids,
            "migration": {
                "alembic_head": state["alembic_head"],
                "indexed_count": state["indexed_count"],
                "legacy_binding_missing_count": state["legacy_binding_missing_count"],
                "stable_identity": state["stable_identity"],
            },
            "workload_binding": workload,
            "identity": {**identity, **info_cross, "negative_matrix": "passed"},
            "retrieval": {
                "dataset_key": dataset_key,
                "real_evidence_count": real["evidence_count"],
                "unknown_dataset": unknown["unknown_dataset"],
                "empty_result": empty["empty_result"],
                "unmapped_chunk_dropped": unmapped["unmapped_chunk_dropped"],
                "provider_timeout": timeout["provider_timeout"],
                "token_budget": budget,
            },
            "citation": {
                "source_href_relative": real["citation_source_href"].startswith(
                    "/api/citations/"
                ),
                "provider_fields_absent": real["citation_provider_fields_absent"],
                **lineage,
            },
            "sensitive_values_printed": False,
        }
        print(json.dumps(summary, ensure_ascii=False, indent=2))
        return 0
    except (
        VerificationError,
        subprocess.CalledProcessError,
        subprocess.TimeoutExpired,
        OSError,
        ValueError,
        KeyError,
    ) as exc:
        summary["error"] = str(exc)
        print(json.dumps(summary, ensure_ascii=False, indent=2), file=sys.stderr)
        return 1
    finally:
        if overrides_active:
            try:
                remove_knowledge_overrides(
                    kubeconfig=kubeconfig, namespace=args.namespace
                )
            except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
                print(
                    json.dumps(
                        {
                            "warning": "failed to remove P0-004 Knowledge env overrides",
                            "manual_action": (
                                "remove RAGFLOW_API_BASE, RETRIEVAL_DATASET_ALLOWLIST and "
                                "RETRIEVAL_PROVIDER_TIMEOUT_SECONDS explicit env values"
                            ),
                            "error_type": type(exc).__name__,
                        }
                    ),
                    file=sys.stderr,
                )
        if provider_active:
            try:
                delete_provider_double(
                    kubeconfig=kubeconfig, namespace=args.namespace
                )
            except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
                print(
                    json.dumps(
                        {
                            "warning": "failed to delete P0-004 provider double",
                            "manual_action": (
                                "delete deployment/service p0-004-provider-double"
                            ),
                        }
                    ),
                    file=sys.stderr,
                )


if __name__ == "__main__":
    raise SystemExit(main())
