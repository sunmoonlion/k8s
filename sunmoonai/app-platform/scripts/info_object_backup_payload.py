"""Read-only Info object export payload; run via stdin in the existing API Pod.

stdout is a private tar archive, never a terminal. On failure stdout is a JSON
inventory of missing/mismatched references (also private). Does not write S3 or
SQL, search alternate versions, mutate references, or silently omit failures.
"""
from __future__ import annotations

import asyncio
import hashlib
import io
import json
import re
import sys
import tarfile

MAX_OBJECT_BYTES = 32 * 1024 * 1024
MAX_TOTAL_BYTES = 256 * 1024 * 1024
MAX_REFERENCES = 5000
PREFIX = "info/original/"


def validate_reference(row, bucket):
    if row["bucket"] != bucket or not row["object_key"].startswith(PREFIX):
        raise ValueError("reference_outside_info_scope")
    if not re.fullmatch(r"[0-9a-f]{64}", row["sha256"]):
        raise ValueError("invalid_reference_digest")
    if not 0 <= row["size_bytes"] <= MAX_OBJECT_BYTES:
        raise ValueError("object_size_bound")


def fetch_reference(client, row):
    params = {"Bucket": row["bucket"], "Key": row["object_key"]}
    version = row["version_id"]
    if version is not None:
        params["VersionId"] = version
    response = client.get_object(**params)
    stream = response["Body"]
    try:
        body = stream.read(MAX_OBJECT_BYTES + 1)
    finally:
        stream.close()
    actual_version = response.get("VersionId")
    if version is not None and actual_version != version:
        raise ValueError("object_version_mismatch")
    if len(body) != row["size_bytes"] or int(response["ContentLength"]) != len(body):
        raise ValueError("object_size_mismatch")
    if hashlib.sha256(body).hexdigest() != row["sha256"]:
        raise ValueError("object_digest_mismatch")
    return body, {"resolved_version_id": actual_version,
                  "reference_was_unversioned": version is None,
                  "content_type": response.get("ContentType"),
                  "metadata": response.get("Metadata", {})}


async def references(settings):
    import asyncpg
    from sqlalchemy.engine import make_url
    url = make_url(str(settings.database_url))
    if url.database != "info_admin":
        raise ValueError("wrong_info_database")
    conn = await asyncpg.connect(host=url.host, port=url.port or 5432,
        user=url.username, password=url.password, database=url.database,
        timeout=5, command_timeout=30)
    try:
        async with conn.transaction(isolation="repeatable_read", readonly=True):
            rows = await conn.fetch("""
              SELECT 'raw_artifact' AS origin,id::text,bucket,object_key,version_id,
                     sha256,size_bytes FROM raw_artifact
              UNION ALL
              SELECT 'extracted_content',id::text,bucket,object_key,NULL::text,
                     sha256,size_bytes FROM extracted_content
              ORDER BY origin,id LIMIT 5001
            """)
            if len(rows) > MAX_REFERENCES:
                raise ValueError("reference_count_bound")
            return [dict(row) for row in rows]
    finally:
        await conn.close()


def main():
    from core.config import get_settings
    import boto3
    from botocore.config import Config
    from botocore.exceptions import ClientError

    settings = get_settings()
    rows = asyncio.run(references(settings))
    # The running rollback image predates ObjectStorage.s3_client(). Use its
    # existing settings directly; never assume candidate code is already live.
    if settings.storage_backend.lower() != "s3":
        raise ValueError("s3_backend_required")
    client = boto3.client("s3", endpoint_url=settings.s3_endpoint,
        region_name=settings.s3_region, aws_access_key_id=settings.s3_access_key_id,
        aws_secret_access_key=settings.s3_secret_access_key, use_ssl=settings.s3_use_tls,
        config=Config(s3={"addressing_style":"path" if settings.s3_force_path_style else "virtual"},
                      connect_timeout=3, read_timeout=5,
                      retries={"mode":"standard", "total_max_attempts":2}))
    failures, manifest, blobs = [], [], {}
    total = 0
    try:
        for row in rows:
            try:
                validate_reference(row, settings.s3_bucket)
                body, details = fetch_reference(client, row)
                if row["sha256"] not in blobs:
                    total += len(body)
                    if total > MAX_TOTAL_BYTES:
                        raise ValueError("archive_size_bound")
                    blobs[row["sha256"]] = body
                manifest.append(row | details)
            except ClientError as exc:
                # Keep provider messages/URLs/credentials out of output.
                code = str(exc.response.get("Error", {}).get("Code", "unknown"))
                failures.append(row | {"reason": code if code in {
                    "NoSuchKey", "NoSuchVersion", "AccessDenied", "404", "403"
                } else "s3_error"})
            except ValueError as exc:
                failures.append(row | {"reason": str(exc)})
    finally:
        client.close()
    if failures:
        print(json.dumps({"status":"failed", "references":len(rows),
                          "verified":len(manifest), "failures":failures}))
        return 1
    with tarfile.open(fileobj=sys.stdout.buffer, mode="w|") as archive:
        payloads = {"manifest.private.json":json.dumps({
            "kind":"info-object-backup-v1", "live_writes":False,
            "references":manifest, "unique_bytes":total,
            "unversioned_policy":"latest must match recorded size and sha256; no reference rewrite",
        }, sort_keys=True).encode()}
        payloads.update({"blobs/" + digest:body for digest,body in blobs.items()})
        for name, body in sorted(payloads.items()):
            member = tarfile.TarInfo(name)
            member.size, member.mode = len(body), 0o600
            archive.addfile(member, io.BytesIO(body))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(json.dumps({"status":"failed", "reason":type(exc).__name__}))
        raise SystemExit(1)
