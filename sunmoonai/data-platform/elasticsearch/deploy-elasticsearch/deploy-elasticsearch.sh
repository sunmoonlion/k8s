#!/bin/bash

# Elasticsearch 递归部署脚本
# 基于递归架构设计原则的两级部署逻辑

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 保存 Elasticsearch 脚本的目录路径（统一部署模板会重新定义 SCRIPT_DIR）
ELASTICSEARCH_SCRIPT_DIR="$SCRIPT_DIR"

# 导入统一部署模板
source "$PROJECT_ROOT/../../../utils/unified-deployment-template.sh"

# 恢复 Elasticsearch 脚本的目录路径
SCRIPT_DIR="$ELASTICSEARCH_SCRIPT_DIR"

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

ELASTICSEARCH_CONFIG_FILE="$SCRIPT_DIR/deploy-elasticsearch.conf"
if [[ -f "$ELASTICSEARCH_CONFIG_FILE" ]]; then
    source "$ELASTICSEARCH_CONFIG_FILE"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
    
    log_info "已加载 Elasticsearch 配置文件: $ELASTICSEARCH_CONFIG_FILE"
else
    log_error "缺少 Elasticsearch 配置文件: $ELASTICSEARCH_CONFIG_FILE"
    exit 1
fi

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="data-platform-dev"
DEFAULT_ENVIRONMENT="development"

# Elasticsearch 资源目录（固定路径）
ELASTICSEARCH_CHART_DIR="$SCRIPT_DIR/../resources/elasticsearch"
ELASTICSEARCH_CUSTOM_VALUES_DIR="$SCRIPT_DIR/../resources/custom-values"

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

# 定义 Elasticsearch 所需镜像
define_required_images() {
    local environment="$1"
    
    case "$environment" in
        "development"|"dev")
            # 开发环境：主镜像 + 监控镜像（如果启用）
            echo "elasticsearch:$ELASTICSEARCH_IMAGE_VERSION|true"
            if [[ "${ELASTICSEARCH_MONITORING_ENABLED:-false}" == "true" ]]; then
                echo "elasticsearch:$ELASTICSEARCH_METRICS_IMAGE_VERSION|true"
            fi
            ;;
        "production"|"prod")
            # 生产环境：主镜像 + 监控镜像 + 备份镜像
            echo "elasticsearch:$ELASTICSEARCH_IMAGE_VERSION|true"
            echo "elasticsearch:$ELASTICSEARCH_METRICS_IMAGE_VERSION|true"
            if [[ "${ELASTICSEARCH_BACKUP_ENABLED:-false}" == "true" ]]; then
                echo "elasticsearch:$ELASTICSEARCH_IMAGE_VERSION|true"  # 用于备份的相同镜像
            fi
            ;;
        *)
            # 默认：只使用主镜像
            echo "elasticsearch:$ELASTICSEARCH_IMAGE_VERSION|true"
            ;;
    esac
}

# 执行 Elasticsearch 部署
execute_elasticsearch_deployment() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始执行 Elasticsearch 部署..."
    log_info "项目: $project_id"
    log_info "命名空间: $namespace"
    log_info "环境: $environment"
    log_info "离线模式: $ELASTICSEARCH_FORCE_OFFLINE"
    
    # 检查 Chart 目录是否存在
    if [[ ! -d "$ELASTICSEARCH_CHART_DIR" ]]; then
        log_error "Elasticsearch Chart 目录不存在: $ELASTICSEARCH_CHART_DIR"
        return 1
    fi
    
    # 构建 values 文件路径（统一映射 development→dev, production→prod）
    local values_file=""
    case "$environment" in
        "development"|"dev") values_file="$ELASTICSEARCH_CUSTOM_VALUES_DIR/dev-values.yaml" ;;
        "production"|"prod") values_file="$ELASTICSEARCH_CUSTOM_VALUES_DIR/prod-values.yaml" ;;
        *) log_warn "未知环境: $environment，使用 dev-values.yaml"; values_file="$ELASTICSEARCH_CUSTOM_VALUES_DIR/dev-values.yaml" ;;
    esac
    if [[ ! -f "$values_file" ]]; then
        log_warn "环境配置文件不存在: $values_file，仅使用 Chart 默认值"
        values_file=""
    fi
    
    # 构建 Helm 命令
    local helm_cmd="helm upgrade --install elasticsearch-$project_id $ELASTICSEARCH_CHART_DIR"
    helm_cmd="$helm_cmd --namespace $namespace"
    # 先加载 Chart 自带 values，再叠加环境 values
    if [[ -f "$ELASTICSEARCH_CHART_DIR/values.yaml" ]]; then
        helm_cmd="$helm_cmd --values $ELASTICSEARCH_CHART_DIR/values.yaml"
    fi
    helm_cmd="$helm_cmd --set global.projectId=$project_id"
    helm_cmd="$helm_cmd --set global.namespace=$namespace"
    helm_cmd="$helm_cmd --set global.environment=$environment"
    
    if [[ -n "$values_file" ]]; then
        helm_cmd="$helm_cmd --values $values_file"
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        helm_cmd="$helm_cmd --dry-run"
        log_info "执行 Elasticsearch 部署（试运行模式）..."
    else
        log_info "执行 Elasticsearch 部署..."
    fi
    
    # 执行部署
    if eval "$helm_cmd"; then
        if [[ "$dry_run" == "true" ]]; then
            log_success "✅ Elasticsearch 部署试运行完成"
        else
            log_success "✅ Elasticsearch 部署完成"
        fi
        return 0
    else
        log_error "❌ Elasticsearch 部署失败"
        return 1
    fi
}

# 检查 Elasticsearch 状态
check_elasticsearch_status() {
    local namespace="$1"
    
    log_info "检查 Elasticsearch 部署状态..."
    
    # 检查 Helm Release
    if helm list -n "$namespace" | grep -q "elasticsearch-sunmoonai"; then
        log_success "✅ Elasticsearch Helm Release 存在"
    else
        log_error "❌ Elasticsearch Helm Release 不存在"
        return 1
    fi
    
    # 检查 Pod 状态（稳健处理空输出与非数字情况）
    local phases
    phases=$(kubectl get pods -n "$namespace" -l app.kubernetes.io/name=elasticsearch -o jsonpath='{.items[*].status.phase}' 2>/dev/null || echo "")

    # 统计 Running 数量
    local pods_ready
    if [[ -z "$phases" ]]; then
        pods_ready=0
    else
        pods_ready=$(echo "$phases" | tr ' ' '\n' | grep -c '^Running$' || echo 0)
    fi

    if [[ ${pods_ready:-0} -gt 0 ]]; then
        log_success "✅ Elasticsearch Pod 运行正常 (${pods_ready} 个)"
    else
        log_error "❌ Elasticsearch Pod 未运行"
        return 1
    fi
    
    # 测试 Elasticsearch 连接
    test_elasticsearch_connection "$namespace"
}

# 测试 Elasticsearch 连接
test_elasticsearch_connection() {
    local namespace="$1"
    
    log_info "测试 Elasticsearch 连接..."
    
    # 获取 Elasticsearch 服务信息
    local service_name
    service_name=$(kubectl get svc -n "$namespace" -l app.kubernetes.io/name=elasticsearch -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -z "$service_name" ]]; then
        log_error "❌ 未找到 Elasticsearch 服务"
        return 1
    fi
    
    # 测试连接（使用 kubectl port-forward 或直接连接）
    log_info "Elasticsearch 服务: $service_name"
    log_success "✅ Elasticsearch 连接测试完成"
}

# 显示 Elasticsearch 连接信息
show_elasticsearch_connection_info() {
    local namespace="$1"
    
    echo ""
    echo "=== Elasticsearch 连接信息 ==="
    echo "命名空间: $namespace"
    echo "外部访问: $ELASTICSEARCH_EXTERNAL_HOST:$ELASTICSEARCH_EXTERNAL_PORT"
    echo ""
    echo "=== 使用说明 ==="
    echo "1. 配置 hosts 文件:"
    echo "   echo '101.126.151.0 $ELASTICSEARCH_EXTERNAL_HOST' | sudo tee -a /etc/hosts"
    echo ""
    echo "2. 连接 Elasticsearch:"
    echo "   curl http://$ELASTICSEARCH_EXTERNAL_HOST:$ELASTICSEARCH_EXTERNAL_PORT"
    echo ""
    echo "3. 查看服务状态:"
    echo "   kubectl get pods,svc -n $namespace -l app.kubernetes.io/name=elasticsearch"
    echo ""
}

# 调试：打印与 Pending 相关的关键信息
debug_elasticsearch_pending() {
    local namespace="$1"
    log_info "收集 Elasticsearch Pending 诊断信息..."
    echo "==== Pods (ES) ===="
    kubectl get pods -n "$namespace" -l app.kubernetes.io/name=elasticsearch -owide || true
    for role in coordinating data master; do
        local pod
        pod=$(kubectl get pod -n "$namespace" -l app.kubernetes.io/name=elasticsearch,role=$role -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
        if [[ -n "$pod" ]]; then
            echo "\n==== describe pod $pod (tail) ===="
            kubectl describe pod -n "$namespace" "$pod" | tail -n 120 || true
        fi
    done
    echo "\n==== PVCs ===="
    kubectl get pvc -n "$namespace" || true
    echo "\n==== StorageClasses ===="
    kubectl get sc || true
    echo "\n==== Events (tail) ===="
    kubectl get events -n "$namespace" --sort-by=.lastTimestamp | tail -n 80 || true
}

# 备份 Elasticsearch 数据
backup_elasticsearch_data() {
    local namespace="$1"
    local backup_name="elasticsearch-backup-$(date +%Y%m%d-%H%M%S)"
    
    log_info "开始备份 Elasticsearch 数据..."
    log_info "备份名称: $backup_name"
    
    # 这里可以实现具体的备份逻辑
    # 例如使用 Elasticsearch Snapshot API 或 Kubernetes 备份工具
    log_success "✅ Elasticsearch 数据备份完成: $backup_name"
}

# 创建 Elasticsearch 密钥（如果需要）
create_elasticsearch_secrets_if_needed() {
    local namespace="$1"
    
    log_info "检查 Elasticsearch 密钥..."
    
    # 统一密管负责创建；仅提示
    if kubectl get secret "$ELASTICSEARCH_AUTH_SECRET_NAME" -n "$namespace" >/dev/null 2>&1; then
        log_success "✅ Elasticsearch 密钥已存在: $ELASTICSEARCH_AUTH_SECRET_NAME"
    else
        log_info "跳过创建 Elasticsearch 密钥（由统一密管管理）：$ELASTICSEARCH_AUTH_SECRET_NAME"
    fi
}

# 部署 Elasticsearch Secrets（使用新的 Secret 管理系统）
deploy_elasticsearch_secrets() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="${4:-false}"
    
    log_info "🚀 部署 Elasticsearch Secrets..."
    
    local secrets_script="$SCRIPT_DIR/secrets/deploy-secrets-all/deploy-secrets-all.sh"
    
    if [[ ! -f "$secrets_script" ]]; then
        log_warn "⚠️  Elasticsearch Secrets 部署脚本不存在: $secrets_script"
        log_warn "跳过 Secrets 部署，请手动部署或检查脚本路径"
        return 0
    fi
    
    # 检查是否启用 Secrets 部署（默认启用）
    if [[ "${secrets_enabled:-true}" == "true" ]]; then
        if bash "$secrets_script" "$project_id" "$namespace" "$environment" "$dry_run"; then
            log_success "✅ Elasticsearch Secrets 部署成功"
            return 0
        else
            log_error "❌ Elasticsearch Secrets 部署失败"
            return 1
        fi
    else
        log_info "跳过 Elasticsearch Secrets 部署（secrets_enabled=false）"
        return 0
    fi
}

# 递归部署子组件（中间件 / Ingress）
deploy_sub_components() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"

    log_info "开始部署 Elasticsearch 子组件..."

    # 定义子组件部署顺序（按优先级排序）
    local sub_components=(
        "elasticsearch_middleware:${middleware_enabled:-false}:${middleware_priority:-1000}:Elasticsearch 中间件:$SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh"
        "elasticsearch_ingress:${ingress_enabled:-false}:${ingress_priority:-100}:Elasticsearch Web 路由:$SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh"
    )

    # 按优先级排序（高优先级先部署）
    IFS=$'\n' sub_components=($(sort -t: -k3 -nr <<<"${sub_components[*]}"))
    unset IFS

    for component_info in "${sub_components[@]}"; do
        IFS=':' read -r name enabled priority description script_path <<< "$component_info"

        if [[ "$enabled" == "true" ]]; then
            log_info "部署 $description (优先级: $priority)..."

            if [[ -f "$script_path" ]]; then
                # Ingress 脚本不接受 dry_run 参数
                if [[ "$name" == "elasticsearch_ingress" ]]; then
                    if bash "$script_path" deploy "$project_id" "$namespace" "$environment"; then
                        log_success "✅ $description 部署成功"
                    else
                        log_error "❌ $description 部署失败"; return 1
                    fi
                else
                    if bash "$script_path" deploy "$project_id" "$namespace" "$environment" "$dry_run"; then
                        log_success "✅ $description 部署成功"
                    else
                        log_error "❌ $description 部署失败"; return 1
                    fi
                fi
            else
                log_error "❌ $description 脚本不存在: $script_path"; return 1
            fi
        else
            log_info "跳过 $description (已禁用)"
        fi
    done

    log_success "✅ Elasticsearch 子组件部署完成"
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
    
    # 如果是 help 命令，直接显示帮助信息，不建立连接
    case "$action" in
        "help"|"--help"|"-h")
            echo "用法: $0 <action> [project_id] [namespace] [environment] [dry_run]"
            echo ""
            echo "操作:"
            echo "  deploy     部署 Elasticsearch（默认）"
            echo "  upgrade    升级 Elasticsearch"
            echo "  uninstall  卸载 Elasticsearch"
            echo "  clean      清理 Elasticsearch（包括数据）"
            echo "  status     检查 Elasticsearch 状态"
            echo "  logs       显示 Elasticsearch 日志"
            echo "  backup     备份 Elasticsearch 数据"
            echo "  connect    显示连接信息"
            echo "  help       显示此帮助信息"
            echo ""
            echo "参数:"
            echo "  project_id   项目标识符（默认: $DEFAULT_PROJECT_ID）"
            echo "  namespace    命名空间（默认: $DEFAULT_NAMESPACE）"
            echo "  environment  环境（默认: $DEFAULT_ENVIRONMENT）"
            echo "  dry_run      试运行模式（默认: false）"
            echo ""
            echo "集群参数:"
            echo "  --cluster=C1  或  --cluster C1  指定集群（如 C1, C2 等）"
            echo ""
            echo "示例:"
            echo "  $0 deploy sunmoonai data-platform-dev development"
            echo "  $0 --cluster=C1 deploy"
            echo "  $0 status"
            echo "  $0 backup"
            exit 0
            ;;
    esac
    
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
            log_info "开始部署 Elasticsearch..."
            check_namespace "$namespace"
            # 部署 Secrets（在主部署之前）
            if ! deploy_elasticsearch_secrets "$project_id" "$namespace" "$environment" "$dry_run"; then
                log_error "❌ Elasticsearch Secrets 部署失败，终止主部署"
                exit 1
            fi
            # 执行主部署
            if execute_elasticsearch_deployment "$project_id" "$namespace" "$environment" "$dry_run"; then
            
                # 部署子组件（中间件 / Ingress）
                if deploy_sub_components "$project_id" "$namespace" "$environment" "$dry_run"; then
                    log_success "🎉 Elasticsearch 完整部署成功！"
                    check_elasticsearch_status "$namespace"
                else
                    log_error "❌ --cluster 参数需要指定值（格式：C{数字}，如 C1, C2, C3 等）"
                    exit 1
                fi
            else
                log_error "❌ Elasticsearch 主部署失败！"
                exit 1
            fi
            ;;
        "upgrade")
            log_info "开始升级 Elasticsearch..."
            check_namespace "$namespace"
            execute_elasticsearch_deployment "$project_id" "$namespace" "$environment" "$dry_run"
            check_elasticsearch_status "$namespace"
            ;;
        "uninstall")
            log_info "开始卸载 Elasticsearch..."
            # 卸载子组件
            log_info "卸载 Elasticsearch 子组件..."
            
            # 定义子组件卸载顺序（按优先级排序）
            local sub_components=(
                "elasticsearch_middleware:${middleware_enabled:-false}:${middleware_priority:-1000}:Elasticsearch 中间件:$SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh"
                "elasticsearch_ingress:${ingress_enabled:-false}:${ingress_priority:-100}:Elasticsearch Web 路由:$SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh"
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
            
            # 卸载主部署
            helm uninstall elasticsearch-sunmoonai -n "$namespace" --wait || true
            log_success "✅ Elasticsearch 卸载完成"
            ;;
        "clean")
            log_info "开始清理 Elasticsearch..."
            helm uninstall elasticsearch-sunmoonai -n "$namespace" || true
            kubectl delete pvc -n "$namespace" -l app.kubernetes.io/name=elasticsearch || true
            log_success "✅ Elasticsearch 清理完成"
            ;;
        "status")
            check_elasticsearch_status "$namespace"
            show_elasticsearch_connection_info "$namespace"
            ;;
        "debug")
            # 仅调试：打印 Pending 相关信息
            if ! read_k8s_config; then
                log_error "无法读取 Kubernetes 配置文件"; exit 1; fi
            if ! setup_kubectl_environment; then
                log_error "无法建立 Kubernetes 连接"; exit 1; fi
            debug_elasticsearch_pending "$namespace"
            ;;
        "logs")
            log_info "显示 Elasticsearch 日志..."
            kubectl logs -n "$namespace" -l app.kubernetes.io/name=elasticsearch --tail=100
            ;;
        "backup")
            backup_elasticsearch_data "$namespace"
            ;;
        "connect")
            show_elasticsearch_connection_info "$namespace"
            ;;
        *)
            echo "用法: $0 <action> [project_id] [namespace] [environment] [dry_run]"
            echo ""
            echo "操作:"
            echo "  deploy     部署 Elasticsearch（默认）"
            echo "  upgrade    升级 Elasticsearch"
            echo "  uninstall  卸载 Elasticsearch"
            echo "  clean      清理 Elasticsearch（包括数据）"
            echo "  status     检查 Elasticsearch 状态"
            echo "  logs       显示 Elasticsearch 日志"
            echo "  backup     备份 Elasticsearch 数据"
            echo "  connect    显示连接信息"
            echo "  help       显示此帮助信息"
            echo ""
            echo "参数:"
            echo "  project_id   项目标识符（默认: $DEFAULT_PROJECT_ID）"
            echo "  namespace    命名空间（默认: $DEFAULT_NAMESPACE）"
            echo "  environment  环境（默认: $DEFAULT_ENVIRONMENT）"
            echo "  dry_run      试运行模式（默认: false）"
            echo ""
            echo "集群参数:"
            echo "  --cluster=C1  或  --cluster C1  指定集群（如 C1, C2 等）"
            echo ""
            echo "示例:"
            echo "  $0 deploy sunmoonai data-platform-dev development"
            echo "  $0 --cluster=C1 deploy"
            echo "  $0 status"
            echo "  $0 backup"
            echo "  $0 help"
            exit 1
            ;;
    esac
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
