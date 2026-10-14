#!/usr/bin/env bash
set -euo pipefail
cd "$1"
export DATABASE_URL=postgresql+asyncpg://postgres:opus@127.0.0.1:55440/info ENV=test
P() { docker exec opus-rename-pg psql -U postgres -d info -Atqc "$1"; }
# 只填必填列的模拟行：raw_artifact、extracted_content、security_dataset 各一行旧桶旧键；requester 一行 info-app
python3 - <<'PY' > ${SEED:-/tmp/rename-seed.sql}
import subprocess, uuid
def q(sql): return subprocess.run(["docker","exec","opus-rename-pg","psql","-U","postgres","-d","info","-Atqc",sql],capture_output=True,text=True,check=True).stdout.split("\n")
out=["SET session_replication_role = replica;"]
special={"bucket":"'info-originals'","object_key":None,"source_app":"'info-app'","sha256":"'"+'a'*64+"'","content_hash":"'"+'a'*64+"'"}
keys={"raw_artifact":"info/original/source=a/date=2026/job=1/x.html","extracted_content":"info/original/source=a/clean.md","security_dataset":"info/securities/code=600009/datasets/v1"}
for t in ("raw_artifact","extracted_content","security_dataset","security_request_requester","info_document"):
    cols=[l.split("|") for l in q(f"select column_name,data_type from information_schema.columns where table_name='{t}' and is_nullable='NO' and column_default is null") if l]
    names,vals=[],[]
    for c,dt in cols:
        names.append(c)
        if c=="object_key": vals.append(f"'{keys[t]}'")
        elif c in special and special[c]: vals.append(special[c])
        elif "uuid" in dt: vals.append(f"'{uuid.uuid4()}'")
        elif "timestamp" in dt or "date" in dt: vals.append("now()")
        elif dt in ("integer","bigint","smallint"): vals.append("1")
        elif dt=="boolean": vals.append("false")
        elif dt in ("json","jsonb"): vals.append("'{}'")
        else: vals.append("'x'")
    if t=="security_request_requester" and "source_app" not in names: names.append("source_app"); vals.append("'info-app'")
    checks=[l.split("|",1) for l in q(f"select conname, pg_get_constraintdef(oid) from pg_constraint where conrelid='{t}'::regclass and contype='c'") if l]
    out += [f'ALTER TABLE {t} DROP CONSTRAINT "{c}";' for c,_ in checks]
    if t!="info_document":  # 模拟行不造上游数据：这几张表的外键（名字里都不带 info_）去掉
        out += [f'ALTER TABLE {t} DROP CONSTRAINT "{c}";' for c in q(f"select conname from pg_constraint where conrelid='{t}'::regclass and contype='f'") if c]
    out.append(f"INSERT INTO {t} ({','.join(names)}) VALUES ({','.join(vals)});")
    pass  # 检查约束不加回：更新模拟行时会被重新检查
print("\n".join(out))
PY
docker exec -i opus-rename-pg psql -U postgres -d info -q -v ON_ERROR_STOP=1 < ${SEED:-/tmp/rename-seed.sql}
snap() {
  echo "  tables: $(P "select string_agg(tablename,' ' order by tablename) from pg_tables where schemaname='public' and (tablename like 'info%' or tablename like 'knowgather%')")"
  echo "  names with info_:       $(P "select count(*) from (select conname n from pg_constraint union all select relname from pg_class where relkind in ('i','S')) x where n ~ '(^|_)info_(source|collector|document)'")"
  echo "  names with knowgather_: $(P "select count(*) from (select conname n from pg_constraint union all select relname from pg_class where relkind in ('i','S')) x where n ~ '(^|_)knowgather_(source|collector|document)'")"
  for t in raw_artifact extracted_content security_dataset; do echo "  $t: $(P "select bucket||' '||object_key from $t")"; done
  echo "  requester source_app: $(P "select source_app from security_request_requester")"
}
echo "== 旧末端 + 模拟数据"; snap
.venv/bin/alembic upgrade head >/dev/null; echo "== upgrade head"; snap
.venv/bin/alembic downgrade 20260929_0013 >/dev/null; echo "== downgrade 回 0013"; snap
.venv/bin/alembic upgrade head >/dev/null 2>&1 && echo "== 再 upgrade（可重复）" && P "select version_num from alembic_version"
