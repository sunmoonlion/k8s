#!/bin/bash

# =============================================================================
# Traefik TLS Secret 部署脚本
# 文件名: deploy-traefik-tls-secret.sh
# 用途: 生成并部署Traefik TLS Secret到Kubernetes集群
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRET_DIR="$(dirname "$SCRIPT_DIR")"  # traefik-tls-secret 目录
# 计算项目根目录（k8s目录）
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../../.." && pwd)"

# 先加载Secret生成核心函数（包含日志函数定义）
source "$PROJECT_ROOT/utils/secret-management/lib/secret-core.sh"

# 计算 Traefik 部署配置路径
# 从 deploy-traefik-tls-secret/ 向上3级到达 deploy-traefik/
# deploy-traefik-tls-secret/ -> traefik-tls-secret/ -> secrets/ -> deploy-traefik/
TRAEFIK_DEPLOY_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
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
# 加载Secret数据准备函数
source "$PROJECT_ROOT/utils/secret-management/lib/secret-data.sh"

# 加载 TLS Secret 部署配置（可选，用于覆盖 Secret 部署参数）
source "$SCRIPT_DIR/deploy-traefik-tls-secret.conf"

# 再次应用集群配置映射（如果有 TLS Secret 配置中的集群特定配置）
if [[ -f "$PROJECT_ROOT/utils/cluster-config-mapping.sh" ]]; then
    apply_cluster_config_mapping
fi

# 注意：日志函数已在 secret-core.sh 和 secret-data.sh 中定义（输出到 stderr）

# 解析命令行参数（优先于配置文件加载，确保命令行参数优先级最高）
declare -a PARSED_ARGS

parse_cluster_arg() {
    local args=("$@")
    PARSED_ARGS=()
    local cluster_value=""
    local i=0
    
    while [[ $i -lt ${#args[@]} ]]; do
        # 启用大小写不敏感匹配
        shopt -s nocasematch
        case "${args[$i]}" in
            --[cC][lL][uU][sS][tT][eE][rR]=*)
                # 支持等号形式：--cluster=C1 或 --CLUSTER=C1（大小写不敏感）
                cluster_value="${args[$i]#*=}"
                cluster_value=$(echo "$cluster_value" | tr '[:lower:]' '[:upper:]')
                export CLUSTER="$cluster_value"
                log_info "🔧 设置集群环境变量: CLUSTER=$cluster_value"
                ;;
            --[cC][lL][uU][sS][tT][eE][rR]|-c|-C)
                # 支持空格形式：--cluster C1 或 -c C1（大小写不敏感）
                if [[ $((i+1)) -lt ${#args[@]} ]]; then
                    cluster_value="${args[$((i+1))]}"
                    cluster_value=$(echo "$cluster_value" | tr '[:lower:]' '[:upper:]')
                    export CLUSTER="$cluster_value"
                    log_info "🔧 设置集群环境变量: CLUSTER=$cluster_value"
                    i=$((i+1))
                else
                    log_error "❌ --cluster 参数需要指定值（格式：C{数字}，如 C1, C2, C3 等）"
                    exit 1
                fi
                ;;
            *)
                PARSED_ARGS+=("${args[$i]}")
                ;;
        esac
        # 恢复大小写敏感匹配
        shopt -u nocasematch
        i=$((i+1))
    done
    
    if [[ -n "$cluster_value" ]]; then
        if [[ -f "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh" ]]; then
            source "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh"
            apply_cluster_config_mapping "$cluster_value"
        fi
    fi
}

# 先解析命令行参数（如果提供）
# 保存原始参数，以便在 main 函数中使用
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

# 主函数
main() {
    set -- "${PARSED_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    local project_id="${1:-$DEFAULT_PROJECT_ID}"
    local namespace="${2:-$DEFAULT_NAMESPACE}"
    local environment="${3:-$DEFAULT_ENVIRONMENT}"
    local dry_run="${4:-false}"
    
    log_info "部署 Traefik TLS Secret..."
    log_info "部署参数："
    log_info "  - 项目ID: $project_id"
    log_info "  - 命名空间: $namespace"
    log_info "  - 环境: $environment"
    log_info "  - 试运行: $dry_run"
    echo ""
    
    # 1. 生成服务器证书（每次部署均重新生成）
    log_info "生成服务器证书..."
    
    # 获取服务器证书路径（在同一 Secret 的 server-cert 目录下）
    local server_cert_dir="$SECRET_DIR/server-cert"
    local server_crt="$server_cert_dir/server.crt"
    local server_key="$server_cert_dir/server.key"
    
    # 调用服务器证书生成脚本（始终执行以确保更新）
    local cert_gen_script="$server_cert_dir/generate-server-cert/generate-server-cert.sh"
    
    if [[ ! -f "$cert_gen_script" ]]; then
        log_error "服务器证书生成脚本不存在: $cert_gen_script"
        exit 1
    fi
    
    if [[ ! -x "$cert_gen_script" ]]; then
        log_warn "服务器证书生成脚本无执行权限，尝试添加执行权限"
        chmod +x "$cert_gen_script" || {
            log_error "无法添加执行权限: $cert_gen_script"
            exit 1
        }
    fi
    
    # 执行证书生成（内部严格检查 CA；不会自动生成 CA）
    if ! bash "$cert_gen_script"; then
        log_error "服务器证书生成失败"
        exit 1
    fi
    log_success "服务器证书生成完成：$server_crt"
    
    # 2. 准备TLS Secret数据
    log_info "准备TLS Secret数据..."
    
    # 获取CA路径（从 Traefik 配置读取）
    local ca_dir="${TRAEFIK_CA_LOCAL_DIR/#\~/$HOME}"
    local ca_cert="$ca_dir/ca.crt"
    
    # 使用 prepare_tls_secret_data 准备数据
    local prepare_args=(
        --tls-crt "$server_cert_dir"
        --tls-key "$server_cert_dir"
    )
    
    if [[ -f "$ca_cert" ]]; then
        prepare_args+=(--ca-crt "$ca_cert")
    fi
    
    # 捕获 prepare_tls_secret_data 的输出（只捕获 stdout，stderr 会直接输出到终端）
    # 注意：prepare_tls_secret_data 的日志已重定向到 stderr，只有目录路径通过 stdout 返回
    local temp_data_dir
    temp_data_dir=$(prepare_tls_secret_data "${prepare_args[@]}")
    local prepare_ret=$?
    
    # 如果函数返回错误，退出
    if [[ $prepare_ret -ne 0 ]] || [[ -z "$temp_data_dir" ]]; then
        log_error "TLS Secret数据准备失败"
        exit 1
    fi
    
    # 清理可能的额外输出（只保留最后一行，应该是目录路径）
    # 因为某些日志可能仍然输出到 stdout，需要提取最后一行
    temp_data_dir=$(echo "$temp_data_dir" | tail -n 1 | tr -d '\n\r' | xargs)
    
    # 验证目录路径是否有效（必须是有效的目录路径）
    if [[ ! -d "$temp_data_dir" ]]; then
        log_error "TLS Secret数据目录无效: $temp_data_dir"
        log_error "请检查 prepare_tls_secret_data 函数的返回值"
        exit 1
    fi
    
    trap "rm -rf $temp_data_dir" EXIT
    
    # 2. 生成TLS Secret YAML
    local secret_yaml="$SECRET_DIR/traefik-tls-secret.yaml"
    
    log_info "生成TLS Secret YAML..."
    
    # 构建生成命令的参数
    local gen_args=(
        --name "$SECRET_NAME"
        --namespace "$namespace"
        --tls-crt "$temp_data_dir/tls.crt"
        --tls-key "$temp_data_dir/tls.key"
    )
    
    # 如果CA证书存在，添加CA证书参数
    if [[ -f "$temp_data_dir/ca.crt" ]]; then
        gen_args+=(--ca-crt "$temp_data_dir/ca.crt")
    fi
    
    gen_args+=(--output "$secret_yaml")
    
    # 调用生成函数
    generate_tls_secret_yaml "${gen_args[@]}"
    
    log_success "TLS Secret YAML生成完成: $secret_yaml"
    
    # 4. 部署Secret到Kubernetes（由底层脚本负责）
    if [[ "$dry_run" != "true" ]]; then
        log_info "部署Secret到Kubernetes集群..."
        
        # 检查命名空间是否存在
        if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
            log_error "命名空间不存在: $namespace"
            log_error "请先创建命名空间: kubectl create namespace $namespace"
            exit 1
        fi
        
        # 部署Secret
        if kubectl apply -f "$secret_yaml"; then
            log_success "Secret已部署: $SECRET_NAME (命名空间: $namespace)"
        else
            log_error "Secret部署失败"
            exit 1
        fi
        
        # 5. 可选：重启相关组件（如果配置了）
        if [[ "${RESTART_COMPONENTS:-false}" == "true" ]]; then
            log_info "重启使用该Secret的组件..."
            IFS=',' read -ra COMPONENTS <<< "${RESTART_COMPONENTS_LIST:-}"
            for component in "${COMPONENTS[@]}"; do
                component=$(echo "$component" | xargs)  # 去除空格
                if [[ -n "$component" ]]; then
                    log_info "重启组件: $component"
                    if kubectl rollout restart deployment/"$component" -n "$namespace" 2>/dev/null; then
                        log_success "组件 $component 重启命令已执行"
                    elif kubectl rollout restart statefulset/"$component" -n "$namespace" 2>/dev/null; then
                        log_success "组件 $component 重启命令已执行"
                    else
                        log_warn "组件 $component 不存在或重启失败"
                    fi
                fi
            done
        fi
    else
        log_info "[试运行] 将部署Secret: $SECRET_NAME"
        log_info "[试运行] YAML文件: $secret_yaml"
    fi
    
    echo ""
    log_success "Traefik TLS Secret 部署完成！"
    log_info "部署信息："
    log_info "  - Secret名称: $SECRET_NAME"
    log_info "  - 命名空间: $namespace"
    log_info "  - 部署时间: $(date '+%Y-%m-%d %H:%M:%S')"
}

# 显示帮助信息
show_help() {
    echo "Traefik TLS Secret 部署脚本"
    echo ""
    echo "用法:"
    echo "  $0 [项目ID] [命名空间] [环境] [试运行]"
    echo ""
    echo "参数:"
    echo "  项目ID     项目标识符 (默认: $DEFAULT_PROJECT_ID)"
    echo "  命名空间   Kubernetes 命名空间 (默认: $DEFAULT_NAMESPACE)"
    echo "  环境       部署环境 (默认: $DEFAULT_ENVIRONMENT)"
    echo "  试运行     是否试运行 (默认: false)"
    echo ""
    echo "示例:"
    echo "  $0                                    # 使用默认参数"
    echo "  $0 sunmoonai ingress-platform-dev dev # 指定参数"
    echo "  $0 sunmoonai ingress-platform-dev dev true # 试运行模式"
    echo ""
    echo "配置文件: $SCRIPT_DIR/deploy-traefik-tls-secret.conf"
}

# 主程序入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # 检查参数
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_help
        exit 0
    fi
    
    # 执行部署
    main "$@"
fi

