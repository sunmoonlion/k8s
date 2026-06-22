#!/bin/bash

# =============================================================================
# 集群配置映射函数库
# 文件名: cluster-config-mapping.sh
# 用途: 提供集群级别的配置映射功能，支持 C{数字}_* 与 KIND_* 前缀（如 C1_*, C2_*, C3_*, KIND_*）；启用哪套由 default_cluster/CLUSTER 决定并自动覆盖到无前缀变量
# 设计: 通用工具函数，可被所有脚本调用
# =============================================================================

# =============================================================================
# 全局默认集群配置读取函数
# =============================================================================
# 用途：从全局配置文件读取默认集群配置
# 返回：默认集群标识（如 C1, C2），如果未找到则返回 C1
# 配置文件优先级：
#   1. k8s/utils/k8s-admin.conf 中的 [GLOBAL] 段的 default_cluster
#   2. 如果未找到，返回 C1
get_global_default_cluster() {
  # 尝试多个可能的配置文件路径
  local config_files=(
    "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/k8s-admin.conf"
    "$HOME/k8s/utils/k8s-admin.conf"
    "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")/utils/k8s-admin.conf"
  )
  
  local default_cluster="C1"  # 最终默认值
  
  for config_file in "${config_files[@]}"; do
    if [[ -f "$config_file" ]]; then
      # 读取 [GLOBAL] 段中的 default_cluster
      local found_cluster=$(sed -n '/^\[GLOBAL\]$/,/^\[[A-Z]/p' "$config_file" 2>/dev/null | grep "^default_cluster=" | head -1 | cut -d'=' -f2 | tr -d ' ')
      if [[ -n "$found_cluster" ]]; then
        default_cluster="$found_cluster"
        break
      fi
    fi
  done
  
  echo "$default_cluster"
}

# =============================================================================
# 获取默认集群函数（供脚本直接调用）
# =============================================================================
# 用途：获取默认集群配置，优先级：环境变量 CLUSTER > 全局配置文件 > C1
# 返回：集群标识（如 C1, C2）
# 使用示例：
#   local cluster=$(get_default_cluster)
#   export CLUSTER="$cluster"
get_default_cluster() {
  # 优先级1：环境变量 CLUSTER
  if [[ -n "${CLUSTER:-}" ]]; then
    echo "$CLUSTER"
    return 0
  fi
  
  # 优先级2：全局配置文件
  local global_default=$(get_global_default_cluster)
  echo "$global_default"
}

# =============================================================================
# Harbor 地址按集群解析
# =============================================================================
# 用途：统一 app 镜像仓库和 imagePullSecret 的 docker-server 默认值
# 重要：新增 app / 新增组件时不要写死 harbor.sunmoonai.com:30443。
#       部署入口只传 kind/c1，此函数负责按集群返回正确 Harbor 地址。
# 规则：
#   - KIND 使用 NodePort 暴露的 Harbor: harbor.sunmoonai.com:30443
#   - C1/C2/C3 等远程集群使用 NodePort 暴露的 Harbor: harbor.sunmoonai.com:30443
# 可通过环境变量覆盖：
#   {CLUSTER}_HARBOR_REGISTRY：指定集群优先值，例如 C1_HARBOR_REGISTRY
#   HARBOR_REGISTRY / REMOTE_HARBOR_REGISTRY：远程集群默认值
#   KIND_HARBOR_REGISTRY：Kind 默认值
get_cluster_harbor_registry() {
  local cluster_selected="${1:-}"

  if [[ -z "$cluster_selected" ]]; then
    cluster_selected=$(get_default_cluster)
  fi

  cluster_selected=$(echo "$cluster_selected" | tr '[:lower:]' '[:upper:]')

  local cluster_registry_var="${cluster_selected}_HARBOR_REGISTRY"
  local cluster_registry="${!cluster_registry_var:-}"
  if [[ -n "$cluster_registry" ]]; then
    echo "$cluster_registry"
    return 0
  fi

  case "$cluster_selected" in
    KIND)
      echo "${KIND_HARBOR_REGISTRY:-harbor.sunmoonai.com:30443}"
      ;;
    *)
      echo "${REMOTE_HARBOR_REGISTRY:-${HARBOR_REGISTRY:-harbor.sunmoonai.com:30443}}"
      ;;
  esac
}

apply_cluster_harbor_default() {
  local var_name="$1"
  local registry
  registry="$(get_cluster_harbor_registry)"

  if [[ -z "${!var_name:-}" ]]; then
    export "$var_name=$registry"
  fi
}

apply_cluster_harbor_registry_defaults() {
  local registry
  registry="$(get_cluster_harbor_registry)"

  local var_name var_value
  for var_name in $(compgen -v | grep -E '(^DOCKER_SERVER$|_IMAGE_REGISTRY$)' || true); do
    var_value="${!var_name:-}"

    # Keep explicit custom registries. Normalize only empty values and the old
    # scaffold defaults so generated manifests and imagePullSecrets stay aligned.
    case "$var_value" in
      ""|"harbor.sunmoonai.com"|"harbor.sunmoonai.com:30443")
        export "$var_name=$registry"
        ;;
    esac
  done
}

# =============================================================================
# 集群配置映射函数
# =============================================================================
# 用途：将 C*_ 前缀的配置映射到默认配置变量
# 参数：$1 = 集群标识（格式：C{数字}，如 C1, C2, C3 等，可选，会自动从 CLUSTER 获取）
# 说明：所有直接 source 配置文件的脚本都应该在 source 后调用此函数
# 
# 使用方法：
#   1. source "$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")/utils/cluster-config-mapping.sh"
#   2. source "$SCRIPT_DIR/deploy-*.conf"
#   3. apply_cluster_config_mapping
#
# 配置文件示例：
#   
#   # ================================================================
#   # 场景1: 不加前缀（两个集群都适用）
#   # ================================================================
#   STEP09_ENABLED=true
#   # 结果：C1=true, C2=true
#   
#   # ================================================================
#   # 场景2: 只加一个集群前缀（该集群覆盖，另一个用默认值）
#   # ================================================================
#   STEP09_ENABLED=true              # 默认值
#   C1_STEP09_ENABLED=false          # 只覆盖C1
#   # 结果：C1=false, C2=true
#   
#   # ================================================================
#   # 场景3: 多个集群都加前缀（精确控制，支持不连续编号）
#   # ================================================================
#   STEP09_ENABLED=true              # 默认值（会被覆盖）
#   C1_STEP09_ENABLED=true
#   C2_STEP09_ENABLED=false
#   C3_STEP09_ENABLED=true           # 支持 C3，即使没有 C2
#   # 结果：C1=true, C2=false, C3=true（精确控制）
#   # 注意：集群编号可以不连续，如只有 C1 和 C3
apply_cluster_config_mapping() {
  local cluster_selected="${1:-}"
  
  # 如果没有指定集群，尝试从环境变量、配置文件或默认值获取
  if [[ -z "$cluster_selected" ]]; then
    # 优先级1：环境变量 CLUSTER
    if [[ -n "${CLUSTER:-}" ]]; then
      cluster_selected="$CLUSTER"
    else
      # 优先级2：从全局配置文件读取默认集群
      cluster_selected=$(get_global_default_cluster)
      # 设置 CLUSTER 环境变量，以便后续使用
      export CLUSTER="$cluster_selected"
    fi
  fi
  
  # 统一为大写，便于前缀匹配（kind -> KIND）
  cluster_selected=$(echo "$cluster_selected" | tr '[:lower:]' '[:upper:]')
  export CLUSTER="$cluster_selected"

  # 验证集群值格式：C{数字}（如 C1, C2, C3）或 KIND，其他格式跳过映射
  if [[ ! "$cluster_selected" =~ ^(C[0-9]+|KIND)$ ]]; then
    return 0
  fi

  # 映射：当前集群前缀的变量覆盖到无前缀（C1_* / C2_* / KIND_* -> *）
  local cluster_prefix="${cluster_selected}_"
  
  # 使用 compgen -v 获取所有变量名，然后过滤
  local mapped_count=0
  for var_name in $(compgen -v | grep "^${cluster_prefix}" || true); do
    # 提取去掉集群前缀后的变量名
    local base_var_name="${var_name#${cluster_prefix}}"
    
    # 跳过 SERVER_n_* 变量（由 load_config_file 处理）
    if [[ "$base_var_name" =~ ^SERVER_[0-9]+_ ]]; then
      continue
    fi
    
    # 跳过 CLUSTER 等系统变量
    if [[ "$base_var_name" == "CLUSTER" ]]; then
      continue
    fi
    
    # 如果存在集群特定的配置，覆盖默认值
    # 例如：C1_STEP09_ENABLED=true 会覆盖 STEP09_ENABLED
    #       C3_STEP09_ENABLED=false 会覆盖 STEP09_ENABLED（当 CLUSTER=C3 时）
    local cluster_value="${!var_name}"
    if [[ -n "$cluster_value" ]]; then
      eval "$base_var_name=\"$cluster_value\""
      mapped_count=$((mapped_count+1))  # 使用显式赋值，避免 ((mapped_count++)) 在某些情况下导致的问题
    fi
  done
  
  # 如果映射了配置，输出日志（可选，避免过多输出）
  if [[ $mapped_count -gt 0 ]]; then
    # 只在调试模式下输出
    if [[ "${CLUSTER_CONFIG_MAPPING_DEBUG:-false}" == "true" ]]; then
      echo "[DEBUG] 集群配置映射: 已映射 $mapped_count 个配置项 (集群: $cluster_selected)" >&2
    fi
  fi

  apply_cluster_harbor_registry_defaults
  
  return 0
}
