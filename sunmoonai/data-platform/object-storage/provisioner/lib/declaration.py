#!/usr/bin/env python3

import argparse
import json
import re
import shlex
import sys
from pathlib import Path


DNS_LABEL = re.compile(r"^[a-z0-9]([-a-z0-9]*[a-z0-9])?$")
BUCKET_NAME = re.compile(r"^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$")
ALLOWED_PERMISSIONS = {"read", "write", "delete", "list"}


def fail(message):
    raise ValueError(message)


def load_declaration(path):
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"cannot read declaration: {exc}")

    if data.get("apiVersion") != "storage.sunmoonai.com/v1alpha1":
        fail("apiVersion must be storage.sunmoonai.com/v1alpha1")
    if data.get("kind") != "ObjectStorageAccess":
        fail("kind must be ObjectStorageAccess")

    metadata = data.get("metadata")
    spec = data.get("spec")
    if not isinstance(metadata, dict) or not isinstance(spec, dict):
        fail("metadata and spec must be objects")

    required = (
        "provider",
        "environment",
        "app",
        "backend",
        "namespace",
        "secretName",
        "configMapName",
        "buckets",
    )
    missing = [key for key in required if key not in spec]
    if missing:
        fail(f"missing spec fields: {', '.join(missing)}")
    if spec["provider"] != "platform-s3":
        fail("spec.provider must be platform-s3")
    if spec["environment"] not in {"development", "staging", "production"}:
        fail("spec.environment must be development, staging, or production")
    if spec.get("deletionPolicy", "Retain") != "Retain":
        fail("only deletionPolicy=Retain is supported")

    labels = {
        "metadata.name": metadata.get("name"),
        "spec.app": spec["app"],
        "spec.backend": spec["backend"],
        "spec.namespace": spec["namespace"],
        "spec.secretName": spec["secretName"],
        "spec.configMapName": spec["configMapName"],
    }
    for field, value in labels.items():
        if not isinstance(value, str) or len(value) > 63 or not DNS_LABEL.fullmatch(value):
            fail(f"{field} must be a valid DNS label")

    buckets = spec["buckets"]
    if not isinstance(buckets, list) or not buckets:
        fail("spec.buckets must contain at least one bucket")

    seen = set()
    for index, bucket in enumerate(buckets):
        if not isinstance(bucket, dict):
            fail(f"bucket {index} must be an object")
        name = bucket.get("name")
        if (
            not isinstance(name, str)
            or not 3 <= len(name) <= 63
            or not BUCKET_NAME.fullmatch(name)
            or ".." in name
            or ".-" in name
            or "-." in name
        ):
            fail(f"bucket {index} has an invalid S3 bucket name")
        if name in seen:
            fail(f"duplicate bucket: {name}")
        seen.add(name)

        permissions = bucket.get("permissions")
        if not isinstance(permissions, list) or not permissions:
            fail(f"bucket {name} must contain permissions")
        unknown = set(permissions) - ALLOWED_PERMISSIONS
        if unknown:
            fail(f"bucket {name} has unsupported permissions: {sorted(unknown)}")
        if len(permissions) != len(set(permissions)):
            fail(f"bucket {name} contains duplicate permissions")
        if bucket.get("objectLock", False) and not bucket.get("versioning", False):
            fail(f"bucket {name}: objectLock requires versioning")

    return data


def policy_document(data):
    statements = []
    for bucket in data["spec"]["buckets"]:
        name = bucket["name"]
        permissions = set(bucket["permissions"])

        bucket_actions = []
        object_actions = []
        if "list" in permissions:
            bucket_actions.extend(
                ["s3:GetBucketLocation", "s3:ListBucket", "s3:ListBucketVersions"]
            )
        if "read" in permissions:
            object_actions.extend(["s3:GetObject", "s3:GetObjectVersion"])
        if "write" in permissions:
            object_actions.extend(
                ["s3:AbortMultipartUpload", "s3:PutObject", "s3:ListMultipartUploadParts"]
            )
            bucket_actions.append("s3:ListBucketMultipartUploads")
        if "delete" in permissions:
            object_actions.extend(["s3:DeleteObject", "s3:DeleteObjectVersion"])

        if bucket_actions:
            statements.append(
                {
                    "Effect": "Allow",
                    "Action": sorted(set(bucket_actions)),
                    "Resource": [f"arn:aws:s3:::{name}"],
                }
            )
        if object_actions:
            statements.append(
                {
                    "Effect": "Allow",
                    "Action": sorted(set(object_actions)),
                    "Resource": [f"arn:aws:s3:::{name}/*"],
                }
            )

    return {"Version": "2012-10-17", "Statement": statements}


def shell_output(data):
    spec = data["spec"]
    values = {
        "DECLARATION_NAME": data["metadata"]["name"],
        "APP_NAME": spec["app"],
        "BACKEND_NAME": spec["backend"],
        "TARGET_NAMESPACE": spec["namespace"],
        "TARGET_SECRET_NAME": spec["secretName"],
        "TARGET_CONFIGMAP_NAME": spec["configMapName"],
        "S3_REGION": spec.get("region", "us-east-1"),
        "S3_FORCE_PATH_STYLE": str(spec.get("forcePathStyle", True)).lower(),
        "S3_USE_TLS": str(spec.get("useTLS", False)).lower(),
        "DELETION_POLICY": spec.get("deletionPolicy", "Retain"),
        "BUCKET_COUNT": str(len(spec["buckets"])),
    }
    for key, value in values.items():
        print(f"{key}={shlex.quote(value)}")

    for index, bucket in enumerate(spec["buckets"]):
        print(f"BUCKET_{index}_NAME={shlex.quote(bucket['name'])}")
        print(
            f"BUCKET_{index}_VERSIONING="
            f"{shlex.quote(str(bucket.get('versioning', False)).lower())}"
        )
        print(
            f"BUCKET_{index}_OBJECT_LOCK="
            f"{shlex.quote(str(bucket.get('objectLock', False)).lower())}"
        )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["validate", "shell", "policy"])
    parser.add_argument("declaration")
    args = parser.parse_args()

    try:
        data = load_declaration(args.declaration)
        if args.command == "validate":
            print(f"valid: {data['metadata']['name']}")
        elif args.command == "shell":
            shell_output(data)
        else:
            json.dump(policy_document(data), sys.stdout, indent=2)
            print()
    except ValueError as exc:
        print(f"declaration error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
