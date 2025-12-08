#!/bin/bash

# Jenkins Web 路由部署脚本

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Jenkins 项目根目录（与主 deploy-jenkins.sh 保持一致）
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# 导入统一部署模板（提供 log_* 和 Kubernetes 连接管理函数）
source "$PROJECT_ROOT/../../../utils/unified-deployment-template.sh"
JENKINS_WEB_FILE="$(dirname "$SCRIPT_DIR")/jenkins-web-route.yaml"

# 部署 Jenkins Web 路由
deploy_jenkins_web() {
    local namespace="${1:-cicd-platform-dev}"
    
    log_info "部署 Jenkins Web 路由..."
    log_info "命名空间: $namespace"
    
    # 检查配置文件是否存在
    if [[ ! -f "$JENKINS_WEB_FILE" ]]; then
        log_error "Jenkins Web 路由配置文件不存在: $JENKINS_WEB_FILE"
        return 1
    fi
    
    # 应用 Web 路由配置
    log_info "应用 Jenkins Web 路由配置..."
    if kubectl apply -f "$JENKINS_WEB_FILE" -n "$namespace"; then
        log_success "✅ Jenkins Web 路由配置应用成功"
    else
        log_error "❌ Jenkins Web 路由配置应用失败"
        return 1
    fi
    
    # 检查路由状态
    log_info "检查 Jenkins Web 路由状态..."
    kubectl get ingressroute -n "$namespace" jenkins-web-route
    
    log_success "✅ Jenkins Web 路由部署完成！"
    return 0
}

# 删除 Jenkins Web 路由
delete_jenkins_web() {
    local namespace="${1:-cicd-platform-dev}"
    
    log_info "删除 Jenkins Web 路由..."
    log_info "命名空间: $namespace"
    
    if kubectl delete -f "$JENKINS_WEB_FILE" 2>/dev/null; then
        log_success "✅ Jenkins Web 路由配置删除成功"
    else
        log_warn "⚠️ Jenkins Web 路由配置不存在或删除失败"
    fi
    
    log_success "✅ Jenkins Web 路由删除完成！"
    return 0
}

# 检查路由状态
check_web_status() {
    local namespace="${1:-cicd-platform-dev}"
    
    log_info "检查 Jenkins Web 路由状态..."
    
    # 检查路由是否存在
    if kubectl get ingressroute -n "$namespace" jenkins-web-route >/dev/null 2>&1; then
        log_success "✅ Jenkins Web 路由存在"
        kubectl get ingressroute -n "$namespace" jenkins-web-route
    else
        log_error "❌ Jenkins Web 路由不存在"
        return 1
    fi
}

# 主函数
main() {
    local action="${1:-deploy}"
    local namespace="${2:-cicd-platform-dev}"
    
    # 建立远程 k8s 连接（使用统一模板中的连接管理函数）
    if ! read_k8s_config; then
        log_error "无法读取 Kubernetes 配置文件"; exit 1; fi
    if ! setup_kubectl_environment; then
        log_error "无法建立 Kubernetes 连接"; exit 1; fi
    
    case "$action" in
        "deploy")
            deploy_jenkins_web "$namespace"
            ;;
        "uninstall")
            delete_jenkins_web "$namespace"
            ;;
        "status")
            check_web_status "$namespace"
            ;;
        "help"|"-h"|"--help")
            echo "用法: $0 <action> [namespace]"
            echo ""
            echo "操作:"
            echo "  deploy           部署 Jenkins Web 路由（默认）"
            echo "  uninstall        删除 Jenkins Web 路由"
            echo "  status           检查路由状态"
            echo "  help             显示此帮助信息"
            echo ""
            echo "参数:"
            echo "  namespace 命名空间（默认: cicd-platform-dev）"
            echo ""
            echo "示例:"
            echo "  $0 deploy"
            echo "  $0 deploy cicd-platform-dev"
            echo "  $0 uninstall"
            echo "  $0 status"
            exit 0
            ;;
        *)
            log_error "未知操作: $action"
            echo "使用 '$0 help' 查看帮助信息"
            exit 1
            ;;
    esac
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
