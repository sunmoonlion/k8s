#!/usr/bin/env bash
# 本机联调：证券代码 → info 采集建库 → 对象存储 → 向知识服务登记 → 知识服务取文件 → MCP 查询。
#
# 不连任何集群。用一次性的容器（对象存储、缓存）和一个已有的 PostgreSQL 容器里的两个新库。
# 口令每次随机生成，只放在状态目录里（0600），不进仓库、不进结果文件。
#
# 用法：run.sh up | ingest <代码> | build <代码> | driver verify <代码> | negative <代码> | queued <代码> | down
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${WORKSPACE:-$HOME/worktrees/fable}"
INFO="$WORKSPACE/info-app/info-backend/app"
KNOW="$WORKSPACE/knowledge-app/knowledge-backend/app"
STATE="${DATASET_CHAIN_STATE:-$HOME/.cache/sunmoon-dataset-chain}"
PG_CONTAINER="${PG_CONTAINER:-pgtest}"
PG_URL_BASE="${PG_URL_BASE:-postgresql://t:t@127.0.0.1:55432}"
S3_IMAGE="${S3_IMAGE:-bitnamilegacy/minio:2025.7.23}"
REDIS_IMAGE="${REDIS_IMAGE:-redis:7-alpine}"
S3_PORT=59000 REDIS_PORT=59379 OIDC_PORT=59080 KNOW_PORT=59001
INFO_BUCKET=development-info-originals
AUDIENCE=sunmoonai-knowledge-internal
SUBJECT=service/sunmoonai-info-knowledge-ingest

say() { printf '%s\n' "$*" >&2; }
secret() { head -c 24 /dev/urandom | base64 | tr -d '/+=' | cut -c1-28; }
wait_http() { for _ in $(seq 1 "${2:-40}"); do curl -s -o /dev/null -m 2 "$1" && return 0; sleep 1; done; return 1; }

load() { [ -f "$STATE/env" ] || { say "先运行 up"; exit 1; }; set -a; . "$STATE/env"; set +a; }

common_env() {
  cat <<ENV
ENV=development
REDIS_HOST=127.0.0.1
REDIS_PORT=$REDIS_PORT
S3_ENDPOINT=http://127.0.0.1:$S3_PORT
S3_REGION=us-east-1
S3_FORCE_PATH_STYLE=true
S3_USE_TLS=false
CASDOOR_VERIFY_SSL=false
ENV
}

up() {
  mkdir -p "$STATE"; chmod 700 "$STATE"
  if [ ! -f "$STATE/env" ]; then
    umask 077
    cat > "$STATE/env" <<ENV
S3_ROOT_USER=itroot
S3_ROOT_PASSWORD=$(secret)
INFO_S3_KEY=itinfo
INFO_S3_SECRET=$(secret)
KNOW_S3_KEY=itknowledge
KNOW_S3_SECRET=$(secret)
NOACCESS_S3_KEY=itnoaccess
NOACCESS_S3_SECRET=$(secret)
INFO_CLIENT_ID=it-info-client
INFO_CLIENT_SECRET=$(secret)
MCP_TOKEN=$(secret)
MCP_TOKEN_NARROW=$(secret)
ENV
  fi
  load
  docker rm -f it-s3 it-redis >/dev/null 2>&1 || true
  docker run -d --name it-s3 -p 127.0.0.1:$S3_PORT:9000 \
    -e MINIO_ROOT_USER="$S3_ROOT_USER" -e MINIO_ROOT_PASSWORD="$S3_ROOT_PASSWORD" \
    "$S3_IMAGE" >/dev/null
  docker run -d --name it-redis -p 127.0.0.1:$REDIS_PORT:6379 "$REDIS_IMAGE" >/dev/null
  wait_http "http://127.0.0.1:$S3_PORT/minio/health/live" 60 || { say "对象存储没起来"; exit 1; }

  # 桶开版本保留；info 可读写自己的桶，knowledge 对它只读，第三个账号什么都没有
  mc() { docker exec it-s3 mc "$@"; }
  mc alias set it "http://127.0.0.1:9000" "$S3_ROOT_USER" "$S3_ROOT_PASSWORD" >/dev/null
  mc mb --ignore-existing "it/$INFO_BUCKET" >/dev/null
  mc version enable "it/$INFO_BUCKET" >/dev/null
  docker exec -i it-s3 sh -c 'cat > /tmp/info-rw.json' <<JSON
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["s3:GetObject","s3:GetObjectVersion","s3:PutObject","s3:ListBucket","s3:ListBucketVersions","s3:GetBucketLocation"],"Resource":["arn:aws:s3:::$INFO_BUCKET","arn:aws:s3:::$INFO_BUCKET/*"]}]}
JSON
  docker exec -i it-s3 sh -c 'cat > /tmp/info-ro.json' <<JSON
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["s3:GetObject","s3:GetObjectVersion"],"Resource":["arn:aws:s3:::$INFO_BUCKET/*"]}]}
JSON
  mc admin policy create it info-rw /tmp/info-rw.json >/dev/null
  mc admin policy create it info-ro /tmp/info-ro.json >/dev/null
  mc admin user add it "$INFO_S3_KEY" "$INFO_S3_SECRET" >/dev/null
  mc admin user add it "$KNOW_S3_KEY" "$KNOW_S3_SECRET" >/dev/null
  mc admin user add it "$NOACCESS_S3_KEY" "$NOACCESS_S3_SECRET" >/dev/null
  mc admin policy attach it info-rw --user "$INFO_S3_KEY" >/dev/null
  mc admin policy attach it info-ro --user "$KNOW_S3_KEY" >/dev/null

  for db in it_info it_knowledge; do
    docker exec "$PG_CONTAINER" psql -U t -d postgres -qc "DROP DATABASE IF EXISTS $db WITH (FORCE)" -c "CREATE DATABASE $db" >/dev/null 2>&1
  done
  # info 的迁移链要求库里预先装好 uuid-ossp（它自己不建；knowledge 的迁移链自己建）。
  # 这里替平台的数据库供给步骤做这件事。新集群上要由供给步骤保证，见待办账本。
  docker exec "$PG_CONTAINER" psql -U t -d it_info -qc 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public' >/dev/null
  say "从空库跑迁移：info"
  (cd "$INFO" && DATABASE_URL="$PG_URL_BASE/it_info" ENV=development uv run alembic upgrade head 2>&1 | tail -1 >&2)
  say "从空库跑迁移：knowledge"
  (cd "$KNOW" && DATABASE_URL="$PG_URL_BASE/it_knowledge" ENV=development uv run alembic upgrade head 2>&1 | tail -1 >&2)

  umask 077
  python3 - "$STATE" <<PY
import json, os, sys
state = sys.argv[1]
e = dict(l.strip().split("=", 1) for l in open(f"{state}/env") if "=" in l)
json.dump({e["INFO_CLIENT_ID"]: {"secret": e["INFO_CLIENT_SECRET"], "subject": "$SUBJECT", "audience": "$AUDIENCE"}}, open(f"{state}/clients.json", "w"))
tokens = {
    e["MCP_TOKEN"]: {"user": "it-expert", "sandbox": "it", "tools": None},
    e["MCP_TOKEN_NARROW"]: {"user": "it-narrow", "sandbox": "it", "tools": ["describe_schema"]},
}
json.dump(tokens, open(f"{state}/mcp-tokens.json", "w"))
PY
  pkill_port $OIDC_PORT; pkill_port $KNOW_PORT
  spawn "$STATE/oidc.log" /dev/null "$KNOW" .venv/bin/python "$HERE/oidc_standin.py" --port $OIDC_PORT --clients "$STATE/clients.json"
  wait_http "http://127.0.0.1:$OIDC_PORT/jwks" 20 || { say "身份服务替身没起来"; exit 1; }
  start_knowledge
  say "就绪"
}

# 后台进程与调用它的命令行彻底脱开：不继承输出管道，否则调用方永远等不到结束
spawn() {
  local log="$1" envfile="$2" dir="$3"; shift 3
  (
    cd "$dir"
    if [ "$envfile" != /dev/null ]; then set -a; . "$envfile"; set +a; fi
    exec setsid "$@"
  ) > "$log" 2>&1 < /dev/null &
  disown
}

pkill_port() {
  local pid
  pid="$(ss -ltnpH "sport = :$1" 2>/dev/null | grep -oE 'pid=[0-9]+' | head -1 | cut -d= -f2 || true)"
  [ -z "$pid" ] || kill "$pid" 2>/dev/null || true
}

knowledge_env() {
  common_env
  cat <<ENV
DATABASE_URL=$PG_URL_BASE/it_knowledge
S3_ACCESS_KEY_ID=${KNOW_S3_KEY_OVERRIDE:-$KNOW_S3_KEY}
S3_SECRET_ACCESS_KEY=${KNOW_S3_SECRET_OVERRIDE:-$KNOW_S3_SECRET}
KNOWLEDGE_DATASET_REGISTRY_ENABLED=${REGISTRY_ENABLED:-true}
KNOWLEDGE_DATASET_ALLOWED_BUCKETS=${ALLOWED_BUCKETS:-$INFO_BUCKET}
KNOWLEDGE_DATASET_CACHE_DIR=$STATE/knowledge-datasets
KNOWLEDGE_SEMANTIC_ENGINE_ENABLED=true
KNOWLEDGE_SEMANTIC_CACHE_DIR=$STATE/knowledge-semantic
KNOWLEDGE_MCP_TOKENS_JSON='$(cat "$STATE/mcp-tokens.json")'
INTERNAL_AUTH_DISCOVERY_URL=http://127.0.0.1:$OIDC_PORT/.well-known/openid-configuration
INTERNAL_AUTH_AUDIENCE=$AUDIENCE
INTERNAL_AUTH_SUBJECT_ALLOWLIST=${SUBJECT_ALLOWLIST:-$SUBJECT}
ENV
}

start_knowledge() {
  load
  pkill_port $KNOW_PORT; sleep 1
  mkdir -p "$STATE/knowledge-datasets" "$STATE/knowledge-semantic"
  knowledge_env > "$STATE/knowledge.env"; chmod 600 "$STATE/knowledge.env"
  spawn "$STATE/knowledge.log" "$STATE/knowledge.env" "$KNOW" .venv/bin/uvicorn app.bootstrap.api:app --host 127.0.0.1 --port $KNOW_PORT
  wait_http "http://127.0.0.1:$KNOW_PORT/api/internal/v1/knowledge/datasets" 60 || { say "知识服务没起来，见 $STATE/knowledge.log"; tail -5 "$STATE/knowledge.log" >&2; exit 1; }
}

info_env() {
  common_env
  cat <<ENV
DATABASE_URL=$PG_URL_BASE/it_info
STORAGE_BACKEND=s3
S3_BUCKET=$INFO_BUCKET
S3_ACCESS_KEY_ID=$INFO_S3_KEY
S3_SECRET_ACCESS_KEY=$INFO_S3_SECRET
KNOWLEDGE_APP_DATASET_URL=http://127.0.0.1:$KNOW_PORT/api/internal/v1/knowledge/datasets
KNOWLEDGE_APP_SERVICE_DISCOVERY_URL=http://127.0.0.1:$OIDC_PORT/.well-known/openid-configuration
KNOWLEDGE_APP_SERVICE_CLIENT_ID=$INFO_CLIENT_ID
KNOWLEDGE_APP_SERVICE_CLIENT_SECRET=${INFO_CLIENT_SECRET_OVERRIDE:-$INFO_CLIENT_SECRET}
CELERY_BROKER_URL=redis://127.0.0.1:$REDIS_PORT/1
CELERY_QUEUE=info-it
ENV
}

info_cli() {
  load
  info_env > "$STATE/info.env"; chmod 600 "$STATE/info.env"
  (cd "$INFO" && set -a && . "$STATE/info.env" && set +a && uv run python -m "$@")
}

register_once() {
  load
  info_env > "$STATE/info.env"; chmod 600 "$STATE/info.env"
  (cd "$INFO" && set -a && . "$STATE/info.env" && set +a && PYTHONPATH="$INFO" .venv/bin/python "$HERE/register_once.py" "$1" 2>/dev/null | tail -1)
}

# 一种出错的情况：按给定的设置重启知识服务（或不重启），登记一次，看结果是不是预期的错误码
expect() {
  local title="$1" want="$2" code="$3" got
  got="$(register_once "$code")"
  if printf '%s' "$got" | python3 -c "
import json,sys
want=sys.argv[1]; r=json.loads(sys.stdin.read())
ok = (r['error'] is None and r['registered'] and r['recorded_at'] and r['recorded_error'] is None) if want=='ok' else (r['error']==want and r['recorded_error']==want)
sys.exit(0 if ok else 1)" "$want"; then
    printf '通过 | %s | %s\n' "$title" "$want"
  else
    printf '未过 | %s | 期望 %s，实际 %s\n' "$title" "$want" "$got"; FAILED=$((FAILED+1))
  fi
}

negative() {
  local code="$1"; FAILED=0
  load
  expect "同一版本再登记一次（幂等）" ok "$code"
  local rows; rows="$(docker exec "$PG_CONTAINER" psql -U t -d it_knowledge -Atc "select count(*) from knowledge_dataset")"
  [ "$rows" = 1 ] && echo "通过 | 知识服务的登记表仍然只有一行" || { echo "未过 | 知识服务的登记表有 $rows 行"; FAILED=$((FAILED+1)); }

  REGISTRY_ENABLED=false start_knowledge
  expect "知识服务的登记开关关着" knowledge_registry_disabled "$code"
  ALLOWED_BUCKETS=some-other-bucket start_knowledge
  expect "对象所在的桶不在知识服务的允许清单里" knowledge_refused_registration "$code"
  SUBJECT_ALLOWLIST=service/someone-else start_knowledge
  expect "info 的服务身份没有被知识服务绑定" knowledge_rejected_identity "$code"
  start_knowledge
  INFO_CLIENT_SECRET_OVERRIDE=wrong-secret expect "info 拿错的口令去换令牌" service_token_unavailable "$code"
  pkill_port $OIDC_PORT; sleep 1
  expect "身份服务不在" service_token_unavailable "$code"
  spawn "$STATE/oidc.log" /dev/null "$KNOW" .venv/bin/python "$HERE/oidc_standin.py" --port $OIDC_PORT --clients "$STATE/clients.json"
  wait_http "http://127.0.0.1:$OIDC_PORT/jwks" 20
  pkill_port $KNOW_PORT; sleep 1
  expect "知识服务不在" knowledge_unreachable "$code"

  start_knowledge
  expect "各项恢复后登记成功，之前记下的错误被清掉" ok "$code"

  # 身份服务的替身每次启动都换签名密钥：知识服务不重启，要能自己重新取公钥
  pkill_port $OIDC_PORT; sleep 1
  spawn "$STATE/oidc.log" /dev/null "$KNOW" .venv/bin/python "$HERE/oidc_standin.py" --port $OIDC_PORT --clients "$STATE/clients.json"
  wait_http "http://127.0.0.1:$OIDC_PORT/jwks" 20
  expect "身份服务换了签名密钥，知识服务不重启也能验" ok "$code"

  # 知识服务的存储账号没有权限：专家得到的是一句不含内部细节的话
  rm -rf "$STATE/knowledge-datasets" "$STATE/knowledge-semantic"
  KNOW_S3_KEY_OVERRIDE="$NOACCESS_S3_KEY" KNOW_S3_SECRET_OVERRIDE="$NOACCESS_S3_SECRET" start_knowledge
  (cd "$KNOW" && STATE="$STATE" KNOW_PORT=$KNOW_PORT S3_PORT=$S3_PORT INFO_BUCKET=$INFO_BUCKET .venv/bin/python "$HERE/driver.py" storage-denied "$code") || FAILED=$((FAILED+1))

  # 有人往同一个键写了别的内容：知识服务钉住的是登记时的那个版本
  rm -rf "$STATE/knowledge-datasets" "$STATE/knowledge-semantic"
  start_knowledge
  (cd "$KNOW" && STATE="$STATE" KNOW_PORT=$KNOW_PORT S3_PORT=$S3_PORT INFO_BUCKET=$INFO_BUCKET .venv/bin/python "$HERE/driver.py" overwritten "$code") || FAILED=$((FAILED+1))
  if [ -f "$STATE/junk-version" ]; then  # 联调自己写进去的那个版本，用管理账号清掉
    docker exec it-s3 mc rm --quiet --version-id "$(sed -n 2p "$STATE/junk-version")" "it/$INFO_BUCKET/$(sed -n 1p "$STATE/junk-version")" >/dev/null
    rm -f "$STATE/junk-version"
  fi

  echo "出错情况合计未过 $FAILED 项"
  [ "$FAILED" = 0 ]
}

stop_worker() {
  [ -f "$STATE/worker.pid" ] || return 0
  kill "$(cat "$STATE/worker.pid")" 2>/dev/null || true
  rm -f "$STATE/worker.pid"
}

# 生产上的走法：登记批次并排队 → 分发器把待办发给工作进程 → 采集、建库、登记三步接力。
# 任务队列在生产上是 RabbitMQ；这台机器上它的容器起不来（读不了自己的 cookie 文件），
# 这里用已有的缓存容器当队列。验证的是应用这一层的接力，不是队列本身。
queued() {
  local code="$1" waited=0 state=""
  load
  info_env > "$STATE/info.env"; chmod 600 "$STATE/info.env"
  stop_worker
  (
    cd "$INFO"; set -a; . "$STATE/info.env"; set +a
    exec setsid .venv/bin/celery -A app.bootstrap.worker:celery_app worker --loglevel=INFO --concurrency=1 --pidfile="$STATE/worker.pid"
  ) > "$STATE/worker.log" 2>&1 < /dev/null &
  disown
  for _ in $(seq 1 60); do grep -q "ready\." "$STATE/worker.log" 2>/dev/null && break; sleep 1; done
  grep -q "ready\." "$STATE/worker.log" || { say "工作进程没起来，见 $STATE/worker.log"; tail -5 "$STATE/worker.log" >&2; return 1; }
  (cd "$INFO" && set -a && . "$STATE/info.env" && set +a && PYTHONPATH="$INFO" .venv/bin/python "$HERE/enqueue_once.py" "$code" 2>/dev/null | tail -1) > "$STATE/queued-$code.json"
  say "已排队：$(cat "$STATE/queued-$code.json")"
  while [ "$waited" -lt "${QUEUED_TIMEOUT:-900}" ]; do
    (cd "$INFO" && set -a && . "$STATE/info.env" && set +a && .venv/bin/python -m app.cli.drain_delivery_outbox >/dev/null 2>&1) || true
    state="$(docker exec "$PG_CONTAINER" psql -U t -d it_info -Atc "select coalesce((select status from security_ingestion where security_code='$code' order by created_at desc limit 1),'-') || '|' || coalesce((select status || '/' || (knowledge_registered_at is not null)::text || '/' || coalesce(knowledge_registration_error,'') from security_dataset where security_code='$code' order by built_at desc limit 1),'-')")"
    case "$state" in
      *"|published/true/") say "完成：$state（${waited} 秒）"; stop_worker; return 0 ;;
      failed*|*"|quality_failed"*) say "停在：$state"; stop_worker; return 1 ;;
    esac
    sleep 10; waited=$((waited+10))
  done
  say "超时：$state"; stop_worker; return 1
}

down() {
  pkill_port $KNOW_PORT; pkill_port $OIDC_PORT; stop_worker
  docker rm -f it-s3 it-redis >/dev/null 2>&1 || true
  for db in it_info it_knowledge; do
    docker exec "$PG_CONTAINER" psql -U t -d postgres -qc "DROP DATABASE IF EXISTS $db WITH (FORCE)" >/dev/null 2>&1 || true
  done
  rm -rf "$STATE"
  say "已清理"
}

case "${1:-}" in
  up) up ;;
  down) down ;;
  ingest) info_cli app.cli.security_ingest --code "$2" ;;
  build) shift; info_cli app.cli.security_dataset --code "$1" --register ;;
  negative) negative "$2" ;;
  queued) queued "$2" ;;
  restart-knowledge) start_knowledge ;;
  restart-identity)
    load; pkill_port $OIDC_PORT; sleep 1
    spawn "$STATE/oidc.log" /dev/null "$KNOW" .venv/bin/python "$HERE/oidc_standin.py" --port $OIDC_PORT --clients "$STATE/clients.json"
    wait_http "http://127.0.0.1:$OIDC_PORT/jwks" 20 || { say "身份服务替身没起来"; exit 1; } ;;
  knowledge-log) tail -"${2:-20}" "$STATE/knowledge.log" ;;
  driver) shift; load; (cd "$KNOW" && STATE="$STATE" KNOW_PORT=$KNOW_PORT S3_PORT=$S3_PORT INFO_BUCKET=$INFO_BUCKET PG_URL_BASE="$PG_URL_BASE" \
            .venv/bin/python "$HERE/driver.py" "$@") ;;
  *) say "用法：run.sh up | ingest <代码> | build <代码> | driver verify <代码> | negative <代码> | queued <代码> | restart-knowledge | down"; exit 2 ;;
esac
