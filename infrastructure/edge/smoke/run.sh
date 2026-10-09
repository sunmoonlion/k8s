#!/usr/bin/env bash
# 边缘本机冒烟（SDD 0013 第三节验收）：临时令牌 + 临时 frpc + 替身后端，验完全部清理。不对外，不用真令牌。
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd); infra=$(cd "$here/../.." && pwd)
work=$(mktemp -d); dir=/etc/sunmoon/edge-smoke
node_bin=${NODE_BIN:-$HOME/.nvm/versions/node/v24.21.0/bin/node}
frpc_image=$(awk -F': ' '/^edge_smoke_frpc_image:/{print $2}' "$infra/edge/config.yaml")
fail=0; check() { if (set +o pipefail; eval "$2"); then echo "  ✓ $1"; else echo "  ✗ $1"; fail=1; fi; }
cleanup() {
  docker rm -f sunmoon-edge-smoke-frpc sunmoon-edge-smoke-badfrpc >/dev/null 2>&1
  [ -n "${backend_pid:-}" ] && kill "$backend_pid" 2>/dev/null
  sudo -n systemctl stop sunmoon-edge.service 2>/dev/null
  sudo -n rm -rf "$dir"; rm -rf "$work"
}
[ "${KEEP:-0}" = 1 ] || trap cleanup EXIT
token=$(openssl rand -base64 36 | tr -d '\n/+=' | cut -c1-48)
sudo -n install -d -m 700 "$dir"
printf 'token: %s\n' "$token" | sudo -n install -m 600 /dev/stdin "$dir/frp-token.yaml"
echo "== 部署（smoke 模式）"
(cd "$infra" && .venv/bin/ansible-playbook -i edge/inventory.yaml edge/service.yaml -e @edge/config.yaml \
  -e edge_action=deploy -e edge_tls_mode=smoke -e edge_config_dir=$dir -e edge_token_file=$dir/frp-token.yaml </dev/null >"$work/deploy.log" 2>&1) \
  || { tail -30 "$work/deploy.log"; exit 1; }
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$work/k.pem" -out "$work/c.pem" -days 1 -subj /CN=smoke >/dev/null 2>&1
"$node_bin" "$here/backend.mjs" "$work/k.pem" "$work/c.pem" 18443 & backend_pid=$!
docker run -d --name sunmoon-edge-smoke-frpc --network host -e FRP_AUTH_TOKEN="$token" \
  -v "$here/frpc.toml.tmpl:/etc/frp/frpc.toml:ro" "$frpc_image" -c /etc/frp/frpc.toml >/dev/null
sleep 4
r() { curl -sk --max-time 10 --resolve "$1:30443:127.0.0.1" "https://$1:30443$2" "${@:3}"; }
echo "== 检查"
for h in investment casdoor relay; do
  check "$h 经隧道回显正确 Host" "r $h.sunmoonai.com /hello | grep -q '\"host\":\"$h.sunmoonai.com'"
done
check "proto=https 保留到后端" "r investment.sunmoonai.com /x | grep -q '\"proto\":\"https\"'"
check "X-Forwarded-For 第一个是真实来源" "r investment.sunmoonai.com /x | grep -q '\"xff\":\"127.0.0.1'"
check "未列出的域名 404" "[ \"\$(r harbor.sunmoonai.com / -o /dev/null -w '%{http_code}')\" = 404 ]"
check "80 跳 30443" "curl -s -o /dev/null -w '%{redirect_url}' --resolve investment.sunmoonai.com:80:127.0.0.1 http://investment.sunmoonai.com/a | grep -q '^https://investment.sunmoonai.com:30443/a'"
check "SSE 分三次到达（不被缓冲）" "r investment.sunmoonai.com /sse -N | awk '{print systime()}' | uniq | wc -l | grep -qE '^[23]$'"
check "WebSocket 升级透传 101" "curl -sk -i --max-time 5 --http1.1 --resolve relay.sunmoonai.com:30443:127.0.0.1 -H 'Connection: Upgrade' -H 'Upgrade: websocket' -H 'Sec-WebSocket-Version: 13' -H 'Sec-WebSocket-Key: c21va2Utc21va2Utc21va2U=' https://relay.sunmoonai.com:30443/ws 2>/dev/null | head -1 | grep -q ' 101 '"
docker run -d --name sunmoon-edge-smoke-badfrpc --network host -e FRP_AUTH_TOKEN="wrong-token-wrong-token-wrong-token" \
  -v "$here/frpc.toml.tmpl:/etc/frp/frpc.toml:ro" "$frpc_image" -c /etc/frp/frpc.toml >/dev/null; sleep 3
check "错令牌的 frpc 登录被拒" "docker logs sunmoon-edge-smoke-badfrpc 2>&1 | grep -qi 'token'"
check "vhost 8080 只绑本机" "! ss -ltn | awk '{print \$4}' | grep -qE '^(0\.0\.0\.0|\[::\]|\*):8080$'"
check "Traefik 健康口只绑本机" "! ss -ltn | awk '{print \$4}' | grep -qE '^(0\.0\.0\.0|\[::\]|\*):8082$'"
check "frps 日志里没有令牌" "! sudo -n docker compose -f $dir/compose.yaml logs frps 2>&1 | grep -qF \"$token\""
echo "exit=$fail"; exit $fail
