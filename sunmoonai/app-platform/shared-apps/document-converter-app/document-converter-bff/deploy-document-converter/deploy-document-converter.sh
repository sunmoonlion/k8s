#!/bin/bash

# Document Converter 递归部署脚本
# 基于递归架构设计原则的两级部署逻辑

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 保存 Document Converter 脚本的目录路径（统一部署模板会重新定义 SCRIPT_DIR）
DOCUMENT_CONVERTER_SCRIPT_DIR="$SCRIPT_DIR"

# 导入统一部署模板
source "$PROJECT_ROOT/../../../utils/unified-deployment-template.sh"

# 恢复 Document Converter 脚本的目录路径
SCRIPT_DIR="$DOCUMENT_CONVERTER_SCRIPT_DIR"

# 解析命令行参数
parse_cluster_arg() {
    local args=("$@")
    PARSED_ARGS=()
    local cluster_value=""
    local i=0
    
    while [[ $i -lt ${#args[@]} ]]; do
        shopt -s nocasematch
        case "${args[$i]}" in
            --[cC][lL][uU][sS][tT][eE][rR]=*)
                cluster_value="${args[$i]#*=}"
                cluster_value=$(echo "$cluster_value" | tr '[:lower:]' '[:upper:]')
                export CLUSTER="$cluster_value"
                log_info "🔧 设置集群环境变量: CLUSTER=$cluster_value"
                ;;
            --[cC][lL][uU][sS][tT][eE][rR]|-c|-C)
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
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

CONVERTER_CONFIG_FILE="$SCRIPT_DIR/deploy-document-converter.conf"
if [[ -f "$CONVERTER_CONFIG_FILE" ]]; then
    source "$CONVERTER_CONFIG_FILE"
    
    # 加载集群配置映射函数
    if [[ -f "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh"
        apply_cluster_config_mapping
    fi
    
    log_info "已加载 Document Converter 配置文件: $CONVERTER_CONFIG_FILE"
else
    log_error "缺少 Document Converter 配置文件: $CONVERTER_CONFIG_FILE"
    exit 1
fi

# 默认配置
DEFAULT_PROJECT_ID="${DOCUMENT_CONVERTER_PROJECT_ID:-sunmoonai}"
DEFAULT_NAMESPACE="${DOCUMENT_CONVERTER_NAMESPACE:-app-platform-dev}"
DEFAULT_ENVIRONMENT="${ENVIRONMENT:-development}"

# 资源目录（新的结构：resources/ 在项目根目录下）
CONVERTER_RESOURCE_DIR="$PROJECT_ROOT/resources"

# 检查命名空间
check_namespace() {
    local namespace="${DOCUMENT_CONVERTER_NAMESPACE:-$DEFAULT_NAMESPACE}"
    log_info "检查命名空间: $namespace"
    
    if ! kubectl get namespace "$namespace" &>/dev/null; then
        log_warn "命名空间不存在，正在创建: $namespace"
        kubectl create namespace "$namespace"
        log_success "命名空间创建成功: $namespace"
    else
        log_success "命名空间已存在: $namespace"
    fi
}

# 部署 Document Converter Secrets
deploy_document_converter_secrets() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="${4:-false}"
    
    log_info "🚀 部署 Document Converter Secrets..."
    
    local secrets_script="$SCRIPT_DIR/secrets/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh"
    
    if [[ ! -f "$secrets_script" ]]; then
        log_warn "⚠️  Document Converter Secrets 部署脚本不存在: $secrets_script"
        log_warn "跳过 Secrets 部署，请手动部署或检查脚本路径"
        return 0
    fi
    
    # 检查是否启用 Secrets 部署（默认启用）
    if [[ "${secrets_enabled:-true}" == "true" ]]; then
        if bash "$secrets_script" "$project_id" "$namespace" "$environment" "$dry_run"; then
            log_success "✅ Document Converter Secrets 部署成功"
            return 0
        else
            log_error "❌ Document Converter Secrets 部署失败"
            return 1
        fi
    else
        log_info "跳过 Document Converter Secrets 部署（secrets_enabled=false）"
        return 0
    fi
}

# 部署 Document Converter
execute_converter_deployment() {
    local namespace="${DOCUMENT_CONVERTER_NAMESPACE:-$DEFAULT_NAMESPACE}"
    local environment="${ENVIRONMENT:-$DEFAULT_ENVIRONMENT}"
    
    log_info "🚀 开始部署 Document Converter..."
    log_info "命名空间: $namespace"
    log_info "环境: $environment"
    
    # 检查资源目录
    if [[ ! -d "$CONVERTER_RESOURCE_DIR" ]]; then
        log_error "资源目录不存在: $CONVERTER_RESOURCE_DIR"
        exit 1
    fi
    
    # 准备镜像地址
    local image_registry="${DOCUMENT_CONVERTER_IMAGE_REGISTRY:-harbor.sunmoonai.com:30443}"
    local image_project="${DOCUMENT_CONVERTER_IMAGE_PROJECT:-k8s-images}"
    local image_name="${DOCUMENT_CONVERTER_IMAGE_NAME:-document-converter}"
    local image_tag="${DOCUMENT_CONVERTER_IMAGE_TAG:-latest}"
    local full_image="${image_registry}/${image_project}/${image_name}:${image_tag}"
    
    log_info "镜像地址: $full_image"
    
    # 处理 Deployment YAML（新结构：直接在 resources/ 目录下）
    local deployment_file="$CONVERTER_RESOURCE_DIR/deployment.yaml"
    if [[ ! -f "$deployment_file" ]]; then
        log_error "Deployment 文件不存在: $deployment_file"
        log_error "请确保文件存在于: $CONVERTER_RESOURCE_DIR/deployment.yaml"
        exit 1
    fi
    
    # 替换模板变量
    local temp_deployment=$(mktemp)
    sed -e "s|{{NAMESPACE}}|$namespace|g" \
        -e "s|{{IMAGE}}|$full_image|g" \
        -e "s|{{REPLICAS}}|${DOCUMENT_CONVERTER_REPLICAS:-2}|g" \
        -e "s|{{CPU_REQUEST}}|${DOCUMENT_CONVERTER_CPU_REQUEST:-500m}|g" \
        -e "s|{{CPU_LIMIT}}|${DOCUMENT_CONVERTER_CPU_LIMIT:-1000m}|g" \
        -e "s|{{MEMORY_REQUEST}}|${DOCUMENT_CONVERTER_MEMORY_REQUEST:-512Mi}|g" \
        -e "s|{{MEMORY_LIMIT}}|${DOCUMENT_CONVERTER_MEMORY_LIMIT:-1Gi}|g" \
        "$deployment_file" > "$temp_deployment"
    
    # 应用 Deployment
    log_info "应用 Deployment..."
    kubectl apply -f "$temp_deployment"
    rm -f "$temp_deployment"
    
    # 处理 Service YAML（新结构：直接在 resources/ 目录下）
    local service_file="$CONVERTER_RESOURCE_DIR/service.yaml"
    if [[ -f "$service_file" ]]; then
        local temp_service=$(mktemp)
        sed -e "s|{{NAMESPACE}}|$namespace|g" \
            -e "s|{{SERVICE_PORT}}|${DOCUMENT_CONVERTER_SERVICE_PORT:-8000}|g" \
            "$service_file" > "$temp_service"
        
        log_info "应用 Service..."
        kubectl apply -f "$temp_service"
        rm -f "$temp_service"
    fi
    
    log_success "✅ Document Converter 部署完成"
}

# 部署子级组件
deploy_sub_components() {
    log_info "部署子级组件..."
    
    # 部署 Middleware
    if [[ "${middleware_enabled:-true}" == "true" ]]; then
        local middleware_script="$PROJECT_ROOT/middleware/deploy-middleware-all/deploy-middleware-all.sh"
        if [[ -f "$middleware_script" ]]; then
            log_info "部署 Middleware..."
            bash "$middleware_script" "${ORIGINAL_ARGS[@]}"
        fi
    fi
    
    # 部署 Ingress
    if [[ "${ingress_enabled:-true}" == "true" ]]; then
        local ingress_script="$PROJECT_ROOT/ingress/deploy-ingress/deploy-ingress.sh"
        if [[ -f "$ingress_script" ]]; then
            log_info "部署 Ingress..."
            bash "$ingress_script" "${ORIGINAL_ARGS[@]}"
        fi
    fi
}

# 显示连接信息
show_converter_connection_info() {
    local namespace="${DOCUMENT_CONVERTER_NAMESPACE:-$DEFAULT_NAMESPACE}"
    local unified_host="${DOCUMENT_CONVERTER_UNIFIED_HOST:-www.sunmoonai.com}"
    local service_port="${DOCUMENT_CONVERTER_SERVICE_PORT:-8000}"
    
    log_info "=========================================="
    log_info "Document Converter 访问信息"
    log_info "=========================================="
    log_info "命名空间: $namespace"
    log_info "服务端口: $service_port"
    log_info ""
    log_info "API 端点:"
    log_info "  - 健康检查: GET /health"
    log_info "  - 转换接口: POST /api/v1/convert"
    log_info "  - 格式列表: GET /api/v1/formats"
    log_info ""
    if [[ "${ingress_enabled:-false}" == "true" ]]; then
        log_info "访问方式（通过 Traefik IngressRoute）:"
        log_info "  - https://$unified_host/document-converter"
        log_info "  - 或通过节点 IP: https://<节点IP>:30443/document-converter"
    else
        log_info "访问方式（集群内部 Service）:"
        log_info "  - http://document-converter.${namespace}.svc.cluster.local:${service_port}"
        log_info "  - 或通过 Service: http://document-converter:${service_port} (同命名空间)"
    fi
    log_info "=========================================="
}

# 卸载 Document Converter
uninstall_document_converter() {
    local namespace="${DOCUMENT_CONVERTER_NAMESPACE:-$DEFAULT_NAMESPACE}"
    
    log_info "=========================================="
    log_info "Document Converter 卸载脚本"
    log_info "=========================================="
    
    # 设置 Kubernetes 连接
    setup_kubectl_environment
    
    log_info "开始卸载 Document Converter..."
    log_info "命名空间: $namespace"
    
    # 卸载子级组件（逆序）
    log_info "卸载子级组件..."
    
    # 卸载 Ingress
    if [[ "${ingress_enabled:-true}" == "true" ]]; then
        local ingress_script="$PROJECT_ROOT/ingress/deploy-ingress/deploy-ingress.sh"
        if [[ -f "$ingress_script" ]]; then
            log_info "卸载 Ingress..."
            bash "$ingress_script" uninstall "${ORIGINAL_ARGS[@]}" || log_warn "Ingress 卸载失败或不存在"
        fi
    fi
    
    # 卸载 Middleware
    if [[ "${middleware_enabled:-true}" == "true" ]]; then
        local middleware_script="$PROJECT_ROOT/middleware/deploy-middleware-all/deploy-middleware-all.sh"
        if [[ -f "$middleware_script" ]]; then
            log_info "卸载 Middleware..."
            bash "$middleware_script" uninstall "${ORIGINAL_ARGS[@]}" || log_warn "Middleware 卸载失败或不存在"
        fi
    fi
    
    # 卸载 Deployment 和 Service
    log_info "卸载 Deployment 和 Service..."
    kubectl delete deployment document-converter -n "$namespace" --ignore-not-found=true || true
    kubectl delete service document-converter -n "$namespace" --ignore-not-found=true || true
    
    # 可选：卸载 Secrets（如果需要）
    # kubectl delete secret harbor-registry-secret -n "$namespace" --ignore-not-found=true || true
    
    log_success "✅ Document Converter 卸载完成！"
}

# 主函数
main() {
    set -- "${ORIGINAL_ARGS[@]}"
    
    local action="${1:-deploy}"
    if [[ "$action" == "deploy" || "$action" == "uninstall" || "$action" == "status" ]]; then
        shift
    fi
    
    case "$action" in
        deploy)
            log_info "=========================================="
            log_info "Document Converter 部署脚本"
            log_info "=========================================="
            
            # 设置 Kubernetes 连接
            setup_kubectl_environment
            
            # 检查命名空间
            check_namespace
            
            # 部署 Secrets（优先部署，确保 Secret 在 Deployment 之前存在）
            local project_id="${DOCUMENT_CONVERTER_PROJECT_ID:-$DEFAULT_PROJECT_ID}"
            local namespace="${DOCUMENT_CONVERTER_NAMESPACE:-$DEFAULT_NAMESPACE}"
            local environment="${ENVIRONMENT:-$DEFAULT_ENVIRONMENT}"
            deploy_document_converter_secrets "$project_id" "$namespace" "$environment" "false"
            
            # 部署 Document Converter
            execute_converter_deployment
            
            # 部署子级组件
            deploy_sub_components
            
            # 显示连接信息
            show_converter_connection_info
            
            log_success "✅ Document Converter 部署完成！"
            ;;
        uninstall)
            uninstall_document_converter
            ;;
        status)
            log_info "状态查询功能待实现"
            ;;
        *)
            log_error "❌ 未知操作: $action"
            log_info "支持的操作: deploy, uninstall, status"
            exit 1
            ;;
    esac
}

# 执行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

