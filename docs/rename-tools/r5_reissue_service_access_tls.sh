#!/usr/bin/env bash
# R5.1 第 4 步（k8s/docs/rename.md）：traefik 内部访问证书按新名重签——knowledge-tls → knowbase-tls。
# 平台任务 infrastructure/components/tasks/tls-identity.yaml 只在证书不存在时签发（creates:），已签过的身份不会因
# 主机名变了自动重签（「域名/证书轮换显式安排」），这里就是那次显式安排。
# 做法：沿用原私钥（身份不换），按任务里同样的 openssl 参数重出 CSR、用平台 CA 重签五年证书，SAN 只换主机名；
# 私有目录与备份目录两份一起换（任务要求二者逐字节相同），旧证书改名留在原处（证书是公开内容）。
# 不打印私钥；只报证书的公开字段。必须 root，并在 PID 1 的挂载命名空间里跑（备份盘只在那边可见）：
#   sudo -n nsenter --target 1 --mount --wd=/home/zymun/worktrees/qwen/k8s -- bash docs/rename-tools/r5_reissue_service_access_tls.sh
# 演练用：R5_TLS_PRIVATE / R5_TLS_BACKUP / R5_TLS_CA_DIR 改指副本目录；真跑别设。
set -euo pipefail
D=${R5_TLS_PRIVATE:-/etc/sunmoon/services/sunmoon-kind/service-access}/tls
B=${R5_TLS_BACKUP:-/mnt/sunmoon-data/backups/services/sunmoon-kind/service-access}/tls
CA_DIR=${R5_TLS_CA_DIR:-/etc/sunmoon/registry/tls}
NS=app-platform-dev
NEW=("casdoor-tls.$NS.svc.cluster.local" "knowbase-tls.$NS.svc.cluster.local")   # 顺序同 service-access/config.yaml，第一个作 CN
OLD="knowledge-tls.$NS.svc.cluster.local"
stop() { echo "STOP: $*"; exit 3; }
verifies() { openssl verify -CAfile "$CA_DIR/ca.crt" -verify_hostname "$1" "$2" >/dev/null 2>&1; }
show() { openssl x509 -in "$1" -noout -subject -serial -startdate -enddate -ext subjectAltName 2>/dev/null | sed 's/^/  /'; }

[ -n "${R5_TLS_PRIVATE:-}" ] || [ "$(id -u)" = 0 ] || stop "要 root"
for f in "$D/server.key" "$D/server.crt" "$B/server.key" "$B/server.crt"; do
  [ -f "$f" ] && [ ! -L "$f" ] || stop "缺文件或是链接: $f"
  [ -n "${R5_TLS_PRIVATE:-}" ] || [ "$(stat -c '%u %a' "$f")" = "0 600" ] || stop "属主或权限不是 root 0600: $f"
done
cmp -s "$D/server.key" "$B/server.key" && cmp -s "$D/server.crt" "$B/server.crt" || stop "私有目录与备份不一致，先查清再说"
echo "== 现有证书"; show "$D/server.crt"
if verifies "${NEW[0]}" "$D/server.crt" && verifies "${NEW[1]}" "$D/server.crt"; then echo "已含新名，不用重签"; echo "exit=0"; exit 0; fi
verifies "${NEW[0]}" "$D/server.crt" && verifies "$OLD" "$D/server.crt" || stop "现有证书不是预期的旧证书（应含 ${NEW[0]} 与 $OLD）"

stamp=$(date +%Y%m%d-%H%M%S)
work=$(mktemp -d "$D/.reissue-XXXXXX"); trap 'rm -rf "$work"' EXIT
san=$(printf 'DNS:%s,' "${NEW[@]}"); san=${san%,}
cat > "$work/extensions.cnf" <<EOF
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=$san
EOF
openssl req -new -key "$D/server.key" -out "$work/server.csr" -subj "/CN=${NEW[0]}"
openssl x509 -req -in "$work/server.csr" -CA "$CA_DIR/ca.crt" -CAkey "$CA_DIR/ca.key" -set_serial "0x$(openssl rand -hex 16)" \
  -days 1825 -sha256 -extfile "$work/extensions.cnf" -out "$work/server.crt" 2>/dev/null
for h in "${NEW[@]}"; do verifies "$h" "$work/server.crt" || stop "新证书验不过 $h"; done
verifies "$OLD" "$work/server.crt" && stop "新证书还含旧名 $OLD"
[ "$(openssl pkey -in "$D/server.key" -pubout)" = "$(openssl x509 -in "$work/server.crt" -pubkey -noout)" ] || stop "新证书与私钥不配对"

for dir in "$D" "$B"; do
  cp -p "$dir/server.crt" "$dir/server.crt.before-rename-$stamp"
  install -m 0600 "$work/server.crt" "$dir/server.crt.new" && mv -f "$dir/server.crt.new" "$dir/server.crt"
done
install -m 0600 "$work/server.csr" "$D/server.csr"
install -m 0600 "$work/extensions.cnf" "$D/extensions.cnf"
cmp -s "$D/server.crt" "$B/server.crt" || stop "换完后两份不一致"
echo "== 新证书（私有目录与备份两份相同；旧证书留作 server.crt.before-rename-$stamp）"; show "$D/server.crt"
echo "exit=0"
