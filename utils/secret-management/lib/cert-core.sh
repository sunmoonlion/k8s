#!/bin/bash

# =============================================================================
# 证书生成核心函数库（抽离版本）
# 文件名: cert-core.sh
# 用途: 提供服务器证书生成函数（基于 CA 生成服务器证书）
# 设计: 完全参数化，不依赖组合代码，组件可直接调用
# 注意: 此模块只提供服务器证书生成，不提供 CA 生成功能
#       CA 生成请使用 ~/master/k8s/utils/ca-management/
# =============================================================================

# 日志函数（如果未定义）
log_info() { echo -e "[INFO] $*"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $*" 1>&2; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $*"; }

# =============================================================================
# 服务器证书生成函数
# =============================================================================
# 用法: generate_server_cert_from_ca --ca-cert <path> --ca-key <path> --server-cn <cn> [--server-dns <dns>] [--server-ips <ips>] --output-dir <dir> [--days <days>] [--key-size <size>]
generate_server_cert_from_ca() {
    local ca_cert=""
    local ca_key=""
    local server_cn=""
    local server_dns=""
    local server_ips=""
    local output_dir=""
    local days="365"
    local key_size="2048"
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ca-cert)
                ca_cert="$2"
                shift 2
                ;;
            --ca-key)
                ca_key="$2"
                shift 2
                ;;
            --server-cn)
                server_cn="$2"
                shift 2
                ;;
            --server-dns)
                server_dns="$2"
                shift 2
                ;;
            --server-ips)
                server_ips="$2"
                shift 2
                ;;
            --output-dir)
                output_dir="$2"
                shift 2
                ;;
            --days)
                days="$2"
                shift 2
                ;;
            --key-size)
                key_size="$2"
                shift 2
                ;;
            *)
                log_error "未知参数: $1"
                return 1
                ;;
        esac
    done
    
    # 验证必需参数
    if [[ -z "$ca_cert" || -z "$ca_key" || -z "$server_cn" || -z "$output_dir" ]]; then
        log_error "缺少必需参数"
        log_error "用法: generate_server_cert_from_ca --ca-cert <path> --ca-key <path> --server-cn <cn> [--server-dns <dns>] [--server-ips <ips>] --output-dir <dir> [--days <days>] [--key-size <size>]"
        return 1
    fi
    
    # 检查CA文件
    if [[ ! -f "$ca_cert" ]]; then
        log_error "CA证书文件不存在: $ca_cert"
        return 1
    fi
    
    if [[ ! -f "$ca_key" ]]; then
        log_error "CA私钥文件不存在: $ca_key"
        return 1
    fi
    
    # 创建输出目录
    mkdir -p "$output_dir"
    
    # 证书和私钥路径
    local cert_path="$output_dir/server.crt"
    local key_path="$output_dir/server.key"
    
    # 生成私钥
    log_info "生成服务器私钥: $key_path"
    openssl genrsa -out "$key_path" "$key_size"
    
    # 创建服务器证书配置文件（用于 CSR）
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
CN = $server_cn

[v3_req]
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
subjectAltName = @alt_names

[alt_names]
DNS.1 = $server_cn
EOF

    # 添加DNS列表到配置文件
    if [[ -n "$server_dns" ]]; then
        local dns_count=2
        IFS=',' read -ra DNS_ARRAY <<< "$server_dns"
        for dns in "${DNS_ARRAY[@]}"; do
            dns=$(echo "$dns" | xargs)  # 去除空格
            # 跳过空值和与CN重复的值（DNS.1 已经设置为 CN，避免重复）
            if [[ -n "$dns" && "$dns" != "$server_cn" ]]; then
                echo "DNS.$dns_count = $dns" >> "$config_path"
                ((dns_count++))
            fi
        done
    fi
    
    # 添加IP列表到配置文件
    if [[ -n "$server_ips" ]]; then
        local ip_count=1
        IFS=' ' read -ra IP_ARRAY <<< "$server_ips"
        for ip in "${IP_ARRAY[@]}"; do
            ip=$(echo "$ip" | xargs)  # 去除空格
            if [[ -n "$ip" ]]; then
                echo "IP.$ip_count = $ip" >> "$config_path"
                ((ip_count++))
            fi
        done
    fi
    
    # 生成证书签名请求
    local csr_path="$output_dir/server.csr"
    log_info "生成服务器证书签名请求: $csr_path"
    openssl req -new -key "$key_path" -out "$csr_path" -config "$config_path"
    
    # 创建用于签名的扩展配置文件（包含 authorityKeyIdentifier）
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
DNS.1 = $server_cn
EOF

    # 添加DNS列表到扩展配置文件
    if [[ -n "$server_dns" ]]; then
        local dns_count=2
        IFS=',' read -ra DNS_ARRAY <<< "$server_dns"
        for dns in "${DNS_ARRAY[@]}"; do
            dns=$(echo "$dns" | xargs)  # 去除空格
            # 跳过空值和与CN重复的值（DNS.1 已经设置为 CN，避免重复）
            if [[ -n "$dns" && "$dns" != "$server_cn" ]]; then
                echo "DNS.$dns_count = $dns" >> "$ext_config_path"
                ((dns_count++))
            fi
        done
    fi
    
    # 添加IP列表到扩展配置文件
    if [[ -n "$server_ips" ]]; then
        local ip_count=1
        IFS=' ' read -ra IP_ARRAY <<< "$server_ips"
        for ip in "${IP_ARRAY[@]}"; do
            ip=$(echo "$ip" | xargs)  # 去除空格
            if [[ -n "$ip" ]]; then
                echo "IP.$ip_count = $ip" >> "$ext_config_path"
                ((ip_count++))
            fi
        done
    fi
    
    # 使用CA签名服务器证书（使用扩展配置文件）
    log_info "使用CA签名服务器证书: $cert_path"
    openssl x509 -req -in "$csr_path" -CA "$ca_cert" -CAkey "$ca_key" \
        -CAcreateserial -out "$cert_path" -days "$days" \
        -extensions v3_req -extfile "$ext_config_path"
    
    # 设置权限
    chmod 600 "$key_path"
    chmod 644 "$cert_path"
    
    # 清理临时文件
    rm -f "$csr_path"
    rm -f "$config_path"
    rm -f "$ext_config_path"
    rm -f "$output_dir/ca.srl"  # OpenSSL创建的序列号文件
    
    log_success "服务器证书生成完成"
    log_info "  - 证书: $cert_path"
    log_info "  - 私钥: $key_path"
    log_info "  - CN: $server_cn"
    if [[ -n "$server_dns" ]]; then
        log_info "  - DNS: $server_dns"
    fi
    if [[ -n "$server_ips" ]]; then
        log_info "  - IPs: $server_ips"
    fi
    
    return 0
}

# =============================================================================
# CA路径获取辅助函数
# =============================================================================
# 用法: get_ca_paths
# 返回: ca_cert_path|ca_key_path（通过echo输出，用|分隔）
# 说明: 从配置文件或环境变量读取CA路径，确保路径一致性
# 注意: CA 配置已迁移到 ~/master/k8s/utils/ca-management/ca-management.conf
get_ca_paths() {
    # 优先从 ca-management 配置文件读取
    local ca_config_file="$HOME/k8s/utils/ca-management/ca-management.conf"
    local ca_dir=""
    
    if [[ -f "$ca_config_file" ]]; then
        # 从 ca-management 配置读取
        source "$ca_config_file"
        ca_dir="${ROOT_CA_LOCAL_DIR:-~/master/k8s/certs/ca/shared}"
    else
        # 回退到环境变量或默认值
        ca_dir="${ROOT_CA_LOCAL_DIR:-~/master/k8s/certs/ca/shared}"
    fi
    
    # 展开路径中的 ~ 符号
    ca_dir="${ca_dir/#\~/$HOME}"
    
    local ca_cert="$ca_dir/ca.crt"
    local ca_key="$ca_dir/ca.key"
    
    # 检查CA文件是否存在
    if [[ ! -f "$ca_cert" ]]; then
        log_error "CA证书不存在: $ca_cert"
        log_error "请先运行: ~/master/k8s/utils/ca-management/generate-ca.sh"
        log_error "CA 管理已迁移到 ~/master/k8s/utils/ca-management/"
        return 1
    fi
    
    if [[ ! -f "$ca_key" ]]; then
        log_error "CA私钥不存在: $ca_key"
        log_error "请先运行: ~/master/k8s/utils/ca-management/generate-ca.sh"
        log_error "CA 管理已迁移到 ~/master/k8s/utils/ca-management/"
        return 1
    fi
    
    # 返回路径（用|分隔）
    echo "$ca_cert|$ca_key"
    return 0
}

