#!/bin/bash

# 统一部署模板脚本
# 专注于提供基础设施服务：Kubernetes 连接管理和镜像检查
# 移除部署执行逻辑、路径计算和模板变量处理

set -euo pipefail

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 使用绝对路径指向正确的配置文件
CONFIG_FILE="${UNIFIED_CONFIG_FILE:-$SCRIPT_DIR/k8s-admin.conf}"
STATUS_FILE="$SCRIPT_DIR/.k8s-status"
PID_FILE="$SCRIPT_DIR/.k8s-tunnel.pid"

# 清理函数（保留原始退出码，避免子脚本“失败却返回成功”）
cleanup() {
    local exit_code=$?
    # 检查是否禁用自动清理
    if [[ "${DISABLE_AUTO_CLEANUP:-false}" == "true" ]]; then
        log_info "跳过自动清理（由主脚本负责）"
        return "$exit_code"
    fi

    cleanup_k8s_connection
    exit "$exit_code"
}

# 设置信号处理
trap cleanup EXIT INT TERM

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ── 端口工具 ──────────────────────────────────────────────────────────────────
# 检测本地端口是否已在监听（比 netstat 更快，无外部依赖）
_port_is_listening() {
  (echo >/dev/tcp/127.0.0.1/"$1") 2>/dev/null
}

# 等待本地端口开始监听（替代固定 sleep）
_wait_for_port() {
  local port="$1" timeout="${2:-20}"
  local i=0
  while [[ $i -lt $timeout ]]; do
    if _port_is_listening "$port"; then return 0; fi
    sleep 1; i=$((i + 1))
  done
  return 1
}

# 释放本地端口：杀掉占用进程，等待端口真正空闲
_release_local_port() {
  local port="$1" max_wait="${2:-5}"
  pkill -f "ssh.*[: ]${port}:127\.0\.0\.1:" >/dev/null 2>&1 || true
  pkill -f "ssh.*[: ]${port}:[^:]*:[0-9]"   >/dev/null 2>&1 || true
  pkill -f "ssh.*-L ?${port}:"               >/dev/null 2>&1 || true
  local waited=0
  while [[ $waited -lt $max_wait ]]; do
    local pids=""
    if command -v lsof >/dev/null 2>&1; then
      pids=$(lsof -ti "TCP:${port}" 2>/dev/null || true)
    elif command -v ss >/dev/null 2>&1; then
      pids=$(ss -tlnp 2>/dev/null | awk -v p=":${port}" '$0~p {match($0,/pid=([0-9]+)/,a); if(a[1]) print a[1]}' || true)
    fi
    [[ -z "$pids" ]] && break
    echo "$pids" | xargs kill -9 2>/dev/null || true
    sleep 1; waited=$((waited + 1))
  done
}

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

# ========================================
# Harbor 就绪检查（组件通用）
# ========================================

wait_for_harbor_if_needed() {
    # 允许通过环境变量显式跳过（例如离线调试时只做本地 kind load）
    if [[ "${SKIP_HARBOR_WAIT:-false}" == "true" ]]; then
        return 0
    fi

    # 只在当前 shell 进程内检查一次，避免多个组件重复等待
    if [[ -n "${HARBOR_READY_CHECKED:-}" ]]; then
        return 0
    fi

    local host="${HARBOR_HOST:-harbor.sunmoonai.com}"
    local port="${HARBOR_PORT:-30443}"
    local timeout="${HARBOR_WAIT_TIMEOUT:-300}" # 最长等待秒数，默认 5 分钟
    local interval=5
    local start
    start=$(date +%s)

    log_info "[harbor] 等待 Harbor 就绪 (${host}:${port}，最长 ${timeout}s)..."

    while true; do
        # 不带凭证访问 /v2/，能返回 JSON（401/200）即认为 Harbor 已就绪
        if curl -sk --noproxy '*' "https://${host}:${port}/v2/" | grep -q '"errors"' ; then
            log_info "[harbor] Harbor /v2/ 已响应"
            export HARBOR_READY_CHECKED="1"
            return 0
        fi
        local now
        now=$(date +%s)
        if (( now - start >= timeout )); then
            log_warn "[harbor] Harbor 在 ${timeout}s 内未就绪，后续镜像推送可能失败（可稍后单独重试 push）"
            export HARBOR_READY_CHECKED="1"
            return 1
        fi
        sleep "${interval}"
    done
}

# ========================================
# Traefik Service 端口获取函数
# ========================================

# 从 Traefik Service 中获取指定 entryPoint 的 NodePort
# 参数: entry_point_name (例如: mongodb, redis, postgresql)
# 返回: NodePort 端口号，如果获取失败则返回空字符串
get_traefik_nodeport() {
    local entry_point="$1"
    local traefik_namespace="${TRAEFIK_NAMESPACE:-ingress-platform-dev}"
    local traefik_service="${TRAEFIK_SERVICE:-traefik-sunmoonai}"
    
    # 从 Traefik Service 中查找对应 entryPoint 的 NodePort
    # Service 的端口名称格式通常是: tcp-{entrypoint}-{port}
    # 例如: tcp-mongodb-27017 -> NodePort: 30445
    local nodeport
    nodeport=$(kubectl get svc -n "$traefik_namespace" "$traefik_service" -o jsonpath="{.spec.ports[?(@.name==\"tcp-${entry_point}-*\")].nodePort}" 2>/dev/null | head -1)
    
    # 如果上面的方法失败，尝试从所有 TCP 端口中查找
    if [[ -z "$nodeport" ]]; then
        # 获取所有 TCP 端口的名称和 NodePort
        local port_info
        port_info=$(kubectl get svc -n "$traefik_namespace" "$traefik_service" -o jsonpath='{.spec.ports[?(@.protocol=="TCP")]}' 2>/dev/null)
        
        # 尝试匹配 entryPoint 名称
        if echo "$port_info" | grep -q "$entry_point"; then
            # 使用更通用的方法：查找包含 entryPoint 名称的端口
            nodeport=$(kubectl get svc -n "$traefik_namespace" "$traefik_service" -o jsonpath="{.spec.ports[?(@.name=~\"tcp-${entry_point}.*\")].nodePort}" 2>/dev/null | head -1)
        fi
    fi
    
    echo "$nodeport"
}

# 获取 MongoDB 外部端口（从 Traefik Service 中动态获取）
get_mongodb_external_port() {
    local port
    port=$(get_traefik_nodeport "mongodb")
    if [[ -n "$port" ]]; then
        echo "$port"
    else
        # 如果无法获取，返回默认值（从 Traefik dev-values.yaml 中读取）
        echo "30445"
    fi
}

# 获取 Redis 外部端口（从 Traefik Service 中动态获取）
get_redis_external_port() {
    local port
    port=$(get_traefik_nodeport "redis")
    if [[ -n "$port" ]]; then
        echo "$port"
    else
        # 如果无法获取，返回默认值（从 Traefik dev-values.yaml 中读取）
        echo "30446"
    fi
}

# 获取 PostgreSQL 外部端口（从 Traefik Service 中动态获取）
get_postgresql_external_port() {
    local port
    port=$(get_traefik_nodeport "postgresql")
    if [[ -n "$port" ]]; then
        echo "$port"
    else
        # 如果无法获取，返回默认值（从 Traefik dev-values.yaml 中读取）
        echo "30444"
    fi
}

# 获取 Neo4j 外部端口（从 Traefik Service 中动态获取）
get_neo4j_external_port() {
    local port
    port=$(get_traefik_nodeport "neo4j")
    if [[ -n "$port" ]]; then
        echo "$port"
    else
        # 如果无法获取，返回默认值（从 Traefik dev-values.yaml 中读取）
        echo "30099"
    fi
}

# 从 Kubernetes Service 中获取指定服务的端口
# 参数: service_name, namespace (可选，默认: data-platform-dev)
# 返回: Service 的端口号，如果获取失败则返回空字符串
get_service_port() {
    local service_name="$1"
    local namespace="${2:-data-platform-dev}"
    
    # 从 Service 中获取第一个端口的 port 字段
    local port
    port=$(kubectl get svc -n "$namespace" "$service_name" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
    
    echo "$port"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

# ========================================
# Kubernetes 连接管理函数
# ========================================

# 检查 kubectl 是否可用
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl 未安装或不在 PATH 中"
        return 1
    fi
    return 0
}

# 检查 helm 是否可用
check_helm() {
    if ! command -v helm &> /dev/null; then
        log_error "helm 未安装或不在 PATH 中"
        echo "安装指引:"
        echo "  - 官方安装文档: https://helm.sh/docs/intro/install/"
        echo "  - 快速安装: curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
        return 1
    fi
    return 0
}

# 初始化环境
initialize_environment() {
    # 确保 .kube 目录存在
    local kube_dir="$HOME/.kube"
    if [[ ! -d "$kube_dir" ]]; then
        log_info "📁 创建 .kube 目录: $kube_dir"
        mkdir -p "$kube_dir"
        log_success "✅ .kube 目录已创建"
    fi
    
    # 检查 kubectl 是否安装
    check_kubectl
}

# 读取配置文件
read_k8s_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "配置文件不存在: $CONFIG_FILE"
        return 1
    fi
    
    # 读取全局配置（使用精确匹配避免跨段读取）
    GLOBAL_DEFAULT_MODE=$(sed -n '/^\[GLOBAL\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^default_mode=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    GLOBAL_AUTO_STOP=$(sed -n '/^\[GLOBAL\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^auto_stop=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    GLOBAL_TIMEOUT=$(sed -n '/^\[GLOBAL\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^timeout=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    GLOBAL_DEFAULT_CLUSTER=$(sed -n '/^\[GLOBAL\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^default_cluster=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    
    # 确定使用的集群（优先级：环境变量 > 配置文件默认值）
    local cluster_name="${CLUSTER:-${GLOBAL_DEFAULT_CLUSTER:-C1}}"
    # 规范化：纯数字视为 C 编号，如 2 -> C2
    if [[ "$cluster_name" =~ ^[0-9]+$ ]]; then
        cluster_name="C${cluster_name}"
    fi
    cluster_name=$(echo "$cluster_name" | tr '[:lower:]' '[:upper:]')
    
    local cluster_name_upper="$cluster_name"
    # Kind 模式：目标集群为 KIND 时，读 [KIND] 段并返回
    if [[ "$cluster_name_upper" == "KIND" ]]; then
        log_info "使用 Kind 集群配置"
        KIND_CLUSTER_NAME=$(sed -n '/^\[KIND\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^cluster_name=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        KIND_KUBECONFIG=$(sed -n '/^\[KIND\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^kubeconfig=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-kind}"
        KIND_KUBECONFIG="${KIND_KUBECONFIG:-$HOME/.kube/kind-config}"
        KIND_KUBECONFIG="${KIND_KUBECONFIG/#\~/$HOME}"
        KIND_KUBECONFIG=$(eval echo "$KIND_KUBECONFIG")
        K8S_TARGET_MODE=kind
        log_info "Kind 集群名: $KIND_CLUSTER_NAME, kubeconfig: $KIND_KUBECONFIG"
        return 0
    fi
    
    # 验证集群名称格式：必须是 C{数字} 格式（如 C1, C2, C3, C10 等）
    # 支持不连续的集群编号（如只有 C1 和 C3，没有 C2）
    if [[ ! "$cluster_name" =~ ^C[0-9]+$ ]]; then
        log_error "无效的集群名称: $cluster_name (格式必须为 C{数字}，如 C1, C2, C3 等；或使用 CLUSTER=KIND / default_cluster=KIND 连接 Kind)"
        return 1
    fi
    
    log_info "使用集群配置: $cluster_name"
    
    # 根据集群名称确定配置段（为 grep 和 sed 分别准备版本）
    local bastion_section_literal="[${cluster_name}_BASTION]"
    local direct_section_literal="[${cluster_name}_DIRECT]"
    local bastion_section="\\[${cluster_name}_BASTION\\]"
    local direct_section="\\[${cluster_name}_DIRECT\\]"
    
    # 检查集群特定配置是否存在，如果不存在则使用默认配置段
    local use_default=false
    # 使用固定字符串匹配，避免 [] 被当作字符类
    if ! grep -Fq "${bastion_section_literal}" "$CONFIG_FILE"; then
        log_warn "未找到 ${bastion_section_literal}，使用默认 [BASTION] 配置"
        use_default=true
    fi
    
    # 展开路径中的 ~ 和环境变量
    expand_path() {
        local path="$1"
        path="${path/#\~/$HOME}"
        path=$(eval echo "$path")
        echo "$path"
    }
    
    # 仅取第一行，防止值中包含换行导致显示异常
    first_line() {
        local v="$1"
        # 删除可能的回车并截断到第一行
        v=${v//$'\r'/}
        printf '%s' "${v%%$'\n'*}"
    }
    
    # 读取跳板机模式配置（使用精确匹配避免跨段读取）
    if [[ "$use_default" == "true" ]]; then
        BASTION_HOST=$(sed -n '/^\[BASTION\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^host=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        BASTION_USER=$(sed -n '/^\[BASTION\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^user=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        BASTION_SECRET=$(sed -n '/^\[BASTION\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^secret=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        BASTION_PASS=$(sed -n '/^\[BASTION\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^pass=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        BASTION_SUDO_PASS=$(sed -n '/^\[BASTION\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^sudo_pass=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        BASTION_API_SERVER=$(sed -n '/^\[BASTION\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^api_server=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        BASTION_API_USER=$(sed -n '/^\[BASTION\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^api_user=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        BASTION_API_PORT=$(sed -n '/^\[BASTION\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^api_port=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        BASTION_LOCAL_PORT=$(sed -n '/^\[BASTION\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^local_port=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        BASTION_KUBECONFIG=$(sed -n '/^\[BASTION\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^kubeconfig=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        BASTION_BIND_ALIAS=$(sed -n '/^\[BASTION\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^bind_alias=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    else
        BASTION_HOST=$(sed -n "/^${bastion_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^host=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        BASTION_USER=$(sed -n "/^${bastion_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^user=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        BASTION_SECRET=$(sed -n "/^${bastion_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^secret=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        BASTION_PASS=$(sed -n "/^${bastion_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^pass=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        BASTION_SUDO_PASS=$(sed -n "/^${bastion_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^sudo_pass=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        BASTION_API_SERVER=$(sed -n "/^${bastion_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^api_server=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        BASTION_API_USER=$(sed -n "/^${bastion_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^api_user=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        BASTION_API_PORT=$(sed -n "/^${bastion_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^api_port=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        BASTION_LOCAL_PORT=$(sed -n "/^${bastion_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^local_port=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        BASTION_KUBECONFIG=$(sed -n "/^${bastion_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^kubeconfig=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        BASTION_BIND_ALIAS=$(sed -n "/^${bastion_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^bind_alias=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    fi
    
    # 规范化为单行值
    BASTION_HOST=$(first_line "$BASTION_HOST")
    BASTION_USER=$(first_line "$BASTION_USER")
    BASTION_SECRET=$(first_line "$BASTION_SECRET")
    BASTION_PASS=$(first_line "$BASTION_PASS")
    BASTION_SUDO_PASS=$(first_line "$BASTION_SUDO_PASS")
    BASTION_API_SERVER=$(first_line "$BASTION_API_SERVER")
    BASTION_API_USER=$(first_line "$BASTION_API_USER")
    BASTION_API_PORT=$(first_line "$BASTION_API_PORT")
    BASTION_LOCAL_PORT=$(first_line "$BASTION_LOCAL_PORT")
    BASTION_KUBECONFIG=$(first_line "$BASTION_KUBECONFIG")
    BASTION_BIND_ALIAS=$(first_line "$BASTION_BIND_ALIAS")
    
    # 读取直接访问模式配置（使用精确匹配避免跨段读取）
    if [[ "$use_default" == "true" ]]; then
        DIRECT_HOST=$(sed -n '/^\[DIRECT\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^host=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        DIRECT_USER=$(sed -n '/^\[DIRECT\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^user=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        DIRECT_SECRET=$(sed -n '/^\[DIRECT\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^secret=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        DIRECT_PASS=$(sed -n '/^\[DIRECT\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^pass=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        DIRECT_SUDO_PASS=$(sed -n '/^\[DIRECT\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^sudo_pass=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        DIRECT_LOCAL_PORT=$(sed -n '/^\[DIRECT\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^local_port=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        DIRECT_REMOTE_API_HOST=$(sed -n '/^\[DIRECT\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^remote_api_host=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        DIRECT_REMOTE_API_PORT=$(sed -n '/^\[DIRECT\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^remote_api_port=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        DIRECT_KUBECONFIG=$(sed -n '/^\[DIRECT\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^kubeconfig=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        DIRECT_BIND_ALIAS=$(sed -n '/^\[DIRECT\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^bind_alias=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    else
        DIRECT_HOST=$(sed -n "/^${direct_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^host=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        DIRECT_USER=$(sed -n "/^${direct_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^user=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        DIRECT_SECRET=$(sed -n "/^${direct_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^secret=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        DIRECT_PASS=$(sed -n "/^${direct_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^pass=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        DIRECT_SUDO_PASS=$(sed -n "/^${direct_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^sudo_pass=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        DIRECT_LOCAL_PORT=$(sed -n "/^${direct_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^local_port=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        DIRECT_REMOTE_API_HOST=$(sed -n "/^${direct_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^remote_api_host=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        DIRECT_REMOTE_API_PORT=$(sed -n "/^${direct_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^remote_api_port=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        DIRECT_KUBECONFIG=$(sed -n "/^${direct_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^kubeconfig=" | head -1 | cut -d'=' -f2 | tr -d ' ')
        DIRECT_BIND_ALIAS=$(sed -n "/^${direct_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^bind_alias=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    fi
    
    # 规范化为单行值
    DIRECT_HOST=$(first_line "$DIRECT_HOST")
    DIRECT_USER=$(first_line "$DIRECT_USER")
    DIRECT_SECRET=$(first_line "$DIRECT_SECRET")
    DIRECT_PASS=$(first_line "$DIRECT_PASS")
    DIRECT_SUDO_PASS=$(first_line "$DIRECT_SUDO_PASS")
    DIRECT_LOCAL_PORT=$(first_line "$DIRECT_LOCAL_PORT")
    DIRECT_REMOTE_API_HOST=$(first_line "$DIRECT_REMOTE_API_HOST")
    DIRECT_REMOTE_API_PORT=$(first_line "$DIRECT_REMOTE_API_PORT")
    DIRECT_KUBECONFIG=$(first_line "$DIRECT_KUBECONFIG")
    DIRECT_BIND_ALIAS=$(first_line "$DIRECT_BIND_ALIAS")
    
    # 确保变量已定义，防止未定义变量错误
    DIRECT_BIND_ALIAS="${DIRECT_BIND_ALIAS:-false}"
    
    # 展开包含 ~ 的路径
    BASTION_KUBECONFIG=$(expand_path "$BASTION_KUBECONFIG")
    DIRECT_KUBECONFIG=$(expand_path "$DIRECT_KUBECONFIG")
    
    log_info "配置文件加载成功"
    return 0
}

# 保存连接状态（按 k8s-connection-manager.sh 的字段统一）
save_k8s_status() {
    local mode="$1"
    local _timestamp="$2"   # 参数位占位，当前不写入文件
    local _local_port="$3"  # 参数位占位，当前不写入文件
    local pid="$4"

    # 统一采用 CURRENT_* 字段，完全对齐 k8s-connection-manager.sh
    CURRENT_MODE="$mode"
    # CURRENT_KUBECONFIG 由上层在建立连接后设置，这里不修改
    TUNNEL_PID="$pid"

    cat > "$STATUS_FILE" << EOF
CURRENT_MODE=$CURRENT_MODE
CURRENT_KUBECONFIG=$CURRENT_KUBECONFIG
TUNNEL_PID=$TUNNEL_PID
EOF
    log_info "连接状态已保存: CURRENT_MODE=$CURRENT_MODE, TUNNEL_PID=$TUNNEL_PID"
}

# 加载连接状态（直接使用 CURRENT_* 字段）
load_k8s_status() {
    # 初始化变量（只有在未定义时才初始化）
    CURRENT_MODE=${CURRENT_MODE:-""}
    CURRENT_KUBECONFIG=${CURRENT_KUBECONFIG:-""}
    TUNNEL_PID=${TUNNEL_PID:-""}
    LOCAL_PORT=${LOCAL_PORT:-""}
    
    if [[ -f "$STATUS_FILE" ]]; then
        source "$STATUS_FILE"

        # 基本校验，防止读取到空/损坏状态而被误判为“已连接”
        if [[ -z "$CURRENT_MODE" || -z "$CURRENT_KUBECONFIG" ]]; then
            log_warn "连接状态文件无效（CURRENT_MODE 或 CURRENT_KUBECONFIG 为空），将忽略并重新建立连接"
            clear_k8s_status
            return 1
        fi
        log_info "连接状态已加载: CURRENT_MODE=$CURRENT_MODE, TUNNEL_PID=$TUNNEL_PID"
        return 0
    fi
    return 1
}

# 清理连接状态
clear_k8s_status() {
    if [[ -f "$STATUS_FILE" ]]; then
        rm -f "$STATUS_FILE"
        log_info "连接状态已清理"
    fi
}

# 检查连接状态
check_k8s_connection_status() {
    if load_k8s_status; then
        # Kind 模式：无隧道，仅校验 kubeconfig 与 kubectl 可用
        if [[ "$CURRENT_MODE" == "kind" ]]; then
            if [[ -n "$CURRENT_KUBECONFIG" ]] && [[ -f "$CURRENT_KUBECONFIG" ]]; then
                if KUBECONFIG="$CURRENT_KUBECONFIG" kubectl get nodes --request-timeout=10s >/dev/null 2>&1; then
                    log_info "连接状态正常 (Kind)"
                    return 0
                fi
            fi
            log_warn "Kind 连接状态异常，需要重新建立连接"
            clear_k8s_status
            return 1
        fi
        # 远程模式：检查进程是否还在运行
        if [[ -n "$TUNNEL_PID" ]] && kill -0 "$TUNNEL_PID" 2>/dev/null; then
            # 如有 LOCAL_PORT，则顺便校验端口监听；否则仅依赖 kubectl 检测
            if [[ -n "$LOCAL_PORT" ]]; then
                if ! _port_is_listening "$LOCAL_PORT"; then
                    log_warn "连接状态异常，端口 $LOCAL_PORT 未在监听"
                    clear_k8s_status
                    return 1
                fi
            fi

            # 测试 kubectl 连接（带重试）
            local retry_count=0
            local max_retries=3
            
            while [[ $retry_count -lt $max_retries ]]; do
                if KUBECONFIG="$CURRENT_KUBECONFIG" kubectl get nodes --request-timeout=10s >/dev/null 2>&1; then
                    log_info "连接状态正常: TUNNEL_PID=$TUNNEL_PID${LOCAL_PORT:+, PORT=$LOCAL_PORT}"
                    return 0  # 连接正常
                fi

                retry_count=$((retry_count+1))  # 使用显式赋值，避免 ((retry_count++)) 在某些情况下导致的问题
                if [[ $retry_count -lt $max_retries ]]; then
                    sleep 1  # 等待1秒后重试
                fi
            done
            
            log_warn "连接状态异常，kubectl 连接失败"
            return 1
        fi
        log_warn "连接状态异常，需要重新建立连接"
        clear_k8s_status
    fi
    return 1
}

# 自动重连
auto_reconnect() {
    log_info "检测到连接断开，正在自动重连..."

    # 清理旧的连接（杀进程并等端口释放）
    if [[ -n "${TUNNEL_PID:-}" ]]; then
        kill "$TUNNEL_PID" 2>/dev/null || true
        wait "$TUNNEL_PID" 2>/dev/null || true
    fi
    if [[ -n "${LOCAL_PORT:-}" ]]; then
        _release_local_port "$LOCAL_PORT"
    fi

    # 重新启动连接
    if start_k8s_connection; then
        # 检查重连是否成功
        if check_k8s_connection_status; then
            log_success "自动重连成功"
            return 0
        else
            log_error "自动重连失败"
            return 1
        fi
    else
        log_error "自动重连失败"
        return 1
    fi
}

# 建立 Kubernetes 连接
start_k8s_connection() {
    # 先读取配置文件
    if ! read_k8s_config; then
        return 1
    fi
    
    # Kind 模式：直接走 Kind 建连，不依赖 bastion/direct
    if [[ "${K8S_TARGET_MODE:-}" == "kind" ]]; then
        start_kind_connection
        return $?
    fi
    
    local mode="${1:-$GLOBAL_DEFAULT_MODE}"
    
    log_info "开始建立 Kubernetes 连接，模式: $mode"
    
    # 检查 kubectl
    if ! check_kubectl; then
        return 1
    fi
    
    case "$mode" in
        "bastion")
            start_bastion_connection
            ;;
        "direct")
            start_direct_connection
            ;;
        "local")
            setup_local_connection
            ;;
        *)
            log_error "不支持的连接模式: $mode"
            return 1
            ;;
    esac
}

# Kind 模式连接：将 kind kubeconfig 写入配置路径并设置 KUBECONFIG
# 注意：如果目标集群为 KIND，则必须存在 kind 命令且 Kind 集群可用；不做“隐式回退”，避免破坏集群选择优先级
start_kind_connection() {
    log_info "使用 Kind 模式连接..."
    
    if ! command -v kind &>/dev/null; then
        log_error "未找到 kind 命令，但当前选择的集群为 KIND。请安装 kind，或通过 --cluster/-c/CLUSTER 指定目标集群为 C1/C2 等"
        return 1
    fi
    
    if ! kind get clusters 2>/dev/null | grep -q "^${KIND_CLUSTER_NAME}$"; then
        log_error "Kind 集群 ${KIND_CLUSTER_NAME} 不存在，请先运行: kind create cluster --name ${KIND_CLUSTER_NAME}"
        return 1
    fi
    
    local kubeconfig_dir
    kubeconfig_dir=$(dirname "$KIND_KUBECONFIG")
    if [[ ! -d "$kubeconfig_dir" ]]; then
        mkdir -p "$kubeconfig_dir"
        log_info "已创建 kubeconfig 目录: $kubeconfig_dir"
    fi
    
    kind get kubeconfig --name "$KIND_CLUSTER_NAME" > "$KIND_KUBECONFIG" || {
        log_error "无法获取 Kind 集群 ${KIND_CLUSTER_NAME} 的 kubeconfig"
        return 1
    }
    
    CURRENT_KUBECONFIG="$KIND_KUBECONFIG"
    export KUBECONFIG="$KIND_KUBECONFIG"
    log_info "已设置环境变量: export KUBECONFIG=$KIND_KUBECONFIG"
    
    save_k8s_status "kind" "$(date +%s)" "" ""
    log_success "Kind 连接建立成功"
    return 0
}

# 跳板机模式连接
start_bastion_connection() {
    log_info "使用跳板机模式连接..."
    
    # 检查必要的配置
    if [[ -z "$BASTION_HOST" ]] || [[ -z "$BASTION_USER" ]]; then
        log_error "跳板机配置不完整"
        return 1
    fi
    
    # 建立 SSH 隧道
    local ssh_cmd="ssh -f -N -L $BASTION_LOCAL_PORT:$BASTION_API_SERVER:$BASTION_API_PORT"
    
    if [[ -n "$BASTION_SECRET" ]]; then
        ssh_cmd="$ssh_cmd -i $BASTION_SECRET"
    fi
    
    ssh_cmd="$ssh_cmd $BASTION_USER@$BASTION_HOST"
    
    log_info "执行命令: $ssh_cmd"
    
    if eval "$ssh_cmd"; then
        local pid=$(pgrep -f "ssh.*$BASTION_LOCAL_PORT:$BASTION_API_SERVER")
        
        # 确保本地 kubeconfig 目录存在
        local kubeconfig_dir
        kubeconfig_dir=$(dirname "$BASTION_KUBECONFIG")
        if [[ ! -d "$kubeconfig_dir" ]]; then
            log_info "创建 kubeconfig 目录: $kubeconfig_dir"
            mkdir -p "$kubeconfig_dir"
            log_success "✅ kubeconfig 目录已创建"
        fi
        
        # 设置当前 kubeconfig
        CURRENT_KUBECONFIG="$BASTION_KUBECONFIG"
        
        # 立即设置环境变量，使 kubectl 使用远程集群配置
        export KUBECONFIG="$BASTION_KUBECONFIG"
        log_info "已设置环境变量: export KUBECONFIG=$BASTION_KUBECONFIG"
        
        save_k8s_status "bastion" "$(date +%s)" "$BASTION_LOCAL_PORT" "$pid"
        log_success "跳板机连接建立成功"
        return 0
    else
        log_error "跳板机连接建立失败"
        return 1
    fi
}

# 直接访问模式连接
start_direct_connection() {
    log_info "使用直接访问模式连接..."
    
    # 检查必要的配置
    if [[ -z "$DIRECT_HOST" ]] || [[ -z "$DIRECT_USER" ]]; then
        log_error "直接访问配置不完整"
        return 1
    fi
    
    # 解析主机和端口
    local direct_host_ip
    local direct_host_port
    direct_host_ip=$(echo "$DIRECT_HOST" | cut -d':' -f1)
    direct_host_port=$(echo "$DIRECT_HOST" | cut -d':' -f2)
    direct_host_port=${direct_host_port:-22}
    
    # 构建 SSH 命令参数
    local ssh_args=""
    if [[ -n "$DIRECT_SECRET" ]]; then
        ssh_args="-i $DIRECT_SECRET"
    fi
    if [[ -n "$DIRECT_PASS" ]]; then
        ssh_args="$ssh_args -o PasswordAuthentication=yes"
    fi
    
    # 启动隧道（先等端口完全释放，再绑定）
    _release_local_port "$DIRECT_LOCAL_PORT"
    log_info "建立隧道: 本地:$DIRECT_LOCAL_PORT → $DIRECT_REMOTE_API_HOST:$DIRECT_REMOTE_API_PORT"
    # shellcheck disable=SC2086
    ssh $ssh_args \
        -o ConnectTimeout="$GLOBAL_TIMEOUT" \
        -o ServerAliveInterval=10 \
        -o ServerAliveCountMax=6 \
        -o TCPKeepAlive=yes \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -L "$DIRECT_LOCAL_PORT:$DIRECT_REMOTE_API_HOST:$DIRECT_REMOTE_API_PORT" \
        "$DIRECT_USER@$direct_host_ip" -p "$direct_host_port" -N &
    local tunnel_pid=$!

    # 主动等待端口就绪（替代固定 sleep 2）
    if ! _wait_for_port "$DIRECT_LOCAL_PORT" 20; then
        log_error "隧道启动失败（端口 $DIRECT_LOCAL_PORT 未监听）"
        kill "$tunnel_pid" 2>/dev/null || true
        return 1
    fi
    if ! kill -0 "$tunnel_pid" 2>/dev/null; then
        log_error "隧道启动失败"
        return 1
    fi

    log_info "隧道已启动 (PID: $tunnel_pid)"
    
    # 获取 kubeconfig
    log_info "获取远程 kubeconfig..."
    local remote_tmp="/tmp/admin.conf.$$"
    local ssh_base=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout="$GLOBAL_TIMEOUT" -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o TCPKeepAlive=yes -p "$direct_host_port")
    local scp_base=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout="$GLOBAL_TIMEOUT" -P "$direct_host_port")
    
    # 构建 SSH 和 SCP 命令
    local ssh_cmd
    local ssh_cmd_tty
    local scp_cmd
    if [[ -n "$DIRECT_SECRET" ]]; then
        ssh_cmd=(ssh -i "$DIRECT_SECRET" "${ssh_base[@]}" "$DIRECT_USER@$direct_host_ip")
        ssh_cmd_tty=(ssh -t -i "$DIRECT_SECRET" "${ssh_base[@]}" "$DIRECT_USER@$direct_host_ip")
        scp_cmd=(scp -i "$DIRECT_SECRET" "${scp_base[@]}")
    else
        ssh_cmd=(ssh "${ssh_base[@]}" "$DIRECT_USER@$direct_host_ip")
        ssh_cmd_tty=(ssh -t "${ssh_base[@]}" "$DIRECT_USER@$direct_host_ip")
        scp_cmd=(scp "${scp_base[@]}")
    fi
    
    # 首先测试 SSH 连接是否正常
    log_info "测试 SSH 连接..."
    if ! "${ssh_cmd[@]}" "echo 'SSH connection test successful'" >/dev/null 2>&1; then
        log_error "SSH 连接测试失败，请检查网络连接和认证配置"
        kill "$tunnel_pid" 2>/dev/null || true
        return 1
    fi
    
    # 检查原始文件是否存在（使用 sudo，因为文件通常需要 root 权限）
    log_info "检查远程 kubeconfig 文件..."
    if ! "${ssh_cmd[@]}" "sudo test -f /etc/kubernetes/admin.conf" 2>/dev/null; then
        log_error "/etc/kubernetes/admin.conf 不存在或无法访问"
        log_error "提示：请确保远程服务器上已安装 Kubernetes 并初始化了集群"
        kill "$tunnel_pid" 2>/dev/null || true
        return 1
    fi
    
    # 创建可读的临时副本（支持多种方法）
    log_info "准备远程 kubeconfig 副本..."
    local prepare_success=false
    
    # 方法1: 尝试使用 sudo（免密 sudo，不需要 -t）
    log_info "尝试使用 sudo..."
    if "${ssh_cmd[@]}" "sudo cp -f /etc/kubernetes/admin.conf '$remote_tmp' && sudo chmod 0644 '$remote_tmp'" >/dev/null 2>&1; then
        # 检查文件是否成功创建
        sleep 1
        if "${ssh_cmd[@]}" "test -f '$remote_tmp' && test -r '$remote_tmp'" 2>/dev/null; then
            prepare_success=true
        fi
    fi
    
    # 方法2: 如果方法1失败且配置了 sudo 密码，尝试使用密码（需要 -t）
    if [[ "$prepare_success" == "false" && -n "$DIRECT_SUDO_PASS" ]]; then
        log_info "使用 sudo 密码进行认证..."
        if echo "$DIRECT_SUDO_PASS" | "${ssh_cmd_tty[@]}" "sudo -S cp -f /etc/kubernetes/admin.conf '$remote_tmp' && sudo -S chmod 0644 '$remote_tmp'" </dev/null 2>&1 | grep -vE "(Pseudo-terminal|Warning)" >/dev/null 2>&1; then
            sleep 1
            if "${ssh_cmd[@]}" "test -f '$remote_tmp' && test -r '$remote_tmp'" 2>/dev/null; then
                prepare_success=true
            fi
        fi
    fi
    
    # 方法3: 如果 sudo 失败，尝试直接复制（如果文件权限允许）
    if [[ "$prepare_success" == "false" ]]; then
        log_info "尝试直接复制（不使用 sudo）..."
        if "${ssh_cmd[@]}" "cp -f /etc/kubernetes/admin.conf '$remote_tmp' 2>/dev/null && chmod 0644 '$remote_tmp' 2>/dev/null && test -f '$remote_tmp' && test -r '$remote_tmp'" 2>/dev/null; then
            prepare_success=true
        fi
    fi
    
    if [[ "$prepare_success" == "false" ]]; then
        log_error "无法在远程服务器上准备 kubeconfig"
        log_error "提示：请确保配置了免密 sudo，或检查 /etc/kubernetes/admin.conf 的文件权限"
        log_error "提示：可以在远程服务器运行: sudo chmod 644 /etc/kubernetes/admin.conf"
        kill "$tunnel_pid" 2>/dev/null || true
        return 1
    fi
    
    # 验证远程文件存在
    if ! "${ssh_cmd[@]}" "test -s '$remote_tmp'"; then
        log_error "远程 kubeconfig 文件不存在或为空"
        kill "$tunnel_pid" 2>/dev/null || true
        return 1
    fi
    
    # 确保本地 kubeconfig 目录存在
    local kubeconfig_dir
    kubeconfig_dir=$(dirname "$DIRECT_KUBECONFIG")
    if [[ ! -d "$kubeconfig_dir" ]]; then
        log_info "创建 kubeconfig 目录: $kubeconfig_dir"
        mkdir -p "$kubeconfig_dir"
        log_success "✅ kubeconfig 目录已创建"
    fi
    
    # 下载 kubeconfig
    if ! "${scp_cmd[@]}" "$DIRECT_USER@$direct_host_ip:$remote_tmp" "$DIRECT_KUBECONFIG"; then
        log_error "无法下载 kubeconfig"
        kill "$tunnel_pid" 2>/dev/null || true
        return 1
    fi
    
    # 清理远程临时文件
    "${ssh_cmd[@]}" "sudo rm -f '$remote_tmp'" >/dev/null 2>&1 || true
    
    # 读取从远端获取的 kubeconfig 中原始 server，决定是否走别名严格 TLS
    local original_server_url
    original_server_url=$(grep -m1 '^\s*server:' "$DIRECT_KUBECONFIG" | awk '{print $2}')
    local original_host
    local original_port
    original_host=$(echo "$original_server_url" | sed -E 's#https?://([^:/]+).*#\1#')
    original_port=$(echo "$original_server_url" | sed -E 's#https?://[^:/]+:([0-9]+).*#\1#')
    if [[ -z "$original_port" ]]; then original_port=6443; fi

    if [[ "${DIRECT_BIND_ALIAS:-false}" == "true" ]]; then
        # 使用域名别名保持严格 TLS
        log_info "配置域名别名并保持严格 TLS"
        # 重启隧道指向 127.0.0.1（先等端口完全释放）
        if [[ -n "$tunnel_pid" ]] && kill -0 "$tunnel_pid" 2>/dev/null; then
            kill "$tunnel_pid" 2>/dev/null || true
            wait "$tunnel_pid" 2>/dev/null || true
        fi
        _release_local_port "$DIRECT_LOCAL_PORT"
        log_info "建立隧道: 本地:$DIRECT_LOCAL_PORT → 127.0.0.1:$original_port"
        # shellcheck disable=SC2086
        ssh $ssh_args \
            -o ConnectTimeout="$GLOBAL_TIMEOUT" \
            -o ServerAliveInterval=10 \
            -o ServerAliveCountMax=6 \
            -o TCPKeepAlive=yes \
            -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            -L "$DIRECT_LOCAL_PORT:127.0.0.1:$original_port" \
            "$DIRECT_USER@$direct_host_ip" -p "$direct_host_port" -N &
        tunnel_pid=$!
        _wait_for_port "$DIRECT_LOCAL_PORT" 20 || log_warn "等待精确隧道端口超时，继续..."

        # 动态解析证书SAN，选择有效的域名
        local cert_tmp=$(mktemp)
        local valid_domain=""
        
        # 从kubeconfig中提取证书并解析SAN
        if command -v yq >/dev/null 2>&1; then
            # 使用yq提取证书数据
            local cert_data
            cert_data=$(yq e '.clusters[0].cluster["certificate-authority-data"]' "$DIRECT_KUBECONFIG" 2>/dev/null || echo "")
            if [[ -n "$cert_data" ]]; then
                echo "$cert_data" | base64 -d > "$cert_tmp" 2>/dev/null
                valid_domain=$(openssl x509 -in "$cert_tmp" -noout -text 2>/dev/null | grep -oP 'DNS:[^,\s]+' | head -n1 | cut -d: -f2)
            fi
        fi
        
        # 如果yq不可用或解析失败，尝试使用grep直接解析
        if [[ -z "$valid_domain" ]]; then
            valid_domain=$(grep -oP 'certificate-authority-data:\s*\K[^[:space:]]+' "$DIRECT_KUBECONFIG" | head -n1 | base64 -d 2>/dev/null | openssl x509 -noout -text 2>/dev/null | grep -oP 'DNS:[^,\s]+' | head -n1 | cut -d: -f2)
        fi
        
        # 如果还是失败，使用默认域名
        if [[ -z "$valid_domain" ]]; then
            valid_domain="kubernetes"
            log_warn "无法解析证书SAN，使用默认域名: $valid_domain"
        fi
        
        rm -f "$cert_tmp"
        
        # hosts 添加域名别名（带标记）
        if ! grep -q "^127.0.0.1[[:space:]]*$valid_domain[[:space:]]*# added_by_k8s_manager" /etc/hosts 2>/dev/null; then
            echo "127.0.0.1 $valid_domain # added_by_k8s_manager" | sudo tee -a /etc/hosts >/dev/null
            log_info "已添加域名别名: 127.0.0.1 $valid_domain"
        else
            log_info "域名别名已存在: 127.0.0.1 $valid_domain"
        fi
        # 修改 kubeconfig 使用有效域名
        sed -i "s|server: https://.*:6443|server: https://$valid_domain:$DIRECT_LOCAL_PORT|g" "$DIRECT_KUBECONFIG"
        log_info "已配置域名别名严格 TLS 模式"
    else
        # 回环方案：将 server 改为 127.0.0.1:PORT，并添加 insecure，删除证书字段
        log_info "修改 kubeconfig 服务器地址 (回环) ..."
        sed -i "s|server: https://.*:6443|server: https://127.0.0.1:$DIRECT_LOCAL_PORT|g" "$DIRECT_KUBECONFIG"
        sed -i '/certificate-authority-data:/d' "$DIRECT_KUBECONFIG"
        sed -i '/certificate-authority:/d' "$DIRECT_KUBECONFIG"
        sed -i "/server: https:\/\/127.0.0.1:$DIRECT_LOCAL_PORT/a\\    insecure-skip-tls-verify: true" "$DIRECT_KUBECONFIG"
        log_info "已配置回环模式并应用 TLS 设置"
    fi
    
    # 设置当前 kubeconfig
    CURRENT_KUBECONFIG="$DIRECT_KUBECONFIG"
    
    # 立即设置环境变量，使 kubectl 使用远程集群配置
    export KUBECONFIG="$DIRECT_KUBECONFIG"
    log_info "已设置环境变量: export KUBECONFIG=$DIRECT_KUBECONFIG"
    
    save_k8s_status "direct" "$(date +%s)" "$DIRECT_LOCAL_PORT" "$tunnel_pid"
    log_success "直接访问连接建立成功"
    return 0
}

# 本地连接设置
setup_local_connection() {
    log_info "使用本地 Kubernetes 集群..."
    unset KUBECONFIG
    save_k8s_status "local" "$(date +%s)" "0" "0"
    log_success "本地连接设置完成"
    return 0
}

# 静默停止连接
stop_k8s_connection_quiet() {
    # 初始化变量
    CURRENT_MODE=${CURRENT_MODE:-""}
    TUNNEL_PID=${TUNNEL_PID:-""}
    
    # 静默加载状态（不显示日志）
    if [[ -f "$STATUS_FILE" ]]; then
        source "$STATUS_FILE"
    else
        return 0
    fi
    
    case "$CURRENT_MODE" in
        "bastion")
            if [[ -n "$TUNNEL_PID" ]]; then
                kill "$TUNNEL_PID" 2>/dev/null || true
            fi
            ;;
        "direct")
            if [[ -n "$TUNNEL_PID" ]]; then
                log_info "停止 SSH 端口转发，PID: $TUNNEL_PID"
                kill "$TUNNEL_PID" 2>/dev/null || true
            fi
            # 清理域名别名（只删除带标记的条目）
            if [[ "${DIRECT_BIND_ALIAS:-false}" == "true" ]] && [[ -n "${DIRECT_HOST:-}" ]]; then
                local api_ip
                api_ip=$(echo "$DIRECT_HOST" | cut -d':' -f1)
                sudo sed -i "/127.0.0.1 $api_ip # added_by_k8s_manager$/d" /etc/hosts 2>/dev/null || true
                # 同时清理可能添加的域名别名
                sudo sed -i "/# added_by_k8s_manager$/d" /etc/hosts 2>/dev/null || true
            fi
            ;;
        "kind")
            # Kind 无隧道，仅清理状态
            ;;
        "local")
            # 本地模式不需要特殊处理
            ;;
    esac
    clear_k8s_status
}

# 设置 kubectl 环境
setup_kubectl_environment() {
    log_info "设置 kubectl 环境..."
    
    # 检查现有连接状态
    if check_k8s_connection_status; then
        log_info "使用现有连接"
    else
        # 尝试自动重连
        if auto_reconnect; then
            log_info "自动重连成功"
        else
            log_info "建立新连接"
            if ! start_k8s_connection; then
                log_error "无法建立 Kubernetes 连接"
                return 1
            fi
        fi
    fi
    
    # 加载连接状态以获取 CURRENT_MODE 和 CURRENT_KUBECONFIG
    if load_k8s_status; then
        # 设置环境变量
        if [[ -z "$CURRENT_MODE" ]]; then
            log_error "连接状态无效：CURRENT_MODE 为空"
            return 1
        fi
        case "$CURRENT_MODE" in
            "bastion"|"direct"|"kind")
                export KUBECONFIG="$CURRENT_KUBECONFIG"
                log_info "已设置环境变量: export KUBECONFIG=$CURRENT_KUBECONFIG"
                ;;
            "local")
                unset KUBECONFIG
                log_info "已清除 KUBECONFIG 环境变量，使用本地配置"
                ;;
            *)
                log_error "连接状态无效：未知 CURRENT_MODE='$CURRENT_MODE'"
                return 1
        esac
    else
        # 未能加载任何有效状态：
        # - 如果显式指定了远程集群（如 CLUSTER=C1/C2），认为是严重错误，返回非 0 让上层脚本感知
        # - 否则才兜底到本地 kubeconfig
        local cluster_upper="${CLUSTER:-}"
        cluster_upper=$(echo "$cluster_upper" | tr '[:lower:]' '[:upper:]')
        if [[ -n "$cluster_upper" && "$cluster_upper" != "KIND" && "$cluster_upper" != "LOCAL" ]]; then
            log_error "未找到集群 $cluster_upper 的有效连接状态，且无法自动建立连接，请检查远程连接配置/脚本"
            return 1
        fi
        unset KUBECONFIG
        log_info "未找到连接状态，回退为本地 kubeconfig"
    fi
    
    # 连接建立后，环境变量已经设置好了，不需要额外验证
    log_success "Kubernetes 环境设置成功"
    return 0
}

# ========================================
# 集群参数解析（组件通用）
# ========================================
# 目标：把“集群选择”下沉到统一模板，组件脚本不再各自复制解析逻辑。
#
# 支持：
#   - --cluster=C2 / --CLUSTER=c2
#   - --cluster C2 / -c C2 / -c 2
#   - -c2 / -C2
# 输出：
#   - 设置并导出 CLUSTER（统一为大写，数字自动补全为 C{数字}）
#   - 生成 PARSED_ARGS（去掉 cluster 参数后的其余参数，供组件脚本继续解析自身参数）
unified_parse_cluster_arg() {
    local args=("$@")
    PARSED_ARGS=()
    local cluster_value=""
    local i=0

    while [[ $i -lt ${#args[@]} ]]; do
        shopt -s nocasematch
        case "${args[$i]}" in
            --[cC][lL][uU][sS][tT][eE][rR]=*)
                cluster_value="${args[$i]#*=}"
                ;;
            --[cC][lL][uU][sS][tT][eE][rR]|-c|-C)
                if [[ $((i+1)) -lt ${#args[@]} ]]; then
                    cluster_value="${args[$((i+1))]}"
                    i=$((i+1))
                else
                    log_error "❌ --cluster 参数需要指定值（格式：C{数字} 或 -c2、-c 2 等）"
                    exit 1
                fi
                ;;
            -[cC][0-9]*)
                cluster_value="${args[$i]#-[cC]}"
                ;;
            *)
                PARSED_ARGS+=("${args[$i]}")
                ;;
        esac
        shopt -u nocasematch
        i=$((i+1))
    done

    if [[ -n "$cluster_value" ]]; then
        cluster_value=$(echo "$cluster_value" | tr '[:lower:]' '[:upper:]')
        [[ "$cluster_value" =~ ^[0-9]+$ ]] && cluster_value="C${cluster_value}"
        export CLUSTER="$cluster_value"
        log_info "🔧 设置集群环境变量: CLUSTER=$cluster_value"
    fi
}

# 子组件脚本常用别名（与 setup_kubectl_environment 一致，避免“未找到命令”）
setup_connection() {
    setup_kubectl_environment
}

# 清理连接资源
cleanup_k8s_connection() {
    log_info "清理 Kubernetes 连接资源..."
    stop_k8s_connection_quiet
    if [[ -f "$PID_FILE" ]]; then
        rm -f "$PID_FILE"
    fi
}

# ========================================
# Harbor 镜像按需推送（组件通用）
# ========================================
# 按集群模式分流：
#   - Kind：使用 sunmoonai/kind-infrastructure/push-to-harbor/push-images-to-harbor.sh（--img-file 组件清单）
#   - 远程（C1/C2/...）：使用 utils/registry-push-management/loadimage.sh remote-push-from-list（tar 已在远端节点）
# - component_name: 组件名称（用于定位 utils/components-images/<component_name>-images.txt）
push_component_images_to_harbor() {
    local component_name="$1"

    # 在首次推送组件镜像前等待 Harbor 就绪（只检查一次）
    wait_for_harbor_if_needed || true

    local base_dir
    base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    local image_list_file="$base_dir/components-images/${component_name}-images.txt"

    if [[ ! -f "$image_list_file" ]]; then
        log_warn "[images] 找不到组件镜像清单: $image_list_file，跳过 Harbor 镜像推送"
        return 0
    fi

    local image_list_abs="$image_list_file"
    [[ "$image_list_abs" != /* ]] && image_list_abs="$(cd "$(dirname "$image_list_file")" && pwd)/$(basename "$image_list_file")"

    if [[ "${K8S_TARGET_MODE:-}" == "kind" ]]; then
        # Kind：使用 push-to-harbor；先按镜像列表 pull，若有本地 tar 目录则同时 load+push（pull 失败时仍可从 tar 推送）
        local k8s_root; k8s_root="$(cd "$base_dir/.." && pwd)"
        local kind_push_sh="$k8s_root/sunmoonai/kind-infrastructure/push-to-harbor/push-images-to-harbor.sh"
        if [[ ! -f "$kind_push_sh" ]]; then
            log_warn "[images] Kind 模式下 push-images-to-harbor.sh 不存在: $kind_push_sh，跳过 Harbor 镜像推送"
            return 0
        fi
        local kind_push_args=(--img-file "$image_list_abs")
        # Kind 模式下传递集群名，启用 kind load 兜底（push 失败时直接加载到节点）
        local kind_cluster="${KIND_CLUSTER_NAME:-kind}"
        kind_push_args+=(--kind-cluster "$kind_cluster")
        local tar_dir="${COMPONENT_IMAGE_TAR_DIR:-$HOME/packages-to-be-installed/images}"
        if [[ -d "$tar_dir" ]]; then
            kind_push_args+=(--tar-dir "$tar_dir")
            log_info "[images] Kind 集群：使用 push-to-harbor 推送组件镜像（清单 + 本地 tar 目录: $tar_dir，push 失败时 kind load 兜底）"
        else
            log_info "[images] Kind 集群：使用 push-to-harbor 按需推送组件镜像到 Harbor（component=${component_name}，push 失败时 kind load 兜底）"
        fi
        if ! "$kind_push_sh" "${kind_push_args[@]}"; then
            log_warn "[images] 组件 ${component_name} 镜像推送返回非零状态，请检查 push-to-harbor 或稍后单独执行"
        else
            log_info "[images] 组件 ${component_name} 相关镜像已确保存在于 Harbor（或已按需推送）"
        fi
        return 0
    fi

    # 远程集群：使用 registry-push-management（SSH + nerdctl）
    local loadimage_sh="$base_dir/registry-push-management/loadimage.sh"
    if [[ ! -f "$loadimage_sh" ]]; then
        log_warn "[images] registry-push-management 工具不存在: $loadimage_sh，跳过 Harbor 镜像推送"
        return 0
    fi

    if [[ -z "${_REG_PUSH_CLEANUP_WARNED:-}" ]]; then
        local cleanup_flag="${CLEANUP_REMOTE_TAR_AFTER_PUSH:-}"
        if [[ -z "$cleanup_flag" ]]; then
            local loadimage_conf="$base_dir/registry-push-management/loadimage.conf"
            if [[ -f "$loadimage_conf" ]]; then
                # shellcheck disable=SC1090
                source "$loadimage_conf"
                cleanup_flag="${CLEANUP_REMOTE_TAR_AFTER_PUSH:-}"
            fi
        fi
        if [[ "${cleanup_flag:-true}" == "true" ]]; then
            log_warn "[images] 提示：CLEANUP_REMOTE_TAR_AFTER_PUSH=true，推送后会删除远程 tar。上述风险仅针对 Step11 会校验的镜像（如 bitnami/redis、bitnami/postgresql）；其它组件镜像的 tar 删除后不会在 Step11 verify 中校验，故不影响 verify 结果。"
        fi
        _REG_PUSH_CLEANUP_WARNED=1
    fi
    log_info "[images] 使用 registry-push-management 按需推送组件镜像到 Harbor（component=${component_name}）"

    local cluster_args=()
    if [[ -n "${CLUSTER:-}" ]]; then
        cluster_args+=(--cluster "$CLUSTER")
    fi

    if ! "$loadimage_sh" "${cluster_args[@]}" remote-push-from-list "$image_list_file"; then
        log_warn "[images] 组件 ${component_name} 镜像推送工具返回非零状态，请稍后在 utils/registry-push-management 中单独检查"
    else
        log_info "[images] 组件 ${component_name} 相关镜像已确保存在于 Harbor（或已按需推送）"
    fi

    return 0
}

# ========================================
# 使用说明和帮助信息
# ========================================

# 显示使用说明
show_usage() {
    cat << EOF
统一部署模板脚本

专注于提供基础设施服务：
- Kubernetes 连接管理
- 基础工具函数
- Harbor 镜像按需推送（push_component_images_to_harbor）

用法: $0 <command> [options]

命令:
  setup-kubectl    设置 kubectl 环境
  check-helm       检查本机是否安装 helm
  cleanup          清理连接资源

EOF
}

# 主程序入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # 初始化环境
    initialize_environment
    
    # 脚本直接执行时的处理
    if [[ $# -lt 1 ]]; then
        show_usage
        exit 1
    fi
    
    case "$1" in
        "setup-kubectl")
            setup_kubectl_environment
            ;;
        "check-helm")
            check_helm
            ;;
        "cleanup")
            cleanup_k8s_connection
            ;;
        *)
            log_error "未知命令: $1"
            show_usage
            exit 1
            ;;
    esac
fi
