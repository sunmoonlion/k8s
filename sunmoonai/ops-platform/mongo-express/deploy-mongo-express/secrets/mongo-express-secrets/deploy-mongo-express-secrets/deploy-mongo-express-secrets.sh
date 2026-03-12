#!/bin/bash

# =============================================================================
# Mongo Express Secret 部署脚本
# 文件名: deploy-mongo-express-secrets.sh
# 用途: 生成并部署Mongo Express认证Secret到Kubernetes集群
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRET_DIR="$(dirname "$SCRIPT_DIR")"  # mongo-express-secrets 目录
# 计算项目根目录（k8s目录）
# 从 deploy-mongo-express-secrets/ 向上8级到达 k8s/
# deploy-mongo-express-secrets/ -> mongo-express-secrets/ -> secrets/ -> deploy-mongo-express/ -> mongo-express/ -> ops-platform/ -> sunmoonai/ -> k8s/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../../.." && pwd)"

# 保存 SCRIPT_DIR，因为 unified-deployment-template.sh 可能会覆盖它
MONGO_EXPRESS_SECRETS_SCRIPT_DIR="$SCRIPT_DIR"

# 导入统一部署模板（建立远程 k8s 连接）
source "$PROJECT_ROOT/utils/unified-deployment-template.sh"

# 恢复 SCRIPT_DIR（unified-deployment-template.sh 可能会覆盖它）
SCRIPT_DIR="$MONGO_EXPRESS_SECRETS_SCRIPT_DIR"

# 加载Secret生成核心函数
source "$PROJECT_ROOT/utils/secret-management/lib/secret-core.sh"

# 日志函数（如果未定义，但 unified-deployment-template.sh 应该已经定义了）
# 保留这些定义作为后备，以防 unified-deployment-template.sh 未定义
if ! declare -f log_info >/dev/null 2>&1; then
    log_info() { echo -e "[INFO] $*"; }
    log_success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }
    log_error() { echo -e "\033[31m[ERROR]\033[0m $*" 1>&2; }
    log_warn() { echo -e "\033[33m[WARN]\033[0m $*"; }
fi

# 解析命令行参数（优先于配置文件加载，确保命令行参数优先级最高）
declare -a PARSED_ARGS

# 生成随机密码
generate_password() {
    local length="${1:-16}"
    openssl rand -base64 $((length * 3 / 4)) | tr -d "=+/" | cut -c1-${length}
}

# =============================================================================
# 默认配置（在配置加载前提供默认值，避免未定义变量错误）
# =============================================================================
# 注意：这些默认值会在配置文件加载后被覆盖
# 但必须在这里定义，因为第一个 main 函数可能在配置加载前被调用

# 基本默认值
DEFAULT_PROJECT_ID="${DEFAULT_PROJECT_ID:-sunmoonai}"
DEFAULT_NAMESPACE="${DEFAULT_NAMESPACE:-ops-platform-dev}"
DEFAULT_ENVIRONMENT="${DEFAULT_ENVIRONMENT:-development}"

# Secret 基本信息默认值
SECRET_NAME="${SECRET_NAME:-mongo-express-secrets}"
SECRET_NAMESPACE="${SECRET_NAMESPACE:-ops-platform-dev}"
SECRET_TYPE="${SECRET_TYPE:-Opaque}"

# Secret 键名默认值
MONGO_EXPRESS_AUTH_SECRET_PASSWORD_KEY="${MONGO_EXPRESS_AUTH_SECRET_PASSWORD_KEY:-mongo-express-password}"
MONGO_EXPRESS_ADMIN_USER_KEY="${MONGO_EXPRESS_ADMIN_USER_KEY:-mongo-express-admin-user}"
MONGO_EXPRESS_MONGODB_AUTH_PASSWORD_KEY="${MONGO_EXPRESS_MONGODB_AUTH_PASSWORD_KEY:-mongodb-auth-password}"
MONGO_EXPRESS_SITE_COOKIE_SECRET_KEY="${MONGO_EXPRESS_SITE_COOKIE_SECRET_KEY:-site-cookie-secret}"
MONGO_EXPRESS_SITE_SESSION_SECRET_KEY="${MONGO_EXPRESS_SITE_SESSION_SECRET_KEY:-site-session-secret}"
MONGO_EXPRESS_BASIC_AUTH_PASSWORD_KEY="${MONGO_EXPRESS_BASIC_AUTH_PASSWORD_KEY:-basic-auth-password}"

# Secret 部署配置默认值
RESTART_COMPONENTS="${RESTART_COMPONENTS:-false}"
RESTART_PRIORITY="${RESTART_PRIORITY:-50}"
RESTART_COMPONENTS_LIST="${RESTART_COMPONENTS_LIST:-}"

# Secret 数据默认值（这些通常为空，由脚本生成）
mongo_express_password="${mongo_express_password:-}"
mongo_express_admin_user="${mongo_express_admin_user:-admin}"
mongodb_auth_password="${mongodb_auth_password:-}"
basic_auth_password="${basic_auth_password:-}"

# 先解析命令行参数（如果提供）
# 保存原始参数，以便在 main 函数中使用
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    log_info "原始参数数量: $#"
    log_info "原始参数: ${ORIGINAL_ARGS[@]}"
    unified_parse_cluster_arg "$@"
    log_info "解析后参数数量: ${#PARSED_ARGS[@]}"
    log_info "解析后参数: ${PARSED_ARGS[@]}"
    # 注意：不要覆盖 ORIGINAL_ARGS，保留原始参数用于后续处理
    # PARSED_ARGS 包含已移除 --cluster 参数的参数列表
fi


# 加载配置
# 确保使用正确的 SCRIPT_DIR（防止被 unified-deployment-template.sh 覆盖）
if [[ -f "$SCRIPT_DIR/deploy-mongo-express-secrets.conf" ]]; then
    source "$SCRIPT_DIR/deploy-mongo-express-secrets.conf"
else
    log_error "配置文件不存在: $SCRIPT_DIR/deploy-mongo-express-secrets.conf"
    log_error "SCRIPT_DIR: $SCRIPT_DIR"
    exit 1
fi

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

# 生成随机密码
generate_password() {
    local length="${1:-16}"
    openssl rand -base64 $((length * 3 / 4)) | tr -d "=+/" | cut -c1-${length}
}

main() {
    # 使用解析后的参数（已移除 --cluster 参数）
    # 如果 PARSED_ARGS 有值，使用它（已移除 --cluster），否则使用原始参数
    if [[ ${#PARSED_ARGS[@]} -gt 0 ]]; then
        set -- "${PARSED_ARGS[@]}"
    else
        set -- "${ORIGINAL_ARGS[@]}"
    fi
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    # 调试：显示解析后的参数
    log_info "解析后的参数数量: $#"
    log_info "解析后的参数: $@"
    
    local project_id="${1:-$DEFAULT_PROJECT_ID}"
    local namespace="${2:-$DEFAULT_NAMESPACE}"
    local environment="${3:-$DEFAULT_ENVIRONMENT}"
    local dry_run="${4:-false}"
    
    log_info "部署 Mongo Express Secret..."
    log_info "部署参数："
    log_info "  - 项目ID: $project_id"
    log_info "  - 命名空间: $namespace"
    log_info "  - 环境: $environment"
    log_info "  - 试运行: $dry_run"
    echo ""
    
    # 建立远程 k8s 连接（如果需要在部署前检查命名空间）
    if [[ "$dry_run" != "true" ]]; then
        setup_kubectl_environment
    fi
    
    # 1. 准备Opaque Secret数据
    log_info "准备Opaque Secret数据..."
    
    # 创建临时数据目录
    local temp_data_dir=$(mktemp -d)
    trap "rm -rf $temp_data_dir" EXIT
    
    # 生成密码（如果未提供）
    if [[ -z "${mongo_express_password:-}" ]]; then
        mongo_express_password=$(generate_password 16)
        log_info "生成随机密码: ${mongo_express_password:0:4}..."
    fi
    
    # 生成 MongoDB 认证密码（如果未提供，使用 mongo_express_password 或生成新的）
    if [[ -z "${mongodb_auth_password:-}" ]]; then
        if [[ -n "${mongo_express_password:-}" ]]; then
            mongodb_auth_password="${mongo_express_password}"
            log_info "使用 mongo_express_password 作为 mongodb_auth_password"
        else
            mongodb_auth_password=$(generate_password 16)
            log_info "生成 MongoDB 认证随机密码: ${mongodb_auth_password:0:4}..."
        fi
    fi
    
    # 生成 Basic Auth 密码（如果未提供）
    if [[ -z "${basic_auth_password:-}" ]]; then
        basic_auth_password=$(generate_password 16)
        log_info "生成 Basic Auth 随机密码: ${basic_auth_password:0:4}..."
    fi
    
    # 生成 Cookie Secret（32 字符随机字符串）
    local site_cookie_secret=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-32)
    
    # 生成 Session Secret（32 字符随机字符串）
    local site_session_secret=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-32)
    
    # 从配置中提取数据键
    if [[ -n "${mongo_express_password:-}" ]]; then
        echo -n "${mongo_express_password}" > "$temp_data_dir/${MONGO_EXPRESS_AUTH_SECRET_PASSWORD_KEY}"
        log_info "添加数据键: ${MONGO_EXPRESS_AUTH_SECRET_PASSWORD_KEY}"
    fi
    
    if [[ -n "${mongo_express_admin_user:-}" ]]; then
        echo -n "${mongo_express_admin_user}" > "$temp_data_dir/${MONGO_EXPRESS_ADMIN_USER_KEY}"
        log_info "添加数据键: ${MONGO_EXPRESS_ADMIN_USER_KEY}"
    fi
    
    # MongoDB 认证密码（必须生成，用于非管理员模式连接 MongoDB）
    # 注意：即使 mongodb_auth_password 为空，也要生成一个默认值，确保 Secret 中有这个键
    if [[ -z "${mongodb_auth_password:-}" ]]; then
        mongodb_auth_password="${mongo_express_password:-$(generate_password 16)}"
        log_warn "⚠️  mongodb_auth_password 未设置，使用 mongo_express_password 或生成随机密码"
    fi
    echo -n "${mongodb_auth_password}" > "$temp_data_dir/${MONGO_EXPRESS_MONGODB_AUTH_PASSWORD_KEY}"
    log_info "添加数据键: ${MONGO_EXPRESS_MONGODB_AUTH_PASSWORD_KEY}"
    
    # Cookie Secret
    echo -n "${site_cookie_secret}" > "$temp_data_dir/${MONGO_EXPRESS_SITE_COOKIE_SECRET_KEY}"
    log_info "添加数据键: ${MONGO_EXPRESS_SITE_COOKIE_SECRET_KEY}"
    
    # Session Secret
    echo -n "${site_session_secret}" > "$temp_data_dir/${MONGO_EXPRESS_SITE_SESSION_SECRET_KEY}"
    log_info "添加数据键: ${MONGO_EXPRESS_SITE_SESSION_SECRET_KEY}"
    
    # Basic Auth 密码
    if [[ -n "${basic_auth_password:-}" ]]; then
        echo -n "${basic_auth_password}" > "$temp_data_dir/${MONGO_EXPRESS_BASIC_AUTH_PASSWORD_KEY}"
        log_info "添加数据键: ${MONGO_EXPRESS_BASIC_AUTH_PASSWORD_KEY}"
    fi
    
    # 2. 生成Opaque Secret YAML
    local secret_yaml="$SECRET_DIR/mongo-express-secrets.yaml"
    
    log_info "生成Opaque Secret YAML..."
    generate_opaque_secret_yaml \
        --name "$SECRET_NAME" \
        --namespace "$namespace" \
        --data-dir "$temp_data_dir" \
        --output "$secret_yaml"
    
    log_success "Opaque Secret YAML生成完成: $secret_yaml"
    
    # 3. 部署Secret到Kubernetes
    if [[ "$dry_run" != "true" ]]; then
        log_info "部署Secret到Kubernetes集群..."
        
        # 检查命名空间是否存在（使用更详细的错误信息）
        log_info "检查命名空间: $namespace"
        if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
            local kubectl_error=$(kubectl get namespace "$namespace" 2>&1)
            log_error "命名空间不存在: $namespace"
            log_error "kubectl 错误信息: $kubectl_error"
            log_error "请先创建命名空间: kubectl create namespace $namespace"
            log_info "或者检查 kubectl 连接是否正确"
            exit 1
        else
            log_success "✅ 命名空间存在: $namespace"
        fi
        
        # 部署Secret
        if kubectl apply -f "$secret_yaml"; then
            log_success "Secret已部署: $SECRET_NAME (命名空间: $namespace)"
            log_info "Mongo Express 管理员用户: ${mongo_express_admin_user:-admin}"
            if [[ -n "${mongo_express_password:-}" ]]; then
                log_info "Mongo Express 密码: ${mongo_express_password:0:4}..."
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
        log_info "[试运行] 将部署Secret: $SECRET_NAME"
        log_info "[试运行] YAML文件: $secret_yaml"
    fi
    
    echo ""
    log_success "Mongo Express Secret 部署完成！"
    log_info "部署信息："
    log_info "  - Secret名称: $SECRET_NAME"
    log_info "  - 命名空间: $namespace"
    log_info "  - 部署时间: $(date '+%Y-%m-%d %H:%M:%S')"
}

# 显示帮助信息
show_help() {
    echo "Mongo Express Secret 部署脚本"
    echo ""
    echo "用法:"
    echo "  $0 [项目ID] [命名空间] [环境] [试运行]"
    echo ""
    echo "参数:"
    echo "  项目ID     项目标识符 (默认: ${DEFAULT_PROJECT_ID:-sunmoonai})"
    echo "  命名空间   Kubernetes 命名空间 (默认: ${DEFAULT_NAMESPACE:-ops-platform-dev})"
    echo "  环境       部署环境 (默认: ${DEFAULT_ENVIRONMENT:-development})"
    echo "  试运行     是否试运行 (默认: false)"
    echo ""
    echo "示例:"
    echo "  $0                                    # 使用默认参数"
    echo "  $0 sunmoonai ops-platform-dev dev   # 指定参数"
    echo "  $0 sunmoonai ops-platform-dev dev true # 试运行模式"
    echo ""
    echo "配置文件: $SCRIPT_DIR/deploy-mongo-express-secrets.conf"
}

# 主程序入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_help
        exit 0
    fi
    main "$@"
fi
