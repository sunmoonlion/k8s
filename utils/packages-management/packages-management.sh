#!/bin/bash

# =============================================================================
# deb包和镜像构建脚本
# 文件名: debs-images-build.sh
# 用途: 构建 deb 包和 Docker 镜像，并传输到远程服务器
# =============================================================================

set -euo pipefail

# 设置环境变量以避免 locale 警告
export LC_ALL=C
export LANG=C
export LANGUAGE=C

# 上传 tar 包到服务器（两步选择：文件与服务器）
upload_tars_to_servers() {
    echo "📤 上传 tar 包到服务器..."

    # 本地 tar 目录
    if [[ -z "${TARS_DIR:-}" ]]; then TARS_DIR="$HOME/packages-to-be-installed/tars"; fi
    mkdir -p "$TARS_DIR" >/dev/null 2>&1 || true
    if [[ ! -d "$TARS_DIR" ]]; then
        echo "❌ 未找到 tar 源目录: $TARS_DIR"; return 1
    fi

    # 构建 tar 列表
    local tar_files=()
    for f in "$TARS_DIR"/*; do [[ -f "$f" ]] && tar_files+=("$(basename "$f")"); done
    if [[ ${#tar_files[@]} -eq 0 ]]; then echo "❌ 没有找到可上传的 tar 文件"; return 1; fi

    echo "📦 可用的 tar 文件："
    echo "================================"
    for i in $(seq 0 $((${#tar_files[@]}-1))); do
        local file="${tar_files[i]}"; local size=$(du -h "$TARS_DIR/$file" | cut -f1); local date=$(stat -c %y "$TARS_DIR/$file" | cut -d' ' -f1)
        echo "$((i+1)). $file ($size, 创建时间: $date)"
    done
    echo "================================"
    read -p "请输入要上传的 tar 序号（空格分隔多个序号，如：1 2），输入 all 选择全部：
tar 序号: " selected_indices

    local files_to_upload=()
    if [[ "$selected_indices" == "all" ]]; then
        files_to_upload=("${tar_files[@]}")
    else
        for idx in $selected_indices; do
            if [[ "$idx" =~ ^[0-9]+$ ]] && (( idx >= 1 && idx <= ${#tar_files[@]} )); then
                files_to_upload+=("${tar_files[$((idx-1))]}")
            else
                echo "⚠️ 无效序号: $idx，已跳过"
            fi
        done
    fi
    [[ ${#files_to_upload[@]} -eq 0 ]] && { echo "❌ 未选择任何文件"; return 1; }

    # 读取服务器（环境 -> 文件 -> deploy.conf 自动发现）
    local servers=()
    if [[ -n "${SERVERS_FILE:-}" && -f "$SERVERS_FILE" ]]; then
        mapfile -t servers < "$SERVERS_FILE"
    elif [[ -n "${SERVERS_LIST:-}" ]]; then
        IFS=',' read -ra servers <<< "$SERVERS_LIST"
    else
        local dc="/home/zouyaming/toolboxes/k8s-deploy/config/deploy.conf"
        if [[ -f "$dc" ]]; then source "$dc"; fi
        local idx=1
        while true; do
            local host_var="SERVER_${idx}_PUBLIC_IP"; local user_var="SERVER_${idx}_USER"; local port_var="SERVER_${idx}_SSH_PORT"; local dir_var="SERVER_${idx}_DIR"
            local host="${!host_var-}"; local user="${!user_var-}"; local port="${!port_var-}"; local rdir="${!dir_var-}"
            [[ -z "$host" ]] && break
            [[ -z "$user" ]] && user="root"
            [[ -z "$port" ]] && port=22
            [[ -z "$rdir" ]] && rdir="~/packages-to-be-installed/tars"
            servers+=("$host|$user|$port|$rdir")
            idx=$((idx+1))
        done
    fi
    if [[ ${#servers[@]} -eq 0 ]]; then echo "❌ 未配置服务器列表"; return 1; fi

    echo "🌐 可用服务器："
    for i in $(seq 0 $((${#servers[@]}-1))); do
        IFS='|' read -r h u p d <<<"${servers[i]}"; echo "$((i+1)). $h (用户: $u, 端口: $p)"
    done
    read -p "输入要上传的服务器序号（空格分隔，all=全部）: " selected_srv
    local srv_to_use=()
    if [[ "$selected_srv" == "all" ]]; then srv_to_use=("${servers[@]}"); else
        for idx in $selected_srv; do
            if [[ "$idx" =~ ^[0-9]+$ ]] && (( idx >= 1 && idx <= ${#servers[@]} )); then srv_to_use+=("${servers[$((idx-1))]}"); else echo "⚠️ 无效序号: $idx"; fi
        done
    fi
    [[ ${#srv_to_use[@]} -eq 0 ]] && { echo "❌ 未选择服务器"; return 1; }

    ensure_pv >/dev/null 2>&1 || true
    local timeout_seconds=3600

    for s in "${srv_to_use[@]}"; do
        IFS='|' read -r host user port rdir <<<"$s"
        echo "➡️ 正在上传到 $host (用户: $user, 端口: $port) ..."
        # 确保远端目录树
        local base_dir
        base_dir="${rdir%/tars}"
        [[ -z "$base_dir" || "$base_dir" == "$rdir" ]] && base_dir="~/packages-to-be-installed"
        
        # 创建远程目录，确保路径正确解析
        ssh -o StrictHostKeyChecking=no -p "$port" "$user@$host" "bash -lc 'bd=$base_dir; case \"\$bd\" in ~*) bd=\"\$HOME\${bd#\~}\" ;; /home/zouyaming*) bd=\"/home/$user\${bd#/home/zouyaming}\" ;; esac; mkdir -p \"\$bd\"/tars \"\$bd\"/debs \"\$bd\"/images \"\$bd\"/charts'" >/dev/null 2>&1 || true
        echo "  📂 已确保远端目录: $base_dir/{tars,debs,images,charts}"

        for f in "${files_to_upload[@]}"; do
            local local_path="$TARS_DIR/$f"; local size_bytes=$(stat -c%s "$local_path" 2>/dev/null || echo 0)
            echo "    📤 $f..."
            # 预检 SSH 连通性
            if ! ssh -o ConnectTimeout=6 -o StrictHostKeyChecking=no -p "$port" "$user@$host" "echo ok" >/dev/null 2>&1; then
                echo "      ❌ 无法连接 $host:$port（SSH 预检失败）"
                continue
            fi
            local success=false
            
            # 获取正确的远程目录路径
            local remote_dir
            # 检查路径是否包含本地用户名，如果是则替换为远程用户名
            if [[ "$rdir" == /home/zouyaming* ]]; then
                remote_dir="/home/$user${rdir#/home/zouyaming}"
            elif [[ "$rdir" == ~* ]]; then
                remote_dir="/home/$user${rdir#\~}"
            else
                remote_dir="$rdir"
            fi
            
            # 尝试使用 pv 显示进度，如果失败则使用 scp
            if command -v pv >/dev/null 2>&1 && [[ $size_bytes -gt 0 ]]; then
                echo "      📶 进度传输（pv）..."
                if pv -s $size_bytes "$local_path" | ssh -o StrictHostKeyChecking=no -p "$port" "$user@$host" "cat > $remote_dir/tars/$f" > /tmp/upload_tars.log 2>&1; then
                    success=true
                else
                    echo "      ⚠️  pv 传输失败，回退到 scp..."
                    if scp -P "$port" -o LogLevel=ERROR "$local_path" "$user@$host:$remote_dir/tars/" > /tmp/upload_tars.log 2>&1; then
                        success=true
                    fi
                fi
            else
                # 直接使用 scp
                if scp -P "$port" -o LogLevel=ERROR "$local_path" "$user@$host:$remote_dir/tars/" > /tmp/upload_tars.log 2>&1; then
                    success=true
                else
                    echo "      ⚠️  scp 上传失败，尝试备用方法..."
                    # 备用方法：使用 rsync（如果可用）
                    if command -v rsync >/dev/null 2>&1; then
                        echo "      🔄 使用 rsync 上传到: $user@$host:$remote_dir/tars/"
                        if rsync -avz -e "ssh -p $port" "$local_path" "$user@$host:$remote_dir/tars/" > /tmp/upload_tars.log 2>&1; then
                            success=true
                        fi
                    fi
                fi
            fi
            if [[ "$success" == true ]]; then
                local lbytes=$(stat -c%s "$local_path" 2>/dev/null || echo 0)
                local rbytes=$(ssh -o StrictHostKeyChecking=no -p "$port" "$user@$host" "stat -c%s '$remote_dir/tars/$f' 2>/dev/null" || echo 0)
                if [[ "$lbytes" == "$rbytes" && "$rbytes" != "0" ]]; then
                    echo "      ✅ $f 上传成功（校验通过）"
                else
                    echo "      ⚠️  $f 上传完成但校验不通过（本地: $lbytes, 远端: $rbytes）"
                fi
            else
                echo "      ❌ $f 上传失败"
                echo "      📋 错误日志："; tail -n 50 /tmp/upload_tars.log 2>/dev/null || echo "      无法获取错误日志"
            fi
        done
        echo "  ✅ 服务器 $host tar 上传完成"
    done

    echo "🎉 所有服务器 tar 上传完成！"
}

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 加载配置文件（仅同级 packages.conf）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_CONF="$SCRIPT_DIR/packages.conf"
if [[ -f "$DEPLOY_CONF" ]]; then
    source "$DEPLOY_CONF"
else
    echo "❌ 未找到配置文件：$DEPLOY_CONF"
    echo "💡 请在脚本同目录创建 packages.conf"
fi

# 构建目录设置
BUILD_DIR="$HOME/packages-to-be-installed"
DEB_DIR="$BUILD_DIR/debs"
IMAGE_DIR="$BUILD_DIR/images"
CHART_DIR="$BUILD_DIR/charts"
WORK_DIR="$BUILD_DIR/work"
TARS_DIR="$BUILD_DIR/tars"

# 下载重试策略（可通过环境变量覆盖）
RETRY_ENABLED=${RETRY_ENABLED:-true}
RETRY_COUNT=${RETRY_COUNT:-3}
RETRY_DELAY=${RETRY_DELAY:-2}
# 上传调试开关（true/false）。为 true 时打印更详尽的调试信息并启用 scp -v
UPLOAD_DEBUG=${UPLOAD_DEBUG:-false}
UPLOAD_USE_SCP_PROGRESS=${UPLOAD_USE_SCP_PROGRESS:-false}

# 确保 pv 可用：用于上传进度条
ensure_pv() {
    if command -v pv >/dev/null 2>&1; then
        return 0
    fi
    echo "⏳ 正在安装 pv 以显示上传进度..."
    if command -v apt-get >/dev/null 2>&1; then
        if [ "$(id -u)" -eq 0 ]; then
            apt-get update -y >/dev/null 2>&1 && apt-get install -y pv >/dev/null 2>&1 || true
        else
            sudo -n apt-get update -y >/dev/null 2>&1 && sudo -n apt-get install -y pv >/dev/null 2>&1 || true
        fi
    fi
    if command -v pv >/dev/null 2>&1; then
        echo "✅ pv 已就绪"
        return 0
    else
        echo "⚠️ 未能自动安装 pv，将使用备用方式（无进度条）"
        return 1
    fi
}

# 用户输入的包和镜像列表
USER_PACKAGES=()
USER_IMAGES=()

 

# =============================================================================
# 构建功能
# =============================================================================

# 检查构建依赖
check_build_dependencies() {
    echo "🔍 检查构建依赖..."
    
    local missing_tools=()
    local required_tools=("dpkg-deb" "wget" "curl" "tar" "gzip")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo "❌ 缺少必要工具: ${missing_tools[*]}"
        echo "💡 请安装: sudo apt-get install ${missing_tools[*]}"
        return 1
    fi
    
    # 检查sudo权限
    if ! sudo -n true 2>/dev/null; then
        echo "⚠️  需要sudo权限，请确保当前用户有sudo权限"
        echo "💡 如果遇到权限问题，请运行: sudo visudo"
    fi
    
    echo "✅ 依赖检查通过"
    return 0
}

# 初始化构建目录
init_build_directories() {
    echo "🔧 初始化构建目录..."
    
    # 创建主构建目录
    if [ ! -d "$BUILD_DIR" ]; then
        mkdir -p "$BUILD_DIR"
        echo "✅ 创建构建目录: $BUILD_DIR"
    else
        echo "✅ 构建目录已存在: $BUILD_DIR"
    fi
    
    # 创建deb包目录
    if [ ! -d "$DEB_DIR" ]; then
        mkdir -p "$DEB_DIR"
        echo "✅ 创建deb包目录: $DEB_DIR"
    else
        echo "✅ deb包目录已存在: $DEB_DIR"
    fi
    
    # 创建镜像包目录
    if [ ! -d "$IMAGE_DIR" ]; then
        mkdir -p "$IMAGE_DIR"
        echo "✅ 创建镜像包目录: $IMAGE_DIR"
    else
        echo "✅ 镜像包目录已存在: $IMAGE_DIR"
    fi

    # 创建 helm chart 目录
    if [ ! -d "$CHART_DIR" ]; then
        mkdir -p "$CHART_DIR"
        echo "✅ 创建 chart 目录: $CHART_DIR"
    else
        echo "✅ chart 目录已存在: $CHART_DIR"
    fi
    
    # 创建 tar 源文件目录
    if [ ! -d "$TARS_DIR" ]; then
        mkdir -p "$TARS_DIR"
        echo "✅ 创建tar源目录: $TARS_DIR"
    else
        echo "✅ tar源目录已存在: $TARS_DIR"
    fi
    
    # 创建工作目录
    if [ ! -d "$WORK_DIR" ]; then
        mkdir -p "$WORK_DIR"
        echo "✅ 创建工作目录: $WORK_DIR"
    else
        echo "✅ 工作目录已存在: $WORK_DIR"
    fi
    

    
    # 切换到工作目录
    cd "$WORK_DIR"
    echo "📁 切换到工作目录: $WORK_DIR"
}

# 清理临时文件
cleanup_temp_files() {
    echo "🧹 清理临时文件..."
    
    # 清理工作目录中的临时文件
    if [[ -d "$WORK_DIR" ]]; then
        cd "$WORK_DIR"
        rm -rf temp_* *.tmp *.tar.gz *.deb 2>/dev/null || true
        echo "✅ 临时文件清理完成"
    fi
}

# 显示使用说明
show_usage() {
    cat << EOF
deb包和镜像构建脚本

使用方法:
    $0 [选项]

选项:
    -h, --help     显示此帮助信息
    -v, --version  显示脚本版本
    -b, --build    下载模式
    -u, --upload   上传模式
    --charts       Helm charts 菜单

功能说明:
    - 构建 deb 包和 Docker 镜像
    - 上传包到远程服务器
    - 支持代理配置
    - 分发镜像包到远端并在 k8s.io 加载后推送 Harbor

示例:
    $0 --build      # 下载模式
    $0 --upload     # 上传模式
    $0 --charts     # charts 子菜单
    $0 --help       # 显示帮助
EOF
}

# 显示版本信息
show_version() {
    echo "deb包和镜像构建脚本 v1.0.0"
    echo "支持构建 deb 包和 Docker 镜像"
    echo "支持传输到远程服务器"
}

# 保障 helm 可用
ensure_helm() {
    if command -v helm >/dev/null 2>&1; then return 0; fi
    echo "⏳ 未检测到 helm，尝试安装..."
    if command -v curl >/dev/null 2>&1; then
        if [ "$(id -u)" -eq 0 ]; then
            curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash || true
        else
            curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | sudo -n bash || true
        fi
    fi
    if command -v helm >/dev/null 2>&1; then
        echo "✅ helm 已就绪"; return 0
    fi
    echo "❌ 未能自动安装 helm"
    return 1
}

# 下载 helm charts 到本地 CHART_DIR
download_helm_charts() {
    echo "📥 下载 Helm charts 到本地..."
    ensure_helm || return 1
    init_build_directories >/dev/null 2>&1
    echo "输入格式：<repo/chart> <version>（示例：projectcalico/tigera-operator 3.28.2）"
    echo "多次输入可添加多个，直接回车结束"
    local pairs=()
    while true; do
        read -p "chart 与版本: " line
        [[ -z "$line" ]] && break
        pairs+=("$line")
    done
    [[ ${#pairs[@]} -eq 0 ]] && { echo "❌ 未输入任何 chart"; return 1; }
    mkdir -p "$CHART_DIR"
    local ok=0 fail=0
    
    # 预定义常用仓库
    local repos_added=()
    
    for item in "${pairs[@]}"; do
        local chart ver
        chart="$(echo "$item" | awk '{print $1}')"; ver="$(echo "$item" | awk '{print $2}')"
        if [[ -z "$chart" || -z "$ver" ]]; then echo "⚠️  忽略无效输入: $item"; continue; fi
        
        # 提取仓库名称
        local repo_name
        repo_name="$(echo "$chart" | cut -d'/' -f1)"
        
        # 自动添加常用仓库
        case "$repo_name" in
            projectcalico)
                if [[ ! " ${repos_added[*]} " =~ " projectcalico " ]]; then
                    echo "⏳ 添加 Calico 仓库..."
                    helm repo add projectcalico https://projectcalico.docs.tigera.io/charts || true
                    repos_added+=("projectcalico")
                fi
                ;;
            nfs-subdir-external-provisioner)
                if [[ ! " ${repos_added[*]} " =~ " nfs-subdir-external-provisioner " ]]; then
                    echo "⏳ 添加 NFS Subdir External Provisioner 仓库..."
                    helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/ || true
                    repos_added+=("nfs-subdir-external-provisioner")
                fi
                ;;
            flannel)
                if [[ ! " ${repos_added[*]} " =~ " flannel " ]]; then
                    echo "⏳ 添加 Flannel 仓库..."
                    helm repo add flannel https://flannel-io.github.io/flannel || true
                    repos_added+=("flannel")
                fi
                ;;
            cilium)
                if [[ ! " ${repos_added[*]} " =~ " cilium " ]]; then
                    echo "⏳ 添加 Cilium 仓库..."
                    helm repo add cilium https://helm.cilium.io || true
                    repos_added+=("cilium")
                fi
                ;;
            weaveworks)
                if [[ ! " ${repos_added[*]} " =~ " weaveworks " ]]; then
                    echo "⏳ 添加 Weave 仓库..."
                    helm repo add weaveworks https://weaveworks.github.io/weave || true
                    repos_added+=("weaveworks")
                fi
                ;;
        esac
        
        echo "⏳ helm pull $chart --version $ver"
        if helm pull "$chart" --version "$ver" --destination "$CHART_DIR"; then 
            ok=$((ok+1)); echo "✅ $chart@$ver"
        else 
            fail=$((fail+1)); echo "❌ $chart@$ver"
        fi
    done
    echo "📊 结果：成功 $ok 个，失败 $fail 个"
}

# 选择 charts 并远程 helm 安装（helm upgrade --install）
remote_helm_install_on_servers() {
    echo "🧩 远程安装 Helm charts..."
    ensure_helm || true
    init_build_directories >/dev/null 2>&1
    if [[ ! -d "$CHART_DIR" ]]; then echo "❌ 未找到 chart 目录: $CHART_DIR"; return 1; fi
    local charts=()
    while IFS= read -r f; do charts+=("$(basename "$f")"); done < <(find "$CHART_DIR" -maxdepth 1 -type f \( -name "*.tgz" -o -name "*.tar.gz" \))
    if [[ ${#charts[@]} -eq 0 ]]; then echo "❌ 本地无 charts 包"; return 1; fi
    echo "📦 可用 charts 包："; for i in $(seq 0 $((${#charts[@]}-1))); do echo "$((i+1)). ${charts[i]}"; done
    read -p "请选择要安装的 charts 序号（空格分隔，all 为全部）: " idxs
    local chosen=(); if [[ "$idxs" == "all" ]]; then chosen=("${charts[@]}"); else IFS=' ' read -ra IDS <<< "$idxs"; for id in "${IDS[@]}"; do [[ "$id" =~ ^[0-9]+$ ]] && [[ "$id" -ge 1 ]] && [[ "$id" -le ${#charts[@]} ]] && chosen+=("${charts[id-1]}") || echo "⚠️ 忽略: $id"; done; fi
    [[ ${#chosen[@]} -eq 0 ]] && { echo "❌ 未选择 chart"; return 1; }
    # 选择 release 名与命名空间
    read -p "请输入 release 名称（默认 chart 名去后缀）: " rel_input
    read -p "请输入命名空间（默认 kube-system）: " ns_input
    local ns="${ns_input:-kube-system}"
    # 选择服务器
    local server_count=$(get_server_count); [[ "$server_count" -eq 0 ]] && { echo "❌ 未配置服务器"; return 1; }
    echo "🖥️  可用服务器："; for i in $(seq 1 "$server_count"); do eval hip="\$SERVER_${i}_PUBLIC_IP"; echo "$i. $hip"; done
    read -p "请输入服务器序号（空格分隔，all 为全部）: " sidx
    local servers=(); if [[ "$sidx" == "all" ]]; then for i in $(seq 1 "$server_count"); do servers+=("$i"); done; else IFS=' ' read -ra SIDS <<< "$sidx"; for id in "${SIDS[@]}"; do [[ "$id" =~ ^[0-9]+$ ]] && [[ "$id" -ge 1 ]] && [[ "$id" -le "$server_count" ]] && servers+=("$id") || echo "⚠️ 忽略: $id"; done; fi
    [[ ${#servers[@]} -eq 0 ]] && { echo "❌ 未选择服务器"; return 1; }
    # 逐台：上传 chart 到 /tmp 并执行 helm upgrade --install
    for i in "${servers[@]}"; do
        eval host="\$SERVER_${i}_PUBLIC_IP"; eval user="\$SERVER_${i}_USER"; eval pass="\${SERVER_${i}_PASS-}"; eval secret="\${SERVER_${i}_SECRET-}"; eval port="\${SERVER_${i}_SSH_PORT-1022}"
        echo "🖥️  服务器 $host:"
        for pkg in "${chosen[@]}"; do
            local local_pkg="$CHART_DIR/$pkg"; local remote_pkg="/tmp/$pkg"
            echo "  📤 上传 $pkg ..."
            if [[ -n "$secret" && -f "$secret" ]]; then
                scp -P "$port" -i "$secret" -o StrictHostKeyChecking=no "$local_pkg" "$user@$host:$remote_pkg" || { echo "  ❌ 传输失败 $pkg"; continue; }
                ssh -p "$port" -i "$secret" -o StrictHostKeyChecking=no "$user@$host" "helm version >/dev/null 2>&1 || curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | sudo -n bash || true"
                local rel_name="${rel_input:-${pkg%%-*}}"
                echo "  🚀 安装: helm upgrade --install $rel_name $remote_pkg -n $ns --create-namespace"
                ssh -p "$port" -i "$secret" -o StrictHostKeyChecking=no "$user@$host" "helm upgrade --install '$rel_name' '$remote_pkg' -n '$ns' --create-namespace"
            else
                sshpass -p "$pass" scp -P "$port" -o StrictHostKeyChecking=no "$local_pkg" "$user@$host:$remote_pkg" || { echo "  ❌ 传输失败 $pkg"; continue; }
                sshpass -p "$pass" ssh -p "$port" -o StrictHostKeyChecking=no "$user@$host" "helm version >/dev/null 2>&1 || (echo '$pass' | sudo -S sh -c 'curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash') || true"
                local rel_name="${rel_input:-${pkg%%-*}}"
                echo "  🚀 安装: helm upgrade --install $rel_name $remote_pkg -n $ns --create-namespace"
                sshpass -p "$pass" ssh -p "$port" -o StrictHostKeyChecking=no "$user@$host" "helm upgrade --install '$rel_name' '$remote_pkg' -n '$ns' --create-namespace"
            fi
        done
    done
}
# 上传 charts 到服务器（DIR/charts）
upload_charts_to_servers() {
    echo "📤 上传 charts 到服务器..."
    init_build_directories >/dev/null 2>&1
    if [[ ! -d "$CHART_DIR" ]]; then echo "❌ 未找到 chart 目录: $CHART_DIR"; return 1; fi
    local chart_files=()
    while IFS= read -r f; do chart_files+=("$(basename "$f")"); done < <(find "$CHART_DIR" -maxdepth 1 -type f \( -name "*.tgz" -o -name "*.tar.gz" \))
    if [[ ${#chart_files[@]} -eq 0 ]]; then echo "❌ 没有可上传的 chart 包"; return 1; fi
    echo "📦 可用的 chart 包："; for i in $(seq 0 $((${#chart_files[@]}-1))); do f="${chart_files[i]}"; sz=$(du -h "$CHART_DIR/$f" | cut -f1); echo "$((i+1)). $f ($sz)"; done
    read -p "请输入要上传的 chart 序号（空格分隔，all 为全部）: " idxs
    local chosen=()
    if [[ "$idxs" == "all" ]]; then chosen=("${chart_files[@]}"); else IFS=' ' read -ra IDS <<< "$idxs"; for id in "${IDS[@]}"; do [[ "$id" =~ ^[0-9]+$ ]] && [[ "$id" -ge 1 ]] && [[ "$id" -le ${#chart_files[@]} ]] && chosen+=("${chart_files[id-1]}") || echo "⚠️ 忽略: $id"; done; fi
    [[ ${#chosen[@]} -eq 0 ]] && { echo "❌ 未选择有效 chart"; return 1; }
    local server_count=$(get_server_count); [[ "$server_count" -eq 0 ]] && { echo "❌ 未配置服务器"; return 1; }
    echo "🖥️  可用服务器："; for i in $(seq 1 "$server_count"); do eval hip="\$SERVER_${i}_PUBLIC_IP"; eval usr="\$SERVER_${i}_USER"; echo "$i. $hip (用户: $usr)"; done
    read -p "请输入服务器序号（空格分隔，all 为全部）: " sidx
    local servers=(); if [[ "$sidx" == "all" ]]; then for i in $(seq 1 "$server_count"); do servers+=("$i"); done; else IFS=' ' read -ra SIDS <<< "$sidx"; for id in "${SIDS[@]}"; do [[ "$id" =~ ^[0-9]+$ ]] && [[ "$id" -ge 1 ]] && [[ "$id" -le "$server_count" ]] && servers+=("$id") || echo "⚠️  忽略: $id"; done; fi
    [[ ${#servers[@]} -eq 0 ]] && { echo "❌ 未选择服务器"; return 1; }
    for i in "${servers[@]}"; do
        eval host="\$SERVER_${i}_PUBLIC_IP"; eval user="\$SERVER_${i}_USER"; eval pass="\${SERVER_${i}_PASS-}"; eval secret="\${SERVER_${i}_SECRET-}"; eval port="\${SERVER_${i}_SSH_PORT-1022}"; eval dir="\${SERVER_${i}_DIR-~/packages-to-be-installed}"
        echo "🖥️  上传到 $host..."
        # 生成远端脚本，避免本地提前展开 ${base#~}
        local _mk
        _mk=$(cat <<'EOS'
base='__BASE__'
if [ "${base#~}" != "$base" ]; then base="$HOME${base#~}"; fi
mkdir -p "$base/debs" "$base/images" "$base/tars" "$base/charts"
EOS
)
        _mk="${_mk//__BASE__/$dir}"
        # 通过 base64 传输远端脚本执行
        local _mk_b64; _mk_b64=$(printf '%s' "$_mk" | base64 -w0)
        if [[ -n "$secret" && -f "$secret" ]]; then
            ssh -i "$secret" -o StrictHostKeyChecking=no -p "$port" "$user@$host" "echo $_mk_b64 | base64 -d | bash"
        else
            sshpass -p "$pass" ssh -o StrictHostKeyChecking=no -p "$port" "$user@$host" "echo $_mk_b64 | base64 -d | bash"
        fi
        for f in "${chosen[@]}"; do
            echo "  📤 $f"
            if [[ -n "$secret" && -f "$secret" ]]; then
                scp -i "$secret" -o LogLevel=ERROR -o StrictHostKeyChecking=no -P "$port" "$CHART_DIR/$f" "$user@$host:$dir/charts/"
                scp -i "$secret" -o LogLevel=ERROR -o StrictHostKeyChecking=no -P "$port" "$CHART_DIR/$f" "$user@$host:~/packages-to-be-installed/charts/" || true
            else
                sshpass -p "$pass" scp -o LogLevel=ERROR -o StrictHostKeyChecking=no -P "$port" "$CHART_DIR/$f" "$user@$host:$dir/charts/"
                sshpass -p "$pass" scp -o LogLevel=ERROR -o StrictHostKeyChecking=no -P "$port" "$CHART_DIR/$f" "$user@$host:~/packages-to-be-installed/charts/" || true
            fi
        done
        echo "  ✅ 服务器 $host charts 上传完成"
    done
    echo "🎉 所有选定服务器 charts 上传完成！"
}

# charts 子菜单
charts_menu() {
    while true; do
        echo ""; echo "📦 Helm charts 菜单"; echo "================================";
        echo "1. 下载 charts 到本地 ($CHART_DIR)"; echo "2. 上传 charts 到服务器 (DIR/charts)"; echo "0. 返回"; echo "";
        read -p "请选择 (0-2): " ch
        case "$ch" in
            0) break ;;
            1) download_helm_charts ;;
            2) upload_charts_to_servers ;;
            *) echo "❌ 无效选择" ;;
        esac
    done
}

# =============================================================================
# 构建功能
# =============================================================================

# 获取用户输入
get_user_input() {
    local input_type="$1"
    
    if [[ "$input_type" == "packages" ]]; then
        echo ""
        echo "📦 请输入要构建的包（APT 模式：包名[:架构] [版本]；包含 URL 的请用"下载 tar 包"）"
        echo "💡 提示：可输入短版本（如 1.29），脚本将列出可用完整版本供选择"
        echo "================================"
        echo "输入包名后按回车，直接按回车键完成输入"
        echo "================================"
        
        USER_PACKAGES=()
        while true; do
            read -p "请输入包名: " package_input
            
            if [[ -n "$package_input" ]]; then
                USER_PACKAGES+=("$package_input")
                echo "✅ 已添加: $package_input"
            else
                break
            fi
        done
        
        if [[ ${#USER_PACKAGES[@]} -eq 0 ]]; then
            echo "⚠️ 未输入任何包"
            return 1
        fi
        
        echo "📦 已添加 ${#USER_PACKAGES[@]} 个包"
        return 0
    elif [[ "$input_type" == "images" ]]; then
        echo ""
        echo "🐳 请输入要构建的镜像"
        echo "================================"
        echo "输入镜像名后按回车，直接按回车键完成输入"
        echo "================================"
        
        USER_IMAGES=()
        while true; do
            read -p "请输入镜像名: " image_input
            
            if [[ -n "$image_input" ]]; then
                USER_IMAGES+=("$image_input")
                echo "✅ 已添加: $image_input"
            else
                break
            fi
        done
        
        if [[ ${#USER_IMAGES[@]} -eq 0 ]]; then
            echo "⚠️ 未输入任何镜像"
            return 1
        fi
        
        echo "🐳 已添加 ${#USER_IMAGES[@]} 个镜像"
        return 0
    elif [[ "$input_type" == "tars" ]]; then
        echo ""
        echo "📥 请输入要下载的 tar 包信息"
        echo "================================"
        echo "格式：包名 版本 URL [tar内路径]，或 包名 URL"
        echo "例如：kubeadm https://dl.k8s.io/release/v1.28.0/kubernetes-node-linux-amd64.tar.gz"
        echo "================================"
        USER_TARS=()
        while true; do
            read -p "请输入（空行结束）: " tar_input
            if [[ -n "$tar_input" ]]; then
                USER_TARS+=("$tar_input")
                echo "✅ 已添加: $tar_input"
            else
                break
            fi
        done
        if [[ ${#USER_TARS[@]} -eq 0 ]]; then
            echo "⚠️ 未输入任何 tar 下载项"
            return 1
        fi
        echo "📥 已添加 ${#USER_TARS[@]} 个下载项"
        return 0
    fi
}

# 构建 deb 包
build_deb_packages() {
    echo "🔨 构建 deb 包..."
    
    # 检查依赖
    if ! check_build_dependencies >/dev/null 2>&1; then
        echo "❌ 依赖检查失败，退出构建"
        return 1
    fi
    
    # 确保目录存在
    init_build_directories >/dev/null 2>&1
    
    # 获取用户输入
    if get_user_input "packages"; then
        # 构建包
        local failed_packages=()
        local success_packages=()
        
        echo "⏳ 正在开始构建，请稍候..."
        for package in "${USER_PACKAGES[@]}"; do
            if ! build_simple_package "$package"; then
                failed_packages+=("$package")
                continue
            else
                success_packages+=("$package")
            fi
        done
        
        # 显示构建结果总结
        echo ""
        echo "📊 构建结果："
        
        if [[ ${#success_packages[@]} -gt 0 ]]; then
            echo "✅ 构建成功的包："
            for package in "${success_packages[@]}"; do
                echo "  📦 $package"
            done
        fi
        
        if [[ ${#failed_packages[@]} -gt 0 ]]; then
            echo ""
            echo "❌ 构建失败的包："
            for package in "${failed_packages[@]}"; do
                echo "  📦 $package（APT 下载失败，可尝试直接下载 tar 包）"
            done
        fi
        
        cleanup_temp_files >/dev/null 2>&1
        
        echo ""
        echo "🎉 构建完成！"
        echo "📁 deb 包位置: $DEB_DIR"
        
        # 显示构建的包列表
        if [[ -d "$DEB_DIR" ]]; then
            local deb_count=$(find "$DEB_DIR" -name "*.deb" -type f | wc -l)
            if [[ "$deb_count" -gt 0 ]]; then
                echo "📦 构建的包列表："
                find "$DEB_DIR" -name "*.deb" -type f -exec basename {} \;
            fi
        fi
    fi
}

# 构建 Docker 镜像
build_docker_images() {
    echo "🐳 构建 Docker 镜像..."
    
    # 确保目录存在
    init_build_directories >/dev/null 2>&1
    
    # 获取用户输入
    if get_user_input "images"; then
        # 构建镜像
        echo "⏳ 正在下载镜像并打包，请稍候..."
        local success_images=()
        local failed_images=()
        for image in "${USER_IMAGES[@]}"; do
            local image_name=""
            local image_version="latest"
            if [[ "$image" == *":"* ]]; then
                image_name=$(echo "$image" | cut -d: -f1)
                image_version=$(echo "$image" | cut -d: -f2)
            else
                image_name="$image"
            fi
            if build_image_package "$image_name" "$image_version"; then
                success_images+=("$image_name:$image_version")
            else
                failed_images+=("$image_name:$image_version")
            fi
        done

        # 清理临时文件
        cleanup_temp_files >/dev/null 2>&1

        # 构建结果
        echo ""
        echo "📊 镜像构建结果："
        if [[ ${#success_images[@]} -gt 0 ]]; then
            echo "✅ 成功："
            for img in "${success_images[@]}"; do
                echo "  - $img"
            done
        fi
        if [[ ${#failed_images[@]} -gt 0 ]]; then
            echo "❌ 失败："
            for img in "${failed_images[@]}"; do
                echo "  - $img"
            done
        fi

        echo "📁 镜像包位置: $IMAGE_DIR"
    fi
}

# 拉取 Docker 镜像（仅 pull 到本地，不打包）
pull_docker_images() {
    echo "🐳 拉取 Docker 镜像到本地..."
    init_build_directories >/dev/null 2>&1
    if get_user_input "images"; then
        local success_images=()
        local failed_images=()
        echo "⏳ 正在拉取镜像，请稍候..."
        for image in "${USER_IMAGES[@]}"; do
            local image_ref="$image"
            [[ "$image_ref" != *":"* ]] && image_ref="$image_ref:latest"
            if docker pull "$image_ref"; then
                success_images+=("$image_ref")
            else
                failed_images+=("$image_ref")
            fi
        done
        echo ""
        echo "📊 拉取结果："
        [[ ${#success_images[@]} -gt 0 ]] && { echo "✅ 成功："; for x in "${success_images[@]}"; do echo "  - $x"; done; }
        [[ ${#failed_images[@]} -gt 0 ]] && { echo "❌ 失败："; for x in "${failed_images[@]}"; do echo "  - $x"; done; }
        echo "🎉 完成！"
    fi
}



# 选择本地镜像进行打包并上传
package_local_images_to_tar() {
    echo "📦 镜像打包与上传..."
    init_build_directories >/dev/null 2>&1
    
    # 第一步：询问是否要先打包本地镜像
    echo ""
    read -p "是否要先打包本地Docker镜像？(y/N): " package_choice
    if [[ "$package_choice" =~ ^[Yy]$ ]]; then
        # 枚举本地镜像
        local images=()
        while IFS= read -r line; do
            images+=("$line")
        done < <(docker images --format '{{.Repository}}:{{.Tag}}' | grep -v "<none>" | sed 's/:$/:latest/')
        if [[ ${#images[@]} -eq 0 ]]; then
            echo "❌ 本地没有可打包的镜像"
            echo "💡 将直接列出已存在的镜像包..."
        else
            echo "📃 可选镜像："
            for i in $(seq 0 $((${#images[@]}-1))); do
                echo "$((i+1)). ${images[i]}"
            done
            read -p "请输入要打包的镜像序号（空格分隔，all 为全部）：" idxs
            local chosen=()
            if [[ "$idxs" == "all" ]]; then
                chosen=("${images[@]}")
            else
                IFS=' ' read -ra IDS <<< "$idxs"
                for id in "${IDS[@]}"; do
                    if [[ "$id" =~ ^[0-9]+$ ]] && [[ "$id" -ge 1 ]] && [[ "$id" -le ${#images[@]} ]]; then
                        chosen+=("${images[id-1]}")
                    else
                        echo "⚠️  忽略无效序号: $id"
                    fi
                done
            fi
            if [[ ${#chosen[@]} -gt 0 ]]; then
                # 打包镜像
                echo "⏳ 正在打包镜像为 tar，请稍候..."
                for ref in "${chosen[@]}"; do
                    local safe_name=$(echo "$ref" | sed 's#[/:]#_#g')
                    local out_file="$IMAGE_DIR/${safe_name}.tar"
                    echo "  📦 保存 $ref -> $(basename "$out_file")"
                    if docker save -o "$out_file" "$ref"; then
                        echo "  ✅ 已保存: $(basename "$out_file")"
                    else
                        echo "  ❌ 失败: $ref"
                    fi
                done
                echo "🎉 打包完成！"
            fi
        fi
    else
        echo "⏭️  跳过打包，直接列出已存在的镜像包..."
    fi
    
    # 第二步：列出所有tar文件（包括刚打包的和原来就有的）让用户选择上传
    echo ""
    echo "📤 开始上传镜像包..."
    upload_images_to_servers
}





# 批量下载 tar 包到目录（不构建 deb）
download_tar_packages() {
    echo "📥 下载 tar 包到目录..."
    init_build_directories >/dev/null 2>&1
    if get_user_input "tars"; then
        local failed_items=()
        local success_items=()
        echo "⏳ 正在下载所选 tar，请稍候..."
        for item in "${USER_TARS[@]}"; do
            # 解析输入：支持两种格式
            # 1) 包名 URL
            # 2) 包名 版本 URL [tar内路径]
            local arr=($item)
            local pkg=""
            local ver=""
            local url=""
            local tar_inner=""
            if [[ ${#arr[@]} -ge 2 && "${arr[1]}" =~ ^https?:// ]]; then
                pkg="${arr[0]}"
                url="${arr[1]}"
                tar_inner="${arr[2]:-}"
            elif [[ ${#arr[@]} -ge 3 ]]; then
                pkg="${arr[0]}"
                ver="${arr[1]}"
                url="${arr[2]}"
                tar_inner="${arr[3]:-}"
            else
                echo "❌ 格式不正确: $item"
                failed_items+=("$item")
                continue
            fi

            # 下载 tar 到工作目录
            echo "📥 下载: $pkg ${ver:+$ver }$url"
            local filename="${pkg}${ver:+_$ver}_$(basename "$url")"
            local out_path="$WORK_DIR/$filename"
            echo "  📥 下载: $url"
            if curl $([ "$RETRY_ENABLED" = true ] && echo "--retry $RETRY_COUNT --retry-delay $RETRY_DELAY") --fail --show-error --location --http1.1 -o "$out_path" "$url"; then
                echo "  ✅ 下载完成: $out_path"
                success_items+=("$filename")
            else
                echo "  ❌ 下载失败: $item"
                echo "  🔍 建议：检查 URL、网络连通、或稍后重试"
                failed_items+=("$item")
            fi
        done
        echo ""
        echo "📊 下载结果："
        if [[ ${#success_items[@]} -gt 0 ]]; then
            echo "✅ 成功:"
            for s in "${success_items[@]}"; do
                echo "  - $s"
            done
            
            # 移动成功的文件到 tars 目录
            echo ""
            echo "📁 移动文件到 tars 目录..."
            for s in "${success_items[@]}"; do
                local source_file="$WORK_DIR/$s"
                # 提取原始文件名（去掉包名和版本前缀）
                local original_name=$(basename "$s" | sed 's/^[^_]*_[^_]*_//')
                local target_file="$TARS_DIR/$original_name"
                
                if [[ -f "$source_file" ]]; then
                    mv "$source_file" "$target_file"
                    echo "  ✅ 已移动: $s -> $original_name"
                else
                    echo "  ❌ 源文件不存在: $source_file"
                fi
            done
            echo "📁 最终保存目录: $TARS_DIR"
        fi
        if [[ ${#failed_items[@]} -gt 0 ]]; then
            echo "❌ 失败:"
            for f in "${failed_items[@]}"; do
                echo "  - $f"
            done
        fi
    fi
}

# 通用二进制与压缩包下载/验证/提取工具函数
validate_binary_file() {
    local file_path="$1"
    if [[ ! -f "$package_path" ]] || [[ ! -s "$package_path" ]]; then
        return 1
    fi
    if file "$package_path" | grep -q "ELF\|executable\|binary"; then
        return 0
    fi
    if grep -q "Error\|NoSuchKey\|AccessDenied\|404\|Not Found" "$package_path" 2>/dev/null; then
        rm -f "$package_path"
        return 1
    fi
    local file_size=$(stat -c%s "$package_path" 2>/dev/null || echo "0")
    if [[ "$package_size" -lt 1000 ]]; then
        rm -f "$package_path"
        return 1
    fi
    return 0
}

download_and_extract_from_tar() {
    local tar_url="$1"
    local target_file="$2"
    local output_file="$3"
    local tar_path="$4"

    echo "    DEBUG: 开始下载 tar.gz 文件: $tar_url"
    # 使用默认进度表（显示百分比、平均/当前速度、已用/剩余时间）
    if ! curl --retry 3 --retry-delay 2 --fail --show-error --location --http1.1 -o "temp.tar.gz" "$tar_url"; then
        echo "    DEBUG: 下载失败"
        return 1
    fi
    echo "    DEBUG: 下载成功，验证文件..."
    if ! file "temp.tar.gz" | grep -q "gzip\|tar"; then
        echo "    DEBUG: 文件验证失败，不是有效的 tar.gz 文件"
        rm -f temp.tar.gz
        return 1
    fi
    echo "    DEBUG: 文件验证成功，开始解压..."
    tar -xzf temp.tar.gz
    echo "    DEBUG: 解压完成，查找目标文件: $target_file"

    local found_file=""
    if [[ -n "$tar_path" ]]; then
        echo "    DEBUG: 使用指定路径: $tar_path"
        found_file=$(find . -path "$tar_path" -type f 2>/dev/null | head -1)
    else
        echo "    DEBUG: 使用默认路径模式"
        local possible_paths=(
            "*/server/bin/${target_file}"
            "*/platforms/linux/amd64/${target_file}"
            "*/bin/${target_file}"
            "*/${target_file}"
        )
        for pattern in "${possible_paths[@]}"; do
            echo "    DEBUG: 尝试模式: $pattern"
            found_file=$(find . -name "$pattern" -type f 2>/dev/null | head -1)
            if [[ -n "$found_file" ]]; then
                echo "    DEBUG: 找到文件: $found_file"
                break
            fi
        done
    fi

    if [[ -n "$found_file" ]] && [[ -f "$found_file" ]]; then
        echo "    DEBUG: 复制文件到: $output_file"
        cp "$found_file" "$output_file"
        chmod +x "$output_file"
        rm -f temp.tar.gz
        rm -rf kubernetes/ 2>/dev/null || true
        echo "    DEBUG: 提取成功"
        return 0
    else
        echo "    DEBUG: 未找到目标文件: $target_file"
        echo "    DEBUG: 当前目录内容:"
        find . -type f -name "*${target_file}*" 2>/dev/null | head -5
    fi

    rm -f temp.tar.gz
    rm -rf kubernetes/ 2>/dev/null || true
    echo "    DEBUG: 提取失败"
    return 1
}

download_direct_package() {
    local package_name="$1"
    local version="$2"
    local download_url="$3"
    local tar_path="$4"
    local output_file="$5"

    echo "📥 直接下载: $package_name"
    [[ -n "$version" ]] && echo "  版本: $version"
    echo "  URL: $download_url"
    [[ -n "$tar_path" ]] && echo "  Tar路径: $tar_path"

    if [[ "$download_url" == *".tar.gz" ]] || [[ "$download_url" == *".tgz" ]]; then
        echo "  📦 检测到 tar.gz 文件，尝试提取..."
        if download_and_extract_from_tar "$download_url" "$package_name" "$output_file" "$tar_path"; then
            echo "  ✅ $package_name 从 tar.gz 提取成功"
            return 0
        fi
    else
        echo "  📦 检测到二进制文件，直接下载..."
        # 使用默认进度表（显示百分比、平均/当前速度、已用/剩余时间）
        if curl --retry 3 --retry-delay 2 --fail --show-error --location --http1.1 -o "$output_file" "$download_url" \
           && validate_binary_file "$output_file"; then
            chmod +x "$output_file"
            echo "  ✅ $package_name 下载成功"
            return 0
        fi
    fi
    echo "  ❌ $package_name 下载失败"
    return 1
}

# 简化的包构建函数
build_simple_package() {
    local package_input="$1"
    
    # 解析输入
    local parts=($package_input)
    
    # 仅保留 APT 下载 .deb（不再安装后重打包）
    if [[ ${#parts[@]} -eq 1 ]]; then
        local package_name="${parts[0]}"
        echo "📦 APT 模式: $package_name"
        echo "  🔎 检索可用版本..."
        local available_versions=$(apt-cache madison "$package_name" 2>/dev/null | awk '{print $3}' | sed '/^$/d' | head -20)
        if [[ -z "$available_versions" ]]; then
            echo "  ❌ 未找到可用版本"
            # 尝试给出相近包名建议
            echo "  💡 可能的包名："
            local candidates=$(apt-cache pkgnames 2>/dev/null | grep -i "^$package_name" -m 10)
            if [[ -z "$candidates" ]]; then
                candidates=$(apt-cache pkgnames 2>/dev/null | grep -i "$package_name" -m 10)
            fi
            if [[ -z "$candidates" ]] && [[ "$package_name" == kube* ]]; then
                candidates=$'kubelet\nkubeadm\nkubectl'
            fi
            if [[ -n "$candidates" ]]; then
                local idxs=0
                local cand_arr=()
                while IFS= read -r c; do idxs=$((idxs+1)); cand_arr+=("$c"); echo "   $idxs) $c"; done <<< "$candidates"
                read -p "  是否改为以上某个包？输入序号继续（回车跳过）: " cidx
                if [[ -n "$cidx" ]] && [[ "$cidx" =~ ^[0-9]+$ ]] && [[ "$cidx" -ge 1 ]] && [[ "$cidx" -le ${#cand_arr[@]} ]]; then
                    package_name="${cand_arr[cidx-1]}"
                    echo "  ✅ 已选择包名: $package_name"
                    available_versions=$(apt-cache madison "$package_name" 2>/dev/null | awk '{print $3}' | sed '/^$/d' | head -20)
                fi
            fi
            if [[ -z "$available_versions" ]]; then
                echo "  ❌ 仍未找到可用版本"
                return 1
            fi
        fi
        echo "  📋 可用版本（选择序号或直接回车取消）："
        local idx=0
        local versions_array=()
        while IFS= read -r v; do
            [[ -z "$v" ]] && continue
            idx=$((idx+1))
            versions_array+=("$v")
            echo "   $idx) $v"
        done <<< "$available_versions"
        read -p "  选择版本序号: " ver_idx
        if [[ -z "$ver_idx" ]] || ! [[ "$ver_idx" =~ ^[0-9]+$ ]] || [[ "$ver_idx" -lt 1 ]] || [[ "$ver_idx" -gt ${#versions_array[@]} ]]; then
            echo "  ❌ 未选择有效版本"
            return 1
        fi
        local version_chosen="${versions_array[ver_idx-1]}"
        # kube 系列根据选择的版本切换通道
        if [[ "$package_name" =~ kube|kubernetes ]]; then
            local minor_chosen="$(echo "$version_chosen" | awk -F. '{print $1"."$2}')"
            add_kubernetes_repository "$minor_chosen"
            echo "  🔄 已切换 Kubernetes 通道至 v$minor_chosen"
            sudo apt-get update || true
        fi
        if download_deb_package "$package_name" "$version_chosen"; then
            echo "✅ $package_name 下载完成（.deb 已保存）"
            return 0
        else
            echo "❌ $package_name APT 下载失败，可尝试直接下载 tar 包"
            return 1
        fi
    elif [[ ${#parts[@]} -eq 2 && ! "${parts[1]}" =~ ^https?:// ]]; then
        local package_name="${parts[0]}"
        local version="${parts[1]}"
        echo "📦 APT 模式（指定版本）: $package_name $version"
        # 若版本不包含修订号，列出候选完整版本供选择
        if [[ ! "$version" =~ - ]]; then
            echo "  🔎 检索可用版本..."
            local available_versions=$(apt-cache madison "$package_name" 2>/dev/null | awk '{print $3}' | sed '/^$/d' | head -20)
            if [[ -z "$available_versions" ]]; then
                echo "  ❌ 未找到可用版本"
                # 包名可能有误，尝试建议
                echo "  💡 可能的包名："
                local candidates=$(apt-cache pkgnames 2>/dev/null | grep -i "^$package_name" -m 10)
                if [[ -z "$candidates" ]]; then
                    candidates=$(apt-cache pkgnames 2>/dev/null | grep -i "$package_name" -m 10)
                fi
                if [[ -z "$candidates" ]] && [[ "$package_name" == kube* ]]; then
                    candidates=$'kubelet\nkubeadm\nkubectl'
                fi
                if [[ -n "$candidates" ]]; then
                    local idxs=0
                    local cand_arr=()
                    while IFS= read -r c; do idxs=$((idxs+1)); cand_arr+=("$c"); echo "   $idxs) $c"; done <<< "$candidates"
                    read -p "  是否改为以上某个包？输入序号继续（回车跳过）: " cidx
                    if [[ -n "$cidx" ]] && [[ "$cidx" =~ ^[0-9]+$ ]] && [[ "$cidx" -ge 1 ]] && [[ "$cidx" -le ${#cand_arr[@]} ]]; then
                        package_name="${cand_arr[cidx-1]}"
                        echo "  ✅ 已选择包名: $package_name"
                        available_versions=$(apt-cache madison "$package_name" 2>/dev/null | awk '{print $3}' | sed '/^$/d' | head -20)
                    fi
                fi
                if [[ -z "$available_versions" ]]; then
                    echo "  ❌ 仍未找到可用版本"
                    return 1
                fi
            fi
            if [[ "$package_name" =~ kube|kubernetes ]]; then
                local minor_hint="$(echo "$version" | awk -F. '{print $1"."$2}')"
                if [[ -n "$minor_hint" ]]; then
                    local filtered=$(echo "$available_versions" | grep -E "^${minor_hint}\\.")
                    if [[ -z "$filtered" ]]; then
                        # 提示是否切换到对应通道再重试获取该小版本
                        local current_minor_q="$(get_current_k8s_minor)"
                        echo "  ❓ 当前通道为 v${current_minor_q:-未配置}，是否切换到 v$minor_hint 通道以获取该小版本？(y/N)"
                        read -p "  切换通道: " switch_minor
                        if [[ "$switch_minor" =~ ^[Yy]$ ]]; then
                            add_kubernetes_repository "$minor_hint"
                            echo "  🔄 已切换 Kubernetes 通道至 v$minor_hint"
                            sudo apt-get update || true
                            available_versions=$(apt-cache madison "$package_name" 2>/dev/null | awk '{print $3}' | sed '/^$/d' | head -20)
                            filtered=$(echo "$available_versions" | grep -E "^${minor_hint}\\.")
                        else
                            echo "  ⚠️  未切换通道，显示当前通道的可用版本"
                        fi
                    fi
                    if [[ -n "$filtered" ]]; then
                        available_versions="$filtered"
                    fi
                fi
            fi
            echo "  📋 可用版本（选择序号或直接回车取消）："
            local idx=0
            local versions_array=()
            while IFS= read -r v; do
                [[ -z "$v" ]] && continue
                idx=$((idx+1))
                versions_array+=("$v")
                echo "   $idx) $v"
            done <<< "$available_versions"
            read -p "  选择版本序号: " ver_idx
            if [[ -z "$ver_idx" ]] || ! [[ "$ver_idx" =~ ^[0-9]+$ ]] || [[ "$ver_idx" -lt 1 ]] || [[ "$ver_idx" -gt ${#versions_array[@]} ]]; then
                echo "  ❌ 未选择有效版本"
                return 1
            fi
            version="${versions_array[ver_idx-1]}"
            echo "  ✅ 已选择版本: $version"
        fi
        # 若指定版本属于 Kubernetes 生态，尝试切换对应通道 vX.Y
        if [[ "$package_name" =~ kube|kubernetes ]]; then
            local minor="$(echo "$version" | awk -F. '{print $1"."$2}')"
            add_kubernetes_repository "$minor"
            echo "  🔄 已切换 Kubernetes 通道至 v$minor"
            sudo apt-get update || true
        fi
        local desired_minor_for_dl=""
        if [[ "$package_name" =~ kube|kubernetes ]]; then
            desired_minor_for_dl="$(echo "$version" | awk -F. '{print $1"."$2}')"
        fi
        if download_deb_package "$package_name" "$version" "$desired_minor_for_dl"; then
            echo "✅ $package_name 下载完成（.deb 已保存）"
            return 0
        else
            echo "  ❌ 指定版本未找到，列出可用版本："
            local minor_hint2="$(echo "$version" | awk -F. '{print $1"."$2}')"
            local available_versions2=$(apt-cache madison "$package_name" 2>/dev/null | awk '{print $3}' | sed '/^$/d' | head -20)
            if [[ -n "$minor_hint2" ]]; then
                available_versions2=$(echo "$available_versions2" | grep -E "^${minor_hint2}\\.")
            fi
            if [[ -z "$available_versions2" ]]; then
                echo "  ❌ 未找到可用版本"
                echo "❌ $package_name APT 下载失败，可尝试直接下载 tar 包"
                return 1
            fi
            # 在失败分支再次提供切换通道机会（仅 kube* 包）
            if [[ "$package_name" =~ kube|kubernetes ]]; then
                local current_minor_q3="$(get_current_k8s_minor)"
                if [[ -n "$minor_hint2" && "$minor_hint2" != "$current_minor_q3" ]]; then
                    echo "  ❓ 当前通道为 v${current_minor_q3:-未配置}，是否切换到 v$minor_hint2 通道以获取该小版本？(y/N)"
                    read -p "  切换通道: " switch_minor3
                    if [[ "$switch_minor3" =~ ^[Yy]$ ]]; then
                        add_kubernetes_repository "$minor_hint2"
                        echo "  🔄 已切换 Kubernetes 通道至 v$minor_hint2"
                        sudo apt-get update || true
                        available_versions2=$(apt-cache madison "$package_name" 2>/dev/null | awk '{print $3}' | sed '/^$/d' | head -20)
                        available_versions2=$(echo "$available_versions2" | grep -E "^${minor_hint2}\\.")
                    fi
                fi
            fi
            echo "  📋 可用版本（选择序号或直接回车取消）："
            local idx2=0
            local versions_array2=()
            while IFS= read -r v; do
                [[ -z "$v" ]] && continue
                idx2=$((idx2+1))
                versions_array2+=("$v")
                echo "   $idx2) $v"
            done <<< "$available_versions2"
            read -p "  选择版本序号: " ver_idx2
            if [[ -z "$ver_idx2" ]] || ! [[ "$ver_idx2" =~ ^[0-9]+$ ]] || [[ "$ver_idx2" -lt 1 ]] || [[ "$ver_idx2" -gt ${#versions_array2[@]} ]]; then
                echo "  ❌ 未选择有效版本"
                echo "❌ $package_name APT 下载失败，可尝试直接下载 tar 包"
                return 1
            fi
            local version_retry="${versions_array2[ver_idx2-1]}"
            if [[ "$package_name" =~ kube|kubernetes ]]; then
                local minor_retry="$(echo "$version_retry" | awk -F. '{print $1"."$2}')"
                add_kubernetes_repository "$minor_retry"
                echo "  🔄 已切换 Kubernetes 通道至 v$minor_retry"
                sudo apt-get update || true
            fi
            local desired_minor_for_dl2=""
            if [[ "$package_name" =~ kube|kubernetes ]]; then
                desired_minor_for_dl2="$(echo "$version_retry" | awk -F. '{print $1"."$2}')"
            fi
            if download_deb_package "$package_name" "$version_retry" "$desired_minor_for_dl2"; then
                echo "✅ $package_name 下载完成（.deb 已保存）"
                return 0
            else
                echo "❌ $package_name APT 下载失败，可尝试直接下载 tar 包"
                return 1
            fi
        fi
    else
        echo "❌ 不支持的包格式: $package_input"
        echo "  仅支持：包名 或 包名 版本号（APT 模式）"
        return 1
    fi
}

# 从本地 tar.gz 提取目标文件
extract_from_local_tar() {
    local local_tar="$1"
    local target_file="$2"
    local output_file="$3"
    local tar_path="$4"

    echo "    DEBUG: 验证本地 tar.gz: $local_tar"
    if [[ ! -f "$local_tar" ]]; then
        echo "    DEBUG: 本地文件不存在"
        return 1
    fi
    if ! file "$local_tar" | grep -q "gzip\|tar"; then
        echo "    DEBUG: 非有效 tar.gz 文件"
        return 1
    fi
    echo "    DEBUG: 解压本地 tar.gz..."
    local tmp_dir
    tmp_dir=$(mktemp -d)
    tar -xzf "$local_tar" -C "$tmp_dir"
    echo "    DEBUG: 查找目标文件: $target_file"
    local found_file=""
    if [[ -n "$tar_path" ]]; then
        echo "    DEBUG: 使用指定路径: $tar_path"
        found_file=$(find "$tmp_dir" -path "$tar_path" -type f 2>/dev/null | head -1)
    else
        local possible_paths=(
            "*/server/bin/${target_file}"
            "*/platforms/linux/amd64/${target_file}"
            "*/bin/${target_file}"
            "*/${target_file}"
        )
        for pattern in "${possible_paths[@]}"; do
            echo "    DEBUG: 尝试模式: $pattern"
            found_file=$(find "$tmp_dir" -name "$pattern" -type f 2>/dev/null | head -1)
            if [[ -n "$found_file" ]]; then
                echo "    DEBUG: 找到文件: $found_file"
                break
            fi
        done
    fi
    if [[ -n "$found_file" ]] && [[ -f "$found_file" ]]; then
        cp "$found_file" "$output_file"
        chmod +x "$output_file"
        rm -rf "$tmp_dir"
        echo "    DEBUG: 提取成功 -> $output_file"
        return 0
    else
        echo "    DEBUG: 未找到目标文件"
        rm -rf "$tmp_dir"
        return 1
    fi
}

# 用单个二进制文件创建简单 deb 包
create_single_binary_deb() {
    local package_name="$1"
    local binary_path="$2"
    local version="${3:-1.0.0}"
    local install_dir="${4:-/usr/local/bin}"

    if [[ ! -f "$binary_path" ]]; then
        echo "  ❌ 二进制文件不存在: $binary_path"
        return 1
    fi

    echo "  📦 使用单个二进制构建 deb: $package_name ($version)"
    local pkg_root
    pkg_root=$(mktemp -d)
    mkdir -p "$pkg_root/DEBIAN" "$pkg_root${install_dir}"
    cp "$binary_path" "$pkg_root${install_dir}/$package_name"
    chmod 0755 "$pkg_root${install_dir}/$package_name"

    cat > "$pkg_root/DEBIAN/control" << EOF
Package: $package_name
Version: $version
Architecture: $(dpkg --print-architecture 2>/dev/null || echo amd64)
Maintainer: Auto-generated
Description: Auto-generated single-binary package for $package_name
EOF

    mkdir -p "$DEB_DIR"
    local deb_out="$DEB_DIR/${package_name}_${version}_$(dpkg --print-architecture 2>/dev/null || echo amd64).deb"
    dpkg-deb --build "$pkg_root" "$deb_out"
    local rc=$?
    rm -rf "$pkg_root"
    if [[ $rc -eq 0 ]]; then
        echo "  ✅ 创建成功: $deb_out"
        return 0
    else
        echo "  ❌ deb 构建失败"
        return 1
    fi
}

# 交互：从本地文件构建 deb（已手动下载）
build_deb_from_local_file() {
    echo ""
    echo "📦 从本地文件构建 deb 包"
    read -p "请输入包名（将作为可执行名安装到 /usr/local/bin）: " package_name
    if [[ -z "$package_name" ]]; then
        echo "❌ 包名不能为空"
        return 1
    fi
    read -p "请输入本地文件路径（支持二进制或 .tar.gz/.tgz）: " local_path
    if [[ ! -f "$local_path" ]]; then
        echo "❌ 本地文件不存在"
        return 1
    fi
    read -p "请输入版本号（默认 1.0.0）: " version
    version=${version:-1.0.0}
    local tmp_bin
    tmp_bin=$(mktemp)

    if [[ "$local_path" == *.tar.gz || "$local_path" == *.tgz ]]; then
        read -p "如需指定 tar 内路径，请输入（留空则自动查找）: " tar_inner
        echo "  📦 从本地 tar.gz 提取 $package_name..."
        if ! extract_from_local_tar "$local_path" "$package_name" "$tmp_bin" "$tar_inner"; then
            rm -f "$tmp_bin"
            echo "❌ 提取失败"
            return 1
        fi
    else
        cp "$local_path" "$tmp_bin"
        chmod +x "$tmp_bin"
        if ! validate_binary_file "$tmp_bin"; then
            rm -f "$tmp_bin"
            echo "❌ 二进制校验失败"
            return 1
        fi
    fi

    if create_single_binary_deb "$package_name" "$tmp_bin" "$version" "/usr/local/bin"; then
        rm -f "$tmp_bin"
        echo "✅ 本地文件构建完成"
        return 0
    else
        rm -f "$tmp_bin"
        echo "❌ 本地文件构建失败"
        return 1
    fi
}

# 下载 deb 包
download_deb_package() {
    local package_name="$1"
    local version="${2:-}"
    local desired_minor="${3:-}"
    
    echo "  📥 下载 deb 包: $package_name"
    
    # 检查是否需要添加/切换 Kubernetes 源（基于包名模式匹配）
    case "$package_name" in
        *docker*)
            echo "  🔑 添加 Docker 官方源..."
            add_docker_repository
            ;;
        *kube*|*kubernetes*)
            echo "  🔑 添加 Kubernetes 官方仓库..."
            # 仅在需要时切换；若提供了目标小版本，则切换到该通道；否则若未配置任何通道，则初始化一次
            local current_minor_q="$(get_current_k8s_minor)"
            if [[ -n "$desired_minor" && "$desired_minor" != "$current_minor_q" ]]; then
                add_kubernetes_repository "$desired_minor"
            elif [[ -z "$current_minor_q" ]]; then
                add_kubernetes_repository  # 初始化为最新稳定通道
            fi
            ;;
        *mysql*)
            echo "  🔑 添加 MySQL 官方源..."
            add_mysql_repository
            ;;
        *redis*)
            echo "  🔑 添加 Redis 官方源..."
            add_redis_repository
            ;;
        *nerdctl*)
            echo "  🔑 添加 Docker 官方源（nerdctl 包含在 Docker 仓库中）..."
            add_docker_repository
            ;;
        *)
            echo "  📦 使用系统默认源下载: $package_name"
            ;;
    esac
    
    # 更新包列表
    echo "  📦 正在更新包列表..."
    if ! sudo apt-get update; then
        echo "  ⚠️  包列表更新失败，但继续尝试下载"
    else
        echo "  ✅ 包列表更新成功"
    fi
    
    # 解析候选版本（当未指定版本时用于展示）
    local candidate_version=""
    if [[ -z "$version" ]]; then
        candidate_version=$(apt-cache policy "$package_name" 2>/dev/null | awk '/Candidate:/ {print $2; exit}')
        candidate_version=${candidate_version:-unknown}
        echo "  🔎 候选版本: $candidate_version"
    fi

    # 直接下载 deb 包，不安装
    local download_cmd="apt-get download $package_name"
    if [[ -n "$version" ]]; then
        download_cmd="apt-get download $package_name=$version"
    fi
    
    echo "  📦 正在下载 deb 包: $download_cmd"
    
    if sudo $download_cmd; then
        echo "  ✅ deb 包下载成功: $package_name"
        
        # 查找下载的 deb 文件
        local deb_file=$(find . -maxdepth 1 -name "*${package_name}*.deb" -type f | head -1)
        if [[ -n "$deb_file" ]] && [[ -f "$deb_file" ]]; then
            echo "  📁 找到 deb 文件: $deb_file"
            # 移动到 deb 目录
            mv "$deb_file" "$DEB_DIR/"
            echo "  ✅ deb 包已移动到: $DEB_DIR/"
            return 0
        else
            echo "  ⚠️  未找到下载的 deb 文件"
            return 1
        fi
    else
        echo "  ❌ deb 包下载失败: $package_name"
        echo "  💡 可能原因："
        echo "     - 包名不正确"
        echo "     - 网络连接问题"
        echo "     - 仓库配置失败"
        echo "  🔍 建议："
        echo "     - 尝试: apt search $package_name"
        echo "     - 或者: apt-cache search $package_name"
        return 1
    fi
}

# 添加 Kubernetes 官方仓库
add_kubernetes_repository() {
    local desired_minor="${1:-}"
    local list_file="/etc/apt/sources.list.d/kubernetes.list"
    echo "  🔑 校验/更新 Kubernetes 官方仓库..."

    # 计算目标通道主次版本（vX.Y）
    local k8s_minor=""
    if [[ -n "$desired_minor" ]]; then
        k8s_minor="$desired_minor"
    else
        local k8s_version=""
        if command -v curl >/dev/null 2>&1; then
            k8s_version=$(curl -sL https://dl.k8s.io/release/stable.txt 2>/dev/null | sed 's/v//' | tr -d '\n\r')
        fi
        if [[ -z "$k8s_version" ]] || [[ "$k8s_version" == *"html"* ]] || [[ "$k8s_version" == *"error"* ]]; then
            echo "  ⚠️  无法获取最新版本，使用默认版本"
            k8s_version="1.33.0"
        fi
        k8s_minor="$(echo "$k8s_version" | awk -F. '{print $1"."$2}')"
    fi
    echo "  📦 目标版本通道: v$k8s_minor"

    # 准备 GPG 密钥（幂等）
    sudo mkdir -p /etc/apt/keyrings
    curl --retry 3 --retry-delay 2 --fail --silent --show-error --location --http1.1 \
        "https://pkgs.k8s.io/core:/stable:/v${k8s_minor}/deb/Release.key" \
        | sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    # 生成期望的 sources 行
    local desired_line="deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${k8s_minor}/deb/ /"

    # 若文件已存在但版本不匹配，则更新；否则创建
    if [[ -f "$list_file" ]]; then
        if grep -q "v${k8s_minor}/deb" "$list_file"; then
            echo "  ✅ Kubernetes 仓库已是最新通道"
        else
            echo "  🔄 检测到旧版本通道，正在更新为 v${k8s_minor}..."
            echo "$desired_line" | sudo tee "$list_file" >/dev/null
            echo "  ✅ 已更新 Kubernetes 仓库通道"
        fi
    else
        echo "$desired_line" | sudo tee "$list_file" >/dev/null
        echo "  ✅ 已添加 Kubernetes 仓库通道"
    fi
}

# 添加 Docker 官方仓库
add_docker_repository() {
    # 统一 Docker 仓库配置，避免 Signed-By 冲突
    echo "  🔑 添加/修复 Docker 官方仓库配置..."

    local desired_keyring="/usr/share/keyrings/docker-archive-keyring.gpg"

    # 准备 keyring 目录与密钥
    sudo mkdir -p "/usr/share/keyrings"
    curl --retry 3 --retry-delay 2 --fail --silent --show-error --location --http1.1 \
        https://download.docker.com/linux/ubuntu/gpg \
        | sudo gpg --dearmor --yes -o "$desired_keyring"
    sudo chmod 0644 "$desired_keyring" 2>/dev/null || true

    # 移除可能造成冲突的旧列表（包括 containerd.list 或任何包含 download.docker.com 的列表）
    if ls /etc/apt/sources.list.d/*.list >/dev/null 2>&1; then
        sudo grep -RIl "download.docker.com" /etc/apt/sources.list.d 2>/dev/null | xargs -r sudo rm -f
    fi
    sudo rm -f /etc/apt/sources.list.d/containerd.list 2>/dev/null || true

    # 移除主 sources.list 中可能残留的 docker 源，避免未使用 signed-by 导致 NO_PUBKEY
    if [[ -f /etc/apt/sources.list ]]; then
        sudo sed -i '/download\.docker\.com/d' /etc/apt/sources.list
    fi

    # 创建标准的 docker.list（带 signed-by，避免使用系统信任库）
    echo "deb [arch=$(dpkg --print-architecture) signed-by=$desired_keyring] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

    echo "  ✅ Docker 仓库配置完成（已统一 Signed-By）"
}

# 添加 MySQL 官方仓库
add_mysql_repository() {
    # 检查是否已经配置过 MySQL 仓库
    if [[ -f "/etc/apt/sources.list.d/mysql.list" ]]; then
        echo "  ✅ MySQL 仓库已配置，跳过重复配置"
        return 0
    fi
    
    echo "  🔑 添加 MySQL 官方仓库..."
    
    # 添加 MySQL GPG 密钥（幂等、非交互、带重试）
    sudo mkdir -p /etc/apt/keyrings
    curl --retry 3 --retry-delay 2 --fail --silent --show-error --location --http1.1 \
        https://repo.mysql.com/RPM-GPG-KEY-mysql-2022 \
        | sudo gpg --dearmor --yes -o /etc/apt/keyrings/mysql.gpg
    
    # 添加 MySQL 仓库
    echo "deb [signed-by=/etc/apt/keyrings/mysql.gpg] https://repo.mysql.com/apt/ubuntu $(lsb_release -cs) mysql-8.0" | sudo tee /etc/apt/sources.list.d/mysql.list >/dev/null
    
    echo "  ✅ MySQL 仓库添加完成"
}

# 添加 Redis 官方仓库
add_redis_repository() {
    # 检查是否已经配置过 Redis 仓库
    if [[ -f "/etc/apt/sources.list.d/redis.list" ]]; then
        echo "  ✅ Redis 仓库已配置，跳过重复配置"
        return 0
    fi
    
    echo "  🔑 添加 Redis 官方仓库..."
    
    # 添加 Redis GPG 密钥（幂等、非交互、带重试）
    sudo mkdir -p /etc/apt/keyrings
    curl --retry 3 --retry-delay 2 --fail --silent --show-error --location --http1.1 \
        https://packages.redis.io/gpg \
        | sudo gpg --dearmor --yes -o /etc/apt/keyrings/redis.gpg
    
    # 添加 Redis 仓库
    echo "deb [signed-by=/etc/apt/keyrings/redis.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list >/dev/null
    
    echo "  ✅ Redis 仓库添加完成"
}



# 下载 APT 包
download_apt_package() {
    local package_name="$1"
    local version="${2:-}"
    
    echo "  📦 安装 APT 包: $package_name"
    
    if [[ -z "$version" ]]; then
        sudo apt-get install -y "$package_name"
    else
        sudo apt-get install -y "$package_name=$version"
    fi
    
    if [[ $? -eq 0 ]]; then
        echo "  ✅ 安装成功"
        return 0
    else
        echo "  ❌ 安装失败"
        return 1
    fi
}

# 创建 deb 包
create_deb_package() {
    local package_name="$1"
    local provided_version="${2:-}"
    
    echo "  📦 创建 deb 包: $package_name"
    
    # 解析版本与架构
    local arch=$(dpkg --print-architecture 2>/dev/null || echo amd64)
    local version="$provided_version"
    if [[ -z "$version" ]]; then
        version=$(dpkg-query -W -f='${Version}' "$package_name" 2>/dev/null | head -1)
    fi
    version=${version:-1.0.0}
    
    # 创建工作目录
    local work_dir="$WORK_DIR/$package_name"
    mkdir -p "$work_dir"
    cd "$work_dir"
    
    # 查找已安装的文件
    local package_files=$(dpkg -L "$package_name" 2>/dev/null | grep -v "^/$" | grep -v "^/usr/share/doc" | grep -v "^/usr/share/man")
    
    if [[ -z "$package_files" ]]; then
        echo "  ❌ 未找到包文件"
        cd - > /dev/null
        rm -rf "$work_dir"
        return 1
    fi
    
    # 创建 deb 包结构
    mkdir -p "DEBIAN"
    mkdir -p "usr/bin" "usr/lib" "usr/share" "etc" "var"
    
    # 复制文件
    for file in $package_files; do
        if [[ -f "$file" ]]; then
            local target_dir=$(dirname "$file" | sed 's|^/||')
            mkdir -p "$target_dir"
            cp "$file" "$target_dir/"
        fi
    done
    
    # 创建控制文件
    cat > "DEBIAN/control" << EOF
Package: $package_name
Version: $version
Architecture: $arch
Maintainer: Auto-generated
Description: Auto-generated package for $package_name
EOF
    
    # 构建 deb 包
    local out_deb="$DEB_DIR/${package_name}_${version}_${arch}.deb"
    dpkg-deb --build . "$out_deb"
    
    local rc=$?
    cd - > /dev/null
    rm -rf "$work_dir"
    if [[ $rc -eq 0 ]]; then
        echo "  ✅ deb 包创建成功: $(basename "$out_deb")"
        return 0
    else
        echo "  ❌ deb 包创建失败"
        return 1
    fi
}

# 解析架构标识
get_architecture_tag() {
    local arch
    arch=$(dpkg --print-architecture 2>/dev/null || echo "amd64")
    case "$arch" in
        amd64|x86_64)
            echo "amd64" ;;
        arm64|aarch64)
            echo "arm64" ;;
        *)
            echo "$arch" ;;
    esac
}

# 构建镜像包
build_image_package() {
    local image_name="$1"
    local image_version="$2"
    
    echo "  🐳 构建镜像包: $image_name:$image_version"
    
 
    
    # 拉取镜像
    echo "  📥 拉取镜像: $image_name:$image_version"
    if docker pull "$image_name:$image_version"; then
        # 保存镜像
        local image_file="$IMAGE_DIR/${image_name//\//_}_${image_version}.tar"
        echo "  💾 保存镜像到: $image_file"
        if docker save "$image_name:$image_version" -o "$image_file"; then
            echo "  ✅ 镜像包创建成功"
            return 0
        else
            echo "  ❌ 镜像保存失败"
            return 1
        fi
    else
        echo "  ❌ 镜像拉取失败"
        return 1
    fi
}

# =============================================================================
# 上传功能
# =============================================================================

# 获取SSH密钥路径
get_ssh_key_path() {
    local secret_path="$1"
    
    if [[ -f "$secret_path" ]]; then
        echo "$secret_path"
    elif [[ -f "$HOME/.ssh/$secret_path" ]]; then
        echo "$HOME/.ssh/$secret_path"
    elif [[ -f "$HOME/.ssh/id_rsa" ]]; then
        echo "$HOME/.ssh/id_rsa"
    else
        echo ""
    fi
}

# 获取当前已配置的 Kubernetes 通道主次版本（X.Y），未配置则输出空
get_current_k8s_minor() {
    local list_file="/etc/apt/sources.list.d/kubernetes.list"
    if [[ -f "$list_file" ]]; then
        grep -oE 'v[0-9]+\.[0-9]+' "$list_file" | head -1 | sed 's/^v//'
        return 0
    fi
    echo ""
}

# 获取服务器数量
get_server_count() {
    local count=0
    while true; do
        count=$((count + 1))
        local host_var="SERVER_${count}_PUBLIC_IP"
        if [ -z "${!host_var-}" ]; then
            count=$((count - 1))
            break
        fi
    done
    echo "$count"
}

# 检查sshpass
check_sshpass() {
    echo "🔍 检查 sshpass..."
    if command -v sshpass >/dev/null 2>&1; then
        echo "✅ sshpass 已安装"
        return 0
    else
        echo "❌ sshpass 未安装"
        echo "💡 请安装: sudo apt-get install sshpass"
        return 1
    fi
}

# 上传文件到服务器
upload_files_to_servers() {
    echo "📤 上传文件到服务器..."
    
    # 检查 sshpass
    if ! check_sshpass; then
        return 1
    fi
    
    # 检查构建目录
    if [[ ! -d "$BUILD_DIR" ]]; then
        echo "❌ 构建目录不存在: $BUILD_DIR"
        echo "💡 请先运行构建功能"
        return 1
    fi
    
    # 检查是否有文件可上传
    local deb_count=$(find "$DEB_DIR" -name "*.deb" -type f 2>/dev/null | wc -l)
    local image_count=$(find "$IMAGE_DIR" -name "*.tar" -type f 2>/dev/null | wc -l)
    
    if [[ "$deb_count" -eq 0 && "$image_count" -eq 0 ]]; then
        echo "❌ 没有找到可上传的文件"
        echo "💡 请先运行构建功能创建包和镜像"
        return 1
    fi
    
    echo "📊 找到可上传的文件："
    echo "  📦 deb 包: $deb_count 个"
    echo "  🐳 镜像: $image_count 个"
    
    # 获取服务器数量
    local server_count=$(get_server_count)
    if [[ "$server_count" -eq 0 ]]; then
        echo "❌ 配置文件中未找到任何服务器配置"
        return 1
    fi
    
    echo "📊 检测到 $server_count 台服务器"
    
    # 遍历所有服务器上传文件
    for i in $(seq 1 "$server_count"); do
        local host_var="SERVER_${i}_PUBLIC_IP"
        local user_var="SERVER_${i}_USER"
        local pass_var="SERVER_${i}_PASS"
        local secret_var="SERVER_${i}_SECRET"
        local dir_var="SERVER_${i}_DIR"
        local port_var="SERVER_${i}_SSH_PORT"
        
        local host=${!host_var}
        local user=${!user_var}
        local pass=${!pass_var-}
        local secret=${!secret_var-}
        local dir=${!dir_var}
        local port=${!port_var:-1022}
        
        echo "🖥️  上传到服务器 $host..."
        
        # SSH 选项
        local SSH_OPTS="-o StrictHostKeyChecking=no"
        
        # 上传 deb 包
        if [[ "$deb_count" -gt 0 ]]; then
            echo "  📦 上传 deb 包..."
            if [[ -n "$secret" && "$secret" != "none" && -f "$secret" ]]; then
                scp -i "$(get_ssh_key_path "$secret")" $SSH_OPTS -P $port "$DEB_DIR"/*.deb "$user@$host:$dir/"
            elif [[ -n "$pass" && "$pass" != "none" ]]; then
                sshpass -p "$pass" scp $SSH_OPTS -P $port "$DEB_DIR"/*.deb "$user@$host:$dir/"
            else
                echo "  ❌ 服务器 $host 未提供有效的密钥或密码，跳过"
                continue
            fi
            
            if [[ $? -eq 0 ]]; then
                # 远端校验：比对第一个 deb 文件大小
                local first_deb=$(ls -1 "$DEB_DIR"/*.deb 2>/dev/null | head -1)
                local fbase=$(basename "$first_deb")
                local local_bytes=$(stat -c%s "$first_deb" 2>/dev/null || echo 0)
                local remote_bytes=0
                if [[ -n "$secret" && "$secret" != "none" && -f "$secret" ]]; then
                    remote_bytes=$(ssh -i "$(get_ssh_key_path "$secret")" $SSH_OPTS -p $port "$user@$host" "stat -c%s '$dir/$fbase' 2>/dev/null" || echo 0)
                elif [[ -n "$pass" && "$pass" != "none" ]]; then
                    remote_bytes=$(sshpass -p "$pass" ssh $SSH_OPTS -p $port "$user@$host" "stat -c%s '$dir/$fbase' 2>/dev/null" || echo 0)
                fi
                if [[ "$remote_bytes" == "$local_bytes" && "$remote_bytes" != "0" ]]; then
                    echo "  ✅ deb 包上传成功（校验通过）"
                else
                    echo "  ⚠️  deb 包上传完成但校验不通过（本地: $local_bytes, 远端: $remote_bytes）"
                fi
            else
                echo "  ❌ deb 包上传失败"
            fi
        fi
        
        # 上传镜像
        if [[ "$image_count" -gt 0 ]]; then
            echo "  🐳 上传镜像..."
            if [[ -n "$secret" && "$secret" != "none" && -f "$secret" ]]; then
                scp -i "$(get_ssh_key_path "$secret")" $SSH_OPTS -P $port "$IMAGE_DIR"/*.tar "$user@$host:$dir/"
            elif [[ -n "$pass" && "$pass" != "none" ]]; then
                sshpass -p "$pass" scp $SSH_OPTS -P $port "$IMAGE_DIR"/*.tar "$user@$host:$dir/"
            fi
            
            if [[ $? -eq 0 ]]; then
                # 远端校验：比对第一个 tar 文件大小
                local first_tar=$(ls -1 "$IMAGE_DIR"/*.tar 2>/dev/null | head -1)
                local tbase=$(basename "$first_tar")
                local local_bytes=$(stat -c%s "$first_tar" 2>/dev/null || echo 0)
                local remote_bytes=0
                if [[ -n "$secret" && "$secret" != "none" && -f "$secret" ]]; then
                    remote_bytes=$(ssh -i "$(get_ssh_key_path "$secret")" $SSH_OPTS -p $port "$user@$host" "stat -c%s '$dir/$tbase' 2>/dev/null" || echo 0)
                elif [[ -n "$pass" && "$pass" != "none" ]]; then
                    remote_bytes=$(sshpass -p "$pass" ssh $SSH_OPTS -p $port "$user@$host" "stat -c%s '$dir/$tbase' 2>/dev/null" || echo 0)
                fi
                if [[ "$remote_bytes" == "$local_bytes" && "$remote_bytes" != "0" ]]; then
                    echo "  ✅ 镜像上传成功（校验通过）"
                else
                    echo "  ⚠️  镜像上传完成但校验不通过（本地: $local_bytes, 远端: $remote_bytes）"
                fi
            else
                echo "  ❌ 镜像上传失败"
            fi
        fi
        
        echo "✅ 服务器 $host 上传完成"
    done
    
    echo "🎉 所有文件上传完成！"
}

# 主函数
main() {
    local command=${1:-}
    
    case "$command" in
        -h|--help)
            show_usage
            ;;
        -v|--version)
            show_version
            ;;
        -b|--build)
            echo "📥 下载模式"
            show_build_menu
            ;;
        -u|--upload)
            echo "📤 上传模式"
            upload_files_to_servers
            ;;
        --charts)
            charts_menu
            ;;
        
        "")
            # 没有参数时，直接显示主菜单
            echo "🔨 deb包和镜像构建工具"
            show_main_menu
            ;;
        *)
            show_usage
            ;;
    esac
}
# 分发镜像包并在远端导入k8s.io + 推送 Harbor

# 主菜单
show_main_menu() {
    while true; do
        echo ""
        echo "📦 下载/上传/安装 工具"
        echo "================================"
        echo "=== 下载功能 ==="
        echo "1. 下载 deb 包"
        echo "2. 下载 tar 包"
        echo "3. 下载 images"
        echo "4. 下载 charts"
        echo "=== 上传功能 ==="
        echo "5. 上传 debs"
        echo "6. 上传 tars"
        echo "7. 上传镜像包"
        echo "8. 上传 charts"
        echo "=== 安装 ==="
        echo "9. 远程安装 debs"
        echo "10. 远程安装镜像包"
        echo "11. 远程安装 tar 包"
        echo "12. 远程安装 charts"
        echo "=== 其他 ==="
        echo "13. 安装/更新本地 helm"
        echo "0. 退出"
        echo ""
        read -p "请选择要执行的步骤 (0-13): " step_choice
        
        case "$step_choice" in
            0)
                echo "👋 退出操作"
                break
                ;;
            1)
                echo "📥 执行: 下载 deb 包..."; build_deb_packages ;;
            2)
                echo "📥 执行: 下载 tar 包..."; download_tar_packages ;;
            3)
                echo "🐳 执行: 拉取 Docker 镜像到本地..."; pull_docker_images ;;
            4)
                echo "📥 执行: 下载 Helm charts 到本地..."; download_helm_charts ;;
            5)
                echo "📤 执行: 上传 deb 包到服务器..."
                check_sshpass
                upload_packages_only
                ;;
            6)
                echo "📤 执行: 上传 tar 包到服务器..."
                check_sshpass
                upload_tars_to_servers
                ;;
            7)
                echo "📤 执行: 镜像打包与上传..."
                check_sshpass
                package_local_images_to_tar
                ;;
            8)
                echo "📤 执行: 上传 charts 到服务器..."; check_sshpass; upload_charts_to_servers
                ;;
            9)
                echo "🧩 执行: 安装 debs..."
                install_debs_on_servers
                ;;
            10)
                echo "🧩 执行: 安装 images..."
                install_images_on_servers
                ;;
            11)
                echo "📦 执行: 远程安装 tar 包..."; install_tars_on_servers
                ;;
            12)
                echo "🧩 执行: 远程安装 Helm charts..."; remote_helm_install_on_servers
                ;;
            13)
                echo "⚙️  执行: 安装/更新本地 helm..."; ensure_helm
                ;;
            *)
                echo "❌ 无效选择"
                ;;
        esac
        
        echo ""
        echo "🔄 操作完成，返回主菜单..."
        read -p "按回车键继续..."
    done
}

# 显示状态
show_status() {
    echo "📊 当前状态："
    echo "================================"
    
    # 检查构建目录
    if [[ -d "$BUILD_DIR" ]]; then
        echo "📁 构建目录: $BUILD_DIR"
        
        # 统计 deb 包
        local deb_count=$(find "$DEB_DIR" -name "*.deb" -type f 2>/dev/null | wc -l)
        echo "📦 deb 包数量: $deb_count"
        if [[ "$deb_count" -gt 0 ]]; then
            echo "📦 deb 包列表："
            find "$DEB_DIR" -name "*.deb" -type f -exec basename {} \; | head -5
            if [[ "$deb_count" -gt 5 ]]; then
                echo "  ... 还有 $((deb_count - 5)) 个包"
            fi
        fi
        
        # 统计 tar 源文件
        local tar_count=$(find "$TARS_DIR" -maxdepth 1 -type f 2>/dev/null | wc -l)
        echo "📥 tar 文件数量: $tar_count"
        if [[ "$tar_count" -gt 0 ]]; then
            echo "📥 tar 文件列表："
            ls -1 "$TARS_DIR" 2>/dev/null | head -5
            if [[ "$tar_count" -gt 5 ]]; then
                echo "  ... 还有 $((tar_count - 5)) 个 tar 文件"
            fi
        fi
        
        # 统计镜像
        local image_count=$(find "$IMAGE_DIR" -name "*.tar" -type f 2>/dev/null | wc -l)
        echo "🐳 镜像数量: $image_count"
        if [[ "$image_count" -gt 0 ]]; then
            echo "🐳 镜像列表："
            find "$IMAGE_DIR" -name "*.tar" -type f -exec basename {} \; | head -5
            if [[ "$image_count" -gt 5 ]]; then
                echo "  ... 还有 $((image_count - 5)) 个镜像"
            fi
        fi
    else
        echo "❌ 构建目录不存在"
    fi
    
    # 检查服务器配置
    local server_count=$(get_server_count)
    echo "🖥️  配置的服务器: $server_count 台"
    
    echo "================================"
}

# 安装 debs 到选定服务器（从本地 $DEB_DIR 选择包 → 选择服务器 → 远端安装）
install_debs_on_servers() {
    echo "🧩 安装 debs 到服务器..."
    # 列出本地 deb
    local debs=()
    if [[ -d "$DEB_DIR" ]]; then
        while IFS= read -r f; do debs+=("$(basename "$f")"); done < <(find "$DEB_DIR" -name "*.deb" -type f)
    fi
    if [[ ${#debs[@]} -eq 0 ]]; then echo "❌ 本地没有 deb 包"; return 1; fi
    echo "📦 可安装 deb 包："; for i in $(seq 0 $((${#debs[@]}-1))); do echo "$((i+1)). ${debs[i]}"; done
    read -p "请输入要安装的 deb 序号（空格分隔，all 为全部）: " idxs
    local chosen=()
    if [[ "$idxs" == "all" ]]; then chosen=("${debs[@]}"); else IFS=' ' read -ra IDS <<< "$idxs"; for id in "${IDS[@]}"; do [[ "$id" =~ ^[0-9]+$ ]] && [[ "$id" -ge 1 ]] && [[ "$id" -le ${#debs[@]} ]] && chosen+=("${debs[id-1]}") || echo "⚠️  忽略: $id"; done; fi
    [[ ${#chosen[@]} -eq 0 ]] && { echo "❌ 未选择 deb"; return 1; }

    # 选择服务器
    local server_count=$(get_server_count); [[ "$server_count" -eq 0 ]] && { echo "❌ 未配置服务器"; return 1; }
    echo "🖥️  可用的服务器："; for i in $(seq 1 "$server_count"); do eval host_ip="\$SERVER_${i}_PUBLIC_IP"; echo "$i. $host_ip"; done
    read -p "请输入要安装的服务器序号（空格分隔，all 为全部）: " sidx
    local servers=()
    if [[ "$sidx" == "all" ]]; then for i in $(seq 1 "$server_count"); do servers+=("$i"); done; else IFS=' ' read -ra SIDS <<< "$sidx"; for id in "${SIDS[@]}"; do [[ "$id" =~ ^[0-9]+$ ]] && [[ "$id" -ge 1 ]] && [[ "$id" -le "$server_count" ]] && servers+=("$id") || echo "⚠️  忽略: $id"; done; fi
    [[ ${#servers[@]} -eq 0 ]] && { echo "❌ 未选择服务器"; return 1; }

    # 逐台服务器安装
    for i in "${servers[@]}"; do
        eval host="\$SERVER_${i}_PUBLIC_IP"; eval user="\$SERVER_${i}_USER"; eval pass="\${SERVER_${i}_PASS-}"; eval secret="\${SERVER_${i}_SECRET-}"; eval port="\${SERVER_${i}_SSH_PORT-1022}"
        echo "🖥️  在 $host 安装..."
        # 上传并安装每个 deb
        for f in "${chosen[@]}"; do
            echo "  📤 传输 $f 并安装..."
            local remote_path="/tmp/$f"
            if [[ -n "$secret" && -f "$secret" ]]; then
                scp -P "$port" -i "$secret" -o StrictHostKeyChecking=no "$DEB_DIR/$f" "$user@$host:$remote_path" || { echo "  ❌ 传输失败 $f"; continue; }
                ssh -p "$port" -i "$secret" -o StrictHostKeyChecking=no "$user@$host" "sudo dpkg -i '$remote_path' || sudo apt-get -f install -y && sudo dpkg -i '$remote_path' && rm -f '$remote_path'" && echo "  ✅ 安装完成: $f" || echo "  ❌ 安装失败: $f"
            else
                sshpass -p "$pass" scp -P "$port" -o StrictHostKeyChecking=no "$DEB_DIR/$f" "$user@$host:$remote_path" || { echo "  ❌ 传输失败 $f"; continue; }
                sshpass -p "$pass" ssh -p "$port" -o StrictHostKeyChecking=no "$user@$host" "sudo dpkg -i '$remote_path' || sudo apt-get -f install -y && sudo dpkg -i '$remote_path' && rm -f '$remote_path'" && echo "  ✅ 安装完成: $f" || echo "  ❌ 安装失败: $f"
            fi
        done
    done
}

# 安装 images 到选定服务器（选择服务器 → 扫描远程镜像包 → 选择镜像包 → 选择导入方式 → 导入到本地）
install_images_on_servers() {
    echo "🧩 安装 images 到服务器（从远程导入镜像到本地）..."
    
    # 第一步：选择服务器
    local server_count=$(get_server_count)
    if [[ "$server_count" -eq 0 ]]; then 
        echo "❌ 未配置服务器"; 
        return 1; 
    fi
    
    echo "🖥️  可用的服务器："
    for i in $(seq 1 "$server_count"); do 
        eval host_ip="\$SERVER_${i}_PUBLIC_IP"
        eval user="\$SERVER_${i}_USER"
        echo "$i. $host_ip (用户: $user)"
    done
    
    read -p "请输入服务器序号（空格分隔，all 为全部）: " sidx
    local servers=()
    if [[ "$sidx" == "all" ]]; then 
        for i in $(seq 1 "$server_count"); do 
            servers+=("$i")
        done
    else 
        IFS=' ' read -ra SIDS <<< "$sidx"
        for id in "${SIDS[@]}"; do 
            if [[ "$id" =~ ^[0-9]+$ ]] && [[ "$id" -ge 1 ]] && [[ "$id" -le "$server_count" ]]; then 
                servers+=("$id")
            else 
                echo "⚠️  忽略无效服务器序号: $id"
            fi
        done
    fi
    
    if [[ ${#servers[@]} -eq 0 ]]; then 
        echo "❌ 未选择服务器"; 
        return 1; 
    fi

    # 第二步：扫描远程镜像包
    for i in "${servers[@]}"; do
        eval host="\$SERVER_${i}_PUBLIC_IP"
        eval user="\$SERVER_${i}_USER"
        eval pass="\${SERVER_${i}_PASS-}"
        eval secret="\${SERVER_${i}_SECRET-}"
        eval port="\${SERVER_${i}_SSH_PORT-1022}"
        eval dir="\${SERVER_${i}_DIR-~/packages-to-be-installed}"
        
        echo "🖥️  扫描服务器 $host 的镜像包..."
        
        # 构建远程镜像目录路径
        local remote_images_dir="$dir/images"
        if [[ "$remote_images_dir" == ~* ]]; then
            remote_images_dir="/home/$user${remote_images_dir#\~}"
        fi
        
        # 扫描远程镜像包
        local remote_images=()
        local scan_command="find '$remote_images_dir' -name '*.tar' -type f 2>/dev/null | sort"
        
        if [[ -n "$secret" && -f "$secret" ]]; then
            local scan_result=$(ssh -p "$port" -i "$secret" -o StrictHostKeyChecking=no "$user@$host" "$scan_command" 2>/dev/null)
        else
            local scan_result=$(sshpass -p "$pass" ssh -p "$port" -o StrictHostKeyChecking=no "$user@$host" "$scan_command" 2>/dev/null)
        fi
        
        if [[ -z "$scan_result" ]]; then
            echo "  ❌ 服务器 $host 的 $remote_images_dir 目录下没有找到镜像包"
            continue
        fi
        
        # 解析扫描结果
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                remote_images+=("$(basename "$line")")
            fi
        done <<< "$scan_result"
        
        if [[ ${#remote_images[@]} -eq 0 ]]; then
            echo "  ❌ 服务器 $host 没有可用的镜像包"
            continue
        fi
        
        echo "  📦 找到 ${#remote_images[@]} 个镜像包："
        for idx in $(seq 0 $((${#remote_images[@]}-1))); do
            local image="${remote_images[idx]}"
            echo "    $((idx+1)). $image"
        done
        
        # 第三步：用户选择远程镜像包
        read -p "  请选择要导入的镜像包序号（空格分隔，all 为全部）: " image_idxs
        local chosen_images=()
        if [[ "$image_idxs" == "all" ]]; then
            chosen_images=("${remote_images[@]}")
        else
            IFS=' ' read -ra IMAGE_IDS <<< "$image_idxs"
            for img_id in "${IMAGE_IDS[@]}"; do
                if [[ "$img_id" =~ ^[0-9]+$ ]] && [[ "$img_id" -ge 1 ]] && [[ "$img_id" -le ${#remote_images[@]} ]]; then
                    chosen_images+=("${remote_images[img_id-1]}")
                else
                    echo "    ⚠️  忽略无效镜像序号: $img_id"
                fi
            done
        fi
        
        if [[ ${#chosen_images[@]} -eq 0 ]]; then
            echo "  ❌ 未选择镜像包"
            continue
        fi
        
        # 第四步：探测可用的导入方式
        local available_methods=()
        if [[ -n "$secret" && -f "$secret" ]]; then
            ssh -p "$port" -i "$secret" -o StrictHostKeyChecking=no "$user@$host" "command -v docker >/dev/null 2>&1" && available_methods+=("docker")
            ssh -p "$port" -i "$secret" -o StrictHostKeyChecking=no "$user@$host" "command -v nerdctl >/dev/null 2>&1" && available_methods+=("nerdctl")
            ssh -p "$port" -i "$secret" -o StrictHostKeyChecking=no "$user@$host" "command -v ctr >/dev/null 2>&1" && available_methods+=("ctr")
        else
            sshpass -p "$pass" ssh -p "$port" -o StrictHostKeyChecking=no "$user@$host" "command -v docker >/dev/null 2>&1" && available_methods+=("docker")
            sshpass -p "$pass" ssh -p "$port" -o StrictHostKeyChecking=no "$user@$host" "command -v nerdctl >/dev/null 2>&1" && available_methods+=("nerdctl")
            sshpass -p "$pass" ssh -p "$port" -o StrictHostKeyChecking=no "$user@$host" "command -v ctr >/dev/null 2>&1" && available_methods+=("ctr")
        fi

        if [[ ${#available_methods[@]} -eq 0 ]]; then
            echo "  ❌ 远端未检测到可用的导入工具（docker/nerdctl/ctr）。请先安装其中之一。"
            continue
        fi

        # 第五步：用户选择导入方式
        echo "  ⚙️  可用导入方式："
        for idx in $(seq 0 $((${#available_methods[@]}-1))); do 
            echo "    $((idx+1)). ${available_methods[idx]}"
        done
        read -p "  选择导入方式（默认1）: " method_idx
        if [[ -z "$method_idx" || ! "$method_idx" =~ ^[0-9]+$ || "$method_idx" -lt 1 || "$method_idx" -gt ${#available_methods[@]} ]]; then 
            method_idx=1
        fi
        local method="${available_methods[method_idx-1]}"
        echo "  ✅ 使用方式: $method"

        # 如果选择 nerdctl 或 ctr，询问命名空间
        local container_namespace="k8s.io"
        if [[ "$method" == "nerdctl" ]] || [[ "$method" == "ctr" ]]; then
            echo "  📦 选择容器命名空间："
            echo "    1. k8s.io (Kubernetes 默认，推荐)"
            echo "    2. default (容器运行时默认)"
            echo "    3. 自定义命名空间"
            read -p "    选择命名空间 (1-3，默认1): " namespace_choice
            case "$namespace_choice" in
                1) container_namespace="k8s.io" ;;
                2) container_namespace="default" ;;
                3) 
                    read -p "    请输入自定义命名空间: " custom_namespace
                    container_namespace="${custom_namespace:-k8s.io}"
                    ;;
                *) container_namespace="k8s.io" ;;
            esac
            echo "  ✅ 命名空间: $container_namespace"
        fi

        # 第六步：执行导入
        echo "  🚀 开始导入镜像包..."
        for image_tar in "${chosen_images[@]}"; do
            echo "    📥 导入 $image_tar..."
            local remote_tar_path="$remote_images_dir/$image_tar"
            
            if [[ -n "$secret" && -f "$secret" ]]; then
                if [[ -n "$pass" ]]; then
                    if [[ "$method" == "docker" ]]; then
                        ssh -p "$port" -i "$secret" -o StrictHostKeyChecking=no "$user@$host" "echo '$pass' | sudo -S docker load -i '$remote_tar_path'"
                    elif [[ "$method" == "nerdctl" ]]; then
                        ssh -p "$port" -i "$secret" -o StrictHostKeyChecking=no "$user@$host" "echo '$pass' | sudo -S nerdctl -n $container_namespace load -i '$remote_tar_path'"
                    else
                        ssh -p "$port" -i "$secret" -o StrictHostKeyChecking=no "$user@$host" "echo '$pass' | sudo -S ctr -n $container_namespace images import '$remote_tar_path'"
                    fi
                else
                    if [[ "$method" == "docker" ]]; then
                        ssh -p "$port" -i "$secret" -o StrictHostKeyChecking=no "$user@$host" "sudo -n docker load -i '$remote_tar_path' || docker load -i '$remote_tar_path'"
                    elif [[ "$method" == "nerdctl" ]]; then
                        ssh -p "$port" -i "$secret" -o StrictHostKeyChecking=no "$user@$host" "sudo -n nerdctl -n $container_namespace load -i '$remote_tar_path' || nerdctl -n $container_namespace load -i '$remote_tar_path'"
                    else
                        ssh -p "$port" -i "$secret" -o StrictHostKeyChecking=no "$user@$host" "sudo -n ctr -n $container_namespace images import '$remote_tar_path' || ctr -n $container_namespace images import '$remote_tar_path'"
                    fi
                fi
            else
                if [[ "$method" == "docker" ]]; then
                    sshpass -p "$pass" ssh -p "$port" -o StrictHostKeyChecking=no "$user@$host" "echo '$pass' | sudo -S docker load -i '$remote_tar_path'"
                elif [[ "$method" == "nerdctl" ]]; then
                    sshpass -p "$pass" ssh -p "$port" -o StrictHostKeyChecking=no "$user@$host" "echo '$pass' | sudo -S nerdctl -n $container_namespace load -i '$remote_tar_path'"
                else
                    sshpass -p "$pass" ssh -p "$port" -o StrictHostKeyChecking=no "$user@$host" "echo '$pass' | sudo -S ctr -n $container_namespace images import '$remote_tar_path'"
                fi
            fi
            
            if [[ $? -eq 0 ]]; then
                echo "      ✅ 导入成功: $image_tar"
            else
                echo "      ❌ 导入失败: $image_tar"
            fi
        done
        
        echo "  🎉 服务器 $host 镜像导入完成"
    done
    
    echo "🎉 所有服务器镜像导入完成！"
}

# 安装 tar 包到选定服务器（选择服务器 → 扫描远程 tar 包 → 选择 tar 包 → 选择安装方式 → 安装到系统）
install_tars_on_servers() {
    echo "📦 安装 tar 包到服务器（从远程 tar 包安装到系统）..."
    
    # 第一步：选择服务器
    local server_count=$(get_server_count)
    if [[ "$server_count" -eq 0 ]]; then 
        echo "❌ 未配置服务器"; 
        return 1; 
    fi
    
    echo "🖥️  可用的服务器："
    for i in $(seq 1 "$server_count"); do 
        eval host_ip="\$SERVER_${i}_PUBLIC_IP"
        eval user="\$SERVER_${i}_USER"
        echo "$i. $host_ip (用户: $user)"
    done
    
    read -p "请输入服务器序号（空格分隔，all 为全部）: " sidx
    local servers=()
    if [[ "$sidx" == "all" ]]; then 
        for i in $(seq 1 "$server_count"); do 
            servers+=("$i")
        done
    else 
        IFS=' ' read -ra SIDS <<< "$sidx"
        for id in "${SIDS[@]}"; do 
            if [[ "$id" =~ ^[0-9]+$ ]] && [[ "$id" -ge 1 ]] && [[ "$id" -le "$server_count" ]]; then 
                servers+=("$id")
            else 
                echo "⚠️  忽略无效服务器序号: $id"
            fi
        done
    fi
    
    if [[ ${#servers[@]} -eq 0 ]]; then 
        echo "❌ 未选择服务器"; 
        return 1; 
    fi

    # 第二步：扫描远程 tar 包
    for i in "${servers[@]}"; do
        eval host="\$SERVER_${i}_PUBLIC_IP"
        eval user="\$SERVER_${i}_USER"
        eval pass="\${SERVER_${i}_PASS-}"
        eval secret="\${SERVER_${i}_SECRET-}"
        eval port="\${SERVER_${i}_SSH_PORT-1022}"
        eval dir="\${SERVER_${i}_DIR-~/packages-to-be-installed}"
        
        echo "🖥️  扫描服务器 $host 的 tar 包..."
        
        # 构建远程 tar 目录路径
        local remote_tars_dir="$dir/tars"
        if [[ "$remote_tars_dir" == ~* ]]; then
            remote_tars_dir="/home/$user${remote_tars_dir#\~}"
        fi
        
        # 扫描远程 tar 包
        local remote_tars=()
        local scan_command="find '$remote_tars_dir' -name '*.tar*' -type f 2>/dev/null | sort"
        
        if [[ -n "$secret" && -f "$secret" ]]; then
            local scan_result=$(ssh -p "$port" -i "$secret" -o StrictHostKeyChecking=no "$user@$host" "$scan_command" 2>/dev/null)
        else
            local scan_result=$(sshpass -p "$pass" ssh -p "$port" -o StrictHostKeyChecking=no "$user@$host" "$scan_command" 2>/dev/null)
        fi
        
        if [[ -z "$scan_result" ]]; then
            echo "  ❌ 服务器 $host 的 $remote_tars_dir 目录下没有找到 tar 包"
            continue
        fi
        
        # 解析扫描结果
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                remote_tars+=("$(basename "$line")")
            fi
        done <<< "$scan_result"
        
        if [[ ${#remote_tars[@]} -eq 0 ]]; then
            echo "  ❌ 服务器 $host 没有可用的 tar 包"
            continue
        fi
        
        echo "  📦 找到 ${#remote_tars[@]} 个 tar 包："
        for idx in $(seq 0 $((${#remote_tars[@]}-1))); do
            local tar_file="${remote_tars[idx]}"
            echo "    $((idx+1)). $tar_file"
        done
        
        # 第三步：用户选择远程 tar 包
        read -p "  请选择要安装的 tar 包序号（空格分隔，all 为全部）: " tar_idxs
        local chosen_tars=()
        if [[ "$tar_idxs" == "all" ]]; then
            chosen_tars=("${remote_tars[@]}")
        else
            IFS=' ' read -ra TAR_IDS <<< "$tar_idxs"
            for tar_id in "${TAR_IDS[@]}"; do
                if [[ "$tar_id" =~ ^[0-9]+$ ]] && [[ "$tar_id" -ge 1 ]] && [[ "$tar_id" -le ${#remote_tars[@]} ]]; then
                    chosen_tars+=("${remote_tars[tar_id-1]}")
                else
                    echo "    ⚠️  忽略无效 tar 包序号: $tar_id"
                fi
            done
        fi
        
        if [[ ${#chosen_tars[@]} -eq 0 ]]; then
            echo "  ❌ 未选择 tar 包"
            continue
        fi
        
        # 第四步：选择安装方式
        echo "  ⚙️  选择安装方式："
        echo "    1. 解压到 /usr/local/bin（推荐）"
        echo "    2. 解压到 /opt"
        echo "    3. 解压到 /tmp 并手动处理"
        echo "    4. 自定义路径"
        read -p "  选择安装方式（1-4，默认1）: " install_method
        install_method=${install_method:-1}
        
        local install_path=""
        case "$install_method" in
            1) install_path="/usr/local/bin" ;;
            2) install_path="/opt" ;;
            3) install_path="/tmp" ;;
            4) 
                read -p "  请输入自定义安装路径: " custom_path
                install_path="$custom_path"
                ;;
            *) 
                echo "  ❌ 无效选择，使用默认路径 /usr/local/bin"
                install_path="/usr/local/bin"
                ;;
        esac
        
        echo "  ✅ 安装路径: $install_path"

        # 第五步：执行安装
        echo "  🚀 开始安装 tar 包..."
        for tar_file in "${chosen_tars[@]}"; do
            echo "    📦 安装 $tar_file..."
            local remote_tar_path="$remote_tars_dir/$tar_file"
            
            # 构建安装命令
            local install_cmd=""
            if [[ "$install_method" == "3" ]]; then
                # 仅解压到 /tmp
                install_cmd="cd /tmp && tar -xzf '$remote_tar_path' && echo '已解压到 /tmp，请手动处理'"
            else
                # 解压并安装到指定路径
                install_cmd="sudo mkdir -p '$install_path' && cd '$install_path' && sudo tar -xzf '$remote_tar_path' && sudo chmod +x '$install_path'/* 2>/dev/null || true"
            fi
            
            if [[ -n "$secret" && -f "$secret" ]]; then
                if [[ -n "$pass" ]]; then
                    ssh -p "$port" -i "$secret" -o StrictHostKeyChecking=no "$user@$host" "echo '$pass' | sudo -S bash -c '$install_cmd'"
                else
                    ssh -p "$port" -i "$secret" -o StrictHostKeyChecking=no "$user@$host" "sudo -n bash -c '$install_cmd' || bash -c '$install_cmd'"
                fi
            else
                sshpass -p "$pass" ssh -p "$port" -o StrictHostKeyChecking=no "$user@$host" "echo '$pass' | sudo -S bash -c '$install_cmd'"
            fi
            
            if [[ $? -eq 0 ]]; then
                echo "      ✅ 安装成功: $tar_file"
                if [[ "$install_method" != "3" ]]; then
                    echo "      📁 安装位置: $install_path"
                fi
            else
                echo "      ❌ 安装失败: $tar_file"
            fi
        done
        
        echo "  🎉 服务器 $host tar 包安装完成"
    done
    
    echo "🎉 所有服务器 tar 包安装完成！"
}

# =============================================================================
# 上传功能
# =============================================================================

# 上传镜像到服务器
upload_images_to_servers() {
    echo "📤 上传镜像到服务器..."
    
    # 检查是否有镜像可上传
    local available_packages=()
    if [[ -d "$IMAGE_DIR" ]]; then
        for tar_file in "$IMAGE_DIR"/*.tar; do
            if [[ -f "$tar_file" ]]; then
                local filename=$(basename "$tar_file")
                available_packages+=("$filename")
            fi
        done
    fi
    
    if [[ ${#available_packages[@]} -eq 0 ]]; then
        echo "❌ 没有找到可上传的镜像包"
        echo "💡 请先运行构建功能创建镜像包，或确保 $IMAGE_DIR 目录下有 .tar 文件"
        return 1
    fi
    
    echo "📦 可用的镜像包："
    echo "================================"
    for i in $(seq 0 $((${#available_packages[@]}-1))); do
        local package="${available_packages[i]}"
        local size=$(du -h "$IMAGE_DIR/$package" | cut -f1)
        local date=$(stat -c %y "$IMAGE_DIR/$package" | cut -d' ' -f1)
        echo "$((i+1)). $package ($size, 创建时间: $date)"
    done
    echo "================================"
    
    # 选择镜像包
    echo "请输入要上传的镜像包序号（用空格分隔多个序号，如：1 2，输入 all 选择全部）："
    read -p "镜像包序号: " selected_packages
    
    local packages_to_upload=()
    if [[ "$selected_packages" == "all" ]]; then
        packages_to_upload=("${available_packages[@]}")
    else
        IFS=' ' read -ra PACKAGE_INDICES <<< "$selected_packages"
        for package_index in "${PACKAGE_INDICES[@]}"; do
            if [[ "$package_index" =~ ^[0-9]+$ ]] && [[ "$package_index" -ge 1 ]] && [[ "$package_index" -le ${#available_packages[@]} ]]; then
                local selected_package="${available_packages[package_index-1]}"
                packages_to_upload+=("$selected_package")
                echo "✅ 选择镜像包: $selected_package"
            else
                echo "⚠️  忽略无效镜像包序号: $package_index"
            fi
        done
    fi
    
    if [[ ${#packages_to_upload[@]} -eq 0 ]]; then
        echo "❌ 没有选择有效的镜像包"
        return 1
    fi
    
    # 选择上传方式
    echo ""
    echo "📤 选择上传方式："
    echo "1. 上传到所有服务器"
    echo "2. 上传到指定服务器"
    echo "3. 手动输入服务器信息"
    echo ""
    read -p "请选择 (1-3): " upload_choice
    
    # 临时保存选择的镜像包，供后续函数使用
    export SELECTED_IMAGE_PACKAGES=("${packages_to_upload[@]}")
    
    case "$upload_choice" in
        1)
            echo "📤 上传到所有服务器..."
            upload_images_to_all_servers_selected
            ;;
        2)
            echo "📤 上传到指定服务器..."
            upload_images_to_selected_servers_selected
            ;;
        3)
            echo "📤 手动输入服务器信息..."
            upload_images_to_manual_servers_selected
            ;;
        *)
            echo "❌ 无效选择"
            return 1
            ;;
    esac
}

# 上传已选择的镜像包到所有服务器
upload_images_to_all_servers_selected() {
    if [[ -z "${SELECTED_IMAGE_PACKAGES:-}" ]] || [[ ${#SELECTED_IMAGE_PACKAGES[@]} -eq 0 ]]; then
        echo "❌ 没有选择镜像包"
        return 1
    fi
    
    local packages_to_upload=("${SELECTED_IMAGE_PACKAGES[@]}")
    local server_count=$(get_server_count)
    if [[ "$server_count" -eq 0 ]]; then
        echo "❌ 配置文件中未找到任何服务器配置"
        return 1
    fi
    
    echo "🖥️  将上传到所有 $server_count 台服务器："
    for i in $(seq 1 "$server_count"); do
        local host_var="SERVER_${i}_PUBLIC_IP"
        local user_var="SERVER_${i}_USER"
        local host=${!host_var}
        local user=${!user_var}
        echo "  - $host ($user)"
    done
    
    # 上传镜像包到所有服务器
    for package in "${packages_to_upload[@]}"; do
        echo ""
        echo "📦 上传镜像包: $package"
        for i in $(seq 1 "$server_count"); do
            local host_var="SERVER_${i}_PUBLIC_IP"
            local user_var="SERVER_${i}_USER"
            local port_var="SERVER_${i}_SSH_PORT"
            local secret_var="SERVER_${i}_SECRET"
            local pass_var="SERVER_${i}_PASS"
            local dir_var="SERVER_${i}_DIR"
            
            local host=${!host_var}
            local user=${!user_var}
            local port=${!port_var:-22}
            local secret=${!secret_var:-}
            local pass=${!pass_var:-}
            local remote_dir=${!dir_var:-~/packages-to-be-installed}
            remote_dir="${remote_dir%/}/images"
            
            echo "  → 上传到 $host ($user)..."
            # 创建远程目录并上传
            local SSH_OPTS="-o StrictHostKeyChecking=no"
            local SCP_OPTS="-P $port"
            local payload_mkdir="$(printf 'mkdir -p "%s"\n' "$remote_dir" | base64 -w0)"
            if [[ -n "$secret" && "$secret" != "none" && -f "$secret" ]]; then
                local key_file=$(get_ssh_key_path "$secret")
                ssh -i "$key_file" $SSH_OPTS -p $port "$user@$host" "bash -lc 'echo $payload_mkdir | base64 -d | bash -e'" 2>/dev/null || true
                if scp -i "$key_file" $SCP_OPTS "$IMAGE_DIR/$package" "$user@$host:$remote_dir/" 2>/dev/null; then
                    echo "    ✅ 上传成功"
                else
                    echo "    ❌ 上传失败"
                fi
            elif [[ -n "$pass" && "$pass" != "none" ]]; then
                sshpass -p "$pass" ssh $SSH_OPTS -p $port "$user@$host" "bash -lc 'echo $payload_mkdir | base64 -d | bash -e'" 2>/dev/null || true
                if sshpass -p "$pass" scp $SCP_OPTS "$IMAGE_DIR/$package" "$user@$host:$remote_dir/" 2>/dev/null; then
                    echo "    ✅ 上传成功"
                else
                    echo "    ❌ 上传失败"
                fi
            else
                echo "    ❌ 服务器 $host 未提供有效的密钥或密码，跳过"
            fi
        done
    done
    
    echo ""
    echo "✅ 所有镜像包上传完成！"
}

# 上传已选择的镜像包到指定服务器
upload_images_to_selected_servers_selected() {
    if [[ -z "${SELECTED_IMAGE_PACKAGES:-}" ]] || [[ ${#SELECTED_IMAGE_PACKAGES[@]} -eq 0 ]]; then
        echo "❌ 没有选择镜像包"
        return 1
    fi
    
    local packages_to_upload=("${SELECTED_IMAGE_PACKAGES[@]}")
    local server_count=$(get_server_count)
    if [[ "$server_count" -eq 0 ]]; then
        echo "❌ 配置文件中未找到任何服务器配置"
        return 1
    fi
    
    echo "🖥️  可用的服务器："
    echo "================================"
    for i in $(seq 1 "$server_count"); do
        local host_var="SERVER_${i}_PUBLIC_IP"
        local user_var="SERVER_${i}_USER"
        local type_var="SERVER_${i}_TYPE"
        local host=${!host_var}
        local user=${!user_var}
        local node_type=${!type_var:-unknown}
        echo "$i. $host (用户: $user, 类型: $node_type)"
    done
    echo "================================"
    
    read -p "请输入要上传的服务器序号（用空格分隔多个序号，如：1 2）：" server_indices
    
    local servers_to_upload=()
    IFS=' ' read -ra SERVER_INDICES <<< "$server_indices"
    for server_index in "${SERVER_INDICES[@]}"; do
        if [[ "$server_index" =~ ^[0-9]+$ ]] && [[ "$server_index" -ge 1 ]] && [[ "$server_index" -le "$server_count" ]]; then
            servers_to_upload+=("$server_index")
        else
            echo "⚠️  忽略无效服务器序号: $server_index"
        fi
    done
    
    if [[ ${#servers_to_upload[@]} -eq 0 ]]; then
        echo "❌ 没有选择有效的服务器"
        return 1
    fi
    
    # 上传镜像包到选定的服务器
    for package in "${packages_to_upload[@]}"; do
        echo ""
        echo "📦 上传镜像包: $package"
        for server_index in "${servers_to_upload[@]}"; do
            local host_var="SERVER_${server_index}_PUBLIC_IP"
            local user_var="SERVER_${server_index}_USER"
            local port_var="SERVER_${server_index}_SSH_PORT"
            local secret_var="SERVER_${server_index}_SECRET"
            local pass_var="SERVER_${server_index}_PASS"
            local dir_var="SERVER_${server_index}_DIR"
            
            local host=${!host_var}
            local user=${!user_var}
            local port=${!port_var:-22}
            local secret=${!secret_var:-}
            local pass=${!pass_var:-}
            local remote_dir=${!dir_var:-~/packages-to-be-installed}
            remote_dir="${remote_dir%/}/images"
            
            echo "  → 上传到 $host ($user)..."
            # 创建远程目录并上传
            local SSH_OPTS="-o StrictHostKeyChecking=no"
            local SCP_OPTS="-P $port"
            local payload_mkdir="$(printf 'mkdir -p "%s"\n' "$remote_dir" | base64 -w0)"
            if [[ -n "$secret" && "$secret" != "none" && -f "$secret" ]]; then
                local key_file=$(get_ssh_key_path "$secret")
                ssh -i "$key_file" $SSH_OPTS -p $port "$user@$host" "bash -lc 'echo $payload_mkdir | base64 -d | bash -e'" 2>/dev/null || true
                if scp -i "$key_file" $SCP_OPTS "$IMAGE_DIR/$package" "$user@$host:$remote_dir/" 2>/dev/null; then
                    echo "    ✅ 上传成功"
                else
                    echo "    ❌ 上传失败"
                fi
            elif [[ -n "$pass" && "$pass" != "none" ]]; then
                sshpass -p "$pass" ssh $SSH_OPTS -p $port "$user@$host" "bash -lc 'echo $payload_mkdir | base64 -d | bash -e'" 2>/dev/null || true
                if sshpass -p "$pass" scp $SCP_OPTS "$IMAGE_DIR/$package" "$user@$host:$remote_dir/" 2>/dev/null; then
                    echo "    ✅ 上传成功"
                else
                    echo "    ❌ 上传失败"
                fi
            else
                echo "    ❌ 服务器 $host 未提供有效的密钥或密码，跳过"
            fi
        done
    done
    
    echo ""
    echo "✅ 所有镜像包上传完成！"
}

# 上传已选择的镜像包到手动输入的服务器
upload_images_to_manual_servers_selected() {
    if [[ -z "${SELECTED_IMAGE_PACKAGES:-}" ]] || [[ ${#SELECTED_IMAGE_PACKAGES[@]} -eq 0 ]]; then
        echo "❌ 没有选择镜像包"
        return 1
    fi
    
    local packages_to_upload=("${SELECTED_IMAGE_PACKAGES[@]}")
    
    read -p "请输入服务器 IP 地址: " manual_host
    read -p "请输入用户名 (默认: root): " manual_user
    manual_user=${manual_user:-root}
    read -p "请输入 SSH 端口 (默认: 22): " manual_port
    manual_port=${manual_port:-22}
    read -p "请输入私钥路径 (可选，直接回车跳过): " manual_secret
    read -p "请输入密码 (可选，直接回车跳过): " manual_pass
    read -p "请输入远程目录 (默认: ~/packages-to-be-installed/images): " manual_dir
    manual_dir=${manual_dir:-~/packages-to-be-installed/images}
    
    # 上传镜像包
    for package in "${packages_to_upload[@]}"; do
        echo ""
        echo "📦 上传镜像包: $package"
        echo "  → 上传到 $manual_host ($manual_user)..."
        upload_file_to_server "$IMAGE_DIR/$package" "$manual_host" "$manual_user" "$manual_port" "$manual_secret" "$manual_pass" "$manual_dir"
    done
    
    echo ""
    echo "✅ 所有镜像包上传完成！"
}

# 仅上传包
upload_packages_only() {
    echo "📤 上传 deb 包到服务器..."
    
    # 检查是否有包可上传
    local deb_count=$(find "$DEB_DIR" -name "*.deb" -type f 2>/dev/null | wc -l)
    if [[ "$deb_count" -eq 0 ]]; then
        echo "❌ 没有找到可上传的 deb 包"
        echo "💡 请先运行构建功能创建 deb 包"
        return 1
    fi
    
    echo "📊 找到 $deb_count 个 deb 包可上传"
    
    # 显示包列表
    echo "📦 deb 包列表："
    find "$DEB_DIR" -name "*.deb" -type f -exec basename {} \;
    
    # 选择上传方式
    echo ""
    echo "📤 选择上传方式："
    echo "1. 上传到所有服务器"
    echo "2. 上传到指定服务器"
    echo "3. 手动输入服务器信息"
    echo ""
    read -p "请选择 (1-3): " upload_choice
    
    case "$upload_choice" in
        1)
            echo "📤 上传到所有服务器..."
            upload_packages_to_all_servers
            ;;
        2)
            echo "📤 上传到指定服务器..."
            upload_packages_to_selected_servers
            ;;
        3)
            echo "📤 手动输入服务器信息..."
            upload_packages_to_manual_servers
            ;;
        *)
            echo "❌ 无效选择"
            return 1
            ;;
    esac
}

## 已移除：上传所有文件 upload_all_files（应产品需求简化菜单）

# 上传镜像到所有服务器
upload_images_to_all_servers() {
    echo "📤 上传镜像到所有服务器..."
    
    # =============================================================================
    # 第一步：选择要上传的镜像包
    # =============================================================================
    
    # 获取所有镜像包
    local available_packages=()
    if [[ -d "$IMAGE_DIR" ]]; then
        for tar_file in "$IMAGE_DIR"/*.tar; do
            if [[ -f "$tar_file" ]]; then
                local filename=$(basename "$tar_file")
                available_packages+=("$filename")
            fi
        done
    fi
    
    if [[ ${#available_packages[@]} -eq 0 ]]; then
        echo "❌ 没有找到可上传的镜像包"
        echo "💡 请先运行构建功能创建镜像包"
        return 1
    fi
    
    echo "📦 可用的镜像包："
    echo "================================"
    for i in $(seq 0 $((${#available_packages[@]}-1))); do
        local package="${available_packages[i]}"
        local size=$(du -h "$IMAGE_DIR/$package" | cut -f1)
        local date=$(stat -c %y "$IMAGE_DIR/$package" | cut -d' ' -f1)
        echo "$((i+1)). $package ($size, 创建时间: $date)"
    done
    echo "================================"
    
    # 选择镜像包
    echo "请输入要上传的镜像包序号（用空格分隔多个序号，如：1 2）："
    read -p "镜像包序号: " selected_packages
    
    local packages_to_upload=()
    IFS=' ' read -ra PACKAGE_INDICES <<< "$selected_packages"
    for package_index in "${PACKAGE_INDICES[@]}"; do
        if [[ "$package_index" =~ ^[0-9]+$ ]] && [[ "$package_index" -ge 1 ]] && [[ "$package_index" -le ${#available_packages[@]} ]]; then
            local selected_package="${available_packages[package_index-1]}"
            packages_to_upload+=("$selected_package")
            echo "✅ 选择镜像包: $selected_package"
        else
            echo "⚠️  忽略无效镜像包序号: $package_index"
        fi
    done
    
    if [[ ${#packages_to_upload[@]} -eq 0 ]]; then
        echo "❌ 没有选择有效的镜像包"
        return 1
    fi
    
    # =============================================================================
    # 第二步：获取所有服务器信息
    # =============================================================================
    
    # 获取服务器数量
    local server_count=$(get_server_count)
    if [[ "$server_count" -eq 0 ]]; then
        echo "❌ 配置文件中未找到任何服务器配置"
        return 1
    fi
    
    # 获取所有服务器
    local servers_to_upload=()
    for i in $(seq 1 "$server_count"); do
        servers_to_upload+=("$i")
    done
    
    echo "🖥️  将上传到所有 $server_count 台服务器："
    for i in $(seq 1 "$server_count"); do
        local host_var="SERVER_${i}_PUBLIC_IP"
        local user_var="SERVER_${i}_USER"
        local type_var="SERVER_${i}_TYPE"
        
        local host=${!host_var}
        local user=${!user_var}
        local node_type=${!type_var:-unknown}
        
        echo "  $i. $host (用户: $user, 类型: $node_type)"
    done
    
    # =============================================================================
    # 第三步：显示上传计划并确认
    # =============================================================================
    
    echo ""
    echo "📋 上传计划："
    echo "================================"
    echo "📦 要上传的镜像包："
    for package in "${packages_to_upload[@]}"; do
        local size=$(du -h "$IMAGE_DIR/$package" | cut -f1)
        echo "  - $package ($size)"
    done
    
    echo ""
    echo "🖥️  目标服务器："
    for server_index in "${servers_to_upload[@]}"; do
        local host_var="SERVER_${server_index}_PUBLIC_IP"
        local user_var="SERVER_${server_index}_USER"
        local type_var="SERVER_${server_index}_TYPE"
        
        local host=${!host_var}
        local user=${!user_var}
        local node_type=${!type_var:-unknown}
        
        echo "  - $host (用户: $user, 类型: $node_type)"
    done
    
    echo ""
    echo "📊 总计：${#packages_to_upload[@]} 个镜像包 × ${#servers_to_upload[@]} 台服务器 = $(( ${#packages_to_upload[@]} * ${#servers_to_upload[@]} )) 次上传"
    echo "================================"
    
    # 确认上传
    echo ""
    read -p "确认开始上传？(y/N): " confirm_upload
    if [[ ! "$confirm_upload" =~ ^[Yy]$ ]]; then
        echo "❌ 用户取消上传"
        return 0
    fi
    
    echo ""
    echo "🚀 开始上传..."
    
    # =============================================================================
    # 第四步：执行上传
    # =============================================================================
    
    # 遍历所有服务器上传
    for i in $(seq 1 "$server_count"); do
        local host_var="SERVER_${i}_PUBLIC_IP"
        local user_var="SERVER_${i}_USER"
        local pass_var="SERVER_${i}_PASS"
        local secret_var="SERVER_${i}_SECRET"
        local dir_var="SERVER_${i}_DIR"
        local port_var="SERVER_${i}_SSH_PORT"
        
        local host=${!host_var}
        local user=${!user_var}
        local pass=${!pass_var-}
        local secret=${!secret_var-}
        local dir=${!dir_var}
        local port=${!port_var:-1022}
        
        echo "🖥️  上传到服务器 $host..."
        
        # SSH 选项
        local SSH_OPTS="-o StrictHostKeyChecking=no"
        local SCP_OPTS="-P $port"
        
        # 规范化远程基础目录与各子目录
        local base_dir="$dir"
        case "$base_dir" in
            */debs|*/images|*/tars|*/charts) base_dir="${base_dir%/*}";;
        esac
        local remote_deb_dir="$base_dir/debs"
        local remote_img_dir="$base_dir/images"
        
        # 创建远程目录树（使用 base64 注入避免引号问题）
        local payload_mkdir
        payload_mkdir="$(printf '%b' "BD=$base_dir\ncase \"\$BD\" in\n  ~*) BD=\"\$HOME\${BD#\~}\" ;;\n  *) : ;;\nesac\nmkdir -p \"\$BD\"/debs \"\$BD\"/images \"\$BD\"/tars \"\$BD\"/charts\n" | base64 -w0)"
        if [[ -n "$secret" && "$secret" != "none" && -f "$secret" ]]; then
            ssh -i "$(get_ssh_key_path "$secret")" $SSH_OPTS -p $port "$user@$host" "bash -lc 'echo $payload_mkdir | base64 -d | bash -e'"
        elif [[ -n "$pass" && "$pass" != "none" ]]; then
            sshpass -p "$pass" ssh $SSH_OPTS -p $port "$user@$host" "bash -lc 'echo $payload_mkdir | base64 -d | bash -e'"
        else
            echo "  ❌ 服务器 $host 未提供有效的密钥或密码，跳过"
            continue
        fi
        
        # 镜像上传函数只上传镜像包，不上传 deb 包
        
        # 上传用户选择的镜像包
        if [[ ${#packages_to_upload[@]} -gt 0 ]]; then
            echo "  🐳 上传镜像包..."
            for package in "${packages_to_upload[@]}"; do
                echo "    📤 上传 $package..."
                if [[ -n "$secret" && "$secret" != "none" && -f "$secret" ]]; then
                    local key_file=$(get_ssh_key_path "$secret")
                    scp -i "$key_file" $SCP_OPTS "$IMAGE_DIR/$package" "$user@$host:$remote_img_dir/"
                elif [[ -n "$pass" && "$pass" != "none" ]]; then
                    sshpass -p "$pass" scp $SCP_OPTS "$IMAGE_DIR/$package" "$user@$host:$remote_img_dir/"
                fi
                if [[ $? -eq 0 ]]; then
                    echo "      ✅ $package 上传成功"
                else
                    echo "      ❌ $package 上传失败"
                fi
            done
        fi
        
        echo "  ✅ 服务器 $host 所有文件上传完成"
    done
    
    echo "🎉 所有服务器镜像上传完成！"
}

# 上传镜像到指定服务器
upload_images_to_selected_servers() {
    echo "📤 上传镜像到指定服务器..."
    
    # =============================================================================
    # 第一步：选择要上传的镜像包
    # =============================================================================
    
    # 获取所有镜像包
    local available_packages=()
    if [[ -d "$IMAGE_DIR" ]]; then
        for tar_file in "$IMAGE_DIR"/*.tar; do
            if [[ -f "$tar_file" ]]; then
                local filename=$(basename "$tar_file")
                available_packages+=("$filename")
            fi
        done
    fi
    
    if [[ ${#available_packages[@]} -eq 0 ]]; then
        echo "❌ 没有找到可上传的镜像包"
        echo "💡 请先运行构建功能创建镜像包"
        return 1
    fi
    
    echo "📦 可用的镜像包："
    echo "================================"
    for i in $(seq 0 $((${#available_packages[@]}-1))); do
        local package="${available_packages[i]}"
        local size=$(du -h "$IMAGE_DIR/$package" | cut -f1)
        local date=$(stat -c %y "$IMAGE_DIR/$package" | cut -d' ' -f1)
        echo "$((i+1)). $package ($size, 创建时间: $date)"
    done
    echo "================================"
    
    # 选择镜像包
    echo "请输入要上传的镜像包序号（用空格分隔多个序号，如：1 2）："
    read -p "镜像包序号: " selected_packages
    
    local packages_to_upload=()
    IFS=' ' read -ra PACKAGE_INDICES <<< "$selected_packages"
    for package_index in "${PACKAGE_INDICES[@]}"; do
        if [[ "$package_index" =~ ^[0-9]+$ ]] && [[ "$package_index" -ge 1 ]] && [[ "$package_index" -le ${#available_packages[@]} ]]; then
            local selected_package="${available_packages[package_index-1]}"
            packages_to_upload+=("$selected_package")
            echo "✅ 选择镜像包: $selected_package"
        else
            echo "⚠️  忽略无效镜像包序号: $package_index"
        fi
    done
    
    if [[ ${#packages_to_upload[@]} -eq 0 ]]; then
        echo "❌ 没有选择有效的镜像包"
        return 1
    fi
    
    # =============================================================================
    # 第二步：选择要上传的服务器
    # =============================================================================
    
    # 获取服务器数量
    local server_count=$(get_server_count)
    if [[ "$server_count" -eq 0 ]]; then
        echo "❌ 配置文件中未找到任何服务器配置"
        return 1
    fi
    
    echo "🖥️  可用的服务器："
    echo "================================"
    for i in $(seq 1 "$server_count"); do
        local host_var="SERVER_${i}_PUBLIC_IP"
        local user_var="SERVER_${i}_USER"
        local type_var="SERVER_${i}_TYPE"
        
        local host=${!host_var}
        local user=${!user_var}
        local node_type=${!type_var:-unknown}
        
        echo "$i. $host (用户: $user, 类型: $node_type)"
    done
    echo "================================"
    
    # 选择服务器
    echo "请输入要上传的服务器序号（用空格分隔多个序号，如：1 2）："
    read -p "服务器序号: " selected_servers
    
    local servers_to_upload=()
    IFS=' ' read -ra SERVER_INDICES <<< "$selected_servers"
    for server_index in "${SERVER_INDICES[@]}"; do
        if [[ "$server_index" =~ ^[0-9]+$ ]] && [[ "$server_index" -ge 1 ]] && [[ "$server_index" -le "$server_count" ]]; then
            servers_to_upload+=("$server_index")
            local host_var="SERVER_${server_index}_PUBLIC_IP"
            local host=${!host_var}
            echo "✅ 选择服务器: $host"
        else
            echo "⚠️  忽略无效服务器序号: $server_index"
        fi
    done
    
    if [[ ${#servers_to_upload[@]} -eq 0 ]]; then
        echo "❌ 没有选择有效的服务器"
        return 1
    fi
    
    # =============================================================================
    # 第三步：显示上传计划并确认
    # =============================================================================
    
    echo ""
    echo "📋 上传计划："
    echo "================================"
    echo "📦 要上传的镜像包："
    for package in "${packages_to_upload[@]}"; do
        local size=$(du -h "$IMAGE_DIR/$package" | cut -f1)
        echo "  - $package ($size)"
    done
    
    echo ""
    echo "🖥️  目标服务器："
    for server_index in "${servers_to_upload[@]}"; do
        local host_var="SERVER_${server_index}_PUBLIC_IP"
        local user_var="SERVER_${server_index}_USER"
        local type_var="SERVER_${server_index}_TYPE"
        
        local host=${!host_var}
        local user=${!user_var}
        local node_type=${!type_var:-unknown}
        
        echo "  - $host (用户: $user, 类型: $node_type)"
    done
    
    echo ""
    echo "📊 总计：${#packages_to_upload[@]} 个镜像包 × ${#servers_to_upload[@]} 台服务器 = $(( ${#packages_to_upload[@]} * ${#servers_to_upload[@]} )) 次上传"
    echo "================================"
    
    # 确认上传
    echo ""
    read -p "确认开始上传？(y/N): " confirm_upload
    if [[ ! "$confirm_upload" =~ ^[Yy]$ ]]; then
        echo "❌ 用户取消上传"
        return 0
    fi
    
    echo ""
    echo "🚀 开始上传..."
    
    # =============================================================================
    # 第四步：执行上传
    # =============================================================================
    
    # 上传到选定的服务器
    for server_index in "${servers_to_upload[@]}"; do
        local host_var="SERVER_${server_index}_PUBLIC_IP"
        local user_var="SERVER_${server_index}_USER"
        local pass_var="SERVER_${server_index}_PASS"
        local secret_var="SERVER_${server_index}_SECRET"
        local dir_var="SERVER_${server_index}_DIR"
        local port_var="SERVER_${server_index}_SSH_PORT"
        
        local host=${!host_var}
        local user=${!user_var}
        local pass=${!pass_var-}
        local secret=${!secret_var-}
        local dir=${!dir_var}
        local port=${!port_var:-1022}
        
        echo "🖥️  上传到服务器 $host..."
        
        # SSH 选项
        local SSH_OPTS="-o StrictHostKeyChecking=no"
        local SCP_OPTS="-P $port"
        
        # 规范化远程基础目录与各子目录
        local base_dir="$dir"
        case "$base_dir" in
            */debs|*/images|*/tars|*/charts) base_dir="${base_dir%/*}";;
        esac
        local remote_deb_dir="$base_dir/debs"
        local remote_img_dir="$base_dir/images"
        
        # 创建远程目录树（使用 base64 注入避免引号问题）
        local payload_mkdir
        payload_mkdir="$(printf '%b' "BD=$base_dir\ncase \"\$BD\" in\n  ~*) BD=\"\$HOME\${BD#\~}\" ;;\n  *) : ;;\nesac\nmkdir -p \"\$BD\"/debs \"\$BD\"/images \"\$BD\"/tars \"\$BD\"/charts\n" | base64 -w0)"
        if [[ -n "$secret" && "$secret" != "none" && -f "$secret" ]]; then
            ssh -i "$(get_ssh_key_path "$secret")" $SSH_OPTS -p $port "$user@$host" "bash -lc 'echo $payload_mkdir | base64 -d | bash -e'"
        elif [[ -n "$pass" && "$pass" != "none" ]]; then
            sshpass -p "$pass" ssh $SSH_OPTS -p $port "$user@$host" "bash -lc 'echo $payload_mkdir | base64 -d | bash -e'"
        else
            echo "  ❌ 服务器 $host 未提供有效的密钥或密码，跳过"
            continue
        fi
        
        # 镜像上传函数只上传镜像包，不上传 deb 包

        
        # 注意：deb 包上传完成后，不需要上传镜像包
        # 镜像包应该通过专门的镜像上传功能处理
        
        echo "  ✅ 服务器 $host 所有文件上传完成"
    done
    
    echo "🎉 选定服务器上传完成！"
}

# 上传镜像到手动输入的服务器
upload_images_to_manual_servers() {
    echo "📤 上传镜像到手动输入的服务器..."
    
    # 获取所有镜像包
    local available_packages=()
    if [[ -d "$IMAGE_DIR" ]]; then
        for tar_file in "$IMAGE_DIR"/*.tar; do
            if [[ -f "$tar_file" ]]; then
                local filename=$(basename "$tar_file")
                available_packages+=("$filename")
            fi
        done
    fi
    
    if [[ ${#available_packages[@]} -eq 0 ]]; then
        echo "❌ 没有找到可上传的镜像包"
        return 1
    fi
    
    echo "📦 将上传以下镜像包："
    for package in "${available_packages[@]}"; do
        local size=$(du -h "$IMAGE_DIR/$package" | cut -f1)
        echo "  - $package ($size)"
    done
    
    # 手动输入服务器信息
    echo "📝 手动输入服务器信息"
    echo "================================"
    echo "格式：IP:端口:用户名:密码或密钥路径:远程目录"
    echo "示例：192.168.1.100:22:root:mypassword:/opt/images"
    echo "示例：192.168.1.100:22:root:/path/to/key:/opt/images"
    echo "================================"
    
    local manual_servers=()
    while true; do
        read -p "请输入服务器信息（留空结束）: " server_info
        
        if [[ -z "$server_info" ]]; then
            break
        fi
        
        # 解析服务器信息
        IFS=':' read -ra SERVER_PARTS <<< "$server_info"
        if [[ ${#SERVER_PARTS[@]} -eq 5 ]]; then
            local host="${SERVER_PARTS[0]}"
            local port="${SERVER_PARTS[1]}"
            local user="${SERVER_PARTS[2]}"
            local auth="${SERVER_PARTS[3]}"
            local dir="${SERVER_PARTS[4]}"
            
            # 验证信息
            if [[ -z "$host" || -z "$user" || -z "$dir" ]]; then
                echo "❌ 服务器信息不完整，请重新输入"
                continue
            fi
            
            # 检查认证方式
            if [[ -f "$auth" ]]; then
                # 密钥文件
                echo "✅ 添加服务器: $host (密钥认证)"
                manual_servers+=("$host:$port:$user:key:$auth:$dir")
            elif [[ -n "$auth" ]]; then
                # 密码
                echo "✅ 添加服务器: $host (密码认证)"
                manual_servers+=("$host:$port:$user:pass:$auth:$dir")
            else
                echo "❌ 无效的认证信息，请重新输入"
                continue
            fi
        else
            echo "❌ 格式错误，请按照格式输入"
            continue
        fi
    done
    
    if [[ ${#manual_servers[@]} -eq 0 ]]; then
        echo "❌ 没有输入有效的服务器信息"
        return 1
    fi
    
    # 上传到手动输入的服务器
    for server_info in "${manual_servers[@]}"; do
        IFS=':' read -ra SERVER_PARTS <<< "$server_info"
        local host="${SERVER_PARTS[0]}"
        local port="${SERVER_PARTS[1]}"
        local user="${SERVER_PARTS[2]}"
        local auth_type="${SERVER_PARTS[3]}"
        local auth_value="${SERVER_PARTS[4]}"
        local dir="${SERVER_PARTS[5]}"
        
        echo "🖥️  上传镜像到手动输入服务器 $host..."
        
        # SSH 选项
        local SSH_OPTS="-o StrictHostKeyChecking=no"
        local SCP_OPTS="-P $port"
        
        # 规范化远程基础目录与各子目录
        local base_dir="$dir"
        case "$base_dir" in
            */debs|*/images|*/tars|*/charts) base_dir="${base_dir%/*}";;
        esac
        local remote_deb_dir="$base_dir/debs"
        local remote_img_dir="$base_dir/images"
        
        # 创建远程目录树（使用 base64 注入避免引号问题）
        local payload_mkdir
        payload_mkdir="$(printf '%b' "BD=$base_dir\ncase \"\$BD\" in\n  ~*) BD=\"\$HOME\${BD#\~}\" ;;\n  *) : ;;\nesac\nmkdir -p \"\$BD\"/debs \"\$BD\"/images \"\$BD\"/tars \"\$BD\"/charts\n" | base64 -w0)"
        if [[ -n "$secret" && "$secret" != "none" && -f "$secret" ]]; then
            ssh -i "$(get_ssh_key_path "$secret")" $SSH_OPTS -p $port "$user@$host" "bash -lc 'echo $payload_mkdir | base64 -d | bash -e'"
        elif [[ -n "$pass" && "$pass" != "none" ]]; then
            sshpass -p "$pass" ssh $SSH_OPTS -p $port "$user@$host" "bash -lc 'echo $payload_mkdir | base64 -d | bash -e'"
        else
            echo "  ❌ 服务器 $host 未提供有效的密钥或密码，跳过"
            continue
        fi
        
        # 镜像上传函数只上传镜像包，不上传 deb 包
        
        # 注意：deb 包上传完成后，不需要上传镜像包
        # 镜像包应该通过专门的镜像上传功能处理
        
        echo "  ✅ 服务器 $host 所有文件上传完成"
    done
    
    echo "🎉 手动输入服务器镜像上传完成！"
}

# 上传包到所有服务器
upload_packages_to_all_servers() {
    echo "📤 上传包到所有服务器..."
    
    # =============================================================================
    # 第一步：选择要上传的deb包
    # =============================================================================
    
    # 检查是否有deb包可上传
    local deb_count=$(find "$DEB_DIR" -name "*.deb" -type f 2>/dev/null | wc -l)
    if [[ "$deb_count" -eq 0 ]]; then
        echo "❌ 没有找到可上传的 deb 包"
        echo "💡 请先运行构建功能创建 deb 包"
        return 1
    fi
    
    # 获取所有deb包
    local available_packages=()
    if [[ -d "$DEB_DIR" ]]; then
        for deb_file in "$DEB_DIR"/*.deb; do
            if [[ -f "$deb_file" ]]; then
                local filename=$(basename "$deb_file")
                available_packages+=("$filename")
            fi
        done
    fi
    
    echo "📦 可用的 deb 包："
    echo "================================"
    for i in $(seq 0 $((${#available_packages[@]}-1))); do
        local package="${available_packages[i]}"
        local size=$(du -h "$DEB_DIR/$package" | cut -f1)
        local date=$(stat -c %y "$DEB_DIR/$package" | cut -d' ' -f1)
        echo "$((i+1)). $package ($size, 创建时间: $date)"
    done
    echo "================================"
    
    # 选择deb包
    echo "请输入要上传的deb包序号（用空格分隔多个序号，如：1 2）："
    read -p "deb包序号: " selected_packages
    
    local packages_to_upload=()
    IFS=' ' read -ra PACKAGE_INDICES <<< "$selected_packages"
    for package_index in "${PACKAGE_INDICES[@]}"; do
        if [[ "$package_index" =~ ^[0-9]+$ ]] && [[ "$package_index" -ge 1 ]] && [[ "$package_index" -le ${#available_packages[@]} ]]; then
            local selected_package="${available_packages[package_index-1]}"
            packages_to_upload+=("$selected_package")
            echo "✅ 选择deb包: $selected_package"
        else
            echo "⚠️  忽略无效deb包序号: $package_index"
        fi
    done
    
    if [[ ${#packages_to_upload[@]} -eq 0 ]]; then
        echo "❌ 没有选择有效的deb包"
        return 1
    fi
    
    # =============================================================================
    # 第二步：获取所有服务器信息
    # =============================================================================
    
    # 获取服务器数量
    local server_count=$(get_server_count)
    if [[ "$server_count" -eq 0 ]]; then
        echo "❌ 配置文件中未找到任何服务器配置"
        return 1
    fi
    
    # 获取所有服务器
    local servers_to_upload=()
    for i in $(seq 1 "$server_count"); do
        servers_to_upload+=("$i")
    done
    
    echo "🖥️  将上传到所有 $server_count 台服务器："
    for i in $(seq 1 "$server_count"); do
        local host_var="SERVER_${i}_PUBLIC_IP"
        local user_var="SERVER_${i}_USER"
        local type_var="SERVER_${i}_TYPE"
        
        local host=${!host_var}
        local user=${!user_var}
        local node_type=${!type_var:-unknown}
        
        echo "  $i. $host (用户: $user, 类型: $node_type)"
    done
    
    # =============================================================================
    # 第三步：显示上传计划并确认
    # =============================================================================
    
    echo ""
    echo "📋 上传计划："
    echo "================================"
    echo "📦 要上传的deb包："
    for package in "${packages_to_upload[@]}"; do
        local size=$(du -h "$DEB_DIR/$package" | cut -f1)
        echo "  - $package ($size)"
    done
    
    echo ""
    echo "🖥️  目标服务器："
    for server_index in "${servers_to_upload[@]}"; do
        local host_var="SERVER_${server_index}_PUBLIC_IP"
        local user_var="SERVER_${server_index}_USER"
        local type_var="SERVER_${server_index}_TYPE"
        
        local host=${!host_var}
        local user=${!user_var}
        local node_type=${!type_var:-unknown}
        
        echo "  - $host (用户: $user, 类型: $node_type)"
    done
    
    echo ""
    echo "📊 总计：${#packages_to_upload[@]} 个deb包 × ${#servers_to_upload[@]} 台服务器 = $(( ${#packages_to_upload[@]} * ${#servers_to_upload[@]} )) 次上传"
    echo "================================"
    
    # 确认上传
    echo ""
    read -p "确认开始上传？(y/N): " confirm_upload
    if [[ ! "$confirm_upload" =~ ^[Yy]$ ]]; then
        echo "❌ 用户取消上传"
        return 0
    fi
    
    echo ""
    echo "🚀 开始上传..."
    
    # =============================================================================
    # 第四步：执行上传
    # =============================================================================
    
    # 遍历所有服务器上传
    for i in $(seq 1 "$server_count"); do
        local host_var="SERVER_${i}_PUBLIC_IP"
        local user_var="SERVER_${i}_USER"
        local pass_var="SERVER_${i}_PASS"
        local secret_var="SERVER_${i}_SECRET"
        local dir_var="SERVER_${i}_DIR"
        local port_var="SERVER_${i}_SSH_PORT"
        
        local host=${!host_var}
        local user=${!user_var}
        local pass=${!pass_var-}
        local secret=${!secret_var-}
        local dir=${!dir_var}
        local port=${!port_var:-1022}
        
        echo "🖥️  上传到服务器 $host..."
        
        # SSH 选项
        local SSH_OPTS="-o StrictHostKeyChecking=no"
        local SCP_OPTS="-P $port"
        
        # 规范化远程基础目录与各子目录
        local base_dir="$dir"
        case "$base_dir" in
            */debs|*/images|*/tars|*/charts) base_dir="${base_dir%/*}";;
        esac
        local remote_deb_dir="$base_dir/debs"
        local remote_img_dir="$base_dir/images"
        
        # 创建远程目录树（使用 base64 注入避免引号问题）
        local payload_mkdir
        payload_mkdir="$(printf '%b' "BD=$base_dir\ncase \"\$BD\" in\n  ~*) BD=\"\$HOME\${BD#\~}\" ;;\n  *) : ;;\nesac\nmkdir -p \"\$BD\"/debs \"\$BD\"/images \"\$BD\"/tars \"\$BD\"/charts\n" | base64 -w0)"
        if [[ -n "$secret" && "$secret" != "none" && -f "$secret" ]]; then
            ssh -i "$(get_ssh_key_path "$secret")" $SSH_OPTS -p $port "$user@$host" "bash -lc 'echo $payload_mkdir | base64 -d | bash -e'"
        elif [[ -n "$pass" && "$pass" != "none" ]]; then
            sshpass -p "$pass" ssh $SSH_OPTS -p $port "$user@$host" "bash -lc 'echo $payload_mkdir | base64 -d | bash -e'"
        else
            echo "  ❌ 服务器 $host 未提供有效的密钥或密码，跳过"
            continue
        fi
        
        # 上传用户选择的 deb 包
        if [[ ${#packages_to_upload[@]} -gt 0 ]]; then
            echo "  📦 上传 deb 包..."
            echo "    ⏳ 上传在进行，请耐心等待..."
            
            # 计算总大小用于进度条
            local total_size=0
            for package in "${packages_to_upload[@]}"; do
                local file="$DEB_DIR/$package"
                if [[ -f "$file" ]]; then
                    total_size=$((total_size + $(stat -c%s "$file" 2>/dev/null || echo 0)))
                fi
            done
            
            if [[ -n "$secret" && "$secret" != "none" && -f "$secret" ]]; then
                local key_file=$(get_ssh_key_path "$secret")
                # 尝试使用 pv 显示进度，如果失败则使用普通 scp
                if command -v pv >/dev/null 2>&1 && [[ $total_size -gt 0 ]]; then
                    # 创建临时目录包含选中的文件
                    local temp_dir=$(mktemp -d)
                    for package in "${packages_to_upload[@]}"; do
                        cp "$DEB_DIR/$package" "$temp_dir/"
                    done
                    tar -czf - -C "$temp_dir" . | pv -s $total_size | ssh -i "$key_file" $SSH_OPTS -p $port "$user@$host" "cd $remote_deb_dir && tar -xzf -" 2>/dev/null || {
                        echo "    ⚠️  pv 进度条失败，使用标准上传..."
                        for package in "${packages_to_upload[@]}"; do
                            scp -i "$key_file" $SCP_OPTS "$DEB_DIR/$package" "$user@$host:$remote_deb_dir/"
                        done
                    }
                    rm -rf "$temp_dir"
                else
                    for package in "${packages_to_upload[@]}"; do
                        scp -i "$key_file" $SCP_OPTS "$DEB_DIR/$package" "$user@$host:$remote_deb_dir/"
                    done
                fi
            elif [[ -n "$pass" && "$pass" != "none" ]]; then
                # 尝试使用 pv 显示进度，如果失败则使用普通 scp
                if command -v pv >/dev/null 2>&1 && [[ $total_size -gt 0 ]]; then
                    # 创建临时目录包含选中的文件
                    local temp_dir=$(mktemp -d)
                    for package in "${packages_to_upload[@]}"; do
                        cp "$DEB_DIR/$package" "$temp_dir/"
                    done
                    tar -czf - -C "$temp_dir" . | pv -s $total_size | sshpass -p "$pass" ssh $SSH_OPTS -p $port "$user@$host" "cd $remote_deb_dir && tar -xzf -" 2>/dev/null || {
                        echo "    ⚠️  pv 进度条失败，使用标准上传..."
                        for package in "${packages_to_upload[@]}"; do
                            sshpass -p "$pass" scp $SCP_OPTS "$DEB_DIR/$package" "$user@$host:$remote_deb_dir/"
                        done
                    }
                    rm -rf "$temp_dir"
                else
                    for package in "${packages_to_upload[@]}"; do
                        sshpass -p "$pass" scp $SCP_OPTS "$DEB_DIR/$package" "$user@$host:$remote_deb_dir/"
                    done
                fi
            fi
            
            if [[ $? -eq 0 ]]; then
                echo "    ✅ deb 包上传成功"
            else
                echo "    ❌ deb 包上传失败"
            fi
        fi
        
        # 注意：deb 包上传完成后，不需要上传镜像包
        # 镜像包应该通过专门的镜像上传功能处理
        
        echo "  ✅ 服务器 $host 所有文件上传完成"
    done
    
    echo "🎉 所有服务器上传完成！"
}

# 上传包到指定服务器
upload_packages_to_selected_servers() {
    echo "📤 上传包到指定服务器..."
    
    # =============================================================================
    # 第一步：选择要上传的deb包
    # =============================================================================
    
    # 检查是否有deb包可上传
    local deb_count=$(find "$DEB_DIR" -name "*.deb" -type f 2>/dev/null | wc -l)
    if [[ "$deb_count" -eq 0 ]]; then
        echo "❌ 没有找到可上传的 deb 包"
        echo "💡 请先运行构建功能创建 deb 包"
        return 1
    fi
    
    # 获取所有deb包
    local available_packages=()
    if [[ -d "$DEB_DIR" ]]; then
        for deb_file in "$DEB_DIR"/*.deb; do
            if [[ -f "$deb_file" ]]; then
                local filename=$(basename "$deb_file")
                available_packages+=("$filename")
            fi
        done
    fi
    
    echo "📦 可用的 deb 包："
    echo "================================"
    for i in $(seq 0 $((${#available_packages[@]}-1))); do
        local package="${available_packages[i]}"
        local size=$(du -h "$DEB_DIR/$package" | cut -f1)
        local date=$(stat -c %y "$DEB_DIR/$package" | cut -d' ' -f1)
        echo "$((i+1)). $package ($size, 创建时间: $date)"
    done
    echo "================================"
    
    # 选择deb包
    echo "请输入要上传的deb包序号（用空格分隔多个序号，如：1 2）："
    read -p "deb包序号: " selected_packages
    
    local packages_to_upload=()
    IFS=' ' read -ra PACKAGE_INDICES <<< "$selected_packages"
    for package_index in "${PACKAGE_INDICES[@]}"; do
        if [[ "$package_index" =~ ^[0-9]+$ ]] && [[ "$package_index" -ge 1 ]] && [[ "$package_index" -le ${#available_packages[@]} ]]; then
            local selected_package="${available_packages[package_index-1]}"
            packages_to_upload+=("$selected_package")
            echo "✅ 选择deb包: $selected_package"
        else
            echo "⚠️  忽略无效deb包序号: $package_index"
        fi
    done
    
    if [[ ${#packages_to_upload[@]} -eq 0 ]]; then
        echo "❌ 没有选择有效的deb包"
        return 1
    fi
    
    # =============================================================================
    # 第二步：选择要上传的服务器
    # =============================================================================
    
    # 获取服务器数量
    local server_count=$(get_server_count)
    if [[ "$server_count" -eq 0 ]]; then
        echo "❌ 配置文件中未找到任何服务器配置"
        return 1
    fi
    
    # 显示服务器列表
    echo "🖥️  可用的服务器："
    echo "================================"
    for i in $(seq 1 "$server_count"); do
        local host_var="SERVER_${i}_PUBLIC_IP"
        local user_var="SERVER_${i}_USER"
        local type_var="SERVER_${i}_TYPE"
        
        local host=${!host_var}
        local user=${!user_var}
        local node_type=${!type_var:-unknown}
        
        echo "$i. $host (用户: $user, 类型: $node_type)"
    done
    echo "================================"
    
    # 选择服务器
    echo "请输入要上传的服务器序号（用空格分隔多个序号，如：1 2）："
    read -p "服务器序号: " selected_servers
    
    # 解析服务器序号
    IFS=' ' read -ra SERVER_INDICES <<< "$selected_servers"
    local servers_to_upload=()
    
    for server_index in "${SERVER_INDICES[@]}"; do
        if [[ "$server_index" =~ ^[0-9]+$ ]] && [ "$server_index" -ge 1 ] && [ "$server_index" -le "$server_count" ]; then
            servers_to_upload+=("$server_index")
            local host_var="SERVER_${server_index}_PUBLIC_IP"
            local host=${!host_var}
            echo "✅ 选择服务器: $host"
        else
            echo "⚠️  忽略无效服务器序号: $server_index"
        fi
    done
    
    if [[ ${#servers_to_upload[@]} -eq 0 ]]; then
        echo "❌ 没有选择有效的服务器"
        return 1
    fi
    
    # =============================================================================
    # 第三步：显示上传计划并确认
    # =============================================================================
    
    echo ""
    echo "📋 上传计划："
    echo "================================"
    echo "📦 要上传的deb包："
    for package in "${packages_to_upload[@]}"; do
        local size=$(du -h "$DEB_DIR/$package" | cut -f1)
        echo "  - $package ($size)"
    done
    
    echo ""
    echo "🖥️  目标服务器："
    for server_index in "${servers_to_upload[@]}"; do
        local host_var="SERVER_${server_index}_PUBLIC_IP"
        local user_var="SERVER_${server_index}_USER"
        local type_var="SERVER_${server_index}_TYPE"
        
        local host=${!host_var}
        local user=${!user_var}
        local node_type=${!type_var:-unknown}
        
        echo "  - $host (用户: $user, 类型: $node_type)"
    done
    
    echo ""
    echo "📊 总计：${#packages_to_upload[@]} 个deb包 × ${#servers_to_upload[@]} 台服务器 = $(( ${#packages_to_upload[@]} * ${#servers_to_upload[@]} )) 次上传"
    echo "================================"
    
    # 确认上传
    echo ""
    read -p "确认开始上传？(y/N): " confirm_upload
    if [[ ! "$confirm_upload" =~ ^[Yy]$ ]]; then
        echo "❌ 用户取消上传"
        return 0
    fi
    
    echo ""
    echo "🚀 开始上传..."
    
    # =============================================================================
    # 第四步：执行上传
    # =============================================================================
    
    # 上传到选定的服务器
    for server_index in "${servers_to_upload[@]}"; do
        local host_var="SERVER_${server_index}_PUBLIC_IP"
        local user_var="SERVER_${server_index}_USER"
        local pass_var="SERVER_${server_index}_PASS"
        local secret_var="SERVER_${server_index}_SECRET"
        local dir_var="SERVER_${server_index}_DIR"
        local port_var="SERVER_${server_index}_SSH_PORT"
        
        local host=${!host_var}
        local user=${!user_var}
        local pass=${!pass_var-}
        local secret=${!secret_var-}
        local dir=${!dir_var}
        local port=${!port_var:-1022}
        
        echo "🖥️  上传到服务器 $host..."
        
        # SSH 选项
        local SSH_OPTS="-o StrictHostKeyChecking=no"
        local SCP_OPTS="-P $port"
        
        # 规范化远程基础目录与各子目录
        local base_dir="$dir"
        case "$base_dir" in
            */debs|*/images|*/tars|*/charts) base_dir="${base_dir%/*}";;
        esac
        local remote_deb_dir="$base_dir/debs"
        local remote_img_dir="$base_dir/images"
        
        # 创建远程目录树（使用 base64 注入避免引号问题）
        local payload_mkdir
        payload_mkdir="$(printf '%b' "BD=$base_dir\ncase \"\$BD\" in\n  ~*) BD=\"\$HOME\${BD#\~}\" ;;\n  *) : ;;\nesac\nmkdir -p \"\$BD\"/debs \"\$BD\"/images \"\$BD\"/tars \"\$BD\"/charts\n" | base64 -w0)"
        if [[ -n "$secret" && "$secret" != "none" && -f "$secret" ]]; then
            ssh -i "$(get_ssh_key_path "$secret")" $SSH_OPTS -p $port "$user@$host" "bash -lc 'echo $payload_mkdir | base64 -d | bash -e'"
        elif [[ -n "$pass" && "$pass" != "none" ]]; then
            sshpass -p "$pass" ssh $SSH_OPTS -p $port "$user@$host" "bash -lc 'echo $payload_mkdir | base64 -d | bash -e'"
        else
            echo "  ❌ 服务器 $host 未提供有效的密钥或密码，跳过"
            continue
        fi
        
        # 上传用户选择的 deb 包
        if [[ ${#packages_to_upload[@]} -gt 0 ]]; then
            echo "  📦 上传 deb 包..."
            echo "    ⏳ 上传在进行，请耐心等待..."
            
            # 计算总大小用于进度条
            local total_size=0
            for package in "${packages_to_upload[@]}"; do
                local file="$DEB_DIR/$package"
                if [[ -f "$file" ]]; then
                    total_size=$((total_size + $(stat -c%s "$file" 2>/dev/null || echo 0)))
                fi
            done
            
            if [[ -n "$secret" && "$secret" != "none" && -f "$secret" ]]; then
                local key_file=$(get_ssh_key_path "$secret")
                # 尝试使用 pv 显示进度，如果失败则使用普通 scp
                if command -v pv >/dev/null 2>&1 && [[ $total_size -gt 0 ]]; then
                    # 创建临时目录包含选中的文件
                    local temp_dir=$(mktemp -d)
                    for package in "${packages_to_upload[@]}"; do
                        cp "$DEB_DIR/$package" "$temp_dir/"
                    done
                    tar -czf - -C "$temp_dir" . | pv -s $total_size | ssh -i "$key_file" $SSH_OPTS -p $port "$user@$host" "cd $remote_deb_dir && tar -xzf -" 2>/dev/null || {
                        echo "    ⚠️  pv 进度条失败，使用标准上传..."
                        for package in "${packages_to_upload[@]}"; do
                            scp -i "$key_file" $SCP_OPTS "$DEB_DIR/$package" "$user@$host:$remote_deb_dir/"
                        done
                    }
                    rm -rf "$temp_dir"
                else
                    for package in "${packages_to_upload[@]}"; do
                        scp -i "$key_file" $SCP_OPTS "$DEB_DIR/$package" "$user@$host:$remote_deb_dir/"
                    done
                fi
            elif [[ -n "$pass" && "$pass" != "none" ]]; then
                # 尝试使用 pv 显示进度，如果失败则使用普通 scp
                if command -v pv >/dev/null 2>&1 && [[ $total_size -gt 0 ]]; then
                    # 创建临时目录包含选中的文件
                    local temp_dir=$(mktemp -d)
                    for package in "${packages_to_upload[@]}"; do
                        cp "$DEB_DIR/$package" "$temp_dir/"
                    done
                    tar -czf - -C "$temp_dir" . | pv -s $total_size | sshpass -p "$pass" ssh $SSH_OPTS -p $port "$user@$host" "cd $remote_deb_dir && tar -xzf -" 2>/dev/null || {
                        echo "    ⚠️  pv 进度条失败，使用标准上传..."
                        for package in "${packages_to_upload[@]}"; do
                            sshpass -p "$pass" scp $SCP_OPTS "$DEB_DIR/$package" "$user@$host:$remote_deb_dir/"
                        done
                    }
                    rm -rf "$temp_dir"
                else
                    for package in "${packages_to_upload[@]}"; do
                        sshpass -p "$pass" scp $SCP_OPTS "$DEB_DIR/$package" "$user@$host:$remote_deb_dir/"
                    done
                fi
            fi
            
            if [[ $? -eq 0 ]]; then
                echo "    ✅ deb 包上传成功"
            else
                echo "    ❌ deb 包上传失败"
            fi
        fi
        
        # 注意：deb 包上传完成后，不需要上传镜像包
        # 镜像包应该通过专门的镜像上传功能处理
        
        echo "  ✅ 服务器 $host 所有文件上传完成"
    done
    
    echo "🎉 选定服务器上传完成！"
}

# 上传包到手动输入的服务器
upload_packages_to_manual_servers() {
    echo "📤 上传包到手动输入的服务器..."
    
    # 检查是否有deb包可上传
    local deb_count=$(find "$DEB_DIR" -name "*.deb" -type f 2>/dev/null | wc -l)
    if [[ "$deb_count" -eq 0 ]]; then
        echo "❌ 没有找到可上传的 deb 包"
        echo "💡 请先运行构建功能创建 deb 包"
        return 1
    fi
    
    echo "📊 找到 $deb_count 个 deb 包可上传"
    
    # 显示deb包列表
    echo "📦 deb 包列表："
    find "$DEB_DIR" -name "*.deb" -type f -exec basename {} \;
    
    echo "📝 手动输入服务器信息"
    echo "================================"
    echo "格式：IP:端口:用户名:密码或密钥路径:远程目录"
    echo "示例：192.168.1.100:22:root:mypassword:/opt/packages"
    echo "示例：192.168.1.100:22:root:/path/to/key:/opt/packages"
    echo "================================"
    
    local manual_servers=()
    
    while true; do
        read -p "请输入服务器信息（留空结束）: " server_info
        
        if [[ -z "$server_info" ]]; then
            break
        fi
        
        # 解析服务器信息
        IFS=':' read -ra SERVER_PARTS <<< "$server_info"
        if [ ${#SERVER_PARTS[@]} -eq 5 ]; then
            local host="${SERVER_PARTS[0]}"
            local port="${SERVER_PARTS[1]}"
            local user="${SERVER_PARTS[2]}"
            local auth="${SERVER_PARTS[3]}"
            local dir="${SERVER_PARTS[4]}"
            
            # 验证信息
            if [[ -z "$host" || -z "$user" || -z "$dir" ]]; then
                echo "❌ 服务器信息不完整，请重新输入"
                continue
            fi
            
            # 检查认证方式
            if [[ -f "$auth" ]]; then
                # 密钥文件
                echo "✅ 添加服务器: $host (密钥认证)"
                manual_servers+=("$host:$port:$user:key:$auth:$dir")
            elif [[ -n "$auth" ]]; then
                # 密码
                echo "✅ 添加服务器: $host (密码认证)"
                manual_servers+=("$host:$port:$user:pass:$auth:$dir")
            else
                echo "❌ 无效的认证信息，请重新输入"
                continue
            fi
        else
            echo "❌ 格式错误，请按照格式输入"
            continue
        fi
    done
    
    if [ ${#manual_servers[@]} -eq 0 ]; then
        echo "❌ 没有输入有效的服务器信息"
        return 1
    fi
    
    # 上传到手动输入的服务器
    for server_info in "${manual_servers[@]}"; do
        IFS=':' read -ra PARTS <<< "$server_info"
        local host="${PARTS[0]}"
        local port="${PARTS[1]}"
        local user="${PARTS[2]}"
        local auth_type="${PARTS[3]}"
        local auth_value="${PARTS[4]}"
        local dir="${PARTS[5]}"
        
        echo "🖥️  上传到服务器 $host..."
        
        # SSH 选项
        local SSH_OPTS="-o StrictHostKeyChecking=no"
        local SCP_OPTS="-P $port"
        
        # 规范化远程基础目录与各子目录
        local base_dir="$dir"
        case "$base_dir" in
            */debs|*/images|*/tars|*/charts) base_dir="${base_dir%/*}";;
        esac
        local remote_deb_dir="$base_dir/debs"
        local remote_img_dir="$base_dir/images"
        
        # 创建远程目录树（使用 base64 注入避免引号问题）
        local payload_mkdir
        payload_mkdir="$(printf '%b' "BD=$base_dir\ncase \"\$BD\" in\n  ~*) BD=\"\$HOME\${BD#\~}\" ;;\n  *) : ;;\nesac\nmkdir -p \"\$BD\"/debs \"\$BD\"/images \"\$BD\"/tars \"\$BD\"/charts\n" | base64 -w0)"
        if [[ -n "$secret" && "$secret" != "none" && -f "$secret" ]]; then
            ssh -i "$(get_ssh_key_path "$secret")" $SSH_OPTS -p $port "$user@$host" "bash -lc 'echo $payload_mkdir | base64 -d | bash -e'"
        elif [[ -n "$pass" && "$pass" != "none" ]]; then
            sshpass -p "$pass" ssh $SSH_OPTS -p $port "$user@$host" "bash -lc 'echo $payload_mkdir | base64 -d | bash -e'"
        else
            echo "  ❌ 服务器 $host 未提供有效的密钥或密码，跳过"
            continue
        fi
        
        # 上传用户选择的 deb 包
        if [[ ${#packages_to_upload[@]} -gt 0 ]]; then
            echo "  📦 上传 deb 包到服务器 $host..."
            for package in "${packages_to_upload[@]}"; do
                if [[ "$auth_type" == "key" ]]; then
                    scp -i "$auth_value" $SCP_OPTS "$DEB_DIR/$package" "$user@$host:$remote_deb_dir/"
                elif [[ "$auth_type" == "pass" ]]; then
                    sshpass -p "$auth_value" scp $SCP_OPTS "$DEB_DIR/$package" "$user@$host:$remote_deb_dir/"
                fi
                
                if [[ $? -eq 0 ]]; then
                    echo "    ✅ $package 上传成功"
                else
                    echo "    ❌ $package 上传失败"
                fi
            done
        fi
        
        # 上传用户选择的镜像包
        if [[ ${#packages_to_upload[@]} -gt 0 ]]; then
            echo "  🐳 上传镜像包到服务器 $host..."
            for package in "${packages_to_upload[@]}"; do
                file="$(basename "$package")"
                echo "    📤 上传 $package..."
                if [[ "$auth_type" == "key" ]]; then
                    scp -i "$auth_value" $SCP_OPTS "$IMAGE_DIR/$package" "$user@$host:$remote_img_dir/"
                elif [[ "$auth_type" == "pass" ]]; then
                    sshpass -p "$auth_value" scp $SCP_OPTS "$IMAGE_DIR/$package" "$user@$host:$remote_img_dir/"
                fi
                
                if [[ $? -eq 0 ]]; then
                    echo "      ✅ $package 上传成功"
                else
                    echo "      ❌ $package 上传失败"
            fi
        done
        fi
        
        echo "  ✅ 服务器 $host 所有文件上传完成"
    done
    
    echo "🎉 手动服务器上传完成！"
}

# 构建菜单
show_build_menu() {
    while true; do
        echo ""
        echo "📥 下载菜单："
        echo "1. 下载 deb 包（APT/URL）"
        echo "2. 从本地文件构建 deb（已下载二进制或 tar.gz）"
        echo "0. 返回"
        echo ""
        read -p "请选择 (0-2): " build_choice
        
        case "$build_choice" in
            0)
                echo "👋 返回主菜单"
                break
                ;;
            1)
                echo "📥 下载 deb 包"
                build_deb_packages
                ;;
            2)
                echo "📦 从本地文件打包为 deb"
                build_deb_from_local_file
                ;;
            *)
                echo "❌ 无效选择"
                ;;
        esac
    done
}

# 构建所有包和镜像
build_all_packages_and_images() {
    echo "🔨 构建所有包和镜像..."
    
    # 构建 deb 包
    echo "📦 步骤 1/2: 构建 deb 包"
    build_deb_packages
    
    # 构建 Docker 镜像
    echo "🐳 步骤 2/2: 构建 Docker 镜像"
    build_docker_images
    
    echo "🎉 所有构建完成！"
}

# 如果脚本被直接执行，调用主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

# =============================================================================
# 上传所有文件到服务器的函数
# =============================================================================

# 上传所有文件到所有服务器
upload_all_files_to_all_servers() {
    echo "📤 上传所有文件到所有服务器..."
    
    # 获取服务器数量
    local server_count=$(get_server_count)
    if [[ "$server_count" -eq 0 ]]; then
        echo "❌ 配置文件中未找到任何服务器配置"
        return 1
    fi
    
    echo "📊 检测到 $server_count 台服务器"
    
    # 获取所有文件
    local deb_files=()
    local image_files=()
    
    if [[ -d "$DEB_DIR" ]]; then
        for deb_file in "$DEB_DIR"/*.deb; do
            if [[ -f "$deb_file" ]]; then
                deb_files+=("$(basename "$deb_file")")
            fi
        done
    fi
    
    if [[ -d "$IMAGE_DIR" ]]; then
        for tar_file in "$IMAGE_DIR"/*.tar; do
            if [[ -f "$tar_file" ]]; then
                image_files+=("$(basename "$tar_file")")
            fi
        done
    fi
    
    if [[ ${#deb_files[@]} -eq 0 && ${#image_files[@]} -eq 0 ]]; then
        echo "❌ 没有找到可上传的文件"
        echo "💡 请先运行构建功能创建文件"
        return 1
    fi
    
    # 显示可用的文件
    echo "📦 可用的文件："
    echo "================================"
    
    if [[ ${#deb_files[@]} -gt 0 ]]; then
        echo "📦 deb 包："
        for i in $(seq 0 $((${#deb_files[@]}-1))); do
            local file="${deb_files[i]}"
            local size=$(du -h "$DEB_DIR/$file" | cut -f1)
            local date=$(stat -c %y "$DEB_DIR/$file" | cut -d' ' -f1)
            echo "  $((i+1)). $file ($size, 创建时间: $date)"
        done
    fi
    
    if [[ ${#image_files[@]} -gt 0 ]]; then
        echo ""
        echo "🐳 镜像包："
        for i in $(seq 0 $((${#image_files[@]}-1))); do
            local file="${image_files[i]}"
            local size=$(du -h "$IMAGE_DIR/$file" | cut -f1)
            local date=$(stat -c %y "$IMAGE_DIR/$file" | cut -d' ' -f1)
            echo "  $((i+${#deb_files[@]}+1)). $file ($size, 创建时间: $date)"
        done
    fi
    echo "================================"
    
    # 选择文件
    echo "请输入要上传的文件序号（用空格分隔多个序号，如：1 2 3）："
    read -p "文件序号: " selected_files
    
    local files_to_upload=()
    IFS=' ' read -ra FILE_INDICES <<< "$selected_files"
    for file_index in "${FILE_INDICES[@]}"; do
        if [[ "$package_index" =~ ^[0-9]+$ ]]; then
            if [[ "$package_index" -ge 1 ]] && [[ "$package_index" -le ${#deb_files[@]} ]]; then
                # 选择的是deb包
                local selected_file="${deb_files[file_index-1]}"
                files_to_upload+=("deb:$selected_file")
                echo "✅ 选择deb包: $selected_file"
            elif [[ "$package_index" -gt ${#deb_files[@]} ]] && [[ "$package_index" -le $(( ${#deb_files[@]} + ${#image_files[@]} )) ]]; then
                # 选择的是镜像包
                local image_index=$((file_index - ${#deb_files[@]} - 1))
                local selected_file="${image_files[image_index]}"
                files_to_upload+=("image:$selected_file")
                echo "✅ 选择镜像包: $selected_file"
            else
                echo "⚠️  忽略无效文件序号: $package_index"
            fi
        else
            echo "⚠️  忽略无效文件序号: $package_index"
        fi
    done
    
    if [[ ${#files_to_upload[@]} -eq 0 ]]; then
        echo "❌ 没有选择有效的文件"
        return 1
    fi
    
    # 获取所有服务器
    local servers_to_upload=()
    for i in $(seq 1 "$server_count"); do
        servers_to_upload+=("$i")
    done
    
    echo "🖥️  将上传到所有 $server_count 台服务器："
    for i in $(seq 1 "$server_count"); do
        local host_var="SERVER_${i}_PUBLIC_IP"
        local user_var="SERVER_${i}_USER"
        local type_var="SERVER_${i}_TYPE"
        
        local host=${!host_var}
        local user=${!user_var}
        local node_type=${!type_var:-unknown}
        
        echo "  $i. $host (用户: $user, 类型: $node_type)"
    done
    
    # 显示上传计划并确认
    echo ""
    echo "📋 上传计划："
    echo "================================"
    echo "📦 要上传的文件："
    for file_info in "${files_to_upload[@]}"; do
        local file_type="${file_info%%:*}"
        local file_name="${file_info##*:}"
        if [[ "$file_type" == "deb" ]]; then
            local size=$(du -h "$DEB_DIR/$file_name" | cut -f1)
            echo "  📦 $file_name ($size)"
        else
            local size=$(du -h "$IMAGE_DIR/$file_name" | cut -f1)
            echo "  🐳 $file_name ($size)"
        fi
    done
    
    echo ""
    echo "🖥️  目标服务器："
    for server_index in "${servers_to_upload[@]}"; do
        local host_var="SERVER_${server_index}_PUBLIC_IP"
        local user_var="SERVER_${server_index}_USER"
        local type_var="SERVER_${server_index}_TYPE"
        
        local host=${!host_var}
        local user=${!user_var}
        local node_type=${!type_var:-unknown}
        
        echo "  - $host (用户: $user, 类型: $node_type)"
    done
    
    echo ""
    echo "📊 总计：${#files_to_upload[@]} 个文件 × ${#servers_to_upload[@]} 台服务器 = $(( ${#files_to_upload[@]} * ${#servers_to_upload[@]} )) 次上传"
    echo "================================"
    
    # 确认上传
    echo ""
    read -p "确认开始上传？(y/N): " confirm_upload
    if [[ ! "$confirm_upload" =~ ^[Yy]$ ]]; then
        echo "❌ 用户取消上传"
        return 0
    fi
    
    echo ""
    echo "🚀 开始上传..."
    
    # 遍历所有服务器上传
    for i in $(seq 1 "$server_count"); do
        local host_var="SERVER_${i}_PUBLIC_IP"
        local user_var="SERVER_${i}_USER"
        local pass_var="SERVER_${i}_PASS"
        local secret_var="SERVER_${i}_SECRET"
        local dir_var="SERVER_${i}_DIR"
        local port_var="SERVER_${i}_SSH_PORT"
        
        local host=${!host_var}
        local user=${!user_var}
        local pass=${!pass_var-}
        local secret=${!secret_var-}
        local dir=${!dir_var}
        local port=${!port_var:-1022}
        
        echo "🖥️  上传到服务器 $host..."
        
        # SSH 选项
        local SSH_OPTS="-o StrictHostKeyChecking=no"
        local SCP_OPTS="-P $port"
        
        # 规范化远程基础目录与各子目录
        local base_dir="$dir"
        case "$base_dir" in
            */debs|*/images|*/tars|*/charts) base_dir="${base_dir%/*}";;
        esac
        local remote_deb_dir="$base_dir/debs"
        local remote_img_dir="$base_dir/images"
        
        # 创建远程目录树（使用 base64 注入避免引号问题）
        local payload_mkdir
        payload_mkdir="$(printf '%b' "BD=$base_dir\ncase \"\$BD\" in\n  ~*) BD=\"\$HOME\${BD#\~}\" ;;\n  *) : ;;\nesac\nmkdir -p \"\$BD\"/debs \"\$BD\"/images \"\$BD\"/tars \"\$BD\"/charts\n" | base64 -w0)"
        if [[ -n "$secret" && "$secret" != "none" && -f "$secret" ]]; then
            ssh -i "$(get_ssh_key_path "$secret")" $SSH_OPTS -p $port "$user@$host" "bash -lc 'echo $payload_mkdir | base64 -d | bash -e'"
        elif [[ -n "$pass" && "$pass" != "none" ]]; then
            sshpass -p "$pass" ssh $SSH_OPTS -p $port "$user@$host" "bash -lc 'echo $payload_mkdir | base64 -d | bash -e'"
        else
            echo "  ❌ 服务器 $host 未提供有效的密钥或密码，跳过"
            continue
        fi
        
        # 上传文件
        for file_info in "${files_to_upload[@]}"; do
            local file_type="${file_info%%:*}"
            local file_name="${file_info##*:}"
            
            if [[ "$file_type" == "deb" ]]; then
                echo "  📦 上传 $file_name..."
                if [[ -n "$secret" && "$secret" != "none" && -f "$secret" ]]; then
                    local key_file=$(get_ssh_key_path "$secret")
                    scp -i "$key_file" $SCP_OPTS -o LogLevel=ERROR "$DEB_DIR/$file_name" "$user@$host:$dir/"
                elif [[ -n "$pass" && "$pass" != "none" ]]; then
                    sshpass -p "$pass" scp $SCP_OPTS -o LogLevel=ERROR "$DEB_DIR/$file_name" "$user@$host:$dir/"
                fi
                
                if [[ $? -eq 0 ]]; then
                    echo "    ✅ $file_name 上传成功"
                else
                    echo "    ❌ $file_name 上传失败"
                fi
            else
                echo "  🐳 上传 $file_name..."
                if [[ -n "$secret" && "$secret" != "none" && -f "$secret" ]]; then
                    local key_file=$(get_ssh_key_path "$secret")
                    scp -i "$key_file" $SCP_OPTS -o LogLevel=ERROR "$IMAGE_DIR/$file_name" "$user@$host:$dir/"
                elif [[ -n "$pass" && "$pass" != "none" ]]; then
                    sshpass -p "$pass" scp $SCP_OPTS -o LogLevel=ERROR "$IMAGE_DIR/$file_name" "$user@$host:$dir/"
                fi
                
                if [[ $? -eq 0 ]]; then
                    echo "    ✅ $file_name 上传成功"
                else
                    echo "    ❌ $file_name 上传失败"
                fi
            fi
        done
        
        echo "  ✅ 服务器 $host 所有文件上传完成"
    done
    
    echo "🎉 所有服务器文件上传完成！"
}

# 上传所有文件到指定服务器
upload_all_files_to_selected_servers() {
    echo "📤 上传所有文件到指定服务器..."
    
    # 获取服务器数量
    local server_count=$(get_server_count)
    if [[ "$server_count" -eq 0 ]]; then
        echo "❌ 配置文件中未找到任何服务器配置"
        return 1
    fi
    
    echo "📊 检测到 $server_count 台服务器"
    
    # 显示服务器列表
    echo "🖥️  可用的服务器："
    echo "================================"
    for i in $(seq 1 "$server_count"); do
        local host_var="SERVER_${i}_PUBLIC_IP"
        local user_var="SERVER_${i}_USER"
        local type_var="SERVER_${i}_TYPE"
        
        local host=${!host_var}
        local user=${!user_var}
        local node_type=${!type_var:-unknown}
        
        echo "$i. $host (用户: $user, 类型: $node_type)"
    done
    echo "================================"
    
    # 选择服务器
    echo "请输入要上传的服务器序号（用空格分隔多个序号，如：1 2）："
    read -p "服务器序号: " selected_servers
    
    local servers_to_upload=()
    IFS=' ' read -ra SERVER_INDICES <<< "$selected_servers"
    for server_index in "${SERVER_INDICES[@]}"; do
        if [[ "$server_index" =~ ^[0-9]+$ ]] && [[ "$server_index" -ge 1 ]] && [[ "$server_index" -le "$server_count" ]]; then
            servers_to_upload+=("$server_index")
            local host_var="SERVER_${server_index}_PUBLIC_IP"
            local host=${!host_var}
            echo "✅ 选择服务器: $host"
        else
            echo "⚠️  忽略无效服务器序号: $server_index"
        fi
    done
    
    if [[ ${#servers_to_upload[@]} -eq 0 ]]; then
        echo "❌ 没有选择有效的服务器"
        return 1
    fi
    
    # 获取所有文件
    local deb_files=()
    local image_files=()
    
    if [[ -d "$DEB_DIR" ]]; then
        for deb_file in "$DEB_DIR"/*.deb; do
            if [[ -f "$deb_file" ]]; then
                deb_files+=("$(basename "$deb_file")")
            fi
        done
    fi
    
    if [[ -d "$IMAGE_DIR" ]]; then
        for tar_file in "$IMAGE_DIR"/*.tar; do
            if [[ -f "$tar_file" ]]; then
                image_files+=("$(basename "$tar_file")")
            fi
        done
    fi
    
    if [[ ${#deb_files[@]} -eq 0 && ${#image_files[@]} -eq 0 ]]; then
        echo "❌ 没有找到可上传的文件"
        return 1
    fi
    
    echo "📦 将上传以下文件："
    for file in "${deb_files[@]}"; do
        local size=$(du -h "$DEB_DIR/$file" | cut -f1)
        echo "  📦 $file ($size)"
    done
    for file in "${image_files[@]}"; do
        local size=$(du -h "$IMAGE_DIR/$file" | cut -f1)
        echo "  🐳 $file ($size)"
    done
    
    # 上传到选定的服务器
    for server_index in "${servers_to_upload[@]}"; do
        local host_var="SERVER_${server_index}_PUBLIC_IP"
        local user_var="SERVER_${server_index}_USER"
        local pass_var="SERVER_${server_index}_PASS"
        local secret_var="SERVER_${server_index}_SECRET"
        local dir_var="SERVER_${server_index}_DIR"
        local port_var="SERVER_${server_index}_SSH_PORT"
        
        local host=${!host_var}
        local user=${!user_var}
        local pass=${!pass_var-}
        local secret=${!secret_var-}
        local dir=${!dir_var}
        local port=${!port_var:-1022}
        
        echo "🖥️  上传到服务器 $host..."
        
        # SSH 选项
        local SSH_OPTS="-o StrictHostKeyChecking=no"
        local SCP_OPTS="-P $port"
        
        # 规范化远程基础目录与各子目录
        local base_dir="$dir"
        case "$base_dir" in
            */debs|*/images|*/tars|*/charts) base_dir="${base_dir%/*}";;
        esac
        local remote_deb_dir="$base_dir/debs"
        local remote_img_dir="$base_dir/images"
        
        # 创建远程目录树（使用 base64 注入避免引号问题）
        local payload_mkdir
        payload_mkdir="$(printf '%b' "BD=$base_dir\ncase \"\$BD\" in\n  ~*) BD=\"\$HOME\${BD#\~}\" ;;\n  *) : ;;\nesac\nmkdir -p \"\$BD\"/debs \"\$BD\"/images \"\$BD\"/tars \"\$BD\"/charts\n" | base64 -w0)"
        if [[ -n "$secret" && "$secret" != "none" && -f "$secret" ]]; then
            ssh -i "$(get_ssh_key_path "$secret")" $SSH_OPTS -p $port "$user@$host" "bash -lc 'echo $payload_mkdir | base64 -d | bash -e'"
        elif [[ -n "$pass" && "$pass" != "none" ]]; then
            sshpass -p "$pass" ssh $SSH_OPTS -p $port "$user@$host" "bash -lc 'echo $payload_mkdir | base64 -d | bash -e'"
        else
            echo "  ❌ 服务器 $host 未提供有效的密钥或密码，跳过"
            continue
        fi
        
        # 上传用户选择的 deb 包
        if [[ ${#packages_to_upload[@]} -gt 0 ]]; then
            echo "  📦 上传 deb 包..."
            echo "    ⏳ 上传在进行，请耐心等待..."
            
            # 计算总大小用于进度条
            local total_size=0
            for package in "${packages_to_upload[@]}"; do
                local file="$DEB_DIR/$package"
                if [[ -f "$file" ]]; then
                    total_size=$((total_size + $(stat -c%s "$file" 2>/dev/null || echo 0)))
                fi
            done
            
            if [[ -n "$secret" && "$secret" != "none" && -f "$secret" ]]; then
                local key_file=$(get_ssh_key_path "$secret")
                # 尝试使用 pv 显示进度，如果失败则使用普通 scp
                if command -v pv >/dev/null 2>&1 && [[ $total_size -gt 0 ]]; then
                    # 创建临时目录包含选中的文件
                    local temp_dir=$(mktemp -d)
                    for package in "${packages_to_upload[@]}"; do
                        cp "$DEB_DIR/$package" "$temp_dir/"
                    done
                    tar -czf - -C "$temp_dir" . | pv -s $total_size | ssh -i "$key_file" $SSH_OPTS -p $port "$user@$host" "cd $remote_deb_dir && tar -xzf -" 2>/dev/null || {
                        echo "    ⚠️  pv 进度条失败，使用标准上传..."
                        for package in "${packages_to_upload[@]}"; do
                            scp -i "$key_file" $SCP_OPTS "$DEB_DIR/$package" "$user@$host:$remote_deb_dir/"
                        done
                    }
                    rm -rf "$temp_dir"
                else
                    for package in "${packages_to_upload[@]}"; do
                        scp -i "$key_file" $SCP_OPTS "$DEB_DIR/$package" "$user@$host:$remote_deb_dir/"
                    done
                fi
            elif [[ -n "$pass" && "$pass" != "none" ]]; then
                # 尝试使用 pv 显示进度，如果失败则使用普通 scp
                if command -v pv >/dev/null 2>&1 && [[ $total_size -gt 0 ]]; then
                    # 创建临时目录包含选中的文件
                    local temp_dir=$(mktemp -d)
                    for package in "${packages_to_upload[@]}"; do
                        cp "$DEB_DIR/$package" "$temp_dir/"
                    done
                    tar -czf - -C "$temp_dir" . | pv -s $total_size | sshpass -p "$pass" ssh $SSH_OPTS -p $port "$user@$host" "cd $remote_deb_dir && tar -xzf -" 2>/dev/null || {
                        echo "    ⚠️  pv 进度条失败，使用标准上传..."
                        for package in "${packages_to_upload[@]}"; do
                            sshpass -p "$pass" scp $SCP_OPTS "$DEB_DIR/$package" "$user@$host:$remote_deb_dir/"
                        done
                    }
                    rm -rf "$temp_dir"
                else
                    for package in "${packages_to_upload[@]}"; do
                        sshpass -p "$pass" scp $SCP_OPTS "$DEB_DIR/$package" "$user@$host:$remote_deb_dir/"
                    done
                fi
            fi
            
            if [[ $? -eq 0 ]]; then
                echo "    ✅ deb 包上传成功"
            else
                echo "    ❌ deb 包上传失败"
            fi
        fi
        
        # 注意：deb 包上传完成后，不需要上传镜像包
        # 镜像包应该通过专门的镜像上传功能处理
        
        echo "  ✅ 服务器 $host 所有文件上传完成"
    done
    
    echo "🎉 选定服务器文件上传完成！"
}

# 上传所有文件到手动输入的服务器
upload_all_files_to_manual_servers() {
    echo "📤 上传所有文件到手动输入的服务器..."
    
    # 获取所有文件
    local deb_files=()
    local image_files=()
    
    if [[ -d "$DEB_DIR" ]]; then
        for deb_file in "$DEB_DIR"/*.deb; do
            if [[ -f "$deb_file" ]]; then
                deb_files+=("$(basename "$deb_file")")
            fi
        done
    fi
    
    if [[ -d "$IMAGE_DIR" ]]; then
        for tar_file in "$IMAGE_DIR"/*.tar; do
            if [[ -f "$tar_file" ]]; then
                image_files+=("$(basename "$tar_file")")
            fi
        done
    fi
    
    if [[ ${#deb_files[@]} -eq 0 && ${#image_files[@]} -eq 0 ]]; then
        echo "❌ 没有找到可上传的文件"
        return 1
    fi
    
    echo "📦 将上传以下文件："
    for file in "${deb_files[@]}"; do
        local size=$(du -h "$DEB_DIR/$file" | cut -f1)
        echo "  📦 $file ($size)"
    done
    for file in "${image_files[@]}"; do
        local size=$(du -h "$IMAGE_DIR/$file" | cut -f1)
        echo "  🐳 $file ($size)"
    done
    
    # 手动输入服务器信息
    echo "📝 手动输入服务器信息"
    echo "================================"
    echo "格式：IP:端口:用户名:密码或密钥路径:远程目录"
    echo "示例：192.168.1.100:22:root:mypassword:/opt/files"
    echo "示例：192.168.1.100:22:root:/path/to/key:/opt/files"
    echo "================================"
    
    local manual_servers=()
    while true; do
        read -p "请输入服务器信息（留空结束）: " server_info
        
        if [[ -z "$server_info" ]]; then
            break
        fi
        
        # 解析服务器信息
        IFS=':' read -ra SERVER_PARTS <<< "$server_info"
        if [[ ${#SERVER_PARTS[@]} -eq 5 ]]; then
            local host="${SERVER_PARTS[0]}"
            local port="${SERVER_PARTS[1]}"
            local user="${SERVER_PARTS[2]}"
            local auth="${SERVER_PARTS[3]}"
            local dir="${SERVER_PARTS[4]}"
            
            # 验证信息
            if [[ -z "$host" || -z "$user" || -z "$dir" ]]; then
                echo "❌ 服务器信息不完整，请重新输入"
                continue
            fi
            
            # 检查认证方式
            if [[ -f "$auth" ]]; then
                # 密钥文件
                echo "✅ 添加服务器: $host (密钥认证)"
                manual_servers+=("$host:$port:$user:key:$auth:$dir")
            elif [[ -n "$auth" ]]; then
                # 密码
                echo "✅ 添加服务器: $host (密码认证)"
                manual_servers+=("$host:$port:$user:pass:$auth:$dir")
            else
                echo "❌ 无效的认证信息，请重新输入"
                continue
            fi
        else
            echo "❌ 格式错误，请按照格式输入"
            continue
        fi
    done
    
    if [[ ${#manual_servers[@]} -eq 0 ]]; then
        echo "❌ 没有输入有效的服务器信息"
        return 1
    fi
    
    # 上传到手动输入的服务器
    for server_info in "${manual_servers[@]}"; do
        IFS=':' read -ra SERVER_PARTS <<< "$server_info"
        local host="${SERVER_PARTS[0]}"
        local port="${SERVER_PARTS[1]}"
        local user="${SERVER_PARTS[2]}"
        local auth_type="${SERVER_PARTS[3]}"
        local auth_value="${SERVER_PARTS[4]}"
        local dir="${SERVER_PARTS[5]}"
        
        echo "🖥️  上传所有文件到手动输入服务器 $host..."
        
        # SSH 选项
        local SSH_OPTS="-o StrictHostKeyChecking=no"
        local SCP_OPTS="-P $port"
        
        # 规范化远程基础目录与各子目录
        local base_dir="$dir"
        case "$base_dir" in
            */debs|*/images|*/tars|*/charts) base_dir="${base_dir%/*}";;
        esac
        local remote_deb_dir="$base_dir/debs"
        local remote_img_dir="$base_dir/images"
        
        # 创建远程目录树（使用 base64 注入避免引号问题）
        local payload_mkdir
        payload_mkdir="$(printf '%b' "BD=$base_dir\ncase \"\$BD\" in\n  ~*) BD=\"\$HOME\${BD#\~}\" ;;\n  *) : ;;\nesac\nmkdir -p \"\$BD\"/debs \"\$BD\"/images \"\$BD\"/tars \"\$BD\"/charts\n" | base64 -w0)"
        if [[ -n "$secret" && "$secret" != "none" && -f "$secret" ]]; then
            ssh -i "$(get_ssh_key_path "$secret")" $SSH_OPTS -p $port "$user@$host" "bash -lc 'echo $payload_mkdir | base64 -d | bash -e'"
        elif [[ -n "$pass" && "$pass" != "none" ]]; then
            sshpass -p "$pass" ssh $SSH_OPTS -p $port "$user@$host" "bash -lc 'echo $payload_mkdir | base64 -d | bash -e'"
        else
            echo "  ❌ 服务器 $host 未提供有效的密钥或密码，跳过"
            continue
        fi
        
        # 上传用户选择的 deb 包
        if [[ ${#packages_to_upload[@]} -gt 0 ]]; then
            echo "  📦 上传 deb 包到服务器 $host..."
            for package in "${packages_to_upload[@]}"; do
                if [[ "$auth_type" == "key" ]]; then
                    scp -i "$auth_value" $SCP_OPTS "$DEB_DIR/$package" "$user@$host:$remote_deb_dir/"
                elif [[ "$auth_type" == "pass" ]]; then
                    sshpass -p "$auth_value" scp $SCP_OPTS "$DEB_DIR/$package" "$user@$host:$remote_deb_dir/"
                fi
                
                if [[ $? -eq 0 ]]; then
                    echo "    ✅ $package 上传成功"
                else
                    echo "    ❌ $package 上传失败"
                fi
            done
        fi
        
        # 上传用户选择的镜像包
        if [[ ${#packages_to_upload[@]} -gt 0 ]]; then
            echo "  🐳 上传镜像包到服务器 $host..."
            for package in "${packages_to_upload[@]}"; do
                file="$(basename "$package")"
                echo "    📤 上传 $package..."
                if [[ "$auth_type" == "key" ]]; then
                    scp -i "$auth_value" $SCP_OPTS "$IMAGE_DIR/$package" "$user@$host:$remote_img_dir/"
                elif [[ "$auth_type" == "pass" ]]; then
                    sshpass -p "$auth_value" scp $SCP_OPTS "$IMAGE_DIR/$package" "$user@$host:$remote_img_dir/"
                fi
                
                if [[ $? -eq 0 ]]; then
                    echo "      ✅ $package 上传成功"
                else
                    echo "      ❌ $package 上传失败"
            fi
        done
        fi
        
        echo "  ✅ 服务器 $host 所有文件上传完成"
    done
    
    echo " 手动输入服务器文件上传完成！"
}
