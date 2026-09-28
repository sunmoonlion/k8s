#!/bin/bash

# Shared request boundary: before configuration, credentials, connections and EXIT traps.
# shellcheck source=/dev/null
source "$(dirname -- "${BASH_SOURCE[0]}")/../../../../../../../../utils/deploy-plan.sh" || exit 2
sunmoon_deploy_entry "${BASH_SOURCE[0]}" action "$@" || exit $?
[[ "$SUNMOON_DEPLOY_PLAN_ONLY" != true ]] || exit 0
set -- "${SUNMOON_DEPLOY_EXEC_ARGS[@]}"
export DISABLE_AUTO_CLEANUP=true

# Document Converter BFF 部署脚本
# 用法: ./deploy-document-converter-backend.sh <deploy|uninstall|status> [project_id] [namespace] [environment]
# 镜像构建请在源码仓库执行 mybuild/build-image.sh（可选推送）

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 项目根目录（deploy-document-converter-backend 目录）
# 从 app/deploy-app/ 向上 2 级到达 deploy-document-converter-backend/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# 应用根目录（document-converter-backend 目录）
# 从 deploy-document-converter-backend/ 向上 1 级到达 document-converter-backend/
APP_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"

# 保存 Document Converter 脚本的目录路径（统一部署模板会重新定义 SCRIPT_DIR）
DOCUMENT_CONVERTER_SCRIPT_DIR="$SCRIPT_DIR"

# 计算 k8s 根目录（向上搜索 utils/cluster-arg-parser.sh）
find_k8s_root_dir() {
    local search_dir="$1"
    while [[ -n "$search_dir" && "$search_dir" != "/" ]]; do
        if [[ -f "$search_dir/utils/cluster-arg-parser.sh" ]]; then
            echo "$search_dir"
            return 0
        fi
        search_dir="$(dirname "$search_dir")"
    done
    return 1
}
K8S_ROOT_DIR="$(find_k8s_root_dir "$APP_ROOT")"
if [[ -z "${K8S_ROOT_DIR:-}" ]]; then
    echo "[ERROR] 无法定位 k8s 根目录（未找到 utils/cluster-arg-parser.sh），APP_ROOT=$APP_ROOT" 1>&2
    exit 1
fi

# 导入统一部署模板
source "$K8S_ROOT_DIR/utils/unified-deployment-template.sh"

# 恢复 Document Converter 脚本的目录路径
SCRIPT_DIR="$DOCUMENT_CONVERTER_SCRIPT_DIR"

# 解析命令行参数

# 先解析命令行参数（如果提供）
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    unified_parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi
REQUESTED_CLUSTER="${CLUSTER:-}"

# 加载部署配置文件（标准结构：app/deploy-app/deploy-document-converter-backend.conf）
DOCUMENT_CONVERTER_BFF_CONFIG_FILE="$SCRIPT_DIR/deploy-document-converter-backend.conf"
[[ -f "$DOCUMENT_CONVERTER_BFF_CONFIG_FILE" && ! -L "$DOCUMENT_CONVERTER_BFF_CONFIG_FILE" ]] || {
    log_error 'Document Converter 当前部署配置缺失或为软链接'; exit 1;
}
source "$DOCUMENT_CONVERTER_BFF_CONFIG_FILE" >/dev/null 2>&1 || {
    log_error 'Document Converter 部署配置读取失败'; exit 1;
}
source "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh" || exit 1
apply_cluster_config_mapping || exit 1
log_info "已加载 Document Converter 配置: $DOCUMENT_CONVERTER_BFF_CONFIG_FILE"

# 默认配置从配置文件读取（deploy-document-converter-backend.conf）
# 如果配置文件未设置，则使用空值（由函数参数默认值处理）
DEFAULT_PROJECT_ID="${DOCUMENT_CONVERTER_BFF_PROJECT_ID:-}"
DEFAULT_NAMESPACE="${DOCUMENT_CONVERTER_BFF_NAMESPACE:-}"
DEFAULT_ENVIRONMENT="${ENVIRONMENT:-}"

# 资源文件路径（对齐项目结构）
# 从 app/deploy-app/ 向上 3 级到达应用根目录（document-converter-backend/）
# app/deploy-app/ -> app/ -> deploy-document-converter-backend/ -> document-converter-backend/
RESOURCES_DIR="$APP_ROOT/resources"
# 使用生成的 YAML 文件（由各组件自己的 generate-*.sh 生成）
# YAML 文件现在分散在各组件的 generate-* 目录下
K8S_RESOURCE_DIR="${RESOURCES_DIR}/k8s-resource"
DOCUMENT_CONVERTER_BFF_YAML="${K8S_RESOURCE_DIR}/custom-values/app/generate-app/document-converter-backend-generated.yaml"
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
    
    local _ns_err
    _ns_err=$(kubectl get namespace "$namespace" 2>&1)
    if [[ $? -eq 0 ]]; then
        log_success "✅ 命名空间 $namespace 已存在"
        return 0
    elif echo "$_ns_err" | grep -qiE "not.?found|NotFound"; then
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
    else
        log_warn "kubectl 连接失败，尝试自动重连后重试（${_ns_err%%$'\n'*}）"
        if command -v setup_kubectl_environment >/dev/null 2>&1 && setup_kubectl_environment >/dev/null 2>&1; then
            if kubectl get namespace "$namespace" >/dev/null 2>&1; then
                log_success "✅ 重连后命名空间 $namespace 已存在"
                return 0
            fi
        fi
        log_error "❌ kubectl 连接失败，无法验证命名空间 $namespace（${_ns_err%%$'\n'*}）"
        log_error "请检查 KUBECONFIG 和集群连接状态"
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
    local component_type="$1" project_id="$2" namespace="$3" environment="$4"
    local dry_run="${5:-false}" operation="${6:-deploy}" base_dir="$PROJECT_ROOT/$1"
    local script_file conf_file dirname prefix settings enabled priority
    local -a components=() sorted_components=()
    case "$operation" in deploy|uninstall) ;; *) return 2 ;; esac
    # These categories have a direct entry, rather than a nested per-resource directory.
    case "$component_type" in
        ingress) script_file="$base_dir/deploy-ingress/deploy-ingress.sh" ;;
        middleware) script_file="$base_dir/deploy-middleware-all/deploy-middleware-all.sh" ;;
        *) script_file='' ;;
    esac
    if [[ -n "$script_file" ]]; then
        [[ -f "$script_file" ]] || { log_error "启用的组件入口缺失: $component_type"; return 1; }
        DISABLE_AUTO_CLEANUP=true bash "$script_file" "$operation" "$project_id" "$namespace" "$environment" "$dry_run"
        return $?
    fi
    [[ -d "$base_dir" ]] || { log_error "启用的组件目录缺失: $component_type"; return 1; }
    local subdir
    for subdir in "$base_dir"/*/; do
        [[ -d "$subdir" ]] || continue
        dirname="$(basename "$subdir")"
        [[ "$dirname" != deploy-*-all ]] || continue
        script_file="$subdir/deploy-$dirname/deploy-$dirname.sh"
        conf_file="$subdir/deploy-$dirname/deploy-$dirname.conf"
        case "$dirname" in
            dc-secret) prefix=document_converter_secret ;;
            dc-config) prefix=document_converter_config ;;
            dc-backend-ns) prefix=document_converter_bff_namespace ;;
            *) prefix="${dirname//-/_}" ;;
        esac
        [[ "$prefix" =~ ^[a-zA-Z_][a-zA-Z_0-9]*$ && -f "$conf_file" ]] || { log_error '子组件配置缺失或名字不合法'; return 1; }
        # Read controls in a subshell: child NAMESPACE/PROJECT_ID must not overwrite the parent target.
        settings=$(
            set +x
            source "$conf_file" >/dev/null 2>&1 || exit 1
            apply_cluster_config_mapping >/dev/null || exit 1
            enabled_var="${prefix}_enabled"; priority_var="${prefix}_priority"
            printf '%s %s' "${!enabled_var:-true}" "${!priority_var:-100}"
        ) || { log_error '子组件配置读取失败'; return 1; }
        read -r enabled priority <<< "$settings"
        [[ "$enabled" == true || "$enabled" == false ]] || { log_error '组件 enabled 必须为 true/false'; return 1; }
        [[ "$priority" =~ ^[0-9]+$ ]] || { log_error '组件 priority 必须为非负整数'; return 1; }
        [[ "$enabled" == true ]] || { log_info "跳过已禁用组件: $dirname"; continue; }
        [[ -f "$script_file" ]] || { log_error "启用的组件脚本缺失: $dirname"; return 1; }
        components+=("$priority"$'\t'"$dirname"$'\t'"$script_file")
    done
    [[ ${#components[@]} -gt 0 ]] || { log_info "没有启用的 $component_type 子组件"; return 0; }
    local order=-nr sorted line
    [[ "$operation" != uninstall ]] || order=-n
    sorted=$(printf '%s\n' "${components[@]}" | LC_ALL=C sort -t $'\t' -k1,1 "$order") || return 1
    mapfile -t sorted_components <<< "$sorted"
    for line in "${sorted_components[@]}"; do
        IFS=$'\t' read -r priority dirname script_file <<< "$line"
        log_info "$operation $dirname (priority=$priority)"
        DISABLE_AUTO_CLEANUP=true bash "$script_file" "$operation" "$project_id" "$namespace" "$environment" "$dry_run" || return $?
    done
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
    if [[ "$yaml_file" == *"document-converter-backend-generated.yaml" ]] && [[ "$yaml_file" != *"config"* ]] && [[ "$yaml_file" != *"secret"* ]] && [[ "$yaml_file" != *"pvc"* ]] && [[ "$yaml_file" != *"ingress"* ]]; then
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
        export NAMESPACE="${NAMESPACE:-${DOCUMENT_CONVERTER_BFF_NAMESPACE:-app-platform-dev}}"
        export ENVIRONMENT="${ENVIRONMENT:-development}"
        export ENV="${ENV:-dev}"
        export PROJECT_ID="${PROJECT_ID:-${DOCUMENT_CONVERTER_BFF_PROJECT_ID:-sunmoonai}}"
        
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
    if [[ "${secrets_enabled:-true}" == "true" ]] || [[ "${configmap_enabled:-true}" == "true" ]]; then
        # 检查 ConfigMap 和 Secret 的部署脚本
        local secrets_dir="$PROJECT_ROOT/secret"
        local configmap_dir="$PROJECT_ROOT/configMap"
        local config_script="$configmap_dir/dc-config/deploy-dc-config/deploy-dc-config.sh"
        local secret_script="$secrets_dir/dc-secret/deploy-dc-secret/deploy-dc-secret.sh"
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
    export DOCUMENT_CONVERTER_IMAGE_REGISTRY="${DOCUMENT_CONVERTER_IMAGE_REGISTRY:-$(get_cluster_harbor_registry)}"
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

    if ! python3 -B "$K8S_ROOT_DIR/sunmoonai/registry-platform/images.py" check \
        --image "$DOCUMENT_CONVERTER_BFF_FULL_IMAGE_NAME" --apply; then
        return 1
    fi
    
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
        sunmoon_deploy_target_check "$K8S_ROOT_DIR" || return 1
        kubectl apply -f "$DOCUMENT_CONVERTER_BFF_PVC_YAML" -n "$NAMESPACE" || return 1
        if [ $? -eq 0 ]; then
            log_success "PVC 部署完成"
        else
            log_error "PVC 部署失败"
            return 1
        fi
    fi
    
    # 部署 Deployment 和 Service（直接使用生成的 YAML）
    sunmoon_deploy_target_check "$K8S_ROOT_DIR" || return 1
    kubectl apply -f "$DOCUMENT_CONVERTER_BFF_YAML" -n "$NAMESPACE" || return 1
    
        if [ $? -eq 0 ]; then
        log_success "Document Converter BFF 部署完成！"
        echo ""
        log_info "检查部署状态:"
        echo "  kubectl get pods -n $NAMESPACE -l app=document-converter-backend"
        echo "  kubectl get svc -n $NAMESPACE -l app=document-converter-backend"
        echo ""
        log_info "查看 Pod 日志:"
        echo "  kubectl logs -n $NAMESPACE -l app=document-converter-backend -f"
    else
        log_error "Document Converter BFF 部署失败"
        exit 1
    fi
}


# 卸载 Document Converter BFF
uninstall_app() {
    log_info "开始卸载 Document Converter BFF..."
    log_info "环境: $ENVIRONMENT, 命名空间: $NAMESPACE"
    
    sunmoon_deploy_target_check "$K8S_ROOT_DIR" || return 1
    kubectl delete deployment document-converter -n "$NAMESPACE" --ignore-not-found=true || return 1
    sunmoon_deploy_target_check "$K8S_ROOT_DIR" || return 1
    kubectl delete service document-converter -n "$NAMESPACE" --ignore-not-found=true || return 1
    log_success "✅ Document Converter BFF 核心服务卸载完成"
    
    # ============================================================
    # 阶段2：卸载子级组件（按优先级，逆序卸载）
    # 注意：Namespace 应该在最后卸载，因为删除 namespace 会删除其中的所有资源
    # ============================================================
    log_info "🚀 阶段2：卸载 Document Converter BFF 子级组件..."
    if ! uninstall_sub_components "$PROJECT_ID" "$NAMESPACE" "$ENVIRONMENT" false; then
        log_error "Document Converter BFF 子级组件卸载失败"
        return 1
    fi
    log_success "✅ Document Converter BFF 子级组件卸载完成"
    
    # ============================================================
    # 阶段3：卸载 Namespace（最后卸载，需要用户确认）
    # 注意：删除 namespace 会删除其中的所有资源，需要谨慎操作
    # ============================================================
    if [[ "${namespace_enabled:-true}" == "true" ]]; then
        log_warn "⚠️  注意：卸载 Namespace 将删除命名空间 $NAMESPACE 及其中的所有资源！"
        log_info "如需卸载 Namespace，请手动执行："
        log_info "  cd deploy-document-converter-backend/namespace/dc-backend-ns/deploy-dc-backend-ns"
        log_info "  ./deploy-dc-backend-ns.sh uninstall $PROJECT_ID $NAMESPACE $ENVIRONMENT"
    fi
    
    log_success "Document Converter BFF 卸载完成！"
}

# 卸载子组件（按优先级，逆序）
uninstall_sub_components() {
    local project_id="$1" namespace="$2" environment="$3" dry_run="$4"
    local category flag
    # Reverse the dependency order; namespace/PVC are retained.
    for category in ingress middleware configMap secret; do
        case "$category" in
            ingress) flag="${ingress_enabled:-false}" ;;
            middleware) flag="${middleware_enabled:-false}" ;;
            configMap) flag="${configmap_enabled:-true}" ;;
            secret) flag="${secrets_enabled:-true}" ;;
        esac
        [[ "$flag" == true || "$flag" == false ]] || { log_error '组件总开关必须为 true/false'; return 1; }
        [[ "$flag" == true ]] || continue
        scan_and_deploy_components "$category" "$project_id" "$namespace" "$environment" "$dry_run" uninstall || return $?
    done
}

# 显示状态
show_status() {
    log_info "Document Converter BFF 状态:"
    echo ""
    echo "📦 Pods:"
    kubectl get pods -n "$NAMESPACE" -l app=document-converter-backend || return 1
    echo ""
    echo "🌐 Services:"
    kubectl get svc -n "$NAMESPACE" -l app=document-converter-backend || return 1
    echo ""
    echo "📋 Deployments:"
    kubectl get deployment -n "$NAMESPACE" -l app=document-converter-backend || return 1
    echo ""
    echo "📋 ConfigMaps:"
    kubectl get configmap -n "$NAMESPACE" -l app=document-converter-backend || return 1
    echo ""
    echo "🔐 Secrets:"
    kubectl get secret -n "$NAMESPACE" -l app=document-converter-backend || return 1
    echo ""
    echo "📦 PVCs:"
    kubectl get pvc -n "$NAMESPACE" -l app=document-converter-backend || return 1
}

# 主函数
main() {
    # 使用解析后的参数（已移除 --cluster 参数）
    set -- "${ORIGINAL_ARGS[@]}"
    
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
    
    case "$ACTION" in
        deploy|uninstall|status) ;;
        *) log_error '支持的操作: deploy, uninstall, status'; return 2 ;;
    esac
    [[ "$REQUESTED_CLUSTER" =~ ^(KIND|C[1-9][0-9]*)$ && "$CLUSTER" == "$REQUESTED_CLUSTER" ]] || {
        log_error '必须显式指定集群，且配置不得改变选择'; return 1;
    }
    [[ "$NAMESPACE" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ && ${#NAMESPACE} -le 63 ]] || {
        log_error '必须指定合法的 namespace'; return 1;
    }
    local flag
    for flag in namespace_enabled secrets_enabled configmap_enabled middleware_enabled ingress_enabled; do
        [[ ! -v "$flag" || "${!flag}" == true || "${!flag}" == false ]] || {
            log_error '组件总开关必须为 true/false'; return 1;
        }
    done
    sunmoon_deploy_target_init "$K8S_ROOT_DIR" || return 1
    check_kubectl
    case "$ACTION" in
        deploy)
            if [[ "${namespace_enabled:-true}" != true ]]; then check_namespace "$NAMESPACE" || return 1; fi
            deploy_app || return 1 ;;
        uninstall) uninstall_app || return 1 ;;
        status) show_status || return 1 ;;
    esac
}

# 执行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
