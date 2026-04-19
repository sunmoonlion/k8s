#!/bin/bash

# RabbitMQ 递归部署脚本
# 基于递归架构设计原则的两级部署逻辑

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 保存 RabbitMQ 脚本的目录路径（统一部署模板会重新定义 SCRIPT_DIR）
RABBITMQ_SCRIPT_DIR="$SCRIPT_DIR"

# 导入统一部署模板
source "$PROJECT_ROOT/../../../utils/unified-deployment-template.sh"

# 恢复 RabbitMQ 脚本的目录路径
SCRIPT_DIR="$RABBITMQ_SCRIPT_DIR"

# 检查命名空间是否存在
check_namespace() {
    local namespace="$1"
    
    local _ns_err
    _ns_err=$(kubectl get namespace "$namespace" 2>&1)
    if [[ $? -eq 0 ]]; then
        log_success "✅ 命名空间 $namespace 已存在"
        return 0
    elif echo "$_ns_err" | grep -qiE "not.?found|NotFound"; then
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
    else
        log_error "❌ kubectl 连接失败，无法验证命名空间 $namespace（${_ns_err%%$'\n'*}）"
        log_error "请检查 KUBECONFIG 和集群连接状态"
        return 1
    fi
}

# RabbitMQ 资源目录（固定路径）
RABBITMQ_CHART_DIR="$RABBITMQ_SCRIPT_DIR/../resources/rabbitmq"
RABBITMQ_CUSTOM_VALUES_DIR="$RABBITMQ_SCRIPT_DIR/../resources/custom-values"

# 注意：日志函数已由统一部署模板提供，不需要重新定义

# 端口转发并输出初始密码
forward_rabbitmq_access() {
    local project_id="$1"
    local namespace="$2"

    log_info "准备进行端口转发并输出初始密码..."

    local service_name
    service_name=$(kubectl get svc -n "$namespace" -l app.kubernetes.io/name=rabbitmq,app.kubernetes.io/instance="rabbitmq-$project_id" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "rabbitmq-$project_id")

    echo ""
    echo "=== RabbitMQ 初始登录信息（管理控制台） ==="
    echo -n "用户名: "; echo "admin"
    echo -n "密码:   "
    kubectl get secret -n "$namespace" rabbitmq-auth-secret -o jsonpath='{.data.rabbitmq-password}' 2>/dev/null | base64 -d || true
    echo ""
    echo ""
    echo "访问地址（管理控制台）: http://127.0.0.1:15672/"
    echo "提示: 按 Ctrl+C 结束端口转发"
    echo ""

    kubectl port-forward -n "$namespace" "svc/${service_name}" 15672:15672
}

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

# 定义 RabbitMQ 配置文件路径
RABBITMQ_CONFIG_FILE="$SCRIPT_DIR/deploy-rabbitmq.conf"

# 加载 RabbitMQ 配置文件
load_rabbitmq_config() {
    if [[ ! -f "$RABBITMQ_CONFIG_FILE" ]]; then
        log_error "RabbitMQ 配置文件不存在: $RABBITMQ_CONFIG_FILE"
        return 1
    fi
    
    source "$RABBITMQ_CONFIG_FILE"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
    
    log_info "已加载 RabbitMQ 配置文件: $RABBITMQ_CONFIG_FILE"
    log_info "配置文件加载成功"
    return 0
}

# 定义 RabbitMQ 所需镜像（保留给镜像检查设计使用）
define_required_images() {
    local environment="$1"
    
    case "$environment" in
        "development"|"dev")
            echo "bitnamilegacy/rabbitmq:$RABBITMQ_IMAGE_VERSION|true"
            ;;
        "production"|"prod")
            echo "bitnamilegacy/rabbitmq:$RABBITMQ_IMAGE_VERSION|true"
            ;;
        *)
            echo "bitnamilegacy/rabbitmq:$RABBITMQ_IMAGE_VERSION|true"
            ;;
    esac
}

# 使用统一模板的通用按需推送 helper，将 RabbitMQ 组件镜像推送到 Harbor
push_rabbitmq_images_to_harbor() {
    push_component_images_to_harbor "rabbitmq"
}

# 执行 RabbitMQ 部署
execute_rabbitmq_deployment() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始执行 RabbitMQ 部署..."
    log_info "项目: $project_id"
    log_info "命名空间: $namespace"
    log_info "环境: $environment"
    log_info "干运行: $dry_run"
    
    # 检查命名空间是否存在
    check_namespace "$namespace"
    
    # 检查 Chart 目录
    if [[ ! -d "$RABBITMQ_CHART_DIR" ]]; then
        log_error "RabbitMQ Chart 目录不存在: $RABBITMQ_CHART_DIR"
        return 1
    fi
    
    # 检查自定义配置目录
    if [[ ! -d "$RABBITMQ_CUSTOM_VALUES_DIR" ]]; then
        log_error "RabbitMQ 自定义配置目录不存在: $RABBITMQ_CUSTOM_VALUES_DIR"
        return 1
    fi
    
    local values_file
    local cluster_lower="$(echo "${CLUSTER:-}" | tr '[:upper:]' '[:lower:]')"
    case "$environment" in
        "development"|"dev")
            if [[ "$cluster_lower" == "kind" ]]; then
                # Kind：静态 hostPath PV + dev-values-kind.yaml
                local pv_pvc_file="$RABBITMQ_CUSTOM_VALUES_DIR/rabbitmq-kind-pv-pvc.yaml"
                if [[ ! -f "$pv_pvc_file" ]]; then
                    log_error "未找到 Kind 静态 PV/PVC 文件: $pv_pvc_file"
                    return 1
                fi
                log_info "Kind 集群：应用静态 PV/PVC: $pv_pvc_file"
                kubectl apply -f "$pv_pvc_file"
                values_file="$RABBITMQ_CUSTOM_VALUES_DIR/dev-values-kind.yaml"
            else
                # Remote：动态 local-path
                values_file="$RABBITMQ_CUSTOM_VALUES_DIR/dev-values.yaml"
            fi
            ;;
        "production"|"prod")
            values_file="$RABBITMQ_CUSTOM_VALUES_DIR/prod-values.yaml"
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
    local helm_cmd="helm upgrade --install rabbitmq-$project_id $RABBITMQ_CHART_DIR"
    helm_cmd="$helm_cmd --namespace $namespace"
    helm_cmd="$helm_cmd --values $RABBITMQ_CHART_DIR/values.yaml"
    helm_cmd="$helm_cmd --values $values_file"
    helm_cmd="$helm_cmd --set global.projectId=$project_id"
    helm_cmd="$helm_cmd --set global.namespace=$namespace"
    # 统一镜像与安全策略
    helm_cmd="$helm_cmd --set global.imageRegistry=${RABBITMQ_IMAGE_REGISTRY:-harbor.sunmoonai.com:30443}"
    helm_cmd="$helm_cmd --set global.security.allowInsecureImages=true"
    helm_cmd="$helm_cmd --set volumePermissions.image.registry=${RABBITMQ_IMAGE_REGISTRY:-harbor.sunmoonai.com:30443}"
    helm_cmd="$helm_cmd --set volumePermissions.image.repository=${RABBITMQ_IMAGE_PROJECT:-k8s-images}/os-shell"
    helm_cmd="$helm_cmd --set volumePermissions.image.tag=${RABBITMQ_OS_SHELL_IMAGE_VERSION:-12-debian-12-r51}"
    
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
            log_success "✅ RabbitMQ 干运行部署成功！"
        else
            log_success "✅ RabbitMQ 部署成功！"
        fi
        return 0
    else
        # 检查是否是 release 冲突错误或 StatefulSet 更新错误
        if echo "$helm_result" | grep -q "cannot re-use a name that is still in use" || \
           echo "$helm_result" | grep -q "updates to statefulset spec for fields other than"; then
            if echo "$helm_result" | grep -q "cannot re-use a name that is still in use"; then
                log_warn "检测到 release 名称冲突，尝试强制清理后重新部署..."
            else
                log_warn "检测到 StatefulSet 更新限制，尝试强制清理后重新部署..."
            fi
            
            # 显示当前存在的 release
            log_info "检查当前存在的 RabbitMQ release..."
            local existing_releases=$(helm list -n "$namespace" | grep "rabbitmq-$project_id" || true)
            if [[ -n "$existing_releases" ]]; then
                log_info "发现以下旧的 RabbitMQ release:"
                echo "$existing_releases" | while read -r line; do
                    log_info "  - $line"
                done
            fi
            
            # 强制删除已存在的 release
            log_info "正在清理旧的 release: rabbitmq-$project_id"
            if helm uninstall "rabbitmq-$project_id" -n "$namespace" --wait >/dev/null 2>&1; then
                log_success "✅ 旧的 release 清理成功: rabbitmq-$project_id"
                log_info "等待资源清理完成..."
                sleep 5
                
                # 强制清理可能残留的 StatefulSet
                log_info "检查并清理可能残留的 StatefulSet..."
                local statefulset_name="rabbitmq-$project_id"
                if KUBECONFIG="${KUBECONFIG:-}" kubectl get statefulset "$statefulset_name" -n "$namespace" >/dev/null 2>&1; then
                    log_warn "发现残留的 StatefulSet，正在强制删除..."
                    KUBECONFIG="${KUBECONFIG:-}" kubectl delete statefulset "$statefulset_name" -n "$namespace" --force --grace-period=0 >/dev/null 2>&1
                    sleep 3
                fi
                
                # 重新尝试部署
                log_info "重新尝试部署..."
                if eval "$helm_cmd"; then
                    if [[ "$dry_run" == "true" ]]; then
                        log_success "✅ RabbitMQ 干运行部署成功！"
                    else
                        log_success "✅ RabbitMQ 部署成功！"
                    fi
                    return 0
                else
                    log_error "❌ --cluster 参数需要指定值（格式：C{数字}，如 C1, C2, C3 等）"
                    return 1
                fi
            else
                log_error "无法删除已存在的 release，请手动删除"
                log_error "删除命令: helm uninstall rabbitmq-$project_id -n $namespace --wait"
                return 1
            fi
        else
            log_error "❌ RabbitMQ 部署失败！"
            log_error "错误信息: $helm_result"
            return 1
        fi
    fi
}

# 递归部署子组件（Web Ingress）
deploy_sub_components() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"

    log_info "开始部署 RabbitMQ 子组件..."

    # 定义子组件部署顺序（按优先级排序）
    local sub_components=(
        "rabbitmq_secrets:${secrets_enabled:-false}:${secrets_priority:-10}:RabbitMQ 密钥管理:$RABBITMQ_SCRIPT_DIR/secrets/deploy-secrets-all/deploy-secrets-all.sh"
        "rabbitmq_middleware:${middleware_enabled:-false}:${middleware_priority:-1000}:RabbitMQ 中间件:$RABBITMQ_SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh"
        "rabbitmq_ingress:${ingress_enabled:-false}:${ingress_priority:-100}:RabbitMQ Web 路由:$RABBITMQ_SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh"
    )

    # 按优先级排序（高优先级先部署）
    IFS=$'\n' sub_components=($(sort -t: -k3 -nr <<<"${sub_components[*]}"))
    unset IFS

    for component_info in "${sub_components[@]}"; do
        IFS=':' read -r name enabled priority description script_path <<< "$component_info"

        if [[ "$enabled" == "true" ]]; then
            log_info "部署 $description (优先级: $priority)..."

            if [[ -f "$script_path" ]]; then
                # Ingress 和 Secrets 脚本不接受 dry_run 参数
                if [[ "$name" == "rabbitmq_ingress" || "$name" == "rabbitmq_secrets" ]]; then
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

    log_success "✅ RabbitMQ 子组件部署完成"
    return 0
}

# 卸载子组件
uninstall_sub_components() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"

    log_info "卸载 RabbitMQ 子组件..."
    
    # 定义子组件卸载顺序（按优先级排序，卸载时逆序）
    local sub_components=(
        "rabbitmq_secrets:${secrets_enabled:-false}:${secrets_priority:-10}:RabbitMQ 密钥管理:$RABBITMQ_SCRIPT_DIR/secrets/deploy-secrets-all/deploy-secrets-all.sh"
        "rabbitmq_middleware:${middleware_enabled:-false}:${middleware_priority:-1000}:RabbitMQ 中间件:$RABBITMQ_SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh"
        "rabbitmq_ingress:${ingress_enabled:-false}:${ingress_priority:-100}:RabbitMQ Web 路由:$RABBITMQ_SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh"
    )
    
    # 按优先级排序（卸载时反向顺序）
    IFS=$'\n' sub_components=($(sort -t: -k3 -n <<<"${sub_components[*]}"))
    unset IFS
    
    # 卸载子组件（按优先级逆序，即优先级高的后卸载）
    local uninstall_failed=false
    for component_info in "${sub_components[@]}"; do
        IFS=':' read -r name enabled priority description script_path <<< "$component_info"
        if [[ "$enabled" == "true" ]]; then
            log_info "卸载 $description (优先级: $priority)..."
            if [[ -f "$script_path" ]]; then
                # 禁用子脚本的自动清理，保持连接以便后续操作
                if DISABLE_AUTO_CLEANUP=true bash "$script_path" uninstall "$project_id" "$namespace" "$environment"; then
                    log_success "✅ $description 卸载完成"
                else
                    log_warn "⚠️ $description 卸载失败，继续执行..."
                    uninstall_failed=true
                fi
            else
                log_warn "⚠️ $description 脚本不存在: $script_path"
            fi
        fi
    done

    # 清理可能残留的子组件资源（即使脚本执行失败）
    log_info "清理可能残留的子组件资源..."
    kubectl delete ingressroute -n "$namespace" -l component=rabbitmq 2>/dev/null || true
    kubectl delete middleware -n "$namespace" -l component=rabbitmq 2>/dev/null || true
    kubectl delete ingressroute -n "$namespace" rabbitmq-web-route 2>/dev/null || true
    kubectl delete middleware -n "$namespace" rabbitmq-stripprefix rabbitmq-policy 2>/dev/null || true

    if [[ "$uninstall_failed" == "true" ]]; then
        log_warn "⚠️  部分子组件卸载失败，但已尝试清理残留资源"
    else
        log_success "✅ RabbitMQ 子组件卸载完成"
    fi
    
    return 0
}

# 检查 RabbitMQ 状态
check_rabbitmq_status() {
    local project_id="$1"
    local namespace="$2"
    local release_name="rabbitmq-$project_id"
    local label_selector="app.kubernetes.io/instance=$release_name"
    
    log_info "检查 RabbitMQ 状态..."

    # 确保 kubectl/helm 可连集群（避免主流程已清理隧道后 status 误判为失败）
    if type setup_kubectl_environment >/dev/null 2>&1; then
        setup_kubectl_environment || true
    fi
    
    # 检查 Pod 状态（区分“启动中”和“异常未运行”）
    local phases
    phases=$(kubectl get pods -n "$namespace" -l "$label_selector" -o jsonpath='{.items[*].status.phase}' 2>/dev/null || echo "")
    if [[ -z "$phases" ]]; then
        log_error "未找到 RabbitMQ Pod"
        return 1
    fi
    
    # 辅助判断：如果出现常见失败状态，直接判定失败
    local pods_table
    pods_table=$(kubectl get pods -n "$namespace" -l "$label_selector" --no-headers 2>/dev/null || echo "")
    if echo "$pods_table" | grep -qE 'CrashLoopBackOff|ImagePullBackOff|ErrImagePull|CreateContainerConfigError|RunContainerError|Error'; then
        log_error "❌ RabbitMQ Pod 存在失败状态（CrashLoop/ImagePull/Error 等）"
        kubectl get pods -n "$namespace" -l "$label_selector" -owide 2>/dev/null || true
        return 1
    fi
    
    local pods_running pods_pending pods_failed
    pods_running=$(echo "$phases" | tr ' ' '\n' | grep -c '^Running$' 2>/dev/null || echo "0")
    pods_pending=$(echo "$phases" | tr ' ' '\n' | grep -c '^Pending$' 2>/dev/null || echo "0")
    pods_failed=$(echo "$phases" | tr ' ' '\n' | grep -cE '^(Failed|Unknown)$' 2>/dev/null || echo "0")
    pods_running=$(echo "$pods_running" | tr -d '[:space:]'); pods_running=${pods_running:-0}
    pods_pending=$(echo "$pods_pending" | tr -d '[:space:]'); pods_pending=${pods_pending:-0}
    pods_failed=$(echo "$pods_failed" | tr -d '[:space:]'); pods_failed=${pods_failed:-0}
    
    if [[ "$pods_failed" =~ ^[0-9]+$ ]] && [[ "$pods_failed" -gt 0 ]]; then
        log_error "❌ RabbitMQ Pod 存在 Failed/Unknown 状态"
        kubectl get pods -n "$namespace" -l "$label_selector" -owide 2>/dev/null || true
        return 1
    fi
    
    if [[ "$pods_running" =~ ^[0-9]+$ ]] && [[ "$pods_running" -gt 0 ]] && [[ "$pods_pending" -eq 0 ]]; then
        log_success "✅ RabbitMQ Pod 运行正常（Running: $pods_running）"
        return 0
    fi
    
    if [[ "$pods_pending" =~ ^[0-9]+$ ]] && [[ "$pods_pending" -gt 0 ]]; then
        log_warn "⏳ RabbitMQ Pod 正在启动中（Pending: $pods_pending, Running: $pods_running）"
        log_info "提示：这是正常的启动过程，如需查看详细进度可稍后运行 status 子命令。"
        return 0
    fi
    
    log_error "❌ RabbitMQ Pod 状态异常（Running: $pods_running, Pending: $pods_pending）"
    kubectl get pods -n "$namespace" -l "$label_selector" -owide 2>/dev/null || true
    return 1
}

# 获取 RabbitMQ 日志
get_rabbitmq_logs() {
    local project_id="$1"
    local namespace="$2"
    local tail_lines="${3:-50}"
    
    log_info "获取 RabbitMQ 日志（最近 $tail_lines 行）..."
    
    local pods=$(kubectl get pods -n "$namespace" -l app.kubernetes.io/name=rabbitmq,app.kubernetes.io/instance="rabbitmq-$project_id" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    if [[ -z "$pods" ]]; then
        log_error "未找到 RabbitMQ Pod"
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

# 卸载 RabbitMQ
uninstall_rabbitmq() {
    local project_id="$1"
    local namespace="$2"
    local clean_pvc="${3:-false}"
    local release_name="rabbitmq-$project_id"
    
    log_info "卸载 RabbitMQ..."
    
    # 检查是否已安装（使用更可靠的方式）
    # 方法1: 尝试使用 JSON 输出（如果 jq 可用）
    # 方法2: 使用 grep + awk 匹配精确的 release 名称
    local existing_release
    if command -v jq &> /dev/null; then
        existing_release=$(helm list -n "$namespace" --output json 2>/dev/null | jq -r ".[] | select(.name == \"$release_name\") | .name" 2>/dev/null || true)
    fi
    # 如果 jq 不可用或未找到，使用 grep + awk
    if [[ -z "$existing_release" ]]; then
        existing_release=$(helm list -n "$namespace" 2>/dev/null | grep -E "^${release_name}[[:space:]]" | awk '{print $1}' || true)
    fi
    # 如果还是找不到，尝试直接检查 release 是否存在
    if [[ -z "$existing_release" ]]; then
        if helm status "$release_name" -n "$namespace" &>/dev/null; then
            existing_release="$release_name"
        fi
    fi
    
    if [[ -z "$existing_release" ]]; then
        log_warn "RabbitMQ release '$release_name' 未安装或已卸载"
        # 即使 release 不存在，也检查是否有残留资源需要清理
        local remaining_resources
        remaining_resources=$(kubectl get all,ingressroute,middleware -n "$namespace" 2>/dev/null | grep -i "rabbitmq" || true)
        if [[ -n "$remaining_resources" ]]; then
            log_warn "发现残留的 RabbitMQ 资源，尝试清理..."
            kubectl delete ingressroute -n "$namespace" -l component=rabbitmq 2>/dev/null || true
            kubectl delete middleware -n "$namespace" -l component=rabbitmq 2>/dev/null || true
        fi
        return 0
    fi
    
    log_info "发现 RabbitMQ release: $release_name"
    
    # 确保连接可用
    if ! kubectl get nodes >/dev/null 2>&1; then
        log_warn "连接已断开，重新建立连接..."
        if ! setup_kubectl_environment; then
            log_error "无法重新建立 Kubernetes 连接"
            return 1
        fi
    fi
    
    # 执行卸载（使用 --wait 确保资源完全删除）
    log_info "正在卸载 Helm release: $release_name"
    local uninstall_result=0
    if helm uninstall "$release_name" -n "$namespace" --wait --timeout 5m 2>&1; then
        uninstall_result=0
    else
        uninstall_result=$?
        # 如果卸载失败，检查是否是连接问题
        if [[ $uninstall_result -ne 0 ]]; then
            log_warn "Helm 卸载返回错误码: $uninstall_result"
            # 检查连接是否仍然可用
            if ! kubectl get nodes >/dev/null 2>&1; then
                log_warn "连接已断开，尝试重新建立连接并重试..."
                if setup_kubectl_environment; then
                    # 重试一次卸载（不使用 --wait，因为可能已经部分卸载）
                    log_info "重试卸载 Helm release: $release_name"
                    helm uninstall "$release_name" -n "$namespace" --timeout 3m 2>&1 || true
                fi
            fi
        fi
    fi
    
    # 检查 release 是否真的被卸载了
    local release_still_exists=false
    if command -v jq &> /dev/null; then
        if helm list -n "$namespace" --output json 2>/dev/null | jq -r ".[] | select(.name == \"$release_name\") | .name" 2>/dev/null | grep -q "^${release_name}$"; then
            release_still_exists=true
        fi
    else
        if helm list -n "$namespace" 2>/dev/null | grep -E "^${release_name}[[:space:]]" >/dev/null; then
            release_still_exists=true
        fi
    fi
    
    if [[ "$release_still_exists" == "true" ]]; then
        log_warn "⚠️  Release 仍然存在，可能需要手动清理"
        log_warn "请执行: helm uninstall $release_name -n $namespace"
        # 即使 release 还存在，也尝试清理残留资源
    fi
    
    # 如果卸载成功或 release 已不存在，继续清理残留资源
    if [[ $uninstall_result -eq 0 ]] || [[ "$release_still_exists" == "false" ]]; then
        if [[ $uninstall_result -eq 0 ]]; then
            log_success "✅ RabbitMQ Helm release 卸载成功！"
        fi
        
        # 确保连接可用（在清理资源之前）
        if ! kubectl get nodes >/dev/null 2>&1; then
            log_warn "连接已断开，重新建立连接..."
            if ! setup_kubectl_environment; then
                log_error "无法重新建立 Kubernetes 连接，跳过资源清理"
                return 1
            fi
        fi
        
        # 等待 Pod 完全终止（最多等待 30 秒）
        log_info "等待 Pod 完全终止..."
        local wait_count=0
        local max_wait=30
        while [[ $wait_count -lt $max_wait ]]; do
            local terminating_pods
            terminating_pods=$(kubectl get pods -n "$namespace" -l app.kubernetes.io/name=rabbitmq,app.kubernetes.io/instance="rabbitmq-$project_id" --no-headers 2>/dev/null | grep -E "(Terminating|Pending)" || true)
            if [[ -z "$terminating_pods" ]]; then
                break
            fi
            sleep 1
            wait_count=$((wait_count + 1))
        done
        
        if [[ $wait_count -ge $max_wait ]]; then
            log_warn "⚠️  仍有 Pod 处于 Terminating 状态，尝试强制删除..."
            kubectl delete pods -n "$namespace" -l app.kubernetes.io/name=rabbitmq,app.kubernetes.io/instance="rabbitmq-$project_id" --grace-period=0 --force 2>/dev/null || true
            sleep 2
        fi
        
        # 清理可能残留的资源（IngressRoute、Middleware 等）
        log_info "清理残留的 RabbitMQ 资源..."
        local cleaned=false
        
        # 清理 IngressRoute
        if kubectl get ingressroute -n "$namespace" 2>/dev/null | grep -q "rabbitmq"; then
            kubectl delete ingressroute -n "$namespace" -l component=rabbitmq 2>/dev/null && cleaned=true
            kubectl delete ingressroute -n "$namespace" rabbitmq-web-route 2>/dev/null && cleaned=true
        fi
        
        # 清理 Middleware
        if kubectl get middleware -n "$namespace" 2>/dev/null | grep -q "rabbitmq"; then
            kubectl delete middleware -n "$namespace" -l component=rabbitmq 2>/dev/null && cleaned=true
            kubectl delete middleware -n "$namespace" rabbitmq-stripprefix rabbitmq-policy 2>/dev/null && cleaned=true
        fi
        
        if [[ "$cleaned" == "true" ]]; then
            log_info "已清理残留资源"
        fi
        
        # 如果需要清理 PVC
        if [[ "$clean_pvc" == "true" ]]; then
            log_info "正在清理相关的 PVC..."
            clean_rabbitmq_pvc "$project_id" "$namespace"
        fi
        
        # 最终验证（排除 Terminating 状态的 Pod）
        local remaining
        remaining=$(kubectl get all,ingressroute,middleware -n "$namespace" 2>/dev/null | grep -i "rabbitmq" | grep -v "Terminating" || true)
        if [[ -n "$remaining" ]]; then
            log_warn "⚠️  仍有残留资源:"
            echo "$remaining"
            log_info "💡 提示: 如果 Pod 处于 Terminating 状态，这是正常的，Kubernetes 会继续清理"
        else
            log_success "✅ RabbitMQ 完全卸载完成！"
        fi
        
        return 0
    else
        log_error "❌ RabbitMQ 卸载失败！"
        log_error "请手动检查并清理: helm uninstall $release_name -n $namespace"
        return 1
    fi
}

# 清理 RabbitMQ PVC
clean_rabbitmq_pvc() {
    local project_id="$1"
    local namespace="$2"
    
    log_info "清理 RabbitMQ PVC..."
    
    # 查找相关的 PVC
    local pvcs=$(KUBECONFIG="${KUBECONFIG:-}" kubectl get pvc -n "$namespace" -o name | grep "rabbitmq-$project_id" || true)
    
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
    local project_id="${2:-${RABBITMQ_PROJECT_ID:-}}"
    local namespace="${3:-${RABBITMQ_NAMESPACE:-}}"
    local environment="${4:-development}"
    local dry_run="${5:-false}"
    
    
    case "$action" in
        "deploy")
            if [[ -z "$project_id" ]]; then
                log_error "请提供项目ID"
                echo "用法: $0 deploy <project_id> [namespace] [environment] [dry_run]"
                echo "示例: $0 deploy $RABBITMQ_PROJECT_ID $RABBITMQ_NAMESPACE development false"
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
            
            # 执行部署前，按需推送 RabbitMQ 组件镜像到 Harbor（Kind 使用 push-to-harbor，远程使用 registry-push-management）
            push_rabbitmq_images_to_harbor || log_warn "[images] RabbitMQ 镜像推送阶段出现警告，可稍后单独检查 Harbor 镜像状态"
            
            # 执行部署
            if execute_rabbitmq_deployment "$project_id" "$namespace" "$environment" "$dry_run"; then
                # 部署子组件（包括 Secrets、Middleware 和 Ingress，按优先级自动排序）
                if ! deploy_sub_components "$project_id" "$namespace" "$environment" "$dry_run"; then
                    log_error "❌ 子组件部署失败"
                    return 1
                fi
                # 安装后清理控制平面 tar 包
                if [[ -x "$PROJECT_ROOT/../../cicd-platform/harbor/utils/harbor-image-management/harbor-image.sh" ]]; then
                    : # 通用工具已在推送过程中清理，无需额外清理
                fi
                # 显示部署信息
                log_info "RabbitMQ 部署信息:"
                log_info "项目: $project_id"
                log_info "命名空间: $namespace"
                log_info "服务名称: rabbitmq-$project_id"
                log_info "Chart 目录: $RABBITMQ_CHART_DIR"
                log_info ""
                log_info "检查部署状态:"
                log_info "kubectl get pods -n $namespace -l app.kubernetes.io/name=rabbitmq"
                log_info "kubectl get svc -n $namespace -l app.kubernetes.io/name=rabbitmq"
                log_info "kubectl logs -n $namespace -l app.kubernetes.io/name=rabbitmq"
                log_info ""
                log_info "管理界面: http://rabbitmq.sunmoonai.com"
                return 0
            else
                log_error "❌ RabbitMQ 部署失败！"
                return 1
            fi
            ;;
        "upgrade")
            if [[ -z "$project_id" ]]; then
                log_error "请提供项目ID"
                echo "用法: $0 upgrade <project_id> [namespace] [environment] [dry_run]"
                echo "示例: $0 upgrade $RABBITMQ_PROJECT_ID $RABBITMQ_NAMESPACE development false"
                exit 1
            fi
            
            log_info "开始升级 RabbitMQ..."
            # 设置 Kubernetes 环境
            if ! setup_kubectl_environment; then
                log_error "无法建立 Kubernetes 连接"
                return 1
            fi
            # 直接调用部署函数进行升级（避免递归调用 main）
            check_namespace "$namespace"
            execute_rabbitmq_deployment "$project_id" "$namespace" "$environment" "$dry_run"
            check_rabbitmq_status "$project_id" "$namespace" || true
            ;;
        "uninstall")
            # 智能参数处理：
            # 1. 如果 project_id 为空，使用配置文件中的默认值
            # 2. 如果 project_id 是 "deploy"（可能是误传），使用配置文件中的默认值
            # 3. 如果 project_id 看起来像命名空间（包含 "-"），可能是参数顺序错误
            # 4. 如果 namespace 为空或等于 project_id，使用配置文件中的默认值
            
            if [[ -z "$project_id" ]] || [[ "$project_id" == "deploy" ]]; then
                # "deploy" 通常是动作，不是 project_id
                project_id="${RABBITMQ_PROJECT_ID:-sunmoonai}"
                log_info "使用默认项目ID: $project_id"
            elif [[ "$project_id" == *"-"* ]] && [[ "$project_id" != "sunmoonai" ]]; then
                # project_id 包含 "-"，可能是命名空间，交换参数
                log_warn "检测到参数可能顺序错误，尝试自动纠正..."
                if [[ -z "$namespace" ]] || [[ "$namespace" == "sunmoonai" ]] || [[ "$namespace" == "deploy" ]]; then
                    namespace="$project_id"
                    project_id="${RABBITMQ_PROJECT_ID:-sunmoonai}"
                    log_info "已纠正：project_id=$project_id, namespace=$namespace"
                fi
            fi
            
            # 如果 namespace 为空、等于 project_id 或者是 "deploy"（可能是误传），使用配置文件中的默认值
            if [[ -z "$namespace" ]] || [[ "$namespace" == "$project_id" ]] || [[ "$namespace" == "deploy" ]] || [[ "$namespace" == "sunmoonai" ]]; then
                namespace="${RABBITMQ_NAMESPACE:-messaging-platform-dev}"
                log_info "使用默认命名空间: $namespace"
            fi
            
            # 如果 environment 为空，使用默认值
            if [[ -z "$environment" ]]; then
                environment="development"
            fi
            
            local clean_pvc="${5:-false}"
            
            log_info "卸载参数: project_id=$project_id, namespace=$namespace, environment=$environment, clean_pvc=$clean_pvc"
            
            # 设置 Kubernetes 环境
            if ! setup_kubectl_environment; then
                log_error "无法建立 Kubernetes 连接"
                return 1
            fi
            # 先卸载子组件（Web Ingress）
            uninstall_sub_components "$project_id" "$namespace" "$environment"
            
            # 确保连接仍然可用（在卸载主组件之前）
            if ! kubectl get nodes >/dev/null 2>&1; then
                log_info "连接已断开，重新建立连接..."
                if ! setup_kubectl_environment; then
                    log_error "无法重新建立 Kubernetes 连接"
                    return 1
                fi
            fi

            # 执行卸载（函数内部会处理连接问题）
            if uninstall_rabbitmq "$project_id" "$namespace" "$clean_pvc"; then
                return 0
            else
                return 1
            fi
            ;;
        "clean")
            if [[ -z "$project_id" ]]; then
                log_error "请提供项目ID"
                echo "用法: $0 clean <project_id> [namespace]"
                echo "示例: $0 clean $RABBITMQ_PROJECT_ID $RABBITMQ_NAMESPACE"
                exit 1
            fi
            
            # 设置 Kubernetes 环境
            if ! setup_kubectl_environment; then
                log_error "无法建立 Kubernetes 连接"
                return 1
            fi
            
            clean_rabbitmq_pvc "$project_id" "$namespace"
            ;;
        "status")
            if [[ -z "$project_id" ]]; then
                log_error "请提供项目ID"
                echo "用法: $0 status <project_id> [namespace]"
                echo "示例: $0 status $RABBITMQ_PROJECT_ID $RABBITMQ_NAMESPACE"
                exit 1
            fi
            
            # 设置 Kubernetes 环境
            if ! setup_kubectl_environment; then
                log_error "无法建立 Kubernetes 连接"
                return 1
            fi
            
            if check_rabbitmq_status "$project_id" "$namespace"; then
                return 0
            else
                return 1
            fi
            ;;
        "logs")
            if [[ -z "$project_id" ]]; then
                log_error "请提供项目ID"
                echo "用法: $0 logs <project_id> [namespace] [tail_lines]"
                echo "示例: $0 logs $RABBITMQ_PROJECT_ID $RABBITMQ_NAMESPACE 100"
                exit 1
            fi
            
            local tail_lines="${5:-50}"
            
            # 设置 Kubernetes 环境
            if ! setup_kubectl_environment; then
                log_error "无法建立 Kubernetes 连接"
                return 1
            fi
            
            get_rabbitmq_logs "$project_id" "$namespace" "$tail_lines"
            ;;
        "inspect")
            if [[ -z "$project_id" ]]; then
                log_error "请提供项目ID"
                echo "用法: $0 inspect <project_id> [namespace]"
                exit 1
            fi
            # 建立连接
            if ! setup_kubectl_environment; then
                log_error "无法建立 Kubernetes 连接"; return 1; fi
            log_info "获取 RabbitMQ Pod/事件/PVC 信息..."
            kubectl get pods -n "$namespace" -l app.kubernetes.io/name=rabbitmq -owide || true
            local pod
            pod=$(kubectl get pods -n "$namespace" -l app.kubernetes.io/name=rabbitmq -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
            if [[ -n "$pod" ]]; then
                echo "--- describe pod ---"; kubectl describe pod -n "$namespace" "$pod" || true
            else
                log_warn "未找到 Pod"
            fi
            echo "--- pvc ---"; kubectl get pvc -n "$namespace" | grep rabbitmq || true
            echo "--- events (last 80) ---"; kubectl get events -n "$namespace" --sort-by=.lastTimestamp | tail -n 80 || true
            ;;
        "forward")
            if [[ -z "$project_id" ]]; then
                log_error "请提供项目ID"
                echo "用法: $0 forward <project_id> [namespace]"
                exit 1
            fi
            if ! setup_kubectl_environment; then
                log_error "无法建立 Kubernetes 连接"; return 1; fi
            check_rabbitmq_status "$project_id" "$namespace" || true
            forward_rabbitmq_access "$project_id" "$namespace"
            ;;
        *)
            echo "RabbitMQ 部署脚本 - 重构版本"
            echo ""
            echo "用法: $0 <action> <project_id> [additional_params...]"
            echo ""
            echo "操作:"
            echo "  deploy     部署 RabbitMQ"
            echo "  upgrade    升级 RabbitMQ"
            echo "  uninstall  卸载 RabbitMQ"
            echo "  clean      清理 RabbitMQ PVC"
            echo "  status     检查 RabbitMQ 状态"
            echo "  logs       获取 RabbitMQ 日志"
            echo "  forward    端口转发并输出初始密码（不改动集群）"
            echo ""
            echo "详细用法:"
            echo "  deploy:    $0 deploy <project_id> [namespace] [environment] [dry_run]"
            echo "  upgrade:   $0 upgrade <project_id> [namespace] [environment] [dry_run]"
            echo "  uninstall: $0 uninstall <project_id> [namespace] [clean_pvc]"
            echo "  clean:     $0 clean <project_id> [namespace]"
            echo "  status:    $0 status <project_id> [namespace]"
            echo "  logs:      $0 logs <project_id> [namespace] [tail_lines]"
            echo "  forward:   $0 forward $RABBITMQ_PROJECT_ID $RABBITMQ_NAMESPACE   # 端口转发并输出初始密码"
            echo ""
            echo "参数说明:"
            echo "  project_id   项目标识符（必需）"
            echo "  namespace    命名空间（可选，默认: $RABBITMQ_NAMESPACE）"
            echo "  environment  环境（可选，默认: development）"
            echo "  dry_run      干运行模式（可选，默认: false）"
            echo "  clean_pvc    是否清理PVC（可选，默认: false）"
            echo "  tail_lines   日志行数（可选，默认: 50）"
            echo ""
            echo "示例:"
            echo "  $0 deploy $RABBITMQ_PROJECT_ID $RABBITMQ_NAMESPACE development"
            echo "  $0 upgrade $RABBITMQ_PROJECT_ID $RABBITMQ_NAMESPACE production"
            echo "  $0 uninstall $RABBITMQ_PROJECT_ID $RABBITMQ_NAMESPACE"
            echo "  $0 uninstall $RABBITMQ_PROJECT_ID $RABBITMQ_NAMESPACE true  # 同时清理PVC"
            echo "  $0 clean $RABBITMQ_PROJECT_ID $RABBITMQ_NAMESPACE"
            echo "  $0 status $RABBITMQ_PROJECT_ID $RABBITMQ_NAMESPACE"
            echo "  $0 logs $RABBITMQ_PROJECT_ID $RABBITMQ_NAMESPACE 100"
            echo ""
            echo "环境:"
            echo "  development  开发环境（最小配置）"
            echo "  production   生产环境（高可用配置）"
            echo ""
            echo "注意:"
            echo "  - 清理PVC会永久删除数据，请谨慎使用"
            echo "  - 部署时遇到冲突会自动清理旧的release，但保留PVC和数据"
            echo "  - RabbitMQ 的网络访问需要通过 ingress-platform 配置"
            exit 1
            ;;
    esac
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # 加载 RabbitMQ 配置
    if ! load_rabbitmq_config; then
        exit 1
    fi

    # 执行主函数
    main "$@"
fi
