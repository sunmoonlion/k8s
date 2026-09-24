#!/usr/bin/env python3
"""Structural diff of two rehearsal catalog snapshots (baseline.private.json vs restore-N-catalog.private.json).

Prints only catalog facts (table/column/constraint/index/trigger/ACL entries) that differ, never row data:
the catalog files hold no rows. ACL strings carry role names, not passwords. Use it to review a
`restored_catalog_mismatch` before deciding whether comparable_catalog may normalize the difference.

    python3 catalog_diff.py ~/private/x/baseline.private.json ~/private/x/restore-1-catalog.private.json
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import kind_database_rehearsal as common


def load_catalog(path: Path) -> dict:
    data = json.loads(path.read_text())
    return data["catalog"] if "catalog" in data else data


def key_of(kind: str, entry: dict) -> str:
    for candidate in (("tablename",), ("table_name", "column_name"), ("table_name", "name"),
                      ("tablename", "indexname"), ("relname",), ("creator", "schema", "kind")):
        if all(c in entry for c in candidate):
            return "/".join(str(entry[c]) for c in candidate)
    return json.dumps(entry, sort_keys=True)


def diff(baseline: dict, restored: dict) -> dict[str, dict]:
    out: dict[str, dict] = {}
    a, b = common.comparable_catalog(baseline), common.comparable_catalog(restored)
    for kind in sorted(set(a) | set(b)):
        left = {key_of(kind, e): e for e in a.get(kind, [])}
        right = {key_of(kind, e): e for e in b.get(kind, [])}
        only_left = sorted(set(left) - set(right))
        only_right = sorted(set(right) - set(left))
        changed = sorted(k for k in set(left) & set(right) if left[k] != right[k])
        if only_left or only_right or changed:
            out[kind] = {
                "only_in_baseline": {k: left[k] for k in only_left},
                "only_in_restored": {k: right[k] for k in only_right},
                "changed": {k: {"baseline": left[k], "restored": right[k]} for k in changed},
            }
    return out


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    result = diff(load_catalog(Path(argv[1])), load_catalog(Path(argv[2])))
    print(json.dumps({"differs": bool(result), "kinds": sorted(result), "detail": result},
                     indent=2, sort_keys=True, ensure_ascii=False))
    return 1 if result else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
