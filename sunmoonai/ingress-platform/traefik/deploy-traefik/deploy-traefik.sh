#!/usr/bin/env bash

# =============================================================================
# Traefik 部署脚本
# - 部署 Traefik Ingress Controller
# - 支持多集群配置
# =============================================================================

# 脚本目录配置
THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$THIS_DIR")"
TRAEFIK_SCRIPT_DIR="$THIS_DIR"

# 导入统一部署模板（建立远程 k8s 连接）
# 计算 utils 路径：当前脚本在 sunmoonai/ingress-platform/traefik/deploy-traefik/
# 向上 4 层到 k8s，然后进入 utils
UTILS_DIR="$(cd "$THIS_DIR/../../../.." && pwd)/utils"
if [[ -f "$UTILS_DIR/unified-deployment-template.sh" ]]; then
    source "$UTILS_DIR/unified-deployment-template.sh"
else
    echo "错误: 找不到统一部署模板: $UTILS_DIR/unified-deployment-template.sh"
    exit 1
fi

# 检查命名空间是否存在
check_namespace() {
    local namespace="$1"
    local max_retries=3
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        if kubectl get namespace "$namespace" >/dev/null 2>&1; then
            log_success "✅ 命名空间 $namespace 已存在"
            return 0
        else
            retry_count=$((retry_count + 1))
            if [[ $retry_count -lt $max_retries ]]; then
                log_warn "⚠️  命名空间 $namespace 检查失败，重试 $retry_count/$max_retries..."
                sleep 2
                # 重新建立连接
                if ! setup_kubectl_environment; then
                    log_error "无法重新建立 Kubernetes 连接"
                    return 1
                fi
            fi
        fi
    done
    
    log_error "❌ 命名空间 $namespace 不存在！"
    echo ""
    log_info "请先使用 namespace-platform 部署所需的命名空间："
    echo "  cd ../../namespace-platform"
    echo "  ./scripts/deploy.sh --env dev"
    echo ""
    log_info "或者手动创建命名空间："
    echo "  kubectl create namespace $namespace"
    echo ""
    return 1
}

# Traefik 资源目录（固定路径）
TRAEFIK_CHART_DIR="$TRAEFIK_SCRIPT_DIR/../resources/traefik/traefik"
TRAEFIK_CRDS_DIR="$TRAEFIK_SCRIPT_DIR/../resources/traefik/traefik-crds"
TRAEFIK_CUSTOM_VALUES_DIR="$TRAEFIK_SCRIPT_DIR/../resources/custom-values"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}


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

# Traefik 配置文件路径
TRAEFIK_CONFIG_FILE="$TRAEFIK_SCRIPT_DIR/deploy-traefik.conf"

# 加载 Traefik 配置文件
load_traefik_config() {
    if [[ ! -f "$TRAEFIK_CONFIG_FILE" ]]; then
        log_error "Traefik 配置文件不存在: $TRAEFIK_CONFIG_FILE"
        return 1
    fi
    
    source "$TRAEFIK_CONFIG_FILE"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
    
    log_info "已加载 Traefik 配置文件: $TRAEFIK_CONFIG_FILE"
    log_info "配置文件加载成功"
    return 0
}

# 定义 Traefik 所需镜像
define_required_images() {
    local environment="$1"
    
    case "$environment" in
        "development"|"dev")
            # 开发环境：只需要主镜像
            echo "traefik:$TRAEFIK_IMAGE_VERSION|true"
            ;;
        "production"|"prod")
            # 生产环境：主镜像
            echo "traefik:$TRAEFIK_PROD_IMAGE_VERSION|true"
            ;;
        *)
            # 默认：只使用主镜像
            echo "traefik:$TRAEFIK_IMAGE_VERSION|true"
            ;;
    esac
}

# 部署子级组件（按优先级，包含 secrets 和 middleware）
deploy_sub_components_by_priority() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始基于优先级的子级组件部署..."
    
    # 定义组件部署信息（组件名:启用标志:优先级:描述:脚本路径）
    local components=(
        "secrets:${secrets_enabled:-false}:${secrets_priority:-2000}:Traefik Secrets:$TRAEFIK_SCRIPT_DIR/secrets/deploy-secrets-all/deploy-secrets-all.sh"
        "middleware:${middleware_enabled:-false}:${middleware_priority:-1000}:Traefik 中间件:$TRAEFIK_SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh"
    )
    
    # 先过滤出启用的组件，然后按优先级排序
    local enabled_components=()
    local disabled_components=()
    
    for component_info in "${components[@]}"; do
        IFS=':' read -r name enabled priority description script_path <<< "$component_info"
        if [[ "$enabled" == "true" ]]; then
            enabled_components+=("$component_info")
        else
            disabled_components+=("$component_info")
        fi
    done
    
    # 根据启用组件数量决定是否进行优先级排序
    if [[ ${#enabled_components[@]} -gt 1 ]]; then
        # 多个组件启用时，按优先级排序（数值越大优先级越高）
        IFS=$'\n' sorted_enabled_components=($(printf '%s\n' "${enabled_components[@]}" | sort -t: -k3 -nr))
        log_info "📋 子级组件部署顺序（按优先级排序）："
        
        for component_info in "${sorted_enabled_components[@]}"; do
            IFS=':' read -r name enabled priority description script_path <<< "$component_info"
            log_info "  🚀 $priority - $description"
        done
    elif [[ ${#enabled_components[@]} -eq 1 ]]; then
        # 只有一个组件启用时，直接使用，无需排序
        sorted_enabled_components=("${enabled_components[@]}")
        IFS=':' read -r name enabled priority description script_path <<< "${enabled_components[0]}"
        log_info "📋 子级组件部署顺序（单个组件，无需排序）："
        log_info "  🚀 $description"
    else
        # 没有启用的组件
        sorted_enabled_components=()
        log_info "📋 子级组件部署顺序：无启用的组件"
    fi
    
    # 显示禁用的组件
    if [[ ${#disabled_components[@]} -gt 0 ]]; then
        log_info "  ⏭️  禁用的组件："
        for component_info in "${disabled_components[@]}"; do
            IFS=':' read -r name enabled priority description script_path <<< "$component_info"
            log_info "    $description (${name}_enabled=false)"
        done
    fi
    
    # 部署启用的组件
    for component_info in "${sorted_enabled_components[@]}"; do
        IFS=':' read -r name enabled priority description script_path <<< "$component_info"
        
        if [[ ${#enabled_components[@]} -gt 1 ]]; then
            log_info "🚀 部署 $description (优先级: $priority)..."
        else
            log_info "🚀 部署 $description..."
        fi
        
        if [[ -f "$script_path" ]]; then
            local original_dir="$(pwd)"
            cd "$(dirname "$script_path")"
            
            # 根据组件类型决定参数传递方式
            # middleware 脚本需要 action 参数，secrets 脚本不需要
            if [[ "$name" == "middleware" ]]; then
                # middleware 脚本参数顺序：action, project_id, namespace, environment, dry_run
                if ./"$(basename "$script_path")" "deploy" "$project_id" "$namespace" "$environment" "$dry_run"; then
                    log_success "✅ $description 部署成功"
                else
                    log_error "❌ $description 部署失败"
                    cd "$original_dir"
                    return 1
                fi
            else
                # 其他脚本（如 secrets）参数顺序：project_id, namespace, environment, dry_run
                if ./"$(basename "$script_path")" "$project_id" "$namespace" "$environment" "$dry_run"; then
                    log_success "✅ $description 部署成功"
                else
                    log_error "❌ $description 部署失败"
                    cd "$original_dir"
                    return 1
                fi
            fi
            
            cd "$original_dir"
        else
            log_warn "⚠️  $description 部署脚本不存在: $script_path"
        fi
    done
    
    log_success "✅ 子级组件部署完成！"
}

# 部署中间件子组件（调用 middleware 级别脚本）
deploy_middleware_components_by_priority() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"

    log_info "开始部署中间件子组件..."

    # 调用 middleware 级别的部署脚本
    local middleware_script="$TRAEFIK_SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh"
    
    if [[ -f "$middleware_script" ]]; then
        local original_dir="$(pwd)"
        cd "$(dirname "$middleware_script")"
        
        # 传递 deploy action 和所有参数
        if ./"$(basename "$middleware_script")" deploy "$project_id" "$namespace" "$environment" "$dry_run"; then
            log_success "✅ 中间件子组件部署成功"
        else
            log_error "❌ 中间件子组件部署失败"
            cd "$original_dir"
            return 1
        fi
        
        cd "$original_dir"
    else
        log_warn "⚠️  中间件部署脚本不存在: $middleware_script"
    fi

    log_success "✅ 中间件子组件部署完成！"
}

# 执行 Traefik 部署
execute_traefik_deployment() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始执行 Traefik 部署..."
    log_info "项目: $project_id"
    log_info "命名空间: $namespace"
    log_info "环境: $environment"
    log_info "干运行: $dry_run"
    
    # 重新建立 Kubernetes 连接（确保连接正常）
    if ! setup_kubectl_environment; then
        log_error "无法建立 Kubernetes 连接"
        return 1
    fi
    
    # 检查命名空间是否存在
    check_namespace "$namespace"
    
    # 检查 Chart 目录
    if [[ ! -d "$TRAEFIK_CHART_DIR" ]]; then
        log_error "Traefik Chart 目录不存在: $TRAEFIK_CHART_DIR"
        return 1
    fi
    
    # 检查自定义配置目录
    if [[ ! -d "$TRAEFIK_CUSTOM_VALUES_DIR" ]]; then
        log_error "Traefik 自定义配置目录不存在: $TRAEFIK_CUSTOM_VALUES_DIR"
        return 1
    fi
    
    # 构建环境特定的 values 文件路径
    local values_file
    case "$environment" in
        "development"|"dev")
            values_file="$TRAEFIK_CUSTOM_VALUES_DIR/dev-values.yaml"
            ;;
        "production"|"prod")
            values_file="$TRAEFIK_CUSTOM_VALUES_DIR/prod-values.yaml"
            ;;
        *)
            log_error "不支持的环境: $environment"
            return 1
            ;;
    esac
    
    if [[ ! -f "$values_file" ]]; then
        log_error "环境配置文件不存在: $values_file"
        return 1
    fi
    
    # 构建 Helm 命令
    local helm_cmd="helm upgrade --install traefik-$project_id $TRAEFIK_CHART_DIR"
    helm_cmd="$helm_cmd --namespace $namespace"
    helm_cmd="$helm_cmd --values $TRAEFIK_CHART_DIR/values.yaml"
    helm_cmd="$helm_cmd --values $values_file"
    helm_cmd="$helm_cmd --set global.projectId=$project_id"
    helm_cmd="$helm_cmd --set global.namespace=$namespace"
    
    if [[ "$dry_run" == "true" ]]; then
        helm_cmd="$helm_cmd --dry-run"
        log_info "执行干运行部署..."
    else
        log_info "执行实际部署..."
    fi
    
    # 执行 Helm 命令
    log_info "执行命令: $helm_cmd"
    local helm_result
    helm_result=$(eval "$helm_cmd" 2>&1)
    local helm_exit_code=$?
    
    if [[ $helm_exit_code -eq 0 ]]; then
        if [[ "$dry_run" == "true" ]]; then
            log_success "✅ Traefik 干运行部署成功！"
        else
            log_success "✅ Traefik 部署成功！"
        fi
        return 0
    else
        # 检查是否是 release 冲突错误
        if echo "$helm_result" | grep -q "cannot re-use a name that is still in use"; then
            log_warning "检测到 release 名称冲突，尝试强制清理后重新部署..."
            
            # 显示当前存在的 release
            log_info "检查当前存在的 Traefik release..."
            local existing_releases=$(helm list -n "$namespace" | grep "traefik-$project_id" || true)
            if [[ -n "$existing_releases" ]]; then
                log_info "发现以下旧的 Traefik release:"
                echo "$existing_releases" | while read -r line; do
                    log_info "  - $line"
                done
            fi
            
            # 强制删除已存在的 release
            log_info "正在清理旧的 release: traefik-$project_id"
            if helm uninstall "traefik-$project_id" -n "$namespace" --wait >/dev/null 2>&1; then
                log_success "✅ 旧的 release 清理成功: traefik-$project_id"
                log_info "等待资源清理完成..."
                sleep 5
                
                # 重新尝试部署
                log_info "重新尝试部署..."
                if eval "$helm_cmd"; then
                    if [[ "$dry_run" == "true" ]]; then
                        log_success "✅ Traefik 干运行部署成功！"
                    else
                        log_success "✅ Traefik 部署成功！"
                    fi
                    return 0
                else
                    log_error "❌ Traefik 重新部署失败！"
                    return 1
                fi
            else
                log_error "无法删除已存在的 release，请手动删除"
                log_error "删除命令: helm uninstall traefik-$project_id -n $namespace --wait"
                return 1
            fi
        else
            log_error "❌ Traefik 部署失败！"
            log_error "错误信息: $helm_result"
            return 1
        fi
    fi
}

# 部署 Traefik CRDs
deploy_traefik_crds() {
    local namespace="$1"
    
    log_info "部署 Traefik CRDs..."
    
    if [[ ! -d "$TRAEFIK_CRDS_DIR" ]]; then
        log_error "Traefik CRDs Chart 目录不存在: $TRAEFIK_CRDS_DIR"
        return 1
    fi
    
    # 检查是否已安装 CRDs (CRDs 是集群级别的)
    # 检查新的 Traefik CRD 名称（traefik.io 域名）
    if kubectl get crd middlewares.traefik.io >/dev/null 2>&1; then
        log_info "Traefik CRDs 已安装，继续部署以确保最新版本"
        # 不跳过，继续部署以确保 CRD 是最新版本（kubectl apply 是幂等的）
    fi
    
    # 部署 CRDs (CRDs 部署到集群级别，不需要命名空间)
    log_info "正在部署 Traefik CRDs..."
    if kubectl apply -f "$TRAEFIK_CRDS_DIR/crds-files/traefik/"; then
        log_success "Traefik CRDs 部署成功"
    else
        log_error "Traefik CRDs 部署失败"
        return 1
    fi
    
    log_success "Traefik CRDs 部署成功"
}

# 检查中间件子组件状态
check_middleware_components_status() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"

    log_info "检查中间件子组件状态..."

    # 调用 middleware 级别的状态检查脚本
    local middleware_script="$TRAEFIK_SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh"
    
    if [[ -f "$middleware_script" ]]; then
        local original_dir="$(pwd)"
        cd "$(dirname "$middleware_script")"
        
        if ./"$(basename "$middleware_script")" status "$project_id" "$namespace" "$environment" "$dry_run"; then
            log_success "✅ 中间件子组件状态检查完成"
        else
            log_warn "⚠️  中间件子组件状态检查异常"
        fi
        
        cd "$original_dir"
    else
        log_warn "⚠️  中间件状态脚本不存在: $middleware_script"
    fi

    log_success "✅ 中间件子组件状态检查完成！"
}

# 检查 Traefik 状态
check_traefik_status() {
    local project_id="$1"
    local namespace="$2"
    
    log_info "检查 Traefik 状态..."
    
    # 检查 Pod 状态
    local pods=$(kubectl get pods -n "$namespace" -l app.kubernetes.io/name=traefik,app.kubernetes.io/instance="traefik-$project_id" -o jsonpath='{.items[*].status.phase}' 2>/dev/null)
    if [[ -z "$pods" ]]; then
        log_error "未找到 Traefik Pod"
        return 1
    fi
    
    local all_running=true
    for pod_status in $pods; do
        if [[ "$pod_status" != "Running" ]]; then
            log_warn "Pod 状态异常: $pod_status"
            all_running=false
        fi
    done
    
    if [[ "$all_running" == "true" ]]; then
        log_success "✅ 所有 Traefik Pod 运行正常"
        return 0
    else
        log_error "❌ 部分 Traefik Pod 状态异常"
        return 1
    fi
}

# 获取中间件子组件日志
get_middleware_components_logs() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    local tail_lines="${5:-50}"

    log_info "获取中间件子组件日志..."

    # 调用 middleware 级别的日志获取脚本
    local middleware_script="$TRAEFIK_SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh"
    
    if [[ -f "$middleware_script" ]]; then
        local original_dir="$(pwd)"
        cd "$(dirname "$middleware_script")"
        
        if ./"$(basename "$middleware_script")" logs "$project_id" "$namespace" "$environment" "$dry_run" "$tail_lines"; then
            log_success "✅ 中间件子组件日志获取完成"
        else
            log_warn "⚠️  中间件子组件日志获取异常"
        fi
        
        cd "$original_dir"
    else
        log_warn "⚠️  中间件日志脚本不存在: $middleware_script"
    fi

    log_success "✅ 中间件子组件日志获取完成！"
}

# 获取 Traefik 日志
get_traefik_logs() {
    local project_id="$1"
    local namespace="$2"
    local tail_lines="${3:-50}"
    
    log_info "获取 Traefik 日志（最近 $tail_lines 行）..."
    
    local pods=$(kubectl get pods -n "$namespace" -l app.kubernetes.io/name=traefik,app.kubernetes.io/instance="traefik-$project_id" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    if [[ -z "$pods" ]]; then
        log_error "未找到 Traefik Pod"
        return 1
    fi
    
    for pod in $pods; do
        log_info "Pod: $pod"
        echo "----------------------------------------"
        kubectl logs -n "$namespace" "$pod" --tail="$tail_lines" 2>/dev/null || log_warn "无法获取 Pod $pod 的日志"
        echo "----------------------------------------"
    done
    
    return 0
}

# 卸载中间件子组件（按优先级反向）
uninstall_middleware_components_by_priority() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"

    log_info "开始卸载中间件子组件..."

    # 调用 middleware 级别的卸载脚本
    local middleware_script="$TRAEFIK_SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh"
    
    if [[ -f "$middleware_script" ]]; then
        local original_dir="$(pwd)"
        cd "$(dirname "$middleware_script")"
        
        # 禁用子脚本的自动清理，保持连接以便后续操作
        if DISABLE_AUTO_CLEANUP=true ./"$(basename "$middleware_script")" uninstall "$project_id" "$namespace" "$environment" "$dry_run"; then
            log_success "✅ 中间件子组件卸载成功"
        else
            log_error "❌ 中间件子组件卸载失败"
            cd "$original_dir"
            return 1
        fi
        
        cd "$original_dir"
    else
        log_warn "⚠️  中间件卸载脚本不存在: $middleware_script"
    fi

    log_success "✅ 中间件子组件卸载完成！"
}

# 卸载 Traefik
uninstall_traefik() {
    local project_id="$1"
    local namespace="$2"
    local clean_pvc="${3:-false}"
    
    log_info "卸载 Traefik..."
    
    # 检查是否已安装
    if ! helm list -n "$namespace" | grep -q "traefik-$project_id"; then
        log_warn "Traefik 未安装或已卸载"
        return 0
    fi
    
    # 执行卸载
    if helm uninstall "traefik-$project_id" -n "$namespace"; then
        log_success "✅ Traefik 卸载成功！"
        
        # 如果需要清理 PVC
        if [[ "$clean_pvc" == "true" ]]; then
            log_info "正在清理相关的 PVC..."
            clean_traefik_pvc "$project_id" "$namespace"
        fi
        
        return 0
    else
        log_error "❌ Traefik 卸载失败！"
        return 1
    fi
}

# 卸载 Traefik CRDs
uninstall_traefik_crds() {
    local namespace="$1"
    
    log_info "卸载 Traefik CRDs..."
    
    # 检查是否已安装
    if ! helm list -n "$namespace" | grep -q "traefik-crds"; then
        log_warn "Traefik CRDs 未安装或已卸载"
        return 0
    fi
    
    # 执行卸载
    if helm uninstall traefik-crds -n "$namespace"; then
        log_success "✅ Traefik CRDs 卸载成功！"
        return 0
    else
        log_error "❌ Traefik CRDs 卸载失败！"
        return 1
    fi
}

# 自动配置所有节点的 iptables 转发规则
configure_nodes_iptables() {
    log_info "开始自动配置所有节点的 iptables 转发规则..."
    
    # 检查脚本是否存在
    local iptables_script="$PROJECT_ROOT/setup-iptables-forward.sh"
    if [[ ! -f "$iptables_script" ]]; then
        log_error "iptables 配置脚本不存在: $iptables_script"
        return 1
    fi
    
    # 加载基础设施配置文件（包含节点配置）
    local infra_config_file="$PROJECT_ROOT/../../infrastructure/deploy-infrastructure-all/deploy-infrastructure-all.conf"
    if [[ ! -f "$infra_config_file" ]]; then
        log_warn "基础设施配置文件不存在: $infra_config_file"
        log_info "无法自动获取节点配置，跳过自动配置"
        log_info "请手动在每个节点上执行: $iptables_script add --persist"
        return 1
    fi
    
    # 加载配置文件
    log_info "加载节点配置: $infra_config_file"
    source "$infra_config_file"
    
    # 应用集群配置映射（将 C{数字}_SERVER_n_* 映射到 SERVER_n_*）
    if [[ -f "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh"
        apply_cluster_config_mapping
        
        # 手动处理 SERVER_n_* 变量的映射（因为 apply_cluster_config_mapping 跳过了这些变量）
        local cluster_selected="${CLUSTER:-}"
        if [[ -n "$cluster_selected" && "$cluster_selected" =~ ^C[0-9]+$ ]]; then
            local cluster_prefix="${cluster_selected}_"
            log_info "应用集群配置映射: $cluster_selected -> SERVER_n_*"
            
            # 遍历所有可能的节点编号（1-20，可根据需要调整）
            for idx in {1..20}; do
                # 检查是否存在集群特定的 SERVER_n_* 配置
                local cluster_public_ip_var="${cluster_prefix}SERVER_${idx}_PUBLIC_IP"
                local cluster_public_ip="${!cluster_public_ip_var:-}"
                
                # 如果存在集群特定的配置，映射所有相关的 SERVER_n_* 变量
                if [[ -n "$cluster_public_ip" ]]; then
                    # 映射所有 SERVER_n_* 变量
                    local server_vars=(
                        "PUBLIC_IP" "LOCAL_IP" "USER" "SECRET" "PASS" "SSH_PORT"
                        "DIR" "CURRENT_HOSTNAME" "CLUSTER_HOSTNAME" "EXTRA_LABELS" "TAINTS" "TYPE"
                    )
                    
                    for var_suffix in "${server_vars[@]}"; do
                        local cluster_var="${cluster_prefix}SERVER_${idx}_${var_suffix}"
                        local base_var="SERVER_${idx}_${var_suffix}"
                        
                        # 如果集群特定配置存在，映射到基础变量
                        if [[ -n "${!cluster_var:-}" ]]; then
                            eval "$base_var=\"${!cluster_var}\""
                        fi
                    done
                fi
            done
        fi
    fi
    
    # 遍历所有节点配置
    local success_count=0
    local fail_count=0
    local node_count=0
    
    local idx=1
    while true; do
        # 获取节点配置变量名
        local public_ip_var="SERVER_${idx}_PUBLIC_IP"
        local user_var="SERVER_${idx}_USER"
        local secret_var="SERVER_${idx}_SECRET"
        local pass_var="SERVER_${idx}_PASS"
        local ssh_port_var="SERVER_${idx}_SSH_PORT"
        local hostname_var="SERVER_${idx}_CLUSTER_HOSTNAME"
        
        # 获取节点配置值
        local node_ip="${!public_ip_var:-}"
        local node_user="${!user_var:-}"
        local node_secret="${!secret_var:-}"
        local node_pass="${!pass_var:-}"
        local node_ssh_port="${!ssh_port_var:-22}"
        local node_hostname="${!hostname_var:-}"
        
        # 如果 PUBLIC_IP 为空，说明没有更多节点
        if [[ -z "$node_ip" ]]; then
            break
        fi
        
        ((node_count++))
        
        # 使用节点主机名或节点编号作为标识
        local node_name="${node_hostname:-节点${idx}}"
        log_info "配置节点 $idx: $node_name (SSH 地址: $node_ip)"
        
        # 确定 SSH 用户（优先使用配置，否则使用环境变量或默认值）
        local ssh_user="${node_user:-${SSH_USER:-root}}"
        local ssh_key="${node_secret:-${SSH_KEY:-$HOME/.ssh/id_rsa}}"
        local ssh_port="${node_ssh_port:-${SSH_PORT:-22}}"
        local ssh_pass="${node_pass:-${SSH_PASSWORD:-}}"
        
        # 显示 SSH 配置信息（用于调试）
        log_info "  SSH 配置: 用户=$ssh_user, 端口=$ssh_port, 密钥=$ssh_key"
        
        # 构建 SSH 命令（使用数组避免空格解析问题）
        local ssh_cmd_array=()
        if [[ -f "$ssh_key" ]]; then
            ssh_cmd_array=("ssh" "-i" "$ssh_key" "-o" "StrictHostKeyChecking=no" "-o" "ConnectTimeout=10" "-p" "$ssh_port" "$ssh_user@$node_ip")
        elif command -v sshpass >/dev/null 2>&1 && [[ -n "$ssh_pass" ]]; then
            ssh_cmd_array=("sshpass" "-p" "$ssh_pass" "ssh" "-o" "StrictHostKeyChecking=no" "-o" "ConnectTimeout=10" "-p" "$ssh_port" "$ssh_user@$node_ip")
        else
            log_warn "  节点 $node_ip: 无法找到 SSH 密钥 ($ssh_key) 且无密码配置，跳过"
            log_info "    提示: 在 deploy-infrastructure-all.conf 中配置 SERVER_${idx}_SECRET 或 SERVER_${idx}_PASS"
            ((fail_count++))
            ((idx++))
            continue
        fi
        
        # 测试 SSH 连接并输出详细错误信息
        log_info "  测试 SSH 连接..."
        local ssh_test_output
        ssh_test_output=$("${ssh_cmd_array[@]}" "mkdir -p /tmp" 2>&1)
        local ssh_test_status=$?
        
        if [[ $ssh_test_status -eq 0 ]]; then
            log_info "  ✓ SSH 连接成功"
        else
            log_warn "  ⚠️  SSH 连接失败 (退出码: $ssh_test_status)"
            log_info "  错误详情: $ssh_test_output"
            log_info "  请检查:"
            log_info "    - SSH 密钥路径是否正确: $ssh_key"
            log_info "    - SSH 端口是否正确: $ssh_port"
            log_info "    - SSH 用户是否正确: $ssh_user"
            log_info "    - 网络连接是否正常"
            log_info "    - 节点防火墙是否允许 SSH 连接"
            ((fail_count++))
            ((idx++))
            continue
        fi
        
        # 复制脚本到节点并执行
        log_info "  复制脚本到节点..."
        # 构建 scp 命令（使用数组避免空格解析问题）
        local scp_cmd_array=()
        if [[ -f "$ssh_key" ]]; then
            scp_cmd_array=("scp" "-i" "$ssh_key" "-o" "StrictHostKeyChecking=no" "-P" "$ssh_port")
        elif command -v sshpass >/dev/null 2>&1 && [[ -n "$ssh_pass" ]]; then
            scp_cmd_array=("sshpass" "-p" "$ssh_pass" "scp" "-o" "StrictHostKeyChecking=no" "-P" "$ssh_port")
        else
            log_warn "  ⚠️  节点 $node_ip: 无法构建 scp 命令（缺少 SSH 密钥或密码）"
            ((fail_count++))
            ((idx++))
            continue
        fi
        
        local scp_output
        scp_output=$("${scp_cmd_array[@]}" "$iptables_script" "$ssh_user@$node_ip:/tmp/setup-iptables-forward.sh" 2>&1)
        local scp_status=$?
        
        if [[ $scp_status -eq 0 ]]; then
            log_info "  ✓ 脚本复制成功"
            log_info "  执行 iptables 配置..."
            local exec_output
            exec_output=$("${ssh_cmd_array[@]}" "chmod +x /tmp/setup-iptables-forward.sh && sudo /tmp/setup-iptables-forward.sh add --persist" 2>&1)
            local exec_status=$?
            
            if [[ $exec_status -eq 0 ]]; then
                log_success "  ✓ 节点 $node_name ($node_ip) 配置成功"
                ((success_count++))
            else
                log_warn "  ⚠️  节点 $node_name ($node_ip) 配置失败（退出码: $exec_status）"
                log_info "  错误详情: $exec_output"
                log_info "  手动执行命令: ssh $ssh_user@$node_ip 'sudo /tmp/setup-iptables-forward.sh add --persist'"
                ((fail_count++))
            fi
        else
            log_warn "  ⚠️  节点 $node_name ($node_ip): 无法复制脚本（退出码: $scp_status）"
            log_info "  错误详情: $scp_output"
            ((fail_count++))
        fi
        
        ((idx++))
    done
    
    log_info ""
    if [[ $success_count -gt 0 ]]; then
        log_success "✓ 成功配置 $success_count 个节点"
    fi
    if [[ $fail_count -gt 0 ]]; then
        log_warn "⚠️  $fail_count 个节点配置失败，请手动配置"
        log_info "手动配置命令:"
        log_info "  scp $iptables_script root@<节点IP>:/tmp/"
        log_info "  ssh root@<节点IP> 'sudo /tmp/setup-iptables-forward.sh add --persist'"
    fi
    
    if [[ $success_count -eq 0 && $fail_count -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

# 清理 Traefik PVC
clean_traefik_pvc() {
    local project_id="$1"
    local namespace="$2"
    
    log_info "清理 Traefik PVC..."
    
    # 查找相关的 PVC
    local pvcs=$(KUBECONFIG="${KUBECONFIG:-}" kubectl get pvc -n "$namespace" -o name | grep "traefik-$project_id" || true)
    
    if [[ -n "$pvcs" ]]; then
        log_info "发现以下 PVC 需要清理:"
        echo "$pvcs"
        
        # 删除 PVC
        echo "$pvcs" | xargs -r env KUBECONFIG="${KUBECONFIG:-}" kubectl delete -n "$namespace"
        
        if [[ $? -eq 0 ]]; then
            log_success "✅ PVC 清理成功！"
        else
            log_error "❌ PVC 清理失败！"
            return 1
        fi
    else
        log_info "未发现需要清理的 PVC"
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
    
    local action="${1:-}"
    local project_id="${2:-}"
    local namespace="${3:-$TRAEFIK_NAMESPACE}"
    local environment="${4:-development}"
    local dry_run="${5:-false}"
    
    
    case "$action" in
        "deploy")
            if [[ -z "$project_id" ]]; then
                log_error "请提供项目ID"
                echo "用法: $0 deploy <project_id> [namespace] [environment] [dry_run]"
                echo "示例: $0 deploy $TRAEFIK_PROJECT_ID"
                echo "示例: $0 deploy $TRAEFIK_PROJECT_ID $TRAEFIK_NAMESPACE development"
                echo "注意: 如果不指定 namespace，将使用配置文件中的默认值: $TRAEFIK_NAMESPACE"
                exit 1
            fi
            
            # 读取 Kubernetes 配置文件
            if ! read_k8s_config; then
                log_error "无法读取 Kubernetes 配置文件"
                return 1
            fi
            
            # 设置 Kubernetes 环境（建立远程连接）
            if ! setup_kubectl_environment; then
                log_error "无法建立 Kubernetes 连接"
                return 1
            fi
            
            # 检查镜像（仅离线模式或强制开启时）
            local force_image_check="${FORCE_IMAGE_CHECK:-false}"
            # 使用组件级配置开关 ENABLE_OFFLINE_IMAGE_CHECK 控制预检查
            local enable_offline_image_check="${ENABLE_OFFLINE_IMAGE_CHECK:-false}"
            if [[ "$force_image_check" == "true" || "$enable_offline_image_check" == "true" ]]; then
                local required_images=$(define_required_images "$environment")
                if ! check_component_images "$project_id" "$namespace" "traefik" "$environment" "$required_images"; then
                    log_error "镜像检查失败，部署终止"
                    generate_image_list "$project_id" "traefik" "$required_images"
                    return 1
                fi
            else
                log_info "在线模式，无需预检查镜像（将在线拉取镜像）"
            fi
            
            # 部署 CRDs
            deploy_traefik_crds "$namespace"
            
            # 部署子级组件（按优先级：secrets > middleware）
            deploy_sub_components_by_priority "$project_id" "$namespace" "$environment" "$dry_run"
            
            # 执行部署
            if execute_traefik_deployment "$project_id" "$namespace" "$environment" "$dry_run"; then
                # 显示部署信息
                log_info "Traefik 部署信息:"
                log_info "项目: $project_id"
                log_info "命名空间: $namespace"
                log_info "服务名称: traefik-$project_id"
                log_info "Chart 目录: $TRAEFIK_CHART_DIR"
                # 显示实际使用的配置文件
                local actual_values_file
                case "$environment" in
                    "development"|"dev")
                        actual_values_file="$TRAEFIK_CUSTOM_VALUES_DIR/dev-values.yaml"
                        ;;
                    "production"|"prod")
                        actual_values_file="$TRAEFIK_CUSTOM_VALUES_DIR/prod-values.yaml"
                        ;;
                    *)
                        actual_values_file="$TRAEFIK_CUSTOM_VALUES_DIR/${environment}-values.yaml"
                        ;;
                esac
                log_info "配置文件: $actual_values_file"
                log_info ""
                log_info "检查部署状态:"
                log_info "kubectl get pods -n $namespace -l app.kubernetes.io/name=traefik"
                log_info "kubectl get svc -n $namespace -l app.kubernetes.io/name=traefik"
                log_info "kubectl logs -n $namespace -l app.kubernetes.io/name=traefik"
                log_info ""
                
                # 自动配置 iptables 转发（仅在非 dry-run 模式下；Kind 集群无需且无法 SSH 到节点）
                if [[ "$dry_run" != "true" ]]; then
                    if [[ "${K8S_TARGET_MODE:-}" == "kind" ]]; then
                        log_info "Kind 集群无需配置节点 iptables，跳过"
                    else
                        log_info "自动配置所有节点的 iptables 端口转发规则..."
                        log_info ""
                        
                        # 检查是否启用自动配置（可通过环境变量控制）
                        local auto_config_iptables="${AUTO_CONFIG_IPTABLES:-true}"
                        if [[ "$auto_config_iptables" == "true" ]]; then
                            if configure_nodes_iptables; then
                                log_success "✓ 所有节点的 iptables 转发规则已配置并持久化"
                            else
                                log_warning "⚠️  部分节点配置失败，请检查上述错误信息并手动配置"
                                log_info ""
                                log_info "手动配置步骤："
                                log_info "1. 将脚本复制到节点："
                                log_info "   scp $PROJECT_ROOT/setup-iptables-forward.sh root@<节点IP>:/tmp/"
                                log_info ""
                                log_info "2. 在节点上执行（需要 root 权限）："
                                log_info "   ssh root@<节点IP>"
                                log_info "   sudo /tmp/setup-iptables-forward.sh add --persist"
                                log_info ""
                                log_info "详细说明请查看："
                                log_info "   $PROJECT_ROOT/setup-iptables-forward.README.md"
                                log_info ""
                                log_info "提示：如果不想自动配置，可设置环境变量 AUTO_CONFIG_IPTABLES=false"
                            fi
                        else
                            log_info "自动配置已禁用（AUTO_CONFIG_IPTABLES=false），跳过 iptables 配置"
                            log_info ""
                            log_info "如需手动配置，请执行："
                            log_info "  $PROJECT_ROOT/setup-iptables-forward.sh add --persist"
                        fi
                    fi
                    log_info ""
                fi
                
                return 0
            else
                log_error "❌ Traefik 部署失败！"
                return 1
            fi
            ;;
        "upgrade")
            if [[ -z "$project_id" ]]; then
                log_error "请提供项目ID"
                echo "用法: $0 upgrade <project_id> [namespace] [environment] [dry_run]"
                echo "示例: $0 upgrade $TRAEFIK_PROJECT_ID"
                echo "示例: $0 upgrade $TRAEFIK_PROJECT_ID $TRAEFIK_NAMESPACE development"
                echo "注意: 如果不指定 namespace，将使用配置文件中的默认值: $TRAEFIK_NAMESPACE"
                exit 1
            fi
            
            log_info "开始升级 Traefik..."
            # 调用部署函数进行升级
            main "deploy" "$project_id" "$namespace" "$environment" "$dry_run"
            ;;
        "uninstall")
            if [[ -z "$project_id" ]]; then
                log_error "请提供项目ID"
                echo "用法: $0 uninstall <project_id> [namespace] [clean_pvc]"
                echo "示例: $0 uninstall $TRAEFIK_PROJECT_ID"
                echo "示例: $0 uninstall $TRAEFIK_PROJECT_ID $TRAEFIK_NAMESPACE true  # 同时清理PVC"
                echo "注意: 如果不指定 namespace，将使用配置文件中的默认值: $TRAEFIK_NAMESPACE"
                exit 1
            fi
            
            local clean_pvc="${5:-false}"
            
            # 设置 Kubernetes 环境
            if ! setup_kubectl_environment; then
                log_error "无法建立 Kubernetes 连接"
                return 1
            fi
            
            # 卸载中间件子组件（按优先级反向）
            uninstall_middleware_components_by_priority "$project_id" "$namespace" "$environment" "$dry_run"
            
            # 确保连接仍然可用
            if ! kubectl get nodes >/dev/null 2>&1; then
                log_info "连接已断开，重新建立连接..."
                if ! setup_kubectl_environment; then
                    log_error "无法重新建立 Kubernetes 连接"
                    return 1
                fi
            fi
            
            if uninstall_traefik "$project_id" "$namespace" "$clean_pvc"; then
                return 0
            else
                return 1
            fi
            ;;
        "clean")
            if [[ -z "$project_id" ]]; then
                log_error "请提供项目ID"
                echo "用法: $0 clean <project_id> [namespace]"
                echo "示例: $0 clean $TRAEFIK_PROJECT_ID"
                echo "示例: $0 clean $TRAEFIK_PROJECT_ID $TRAEFIK_NAMESPACE"
                echo "注意: 如果不指定 namespace，将使用配置文件中的默认值: $TRAEFIK_NAMESPACE"
                exit 1
            fi
            
            # 设置 Kubernetes 环境
            if ! setup_kubectl_environment; then
                log_error "无法建立 Kubernetes 连接"
                return 1
            fi
            
            clean_traefik_pvc "$project_id" "$namespace"
            ;;
        "status")
            if [[ -z "$project_id" ]]; then
                log_error "请提供项目ID"
                echo "用法: $0 status <project_id> [namespace]"
                echo "示例: $0 status $TRAEFIK_PROJECT_ID"
                echo "注意: 如果不指定 namespace，将使用配置文件中的默认值: $TRAEFIK_NAMESPACE"
                exit 1
            fi
            
            # 设置 Kubernetes 环境
            if ! setup_kubectl_environment; then
                log_error "无法建立 Kubernetes 连接"
                return 1
            fi
            
            # 检查中间件子组件状态
            check_middleware_components_status "$project_id" "$namespace" "$environment" "$dry_run"
            
            if check_traefik_status "$project_id" "$namespace"; then
                return 0
            else
                return 1
            fi
            ;;
        "logs")
            if [[ -z "$project_id" ]]; then
                log_error "请提供项目ID"
                echo "用法: $0 logs <project_id> [namespace] [tail_lines]"
                echo "示例: $0 logs $TRAEFIK_PROJECT_ID 100"
                echo "注意: 如果不指定 namespace，将使用配置文件中的默认值: $TRAEFIK_NAMESPACE"
                exit 1
            fi
            
            local tail_lines="${5:-50}"
            
            # 设置 Kubernetes 环境
            if ! setup_kubectl_environment; then
                log_error "无法建立 Kubernetes 连接"
                return 1
            fi
            
            # 获取中间件子组件日志
            get_middleware_components_logs "$project_id" "$namespace" "$environment" "$dry_run" "$tail_lines"
            
            get_traefik_logs "$project_id" "$namespace" "$tail_lines"
            ;;
        "uninstall-crds")
            # 设置 Kubernetes 环境
            if ! setup_kubectl_environment; then
                log_error "无法建立 Kubernetes 连接"
                return 1
            fi
            
            if uninstall_traefik_crds "$namespace"; then
                return 0
            else
                return 1
            fi
            ;;
        "configure-iptables"|"setup-iptables")
            log_info "开始配置所有节点的 iptables 端口转发规则..."
            log_info ""
            
            # 配置所有节点的 iptables 转发规则
            if configure_nodes_iptables; then
                log_success "✓ 所有节点的 iptables 转发规则已配置并持久化"
                log_info ""
                log_info "验证步骤："
                log_info "1. 检查 iptables 规则（在每个节点上执行）："
                log_info "   sudo iptables -t nat -L PREROUTING -n | grep -E '443|30443'"
                log_info "   sudo iptables -t nat -L OUTPUT -n | grep -E '443|30443'"
                log_info ""
                log_info "2. 测试标准端口访问："
                log_info "   curl -k https://<节点IP>:443"
                log_info ""
                return 0
            else
                log_warn "⚠️  部分节点配置失败，请检查上述错误信息并手动配置"
                log_info ""
                log_info "手动配置步骤："
                log_info "1. 将脚本复制到节点："
                log_info "   scp $PROJECT_ROOT/setup-iptables-forward.sh root@<节点IP>:/tmp/"
                log_info ""
                log_info "2. 在节点上执行（需要 root 权限）："
                log_info "   ssh root@<节点IP>"
                log_info "   sudo /tmp/setup-iptables-forward.sh add --persist"
                log_info ""
                log_info "详细说明请查看："
                log_info "   $PROJECT_ROOT/setup-iptables-forward.README.md"
                log_info ""
                return 1
            fi
            ;;
        *)
            echo "Traefik 部署脚本 - 重构版本（支持中间件子组件）"
            echo ""
            echo "用法: $0 <action> <project_id> [additional_params...]"
            echo ""
            echo "操作:"
            echo "  deploy             部署 Traefik（包含中间件子组件）"
            echo "  upgrade            升级 Traefik（包含中间件子组件）"
            echo "  uninstall          卸载 Traefik（包含中间件子组件）"
            echo "  clean              清理 Traefik PVC"
            echo "  status             检查 Traefik 状态（包含中间件子组件）"
            echo "  logs               获取 Traefik 日志（包含中间件子组件）"
            echo "  uninstall-crds     卸载 Traefik CRDs"
            echo "  configure-iptables 配置所有节点的 iptables 转发规则（80/443 -> 30080/30443）"
            echo ""
            echo "详细用法:"
            echo "  deploy:            $0 deploy <project_id> [namespace] [environment] [dry_run]"
            echo "  upgrade:           $0 upgrade <project_id> [namespace] [environment] [dry_run]"
            echo "  uninstall:         $0 uninstall <project_id> [namespace] [clean_pvc]"
            echo "  clean:             $0 clean <project_id> [namespace]"
            echo "  status:            $0 status <project_id> [namespace]"
            echo "  logs:              $0 logs <project_id> [namespace] [tail_lines]"
            echo "  configure-iptables: $0 configure-iptables"
            echo ""
            echo "⚠️  重要提示："
            echo "   - 如果不指定 namespace，将使用配置文件中的默认值: $TRAEFIK_NAMESPACE"
            echo "   - 如果只指定 project_id，environment 默认为 development"
            echo "   - 参数顺序很重要：project_id → namespace → environment → options"
            echo ""
            echo "参数说明:"
            echo "  project_id   项目标识符（必需）"
            echo "  namespace    命名空间（可选，默认: $TRAEFIK_NAMESPACE）"
            echo "  environment  环境（可选，默认: development）"
            echo "  dry_run      干运行模式（可选，默认: false）"
            echo "  clean_pvc    是否清理PVC（可选，默认: false）"
            echo "  tail_lines   日志行数（可选，默认: 50）"
            echo ""
            echo "示例:"
            echo "  # 推荐用法：使用默认命名空间和开发环境"
            echo "  $0 deploy $TRAEFIK_PROJECT_ID"
            echo "  $0 upgrade $TRAEFIK_PROJECT_ID"
            echo "  $0 uninstall $TRAEFIK_PROJECT_ID"
            echo ""
            echo "  # 指定命名空间和环境"
            echo "  $0 deploy $TRAEFIK_PROJECT_ID $TRAEFIK_NAMESPACE development"
            echo "  $0 upgrade $TRAEFIK_PROJECT_ID $TRAEFIK_NAMESPACE production"
            echo "  $0 uninstall $TRAEFIK_PROJECT_ID $TRAEFIK_NAMESPACE true  # 同时清理PVC"
            echo ""
            echo "  # 其他操作"
            echo "  $0 clean $TRAEFIK_PROJECT_ID"
            echo "  $0 status $TRAEFIK_PROJECT_ID"
            echo "  $0 logs $TRAEFIK_PROJECT_ID 100"
            echo ""
            echo "  # 配置 iptables 转发规则（在所有节点上）"
            echo "  $0 configure-iptables"
            echo "  # 或使用别名"
            echo "  $0 setup-iptables"
            echo ""
            echo "环境:"
            echo "  development  开发环境（单副本，基础配置）"
            echo "  production   生产环境（高可用，完整配置）"
            echo ""
            echo "中间件子组件:"
            echo "  - 超时中间件 (timeout)     - 控制请求超时时间"
            echo "  - 缓冲中间件 (buffering)    - 控制请求/响应缓冲"
            echo ""
            echo "注意:"
            echo "  - 清理PVC会永久删除数据，请谨慎使用"
            echo "  - 部署时遇到冲突会自动清理旧的release，但保留PVC和数据"
            echo "  - 中间件子组件按优先级部署：timeout(1000) → buffering(900)"
            echo "  - 可通过配置文件控制中间件子组件的启用/禁用"
            exit 1
            ;;
    esac
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # 加载 Traefik 配置
    if ! load_traefik_config; then
        exit 1
    fi
    
    # 执行主函数
    main "$@"
fi
