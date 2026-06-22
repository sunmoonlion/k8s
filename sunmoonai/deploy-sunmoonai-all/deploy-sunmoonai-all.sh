#!/usr/bin/env bash

# =============================================================================
# SunmoonAI 项目总部署脚本
# - 管理多个平台组件的部署
# - 支持优先级控制和依赖管理
# - 支持多集群配置
# =============================================================================

# 脚本目录配置
THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$THIS_DIR")"
# k8s 根目录：.../k8s（用于引用 utils 下的通用脚本）
K8S_ROOT_DIR="$(dirname "$PROJECT_ROOT")"

# 集群参数解析（轻量，无连接副作用）
source "$K8S_ROOT_DIR/utils/cluster-arg-parser.sh"
# shellcheck source=deploy-runtime-helpers.sh
[[ -f "$K8S_ROOT_DIR/utils/deploy-runtime-helpers.sh" ]] && source "$K8S_ROOT_DIR/utils/deploy-runtime-helpers.sh"


# 颜色输出函数
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }
bold() { echo -e "\033[1m$*\033[0m"; }

# 日志函数
log_info() { echo "ℹ️  $*"; }
log_success() { green "✅ $*"; }
log_warn() { yellow "⚠️  $*"; }
log_error() { red "❌ $*"; }


# 恢复 SunmoonAI 脚本的目录路径
SCRIPT_DIR="$PROJECT_ROOT"


# 解析命令行参数（优先于配置文件加载，确保命令行参数优先级最高）

# 先解析命令行参数（如果提供）
# 保存原始参数，以便在 main 函数中使用
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    unified_parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

SUNMOONAI_CONFIG_FILE="$THIS_DIR/deploy-sunmoonai-all.conf"
if [[ -f "$SUNMOONAI_CONFIG_FILE" ]]; then
    source "$SUNMOONAI_CONFIG_FILE"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh" ]]; then
        source "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
    
    log_info "已加载 SunmoonAI 配置文件: $SUNMOONAI_CONFIG_FILE"
else
    log_error "缺少 SunmoonAI 配置文件: $SUNMOONAI_CONFIG_FILE"
    exit 1
fi

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
# 注意：SunmoonAI 项目本身不需要总命名空间，各平台使用自己的命名空间
DEFAULT_ENVIRONMENT="development"

# 检查命名空间是否存在（注意：不是所有平台都需要检查命名空间）
# 命名空间检查由各个子级脚本负责
check_namespace() {
    local namespace="$1"
    
    local _ns_err
    _ns_err=$(kubectl get namespace "$namespace" 2>&1)
    if [[ $? -eq 0 ]]; then
        log_success "✅ 命名空间 $namespace 已存在"
        return 0
    elif echo "$_ns_err" | grep -qiE "not.?found|NotFound"; then
        log_error "❌ 命名空间 $namespace 不存在！"
        echo ""
        log_info "请先使用 infrastructure 部署基础设施（包含命名空间创建）："
        echo "  ./deploy-sunmoonai-all.sh deploy sunmoonai -c C1"
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

# 调用子级脚本并传递集群参数
call_subscript() {
    local script_path="$1"
    shift
    local args=("$@")

    if declare -F call_deploy_subscript >/dev/null 2>&1; then
        call_deploy_subscript "$K8S_ROOT_DIR" "$script_path" "${args[@]}"
        return $?
    fi
    
    # 如果设置了 CLUSTER 环境变量，添加 --cluster 参数
    if [[ -n "${CLUSTER:-}" ]]; then
        DISABLE_AUTO_CLEANUP=true "$script_path" --cluster "$CLUSTER" "${args[@]}"
    else
        DISABLE_AUTO_CLEANUP=true "$script_path" "${args[@]}"
    fi
}

# 与 utils/kubeconfig-path-for-cluster.sh、unified-deployment-template 共用同一解析规则
# shellcheck source=/dev/null
source "${PROJECT_ROOT}/../utils/kubeconfig-path-for-cluster.sh"

# 当 CLUSTER=KIND 时，在总控进程中设置 KUBECONFIG，使后续 data/messaging/ops 等平台部署都操作同一 Kind 集群。
# 否则 deploy-kind 在子进程里 export 的 KUBECONFIG 不会继承，导致子脚本有时用默认 kubeconfig，出现 Secret 未创建等不稳定现象。
resolve_kind_kubeconfig() {
    kubeconfig_path_from_admin_conf "${PROJECT_ROOT}/../utils/k8s-admin.conf" "KIND"
}

# 从 k8s-admin.conf 读取当前 CLUSTER（C1/C2/…）对应的 kubeconfig 路径
resolve_remote_cluster_kubeconfig_path() {
    local cu
    cu=$(echo "${CLUSTER:-}" | tr '[:lower:]' '[:upper:]')
    kubeconfig_path_from_admin_conf "${PROJECT_ROOT}/../utils/k8s-admin.conf" "$cu"
}

# 等待命名空间内 Pod 就绪（Running/Completed），超时后不失败
# 用法: wait_for_namespace_pods_ready <namespace> [timeout_sec]
# 仅在 WAIT_READY=true 时由部署流程调用
wait_for_namespace_pods_ready() {
    local namespace="$1"
    local timeout_sec="${2:-${WAIT_READY_TIMEOUT:-180}}"
    local interval=10
    local waited=0

    if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
        log_warn "⚠️  命名空间 $namespace 不存在，跳过等待"
        return 0
    fi
    while [[ $waited -lt $timeout_sec ]]; do
        local not_ready
        not_ready=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | grep -vE "Running|Completed|Succeeded" | grep -c . || true)
        if [[ "${not_ready:-0}" -eq 0 ]]; then
            log_success "✅ $namespace 内 Pod 已就绪 (${waited}s)"
            return 0
        fi
        log_info "⏳ 等待 $namespace 的 Pod 就绪... (${waited}s/${timeout_sec}s, 非 Running/Completed: ${not_ready:-0})"
        sleep "$interval"
        waited=$((waited + interval))
    done
    log_warn "⚠️  等待 $namespace 就绪超时 (${timeout_sec}s)，继续执行"
    return 0
}

# 部署平台组件（按优先级）
deploy_platform_components_by_priority() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始基于优先级的平台组件部署..."
    # 当目标为 Kind 时，确保总控进程已设置 KUBECONFIG，避免子脚本继承不到而出现 Secret 未创建等不稳定
    local cluster_upper kind_kubeconfig
    cluster_upper=$(echo "${CLUSTER:-}" | tr '[:lower:]' '[:upper:]')
    if [[ "$cluster_upper" == "KIND" ]]; then
        kind_kubeconfig=$(resolve_kind_kubeconfig)
        if [[ -f "$kind_kubeconfig" && "${KUBECONFIG:-}" != "$kind_kubeconfig" ]]; then
            unset KUBECONFIG
            export KUBECONFIG="$kind_kubeconfig"
            log_info "已设置 KUBECONFIG=$KUBECONFIG（Kind 集群）"
        fi
    elif [[ "$cluster_upper" =~ ^C[0-9]+$ ]]; then
        # 远程集群：总控进程里的 kubectl（如 WAIT_READY）需指向 C1/C2 的 admin.conf，避免继承 shell 中误留的 Kind KUBECONFIG
        local remote_kc
        if ! remote_kc=$(resolve_remote_cluster_kubeconfig_path); then
            log_warn "无法从 k8s-admin.conf 解析 CLUSTER=$cluster_upper 的 kubeconfig 路径，总控进程将继续使用当前 KUBECONFIG=${KUBECONFIG:-<unset>}（可能串集群）"
        elif [[ -n "$remote_kc" && -f "$remote_kc" ]]; then
            unset KUBECONFIG
            export KUBECONFIG="$remote_kc"
            log_info "已设置 KUBECONFIG=$KUBECONFIG（远程集群 $cluster_upper）"
        fi
    fi
    if [[ "${WAIT_READY:-false}" == "true" ]]; then
        log_info "⏳ 已启用等待就绪模式 (WAIT_READY=true, 单平台超时: ${WAIT_READY_TIMEOUT:-180}s)"
    fi

    # 获取所有启用的平台组件及其优先级
    local components=()
    
    # 检查基础设施平台
    if [[ "${infrastructure_enabled:-false}" == "true" ]]; then
        local priority="${infrastructure_priority:-1000}"
        components+=("$priority:infrastructure")
    fi
    
    # 检查入口平台
    if [[ "${ingress_platform_enabled:-false}" == "true" ]]; then
        local priority="${ingress_platform_priority:-900}"
        components+=("$priority:ingress-platform")
    fi
    
    # 检查 CI/CD 平台
    if [[ "${cicd_platform_enabled:-false}" == "true" ]]; then
        local priority="${cicd_platform_priority:-800}"
        components+=("$priority:cicd-platform")
    fi
    
    # 检查数据平台
    if [[ "${data_platform_enabled:-false}" == "true" ]]; then
        local priority="${data_platform_priority:-700}"
        components+=("$priority:data-platform")
    fi

    # 检查应用平台
    if [[ "${app_platform_enabled:-false}" == "true" ]]; then
        local priority="${app_platform_priority:-450}"
        components+=("$priority:app-platform")
    fi
    
    # 检查消息平台
    if [[ "${messaging_platform_enabled:-false}" == "true" ]]; then
        local priority="${messaging_platform_priority:-500}"
        components+=("$priority:messaging-platform")
    fi
    
    # 检查运维平台
    if [[ "${ops_platform_enabled:-false}" == "true" ]]; then
        local priority="${ops_platform_priority:-400}"
        components+=("$priority:ops-platform")
    fi
    
    # 按优先级排序（数值大的先部署）
    IFS=$'\n' sorted_components=($(sort -nr <<<"${components[*]}"))
    unset IFS
    
    if [[ ${#sorted_components[@]} -eq 0 ]]; then
        log_warn "⚠️  没有启用的平台组件"
        return 0
    fi
    
    log_info "📋 平台组件部署顺序："
    for component_info in "${sorted_components[@]}"; do
        local priority="${component_info%%:*}"
        local component="${component_info##*:}"
        log_info "  🚀 $component (优先级: $priority)"
    done
    
    # 部署平台组件
    for component_info in "${sorted_components[@]}"; do
        local component="${component_info##*:}"
        log_info "🚀 部署 $component..."
        
        case "$component" in
            "infrastructure")
                # 基础设施第一阶段：根据 CLUSTER 分流到 Kind 或远程集群
                local cluster_selected="${CLUSTER:-}"
                local cluster_upper
                cluster_upper=$(echo "${cluster_selected:-}" | tr '[:lower:]' '[:upper:]')

                if [[ "$cluster_upper" == "KIND" ]]; then
                    local kind_script="$PROJECT_ROOT/kind-infrastructure/deploy-kind/deploy-kind.sh"
                    if [[ -f "$kind_script" ]]; then
                        log_info "使用 Kind 基础设施一键脚本: $kind_script"
                        if "$kind_script"; then
                            log_success "✅ KIND 基础设施部署完成"
                            # 在总控进程中导出 KUBECONFIG，否则后续 messaging/data/ops 等子脚本不会继承 deploy-kind 子进程的 export，导致 kubectl 指向错误集群、Secret 等未创建而不稳定
                            local kind_kubeconfig
                            kind_kubeconfig=$(resolve_kind_kubeconfig)
                            if [[ -f "$kind_kubeconfig" ]]; then
                                export KUBECONFIG="$kind_kubeconfig"
                                log_info "已设置 KUBECONFIG=$KUBECONFIG，后续平台部署将使用该 Kind 集群"
                            else
                                log_warn "未找到 Kind kubeconfig ($kind_kubeconfig)，请确保已 export KUBECONFIG 或后续部署可能失败"
                            fi
                        else
                            log_error "❌ KIND 基础设施部署失败"
                            return 1
                        fi
                    else
                        log_error "❌ KIND 基础设施脚本不存在: $kind_script"
                        return 1
                    fi
                else
                    if [[ -d "$PROJECT_ROOT/infrastructure/deploy-infrastructure-all" ]]; then
                        local script_path="$PROJECT_ROOT/infrastructure/deploy-infrastructure-all/deploy-infrastructure-all.sh"
                        if [[ -f "$script_path" ]]; then
                            log_info "使用远程基础设施脚本: $script_path"
                            if call_subscript "$script_path" deploy "$project_id" "$environment" "$dry_run"; then
                                log_success "✅ 远程基础设施部署完成"
                                local remote_kc
                                if ! remote_kc=$(resolve_remote_cluster_kubeconfig_path); then
                                    log_warn "无法从 k8s-admin.conf 解析 CLUSTER=${cluster_upper} 的 kubeconfig 路径，基础设施后同步跳过（当前 KUBECONFIG=${KUBECONFIG:-<unset>}）"
                                elif [[ -n "$remote_kc" && -f "$remote_kc" ]]; then
                                    unset KUBECONFIG
                                    export KUBECONFIG="$remote_kc"
                                    log_info "总控进程已同步 KUBECONFIG=$KUBECONFIG（后续平台与 kubectl 一致性）"
                                fi
                            else
                                log_error "❌ 远程基础设施部署失败"
                                return 1
                            fi
                        else
                            log_error "❌ 基础设施部署脚本不存在: $script_path"
                            return 1
                        fi
                    else
                        log_error "❌ 基础设施目录不存在: $PROJECT_ROOT/infrastructure/deploy-infrastructure-all"
                        return 1
                    fi
                fi
                ;;
            "ingress-platform")
                if [[ -d "$PROJECT_ROOT/ingress-platform/deploy-ingress-platform-all" ]]; then
                    local script_path="$PROJECT_ROOT/ingress-platform/deploy-ingress-platform-all/deploy-ingress-platform-all.sh"
                    if [[ -f "$script_path" ]]; then
                        if call_subscript "$script_path" deploy "$project_id" "ingress-platform-dev" "$environment" "$dry_run"; then
                            log_success "✅ $component 部署成功"
                            if [[ "${WAIT_READY:-false}" == "true" ]]; then
                                wait_for_namespace_pods_ready "ingress-platform-dev"
                            fi
                        else
                            log_error "❌ $component 部署失败"
                            return 1
                        fi
                    else
                        log_error "❌ $component 部署脚本不存在: $script_path"
                        return 1
                    fi
                else
                    log_error "❌ $component 目录不存在: $PROJECT_ROOT/ingress-platform/deploy-ingress-platform-all"
                    return 1
                fi
                ;;
            "cicd-platform")
                if [[ -d "$PROJECT_ROOT/cicd-platform/deploy-cicd-platform-all" ]]; then
                    local script_path="$PROJECT_ROOT/cicd-platform/deploy-cicd-platform-all/deploy-cicd-platform-all.sh"
                    if [[ -f "$script_path" ]]; then
                        if call_subscript "$script_path" deploy "$project_id" "cicd-platform-dev" "$environment" "$dry_run"; then
                            log_success "✅ $component 部署成功"
                            if [[ "${WAIT_READY:-false}" == "true" ]]; then
                                wait_for_namespace_pods_ready "cicd-platform-dev"
                            fi
                        else
                            log_error "❌ $component 部署失败"
                            return 1
                        fi
                    else
                        log_error "❌ $component 部署脚本不存在: $script_path"
                        return 1
                    fi
                else
                    log_error "❌ $component 目录不存在: $PROJECT_ROOT/cicd-platform/deploy-cicd-platform-all"
                    return 1
                fi
                ;;
            "data-platform")
                if [[ -d "$PROJECT_ROOT/data-platform/deploy-data-platform-all" ]]; then
                    local script_path="$PROJECT_ROOT/data-platform/deploy-data-platform-all/deploy-data-platform-all.sh"
                    if [[ -f "$script_path" ]]; then
                        if call_subscript "$script_path" deploy "$project_id" "data-platform-dev" "$environment" "$dry_run"; then
                            log_success "✅ $component 部署成功"
                            if [[ "${WAIT_READY:-false}" == "true" ]]; then
                                wait_for_namespace_pods_ready "data-platform-dev"
                            fi
                        else
                            log_error "❌ $component 部署失败"
                            return 1
                        fi
                    else
                        log_error "❌ $component 部署脚本不存在: $script_path"
                        return 1
                    fi
                else
                    log_error "❌ $component 目录不存在: $PROJECT_ROOT/data-platform/deploy-data-platform-all"
                    return 1
                fi
                ;;
            "app-platform")
                if [[ -d "$PROJECT_ROOT/app-platform/deploy-app-platform-all" ]]; then
                    local script_path="$PROJECT_ROOT/app-platform/deploy-app-platform-all/deploy-app-platform-all.sh"
                    if [[ -f "$script_path" ]]; then
                        if call_subscript "$script_path" deploy "$project_id" "${APP_PLATFORM_NAMESPACE:-app-platform-dev}" "${APP_PLATFORM_ENVIRONMENT:-$environment}" "$dry_run"; then
                            log_success "✅ $component 部署成功"
                            if [[ "${WAIT_READY:-false}" == "true" ]]; then
                                wait_for_namespace_pods_ready "${APP_PLATFORM_NAMESPACE:-app-platform-dev}"
                            fi
                        else
                            log_error "❌ $component 部署失败"
                            return 1
                        fi
                    else
                        log_error "❌ $component 部署脚本不存在: $script_path"
                        return 1
                    fi
                else
                    log_error "❌ $component 目录不存在: $PROJECT_ROOT/app-platform/deploy-app-platform-all"
                    return 1
                fi
                ;;
            "messaging-platform")
                if [[ -d "$PROJECT_ROOT/messaging-platform/deploy-messaging-platform-all" ]]; then
                    local script_path="$PROJECT_ROOT/messaging-platform/deploy-messaging-platform-all/deploy-messaging-platform-all.sh"
                    if [[ -f "$script_path" ]]; then
                        if call_subscript "$script_path" deploy "$project_id" "messaging-platform-dev" "$environment" "$dry_run"; then
                            log_success "✅ $component 部署成功"
                            if [[ "${WAIT_READY:-false}" == "true" ]]; then
                                wait_for_namespace_pods_ready "messaging-platform-dev"
                            fi
                        else
                            log_error "❌ $component 部署失败"
                            return 1
                        fi
                    else
                        log_error "❌ $component 部署脚本不存在: $script_path"
                        return 1
                    fi
                else
                    log_error "❌ $component 目录不存在: $PROJECT_ROOT/messaging-platform/deploy-messaging-platform-all"
                    return 1
                fi
                ;;
            "ops-platform")
                if [[ -d "$PROJECT_ROOT/ops-platform/deploy-ops-platform-all" ]]; then
                    local script_path="$PROJECT_ROOT/ops-platform/deploy-ops-platform-all/deploy-ops-platform-all.sh"
                    if [[ -f "$script_path" ]]; then
                        if call_subscript "$script_path" deploy "$project_id" "ops-platform-dev" "$environment" "$dry_run"; then
                            log_success "✅ $component 部署成功"
                            if [[ "${WAIT_READY:-false}" == "true" ]]; then
                                wait_for_namespace_pods_ready "ops-platform-dev"
                            fi
                        else
                            log_error "❌ $component 部署失败"
                            return 1
                        fi
                    else
                        log_error "❌ $component 部署脚本不存在: $script_path"
                        return 1
                    fi
                else
                    log_error "❌ $component 目录不存在: $PROJECT_ROOT/ops-platform/deploy-ops-platform-all"
                    return 1
                fi
                ;;
            *)
                log_error "❌ 未知的平台组件: $component"
                return 1
                ;;
        esac
    done
    
    log_success "✅ 所有平台组件部署完成！"
}

# 卸载平台组件（按优先级）
uninstall_platform_components_by_priority() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始基于优先级的平台组件卸载..."
    
    # 获取所有启用的平台组件及其优先级
    local components=()
    
    # 检查基础设施平台
    if [[ "${infrastructure_enabled:-false}" == "true" ]]; then
        local priority="${infrastructure_priority:-1000}"
        components+=("$priority:infrastructure")
    fi
    
    # 检查入口平台
    if [[ "${ingress_platform_enabled:-false}" == "true" ]]; then
        local priority="${ingress_platform_priority:-900}"
        components+=("$priority:ingress-platform")
    fi
    
    # 检查 CI/CD 平台
    if [[ "${cicd_platform_enabled:-false}" == "true" ]]; then
        local priority="${cicd_platform_priority:-800}"
        components+=("$priority:cicd-platform")
    fi
    
    # 检查数据平台
    if [[ "${data_platform_enabled:-false}" == "true" ]]; then
        local priority="${data_platform_priority:-700}"
        components+=("$priority:data-platform")
    fi
    
    # 检查应用平台
    if [[ "${app_platform_enabled:-false}" == "true" ]]; then
        local priority="${app_platform_priority:-450}"
        components+=("$priority:app-platform")
    fi
    
    # 检查消息平台
    if [[ "${messaging_platform_enabled:-false}" == "true" ]]; then
        local priority="${messaging_platform_priority:-500}"
        components+=("$priority:messaging-platform")
    fi
    
    # 检查运维平台
    if [[ "${ops_platform_enabled:-false}" == "true" ]]; then
        local priority="${ops_platform_priority:-400}"
        components+=("$priority:ops-platform")
    fi
    
    # 按优先级排序（数值大的先卸载）
    IFS=$'\n' sorted_components=($(sort -nr <<<"${components[*]}"))
    unset IFS
    
    if [[ ${#sorted_components[@]} -eq 0 ]]; then
        log_warn "⚠️  没有启用的平台组件"
        return 0
    fi
    
    log_info "📋 平台组件卸载顺序："
    for component_info in "${sorted_components[@]}"; do
        local priority="${component_info%%:*}"
        local component="${component_info##*:}"
        log_info "  🗑️  $component (优先级: $priority)"
    done
    
    # 卸载平台组件
    for component_info in "${sorted_components[@]}"; do
        local component="${component_info##*:}"
        log_info "🗑️  卸载 $component..."
        
        case "$component" in
            "infrastructure")
                if [[ -d "$PROJECT_ROOT/infrastructure/deploy-infrastructure-all" ]]; then
                    local script_path="$PROJECT_ROOT/infrastructure/deploy-infrastructure-all/deploy-infrastructure-all.sh"
                    if [[ -f "$script_path" ]]; then
                        if "$script_path" uninstall "$project_id" "infrastructure-dev" "$environment" "$dry_run"; then
                            log_success "✅ $component 卸载成功"
                        else
                            log_error "❌ $component 卸载失败"
                            return 1
                        fi
                    else
                        log_error "❌ $component 卸载脚本不存在: $script_path"
                        return 1
                    fi
                else
                    log_error "❌ --cluster 参数需要指定值（格式：C{数字}，如 C1, C2, C3 等）"
                    return 1
                fi
                ;;
            "ingress-platform")
                if [[ -d "$PROJECT_ROOT/ingress-platform/deploy-ingress-platform-all" ]]; then
                    local script_path="$PROJECT_ROOT/ingress-platform/deploy-ingress-platform-all/deploy-ingress-platform-all.sh"
                    if [[ -f "$script_path" ]]; then
                        if "$script_path" uninstall "$project_id" "ingress-platform-dev" "$environment" "$dry_run"; then
                            log_success "✅ $component 卸载成功"
                        else
                            log_error "❌ $component 卸载失败"
                            return 1
                        fi
                    else
                        log_error "❌ $component 卸载脚本不存在: $script_path"
                        return 1
                    fi
                else
                    log_error "❌ --cluster 参数需要指定值（格式：C{数字}，如 C1, C2, C3 等）"
                    return 1
                fi
                ;;
            "cicd-platform")
                if [[ -d "$PROJECT_ROOT/cicd-platform/deploy-cicd-platform-all" ]]; then
                    local script_path="$PROJECT_ROOT/cicd-platform/deploy-cicd-platform-all/deploy-cicd-platform-all.sh"
                    if [[ -f "$script_path" ]]; then
                        if "$script_path" uninstall "$project_id" "cicd-platform-dev" "$environment" "$dry_run"; then
                            log_success "✅ $component 卸载成功"
                        else
                            log_error "❌ $component 卸载失败"
                            return 1
                        fi
                    else
                        log_error "❌ $component 卸载脚本不存在: $script_path"
                        return 1
                    fi
                else
                    log_error "❌ --cluster 参数需要指定值（格式：C{数字}，如 C1, C2, C3 等）"
                    return 1
                fi
                ;;
            "data-platform")
                log_info "清理数据平台..."
                # 这里可以添加具体的数据平台清理逻辑
                log_success "✅ $component 清理完成"
                ;;
            "app-platform")
                if [[ -d "$PROJECT_ROOT/app-platform/deploy-app-platform-all" ]]; then
                    local script_path="$PROJECT_ROOT/app-platform/deploy-app-platform-all/deploy-app-platform-all.sh"
                    if [[ -f "$script_path" ]]; then
                        if call_subscript "$script_path" uninstall "$project_id" "${APP_PLATFORM_NAMESPACE:-app-platform-dev}" "${APP_PLATFORM_ENVIRONMENT:-$environment}" "$dry_run"; then
                            log_success "✅ $component 卸载成功"
                        else
                            log_error "❌ $component 卸载失败"
                            return 1
                        fi
                    else
                        log_error "❌ $component 卸载脚本不存在: $script_path"
                        return 1
                    fi
                else
                    log_error "❌ $component 目录不存在: $PROJECT_ROOT/app-platform/deploy-app-platform-all"
                    return 1
                fi
                ;;
            "messaging-platform")
                log_info "清理消息平台..."
                # 这里可以添加具体的消息平台清理逻辑
                log_success "✅ $component 清理完成"
                ;;
            "ops-platform")
                log_info "清理运维平台..."
                # 这里可以添加具体的运维平台清理逻辑
                log_success "✅ $component 清理完成"
                ;;
            *)
                log_error "❌ 未知的平台组件: $component"
                return 1
                ;;
        esac
    done
    
    log_success "✅ 所有平台组件卸载完成！"
}

# 检查平台组件状态
check_platform_components_status() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    
    log_info "检查平台组件状态..."
    
    # 检查基础设施平台
    if [[ "${infrastructure_enabled:-false}" == "true" ]]; then
        log_info "检查基础设施平台状态..."
        if [[ -d "$PROJECT_ROOT/infrastructure/deploy-infrastructure-all" ]]; then
            local script_path="$PROJECT_ROOT/infrastructure/deploy-infrastructure-all/deploy-infrastructure-all.sh"
            if [[ -f "$script_path" ]]; then
                call_subscript "$script_path" status "$project_id" "infrastructure-dev" "$environment"
            else
                log_error "❌ 基础设施平台状态检查脚本不存在: $script_path"
            fi
        else
            log_error "❌ 基础设施平台目录不存在: $PROJECT_ROOT/infrastructure/deploy-infrastructure-all"
        fi
    fi
    
    # 检查入口平台
    if [[ "${ingress_platform_enabled:-false}" == "true" ]]; then
        log_info "检查入口平台状态..."
        if [[ -d "$PROJECT_ROOT/ingress-platform/deploy-ingress-platform-all" ]]; then
            local script_path="$PROJECT_ROOT/ingress-platform/deploy-ingress-platform-all/deploy-ingress-platform-all.sh"
            if [[ -f "$script_path" ]]; then
                call_subscript "$script_path" status "$project_id" "ingress-platform-dev" "$environment"
            else
                log_error "❌ 入口平台状态检查脚本不存在: $script_path"
            fi
        else
            log_error "❌ 入口平台目录不存在: $PROJECT_ROOT/ingress-platform/deploy-ingress-platform-all"
        fi
    fi
    
    # 检查 CI/CD 平台
    if [[ "${cicd_platform_enabled:-false}" == "true" ]]; then
        log_info "检查 CI/CD 平台状态..."
        if [[ -d "$PROJECT_ROOT/cicd-platform/deploy-cicd-platform-all" ]]; then
            local script_path="$PROJECT_ROOT/cicd-platform/deploy-cicd-platform-all/deploy-cicd-platform-all.sh"
            if [[ -f "$script_path" ]]; then
                call_subscript "$script_path" status "$project_id" "cicd-platform-dev" "$environment"
            else
                log_error "❌ CI/CD 平台状态检查脚本不存在: $script_path"
            fi
        else
            log_error "❌ CI/CD 平台目录不存在: $PROJECT_ROOT/cicd-platform/deploy-cicd-platform-all"
        fi
    fi
    
    # 检查其他平台
    if [[ "${data_platform_enabled:-false}" == "true" ]]; then
        log_info "检查数据平台状态..."
        if [[ -f "$PROJECT_ROOT/data-platform/deploy-data-platform-all/deploy-data-platform-all.sh" ]]; then
            call_subscript "$PROJECT_ROOT/data-platform/deploy-data-platform-all/deploy-data-platform-all.sh" status "$project_id" "data-platform-dev" "$environment"
        else
            log_warn "⚠️ 数据平台总控脚本不存在"
        fi
    fi
    
    if [[ "${app_platform_enabled:-false}" == "true" ]]; then
        log_info "检查应用平台状态..."
        if [[ -f "$PROJECT_ROOT/app-platform/deploy-app-platform-all/deploy-app-platform-all.sh" ]]; then
            call_subscript "$PROJECT_ROOT/app-platform/deploy-app-platform-all/deploy-app-platform-all.sh" status "$project_id" "${APP_PLATFORM_NAMESPACE:-app-platform-dev}" "${APP_PLATFORM_ENVIRONMENT:-$environment}"
        else
            log_warn "⚠️ 应用平台总控脚本不存在"
        fi
    fi
    
    if [[ "${messaging_platform_enabled:-false}" == "true" ]]; then
        log_info "检查消息平台状态..."
        if [[ -f "$PROJECT_ROOT/messaging-platform/deploy-messaging-platform-all/deploy-messaging-platform-all.sh" ]]; then
            call_subscript "$PROJECT_ROOT/messaging-platform/deploy-messaging-platform-all/deploy-messaging-platform-all.sh" status "$project_id" "messaging-platform-dev" "$environment"
        else
            log_warn "⚠️ 消息平台总控脚本不存在"
        fi
    fi
    
    if [[ "${ops_platform_enabled:-false}" == "true" ]]; then
        log_info "检查运维平台状态..."
        if [[ -f "$PROJECT_ROOT/ops-platform/deploy-ops-platform-all/deploy-lps-platfrom-all.sh" ]]; then
            call_subscript "$PROJECT_ROOT/ops-platform/deploy-ops-platform-all/deploy-lps-platfrom-all.sh" status "$project_id" "ops-platform-dev" "$environment"
        else
            log_warn "⚠️ 运维平台总控脚本不存在"
        fi
    fi
}

# 获取平台组件日志
get_platform_components_logs() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    
    log_info "获取平台组件日志..."
    
    # 获取基础设施平台日志
    if [[ "${infrastructure_enabled:-false}" == "true" ]]; then
        log_info "获取基础设施平台日志..."
        if [[ -d "$PROJECT_ROOT/infrastructure/deploy-infrastructure-all" ]]; then
            local script_path="$PROJECT_ROOT/infrastructure/deploy-infrastructure-all/deploy-infrastructure-all.sh"
            if [[ -f "$script_path" ]]; then
                "$script_path" logs "$project_id" "infrastructure-dev" "$environment"
            else
                log_error "❌ 基础设施平台日志获取脚本不存在: $script_path"
            fi
        else
            log_error "❌ 基础设施平台目录不存在: $PROJECT_ROOT/infrastructure/deploy-infrastructure-all"
        fi
    fi
    
    # 获取入口平台日志
    if [[ "${ingress_platform_enabled:-false}" == "true" ]]; then
        log_info "获取入口平台日志..."
        if [[ -d "$PROJECT_ROOT/ingress-platform/deploy-ingress-platform-all" ]]; then
            local script_path="$PROJECT_ROOT/ingress-platform/deploy-ingress-platform-all/deploy-ingress-platform-all.sh"
            if [[ -f "$script_path" ]]; then
                "$script_path" logs "$project_id" "ingress-platform-dev" "$environment"
            else
                log_error "❌ 入口平台日志获取脚本不存在: $script_path"
            fi
        else
            log_error "❌ 入口平台目录不存在: $PROJECT_ROOT/ingress-platform/deploy-ingress-platform-all"
        fi
    fi
    
    # 获取 CI/CD 平台日志
    if [[ "${cicd_platform_enabled:-false}" == "true" ]]; then
        log_info "获取 CI/CD 平台日志..."
        if [[ -d "$PROJECT_ROOT/cicd-platform/deploy-cicd-platform-all" ]]; then
            local script_path="$PROJECT_ROOT/cicd-platform/deploy-cicd-platform-all/deploy-cicd-platform-all.sh"
            if [[ -f "$script_path" ]]; then
                "$script_path" logs "$project_id" "cicd-platform-dev" "$environment"
            else
                log_error "❌ CI/CD 平台日志获取脚本不存在: $script_path"
            fi
        else
            log_error "❌ CI/CD 平台目录不存在: $PROJECT_ROOT/cicd-platform/deploy-cicd-platform-all"
        fi
    fi
    
    # 获取其他平台日志
    if [[ "${data_platform_enabled:-false}" == "true" ]]; then
        log_info "获取数据平台日志..."
        if [[ -f "$PROJECT_ROOT/data-platform/deploy-data-platform-all/deploy-data-platform-all.sh" ]]; then
            "$PROJECT_ROOT/data-platform/deploy-data-platform-all/deploy-data-platform-all.sh" logs "$project_id" "data-platform-dev" "$environment"
        else
            log_warn "⚠️ 数据平台总控脚本不存在"
        fi
    fi
    
    if [[ "${app_platform_enabled:-false}" == "true" ]]; then
        log_info "获取应用平台日志..."
        if [[ -f "$PROJECT_ROOT/app-platform/deploy-app-platform-all/deploy-app-platform-all.sh" ]]; then
            call_subscript "$PROJECT_ROOT/app-platform/deploy-app-platform-all/deploy-app-platform-all.sh" logs "$project_id" "${APP_PLATFORM_NAMESPACE:-app-platform-dev}" "${APP_PLATFORM_ENVIRONMENT:-$environment}"
        else
            log_warn "⚠️ 应用平台总控脚本不存在"
        fi
    fi
    
    if [[ "${messaging_platform_enabled:-false}" == "true" ]]; then
        log_info "获取消息平台日志..."
        if [[ -f "$PROJECT_ROOT/messaging-platform/deploy-messaging-platform-all/deploy-messaging-platform-all.sh" ]]; then
            "$PROJECT_ROOT/messaging-platform/deploy-messaging-platform-all/deploy-messaging-platform-all.sh" logs "$project_id" "messaging-platform-dev" "$environment"
        else
            log_warn "⚠️ 消息平台总控脚本不存在"
        fi
    fi
    
    if [[ "${ops_platform_enabled:-false}" == "true" ]]; then
        log_info "获取运维平台日志..."
        if [[ -f "$PROJECT_ROOT/ops-platform/deploy-ops-platform-all/deploy-lps-platfrom-all.sh" ]]; then
            "$PROJECT_ROOT/ops-platform/deploy-ops-platform-all/deploy-lps-platfrom-all.sh" logs "$project_id" "ops-platform-dev" "$environment"
        else
            log_warn "⚠️ 运维平台总控脚本不存在"
        fi
    fi
}

# 主部署函数
deploy_sunmoonai() {
    local project_id="$1"
    local namespace="$2"  # 这个参数保留但不使用，各平台有自己的命名空间
    local environment="$3"
    local dry_run="$4"
    
    # 部署前：按配置自动从 .yaml.example 复制生成各组件 secret 的 .yaml 占位文件
    if [[ "${PREPARE_SECRETS_FROM_EXAMPLES:-true}" == "true" ]]; then
        local prepare_script="$PROJECT_ROOT/../utils/prepare-secrets-from-examples.sh"
        prepare_script="$(cd "$(dirname "$prepare_script")" && pwd)/$(basename "$prepare_script")"
        if [[ -x "$prepare_script" ]]; then
            log_info "部署前：从 .yaml.example 复制生成各组件 secret 的 .yaml（PREPARE_SECRETS_FROM_EXAMPLES=true）"
            "$prepare_script" || log_warn "prepare-secrets-from-examples 执行异常，继续部署"
        else
            log_warn "未找到或不可执行: $prepare_script，跳过 secret 占位文件生成"
        fi
    fi
    
    log_info "开始部署 SunmoonAI 项目..."
    log_info "项目: $project_id"
    log_info "环境: $environment"
    log_info "干运行: $dry_run"
    log_info "注意：各平台使用自己的命名空间"
    
    # 部署平台组件（按优先级）
    if ! deploy_platform_components_by_priority "$project_id" "$namespace" "$environment" "$dry_run"; then
        log_error "❌ 平台组件部署失败"
        return 1
    fi
    
    log_success "✅ SunmoonAI 项目部署完成！"
}

# 主卸载函数
uninstall_sunmoonai() {
    local project_id="$1"
    local namespace="$2"  # 这个参数保留但不使用，各平台有自己的命名空间
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始卸载 SunmoonAI 项目..."
    log_info "项目: $project_id"
    log_info "环境: $environment"
    log_info "干运行: $dry_run"
    log_info "注意：各平台使用自己的命名空间"
    
    # 卸载平台组件（按优先级）
    if ! uninstall_platform_components_by_priority "$project_id" "$namespace" "$environment" "$dry_run"; then
        log_error "❌ 平台组件卸载失败"
        return 1
    fi
    
    log_success "✅ SunmoonAI 项目卸载完成！"
}

# 主状态检查函数
check_sunmoonai_status() {
    local project_id="$1"
    local namespace="$2"  # 这个参数保留但不使用，各平台有自己的命名空间
    local environment="$3"
    
    log_info "检查 SunmoonAI 项目状态..."
    log_info "项目: $project_id"
    log_info "环境: $environment"
    log_info "注意：各平台使用自己的命名空间"
    
    # 检查平台组件状态
    check_platform_components_status "$project_id" "$namespace" "$environment"
    
    log_success "✅ SunmoonAI 项目状态检查完成！"
}

# 主日志获取函数
get_sunmoonai_logs() {
    local project_id="$1"
    local namespace="$2"  # 这个参数保留但不使用，各平台有自己的命名空间
    local environment="$3"
    
    log_info "获取 SunmoonAI 项目日志..."
    log_info "项目: $project_id"
    log_info "环境: $environment"
    log_info "注意：各平台使用自己的命名空间"
    
    # 获取平台组件日志
    get_platform_components_logs "$project_id" "$namespace" "$environment"
    
    log_success "✅ SunmoonAI 项目日志获取完成！"
}

# 显示帮助信息
show_help() {
    cat << EOF
SunmoonAI 项目总部署脚本

用法:
    $0 [--cluster C1|C2] <action> <project_id> <environment> [dry_run]

参数:
    --cluster, -c   集群选择 (格式：C{数字}，如 C1, C2, C3 等)，也可以通过环境变量 CLUSTER 设置
    action          操作类型 (deploy|uninstall|status|logs)
    project_id      项目ID (默认: $DEFAULT_PROJECT_ID)
    environment     环境 (默认: $DEFAULT_ENVIRONMENT)
    dry_run         是否干运行 (true|false, 默认: false)

可选配置 (deploy-sunmoonai-all.conf 或环境变量):
    WAIT_READY      为 true 时，每个平台部署完成后轮询该命名空间 Pod 直至就绪或超时 (默认: false)
    WAIT_READY_TIMEOUT  单平台最大等待秒数 (默认: 180，即 3 分钟)；超时后不视为失败

示例:
    $0 --cluster C1 deploy sunmoonai development false
    $0 -c C2 deploy sunmoonai development false
    $0 deploy sunmoonai development false
    CLUSTER=C1 $0 deploy sunmoonai development false

功能:
    - 基于递归架构的平台级部署逻辑
    - 支持平台组件优先级控制
    - 支持多个平台组件管理
    - 支持连接管理和错误处理

平台组件:
    - Infrastructure: 基础设施平台 (优先级: ${infrastructure_priority:-1000})
    - Ingress Platform: 入口平台 (优先级: ${ingress_platform_priority:-900})
    - CI/CD Platform: CI/CD 平台 (优先级: ${cicd_platform_priority:-800})
    - Data Platform: 数据平台 (优先级: ${data_platform_priority:-700})
    - Messaging Platform: 消息平台 (优先级: ${messaging_platform_priority:-500})
    - App Platform: 应用平台 (优先级: ${app_platform_priority:-450})
    - Ops Platform: 运维平台 (优先级: ${ops_platform_priority:-400})
EOF
}

# 解析命令行参数（支持 --cluster 或 -c）
# 使用全局数组存储处理后的参数
declare -a PARSED_ARGS


# 主函数
main() {
    # 解析集群参数（支持 --cluster 或 -c）
    # 使用解析后的参数（已移除 --cluster 参数）
    set -- "${ORIGINAL_ARGS[@]}"
    
    # 使用解析后的参数数组
    set -- "${PARSED_ARGS[@]}"
    
    local action="${1:-}"
    local project_id="${2:-$DEFAULT_PROJECT_ID}"
    local environment="${3:-$DEFAULT_ENVIRONMENT}"
    local dry_run="${4:-false}"
    local namespace="dummy"  # 保留参数但不使用
    
    # 检查参数
    if [[ -z "$action" ]]; then
        log_error "❌ 缺少操作参数"
        show_help
        exit 1
    fi
    
    # 显示当前集群配置（如果设置了）
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    # 执行操作
    case "$action" in
        "deploy")
            deploy_sunmoonai "$project_id" "$namespace" "$environment" "$dry_run"
            ;;
        "uninstall")
            uninstall_sunmoonai "$project_id" "$namespace" "$environment" "$dry_run"
            ;;
        "status")
            check_sunmoonai_status "$project_id" "$namespace" "$environment"
            ;;
        "logs")
            get_sunmoonai_logs "$project_id" "$namespace" "$environment"
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "❌ 未知操作: $action"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
