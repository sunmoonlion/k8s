"""同名场景：模型 order_performance 与物理表同名，但不暴露 cogs_cents。"""
import base64, json, os, copy
from wren.engine import WrenEngine
from wren.config import WrenConfig
H=os.path.expanduser("~/wren-probe")
mdl=json.load(open(f"{H}/project/target/mdl.json"))
m2=copy.deepcopy(mdl); m2["cubes"]=[]; m2["relationships"]=[]
op=[m for m in m2["models"] if m["name"]=="order_performance"][0]
op["columns"]=[c for c in op["columns"] if c["name"] not in ("cogs_cents","gross_profit_cents")]
m2["models"]=[op]
b64=base64.b64encode(json.dumps(m2).encode()).decode()
conn=json.load(open(f"{H}/connection.json")); conn.pop("datasource",None)
import sys
FB=(sys.argv[1]=="on")
print("fallback =",FB)
for label,cfg in [("默认",WrenConfig()),("严格",WrenConfig(strict_mode=True))]:
    eng=WrenEngine(b64,"duckdb",conn,config=cfg,fallback=FB)
    for t,sql in [("全名查未暴露字段","SELECT SUM(cogs_cents) AS v FROM lesson23.main.order_performance"),
                  ("全名查已暴露字段","SELECT SUM(net_revenue_cents) AS v FROM lesson23.main.order_performance"),
                  ("全名 SELECT *","SELECT * FROM lesson23.main.order_performance LIMIT 1")]:
        try:
            r=eng.query(sql,limit=1).to_pylist(); out=f"放行 字段数={len(r[0])} 含cogs={'cogs_cents' in r[0]} {str(r[0])[:70]}"
        except Exception as e: out=f"拦截 {str(e)[:110]}"
        print(f"{label} | {t:12} | {out}")
    print(f"{label} | 改写结果 |", eng.dry_plan("SELECT SUM(net_revenue_cents) AS v FROM lesson23.main.order_performance")[:230])
    eng.close()
