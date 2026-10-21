#!/usr/bin/env bash
# 生成 Ubuntu 自动安装的应答 ISO（cidata）。本地助手在 WSL 里跑；口令只做哈希、不落盘明文。
# 用法：bash make-seed-iso.sh --out /mnt/d/iso/sunmoon-prod-seed.iso --pubkey ~/.ssh/id_rsa.pub [--ip 192.168.80.10 --prefix 24 --gateway 192.168.80.1 --host sunmoon-prod --user sunmoon]
set -euo pipefail
OUT=""; PUBKEY=""; IP=192.168.80.10; PREFIX=24; GW=192.168.80.1; HOSTNAME=sunmoon-prod; USERNAME=sunmoon
while [ $# -gt 0 ]; do case "$1" in
  --out) OUT=$2; shift 2;; --pubkey) PUBKEY=$2; shift 2;; --ip) IP=$2; shift 2;; --prefix) PREFIX=$2; shift 2;;
  --gateway) GW=$2; shift 2;; --host) HOSTNAME=$2; shift 2;; --user) USERNAME=$2; shift 2;; *) echo "unknown $1" >&2; exit 2;; esac; done
[ -n "$OUT" ] && [ -n "$PUBKEY" ] || { echo "need --out and --pubkey" >&2; exit 2; }
[ -f "$PUBKEY" ] || { echo "no pubkey $PUBKEY" >&2; exit 2; }
command -v xorriso >/dev/null || command -v genisoimage >/dev/null || { echo "install xorriso or genisoimage (sudo apt-get install -y xorriso)" >&2; exit 2; }
here=$(cd "$(dirname "$0")" && pwd)
read -rs -p "控制台口令（只在 Hyper-V 控制台登录时用，SSH 不用它；不回显）: " PW; echo
HASH=$(printf '%s' "$PW" | openssl passwd -6 -stdin); unset PW
KEY=$(cut -d' ' -f1,2 "$PUBKEY")
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
sed -e "s|__HOSTNAME__|$HOSTNAME|g" -e "s|__USER__|$USERNAME|g" -e "s|__PASSWORD_HASH__|$HASH|g" -e "s|__SSH_PUBKEY__|$KEY|g" \
    -e "s|__VM_IP__|$IP|g" -e "s|__PREFIX__|$PREFIX|g" -e "s|__GATEWAY__|$GW|g" "$here/autoinstall/user-data.tpl" > "$tmp/user-data"
sed -e "s|__HOSTNAME__|$HOSTNAME|g" "$here/autoinstall/meta-data.tpl" > "$tmp/meta-data"
python3 - "$tmp/user-data" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1])); assert d['autoinstall']['version'] == 1
PY
if command -v xorriso >/dev/null; then xorriso -as mkisofs -quiet -o "$OUT" -V cidata -J -r "$tmp/user-data" "$tmp/meta-data"
else genisoimage -quiet -output "$OUT" -volid cidata -joliet -rock "$tmp/user-data" "$tmp/meta-data"; fi
echo "seed iso: $OUT ($(stat -c %s "$OUT") bytes); host $HOSTNAME user $USERNAME ip $IP/$PREFIX gw $GW"
