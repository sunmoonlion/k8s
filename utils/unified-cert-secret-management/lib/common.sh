#!/bin/bash

# =============================================================================
# 公共函数库
# 文件名: common.sh
# 用途: 提供TLS管理系统的公共函数
# 设计: 基于五层架构，提供通用工具函数
# =============================================================================

# =============================================================================
# 配置读取函数
# =============================================================================

# 读取配置值
get_config() {
    local key="$1"
    local default="${2:-}"
    
    # 从环境变量中读取（因为配置文件已经source）
    local value="${!key:-$default}"
    echo "$value"
}

# 自动计算Secret数量
get_secret_count() {
    local combo="$1"
    local count=0
    
    # 从环境变量中查找所有以 SECRET_${i}_TYPE 开头的配置
    for config_key in $(compgen -v | grep "^${combo}_SECRET_[0-9]\+_TYPE$"); do
        # 提取索引号
        if [[ "$config_key" =~ ^${combo}_SECRET_([0-9]+)_TYPE$ ]]; then
            # 只统计实际配置的Secret（TYPE不为空）
            local secret_type="${!config_key:-}"
            if [[ -n "$secret_type" ]]; then
                count=$((count + 1))
            fi
        fi
    done
    
    echo "$count"
}

# 获取五层架构配置 - 使用5位编码格式
get_five_layer_config() {
    # 检查参数数量，支持组合代码或6个参数
    if [[ $# -eq 2 ]]; then
        # 组合代码格式
        local combo="$1"
        local config_suffix="$2"
        local config_key="${combo}_${config_suffix}"
        get_config "$config_key"
    else
        # 6个参数格式
        local service_type="$1"      # harbor, mysql, postgresql, mongodb
        local server_env="$2"       # k8s, clastic
        local server_node="$3"       # 1, 2, 3, 4
        local client_env="$4"        # docker, nerdctl, k8s
        local client_node="$5"       # 1, 2, 3, 4
        local config_suffix="$6"     # ENABLED, SERVER_HOST, etc.
        
        # 生成5位编码
        local code=$(generate_five_layer_code "$service_type" "$server_env" "$server_node" "$client_env" "$client_node")
        local config_key="${code}_${config_suffix}"
        get_config "$config_key"
    fi
}

# 检查五层组合是否启用
is_five_layer_enabled() {
    local service_type="$1"
    local server_env="$2"
    local server_node="$3"
    local client_env="$4"
    local client_node="$5"
    
    local enabled=$(get_five_layer_config "$service_type" "$server_env" "$server_node" "$client_env" "$client_node" "ENABLED")
    # 如果没有ENABLED配置，默认启用
    if [[ -z "$enabled" ]]; then
        return 0
    fi
    [[ "$enabled" == "true" ]]
}

# 获取五层组合描述
get_five_layer_description() {
    local service_type="$1"
    local server_env="$2"
    local server_node="$3"
    local client_env="$4"
    local client_node="$5"

    local service_name=""
    case "$service_type" in
        "harbor") service_name="Harbor" ;;
        "mysql") service_name="MySQL" ;;
        "postgresql") service_name="PostgreSQL" ;;
        "mongodb") service_name="MongoDB" ;;
    esac

    local server_env_name=""
    case "$server_env" in
        "k8s") server_env_name="K8s" ;;
        "clastic") server_env_name="Clastic" ;;
    esac

    local client_env_name=""
    case "$client_env" in
        "docker") client_env_name="Docker" ;;
        "nerdctl") client_env_name="nerdctl" ;;
        "k8s") client_env_name="K8s" ;;
    esac
    
    echo "${service_name}-${server_env}-节点${server_node} -> ${client_env}-节点${client_node}"
}

# 生成5位编码
generate_five_layer_code() {
    local service_type="$1"
    local server_env="$2"
    local server_node="$3"
    local client_env="$4"
    local client_node="$5"

    # 处理单字符代码或完整名称
    local service_code=""
    case "$service_type" in
        "H"|"harbor"|"HARBOR") service_code="H" ;;
        "M"|"mysql"|"MYSQL") service_code="M" ;;
        "P"|"postgresql"|"POSTGRESQL") service_code="P" ;;
        "D"|"mongodb"|"MONGODB") service_code="D" ;;
    esac
    
    local server_env_code=""
    case "$server_env" in
        "K"|"k8s") server_env_code="K" ;;
        "C"|"clastic") server_env_code="C" ;;
    esac
    
    local client_env_code=""
    case "$client_env" in
        "D"|"docker") client_env_code="D" ;;
        "N"|"nerdctl") client_env_code="N" ;;
        "K"|"k8s") client_env_code="K" ;;
    esac
    
    echo "${service_code}${server_env_code}${server_node}${client_env_code}${client_node}"
}

# 验证五层参数
validate_five_layer_params() {
    local service_type="$1"
    local server_env="$2"
    local server_node="$3"
    local client_env="$4"
    local client_node="$5"

    if [[ -z "$service_type" || -z "$server_env" || -z "$server_node" || -z "$client_env" || -z "$client_node" ]]; then
        log_error "所有五层参数都必须提供。"
        return 1
    fi
    return 0
}

# =============================================================================
# 日志函数
# =============================================================================

# 简单的日志函数
log_success() { echo "✅ $*"; }
log_info() { echo "ℹ️  $*"; }
log_warn() { echo "⚠️  $*"; }
log_error() { echo "❌ $*"; }
log_debug() { echo "🔍 $*"; }

# =============================================================================
# 帮助函数
# =============================================================================

show_help() {
    clear
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                           TLS 管理系统 v4.0                                ║"
    echo "║                                帮助信息                                    ║"
    echo "╠══════════════════════════════════════════════════════════════════════════════╣"
    echo "║  本系统用于管理五层架构下的TLS证书。                                       ║"
    echo "║  五层架构定义如下:                                                         ║"
    echo "║  服务类型 -> 服务端环境 -> 服务端节点 -> 客户端环境 -> 客户端节点           ║"
    echo "║                                                                              ║"
    echo "║  编码规则:                                                                 ║"
    echo "║  - 第1位 (服务类型): H=Harbor, M=MySQL, P=PostgreSQL, D=MongoDB             ║"
    echo "║  - 第2位 (服务端环境): K=K8s, C=Clastic                                    ║"
    echo "║  - 第3位 (服务端节点): 1, 2, 3, 4 (数字)                                   ║"
    echo "║  - 第4位 (客户端环境): D=Docker, N=nerdctl, K=K8s                          ║"
    echo "║  - 第5位 (客户端节点): 1, 2, 3, 4 (数字)                                   ║"
    echo "║                                                                              ║"
    echo "║  示例: HARBOR_K1_D1 = Harbor-K8s-节点1 -> Docker-节点1                    ║"
    echo "║                                                                              ║"
    echo "║  操作流程:                                                                 ║"
    echo "║  1. 选择服务类型 (如 Harbor)                                               ║"
    echo "║  2. 选择服务端环境 (如 K8s)                                                ║"
    echo "║  3. 选择服务端节点 (如 节点1)                                              ║"
    echo "║  4. 选择客户端环境 (如 Docker)                                             ║"
    echo "║  5. 选择客户端节点 (如 节点1)                                              ║"
    echo "║  6. 确认并执行证书生成、分发和部署操作。                                   ║"
    echo "║                                                                              ║"
    echo "║  配置文件: cert-secret.conf (所有配置项均在此文件中定义)                   ║"
    echo "║  脚本: scripts/five-layer-deploy.sh (通用部署脚本)                         ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
}

# =============================================================================
# 暂停函数
# =============================================================================

pause_for_user() {
    read -p "按回车键继续..."
}