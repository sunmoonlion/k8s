#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$BASE_DIR/../utils/common.sh"

load_config_file || exit 1

STEP_PREFIX=STEP01
TARGET="${STEP01_TARGET:-all}"

# 该步不直接声明必需离线工件（离线包预同步由 PRE_SYNC_OFFLINE_PACKAGES 控制）
required_artifacts(){ return 0; }
if [[ "${1:-}" == "--required-artifacts" ]]; then required_artifacts; exit 0; fi

IPTABLES_MODE="${STEP01_IPTABLES_MODE:-nft}"  # nft | legacy
DISABLE_SWAP="${STEP01_DISABLE_SWAP:-true}"
SYSCTL_OVERRIDES_RAW="${STEP01_SYSCTL_OVERRIDES:-}"
LOAD_MODULES_RAW="${STEP01_LOAD_KERNEL_MODULES:-overlay,br_netfilter}"
SET_HOSTNAME="${STEP01_SET_HOSTNAME:-true}"
AUTOGEN_HOSTS="${STEP01_AUTOGEN_HOSTS:-true}"
SYNC_TIME="${STEP01_SYNC_TIME:-true}"

LOCAL_PACKAGES_ROOT="${LOCAL_PACKAGES_ROOT:-$HOME/packages-to-be-installed}"
PRE_SYNC_OFFLINE_PACKAGES="${PRE_SYNC_OFFLINE_PACKAGES:-false}"

precheck(){ log_info "[Step01] 预检 OS 基线配置"; }
ensure_resources(){ :; }

_sync_offline_packages_to_node(){
  # 仅在显式开启 PRE_SYNC_OFFLINE_PACKAGES 时执行
  if [[ "$PRE_SYNC_OFFLINE_PACKAGES" != "true" ]]; then
    return 0
  fi

  local idx="$1"
  local remote_dir; remote_dir="$(get_server_var "$idx" DIR)"
  remote_dir="$(resolve_remote_dir "$remote_dir")"

  if [[ -z "$remote_dir" ]]; then
    log_warn "[Step01] 节点 $idx 未配置 SERVER_n_DIR，跳过离线包预同步"
    return 0
  fi

  local local_root="$LOCAL_PACKAGES_ROOT"
  if [[ ! -d "$local_root" ]]; then
    log_warn "[Step01] 本机离线包根目录不存在: $local_root，跳过离线包预同步"
    return 0
  fi

  log_info "[Step01] 节点 $idx: 预同步离线包（源: $local_root → 目标: $remote_dir）"

  local sub
  for sub in debs tars images charts; do
    local src_dir="$local_root/$sub"
    if [[ -d "$src_dir" ]]; then
      local dst_dir="$remote_dir/$sub"
      log_info "[Step01] 节点 $idx: 同步子目录 $sub"
      ssh_exec "$idx" "mkdir -p '$dst_dir'" || true
      # 使用 rsync 同步目录内容；若 rsync 不可用则回退到 scp
      if command -v rsync >/dev/null 2>&1; then
        rsync -az "$src_dir"/ "$(get_server_ssh "$idx"):$dst_dir"/ || log_warn "[Step01] 节点 $idx: rsync $sub 失败，可手动同步"
      else
        scp -r "$src_dir"/* "$(get_server_ssh "$idx"):$dst_dir"/ 2>/dev/null || log_warn "[Step01] 节点 $idx: scp $sub 失败，可手动同步"
      fi
    fi
  done
}

_apply_swap_and_sysctl(){
  local sw="$DISABLE_SWAP"; local sys="$SYSCTL_OVERRIDES_RAW"; local mods="$LOAD_MODULES_RAW"
  # 禁用 swap
  if [[ "$sw" == "true" ]]; then
    ssh_exec_sudo "$i" "bash -lc 'sed -ri \"s/^(.*[[:space:]]+swap[[:space:]].*)$/#\\1/\" /etc/fstab; swapoff -a || true'" || true
  fi
  # 加载内核模块并持久化
  if [[ -n "$mods" ]]; then
    local list; list="$(echo "$mods" | tr ',' ' ')"
    for mod_name in $list; do
      ssh_exec_sudo "$i" "bash -lc 'echo \"$mod_name\" > /etc/modules-load.d/$mod_name.conf; modprobe \"$mod_name\" || true'" || true
    done
  fi
  # 应用 sysctl 覆盖
  if [[ -n "$sys" ]]; then
    local sys_lines; sys_lines="$(echo "$sys" | tr ',' '\n')"
    local sys_b64; sys_b64="$(printf '%s\n' "$sys_lines" | base64 -w0)"
    ssh_exec_sudo "$i" "bash -lc 'echo $sys_b64 | base64 -d > /etc/sysctl.d/99-k8s.conf; sysctl --system >/dev/null 2>&1 || sysctl -p >/dev/null 2>&1 || true'" || true
  fi
}

_configure_iptables_mode(){
  local mode="$IPTABLES_MODE"
  if [[ "$mode" == "legacy" ]]; then
    ssh_exec_sudo "$i" "bash -lc 'update-alternatives --set iptables /usr/sbin/iptables-legacy 2>/dev/null || true; update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy 2>/dev/null || true'" || true
  else
    ssh_exec_sudo "$i" "bash -lc 'update-alternatives --set iptables /usr/sbin/iptables-nft 2>/dev/null || true; update-alternatives --set ip6tables /usr/sbin/ip6tables-nft 2>/dev/null || true'" || true
  fi
}

_set_hostname_and_hosts(){
  # 先写 /etc/hosts 再改 hostname，避免 sudo 报 unable to resolve host
  if [[ "$AUTOGEN_HOSTS" == "true" ]]; then
    local entries; entries="$(generate_hosts_entries)"
    if [[ -n "$entries" ]]; then
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local ip host
        ip="${line%% *}"; host="${line#* }"
        ssh_exec_sudo "$i" "bash -lc 'grep -qE \"(^|\\\\s)${host}(\\\\s|$)\" /etc/hosts || echo \"${ip} ${host}\" >> /etc/hosts'" || true
      done <<< "$entries"
    fi
  fi
  if [[ "$SET_HOSTNAME" == "true" ]]; then
    local chost; chost="$(get_server_var "$i" CLUSTER_HOSTNAME)"
    if [[ -n "$chost" ]]; then
      ssh_exec_sudo "$i" "bash -lc 'if ! grep -qE \"(^|\\\\s)${chost}(\\\\s|$)\" /etc/hosts; then echo \"127.0.1.1 ${chost}\" >> /etc/hosts; fi; hostnamectl set-hostname \"${chost}\"'" || true
    fi
  fi
}

_ensure_time_sync(){
  local mode; mode="${TIME_SYNC:-systemd-timesyncd}"
  if [[ "$mode" == "systemd-timesyncd" ]]; then
    ssh_exec_sudo "$i" "bash -lc 'systemctl enable --now systemd-timesyncd >/dev/null 2>&1 || true'" || true
  elif [[ "$mode" == "chrony" ]]; then
    # 检查是否已安装 chrony
    if ! ssh_exec "$i" "bash -lc 'command -v chrony >/dev/null 2>&1'"; then
      log_warn "[Step01] chrony 未安装，需要在线安装"
      ssh_exec_sudo "$i" "bash -lc 'apt-get update -y >/dev/null 2>&1 || true; apt-get install -y chrony >/dev/null 2>&1 || true; systemctl enable --now chrony >/dev/null 2>&1 || true'" || true
    else
      log_info "[Step01] chrony 已安装，启动服务"
      ssh_exec_sudo "$i" "bash -lc 'systemctl enable --now chrony >/dev/null 2>&1 || true'" || true
    fi
  fi
}

execute(){
  # 可选：在应用 OS 基线前，将本机离线包预同步到远程节点
  _sync_offline_packages_to_node "$i" || true

  log_info "[Step01] 节点 $i 应用 OS 基线"
  _apply_swap_and_sysctl || true
  _configure_iptables_mode || true
  _set_hostname_and_hosts || true
  if [[ "$SYNC_TIME" == "true" ]]; then _ensure_time_sync || true; fi
  
  # 安装 Kubernetes 必要的依赖包（使用离线包）
  log_info "[Step01] 安装 Kubernetes 依赖包（离线模式）"
  local remote_dir; remote_dir="$(get_server_var "$i" DIR)"
  remote_dir="$(resolve_remote_dir "$remote_dir")"
  
  # 检查离线包是否存在
  if ssh_exec "$i" "bash -lc 'dir=\"$remote_dir\"; case \"\$dir\" in ~*) dir=\"/home/zym\${dir#\~}\" ;; esac; test -f \"\$dir/debs/conntrack_1%3a1.4.8-1ubuntu1_amd64.deb\" && test -f \"\$dir/debs/socat_1.8.0.0-4build3_amd64.deb\"'"; then
    log_info "[Step01] 使用离线 deb 包安装依赖"
    ssh_exec_sudo "$i" "bash -lc 'dir=\"$remote_dir\"; case \"\$dir\" in ~*) dir=\"/home/zym\${dir#\~}\" ;; esac; cd \"\$dir/debs\" && dpkg -i conntrack_1%3a1.4.8-1ubuntu1_amd64.deb socat_1.8.0.0-4build3_amd64.deb || apt-get install -f -y'" || true
  else
    log_warn "[Step01] 离线包不存在，回退到在线安装"
    ssh_exec_sudo "$i" "bash -lc 'export DEBIAN_FRONTEND=noninteractive; apt-get update -y >/dev/null 2>&1 || true; apt-get install -y -o Dpkg::Options::=\"--force-confdef\" -o Dpkg::Options::=\"--force-confold\" conntrack socat ebtables >/dev/null 2>&1 || true'" || true
  fi
}

verify(){ log_info "[Step01] 基线设置完成"; }

main(){ precheck; ensure_resources; for_each_node "$TARGET" execute; verify; }
main "$@"


