"""探针第二步：安全防护。用库的方式（WrenEngine）调用，和将来嵌进知识后端的方式一致。
两种模式各跑一遍：默认、严格模式（只许查语义模型里的表）。"""
import base64, json, os, time, resource
from wren.engine import WrenEngine
from wren.config import WrenConfig
from wren.model.error import WrenError
H=os.path.expanduser("~/wren-probe")
mdl=json.load(open(f"{H}/project/target/mdl.json"))
b64=base64.b64encode(json.dumps(mdl).encode()).decode()
conn=json.load(open(f"{H}/connection.json")); conn.pop("datasource",None)
CASES=[
 ("正常查询","SELECT region, SUM(net_revenue_cents) AS net FROM order_performance GROUP BY region ORDER BY net DESC LIMIT 2",True),
 ("带 CTE 的查询","WITH t AS (SELECT region, net_revenue_cents FROM order_performance) SELECT region, COUNT(*) AS n FROM t GROUP BY region LIMIT 2",True),
 ("删除","DELETE FROM order_performance",False),
 ("插入","INSERT INTO order_performance (order_id) VALUES ('x')",False),
 ("建表","CREATE TABLE evil AS SELECT 1",False),
 ("多条语句","SELECT 1; DROP TABLE order_performance",False),
 ("挂载别的库","ATTACH DATABASE '/tmp/x.db' AS x",False),
 ("PRAGMA","PRAGMA database_list",False),
 ("读本地文件 read_text",f"SELECT * FROM read_text('{H}/data/secret.txt')",False),
 ("读本地文件 read_csv",f"SELECT * FROM read_csv('{H}/data/secret.txt')",False),
 ("读系统文件","SELECT * FROM read_csv('/etc/passwd', delim=':', header=false)",False),
 ("绕过语义层直查物理表","SELECT COUNT(*) AS n FROM lesson23.main.order_performance",False),
 ("查系统目录","SELECT table_name FROM information_schema.tables LIMIT 3",False),
 ("列出密钥函数","SELECT * FROM duckdb_secrets()",False),
 ("语义模型外的表","SELECT * FROM metric_dictionary LIMIT 1",False),
 ("导出文件 COPY","COPY (SELECT 1) TO '/tmp/wren-probe-out.csv'",False),
 ("装扩展","INSTALL httpfs",False),
]
def run(name,cfg):
    print(f"\n#### 模式：{name}")
    eng=WrenEngine(b64,"duckdb",conn,config=cfg)
    res=[]
    for title,sql,should_pass in CASES:
        t=time.time()
        try:
            tb=eng.query(sql,limit=5); out=f"放行 rows={tb.num_rows} first={tb.to_pylist()[:1]}"; ok=True
        except WrenError as e:
            out=f"拦截 code={getattr(e,'error_code',None)} phase={getattr(e,'phase',None)} msg={str(e)[:110]}"; ok=False
        except Exception as e:
            out=f"拦截(非结构化) {type(e).__name__}: {str(e)[:110]}"; ok=False
        verdict="符合预期" if ok==should_pass else "!! 不符合预期"
        print(f"- {title:16} | {verdict:8} | {out[:200]} | {int((time.time()-t)*1000)}ms")
        res.append((title,ok==should_pass))
    eng.close(); return res
a=run("默认",WrenConfig())
b=run("严格",WrenConfig(strict_mode=True,denied_functions=frozenset({"read_text","read_csv","read_blob","read_json","read_parquet","glob","duckdb_secrets","getenv"})))
print("\n默认模式不符合预期：",[t for t,ok in a if not ok])
print("严格模式不符合预期：",[t for t,ok in b if not ok])
print("进程内存峰值 MB：",resource.getrusage(resource.RUSAGE_SELF).ru_maxrss//1024)
print("导出文件是否被写出：",os.path.exists("/tmp/wren-probe-out.csv"))
