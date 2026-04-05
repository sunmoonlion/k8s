#!/bin/bash

# =============================================================================
# SSH工具库
# 文件名: ssh.sh
# 用途: 提供SSH连接、命令执行和文件传输功能
# 设计: 基于五层架构，支持重试机制和日志记录
# =============================================================================

# 加载公共函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# =============================================================================
# SSH连接配置
# =============================================================================

# 从cert-secret.conf加载SSH配置
SSH_TIMEOUT=$(get_config "SSH_TIMEOUT")
SSH_RETRY_COUNT=$(get_config "SSH_RETRY_COUNT")
SSH_RETRY_DELAY=$(get_config "SSH_RETRY_DELAY")

# =============================================================================
# SSH命令执行函数
# =============================================================================

# 执行远程SSH命令
execute_ssh_command() {
    local host="$1"
    local port="$2"
    local username="$3"
    local ssh_key="$4"
    local command="$5"

    log_info "执行SSH命令: $host:$port"
    log_debug "命令: $command"

    local ssh_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=${SSH_TIMEOUT:-30}"
    local identity_file_opt=""
    if [[ -n "$ssh_key" ]] && [[ -f "$ssh_key" ]]; then
        identity_file_opt="-i $ssh_key"
    fi

    ssh -p "$port" $identity_file_opt $ssh_opts "$username@$host" "$command"
}

# 带重试机制的远程SSH命令执行
execute_ssh_command_with_retry() {
    local host="$1"
    local port="$2"
    local username="$3"
    local ssh_key="$4"
    local command="$5"
    local retry_count="${SSH_RETRY_COUNT:-3}"
    local retry_delay="${SSH_RETRY_DELAY:-5}"

    for ((i=1; i<=$retry_count; i++)); do
        log_debug "SSH尝试 $i/$retry_count"
        if execute_ssh_command "$host" "$port" "$username" "$ssh_key" "$command"; then
            log_success "SSH命令执行成功: $host"
            return 0
        else
            log_warn "SSH命令执行失败 (尝试 $i/$retry_count): $host"
            if [[ "$i" -lt "$retry_count" ]]; then
                log_info "等待 $retry_delay 秒后重试..."
                sleep "$retry_delay"
            fi
        fi
    done

    log_error "SSH命令执行失败，已达到最大重试次数: $host"
    return 1
}

# =============================================================================
# SCP文件传输函数
# =============================================================================

# 传输文件到远程主机
transfer_file() {
    local local_path="$1"
    local remote_host="$2"
    local remote_port="$3"
    local remote_username="$4"
    local remote_ssh_key="$5"
    local remote_path="$6"

    log_info "执行SCP传输: $local_path -> $remote_host:$remote_path"

    local scp_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=${SSH_TIMEOUT:-30}"
    local identity_file_opt=""
    if [[ -n "$remote_ssh_key" ]] && [[ -f "$remote_ssh_key" ]]; then
        identity_file_opt="-i $remote_ssh_key"
    fi

    # 处理端口参数
    local port_opt=""
    if [[ -n "$remote_port" ]]; then
        port_opt="-P $remote_port"
    fi
    
    scp $port_opt $identity_file_opt $scp_opts "$local_path" "$remote_username@$remote_host:$remote_path"
}

# 带重试机制的SCP下载
execute_scp_command_with_retry() {
    local remote_host="$1"
    local remote_port="$2"
    local remote_username="$3"
    local remote_ssh_key="$4"
    local remote_path="$5"
    local local_path="$6"
    local retry_count="${SSH_RETRY_COUNT:-3}"
    local retry_delay="${SSH_RETRY_DELAY:-5}"

    for ((i=1; i<=$retry_count; i++)); do
        log_info "🔍 SCP尝试 $i/$retry_count"
        log_info "ℹ️  执行SCP下载: $remote_username@$remote_host:$remote_path -> $local_path"
        
        if scp -i "$remote_ssh_key" -P "$remote_port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$remote_username@$remote_host:$remote_path" "$local_path" 2>/dev/null; then
            log_success "✅ SCP下载成功: $remote_host"
            return 0
        else
            log_warn "⚠️  SCP下载失败 (尝试 $i/$retry_count): $remote_host"
            if [[ $i -lt $retry_count ]]; then
                log_info "ℹ️  等待 $retry_delay 秒后重试..."
                sleep $retry_delay
            fi
        fi
    done
    
    log_error "❌ SCP下载失败，已达到最大重试次数: $remote_host"
    return 1
}

# 带重试机制的文件传输
transfer_file_with_retry() {
    local local_path="$1"
    local remote_host="$2"
    local remote_port="$3"
    local remote_username="$4"
    local remote_ssh_key="$5"
    local remote_path="$6"
    local retry_count="${SSH_RETRY_COUNT:-3}"
    local retry_delay="${SSH_RETRY_DELAY:-5}"

    for ((i=1; i<=$retry_count; i++)); do
        log_debug "SCP尝试 $i/$retry_count"
        if transfer_file "$local_path" "$remote_host" "$remote_port" "$remote_username" "$remote_ssh_key" "$remote_path"; then
            log_success "SCP传输成功: $remote_host"
            return 0
        else
            log_warn "SCP传输失败 (尝试 $i/$retry_count): $remote_host"
            if [[ "$i" -lt "$retry_count" ]]; then
                log_info "等待 $retry_delay 秒后重试..."
                sleep "$retry_delay"
            fi
        fi
    done

    log_error "SCP传输失败，已达到最大重试次数: $remote_host"
    return 1
}

# =============================================================================
# 五层架构专用函数
# =============================================================================

# 分发证书到服务端
distribute_certificates_to_server() {
    # 检查参数数量，支持组合代码或5个参数
    if [[ $# -eq 1 ]]; then
        # 组合代码格式
        local combo="$1"
        local server_host=$(get_five_layer_config "$combo" "SERVER_HOST")
        local server_port=$(get_five_layer_config "$combo" "SERVER_PORT")
        local server_username=$(get_five_layer_config "$combo" "SERVER_USERNAME")
        local server_ssh_key=$(get_five_layer_config "$combo" "SERVER_SSH_KEY")
        local server_cert_dir=$(get_five_layer_config "$combo" "SERVER_CERT_DIR")
    else
        # 5个参数格式
        local service_type="$1"
        local server_env="$2"
        local server_node="$3"
        local client_env="$4"
        local client_node="$5"
        
        local server_host=$(get_five_layer_config "$service_type" "$server_env" "$server_node" "$client_env" "$client_node" "SERVER_HOST")
        local server_port=$(get_five_layer_config "$service_type" "$server_env" "$server_node" "$client_env" "$client_node" "SERVER_PORT")
        local server_username=$(get_five_layer_config "$service_type" "$server_env" "$server_node" "$client_env" "$client_node" "SERVER_USERNAME")
        local server_ssh_key=$(get_five_layer_config "$service_type" "$server_env" "$server_node" "$client_env" "$client_node" "SERVER_SSH_KEY")
        local server_cert_dir=$(get_five_layer_config "$service_type" "$server_env" "$server_node" "$client_env" "$client_node" "SERVER_CERT_DIR")
    fi
    
    log_info "分发证书到服务端..."
    
    # 使用临时证书文件
    local temp_ca_cert_path="$TEMP_CA_CERT_PATH"
    local temp_ca_key_path="$TEMP_CA_KEY_PATH"
    local temp_server_cert_path="$TEMP_SERVER_CERT_PATH"
    local temp_server_key_path="$TEMP_SERVER_KEY_PATH"
    
    # 检查远程证书是否已存在且有效
    local check_cert_cmd="test -f $server_cert_dir/ca.crt && test -f $server_cert_dir/ca.key && test -f $server_cert_dir/server.crt && test -f $server_cert_dir/server.key"
    if execute_ssh_command_with_retry "$server_host" "$server_port" "$server_username" "$server_ssh_key" "$check_cert_cmd" >/dev/null 2>&1; then
        log_info "远程证书已存在，跳过分发: $server_host:$server_cert_dir"
        return 0
    fi
    
    # 创建远程目录
    local create_dir_cmd="sudo mkdir -p $server_cert_dir && sudo chown $server_username:$server_username $server_cert_dir"
    if ! execute_ssh_command_with_retry "$server_host" "$server_port" "$server_username" "$server_ssh_key" "$create_dir_cmd"; then
        log_error "创建远程目录失败"
        return 1
    fi
    
    # 传输CA证书
    if ! transfer_file_with_retry "$temp_ca_cert_path" "$server_host" "$server_port" "$server_username" "$server_ssh_key" "/tmp/ca.crt"; then
        log_error "传输CA证书失败"
        return 1
    fi
    
    # 传输CA私钥
    if ! transfer_file_with_retry "$temp_ca_key_path" "$server_host" "$server_port" "$server_username" "$server_ssh_key" "/tmp/ca.key"; then
        log_error "传输CA私钥失败"
        return 1
    fi
    
    # 传输服务器证书
    if ! transfer_file_with_retry "$temp_server_cert_path" "$server_host" "$server_port" "$server_username" "$server_ssh_key" "/tmp/server.crt"; then
        log_error "传输服务器证书失败"
        return 1
    fi
    
    # 传输服务器私钥
    if ! transfer_file_with_retry "$temp_server_key_path" "$server_host" "$server_port" "$server_username" "$server_ssh_key" "/tmp/server.key"; then
        log_error "传输服务器私钥失败"
        return 1
    fi
    
    # 移动文件到最终位置并设置权限
    local move_files_cmd="sudo mv /tmp/ca.crt $server_cert_dir/ && sudo mv /tmp/ca.key $server_cert_dir/ && sudo mv /tmp/server.crt $server_cert_dir/ && sudo mv /tmp/server.key $server_cert_dir/ && sudo chown $server_username:$server_username $server_cert_dir/* && sudo chmod 600 $server_cert_dir/*.key && sudo chmod 644 $server_cert_dir/*.crt"
    if ! execute_ssh_command_with_retry "$server_host" "$server_port" "$server_username" "$server_ssh_key" "$move_files_cmd"; then
        log_warn "设置远程文件权限失败"
    fi
    
    log_success "证书分发到服务端完成"
}

# 分发CA证书到客户端
distribute_ca_certificate_to_client() {
    # 检查参数数量，支持组合代码或5个参数
    if [[ $# -eq 1 ]]; then
        # 组合代码格式
        local combo="$1"
        local client_host=$(get_five_layer_config "$combo" "CLIENT_HOST")
        local client_port=$(get_five_layer_config "$combo" "CLIENT_PORT")
        local client_username=$(get_five_layer_config "$combo" "CLIENT_USERNAME")
        local client_ssh_key=$(get_five_layer_config "$combo" "CLIENT_SSH_KEY")
        local client_cert_dir=$(get_five_layer_config "$combo" "CLIENT_CERT_DIR")
        local client_ca_path=$(get_five_layer_config "$combo" "CLIENT_CA_CERT_PATH")
    else
        # 5个参数格式
        local service_type="$1"
        local server_env="$2"
        local server_node="$3"
        local client_env="$4"
        local client_node="$5"
        
        # 生成组合代码
        local combo=$(generate_five_layer_code "$service_type" "$server_env" "$server_node" "$client_env" "$client_node")
        
        local client_host=$(get_five_layer_config "$service_type" "$server_env" "$server_node" "$client_env" "$client_node" "CLIENT_HOST")
        local client_port=$(get_five_layer_config "$service_type" "$server_env" "$server_node" "$client_env" "$client_node" "CLIENT_PORT")
        local client_username=$(get_five_layer_config "$service_type" "$server_env" "$server_node" "$client_env" "$client_node" "CLIENT_USERNAME")
        local client_ssh_key=$(get_five_layer_config "$service_type" "$server_env" "$server_node" "$client_env" "$client_node" "CLIENT_SSH_KEY")
        local client_cert_dir=$(get_five_layer_config "$service_type" "$server_env" "$server_node" "$client_env" "$client_node" "CLIENT_CERT_DIR")
        local client_ca_path=$(get_five_layer_config "$service_type" "$server_env" "$server_node" "$client_env" "$client_node" "CLIENT_CA_CERT_PATH")
    fi
    
    log_info "分发CA证书到客户端..."
    
    # 从服务端获取已分发的CA证书
    local server_host=$(get_five_layer_config "$combo" "SERVER_HOST")
    local server_port=$(get_five_layer_config "$combo" "SERVER_PORT")
    local server_username=$(get_five_layer_config "$combo" "SERVER_USERNAME")
    local server_ssh_key=$(get_five_layer_config "$combo" "SERVER_SSH_KEY")
    local server_cert_dir=$(get_five_layer_config "$combo" "SERVER_CERT_DIR")
    
    # 从服务端下载CA证书到本地临时文件
    local temp_ca_cert_path="/tmp/${combo}-client-ca.crt"
    local remote_ca_cert_path="$server_cert_dir/ca.crt"
    
    # 检查远程CA证书是否已存在
    local check_ca_cmd="test -f $client_ca_path"
    if execute_ssh_command_with_retry "$client_host" "$client_port" "$client_username" "$client_ssh_key" "$check_ca_cmd" >/dev/null 2>&1; then
        log_info "远程CA证书已存在，跳过分发: $client_host:$client_ca_path"
        return 0
    fi
    
    # 从服务端下载CA证书
    log_info "从服务端下载CA证书: $server_host:$remote_ca_cert_path"
    local scp_cmd="scp -i $server_ssh_key -P $server_port $server_username@$server_host:$remote_ca_cert_path $temp_ca_cert_path"
    if ! execute_scp_command_with_retry "$server_host" "$server_port" "$server_username" "$server_ssh_key" "$remote_ca_cert_path" "$temp_ca_cert_path"; then
        log_error "从服务端下载CA证书失败"
        return 1
    fi
    
    # 创建远程目录
    local create_dir_cmd="sudo mkdir -p $client_cert_dir && sudo chown $client_username:$client_username $client_cert_dir"
    if ! execute_ssh_command_with_retry "$client_host" "$client_port" "$client_username" "$client_ssh_key" "$create_dir_cmd"; then
        log_error "创建远程目录失败"
        return 1
    fi
    
    # 传输CA证书
    if ! transfer_file_with_retry "$temp_ca_cert_path" "$client_host" "$client_port" "$client_username" "$client_ssh_key" "/tmp/ca.crt"; then
        log_error "传输CA证书失败"
        return 1
    fi
    
    # 移动文件到最终位置并设置权限
    local move_files_cmd="sudo cp /tmp/ca.crt $client_ca_path && sudo chown $client_username:$client_username $client_ca_path && sudo chmod 644 $client_ca_path && rm -f /tmp/ca.crt"
    if ! execute_ssh_command_with_retry "$client_host" "$client_port" "$client_username" "$client_ssh_key" "$move_files_cmd"; then
        log_warn "设置远程文件权限失败"
    fi
    
    log_success "CA证书分发到客户端完成"
}