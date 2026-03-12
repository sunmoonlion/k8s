#!/bin/bash

# MongoDB 递归部署脚本
# 基于递归架构设计原则的两级部署逻辑

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 保存 MongoDB 脚本的目录路径（统一部署模板会重新定义 SCRIPT_DIR）
MONGODB_SCRIPT_DIR="$SCRIPT_DIR"

# 导入统一部署模板
source "$PROJECT_ROOT/../../../utils/unified-deployment-template.sh"

# 恢复 MongoDB 脚本的目录路径
SCRIPT_DIR="$MONGODB_SCRIPT_DIR"

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

MONGODB_CONFIG_FILE="$SCRIPT_DIR/deploy-mongodb.conf"
if [[ -f "$MONGODB_CONFIG_FILE" ]]; then
    source "$MONGODB_CONFIG_FILE"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$PROJECT_ROOT/utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
    
    # 如果 MONGODB_EXTERNAL_PORT 未设置，从 Traefik Service 中动态获取
    if [[ -z "${MONGODB_EXTERNAL_PORT:-}" ]]; then
        if type get_mongodb_external_port >/dev/null 2>&1; then
            MONGODB_EXTERNAL_PORT=$(get_mongodb_external_port)
            log_info "从 Traefik Service 获取 MongoDB 外部端口: $MONGODB_EXTERNAL_PORT"
        else
            log_warn "⚠️  get_mongodb_external_port 函数不可用，使用默认端口 30445"
            MONGODB_EXTERNAL_PORT="30445"
        fi
    fi
    
    log_info "已加载 MongoDB 配置文件: $MONGODB_CONFIG_FILE"
else
    log_error "缺少 MongoDB 配置文件: $MONGODB_CONFIG_FILE"
    exit 1
fi

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="data-platform-dev"
DEFAULT_ENVIRONMENT="development"

# MongoDB 资源目录（固定路径）
MONGODB_CHART_DIR="$SCRIPT_DIR/../resources/mongodb"
MONGODB_CUSTOM_VALUES_DIR="$SCRIPT_DIR/../resources/custom-values"

# 检查命名空间是否存在，如果不存在则创建
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
        log_warn "⚠️  命名空间 $namespace 不存在，尝试创建..."
        if kubectl create namespace "$namespace" 2>/dev/null; then
            log_success "✅ 命名空间 $namespace 已创建"
            return 0
        else
            log_error "❌ 无法创建命名空间 $namespace"
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
    fi
}

# 定义 MongoDB 所需镜像（保留给镜像检查设计使用）
define_required_images() {
    local environment="$1"
    
    case "$environment" in
        "development"|"dev")
            echo "bitnami/mongodb:$MONGODB_IMAGE_VERSION|true"
            if [[ "${MONGODB_MONITORING_ENABLED:-false}" == "true" ]]; then
                echo "bitnami/mongodb-exporter:$MONGODB_METRICS_IMAGE_VERSION|true"
            fi
            ;;
        "production"|"prod")
            echo "bitnami/mongodb:$MONGODB_IMAGE_VERSION|true"
            echo "bitnami/mongodb-exporter:$MONGODB_METRICS_IMAGE_VERSION|true"
            if [[ "${MONGODB_BACKUP_ENABLED:-false}" == "true" ]]; then
                echo "bitnami/mongodb:$MONGODB_IMAGE_VERSION|true"
            fi
            ;;
        *)
            echo "bitnami/mongodb:$MONGODB_IMAGE_VERSION|true"
            ;;
    esac
}

# 使用统一模板的通用按需推送 helper，将 MongoDB 组件镜像推送到 Harbor
push_mongodb_images_to_harbor() {
    push_component_images_to_harbor "mongodb"
}

# 执行 MongoDB 部署
execute_mongodb_deployment() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始执行 MongoDB 部署..."
    log_info "项目: $project_id"
    log_info "命名空间: $namespace"
    log_info "环境: $environment"
    log_info "离线模式: $MONGODB_FORCE_OFFLINE"
    
    # 检查 Chart 目录是否存在
    if [[ ! -d "$MONGODB_CHART_DIR" ]]; then
        log_error "MongoDB Chart 目录不存在: $MONGODB_CHART_DIR"
        return 1
    fi
    
    # 构建 values 文件路径（统一映射 development→dev, production→prod），并根据持久化模式选择是否复用老盘
    local values_file=""
    # 支持全局强制模式：SUNMOONAI_GLOBAL_PERSIST_MODE=init|reuse
    local global_persist_mode="${SUNMOONAI_GLOBAL_PERSIST_MODE:-}"
    local persist_mode
    if [[ -n "$global_persist_mode" ]]; then
        persist_mode="$global_persist_mode"
        log_info "检测到全局持久化模式 SUNMOONAI_GLOBAL_PERSIST_MODE=$global_persist_mode，将覆盖组件配置 MONGODB_PERSIST_MODE=${MONGODB_PERSIST_MODE:-init}"
    else
        persist_mode="${MONGODB_PERSIST_MODE:-init}"
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
                local pv_pvc_file="$MONGODB_CUSTOM_VALUES_DIR/mongodb-dev-pv-pvc.yaml"
                if [[ ! -f "$pv_pvc_file" ]]; then
                    log_error "复用模式启用，但未找到静态 PV/PVC 文件: $pv_pvc_file"
                    return 1
                fi
                log_info "MONGODB_PERSIST_MODE=reuse，先应用静态 PV/PVC: $pv_pvc_file"
                kubectl apply -f "$pv_pvc_file"
                values_file="$MONGODB_CUSTOM_VALUES_DIR/dev-values-persist.yaml"
            else
                # 初始化模式：使用原始 dev-values.yaml（动态 nfs-2，新盘）
                values_file="$MONGODB_CUSTOM_VALUES_DIR/dev-values.yaml"
            fi
            ;;
        "production"|"prod")
            values_file="$MONGODB_CUSTOM_VALUES_DIR/prod-values.yaml"
            ;;
        *)
            log_warn "未知环境: $environment，使用 dev-values.yaml"
            values_file="$MONGODB_CUSTOM_VALUES_DIR/dev-values.yaml"
            ;;
    esac
    if [[ ! -f "$values_file" ]]; then
        log_error "环境配置文件不存在: $values_file"
        return 1
    fi
    
    # 注意：StorageClass 与 Secret 键名需通过 dev-values.yaml 与密管系统配置保证正确；脚本不做自修复

    # 构建 Helm 命令
    local helm_cmd="helm upgrade --install mongodb-$project_id $MONGODB_CHART_DIR"
    helm_cmd="$helm_cmd --namespace $namespace"
    # 先加载 Chart 自带 values，再叠加环境 values
    if [[ -f "$MONGODB_CHART_DIR/values.yaml" ]]; then
        helm_cmd="$helm_cmd --values $MONGODB_CHART_DIR/values.yaml"
    fi
    helm_cmd="$helm_cmd --set global.projectId=$project_id"
    helm_cmd="$helm_cmd --set global.namespace=$namespace"
    helm_cmd="$helm_cmd --set global.environment=$environment"
    helm_cmd="$helm_cmd --set global.security.allowInsecureImages=true"
    
    # 使用 Harbor 时覆盖镜像地址，避免从 docker.io 拉取（离线/网络受限环境）
    if [[ -n "${MONGODB_IMAGE_REGISTRY:-}" ]] && [[ -n "${MONGODB_IMAGE_PROJECT:-}" ]]; then
        helm_cmd="$helm_cmd --set global.imageRegistry=$MONGODB_IMAGE_REGISTRY"
        helm_cmd="$helm_cmd --set image.registry=$MONGODB_IMAGE_REGISTRY"
        helm_cmd="$helm_cmd --set image.repository=$MONGODB_IMAGE_PROJECT/mongodb"
        helm_cmd="$helm_cmd --set image.tag=${MONGODB_IMAGE_VERSION:-8.0.13-debian-12-r0}"
        helm_cmd="$helm_cmd --set metrics.image.registry=$MONGODB_IMAGE_REGISTRY"
        helm_cmd="$helm_cmd --set metrics.image.repository=$MONGODB_IMAGE_PROJECT/mongodb-exporter"
        helm_cmd="$helm_cmd --set metrics.image.tag=${MONGODB_METRICS_IMAGE_VERSION:-0.47.0-debian-12-r1}"
        # Init 容器（volumePermissions 等）也走 Harbor，避免 Init:ImagePullBackOff
        helm_cmd="$helm_cmd --set volumePermissions.image.registry=$MONGODB_IMAGE_REGISTRY"
        helm_cmd="$helm_cmd --set volumePermissions.image.repository=$MONGODB_IMAGE_PROJECT/os-shell"
        helm_cmd="$helm_cmd --set volumePermissions.image.tag=${MONGODB_OS_SHELL_IMAGE_VERSION:-12-debian-12-r51}"
        helm_cmd="$helm_cmd --set tls.image.registry=$MONGODB_IMAGE_REGISTRY"
        helm_cmd="$helm_cmd --set tls.image.repository=$MONGODB_IMAGE_PROJECT/nginx"
        log_info "使用 Harbor 镜像: $MONGODB_IMAGE_REGISTRY/$MONGODB_IMAGE_PROJECT/mongodb:${MONGODB_IMAGE_VERSION:-8.0.13-debian-12-r0}"
    fi
    
    if [[ -n "$values_file" ]]; then
        helm_cmd="$helm_cmd --values $values_file"
    fi
    # 不在脚本中覆盖 StorageClass，完全以 values 配置为准
    
    if [[ "$dry_run" == "true" ]]; then
        helm_cmd="$helm_cmd --dry-run"
        log_info "执行 MongoDB 部署（试运行模式）..."
    else
        log_info "执行 MongoDB 部署..."
    fi
    
    # 执行部署
    if eval "$helm_cmd"; then
        if [[ "$dry_run" == "true" ]]; then
            log_success "✅ MongoDB 部署试运行完成"
        else
            log_success "✅ MongoDB 部署完成"
        fi
        # 不在脚本中等待就绪，交由外层流程控制
        return 0
    else
        log_error "❌ MongoDB 部署失败"
        return 1
    fi
}

# 检查 MongoDB 状态
check_mongodb_status() {
    local project_id="$1"
    local namespace="$2"
    local release_name="mongodb-$project_id"
    local label_selector="app.kubernetes.io/instance=$release_name"
    
    log_info "检查 MongoDB 部署状态..."
    
    # 检查 Helm Release
    if helm list -n "$namespace" | grep -q "$release_name"; then
        log_success "✅ MongoDB Helm Release 存在"
    else
        log_error "❌ MongoDB Helm Release 不存在"
        return 1
    fi
    
    # 检查 Pod 状态：区分“启动中”和“异常未运行”
    local phases
    phases=$(kubectl get pods -n "$namespace" -l "$label_selector" -o jsonpath='{.items[*].status.phase}' 2>/dev/null || echo "")
    local pods_running pods_pending
    pods_running=$(echo "$phases" | tr ' ' '\n' | grep -c '^Running$' 2>/dev/null || echo "0")
    pods_running=$(echo "$pods_running" | tr -d '[:space:]')
    pods_running=${pods_running:-0}
    pods_pending=$(echo "$phases" | tr ' ' '\n' | grep -cE '^(Pending|ContainerCreating)$' 2>/dev/null || echo "0")
    pods_pending=$(echo "$pods_pending" | tr -d '[:space:]')
    pods_pending=${pods_pending:-0}
    
    if [[ "$pods_running" =~ ^[0-9]+$ ]] && [[ "$pods_running" -gt 0 ]]; then
        log_success "✅ MongoDB Pod 运行正常 ($pods_running 个)"
    elif [[ "$pods_pending" =~ ^[0-9]+$ ]] && [[ "$pods_pending" -gt 0 ]]; then
        log_warn "⏳ MongoDB Pod 正在启动中（$pods_pending 个 Pending/ContainerCreating，0 个 Running）"
        log_info "提示：这是正常的启动过程，如需查看详细进度可稍后运行 status 子命令。"
        # 启动中不视为失败，直接返回成功，让整体部署流程继续
        return 0
    else
        log_error "❌ MongoDB Pod 未运行"
        kubectl get pods -n "$namespace" -l "$label_selector" || true
        return 1
    fi
    
    # 测试 MongoDB 连接
    test_mongodb_connection "$project_id" "$namespace"
}

# 测试 MongoDB 连接
test_mongodb_connection() {
    local project_id="$1"
    local namespace="$2"
    local release_name="mongodb-$project_id"
    local label_selector="app.kubernetes.io/instance=$release_name"
    
    log_info "测试 MongoDB 连接..."
    
    # 获取 MongoDB 服务信息
    local service_name
    service_name=$(kubectl get svc -n "$namespace" -l "$label_selector" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -z "$service_name" ]]; then
        log_error "❌ 未找到 MongoDB 服务"
        return 1
    fi
    
    # 测试连接（使用 kubectl port-forward 或直接连接）
    log_info "MongoDB 服务: $service_name"
    log_success "✅ MongoDB 连接测试完成"
}

# 显示 MongoDB 连接信息
show_mongodb_connection_info() {
    local namespace="$1"
    
    echo ""
    echo "=== MongoDB 连接信息 ==="
    echo "命名空间: $namespace"
    echo "外部访问: $MONGODB_EXTERNAL_HOST:$MONGODB_EXTERNAL_PORT"
    echo ""
    echo "=== 使用说明 ==="
    echo "1. 配置 hosts 文件:"
    echo "   echo '101.126.151.0 ${MONGODB_EXTERNAL_HOST:-llmops.sunmoonai.com}' | sudo tee -a /etc/hosts"
    echo ""
    echo "2. 连接 MongoDB:"
    echo "   mongosh mongodb://$MONGODB_EXTERNAL_HOST:$MONGODB_EXTERNAL_PORT"
    echo ""
    echo "3. 查看服务状态:"
    echo "   kubectl get pods,svc -n $namespace -l app.kubernetes.io/instance=mongodb-<project_id>"
    echo ""
}

# 备份 MongoDB 数据库
backup_mongodb_database() {
    local namespace="$1"
    local backup_name="mongodb-backup-$(date +%Y%m%d-%H%M%S)"
    
    log_info "开始备份 MongoDB 数据库..."
    log_info "备份名称: $backup_name"
    
    # 这里可以实现具体的备份逻辑
    # 例如使用 mongodump 或 Kubernetes 备份工具
    log_success "✅ MongoDB 数据库备份完成: $backup_name"
}

# 部署 MongoDB Secrets（使用新的 Secret 管理系统）
deploy_mongodb_secrets() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="${4:-false}"
    
    log_info "🚀 部署 MongoDB Secrets..."
    
    local secrets_script="$SCRIPT_DIR/secrets/deploy-secrets-all/deploy-secrets-all.sh"
    
    if [[ ! -f "$secrets_script" ]]; then
        log_warn "⚠️  MongoDB Secrets 部署脚本不存在: $secrets_script"
        log_warn "跳过 Secrets 部署，请手动部署或检查脚本路径"
        return 0
    fi
    
    # 检查是否启用 Secrets 部署（默认启用）
    if [[ "${secrets_enabled:-true}" == "true" ]]; then
        # deploy-secrets-all.sh 期望的参数是: project_id namespace environment dry_run
        # 传递 --cluster 参数以保持集群配置
        if [[ -n "${CLUSTER:-}" ]]; then
            if bash "$secrets_script" "$project_id" "$namespace" "$environment" "$dry_run" --cluster "${CLUSTER}"; then
                log_success "✅ MongoDB Secrets 部署成功"
                return 0
            else
                log_error "❌ MongoDB Secrets 部署失败"
                return 1
            fi
        else
            if bash "$secrets_script" "$project_id" "$namespace" "$environment" "$dry_run"; then
                log_success "✅ MongoDB Secrets 部署成功"
                return 0
            else
                log_error "❌ MongoDB Secrets 部署失败"
                return 1
            fi
        fi
    else
        log_info "跳过 MongoDB Secrets 部署（secrets_enabled=false）"
        return 0
    fi
}

# 递归部署子组件（参考 PostgreSQL 的实现）
deploy_sub_components() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始部署 MongoDB 子组件..."
    
    # 定义子组件部署顺序（按优先级排序）
    local sub_components=(
        "mongodb_secrets:${secrets_enabled:-true}:${secrets_priority:-2000}:MongoDB Secrets:$SCRIPT_DIR/secrets/deploy-secrets-all/deploy-secrets-all.sh"
        "mongodb_middleware:${middleware_enabled:-false}:${middleware_priority:-1000}:MongoDB 中间件:$SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh"
        "mongodb_ingress:${ingress_enabled:-false}:${ingress_priority:-100}:MongoDB TCP 路由:$SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh"
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
                # Ingress 脚本不接受 dry_run 参数，只传递 deploy/project_id/namespace/environment
                if [[ "$name" == "mongodb_ingress" ]]; then
                    if bash "$script_path" deploy "$project_id" "$namespace" "$environment"; then
                        log_success "✅ $description 部署成功"
                    else
                        log_error "❌ $description 部署失败"
                        return 1
                    fi
                else
                    # 其他子组件可以传递 dry_run 参数
                    # 确保 KUBECONFIG 环境变量被传递
                    if env KUBECONFIG="${KUBECONFIG:-}" bash "$script_path" deploy "$project_id" "$namespace" "$environment" "$dry_run"; then
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
    set -- "${PARSED_ARGS[@]}"
    
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
            log_info "开始部署 MongoDB..."
            check_namespace "$namespace"
            
            # 在部署前按需推送 MongoDB 组件镜像到 Harbor（Kind 使用 push-to-harbor，远程使用 registry-push-management）
            push_mongodb_images_to_harbor || log_warn "[images] MongoDB 镜像推送阶段出现警告，可稍后单独检查 Harbor 镜像状态"
            
            # ============================================================
            # 阶段1：部署子级组件（按优先级，先部署依赖项）
            # ============================================================
            log_info "🚀 阶段1：部署 MongoDB 子级组件..."
            if ! deploy_sub_components "$project_id" "$namespace" "$environment" "$dry_run"; then
                log_error "❌ MongoDB 子级组件部署失败！"
                exit 1
            fi
            log_success "✅ MongoDB 子级组件部署完成"
            
            # ============================================================
            # 阶段2：部署本级核心服务（Helm Chart 部署）
            # ============================================================
            log_info "🚀 阶段2：部署 MongoDB 核心服务..."
            
            execute_mongodb_deployment "$project_id" "$namespace" "$environment" "$dry_run"
            check_mongodb_status "$project_id" "$namespace"
            show_mongodb_connection_info "$namespace"
            ;;
        "upgrade")
            log_info "开始升级 MongoDB..."
            check_namespace "$namespace"
            execute_mongodb_deployment "$project_id" "$namespace" "$environment" "$dry_run"
            check_mongodb_status "$project_id" "$namespace"
            ;;
        "uninstall")
            log_info "开始卸载 MongoDB..."
            
            # 设置 Kubernetes 环境
            if ! setup_kubectl_environment; then
                log_error "无法建立 Kubernetes 连接"
                return 1
            fi
            
            # 卸载子组件（按优先级逆序）
            log_info "卸载 MongoDB 子组件..."
            local sub_components=(
                "mongodb_secrets:${secrets_enabled:-true}:${secrets_priority:-2000}:MongoDB Secrets:$SCRIPT_DIR/secrets/deploy-secrets-all/deploy-secrets-all.sh"
                "mongodb_middleware:${middleware_enabled:-false}:${middleware_priority:-1000}:MongoDB 中间件:$SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh"
                "mongodb_ingress:${ingress_enabled:-false}:${ingress_priority:-100}:MongoDB TCP 路由:$SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh"
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
                        DISABLE_AUTO_CLEANUP=true bash "$script_path" uninstall "$project_id" "$namespace" "$environment" || true
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
            
            helm uninstall "mongodb-$project_id" -n "$namespace" || true
            log_success "✅ MongoDB 卸载完成"
            ;;
        "clean")
            log_info "开始清理 MongoDB..."
            helm uninstall "mongodb-$project_id" -n "$namespace" || true
            kubectl delete pvc -n "$namespace" -l app.kubernetes.io/instance="mongodb-$project_id" || true
            log_success "✅ MongoDB 清理完成"
            ;;
        "status")
            check_mongodb_status "$project_id" "$namespace"
            show_mongodb_connection_info "$namespace"
            ;;
        "logs")
            log_info "显示 MongoDB 日志..."
            kubectl logs -n "$namespace" -l app.kubernetes.io/instance="mongodb-$project_id" --tail=100
            ;;
        "backup")
            backup_mongodb_database "$namespace"
            ;;
        "connect")
            show_mongodb_connection_info "$namespace"
            ;;
        *)
            echo "用法: $0 <action> [project_id] [namespace] [environment] [dry_run]"
            echo ""
            echo "操作:"
            echo "  deploy     部署 MongoDB（默认）"
            echo "  upgrade    升级 MongoDB"
            echo "  uninstall  卸载 MongoDB"
            echo "  clean      清理 MongoDB（包括数据）"
            echo "  status     检查 MongoDB 状态"
            echo "  logs       显示 MongoDB 日志"
            echo "  backup     备份 MongoDB 数据库"
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
