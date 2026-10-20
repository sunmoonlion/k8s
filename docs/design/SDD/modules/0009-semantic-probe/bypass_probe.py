"""探针第三步：字段级暴露控制能不能被绕过。
模型 orders 指向物理表 order_performance，但不暴露 cogs_cents、gross_profit_cents。"""
import base64, json, os, copy
from wren.engine import WrenEngine
from wren.config import WrenConfig
from wren.model.error import WrenError
H=os.path.expanduser("~/wren-probe")
mdl=json.load(open(f"{H}/project/target/mdl.json"))
m2=copy.deepcopy(mdl); m2["cubes"]=[]; m2["relationships"]=[]
op=[m for m in m2["models"] if m["name"]=="order_performance"][0]
op["name"]="orders"; op["columns"]=[c for c in op["columns"] if c["name"] not in ("cogs_cents","gross_profit_cents")]
m2["models"]=[op]
b64=base64.b64encode(json.dumps(m2).encode()).decode()
conn=json.load(open(f"{H}/connection.json")); conn.pop("datasource",None)
Q=[("经模型查已暴露字段","SELECT SUM(net_revenue_cents) AS v FROM orders",True),
   ("经模型查未暴露字段","SELECT SUM(cogs_cents) AS v FROM orders",False),
   ("SELECT * 是否带出未暴露字段","SELECT * FROM orders LIMIT 1","nocogs"),
   ("物理表全名查未暴露字段","SELECT SUM(cogs_cents) AS v FROM lesson23.main.order_performance",False),
   ("物理表带 schema 查未暴露字段","SELECT SUM(cogs_cents) AS v FROM main.order_performance",False),
   ("物理表裸名查未暴露字段","SELECT SUM(cogs_cents) AS v FROM order_performance",False),
   ("子查询里藏物理表","SELECT v FROM (SELECT SUM(cogs_cents) AS v FROM lesson23.main.order_performance) t",False),
   ("CTE 里藏物理表","WITH x AS (SELECT cogs_cents FROM lesson23.main.order_performance) SELECT SUM(cogs_cents) AS v FROM x",False),
   ("别的物理表","SELECT COUNT(*) AS v FROM lesson23.main.funnel_daily",False)]
bad=frozenset({"read_text","read_csv","read_blob","read_json","read_parquet","glob","duckdb_secrets","getenv"})
for label,cfg,fb in [("默认, fallback=开",WrenConfig(),True),("严格, fallback=开",WrenConfig(strict_mode=True,denied_functions=bad),True),("严格, fallback=关",WrenConfig(strict_mode=True,denied_functions=bad),False)]:
    print(f"\n#### {label}")
    eng=WrenEngine(b64,"duckdb",conn,config=cfg,fallback=fb)
    for t,sql,exp in Q:
        try:
            r=eng.query(sql,limit=2).to_pylist(); 
            if exp=="nocogs": ok=("cogs_cents" not in r[0]); out=f"返回 {len(r[0])} 个字段，含 cogs_cents={('cogs_cents' in r[0])}"
            else: ok=(exp is True); out=f"放行 {r[:1]}"
        except WrenError as e:
            ok=(exp is False); out=f"拦截 {str(e)[:120]}"
        except Exception as e:
            ok=(exp is False); out=f"拦截(非结构化) {type(e).__name__}: {str(e)[:100]}"
        print(f"- {t:22} | {'符合预期' if ok else '!! 泄露/不符'} | {out[:170]}")
    try: print("  dry_plan(物理表全名) →", eng.dry_plan("SELECT SUM(cogs_cents) AS v FROM lesson23.main.order_performance")[:160])
    except Exception as e: print("  dry_plan(物理表全名) 拦截：", str(e)[:140])
    eng.close()
