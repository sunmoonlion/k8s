#!/bin/bash

# =============================================================================
# Harbor Registry Secret 部署脚本（Incubator SSR）
# 文件名: deploy-harbor-registry-secret.sh
# 用途: 生成并部署 Harbor 镜像拉取 Secret 到 Kubernetes 集群
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRET_DIR="$(dirname "$SCRIPT_DIR")"  # harbor-registry-secret 目录
# 计算项目根目录（k8s 目录）
# 从 deploy-harbor-registry-secret/ 向上 9 级到达 k8s/
# deploy-harbor-registry-secret/ -> harbor-registry-secret/ -> secrets/ -> deploy-incubator-ssr/ -> incubator-app-ssr/ -> incubator-app/ -> business-apps/ -> app-platform/ -> sunmoonai/ -> k8s/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../../../../.." && pwd)"

# 加载 Secret 生成核心函数
source "$PROJECT_ROOT/utils/secret-management/lib/secret-core.sh"

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
                cluster_value="${args[$i]#*=}"
                cluster_value=$(echo "$cluster_value" | tr '[:lower:]' '[:upper:]')
                export CLUSTER="$cluster_value"
                log_info "🔧 设置集群环境变量: CLUSTER=$cluster_value"
                ;;
            --[cC][lL][uU][sS][tT][eE][rR]|-c|-C)
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

ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

# 尝试加载主配置文件（如果存在），以获取 INCUBATOR_APP_SSR_IMAGE_REGISTRY 等环境变量
# 主配置文件路径：../../deploy-incubator-ssr.conf（相对于当前脚本目录）
MAIN_CONFIG_FILE="$(cd "$SCRIPT_DIR/../../.." && pwd)/deploy-incubator-ssr.conf"
if [[ -f "$MAIN_CONFIG_FILE" ]]; then
    set +e
    source "$MAIN_CONFIG_FILE" 2>/dev/null
    set -e
    log_info "已加载主配置文件: $MAIN_CONFIG_FILE"
fi

CONFIG_FILE="$SCRIPT_DIR/deploy-harbor-registry-secret.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    
    if [[ -f "$PROJECT_ROOT/utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/utils/cluster-config-mapping.sh"
        apply_cluster_config_mapping
    fi
else
    log_error "配置文件不存在: $CONFIG_FILE"
    exit 1
fi

main() {
    set -- "${ORIGINAL_ARGS[@]}"
    set -- "${PARSED_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    local project_id="${1:-$DEFAULT_PROJECT_ID}"
    local namespace="${2:-$DEFAULT_NAMESPACE}"
    local environment="${3:-$DEFAULT_ENVIRONMENT}"
    local dry_run="${4:-false}"
    
    log_info "部署 Harbor Registry Secret (Incubator SSR)..."
    log_info "部署参数："
    log_info "  - 项目ID: $project_id"
    log_info "  - 命名空间: $namespace"
    log_info "  - 环境: $environment"
    log_info "  - 试运行: $dry_run"
    echo ""
    
    log_info "准备 Docker 认证 Secret 数据..."
    
    local prepare_args=(
        --server "${DOCKER_SERVER:-harbor.sunmoonai.com:30443}"
        --username "$DOCKER_USERNAME"
        --password "$DOCKER_PASSWORD"
    )
    
    if [[ -n "${DOCKER_EMAIL:-}" ]]; then
        prepare_args+=(--email "$DOCKER_EMAIL")
    fi
    
    local temp_data_dir
    temp_data_dir=$(prepare_docker_auth_secret_data "${prepare_args[@]}")
    if [[ $? -ne 0 ]] || [[ -z "$temp_data_dir" ]]; then
        log_error "Docker 认证 Secret 数据准备失败"
        exit 1
    fi
    
    trap "rm -rf $temp_data_dir" EXIT
    
    local secret_yaml="$SECRET_DIR/harbor-registry-secret.yaml"
    
    log_info "生成 Docker Secret YAML..."
    
    generate_docker_secret_yaml \
        --name "$SECRET_NAME" \
        --namespace "$namespace" \
        --docker-config "$temp_data_dir/.dockerconfigjson" \
        --output "$secret_yaml"
    
    log_success "Docker Secret YAML 生成完成: $secret_yaml"
    
    if [[ "$dry_run" != "true" ]]; then
        log_info "部署 Secret 到 Kubernetes 集群..."
        
        if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
            log_error "命名空间不存在: $namespace"
            log_error "请先创建命名空间: kubectl create namespace $namespace"
            exit 1
        fi
        
        if kubectl apply -f "$secret_yaml"; then
            log_success "Secret 已部署: $SECRET_NAME (命名空间: $namespace)"
        else
            log_error "Secret 部署失败"
            exit 1
        fi
        
        if [[ "${RESTART_COMPONENTS:-false}" == "true" && -n "${RESTART_COMPONENTS_LIST:-}" ]]; then
            log_info "重启使用该 Secret 的组件..."
            IFS=',' read -ra COMPONENTS <<< "${RESTART_COMPONENTS_LIST}"
            for component in "${COMPONENTS[@]}"; do
                component=$(echo "$component" | xargs)
                if [[ -n "$component" ]]; then
                    log_info "重启组件: $component"
                    kubectl rollout restart deployment/"$component" -n "$namespace" 2>/dev/null || \
                    kubectl rollout restart statefulset/"$component" -n "$namespace" 2>/dev/null || \
                    log_warn "组件 $component 不存在或重启失败"
                fi
            done
        fi
    else
        log_info "[试运行] 将部署 Secret: $SECRET_NAME"
        log_info "[试运行] YAML 文件: $secret_yaml"
    fi
    
    echo ""
    log_success "Harbor Registry Secret (Incubator SSR) 部署完成！"
    log_info "部署信息："
    log_info "  - Secret 名称: $SECRET_NAME"
    log_info "  - 命名空间: $namespace"
    log_info "  - 部署时间: $(date '+%Y-%m-%d %H:%M:%S')"
}

show_help() {
    echo "Harbor Registry Secret 部署脚本 (Incubator SSR)"
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
    echo "  $0                                          # 使用默认参数"
    echo "  $0 sunmoonai app-platform-dev dev          # 指定参数"
    echo "  $0 sunmoonai app-platform-dev dev true     # 试运行模式"
    echo ""
    echo "配置文件: $SCRIPT_DIR/deploy-harbor-registry-secret.conf"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        show_help
        exit 0
    fi
    main "$@"
fi


