#!/bin/bash

# =============================================================================
# TLS管理系统 - 自动部署脚本
# 文件名: deploy-all.sh
# 用途: 根据cert-secret.conf中已配置的组合自动部署服务端和客户端
# 支持模式: 初始化部署、证书轮换、强制更新
# 注意: 此脚本已合并 rotate-certs.sh 的所有功能，支持命令行参数
# =============================================================================

set -euo pipefail

# 获取项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 计算 k8s 根目录（utils 的父目录）
# unified-cert-secret-management/ -> utils/ -> k8s/
K8S_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"

# 显示使用说明
show_usage() {
    echo "TLS管理系统 - 自动部署脚本"
    echo "================================"
    echo ""
    echo "用法: $0 [选项] [模式] [SECRET_FILTER...]"
    echo ""
    echo "选项:"
    echo "  -c, --cluster CLUSTER    指定集群标识（如 C1, c1, C2），会应用对应的集群配置"
    echo "                           注意：会自动转换为大写格式（c1 -> C1）"
    echo "  -h, --help               显示此帮助信息"
    echo ""
    echo "模式:"
    echo "  rotate    证书轮换（默认）- CA证书已存在则跳过，服务器证书重新生成，重启组件"
    echo "  init      初始化部署 - 仅生成和分发CA证书，不生成服务器证书，不重启组件"
    echo "  force     强制更新 - 删除所有证书并强制重新生成，重启组件"
    echo ""
    echo "SECRET_FILTER:"
    echo "  精确匹配: 指定完整组合名，如 TRAEFIK_K1_K1"
    echo "  前缀匹配: 指定服务名，如 TRAEFIK 匹配所有 TRAEFIK_* 组合"
    echo "  多参数: 可指定多个过滤器，用空格分隔"
    echo ""
    echo "环境变量（优先级低于命令行参数）:"
    echo "  CLUSTER                  集群标识（如 C1, c1, C2），会自动转换为大写格式"
    echo "  TLS_MODE                 运行模式: init(初始化), rotate(轮换), force(强制更新)"
    echo "  SECRET_FILTERS           Secret过滤器，支持精确匹配和前缀匹配"
    echo ""
    echo "示例:"
    echo "  $0                           # 执行所有证书轮换（默认rotate模式）"
    echo "  $0 rotate                    # 执行所有证书轮换"
    echo "  $0 force                     # 强制重新生成所有证书"
    echo "  $0 init                      # 初始化部署（仅CA证书）"
    echo "  $0 --cluster C1 rotate       # 使用集群1配置执行轮换"
    echo "  $0 -c C2 force TRAEFIK_K1_K1  # 使用集群2配置，强制更新 TRAEFIK_K1_K1"
    echo "  $0 rotate TRAEFIK            # 处理所有 TRAEFIK_* 组合"
    echo "  TLS_MODE=force $0             # 通过环境变量指定模式"
    echo ""
}

# 解析命令行参数
CLUSTER_ARG=""
MODE_ARG=""
SECRET_FILTERS_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--cluster)
            if [[ -z "${2:-}" ]]; then
                echo "错误: --cluster 参数需要指定集群标识（如 C1, C2）"
                exit 1
            fi
            CLUSTER_ARG="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        rotate|init|force)
            # 模式参数
            if [[ -z "$MODE_ARG" ]]; then
                MODE_ARG="$1"
            else
                # 如果已经设置了模式，将其作为过滤器
                SECRET_FILTERS_ARGS+=("$1")
            fi
            shift
            ;;
        *)
            # 其他参数作为过滤器或模式
            if [[ -z "$MODE_ARG" ]] && [[ "$1" =~ ^(rotate|init|force)$ ]]; then
                MODE_ARG="$1"
            else
                SECRET_FILTERS_ARGS+=("$1")
            fi
            shift
            ;;
    esac
done

# 设置集群配置（优先级：命令行参数 > CLUSTER 环境变量 > 全局配置文件默认值）
if [[ -n "$CLUSTER_ARG" ]]; then
    # 自动转换集群标识为大写格式（c1 -> C1）
    if [[ "$CLUSTER_ARG" =~ ^[cC][0-9]+$ ]]; then
        export CLUSTER=$(echo "$CLUSTER_ARG" | tr "[:lower:]" "[:upper:]")
    else
        export CLUSTER="$CLUSTER_ARG"
    fi
elif [[ -n "${CLUSTER:-}" ]]; then
    # 环境变量中的集群标识也自动转换
    if [[ "$CLUSTER" =~ ^[cC][0-9]+$ ]]; then
        export CLUSTER=$(echo "$CLUSTER" | tr "[:lower:]" "[:upper:]")
    fi
else
    # 如果既没有参数也没有环境变量，先不设置，让 apply_cluster_config_mapping 从全局配置读取
    # 注意：不要设置为空字符串，这样 apply_cluster_config_mapping 才能正确读取默认值
    unset CLUSTER
fi

# 保存命令行参数中的模式（如果有）
SAVED_MODE_ARG="$MODE_ARG"

# Secret过滤器配置（优先级：命令行参数 > 环境变量）
if [[ ${#SECRET_FILTERS_ARGS[@]} -gt 0 ]]; then
    export SECRET_FILTERS="${SECRET_FILTERS_ARGS[*]}"
elif [[ -z "${SECRET_FILTERS:-}" ]]; then
    SECRET_FILTERS=""
fi

# 本地化设置，避免 locale 警告
export LC_ALL=C

# 自动清理临时证书文件（仅删除本工具生成的临时目录/文件）
echo "清理临时证书文件..."
rm -rf \
  /tmp/*-ca-certs \
  /tmp/*-server-certs \
  /tmp/*-data \
  /tmp/*-tls.yaml \
  /tmp/harbor*.yaml \
  /tmp/cert-secret-* \
  2>/dev/null || true
echo "临时文件清理完成"

# 解析配置文件优先级
CONFIG_FILE="$PROJECT_ROOT/cert-secret.conf"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: 配置文件不存在: $CONFIG_FILE"
    exit 1
fi
echo "使用配置文件: $CONFIG_FILE"
source "$CONFIG_FILE"

# 加载集群配置映射函数（用于将 C1_* 或 C2_* 映射为默认配置）
if [[ -f "$K8S_ROOT/utils/cluster-config-mapping.sh" ]]; then
    source "$K8S_ROOT/utils/cluster-config-mapping.sh"
    # 应用集群配置映射（使用 CLUSTER）
    if command -v apply_cluster_config_mapping &>/dev/null; then
        # 调试：检查调用前的 CLUSTER
        echo "调试：调用 apply_cluster_config_mapping 前，CLUSTER=${CLUSTER:-未设置}"
        apply_cluster_config_mapping
        # 调试：检查调用后的 CLUSTER
        echo "调试：调用 apply_cluster_config_mapping 后，CLUSTER=${CLUSTER:-未设置}"
        # 如果 apply_cluster_config_mapping 设置了 CLUSTER（从全局配置读取），使用它
        if [[ -n "${CLUSTER:-}" ]]; then
            export CLUSTER="${CLUSTER}"
            echo "应用集群配置: CLUSTER=${CLUSTER}"
        else
            echo "集群配置: 未指定（使用默认配置）"
        fi
    fi
fi

# 运行模式配置
# 支持的模式: init(初始化), rotate(轮换), force(强制更新)
# 优先级：命令行参数 > 环境变量 > 配置文件 > 默认值(rotate)
# 配置文件中的 TLS_MODE 已在 cert-secret.conf 中定义并加载
# 现在应用优先级：命令行参数 > 环境变量 > 配置文件 > 默认值
if [[ -n "$SAVED_MODE_ARG" ]]; then
    # 命令行参数优先级最高
    export TLS_MODE="$SAVED_MODE_ARG"
elif [[ -n "${TLS_MODE:-}" ]]; then
    # 环境变量或配置文件中的值
    export TLS_MODE="$TLS_MODE"
else
    # 默认值
    export TLS_MODE="rotate"
fi

# 验证运行模式
case "$TLS_MODE" in
    "init"|"rotate"|"force")
        # 模式有效
        ;;
    *)
        echo "ERROR: 未知运行模式: $TLS_MODE"
        echo "  支持的模式: init, rotate, force"
        exit 1
        ;;
esac

# 加载公共函数
source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/ssh.sh"
# 加载证书管理核心函数（包含基于 CLIENT_CONTAINERD_PATH / CLIENT_DOCKER_PATH 的新一代分发逻辑）
source "$PROJECT_ROOT/lib/cert.sh"

# 显示运行模式信息
show_mode_info() {
    case "$TLS_MODE" in
        "init")
            echo "运行模式: 初始化部署"
            echo "  用途: K8s系统初始化时只生成和分发CA证书"
            echo "  特点: 生成CA证书，归档CA证书，分发CA到客户端节点"
            echo "  关闭: 服务器证书生成、Secret生成和部署、组件重启"
            ;;
        "rotate")
            echo "运行模式: 证书轮换"
            echo "  用途: 定期轮换证书，更新现有Secret"
            echo "  特点: CA证书已存在则跳过，服务器证书重新生成，更新Secret，重启相关组件"
            ;;
        "force")
            echo "运行模式: 强制更新"
            echo "  用途: 强制重新生成和部署所有证书"
            echo "  特点: 忽略现有证书，强制重新生成"
            ;;
        *)
            echo "ERROR: 未知运行模式: $TLS_MODE"
            echo "  支持的模式: init, rotate, force"
            exit 1
            ;;
    esac
    echo ""
}

# 部署脚本路径
DEPLOY_SERVER_SCRIPT="$PROJECT_ROOT/scripts/deploy-server.sh"
DEPLOY_CLIENT_SCRIPT="$PROJECT_ROOT/scripts/deploy-client.sh"

# 检查组合是否已配置
is_combo_configured() {
    local combo="$1"
    local config_var="${combo}_ENABLED"
    
    if [[ "${!config_var:-}" == "true" ]]; then
        echo "SUCCESS: $combo 配置已启用" >&2
        return 0
    else
        echo "ERROR: $combo 配置未启用" >&2
        return 1
    fi
}

# 检查组合是否匹配过滤器
is_combo_matched() {
    local combo="$1"
    local filters="$2"
    
    # 如果没有过滤器，匹配所有组合
    if [[ -z "$filters" ]]; then
        return 0
    fi
    
    # 将过滤器字符串转换为数组
    local filter_array=()
    IFS=' ' read -ra filter_array <<< "$filters"
    
    # 检查每个过滤器
    for filter in "${filter_array[@]}"; do
        # 精确匹配
        if [[ "$combo" == "$filter" ]]; then
            return 0
        fi
        
        # 前缀匹配（服务名匹配）
        if [[ "$combo" == "${filter}_"* ]]; then
            return 0
        fi
    done
    
    return 1
}

# 获取所有已配置的组合
get_configured_combinations() {
    local combinations=()
    
    # 动态扫描配置文件中的所有 *_ENABLED="true" 配置项
    while IFS='=' read -r key value; do
        # 跳过注释和空行
        if [[ "$key" =~ ^[[:space:]]*# ]] || [[ -z "$key" ]]; then
            continue
        fi
        
        # 检查是否是 ENABLED 配置项，但排除 SECRET_*_ENABLED 配置项
        if [[ "$key" =~ _ENABLED$ ]] && [[ ! "$key" =~ _SECRET_.*_ENABLED$ ]]; then
            # 提取组合名称（去掉 _ENABLED 后缀）
            local combo="${key%_ENABLED}"
            
            # 检查值是否为 "true"
            if [[ "$value" == "\"true\"" ]] || [[ "$value" == "true" ]]; then
                # 先检查是否匹配过滤器
                if is_combo_matched "$combo" "$SECRET_FILTERS"; then
                    # 再根据当前 CLUSTER 过滤远程 / KIND 组合的适用性
                    # 约定：
                    #   - CLUSTER=KIND 时，仅处理 *KIND* 相关组合（如 TRAEFIK_KIND_KIND）
                    #   - CLUSTER 为 C1/C2/... 时，跳过 KIND 专用组合（如 TRAEFIK_KIND_KIND）
                    if [[ -n "${CLUSTER:-}" ]]; then
                        local cluster_upper
                        cluster_upper="$(echo "$CLUSTER" | tr '[:lower:]' '[:upper:]')"
                        case "$cluster_upper" in
                            KIND)
                                # Kind 模式：只保留 KIND 相关组合
                                if [[ "$combo" != *"_KIND_"* ]]; then
                                    echo "跳过组合（当前为 KIND 模式，仅处理 KIND 组合）: $combo" >&2
                                    continue
                                fi
                                ;;
                            C[0-9]*)
                                # 远程模式（C1/C2/...）：跳过 KIND 专用组合
                                if [[ "$combo" == *"_KIND_"* ]]; then
                                    echo "跳过组合（远程集群不处理 KIND 组合）: $combo" >&2
                                    continue
                                fi
                                ;;
                            *)
                                # 其它集群标识：暂不额外过滤
                                ;;
                        esac
                    fi

                    combinations+=("$combo")
                    echo "发现已启用的组合: $combo" >&2
                else
                    echo "跳过组合（不匹配过滤器）: $combo" >&2
                fi
            fi
        fi
    done < "$CONFIG_FILE"
    
    echo "${combinations[@]}"
}

# 服务端部署函数
deploy_server() {
    local combo="$1"
    
    # 解析组合名称 (例如: HARBOR_K1_K1 -> HARBOR K 1 K 1)
    # 新格式: 服务名全称_服务端环境_服务端节点_客户端环境_客户端节点
    # 特殊：TRAEFIK_KIND_KIND 这类 KIND 组合需要保持 KIND 语义，又要复用 K 插件
    IFS='_' read -ra PARTS <<< "$combo"
    local service_type="${PARTS[0]}"       # HARBOR / TRAEFIK 等
    local server_env server_node client_env client_node

    if [[ "${PARTS[1]}" == "KIND" && "${PARTS[2]}" == "KIND" ]]; then
        # KIND 组合：保持 combo = TRAEFIK_KIND_KIND，但插件仍使用 K 环境
        # 约定：server_env=K, server_node=IND → 重新拼接时得到 KIND
        server_env="K"
        server_node="IND"
        client_env="K"
        client_node="IND"
    else
        # 常规组合：如 HARBOR_K1_K1 / TRAEFIK_K1_D2
        if [[ "${PARTS[1]}" =~ ^([A-Z])([0-9]+)$ ]]; then
            server_env="${BASH_REMATCH[1]}"
            server_node="${BASH_REMATCH[2]}"
        else
            server_env="${PARTS[1]:0:1}"
            server_node="${PARTS[1]:1:1}"
        fi
        if [[ "${PARTS[2]}" =~ ^([A-Z])([0-9]+)$ ]]; then
            client_env="${BASH_REMATCH[1]}"
            client_node="${BASH_REMATCH[2]}"
        else
            client_env="${PARTS[2]:0:1}"
            client_node="${PARTS[2]:1:1}"
        fi
    fi
    
    # 获取服务端配置
    local server_host="${combo}_SERVER_HOST"
    local server_port="${combo}_SERVER_PORT"
    local server_username="${combo}_SERVER_USERNAME"
    local server_ssh_key="${combo}_SERVER_SSH_KEY"
    
    if [[ -n "${!server_host:-}" ]]; then
        echo "连接到服务端: ${!server_host}:${!server_port:-22}"
        echo "用户名: ${!server_username:-root}"
        echo "SSH密钥: ${!server_ssh_key:-/root/.ssh/id_rsa}"
        
        # 调用实际的服务端部署脚本
        echo "执行服务端部署..."
        if [[ -f "$DEPLOY_SERVER_SCRIPT" ]]; then
            echo "调用部署脚本: $DEPLOY_SERVER_SCRIPT"
            echo "组合: $combo -> $service_type $server_env $server_node $client_env $client_node"
            
            # 设置环境变量供部署脚本使用
            export COMBO="$combo"
            export SERVER_HOST="${!server_host}"
            export SERVER_PORT="${!server_port:-22}"
            export SERVER_USERNAME="${!server_username:-root}"
            export SERVER_SSH_KEY="${!server_ssh_key:-/root/.ssh/id_rsa}"
            export TLS_MODE="${TLS_MODE:-rotate}"  # 传递运行模式到部署脚本
            # 传递 CLUSTER 环境变量到部署脚本（确保集群配置映射能正确工作）
            if [[ -n "${CLUSTER:-}" ]]; then
                export CLUSTER="${CLUSTER}"
            fi
            
            # 调用部署脚本，传递正确的5个参数
            if bash "$DEPLOY_SERVER_SCRIPT" "$service_type" "$server_env" "$server_node" "$client_env" "$client_node"; then
                echo "SUCCESS: 服务端部署完成"
            else
                echo "ERROR: 服务端部署失败"
                return 1
            fi
        else
            echo "ERROR: 服务端部署脚本不存在: $DEPLOY_SERVER_SCRIPT"
            return 1
        fi
    else
        # 检查是否是共享服务端的情况（多个组合共享同一个服务端）
        local server_prefix="${service_type}_${server_env}${server_node}"
        local shared_server_host="${server_prefix}_K1_SERVER_HOST"
        if [[ -n "${!shared_server_host:-}" ]]; then
            echo "ℹ️  此组合共享服务端配置（服务端已由 ${server_prefix}_K1 组合处理），跳过服务端部署"
        else
            echo "⚠️  服务端配置不完整（${combo}_SERVER_HOST 未配置），跳过服务端部署"
            echo "   提示：如果此组合共享服务端，请确保对应的服务端组合已配置"
        fi
    fi
}

# 客户端部署函数
deploy_client() {
    local combo="$1"
    
    # 解析组合名称 (例如: HARBOR_K1_K1 -> HARBOR K 1 K 1)
    # 新格式: 服务名全称_服务端环境_服务端节点_客户端环境_客户端节点
    # 特殊：TRAEFIK_KIND_KIND 这类 KIND 组合需要保持 KIND 语义，又要复用 K 插件
    IFS='_' read -ra PARTS <<< "$combo"
    local service_type="${PARTS[0]}"       # HARBOR / TRAEFIK 等
    local server_env server_node client_env client_node

    if [[ "${PARTS[1]}" == "KIND" && "${PARTS[2]}" == "KIND" ]]; then
        # KIND 组合：保持 combo = TRAEFIK_KIND_KIND，但插件仍使用 K 环境
        server_env="K"
        server_node="IND"
        client_env="K"
        client_node="IND"
    else
        if [[ "${PARTS[1]}" =~ ^([A-Z])([0-9]+)$ ]]; then
            server_env="${BASH_REMATCH[1]}"
            server_node="${BASH_REMATCH[2]}"
        else
            server_env="${PARTS[1]:0:1}"
            server_node="${PARTS[1]:1:1}"
        fi
        if [[ "${PARTS[2]}" =~ ^([A-Z])([0-9]+)$ ]]; then
            client_env="${BASH_REMATCH[1]}"
            client_node="${BASH_REMATCH[2]}"
        else
            client_env="${PARTS[2]:0:1}"
            client_node="${PARTS[2]:1:1}"
        fi
    fi
    
    # 获取客户端基础配置（Docker/nerdctl 客户端使用 CLIENT_HOST，K8s 客户端使用多节点配置）
    local client_host="${combo}_CLIENT_HOST"
    local client_port="${combo}_CLIENT_PORT"
    local client_username="${combo}_CLIENT_USERNAME"
    local client_ssh_key="${combo}_CLIENT_SSH_KEY"
    
    # 对于 K8s 客户端（client_env=K），不强制要求 CLIENT_HOST，
    # 由插件和配套的 CLIENT_NODES / CLIENT_NODE_HOSTS 等配置决定如何分发到各节点。
    # KIND 模式下：客户端 CA 分发由 kind-infrastructure 专用脚本负责，这里只负责 CA 生成/归档
    if [[ -n "${CLUSTER:-}" ]]; then
        local cluster_upper
        cluster_upper="$(echo "$CLUSTER" | tr '[:lower:]' '[:upper:]')"
        if [[ "$cluster_upper" == "KIND" && "$combo" == "TRAEFIK_KIND_KIND" ]]; then
            echo "ℹ️  KIND 模式下，Traefik 客户端 CA 分发由 kind-infrastructure 处理，此处仅负责 CA 生成，跳过客户端部署: $combo"
            return 0
        fi
    fi

    if [[ "$client_env" == "K" ]] || [[ -n "${!client_host:-}" ]]; then
        if [[ "$client_env" == "K" ]]; then
            echo "使用 K8s 多节点客户端配置，组合: $combo -> $service_type $server_env $server_node $client_env $client_node"
        else
            echo "连接到客户端: ${!client_host}:${!client_port:-22}"
            echo "用户名: ${!client_username:-root}"
            echo "SSH密钥: ${!client_ssh_key:-/root/.ssh/id_rsa}"
        fi
        
        # 调用实际的客户端部署脚本
        echo "执行客户端部署..."
        if [[ -f "$DEPLOY_CLIENT_SCRIPT" ]]; then
            echo "调用部署脚本: $DEPLOY_CLIENT_SCRIPT"
            echo "组合: $combo -> $service_type $server_env $server_node $client_env $client_node"
            
            # 设置环境变量供部署脚本使用
            export COMBO="$combo"
            if [[ "$client_env" != "K" ]]; then
                export CLIENT_HOST="${!client_host}"
                export CLIENT_PORT="${!client_port:-22}"
                export CLIENT_USERNAME="${!client_username:-root}"
                export CLIENT_SSH_KEY="${!client_ssh_key:-/root/.ssh/id_rsa}"
            fi
            export TLS_MODE="${TLS_MODE:-rotate}"  # 传递运行模式到部署脚本
            # 传递 CLUSTER 环境变量到部署脚本（确保集群配置映射能正确工作）
            if [[ -n "${CLUSTER:-}" ]]; then
                export CLUSTER="${CLUSTER}"
            fi
            
            # 调用部署脚本，传递正确的5个参数
            if bash "$DEPLOY_CLIENT_SCRIPT" "$service_type" "$server_env" "$server_node" "$client_env" "$client_node"; then
                echo "SUCCESS: 客户端部署完成"
            else
                echo "ERROR: 客户端部署失败"
                return 1
            fi
        else
            echo "ERROR: 客户端部署脚本不存在: $DEPLOY_CLIENT_SCRIPT"
            return 1
        fi
    else
        echo "ERROR: 客户端配置不完整，跳过部署"
    fi
}

# 简单的组件重启函数
restart_components() {
    local combo="$1"

    # 由各 Secret 的 SECRET_<i>_ENABLED 决定是否纳入重启列表；不使用组合级开关
    # 支持处理所有启用的 Secret（SECRET_0, SECRET_1, SECRET_2...）的重启配置
    
    echo "检查组件重启配置: $combo"
    
    # 获取服务端配置
    local server_host="${combo}_SERVER_HOST"
    local server_port="${combo}_SERVER_PORT"
    local server_username="${combo}_SERVER_USERNAME"
    local server_ssh_key="${combo}_SERVER_SSH_KEY"
    
    if [[ -z "${!server_host:-}" ]]; then
        echo "⚠️  此组合共享服务端配置（服务端已由其他组合处理），跳过重启"
        return 0
    fi
    
    # 收集所有需要重启的组件（去重）
    local all_components=()
    local secret_index=0
    
    # 遍历所有可能的 Secret（SECRET_0, SECRET_1, SECRET_2...最多到 SECRET_100）
    while [[ $secret_index -le 100 ]]; do
        # 检查 Secret 是否配置（通过检查 TYPE 是否存在）
        local secret_type_config="${combo}_SECRET_${secret_index}_TYPE"
        local secret_type="${!secret_type_config:-}"
        
        # 如果 Secret 未配置（TYPE 为空），跳过
        if [[ -z "$secret_type" ]]; then
            secret_index=$((secret_index + 1))
            continue
        fi
        
        # 获取组件列表
        local components_config="${combo}_SECRET_${secret_index}_RESTART_COMPONENTS_LIST"
        local components="${!components_config:-}"
        
        if [[ -z "$components" ]]; then
            echo "  SECRET_${secret_index}: 未配置组件列表，跳过重启"
            secret_index=$((secret_index + 1))
            continue
        fi
        
        echo "  SECRET_${secret_index}: 需要重启的组件: $components"
        
        # 将组件添加到列表（去重）
        IFS=',' read -ra component_array <<< "$components"
        for component in "${component_array[@]}"; do
            component=$(echo "$component" | xargs) # 去除空格
            if [[ -n "$component" ]]; then
                # 检查是否已存在（去重）
                local exists=false
                for existing in "${all_components[@]}"; do
                    if [[ "$existing" == "$component" ]]; then
                        exists=true
                        break
                    fi
                done
                if [[ "$exists" == "false" ]]; then
                    all_components+=("$component")
                fi
            fi
        done
        
        secret_index=$((secret_index + 1))
    done
    
    # 如果没有需要重启的组件，返回
    if [[ ${#all_components[@]} -eq 0 ]]; then
        echo "没有需要重启的组件: $combo"
        return 0
    fi
    
    echo "重启相关组件: $combo (共 ${#all_components[@]} 个组件)"
    
    # 重启所有收集到的组件
    for component in "${all_components[@]}"; do
        echo "重启组件: $component"
        
        # 在所有命名空间中查找组件
        local check_cmd="kubectl get deployment,statefulset,daemonset --all-namespaces --no-headers 2>/dev/null | grep \"$component\" | awk '{print \$1 \":\" \$2}'"
        local result=$(ssh -i "${!server_ssh_key:-/root/.ssh/id_rsa}" -p "${!server_port:-22}" "${!server_username:-root}@${!server_host}" "$check_cmd" 2>/dev/null || echo "")
        
        if [[ -n "$result" ]]; then
            local found_namespace=$(echo "$result" | cut -d':' -f1)
            local resource_info=$(echo "$result" | cut -d':' -f2)
            local resource_type=$(echo "$resource_info" | cut -d'/' -f1)
            local resource_name=$(echo "$resource_info" | cut -d'/' -f2)
            
            # 重启组件
            local restart_cmd="kubectl rollout restart $resource_type/$resource_name -n $found_namespace"
            if ssh -i "${!server_ssh_key:-/root/.ssh/id_rsa}" -p "${!server_port:-22}" "${!server_username:-root}@${!server_host}" "$restart_cmd" 2>/dev/null; then
                echo "SUCCESS: 组件 $resource_type/$resource_name (命名空间: $found_namespace) 重启成功"
            else
                echo "ERROR: 组件 $resource_type/$resource_name (命名空间: $found_namespace) 重启失败"
            fi
        else
            echo "WARNING: 组件 $component 不存在，跳过"
        fi
    done
}

# 主部署函数
deploy_all_combinations() {
    echo "🔐 TLS证书管理 - $TLS_MODE 模式"
    echo "================================"
    echo ""
    
    # 显示运行模式信息
    show_mode_info
    
    # 显示集群配置信息
    if [[ -n "${CLUSTER:-}" ]]; then
        echo "集群配置: ${CLUSTER}"
    else
        echo "集群配置: 未指定（使用默认配置）"
    fi
    echo ""
    
    # 显示过滤器信息
    if [[ -n "$SECRET_FILTERS" ]]; then
        echo "Secret过滤器: $SECRET_FILTERS"
        echo "将只处理匹配过滤器的组合"
    else
        echo "Secret过滤器: 无（处理所有已启用的组合）"
    fi
    echo ""
    
    # 获取所有已配置的组合
    local combinations=($(get_configured_combinations))
    
    if [[ ${#combinations[@]} -eq 0 ]]; then
        if [[ -n "$SECRET_FILTERS" ]]; then
            echo "ERROR: 没有找到匹配过滤器的组合"
            echo "过滤器: $SECRET_FILTERS"
        else
            echo "ERROR: 没有找到已配置的组合"
        fi
        return 1
    fi
    
    echo "发现 ${#combinations[@]} 个匹配的组合:"
    for combo in "${combinations[@]}"; do
        echo "  - $combo"
    done
    echo ""
    
    # 部署每个组合（组件级独立证书管理）
    for combo in "${combinations[@]}"; do
        echo "处理组合: $combo"
        echo "================================"
        
        # 部署服务端
        deploy_server "$combo"
        
        # 部署客户端
        deploy_client "$combo"
        
        # 根据模式决定是否重启组件
        case "$TLS_MODE" in
            "init")
                echo "初始化模式：跳过组件重启"
                ;;
            "rotate"|"force")
                echo "轮换/强制模式：重启相关组件"
                restart_components "$combo" || true
                ;;
        esac
        
        echo "组合 $combo 处理完成"
        echo "================================"
        echo ""
    done
    
    echo "所有组合部署完成！"
}

# 主函数
main() {
    # 检查是否在正确的目录
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "ERROR: 请在cert-secret-management目录下运行此脚本"
        exit 1
    fi
    
    # 执行部署
    deploy_all_combinations
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
