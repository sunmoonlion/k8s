#!/usr/bin/env bash
set -euo pipefail

DOCKER_MP="/mnt/docker-ext4"
PV_MP="/mnt/pv-kind-ext4"
BIND_MP="/data/kind-local-storage"

docker_src=$(findmnt -n -o SOURCE "$DOCKER_MP" 2>/dev/null || true)
pv_src=$(findmnt -n -o SOURCE "$PV_MP" 2>/dev/null || true)
bind_src=$(findmnt -n -o SOURCE "$BIND_MP" 2>/dev/null || true)

ok=true

if [[ -z "$docker_src" || -z "$pv_src" || -z "$bind_src" ]]; then
  ok=false
fi

if [[ -n "$pv_src" && -n "$bind_src" && "$pv_src" != "$bind_src" ]]; then
  ok=false
fi

if [[ "$ok" == "true" ]]; then
  if [[ "${STORAGE_CHECK_SHOW_OK:-0}" == "1" ]]; then
    echo "[storage-check] OK docker=$docker_src pv=$pv_src bind=$bind_src"
  fi
  exit 0
fi

echo "[storage-check] WARN 挂载异常，可能写偏到WSL系统盘" >&2
echo "  docker: ${docker_src:-<not-mounted>}" >&2
echo "  pv:     ${pv_src:-<not-mounted>}" >&2
echo "  bind:   ${bind_src:-<not-mounted>}" >&2
echo "  建议：Windows管理员PowerShell执行 wsl --mount 两块盘，再回WSL sudo mount -a" >&2
exit 1
