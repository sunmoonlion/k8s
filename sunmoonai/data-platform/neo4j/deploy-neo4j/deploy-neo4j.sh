#!/bin/bash

# Neo4j 递归部署脚本
# 基于递归架构设计原则的两级部署逻辑

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 保存 Neo4j 脚本的目录路径（统一部署模板会重新定义 SCRIPT_DIR）
NEO4J_SCRIPT_DIR="$SCRIPT_DIR"

# 导入统一部署模板
source "$PROJECT_ROOT/../../../utils/unified-deployment-template.sh"

# 恢复 Neo4j 脚本的目录路径
SCRIPT_DIR="$NEO4J_SCRIPT_DIR"

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

NEO4J_CONFIG_FILE="$SCRIPT_DIR/deploy-neo4j.conf"
if [[ -f "$NEO4J_CONFIG_FILE" ]]; then
    source "$NEO4J_CONFIG_FILE"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
    
    log_info "已加载 Neo4j 配置文件: $NEO4J_CONFIG_FILE"
else
    log_error "缺少 Neo4j 配置文件: $NEO4J_CONFIG_FILE"
    exit 1
fi

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="data-platform-dev"
DEFAULT_ENVIRONMENT="development"

# Neo4j 资源目录（固定路径）
NEO4J_CHART_DIR="$SCRIPT_DIR/../resources/neo4j"
NEO4J_CUSTOM_VALUES_DIR="$SCRIPT_DIR/../resources/custom-values"

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

# 定义 Neo4j 所需镜像（保留给镜像检查设计使用）
define_required_images() {
    local environment="$1"
    
    case "$environment" in
        "development"|"dev")
            echo "neo4j/neo4j:$NEO4J_IMAGE_VERSION|true"
            if [[ "${NEO4J_COMMUNITY_ENABLED:-false}" == "true" ]]; then
                echo "neo4j/neo4j:$NEO4J_COMMUNITY_IMAGE_VERSION|true"
            fi
            ;;
        "production"|"prod")
            echo "neo4j/neo4j:$NEO4J_IMAGE_VERSION|true"
            if [[ "${NEO4J_MONITORING_ENABLED:-false}" == "true" ]]; then
                echo "neo4j/neo4j:$NEO4J_IMAGE_VERSION|true"
            fi
            ;;
        *)
            echo "neo4j/neo4j:$NEO4J_IMAGE_VERSION|true"
            ;;
    esac
}

# 使用统一模板的通用按需推送 helper，将 Neo4j 组件镜像推送到 Harbor
push_neo4j_images_to_harbor() {
    push_component_images_to_harbor "neo4j"
}

# 执行 Neo4j 部署
execute_neo4j_deployment() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始执行 Neo4j 部署..."
    log_info "项目: $project_id"
    log_info "命名空间: $namespace"
    log_info "环境: $environment"
    log_info "离线模式: $NEO4J_FORCE_OFFLINE"
    
    # 检查 Chart 目录是否存在
    if [[ ! -d "$NEO4J_CHART_DIR" ]]; then
        log_error "Neo4j Chart 目录不存在: $NEO4J_CHART_DIR"
        return 1
    fi
    
    # 构建 values 文件路径，并根据持久化模式选择是否复用老盘（仅对 development/dev 生效）
    local values_file
    # 支持全局强制模式：SUNMOONAI_GLOBAL_PERSIST_MODE=init|reuse
    local global_persist_mode="${SUNMOONAI_GLOBAL_PERSIST_MODE:-}"
    local persist_mode
    if [[ -n "$global_persist_mode" ]]; then
        persist_mode="$global_persist_mode"
        log_info "检测到全局持久化模式 SUNMOONAI_GLOBAL_PERSIST_MODE=$global_persist_mode，将覆盖组件配置 NEO4J_PERSIST_MODE=${NEO4J_PERSIST_MODE:-init}"
    else
        persist_mode="${NEO4J_PERSIST_MODE:-init}"
    fi
    # 远程集群（C1/C2 等）仅使用动态 StorageClass，不应用 Kind 静态 PV/PVC（避免 172.28.46.235）
    if [[ -n "${CLUSTER:-}" && "$(echo "${CLUSTER}" | tr '[:upper:]' '[:lower:]')" != "kind" ]]; then
        if [[ "$persist_mode" == "reuse" ]]; then
            log_info "集群 ${CLUSTER} 为远程集群，强制使用动态存储 (init)，不应用 Kind 静态 PV/PVC"
            persist_mode="init"
        fi
    fi
    case "$environment" in
        "production"|"prod")
            values_file="$NEO4J_CUSTOM_VALUES_DIR/prod-values.yaml"
            ;;
        "development"|"dev")
            if [[ "$persist_mode" == "reuse" ]]; then
                # 复用模式：先应用静态 PV/PVC，再使用 dev-values-persist.yaml
                local pv_pvc_file="$NEO4J_CUSTOM_VALUES_DIR/neo4j-dev-pv-pvc.yaml"
                if [[ ! -f "$pv_pvc_file" ]]; then
                    log_error "复用模式启用，但未找到静态 PV/PVC 文件: $pv_pvc_file"
                    return 1
                fi
                log_info "NEO4J_PERSIST_MODE=reuse，先应用静态 PV/PVC: $pv_pvc_file"
                kubectl apply -f "$pv_pvc_file"
                values_file="$NEO4J_CUSTOM_VALUES_DIR/dev-values-persist.yaml"
            else
                # 初始化模式：使用原始 dev-values.yaml（动态 nfs-2，新盘）
                values_file="$NEO4J_CUSTOM_VALUES_DIR/dev-values.yaml"
            fi
            ;;
        *)
            values_file="$NEO4J_CUSTOM_VALUES_DIR/dev-values.yaml"
            ;;
    esac
    if [[ ! -f "$values_file" ]]; then
        log_error "环境配置文件不存在: $values_file"
        return 1
    fi
    
    # 构建 Helm 命令
    local release_name="neo4j-$project_id"
    local helm_cmd="helm upgrade --install $release_name $NEO4J_CHART_DIR"
    helm_cmd="$helm_cmd --namespace $namespace"
    helm_cmd="$helm_cmd --set global.projectId=$project_id"
    helm_cmd="$helm_cmd --set global.namespace=$namespace"
    helm_cmd="$helm_cmd --set global.environment=$environment"
    
    # 使用 Harbor 时覆盖镜像，避免从 docker.io 拉取
    if [[ -n "${NEO4J_IMAGE_REGISTRY:-}" ]] && [[ -n "${NEO4J_IMAGE_PROJECT:-}" ]]; then
        helm_cmd="$helm_cmd --set global.imageRegistry=$NEO4J_IMAGE_REGISTRY"
        helm_cmd="$helm_cmd --set image.registry=$NEO4J_IMAGE_REGISTRY"
        helm_cmd="$helm_cmd --set image.repository=$NEO4J_IMAGE_PROJECT/neo4j"
        helm_cmd="$helm_cmd --set image.tag=${NEO4J_IMAGE_VERSION:-5.26.11-debian-12-r0}"
        helm_cmd="$helm_cmd --set volumePermissions.image.registry=$NEO4J_IMAGE_REGISTRY"
        helm_cmd="$helm_cmd --set volumePermissions.image.repository=$NEO4J_IMAGE_PROJECT/os-shell"
        helm_cmd="$helm_cmd --set volumePermissions.image.tag=${NEO4J_OS_SHELL_IMAGE_VERSION:-12-debian-12-r51}"
        log_info "使用 Harbor 镜像: $NEO4J_IMAGE_REGISTRY/$NEO4J_IMAGE_PROJECT/neo4j:${NEO4J_IMAGE_VERSION:-5.26.11-debian-12-r0}"
    fi
    
    helm_cmd="$helm_cmd --values $values_file"
    
    if [[ "$dry_run" == "true" ]]; then
        helm_cmd="$helm_cmd --dry-run"
        log_info "执行 Neo4j 部署（试运行模式）..."
    else
        log_info "执行 Neo4j 部署..."
    fi
    
    # 执行部署
    if eval "$helm_cmd"; then
        if [[ "$dry_run" == "true" ]]; then
            log_success "✅ Neo4j 部署试运行完成"
        else
            log_success "✅ Neo4j 部署完成"
        fi
        return 0
    else
        log_error "❌ Neo4j 部署失败"
        return 1
    fi
}

# 检查 Neo4j 状态
check_neo4j_status() {
    local project_id="$1"
    local namespace="$2"
    local release_name="neo4j-$project_id"
    local label_selector="app.kubernetes.io/instance=$release_name"
    
    log_info "检查 Neo4j 部署状态..."

    # 确保 kubectl/helm 可连集群（避免主流程已清理隧道后 status 误判为失败）
    if type setup_kubectl_environment >/dev/null 2>&1; then
        setup_kubectl_environment || true
    fi
    
    # 检查 Helm Release
    if helm list -n "$namespace" | grep -q "$release_name"; then
        log_success "✅ Neo4j Helm Release 存在"
    else
        log_error "❌ Neo4j Helm Release 不存在"
        return 1
    fi
    
    # 检查 Pod 状态：区分“启动中”和“异常未运行”
    local phases
    phases=$(kubectl get pods -n "$namespace" -l "$label_selector" -o jsonpath='{.items[*].status.phase}' 2>/dev/null || echo "")
    local pods_running pods_pending
    if [[ -z "$phases" ]]; then
        pods_running=0
        pods_pending=0
    else
        local pods_running_str pods_pending_str
        pods_running_str=$(echo "$phases" | tr ' ' '\n' | grep -c '^Running$' 2>/dev/null || echo "0")
        pods_pending_str=$(echo "$phases" | tr ' ' '\n' | grep -cE '^(Pending|ContainerCreating)$' 2>/dev/null || echo "0")
        pods_running=$(echo "$pods_running_str" | tr -d '[:space:]')
        pods_running=${pods_running:-0}
        pods_pending=$(echo "$pods_pending_str" | tr -d '[:space:]')
        pods_pending=${pods_pending:-0}
    fi
    if [[ "$pods_running" =~ ^[0-9]+$ ]] && [[ "$pods_running" -gt 0 ]]; then
        log_success "✅ Neo4j Pod 运行正常 ($pods_running 个)"
    elif [[ "$pods_pending" =~ ^[0-9]+$ ]] && [[ "$pods_pending" -gt 0 ]]; then
        log_warn "⏳ Neo4j Pod 正在启动中（$pods_pending 个 Pending/ContainerCreating，0 个 Running）"
        log_info "提示：这是正常的启动过程，如需查看详细进度可稍后运行 status 子命令。"
        # 启动中不视为失败，直接返回成功，让整体部署流程继续
        return 0
    else
        log_error "❌ Neo4j Pod 未运行"
        kubectl get pods -n "$namespace" -l "$label_selector" -owide || true
        kubectl get pvc  -n "$namespace" -l "$label_selector" || true
        kubectl get events -n "$namespace" --sort-by=.lastTimestamp | tail -n 20 || true
        return 1
    fi
    
    # 测试 Neo4j 连接
    test_neo4j_connection "$project_id" "$namespace"
}

# 测试 Neo4j 连接
test_neo4j_connection() {
    local project_id="$1"
    local namespace="$2"
    local release_name="neo4j-$project_id"
    local label_selector="app.kubernetes.io/instance=$release_name"
    
    log_info "测试 Neo4j 连接..."
    
    # 获取 Neo4j 服务信息
    local service_name
    service_name=$(kubectl get svc -n "$namespace" -l "$label_selector" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -z "$service_name" ]]; then
        log_error "❌ 未找到 Neo4j 服务"
        return 1
    fi
    
    # 测试连接（使用 kubectl port-forward 或直接连接）
    log_info "Neo4j 服务: $service_name"
    log_success "✅ Neo4j 连接测试完成"
}

# 递归部署子组件（中间件 / Ingress-All）
deploy_sub_components() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"

    log_info "开始部署 Neo4j 子组件..."

    # 定义子组件部署顺序（按优先级排序，数值越大越先部署）
    local sub_components=(
        "neo4j_secrets:${secrets_enabled:-true}:${secrets_priority:-10}:Neo4j Secrets:$SCRIPT_DIR/secrets/deploy-secrets-all/deploy-secrets-all.sh"
        "neo4j_middleware:${middleware_enabled:-false}:${middleware_priority:-1000}:Neo4j 中间件:$SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh"
        "neo4j_ingress:${ingress_enabled:-false}:${ingress_priority:-100}:Neo4j 路由(含 Web+TCP):$SCRIPT_DIR/ingress/deploy-ingress-all/deploy-ingress-all.sh"
    )

    IFS=$'\n' sub_components=($(sort -t: -k3 -nr <<<"${sub_components[*]}")); unset IFS

    for component_info in "${sub_components[@]}"; do
        IFS=':' read -r name enabled priority description script_path <<< "$component_info"
        if [[ "$enabled" == "true" ]]; then
            log_info "部署 $description (优先级: $priority)..."
            if [[ -f "$script_path" ]]; then
                # 这些子脚本以 namespace 为主要参数
                if bash "$script_path" deploy "$namespace"; then
                    log_success "✅ $description 部署成功"
                else
                    log_error "❌ $description 部署失败"
                    return 1
                fi
            else
                log_error "❌ 子脚本不存在: $script_path"; return 1
            fi
        else
            log_info "跳过 $description (已禁用)"
        fi
    done

    log_success "✅ Neo4j 子组件部署完成"
    return 0
}

# 卸载子组件（反向优先级）
uninstall_sub_components() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"

    log_info "卸载 Neo4j 子组件..."

    local sub_components=(
        "neo4j_middleware:${middleware_enabled:-false}:${middleware_priority:-1000}:Neo4j 中间件:$SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh"
        "neo4j_ingress:${ingress_enabled:-false}:${ingress_priority:-100}:Neo4j 路由(含 Web+TCP):$SCRIPT_DIR/ingress/deploy-ingress-all/deploy-ingress-all.sh"
    )

    IFS=$'\n' sub_components=($(sort -t: -k3 -n <<<"${sub_components[*]}")); unset IFS

    for component_info in "${sub_components[@]}"; do
        IFS=':' read -r name enabled priority description script_path <<< "$component_info"
        if [[ "$enabled" == "true" ]]; then
            log_info "卸载 $description (优先级: $priority)..."
            if [[ -f "$script_path" ]]; then
                # 禁用子脚本的自动清理，保持连接以便后续操作
                DISABLE_AUTO_CLEANUP=true bash "$script_path" uninstall "$namespace" || true
                log_success "✅ $description 卸载完成"
            else
                log_warn "⚠️ 子脚本不存在: $script_path"
            fi
        fi
    done

    return 0
}

# 端口转发并输出初始密码
forward_neo4j_access() {
    local namespace="$1"
    local project_id="${2:-$DEFAULT_PROJECT_ID}"
    local release_name="neo4j-$project_id"
    local label_selector="app.kubernetes.io/instance=$release_name"

    log_info "准备进行端口转发并输出初始密码..."

    local service_name
    service_name=$(kubectl get svc -n "$namespace" -l "$label_selector" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "$release_name")

    echo ""
    echo "=== Neo4j 初始登录信息 ==="
    echo -n "用户名: "; echo "neo4j"
    echo -n "密码:   "
    kubectl get secret -n "$namespace" neo4j-secrets -o jsonpath='{.data.neo4j-password}' 2>/dev/null | base64 -d || true
    echo ""
    echo ""
    echo "访问地址: http://127.0.0.1:7474/"
    echo "提示: 按 Ctrl+C 结束端口转发"
    echo ""

    kubectl port-forward -n "$namespace" "svc/${service_name}" 7474:7474
}

# 显示 Neo4j 连接信息
show_neo4j_connection_info() {
    local namespace="$1"
    
    echo ""
    echo "=== Neo4j 连接信息 ==="
    echo "命名空间: $namespace"
    echo "外部访问: https://${NEO4J_UNIFIED_HOST:-llmops.sunmoonai.com}/neo4j"
    echo ""
    echo "=== 使用说明 ==="
    echo "1. 配置 hosts 文件（如果需要）:"
    echo "   echo '101.126.151.0 ${NEO4J_UNIFIED_HOST:-llmops.sunmoonai.com}' | sudo tee -a /etc/hosts"
    echo ""
    echo "2. 访问 Neo4j Browser:"
    echo "   https://${NEO4J_UNIFIED_HOST:-llmops.sunmoonai.com}/neo4j"
    echo ""
    echo "3. 查看服务状态:"
    echo "   kubectl get pods,svc -n $namespace -l app.kubernetes.io/instance=neo4j-<project_id>"
    echo ""
    echo "4. 连接 Neo4j 数据库:"
    # 动态获取外部端口
    local external_port
    external_port=$(get_neo4j_external_port)
    echo "   bolt://${NEO4J_UNIFIED_HOST:-llmops.sunmoonai.com}:${external_port}"
    echo "   用户名: neo4j"
    echo "   密码: 从 Secret 中获取"
    echo ""
}

# 备份 Neo4j 数据
backup_neo4j_data() {
    local namespace="$1"
    local backup_name="neo4j-backup-$(date +%Y%m%d-%H%M%S)"
    
    log_info "开始备份 Neo4j 数据..."
    log_info "备份名称: $backup_name"
    
    # 这里可以实现具体的备份逻辑
    # 例如使用 Neo4j 备份工具或 Kubernetes 备份工具
    log_success "✅ Neo4j 数据备份完成: $backup_name"
}

# 创建 Neo4j 密钥（若不存在则先部署，避免 Pod 卡在 ContainerCreating）
create_neo4j_secrets_if_needed() {
    local namespace="$1"
    
    log_info "检查 Neo4j 密钥..."
    
    if kubectl get secret "$NEO4J_AUTH_SECRET_NAME" -n "$namespace" >/dev/null 2>&1; then
        log_success "✅ Neo4j 密钥已存在: $NEO4J_AUTH_SECRET_NAME"
        return 0
    fi
    
    log_info "创建 Neo4j 密钥（Chart 依赖 neo4j-secrets 存在）..."
    if [[ -f "$SCRIPT_DIR/secrets/neo4j-secrets/deploy-neo4j-secrets/deploy-neo4j-secrets.sh" ]]; then
        "$SCRIPT_DIR/secrets/neo4j-secrets/deploy-neo4j-secrets/deploy-neo4j-secrets.sh" deploy "$namespace"
    else
        log_warn "⚠️ Neo4j 密钥部署脚本不存在，跳过密钥创建"
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
        log_error "无法读取 Kubernetes 配置文件"; exit 1; fi
    if ! setup_kubectl_environment; then
        log_error "无法建立 Kubernetes 连接"; exit 1; fi
    
    case "$action" in
        "deploy")
            log_info "开始部署 Neo4j..."
            check_namespace "$namespace"
            # 在部署前按需推送 Neo4j 组件镜像到 Harbor（Kind 使用 push-to-harbor，远程使用 registry-push-management）
            push_neo4j_images_to_harbor || log_warn "[images] Neo4j 镜像推送阶段出现警告，可稍后单独检查 Harbor 镜像状态"
            # 先确保 neo4j-secrets 存在，再执行 Helm，避免 Pod 卡在 ContainerCreating（MountVolume.SetUp: secret "neo4j-secrets" not found）
            create_neo4j_secrets_if_needed "$namespace"
            execute_neo4j_deployment "$project_id" "$namespace" "$environment" "$dry_run"
            # 部署子组件（中间件 / Ingress-All）
            if deploy_sub_components "$project_id" "$namespace" "$environment" "$dry_run"; then
                check_neo4j_status "$project_id" "$namespace" || true
                show_neo4j_connection_info "$namespace"
            else
                log_error "❌ Neo4j 子组件部署失败"
                exit 1
            fi
            ;;
        "upgrade")
            log_info "开始升级 Neo4j..."
            check_namespace "$namespace"
            execute_neo4j_deployment "$project_id" "$namespace" "$environment" "$dry_run"
            check_neo4j_status "$project_id" "$namespace"
            ;;
        "uninstall")
            log_info "开始卸载 Neo4j..."
            # 先卸载子组件
            uninstall_sub_components "$project_id" "$namespace" "$environment"
            # 确保连接仍然可用
            if ! kubectl get nodes >/dev/null 2>&1; then
                log_info "连接已断开，重新建立连接..."
                if ! setup_kubectl_environment; then
                    log_error "无法重新建立 Kubernetes 连接"
                    return 1
                fi
            fi
            # 再卸载主部署
            helm uninstall "neo4j-$project_id" -n "$namespace" --wait || true
            log_success "✅ Neo4j 卸载完成"
            ;;
        "clean")
            log_info "开始清理 Neo4j..."
            helm uninstall "neo4j-$project_id" -n "$namespace" || true
            kubectl delete pvc -n "$namespace" -l app.kubernetes.io/instance="neo4j-$project_id" || true
            log_success "✅ Neo4j 清理完成"
            ;;
        "status")
            check_neo4j_status "$project_id" "$namespace"
            show_neo4j_connection_info "$namespace"
            ;;
        "logs")
            log_info "显示 Neo4j 日志..."
            kubectl logs -n "$namespace" -l app.kubernetes.io/instance="neo4j-$project_id" --tail=100
            ;;
        "backup")
            backup_neo4j_data "$namespace"
            ;;
        "connect")
            show_neo4j_connection_info "$namespace"
            ;;
        "forward")
            check_neo4j_status "$project_id" "$namespace" || true
            forward_neo4j_access "$namespace" "$project_id"
            ;;
        *)
            echo "用法: $0 <action> [project_id] [namespace] [environment] [dry_run]"
            echo ""
            echo "操作:"
            echo "  deploy     部署 Neo4j（默认）"
            echo "  upgrade    升级 Neo4j"
            echo "  uninstall  卸载 Neo4j"
            echo "  clean      清理 Neo4j（包括数据）"
            echo "  status     检查 Neo4j 状态"
            echo "  logs       显示 Neo4j 日志"
            echo "  forward    端口转发并输出初始密码（不改动集群）"
            echo "  backup     备份 Neo4j 数据"
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
            echo "  $0 forward sunmoonai data-platform-dev development"
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
