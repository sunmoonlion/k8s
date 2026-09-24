#!/usr/bin/env bash
# 本地预览栈的入口。子命令：init | up [core|full] | seed | agent | status | down [wipe]
# 要求：docker（含 compose v2）、node 20+（跑本地代理）、并列的四个仓 k8s / runtime / investment-app / knowledge-app。
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; cd "$HERE"
WS="${SUNMOON_WS:-$(cd "$HERE/../../../.." && pwd)}"   # 工位根：k8s 的上一级
rand() { head -c "$1" /dev/urandom | base64 | tr -d '=+/\n' | cut -c1-"$1"; }

cmd_init() {
  [ -f .env ] && { echo ".env 已存在，不覆盖（要重来先删 .env 与 secrets/）"; exit 1; }
  local backend="$WS/investment-app/investment-backend" web="$WS/investment-app/investment-web-frontend" know="$WS/knowledge-app/knowledge-backend/app"
  for d in "$backend/app/Dockerfile" "$web/mybuild/Dockerfile" "$know/Dockerfile" "$WS/runtime/agent"; do [ -e "$d" ] || { echo "缺 $d"; exit 3; }; done
  local dataset="$know/datasets/lesson23_business_analysis.sqlite"
  [ -f "$dataset" ] || echo "提醒：$dataset 不存在，知识 MCP 起不来；见 knowledge-backend/app/datasets/README.md"
  local auth="${MODEL_AUTH_JSON:-$HOME/.codex-probe-kimi/auth.json}"
  [ -f "$auth" ] || echo "提醒：$auth 不存在，沙箱起不来（BYOK 必需）"
  mkdir -p secrets; head -c 32 /dev/urandom | base64 | tr -d '=+/\n' > secrets/app-server-token; chmod 644 secrets/app-server-token
  local fernet; fernet="$(head -c 32 /dev/urandom | base64 | tr '+/' '-_')"
  cat > .env <<ENV
# 由 preview.sh init 生成；含随机令牌与演示密码，不进 git
INVESTMENT_BACKEND_DIR=$backend/app
INVESTMENT_WEB_FRONTEND_DIR=$web
KNOWLEDGE_BACKEND_DIR=$know
K8S_DIR=$WS/k8s
KNOWLEDGE_DATASET_DIR=$know/datasets
MODEL_AUTH_JSON=$auth
MODEL_PROVIDER=${MODEL_PROVIDER:-kimi}
MODEL=${MODEL:-kimi-k3}
PROVIDER_BASE_URL=${PROVIDER_BASE_URL:-https://api.moonshot.cn/v1}
PYPI_INDEX_URL=${PYPI_INDEX_URL:-https://pypi.tuna.tsinghua.edu.cn/simple}
RELAY_USER=local
RELAY_AGENT_TOKEN=$(rand 32)
RELAY_SANDBOX_TOKEN=$(rand 32)
KNOWLEDGE_MCP_TOKEN=kmcp-$(rand 32)
WEB_CLIENT_ID=$(rand 20)
WEB_CLIENT_SECRET=$(rand 40)
ADMIN_CLIENT_ID=$(rand 20)
ADMIN_CLIENT_SECRET=$(rand 40)
DEMO_USER=demo
DEMO_PASSWORD=demo-$(rand 8)
WORKBENCH_CREDENTIAL_KEY=$fernet
PREVIEW_ROOTS=${PREVIEW_ROOTS:-$HOME/research}
ENV
  chmod 600 .env
  echo "已生成 .env 与 secrets/。演示账号：$(grep '^DEMO_USER=' .env | cut -d= -f2) / $(grep '^DEMO_PASSWORD=' .env | cut -d= -f2)"
  echo "白名单根目录 PREVIEW_ROOTS=$(grep '^PREVIEW_ROOTS=' .env | cut -d= -f2)（改 .env 可换；目录要真实存在）"
}

cmd_up() {
  [ -f .env ] || { echo "先 bash preview.sh init"; exit 1; }
  local profile="${1:-full}"
  if [ "$profile" = full ]; then docker compose --profile full up -d --build; else docker compose up -d --build; fi
  cmd_status
}

cmd_seed() {
  set -a; . ./.env; set +a
  mkdir -p "$PREVIEW_ROOTS"
  docker compose exec -e PREVIEW_ROOTS="$PREVIEW_ROOTS" backend-api python /preview/seed_workbench.py
}

cmd_agent() {
  set -a; . ./.env; set +a
  local cli="$WS/runtime/agent/dist/cli.js"
  [ -f "$cli" ] || { echo "先在 $WS/runtime/agent 里 pnpm install && pnpm build"; exit 3; }
  export SUNMOON_AGENT_HOME="${SUNMOON_AGENT_HOME:-$HOME/.sunmoon-agent-preview}"
  mkdir -p "$PREVIEW_ROOTS"
  [ -f "$SUNMOON_AGENT_HOME/config.json" ] || node "$cli" init --relay ws://127.0.0.1:47100 --user "$RELAY_USER" --token "$RELAY_AGENT_TOKEN" --root "$PREVIEW_ROOTS"
  echo "代理前台运行，Ctrl-C 停；白名单 $PREVIEW_ROOTS；家 $SUNMOON_AGENT_HOME"
  exec node "$cli" start
}

cmd_status() {
  docker compose ps --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}'
  printf 'casdoor  '; curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8100/api/get-account || true
  printf 'backend  '; curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3000/api/health || true
  printf 'login    '; curl -s -o /dev/null -w '%{http_code} -> %{redirect_url}\n' http://127.0.0.1:3000/api/auth/web/login || true
  printf 'mcp      '; curl -s -o /dev/null -w '%{http_code}\n' -X POST http://127.0.0.1:47900/api/mcp/knowledge -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","id":1,"method":"ping"}' || true
}

cmd_down() { if [ "${1:-}" = wipe ]; then docker compose --profile full down -v; else docker compose --profile full down; fi; }

case "${1:-}" in
  init) cmd_init ;;
  up) cmd_up "${2:-full}" ;;
  seed) cmd_seed ;;
  agent) cmd_agent ;;
  status) cmd_status ;;
  down) cmd_down "${2:-}" ;;
  *) echo "用法: bash preview.sh init | up [core|full] | seed | agent | status | down [wipe]"; exit 2 ;;
esac
