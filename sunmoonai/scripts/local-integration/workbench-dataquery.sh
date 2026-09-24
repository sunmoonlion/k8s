#!/usr/bin/env bash
# 问数评测（0007 第一批）：工作台（账房 + runner，进程内）→ 沙箱容器（带知识 MCP 配置）→ 会合点 → 本地代理 → 本机；
# 知识 MCP 由 knowledge-backend 的最小应用在本机起（uvicorn），沙箱经 host.docker.internal 访问。
# 看什么：1) 沙箱里的 Codex 能列出并调用 sunmoon_knowledge 的三个工具；2) 基线臂与 DATA_QUERY 臂各跑 N 案；
#         3) 判定只有 pass/fail/undecidable；4) 报告落 investment-backend/app/eval/reports/。
# 前提：workbench-chain.sh 的前提 + knowledge-backend 已 uv sync 且 datasets/ 里有 lesson23 sqlite。
# 用法：bash sunmoonai/scripts/local-integration/workbench-dataquery.sh [--limit N] [--arms baseline,pack] [--case-ids a,b]
set -o pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; K8S="$(cd "$HERE/../../.." && pwd)"; WS="$(cd "$K8S/.." && pwd)"
RUNTIME="$WS/runtime"; BACKEND="$WS/investment-app/investment-backend/app"; KNOWLEDGE="$WS/knowledge-app/knowledge-backend/app"
source "$RUNTIME/scripts/env-header.sh"
PY="$RUNTIME/.venv/bin/python"; IMAGE="${IMAGE:-sunmoon/sandbox:dev}"
RELAY_PORT=47100; APP_PORT=47800; MCP_PORT=47900; USER_ID=local; AGENT_TOKEN=agent-secret; SANDBOX_TOKEN=sandbox-secret
ROOT="$RUNTIME/probe/user-ws"; mkdir -p "$ROOT"; AGENT_HOME="$(mktemp -d /tmp/sunmoon-agent-it.XXXXXX)"; TOKDIR="$(mktemp -d /tmp/sunmoon-tok.XXXXXX)"
DB_URL="${AGENT_TEST_DATABASE_URL:-postgresql://t:t@127.0.0.1:55432/agent_tests}"
DATASET="${EVAL_DATASET:-$KNOWLEDGE/datasets/lesson23_business_analysis.sqlite}"
pids=(); kill_port() { ss -ltnp 2>/dev/null | grep ":$1 " | grep -o 'pid=[0-9]*' | cut -d= -f2 | sort -u | xargs -r kill 2>/dev/null; }
cleanup() { docker rm -f sandbox-dq >/dev/null 2>&1; for p in "${pids[@]}"; do kill "$p" 2>/dev/null; done; kill_port $MCP_PORT; kill_port $RELAY_PORT; rm -rf "$AGENT_HOME" "$TOKDIR"; }
trap cleanup EXIT

KEYFILE="${KEYFILE:-$HOME/.codex-probe-kimi/auth.json}"; [ -f "$KEYFILE" ] || { echo "缺 $KEYFILE"; exit 3; }
[ -f "$DATASET" ] || { echo "缺数据集 $DATASET（见 knowledge-backend/app/datasets/README.md）"; exit 3; }
(cd "$BACKEND" && uv run python -c "import asyncpg, psycopg" 2>/dev/null) || { echo "backend venv 没就绪（cd $BACKEND && uv sync）"; exit 3; }
(cd "$KNOWLEDGE" && uv run python -c "import uvicorn" 2>/dev/null) || { echo "knowledge venv 没就绪（cd $KNOWLEDGE && uv sync）"; exit 3; }
for port in $RELAY_PORT $APP_PORT $MCP_PORT; do ss -ltn | grep -q ":$port " && { echo "端口 $port 被占用"; exit 4; }; done
head -c 32 /dev/urandom | base64 | tr -d '=+/\n' > "$TOKDIR/token"; chmod 644 "$TOKDIR/token"; APP_TOKEN=$(cat "$TOKDIR/token")
MCP_TOKEN="kmcp-$(head -c 24 /dev/urandom | base64 | tr -d '=+/\n')"

echo "--- 0. 知识 MCP（本机 :$MCP_PORT，数据集 $(basename "$DATASET")）"
(cd "$KNOWLEDGE" && KNOWLEDGE_DATASET_PATH="$DATASET" KNOWLEDGE_MCP_TOKENS_JSON="{\"$MCP_TOKEN\":{\"user\":\"$USER_ID\",\"sandbox\":\"sandbox-dq\"}}" setsid uv run uvicorn app.bootstrap.mcp:app --host 0.0.0.0 --port $MCP_PORT --log-level warning > "$HERE/results/.mcp.log" 2>&1 < /dev/null & echo $! > "$TOKDIR/mcp.pid")
pids+=($(cat "$TOKDIR/mcp.pid"))
for i in $(seq 1 40); do ss -ltn | grep -q ":$MCP_PORT " && break; sleep 0.5; done
curl -s -o /dev/null -w "  MCP 未授权探测 HTTP %{http_code}\n" -X POST "http://127.0.0.1:$MCP_PORT/api/mcp/knowledge" -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","id":1,"method":"ping"}'
TOOLS=$(curl -s -X POST "http://127.0.0.1:$MCP_PORT/api/mcp/knowledge" -H "Authorization: Bearer $MCP_TOKEN" -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | python3 -c "import json,sys;print(','.join(t['name'] for t in json.load(sys.stdin)['result']['tools']))")
echo "  VERDICT MCP 授权后列出工具                                 $([ "$TOOLS" = "describe_schema,metric_definitions,run_sql" ] && echo pass || echo fail) $TOOLS"

echo "--- 1. 会合点"
RELAY_HOST=0.0.0.0 RELAY_PORT=$RELAY_PORT RELAY_TOKENS_JSON="{\"$USER_ID\":{\"agent\":\"$AGENT_TOKEN\",\"sandbox\":\"$SANDBOX_TOKEN\"}}" setsid "$PY" "$K8S/sunmoonai/relay-platform/relay/relay.py" > "$HERE/results/.relay.log" 2>&1 < /dev/null & pids+=($!)
for i in $(seq 1 20); do ss -ltn | grep -q ":$RELAY_PORT " && break; sleep 0.5; done
echo "--- 2. 本地代理（白名单 $ROOT）"
export SUNMOON_AGENT_HOME="$AGENT_HOME"
node "$RUNTIME/agent/dist/cli.js" init --relay "ws://127.0.0.1:$RELAY_PORT" --user $USER_ID --token $AGENT_TOKEN --root "$ROOT" >/dev/null
setsid node "$RUNTIME/agent/dist/cli.js" start > "$HERE/results/.agent.log" 2>&1 < /dev/null & pids+=($!)
for i in $(seq 1 40); do grep -q '"relay connected"' "$HERE/results/.agent.log" 2>/dev/null && break; sleep 0.5; done
grep -q '"relay connected"' "$HERE/results/.agent.log" || { echo "代理没连上"; cat "$HERE/results/.agent.log"; exit 6; }
echo "--- 3. 沙箱容器（含知识 MCP 配置）"
MODEL_KEY=$(python3 -c "import json;print(json.load(open('$KEYFILE'))['OPENAI_API_KEY'])")
docker run -d --name sandbox-dq --add-host=host.docker.internal:host-gateway -p 127.0.0.1:$APP_PORT:47800 -e RELAY_URL="ws://host.docker.internal:$RELAY_PORT" -e RELAY_USER=$USER_ID -e RELAY_TOKEN=$SANDBOX_TOKEN -e OPENAI_API_KEY="$MODEL_KEY" -e MODEL_PROVIDER=kimi -e MODEL=kimi-k3 -e PROVIDER_BASE_URL=https://api.moonshot.cn/v1 -e APP_SERVER_TOKEN_FILE=/secrets/token -e KNOWLEDGE_MCP_URL="http://host.docker.internal:$MCP_PORT/api/mcp/knowledge" -e KNOWLEDGE_MCP_TOKEN="$MCP_TOKEN" -v "$TOKDIR/token:/secrets/token:ro" "$IMAGE" >/dev/null
unset MODEL_KEY
for i in $(seq 1 40); do ss -ltn | grep -q ":$APP_PORT " && docker logs sandbox-dq 2>&1 | grep -q "listening on" && break; sleep 0.5; done; sleep 1
docker exec sandbox-dq sh -c 'grep -A3 "mcp_servers.sunmoon_knowledge" "$CODEX_HOME/config.toml" 2>/dev/null || grep -A3 sunmoon_knowledge /data/codex/config.toml' | sed 's/^/  config: /'
echo "--- 4. 评测"
(cd "$BACKEND" && AGENT_TEST_DATABASE_URL="$DB_URL" APP_SERVER_URL="ws://127.0.0.1:$APP_PORT" APP_SERVER_TOKEN="$APP_TOKEN" ROOT="$ROOT" EVAL_DATASET="$DATASET" timeout 3600 uv run python -m eval.run_eval "$@" 2>&1 | grep --line-buffered -v "sk-")
rc=${PIPESTATUS[0]}
echo "--- 日志尾部"; echo "[mcp]"; grep -v "sk-" "$HERE/results/.mcp.log" | tail -5 | cut -c1-200; echo "[sandbox]"; docker logs sandbox-dq 2>&1 | grep -v "sk-" | tail -4 | cut -c1-200
rm -f "$HERE/results/.relay.log" "$HERE/results/.agent.log" "$HERE/results/.mcp.log"
exit $rc
