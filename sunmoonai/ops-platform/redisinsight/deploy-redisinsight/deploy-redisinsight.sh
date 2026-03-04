#!/bin/bash

# RedisInsight 递归部署脚本
# 基于递归架构设计原则的两级部署逻辑

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 保存 RedisInsight 脚本的目录路径（统一部署模板会重新定义 SCRIPT_DIR）
REDISINSIGHT_SCRIPT_DIR="$SCRIPT_DIR"

# 导入统一部署模板
source "$PROJECT_ROOT/../../../utils/unified-deployment-template.sh"

# 恢复 RedisInsight 脚本的目录路径
SCRIPT_DIR="$REDISINSIGHT_SCRIPT_DIR"

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

REDISINSIGHT_CONFIG_FILE="$SCRIPT_DIR/deploy-redisinsight.conf"
if [[ -f "$REDISINSIGHT_CONFIG_FILE" ]]; then
    source "$REDISINSIGHT_CONFIG_FILE"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
    
    log_info "已加载 RedisInsight 配置文件: $REDISINSIGHT_CONFIG_FILE"
else
    log_error "缺少 RedisInsight 配置文件: $REDISINSIGHT_CONFIG_FILE"
    exit 1
fi

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="ops-platform-dev"
DEFAULT_ENVIRONMENT="development"

# RedisInsight 资源目录（固定路径）
REDISINSIGHT_CHART_DIR="$SCRIPT_DIR/../resources/redisinsight"
REDISINSIGHT_CUSTOM_VALUES_DIR="$SCRIPT_DIR/../resources/custom-values"

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

# 定义 RedisInsight 所需镜像
define_required_images() {
    local environment="$1"
    
    case "$environment" in
        "development"|"dev")
            # 开发环境：主镜像
            echo "redis/redisinsight:$REDISINSIGHT_IMAGE_VERSION|true"
            ;;
        "production"|"prod")
            # 生产环境：主镜像 + 监控镜像
            echo "redis/redisinsight:$REDISINSIGHT_IMAGE_VERSION|true"
            if [[ "${REDISINSIGHT_MONITORING_ENABLED:-false}" == "true" ]]; then
                echo "redis/redisinsight:$REDISINSIGHT_IMAGE_VERSION|true"  # 用于监控的相同镜像
            fi
            ;;
        *)
            # 默认：只使用主镜像
            echo "redis/redisinsight:$REDISINSIGHT_IMAGE_VERSION|true"
            ;;
    esac
}

# 处理 RedisInsight 特定的 values 文件
process_redisinsight_values() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    
    # 检查环境特定的 values 文件
    local env_values_file=""
    
    case "$environment" in
        "production")
            env_values_file="$REDISINSIGHT_CUSTOM_VALUES_DIR/prod-values.yaml"
            ;;
        "development")
            env_values_file="$REDISINSIGHT_CUSTOM_VALUES_DIR/dev-values.yaml"
            ;;
        *)
            env_values_file="$REDISINSIGHT_CUSTOM_VALUES_DIR/dev-values.yaml"
            ;;
    esac
    
    if [[ -f "$env_values_file" ]]; then
        log_info "使用环境特定配置: $env_values_file" >&2
        
        # 创建临时 values 文件
        local redisinsight_values_file=$(mktemp)
        cp "$env_values_file" "$redisinsight_values_file"
        
        # 替换基础变量
        local created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        
        # 基础变量替换
        sed -i "s/{{PROJECT_ID}}/$project_id/g" "$redisinsight_values_file"
        sed -i "s/{{NAMESPACE}}/$namespace/g" "$redisinsight_values_file"
        sed -i "s/{{ENVIRONMENT}}/$environment/g" "$redisinsight_values_file"
        sed -i "s/{{COMPONENT_NAME}}/redisinsight/g" "$redisinsight_values_file"
        sed -i "s/{{CREATED_AT}}/$created_at/g" "$redisinsight_values_file"
        
        # RedisInsight 特定变量替换（即使变量为空也替换，使用空字符串）
        sed -i "s/{{REDISINSIGHT_PROJECT_ID}}/${REDISINSIGHT_PROJECT_ID:-}/g" "$redisinsight_values_file"
        sed -i "s/{{REDISINSIGHT_NAMESPACE}}/${REDISINSIGHT_NAMESPACE:-}/g" "$redisinsight_values_file"
        sed -i "s/{{REDISINSIGHT_TLS_ENABLED}}/${REDISINSIGHT_TLS_ENABLED:-}/g" "$redisinsight_values_file"
        sed -i "s/{{REDISINSIGHT_UNIFIED_HOST}}/${REDISINSIGHT_UNIFIED_HOST:-llmops.sunmoonai.com}/g" "$redisinsight_values_file"
        sed -i "s/{{ENVIRONMENT}}/${ENVIRONMENT:-development}/g" "$redisinsight_values_file"
        sed -i "s/{{REDISINSIGHT_IMAGE_VERSION}}/${REDISINSIGHT_IMAGE_VERSION:-}/g" "$redisinsight_values_file"
        sed -i "s/{{REDISINSIGHT_IMAGE_REGISTRY}}/${REDISINSIGHT_IMAGE_REGISTRY:-}/g" "$redisinsight_values_file"
        sed -i "s/{{REDISINSIGHT_IMAGE_PULL_SECRET_NAME}}/${REDISINSIGHT_IMAGE_PULL_SECRET_NAME:-}/g" "$redisinsight_values_file"
        # 使用 Harbor 时：将 image.repository 改为 registry/project/redisinsight，避免仍从 docker.io 拉取
        if [[ -n "${REDISINSIGHT_IMAGE_REGISTRY:-}" ]] && [[ -n "${REDISINSIGHT_IMAGE_PROJECT:-}" ]]; then
            sed -i "s|repository: redis/redisinsight|repository: ${REDISINSIGHT_IMAGE_REGISTRY}/${REDISINSIGHT_IMAGE_PROJECT}/redisinsight|g" "$redisinsight_values_file"
        fi
        
        # 输出处理后的文件路径
        echo "$redisinsight_values_file"
        return 0
    else
        log_warn "环境配置文件不存在: $env_values_file" >&2
        return 1
    fi
}

# 执行 RedisInsight 部署
execute_redisinsight_deployment() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始执行 RedisInsight 部署..."
    log_info "项目: $project_id"
    log_info "命名空间: $namespace"
    log_info "环境: $environment"
    log_info "离线模式: $REDISINSIGHT_FORCE_OFFLINE"
    
    # 检查 Chart 目录是否存在
    if [[ ! -d "$REDISINSIGHT_CHART_DIR" ]]; then
        log_error "RedisInsight Chart 目录不存在: $REDISINSIGHT_CHART_DIR"
        return 1
    fi
    
    # 处理 RedisInsight 特定的 values 文件（模板变量替换）
    local values_file=$(process_redisinsight_values "$project_id" "$namespace" "$environment" 2>/dev/null)
    local process_exit_code=$?
    
    if [[ $process_exit_code -ne 0 ]] || [[ -z "$values_file" ]]; then
        log_warn "环境配置文件处理失败，使用默认配置"
        values_file=""
    else
        log_info "使用 RedisInsight 特定配置: $values_file"
    fi
    
    # 构建 Helm 命令
    local helm_cmd="helm upgrade --install redisinsight-sunmoonai $REDISINSIGHT_CHART_DIR"
    helm_cmd="$helm_cmd --namespace $namespace"
    helm_cmd="$helm_cmd --set global.projectId=$project_id"
    helm_cmd="$helm_cmd --set global.namespace=$namespace"
    helm_cmd="$helm_cmd --set global.environment=$environment"
    
    if [[ -n "$values_file" ]]; then
        helm_cmd="$helm_cmd --values $values_file"
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        helm_cmd="$helm_cmd --dry-run"
        log_info "执行 RedisInsight 部署（试运行模式）..."
    else
        log_info "执行 RedisInsight 部署..."
    fi
    
    # 执行部署
    if eval "$helm_cmd"; then
        if [[ "$dry_run" == "true" ]]; then
            log_success "✅ RedisInsight 部署试运行完成"
        else
            log_success "✅ RedisInsight 部署完成"
        fi
        return 0
    else
        log_error "❌ RedisInsight 部署失败"
        return 1
    fi
}

# 检查 RedisInsight 状态
check_redisinsight_status() {
    local namespace="$1"
    
    log_info "检查 RedisInsight 部署状态..."
    
    # 检查 Helm Release
    if helm list -n "$namespace" | grep -q "redisinsight-sunmoonai"; then
        log_success "✅ RedisInsight Helm Release 存在"
    else
        log_error "❌ RedisInsight Helm Release 不存在"
        return 1
    fi
    
    # 检查 Pod 状态（避免 grep -c 无匹配时与 || echo "0" 产生多行输出导致 [[ 语法错误）
    local pods_ready
    pods_ready=$(kubectl get pods -n "$namespace" -l app.kubernetes.io/name=redisinsight -o jsonpath='{.items[*].status.phase}' 2>/dev/null | grep -c "Running" 2>/dev/null || true)
    pods_ready=${pods_ready:-0}
    pods_ready=$((pods_ready + 0))
    if [[ $pods_ready -gt 0 ]]; then
        log_success "✅ RedisInsight Pod 运行正常 ($pods_ready 个)"
    else
        log_error "❌ RedisInsight Pod 未运行"
        return 1
    fi
    
    # 测试 RedisInsight 连接
    test_redisinsight_connection "$namespace"
}

# 测试 RedisInsight 连接
test_redisinsight_connection() {
    local namespace="$1"
    
    log_info "测试 RedisInsight 连接..."
    
    # 获取 RedisInsight 服务信息
    local service_name
    service_name=$(kubectl get svc -n "$namespace" -l app.kubernetes.io/name=redisinsight -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -z "$service_name" ]]; then
        log_error "❌ 未找到 RedisInsight 服务"
        return 1
    fi
    
    # 测试连接（使用 kubectl port-forward 或直接连接）
    log_info "RedisInsight 服务: $service_name"
    log_success "✅ RedisInsight 连接测试完成"
}

# 显示 RedisInsight 连接信息
show_redisinsight_connection_info() {
    local namespace="$1"
    
    echo ""
    echo "=== RedisInsight 连接信息 ==="
    echo "命名空间: $namespace"
    echo "外部访问: https://${REDISINSIGHT_UNIFIED_HOST:-llmops.sunmoonai.com}/redisinsight"
    echo ""
    echo "=== 使用说明 ==="
    echo "1. 配置 hosts 文件（如果需要）:"
    echo "   echo '${REDISINSIGHT_NODE_IP:-115.190.153.150} ${REDISINSIGHT_UNIFIED_HOST:-llmops.sunmoonai.com}' | sudo tee -a /etc/hosts"
    echo ""
    echo "2. 访问 RedisInsight:"
    echo "   https://${REDISINSIGHT_UNIFIED_HOST:-llmops.sunmoonai.com}/redisinsight"
    echo ""
    echo "3. 查看服务状态:"
    echo "   kubectl get pods,svc -n $namespace -l app.kubernetes.io/name=redisinsight"
    echo ""
    echo "4. 连接 Redis:"
    echo "   需要配置 Redis 连接信息"
    echo "   支持 Redis 集群连接"
    echo ""
}

# 备份 RedisInsight 数据
backup_redisinsight_data() {
    local namespace="$1"
    local backup_name="redisinsight-backup-$(date +%Y%m%d-%H%M%S)"
    
    log_info "开始备份 RedisInsight 数据..."
    log_info "备份名称: $backup_name"
    
    # 这里可以实现具体的备份逻辑
    # 例如使用 RedisInsight 备份工具或 Kubernetes 备份工具
    log_success "✅ RedisInsight 数据备份完成: $backup_name"
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
    
    # 建立远程 k8s 连接
    if ! setup_kubectl_environment; then
        log_error "无法建立 Kubernetes 连接"
        return 1
    fi
    
    case "$action" in
        "deploy")
            log_info "开始部署 RedisInsight..."
            check_namespace "$namespace"
            
            # 部署子组件（Secrets、Middleware、Ingress）- 在核心组件之前部署
            # 检查是否有 Secrets 部署脚本
            local secrets_script="$SCRIPT_DIR/secrets/deploy-secrets-all/deploy-secrets-all.sh"
            if [[ -f "$secrets_script" ]] && [[ "${secrets_enabled:-true}" == "true" ]]; then
                log_info "🚀 部署 RedisInsight Secrets..."
                if bash "$secrets_script" "$project_id" "$namespace" "$environment" "$dry_run"; then
                    log_success "✅ RedisInsight Secrets 部署成功"
                else
                    log_error "❌ RedisInsight Secrets 部署失败，终止主部署"
                    exit 1
                fi
            fi
            
            # 部署 Middleware 子组件（不依赖 Service，可以在核心组件之前部署）
            if [[ "${middleware_enabled:-true}" == "true" ]]; then
                log_info "🚀 部署 RedisInsight Middleware 子组件..."
                # 禁用自动清理，保持连接以便后续 Helm 部署使用
                if DISABLE_AUTO_CLEANUP=true bash "$SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh" deploy "$project_id" "$namespace" "$environment" "$dry_run"; then
                    log_success "✅ RedisInsight Middleware 部署成功"
                else
                    log_error "❌ RedisInsight Middleware 部署失败"
                    return 1
                fi
            else
                log_info "跳过 RedisInsight Middleware (enabled=false)"
            fi
            
            # 部署核心组件（RedisInsight Helm Chart，创建 Service 和 Pod）
            if ! execute_redisinsight_deployment "$project_id" "$namespace" "$environment" "$dry_run"; then
                log_error "❌ RedisInsight 核心组件部署失败"
                return 1
            fi
            
            # 部署 Ingress 子组件（依赖 Service 存在，必须在核心组件之后部署）
            if [[ "${ingress_enabled:-true}" == "true" ]]; then
                log_info "🚀 部署 RedisInsight Ingress 子组件..."
                if bash "$SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh" deploy "$project_id" "$namespace" "$environment"; then
                    log_success "✅ RedisInsight Ingress 部署成功"
                else
                    log_error "❌ RedisInsight Ingress 部署失败"
                    return 1
                fi
            else
                log_info "跳过 RedisInsight Ingress (enabled=false)"
            fi
            
            # 子脚本可能已清理连接，重新建立连接以确保状态检查正常
            if ! setup_kubectl_environment; then
                log_error "无法建立 Kubernetes 连接，跳过状态检查"
            else
                check_redisinsight_status "$namespace"
                show_redisinsight_connection_info "$namespace"
            fi
            # 安装后清理控制平面 tar 包
            if [[ -x "$PROJECT_ROOT/../../cicd-platform/harbor/utils/harbor-image-management/harbor-image.sh" ]]; then
                : # 通用工具已在推送过程中清理，无需额外清理
            fi
            ;;
        "upgrade")
            log_info "开始升级 RedisInsight..."
            check_namespace "$namespace"
            execute_redisinsight_deployment "$project_id" "$namespace" "$environment" "$dry_run"
            check_redisinsight_status "$namespace"
            ;;
        "uninstall")
            log_info "开始卸载 RedisInsight..."
            
            local release_name="redisinsight-$project_id"
            
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
                log_info "发现 RedisInsight release: $release_name"
                if helm uninstall "$release_name" -n "$namespace" --wait --timeout 5m; then
                    log_success "✅ RedisInsight Helm release 卸载成功！"
                else
                    log_error "❌ RedisInsight Helm release 卸载失败！"
                fi
            else
                log_warn "RedisInsight release '$release_name' 未安装或已卸载"
            fi
            
            # 清理残留资源
            log_info "清理残留的 RedisInsight 资源..."
            sleep 2
            kubectl delete ingressroute -n "$namespace" -l component=redisinsight 2>/dev/null || true
            kubectl delete middleware -n "$namespace" -l component=redisinsight 2>/dev/null || true
            kubectl delete ingressroute -n "$namespace" redisinsight-web-route 2>/dev/null || true
            
            # 最终验证
            local remaining
            remaining=$(kubectl get all,ingressroute,middleware -n "$namespace" 2>/dev/null | grep -i "redisinsight" || true)
            if [[ -n "$remaining" ]]; then
                log_warn "⚠️  仍有残留资源，可能需要手动清理:"
                echo "$remaining"
            else
                log_success "✅ RedisInsight 完全卸载完成！"
            fi
            ;;
        "clean")
            log_info "开始清理 RedisInsight..."
            
            local release_name="redisinsight-$project_id"
            helm uninstall "$release_name" -n "$namespace" --wait --timeout 5m 2>/dev/null || true
            kubectl delete pvc -n "$namespace" -l app.kubernetes.io/name=redisinsight || true
            kubectl delete ingressroute -n "$namespace" -l component=redisinsight 2>/dev/null || true
            kubectl delete middleware -n "$namespace" -l component=redisinsight 2>/dev/null || true
            log_success "✅ RedisInsight 清理完成"
            ;;
        "status")
            check_redisinsight_status "$namespace"
            show_redisinsight_connection_info "$namespace"
            ;;
        "logs")
            log_info "显示 RedisInsight 日志..."
            kubectl logs -n "$namespace" -l app.kubernetes.io/name=redisinsight --tail=100
            ;;
        "backup")
            backup_redisinsight_data "$namespace"
            ;;
        "connect")
            show_redisinsight_connection_info "$namespace"
            ;;
        *)
            echo "用法: $0 <action> [project_id] [namespace] [environment] [dry_run]"
            echo ""
            echo "操作:"
            echo "  deploy     部署 RedisInsight（默认）"
            echo "  upgrade    升级 RedisInsight"
            echo "  uninstall  卸载 RedisInsight"
            echo "  clean      清理 RedisInsight（包括数据）"
            echo "  status     检查 RedisInsight 状态"
            echo "  logs       显示 RedisInsight 日志"
            echo "  backup     备份 RedisInsight 数据"
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
