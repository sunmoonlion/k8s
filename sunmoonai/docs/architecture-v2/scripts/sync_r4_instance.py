#!/usr/bin/env python3
"""Three-way sync one Architecture v2 template component into one instance.

The instance is compared against the exact template revision from which its
common base was derived. Template and instance changes are merged, while every
instance-owned difference must be classified explicitly.
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import os
import stat
import subprocess
import sys
import tempfile
from pathlib import Path


class SyncError(RuntimeError):
    pass


def git(repo: Path, *args: str, check: bool = True) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        ["git", *args], cwd=repo, check=check, capture_output=True
    )


def revision_files(repo: Path, revision: str) -> dict[str, str]:
    output = git(repo, "ls-tree", "-r", revision).stdout.decode()
    result: dict[str, str] = {}
    for line in output.splitlines():
        metadata, path = line.split("\t", 1)
        mode, _kind, _object_id = metadata.split()
        result[path] = mode
    return result


def revision_blob(repo: Path, revision: str, path: str) -> bytes:
    return git(repo, "show", f"{revision}:{path}").stdout


def instance_files(repo: Path) -> dict[str, str]:
    return revision_files(repo, "HEAD")


def instantiate(
    content: bytes,
    substitutions: list[dict[str, str]],
    path: str,
) -> bytes:
    try:
        value = content.decode("utf-8")
    except UnicodeDecodeError:
        return content
    for substitution in substitutions:
        if substitution.get("glob") and not fnmatch.fnmatchcase(
            path, substitution["glob"]
        ):
            continue
        value = value.replace(substitution["from"], substitution["to"])
    return value.encode("utf-8")


def is_text(*values: bytes) -> bool:
    for value in values:
        if b"\0" in value:
            return False
        try:
            value.decode("utf-8")
        except UnicodeDecodeError:
            return False
    return True


def merge_text(local: bytes, base: bytes, target: bytes) -> tuple[bytes, bool]:
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        paths = [root / name for name in ("local", "base", "target")]
        for path, content in zip(paths, (local, base, target), strict=True):
            path.write_bytes(content)
        result = subprocess.run(
            ["git", "merge-file", "-p", "--diff3", *(str(path) for path in paths)],
            check=False,
            capture_output=True,
        )
        if result.returncode < 0 or result.returncode > 127:
            raise SyncError(result.stderr.decode(errors="replace"))
        return result.stdout, result.returncode != 0


def matching_rule(path: str, rules: list[dict[str, str]]) -> dict[str, str] | None:
    for rule in rules:
        if fnmatch.fnmatchcase(path, rule["glob"]):
            return rule
    return None


def classify(path: str, rules: list[dict[str, str]]) -> str | None:
    rule = matching_rule(path, rules)
    return rule["class"] if rule else None


def operation_with_rule(
    path: str,
    action: str,
    rule: dict[str, str],
) -> dict[str, object]:
    operation: dict[str, object] = {
        "path": path,
        "action": action,
        "class": rule["class"],
    }
    for key in ("strategy", "reason", "owner", "deadline"):
        if value := rule.get(key):
            operation[key] = value
    return operation


def write_path(path: Path, content: bytes, mode: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_symlink() or path.exists():
        path.unlink()
    if mode == "120000":
        os.symlink(content.decode(), path)
        return
    path.write_bytes(content)
    permissions = path.stat().st_mode
    if mode == "100755":
        path.chmod(permissions | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    else:
        path.chmod(permissions & ~(stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("plan", "apply"))
    parser.add_argument("--template-repo", type=Path, required=True)
    parser.add_argument("--base-revision", required=True)
    parser.add_argument("--target-revision", required=True)
    parser.add_argument("--instance-repo", type=Path, required=True)
    parser.add_argument("--expected-instance-commit", required=True)
    parser.add_argument("--app", required=True)
    parser.add_argument("--component", required=True)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--report", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    template = args.template_repo.resolve()
    instance = args.instance_repo.resolve()
    try:
        if git(instance, "status", "--porcelain").stdout:
            raise SyncError("instance repository must be clean")
        actual_head = git(instance, "rev-parse", "HEAD").stdout.decode().strip()
        if actual_head != args.expected_instance_commit:
            raise SyncError(
                f"instance HEAD mismatch expected={args.expected_instance_commit} actual={actual_head}"
            )
        git(template, "cat-file", "-e", f"{args.base_revision}^{{commit}}")
        git(template, "cat-file", "-e", f"{args.target_revision}^{{commit}}")
        config = json.loads(args.config.read_text(encoding="utf-8"))
        component_config = config["components"][args.component]
        substitutions = component_config.get("substitutions", [])
        if any(
            not item.get("from")
            or item.get("to") is None
            or item["from"] == item["to"]
            for item in substitutions
        ):
            raise SyncError("substitutions must have distinct non-empty from/to values")
        if len(
            {(item.get("glob", "*"), item["from"]) for item in substitutions}
        ) != len(substitutions):
            raise SyncError("substitutions contain duplicate source values")
        rules = component_config.get("classifications", [])
        remove = set(component_config.get("remove", []))
        skip_template = component_config.get("skip_template", [])
        resolutions = component_config.get("resolutions", [])
        allowed_classes = {
            "domain-extension",
            "deployment-config",
            "temporary-compatibility",
        }
        classified_rules = [*rules, *skip_template]
        classified_rules.extend(
            rule for rule in resolutions if rule.get("strategy") == "local"
        )
        if any(rule.get("class") not in allowed_classes for rule in classified_rules):
            raise SyncError("classification config contains an unsupported class")
        allowed_strategies = {"target", "local", "merge"}
        if any(rule.get("strategy") not in allowed_strategies for rule in resolutions):
            raise SyncError("resolution config contains an unsupported strategy")
        if any(not rule.get("reason") for rule in [*skip_template, *resolutions]):
            raise SyncError("skip/resolution rules must include a reason")
        if any(
            rule.get("class") == "temporary-compatibility"
            and (not rule.get("owner") or not rule.get("deadline"))
            for rule in [*rules, *skip_template, *resolutions]
        ):
            raise SyncError(
                "temporary-compatibility rules must include owner and deadline"
            )

        base_files = revision_files(template, args.base_revision)
        target_files = revision_files(template, args.target_revision)
        local_files = instance_files(instance)
        operations: list[dict[str, object]] = []
        writes: dict[str, tuple[bytes, str]] = {}
        deletes: set[str] = set()
        prohibited: list[str] = []

        for path in sorted(set(base_files) | set(target_files)):
            in_base = path in base_files
            in_target = path in target_files
            in_local = path in local_files
            base = instantiate(
                revision_blob(template, args.base_revision, path), substitutions, path
            ) if in_base else None
            target = instantiate(
                revision_blob(template, args.target_revision, path), substitutions, path
            ) if in_target else None
            local = (instance / path).read_bytes() if in_local else None

            skip_rule = matching_rule(path, skip_template)
            if skip_rule:
                operations.append(
                    operation_with_rule(path, "skip-template", skip_rule)
                )
                continue

            resolution = matching_rule(path, resolutions)
            if resolution:
                strategy = resolution["strategy"]
                if strategy == "target":
                    if in_target:
                        writes[path] = (target, target_files[path])
                        operations.append(
                            operation_with_rule(
                                path,
                                "resolve-target",
                                {**resolution, "class": "common-template"},
                            )
                        )
                    else:
                        deletes.add(path)
                        operations.append(
                            operation_with_rule(
                                path,
                                "resolve-target-deletion",
                                {**resolution, "class": "common-template"},
                            )
                        )
                    continue
                if strategy == "local":
                    operations.append(
                        operation_with_rule(path, "resolve-local", resolution)
                    )
                    continue
                # The merge strategy intentionally falls through to the normal
                # three-way merge. It documents that a non-conflicting merge is
                # expected but never suppresses a real conflict.

            if in_target and not in_base:
                if not in_local:
                    writes[path] = (target, target_files[path])
                    operations.append({"path": path, "action": "add-common"})
                elif local == target:
                    operations.append({"path": path, "action": "already-current"})
                else:
                    prohibited.append(path)
                    operations.append({"path": path, "action": "new-path-collision", "class": "prohibited-drift"})
                continue

            if in_base and not in_target:
                if not in_local:
                    operations.append({"path": path, "action": "already-absent"})
                elif local == base or path in remove:
                    deletes.add(path)
                    operations.append({"path": path, "action": "remove-obsolete-common"})
                else:
                    category = classify(path, rules)
                    if category:
                        operations.append({"path": path, "action": "preserve-template-deleted-local", "class": category})
                    else:
                        prohibited.append(path)
                        operations.append({"path": path, "action": "modified-template-deletion", "class": "prohibited-drift"})
                continue

            if not in_local:
                prohibited.append(path)
                operations.append({"path": path, "action": "missing-common", "class": "prohibited-drift"})
                continue
            if local == target:
                operations.append({"path": path, "action": "already-current"})
                continue
            if local == base:
                writes[path] = (target, target_files[path])
                operations.append({"path": path, "action": "update-common"})
                continue
            if target == base:
                category = classify(path, rules)
                if category:
                    operations.append({"path": path, "action": "preserve-local", "class": category})
                else:
                    prohibited.append(path)
                    operations.append({"path": path, "action": "unclassified-local-change", "class": "prohibited-drift"})
                continue
            if not is_text(local, base, target):
                prohibited.append(path)
                operations.append({"path": path, "action": "binary-conflict", "class": "prohibited-drift"})
                continue
            merged, conflict = merge_text(local, base, target)
            if conflict:
                prohibited.append(path)
                operations.append({"path": path, "action": "merge-conflict", "class": "prohibited-drift"})
                continue
            category = classify(path, rules)
            if merged != target and category is None:
                prohibited.append(path)
                operations.append({"path": path, "action": "unclassified-merged-change", "class": "prohibited-drift"})
                continue
            writes[path] = (merged, target_files[path])
            operation: dict[str, object] = {"path": path, "action": "merge-common"}
            if category:
                operation["class"] = category
            if resolution:
                operation["strategy"] = "merge"
                operation["reason"] = resolution["reason"]
            operations.append(operation)

        for path in sorted(set(local_files) - set(base_files)):
            if path in target_files:
                continue
            if path in remove:
                deletes.add(path)
                operations.append({"path": path, "action": "remove-instance-obsolete"})
                continue
            category = classify(path, rules)
            if category:
                operations.append({"path": path, "action": "preserve-instance", "class": category})
            else:
                prohibited.append(path)
                operations.append({"path": path, "action": "unclassified-instance", "class": "prohibited-drift"})

        summary: dict[str, object] = {
            "task": "architecture-v2-r4-component-sync",
            "action": args.action,
            "result": "passed" if not prohibited else "needs-resolution",
            "app": args.app,
            "component": args.component,
            "base_revision": args.base_revision,
            "target_revision": args.target_revision,
            "instance_commit": actual_head,
            "writes": len(writes),
            "deletes": len(deletes),
            "prohibited_drift": sorted(set(prohibited)),
            "prohibited_drift_count": len(set(prohibited)),
            "operations": operations,
        }
        rendered = json.dumps(summary, ensure_ascii=False, indent=2) + "\n"
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(rendered, encoding="utf-8")
        print(rendered, end="")
        if prohibited:
            return 1
        if args.action == "apply":
            for path in sorted(deletes):
                target_path = instance / path
                if target_path.is_symlink() or target_path.exists():
                    target_path.unlink()
            for path, (content, mode) in writes.items():
                write_path(instance / path, content, mode)
        return 0
    except (OSError, ValueError, KeyError, SyncError, subprocess.SubprocessError) as exc:
        print(
            json.dumps(
                {
                    "task": "architecture-v2-r4-component-sync",
                    "result": "failed",
                    "error": str(exc),
                },
                ensure_ascii=False,
            ),
            file=sys.stderr,
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
