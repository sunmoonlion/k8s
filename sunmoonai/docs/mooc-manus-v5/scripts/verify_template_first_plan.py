#!/usr/bin/env python3
"""Verify the accepted template-first execution order without touching runtime state."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def require(path: Path, *needles: str) -> str:
    text = path.read_text()
    missing = [needle for needle in needles if needle not in text]
    if missing:
        raise AssertionError(f"{path} is missing accepted plan statements: {missing}")
    return text


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--k8s",
        type=Path,
        default=Path.home() / "k8s",
        help="Path to the k8s repository",
    )
    return parser.parse_args()


def main() -> None:
    k8s = parse_args().k8s.resolve()
    docs = k8s / "sunmoonai/docs"

    adr = require(
        docs / "mooc-manus-v5/adr/ADR-017-template-first-instance-adoption.md",
        "状态：ACCEPTED",
        "P0-009A：",
        "P0-009B：Info",
        "P0-009C：Knowledge",
        "P0-009D：Research",
        "P0-009E：",
        "INSTANCE_FOUNDATION_ALIGNED",
        "SUPERSEDED_BY_P0_009",
    )
    plan = require(
        docs / "mooc-manus-langgraph-v5-implementation-plan.md",
        "### V5-P0-009 统一模板发布与三实例立即收敛 Rollup",
        "NOT_STARTED / BLOCKED_BY_P0_008B_B6",
        "### V5-M1-411A 固定模板替换三个 App 基础前端",
        "状态：SUPERSEDED_BY_P0_009",
        "B6 是唯一下一任务",
        "P0-009E -> P0-008C",
    )
    long_term = require(
        docs / "mooc-manus-langgraph-longterm-plan-v5.md",
        "最近修订：2026-07-26（P0-008B/B5 FastAPI 通用内核与默认 Web BFF 固定）",
        "P0-009 全部通过前不得继续新增业务功能",
        "INSTANCE_FOUNDATION_ALIGNED",
    )
    handoff = require(
        docs / "mooc-manus-langgraph-v5-handoff-20260712.md",
        "P0-008B = IN_PROGRESS / B5_ACCEPTED / B6_NEXT",
        "P0-009  = NOT_STARTED / BLOCKED_BY_P0_008B_B6",
        "唯一下一任务是 B6",
        "B6 后立即激活 P0-009A",
    )

    stale_current_statements = (
        "Gate P0 后依次执行 M1-411A",
        "B6（双实现门禁） -> P0-008C",
        "Gate P0 后在现有 App 仓库内按冻结 commit",
    )
    for name, text in (
        ("ADR-017", adr),
        ("implementation plan", plan),
        ("v5", long_term),
        ("handoff", handoff),
    ):
        stale = [item for item in stale_current_statements if item in text]
        if stale:
            raise AssertionError(f"{name} still contains superseded order: {stale}")

    print(
        json.dumps(
            {
                "task": "V5-PLAN-TEMPLATE-FIRST",
                "result": "passed",
                "decision": "ADR-017",
                "current_code_task": "P0-008B/B6",
                "next_after_template_release": "P0-009A",
                "instance_order": ["info", "knowledge", "research"],
                "business_development_locked_until": "P0-009E_ACCEPTED",
            },
            ensure_ascii=False,
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
