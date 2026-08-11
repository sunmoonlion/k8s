#!/usr/bin/env python3
"""Verify the committed Knowledge/RAGFlow binding without exposing provider IDs."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys


PROGRAM = r'''
import asyncio
import hashlib
import json

from sqlalchemy import select

from app.infrastructure.external.ragflow import RAGFlowClient, check_ragflow_config
from app.infrastructure.models.knowledge import KnowledgeDocumentVersion
from app.infrastructure.storage.postgres import get_postgres
from core.config import get_settings


def digest(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


async def main() -> None:
    settings = get_settings()
    postgres = get_postgres()
    await postgres.init()
    try:
        async with postgres.session_factory() as session:
            result = await session.execute(
                select(KnowledgeDocumentVersion)
                .where(
                    KnowledgeDocumentVersion.status == "indexed",
                    KnowledgeDocumentVersion.provider == "ragflow",
                )
                .order_by(KnowledgeDocumentVersion.created_at)
            )
            versions = list(result.scalars().all())
        if not versions:
            raise RuntimeError("no indexed RAGFlow binding exists")
        version = versions[0]
        config = await check_ragflow_config(settings)
        if not config.enabled or not config.reachable:
            raise RuntimeError("RAGFlow configuration is not reachable")
        client = RAGFlowClient(
            settings,
            timeout_seconds=settings.retrieval_provider_timeout_seconds,
        )
        try:
            document = await client.get_document(
                version.provider_dataset_id,
                version.provider_document_id,
            )
            query = (version.title or version.source_name or "knowledge").strip()
            retrieval = await client.retrieve(
                question=query,
                dataset_ids=[version.provider_dataset_id],
                document_ids=[version.provider_document_id],
                top_k=8,
            )
        finally:
            await client.close()
        matching_chunks = sum(
            1
            for chunk in retrieval.chunks
            if str(chunk.get("document_id") or chunk.get("doc_id") or "")
            == version.provider_document_id
        )
        print(
            json.dumps(
                {
                    "task": "R5-K0-knowledge-provider-baseline",
                    "result": "passed",
                    "indexed_binding_count": len(versions),
                    "dataset_id_sha256": digest(version.provider_dataset_id),
                    "document_id_sha256": digest(version.provider_document_id),
                    "provider_document_found": bool(document),
                    "provider_document_run": str(document.get("run") or ""),
                    "provider_document_chunk_count": document.get("chunk_count"),
                    "retrieval_total": retrieval.total,
                    "retrieval_returned_chunks": len(retrieval.chunks),
                    "retrieval_matching_chunks": matching_chunks,
                    "provider_reachable": config.reachable,
                    "provider_has_default_embedding": config.has_default_embedding,
                    "credentials_printed": False,
                    "provider_ids_printed": False,
                    "retrieval_content_printed": False,
                },
                ensure_ascii=False,
                sort_keys=True,
            )
        )
    finally:
        await postgres.shutdown()


asyncio.run(main())
'''


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--kubeconfig", required=True)
    parser.add_argument("--namespace", default="app-platform-dev")
    parser.add_argument("--deployment", default="knowledge-admin-backend")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    command = [
        "kubectl",
        "--kubeconfig",
        args.kubeconfig,
        "exec",
        "--quiet",
        "-n",
        args.namespace,
        f"deployment/{args.deployment}",
        "--",
        "/app/.venv/bin/python",
        "-c",
        PROGRAM,
    ]
    completed = subprocess.run(command, text=True, capture_output=True, check=False)
    if completed.returncode != 0:
        error_type = "provider-probe-failed"
        print(
            json.dumps(
                {
                    "task": "R5-K0-knowledge-provider-baseline",
                    "result": "failed",
                    "error": error_type,
                    "credentials_printed": False,
                    "provider_ids_printed": False,
                },
                sort_keys=True,
            )
        )
        return 1
    try:
        payload = json.loads(completed.stdout.strip().splitlines()[-1])
    except (IndexError, json.JSONDecodeError):
        print(
            json.dumps(
                {
                    "task": "R5-K0-knowledge-provider-baseline",
                    "result": "failed",
                    "error": "provider-probe-output-invalid",
                    "credentials_printed": False,
                    "provider_ids_printed": False,
                },
                sort_keys=True,
            )
        )
        return 1
    print(json.dumps(payload, indent=2, ensure_ascii=False, sort_keys=True))
    if payload.get("result") != "passed":
        return 1
    if not payload.get("provider_document_found"):
        return 1
    if payload.get("retrieval_matching_chunks", 0) < 1:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
