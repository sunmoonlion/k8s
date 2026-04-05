#!/bin/bash

# 集群参数解析（轻量，无连接副作用）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$K8S_ROOT_DIR/utils/cluster-arg-parser.sh"


# =============================================================================
# registry-push-management 菜单式管理工具
# 文件名: registry-push-menu.sh
# 用途: 提供交互式菜单，管理镜像推送配置和执行推送操作
# =============================================================================

set -euo pipefail

# 设置环境变量以避免 locale 警告
export LC_ALL=C
export LANG=C
export LANGUAGE=C

# 脚本目录
# SCRIPT_DIR 已在上方初始化，保留此处逻辑兼容
SCRIPT_DIR="${SCRIPT_DIR:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"}"
CONF_FILE="$SCRIPT_DIR/loadimage.conf"
LOADIMAGE_TOOL="$SCRIPT_DIR/loadimage.sh"

# 加载集群配置映射函数（用于获取默认集群）
CLUSTER_MAPPING_SCRIPT="$(dirname "$SCRIPT_DIR")/cluster-config-mapping.sh"
if [[ -f "$CLUSTER_MAPPING_SCRIPT" ]]; then
    source "$CLUSTER_MAPPING_SCRIPT"
fi

# =============================================================================
# 解析命令行参数（支持 --cluster 或 -c 参数）
# =============================================================================

# 解析命令行参数（如果提供）
# 注意：解析后的参数会保存到 PARSED_ARGS，用于后续的 main 函数
if [[ $# -gt 0 ]]; then
    unified_parse_cluster_arg "$@"
    # 如果有未识别的参数，显示错误（但 --cluster/-c 参数已经被处理，不会在这里）
    if [[ ${#PARSED_ARGS[@]} -gt 0 ]]; then
        err "未知参数: ${PARSED_ARGS[*]}"
        echo "使用 $0 -h 查看帮助"
        exit 1
    fi
    # 保存解析后的参数（已移除 --cluster/-c 参数），供 main 函数使用
    MAIN_ARGS=("${PARSED_ARGS[@]}")
else
    MAIN_ARGS=()
fi

# 获取默认集群（优先级：命令行参数 > 环境变量 CURRENT_CLUSTER > 全局默认值）
# 如果没有设置 CURRENT_CLUSTER，从全局配置获取默认值（当前默认值：C2）
if [[ -z "${CURRENT_CLUSTER:-}" ]] && type get_default_cluster >/dev/null 2>&1; then
    CURRENT_CLUSTER=$(get_default_cluster)
fi
# 如果仍然没有，使用 C2 作为最终默认值（与全局配置保持一致）
CURRENT_CLUSTER="${CURRENT_CLUSTER:-C2}"
export CURRENT_CLUSTER

# 日志函数
log() { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
ok() { log "✅ $*"; }
warn() { log "⚠️  $*"; }
err() { log "❌ $*"; }

# 加载配置文件并应用集群配置映射
load_config() {
    if [[ ! -f "$CONF_FILE" ]]; then
        err "配置文件不存在: $CONF_FILE"
        return 1
    fi
    
    # 加载配置文件
    source "$CONF_FILE"
    
    # 加载集群配置映射函数（如果存在）
    CLUSTER_MAPPING_SCRIPT="$(dirname "$SCRIPT_DIR")/cluster-config-mapping.sh"
    if [[ -f "$CLUSTER_MAPPING_SCRIPT" ]]; then
        source "$CLUSTER_MAPPING_SCRIPT"
        # 应用集群配置映射
        if type apply_cluster_config_mapping >/dev/null 2>&1; then
            export CLUSTER="$CURRENT_CLUSTER"
            apply_cluster_config_mapping "$CURRENT_CLUSTER"
        fi
    fi
}

# 选择集群
select_cluster() {
    load_config || return 1
    
    echo ""
    echo "🎯 选择集群"
    echo "================================"
    echo "当前选择的集群: $CURRENT_CLUSTER"
    echo ""
    echo "可用集群："
    
    # 检测配置文件中定义的集群
    local clusters=()
    if grep -q "^C1_REGISTRY_URL=" "$CONF_FILE" 2>/dev/null; then
        clusters+=("C1")
        echo "  1. C1"
    fi
    if grep -q "^C2_REGISTRY_URL=" "$CONF_FILE" 2>/dev/null; then
        clusters+=("C2")
        echo "  2. C2"
    fi
    if grep -q "^C3_REGISTRY_URL=" "$CONF_FILE" 2>/dev/null; then
        clusters+=("C3")
        echo "  3. C3"
    fi
    
    echo ""
    read -p "请选择集群 (1-${#clusters[@]}, 留空保持当前): " choice
    
    if [[ -n "$choice" ]] && [[ "$choice" =~ ^[0-9]+$ ]]; then
        local idx=$((choice - 1))
        if [[ $idx -ge 0 ]] && [[ $idx -lt ${#clusters[@]} ]]; then
            CURRENT_CLUSTER="${clusters[$idx]}"
            export CURRENT_CLUSTER
            ok "已选择集群: $CURRENT_CLUSTER"
            # 重新加载配置以应用新集群的配置
            load_config
        else
            err "无效选择"
        fi
    else
        ok "保持当前集群: $CURRENT_CLUSTER"
    fi
}

# 保存配置到文件（创建默认集群配置）
save_config() {
    local temp_file=$(mktemp)
    cat > "$temp_file" <<EOF
# registry-push-management 集群配置
# 说明：必须为每个集群配置相应的参数，使用 C1_*, C2_* 等前缀
# 当 CLUSTER 环境变量设置为对应值时，会使用对应的集群配置

# 本地镜像包目录（所有集群通用）
LOCAL_IMAGE_DIR="\$HOME/packages-to-be-installed/images"

# ============================================================================
# C1 集群配置（当 CLUSTER=C1 时生效）
# ============================================================================
C1_REGISTRY_URL=""
C1_PROJECT_NAME="k8s-images"
C1_REGISTRY_USERNAME=""
C1_REGISTRY_PASSWORD=""
# C1_REGISTRY_LOGIN_BEFORE_PUSH="true"              # C1 集群是否在 push 前登录（默认：true）
#   说明：控制是否在推送镜像前先登录到 Registry
#   - true: 推送前执行 nerdctl login，使用上面的 REGISTRY_USERNAME 和 REGISTRY_PASSWORD 进行认证
#   - false: 跳过登录步骤，适用于已配置全局认证或匿名访问的 Registry
C1_REMOTE_HOST=""
C1_REMOTE_USER="root"
C1_REMOTE_SSH_PORT="22"
C1_REMOTE_SECRET=""
C1_REMOTE_PASS=""
C1_REMOTE_IMAGE_DIR="~/packages-to-be-installed/images"

# ============================================================================
# 如需添加更多集群，使用 C2_*, C3_* 等前缀，格式与上面相同
# ============================================================================

# nerdctl/containerd
NERDCTL_BIN="nerdctl"
CONTAINERD_NAMESPACE="k8s.io"
USE_SUDO="true"

# 推送重试
PUSH_RETRY="2"
PUSH_RETRY_INTERVAL="3"

# 代理（可选）
HTTP_PROXY=""
HTTPS_PROXY=""
NO_PROXY="localhost,127.0.0.1,::1"

# 推送前检查工具配置（必须：推送前检查 registry 是否存在，存在则跳过）
EXISTENCE_CHECK_TOOL="skopeo"
REGISTRY_TLS_VERIFY="false"
EOF
    mv "$temp_file" "$CONF_FILE"
    ok "已创建默认配置文件: $CONF_FILE"
    warn "请编辑配置文件，为每个集群设置相应的配置项（C1_*, C2_* 等）"
}

# 显示当前配置
show_config() {
    load_config || return 1
    
    echo ""
    echo "📋 当前配置 (集群: $CURRENT_CLUSTER)"
    echo "================================"
    echo "=== 本地配置 ==="
    echo "1.  LOCAL_IMAGE_DIR: ${LOCAL_IMAGE_DIR:-未设置}"
    echo ""
    echo "=== Registry 配置 ($CURRENT_CLUSTER) ==="
    echo "2.  REGISTRY_URL: ${REGISTRY_URL:-未设置}"
    echo "3.  PROJECT_NAME: ${PROJECT_NAME:-未设置}"
    echo "4.  REGISTRY_USERNAME: ${REGISTRY_USERNAME:-未设置}"
    echo "5.  REGISTRY_PASSWORD: ${REGISTRY_PASSWORD:+已设置（隐藏）}"
    echo "6.  REGISTRY_LOGIN_BEFORE_PUSH: ${REGISTRY_LOGIN_BEFORE_PUSH:-true}"
    echo ""
    echo "=== 远程节点配置 ($CURRENT_CLUSTER) ==="
    echo "7.  REMOTE_HOST: ${REMOTE_HOST:-未设置}"
    echo "8.  REMOTE_USER: ${REMOTE_USER:-未设置}"
    echo "9.  REMOTE_SSH_PORT: ${REMOTE_SSH_PORT:-未设置}"
    echo "10. REMOTE_SECRET: ${REMOTE_SECRET:-未设置}"
    echo "11. REMOTE_PASS: ${REMOTE_PASS:+已设置（隐藏）}"
    echo "12. REMOTE_IMAGE_DIR: ${REMOTE_IMAGE_DIR:-未设置}"
    echo ""
    echo "=== 容器运行时配置（所有集群通用）==="
    echo "13. NERDCTL_BIN: ${NERDCTL_BIN:-nerdctl}"
    echo "14. CONTAINERD_NAMESPACE: ${CONTAINERD_NAMESPACE:-k8s.io}"
    echo "15. USE_SUDO: ${USE_SUDO:-true}"
    echo ""
    echo "=== 推送可靠性配置（所有集群通用）==="
    echo "16. PUSH_RETRY: ${PUSH_RETRY:-2}"
    echo "17. PUSH_RETRY_INTERVAL: ${PUSH_RETRY_INTERVAL:-3}"
    echo ""
    echo "=== 网络代理配置（所有集群通用）==="
    echo "18. HTTP_PROXY: ${HTTP_PROXY:-未设置}"
    echo "19. HTTPS_PROXY: ${HTTPS_PROXY:-未设置}"
    echo "20. NO_PROXY: ${NO_PROXY:-localhost,127.0.0.1,::1}"
    echo ""
    echo "=== 推送检查配置（所有集群通用）==="
    echo "21. EXISTENCE_CHECK_TOOL: ${EXISTENCE_CHECK_TOOL:-skopeo}"
    echo "22. REGISTRY_TLS_VERIFY: ${REGISTRY_TLS_VERIFY:-false}"
    echo "================================"
}

# 更新配置文件中的配置项
update_config_file() {
    local cluster_prefix="$1"
    local var_name="$2"
    local var_value="$3"
    
    # 转义特殊字符
    local escaped_value=$(printf '%s\n' "$var_value" | sed 's/[[\.*^$()+?{|]/\\&/g')
    
    # 构建配置行
    local config_line="${cluster_prefix}${var_name}=\"${escaped_value}\""
    
    # 如果配置项已存在，更新它；否则在对应集群配置段末尾添加
    if grep -q "^${cluster_prefix}${var_name}=" "$CONF_FILE" 2>/dev/null; then
        # 更新现有配置行（保留注释）
        sed -i "s|^${cluster_prefix}${var_name}=.*|${config_line}|" "$CONF_FILE"
    else
        # 找到对应集群配置段的结束位置，在之前插入
        local cluster_section_pattern="# ============================================================================\n# ${cluster_prefix} 集群配置"
        if grep -q "^# ${cluster_prefix} 集群配置" "$CONF_FILE" 2>/dev/null; then
            # 在集群配置段的最后一个配置项后添加
            local last_line=$(grep -n "^${cluster_prefix}" "$CONF_FILE" | tail -1 | cut -d: -f1)
            if [[ -n "$last_line" ]]; then
                sed -i "${last_line}a\\${config_line}" "$CONF_FILE"
            else
                # 如果找不到，在集群配置段标题后添加
                sed -i "/^# ${cluster_prefix} 集群配置/a\\${config_line}" "$CONF_FILE"
            fi
        fi
    fi
}

# 编辑配置项
edit_config_item() {
    load_config || return 1
    
    local item_num="$1"
    local var_name=""
    local cluster_var_name=""
    local var_value=""
    local prompt=""
    local is_password=false
    local is_cluster_specific=false
    
    case "$item_num" in
        1) var_name="LOCAL_IMAGE_DIR"; prompt="本地镜像包目录"; var_value="${LOCAL_IMAGE_DIR:-$HOME/packages-to-be-installed/images}" ;;
        2) cluster_var_name="REGISTRY_URL"; var_name="${CURRENT_CLUSTER}_REGISTRY_URL"; prompt="Registry 地址（不含协议）"; var_value="${REGISTRY_URL:-}"; is_cluster_specific=true ;;
        3) cluster_var_name="PROJECT_NAME"; var_name="${CURRENT_CLUSTER}_PROJECT_NAME"; prompt="项目名称"; var_value="${PROJECT_NAME:-}"; is_cluster_specific=true ;;
        4) cluster_var_name="REGISTRY_USERNAME"; var_name="${CURRENT_CLUSTER}_REGISTRY_USERNAME"; prompt="Registry 用户名"; var_value="${REGISTRY_USERNAME:-}"; is_cluster_specific=true ;;
        5) cluster_var_name="REGISTRY_PASSWORD"; var_name="${CURRENT_CLUSTER}_REGISTRY_PASSWORD"; prompt="Registry 密码"; var_value="${REGISTRY_PASSWORD:-}"; is_password=true; is_cluster_specific=true ;;
        6) cluster_var_name="REGISTRY_LOGIN_BEFORE_PUSH"; var_name="${CURRENT_CLUSTER}_REGISTRY_LOGIN_BEFORE_PUSH"; prompt="推送前自动登录 (true/false)"; var_value="${REGISTRY_LOGIN_BEFORE_PUSH:-true}"; is_cluster_specific=true ;;
        7) cluster_var_name="REMOTE_HOST"; var_name="${CURRENT_CLUSTER}_REMOTE_HOST"; prompt="远程节点 IP 地址"; var_value="${REMOTE_HOST:-}"; is_cluster_specific=true ;;
        8) cluster_var_name="REMOTE_USER"; var_name="${CURRENT_CLUSTER}_REMOTE_USER"; prompt="SSH 用户名"; var_value="${REMOTE_USER:-}"; is_cluster_specific=true ;;
        9) cluster_var_name="REMOTE_SSH_PORT"; var_name="${CURRENT_CLUSTER}_REMOTE_SSH_PORT"; prompt="SSH 端口"; var_value="${REMOTE_SSH_PORT:-}"; is_cluster_specific=true ;;
        10) cluster_var_name="REMOTE_SECRET"; var_name="${CURRENT_CLUSTER}_REMOTE_SECRET"; prompt="SSH 私钥路径"; var_value="${REMOTE_SECRET:-}"; is_cluster_specific=true ;;
        11) cluster_var_name="REMOTE_PASS"; var_name="${CURRENT_CLUSTER}_REMOTE_PASS"; prompt="SSH 密码（留空则使用密钥）"; var_value="${REMOTE_PASS:-}"; is_password=true; is_cluster_specific=true ;;
        12) cluster_var_name="REMOTE_IMAGE_DIR"; var_name="${CURRENT_CLUSTER}_REMOTE_IMAGE_DIR"; prompt="远程镜像目录"; var_value="${REMOTE_IMAGE_DIR:-}"; is_cluster_specific=true ;;
        13) var_name="NERDCTL_BIN"; prompt="nerdctl 命令路径"; var_value="${NERDCTL_BIN:-nerdctl}" ;;
        14) var_name="CONTAINERD_NAMESPACE"; prompt="containerd 命名空间"; var_value="${CONTAINERD_NAMESPACE:-k8s.io}" ;;
        15) var_name="USE_SUDO"; prompt="使用 sudo (true/false)"; var_value="${USE_SUDO:-true}" ;;
        16) var_name="PUSH_RETRY"; prompt="推送重试次数"; var_value="${PUSH_RETRY:-2}" ;;
        17) var_name="PUSH_RETRY_INTERVAL"; prompt="重试间隔（秒）"; var_value="${PUSH_RETRY_INTERVAL:-3}" ;;
        18) var_name="HTTP_PROXY"; prompt="HTTP 代理"; var_value="${HTTP_PROXY:-}" ;;
        19) var_name="HTTPS_PROXY"; prompt="HTTPS 代理"; var_value="${HTTPS_PROXY:-}" ;;
        20) var_name="NO_PROXY"; prompt="不使用代理的地址"; var_value="${NO_PROXY:-localhost,127.0.0.1,::1}" ;;
        21) var_name="EXISTENCE_CHECK_TOOL"; prompt="存在性检查工具 (skopeo/none)"; var_value="${EXISTENCE_CHECK_TOOL:-skopeo}" ;;
        22) var_name="REGISTRY_TLS_VERIFY"; prompt="TLS 证书校验 (true/false)"; var_value="${REGISTRY_TLS_VERIFY:-false}" ;;
        *)
            err "无效的配置项序号: $item_num"
            return 1
            ;;
    esac
    
    echo ""
    if [[ "$is_cluster_specific" == true ]]; then
        echo "📝 编辑配置项: $cluster_var_name (集群: $CURRENT_CLUSTER)"
    else
        echo "📝 编辑配置项: $var_name"
    fi
    echo "说明: $prompt"
    echo "当前值: ${var_value:-（空）}"
    echo ""
    
    if [[ "$is_password" == true ]]; then
        read -sp "请输入新值（留空保持原值，输入时不会显示）: " new_value
        echo ""
    else
        read -p "请输入新值（留空保持原值）: " new_value
    fi
    
    if [[ -n "$new_value" ]]; then
        if [[ "$is_cluster_specific" == true ]]; then
            # 更新集群特定配置
            update_config_file "${CURRENT_CLUSTER}_" "$cluster_var_name" "$new_value"
        else
            # 更新通用配置
            sed -i "s|^${var_name}=.*|${var_name}=\"${new_value}\"|" "$CONF_FILE" || \
            echo "${var_name}=\"${new_value}\"" >> "$CONF_FILE"
        fi
        ok "配置项已更新"
        # 重新加载配置
        load_config
    else
        warn "未修改配置项"
    fi
}

# 配置管理菜单
config_menu() {
    while true; do
        echo ""
        echo "⚙️  配置管理 (集群: $CURRENT_CLUSTER)"
        echo "================================"
        show_config
        echo ""
        echo "操作选项："
        echo "c. 切换集群"
        echo "1-22. 编辑对应配置项"
        echo "0. 返回主菜单"
        echo ""
        read -p "请选择 (0-22, c): " choice
        
        if [[ "$choice" == "0" ]]; then
            break
        elif [[ "$choice" == "c" ]] || [[ "$choice" == "C" ]]; then
            select_cluster
            read -p "按回车键继续..."
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le 22 ]]; then
            edit_config_item "$choice"
            read -p "按回车键继续..."
        else
            err "无效选择"
        fi
    done
}

# 推送镜像（合并了原来的单个、批量、目录推送功能）
push_images() {
    load_config || return 1
    
    echo ""
    echo "📤 推送镜像"
    echo "================================"
    
    # 检查必要配置
    if [[ -z "${REMOTE_HOST:-}" ]]; then
        err "未配置 REMOTE_HOST，请先在配置管理中设置"
        return 1
    fi
    
    if [[ -z "${REGISTRY_URL:-}" ]]; then
        err "未配置 REGISTRY_URL，请先在配置管理中设置"
        return 1
    fi
    
    # 获取本地镜像目录
    local dir="${LOCAL_IMAGE_DIR:-$HOME/packages-to-be-installed/images}"
    if [[ ! -d "$dir" ]]; then
        err "镜像目录不存在: $dir"
        return 1
    fi
    
    # 列出所有镜像文件
    local image_files=()
    local image_names=()
    
    # 查找所有 .tar 和 .tar.gz 文件
    while IFS= read -r -d '' file; do
        local basename_file=$(basename "$file")
        image_files+=("$file")
        
        # 从文件名推断镜像名：去掉 .tar 或 .tar.gz 后缀，将 _ 替换回 / 和 :
        local img_name="${basename_file%.tar*}"
        # 尝试将 _ 替换回 / 和 :，但需要智能处理
        # 简单策略：如果文件名包含 _，尝试恢复为镜像名格式
        # 这里我们保持原样，让 loadimage.sh 来处理
        image_names+=("$img_name")
    done < <(find "$dir" -maxdepth 1 -type f \( -name "*.tar" -o -name "*.tar.gz" \) -print0 2>/dev/null | sort -z)
    
    if [[ ${#image_files[@]} -eq 0 ]]; then
        err "在目录 $dir 中未找到镜像文件（.tar 或 .tar.gz）"
        return 1
    fi
    
    # 显示镜像列表
    echo "📦 可用的镜像文件："
    echo "================================"
    for i in $(seq 0 $((${#image_files[@]}-1))); do
        local file="${image_files[i]}"
        local basename_file=$(basename "$file")
        local size=$(du -h "$file" | cut -f1)
        local date=$(stat -c %y "$file" 2>/dev/null | cut -d' ' -f1 || echo "未知")
        echo "$((i+1)). $basename_file ($size, 创建时间: $date)"
    done
    echo "================================"
    
    # 用户选择
    read -p "请输入要推送的镜像序号（空格分隔多个序号，如：1 2），输入 all 选择全部: " selected_indices
    
    local files_to_push=()
    if [[ "$selected_indices" == "all" ]]; then
        files_to_push=("${image_files[@]}")
    else
        for idx in $selected_indices; do
            if [[ "$idx" =~ ^[0-9]+$ ]] && (( idx >= 1 && idx <= ${#image_files[@]} )); then
                files_to_push+=("${image_files[$((idx-1))]}")
            else
                warn "无效序号: $idx，已跳过"
            fi
        done
    fi
    
    if [[ ${#files_to_push[@]} -eq 0 ]]; then
        err "未选择任何镜像"
        return 1
    fi
    
    echo ""
    echo "已选择 ${#files_to_push[@]} 个镜像，开始推送..."
    echo ""
    
    # 逐个推送选中的镜像
    # 使用 push-from-dir 的方式：先加载镜像获取实际引用，再构建目标引用
    # 对每个选中的文件，创建临时目录并使用 push-from-dir 处理
    local success_count=0
    local fail_count=0
    
    for tar_file in "${files_to_push[@]}"; do
        local basename_file=$(basename "$tar_file")
        echo "📤 推送: $basename_file"
        
        # 创建一个临时目录，只包含当前文件
        local temp_dir=$(mktemp -d)
        cp "$tar_file" "$temp_dir/"
        
        # 使用 push-from-dir 处理临时目录（只包含一个文件）
        # push-from-dir 会自动：
        # 1. 上传 tar 到远程
        # 2. 加载镜像获取实际引用
        # 3. 从引用提取 name_only 和 tag
        # 4. 构建目标引用并推送
        
        # 使用临时日志文件捕获输出，同时实时显示进度
        local log_file="/tmp/registry_push_${basename_file}_$$.log"
        # 确保日志文件存在（即使为空）
        touch "$log_file" 2>/dev/null || log_file="/tmp/registry_push_${basename_file}_${RANDOM}.log"
        local push_success=false
        local exit_code=0
        
        # 执行推送命令，使用 tee 同时输出到终端和日志文件，实时显示进度
        echo "  ⏳ 正在推送..."
        set +e  # 临时禁用错误退出，以便捕获退出码
        
        # 设置 CLUSTER 环境变量
        export CLUSTER="$CURRENT_CLUSTER"
        
        # 直接使用 tee 显示进度，同时保存到日志文件
        # 使用 unbuffered 模式确保实时输出
        CLUSTER="$CURRENT_CLUSTER" "$LOADIMAGE_TOOL" push-from-dir \
            "$temp_dir" \
            "${REMOTE_HOST:-}" \
            "${REMOTE_IMAGE_DIR:-}" \
            "${REMOTE_USER:-}" \
            "${REMOTE_SSH_PORT:-}" \
            "${REMOTE_SECRET:-}" \
            "${REMOTE_PASS:-}" 2>&1 | tee "$log_file"
        
        exit_code=${PIPESTATUS[0]}  # 获取第一个命令（loadimage.sh）的退出码
        set -e
        
        # 根据退出码和日志内容判断是否成功
        if [[ $exit_code -eq 0 ]]; then
            # 检查日志中是否包含推送成功的标志
            if grep -q "✅ 推送成功:" "$log_file" 2>/dev/null; then
                push_success=true
            # 检查是否包含致命错误（排除清理步骤的错误）
            elif grep -qE "(跳过|无法解析|无法构造|未能解析)" "$log_file" 2>/dev/null; then
                push_success=false
            else
                # 没有明确的成功标志，也没有致命错误，判定为成功
                push_success=true
            fi
        else
            push_success=false
        fi
        
        if [[ "$push_success" == true ]]; then
            ok "$basename_file 推送成功"
            success_count=$((success_count + 1))
        else
            err "$basename_file 推送失败"
            # 直接显示日志文件内容（参考 packages-management.sh）
            if [[ -f "$log_file" ]] && [[ -s "$log_file" ]]; then
                echo "  错误日志："
                tail -n 50 "$log_file" 2>/dev/null | sed 's/^/    /' || echo "    无法读取错误日志"
            else
                echo "  警告: 未生成日志文件"
            fi
            fail_count=$((fail_count + 1))
        fi
        
        # 清理日志文件
        rm -f "$log_file" 2>/dev/null || true
        
        # 清理临时目录
        rm -rf "$temp_dir" 2>/dev/null || true
        echo ""
    done
    
    echo "================================"
    echo "推送完成: 成功 $success_count 个，失败 $fail_count 个"
    
    if [[ $fail_count -gt 0 ]]; then
        return 1
    fi
}

# 列出远程仓库中的镜像
list_registry_images() {
    load_config || return 1
    
    local registry_url="${REGISTRY_URL:-}"
    local project_name="${PROJECT_NAME:-k8s-images}"
    
    if [[ -z "$registry_url" ]]; then
        return 1
    fi
    
    echo ""
    echo "🔍 正在检查远程仓库中的镜像..."
    
    # 尝试使用 skopeo 列出镜像（如果可用）
    if command -v skopeo >/dev/null 2>&1; then
        local tlsopt="--tls-verify=${REGISTRY_TLS_VERIFY:-false}"
        local credopt=""
        if [[ -n "${REGISTRY_USERNAME:-}" ]] && [[ -n "${REGISTRY_PASSWORD:-}" ]]; then
            credopt="--creds ${REGISTRY_USERNAME}:${REGISTRY_PASSWORD}"
        fi
        
        # 尝试列出项目下的镜像
        local repo_url="docker://${registry_url}/${project_name}"
        local tags_output=""
        
        # 使用 skopeo list-tags 列出所有标签
        if tags_output=$(skopeo list-tags $tlsopt $credopt "$repo_url" 2>/dev/null); then
            # 解析 JSON 输出（简单处理）
            local tags=$(echo "$tags_output" | grep -oE '"name"\s*:\s*"[^"]+"' | sed 's/"name"\s*:\s*"\([^"]*\)"/\1/' | head -50)
            
            if [[ -n "$tags" ]]; then
                echo ""
                echo "📦 远程仓库中的镜像（${registry_url}/${project_name}）："
                echo "================================"
                local count=1
                while IFS= read -r tag; do
                    [[ -z "$tag" ]] && continue
                    local full_ref="${registry_url}/${project_name}/${tag}:latest"
                    # 尝试检查是否有其他标签
                    echo "$count. ${project_name}/${tag}"
                    count=$((count + 1))
                done <<< "$tags"
                echo "================================"
                return 0
            fi
        fi
    fi
    
    # 如果 skopeo 不可用或失败，尝试使用 Harbor API（如果是 Harbor）
    if [[ "$registry_url" == *"harbor"* ]] || [[ "$registry_url" == *"sunmoonai"* ]]; then
        # 尝试使用 curl 访问 Harbor API
        local api_url="https://${registry_url}/api/v2.0/projects/${project_name}/repositories"
        local curl_opts="-k -s"
        [[ "${REGISTRY_TLS_VERIFY:-false}" == "true" ]] && curl_opts="-s"
        
        # 构建 curl 命令
        local curl_cmd="curl $curl_opts"
        if [[ -n "${REGISTRY_USERNAME:-}" ]] && [[ -n "${REGISTRY_PASSWORD:-}" ]]; then
            curl_cmd="$curl_cmd -u ${REGISTRY_USERNAME}:${REGISTRY_PASSWORD}"
        fi
        # 第一步：列出所有项目
        local projects_api_url="https://${registry_url}/api/v2.0/projects"
        local projects_output=""
        projects_output=$(eval "$curl_cmd '$projects_api_url'" 2>/dev/null)
        local projects_exit=$?
        
        # 检查是否有错误
        if echo "$projects_output" | grep -q '"errors"'; then
            local error_msg=$(echo "$projects_output" | grep -oE '"message"\s*:\s*"[^"]+"' | head -1 | sed 's/"message"\s*:\s*"\([^"]*\)"/\1/')
            if [[ "$error_msg" == *"unauthorized"* ]] || [[ "$error_msg" == *"UNAUTHORIZED"* ]]; then
                warn "Harbor API 需要认证，请在配置中设置 REGISTRY_USERNAME 和 REGISTRY_PASSWORD"
            else
                warn "Harbor API 错误: $error_msg"
            fi
            return 1
        fi
        
        if [[ $projects_exit -ne 0 ]] || [[ -z "$projects_output" ]]; then
            warn "无法获取项目列表"
            return 1
        fi
        
        # 解析项目列表
        local project_names=$(echo "$projects_output" | grep -oE '"name"\s*:\s*"[^"]+"' | sed 's/"name"\s*:\s*"\([^"]*\)"/\1/' | sort -u)
        
        if [[ -z "$project_names" ]]; then
            warn "未找到任何项目"
            return 1
        fi
        
        echo ""
        echo "📦 远程仓库中的镜像（所有项目）："
        echo "================================"
        local total_count=1
        local all_images=()  # 存储所有镜像的完整引用，用于后续选择
        
        # 遍历每个项目
        while IFS= read -r proj_name; do
            [[ -z "$proj_name" ]] && continue
            
            # 获取该项目下的所有仓库（处理分页）
            local repos_api_url="https://${registry_url}/api/v2.0/projects/${proj_name}/repositories"
            local all_repos_output=""
            local page=1
            local page_size=100
            
            # 循环获取所有分页的仓库
            while true; do
                local current_url="${repos_api_url}?page=${page}&page_size=${page_size}"
                local repos_output=""
                repos_output=$(eval "$curl_cmd '$current_url'" 2>/dev/null)
                
                if [[ -z "$repos_output" ]] || echo "$repos_output" | grep -q '"errors"'; then
                    break
                fi
                
                # 检查是否有数据
                local repo_count=$(echo "$repos_output" | grep -oE '"name"\s*:\s*"[^"]+"' | wc -l)
                if [[ $repo_count -eq 0 ]]; then
                    break
                fi
                
                all_repos_output+="$repos_output"
                
                # 检查是否还有更多页（如果返回的数量小于 page_size，说明是最后一页）
                if [[ $repo_count -lt $page_size ]]; then
                    break
                fi
                
                page=$((page + 1))
            done
            
            if [[ -z "$all_repos_output" ]]; then
                continue
            fi
            
            # 解析仓库列表
            local repo_names=$(echo "$all_repos_output" | grep -oE '"name"\s*:\s*"[^"]+"' | sed 's/"name"\s*:\s*"\([^"]*\)"/\1/' | sort -u)
            
            # 遍历每个仓库
            while IFS= read -r full_repo_name; do
                [[ -z "$full_repo_name" ]] && continue
                
                # 尝试获取该仓库的标签列表
                local repo_name="${full_repo_name#${proj_name}/}"
                local tags_api_url="https://${registry_url}/api/v2.0/projects/${proj_name}/repositories/${repo_name}/artifacts"
                local tags_output=""
                local tags=""
                local first_tag=""
                
                if tags_output=$(eval "$curl_cmd '${tags_api_url}?page_size=5'" 2>/dev/null | head -50); then
                    # 从 artifacts 中提取标签信息
                    # Harbor API 返回的 artifacts 中，tags 是一个数组
                    tags=$(echo "$tags_output" | grep -A 10 '"tags"' | grep -oE '"name"\s*:\s*"[^"]+"' | sed 's/"name"\s*:\s*"\([^"]*\)"/\1/' | head -5 | tr '\n' ',' | sed 's/,$//')
                    first_tag=$(echo "$tags" | cut -d',' -f1)
                    # 如果没找到标签，尝试从 digest 或其他字段提取
                    if [[ -z "$tags" ]]; then
                        tags=$(echo "$tags_output" | grep -oE '"digest"\s*:\s*"[^"]+"' | head -1 | sed 's/"digest"\s*:\s*"\([^"]*\)"/\1/' | cut -d: -f2 | cut -c1-12)
                        first_tag="$tags"
                    fi
                fi
                
                # 构建完整的镜像引用
                local full_image_ref=""
                if [[ -n "$first_tag" ]]; then
                    full_image_ref="${registry_url}/${full_repo_name}:${first_tag}"
                else
                    full_image_ref="${registry_url}/${full_repo_name}:latest"
                fi
                all_images+=("$full_image_ref")
                
                if [[ -n "$tags" ]]; then
                    echo "$total_count. ${full_repo_name} (标签: ${tags})"
                else
                    echo "$total_count. ${full_repo_name}"
                fi
                total_count=$((total_count + 1))
            done <<< "$repo_names"
        done <<< "$project_names"
        
        echo "================================"
        echo ""
        echo "💡 提示："
        echo "  - 输入序号（如：1）选择列表中的镜像"
        echo "  - 输入镜像名称（如：项目名/镜像名:标签）"
        echo "  - 可以输入多个，每行一个，输入空行完成输入"
        
        # 将镜像列表保存到全局变量（通过文件传递）
        local temp_file="/tmp/registry_images_list_$$.txt"
        printf '%s\n' "${all_images[@]}" > "$temp_file"
        export REGISTRY_IMAGES_LIST_FILE="$temp_file"
        export REGISTRY_IMAGES_COUNT=${#all_images[@]}
        
        return 0
    fi
    
    # 如果都失败了，返回失败
    warn "无法列出远程仓库镜像（可能需要手动输入）"
    return 1
}

# 拉取镜像到远程节点
pull_images() {
    load_config || return 1
    
    echo ""
    echo "📥 拉取镜像到远程节点"
    echo "================================"
    
    # 检查必要配置
    if [[ -z "${REMOTE_HOST:-}" ]]; then
        err "未配置 REMOTE_HOST，请先在配置管理中设置"
        return 1
    fi
    
    if [[ -z "${REGISTRY_URL:-}" ]]; then
        err "未配置 REGISTRY_URL，请先在配置管理中设置"
        return 1
    fi
    
    # 先尝试列出远程仓库中的镜像
    list_registry_images || true
    
    # 读取镜像列表文件（如果存在）
    local images_list_file="${REGISTRY_IMAGES_LIST_FILE:-}"
    local images_count="${REGISTRY_IMAGES_COUNT:-0}"
    local available_images=()
    if [[ -n "$images_list_file" ]] && [[ -f "$images_list_file" ]]; then
        mapfile -t available_images < "$images_list_file"
        rm -f "$images_list_file" 2>/dev/null || true
    fi
    
    echo ""
    echo "请输入要拉取的镜像："
    echo "  - 输入序号（如：1）选择列表中的镜像"
    echo "  - 输入镜像名称（如：项目名/镜像名:标签 或 ${REGISTRY_URL}/项目名/镜像名:标签）"
    echo "  - 可以输入多个，每行一个，输入空行完成输入"
    echo "  - 如果只输入 repo:tag，会自动补全为 ${REGISTRY_URL}/${PROJECT_NAME}/repo:tag"
    echo "================================"
    
    local image_refs=()
    while true; do
        read -p "镜像引用或序号（留空完成输入）: " img_input
        [[ -z "$img_input" ]] && break
        
        local img_ref="$img_input"
        
        # 如果输入的是纯数字，尝试从列表中获取对应的镜像
        if [[ "$img_input" =~ ^[0-9]+$ ]]; then
            local idx=$((img_input - 1))
            if [[ $idx -ge 0 ]] && [[ $idx -lt ${#available_images[@]} ]]; then
                img_ref="${available_images[$idx]}"
                echo "  ✅ 选择镜像: $img_ref"
            else
                warn "无效序号: $img_input（有效范围: 1-${#available_images[@]}），请重新输入"
                continue
            fi
        # 如果输入的是 repo:tag 格式（不包含 /），自动补全为完整引用
        elif [[ "$img_ref" != *"/"* ]]; then
            local repo="${img_ref%:*}"
            local tag="${img_ref##*:}"
            [[ "$tag" == "$repo" ]] && tag="latest"
            local name_only="${repo##*/}"
            img_ref="${REGISTRY_URL}/${PROJECT_NAME}/${name_only}:${tag}"
            echo "  📝 自动补全为: $img_ref"
        # 如果输入的是项目名/镜像名格式，补全 registry
        elif [[ "$img_ref" != *"${REGISTRY_URL}"* ]] && [[ "$img_ref" == *"/"* ]]; then
            img_ref="${REGISTRY_URL}/${img_ref}"
            # 如果没有标签，添加默认标签
            if [[ "$img_ref" != *":"* ]]; then
                img_ref="${img_ref}:latest"
            fi
        fi
        
        image_refs+=("$img_ref")
    done
    
    if [[ ${#image_refs[@]} -eq 0 ]]; then
        err "未输入任何镜像引用"
        return 1
    fi
    
    echo ""
    echo "已选择 ${#image_refs[@]} 个镜像，开始拉取..."
    echo ""
    
    # 在远程节点上执行拉取
    local success_count=0
    local fail_count=0
    
    # 准备远程执行命令的环境变量和前缀
    local sudo_prefix=""
    [[ "${USE_SUDO:-true}" == "true" ]] && sudo_prefix="sudo -n "
    local nb="${NERDCTL_BIN:-nerdctl}"
    local ns="${CONTAINERD_NAMESPACE:-k8s.io}"
    
    # 准备代理环境变量
    local env_proxy=""
    [[ -n "${HTTP_PROXY:-}" ]] && env_proxy+=" HTTP_PROXY=${HTTP_PROXY}"
    [[ -n "${HTTPS_PROXY:-}" ]] && env_proxy+=" HTTPS_PROXY=${HTTPS_PROXY}"
    [[ -n "${NO_PROXY:-}" ]] && env_proxy+=" NO_PROXY=${NO_PROXY}"
    
    # 如果需要，先登录 Registry
    if [[ "${REGISTRY_LOGIN_BEFORE_PUSH:-false}" == "true" ]] && \
       [[ -n "${REGISTRY_USERNAME:-}" ]] && [[ -n "${REGISTRY_PASSWORD:-}" ]]; then
        echo "🔐 登录 Registry..."
        local login_cmd="echo '${REGISTRY_PASSWORD}' | ${sudo_prefix}${nb} login '${REGISTRY_URL}' -u '${REGISTRY_USERNAME}' --password-stdin"
        
        if [[ -n "${REMOTE_SECRET:-}" ]] && [[ -f "${REMOTE_SECRET}" ]]; then
            ssh -i "${REMOTE_SECRET}" -o StrictHostKeyChecking=no -o LogLevel=ERROR -p "${REMOTE_SSH_PORT:-22}" \
                "${REMOTE_USER:-root}@${REMOTE_HOST}" "$login_cmd" >/dev/null 2>&1 || warn "Registry 登录失败，继续尝试拉取..."
        elif [[ -n "${REMOTE_PASS:-}" ]] && command -v sshpass >/dev/null 2>&1; then
            sshpass -p "${REMOTE_PASS}" ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR -p "${REMOTE_SSH_PORT:-22}" \
                "${REMOTE_USER:-root}@${REMOTE_HOST}" "$login_cmd" >/dev/null 2>&1 || warn "Registry 登录失败，继续尝试拉取..."
        else
            ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR -p "${REMOTE_SSH_PORT:-22}" \
                "${REMOTE_USER:-root}@${REMOTE_HOST}" "$login_cmd" >/dev/null 2>&1 || warn "Registry 登录失败，继续尝试拉取..."
        fi
    fi
    
    # 逐个拉取镜像
    for img_ref in "${image_refs[@]}"; do
        echo "📥 拉取: $img_ref"
        
        local pull_cmd="${env_proxy} ${sudo_prefix}${nb} -n '${ns}' pull '${img_ref}'"
        local pull_output=""
        local pull_exit_code=0
        
        # 执行拉取命令并捕获输出
        set +e
        if [[ -n "${REMOTE_SECRET:-}" ]] && [[ -f "${REMOTE_SECRET}" ]]; then
            pull_output=$(ssh -i "${REMOTE_SECRET}" -o StrictHostKeyChecking=no -o LogLevel=ERROR -p "${REMOTE_SSH_PORT:-22}" \
                "${REMOTE_USER:-root}@${REMOTE_HOST}" "$pull_cmd" 2>&1)
            pull_exit_code=$?
        elif [[ -n "${REMOTE_PASS:-}" ]] && command -v sshpass >/dev/null 2>&1; then
            pull_output=$(sshpass -p "${REMOTE_PASS}" ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR -p "${REMOTE_SSH_PORT:-22}" \
                "${REMOTE_USER:-root}@${REMOTE_HOST}" "$pull_cmd" 2>&1)
            pull_exit_code=$?
        else
            pull_output=$(ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR -p "${REMOTE_SSH_PORT:-22}" \
                "${REMOTE_USER:-root}@${REMOTE_HOST}" "$pull_cmd" 2>&1)
            pull_exit_code=$?
        fi
        set -e
        
        if [[ $pull_exit_code -eq 0 ]]; then
            ok "$img_ref 拉取成功"
            
            # 去掉 registry 前缀，重新标记镜像以便本地使用
            # 例如：www.sunmoonai.com:30443/k8s-images/csi:v3.28.2 -> k8s-images/csi:v3.28.2
            local local_ref="$img_ref"
            if [[ "$img_ref" == *"${REGISTRY_URL}"* ]]; then
                # 去掉 registry URL 前缀
                local_ref="${img_ref#${REGISTRY_URL}/}"
                # 如果去掉前缀后和原引用相同，说明格式不对，尝试其他方式
                if [[ "$local_ref" == "$img_ref" ]]; then
                    # 尝试从完整路径中提取项目名/镜像名:标签
                    local_ref="${img_ref#*://}"
                    local_ref="${local_ref#*/}"
                fi
                
                # 重新标记镜像
                if [[ -n "$local_ref" ]] && [[ "$local_ref" != "$img_ref" ]]; then
                    local tag_cmd="${env_proxy} ${sudo_prefix}${nb} -n '${ns}' tag '${img_ref}' '${local_ref}'"
                    local tag_exit_code=0
                    
                    set +e
                    if [[ -n "${REMOTE_SECRET:-}" ]] && [[ -f "${REMOTE_SECRET}" ]]; then
                        ssh -i "${REMOTE_SECRET}" -o StrictHostKeyChecking=no -o LogLevel=ERROR -p "${REMOTE_SSH_PORT:-22}" \
                            "${REMOTE_USER:-root}@${REMOTE_HOST}" "$tag_cmd" >/dev/null 2>&1
                        tag_exit_code=$?
                    elif [[ -n "${REMOTE_PASS:-}" ]] && command -v sshpass >/dev/null 2>&1; then
                        sshpass -p "${REMOTE_PASS}" ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR -p "${REMOTE_SSH_PORT:-22}" \
                            "${REMOTE_USER:-root}@${REMOTE_HOST}" "$tag_cmd" >/dev/null 2>&1
                        tag_exit_code=$?
                    else
                        ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR -p "${REMOTE_SSH_PORT:-22}" \
                            "${REMOTE_USER:-root}@${REMOTE_HOST}" "$tag_cmd" >/dev/null 2>&1
                        tag_exit_code=$?
                    fi
                    set -e
                    
                    if [[ $tag_exit_code -eq 0 ]]; then
                        echo "  ✅ 已标记为本地镜像: $local_ref"
                    else
                        warn "  标记本地镜像失败，但拉取成功"
                    fi
                fi
            fi
            
            success_count=$((success_count + 1))
        else
            err "$img_ref 拉取失败"
            if [[ -n "$pull_output" ]]; then
                echo "  错误信息:"
                echo "$pull_output" | tail -10 | sed 's/^/    /'
            else
                echo "  退出码: $pull_exit_code"
            fi
            fail_count=$((fail_count + 1))
        fi
        echo ""
    done
    
    echo "================================"
    echo "拉取完成: 成功 $success_count 个，失败 $fail_count 个"
    
    if [[ $fail_count -gt 0 ]]; then
        return 1
    fi
}

# 测试连接
test_connection() {
    load_config || return 1
    
    echo ""
    echo "🔍 测试连接"
    echo "================================"
    
    # 测试远程节点连接
    if [[ -n "${REMOTE_HOST:-}" ]]; then
        echo "测试远程节点连接: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_SSH_PORT}"
        local ssh_opts="-o StrictHostKeyChecking=no -o ConnectTimeout=5"
        
        if [[ -n "${REMOTE_SECRET:-}" ]] && [[ -f "${REMOTE_SECRET}" ]]; then
            if ssh -i "${REMOTE_SECRET}" $ssh_opts -p "${REMOTE_SSH_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" "echo OK" 2>/dev/null; then
                ok "远程节点 SSH 连接成功"
            else
                err "远程节点 SSH 连接失败"
            fi
        elif [[ -n "${REMOTE_PASS:-}" ]]; then
            if command -v sshpass >/dev/null 2>&1; then
                if sshpass -p "${REMOTE_PASS}" ssh $ssh_opts -p "${REMOTE_SSH_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" "echo OK" 2>/dev/null; then
                    ok "远程节点 SSH 连接成功"
                else
                    err "远程节点 SSH 连接失败"
                fi
            else
                warn "未安装 sshpass，无法使用密码连接"
            fi
        else
            warn "未配置 SSH 密钥或密码"
        fi
        
        # 测试远程节点 nerdctl
        echo ""
        echo "测试远程节点 nerdctl..."
        if [[ -n "${REMOTE_SECRET:-}" ]] && [[ -f "${REMOTE_SECRET}" ]]; then
            if ssh -i "${REMOTE_SECRET}" $ssh_opts -p "${REMOTE_SSH_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" "command -v ${NERDCTL_BIN:-nerdctl}" >/dev/null 2>&1; then
                ok "远程节点 nerdctl 可用"
            else
                err "远程节点 nerdctl 不可用"
            fi
        fi
    else
        warn "未配置 REMOTE_HOST"
    fi
    
    # 测试 Registry 连接
    if [[ -n "${REGISTRY_URL:-}" ]]; then
        echo ""
        echo "测试 Registry 连接: ${REGISTRY_URL}"
        local protocol="https"
        [[ "${REGISTRY_TLS_VERIFY:-false}" == "false" ]] && curl_opts="-k" || curl_opts=""
        
        if curl -sfS $curl_opts "${protocol}://${REGISTRY_URL}/v2/" >/dev/null 2>&1; then
            ok "Registry 连接成功"
        else
            warn "Registry 连接失败（可能正常，如果 Registry 需要认证）"
        fi
    else
        warn "未配置 REGISTRY_URL"
    fi
    
    echo ""
    echo "测试完成"
}

# 显示状态信息
show_status() {
    load_config || return 1
    
    echo ""
    echo "📊 系统状态"
    echo "================================"
    
    # 本地目录
    echo "=== 本地环境 ==="
    if [[ -n "${LOCAL_IMAGE_DIR:-}" ]] && [[ -d "${LOCAL_IMAGE_DIR}" ]]; then
        local count=$(find "${LOCAL_IMAGE_DIR}" -maxdepth 1 -type f \( -name "*.tar" -o -name "*.tar.gz" \) 2>/dev/null | wc -l)
        local size=$(du -sh "${LOCAL_IMAGE_DIR}" 2>/dev/null | cut -f1)
        echo "本地镜像目录: ${LOCAL_IMAGE_DIR}"
        echo "  镜像文件数: $count"
        echo "  目录大小: $size"
    else
        echo "本地镜像目录: ${LOCAL_IMAGE_DIR:-未设置}"
        warn "  目录不存在"
    fi
    
    # 远程节点
    echo ""
    echo "=== 远程节点 ==="
    if [[ -n "${REMOTE_HOST:-}" ]]; then
        echo "远程节点: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_SSH_PORT}"
        echo "  镜像目录: ${REMOTE_IMAGE_DIR}"
    else
        echo "远程节点: 未配置"
    fi
    
    # Registry
    echo ""
    echo "=== Registry ==="
    if [[ -n "${REGISTRY_URL:-}" ]]; then
        echo "Registry: ${REGISTRY_URL}"
        echo "  项目: ${PROJECT_NAME}"
        echo "  用户名: ${REGISTRY_USERNAME:-未设置}"
    else
        echo "Registry: 未配置"
    fi
    
    echo "================================"
}

# 主菜单
show_main_menu() {
    while true; do
        echo ""
        echo "🐳 镜像推送管理工具 (当前集群: $CURRENT_CLUSTER)"
        echo "================================"
        echo "=== 集群管理 ==="
        echo "c. 切换集群"
        echo ""
        echo "=== 配置管理 ==="
        echo "1. 查看配置"
        echo "2. 编辑配置"
        echo ""
        echo "=== 推送操作 ==="
        echo "3. 推送镜像"
        echo "4. 拉取镜像"
        echo ""
        echo "0. 退出"
        echo "================================"
        read -p "请选择 (0-4, c): " choice
        
        case "$choice" in
            0)
                echo "👋 退出"
                break
                ;;
            c|C)
                select_cluster
                read -p "按回车键继续..."
                ;;
            1)
                show_config
                read -p "按回车键继续..."
                ;;
            2)
                config_menu
                ;;
            3)
                push_images
                read -p "按回车键继续..."
                ;;
            4)
                pull_images
                read -p "按回车键继续..."
                ;;
            *)
                err "无效选择"
                ;;
        esac
    done
}

# 主函数
main() {
    # 使用解析后的参数（已移除 --cluster/-c 参数）
    # MAIN_ARGS 在脚本开头已经设置（如果解析了参数）
    local command="${MAIN_ARGS[0]:-}"
    
    case "$command" in
        -h|--help)
            cat <<EOF
镜像推送管理工具 - 菜单式管理界面

用法:
  $0                      # 显示主菜单（使用默认集群）
  $0 --cluster C1         # 指定集群 C1 并显示主菜单
  $0 -c C2                # 指定集群 C2 并显示主菜单
  $0 --cluster=C1         # 指定集群 C1（等号形式）
  $0 -h|--help            # 显示帮助

参数:
  --cluster, -c           指定集群（C1, C2, C3）
                          如果不指定，使用环境变量 CURRENT_CLUSTER 或全局默认值（当前：C2）

功能:
  - 配置管理：查看和编辑所有配置项
  - 镜像推送：从本地镜像目录选择并推送镜像（支持单个、多个或全部）
  - 连接测试：测试远程节点和 Registry 连接
  - 状态查看：查看本地和远程环境状态

示例:
  # 使用默认集群 C2
  $0

  # 指定集群 C1
  $0 --cluster C1
  $0 -c C1

EOF
            ;;
        "")
            # 检查工具是否存在
            if [[ ! -f "$LOADIMAGE_TOOL" ]]; then
                err "工具脚本不存在: $LOADIMAGE_TOOL"
                exit 1
            fi
            
            # 检查配置文件
            if [[ ! -f "$CONF_FILE" ]]; then
                warn "配置文件不存在，将创建默认配置"
                save_config
            fi
            
            show_main_menu
            ;;
        *)
            err "未知参数: $command"
            echo "使用 $0 -h 查看帮助"
            exit 1
            ;;
    esac
}

# 执行主函数
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    # 使用解析后的参数（已移除 --cluster/-c 参数）
    # MAIN_ARGS 在参数解析时已经设置（即使为空数组）
    # 如果解析了参数，MAIN_ARGS 可能为空（表示没有其他参数，只指定了集群）
    # 如果没解析参数，MAIN_ARGS 也为空，使用原始参数
    if [[ $# -gt 0 ]]; then
        # 有参数传入，使用解析后的参数（MAIN_ARGS）
        main "${MAIN_ARGS[@]}"
    else
        # 没有参数，直接调用
        main
    fi
fi

