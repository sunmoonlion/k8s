#!/bin/bash

# Kibana 递归部署脚本
# 基于递归架构设计原则的两级部署逻辑

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 保存 Kibana 脚本的目录路径（统一部署模板会重新定义 SCRIPT_DIR）
KIBANA_SCRIPT_DIR="$SCRIPT_DIR"

# 导入统一部署模板
source "$PROJECT_ROOT/../../../utils/unified-deployment-template.sh"

# 恢复 Kibana 脚本的目录路径
SCRIPT_DIR="$KIBANA_SCRIPT_DIR"

# 先解析命令行参数中的集群选择（下沉到统一模板）
# 保存原始参数，以便在 main 函数中使用
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    if type unified_parse_cluster_arg >/dev/null 2>&1; then
        unified_parse_cluster_arg "$@"
        ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
    else
        log_warn "⚠️  unified_parse_cluster_arg 不存在，跳过集群参数解析（将依赖 CLUSTER/default_cluster）"
    fi
fi

KIBANA_CONFIG_FILE="$SCRIPT_DIR/deploy-kibana.conf"
if [[ -f "$KIBANA_CONFIG_FILE" ]]; then
    # 在加载配置文件前保存 SCRIPT_DIR，防止被覆盖
    SAVED_SCRIPT_DIR="$SCRIPT_DIR"
    source "$KIBANA_CONFIG_FILE"
    # 恢复 SCRIPT_DIR，防止被配置文件覆盖
    SCRIPT_DIR="$SAVED_SCRIPT_DIR"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    # 在加载前再次保存 SCRIPT_DIR，因为 cluster-config-mapping.sh 可能会覆盖它
    SAVED_SCRIPT_DIR="$SCRIPT_DIR"
    if [[ -f "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh" ]]; then
        # 临时保存当前的 SCRIPT_DIR
        original_script_dir="$SCRIPT_DIR"
        source "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh"
        # 立即恢复 SCRIPT_DIR，防止被 cluster-config-mapping.sh 覆盖
        SCRIPT_DIR="$original_script_dir"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
        # 再次确保 SCRIPT_DIR 正确
        SCRIPT_DIR="$original_script_dir"
    fi
    # 最后再次确保 SCRIPT_DIR 正确
    SCRIPT_DIR="$SAVED_SCRIPT_DIR"
    
    log_info "已加载 Kibana 配置文件: $KIBANA_CONFIG_FILE"
else
    log_error "缺少 Kibana 配置文件: $KIBANA_CONFIG_FILE"
    exit 1
fi

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="data-platform-dev"
DEFAULT_ENVIRONMENT="development"

# Kibana 资源目录（固定路径）
KIBANA_CHART_DIR="$SCRIPT_DIR/../resources/kibana"
KIBANA_CUSTOM_VALUES_DIR="$SCRIPT_DIR/../resources/custom-values"

# 检查命名空间是否存在
check_namespace() {
    local namespace="$1"
    
    # 确保 Kubernetes 连接已建立
    if ! setup_kubectl_environment; then
        log_error "❌ 无法建立 Kubernetes 连接"
        return 1
    fi
    
    local _ns_err
    _ns_err=$(kubectl get namespace "$namespace" 2>&1)
    if [[ $? -eq 0 ]]; then
        log_success "✅ 命名空间 $namespace 已存在"
        return 0
    elif echo "$_ns_err" | grep -qiE "not.?found|NotFound"; then
        log_error "❌ 命名空间 $namespace 不存在！"
        echo ""
        log_info "请先使用 namespace-platform 部署所需的命名空间："
        echo "  cd ../../../../namespace-platform"
        echo "  ./scripts/deploy.sh --env dev"
        echo ""
        log_info "或者手动创建命名空间："
        echo "  kubectl create namespace $namespace"
        echo ""
        return 1
    else
        log_error "❌ kubectl 连接失败，无法验证命名空间 $namespace（${_ns_err%%$'\n'*}）"
        log_error "请检查 KUBECONFIG 和集群连接状态"
        return 1
    fi
}

# 定义 Kibana 所需镜像（保留给镜像检查设计使用）
define_required_images() {
    local environment="$1"
    
    case "$environment" in
        "development"|"dev")
            echo "kibana:$KIBANA_IMAGE_VERSION|true"
            ;;
        "production"|"prod")
            echo "kibana:$KIBANA_IMAGE_VERSION|true"
            ;;
        *)
            echo "kibana:$KIBANA_IMAGE_VERSION|true"
            ;;
    esac
}

# 使用统一模板的通用按需推送 helper，将 Kibana 组件镜像推送到 Harbor
push_kibana_images_to_harbor() {
    push_component_images_to_harbor "kibana"
}

# 执行 Kibana 部署
execute_kibana_deployment() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始执行 Kibana 部署..."
    log_info "项目: $project_id"
    log_info "命名空间: $namespace"
    log_info "环境: $environment"
    log_info "离线模式: $KIBANA_FORCE_OFFLINE"
    
    # 检查 Chart 目录是否存在
    if [[ ! -d "$KIBANA_CHART_DIR" ]]; then
        log_error "Kibana Chart 目录不存在: $KIBANA_CHART_DIR"
        return 1
    fi
    
    # 构建 values 文件路径
    # 环境名称映射：development -> dev, production -> prod
    local env_file_name="${environment}"
    if [[ "$environment" == "development" ]]; then
        env_file_name="dev"
    elif [[ "$environment" == "production" ]]; then
        env_file_name="prod"
    fi
    local values_file="$KIBANA_CUSTOM_VALUES_DIR/${env_file_name}-values.yaml"
    if [[ ! -f "$values_file" ]]; then
        log_warn "环境配置文件不存在: $values_file，使用默认配置"
        values_file=""
    else
        log_info "使用 values 文件: $values_file"
    fi
    
    # 构建 Helm 命令
    local release_name="kibana-$project_id"
    local helm_cmd="helm upgrade --install $release_name $KIBANA_CHART_DIR"
    helm_cmd="$helm_cmd --namespace $namespace"
    helm_cmd="$helm_cmd --set global.projectId=$project_id"
    helm_cmd="$helm_cmd --set global.namespace=$namespace"
    helm_cmd="$helm_cmd --set global.environment=$environment"
    
    # 使用 Harbor 时覆盖镜像，避免从 docker.io 拉取
    if [[ -n "${KIBANA_IMAGE_REGISTRY:-}" ]] && [[ -n "${KIBANA_IMAGE_PROJECT:-}" ]]; then
        helm_cmd="$helm_cmd --set global.imageRegistry=$KIBANA_IMAGE_REGISTRY"
        helm_cmd="$helm_cmd --set image.registry=$KIBANA_IMAGE_REGISTRY"
        helm_cmd="$helm_cmd --set image.repository=$KIBANA_IMAGE_PROJECT/kibana"
        helm_cmd="$helm_cmd --set image.tag=${KIBANA_IMAGE_VERSION:-9.1.2-debian-12-r0}"
        helm_cmd="$helm_cmd --set volumePermissions.image.registry=$KIBANA_IMAGE_REGISTRY"
        helm_cmd="$helm_cmd --set volumePermissions.image.repository=$KIBANA_IMAGE_PROJECT/os-shell"
        helm_cmd="$helm_cmd --set volumePermissions.image.tag=${KIBANA_OS_SHELL_IMAGE_VERSION:-12-debian-12-r51}"
        log_info "使用 Harbor 镜像: $KIBANA_IMAGE_REGISTRY/$KIBANA_IMAGE_PROJECT/kibana:${KIBANA_IMAGE_VERSION:-9.1.2-debian-12-r0}"
    fi
    
    if [[ -n "$values_file" ]]; then
        helm_cmd="$helm_cmd --values $values_file"
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        helm_cmd="$helm_cmd --dry-run"
        log_info "执行 Kibana 部署（试运行模式）..."
    else
        log_info "执行 Kibana 部署..."
    fi
    
    # 执行部署
    if eval "$helm_cmd"; then
        if [[ "$dry_run" == "true" ]]; then
            log_success "✅ Kibana 部署试运行完成"
        else
            log_success "✅ Kibana 部署完成"
        fi
        return 0
    else
        log_error "❌ Kibana 部署失败"
        return 1
    fi
}

# 检查 Kibana 状态
check_kibana_status() {
    local project_id="$1"
    local namespace="$2"
    local release_name="kibana-$project_id"
    local label_selector="app.kubernetes.io/instance=$release_name"
    
    log_info "检查 Kibana 部署状态..."
    
    # 确保 Kubernetes 连接可用（如果连接已断开，尝试重新建立）
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_warn "⚠️  Kubernetes 连接已断开，尝试重新建立..."
        if ! setup_kubectl_environment; then
            log_warn "⚠️  无法重新建立 Kubernetes 连接，跳过状态检查"
            return 0  # 不返回错误，因为部署可能已经成功
        fi
    fi
    
    # 检查 Helm Release
    if helm list -n "$namespace" | grep -q "$release_name"; then
        log_success "✅ Kibana Helm Release 存在"
    else
        log_error "❌ Kibana Helm Release 不存在"
        return 1
    fi
    
    # 检查 Pod 状态：区分“启动中”和“异常未运行”
    local phases
    phases=$(kubectl get pods -n "$namespace" -l "$label_selector" -o jsonpath='{.items[*].status.phase}' 2>/dev/null || echo "")
    local pods_running=0
    local pods_pending=0
    if [[ -n "$phases" ]]; then
        local running_count pending_count
        running_count=$(echo "$phases" | tr ' ' '\n' | grep -c '^Running$' 2>/dev/null || echo "0")
        pending_count=$(echo "$phases" | tr ' ' '\n' | grep -cE '^(Pending|ContainerCreating)$' 2>/dev/null || echo "0")
        pods_running=$(echo "$running_count" | tr -d '[:space:]' | sed 's/[^0-9]//g')
        pods_pending=$(echo "$pending_count" | tr -d '[:space:]' | sed 's/[^0-9]//g')
        [[ -z "$pods_running" || ! "$pods_running" =~ ^[0-9]+$ ]] && pods_running=0
        [[ -z "$pods_pending" || ! "$pods_pending" =~ ^[0-9]+$ ]] && pods_pending=0
        pods_running=$((10#$pods_running))
        pods_pending=$((10#$pods_pending))
    fi
    if (( pods_running > 0 )); then
        log_success "✅ Kibana Pod 运行正常 (${pods_running} 个)"
    elif (( pods_pending > 0 )); then
        log_warn "⏳ Kibana Pod 正在启动中（${pods_pending} 个 Pending/ContainerCreating，0 个 Running）"
        log_info "提示：这是正常的启动过程，如需查看详细进度可稍后运行 status 子命令。"
        # 启动中不视为失败，直接返回成功，让整体部署流程继续
        return 0
    else
        log_error "❌ Kibana Pod 未运行"
        return 1
    fi
    
    # 测试 Kibana 连接
    test_kibana_connection "$project_id" "$namespace"
}

# 测试 Kibana 连接
test_kibana_connection() {
    local project_id="$1"
    local namespace="$2"
    local release_name="kibana-$project_id"
    local label_selector="app.kubernetes.io/instance=$release_name"
    
    log_info "测试 Kibana 连接..."
    
    # 获取 Kibana 服务信息
    local service_name
    service_name=$(kubectl get svc -n "$namespace" -l "$label_selector" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -z "$service_name" ]]; then
        log_error "❌ 未找到 Kibana 服务"
        return 1
    fi
    
    # 测试连接（使用 kubectl port-forward 或直接连接）
    log_info "Kibana 服务: $service_name"
    log_success "✅ Kibana 连接测试完成"
}

# 显示 Kibana 连接信息
show_kibana_connection_info() {
    local namespace="$1"
    
    # 获取外部访问配置（使用默认值如果未设置）
    local external_host="${KIBANA_UNIFIED_HOST:-www.sunmoonai.com}"
    local external_port="${KIBANA_EXTERNAL_PORT:-30443}"
    
    echo ""
    echo "=== Kibana 连接信息 ==="
    echo "命名空间: $namespace"
    echo "外部访问: $external_host:$external_port/kibana"
    echo ""
    echo "=== 使用说明 ==="
    echo "1. 配置 hosts 文件（如果需要）:"
    echo "   echo '101.126.151.0 $external_host' | sudo tee -a /etc/hosts"
    echo ""
    echo "2. 访问 Kibana:"
    echo "   https://$external_host:$external_port/kibana"
    echo "   或（如果配置了 iptables 转发）:"
    echo "   https://$external_host/kibana"
    echo ""
    echo "3. 查看服务状态:"
    echo "   kubectl get pods,svc -n $namespace -l app.kubernetes.io/instance=kibana-<project_id>"
    echo ""
}

# 递归部署子组件（中间件 / Ingress）
deploy_sub_components() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"

    log_info "开始部署 Kibana 子组件..."

    local sub_components=(
        "kibana_middleware:${middleware_enabled:-false}:${middleware_priority:-1000}:Kibana 中间件:$SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh"
        "kibana_ingress:${ingress_enabled:-false}:${ingress_priority:-100}:Kibana Web 路由:$SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh"
    )

    IFS=$'\n' sub_components=($(sort -t: -k3 -nr <<<"${sub_components[*]}")); unset IFS

    for component_info in "${sub_components[@]}"; do
        IFS=':' read -r name enabled priority description script_path <<< "$component_info"
        if [[ "$enabled" == "true" ]]; then
            log_info "部署 $description (优先级: $priority)..."
            if [[ -f "$script_path" ]]; then
                if [[ "$name" == "kibana_ingress" ]]; then
                    bash "$script_path" deploy "$project_id" "$namespace" "$environment" || return 1
                else
                    bash "$script_path" deploy "$project_id" "$namespace" "$environment" "$dry_run" || return 1
                fi
            else
                log_error "❌ $description 脚本不存在: $script_path"; return 1
            fi
        fi
    done

    log_success "✅ Kibana 子组件部署完成"
    return 0
}

# 创建 Kibana 密钥（如果需要）
create_kibana_secrets_if_needed() {
    local namespace="$1"
    
    log_info "检查 Kibana 密钥..."
    
    # 统一密管负责创建；仅提示
    if kubectl get secret "$KIBANA_AUTH_SECRET_NAME" -n "$namespace" >/dev/null 2>&1; then
        log_success "✅ Kibana 密钥已存在: $KIBANA_AUTH_SECRET_NAME"
    else
        log_info "跳过创建 Kibana 密钥（由统一密管管理）：$KIBANA_AUTH_SECRET_NAME"
    fi
}

# 部署 Kibana Secrets（使用新的 Secret 管理系统）
deploy_kibana_secrets() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="${4:-false}"
    
    log_info "🚀 部署 Kibana Secrets..."
    
    local secrets_script="$SCRIPT_DIR/secrets/deploy-secrets-all/deploy-secrets-all.sh"
    
    if [[ ! -f "$secrets_script" ]]; then
        log_warn "⚠️  Kibana Secrets 部署脚本不存在: $secrets_script"
        log_warn "跳过 Secrets 部署，请手动部署或检查脚本路径"
        return 0
    fi
    
    # 检查是否启用 Secrets 部署（默认启用）
    if [[ "${secrets_enabled:-true}" == "true" ]]; then
        # 设置 SECRETS_SCRIPT_DIR 环境变量，让子脚本知道自己的目录
        local secrets_script_dir="$(dirname "$secrets_script")"
        if SECRETS_SCRIPT_DIR="$secrets_script_dir" bash "$secrets_script" "$project_id" "$namespace" "$environment" "$dry_run"; then
            log_success "✅ Kibana Secrets 部署成功"
            return 0
        else
            log_error "❌ Kibana Secrets 部署失败"
            return 1
        fi
    else
        log_info "跳过 Kibana Secrets 部署（secrets_enabled=false）"
        return 0
    fi
}

# 解析命令行参数（支持 --cluster 或 -c）
declare -a PARSED_ARGS


# 主函数
main() {
    # 使用解析后的参数（已移除 --cluster 参数）
    set -- "${ORIGINAL_ARGS[@]}"
    set -- "${PARSED_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    local action="${1:-deploy}"
    local project_id="${2:-$DEFAULT_PROJECT_ID}"
    local namespace="${3:-$DEFAULT_NAMESPACE}"
    local environment="${4:-$DEFAULT_ENVIRONMENT}"
    local dry_run="${5:-false}"
    
    # 读取 Kubernetes 配置文件并建立连接
    if ! read_k8s_config; then
        log_error "无法读取 Kubernetes 配置文件"
        exit 1
    fi
    if ! setup_kubectl_environment; then
        log_error "无法建立 Kubernetes 连接"
        exit 1
    fi
    
    case "$action" in
        "deploy")
            log_info "开始部署 Kibana..."
            if [[ "${KIBANA_ENABLED:-true}" != "true" ]]; then
                log_warn "Kibana 已被禁用（KIBANA_ENABLED=false），跳过部署。"
                # 若已有 release，则可选择缩容为 0，节省资源
                if helm list -n "$namespace" | grep -q "kibana-$project_id"; then
                    log_info "将现有 Kibana 缩容为 0 副本以节省资源"
                    kubectl -n "$namespace" scale deploy/kibana-"$project_id" --replicas=0 || true
                fi
                exit 0
            fi
            check_namespace "$namespace"
            # 在部署前按需推送 Kibana 组件镜像到 Harbor（Kind 使用 push-to-harbor，远程使用 registry-push-management）
            push_kibana_images_to_harbor || log_warn "[images] Kibana 镜像推送阶段出现警告，可稍后单独检查 Harbor 镜像状态"
            # 部署 Secrets（在主部署之前）
            if ! deploy_kibana_secrets "$project_id" "$namespace" "$environment" "$dry_run"; then
                log_error "❌ Kibana Secrets 部署失败，终止主部署"
                exit 1
            fi
            execute_kibana_deployment "$project_id" "$namespace" "$environment" "$dry_run"
            # 子组件：中间件与 Web Ingress
            if deploy_sub_components "$project_id" "$namespace" "$environment" "$dry_run"; then
                check_kibana_status "$project_id" "$namespace" || true
                show_kibana_connection_info "$namespace"
            else
                log_error "❌ Kibana 子组件部署失败"
                exit 1
            fi
            ;;
        "upgrade")
            log_info "开始升级 Kibana..."
            check_namespace "$namespace"
            execute_kibana_deployment "$project_id" "$namespace" "$environment" "$dry_run"
            check_kibana_status "$project_id" "$namespace"
            ;;
        "uninstall")
            log_info "开始卸载 Kibana..."
            # 卸载子组件
            log_info "卸载 Kibana 子组件..."
            local sub_components=(
                "kibana_middleware:${middleware_enabled:-false}:${middleware_priority:-1000}:Kibana 中间件:$SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh"
                "kibana_ingress:${ingress_enabled:-false}:${ingress_priority:-100}:Kibana Web 路由:$SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh"
            )
            IFS=$'\n' sub_components=($(sort -t: -k3 -n <<<"${sub_components[*]}")); unset IFS
            for component_info in "${sub_components[@]}"; do
                IFS=':' read -r name enabled priority description script_path <<< "$component_info"
                if [[ "$enabled" == "true" && -f "$script_path" ]]; then
                    # 禁用子脚本的自动清理，保持连接以便后续操作
                    DISABLE_AUTO_CLEANUP=true bash "$script_path" uninstall "$project_id" "$namespace" "$environment" || true
                    log_success "✅ $description 卸载完成"
                fi
            done
            # 确保连接仍然可用
            if ! kubectl get nodes >/dev/null 2>&1; then
                log_info "连接已断开，重新建立连接..."
                if ! setup_kubectl_environment; then
                    log_error "无法重新建立 Kubernetes 连接"
                    return 1
                fi
            fi
            helm uninstall "kibana-$project_id" -n "$namespace" --wait || true
            log_success "✅ Kibana 卸载完成"
            ;;
        "clean")
            log_info "开始清理 Kibana..."
            helm uninstall "kibana-$project_id" -n "$namespace" || true
            kubectl delete pvc -n "$namespace" -l app.kubernetes.io/instance="kibana-$project_id" || true
            log_success "✅ Kibana 清理完成"
            ;;
        "status")
            check_kibana_status "$project_id" "$namespace"
            show_kibana_connection_info "$namespace"
            ;;
        "logs")
            log_info "显示 Kibana 日志..."
            kubectl logs -n "$namespace" -l app.kubernetes.io/instance="kibana-$project_id" --tail=100
            ;;
        "connect")
            show_kibana_connection_info "$namespace"
            ;;
        *)
            echo "用法: $0 <action> [project_id] [namespace] [environment] [dry_run]"
            echo ""
            echo "操作:"
            echo "  deploy     部署 Kibana（默认）"
            echo "  upgrade    升级 Kibana"
            echo "  uninstall  卸载 Kibana"
            echo "  clean      清理 Kibana（包括数据）"
            echo "  status     检查 Kibana 状态"
            echo "  logs       显示 Kibana 日志"
            echo "  connect    显示连接信息"
            echo ""
            echo "参数:"
            echo "  project_id   项目标识符（默认: $DEFAULT_PROJECT_ID）"
            echo "  namespace    命名空间（默认: $DEFAULT_NAMESPACE）"
            echo "  environment  环境（默认: $DEFAULT_ENVIRONMENT）"
            echo "  dry_run      试运行模式（默认: false）"
            echo ""
            echo "示例:"
            echo "  $0 deploy sunmoonai data-platform-dev development"
            echo "  $0 status"
            exit 1
            ;;
    esac
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
