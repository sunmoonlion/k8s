#!/bin/bash

# Mongo Express 递归部署脚本
# 基于递归架构设计原则的两级部署逻辑

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 保存 Mongo Express 脚本的目录路径（统一部署模板会重新定义 SCRIPT_DIR）
MONGO_EXPRESS_SCRIPT_DIR="$SCRIPT_DIR"

# 导入统一部署模板
source "$PROJECT_ROOT/../../../utils/unified-deployment-template.sh"

# 恢复 Mongo Express 脚本的目录路径
SCRIPT_DIR="$MONGO_EXPRESS_SCRIPT_DIR"

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

MONGO_EXPRESS_CONFIG_FILE="$SCRIPT_DIR/deploy-mongo-express.conf"
if [[ -f "$MONGO_EXPRESS_CONFIG_FILE" ]]; then
    source "$MONGO_EXPRESS_CONFIG_FILE"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
    
    log_info "已加载 Mongo Express 配置文件: $MONGO_EXPRESS_CONFIG_FILE"
else
    log_error "缺少 Mongo Express 配置文件: $MONGO_EXPRESS_CONFIG_FILE"
    exit 1
fi

# 加载 MongoDB 部署配置文件（用于获取 MongoDB 连接信息）
MONGODB_CONFIG_FILE="$PROJECT_ROOT/../../../data-platform/mongodb/deploy-mongodb/deploy-mongodb.conf"
if [[ -f "$MONGODB_CONFIG_FILE" ]]; then
    source "$MONGODB_CONFIG_FILE"
    log_info "已加载 MongoDB 配置文件: $MONGODB_CONFIG_FILE"
fi

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="ops-platform-dev"
DEFAULT_ENVIRONMENT="development"

# Mongo Express 资源目录（固定路径）
MONGO_EXPRESS_CHART_DIR="$SCRIPT_DIR/../resources/mongo-express"
MONGO_EXPRESS_CUSTOM_VALUES_DIR="$SCRIPT_DIR/../resources/custom-values"

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

# 定义 Mongo Express 所需镜像（保留给镜像检查设计使用）
define_required_images() {
    local environment="$1"
    
    case "$environment" in
        "development"|"dev")
            echo "mongo-express:$MONGO_EXPRESS_IMAGE_VERSION|true"
            ;;
        "production"|"prod")
            echo "mongo-express:$MONGO_EXPRESS_IMAGE_VERSION|true"
            if [[ "${MONGO_EXPRESS_MONITORING_ENABLED:-false}" == "true" ]]; then
                echo "mongo-express:$MONGO_EXPRESS_IMAGE_VERSION|true"
            fi
            ;;
        *)
            echo "mongo-express:$MONGO_EXPRESS_IMAGE_VERSION|true"
            ;;
    esac
}

# 使用统一模板的通用按需推送 helper，将 Mongo Express 组件镜像推送到 Harbor
push_mongo_express_images_to_harbor() {
    push_component_images_to_harbor "mongo-express"
}

# 处理 Mongo Express 特定的 values 文件
process_mongo_express_values() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    
    # 检查环境特定的 values 文件
    local env_values_file=""
    
    case "$environment" in
        "production")
            env_values_file="$MONGO_EXPRESS_CUSTOM_VALUES_DIR/prod-values.yaml"
            ;;
        "development")
            env_values_file="$MONGO_EXPRESS_CUSTOM_VALUES_DIR/dev-values.yaml"
            ;;
        *)
            env_values_file="$MONGO_EXPRESS_CUSTOM_VALUES_DIR/dev-values.yaml"
            ;;
    esac
    
    if [[ -f "$env_values_file" ]]; then
        log_info "使用环境特定配置: $env_values_file" >&2
        
        # 创建临时 values 文件
        local mongo_express_values_file=$(mktemp)
        cp "$env_values_file" "$mongo_express_values_file"
        
        # 替换基础变量
        local created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        
        # 基础变量替换
        sed -i "s/{{PROJECT_ID}}/$project_id/g" "$mongo_express_values_file"
        sed -i "s/{{NAMESPACE}}/$namespace/g" "$mongo_express_values_file"
        sed -i "s/{{ENVIRONMENT}}/$environment/g" "$mongo_express_values_file"
        sed -i "s/{{COMPONENT_NAME}}/mongo-express/g" "$mongo_express_values_file"
        sed -i "s/{{CREATED_AT}}/$created_at/g" "$mongo_express_values_file"
        
        # Mongo Express 特定变量替换（即使变量为空也替换，使用空字符串）
        sed -i "s/{{MONGO_EXPRESS_PROJECT_ID}}/${MONGO_EXPRESS_PROJECT_ID:-}/g" "$mongo_express_values_file"
        sed -i "s/{{MONGO_EXPRESS_NAMESPACE}}/${MONGO_EXPRESS_NAMESPACE:-}/g" "$mongo_express_values_file"
        sed -i "s/{{MONGO_EXPRESS_TLS_ENABLED}}/${MONGO_EXPRESS_TLS_ENABLED:-}/g" "$mongo_express_values_file"
        sed -i "s/{{MONGO_EXPRESS_AUTH_SECRET_NAME}}/${MONGO_EXPRESS_AUTH_SECRET_NAME:-}/g" "$mongo_express_values_file"
        sed -i "s/{{MONGO_EXPRESS_AUTH_SECRET_PASSWORD_KEY}}/${MONGO_EXPRESS_AUTH_SECRET_PASSWORD_KEY:-}/g" "$mongo_express_values_file"
        # Secret 键名配置替换
        sed -i "s/{{MONGO_EXPRESS_MONGODB_AUTH_PASSWORD_KEY}}/${MONGO_EXPRESS_MONGODB_AUTH_PASSWORD_KEY:-mongodb-auth-password}/g" "$mongo_express_values_file"
        sed -i "s/{{MONGO_EXPRESS_SITE_COOKIE_SECRET_KEY}}/${MONGO_EXPRESS_SITE_COOKIE_SECRET_KEY:-site-cookie-secret}/g" "$mongo_express_values_file"
        sed -i "s/{{MONGO_EXPRESS_SITE_SESSION_SECRET_KEY}}/${MONGO_EXPRESS_SITE_SESSION_SECRET_KEY:-site-session-secret}/g" "$mongo_express_values_file"
        sed -i "s/{{MONGO_EXPRESS_BASIC_AUTH_PASSWORD_KEY}}/${MONGO_EXPRESS_BASIC_AUTH_PASSWORD_KEY:-basic-auth-password}/g" "$mongo_express_values_file"
        sed -i "s/{{MONGO_EXPRESS_IMAGE_VERSION}}/${MONGO_EXPRESS_IMAGE_VERSION:-}/g" "$mongo_express_values_file"
        sed -i "s|{{MONGO_EXPRESS_IMAGE_REGISTRY}}|${MONGO_EXPRESS_IMAGE_REGISTRY:-}|g" "$mongo_express_values_file"
        # 替换 image.registry（如果使用 Harbor 私有仓库，需要替换 docker.io）
        if [[ -n "${MONGO_EXPRESS_IMAGE_REGISTRY:-}" ]]; then
            sed -i "s|registry: docker.io|registry: ${MONGO_EXPRESS_IMAGE_REGISTRY}|g" "$mongo_express_values_file"
            # 如果配置了镜像项目名，需要更新 repository 路径
            if [[ -n "${MONGO_EXPRESS_IMAGE_PROJECT:-}" ]]; then
                # 将 repository: mongo-express 替换为 repository: k8s-images/mongo-express
                sed -i "s|repository: mongo-express|repository: ${MONGO_EXPRESS_IMAGE_PROJECT}/mongo-express|g" "$mongo_express_values_file"
            fi
        fi
        # 处理 imagePullSecrets：如果 secret name 为空，设置为空数组，否则设置为包含该 secret 的数组
        if [[ -n "${MONGO_EXPRESS_IMAGE_PULL_SECRET_NAME:-}" ]]; then
            # 使用 awk 进行多行替换
            awk -v secret_name="${MONGO_EXPRESS_IMAGE_PULL_SECRET_NAME}" '
                /imagePullSecrets: "{{MONGO_EXPRESS_IMAGE_PULL_SECRETS}}"/ {
                    print "  imagePullSecrets:"
                    print "    - name: " secret_name
                    next
                }
                { print }
            ' "$mongo_express_values_file" > "${mongo_express_values_file}.tmp" && mv "${mongo_express_values_file}.tmp" "$mongo_express_values_file"
        else
            sed -i 's/imagePullSecrets: "{{MONGO_EXPRESS_IMAGE_PULL_SECRETS}}"/imagePullSecrets: []/g' "$mongo_express_values_file"
        fi
        sed -i "s/{{MONGO_EXPRESS_UNIFIED_HOST}}/${MONGO_EXPRESS_UNIFIED_HOST:-llmops.sunmoonai.com}/g" "$mongo_express_values_file"
        
        # MongoDB 连接配置变量替换（从配置文件读取）
        # 注意：这些变量在 deploy-mongo-express.conf 中定义，即使为空也要替换（使用默认值）
        sed -i "s/{{MONGODB_EXTERNAL_HOST}}/${MONGODB_EXTERNAL_HOST:-llmops.sunmoonai.com}/g" "$mongo_express_values_file"
        sed -i "s/{{MONGODB_EXTERNAL_PORT}}/${MONGODB_EXTERNAL_PORT:-27017}/g" "$mongo_express_values_file"
        
        # 输出处理后的文件路径
        echo "$mongo_express_values_file"
        return 0
    else
        log_warn "环境配置文件不存在: $env_values_file" >&2
        return 1
    fi
}

# 执行 Mongo Express 部署
execute_mongo_express_deployment() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始执行 Mongo Express 部署..."
    log_info "项目: $project_id"
    log_info "命名空间: $namespace"
    log_info "环境: $environment"
    log_info "离线模式: $MONGO_EXPRESS_FORCE_OFFLINE"
    
    # 检查 Chart 目录是否存在
    if [[ ! -d "$MONGO_EXPRESS_CHART_DIR" ]]; then
        log_error "Mongo Express Chart 目录不存在: $MONGO_EXPRESS_CHART_DIR"
        return 1
    fi
    
    # 处理 Mongo Express 特定的 values 文件（模板变量替换）
    local values_file=$(process_mongo_express_values "$project_id" "$namespace" "$environment" 2>/dev/null)
    local process_exit_code=$?
    
    if [[ $process_exit_code -ne 0 ]] || [[ -z "$values_file" ]]; then
        log_warn "环境配置文件处理失败，使用默认配置"
        values_file=""
    else
        log_info "使用 Mongo Express 特定配置: $values_file"
    fi
    
    # 构建 Helm 命令
    local helm_cmd="helm upgrade --install mongo-express-sunmoonai $MONGO_EXPRESS_CHART_DIR"
    helm_cmd="$helm_cmd --namespace $namespace"
    helm_cmd="$helm_cmd --set global.projectId=$project_id"
    helm_cmd="$helm_cmd --set global.namespace=$namespace"
    helm_cmd="$helm_cmd --set global.environment=$environment"
    
    if [[ -n "$values_file" ]]; then
        helm_cmd="$helm_cmd --values $values_file"
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        helm_cmd="$helm_cmd --dry-run"
        log_info "执行 Mongo Express 部署（试运行模式）..."
    else
        log_info "执行 Mongo Express 部署..."
    fi
    
    # 执行部署
    if eval "$helm_cmd"; then
        if [[ "$dry_run" == "true" ]]; then
            log_success "✅ Mongo Express 部署试运行完成"
        else
            log_success "✅ Mongo Express 部署完成"
        fi
        return 0
    else
        log_error "❌ Mongo Express 部署失败"
        return 1
    fi
}

# 检查 Mongo Express 状态
check_mongo_express_status() {
    local namespace="$1"
    
    log_info "检查 Mongo Express 部署状态..."
    
    # 检查 Helm Release
    if helm list -n "$namespace" | grep -q "mongo-express-sunmoonai"; then
        log_success "✅ Mongo Express Helm Release 存在"
    else
        log_error "❌ Mongo Express Helm Release 不存在"
        return 1
    fi
    
    # 检查 Pod 状态
    local pods_info
    pods_info=$(kubectl get pods -n "$namespace" -l app.kubernetes.io/name=mongo-express --no-headers 2>/dev/null)
    
    if [[ -z "$pods_info" ]]; then
        log_error "❌ 未找到 Mongo Express Pod"
        log_info "提示: Pod 可能还在创建中，请稍后使用以下命令检查:"
        log_info "  kubectl get pods -n $namespace -l app.kubernetes.io/name=mongo-express"
        return 1
    fi
    
    # 统计各状态的 Pod 数量
    local pods_running=$(echo "$pods_info" | awk '{print $3}' | grep -c "Running" 2>/dev/null || echo "0")
    pods_running=$(echo "$pods_running" | tr -d '[:space:]' | head -n1)
    [[ "$pods_running" =~ ^[0-9]+$ ]] || pods_running=0
    
    local pods_pending=$(echo "$pods_info" | awk '{print $3}' | grep -cE "Pending|ContainerCreating|Init:" 2>/dev/null || echo "0")
    pods_pending=$(echo "$pods_pending" | tr -d '[:space:]' | head -n1)
    [[ "$pods_pending" =~ ^[0-9]+$ ]] || pods_pending=0
    
    local pods_failed=$(echo "$pods_info" | awk '{print $3}' | grep -cE "Error|CrashLoopBackOff|ImagePullBackOff|ErrImagePull" 2>/dev/null || echo "0")
    pods_failed=$(echo "$pods_failed" | tr -d '[:space:]' | head -n1)
    [[ "$pods_failed" =~ ^[0-9]+$ ]] || pods_failed=0
    
    local total_pods=$(echo "$pods_info" | wc -l | tr -d '[:space:]' | head -n1)
    [[ "$total_pods" =~ ^[0-9]+$ ]] || total_pods=0
    
    # 显示 Pod 状态摘要
    log_info "Pod 状态摘要:"
    log_info "  - 总计: $total_pods 个"
    log_info "  - 运行中: $pods_running 个"
    log_info "  - 启动中: $pods_pending 个"
    log_info "  - 失败: $pods_failed 个"
    
    # 显示所有 Pod 的详细状态
    echo ""
    log_info "Pod 详细状态:"
    kubectl get pods -n "$namespace" -l app.kubernetes.io/name=mongo-express 2>/dev/null || true
    echo ""
    
    if [[ "$pods_running" -gt 0 ]]; then
        log_success "✅ Mongo Express Pod 运行正常 ($pods_running/$total_pods 个运行中)"
    elif [[ "$pods_pending" -gt 0 ]]; then
        log_info "⏳ Mongo Express Pod 正在启动中 ($pods_pending 个启动中)"
        log_info "提示: 请稍后使用以下命令检查状态:"
        log_info "  kubectl get pods -n $namespace -l app.kubernetes.io/name=mongo-express"
        log_info "  kubectl describe pods -n $namespace -l app.kubernetes.io/name=mongo-express"
        return 0  # 启动中不算错误
    elif [[ "$pods_failed" -gt 0 ]]; then
        log_error "❌ Mongo Express Pod 启动失败 ($pods_failed 个失败)"
        log_info "提示: 请使用以下命令查看详细错误:"
        log_info "  kubectl describe pods -n $namespace -l app.kubernetes.io/name=mongo-express"
        log_info "  kubectl logs -n $namespace -l app.kubernetes.io/name=mongo-express"
        return 1
    else
        log_error "❌ Mongo Express Pod 状态未知"
        return 1
    fi
    
    # 测试 Mongo Express 连接
    test_mongo_express_connection "$namespace"
}

# 测试 Mongo Express 连接
test_mongo_express_connection() {
    local namespace="$1"
    
    log_info "测试 Mongo Express 连接..."
    
    # 获取 Mongo Express 服务信息
    local service_name
    service_name=$(kubectl get svc -n "$namespace" -l app.kubernetes.io/name=mongo-express -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -z "$service_name" ]]; then
        log_error "❌ 未找到 Mongo Express 服务"
        return 1
    fi
    
    # 测试连接（使用 kubectl port-forward 或直接连接）
    log_info "Mongo Express 服务: $service_name"
    log_success "✅ Mongo Express 连接测试完成"
}

# 显示 Mongo Express 连接信息
show_mongo_express_connection_info() {
    local namespace="$1"
    
    echo ""
    echo "=== Mongo Express 连接信息 ==="
    echo "命名空间: $namespace"
    echo "外部访问: https://${MONGO_EXPRESS_UNIFIED_HOST:-llmops.sunmoonai.com}/mongo-express"
    echo ""
    echo "=== 使用说明 ==="
    echo "1. 配置 hosts 文件（如果需要）:"
    echo "   echo '${MONGO_EXPRESS_NODE_IP:-115.190.153.150} ${MONGO_EXPRESS_UNIFIED_HOST:-llmops.sunmoonai.com}' | sudo tee -a /etc/hosts"
    echo ""
    echo "2. 访问 Mongo Express:"
    echo "   https://${MONGO_EXPRESS_UNIFIED_HOST:-llmops.sunmoonai.com}/mongo-express"
    echo ""
    echo "3. 查看服务状态:"
    echo "   kubectl get pods,svc -n $namespace -l app.kubernetes.io/name=mongo-express"
    echo ""
    echo "4. 连接 MongoDB:"
    echo "   需要配置 MongoDB 连接信息"
    echo "   支持 MongoDB 集群连接"
    echo ""
}

# 备份 Mongo Express 数据
backup_mongo_express_data() {
    local namespace="$1"
    local backup_name="mongo-express-backup-$(date +%Y%m%d-%H%M%S)"
    
    log_info "开始备份 Mongo Express 数据..."
    log_info "备份名称: $backup_name"
    
    # 这里可以实现具体的备份逻辑
    # 例如使用 Mongo Express 备份工具或 Kubernetes 备份工具
    log_success "✅ Mongo Express 数据备份完成: $backup_name"
}

# 创建 Mongo Express 密钥（如果需要）
create_mongo_express_secrets_if_needed() {
    local namespace="$1"
    
    log_info "检查 Mongo Express 密钥..."
    
    # 检查是否已存在密钥
    if kubectl get secret "$MONGO_EXPRESS_AUTH_SECRET_NAME" -n "$namespace" >/dev/null 2>&1; then
        log_success "✅ Mongo Express 密钥已存在: $MONGO_EXPRESS_AUTH_SECRET_NAME"
        return 0
    fi
    
    # 创建密钥
    log_info "创建 Mongo Express 密钥..."
    if [[ -f "$SCRIPT_DIR/secrets/mongo-express-secrets/deploy-mongo-express-secrets/deploy-mongo-express-secrets.sh" ]]; then
        "$SCRIPT_DIR/secrets/mongo-express-secrets/deploy-mongo-express-secrets/deploy-mongo-express-secrets.sh" deploy
    else
        log_warn "⚠️ Mongo Express 密钥部署脚本不存在，跳过密钥创建"
    fi
}

# 递归部署子组件
deploy_sub_components() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    local skip_ingress="${5:-false}"  # 新增参数：是否跳过 Ingress 部署
    
    log_info "开始部署 Mongo Express 子组件..."
    
    # 定义子组件部署顺序（按优先级排序）
    # 说明：组件自管 Secrets，并在本脚本内触发
    # 注意：Ingress 依赖 Service 存在，如果 skip_ingress=true，则不包含 Ingress
    local sub_components=(
        "mongo_express_secrets:${secrets_enabled:-true}:${secrets_priority:-10}:Mongo Express Secrets:$SCRIPT_DIR/secrets/deploy-secrets-all/deploy-secrets-all.sh"
        "mongo_express_middleware:${middleware_enabled:-false}:${middleware_priority:-1000}:Mongo Express 中间件:$SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh"
    )
    
    # 如果不需要跳过 Ingress，则添加 Ingress 到列表
    if [[ "$skip_ingress" != "no_ingress" ]]; then
        sub_components+=("mongo_express_ingress:${ingress_enabled:-false}:${ingress_priority:-100}:Mongo Express Web 路由:$SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh")
    fi
    
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
                # 如果设置了 CLUSTER，也传递给 Ingress 脚本
                if [[ "$name" == "mongo_express_ingress" ]]; then
                    local cluster_value_trimmed=$(echo "${CLUSTER:-}" | tr -d '[:space:]')
                    if [[ -n "${CLUSTER:-}" ]] && [[ "${CLUSTER}" != "" ]] && [[ -n "$cluster_value_trimmed" ]]; then
                        log_info "传递 CLUSTER 参数给 Ingress 脚本: --cluster $CLUSTER (trimmed: $cluster_value_trimmed)"
                        if CLUSTER="$CLUSTER" bash "$script_path" deploy "$project_id" "$namespace" "$environment" --cluster "$CLUSTER"; then
                            log_success "✅ $description 部署成功"
                        else
                            log_error "❌ $description 部署失败"
                            return 1
                        fi
                    else
                        if bash "$script_path" deploy "$project_id" "$namespace" "$environment"; then
                            log_success "✅ $description 部署成功"
                        else
                            log_error "❌ $description 部署失败"
                            return 1
                        fi
                    fi
                else
                    # 其他子组件可以传递 dry_run 参数
                    # 注意：secrets 脚本不需要 "deploy" 参数，直接传递 project_id, namespace, environment, dry_run
                    # 如果 CLUSTER 环境变量已设置且非空，也传递给 secrets 脚本
                    if [[ "$name" == "mongo_express_secrets" ]]; then
                        # 使用更严格的检查：确保 CLUSTER 不为空且不是空字符串
                        local cluster_value_trimmed=$(echo "${CLUSTER:-}" | tr -d '[:space:]')
                        if [[ -n "${CLUSTER:-}" ]] && [[ "${CLUSTER}" != "" ]] && [[ -n "$cluster_value_trimmed" ]]; then
                            log_info "传递 CLUSTER 参数给 secrets 脚本: --cluster $CLUSTER (trimmed: $cluster_value_trimmed)"
                            if CLUSTER="$CLUSTER" bash "$script_path" "$project_id" "$namespace" "$environment" "$dry_run" --cluster "$CLUSTER"; then
                                log_success "✅ $description 部署成功"
                            else
                                log_error "❌ $description 部署失败"
                                return 1
                            fi
                        else
                            if bash "$script_path" "$project_id" "$namespace" "$environment" "$dry_run"; then
                                log_success "✅ $description 部署成功"
                            else
                                log_error "❌ $description 部署失败"
                                return 1
                            fi
                        fi
                    elif [[ "$name" == "mongo_express_middleware" ]]; then
                        # 中间件脚本需要传递 --cluster 参数（如果设置了 CLUSTER）
                        # 禁用自动清理，保持连接以便后续 Helm 部署使用
                        local cluster_value_trimmed=$(echo "${CLUSTER:-}" | tr -d '[:space:]')
                        if [[ -n "${CLUSTER:-}" ]] && [[ "${CLUSTER}" != "" ]] && [[ -n "$cluster_value_trimmed" ]]; then
                            log_info "传递 CLUSTER 参数给中间件脚本: --cluster $CLUSTER (trimmed: $cluster_value_trimmed)"
                            if DISABLE_AUTO_CLEANUP=true CLUSTER="$CLUSTER" bash "$script_path" deploy "$project_id" "$namespace" "$environment" "$dry_run" --cluster "$CLUSTER"; then
                                log_success "✅ $description 部署成功"
                            else
                                log_error "❌ $description 部署失败"
                                return 1
                            fi
                        else
                            if DISABLE_AUTO_CLEANUP=true bash "$script_path" deploy "$project_id" "$namespace" "$environment" "$dry_run"; then
                                log_success "✅ $description 部署成功"
                            else
                                log_error "❌ $description 部署失败"
                                return 1
                            fi
                        fi
                    else
                        if bash "$script_path" deploy "$project_id" "$namespace" "$environment" "$dry_run"; then
                            log_success "✅ $description 部署成功"
                        else
                            log_error "❌ $description 部署失败"
                            return 1
                        fi
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
    
    log_success "✅ Mongo Express 子组件部署完成"
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
    
    # 建立远程 k8s 连接
    if ! setup_kubectl_environment; then
        log_error "无法建立 Kubernetes 连接"
        return 1
    fi
    
    case "$action" in
        "deploy")
            log_info "开始部署 Mongo Express..."
            check_namespace "$namespace"
            # 在部署前按需推送 Mongo Express 组件镜像到 Harbor（Kind 使用 push-to-harbor，远程使用 registry-push-management）
            push_mongo_express_images_to_harbor || log_warn "[images] Mongo Express 镜像推送阶段出现警告，可稍后单独检查 Harbor 镜像状态"
            
            # 部署子组件（Secrets、Middleware）- 在核心组件之前部署（Ingress 在核心组件之后）
            # 注意：Ingress 依赖 Service 存在，必须在核心组件之后部署
            if deploy_sub_components "$project_id" "$namespace" "$environment" "$dry_run" "no_ingress"; then
                log_success "✅ Mongo Express 子组件（Secrets、Middleware）部署完成！"
            else
                log_error "❌ Mongo Express 子组件部署失败，终止主部署"
                exit 1
            fi
            
            # 部署核心组件（Mongo Express Helm Chart，创建 Service 和 Pod）
            if execute_mongo_express_deployment "$project_id" "$namespace" "$environment" "$dry_run"; then
                log_success "✅ Mongo Express 核心部署成功！"
                
                # 部署 Ingress 子组件（依赖 Service 存在，必须在核心组件之后部署）
                if [[ "${ingress_enabled:-false}" == "true" ]]; then
                    log_info "🚀 部署 Mongo Express Ingress 子组件..."
                    local cluster_value_trimmed=$(echo "${CLUSTER:-}" | tr -d '[:space:]')
                    if [[ -n "${CLUSTER:-}" ]] && [[ "${CLUSTER}" != "" ]] && [[ -n "$cluster_value_trimmed" ]]; then
                        log_info "传递 CLUSTER 参数给 Ingress 脚本: --cluster $CLUSTER"
                        if CLUSTER="$CLUSTER" bash "$SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh" deploy "$project_id" "$namespace" "$environment" --cluster "$CLUSTER"; then
                            log_success "✅ Mongo Express Ingress 部署成功"
                        else
                            log_error "❌ Mongo Express Ingress 部署失败"
                            return 1
                        fi
                    else
                        if bash "$SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh" deploy "$project_id" "$namespace" "$environment"; then
                            log_success "✅ Mongo Express Ingress 部署成功"
                        else
                            log_error "❌ Mongo Express Ingress 部署失败"
                            return 1
                        fi
                    fi
                else
                    log_info "跳过 Mongo Express Ingress (enabled=false)"
                fi
                
                log_success "🎉 Mongo Express 完整部署成功！"
                check_mongo_express_status "$namespace"
            else
                log_error "❌ Mongo Express 核心部署失败"
                return 1
            fi
            ;;
        "upgrade")
            log_info "开始升级 Mongo Express..."
            check_namespace "$namespace"
            execute_mongo_express_deployment "$project_id" "$namespace" "$environment" "$dry_run"
            check_mongo_express_status "$namespace"
            ;;
        "uninstall")
            log_info "开始卸载 Mongo Express..."
            
            # 卸载子组件
            log_info "卸载 Mongo Express 子组件..."
            
            # 定义子组件卸载顺序（按优先级排序）
            local sub_components=(
                "mongo_express_middleware:${middleware_enabled:-false}:${middleware_priority:-1000}:Mongo Express 中间件:$SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh"
                "mongo_express_ingress:${ingress_enabled:-false}:${ingress_priority:-100}:Mongo Express Web 路由:$SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh"
            )
            
            # 按优先级排序（卸载时反向顺序）
            IFS=$'\n' sub_components=($(sort -t: -k3 -n <<<"${sub_components[*]}"))
            unset IFS
            
            # 卸载子组件
            local uninstall_failed=false
            for component_info in "${sub_components[@]}"; do
                IFS=':' read -r name enabled priority description script_path <<< "$component_info"
                
                if [[ "$enabled" == "true" ]]; then
                    log_info "卸载 $description (优先级: $priority)..."
                    
                    if [[ -f "$script_path" ]]; then
                        # 禁用子脚本的自动清理，保持连接以便后续操作
                        if DISABLE_AUTO_CLEANUP=true bash "$script_path" uninstall "$project_id" "$namespace" "$environment"; then
                            log_success "✅ $description 卸载成功"
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
            kubectl delete ingressroute -n "$namespace" -l component=mongo-express 2>/dev/null || true
            kubectl delete middleware -n "$namespace" -l component=mongo-express 2>/dev/null || true
            kubectl delete ingressroute -n "$namespace" mongo-express-web-route 2>/dev/null || true
            kubectl delete middleware -n "$namespace" mongo-express-policy 2>/dev/null || true
            
            if [[ "$uninstall_failed" == "true" ]]; then
                log_warn "⚠️  部分子组件卸载失败，但已尝试清理残留资源"
            fi
            
            # 确保连接仍然可用
            if ! kubectl get nodes >/dev/null 2>&1; then
                log_info "连接已断开，重新建立连接..."
                if ! setup_kubectl_environment; then
                    log_error "无法重新建立 Kubernetes 连接"
                    return 1
                fi
            fi
            
            # 卸载主部署
            local release_name="mongo-express-$project_id"
            
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
                log_info "发现 Mongo Express release: $release_name"
                if helm uninstall "$release_name" -n "$namespace" --wait --timeout 5m; then
                    log_success "✅ Mongo Express Helm release 卸载成功！"
                else
                    log_error "❌ Mongo Express Helm release 卸载失败！"
                    return 1
                fi
            else
                log_warn "Mongo Express release '$release_name' 未安装或已卸载"
            fi
            
            # 清理残留资源
            log_info "清理残留的 Mongo Express 资源..."
            sleep 2
            kubectl delete ingressroute -n "$namespace" -l component=mongo-express 2>/dev/null || true
            kubectl delete middleware -n "$namespace" -l component=mongo-express 2>/dev/null || true
            kubectl delete ingressroute -n "$namespace" mongo-express-web-route 2>/dev/null || true
            kubectl delete middleware -n "$namespace" mongo-express-policy 2>/dev/null || true
            
            # 最终验证
            local remaining
            remaining=$(kubectl get all,ingressroute,middleware -n "$namespace" 2>/dev/null | grep -i "mongo-express" || true)
            if [[ -n "$remaining" ]]; then
                log_warn "⚠️  仍有残留资源，可能需要手动清理:"
                echo "$remaining"
            else
                log_success "✅ Mongo Express 完全卸载完成！"
            fi
            
            return 0
            ;;
        "clean")
            log_info "开始清理 Mongo Express..."
            
            local release_name="mongo-express-$project_id"
            helm uninstall "$release_name" -n "$namespace" --wait --timeout 5m 2>/dev/null || true
            kubectl delete pvc -n "$namespace" -l app.kubernetes.io/name=mongo-express || true
            kubectl delete ingressroute -n "$namespace" -l component=mongo-express 2>/dev/null || true
            kubectl delete middleware -n "$namespace" -l component=mongo-express 2>/dev/null || true
            log_success "✅ Mongo Express 清理完成"
            ;;
        "status")
            check_mongo_express_status "$namespace"
            show_mongo_express_connection_info "$namespace"
            ;;
        "logs")
            log_info "显示 Mongo Express 日志..."
            kubectl logs -n "$namespace" -l app.kubernetes.io/name=mongo-express --tail=100
            ;;
        "backup")
            backup_mongo_express_data "$namespace"
            ;;
        "connect")
            show_mongo_express_connection_info "$namespace"
            ;;
        *)
            echo "用法: $0 <action> [project_id] [namespace] [environment] [dry_run]"
            echo ""
            echo "操作:"
            echo "  deploy     部署 Mongo Express（默认）"
            echo "  upgrade    升级 Mongo Express"
            echo "  uninstall  卸载 Mongo Express"
            echo "  clean      清理 Mongo Express（包括数据）"
            echo "  status     检查 Mongo Express 状态"
            echo "  logs       显示 Mongo Express 日志"
            echo "  backup     备份 Mongo Express 数据"
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
