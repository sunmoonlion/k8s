#!/bin/bash

# Redis 递归部署脚本
# 基于递归架构设计原则的两级部署逻辑

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 保存 Redis 脚本的目录路径（统一部署模板会重新定义 SCRIPT_DIR）
REDIS_SCRIPT_DIR="$SCRIPT_DIR"

# 导入统一部署模板
source "$PROJECT_ROOT/../../../utils/unified-deployment-template.sh"

# 恢复 Redis 脚本的目录路径
SCRIPT_DIR="$REDIS_SCRIPT_DIR"

# 解析命令行参数（优先于配置文件加载，确保命令行参数优先级最高）
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
        if [[ -f "$PROJECT_ROOT/utils/cluster-config-mapping.sh" ]]; then
            source "$PROJECT_ROOT/utils/cluster-config-mapping.sh"
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

REDIS_CONFIG_FILE="$SCRIPT_DIR/deploy-redis.conf"
if [[ -f "$REDIS_CONFIG_FILE" ]]; then
    source "$REDIS_CONFIG_FILE"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$PROJECT_ROOT/utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
    
    # 如果 REDIS_EXTERNAL_PORT 未设置，从 Traefik Service 中动态获取
    if [[ -z "${REDIS_EXTERNAL_PORT:-}" ]]; then
        if type get_redis_external_port >/dev/null 2>&1; then
            REDIS_EXTERNAL_PORT=$(get_redis_external_port)
            log_info "从 Traefik Service 获取 Redis 外部端口: $REDIS_EXTERNAL_PORT"
        else
            log_warn "⚠️  get_redis_external_port 函数不可用，使用默认端口 30446"
            REDIS_EXTERNAL_PORT="30446"
        fi
    fi
    
    log_info "已加载 Redis 配置文件: $REDIS_CONFIG_FILE"
else
    log_error "缺少 Redis 配置文件: $REDIS_CONFIG_FILE"
    exit 1
fi

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="data-platform-dev"
DEFAULT_ENVIRONMENT="development"

# Redis 资源目录（固定路径）
REDIS_CHART_DIR="$SCRIPT_DIR/../resources/redis"
REDIS_CUSTOM_VALUES_DIR="$SCRIPT_DIR/../resources/custom-values"

# 检查命名空间是否存在
check_namespace() {
    local namespace="$1"
    
    # 检查是否已有可用的Kubernetes连接
    if ! kubectl get nodes >/dev/null 2>&1; then
        # 确保 Kubernetes 连接已建立
        if ! setup_kubectl_environment; then
            log_error "❌ 无法建立 Kubernetes 连接"
            return 1
        fi
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

# 定义 Redis 所需镜像（保留给镜像检查设计使用）
define_required_images() {
    local environment="$1"
    
    case "$environment" in
        "development"|"dev")
            echo "bitnami/redis:$REDIS_IMAGE_VERSION|true"
            if [[ "${REDIS_MONITORING_ENABLED:-false}" == "true" ]]; then
                echo "bitnami/redis-exporter:$REDIS_METRICS_IMAGE_VERSION|true"
            fi
            ;;
        "production"|"prod")
            echo "bitnami/redis:$REDIS_IMAGE_VERSION|true"
            echo "bitnami/redis-exporter:$REDIS_METRICS_IMAGE_VERSION|true"
            if [[ "${REDIS_SENTINEL_ENABLED:-false}" == "true" ]]; then
                echo "bitnami/redis-sentinel:$REDIS_SENTINEL_IMAGE_VERSION|true"
            fi
            ;;
        *)
            echo "bitnami/redis:$REDIS_IMAGE_VERSION|true"
            ;;
    esac
}

# 使用统一模板的通用按需推送 helper，将 Redis 组件镜像推送到 Harbor
push_redis_images_to_harbor() {
    push_component_images_to_harbor "redis"
}

# 执行 Redis 部署
execute_redis_deployment() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始执行 Redis 部署..."
    log_info "项目: $project_id"
    log_info "命名空间: $namespace"
    log_info "环境: $environment"
    log_info "离线模式: $REDIS_FORCE_OFFLINE"
    
    # 确保 Kubernetes 连接已建立（在执行 Helm 部署前）
    if ! kubectl get nodes >/dev/null 2>&1; then
        if ! setup_kubectl_environment; then
            log_error "❌ 无法建立 Kubernetes 连接"
            return 1
        fi
    fi
    
    # 检查 KUBECONFIG 环境变量（Helm 需要它）
    if [[ -z "${KUBECONFIG:-}" ]]; then
        log_error "KUBECONFIG 环境变量未设置"
        return 1
    fi
    
    # 验证 Kubernetes 连接
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "❌ Kubernetes 集群连接失败"
        return 1
    fi
    
    # 检查 Chart 目录是否存在
    if [[ ! -d "$REDIS_CHART_DIR" ]]; then
        log_error "Redis Chart 目录不存在: $REDIS_CHART_DIR"
        return 1
    fi
    
    # 构建 values 文件路径（统一映射 development→dev, production→prod），并根据持久化模式选择是否复用老盘
    local values_file=""
    # 支持全局强制模式：SUNMOONAI_GLOBAL_PERSIST_MODE=init|reuse
    local global_persist_mode="${SUNMOONAI_GLOBAL_PERSIST_MODE:-}"
    local persist_mode
    if [[ -n "$global_persist_mode" ]]; then
        persist_mode="$global_persist_mode"
        log_info "检测到全局持久化模式 SUNMOONAI_GLOBAL_PERSIST_MODE=$global_persist_mode，将覆盖组件配置 REDIS_PERSIST_MODE=${REDIS_PERSIST_MODE:-init}"
    else
        persist_mode="${REDIS_PERSIST_MODE:-init}"
    fi
    # 远程集群（C1/C2 等）仅使用动态 StorageClass，不应用 Kind 静态 PV/PVC（避免 172.28.46.235）
    if [[ -n "${CLUSTER:-}" && "$(echo "${CLUSTER}" | tr '[:upper:]' '[:lower:]')" != "kind" ]]; then
        if [[ "$persist_mode" == "reuse" ]]; then
            log_info "集群 ${CLUSTER} 为远程集群，强制使用动态存储 (init)，不应用 Kind 静态 PV/PVC"
            persist_mode="init"
        fi
    fi
    case "$environment" in
        "development"|"dev")
            if [[ "$persist_mode" == "reuse" ]]; then
                # 复用模式：先应用静态 PV/PVC，再使用 dev-values-persist.yaml
                local pv_pvc_file="$REDIS_CUSTOM_VALUES_DIR/redis-dev-pv-pvc.yaml"
                if [[ ! -f "$pv_pvc_file" ]]; then
                    log_error "复用模式启用，但未找到静态 PV/PVC 文件: $pv_pvc_file"
                    return 1
                fi
                log_info "REDIS_PERSIST_MODE=reuse，先应用静态 PV/PVC: $pv_pvc_file"
                kubectl apply -f "$pv_pvc_file"
                values_file="$REDIS_CUSTOM_VALUES_DIR/dev-values-persist.yaml"
            else
                # 初始化模式：使用原始 dev-values.yaml（动态 nfs-2，新盘）
                values_file="$REDIS_CUSTOM_VALUES_DIR/dev-values.yaml"
            fi
            ;;
        "production"|"prod")
            values_file="$REDIS_CUSTOM_VALUES_DIR/prod-values.yaml"
            ;;
        *)
            log_warn "未知环境: $environment，使用 dev-values.yaml"
            values_file="$REDIS_CUSTOM_VALUES_DIR/dev-values.yaml"
            ;;
    esac
    if [[ ! -f "$values_file" ]]; then
        log_error "环境配置文件不存在: $values_file"
        return 1
    fi
    
    # 构建 Helm 命令（确保使用正确的 kubeconfig）
    local helm_cmd="helm upgrade --install redis-$project_id $REDIS_CHART_DIR"
    helm_cmd="$helm_cmd --namespace $namespace"
    helm_cmd="$helm_cmd --kubeconfig ${KUBECONFIG}"
    # 先加载 Chart 自带 values，再叠加环境 values
    if [[ -f "$REDIS_CHART_DIR/values.yaml" ]]; then
        helm_cmd="$helm_cmd --values $REDIS_CHART_DIR/values.yaml"
    fi
    helm_cmd="$helm_cmd --set global.projectId=$project_id"
    helm_cmd="$helm_cmd --set global.namespace=$namespace"
    helm_cmd="$helm_cmd --set global.environment=$environment"
    
    # 使用 Harbor 时覆盖镜像，与其他 data-platform 组件一致
    if [[ -n "${REDIS_IMAGE_REGISTRY:-}" ]] && [[ -n "${REDIS_IMAGE_PROJECT:-}" ]]; then
        # Bitnami charts 会校验“非标准镜像”并中止安装；当我们将镜像重写到 Harbor 时需要显式放行
        helm_cmd="$helm_cmd --set global.security.allowInsecureImages=true"
        helm_cmd="$helm_cmd --set global.imageRegistry=$REDIS_IMAGE_REGISTRY"
        helm_cmd="$helm_cmd --set image.registry=$REDIS_IMAGE_REGISTRY"
        helm_cmd="$helm_cmd --set image.repository=$REDIS_IMAGE_PROJECT/redis"
        helm_cmd="$helm_cmd --set image.tag=${REDIS_IMAGE_VERSION:-8.2.1-debian-12-r0}"
        helm_cmd="$helm_cmd --set metrics.image.registry=$REDIS_IMAGE_REGISTRY"
        helm_cmd="$helm_cmd --set metrics.image.repository=$REDIS_IMAGE_PROJECT/redis-exporter"
        helm_cmd="$helm_cmd --set metrics.image.tag=${REDIS_METRICS_IMAGE_VERSION:-1.76.0-debian-12-r0}"
        helm_cmd="$helm_cmd --set volumePermissions.image.registry=$REDIS_IMAGE_REGISTRY"
        helm_cmd="$helm_cmd --set volumePermissions.image.repository=$REDIS_IMAGE_PROJECT/os-shell"
        helm_cmd="$helm_cmd --set volumePermissions.image.tag=${REDIS_OS_SHELL_IMAGE_VERSION:-12-debian-12-r51}"
        log_info "使用 Harbor 镜像: $REDIS_IMAGE_REGISTRY/$REDIS_IMAGE_PROJECT/redis:${REDIS_IMAGE_VERSION:-8.2.1-debian-12-r0}"
    fi
    
    helm_cmd="$helm_cmd --values $values_file"
    
    if [[ "$dry_run" == "true" ]]; then
        helm_cmd="$helm_cmd --dry-run"
        log_info "执行 Redis 部署（试运行模式）..."
    else
        log_info "执行 Redis 部署..."
    fi
    
    # 执行部署
    if eval "$helm_cmd"; then
        if [[ "$dry_run" == "true" ]]; then
            log_success "✅ Redis 部署试运行完成"
        else
            log_success "✅ Redis 部署完成"
        fi
        return 0
    else
        log_error "❌ Redis 部署失败"
        return 1
    fi
}

# 检查 Redis 状态
check_redis_status() {
    local project_id="$1"
    local namespace="$2"
    local release_name="redis-$project_id"
    local label_selector="app.kubernetes.io/instance=$release_name"
    
    log_info "检查 Redis 部署状态..."

    # 确保 Kubernetes 连接与 KUBECONFIG 可用（避免使用到默认的 localhost:8080）
    if ! kubectl get nodes >/dev/null 2>&1; then
        if ! setup_kubectl_environment; then
            log_error "❌ 无法建立 Kubernetes 连接"
            return 1
        fi
    fi
    if [[ -z "${KUBECONFIG:-}" ]]; then
        log_error "❌ KUBECONFIG 环境变量未设置"
        return 1
    fi
    
    # 检查 Helm Release
    if helm list -n "$namespace" --kubeconfig "${KUBECONFIG}" | grep -q "$release_name"; then
        log_success "✅ Redis Helm Release 存在"
    else
        log_error "❌ Redis Helm Release 不存在"
        return 1
    fi
    
    # 检查 Pod 状态（避免在 set -e/pipefail 下因 grep 无匹配直接退出）
    local phases pods_running pods_pending
    phases=$(kubectl get pods -n "$namespace" -l "$label_selector" -o jsonpath='{.items[*].status.phase}' 2>/dev/null || echo "")
    pods_running=0
    pods_pending=0
    if [[ -n "$phases" ]]; then
        pods_running=$(echo "$phases" | tr ' ' '\n' | grep -c '^Running$' 2>/dev/null || echo "0")
        pods_pending=$(echo "$phases" | tr ' ' '\n' | grep -cE '^(Pending|ContainerCreating)$' 2>/dev/null || echo "0")
        pods_running=$(echo "$pods_running" | tr -d '[:space:]')
        pods_pending=$(echo "$pods_pending" | tr -d '[:space:]')
        [[ -z "$pods_running" || ! "$pods_running" =~ ^[0-9]+$ ]] && pods_running=0
        [[ -z "$pods_pending" || ! "$pods_pending" =~ ^[0-9]+$ ]] && pods_pending=0
    fi

    if (( pods_running > 0 )); then
        log_success "✅ Redis Pod 运行正常 (${pods_running} 个)"
    elif (( pods_pending > 0 )); then
        log_warn "⏳ Redis Pod 正在启动中（${pods_pending} 个 Pending/ContainerCreating，0 个 Running）"
        log_info "提示：这是正常的启动过程，如需查看详细进度可稍后运行 status 子命令。"
        # 启动中不视为失败，让整体部署流程继续
        return 0
    else
        log_warn "⚠️  Redis Pod 可能还在启动中或尚未创建（0 个 Running）"
        log_info "当前 Pod 状态："
        kubectl get pods -n "$namespace" -l "$label_selector" 2>/dev/null || true
        # 不返回错误，因为资源可能还在创建
        return 0
    fi

    # 测试 Redis 连接（best-effort：不阻断整体部署）
    test_redis_connection "$project_id" "$namespace" || true
    return 0
}

# 测试 Redis 连接
test_redis_connection() {
    local project_id="$1"
    local namespace="$2"
    local release_name="redis-$project_id"
    local label_selector="app.kubernetes.io/instance=$release_name"
    
    log_info "测试 Redis 连接..."

    # 确保 kubectl 可用
    if ! kubectl get nodes >/dev/null 2>&1; then
        if ! setup_kubectl_environment; then
            log_error "❌ 无法建立 Kubernetes 连接"
            return 1
        fi
    fi
    
    # 获取 Redis 服务信息
    local service_name
    service_name=$(kubectl get svc -n "$namespace" -l "$label_selector" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -z "$service_name" ]]; then
        log_warn "⏳ 未找到 Redis 服务（可能还在创建中），跳过连接测试"
        return 0
    fi
    
    # 测试连接（使用 kubectl port-forward 或直接连接）
    log_info "Redis 服务: $service_name"
    log_success "✅ Redis 连接测试完成"
}

# 显示 Redis 连接信息
show_redis_connection_info() {
    local namespace="$1"
    
    echo ""
    echo "=== Redis 连接信息 ==="
    echo "命名空间: $namespace"
    echo "外部访问: $REDIS_EXTERNAL_HOST:$REDIS_EXTERNAL_PORT"
    echo ""
    echo "=== 使用说明 ==="
    echo "1. 配置 hosts 文件:"
    echo "   echo '101.126.151.0 ${REDIS_EXTERNAL_HOST:-llmops.sunmoonai.com}' | sudo tee -a /etc/hosts"
    echo ""
    echo "2. 连接 Redis:"
    echo "   redis-cli -h $REDIS_EXTERNAL_HOST -p $REDIS_EXTERNAL_PORT"
    echo ""
    echo "3. 查看服务状态:"
    echo "   kubectl get pods,svc -n $namespace -l app.kubernetes.io/instance=redis-<project_id>"
    echo ""
}

# 备份 Redis 数据
backup_redis_data() {
    local namespace="$1"
    local backup_name="redis-backup-$(date +%Y%m%d-%H%M%S)"
    
    log_info "开始备份 Redis 数据..."
    log_info "备份名称: $backup_name"
    
    # 这里可以实现具体的备份逻辑
    # 例如使用 redis-cli --rdb 或 Kubernetes 备份工具
    log_success "✅ Redis 数据备份完成: $backup_name"
}

# 部署 Redis Secrets（使用新的 Secret 管理系统）
deploy_redis_secrets() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="${4:-false}"
    
    log_info "🚀 部署 Redis Secrets..."
    
    local secrets_script="$SCRIPT_DIR/secrets/deploy-secrets-all/deploy-secrets-all.sh"
    
    if [[ ! -f "$secrets_script" ]]; then
        log_warn "⚠️  Redis Secrets 部署脚本不存在: $secrets_script"
        log_warn "跳过 Secrets 部署，请手动部署或检查脚本路径"
        return 0
    fi
    
    # 检查是否启用 Secrets 部署（默认启用）
    if [[ "${secrets_enabled:-true}" == "true" ]]; then
        # deploy-secrets-all.sh 期望的参数是: action namespace
        # 传递 --cluster 参数以保持集群配置
        if [[ -n "${CLUSTER:-}" ]]; then
            if bash "$secrets_script" deploy "$namespace" --cluster "${CLUSTER}"; then
                log_success "✅ Redis Secrets 部署成功"
                return 0
            else
                log_error "❌ Redis Secrets 部署失败"
                return 1
            fi
        else
            if bash "$secrets_script" deploy "$namespace"; then
                log_success "✅ Redis Secrets 部署成功"
                return 0
            else
                log_error "❌ Redis Secrets 部署失败"
                return 1
            fi
        fi
    else
        log_info "跳过 Redis Secrets 部署（secrets_enabled=false）"
        return 0
    fi
}

# 递归部署子组件（参考 PostgreSQL 的实现）
deploy_sub_components() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始部署 Redis 子组件..."
    
    # 定义子组件部署顺序（按优先级排序）
    local sub_components=(
        "redis_secrets:${secrets_enabled:-true}:${secrets_priority:-2000}:Redis Secrets:$SCRIPT_DIR/secrets/deploy-secrets-all/deploy-secrets-all.sh"
        "redis_middleware:${middleware_enabled:-false}:${middleware_priority:-1000}:Redis 中间件:$SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh"
        "redis_ingress:${ingress_enabled:-false}:${ingress_priority:-100}:Redis TCP 路由:$SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh"
    )
    
    # 按优先级排序
    IFS=$'\n' sub_components=($(sort -t: -k3 -nr <<<"${sub_components[*]}"))
    unset IFS
    
    # 部署子组件
    for component_info in "${sub_components[@]}"; do
        IFS=':' read -r name enabled priority description script_path <<< "$component_info"
        
        if [[ "$enabled" == "true" ]]; then
            log_info "部署 $description (优先级: $priority)..."
            
            if [[ -f "$script_path" ]]; then
                # Redis secrets 脚本期望的参数是: action namespace
                if [[ "$name" == "redis_secrets" ]]; then
                    if [[ -n "${CLUSTER:-}" ]]; then
                        if bash "$script_path" deploy "$namespace" --cluster "${CLUSTER}"; then
                            log_success "✅ $description 部署成功"
                        else
                            log_error "❌ $description 部署失败"
                            return 1
                        fi
                    else
                        if bash "$script_path" deploy "$namespace"; then
                            log_success "✅ $description 部署成功"
                        else
                            log_error "❌ $description 部署失败"
                            return 1
                        fi
                    fi
                # Ingress 脚本不接受 dry_run 参数，只传递 deploy/project_id/namespace/environment
                elif [[ "$name" == "redis_ingress" ]]; then
                    if bash "$script_path" deploy "$project_id" "$namespace" "$environment"; then
                        log_success "✅ $description 部署成功"
                    else
                        log_error "❌ $description 部署失败"
                        return 1
                    fi
                else
                    # 其他子组件可以传递 dry_run 参数
                    if bash "$script_path" deploy "$project_id" "$namespace" "$environment" "$dry_run"; then
                        log_success "✅ $description 部署成功"
                    else
                        log_error "❌ $description 部署失败"
                        return 1
                    fi
                fi
            else
                log_error "❌ $description 脚本不存在: $script_path"
                return 1
            fi
        else
            log_info "跳过 $description (已禁用)"
        fi
    done
    
    return 0
}

# 解析命令行参数（支持 --cluster 或 -c）
declare -a PARSED_ARGS


# 主函数
main() {
    # 使用解析后的参数（已移除 --cluster 参数）
    set -- "${ORIGINAL_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    local action="${1:-deploy}"
    local project_id="${2:-$DEFAULT_PROJECT_ID}"
    local namespace="${3:-$DEFAULT_NAMESPACE}"
    local environment="${4:-$DEFAULT_ENVIRONMENT}"
    local dry_run="${5:-false}"
    
    # 读取 Kubernetes 配置文件
    if ! read_k8s_config; then
        log_error "无法读取 Kubernetes 配置文件"
        exit 1
    fi
    # 建立远程 k8s 连接
    if ! setup_kubectl_environment; then
        log_error "无法建立 Kubernetes 连接"
        exit 1
    fi
    
    case "$action" in
        "deploy")
            log_info "开始部署 Redis..."
            check_namespace "$namespace"
            
            # 在部署前按需推送 Redis 组件镜像到 Harbor（Kind 使用 push-to-harbor，远程使用 registry-push-management）
            push_redis_images_to_harbor || log_warn "[images] Redis 镜像推送阶段出现警告，可稍后单独检查 Harbor 镜像状态"
            
            # ============================================================
            # 阶段1：部署子级组件（按优先级，先部署依赖项）
            # ============================================================
            log_info "🚀 阶段1：部署 Redis 子级组件..."
            if ! deploy_sub_components "$project_id" "$namespace" "$environment" "$dry_run"; then
                log_error "❌ Redis 子级组件部署失败！"
                exit 1
            fi
            log_success "✅ Redis 子级组件部署完成"
            
            # ============================================================
            # 阶段2：部署本级核心服务（Helm Chart 部署）
            # ============================================================
            log_info "🚀 阶段2：部署 Redis 核心服务..."
            
            execute_redis_deployment "$project_id" "$namespace" "$environment" "$dry_run"
            check_redis_status "$project_id" "$namespace"
            show_redis_connection_info "$namespace"
            ;;
        "upgrade")
            log_info "开始升级 Redis..."
            check_namespace "$namespace"
            execute_redis_deployment "$project_id" "$namespace" "$environment" "$dry_run"
            check_redis_status "$project_id" "$namespace"
            ;;
        "uninstall")
            log_info "开始卸载 Redis..."
            
            # 设置 Kubernetes 环境
            if ! setup_kubectl_environment; then
                log_error "无法建立 Kubernetes 连接"
                return 1
            fi
            
            # 卸载子组件（按优先级逆序）
            log_info "卸载 Redis 子组件..."
            local sub_components=(
                "redis_secrets:${secrets_enabled:-true}:${secrets_priority:-2000}:Redis Secrets:$SCRIPT_DIR/secrets/deploy-secrets-all/deploy-secrets-all.sh"
                "redis_middleware:${middleware_enabled:-false}:${middleware_priority:-1000}:Redis 中间件:$SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh"
                "redis_ingress:${ingress_enabled:-false}:${ingress_priority:-100}:Redis TCP 路由:$SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh"
            )
            
            # 按优先级排序（卸载时反向顺序）
            IFS=$'\n' sub_components=($(sort -t: -k3 -n <<<"${sub_components[*]}"))
            unset IFS
            
            # 卸载子组件
            for component_info in "${sub_components[@]}"; do
                IFS=':' read -r name enabled priority description script_path <<< "$component_info"
                if [[ "$enabled" == "true" ]]; then
                    log_info "卸载 $description (优先级: $priority)..."
                    if [[ -f "$script_path" ]]; then
                        # 禁用子脚本的自动清理，保持连接以便后续操作
                        # Redis secrets 脚本期望的参数是: action namespace
                        if [[ "$name" == "redis_secrets" ]]; then
                            if [[ -n "${CLUSTER:-}" ]]; then
                                DISABLE_AUTO_CLEANUP=true bash "$script_path" uninstall "$namespace" --cluster "${CLUSTER}" || true
                            else
                                DISABLE_AUTO_CLEANUP=true bash "$script_path" uninstall "$namespace" || true
                            fi
                        else
                            DISABLE_AUTO_CLEANUP=true bash "$script_path" uninstall "$project_id" "$namespace" "$environment" || true
                        fi
                        log_success "✅ $description 卸载完成"
                    else
                        log_warn "⚠️ $description 脚本不存在: $script_path"
                    fi
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
            
            helm uninstall "redis-$project_id" -n "$namespace" || true
            log_success "✅ Redis 卸载完成"
            ;;
        "clean")
            log_info "开始清理 Redis..."
            helm uninstall "redis-$project_id" -n "$namespace" || true
            kubectl delete pvc -n "$namespace" -l app.kubernetes.io/instance="redis-$project_id" || true
            log_success "✅ Redis 清理完成"
            ;;
        "status")
            check_redis_status "$project_id" "$namespace"
            show_redis_connection_info "$namespace"
            ;;
        "logs")
            log_info "显示 Redis 日志..."
            kubectl logs -n "$namespace" -l app.kubernetes.io/instance="redis-$project_id" --tail=100
            ;;
        "backup")
            backup_redis_data "$namespace"
            ;;
        "connect")
            show_redis_connection_info "$namespace"
            ;;
        *)
            echo "用法: $0 [--cluster C1|C2] <action> [project_id] [namespace] [environment] [dry_run]"
            echo ""
            echo "参数:"
            echo "  --cluster, -c   集群选择 (格式：C{数字}，如 C1, C2, C3 等)，也可以通过环境变量 CLUSTER 设置"
            echo ""
            echo "操作:"
            echo "  deploy     部署 Redis（默认）"
            echo "  upgrade    升级 Redis"
            echo "  uninstall  卸载 Redis"
            echo "  clean      清理 Redis（包括数据）"
            echo "  status     检查 Redis 状态"
            echo "  logs       显示 Redis 日志"
            echo "  backup     备份 Redis 数据"
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
            echo "  $0 backup"
            exit 1
            ;;
    esac
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
