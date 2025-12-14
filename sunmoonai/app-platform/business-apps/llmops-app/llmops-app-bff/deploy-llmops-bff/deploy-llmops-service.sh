#!/bin/bash

# LLMOps Service 部署脚本
# 用法: ./deploy-llmops-service.sh <action> [project_id] [namespace] [environment] [-c|--cluster CLUSTER]
# 注意: 镜像构建请使用 build/build-image.sh 脚本

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 保存 LLMOps Service 脚本的目录路径（统一部署模板会重新定义 SCRIPT_DIR）
LLMOPS_SERVICE_SCRIPT_DIR="$SCRIPT_DIR"

# 导入统一部署模板
# 注意：从 llmops-app-bff 到 k8s 需要 5 级（llmops-app-bff -> llmops-app -> business-apps -> app-platform -> sunmoonai -> k8s）
source "$PROJECT_ROOT/../../../../../utils/unified-deployment-template.sh"

# 恢复 LLMOps Service 脚本的目录路径
SCRIPT_DIR="$LLMOPS_SERVICE_SCRIPT_DIR"

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
        if [[ -f "$PROJECT_ROOT/../../../../../utils/cluster-config-mapping.sh" ]]; then
            source "$PROJECT_ROOT/../../../../../utils/cluster-config-mapping.sh"
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

# 加载部署配置文件
LLMOPS_SERVICE_CONFIG_FILE="$SCRIPT_DIR/deploy-llmops-service.conf"
if [[ -f "$LLMOPS_SERVICE_CONFIG_FILE" ]]; then
    source "$LLMOPS_SERVICE_CONFIG_FILE"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$PROJECT_ROOT/../../../../../utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/../../../../../utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
    
    log_info "已加载 LLMOps Service 配置文件: $LLMOPS_SERVICE_CONFIG_FILE"
else
    log_warn "未找到 LLMOps Service 配置文件: $LLMOPS_SERVICE_CONFIG_FILE，使用默认配置"
fi

# 默认配置（对齐 PostgreSQL 部署脚本，使用硬编码默认值）
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="app-platform-dev"
DEFAULT_ENVIRONMENT="development"

# 镜像配置（从部署配置文件读取，用于部署时指定镜像）
# 镜像名称和标签应该与 build/build.conf 中的配置保持一致
LLMOPS_SERVICE_IMAGE="${LLMOPS_SERVICE_IMAGE:-llmops-service}"
LLMOPS_SERVICE_TAG="${LLMOPS_SERVICE_TAG:-1.0.0}"

# 项目ID（从配置文件读取，如果未设置则使用默认值）
PROJECT_ID="${LLMOPS_SERVICE_PROJECT_ID:-${PROJECT_ID:-sunmoonai}}"

# 资源文件路径（对齐 PostgreSQL 结构，统一使用 llmops-service.yaml）
RESOURCES_DIR="../resources"
LLMOPS_SERVICE_YAML="${RESOURCES_DIR}/llmops-service.yaml"

# Secrets 和 ConfigMaps 路径（对齐项目架构，放在 deploy-llmops-bff/secrets/ 下）
SECRETS_DIR="./secrets"
LLMOPS_SERVICE_CONFIGMAP="${SECRETS_DIR}/llmops-service-config/llmops-service-config.yaml"
LLMOPS_SERVICE_SECRET="${SECRETS_DIR}/llmops-service-secret/llmops-service-secret.yaml"
DEPLOY_SECRETS_ALL="${SECRETS_DIR}/deploy-secrets-all/deploy-secrets-all.sh"

# 检查 kubectl 是否可用
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl 未安装或不在 PATH 中"
        exit 1
    fi
}

# 检查命名空间是否存在
check_namespace() {
    local namespace="$1"
    
    # 检查是否已有可用的Kubernetes连接
    if ! kubectl get nodes >/dev/null 2>&1; then
        # 确保 Kubernetes 连接已建立
        if ! setup_kubectl_environment; then
            log_error "❌ 无法建立 Kubernetes 连接"
            echo ""
            log_info "如果已手动设置 KUBECONFIG，请检查："
            echo "  export KUBECONFIG=/path/to/your/kubeconfig"
            echo "  kubectl get nodes"
            echo ""
            log_info "如果需要自动连接，请检查："
            echo "  1. SSH 连接配置是否正确"
            echo "  2. 端口是否被占用（当前错误显示端口可能已被占用）"
            echo "  3. 远程服务器上的 kubeconfig 文件权限"
            echo ""
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
        echo "  cd ../../namespace-platform"
        echo "  ./scripts/deploy.sh --env dev"
        echo ""
        log_info "或者手动创建命名空间："
        echo "  kubectl create namespace $namespace"
        echo ""
        return 1
    fi
}

# 检查环境配置
check_env_config() {
    if [ ! -f "$LLMOPS_SERVICE_YAML" ]; then
        log_error "配置文件不存在: $LLMOPS_SERVICE_YAML"
        log_info "请确保资源文件存在: $RESOURCES_DIR/llmops-service.yaml"
        exit 1
    fi
    if [ ! -f "$LLMOPS_SERVICE_CONFIGMAP" ]; then
        log_error "ConfigMap 文件不存在: $LLMOPS_SERVICE_CONFIGMAP"
        log_info "请确保 secrets 目录存在: $SECRETS_DIR"
        exit 1
    fi
    if [ ! -f "$LLMOPS_SERVICE_SECRET" ]; then
        log_error "Secret 文件不存在: $LLMOPS_SERVICE_SECRET"
        log_info "请确保 secrets 目录存在: $SECRETS_DIR"
        exit 1
    fi
    
    # 检查 envsubst 是否可用
    if ! command -v envsubst &> /dev/null; then
        log_error "envsubst 命令未找到，请安装 gettext 包"
        log_info "Ubuntu/Debian: sudo apt-get install gettext-base"
        log_info "CentOS/RHEL: sudo yum install gettext"
        exit 1
    fi
}

# 部署 Web API
deploy_web_api() {
    log_info "开始部署 LLMOps Service..."
    log_info "环境: $ENV, 命名空间: $NAMESPACE"
    
    # 检查环境配置
    check_env_config
    
    # deploy 命令：使用 Harbor 镜像部署
    # 注意：部署前请确保镜像已构建并推送到 Harbor
    # 构建镜像请使用: cd ../../../../../sunmoonai-llmops-service/build && ./build-image.sh build-push
    LLMOPS_SERVICE_FULL_IMAGE_NAME="${LLMOPS_SERVICE_IMAGE_REGISTRY}/${LLMOPS_SERVICE_IMAGE_PROJECT}/${LLMOPS_SERVICE_IMAGE}:${LLMOPS_SERVICE_TAG}"
    IMAGE_PULL_POLICY="IfNotPresent"  # 如果本地有则使用，否则从仓库拉取
    log_info "使用 Harbor 镜像部署: $LLMOPS_SERVICE_FULL_IMAGE_NAME"
    log_info "Kubernetes 将从镜像仓库拉取镜像"
    log_warn "⚠️  请确保该镜像已存在于 Harbor 仓库中"
    
    # 部署 Secrets 和 ConfigMaps（使用统一部署脚本）
    if [[ -f "$DEPLOY_SECRETS_ALL" ]]; then
        log_info "使用统一部署脚本部署 Secrets 和 ConfigMaps..."
        bash "$DEPLOY_SECRETS_ALL" deploy "$PROJECT_ID" "$NAMESPACE" "$ENV" || {
            log_error "Secrets 和 ConfigMaps 部署失败"
            exit 1
        }
    else
        log_warn "统一部署脚本不存在，使用直接部署方式..."
        # 部署 ConfigMap（使用 envsubst 替换环境变量）
        log_info "部署 ConfigMap (环境: $ENV, 命名空间: $NAMESPACE)..."
        TEMP_CONFIGMAP=$(mktemp)
        export NAMESPACE ENV
        envsubst < "$LLMOPS_SERVICE_CONFIGMAP" > "$TEMP_CONFIGMAP"
        kubectl apply -f "$TEMP_CONFIGMAP" -n "$NAMESPACE"
        rm -f "$TEMP_CONFIGMAP"
        
        # 部署 Secret（使用 envsubst 替换环境变量）
        log_info "部署 Secret (环境: $ENV, 命名空间: $NAMESPACE)..."
        TEMP_SECRET=$(mktemp)
        export NAMESPACE ENV
        envsubst < "$LLMOPS_SERVICE_SECRET" > "$TEMP_SECRET"
        kubectl apply -f "$TEMP_SECRET" -n "$NAMESPACE"
        rm -f "$TEMP_SECRET"
    fi
    
    # 部署 LLMOps Service（动态替换镜像名称和命名空间）
    log_info "部署 LLMOps Service (环境: $ENV, 镜像: $LLMOPS_SERVICE_FULL_IMAGE_NAME, 拉取策略: ${IMAGE_PULL_POLICY:-IfNotPresent}, 命名空间: $NAMESPACE)..."
    # 创建临时文件并替换环境变量（包括镜像名称、拉取策略和命名空间）
    TEMP_YAML=$(mktemp)
    export NAMESPACE ENV LLMOPS_SERVICE_IMAGE LLMOPS_SERVICE_TAG LLMOPS_SERVICE_IMAGE_REGISTRY LLMOPS_SERVICE_IMAGE_PROJECT LLMOPS_SERVICE_FULL_IMAGE_NAME IMAGE_PULL_POLICY
    envsubst < "$LLMOPS_SERVICE_YAML" > "$TEMP_YAML"
    kubectl apply -f "$TEMP_YAML" -n "$NAMESPACE"
    rm -f "$TEMP_YAML"
    
    log_success "LLMOps Service 部署完成！"
    
    # 部署 Ingress（如果启用）
    if [[ "${ingress_enabled:-true}" == "true" ]]; then
        log_info "部署 LLMOps Service Ingress..."
        local ingress_script="$SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh"
        if [[ -f "$ingress_script" ]]; then
            if bash "$ingress_script" deploy "$PROJECT_ID" "$NAMESPACE" "$ENV"; then
                log_success "✅ LLMOps Service Ingress 部署成功"
            else
                log_warn "⚠️ LLMOps Service Ingress 部署失败（可能已存在）"
            fi
        else
            log_warn "⚠️ Ingress 部署脚本不存在: $ingress_script"
        fi
    else
        log_info "Ingress 部署已禁用，跳过"
    fi
    
    # 显示访问信息
    echo ""
    log_info "访问信息:"
    echo "  🌐 域名: ${LLMOPS_SERVICE_UNIFIED_HOST:-llmops.sunmoonai.com}"
    echo "  🔗 端口: ${LLMOPS_SERVICE_EXTERNAL_PORT:-30443} (HTTPS)"
    echo "  📍 完整URL: https://${LLMOPS_SERVICE_UNIFIED_HOST:-llmops.sunmoonai.com}:${LLMOPS_SERVICE_EXTERNAL_PORT:-30443}/api/v1"
    echo ""
    log_info "检查部署状态:"
    echo "  kubectl get pods -n $NAMESPACE -l app=llmops-service"
    echo "  kubectl get svc -n $NAMESPACE -l app=llmops-service"
    echo "  kubectl get ingressroute -n $NAMESPACE"
    echo ""
    log_info "查看 Pod 日志:"
    echo "  kubectl logs -n $NAMESPACE -l app=llmops-service -f"
}

# 卸载 Web API
undeploy_web_api() {
    log_info "开始卸载 LLMOps Service..."
    log_info "环境: $ENV, 命名空间: $NAMESPACE"
    
    # 检查环境配置
    check_env_config
    
    # 卸载时使用原始 YAML（删除时不需要替换镜像，但需要替换命名空间）
    TEMP_YAML=$(mktemp)
    export NAMESPACE ENV
    envsubst < "$LLMOPS_SERVICE_YAML" > "$TEMP_YAML"
    kubectl delete -f "$TEMP_YAML" -n "$NAMESPACE" --ignore-not-found=true
    rm -f "$TEMP_YAML"
    
    # 卸载 Ingress（如果启用）
    if [[ "${ingress_enabled:-true}" == "true" ]]; then
        log_info "卸载 LLMOps Service Ingress..."
        local ingress_script="$SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh"
        if [[ -f "$ingress_script" ]]; then
            if bash "$ingress_script" uninstall "$PROJECT_ID" "$NAMESPACE" "$ENV"; then
                log_success "✅ LLMOps Service Ingress 卸载成功"
            else
                log_warn "⚠️ LLMOps Service Ingress 卸载失败（可能不存在）"
            fi
        else
            log_warn "⚠️ Ingress 部署脚本不存在: $ingress_script"
        fi
    fi
    
    # 卸载 Secrets 和 ConfigMaps（使用统一部署脚本）
    if [[ -f "$DEPLOY_SECRETS_ALL" ]]; then
        log_info "使用统一部署脚本卸载 Secrets 和 ConfigMaps..."
        bash "$DEPLOY_SECRETS_ALL" uninstall "$PROJECT_ID" "$NAMESPACE" "$ENV" || {
            log_warn "Secrets 和 ConfigMaps 卸载失败（可能不存在）"
        }
    else
        log_warn "统一部署脚本不存在，使用直接卸载方式..."
        # 卸载 Secret 和 ConfigMap（使用 envsubst 替换环境变量）
        TEMP_SECRET=$(mktemp)
        TEMP_CONFIGMAP=$(mktemp)
        export NAMESPACE ENV
        envsubst < "$LLMOPS_SERVICE_SECRET" > "$TEMP_SECRET"
        envsubst < "$LLMOPS_SERVICE_CONFIGMAP" > "$TEMP_CONFIGMAP"
        kubectl delete -f "$TEMP_SECRET" -n "$NAMESPACE" --ignore-not-found=true
        kubectl delete -f "$TEMP_CONFIGMAP" -n "$NAMESPACE" --ignore-not-found=true
        rm -f "$TEMP_SECRET" "$TEMP_CONFIGMAP"
    fi
    
    log_success "LLMOps Service 卸载完成！"
}

# 显示状态
show_status() {
    log_info "LLMOps Service 状态:"
    echo ""
    echo "📦 Pods:"
    kubectl get pods -n "$NAMESPACE" -l app=llmops-service 2>/dev/null || echo "  无 Pod 运行"
    echo ""
    echo "🌐 Services:"
    kubectl get svc -n "$NAMESPACE" -l app=llmops-service 2>/dev/null || echo "  无 Service"
    echo ""
    echo "📋 ConfigMaps:"
    kubectl get configmap -n "$NAMESPACE" -l app=llmops-service 2>/dev/null || echo "  无 ConfigMap"
    echo ""
    echo "🔐 Secrets:"
    kubectl get secret -n "$NAMESPACE" -l app=llmops-service 2>/dev/null || echo "  无 Secret"
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
    
    # 将 environment 转换为 ENV（用于兼容性）
    case "$environment" in
        "development"|"dev")
            ENV="dev"
            ;;
        "production"|"prod")
            ENV="prod"
            ;;
        *)
            ENV="dev"  # 默认值
            ;;
    esac
    
    # 更新全局变量
    ACTION="$action"
    PROJECT_ID="$project_id"
    NAMESPACE="$namespace"
    ENVIRONMENT="$environment"
    
    log_info "LLMOps Service 部署脚本启动"
    log_info "操作: $ACTION, 项目: $PROJECT_ID, 命名空间: $NAMESPACE, 环境: $ENVIRONMENT"
    
    check_kubectl
    
    case "$ACTION" in
        "deploy")
            log_info "开始部署 LLMOps Service..."
            
            # 读取 Kubernetes 配置文件
            if ! read_k8s_config; then
                log_error "无法读取 Kubernetes 配置文件"
                exit 1
            fi
            
            # 检查是否已有可用的Kubernetes连接
            if kubectl get nodes >/dev/null 2>&1; then
                log_info "使用现有 Kubernetes 连接"
            else
                # 设置 Kubernetes 环境（建立远程连接）
                if ! setup_kubectl_environment; then
                    log_error "无法建立 Kubernetes 连接"
                    exit 1
                fi
                
                # 验证连接是否可用
                if ! kubectl get nodes >/dev/null 2>&1; then
                    log_error "Kubernetes 连接不可用，请检查连接状态"
                    exit 1
                fi
            fi
            
            if ! check_namespace "$namespace"; then
                log_error "❌ 命名空间检查失败"
                exit 1
            fi
            deploy_web_api
            show_status
            ;;
        "undeploy")
            if ! check_namespace "$namespace"; then
                log_error "❌ 命名空间检查失败"
                exit 1
            fi
            undeploy_web_api
            ;;
        "status")
            show_status
            ;;
        *)
            log_error "无效的操作: $ACTION"
            echo "用法: $0 <action> [project_id] [namespace] [environment] [-c|--cluster CLUSTER]"
            echo ""
            echo "操作:"
            echo "  deploy     部署 LLMOps Service"
            echo "  undeploy   卸载 LLMOps Service"
            echo "  status     查看 LLMOps Service 状态"
            echo ""
            echo "参数说明:"
            echo "  project_id   项目标识符（默认: $DEFAULT_PROJECT_ID）"
            echo "  namespace    命名空间（默认: $DEFAULT_NAMESPACE）"
            echo "  environment  环境（默认: $DEFAULT_ENVIRONMENT）"
            echo "  -c, --cluster 集群配置（如 C1, C2）"
            echo ""
            echo "操作说明:"
            echo "  deploy       - 部署到 Kubernetes（从 Harbor 拉取镜像）"
            echo "                注意: 部署前请确保镜像已构建并推送到 Harbor"
            echo "                构建镜像: cd ../../../../../sunmoonai-llmops-service/build && ./build-image.sh build-push"
            echo "  undeploy     - 卸载 LLMOps Service"
            echo "  status       - 查看 LLMOps Service 状态"
            echo ""
            echo "示例:"
            echo "  $0 deploy sunmoonai app-platform-dev development"
            echo "  $0 deploy sunmoonai app-platform-prod production -c C1"
            echo "  $0 deploy sunmoonai                              # 使用默认命名空间和环境"
            echo ""
            echo "完整流程示例:"
            echo "  # 1. 构建并推送镜像"
            echo "  cd ../../../../../sunmoonai-llmops-service/build"
            echo "  ./build-image.sh build-push"
            echo ""
            echo "  # 2. 部署服务"
            echo "  cd ../../k8s/sunmoonai/app-platform/business-apps/llmops-app/llmops-app-bff/deploy-llmops-bff"
            echo "  ./deploy-llmops-service.sh deploy sunmoonai app-platform-dev development"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
