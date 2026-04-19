#!/bin/bash

# =============================================================================
# 证书管理库
# 文件名: ca.sh
# 用途: 提供TLS证书生成、分发和验证功能
# 设计: 基于五层架构，支持独立CA和证书生命周期管理
# =============================================================================

# 加载公共函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/ssh.sh"

# 自动验证证书链一致性
verify_cert_chain_auto() {
    local server_crt="$1"
    local ca_crt="$2"
    
    if [[ ! -f "$server_crt" || ! -f "$ca_crt" ]]; then
        log_error "证书文件不存在: $server_crt 或 $ca_crt"
        return 1
    fi
    
    # 提取服务器证书的Authority Key Identifier
    local server_aki=$(openssl x509 -in "$server_crt" -text -noout | grep -A 1 "Authority Key Identifier" | tail -1 | tr -d ' :')
    
    # 提取CA证书的Subject Key Identifier
    local ca_ski=$(openssl x509 -in "$ca_crt" -text -noout | grep -A 1 "Subject Key Identifier" | tail -1 | tr -d ' :')
    
    if [[ "$server_aki" == "$ca_ski" ]]; then
        log_success "证书链验证通过: 服务器证书由CA证书签发"
        return 0
    else
        log_error "证书链验证失败: 服务器证书不是由CA证书签发"
        log_error "服务器证书Authority Key Identifier: $server_aki"
        log_error "CA证书Subject Key Identifier: $ca_ski"
        return 1
    fi
}

# =============================================================================
# 本地存储与Secret YAML渲染
# =============================================================================

# 本地保存CA公钥副本（默认仅保存 ca.crt）
save_local_ca_copy() {
    local combo="$1"
    local temp_cert_dir="/tmp/${combo}-certs"
    local local_ca_dir="${LOCAL_CA_DIR:-}"
    local save_enabled="${SAVE_LOCAL_CA_COPY:-false}"
    local save_private_key="${SAVE_LOCAL_CA_PRIVATE_KEY:-false}"

    if [[ "$save_enabled" != "true" ]]; then
        return 0
    fi

    if [[ -z "$local_ca_dir" ]]; then
        log_warn "未配置 LOCAL_CA_DIR，跳过本地CA保存"
        return 0
    fi

    mkdir -p "$local_ca_dir/$combo"

    local src_ca_crt="$temp_cert_dir/ca.crt"
    local src_ca_key="$temp_cert_dir/ca.key"
    local dst_ca_crt="$local_ca_dir/$combo/ca.crt"
    local dst_ca_key="$local_ca_dir/$combo/ca.key"

    if [[ -f "$src_ca_crt" ]]; then
        cp "$src_ca_crt" "$dst_ca_crt"
        chmod 644 "$dst_ca_crt"
        log_success "已保存本地CA证书: $dst_ca_crt"
    else
        log_warn "未找到CA证书: $src_ca_crt"
    fi

    if [[ "$save_private_key" == "true" && -f "$src_ca_key" ]]; then
        cp "$src_ca_key" "$dst_ca_key"
        chmod 600 "$dst_ca_key"
        log_warn "已保存本地CA私钥(请确保安全与gitignore): $dst_ca_key"
    fi
}

# 渲染Kubernetes Secret YAML并落地到本地
render_secret_yaml() {
    local combo="$1"
    local secret_type="${2:-}"
    local secret_name="${3:-}"
    local secret_namespace="${4:-}"
    
    # 如果提供了具体参数，使用它们；否则从配置中读取
    if [[ -n "$secret_type" && -n "$secret_name" && -n "$secret_namespace" ]]; then
        # 使用传入的参数
        log_info "使用传入参数: type=$secret_type, name=$secret_name, namespace=$secret_namespace"
    else
        # 回退到配置读取 - 使用新的统一配置系统
        log_warn "render_secret_yaml函数需要传入具体参数，不支持从旧配置读取"
        log_warn "请使用新的统一Secret配置系统"
        return 1
    fi
    

    if [[ -z "$secret_namespace" || -z "$secret_name" ]]; then
        log_debug "缺少 namespace 或 secret_name，跳过本地YAML渲染"
        return 0
    fi

    # 注意：全局LOCAL_SECRET_DIR配置已迁移到统一的Secret配置系统
    # 每个Secret的归档目录由 SECRET_${i}_LOCAL_SECRET_DIR 控制
    # 这里使用临时文件路径，归档由调用方处理
    # 使用命名空间和名称组合确保文件名唯一
    local local_secret_path="/tmp/${secret_namespace}-${secret_name}.yaml"

    mkdir -p "$(dirname "$local_secret_path")"

    # 根据Secret类型处理不同的数据
    case "$secret_type" in
        "kubernetes.io/tls")
            render_tls_secret_yaml "$combo" "$secret_name" "$secret_namespace" "$local_secret_path"
            ;;
        "kubernetes.io/dockerconfigjson")
            render_docker_auth_secret_yaml "$combo" "$secret_name" "$secret_namespace" "$local_secret_path"
            ;;
        "Opaque")
            render_opaque_secret_yaml "$combo" "$secret_name" "$secret_namespace" "$local_secret_path"
            ;;
        *)
            log_error "不支持的Secret类型: $secret_type"
            return 1
            ;;
    esac
}

# =============================================================================
# 参数提取函数
# =============================================================================

# 提取CA证书配置
get_ca_config() {
    local combo="$1"
    local cn=$(get_five_layer_config "$combo" "CA_CN")
    local days=$(get_five_layer_config "$combo" "CA_DAYS")
    local key_size=$(get_five_layer_config "$combo" "CA_KEY_SIZE")
    
    # 设置默认值
    cn=${cn:-"SunMoonAI Root CA"}
    days=${days:-3650}
    key_size=${key_size:-4096}
    
    # 返回配置（不包含日志输出）
    echo "$cn|$days|$key_size"
}

# 提取服务器证书配置
get_server_config() {
    local combo="$1"
    local cn=$(get_five_layer_config "$combo" "SERVER_CN")
    local days=$(get_five_layer_config "$combo" "SERVER_DAYS")
    local key_size=$(get_five_layer_config "$combo" "SERVER_KEY_SIZE")
    
    # 设置默认值
    cn=${cn:-"server"}
    days=${days:-365}
    key_size=${key_size:-2048}
    
    # 提取DNS配置
    local dns_list=()
    for i in {1..10}; do
        local dns=$(get_five_layer_config "$combo" "SERVER_DNS_$i")
        if [[ -n "$dns" ]]; then
            dns_list+=("$dns")
        fi
    done
    
    # 提取IP配置
    local ip_list=()
    for i in {1..10}; do
        local ip=$(get_five_layer_config "$combo" "SERVER_IP_$i")
        if [[ -n "$ip" ]]; then
            ip_list+=("$ip")
        fi
    done
    
    # 返回配置（不包含日志输出）
    echo "$cn|$days|$key_size|${dns_list[*]}|${ip_list[*]}"
}


# =============================================================================
# 证书生成函数
# =============================================================================

# 生成CA证书
generate_ca_certificate() {
    local combo="$1"
    # 按前三层（SERVICE_SERVERENVSERVERNODE）标识
    local server_prefix=$(echo "$combo" | sed 's/_[KDN][0-9]*$//')
    local output_dir="${2:-/tmp/${server_prefix}-ca-certs}"

    log_info "生成CA证书..."

    # 创建输出目录
    mkdir -p "$output_dir"

    # 设置输出文件路径
    local cert_path="$output_dir/ca.crt"
    local key_path="$output_dir/ca.key"
    
    # 检查运行模式：force 模式强制重新生成 CA 证书
    local tls_mode="${TLS_MODE:-rotate}"
    
    # 获取归档目录配置（证书存在的唯一依据）
    local local_ca_cert_dir=$(get_five_layer_config "$combo" "LOCAL_CA_CERT_DIR" 2>/dev/null || echo "")
    local archived_cert_path=""
    local archived_key_path=""
    
    if [[ -n "$local_ca_cert_dir" ]]; then
        # 展开路径中的 ~ 符号
        local_ca_cert_dir="${local_ca_cert_dir/#\~/$HOME}"
        archived_cert_path="$local_ca_cert_dir/ca.crt"
        archived_key_path="$local_ca_cert_dir/ca.key"
    fi
    
    # 以归档目录为唯一依据检查证书是否存在
    local cert_exists=false
    if [[ -n "$archived_cert_path" && -f "$archived_cert_path" && -f "$archived_key_path" ]]; then
        cert_exists=true
        log_info "归档目录中存在CA证书: $archived_cert_path"
        
        # 如果归档目录存在证书，复制到临时目录使用
        cp "$archived_cert_path" "$cert_path"
        cp "$archived_key_path" "$key_path"
        chmod 644 "$cert_path"
        chmod 600 "$key_path"
        log_info "CA证书已从归档目录复制到临时目录: $cert_path"
    fi
    
    # 检查是否需要重新生成（force 模式或归档目录不存在）
    if [[ "$cert_exists" == "true" ]]; then
        if [[ "$tls_mode" == "force" ]]; then
            log_warn "强制更新模式：CA 将被重新生成，所有共用此 Harbor 的集群（如 C2）必须重新运行 CA 分发，否则 nerdctl push/pull 将因 TLS 证书不匹配而失败"
            log_info "强制更新模式：删除已存在的CA证书并重新生成"
            rm -f "$cert_path" "$key_path"
            if [[ -n "$archived_cert_path" ]]; then
                rm -f "$archived_cert_path" "$archived_key_path"
            fi
            log_info "已删除旧CA证书"
            cert_exists=false  # 标记为不存在，后续会重新生成
        else
            log_info "CA证书已存在（归档目录），跳过生成: $archived_cert_path"
            log_info "提示：如需强制重新生成，请使用 force 模式 (TLS_MODE=force)"
            return 0
        fi
    fi

    # 如果归档目录不存在证书，需要生成新的
    if [[ "$cert_exists" == "false" ]]; then
        # 提取CA配置
        local config=$(get_ca_config "$combo")
        IFS='|' read -r cn days key_size <<< "$config"
        
        # 根据模式输出不同的日志信息
        if [[ "$tls_mode" == "force" ]]; then
            log_info "强制更新模式：生成新CA证书"
        elif [[ "$tls_mode" == "init" ]]; then
            log_info "初始化模式：生成新CA证书"
        else
            log_info "轮换模式：归档目录中CA证书不存在，生成新CA证书"
        fi
        
        # 生成CA私钥
        log_info "生成CA私钥: $key_path"
        openssl genrsa -out "$key_path" "$key_size"
        
        # 生成CA证书
        log_info "生成CA证书: $cert_path"
        openssl req -new -x509 -key "$key_path" -out "$cert_path" -days "$days" -subj "/CN=$cn"
        
        # 设置权限
        chmod 600 "$key_path"
        chmod 644 "$cert_path"
        
        log_success "CA证书生成完成: $cert_path"
        
        # 生成后立即归档到归档目录（如果配置了归档目录）
        if [[ -n "$local_ca_cert_dir" ]]; then
            mkdir -p "$local_ca_cert_dir"
            cp "$cert_path" "$archived_cert_path"
            cp "$key_path" "$archived_key_path"
            chmod 644 "$archived_cert_path"
            chmod 600 "$archived_key_path"
            log_success "CA证书已归档到: $archived_cert_path"
        fi
    fi
}

# 生成服务器证书
generate_server_certificate() {
    local combo="$1"
    # 按前三层（SERVICE_SERVERENVSERVERNODE）标识
    local server_prefix=$(echo "$combo" | sed 's/_[KDN][0-9]*$//')
    local output_dir="${2:-/tmp/${server_prefix}-server-certs}"
    
    log_info "生成服务器证书..."
    
    # 创建输出目录
    mkdir -p "$output_dir"
    
    # 提取服务器配置
    local config=$(get_server_config "$combo")
    IFS='|' read -r cn days key_size dns_list ip_list <<< "$config"
    
    # 设置输出文件路径
    local cert_path="$output_dir/server.crt"
    local key_path="$output_dir/server.key"
    
    # 检查运行模式：force 模式明确删除已存在的服务器证书
    local tls_mode="${TLS_MODE:-rotate}"
    if [[ -f "$cert_path" || -f "$key_path" ]]; then
        if [[ "$tls_mode" == "force" ]]; then
            log_info "强制更新模式：删除已存在的服务器证书并重新生成"
            rm -f "$cert_path" "$key_path"
            log_info "已删除旧服务器证书: $cert_path 和 $key_path"
        else
            log_info "将覆盖已存在的服务器证书: $cert_path"
        fi
    fi
    
    # 根据模式输出不同的日志信息
    if [[ "$tls_mode" == "force" ]]; then
        log_info "强制更新模式：生成新服务器证书"
    else
        log_info "证书轮换模式：生成新服务器证书"
    fi
    
    # 使用主CA证书（按前三层前缀定位）
    local ca_cert_path="/tmp/${server_prefix}-ca-certs/ca.crt"
    local ca_key_path="/tmp/${server_prefix}-ca-certs/ca.key"
    
    # 检查CA证书是否存在
    if [[ ! -f "$ca_cert_path" || ! -f "$ca_key_path" ]]; then
        log_error "主CA证书不存在: $ca_cert_path 或 $ca_key_path"
        log_error "请先生成主CA证书: $server_prefix"
        return 1
    fi
    
    log_info "使用主CA证书: $ca_cert_path"
    
    # 生成服务器私钥
    log_info "生成服务器私钥: $key_path"
    openssl genrsa -out "$key_path" "$key_size"
    
    # 创建服务器证书配置文件
    local config_path="$output_dir/server.conf"
    log_info "创建服务器证书配置文件: $config_path"
    cat > "$config_path" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no
default_bits = $key_size
default_md = sha256

[req_distinguished_name]
C = CN
ST = Beijing
L = Beijing
O = SunMoonAI
OU = IT
CN = $cn

[v3_req]
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
subjectAltName = @alt_names

[alt_names]
DNS.1 = $cn
EOF

    # 添加DNS和IP列表到配置文件
    if [[ -n "$dns_list" ]]; then
        local dns_count=2
        # DNS列表是空格分隔的，使用空格作为分隔符
        IFS=' ' read -ra DNS_ARRAY <<< "$dns_list"
        for dns in "${DNS_ARRAY[@]}"; do
            # 去除可能的空格
            dns=$(echo "$dns" | xargs)
            # 跳过空值和与CN重复的值（DNS.1 已经设置为 CN，避免重复）
            if [[ -n "$dns" && "$dns" != "$cn" ]]; then
                echo "DNS.$dns_count = $dns" >> "$config_path"
                ((dns_count++))
            fi
        done
    fi
    
    if [[ -n "$ip_list" ]]; then
        local ip_count=1
        IFS=' ' read -ra IP_ARRAY <<< "$ip_list"
        for ip in "${IP_ARRAY[@]}"; do
            echo "IP.$ip_count = $ip" >> "$config_path"
            ((ip_count++))
        done
    fi
    
    # 生成证书签名请求
    local csr_path="$output_dir/server.csr"
    log_info "生成服务器证书签名请求: $csr_path"
    openssl req -new -key "$key_path" -out "$csr_path" -config "$config_path"
    
    # 创建用于签名的扩展配置文件（包含 authorityKeyIdentifier）
    # 注意：authorityKeyIdentifier 不能在 CSR 中，只能在签名时添加
    local ext_config_path="$output_dir/server-ext.conf"
    log_info "创建证书扩展配置文件: $ext_config_path"
    cat > "$ext_config_path" << EOF
[v3_req]
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
subjectAltName = @alt_names

[alt_names]
DNS.1 = $cn
EOF

    # 添加DNS和IP列表到扩展配置文件
    if [[ -n "$dns_list" ]]; then
        local dns_count=2
        IFS=' ' read -ra DNS_ARRAY <<< "$dns_list"
        for dns in "${DNS_ARRAY[@]}"; do
            dns=$(echo "$dns" | xargs)
            # 跳过空值和与CN重复的值（DNS.1 已经设置为 CN，避免重复）
            if [[ -n "$dns" && "$dns" != "$cn" ]]; then
                echo "DNS.$dns_count = $dns" >> "$ext_config_path"
                ((dns_count++))
            fi
        done
    fi
    
    if [[ -n "$ip_list" ]]; then
        local ip_count=1
        IFS=' ' read -ra IP_ARRAY <<< "$ip_list"
        for ip in "${IP_ARRAY[@]}"; do
            ip=$(echo "$ip" | xargs)
            if [[ -n "$ip" ]]; then
                echo "IP.$ip_count = $ip" >> "$ext_config_path"
                ((ip_count++))
            fi
        done
    fi
    
    # 使用CA签名服务器证书（使用扩展配置文件，包含 authorityKeyIdentifier）
    log_info "使用CA签名服务器证书: $cert_path"
    openssl x509 -req -in "$csr_path" -CA "$ca_cert_path" -CAkey "$ca_key_path" -CAcreateserial -out "$cert_path" -days "$days" -extensions v3_req -extfile "$ext_config_path"
    
    # 设置权限
    chmod 600 "$key_path"
    chmod 644 "$cert_path"
    
    # 清理CSR文件
    rm -f "$csr_path"
    
    log_success "服务器证书生成完成: $cert_path"
}


# 生成所有证书（便捷函数）
generate_all_certificates() {
    local combo="$1"                 # 组合代码
    local output_dir="$2"            # 输出目录
    
    log_info "开始生成所有证书: $combo"
    
    # 创建输出目录
    mkdir -p "$output_dir"
    
    # 1. 生成CA证书
    log_info "=== 步骤 1: 生成CA证书 ==="
    if ! generate_ca_certificate "$combo" "$output_dir"; then
        log_error "CA证书生成失败"
        return 1
    fi
    
    # 2. 生成服务器证书
    log_info "=== 步骤 2: 生成服务器证书 ==="
    if ! generate_server_certificate "$combo" "$output_dir"; then
        log_error "服务器证书生成失败"
        return 1
    fi
    
    
    # 3. 自动验证证书链一致性
    log_info "=== 步骤 3: 验证证书链一致性 ==="
    if ! verify_cert_chain_auto "$output_dir/server.crt" "$output_dir/ca.crt"; then
        log_error "证书链验证失败，重新生成证书..."
        # 删除当前证书，重新生成
        rm -f "$output_dir/server.crt" "$output_dir/server.key"
        if ! generate_server_certificate "$combo" "$output_dir"; then
            log_error "重新生成服务器证书失败"
            return 1
        fi
        # 再次验证
        if ! verify_cert_chain_auto "$output_dir/server.crt" "$output_dir/ca.crt"; then
            log_success "重新生成后证书链验证通过"
        else
            log_error "重新生成后证书链仍然验证失败"
            return 1
        fi
    else
        log_success "证书链验证通过"
    fi
    
    log_success "所有证书生成完成！"
    log_info "证书文件位置: $output_dir"
    log_info "├── ca.crt          # CA证书"
    log_info "├── ca.key          # CA私钥"
    log_info "├── server.crt      # 服务器证书"
    log_info "└── server.key      # 服务器私钥"
}


# =============================================================================
# 证书分发函数
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
        local server_ca_cert_dir=$(get_five_layer_config "$combo" "SERVER_CA_CERT_DIR")
        local server_server_cert_dir=$(get_five_layer_config "$combo" "SERVER_SERVER_CERT_DIR")
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
        local server_ca_cert_dir=$(get_five_layer_config "$service_type" "$server_env" "$server_node" "$client_env" "$client_node" "SERVER_CA_CERT_DIR")
        local server_server_cert_dir=$(get_five_layer_config "$service_type" "$server_env" "$server_node" "$client_env" "$client_node" "SERVER_SERVER_CERT_DIR")
    fi
    
    log_info "分发证书到服务端..."
    
    # 使用临时证书文件路径
    local temp_ca_cert_path="/tmp/${combo}-ca-certs/ca.crt"
    local temp_ca_key_path="/tmp/${combo}-ca-certs/ca.key"
    local temp_server_cert_path="/tmp/${combo}-server-certs/server.crt"
    local temp_server_key_path="/tmp/${combo}-server-certs/server.key"
    
    # 创建远程目录
    local create_dir_cmd="sudo mkdir -p $server_ca_cert_dir $server_server_cert_dir && sudo chown $server_username:$server_username $server_ca_cert_dir $server_server_cert_dir"
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
    local move_files_cmd="sudo mv /tmp/ca.crt $server_ca_cert_dir/ && sudo mv /tmp/ca.key $server_ca_cert_dir/ && sudo mv /tmp/server.crt $server_server_cert_dir/ && sudo mv /tmp/server.key $server_server_cert_dir/ && sudo chown $server_username:$server_username $server_ca_cert_dir/* $server_server_cert_dir/* && sudo chmod 600 $server_ca_cert_dir/*.key $server_server_cert_dir/*.key && sudo chmod 644 $server_ca_cert_dir/*.crt $server_server_cert_dir/*.crt"
    if ! execute_ssh_command_with_retry "$server_host" "$server_port" "$server_username" "$server_ssh_key" "$move_files_cmd"; then
        log_warn "设置远程文件权限失败"
    fi
    
    log_success "证书分发到服务端完成"
}

# 校验本地归档 CA 与 K8s secret 中的 ca.crt 是否一致
# 返回 0=一致或无法校验（跳过）, 1=不一致（应中止分发）
validate_ca_vs_k8s() {
    local combo="$1"
    local local_ca_path="$2"

    local secret_name secret_namespace secret_key
    secret_name=$(get_five_layer_config "$combo" "CA_VALIDATE_SECRET_NAME" 2>/dev/null || echo "")
    [[ -z "$secret_name" ]] && return 0  # 未配置校验，跳过

    secret_namespace=$(get_five_layer_config "$combo" "CA_VALIDATE_SECRET_NAMESPACE" 2>/dev/null || echo "")
    secret_key=$(get_five_layer_config "$combo" "CA_VALIDATE_SECRET_KEY" 2>/dev/null || echo "ca.crt")

    local server_prefix
    server_prefix=$(echo "$combo" | sed 's/_[KDN][0-9]*$//')
    local server_host server_port server_username server_ssh_key
    server_host=$(get_five_layer_config "${server_prefix}_K1" "SERVER_HOST" 2>/dev/null || get_five_layer_config "$combo" "SERVER_HOST" 2>/dev/null || echo "")
    [[ -z "$server_host" || "$server_host" == "127.0.0.1" ]] && return 0  # KIND 等本地 combo 跳过

    server_port=$(get_five_layer_config "${server_prefix}_K1" "SERVER_PORT" 2>/dev/null || echo "22")
    server_username=$(get_five_layer_config "${server_prefix}_K1" "SERVER_USERNAME" 2>/dev/null || echo "root")
    server_ssh_key=$(get_five_layer_config "${server_prefix}_K1" "SERVER_SSH_KEY" 2>/dev/null || echo "")
    server_ssh_key="${server_ssh_key/#\~/$HOME}"

    log_info "校验本地归档 CA 与 K8s secret ${secret_namespace}/${secret_name} 一致性..."

    local k8s_ca_fp
    k8s_ca_fp=$(ssh -i "$server_ssh_key" -p "$server_port" -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
        "${server_username}@${server_host}" \
        "kubectl get secret ${secret_name} -n ${secret_namespace} -o jsonpath='{.data.${secret_key}}' 2>/dev/null | base64 -d | openssl x509 -noout -fingerprint -sha256 2>/dev/null" 2>/dev/null || echo "")

    [[ -z "$k8s_ca_fp" ]] && { log_warn "无法从 K8s 获取 CA 指纹，跳过一致性校验"; return 0; }

    local local_ca_fp
    local_ca_fp=$(openssl x509 -noout -fingerprint -sha256 -in "$local_ca_path" 2>/dev/null || echo "")
    [[ -z "$local_ca_fp" ]] && { log_warn "无法读取本地归档 CA，跳过一致性校验"; return 0; }

    if [[ "$local_ca_fp" != "$k8s_ca_fp" ]]; then
        log_error "CA 不一致！本地归档与 K8s secret 中的 CA 指纹不同："
        log_error "  本地归档: $local_ca_fp"
        log_error "  K8s secret: $k8s_ca_fp"
        log_error "请先运行 sync-ca-from-k8s.sh 同步本地归档，再重新执行 Step12 分发"
        return 1
    fi

    log_info "CA 一致性校验通过：本地归档与 K8s secret 指纹一致"
    return 0
}

# 分发CA证书到客户端
distribute_ca_certificate_to_client() {
    # 仅支持 1 参：distribute_ca_certificate_to_client <combo>
    local combo="$1"
    
    # 根据客户端环境类型自动选择证书路径
    # 组合格式: SERVICE_ENV_NODE_ENV_NODE (如: TRAEFIK_K1_K1 或 TRAEFIK_KIND_KIND)
    local client_env=""
    if [[ "$combo" =~ _KIND$ ]]; then
        # KIND 组合（例如 TRAEFIK_KIND_KIND）
        client_env="KIND"
    else
        client_env=$(echo "$combo" | sed 's/.*_\([KDN][0-9]*\)$/\1/' | sed 's/[0-9]*$//')
    fi
    local client_cert_path=""
    
    case "$client_env" in
        "K"|"KIND")
            # K8s环境使用containerd证书路径（KIND 也属于 K8s 环境）
            client_cert_path=$(get_five_layer_config "$combo" "CLIENT_CONTAINERD_PATH")
            ;;
        "D"|"N")
            # Docker/nerdctl环境使用Docker证书路径
            client_cert_path=$(get_five_layer_config "$combo" "CLIENT_DOCKER_PATH")
            ;;
        *)
            log_error "不支持的客户端环境类型: $client_env (组合: $combo)"
            return 1
            ;;
    esac
    
    if [[ -z "$client_cert_path" ]]; then
        log_error "未配置客户端证书路径: $combo"
        return 1
    fi
    
    # 确定服务器端CA证书路径（按前三层前缀定位）
    # 例如：TRAEFIK_K1_K1、TRAEFIK_K1_D1、TRAEFIK_K1_N2 -> server_prefix=TRAEFIK_K1
    #       TRAEFIK_KIND_KIND -> server_prefix=TRAEFIK
    local server_prefix=""
    if [[ "$combo" =~ _KIND_KIND$ ]]; then
        server_prefix=$(echo "$combo" | sed 's/_KIND_KIND$//')
    else
        server_prefix=$(echo "$combo" | sed 's/_[KDN][0-9]*$//')
    fi
    local temp_ca_cert_path="/tmp/${server_prefix}-ca-certs/ca.crt"
    
    # 检查服务器端CA证书是否存在；若不存在，尝试自动生成（按前三层前缀定位）
    if [[ ! -f "$temp_ca_cert_path" ]]; then
        log_warn "服务器端CA证书不存在: $temp_ca_cert_path；尝试自动生成..."
        if ! generate_ca_certificate "$combo"; then
            log_error "自动生成CA证书失败，请先生成服务端前三层($server_prefix)的CA"
            return 1
        fi
        if [[ ! -f "$temp_ca_cert_path" ]]; then
            log_error "自动生成后仍未找到CA证书: $temp_ca_cert_path"
            return 1
        fi
    fi
    
    log_info "使用服务器端前缀 $server_prefix 的CA证书: $temp_ca_cert_path"

    # 分发前校验本地归档 CA 与 K8s 部署的 CA 一致（防止 CA 分叉导致客户端 TLS 失败）
    if ! validate_ca_vs_k8s "$combo" "$temp_ca_cert_path"; then
        return 1
    fi

    # 检查是否是K8s多节点配置
    local client_nodes=$(get_five_layer_config "$combo" "CLIENT_NODES")
    
    # 如果未找到配置且使用了集群配置映射，尝试直接读取集群特定配置
    if [[ -z "$client_nodes" && -n "${CLUSTER:-}" ]]; then
        local cluster_config="${CLUSTER}_${combo}_CLIENT_NODES"
        if [[ -n "${!cluster_config:-}" ]]; then
            client_nodes="${!cluster_config}"
        fi
    fi
    
    if [[ -n "$client_nodes" && "$client_env" == "K" ]]; then
        # K8s多节点配置：循环分发到所有节点
        log_info "检测到K8s多节点配置，开始分发到所有节点..."
        
        # 解析节点配置
        IFS=',' read -ra NODE_ARRAY <<< "$client_nodes"
        
        # 读取其他客户端节点配置（支持集群配置映射回退）
        local client_node_hosts=$(get_five_layer_config "$combo" "CLIENT_NODE_HOSTS")
        if [[ -z "$client_node_hosts" && -n "${CLUSTER:-}" ]]; then
            local cluster_config="${CLUSTER}_${combo}_CLIENT_NODE_HOSTS"
            client_node_hosts="${!cluster_config:-}"
        fi
        
        local client_node_ports=$(get_five_layer_config "$combo" "CLIENT_NODE_PORTS")
        if [[ -z "$client_node_ports" && -n "${CLUSTER:-}" ]]; then
            local cluster_config="${CLUSTER}_${combo}_CLIENT_NODE_PORTS"
            client_node_ports="${!cluster_config:-}"
        fi
        
        local client_node_usernames=$(get_five_layer_config "$combo" "CLIENT_NODE_USERNAMES")
        if [[ -z "$client_node_usernames" && -n "${CLUSTER:-}" ]]; then
            local cluster_config="${CLUSTER}_${combo}_CLIENT_NODE_USERNAMES"
            client_node_usernames="${!cluster_config:-}"
        fi
        
        local client_node_ssh_keys=$(get_five_layer_config "$combo" "CLIENT_NODE_SSH_KEYS")
        if [[ -z "$client_node_ssh_keys" && -n "${CLUSTER:-}" ]]; then
            local cluster_config="${CLUSTER}_${combo}_CLIENT_NODE_SSH_KEYS"
            client_node_ssh_keys="${!cluster_config:-}"
        fi
        
        IFS=',' read -ra HOST_ARRAY <<< "$client_node_hosts"
        IFS=',' read -ra PORT_ARRAY <<< "$client_node_ports"
        IFS=',' read -ra USERNAME_ARRAY <<< "$client_node_usernames"
        IFS=',' read -ra SSH_KEY_ARRAY <<< "$client_node_ssh_keys"
        
        # 循环处理各个节点
        for i in "${!NODE_ARRAY[@]}"; do
            local node_name="${NODE_ARRAY[$i]}"
            
            # 检查数组边界
            if [[ $i -ge ${#HOST_ARRAY[@]} ]]; then
                log_warn "节点 $node_name 缺少主机配置，跳过"
                continue
            fi
            
            local node_host="${HOST_ARRAY[$i]}"
            local node_port="${PORT_ARRAY[$i]:-22}"
            local node_username="${USERNAME_ARRAY[$i]:-root}"
            local node_ssh_key="${SSH_KEY_ARRAY[$i]}"
            
            log_info "分发CA证书到节点: $node_name ($node_host)"
            
            # 创建containerd证书目录
            local create_dir_cmd="sudo mkdir -p $client_cert_path && sudo chown $node_username:$node_username $client_cert_path"
            if ! execute_ssh_command_with_retry "$node_host" "$node_port" "$node_username" "$node_ssh_key" "$create_dir_cmd"; then
                log_error "节点 $node_name 创建containerd证书目录失败"
                continue
            fi
            
            # 传输CA证书
            if ! transfer_file_with_retry "$temp_ca_cert_path" "$node_host" "$node_port" "$node_username" "$node_ssh_key" "/tmp/ca.crt"; then
                log_error "节点 $node_name CA证书传输失败"
                continue
            fi
            
            # 移动CA证书到containerd路径
            local client_ca_path="${client_cert_path}/ca.crt"
            local move_ca_cmd="sudo mv /tmp/ca.crt $client_ca_path && sudo chown $node_username:$node_username $client_ca_path && sudo chmod 644 $client_ca_path"
            if ! execute_ssh_command_with_retry "$node_host" "$node_port" "$node_username" "$node_ssh_key" "$move_ca_cmd"; then
                log_error "节点 $node_name CA证书移动失败"
                continue
            fi
            
            log_success "节点 $node_name CA证书分发完成"

            # 同步 CA 到系统信任库，便于 nerdctl / curl 使用系统 CA 验证 Harbor TLS
            # 复用 Docker 客户端的命名规则：harbor-<registry>-ca.crt
            local harbor_registry
            harbor_registry=$(echo "$client_cert_path" | sed 's|.*certs\.d/\([^/]*\).*|\1|')
            local system_ca_name="harbor-${harbor_registry//[^a-zA-Z0-9]/-}-ca.crt"
            local system_ca_path="/usr/local/share/ca-certificates/$system_ca_name"
            # update-ca-certificates 在证书文件名不变时可能报告 "0 added"（内容替换不计入数量）
            # 因此追加一道验证：若 CA 指纹不在系统 bundle 中，则直接追加，确保 nerdctl 可验证 Harbor TLS
            local import_system_ca_cmd="sudo cp $client_ca_path $system_ca_path && sudo chmod 644 $system_ca_path && sudo update-ca-certificates && ( sudo openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt $system_ca_path >/dev/null 2>&1 || sudo sh -c 'cat $system_ca_path >> /etc/ssl/certs/ca-certificates.crt' )"
            if ! execute_ssh_command_with_retry "$node_host" "$node_port" "$node_username" "$node_ssh_key" "$import_system_ca_cmd"; then
                log_error "节点 $node_name 导入系统 CA 证书失败，nerdctl 将无法验证 Harbor TLS"
                continue
            else
                log_success "节点 $node_name 系统 CA 已更新: $system_ca_path"
            fi
        done
        
        log_success "CA证书分发到所有K8s客户端节点完成"
        return 0
    fi
    
    # 单客户端配置（Docker/nerdctl 或未配置多节点的 K8s）
    local client_host=$(get_five_layer_config "$combo" "CLIENT_HOST")
    local client_port=$(get_five_layer_config "$combo" "CLIENT_PORT")
    local client_username=$(get_five_layer_config "$combo" "CLIENT_USERNAME")
    local client_ssh_key=$(get_five_layer_config "$combo" "CLIENT_SSH_KEY")
    
    if [[ -z "$client_host" ]]; then
        log_error "未配置客户端主机: $combo"
        return 1
    fi
    
    local client_cert_dir="$client_cert_path"
    local client_ca_path="${client_cert_path}/ca.crt"

    log_info "分发CA证书到客户端..."
    
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
    
    # Docker 客户端需要重启 Docker 服务才能加载新的 CA 证书
    # containerd 和 nerdctl 会在每次拉取镜像时动态读取证书，不需要重启
    if [[ "$client_env" == "D" ]]; then
        log_info "Docker 客户端需要导入系统 CA 并重启 Docker 服务以加载新的 CA 证书..."
        
        # 从 client_cert_path 提取 Harbor 域名（例如：/etc/docker/certs.d/harbor.sunmoonai.com:30443 -> harbor.sunmoonai.com:30443）
        # 提取 certs.d/ 后面的部分（包含端口）
        local harbor_registry=$(echo "$client_cert_path" | sed 's|.*certs\.d/\([^/]*\).*|\1|')
        # 将域名中的特殊字符替换为连字符，生成安全的文件名
        local system_ca_name="harbor-${harbor_registry//[^a-zA-Z0-9]/-}-ca.crt"
        local system_ca_path="/usr/local/share/ca-certificates/${system_ca_name}"
        
        # 1. 导入 CA 证书到系统 CA 存储
        log_info "导入 CA 证书到系统 CA 存储: $system_ca_path"
        local import_system_ca_cmd="sudo cp $client_ca_path $system_ca_path && sudo chmod 644 $system_ca_path && sudo update-ca-certificates && ( sudo openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt $system_ca_path >/dev/null 2>&1 || sudo sh -c 'cat $system_ca_path >> /etc/ssl/certs/ca-certificates.crt' )"
        if ! execute_ssh_command_with_retry "$client_host" "$client_port" "$client_username" "$client_ssh_key" "$import_system_ca_cmd"; then
            log_error "导入系统 CA 失败"
            return 1
        else
            log_success "系统 CA 导入成功"
        fi
        
        # 2. 重启 Docker 服务
        log_info "重启 Docker 服务..."
        local restart_docker_cmd="sudo systemctl restart docker"
        if execute_ssh_command_with_retry "$client_host" "$client_port" "$client_username" "$client_ssh_key" "$restart_docker_cmd"; then
            log_success "Docker 服务重启成功"
        else
            log_warn "Docker 服务重启失败，请手动重启: sudo systemctl restart docker"
        fi
    fi
    
    log_success "CA证书分发到客户端完成"
}


# =============================================================================
# 证书验证函数
# =============================================================================

# 验证证书
verify_certificate() {
    local cert_path="$1"
    local key_path="${2:-}"
    
    if [[ ! -f "$cert_path" ]]; then
        log_error "证书文件不存在: $cert_path"
        return 1
    fi
    
    # 验证证书格式
    if ! openssl x509 -in "$cert_path" -text -noout >/dev/null 2>&1; then
        log_error "证书格式无效: $cert_path"
        return 1
    fi
    
    # 验证私钥（如果提供）
    if [[ -n "$key_path" ]] && [[ -f "$key_path" ]]; then
        if ! openssl rsa -in "$key_path" -check >/dev/null 2>&1; then
            log_error "私钥格式无效: $key_path"
            return 1
        fi
    fi
    
    log_success "证书验证通过: $cert_path"
    return 0
}

# =============================================================================
# 客户端证书分发和Secret管理
# =============================================================================


# 创建客户端认证Secret
create_client_auth_secret() {
    local combo="$1"
    local client_host=$(get_five_layer_config "$combo" "CLIENT_HOST")
    local client_port=$(get_five_layer_config "$combo" "CLIENT_PORT")
    local client_username=$(get_five_layer_config "$combo" "CLIENT_USERNAME")
    local client_ssh_key=$(get_five_layer_config "$combo" "CLIENT_SSH_KEY")
    local client_namespace=$(get_five_layer_config "$combo" "CLIENT_NAMESPACE")
    local client_secret_name=$(get_five_layer_config "$combo" "CLIENT_SECRET_NAME")
    local client_secret_type=$(get_five_layer_config "$combo" "CLIENT_SECRET_TYPE")

    log_info "创建客户端认证Secret..."

    # 获取认证信息（从配置或环境变量）
    local harbor_username=$(get_five_layer_config "$combo" "CLIENT_HARBOR_USERNAME")
    local harbor_password=$(get_five_layer_config "$combo" "CLIENT_HARBOR_PASSWORD")
    local harbor_token=$(get_five_layer_config "$combo" "CLIENT_HARBOR_TOKEN")
    local harbor_robot_name=$(get_five_layer_config "$combo" "CLIENT_HARBOR_ROBOT_NAME")
    
    # 设置默认值
    harbor_username=${harbor_username:-"admin"}
    harbor_password=${harbor_password:-"Harbor12345"}
    harbor_robot_name=${harbor_robot_name:-"robot$combo"}

    # 创建认证Secret YAML
    local secret_yaml="/tmp/${client_secret_name}.yaml"
    
    # 判断使用哪种认证方式
    if [[ -n "$harbor_token" ]]; then
        # 使用机器人Token认证
        log_info "使用机器人Token认证"
        local b64_token=$(echo -n "$harbor_token" | base64 -w 0)
        local b64_robot_name=$(echo -n "$harbor_robot_name" | base64 -w 0)
        
        cat > "$secret_yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${client_secret_name}
  namespace: ${client_namespace}
type: ${client_secret_type}
data:
  token: ${b64_token}
  robot_name: ${b64_robot_name}
EOF
    else
        # 使用用户名密码认证
        log_info "使用用户名密码认证"
        local b64_username=$(echo -n "$harbor_username" | base64 -w 0)
        local b64_password=$(echo -n "$harbor_password" | base64 -w 0)
        
        cat > "$secret_yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${client_secret_name}
  namespace: ${client_namespace}
type: ${client_secret_type}
data:
  username: ${b64_username}
  password: ${b64_password}
EOF
    fi

    # 传输Secret YAML到远程
    if ! transfer_file_with_retry "$secret_yaml" "$client_host" "$client_port" "$client_username" "$client_ssh_key" "/tmp/${client_secret_name}.yaml"; then
        log_error "传输Secret YAML失败"
        return 1
    fi

    # 不清理本地临时文件，留给归档逻辑处理
    log_success "客户端认证Secret创建完成"
}

# 部署客户端Secret到K8s集群
deploy_client_secret_to_k8s() {
    local combo="$1"
    local client_host=$(get_five_layer_config "$combo" "CLIENT_HOST")
    local client_port=$(get_five_layer_config "$combo" "CLIENT_PORT")
    local client_username=$(get_five_layer_config "$combo" "CLIENT_USERNAME")
    local client_ssh_key=$(get_five_layer_config "$combo" "CLIENT_SSH_KEY")
    local client_secret_name=$(get_five_layer_config "$combo" "CLIENT_SECRET_NAME")

    log_info "部署客户端Secret到K8s集群..."

    # 应用Secret
    local apply_cmd="kubectl apply -f /tmp/${client_secret_name}.yaml"
    if ! execute_ssh_command_with_retry "$client_host" "$client_port" "$client_username" "$client_ssh_key" "$apply_cmd"; then
        log_error "部署客户端Secret失败"
        return 1
    fi

    # 清理远程临时文件
    local cleanup_cmd="rm -f /tmp/${client_secret_name}.yaml"
    execute_ssh_command_with_retry "$client_host" "$client_port" "$client_username" "$client_ssh_key" "$cleanup_cmd" || true

    log_success "客户端Secret部署完成"
}


# 渲染TLS Secret YAML
render_tls_secret_yaml() {
    local combo="$1"
    local secret_name="$2"
    local secret_namespace="$3"
    local local_secret_path="$4"
    
    # 使用 prepare_tls_secret_data 准备的数据目录
    local temp_secret_dir="/tmp/${secret_name}-data"
    local server_crt="$temp_secret_dir/tls.crt"
    local server_key="$temp_secret_dir/tls.key"
    local ca_crt="$temp_secret_dir/ca.crt"

    # base64 编码（单行）
    local b64_server_crt="" b64_server_key="" b64_ca_crt=""
    if [[ -f "$server_crt" ]]; then b64_server_crt=$(base64 -w 0 "$server_crt"); fi
    if [[ -f "$server_key" ]]; then b64_server_key=$(base64 -w 0 "$server_key"); fi
    if [[ -f "$ca_crt" ]]; then b64_ca_crt=$(base64 -w 0 "$ca_crt"); fi

    # 渲染TLS Secret YAML
    {
        echo "apiVersion: v1"
        echo "kind: Secret"
        echo "metadata:"
        echo "  name: ${secret_name}"
        echo "  namespace: ${secret_namespace}"
        echo "type: kubernetes.io/tls"
        echo "data:"
        if [[ -n "$b64_server_crt" ]]; then
            echo "  tls.crt: ${b64_server_crt}"
        fi
        if [[ -n "$b64_server_key" ]]; then
            echo "  tls.key: ${b64_server_key}"
        fi
        if [[ -n "$b64_ca_crt" ]]; then
            echo "  ca.crt: ${b64_ca_crt}"
        fi
    } > "$local_secret_path"

    # TLS Secret 包含私钥，设置安全权限
    chmod 600 "$local_secret_path"
    log_success "TLS Secret YAML已生成: $local_secret_path"
}

# 渲染Docker认证Secret YAML
render_docker_auth_secret_yaml() {
    local combo="$1"
    local secret_name="$2"
    local secret_namespace="$3"
    local local_secret_path="$4"
    
    # 从准备好的数据目录读取
    local temp_secret_dir="/tmp/${secret_name}-data"
    local docker_config="$temp_secret_dir/.dockerconfigjson"
    
    if [[ ! -f "$docker_config" ]]; then
        log_error "Docker认证配置文件不存在: $docker_config"
        return 1
    fi
    
    local b64_docker_config=$(base64 -w 0 "$docker_config")
    
    # 渲染Docker认证Secret YAML
    {
        echo "apiVersion: v1"
        echo "kind: Secret"
        echo "metadata:"
        echo "  name: ${secret_name}"
        echo "  namespace: ${secret_namespace}"
        echo "type: kubernetes.io/dockerconfigjson"
        echo "data:"
        echo "  .dockerconfigjson: ${b64_docker_config}"
    } > "$local_secret_path"

    log_success "Docker认证Secret YAML已生成: $local_secret_path"
}

# 渲染通用Secret YAML
render_opaque_secret_yaml() {
    local combo="$1"
    local secret_name="$2"
    local secret_namespace="$3"
    local local_secret_path="$4"
    
    # 从准备好的数据目录读取
    local temp_secret_dir="/tmp/${secret_name}-data"
    
    # 检查数据目录是否存在
    if [[ ! -d "$temp_secret_dir" ]]; then
        log_error "数据目录不存在: $temp_secret_dir"
        return 1
    fi
    
    # 渲染通用Secret YAML
    {
        echo "apiVersion: v1"
        echo "kind: Secret"
        echo "metadata:"
        echo "  name: ${secret_name}"
        echo "  namespace: ${secret_namespace}"
        echo "type: Opaque"
        echo "data:"
        
        # 遍历数据目录中的所有文件
        for file in "$temp_secret_dir"/*; do
            if [[ -f "$file" ]]; then
                local key_name=$(basename "$file")
                local b64_content=$(base64 -w 0 "$file")
                echo "  ${key_name}: ${b64_content}"
            fi
        done
    } > "$local_secret_path"

    log_success "通用Secret YAML已生成: $local_secret_path"
}
