"""KIND-bound wrapper for the explicitly approved 2026-07-07 four-key recovery."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

import kind_database_rehearsal as common


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--kubeconfig", type=Path, required=True)
    parser.add_argument("--cluster-uid", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    args.output = args.output.absolute()
    if args.output != args.output.resolve() or not args.output.parent.is_dir():
        raise common.RehearsalError("output_parent_missing_or_symlink")
    if subprocess.run(["git", "-C", str(args.output.parent), "rev-parse", "--show-toplevel"],
                      capture_output=True).returncode == 0:
        raise common.RehearsalError("receipt_must_be_outside_git")
    args.output.mkdir(mode=0o700)
    common.verify_kind(args)
    payload = Path(__file__).with_name("recover_info_objects_20260707.py").read_bytes()
    common.private_write(args.output / "payload.py", payload)
    argv = ["kubectl", "--kubeconfig", str(args.kubeconfig), "--context", "kind-kind",
            "-n", "app-platform-dev", "exec", "-i", "deployment/info-backend-api", "--", "python", "-B", "-"]
    if args.apply:
        argv.append("--apply")
    result = subprocess.run(argv, input=payload, capture_output=True, timeout=180)
    common.private_write(args.output / "stdout.json", result.stdout)
    common.private_write(args.output / "stderr.private.log", result.stderr)
    receipt = {"cluster_uid":args.cluster_uid, "payload_sha256":hashlib.sha256(payload).hexdigest(),
               "apply":args.apply, "exit_code":result.returncode}
    common.private_write(args.output / "execution.json", common.encoded(receipt))
    print(common.encoded(receipt))
    # Payload emits only controlled status, file identities and checksums.
    report = json.loads(result.stdout)
    print(common.encoded(report))
    return result.returncode


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(common.encoded({"status":"failed", "reason":type(exc).__name__,
                              "warning":"inspect private receipt before any retry"}))
        raise SystemExit(1)
