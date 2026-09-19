"""Restore private Info archive to owned network-isolated disposable MinIO."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import secrets
import subprocess

import kind_database_rehearsal as common

MINIO_IMAGE = "sha256:a72bf37c235a83a73890d2a46c5b36801fed61c335175e0396070bf84a8bbb98"
CLIENT_IMAGE = "harbor.sunmoonai.com:30443/app-images/info-backend@sha256:ec9e1da89285ec0e85d12ff51e25ce42c713b604989f9f8ba6c7812ff517c4aa"
LABEL = "sunmoonai.info-object-restore"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--sha256", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    archive, output = args.archive.absolute(), args.output.absolute()
    if archive != archive.resolve() or output != output.resolve() or not output.parent.is_dir():
        raise common.RehearsalError("path_not_explicit_or_parent_missing")
    if hashlib.sha256(archive.read_bytes()).hexdigest() != args.sha256:
        raise common.RehearsalError("archive_digest_mismatch")
    if subprocess.run(["git", "-C", str(output.parent), "rev-parse", "--show-toplevel"], capture_output=True).returncode == 0:
        raise common.RehearsalError("private_output_inside_git")
    output.mkdir(mode=0o700)
    common.ERROR_DIR = output
    token = secrets.token_hex(10)
    env = {**os.environ, "MINIO_ROOT_USER":"restore"+token, "MINIO_ROOT_PASSWORD":secrets.token_hex(24)}
    container = common.run(["docker", "create", "--pull=never", "--network=none", "--memory=512m", "--cpus=2",
        "--name", "info-restore-"+token, "--label", LABEL+"="+token,
        "-e", "MINIO_ROOT_USER", "-e", "MINIO_ROOT_PASSWORD", "-e", "MINIO_BROWSER=off",
        "-e", "MINIO_UPDATE=off", MINIO_IMAGE, "server", "/data", "--address", "127.0.0.1:9000"], env=env).decode().strip()
    try:
        common.run(["docker", "start", container])
        payload = Path(__file__).with_name("info_object_restore_payload.py").resolve()
        result = subprocess.run(["docker", "run", "--rm", "--pull=never", "--network=container:"+container,
            "--user", f"{os.getuid()}:{os.getgid()}",
            "--read-only", "--tmpfs", "/tmp", "--cap-drop=ALL", "--security-opt=no-new-privileges",
            "--memory=512m", "--cpus=2", "-e", "MINIO_ROOT_USER", "-e", "MINIO_ROOT_PASSWORD",
            "--mount", f"type=bind,src={archive},dst=/backup/objects.private.tar,readonly",
            "--mount", f"type=bind,src={payload},dst=/restore.py,readonly",
            CLIENT_IMAGE, "python", "-B", "/restore.py"], env=env, capture_output=True, timeout=180)
        common.private_write(output / "restore.private.json", result.stdout)
        common.private_write(output / "stderr.private.log", result.stderr)
        if result.returncode:
            raise common.RehearsalError("isolated_s3_restore_failed")
        report = json.loads(result.stdout)
        report.pop("mapping")
        report.update(archive_sha256=args.sha256, network="none", live_writes=False)
    finally:
        obj = json.loads(common.run(["docker", "inspect", container]))[0]
        if (obj["Config"]["Labels"].get(LABEL) != token or obj["Image"] != MINIO_IMAGE
                or obj["HostConfig"]["NetworkMode"] != "none" or any(m["Type"] != "volume" for m in obj["Mounts"])):
            raise common.RehearsalError("refuse_cleanup_unowned_restore")
        common.run(["docker", "rm", "-f", "-v", container])
    report["owned_disposable_cleaned"] = True
    common.private_write(output / "receipt.json", common.encoded(report))
    print(common.encoded(report))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(common.encoded({"status":"failed", "reason":str(exc) if isinstance(exc, common.RehearsalError) else type(exc).__name__}))
        raise SystemExit(1)
