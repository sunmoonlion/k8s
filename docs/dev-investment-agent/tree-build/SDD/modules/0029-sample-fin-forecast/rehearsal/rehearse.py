"""K19 预演：照「财务分析与预测」清单的方法，用真数据造出「做对了」的各步交回物，
走工作台真实的计算工具与判分代码（judge + judge_numbers + expectation_met）。

用法（在 knowbench-backend/app 下）：
  PYTHONPATH=.:tests .venv/bin/python <本文件> <cells.json> <manifest.json>
"""

from __future__ import annotations

import asyncio
import json
import sys
from decimal import Decimal
from typing import Any

from test_knowbot_compute import EventRepo  # 计算记录记在内存里
from test_workbench_knowbot_data import Records, _pin, _task

from app.application.workbench.acceptance import judge
from app.application.workbench.acceptance_numbers import judge_numbers
from app.application.workbench.knowbot_compute import KnowbotCompute
from app.domain.workbench import compute as calc
from app.domain.workbench.errors import ComputeRefused
from app.domain.workbench.packs import AcceptanceRule
from app.domain.workbench.test_runs import Expectation, expectation_met

CELLS = json.load(open(sys.argv[1]))
MANIFEST = json.load(open(sys.argv[2]))
WB = MANIFEST["data_bindings"][0]["dataset_id"]
SHA = MANIFEST["data_bindings"][0]["sha256"]
BS, IS, CF, KEY = "资产负债表", "利润表", "现金流量表", "主要会计数据"
REV, COST, NP, MIN, NET = "营业收入", "营业成本", "归属于母公司股东的净利润", "少数股东损益", "净利润"
EQ_PARENT = "归属于母公司所有者权益（或股东权益）合计"
OCF = "经营活动产生的现金流量净额"


class Source:
    async def cells(self, purpose, cells):  # type: ignore[no-untyped-def]
        out = []
        for ref in cells:
            row = CELLS.get(ref["sheet"], {}).get("rows", {}).get(ref["row"])
            hit = row.get(ref["column"]) if row else None
            out.append(
                {
                    **ref,
                    "found": hit is not None,
                    "raw": hit[0] if hit else None,
                    "number": hit[1] if hit else None,
                    "version": "1",
                    "sha256": SHA,
                }
            )
        return out


def addr(sheet: str, row: str, col: str) -> str:
    return calc.address(WB, sheet, row, col)


def raw(sheet: str, row: str, col: str) -> str | None:
    hit = CELLS[sheet]["rows"].get(row, {}).get(col)
    return hit[0] if hit else None


PERIODS = CELLS[BS]["columns"]
YEARS = [p for p in PERIODS if p.endswith("12-31")]
problems: list[str] = []


async def main() -> None:
    task = _task(session_id="s1")
    pin = _pin()
    pin["manifest"]["data_bindings"] = [{"dataset_id": WB, "version": "1", "sha256": SHA}]
    records = Records(task, pin)
    records.repo = EventRepo(records.repo)
    tool = KnowbotCompute(records, Source())  # type: ignore[arg-type]

    async def c(name: str, expr: str, inputs: dict[str, Any], places: int) -> dict[str, Any] | None:
        try:
            got = await tool.compute("t", name, expr, inputs, places)
        except ComputeRefused as exc:
            problems.append(f"compute refused {name}: {exc.message}")
            return None
        return {"compute_id": got["id"], "value": got["value"]}

    steps = {s["step_id"]: s for s in MANIFEST["pack"]["workflow"]}
    out: dict[str, Any] = {}

    # ---- reconcile ----
    bs, np_, cash, opening, unbalanced, skipped = [], [], [], [], [], []
    for p in PERIODS:
        for bucket, name, expr, inputs in (
            (bs, "bs", "a - (l + e)", {"a": (BS, "资产总计"), "l": (BS, "负债合计"), "e": (BS, "所有者权益（或股东权益）合计")}),
            (np_, "np", "p + m - n", {"p": (IS, NP), "m": (IS, MIN), "n": (IS, NET)}),
            (cash, "cash", "e - (b + d)", {"e": (CF, "期末现金及现金等价物余额"), "b": (CF, "期初现金及现金等价物余额"), "d": (CF, "现金及现金等价物净增加额")}),
        ):
            if any(raw(s, r, p) is None for s, r in inputs.values()):
                skipped.append({"check": name, "period": p, "why": "cell empty"})
                continue
            r = await c(f"{name} {p}", expr, {k: addr(s, row, p) for k, (s, row) in inputs.items()}, 2)
            if r:
                ok = abs(Decimal(r["value"])) <= 1
                bucket.append({"period": p, **r, "balanced": ok})
                if not ok:
                    unbalanced.append({"check": name, "period": p, "value": r["value"]})
    for prev, cur in zip(YEARS, YEARS[1:]):
        r = await c(f"opening {cur}", "o - c", {"o": addr(CF, "期初现金及现金等价物余额", cur), "c": addr(CF, "期末现金及现金等价物余额", prev)}, 2)
        if r:
            ok = abs(Decimal(r["value"])) <= 1
            opening.append({"period": cur, **r, "balanced": ok})
            if not ok:
                unbalanced.append({"check": "opening", "period": cur, "value": r["value"]})
    out["reconcile"] = {"bs_check": bs, "np_check": np_, "cash_check": cash, "opening_check": opening,
                        "unbalanced": unbalanced, "excluded_periods": sorted({u["period"] for u in unbalanced}),
                        "skipped": skipped, "note": ""}

    # ---- series ----
    quarters = [p for p in PERIODS]
    single: dict[str, dict[str, str]] = {REV: {}, NP: {}}  # period -> address or compute id
    q1, derived = [], []
    for item in (REV, NP):
        for p in quarters:
            if p.endswith("03-31"):
                q1.append({"item": item, "period": p, "address": addr(IS, item, p), "value": raw(IS, item, p)})
                single[item][p] = addr(IS, item, p)
            else:
                prev = quarters[quarters.index(p) - 1]
                r = await c(f"{item} {p} single", "cum - prev", {"cum": addr(IS, item, p), "prev": addr(IS, item, prev)}, 2)
                if r:
                    derived.append({"item": item, "period": p, **r})
                    single[item][p] = r["compute_id"]
    out["series"] = {"q1": q1, "derived": derived, "note": ""}

    # ---- indicators ----
    ind: dict[str, list] = {k: [] for k in ("gross_margin", "net_margin", "roe", "cash_ratio", "revenue_growth", "profit_growth")}
    na: list[dict[str, str]] = []
    for i, y in enumerate(YEARS):
        for key, expr, inputs in (
            ("gross_margin", "(rev - cost) / rev", {"rev": addr(IS, REV, y), "cost": addr(IS, COST, y)}),
            ("net_margin", "np / rev", {"np": addr(IS, NP, y), "rev": addr(IS, REV, y)}),
            ("cash_ratio", "ocf / np", {"ocf": addr(CF, OCF, y), "np": addr(IS, NP, y)}),
        ):
            r = await c(f"{key} {y}", expr, inputs, 4)
            if r:
                ind[key].append({"period": y, **r})
        if i == 0:
            na.append({"indicator": "roe", "period": y, "reason": "第一年没有期初"})
            continue
        prev = YEARS[i - 1]
        if raw(BS, EQ_PARENT, y) is None or raw(BS, EQ_PARENT, prev) is None:
            na.append({"indicator": "roe", "period": y, "reason": "归母净资产缺数"})
        else:
            r = await c(f"roe {y}", "np / ((open + close) / 2)", {"np": addr(IS, NP, y), "open": addr(BS, EQ_PARENT, prev), "close": addr(BS, EQ_PARENT, y)}, 4)
            if r:
                ind["roe"].append({"period": y, **r})
        for key, item in (("revenue_growth", REV), ("profit_growth", NP)):
            r = await c(f"{key} {y}", "(cur - prev) / prev", {"cur": addr(IS, item, y), "prev": addr(IS, item, prev)}, 4)
            if r:
                ind[key].append({"period": y, **r})
    values = [{"item": item, "period": y, "address": addr(IS, item, y), "value": raw(IS, item, y)} for item in (REV, NP) for y in YEARS]
    out["indicators"] = {**ind, "values": values, "not_applicable": na, "not_available": [],
                         "findings": ["营业收入从 2021 年到 2025 年逐年上升。"], "note": ""}

    # ---- official ----
    pairs = ((REV, IS, REV, "营业收入"), ("归母净利润", IS, NP, "归属于上市公司股东的净利润"),
             ("扣非净利润", IS, "扣除非经常性损益后的归属于母公司股东的净利润", "归属于上市公司股东的扣除非经常性损益的净利润"),
             ("经营现金流", CF, OCF, "经营活动产生的现金流量净额"))
    diffs, official_values, mismatches = [], [], []
    for y in YEARS:
        for item, sheet, ours, official in pairs:
            r = await c(f"diff {item} {y}", "(ours - official) / official", {"ours": addr(sheet, ours, y), "official": addr(KEY, official, y)}, 6)
            if r:
                ok = abs(Decimal(r["value"])) <= Decimal("0.001")
                diffs.append({"item": item, "year": y[:4], **r, "matches": ok})
                if not ok:
                    mismatches.append({"item": item, "year": y[:4], "ours": raw(sheet, ours, y), "official": raw(KEY, official, y)})
            official_values.append({"item": item, "year": y[:4], "address": addr(KEY, official, y), "value": raw(KEY, official, y)})
    out["official"] = {"copy_checks": [], "official_values": official_values, "diffs": diffs, "roe_pairs": [],
                       "mismatches": mismatches,
                       "official_by_year": {y[:4]: {"revenue": raw(KEY, "营业收入", y)} for y in YEARS}, "note": ""}

    # ---- forecast (horizon 2) ----
    yoy_ids: dict[str, list[tuple[str, str]]] = {REV: [], NP: []}
    fc = {"yoy": [], "rates": [], "forecasts": [], "backtest": [], "errors": [], "mean_errors": []}
    for item in (REV, NP):
        ser = single[item]
        for p in quarters:
            ly = str(int(p[:4]) - 1) + p[4:]
            if ly in ser:
                r = await c(f"yoy {item} {p}", "(cur - prev) / prev", {"cur": ser[p], "prev": ser[ly]}, 6)
                if r:
                    fc["yoy"].append({"item": item, "period": p, **r})
                    yoy_ids[item].append((p, r["compute_id"]))
        ids = [i for _, i in yoy_ids[item]]
        rates = {}
        for kind, expr, xs in (("median", "median(g)", ids[-4:]), ("min", "min(g)", ids[-8:]), ("max", "max(g)", ids[-8:])):
            r = await c(f"{kind} {item}", expr, {"g": xs}, 6)
            if r:
                fc["rates"].append({"item": item, "kind": kind, "for_period": "next", **r})
                rates[kind] = r["compute_id"]
        for target in ("2026-09-30", "2026-12-31"):
            base = ser[str(int(target[:4]) - 1) + target[4:]]
            for kind, rk in (("point", "median"), ("low", "min"), ("high", "max")):
                r = await c(f"fc {item} {target} {kind}", "base * (1 + g)", {"base": base, "g": rates[rk]}, 2)
                if r:
                    fc["forecasts"].append({"item": item, "period": target, "kind": kind, **r})
        errs = []
        for t in quarters[-4:]:
            before = [i for p, i in yoy_ids[item] if p < t]
            med = await c(f"bt median {item} {t}", "median(g)", {"g": before[-4:]}, 6)
            lo = await c(f"bt min {item} {t}", "min(g)", {"g": before[-8:]}, 6)
            hi = await c(f"bt max {item} {t}", "max(g)", {"g": before[-8:]}, 6)
            for kind, rr in (("median", med), ("min", lo), ("max", hi)):
                if rr:
                    fc["rates"].append({"item": item, "kind": kind, "for_period": t, **rr})
            base = ser[str(int(t[:4]) - 1) + t[4:]]
            preds = {}
            for kind, rr in (("point", med), ("low", lo), ("high", hi)):
                r = await c(f"bt {item} {t} {kind}", "base * (1 + g)", {"base": base, "g": rr["compute_id"]}, 2)
                if r:
                    fc["backtest"].append({"item": item, "period": t, "kind": kind, **r})
                    preds[kind] = r
            e = await c(f"err {item} {t}", "abs(pred - actual) / actual", {"pred": preds["point"]["compute_id"], "actual": ser[t]}, 6)
            if e:
                fc["errors"].append({"item": item, "period": t, **e, "in_range": True})
                errs.append(e["compute_id"])
        m = await c(f"mean err {item}", "avg(e)", {"e": errs}, 6)
        if m:
            fc["mean_errors"].append({"item": item, **m})
    out["forecast"] = {**fc, "horizon": 2, "assumptions": ["近期增速延续", "没有重大口径或业务变化"], "note": ""}

    # ---- judge every step ----
    owner_task = {**records.task, "owner_actor_id": records.owner}
    for sid, artifact in out.items():
        rules = tuple(AcceptanceRule.model_validate(a) for a in steps[sid]["acceptance"])
        text = json.dumps(artifact, ensure_ascii=False)
        v = await judge_numbers(judge(text, rules), rules, repo=records.repo, task=owner_task, source=Source())  # type: ignore[arg-type]
        bad = [ch for ch in v.checks if ch.get("pass") is False]
        print(f"{sid:11s} {'PASS' if v.ok else 'FAIL'}  checks={len(v.checks)}", "" if v.ok else bad)
    # ---- expectations of case c1 ----
    for e in ({"artifact": "official", "path": "official_by_year.2024.revenue", "kind": "approx", "value": 170899152276.34, "tolerance": 0.001},
              {"artifact": "forecast", "path": "horizon", "kind": "equals", "value": "2"}):
        print("expect", e["path"], expectation_met(Expectation.model_validate(e), out))
    print("computations", len(records.repo.events), "| problems:", problems or "none")
    print("unbalanced", out["reconcile"]["unbalanced"], "| roe n/a", [n for n in na if n["indicator"] == "roe"])
    print("mismatches", out["official"]["mismatches"])
    print("forecast REV", [(f["period"], f["kind"], f["value"]) for f in fc["forecasts"] if f["item"] == REV])
    print("mean errors", [(m["item"], m["value"]) for m in fc["mean_errors"]])
    import os
    if os.environ.get("DUMP"):
        json.dump(out, open(os.environ["DUMP"], "w"), ensure_ascii=False, indent=1)


asyncio.run(main())
