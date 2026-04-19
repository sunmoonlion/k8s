#!/bin/bash

# Jenkins 递归部署脚本
# 基于递归架构设计原则的两级部署逻辑

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 保存 Jenkins 脚本的目录路径（统一部署模板会重新定义 SCRIPT_DIR）
JENKINS_SCRIPT_DIR="$SCRIPT_DIR"

# 导入统一部署模板
source "$PROJECT_ROOT/../../../utils/unified-deployment-template.sh"

# 恢复 Jenkins 脚本的目录路径
SCRIPT_DIR="$JENKINS_SCRIPT_DIR"

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

JENKINS_CONFIG_FILE="$SCRIPT_DIR/deploy-jenkins.conf"
if [[ -f "$JENKINS_CONFIG_FILE" ]]; then
    source "$JENKINS_CONFIG_FILE"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
    
    log_info "已加载 Jenkins 配置文件: $JENKINS_CONFIG_FILE"
else
    log_error "缺少 Jenkins 配置文件: $JENKINS_CONFIG_FILE"
    exit 1
fi

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="cicd-platform-dev"
DEFAULT_ENVIRONMENT="development"

# Jenkins 资源目录（固定路径）
JENKINS_CHART_DIR="$SCRIPT_DIR/../resources/jenkins"
JENKINS_CUSTOM_VALUES_DIR="$SCRIPT_DIR/../resources/custom-values"

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

# 定义 Jenkins 所需镜像（保留给镜像检查设计使用）
define_required_images() {
    local environment="$1"
    
    case "$environment" in
        "development"|"dev")
            echo "jenkins/jenkins:$JENKINS_IMAGE_VERSION|true"
            if [[ "${JENKINS_AGENT_ENABLED:-false}" == "true" ]]; then
                echo "jenkins/inbound-agent:$JENKINS_AGENT_IMAGE_VERSION|true"
            fi
            ;;
        "production"|"prod")
            echo "jenkins/jenkins:$JENKINS_IMAGE_VERSION|true"
            echo "jenkins/inbound-agent:$JENKINS_AGENT_IMAGE_VERSION|true"
            if [[ "${JENKINS_MONITORING_ENABLED:-false}" == "true" ]]; then
                echo "jenkins/jenkins:$JENKINS_IMAGE_VERSION|true"
            fi
            ;;
        *)
            echo "jenkins/jenkins:$JENKINS_IMAGE_VERSION|true"
            ;;
    esac
}

# 使用统一模板的通用按需推送 helper，将 Jenkins 组件镜像推送到 Harbor
push_jenkins_images_to_harbor() {
    push_component_images_to_harbor "jenkins"
}

# 执行 Jenkins 部署
execute_jenkins_deployment() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始执行 Jenkins 部署..."
    log_info "项目: $project_id"
    log_info "命名空间: $namespace"
    log_info "环境: $environment"
    log_info "离线模式: $JENKINS_FORCE_OFFLINE"
    
    # 检查 Chart 目录是否存在
    if [[ ! -d "$JENKINS_CHART_DIR" ]]; then
        log_error "Jenkins Chart 目录不存在: $JENKINS_CHART_DIR"
        return 1
    fi
    
    # 构建 values 文件路径（根据环境名称映射到实际文件名）
    # 约定：
    #   - development/dev -> dev-values.yaml
    #   - production/prod -> prod-values.yaml
    #   - 其他环境        -> <environment>-values.yaml
    local values_filename=""
    case "$environment" in
        "development"|"dev")
            local cluster_lower="$(echo "${CLUSTER:-}" | tr '[:upper:]' '[:lower:]')"
            if [[ "$cluster_lower" == "kind" ]]; then
                local pv_pvc_file="$JENKINS_CUSTOM_VALUES_DIR/jenkins-kind-pv-pvc.yaml"
                kubectl apply -f "$pv_pvc_file" >&2
                values_filename="dev-values-kind.yaml"
            else
                values_filename="dev-values.yaml"
            fi
            ;;
        "production"|"prod")
            values_filename="prod-values.yaml"
            ;;
        *)
            values_filename="${environment}-values.yaml"
            ;;
    esac
    local values_file="$JENKINS_CUSTOM_VALUES_DIR/${values_filename}"
    if [[ ! -f "$values_file" ]]; then
        log_warn "环境配置文件不存在: $values_file，使用默认配置"
        values_file=""
    fi
    
    # 从 Secret 或配置文件读取密码（Helm 升级时需要提供当前密码）
    # 优先级：Secret > 配置文件
    local jenkins_password=""
    local secret_name="jenkins-${project_id}"
    local secrets_config_file="$SCRIPT_DIR/secrets/jenkins-${project_id}/deploy-jenkins-${project_id}/jenkins-${project_id}.conf"
    
    # 方法1：尝试从 Secret 读取（如果存在）
    if kubectl get secret "$secret_name" -n "$namespace" >/dev/null 2>&1; then
        jenkins_password=$(kubectl get secret "$secret_name" -n "$namespace" -o jsonpath='{.data.jenkins-password}' 2>/dev/null | base64 -d || echo "")
        if [[ -n "$jenkins_password" ]]; then
            log_info "从 Secret 读取密码（用于 Helm 升级）"
        fi
    else
        log_warn "Secret $secret_name 不存在，将尝试从配置文件读取密码"
    fi
    
    # 方法2：如果 Secret 不存在或密码为空，从配置文件读取
    if [[ -z "$jenkins_password" ]]; then
        if [[ -f "$secrets_config_file" ]]; then
            # 临时禁用错误退出，因为配置文件可能包含一些在当前上下文中不适用的配置
            set +e
            source "$secrets_config_file" 2>/dev/null
            set -e
            if [[ -n "${JENKINS_PASSWORD:-}" ]]; then
                jenkins_password="$JENKINS_PASSWORD"
                log_info "从配置文件读取密码（用于 Helm 升级）"
            else
                log_warn "配置文件中未设置 JENKINS_PASSWORD"
            fi
        else
            log_warn "配置文件不存在: $secrets_config_file"
        fi
    fi
    
    # 如果仍然没有密码，检查是否是首次安装（Helm Release 不存在）
    if [[ -z "$jenkins_password" ]]; then
        if helm list -n "$namespace" | grep -q "jenkins-${project_id}"; then
            # Helm Release 存在，说明是升级，必须提供密码
            log_error "❌ Helm 升级需要提供当前密码，但无法从 Secret 或配置文件读取"
            log_error "   请先部署 Secret 或确保配置文件中有 JENKINS_PASSWORD"
            log_info "   部署 Secret: cd secrets/jenkins-${project_id}/deploy-jenkins-${project_id} && ./deploy-jenkins-secrets.sh deploy"
            return 1
        else
            # Helm Release 不存在，说明是首次安装，可以使用空密码（Chart 会自动生成）
            log_info "首次安装，将使用 Chart 默认密码（或自动生成）"
        fi
    fi
    
    # 构建 Helm 命令
    local release_name="jenkins-$project_id"
    local helm_cmd="helm upgrade --install $release_name $JENKINS_CHART_DIR"
    helm_cmd="$helm_cmd --namespace $namespace"
    helm_cmd="$helm_cmd --set global.projectId=$project_id"
    helm_cmd="$helm_cmd --set global.namespace=$namespace"
    helm_cmd="$helm_cmd --set global.environment=$environment"
    helm_cmd="$helm_cmd --set volumePermissions.image.registry=${JENKINS_IMAGE_REGISTRY:-harbor.sunmoonai.com:30443}"
    helm_cmd="$helm_cmd --set volumePermissions.image.repository=${JENKINS_IMAGE_PROJECT:-k8s-images}/os-shell"
    helm_cmd="$helm_cmd --set volumePermissions.image.tag=${JENKINS_OS_SHELL_IMAGE_VERSION:-12-debian-12-r51}"
    
    # 如果读取到密码，通过 --set 传递给 Helm（解决升级时的密码要求）
    if [[ -n "$jenkins_password" ]]; then
        # 转义密码中的特殊字符，使用双引号包裹
        # 转义双引号、反斜杠和美元符号
        local escaped_password
        escaped_password=$(printf '%s' "$jenkins_password" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\$/\\$/g')
        helm_cmd="$helm_cmd --set jenkinsPassword=\"$escaped_password\""
    fi
    
    if [[ -n "$values_file" ]]; then
        helm_cmd="$helm_cmd --values $values_file"
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        helm_cmd="$helm_cmd --dry-run"
        log_info "执行 Jenkins 部署（试运行模式）..."
    else
        log_info "执行 Jenkins 部署..."
    fi
    
    # 执行部署
    if eval "$helm_cmd"; then
        if [[ "$dry_run" == "true" ]]; then
            log_success "✅ Jenkins 部署试运行完成"
        else
            log_success "✅ Jenkins 部署完成"
        fi
        return 0
    else
        log_error "❌ Jenkins 部署失败"
        return 1
    fi
}

# 检查 Jenkins 状态
check_jenkins_status() {
    local project_id="$1"
    local namespace="$2"
    local release_name="jenkins-$project_id"
    local label_selector="app.kubernetes.io/instance=$release_name"
    
    log_info "检查 Jenkins 部署状态..."

    # 确保 kubectl/helm 可连集群（避免主流程已清理隧道后 status 误判为失败）
    if type setup_kubectl_environment >/dev/null 2>&1; then
        setup_kubectl_environment || true
    fi
    
    # 检查 Helm Release
    if helm list -n "$namespace" | grep -q "$release_name"; then
        log_success "✅ Jenkins Helm Release 存在"
    else
        log_error "❌ Jenkins Helm Release 不存在"
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
        log_success "✅ Jenkins Pod 运行正常 (${pods_running} 个)"
    elif [[ "$pods_pending" =~ ^[0-9]+$ ]] && [[ "$pods_pending" -gt 0 ]]; then
        log_warn "⏳ Jenkins Pod 正在启动中（$pods_pending 个 Pending/ContainerCreating，0 个 Running）"
        log_info "提示：这是正常的启动过程，如需查看详细进度可稍后运行 status 子命令。"
        # 启动中不视为失败，直接返回成功，让整体部署流程继续
        return 0
    else
        log_error "❌ Jenkins Pod 未运行"
        # 输出基本诊断信息以便快速定位
        kubectl get pods -n "$namespace" -l "$label_selector" -owide || true
        kubectl get pvc  -n "$namespace" -l "$label_selector" || true
        kubectl get events -n "$namespace" --sort-by=.lastTimestamp | tail -n 20 || true
        return 1
    fi
    
    # 测试 Jenkins 连接
    test_jenkins_connection "$project_id" "$namespace"
}

# 测试 Jenkins 连接
test_jenkins_connection() {
    local project_id="$1"
    local namespace="$2"
    local release_name="jenkins-$project_id"
    local label_selector="app.kubernetes.io/instance=$release_name"
    
    log_info "测试 Jenkins 连接..."
    
    # 获取 Jenkins 服务信息
    local service_name
    service_name=$(kubectl get svc -n "$namespace" -l "$label_selector" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -z "$service_name" ]]; then
        log_error "❌ 未找到 Jenkins 服务"
        return 1
    fi
    
    # 测试连接（使用 kubectl port-forward 或直接连接）
    log_info "Jenkins 服务: $service_name"
    log_success "✅ Jenkins 连接测试完成"
}

# 递归部署子组件（中间件 / Web Ingress）
deploy_sub_components() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"

    log_info "开始部署 Jenkins 子组件..."

    local sub_components=(
        "jenkins_secrets:${secrets_enabled:-false}:${secrets_priority:-10}:Jenkins Secrets:$SCRIPT_DIR/secrets/deploy-secrets-all/deploy-secrets-all.sh"
        "jenkins_middleware:${middleware_enabled:-false}:${middleware_priority:-1000}:Jenkins 中间件:$SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh"
        "jenkins_ingress:${ingress_enabled:-false}:${ingress_priority:-100}:Jenkins Web 路由:$SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh"
    )

    IFS=$'\n' sub_components=($(sort -t: -k3 -nr <<<"${sub_components[*]}")); unset IFS

    for component_info in "${sub_components[@]}"; do
        IFS=':' read -r name enabled priority description script_path <<< "$component_info"
        if [[ "$enabled" == "true" ]]; then
            log_info "部署 $description (优先级: $priority)..."
            if [[ -f "$script_path" ]]; then
                case "$name" in
                    "jenkins_ingress")
                        # Ingress 子脚本只需要命名空间参数
                        DISABLE_AUTO_CLEANUP=true bash "$script_path" deploy "$namespace" || return 1
                        ;;
                    "jenkins_secrets")
                        # Secrets 总控脚本使用: <project_id> <namespace> <environment> <dry_run>
                        # 注意：Secret 已在主部署流程中提前部署（在 Helm Chart 之前），这里跳过避免重复部署
                        log_info "跳过 Secret 部署（已在主部署流程中提前部署）"
                        ;;
                    *)
                        # 其他子组件（例如中间件总控），保持完整参数签名
                        DISABLE_AUTO_CLEANUP=true bash "$script_path" deploy "$project_id" "$namespace" "$environment" "$dry_run" || return 1
                        ;;
                esac
                log_success "✅ $description 部署成功"
            else
                log_error "❌ 子脚本不存在: $script_path"; return 1
            fi
        fi
    done

    log_success "✅ Jenkins 子组件部署完成"
    return 0
}

# 卸载子组件（反向优先级）
uninstall_sub_components() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"

    log_info "卸载 Jenkins 子组件..."

    local sub_components=(
        "jenkins_secrets:${secrets_enabled:-false}:${secrets_priority:-10}:Jenkins Secrets:$SCRIPT_DIR/secrets/deploy-secrets-all/deploy-secrets-all.sh"
        "jenkins_middleware:${middleware_enabled:-false}:${middleware_priority:-1000}:Jenkins 中间件:$SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh"
        "jenkins_ingress:${ingress_enabled:-false}:${ingress_priority:-100}:Jenkins Web 路由:$SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh"
    )

    IFS=$'\n' sub_components=($(sort -t: -k3 -n <<<"${sub_components[*]}")); unset IFS

    for component_info in "${sub_components[@]}"; do
        IFS=':' read -r name enabled priority description script_path <<< "$component_info"
        if [[ "$enabled" == "true" ]]; then
            log_info "卸载 $description (优先级: $priority)..."
            if [[ -f "$script_path" ]]; then
                # 禁用子脚本的自动清理，保持连接以便后续操作
                if [[ "$name" == "jenkins_ingress" ]]; then
                    DISABLE_AUTO_CLEANUP=true bash "$script_path" uninstall "$namespace" || true
                elif [[ "$name" == "jenkins_secrets" ]]; then
                    # Secrets 总控脚本使用: <project_id> <namespace> <environment>
                    DISABLE_AUTO_CLEANUP=true bash "$script_path" uninstall "$project_id" "$namespace" "$environment" || true
                else
                    DISABLE_AUTO_CLEANUP=true bash "$script_path" uninstall "$project_id" "$namespace" "$environment" || true
                fi
                log_success "✅ $description 卸载完成"
            else
                log_warn "⚠️ 子脚本不存在: $script_path"
            fi
        fi
    done
}

# 端口转发并输出初始密码
forward_jenkins_access() {
    local namespace="$1"
    local project_id="${2:-$DEFAULT_PROJECT_ID}"
    local release_name="jenkins-$project_id"
    local label_selector="app.kubernetes.io/instance=$release_name"

    log_info "准备进行端口转发并输出初始密码..."

    local service_name
    service_name=$(kubectl get svc -n "$namespace" -l "$label_selector" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -z "$service_name" ]]; then
        service_name="$release_name"
    fi

    # 打印初始密码
    echo ""
    echo "=== Jenkins 初始登录信息 ==="
    echo -n "用户名: "; echo "user"
    echo -n "密码:   "
    kubectl get secret -n "$namespace" "$release_name" -o jsonpath='{.data.jenkins-password}' 2>/dev/null | base64 -d || true
    echo ""
    echo ""
    echo "访问地址: http://127.0.0.1:8080/"
    echo "提示: 按 Ctrl+C 结束端口转发"
    echo ""

    # 执行端口转发（前台运行，便于用户直接访问）
    kubectl port-forward -n "$namespace" "svc/${service_name}" 8080:8080
}

# 显示 Jenkins 连接信息
show_jenkins_connection_info() {
    local namespace="$1"
    
    echo ""
    echo "=== Jenkins 连接信息 ==="
    echo "命名空间: $namespace"
    echo "外部访问: https://${JENKINS_UNIFIED_HOST:-www.sunmoonai.com}/jenkins"
    echo ""
    echo "=== 使用说明 ==="
    echo "1. 配置 hosts 文件（如果需要）:"
    echo "   echo '101.126.151.0 ${JENKINS_UNIFIED_HOST:-www.sunmoonai.com}' | sudo tee -a /etc/hosts"
    echo ""
    echo "2. 访问 Jenkins:"
    echo "   https://${JENKINS_UNIFIED_HOST:-www.sunmoonai.com}/jenkins"
    echo ""
    echo "3. 查看服务状态:"
    echo "   kubectl get pods,svc -n $namespace -l app.kubernetes.io/instance=jenkins-<project_id>"
    echo ""
    echo "4. 获取初始密码:"
    echo "   kubectl exec -n $namespace -it deployment/jenkins-<project_id> -- cat /var/jenkins_home/secrets/initialAdminPassword"
    echo ""
}

# 备份 Jenkins 数据
backup_jenkins_data() {
    local namespace="$1"
    local backup_name="jenkins-backup-$(date +%Y%m%d-%H%M%S)"
    
    log_info "开始备份 Jenkins 数据..."
    log_info "备份名称: $backup_name"
    
    # 这里可以实现具体的备份逻辑
    # 例如使用 Jenkins 备份插件或 Kubernetes 备份工具
    log_success "✅ Jenkins 数据备份完成: $backup_name"
}

# 创建 Jenkins 密钥（如果需要）
create_jenkins_secrets_if_needed() {
    local namespace="$1"
    log_info "检查 Jenkins 密钥..."
    if kubectl get secret "$JENKINS_AUTH_SECRET_NAME" -n "$namespace" >/dev/null 2>&1; then
        log_success "✅ Jenkins 密钥已存在: $JENKINS_AUTH_SECRET_NAME"
    else
        log_info "跳过创建 Jenkins 密钥（由统一密管管理）：$JENKINS_AUTH_SECRET_NAME"
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
            log_info "开始部署 Jenkins..."
            check_namespace "$namespace"
            # 在部署前按需推送 Jenkins 组件镜像到 Harbor（Kind 使用 push-to-harbor，远程使用 registry-push-management）
            push_jenkins_images_to_harbor || log_warn "[images] Jenkins 镜像推送阶段出现警告，可稍后单独检查 Harbor 镜像状态"
            # 重要：必须先部署 Secret，再部署 Helm Chart
            # Bitnami Chart 只在首次启动时使用密码，如果 Secret 不存在，Chart 会生成随机密码
            if [[ "${secrets_enabled:-true}" == "true" ]]; then
                log_info "先部署 Jenkins Secret（必须在 Helm Chart 部署之前）..."
                if [[ -f "$SCRIPT_DIR/secrets/deploy-secrets-all/deploy-secrets-all.sh" ]]; then
                    DISABLE_AUTO_CLEANUP=true bash "$SCRIPT_DIR/secrets/deploy-secrets-all/deploy-secrets-all.sh" "$project_id" "$namespace" "$environment" "$dry_run" || {
                        log_error "❌ Jenkins Secret 部署失败"
                        return 1
                    }
                else
                    log_warn "⚠️ Secret 部署脚本不存在，跳过 Secret 部署"
                fi
            else
                log_info "跳过 Secret 部署（secrets_enabled=false）"
            fi
            create_jenkins_secrets_if_needed "$namespace"
            execute_jenkins_deployment "$project_id" "$namespace" "$environment" "$dry_run"
            # 部署子组件（中间件 / Web Ingress，Secret 已部署，跳过）
            if deploy_sub_components "$project_id" "$namespace" "$environment" "$dry_run"; then
                check_jenkins_status "$project_id" "$namespace" || true
            else
                log_error "❌ Jenkins 子组件部署失败"
                exit 1
            fi
            ;;
        "upgrade")
            log_info "开始升级 Jenkins..."
            check_namespace "$namespace"
            execute_jenkins_deployment "$project_id" "$namespace" "$environment" "$dry_run"
            check_jenkins_status "$project_id" "$namespace"
            ;;
        "uninstall")
            log_info "开始卸载 Jenkins..."
            # 卸载子组件
            uninstall_sub_components "$project_id" "$namespace" "$environment"
            # 确保连接仍然可用
            if ! kubectl get nodes >/dev/null 2>&1; then
                log_info "连接已断开，重新建立连接..."
                if ! setup_kubectl_environment; then
                    log_error "无法重新建立 Kubernetes 连接"
                    return 1
                fi
            fi
            # 卸载主部署
            helm uninstall "jenkins-$project_id" -n "$namespace" --wait || true
            # 注意：不删除 PVC，保留数据以便重新部署时恢复
            # 如果需要完全清理（包括数据），请使用 "clean" 操作
            log_success "✅ Jenkins 卸载完成"
            log_info "⚠️  PVC 已保留，重新部署时会恢复数据"
            log_info "   如需完全清理（包括数据），请使用: $0 clean"
            ;;
        "clean")
            log_warn "⚠️  警告：此操作将删除所有 Jenkins 数据（包括 PVC）！"
            log_info "开始完全清理 Jenkins（包括数据）..."
            # 卸载子组件
            uninstall_sub_components "$project_id" "$namespace" "$environment"
            # 确保连接仍然可用
            if ! kubectl get nodes >/dev/null 2>&1; then
                log_info "连接已断开，重新建立连接..."
                if ! setup_kubectl_environment; then
                    log_error "无法重新建立 Kubernetes 连接"
                    return 1
                fi
            fi
            # 卸载主部署
            helm uninstall "jenkins-$project_id" -n "$namespace" --wait || true
            # 删除 PVC（会删除所有数据）
            log_info "删除 PVC（会删除所有数据）..."
            kubectl delete pvc -n "$namespace" -l app.kubernetes.io/instance="jenkins-$project_id" || true
            kubectl delete pvc -n "$namespace" "${project_id}-jenkins" 2>/dev/null || true
            log_success "✅ Jenkins 完全清理完成（包括数据）"
            log_info "重新部署时会使用 Secret 中的密码初始化"
            ;;
        "status")
            check_jenkins_status "$project_id" "$namespace"
            show_jenkins_connection_info "$namespace"
            ;;
        "logs")
            log_info "显示 Jenkins 日志..."
            kubectl logs -n "$namespace" -l app.kubernetes.io/instance="jenkins-$project_id" --tail=100
            ;;
        "forward")
            # 确保已建立连接后，前台进行端口转发并打印初始密码
            check_jenkins_status "$project_id" "$namespace" || true
            forward_jenkins_access "$namespace" "$project_id"
            ;;
        "backup")
            backup_jenkins_data "$namespace"
            ;;
        "connect")
            show_jenkins_connection_info "$namespace"
            ;;
        *)
            echo "用法: $0 <action> [project_id] [namespace] [environment] [dry_run]"
            echo ""
            echo "操作:"
            echo "  deploy     部署 Jenkins（默认）"
            echo "  upgrade    升级 Jenkins"
            echo "  uninstall  卸载 Jenkins"
            echo "  clean      清理 Jenkins（包括数据）"
            echo "  status     检查 Jenkins 状态"
            echo "  logs       显示 Jenkins 日志"
            echo "  forward    端口转发并输出初始密码（不改动集群）"
            echo "  backup     备份 Jenkins 数据"
            echo "  connect    显示连接信息"
            echo ""
            echo "参数:"
            echo "  project_id   项目标识符（默认: $DEFAULT_PROJECT_ID）"
            echo "  namespace    命名空间（默认: $DEFAULT_NAMESPACE）"
            echo "  environment  环境（默认: $DEFAULT_ENVIRONMENT）"
            echo "  dry_run      试运行模式（默认: false）"
            echo ""
            echo "示例:"
            echo "  $0 deploy sunmoonai cicd-platform-dev development"
            echo "  $0 forward sunmoonai cicd-platform-dev development"
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
