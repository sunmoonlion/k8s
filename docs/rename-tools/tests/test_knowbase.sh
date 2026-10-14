#!/usr/bin/env bash
set -uo pipefail
cd "$1"
export DATABASE_URL=postgresql+asyncpg://postgres:opus@127.0.0.1:55440/knowledge ENV=test
P() { docker exec opus-rename-pg psql -U postgres -d knowledge -Atqc "$1"; }
python3 - <<'PY' | docker exec -i opus-rename-pg psql -U postgres -d knowledge -q -v ON_ERROR_STOP=1
import subprocess, uuid
def q(sql): return [l for l in subprocess.run(["docker","exec","opus-rename-pg","psql","-U","postgres","-d","knowledge","-Atqc",sql],capture_output=True,text=True,check=True).stdout.split("\n") if l]
special={"knowledge_ingestion_job":{"source_app":"'info-app'","canonical_url":"'https://info.sunmoonai.com:30443/acceptance/1'"},
 "knowledge_document":{"source_app":"'info-app'"},
 "knowledge_document_version":{"source_app":"'info-app'","source_uri":"'s3://info-originals/info/original/source=a/x.md'"},
 "knowledge_dataset":{"source_app":"'info'","bucket":"'info-originals'","object_key":"'info/securities/code=600009/datasets/v1'"}}
out=["SET session_replication_role = replica;"]
for t,sp in special.items():
    out += [f'ALTER TABLE {t} DROP CONSTRAINT "{c}";' for c in q(f"select conname from pg_constraint where conrelid='{t}'::regclass and contype in ('c','f')")]
    cols=[l.split("|") for l in q(f"select column_name,data_type from information_schema.columns where table_name='{t}' and (is_nullable='NO' and column_default is null)")]
    names,vals=[],[]
    for c,dt in cols:
        names.append(c)
        if c in sp: vals.append(sp[c])
        elif "uuid" in dt: vals.append(f"'{uuid.uuid4()}'")
        elif "timestamp" in dt or "date" in dt: vals.append("now()")
        elif dt in ("integer","bigint","smallint"): vals.append("1")
        elif dt=="boolean": vals.append("false")
        elif dt in ("json","jsonb"): vals.append("'{}'")
        else: vals.append("'x'")
    for c,v in sp.items():
        if c not in names: names.append(c); vals.append(v)
    out.append(f"INSERT INTO {t} ({','.join(names)}) VALUES ({','.join(vals)});")
print("\n".join(out))
PY
snap() {
  for t in knowledge_ingestion_job knowledge_document knowledge_document_version knowledge_dataset; do echo "  $t source_app: $(P "select source_app from $t")"; done
  echo "  dataset: $(P "select bucket||' '||object_key from knowledge_dataset")"
  echo "  source_uri: $(P "select source_uri from knowledge_document_version")"
  echo "  canonical_url: $(P "select canonical_url from knowledge_ingestion_job")"
}
echo "== 旧末端 + 模拟数据"; snap
.venv/bin/alembic upgrade head >/dev/null 2>&1; echo "== upgrade head（$(P 'select version_num from alembic_version')）"; snap
.venv/bin/alembic downgrade 20260927_0007 >/dev/null 2>&1; echo "== downgrade（$(P 'select version_num from alembic_version')）"; snap
