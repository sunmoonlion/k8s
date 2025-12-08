#!/bin/bash

# =============================================================================
# 集群配置映射函数库
# 文件名: cluster-config-mapping.sh
# 用途: 提供集群级别的配置映射功能，支持 C{数字}_* 前缀配置（如 C1_*, C2_*, C3_* 等）
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
  
  # 验证集群值格式：必须是 C{数字} 格式（如 C1, C2, C3, C10 等）
  # 支持不连续的集群编号（如只有 C1 和 C3，没有 C2）
  if [[ ! "$cluster_selected" =~ ^C[0-9]+$ ]]; then
    # 不是有效的集群格式，跳过映射
    return 0
  fi
  
  # 映射组件级别的集群配置（如 C1_STEPXX_ENABLED -> STEPXX_ENABLED）
  # 遍历所有以 C*_ 开头的变量，查找组件配置
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
  
  return 0
}

