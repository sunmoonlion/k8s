"""Export Info-owned referenced objects read-only to a private local archive.

This is an online preparation backup, not a quiescent cutover receipt or proof
of S3 restoration. Credentials remain in the existing API process environment.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile

import kind_database_rehearsal as common


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--kubeconfig", type=Path, required=True)
    parser.add_argument("--cluster-uid", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output = args.output.absolute()
    if args.output != args.output.resolve() or not args.output.parent.is_dir():
        raise common.RehearsalError("output_parent_missing_or_symlink")
    if subprocess.run(["git", "-C", str(args.output.parent), "rev-parse", "--show-toplevel"],
                      capture_output=True).returncode == 0:
        raise common.RehearsalError("backup_must_be_outside_git")
    args.output.mkdir(mode=0o700)
    common.ERROR_DIR = args.output
    common.verify_kind(args)
    # Resolve a ready, non-terminating API Pod once; no deployment or restart.
    pods = json.loads(common.kubectl(args, "-n", "app-platform-dev", "get", "pods", "-o", "json"))["items"]
    pods = [pod for pod in pods if pod["metadata"]["name"].startswith("info-backend-api-")
            and not pod["metadata"].get("deletionTimestamp")
            and any(c["type"] == "Ready" and c["status"] == "True" for c in pod.get("status", {}).get("conditions", []))]
    if not pods:
        raise common.RehearsalError("no_ready_info_api")
    pod = sorted(pods, key=lambda p:p["metadata"]["name"])[0]
    containers = pod["spec"]["containers"]
    if len(containers) != 1:
        raise common.RehearsalError("unexpected_api_sidecar")
    payload = Path(__file__).with_name("info_object_backup_payload.py").read_bytes()
    result = subprocess.run(["kubectl", "--kubeconfig", str(args.kubeconfig), "--context", "kind-kind",
        "-n", "app-platform-dev", "exec", "-i", pod["metadata"]["name"], "-c", containers[0]["name"],
        "--", "python", "-B", "-"], input=payload, capture_output=True, timeout=300)
    common.private_write(args.output / "payload-stderr.private.log", result.stderr)
    if result.returncode:
        common.private_write(args.output / "failure.private.json", result.stdout)
        try:
            failure = json.loads(result.stdout)
            summary = {key:failure[key] for key in ("status", "reason", "references", "verified") if key in failure}
            summary["failure_counts"] = dict(Counter(row["reason"] for row in failure.get("failures", [])))
        except (ValueError, KeyError, TypeError):
            summary = {"status":"failed", "reason":"payload_failed"}
        print(common.encoded(summary))
        return 1
    common.private_write(args.output / "objects.private.tar", result.stdout)
    with tarfile.open(fileobj=io.BytesIO(result.stdout)) as archive:
        manifest = json.load(archive.extractfile("manifest.private.json"))
        if manifest.get("kind") != "info-object-backup-v1" or manifest.get("live_writes") is not False:
            raise common.RehearsalError("invalid_object_manifest")
        expected = {"manifest.private.json"} | {"blobs/" + row["sha256"] for row in manifest["references"]}
        names = archive.getnames()
        if set(names) != expected or len(names) != len(expected) or any(not m.isfile() for m in archive):
            raise common.RehearsalError("unexpected_archive_members")
        for row in manifest["references"]:
            blob = archive.extractfile("blobs/" + row["sha256"]).read()
            if len(blob) != row["size_bytes"] or hashlib.sha256(blob).hexdigest() != row["sha256"]:
                raise common.RehearsalError("archived_object_mismatch")
    receipt = {"status":"backed_up", "cluster_uid":args.cluster_uid, "live_writes":False,
        "pod_uid":pod["metadata"]["uid"], "payload_sha256":hashlib.sha256(payload).hexdigest(),
        "references":len(manifest["references"]), "unique_blobs":len(expected)-1,
        "archive_sha256":hashlib.sha256(result.stdout).hexdigest(),
        "s3_restore_verified":False, "cutover_backup_receipt":False}
    common.private_write(args.output / "backup.json", common.encoded(receipt))
    print(common.encoded(receipt))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        reason = str(exc) if isinstance(exc, common.RehearsalError) else type(exc).__name__
        print(common.encoded({"status":"failed", "reason":reason}))
        raise SystemExit(1)
