#!/usr/bin/env python3
"""Exercise the candidate Knowledge API through the real legacy consumer contract."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from typing import Any


PROGRAM = r'''
import asyncio
import json
import os
import uuid

import httpx

from app.domain.agent.knowledge import (
    Citation,
    KnowledgeFilters,
    KnowledgeQuery,
    RetrievalSecurityContext,
)
from app.infrastructure.external.knowledge_retrieval import (
    get_knowledge_retrieval_client,
)


async def main() -> None:
    client = get_knowledge_retrieval_client()
    provider = client._token_provider
    retrieval_url = client._retrieval_url
    if provider is None or not retrieval_url:
        raise RuntimeError("retrieval relation is not configured")

    token = await provider.get_token()
    ingestion_url = retrieval_url.rsplit("/", 1)[0] + "/ingestions"
    async with httpx.AsyncClient(timeout=20) as http:
        valid_shape = await http.post(
            retrieval_url,
            json={},
            headers={"Authorization": f"Bearer {token}"},
        )
        cross_relation = await http.post(
            ingestion_url,
            json={},
            headers={"Authorization": f"Bearer {token}"},
        )
        anonymous = await http.post(retrieval_url, json={})
    if (
        valid_shape.status_code,
        cross_relation.status_code,
        anonymous.status_code,
    ) != (422, 401, 401):
        raise RuntimeError("service identity boundary returned unexpected statuses")

    query = KnowledgeQuery(
        request_id=uuid.uuid4(),
        query=os.environ["R5_QUERY_HINT"],
        dataset_keys=[os.environ["R5_DATASET_KEY"]],
        filters=KnowledgeFilters(),
        top_k=5,
        token_budget=4000,
        security_context=RetrievalSecurityContext(
            tenant_id="sunmoonai",
            actor_id=uuid.uuid4(),
            actor_type="service",
            policy_version="architecture-v2-r5",
        ),
    )
    response = await client.retrieve(query)
    if not response.evidence:
        raise RuntimeError("candidate retrieval returned no governed evidence")
    citation = Citation.from_evidence(response.evidence[0])
    citation_payload = citation.model_dump(mode="json")
    forbidden = {
        key
        for key in citation_payload
        if key in {"source_uri", "provider", "provider_metadata"}
        or key.startswith(("provider_", "ragflow_"))
    }
    if forbidden:
        raise RuntimeError("citation leaked provider fields")

    token = ""
    print(json.dumps({
        "task": "R5-K3-knowledge-service-contract",
        "result": "passed",
        "valid_retrieval_shape": valid_shape.status_code,
        "retrieval_token_on_ingestion": cross_relation.status_code,
        "anonymous_retrieval": anonymous.status_code,
        "evidence_count": len(response.evidence),
        "citation_provider_fields_absent": True,
        "token_printed": False,
        "credentials_printed": False,
        "retrieval_content_printed": False,
        "provider_ids_printed": False,
        "service_account_token_mounted": False,
    }, separators=(",", ":"), sort_keys=True))


try:
    asyncio.run(main())
except Exception as exc:
    print(json.dumps({
        "task": "R5-K3-knowledge-service-contract",
        "result": "failed",
        "reason": type(exc).__name__,
        "token_printed": False,
        "credentials_printed": False,
        "retrieval_content_printed": False,
        "provider_ids_printed": False,
    }, separators=(",", ":"), sort_keys=True))
    raise SystemExit(1) from None
'''


def kubectl(args: argparse.Namespace, *values: str, input_text: str | None = None) -> str:
    completed = subprocess.run(
        ["kubectl", "--kubeconfig", args.kubeconfig, *values],
        input=input_text,
        text=True,
        capture_output=True,
        check=False,
        env={key: value for key, value in __import__("os").environ.items() if key != "DEBUG"},
    )
    if completed.returncode != 0:
        raise RuntimeError("kubectl command failed")
    return completed.stdout


def deployment_image(args: argparse.Namespace) -> str:
    if args.image:
        return args.image
    return kubectl(
        args,
        "get",
        "deployment",
        args.consumer_deployment,
        "-n",
        args.namespace,
        "-o",
        "jsonpath={.spec.template.spec.containers[0].image}",
    ).strip()


def job_manifest(args: argparse.Namespace, image: str) -> dict[str, Any]:
    return {
        "apiVersion": "batch/v1",
        "kind": "Job",
        "metadata": {
            "name": args.job,
            "namespace": args.namespace,
            "labels": {"sunmoonai.com/task": "r5-k3-knowledge-service-contract"},
        },
        "spec": {
            "backoffLimit": 0,
            "activeDeadlineSeconds": 180,
            "ttlSecondsAfterFinished": 300,
            "template": {
                "metadata": {
                    "labels": {
                        "sunmoonai.com/task": "r5-k3-knowledge-service-contract",
                        "sunmoonai.com/allow-knowledge-r5-internal": "true",
                    }
                },
                "spec": {
                    "restartPolicy": "Never",
                    "automountServiceAccountToken": False,
                    "imagePullSecrets": [{"name": "harbor-registry-secret"}],
                    "containers": [
                        {
                            "name": "verify",
                            "image": image,
                            "imagePullPolicy": "IfNotPresent",
                            "command": ["/app/.venv/bin/python", "-c", PROGRAM],
                            "env": [
                                {
                                    "name": "KNOWLEDGE_RETRIEVAL_URL",
                                    "value": args.endpoint,
                                },
                                {"name": "R5_DATASET_KEY", "value": args.dataset_key},
                                {"name": "R5_QUERY_HINT", "value": args.query_hint},
                                *[
                                    {
                                        "name": key,
                                        "valueFrom": {
                                            "secretKeyRef": {
                                                "name": args.caller_secret,
                                                "key": key,
                                            }
                                        },
                                    }
                                    for key in (
                                        "KNOWLEDGE_RETRIEVAL_SERVICE_CLIENT_ID",
                                        "KNOWLEDGE_RETRIEVAL_SERVICE_CLIENT_SECRET",
                                        "KNOWLEDGE_RETRIEVAL_SERVICE_DISCOVERY_URL",
                                        "KNOWLEDGE_RETRIEVAL_SERVICE_BACKCHANNEL_ENDPOINT",
                                    )
                                ],
                            ],
                            "securityContext": {
                                "allowPrivilegeEscalation": False,
                                "capabilities": {"drop": ["ALL"]},
                            },
                        }
                    ],
                },
            },
        },
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--kubeconfig", required=True)
    parser.add_argument("--namespace", default="app-platform-dev")
    parser.add_argument("--consumer-deployment", default="celeryworker-research-admin-backend")
    parser.add_argument("--caller-secret", default="research-knowledge-retrieval-client")
    parser.add_argument("--endpoint", default="http://knowledge-r5-backend:8000/api/internal/v1/knowledge/retrievals")
    parser.add_argument("--dataset-key", required=True)
    parser.add_argument("--query-hint", required=True)
    parser.add_argument("--image")
    parser.add_argument("--job", default="r5-k3-knowledge-service-contract")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        image = deployment_image(args)
        kubectl(args, "delete", "job", args.job, "-n", args.namespace, "--ignore-not-found=true", "--wait=true")
        kubectl(args, "apply", "-f", "-", input_text=json.dumps(job_manifest(args, image)))
        deadline = time.monotonic() + 180
        succeeded = False
        while time.monotonic() < deadline:
            payload = json.loads(kubectl(args, "get", "job", args.job, "-n", args.namespace, "-o", "json"))
            status = payload.get("status", {})
            if status.get("succeeded") == 1:
                succeeded = True
                break
            if status.get("failed"):
                break
            time.sleep(2)
        logs = kubectl(args, "logs", f"job/{args.job}", "-n", args.namespace, "--all-containers=true")
        marker = next((line for line in reversed(logs.splitlines()) if line.startswith("{")), "")
        result = json.loads(marker)
        print(json.dumps(result, indent=2, ensure_ascii=False, sort_keys=True))
        return 0 if succeeded and result.get("result") == "passed" else 1
    except (RuntimeError, json.JSONDecodeError):
        print(json.dumps({
            "task": "R5-K3-knowledge-service-contract",
            "result": "failed",
            "reason": "harness-failure",
            "credentials_printed": False,
        }, sort_keys=True))
        return 1
    finally:
        try:
            kubectl(args, "delete", "job", args.job, "-n", args.namespace, "--ignore-not-found=true", "--wait=false")
        except RuntimeError:
            pass


if __name__ == "__main__":
    sys.exit(main())
