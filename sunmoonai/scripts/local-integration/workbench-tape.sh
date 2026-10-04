#!/usr/bin/env bash
# 录磁带：用真的 Codex 跑几段像样的对话（聊天、项目里的聊天、工作），把对面发来的原始消息按轮次存下来。
# 预览的样例里，聊天与工作页显示的事件由它重放而来（investment-backend tests/test_preview_fixtures.py）。
# 前提与 workbench-chain.sh 相同。每录一次花一点模型费用。
# 用法：TAPE_OUT=<文件> bash sunmoonai/scripts/local-integration/workbench-tape.sh   （在 k8s 仓根）
#      不给 TAPE_OUT 就写到 investment-backend 的 tests/preview_tapes/conversations.json
set -o pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; K8S="$(cd "$HERE/../../.." && pwd)"; WS="$(cd "$K8S/.." && pwd)"
RUNTIME="$WS/runtime"; BACKEND="$WS/investment-app/investment-backend/app"
source "$RUNTIME/scripts/env-header.sh"
PY="$RUNTIME/.venv/bin/python"; IMAGE="${IMAGE:-sunmoon/sandbox:dev}"
RELAY_PORT=47100; APP_PORT=47800; USER_ID=local; AGENT_TOKEN=agent-secret; SANDBOX_TOKEN=sandbox-secret
# 项目目录放在任何代码仓库之外：Codex 会读上级目录里的 AGENTS.md，放在仓库里会把仓库的说明带进对话
ROOT="${TAPE_ROOT:-$HOME/.cache/sunmoon-tape/research}"; mkdir -p "$ROOT"; AGENT_HOME="$(mktemp -d /tmp/sunmoon-agent-it.XXXXXX)"; TOKDIR="$(mktemp -d /tmp/sunmoon-tok.XXXXXX)"
DB_URL="${AGENT_TEST_DATABASE_URL:-postgresql://t:t@127.0.0.1:55432/agent_tests}"
TAPE_OUT="${TAPE_OUT:-$BACKEND/tests/preview_tapes/conversations.json}"
pids=(); cleanup() { docker rm -f sandbox-tape >/dev/null 2>&1; for p in "${pids[@]}"; do kill "$p" 2>/dev/null; done; rm -rf "$AGENT_HOME" "$TOKDIR"; }
trap cleanup EXIT

echo "--- 依赖"
for f in "$PY" "$RUNTIME/agent/dist/cli.js" "$K8S/sunmoonai/relay-platform/relay/relay.py" "$K8S/sunmoonai/sandbox-platform/bridge/sandbox_bridge.py" "$BACKEND/tests/drivers/workbench_tape_driver.py"; do [ -e "$f" ] || { echo "缺 $f"; exit 3; }; done
docker image inspect "$IMAGE" >/dev/null 2>&1 || { echo "没有镜像 $IMAGE"; exit 3; }
KEYFILE="${KEYFILE:-$HOME/.codex-probe-kimi/auth.json}"; [ -f "$KEYFILE" ] || { echo "缺 $KEYFILE"; exit 3; }
(cd "$BACKEND" && uv run python -c "import asyncpg, psycopg" 2>/dev/null) || { echo "backend venv 没就绪（cd $BACKEND && uv sync）"; exit 3; }
for port in $RELAY_PORT $APP_PORT; do ss -ltn | grep -q ":$port " && { echo "端口 $port 被占用"; exit 4; }; done
head -c 32 /dev/urandom | base64 | tr -d '=+/\n' > "$TOKDIR/token"; chmod 644 "$TOKDIR/token"; APP_TOKEN=$(cat "$TOKDIR/token")

echo "--- 1. 会合点"
RELAY_HOST=0.0.0.0 RELAY_PORT=$RELAY_PORT RELAY_TOKENS_JSON="{\"$USER_ID\":{\"agent\":\"$AGENT_TOKEN\",\"sandbox\":\"$SANDBOX_TOKEN\"}}" setsid "$PY" "$K8S/sunmoonai/relay-platform/relay/relay.py" > "$HERE/results/.relay.log" 2>&1 < /dev/null & pids+=($!)
for i in $(seq 1 20); do ss -ltn | grep -q ":$RELAY_PORT " && break; sleep 0.5; done
echo "--- 2. 本地代理（白名单 $ROOT）"
export SUNMOON_AGENT_HOME="$AGENT_HOME"
node "$RUNTIME/agent/dist/cli.js" init --relay "ws://127.0.0.1:$RELAY_PORT" --user $USER_ID --token $AGENT_TOKEN --root "$ROOT" >/dev/null
setsid node "$RUNTIME/agent/dist/cli.js" start > "$HERE/results/.agent.log" 2>&1 < /dev/null & pids+=($!)
for i in $(seq 1 40); do grep -q '"relay connected"' "$HERE/results/.agent.log" 2>/dev/null && break; sleep 0.5; done
grep -q '"relay connected"' "$HERE/results/.agent.log" || { echo "代理没连上"; cat "$HERE/results/.agent.log"; exit 6; }
echo "--- 3. 沙箱容器"
MODEL_KEY=$(python3 -c "import json;print(json.load(open('$KEYFILE'))['OPENAI_API_KEY'])")
docker run -d --name sandbox-tape --add-host=host.docker.internal:host-gateway -p 127.0.0.1:$APP_PORT:47800 -e RELAY_URL="ws://host.docker.internal:$RELAY_PORT" -e RELAY_USER=$USER_ID -e RELAY_TOKEN=$SANDBOX_TOKEN -e OPENAI_API_KEY="$MODEL_KEY" -e MODEL_PROVIDER=kimi -e MODEL=kimi-k3 -e PROVIDER_BASE_URL=https://api.moonshot.cn/v1 -e APP_SERVER_TOKEN_FILE=/secrets/token -v "$TOKDIR/token:/secrets/token:ro" "$IMAGE" >/dev/null
unset MODEL_KEY
for i in $(seq 1 40); do ss -ltn | grep -q ":$APP_PORT " && docker logs sandbox-tape 2>&1 | grep -q "listening on" && break; sleep 0.5; done; sleep 1
echo "--- 4. 工作台驱动整条链"
(cd "$BACKEND" && AGENT_TEST_DATABASE_URL="$DB_URL" APP_SERVER_URL="ws://127.0.0.1:$APP_PORT" APP_SERVER_TOKEN="$APP_TOKEN" ROOT="$ROOT" TAPE_OUT="$TAPE_OUT" timeout 1500 uv run python tests/drivers/workbench_tape_driver.py 2>&1 | grep -v "sk-")
rc=${PIPESTATUS[0]}
# 查问题用：KEEP_DIR=<目录> 时，把沙箱里这条线的记录与两份日志留一份（去掉含 key 的行）。目录不要放在仓库里
if [ -n "${KEEP_DIR:-}" ]; then
  mkdir -p "$KEEP_DIR"; chmod 700 "$KEEP_DIR"
  for f in $(docker exec sandbox-tape sh -c 'find / -name "rollout-*.jsonl" 2>/dev/null'); do docker exec sandbox-tape cat "$f" | grep -v "sk-" > "$KEEP_DIR/$(basename "$f")"; done
  grep -v "sk-" "$HERE/results/.agent.log" > "$KEEP_DIR/agent.log"; docker logs sandbox-tape 2>&1 | grep -v "sk-" > "$KEEP_DIR/sandbox.log"
fi
echo "--- 日志尾部"; echo "[agent]"; tail -4 "$HERE/results/.agent.log" | cut -c1-200; echo "[sandbox]"; docker logs sandbox-tape 2>&1 | grep -v "sk-" | tail -4 | cut -c1-200
rm -f "$HERE/results/.relay.log" "$HERE/results/.agent.log"
exit $rc
