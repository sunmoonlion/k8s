"""K19 预演：照「财务分析与预测」清单的方法，用真数据造出「做对了」的各步交回物，
走工作台真实的计算工具与判分代码（judge + judge_numbers + expectation_met）。

用法（在 knowbench-backend/app 下）：
  PYTHONPATH=.:tests .venv/bin/python <本文件> <cells.json> <manifest.json> [<pages.json> <map.json>]
第 3 稿的第 6 步（对照管理层讨论）要后两个：pages.json、map.json 见同目录 quotes.py；核引文时
调 knowlab 真实的找原话代码（quotes.py find，环境变量 KNOWLAB_APP 指 knowlab-backend/app）。
"""

from __future__ import annotations

import asyncio
import json
import os
import subprocess
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
PAGES = json.load(open(sys.argv[3])) if len(sys.argv) > 4 else {}
PDF_MAP = sys.argv[4] if len(sys.argv) > 4 else ""
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

    async def quotes(self, purpose, quotes):  # type: ignore[no-untyped-def]
        here = os.path.dirname(os.path.abspath(__file__))
        app = os.environ["KNOWLAB_APP"]
        done = subprocess.run(
            [f"{app}/.venv/bin/python", f"{here}/quotes.py", "find", PDF_MAP],
            input=json.dumps(quotes), capture_output=True, text=True, check=True,
            cwd=app, env={**os.environ, "PYTHONPATH": "."},
        )
        return json.loads(done.stdout)


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
    pin["manifest"]["data_bindings"] = MANIFEST["data_bindings"]
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

    # ---- official（第 3 稿：分析结论对照管理层讨论，SDD 0036） ----
    years = {"35da3157-7472-4404-b7f7-fd4eb8128839": "2021", "538285ed-c604-4110-9160-bfdd0ed4d262": "2022",
             "f4703e18-4db5-4bb6-870f-efec5dd0ddac": "2023", "3103d049-ec3f-452b-9a2b-56748cd6efe0": "2024",
             "d1bfb7a8-6a24-47da-a2d1-7cc3e7859e4a": "2025"}
    r2024, r2025 = "3103d049-ec3f-452b-9a2b-56748cd6efe0", "d1bfb7a8-6a24-47da-a2d1-7cc3e7859e4a"
    sections = [{"year": y, "dataset_id": d, **PAGES[d]["section"]} for d, y in years.items()]
    # 结论照年报写（2025 年营业收入是降的，旧预演那句「逐年上升」不对）；引文从管理层讨论原文里截
    support_np = {"dataset_id": r2024, "page": 8, "text": "归属于上市公司股东的净利润862.28亿元，同比增长15.38%"}
    # 表格那一行（纯数字多）按 0036 的新规则不认，引叙述（审读 10-19）
    support_rev = {"dataset_id": r2025, "page": 9, "text": "营业收入变动原因说明：主要是酱香系列酒产品结构调整影响。"}
    checks = [
        {"finding": "2024 年归属于母公司所有者的净利润同比增长。", "verdict": "支持", "quotes": [support_np],
         "why": "2024 年报管理层讨论写归母净利润同比增长 15.38%。"},
        {"finding": "2025 年营业收入的变动主要来自酱香系列酒的产品结构调整。", "verdict": "支持", "quotes": [support_rev],
         "why": "2025 年报管理层讨论写营业收入变动主要是酱香系列酒产品结构调整影响。"},
        {"finding": "2023 年毛利率与上年基本持平。", "verdict": "不支持", "quotes": [],
         "why": "管理层讨论没有提到毛利率与上年比。"},
    ]
    official_values = [{"item": "营业收入", "year": y[:4], "address": addr(KEY, "营业收入", y), "value": raw(KEY, "营业收入", y)} for y in YEARS]
    out["official"] = {"sections": sections, "sections_missing": [], "checks": checks,
                       "official_values": official_values,
                       "official_by_year": {y[:4]: {"revenue": raw(KEY, "营业收入", y)} for y in YEARS}, "note": ""}
    out["indicators"]["findings"] = [c["finding"] for c in checks]
    # covers 要对上游：第 1 步的年报清单、第 5 步的结论（工作台从这件委托的交回物里取）
    upstream = {
        "scope": {"reports": [{"year": y, "dataset_id": d} for d, y in years.items()]},
        "indicators": out["indicators"],
    }
    records.repo.artifacts = [{"name": n, "kind": "step", "content": c} for n, c in upstream.items()]

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

    async def run(sid: str, artifact: dict[str, Any]) -> Any:
        rules = tuple(AcceptanceRule.model_validate(a) for a in steps[sid]["acceptance"])
        text = json.dumps(artifact, ensure_ascii=False)
        return await judge_numbers(judge(text, rules), rules, repo=records.repo, task=owner_task, source=Source())  # type: ignore[arg-type]

    for sid, artifact in out.items():
        v = await run(sid, artifact)
        bad = [ch for ch in v.checks if ch.get("pass") is False]
        print(f"{sid:11s} {'PASS' if v.ok else 'FAIL'}  checks={len(v.checks)}", "" if v.ok else bad)
    # ---- 第 6 步做错了的几种，都应当不过；该过的几种应当过 ----
    def variant(**change: Any) -> dict[str, Any]:
        bad = json.loads(json.dumps(out["official"]))
        for key, value in change.items():
            bad["checks"][0][key] = value
        return bad

    wrong_char = dict(support_np, text=support_np["text"].replace("15.38", "15.39"))
    unbound = dict(support_np, dataset_id="00000000-0000-0000-0000-000000000000")
    cases = [
        ("判支持没引原文", variant(quotes=[]), False),
        ("页码错一页", variant(quotes=[dict(support_np, page=9)]), False),
        ("改了一个数字", variant(quotes=[wrong_char]), False),
        ("引了没绑的数据", variant(quotes=[unbound]), False),
        ("引文太短", variant(quotes=[dict(support_np, text="净利润")]), False),
        # 汉字之间的空格、断行去掉；数字之间的空格按 0036 算分词、不去（「862」≠「8 6 2」）
        ("字间插空格、断行", variant(quotes=[dict(support_np, text=" ".join(support_np["text"][:13]) + "\n" + support_np["text"][13:])]), True),
        ("数字间插空格", variant(quotes=[dict(support_np, text=support_np["text"].replace("862.28", "8 6 2.28"))]), False),
        ("全判不支持、不引", {**out["official"], "checks": [dict(c, verdict="不支持", quotes=[]) for c in checks]}, True),
        ("一节都没找到", {**out["official"], "sections": [], "checks": [dict(c, verdict="不支持", quotes=[]) for c in checks],
                     "sections_missing": [{"year": y, "dataset_id": d, "why": "目录里没找到管理层讨论这一节"} for d, y in years.items()]}, True),
        ("只写了一份没找到", {**out["official"], "sections": [], "checks": [dict(c, verdict="不支持", quotes=[]) for c in checks],
                     "sections_missing": [{"year": "2024", "dataset_id": r2024, "why": "没找到管理层讨论这一节"}]}, False),
        ("判不支持却引了假话", variant(verdict="不支持", quotes=[wrong_char]), False),
        ("纯数字的引文", variant(quotes=[dict(support_np, text="862.28亿元，同比增长15.38%")]), False),
        ("判成「部分支持」", variant(verdict="部分支持", quotes=[]), False),
        ("一条结论都不对照", {**out["official"], "checks": []}, False),
        ("漏了一份年报", {**out["official"], "sections": sections[1:]}, False),
        ("结论缺判断", {**out["official"], "checks": [{k: v for k, v in checks[0].items() if k != "verdict"}, *checks[1:]]}, False),
    ]
    for name, artifact, should in cases:
        v = await run("official", artifact)
        detail = [ch["detail"] for ch in v.checks if ch.get("pass") is False]
        mark = "ok " if v.ok == should else "WRONG"
        print(f"  {mark} {name}: {'过' if v.ok else '不过'}", detail if detail else "")
        if v.ok != should:
            problems.append(f"official variant {name}")
    # ---- expectations of case c1 ----
    for e in ({"artifact": "official", "path": "official_by_year.2024.revenue", "kind": "approx", "value": 170899152276.34, "tolerance": 0.001},
              {"artifact": "forecast", "path": "horizon", "kind": "equals", "value": "2"}):
        print("expect", e["path"], expectation_met(Expectation.model_validate(e), out))
    print("computations", len(records.repo.events), "| problems:", problems or "none")
    print("unbalanced", out["reconcile"]["unbalanced"], "| roe n/a", [n for n in na if n["indicator"] == "roe"])
    print("sections", [(x["year"], x["first_page"], x["last_page"]) for x in out["official"]["sections"]])
    print("forecast REV", [(f["period"], f["kind"], f["value"]) for f in fc["forecasts"] if f["item"] == REV])
    print("mean errors", [(m["item"], m["value"]) for m in fc["mean_errors"]])
    import os
    if os.environ.get("DUMP"):
        json.dump(out, open(os.environ["DUMP"], "w"), ensure_ascii=False, indent=1)


asyncio.run(main())
