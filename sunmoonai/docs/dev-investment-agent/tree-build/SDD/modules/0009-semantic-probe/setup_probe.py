"""探针第一步：把第 23 课零售库（SQLite，只读）转成 DuckDB 文件，并生成 Wren 语义模型项目。
只读源数据集；所有产物在 ~/wren-probe 下。"""
import os, sqlite3, duckdb, yaml, hashlib, json
SRC="/home/zym/worktrees/fable/knowledge-app/knowledge-backend/app/datasets/lesson23_business_analysis.sqlite"
OUT=os.path.expanduser("~/wren-probe/data/lesson23.duckdb")
PROJ=os.path.expanduser("~/wren-probe/project")
TABLES=["order_performance","order_line_performance","funnel_daily","lost_demand_daily","inventory_daily_analysis","supply_performance"]
DESC={"order_performance":"订单级经营事实，一行一张支付订单；金额单位为分","order_line_performance":"订单行级事实，一行一个商品行；金额单位为分",
      "funnel_daily":"按日、地区、渠道、活动聚合的会话漏斗","lost_demand_daily":"按日的缺货损失事件聚合","inventory_daily_analysis":"按日、仓库、商品的库存快照","supply_performance":"采购到货表现，一行一个采购行"}
TYPE={"INTEGER":"BIGINT","TEXT":"VARCHAR","REAL":"DOUBLE"}
print("source sha256", hashlib.sha256(open(SRC,"rb").read()).hexdigest())
src=sqlite3.connect(f"file:{SRC}?mode=ro",uri=True)
if os.path.exists(OUT): os.remove(OUT)
db=duckdb.connect(OUT)
meta={}
for t in TABLES:
    cols=[(r[1],r[2].upper()) for r in src.execute(f'pragma table_info("{t}")')]
    rows=src.execute(f'select * from "{t}"').fetchall()
    ddl=[]; sel=[]
    for n,ty in cols:
        wt="DATE" if n.endswith("_date") else TYPE.get(ty,"VARCHAR")
        ddl.append(f'"{n}" {wt}'); meta.setdefault(t,[]).append((n,wt))
    db.execute(f'create table "{t}" ({", ".join(ddl)})')
    db.executemany(f'insert into "{t}" values ({", ".join(["?"]*len(cols))})', rows)
    print(t, db.execute(f'select count(*) from "{t}"').fetchone()[0])
md=src.execute("select metric_name,display_name,source_table,expression_hint,unit,time_basis,description from metric_dictionary").fetchall()
db.close()
# ---- 项目
def dump(path,obj):
    os.makedirs(os.path.dirname(path),exist_ok=True)
    yaml.safe_dump(obj,open(path,"w"),allow_unicode=True,sort_keys=False)
dump(f"{PROJ}/wren_project.yml",{"schema_version":5,"name":"lesson23","catalog":"wren","schema":"public","data_source":"duckdb"})
PK={"order_performance":"order_id","order_line_performance":"line_id","supply_performance":"po_line_id"}
disp={m[0]:m for m in md}
for t,cols in meta.items():
    cs=[]
    for n,wt in cols:
        c={"name":n,"type":wt,"is_calculated":False,"not_null":False,"properties":{}}
        if n in disp and disp[n][2]==t: c["properties"]={"description":f"{disp[n][1]}：{disp[n][6]}（单位 {disp[n][4]}，时间口径 {disp[n][5]}）","display_name":disp[n][1]}
        if PK.get(t)==n: c["is_primary_key"]=True; c["not_null"]=True
        cs.append(c)
    m={"name":t,"properties":{"description":DESC[t]},"table_reference":{"catalog":"lesson23","schema":"main","table":t},"columns":cs,"cached":False}
    if t in PK: m["primary_key"]=PK[t]
    dump(f"{PROJ}/models/{t}/metadata.yml",m)
dump(f"{PROJ}/relationships.yml",{"relationships":[{"name":"line_order","models":["order_line_performance","order_performance"],"join_type":"MANY_TO_ONE","condition":"order_line_performance.order_id = order_performance.order_id"}]})
# 口径 → cube：口径表里 source_table=order_performance 的全部进 measures
meas=[]
for name,dn,st,expr,unit,tb,desc in md:
    if st!="order_performance": continue
    ratio="/" in expr
    e=expr if not ratio else expr.replace(" / "," * 1.0 / NULLIF(",1)+", 0)"
    meas.append({"name":name,"expression":e,"type":"DOUBLE" if ratio else "BIGINT","properties":{"description":f"{dn}：{desc}（单位 {unit}）","display_name":dn}})
meas.append({"name":"order_count","expression":"COUNT(*)","type":"BIGINT","properties":{"description":"支付订单数","display_name":"订单数"}})
dump(f"{PROJ}/cubes/order_metrics/metadata.yml",{"name":"order_metrics","base_object":"order_performance","measures":meas,
    "dimensions":[{"name":d,"expression":d,"type":"VARCHAR"} for d in ("region","city","channel","channel_kind","campaign_name")],
    "time_dimensions":[{"name":"order_date","expression":"order_date","type":"DATE"}],
    "properties":{"description":"订单口径：来自数据集的口径表 metric_dictionary，随数据版本一起发布"}})
json.dump({"datasource":"duckdb","url":os.path.dirname(OUT),"format":"duckdb"},open(os.path.expanduser("~/wren-probe/connection.json"),"w"))
print("measures", [m["name"] for m in meas])
