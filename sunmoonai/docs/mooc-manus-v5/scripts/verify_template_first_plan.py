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
    unified_frontend_adr = require(
        docs / "mooc-manus-v5/adr/ADR-018-unified-next-frontend-surfaces.md",
        "状态：ACCEPTED",
        "P0-007D React Admin Legacy Closure + 原子改名",
        "P0-007E Next Admin Template + FastAPI Admin Pair",
        "P0-007D/E 插入后，B6 不再是当前立即任务",
        "tpl-admin-frontend-react",
    )
    plan = require(
        docs / "mooc-manus-langgraph-v5-implementation-plan.md",
        "### V5-P0-007D React Router Admin Legacy 最终配对与原子改名",
        "### V5-P0-007E Next Admin 默认模板与 FastAPI Admin 配对",
        "P0-007D（`ACCEPTED`，2026-07-28）",
        "P0-007E（`ACCEPTED`，2026-07-28）",
        "### V5-P0-009 统一模板发布与三实例立即收敛 Rollup",
        "P0-009A_ACCEPTED",
        "P0-009D_ACCEPTED",
        "P0-009E_ACCEPTED",
        "### V5-M1-411A 固定模板替换三个 App 基础前端",
        "状态：SUPERSEDED_BY_P0_009",
        "B6.1 Frontend Common Kernel Parity Gate",
        "B6.2 Vue Legacy Intake + Admin Pair Gate",
        "B6.3 Dual Web Profile Contract/Paired Gate",
        "B6.4 Unified Release/Clean-room Gate",
        "组件能力补齐与配对是两个门",
        "P0-009E -> P0-008C",
        "唯一下一任务是 P0-008C",
    )
    long_term = require(
        docs / "mooc-manus-langgraph-longterm-plan-v5.md",
        "最近修订：2026-07-29（P0-009E 经 Codex fail-closed 独立复验接受；下一任务 P0-008C）",
        "当前唯一任务是 P0-008C",
        "P0-009 全部通过前不得继续新增业务功能",
        "tpl-app/tpl-admin-frontend-vue",
        "组件能力门与 Frontend/Backend 真实配对门",
        "INSTANCE_FOUNDATION_ALIGNED",
    )
    handoff = require(
        docs / "mooc-manus-langgraph-v5-handoff-20260712.md",
        "P0-007D = ACCEPTED",
        "P0-007E = ACCEPTED",
        "P0-008B = ACCEPTED / B6_ACCEPTED",
        "P0-009  = ACCEPTED / P0-009A_ACCEPTED / P0-009B_ACCEPTED / P0-009C_ACCEPTED / P0-009D_ACCEPTED / P0-009E_ACCEPTED",
        "唯一下一任务是 P0-008C",
        "B6.1 Frontend Common Kernel Parity",
        "B6.2 Vue Legacy Intake + Admin Pair",
        "B6.3 Dual Web Profile Pair",
        "B6.4 Unified Release/Clean-room",
        "B6 后立即激活 P0-009A",
        "V5-P0-009E",
    )
    legacy_evidence = require(
        docs / "evidence/v5/V5-P0-007D/result.md",
        "状态：`ACCEPTED`",
        "tpl-admin-frontend-react",
        "0b58adc4035d2b695646b0700dfc2fb707d14b57",
        "a280ea2eed40d2eb262e428918961299490e2026",
        "P0-007E",
    )
    next_admin_evidence = require(
        docs / "evidence/v5/V5-P0-007E/result.md",
        "状态：`ACCEPTED`",
        "fb69795b04e0b888a2917c3936f7f80aeac79cc9",
        "69e634b8e5b06da9d1dcd01c9b1350e0571d74bd",
        "7089e191b10d4ff33109691cf5e5e1b7f0dd8efe",
        "P0-008B/B6",
    )

    stale_current_statements = (
        "Gate P0 后依次执行 M1-411A",
        "B6（双实现门禁） -> P0-008C",
        "Gate P0 后在现有 App 仓库内按冻结 commit",
    )
    for name, text in (
        ("ADR-017", adr),
        ("ADR-018", unified_frontend_adr),
        ("implementation plan", plan),
        ("v5", long_term),
        ("handoff", handoff),
        ("P0-007D evidence", legacy_evidence),
        ("P0-007E evidence", next_admin_evidence),
    ):
        stale = [item for item in stale_current_statements if item in text]
        if stale:
            raise AssertionError(f"{name} still contains superseded order: {stale}")

    print(
        json.dumps(
            {
                "task": "V5-PLAN-TEMPLATE-FIRST",
                "result": "passed",
                "decision": "ADR-017+ADR-018",
                "legacy_closure": "P0-007D_ACCEPTED",
                "next_admin": "P0-007E_ACCEPTED",
                "current_code_task": "P0-008C",
                "b6_order": [
                    "frontend-common-kernel",
                    "vue-admin-fastapi-admin-reference-pair",
                    "next-web-dual-backend-pair",
                    "unified-clean-room-release",
                ],
                "p0_009a": "ACCEPTED",
                "p0_009c": "ACCEPTED",
                "p0_009d": "ACCEPTED",
                "p0_009e": "ACCEPTED",
                "p0_009": "ACCEPTED",
                "next_after_template_release": "P0-008C",
                "instance_order": ["info", "knowledge", "research"],
                "business_development_locked_until": "P0-008C_ACCEPTED",
            },
            ensure_ascii=False,
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
