#!/bin/bash

# Logstash 递归部署脚本
# 基于递归架构设计原则的两级部署逻辑

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 保存 Logstash 脚本的目录路径（统一部署模板会重新定义 SCRIPT_DIR）
LOGSTASH_SCRIPT_DIR="$SCRIPT_DIR"

# 导入统一部署模板
source "$PROJECT_ROOT/../../../utils/unified-deployment-template.sh"

# 恢复 Logstash 脚本的目录路径
SCRIPT_DIR="$LOGSTASH_SCRIPT_DIR"

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

LOGSTASH_CONFIG_FILE="$SCRIPT_DIR/deploy-logstash.conf"
if [[ -f "$LOGSTASH_CONFIG_FILE" ]]; then
    source "$LOGSTASH_CONFIG_FILE"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
    
    log_info "已加载 Logstash 配置文件: $LOGSTASH_CONFIG_FILE"
else
    log_error "缺少 Logstash 配置文件: $LOGSTASH_CONFIG_FILE"
    exit 1
fi

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="data-platform-dev"
DEFAULT_ENVIRONMENT="development"

# Logstash 资源目录（固定路径）
LOGSTASH_CHART_DIR="$SCRIPT_DIR/../resources/logstash"
LOGSTASH_CUSTOM_VALUES_DIR="$SCRIPT_DIR/../resources/custom-values"

# 检查命名空间是否存在
check_namespace() {
    local namespace="$1"
    
    # 确保 Kubernetes 连接已建立
    if ! setup_kubectl_environment; then
        log_error "❌ 无法建立 Kubernetes 连接"
        return 1
    fi
    
    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
        log_success "✅ 命名空间 $namespace 已存在"
        return 0
    else
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
    fi
}

# 定义 Logstash 所需镜像（保留给镜像检查设计使用）
define_required_images() {
    local environment="$1"
    
    case "$environment" in
        "development"|"dev")
            echo "logstash:$LOGSTASH_IMAGE_VERSION|true"
            ;;
        "production"|"prod")
            echo "logstash:$LOGSTASH_IMAGE_VERSION|true"
            ;;
        *)
            echo "logstash:$LOGSTASH_IMAGE_VERSION|true"
            ;;
    esac
}

# 使用统一模板的通用按需推送 helper，将 Logstash 组件镜像推送到 Harbor
push_logstash_images_to_harbor() {
    push_component_images_to_harbor "logstash"
}

# 执行 Logstash 部署
execute_logstash_deployment() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始执行 Logstash 部署..."
    log_info "项目: $project_id"
    log_info "命名空间: $namespace"
    log_info "环境: $environment"
    log_info "离线模式: $LOGSTASH_FORCE_OFFLINE"
    
    # 检查 Chart 目录是否存在
    if [[ ! -d "$LOGSTASH_CHART_DIR" ]]; then
        log_error "Logstash Chart 目录不存在: $LOGSTASH_CHART_DIR"
        return 1
    fi
    
    # 构建 values 文件路径
    # 支持环境名称映射：development -> dev, production -> prod
    local env_file_name="${environment}"
    case "${environment}" in
        "development"|"dev")
            env_file_name="dev"
            ;;
        "production"|"prod")
            env_file_name="prod"
            ;;
    esac
    
    local values_file="$LOGSTASH_CUSTOM_VALUES_DIR/${env_file_name}-values.yaml"
    if [[ ! -f "$values_file" ]]; then
        log_warn "环境配置文件不存在: $values_file，使用默认配置"
        values_file=""
    else
        log_info "使用环境配置文件: $values_file"
    fi
    
    # 构建 Helm 命令
    local release_name="logstash-$project_id"
    local helm_cmd="helm upgrade --install $release_name $LOGSTASH_CHART_DIR"
    helm_cmd="$helm_cmd --namespace $namespace"
    helm_cmd="$helm_cmd --set global.projectId=$project_id"
    helm_cmd="$helm_cmd --set global.namespace=$namespace"
    helm_cmd="$helm_cmd --set global.environment=$environment"
    
    # 使用 Harbor 时覆盖镜像，避免从 docker.io 拉取
    if [[ -n "${LOGSTASH_IMAGE_REGISTRY:-}" ]] && [[ -n "${LOGSTASH_IMAGE_PROJECT:-}" ]]; then
        helm_cmd="$helm_cmd --set global.imageRegistry=$LOGSTASH_IMAGE_REGISTRY"
        helm_cmd="$helm_cmd --set image.registry=$LOGSTASH_IMAGE_REGISTRY"
        helm_cmd="$helm_cmd --set image.repository=$LOGSTASH_IMAGE_PROJECT/logstash"
        helm_cmd="$helm_cmd --set image.tag=${LOGSTASH_IMAGE_VERSION:-9.1.2-debian-12-r0}"
        helm_cmd="$helm_cmd --set volumePermissions.image.registry=$LOGSTASH_IMAGE_REGISTRY"
        helm_cmd="$helm_cmd --set volumePermissions.image.repository=$LOGSTASH_IMAGE_PROJECT/os-shell"
        helm_cmd="$helm_cmd --set volumePermissions.image.tag=${LOGSTASH_OS_SHELL_IMAGE_VERSION:-12-debian-12-r51}"
        log_info "使用 Harbor 镜像: $LOGSTASH_IMAGE_REGISTRY/$LOGSTASH_IMAGE_PROJECT/logstash:${LOGSTASH_IMAGE_VERSION:-9.1.2-debian-12-r0}"
    fi
    
    if [[ -n "$values_file" ]]; then
        helm_cmd="$helm_cmd --values $values_file"
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        helm_cmd="$helm_cmd --dry-run"
        log_info "执行 Logstash 部署（试运行模式）..."
    else
        log_info "执行 Logstash 部署..."
    fi
    
    # 执行部署
    if eval "$helm_cmd"; then
        if [[ "$dry_run" == "true" ]]; then
            log_success "✅ Logstash 部署试运行完成"
        else
            log_success "✅ Logstash 部署完成"
        fi
        return 0
    else
        log_error "❌ Logstash 部署失败"
        return 1
    fi
}

# 检查 Logstash 状态
check_logstash_status() {
    local project_id="$1"
    local namespace="$2"
    local release_name="logstash-$project_id"
    local label_selector="app.kubernetes.io/instance=$release_name"
    
    log_info "检查 Logstash 部署状态..."
    
    # 确保 Kubernetes 连接已建立（子组件部署后可能已断开）
    if ! setup_kubectl_environment; then
        log_error "❌ 无法建立 Kubernetes 连接"
        return 1
    fi
    
    # 检查 Helm Release
    if helm list -n "$namespace" | grep -q "$release_name"; then
        log_success "✅ Logstash Helm Release 存在"
    else
        log_error "❌ Logstash Helm Release 不存在"
        return 1
    fi
    
    # 检查 Pod 状态（稳健处理空输出与非数字情况）
    local pods_info
    pods_info=$(kubectl get pods -n "$namespace" -l "$label_selector" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}' 2>/dev/null || echo "")
    
    if [[ -z "$pods_info" ]]; then
        log_warn "⚠️  未找到 Logstash Pod（可能正在创建中）"
        # 兼容性兜底：尝试使用 chart name 查找
        pods_info=$(kubectl get pods -n "$namespace" -l app.kubernetes.io/name=logstash -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}' 2>/dev/null || echo "")
        if [[ -z "$pods_info" ]]; then
            log_error "❌ Logstash Pod 不存在"
            return 1
        fi
    fi
    
    # 显示所有 Pod 状态
    log_info "Logstash Pod 状态："
    echo "$pods_info" | while IFS=$'\t' read -r pod_name pod_phase; do
        if [[ -n "$pod_name" ]]; then
            log_info "  - $pod_name: $pod_phase"
        fi
    done
    
    # 统计 Running 状态的 Pod
    local pods_running
    pods_running=$(echo "$pods_info" | awk -F'\t' '$2 == "Running" {count++} END {print count+0}' || echo "0")
    pods_running=$((pods_running + 0))
    
    # 统计所有 Pod 数量
    local pods_total
    pods_total=$(echo "$pods_info" | grep -c '^[^[:space:]]' || echo "0")
    pods_total=$((pods_total + 0))
    
    if [[ $pods_running -gt 0 ]]; then
        log_success "✅ Logstash Pod 运行正常 (${pods_running}/${pods_total} 个运行中)"
    elif [[ $pods_total -gt 0 ]]; then
        log_warn "⚠️  Logstash Pod 存在但未运行 (${pods_total} 个 Pod，0 个运行中)"
        log_info "请等待 Pod 启动或检查 Pod 状态："
        log_info "  kubectl get pods -n $namespace -l app.kubernetes.io/instance=$release_name"
        log_info "  kubectl describe pods -n $namespace -l app.kubernetes.io/instance=$release_name"
        # 不返回错误，因为 Pod 可能正在启动中
        return 0
    else
        log_error "❌ Logstash Pod 不存在"
        return 1
    fi
    
    # 测试 Logstash 连接
    test_logstash_connection "$project_id" "$namespace"
}

# 测试 Logstash 连接
test_logstash_connection() {
    local project_id="$1"
    local namespace="$2"
    local release_name="logstash-$project_id"
    local label_selector="app.kubernetes.io/instance=$release_name"
    
    log_info "测试 Logstash 连接..."
    
    # 获取 Logstash 服务信息
    local service_name
    service_name=$(kubectl get svc -n "$namespace" -l "$label_selector" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -z "$service_name" ]]; then
        log_error "❌ 未找到 Logstash 服务"
        return 1
    fi
    
    # 测试连接（使用 kubectl port-forward 或直接连接）
    log_info "Logstash 服务: $service_name"
    log_success "✅ Logstash 连接测试完成"
}

# 递归部署子组件（中间件 / Ingress）
deploy_sub_components() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"

    log_info "开始部署 Logstash 子组件..."

    local sub_components=(
        "logstash_middleware:${middleware_enabled:-false}:${middleware_priority:-1000}:Logstash 中间件:$SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh"
        "logstash_ingress:${ingress_enabled:-false}:${ingress_priority:-100}:Logstash Web 路由:$SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh"
    )

    IFS=$'\n' sub_components=($(sort -t: -k3 -nr <<<"${sub_components[*]}")); unset IFS

    for component_info in "${sub_components[@]}"; do
        IFS=':' read -r name enabled priority description script_path <<< "$component_info"
        if [[ "$enabled" == "true" ]]; then
            log_info "部署 $description (优先级: $priority)..."
            if [[ -f "$script_path" ]]; then
                if [[ "$name" == "logstash_ingress" ]]; then
                    bash "$script_path" deploy "$project_id" "$namespace" "$environment" || return 1
                else
                    bash "$script_path" deploy "$project_id" "$namespace" "$environment" "$dry_run" || return 1
                fi
            else
                log_error "❌ $description 脚本不存在: $script_path"; return 1
            fi
        fi
    done

    log_success "✅ Logstash 子组件部署完成"
    return 0
}

# 显示 Logstash 连接信息
show_logstash_connection_info() {
    local project_id="$1"
    local namespace="$2"
    
    # 获取配置变量（使用默认值避免未定义变量错误）
    local unified_host="${LOGSTASH_UNIFIED_HOST:-www.sunmoonai.com}"
    local release_name="logstash-$project_id"
    local label_selector="app.kubernetes.io/instance=$release_name"
    local service_name
    service_name=$(kubectl get svc -n "$namespace" -l "$label_selector" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "$release_name")
    
    # 尝试从 Service 获取端口信息
    local service_port
    service_port=$(kubectl get svc -n "$namespace" "$service_name" -o jsonpath='{.spec.ports[?(@.name=="http")].port}' 2>/dev/null || echo "8080")
    service_port="${service_port:-8080}"
    
    echo ""
    echo "=== Logstash 连接信息 ==="
    echo "命名空间: $namespace"
    echo "服务名称: $service_name"
    echo "统一域名: $unified_host"
    echo "服务端口: $service_port"
    echo ""
    echo "=== 使用说明 ==="
    echo "1. 通过 Ingress 访问（推荐）:"
    echo "   curl http://$unified_host/logstash"
    echo ""
    echo "2. 通过 Port Forward 访问:"
    echo "   kubectl port-forward -n $namespace svc/$service_name ${service_port}:${service_port}"
    echo "   curl http://localhost:${service_port}"
    echo ""
    echo "3. 查看服务状态:"
    echo "   kubectl get pods,svc,ingressroute -n $namespace -l app.kubernetes.io/instance=$release_name"
    echo ""
}

# 创建 Logstash 密钥（如果需要）
create_logstash_secrets_if_needed() {
    local namespace="$1"
    
    log_info "检查 Logstash 密钥..."
    
    # 统一密管负责创建；仅提示
    if kubectl get secret "$LOGSTASH_AUTH_SECRET_NAME" -n "$namespace" >/dev/null 2>&1; then
        log_success "✅ Logstash 密钥已存在: $LOGSTASH_AUTH_SECRET_NAME"
    else
        log_info "跳过创建 Logstash 密钥（由统一密管管理）：$LOGSTASH_AUTH_SECRET_NAME"
    fi
}

# 部署 Logstash Secrets（使用新的 Secret 管理系统）
deploy_logstash_secrets() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="${4:-false}"
    
    log_info "🚀 部署 Logstash Secrets..."
    
    local secrets_script="$SCRIPT_DIR/secrets/deploy-secrets-all/deploy-secrets-all.sh"
    
    if [[ ! -f "$secrets_script" ]]; then
        log_warn "⚠️  Logstash Secrets 部署脚本不存在: $secrets_script"
        log_warn "跳过 Secrets 部署，请手动部署或检查脚本路径"
        return 0
    fi
    
    # 检查是否启用 Secrets 部署（默认启用）
    if [[ "${secrets_enabled:-true}" == "true" ]]; then
        if bash "$secrets_script" "$project_id" "$namespace" "$environment" "$dry_run"; then
            log_success "✅ Logstash Secrets 部署成功"
            return 0
        else
            log_error "❌ Logstash Secrets 部署失败"
            return 1
        fi
    else
        log_info "跳过 Logstash Secrets 部署（secrets_enabled=false）"
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
            log_info "开始部署 Logstash..."
            check_namespace "$namespace"
            # 在部署前按需推送 Logstash 组件镜像到 Harbor（Kind 使用 push-to-harbor，远程使用 registry-push-management）
            push_logstash_images_to_harbor || log_warn "[images] Logstash 镜像推送阶段出现警告，可稍后单独检查 Harbor 镜像状态"
            # 部署 Secrets（在主部署之前）
            if ! deploy_logstash_secrets "$project_id" "$namespace" "$environment" "$dry_run"; then
                log_error "❌ Logstash Secrets 部署失败，终止主部署"
                exit 1
            fi
            execute_logstash_deployment "$project_id" "$namespace" "$environment" "$dry_run"
            # 子组件：中间件与 Web Ingress
            if deploy_sub_components "$project_id" "$namespace" "$environment" "$dry_run"; then
                check_logstash_status "$project_id" "$namespace" || true
                show_logstash_connection_info "$project_id" "$namespace"
            else
                log_error "❌ Logstash 子组件部署失败"
                exit 1
            fi
            ;;
        "upgrade")
            log_info "开始升级 Logstash..."
            check_namespace "$namespace"
            execute_logstash_deployment "$project_id" "$namespace" "$environment" "$dry_run"
            check_logstash_status "$project_id" "$namespace"
            ;;
        "uninstall")
            log_info "开始卸载 Logstash..."
            # 卸载子组件（禁用自动清理，保持连接以便后续 helm uninstall）
            log_info "卸载 Logstash 子组件..."
            local sub_components=(
                "logstash_middleware:${middleware_enabled:-false}:${middleware_priority:-1000}:Logstash 中间件:$SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh"
                "logstash_ingress:${ingress_enabled:-false}:${ingress_priority:-100}:Logstash Web 路由:$SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh"
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
            helm uninstall "logstash-$project_id" -n "$namespace" --wait || true
            log_success "✅ Logstash 卸载完成"
            ;;
        "clean")
            log_info "开始清理 Logstash..."
            helm uninstall "logstash-$project_id" -n "$namespace" || true
            kubectl delete pvc -n "$namespace" -l app.kubernetes.io/instance="logstash-$project_id" || true
            log_success "✅ Logstash 清理完成"
            ;;
        "status")
            check_logstash_status "$project_id" "$namespace"
            show_logstash_connection_info "$project_id" "$namespace"
            ;;
        "logs")
            log_info "显示 Logstash 日志..."
            kubectl logs -n "$namespace" -l app.kubernetes.io/instance="logstash-$project_id" --tail=100
            ;;
        "connect")
            show_logstash_connection_info "$project_id" "$namespace"
            ;;
        *)
            echo "用法: $0 <action> [project_id] [namespace] [environment] [dry_run]"
            echo ""
            echo "操作:"
            echo "  deploy     部署 Logstash（默认）"
            echo "  upgrade    升级 Logstash"
            echo "  uninstall  卸载 Logstash"
            echo "  clean      清理 Logstash（包括数据）"
            echo "  status     检查 Logstash 状态"
            echo "  logs       显示 Logstash 日志"
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
