#!/bin/bash

# =============================================================================
# Traefik 服务器证书生成脚本
# 文件名: generate-server-cert.sh
# 用途: 生成Traefik TLS Secret所需的服务器证书
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_CERT_DIR="$(dirname "$SCRIPT_DIR")"  # server-cert 目录
SECRET_DIR="$(dirname "$SERVER_CERT_DIR")"  # traefik-tls-secret 目录
# 计算项目根目录（k8s目录）
# 从 generate-server-cert/ 向上8级到达 k8s/
# generate-server-cert/ -> server-cert/ -> traefik-tls-secret/ -> secrets/ -> deploy-traefik/ -> traefik/ -> ingress-platform/ -> sunmoonai/ -> k8s/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../../../.." && pwd)"

# 先加载日志函数（包含在 secret-core.sh 中）
source "$PROJECT_ROOT/utils/secret-management/lib/secret-core.sh"

# 计算 Traefik 部署配置路径
# 从 generate-server-cert/ 向上4级到达 deploy-traefik/
# generate-server-cert/ -> server-cert/ -> traefik-tls-secret/ -> secrets/ -> deploy-traefik/
TRAEFIK_DEPLOY_DIR="$(cd "$SCRIPT_DIR/../../../../" && pwd)"
TRAEFIK_CONFIG_FILE="$TRAEFIK_DEPLOY_DIR/deploy-traefik.conf"

# 加载 Traefik 主配置文件（优先，包含 CA 路径配置）
if [[ -f "$TRAEFIK_CONFIG_FILE" ]]; then
    source "$TRAEFIK_CONFIG_FILE"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$PROJECT_ROOT/utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
else
    log_error "Traefik 配置文件不存在: $TRAEFIK_CONFIG_FILE"
    exit 1
fi

# 加载证书生成核心函数（服务器证书生成在 secret-management 中）
source "$PROJECT_ROOT/utils/secret-management/lib/cert-core.sh"

# 加载证书生成配置文件（服务器证书生成的主要配置源）
# 注意：此配置文件是服务器证书生成的权威配置源
# cert-secret.conf 中的配置仅供参考，主要用于 CA 证书管理和 Secret 部署
CONFIG_FILE="$SCRIPT_DIR/generate-server-cert.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    
    # 应用集群配置映射（如果有证书生成配置中的集群特定配置）
    if [[ -f "$PROJECT_ROOT/utils/cluster-config-mapping.sh" ]]; then
        apply_cluster_config_mapping
    fi
fi

# 如果 SERVER_IPS 未设置，尝试从 cert-secret.conf 读取 TRAEFIK_K1_K1_SERVER_IP_* 配置
if [[ -z "${SERVER_IPS:-}" ]]; then
    local cert_secret_conf="$PROJECT_ROOT/utils/unified-cert-secret-management/cert-secret.conf"
    if [[ -f "$cert_secret_conf" ]]; then
        # 加载 cert-secret.conf 以读取 IP 配置
        source "$cert_secret_conf" 2>/dev/null || true
        
        # 应用集群配置映射（如果存在）
        if [[ -f "$PROJECT_ROOT/utils/cluster-config-mapping.sh" ]]; then
            source "$PROJECT_ROOT/utils/cluster-config-mapping.sh"
            apply_cluster_config_mapping 2>/dev/null || true
        fi
        
        # 收集所有 TRAEFIK_K1_K1_SERVER_IP_* 配置
        local ips=()
        for i in {1..10}; do
            local ip_var="TRAEFIK_K1_K1_SERVER_IP_$i"
            # 使用间接变量引用
            local ip_value=""
            eval "ip_value=\"\${$ip_var:-}\""
            if [[ -n "$ip_value" ]]; then
                ips+=("$ip_value")
            fi
        done
        
        # 如果找到了 IP 配置，设置 SERVER_IPS
        if [[ ${#ips[@]} -gt 0 ]]; then
            SERVER_IPS="${ips[*]}"
            log_info "从 cert-secret.conf 读取 IP 配置: $SERVER_IPS"
        fi
    fi
fi

main() {
    log_info "开始生成Traefik服务器证书..."
    
    # 获取CA路径（从 Traefik 配置读取）
    local ca_dir="${TRAEFIK_CA_LOCAL_DIR/#\~/$HOME}"
    local ca_cert="$ca_dir/ca.crt"
    local ca_key="$ca_dir/ca.key"
    
    # 检查CA是否存在（严格检查：不存在则报错退出，不生成CA）
    if [[ ! -f "$ca_cert" || ! -f "$ca_key" ]]; then
        log_error "❌ CA不存在，无法生成服务器证书"
        log_error ""
        log_error "CA证书路径: $ca_cert"
        log_error "CA私钥路径: $ca_key"
        log_error ""
        log_error "CA路径配置: TRAEFIK_CA_LOCAL_DIR=${TRAEFIK_CA_LOCAL_DIR:-未设置}"
        log_error "配置文件: $TRAEFIK_CONFIG_FILE"
        log_error ""
        log_error "请先通过基础设施部署流程生成统一CA："
        log_error "  1. 运行基础设施部署的 Step12 生成CA："
        log_error "     cd ~/master/k8s/sunmoonai/infrastructure/deploy-infrastructure-all"
        log_error "     bash deploy-infrastructure-all.sh deploy"
        log_error ""
        log_error "  2. 或者单独运行 Step12："
        log_error "     bash ~/master/k8s/sunmoonai/infrastructure/steps/step12_ca_generation.sh all"
        log_error ""
        log_error "  3. 或者手动运行CA生成脚本（不推荐，仅用于测试）："
        log_error "     ~/master/k8s/utils/ca-management/generate-ca.sh"
        log_error ""
        log_error "注意："
        log_error "  - CA必须由基础设施统一管理，不能在各组件中单独生成，以避免CA混乱"
        log_error "  - CA路径在 Traefik 配置文件（deploy-traefik.conf）中的 TRAEFIK_CA_LOCAL_DIR 设置"
        exit 1
    fi
    
    # 输出目录：server-cert/（与 generate-server-cert 同级）
    local output_dir="$SERVER_CERT_DIR"
    
    log_info "配置信息:"
    log_info "  - CA证书: $ca_cert"
    log_info "  - CA私钥: $ca_key"
    log_info "  - 输出目录: $output_dir"
    log_info "  - 服务器CN: ${SERVER_CN:-}"
    log_info "  - 服务器DNS: ${SERVER_DNS:-}"
    log_info "  - 服务器IPs: ${SERVER_IPS:-}"
    log_info "  - 有效期: ${SERVER_DAYS:-365} 天"
    log_info "  - 密钥长度: ${SERVER_KEY_SIZE:-2048} 位"
    echo ""
    
    # 调用证书生成函数
    generate_server_cert_from_ca \
        --ca-cert "$ca_cert" \
        --ca-key "$ca_key" \
        --server-cn "${SERVER_CN}" \
        --server-dns "${SERVER_DNS:-}" \
        --server-ips "${SERVER_IPS:-}" \
        --output-dir "$output_dir" \
        --days "${SERVER_DAYS:-365}" \
        --key-size "${SERVER_KEY_SIZE:-2048}"
    
    echo ""
    log_success "Traefik服务器证书生成完成"
    log_info "证书位置: $output_dir/server.crt"
    log_info "私钥位置: $output_dir/server.key"
}

main "$@"

