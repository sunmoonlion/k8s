#!/bin/bash

# Celery Worker 多后端部署脚本
# 用法: ./deploy-multi-celeryworker.sh <action> [project_id] [namespace] [environment]
# 注意: 镜像构建请使用 build/build-image.sh 脚本

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 保存 Celery Worker 脚本的目录路径（统一部署模板会重新定义 SCRIPT_DIR）
CELERY_WORKER_SCRIPT_DIR="$SCRIPT_DIR"

# 导入统一部署模板
# 注意：从 celeryworker-bff 到 k8s 需要 5 级（celeryworker-bff -> celeryworker-app -> shared-apps -> app-platform -> sunmoonai -> k8s）
source "$PROJECT_ROOT/../../../../../utils/unified-deployment-template.sh"

# 恢复 Celery Worker 脚本的目录路径
SCRIPT_DIR="$CELERY_WORKER_SCRIPT_DIR"

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
CELERY_WORKER_CONFIG_FILE="$SCRIPT_DIR/deploy-multi-celeryworker.conf"
if [[ -f "$CELERY_WORKER_CONFIG_FILE" ]]; then
    source "$CELERY_WORKER_CONFIG_FILE"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$PROJECT_ROOT/../../../../../utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/../../../../../utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
    
    log_info "已加载 Celery Worker 多后端配置文件: $CELERY_WORKER_CONFIG_FILE"
else
    log_warn "未找到 Celery Worker 多后端配置文件: $CELERY_WORKER_CONFIG_FILE，使用默认配置"
fi

# 默认配置（对齐 PostgreSQL 部署脚本，使用硬编码默认值）
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="app-platform-dev"
DEFAULT_ENVIRONMENT="development"

# 镜像配置（从部署配置文件读取，用于部署时指定镜像）
# 镜像名称和标签应该与 build/build.conf 中的配置保持一致
CELERY_WORKER_IMAGE="${CELERY_WORKER_IMAGE:-celeryworker}"
CELERY_WORKER_TAG="${CELERY_WORKER_TAG:-1.0.0}"

# 资源文件路径（对齐项目结构，统一使用 multi-celeryworker.yaml）
RESOURCES_DIR="../resources"
CELERYWORKER_YAML="${RESOURCES_DIR}/multi-celeryworker.yaml"

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
    if [ ! -f "$CELERYWORKER_YAML" ]; then
        log_error "配置文件不存在: $CELERYWORKER_YAML"
        log_info "请确保资源文件存在: $RESOURCES_DIR/multi-celeryworker.yaml"
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

# 部署 Celery Worker
deploy_celeryworker() {
    log_info "开始部署 Celery Worker（多后端）..."
    log_info "环境: $ENVIRONMENT, 命名空间: $NAMESPACE"
    
    # 检查环境配置
    check_env_config
    
    # deploy 命令：使用 Harbor 镜像部署
    # 注意：部署前请确保镜像已构建并推送到 Harbor
    # 构建镜像请使用: cd ../build && ./build-image.sh build-push
    CELERY_WORKER_FULL_IMAGE_NAME="${CELERY_WORKER_IMAGE_REGISTRY}/${CELERY_WORKER_IMAGE_PROJECT}/${CELERY_WORKER_IMAGE}:${CELERY_WORKER_TAG}"
    IMAGE_PULL_POLICY="IfNotPresent"  # 如果本地有则使用，否则从仓库拉取
    log_info "使用 Harbor 镜像部署: $CELERY_WORKER_FULL_IMAGE_NAME"
    log_info "Kubernetes 将从镜像仓库拉取镜像"
    log_warn "⚠️  请确保该镜像已存在于 Harbor 仓库中"
    
    # 准备环境变量
    export NAMESPACE="$NAMESPACE"
    export ENV="$ENV"  # 保留 ENV 用于兼容性（YAML 中可能使用）
    export ENVIRONMENT="$ENVIRONMENT"
    export CELERY_WORKER_IMAGE_REGISTRY="${CELERY_WORKER_IMAGE_REGISTRY:-harbor.sunmoonai.com:30443}"
    export CELERY_WORKER_IMAGE_PROJECT="${CELERY_WORKER_IMAGE_PROJECT:-k8s-images}"
    export CELERY_WORKER_IMAGE="${CELERY_WORKER_IMAGE}"
    export CELERY_WORKER_TAG="${CELERY_WORKER_TAG}"
    export CELERY_WORKER_FULL_IMAGE_NAME="$CELERY_WORKER_FULL_IMAGE_NAME"
    export IMAGE_PULL_POLICY="${IMAGE_PULL_POLICY:-IfNotPresent}"
    
    # 多后端配置（统一格式，支持动态配置）
    # 后端1: llmops-app-bff
    export LLMOPS_IMAGE_REGISTRY="${BACKEND_llmops_IMAGE_REGISTRY:-${DEFAULT_BACKEND_IMAGE_REGISTRY:-harbor.sunmoonai.com:30443}}"
    export LLMOPS_IMAGE_PROJECT="${BACKEND_llmops_IMAGE_PROJECT:-${DEFAULT_BACKEND_IMAGE_PROJECT:-k8s-images}}"
    export LLMOPS_IMAGE="${BACKEND_llmops_IMAGE:-llmops-app-bff}"
    export LLMOPS_TAG="${BACKEND_llmops_TAG:-1.0.0}"
    export LLMOPS_CODE_EXTRACT_SOURCE_DIR="${BACKEND_llmops_CODE_EXTRACT_SOURCE_DIR:-${DEFAULT_CODE_EXTRACT_SOURCE_DIR:-/app/app}}"
    export LLMOPS_CODE_EXTRACT_DIRS="${BACKEND_llmops_CODE_EXTRACT_DIRS:-${DEFAULT_CODE_EXTRACT_DIRS:-worker core services db models schemas crud}}"
    export LLMOPS_CODE_EXTRACT_FILES="${BACKEND_llmops_CODE_EXTRACT_FILES:-${DEFAULT_CODE_EXTRACT_FILES:-__init__.py celeryworker_pre_start.py}}"
    
    # 后端2: incubator-service
    export INCUBATOR_IMAGE_REGISTRY="${BACKEND_incubator_IMAGE_REGISTRY:-${DEFAULT_BACKEND_IMAGE_REGISTRY:-harbor.sunmoonai.com:30443}}"
    export INCUBATOR_IMAGE_PROJECT="${BACKEND_incubator_IMAGE_PROJECT:-${DEFAULT_BACKEND_IMAGE_PROJECT:-k8s-images}}"
    export INCUBATOR_IMAGE="${BACKEND_incubator_IMAGE:-incubator-service}"
    export INCUBATOR_TAG="${BACKEND_incubator_TAG:-1.0.0}"
    export INCUBATOR_CODE_EXTRACT_SOURCE_DIR="${BACKEND_incubator_CODE_EXTRACT_SOURCE_DIR:-${DEFAULT_CODE_EXTRACT_SOURCE_DIR:-/app/app}}"
    export INCUBATOR_CODE_EXTRACT_DIRS="${BACKEND_incubator_CODE_EXTRACT_DIRS:-worker core services db models}"
    export INCUBATOR_CODE_EXTRACT_FILES="${BACKEND_incubator_CODE_EXTRACT_FILES:-__init__.py}"
    
    # 从配置文件读取环境变量
    # RabbitMQ 和 Redis 配置（方案A：所有后端共享）
    # RabbitMQ: 单个实例 + 多个队列（llmops-queue, incubator-queue）
    # Redis: 单个实例 + 结果键前缀（自动区分 llmops 和 incubator）
    export CELERY_BROKER_URL="${CELERY_BROKER_URL:-amqp://admin:admin123@rabbitmq-sunmoonai.messaging-platform-dev:5672//}"
    export CELERY_RESULT_BACKEND="${CELERY_RESULT_BACKEND:-redis://redis-service.data-platform:6379/0}"
    export CELERY_QUEUES="${CELERY_QUEUES:-llmops-queue,incubator-queue}"
    export CELERY_CONCURRENCY="${CELERY_CONCURRENCY:-2}"
    export REDIS_URL="${REDIS_URL:-redis://redis-service.data-platform:6379}"
    
    # 部署 Celery Worker（动态替换镜像名称和命名空间）
    log_info "部署 Celery Worker（多后端）(环境: $ENVIRONMENT, 镜像: $CELERY_WORKER_FULL_IMAGE_NAME, 拉取策略: ${IMAGE_PULL_POLICY:-IfNotPresent}, 命名空间: $NAMESPACE)..."
    # 创建临时文件并替换环境变量（包括镜像名称、拉取策略和命名空间）
    TEMP_YAML=$(mktemp)
    envsubst < "$CELERYWORKER_YAML" > "$TEMP_YAML"
    kubectl apply -f "$TEMP_YAML" -n "$NAMESPACE"
    rm -f "$TEMP_YAML"
    
    if [ $? -eq 0 ]; then
        log_success "Celery Worker（多后端）部署完成！"
        log_info "监听队列: ${CELERY_QUEUES}"
        echo ""
        log_info "检查部署状态:"
        echo "  kubectl get pods -n $NAMESPACE -l app=celeryworker-multi"
        echo "  kubectl get svc -n $NAMESPACE -l app=celeryworker-multi"
        echo ""
        log_info "查看 Pod 日志:"
        echo "  kubectl logs -n $NAMESPACE -l app=celeryworker-multi -f"
    else
        log_error "Celery Worker（多后端）部署失败"
        exit 1
    fi
}

# 卸载 Celery Worker
undeploy_celeryworker() {
    log_info "开始卸载 Celery Worker（多后端）..."
    log_info "环境: $ENVIRONMENT, 命名空间: $NAMESPACE"
    
    check_env_config
    
    # 卸载时使用原始 YAML（删除时不需要替换镜像，但需要替换命名空间）
    TEMP_YAML=$(mktemp)
    export NAMESPACE="$NAMESPACE"
    export ENV="$ENV"  # 保留 ENV 用于兼容性（YAML 中可能使用）
    export ENVIRONMENT="$ENVIRONMENT"
    envsubst < "$CELERYWORKER_YAML" > "$TEMP_YAML"
    kubectl delete -f "$TEMP_YAML" -n "$NAMESPACE" --ignore-not-found=true
    rm -f "$TEMP_YAML"
    
    log_success "Celery Worker（多后端）卸载完成！"
}

# 显示状态
show_status() {
    log_info "Celery Worker（多后端）状态:"
    echo ""
    echo "📦 Pods:"
    kubectl get pods -n "$NAMESPACE" -l app=celeryworker-multi 2>/dev/null || echo "  无 Pod 运行"
    echo ""
    echo "🌐 Services:"
    kubectl get svc -n "$NAMESPACE" -l app=celeryworker-multi 2>/dev/null || echo "  无 Service"
    echo ""
    echo "📋 Deployments:"
    kubectl get deployment -n "$NAMESPACE" -l app=celeryworker-multi 2>/dev/null || echo "  无 Deployment"
    echo ""
    log_info "Init Container 日志（最近一个 Pod）:"
    POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=celeryworker-multi -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$POD_NAME" ]; then
        log_info "Pod: $POD_NAME"
        echo ""
        log_info "Init Container: extract-llmops-code"
        kubectl logs -n "$NAMESPACE" "$POD_NAME" -c extract-llmops-code --tail=20 2>/dev/null || log_warn "无法获取日志"
        echo ""
        log_info "Init Container: extract-incubator-code"
        kubectl logs -n "$NAMESPACE" "$POD_NAME" -c extract-incubator-code --tail=20 2>/dev/null || log_warn "无法获取日志"
        echo ""
        log_info "Init Container: merge-code"
        kubectl logs -n "$NAMESPACE" "$POD_NAME" -c merge-code --tail=20 2>/dev/null || log_warn "无法获取日志"
    else
        log_warn "未找到运行中的 Pod"
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
    
    log_info "Celery Worker（多后端）部署脚本启动"
    log_info "操作: $ACTION, 项目: $PROJECT_ID, 命名空间: $NAMESPACE, 环境: $ENVIRONMENT"
    
    check_kubectl
    
    case "$ACTION" in
        "deploy")
            log_info "开始部署 Celery Worker（多后端）..."
            
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
            deploy_celeryworker
            show_status
            ;;
        "undeploy")
            if ! check_namespace "$namespace"; then
                log_error "❌ 命名空间检查失败"
                exit 1
            fi
            undeploy_celeryworker
            ;;
        "status")
            show_status
            ;;
        *)
            log_error "无效的操作: $ACTION"
            echo "用法: $0 <action> [project_id] [namespace] [environment]"
            echo ""
            echo "操作:"
            echo "  deploy     部署 Celery Worker（多后端）"
            echo "  undeploy   卸载 Celery Worker（多后端）"
            echo "  status     查看 Celery Worker（多后端）状态"
            echo ""
            echo "参数说明:"
            echo "  project_id   项目标识符（默认: $DEFAULT_PROJECT_ID）"
            echo "  namespace    命名空间（默认: $DEFAULT_NAMESPACE）"
            echo "  environment  环境（默认: $DEFAULT_ENVIRONMENT）"
            echo ""
            echo "操作说明:"
            echo "  deploy       - 部署到 Kubernetes（从 Harbor 拉取镜像）"
            echo "                注意: 部署前请确保镜像已构建并推送到 Harbor"
            echo "                构建镜像: cd ../build && ./build-image.sh build-push"
            echo "  undeploy     - 卸载 Celery Worker（多后端）"
            echo "  status       - 查看 Celery Worker（多后端）状态"
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
            echo "  cd ../build"
            echo "  ./build-image.sh build-push"
            echo ""
            echo "  # 2. 部署服务"
            echo "  cd ../deploy-celeryworker-bff"
            echo "  ./deploy-multi-celeryworker.sh deploy sunmoonai app-platform-dev development"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
