#!/bin/bash

# =============================================================================
# Harbor Registry Secret 部署脚本
# 文件名: deploy-harbor-registry-secret.sh
# 用途: 部署Harbor镜像拉取Secret到Kubernetes集群
# =============================================================================

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Harbor Registry Secret 配置文件路径
HARBOR_SECRET_CONFIG_FILE="$SCRIPT_DIR/deploy-harbor-registry-secret.conf"

# Jenkins 项目根目录（与主 deploy-jenkins.sh 保持一致）
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# 导入统一部署模板（提供 log_* 和 Kubernetes 连接管理函数）
source "$PROJECT_ROOT/../../../utils/unified-deployment-template.sh"

# 解析命令行参数（优先于配置文件加载，确保命令行参数优先级最高）

# 先解析命令行参数（如果提供）
# 保存原始参数，以便在 main 函数中使用
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    unified_parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

# 加载配置
load_config() {
    # 尝试加载主配置文件（如果存在），以获取 JENKINS_IMAGE_REGISTRY 等环境变量
    MAIN_CONFIG_FILE="$(cd "$SCRIPT_DIR/../../.." && pwd)/deploy-jenkins.conf"
    if [[ -f "$MAIN_CONFIG_FILE" ]]; then
        # 临时禁用错误退出，因为主配置文件可能包含一些在当前上下文中不适用的配置
        set +e
        source "$MAIN_CONFIG_FILE" 2>/dev/null
        set -e
        log_info "已加载主配置文件: $MAIN_CONFIG_FILE"
    fi
    
    if [[ ! -f "$HARBOR_SECRET_CONFIG_FILE" ]]; then
        log_error "Harbor Registry Secret 配置文件不存在: $HARBOR_SECRET_CONFIG_FILE"
        exit 1
    fi
    
    source "$HARBOR_SECRET_CONFIG_FILE"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
    
    # 优先使用主配置文件中的 JENKINS_IMAGE_REGISTRY（如果已设置）
    if [[ -n "${JENKINS_IMAGE_REGISTRY:-}" ]]; then
        DOCKER_SERVER="$JENKINS_IMAGE_REGISTRY"
        log_info "使用主配置文件中的镜像仓库地址: $DOCKER_SERVER"
    fi
    
    log_success "✅ Harbor Registry Secret 配置加载成功"
}

# 部署 Harbor Registry Secret
deploy_harbor_registry_secret() {
    local namespace="${1:-cicd-platform-dev}"
    
    log_info "部署 Harbor Registry Secret..."
    log_info "命名空间: $namespace"
    log_info "Docker服务器: ${DOCKER_SERVER:-harbor.sunmoonai.local}"
    log_info "用户名: $DOCKER_USERNAME"
    
    # 检查密钥是否已存在
    if kubectl get secret "$SECRET_NAME" -n "$namespace" >/dev/null 2>&1; then
        log_success "✅ Harbor Registry Secret 已存在: $SECRET_NAME"
        log_info "如需更新，请先执行 uninstall 删除现有 Secret"
        return 0
    fi
    
    log_info "创建 Harbor Registry Secret..."
    
    # 构建 kubectl create secret docker-registry 命令
    local create_cmd=(
        kubectl create secret docker-registry "$SECRET_NAME"
        --namespace="$namespace"
        --docker-server="${DOCKER_SERVER:-harbor.sunmoonai.local}"
        --docker-username="$DOCKER_USERNAME"
        --docker-password="$DOCKER_PASSWORD"
    )
    
    # 如果配置了邮箱，添加邮箱参数
    if [[ -n "${DOCKER_EMAIL:-}" ]]; then
        create_cmd+=(--docker-email="$DOCKER_EMAIL")
    fi
    
    # 执行创建命令
    if "${create_cmd[@]}" 2>/dev/null; then
        log_success "✅ Harbor Registry Secret 创建成功: $SECRET_NAME"
        log_info "Secret 信息："
        log_info "  - 名称: $SECRET_NAME"
        log_info "  - 命名空间: $namespace"
        log_info "  - Docker服务器: ${DOCKER_SERVER:-harbor.sunmoonai.local}"
        log_info "  - 用户名: $DOCKER_USERNAME"
    else
        log_error "❌ Harbor Registry Secret 创建失败"
        return 1
    fi
    
    return 0
}

# 删除 Harbor Registry Secret
delete_harbor_registry_secret() {
    local namespace="${1:-cicd-platform-dev}"
    
    log_info "删除 Harbor Registry Secret..."
    log_info "命名空间: $namespace"
    
    if kubectl delete secret "$SECRET_NAME" -n "$namespace" 2>/dev/null; then
        log_success "✅ Harbor Registry Secret 删除成功"
    else
        log_warn "⚠️ Harbor Registry Secret 不存在或删除失败"
    fi
    
    return 0
}

# 检查 Secret 状态
check_secret_status() {
    local namespace="${1:-cicd-platform-dev}"
    
    log_info "检查 Harbor Registry Secret 状态..."
    log_info "命名空间: $namespace"
    
    if kubectl get secret "$SECRET_NAME" -n "$namespace" >/dev/null 2>&1; then
        log_success "✅ Harbor Registry Secret 存在: $SECRET_NAME"
        kubectl get secret "$SECRET_NAME" -n "$namespace"
        echo ""
        log_info "Secret 详细信息："
        kubectl describe secret "$SECRET_NAME" -n "$namespace" | grep -E "(Name:|Namespace:|Type:|docker-server|docker-username)" || true
    else
        log_error "❌ Harbor Registry Secret 不存在: $SECRET_NAME"
        return 1
    fi
    
    return 0
}

# 主函数
main() {
    # 使用解析后的参数（已移除 --cluster 参数）
    set -- "${ORIGINAL_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    local action="${1:-deploy}"
    local namespace="${2:-cicd-platform-dev}"
    
    # 建立远程 k8s 连接（使用统一模板中的连接管理函数）
    if ! read_k8s_config; then
        log_error "无法读取 Kubernetes 配置文件"; exit 1; fi
    if ! setup_kubectl_environment; then
        log_error "无法建立 Kubernetes 连接"; exit 1; fi
    
    # 加载配置
    load_config
    
    case "$action" in
        "deploy")
            deploy_harbor_registry_secret "$namespace"
            ;;
        "uninstall")
            delete_harbor_registry_secret "$namespace"
            ;;
        "status")
            check_secret_status "$namespace"
            ;;
        "help"|"-h"|"--help")
            echo "用法: $0 <action> [namespace]"
            echo ""
            echo "操作:"
            echo "  deploy           部署 Harbor Registry Secret（默认）"
            echo "  uninstall        删除 Harbor Registry Secret"
            echo "  status           检查 Secret 状态"
            echo "  help             显示此帮助信息"
            echo ""
            echo "参数:"
            echo "  namespace 命名空间（默认: cicd-platform-dev）"
            echo ""
            echo "示例:"
            echo "  $0 deploy"
            echo "  $0 deploy cicd-platform-dev"
            echo "  $0 uninstall"
            echo "  $0 status"
            echo ""
            echo "支持 --cluster 参数指定集群："
            echo "  $0 --cluster=C2 deploy"
            echo "  $0 --cluster C2 deploy cicd-platform-dev"
            exit 0
            ;;
        *)
            log_error "未知操作: $action"
            echo "使用 '$0 help' 查看帮助信息"
            exit 1
            ;;
    esac
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
