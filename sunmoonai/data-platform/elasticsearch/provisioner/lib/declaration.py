#!/usr/bin/env python3

import argparse
import json
import re
import shlex
import sys
from pathlib import Path


DNS_LABEL = re.compile(r"^[a-z0-9]([-a-z0-9]*[a-z0-9])?$")
DATASET_NAME = re.compile(r"^[a-z0-9]([-a-z0-9]*[a-z0-9])?$")
ALLOWED_PERMISSIONS = {"read", "write"}


def fail(message):
    raise ValueError(message)


def load(path):
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"cannot read declaration: {exc}")

    if data.get("apiVersion") != "search.sunmoonai.com/v1alpha1":
        fail("apiVersion must be search.sunmoonai.com/v1alpha1")
    if data.get("kind") != "ElasticsearchAccess":
        fail("kind must be ElasticsearchAccess")

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
        "datasets",
    )
    missing = [key for key in required if key not in spec]
    if missing:
        fail(f"missing spec fields: {', '.join(missing)}")
    if spec["provider"] != "platform-elasticsearch":
        fail("spec.provider must be platform-elasticsearch")
    if spec["environment"] not in {"development", "staging", "production"}:
        fail("unsupported environment")

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

    datasets = spec["datasets"]
    if not isinstance(datasets, list) or not datasets:
        fail("spec.datasets must contain at least one dataset")

    seen = set()
    for index, dataset in enumerate(datasets):
        if not isinstance(dataset, dict):
            fail(f"dataset {index} must be an object")
        name = dataset.get("name")
        if not isinstance(name, str) or not DATASET_NAME.fullmatch(name):
            fail(f"dataset {index} has an invalid name")
        if name in seen:
            fail(f"duplicate dataset: {name}")
        seen.add(name)

        schema_version = dataset.get("schemaVersion")
        if not isinstance(schema_version, int) or schema_version < 1:
            fail(f"dataset {name}: schemaVersion must be a positive integer")
        permissions = dataset.get("permissions")
        if not isinstance(permissions, list) or not permissions:
            fail(f"dataset {name}: permissions are required")
        unknown = set(permissions) - ALLOWED_PERMISSIONS
        if unknown:
            fail(f"dataset {name}: unsupported permissions: {sorted(unknown)}")
        if len(permissions) != len(set(permissions)):
            fail(f"dataset {name}: duplicate permissions")

        for field in ("settings", "mappings"):
            value = dataset.get(field, {})
            if not isinstance(value, dict):
                fail(f"dataset {name}: {field} must be an object")

    return data


def names(data, dataset):
    spec = data["spec"]
    prefix = f"{spec['environment']}-{spec['app']}-{dataset['name']}"
    return {
        "prefix": prefix,
        "template": prefix,
        "physical": f"{prefix}-v{dataset['schemaVersion']}-000001",
        "read_alias": f"{prefix}-read",
        "write_alias": f"{prefix}-write",
    }


def shell_output(data):
    spec = data["spec"]
    values = {
        "DECLARATION_NAME": data["metadata"]["name"],
        "APP_NAME": spec["app"],
        "BACKEND_NAME": spec["backend"],
        "TARGET_NAMESPACE": spec["namespace"],
        "TARGET_SECRET_NAME": spec["secretName"],
        "TARGET_CONFIGMAP_NAME": spec["configMapName"],
        "ES_USERNAME": data["metadata"]["name"],
        "ES_ROLE_NAME": f"{spec['environment']}-{spec['app']}-{spec['backend']}-search",
        "DATASET_COUNT": str(len(spec["datasets"])),
    }
    for key, value in values.items():
        print(f"{key}={shlex.quote(value)}")
    for index, dataset in enumerate(spec["datasets"]):
        resource_names = names(data, dataset)
        print(f"DATASET_{index}_NAME={shlex.quote(dataset['name'])}")
        for key, value in resource_names.items():
            print(f"DATASET_{index}_{key.upper()}={shlex.quote(value)}")


def render(data, directory):
    output = Path(directory)
    output.mkdir(parents=True, exist_ok=True)
    role_indices = []
    aliases = {}

    for index, dataset in enumerate(data["spec"]["datasets"]):
        resource_names = names(data, dataset)
        permissions = set(dataset["permissions"])
        index_privileges = ["view_index_metadata"]
        if "read" in permissions:
            index_privileges.extend(["read", "monitor"])
        if "write" in permissions:
            index_privileges.extend(["create_index", "create", "index", "write"])

        allowed_names = []
        if "read" in permissions:
            allowed_names.append(resource_names["read_alias"])
        if "write" in permissions:
            allowed_names.append(resource_names["write_alias"])
        role_indices.append(
            {
                "names": allowed_names,
                "privileges": sorted(set(index_privileges)),
                "allow_restricted_indices": False,
            }
        )

        template = {
            "index_patterns": [f"{resource_names['prefix']}-v*-*"],
            "priority": 100,
            "template": {
                "settings": {
                    "number_of_shards": 1,
                    "number_of_replicas": 0,
                    **dataset.get("settings", {}),
                },
                "mappings": dataset.get("mappings", {}),
            },
            "_meta": {
                "managed_by": "sunmoonai-elasticsearch-provisioner",
                "app": data["spec"]["app"],
                "backend": data["spec"]["backend"],
                "dataset": dataset["name"],
                "schema_version": dataset["schemaVersion"],
            },
        }
        initial_index = {
            "aliases": {
                resource_names["read_alias"]: {},
                resource_names["write_alias"]: {"is_write_index": True},
            }
        }
        (output / f"template-{index}.json").write_text(
            json.dumps(template, indent=2) + "\n", encoding="utf-8"
        )
        (output / f"index-{index}.json").write_text(
            json.dumps(initial_index, indent=2) + "\n", encoding="utf-8"
        )
        aliases[dataset["name"]] = {
            "read": resource_names["read_alias"],
            "write": resource_names["write_alias"],
        }

    role = {
        "cluster": [],
        "indices": role_indices,
        "applications": [],
        "run_as": [],
        "metadata": {
            "managed_by": "sunmoonai-elasticsearch-provisioner",
            "app": data["spec"]["app"],
            "backend": data["spec"]["backend"],
        },
    }
    (output / "role.json").write_text(
        json.dumps(role, indent=2) + "\n", encoding="utf-8"
    )
    (output / "aliases.json").write_text(
        json.dumps(aliases, separators=(",", ":")) + "\n", encoding="utf-8"
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["validate", "shell", "render"])
    parser.add_argument("declaration")
    parser.add_argument("output", nargs="?")
    args = parser.parse_args()

    try:
        data = load(args.declaration)
        if args.command == "validate":
            print(f"valid: {data['metadata']['name']}")
        elif args.command == "shell":
            shell_output(data)
        else:
            if not args.output:
                fail("render requires an output directory")
            render(data, args.output)
    except ValueError as exc:
        print(f"declaration error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
