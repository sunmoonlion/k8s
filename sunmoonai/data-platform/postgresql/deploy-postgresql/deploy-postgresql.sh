#!/bin/bash

# PostgreSQL 递归部署脚本
# 基于递归架构设计原则的两级部署逻辑

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 保存 PostgreSQL 脚本的目录路径（统一部署模板会重新定义 SCRIPT_DIR）
POSTGRESQL_SCRIPT_DIR="$SCRIPT_DIR"

# 导入统一部署模板
source "$PROJECT_ROOT/../../../utils/unified-deployment-template.sh"

# 恢复 PostgreSQL 脚本的目录路径
SCRIPT_DIR="$POSTGRESQL_SCRIPT_DIR"


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

POSTGRESQL_CONFIG_FILE="$SCRIPT_DIR/deploy-postgresql.conf"
if [[ -f "$POSTGRESQL_CONFIG_FILE" ]]; then
    source "$POSTGRESQL_CONFIG_FILE"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
    
    log_info "已加载 PostgreSQL 配置文件: $POSTGRESQL_CONFIG_FILE"
else
    log_error "缺少 PostgreSQL 配置文件: $POSTGRESQL_CONFIG_FILE"
    exit 1
fi

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="data-platform-dev"
DEFAULT_ENVIRONMENT="development"

# PostgreSQL 资源目录（固定路径）
POSTGRESQL_CHART_DIR="$SCRIPT_DIR/../resources/postgresql"
POSTGRESQL_CUSTOM_VALUES_DIR="$SCRIPT_DIR/../resources/custom-values"

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

# 检测部署模式
detect_deployment_mode() {
    local mode="${DEPLOYMENT_MODE:-online}"
    case "$mode" in
        "online")
            log_info "🌐 使用在线部署模式"
            ENABLE_OFFLINE_IMAGE_CHECK="false"
            POSTGRESQL_FORCE_OFFLINE="false"
            ;;
        "offline")
            log_info "📦 使用离线部署模式"
            ENABLE_OFFLINE_IMAGE_CHECK="true"
            POSTGRESQL_FORCE_OFFLINE="true"
            ;;
        *)
            log_warn "未知部署模式: $mode，默认使用在线模式"
            ENABLE_OFFLINE_IMAGE_CHECK="false"
            POSTGRESQL_FORCE_OFFLINE="false"
            ;;
    esac
}

# 定义 PostgreSQL 所需镜像
define_required_images() {
    local environment="$1"
    
    # 在线模式：返回基础镜像名（不带版本）
    if [[ "$ENABLE_OFFLINE_IMAGE_CHECK" == "false" ]]; then
        case "$environment" in
            "development"|"dev")
                echo "bitnami/postgresql|true"
                if [[ "${POSTGRESQL_MONITORING_ENABLED:-false}" == "true" ]]; then
                    echo "bitnami/postgresql-exporter|true"
                fi
                ;;
            "production"|"prod")
                echo "bitnami/postgresql|true"
                echo "bitnami/postgresql-exporter|true"
                if [[ "${POSTGRESQL_BACKUP_ENABLED:-false}" == "true" ]]; then
                    echo "bitnami/postgresql|true"
                fi
                ;;
            *)
                echo "bitnami/postgresql|true"
                ;;
        esac
    else
        # 离线模式：返回具体版本（原有逻辑）
        case "$environment" in
            "development"|"dev")
                echo "bitnami/postgresql:$POSTGRESQL_IMAGE_VERSION|true"
                if [[ "${POSTGRESQL_MONITORING_ENABLED:-false}" == "true" ]]; then
                    echo "bitnami/postgresql-exporter:$POSTGRESQL_METRICS_IMAGE_VERSION|true"
                fi
                ;;
            "production"|"prod")
                echo "bitnami/postgresql:$POSTGRESQL_IMAGE_VERSION|true"
                echo "bitnami/postgresql-exporter:$POSTGRESQL_METRICS_IMAGE_VERSION|true"
                if [[ "${POSTGRESQL_BACKUP_ENABLED:-false}" == "true" ]]; then
                    echo "bitnami/postgresql:$POSTGRESQL_IMAGE_VERSION|true"
                fi
                ;;
            *)
                echo "bitnami/postgresql:$POSTGRESQL_IMAGE_VERSION|true"
                ;;
        esac
    fi
}

# 处理 PostgreSQL 特定的 values 文件
process_postgresql_values() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    
    # 确定环境目录
    local env_dir=""
    case "$environment" in
        "production")
            env_dir="values-prod"
            ;;
        "development")
            env_dir="values-dev"
            ;;
        *)
            env_dir="values-dev"  # 默认使用开发环境
            ;;
    esac
    
    # 检查环境特定的 values 文件
    local env_values_file=""
    
    case "$environment" in
        "production")
            env_values_file="$PROJECT_ROOT/resources/custom-values/prod-values.yaml"
            ;;
        "development")
            env_values_file="$PROJECT_ROOT/resources/custom-values/dev-values.yaml"
            ;;
        *)
            env_values_file="$PROJECT_ROOT/resources/custom-values/dev-values.yaml"
            ;;
    esac
    
    if [[ -f "$env_values_file" ]]; then
        log_info "使用环境特定配置: $env_values_file" >&2
        
        # 创建临时 values 文件
        local postgresql_values_file=$(mktemp)
        cp "$env_values_file" "$postgresql_values_file"
        
        # 替换基础变量
        local created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        
        # 基础变量替换
        sed -i "s/{{PROJECT_ID}}/$project_id/g" "$postgresql_values_file"
        sed -i "s/{{NAMESPACE}}/$namespace/g" "$postgresql_values_file"
        sed -i "s/{{ENVIRONMENT}}/$environment/g" "$postgresql_values_file"
        sed -i "s/{{COMPONENT_NAME}}/postgresql/g" "$postgresql_values_file"
        sed -i "s/{{CREATED_AT}}/$created_at/g" "$postgresql_values_file"
        
        # PostgreSQL 特定变量替换
        if [[ -n "${POSTGRESQL_PROJECT_ID:-}" ]]; then
            sed -i "s/{{POSTGRESQL_PROJECT_ID}}/${POSTGRESQL_PROJECT_ID}/g" "$postgresql_values_file"
        fi
        if [[ -n "${POSTGRESQL_NAMESPACE:-}" ]]; then
            sed -i "s/{{POSTGRESQL_NAMESPACE}}/${POSTGRESQL_NAMESPACE}/g" "$postgresql_values_file"
        fi
        if [[ -n "${POSTGRESQL_EXTERNAL_HOST:-}" ]]; then
            sed -i "s/{{POSTGRESQL_EXTERNAL_HOST}}/${POSTGRESQL_EXTERNAL_HOST}/g" "$postgresql_values_file"
        fi
        if [[ -n "${POSTGRESQL_EXTERNAL_PORT:-}" ]]; then
            sed -i "s/{{POSTGRESQL_EXTERNAL_PORT}}/${POSTGRESQL_EXTERNAL_PORT}/g" "$postgresql_values_file"
        fi
        if [[ -n "${POSTGRESQL_TLS_ENABLED:-}" ]]; then
            sed -i "s/{{POSTGRESQL_TLS_ENABLED}}/${POSTGRESQL_TLS_ENABLED}/g" "$postgresql_values_file"
        fi
        if [[ -n "${POSTGRESQL_TLS_AUTO_GENERATED:-}" ]]; then
            sed -i "s/{{POSTGRESQL_TLS_AUTO_GENERATED}}/${POSTGRESQL_TLS_AUTO_GENERATED}/g" "$postgresql_values_file"
        fi
        if [[ -n "${POSTGRESQL_TLS_CERTIFICATES_SECRET:-}" ]]; then
            sed -i "s/{{POSTGRESQL_TLS_CERTIFICATES_SECRET}}/${POSTGRESQL_TLS_CERTIFICATES_SECRET}/g" "$postgresql_values_file"
        fi
        if [[ -n "${POSTGRESQL_TLS_CERT_FILENAME:-}" ]]; then
            sed -i "s/{{POSTGRESQL_TLS_CERT_FILENAME}}/${POSTGRESQL_TLS_CERT_FILENAME}/g" "$postgresql_values_file"
        fi
        if [[ -n "${POSTGRESQL_TLS_CERT_KEY_FILENAME:-}" ]]; then
            sed -i "s/{{POSTGRESQL_TLS_CERT_KEY_FILENAME}}/${POSTGRESQL_TLS_CERT_KEY_FILENAME}/g" "$postgresql_values_file"
        fi
        if [[ -n "${POSTGRESQL_TLS_CERT_CA_FILENAME:-}" ]]; then
            sed -i "s/{{POSTGRESQL_TLS_CERT_CA_FILENAME}}/${POSTGRESQL_TLS_CERT_CA_FILENAME}/g" "$postgresql_values_file"
        fi
        if [[ -n "${POSTGRESQL_AUTH_SECRET_NAME:-}" ]]; then
            sed -i "s/{{POSTGRESQL_AUTH_SECRET_NAME}}/${POSTGRESQL_AUTH_SECRET_NAME}/g" "$postgresql_values_file"
        fi
        if [[ -n "${POSTGRESQL_AUTH_SECRET_PASSWORD_KEY:-}" ]]; then
            sed -i "s/{{POSTGRESQL_AUTH_SECRET_PASSWORD_KEY}}/${POSTGRESQL_AUTH_SECRET_PASSWORD_KEY}/g" "$postgresql_values_file"
        fi
        if [[ -n "${POSTGRESQL_AUTH_SECRET_ADMIN_PASSWORD_KEY:-}" ]]; then
            sed -i "s/{{POSTGRESQL_AUTH_SECRET_ADMIN_PASSWORD_KEY}}/${POSTGRESQL_AUTH_SECRET_ADMIN_PASSWORD_KEY}/g" "$postgresql_values_file"
        fi
        if [[ -n "${POSTGRESQL_AUTH_SECRET_DEV_PASSWORD_KEY:-}" ]]; then
            sed -i "s/{{POSTGRESQL_AUTH_SECRET_DEV_PASSWORD_KEY}}/${POSTGRESQL_AUTH_SECRET_DEV_PASSWORD_KEY}/g" "$postgresql_values_file"
        fi
        if [[ -n "${POSTGRESQL_IMAGE_REGISTRY:-}" ]]; then
            sed -i "s/{{POSTGRESQL_IMAGE_REGISTRY}}/${POSTGRESQL_IMAGE_REGISTRY}/g" "$postgresql_values_file"
        fi
        if [[ -n "${POSTGRESQL_IMAGE_PROJECT:-}" ]]; then
            sed -i "s/{{POSTGRESQL_IMAGE_PROJECT}}/${POSTGRESQL_IMAGE_PROJECT}/g" "$postgresql_values_file"
        fi
        if [[ -n "${POSTGRESQL_IMAGE_PULL_SECRET_NAME:-}" ]]; then
            sed -i "s/{{POSTGRESQL_IMAGE_PULL_SECRET_NAME}}/${POSTGRESQL_IMAGE_PULL_SECRET_NAME}/g" "$postgresql_values_file"
        fi
        
        # 使用统一模板的变量替换函数（若函数存在则调用）
        if type replace_template_variables >/dev/null 2>&1; then
          replace_template_variables "$postgresql_values_file" "$project_id" "$namespace" "postgresql" "$environment"
        fi
        
        # 只输出临时文件路径到stdout，不包含任何日志信息
        echo "$postgresql_values_file"
        return 0
    else
        log_error "缺少环境特定 values 文件: $env_values_file"
        return 1
    fi
}

# 执行 PostgreSQL 部署
execute_postgresql_deployment() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始执行 PostgreSQL 部署..."
    log_info "项目: $project_id"
    log_info "命名空间: $namespace"
    log_info "环境: $environment"
    log_info "干运行: $dry_run"
    
    # 检查 Chart 目录
    if [[ ! -d "$POSTGRESQL_CHART_DIR" ]]; then
        log_error "PostgreSQL Chart 目录不存在: $POSTGRESQL_CHART_DIR"
        return 1
    fi
    
    # 检查自定义配置目录
    if [[ ! -d "$POSTGRESQL_CUSTOM_VALUES_DIR" ]]; then
        log_error "PostgreSQL 自定义配置目录不存在: $POSTGRESQL_CUSTOM_VALUES_DIR"
        return 1
    fi
    
    # 检查命名空间是否存在
    if ! check_namespace "$namespace"; then
        log_error "❌ 命名空间检查失败"
        return 1
    fi
    
    # 处理 PostgreSQL 特定的 values 文件
    local postgresql_values_file=$(process_postgresql_values "$project_id" "$namespace" "$environment" 2>/dev/null)
    local process_exit_code=$?
    
    if [[ $process_exit_code -ne 0 ]] || [[ -z "$postgresql_values_file" ]]; then
        log_error "❌ PostgreSQL values 文件处理失败"
        return 1
    fi
    
    # 使用 PostgreSQL 特定的 values 文件
    log_info "使用 PostgreSQL 特定配置: $postgresql_values_file"
    
    # 构建 Helm 命令
    local helm_cmd="helm upgrade --install postgresql-$project_id $POSTGRESQL_CHART_DIR"
    helm_cmd="$helm_cmd --namespace $namespace"
    helm_cmd="$helm_cmd --values $POSTGRESQL_CHART_DIR/values.yaml"
    helm_cmd="$helm_cmd --values $postgresql_values_file"
    helm_cmd="$helm_cmd --set global.projectId=$project_id"
    helm_cmd="$helm_cmd --set global.namespace=$namespace"
    helm_cmd="$helm_cmd --set global.security.allowInsecureImages=true"
    
    # 在线模式：添加镜像仓库配置
    if [[ "$ENABLE_OFFLINE_IMAGE_CHECK" == "false" ]]; then
        if [[ -n "${POSTGRESQL_IMAGE_REGISTRY:-}" ]]; then
            helm_cmd="$helm_cmd --set global.imageRegistry=$POSTGRESQL_IMAGE_REGISTRY"
            log_info "使用镜像仓库: $POSTGRESQL_IMAGE_REGISTRY"
        fi
        if [[ -n "${POSTGRESQL_IMAGE_PROJECT:-}" ]]; then
            helm_cmd="$helm_cmd --set global.imageProject=$POSTGRESQL_IMAGE_PROJECT"
            log_info "使用镜像项目: $POSTGRESQL_IMAGE_PROJECT"
        fi
    fi

    if [[ "$dry_run" == "true" ]]; then
        helm_cmd="$helm_cmd --dry-run"
        log_info "执行干运行部署..."
    else
        log_info "执行实际部署..."
    fi
    
    # 执行 Helm 命令
    log_info "执行命令: $helm_cmd"
    
    # 检查KUBECONFIG环境变量
    if [[ -z "${KUBECONFIG:-}" ]]; then
        log_error "KUBECONFIG 环境变量未设置"
        return 1
    fi
    
    # 检查kubectl连接
    if ! kubectl get nodes >/dev/null 2>&1; then
        log_error "kubectl 连接失败，请检查Kubernetes连接"
        return 1
    fi
    
    local helm_result
    local helm_exit_code=0
    
    # 执行Helm命令并捕获输出
    if helm_result=$(eval "$helm_cmd" 2>&1); then
        helm_exit_code=0
        log_info "Helm 命令执行成功"
        log_info "输出: $helm_result"
    else
        helm_exit_code=$?
        log_error "Helm 命令执行失败，退出码: $helm_exit_code"
        log_error "错误信息: $helm_result"
    fi
    
    if [[ $helm_exit_code -eq 0 ]]; then
        if [[ "$dry_run" == "true" ]]; then
            log_success "✅ PostgreSQL 干运行部署成功！"
        else
            log_success "✅ PostgreSQL 部署成功！"
        fi
        return 0
    else
        log_error "❌ PostgreSQL 部署失败！"
        return 1
    fi
}

# 递归部署子组件
deploy_sub_components() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始部署 PostgreSQL 子组件..."
    
    # 定义子组件部署顺序（按优先级排序）
    # Secrets 现在由组件自己的 secrets/deploy-secrets-all 管理
    local sub_components=(
        "postgresql_secrets:${secrets_enabled:-true}:${secrets_priority:-2000}:PostgreSQL Secrets:$SCRIPT_DIR/secrets/deploy-secrets-all/deploy-secrets-all.sh"
        "postgresql_middleware:${middleware_enabled:-false}:${middleware_priority:-1000}:PostgreSQL 中间件:$SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh"
        "postgresql_ingress:${ingress_enabled:-false}:${ingress_priority:-100}:PostgreSQL TCP 路由:$SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh"
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
                if [[ "$name" == "postgresql_ingress" ]]; then
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
    
    log_success "✅ PostgreSQL 子组件部署完成"
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
    
    local action="${1:-}"
    local project_id="${2:-$DEFAULT_PROJECT_ID}"
    local namespace="${3:-$DEFAULT_NAMESPACE}"
    local environment="${4:-$DEFAULT_ENVIRONMENT}"
    local dry_run="${5:-false}"
    
    case "$action" in
        "deploy")
            log_info "开始部署 PostgreSQL..."
            
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
            
            # 检测部署模式
            detect_deployment_mode
            
            # ============================================================
            # 阶段1：部署子级组件（按优先级，先部署依赖项）
            # ============================================================
            log_info "🚀 阶段1：部署 PostgreSQL 子级组件..."
            if ! deploy_sub_components "$project_id" "$namespace" "$environment" "$dry_run"; then
                log_error "❌ PostgreSQL 子级组件部署失败！"
                return 1
            fi
            log_success "✅ PostgreSQL 子级组件部署完成"
            
            # ============================================================
            # 阶段2：部署本级核心服务（Helm Chart 部署）
            # ============================================================
            log_info "🚀 阶段2：部署 PostgreSQL 核心服务..."
            
            # 执行主部署（Helm Chart）
            if ! execute_postgresql_deployment "$project_id" "$namespace" "$environment" "$dry_run"; then
                log_error "❌ PostgreSQL 核心服务部署失败！"
                return 1
            fi
            log_success "✅ PostgreSQL 核心服务部署成功！"
            
            # ============================================================
            # 阶段3：部署本级专属组件（如果有的话）
            # ============================================================
            # 目前 PostgreSQL 没有专属组件，预留接口
            log_info "🚀 阶段3：部署 PostgreSQL 专属组件..."
            log_info "（当前无专属组件需要部署）"
            
            # ============================================================
            # 部署完成
            # ============================================================
            log_success "🎉 PostgreSQL 完整部署成功！"
            log_info "PostgreSQL 部署信息:"
            log_info "项目: $project_id"
            log_info "命名空间: $namespace"
            log_info "环境: $environment"
            log_info "服务名称: postgresql-$project_id"
            if [[ -n "${POSTGRESQL_EXTERNAL_HOST:-}" && -n "${POSTGRESQL_EXTERNAL_PORT:-}" ]]; then
                log_info "访问地址: http://$POSTGRESQL_EXTERNAL_HOST:$POSTGRESQL_EXTERNAL_PORT"
            fi
            
            # 安装后清理控制平面 tar 包
            if [[ -x "$PROJECT_ROOT/../../cicd-platform/harbor/utils/harbor-image-management/harbor-image.sh" ]]; then
                : # 通用工具已在推送过程中清理，无需额外清理
            fi
            return 0
            ;;
        "upgrade")
            log_info "开始升级 PostgreSQL..."
            # 调用部署函数进行升级
            main "deploy" "$project_id" "$namespace" "$environment" "$dry_run"
            ;;
        "uninstall")
            log_info "开始卸载 PostgreSQL..."
            
            # 设置 Kubernetes 环境
            if ! setup_kubectl_environment; then
                log_error "无法建立 Kubernetes 连接"
                return 1
            fi
            
            # 卸载子组件
            log_info "卸载 PostgreSQL 子组件..."
            
            # 定义子组件卸载顺序（按优先级排序）
            local sub_components=(
                "postgresql_middleware:${middleware_enabled:-false}:${middleware_priority:-1000}:PostgreSQL 中间件:$SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh"
                "postgresql_ingress:${ingress_enabled:-false}:${ingress_priority:-100}:PostgreSQL TCP 路由:$SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh"
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
                        if [[ "$name" == "postgresql_ingress" ]]; then
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
            
            # 确保连接仍然可用
            if ! kubectl get nodes >/dev/null 2>&1; then
                log_info "连接已断开，重新建立连接..."
                if ! setup_kubectl_environment; then
                    log_error "无法重新建立 Kubernetes 连接"
                    return 1
                fi
            fi
            
            # 卸载主部署
            if helm uninstall "postgresql-$project_id" -n "$namespace" --wait; then
                log_success "✅ PostgreSQL 卸载成功！"
                return 0
            else
                log_error "❌ PostgreSQL 卸载失败！"
                return 1
            fi
            ;;
        "status")
            log_info "检查 PostgreSQL 状态..."
            
            # 设置 Kubernetes 环境
            if ! setup_kubectl_environment; then
                log_error "无法建立 Kubernetes 连接"
                return 1
            fi
            
            # 检查主部署状态
            if helm list -n "$namespace" | grep -q "postgresql-$project_id"; then
                log_success "✅ PostgreSQL 主部署存在"
            else
                log_error "❌ PostgreSQL 主部署不存在"
                return 1
            fi
            
            # 检查子组件状态
            log_info "检查子组件状态..."
            kubectl get pods -n "$namespace" -l app.kubernetes.io/name=postgresql
            kubectl get svc -n "$namespace" -l app.kubernetes.io/name=postgresql
            kubectl get ingress -n "$namespace" -l app=data-platform-ingress
            kubectl get middleware -n "$namespace" -l app=data-platform-ingress
            kubectl get secret -n "$namespace" -l app=data-platform-ingress
            
            return 0
            ;;
        *)
            echo "PostgreSQL 递归部署脚本"
            echo ""
            echo "用法: $0 <action> [project_id] [namespace] [environment] [dry_run]"
            echo ""
            echo "操作:"
            echo "  deploy     部署 PostgreSQL"
            echo "  upgrade    升级 PostgreSQL"
            echo "  uninstall  卸载 PostgreSQL"
            echo "  status     检查 PostgreSQL 状态"
            echo ""
            echo "参数说明:"
            echo "  project_id   项目标识符（默认: $DEFAULT_PROJECT_ID）"
            echo "  namespace    命名空间（默认: $DEFAULT_NAMESPACE）"
            echo "  environment  环境（默认: $DEFAULT_ENVIRONMENT）"
            echo "  dry_run      干运行模式（默认: false）"
            echo ""
            echo "示例:"
            echo "  $0 deploy sunmoonai data-platform-dev development"
            echo "  $0 upgrade sunmoonai data-platform-dev production"
            echo "  $0 uninstall sunmoonai data-platform-dev"
            echo "  $0 status sunmoonai data-platform-dev"
            echo ""
            echo "环境:"
            echo "  development  开发环境（最小配置）"
            echo "  production   生产环境（高可用配置）"
            echo ""
            echo "注意:"
            echo "  - 部署时会自动部署子组件（中间件、路由）"
            echo "  - 卸载时会自动卸载所有子组件"
            echo "  - 支持离线部署模式，避免循环依赖"
            exit 1
            ;;
    esac
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # 执行主函数
    main "$@"
fi