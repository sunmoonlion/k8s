"""Restore an archive ONLY into a fresh loopback disposable MinIO.

The enclosing operator owns a network=none container. No business credentials.
S3 assigns new version IDs: return an explicit mapping, never claim IDs survive.
"""
import hashlib
import json
import os
import tarfile
import time


def restore_plan(manifest):
    if manifest.get("kind") != "info-object-backup-v1" or manifest.get("live_writes") is not False:
        raise ValueError("invalid_manifest")
    groups, latest = {}, {}
    rows = manifest["references"]
    if len(rows) > 5000:
        raise ValueError("too_many_references")
    for row in rows:
        bucket, key = row["bucket"], row["object_key"]
        if bucket != "development-info-originals" or not key.startswith("info/original/"):
            raise ValueError("wrong_object_scope")
        version = row["resolved_version_id"]
        identity = (bucket, key, version)
        if identity in groups and any(groups[identity][k] != row[k] for k in ("sha256", "size_bytes", "metadata", "content_type")):
            raise ValueError("inconsistent_version_snapshot")
        groups[identity] = row
        if row["reference_was_unversioned"]:
            if (bucket, key) in latest and latest[(bucket, key)] != version:
                raise ValueError("latest_changed_during_backup")
            latest[(bucket, key)] = version
    # Restore the captured latest version last for every unversioned reference.
    return sorted(groups.items(), key=lambda item:(item[0][:2], latest.get(item[0][:2]) == item[0][2], str(item[0][2])))


def main():
    import boto3
    from botocore.config import Config
    client = boto3.client("s3", endpoint_url="http://127.0.0.1:9000", region_name="us-east-1",
        aws_access_key_id=os.environ["MINIO_ROOT_USER"], aws_secret_access_key=os.environ["MINIO_ROOT_PASSWORD"],
        config=Config(s3={"addressing_style":"path"}, connect_timeout=1, read_timeout=5,
                      retries={"total_max_attempts":1}))
    try:
        deadline = time.monotonic() + 40
        while True:
            try:
                response = client.list_buckets()
                break
            except Exception:
                if time.monotonic() >= deadline:
                    raise ValueError("isolated_minio_not_ready") from None
                time.sleep(.2)
        if response["Buckets"]:
            raise ValueError("restore_target_not_empty")
        with tarfile.open("/backup/objects.private.tar", "r:") as archive:
            manifest = json.load(archive.extractfile("manifest.private.json"))
            plan = restore_plan(manifest)
            expected = {"manifest.private.json"} | {"blobs/"+r["sha256"] for r in manifest["references"]}
            if set(archive.getnames()) != expected or len(archive.getnames()) != len(expected):
                raise ValueError("archive_member_mismatch")
            for bucket in sorted({identity[0] for identity, _ in plan}):
                client.create_bucket(Bucket=bucket)
                client.put_bucket_versioning(Bucket=bucket, VersioningConfiguration={"Status":"Enabled"})
            mapping = []
            for (bucket,key,source_version), row in plan:
                body = archive.extractfile("blobs/" + row["sha256"]).read()
                if len(body) != row["size_bytes"] or hashlib.sha256(body).hexdigest() != row["sha256"]:
                    raise ValueError("archive_content_mismatch")
                reply = client.put_object(Bucket=bucket, Key=key, Body=body,
                    Metadata=row["metadata"], ContentType=row["content_type"] or "application/octet-stream")
                version = reply.get("VersionId")
                if not version or version == "null":
                    raise ValueError("restore_version_missing")
                obj = client.get_object(Bucket=bucket, Key=key, VersionId=version)
                try:
                    restored = obj["Body"].read(len(body)+1)
                finally:
                    obj["Body"].close()
                if restored != body or obj.get("VersionId") != version or obj.get("Metadata", {}) != row["metadata"]:
                    raise ValueError("restored_object_mismatch")
                mapping.append({"bucket":bucket, "key":key, "source_version":source_version,
                                "restored_version":version, "sha256":row["sha256"]})
            for row in manifest["references"]:
                if not row["reference_was_unversioned"]:
                    continue
                obj = client.get_object(Bucket=row["bucket"], Key=row["object_key"])
                try:
                    body = obj["Body"].read(row["size_bytes"]+1)
                finally:
                    obj["Body"].close()
                if len(body) != row["size_bytes"] or hashlib.sha256(body).hexdigest() != row["sha256"]:
                    raise ValueError("unversioned_reference_mismatch")
        print(json.dumps({"status":"restored", "references":len(manifest["references"]),
            "versions":len(mapping), "version_ids_preserved":False,
            "database_reference_remap_tested":False, "mapping":mapping}))
    finally:
        client.close()


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(json.dumps({"status":"failed", "reason":type(exc).__name__}))
        raise SystemExit(1)
