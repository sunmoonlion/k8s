#!/bin/bash

# =============================================================================
# Harbor Clastic服务端部署插件
# 文件名: harbor-clastic-deploy.sh
# 用途: Harbor在Clastic环境下的服务端部署
# =============================================================================

set -euo pipefail

# 获取项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

# 计算 k8s 根目录（utils 的父目录）
# unified-cert-secret-management/ -> utils/ -> k8s/
K8S_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"

# 加载配置文件（如果存在）
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
# Harbor Clastic服务端部署
# =============================================================================

deploy_harbor_clastic() {
    local service_type="$1"      # harbor
    local server_env="$2"       # clastic
    local server_node="$3"      # 1
    local client_env="$4"       # docker
    local client_node="$5"      # 1
    
    # 生成组合代码
    local combo="${service_type}_${server_env}${server_node}_${client_env}${client_node}"
    
    log_info "部署Harbor Clastic服务端..."
    log_info "组合代码: $combo"
    
    # 获取运行模式（从环境变量或配置文件）
    local tls_mode="${TLS_MODE:-rotate}"
    
    # 1. 生成CA证书
    if ! generate_ca_certificate "$combo"; then
        log_error "CA证书生成失败"
        return 1
    fi
    
    # 在 init 模式下，只生成和分发 CA，关闭其他功能
    if [[ "$tls_mode" == "init" ]]; then
        log_info "初始化模式 (init)：只生成和分发 CA 证书，关闭服务器证书生成、服务配置更新和服务重启"
        
        # 归档CA证书
        log_info "开始服务端证书归档..."
        local local_ca_cert_dir=$(get_five_layer_config "$combo" "LOCAL_CA_CERT_DIR")
        if [[ -n "$local_ca_cert_dir" ]]; then
            mkdir -p "$local_ca_cert_dir"
        fi
        
        local server_prefix=$(echo "$combo" | sed 's/_[KDN][0-9]*$//')
        local temp_ca_cert_path="/tmp/${server_prefix}-ca-certs/ca.crt"
        local temp_ca_key_path="/tmp/${server_prefix}-ca-certs/ca.key"
        
        # 归档CA证书
        if [[ -f "$temp_ca_cert_path" && -n "$local_ca_cert_dir" ]]; then
            cp "$temp_ca_cert_path" "$local_ca_cert_dir/ca.crt"
            log_info "CA证书已归档到: $local_ca_cert_dir/ca.crt"
        fi
        if [[ -f "$temp_ca_key_path" && -n "$local_ca_cert_dir" ]]; then
            cp "$temp_ca_key_path" "$local_ca_cert_dir/ca.key"
            log_info "CA私钥已归档到: $local_ca_cert_dir/ca.key"
        fi
        
        log_success "初始化模式：CA证书生成和归档完成"
        log_info "初始化模式：跳过服务器证书生成、服务配置更新和服务重启"
        # 注意：CA 分发到客户端的逻辑在客户端部署插件中执行
        return 0
    fi
    
    # 检查是否启用服务器证书生成（非 init 模式）
    local generate_server_cert=$(get_five_layer_config "$combo" "GENERATE_SERVER_CERT_ENABLED")
    if [[ -z "$generate_server_cert" ]]; then
        generate_server_cert="true"  # 默认启用
    fi
    
    # 2. 生成服务器证书（如果启用）
    if [[ "$generate_server_cert" == "true" ]]; then
        log_info "服务器证书生成已启用，开始生成服务器证书..."
        if ! generate_server_certificate "$combo"; then
            log_error "服务器证书生成失败"
            return 1
        fi
    else
        log_info "服务器证书生成已禁用 (GENERATE_SERVER_CERT_ENABLED=false)，跳过服务器证书生成"
    fi
    
    # 3. 分发证书到服务端（仅在服务器证书生成启用时）
    if [[ "$generate_server_cert" == "true" ]]; then
        if ! distribute_certificates_to_server "$combo"; then
            log_error "Harbor Clastic服务端证书分发失败"
            return 1
        fi
    else
        log_info "服务器证书生成已禁用，跳过服务器证书分发"
    fi
    
    # 4. 更新Harbor配置文件
    local server_host=$(get_five_layer_config "$combo" "SERVER_HOST")
    local server_port=$(get_five_layer_config "$combo" "SERVER_PORT")
    local server_username=$(get_five_layer_config "$combo" "SERVER_USERNAME")
    local server_ssh_key=$(get_five_layer_config "$combo" "SERVER_SSH_KEY")
    local ca_cert_dir=$(get_five_layer_config "$combo" "SERVER_CA_CERT_DIR")
    local server_cert_dir=$(get_five_layer_config "$combo" "SERVER_SERVER_CERT_DIR")
    # 兜底默认目录
    if [[ -z "$ca_cert_dir" ]]; then
        ca_cert_dir="/etc/ssl/certs"
    fi
    if [[ -z "$server_cert_dir" ]]; then
        server_cert_dir="/etc/harbor/certs"
    fi
    
    # 更新Harbor配置文件中的证书路径（CA证书和服务器证书使用不同目录）
    local update_harbor_config_cmd="sudo sed -i 's|/etc/harbor/certs/ca.crt|$ca_cert_dir/ca.crt|g' /etc/harbor/harbor.yml && sudo sed -i 's|/etc/harbor/certs/harbor.crt|$server_cert_dir/server.crt|g' /etc/harbor/harbor.yml && sudo sed -i 's|/etc/harbor/certs/harbor.key|$server_cert_dir/server.key|g' /etc/harbor/harbor.yml"
    if ! execute_ssh_command_with_retry "$server_host" "$server_port" "$server_username" "$server_ssh_key" "$update_harbor_config_cmd"; then
        log_warn "Harbor配置文件更新失败，但继续执行"
    fi
    
    # 5. 重启Harbor服务
    local restart_cmd=$(get_five_layer_config "$combo" "SERVER_SERVICE_RESTART_CMD")
    if [[ -n "$restart_cmd" ]]; then
        if ! execute_ssh_command_with_retry "$server_host" "$server_port" "$server_username" "$server_ssh_key" "sudo $restart_cmd"; then
            log_error "Harbor Clastic服务重启失败"
            return 1
        fi
    fi
    
    # 6. 服务端证书归档
    log_info "开始服务端证书归档..."
    
    # 获取服务端归档配置
    local local_cert_dir=$(get_five_layer_config "$combo" "LOCAL_CERT_DIR")
    local local_server_cert_dir=$(get_five_layer_config "$combo" "LOCAL_SERVER_CERT_DIR")
    local local_ca_cert_dir=$(get_five_layer_config "$combo" "LOCAL_CA_CERT_DIR")
    
    # 创建归档目录
    if [[ -n "$local_cert_dir" ]]; then
        mkdir -p "$local_cert_dir"
    fi
    if [[ -n "$local_server_cert_dir" ]]; then
        mkdir -p "$local_server_cert_dir"
    fi
    if [[ -n "$local_ca_cert_dir" ]]; then
        mkdir -p "$local_ca_cert_dir"
    fi
    
    # 使用临时证书文件（按前三层前缀存放）
    local server_prefix=$(echo "$combo" | sed 's/_[KDN][0-9]*$//')
    local temp_ca_cert_path="/tmp/${server_prefix}-ca-certs/ca.crt"
    local temp_ca_key_path="/tmp/${server_prefix}-ca-certs/ca.key"
    local temp_server_cert_path="/tmp/${server_prefix}-server-certs/server.crt"
    local temp_server_key_path="/tmp/${server_prefix}-server-certs/server.key"
    
    # 归档CA证书
    if [[ -f "$temp_ca_cert_path" && -n "$local_ca_cert_dir" ]]; then
        cp "$temp_ca_cert_path" "$local_ca_cert_dir/ca.crt"
        log_info "CA证书已归档到: $local_ca_cert_dir/ca.crt"
    fi
    
    if [[ -f "$temp_ca_key_path" && -n "$local_ca_cert_dir" ]]; then
        cp "$temp_ca_key_path" "$local_ca_cert_dir/ca.key"
        log_info "CA私钥已归档到: $local_ca_cert_dir/ca.key"
    fi
    
    # 归档服务器证书（仅在服务器证书生成启用时）
    if [[ "$generate_server_cert" == "true" ]]; then
        if [[ -f "$temp_server_cert_path" && -n "$local_server_cert_dir" ]]; then
            cp "$temp_server_cert_path" "$local_server_cert_dir/server.crt"
            log_info "服务器证书已归档到: $local_server_cert_dir/server.crt"
        fi
        
        if [[ -f "$temp_server_key_path" && -n "$local_server_cert_dir" ]]; then
            cp "$temp_server_key_path" "$local_server_cert_dir/server.key"
            log_info "服务器私钥已归档到: $local_server_cert_dir/server.key"
        fi
    else
        log_info "服务器证书生成已禁用，跳过服务器证书归档"
    fi
    
    log_success "服务端证书归档完成"
    
    log_success "Harbor Clastic服务端部署完成"
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
    
    deploy_harbor_clastic "$@"
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
