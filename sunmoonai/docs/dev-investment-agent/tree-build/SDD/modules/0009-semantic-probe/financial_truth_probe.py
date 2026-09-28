"""落地前验证：财务数据集 → DuckDB + MDL（物理表加前缀），真值查询经引擎与 SQLite 直查比对。"""
import base64, json, os, sqlite3, sys, time
import duckdb
from wren.engine import WrenEngine
from wren.config import WrenConfig
from wren.model.error import WrenError

SRC = "/home/zym/ashare-probe/data/sh600009-financials.from-info.sqlite"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")
os.makedirs(OUT, exist_ok=True)
DB = os.path.join(OUT, "ds.duckdb")
TYPE = {"INTEGER": "BIGINT", "TEXT": "VARCHAR", "REAL": "DOUBLE"}
PREFIX = "t_"

src = sqlite3.connect(f"file:{SRC}?mode=ro", uri=True)
tables = [r[0] for r in src.execute("select name from sqlite_master where type='table' order by 1")]
if os.path.exists(DB):
    os.remove(DB)
db = duckdb.connect(DB)
models = []
t0 = time.time()
for t in tables:
    cols = [(r[1], (r[2] or "TEXT").upper()) for r in src.execute(f'pragma table_info("{t}")')]
    ddl = ", ".join(f'"{n}" {TYPE.get(ty, "VARCHAR")}' for n, ty in cols)
    db.execute(f'create table "{PREFIX}{t}" ({ddl})')
    rows = src.execute(f'select * from "{t}"').fetchall()
    if rows:
        import pyarrow as pa
        arrays = {n: [r[i] for r in rows] for i, (n, _) in enumerate(cols)}
        tbl = pa.table({n: pa.array(v, type={"BIGINT": pa.int64(), "DOUBLE": pa.float64()}.get(TYPE.get(ty, "VARCHAR"), pa.string())) for (n, ty), v in zip(cols, arrays.values())})
        db.register("incoming", tbl)
        db.execute(f'insert into "{PREFIX}{t}" select * from incoming')
        db.unregister("incoming")
    models.append({
        "name": t,
        "tableReference": {"catalog": "ds", "schema": "main", "table": PREFIX + t},
        "columns": [{"name": n, "type": TYPE.get(ty, "VARCHAR"), "isCalculated": False, "notNull": False, "properties": {}} for n, ty in cols],
        "cached": False, "properties": {},
    })
db.close()
print("converted", len(tables), "tables in", round(time.time() - t0, 2), "s")
mdl = {"catalog": "wren", "schema": "public", "models": models, "relationships": [], "views": [], "cubes": [], "dataSource": "duckdb", "layoutVersion": 3}
b64 = base64.b64encode(json.dumps(mdl).encode()).decode()
cfg = WrenConfig(strict_mode=True, denied_functions=frozenset({"read_text", "read_csv", "read_blob", "read_json", "read_parquet", "glob", "duckdb_secrets", "getenv"}))
eng = WrenEngine(b64, "duckdb", {"url": OUT, "format": "duckdb"}, fallback=False, config=cfg)

def lite(sql):
    c = sqlite3.connect(f"file:{SRC}?mode=ro", uri=True); c.row_factory = sqlite3.Row
    return [dict(r) for r in c.execute(sql)]

def close(a, b):
    if isinstance(a, (int, float)) and isinstance(b, (int, float)) and not isinstance(a, bool):
        return abs(float(a) - float(b)) <= 1e-6 * max(1.0, abs(float(a)))
    return a == b

cases = json.load(open("/home/zym/ashare-probe/eval/ashare_600009_13.json"))
bad = 0; n = 0
for c in cases:
    for q in c["truth_queries"]:
        n += 1
        expect = lite(q["sql"])
        try:
            got = eng.query(q["sql"], limit=500).to_pylist()
        except WrenError as e:
            bad += 1; print("ENGINE FAIL", c["case_id"], q["query_id"], getattr(e, "error_code", None), str(e)[:300]); continue
        except Exception as e:
            bad += 1; print("ENGINE FAIL*", c["case_id"], q["query_id"], type(e).__name__, str(e)[:300]); continue
        same = len(got) == len(expect) and all(set(a) == set(b) and all(close(a[k], b[k]) for k in a) for a, b in zip(expect, got))
        if not same:
            bad += 1
            print("DIFF", c["case_id"], q["query_id"], len(expect), len(got))
            for a, b in zip(expect, got):
                if a != b: print("   sqlite:", a); print("   engine:", b); break
        else:
            print("same", c["case_id"], q["query_id"], len(got))
print(n, "queries,", bad, "not same")
for title, sql in [
    ("直查物理表(裸名)", "SELECT COUNT(*) n FROM t_income_statement"),
    ("直查物理表(全名)", "SELECT COUNT(*) n FROM ds.main.t_income_statement"),
    ("全名引用模型名", "SELECT COUNT(*) n FROM ds.main.income_statement"),
    ("系统目录", "SELECT table_name FROM information_schema.tables"),
    ("模型", "SELECT COUNT(*) n FROM income_statement"),
]:
    try:
        print(title, "放行", eng.query(sql, limit=3).to_pylist())
    except Exception as e:
        print(title, "拦截", getattr(e, "error_code", type(e).__name__), str(e)[:120])
eng.close()
