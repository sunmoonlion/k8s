#!/bin/bash

# =============================================================================
# Cron 任务安装脚本
# 用途：安装或更新定时清理任务的 Cron 配置
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLEANUP_DIR="$(dirname "$SCRIPT_DIR")"

# 加载定时任务配置
PERIODIC_CONF_FILE="$CLEANUP_DIR/periodic-cleanup.conf"
if [[ -f "$PERIODIC_CONF_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$PERIODIC_CONF_FILE"
else
    echo "[ERROR] 定时任务配置文件不存在: $PERIODIC_CONF_FILE"
    exit 1
fi

CRON_FILE="/etc/cron.d/k8s-image-cleanup"
CRON_EXAMPLE="$SCRIPT_DIR/k8s-image-cleanup.cron.example"

log_info() { echo -e "[INFO] $*"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $*" 1>&2; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }

# 检查权限
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限，请使用 sudo 执行"
        exit 1
    fi
}

# 生成 Cron 配置
generate_cron_config() {
    local schedule="${PERIODIC_CLEANUP_SCHEDULE:-0 2 * * *}"
    local user="${CRON_USER:-zym}"
    local script_path="$CLEANUP_DIR/periodic-cleanup.sh"
    local log_file="${LOG_FILE:-/var/log/k8s-image-cleanup.log}"
    
    cat <<EOF
# =============================================================================
# Kubernetes 镜像定期清理 Cron 配置
# 自动生成时间: $(date '+%Y-%m-%d %H:%M:%S')
# =============================================================================
# 
# 说明：
#   - 执行时间: $schedule
#   - 实际是否执行由 periodic-cleanup.conf 中的开关控制
#   - 日志文件: $log_file
#
# =============================================================================

# 定时清理任务
$schedule $user $script_path execute >> $log_file 2>&1

EOF
}

# 安装 Cron 配置
install_cron() {
    log_info "安装 Cron 配置..."
    
    # 生成配置
    local cron_config
    cron_config=$(generate_cron_config)
    
    # 写入文件
    echo "$cron_config" > "$CRON_FILE"
    chmod 644 "$CRON_FILE"
    chown root:root "$CRON_FILE"
    
    log_success "Cron 配置已安装: $CRON_FILE"
    echo ""
    echo "配置内容："
    echo "$cron_config"
    echo ""
    
    # 重启 Cron 服务
    log_info "重启 Cron 服务..."
    if systemctl restart cron 2>/dev/null || systemctl restart crond 2>/dev/null; then
        log_success "Cron 服务已重启"
    else
        log_error "Cron 服务重启失败，请手动重启"
    fi
}

# 卸载 Cron 配置
uninstall_cron() {
    log_info "卸载 Cron 配置..."
    
    if [[ -f "$CRON_FILE" ]]; then
        rm -f "$CRON_FILE"
        log_success "Cron 配置已卸载: $CRON_FILE"
        
        # 重启 Cron 服务
        log_info "重启 Cron 服务..."
        if systemctl restart cron 2>/dev/null || systemctl restart crond 2>/dev/null; then
            log_success "Cron 服务已重启"
        fi
    else
        log_info "Cron 配置文件不存在，无需卸载"
    fi
}

# 显示状态
show_status() {
    echo "=== Cron 配置状态 ==="
    echo ""
    
    if [[ -f "$CRON_FILE" ]]; then
        echo "✅ Cron 配置文件存在: $CRON_FILE"
        echo ""
        echo "配置内容："
        cat "$CRON_FILE"
    else
        echo "❌ Cron 配置文件不存在"
    fi
    
    echo ""
    echo "定时任务配置："
    echo "  开关: ${PERIODIC_CLEANUP_ENABLED:-false}"
    echo "  执行时间: ${PERIODIC_CLEANUP_SCHEDULE:-0 2 * * *}"
    echo "  执行模式: ${EXECUTION_MODE:-conditional}"
}

# 主函数
main() {
    local action="${1:-install}"
    
    case "$action" in
        "install")
            check_permissions
            install_cron
            ;;
        "uninstall")
            check_permissions
            uninstall_cron
            ;;
        "status")
            show_status
            ;;
        "help"|"--help"|"-h"|*)
            cat <<EOF
Cron 任务安装脚本

用法:
  sudo $0 install      # 安装 Cron 配置
  sudo $0 uninstall    # 卸载 Cron 配置
  $0 status            # 显示状态
  $0 help              # 显示帮助

EOF
            ;;
    esac
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

