#!/bin/bash

# =============================================================================
# 定时清理任务包装脚本
# 用途：定时任务的入口脚本，检查开关和条件后调用清理脚本
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载定时任务配置
PERIODIC_CONF_FILE="$SCRIPT_DIR/periodic-cleanup.conf"
if [[ -f "$PERIODIC_CONF_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$PERIODIC_CONF_FILE"
else
    echo "[ERROR] 定时任务配置文件不存在: $PERIODIC_CONF_FILE"
    exit 1
fi

# 清理脚本路径
CLEANUP_SCRIPT="$SCRIPT_DIR/image-cleanup.sh"

# 日志函数
log_with_timestamp() {
    local msg="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $msg" | tee -a "${LOG_FILE:-/var/log/k8s-image-cleanup.log}" 2>/dev/null || echo "[$timestamp] $msg"
}

# 检查定时任务是否启用
check_periodic_enabled() {
    if [[ "${PERIODIC_CLEANUP_ENABLED:-false}" != "true" ]]; then
        log_with_timestamp "[INFO] 定时清理任务未启用 (PERIODIC_CLEANUP_ENABLED=false)，跳过执行"
        return 1
    fi
    return 0
}

# 检查磁盘使用率（如果启用条件模式）
check_disk_condition() {
    local mode="${EXECUTION_MODE:-conditional}"
    
    if [[ "$mode" == "always" ]]; then
        log_with_timestamp "[INFO] 执行模式: always（总是执行，忽略磁盘使用率检查）"
        return 0
    fi
    
    log_with_timestamp "[INFO] 执行模式: conditional（条件执行，检查磁盘使用率）"
    
    # 调用清理脚本检查磁盘使用率
    if bash "$CLEANUP_SCRIPT" check-disk-usage >/dev/null 2>&1; then
        log_with_timestamp "[INFO] 磁盘使用率满足清理条件"
        return 0
    else
        log_with_timestamp "[INFO] 磁盘使用率不满足清理条件，跳过清理"
        return 1
    fi
}

# 执行清理
execute_cleanup() {
    log_with_timestamp "[INFO] 开始执行定期镜像清理..."
    
    # 检查清理脚本是否存在
    if [[ ! -f "$CLEANUP_SCRIPT" ]]; then
        log_with_timestamp "[ERROR] 清理脚本不存在: $CLEANUP_SCRIPT"
        return 1
    fi
    
    # 执行清理
    if bash "$CLEANUP_SCRIPT" cleanup-all-nodes; then
        log_with_timestamp "[SUCCESS] 定期镜像清理完成"
        return 0
    else
        log_with_timestamp "[ERROR] 定期镜像清理失败"
        return 1
    fi
}

# 主函数
main() {
    local force="${1:-}"
    
    log_with_timestamp "[INFO] ========================================"
    log_with_timestamp "[INFO] 定期镜像清理任务开始"
    
    # 检查定时任务开关
    if [[ "$force" != "--force" ]]; then
        if ! check_periodic_enabled; then
            log_with_timestamp "[INFO] 定时清理任务结束（未启用）"
            log_with_timestamp "[INFO] ========================================"
            return 0
        fi
    else
        log_with_timestamp "[INFO] 强制模式，跳过定时任务开关检查"
    fi
    
    # 检查磁盘使用率（如果启用条件模式）
    if [[ "$force" != "--force" ]]; then
        if ! check_disk_condition; then
            log_with_timestamp "[INFO] 定时清理任务结束（条件不满足）"
            log_with_timestamp "[INFO] ========================================"
            return 0
        fi
    else
        log_with_timestamp "[INFO] 强制模式，跳过磁盘使用率检查"
    fi
    
    # 执行清理
    execute_cleanup
    
    log_with_timestamp "[INFO] 定时清理任务结束"
    log_with_timestamp "[INFO] ========================================"
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

