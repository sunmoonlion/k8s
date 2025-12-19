#!/bin/bash

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Jenkins 密钥配置文件路径
JENKINS_SECRETS_CONFIG_FILE="$SCRIPT_DIR/jenkins-sunmoonai.conf"

# Jenkins 项目根目录（与主 deploy-jenkins.sh 保持一致）
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# 导入统一部署模板（提供 log_* 和 Kubernetes 连接管理函数）
source "$PROJECT_ROOT/../../../utils/unified-deployment-template.sh"

# 解析命令行参数（优先于配置文件加载，确保命令行参数优先级最高）
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
        if [[ -f "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh" ]]; then
            source "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh"
            apply_cluster_config_mapping "$cluster_value"
        fi
    fi
}

# 先解析命令行参数（如果提供）
# 保存原始参数，以便在 main 函数中使用
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

# 加载配置
load_config() {
    if [[ ! -f "$JENKINS_SECRETS_CONFIG_FILE" ]]; then
        log_error "Jenkins 密钥配置文件不存在: $JENKINS_SECRETS_CONFIG_FILE"
        exit 1
    fi
    
    source "$JENKINS_SECRETS_CONFIG_FILE"
    log_success "✅ Jenkins 密钥配置加载成功"
}

# 生成随机密码
generate_password() {
    local length="${1:-16}"
    openssl rand -base64 $((length * 3 / 4)) | tr -d "=+/" | cut -c1-${length}
}

# 部署 Jenkins 密钥
# 注意：Secret 名称必须与 Helm Chart 创建的 Secret 名称一致（jenkins-{project_id}）
# 这样 Chart 可以直接使用这个 Secret，无需通过 extraEnvVars 覆盖
deploy_jenkins_secrets() {
    local namespace="${1:-cicd-platform-dev}"
    
    log_info "部署 Jenkins 密钥..."
    log_info "命名空间: $namespace"
    log_info "Secret 名称: $JENKINS_SECRET_NAME（必须与 Chart 创建的 Secret 名称一致）"
    log_info "Secret 键名: $JENKINS_AUTH_SECRET_PASSWORD_KEY（Chart 模板中固定的键名）"
    log_info "说明: 如果 jenkinsPassword: \"\" 留空，Chart 会检查此 Secret 是否存在"
    log_info "      如果存在，使用 Secret 中的密码；如果不存在，Chart 会生成随机密码"
    
    # 检查密钥是否已存在
    local secret_exists=false
    if kubectl get secret "$JENKINS_SECRET_NAME" -n "$namespace" >/dev/null 2>&1; then
        secret_exists=true
        log_info "Jenkins 密钥已存在: $JENKINS_SECRET_NAME"
    fi
    
    # 生成或使用配置的密码
    # 注意：不再在 Secret 中存储用户名，因为 Bitnami Chart 不会从 Secret 读取用户名
    # 用户名通过 jenkinsUser values 参数设置（或使用默认值 "user"）
    local jenkins_password
    
    # 如果配置文件中设置了密码，使用配置的值；否则自动生成
    if [[ -n "${JENKINS_PASSWORD:-}" ]]; then
        jenkins_password="${JENKINS_PASSWORD}"
        log_info "使用配置文件中设置的密码"
    else
        jenkins_password=$(generate_password 16)
        log_info "自动生成随机密码"
    fi
    
    # 显示用户名信息（仅用于日志，不写入 Secret）
    local jenkins_admin_user
    if [[ -n "${JENKINS_ADMIN_USER:-}" ]]; then
        jenkins_admin_user="${JENKINS_ADMIN_USER}"
        log_info "配置文件中设置了自定义用户名: $jenkins_admin_user（注意：需要在 dev-values.yaml 中设置 jenkinsUser）"
    else
        jenkins_admin_user="user"  # Bitnami Jenkins 默认用户名
        log_info "使用 Bitnami 默认用户名: $jenkins_admin_user（dev-values.yaml 中应注释掉 jenkinsUser）"
    fi
    
    log_info "生成 Jenkins 密钥（仅包含密码）..."
    
    # 获取 Helm Release 名称（必须与 deploy-jenkins.sh 中的 Helm Release 名称一致）
    # 默认使用 jenkins-{project_id} 格式，与 Chart 的 Secret 命名规则一致
    local helm_release_name="${HELM_RELEASE_NAME:-jenkins-sunmoonai}"
    
    # 创建或更新密钥（只包含密码，不包含用户名）
    # 重要：添加 Helm 管理的标签和注解，让 Helm 认为它管理这个 Secret
    # 这样 Helm Chart 安装时就不会报错说 Secret 已存在但缺少 Helm 元数据
    if [[ "$secret_exists" == "true" ]]; then
        # Secret 已存在，先删除再重新创建（确保标签和注解正确）
        log_info "更新现有 Secret（添加 Helm 管理标签和注解）..."
        kubectl delete secret "$JENKINS_SECRET_NAME" -n "$namespace" 2>/dev/null || true
    fi
    
    # 创建 Secret（使用 YAML 模板方式，确保标签和注解正确）
    log_info "创建 Secret（带 Helm 管理标签和注解，Release: $helm_release_name）..."
    local secret_yaml=$(cat <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: $JENKINS_SECRET_NAME
  namespace: $namespace
  labels:
    app.kubernetes.io/managed-by: Helm
  annotations:
    meta.helm.sh/release-name: $helm_release_name
    meta.helm.sh/release-namespace: $namespace
type: Opaque
data:
  $JENKINS_AUTH_SECRET_PASSWORD_KEY: $(echo -n "$jenkins_password" | base64 -w 0)
EOF
)
    echo "$secret_yaml" | kubectl apply -f -
    
    if [[ $? -eq 0 ]]; then
        log_success "✅ Jenkins 密钥${secret_exists:+更新}${secret_exists:-创建}成功: $JENKINS_SECRET_NAME"
        log_info "Jenkins 用户名: $jenkins_admin_user（通过 jenkinsUser values 参数设置，不在 Secret 中）"
        log_info "Jenkins 密码: $jenkins_password"
        
        # 注意：现在使用 Bitnami 默认用户名 "user"，不自定义用户名
        # 如果配置文件中设置了自定义用户名（JENKINS_ADMIN_USER），则自动更新 dev-values.yaml
        # 如果使用默认值，dev-values.yaml 中应注释掉 jenkinsUser，让 Chart 使用默认值
        if [[ -n "${JENKINS_ADMIN_USER:-}" ]]; then
            # 计算 dev-values.yaml 的正确路径（使用 PROJECT_ROOT）
            local dev_values_file="$PROJECT_ROOT/resources/custom-values/dev-values.yaml"
            if [[ -f "$dev_values_file" ]]; then
                log_info "检测到自定义用户名，更新 dev-values.yaml 中的 jenkinsUser 为: $jenkins_admin_user"
                # 使用 sed 更新 jenkinsUser 配置
                if sed -i "s/^jenkinsUser:.*/jenkinsUser: $jenkins_admin_user/" "$dev_values_file" 2>/dev/null; then
                    log_success "✅ 已更新 dev-values.yaml 中的 jenkinsUser"
                else
                    log_warn "⚠️ 无法自动更新 dev-values.yaml，请手动设置 jenkinsUser: $jenkins_admin_user"
                fi
            else
                log_warn "⚠️ dev-values.yaml 文件不存在: $dev_values_file"
                log_info "提示: 请手动更新 dev-values.yaml 中的 jenkinsUser 为: $jenkins_admin_user"
            fi
        else
            log_info "使用 Bitnami 默认用户名 'user'，dev-values.yaml 中应注释掉 jenkinsUser"
        fi
    else
        log_error "❌ Jenkins 密钥${secret_exists:+更新}${secret_exists:-创建}失败"
        return 1
    fi
    
    return 0
}

# 删除 Jenkins 密钥
delete_jenkins_secrets() {
    local namespace="${1:-cicd-platform-dev}"
    
    log_info "删除 Jenkins 密钥..."
    log_info "命名空间: $namespace"
    
    if kubectl delete secret "$JENKINS_SECRET_NAME" -n "$namespace" 2>/dev/null; then
        log_success "✅ Jenkins 密钥删除成功"
    else
        log_warn "⚠️ Jenkins 密钥不存在或删除失败"
    fi
    
    return 0
}

# 检查密钥状态
check_secrets_status() {
    local namespace="${1:-cicd-platform-dev}"
    
    log_info "检查 Jenkins 密钥状态..."
    log_info "命名空间: $namespace"
    
    if kubectl get secret "$JENKINS_SECRET_NAME" -n "$namespace" >/dev/null 2>&1; then
        log_success "✅ Jenkins 密钥存在: $JENKINS_SECRET_NAME"
        kubectl get secret "$JENKINS_SECRET_NAME" -n "$namespace"
    else
        log_error "❌ Jenkins 密钥不存在: $JENKINS_SECRET_NAME"
        return 1
    fi
    
    return 0
}

# 解析命令行参数（支持 --cluster 或 -c）
declare -a PARSED_ARGS


# 主函数
main() {
    # 使用解析后的参数（已移除 --cluster 参数）
    set -- "${ORIGINAL_ARGS[@]}"
    set -- "${PARSED_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    local action="${1:-deploy}"
    local namespace="${2:-cicd-platform-dev}"
    
    # 建立远程 k8s 连接（使用统一模板中的连接管理函数）
    if ! read_k8s_config; then
        log_error "无法读取 Kubernetes 配置文件"; exit 1; fi
    if ! setup_kubectl_environment; then
        log_error "无法建立 Kubernetes 连接"; exit 1; fi
    
    # 加载配置
    load_config
    
    case "$action" in
        "deploy")
            deploy_jenkins_secrets "$namespace"
            ;;
        "uninstall")
            delete_jenkins_secrets "$namespace"
            ;;
        "status")
            check_secrets_status "$namespace"
            ;;
        "help"|"-h"|"--help")
            echo "用法: $0 <action> [namespace]"
            echo ""
            echo "操作:"
            echo "  deploy           部署 Jenkins 密钥（默认）"
            echo "  uninstall        删除 Jenkins 密钥"
            echo "  status           检查密钥状态"
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
