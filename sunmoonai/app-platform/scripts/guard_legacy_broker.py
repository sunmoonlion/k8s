"""Read-only fail-closed guard against legacy whole-definition overwrite.

An operational safety gate, not authorization enforcement against cluster
administrators. No live mutation, credential logging, or arbitrary JSON import.
"""
import argparse
import base64
import json
import re
import subprocess

MARKER = "sunmoonai.com/runtime-identity-cutover"
APPS = ("info", "knowledge", "investment")
NEW_USER = re.compile(r"(?:info|knowledge|investment)-backend-(?:api|worker|scheduler)-v2")


def verify_legacy_allowed(secret, runtime_names):
    if runtime_names:
        raise ValueError("independent runtime Secret exists; refuse legacy broker overwrite")
    if secret is None:
        return
    if MARKER in secret.get("metadata", {}).get("annotations", {}):
        raise ValueError("broker definitions are managed by identity cutover; refuse legacy overwrite")
    try:
        value = json.loads(base64.b64decode(secret["data"]["load_definition.json"], validate=True))
        if not isinstance(value, dict) or not isinstance(value.get("users"), list):
            raise ValueError()
        for row in value["users"]:
            if not isinstance(row, dict) or not isinstance(row.get("name"), str):
                raise ValueError()
    except (KeyError, TypeError, ValueError):
        raise ValueError("unreadable broker definitions; refuse legacy overwrite") from None
    if any(NEW_USER.fullmatch(row["name"]) for row in value["users"]):
        raise ValueError("independent broker users exist; refuse legacy overwrite")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--kubeconfig")
    parser.add_argument("--namespace", default="messaging-platform-dev")
    parser.add_argument("--app-namespace", default="app-platform-dev")
    args = parser.parse_args()
    if any(not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,62}",n) for n in (args.namespace,args.app_namespace)):
        raise ValueError("invalid namespace")
    command = ["kubectl"]
    if args.kubeconfig:
        command.extend(("--kubeconfig",args.kubeconfig))
    def read(namespace,name,output):
        result = subprocess.run([*command,"--request-timeout=15s","-n",namespace,"get","secret",name,
            "--ignore-not-found=true","-o",output],capture_output=True,text=True,timeout=20)
        if result.returncode:
            raise ValueError("cluster query failed; legacy overwrite refused")
        return result.stdout.strip()
    raw = read(args.namespace,"rabbitmq-app-definitions","json")
    try:
        secret = json.loads(raw) if raw else None
    except ValueError:
        raise ValueError("invalid cluster response; legacy overwrite refused") from None
    names = [read(args.app_namespace,app+"-backend-runtime","name") for app in APPS]
    verify_legacy_allowed(secret,[name for name in names if name])


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(str(exc) if isinstance(exc,ValueError) else "legacy broker guard failed")
        raise SystemExit(1)
