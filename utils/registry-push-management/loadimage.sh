#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# registry-push-management: 通用镜像加载/打标/推送工具（Registry 无关）
# =============================================================================
# - 在远端节点执行：upload -> load -> tag -> push -> cleanup（可选）
# - 不绑定任何特定 Registry；目标引用可基于 REGISTRY_URL/PROJECT_NAME 构造，或直接传入完整 target_ref

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_FILE="${LOADIMAGE_CONF:-$SCRIPT_DIR/loadimage.conf}"

# 加载集群配置映射函数（如果存在）
CLUSTER_MAPPING_SCRIPT="$(dirname "$SCRIPT_DIR")/cluster-config-mapping.sh"
if [[ -f "$CLUSTER_MAPPING_SCRIPT" ]]; then
  source "$CLUSTER_MAPPING_SCRIPT"
fi

# 保存环境变量（如果已设置，用于覆盖配置文件中的值）
# 组件脚本可以通过环境变量覆盖配置文件中的值
SAVED_CLEANUP_REMOTE_TAR_AFTER_PUSH="${CLEANUP_REMOTE_TAR_AFTER_PUSH:-}"

# =============================================================================
# 解析命令行参数（支持 --cluster 或 -c 参数）
# =============================================================================
# 在加载配置之前解析，以便后续的 apply_cluster_config_mapping 可以使用
# 注意：只有在脚本被直接调用时才解析参数，被 source 时跳过
parse_cluster_arg() {
  local args=("$@")
  PARSED_ARGS=()
  local cluster_value=""
  local i=0
  
  while [[ $i -lt ${#args[@]} ]]; do
    shopt -s nocasematch
    case "${args[$i]}" in
      --cluster=*)
        # 支持等号形式：--cluster=C1 或 --CLUSTER=C1（大小写不敏感）
        cluster_value="${args[$i]#*=}"
        cluster_value=$(echo "$cluster_value" | tr '[:lower:]' '[:upper:]')
        export CLUSTER="$cluster_value"
        ;;
      --cluster|-c)
        # 支持空格形式：--cluster C1 或 -c C1（大小写不敏感）
        if [[ $((i+1)) -lt ${#args[@]} ]]; then
          cluster_value="${args[$((i+1))]}"
          cluster_value=$(echo "$cluster_value" | tr '[:lower:]' '[:upper:]')
          export CLUSTER="$cluster_value"
          i=$((i+1))
        fi
        ;;
      *)
        PARSED_ARGS+=("${args[$i]}")
        ;;
    esac
    shopt -u nocasematch
    i=$((i+1))
  done
}

# 保存原始参数（用于 main 函数）
ORIGINAL_MAIN_ARGS=("$@")

# 如果脚本被直接调用（不是被 source），解析命令行参数
# 注意：这里不能直接修改 $@，因为会影响后续的 main 函数
# 我们将在 main 函数中处理参数解析
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  # 保存原始参数
  ORIGINAL_MAIN_ARGS=("$@")
  # 解析集群参数（如果提供）
  if [[ $# -gt 0 ]]; then
    parse_cluster_arg "$@"
    # 保存解析后的参数（移除 --cluster 参数）
    ORIGINAL_MAIN_ARGS=("${PARSED_ARGS[@]}")
  fi
else
  # 如果被 source，保存原始参数（用于 main 函数）
  ORIGINAL_MAIN_ARGS=("$@")
fi

# 如果没有设置 CLUSTER，尝试从全局配置获取默认值
# 注意：如果被其他脚本调用，CLUSTER 可能已经通过环境变量设置
# 全局默认值在 k8s-admin.conf 的 [GLOBAL] 段中设置（当前默认值：C2）
if [[ -z "${CLUSTER:-}" ]] && type get_default_cluster >/dev/null 2>&1; then
  CLUSTER=$(get_default_cluster)
  export CLUSTER
fi

# 加载配置文件
[[ -f "$CONF_FILE" ]] && source "$CONF_FILE"

# 如果环境变量已设置（由组件脚本传递），优先使用环境变量的值
# 这样可以确保组件配置能够覆盖配置文件中的值
if [[ -n "$SAVED_CLEANUP_REMOTE_TAR_AFTER_PUSH" ]]; then
  CLEANUP_REMOTE_TAR_AFTER_PUSH="$SAVED_CLEANUP_REMOTE_TAR_AFTER_PUSH"
fi

# 应用集群配置映射（如果函数存在）
# 此时 CLUSTER 环境变量应该已经设置（通过命令行参数或默认值）
if type apply_cluster_config_mapping >/dev/null 2>&1; then
  apply_cluster_config_mapping
fi

log(){ printf "[reg-push] %s %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
ok(){ log "✅ $*"; }
warn(){ log "⚠️  $*"; }
err(){ log "❌ $*"; }

DRY_RUN="${DRY_RUN:-false}"

# =============================================================================
# 工具类配置（所有集群通用，有默认值）
# =============================================================================
NERDCTL_BIN="${NERDCTL_BIN:-nerdctl}"
CONTAINERD_NAMESPACE="${CONTAINERD_NAMESPACE:-k8s.io}"
USE_SUDO="${USE_SUDO:-true}"
PUSH_RETRY="${PUSH_RETRY:-2}"
PUSH_RETRY_INTERVAL="${PUSH_RETRY_INTERVAL:-3}"
LOCAL_IMAGE_DIR="${LOCAL_IMAGE_DIR:-$HOME/packages-to-be-installed/images}"
# 推送后清理远程 tar 文件开关（允许通过环境变量覆盖，用于组件脚本控制）
# 组件脚本可以通过设置 CLEANUP_REMOTE_TAR_AFTER_PUSH 环境变量来覆盖配置文件中的值
CLEANUP_REMOTE_TAR_AFTER_PUSH="${CLEANUP_REMOTE_TAR_AFTER_PUSH:-true}"

# =============================================================================
# 集群相关配置（必须通过集群配置映射设置，如 C1_REGISTRY_URL -> REGISTRY_URL）
# 这些变量没有默认值，必须从集群配置中获取
# =============================================================================
REGISTRY_URL="${REGISTRY_URL:-}"
PROJECT_NAME="${PROJECT_NAME:-}"
REMOTE_HOST="${REMOTE_HOST:-}"
REMOTE_USER="${REMOTE_USER:-}"
REMOTE_SSH_PORT="${REMOTE_SSH_PORT:-}"
REMOTE_SECRET="${REMOTE_SECRET:-}"
REMOTE_PASS="${REMOTE_PASS:-}"
REMOTE_IMAGE_DIR="${REMOTE_IMAGE_DIR:-}"
REGISTRY_USERNAME="${REGISTRY_USERNAME:-}"
REGISTRY_PASSWORD="${REGISTRY_PASSWORD:-}"
REGISTRY_LOGIN_BEFORE_PUSH="${REGISTRY_LOGIN_BEFORE_PUSH:-true}"

# =============================================================================
# 验证集群配置是否已正确设置
# =============================================================================
validate_cluster_config() {
  local missing_vars=()
  
  # 检查必需的配置项
  [[ -z "$REGISTRY_URL" ]] && missing_vars+=("REGISTRY_URL")
  [[ -z "$PROJECT_NAME" ]] && missing_vars+=("PROJECT_NAME")
  [[ -z "$REMOTE_HOST" ]] && missing_vars+=("REMOTE_HOST")
  [[ -z "$REMOTE_USER" ]] && missing_vars+=("REMOTE_USER")
  [[ -z "$REMOTE_SSH_PORT" ]] && missing_vars+=("REMOTE_SSH_PORT")
  [[ -z "$REMOTE_IMAGE_DIR" ]] && missing_vars+=("REMOTE_IMAGE_DIR")
  
  if [[ ${#missing_vars[@]} -gt 0 ]]; then
    err "集群配置不完整，缺少以下必需配置项："
    for var in "${missing_vars[@]}"; do
      err "  - $var"
    done
    err ""
    if [[ -z "${CLUSTER:-}" ]]; then
      err "提示：请设置 CLUSTER 环境变量（如 CLUSTER=C1 或 CLUSTER=C2）"
      err "或者使用命令行参数 --cluster C1 或 --cluster C2"
      err "或者在配置文件中添加对应的集群配置（如 C1_${missing_vars[0]}, C2_${missing_vars[0]} 等）"
      err "全局默认集群在 k8s-admin.conf 中设置（当前默认值：C2）"
    else
      err "提示：当前 CLUSTER=${CLUSTER}，请在配置文件中添加 ${CLUSTER}_${missing_vars[0]} 等配置项"
    fi
    return 1
  fi
  
  return 0
}

# 验证函数已定义，将在 main 函数中调用

# 远程执行与上传
exec_remote(){
  local host="$1" user="${2:-root}" port="${3:-22}" cmd="$4" secret="${5:-}" pass="${6:-}"
  local base=(-o StrictHostKeyChecking=no -o LogLevel=ERROR -p "$port")
  # 优化 SSH 选项：保持连接，禁用压缩（可能影响性能），允许 TTY（用于进度显示）
  base+=(-o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o Compression=no)
  if [[ "$DRY_RUN" == "true" ]]; then log "[dry-run] ssh $user@$host:$port: $cmd"; return 0; fi
  # 使用 bash -lc 确保远程环境变量和 ~ 正确展开
  if [[ -n "$secret" && -f "$secret" ]]; then
    ssh -i "$secret" "${base[@]}" "$user@$host" "bash -lc $(printf '%q' "$cmd")"
  elif command -v sshpass >/dev/null 2>&1 && [[ -n "$pass" ]]; then
    sshpass -p "$pass" ssh "${base[@]}" "$user@$host" "bash -lc $(printf '%q' "$cmd")"
  else
    ssh "${base[@]}" "$user@$host" "bash -lc $(printf '%q' "$cmd")"
  fi
}

scp_remote(){
  local src="$1" host="$2" user="${3:-root}" port="${4:-22}" dst_dir="$5" secret="${6:-}" pass="${7:-}"
  local base=(-o StrictHostKeyChecking=no -o LogLevel=ERROR -P "$port")
  if [[ "$DRY_RUN" == "true" ]]; then log "[dry-run] scp $src -> $user@$host:$dst_dir/"; return 0; fi
  
  local basename_file=$(basename "$src")
  local size_bytes=$(stat -c%s "$src" 2>/dev/null || echo 0)
  
  # 检查远程文件是否已存在且大小相同
  local remote_size=0
  # 构建 SSH 选项（scp 使用 -P，ssh 使用 -p）
  local ssh_base=(-o StrictHostKeyChecking=no -o LogLevel=ERROR -p "$port")
  
  # 获取远程用户的主目录（$user 是远程用户，从 REMOTE_USER 配置读取）
  # 如果路径包含 ~，需要获取远程用户的主目录来展开
  local remote_home=""
  if [[ "${dst_dir:0:1}" == "~" ]]; then
    # 通过 SSH 获取远程用户的真实主目录，而不是硬编码 /home/$user
    # 如果无法获取，回退到 /home/$user（大多数情况下的默认值）
    remote_home="/home/$user"
    if [[ -n "$secret" && -f "$secret" ]]; then
      remote_home=$(ssh -i "$secret" "${ssh_base[@]}" "$user@$host" "echo \$HOME" 2>/dev/null || echo "/home/$user")
    elif command -v sshpass >/dev/null 2>&1 && [[ -n "$pass" ]]; then
      remote_home=$(sshpass -p "$pass" ssh "${ssh_base[@]}" "$user@$host" "echo \$HOME" 2>/dev/null || echo "/home/$user")
    else
      remote_home=$(ssh "${ssh_base[@]}" "$user@$host" "echo \$HOME" 2>/dev/null || echo "/home/$user")
    fi
    # 清理可能的换行符
    remote_home=$(echo "$remote_home" | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [[ -z "$remote_home" ]] && remote_home="/home/$user"
  fi
  
  # 先在本地展开 dst_dir 中的 ~ 为绝对路径（参考 packages-management.sh 的方法）
  # 这样就不需要在远程通过 bash -lc 展开 ~，避免转义问题
  local expanded_dst_dir="$dst_dir"
  if [[ "${dst_dir:0:1}" == "~" ]]; then
    # 将 ~ 展开为远程用户的主目录
    expanded_dst_dir="$remote_home${dst_dir#\~}"
  fi
  
  # 构建完整的远程文件路径（使用已展开的 dst_dir）
  local remote_file="$expanded_dst_dir/$basename_file"
  local expanded_remote_file="$remote_file"
  
  # 使用展开后的绝对路径检查文件（使用单引号包裹路径，避免特殊字符问题）
  local remote_file_quoted=$(printf '%q' "$expanded_remote_file")
  
  # 直接使用 stat 命令检查文件并获取大小
  # stat 命令：如果文件存在返回大小（数字），如果不存在返回错误（非零退出码）
  # 注意：remote_file_quoted 已经通过 printf '%q' 转义，可以直接在命令中使用
  # 构建完整的命令字符串，确保路径被正确引用
  local stat_cmd="LC_ALL=C stat -c%s $remote_file_quoted"
  
  # 添加调试信息：显示实际检查的路径
  if [[ "${DEBUG_FILE_CHECK:-false}" == "true" ]]; then
    log "🔍 [DEBUG] 检查远程文件: $expanded_remote_file"
    log "🔍 [DEBUG] 转义后的路径: $remote_file_quoted"
    log "🔍 [DEBUG] 执行的命令: $stat_cmd"
  fi
  
  # 执行命令，将 stderr 和 stdout 都捕获
  # 注意：需要将命令作为单个参数传递给 SSH，使用 "$user@$host" 格式
  local raw_output=""
  local ssh_exit_code=0
  if [[ -n "$secret" && -f "$secret" ]]; then
    raw_output=$(ssh -i "$secret" "${ssh_base[@]}" "$user@$host" "$stat_cmd" 2>&1)
    ssh_exit_code=$?
  elif command -v sshpass >/dev/null 2>&1 && [[ -n "$pass" ]]; then
    raw_output=$(sshpass -p "$pass" ssh "${ssh_base[@]}" "$user@$host" "$stat_cmd" 2>&1)
    ssh_exit_code=$?
  else
    raw_output=$(ssh "${ssh_base[@]}" "$user@$host" "$stat_cmd" 2>&1)
    ssh_exit_code=$?
  fi
  
  if [[ "${DEBUG_FILE_CHECK:-false}" == "true" ]]; then
    log "🔍 [DEBUG] SSH退出码: $ssh_exit_code"
    log "🔍 [DEBUG] 原始输出: '$raw_output'"
  fi
  
  # 从输出中提取纯数字（文件大小）
  # 方法：直接提取所有纯数字行，然后取最大的（文件大小通常是最大的数字）
  # 这样可以避免被警告信息干扰（警告行不是纯数字，会被过滤掉）
  local cleaned_output=""
  # 直接提取所有纯数字行（警告行不是纯数字，会被自动过滤）
  local all_numbers=$(echo "$raw_output" | grep -E '^[0-9]+$')
  
  if [[ "${DEBUG_FILE_CHECK:-false}" == "true" ]]; then
    log "🔍 [DEBUG] 原始输出: '$raw_output'"
    log "🔍 [DEBUG] 所有数字行: '$all_numbers'"
  fi
  
  # 如果有数字行，取最大的（文件大小通常是最大的）
  if [[ -n "$all_numbers" ]]; then
    cleaned_output=$(echo "$all_numbers" | sort -n | tail -1)
  fi
  
  if [[ "${DEBUG_FILE_CHECK:-false}" == "true" ]]; then
    log "🔍 [DEBUG] 清理后输出: '$cleaned_output'"
  fi
  
  # 如果提取到纯数字，说明文件存在且获取到了大小
  if [[ "$cleaned_output" =~ ^[0-9]+$ ]] && [[ ${#cleaned_output} -gt 0 ]] && [[ $cleaned_output -gt 0 ]]; then
    remote_size="$cleaned_output"
  else
    # 如果提取失败，可能是文件不存在或命令失败
    # 先检查文件是否存在（使用 test -f）
    local test_cmd="LC_ALL=C test -f $remote_file_quoted"
    local file_exists=false
    if [[ -n "$secret" && -f "$secret" ]]; then
      ssh -i "$secret" "${ssh_base[@]}" "$user@$host" "$test_cmd" >/dev/null 2>&1 && file_exists=true
    elif command -v sshpass >/dev/null 2>&1 && [[ -n "$pass" ]]; then
      sshpass -p "$pass" ssh "${ssh_base[@]}" "$user@$host" "$test_cmd" >/dev/null 2>&1 && file_exists=true
    else
      ssh "${ssh_base[@]}" "$user@$host" "$test_cmd" >/dev/null 2>&1 && file_exists=true
    fi
    
    # 如果文件存在但无法获取大小，才输出警告
    if [[ "$file_exists" == "true" ]]; then
      # 尝试备用方法：使用 wc -c
      local wc_output=""
      if [[ -n "$secret" && -f "$secret" ]]; then
        wc_output=$(ssh -i "$secret" "${ssh_base[@]}" "$user@$host" "LC_ALL=C wc -c < $remote_file_quoted 2>/dev/null" 2>&1 | grep -E '^[0-9]+$' | head -1)
      elif command -v sshpass >/dev/null 2>&1 && [[ -n "$pass" ]]; then
        wc_output=$(sshpass -p "$pass" ssh "${ssh_base[@]}" "$user@$host" "LC_ALL=C wc -c < $remote_file_quoted 2>/dev/null" 2>&1 | grep -E '^[0-9]+$' | head -1)
      else
        wc_output=$(ssh "${ssh_base[@]}" "$user@$host" "LC_ALL=C wc -c < $remote_file_quoted 2>/dev/null" 2>&1 | grep -E '^[0-9]+$' | head -1)
      fi
      if [[ "$wc_output" =~ ^[0-9]+$ ]] && [[ ${#wc_output} -gt 0 ]]; then
        remote_size="$wc_output"
      else
        # 文件存在但无法获取大小，输出警告
        remote_size=0
        if [[ -n "$raw_output" ]]; then
          warn "⚠️  文件存在但无法获取大小，原始输出: '$(echo "$raw_output" | head -3 | tr '\n' '; ')'"
        fi
      fi
    else
      # 文件不存在，这是正常情况，不输出警告
      remote_size=0
    fi
  fi
  
  # 验证是否为有效数字
  if [[ -z "$remote_size" ]] || ! [[ "$remote_size" =~ ^[0-9]+$ ]]; then
    remote_size=0
  fi
  
  # 调试：如果大小异常小（小于1MB）但本地文件很大，可能是提取错误
  if [[ "$remote_size" -gt 0 ]] && [[ "$remote_size" -lt 1048576 ]] && [[ "$size_bytes" -gt 1048576 ]]; then
    warn "⚠️  检测到远程文件大小异常小 ($remote_size 字节 vs 本地 $size_bytes 字节)"
    warn "   原始输出: '$raw_output'"
    warn "   SSH退出码: $ssh_exit_code"
    # 尝试使用更简单的方法重新检查
    local simple_check="test -f $remote_file_quoted && stat -c%s $remote_file_quoted || echo 0"
    local simple_output=""
    if [[ -n "$secret" && -f "$secret" ]]; then
      simple_output=$(ssh -i "$secret" "${ssh_base[@]}" "LC_ALL=C $simple_check" 2>&1 | grep -E '^[0-9]+$' | head -1)
    elif command -v sshpass >/dev/null 2>&1 && [[ -n "$pass" ]]; then
      simple_output=$(sshpass -p "$pass" ssh "${ssh_base[@]}" "LC_ALL=C $simple_check" 2>&1 | grep -E '^[0-9]+$' | head -1)
    else
      simple_output=$(ssh "${ssh_base[@]}" "LC_ALL=C $simple_check" 2>&1 | grep -E '^[0-9]+$' | head -1)
    fi
    if [[ "$simple_output" =~ ^[0-9]+$ ]] && [[ $simple_output -gt 1000 ]]; then
      warn "   使用简单方法重新检查: $simple_output 字节"
      remote_size="$simple_output"
    else
      # 如果重新检查也失败，将 remote_size 设为 0，强制重新上传
      warn "   无法获取正确的远程文件大小，将强制重新上传"
      remote_size=0
    fi
  fi
  
  # 调试：显示检查结果（总是显示，方便调试）
  # 使用已展开的绝对路径用于显示
  local expanded_path_display="$expanded_remote_file"
  
  if [[ "$remote_size" =~ ^[0-9]+$ ]]; then
    if [[ "$remote_size" -gt 0 ]]; then
      log "🔍 检查远程文件: $basename_file (本地: $size_bytes, 远程: $remote_size) [路径: $expanded_path_display]"
    else
      log "🔍 检查远程文件: $basename_file (本地: $size_bytes, 远程: 不存在) [路径: $expanded_path_display]"
    fi
  else
    # 如果 remote_size 不是数字，说明检查失败，记录警告
    warn "无法检查远程文件大小: $basename_file (返回值: '$remote_size') [路径: $expanded_path_display]"
  fi
  
  # 格式化文件大小显示
  local size_display=""
  if command -v numfmt >/dev/null 2>&1 && [[ $size_bytes -gt 0 ]]; then
    size_display=$(numfmt --to=iec-i --suffix=B "$size_bytes" 2>/dev/null || echo "${size_bytes}B")
  else
    # 简单的格式化：转换为 MB/GB
    if [[ $size_bytes -gt 1073741824 ]]; then
      size_display=$(awk "BEGIN {printf \"%.2fGB\", $size_bytes/1073741824}")
    elif [[ $size_bytes -gt 1048576 ]]; then
      size_display=$(awk "BEGIN {printf \"%.2fMB\", $size_bytes/1048576}")
    elif [[ $size_bytes -gt 1024 ]]; then
      size_display=$(awk "BEGIN {printf \"%.2fKB\", $size_bytes/1024}")
    else
      size_display="${size_bytes}B"
    fi
  fi
  
  # 如果远程文件存在且大小相同，跳过上传
  # 使用数值比较而不是字符串比较，避免类型问题
  # 如果远程文件存在但大小不同，提示用户
  if [[ "$remote_size" =~ ^[0-9]+$ ]] && [[ "$size_bytes" =~ ^[0-9]+$ ]] && \
     [[ "$remote_size" -ne "$size_bytes" ]] && [[ "$remote_size" -gt 0 ]]; then
    # 格式化远程文件大小显示
    local remote_size_display=""
    if command -v numfmt >/dev/null 2>&1 && [[ $remote_size -gt 0 ]]; then
      remote_size_display=$(numfmt --to=iec-i --suffix=B "$remote_size" 2>/dev/null || echo "${remote_size}B")
    else
      if [[ $remote_size -gt 1073741824 ]]; then
        remote_size_display=$(awk "BEGIN {printf \"%.2fGB\", $remote_size/1073741824}")
      elif [[ $remote_size -gt 1048576 ]]; then
        remote_size_display=$(awk "BEGIN {printf \"%.2fMB\", $remote_size/1048576}")
      elif [[ $remote_size -gt 1024 ]]; then
        remote_size_display=$(awk "BEGIN {printf \"%.2fKB\", $remote_size/1024}")
      else
        remote_size_display="${remote_size}B"
      fi
    fi
    warn "远程文件大小不同 (本地: $size_display, 远程: $remote_size_display)，将重新上传"
  fi
  
  if [[ "$remote_size" =~ ^[0-9]+$ ]] && [[ "$size_bytes" =~ ^[0-9]+$ ]] && \
     [[ "$remote_size" -eq "$size_bytes" ]] && [[ "$size_bytes" -gt 0 ]]; then
    log "⏭️  跳过上传: $basename_file (远程已存在，大小相同: $size_display)"
    return 0
  fi
  
  # 显示上传提示
  log "📤 上传: $basename_file ($size_display)"
  
  # 复用上面已经展开的 expanded_dst_dir（已在文件检查前展开）
  
  # 尝试使用 pv 显示进度（如果可用且文件大小 > 0）
  if command -v pv >/dev/null 2>&1 && [[ $size_bytes -gt 0 ]]; then
    local ssh_cmd_base=""
    if [[ -n "$secret" && -f "$secret" ]]; then
      ssh_cmd_base="ssh -i $secret ${base[*]}"
    elif command -v sshpass >/dev/null 2>&1 && [[ -n "$pass" ]]; then
      ssh_cmd_base="sshpass -p $pass ssh ${base[*]}"
    else
      ssh_cmd_base="ssh ${base[*]}"
    fi
    # 使用展开后的绝对路径
    if pv -s $size_bytes "$src" | $ssh_cmd_base "$user@$host" "cat > $expanded_remote_file" 2>&1; then
      return 0
    else
      warn "pv 传输失败，回退到 scp..."
    fi
  fi
  
  # 回退到标准 scp（使用展开后的绝对路径）
  # scp 默认不显示进度，但会正常执行
  # 如果文件较大，上传可能需要一些时间，这是正常的
  if [[ -n "$secret" && -f "$secret" ]]; then
    scp -i "$secret" "${base[@]}" "$src" "$user@$host:$expanded_dst_dir/"
  elif command -v sshpass >/dev/null 2>&1 && [[ -n "$pass" ]]; then
    sshpass -p "$pass" scp "${base[@]}" "$src" "$user@$host:$expanded_dst_dir/"
  else
    scp "${base[@]}" "$src" "$user@$host:$expanded_dst_dir/"
  fi
}

parse_loaded_ref(){
  local out="$1" ref
  # 方式1: 查找 "Loaded image" 或 "loaded:"
  ref=$(echo "$out" | awk '/Loaded image/ {print $NF}' | tail -n1)
  [[ -z "$ref" ]] && ref=$(echo "$out" | awk '/loaded:/ {print $2}' | tail -n1)
  # 方式2: 查找包含 : 的行，可能是镜像引用（格式: registry/repo:tag）
  [[ -z "$ref" ]] && ref=$(echo "$out" | grep -E ":[^/]" | grep -vE "^(Loaded|loaded|Error|error)" | head -1 | awk '{print $NF}')
  # 方式3: 使用正则表达式查找镜像引用格式 (registry/repo:tag 或 repo:tag)
  [[ -z "$ref" ]] && ref=$(echo "$out" | grep -oE "[a-zA-Z0-9._-]+(/[a-zA-Z0-9._-]+)+:[a-zA-Z0-9._-]+" | head -1)
  # 方式4: 查找任何包含 / 和 : 的字符串（可能是镜像引用）
  [[ -z "$ref" ]] && ref=$(echo "$out" | grep -oE "[^[:space:]]+/[^[:space:]]+:[^[:space:]]+" | head -1)
  echo "$ref"
}

remote_login_if_needed(){
  local host="$1" user="$2" port="$3" secret="$4" pass="$5"
  [[ "$REGISTRY_LOGIN_BEFORE_PUSH" == "true" ]] || return 0
  [[ -n "$REGISTRY_URL" && -n "$REGISTRY_USERNAME" && -n "$REGISTRY_PASSWORD" ]] || { warn "跳过登录：未配置 REGISTRY_URL/USERNAME/PASSWORD"; return 0; }
  local sudo_prefix=""; [[ "$USE_SUDO" == "true" ]] && sudo_prefix="sudo -n "
  local nb="$NERDCTL_BIN"
  local cmd="echo '$REGISTRY_PASSWORD' | $sudo_prefix$nb login '$REGISTRY_URL' -u '$REGISTRY_USERNAME' --password-stdin"
  exec_remote "$host" "$user" "$port" "$cmd" "$secret" "$pass"
}

load_image(){
  local remote_tar="$1" host="$2" user="${3:-root}" port="${4:-22}" secret="${5:-}" pass="${6:-}"
  local sudo_prefix=""; [[ "$USE_SUDO" == "true" ]] && sudo_prefix="sudo -n "
  local nb="$NERDCTL_BIN" ns="$CONTAINERD_NAMESPACE"
  # 简单命令，交由 exec_remote 的 bash -lc 处理引号和 ~ 展开
  local cmd="$sudo_prefix$nb -n $ns load -i $remote_tar"
  local out; out=$(exec_remote "$host" "$user" "$port" "$cmd" "$secret" "$pass" 2>&1 || true)
  local ref; ref=$(parse_loaded_ref "$out")
  [[ -z "$ref" ]] && { err "未能解析镜像引用: $remote_tar"; return 1; }
  echo "$ref"
}

tag_image(){
  local src_ref="$1" dst_ref="$2" host="$3" user="${4:-root}" port="${5:-22}" secret="${6:-}" pass="${7:-}"
  local sudo_prefix=""; [[ "$USE_SUDO" == "true" ]] && sudo_prefix="sudo -n "
  local nb="$NERDCTL_BIN" ns="$CONTAINERD_NAMESPACE"
  local cmd="$sudo_prefix$nb -n $ns tag $src_ref $dst_ref"
  exec_remote "$host" "$user" "$port" "$cmd" "$secret" "$pass"
}

push_image(){
  local ref="$1" host="$2" user="${3:-root}" port="${4:-22}" secret="${5:-}" pass="${6:-}"
  # 可选登录
  remote_login_if_needed "$host" "$user" "$port" "$secret" "$pass" || true
  # 必须：目标 registry 已有则跳过
  if registry_has_ref "$ref" "$host" "$user" "$port" "$secret" "$pass"; then
    ok "跳过推送（目标已存在）: $ref"
    return 0
  fi
  local nb="$NERDCTL_BIN" ns="$CONTAINERD_NAMESPACE" sudo_prefix=""; [[ "$USE_SUDO" == "true" ]] && sudo_prefix="sudo -n "
  # 构建环境变量数组，避免前导空格问题
  local env_vars=()
  [[ -n "${HTTP_PROXY:-}" ]] && env_vars+=("HTTP_PROXY=$HTTP_PROXY")
  [[ -n "${HTTPS_PROXY:-}" ]] && env_vars+=("HTTPS_PROXY=$HTTPS_PROXY")
  [[ -n "${NO_PROXY:-}" ]] && env_vars+=("NO_PROXY=$NO_PROXY")
  local tries=0 max="$PUSH_RETRY" interval="$PUSH_RETRY_INTERVAL"
  while true; do
    # 构建命令：优先使用环境变量，stdbuf 可能影响性能，只在必要时使用
    local nerdctl_cmd="$sudo_prefix$nb -n $ns push $ref"
    if [[ ${#env_vars[@]} -gt 0 ]]; then
      # 如果有环境变量，使用 env 命令设置
      # 不使用 stdbuf，因为它可能影响性能，而且 nerdctl 本身已经有进度显示
      local cmd="env ${env_vars[*]} $nerdctl_cmd"
    else
      # 没有环境变量，直接使用命令
      local cmd="$nerdctl_cmd"
    fi
    # 添加提示信息，让用户知道推送正在进行
    log "开始推送: $ref"
    if exec_remote "$host" "$user" "$port" "$cmd" "$secret" "$pass"; then ok "推送成功: $ref"; return 0; fi
    tries=$((tries+1))  # 使用显式赋值，避免 ((tries++)) 在某些情况下导致的问题
    if (( tries > max )); then err "推送失败: $ref"; return 1; fi
    log "重试推送 ($tries/$max)..."; sleep "$interval"
  done
}

# 检查目标 registry 是否存在该 ref（使用 skopeo，可选）
registry_has_ref(){
  local ref="$1" host="$2" user="$3" port="$4" secret="$5" pass="$6"
  if [[ "${EXISTENCE_CHECK_TOOL:-skopeo}" != "skopeo" ]]; then
    log "⏭️  跳过存在性检查（EXISTENCE_CHECK_TOOL=${EXISTENCE_CHECK_TOOL:-skopeo}）"
    return 1
  fi
  # 检查远程节点是否安装了 skopeo
  if ! exec_remote "$host" "$user" "$port" "command -v skopeo >/dev/null 2>&1" "$secret" "$pass" 2>/dev/null; then
    warn "远程节点未安装 skopeo，跳过存在性检查，将尝试推送"
    return 1
  fi
  # 仅当远端节点已安装 skopeo 时执行；否则认为未知（让 push 尝试）
  local tlsopt="--tls-verify=${REGISTRY_TLS_VERIFY:-false}"
  local credopt=""; [[ -n "$REGISTRY_USERNAME" && -n "$REGISTRY_PASSWORD" ]] && credopt="--creds '$REGISTRY_USERNAME:$REGISTRY_PASSWORD'"
  log "🔍 检查镜像是否已存在: $ref"
  local cmd="skopeo inspect $tlsopt $credopt docker://$ref >/dev/null 2>&1"
  if exec_remote "$host" "$user" "$port" "$cmd" "$secret" "$pass" 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

remove_image(){
  local ref="$1" host="$2" user="${3:-root}" port="${4:-22}" secret="${5:-}" pass="${6:-}"
  local nb="$NERDCTL_BIN" ns="$CONTAINERD_NAMESPACE" sudo_prefix=""; [[ "$USE_SUDO" == "true" ]] && sudo_prefix="sudo -n "
  local cmd="$sudo_prefix$nb -n $ns rmi $ref || true"
  exec_remote "$host" "$user" "$port" "$cmd" "$secret" "$pass"
}

remove_file(){
  local file="$1" host="$2" user="${3:-root}" port="${4:-22}" secret="${5:-}" pass="${6:-}"
  # 不要在这里加引号，让 printf '%q' 在 exec_remote 中处理转义
  local cmd="rm -f $file || true"
  exec_remote "$host" "$user" "$port" "$cmd" "$secret" "$pass"
}

find_local_tar_for_ref(){
  local img="$1"; local safe
  safe=$(echo "$img" | sed 's#[/:]#_#g')
  for f in "$LOCAL_IMAGE_DIR/${img}.tar" "$LOCAL_IMAGE_DIR/${safe}.tar" "$LOCAL_IMAGE_DIR/${img}.tar.gz"; do
    [[ -f "$f" ]] && { echo "$f"; return 0; }
  done
  return 1
}

build_target_ref(){
  local name_only="$1" tag="$2"
  if [[ -n "$REGISTRY_URL" ]]; then
    echo "$REGISTRY_URL/${PROJECT_NAME}/${name_only}:$tag"
  else
    err "未设置 REGISTRY_URL，无法构造目标引用；请传入完整 target_ref 或在 conf 中配置 REGISTRY_URL"
    return 1
  fi
}

usage(){ cat <<EOF
registry-push-management（通用）
用法:
  # 一步完成：从本地 tar 上传到远端并 push 到目标 registry
  $0 [--cluster C1|C2] upload-load-push <local_tar> <host> <remote_dir> <target_ref> [user] [port] [secret] [pass]

  # 分步：
  $0 [--cluster C1|C2] load-image <remote_tar> <host> [user] [port] [secret] [pass]
  $0 [--cluster C1|C2] tag-image <source_ref> <target_ref> <host> [user] [port] [secret] [pass]
  $0 [--cluster C1|C2] push-image <target_ref> <host> [user] [port] [secret] [pass]
  $0 [--cluster C1|C2] remove-image <image_ref> <host> [user] [port] [secret] [pass]
  $0 [--cluster C1|C2] remove-file <remote_path> <host> [user] [port] [secret] [pass]

  # 便捷：使用本地目录与 REGISTRY_URL/PROJECT_NAME 自动构造目标引用
  $0 [--cluster C1|C2] push-by-ref <repo:tag> [host] [remote_dir] [user] [port] [secret] [pass]
  $0 [--cluster C1|C2] push-from-list <list_file> [host] [remote_dir] [user] [port] [secret] [pass]
  $0 [--cluster C1|C2] push-from-dir [dir] [host] [remote_dir] [user] [port] [secret] [pass]

参数说明:
  --cluster, -c    指定集群（C1, C2, C3 等），用于加载对应的集群配置
                   如果不指定，将使用环境变量 CLUSTER 或全局默认值（当前默认值：C2）
                   全局默认值在 k8s-admin.conf 的 [GLOBAL] 段中设置

  - 方括号参数省略时，将使用 loadimage.conf 中 REMOTE_* 默认值。
  - 若 REGISTRY_URL 未设置，请使用 upload-load-push 并传入完整 target_ref。
  - 可选：REGISTRY_LOGIN_BEFORE_PUSH=true 时，在 push 前于远端执行 nerdctl login（使用 REGISTRY_USERNAME/PASSWORD）。

示例:
  # 指定集群 C2 推送镜像
  $0 --cluster C2 push-by-ref nginx:latest

  # 使用环境变量指定集群
  CLUSTER=C2 $0 push-by-ref nginx:latest

  # 从列表推送（使用集群 C2）
  $0 -c C2 push-from-list images.txt
EOF
}

main(){
  # 如果脚本被直接调用，使用解析后的参数（已移除 --cluster 参数）
  # 如果被其他脚本 source，使用原始参数
  if [[ "${BASH_SOURCE[0]}" == "$0" ]] && [[ ${#ORIGINAL_MAIN_ARGS[@]} -gt 0 ]]; then
    set -- "${ORIGINAL_MAIN_ARGS[@]}"
  fi
  
  local cmd="${1:-help}"; shift || true
  for a in "$@"; do [[ "$a" == "--dry-run" ]] && DRY_RUN="true"; done
  
  # Kind 模式：本脚本通过 SSH 在远程节点执行 load/push，Kind 无此类节点，跳过（避免报错）
  if [[ "$cmd" != "help" && "$cmd" != "-h" && "$cmd" != "--help" ]]; then
    if [[ "${K8S_TARGET_MODE:-}" == "kind" ]]; then
      log "Kind 集群，跳过镜像推送（镜像由 load-initial-images-kind.sh 预加载或在线拉取）"
      return 0
    fi
    local k8s_admin_conf="${SCRIPT_DIR}/../k8s-admin.conf"
    if [[ -f "$k8s_admin_conf" ]]; then
      local cluster_mode="" default_cluster=""
      cluster_mode=$(sed -n '/^\[GLOBAL\]$/,/^\[[A-Z]/p' "$k8s_admin_conf" 2>/dev/null | grep "^cluster_mode=" | head -1 | cut -d'=' -f2 | tr -d ' ')
      default_cluster=$(sed -n '/^\[GLOBAL\]$/,/^\[[A-Z]/p' "$k8s_admin_conf" 2>/dev/null | grep "^default_cluster=" | head -1 | cut -d'=' -f2 | tr -d ' ')
      default_cluster=$(echo "$default_cluster" | tr '[:lower:]' '[:upper:]')
      if [[ "$cluster_mode" == "kind" ]] || [[ "$default_cluster" == "KIND" ]]; then
        log "Kind 集群，跳过镜像推送（镜像由 load-initial-images-kind.sh 预加载或在线拉取）"
        return 0
      fi
    fi
  fi
  
  # 显示当前使用的集群配置（如果已设置）
  if [[ -n "${CLUSTER:-}" ]] && [[ "$cmd" != "help" && "$cmd" != "-h" && "$cmd" != "--help" ]]; then
    log "🎯 使用集群配置: ${CLUSTER}"
  fi
  
  # 验证集群配置（help 命令除外）
  if [[ "$cmd" != "help" && "$cmd" != "-h" && "$cmd" != "--help" ]]; then
    validate_cluster_config || exit 1
  fi
  
  case "$cmd" in
    upload-load-push)
      if [[ $# -lt 4 ]]; then usage; exit 1; fi
      local local_tar="$1" host="$2" remote_dir="$3" target_ref="$4" user="${5:-root}" port="${6:-22}" secret="${7:-}" pass="${8:-}"
      [[ -f "$local_tar" ]] || { err "本地 tar 不存在: $local_tar"; exit 1; }
      log "开始处理镜像: $target_ref (本地文件: $(basename "$local_tar"))"
      local mkdir_cmd="mkdir -p $remote_dir"
      exec_remote "$host" "$user" "$port" "$mkdir_cmd" "$secret" "$pass" || { err "创建远程目录失败: $remote_dir"; exit 1; }
      scp_remote "$local_tar" "$host" "$user" "$port" "$remote_dir" "$secret" "$pass" || { err "上传 tar 文件失败: $local_tar"; exit 1; }
      local remote_tar="$remote_dir/$(basename "$local_tar")"
      log "开始加载镜像: $remote_tar"
      local src_ref; src_ref=$(load_image "$remote_tar" "$host" "$user" "$port" "$secret" "$pass") || { err "加载镜像失败: $remote_tar"; exit 1; }
      log "开始打标镜像: $src_ref -> $target_ref"
      tag_image "$src_ref" "$target_ref" "$host" "$user" "$port" "$secret" "$pass" || { err "打标镜像失败: $src_ref -> $target_ref"; exit 1; }
      log "开始推送镜像: $target_ref"
      push_image "$target_ref" "$host" "$user" "$port" "$secret" "$pass" || { err "推送镜像失败: $target_ref"; exit 1; }
      remove_image "$src_ref" "$host" "$user" "$port" "$secret" "$pass" || true
      remove_image "$target_ref" "$host" "$user" "$port" "$secret" "$pass" || true
      # 根据配置决定是否删除远程 tar 文件
      if [[ "${CLEANUP_REMOTE_TAR_AFTER_PUSH:-true}" == "true" ]]; then
        [[ -n "${remote_tar:-}" ]] && remove_file "$remote_tar" "$host" "$user" "$port" "$secret" "$pass" || true
      else
        log "⏭️  保留远程 tar 文件: $(basename "$remote_tar") (CLEANUP_REMOTE_TAR_AFTER_PUSH=false)"
      fi
      ok "镜像处理完成: $target_ref"
      return 0
      ;;
    load-image)
      [[ $# -ge 2 ]] || { usage; exit 1; }
      load_image "$@" >/dev/null
      ;;
    tag-image)
      [[ $# -ge 3 ]] || { usage; exit 1; }
      tag_image "$@"
      ;;
    push-image)
      [[ $# -ge 2 ]] || { usage; exit 1; }
      push_image "$@"
      ;;
    remove-image)
      [[ $# -ge 2 ]] || { usage; exit 1; }
      remove_image "$@"
      ;;
    remove-file)
      [[ $# -ge 2 ]] || { usage; exit 1; }
      remove_file "$@"
      ;;
    push-by-ref)
      if [[ $# -lt 1 ]]; then usage; exit 1; fi
      local img_ref="$1" host="${2:-$REMOTE_HOST}" remote_dir="${3:-$REMOTE_IMAGE_DIR}" user="${4:-$REMOTE_USER}" port="${5:-$REMOTE_SSH_PORT}" secret="${6:-$REMOTE_SECRET}" pass="${7:-$REMOTE_PASS}"
      [[ -n "$host" ]] || { err "未提供 host（参数或 REMOTE_HOST）"; exit 1; }
      local tar_path; tar_path=$(find_local_tar_for_ref "$img_ref") || { err "未找到本地 tar: $img_ref"; exit 1; }
      local name_only="${img_ref%:*}"; name_only="${name_only##*/}"; local tag="${img_ref##*:}"
      local target_ref; target_ref=$(build_target_ref "$name_only" "$tag") || exit 1
      "${BASH_SOURCE[0]}" upload-load-push "$tar_path" "$host" "$remote_dir" "$target_ref" "$user" "$port" "$secret" "$pass"
      ;;
    push-from-list)
      if [[ $# -lt 1 ]]; then usage; exit 1; fi
      local list_file="$1" host="${2:-$REMOTE_HOST}" remote_dir="${3:-$REMOTE_IMAGE_DIR}" user="${4:-$REMOTE_USER}" port="${5:-$REMOTE_SSH_PORT}" secret="${6:-$REMOTE_SECRET}" pass="${7:-$REMOTE_PASS}"
      [[ -n "$host" ]] || { err "未提供 host（参数或 REMOTE_HOST）"; exit 1; }
      [[ -f "$list_file" ]] || { err "清单文件不存在: $list_file"; exit 1; }
      local success_count=0
      local fail_count=0
      local failed_images=()
      while IFS= read -r img; do
        [[ -z "$img" || "$img" =~ ^# ]] && continue
        log "处理镜像: $img"
        if "${BASH_SOURCE[0]}" push-by-ref "$img" "$host" "$remote_dir" "$user" "$port" "$secret" "$pass"; then
          success_count=$((success_count + 1))
          ok "镜像推送成功: $img"
        else
          fail_count=$((fail_count + 1))
          failed_images+=("$img")
          err "镜像推送失败: $img"
        fi
      done < "$list_file"
      # 输出汇总信息
      log "镜像推送完成: 成功 $success_count 个，失败 $fail_count 个"
      if [[ $fail_count -gt 0 ]]; then
        err "失败的镜像列表:"
        for img in "${failed_images[@]}"; do
          err "  - $img"
        done
        # 如果有失败的镜像，返回非零退出码
        exit 1
      fi
      ;;
    push-from-dir)
      local dir="${1:-$LOCAL_IMAGE_DIR}" host="${2:-${REMOTE_HOST:-}}" remote_dir="${3:-${REMOTE_IMAGE_DIR:-}}" user="${4:-${REMOTE_USER:-root}}" port="${5:-${REMOTE_SSH_PORT:-22}}" secret="${6:-${REMOTE_SECRET:-}}" pass="${7:-${REMOTE_PASS:-}}"
      [[ -n "${host:-}" ]] || { err "未提供 host（参数或 REMOTE_HOST）"; exit 1; }
      [[ -d "$dir" ]] || { err "目录不存在: $dir"; exit 1; }
      shopt -s nullglob
      local push_failed=false
      local processed_count=0
      for tar in "$dir"/*.tar "$dir"/*.tar.gz; do
        [[ -e "$tar" ]] || continue
        processed_count=$((processed_count + 1))
        log "处理文件 $processed_count: $(basename "$tar")"
        local mkdir_cmd="mkdir -p $remote_dir"
        exec_remote "${host:-}" "${user:-}" "${port:-}" "$mkdir_cmd" "${secret:-}" "${pass:-}" || { err "创建远程目录失败: $remote_dir"; push_failed=true; continue; }
        scp_remote "$tar" "${host:-}" "${user:-}" "${port:-}" "$remote_dir" "${secret:-}" "${pass:-}" || { err "上传 tar 文件失败: $tar"; push_failed=true; continue; }
        local remote_tar="$remote_dir/$(basename "$tar")"
        local src_ref; src_ref=$(load_image "$remote_tar" "${host:-}" "${user:-}" "${port:-}" "${secret:-}" "${pass:-}") || { warn "跳过: 无法解析 $tar"; push_failed=true; continue; }
        local name_only="${src_ref%:*}"; name_only="${name_only##*/}"; local tag="${src_ref##*:}"
        local target_ref; target_ref=$(build_target_ref "$name_only" "$tag") || { warn "跳过: 无法构造目标 $src_ref"; push_failed=true; continue; }
        tag_image "$src_ref" "$target_ref" "${host:-}" "${user:-}" "${port:-}" "${secret:-}" "${pass:-}" || { err "打标镜像失败: $src_ref -> $target_ref"; push_failed=true; continue; }
        push_image "$target_ref" "${host:-}" "${user:-}" "${port:-}" "${secret:-}" "${pass:-}" || { err "推送镜像失败: $target_ref"; push_failed=true; continue; }
        log "✅ 推送步骤完成: $target_ref (push_failed=$push_failed)"
        remove_image "$src_ref" "${host:-}" "${user:-}" "${port:-}" "${secret:-}" "${pass:-}" || true
        remove_image "$target_ref" "${host:-}" "${user:-}" "${port:-}" "${secret:-}" "${pass:-}" || true
        # 根据配置决定是否删除远程 tar 文件
        if [[ "${CLEANUP_REMOTE_TAR_AFTER_PUSH:-true}" == "true" ]]; then
          [[ -n "${remote_tar:-}" ]] && remove_file "$remote_tar" "${host:-}" "${user:-}" "${port:-}" "${secret:-}" "${pass:-}" || true
        else
          log "⏭️  保留远程 tar 文件: $(basename "$remote_tar") (CLEANUP_REMOTE_TAR_AFTER_PUSH=false)"
        fi
      done
      log "循环结束: processed_count=${processed_count}, push_failed=${push_failed}"
      # 如果有失败的推送，返回非零退出码
      if [[ "$push_failed" == "true" ]]; then
        err "push-from-dir: 检测到失败的推送操作（push_failed=true）"
        exit 1
      fi
      # 如果没有处理任何文件，也应该返回错误
      local file_count=0
      for tar in "${dir:-$LOCAL_IMAGE_DIR}"/*.tar "${dir:-$LOCAL_IMAGE_DIR}"/*.tar.gz; do
        [[ -e "$tar" ]] && file_count=$((file_count + 1))
      done
      if [[ $file_count -eq 0 ]]; then
        err "push-from-dir: 目录中没有找到任何 tar 文件: ${dir:-$LOCAL_IMAGE_DIR}"
        exit 1
      fi
      ;;
    help|-h|--help|*)
      usage
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
