#!/bin/bash

# =============================================================================
# Secret数据源准备库
# 文件名: secret-data.sh
# 用途: 为不同类型的Secret准备相应的数据源
# 设计: 参数化函数，不依赖五层架构
# =============================================================================

# 日志函数（如果未定义）
# 注意：日志输出到 stderr，确保不影响函数的返回值（通过 stdout）
log_info() { echo -e "[INFO] $*" >&2; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $*" >&2; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $*" >&2; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $*" >&2; }
log_debug() { echo -e "\033[36m[DEBUG]\033[0m $*" >&2; }

_is_placeholder_docker_password() {
    local password="${1:-}"
    [[ -z "$password" || "$password" == "TODO_FILL_IN_HARBOR_PASSWORD" ]]
}

_load_global_harbor_credentials() {
    local lib_dir
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local k8s_root
    k8s_root="$(cd "$lib_dir/../../.." && pwd)"

    local had_errexit=0
    local had_nounset=0
    [[ $- == *e* ]] && had_errexit=1
    [[ $- == *u* ]] && had_nounset=1

    for global_config in \
        "$k8s_root/sunmoonai/deploy-sunmoonai-all/deploy-sunmoonai-all.conf" \
        "$k8s_root/sunmoonai/kind-infrastructure/deploy-kind/deploy-kind.conf"; do
        if [[ -f "$global_config" ]]; then
            set +e +u
            # shellcheck disable=SC1090
            source "$global_config" >/dev/null 2>&1
        fi
    done

    (( had_errexit )) && set -e
    (( had_nounset )) && set -u
}

resolve_docker_auth_password() {
    local password="${1:-}"

    if ! _is_placeholder_docker_password "$password"; then
        printf '%s\n' "$password"
        return 0
    fi

    _load_global_harbor_credentials

    if [[ -n "${HARBOR_ADMIN_PASSWORD:-}" ]]; then
        printf '%s\n' "$HARBOR_ADMIN_PASSWORD"
        return 0
    fi

    log_error "Docker registry 密码未配置。请设置 DOCKER_PASSWORD 或 HARBOR_ADMIN_PASSWORD，不能使用 TODO_FILL_IN_HARBOR_PASSWORD。"
    return 1
}

# =============================================================================
# TLS Secret 数据准备
# =============================================================================
# 用法: prepare_tls_secret_data --tls-crt <path> --tls-key <path> [--ca-crt <path>] [--output-dir <dir>]
# 返回: 输出目录路径（通过 stdout）
prepare_tls_secret_data() {
    local tls_crt=""
    local tls_key=""
    local ca_crt=""
    local output_dir=""
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --tls-crt)
                tls_crt="$2"
                shift 2
                ;;
            --tls-key)
                tls_key="$2"
                shift 2
                ;;
            --ca-crt)
                ca_crt="$2"
                shift 2
                ;;
            --output-dir)
                output_dir="$2"
                shift 2
                ;;
            *)
                log_error "未知参数: $1"
                return 1
                ;;
        esac
    done
    
    # 检查必需参数
    if [[ -z "$tls_crt" || -z "$tls_key" ]]; then
        log_error "TLS Secret需要 --tls-crt 和 --tls-key 参数"
        return 1
    fi
    
    # 展开路径中的 ~ 符号
    tls_crt="${tls_crt/#\~/$HOME}"
    tls_key="${tls_key/#\~/$HOME}"
    
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
    
    # 创建输出目录
    if [[ -z "$output_dir" ]]; then
        output_dir=$(mktemp -d)
    else
        mkdir -p "$output_dir"
    fi
    
    # 复制TLS证书文件到输出目录
    cp "$actual_tls_crt" "$output_dir/tls.crt"
    cp "$actual_tls_key" "$output_dir/tls.key"
    log_info "使用TLS证书: $actual_tls_crt"
    
    # 如果提供了CA证书，也复制它
    if [[ -n "$ca_crt" ]]; then
        ca_crt="${ca_crt/#\~/$HOME}"
        if [[ -f "$ca_crt" ]]; then
            cp "$ca_crt" "$output_dir/ca.crt"
            log_info "已包含CA证书: $ca_crt"
        else
            log_warn "CA证书文件不存在: $ca_crt"
        fi
    fi
    
    # 确保日志输出到 stderr，然后通过 stdout 输出目录路径
    # 注意：必须先输出日志到 stderr，再输出目录路径到 stdout
    log_success "TLS Secret数据准备完成: $output_dir"
    # 显式输出目录路径（不包含任何日志信息）
    printf '%s\n' "$output_dir"
    return 0
}

# =============================================================================
# Docker 认证 Secret 数据准备
# =============================================================================
# 用法: prepare_docker_auth_secret_data --server <url> --username <user> --password <pass> [--email <email>] [--output-dir <dir>]
# 返回: 输出目录路径（通过 stdout）
prepare_docker_auth_secret_data() {
    local docker_server=""
    local docker_username=""
    local docker_password=""
    local docker_email=""
    local docker_config=""
    local output_dir=""
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --server)
                docker_server="$2"
                shift 2
                ;;
            --username)
                docker_username="$2"
                shift 2
                ;;
            --password)
                docker_password="$2"
                shift 2
                ;;
            --email)
                docker_email="$2"
                shift 2
                ;;
            --docker-config)
                docker_config="$2"
                shift 2
                ;;
            --output-dir)
                output_dir="$2"
                shift 2
                ;;
            *)
                log_error "未知参数: $1"
                return 1
                ;;
        esac
    done
    
    # 如果直接提供了DOCKER_CONFIG，使用它
    if [[ -n "$docker_config" ]]; then
        log_info "使用预配置的Docker认证数据"
        
        if [[ -z "$output_dir" ]]; then
            output_dir=$(mktemp -d)
        else
            mkdir -p "$output_dir"
        fi
        
        echo "$docker_config" > "$output_dir/.dockerconfigjson"
        log_success "Docker认证Secret数据准备完成: $output_dir"
        echo "$output_dir"
        return 0
    fi
    
    docker_password="$(resolve_docker_auth_password "$docker_password")" || return 1

    # 检查必需参数
    if [[ -z "$docker_username" || -z "$docker_password" ]]; then
        log_error "Docker认证需要 --username 和 --password 参数，或提供 --docker-config"
        return 1
    fi
    
    # 默认服务器
    if [[ -z "$docker_server" ]]; then
        docker_server="harbor.sunmoonai.local"
    fi
    
    # 创建输出目录
    if [[ -z "$output_dir" ]]; then
        output_dir=$(mktemp -d)
    else
        mkdir -p "$output_dir"
    fi
    
    # 生成Docker认证数据
    local auth_data=""
    if [[ -n "$docker_email" ]]; then
        auth_data="{\"auths\":{\"$docker_server\":{\"username\":\"$docker_username\",\"password\":\"$docker_password\",\"email\":\"$docker_email\",\"auth\":\"$(echo -n "$docker_username:$docker_password" | base64 -w 0)\"}}}"
    else
        auth_data="{\"auths\":{\"$docker_server\":{\"username\":\"$docker_username\",\"password\":\"$docker_password\",\"auth\":\"$(echo -n "$docker_username:$docker_password" | base64 -w 0)\"}}}"
    fi
    
    log_info "使用Docker认证: $docker_username@$docker_server"
    
    echo "$auth_data" > "$output_dir/.dockerconfigjson"
    
    log_success "Docker认证Secret数据准备完成: $output_dir"
    echo "$output_dir"
    return 0
}

# =============================================================================
# Opaque Secret 数据准备
# =============================================================================
# 用法: prepare_opaque_secret_data --data-dir <dir> [--output-dir <dir>]
# 说明: 将源目录中的数据文件复制到输出目录
# 返回: 输出目录路径（通过 stdout）
prepare_opaque_secret_data() {
    local data_dir=""
    local output_dir=""
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --data-dir)
                data_dir="$2"
                shift 2
                ;;
            --output-dir)
                output_dir="$2"
                shift 2
                ;;
            *)
                log_error "未知参数: $1"
                return 1
                ;;
        esac
    done
    
    # 检查必需参数
    if [[ -z "$data_dir" ]]; then
        log_error "Opaque Secret需要 --data-dir 参数"
        return 1
    fi
    
    # 展开路径中的 ~ 符号
    data_dir="${data_dir/#\~/$HOME}"
    
    # 检查源目录是否存在
    if [[ ! -d "$data_dir" ]]; then
        log_error "数据目录不存在: $data_dir"
        return 1
    fi
    
    # 创建输出目录
    if [[ -z "$output_dir" ]]; then
        output_dir=$(mktemp -d)
    else
        mkdir -p "$output_dir"
    fi
    
    # 复制所有文件（不包括隐藏文件，除非明确指定）
    local file_count=0
    while IFS= read -r -d '' file; do
        local filename=$(basename "$file")
        cp "$file" "$output_dir/$filename"
        log_info "添加数据文件: $filename"
        ((file_count++))
    done < <(find "$data_dir" -maxdepth 1 -type f -print0 2>/dev/null)
    
    if [[ $file_count -eq 0 ]]; then
        log_warn "数据目录为空，创建默认配置"
        echo '{"enabled": true, "version": "1.0"}' > "$output_dir/config.json"
    fi
    
    log_success "Opaque Secret数据准备完成: $output_dir ($file_count 个文件)"
    echo "$output_dir"
    return 0
}

# =============================================================================
# Basic Auth Secret 数据准备
# =============================================================================
# 用法: prepare_basic_auth_secret_data --username <user> --password <pass> [--output-dir <dir>]
# 返回: 输出目录路径（通过 stdout）
prepare_basic_auth_secret_data() {
    local username=""
    local password=""
    local output_dir=""
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --username)
                username="$2"
                shift 2
                ;;
            --password)
                password="$2"
                shift 2
                ;;
            --output-dir)
                output_dir="$2"
                shift 2
                ;;
            *)
                log_error "未知参数: $1"
                return 1
                ;;
        esac
    done
    
    # 检查必需参数
    if [[ -z "$username" || -z "$password" ]]; then
        log_error "Basic Auth Secret需要 --username 和 --password 参数"
        return 1
    fi
    
    # 创建输出目录
    if [[ -z "$output_dir" ]]; then
        output_dir=$(mktemp -d)
    else
        mkdir -p "$output_dir"
    fi
    
    # 创建基本认证数据
    echo -n "$username" > "$output_dir/username"
    echo -n "$password" > "$output_dir/password"
    
    log_info "使用基本认证: $username"
    log_success "Basic Auth Secret数据准备完成: $output_dir"
    echo "$output_dir"
    return 0
}

# =============================================================================
# SSH Auth Secret 数据准备
# =============================================================================
# 用法: prepare_ssh_auth_secret_data --private-key <path> [--public-key <path>] [--output-dir <dir>]
# 返回: 输出目录路径（通过 stdout）
prepare_ssh_auth_secret_data() {
    local ssh_private_key=""
    local ssh_public_key=""
    local output_dir=""
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --private-key)
                ssh_private_key="$2"
                shift 2
                ;;
            --public-key)
                ssh_public_key="$2"
                shift 2
                ;;
            --output-dir)
                output_dir="$2"
                shift 2
                ;;
            *)
                log_error "未知参数: $1"
                return 1
                ;;
        esac
    done
    
    # 检查必需参数
    if [[ -z "$ssh_private_key" ]]; then
        log_error "SSH Auth Secret需要 --private-key 参数"
        return 1
    fi
    
    # 展开路径中的 ~ 符号
    ssh_private_key="${ssh_private_key/#\~/$HOME}"
    
    # 检查私钥文件是否存在
    if [[ ! -f "$ssh_private_key" ]]; then
        log_error "SSH私钥文件不存在: $ssh_private_key"
        return 1
    fi
    
    # 创建输出目录
    if [[ -z "$output_dir" ]]; then
        output_dir=$(mktemp -d)
    else
        mkdir -p "$output_dir"
    fi
    
    # 复制SSH私钥
    cp "$ssh_private_key" "$output_dir/ssh-privatekey"
    log_info "使用SSH私钥: $ssh_private_key"
    
    # 如果提供了公钥，也复制它
    if [[ -n "$ssh_public_key" ]]; then
        ssh_public_key="${ssh_public_key/#\~/$HOME}"
        if [[ -f "$ssh_public_key" ]]; then
            cp "$ssh_public_key" "$output_dir/ssh-publickey"
            log_info "使用SSH公钥: $ssh_public_key"
        else
            log_warn "SSH公钥文件不存在: $ssh_public_key"
        fi
    fi
    
    log_success "SSH Auth Secret数据准备完成: $output_dir"
    echo "$output_dir"
    return 0
}
