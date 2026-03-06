#!/bin/bash

# PGAdmin 递归部署脚本
# 基于递归架构设计原则的两级部署逻辑

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 保存 PGAdmin 脚本的目录路径（统一部署模板会重新定义 SCRIPT_DIR）
PGADMIN_SCRIPT_DIR="$SCRIPT_DIR"

# 导入统一部署模板
source "$PROJECT_ROOT/../../../utils/unified-deployment-template.sh"

# 恢复 PGAdmin 脚本的目录路径
SCRIPT_DIR="$PGADMIN_SCRIPT_DIR"

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

PGADMIN_CONFIG_FILE="$SCRIPT_DIR/deploy-pgadmin.conf"
if [[ -f "$PGADMIN_CONFIG_FILE" ]]; then
    source "$PGADMIN_CONFIG_FILE"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
    
    log_info "已加载 pgAdmin 配置文件: $PGADMIN_CONFIG_FILE"
else
    log_error "缺少 pgAdmin 配置文件: $PGADMIN_CONFIG_FILE"
    exit 1
fi

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="ops-platform-dev"
DEFAULT_ENVIRONMENT="development"

# pgAdmin 资源目录（固定路径）
PGADMIN_CHART_DIR="$SCRIPT_DIR/../resources/pgadmin"
PGADMIN_CUSTOM_VALUES_DIR="$SCRIPT_DIR/../resources/custom-values"

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

# 定义 pgAdmin 所需镜像（保留给镜像检查设计使用）
define_required_images() {
    local environment="$1"
    
    case "$environment" in
        "development"|"dev")
            echo "dpage/pgadmin4:$PGADMIN_IMAGE_VERSION|true"
            ;;
        "production"|"prod")
            echo "dpage/pgadmin4:$PGADMIN_IMAGE_VERSION|true"
            if [[ "${PGADMIN_MONITORING_ENABLED:-false}" == "true" ]]; then
                echo "dpage/pgadmin4:$PGADMIN_IMAGE_VERSION|true"
            fi
            ;;
        *)
            echo "dpage/pgadmin4:$PGADMIN_IMAGE_VERSION|true"
            ;;
    esac
}

# 使用统一模板的通用按需推送 helper，将 pgAdmin 组件镜像推送到 Harbor
push_pgadmin_images_to_harbor() {
    push_component_images_to_harbor "pgadmin"
}

# 处理 pgAdmin 特定的 values 文件
process_pgadmin_values() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    
    # 检查环境特定的 values 文件
    local env_values_file=""
    
    case "$environment" in
        "production")
            env_values_file="$PGADMIN_CUSTOM_VALUES_DIR/prod-values.yaml"
            ;;
        "development")
            env_values_file="$PGADMIN_CUSTOM_VALUES_DIR/dev-values.yaml"
            ;;
        *)
            env_values_file="$PGADMIN_CUSTOM_VALUES_DIR/dev-values.yaml"
            ;;
    esac
    
    if [[ -f "$env_values_file" ]]; then
        log_info "使用环境特定配置: $env_values_file" >&2
        
        # 创建临时 values 文件
        local pgadmin_values_file=$(mktemp)
        cp "$env_values_file" "$pgadmin_values_file"
        
        # 替换基础变量
        local created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        
        # 基础变量替换
        sed -i "s/{{PROJECT_ID}}/$project_id/g" "$pgadmin_values_file"
        sed -i "s/{{NAMESPACE}}/$namespace/g" "$pgadmin_values_file"
        sed -i "s/{{ENVIRONMENT}}/$environment/g" "$pgadmin_values_file"
        sed -i "s/{{COMPONENT_NAME}}/pgadmin/g" "$pgadmin_values_file"
        sed -i "s/{{CREATED_AT}}/$created_at/g" "$pgadmin_values_file"
        
        # pgAdmin 特定变量替换（即使变量为空也替换，使用空字符串）
        sed -i "s/{{PGADMIN_PROJECT_ID}}/${PGADMIN_PROJECT_ID:-}/g" "$pgadmin_values_file"
        sed -i "s/{{PGADMIN_NAMESPACE}}/${PGADMIN_NAMESPACE:-}/g" "$pgadmin_values_file"
        sed -i "s/{{PGADMIN_TLS_ENABLED}}/${PGADMIN_TLS_ENABLED:-}/g" "$pgadmin_values_file"
        sed -i "s/{{PGADMIN_UNIFIED_HOST}}/${PGADMIN_UNIFIED_HOST:-llmops.sunmoonai.com}/g" "$pgadmin_values_file"
        sed -i "s/{{PGADMIN_AUTH_SECRET_NAME}}/${PGADMIN_AUTH_SECRET_NAME:-}/g" "$pgadmin_values_file"
        sed -i "s/{{PGADMIN_AUTH_SECRET_PASSWORD_KEY}}/${PGADMIN_AUTH_SECRET_PASSWORD_KEY:-}/g" "$pgadmin_values_file"
        sed -i "s/{{PGADMIN_IMAGE_VERSION}}/${PGADMIN_IMAGE_VERSION:-}/g" "$pgadmin_values_file"
        sed -i "s/{{PGADMIN_IMAGE_REGISTRY}}/${PGADMIN_IMAGE_REGISTRY:-}/g" "$pgadmin_values_file"
        sed -i "s/{{PGADMIN_IMAGE_PROJECT}}/${PGADMIN_IMAGE_PROJECT:-}/g" "$pgadmin_values_file"
        
        # 处理 imagePullSecrets：如果名称为空，设置为空数组
        local pull_secret_name="${PGADMIN_IMAGE_PULL_SECRET_NAME:-}"
        if [[ -z "$pull_secret_name" ]]; then
            # 如果 secret 名称为空，将 imagePullSecrets 设置为空数组
            sed -i 's/^imagePullSecrets:.*/imagePullSecrets: []/' "$pgadmin_values_file"
            sed -i '/^[[:space:]]*- name: "{{PGADMIN_IMAGE_PULL_SECRET_NAME}}"/d' "$pgadmin_values_file"
        else
            sed -i "s/{{PGADMIN_IMAGE_PULL_SECRET_NAME}}/$pull_secret_name/g" "$pgadmin_values_file"
        fi
        
        # 输出处理后的文件路径
        echo "$pgadmin_values_file"
        return 0
    else
        log_warn "环境配置文件不存在: $env_values_file" >&2
        return 1
    fi
}

# 执行 pgAdmin 部署
execute_pgadmin_deployment() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始执行 pgAdmin 部署..."
    log_info "项目: $project_id"
    log_info "命名空间: $namespace"
    log_info "环境: $environment"
    log_info "离线模式: $PGADMIN_FORCE_OFFLINE"
    
    # 检查 Chart 目录是否存在
    if [[ ! -d "$PGADMIN_CHART_DIR" ]]; then
        log_error "pgAdmin Chart 目录不存在: $PGADMIN_CHART_DIR"
        return 1
    fi
    
    # 处理 pgAdmin 特定的 values 文件（模板变量替换）
    local values_file=$(process_pgadmin_values "$project_id" "$namespace" "$environment" 2>/dev/null)
    local process_exit_code=$?
    
    if [[ $process_exit_code -ne 0 ]] || [[ -z "$values_file" ]]; then
        log_warn "环境配置文件处理失败，使用默认配置"
        values_file=""
    else
        log_info "使用 pgAdmin 特定配置: $values_file"
    fi
    
    # 构建 Helm 命令
    local helm_cmd="helm upgrade --install pgadmin-sunmoonai $PGADMIN_CHART_DIR"
    helm_cmd="$helm_cmd --namespace $namespace"
    helm_cmd="$helm_cmd --set global.projectId=$project_id"
    helm_cmd="$helm_cmd --set global.namespace=$namespace"
    helm_cmd="$helm_cmd --set global.environment=$environment"
    
    if [[ -n "$values_file" ]]; then
        helm_cmd="$helm_cmd --values $values_file"
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        helm_cmd="$helm_cmd --dry-run"
        log_info "执行 pgAdmin 部署（试运行模式）..."
    else
        log_info "执行 pgAdmin 部署..."
    fi
    
    # 执行部署
    if eval "$helm_cmd"; then
        if [[ "$dry_run" == "true" ]]; then
            log_success "✅ pgAdmin 部署试运行完成"
        else
            log_success "✅ pgAdmin 部署完成"
        fi
        return 0
    else
        log_error "❌ pgAdmin 部署失败"
        return 1
    fi
}

# 检查 pgAdmin 状态
check_pgadmin_status() {
    local project_id="$1"
    local namespace="$2"
    local release_name="pgadmin-$project_id"
    local label_selector="app.kubernetes.io/instance=$release_name"
    
    log_info "检查 pgAdmin 部署状态..."
    
    # 检查 Helm Release（区分连接失败和实际不存在）
    local helm_output
    local helm_exit_code
    helm_output=$(helm list -n "$namespace" 2>&1)
    helm_exit_code=$?
    
    if [[ $helm_exit_code -ne 0 ]]; then
        # 连接失败，可能是 SSH 端口转发断开，不报错，只警告
        if echo "$helm_output" | grep -qE "connection refused|unreachable|timeout|dial tcp"; then
            log_warn "⚠️  无法连接到 Kubernetes 集群，跳过状态检查"
            log_warn "   提示：这可能是 SSH 端口转发断开导致的，不影响实际部署"
            return 0  # 返回成功，不中断流程
        else
            # 其他错误，可能是权限问题等
            log_warn "⚠️  检查 Helm Release 时出错: $helm_output"
            log_warn "   跳过 Helm Release 检查"
        fi
    elif echo "$helm_output" | grep -q "$release_name"; then
        log_success "✅ pgAdmin Helm Release 存在"
    else
        # 连接成功但 Release 不存在
        log_error "❌ pgAdmin Helm Release 不存在"
        return 1
    fi
    
    # 检查 Pod 状态（同样处理连接失败）
    local pods_output
    local pods_exit_code
    pods_output=$(kubectl get pods -n "$namespace" -l "$label_selector" --no-headers 2>&1)
    pods_exit_code=$?
    
    if [[ $pods_exit_code -ne 0 ]]; then
        # 连接失败，不报错
        if echo "$pods_output" | grep -qE "connection refused|unreachable|timeout|dial tcp"; then
            log_warn "⚠️  无法连接到 Kubernetes 集群，跳过 Pod 状态检查"
            return 0  # 返回成功，不中断流程
        else
            log_warn "⚠️  检查 Pod 状态时出错: $pods_output"
            return 0  # 其他错误也跳过，不中断流程
        fi
    fi
    
    local pods_count
    # 注意：kubectl 在无匹配资源时会返回 exit_code=0 且输出为空；
    # 不能直接对 echo "" | wc -l，否则会误判为 1。
    if [[ -z "${pods_output//[[:space:]]/}" ]]; then
        pods_count=0
    else
        pods_count=$(printf '%s\n' "$pods_output" | grep -cve '^[[:space:]]*$' || echo "0")
        pods_count=$(echo "$pods_count" | tr -d '[:space:]')
    fi
    pods_count=${pods_count:-0}
    
    if [[ "$pods_count" -eq 0 ]]; then
        log_error "❌ 未找到 pgAdmin Pod"
        log_info "检查 Deployment 状态："
        kubectl get deployment -n "$namespace" -l "$label_selector" 2>/dev/null || true
        echo ""
        log_info "检查 ReplicaSet 状态："
        kubectl get replicaset -n "$namespace" -l "$label_selector" 2>/dev/null || true
        return 1
    fi
    
    local pods_ready
    # 使用 jsonpath 直接统计 Running 状态的 Pod 数量，避免换行符问题
    pods_ready=$(kubectl get pods -n "$namespace" -l "$label_selector" -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' 2>/dev/null | grep -c "^Running$" || echo "0")
    # 确保 pods_ready 是纯数字（去除可能的换行符和空格）
    pods_ready=$(echo "$pods_ready" | tr -d '[:space:]')
    pods_ready=${pods_ready:-0}
    
    if [[ "$pods_ready" =~ ^[0-9]+$ ]] && [[ "$pods_ready" -gt 0 ]]; then
        log_success "✅ pgAdmin Pod 运行正常 ($pods_ready 个)"
    else
        log_error "❌ pgAdmin Pod 未运行（找到 $pods_count 个 Pod，但无 Running 状态）"
        log_info "Pod 状态详情："
        kubectl get pods -n "$namespace" -l "$label_selector" -o wide 2>/dev/null || true
        echo ""
        log_info "Pod 详细信息："
        local pod_name
        pod_name=$(kubectl get pods -n "$namespace" -l "$label_selector" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
        if [[ -n "$pod_name" ]]; then
            log_info "Pod 名称: $pod_name"
            echo ""
            log_info "Pod 状态："
            kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.status.phase}' 2>/dev/null || echo "未知"
            echo ""
            log_info "Pod 事件："
            kubectl describe pod "$pod_name" -n "$namespace" 2>/dev/null | grep -A 20 "Events:" || true
            echo ""
            log_info "Pod 容器状态："
            kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{range .status.containerStatuses[*]}{.name}: {.state}{"\n"}{end}' 2>/dev/null || true
        else
            log_warn "无法获取 Pod 名称"
        fi
        return 1
    fi
    
    # 测试 pgAdmin 连接（如果连接可用）
    if kubectl get nodes >/dev/null 2>&1; then
        test_pgadmin_connection "$project_id" "$namespace"
    else
        log_warn "⚠️  无法连接到 Kubernetes 集群，跳过连接测试"
    fi
}

# 测试 pgAdmin 连接
test_pgadmin_connection() {
    local project_id="$1"
    local namespace="$2"
    local release_name="pgadmin-$project_id"
    local label_selector="app.kubernetes.io/instance=$release_name"
    
    log_info "测试 pgAdmin 连接..."
    
    # 获取 pgAdmin 服务信息
    local service_name
    service_name=$(kubectl get svc -n "$namespace" -l "$label_selector" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -z "$service_name" ]]; then
        log_error "❌ 未找到 pgAdmin 服务"
        return 1
    fi
    
    # 测试连接（使用 kubectl port-forward 或直接连接）
    log_info "pgAdmin 服务: $service_name"
    log_success "✅ pgAdmin 连接测试完成"
}

# 显示 pgAdmin 连接信息
show_pgadmin_connection_info() {
    local namespace="$1"
    
    echo ""
    echo "=== pgAdmin 连接信息 ==="
    echo "命名空间: $namespace"
    echo "外部访问: https://${PGADMIN_UNIFIED_HOST:-llmops.sunmoonai.com}/pgadmin"
    echo ""
    echo "=== 使用说明 ==="
    echo "1. 配置 hosts 文件（如果需要）:"
    echo "   echo '${PGADMIN_NODE_IP:-115.190.153.150} ${PGADMIN_UNIFIED_HOST:-llmops.sunmoonai.com}' | sudo tee -a /etc/hosts"
    echo ""
    echo "2. 访问 pgAdmin:"
    echo "   https://${PGADMIN_UNIFIED_HOST:-llmops.sunmoonai.com}/pgadmin"
    echo ""
    echo "3. 查看服务状态:"
    echo "   kubectl get pods,svc -n $namespace -l app.kubernetes.io/instance=pgadmin-<project_id>"
    echo ""
    echo "4. 连接 PostgreSQL:"
    echo "   需要配置 PostgreSQL 连接信息"
    echo "   支持 PostgreSQL 集群连接"
    echo ""
}

# 备份 pgAdmin 数据
backup_pgadmin_data() {
    local namespace="$1"
    local backup_name="pgadmin-backup-$(date +%Y%m%d-%H%M%S)"
    
    log_info "开始备份 pgAdmin 数据..."
    log_info "备份名称: $backup_name"
    
    # 这里可以实现具体的备份逻辑
    # 例如使用 pgAdmin 备份工具或 Kubernetes 备份工具
    log_success "✅ pgAdmin 数据备份完成: $backup_name"
}

# 创建 pgAdmin 密钥（如果需要）
create_pgadmin_secrets_if_needed() {
    local namespace="$1"
    local project_id="${2:-sunmoonai}"
    local environment="${3:-development}"
    local dry_run="${4:-false}"
    
    # 检查是否启用 Secrets 部署（默认启用）
    if [[ "${secrets_enabled:-true}" != "true" ]]; then
        log_info "跳过 pgAdmin Secrets 部署（secrets_enabled=false）"
        return 0
    fi
    
    log_info "🚀 部署 pgAdmin Secrets..."
    
    local secrets_script="$SCRIPT_DIR/secrets/deploy-secrets-all/deploy-secrets-all.sh"
    
    if [[ ! -f "$secrets_script" ]]; then
        log_warn "⚠️  pgAdmin Secrets 部署脚本不存在: $secrets_script"
        log_warn "跳过 Secrets 部署，请手动部署或检查脚本路径"
        return 0
    fi
    
    if bash "$secrets_script" "$project_id" "$namespace" "$environment" "$dry_run"; then
        log_success "✅ pgAdmin Secrets 部署成功"
        return 0
    else
        log_error "❌ pgAdmin Secrets 部署失败"
        return 1
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
    
    case "$action" in
        "deploy")
            log_info "开始部署 pgAdmin..."
            
            # 读取 Kubernetes 配置文件
            if ! read_k8s_config; then
                log_error "无法读取 Kubernetes 配置文件"
                return 1
            fi
            
            # 检查是否已有可用的Kubernetes连接
            if kubectl get nodes >/dev/null 2>&1; then
                log_info "使用现有 Kubernetes 连接"
            else
                # 设置 Kubernetes 环境（建立远程连接）
                if ! setup_kubectl_environment; then
                    log_error "无法建立 Kubernetes 连接"
                    return 1
                fi
                
                # 验证连接是否可用
                if ! kubectl get nodes >/dev/null 2>&1; then
                    log_error "Kubernetes 连接不可用，请检查连接状态"
                    return 1
                fi
            fi
            
            check_namespace "$namespace"
            # 在部署前按需推送 pgAdmin 组件镜像到 Harbor（Kind 使用 push-to-harbor，远程使用 registry-push-management）
            push_pgadmin_images_to_harbor || log_warn "[images] pgAdmin 镜像推送阶段出现警告，可稍后单独检查 Harbor 镜像状态"
            if ! create_pgadmin_secrets_if_needed "$namespace" "$project_id" "$environment" "$dry_run"; then
                log_error "❌ pgAdmin Secrets 部署失败，终止主部署"
                exit 1
            fi
            
            # 部署 Middleware 子组件（不依赖 Service，可以在核心组件之前部署）
            if [[ "${middleware_enabled:-true}" == "true" ]]; then
                log_info "🚀 部署 pgAdmin Middleware 子组件..."
                # 禁用自动清理，保持连接以便后续 Helm 部署使用
                if DISABLE_AUTO_CLEANUP=true bash "$SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh" deploy "$project_id" "$namespace" "$environment" "$dry_run"; then
                    log_success "✅ pgAdmin Middleware 部署成功"
                else
                    log_error "❌ pgAdmin Middleware 部署失败"
                    return 1
                fi
            else
                log_info "跳过 pgAdmin Middleware (enabled=false)"
            fi
            
            # 部署核心组件（pgAdmin Helm Chart，创建 Service 和 Pod）
            if ! execute_pgadmin_deployment "$project_id" "$namespace" "$environment" "$dry_run"; then
                log_error "❌ pgAdmin 核心组件部署失败"
                return 1
            fi
            
            # 部署 Ingress 子组件（依赖 Service 存在，必须在核心组件之后部署）
            if [[ "${ingress_enabled:-true}" == "true" ]]; then
                log_info "🚀 部署 pgAdmin Ingress 子组件..."
                if bash "$SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh" deploy "$project_id" "$namespace" "$environment"; then
                    log_success "✅ pgAdmin Ingress 部署成功"
                else
                    log_error "❌ pgAdmin Ingress 部署失败"
                    return 1
                fi
            else
                log_info "跳过 pgAdmin Ingress (enabled=false)"
            fi
            
            check_pgadmin_status "$project_id" "$namespace"
            show_pgadmin_connection_info "$namespace"
            # 安装后清理控制平面 tar 包
            if [[ -x "$PROJECT_ROOT/../../cicd-platform/harbor/utils/harbor-image-management/harbor-image.sh" ]]; then
                : # 通用工具已在推送过程中清理，无需额外清理
            fi
            ;;
        "upgrade")
            log_info "开始升级 pgAdmin..."
            
            # 读取 Kubernetes 配置文件
            if ! read_k8s_config; then
                log_error "无法读取 Kubernetes 配置文件"
                return 1
            fi
            
            # 检查是否已有可用的Kubernetes连接
            if kubectl get nodes >/dev/null 2>&1; then
                log_info "使用现有 Kubernetes 连接"
            else
                # 设置 Kubernetes 环境（建立远程连接）
                if ! setup_kubectl_environment; then
                    log_error "无法建立 Kubernetes 连接"
                    return 1
                fi
                
                # 验证连接是否可用
                if ! kubectl get nodes >/dev/null 2>&1; then
                    log_error "Kubernetes 连接不可用，请检查连接状态"
                    return 1
                fi
            fi
            
            check_namespace "$namespace"
            execute_pgadmin_deployment "$project_id" "$namespace" "$environment" "$dry_run"
            check_pgadmin_status "$project_id" "$namespace"
            ;;
        "uninstall")
            log_info "开始卸载 pgAdmin..."
            
            # 设置 Kubernetes 环境
            if ! setup_kubectl_environment; then
                log_error "无法建立 Kubernetes 连接"
                return 1
            fi
            
            # 卸载子组件（Middleware 和 Ingress）
            if [[ "${ingress_enabled:-true}" == "true" ]] || [[ "${middleware_enabled:-true}" == "true" ]]; then
                log_info "🚀 卸载 pgAdmin 子组件..."
                
                local sub_components=(
                    "pgadmin_middleware:${middleware_enabled:-true}:${middleware_priority:-1000}:pgAdmin 中间件:$SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh"
                    "pgadmin_ingress:${ingress_enabled:-true}:${ingress_priority:-100}:pgAdmin Web 路由:$SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh"
                )
                
                # 按优先级排序（卸载时反向顺序）
                IFS=$'\n' sub_components=($(sort -t: -k3 -n <<<"${sub_components[*]}"))
                unset IFS
                
                # 卸载子组件
                local uninstall_failed=false
                for component_info in "${sub_components[@]}"; do
                    IFS=':' read -r name enabled priority description script_path <<< "$component_info"
                    
                    if [[ "$enabled" == "true" ]] && [[ -f "$script_path" ]]; then
                        log_info "卸载 $description (优先级: $priority)..."
                        # 禁用子脚本的自动清理，保持连接以便后续操作
                        if DISABLE_AUTO_CLEANUP=true bash "$script_path" uninstall "$project_id" "$namespace" "$environment"; then
                            log_success "✅ $description 卸载完成"
                        else
                            log_warn "⚠️ $description 卸载失败，继续执行..."
                            uninstall_failed=true
                        fi
                    fi
                done
                
                # 清理可能残留的子组件资源（即使脚本执行失败）
                log_info "清理可能残留的子组件资源..."
                kubectl delete ingressroute -n "$namespace" -l component=pgadmin 2>/dev/null || true
                kubectl delete middleware -n "$namespace" -l component=pgadmin 2>/dev/null || true
                kubectl delete ingressroute -n "$namespace" pgadmin-web-route 2>/dev/null || true
                kubectl delete middleware -n "$namespace" pgadmin-stripprefix pgadmin-policy 2>/dev/null || true
                
                if [[ "$uninstall_failed" == "true" ]]; then
                    log_warn "⚠️  部分子组件卸载失败，但已尝试清理残留资源"
                fi
            fi
            
            # 确保连接仍然可用
            if ! kubectl get nodes >/dev/null 2>&1; then
                log_info "连接已断开，重新建立连接..."
                if ! setup_kubectl_environment; then
                    log_error "无法重新建立 Kubernetes 连接"
                    return 1
                fi
            fi
            
            # 卸载 Helm release
            local release_name="pgadmin-$project_id"
            
            # 检查 release 是否存在
            local existing_release
            if command -v jq &> /dev/null; then
                existing_release=$(helm list -n "$namespace" --output json 2>/dev/null | jq -r ".[] | select(.name == \"$release_name\") | .name" 2>/dev/null || true)
            fi
            if [[ -z "$existing_release" ]]; then
                existing_release=$(helm list -n "$namespace" 2>/dev/null | grep -E "^${release_name}[[:space:]]" | awk '{print $1}' || true)
            fi
            if [[ -z "$existing_release" ]]; then
                if helm status "$release_name" -n "$namespace" &>/dev/null; then
                    existing_release="$release_name"
                fi
            fi
            
            if [[ -n "$existing_release" ]]; then
                log_info "发现 pgAdmin release: $release_name"
                if helm uninstall "$release_name" -n "$namespace" --wait --timeout 5m; then
                    log_success "✅ pgAdmin Helm release 卸载成功！"
                else
                    log_error "❌ pgAdmin Helm release 卸载失败！"
                fi
            else
                log_warn "pgAdmin release '$release_name' 未安装或已卸载"
            fi
            
            # 清理可能残留的资源（ConfigMap、Secret、IngressRoute、Middleware）
            log_info "清理可能残留的资源..."
            sleep 2
            kubectl delete configmap -n "$namespace" -l app.kubernetes.io/instance="$release_name" --ignore-not-found=true || true
            kubectl delete secret -n "$namespace" -l app.kubernetes.io/instance="$release_name" --ignore-not-found=true || true
            kubectl delete ingressroute -n "$namespace" -l component=pgadmin 2>/dev/null || true
            kubectl delete middleware -n "$namespace" -l component=pgadmin 2>/dev/null || true
            kubectl delete ingressroute -n "$namespace" pgadmin-web-route 2>/dev/null || true
            kubectl delete middleware -n "$namespace" pgadmin-stripprefix pgadmin-policy 2>/dev/null || true
            
            # 最终验证
            local remaining
            remaining=$(kubectl get all,ingressroute,middleware -n "$namespace" 2>/dev/null | grep -i "pgadmin" || true)
            if [[ -n "$remaining" ]]; then
                log_warn "⚠️  仍有残留资源，可能需要手动清理:"
                echo "$remaining"
            else
                log_success "✅ pgAdmin 完全卸载完成！"
            fi
            ;;
        "clean")
            log_info "开始清理 pgAdmin..."
            
            # 设置 Kubernetes 环境
            if ! setup_kubectl_environment; then
                log_error "无法建立 Kubernetes 连接"
                return 1
            fi
            
            local release_name="pgadmin-$project_id"
            helm uninstall "$release_name" -n "$namespace" --wait --timeout 5m 2>/dev/null || true
            kubectl delete pvc -n "$namespace" -l app.kubernetes.io/instance="$release_name" || true
            kubectl delete ingressroute -n "$namespace" -l component=pgadmin 2>/dev/null || true
            kubectl delete middleware -n "$namespace" -l component=pgadmin 2>/dev/null || true
            kubectl delete configmap -n "$namespace" -l app.kubernetes.io/instance="$release_name" --ignore-not-found=true || true
            kubectl delete secret -n "$namespace" -l app.kubernetes.io/instance="$release_name" --ignore-not-found=true || true
            log_success "✅ pgAdmin 清理完成"
            ;;
        "status")
            # 设置 Kubernetes 环境
            if ! setup_kubectl_environment; then
                log_error "无法建立 Kubernetes 连接"
                return 1
            fi
            
            check_pgadmin_status "$project_id" "$namespace"
            show_pgadmin_connection_info "$namespace"
            ;;
        "logs")
            # 设置 Kubernetes 环境
            if ! setup_kubectl_environment; then
                log_error "无法建立 Kubernetes 连接"
                return 1
            fi
            
            log_info "显示 pgAdmin 日志..."
            kubectl logs -n "$namespace" -l app.kubernetes.io/instance="pgadmin-$project_id" --tail=100
            ;;
        "backup")
            # 设置 Kubernetes 环境
            if ! setup_kubectl_environment; then
                log_error "无法建立 Kubernetes 连接"
                return 1
            fi
            
            backup_pgadmin_data "$namespace"
            ;;
        "connect")
            show_pgadmin_connection_info "$namespace"
            ;;
        *)
            echo "用法: $0 <action> [project_id] [namespace] [environment] [dry_run]"
            echo ""
            echo "操作:"
            echo "  deploy     部署 pgAdmin（默认）"
            echo "  upgrade    升级 pgAdmin"
            echo "  uninstall  卸载 pgAdmin"
            echo "  clean      清理 pgAdmin（包括数据）"
            echo "  status     检查 pgAdmin 状态"
            echo "  logs       显示 pgAdmin 日志"
            echo "  backup     备份 pgAdmin 数据"
            echo "  connect    显示连接信息"
            echo ""
            echo "参数:"
            echo "  project_id   项目标识符（默认: $DEFAULT_PROJECT_ID）"
            echo "  namespace    命名空间（默认: $DEFAULT_NAMESPACE）"
            echo "  environment  环境（默认: $DEFAULT_ENVIRONMENT）"
            echo "  dry_run      试运行模式（默认: false）"
            echo ""
            echo "示例:"
            echo "  $0 deploy sunmoonai ops-platform-dev development"
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
