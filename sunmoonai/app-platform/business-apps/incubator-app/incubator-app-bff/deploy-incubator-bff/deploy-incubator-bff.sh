#!/bin/bash

# Incubator App BFF 部署脚本
# 用法: ./deploy-incubator-bff.sh <deploy|undeploy|status> [project_id] [namespace] [environment]
# 镜像构建请在源码仓库执行 mybuild/build-image.sh（可选推送）

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 保存 Incubator BFF 脚本的目录路径（统一部署模板会重新定义 SCRIPT_DIR）
INCUBATOR_BFF_SCRIPT_DIR="$SCRIPT_DIR"

# 导入统一部署模板
# 注意：从 incubator-app-bff/deploy-incubator-bff 到 k8s 需要 6 级
source "$PROJECT_ROOT/../../../../../utils/unified-deployment-template.sh"

# 恢复 Incubator BFF 脚本的目录路径
SCRIPT_DIR="$INCUBATOR_BFF_SCRIPT_DIR"

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
INCUBATOR_BFF_CONFIG_FILE="$SCRIPT_DIR/deploy-incubator-bff.conf"
if [[ -f "$INCUBATOR_BFF_CONFIG_FILE" ]]; then
    source "$INCUBATOR_BFF_CONFIG_FILE"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$PROJECT_ROOT/../../../../../utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/../../../../../utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
    
    log_info "已加载 Incubator App BFF 配置文件: $INCUBATOR_BFF_CONFIG_FILE"
else
    log_warn "未找到 Incubator App BFF 配置文件: $INCUBATOR_BFF_CONFIG_FILE，使用默认配置"
fi

# 默认配置（对齐 PostgreSQL 部署脚本，使用硬编码默认值）
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="app-platform-dev"
DEFAULT_ENVIRONMENT="development"

# 递归部署子组件
deploy_sub_components() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始部署 Incubator App BFF 子组件..."
    
    # 定义子组件部署顺序（按优先级排序）
    # Secrets 现在由组件自己的 secrets/deploy-secrets-all 管理
    local sub_components=(
        "incubator_bff_secrets:${secrets_enabled:-true}:${secrets_priority:-2000}:Incubator App BFF Secrets:$SCRIPT_DIR/secrets/deploy-secrets-all/deploy-secrets-all.sh"
        "incubator_bff_middleware:${middleware_enabled:-false}:${middleware_priority:-1000}:Incubator App BFF 中间件:$SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh"
        "incubator_bff_ingress:${ingress_enabled:-false}:${ingress_priority:-100}:Incubator App BFF HTTP 路由:$SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh"
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
                if [[ "$name" == "incubator_bff_ingress" ]]; then
                    if bash "$script_path" deploy "$project_id" "$namespace" "$environment"; then
                        log_success "✅ $description 部署成功"
                    else
                        log_error "❌ $description 部署失败"
                        return 1
                    fi
                else
                    # 其他子组件可以传递 dry_run 参数
                    if bash "$script_path" deploy "$project_id" "$namespace" "$environment" "$dry_run"; then
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
    
    log_success "✅ Incubator App BFF 子组件部署完成"
    return 0
}

# 镜像配置（从部署配置文件读取，用于部署时指定镜像）
# 镜像名称和标签应该与 build/build.conf 中的配置保持一致
INCUBATOR_BFF_IMAGE="${INCUBATOR_BFF_IMAGE:-incubator-app-bff}"
INCUBATOR_BFF_TAG="${INCUBATOR_BFF_TAG:-1.0.0}"

# 资源文件路径（对齐项目结构）
RESOURCES_DIR="../resource"
INCUBATOR_BFF_YAML="${RESOURCES_DIR}/incubator-app-bff.yaml"
SECRETS_DIR="$SCRIPT_DIR/secrets"
INCUBATOR_BFF_CONFIGMAP="${SECRETS_DIR}/incubator-app-bff-config/incubator-app-bff-config.yaml"
INCUBATOR_BFF_SECRET="${SECRETS_DIR}/incubator-app-bff-secret/incubator-app-bff-secret.yaml"

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
            echo "  2. 端口是否被占用（当前错误显示端口 6442 已被占用）"
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
    if [ ! -f "$INCUBATOR_BFF_YAML" ]; then
        log_error "配置文件不存在: $INCUBATOR_BFF_YAML"
        log_info "请确保资源文件存在: $RESOURCES_DIR/incubator-app-bff.yaml"
        exit 1
    fi
    
    if [[ "${secrets_enabled:-true}" == "true" ]]; then
        # 检查 ConfigMap 和 Secret 的部署脚本
        local config_script="$SECRETS_DIR/incubator-app-bff-config/deploy-incubator-app-bff-config/deploy-incubator-app-bff-config.sh"
        local secret_script="$SECRETS_DIR/incubator-app-bff-secret/deploy-incubator-app-bff-secret/deploy-incubator-app-bff-secret.sh"
        [[ -f "$config_script" ]] || { log_error "缺少 ConfigMap 部署脚本: $config_script"; exit 1; }
        [[ -f "$secret_script" ]] || { log_error "缺少 Secret 部署脚本: $secret_script"; exit 1; }
    fi
    
    # 检查 envsubst 是否可用
    if ! command -v envsubst &> /dev/null; then
        log_error "envsubst 命令未找到，请安装 gettext 包"
        log_info "Ubuntu/Debian: sudo apt-get install gettext-base"
        log_info "CentOS/RHEL: sudo yum install gettext"
        exit 1
    fi
}

# deploy_secrets_config 函数已移除
# Secrets 和 ConfigMaps 现在通过 deploy_sub_components 统一管理
# 使用 secrets/deploy-secrets-all/deploy-secrets-all.sh 统一部署

# 部署 Incubator App BFF
deploy_app() {
    log_info "开始部署 Incubator App BFF..."
    log_info "环境: $ENVIRONMENT, 命名空间: $NAMESPACE"
    
    # 检查环境配置
    check_env_config
    
    # deploy 命令：使用 Harbor 镜像部署
    # 注意：部署前请确保镜像已构建并推送到 Harbor
    # 构建镜像请使用: cd ../mybuild && ./build-image.sh build-push
    INCUBATOR_BFF_FULL_IMAGE_NAME="${INCUBATOR_BFF_IMAGE_REGISTRY}/${INCUBATOR_BFF_IMAGE_PROJECT}/${INCUBATOR_BFF_IMAGE}:${INCUBATOR_BFF_TAG}"
    IMAGE_PULL_POLICY="IfNotPresent"  # 如果本地有则使用，否则从仓库拉取
    log_info "使用 Harbor 镜像部署: $INCUBATOR_BFF_FULL_IMAGE_NAME"
    log_info "Kubernetes 将从镜像仓库拉取镜像"
    log_warn "⚠️  请确保该镜像已存在于 Harbor 仓库中"
    
    # 准备环境变量
    export NAMESPACE="$NAMESPACE"
    export ENV="$ENV"  # 保留 ENV 用于兼容性（YAML 中可能使用）
    export ENVIRONMENT="$ENVIRONMENT"
    export INCUBATOR_BFF_IMAGE_REGISTRY="${INCUBATOR_BFF_IMAGE_REGISTRY:-harbor.sunmoonai.com:30443}"
    export INCUBATOR_BFF_IMAGE_PROJECT="${INCUBATOR_BFF_IMAGE_PROJECT:-k8s-images}"
    export INCUBATOR_BFF_IMAGE="${INCUBATOR_BFF_IMAGE}"
    export INCUBATOR_BFF_TAG="${INCUBATOR_BFF_TAG}"
    export INCUBATOR_BFF_FULL_IMAGE_NAME="$INCUBATOR_BFF_FULL_IMAGE_NAME"
    export IMAGE_PULL_POLICY="${IMAGE_PULL_POLICY:-IfNotPresent}"
    export INCUBATOR_BFF_IMAGE_PULL_SECRET_NAME="${INCUBATOR_BFF_IMAGE_PULL_SECRET_NAME:-harbor-registry-secret}"
    
    # ============================================================
    # 阶段1：部署子级组件（按优先级，先部署依赖项）
    # ============================================================
    log_info "🚀 阶段1：部署 Incubator App BFF 子级组件..."
    if ! deploy_sub_components "$PROJECT_ID" "$NAMESPACE" "$ENVIRONMENT" false; then
        log_error "❌ Incubator App BFF 子级组件部署失败！"
        return 1
    fi
    log_success "✅ Incubator App BFF 子级组件部署完成"
    
    # ============================================================
    # 阶段2：部署本级核心服务（Deployment 和 Service）
    # ============================================================
    log_info "🚀 阶段2：部署 Incubator App BFF 核心服务..."
    log_info "部署 Incubator App BFF (环境: $ENVIRONMENT, 镜像: $INCUBATOR_BFF_FULL_IMAGE_NAME, 拉取策略: ${IMAGE_PULL_POLICY:-IfNotPresent}, 命名空间: $NAMESPACE)..."
    # 创建临时文件并替换环境变量（包括镜像名称、拉取策略和命名空间）
    TEMP_YAML=$(mktemp)
    # 先使用 sed 处理 ${VAR:-default} 语法，将其转换为 ${VAR}（因为 envsubst 不支持默认值语法）
    # 我们确保所有变量都已 export，所以可以安全地移除默认值部分
    sed -e 's/\${\([^:}]*\):-[^}]*}/\${\1}/g' "$INCUBATOR_BFF_YAML" | envsubst > "$TEMP_YAML"
    kubectl apply -f "$TEMP_YAML" -n "$NAMESPACE"
    rm -f "$TEMP_YAML"
    
    if [ $? -eq 0 ]; then
        log_success "Incubator App BFF 部署完成！"
        echo ""
        log_info "检查部署状态:"
        echo "  kubectl get pods -n $NAMESPACE -l app=incubator-app-bff"
        echo "  kubectl get svc -n $NAMESPACE -l app=incubator-app-bff"
        echo ""
        log_info "查看 Pod 日志:"
        echo "  kubectl logs -n $NAMESPACE -l app=incubator-app-bff -f"
    else
        log_error "Incubator App BFF 部署失败"
        exit 1
    fi
}

# 卸载 Incubator App BFF
undeploy_app() {
    log_info "开始卸载 Incubator App BFF..."
    log_info "环境: $ENVIRONMENT, 命名空间: $NAMESPACE"
    
    check_env_config
    
    # ============================================================
    # 阶段1：卸载本级核心服务（Deployment 和 Service）
    # ============================================================
    log_info "🚀 阶段1：卸载 Incubator App BFF 核心服务..."
    # 卸载时使用原始 YAML（删除时不需要替换镜像，但需要替换命名空间）
    TEMP_YAML=$(mktemp)
    export NAMESPACE="$NAMESPACE"
    export ENV="$ENV"  # 保留 ENV 用于兼容性（YAML 中可能使用）
    export ENVIRONMENT="$ENVIRONMENT"
    envsubst < "$INCUBATOR_BFF_YAML" > "$TEMP_YAML"
    kubectl delete -f "$TEMP_YAML" -n "$NAMESPACE" --ignore-not-found=true
    rm -f "$TEMP_YAML"
    log_success "✅ Incubator App BFF 核心服务卸载完成"
    
    # ============================================================
    # 阶段2：卸载子级组件（按优先级，逆序卸载）
    # ============================================================
    log_info "🚀 阶段2：卸载 Incubator App BFF 子级组件..."
    if ! uninstall_sub_components "$PROJECT_ID" "$NAMESPACE" "$ENVIRONMENT" false; then
        log_warn "⚠️ Incubator App BFF 子级组件卸载部分失败，继续..."
    fi
    log_success "✅ Incubator App BFF 子级组件卸载完成"
    
    log_success "Incubator App BFF 卸载完成！"
}

# 卸载子组件（按优先级，逆序）
uninstall_sub_components() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始卸载 Incubator App BFF 子组件..."
    
    # 定义子组件卸载顺序（按优先级排序，逆序卸载）
    local sub_components=(
        "incubator_bff_middleware:${middleware_enabled:-false}:${middleware_priority:-1000}:Incubator App BFF 中间件:$SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh"
        "incubator_bff_ingress:${ingress_enabled:-false}:${ingress_priority:-100}:Incubator App BFF HTTP 路由:$SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh"
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
                # Ingress 脚本使用 uninstall 命令
                if [[ "$name" == "incubator_bff_ingress" ]]; then
                    if DISABLE_AUTO_CLEANUP=true bash "$script_path" uninstall "$project_id" "$namespace" "$environment"; then
                        log_success "✅ $description 卸载成功"
                    else
                        log_error "❌ $description 卸载失败"
                    fi
                else
                    # 其他子组件可能使用不同的卸载方式
                    if DISABLE_AUTO_CLEANUP=true bash "$script_path" uninstall "$project_id" "$namespace" "$environment"; then
                        log_success "✅ $description 卸载成功"
                    else
                        log_error "❌ $description 卸载失败"
                    fi
                fi
            else
                log_warn "⚠️ $description 脚本不存在: $script_path"
            fi
        fi
    done
    
    log_success "✅ Incubator App BFF 子组件卸载完成"
    return 0
}

# 显示状态
show_status() {
    log_info "Incubator App BFF 状态:"
    echo ""
    echo "📦 Pods:"
    kubectl get pods -n "$NAMESPACE" -l app=incubator-app-bff 2>/dev/null || echo "  无 Pod 运行"
    echo ""
    echo "🌐 Services:"
    kubectl get svc -n "$NAMESPACE" -l app=incubator-app-bff 2>/dev/null || echo "  无 Service"
    echo ""
    echo "📋 Deployments:"
    kubectl get deployment -n "$NAMESPACE" -l app=incubator-app-bff 2>/dev/null || echo "  无 Deployment"
    echo ""
    echo "📋 ConfigMaps:"
    kubectl get configmap -n "$NAMESPACE" -l app=incubator-app-bff 2>/dev/null || echo "  无 ConfigMap"
    echo ""
    echo "🔐 Secrets:"
    kubectl get secret -n "$NAMESPACE" -l app=incubator-app-bff 2>/dev/null || echo "  无 Secret"
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
    
    log_info "Incubator App BFF 部署脚本启动"
    log_info "操作: $ACTION, 项目: $PROJECT_ID, 命名空间: $NAMESPACE, 环境: $ENVIRONMENT"
    
    check_kubectl
    
    case "$ACTION" in
        "deploy")
            log_info "开始部署 Incubator App BFF..."
            
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
            
            deploy_app
            show_status
            ;;
        "undeploy")
            if ! check_namespace "$namespace"; then
                log_error "❌ 命名空间检查失败"
                exit 1
            fi
            undeploy_app
            ;;
        "status")
            show_status
            ;;
        *)
            log_error "无效的操作: $ACTION"
            echo "用法: $0 <action> [project_id] [namespace] [environment]"
            echo ""
            echo "操作:"
            echo "  deploy     部署 Incubator App BFF"
            echo "  undeploy   卸载 Incubator App BFF"
            echo "  status     查看 Incubator App BFF 状态"
            echo ""
            echo "参数说明:"
            echo "  project_id   项目标识符（默认: $DEFAULT_PROJECT_ID）"
            echo "  namespace    命名空间（默认: $DEFAULT_NAMESPACE）"
            echo "  environment  环境（默认: $DEFAULT_ENVIRONMENT）"
            echo ""
            echo "操作说明:"
            echo "  deploy       - 部署到 Kubernetes（从 Harbor 拉取镜像）"
            echo "                注意: 部署前请确保镜像已构建并推送到 Harbor"
            echo "                构建镜像: cd ../mybuild && ./build-image.sh build-push"
            echo "  undeploy     - 卸载 Incubator App BFF"
            echo "  status       - 查看 Incubator App BFF 状态"
            echo ""
            echo "示例:"
            echo "  $0 deploy sunmoonai app-platform-dev development"
            echo "  $0 deploy sunmoonai app-platform-prod production"
            echo "  $0 deploy sunmoonai                              # 使用默认命名空间和环境"
            echo ""
            echo "环境:"
            echo "  development  开发环境"
            echo "  production   生产环境"
            echo ""
            echo "完整流程示例:"
            echo "  # 1. 构建并推送镜像"
            echo "  cd ../mybuild"
            echo "  ./build-image.sh build-push"
            echo ""
            echo "  # 2. 部署服务"
            echo "  cd ../deploy-incubator-bff"
            echo "  ./deploy-incubator-bff.sh deploy sunmoonai app-platform-dev development"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"

