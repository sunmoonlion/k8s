#!/usr/bin/env bash
# ============================
# 本脚本用途与共存说明（请先读我）
#
# 目标
# - 在已有 Docker 的机器上安装/卸载 nerdctl full 版时，与 Docker 稳定共存；卸载后不影响 Docker 使用。
#
# 关键机制（已内置）
# 1) dockerd 直连模式：生成 override.conf，禁用 docker.socket，使 dockerd 固定监听
#    unix:///var/run/docker.sock，规避 socket 激活/FD 传递导致的“连接被拒绝”。
# 2) containerd 自修复：若 containerd.service 的 ExecStart 残留为 /usr/local/bin/containerd
#    而该文件不存在，自动用 drop-in 覆盖为 /usr/bin/containerd。
# 3) 套接字与数据目录分离：Docker 使用 docker.sock 与 /var/lib/docker；
#    nerdctl/containerd 使用 containerd.sock 与 /var/lib/containerd。
#
# 结论
# - 正常情况下，安装 nerdctl full 不会与 Docker 冲突；卸载 nerdctl full 也不会破坏 Docker。
# - 如遇异常，请先阅读下方“快速自检/快速修复”。
#
# 快速自检
#   systemctl is-active docker containerd | cat
#   systemctl show docker -p ExecStart | cat
#   systemctl cat containerd | grep '^ExecStart=' | cat
#   ss -lx | grep -E 'docker\.sock|containerd\.sock' | cat
#   docker info | sed -n '1,20p' | cat
#
# 一键快速修复（复制整段执行）
#   sudo mkdir -p /etc/systemd/system/containerd.service.d
#   printf "[Service]\nExecStart=\nExecStart=/usr/bin/containerd\n" | sudo tee /etc/systemd/system/containerd.service.d/override.conf >/dev/null
#   sudo mkdir -p /etc/systemd/system/docker.service.d
#   sudo tee /etc/systemd/system/docker.service.d/override.conf >/dev/null <<'EOF'
#   [Service]
#   ExecStart=
#   ExecStart=/usr/bin/dockerd --host=unix:///var/run/docker.sock --containerd=/run/containerd/containerd.sock
#   EOF
#   sudo systemctl disable --now docker.socket || true
#   sudo systemctl daemon-reload
#   sudo systemctl enable --now containerd
#   sudo systemctl restart containerd
#   sudo systemctl enable --now docker
#   sudo systemctl restart docker
#
# 验证
#   curl --unix-socket /var/run/docker.sock http://localhost/_ping -sS | cat
#   docker info | sed -n '1,40p' | cat
#   nerdctl --address /run/containerd/containerd.sock info | sed -n '1,20p' | cat
#
# 提示
# - 如有问题，请先按“快速自检/快速修复”操作；仍无法解决，再提 issue 并附上述命令输出。
# ============================
set -euo pipefail

OS_ID=""
OS_CODENAME=""
NONINTERACTIVE="${NONINTERACTIVE:-false}"

msg(){ echo -e "$*"; }
warn(){ echo -e "\033[33m$*\033[0m"; }
err(){ echo -e "\033[31m$*\033[0m" 1>&2; }
die(){ err "$*"; exit 1; }

need(){ command -v "$1" >/dev/null 2>&1 || die "缺少依赖: $1"; }

#-------------------------------
# 系统检测
#-------------------------------
detect_os(){
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    OS_ID="${ID:-}"
    OS_CODENAME="${VERSION_CODENAME:-}"
  fi
    [[ -z "$OS_ID" || -z "$OS_CODENAME" ]] && die "无法检测发行版信息"
    case "$OS_ID" in
    ubuntu|debian) : ;;
        *) die "不支持的发行版: $OS_ID" ;;
  esac
}

#-------------------------------
# APT操作
#-------------------------------
apt_update_retry(){ sudo apt-get -o Acquire::Retries=3 update -y; }
apt_install_retry(){ sudo apt-get -o Acquire::Retries=3 install -y "$@"; }

# 依赖保障（用于 APT 源与配置生成）
ensure_prereqs(){
  sudo apt-get update -y
    sudo apt-get install -y ca-certificates curl gnupg apt-transport-https wget
  sudo install -m 0755 -d /etc/apt/keyrings
}

get_versions_from_apt(){
    local pkg="$1"
    local out
    out=$(LC_ALL=C apt-cache madison "$pkg" 2>/dev/null | awk '{print $3}' | sed '/^$/d' || true)
    [[ -n "$out" ]] && printf '%s\n' "$out" && return 0
    out=$(LC_ALL=C apt-cache policy "$pkg" 2>/dev/null | awk '/Version table:/ {flag=1; next} flag==1 {v=$1; gsub(/\*/, "", v); if(v ~ /[0-9]/) print v}' | sed '/^$/d' || true)
    [[ -n "$out" ]] && printf '%s\n' "$out" && return 0
    out=$(LC_ALL=C apt list -a "$pkg" 2>/dev/null | sed '1d' | awk '{print $2}' | sed '/^\[/d' || true)
    [[ -n "$out" ]] && printf '%s\n' "$out" && return 0
    return 1
}

pick_version(){
    local pkg="$1"
    local versions
    versions=$(get_versions_from_apt "$pkg" || true)
    if [[ -z "$versions" ]]; then
        [[ "$NONINTERACTIVE" == "true" ]] && echo "" && return 0
        echo "未能获取 $pkg 版本列表" >&2
        read -rp "是否直接安装包？(Y/n): " auto || true
        [[ -z "${auto:-}" || "${auto}" =~ ^[Yy]$ ]] && echo "" && return 0
        die "取消安装"
    fi
    [[ "$NONINTERACTIVE" == "true" ]] && printf '%s\n' "$versions" | head -n1 && return 0
    echo "可用版本:" >&2
    nl -w2 -s') ' <<<"$versions" >&2
    read -rp "输入序号（留空最新）: " pick || true
    if [[ -z "${pick:-}" ]]; then
        printf '%s\n' "$versions" | head -n1
    return 0
  fi
    local sel
    sel=$(printf '%s\n' "$versions" | sed -n "${pick}p" || true)
    [[ -z "$sel" ]] && die "无效选择"
    echo "$sel"
}

#-------------------------------
# Docker源配置
#-------------------------------
setup_docker_repo(){
    local channel="${1:-stable}"
    local key_tmp base gpg_url
    key_tmp=$(mktemp)
  local bases=(
    "https://download.docker.com/linux/${OS_ID}"
    "https://mirrors.aliyun.com/docker-ce/linux/${OS_ID}"
    "https://mirrors.cloud.tencent.com/docker-ce/linux/${OS_ID}"
    "https://mirrors.ustc.edu.cn/docker-ce/linux/${OS_ID}"
  )
  local ok_base=""
      for base in "${bases[@]}"; do
        gpg_url="${base}/gpg"
        msg "尝试从 ${gpg_url} 获取 GPG..."
        if curl -fsSL --retry 5 "$gpg_url" -o "$key_tmp"; then
          ok_base="$base"
          break
        fi
      done
    [[ -z "$ok_base" ]] && die "下载 Docker GPG 公钥失败"
    sudo rm -f /etc/apt/keyrings/docker.gpg
    sudo gpg --dearmor --batch --yes -o /etc/apt/keyrings/docker.gpg "$key_tmp"
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    rm -f "$key_tmp"
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] $ok_base $OS_CODENAME $channel" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  msg "使用 Docker 源: ${ok_base} (${channel})"
  apt_update_retry
}

# 修复：若 containerd 的 unit 指向 /usr/local/bin/containerd 且该二进制不存在，覆盖为 /usr/bin/containerd
fix_containerd_unit_execstart(){
    local override_dir="/etc/systemd/system/containerd.service.d"
    local override_file="${override_dir}/override.conf"
    if systemctl cat containerd >/dev/null 2>&1; then
        if systemctl cat containerd | grep -qE "ExecStart=.*/usr/local/bin/containerd"; then
            if [[ ! -x /usr/local/bin/containerd && -x /usr/bin/containerd ]]; then
                msg "修复 containerd ExecStart → /usr/bin/containerd"
                sudo mkdir -p "${override_dir}"
                printf "[Service]\nExecStart=\nExecStart=/usr/bin/containerd\n" | sudo tee "${override_file}" >/dev/null
                sudo systemctl daemon-reload
                sudo systemctl restart containerd || true
            fi
        fi
    fi
}

# 启用 dockerd 直连模式（禁用 socket 激活，直接监听 /var/run/docker.sock）
docker_enable_direct_mode(){
    msg "启用 dockerd 直连模式..."
    sudo mkdir -p /etc/systemd/system/docker.service.d
    sudo tee /etc/systemd/system/docker.service.d/override.conf >/dev/null <<'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --host=unix:///var/run/docker.sock --containerd=/run/containerd/containerd.sock
EOF
    sudo systemctl disable --now docker.socket >/dev/null 2>&1 || true
    sudo systemctl daemon-reload
    sudo systemctl restart docker || true
}

# 恢复 socket 激活模式
docker_restore_socket_activation(){
    msg "恢复 dockerd 的 socket 激活模式..."
    sudo rm -f /etc/systemd/system/docker.service.d/override.conf
    sudo systemctl daemon-reload
    sudo systemctl enable --now docker.socket || true
    sudo systemctl restart docker || true
}

#-------------------------------
# containerd 配置
#-------------------------------
configure_containerd(){
    sudo mkdir -p /etc/containerd
    command -v containerd >/dev/null 2>&1 || die "containerd 未安装"
    sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
    sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    sudo systemctl restart containerd
}

#-------------------------------
# 安装 / 卸载
#-------------------------------
install_docker(){
  ensure_prereqs
    setup_docker_repo
  local ver
    ver=$(pick_version "docker-ce")
  if [[ -n "$ver" ]]; then
        apt_install_retry "docker-ce=$ver" "docker-ce-cli" "containerd.io"
    else
        apt_install_retry "docker-ce" "docker-ce-cli" "containerd.io"
    fi
    # containerd 先启用并修复可能的 ExecStart 残留
    sudo systemctl enable --now containerd || true
    fix_containerd_unit_execstart
    # 启用 docker
    sudo systemctl enable --now docker || true
    # 默认启用直连模式（非交互直接启用；交互询问）
    if [[ "$NONINTERACTIVE" == "true" ]]; then
        docker_enable_direct_mode
    else
        read -rp "是否启用 dockerd 直连模式（禁用 socket 激活，推荐）？(Y/n): " ans || true
        if [[ -z "${ans:-}" || "$ans" =~ ^[Yy]$ ]]; then
            docker_enable_direct_mode
        fi
    fi
}

uninstall_docker(){
    sudo systemctl stop docker || true
    # 仅卸载 Docker 相关包，不移除 containerd.io，避免破坏共存
    sudo apt-get remove --purge -y docker-ce docker-ce-cli docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras || true
    sudo rm -rf /var/lib/docker /etc/docker
    sudo systemctl daemon-reload || true
}

# 独立安装 containerd（不影响 Docker）
install_containerd(){
    ensure_prereqs
    setup_docker_repo
    local ver
    ver=$(pick_version "containerd.io")
    if [[ -n "$ver" ]]; then
        apt_install_retry "containerd.io=$ver"
    else
        apt_install_retry "containerd.io"
    fi
    sudo systemctl enable --now containerd || true
    # 修复可能的 ExecStart 残留
    fix_containerd_unit_execstart
    # 交互式可选生成 config.toml
    # 直接生成/覆盖 config.toml 并设置 SystemdCgroup=true
    configure_containerd
}

# 独立卸载 containerd（不影响 Docker）
uninstall_containerd(){
    sudo systemctl disable --now containerd >/dev/null 2>&1 || true
    sudo apt-get purge -y containerd.io || true
    if [[ "$NONINTERACTIVE" != "true" ]]; then
        read -rp "是否清理 /var/lib/containerd 数据？(y/N): " clean || true
        if [[ "${clean:-}" =~ ^[Yy]$ ]]; then
            sudo rm -rf /var/lib/containerd
        fi
    fi
    sudo systemctl daemon-reload || true
}

#-------------------------------
# 管理操作（Docker / containerd）
#-------------------------------
docker_service_action(){
  local act="$1"
    case "$act" in
        start|stop|restart) sudo systemctl "$act" docker || true ;;
        status) sudo systemctl status docker --no-pager | sed -n '1,30p' || true ;;
    esac
}

docker_logs(){ sudo journalctl -u docker --no-pager -n 200 | sed -n '1,200p' ; }

containerd_service_action(){
    local act="$1"
    case "$act" in
        start|stop|restart) sudo systemctl "$act" containerd || true ;;
        status) sudo systemctl status containerd --no-pager | sed -n '1,30p' || true ;;
    esac
}

containerd_logs(){ sudo journalctl -u containerd --no-pager -n 200 | sed -n '1,200p' ; }

docker_manage_menu(){
  while true; do
        msg "=== Docker 管理 ===\n1) 启动\n2) 停止\n3) 重启\n4) 状态\n5) 日志\n0) 返回"
    read -rp "请输入序号: " ch || true
    case "${ch:-}" in
      1) docker_service_action start ;;
      2) docker_service_action stop ;;
      3) docker_service_action restart ;;
      4) docker_service_action status ;;
      5) docker_logs ;;
      0) break ;;
      *) warn "无效选择" ;;
    esac
  done
}

#-------------------------------
# Docker 私有仓库配置
#-------------------------------
## 私有仓库配置功能已迁移到 private_registry 目录的独立脚本中

containerd_manage_menu(){
  while true; do
        msg "=== containerd 管理 ===\n1) 启动\n2) 停止\n3) 重启\n4) 状态\n5) 日志\n0) 返回"
    read -rp "请输入序号: " ch || true
    case "${ch:-}" in
      1) containerd_service_action start ;;
      2) containerd_service_action stop ;;
      3) containerd_service_action restart ;;
      4) containerd_service_action status ;;
      5) containerd_logs ;;
      0) break ;;
      *) warn "无效选择" ;;
    esac
  done
}

#-------------------------------
# 菜单
#-------------------------------
show_menu(){
    cat <<EOF
请选择操作:
1) 安装 Docker（启用直连模式可选）
2) 卸载 Docker（不移除 containerd）
3) 安装 containerd（独立，可与 Docker 共存）
4) 卸载 containerd（不影响 Docker）
5) 启用 dockerd 直连模式（禁用 socket 激活）
6) 恢复 dockerd socket 激活模式
7) Docker 管理（启动/停止/重启/状态/日志）
8) containerd 管理（启动/停止/重启/状态/日志）
0) 退出
EOF
}

main(){
    detect_os
  while true; do
        show_menu
        [[ "$NONINTERACTIVE" == "true" ]] && opt=1 || read -rp "输入选项: " opt
        case "$opt" in
            1) install_docker ;;
            2) uninstall_docker ;;
            3) install_containerd ;;
            4) uninstall_containerd ;;
            5) docker_enable_direct_mode ;;
            6) docker_restore_socket_activation ;;
            7) docker_manage_menu ;;
            8) containerd_manage_menu ;;
            0) exit 0 ;;
            *) warn "无效选项" ;;
  esac
        [[ "$NONINTERACTIVE" == "true" ]] && break
  done
}

main "$@"
