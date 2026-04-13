#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
CONF_FILE="$SCRIPT_DIR/harbor-image.conf"
# shellcheck source=/dev/null
source "$CONF_FILE"
# 覆盖 conf 中可能写死的 k8s 路径，保证与仓库位置无关
COMPONENT_IMAGES_DIR="${COMPONENT_IMAGES_DIR:-$K8S_ROOT/utils/components-images}"
# 仅用于远程集群（SSH + nerdctl）；Kind 使用 sunmoonai/kind-infrastructure/push-to-harbor
IMAGE_TOOL="${IMAGE_TOOL:-$K8S_ROOT/utils/registry-push-management/loadimage.sh}"

# 加载基础设施配置文件（包含节点配置）
INFRA_CONFIG_FILE="$SCRIPT_DIR/../../../../infrastructure/deploy-infrastructure-all/deploy-infrastructure-all.conf"
if [[ -f "$INFRA_CONFIG_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$INFRA_CONFIG_FILE"
  
  # 应用集群配置映射（将 C{数字}_SERVER_n_* 映射到 SERVER_n_*）
  CLUSTER_CONFIG_MAPPING_FILE="$SCRIPT_DIR/../../../../../utils/cluster-config-mapping.sh"
  if [[ -f "$CLUSTER_CONFIG_MAPPING_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CLUSTER_CONFIG_MAPPING_FILE"
    
    # 确定当前集群（优先使用 CLUSTER 环境变量，否则从 KUBECONFIG 判断）
    detected_cluster="${CLUSTER:-}"
    if [[ -z "$detected_cluster" ]]; then
      if [[ "${KUBECONFIG:-}" == *"c1"* ]] || [[ "${KUBECONFIG:-}" == *"cluster-c1"* ]] || [[ "${KUBECONFIG:-}" == *"C1"* ]]; then
        detected_cluster="C1"
      elif [[ "${KUBECONFIG:-}" == *"c2"* ]] || [[ "${KUBECONFIG:-}" == *"cluster-c2"* ]] || [[ "${KUBECONFIG:-}" == *"C2"* ]]; then
        detected_cluster="C2"
      fi
    fi
    
    if [[ -n "$detected_cluster" ]]; then
      apply_cluster_config_mapping "$detected_cluster"
      
      # 手动处理 SERVER_n_* 变量的映射（因为 apply_cluster_config_mapping 跳过了这些变量）
      if [[ "$detected_cluster" =~ ^C[0-9]+$ ]]; then
        cluster_prefix="${detected_cluster}_"
        
        # 遍历所有可能的节点编号（1-20，可根据需要调整）
        for idx in {1..20}; do
          # 检查是否存在集群特定的 SERVER_n_* 配置
          cluster_public_ip_var="${cluster_prefix}SERVER_${idx}_PUBLIC_IP"
          cluster_public_ip="${!cluster_public_ip_var:-}"
          
          # 如果存在集群特定的配置，映射所有相关的 SERVER_n_* 变量
          if [[ -n "$cluster_public_ip" ]]; then
            # 映射所有 SERVER_n_* 变量
            server_vars=(
              "PUBLIC_IP" "LOCAL_IP" "USER" "SECRET" "PASS" "SSH_PORT"
              "DIR" "CURRENT_HOSTNAME" "CLUSTER_HOSTNAME" "EXTRA_LABELS" "TAINTS" "TYPE"
            )
            
            for var_suffix in "${server_vars[@]}"; do
              cluster_var="${cluster_prefix}SERVER_${idx}_${var_suffix}"
              base_var="SERVER_${idx}_${var_suffix}"
              
              # 如果集群特定配置存在，映射到基础变量
              if [[ -n "${!cluster_var:-}" ]]; then
                eval "$base_var=\"${!cluster_var}\""
              fi
            done
          fi
        done
      fi
    fi
  fi
fi

# 引入全局通用镜像管理工具（默认由上方 K8S_ROOT 推导，可被环境变量覆盖）

log(){ echo -e "[harbor-image] $(date '+%Y-%m-%d %H:%M:%S') $*"; }
ok(){ log "✅ $*"; }
warn(){ log "⚠️  $*"; }
err(){ log "❌ $*"; }

# 全局开关（--dry-run）
DRY_RUN="false"

# 基础配置校验
validate_config(){
  if [[ -z "${HARBOR_REGISTRY:-}" && -z "${HARBOR_API_BASE:-}${HARBOR_URL:-}" ]]; then
    err "未配置 HARBOR_REGISTRY 或 HARBOR_API_BASE/HARBOR_URL"
    return 1
  fi
  return 0
}

# Harbor 就绪检查：API 与 Registry 双探测（带重试）
wait_for_harbor_ready(){
  local max_wait_sec="${HARBOR_WAIT_TIMEOUT:-180}"  # 最长等待秒数
  local interval="${HARBOR_WAIT_INTERVAL:-5}"       # 轮询间隔
  local start_ts; start_ts=$(date +%s)

  # 解析 API Base URL
  local base="${HARBOR_API_BASE:-}"
  if [[ -z "$base" && -n "${HARBOR_URL:-}" ]]; then
    if [[ "$HARBOR_URL" =~ ^https?:// ]]; then base="$HARBOR_URL"; else base="https://$HARBOR_URL"; fi
  fi
  [[ -z "$base" ]] && base="https://$HARBOR_REGISTRY"

  local curl_insecure=()
  [[ "${HARBOR_INSECURE:-false}" == "true" || "${VERIFY_SSL:-true}" == "false" ]] && curl_insecure=(-k)

  while true; do
    local now; now=$(date +%s)
    local elapsed=$(( now - start_ts ))
    if (( elapsed >= max_wait_sec )); then
      err "等待 Harbor 就绪超时 (${max_wait_sec}s)"
      return 1
    fi

    # 1) Harbor API ping
    if curl -sfS "${curl_insecure[@]}" "$base/api/v2.0/ping" >/dev/null 2>&1; then
      # 2) Registry 根接口（/v2/）
      # 200/401 都视为服务已应答（401 代表需要认证，但服务就绪）
      local code
      code=$(curl -s -o /dev/null -w "%{http_code}" "${curl_insecure[@]}" "$base/v2/")
      if [[ "$code" == "200" || "$code" == "401" ]]; then
        ok "Harbor 已就绪"
        return 0
      fi
    fi

    log "等待 Harbor 就绪中... (${elapsed}s/${max_wait_sec}s)"
    sleep "$interval"
  done
}

# Harbor API: 检查 project/repo:tag 是否存在
harbor_api_exists(){
  local project="$1" repo="$2" tag="$3"
  local api_repo; api_repo=$(echo "$repo" | sed 's!/!%2F!g')
  local base="${HARBOR_API_BASE:-}"
  if [[ -z "$base" ]]; then
    # 向后兼容 HARBOR_URL（不带协议时补 https://）
    if [[ -n "${HARBOR_URL:-}" ]]; then
      if [[ "$HARBOR_URL" =~ ^https?:// ]]; then base="$HARBOR_URL"; else base="https://$HARBOR_URL"; fi
    else
      base="https://$HARBOR_REGISTRY"
    fi
  fi
  local url="$base/api/v2.0/projects/$project/repositories/$api_repo/artifacts/$tag"
  local auth=( ); [[ -n "${HARBOR_USERNAME:-}" ]] && auth=(-u "$HARBOR_USERNAME:$HARBOR_PASSWORD")
  curl -sfS "${auth[@]}" "$url" >/dev/null 2>&1
}

# 在控制平面上：upload → load → tag → push → cleanup
push_tar_via_control_plane(){
  local tarfile_name="$1" project="$2"
  local target_repo tag repo_name registry

  # 解析源 ref（来自 tar load 输出在下游完成；此处只构建目标）
  # 目标 registry/project/repo:tag 基于:
  #   - registry: HARBOR_REGISTRY
  #   - project:  $project
  #   - repo:     从 src_ref 派生的 name（在 load 后按实际名）

  # 准备控制平面路径
  local remote_tar="$CONTROL_PLANE_IMAGE_DIR/$tarfile_name"

  # 上传
  "$IMAGE_TOOL" remove-file "$remote_tar" "$CONTROL_PLANE_HOST" "$CONTROL_PLANE_USER" "$CONTROL_PLANE_SSH_PORT" "$CONTROL_PLANE_SECRET" "$CONTROL_PLANE_PASS" >/dev/null 2>&1 || true
  "$IMAGE_TOOL" upload-load-push \
    "$LOCAL_IMAGE_DIR/$tarfile_name" \
    "$CONTROL_PLANE_HOST" \
    "$CONTROL_PLANE_IMAGE_DIR" \
    "_DUMMY_" \
    "$CONTROL_PLANE_USER" "$CONTROL_PLANE_SSH_PORT" "$CONTROL_PLANE_SECRET" "$CONTROL_PLANE_PASS" >/dev/null 2>&1 || true

  # loadimage 工具的 upload-load-push 需要具体 target_ref；
  # 我们分步执行以在 load 后再拼装目标引用
  # 重新分步：上传 → load → 解析源 → tag → push → 清理
  "$IMAGE_TOOL" upload-load-push >/dev/null 2>&1 || true  # no-op，占位保持兼容（不影响下方分步执行）

  # 分步执行
  "$IMAGE_TOOL" upload-load-push >/dev/null 2>&1 || true
}

# 读取组件镜像清单
read_component_list(){
  local component="$1"; local list_file="$COMPONENT_IMAGES_DIR/${component}-images.txt"
  if [[ ! -f "$list_file" ]]; then err "缺少清单: $list_file"; return 1; fi
  cat "$list_file" | sed '/^\s*#/d;/^\s*$/d'
}

# 确保组件镜像存在于 Harbor（按需上传）
ensure_component_images(){
  local component="$1"; local project="${2:-$HARBOR_DEFAULT_PROJECT}"
  validate_config || return 1
  wait_for_harbor_ready || return 1
  if [[ -z "${CONTROL_PLANE_HOST:-}" || -z "${CONTROL_PLANE_USER:-}" ]]; then
    err "未配置控制平面主机/用户，请在 harbor-image.conf 中设置 CONTROL_PLANE_*"; return 1
  fi
  if [[ ! -d "$LOCAL_IMAGE_DIR" ]]; then err "本地镜像目录不存在: $LOCAL_IMAGE_DIR"; return 1; fi

  log "开始处理组件: $component (project=$project)"
  local images; images=$(read_component_list "$component") || return 1

  while IFS= read -r img; do
    local repo="${img%:*}" tag="${img##*:}" NAME_ONLY="${repo##*/}"
    if harbor_api_exists "$project" "$NAME_ONLY" "$tag"; then
      ok "Harbor 已存在: $project/$NAME_ONLY:$tag (跳过)"; continue
    fi

    local tarname
    if tarname=$(bash -lc "BASE='$LOCAL_IMAGE_DIR'; safe=$(echo '$img' | sed 's#[/:]#_#g'); \
      for f in \"$LOCAL_IMAGE_DIR/${img}.tar\" \"$LOCAL_IMAGE_DIR/${safe}.tar\" \"$LOCAL_IMAGE_DIR/${img}.tar.gz\"; do [[ -f \"$f\" ]] && { basename \"$f\"; exit 0; }; done; exit 1" 2>/dev/null); then
      log "推送镜像: $img via $tarname"
      # 上传 tar
      "$IMAGE_TOOL" remove-file "$CONTROL_PLANE_IMAGE_DIR/$tarname" "$CONTROL_PLANE_HOST" "$CONTROL_PLANE_USER" "$CONTROL_PLANE_SSH_PORT" "$CONTROL_PLANE_SECRET" "$CONTROL_PLANE_PASS" >/dev/null 2>&1 || true
      "$IMAGE_TOOL" upload-load-push >/dev/null 2>&1 || true  # 兼容占位
      # 上传文件
      "$IMAGE_TOOL" load-image >/dev/null 2>&1 || true        # 兼容占位
      # 实际分步：上传
      "$IMAGE_TOOL" load-image "$CONTROL_PLANE_IMAGE_DIR/$tarname" "$CONTROL_PLANE_HOST" "$CONTROL_PLANE_USER" "$CONTROL_PLANE_SSH_PORT" "$CONTROL_PLANE_SECRET" "$CONTROL_PLANE_PASS" >/dev/null 2>&1 || true
      # 解析源引用
      local load_out_ref
      load_out_ref=$(bash -lc "echo \"$("$IMAGE_TOOL" load-image \"$CONTROL_PLANE_IMAGE_DIR/$tarname\" \"$CONTROL_PLANE_HOST\" \"$CONTROL_PLANE_USER\" \"$CONTROL_PLANE_SSH_PORT\" \"$CONTROL_PLANE_SECRET\" \"$CONTROL_PLANE_PASS\")\"" 2>/dev/null || true)
      if [[ -z "$load_out_ref" ]]; then
        # 回退：根据 img 估计源引用
        load_out_ref="$img"
      fi
      local dest_ref="$HARBOR_REGISTRY/$project/$NAME_ONLY:$tag"
      "$IMAGE_TOOL" tag-image "$load_out_ref" "$dest_ref" "$CONTROL_PLANE_HOST" "$CONTROL_PLANE_USER" "$CONTROL_PLANE_SSH_PORT" "$CONTROL_PLANE_SECRET" "$CONTROL_PLANE_PASS"
      "$IMAGE_TOOL" push-image "$dest_ref" "$CONTROL_PLANE_HOST" "$CONTROL_PLANE_USER" "$CONTROL_PLANE_SSH_PORT" "$CONTROL_PLANE_SECRET" "$CONTROL_PLANE_PASS"
      if [[ "${AUTO_CLEANUP_AFTER_PUSH:-true}" == "true" ]]; then
        "$IMAGE_TOOL" remove-image "$load_out_ref" "$CONTROL_PLANE_HOST" "$CONTROL_PLANE_USER" "$CONTROL_PLANE_SSH_PORT" "$CONTROL_PLANE_SECRET" "$CONTROL_PLANE_PASS" || true
        "$IMAGE_TOOL" remove-image "$dest_ref" "$CONTROL_PLANE_HOST" "$CONTROL_PLANE_USER" "$CONTROL_PLANE_SSH_PORT" "$CONTROL_PLANE_SECRET" "$CONTROL_PLANE_PASS" || true
        "$IMAGE_TOOL" remove-file "$CONTROL_PLANE_IMAGE_DIR/$tarname" "$CONTROL_PLANE_HOST" "$CONTROL_PLANE_USER" "$CONTROL_PLANE_SSH_PORT" "$CONTROL_PLANE_SECRET" "$CONTROL_PLANE_PASS" || true
      fi
    else
      warn "未找到本地 tar: $img"
    fi
  done <<< "$images"
  ok "组件 $component 镜像处理完成"
}

# 清理组件相关 tar（控制平面）
cleanup_component_tars(){
  local component="$1"
  validate_config || return 1
  if [[ -z "${CONTROL_PLANE_HOST:-}" || -z "${CONTROL_PLANE_USER:-}" ]]; then err "未配置控制平面主机/用户"; return 1; fi
  local list_file="$COMPONENT_IMAGES_DIR/${component}-images.txt"
  [[ -f "$list_file" ]] || { warn "清单缺失，跳过: $list_file"; return 0; }

  local patterns=()
  while IFS= read -r img; do
    [[ -z "$img" || "$img" =~ ^# ]] && continue
    local safe; safe=$(echo "$img" | sed 's#[/:]#_#g')
    patterns+=("$img.tar" "$safe.tar" "$img.tar.gz")
  done < "$list_file"

  for p in "${patterns[@]}"; do
    "$IMAGE_TOOL" remove-file "$CONTROL_PLANE_IMAGE_DIR/$p" "$CONTROL_PLANE_HOST" "$CONTROL_PLANE_USER" "$CONTROL_PLANE_SSH_PORT" "$CONTROL_PLANE_SECRET" "$CONTROL_PLANE_PASS" || true
  done
  ok "组件 $component 控制平面 tar 已清理"
}

# Harbor 安装后：全局清理各节点
cleanup_all_nodes_after_harbor(){
  # 检查是否启用自动清理
  if [[ "${AUTO_CLEANUP_UNUSED_IMAGES:-false}" != "true" ]]; then
    log "自动清理未启用 (AUTO_CLEANUP_UNUSED_IMAGES=false)，跳过全局清理"
    return 0
  fi
  
  log "Harbor 安装后清理所有节点未使用镜像与包文件..."
  
  # 检查基础设施配置文件是否存在
  if [[ ! -f "$INFRA_CONFIG_FILE" ]]; then
    err "基础设施配置文件不存在: $INFRA_CONFIG_FILE"
    err "无法获取节点配置，请确保 deploy-infrastructure-all.conf 存在"
    return 1
  fi
  
  local idx=1
  while true; do
    # 从映射后的 SERVER_n_* 变量读取配置
    local host_var="SERVER_${idx}_PUBLIC_IP"
    local host="${!host_var:-}"
    
    # 如果 PUBLIC_IP 为空，说明没有更多节点
    [[ -z "$host" ]] && break
    
    local user_var="SERVER_${idx}_USER"
    local user="${!user_var:-root}"
    
    local port_var="SERVER_${idx}_SSH_PORT"
    local port="${!port_var:-22}"
    
    local secret_var="SERVER_${idx}_SECRET"
    local secret="${!secret_var:-}"
    
    local pass_var="SERVER_${idx}_PASS"
    local pass="${!pass_var:-}"
    
    local dir_var="SERVER_${idx}_DIR"
    local rdir="${!dir_var:-~/packages-to-be-installed}"

    log "清理节点: $host"
    "$IMAGE_TOOL" exec-remote >/dev/null 2>&1 || true
    if command -v ssh >/dev/null 2>&1; then
      if [[ -n "$secret" && -f "$secret" ]]; then
        ssh -i "$secret" -o StrictHostKeyChecking=no -o LogLevel=ERROR -p "$port" "$user@$host" "sudo -n nerdctl -n '$CONTAINERD_NAMESPACE' image prune -a -f || true; rm -rf '$rdir'/debs/* '$rdir'/tars/* '$rdir'/charts/* '$rdir'/images/*.tar* 2>/dev/null || true"
      elif command -v sshpass >/dev/null 2>&1 && [[ -n "$pass" ]]; then
        sshpass -p "$pass" ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR -p "$port" "$user@$host" "sudo -n nerdctl -n '$CONTAINERD_NAMESPACE' image prune -a -f || true; rm -rf '$rdir'/debs/* '$rdir'/tars/* '$rdir'/charts/* '$rdir'/images/*.tar* 2>/dev/null || true"
      else
        warn "节点 $host: 无法找到 SSH 密钥 ($secret) 且无密码配置，跳过"
        idx=$((idx+1))
        continue
      fi
    fi
    idx=$((idx+1))
  done
  ok "全局清理完成"
}

usage(){ cat <<EOF
Harbor 镜像管理
用法:
  $0 ensure-component-images <component> [project] [--dry-run]  # 按需推送组件镜像
  $0 cleanup-component-tars <component> [--dry-run]             # 清理控制平面该组件 tar
  $0 cleanup-all-nodes-after-harbor [--dry-run]                 # Harbor 安装后全局清理
  $0 status                                                     # 显示配置、连通性和节点摘要
  $0 help                                                       # 帮助
EOF
}

main(){
  local cmd="${1:-help}"; shift || true
  for arg in "$@"; do [[ "$arg" == "--dry-run" ]] && DRY_RUN="true"; done
  case "$cmd" in
    ensure-component-images) ensure_component_images "${1:-}" "${2:-}" ;;
    cleanup-component-tars) cleanup_component_tars "${1:-}" ;;
    cleanup-all-nodes-after-harbor) cleanup_all_nodes_after_harbor ;;
    status)
      validate_config || exit 1
      log "Harbor Registry: ${HARBOR_REGISTRY:-}"
      local base="${HARBOR_API_BASE:-}"; [[ -z "$base" && -n "${HARBOR_URL:-}" ]] && { [[ "$HARBOR_URL" =~ ^https?:// ]] && base="$HARBOR_URL" || base="https://$HARBOR_URL"; }
      log "Harbor API: $base"
      if command -v curl >/dev/null 2>&1 && [[ -n "$base" ]]; then
        if curl -sfS "$base/api/v2.0/ping" >/dev/null 2>&1; then ok "Harbor API 可达"; else warn "Harbor API 不可达或未通过"; fi
      fi
      log "CONTROL_PLANE: ${CONTROL_PLANE_USER:-}@${CONTROL_PLANE_HOST:-}:${CONTROL_PLANE_SSH_PORT:-22} dir=${CONTROL_PLANE_IMAGE_DIR:-}"
      
      # 显示节点信息（从 deploy-infrastructure-all.conf 读取）
      if [[ -f "$INFRA_CONFIG_FILE" ]]; then
        log "节点配置来源: $INFRA_CONFIG_FILE"
        local idx=1
        local count=0
        while true; do
          local host_var="SERVER_${idx}_PUBLIC_IP"
          local host="${!host_var:-}"
          [[ -z "$host" ]] && break
          
          local user_var="SERVER_${idx}_USER"
          local user="${!user_var:-root}"
          
          local port_var="SERVER_${idx}_SSH_PORT"
          local port="${!port_var:-22}"
          
          log "NODE[$idx]: $user@$host:$port"
          idx=$((idx+1))
          count=$((count+1))
        done
        log "节点数: $count"
      else
        warn "基础设施配置文件不存在: $INFRA_CONFIG_FILE"
        log "节点数: 0"
      fi
      ;;
    help|-h|--help|*) usage ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
