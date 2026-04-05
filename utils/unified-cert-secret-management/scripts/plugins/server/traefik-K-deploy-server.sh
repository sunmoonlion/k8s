#!/bin/bash

# =============================================================================
# Harbor K8s服务端部署插件
# 文件名: harbor-k8s-deploy.sh
# 用途: Harbor在K8s环境下的服务端部署
# =============================================================================

set -euo pipefail

# 获取项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

# 计算 k8s 根目录（utils 的父目录）
# unified-cert-secret-management/ -> utils/ -> k8s/
K8S_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"

# 加载配置文件
CONFIG_FILE="$PROJECT_ROOT/cert-secret.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# 加载集群配置映射函数（用于将 C1_* 或 C2_* 映射为默认配置）
if [[ -f "$K8S_ROOT/utils/cluster-config-mapping.sh" ]]; then
    source "$K8S_ROOT/utils/cluster-config-mapping.sh"
    # 应用集群配置映射（使用 CLUSTER 环境变量）
    if command -v apply_cluster_config_mapping &>/dev/null; then
        # 调试：检查 CLUSTER 环境变量
        if [[ -n "${CLUSTER:-}" ]]; then
            echo "ℹ️  插件脚本：CLUSTER=${CLUSTER}"
        else
            echo "⚠️  插件脚本：CLUSTER 环境变量未设置"
        fi
        apply_cluster_config_mapping
    fi
fi

# 加载公共函数
source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/ssh.sh"
source "$PROJECT_ROOT/lib/cert.sh"
source "$PROJECT_ROOT/lib/secret-data.sh"

# =============================================================================
# Harbor K8s服务端部署
# =============================================================================

deploy_harbor_k8s() {
    local service_type="$1"      # H
    local server_env="$2"       # K
    local server_node="$3"      # 1
    local client_env="$4"       # D
    local client_node="$5"      # 1
    
    # 构建新的编码格式
    local combo="${service_type}_${server_env}${server_node}_${client_env}${client_node}"
    
    log_info "部署Harbor K8s服务端..."
    log_info "组合代码: $combo"
    
    # 说明：如果配置了 Secret（有 TYPE），系统会自动处理，无需额外开关。
    
    # 获取运行模式（从环境变量或配置文件）
    local tls_mode="${TLS_MODE:-rotate}"
    
    # 0. 生成CA证书
    if ! generate_ca_certificate "$combo"; then
        log_error "Harbor K8s CA证书生成失败"
        return 1
    fi
    
    # 在 init 模式下，只生成 CA 证书，关闭其他功能
    # 注意：generate_ca_certificate 函数已经处理了CA证书的归档（如果配置了归档目录）
    if [[ "$tls_mode" == "init" ]]; then
        log_info "初始化模式 (init)：只生成 CA 证书，关闭服务器证书生成和 Secret 部署"
        log_info "注意：CA证书归档已由 generate_ca_certificate 函数处理"
        log_info "注意：CA证书分发由客户端脚本负责，服务端脚本不处理CA证书分发"
        log_success "初始化模式：CA证书生成完成"
        return 0
    fi
    
    # 生成服务器证书（非 init 模式）
    # 注意：服务器证书必须由统一证书管理系统生成，以确保证书链验证通过
    #      在 rotate/force 模式下，如果 CA 被重新生成，服务器证书必须同步更新
    log_info "开始生成服务器证书..."
    if ! generate_server_certificate "$combo"; then
        log_error "服务器证书生成失败"
        return 1
    fi
    
    # 1. 服务端证书归档
    # 注意：CA证书归档已由 generate_ca_certificate 函数处理，这里只归档服务器证书
    log_info "开始服务端证书归档..."
    
    # 获取服务端归档配置
    local local_server_cert_dir=$(get_five_layer_config "$combo" "LOCAL_SERVER_CERT_DIR")
    
    # 展开路径中的 ~ 符号
    local_server_cert_dir="${local_server_cert_dir/#\~/$HOME}"
    
    # 创建归档目录
    if [[ -n "$local_server_cert_dir" ]]; then
        mkdir -p "$local_server_cert_dir"
    fi
    
    # 使用临时证书文件路径（按前三层前缀存放）
    local server_prefix=$(echo "$combo" | sed 's/_[KDN][0-9]*$//')
    local temp_server_cert_path="/tmp/${server_prefix}-server-certs/server.crt"
    local temp_server_key_path="/tmp/${server_prefix}-server-certs/server.key"
    
    # 归档服务器证书
    if [[ -f "$temp_server_cert_path" && -n "$local_server_cert_dir" ]]; then
        cp "$temp_server_cert_path" "$local_server_cert_dir/server.crt"
        log_info "服务器证书已归档到: $local_server_cert_dir/server.crt"
    fi
    
    if [[ -f "$temp_server_key_path" && -n "$local_server_cert_dir" ]]; then
        cp "$temp_server_key_path" "$local_server_cert_dir/server.key"
        log_info "服务器私钥已归档到: $local_server_cert_dir/server.key"
    fi
    
    log_success "服务端证书归档完成"
    
    # 注意：CA证书归档已由 generate_ca_certificate 函数处理
    # 注意：CA证书分发由客户端脚本负责，服务端脚本不处理CA证书分发
    
    # 2. 生成并归档多个 Secret YAML（按 SECRET_<i>_ENABLED 控制）
    local secret_count=$(get_secret_count "$combo")
    if [[ -n "$secret_count" && "$secret_count" -gt 0 ]]; then
        log_info "开始处理 $secret_count 个Secret..."
        
        # 循环处理每个Secret - 只处理实际配置的Secret
        local processed_count=0
        for config_key in $(compgen -v | grep "^${combo}_SECRET_[0-9]\+_TYPE$"); do
            # 提取索引号
            if [[ "$config_key" =~ ^${combo}_SECRET_([0-9]+)_TYPE$ ]]; then
                local i="${BASH_REMATCH[1]}"
                local secret_type="${!config_key:-}"
                
                # 只处理实际配置的Secret（TYPE不为空）
                # 说明：如果配置了 Secret（有 TYPE），系统会自动处理，无需额外开关
                if [[ -n "$secret_type" ]]; then
                    local secret_name=$(get_five_layer_config "$combo" "SECRET_${i}_NAME")
                    local secret_namespace=$(get_five_layer_config "$combo" "SECRET_${i}_NAMESPACE")
                    
                    log_info "处理Secret $i: $secret_name (类型: $secret_type)"
            
            # 根据Secret类型处理不同的数据
            case "$secret_type" in
                "kubernetes.io/tls")
                    log_info "  → TLS Secret: 包含证书和私钥"
                    # 准备TLS证书数据
                    if ! prepare_tls_secret_data "$combo" "$secret_name" "$i"; then
                        log_error "TLS证书数据准备失败: $secret_name"
                        continue
                    fi
                    ;;
                "kubernetes.io/dockerconfigjson")
                    log_info "  → Docker认证Secret: 用于镜像拉取认证"
                    # 准备Docker认证数据
                    if ! prepare_docker_auth_secret_data "$combo" "$secret_name" "$i"; then
                        log_error "Docker认证数据准备失败: $secret_name"
                        continue
                    fi
                    ;;
                "Opaque")
                    log_info "  → 通用Secret: 包含自定义数据"
                    # 准备通用配置数据
                    if ! prepare_opaque_secret_data "$combo" "$secret_name" "$i"; then
                        log_error "通用配置数据准备失败: $secret_name"
                        continue
                    fi
                    ;;
                "kubernetes.io/basic-auth")
                    log_info "  → 基本认证Secret: 包含用户名和密码"
                    # 准备基本认证数据
                    if ! prepare_basic_auth_secret_data "$combo" "$secret_name" "$i"; then
                        log_error "基本认证数据准备失败: $secret_name"
                        continue
                    fi
                    ;;
                "kubernetes.io/ssh-auth")
                    log_info "  → SSH认证Secret: 包含SSH私钥"
                    # 准备SSH认证数据
                    if ! prepare_ssh_auth_secret_data "$combo" "$secret_name" "$i"; then
                        log_error "SSH认证数据准备失败: $secret_name"
                        continue
                    fi
                    ;;
                *)
                    log_error "  → 不支持的Secret类型: $secret_type"
                    log_error "  → 支持的类型: kubernetes.io/tls, kubernetes.io/dockerconfigjson, Opaque, kubernetes.io/basic-auth, kubernetes.io/ssh-auth"
                    continue
                    ;;
            esac
            
            # 生成Secret YAML
            if ! render_secret_yaml "$combo" "$secret_type" "$secret_name" "$secret_namespace"; then
                log_error "Secret YAML 生成失败: $secret_name"
                continue
            fi
            
            # 归档Secret YAML - 使用该Secret的独立配置
            local local_secret_dir=$(get_five_layer_config "$combo" "SECRET_${i}_LOCAL_SECRET_DIR")
            # 展开路径中的 ~ 符号
            local_secret_dir="${local_secret_dir/#\~/$HOME}"
            if [[ -n "$local_secret_dir" ]]; then
                mkdir -p "$local_secret_dir"
                
                local temp_yaml="/tmp/${secret_namespace}-${secret_name}.yaml"
                if [[ -f "$temp_yaml" ]]; then
                    # 智能处理路径：移除末尾斜杠再添加文件名
                    local archive_path="${local_secret_dir%/}/${secret_name}.yaml"
                    cp "$temp_yaml" "$archive_path"
                    log_info "Secret YAML已归档到: $archive_path"
                else
                    log_warn "Secret YAML文件不存在: $temp_yaml"
                fi
            else
                log_warn "Secret $i 未配置归档目录，跳过归档"
            fi
                    
                    processed_count=$((processed_count + 1))
                fi
            fi
        done
        
        log_success "多Secret YAML处理完成"
    else
        log_warn "未配置Secret (SECRET_COUNT=0)，跳过Secret处理"
    fi
    
    # 4. 部署多个 Secret 到远程 K8s 集群（自动部署所有配置的 Secret）
    # 注意：全局远程部署配置已迁移到统一的Secret配置系统
    # 每个Secret的远程部署由 SECRET_${i}_APPLY_REMOTE 控制

    local server_host=$(get_five_layer_config "$combo" "SERVER_HOST")
    local server_port=$(get_five_layer_config "$combo" "SERVER_PORT")
    local server_username=$(get_five_layer_config "$combo" "SERVER_USERNAME")
    local server_ssh_key=$(get_five_layer_config "$combo" "SERVER_SSH_KEY")
    
    if [[ -n "$secret_count" && "$secret_count" -gt 0 ]]; then
        log_info "开始部署 $secret_count 个Secret到远程K8s集群..."
        
        # 循环部署每个Secret
        local j
        # 只处理实际配置的Secret
        for config_key in $(compgen -v | grep "^${combo}_SECRET_[0-9]\+_TYPE$"); do
            # 提取索引号
            if [[ "$config_key" =~ ^${combo}_SECRET_([0-9]+)_TYPE$ ]]; then
                local j="${BASH_REMATCH[1]}"
                local secret_type="${!config_key:-}"
                
                # 只处理实际配置的Secret（TYPE不为空）
                # 说明：如果配置了 Secret（有 TYPE），系统会自动部署，无需额外开关
                if [[ -n "$secret_type" ]]; then
                    local secret_name=$(get_five_layer_config "$combo" "SECRET_${j}_NAME")
                    local secret_namespace=$(get_five_layer_config "$combo" "SECRET_${j}_NAMESPACE")
                    
                    log_info "部署Secret $j: $secret_name 到命名空间 $secret_namespace"
            
            # 使用本地渲染的YAML文件 - 使用该Secret的独立归档目录
            local local_secret_dir=$(get_five_layer_config "$combo" "SECRET_${j}_LOCAL_SECRET_DIR")
            # 展开路径中的 ~ 符号
            local_secret_dir="${local_secret_dir/#\~/$HOME}"
            local local_secret_path=""
            
            # 优先使用该Secret的归档目录中的文件
            if [[ -n "$local_secret_dir" ]]; then
                # 智能处理路径：移除末尾斜杠再添加文件名
                local_secret_path="${local_secret_dir%/}/${secret_name}.yaml"
            fi
            
            # 如果归档文件不存在，使用临时文件
            if [[ -z "$local_secret_path" || ! -f "$local_secret_path" ]]; then
                local_secret_path="/tmp/${secret_namespace}-${secret_name}.yaml"
            fi
            
            if [[ ! -f "$local_secret_path" ]]; then
                log_error "本地Secret YAML不存在: $local_secret_path"
                continue
            fi

            # 远程YAML路径
            local remote_yaml_path="/tmp/${secret_namespace}-${secret_name}.yaml"

            # 下发 YAML 到远程控制平面
            if ! transfer_file_with_retry "$local_secret_path" "$server_host" "$server_port" "$server_username" "$server_ssh_key" "$remote_yaml_path"; then
                log_error "下发Secret YAML到远程失败: $secret_name"
                continue
            fi

            # 远程 apply
            local apply_cmd="kubectl apply -f $remote_yaml_path -n $secret_namespace"
            if ! execute_ssh_command_with_retry "$server_host" "$server_port" "$server_username" "$server_ssh_key" "$apply_cmd"; then
                log_error "远程应用Secret YAML失败: $secret_name"
                continue
            fi

            # 清理远程临时YAML
            local cleanup_cmd="rm -f $remote_yaml_path"
            execute_ssh_command_with_retry "$server_host" "$server_port" "$server_username" "$server_ssh_key" "$cleanup_cmd" || true
            
            log_success "Secret $j 部署完成: $secret_name"
                fi
            fi
        done
        
        log_success "所有Secret部署完成"
    else
        log_warn "未配置Secret (SECRET_COUNT=0)，跳过Secret部署"
    fi
    
    # 5. 重启使用Secret的组件（自动重启所有配置了组件列表的 Secret）
    log_info "开始重启使用Secret的组件..."
    
    # 收集所有需要重启的服务信息
    local services_to_restart=()
    
    # 遍历所有配置的Secret，根据手动配置重启相关组件
    for config_key in $(compgen -v | grep "^${combo}_SECRET_[0-9]\+_TYPE$"); do
        if [[ "$config_key" =~ ^${combo}_SECRET_([0-9]+)_TYPE$ ]]; then
            local j="${BASH_REMATCH[1]}"
            local secret_type="${!config_key:-}"
            local secret_name=$(get_five_layer_config "$combo" "SECRET_${j}_NAME")
            local secret_namespace=$(get_five_layer_config "$combo" "SECRET_${j}_NAMESPACE")
            local manual_components=$(get_five_layer_config "$combo" "SECRET_${j}_RESTART_COMPONENTS_LIST")
            
            # 如果配置了组件列表，则重启这些组件（所有类型）
            if [[ -n "$manual_components" ]]; then
                log_info "检测到Secret: $secret_name (类型: $secret_type, 命名空间: $secret_namespace)"
                
                # 使用手动配置的组件列表
                local detected_components=()
                
                if [[ -n "$manual_components" ]]; then
                    log_info "使用手动配置的组件列表: $manual_components"
                    IFS=',' read -ra manual_array <<< "$manual_components"
                    for component in "${manual_array[@]}"; do
                        # 先尝试在Secret的命名空间中查找组件
                        # 使用 -o name 输出格式为 deployment.apps/traefik-sunmoonai 或 deployment/traefik-sunmoonai
                        local check_manual_cmd="kubectl get deployment,statefulset,daemonset $component -n $secret_namespace -o name 2>/dev/null | head -1"
                        local manual_result=$(ssh -i "$server_ssh_key" -p "$server_port" "$server_username@$server_host" "$check_manual_cmd" 2>/dev/null || echo "")
                        
                        if [[ -n "$manual_result" ]]; then
                            # 处理 deployment.apps/traefik-sunmoonai 格式，提取基础资源类型（去掉 .apps 等后缀）
                            local resource_type_full=$(echo "$manual_result" | cut -d'/' -f1)
                            local resource_name=$(echo "$manual_result" | cut -d'/' -f2)
                            # 提取基础资源类型（去掉版本后缀，如 .apps）
                            local resource_type=$(echo "$resource_type_full" | cut -d'.' -f1)
                            detected_components+=("$resource_type/$resource_name:$secret_namespace")
                            log_info "检测到手动配置的组件: $resource_type/$resource_name (命名空间: $secret_namespace)"
                        else
                            # 如果Secret命名空间中没找到，尝试在所有命名空间中查找
                            log_info "在命名空间 $secret_namespace 中未找到 $component，尝试在所有命名空间中搜索..."
                            # 使用 -o name 输出格式为 deployment.apps/traefik-sunmoonai，然后添加命名空间信息
                            local check_all_cmd="kubectl get deployment,statefulset,daemonset --all-namespaces -o name 2>/dev/null | grep \"/$component$\" | head -1"
                            local all_result_line=$(ssh -i "$server_ssh_key" -p "$server_port" "$server_username@$server_host" "$check_all_cmd" 2>/dev/null || echo "")
                            
                            if [[ -n "$all_result_line" ]]; then
                                # 从 deployment.apps/traefik-sunmoonai 格式中提取资源类型和名称
                                local resource_type_full=$(echo "$all_result_line" | cut -d'/' -f1)
                                local resource_name=$(echo "$all_result_line" | cut -d'/' -f2)
                                # 提取基础资源类型（去掉版本后缀，如 .apps）
                                local resource_type=$(echo "$resource_type_full" | cut -d'.' -f1)
                                # 获取命名空间
                                local found_namespace=$(ssh -i "$server_ssh_key" -p "$server_port" "$server_username@$server_host" "kubectl get $resource_type $resource_name --all-namespaces -o jsonpath='{.metadata.namespace}' 2>/dev/null" || echo "")
                                if [[ -n "$found_namespace" ]]; then
                                    detected_components+=("$resource_type/$resource_name:$found_namespace")
                                    log_info "检测到手动配置的组件: $resource_type/$resource_name (命名空间: $found_namespace)"
                                else
                                    log_warn "无法确定组件 $component 的命名空间"
                                fi
                            else
                                log_warn "手动配置的组件 $component 在所有命名空间中都不存在"
                            fi
                        fi
                    done
                else
                    log_warn "未配置组件列表，跳过该Secret"
                    continue
                fi
                
                # 将检测到的组件添加到重启列表
                for component in "${detected_components[@]}"; do
                    if [[ ! " ${services_to_restart[@]} " =~ " ${component} " ]]; then
                        services_to_restart+=("$component")
                    fi
                done
            fi
        fi
    done
    
    # 执行重启
    if [[ ${#services_to_restart[@]} -gt 0 ]]; then
        log_info "发现 ${#services_to_restart[@]} 个需要重启的组件："
        for component in "${services_to_restart[@]}"; do
            log_info "  - $component"
        done
        
        for component in "${services_to_restart[@]}"; do
            local resource_type=$(echo "$component" | cut -d'/' -f1)
            local resource_name=$(echo "$component" | cut -d'/' -f2 | cut -d':' -f1)
            local resource_namespace=$(echo "$component" | cut -d':' -f2)
            
            log_info "重启组件: $resource_type/$resource_name (命名空间: $resource_namespace)"
            
            # 检查组件是否存在
            local check_cmd="kubectl get $resource_type $resource_name -n $resource_namespace --no-headers 2>/dev/null | wc -l"
            local exists=$(ssh -i "$server_ssh_key" -p "$server_port" "$server_username@$server_host" "$check_cmd" 2>/dev/null || echo "0")
            
            if [[ "$exists" == "1" ]]; then
                # 重启组件
                local restart_cmd="kubectl rollout restart $resource_type/$resource_name -n $resource_namespace"
                if execute_ssh_command_with_retry "$server_host" "$server_port" "$server_username" "$server_ssh_key" "$restart_cmd"; then
                    log_success "组件 $resource_type/$resource_name 重启成功"
                else
                    log_warn "组件 $resource_type/$resource_name 重启失败"
                fi
            else
                log_info "组件 $resource_type/$resource_name 不存在，跳过"
            fi
        done
        
        log_success "所有相关组件重启完成，新Secret已生效"
    else
        log_warn "未找到需要重启的组件，跳过自动重启"
        log_info "请检查Secret配置中的RESTART_COMPONENTS_LIST设置"
    fi
    
    
    log_success "Harbor K8s服务端部署完成，相关组件已重启以应用新Secret"
    return 0
}

# =============================================================================
# 主函数
# =============================================================================

main() {
    if [[ $# -ne 5 ]]; then
        log_error "参数数量错误"
        echo "用法: $0 <service_type> <server_env> <server_node> <client_env> <client_node>"
        exit 1
    fi
    
    deploy_harbor_k8s "$@"
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
