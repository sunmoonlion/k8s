#!/bin/bash

# =============================================================================
# Harbor Registry Secret 部署脚本
# 文件名: deploy-harbor-registry-secret.sh
# 用途: 生成并部署Harbor镜像拉取Secret到Kubernetes集群
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRET_DIR="$(dirname "$SCRIPT_DIR")"  # harbor-registry-secret 目录
# 计算项目根目录（k8s目录）
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../../.." && pwd)"

# 加载Secret生成核心函数
source "$PROJECT_ROOT/utils/secret-management/lib/secret-core.sh"
# 加载Secret数据准备函数（包含 prepare_docker_auth_secret_data）
source "$PROJECT_ROOT/utils/secret-management/lib/secret-data.sh"

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

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="ops-platform-dev"
DEFAULT_ENVIRONMENT="development"

# 尝试加载主配置文件（如果存在），以获取 flower_IMAGE_REGISTRY 等环境变量
# 主配置文件路径：../../deploy-flower.conf（相对于当前脚本目录）
MAIN_CONFIG_FILE="$(cd "$SCRIPT_DIR/../../.." && pwd)/deploy-flower.conf"
if [[ -f "$MAIN_CONFIG_FILE" ]]; then
    # 临时禁用错误退出，因为主配置文件可能包含一些在当前上下文中不适用的配置
    set +e
    source "$MAIN_CONFIG_FILE" 2>/dev/null
    set -e
    log_info "已加载主配置文件: $MAIN_CONFIG_FILE"
fi

# 加载配置文件（现在可以使用已设置的 CLUSTER 值和主配置文件中的环境变量）
CONFIG_FILE="$SCRIPT_DIR/deploy-harbor-registry-secret.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$PROJECT_ROOT/utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
else
    log_error "配置文件不存在: $CONFIG_FILE"
    exit 1
fi

main() {
    # 使用解析后的参数（已移除 --cluster 参数）
    set -- "${ORIGINAL_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    # 处理参数：如果第一个参数是 action（如 deploy），则跳过
    local action="${1:-deploy}"
    if [[ "$action" == "deploy" || "$action" == "uninstall" || "$action" == "status" ]]; then
        # 第一个参数是 action，跳过它
        shift
    fi
    
    local project_id="${1:-${PROJECT_ID:-$DEFAULT_PROJECT_ID}}"
    local namespace="${2:-${NAMESPACE:-$DEFAULT_NAMESPACE}}"
    local environment="${3:-${ENVIRONMENT:-$DEFAULT_ENVIRONMENT}}"
    local dry_run="${4:-false}"
    
    log_info "部署 Harbor Registry Secret..."
    log_info "部署参数："
    log_info "  - 项目ID: $project_id"
    log_info "  - 命名空间: $namespace"
    log_info "  - 环境: $environment"
    log_info "  - 试运行: $dry_run"
    echo ""
    
    # 1. 准备Docker认证Secret数据
    log_info "准备Docker认证Secret数据..."
    
    local prepare_args=(
        --server "${DOCKER_SERVER:-harbor.sunmoonai.local}"
        --username "$DOCKER_USERNAME"
        --password "$DOCKER_PASSWORD"
    )
    
    if [[ -n "${DOCKER_EMAIL:-}" ]]; then
        prepare_args+=(--email "$DOCKER_EMAIL")
    fi
    
    local temp_data_dir=$(prepare_docker_auth_secret_data "${prepare_args[@]}")
    if [[ $? -ne 0 ]] || [[ -z "$temp_data_dir" ]]; then
        log_error "Docker认证Secret数据准备失败"
        exit 1
    fi
    
    trap "rm -rf $temp_data_dir" EXIT
    
    # 2. 生成Docker Secret YAML
    local secret_yaml="$SECRET_DIR/harbor-registry-secret.yaml"
    
    log_info "生成Docker Secret YAML..."
    
    # 直接使用 Docker 配置参数生成 Secret YAML
    local generate_args=(
        --name "$SECRET_NAME"
        --namespace "$namespace"
        --docker-server "${DOCKER_SERVER:-harbor.sunmoonai.local}"
        --docker-username "$DOCKER_USERNAME"
        --docker-password "$DOCKER_PASSWORD"
        --output "$secret_yaml"
    )
    
    if [[ -n "${DOCKER_EMAIL:-}" ]]; then
        generate_args+=(--docker-email "$DOCKER_EMAIL")
    fi
    
    generate_docker_secret_yaml "${generate_args[@]}"
    
    log_success "Docker Secret YAML生成完成: $secret_yaml"
    
    # 2. 部署Secret到Kubernetes
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
        
        # 3. 可选：重启相关组件（如果配置了）
        if [[ "${RESTART_flowerS:-false}" == "true" && -n "${RESTART_flowerS_LIST:-}" ]]; then
            log_info "重启使用该Secret的组件..."
            IFS=',' read -ra flowerS <<< "${RESTART_flowerS_LIST}"
            for component in "${flowerS[@]}"; do
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
        log_info "[试运行] 将部署Secret: $SECRET_NAME"
        log_info "[试运行] YAML文件: $secret_yaml"
    fi
    
    echo ""
    log_success "Harbor Registry Secret 部署完成！"
    log_info "部署信息："
    log_info "  - Secret名称: $SECRET_NAME"
    log_info "  - 命名空间: $namespace"
    log_info "  - 部署时间: $(date '+%Y-%m-%d %H:%M:%S')"
}

# 显示帮助信息
show_help() {
    echo "Harbor Registry Secret 部署脚本"
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
    echo "  $0 sunmoonai ops-platform-dev dev   # 指定参数"
    echo "  $0 sunmoonai ops-platform-dev dev true # 试运行模式"
    echo ""
    echo "配置文件: $SCRIPT_DIR/deploy-harbor-registry-secret.conf"
}

# 主程序入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_help
        exit 0
    fi
    main "$@"
fi
