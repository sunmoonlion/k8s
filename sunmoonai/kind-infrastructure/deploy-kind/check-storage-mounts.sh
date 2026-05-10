#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="${SCRIPT_DIR}/deploy-kind.conf"

read_pv_mode_from_conf() {
  local fm="" fp=""
  if [[ -f "$CONF" ]]; then
    fm=$(grep -E '^KIND_PV_STORAGE_MODE=' "$CONF" 2>/dev/null | head -1 | cut -d'=' -f2- | tr -d ' "' || true)
    fp=$(grep -E '^KIND_PV_HOST_PATH=' "$CONF" 2>/dev/null | head -1 | cut -d'=' -f2- | tr -d ' "' || true)
  fi
  KIND_PV_STORAGE_MODE="${KIND_PV_STORAGE_MODE:-${fm:-native}}"
  KIND_PV_HOST_PATH="${KIND_PV_HOST_PATH:-${fp:-/data/kind-local-storage}}"
}

read_pv_mode_from_conf

# --- native：WSL 发行版内普通目录，不要求独立 VHD / fstab ---
if [[ "${KIND_PV_STORAGE_MODE}" == "native" ]]; then
  bind_mp="${KIND_PV_HOST_PATH}"
  if [[ ! -d "$bind_mp" ]]; then
    echo "[storage-check] ERROR native：目录不存在 $bind_mp（请先 kind-up / 或 sudo mkdir -p）" >&2
    exit 1
  fi
  if [[ "${STORAGE_CHECK_SHOW_OK:-0}" == "1" ]]; then
    root_src=$(findmnt -n -o SOURCE / 2>/dev/null || true)
    bind_src=$(findmnt -n -o SOURCE "$bind_mp" 2>/dev/null || true)
    echo "[storage-check] OK native dir=$bind_mp backing=${bind_src:-?} root=${root_src:-?}"
  fi
  exit 0
fi

# --- vhd：独立盘 + bind，避免写偏到 WSL 系统盘 ---
DOCKER_MP="/mnt/docker-ext4"
PV_MP="/mnt/pv-kind-ext4"
BIND_MP="${KIND_PV_HOST_PATH:-/data/kind-local-storage}"

docker_src=$(findmnt -n -o SOURCE "$DOCKER_MP" 2>/dev/null || true)
pv_src=$(findmnt -n -o SOURCE "$PV_MP" 2>/dev/null || true)
bind_src=$(findmnt -n -o SOURCE "$BIND_MP" 2>/dev/null || true)
root_src=$(findmnt -n -o SOURCE / 2>/dev/null || true)

ok=true

if [[ -z "$docker_src" || -z "$pv_src" || -z "$bind_src" ]]; then
  ok=false
fi

if [[ -n "$pv_src" && -n "$bind_src" && "$pv_src" != "$bind_src" ]]; then
  ok=false
fi

# Guard against false-positive mounts that point to the WSL system disk.
if [[ -n "$root_src" ]]; then
  if [[ "$docker_src" == "$root_src" || "$docker_src" == "$root_src["* ]]; then
    ok=false
  fi
  if [[ "$pv_src" == "$root_src" || "$pv_src" == "$root_src["* ]]; then
    ok=false
  fi
  if [[ "$bind_src" == "$root_src" || "$bind_src" == "$root_src["* ]]; then
    ok=false
  fi
fi

if [[ "$ok" == "true" ]]; then
  if [[ "${STORAGE_CHECK_SHOW_OK:-0}" == "1" ]]; then
    echo "[storage-check] OK docker=$docker_src pv=$pv_src bind=$bind_src"
  fi
  exit 0
fi

echo "[storage-check] WARN vhd 模式挂载异常，可能写偏到 WSL 系统盘" >&2
echo "  docker: ${docker_src:-<not-mounted>}" >&2
echo "  pv:     ${pv_src:-<not-mounted>}" >&2
echo "  bind:   ${bind_src:-<not-mounted>}" >&2
echo "  建议：Windows 管理员 PowerShell 执行 wsl --mount，再回 WSL sudo mount -a；或改用 deploy-kind.conf 中 KIND_PV_STORAGE_MODE=native" >&2
exit 1
