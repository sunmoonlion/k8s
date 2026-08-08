#!/bin/bash

# ONLYOFFICE Docs 递归部署脚本
# 基于递归架构设计原则的两级部署逻辑

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 保存 ONLYOFFICE Docs 脚本的目录路径（统一部署模板会重新定义 SCRIPT_DIR）
ONLYOFFICE_SCRIPT_DIR="$SCRIPT_DIR"

# 导入统一部署模板
source "$PROJECT_ROOT/../../../utils/unified-deployment-template.sh"

# 恢复 ONLYOFFICE Docs 脚本的目录路径
SCRIPT_DIR="$ONLYOFFICE_SCRIPT_DIR"

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

ONLYOFFICE_CONFIG_FILE="$SCRIPT_DIR/deploy-onlyoffice-docs.conf"
if [[ -f "$ONLYOFFICE_CONFIG_FILE" ]]; then
    source "$ONLYOFFICE_CONFIG_FILE"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
    
    log_info "已加载 ONLYOFFICE Docs 配置文件: $ONLYOFFICE_CONFIG_FILE"
else
    log_error "缺少 ONLYOFFICE Docs 配置文件: $ONLYOFFICE_CONFIG_FILE"
    exit 1
fi

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="app-platform-dev"
DEFAULT_ENVIRONMENT="development"

# ONLYOFFICE Docs 资源目录（固定路径）
ONLYOFFICE_CHART_DIR="$SCRIPT_DIR/resources/onlyoffice-docs"
ONLYOFFICE_CUSTOM_VALUES_DIR="$SCRIPT_DIR/resources/custom-values"

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

# 执行 ONLYOFFICE Docs 部署
execute_onlyoffice_deployment() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="${4:-false}"
    
    log_info "准备部署 ONLYOFFICE Docs..."
    
    # 检查 Chart 目录是否存在
    if [[ ! -d "$ONLYOFFICE_CHART_DIR" ]]; then
        log_error "❌ ONLYOFFICE Docs Chart 目录不存在: $ONLYOFFICE_CHART_DIR"
        return 1
    fi
    
    # 根据环境选择 values 文件
    local values_file=""
    case "$environment" in
        "development"|"dev")
            values_file="$ONLYOFFICE_CUSTOM_VALUES_DIR/dev-values.yaml"
            ;;
        "production"|"prod")
            values_file="$ONLYOFFICE_CUSTOM_VALUES_DIR/prod-values.yaml"
            ;;
        *)
            log_warn "⚠️  未知环境: $environment，使用 dev-values.yaml"
            values_file="$ONLYOFFICE_CUSTOM_VALUES_DIR/dev-values.yaml"
            ;;
    esac
    
    if [[ ! -f "$values_file" ]]; then
        log_error "❌ Values 文件不存在: $values_file"
        return 1
    fi
    
    log_info "使用 Values 文件: $values_file"
    
    # 构建 Helm 命令
    local release_name="onlyoffice-docs-${project_id}"
    local helm_cmd="helm upgrade --install $release_name $ONLYOFFICE_CHART_DIR"
    helm_cmd="$helm_cmd -n $namespace"
    helm_cmd="$helm_cmd --create-namespace"
    helm_cmd="$helm_cmd -f $values_file"
    
    # 设置镜像仓库
    if [[ -n "${ONLYOFFICE_IMAGE_REGISTRY:-}" ]]; then
        helm_cmd="$helm_cmd --set global.imageRegistry=${ONLYOFFICE_IMAGE_REGISTRY}"
    fi
    
    # 设置镜像拉取密钥
    if [[ -n "${ONLYOFFICE_IMAGE_PROJECT:-}" ]]; then
        helm_cmd="$helm_cmd --set global.imagePullSecrets[0].name=harbor-registry-secret"
    fi
    
    # 设置镜像拉取策略为 Always，确保总是拉取最新镜像
    helm_cmd="$helm_cmd --set global.imagePullPolicy=Always"
    
    if [[ "$dry_run" == "true" ]]; then
        helm_cmd="$helm_cmd --dry-run"
        log_info "执行 ONLYOFFICE Docs 部署（试运行模式）..."
    else
        log_info "执行 ONLYOFFICE Docs 部署..."
    fi
    
    # 执行部署
    if eval "$helm_cmd"; then
        if [[ "$dry_run" == "true" ]]; then
            log_success "✅ ONLYOFFICE Docs 部署试运行完成"
        else
            log_success "✅ ONLYOFFICE Docs 部署完成"
        fi
        return 0
    else
        log_error "❌ ONLYOFFICE Docs 部署失败"
        return 1
    fi
}

# 检查 ONLYOFFICE Docs 状态
check_onlyoffice_status() {
    local namespace="$1"
    
    log_info "检查 ONLYOFFICE Docs 部署状态..."
    
    # 确保 Kubernetes 连接已建立
    if ! setup_kubectl_environment; then
        log_error "❌ 无法建立 Kubernetes 连接"
        return 1
    fi
    
    # 检查 Helm Release
    local release_name="onlyoffice-docs-${ONLYOFFICE_PROJECT_ID:-sunmoonai}"
    if helm list -n "$namespace" | grep -q "$release_name"; then
        log_success "✅ ONLYOFFICE Docs Helm Release 存在"
    else
        log_error "❌ ONLYOFFICE Docs Helm Release 不存在"
        return 1
    fi
    
    # 检查 Pod 状态
    local pods_info
    pods_info=$(kubectl get pods -n "$namespace" -l app.kubernetes.io/name=onlyoffice-docs -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}' 2>/dev/null || echo "")
    
    if [[ -z "$pods_info" ]]; then
        log_warn "⚠️  未找到 ONLYOFFICE Docs Pod（可能正在创建中）"
        pods_info=$(kubectl get pods -n "$namespace" -l app.kubernetes.io/instance="$release_name" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}' 2>/dev/null || echo "")
        if [[ -z "$pods_info" ]]; then
            log_error "❌ ONLYOFFICE Docs Pod 不存在"
            return 1
        fi
    fi
    
    # 显示所有 Pod 状态
    log_info "ONLYOFFICE Docs Pod 状态："
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
        log_success "✅ ONLYOFFICE Docs Pod 运行正常 (${pods_running}/${pods_total} 个运行中)"
    elif [[ $pods_total -gt 0 ]]; then
        log_warn "⚠️  ONLYOFFICE Docs Pod 存在但未运行 (${pods_total} 个 Pod，0 个运行中)"
        log_info "请等待 Pod 启动或检查 Pod 状态："
        log_info "  kubectl get pods -n $namespace -l app.kubernetes.io/name=onlyoffice-docs"
        log_info "  kubectl describe pods -n $namespace -l app.kubernetes.io/name=onlyoffice-docs"
        return 0
    else
        log_error "❌ ONLYOFFICE Docs Pod 不存在"
        return 1
    fi
}

# 递归部署子组件（中间件 / Ingress）
deploy_sub_components() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"

    log_info "开始部署 ONLYOFFICE Docs 子组件..."

    local sub_components=(
        "onlyoffice_middleware:${middleware_enabled:-false}:${middleware_priority:-1000}:ONLYOFFICE Docs 中间件:$SCRIPT_DIR/../middleware/deploy-middleware-all/deploy-middleware-all.sh"
        "onlyoffice_ingress:${ingress_enabled:-false}:${ingress_priority:-100}:ONLYOFFICE Docs Web 路由:$SCRIPT_DIR/../ingress/deploy-ingress/deploy-ingress.sh"
    )

    IFS=$'\n' sub_components=($(sort -t: -k3 -nr <<<"${sub_components[*]}")); unset IFS

    for component_info in "${sub_components[@]}"; do
        IFS=':' read -r name enabled priority description script_path <<< "$component_info"
        if [[ "$enabled" == "true" ]]; then
            log_info "部署 $description (优先级: $priority)..."
            if [[ -f "$script_path" ]]; then
                if [[ "$name" == "onlyoffice_ingress" ]]; then
                    bash "$script_path" deploy "$project_id" "$namespace" "$environment" || return 1
                else
                    bash "$script_path" deploy "$project_id" "$namespace" "$environment" "$dry_run" || return 1
                fi
            else
                log_error "❌ $description 脚本不存在: $script_path"; return 1
            fi
        fi
    done

    log_success "✅ ONLYOFFICE Docs 子组件部署完成"
    return 0
}

# 显示 ONLYOFFICE Docs 连接信息
show_onlyoffice_connection_info() {
    local namespace="$1"
    
    local unified_host="${ONLYOFFICE_UNIFIED_HOST:-www.sunmoonai.com}"
    local service_name="onlyoffice-docs-${ONLYOFFICE_PROJECT_ID:-sunmoonai}"
    local service_port="${ONLYOFFICE_SERVICE_PORT:-8888}"
    
    echo ""
    echo "=== ONLYOFFICE Docs 连接信息 ==="
    echo "命名空间: $namespace"
    echo "服务名称: $service_name"
    echo "统一域名: $unified_host"
    echo "服务端口: $service_port"
    echo ""
    echo "=== 使用说明 ==="
    echo "1. 通过 Ingress 访问（推荐）:"
    echo "   https://$unified_host:30443/onlyoffice-docs"
    echo "   http://$unified_host:30080/onlyoffice-docs"
    echo ""
    echo "2. 通过 Port Forward 访问:"
    echo "   kubectl port-forward -n $namespace svc/$service_name ${service_port}:${service_port}"
    echo "   curl http://localhost:${service_port}/healthcheck"
    echo ""
    echo "3. API 端点:"
    echo "   - 健康检查: https://$unified_host:30443/onlyoffice-docs/healthcheck"
    echo "   - 转换服务: https://$unified_host:30443/onlyoffice-docs/ConvertService.ashx"
    echo ""
    echo "4. 查看服务状态:"
    echo "   kubectl get pods,svc,ingressroute -n $namespace -l app.kubernetes.io/name=onlyoffice-docs"
    echo ""
}

# 部署 ONLYOFFICE Docs Secrets
deploy_onlyoffice_secrets() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="${4:-false}"
    
    log_info "🚀 部署 ONLYOFFICE Docs Secrets..."
    
    local secrets_script="$SCRIPT_DIR/../secrets/deploy-secrets-all/deploy-secrets-all.sh"
    
    if [[ ! -f "$secrets_script" ]]; then
        log_warn "⚠️  ONLYOFFICE Docs Secrets 部署脚本不存在: $secrets_script"
        log_warn "跳过 Secrets 部署，请手动部署或检查脚本路径"
        return 0
    fi
    
    # 检查是否启用 Secrets 部署（默认启用）
    if [[ "${secrets_enabled:-true}" == "true" ]]; then
        if bash "$secrets_script" "$project_id" "$namespace" "$environment" "$dry_run"; then
            log_success "✅ ONLYOFFICE Docs Secrets 部署成功"
            return 0
        else
            log_error "❌ ONLYOFFICE Docs Secrets 部署失败"
            return 1
        fi
    else
        log_info "跳过 ONLYOFFICE Docs Secrets 部署（secrets_enabled=false）"
        return 0
    fi
}

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
            log_info "开始部署 ONLYOFFICE Docs..."
            check_namespace "$namespace"
            # 部署 Secrets（在主部署之前）
            if ! deploy_onlyoffice_secrets "$project_id" "$namespace" "$environment" "$dry_run"; then
                log_error "❌ ONLYOFFICE Docs Secrets 部署失败，终止主部署"
                exit 1
            fi
            execute_onlyoffice_deployment "$project_id" "$namespace" "$environment" "$dry_run"
            # 子组件：中间件与 Web Ingress
            if deploy_sub_components "$project_id" "$namespace" "$environment" "$dry_run"; then
                check_onlyoffice_status "$namespace"
                show_onlyoffice_connection_info "$namespace"
            else
                log_error "❌ ONLYOFFICE Docs 子组件部署失败"
                exit 1
            fi
            ;;
        "upgrade")
            log_info "开始升级 ONLYOFFICE Docs..."
            check_namespace "$namespace"
            execute_onlyoffice_deployment "$project_id" "$namespace" "$environment" "$dry_run"
            check_onlyoffice_status "$namespace"
            ;;
        "status")
            check_onlyoffice_status "$namespace"
            show_onlyoffice_connection_info "$namespace"
            ;;
        "uninstall")
            log_info "开始卸载 ONLYOFFICE Docs..."
            local release_name="onlyoffice-docs-${project_id}"
            helm uninstall "$release_name" -n "$namespace" || log_warn "卸载失败或 Release 不存在"
            log_success "✅ ONLYOFFICE Docs 卸载完成"
            ;;
        *)
            echo "用法: $0 {deploy|upgrade|status|uninstall} [project_id] [namespace] [environment] [dry_run]"
            echo ""
            echo "参数说明:"
            echo "  action:      deploy (部署) | upgrade (升级) | status (状态) | uninstall (卸载)"
            echo "  project_id:  项目 ID (默认: $DEFAULT_PROJECT_ID)"
            echo "  namespace:  命名空间 (默认: $DEFAULT_NAMESPACE)"
            echo "  environment: 环境 (development|production, 默认: $DEFAULT_ENVIRONMENT)"
            echo "  dry_run:     是否试运行 (true|false, 默认: false)"
            echo ""
            echo "示例:"
            echo "  $0 deploy sunmoonai app-platform-dev development"
            echo "  $0 status sunmoonai app-platform-dev development"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"

