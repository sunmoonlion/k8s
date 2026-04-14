#!/bin/bash

# =============================================================================
# Secret数据源准备库
# 文件名: secret-data.sh
# 用途: 为不同类型的Secret准备相应的数据源
# =============================================================================

# 准备TLS Secret数据
prepare_tls_secret_data() {
    local combo="$1"
    local secret_name="$2"
    local secret_index="$3"
    
    log_info "准备TLS Secret数据: $secret_name (索引: $secret_index)"
    
    # 获取该Secret索引的数据源配置
    local tls_crt=$(get_five_layer_config "$combo" "SECRET_${secret_index}_TLS_CRT")
    local tls_key=$(get_five_layer_config "$combo" "SECRET_${secret_index}_TLS_KEY")
    
    # 展开路径中的 ~ 符号
    tls_crt="${tls_crt/#\~/$HOME}"
    tls_key="${tls_key/#\~/$HOME}"
    
    # 检查必需的TLS证书配置
    if [[ -z "$tls_crt" || -z "$tls_key" ]]; then
        log_error "TLS Secret需要配置TLS_CRT和TLS_KEY"
        return 1
    fi
    
    # 智能处理证书路径：支持指向目录或文件
    local actual_tls_crt="$tls_crt"
    local actual_tls_key="$tls_key"
    
    # 如果指向目录，从目录中查找证书文件
    if [[ -d "$tls_crt" ]]; then
        log_info "TLS_CRT指向目录，查找证书文件: $tls_crt"
        # 尝试多种可能的证书文件名
        for cert_file in "server.crt" "tls.crt" "cert.crt" "harbor.crt"; do
            if [[ -f "${tls_crt}/${cert_file}" ]]; then
                actual_tls_crt="${tls_crt}/${cert_file}"
                log_info "找到证书文件: $actual_tls_crt"
                break
            fi
        done
    fi
    
    if [[ -d "$tls_key" ]]; then
        log_info "TLS_KEY指向目录，查找私钥文件: $tls_key"
        # 尝试多种可能的私钥文件名
        for key_file in "server.key" "tls.key" "cert.key" "harbor.key"; do
            if [[ -f "${tls_key}/${key_file}" ]]; then
                actual_tls_key="${tls_key}/${key_file}"
                log_info "找到私钥文件: $actual_tls_key"
                break
            fi
        done
    fi
    
    # 最终检查证书文件是否存在
    if [[ ! -f "$actual_tls_crt" || ! -f "$actual_tls_key" ]]; then
        log_error "TLS证书文件不存在: $actual_tls_crt 或 $actual_tls_key"
        return 1
    fi
    
    # 创建临时数据目录
    local temp_secret_dir="/tmp/${secret_name}-data"
    mkdir -p "$temp_secret_dir"
    
    # 复制TLS证书文件到临时目录
    cp "$actual_tls_crt" "$temp_secret_dir/tls.crt"
    cp "$actual_tls_key" "$temp_secret_dir/tls.key"
    log_info "使用TLS证书: $actual_tls_crt"
    
    # 根据配置决定是否包含CA证书
    local include_ca=$(get_five_layer_config "$combo" "SECRET_${secret_index}_INCLUDE_CA")
    local ca_cert_path=$(get_five_layer_config "$combo" "SECRET_${secret_index}_CA_CRT")
    if [[ "$include_ca" == "true" && -f "$ca_cert_path" ]]; then
        cp "$ca_cert_path" "$temp_secret_dir/ca.crt"
        log_info "已包含CA证书: $ca_cert_path"
    fi
    
    log_success "TLS Secret数据准备完成"
    return 0
}

# 准备Docker认证Secret数据
prepare_docker_auth_secret_data() {
    local combo="$1"
    local secret_name="$2"
    local secret_index="$3"
    
    log_info "准备Docker认证Secret数据: $secret_name (索引: $secret_index)"
    
    # 获取该Secret索引的数据源配置
    local docker_config=$(get_five_layer_config "$combo" "SECRET_${secret_index}_DOCKER_CONFIG")
    
    # 如果直接提供了DOCKER_CONFIG，使用它
    if [[ -n "$docker_config" ]]; then
        log_info "使用预配置的Docker认证数据"
        # 创建临时数据目录
        local temp_secret_dir="/tmp/${secret_name}-data"
        mkdir -p "$temp_secret_dir"
        echo "$docker_config" > "$temp_secret_dir/.dockerconfigjson"
        log_success "Docker认证Secret数据准备完成"
        return 0
    fi
    
    # 使用新的DOCKER_*配置方式
    local docker_server=$(get_five_layer_config "$combo" "SECRET_${secret_index}_DOCKER_SERVER")
    local docker_username=$(get_five_layer_config "$combo" "SECRET_${secret_index}_DOCKER_USERNAME")
    local docker_password=$(get_five_layer_config "$combo" "SECRET_${secret_index}_DOCKER_PASSWORD")
    local docker_email=$(get_five_layer_config "$combo" "SECRET_${secret_index}_DOCKER_EMAIL")
    
    # 如果没有配置DOCKER_SERVER，尝试旧的REGISTRY配置
    if [[ -z "$docker_server" ]]; then
        docker_server=$(get_five_layer_config "$combo" "SECRET_${secret_index}_REGISTRY")
    fi
    
    # 默认值
    if [[ -z "$docker_server" ]]; then
        docker_server="harbor.sunmoonai.local"
    fi
    
    # 创建临时数据目录
    local temp_secret_dir="/tmp/${secret_name}-data"
    mkdir -p "$temp_secret_dir"
    
    # 检查必需参数
    if [[ -z "$docker_username" || -z "$docker_password" ]]; then
        log_error "Docker认证需要配置DOCKER_USERNAME和DOCKER_PASSWORD"
        return 1
    fi
    
    # 生成Docker认证数据
    local auth_data=""
    if [[ -n "$docker_email" ]]; then
        auth_data="{\"auths\":{\"$docker_server\":{\"username\":\"$docker_username\",\"password\":\"$docker_password\",\"email\":\"$docker_email\",\"auth\":\"$(echo -n "$docker_username:$docker_password" | base64 -w 0)\"}}}"
    else
        auth_data="{\"auths\":{\"$docker_server\":{\"username\":\"$docker_username\",\"password\":\"$docker_password\",\"auth\":\"$(echo -n "$docker_username:$docker_password" | base64 -w 0)\"}}}"
    fi
    
    log_info "使用Docker认证: $docker_username@$docker_server"
    
    echo "$auth_data" > "$temp_secret_dir/.dockerconfigjson"
    
    log_success "Docker认证Secret数据准备完成"
    return 0
}

# 准备通用Secret数据
prepare_opaque_secret_data() {
    local combo="$1"
    local secret_name="$2"
    local secret_index="$3"
    
    log_info "准备通用Secret数据: $secret_name (索引: $secret_index)"
    
    # 获取该Secret索引的所有数据源配置
    local config_data=$(get_five_layer_config "$combo" "SECRET_${secret_index}_CONFIG_DATA")
    local config_file=$(get_five_layer_config "$combo" "SECRET_${secret_index}_CONFIG_FILE")
    
    # 创建临时数据目录
    local temp_secret_dir="/tmp/${secret_name}-data"
    mkdir -p "$temp_secret_dir"
    
    # 处理各种数据源
    local has_data=false
    
    # 获取 Secret 类型
    local secret_type=$(get_five_layer_config "$combo" "SECRET_${secret_index}_TYPE")
    
    # 根据 Secret 类型处理数据
    case "$secret_type" in
        "kubernetes.io/tls")
            # TLS Secret 固定键名处理: tls.crt, tls.key
            # 需要将 TLS_CRT 和 TLS_KEY 映射到 tls.crt 和 tls.key
            local tls_crt=$(get_five_layer_config "$combo" "SECRET_${secret_index}_TLS_CRT")
            local tls_key=$(get_five_layer_config "$combo" "SECRET_${secret_index}_TLS_KEY")
            
            if [[ -n "$tls_crt" && -f "$tls_crt" ]]; then
                cp "$tls_crt" "$temp_secret_dir/tls.crt"
                log_info "添加TLS证书: tls.crt (从 TLS_CRT 映射)"
                has_data=true
            fi
            
            if [[ -n "$tls_key" && -f "$tls_key" ]]; then
                cp "$tls_key" "$temp_secret_dir/tls.key"
                log_info "添加TLS私钥: tls.key (从 TLS_KEY 映射)"
                has_data=true
            fi
            ;;
            
        "kubernetes.io/dockerconfigjson")
            # Docker Secret 固定键名处理: .dockerconfigjson
            # 需要将 DOCKER_CONFIG 映射到 .dockerconfigjson
            local docker_config=$(get_five_layer_config "$combo" "SECRET_${secret_index}_DOCKER_CONFIG")
            if [[ -n "$docker_config" ]]; then
                echo "$docker_config" > "$temp_secret_dir/.dockerconfigjson"
                log_info "添加Docker配置: .dockerconfigjson (从 DOCKER_CONFIG 映射)"
                has_data=true
            fi
            ;;
            
        "kubernetes.io/basic-auth")
            # Basic Auth Secret 固定键名处理: username, password
            # 需要将 USERNAME 和 PASSWORD 映射到 username 和 password
            local username=$(get_five_layer_config "$combo" "SECRET_${secret_index}_USERNAME")
            local password=$(get_five_layer_config "$combo" "SECRET_${secret_index}_PASSWORD")
            
            if [[ -n "$username" ]]; then
                echo "$username" > "$temp_secret_dir/username"
                log_info "添加用户名: username (从 USERNAME 映射)"
                has_data=true
            fi
            
            if [[ -n "$password" ]]; then
                echo "$password" > "$temp_secret_dir/password"
                log_info "添加密码: password (从 PASSWORD 映射)"
                has_data=true
            fi
            ;;
            
        "kubernetes.io/ssh-auth")
            # SSH Auth Secret 固定键名处理: ssh-privatekey
            # 需要将 SSH_PRIVATEKEY 映射到 ssh-privatekey
            local ssh_privatekey=$(get_five_layer_config "$combo" "SECRET_${secret_index}_SSH_PRIVATEKEY")
            
            if [[ -n "$ssh_privatekey" && -f "$ssh_privatekey" ]]; then
                cp "$ssh_privatekey" "$temp_secret_dir/ssh-privatekey"
                log_info "添加SSH私钥: ssh-privatekey (从 SSH_PRIVATEKEY 映射)"
                has_data=true
            fi
            ;;
            
        "Opaque"|*)
            # Opaque Secret 或其他类型：动态键名处理
            # 排除系统配置项
            local system_keys=("TYPE" "NAME" "NAMESPACE" "APPLY_REMOTE" "LOCAL_SECRET_DIR")
            
            # 直接读取所有以 SECRET_${secret_index}_ 开头的配置项
            # 使用环境变量而不是文件读取
            for config_key in $(compgen -v | grep "^${combo}_SECRET_${secret_index}_"); do
                # 去掉前缀，得到键名
                local secret_key="${config_key#${combo}_SECRET_${secret_index}_}"
                
                # 跳过系统配置项
                local is_system_key=false
                for sys_key in "${system_keys[@]}"; do
                    if [[ "$secret_key" == "$sys_key" ]]; then
                        is_system_key=true
                        break
                    fi
                done
                
                if [[ "$is_system_key" == false ]]; then
                    local value="${!config_key}"
                    if [[ -n "$value" ]]; then
                        echo -n "$value" > "$temp_secret_dir/$secret_key"
                        log_info "添加数据: $secret_key"
                        has_data=true
                    fi
                fi
            done
            ;;
    esac
    
    # 如果没有任何数据，使用默认配置
    if [[ "$has_data" == false ]]; then
        echo '{"enabled": true, "version": "1.0"}' > "$temp_secret_dir/config.json"
        log_info "使用默认配置数据"
    fi
    
    log_success "通用Secret数据准备完成"
    return 0
}

# 准备基本认证Secret数据
prepare_basic_auth_secret_data() {
    local combo="$1"
    local secret_name="$2"
    local secret_index="$3"
    
    log_info "准备基本认证Secret数据: $secret_name (索引: $secret_index)"
    
    # 获取该Secret索引的数据源配置
    local username=$(get_five_layer_config "$combo" "SECRET_${secret_index}_USERNAME")
    local password=$(get_five_layer_config "$combo" "SECRET_${secret_index}_PASSWORD")
    
    if [[ -z "$username" || -z "$password" ]]; then
        log_error "缺少用户名或密码配置"
        return 1
    fi
    
    # 创建临时数据目录
    local temp_secret_dir="/tmp/${secret_name}-data"
    mkdir -p "$temp_secret_dir"
    
    # 创建基本认证数据
    echo "$username" > "$temp_secret_dir/username"
    echo "$password" > "$temp_secret_dir/password"
    
    log_info "使用基本认证: $username"
    log_success "基本认证Secret数据准备完成"
    return 0
}

# 准备SSH认证Secret数据
prepare_ssh_auth_secret_data() {
    local combo="$1"
    local secret_name="$2"
    local secret_index="$3"
    
    log_info "准备SSH认证Secret数据: $secret_name (索引: $secret_index)"
    
    # 获取该Secret索引的数据源配置
    local ssh_private_key=$(get_five_layer_config "$combo" "SECRET_${secret_index}_SSH_PRIVATE_KEY")
    local ssh_public_key=$(get_five_layer_config "$combo" "SECRET_${secret_index}_SSH_PUBLIC_KEY")
    
    if [[ -z "$ssh_private_key" ]]; then
        log_error "缺少SSH私钥配置"
        return 1
    fi
    
    # 创建临时数据目录
    local temp_secret_dir="/tmp/${secret_name}-data"
    mkdir -p "$temp_secret_dir"
    
    # 复制SSH密钥文件
    if [[ -f "$ssh_private_key" ]]; then
        cp "$ssh_private_key" "$temp_secret_dir/ssh-privatekey"
        log_info "使用SSH私钥: $ssh_private_key"
    else
        log_error "SSH私钥文件不存在: $ssh_private_key"
        return 1
    fi
    
    if [[ -n "$ssh_public_key" && -f "$ssh_public_key" ]]; then
        cp "$ssh_public_key" "$temp_secret_dir/ssh-publickey"
        log_info "使用SSH公钥: $ssh_public_key"
    fi
    
    log_success "SSH认证Secret数据准备完成"
    return 0
}
