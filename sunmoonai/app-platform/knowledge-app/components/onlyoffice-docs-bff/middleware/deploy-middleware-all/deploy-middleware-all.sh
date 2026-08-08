#!/bin/bash

# ONLYOFFICE Docs 中间件总控部署脚本
# 统一部署所有 ONLYOFFICE Docs 中间件组件（stripprefix + policy）

set -e

# 脚本目录（保存为变量，防止被统一部署模板覆盖）
ONLYOFFICE_MIDDLEWARE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 计算项目根目录（k8s目录）
# 从 deploy-middleware-all/ -> middleware/ -> onlyoffice-docs/ -> app-platform/ -> sunmoonai/ -> k8s/
PROJECT_ROOT="$(cd "$ONLYOFFICE_MIDDLEWARE_SCRIPT_DIR/../../../../.." && pwd)"

# 导入统一部署模板（可能会覆盖 SCRIPT_DIR，所以我们已经保存了）
source "$PROJECT_ROOT/../utils/unified-deployment-template.sh"

# 使用保存的脚本目录
ONLYOFFICE_MIDDLEWARE_CONFIG_FILE="$ONLYOFFICE_MIDDLEWARE_SCRIPT_DIR/deploy-middleware-all.conf"

# 加载配置
load_config() {
    local config_file="${ONLYOFFICE_MIDDLEWARE_CONFIG_FILE:-$ONLYOFFICE_MIDDLEWARE_SCRIPT_DIR/deploy-middleware-all.conf}"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "ONLYOFFICE Docs 中间件总控配置文件不存在: $config_file"
        log_error "ONLYOFFICE_MIDDLEWARE_SCRIPT_DIR: $ONLYOFFICE_MIDDLEWARE_SCRIPT_DIR"
        exit 1
    fi
    
    source "$config_file"
    log_success "✅ ONLYOFFICE Docs 中间件总控配置加载成功"
}

# 部署所有中间件组件（按优先级）
deploy_all_middleware() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="${4:-false}"
    
    log_info "开始基于优先级的 ONLYOFFICE Docs 中间件组件部署..."
    log_info "命名空间: $namespace"
    
    local components=(
        "stripprefix:${onlyoffice_stripprefix_enabled:-true}:${onlyoffice_stripprefix_priority:-200}:ONLYOFFICE Docs StripPrefix:$ONLYOFFICE_MIDDLEWARE_SCRIPT_DIR/../onlyoffice-docs-stripprefix/onlyoffice-docs-stripprefix.yaml"
    )
    
    # 过滤启用的组件并按优先级排序
    local enabled=()
    for c in "${components[@]}"; do
        IFS=':' read -r name en pr desc path <<< "$c"
        [[ "$en" == "true" ]] && enabled+=("$c")
    done
    
    # 按优先级降序排序（数值越大越先部署）
    if [[ ${#enabled[@]} -gt 1 ]]; then
        IFS=$'\n' enabled=($(printf '%s\n' "${enabled[@]}" | sort -t: -k3 -nr))
    fi
    
    # 按优先级部署
    for c in "${enabled[@]}"; do
        IFS=':' read -r name en pr desc path <<< "$c"
        log_info "🚀 部署 $desc (优先级: $pr) ..."
        if [[ -f "$path" ]]; then
            # 更新命名空间
            local tmp_file=$(mktemp)
            sed "s/namespace: app-platform-dev/namespace: $namespace/g" "$path" > "$tmp_file"
            if kubectl apply -f "$tmp_file"; then
                log_success "✅ $desc 部署成功"
            else
                log_error "❌ $desc 部署失败"
                rm -f "$tmp_file"
                return 1
            fi
            rm -f "$tmp_file"
        else
            log_error "❌ $desc 配置文件不存在: $path"
            return 1
        fi
    done
    
    log_success "✅ ONLYOFFICE Docs 所有中间件组件部署完成！"
    return 0
}

# 主函数
main() {
    local action="${1:-deploy}"
    local project_id="${2:-sunmoonai}"
    local namespace="${3:-app-platform-dev}"
    local environment="${4:-development}"
    local dry_run="${5:-false}"
    
    if ! setup_kubectl_environment; then
        log_error "无法建立 Kubernetes 连接"
        exit 1
    fi
    
    case "$action" in
        "deploy")
            deploy_all_middleware "$project_id" "$namespace" "$environment" "$dry_run"
            ;;
        *)
            echo "用法: $0 deploy [project_id] [namespace] [environment] [dry_run]"
            exit 1
            ;;
    esac
}

main "$@"

