#!/bin/bash

# ArgoCD 部署脚本
# 使用统一部署模板进行 ArgoCD 部署

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 导入统一部署模板
source "$PROJECT_ROOT/../../../utils/unified-deployment-template.sh"

# 加载 ArgoCD 专用配置文件
ARGOCD_CONFIG_FILE="$PROJECT_ROOT/deploy/deploy-argocd.conf"
if [[ -f "$ARGOCD_CONFIG_FILE" ]]; then
    source "$ARGOCD_CONFIG_FILE"
    log_info "已加载 ArgoCD 配置文件: $ARGOCD_CONFIG_FILE"
    
    # 导出所有 ArgoCD 配置变量为环境变量，供统一模板使用
    export ARGOCD_PROJECT_ID ARGOCD_PROJECT_NAME ARGOCD_NAMESPACE
    export ARGOCD_USERNAME ARGOCD_PASSWORD ARGOCD_CHART_VERSION ARGOCD_APP_VERSION
    export ARGOCD_IMAGE_VERSION ARGOCD_DEX_IMAGE_VERSION ARGOCD_OS_SHELL_IMAGE_VERSION ARGOCD_REDIS_IMAGE_VERSION
    
    # 导出环境特定配置
    case "${ENVIRONMENT:-development}" in
        "production")
            # 存储配置
            export STORAGE_CLASS="$PROD_STORAGE_CLASS"
            export STORAGE_SIZE="$PROD_STORAGE_SIZE"
            export STORAGE_ACCESS_MODE="$PROD_STORAGE_ACCESS_MODE"
            
            # 服务配置
            export SERVICE_TYPE="$PROD_SERVICE_TYPE"
            export SERVICE_PORT="$PROD_SERVICE_PORT"
            export SERVICE_HTTPS_PORT="$PROD_SERVICE_HTTPS_PORT"
            
            # 资源配置
            export CPU_LIMIT="$PROD_CPU_LIMIT"
            export MEMORY_LIMIT="$PROD_MEMORY_LIMIT"
            export CPU_REQUEST="$PROD_CPU_REQUEST"
            export MEMORY_REQUEST="$PROD_MEMORY_REQUEST"
            
            # 副本数配置
            export REPLICA_COUNT="$PROD_REPLICA_COUNT"
            export READ_REPLICAS="$PROD_READ_REPLICAS"
            
            # 网络配置
            export NETWORK_POLICY_ENABLED="$PROD_NETWORK_POLICY_ENABLED"
            export INGRESS_ENABLED="$PROD_INGRESS_ENABLED"
            export TLS_ENABLED="$PROD_TLS_ENABLED"
            
            # 监控配置
            export METRICS_ENABLED="$PROD_METRICS_ENABLED"
            export SERVICE_MONITOR_ENABLED="$PROD_SERVICE_MONITOR_ENABLED"
            export SERVICE_MONITOR_INTERVAL="$PROD_SERVICE_MONITOR_INTERVAL"
            
            # 自动扩缩容配置
            export AUTOSCALING_ENABLED="$PROD_AUTOSCALING_ENABLED"
            export HPA_MIN_REPLICAS="$PROD_HPA_MIN_REPLICAS"
            export HPA_MAX_REPLICAS="$PROD_HPA_MAX_REPLICAS"
            export HPA_TARGET_CPU="$PROD_HPA_TARGET_CPU"
            export HPA_TARGET_MEMORY="$PROD_HPA_TARGET_MEMORY"
            
            # 备份配置
            export BACKUP_ENABLED="$PROD_BACKUP_ENABLED"
            export BACKUP_SCHEDULE="$PROD_BACKUP_SCHEDULE"
            export BACKUP_RETENTION="$PROD_BACKUP_RETENTION"
            
            # 健康检查配置
            export LIVENESS_INITIAL_DELAY="$PROD_LIVENESS_INITIAL_DELAY"
            export LIVENESS_PERIOD="$PROD_LIVENESS_PERIOD"
            export LIVENESS_TIMEOUT="$PROD_LIVENESS_TIMEOUT"
            export READINESS_INITIAL_DELAY="$PROD_READINESS_INITIAL_DELAY"
            export READINESS_PERIOD="$PROD_READINESS_PERIOD"
            export READINESS_TIMEOUT="$PROD_READINESS_TIMEOUT"
            
            # 安全配置
            export POD_SECURITY_POLICY_ENABLED="$PROD_POD_SECURITY_POLICY_ENABLED"
            export AUDIT_ENABLED="$PROD_AUDIT_ENABLED"
            export AUDIT_LEVEL="$PROD_AUDIT_LEVEL"
            export AUDIT_LOG_PATH="$PROD_AUDIT_LOG_PATH"
            export AUDIT_MAX_AGE="$PROD_AUDIT_MAX_AGE"
            export AUDIT_MAX_BACKUP="$PROD_AUDIT_MAX_BACKUP"
            export AUDIT_MAX_SIZE="$PROD_AUDIT_MAX_SIZE"
            
            # ArgoCD 特定配置
            export ARGOCD_SERVER_HOST="$PROD_ARGOCD_SERVER_HOST"
            export ARGOCD_SERVER_PORT="$PROD_ARGOCD_SERVER_PORT"
            export ARGOCD_SERVER_NAME="$PROD_ARGOCD_SERVER_NAME"
            export ARGOCD_SERVER_BASEPATH="$PROD_ARGOCD_SERVER_BASEPATH"
            export ARGOCD_SERVER_REWRITEBASEPATH="$PROD_ARGOCD_SERVER_REWRITEBASEPATH"
            export ARGOCD_SERVER_INSECURE="$PROD_ARGOCD_SERVER_INSECURE"
            export ARGOCD_SERVER_EXTRA_ARGS="$PROD_ARGOCD_SERVER_EXTRA_ARGS"
            
            # 性能配置
            export ARGOCD_REPO_SERVER_PARALLELISM_LIMIT="$PROD_ARGOCD_REPO_SERVER_PARALLELISM_LIMIT"
            export ARGOCD_APPLICATION_CONTROLLER_PARALLELISM_LIMIT="$PROD_ARGOCD_APPLICATION_CONTROLLER_PARALLELISM_LIMIT"
            export ARGOCD_LOGGING_VERBOSE="$PROD_ARGOCD_LOGGING_VERBOSE"
            export ARGOCD_LOGGING_LEVEL="$PROD_ARGOCD_LOGGING_LEVEL"
            ;;
        "development")
            # 存储配置
            export STORAGE_CLASS="$DEV_STORAGE_CLASS"
            export STORAGE_SIZE="$DEV_STORAGE_SIZE"
            export STORAGE_ACCESS_MODE="$DEV_STORAGE_ACCESS_MODE"
            
            # 服务配置
            export SERVICE_TYPE="$DEV_SERVICE_TYPE"
            export SERVICE_PORT="$DEV_SERVICE_PORT"
            export SERVICE_HTTPS_PORT="$DEV_SERVICE_HTTPS_PORT"
            
            # 资源配置
            export CPU_LIMIT="$DEV_CPU_LIMIT"
            export MEMORY_LIMIT="$DEV_MEMORY_LIMIT"
            export CPU_REQUEST="$DEV_CPU_REQUEST"
            export MEMORY_REQUEST="$DEV_MEMORY_REQUEST"
            
            # 副本数配置
            export REPLICA_COUNT="$DEV_REPLICA_COUNT"
            export READ_REPLICAS="$DEV_READ_REPLICAS"
            
            # 网络配置
            export NETWORK_POLICY_ENABLED="$DEV_NETWORK_POLICY_ENABLED"
            export INGRESS_ENABLED="$DEV_INGRESS_ENABLED"
            export TLS_ENABLED="$DEV_TLS_ENABLED"
            
            # 监控配置
            export METRICS_ENABLED="$DEV_METRICS_ENABLED"
            export SERVICE_MONITOR_ENABLED="$DEV_SERVICE_MONITOR_ENABLED"
            export SERVICE_MONITOR_INTERVAL="$DEV_SERVICE_MONITOR_INTERVAL"
            
            # 自动扩缩容配置
            export AUTOSCALING_ENABLED="$DEV_AUTOSCALING_ENABLED"
            export HPA_MIN_REPLICAS="$DEV_HPA_MIN_REPLICAS"
            export HPA_MAX_REPLICAS="$DEV_HPA_MAX_REPLICAS"
            export HPA_TARGET_CPU="$DEV_HPA_TARGET_CPU"
            export HPA_TARGET_MEMORY="$DEV_HPA_TARGET_MEMORY"
            
            # 备份配置
            export BACKUP_ENABLED="$DEV_BACKUP_ENABLED"
            export BACKUP_SCHEDULE="$DEV_BACKUP_SCHEDULE"
            export BACKUP_RETENTION="$DEV_BACKUP_RETENTION"
            
            # 健康检查配置
            export LIVENESS_INITIAL_DELAY="$DEV_LIVENESS_INITIAL_DELAY"
            export LIVENESS_PERIOD="$DEV_LIVENESS_PERIOD"
            export LIVENESS_TIMEOUT="$DEV_LIVENESS_TIMEOUT"
            export READINESS_INITIAL_DELAY="$DEV_READINESS_INITIAL_DELAY"
            export READINESS_PERIOD="$DEV_READINESS_PERIOD"
            export READINESS_TIMEOUT="$DEV_READINESS_TIMEOUT"
            
            # 安全配置
            export POD_SECURITY_POLICY_ENABLED="$DEV_POD_SECURITY_POLICY_ENABLED"
            export AUDIT_ENABLED="$DEV_AUDIT_ENABLED"
            export AUDIT_LEVEL="$DEV_AUDIT_LEVEL"
            export AUDIT_LOG_PATH="$DEV_AUDIT_LOG_PATH"
            export AUDIT_MAX_AGE="$DEV_AUDIT_MAX_AGE"
            export AUDIT_MAX_BACKUP="$DEV_AUDIT_MAX_BACKUP"
            export AUDIT_MAX_SIZE="$DEV_AUDIT_MAX_SIZE"
            
            # ArgoCD 特定配置
            export ARGOCD_SERVER_HOST="$DEV_ARGOCD_SERVER_HOST"
            export ARGOCD_SERVER_PORT="$DEV_ARGOCD_SERVER_PORT"
            export ARGOCD_SERVER_NAME="$DEV_ARGOCD_SERVER_NAME"
            export ARGOCD_SERVER_BASEPATH="$DEV_ARGOCD_SERVER_BASEPATH"
            export ARGOCD_SERVER_REWRITEBASEPATH="$DEV_ARGOCD_SERVER_REWRITEBASEPATH"
            export ARGOCD_SERVER_INSECURE="$DEV_ARGOCD_SERVER_INSECURE"
            export ARGOCD_SERVER_EXTRA_ARGS="$DEV_ARGOCD_SERVER_EXTRA_ARGS"
            
            # 性能配置
            export ARGOCD_REPO_SERVER_PARALLELISM_LIMIT="$DEV_ARGOCD_REPO_SERVER_PARALLELISM_LIMIT"
            export ARGOCD_APPLICATION_CONTROLLER_PARALLELISM_LIMIT="$DEV_ARGOCD_APPLICATION_CONTROLLER_PARALLELISM_LIMIT"
            export ARGOCD_LOGGING_VERBOSE="$DEV_ARGOCD_LOGGING_VERBOSE"
            export ARGOCD_LOGGING_LEVEL="$DEV_ARGOCD_LOGGING_LEVEL"
            ;;
        *)
            log_warn "未知环境: ${ENVIRONMENT:-development}，使用开发环境配置"
            # 使用开发环境配置作为默认值
            export STORAGE_CLASS="$DEV_STORAGE_CLASS"
            export STORAGE_SIZE="$DEV_STORAGE_SIZE"
            export SERVICE_TYPE="$DEV_SERVICE_TYPE"
            export REPLICA_COUNT="$DEV_REPLICA_COUNT"
            export CPU_LIMIT="$DEV_CPU_LIMIT"
            export MEMORY_LIMIT="$DEV_MEMORY_LIMIT"
            ;;
    esac
else
    log_warn "ArgoCD 配置文件不存在: $ARGOCD_CONFIG_FILE，使用默认配置"
fi

# 定义所需镜像函数
define_required_images() {
    local environment="$1"
    
    case "$environment" in
        "production")
            echo "bitnami/argo-cd:$ARGOCD_IMAGE_VERSION|true"
            echo "bitnami/dex:$ARGOCD_DEX_IMAGE_VERSION|true"
            echo "bitnami/os-shell:$ARGOCD_OS_SHELL_IMAGE_VERSION|true"
            echo "bitnami/redis:$ARGOCD_REDIS_IMAGE_VERSION|true"
            ;;
        "development")
            echo "bitnami/argo-cd:$ARGOCD_IMAGE_VERSION|true"
            echo "bitnami/dex:$ARGOCD_DEX_IMAGE_VERSION|false"
            echo "bitnami/os-shell:$ARGOCD_OS_SHELL_IMAGE_VERSION|false"
            echo "bitnami/redis:$ARGOCD_REDIS_IMAGE_VERSION|true"
            ;;
        *)
            echo "bitnami/argo-cd:$ARGOCD_IMAGE_VERSION|true"
            echo "bitnami/redis:$ARGOCD_REDIS_IMAGE_VERSION|true"
            ;;
    esac
}

# 部署 ArgoCD
deploy_argocd() {
    local project_id="$1"
    local namespace="$2"
    local environment="${3:-production}"
    local dry_run="${4:-false}"
    
    log_info "开始部署 ArgoCD..."
    log_info "项目: $project_id"
    log_info "命名空间: $namespace"
    log_info "环境: $environment"
    log_info "干运行: $dry_run"
    
    # 构建所需镜像列表
    local required_images=""
    required_images+="bitnami/argo-cd:$ARGOCD_IMAGE_VERSION|true "
    required_images+="bitnami/dex:$ARGOCD_DEX_IMAGE_VERSION|true "
    required_images+="bitnami/os-shell:$ARGOCD_OS_SHELL_IMAGE_VERSION|true "
    required_images+="bitnami/redis:$ARGOCD_REDIS_IMAGE_VERSION|true"
    
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
    
    # 使用统一模板的部署函数（自动包含镜像检查）
    if deploy_component "$project_id" "$namespace" "argocd" "$environment" "$dry_run" "$required_images"; then
        log_success "ArgoCD 部署成功！"
        
        if [[ "$dry_run" != "true" ]]; then
            show_argocd_info "$project_id" "$namespace"
        fi
        
        return 0
    else
        log_error "ArgoCD 部署失败！"
        return 1
    fi
}

# 显示 ArgoCD 部署信息
show_argocd_info() {
    local project_id="$1"
    local namespace="$2"
    
    log_info "ArgoCD 部署信息:"
    log_info "项目: $project_id"
    log_info "命名空间: $namespace"
    log_info "服务名称: argocd-$project_id"
    log_info "HTTP 端口: ${SERVICE_PORT:-80}"
    log_info "HTTPS 端口: ${SERVICE_HTTPS_PORT:-443}"
    log_info "用户名: ${ARGOCD_USERNAME:-admin}"
    log_info "服务器名称: ${ARGOCD_SERVER_NAME:-}"
    
    log_info ""
    log_info "连接信息:"
    log_info "集群内: argocd-$project_id.$namespace.svc.cluster.local:${SERVICE_PORT:-80}"
    log_info "Web 界面: http://argocd-$project_id.$namespace.svc.cluster.local:${SERVICE_PORT:-80}"
    
    log_info ""
    log_info "CLI 工具:"
    log_info "argocd login argocd-$project_id.$namespace.svc.cluster.local:${SERVICE_PORT:-80}"
    log_info "argocd account get-user-info"
    
    log_info ""
    log_info "检查部署状态:"
    log_info "kubectl get pods -n $namespace -l app.kubernetes.io/name=argocd"
    log_info "kubectl get svc -n $namespace -l app.kubernetes.io/name=argocd"
    log_info "kubectl logs -n $namespace -l app.kubernetes.io/name=argocd"
    
    log_info ""
    log_info "健康检查:"
    log_info "curl http://argocd-$project_id.$namespace.svc.cluster.local:${SERVICE_PORT:-80}/healthz"
    
    log_info ""
    log_info "获取初始密码:"
    log_info "kubectl -n $namespace get secret argocd-$project_id -o jsonpath='{.data.admin\.password}' | base64 -d"
}

# 主函数
main() {
    case "${1:-}" in
        deploy)
            deploy_argocd "${2:-}" "${3:-cicd-platform}" "${4:-production}" "${5:-false}"
            ;;
        upgrade)
            deploy_argocd "${2:-}" "${3:-cicd-platform}" "${4:-production}" "${5:-false}"
            ;;
        uninstall)
            log_info "卸载 ArgoCD..."
            # 这里可以添加卸载逻辑
            ;;
        status)
            log_info "检查 ArgoCD 状态..."
            # 这里可以添加状态检查逻辑
            ;;
        logs)
            log_info "查看 ArgoCD 日志..."
            # 这里可以添加日志查看逻辑
            ;;
        *)
            echo "Usage: $0 {deploy|upgrade|uninstall|status|logs} [project_id] [namespace] [environment] [dry_run]"
            echo ""
            echo "Examples:"
            echo "  $0 deploy sunmoonai cicd-platform production"
            echo "  $0 deploy sunmoonai cicd-platform development true"
            echo "  $0 upgrade sunmoonai cicd-platform production"
            echo "  $0 uninstall sunmoonai cicd-platform"
            echo "  $0 status sunmoonai cicd-platform"
            echo "  $0 logs sunmoonai cicd-platform"
            ;;
    esac
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
