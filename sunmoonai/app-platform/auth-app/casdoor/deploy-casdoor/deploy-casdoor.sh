#!/bin/bash

# Casdoor 部署脚本
# 使用官方 Helm chart：https://casdoor.github.io/casdoor-helm
# 部署到 app-platform-dev 命名空间

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 保存脚本目录（统一模板会重新定义 SCRIPT_DIR）
CASDOOR_SCRIPT_DIR="$SCRIPT_DIR"

# 导入统一部署模板（相对路径：auth-app/casdoor/ → app-platform/ → sunmoonai/ → k8s/ → utils/）
source "$PROJECT_ROOT/../../../../utils/unified-deployment-template.sh"

# 恢复脚本目录
SCRIPT_DIR="$CASDOOR_SCRIPT_DIR"

# 解析命令行参数
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    if type unified_parse_cluster_arg >/dev/null 2>&1; then
        unified_parse_cluster_arg "$@"
        ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
    fi
fi

CASDOOR_CONFIG_FILE="$SCRIPT_DIR/deploy-casdoor.conf"
if [[ -f "$CASDOOR_CONFIG_FILE" ]]; then
    source "$CASDOOR_CONFIG_FILE"

    if [[ -f "$PROJECT_ROOT/../../../../utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/../../../../utils/cluster-config-mapping.sh"
        apply_cluster_config_mapping
    fi
    log_info "已加载 Casdoor 配置文件: $CASDOOR_CONFIG_FILE"
else
    log_error "缺少 Casdoor 配置文件: $CASDOOR_CONFIG_FILE"
    exit 1
fi

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="app-platform-dev"
DEFAULT_ENVIRONMENT="development"

CASDOOR_CHART_DIR="$SCRIPT_DIR/../resources/casdoor"
CASDOOR_CUSTOM_VALUES_DIR="$SCRIPT_DIR/../resources/custom-values"

# ─────────────────────────── 工具函数 ───────────────────────────

check_namespace() {
    local namespace="$1"
    if ! setup_kubectl_environment; then
        log_error "无法建立 Kubernetes 连接"
        return 1
    fi
    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
        log_success "✅ 命名空间 $namespace 已存在"
    else
        log_error "❌ 命名空间 $namespace 不存在，请先创建"
        return 1
    fi
}

check_chart() {
    if [[ ! -d "$CASDOOR_CHART_DIR" ]] || [[ ! -f "$CASDOOR_CHART_DIR/Chart.yaml" ]]; then
        log_error "Casdoor Chart 不存在: $CASDOOR_CHART_DIR"
        echo ""
        echo "请先拉取 Chart："
        echo "  helm repo add casdoor https://casdoor.github.io/casdoor-helm"
        echo "  helm repo update"
        echo "  helm pull casdoor/casdoor --untar --untardir $SCRIPT_DIR/../resources/"
        echo ""
        return 1
    fi
}

push_casdoor_images_to_harbor() {
    push_component_images_to_harbor "casdoor"
}

provision_casdoor_database() {
    local environment="$1" dry_run="$2"
    local bootstrap_dir="$SCRIPT_DIR/../db-access-bootstrap"
    local bootstrap_script

    [[ "$dry_run" == "true" ]] && { log_info "dry-run 模式，跳过 Casdoor 数据库 provision"; return 0; }
    [[ -d "$bootstrap_dir" ]] || { log_warn "Casdoor db-access-bootstrap 目录不存在，跳过: $bootstrap_dir"; return 0; }

    # 始终通过 K8s 临时 PostgreSQL client Pod 执行 provision。
    # external 模式会依赖部署机本地 psql；C1/WSL 环境不保证安装该客户端。
    # K8s 模式在集群内访问 PostgreSQL service，Kind 和远程集群都适用。
    bootstrap_script="$bootstrap_dir/setup-k8s-db-access.sh"

    [[ -x "$bootstrap_script" ]] || { log_error "Casdoor 数据库 provision 脚本不可执行: $bootstrap_script"; return 1; }

    log_info "开始 provision Casdoor 数据库..."
    if bash "$bootstrap_script"; then
        log_success "✅ Casdoor 数据库 provision 完成"
    else
        log_error "❌ Casdoor 数据库 provision 失败"
        return 1
    fi
}

# ─────────────────────────── 主部署 ───────────────────────────

execute_casdoor_deployment() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"

    log_info "开始执行 Casdoor 部署..."
    log_info "项目: $project_id | 命名空间: $namespace | 环境: $environment"

    check_chart || return 1

    local values_file
    case "$environment" in
        "development"|"dev")
            local cluster_lower="$(echo "${CLUSTER:-}" | tr '[:upper:]' '[:lower:]')"
            if [[ "$cluster_lower" == "kind" ]]; then
                local pv_pvc_file="$CASDOOR_CUSTOM_VALUES_DIR/casdoor-kind-pv-pvc.yaml"
                kubectl apply -f "$pv_pvc_file" >&2
                values_file="$CASDOOR_CUSTOM_VALUES_DIR/dev-values-kind.yaml"
            else
                values_file="$CASDOOR_CUSTOM_VALUES_DIR/dev-values.yaml"
            fi
            ;;
        "production"|"prod")
            values_file="$CASDOOR_CUSTOM_VALUES_DIR/prod-values.yaml" ;;
        *)
            log_warn "未知环境 $environment，使用 dev-values.yaml"
            values_file="$CASDOOR_CUSTOM_VALUES_DIR/dev-values.yaml" ;;
    esac

    [[ -f "$values_file" ]] || { log_error "values 文件不存在: $values_file"; return 1; }

    local helm_cmd="helm upgrade --install casdoor-$project_id $CASDOOR_CHART_DIR"
    helm_cmd="$helm_cmd --namespace $namespace"
    [[ -f "$CASDOOR_CHART_DIR/values.yaml" ]] && helm_cmd="$helm_cmd --values $CASDOOR_CHART_DIR/values.yaml"
    helm_cmd="$helm_cmd --values $values_file"
    helm_cmd="$helm_cmd --set global.projectId=$project_id"
    helm_cmd="$helm_cmd --set global.namespace=$namespace"
    helm_cmd="$helm_cmd --set global.environment=$environment"

    # 覆盖为 Harbor 镜像
    # 注意：此 common chart 模板不支持独立的 image.registry 字段，需将 registry 合并到 repository
    if [[ -n "${CASDOOR_IMAGE_REGISTRY:-}" ]] && [[ -n "${CASDOOR_IMAGE_PROJECT:-}" ]]; then
        helm_cmd="$helm_cmd --set image.repository=${CASDOOR_IMAGE_REGISTRY}/${CASDOOR_IMAGE_PROJECT}/casdoor"
        helm_cmd="$helm_cmd --set image.tag=${CASDOOR_IMAGE_VERSION:-latest}"
        log_info "使用 Harbor 镜像: ${CASDOOR_IMAGE_REGISTRY}/${CASDOOR_IMAGE_PROJECT}/casdoor:${CASDOOR_IMAGE_VERSION:-latest}"
    fi

    [[ "$dry_run" == "true" ]] && helm_cmd="$helm_cmd --dry-run"

    if eval "$helm_cmd"; then
        log_success "✅ Casdoor 部署完成"
    else
        log_error "❌ Casdoor 部署失败"
        return 1
    fi
}

# ─────────────────────────── 状态检查 ───────────────────────────

check_casdoor_status() {
    local project_id="$1"
    local namespace="$2"
    local release_name="casdoor-$project_id"

    log_info "检查 Casdoor 部署状态..."

    type setup_kubectl_environment >/dev/null 2>&1 && setup_kubectl_environment || true

    if helm list -n "$namespace" | grep -q "$release_name"; then
        log_success "✅ Casdoor Helm Release 存在"
    else
        log_error "❌ Casdoor Helm Release 不存在"; return 1
    fi

    local pods_running
    pods_running=$(kubectl get pods -n "$namespace" \
        -l "app.kubernetes.io/instance=$release_name" \
        -o jsonpath='{.items[*].status.phase}' 2>/dev/null | tr ' ' '\n' | { grep -c '^Running$' || true; })

    if [[ "$pods_running" -gt 0 ]]; then
        log_success "✅ Casdoor Pod 运行正常 (${pods_running} 个)"
    else
        local pods_pending
        pods_pending=$(kubectl get pods -n "$namespace" \
            -l "app.kubernetes.io/instance=$release_name" \
            -o jsonpath='{.items[*].status.phase}' 2>/dev/null | tr ' ' '\n' | { grep -cE '^(Pending|ContainerCreating)$' || true; })
        if [[ "$pods_pending" -gt 0 ]]; then
            log_warn "⏳ Casdoor Pod 启动中 ($pods_pending 个 Pending)"
        else
            log_error "❌ Casdoor Pod 未运行"
            return 1
        fi
    fi

    echo ""
    echo "=== Casdoor 访问信息 ==="
    echo "管理控制台: https://${CASDOOR_UNIFIED_HOST:-casdoor.sunmoonai.com}"
    echo "命名空间:   $namespace"
    echo ""
}

# ─────────────────────────── 子组件部署 ───────────────────────────

deploy_secrets() {
    local project_id="$1" namespace="$2" environment="$3" dry_run="$4"
    local secrets_script="$SCRIPT_DIR/secrets/deploy-secrets-all/deploy-secrets-all.sh"

    [[ "${secrets_enabled:-true}" != "true" ]] && { log_info "跳过 Secrets 部署"; return 0; }
    [[ -f "$secrets_script" ]] || { log_warn "Secrets 脚本不存在，跳过: $secrets_script"; return 0; }

    if bash "$secrets_script" "$project_id" "$namespace" "$environment" "$dry_run"; then
        log_success "✅ Casdoor Secrets 部署成功"
    else
        log_error "❌ Casdoor Secrets 部署失败"; return 1
    fi
}

deploy_ingress() {
    local project_id="$1" namespace="$2" environment="$3"
    local ingress_script="$SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh"

    [[ "${ingress_enabled:-true}" != "true" ]] && { log_info "跳过 Ingress 部署"; return 0; }
    [[ -f "$ingress_script" ]] || { log_warn "Ingress 脚本不存在，跳过: $ingress_script"; return 0; }

    if DISABLE_AUTO_CLEANUP=true bash "$ingress_script" deploy "$project_id" "$namespace" "$environment"; then
        log_success "✅ Casdoor Ingress 部署成功"
    else
        log_error "❌ Casdoor Ingress 部署失败"; return 1
    fi
}

run_post_deploy_setup() {
    local namespace="$1" dry_run="$2"
    local setup_script="$SCRIPT_DIR/post-deploy-setup.sh"

    [[ "$dry_run" == "true" ]] && { log_info "dry-run 模式，跳过 post-deploy-setup"; return 0; }
    [[ -f "$setup_script" ]] || { log_warn "post-deploy-setup.sh 不存在，跳过"; return 0; }

    setup_kubectl_environment || { log_error "无法建立 Kubernetes 连接"; return 1; }

    log_info "等待 Casdoor Pod 就绪..."
    if ! kubectl rollout status deployment/"casdoor-${CASDOOR_PROJECT_ID:-sunmoonai}" \
        -n "$namespace" --timeout=120s; then
        kubectl get pods -n "$namespace" -l "app.kubernetes.io/instance=casdoor-${CASDOOR_PROJECT_ID:-sunmoonai}" -o wide || true
        log_error "Casdoor Pod 未就绪"
        return 1
    fi

    if bash "$setup_script" "$namespace"; then
        log_success "✅ Casdoor post-deploy-setup 完成"
    else
        log_error "❌ Casdoor post-deploy-setup 失败"; return 1
    fi
}

# ─────────────────────────── 主函数 ───────────────────────────

declare -a PARSED_ARGS

main() {
    set -- "${ORIGINAL_ARGS[@]}"
    set -- "${PARSED_ARGS[@]}"

    [[ -n "${CLUSTER:-}" ]] && log_info "🎯 当前集群: ${CLUSTER}"

    local action="${1:-deploy}"
    local project_id="${2:-$DEFAULT_PROJECT_ID}"
    local namespace="${3:-$DEFAULT_NAMESPACE}"
    local environment="${4:-$DEFAULT_ENVIRONMENT}"
    local dry_run="${5:-false}"

    case "$action" in
        "help"|"--help"|"-h")
            echo "用法: $0 [--cluster C1|C2] <action> [project_id] [namespace] [environment] [dry_run]"
            echo ""
            echo "操作: deploy | upgrade | uninstall | status | help"
            echo "示例: $0 deploy sunmoonai app-platform-dev development"
            exit 0 ;;
    esac

    read_k8s_config || { log_error "无法读取 Kubernetes 配置"; exit 1; }
    setup_kubectl_environment || { log_error "无法建立 Kubernetes 连接"; exit 1; }

    case "$action" in
        "deploy")
            log_info "开始部署 Casdoor..."
            check_namespace "$namespace"
            push_casdoor_images_to_harbor
            provision_casdoor_database "$environment" "$dry_run" || exit 1
            deploy_secrets "$project_id" "$namespace" "$environment" "$dry_run" || exit 1
            execute_casdoor_deployment "$project_id" "$namespace" "$environment" "$dry_run" || exit 1
            deploy_ingress "$project_id" "$namespace" "$environment"
            run_post_deploy_setup "$namespace" "$dry_run" || exit 1
            log_success "🎉 Casdoor 完整部署成功！"
            check_casdoor_status "$project_id" "$namespace" || true
            ;;
        "upgrade")
            log_info "升级 Casdoor..."
            provision_casdoor_database "$environment" "$dry_run" || exit 1
            execute_casdoor_deployment "$project_id" "$namespace" "$environment" "$dry_run"
            check_casdoor_status "$project_id" "$namespace"
            ;;
        "uninstall")
            log_info "卸载 Casdoor..."
            helm uninstall "casdoor-$project_id" -n "$namespace" --wait || true
            log_success "✅ Casdoor 卸载完成"
            ;;
        "status")
            check_casdoor_status "$project_id" "$namespace"
            ;;
        "logs")
            kubectl logs -n "$namespace" \
                -l "app.kubernetes.io/instance=casdoor-$project_id" --tail=100
            ;;
        *)
            echo "用法: $0 [--cluster C1|C2] [deploy|upgrade|uninstall|status|logs|help]"
            exit 1 ;;
    esac
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
