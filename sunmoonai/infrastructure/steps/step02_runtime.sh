#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$BASE_DIR/../utils/common.sh"

load_config_file || exit 1

STEP_PREFIX=STEP02
TARGET="${STEP02_TARGET:-all}"
MODE="${STEP02_RUNTIME_MODE:-nerdctl-full}"
NERDCTL_URL="${STEP02_NERDCTL_FULL_URL:-}"
NS="${STEP02_NERDCTL_NAMESPACE:-k8s.io}"
REMOTE_DIR_FALLBACK="~/packages-to-be-installed"
ONLINE_TIMEOUT="${STEP02_ONLINE_TIMEOUT:-300}"
PACKAGES_DEPLOY_MODE_EFFECTIVE="$(get_packages_deploy_mode)"
CNI_BIN_DIR="${STEP02_CNI_BIN_DIR:-/opt/cni/bin}"
SYSTEMD_CGROUP="${STEP02_SYSTEMD_CGROUP:-true}"
SANDBOX_IMG="${STEP02_SANDBOX_IMAGE:-registry.k8s.io/pause:3.9}"
CTR_ROOT="/var/lib/containerd"
CTR_STATE="/run/containerd"
# 镜像仓库配置（可选，由本步骤写入 containerd hosts.toml）
# 开关：STEP02_REGISTRY_ENABLE=true|false（默认 false）
# 映射：STEP02_REGISTRY_MIRRORS='docker.io=http://harbor.example.com:80/proxy-docker,https://registry-1.docker.io;registry.k8s.io=http://harbor.example.com:80/proxy-k8s,https://registry.k8s.io'
# 直连：STEP02_REGISTRY_DIRECT='harbor.example.com:80' 或 'http://harbor.example.com:80'
REG_ENABLE="${STEP02_REGISTRY_ENABLE:-false}"
REG_MIRRORS_RAW="${STEP02_REGISTRY_MIRRORS:-}"
REG_DIRECT_RAW="${STEP02_REGISTRY_DIRECT:-}"

# CRI socket 配置
CRI_SOCKET_OVERRIDE="${STEP02_CRI_SOCKET_OVERRIDE:-}"

required_artifacts(){
  if [[ "$MODE" == "nerdctl-full" && "$PACKAGES_DEPLOY_MODE_EFFECTIVE" == "offline" ]]; then
    echo "type=tars pattern='nerdctl-full*.tar.gz'"
  fi
}
[[ "${1:-}" == "--required-artifacts" ]] && { required_artifacts; exit 0; }

precheck(){ log_info "[Step02] 预检容器运行时 ($MODE)"; }
ensure_resources(){ :; }



_execute_find_pkg(){
  local dir_raw="$1"
  local payload
  payload="$(printf '%b' "DIR_LITERAL=\"$dir_raw\"\ncase \"\$DIR_LITERAL\" in\n  ~*) base=\"\$HOME\${DIR_LITERAL#\~}\" ;;\n  *)  base=\"\$DIR_LITERAL\" ;;\nesac\nls \"\$base\"/tars/nerdctl-full*.tar.gz \"\$base\"/tars/nerdctl-full*.tgz 2>/dev/null | head -1\n" | base64 -w0)"
  ssh_exec "$i" "bash -lc 'echo $payload | base64 -d | bash -e' | head -1"
}

_execute_download_remote(){
  local dir_raw="$1"; local url="$2"; local fname="$3"
  local payload
  payload="$(printf '%b' "DIR_LITERAL=\"$dir_raw\"\ncase \"\$DIR_LITERAL\" in\n  ~*) base=\"\$HOME\${DIR_LITERAL#\~}\" ;;\n  *)  base=\"\$DIR_LITERAL\" ;;\nesac\nmkdir -p \"\$base/tars\"\ntmp=\"\$base/tars/$fname.tmp\"\nfinal=\"\$base/tars/$fname\"\nrm -f \"\$tmp\"\ncurl -fL -o \"\$tmp\" \"$url\" && mv -f \"\$tmp\" \"\$final\"\n" | base64 -w0)"
  ssh_exec "$i" "timeout ${ONLINE_TIMEOUT} bash -lc 'echo $payload | base64 -d | bash -e'"
}



execute(){
  log_info "[Step02] 在节点 $i 安装/配置运行时 ($MODE)"
  if [[ "$MODE" != "nerdctl-full" ]]; then return 0; fi

  local dir; dir="$(resolve_remote_dir "$(get_server_var "$i" DIR)")"; dir="${dir:-$REMOTE_DIR_FALLBACK}"
  # 目录已在预检阶段创建，此处跳过

  local pkg_path=""
  if ssh_exec "$i" "bash -lc 'test -x /usr/local/bin/nerdctl -a -x /usr/local/bin/containerd'"; then
    log_info "[Step02] 节点 $i 已检测到 nerdctl/containerd，跳过获取包"
    # 继续执行后续的配置步骤（如Harbor配置）
  else
    if [[ "$PACKAGES_DEPLOY_MODE_EFFECTIVE" == "offline" ]]; then
      # 离线模式：优先使用本地离线包
      log_info "[Step02] 离线模式：使用本地离线包"
      
      # 检查远程 tars 文件
      pkg_path="$(_execute_find_pkg "$dir")"
      if [[ -z "${pkg_path:-}" ]]; then
        log_error "[Step02] 节点 $i 缺少 nerdctl-full tar 文件"
        log_error "  - 期望文件模式: $dir/tars/nerdctl-full*.tar.gz"
        log_info "[Step02] 请使用 packages-management.sh 上传 nerdctl-full 包到远程节点"
        return 1
      fi
      
      log_info "[Step02] 找到离线包: $pkg_path"
    else
      # step02 在线模式：检查必要条件
      _check_step02_online_conditions() {
        # 检查配置项
        if [[ -z "$NERDCTL_URL" ]]; then
          log_error "[Step02] 在线模式需要配置 STEP02_NERDCTL_FULL_URL"
          return 1
        fi
        
        # 检查网络连接（step02 需要下载 tar 包）
        log_info "[Step02] 检查网络连接..."
        local score; score="$(online_check_score)"
        if [[ "$score" -lt 1 ]]; then
          log_error "[Step02] 网络连接检查失败（得分: $score/3）"
          log_error "[Step02] 请检查网络连接或切换到离线模式"
          return 1
        fi
        log_info "[Step02] 网络连接检查通过（得分: $score/3）"
        return 0
      }
      
      _check_step02_online_conditions || return 1
      
      local bname; bname="$(basename "${NERDCTL_URL%%\?*}")"; [[ -z "$bname" ]] && bname="nerdctl-full.tgz"
      _execute_download_remote "$dir" "$NERDCTL_URL" "$bname" || { log_error "[Step02] 远端下载失败"; return 1; }
      pkg_path="$(_execute_find_pkg "$dir")"
      if [[ -z "${pkg_path:-}" ]]; then log_error "[Step02] 远端未找到下载后的包"; return 1; fi
    fi
    # 先复制到临时目录，再以 root 权限解包到 /usr/local
    ssh_exec "$i" "cp \"$pkg_path\" /tmp/nerdctl-full.tgz" || { log_error "[Step02] 复制包到临时目录失败"; return 1; }
    ssh_exec_sudo "$i" "mkdir -p /usr/local && tar -C /usr/local -xzf /tmp/nerdctl-full.tgz && mkdir -p \"$CNI_BIN_DIR\" && cp -n /usr/local/libexec/cni/* \"$CNI_BIN_DIR\"/ 2>/dev/null && rm -f /tmp/nerdctl-full.tgz || { echo '[Step02] 解包失败'; exit 1; }"
  fi

  ssh_exec_sudo "$i" "cat >/etc/systemd/system/containerd.service <<'UNIT'
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target

[Service]
ExecStart=/usr/local/bin/containerd
Type=notify
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT"
  ssh_exec_sudo "$i" "sed -i 's/\r$//' /etc/systemd/system/containerd.service || true"
  ssh_exec_sudo "$i" "systemctl daemon-reload"

  ssh_exec_sudo "$i" "mkdir -p /etc/containerd && (containerd config default >/etc/containerd/config.toml || /usr/local/bin/containerd config default >/etc/containerd/config.toml)"
  
  # 配置 containerd
  ssh_exec_sudo "$i" "sed -i \"s#SystemdCgroup = false#SystemdCgroup = ${SYSTEMD_CGROUP}#\" /etc/containerd/config.toml; sed -i \"s#sandbox = '.*'#sandbox = '${SANDBOX_IMG}'#\" /etc/containerd/config.toml; sed -i \"s#^[[:space:]]*root = \\\".*\\\"#root = \\\"${CTR_ROOT}\\\"#\" /etc/containerd/config.toml; sed -i \"s#^[[:space:]]*state = \\\".*\\\"#state = \\\"${CTR_STATE}\\\"#\" /etc/containerd/config.toml || true"
  
  # 配置证书路径，让 containerd 知道在哪里找证书
  ssh_exec_sudo "$i" "sed -i \"s#config_path = ''#config_path = '/etc/containerd/certs.d'#\" /etc/containerd/config.toml || true"
  
  # 写入 registry mirrors 与直连配置（hosts.toml），对在线/离线均无副作用
  if [[ "$REG_ENABLE" == "true" ]]; then
    log_info "[Step02] 在节点 $i 配置 registry mirrors 与直连"
    local payload
    payload="$(cat <<'RS'
set -euo pipefail
REG_MIRRORS_RAW=${REG_MIRRORS_RAW@Q}
REG_DIRECT_RAW=${REG_DIRECT_RAW@Q}
mkdir -p /etc/containerd/certs.d

# helpers
ensure_dir() { mkdir -p "$1"; chmod 0755 "$1"; }
write_hosts() { local file="$1"; shift; printf '%s\n' "$@" >"$file"; chmod 0644 "$file"; }

# mirrors mapping: registry=endpoint1,endpoint2;registry2=...
if [[ -n "${REG_MIRRORS_RAW}" ]]; then
  IFS=';' read -r -a mappings <<< "${REG_MIRRORS_RAW}"
  for kv in "${mappings[@]}"; do
    [[ -z "$kv" ]] && continue
    reg="${kv%%=*}"; eps="${kv#*=}"
    [[ -z "$reg" || -z "$eps" ]] && continue
    dir="/etc/containerd/certs.d/$reg"; ensure_dir "$dir"
    file="$dir/hosts.toml"
    content=("server = \"https://$reg\"")
    IFS=',' read -r -a arr <<< "$eps"
    for ep in "${arr[@]}"; do
      ep="${ep//[[:space:]]/}"
      [[ -z "$ep" ]] && continue
      case "$ep" in http://*|https://*) ;; *) ep="http://$ep" ;; esac
      content+=("[host.\"$ep\"]" "  capabilities = [\"pull\", \"resolve\"]")
    done
    write_hosts "$file" "${content[@]}"
  done
fi

# direct endpoint for pull/push/resolve
if [[ -n "${REG_DIRECT_RAW}" ]]; then
  raw="${REG_DIRECT_RAW}"
  # determine server url and dir name
  server_url="$raw"
  if [[ "$raw" != http://* && "$raw" != https://* ]]; then
    if [[ "$raw" == *:443 ]]; then server_url="https://$raw"; else server_url="http://$raw"; fi
  fi
  dir_host="$raw"
  if [[ "$raw" == http://* || "$raw" == https://* ]]; then dir_host="${raw#*://}"; fi
  dir="/etc/containerd/certs.d/$dir_host"; ensure_dir "$dir"
  file="$dir/hosts.toml"
  printf 'server = "%s"\n[host."%s"]\n  capabilities = ["pull", "push", "resolve"]\n' "$server_url" "$server_url" >"$file"
  chmod 0644 "$file"
fi
RS
    )"
    # 传输并执行远端脚本（通过 base64 安全传输，避免引号/IFS 解析问题）
    local payload_b64 env_content env_b64
    payload_b64="$(printf '%s' "$payload" | base64 -w0)"
    env_content=$(cat <<EOF
REG_MIRRORS_RAW_B64=$(printf '%s' "${REG_MIRRORS_RAW-}" | base64 -w0)
REG_DIRECT_RAW_B64=$(printf '%s' "${REG_DIRECT_RAW-}" | base64 -w0)
EOF
)
    env_b64="$(printf '%s' "$env_content" | base64 -w0)"
    ssh_exec_sudo "$i" "bash -lc 'echo $payload_b64 | base64 -d > /tmp/step02_reg.sh && chmod +x /tmp/step02_reg.sh && echo $env_b64 | base64 -d > /tmp/step02_env && source /tmp/step02_env; REG_MIRRORS_RAW=\"\$(echo \"\${REG_MIRRORS_RAW_B64:-}\" | base64 -d 2>/dev/null || true)\" REG_DIRECT_RAW=\"\$(echo \"\${REG_DIRECT_RAW_B64:-}\" | base64 -d 2>/dev/null || true)\" /tmp/step02_reg.sh; rc=\$?; rm -f /tmp/step02_reg.sh /tmp/step02_env; exit \$rc'"
  fi

  # 配置 CRI socket 路径（如果指定了自定义路径）
  if [[ -n "${CRI_SOCKET_OVERRIDE:-}" ]]; then
    # 从 CRI socket 路径中提取 socket 文件路径
    if [[ "$CRI_SOCKET_OVERRIDE" =~ ^unix://(.+)$ ]]; then
      local socket_path="${BASH_REMATCH[1]}"
      local socket_dir="$(dirname "$socket_path")"
      
      # 创建 socket 目录
      ssh_exec_sudo "$i" "mkdir -p '$socket_dir'"
      
      # 修改 containerd 配置中的 socket 路径
      ssh_exec_sudo "$i" "sed -i \"s#^[[:space:]]*address = \\\".*\\\"#address = \\\"$socket_path\\\"#\" /etc/containerd/config.toml || true"
      
      log_info "[Step02] 已配置自定义 CRI socket 路径: $CRI_SOCKET_OVERRIDE"
    else
      log_warn "[Step02] CRI socket 路径格式不正确，应使用 unix:// 格式: $CRI_SOCKET_OVERRIDE"
    fi
  fi
  
  # 私有仓库配置由 harbor-deploy.sh 处理
  # 这里只做基础运行时配置，避免配置冲突

  # 检查 containerd 是否已经在运行
  local containerd_was_running=false
  if ssh_exec_sudo "$i" "systemctl is-active containerd" >/dev/null 2>&1; then
    containerd_was_running=true
    log_info "[Step02] containerd 已在运行"
  else
    log_info "[Step02] containerd 未运行，将进行首次启动"
  fi

  # 启动或重新加载 containerd 配置
  if [[ "$containerd_was_running" == "false" ]]; then
    # containerd 未运行，启动它
    ssh_exec_sudo "$i" "systemctl enable --now containerd || (systemctl daemon-reload && systemctl enable --now containerd)"
    ssh_exec_sudo "$i" "systemctl is-active containerd" >/dev/null 2>&1 || { log_error "[Step02] containerd 启动失败"; return 1; }
    log_info "[Step02] containerd 已启动"
  else
    # containerd 已在运行，只重新加载配置，不重启服务
    log_info "[Step02] containerd 已在运行，重新加载配置"
    ssh_exec_sudo "$i" "systemctl daemon-reload"
    # 注意：不重启containerd，避免影响运行中的容器
    log_info "[Step02] 跳过containerd重启，避免影响运行中的容器"
  fi
  
  # 安装 crictl
  _install_crictl "$i" || return 1
}

# 安装 crictl 工具
_install_crictl() {
  local node="$1"
  
  # 获取 Kubernetes 版本
  local k8s_version="${STEP03_K8S_VERSION:-${CLUSTER_VERSION:-}}"
  if [[ -n "$k8s_version" && "$k8s_version" != v* ]]; then
    k8s_version="v${k8s_version}"
  fi
  
  # 根据 Kubernetes 版本选择对应的 crictl 版本
  local crictl_version
  case "$k8s_version" in
    v1.30.*)
      crictl_version="v1.30.0"  # 匹配 K8s 1.30.x
      ;;
    v1.29.*)
      crictl_version="v1.29.0"  # 匹配 K8s 1.29.x
      ;;
    v1.28.*)
      crictl_version="v1.28.0"  # 匹配 K8s 1.28.x
      ;;
    *)
      crictl_version="v1.30.0"  # 默认使用 1.30.0
      ;;
  esac
  
  log_info "[Step02] 节点 $node 安装 crictl $crictl_version (匹配 K8s $k8s_version)"
  
  # 检查 crictl 是否已安装
  if ssh_exec "$node" "bash -lc 'command -v crictl >/dev/null 2>&1'"; then
    local current_version
    current_version="$(ssh_exec "$node" "bash -lc 'crictl --version 2>/dev/null | grep -o \"v[0-9][0-9.]*\" | head -1 || echo \"unknown\"'")"
    # 提取主版本号进行比较（如 v1.30.0 -> 1.30）
    local current_major_minor="${current_version%.*}"
    local expected_major_minor="${crictl_version%.*}"
    if [[ "$current_major_minor" == "$expected_major_minor" ]]; then
      log_info "[Step02] 节点 $node crictl $current_version 已安装，主版本匹配"
      return 0
    else
      log_warn "[Step02] 节点 $node crictl 版本不匹配: $current_version (期望主版本: $expected_major_minor.x)"
    fi
  fi
  
  # 离线安装 crictl
  local dir; dir="$(resolve_remote_dir "$(get_server_var "$node" DIR)")"; dir="${dir:-$REMOTE_DIR_FALLBACK}"
  local crictl_file="$dir/tars/crictl-$crictl_version-linux-amd64.tar.gz"
  
  # 使用与 _execute_find_pkg 相同的波浪号展开逻辑
  local payload
  payload="$(printf '%b' "DIR_LITERAL=\"$dir\"\ncase \"\$DIR_LITERAL\" in\n  ~*) base=\"\$HOME\${DIR_LITERAL#\~}\" ;;\n  *)  base=\"\$DIR_LITERAL\" ;;\nesac\ncrictl_file=\"\$base/tars/crictl-$crictl_version-linux-amd64.tar.gz\"\ntest -f \"\$crictl_file\"\n" | base64 -w0)"
  if ssh_exec "$node" "bash -lc 'echo $payload | base64 -d | bash -e'"; then
    log_info "[Step02] 节点 $node 离线安装 crictl $crictl_version"
    # 使用相同的波浪号展开逻辑进行安装，在sudo环境下获取SSH用户的正确家目录
    local ssh_user; ssh_user="$(get_server_var "$node" USER)"
    local install_payload
    install_payload="$(printf '%b' "DIR_LITERAL=\"$dir\"\ncase \"\$DIR_LITERAL\" in\n  ~*) user_home=\$(getent passwd $ssh_user | cut -d: -f6); base=\"\$user_home\${DIR_LITERAL#\~}\" ;;\n  *)  base=\"\$DIR_LITERAL\" ;;\nesac\ncrictl_file=\"\$base/tars/crictl-$crictl_version-linux-amd64.tar.gz\"\ntar -C /usr/local/bin -xzf \"\$crictl_file\" && chmod +x /usr/local/bin/crictl\n" | base64 -w0)"
    ssh_exec_sudo "$node" "bash -lc 'echo $install_payload | base64 -d | bash -e'" || {
      log_error "[Step02] 无法安装 crictl"
      return 1
    }
    log_info "[Step02] crictl $crictl_version 安装完成"
  else
    log_error "[Step02] 离线模式下缺少 crictl 包: $crictl_file"
    log_error "[Step02] 请使用包管理工具下载 crictl $crictl_version"
    return 1
  fi
}

verify(){ log_info "[Step02] 所有符合目标的节点已处理"; }

main(){ precheck; ensure_resources; for_each_node "$TARGET" execute; verify; }

main "$@"


