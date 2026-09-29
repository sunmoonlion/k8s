#!/usr/bin/env bash
# 跨仓联调：聊天、工作在真的 Codex 上。同一条线，先聊天、再放进项目、再转成工作，权限每一轮跟着账走。
# 看什么：1) 没有项目、没有机器也能聊；2) 聊天里动不了手，也不来问用户；3) 放进项目后读得到文件，仍然动不了手；
#         4) 转成工作后动得了手；5) 从头到尾是同一条线，之前聊的还在；6) 换情形时向模型说明；7) 模型起不了子代理。
# 模型有随机性：「只读的拦截真的被碰到」要模型肯去试，偶尔不试就不过，重跑即可；其余各项不该随机。
# 前提与 workbench-chain.sh 相同：并列的四个仓；docker 有 sunmoon/sandbox:dev；Postgres 测试容器 pgtest；
#      Kimi key 在 ~/.codex-probe-kimi/auth.json。
# 用法：bash sunmoonai/scripts/local-integration/workbench-modes.sh   （在 k8s 仓根）
set -o pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; K8S="$(cd "$HERE/../../.." && pwd)"; WS="$(cd "$K8S/.." && pwd)"
RUNTIME="$WS/runtime"; BACKEND="$WS/investment-app/investment-backend/app"
source "$RUNTIME/scripts/env-header.sh"
PY="$RUNTIME/.venv/bin/python"; IMAGE="${IMAGE:-sunmoon/sandbox:dev}"
RELAY_PORT=47100; APP_PORT=47800; USER_ID=local; AGENT_TOKEN=agent-secret; SANDBOX_TOKEN=sandbox-secret
ROOT="$RUNTIME/probe/user-ws"; mkdir -p "$ROOT"; AGENT_HOME="$(mktemp -d /tmp/sunmoon-agent-it.XXXXXX)"; TOKDIR="$(mktemp -d /tmp/sunmoon-tok.XXXXXX)"
DB_URL="${AGENT_TEST_DATABASE_URL:-postgresql://t:t@127.0.0.1:55432/agent_tests}"
pids=(); cleanup() { docker rm -f sandbox-modes >/dev/null 2>&1; for p in "${pids[@]}"; do kill "$p" 2>/dev/null; done; rm -rf "$AGENT_HOME" "$TOKDIR"; }
trap cleanup EXIT

echo "--- 依赖"
for f in "$PY" "$RUNTIME/agent/dist/cli.js" "$K8S/sunmoonai/relay-platform/relay/relay.py" "$K8S/sunmoonai/sandbox-platform/bridge/sandbox_bridge.py" "$BACKEND/tests/drivers/workbench_modes_driver.py"; do [ -e "$f" ] || { echo "缺 $f"; exit 3; }; done
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
docker run -d --name sandbox-modes --add-host=host.docker.internal:host-gateway -p 127.0.0.1:$APP_PORT:47800 -e RELAY_URL="ws://host.docker.internal:$RELAY_PORT" -e RELAY_USER=$USER_ID -e RELAY_TOKEN=$SANDBOX_TOKEN -e OPENAI_API_KEY="$MODEL_KEY" -e MODEL_PROVIDER=kimi -e MODEL=kimi-k3 -e PROVIDER_BASE_URL=https://api.moonshot.cn/v1 -e APP_SERVER_TOKEN_FILE=/secrets/token -v "$TOKDIR/token:/secrets/token:ro" "$IMAGE" >/dev/null
unset MODEL_KEY
for i in $(seq 1 40); do ss -ltn | grep -q ":$APP_PORT " && docker logs sandbox-modes 2>&1 | grep -q "listening on" && break; sleep 0.5; done; sleep 1
echo "--- 4. 工作台驱动整条链"
(cd "$BACKEND" && AGENT_TEST_DATABASE_URL="$DB_URL" APP_SERVER_URL="ws://127.0.0.1:$APP_PORT" APP_SERVER_TOKEN="$APP_TOKEN" ROOT="$ROOT" timeout 900 uv run python tests/drivers/workbench_modes_driver.py 2>&1 | grep -v "sk-")
rc=${PIPESTATUS[0]}
# 子代理会在沙箱里另起一条线：沙箱里应当只有这一条线的记录
lines=$(docker exec sandbox-modes sh -c 'find / -name "rollout-*.jsonl" 2>/dev/null | wc -l')
# 只读的拦截真的被碰到：那条线的记录里，有一次命令的输出是「只读文件系统」。被拦下的命令 Codex 不发事件，只能到这里看
blocked=$(docker exec sandbox-modes sh -c 'cat $(find / -name "rollout-*.jsonl" 2>/dev/null)' | python3 -c '
import json, sys
n = 0
for line in sys.stdin:
    try:
        p = json.loads(line).get("payload") or {}
    except ValueError:
        continue
    if p.get("type") == "function_call_output" and "read-only file system" in str(p.get("output")).lower():
        n += 1
print(n)')
if [ "${blocked:-0}" -ge 1 ]; then echo "  VERDICT 只读的拦截真的被碰到（命令执行了，写被拒）                         pass $blocked 次"; else echo "  VERDICT 只读的拦截真的被碰到（命令执行了，写被拒）                         fail 模型没有去试"; rc=1; fi
if [ "$lines" = "1" ]; then echo "  VERDICT 沙箱里只有一条线的记录                                       pass"; else echo "  VERDICT 沙箱里只有一条线的记录                                       fail 有 $lines 条"; rc=1; fi
# 查问题用：KEEP_DIR=<目录> 时，把沙箱里这条线的记录与两份日志留一份（去掉含 key 的行）。目录不要放在仓库里
if [ -n "${KEEP_DIR:-}" ]; then
  mkdir -p "$KEEP_DIR"; chmod 700 "$KEEP_DIR"
  for f in $(docker exec sandbox-modes sh -c 'find / -name "rollout-*.jsonl" 2>/dev/null'); do docker exec sandbox-modes cat "$f" | grep -v "sk-" > "$KEEP_DIR/$(basename "$f")"; done
  grep -v "sk-" "$HERE/results/.agent.log" > "$KEEP_DIR/agent.log"; docker logs sandbox-modes 2>&1 | grep -v "sk-" > "$KEEP_DIR/sandbox.log"
fi
echo "--- 日志尾部"; echo "[agent]"; tail -4 "$HERE/results/.agent.log" | cut -c1-200; echo "[sandbox]"; docker logs sandbox-modes 2>&1 | grep -v "sk-" | tail -4 | cut -c1-200
rm -f "$HERE/results/.relay.log" "$HERE/results/.agent.log"
exit $rc
