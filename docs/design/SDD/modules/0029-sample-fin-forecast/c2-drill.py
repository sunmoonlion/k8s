"""0030 C2 演练：用样本自己的验收规则跑「取数」「算指标」两步的数值验收；故意改错一个数、换一个算式，都要被抓到。"""
# 用法：在 knowbench-backend/app 下 PYTHONPATH=$PWD uv run python <本文件> <manifest.json>；合成数据，不是真实财报。
import asyncio, contextlib, json, sys, uuid
sys.path.insert(0, "tests")
from app.application.workbench.acceptance import judge
from app.application.workbench.acceptance_numbers import judge_numbers
from app.application.workbench.knowbot_compute import KnowbotCompute
from app.domain.workbench import compute as calc
from app.domain.workbench.packs import AcceptanceRule

M = json.load(open(sys.argv[1]))
STEPS = {s["step_id"]: s for s in M["pack"]["workflow"]}
DATASET = "0b9b8c52-3f0e-4c34-9d0b-2b7f4d3c1a12"
BIND = {"dataset_id": DATASET, "version": "1", "sha256": "a" * 64}
TABLE = {  # 合成的利润表（累计数，单位元）——不是真实数据
    ("营业收入", "2024-03-31"): "46485000000", ("营业收入", "2024-06-30"): "83451000000",
    ("营业成本", "2024-03-31"): "3550000000", ("营业成本", "2024-06-30"): "6531000000",
}
OWNER = str(uuid.uuid4())

class Repo:
    def __init__(self): self.events = []
    async def get_knowbot_pin(self, **kw):
        return {"owner_subject": "u", "digest": "sha256:" + "d" * 64, "manifest": {"data_bindings": [BIND]}}
    async def test_run_for_task(self, task_id): return None
    @contextlib.asynccontextmanager
    async def transaction(self): yield
    async def append_event(self, **kw):
        e = {"cursor": len(self.events) + 1, "type": kw["event_type"], **kw}; self.events.append(e); return e
    async def list_task_events(self, task_id, *, types): return [e for e in self.events if e["type"] in types]

class Records:
    def __init__(self):
        self.repo = Repo(); self.owner = OWNER
        self.task = {"id": "t1", "session_id": "s1", "pack_source": "knowmart", "profile_id": "knowbot:0b9b8c52-3f0e-4c34-9d0b-2b7f4d3c1a10@1",
                     "pack_digest": "sha256:" + "d" * 64, "owner_actor_id": OWNER}
    async def _working(self, task): return self.task
    async def _noted(self, *a, **k): pass

class Cells:
    async def cells(self, purpose, cells):
        return [{**r, "found": (r["row"], r["column"]) in TABLE, "raw": TABLE.get((r["row"], r["column"])),
                 "number": TABLE.get((r["row"], r["column"])), "version": "1", "sha256": "a" * 64} for r in cells]

def at(row, col): return calc.address(DATASET, "利润表", row, col)

async def main():
    rec, src = Records(), Cells()
    tool = KnowbotCompute(rec, src)
    q2 = {}
    for item in ("营业收入", "营业成本"):
        q2[item] = await tool.compute("t1", f"2024Q2 单季{item}", "cur - prev", {"cur": at(item, "2024-06-30"), "prev": at(item, "2024-03-31")})
    gm = await tool.compute("t1", "2024Q2 毛利率", "(rev - cost) / rev", {"rev": q2["营业收入"]["id"], "cost": q2["营业成本"]["id"]}, 4)
    gm_other = await tool.compute("t1", "2024Q2 毛利率（换了写法）", "1 - cost / rev", {"rev": q2["营业收入"]["id"], "cost": q2["营业成本"]["id"]}, 4)

    def rules(step): return tuple(AcceptanceRule.model_validate(r) for r in STEPS[step]["acceptance"])
    async def verdict(step, out):
        return await judge_numbers(judge(json.dumps(out, ensure_ascii=False), rules(step)), rules(step), repo=rec.repo, task=rec.task, source=src)

    extract = {"raw": [{"item": i, "period": p, "address": at(i, c), "value": TABLE[(i, c)]} for i in ("营业收入", "营业成本")
                       for p, c in (("2024-Q1", "2024-03-31"), ("2024-H1", "2024-06-30"))],
               "single_quarter": [{"item": i, "period": "2024-Q2", "compute_id": q2[i]["id"], "value": q2[i]["value"]} for i in q2],
               "missing": [], "unit": "元"}
    empty = {"period": "2024-Q2", "compute_id": gm["id"], "value": gm["value"]}
    analyze = {"metrics": {"gross_margin": [empty], "net_margin": [], "roe": [], "ocf_to_np": [], "growth": []},
               "not_applicable": [], "findings": [{"text": "a", "compute_ids": [gm["id"]]}, {"text": "b", "compute_ids": []}]}
    cases = [("extract 正确", "extract", extract, True), ("analyze 正确", "analyze", analyze, True)]
    bad = json.loads(json.dumps(extract)); bad["raw"][1]["value"] = "83451000001"
    cases.append(("extract 抄错一个原始数（多 1 元）", "extract", bad, False))
    bad = json.loads(json.dumps(extract)); bad["single_quarter"][0]["value"] = "36966000001"
    cases.append(("extract 单季数改了 1 元", "extract", bad, False))
    bad = json.loads(json.dumps(analyze)); bad["metrics"]["gross_margin"][0]["compute_id"] = gm_other["id"]; bad["metrics"]["gross_margin"][0]["value"] = gm_other["value"]
    cases.append(("analyze 毛利率换了算式（结果相同）", "analyze", bad, False))
    bad = json.loads(json.dumps(analyze)); bad["metrics"]["gross_margin"][0]["value"] = "0.9200"
    cases.append(("analyze 毛利率写成 0.92（没调计算）", "analyze", bad, False))
    ok = True
    for name, step, out, expect in cases:
        v = await verdict(step, out)
        hits = [f"{c['rule']}({c['path']}): {c['detail']}" for c in v.checks if c["pass"] is False]
        good = v.ok == expect
        ok &= good
        print(("✓" if good else "✗"), name, "→", "通过" if v.ok else "退回", "|", "; ".join(hits)[:240])
    print("q2 rev", q2["营业收入"]["value"], "cost", q2["营业成本"]["value"], "gm", gm["value"], "gm_other", gm_other["value"])
    sys.exit(0 if ok else 1)

asyncio.run(main())
