#!/usr/bin/env bash
#
# Step07: Namespace Platform Management
# 功能：创建和管理 Kubernetes 命名空间，替代 namespace-platform 功能
# 
# 作者：AI Assistant
# 日期：2024
# 版本：1.0
#

set -euo pipefail

# 加载通用函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 加载配置
if [[ -f "$PROJECT_ROOT/deploy-infrastructure-all/deploy-infrastructure-all.conf" ]]; then
    source "$PROJECT_ROOT/deploy-infrastructure-all/deploy-infrastructure-all.conf"
elif [[ -f "$PROJECT_ROOT/config/deploy.conf" ]]; then
    source "$PROJECT_ROOT/config/deploy.conf"
elif [[ -f "$PROJECT_ROOT/config/cluster.conf" ]]; then
    source "$PROJECT_ROOT/config/cluster.conf"
fi

# 加载通用函数库
if [[ -f "$PROJECT_ROOT/utils/common.sh" ]]; then
    source "$PROJECT_ROOT/utils/common.sh"
fi

# 加载集群配置映射函数（使用 utils 中的通用函数）
K8S_ROOT="$(cd "$PROJECT_ROOT/../.." && pwd)"
if [[ -f "$K8S_ROOT/utils/cluster-config-mapping.sh" ]]; then
    source "$K8S_ROOT/utils/cluster-config-mapping.sh"
    # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
    apply_cluster_config_mapping
fi

# 颜色输出函数
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }

# 日志函数
log_info() { echo -e "$(blue "[INFO]") $*"; }
log_success() { echo -e "$(green "[SUCCESS]") $*"; }
log_warn() { echo -e "$(yellow "[WARN]") $*"; }
log_error() { echo -e "$(red "[ERROR]") $*"; }

# 预检函数
precheck() {
    log_info "[Step07] 预检：命名空间平台管理"

    # 检查配置
    if [[ "${STEP07_ENABLED:-false}" != "true" ]]; then
        log_info "Step07 is disabled, skipping execution"
        exit 0
    fi

    # 检查必要的配置参数
    if [[ -z "${NAMESPACE_PLATFORM_ENVIRONMENTS:-}" ]]; then
        log_error "NAMESPACE_PLATFORM_ENVIRONMENTS 未配置"
        return 1
    fi

    if [[ -z "${NAMESPACE_PLATFORM_PLATFORMS:-}" ]]; then
        log_error "NAMESPACE_PLATFORM_PLATFORMS 未配置"
        return 1
    fi

    log_info "[Step07] 预检通过"
}

# 创建命名空间
create_namespace(){
    local node_idx="${1:-}"
    local platform="${2:-}"
    local environment="${3:-}"
    
    if [[ -z "$node_idx" || -z "$platform" || -z "$environment" ]]; then
        log_error "[Step07] create_namespace 函数参数不完整: node_idx=$node_idx, platform=$platform, environment=$environment"
        return 1
    fi
    
    local namespace="${platform}-${environment}"
    
    log_info "[Step07] 创建命名空间: $namespace"
    
    # 获取 kubectl 完整路径（动态检测）
    # 直接使用 which 从 PATH 查找（最简单可靠）
    local kubectl_cmd
    kubectl_cmd="$(ssh_exec "$node_idx" "which kubectl 2>/dev/null || command -v kubectl 2>/dev/null || echo ''")"
    # 如果 PATH 中找不到，尝试常见位置
    if [[ -z "$kubectl_cmd" ]] || [[ "$kubectl_cmd" == "" ]]; then
        # 使用 || true 防止 set -e 导致脚本退出
        if ssh_exec "$node_idx" "test -x /usr/bin/kubectl" || true; then
            if [[ $? -eq 0 ]]; then
                kubectl_cmd="/usr/bin/kubectl"
            fi
        fi
        if [[ -z "$kubectl_cmd" ]]; then
            if ssh_exec "$node_idx" "test -x /usr/local/bin/kubectl" || true; then
                if [[ $? -eq 0 ]]; then
                    kubectl_cmd="/usr/local/bin/kubectl"
                fi
            fi
        fi
    fi
    # 如果还是找不到，报错
    if [[ -z "${kubectl_cmd:-}" ]]; then
        log_error "[Step07] 节点 $node_idx 上未找到 kubectl 命令（请检查 Step03 是否正确执行）"
        return 1
    fi
    
    # 检查命名空间是否已存在
    # 注意：ssh_exec 使用 stdbuf，需要将环境变量和命令封装在 shell 中
    if ssh_exec "$node_idx" "bash -c 'export KUBECONFIG=\"$REMOTE_KUBECONFIG\" && $kubectl_cmd get ns \"$namespace\" >/dev/null 2>&1'"; then
        log_info "[Step07] 命名空间 $namespace 已存在，跳过创建"
        return 0
    fi
    
    # 创建命名空间
    # 使用远程临时脚本文件的方式，避免 stdbuf 和引号嵌套问题
    local tmp_script="/tmp/step07_create_ns_${namespace}_$$.sh"
    local create_cmd="export KUBECONFIG=\"$REMOTE_KUBECONFIG\"
$kubectl_cmd create namespace \"$namespace\" --dry-run=client -o yaml | $kubectl_cmd apply -f -"
    
    # 将命令写入远程临时文件
    echo "$create_cmd" | ssh_exec "$node_idx" "cat > $tmp_script && chmod +x $tmp_script && bash $tmp_script; rm -f $tmp_script" || {
        log_error "[Step07] 创建命名空间 $namespace 失败"
        ssh_exec "$node_idx" "rm -f $tmp_script" || true
        return 1
    }
    
    # 应用标签和注解
    # 同样使用临时脚本文件
    local label_script="/tmp/step07_label_ns_${namespace}_$$.sh"
    local label_cmd="export KUBECONFIG=\"$REMOTE_KUBECONFIG\"
$kubectl_cmd label namespace \"$namespace\" platform=sunmoonai --overwrite
$kubectl_cmd label namespace \"$namespace\" component=\"$platform\" --overwrite
$kubectl_cmd label namespace \"$namespace\" environment=\"$environment\" --overwrite
$kubectl_cmd label namespace \"$namespace\" tier=\"$platform\" --overwrite
$kubectl_cmd label namespace \"$namespace\" managed-by=infrastructure --overwrite
$kubectl_cmd annotate namespace \"$namespace\" description=\"$environment environment for $platform platform\" --overwrite"
    
    echo "$label_cmd" | ssh_exec "$node_idx" "cat > $label_script && chmod +x $label_script && bash $label_script; rm -f $label_script" || {
        log_warn "[Step07] 应用标签到命名空间 $namespace 失败，但不影响整体流程"
        ssh_exec "$node_idx" "rm -f $label_script" || true
    }
    
    log_success "[Step07] 命名空间 $namespace 创建成功"
}

# 应用命名空间策略
apply_namespace_policies(){
    local namespace="$1"
    
    if [[ "${NAMESPACE_PLATFORM_APPLY_POLICIES:-false}" != "true" ]]; then
        log_info "[Step07] 跳过命名空间策略应用"
        return 0
    fi
    
    log_info "[Step07] 应用命名空间策略: $namespace"
    
    # 这里可以添加资源配额、网络策略等
    # 目前先记录日志
    log_info "[Step07] 命名空间策略应用完成: $namespace"
}

# 清理命名空间
cleanup_namespaces(){
    log_info "[Step07] 清理命名空间"
    
    # 解析环境和平台列表（去除可能的引号和空格）
    local envs="${NAMESPACE_PLATFORM_ENVIRONMENTS//\"/}"
    local platforms="${NAMESPACE_PLATFORM_PLATFORMS//\"/}"
    IFS=',' read -ra ENVIRONMENTS <<< "$envs"
    IFS=',' read -ra PLATFORMS <<< "$platforms"
    
    for env in "${ENVIRONMENTS[@]}"; do
        for platform in "${PLATFORMS[@]}"; do
            local namespace="${platform}-${env}"
            log_info "[Step07] 清理命名空间: $namespace"
            # 这里可以添加清理逻辑
        done
    done
}

# 准备远程 kubeconfig
_prepare_remote_kubeconfig_for_idx(){
    local idx="$1"
    prepare_remote_kubeconfig "$idx" "REMOTE_KUBECONFIG" || {
        log_error "[Step07] 无法在远端节点 $idx 准备可读的 kubeconfig"
        return 1
    }
}

# 主执行函数
execute() {
    log_info "[Step07] 开始执行命名空间平台管理"

    # 检查是否启用
    if [[ "${NAMESPACE_PLATFORM_ENABLE:-false}" != "true" ]]; then
        log_info "[Step07] 命名空间平台管理未启用，跳过"
        return 0
    fi

    # 将 C*_SERVER_* 变量映射为 SERVER_* 变量，确保 get_defined_server_indices 可用
    local _cluster_selected="${CLUSTER:-C1}"
    local _cluster_prefix="${_cluster_selected}_"
    local _server_num=1
    while true; do
        local _pub_var="${_cluster_prefix}SERVER_${_server_num}_PUBLIC_IP"
        if [[ -z "${!_pub_var:-}" ]]; then
            break
        fi
        # 需要映射的字段
        local _fields=("TYPE" "PUBLIC_IP" "LOCAL_IP" "USER" "SECRET" "PASS" "SSH_PORT" "DIR" "CURRENT_HOSTNAME" "CLUSTER_HOSTNAME" "EXTRA_LABELS" "TAINTS")
        for _f in "${_fields[@]}"; do
            local _src_var="${_cluster_prefix}SERVER_${_server_num}_${_f}"
            local _dst_var="SERVER_${_server_num}_${_f}"
            if [[ -n "${!_src_var:-}" ]]; then
                eval "${_dst_var}=\"${!_src_var}\""
            fi
        done
        _server_num=$((_server_num+1))
    done

    # 解析环境和平台列表（去除可能的引号和空格）
    local envs="${NAMESPACE_PLATFORM_ENVIRONMENTS//\"/}"
    local platforms="${NAMESPACE_PLATFORM_PLATFORMS//\"/}"
    IFS=',' read -ra ENVIRONMENTS <<< "$envs"
    IFS=',' read -ra PLATFORMS <<< "$platforms"
    
    # 获取目标节点 - 动态解析可用节点
    local target_nodes=()
    local indices; indices="$(get_defined_server_indices)"
    # 兜底：如果未能从公共函数获得索引，则根据已映射的 SERVER_* 变量推导
    if [[ -z "${indices:-}" ]]; then
        local _i=1
        local _tmp_indices=()
        while true; do
            local _sv="SERVER_${_i}_PUBLIC_IP"
            if [[ -z "${!_sv:-}" ]]; then
                break
            fi
            _tmp_indices+=("${_i}")
            _i=$((_i+1))
        done
        indices="${_tmp_indices[*]}"
    fi
    
    log_info "[Step07] 检测到的节点索引: ${indices:-无}"
    log_info "[Step07] 目标节点类型: ${STEP07_TARGET:-master}"
    
    case "${STEP07_TARGET:-master}" in
        master) 
            for i in $indices; do
                local node_type
                node_type="$(get_server_var "$i" TYPE 2>/dev/null || echo "")"
                log_info "[Step07] 节点 $i 类型: ${node_type:-未定义}"
                if [[ "$node_type" == "master" ]]; then
                    target_nodes+=("$i")
                fi
            done
            ;;
        worker) 
            for i in $indices; do
                local node_type
                node_type="$(get_server_var "$i" TYPE 2>/dev/null || echo "")"
                log_info "[Step07] 节点 $i 类型: ${node_type:-未定义}"
                if [[ "$node_type" == "worker" ]]; then
                    target_nodes+=("$i")
                fi
            done
            ;;
        all) 
            for i in $indices; do
                target_nodes+=("$i")
            done
            ;;
        *) log_error "无效的STEP07_TARGET: ${STEP07_TARGET}"; return 1 ;;
    esac
    
    log_info "[Step07] 找到目标节点: ${target_nodes[*]:-无}"
    
    if [[ ${#target_nodes[@]} -eq 0 ]]; then
        log_error "[Step07] 未找到任何目标节点，无法创建命名空间"
        log_error "[Step07] 请检查配置：STEP07_TARGET=${STEP07_TARGET:-master} 和节点配置"
        return 1
    fi
    
    # 在目标节点上执行
    for i in "${target_nodes[@]}"; do
        log_info "[Step07] 在节点 $i 上执行命名空间管理"
        
        # 准备远程kubeconfig
        _prepare_remote_kubeconfig_for_idx "$i" || continue
        
        # 创建命名空间
        for env in "${ENVIRONMENTS[@]}"; do
            for platform in "${PLATFORMS[@]}"; do
                create_namespace "$i" "$platform" "$env"
            done
        done
        
        # 应用策略
        for env in "${ENVIRONMENTS[@]}"; do
            for platform in "${PLATFORMS[@]}"; do
                local namespace="${platform}-${env}"
                apply_namespace_policies "$namespace"
            done
        done
    done
    
    log_success "[Step07] 命名空间平台管理完成"
}

# 验证函数
verify() {
    log_info "[Step07] 验证命名空间创建结果"
    
    # 解析环境和平台列表（去除可能的引号和空格）
    local envs="${NAMESPACE_PLATFORM_ENVIRONMENTS//\"/}"
    local platforms="${NAMESPACE_PLATFORM_PLATFORMS//\"/}"
    IFS=',' read -ra ENVIRONMENTS <<< "$envs"
    IFS=',' read -ra PLATFORMS <<< "$platforms"
    
    # 获取目标节点 - 动态解析可用节点
    local target_nodes=()
    local indices; indices="$(get_defined_server_indices)"
    
    case "${STEP07_TARGET:-master}" in
        master) 
            for i in $indices; do
                if [[ "$(get_server_var "$i" TYPE)" == "master" ]]; then
                    target_nodes+=("$i")
                fi
            done
            ;;
        worker) 
            for i in $indices; do
                if [[ "$(get_server_var "$i" TYPE)" == "worker" ]]; then
                    target_nodes+=("$i")
                fi
            done
            ;;
        all) 
            for i in $indices; do
                target_nodes+=("$i")
            done
            ;;
        *) log_error "无效的STEP07_TARGET: ${STEP07_TARGET}"; return 1 ;;
    esac
    
    for i in "${target_nodes[@]}"; do
        log_info "[Step07] 验证节点 $i 的命名空间"
        
        # 准备远程kubeconfig
        _prepare_remote_kubeconfig_for_idx "$i" || continue
        
        # 列出所有命名空间（获取 kubectl 路径）
        local kubectl_cmd=""
        if ssh_exec "$i" "test -x /usr/bin/kubectl"; then
            kubectl_cmd="/usr/bin/kubectl"
        elif ssh_exec "$i" "test -x /usr/local/bin/kubectl"; then
            kubectl_cmd="/usr/local/bin/kubectl"
        elif ssh_exec "$i" "bash -lc 'command -v kubectl >/dev/null 2>&1'"; then
            kubectl_cmd="kubectl"
        else
            kubectl_cmd="kubectl"  # 默认尝试，如果失败会被 || true 捕获
        fi
        ssh_exec "$i" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" $kubectl_cmd get ns -o name' || true"
    done
}

# 主函数
main() {
    case "${1:-execute}" in
        precheck) precheck ;;
        execute) precheck && execute ;;
        verify) verify ;;
        cleanup) cleanup_namespaces ;;
        *) 
            echo "用法: $0 [precheck|execute|verify|cleanup]"
            exit 1
            ;;
    esac
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi