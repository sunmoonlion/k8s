#!/bin/bash

# Harbor 递归部署脚本
# 基于递归架构设计原则的两级部署逻辑

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 保存 Harbor 脚本的目录路径（统一部署模板会重新定义 SCRIPT_DIR）
HARBOR_SCRIPT_DIR="$SCRIPT_DIR"

# 导入统一部署模板（包含日志函数）
source "$PROJECT_ROOT/../../../utils/unified-deployment-template.sh"

# 恢复 Harbor 脚本的目录路径
SCRIPT_DIR="$HARBOR_SCRIPT_DIR"

# 解析命令行参数（优先于配置文件加载，确保命令行参数优先级最高）

# 先解析命令行参数（如果提供）
# 保存原始参数，以便在 main 函数中使用
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    unified_parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

# 处理 CLUSTER 环境变量（如果提供）
# 支持 C1/C2 或 1/2 格式，统一转换为 C{数字}；支持 KIND 表示本地 Kind 集群
if [[ -n "${CLUSTER:-}" ]]; then
    if [[ "$CLUSTER" =~ ^[0-9]+$ ]]; then
        export CLUSTER="C${CLUSTER}"
    elif [[ "${CLUSTER^^}" == "KIND" ]]; then
        export CLUSTER="KIND"
    elif [[ ! "$CLUSTER" =~ ^C[0-9]+$ ]]; then
        log_error "无效的 CLUSTER 环境变量值: $CLUSTER (应为数字如 1 或 2，格式如 C1/C2，或 KIND)"
        exit 1
    fi
fi

# 加载 Harbor 部署配置文件
HARBOR_CONFIG_FILE="$SCRIPT_DIR/deploy-harbor.conf"
if [[ -f "$HARBOR_CONFIG_FILE" ]]; then
    source "$HARBOR_CONFIG_FILE"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
    
    log_info "已加载 Harbor 配置文件: $HARBOR_CONFIG_FILE"
else
    log_error "缺少 Harbor 配置文件: $HARBOR_CONFIG_FILE"
    exit 1
fi

# 加载总配置文件（如果存在）
SUNMOONAI_CONFIG_FILE="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")/infrastructure/deploy-infrastructure-all/deploy-infrastructure-all.conf"
if [[ -f "$SUNMOONAI_CONFIG_FILE" ]]; then
    # 保存当前的 CLUSTER（如果已设置），防止被配置文件默认值覆盖
    # 注意：环境变量优先级高于配置文件默认值
    saved_cluster="${CLUSTER:-}"
    
    source "$SUNMOONAI_CONFIG_FILE"
    
    # 如果之前设置了 CLUSTER（通过环境变量），恢复它
    if [[ -n "$saved_cluster" ]]; then
        export CLUSTER="$saved_cluster"
    fi
    
    # 重新应用集群配置映射（使用恢复的 CLUSTER）
    if [[ -f "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh" ]]; then
        apply_cluster_config_mapping
    fi
    
    log_info "已加载总配置文件: $SUNMOONAI_CONFIG_FILE"
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "使用集群配置: $CLUSTER"
    fi
    
    # 使用总配置文件中的 Harbor 密码（如果存在）
    if [[ -n "${HARBOR_ADMIN_PASSWORD:-}" ]]; then
        log_info "使用总配置文件中的 Harbor 密码"
    fi
    if [[ -n "${HARBOR_PROJECT_NAME:-}" ]]; then
        log_info "使用总配置文件中的 Harbor 项目名: $HARBOR_PROJECT_NAME"
    fi
fi

# 加载 CI/CD 平台级配置（含 C1/C2/KIND 的 harbor_enabled），供「当前集群是否部署 Harbor」判断
CICD_PLATFORM_CONF="$(dirname "$(dirname "$SCRIPT_DIR")")/deploy-cicd-platform-all/deploy-cicd-platform-all.conf"
if [[ -f "$CICD_PLATFORM_CONF" ]]; then
    saved_cluster_cicd="${CLUSTER:-}"
    source "$CICD_PLATFORM_CONF"
    [[ -n "$saved_cluster_cicd" ]] && export CLUSTER="$saved_cluster_cicd"
    if [[ -f "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh"
        apply_cluster_config_mapping
    fi
fi

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="harbor"
DEFAULT_ENVIRONMENT="development"

# 检查命名空间是否存在
check_namespace() {
    local namespace="$1"
    
    # 确保 Kubernetes 连接已建立
    if ! setup_kubectl_environment; then
        log_error "❌ 无法建立 Kubernetes 连接"
        return 1
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

# 处理 Harbor 特定的 values 文件
process_harbor_values() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    
    # 确定环境目录
    local env_dir=""
    case "$environment" in
        "production")
            env_dir="values-prod"
            ;;
        "development")
            env_dir="values-dev"
            ;;
        *)
            env_dir="values-dev"  # 默认使用开发环境
            ;;
    esac
    
    # 检查环境特定的 values 文件
    local env_values_file=""
    
    case "$environment" in
        "production")
            env_values_file="$PROJECT_ROOT/resources/custom-values/prod-values.yaml"
            ;;
        "development")
            local cluster_lower="$(echo "${CLUSTER:-}" | tr '[:upper:]' '[:lower:]')"
            if [[ "$cluster_lower" == "kind" ]]; then
                local pv_pvc_file="$PROJECT_ROOT/resources/custom-values/harbor-kind-pv-pvc.yaml"
                kubectl apply -f "$pv_pvc_file" >&2
                env_values_file="$PROJECT_ROOT/resources/custom-values/dev-values-kind.yaml"
            else
                env_values_file="$PROJECT_ROOT/resources/custom-values/dev-values.yaml"
            fi
            ;;
        *)
            env_values_file="$PROJECT_ROOT/resources/custom-values/dev-values.yaml"
            ;;
    esac

    if [[ -f "$env_values_file" ]]; then
        log_info "使用环境特定配置: $env_values_file" >&2
        
        # 创建临时 values 文件
        local harbor_values_file=$(mktemp)
        cp "$env_values_file" "$harbor_values_file"
        
        # 替换基础变量
        local created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        local admin_password="${project_id}_harbor_$(date +%Y)!"
        local harbor_db_password="${project_id}_harbor_$(date +%Y)!"
        local redis_password="${project_id}_redis_$(date +%Y)!"
        
        # 基础变量替换
        sed -i "s/{{PROJECT_ID}}/$project_id/g" "$harbor_values_file"
        sed -i "s/{{NAMESPACE}}/$namespace/g" "$harbor_values_file"
        sed -i "s/{{ENVIRONMENT}}/$environment/g" "$harbor_values_file"
        sed -i "s/{{COMPONENT_NAME}}/harbor/g" "$harbor_values_file"
        sed -i "s/{{CREATED_AT}}/$created_at/g" "$harbor_values_file"
        sed -i "s/{{ADMIN_PASSWORD}}/$admin_password/g" "$harbor_values_file"
        
        # 从 deploy-harbor.conf 文件中读取的变量替换
        if [[ -n "${HARBOR_EXTERNAL_HOST:-}" ]]; then
            sed -i "s/{{HARBOR_EXTERNAL_HOST}}/${HARBOR_EXTERNAL_HOST}/g" "$harbor_values_file"
        fi
        if [[ -n "${HARBOR_EXTERNAL_PORT:-}" ]]; then
            sed -i "s/{{HARBOR_EXTERNAL_PORT}}/${HARBOR_EXTERNAL_PORT}/g" "$harbor_values_file"
        fi
        if [[ -n "${HARBOR_PROJECT_ID:-}" ]]; then
            sed -i "s/{{HARBOR_PROJECT_ID}}/${HARBOR_PROJECT_ID}/g" "$harbor_values_file"
        fi
        if [[ -n "${HARBOR_NAMESPACE:-}" ]]; then
            sed -i "s/{{HARBOR_NAMESPACE}}/${HARBOR_NAMESPACE}/g" "$harbor_values_file"
        fi
        
        # Harbor Secret 相关变量替换
        if [[ -n "${HARBOR_AUTH_SECRET_NAME:-}" ]]; then
            sed -i "s/{{HARBOR_AUTH_SECRET_NAME}}/${HARBOR_AUTH_SECRET_NAME}/g" "$harbor_values_file"
        fi
        if [[ -n "${HARBOR_AUTH_SECRET_PASSWORD_KEY:-}" ]]; then
            sed -i "s/{{HARBOR_AUTH_SECRET_PASSWORD_KEY}}/${HARBOR_AUTH_SECRET_PASSWORD_KEY}/g" "$harbor_values_file"
        fi
        if [[ -n "${HARBOR_TLS_SECRET_NAME:-}" ]]; then
            sed -i "s/{{HARBOR_TLS_SECRET_NAME}}/${HARBOR_TLS_SECRET_NAME}/g" "$harbor_values_file"
        fi
        
        # 替换密码变量（需要转义特殊字符）
        sed -i "s/\${PROJECT_ID}_harbor_\$(date +%Y)!/${harbor_db_password}/g" "$harbor_values_file"
        sed -i "s/\${PROJECT_ID}_redis_\$(date +%Y)!/${redis_password}/g" "$harbor_values_file"
        
        # 替换 HARBOR_TLS_ENABLED 变量
        # 判断 TLS 是否终止在 Traefik：
        # - 如果 values 文件中包含 "ingress.core.tls: false" 或 "tls: false"（在 ingress.core 下），
        #   说明 TLS 终止在 Traefik，HARBOR_TLS_ENABLED 不会被使用
        # - 如果 values 文件中包含 "tls.enabled: {{HARBOR_TLS_ENABLED}}"（在 harbor 下），
        #   说明需要这个配置项来控制 Harbor 的 TLS
        local tls_terminated_at_traefik=false
        # 检查 ingress.core.tls 是否为 false（更精确的匹配）
        if grep -A 20 "ingress:" "$harbor_values_file" | grep -A 10 "core:" | grep -q "tls:.*false"; then
            tls_terminated_at_traefik=true
            log_info "检测到 TLS 终止在 Traefik（ingress.core.tls: false），HARBOR_TLS_ENABLED 配置项不会被使用" >&2
        fi
        
        # 只有当 TLS 不在 Traefik 终止时，才替换 HARBOR_TLS_ENABLED 变量
        # 如果 values 文件中包含 {{HARBOR_TLS_ENABLED}} 占位符，说明需要这个配置项
        if [[ "$tls_terminated_at_traefik" == "false" ]] && grep -q "{{HARBOR_TLS_ENABLED}}" "$harbor_values_file" && [[ -n "${HARBOR_TLS_ENABLED:-}" ]]; then
            sed -i "s/{{HARBOR_TLS_ENABLED}}/${HARBOR_TLS_ENABLED}/g" "$harbor_values_file"
            log_info "已替换 HARBOR_TLS_ENABLED 变量: ${HARBOR_TLS_ENABLED}" >&2
        elif [[ "$tls_terminated_at_traefik" == "true" ]]; then
            log_info "TLS 终止在 Traefik，跳过 HARBOR_TLS_ENABLED 变量替换" >&2
        elif ! grep -q "{{HARBOR_TLS_ENABLED}}" "$harbor_values_file"; then
            log_info "values 文件中不包含 {{HARBOR_TLS_ENABLED}} 占位符，跳过变量替换" >&2
        fi
        
        # 使用统一模板的变量替换函数（若函数存在则调用）
        if type replace_template_variables >/dev/null 2>&1; then
          replace_template_variables "$harbor_values_file" "$project_id" "$namespace" "harbor" "$environment"
        fi
        
        echo "$harbor_values_file"
        return 0
    else
        log_error "缺少环境特定 values 文件: $env_values_file"
        return 1
    fi
}

# 定义 Harbor 所需镜像
define_required_images() {
    local environment="$1"
    
    case "$environment" in
        "development"|"dev")
            # 开发环境：Harbor 核心镜像
            echo "bitnami/harbor-core:${HARBOR_CORE_IMAGE_VERSION:-2.13.2-debian-12-r3}|true"
            echo "bitnami/harbor-portal:${HARBOR_PORTAL_IMAGE_VERSION:-2.13.2-debian-12-r1}|true"
            echo "bitnami/harbor-jobservice:${HARBOR_JOBSERVICE_IMAGE_VERSION:-2.13.2-debian-12-r3}|true"
            echo "bitnami/harbor-registry:${HARBOR_REGISTRY_IMAGE_VERSION:-2.13.2-debian-12-r2}|true"
            echo "bitnami/harbor-registryctl:${HARBOR_REGISTRYCTL_IMAGE_VERSION:-2.13.2-debian-12-r3}|true"
            echo "bitnami/harbor-adapter-trivy:${HARBOR_TRIVY_ADAPTER_IMAGE_VERSION:-2.13.2-debian-12-r2}|true"
            echo "bitnami/harbor-exporter:${HARBOR_EXPORTER_IMAGE_VERSION:-2.13.2-debian-12-r2}|true"
            echo "bitnami/nginx:${HARBOR_NGINX_IMAGE_VERSION:-1.29.1-debian-12-r0}|true"
            echo "bitnami/os-shell:${HARBOR_OS_SHELL_IMAGE_VERSION:-12-debian-12-r50}|true"
            ;;
        "production"|"prod")
            # 生产环境：Harbor 核心镜像 + 监控镜像
            echo "bitnami/harbor-core:${HARBOR_CORE_IMAGE_VERSION:-2.13.2-debian-12-r3}|true"
            echo "bitnami/harbor-portal:${HARBOR_PORTAL_IMAGE_VERSION:-2.13.2-debian-12-r1}|true"
            echo "bitnami/harbor-jobservice:${HARBOR_JOBSERVICE_IMAGE_VERSION:-2.13.2-debian-12-r3}|true"
            echo "bitnami/harbor-registry:${HARBOR_REGISTRY_IMAGE_VERSION:-2.13.2-debian-12-r2}|true"
            echo "bitnami/harbor-registryctl:${HARBOR_REGISTRYCTL_IMAGE_VERSION:-2.13.2-debian-12-r3}|true"
            echo "bitnami/harbor-adapter-trivy:${HARBOR_TRIVY_ADAPTER_IMAGE_VERSION:-2.13.2-debian-12-r2}|true"
            echo "bitnami/harbor-exporter:${HARBOR_EXPORTER_IMAGE_VERSION:-2.13.2-debian-12-r2}|true"
            echo "bitnami/nginx:${HARBOR_NGINX_IMAGE_VERSION:-1.29.1-debian-12-r0}|true"
            echo "bitnami/os-shell:${HARBOR_OS_SHELL_IMAGE_VERSION:-12-debian-12-r50}|true"
            ;;
        *)
            # 默认：只使用核心镜像
            echo "bitnami/harbor-core:${HARBOR_CORE_IMAGE_VERSION:-2.13.2-debian-12-r3}|true"
            echo "bitnami/harbor-portal:${HARBOR_PORTAL_IMAGE_VERSION:-2.13.2-debian-12-r1}|true"
            echo "bitnami/harbor-jobservice:${HARBOR_JOBSERVICE_IMAGE_VERSION:-2.13.2-debian-12-r3}|true"
            echo "bitnami/harbor-registry:${HARBOR_REGISTRY_IMAGE_VERSION:-2.13.2-debian-12-r2}|true"
            echo "bitnami/harbor-registryctl:${HARBOR_REGISTRYCTL_IMAGE_VERSION:-2.13.2-debian-12-r3}|true"
            echo "bitnami/harbor-adapter-trivy:${HARBOR_TRIVY_ADAPTER_IMAGE_VERSION:-2.13.2-debian-12-r2}|true"
            echo "bitnami/harbor-exporter:${HARBOR_EXPORTER_IMAGE_VERSION:-2.13.2-debian-12-r2}|true"
            echo "bitnami/nginx:${HARBOR_NGINX_IMAGE_VERSION:-1.29.1-debian-12-r0}|true"
            echo "bitnami/os-shell:${HARBOR_OS_SHELL_IMAGE_VERSION:-12-debian-12-r50}|true"
            ;;
    esac
}

# 部署 Harbor 核心服务
deploy_harbor_core() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"

    log_info "开始部署 Harbor 核心服务..."
    log_info "项目: $project_id"
    log_info "命名空间: $namespace"
    log_info "环境: $environment"
    log_info "干运行: $dry_run"

    # 检查命名空间是否存在
    check_namespace "$namespace"

    # 检查前置条件
    check_prerequisites

    # 验证 Harbor 配置
    validate_harbor_config

    # 处理 Harbor 特定的 values 文件
    local harbor_values_file=$(process_harbor_values "$project_id" "$namespace" "$environment")
    
    if [[ $? -eq 0 ]] && [[ -n "$harbor_values_file" ]]; then
        # 使用 Harbor 特定的 values 文件
        log_info "使用 Harbor 特定配置: $harbor_values_file"
        
        # 获取资源目录
        local resources_dir="$PROJECT_ROOT/resources/harbor"
        
        # 构建 Helm 命令
        local helm_cmd="helm upgrade --install ${project_id}-harbor $resources_dir"
        helm_cmd="$helm_cmd --namespace $namespace"
        helm_cmd="$helm_cmd --values $resources_dir/values.yaml"
        helm_cmd="$helm_cmd --values $harbor_values_file"
        helm_cmd="$helm_cmd --set global.projectId=$project_id"
        helm_cmd="$helm_cmd --set global.namespace=$namespace"
        
        if [[ "$dry_run" == "true" ]]; then
            helm_cmd="$helm_cmd --dry-run"
            log_info "执行干运行部署..."
        else
            log_info "执行实际部署..."
        fi
        
        # 执行 Helm 命令
        log_info "执行命令: $helm_cmd"
        local helm_result
        helm_result=$(eval "$helm_cmd" 2>&1)
        local helm_exit_code=$?
        
        if [[ $helm_exit_code -eq 0 ]]; then
            if [[ "$dry_run" == "true" ]]; then
                log_success "✅ Harbor 干运行部署成功！"
            else
                log_success "✅ Harbor 部署成功！"
            fi
            
            # 清理临时文件
            rm -f "$harbor_values_file"
            
            if [[ "$dry_run" != "true" ]]; then
                show_deployment_info "$project_id" "$namespace"
            fi
            return 0
        else
            # 检查是否是 StatefulSet 更新限制错误或 PVC 存储类错误
            if echo "$helm_result" | grep -q "updates to statefulset spec for fields other than" || echo "$helm_result" | grep -q "StorageClassName.*local-storage" || echo "$helm_result" | grep -q "spec is immutable after creation"; then
                log_warn "检测到 StatefulSet 更新限制或 PVC 存储类冲突，尝试强制清理后重新部署..."
                
                # 强制删除所有 Harbor 相关的 StatefulSet 和 PVC
                log_info "正在强制删除所有 Harbor 相关资源..."
                
                # 先删除 StatefulSet（按顺序删除）
                log_info "删除 StatefulSet..."
                kubectl delete statefulset "${project_id}-harbor-trivy" -n "$namespace" --grace-period=0 >/dev/null 2>&1 || true
                sleep 2
                kubectl delete statefulset "${project_id}-harbor-jobservice" -n "$namespace" --grace-period=0 >/dev/null 2>&1 || true
                sleep 2
                kubectl delete statefulset "${project_id}-harbor-registry" -n "$namespace" --grace-period=0 >/dev/null 2>&1 || true
                sleep 5
                
                # 再删除 PVC（按顺序删除）
                log_info "删除 PVC..."
                # 删除所有 Harbor 相关的 PVC，包括可能卡在 Terminating 状态的
                for pvc in $(kubectl get pvc -n "$namespace" -o name | grep harbor); do
                    log_info "正在删除 $pvc"
                    kubectl delete $pvc -n "$namespace" --grace-period=0 --force >/dev/null 2>&1 || true
                    # 防止卡死，强制移除 finalizer
                    kubectl patch $pvc -n "$namespace" -p '{"metadata":{"finalizers":null}}' --type=merge >/dev/null 2>&1 || true
                    sleep 2
                done
                sleep 5
                
                log_success "✅ Harbor 相关资源删除成功"
                sleep 3
                
                # 重新尝试部署
                log_info "重新尝试部署..."
                if eval "$helm_cmd"; then
                    if [[ "$dry_run" == "true" ]]; then
                        log_success "✅ Harbor 干运行部署成功！"
                    else
                        log_success "✅ Harbor 部署成功！"
                    fi
                    
                    # 清理临时文件
                    rm -f "$harbor_values_file"
                    
                    if [[ "$dry_run" != "true" ]]; then
                        show_deployment_info "$project_id" "$namespace"
                    fi
                    return 0
                else
                    log_error "❌ --cluster 参数需要指定值（格式：C{数字}，如 C1, C2, C3 等）"
                    return 1
                fi
            else
                log_error "❌ Harbor 部署失败！"
                log_error "错误信息: $helm_result"
                rm -f "$harbor_values_file"
                return 1
            fi
        fi
    else
        log_error "无法处理 Harbor values 文件"
        return 1
    fi
}

# 部署子级组件（按优先级）
deploy_sub_components_by_priority() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始基于优先级的子级组件部署..."
    
    # 定义组件部署信息（组件名:启用标志:优先级:描述:脚本路径）
    local components=(
        "secrets:${secrets_enabled:-false}:${secrets_priority:-2000}:Harbor Secrets:$SCRIPT_DIR/secrets/deploy-secrets-all/deploy-secrets-all.sh"
        "middleware:${middleware_enabled:-false}:${middleware_priority:-1000}:Traefik 中间件:$SCRIPT_DIR/../middleware/deploy-middleware-all/deploy-middleware-all.sh"
        "ingress:${ingress_enabled:-false}:${ingress_priority:-100}:Ingress 配置:$SCRIPT_DIR/../ingress/deploy-ingress-all/deploy-ingress-all.sh"
    )
    
    # 先过滤出启用的组件，然后按优先级排序
    local enabled_components=()
    local disabled_components=()
    
    for component_info in "${components[@]}"; do
        IFS=':' read -r name enabled priority description script_path <<< "$component_info"
        if [[ "$enabled" == "true" ]]; then
            enabled_components+=("$component_info")
        else
            disabled_components+=("$component_info")
        fi
    done
    
    # 根据启用组件数量决定是否进行优先级排序
    if [[ ${#enabled_components[@]} -gt 1 ]]; then
        # 多个组件启用时，按优先级排序（数值越大优先级越高）
        IFS=$'\n' sorted_enabled_components=($(printf '%s\n' "${enabled_components[@]}" | sort -t: -k3 -nr))
        log_info "📋 子级组件部署顺序（按优先级排序）："
        
        for component_info in "${sorted_enabled_components[@]}"; do
            IFS=':' read -r name enabled priority description script_path <<< "$component_info"
            log_info "  🚀 $priority - $description"
        done
    elif [[ ${#enabled_components[@]} -eq 1 ]]; then
        # 只有一个组件启用时，直接使用，无需排序
        sorted_enabled_components=("${enabled_components[@]}")
        IFS=':' read -r name enabled priority description script_path <<< "${enabled_components[0]}"
        log_info "📋 子级组件部署顺序（单个组件，无需排序）："
        log_info "  🚀 $description"
    else
        # 没有启用的组件
        sorted_enabled_components=()
        log_info "📋 子级组件部署顺序：无启用的组件"
    fi
    
    # 显示禁用的组件
    if [[ ${#disabled_components[@]} -gt 0 ]]; then
        log_info "  ⏭️  禁用的组件："
        for component_info in "${disabled_components[@]}"; do
            IFS=':' read -r name enabled priority description script_path <<< "$component_info"
            log_info "    $description (${name}_enabled=false)"
        done
    fi
    
    # 部署启用的组件
    for component_info in "${sorted_enabled_components[@]}"; do
        IFS=':' read -r name enabled priority description script_path <<< "$component_info"
        
        if [[ ${#enabled_components[@]} -gt 1 ]]; then
            log_info "🚀 部署 $description (优先级: $priority)..."
        else
            log_info "🚀 部署 $description..."
        fi
        
        if [[ -f "$script_path" ]]; then
            local original_dir="$(pwd)"
            cd "$(dirname "$script_path")"
            
            if ./"$(basename "$script_path")" "$project_id" "$namespace" "$environment" "$dry_run"; then
                log_success "✅ $description 部署成功"
            else
                log_error "❌ $description 部署失败"
                cd "$original_dir"
                return 1
            fi
            
            cd "$original_dir"
        else
            log_warn "⚠️  $description 部署脚本不存在: $script_path"
        fi
    done
    
    log_success "✅ 子级组件部署完成！"
}

# 部署本级专属组件
deploy_current_level_components() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始部署 Harbor 本级专属组件..."
    
    # Harbor 本级专属部署逻辑
    # 例如：Harbor 核心服务配置、监控配置、日志配置等
    
    # 1. 配置 Harbor 核心服务
    log_info "🔧 配置 Harbor 核心服务..."
    configure_harbor_core_services "$project_id" "$namespace" "$environment"
    
    # 2. 配置 Harbor 监控
    log_info "📊 配置 Harbor 监控..."
    configure_harbor_monitoring "$project_id" "$namespace" "$environment"
    
    # 3. 配置 Harbor 日志
    log_info "📝 配置 Harbor 日志..."
    configure_harbor_logging "$project_id" "$namespace" "$environment"
    
    # 4. 验证 Harbor 部署
    log_info "✅ 验证 Harbor 部署..."
    validate_harbor_deployment "$project_id" "$namespace" "$environment"
    
    log_success "✅ Harbor 本级专属组件部署完成！"
}

# 配置 Harbor 核心服务
configure_harbor_core_services() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    
    log_info "配置 Harbor 核心服务参数..."
    
    # 这里可以添加 Harbor 核心服务的特定配置
    # 例如：调整资源限制、配置环境变量等
    
    log_success "Harbor 核心服务配置完成"
}

# 配置 Harbor 监控
configure_harbor_monitoring() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    
    log_info "配置 Harbor 监控组件..."
    
    # 这里可以添加 Harbor 监控的特定配置
    # 例如：配置 Prometheus 监控、Grafana 仪表板等
    
    log_success "Harbor 监控配置完成"
}

# 配置 Harbor 日志
configure_harbor_logging() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    
    log_info "配置 Harbor 日志组件..."
    
    # 这里可以添加 Harbor 日志的特定配置
    # 例如：配置 ELK 日志收集、日志轮转等
    
    log_success "Harbor 日志配置完成"
}

# 验证 Harbor 部署
validate_harbor_deployment() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    
    log_info "验证 Harbor 整体部署状态..."
    
    # 检查 Harbor 服务状态
    if kubectl get pods -n "$namespace" -l "app.kubernetes.io/instance=$project_id" | grep -q "Running"; then
        log_success "Harbor Pod 运行正常"
    else
        log_warn "Harbor Pod 状态异常"
    fi
    
    # 检查 Harbor 服务可用性
    if kubectl get svc -n "$namespace" -l "app.kubernetes.io/instance=$project_id" | grep -q "harbor"; then
        log_success "Harbor 服务配置正常"
    else
        log_warn "Harbor 服务配置异常"
    fi
    
    log_success "Harbor 部署验证完成"
}

# 创建 Harbor 项目
create_harbor_project() {
    local project_name="$1"
    local harbor_host="$2"
    local harbor_port="$3"
    local admin_user="$4"
    local admin_password="$5"
    # 可选的 SSH 参数（用于在控制平面节点上执行）
    local ssh_host="${6:-}"
    local ssh_user="${7:-}"
    local ssh_key="${8:-}"
    local ssh_port="${9:-22}"
    
    log_info "创建 Harbor 项目: $project_name"
    
    # 构建 SSH 命令（如果提供了 SSH 信息，在控制平面节点上执行）
    local ssh_cmd=""
    if [[ -n "$ssh_host" && -n "$ssh_user" ]]; then
        local ssh_key_option=""
        if [[ -n "$ssh_key" && -f "$ssh_key" ]]; then
            ssh_key_option="-i $ssh_key"
        fi
        local ssh_port_option=""
        if [[ -n "$ssh_port" && "$ssh_port" != "22" ]]; then
            ssh_port_option="-p $ssh_port"
        fi
        ssh_cmd="ssh $ssh_key_option $ssh_port_option -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes $ssh_user@$ssh_host"
    fi
    
    # 创建项目（如果项目已存在，API 会返回 409，我们会在下面处理）
    # 注意：Harbor 中，项目创建者（管理员）默认有所有权限，包括推送权限
    # 使用 curl -w 获取 HTTP 状态码，以便准确判断创建结果
    local create_result=""
    if [[ -n "$ssh_cmd" ]]; then
        # 在控制平面节点上执行
        create_result=$($ssh_cmd "curl -k -s -w \"\\nHTTP_CODE:%{http_code}\" -u \"$admin_user:$admin_password\" -X POST \"https://$harbor_host:$harbor_port/api/v2.0/projects\" -H \"Content-Type: application/json\" -d '{\"project_name\": \"$project_name\", \"metadata\": {\"public\": \"false\"}, \"storage_limit\": -1}'" 2>&1)
    else
        # 在本地执行（可能无法访问）
        create_result=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" -u "$admin_user:$admin_password" -X POST "https://$harbor_host:$harbor_port/api/v2.0/projects" \
            -H "Content-Type: application/json" \
            -d "{\"project_name\": \"$project_name\", \"metadata\": {\"public\": \"false\"}, \"storage_limit\": -1}" 2>&1)
    fi
    local create_exit_code=$?
    
    # 提取 HTTP 状态码和响应体
    local http_code=$(echo "$create_result" | grep "HTTP_CODE:" | cut -d: -f2 | tr -d '\n' || echo "")
    local response_body=$(echo "$create_result" | grep -v "HTTP_CODE:" || echo "")
    
    # 检查创建结果：如果项目已存在（409 Conflict）或创建成功（201 Created），都视为成功
    # Harbor API 返回 409 表示项目已存在，这也是成功的情况
    log_info "创建项目 HTTP 状态码: ${http_code:-unknown}"
    
    # 检查 HTTP 状态码
    if [[ "$http_code" == "201" ]]; then
        # 201 Created：项目创建成功
        log_success "✅ 项目 $project_name 创建成功 (HTTP 201)"
        # 验证管理员权限（管理员应该自动拥有项目所有权限）
        local project_info=""
        if [[ -n "$ssh_cmd" ]]; then
            project_info=$($ssh_cmd "curl -k -s -u \"$admin_user:$admin_password\" \"https://$harbor_host:$harbor_port/api/v2.0/projects/$project_name\"" 2>/dev/null)
        else
            project_info=$(curl -k -s -u "$admin_user:$admin_password" "https://$harbor_host:$harbor_port/api/v2.0/projects/$project_name" 2>/dev/null)
        fi
        if [[ -n "$project_info" ]]; then
            log_info "项目 $project_name 权限验证：管理员拥有所有权限（包括推送）"
        fi
        return 0
    elif [[ "$http_code" == "409" ]]; then
        # 409 Conflict：项目已存在
        log_success "✅ 项目 $project_name 已存在 (HTTP 409)"
        return 0
    elif [[ "$http_code" == "401" ]] || [[ "$http_code" == "403" ]]; then
        # 401/403：认证失败
        log_error "❌ 项目 $project_name 创建失败：认证失败 (HTTP $http_code)"
        log_error "响应内容: $response_body"
        log_error "请检查 Harbor 管理员用户名和密码是否正确"
        return 1
    elif [[ "$http_code" == "000" ]]; then
        # HTTP 000 表示无法连接到服务器（可能是超时或连接失败）
        log_error "❌ 项目 $project_name 创建失败：无法连接到 Harbor API (HTTP 000)"
        log_error "响应内容: $response_body"
        log_error "可能原因："
        log_error "  1. Harbor Ingress 路由尚未生效（需要等待更长时间）"
        log_error "  2. 网络连接问题或 DNS 解析失败"
        log_error "  3. Harbor 服务未完全启动"
        log_error "  4. 连接超时（已设置 15 秒连接超时，30 秒总超时）"
        log_warn "建议：等待 Harbor 服务完全就绪后再重试，或检查 Ingress 路由状态"
        return 1
    elif [[ -n "$http_code" ]]; then
        # 其他 HTTP 错误
        log_error "❌ 项目 $project_name 创建失败 (HTTP $http_code)"
        log_error "响应内容: $response_body"
        return 1
    elif [[ $create_exit_code -ne 0 ]]; then
        # curl 命令执行失败
        log_error "❌ 项目 $project_name 创建失败：curl 命令执行失败 (退出码: $create_exit_code)"
        log_error "响应内容: $response_body"
        return 1
    else
        # 无法获取 HTTP 状态码，但 curl 成功，尝试检查响应内容
        local has_error=$(echo "$response_body" | grep -i "error\|unauthorized\|forbidden" 2>/dev/null || echo "")
        if [[ -n "$has_error" ]]; then
            log_error "❌ 项目 $project_name 创建失败：响应中包含错误信息"
            log_error "响应内容: $response_body"
            return 1
        else
            # 无法确定状态，但也没有明显错误，尝试通过查询项目来验证
            local verify_result=""
            if [[ -n "$ssh_cmd" ]]; then
                verify_result=$($ssh_cmd "curl -k -s -u \"$admin_user:$admin_password\" \"https://$harbor_host:$harbor_port/api/v2.0/projects/$project_name\"" 2>/dev/null)
            else
                verify_result=$(curl -k -s -u "$admin_user:$admin_password" "https://$harbor_host:$harbor_port/api/v2.0/projects/$project_name" 2>/dev/null)
            fi
            if [[ -n "$verify_result" ]] && ! echo "$verify_result" | grep -q "not found\|404"; then
                log_success "✅ 项目 $project_name 创建成功（通过验证确认）"
                return 0
            else
                log_error "❌ 项目 $project_name 创建失败：无法确认项目是否创建成功"
                log_error "响应内容: $response_body"
                return 1
            fi
        fi
    fi
}

# 获取控制平面节点的 SSH 信息（用于 Harbor API 检查）
get_control_plane_ssh_info_for_check() {
    local ssh_port_var="$1"  # 输出变量名：SSH端口
    local ssh_user_var="$2"  # 输出变量名：SSH用户
    local ssh_key_var="$3"   # 输出变量名：SSH密钥路径
    local ssh_host_var="$4"  # 输出变量名：SSH主机地址（公网IP）
    
    # 获取控制平面节点
    local control_plane_nodes=$(kubectl get nodes -l node-role.kubernetes.io/control-plane --no-headers -o custom-columns=":metadata.name" 2>/dev/null || echo "")
    if [[ -z "$control_plane_nodes" ]]; then
        control_plane_nodes=$(kubectl get nodes --no-headers -o custom-columns=":metadata.name" | head -1)
    fi
    local target_node=$(echo "$control_plane_nodes" | head -1)
    local target_node_internal_ip=$(kubectl get node "$target_node" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
    
    if [[ -z "$target_node_internal_ip" ]]; then
        return 1
    fi
    
    # 从配置文件中获取SSH端口信息
    local ssh_port="22"  # 默认端口
    local ssh_user="root"  # 默认用户
    local ssh_key=""  # SSH密钥路径
    local target_node_public_ip=""
    
    # 尝试从总配置文件获取SSH配置
    if [[ -f "$SUNMOONAI_CONFIG_FILE" ]]; then
        # 确定当前集群（从 KUBECONFIG 路径判断，或尝试 C1/C2）
        local cluster_prefix=""
        if [[ "${KUBECONFIG:-}" == *"c1"* ]] || [[ "${KUBECONFIG:-}" == *"cluster-c1"* ]] || [[ "${KUBECONFIG:-}" == *"C1"* ]]; then
            cluster_prefix="C1_"
        elif [[ "${KUBECONFIG:-}" == *"c2"* ]] || [[ "${KUBECONFIG:-}" == *"cluster-c2"* ]] || [[ "${KUBECONFIG:-}" == *"C2"* ]]; then
            cluster_prefix="C2_"
        else
            cluster_prefix="C1_"
        fi
        
        # 查找匹配的服务器配置
        for i in {1..10}; do
            local server_local_ip=$(grep "^${cluster_prefix}SERVER_${i}_LOCAL_IP=" "$SUNMOONAI_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | head -1)
            local server_public_ip=$(grep "^${cluster_prefix}SERVER_${i}_PUBLIC_IP=" "$SUNMOONAI_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | head -1)
            local server_ssh_port=$(grep "^${cluster_prefix}SERVER_${i}_SSH_PORT=" "$SUNMOONAI_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | head -1)
            local server_user=$(grep "^${cluster_prefix}SERVER_${i}_USER=" "$SUNMOONAI_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | head -1)
            local server_secret=$(grep "^${cluster_prefix}SERVER_${i}_SECRET=" "$SUNMOONAI_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | head -1)
            
            if [[ -z "$server_local_ip" ]]; then
                server_local_ip=$(grep "^SERVER_${i}_LOCAL_IP=" "$SUNMOONAI_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | head -1)
                server_public_ip=$(grep "^SERVER_${i}_PUBLIC_IP=" "$SUNMOONAI_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | head -1)
                server_ssh_port=$(grep "^SERVER_${i}_SSH_PORT=" "$SUNMOONAI_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | head -1)
                server_user=$(grep "^SERVER_${i}_USER=" "$SUNMOONAI_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | head -1)
                server_secret=$(grep "^SERVER_${i}_SECRET=" "$SUNMOONAI_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | head -1)
            fi
            
            if [[ "$server_local_ip" == "$target_node_internal_ip" ]]; then
                # 确保SSH端口不为空（如果配置了则使用配置值，否则使用默认值22）
                if [[ -n "$server_ssh_port" ]]; then
                    ssh_port="$server_ssh_port"
                else
                    ssh_port="22"
                fi
                # 确保SSH用户不为空
                if [[ -n "$server_user" ]]; then
                    ssh_user="$server_user"
                else
                    ssh_user="root"
                fi
                ssh_key="${server_secret:-}"
                target_node_public_ip="$server_public_ip"
                break
            fi
        done
    fi
    
    # 使用间接变量赋值返回结果
    # 使用 declare -g 确保设置全局变量，这样即使调用函数中有同名变量也能正确设置
    eval "declare -g $ssh_port_var=\"$ssh_port\""
    eval "declare -g $ssh_user_var=\"$ssh_user\""
    eval "declare -g $ssh_key_var=\"$ssh_key\""
    eval "declare -g $ssh_host_var=\"$target_node_public_ip\""
    
    if [[ -z "$target_node_public_ip" ]]; then
        return 1
    fi
    return 0
}

# 等待 Harbor 服务就绪
wait_for_harbor_ready() {
    local harbor_host="$1"
    local harbor_port="$2"
    local project_id="$3"
    local namespace="$4"
    local max_attempts=60  # 增加等待时间到10分钟
    local attempt=1
    
    log_info "等待 Harbor 服务完全就绪..."
    
    # 获取控制平面节点的 SSH 信息（用于在控制平面节点上执行检查）
    # 注意：不能使用 local，因为需要通过 eval 从函数返回值
    # 先初始化为空，然后通过函数设置
    ssh_port=""
    ssh_user=""
    ssh_key=""
    ssh_host=""
    
    if get_control_plane_ssh_info_for_check ssh_port ssh_user ssh_key ssh_host; then
        log_info "将在控制平面节点 ($ssh_host) 上检查 Harbor API"
    else
        log_warn "无法获取控制平面节点 SSH 信息，将在本地检查 Harbor API（可能无法解析域名）"
        ssh_host=""
    fi
    
    # 构建 SSH 执行命令
    local ssh_key_option=""
    if [[ -n "$ssh_host" && -n "$ssh_key" && -f "$ssh_key" ]]; then
        ssh_key_option="-i $ssh_key"
    fi
    
    # 确保 SSH 端口不为空（默认为 22）
    if [[ -z "$ssh_port" ]]; then
        ssh_port="22"
    fi
    
    while [[ $attempt -le $max_attempts ]]; do
        # 1. 检查所有 Harbor Pod 是否运行
        local harbor_pods=$(kubectl get pods -n "$namespace" -l "app.kubernetes.io/instance=$project_id" --no-headers 2>/dev/null | wc -l)
        local running_pods=$(kubectl get pods -n "$namespace" -l "app.kubernetes.io/instance=$project_id" --no-headers 2>/dev/null | grep "Running" | wc -l)
        
        if [[ $harbor_pods -eq 0 ]]; then
            log_info "等待 Harbor Pod 创建... ($attempt/$max_attempts)"
            sleep 10
            attempt=$((attempt+1))
            continue
        fi
        
        if [[ $running_pods -lt $harbor_pods ]]; then
            log_info "等待 Harbor Pod 启动... ($running_pods/$harbor_pods Running) ($attempt/$max_attempts)"
            sleep 10
            attempt=$((attempt+1))
            continue
        fi
        
        # 2. 检查 Harbor API 是否可访问（在控制平面节点上执行）
        local api_check_result=""
        local api_error_detail=""
        
        if [[ -n "$ssh_host" ]]; then
            # 在控制平面节点上执行检查
            # 先检查 DNS 解析（使用多种方法确保能获取结果）
            local dns_check=""
            # 构建SSH目标（确保用户名不为空）
            local ssh_target=""
            if [[ -n "$ssh_user" ]]; then
                ssh_target="$ssh_user@$ssh_host"
            else
                ssh_target="$ssh_host"
            fi
            
            # 先测试 SSH 连接是否成功
            local ssh_test_result=""
            # 构建 SSH 命令（只有当端口不是默认的 22 时才添加 -p 选项）
            local ssh_port_option=""
            if [[ -n "$ssh_port" && "$ssh_port" != "22" ]]; then
                ssh_port_option="-p $ssh_port"
            fi
            ssh_test_result=$(ssh $ssh_key_option $ssh_port_option -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes "$ssh_target" "echo 'SSH_OK'" 2>&1)
            
            if [[ "$ssh_test_result" != "SSH_OK" ]]; then
                # SSH 连接失败
                api_error_detail="SSH连接失败: 无法连接到控制平面节点 $ssh_target (错误: ${ssh_test_result:0:100})"
                api_check_result="FAIL"
            else
                # SSH 连接成功，继续检查 DNS
                # 方法1: 使用 getent（不需要sudo）
                dns_check=$(ssh $ssh_key_option $ssh_port_option -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes "$ssh_target" "getent hosts $harbor_host 2>&1" 2>/dev/null || echo "")
                
                # 如果 getent 失败，尝试从 /etc/hosts 直接读取（可能需要sudo）
                if [[ -z "$dns_check" ]] || echo "$dns_check" | grep -q "hosts:.*not found"; then
                    # 先尝试不用sudo
                    dns_check=$(ssh $ssh_key_option $ssh_port_option -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes "$ssh_target" "grep '$harbor_host' /etc/hosts 2>&1 | head -1" 2>/dev/null || echo "")
                    # 如果还是失败，尝试用sudo（如果用户有sudo权限）
                    if [[ -z "$dns_check" ]]; then
                        dns_check=$(ssh $ssh_key_option $ssh_port_option -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes "$ssh_target" "sudo grep '$harbor_host' /etc/hosts 2>&1 | head -1" 2>/dev/null || echo "")
                    fi
                fi
                
                # 执行 API 检查并捕获详细错误（使用更可靠的方法）
                local curl_exit_code=0
                local curl_stderr_file=$(mktemp)
                local curl_stdout=""
                
                # 执行 curl 并捕获退出码和错误输出（使用构建好的ssh_target）
                curl_stdout=$(ssh $ssh_key_option $ssh_port_option -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes "$ssh_target" "curl -k -s --connect-timeout 5 -w 'HTTP_CODE:%{http_code}' \"https://$harbor_host:$harbor_port/api/v2.0/systeminfo\" 2>&1" 2>"$curl_stderr_file")
                curl_exit_code=$?
                local ssh_error=$(cat "$curl_stderr_file" 2>/dev/null || echo "")
                rm -f "$curl_stderr_file" 2>/dev/null || true
                
                # 检查结果
                if [[ $curl_exit_code -eq 0 ]] && (echo "$curl_stdout" | grep -q "HTTP_CODE:200\|auth_mode" || echo "$curl_stdout" | grep -q '"auth_mode"'); then
                    api_check_result="OK"
                else
                    api_check_result="FAIL"
                    # 提取错误信息
                    if [[ -z "$dns_check" ]] || echo "$dns_check" | grep -q "hosts:.*not found"; then
                        api_error_detail="DNS解析失败: 无法解析 $harbor_host (getent和/etc/hosts检查都未找到映射)"
                    elif echo "$curl_stdout" | grep -q "Could not resolve host\|Name or service not known"; then
                        api_error_detail="DNS解析失败: 无法解析 $harbor_host"
                    elif echo "$curl_stdout" | grep -q "Connection refused"; then
                        api_error_detail="连接被拒绝: $harbor_host:$harbor_port 可能未启动或端口未开放"
                    elif echo "$curl_stdout" | grep -q "Connection timed out\|Operation timed out"; then
                        api_error_detail="连接超时: 无法连接到 $harbor_host:$harbor_port"
                    elif echo "$curl_stdout" | grep -q "HTTP_CODE:000"; then
                        api_error_detail="HTTP连接失败: curl退出码=$curl_exit_code"
                    elif echo "$curl_stdout" | grep -q "HTTP_CODE:5[0-9][0-9]"; then
                        local http_code=$(echo "$curl_stdout" | grep "HTTP_CODE:" | cut -d: -f2)
                        api_error_detail="Harbor服务错误: HTTP $http_code"
                    elif echo "$curl_stdout" | grep -q "SSL\|certificate"; then
                        api_error_detail="SSL/TLS错误: 证书验证失败"
                    elif [[ -n "$ssh_error" ]]; then
                        api_error_detail="SSH连接错误: $(echo "$ssh_error" | head -1)"
                    else
                        # 提取关键错误信息
                        local error_snippet=$(echo "$curl_stdout" | grep -iE "error|fail|timeout|refused|unable" | head -2 | tr '\n' '; ' | sed 's/; $//')
                        if [[ -n "$error_snippet" ]]; then
                            api_error_detail="连接失败: $error_snippet (curl退出码=$curl_exit_code)"
                        else
                            api_error_detail="API访问失败: curl退出码=$curl_exit_code, DNS检查=$(echo "$dns_check" | head -1)"
                        fi
                    fi
                fi
            fi
        else
            # 本地检查
            local curl_output=""
            curl_output=$(curl -k -v --connect-timeout 5 "https://$harbor_host:$harbor_port/api/v2.0/systeminfo" 2>&1 || echo "")
            
            if echo "$curl_output" | grep -q "HTTP/.*200\|auth_mode"; then
                api_check_result="OK"
            else
                api_check_result="FAIL"
                if echo "$curl_output" | grep -q "Could not resolve host"; then
                    api_error_detail="DNS解析失败: 无法解析 $harbor_host"
                elif echo "$curl_output" | grep -q "Connection refused\|Connection timed out"; then
                    api_error_detail="连接失败: 无法连接到 $harbor_host:$harbor_port"
                else
                    api_error_detail="API访问失败"
                fi
            fi
        fi
        
        if [[ "$api_check_result" != "OK" ]]; then
            if [[ $attempt -eq 1 || $((attempt % 6)) -eq 0 ]]; then
                # 每60秒（6次）输出一次详细错误信息
                log_warn "等待 Harbor API 启动... ($attempt/$max_attempts)"
                if [[ -n "$api_error_detail" && "$api_error_detail" != "API访问失败: " ]]; then
                    log_warn "错误详情: $api_error_detail"
                else
                    log_warn "错误详情: 无法获取详细错误信息，请手动检查"
                fi
                if [[ -n "$ssh_host" && -n "$api_error_detail" ]]; then
                    log_info "提示: 请检查控制平面节点 ($ssh_host) 的DNS映射和Harbor服务状态"
                fi
            else
                log_info "等待 Harbor API 启动... ($attempt/$max_attempts)"
            fi
            sleep 10
            attempt=$((attempt+1))
            continue
        fi
        
        # 3. 检查 Harbor 核心服务健康状态
        local health_check=""
        if [[ -n "$ssh_host" ]]; then
            health_check=$(ssh $ssh_key_option $ssh_port_option -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes "$ssh_target" "curl -k -s --connect-timeout 5 \"https://$harbor_host:$harbor_port/api/v2.0/systeminfo\" 2>/dev/null" 2>/dev/null | jq -r '.auth_mode // empty' 2>/dev/null || echo "")
        else
            health_check=$(curl -k -s --connect-timeout 5 "https://$harbor_host:$harbor_port/api/v2.0/systeminfo" 2>/dev/null | jq -r '.auth_mode // empty' 2>/dev/null || echo "")
        fi
        
        if [[ -z "$health_check" ]]; then
            log_info "等待 Harbor 服务完全初始化... ($attempt/$max_attempts)"
            sleep 10
            attempt=$((attempt+1))
            continue
        fi
        
        # 4. 检查 Harbor 数据库连接（通过 API 检查）
        local db_check=""
        if [[ -n "$ssh_host" ]]; then
            db_check=$(ssh $ssh_key_option $ssh_port_option -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes "$ssh_target" "curl -k -s --connect-timeout 5 \"https://$harbor_host:$harbor_port/api/v2.0/health\" 2>/dev/null" 2>/dev/null | jq -r '.status // empty' 2>/dev/null || echo "")
        else
            db_check=$(curl -k -s --connect-timeout 5 "https://$harbor_host:$harbor_port/api/v2.0/health" 2>/dev/null | jq -r '.status // empty' 2>/dev/null || echo "")
        fi
        
        if [[ "$db_check" != "healthy" ]]; then
            log_info "等待 Harbor 数据库连接... ($attempt/$max_attempts)"
            sleep 10
            attempt=$((attempt+1))
            continue
        fi
        
        # 5. 最终验证：尝试登录
        # 从 Kubernetes Secret 获取 Harbor 管理员密码
        local admin_password="${HARBOR_ADMIN_PASSWORD:-}"
        if [[ -z "$admin_password" ]]; then
            local secret_name="${HARBOR_AUTH_SECRET_NAME:-harbor-secret}"
            local secret_key="${HARBOR_AUTH_SECRET_PASSWORD_KEY:-HARBOR_ADMIN_PASSWORD}"
            admin_password=$(kubectl get secret "$secret_name" -n "$namespace" -o jsonpath="{.data.$secret_key}" 2>/dev/null | base64 -d 2>/dev/null || echo "")
            if [[ -z "$admin_password" ]]; then
                admin_password="${project_id}_harbor_$(date +%Y)!"
            fi
        fi
        local login_check_result=""
        if [[ -n "$ssh_host" ]]; then
            login_check_result=$(ssh $ssh_key_option $ssh_port_option -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes "$ssh_target" "curl -k -s --connect-timeout 5 -u \"admin:$admin_password\" \"https://$harbor_host:$harbor_port/api/v2.0/projects\" >/dev/null 2>&1 && echo 'OK' || echo 'FAIL'" 2>/dev/null || echo "FAIL")
        else
            if curl -k -s --connect-timeout 5 -u "admin:$admin_password" "https://$harbor_host:$harbor_port/api/v2.0/projects" >/dev/null 2>&1; then
                login_check_result="OK"
            else
                login_check_result="FAIL"
            fi
        fi
        
        if [[ "$login_check_result" != "OK" ]]; then
            log_info "等待 Harbor 认证服务就绪... ($attempt/$max_attempts)"
            sleep 10
            attempt=$((attempt+1))
            continue
        fi
        
        log_success "✅ Harbor 服务完全就绪"
        log_info "Harbor 认证模式: $health_check"
        log_info "运行 Pod 数: $running_pods/$harbor_pods"
        return 0
    done
    
    log_error "❌ Harbor 服务启动超时"
    log_error "请检查 Harbor Pod 状态和日志"
    return 1
}

# 推送控制平面镜像到 Harbor
push_control_plane_images() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local harbor_host="$4"
    local harbor_port="$5"
    local admin_user="$6"
    local admin_password="$7"
    local target_project="$8"
    
    log_info "开始推送控制平面镜像到 Harbor..."
    
    # 获取控制平面节点
    local control_plane_nodes=$(kubectl get nodes -l node-role.kubernetes.io/control-plane --no-headers -o custom-columns=":metadata.name" 2>/dev/null || echo "")
    
    if [[ -z "$control_plane_nodes" ]]; then
        log_warn "未找到控制平面节点，尝试使用所有节点"
        control_plane_nodes=$(kubectl get nodes --no-headers -o custom-columns=":metadata.name" | head -1)
    fi
    
    local target_node=$(echo "$control_plane_nodes" | head -1)
    log_info "使用控制平面节点: $target_node"
    
    # 获取控制平面节点的内网IP地址（用于Harbor推送）
    local target_node_internal_ip=$(kubectl get node "$target_node" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
    
    if [[ -z "$target_node_internal_ip" ]]; then
        log_error "无法获取控制平面节点 $target_node 的内网IP地址"
        return 1
    fi
    
    # 从配置文件中获取SSH端口信息
    local ssh_port="22"  # 默认端口
    local ssh_user="root"  # 默认用户
    local ssh_key=""  # SSH密钥路径
    
    # 尝试从总配置文件获取SSH配置
    local target_node_public_ip=""
    if [[ -f "$SUNMOONAI_CONFIG_FILE" ]]; then
        # 确定当前集群（从 KUBECONFIG 路径判断，或尝试 C1/C2）
        local cluster_prefix=""
        if [[ "${KUBECONFIG:-}" == *"c1"* ]] || [[ "${KUBECONFIG:-}" == *"cluster-c1"* ]] || [[ "${KUBECONFIG:-}" == *"C1"* ]]; then
            cluster_prefix="C1_"
        elif [[ "${KUBECONFIG:-}" == *"c2"* ]] || [[ "${KUBECONFIG:-}" == *"cluster-c2"* ]] || [[ "${KUBECONFIG:-}" == *"C2"* ]]; then
            cluster_prefix="C2_"
        else
            # 默认尝试 C1，如果找不到再尝试 C2
            cluster_prefix="C1_"
        fi
        
        # 查找匹配的服务器配置（先尝试带集群前缀的，再尝试不带前缀的）
        for i in {1..10}; do
            local server_type=""
            local server_local_ip=""
            local server_public_ip=""
            local server_ssh_port=""
            local server_user=""
            local server_secret=""
            
            # 先尝试带集群前缀的配置
            server_type=$(grep "^${cluster_prefix}SERVER_${i}_TYPE=" "$SUNMOONAI_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | head -1)
            server_local_ip=$(grep "^${cluster_prefix}SERVER_${i}_LOCAL_IP=" "$SUNMOONAI_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | head -1)
            server_public_ip=$(grep "^${cluster_prefix}SERVER_${i}_PUBLIC_IP=" "$SUNMOONAI_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | head -1)
            server_ssh_port=$(grep "^${cluster_prefix}SERVER_${i}_SSH_PORT=" "$SUNMOONAI_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | head -1)
            server_user=$(grep "^${cluster_prefix}SERVER_${i}_USER=" "$SUNMOONAI_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | head -1)
            server_secret=$(grep "^${cluster_prefix}SERVER_${i}_SECRET=" "$SUNMOONAI_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | head -1)
            
            # 如果没找到，尝试不带前缀的（向后兼容）
            if [[ -z "$server_local_ip" ]]; then
                server_type=$(grep "^SERVER_${i}_TYPE=" "$SUNMOONAI_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | head -1)
                server_local_ip=$(grep "^SERVER_${i}_LOCAL_IP=" "$SUNMOONAI_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | head -1)
                server_public_ip=$(grep "^SERVER_${i}_PUBLIC_IP=" "$SUNMOONAI_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | head -1)
                server_ssh_port=$(grep "^SERVER_${i}_SSH_PORT=" "$SUNMOONAI_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | head -1)
                server_user=$(grep "^SERVER_${i}_USER=" "$SUNMOONAI_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | head -1)
                server_secret=$(grep "^SERVER_${i}_SECRET=" "$SUNMOONAI_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | head -1)
            fi
            
            if [[ "$server_local_ip" == "$target_node_internal_ip" ]]; then
                ssh_port="${server_ssh_port:-22}"
                ssh_user="${server_user:-root}"
                ssh_key="${server_secret:-}"
                target_node_public_ip="$server_public_ip"
                break
            fi
        done
    else
        log_warn "配置文件不存在: $SUNMOONAI_CONFIG_FILE"
    fi
    
    if [[ -z "$target_node_public_ip" ]]; then
        log_error "无法找到控制平面节点 $target_node 对应的公网IP地址"
        return 1
    fi
    
    log_info "控制平面节点: $target_node (内网IP: $target_node_internal_ip, 公网IP: $target_node_public_ip)"
    log_info "Harbor 地址: $harbor_host:$harbor_port"
    log_info "Harbor 项目: $target_project"
    log_info "管理员用户: $admin_user"
    
    # 通过 SSH 连接到控制平面节点并推送镜像
    log_info "开始推送镜像到 Harbor..."
    
    # 创建临时脚本
    local push_script=$(mktemp)
    cat > "$push_script" << EOF
#!/bin/bash
set -e

echo "开始镜像推送..."

# 检查 nerdctl 是否可用
if ! command -v nerdctl >/dev/null 2>&1; then
    echo 'ERROR: nerdctl not found'
    exit 1
fi
echo 'nerdctl 可用'

# 登录到 Harbor（恢复之前的登录方式，使用 -p 参数）
echo 'Attempting Harbor login...'
if ! sudo nerdctl -n k8s.io login $harbor_host:$harbor_port -u $admin_user -p '$admin_password'; then
    echo 'ERROR: Harbor login failed'
    exit 1
fi
echo 'Harbor login successful'

# 获取所有镜像并推送到 Harbor
echo 'Starting image push process...'
sudo nerdctl -n k8s.io images | grep -v harbor.$harbor_host | grep -v '<none>' | awk '{print \$1":"\$2}' | while read image; do
    if [[ \$image == *'/'* ]]; then
        # 提取镜像名和标签（改进：正确处理包含端口的镜像名）
        # 使用 bash 参数扩展，从最后一个 : 分割，避免端口号被误分割
        repo=\${image%:*}
        tag=\${image##*:}
        # 提取镜像名（最后一个/之后的部分，去掉可能的 registry 前缀）
        # 如果包含多个 /，取最后一个 / 之后的部分作为镜像名
        if [[ \$repo == *'/'* ]]; then
            imagename=\${repo##*/}
        else
            imagename=\$repo
        fi
        # 推送到Harbor的指定项目
        echo "Pushing: \$image -> $harbor_host:$harbor_port/$target_project/\$imagename:\$tag"
        if sudo nerdctl -n k8s.io tag \$image $harbor_host:$harbor_port/$target_project/\$imagename:\$tag; then
            if sudo nerdctl -n k8s.io push $harbor_host:$harbor_port/$target_project/\$imagename:\$tag; then
                echo "SUCCESS: \$image pushed successfully"
            else
                echo "ERROR: Failed to push \$image"
            fi
        else
            echo "ERROR: Failed to tag \$image"
        fi
    fi
done
echo 'Image push process completed'
EOF

    # 通过 SSH 执行脚本（使用配置的端口、用户和密钥）
    local ssh_key_option=""
    if [[ -n "$ssh_key" && -f "$ssh_key" ]]; then
        ssh_key_option="-i $ssh_key"
    fi
    
    # 构建 SSH 端口选项
    local push_ssh_port_option=""
    if [[ -n "$ssh_port" && "$ssh_port" != "22" ]]; then
        push_ssh_port_option="-p $ssh_port"
    fi
    local push_result=$(ssh $ssh_key_option $push_ssh_port_option -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes "$ssh_user@$target_node_public_ip" "bash -s" < "$push_script" 2>&1)
    
    # 清理临时脚本
    rm -f "$push_script"
    
    # 检查推送结果：统计成功和失败的数量
    # 使用 tr -d '\n' 去除换行符，确保是纯数字
    local success_count=$(echo "$push_result" | grep -c "SUCCESS:" 2>/dev/null | tr -d '\n' || echo "0")
    local error_count=$(echo "$push_result" | grep -c "ERROR:" 2>/dev/null | tr -d '\n' || echo "0")
    
    # 确保是数字（去除所有非数字字符）
    success_count=$(echo "$success_count" | tr -d '[:space:]' | grep -oE '^[0-9]+$' || echo "0")
    error_count=$(echo "$error_count" | tr -d '[:space:]' | grep -oE '^[0-9]+$' || echo "0")
    
    if [[ $error_count -gt 0 ]]; then
        log_warn "⚠️  部分镜像推送失败"
        log_info "成功推送: $success_count 个镜像"
        log_info "失败推送: $error_count 个镜像"
        log_info "推送结果: $push_result"
        # 如果有成功推送，不返回错误，只记录警告
        if [[ $success_count -gt 0 ]]; then
            log_warn "继续执行，已成功推送的镜像可用"
            return 0
        else
            log_error "❌ 所有镜像推送失败"
            return 1
        fi
    elif [[ $success_count -gt 0 ]]; then
        log_success "✅ 控制平面镜像推送完成"
        log_info "成功推送: $success_count 个镜像"
        log_info "推送结果: $push_result"
        return 0
    else
        log_warn "⚠️  镜像推送状态未知（未检测到成功或失败信息）"
        log_info "推送结果: $push_result"
        # 如果输出包含 "Image push process completed"，认为可能成功（只是没有显式标记）
        if echo "$push_result" | grep -q "Image push process completed"; then
            log_warn "检测到推送流程完成，假设成功"
            return 0
        fi
        return 1
    fi
}

# 自动创建项目并推送镜像
auto_create_project_and_push_images() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    
    # 检查是否启用此功能
    if [[ "${AUTO_CREATE_PROJECT_AND_PUSH_IMAGES:-false}" != "true" ]]; then
        log_error "本次部署，未自动创建 Harbor 项目并推送控制平面镜像到 Harbor！"
        return 0
    fi
    
    log_info "开始自动创建项目并推送控制平面镜像..."
    
    # 获取 Harbor 配置
    local harbor_host="${HARBOR_EXTERNAL_HOST:-harbor.sunmoonai.local}"
    local harbor_port="${HARBOR_EXTERNAL_PORT:-30443}"
    local admin_user="admin"
    
    # 从 Kubernetes Secret 获取 Harbor 管理员密码
    # 优先顺序：1. 环境变量 HARBOR_ADMIN_PASSWORD 2. Secret harbor-secret 3. Secret {release}-envvars 4. 默认值
    local admin_password="${HARBOR_ADMIN_PASSWORD:-}"
    if [[ -z "$admin_password" ]]; then
        # 尝试从 harbor-secret 读取
        local secret_name="${HARBOR_AUTH_SECRET_NAME:-harbor-secret}"
        local secret_key="${HARBOR_AUTH_SECRET_PASSWORD_KEY:-HARBOR_ADMIN_PASSWORD}"
        admin_password=$(kubectl get secret "$secret_name" -n "$namespace" -o jsonpath="{.data.$secret_key}" 2>/dev/null | base64 -d 2>/dev/null || echo "")
        
        # 如果还是空，尝试从 Harbor release 的 envvars secret 读取
        if [[ -z "$admin_password" ]]; then
            local release_name="${project_id}-harbor"
            admin_password=$(kubectl get secret "${release_name}-envvars" -n "$namespace" -o jsonpath="{.data.HARBOR_ADMIN_PASSWORD}" 2>/dev/null | base64 -d 2>/dev/null || echo "")
        fi
        
        # 如果还是空，使用默认值（但这不是推荐的做法）
        if [[ -z "$admin_password" ]]; then
            admin_password="${project_id}_harbor_$(date +%Y)!"
            log_warn "⚠️  无法从 Secret 读取密码，使用默认密码（可能不正确）"
        else
            log_info "✅ 从 Secret 读取 Harbor 管理员密码成功"
        fi
    fi
    
    local target_project="${HARBOR_PROJECT_NAME:-k8s-images}"
    
    # 等待 Harbor 服务就绪（同时获取 SSH 信息）
    # 注意：wait_for_harbor_ready 会将 SSH 信息设置到全局变量中
    if ! wait_for_harbor_ready "$harbor_host" "$harbor_port" "$project_id" "$namespace"; then
        log_error "Harbor 服务未就绪，跳过镜像推送"
        return 1
    fi
    
    # 复用 wait_for_harbor_ready 中已获取的 SSH 信息（全局变量）
    # 注意：不要使用 local，因为 wait_for_harbor_ready 已经设置了全局变量
    if [[ -n "$ssh_host" && -n "$ssh_user" ]]; then
        log_info "将在控制平面节点 ($ssh_host) 上创建 Harbor 项目"
    else
        log_warn "无法获取控制平面节点 SSH 信息，将在本地执行（可能无法访问）"
    fi
    
    # 创建项目（在控制平面节点上执行，与 wait_for_harbor_ready 保持一致）
    if ! create_harbor_project "$target_project" "$harbor_host" "$harbor_port" "$admin_user" "$admin_password" "$ssh_host" "$ssh_user" "$ssh_key" "$ssh_port"; then
        log_error "项目创建失败，跳过镜像推送"
        return 1
    fi
    
    # 推送镜像
    if ! push_control_plane_images "$project_id" "$namespace" "$environment" "$harbor_host" "$harbor_port" "$admin_user" "$admin_password" "$target_project"; then
        log_error "镜像推送失败"
        return 1
    fi
    
    log_success "✅ 自动创建项目并推送镜像完成"
    log_info "Harbor 项目: $target_project"
    log_info "Harbor 地址: https://$harbor_host:$harbor_port"
    log_info "管理员用户: $admin_user"
}

# 主部署函数 - 实现两级部署逻辑
deploy_harbor() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"

    # 当前集群未启用 Harbor 时（如 C2 共用 C1 的 Harbor），跳过整个部署及阶段4
    if [[ "${harbor_enabled:-true}" == "false" ]]; then
        log_info "当前集群 (CLUSTER=${CLUSTER:-}) 未启用 Harbor 部署 (harbor_enabled=false)，跳过（含阶段4 自动创建项目并推送镜像）"
        return 0
    fi

    log_info "开始 Harbor 递归部署..."
    log_info "项目: $project_id"
    log_info "命名空间: $namespace"
    log_info "环境: $environment"
    log_info "干运行: $dry_run"

    # ============================================================================
    # 两级部署逻辑：子级组件部署 + 本级专属部署
    # ============================================================================
    
    # 阶段1：部署子级组件（按优先级）
    log_info "🚀 阶段1：部署子级组件（按优先级）..."
    deploy_sub_components_by_priority "$project_id" "$namespace" "$environment" "$dry_run"
    
    # 阶段2：部署 Harbor 核心服务
    log_info "🚀 阶段2：部署 Harbor 核心服务..."
    deploy_harbor_core "$project_id" "$namespace" "$environment" "$dry_run"
    
    # 阶段3：部署本级专属组件
    log_info "🚀 阶段3：部署本级专属组件..."
    deploy_current_level_components "$project_id" "$namespace" "$environment" "$dry_run"
    
    # -------------------------------------------------------------------------
    # 阶段4：自动创建项目并推送控制平面镜像到 Harbor（备忘：Kind 与远程差异）
    # -------------------------------------------------------------------------
    # 共用本脚本时，为何 Kind 不推镜像而远程会推？
    # - 本阶段调用 auto_create_project_and_push_images → push_control_plane_images，
    #   依赖「远程控制平面节点」的 SSH，在节点上用 nerdctl 把已有镜像推到 Harbor。
    # - Kind 无远程节点与 SSH，因此当 K8S_TARGET_MODE=kind 时此处显式跳过阶段4，
    #   避免无意义/失败；Kind 的控制平面镜像由 load-images / push-to-harbor 等别处处理。
    # - K8S_TARGET_MODE 来自 unified-deployment-template 的 setup_kubectl_environment
    #   （CLUSTER=KIND 时设为 kind）。各组件（Jenkins/RabbitMQ 等）的推镜像由
    #   push_component_images_to_harbor 处理：Kind 用 push-to-harbor，远程用 loadimage.sh。
    # -------------------------------------------------------------------------
    if [[ "$dry_run" != "true" ]]; then
        if [[ "${K8S_TARGET_MODE:-}" == "kind" ]]; then
            log_info "Kind 集群跳过自动创建项目并推送镜像（无需从节点 SSH 推送）"
        else
            log_info "🚀 阶段4：自动创建项目并推送镜像..."
            auto_create_project_and_push_images "$project_id" "$namespace" "$environment"
        fi
    else
        log_info "干运行模式，跳过自动创建项目并推送镜像"
    fi
    
    log_success "🎉 Harbor 递归部署完成！"
}

# 升级 Harbor
upgrade_harbor() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"

    log_info "开始升级 Harbor..."
    
    # 检查是否已部署
    if ! helm list -n "$namespace" | grep -q "${project_id}-harbor"; then
        log_error "Harbor 未部署，请先执行部署操作"
        return 1
    fi

    # 执行升级（实际上与部署使用相同的函数）
    deploy_harbor "$project_id" "$namespace" "$environment" "$dry_run"
}

# 卸载子组件（反向优先级）
uninstall_sub_components_by_priority() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"

    log_info "开始卸载 Harbor 子组件（按优先级逆序）..."
    
    # 定义组件卸载信息（组件名:启用标志:优先级:描述:脚本路径）
    local components=(
        "secrets:${secrets_enabled:-false}:${secrets_priority:-2000}:Harbor Secrets:$SCRIPT_DIR/secrets/deploy-secrets-all/deploy-secrets-all.sh"
        "middleware:${middleware_enabled:-false}:${middleware_priority:-1000}:Traefik 中间件:$SCRIPT_DIR/../middleware/deploy-middleware-all/deploy-middleware-all.sh"
        "ingress:${ingress_enabled:-false}:${ingress_priority:-100}:Ingress 配置:$SCRIPT_DIR/../ingress/deploy-ingress-all/deploy-ingress-all.sh"
    )
    
    # 按优先级升序排序（卸载时逆序）
    IFS=$'\n' components=($(sort -t: -k3 -n <<<"${components[*]}"))
    unset IFS
    
    # 卸载子组件
    for component_info in "${components[@]}"; do
        IFS=':' read -r name enabled priority description script_path <<< "$component_info"
        if [[ "$enabled" == "true" ]]; then
            log_info "卸载 $description (优先级: $priority)..."
            if [[ -f "$script_path" ]]; then
                # 禁用子脚本的自动清理，保持连接以便后续操作
                DISABLE_AUTO_CLEANUP=true bash "$script_path" uninstall "$project_id" "$namespace" "$environment" "$dry_run" || true
                log_success "✅ $description 卸载完成"
            else
                log_warn "⚠️ $description 脚本不存在: $script_path"
            fi
        fi
    done
    
    log_success "✅ Harbor 子组件卸载完成"
    return 0
}

# 卸载 Harbor
uninstall_harbor() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"

    log_info "开始卸载 Harbor..."
    
    local release_name="${project_id}-harbor"
    
    # 检查是否已部署
    if ! helm list -n "$namespace" | grep -q "$release_name"; then
        log_warn "Harbor 未部署，无需卸载"
        return 0
    fi

    if [[ "$dry_run" == "true" ]]; then
        log_info "干运行模式：将卸载 $release_name"
        return 0
    fi

    # 确认卸载
    echo "警告: 即将卸载 Harbor (release: $release_name)"
    read -p "确认卸载? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "取消卸载"
        return 0
    fi

    # 执行卸载
    if helm uninstall "$release_name" -n "$namespace"; then
        log_info "Harbor 卸载成功！"
        
        # 清理命名空间（可选）
        read -p "是否删除命名空间 $namespace? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kubectl delete namespace "$namespace"
            log_info "命名空间 $namespace 已删除"
        fi
        return 0
    else
        log_error "Harbor 卸载失败！"
        return 1
    fi
}

# 查看 Harbor 状态
status_harbor() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"

    log_info "查看 Harbor 状态..."
    
    local release_name="${project_id}-harbor"
    
    # 检查 Helm release
    echo "=== Helm Release 状态 ==="
    if helm list -n "$namespace" | grep -q "$release_name"; then
        helm list -n "$namespace" | grep "$release_name"
    else
        echo "未找到 Harbor release"
        return 1
    fi
    
    echo
    
    # 检查 Pod 状态
    echo "=== Pod 状态 ==="
    kubectl get pods -n "$namespace" -l "app.kubernetes.io/instance=$project_id"
    
    echo
    
    # 检查服务状态
    echo "=== 服务状态 ==="
    kubectl get svc -n "$namespace" -l "app.kubernetes.io/instance=$project_id"
    
    echo
    
    # 检查 PVC 状态
    echo "=== 持久化卷状态 ==="
    kubectl get pvc -n "$namespace" -l "app.kubernetes.io/instance=$project_id"
    
    echo
    
    # 检查配置映射
    echo "=== 配置映射状态 ==="
    kubectl get configmap -n "$namespace" -l "app.kubernetes.io/instance=$project_id"
    
    echo
    
    # 检查密钥
    echo "=== 密钥状态 ==="
    kubectl get secret -n "$namespace" -l "app.kubernetes.io/instance=$project_id"
}

# 查看 Harbor 日志
logs_harbor() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"

    log_info "查看 Harbor 日志..."
    
    local release_name="${project_id}-harbor"
    
    # 检查是否已部署
    if ! helm list -n "$namespace" | grep -q "$release_name"; then
        log_error "Harbor 未部署"
        return 1
    fi

    # 获取所有 Harbor Pod
    local pods=$(kubectl get pods -n "$namespace" -l "app.kubernetes.io/instance=$project_id" --no-headers -o custom-columns=":metadata.name")
    
    if [[ -z "$pods" ]]; then
        log_error "未找到 Harbor Pod"
        return 1
    fi

    # 显示日志
    for pod in $pods; do
        echo "=== $pod 日志 ==="
        kubectl logs -n "$namespace" "$pod" --tail=50
        echo
    done
}

# 验证 Harbor 配置
validate_harbor_config() {
    log_info "验证 Harbor 配置..."

    # 精简校验：仅校验核心必需字段
    local required_vars=(
        "HARBOR_PROJECT_ID"
        "HARBOR_NAMESPACE"
        "ENVIRONMENT"
        "HARBOR_EXTERNAL_HOST"
        "HARBOR_EXTERNAL_PORT"
    )

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "配置文件缺少必需字段: $var"
            return 1
        fi
    done

    # 可选字段验证（如果设置了则验证格式）
    if [[ -n "${HARBOR_TLS_ENABLED:-}" ]]; then
        if [[ "$HARBOR_TLS_ENABLED" != "true" && "$HARBOR_TLS_ENABLED" != "false" ]]; then
            log_error "HARBOR_TLS_ENABLED 必须是 'true' 或 'false'"
            return 1
        fi
    fi

    # 验证外部访问配置格式
    if [[ -n "${HARBOR_EXTERNAL_HOST:-}" ]]; then
        # 简单的IP或域名格式验证
        if [[ ! "$HARBOR_EXTERNAL_HOST" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && \
           [[ ! "$HARBOR_EXTERNAL_HOST" =~ ^[a-zA-Z0-9.-]+$ ]]; then
            log_warn "HARBOR_EXTERNAL_HOST 格式可能不正确: $HARBOR_EXTERNAL_HOST"
        fi
    fi

    if [[ -n "${HARBOR_EXTERNAL_PORT:-}" ]]; then
        # 验证端口号格式
        if [[ ! "$HARBOR_EXTERNAL_PORT" =~ ^[0-9]+$ ]] || [[ "$HARBOR_EXTERNAL_PORT" -lt 1 ]] || [[ "$HARBOR_EXTERNAL_PORT" -gt 65535 ]]; then
            log_error "HARBOR_EXTERNAL_PORT 必须是 1-65535 之间的数字"
            return 1
        fi
    fi

    log_success "Harbor 配置验证通过"
}

# 检查前置条件
check_prerequisites() {
    log_info "检查前置条件..."
    # 检查 Helm
    if ! check_helm; then exit 1; fi
    # 检查 Kubernetes 集群
    if ! setup_kubectl_environment; then exit 1; fi
    
    # 检查资源目录
    local resources_dir="$PROJECT_ROOT/resources/harbor"
    if [[ ! -d "$resources_dir" ]]; then
        log_error "Harbor 资源目录不存在: $resources_dir"
        exit 1
    fi
    
    # 检查 Chart.yaml
    if [[ ! -f "$resources_dir/Chart.yaml" ]]; then
        log_error "Harbor Chart.yaml 不存在: $resources_dir/Chart.yaml"
        exit 1
    fi
    
    # 检查 values.yaml
    if [[ ! -f "$resources_dir/values.yaml" ]]; then
        log_error "Harbor values.yaml 不存在: $resources_dir/values.yaml"
        exit 1
    fi
    
    log_info "前置条件检查通过"
}

# 显示部署信息
show_deployment_info() {
    local project_id="$1"
    local namespace="$2"
    
    echo
    echo "=== Harbor 部署完成 ==="
    echo "项目: $project_id"
    echo "命名空间: $namespace"
    echo "Release: ${project_id}-harbor"
    echo
    
    # 获取服务信息
    local service_info=$(kubectl get svc -n "$namespace" -l "app.kubernetes.io/instance=$project_id" --no-headers -o custom-columns="NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP,EXTERNAL-IP:.status.loadBalancer.ingress[0].ip,PORT:.spec.ports[0].port" 2>/dev/null)
    
    if [[ -n "$service_info" ]]; then
        echo "=== 服务信息 ==="
        echo "$service_info"
        echo
    fi
    
    # 获取 Pod 状态
    local pod_status=$(kubectl get pods -n "$namespace" -l "app.kubernetes.io/instance=$project_id" --no-headers -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready" 2>/dev/null)
    
    if [[ -n "$pod_status" ]]; then
        echo "=== Pod 状态 ==="
        echo "$pod_status"
        echo
    fi
    
    echo "=== 访问信息 ==="
    echo "查看状态: $0 status"
    echo "查看日志: $0 logs"
    echo "卸载: $0 uninstall"
    echo
}

# 主函数
main() {
    # 使用解析后的参数（已移除 --cluster 参数）
    set -- "${ORIGINAL_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    local action="${1:-}"
    local project_id="${2:-$HARBOR_PROJECT_ID}"
    local namespace="${3:-$HARBOR_NAMESPACE}"
    local environment="${4:-$ENVIRONMENT}"
    local dry_run="${5:-false}"
    
    case "$action" in
        "deploy")
            if [[ -z "$project_id" ]]; then
                log_error "请提供项目ID"
                echo "用法: $0 deploy <project_id> [namespace] [environment] [dry_run]"
                echo "示例: $0 deploy $HARBOR_PROJECT_ID $HARBOR_NAMESPACE $ENVIRONMENT false"
                exit 1
            fi
            
            # 读取 Kubernetes 配置文件
            if ! read_k8s_config; then
                log_error "无法读取 Kubernetes 配置文件"
                return 1
            fi
            
            # 设置 Kubernetes 环境（建立远程连接）
            if ! setup_kubectl_environment; then
                log_error "无法建立 Kubernetes 连接"
                return 1
            fi
            
            # 执行部署
            if deploy_harbor "$project_id" "$namespace" "$environment" "$dry_run"; then
                # 显示部署信息
                log_info "Harbor 部署信息:"
                log_info "项目: $project_id"
                log_info "命名空间: $namespace"
                log_info "服务名称: ${project_id}-harbor"
                log_info "Chart 目录: $PROJECT_ROOT/resources/harbor"
                log_info ""
                log_info "检查部署状态:"
                log_info "kubectl get pods -n $namespace -l app.kubernetes.io/instance=$project_id"
                log_info "kubectl get svc -n $namespace -l app.kubernetes.io/instance=$project_id"
                log_info "kubectl logs -n $namespace -l app.kubernetes.io/instance=$project_id"
                # Harbor 安装完成后：触发全局清理（未使用镜像与各节点包文件）
                local harbor_tool="$PROJECT_ROOT/utils/harbor-image-management/harbor-image.sh"
                if [[ -x "$harbor_tool" ]]; then
                    log_info "触发 Harbor 安装后全局清理..."
                    if ! "$harbor_tool" cleanup-all-nodes-after-harbor; then
                        log_warn "全局清理执行失败或部分失败"
                    fi
                else
                    log_warn "未找到 Harbor 镜像管理工具: $harbor_tool"
                fi

                return 0
            else
                log_error "❌ Harbor 部署失败！"
                return 1
            fi
            ;;
        "upgrade")
            if [[ -z "$project_id" ]]; then
                log_error "请提供项目ID"
                echo "用法: $0 upgrade <project_id> [namespace] [environment] [dry_run]"
                echo "示例: $0 upgrade $HARBOR_PROJECT_ID $HARBOR_NAMESPACE $ENVIRONMENT false"
                exit 1
            fi
            
            log_info "开始升级 Harbor..."
            # 调用部署函数进行升级
            main "deploy" "$project_id" "$namespace" "$environment" "$dry_run"
            ;;
        "uninstall")
            if [[ -z "$project_id" ]]; then
                log_error "请提供项目ID"
                echo "用法: $0 uninstall <project_id> [namespace] [environment] [dry_run]"
                echo "示例: $0 uninstall $HARBOR_PROJECT_ID $HARBOR_NAMESPACE $ENVIRONMENT false"
                exit 1
            fi
            
            # 设置 Kubernetes 环境
            if ! setup_kubectl_environment; then
                log_error "无法建立 Kubernetes 连接"
                return 1
            fi
            
            # 卸载子组件（按优先级逆序）
            uninstall_sub_components_by_priority "$project_id" "$namespace" "$environment" "$dry_run"
            
            # 确保连接仍然可用
            if ! kubectl get nodes >/dev/null 2>&1; then
                log_info "连接已断开，重新建立连接..."
                if ! setup_kubectl_environment; then
                    log_error "无法重新建立 Kubernetes 连接"
                    return 1
                fi
            fi
            
            if uninstall_harbor "$project_id" "$namespace" "$environment" "$dry_run"; then
                return 0
            else
                return 1
            fi
            ;;
        "status")
            if [[ -z "$project_id" ]]; then
                log_error "请提供项目ID"
                echo "用法: $0 status <project_id> [namespace] [environment] [dry_run]"
                echo "示例: $0 status $HARBOR_PROJECT_ID $HARBOR_NAMESPACE $ENVIRONMENT false"
                exit 1
            fi
            
            # 设置 Kubernetes 环境
            if ! setup_kubectl_environment; then
                log_error "无法建立 Kubernetes 连接"
                return 1
            fi
            
            if status_harbor "$project_id" "$namespace" "$environment" "$dry_run"; then
                return 0
            else
                return 1
            fi
            ;;
        "logs")
            if [[ -z "$project_id" ]]; then
                log_error "请提供项目ID"
                echo "用法: $0 logs <project_id> [namespace] [environment] [dry_run]"
                echo "示例: $0 logs $HARBOR_PROJECT_ID $HARBOR_NAMESPACE $ENVIRONMENT false"
                exit 1
            fi
            
            # 设置 Kubernetes 环境
            if ! setup_kubectl_environment; then
                log_error "无法建立 Kubernetes 连接"
                return 1
            fi
            
            logs_harbor "$project_id" "$namespace" "$environment" "$dry_run"
            ;;
        *)
            echo "Harbor 递归部署脚本"
            echo ""
            echo "用法: $0 <action> <project_id> [additional_params...]"
            echo ""
            echo "操作:"
            echo "  deploy     部署 Harbor（递归部署）"
            echo "  upgrade    升级 Harbor"
            echo "  uninstall  卸载 Harbor"
            echo "  status     检查 Harbor 状态"
            echo "  logs       获取 Harbor 日志"
            echo ""
            echo "详细用法:"
            echo "  deploy:    $0 deploy <project_id> [namespace] [environment] [dry_run]"
            echo "  upgrade:   $0 upgrade <project_id> [namespace] [environment] [dry_run]"
            echo "  uninstall: $0 uninstall <project_id> [namespace] [environment] [dry_run]"
            echo "  status:    $0 status <project_id> [namespace] [environment] [dry_run]"
            echo "  logs:      $0 logs <project_id> [namespace] [environment] [dry_run]"
            echo ""
            echo "参数说明:"
            echo "  project_id   项目标识符（必需）"
            echo "  namespace    命名空间（可选，默认: $HARBOR_NAMESPACE）"
            echo "  environment  环境（可选，默认: $ENVIRONMENT）"
            echo "  dry_run      干运行模式（可选，默认: false）"
            echo ""
            echo "示例:"
            echo "  $0 deploy $HARBOR_PROJECT_ID $HARBOR_NAMESPACE $ENVIRONMENT"
            echo "  $0 upgrade $HARBOR_PROJECT_ID $HARBOR_NAMESPACE $ENVIRONMENT"
            echo "  $0 uninstall $HARBOR_PROJECT_ID $HARBOR_NAMESPACE $ENVIRONMENT"
            echo "  $0 status $HARBOR_PROJECT_ID $HARBOR_NAMESPACE $ENVIRONMENT"
            echo "  $0 logs $HARBOR_PROJECT_ID $HARBOR_NAMESPACE $ENVIRONMENT"
            echo ""
            echo "环境:"
            echo "  production   生产环境（高可用配置）"
            echo "  development  开发环境（最小配置）"
            echo ""
            echo "递归部署架构:"
            echo "  阶段1: 部署子级组件（按优先级）"
            echo "  阶段2: 部署 Harbor 核心服务"
            echo "  阶段3: 部署本级专属组件"
            echo "  阶段4: 自动创建项目并推送镜像（可选）"
            echo ""
            exit 1
            ;;
    esac
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi