#!/bin/bash

# Document Converter BFF 部署脚本
# 用法: ./deploy-document-converter-bff.sh <deploy|uninstall|status> [project_id] [namespace] [environment]
# 镜像构建请在源码仓库执行 mybuild/build-image.sh（可选推送）

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 项目根目录（deploy-document-converter-bff 目录）
# 从 app/deploy-app/ 向上 2 级到达 deploy-document-converter-bff/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# 应用根目录（document-converter-bff 目录）
# 从 deploy-document-converter-bff/ 向上 1 级到达 document-converter-bff/
APP_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"

# 保存 Document Converter 脚本的目录路径（统一部署模板会重新定义 SCRIPT_DIR）
DOCUMENT_CONVERTER_SCRIPT_DIR="$SCRIPT_DIR"

# 导入统一部署模板
# 从应用根目录（document-converter-bff/）到 k8s/ 需要向上 3 级
# document-converter-bff/ -> document-converter-app/ -> sunmoonai/ -> k8s/
source "$APP_ROOT/../../../k8s/utils/unified-deployment-template.sh"

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
        if [[ -f "$APP_ROOT/../../../../k8s/utils/cluster-config-mapping.sh" ]]; then
            source "$APP_ROOT/../../../../k8s/utils/cluster-config-mapping.sh"
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

# 加载部署配置文件（标准结构：app/deploy-app/deploy-document-converter-bff.conf）
DOCUMENT_CONVERTER_BFF_CONFIG_FILE="$SCRIPT_DIR/deploy-document-converter-bff.conf"
if [[ -f "$DOCUMENT_CONVERTER_BFF_CONFIG_FILE" ]]; then
    source "$DOCUMENT_CONVERTER_BFF_CONFIG_FILE"
    
    # 加载集群配置映射函数
    if [[ -f "$APP_ROOT/../../../../k8s/utils/cluster-config-mapping.sh" ]]; then
        source "$APP_ROOT/../../../../k8s/utils/cluster-config-mapping.sh"
        apply_cluster_config_mapping
    fi
    
    log_info "已加载 Document Converter BFF 配置文件: $DOCUMENT_CONVERTER_BFF_CONFIG_FILE"
else
    log_warn "未找到 Document Converter BFF 配置文件: $DOCUMENT_CONVERTER_BFF_CONFIG_FILE，使用默认配置"
fi

# 向后兼容：如果存在旧的配置文件，也加载它（但会给出警告）
OLD_CONFIG_FILE="$PROJECT_ROOT/deploy-document-converter.conf"
if [[ -f "$OLD_CONFIG_FILE" ]]; then
    log_warn "⚠️  检测到旧版配置文件: $OLD_CONFIG_FILE"
    log_warn "⚠️  此文件已废弃，请使用标准配置文件: $DOCUMENT_CONVERTER_BFF_CONFIG_FILE"
    source "$OLD_CONFIG_FILE"
fi

# 默认配置从配置文件读取（deploy-document-converter-bff.conf）
# 如果配置文件未设置，则使用空值（由函数参数默认值处理）
DEFAULT_PROJECT_ID="${DOCUMENT_CONVERTER_BFF_PROJECT_ID:-}"
DEFAULT_NAMESPACE="${DOCUMENT_CONVERTER_BFF_NAMESPACE:-}"
DEFAULT_ENVIRONMENT="${ENVIRONMENT:-}"

# 资源文件路径（对齐项目结构）
# 从 app/deploy-app/ 向上 3 级到达应用根目录（document-converter-bff/）
# app/deploy-app/ -> app/ -> deploy-document-converter-bff/ -> document-converter-bff/
RESOURCES_DIR="../../../resources"
# 使用生成的 YAML 文件（由各组件自己的 generate-*.sh 生成）
# YAML 文件现在分散在各组件的 generate-* 目录下
K8S_RESOURCE_DIR="${RESOURCES_DIR}/k8s-resource"
DOCUMENT_CONVERTER_BFF_YAML="${K8S_RESOURCE_DIR}/custom-values/app/generate-app/document-converter-bff-generated.yaml"
DOCUMENT_CONVERTER_BFF_PVC_YAML="${K8S_RESOURCE_DIR}/custom-values/pvc/document-converter-pvc/generate-document-converter-pvc/document-converter-pvc-generated.yaml"
# 模板文件路径（在 resources/k8s-resource/templates/）
TEMPLATES_DIR="${K8S_RESOURCE_DIR}/templates"
DOCUMENT_CONVERTER_BFF_CONFIGMAP="${TEMPLATES_DIR}/configmap/document-converter-config.yaml"
DOCUMENT_CONVERTER_BFF_SECRET="${TEMPLATES_DIR}/secret/document-converter-secret.yaml"

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

# 动态扫描并部署组件（替换 deploy-*-all 脚本）
# 参数：
#   $1: 组件类型目录（如 "secret" 或 "middleware"）
#   $2: project_id
#   $3: namespace
#   $4: environment
#   $5: dry_run（可选）
scan_and_deploy_components() {
    local component_type="$1"
    local project_id="$2"
    local namespace="$3"
    local environment="$4"
    local dry_run="${5:-}"
    local base_dir="$PROJECT_ROOT/$component_type"
    local components=()
    
    log_info "开始扫描 $component_type/ 目录下的组件..."
    
    # 检查目录是否存在
    if [[ ! -d "$base_dir" ]]; then
        log_warn "目录不存在: $base_dir，跳过 $component_type 组件部署"
        return 0
    fi
    
    # 扫描所有子目录
    for subdir in "$base_dir"/*/; do
        # 检查是否是目录
        [[ ! -d "$subdir" ]] && continue
        
        local dirname=$(basename "$subdir")
        
        # 跳过 deploy-*-all 目录
        if [[ "$dirname" =~ ^deploy-.*-all$ ]]; then
            log_info "跳过 deploy-*-all 目录: $dirname"
            continue
        fi
        
        # 查找 deploy-* 目录
        # 特殊处理：ingress 组件使用 deploy-ingress（简化命名）
        local deploy_dir
        local script_file
        local conf_file
        
        if [[ "$component_type" == "ingress" ]]; then
            # Ingress 组件使用简化命名：deploy-ingress/deploy-ingress.sh
            deploy_dir="$subdir/deploy-ingress"
            script_file="$deploy_dir/deploy-ingress.sh"
            conf_file="$deploy_dir/deploy-ingress.conf"
        else
            # 其他组件使用标准命名：deploy-{component-name}/deploy-{component-name}.sh
            deploy_dir="$subdir/deploy-${dirname}"
            script_file="$deploy_dir/deploy-${dirname}.sh"
            conf_file="$deploy_dir/deploy-${dirname}.conf"
        fi
        
        if [[ ! -d "$deploy_dir" ]]; then
            log_warn "未找到部署目录: $deploy_dir，跳过组件 $dirname"
            continue
        fi
        
        if [[ ! -f "$script_file" ]]; then
            log_warn "部署脚本不存在: $script_file，跳过组件 $dirname"
            continue
        fi
        
        # 将目录名转换为变量名（将 - 替换为 _）
        # 特殊处理：document-converter-bff-* -> document_converter_bff_*
        # 例如：harbor-registry-secret -> harbor_registry_secret
        #      document-converter-bff-secret -> document_converter_bff_secret
        #      document-converter-bff-config -> document_converter_bff_config
        local var_base=$(echo "$dirname" | tr '-' '_')
        # 处理 document_converter_bff_* 简化为 document_converter_bff_*
        var_base=$(echo "$var_base" | sed 's/^document_converter_bff_/document_converter_bff_/')
        
        local enabled_var="${var_base}_enabled"
        local priority_var="${var_base}_priority"
        local description_var="${var_base}_description"
        
        # 读取配置文件（如果存在）
        local enabled="true"
        local priority="100"
        local description="$dirname"
        
        if [[ -f "$conf_file" ]]; then
            # Source 配置文件以读取变量
            # 注意：每个组件的变量名是特定的，不会冲突
            source "$conf_file" 2>/dev/null || true
            
            # 读取组件特定的 enabled 和 priority（使用 eval 动态获取变量值）
            # 混合方案：主配置的总开关（在 deploy_sub_components 中检查）&& 组件的细粒度开关 = 最终是否部署
            # 例如：secrets_enabled=true && harbor_registry_secret_enabled=true = 部署
            eval "enabled=\${${enabled_var}:-true}"
            eval "priority=\${${priority_var}:-100}"
            eval "description=\${${description_var}:-$dirname}"
        fi
        
        # 添加到组件列表（格式：dirname:enabled:priority:description:script_file）
        components+=("$dirname:$enabled:$priority:$description:$script_file")
    done
    
    # 如果没有找到组件，直接返回
    if [[ ${#components[@]} -eq 0 ]]; then
        log_info "未找到 $component_type 组件，跳过部署"
        return 0
    fi
    
    # 按优先级排序（数值越大优先级越高）
    IFS=$'\n' sorted_components=($(printf '%s\n' "${components[@]}" | sort -t: -k3 -nr))
    unset IFS
    
    # 显示部署顺序
    log_info "📋 $component_type 组件部署顺序（按优先级排序）："
    for c in "${sorted_components[@]}"; do
        IFS=':' read -r name enabled priority desc script <<< "$c"
        if [[ "$enabled" == "true" ]]; then
            log_info "  🚀 $priority - $desc"
        else
            log_info "  ⏭️  $priority - $desc (已禁用)"
        fi
    done
    
    # 部署启用的组件
    for c in "${sorted_components[@]}"; do
        IFS=':' read -r name enabled priority desc script <<< "$c"
        
        if [[ "$enabled" == "true" ]]; then
            log_info "🚀 部署 $desc (优先级: $priority)..."
            
            if [[ -f "$script" ]]; then
                # 禁用子脚本的自动清理，保持连接以便后续操作
                if DISABLE_AUTO_CLEANUP=true bash "$script" deploy "$project_id" "$namespace" "$environment" "$dry_run"; then
                    log_success "✅ $desc 部署成功"
                else
                    log_error "❌ $desc 部署失败"
                    return 1
                fi
            else
                log_error "❌ $desc 部署脚本不存在: $script"
                return 1
            fi
        else
            log_info "⏭️  跳过 $desc (已禁用)"
        fi
    done
    
    log_success "✅ $component_type 组件部署完成"
    return 0
}

# 递归部署子组件
deploy_sub_components() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始部署 Document Converter BFF 子组件..."
    
    # 首先部署 Namespace（如果启用，应在所有资源之前）
    if [[ "${namespace_enabled:-true}" == "true" ]]; then
        if ! scan_and_deploy_components "namespace" "$project_id" "$namespace" "$environment" "$dry_run"; then
            log_error "❌ Namespace 组件部署失败"
            return 1
        fi
    else
        log_info "⏭️  跳过 Namespace 组件部署 (已禁用)"
    fi
    
    # 使用动态扫描函数部署 secret、configmap 和 middleware 组件
    # 如果启用了 secrets，则动态扫描并部署所有 secret 组件
    if [[ "${secrets_enabled:-true}" == "true" ]]; then
        if ! scan_and_deploy_components "secret" "$project_id" "$namespace" "$environment" "$dry_run"; then
            log_error "❌ Secret 组件部署失败"
            return 1
        fi
    else
        log_info "⏭️  跳过 Secret 组件部署 (已禁用)"
    fi
    
    # 如果启用了 configmap，则动态扫描并部署所有 configmap 组件
    if [[ "${configmap_enabled:-true}" == "true" ]]; then
        if ! scan_and_deploy_components "configMap" "$project_id" "$namespace" "$environment" "$dry_run"; then
            log_error "❌ ConfigMap 组件部署失败"
            return 1
        fi
    else
        log_info "⏭️  跳过 ConfigMap 组件部署 (已禁用)"
    fi
    
    # 如果启用了 middleware，则动态扫描并部署所有 middleware 组件
    if [[ "${middleware_enabled:-false}" == "true" ]]; then
        if ! scan_and_deploy_components "middleware" "$project_id" "$namespace" "$environment" "$dry_run"; then
            log_error "❌ Middleware 组件部署失败"
            return 1
        fi
    else
        log_info "⏭️  跳过 Middleware 组件部署 (已禁用)"
    fi
    
    # Ingress 组件（使用动态扫描）
    if [[ "${ingress_enabled:-false}" == "true" ]]; then
        if ! scan_and_deploy_components "ingress" "$project_id" "$namespace" "$environment" "$dry_run"; then
            log_error "❌ Ingress 组件部署失败"
            return 1
        fi
    else
        log_info "⏭️  跳过 Ingress 组件部署 (已禁用)"
    fi
    
    log_success "✅ Document Converter BFF 子组件部署完成"
    return 0
}

# 检查环境配置
# 自动生成 YAML 文件的辅助函数
# 注意：总是重新生成，确保使用最新的模板
# 参数：yaml_file - 要生成的 YAML 文件路径（用于确定是哪个组件）
auto_generate_yaml() {
    local yaml_file="$1"
    local custom_values_dir="$2"  # 保留参数兼容性，但不再使用
    
    log_info "重新生成 YAML 文件（确保使用最新的模板）..."
    
    # 根据 YAML 文件路径确定对应的生成脚本
    local generate_script=""
    if [[ "$yaml_file" == *"document-converter-bff-generated.yaml" ]] && [[ "$yaml_file" != *"config"* ]] && [[ "$yaml_file" != *"secret"* ]] && [[ "$yaml_file" != *"pvc"* ]] && [[ "$yaml_file" != *"ingress"* ]]; then
        # 主应用 YAML
        generate_script="${K8S_RESOURCE_DIR}/custom-values/app/generate-app/generate-app.sh"
    elif [[ "$yaml_file" == *"document-converter-pvc-generated.yaml" ]]; then
        # PVC YAML
        generate_script="${K8S_RESOURCE_DIR}/custom-values/pvc/document-converter-pvc/generate-document-converter-pvc/generate-document-converter-pvc.sh"
    else
        log_warn "无法确定生成脚本，尝试使用默认路径"
        generate_script="${K8S_RESOURCE_DIR}/custom-values/app/generate-app/generate-app.sh"
    fi
    
    if [ -f "$generate_script" ]; then
        # 导出基础配置变量，供生成脚本使用（通过环境变量继承）
        # 这样生成脚本可以通过 ${NAMESPACE:-default} 语法使用这些值
        export NAMESPACE="${DOCUMENT_CONVERTER_BFF_NAMESPACE:-app-platform-dev}"
        export ENVIRONMENT="${ENVIRONMENT:-development}"
        export ENV="${ENV:-dev}"
        export PROJECT_ID="${DOCUMENT_CONVERTER_BFF_PROJECT_ID:-sunmoonai}"
        
        if bash "$generate_script"; then
            log_success "YAML 文件生成成功"
        else
            log_error "YAML 文件生成失败"
            return 1
        fi
    else
        log_error "生成脚本不存在: $generate_script"
        return 1
    fi
    return 0
}

check_env_config() {
    # 自动生成 YAML 文件（如果不存在）
    if ! auto_generate_yaml "$DOCUMENT_CONVERTER_BFF_YAML" "$K8S_RESOURCE_DIR"; then
        exit 1
    fi
    
    if [[ "${secrets_enabled:-true}" == "true" ]] || [[ "${configmap_enabled:-true}" == "true" ]]; then
        # 检查 ConfigMap 和 Secret 的部署脚本
        local secrets_dir="$PROJECT_ROOT/secret"
        local configmap_dir="$PROJECT_ROOT/configMap"
        local config_script="$configmap_dir/document-converter-config/deploy-document-converter-config/deploy-document-converter-config.sh"
        local secret_script="$secrets_dir/document-converter-secret/deploy-document-converter-secret/deploy-document-converter-secret.sh"
        if [[ "${configmap_enabled:-true}" == "true" ]]; then
            [[ -f "$config_script" ]] || { log_error "缺少 ConfigMap 部署脚本: $config_script"; exit 1; }
        fi
        if [[ "${secrets_enabled:-true}" == "true" ]]; then
            [[ -f "$secret_script" ]] || { log_error "缺少 Secret 部署脚本: $secret_script"; exit 1; }
        fi
    fi
    
    # 自动生成 YAML 文件（如果不存在）
    if ! auto_generate_yaml "$DOCUMENT_CONVERTER_BFF_YAML" "$K8S_RESOURCE_DIR"; then
        exit 1
    fi
}

# 镜像配置（从部署配置文件读取，用于部署时指定镜像）
# 镜像名称和标签应该与 build/build.conf 中的配置保持一致
# 注意：这些配置应该在 generate-app.conf 中，这里仅用于部署时的覆盖
# 如果未设置，将从 generate-app.conf 读取（由生成脚本处理）
DOCUMENT_CONVERTER_BFF_IMAGE="${DOCUMENT_CONVERTER_BFF_IMAGE:-}"
DOCUMENT_CONVERTER_BFF_TAG="${DOCUMENT_CONVERTER_BFF_TAG:-}"

# 部署 Document Converter BFF
deploy_app() {
    log_info "开始部署 Document Converter BFF..."
    log_info "环境: $ENVIRONMENT, 命名空间: $NAMESPACE"
    
    # 检查环境配置
    check_env_config
    
    # deploy 命令：使用 Harbor 镜像部署
    # 注意：部署前请确保镜像已构建并推送到 Harbor
    # 构建镜像请使用: cd ../mybuild && ./build-image.sh build-push
    # 镜像配置从生成配置中读取（通过生成脚本导出环境变量）
    # 如果生成脚本已运行，这些变量应该已经设置；否则使用默认值
    export DOCUMENT_CONVERTER_IMAGE_REGISTRY="${DOCUMENT_CONVERTER_IMAGE_REGISTRY:-harbor.sunmoonai.com:30443}"
    export DOCUMENT_CONVERTER_IMAGE_PROJECT="${DOCUMENT_CONVERTER_IMAGE_PROJECT:-k8s-images}"
    export DOCUMENT_CONVERTER_IMAGE="${DOCUMENT_CONVERTER_IMAGE:-document-converter}"
    export DOCUMENT_CONVERTER_TAG="${DOCUMENT_CONVERTER_TAG:-1.0}"
    export IMAGE_PULL_POLICY="${IMAGE_PULL_POLICY:-Always}"
    export DOCUMENT_CONVERTER_IMAGE_PULL_SECRET_NAME="${DOCUMENT_CONVERTER_IMAGE_PULL_SECRET_NAME:-harbor-registry-secret}"
    
    DOCUMENT_CONVERTER_BFF_FULL_IMAGE_NAME="${DOCUMENT_CONVERTER_IMAGE_REGISTRY}/${DOCUMENT_CONVERTER_IMAGE_PROJECT}/${DOCUMENT_CONVERTER_IMAGE}:${DOCUMENT_CONVERTER_TAG}"
    log_info "使用 Harbor 镜像部署: $DOCUMENT_CONVERTER_BFF_FULL_IMAGE_NAME"
    log_info "Kubernetes 将从镜像仓库拉取镜像"
    log_warn "⚠️  请确保该镜像已存在于 Harbor 仓库中"
    
    # 准备环境变量（用于后续的 YAML 生成和部署）
    export NAMESPACE="$NAMESPACE"
    export ENV="$ENV"  # 保留 ENV 用于兼容性（YAML 中可能使用）
    export ENVIRONMENT="$ENVIRONMENT"
    export DOCUMENT_CONVERTER_BFF_FULL_IMAGE_NAME="$DOCUMENT_CONVERTER_BFF_FULL_IMAGE_NAME"
    
    # ============================================================
    # 阶段1：部署子级组件（按优先级，先部署依赖项）
    # ============================================================
    log_info "🚀 阶段1：部署 Document Converter BFF 子级组件..."
    if ! deploy_sub_components "$PROJECT_ID" "$NAMESPACE" "$ENVIRONMENT" false; then
        log_error "❌ Document Converter BFF 子级组件部署失败！"
        return 1
    fi
    log_success "✅ Document Converter BFF 子级组件部署完成"
    
    # ============================================================
    # 阶段2：部署本级核心服务（Deployment 和 Service）
    # ============================================================
    log_info "🚀 阶段2：部署 Document Converter BFF 核心服务..."
    log_info "部署 Document Converter BFF (环境: $ENVIRONMENT, 镜像: $DOCUMENT_CONVERTER_BFF_FULL_IMAGE_NAME, 拉取策略: ${IMAGE_PULL_POLICY:-Always}, 命名空间: $NAMESPACE)..."
    
    # 确保 Kubernetes 连接仍然可用（子组件脚本可能已清理连接）
    if ! kubectl get nodes >/dev/null 2>&1; then
        log_warn "⚠️ Kubernetes 连接已断开，正在重新建立连接..."
        if ! setup_kubectl_environment; then
            log_error "❌ 无法重新建立 Kubernetes 连接"
            return 1
        fi
        # 验证连接是否可用
        if ! kubectl get nodes >/dev/null 2>&1; then
            log_error "❌ Kubernetes 连接不可用，请检查连接状态"
            return 1
        fi
        log_success "✅ Kubernetes 连接已重新建立"
    fi
    
    # 检查生成的 YAML 文件是否存在
    # 自动生成 YAML 文件（如果不存在）
    if ! auto_generate_yaml "$DOCUMENT_CONVERTER_BFF_YAML" "$K8S_RESOURCE_DIR"; then
        return 1
    fi
    
    # 部署 PVC（如果存在）
    if [ -f "$DOCUMENT_CONVERTER_BFF_PVC_YAML" ]; then
        log_info "部署 PVC..."
        kubectl apply -f "$DOCUMENT_CONVERTER_BFF_PVC_YAML" -n "$NAMESPACE"
        if [ $? -eq 0 ]; then
            log_success "PVC 部署完成"
        else
            log_error "PVC 部署失败"
            return 1
        fi
    fi
    
    # 部署 Deployment 和 Service（直接使用生成的 YAML）
    kubectl apply -f "$DOCUMENT_CONVERTER_BFF_YAML" -n "$NAMESPACE"
    
    if [ $? -eq 0 ]; then
        log_success "Document Converter BFF 部署完成！"
        echo ""
        log_info "检查部署状态:"
        echo "  kubectl get pods -n $NAMESPACE -l app=document-converter-bff"
        echo "  kubectl get svc -n $NAMESPACE -l app=document-converter-bff"
        echo ""
        log_info "查看 Pod 日志:"
        echo "  kubectl logs -n $NAMESPACE -l app=document-converter-bff -f"
    else
        log_error "Document Converter BFF 部署失败"
        exit 1
    fi
}


# 卸载 Document Converter BFF
uninstall_app() {
    log_info "开始卸载 Document Converter BFF..."
    log_info "环境: $ENVIRONMENT, 命名空间: $NAMESPACE"
    
    check_env_config
    
    # ============================================================
    # 阶段1：卸载本级核心服务（Deployment 和 Service）
    # ============================================================
    log_info "🚀 阶段1：卸载 Document Converter BFF 核心服务..."
    # 卸载时使用原始 YAML（删除时不需要替换镜像，但需要替换命名空间）
    # 检查生成的 YAML 文件是否存在
    if [ ! -f "$DOCUMENT_CONVERTER_BFF_YAML" ]; then
        log_warn "生成的 YAML 文件不存在: $DOCUMENT_CONVERTER_BFF_YAML，尝试直接删除资源"
        kubectl delete deployment document-converter-bff -n "$NAMESPACE" --ignore-not-found=true || true
        kubectl delete service document-converter-bff -n "$NAMESPACE" --ignore-not-found=true || true
    else
        kubectl delete -f "$DOCUMENT_CONVERTER_BFF_YAML" -n "$NAMESPACE" --ignore-not-found=true
    fi
    log_success "✅ Document Converter BFF 核心服务卸载完成"
    
    # ============================================================
    # 阶段2：卸载子级组件（按优先级，逆序卸载）
    # 注意：Namespace 应该在最后卸载，因为删除 namespace 会删除其中的所有资源
    # ============================================================
    log_info "🚀 阶段2：卸载 Document Converter BFF 子级组件..."
    if ! uninstall_sub_components "$PROJECT_ID" "$NAMESPACE" "$ENVIRONMENT" false; then
        log_warn "⚠️ Document Converter BFF 子级组件卸载部分失败，继续..."
    fi
    log_success "✅ Document Converter BFF 子级组件卸载完成"
    
    # ============================================================
    # 阶段3：卸载 Namespace（最后卸载，需要用户确认）
    # 注意：删除 namespace 会删除其中的所有资源，需要谨慎操作
    # ============================================================
    if [[ "${namespace_enabled:-true}" == "true" ]]; then
        log_warn "⚠️  注意：卸载 Namespace 将删除命名空间 $NAMESPACE 及其中的所有资源！"
        log_info "如需卸载 Namespace，请手动执行："
        log_info "  cd deploy-document-converter-bff/namespace/document-converter-bff-namespace/deploy-document-converter-bff-namespace"
        log_info "  ./deploy-document-converter-bff-namespace.sh uninstall $PROJECT_ID $NAMESPACE $ENVIRONMENT"
    fi
    
    log_success "Document Converter BFF 卸载完成！"
}

# 卸载子组件（按优先级，逆序）
uninstall_sub_components() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始卸载 Document Converter BFF 子组件..."
    
    # 定义子组件卸载顺序（按优先级排序，逆序卸载）
    # 注意：这里只处理需要特殊卸载逻辑的组件，其他组件通过动态扫描卸载
    local sub_components=(
        "document_converter_bff_middleware:${middleware_enabled:-false}:${middleware_priority:-1000}:Document Converter BFF 中间件:$PROJECT_ROOT/middleware/deploy-middleware-all/deploy-middleware-all.sh"
        "document_converter_bff_ingress:${ingress_enabled:-false}:${ingress_priority:-100}:Document Converter BFF HTTP 路由:$PROJECT_ROOT/ingress/deploy-ingress/deploy-ingress.sh"
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
                if [[ "$name" == "document_converter_bff_ingress" ]]; then
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
    
    # 动态卸载其他组件（secret, configmap）
    # 注意：scan_and_deploy_components 只支持 deploy，卸载需要直接调用组件的 uninstall 脚本
    if [[ "${secrets_enabled:-true}" == "true" ]]; then
        local secrets_dir="$PROJECT_ROOT/secret"
        if [[ -d "$secrets_dir" ]]; then
            for secret_dir in "$secrets_dir"/*/; do
                [[ ! -d "$secret_dir" ]] && continue
                local secret_name=$(basename "$secret_dir")
                local secret_deploy_dir="$secret_dir/deploy-${secret_name}"
                local secret_script="$secret_deploy_dir/deploy-${secret_name}.sh"
                if [[ -f "$secret_script" ]]; then
                    log_info "卸载 Secret: $secret_name..."
                    if DISABLE_AUTO_CLEANUP=true bash "$secret_script" uninstall "$project_id" "$namespace" "$environment" 2>/dev/null; then
                        log_success "✅ Secret $secret_name 卸载成功"
                    else
                        log_warn "⚠️ Secret $secret_name 卸载失败或已不存在"
                    fi
                fi
            done
        fi
    fi
    
    if [[ "${configmap_enabled:-true}" == "true" ]]; then
        local configmap_dir="$PROJECT_ROOT/configMap"
        if [[ -d "$configmap_dir" ]]; then
            for config_dir in "$configmap_dir"/*/; do
                [[ ! -d "$config_dir" ]] && continue
                local config_name=$(basename "$config_dir")
                local config_deploy_dir="$config_dir/deploy-${config_name}"
                local config_script="$config_deploy_dir/deploy-${config_name}.sh"
                if [[ -f "$config_script" ]]; then
                    log_info "卸载 ConfigMap: $config_name..."
                    if DISABLE_AUTO_CLEANUP=true bash "$config_script" uninstall "$project_id" "$namespace" "$environment" 2>/dev/null; then
                        log_success "✅ ConfigMap $config_name 卸载成功"
                    else
                        log_warn "⚠️ ConfigMap $config_name 卸载失败或已不存在"
                    fi
                fi
            done
        fi
    fi
    
    log_success "✅ Document Converter BFF 子组件卸载完成"
    return 0
}

# 显示状态
show_status() {
    log_info "Document Converter BFF 状态:"
    echo ""
    echo "📦 Pods:"
    kubectl get pods -n "$NAMESPACE" -l app=document-converter-bff 2>/dev/null || echo "  无 Pod 运行"
    echo ""
    echo "🌐 Services:"
    kubectl get svc -n "$NAMESPACE" -l app=document-converter-bff 2>/dev/null || echo "  无 Service"
    echo ""
    echo "📋 Deployments:"
    kubectl get deployment -n "$NAMESPACE" -l app=document-converter-bff 2>/dev/null || echo "  无 Deployment"
    echo ""
    echo "📋 ConfigMaps:"
    kubectl get configmap -n "$NAMESPACE" -l app=document-converter-bff 2>/dev/null || echo "  无 ConfigMap"
    echo ""
    echo "🔐 Secrets:"
    kubectl get secret -n "$NAMESPACE" -l app=document-converter-bff 2>/dev/null || echo "  无 Secret"
    echo ""
    echo "📦 PVCs:"
    kubectl get pvc -n "$NAMESPACE" -l app=document-converter-bff 2>/dev/null || echo "  无 PVC"
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
    # 参数优先级：命令行参数 > 配置文件 > 空值（由调用者确保提供）
    local project_id="${2:-${DEFAULT_PROJECT_ID:-}}"
    local namespace="${3:-${DEFAULT_NAMESPACE:-}}"
    local environment="${4:-${DEFAULT_ENVIRONMENT:-}}"
    
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
    
    log_info "Document Converter BFF 部署脚本启动"
    log_info "操作: $ACTION, 项目: $PROJECT_ID, 命名空间: $NAMESPACE, 环境: $ENVIRONMENT"
    
    check_kubectl
    
    case "$ACTION" in
        "deploy")
            log_info "开始部署 Document Converter BFF..."
            
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
            
            # 如果启用了 namespace 组件，先部署 namespace（会在 deploy_sub_components 中处理）
            # 否则检查命名空间是否存在
            if [[ "${namespace_enabled:-true}" != "true" ]]; then
                if ! check_namespace "$NAMESPACE"; then
                    log_error "命名空间检查失败"
                    exit 1
                fi
            fi
            
            # 部署应用
            if deploy_app; then
                log_success "✅ Document Converter BFF 部署完成！"
            else
                log_error "❌ Document Converter BFF 部署失败"
                exit 1
            fi
            ;;
        "uninstall")
            log_info "开始卸载 Document Converter BFF..."
            
            # 读取 Kubernetes 配置文件
            if ! read_k8s_config; then
                log_error "无法读取 Kubernetes 配置文件"
                exit 1
            fi
            
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
            
            # 卸载应用
            uninstall_app
            ;;
        "status")
            log_info "查询 Document Converter BFF 状态..."
            
            # 读取 Kubernetes 配置文件
            if ! read_k8s_config; then
                log_error "无法读取 Kubernetes 配置文件"
                exit 1
            fi
            
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
            
            show_status
            ;;
        *)
            log_error "❌ 未知操作: $ACTION"
            log_info "支持的操作: deploy, uninstall, status"
            exit 1
            ;;
    esac
}

# 执行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

