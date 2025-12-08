#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Infrastructure 包同步脚本
# =============================================================================
# 用途：基础设施安装前的包文件同步和安装后的清理
# - 同步 debs, images, tars, charts 到所有节点
# - 节点安装后清理包文件

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_FILE="$SCRIPT_DIR/package-sync.conf"
# shellcheck source=/dev/null
source "$CONF_FILE"

# 日志函数（需要在集群配置映射之前定义，以便在映射时可以使用）
log() { echo -e "[package-sync] $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_info() { log "ℹ️  $*"; }
log_success() { log "✅ $*"; }
log_warn() { log "⚠️  $*"; }
log_error() { log "❌ $*"; }

# 计算 k8s 根目录
# package-preparation/ -> utils/ -> infrastructure/ -> sunmoonai/ -> k8s/
# 尝试多个可能的路径
K8S_ROOT=""
if [[ -f "$HOME/k8s/utils/cluster-config-mapping.sh" ]]; then
    K8S_ROOT="$HOME/k8s"
elif [[ -f "$SCRIPT_DIR/../../../../utils/cluster-config-mapping.sh" ]]; then
    K8S_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
elif [[ -f "$SCRIPT_DIR/../../../utils/cluster-config-mapping.sh" ]]; then
    K8S_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
else
    # 默认尝试从 package-preparation 向上找到 k8s 目录
    K8S_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

# 加载集群配置映射函数（用于将 C1_* 或 C2_* 映射为默认配置）
if [[ -f "$K8S_ROOT/utils/cluster-config-mapping.sh" ]]; then
    source "$K8S_ROOT/utils/cluster-config-mapping.sh"
    # 应用集群配置映射（使用 CLUSTER 环境变量）
    if command -v apply_cluster_config_mapping &>/dev/null; then
        apply_cluster_config_mapping
        if [[ -n "${CLUSTER:-}" ]]; then
            log_info "应用集群配置: CLUSTER=${CLUSTER}"
        fi
    fi
    
    # 手动映射 SERVER_n_* 变量（因为 apply_cluster_config_mapping 跳过了这些变量）
    if [[ -n "${CLUSTER:-}" ]] && [[ "$CLUSTER" =~ ^C[0-9]+$ ]]; then
        cluster_prefix="${CLUSTER}_"
        server_num=1
        while true; do
            cluster_pub_ip_var="${cluster_prefix}SERVER_${server_num}_PUBLIC_IP"
            if [[ -z "${!cluster_pub_ip_var:-}" ]]; then
                break
            fi
            
            # 映射所有 SERVER_n_* 字段
            fields=("TYPE" "PUBLIC_IP" "LOCAL_IP" "USER" "SECRET" "PASS" "SSH_PORT" "DIR" 
                    "CURRENT_HOSTNAME" "CLUSTER_HOSTNAME" "EXTRA_LABELS" "TAINTS")
            for field in "${fields[@]}"; do
                cluster_var="${cluster_prefix}SERVER_${server_num}_${field}"
                server_var="SERVER_${server_num}_${field}"
                if [[ -n "${!cluster_var:-}" ]]; then
                    eval "$server_var=\"${!cluster_var}\""
                fi
            done
            
            server_num=$((server_num+1))
        done
        log_info "已映射 ${CLUSTER} 集群的 $((server_num-1)) 个节点配置"
    fi
fi

# 全局开关（--dry-run）
DRY_RUN="false"

# 基础配置校验
validate_config() {
    local servers
    mapfile -t servers < <(list_servers)
    if [[ ${#servers[@]} -eq 0 ]]; then
        log_error "未在 package-sync.conf 中配置任何 SERVER_*_PUBLIC_IP；请至少配置一个节点"
        return 1
    fi
    # 校验每个节点的必要字段
    for idx in "${servers[@]}"; do
        IFS='|' read -r host user port secret pass rdir <<< "$(get_server_info "$idx")"
        if [[ -z "$host" || -z "$user" ]]; then
            log_error "SERVER_${idx}_PUBLIC_IP 或 SERVER_${idx}_USER 缺失"
            return 1
        fi
    done
    # 校验本地目录存在
    [[ -d "$LOCAL_PACKAGE_DIR" ]] || log_warn "本地包目录不存在：$LOCAL_PACKAGE_DIR"
    return 0
}

# 列出所有服务器
list_servers() {
    local idx=1
    while true; do
        local pub_ip_var="SERVER_${idx}_PUBLIC_IP"
        local host_ip="${!pub_ip_var:-}"
        [[ -z "$host_ip" ]] && break
        echo "$idx"
        idx=$((idx+1))
    done
}

# 获取服务器信息
get_server_info() {
    local idx="$1"
    local host_var="SERVER_${idx}_PUBLIC_IP"
    local user_var="SERVER_${idx}_USER"
    local port_var="SERVER_${idx}_SSH_PORT"
    local secret_var="SERVER_${idx}_SECRET"
    local pass_var="SERVER_${idx}_PASS"
    local dir_var="SERVER_${idx}_DIR"
    
    local host="${!host_var:-}"
    local user="${!user_var:-}"
    local port="${!port_var:-22}"
    local secret="${!secret_var:-}"
    local pass="${!pass_var:-}"
    local rdir="${!dir_var:-$REMOTE_PACKAGE_DIR}"
    
    # 展开 ~ 路径
    rdir=$(eval echo "$rdir")
    
    echo "$host|$user|$port|$secret|$pass|$rdir"
}

# rsync 全量同步
rsync_full() {
    local src="$1" dst_host="$2" dst_user="$3" dst_port="$4" dst_path="$5" secret="$6" pass="$7"
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[dry-run] rsync_full: $src -> $dst_user@$dst_host:$dst_path"
        return 0
    fi
    
    if command -v rsync >/dev/null 2>&1; then
        if [[ -n "$secret" && -f "$secret" ]]; then
            RSYNC_RSH="ssh -i $secret -o StrictHostKeyChecking=no -p $dst_port" \
                rsync -av --delete --mkpath "$src/" "$dst_user@$dst_host:$dst_path/" 2>/dev/null
            return $?
        elif [[ -n "$pass" ]]; then
            if command -v sshpass >/dev/null 2>&1; then
                RSYNC_RSH="sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $dst_port" \
                    rsync -av --delete --mkpath "$src/" "$dst_user@$dst_host:$dst_path/" 2>/dev/null
                return $?
            fi
        fi
    fi
    
    # fallback: scp
    if [[ -n "$secret" && -f "$secret" ]]; then
        ssh -i "$secret" -p "$dst_port" -o StrictHostKeyChecking=no "$dst_user@$dst_host" \
            "rm -rf '$dst_path' && mkdir -p '$dst_path'" 2>/dev/null || true
        scp -r -i "$secret" -P "$dst_port" -o StrictHostKeyChecking=no \
            "$src"/* "$dst_user@$dst_host:$dst_path/" 2>/dev/null || true
    elif [[ -n "$pass" ]] && command -v sshpass >/dev/null 2>&1; then
        sshpass -p "$pass" ssh -p "$dst_port" -o StrictHostKeyChecking=no "$dst_user@$dst_host" \
            "rm -rf '$dst_path' && mkdir -p '$dst_path'" 2>/dev/null || true
        sshpass -p "$pass" scp -r -P "$dst_port" -o StrictHostKeyChecking=no \
            "$src"/* "$dst_user@$dst_host:$dst_path/" 2>/dev/null || true
    fi
    return 0
}

# rsync 增量同步
rsync_incremental() {
    local src="$1" dst_host="$2" dst_user="$3" dst_port="$4" dst_path="$5" secret="$6" pass="$7"
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[dry-run] rsync_incremental: $src -> $dst_user@$dst_host:$dst_path"
        return 0
    fi
    
    if command -v rsync >/dev/null 2>&1; then
        if [[ -n "$secret" && -f "$secret" ]]; then
            RSYNC_RSH="ssh -i $secret -o StrictHostKeyChecking=no -p $dst_port" \
                rsync -av --mkpath "$src/" "$dst_user@$dst_host:$dst_path/" 2>/dev/null
            return $?
        elif [[ -n "$pass" ]]; then
            if command -v sshpass >/dev/null 2>&1; then
                RSYNC_RSH="sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $dst_port" \
                    rsync -av --mkpath "$src/" "$dst_user@$dst_host:$dst_path/" 2>/dev/null
                return $?
            fi
        fi
    fi
    
    # fallback: scp
    if [[ -n "$secret" && -f "$secret" ]]; then
        ssh -i "$secret" -p "$dst_port" -o StrictHostKeyChecking=no "$dst_user@$dst_host" \
            "mkdir -p '$dst_path'" 2>/dev/null || true
        scp -r -i "$secret" -P "$dst_port" -o StrictHostKeyChecking=no \
            "$src"/* "$dst_user@$dst_host:$dst_path/" 2>/dev/null || true
    elif [[ -n "$pass" ]] && command -v sshpass >/dev/null 2>&1; then
        sshpass -p "$pass" ssh -p "$dst_port" -o StrictHostKeyChecking=no "$dst_user@$dst_host" \
            "mkdir -p '$dst_path'" 2>/dev/null || true
        sshpass -p "$pass" scp -r -P "$dst_port" -o StrictHostKeyChecking=no \
            "$src"/* "$dst_user@$dst_host:$dst_path/" 2>/dev/null || true
    fi
    return 0
}

# 同步包到单个节点
sync_to_node() {
    local node_idx="$1"
    local sync_type="${2:-all}"  # all, debs, images, tars, charts
    
    local server_info
    server_info=$(get_server_info "$node_idx")
    IFS='|' read -r host user port secret pass rdir <<< "$server_info"
    
    if [[ -z "$host" ]]; then
        log_error "服务器 $node_idx 配置不存在"
        return 1
    fi
    
    log_info "同步到节点: $host ($user@$host:$port)"
    
    # 同步 debs
    if [[ "$sync_type" == "all" || "$sync_type" == "debs" ]]; then
        if [[ -d "$LOCAL_DEBS_DIR" ]] && [[ -n "$(ls -A "$LOCAL_DEBS_DIR" 2>/dev/null)" ]]; then
            log_info "  同步 debs..."
            rsync_full "$LOCAL_DEBS_DIR" "$host" "$user" "$port" "$rdir/debs" "$secret" "$pass"
            log_success "  debs 同步完成"
        else
            log_info "  跳过 debs（目录不存在或为空）"
        fi
    fi
    
    # 同步 images
    if [[ "$sync_type" == "all" || "$sync_type" == "images" ]]; then
        if [[ -d "$LOCAL_IMAGES_DIR" ]] && [[ -n "$(ls -A "$LOCAL_IMAGES_DIR" 2>/dev/null)" ]]; then
            log_info "  同步 images..."
            rsync_full "$LOCAL_IMAGES_DIR" "$host" "$user" "$port" "$rdir/images" "$secret" "$pass"
            log_success "  images 同步完成"
        else
            log_info "  跳过 images（目录不存在或为空）"
        fi
    fi
    
    # 同步 tars
    if [[ "$sync_type" == "all" || "$sync_type" == "tars" ]]; then
        if [[ -d "$LOCAL_TARS_DIR" ]] && [[ -n "$(ls -A "$LOCAL_TARS_DIR" 2>/dev/null)" ]]; then
            log_info "  同步 tars..."
            rsync_full "$LOCAL_TARS_DIR" "$host" "$user" "$port" "$rdir/tars" "$secret" "$pass"
            log_success "  tars 同步完成"
        else
            log_info "  跳过 tars（目录不存在或为空）"
        fi
    fi
    
    # 同步 charts
    if [[ "$sync_type" == "all" || "$sync_type" == "charts" ]]; then
        if [[ -d "$LOCAL_CHARTS_DIR" ]] && [[ -n "$(ls -A "$LOCAL_CHARTS_DIR" 2>/dev/null)" ]]; then
            log_info "  同步 charts..."
            rsync_full "$LOCAL_CHARTS_DIR" "$host" "$user" "$port" "$rdir/charts" "$secret" "$pass"
            log_success "  charts 同步完成"
        else
            log_info "  跳过 charts（目录不存在或为空）"
        fi
    fi
    
    log_success "节点 $host 同步完成"
    return 0
}

# 同步包到所有节点
sync_packages_to_all_nodes() {
    local sync_type="${1:-all}"
    
    log_info "开始同步包文件到所有节点（类型: $sync_type）..."
    
    local servers
    mapfile -t servers < <(list_servers)
    
    if [[ ${#servers[@]} -eq 0 ]]; then
        log_error "未配置任何服务器节点"
        return 1
    fi
    
    log_info "找到 ${#servers[@]} 个节点"
    
    for idx in "${servers[@]}"; do
        if ! sync_to_node "$idx" "$sync_type"; then
            log_error "节点 $idx 同步失败"
            return 1
        fi
    done
    
    log_success "所有节点同步完成"
    return 0
}

# 清理节点包文件
cleanup_node_packages() {
    local node_ip="$1"
    local node_user="${2:-}"
    local node_port="${3:-22}"
    local cleanup_type="${4:-all}"  # all, debs, tars, charts
    
    log_info "清理节点包文件: $node_ip (类型: $cleanup_type)"
    
    # 查找节点索引
    local node_idx=0
    for idx in $(list_servers); do
        local host_var="SERVER_${idx}_PUBLIC_IP"
        if [[ "${!host_var:-}" == "$node_ip" ]]; then
            node_idx=$idx
            break
        fi
    done
    
    if [[ $node_idx -eq 0 ]]; then
        log_warn "未找到节点配置，使用提供的参数"
        local secret=""
        local pass=""
        local rdir="$REMOTE_PACKAGE_DIR"
    else
        local server_info
        server_info=$(get_server_info "$node_idx")
        IFS='|' read -r host user port secret pass rdir <<< "$server_info"
        [[ -z "$node_user" ]] && node_user="$user"
        [[ -z "$node_port" ]] && node_port="$port"
    fi
    
    # 构建清理命令
    local cleanup_cmd=""
    if [[ "$cleanup_type" == "all" ]]; then
        cleanup_cmd="rm -rf $rdir/debs/* $rdir/tars/* $rdir/charts/* 2>/dev/null || true"
    else
        [[ "$cleanup_type" == "debs" ]] && cleanup_cmd="rm -rf $rdir/debs/* 2>/dev/null || true"
        [[ "$cleanup_type" == "tars" ]] && cleanup_cmd="rm -rf $rdir/tars/* 2>/dev/null || true"
        [[ "$cleanup_type" == "charts" ]] && cleanup_cmd="rm -rf $rdir/charts/* 2>/dev/null || true"
    fi
    
    # 执行清理
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[dry-run] ssh $node_user@$node_ip: $cleanup_cmd"
        log_success "节点 $node_ip 清理完成（dry-run）"
        return 0
    fi
    if [[ -n "$secret" && -f "$secret" ]]; then
        ssh -i "$secret" -p "$node_port" -o StrictHostKeyChecking=no "$node_user@$node_ip" "$cleanup_cmd"
    elif [[ -n "$pass" ]] && command -v sshpass >/dev/null 2>&1; then
        sshpass -p "$pass" ssh -p "$node_port" -o StrictHostKeyChecking=no "$node_user@$node_ip" "$cleanup_cmd"
    else
        log_warn "无法清理节点（缺少认证信息）"
        return 1
    fi
    
    log_success "节点 $node_ip 清理完成"
    return 0
}

# 使用说明
usage() {
    cat <<EOF
Infrastructure 包同步工具

用法:
  $0 sync-packages-to-all-nodes [type] [--dry-run]    # 同步包到所有节点（all|debs|images|tars|charts）
  $0 sync-images-to-all-nodes [--dry-run]             # 兼容别名，同步 images 到所有节点
  $0 install-images-on-all-nodes [--dry-run]          # 在所有节点安装 images 目录下的所有镜像到 k8s.io
  $0 cleanup-node-packages <ip> [user] [port] [type] [--dry-run]  # 清理单节点包文件
  $0 cleanup-packages-on-all-nodes [type] [--dry-run] # 清理所有节点包文件（all|debs|tars|charts）
  $0 status                                           # 显示配置与节点摘要

示例:
  $0 sync-packages-to-all-nodes              # 同步所有类型的包
  $0 sync-packages-to-all-nodes images       # 仅同步镜像包
  $0 cleanup-node-packages 192.168.1.10     # 清理节点所有包文件
  $0 cleanup-node-packages 192.168.1.10 zym 1022 debs  # 清理节点 deb 包
  $0 sync-packages-to-all-nodes images --dry-run       # 以 dry-run 模式查看同步计划

EOF
}

# 在单个节点安装 images 目录下的所有镜像（加载到 k8s.io 命名空间）
install_images_on_node() {
    local node_idx="$1"

    local server_info
    server_info=$(get_server_info "$node_idx")
    IFS='|' read -r host user port secret pass rdir <<< "$server_info"

    if [[ -z "$host" ]]; then
        log_error "服务器 $node_idx 配置不存在"
        return 1
    fi

    local images_dir="$rdir/images"
    log_info "在节点安装镜像: $host ($images_dir)"

    # 统计 tar 数量
    local count_cmd="find '$images_dir' -maxdepth 1 -type f -name '*.tar' 2>/dev/null | wc -l"
    local tar_count="0"
    if [[ -n "$secret" && -f "$secret" ]]; then
        tar_count=$(ssh -i "$secret" -p "$port" -o StrictHostKeyChecking=no "$user@$host" "$count_cmd" 2>/dev/null || echo 0)
    elif [[ -n "$pass" ]] && command -v sshpass >/dev/null 2>&1; then
        tar_count=$(sshpass -p "$pass" ssh -p "$port" -o StrictHostKeyChecking=no "$user@$host" "$count_cmd" 2>/dev/null || echo 0)
    else
        log_warn "无法连接节点（缺少认证信息）: $host"; return 1
    fi

    if [[ "${tar_count// /}" == "0" ]]; then
        log_warn "节点 $host: 未找到任何 .tar 镜像文件"
        return 0
    fi

    # 获取 tar 列表
    local list_cmd="find '$images_dir' -maxdepth 1 -type f -name '*.tar' -printf '%p\n' 2>/dev/null | sort"
    local tar_list
    if [[ -n "$secret" && -f "$secret" ]]; then
        tar_list=$(ssh -i "$secret" -p "$port" -o StrictHostKeyChecking=no "$user@$host" "$list_cmd" 2>/dev/null || true)
    else
        tar_list=$(sshpass -p "$pass" ssh -p "$port" -o StrictHostKeyChecking=no "$user@$host" "$list_cmd" 2>/dev/null || true)
    fi

    local loaded=0 failed=0 skipped=0 idx=0
    while IFS= read -r tar_file; do
        [[ -z "$tar_file" ]] && continue
        idx=$((idx+1))
        local base
        base=$(basename "$tar_file")
        log_info "  [$idx/$tar_count] 加载: $base"

        # 解析 tar 内的 manifest.json 获取 RepoTags（优先使用 jq；无 jq 则用 grep/sed 简单解析）
        local parse_cmd="if command -v jq >/dev/null 2>&1; then tar -xOf '$tar_file' manifest.json 2>/dev/null | jq -r '.[0].RepoTags[]'; else tar -xOf '$tar_file' manifest.json 2>/dev/null | sed -n 's/.*\"RepoTags\"\s*:\s*\[\s*\"\([^\"]*\)\".*/\1/p' ; fi"
        local repotags
        if [[ -n "$secret" && -f "$secret" ]]; then
            repotags=$(ssh -i "$secret" -p "$port" -o StrictHostKeyChecking=no "$user@$host" "$parse_cmd" 2>/dev/null || echo "")
        else
            repotags=$(sshpass -p "$pass" ssh -p "$port" -o StrictHostKeyChecking=no "$user@$host" "$parse_cmd" 2>/dev/null || echo "")
        fi

        local should_skip="false"
        if [[ -n "$repotags" ]]; then
            # 若任意一个 tag 已存在于 k8s.io，则认为该 tar 可跳过
            while IFS= read -r tag; do
                [[ -z "$tag" ]] && continue
                local exists_cmd="sudo nerdctl -n k8s.io images --format '{{.Repository}}:{{.Tag}}' | grep -Fx '$tag' >/dev/null 2>&1"
                if [[ -n "$secret" && -f "$secret" ]]; then
                    if ssh -i "$secret" -p "$port" -o StrictHostKeyChecking=no "$user@$host" "$exists_cmd"; then should_skip="true"; break; fi
                else
                    if sshpass -p "$pass" ssh -p "$port" -o StrictHostKeyChecking=no "$user@$host" "$exists_cmd"; then should_skip="true"; break; fi
                fi
            done <<< "$repotags"
        fi

        if [[ "$should_skip" == "true" ]]; then
            log_info "  已存在（按 RepoTags 判断），跳过: $base"
            skipped=$((skipped+1))
            continue
        fi

        local load_cmd="sudo nerdctl -n k8s.io load -i '$tar_file'"
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "  [dry-run] $load_cmd"
            continue
        fi

        if [[ -n "$secret" && -f "$secret" ]]; then
            if ssh -i "$secret" -p "$port" -o StrictHostKeyChecking=no "$user@$host" "$load_cmd"; then
                loaded=$((loaded+1))
            else
                failed=$((failed+1))
                log_warn "  加载失败: $base"
            fi
        else
            if sshpass -p "$pass" ssh -p "$port" -o StrictHostKeyChecking=no "$user@$host" "$load_cmd"; then
                loaded=$((loaded+1))
            else
                failed=$((failed+1))
                log_warn "  加载失败: $base"
            fi
        fi
    done <<< "$tar_list"

    log_success "节点 $host 加载完成: 成功 $loaded, 跳过 $skipped, 失败 $failed, 共 $tar_count"
    [[ $failed -eq 0 ]]
}

# 在所有节点安装 images 目录下的所有镜像
install_images_on_all_nodes() {
    log_info "开始在所有节点安装 images 下的镜像..."
    local servers
    mapfile -t servers < <(list_servers)
    if [[ ${#servers[@]} -eq 0 ]]; then
        log_error "未配置任何服务器节点"
        return 1
    fi
    local any_failed=0
    for idx in "${servers[@]}"; do
        install_images_on_node "$idx" || any_failed=1
    done
    if [[ $any_failed -eq 0 ]]; then
        log_success "所有节点镜像安装完成"
        return 0
    else
        log_warn "部分节点镜像安装失败"
        return 1
    fi
}

# 主函数
main() {
    local cmd="${1:-}"
    shift || true
    # 解析可选的 --dry-run
    for arg in "$@"; do
        [[ "$arg" == "--dry-run" ]] && DRY_RUN="true"
    done
    case "$cmd" in
        "sync-packages-to-all-nodes")
            validate_config || exit 1
            local type="all"
            [[ -n "${1:-}" && "${1:-}" != --dry-run ]] && type="$1"
            sync_packages_to_all_nodes "$type"
            ;;
        "sync-images-to-all-nodes")
            validate_config || exit 1
            sync_packages_to_all_nodes "images"
            ;;
        "install-images-on-all-nodes")
            validate_config || exit 1
            install_images_on_all_nodes
            ;;
        "cleanup-node-packages")
            if [[ $# -lt 1 ]]; then
                log_error "缺少节点IP参数"
                usage
                exit 1
            fi
            validate_config || exit 1
            local ip="$1"; shift || true
            local user="${1:-}"; [[ -n "${1:-}" ]] && shift || true
            local port="${1:-22}"; [[ -n "${1:-}" ]] && shift || true
            local ctype="${1:-all}"
            cleanup_node_packages "$ip" "$user" "$port" "$ctype"
            ;;
        "cleanup-packages-on-all-nodes")
            validate_config || exit 1
            local ctype="${1:-all}"
            local servers; mapfile -t servers < <(list_servers)
            if [[ ${#servers[@]} -eq 0 ]]; then log_error "未配置任何服务器节点"; exit 1; fi
            for idx in "${servers[@]}"; do
                IFS='|' read -r host user port secret pass rdir <<< "$(get_server_info "$idx")"
                cleanup_node_packages "$host" "$user" "$port" "$ctype" || true
            done
            log_success "所有节点清理完成"
            ;;
        "status")
            validate_config || exit 1
            log_info "本地目录: $LOCAL_PACKAGE_DIR"
            log_info "debs:   $(ls -1 "$LOCAL_DEBS_DIR" 2>/dev/null | wc -l | tr -d ' ') files"
            log_info "images: $(ls -1 "$LOCAL_IMAGES_DIR" 2>/dev/null | wc -l | tr -d ' ') files"
            log_info "tars:   $(ls -1 "$LOCAL_TARS_DIR" 2>/dev/null | wc -l | tr -d ' ') files"
            log_info "charts: $(ls -1 "$LOCAL_CHARTS_DIR" 2>/dev/null | wc -l | tr -d ' ') files"
            local servers; mapfile -t servers < <(list_servers)
            log_info "已配置节点数: ${#servers[@]}"
            for idx in "${servers[@]}"; do
                IFS='|' read -r host user port secret pass rdir <<< "$(get_server_info "$idx")"
                log_info "  [$idx] $user@$host:$port dir=$rdir"
            done
            ;;
        "help"|"-h"|"--help")
            usage
            ;;
        *)
            log_error "未知命令: $cmd"
            usage
            exit 1
            ;;
    esac
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

