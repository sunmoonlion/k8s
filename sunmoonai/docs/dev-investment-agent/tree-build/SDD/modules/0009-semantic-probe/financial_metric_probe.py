"""落地前验证二：财务口径用 cube 表达（含适用条件）、跨表口径用关系、按口径名查询。"""
import base64, json, os, sqlite3
import duckdb
from wren.engine import WrenEngine
from wren.config import WrenConfig
from wren_core import cube_query_to_sql

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")
db = duckdb.connect(os.path.join(OUT, "ds.duckdb"), read_only=True)
def cols(t):
    return [(r[1], r[2]) for r in db.execute(f"pragma table_info('t_{t}')").fetchall()]
KEY = ("security_code", "report_date")
models = []
for t in ("income_statement", "balance_sheet", "cash_flow"):
    cs = [{"name": n, "type": ty, "isCalculated": False, "notNull": False, "properties": {}} for n, ty in cols(t)]
    models.append({"name": t, "tableReference": {"catalog": "ds", "schema": "main", "table": "t_" + t}, "columns": cs, "cached": False, "properties": {}, "primaryKey": "report_date"})
db.close()
# 现金流量表 → 利润表：同一公司同一报告期
rels = [{"name": "cash_income", "models": ["cash_flow", "income_statement"], "joinType": "ONE_TO_ONE",
         "condition": "cash_flow.report_date = income_statement.report_date AND cash_flow.security_code = income_statement.security_code"}]
cf = next(m for m in models if m["name"] == "cash_flow")
cf["columns"].append({"name": "income_statement", "type": "income_statement", "relationship": "cash_income", "isCalculated": False, "notNull": False, "properties": {}})
cf["columns"].append({"name": "netprofit_same_period", "type": "DOUBLE", "isCalculated": True, "expression": "income_statement.netprofit", "notNull": False, "properties": {}})
DIMS = [{"name": d, "expression": d, "type": "VARCHAR"} for d in ("report_date", "report_type", "basis")] + [{"name": "fiscal_year", "expression": "fiscal_year", "type": "BIGINT"}]
cubes = [
 {"name": "income_metrics", "baseObject": "income_statement", "dimensions": DIMS, "timeDimensions": [], "properties": {},
  "measures": [
   {"name": "gross_margin", "type": "DOUBLE", "expression": "(SUM(operate_income) - SUM(operate_cost)) / NULLIF(SUM(operate_income), 0)", "properties": {}},
   {"name": "invest_income_share", "type": "DOUBLE", "expression": "CASE WHEN SUM(operate_profit) > 0 THEN SUM(invest_income) / SUM(operate_profit) END", "properties": {}},
   {"name": "rows_in_group", "type": "BIGINT", "expression": "COUNT(*)", "properties": {}},
  ]},
 {"name": "cash_metrics", "baseObject": "cash_flow", "dimensions": DIMS, "timeDimensions": [], "properties": {},
  "measures": [
   {"name": "ocf_to_netprofit", "type": "DOUBLE", "expression": "CASE WHEN SUM(netprofit_same_period) > 0 THEN SUM(netcash_operate) / SUM(netprofit_same_period) END", "properties": {}},
   {"name": "free_cash_flow", "type": "DOUBLE", "expression": "SUM(netcash_operate) - SUM(construct_long_asset)", "properties": {}},
  ]},
]
mdl = {"catalog": "wren", "schema": "public", "models": models, "relationships": rels, "views": [], "cubes": cubes, "dataSource": "duckdb", "layoutVersion": 3}
b64 = base64.b64encode(json.dumps(mdl).encode()).decode()
eng = WrenEngine(b64, "duckdb", {"url": OUT, "format": "duckdb"}, fallback=False, config=WrenConfig(strict_mode=True))
SRC = "/home/zym/ashare-probe/data/sh600009-financials.from-info.sqlite"
lite = sqlite3.connect(f"file:{SRC}?mode=ro", uri=True)
def run(title, q):
    try:
        sql = cube_query_to_sql(json.dumps(q), json.dumps(mdl)) if isinstance(q, dict) else q
        print("--", title); print("   SQL:", sql[:260].replace("\n", " "))
        rows = eng.query(sql, limit=50).to_pylist()
        for r in rows[:9]: print("   ", r)
        return rows
    except Exception as e:
        print("-- FAIL", title, type(e).__name__, str(e)[:400])
flt = [{"dimension": "report_type", "operator": "eq", "value": "年报"}, {"dimension": "fiscal_year", "operator": "gte", "value": 2019}]
a = run("毛利率 与 投资收益占比（年报，2019 起）", {"cube": "income_metrics", "measures": ["gross_margin", "invest_income_share", "rows_in_group"], "dimensions": ["fiscal_year", "basis"], "filters": flt, "orderBy": [{"member": "fiscal_year", "direction": "asc"}]})
print("   sqlite:", lite.execute("select fiscal_year, basis, (operate_income-operate_cost)/operate_income, case when operate_profit>0 then invest_income/operate_profit end from income_statement where report_type='年报' and fiscal_year>=2019 order by 1").fetchall())
b = run("经营现金流/净利润（跨表）", {"cube": "cash_metrics", "measures": ["ocf_to_netprofit", "free_cash_flow"], "dimensions": ["fiscal_year"], "filters": flt, "orderBy": [{"member": "fiscal_year", "direction": "asc"}]})
print("   sqlite:", lite.execute("select c.fiscal_year, case when i.netprofit>0 then c.netcash_operate/i.netprofit end, c.netcash_operate-c.construct_long_asset from cash_flow c join income_statement i on i.report_date=c.report_date where c.report_type='年报' and c.fiscal_year>=2019 order by 1").fetchall())
run("直接写 SQL 用计算字段", "SELECT fiscal_year, netcash_operate, netprofit_same_period FROM cash_flow WHERE report_type='年报' AND fiscal_year=2025")
run("窗口函数", "SELECT fiscal_year, total_parent_equity, LAG(total_parent_equity) OVER (ORDER BY fiscal_year) AS prev FROM balance_sheet WHERE report_type='年报' AND fiscal_year>=2023 ORDER BY fiscal_year")
eng.close()
