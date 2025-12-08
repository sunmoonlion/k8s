#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Step10: Kubernetes 节点管理
# 功能：管理 Kubernetes 节点的污点（Taints）
# 
# 主要特性：
# - 为指定节点添加污点
# - 支持多种污点类型（NoSchedule、NoExecute、PreferNoSchedule）
# - 通过配置文件控制污点设置
# - 支持批量节点管理
# - 完整的在线/离线部署模式
# - 分层开关控制系统
# - 详细的离线资源检查和报告
#
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$BASE_DIR/../utils/common.sh"

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

load_config_file || exit 1

STEP_PREFIX=STEP10
TARGET="${STEP10_TARGET:-master}"
PACKAGES_DEPLOY_MODE_EFFECTIVE="$(get_packages_deploy_mode)"
REMOTE_KUBECONFIG="${STEP10_REMOTE_KUBECONFIG:-/etc/kubernetes/admin.conf}"
REMOTE_DIR_FALLBACK="${STEP10_REMOTE_DIR_FALLBACK:-~/packages-to-be-installed}"
ONLINE_TIMEOUT="${STEP10_ONLINE_TIMEOUT:-300}"

# 版本配置
KUBECTL_VERSION="${STEP10_KUBECTL_VERSION:-1.30.4}"

required_artifacts(){
    if [[ "$PACKAGES_DEPLOY_MODE_EFFECTIVE" == "offline" ]]; then
        # 不需要额外的离线资源，使用现有的 kubectl
        echo "type=images image='registry.k8s.io/kubectl:v${KUBECTL_VERSION}'"
    fi
}

if [[ "${1:-}" == "--required-artifacts" ]]; then
    required_artifacts
    exit 0
fi

precheck(){
    log_info "[Step10] 预检节点管理配置"
    
    # 1. 步骤总开关检查
    if [[ "${STEP10_ENABLED:-false}" != "true" ]]; then
        log_info "[Step10] STEP10_ENABLED=false，跳过"
        exit 0
    fi
    
    # 2. 检查是否有任何节点污点配置
    local has_taint_config=false
    
    # 检查所有可能的节点污点配置
    for idx in {1..64}; do
        local taint_var="STEP10_NODE_${idx}_TAINTS"
        if [[ -n "${!taint_var:-}" ]]; then
            has_taint_config=true
            break
        fi
    done
    
    if [[ "$has_taint_config" == "false" ]]; then
        log_info "[Step10] 没有配置任何节点污点，跳过"
        exit 0
    fi
    
    # 3. 配置项验证
    _validate_node_management_config
    
    log_info "[Step10] 预检通过"
}

ensure_resources(){
    if [[ "$PACKAGES_DEPLOY_MODE_EFFECTIVE" == "offline" ]]; then
        log_info "[Step10] 离线模式：检查必需资源"
        
        # 检查 kubectl 是否可用 - 找到master节点进行检查
        local master_node_idx
        master_node_idx=$(_find_master_node_index)
        if [[ -z "$master_node_idx" ]]; then
            log_error "[Step10] 未找到master节点"
            return 1
        fi
        
        if ! ssh_exec "$master_node_idx" "bash -lc 'command -v kubectl >/dev/null 2>&1'"; then
            log_error "[Step10] 目标节点未安装 kubectl"
            return 1
        fi
        
        log_info "[Step10] 所有离线资源检查通过"
    fi
}

execute(){
    log_info "[Step10] 在节点 $i 管理 Kubernetes 节点"
    
    local node_type=$(get_server_var "$i" TYPE)
    
    # K8s层操作（仅在master节点执行）
    if [[ "$node_type" == "master" ]]; then
        _prepare_remote_kubeconfig "$i"
        _manage_node_taints "$i"
    fi
}

verify(){ 
    log_info "[Step10] 验证节点管理配置"
    
    # 找到master节点进行验证
    local master_node_idx
    master_node_idx=$(_find_master_node_index)
    
    _prepare_remote_kubeconfig "$master_node_idx"
    _verify_node_taints "$master_node_idx"
    
    _show_node_status "$master_node_idx"
    log_info "[Step10] 节点管理配置完成"
}

# ============================================================================
# 配置验证函数
# ============================================================================

_validate_node_management_config(){
    log_info "[Step10] 验证配置参数"
    
    # 验证污点格式
    local indices; indices="$(get_defined_server_indices)"
    
    for idx in $indices; do
        local taint_var="STEP10_NODE_${idx}_TAINTS"
        local taints="${!taint_var:-}"
        
        if [[ -n "$taints" ]]; then
            # 验证污点格式
            if ! _validate_taint_format "$taints"; then
                log_error "[Step10] 节点 $idx 的污点格式无效: $taints"
                return 1
            fi
        fi
    done
    
    log_info "[Step10] 配置验证通过"
}

_validate_taint_format(){
    local taints="$1"
    
    # 解析污点配置（格式：key1=value1:NoSchedule,key2=value2:NoExecute）
    IFS=',' read -ra TAINT_ARRAY <<< "$taints"
    
    for taint in "${TAINT_ARRAY[@]}"; do
        if [[ -n "$taint" ]]; then
            # 检查污点格式：key=value:effect 或 key:effect
            if [[ "$taint" == *":"* ]]; then
                local key_value="${taint%:*}"
                local effect="${taint##*:}"
                
                # 验证效果
                if [[ "$effect" != "NoSchedule" && "$effect" != "NoExecute" && "$effect" != "PreferNoSchedule" ]]; then
                    log_error "[Step10] 无效的污点效果: $effect"
                    return 1
                fi
            else
                log_error "[Step10] 污点格式无效，缺少效果: $taint"
                return 1
            fi
        fi
    done
    
    return 0
}

# ============================================================================
# 辅助函数
# ============================================================================

_find_master_node_index(){
    local indices; indices="$(get_defined_server_indices)"
    for idx in $indices; do
        local node_type=$(get_server_var "$idx" TYPE)
        if [[ "$node_type" == "master" ]]; then
            echo "$idx"
            return 0
        fi
    done
    log_error "[Step10] 未找到master节点"
    return 1
}

_prepare_remote_kubeconfig(){
    local node_idx="$1"
    prepare_remote_kubeconfig "$node_idx" "REMOTE_KUBECONFIG" || {
        log_error "[Step10] 无法在远端节点 $node_idx 准备可读的 kubeconfig"
        return 1
    }
}

# ============================================================================
# 节点污点管理函数
# ============================================================================

_manage_node_taints(){
    local master_node_idx="$1"
    
    log_info "[Step10] 管理节点污点"
    
    # 获取所有启用的节点污点配置
    local indices; indices="$(get_defined_server_indices)"
    
    for idx in $indices; do
        local taint_var="STEP10_NODE_${idx}_TAINTS"
        local taints="${!taint_var:-}"
        
        if [[ -n "$taints" ]]; then
            _apply_node_taints "$master_node_idx" "$idx" "$taints"
        fi
    done
}

_apply_node_taints(){
    local master_node_idx="$1"
    local node_idx="$2"
    local taints="$3"
    
    # 获取节点名称
    local node_name
    node_name="$(get_server_var "$node_idx" CLUSTER_HOSTNAME)"
    [[ -z "$node_name" ]] && node_name="$(get_server_var "$node_idx" CURRENT_HOSTNAME)"
    
    if [[ -z "$node_name" ]]; then
        log_error "[Step10] 无法获取节点 $node_idx 的主机名"
        return 1
    fi
    
    log_info "[Step10] 为节点 $node_name 应用污点: $taints"
    
    # 解析污点配置（格式：key1=value1:NoSchedule,key2=value2:NoExecute）
    IFS=',' read -ra TAINT_ARRAY <<< "$taints"
    
    for taint in "${TAINT_ARRAY[@]}"; do
        if [[ -n "$taint" ]]; then
            # 解析污点格式：key=value:effect
            if [[ "$taint" == *":"* ]]; then
                local key_value="${taint%:*}"
                local effect="${taint##*:}"
                
                if [[ "$key_value" == *"="* ]]; then
                    local key="${key_value%=*}"
                    local value="${key_value#*=}"
                    local full_taint="${key}=${value}:${effect}"
                else
                    local full_taint="${key_value}:${effect}"
                fi
            else
                # 默认使用 NoSchedule 效果
                local full_taint="${taint}:NoSchedule"
            fi
            
            log_info "[Step10] 应用污点: $full_taint"
            
            # 应用污点
            if ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl taint node \"$node_name\" \"$full_taint\" --overwrite'"; then
                log_success "[Step10] 节点 $node_name 污点应用成功: $full_taint"
            else
                log_error "[Step10] 节点 $node_name 污点应用失败: $full_taint"
            fi
        fi
    done
}

# ============================================================================
# 验证函数
# ============================================================================

_verify_node_taints(){
    local master_node_idx="$1"
    
    log_info "[Step10] 验证节点污点"
    
    # 显示所有节点的污点
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints'"
}

_show_node_status(){
    local master_node_idx="$1"
    
    log_info "[Step10] 显示节点状态"
    
    echo ""
    log_info "节点信息:"
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl get nodes -o wide'"
    
    echo ""
    log_info "节点污点详情:"
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl describe nodes | grep -A 10 \"Taints:\" || echo \"未找到污点信息\"'"
    echo ""
}

# ============================================================================
# 主函数
# ============================================================================

main(){ 
    precheck
    ensure_resources
    for_each_node "$TARGET" execute
    verify
}

main "$@"