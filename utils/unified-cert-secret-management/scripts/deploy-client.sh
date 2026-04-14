#!/bin/bash

# =============================================================================
# 通用客户端部署脚本
# 文件名: deploy-client.sh
# 用途: 根据服务类型和客户端环境调用相应的部署插件
# =============================================================================

set -euo pipefail

# 获取项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 加载公共函数
source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/ssh.sh"

# =============================================================================
# 客户端部署主函数
# =============================================================================

deploy_client() {
    local service_type="$1"
    local server_env="$2"
    local server_node="$3"
    local client_env="$4"
    local client_node="$5"
    
    log_info "部署客户端: $client_env for $service_type"
    
    # 检查部署插件是否存在
    # 优先使用带节点号的插件，如果没有则使用不带节点号的插件
    # 将服务类型映射到正确的文件名前缀
    local script_prefix=""
    case "$service_type" in
        "HARBOR")
            script_prefix="harbor"
            ;;
        "POSTGRESQL")
            script_prefix="postgresql"
            ;;
        *)
            script_prefix="${service_type,,}"  # 转换为小写
            ;;
    esac
    
    local deploy_script="$PROJECT_ROOT/scripts/plugins/client/${script_prefix}-${client_env}-${client_node}-deploy-client.sh"
    if [[ ! -f "$deploy_script" ]]; then
        deploy_script="$PROJECT_ROOT/scripts/plugins/client/${script_prefix}-${client_env}-deploy-client.sh"
        if [[ ! -f "$deploy_script" ]]; then
            log_error "客户端部署插件不存在: $deploy_script"
            log_info "请创建插件: scripts/plugins/client/${script_prefix}-${client_env}-deploy-client.sh"
            return 1
        fi
    fi
    
    # 调用部署插件
    log_info "调用部署插件: $deploy_script"
    # 确保 CLUSTER 环境变量传递到插件脚本
    if [[ -n "${CLUSTER:-}" ]]; then
        export CLUSTER="${CLUSTER}"
    fi
    if ! bash "$deploy_script" "$service_type" "$server_env" "$server_node" "$client_env" "$client_node"; then
        log_error "客户端部署插件执行失败"
        return 1
    fi
    
    log_success "客户端部署完成"
    return 0
}

# =============================================================================
# 主函数
# =============================================================================

main() {
    if [[ $# -ne 5 ]]; then
        log_error "参数数量错误"
        echo "用法: $0 <service_type> <server_env> <server_node> <client_env> <client_node>"
        exit 1
    fi
    
    deploy_client "$@"
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
