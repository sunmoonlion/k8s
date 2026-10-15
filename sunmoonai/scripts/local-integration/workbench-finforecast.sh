#!/usr/bin/env bash
# 财务分析与预测评测（0023 第六节）：与 workbench-dataquery.sh 同一条链——工作台（账房 + runner，进程内）
# → 沙箱容器（带知识 MCP 配置）→ 会合点 → 本地代理 → 本机。区别三处：数据集是知识服务生成的 Olist 1/20 样例
# （olist-ecommerce）；知识 MCP 打开语义层（DuckDB 方言，与题的真值一致）；默认只跑专家臂、十题、预算 20。
# 看什么：1) 沙箱里的 Codex 能调用 sunmoon_knowbase 的工具并查到 olist-ecommerce；2) FIN_FORECAST 五步跑完；
#         3) 判定只有 pass/fail/undecidable；4) 报告落 investment-backend/app/eval/reports/，成稿落 $ROOT。
# 前提：workbench-chain.sh 的前提 + knowbase-backend、investment-backend 已 uv sync；第一次会下载 Olist 的
#       九个 parquet（约 55 MB）到 ~/.cache/sunmoon-olist。
# 用法：bash sunmoonai/scripts/local-integration/workbench-finforecast.sh [run_eval 的参数，覆盖下面的默认值]
set -o pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; K8S="$(cd "$HERE/../../.." && pwd)"; WS="$(cd "$K8S/.." && pwd)"
RUNTIME="$WS/runtime"; BACKEND="$WS/investment-app/investment-backend/app"; KNOWBASE="$WS/knowbase-app/knowbase-backend/app"
source "$RUNTIME/scripts/env-header.sh"
PY="$RUNTIME/.venv/bin/python"; IMAGE="${IMAGE:-sunmoon/sandbox:dev}"
RELAY_PORT=47100; APP_PORT=47800; MCP_PORT=47900; USER_ID=local; AGENT_TOKEN=agent-secret; SANDBOX_TOKEN=sandbox-secret
ROOT="$RUNTIME/probe/user-ws"; mkdir -p "$ROOT"; AGENT_HOME="$(mktemp -d /tmp/sunmoon-agent-it.XXXXXX)"; TOKDIR="$(mktemp -d /tmp/sunmoon-tok.XXXXXX)"
DB_URL="${AGENT_TEST_DATABASE_URL:-postgresql://t:t@127.0.0.1:55432/agent_tests}"
OLIST_CACHE="${OLIST_CACHE:-$HOME/.cache/sunmoon-olist}"; DATASET="$OLIST_CACHE/olist-ecommerce.sqlite"
pids=(); kill_port() { ss -ltnp 2>/dev/null | grep ":$1 " | grep -o 'pid=[0-9]*' | cut -d= -f2 | sort -u | xargs -r kill 2>/dev/null; }
cleanup() { docker rm -f sandbox-ff >/dev/null 2>&1; for p in "${pids[@]}"; do kill "$p" 2>/dev/null; done; kill_port $MCP_PORT; kill_port $RELAY_PORT; rm -rf "$AGENT_HOME" "$TOKDIR"; }
trap cleanup EXIT

KEYFILE="${KEYFILE:-$HOME/.codex-probe-kimi/auth.json}"; [ -f "$KEYFILE" ] || { echo "缺 $KEYFILE"; exit 3; }
(cd "$BACKEND" && uv run python -c "import asyncpg, psycopg" 2>/dev/null) || { echo "backend venv 没就绪（cd $BACKEND && uv sync）"; exit 3; }
(cd "$KNOWBASE" && uv run python -c "import uvicorn" 2>/dev/null) || { echo "knowledge venv 没就绪（cd $KNOWBASE && uv sync）"; exit 3; }
for port in $RELAY_PORT $APP_PORT $MCP_PORT; do ss -ltn | grep -q ":$port " && { echo "端口 $port 被占用"; exit 4; }; done
echo "--- 0a. 生成样例数据集（已有缓存就只核对）"
(cd "$KNOWBASE" && uv run python -m scripts.build_olist_dataset --cache "$OLIST_CACHE/parquet" --out "$DATASET") | tee "$TOKDIR/build.json" | tail -1
grep -q '"data_version": "olist-ecommerce-dcca129e2ea0cb56"' "$TOKDIR/build.json" \
  && echo "  VERDICT 样例的数据版本与评测题一致                         pass" \
  || { echo "  VERDICT 样例的数据版本与评测题一致                         fail（题冻结在 olist-ecommerce-dcca129e2ea0cb56）"; exit 5; }
SEMANTIC_CACHE="$(mktemp -d /tmp/sunmoon-semantic.XXXXXX)"
head -c 32 /dev/urandom | base64 | tr -d '=+/\n' > "$TOKDIR/token"; chmod 644 "$TOKDIR/token"; APP_TOKEN=$(cat "$TOKDIR/token")
MCP_TOKEN="kmcp-$(head -c 24 /dev/urandom | base64 | tr -d '=+/\n')"

echo "--- 0. 知识 MCP（本机 :$MCP_PORT，数据集 $(basename "$DATASET")）"
(cd "$KNOWBASE" && KNOWBASE_DATASET_PATH="$DATASET" KNOWBASE_DATASET_ID=olist-ecommerce KNOWBASE_DATASET_TITLE="巴西电商 Olist 样例（1/20 抽样，演示与评测用，CC BY-NC-SA 4.0）" KNOWBASE_SEMANTIC_ENGINE_ENABLED=true KNOWBASE_SEMANTIC_CACHE_DIR="$SEMANTIC_CACHE" KNOWBASE_MCP_TOKENS_JSON="{\"$MCP_TOKEN\":{\"user\":\"$USER_ID\",\"sandbox\":\"sandbox-ff\"}}" setsid uv run uvicorn app.bootstrap.mcp:app --host 0.0.0.0 --port $MCP_PORT --log-level warning > "$HERE/results/.mcp.log" 2>&1 < /dev/null & echo $! > "$TOKDIR/mcp.pid")
pids+=($(cat "$TOKDIR/mcp.pid"))
for i in $(seq 1 40); do ss -ltn | grep -q ":$MCP_PORT " && break; sleep 0.5; done
curl -s -o /dev/null -w "  MCP 未授权探测 HTTP %{http_code}\n" -X POST "http://127.0.0.1:$MCP_PORT/api/mcp/knowledge" -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","id":1,"method":"ping"}'
TOOLS=$(curl -s -X POST "http://127.0.0.1:$MCP_PORT/api/mcp/knowledge" -H "Authorization: Bearer $MCP_TOKEN" -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | python3 -c "import json,sys;print(','.join(t['name'] for t in json.load(sys.stdin)['result']['tools']))")
echo "  VERDICT MCP 授权后列出工具（含 list_datasets）               $(echo ",$TOOLS," | grep -q ',list_datasets,' && echo ",$TOOLS," | grep -q ',run_sql,' && echo pass || echo fail) $TOOLS"
LISTED=$(curl -s -X POST "http://127.0.0.1:$MCP_PORT/api/mcp/knowledge" -H "Authorization: Bearer $MCP_TOKEN" -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"list_datasets","arguments":{}}}' | python3 -c "import json,sys;r=json.load(sys.stdin)['result'];print(','.join(d['dataset']+'@'+str(d['data_version']) for d in r['structuredContent']['datasets']))")
echo "  VERDICT MCP 列到样例数据集                                 $(echo "$LISTED" | grep -q 'olist-ecommerce@olist-ecommerce-dcca129e2ea0cb56' && echo pass || echo fail) $LISTED"

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
docker run -d --name sandbox-ff --add-host=host.docker.internal:host-gateway -p 127.0.0.1:$APP_PORT:47800 -e RELAY_URL="ws://host.docker.internal:$RELAY_PORT" -e RELAY_USER=$USER_ID -e RELAY_TOKEN=$SANDBOX_TOKEN -e OPENAI_API_KEY="$MODEL_KEY" -e MODEL_PROVIDER=kimi -e MODEL=kimi-k3 -e PROVIDER_BASE_URL=https://api.moonshot.cn/v1 -e APP_SERVER_TOKEN_FILE=/secrets/token -e KNOWBASE_MCP_URL="http://host.docker.internal:$MCP_PORT/api/mcp/knowledge" -e KNOWBASE_MCP_TOKEN="$MCP_TOKEN" -v "$TOKDIR/token:/secrets/token:ro" "$IMAGE" >/dev/null
unset MODEL_KEY
for i in $(seq 1 40); do ss -ltn | grep -q ":$APP_PORT " && docker logs sandbox-ff 2>&1 | grep -q "listening on" && break; sleep 0.5; done; sleep 1
docker exec sandbox-ff sh -c 'grep -A3 "mcp_servers.sunmoon_knowbase" "$CODEX_HOME/config.toml" 2>/dev/null || grep -A3 sunmoon_knowbase /data/codex/config.toml' | sed 's/^/  config: /'
echo "--- 4. 评测"
(cd "$BACKEND" && AGENT_TEST_DATABASE_URL="$DB_URL" APP_SERVER_URL="ws://127.0.0.1:$APP_PORT" APP_SERVER_TOKEN="$APP_TOKEN" ROOT="$ROOT" EVAL_DATASET="$DATASET" timeout 7200 uv run python -m eval.run_eval --cases fin_forecast_10 --profile FIN_FORECAST --dataset-id olist-ecommerce --dialect duckdb --arms pack --limit 10 --budget 20 "$@" 2>&1 | grep --line-buffered -v "sk-")
rc=${PIPESTATUS[0]}
echo "--- 日志尾部"; echo "[mcp]"; grep -v "sk-" "$HERE/results/.mcp.log" | tail -5 | cut -c1-200; echo "[sandbox]"; docker logs sandbox-ff 2>&1 | grep -v "sk-" | tail -4 | cut -c1-200
echo "--- 成稿（ROOT=$ROOT）"; find "$ROOT" -name '*财务分析与预测-成稿.md' -o -name '交回.md' 2>/dev/null | head -20
rm -rf "$SEMANTIC_CACHE"
rm -f "$HERE/results/.relay.log" "$HERE/results/.agent.log" "$HERE/results/.mcp.log"
exit $rc
