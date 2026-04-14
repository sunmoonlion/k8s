#!/bin/bash

# =============================================================================
# Traefik Docker客户端部署插件
# 文件名: traefik-D-deploy-client.sh
# 用途: Traefik的Docker客户端CA证书分发
# =============================================================================

set -euo pipefail

# 获取项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

# 计算 k8s 根目录（utils 的父目录）
# unified-cert-secret-management/ -> utils/ -> k8s/
K8S_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"

# 加载配置文件
CONFIG_FILE="$PROJECT_ROOT/cert-secret.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# 加载集群配置映射函数（用于将 C1_* 或 C2_* 映射为默认配置）
if [[ -f "$K8S_ROOT/utils/cluster-config-mapping.sh" ]]; then
    source "$K8S_ROOT/utils/cluster-config-mapping.sh"
    # 应用集群配置映射（使用 CLUSTER 环境变量）
    if command -v apply_cluster_config_mapping &>/dev/null; then
        apply_cluster_config_mapping
    fi
fi

# 加载公共函数
source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/ssh.sh"
source "$PROJECT_ROOT/lib/cert.sh"

# =============================================================================
# Traefik Docker客户端CA证书分发
# =============================================================================

deploy_traefik_docker() {
    local service_type="$1"      # traefik
    local server_env="$2"       # k8s
    local server_node="$3"      # 1
    local client_env="$4"       # docker
    local client_node="$5"      # 1
    
    # 构建新的编码格式
    local combo="${service_type}_${server_env}${server_node}_${client_env}${client_node}"
    
    log_info "部署Traefik Docker客户端..."
    log_info "组合代码: $combo"
    
    # 记录服务端前三层前缀（用于根证书定位）
    local server_prefix=$(echo "$combo" | sed 's/_[KDN][0-9]*$//')
    log_info "服务端前缀: $server_prefix (CA路径: /tmp/${server_prefix}-ca-certs/ca.crt)"
    
    # 1. 分发CA证书到客户端
    if ! distribute_ca_certificate_to_client "$combo"; then
        log_error "Traefik Docker客户端CA证书分发失败"
        return 1
    fi
    
    # 注意：客户端认证Secret现在通过服务端的统一Secret配置系统处理
    # 客户端脚本只需要处理CA证书分发，Secret创建和部署由服务端统一管理
    log_info "客户端认证Secret由服务端统一Secret配置系统处理"
    
    log_success "Traefik Docker客户端部署完成"
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
    
    deploy_traefik_docker "$@"
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
