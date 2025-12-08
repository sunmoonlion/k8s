#!/bin/bash

# =============================================================================
# 镜像清理脚本（完全独立，不依赖 Harbor）
# 用途：清理 Kubernetes 集群各节点上未使用的镜像缓存和包文件
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# 加载配置文件
CONF_FILE="$SCRIPT_DIR/image-cleanup.conf"
if [[ -f "$CONF_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONF_FILE"
else
    echo "[ERROR] 配置文件不存在: $CONF_FILE"
    exit 1
fi

# 导入通用函数（用于读取节点配置）
if [[ -f "$PROJECT_ROOT/utils/common.sh" ]]; then
    # shellcheck source=/dev/null
    source "$PROJECT_ROOT/utils/common.sh"
else
    echo "[ERROR] 通用函数库不存在: $PROJECT_ROOT/utils/common.sh"
    exit 1
fi

# 日志函数
log() {
    local level="${1:-INFO}"
    shift
    local msg="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $msg" | tee -a "$LOG_FILE" 2>/dev/null || echo "[$timestamp] [$level] $msg"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_debug() { 
    if [[ "${LOG_LEVEL:-INFO}" == "DEBUG" ]]; then
        log "DEBUG" "$@"
    fi
}

# 检查清理功能是否启用
check_cleanup_enabled() {
    if [[ "${CLEANUP_ENABLED:-false}" != "true" ]]; then
        log_info "清理功能未启用 (CLEANUP_ENABLED=false)，跳过清理"
        return 1
    fi
    return 0
}

# 检查磁盘使用率
check_disk_usage() {
    local threshold="${CLEANUP_DISK_THRESHOLD:-75}"
    local usage
    
    # 获取根分区使用率
    usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [[ -z "$usage" ]]; then
        log_warn "无法获取磁盘使用率，跳过检查"
        return 0
    fi
    
    if [[ $usage -ge $threshold ]]; then
        log_info "磁盘使用率: ${usage}% >= ${threshold}%，满足清理条件"
        return 0
    else
        log_info "磁盘使用率: ${usage}% < ${threshold}%，不满足清理条件"
        return 1
    fi
}

# 清理单个节点的镜像
cleanup_node_images() {
    local node_ip="$1"
    local node_user="$2"
    local node_port="$3"
    local secret="$4"
    local pass="$5"
    
    if [[ "${CLEANUP_IMAGES:-true}" != "true" ]]; then
        log_debug "节点 $node_ip: 镜像清理已禁用，跳过"
        return 0
    fi
    
    log_info "节点 $node_ip: 开始清理镜像缓存..."
    
    local cmd="sudo -n $NERDCTL_BIN -n $CONTAINERD_NAMESPACE image prune -a -f || true"
    
    if [[ -n "$secret" && -f "$secret" ]]; then
        if ssh -i "$secret" -o StrictHostKeyChecking=no -o LogLevel=ERROR -p "$node_port" "$node_user@$node_ip" "$cmd" 2>&1; then
            log_info "节点 $node_ip: 镜像清理完成"
            return 0
        else
            log_warn "节点 $node_ip: 镜像清理失败"
            return 1
        fi
    elif [[ -n "$pass" ]] && command -v sshpass >/dev/null 2>&1; then
        if sshpass -p "$pass" ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR -p "$node_port" "$node_user@$node_ip" "$cmd" 2>&1; then
            log_info "节点 $node_ip: 镜像清理完成"
            return 0
        else
            log_warn "节点 $node_ip: 镜像清理失败"
            return 1
        fi
    else
        log_warn "节点 $node_ip: 无法找到 SSH 密钥或密码配置，跳过"
        return 1
    fi
}

# 清理单个节点的包文件
cleanup_node_packages() {
    local node_ip="$1"
    local node_user="$2"
    local node_port="$3"
    local secret="$4"
    local pass="$5"
    local rdir="$6"
    
    if [[ "${CLEANUP_PACKAGES:-true}" != "true" ]]; then
        log_debug "节点 $node_ip: 包文件清理已禁用，跳过"
        return 0
    fi
    
    log_info "节点 $node_ip: 开始清理包文件..."
    
    # 解析要清理的包类型
    local cleanup_dirs=()
    IFS=',' read -ra types <<< "${CLEANUP_PACKAGE_TYPES:-debs,tars,charts,images}"
    for type in "${types[@]}"; do
        type=$(echo "$type" | xargs)  # 去除空格
        case "$type" in
            debs|deb) cleanup_dirs+=("$rdir/debs/*") ;;
            tars|tar) cleanup_dirs+=("$rdir/tars/*") ;;
            charts|chart) cleanup_dirs+=("$rdir/charts/*") ;;
            images|image) cleanup_dirs+=("$rdir/images/*.tar*") ;;
        esac
    done
    
    if [[ ${#cleanup_dirs[@]} -eq 0 ]]; then
        log_debug "节点 $node_ip: 未配置要清理的包类型，跳过"
        return 0
    fi
    
    local cmd="rm -rf ${cleanup_dirs[*]} 2>/dev/null || true"
    
    if [[ -n "$secret" && -f "$secret" ]]; then
        if ssh -i "$secret" -o StrictHostKeyChecking=no -o LogLevel=ERROR -p "$node_port" "$node_user@$node_ip" "$cmd" 2>&1; then
            log_info "节点 $node_ip: 包文件清理完成"
            return 0
        else
            log_warn "节点 $node_ip: 包文件清理失败"
            return 1
        fi
    elif [[ -n "$pass" ]] && command -v sshpass >/dev/null 2>&1; then
        if sshpass -p "$pass" ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR -p "$node_port" "$node_user@$node_ip" "$cmd" 2>&1; then
            log_info "节点 $node_ip: 包文件清理完成"
            return 0
        else
            log_warn "节点 $node_ip: 包文件清理失败"
            return 1
        fi
    else
        log_warn "节点 $node_ip: 无法找到 SSH 密钥或密码配置，跳过"
        return 1
    fi
}

# 清理单个节点
cleanup_node() {
    local node_ip="$1"
    local node_user="$2"
    local node_port="$3"
    local secret="$4"
    local pass="$5"
    local rdir="$6"
    
    log_info "========================================="
    log_info "清理节点: $node_ip"
    
    local success_count=0
    local total_count=0
    
    # 清理镜像
    if [[ "${CLEANUP_IMAGES:-true}" == "true" ]]; then
        total_count=$((total_count + 1))
        if cleanup_node_images "$node_ip" "$node_user" "$node_port" "$secret" "$pass"; then
            success_count=$((success_count + 1))
        fi
    fi
    
    # 清理包文件
    if [[ "${CLEANUP_PACKAGES:-true}" == "true" ]]; then
        total_count=$((total_count + 1))
        if cleanup_node_packages "$node_ip" "$node_user" "$node_port" "$secret" "$pass" "$rdir"; then
            success_count=$((success_count + 1))
        fi
    fi
    
    log_info "节点 $node_ip: 清理完成 ($success_count/$total_count)"
    log_info "========================================="
    
    return 0
}

# 清理所有节点
cleanup_all_nodes() {
    log_info "开始清理所有节点..."
    
    # 检查清理功能是否启用
    if ! check_cleanup_enabled; then
        return 1
    fi
    
    # 加载基础设施配置
    local infra_config="${INFRA_CONFIG_FILE:-}"
    if [[ -z "$infra_config" ]]; then
        # 自动计算配置文件路径
        infra_config="$PROJECT_ROOT/deploy-infrastructure-all/deploy-infrastructure-all.conf"
    fi
    
    if [[ ! -f "$infra_config" ]]; then
        log_error "基础设施配置文件不存在: $infra_config"
        log_error "请检查 INFRA_CONFIG_FILE 配置或确保文件存在"
        return 1
    fi
    
    log_debug "使用基础设施配置文件: $infra_config"
    
    # 加载配置并应用集群映射
    if ! load_config_file; then
        log_error "加载基础设施配置失败"
        return 1
    fi
    
    # 获取所有节点
    local indices
    indices="$(get_defined_server_indices)"
    
    if [[ -z "$indices" ]]; then
        log_error "未找到任何节点配置"
        return 1
    fi
    
    local total_nodes=0
    local success_nodes=0
    
    # 遍历所有节点
    for idx in $indices; do
        local host_var="SERVER_${idx}_PUBLIC_IP"
        local host="${!host_var:-}"
        
        if [[ -z "$host" ]]; then
            continue
        fi
        
        total_nodes=$((total_nodes + 1))
        
        local user_var="SERVER_${idx}_USER"
        local user="${!user_var:-root}"
        
        local port_var="SERVER_${idx}_SSH_PORT"
        local port="${!port_var:-22}"
        
        local secret_var="SERVER_${idx}_SECRET"
        local secret="${!secret_var:-}"
        
        local pass_var="SERVER_${idx}_PASS"
        local pass="${!pass_var:-}"
        
        local dir_var="SERVER_${idx}_DIR"
        local rdir="${!dir_var:-~/packages-to-be-installed}"
        
        if cleanup_node "$host" "$user" "$port" "$secret" "$pass" "$rdir"; then
            success_nodes=$((success_nodes + 1))
        fi
    done
    
    log_info "========================================="
    log_info "所有节点清理完成: $success_nodes/$total_nodes"
    log_info "========================================="
    
    if [[ $success_nodes -eq $total_nodes ]]; then
        return 0
    else
        return 1
    fi
}

# 显示配置
show_config() {
    echo "=== 镜像清理配置 ==="
    echo "清理功能启用: ${CLEANUP_ENABLED:-false}"
    echo "清理镜像: ${CLEANUP_IMAGES:-true}"
    echo "清理包文件: ${CLEANUP_PACKAGES:-true}"
    echo "包文件类型: ${CLEANUP_PACKAGE_TYPES:-debs,tars,charts,images}"
    echo "磁盘使用率阈值: ${CLEANUP_DISK_THRESHOLD:-75}%"
    echo "容器命名空间: ${CONTAINERD_NAMESPACE:-k8s.io}"
    echo "日志文件: ${LOG_FILE:-/var/log/k8s-image-cleanup.log}"
    echo "配置文件: $CONF_FILE"
}

# 主函数
main() {
    local action="${1:-help}"
    
    case "$action" in
        "cleanup-all-nodes")
            cleanup_all_nodes
            ;;
        "cleanup-node")
            if [[ -z "${2:-}" ]]; then
                log_error "请指定节点IP: $0 cleanup-node <node_ip>"
                exit 1
            fi
            # 简化版：需要从配置中查找节点信息
            log_warn "cleanup-node 功能需要从配置中查找节点信息，请使用 cleanup-all-nodes"
            exit 1
            ;;
        "check-disk-usage")
            if check_disk_usage; then
                echo "磁盘使用率满足清理条件"
                exit 0
            else
                echo "磁盘使用率不满足清理条件"
                exit 1
            fi
            ;;
        "show-config")
            show_config
            ;;
        "help"|"--help"|"-h"|*)
            cat <<EOF
镜像清理脚本（完全独立，不依赖 Harbor）

用法:
  $0 cleanup-all-nodes          # 清理所有节点
  $0 check-disk-usage          # 检查磁盘使用率
  $0 show-config               # 显示配置
  $0 help                       # 显示帮助

配置:
  配置文件: $CONF_FILE
  日志文件: ${LOG_FILE:-/var/log/k8s-image-cleanup.log}

EOF
            ;;
    esac
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

