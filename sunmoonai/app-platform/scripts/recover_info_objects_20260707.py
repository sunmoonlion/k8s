"""One approved four-key recovery, not a general S3 repair interface.

Run through the KIND operator wrapper. DB is read-only. No external crawl,
reference rewrite, overwrite, delete, task replay or automatic retry.
"""
from __future__ import annotations

import argparse
import asyncio
import hashlib
import itertools
import json

JOB = "3b05ae27-480d-4d9f-af67-1502f8cbd1f9"
BUCKET = "development-info-originals"
PREFIX = "info/original/source=manual/date=2026-07-07/job=" + JOB + "/"
EXPECTED = {
    "raw.html": ("raw_html", 775, "2830717a990580eab262822cd784a7bfeaf01f34d2f1a6e0532cbd8f76a98e06"),
    "clean.md": ("clean_markdown", 156, "2546628224caf2e38918a5346b4326a24f07db2245d444d58b6637aea79be049"),
    "text.txt": ("text_plain", 156, "2546628224caf2e38918a5346b4326a24f07db2245d444d58b6637aea79be049"),
    "headers.json": ("headers_json", 163, "c7c4da02e0e2ffbfabcaa95459d9be18edd4acf48cd3ea2fe11957bbc7a4764b"),
}
CONTENT_TYPES = {"raw.html":"text/html", "clean.md":"text/markdown; charset=utf-8",
                 "text.txt":"text/plain; charset=utf-8", "headers.json":"application/json; charset=utf-8"}


class RecoveryError(RuntimeError):
    pass


def matches(name, body):
    _, size, digest = EXPECTED[name]
    return len(body) == size and hashlib.sha256(body).hexdigest() == digest


def assert_references(rows):
    expected = {(BUCKET, PREFIX + name, None, kind, size, digest)
                for name, (kind, size, digest) in EXPECTED.items()}
    actual = {(row["bucket"], row["object_key"], row["version_id"], row["artifact_type"],
               row["size_bytes"], row["sha256"]) for row in rows}
    if len(rows) != 4 or actual != expected:
        raise RecoveryError("original_reference_drift")


def assert_missing(client):
    listing = client.list_object_versions(Bucket=BUCKET, Prefix=PREFIX, MaxKeys=100)
    if listing.get("IsTruncated") or listing.get("Versions") or listing.get("DeleteMarkers"):
        raise RecoveryError("target_directory_not_empty")


def reconstruct(raw, metadata, url, extract):
    if not matches("raw.html", raw):
        raise RecoveryError("source_copy_digest_mismatch")
    _, markdown, text, _ = extract(raw.decode(metadata.get("encoding") or "utf-8"), url)
    candidates = {"raw.html":raw, "clean.md":markdown.encode(), "text.txt":text.encode()}
    headers = metadata["headers"]
    if not isinstance(headers, dict) or len(headers) > 8:
        raise RecoveryError("header_reconstruction_bound")
    for ordered in itertools.permutations(headers.items()):
        data = json.dumps(dict(ordered), ensure_ascii=False, indent=2).encode()
        if matches("headers.json", data):
            candidates["headers.json"] = data
            break
    if set(candidates) != set(EXPECTED) or any(not matches(n, b) for n, b in candidates.items()):
        raise RecoveryError("reconstructed_content_mismatch")
    return candidates


def apply_missing(client, candidates, state):
    if set(candidates) != set(EXPECTED) or any(not matches(n, b) for n, b in candidates.items()):
        raise RecoveryError("candidate_drift")
    # Check all four before the first PUT; conditional writes close the race.
    assert_missing(client)
    for name in EXPECTED:
        state["in_flight"] = name
        result = client.put_object(Bucket=BUCKET, Key=PREFIX + name, Body=candidates[name],
            ContentType=CONTENT_TYPES[name], Metadata={"sha256":EXPECTED[name][2]}, IfNoneMatch="*")
        version = result.get("VersionId")
        record = {"file":name, "version_id":version, "sha256":EXPECTED[name][2], "verified":False}
        state["written"].append(record)
        if not version or version == "null":
            raise RecoveryError("versioned_put_receipt_missing")
        response = client.get_object(Bucket=BUCKET, Key=PREFIX + name, VersionId=version)
        try:
            body = response["Body"].read(EXPECTED[name][1] + 1)
        finally:
            response["Body"].close()
        if (not matches(name, body) or response.get("VersionId") != version
                or response.get("ContentLength") != EXPECTED[name][1]
                or response.get("Metadata", {}).get("sha256") != EXPECTED[name][2]):
            raise RecoveryError("restored_object_verification_failed")
        record["verified"] = True
        state["in_flight"] = None


async def inventory(settings):
    import asyncpg
    from sqlalchemy.engine import make_url
    url = make_url(settings.database_url)
    if url.database != "info_admin":
        raise RecoveryError("wrong_database")
    conn = await asyncpg.connect(host=url.host, port=url.port or 5432, user=url.username,
        password=url.password, database=url.database, timeout=5, command_timeout=10)
    try:
        async with conn.transaction(isolation="repeatable_read", readonly=True):
            rows = await conn.fetch("SELECT artifact_type,bucket,object_key,version_id,sha256,size_bytes "
                                   "FROM raw_artifact WHERE crawl_job_id=$1::uuid", JOB)
            assert_references(rows)
            job = await conn.fetchrow("SELECT final_url,target_url,response_metadata FROM crawl_job WHERE id=$1::uuid", JOB)
            duplicate = await conn.fetchrow("SELECT bucket,object_key,version_id FROM raw_artifact "
                "WHERE sha256=$1 AND size_bytes=775 AND version_id IS NOT NULL AND version_id<>'null' "
                "AND bucket=$2 AND object_key LIKE 'info/original/%' ORDER BY id LIMIT 1", EXPECTED["raw.html"][2], BUCKET)
            if not job or not duplicate:
                raise RecoveryError("source_copy_missing")
            return dict(job), dict(duplicate)
    finally:
        await conn.close()


def main(state):
    import boto3
    from botocore.config import Config
    from core.config import get_settings
    from app.application.services.info_crawl_service import _extract_html
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    settings = get_settings()
    if settings.storage_backend.lower() != "s3" or settings.s3_bucket != BUCKET:
        raise RecoveryError("wrong_object_store")
    job, duplicate = asyncio.run(inventory(settings))
    client = boto3.client("s3", endpoint_url=settings.s3_endpoint, region_name=settings.s3_region,
        aws_access_key_id=settings.s3_access_key_id, aws_secret_access_key=settings.s3_secret_access_key,
        use_ssl=settings.s3_use_tls, config=Config(s3={"addressing_style":"path"},
            connect_timeout=3, read_timeout=10, retries={"total_max_attempts":1}))
    try:
        if "IfNoneMatch" not in client.meta.service_model.operation_model("PutObject").input_shape.members:
            raise RecoveryError("conditional_put_not_supported")
        assert_missing(client)
        source = client.get_object(Bucket=duplicate["bucket"], Key=duplicate["object_key"], VersionId=duplicate["version_id"])
        try:
            raw = source["Body"].read(776)
        finally:
            source["Body"].close()
        if source.get("VersionId") != duplicate["version_id"]:
            raise RecoveryError("source_version_mismatch")
        candidates = reconstruct(raw, json.loads(job["response_metadata"]),
                                 job["final_url"] or job["target_url"], _extract_html)
        if args.apply:
            apply_missing(client, candidates, state)
        state.update(status="recovered" if args.apply else "dry_run_passed", database_writes=False,
                     task_replay=False, expected_files=4, bucket=BUCKET, prefix=PREFIX)
    finally:
        client.close()


if __name__ == "__main__":
    state = {"written":[], "in_flight":None}
    try:
        main(state)
    except Exception as exc:
        state.update(status="failed", reason=str(exc) if isinstance(exc, RecoveryError) else type(exc).__name__)
        print(json.dumps(state))
        raise SystemExit(1)
    print(json.dumps(state))
