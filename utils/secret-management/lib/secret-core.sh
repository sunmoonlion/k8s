#!/bin/bash

# =============================================================================
# Secret 生成核心函数库（抽离版本）
# 文件名: secret-core.sh
# 用途: 提供5种Secret类型的YAML生成函数（纯函数，无副作用）
# 设计: 完全参数化，不依赖组合代码，组件可直接调用
# =============================================================================

# 兼容：部分部署脚本会依赖 secret-data.sh 中的 prepare_* 辅助函数
# 这里按需加载，避免“command not found”
_SECRET_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${_SECRET_LIB_DIR}/secret-data.sh" ]]; then
    # shellcheck disable=SC1090
    source "${_SECRET_LIB_DIR}/secret-data.sh"
fi

# 日志函数（如果未定义）
# 注意：日志输出到 stderr，确保不影响函数的返回值（通过 stdout）
log_info() { echo -e "[INFO] $*" >&2; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $*" >&2; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $*" >&2; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $*" >&2; }

# =============================================================================
# 1. TLS Secret 生成函数
# =============================================================================
# 用法: generate_tls_secret_yaml --name <name> --namespace <ns> --tls-crt <path> --tls-key <path> [--ca-crt <path>] --output <path>
generate_tls_secret_yaml() {
    local secret_name=""
    local secret_namespace=""
    local tls_crt=""
    local tls_key=""
    local ca_crt=""
    local output_path=""
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name)
                secret_name="$2"
                shift 2
                ;;
            --namespace)
                secret_namespace="$2"
                shift 2
                ;;
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
            --output)
                output_path="$2"
                shift 2
                ;;
            *)
                log_error "未知参数: $1"
                return 1
                ;;
        esac
    done
    
    # 验证必需参数
    if [[ -z "$secret_name" || -z "$secret_namespace" || -z "$tls_crt" || -z "$tls_key" || -z "$output_path" ]]; then
        log_error "缺少必需参数"
        log_error "用法: generate_tls_secret_yaml --name <name> --namespace <ns> --tls-crt <path> --tls-key <path> [--ca-crt <path>] --output <path>"
        return 1
    fi
    
    # 检查证书文件
    if [[ ! -f "$tls_crt" ]]; then
        log_error "TLS证书文件不存在: $tls_crt"
        return 1
    fi
    
    if [[ ! -f "$tls_key" ]]; then
        log_error "TLS私钥文件不存在: $tls_key"
        return 1
    fi
    
    # Base64编码
    local b64_tls_crt=$(base64 -w 0 "$tls_crt")
    local b64_tls_key=$(base64 -w 0 "$tls_key")
    local b64_ca_crt=""
    
    if [[ -n "$ca_crt" && -f "$ca_crt" ]]; then
        b64_ca_crt=$(base64 -w 0 "$ca_crt")
    fi
    
    # 创建输出目录
    mkdir -p "$(dirname "$output_path")"
    
    # 生成YAML
    {
        echo "apiVersion: v1"
        echo "kind: Secret"
        echo "metadata:"
        echo "  name: ${secret_name}"
        echo "  namespace: ${secret_namespace}"
        echo "type: kubernetes.io/tls"
        echo "data:"
        echo "  tls.crt: ${b64_tls_crt}"
        echo "  tls.key: ${b64_tls_key}"
        if [[ -n "$b64_ca_crt" ]]; then
            echo "  ca.crt: ${b64_ca_crt}"
        fi
    } > "$output_path"
    
    # 设置安全权限
    chmod 600 "$output_path"
    
    log_success "TLS Secret YAML生成完成: $output_path"
    return 0
}

# =============================================================================
# 2. Docker Secret 生成函数
# =============================================================================
# 用法:
#   - generate_docker_secret_yaml --name <name> --namespace <ns> --docker-server <server> --docker-username <user> --docker-password <pass> [--docker-email <email>] --output <path>
#   - generate_docker_secret_yaml --name <name> --namespace <ns> --docker-config <path-to-.dockerconfigjson> --output <path>
generate_docker_secret_yaml() {
    local secret_name=""
    local secret_namespace=""
    local docker_server=""
    local docker_username=""
    local docker_password=""
    local docker_email=""
    local docker_config_path=""
    local output_path=""
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name)
                secret_name="$2"
                shift 2
                ;;
            --namespace)
                secret_namespace="$2"
                shift 2
                ;;
            --docker-server)
                docker_server="$2"
                shift 2
                ;;
            --docker-username)
                docker_username="$2"
                shift 2
                ;;
            --docker-password)
                docker_password="$2"
                shift 2
                ;;
            --docker-email)
                docker_email="$2"
                shift 2
                ;;
            --docker-config)
                docker_config_path="$2"
                shift 2
                ;;
            --output)
                output_path="$2"
                shift 2
                ;;
            *)
                log_error "未知参数: $1"
                return 1
                ;;
        esac
    done
    
    # 验证必需参数
    if [[ -z "$secret_name" || -z "$secret_namespace" || -z "$output_path" ]]; then
        log_error "缺少必需参数"
        log_error "用法: generate_docker_secret_yaml --name <name> --namespace <ns> --docker-server <server> --docker-username <user> --docker-password <pass> [--docker-email <email>] --output <path>"
        log_error "  或: generate_docker_secret_yaml --name <name> --namespace <ns> --docker-config <path> --output <path>"
        return 1
    fi

    # 两种模式：直接使用 dockerconfigjson 文件 或 账号密码生成
    local b64_docker_config=""
    if [[ -n "$docker_config_path" ]]; then
        if [[ ! -f "$docker_config_path" ]]; then
            log_error "docker config 文件不存在: $docker_config_path"
            return 1
        fi
        b64_docker_config=$(base64 -w 0 "$docker_config_path")
    else
        if command -v resolve_docker_auth_password >/dev/null 2>&1; then
            docker_password="$(resolve_docker_auth_password "$docker_password")" || return 1
        fi

        if [[ -z "$docker_server" || -z "$docker_username" || -z "$docker_password" ]]; then
            log_error "缺少 Docker 认证参数（需要 --docker-server/--docker-username/--docker-password 或 --docker-config）"
            return 1
        fi
        # 生成Docker认证数据
        local auth_data=""
        local auth_string
        auth_string=$(echo -n "$docker_username:$docker_password" | base64 -w 0)
        if [[ -n "$docker_email" ]]; then
            auth_data="{\"auths\":{\"$docker_server\":{\"username\":\"$docker_username\",\"password\":\"$docker_password\",\"email\":\"$docker_email\",\"auth\":\"$auth_string\"}}}"
        else
            auth_data="{\"auths\":{\"$docker_server\":{\"username\":\"$docker_username\",\"password\":\"$docker_password\",\"auth\":\"$auth_string\"}}}"
        fi
        b64_docker_config=$(echo -n "$auth_data" | base64 -w 0)
    fi
    
    # 创建输出目录
    mkdir -p "$(dirname "$output_path")"
    
    # 生成YAML
    {
        echo "apiVersion: v1"
        echo "kind: Secret"
        echo "metadata:"
        echo "  name: ${secret_name}"
        echo "  namespace: ${secret_namespace}"
        echo "type: kubernetes.io/dockerconfigjson"
        echo "data:"
        echo "  .dockerconfigjson: ${b64_docker_config}"
    } > "$output_path"
    
    log_success "Docker Secret YAML生成完成: $output_path"
    return 0
}

# =============================================================================
# 3. Opaque Secret 生成函数
# =============================================================================
# 用法: generate_opaque_secret_yaml --name <name> --namespace <ns> --data-dir <dir> --output <path>
#   或: generate_opaque_secret_yaml --name <name> --namespace <ns> --data-file <key:path> [--data-file <key:path> ...] --output <path>
generate_opaque_secret_yaml() {
    local secret_name=""
    local secret_namespace=""
    local data_dir=""
    local data_files=()
    local output_path=""
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name)
                secret_name="$2"
                shift 2
                ;;
            --namespace)
                secret_namespace="$2"
                shift 2
                ;;
            --data-dir)
                data_dir="$2"
                shift 2
                ;;
            --data-file)
                data_files+=("$2")
                shift 2
                ;;
            --output)
                output_path="$2"
                shift 2
                ;;
            *)
                log_error "未知参数: $1"
                return 1
                ;;
        esac
    done
    
    # 验证必需参数
    if [[ -z "$secret_name" || -z "$secret_namespace" || -z "$output_path" ]]; then
        log_error "缺少必需参数"
        log_error "用法: generate_opaque_secret_yaml --name <name> --namespace <ns> (--data-dir <dir> | --data-file <key:path> ...) --output <path>"
        return 1
    fi
    
    # 创建输出目录
    mkdir -p "$(dirname "$output_path")"
    
    # 开始生成YAML
    {
        echo "apiVersion: v1"
        echo "kind: Secret"
        echo "metadata:"
        echo "  name: ${secret_name}"
        echo "  namespace: ${secret_namespace}"
        echo "type: Opaque"
        echo "data:"
    } > "$output_path"
    
    # 方式1：从数据目录读取所有文件
    if [[ -n "$data_dir" ]]; then
        if [[ ! -d "$data_dir" ]]; then
            log_error "数据目录不存在: $data_dir"
            return 1
        fi
        
        for file in "$data_dir"/*; do
            if [[ -f "$file" ]]; then
                local key_name=$(basename "$file")
                local b64_content=$(base64 -w 0 "$file")
                echo "  ${key_name}: ${b64_content}" >> "$output_path"
                log_info "添加数据键: $key_name"
            fi
        done
    fi
    
    # 方式2：从指定文件读取（格式：key:path）
    for data_file in "${data_files[@]}"; do
        if [[ "$data_file" =~ ^([^:]+):(.+)$ ]]; then
            local key_name="${BASH_REMATCH[1]}"
            local file_path="${BASH_REMATCH[2]}"
            
            if [[ ! -f "$file_path" ]]; then
                log_warn "文件不存在，跳过: $file_path"
                continue
            fi
            
            local b64_content=$(base64 -w 0 "$file_path")
            echo "  ${key_name}: ${b64_content}" >> "$output_path"
            log_info "添加数据键: $key_name (从 $file_path)"
        else
            log_warn "无效的数据文件格式（应为 key:path）: $data_file"
        fi
    done
    
    log_success "Opaque Secret YAML生成完成: $output_path"
    return 0
}

# =============================================================================
# 4. Basic Auth Secret 生成函数
# =============================================================================
# 用法: generate_basic_auth_secret_yaml --name <name> --namespace <ns> --username <user> --password <pass> --output <path>
generate_basic_auth_secret_yaml() {
    local secret_name=""
    local secret_namespace=""
    local username=""
    local password=""
    local output_path=""
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name)
                secret_name="$2"
                shift 2
                ;;
            --namespace)
                secret_namespace="$2"
                shift 2
                ;;
            --username)
                username="$2"
                shift 2
                ;;
            --password)
                password="$2"
                shift 2
                ;;
            --output)
                output_path="$2"
                shift 2
                ;;
            *)
                log_error "未知参数: $1"
                return 1
                ;;
        esac
    done
    
    # 验证必需参数
    if [[ -z "$secret_name" || -z "$secret_namespace" || -z "$username" || -z "$password" || -z "$output_path" ]]; then
        log_error "缺少必需参数"
        log_error "用法: generate_basic_auth_secret_yaml --name <name> --namespace <ns> --username <user> --password <pass> --output <path>"
        return 1
    fi
    
    # Base64编码
    local b64_username=$(echo -n "$username" | base64 -w 0)
    local b64_password=$(echo -n "$password" | base64 -w 0)
    
    # 创建输出目录
    mkdir -p "$(dirname "$output_path")"
    
    # 生成YAML
    {
        echo "apiVersion: v1"
        echo "kind: Secret"
        echo "metadata:"
        echo "  name: ${secret_name}"
        echo "  namespace: ${secret_namespace}"
        echo "type: kubernetes.io/basic-auth"
        echo "data:"
        echo "  username: ${b64_username}"
        echo "  password: ${b64_password}"
    } > "$output_path"
    
    log_success "Basic Auth Secret YAML生成完成: $output_path"
    return 0
}

# =============================================================================
# 5. SSH Auth Secret 生成函数
# =============================================================================
# 用法: generate_ssh_auth_secret_yaml --name <name> --namespace <ns> --ssh-privatekey <path> [--ssh-publickey <path>] --output <path>
generate_ssh_auth_secret_yaml() {
    local secret_name=""
    local secret_namespace=""
    local ssh_privatekey=""
    local ssh_publickey=""
    local output_path=""
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name)
                secret_name="$2"
                shift 2
                ;;
            --namespace)
                secret_namespace="$2"
                shift 2
                ;;
            --ssh-privatekey)
                ssh_privatekey="$2"
                shift 2
                ;;
            --ssh-publickey)
                ssh_publickey="$2"
                shift 2
                ;;
            --output)
                output_path="$2"
                shift 2
                ;;
            *)
                log_error "未知参数: $1"
                return 1
                ;;
        esac
    done
    
    # 验证必需参数
    if [[ -z "$secret_name" || -z "$secret_namespace" || -z "$ssh_privatekey" || -z "$output_path" ]]; then
        log_error "缺少必需参数"
        log_error "用法: generate_ssh_auth_secret_yaml --name <name> --namespace <ns> --ssh-privatekey <path> [--ssh-publickey <path>] --output <path>"
        return 1
    fi
    
    # 检查私钥文件
    if [[ ! -f "$ssh_privatekey" ]]; then
        log_error "SSH私钥文件不存在: $ssh_privatekey"
        return 1
    fi
    
    # Base64编码
    local b64_privatekey=$(base64 -w 0 "$ssh_privatekey")
    local b64_publickey=""
    
    if [[ -n "$ssh_publickey" && -f "$ssh_publickey" ]]; then
        b64_publickey=$(base64 -w 0 "$ssh_publickey")
    fi
    
    # 创建输出目录
    mkdir -p "$(dirname "$output_path")"
    
    # 生成YAML
    {
        echo "apiVersion: v1"
        echo "kind: Secret"
        echo "metadata:"
        echo "  name: ${secret_name}"
        echo "  namespace: ${secret_namespace}"
        echo "type: kubernetes.io/ssh-auth"
        echo "data:"
        echo "  ssh-privatekey: ${b64_privatekey}"
        if [[ -n "$b64_publickey" ]]; then
            echo "  ssh-publickey: ${b64_publickey}"
        fi
    } > "$output_path"
    
    # 设置安全权限
    chmod 600 "$output_path"
    
    log_success "SSH Auth Secret YAML生成完成: $output_path"
    return 0
}

# =============================================================================
# 自动选择Secret生成函数（根据类型）
# =============================================================================
# 用法: generate_secret_yaml_by_type --type <type> --name <name> --namespace <ns> [其他类型特定参数] --output <path>
generate_secret_yaml_by_type() {
    local secret_type=""
    local secret_name=""
    local secret_namespace=""
    local output_path=""
    local other_args=()
    
    # 解析通用参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type)
                secret_type="$2"
                shift 2
                ;;
            --name)
                secret_name="$2"
                shift 2
                ;;
            --namespace)
                secret_namespace="$2"
                shift 2
                ;;
            --output)
                output_path="$2"
                shift 2
                ;;
            *)
                other_args+=("$1" "$2")
                shift 2
                ;;
        esac
    done
    
    # 验证必需参数
    if [[ -z "$secret_type" || -z "$secret_name" || -z "$secret_namespace" || -z "$output_path" ]]; then
        log_error "缺少必需参数"
        log_error "用法: generate_secret_yaml_by_type --type <type> --name <name> --namespace <ns> [其他参数] --output <path>"
        return 1
    fi
    
    # 根据类型调用相应函数
    case "$secret_type" in
        "kubernetes.io/tls")
            generate_tls_secret_yaml \
                --name "$secret_name" \
                --namespace "$secret_namespace" \
                "${other_args[@]}" \
                --output "$output_path"
            ;;
        "kubernetes.io/dockerconfigjson")
            generate_docker_secret_yaml \
                --name "$secret_name" \
                --namespace "$secret_namespace" \
                "${other_args[@]}" \
                --output "$output_path"
            ;;
        "Opaque")
            generate_opaque_secret_yaml \
                --name "$secret_name" \
                --namespace "$secret_namespace" \
                "${other_args[@]}" \
                --output "$output_path"
            ;;
        "kubernetes.io/basic-auth")
            generate_basic_auth_secret_yaml \
                --name "$secret_name" \
                --namespace "$secret_namespace" \
                "${other_args[@]}" \
                --output "$output_path"
            ;;
        "kubernetes.io/ssh-auth")
            generate_ssh_auth_secret_yaml \
                --name "$secret_name" \
                --namespace "$secret_namespace" \
                "${other_args[@]}" \
                --output "$output_path"
            ;;
        *)
            log_error "不支持的Secret类型: $secret_type"
            log_error "支持的类型: kubernetes.io/tls, kubernetes.io/dockerconfigjson, Opaque, kubernetes.io/basic-auth, kubernetes.io/ssh-auth"
            return 1
            ;;
    esac
}
