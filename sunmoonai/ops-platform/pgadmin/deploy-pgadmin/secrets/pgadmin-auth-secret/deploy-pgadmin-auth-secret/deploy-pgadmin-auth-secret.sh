#!/bin/bash

# =============================================================================
# pgAdmin Secret 部署脚本
# 文件名: deploy-pgadmin-auth-secret.sh
# 用途: 生成并部署pgAdmin认证Secret到Kubernetes集群
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRET_DIR="$(dirname "$SCRIPT_DIR")"  # pgadmin-auth-secret 目录
# 计算项目根目录（k8s目录）
# 从 deploy-pgadmin-auth-secret/ 向上8级到达 k8s/
# deploy-pgadmin-auth-secret/ -> pgadmin-auth-secret/ -> secrets/ -> deploy-pgadmin/ -> pgadmin/ -> ops-platform/ -> sunmoonai/ -> k8s/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../../.." && pwd)"

# 加载Secret生成核心函数
source "$PROJECT_ROOT/utils/secret-management/lib/secret-core.sh"

# 日志函数（如果未定义）
log_info() { echo -e "[INFO] $*"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $*" 1>&2; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $*"; }

# 解析命令行参数（优先于配置文件加载，确保命令行参数优先级最高）
declare -a PARSED_ARGS

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
        if [[ -f "$PROJECT_ROOT/utils/cluster-config-mapping.sh" ]]; then
            source "$PROJECT_ROOT/utils/cluster-config-mapping.sh"
            apply_cluster_config_mapping "$cluster_value"
        fi
    fi
}

# 生成随机密码
generate_password() {
    local length="${1:-16}"
    openssl rand -base64 $((length * 3 / 4)) | tr -d "=+/" | cut -c1-${length}
}

main() {
    parse_cluster_arg "$@"
    set -- "${PARSED_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    local project_id="${1:-$DEFAULT_PROJECT_ID}"
    local namespace="${2:-$DEFAULT_NAMESPACE}"
    local environment="${3:-$DEFAULT_ENVIRONMENT}"
    local dry_run="${4:-false}"
    
    log_info "部署 pgAdmin Secret..."
    log_info "部署参数："
    log_info "  - 项目ID: $project_id"
    log_info "  - 命名空间: $namespace"
    log_info "  - 环境: $environment"
    log_info "  - 试运行: $dry_run"
    echo ""
    
    # 1. 准备Opaque Secret数据
    log_info "准备Opaque Secret数据..."
    
    # 创建临时数据目录
    local temp_data_dir=$(mktemp -d)
    trap "rm -rf $temp_data_dir" EXIT
    
    # 生成密码（如果未提供）
    if [[ -z "${pgadmin_password:-}" ]]; then
        # 如果配置文件中没有设置，尝试从配置文件重新加载
        if [[ -f "$SCRIPT_DIR/deploy-pgadmin-auth-secret.conf" ]]; then
            source "$SCRIPT_DIR/deploy-pgadmin-auth-secret.conf"
        fi
        # 如果仍然为空，生成随机密码
        if [[ -z "${pgadmin_password:-}" ]]; then
            pgadmin_password=$(generate_password 16)
            log_info "生成随机密码: ${pgadmin_password:0:4}..."
        else
            log_info "使用配置文件中的密码: ${pgadmin_password:0:4}..."
        fi
    else
        log_info "使用已设置的密码: ${pgadmin_password:0:4}..."
    fi
    
    # 从配置中提取数据键（使用默认值避免未定义变量错误）
    if [[ -n "${pgadmin_password:-}" ]]; then
        local password_key="${PGADMIN_AUTH_SECRET_PASSWORD_KEY:-pgadmin-password}"
        echo -n "${pgadmin_password}" > "$temp_data_dir/${password_key}"
        log_info "添加数据键: ${password_key}"
    fi
    
    # 注意：pgAdmin 的用户名（email）在 dev-values.yaml 的 env.email 中定义，不存储在 Secret 中
    
    # 2. 生成Opaque Secret YAML
    local secret_yaml="$SECRET_DIR/pgadmin-auth-secret.yaml"
    local secret_name="${SECRET_NAME:-pgadmin-auth-secret}"
    
    log_info "生成Opaque Secret YAML..."
    generate_opaque_secret_yaml \
        --name "$secret_name" \
        --namespace "$namespace" \
        --data-dir "$temp_data_dir" \
        --output "$secret_yaml"
    
    log_success "Opaque Secret YAML生成完成: $secret_yaml"
    
    # 3. 部署Secret到Kubernetes
    if [[ "$dry_run" != "true" ]]; then
        log_info "部署Secret到Kubernetes集群..."
        
        # 检查命名空间是否存在
        if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
            log_error "命名空间不存在: $namespace"
            log_error "请先创建命名空间: kubectl create namespace $namespace"
            exit 1
        fi
        
        # 部署Secret
        if kubectl apply -f "$secret_yaml"; then
            log_success "Secret已部署: $secret_name (命名空间: $namespace)"
            log_info "注意：pgAdmin 用户名（email）在 dev-values.yaml 的 env.email 中定义"
            if [[ -n "${pgadmin_password:-}" ]]; then
                log_info "pgAdmin 密码: ${pgadmin_password:0:4}..."
            fi
        else
            log_error "Secret部署失败"
            exit 1
        fi
        
        # 4. 可选：重启相关组件（如果配置了）
        if [[ "${RESTART_COMPONENTS:-false}" == "true" && -n "${RESTART_COMPONENTS_LIST:-}" ]]; then
            log_info "重启使用该Secret的组件..."
            IFS=',' read -ra COMPONENTS <<< "${RESTART_COMPONENTS_LIST}"
            for component in "${COMPONENTS[@]}"; do
                component=$(echo "$component" | xargs)
                if [[ -n "$component" ]]; then
                    log_info "重启组件: $component"
                    kubectl rollout restart deployment/"$component" -n "$namespace" 2>/dev/null || \
                    kubectl rollout restart statefulset/"$component" -n "$namespace" 2>/dev/null || \
                    log_warn "组件 $component 不存在或重启失败"
                fi
            done
        fi
    else
        log_info "[试运行] 将部署Secret: $secret_name"
        log_info "[试运行] YAML文件: $secret_yaml"
    fi
    
    echo ""
    log_success "pgAdmin Secret 部署完成！"
    log_info "部署信息："
    log_info "  - Secret名称: $secret_name"
    log_info "  - 命名空间: $namespace"
    log_info "  - 部署时间: $(date '+%Y-%m-%d %H:%M:%S')"
}

# 显示帮助信息
show_help() {
    echo "pgAdmin Secret 部署脚本"
    echo ""
    echo "用法:"
    echo "  $0 [项目ID] [命名空间] [环境] [试运行]"
    echo ""
    echo "参数:"
    echo "  项目ID     项目标识符 (默认: $DEFAULT_PROJECT_ID)"
    echo "  命名空间   Kubernetes 命名空间 (默认: $DEFAULT_NAMESPACE)"
    echo "  环境       部署环境 (默认: $DEFAULT_ENVIRONMENT)"
    echo "  试运行     是否试运行 (默认: false)"
    echo ""
    echo "示例:"
    echo "  $0                                    # 使用默认参数"
    echo "  $0 sunmoonai ops-platform-dev dev   # 指定参数"
    echo "  $0 sunmoonai ops-platform-dev dev true # 试运行模式"
    echo ""
    echo "配置文件: $SCRIPT_DIR/deploy-pgadmin-auth-secret.conf"
}

# 主程序入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_help
        exit 0
    fi
    main "$@"
fi

# 先解析命令行参数（如果提供）
# 保存原始参数，以便在 main 函数中使用
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi


# 加载配置
source "$SCRIPT_DIR/deploy-pgadmin-auth-secret.conf"

# 加载集群配置映射函数（使用 utils 中的通用函数）
if [[ -f "$PROJECT_ROOT/utils/cluster-config-mapping.sh" ]]; then
    source "$PROJECT_ROOT/utils/cluster-config-mapping.sh"
    # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
    apply_cluster_config_mapping
fi

# 日志函数（如果未定义）
log_info() { echo -e "[INFO] $*"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $*" 1>&2; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $*"; }

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="ops-platform-dev"
DEFAULT_ENVIRONMENT="development"

# 解析命令行参数（支持 --cluster 或 -c）
declare -a PARSED_ARGS

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
        if [[ -f "$PROJECT_ROOT/utils/cluster-config-mapping.sh" ]]; then
            source "$PROJECT_ROOT/utils/cluster-config-mapping.sh"
            apply_cluster_config_mapping "$cluster_value"
        fi
    fi
}

# 生成随机密码
generate_password() {
    local length="${1:-16}"
    openssl rand -base64 $((length * 3 / 4)) | tr -d "=+/" | cut -c1-${length}
}

main() {
    # 使用解析后的参数（已移除 --cluster 参数）
    set -- "${ORIGINAL_ARGS[@]}"
    set -- "${PARSED_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    local project_id="${1:-$DEFAULT_PROJECT_ID}"
    local namespace="${2:-$DEFAULT_NAMESPACE}"
    local environment="${3:-$DEFAULT_ENVIRONMENT}"
    local dry_run="${4:-false}"
    
    log_info "部署 pgAdmin Secret..."
    log_info "部署参数："
    log_info "  - 项目ID: $project_id"
    log_info "  - 命名空间: $namespace"
    log_info "  - 环境: $environment"
    log_info "  - 试运行: $dry_run"
    echo ""
    
    # 1. 准备Opaque Secret数据
    log_info "准备Opaque Secret数据..."
    
    # 创建临时数据目录
    local temp_data_dir=$(mktemp -d)
    trap "rm -rf $temp_data_dir" EXIT
    
    # 生成密码（如果未提供）
    if [[ -z "${pgadmin_password:-}" ]]; then
        # 如果配置文件中没有设置，尝试从配置文件重新加载
        if [[ -f "$SCRIPT_DIR/deploy-pgadmin-auth-secret.conf" ]]; then
            source "$SCRIPT_DIR/deploy-pgadmin-auth-secret.conf"
        fi
        # 如果仍然为空，生成随机密码
        if [[ -z "${pgadmin_password:-}" ]]; then
            pgadmin_password=$(generate_password 16)
            log_info "生成随机密码: ${pgadmin_password:0:4}..."
        else
            log_info "使用配置文件中的密码: ${pgadmin_password:0:4}..."
        fi
    else
        log_info "使用已设置的密码: ${pgadmin_password:0:4}..."
    fi
    
    # 从配置中提取数据键（使用默认值避免未定义变量错误）
    if [[ -n "${pgadmin_password:-}" ]]; then
        local password_key="${PGADMIN_AUTH_SECRET_PASSWORD_KEY:-pgadmin-password}"
        echo -n "${pgadmin_password}" > "$temp_data_dir/${password_key}"
        log_info "添加数据键: ${password_key}"
    fi
    
    # 注意：pgAdmin 的用户名（email）在 dev-values.yaml 的 env.email 中定义，不存储在 Secret 中
    
    # 2. 生成Opaque Secret YAML
    local secret_yaml="$SECRET_DIR/pgadmin-auth-secret.yaml"
    local secret_name="${SECRET_NAME:-pgadmin-auth-secret}"
    
    log_info "生成Opaque Secret YAML..."
    generate_opaque_secret_yaml \
        --name "$secret_name" \
        --namespace "$namespace" \
        --data-dir "$temp_data_dir" \
        --output "$secret_yaml"
    
    log_success "Opaque Secret YAML生成完成: $secret_yaml"
    
    # 3. 部署Secret到Kubernetes
    if [[ "$dry_run" != "true" ]]; then
        log_info "部署Secret到Kubernetes集群..."
        
        # 检查命名空间是否存在
        if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
            log_error "命名空间不存在: $namespace"
            log_error "请先创建命名空间: kubectl create namespace $namespace"
            exit 1
        fi
        
        # 部署Secret
        if kubectl apply -f "$secret_yaml"; then
            log_success "Secret已部署: $secret_name (命名空间: $namespace)"
            log_info "注意：pgAdmin 用户名（email）在 dev-values.yaml 的 env.email 中定义"
            if [[ -n "${pgadmin_password:-}" ]]; then
                log_info "pgAdmin 密码: ${pgadmin_password:0:4}..."
            fi
        else
            log_error "Secret部署失败"
            exit 1
        fi
        
        # 4. 可选：重启相关组件（如果配置了）
        if [[ "${RESTART_COMPONENTS:-false}" == "true" && -n "${RESTART_COMPONENTS_LIST:-}" ]]; then
            log_info "重启使用该Secret的组件..."
            IFS=',' read -ra COMPONENTS <<< "${RESTART_COMPONENTS_LIST}"
            for component in "${COMPONENTS[@]}"; do
                component=$(echo "$component" | xargs)
                if [[ -n "$component" ]]; then
                    log_info "重启组件: $component"
                    kubectl rollout restart deployment/"$component" -n "$namespace" 2>/dev/null || \
                    kubectl rollout restart statefulset/"$component" -n "$namespace" 2>/dev/null || \
                    log_warn "组件 $component 不存在或重启失败"
                fi
            done
        fi
    else
        log_info "[试运行] 将部署Secret: $secret_name"
        log_info "[试运行] YAML文件: $secret_yaml"
    fi
    
    echo ""
    log_success "pgAdmin Secret 部署完成！"
    log_info "部署信息："
    log_info "  - Secret名称: $secret_name"
    log_info "  - 命名空间: $namespace"
    log_info "  - 部署时间: $(date '+%Y-%m-%d %H:%M:%S')"
}

# 显示帮助信息
show_help() {
    echo "pgAdmin Secret 部署脚本"
    echo ""
    echo "用法:"
    echo "  $0 [项目ID] [命名空间] [环境] [试运行]"
    echo ""
    echo "参数:"
    echo "  项目ID     项目标识符 (默认: $DEFAULT_PROJECT_ID)"
    echo "  命名空间   Kubernetes 命名空间 (默认: $DEFAULT_NAMESPACE)"
    echo "  环境       部署环境 (默认: $DEFAULT_ENVIRONMENT)"
    echo "  试运行     是否试运行 (默认: false)"
    echo ""
    echo "示例:"
    echo "  $0                                    # 使用默认参数"
    echo "  $0 sunmoonai ops-platform-dev dev   # 指定参数"
    echo "  $0 sunmoonai ops-platform-dev dev true # 试运行模式"
    echo ""
    echo "配置文件: $SCRIPT_DIR/deploy-pgadmin-auth-secret.conf"
}

# 主程序入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_help
        exit 0
    fi
    main "$@"
fi
