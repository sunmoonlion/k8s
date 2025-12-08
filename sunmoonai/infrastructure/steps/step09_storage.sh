#!/usr/bin/env bash
#
# Step09: Storage Configuration
# 功能：配置 Kubernetes 集群存储（本地存储、NFS存储、云存储）
# 
# ⚠️  CRITICAL SECURITY WARNING ⚠️
# 本脚本包含清理函数，必须遵守以下安全原则：
# 1. 绝不使用 kubectl delete --all 或通配符删除
# 2. 只删除明确指定名称的资源
# 3. 避免删除系统级 ClusterRole/ClusterRoleBinding (如 cluster-admin)
# 4. 使用标签选择器而非批量删除
# 
# 主要特性：
# - 多节点本地存储支持
# - 多节点NFS服务器架构
# - 多云存储CSI驱动支持
# - 完整的在线/离线部署模式
# - 分层开关控制系统
# - 详细的离线资源检查和报告
#
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$BASE_DIR/../utils/common.sh"

load_config_file || exit 1

STEP_PREFIX=STEP09
TARGET="${STEP09_TARGET:-master}"
PACKAGES_DEPLOY_MODE_EFFECTIVE="$(get_packages_deploy_mode)"
REMOTE_KUBECONFIG="${STEP09_REMOTE_KUBECONFIG:-/etc/kubernetes/admin.conf}"
REMOTE_DIR_FALLBACK="${STEP09_REMOTE_DIR_FALLBACK:-~/packages-to-be-installed}"
ONLINE_TIMEOUT="${STEP09_ONLINE_TIMEOUT:-300}"

# 版本配置
LOCAL_PATH_VERSION="${STEP09_LOCAL_STORAGE_VERSION:-v0.0.32}"
NFS_PROVISIONER_VERSION="${STEP09_NFS_PROVISIONER_VERSION:-4.0.2}"

required_artifacts(){
    if [[ "$PACKAGES_DEPLOY_MODE_EFFECTIVE" == "offline" ]]; then
        # 本地存储资源
        if [[ "${STEP09_LOCAL_STORAGE_ENABLED:-false}" == "true" ]]; then
            echo "type=images image='rancher/local-path-provisioner:${LOCAL_PATH_VERSION}'"
            # 注意：local-path-provisioner 通常直接使用YAML部署，不需要Helm Chart
        fi
        
        # NFS存储资源
        if [[ "${STEP09_NFS_STORAGE_ENABLED:-false}" == "true" ]]; then
            # NFS Provisioner Helm Chart
            echo "type=charts pattern='nfs-subdir-external-provisioner-${NFS_PROVISIONER_VERSION}.tgz'"
            echo "type=images image='registry.k8s.io/sig-storage/nfs-subdir-external-provisioner:v${NFS_PROVISIONER_VERSION}'"
            
            # NFS服务器和客户端deb包
            echo "type=debs pattern='nfs-common*.deb'"
            echo "type=debs pattern='nfs-kernel-server*.deb'"
            echo "type=debs pattern='rpcbind*.deb'"
            # NFS依赖包
            echo "type=debs pattern='keyutils*.deb'"
            echo "type=debs pattern='libnfsidmap1*.deb'"
        fi
        
        # 云存储资源
        if [[ "${STEP09_CLOUD_STORAGE_ENABLED:-false}" == "true" ]]; then
            case "${STEP09_CLOUD_PROVIDER:-}" in
                aliyun)
                    echo "type=charts pattern='alicloud-nas-csi-driver-*.tgz'"
                    echo "type=images image='registry.cn-hangzhou.aliyuncs.com/acs/csi-plugin:${STEP09_CLOUD_CSI_VERSION:-v1.16.9-aliyun}'"
                    echo "type=images image='registry.cn-hangzhou.aliyuncs.com/acs/csi-provisioner:${STEP09_CLOUD_CSI_VERSION:-v3.4.0}'"
                    ;;
                tencent)
                    echo "type=charts pattern='cfs-csi-driver-*.tgz'"
                    echo "type=images image='ccr.ccs.tencentyun.com/tkeimages/csi-tencentcloud-cfs:${STEP09_CLOUD_CSI_VERSION:-v1.2.0}'"
                    echo "type=images image='ccr.ccs.tencentyun.com/tkeimages/csi-provisioner:${STEP09_CLOUD_CSI_VERSION:-v3.4.0}'"
                    ;;
                huawei)
                    echo "type=charts pattern='huawei-sfs-csi-driver-*.tgz'"
                    echo "type=images image='swr.cn-north-1.myhuaweicloud.com/hwofficial/csi-driver-sfs:${STEP09_CLOUD_CSI_VERSION:-v2.3.0}'"
                    ;;
                aws)
                    echo "type=charts pattern='aws-efs-csi-driver-*.tgz'"
                    echo "type=images image='amazon/aws-efs-csi-driver:${STEP09_CLOUD_CSI_VERSION:-v1.7.0}'"
                    ;;
                volcengine)
                    echo "type=charts pattern='volcengine-vfs-csi-driver-*.tgz'"
                    echo "type=images image='volcengine/vfs-csi-driver:${STEP09_CLOUD_CSI_VERSION:-v1.2.0}'"
                    ;;
            esac
        fi
    fi
}

if [[ "${1:-}" == "--required-artifacts" ]]; then
    required_artifacts
    exit 0
fi

precheck(){
    log_info "[Step09] 预检存储配置"
    
    # 1. 步骤总开关检查
    if [[ "${STEP09_ENABLED:-false}" != "true" ]]; then
        log_info "[Step09] STEP09_ENABLED=false，跳过"
        exit 0
    fi
    
    # 2. 检查是否有任何存储功能启用
    local has_enabled_storage=false
    [[ "${STEP09_LOCAL_STORAGE_ENABLED:-false}" == "true" ]] && has_enabled_storage=true
    [[ "${STEP09_NFS_STORAGE_ENABLED:-false}" == "true" ]] && has_enabled_storage=true  
    [[ "${STEP09_CLOUD_STORAGE_ENABLED:-false}" == "true" ]] && has_enabled_storage=true
    
    if [[ "$has_enabled_storage" == "false" ]]; then
        log_info "[Step09] 所有存储功能都已禁用，跳过"
        exit 0
    fi
    
    # 3. 配置项验证
    _validate_storage_config
    
    log_info "[Step09] 预检通过"
}

ensure_resources(){
    if [[ "$PACKAGES_DEPLOY_MODE_EFFECTIVE" == "offline" ]]; then
        log_info "[Step09] 离线模式：检查必需资源"
        
        # 首先生成资源需求报告（只做一次）
        local -a all_missing_resources=()
        local -a all_available_resources=()
        local total_required=0
        local total_missing=0
        local check_failed=false
        
        # 直接读取 required_artifacts 输出，避免中间处理造成丢行
        local artifacts_output
        artifacts_output="$(required_artifacts)"
        
        # 找到第一个符合条件的节点（用于检查离线资源所在目录）
        local first_node_idx=""
        local indices; indices="$(get_defined_server_indices)"
        for idx in $indices; do
            if node_should_run "$idx" "$TARGET"; then
                first_node_idx="$idx"
                break
            fi
        done
        if [[ -z "$first_node_idx" ]]; then
            log_error "[Step09] 未找到符合条件的节点"
            return 1
        fi
        
        # 逐项检查需要的资源（使用数组避免标准输入冲突）
        local -a norm_lines=()
        while IFS= read -r _l; do
            [[ -z "$_l" ]] && continue
            norm_lines+=("$_l")
        done < <(_generate_required_resources_list)
        
        
        for resource_line in "${norm_lines[@]}"; do
            IFS='|' read -r type_field resource_field desc_field <<< "$resource_line"
            [[ -z "$type_field" ]] && continue
            local resource_type="${type_field#type=}"
            local desc="${desc_field#desc=}"
            case "$resource_type" in
                images)
                    local image_name="${resource_field#image=}"
                    total_required=$((total_required + 1))
                    if _check_image_exists "$image_name" "$first_node_idx"; then
                        all_available_resources+=("✅ 镜像: $image_name - $desc")
                    else
                        all_missing_resources+=("❌ 镜像: $image_name - $desc")
                        total_missing=$((total_missing + 1))
                        check_failed=true
                    fi
                    ;;
                charts)
                    local chart_pattern="${resource_field#pattern=}"
                    total_required=$((total_required + 1))
                    if _check_chart_exists "$chart_pattern" "$first_node_idx"; then
                        all_available_resources+=("✅ Chart: $chart_pattern - $desc")
                    else
                        all_missing_resources+=("❌ Chart: $chart_pattern - $desc")
                        total_missing=$((total_missing + 1))
                        check_failed=true
                    fi
                    ;;
                debs)
                    local deb_pattern="${resource_field#pattern=}"
                    total_required=$((total_required + 1))
                    if _check_deb_exists "$deb_pattern" "$first_node_idx"; then
                        all_available_resources+=("✅ Deb: $deb_pattern - $desc")
                    else
                        all_missing_resources+=("❌ Deb: $deb_pattern - $desc")
                        total_missing=$((total_missing + 1))
                        check_failed=true
                    fi
                    ;;
                *)
                    ;;
            esac
        done
        
        
        # 生成统一的资源报告
        _generate_resource_report "$total_required" "$total_missing" all_available_resources all_missing_resources
        
        if [[ "$check_failed" == "true" ]]; then
            log_error "[Step09] 离线资源检查失败，请按照上述指南准备缺失资源后重试"
            return 1
        fi
        
        log_info "[Step09] 所有离线资源检查通过"
    fi
}

execute(){
    log_info "[Step09] 在节点 $i 配置存储"
    
    local node_type=$(get_server_var "$i" TYPE)
    
    # K8s层操作（仅在master节点执行）
    if [[ "$node_type" == "master" ]]; then
        # 在所有节点配置宿主机层存储
        log_info "[Step09] 在所有节点配置宿主机层存储"
        for node_idx in $(seq 1 10); do
            if [[ -n "$(get_server_var "$node_idx" PUBLIC_IP)" ]]; then
                log_info "[Step09] 配置节点 $node_idx 的存储"
                _configure_host_storage "$node_idx"
            fi
        done
        
        # 在所有节点安装NFS客户端工具（如果启用了NFS存储）
        if [[ "${STEP09_NFS_STORAGE_ENABLED:-false}" == "true" ]]; then
            log_info "[Step09] 在所有节点安装NFS客户端工具"
            for node_idx in $(seq 1 10); do
                if [[ -n "$(get_server_var "$node_idx" PUBLIC_IP)" ]]; then
                    _install_nfs_client "$node_idx" || {
                        log_error "[Step09] 节点 $node_idx NFS客户端工具安装失败"
                        return 1
                    }
                fi
            done
        fi
        
        # 配置Kubernetes层存储
        _prepare_remote_kubeconfig "$i"
        _configure_kubernetes_storage "$i"
    fi
}

verify(){ 
    log_info "[Step09] 验证存储配置"
    
    # 找到master节点进行验证
    local master_node_idx
    master_node_idx=$(_find_master_node_index)
    
    _prepare_remote_kubeconfig "$master_node_idx"
    _verify_storage_classes "$master_node_idx"
    
    if [[ "${STEP09_VALIDATION_ENABLED:-true}" == "true" ]]; then
        _validate_storage_functionality "$master_node_idx"
    fi
    
    _show_storage_status "$master_node_idx"
    log_info "[Step09] 存储配置完成"
}

# ============================================================================
# 配置验证函数
# ============================================================================

_validate_storage_config(){
    log_info "[Step09] 验证配置参数"
    
    # NFS配置验证
    if [[ "${STEP09_NFS_STORAGE_ENABLED:-false}" == "true" && "${STEP09_NFS_SERVER_ENABLED:-false}" == "true" ]]; then
        local has_nfs_server=false
        # 检查所有可能的NFS服务器配置
        # 直接检查所有可能的SERVER_n配置，不依赖PUBLIC_IP
        for idx in {1..64}; do
            local enabled_var="STEP09_NFS_SERVER_${idx}_ENABLED"
            if [[ "${!enabled_var:-false}" == "true" ]]; then
                local path_var="STEP09_NFS_SERVER_${idx}_PATH"
                if [[ -z "${!path_var:-}" ]]; then
                    log_error "[Step09] NFS服务器 $idx 缺少路径配置: $path_var"
                    return 1
                fi
                has_nfs_server=true
            fi
        done
        
        if [[ "$has_nfs_server" == "false" ]]; then
            log_error "[Step09] NFS存储已启用但没有配置任何NFS服务器节点"
            return 1
        fi
    fi
    
    # 云存储配置验证
    if [[ "${STEP09_CLOUD_STORAGE_ENABLED:-false}" == "true" ]]; then
        if [[ -z "${STEP09_CLOUD_PROVIDER:-}" ]]; then
            log_error "[Step09] 云存储已启用但未指定提供商 (STEP09_CLOUD_PROVIDER)"
            return 1
        fi
    fi
    
    log_info "[Step09] 配置验证通过"
}

# ============================================================================
# 离线资源检查函数
# ============================================================================

_generate_required_resources_list(){
    # 直接调用 required_artifacts 函数，转换格式
    local -a required_resources=()
    
    local artifacts_output
    artifacts_output="$(required_artifacts)"
    
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        if [[ "$line" == "type=images image="* ]]; then
            local image_name="${line#type=images image=\'}"
            image_name="${image_name%\'}"
            required_resources+=("type=images|image=$image_name|desc=镜像文件")
        elif [[ "$line" == "type=charts pattern="* ]]; then
            local pattern="${line#type=charts pattern=\'}"
            pattern="${pattern%\'}"
            required_resources+=("type=charts|pattern=$pattern|desc=Helm Chart文件")
        elif [[ "$line" == "type=debs pattern="* ]]; then
            local pattern="${line#type=debs pattern=\'}"
            pattern="${pattern%\'}"
            required_resources+=("type=debs|pattern=$pattern|desc=Debian包文件")
        fi
    done <<< "$artifacts_output"
    
    printf '%s\n' "${required_resources[@]}"
}


_check_image_exists(){
    local image_name="$1"
    local node_idx="$2"
    
    # 检查远程节点的images目录
    local dir; dir="$(resolve_remote_dir "$(get_server_var "$node_idx" DIR)")"; 
    dir="${dir:-$REMOTE_DIR_FALLBACK}"
    
    # 转换镜像名为文件名格式
    local image_file_pattern
    image_file_pattern="$(echo "$image_name" | sed 's|/|_|g' | sed 's|:|_|g').tar"
    
    # 检查文件是否存在
    if ssh_exec "$node_idx" "bash -lc 'base=\"\$HOME${dir#\~}\"; ls \"\$base/images\"/$image_file_pattern >/dev/null 2>&1'"; then
        return 0
    else
        return 1
    fi
}

_check_chart_exists(){
    local chart_pattern="$1"
    local node_idx="$2"
    
    # 检查远程节点的charts目录
    local dir; dir="$(resolve_remote_dir "$(get_server_var "$node_idx" DIR)")"; 
    dir="${dir:-$REMOTE_DIR_FALLBACK}"
    
    # 检查Chart文件是否存在
    if ssh_exec "$node_idx" "bash -lc 'base=\"\$HOME${dir#\~}\"; ls \"\$base/charts\"/$chart_pattern >/dev/null 2>&1'"; then
        return 0
    else
        return 1
    fi
}

_check_deb_exists(){
    local deb_pattern="$1"
    local node_idx="$2"
    
    # 检查远程节点的debs目录
    local dir; dir="$(resolve_remote_dir "$(get_server_var "$node_idx" DIR)")"; 
    dir="${dir:-$REMOTE_DIR_FALLBACK}"
    
    # 检查文件是否存在
    if ssh_exec "$node_idx" "bash -lc 'base=\"\$HOME${dir#\~}\"; ls \"\$base/debs\"/$deb_pattern >/dev/null 2>&1'"; then
        return 0
    else
        return 1
    fi
}

_generate_resource_report(){
    local total_required="$1"
    local total_missing="$2"
    local available_ref_name="$3"
    local missing_ref_name="$4"
    
    # 使用 declare -n 来创建 nameref，这在新版本 bash 中更可靠
    declare -n available_ref=$available_ref_name
    declare -n missing_ref=$missing_ref_name
    
    echo ""
    log_info "==================== Step09 离线资源检查报告 ===================="
    echo ""
    
    # 总体统计
    log_info "📊 资源统计:"
    log_info "   总计需要: $total_required 个资源"
    log_info "   已准备好: $((total_required - total_missing)) 个资源"
    if [[ $total_missing -gt 0 ]]; then
        log_error "   缺失资源: $total_missing 个资源"
    else
        log_info "   ✅ 所有资源已准备就绪！"
    fi
    echo ""
    
    # 可用资源列表
    local available_count=${#available_ref[@]}
    if [[ $available_count -gt 0 ]]; then
        log_info "✅ 已准备的资源 ($available_count 个):"
        local idx=0
        for resource in "${available_ref[@]}"; do
            echo "   $resource"
            idx=$((idx + 1))
        done
        echo ""
    else
        log_info "📝 没有已准备的资源"
    fi
    
    # 缺失资源列表
    if [[ ${#missing_ref[@]} -gt 0 ]]; then
        log_error "❌ 缺失的资源 (${#missing_ref[@]}个):"
        for resource in "${missing_ref[@]}"; do
            echo "   $resource"
        done
        echo ""
        
        # 提供解决方案
        _show_resource_preparation_guide "$missing_ref_name"
    fi
    
    echo ""
    log_info "================================================================"
    echo ""
}

_show_resource_preparation_guide(){
    local missing_ref_name="$1"
    local -n missing_ref=$missing_ref_name
    
    log_info "📋 资源准备指南:"
    echo ""
    
    # 镜像准备指南
    local has_missing_images=false
    for resource in "${missing_ref[@]}"; do
        if [[ "$resource" == *"镜像:"* ]]; then
            has_missing_images=true
            break
        fi
    done
    
    if [[ "$has_missing_images" == "true" ]]; then
        log_info "🐳 镜像文件准备:"
        log_info "   1. 在有网络的机器上运行以下命令拉取镜像:"
        echo ""
        for resource in "${missing_ref[@]}"; do
            if [[ "$resource" == *"镜像:"* ]]; then
                local image_name
                image_name="$(echo "$resource" | sed 's/.*镜像: \([^ ]*\) -.*/\1/')"
                echo "      docker pull $image_name"
            fi
        done
        echo ""
        log_info "   2. 导出镜像为tar文件:"
        echo ""
        for resource in "${missing_ref[@]}"; do
            if [[ "$resource" == *"镜像:"* ]]; then
                local image_name
                image_name="$(echo "$resource" | sed 's/.*镜像: \([^ ]*\) -.*/\1/')"
                local tar_name
                tar_name="$(echo "$image_name" | sed 's|/|_|g' | sed 's|:|_|g').tar"
                echo "      docker save $image_name -o $tar_name"
            fi
        done
        echo ""
        log_info "   3. 将tar文件上传到所有节点的 ~/packages-to-be-installed/images/ 目录"
        echo ""
    fi
    
    # Chart准备指南
    local has_missing_charts=false
    for resource in "${missing_ref[@]}"; do
        if [[ "$resource" == *"Chart:"* ]]; then
            has_missing_charts=true
            break
        fi
    done
    
    if [[ "$has_missing_charts" == "true" ]]; then
        log_info "📦 Helm Chart准备:"
        log_info "   1. 在有网络的机器上运行以下命令下载Chart:"
        echo ""
        
        # NFS Provisioner Chart
        if grep -q "nfs-subdir-external-provisioner" <<< "${missing_ref[*]}"; then
            echo "      # NFS Provisioner Chart"
            echo "      helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/"
            echo "      helm repo update"
            echo "      helm pull nfs-subdir-external-provisioner/nfs-subdir-external-provisioner --version ${NFS_PROVISIONER_VERSION}"
            echo ""
        fi
        
        # 阿里云CSI Chart
        if grep -q "alicloud-nas-csi-driver" <<< "${missing_ref[*]}"; then
            echo "      # 阿里云NAS CSI Driver Chart"
            echo "      helm repo add aliyun https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts"
            echo "      helm repo update"
            echo "      helm pull aliyun/alicloud-nas-csi-driver"
            echo ""
        fi
        
        # 腾讯云CFS Chart
        if grep -q "cfs-csi-driver" <<< "${missing_ref[*]}"; then
            echo "      # 腾讯云CFS CSI Driver Chart"
            echo "      helm repo add tencentcloud https://mirrors.tencent.com/helm-charts"
            echo "      helm repo update"
            echo "      helm pull tencentcloud/cfs-csi-driver"
            echo ""
        fi
        
        # 华为云SFS Chart
        if grep -q "huawei-sfs-csi-driver" <<< "${missing_ref[*]}"; then
            echo "      # 华为云SFS CSI Driver Chart"
            echo "      helm repo add huawei https://repo.huaweicloud.com/helm-charts"
            echo "      helm repo update"
            echo "      helm pull huawei/sfs-csi-driver"
            echo ""
        fi
        
        # AWS EFS Chart
        if grep -q "aws-efs-csi-driver" <<< "${missing_ref[*]}"; then
            echo "      # AWS EFS CSI Driver Chart"
            echo "      helm repo add aws-efs-csi-driver https://kubernetes-sigs.github.io/aws-efs-csi-driver/"
            echo "      helm repo update"
            echo "      helm pull aws-efs-csi-driver/aws-efs-csi-driver"
            echo ""
        fi
        
        # 火山引擎VFS Chart
        if grep -q "volcengine-vfs-csi-driver" <<< "${missing_ref[*]}"; then
            echo "      # 火山引擎VFS CSI Driver Chart"
            echo "      helm repo add volcengine https://volcengine.github.io/helm-charts"
            echo "      helm repo update"
            echo "      helm pull volcengine/vfs-csi-driver"
            echo ""
        fi
        
        log_info "   2. 将下载的.tgz文件上传到所有节点的 ~/packages-to-be-installed/charts/ 目录"
        echo ""
    fi
}

# ============================================================================
# 辅助函数
# ============================================================================

_find_master_node_index(){
    local indices; indices="$(get_defined_server_indices)"
    for idx in $indices; do
        local node_type=$(get_server_var "$idx" TYPE)
  if [[ "$node_type" == "master" ]]; then
            echo "$idx"
            return 0
        fi
    done
    log_error "[Step09] 未找到master节点"
    return 1
}

_prepare_remote_kubeconfig(){
    local node_idx="$1"
    prepare_remote_kubeconfig "$node_idx" "REMOTE_KUBECONFIG" || {
        log_error "[Step09] 无法在远端节点 $node_idx 准备可读的 kubeconfig"
        return 1
    }
}

# ============================================================================
# 宿主机层操作函数
# ============================================================================

_configure_host_storage(){
    local node_idx="$1"
    
    # 本地存储目录准备
    if [[ "${STEP09_LOCAL_STORAGE_ENABLED:-false}" == "true" ]]; then
        _prepare_local_storage_on_node "$node_idx"
    fi
    
    # NFS服务器配置
    if [[ "${STEP09_NFS_STORAGE_ENABLED:-false}" == "true" ]]; then
        _configure_nfs_server_on_node "$node_idx"
    fi
}

_prepare_local_storage_on_node(){
    local node_idx="$1"
    local enabled_var="STEP09_LOCAL_STORAGE_SERVER_${node_idx}_ENABLED"
    
    if [[ "${!enabled_var:-false}" == "true" ]]; then
        log_info "[Step09] 在节点 $node_idx 准备本地存储"
        local storage_path="${STEP09_LOCAL_STORAGE_PATH:-/data/local-storage}"
        ssh_exec_sudo "$node_idx" "mkdir -p '$storage_path' && chmod 755 '$storage_path'"
        log_info "[Step09] 节点 $node_idx 本地存储目录已创建: $storage_path"
    fi
}

_configure_nfs_server_on_node(){
    local node_idx="$1"
    local enabled_var="STEP09_NFS_SERVER_${node_idx}_ENABLED"
    
    if [[ "${!enabled_var:-false}" == "true" ]]; then
        log_info "[Step09] 在节点 $node_idx 配置NFS服务器"
        local nfs_path_var="STEP09_NFS_SERVER_${node_idx}_PATH"
        local nfs_path="${!nfs_path_var}"
        
        # 安装NFS服务器
        _install_nfs_server_on_node "$node_idx"
        
        # 配置NFS共享
        _setup_nfs_share_on_node "$node_idx" "$nfs_path"
        
        log_info "[Step09] 节点 $node_idx NFS服务器配置完成"
    fi
}

# 在所有节点安装NFS客户端工具
_install_nfs_client(){
    local node_idx="$1"
    
    log_info "[Step09] 在节点 $node_idx 安装NFS客户端工具"
    
    # 检查是否已安装nfs客户端工具
    if ssh_exec "$node_idx" "bash -lc 'command -v mount.nfs >/dev/null 2>&1'"; then
        log_info "[Step09] 节点 $node_idx NFS客户端工具已安装"
        return 0
    fi
    
    # 根据部署模式选择安装方式
    if [[ "$PACKAGES_DEPLOY_MODE_EFFECTIVE" == "offline" ]]; then
        _install_nfs_client_offline "$node_idx"
    else
        _install_nfs_client_online "$node_idx"
    fi
    
    log_info "[Step09] 节点 $node_idx NFS客户端工具安装完成"
}

_install_nfs_client_offline(){
    local node_idx="$1"
    
    log_info "[Step09] 节点 $node_idx 离线安装NFS客户端工具"
    
    # 检查离线包是否存在
    local dir; dir="$(resolve_remote_dir "$(get_server_var "$node_idx" DIR)")"; dir="${dir:-$REMOTE_DIR_FALLBACK}"
    
    # 检查是否有NFS客户端相关的deb包
    if ssh_exec "$node_idx" "bash -lc 'base=\"\$HOME${dir#\~}\"; ls \"\$base/debs\"/nfs-common*.deb >/dev/null 2>&1'"; then
        log_info "[Step09] 节点 $node_idx 使用离线deb包安装NFS客户端"
        # 按依赖顺序安装：先安装依赖包，再安装主包
        ssh_exec_sudo "$node_idx" "bash -lc 'base=\"/home/\$SUDO_USER${dir#\~}\"; \
            # 先安装依赖包
            dpkg -i \"\$base/debs\"/keyutils*.deb \"\$base/debs\"/libnfsidmap1*.deb \"\$base/debs\"/rpcbind*.deb 2>/dev/null || true; \
            # 再安装主包
            dpkg -i \"\$base/debs\"/nfs-common*.deb || apt-get install -f -y'"
    else
        log_error "[Step09] 节点 $node_idx 未找到NFS客户端离线包，离线安装失败"
        return 1
    fi
}

_install_nfs_client_online(){
    local node_idx="$1"
    
    log_info "[Step09] 节点 $node_idx 在线安装NFS客户端工具"
    
    # 检测操作系统并安装NFS客户端
    if ssh_exec "$node_idx" "bash -lc 'command -v apt-get >/dev/null 2>&1'"; then
        # Ubuntu/Debian
        ssh_exec_sudo "$node_idx" "apt-get update && apt-get install -y nfs-common"
    elif ssh_exec "$node_idx" "bash -lc 'command -v yum >/dev/null 2>&1'"; then
        # CentOS/RHEL
        ssh_exec_sudo "$node_idx" "yum install -y nfs-utils"
    else
        log_error "[Step09] 节点 $node_idx 不支持的操作系统"
        return 1
    fi
}

_install_nfs_server_on_node(){
    local node_idx="$1"
    
    log_info "[Step09] 在节点 $node_idx 安装NFS服务器"
    
    # 检查是否已安装
    if ssh_exec "$node_idx" "bash -lc 'systemctl is-active nfs-server >/dev/null 2>&1 || systemctl is-active nfs-kernel-server >/dev/null 2>&1'"; then
        log_info "[Step09] 节点 $node_idx NFS服务器已运行"
        return 0
    fi
    
    # 根据部署模式选择安装方式
    if [[ "$PACKAGES_DEPLOY_MODE_EFFECTIVE" == "offline" ]]; then
        _install_nfs_server_offline "$node_idx"
    else
        _install_nfs_server_online "$node_idx"
    fi
    
    log_info "[Step09] 节点 $node_idx NFS服务器安装完成"
}

_install_nfs_server_offline(){
    local node_idx="$1"
    
    log_info "[Step09] 节点 $node_idx 离线安装NFS服务器"
    
    # 检查离线包是否存在
    local dir; dir="$(resolve_remote_dir "$(get_server_var "$node_idx" DIR)")"; dir="${dir:-$REMOTE_DIR_FALLBACK}"
    # 检查是否有NFS相关的deb包
    if ssh_exec "$node_idx" "bash -lc 'base=\"\$HOME${dir#\~}\"; ls \"\$base/debs\"/nfs-kernel-server*.deb \"\$base/debs\"/rpcbind*.deb \"\$base/debs\"/keyutils*.deb \"\$base/debs\"/libnfsidmap1*.deb >/dev/null 2>&1'"; then
        log_info "[Step09] 节点 $node_idx 使用离线deb包安装NFS服务器"
        # 使用SUDO_USER环境变量获取实际用户主目录，避免sudo下~展开为/root的问题
        ssh_exec_sudo "$node_idx" "bash -lc 'base=\"/home/\$SUDO_USER${dir#\~}\"; dpkg -i \"\$base/debs\"/keyutils*.deb \"\$base/debs\"/libnfsidmap1*.deb \"\$base/debs\"/nfs-common*.deb \"\$base/debs\"/rpcbind*.deb \"\$base/debs\"/nfs-kernel-server*.deb || apt-get install -f -y'"
    else
        log_error "[Step09] 节点 $node_idx 未找到NFS离线包，离线安装失败"
        return 1
    fi
    
    # 启动服务 - 增强错误处理和重试机制
    ssh_exec_sudo "$node_idx" "systemctl enable nfs-kernel-server 2>/dev/null || systemctl enable nfs-server"
    
    # 先启动rpcbind服务（NFS依赖）
    ssh_exec_sudo "$node_idx" "systemctl enable rpcbind"
    if ! ssh_exec_sudo "$node_idx" "systemctl start rpcbind"; then
        log_error "[Step09] 节点 $node_idx rpcbind服务启动失败"
        return 1
    fi
    sleep 3
    
    # 启动NFS服务并验证
    if ! _start_nfs_service_with_verification "$node_idx"; then
        log_error "[Step09] 节点 $node_idx NFS服务启动失败"
        return 1
    fi
}

_install_nfs_server_online(){
    local node_idx="$1"
    
    log_info "[Step09] 节点 $node_idx 在线安装NFS服务器"
    
    # 检测操作系统并安装NFS服务器
    if ssh_exec "$node_idx" "bash -lc 'command -v apt-get >/dev/null 2>&1'"; then
        # Ubuntu/Debian
        ssh_exec_sudo "$node_idx" "apt-get update && apt-get install -y nfs-kernel-server nfs-common rpcbind"
        
        # 先启动rpcbind服务
        ssh_exec_sudo "$node_idx" "systemctl enable rpcbind"
        if ! ssh_exec_sudo "$node_idx" "systemctl start rpcbind"; then
            log_error "[Step09] 节点 $node_idx rpcbind服务启动失败"
            return 1
        fi
        sleep 3
        
        # 启动NFS服务并验证
        ssh_exec_sudo "$node_idx" "systemctl enable nfs-kernel-server"
        if ! _start_nfs_service_with_verification "$node_idx"; then
            log_error "[Step09] 节点 $node_idx NFS服务启动失败"
            return 1
        fi
    elif ssh_exec "$node_idx" "bash -lc 'command -v yum >/dev/null 2>&1'"; then
        # CentOS/RHEL
        ssh_exec_sudo "$node_idx" "yum install -y nfs-utils rpcbind"
        
        # 先启动rpcbind服务
        ssh_exec_sudo "$node_idx" "systemctl enable rpcbind"
        if ! ssh_exec_sudo "$node_idx" "systemctl start rpcbind"; then
            log_error "[Step09] 节点 $node_idx rpcbind服务启动失败"
            return 1
        fi
        sleep 3
        
        # 启动NFS服务并验证
        ssh_exec_sudo "$node_idx" "systemctl enable nfs-server"
        if ! _start_nfs_service_with_verification "$node_idx"; then
            log_error "[Step09] 节点 $node_idx NFS服务启动失败"
            return 1
        fi
    else
        log_error "[Step09] 节点 $node_idx 不支持的操作系统"
        return 1
    fi
}

_setup_nfs_share_on_node(){
    local node_idx="$1"
    local nfs_path="$2"
    
    log_info "[Step09] 在节点 $node_idx 配置NFS共享: $nfs_path"
    
    # 创建NFS共享目录
    ssh_exec_sudo "$node_idx" "mkdir -p '$nfs_path' && chown nobody:nogroup '$nfs_path' 2>/dev/null || chown nobody:nobody '$nfs_path'"
    ssh_exec_sudo "$node_idx" "chmod 755 '$nfs_path'"
    
    # 配置exports
    local exports_line="$nfs_path ${STEP09_NFS_SERVER_EXPORTS:-*(rw,sync,no_subtree_check)}"
    ssh_exec_sudo "$node_idx" "bash -lc 'grep -q \"^$nfs_path\" /etc/exports 2>/dev/null || echo \"$exports_line\" >> /etc/exports'"
    
    # 重新加载exports
    ssh_exec_sudo "$node_idx" "exportfs -ra"
    
    # 重启NFS服务 - 增强错误处理和重试机制
    _restart_nfs_service_with_retry "$node_idx"
    
    log_info "[Step09] 节点 $node_idx NFS共享配置完成"
}

# 增强的NFS服务重启函数，包含重试机制
_restart_nfs_service_with_retry(){
    local node_idx="$1"
    local max_retries=3
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        log_info "[Step09] 节点 $node_idx 重启NFS服务 (尝试 $((retry_count + 1))/$max_retries)"
        
        # 停止NFS服务
        if ! ssh_exec_sudo "$node_idx" "systemctl stop nfs-kernel-server 2>/dev/null || systemctl stop nfs-server 2>/dev/null || true"; then
            log_warn "[Step09] 节点 $node_idx NFS服务停止失败，继续尝试启动"
        fi
        
        # 等待服务完全停止
        sleep 3
        
        # 确保rpcbind服务运行
        if ! ssh_exec_sudo "$node_idx" "systemctl is-active rpcbind >/dev/null 2>&1"; then
            log_info "[Step09] 节点 $node_idx 启动rpcbind服务"
            ssh_exec_sudo "$node_idx" "systemctl start rpcbind"
            sleep 2
        fi
        
        # 启动NFS服务
        if ssh_exec_sudo "$node_idx" "systemctl start nfs-kernel-server 2>/dev/null || systemctl start nfs-server"; then
            # 等待服务启动
            sleep 5
            
            # 检查服务状态
            if ssh_exec_sudo "$node_idx" "systemctl is-active nfs-kernel-server >/dev/null 2>&1 || systemctl is-active nfs-server >/dev/null 2>&1"; then
                # 验证NFS服务是否真正可用
                if _verify_nfs_service_ready "$node_idx"; then
                    log_info "[Step09] 节点 $node_idx NFS服务重启成功"
                    return 0
                else
                    log_warn "[Step09] 节点 $node_idx NFS服务已启动但未就绪，重试中..."
                fi
            else
                log_warn "[Step09] 节点 $node_idx NFS服务启动失败，重试中..."
            fi
        else
            log_warn "[Step09] 节点 $node_idx NFS服务启动命令失败，重试中..."
        fi
        
        retry_count=$((retry_count + 1))
        if [[ $retry_count -lt $max_retries ]]; then
            log_info "[Step09] 节点 $node_idx 等待 10 秒后重试..."
            sleep 10
        fi
    done
    
    # 所有重试都失败了
    log_error "[Step09] 节点 $node_idx NFS服务重启失败，已重试 $max_retries 次"
    ssh_exec_sudo "$node_idx" "systemctl status nfs-kernel-server || systemctl status nfs-server"
    return 1
}

# 启动NFS服务并进行验证
_start_nfs_service_with_verification(){
    local node_idx="$1"
    local max_retries=3
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        log_info "[Step09] 节点 $node_idx 启动NFS服务 (尝试 $((retry_count + 1))/$max_retries)"
        
        # 启动NFS服务
        if ssh_exec_sudo "$node_idx" "systemctl start nfs-kernel-server 2>/dev/null || systemctl start nfs-server"; then
            # 等待服务启动
            sleep 5
            
            # 检查服务状态
            if ssh_exec_sudo "$node_idx" "systemctl is-active nfs-kernel-server >/dev/null 2>&1 || systemctl is-active nfs-server >/dev/null 2>&1"; then
                # 验证NFS服务是否真正可用
                if _verify_nfs_service_ready "$node_idx"; then
                    log_info "[Step09] 节点 $node_idx NFS服务启动成功"
                    return 0
                else
                    log_warn "[Step09] 节点 $node_idx NFS服务已启动但未就绪，重试中..."
                fi
            else
                log_warn "[Step09] 节点 $node_idx NFS服务启动失败，重试中..."
            fi
        else
            log_warn "[Step09] 节点 $node_idx NFS服务启动命令失败，重试中..."
        fi
        
        retry_count=$((retry_count + 1))
        if [[ $retry_count -lt $max_retries ]]; then
            log_info "[Step09] 节点 $node_idx 等待 5 秒后重试..."
            sleep 5
        fi
    done
    
    # 所有重试都失败了
    log_error "[Step09] 节点 $node_idx NFS服务启动失败，已重试 $max_retries 次"
    ssh_exec_sudo "$node_idx" "systemctl status nfs-kernel-server || systemctl status nfs-server"
    return 1
}

# 验证NFS服务是否真正可用
_verify_nfs_service_ready(){
    local node_idx="$1"
    local max_checks=6
    local check_count=0
    
    while [[ $check_count -lt $max_checks ]]; do
        # 检查NFS服务是否在监听端口
        if ssh_exec "$node_idx" "netstat -tlnp 2>/dev/null | grep -E ':(2049|111)' >/dev/null || ss -tlnp 2>/dev/null | grep -E ':(2049|111)' >/dev/null"; then
            # 检查exports是否可用
            if ssh_exec_sudo "$node_idx" "exportfs -v >/dev/null 2>&1"; then
                log_info "[Step09] 节点 $node_idx NFS服务验证通过"
                return 0
            fi
        fi
        
        check_count=$((check_count + 1))
        if [[ $check_count -lt $max_checks ]]; then
            sleep 2
        fi
    done
    
    log_warn "[Step09] 节点 $node_idx NFS服务验证失败"
    return 1
}

# ============================================================================
# K8s层操作函数
# ============================================================================

_configure_kubernetes_storage(){
    local master_node_idx="$1"
    
    # 本地存储Provisioner
    if [[ "${STEP09_LOCAL_STORAGE_ENABLED:-false}" == "true" ]]; then
        _install_local_path_provisioner "$master_node_idx"
        _create_local_storage_class "$master_node_idx"
    fi
    
    # NFS Provisioner
    if [[ "${STEP09_NFS_STORAGE_ENABLED:-false}" == "true" ]]; then
        _install_nfs_provisioners "$master_node_idx"
        _create_nfs_storage_classes "$master_node_idx"
    fi
    
    # 云存储CSI
    if [[ "${STEP09_CLOUD_STORAGE_ENABLED:-false}" == "true" ]]; then
        _install_cloud_csi_driver "$master_node_idx"
        _create_cloud_storage_class "$master_node_idx"
    fi
}

# ⚠️  CRITICAL SAFETY NOTE: 
# This function MUST only delete local-path-provisioner specific resources.
# NEVER use wildcards or --all flags that could delete system-wide RBAC resources.
# Previous bug: kubectl delete clusterrole,clusterrolebinding --all deleted cluster-admin!
_cleanup_failed_local_path_provisioner(){
    local master_node_idx="$1"
    
    log_info "[Step09] 清理失败的local-path-provisioner"
    
    # 只删除local-path-provisioner特定资源，绝不使用 --all 或通配符
    # 这些是local-path-provisioner的标准资源名称，安全删除
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl delete deployment local-path-provisioner -n local-path-storage --ignore-not-found=true 2>/dev/null || true'"
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl delete configmap local-path-config -n local-path-storage --ignore-not-found=true 2>/dev/null || true'"
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl delete serviceaccount local-path-provisioner-service-account -n local-path-storage --ignore-not-found=true 2>/dev/null || true'"
    
    # ClusterRole和ClusterRoleBinding - 只删除local-path-provisioner特定的，不影响系统RBAC
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl delete clusterrole local-path-provisioner-role --ignore-not-found=true 2>/dev/null || true'"
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl delete clusterrolebinding local-path-provisioner-bind --ignore-not-found=true 2>/dev/null || true'"
    
    # Namespace内的Role和RoleBinding
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl delete role local-path-provisioner-role -n local-path-storage --ignore-not-found=true 2>/dev/null || true'"
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl delete rolebinding local-path-provisioner-bind -n local-path-storage --ignore-not-found=true 2>/dev/null || true'"
    
    # 删除namespace（如果为空）
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl delete namespace local-path-storage --ignore-not-found=true 2>/dev/null || true'"
    
    # 等待资源清理完成
    sleep 3
    
    log_info "[Step09] local-path-provisioner 清理完成"
}

_install_local_path_provisioner(){
    local master_node_idx="$1"
    
    # 检查是否已安装并运行正常
    if ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl get namespace local-path-storage >/dev/null 2>&1'"; then
        if ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl get deployment local-path-provisioner -n local-path-storage >/dev/null 2>&1'"; then
            local ready_replicas
            ready_replicas=$(ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl get deployment local-path-provisioner -n local-path-storage -o jsonpath=\"{.status.readyReplicas}\" 2>/dev/null || echo \"0\"'")
            if [[ "${ready_replicas:-0}" -gt 0 ]]; then
                log_info "[Step09] local-path-provisioner 已安装并运行正常"
                return 0
            else
                log_info "[Step09] local-path-provisioner 存在但未就绪，重新安装"
                _cleanup_failed_local_path_provisioner "$master_node_idx"
            fi
        else
            log_info "[Step09] local-path-storage namespace存在但deployment缺失，清理后重新安装"
            _cleanup_failed_local_path_provisioner "$master_node_idx"
        fi
    fi
    
    log_info "[Step09] 安装 local-path-provisioner"
    
    if [[ "$PACKAGES_DEPLOY_MODE_EFFECTIVE" == "offline" ]]; then
        _install_local_path_offline "$master_node_idx"
    else
        _install_local_path_online "$master_node_idx"
    fi
}

_install_local_path_online(){
    local master_node_idx="$1"
    
    log_info "[Step09] 在线安装 local-path-provisioner"
    
    # 检查网络连接
    if ! ssh_exec "$master_node_idx" "timeout 10 curl -s https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml >/dev/null"; then
        log_error "[Step09] 无法访问 GitHub"
        return 1
    fi
    
    # 安装
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml'"
    
    # 等待启动
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl wait --for=condition=ready pod -l app=local-path-provisioner -n local-path-storage --timeout=${ONLINE_TIMEOUT}s'"
    
    log_info "[Step09] local-path-provisioner 在线安装完成"
}

_install_local_path_offline(){
    local master_node_idx="$1"
    
    log_info "[Step09] 离线安装 local-path-provisioner"
    
    # 检查镜像是否已加载
    local image_name="rancher/local-path-provisioner:${LOCAL_PATH_VERSION}"
    local image_loaded=false
    
    # 尝试不同的容器运行时检查镜像
    if ssh_exec "$master_node_idx" "bash -lc 'nerdctl -n k8s.io images 2>/dev/null | grep -q local-path-provisioner'"; then
        image_loaded=true
    elif ssh_exec "$master_node_idx" "bash -lc 'sudo nerdctl -n k8s.io images 2>/dev/null | grep -q local-path-provisioner'"; then
        image_loaded=true
    elif ssh_exec "$master_node_idx" "bash -lc 'docker images 2>/dev/null | grep -q local-path-provisioner'"; then
        image_loaded=true
    fi
    
    if [[ "$image_loaded" == "false" ]]; then
        # 加载镜像
        local dir; dir="$(resolve_remote_dir "$(get_server_var "$master_node_idx" DIR)")"; 
        dir="${dir:-$REMOTE_DIR_FALLBACK}"
        local image_tar="$(echo "$image_name" | sed 's|/|_|g' | sed 's|:|_|g').tar"
        
        log_info "[Step09] 加载镜像: $image_name"
        
        # 尝试不同的加载方式
        if ssh_exec "$master_node_idx" "bash -lc 'base=\"\$HOME${dir#\~}\"; sudo nerdctl -n k8s.io load -i \"\$base/images/$image_tar\"' 2>/dev/null"; then
            log_info "[Step09] 使用 nerdctl 加载镜像成功"
        elif ssh_exec "$master_node_idx" "bash -lc 'base=\"\$HOME${dir#\~}\"; docker load -i \"\$base/images/$image_tar\"' 2>/dev/null"; then
            log_info "[Step09] 使用 docker 加载镜像成功"
        else
            log_error "[Step09] 镜像加载失败，请检查容器运行时配置"
            return 1
        fi
    fi
    
    # 下载并修改YAML（如果可以访问网络）
    if ssh_exec "$master_node_idx" "timeout 10 curl -s https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml >/dev/null"; then
        ssh_exec "$master_node_idx" "bash -lc 'curl -s https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml > /tmp/local-path-storage.yaml'"
        ssh_exec "$master_node_idx" "sed -i \"s|rancher/local-path-provisioner:.*|$image_name|g\" /tmp/local-path-storage.yaml"
        ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl apply -f /tmp/local-path-storage.yaml'"
        ssh_exec "$master_node_idx" "rm -f /tmp/local-path-storage.yaml"
    else
        log_error "[Step09] 离线安装需要预先准备 local-path-storage.yaml 文件"
        return 1
    fi
    
    log_info "[Step09] local-path-provisioner 离线安装完成"
}

_create_local_storage_class(){
    local master_node_idx="$1"
    
    log_info "[Step09] 创建本地存储StorageClass"
    
    # 删除旧的StorageClass
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl delete storageclass \"${STEP09_LOCAL_STORAGE_CLASS_NAME}\" --ignore-not-found'"
    
    # 创建新的StorageClass
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl apply -f -'" <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ${STEP09_LOCAL_STORAGE_CLASS_NAME}
  annotations:
    storageclass.kubernetes.io/is-default-class: "${STEP09_LOCAL_STORAGE_DEFAULT_CLASS}"
provisioner: rancher.io/local-path
volumeBindingMode: ${STEP09_LOCAL_STORAGE_VOLUME_BINDING_MODE}
reclaimPolicy: ${STEP09_LOCAL_STORAGE_RECLAIM_POLICY}
EOF
    
    # 如果设置为默认存储类，移除其他默认存储类
    if [[ "${STEP09_LOCAL_STORAGE_DEFAULT_CLASS}" == "true" ]]; then
        log_info "[Step09] 设置为默认StorageClass，移除其他默认存储类"
        ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl get sc -o json | jq -r \".items[].metadata.name\" | while read sc; do if [[ \"\$sc\" != \"${STEP09_LOCAL_STORAGE_CLASS_NAME}\" ]]; then kubectl patch sc \"\$sc\" -p \"{\\\"metadata\\\":{\\\"annotations\\\":{\\\"storageclass.kubernetes.io/is-default-class\\\":\\\"false\\\"}}}\" 2>/dev/null || true; fi; done'"
    fi
    
    log_info "[Step09] 本地存储StorageClass创建完成"
}

_install_nfs_provisioners(){
    local master_node_idx="$1"
    
    log_info "[Step09] 安装NFS Provisioner"
    
    # 注意：NFS客户端工具已在execute函数中安装，此处跳过重复安装
    
    # 获取启用的NFS服务器节点
    local -a nfs_servers=()
    local indices; indices="$(get_defined_server_indices)"
    
    for idx in $indices; do
        local enabled_var="STEP09_NFS_SERVER_${idx}_ENABLED"
        if [[ "${!enabled_var:-false}" == "true" ]]; then
            nfs_servers+=("$idx")
        fi
    done
    
    if [[ ${#nfs_servers[@]} -eq 0 ]]; then
        log_warn "[Step09] 没有启用的NFS服务器节点"
        return 0
    fi
    
    # 为每个NFS服务器安装Provisioner
    for server_idx in "${nfs_servers[@]}"; do
        _install_single_nfs_provisioner "$master_node_idx" "$server_idx"
    done
}

# ✅ SAFE: This function uses specific Helm release names and label selectors
# No wildcards or --all flags that could affect system resources
_cleanup_failed_nfs_provisioner(){
    local master_node_idx="$1"
    local provisioner_name="$2"
    
    log_info "[Step09] 清理失败的NFS Provisioner: $provisioner_name"
    
    # 删除指定的Helm release（安全：只删除特定名称的release）
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" helm uninstall \"$provisioner_name\" -n \"${STEP09_HELM_NAMESPACE}\" 2>/dev/null || true'"
    
    # 使用标签选择器清理相关Kubernetes资源（安全：只删除特定标签的资源）
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl delete deployment,replicaset,pod -l app.kubernetes.io/name=nfs-subdir-external-provisioner,app.kubernetes.io/instance=\"$provisioner_name\" -n \"${STEP09_HELM_NAMESPACE}\" --ignore-not-found=true 2>/dev/null || true'"
    
    # 等待资源清理完成
    sleep 3
    
    log_info "[Step09] NFS Provisioner $provisioner_name 清理完成"
}

_install_single_nfs_provisioner(){
    local master_node_idx="$1"
    local nfs_server_idx="$2"
    
    local provisioner_name="nfs-provisioner-${nfs_server_idx}"
    
    # 检查Helm release状态并处理冲突
    local helm_status
    helm_status=$(ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" helm status \"$provisioner_name\" -n \"${STEP09_HELM_NAMESPACE}\" >/dev/null 2>&1 && echo \"exists\" || echo \"notfound\"'")
    
    if [[ "$helm_status" == "exists" ]]; then
        # 检查deployment是否正常运行
        if ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl get deployment \"$provisioner_name\" -n \"${STEP09_HELM_NAMESPACE}\" >/dev/null 2>&1'"; then
            local ready_replicas
            ready_replicas=$(ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl get deployment \"$provisioner_name\" -n \"${STEP09_HELM_NAMESPACE}\" -o jsonpath=\"{.status.readyReplicas}\" 2>/dev/null || echo \"0\"'")
            if [[ "${ready_replicas:-0}" -gt 0 ]]; then
                log_info "[Step09] NFS Provisioner $provisioner_name 已安装并运行正常"
                return 0
            else
                log_info "[Step09] NFS Provisioner $provisioner_name 存在但未就绪，重新安装"
                _cleanup_failed_nfs_provisioner "$master_node_idx" "$provisioner_name"
            fi
        else
            log_info "[Step09] Helm release $provisioner_name 存在但deployment缺失，清理后重新安装"
            _cleanup_failed_nfs_provisioner "$master_node_idx" "$provisioner_name"
        fi
    fi
    
    # 获取NFS服务器IP
    local nfs_server_ip
    nfs_server_ip="$(get_server_var "$nfs_server_idx" LOCAL_IP)"
    [[ -z "$nfs_server_ip" ]] && nfs_server_ip="$(get_server_var "$nfs_server_idx" PUBLIC_IP)"
    
    if [[ -z "$nfs_server_ip" ]]; then
        log_error "[Step09] 无法获取NFS服务器 $nfs_server_idx 的IP地址"
        return 1
    fi
    
    local nfs_path_var="STEP09_NFS_SERVER_${nfs_server_idx}_PATH"
    local nfs_path="${!nfs_path_var}"
    
    log_info "[Step09] 安装NFS Provisioner: $provisioner_name (${nfs_server_ip}:${nfs_path})"
    
    if [[ "$PACKAGES_DEPLOY_MODE_EFFECTIVE" == "offline" ]]; then
        _install_nfs_provisioner_offline "$master_node_idx" "$provisioner_name" "$nfs_server_ip" "$nfs_path"
    else
        _install_nfs_provisioner_online "$master_node_idx" "$provisioner_name" "$nfs_server_ip" "$nfs_path"
    fi
}

_install_nfs_provisioner_online(){
    local master_node_idx="$1"
    local provisioner_name="$2"
    local nfs_server_ip="$3"
    local nfs_path="$4"
    
    # 检查Helm是否安装
    if ! ssh_exec "$master_node_idx" "bash -lc 'command -v helm >/dev/null 2>&1'"; then
        log_error "[Step09] Helm未安装，请先安装Helm"
        return 1
    fi
    
    # 添加Helm仓库
    ssh_exec "$master_node_idx" "bash -lc 'helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/ 2>/dev/null || true'"
    ssh_exec "$master_node_idx" "bash -lc 'helm repo update'"
    
    # 安装
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" helm install \"$provisioner_name\" nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
        --namespace \"${STEP09_HELM_NAMESPACE}\" \
        --set image.repository=\"registry.k8s.io/sig-storage/nfs-subdir-external-provisioner\" \
        --set image.tag=\"v$NFS_PROVISIONER_VERSION\" \
        --set nfs.server=\"$nfs_server_ip\" \
        --set nfs.path=\"$nfs_path\" \
        --set storageClass.create=false \
        --set nfs.mountOptions[0]=\"rw\" \
        --set nfs.mountOptions[1]=\"sync\" \
        --set nfs.mountOptions[2]=\"hard\" \
        --set nfs.mountOptions[3]=\"intr\" \
        --set nfs.reclaimPolicy=\"${STEP09_NFS_STORAGE_RECLAIM_POLICY:-Delete}\" \
        --version \"$NFS_PROVISIONER_VERSION\"'"
    
    log_info "[Step09] NFS Provisioner $provisioner_name 在线安装完成"
}

_install_nfs_provisioner_offline(){
    local master_node_idx="$1"
    local provisioner_name="$2"
    local nfs_server_ip="$3"
    local nfs_path="$4"
    
    # 检查Chart文件
    local dir; dir="$(resolve_remote_dir "$(get_server_var "$master_node_idx" DIR)")"; 
    dir="${dir:-$REMOTE_DIR_FALLBACK}"
    
    local chart_file
    chart_file=$(ssh_exec "$master_node_idx" "bash -lc 'base=\"\$HOME${dir#\~}\"; ls \"\$base/charts\"/nfs-subdir-external-provisioner-*.tgz 2>/dev/null | head -1'")
    
    if [[ -z "$chart_file" ]]; then
        log_error "[Step09] 未找到NFS Provisioner Chart文件"
        return 1
    fi
    
    # 安装
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" helm install \"$provisioner_name\" \"$chart_file\" \
        --namespace \"${STEP09_HELM_NAMESPACE}\" \
        --set image.repository=\"registry.k8s.io/sig-storage/nfs-subdir-external-provisioner\" \
        --set image.tag=\"v$NFS_PROVISIONER_VERSION\" \
        --set nfs.server=\"$nfs_server_ip\" \
        --set nfs.path=\"$nfs_path\" \
        --set storageClass.create=false \
        --set nfs.mountOptions[0]=\"rw\" \
        --set nfs.mountOptions[1]=\"sync\" \
        --set nfs.mountOptions[2]=\"hard\" \
        --set nfs.mountOptions[3]=\"intr\" \
        --set nfs.reclaimPolicy=\"${STEP09_NFS_STORAGE_RECLAIM_POLICY:-Delete}\"'"
    
    log_info "[Step09] NFS Provisioner $provisioner_name 离线安装完成"
}

_create_nfs_storage_classes(){
    local master_node_idx="$1"
    
    log_info "[Step09] 创建NFS存储StorageClass"
    
    # 根据配置决定创建方式
    if [[ "${STEP09_NFS_CREATE_SEPARATE_STORAGE_CLASSES:-false}" == "true" ]]; then
        _create_separate_nfs_storage_classes "$master_node_idx"
    else
        _create_unified_nfs_storage_class "$master_node_idx"
    fi
}

_create_unified_nfs_storage_class(){
    local master_node_idx="$1"
    
    # 获取第一个启用的NFS服务器作为默认
    local default_nfs_server=""
    local indices; indices="$(get_defined_server_indices)"
    for idx in $indices; do
        local enabled_var="STEP09_NFS_SERVER_${idx}_ENABLED"
        if [[ "${!enabled_var:-false}" == "true" ]]; then
            default_nfs_server="$idx"
            break
        fi
    done
    
    if [[ -z "$default_nfs_server" ]]; then
        log_warn "[Step09] 没有启用的NFS服务器，跳过StorageClass创建"
        return 0
    fi
    
    local provisioner_name="nfs-provisioner-${default_nfs_server}"
    
    # 删除旧的StorageClass
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl delete storageclass \"${STEP09_NFS_STORAGE_CLASS_NAME}\" --ignore-not-found'"
    
    # 创建统一的NFS StorageClass
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl apply -f -'" <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ${STEP09_NFS_STORAGE_CLASS_NAME}
  annotations:
    storageclass.kubernetes.io/is-default-class: "${STEP09_NFS_STORAGE_DEFAULT_CLASS}"
provisioner: cluster.local/${provisioner_name}-nfs-subdir-external-provisioner
volumeBindingMode: ${STEP09_NFS_STORAGE_VOLUME_BINDING_MODE}
reclaimPolicy: ${STEP09_NFS_STORAGE_RECLAIM_POLICY}
EOF
    
    log_info "[Step09] 统一NFS存储StorageClass创建完成"
}

_create_separate_nfs_storage_classes(){
    local master_node_idx="$1"
    
    # 为每个NFS服务器创建独立的StorageClass（支持Harbor专用存储）
    local indices; indices="$(get_defined_server_indices)"
    for idx in $indices; do
        local enabled_var="STEP09_NFS_SERVER_${idx}_ENABLED"
        if [[ "${!enabled_var:-false}" == "true" ]]; then
            local sc_name="${STEP09_NFS_STORAGE_CLASS_PREFIX:-nfs}-${idx}"
            local provisioner_name="nfs-provisioner-${idx}"
            
            ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl apply -f -'" <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ${sc_name}
provisioner: cluster.local/${provisioner_name}-nfs-subdir-external-provisioner
volumeBindingMode: ${STEP09_NFS_STORAGE_VOLUME_BINDING_MODE}
reclaimPolicy: ${STEP09_NFS_STORAGE_RECLAIM_POLICY}
EOF
            
            log_info "[Step09] NFS存储StorageClass创建完成: $sc_name"
        fi
    done
}

_install_cloud_csi_driver(){
    local master_node_idx="$1"
    
    log_info "[Step09] 安装云存储CSI驱动: ${STEP09_CLOUD_PROVIDER}"
    
    case "${STEP09_CLOUD_PROVIDER}" in
        aliyun)
            _install_aliyun_nas_csi "$master_node_idx"
            ;;
        tencent)
            _install_tencent_cfs_csi "$master_node_idx"
            ;;
        volcengine)
            _install_volcengine_vfs_csi "$master_node_idx"
            ;;
        *)
            log_error "[Step09] 不支持的云存储提供商: ${STEP09_CLOUD_PROVIDER}"
            return 1
            ;;
    esac
}

_install_aliyun_nas_csi(){
    local master_node_idx="$1"
    
    # 检查是否已安装
    if ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl get deployment alicloud-nas-controller -n kube-system >/dev/null 2>&1'"; then
        log_info "[Step09] 阿里云NAS CSI驱动已安装"
        return 0
    fi
    
    log_info "[Step09] 安装阿里云NAS CSI驱动"
    
    if [[ "$PACKAGES_DEPLOY_MODE_EFFECTIVE" == "offline" ]]; then
        # 离线安装
        local dir; dir="$(resolve_remote_dir "$(get_server_var "$master_node_idx" DIR)")"; 
        dir="${dir:-$REMOTE_DIR_FALLBACK}"
        
        local chart_file
        chart_file=$(ssh_exec "$master_node_idx" "bash -lc 'base=\"\$HOME${dir#\~}\"; ls \"\$base/charts\"/alicloud-nas-csi-driver-*.tgz 2>/dev/null | head -1'")
        
        if [[ -z "$chart_file" ]]; then
            log_error "[Step09] 未找到阿里云NAS CSI Driver Chart文件"
            return 1
        fi
        
        ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" helm install alicloud-nas \"$chart_file\" --namespace kube-system'"
    else
        # 在线安装
        ssh_exec "$master_node_idx" "bash -lc 'helm repo add aliyun https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts 2>/dev/null || true'"
        ssh_exec "$master_node_idx" "bash -lc 'helm repo update'"
        ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" helm install alicloud-nas aliyun/alicloud-nas-csi-driver --namespace kube-system'"
    fi
    
    log_info "[Step09] 阿里云NAS CSI驱动安装完成"
}

_install_tencent_cfs_csi(){
    local master_node_idx="$1"
    
    log_info "[Step09] 腾讯云CFS CSI驱动安装（待实现）"
}

_install_volcengine_vfs_csi(){
    local master_node_idx="$1"
    
    # 检查是否已安装
    if ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl get deployment volcengine-vfs-controller -n kube-system >/dev/null 2>&1'"; then
        log_info "[Step09] 火山引擎VFS CSI驱动已安装"
        return 0
    fi
    
    log_info "[Step09] 安装火山引擎VFS CSI驱动"
    
    if [[ "$PACKAGES_DEPLOY_MODE_EFFECTIVE" == "offline" ]]; then
        # 离线安装
        local dir; dir="$(resolve_remote_dir "$(get_server_var "$master_node_idx" DIR)")"; 
        dir="${dir:-$REMOTE_DIR_FALLBACK}"
        
        local chart_file
        chart_file=$(ssh_exec "$master_node_idx" "bash -lc 'base=\"\$HOME${dir#\~}\"; ls \"\$base/charts\"/volcengine-vfs-csi-driver-*.tgz 2>/dev/null | head -1'")
        
        if [[ -z "$chart_file" ]]; then
            log_error "[Step09] 未找到火山引擎VFS CSI Driver Chart文件"
            return 1
        fi
        
        # 检查必要的镜像是否已加载
        local csi_image="volcengine/vfs-csi-driver:${STEP09_CLOUD_CSI_VERSION:-v1.2.0}"
        local provisioner_image="registry.k8s.io/sig-storage/csi-provisioner:${STEP09_CLOUD_CSI_VERSION:-v3.4.0}"
        
        # 加载CSI驱动镜像
        local csi_image_tar="$(echo "$csi_image" | sed 's|/|_|g' | sed 's|:|_|g').tar"
        if ssh_exec "$master_node_idx" "bash -lc 'base=\"\$HOME${dir#\~}\"; sudo nerdctl -n k8s.io load -i \"\$base/images/$csi_image_tar\"' 2>/dev/null"; then
            log_info "[Step09] 火山引擎VFS CSI驱动镜像加载成功"
        elif ssh_exec "$master_node_idx" "bash -lc 'base=\"\$HOME${dir#\~}\"; docker load -i \"\$base/images/$csi_image_tar\"' 2>/dev/null"; then
            log_info "[Step09] 火山引擎VFS CSI驱动镜像加载成功"
        else
            log_warn "[Step09] 火山引擎VFS CSI驱动镜像加载失败，尝试在线拉取"
        fi
        
        # 加载CSI Provisioner镜像
        local provisioner_image_tar="$(echo "$provisioner_image" | sed 's|/|_|g' | sed 's|:|_|g').tar"
        if ssh_exec "$master_node_idx" "bash -lc 'base=\"\$HOME${dir#\~}\"; sudo nerdctl -n k8s.io load -i \"\$base/images/$provisioner_image_tar\"' 2>/dev/null"; then
            log_info "[Step09] CSI Provisioner镜像加载成功"
        elif ssh_exec "$master_node_idx" "bash -lc 'base=\"\$HOME${dir#\~}\"; docker load -i \"\$base/images/$provisioner_image_tar\"' 2>/dev/null"; then
            log_info "[Step09] CSI Provisioner镜像加载成功"
        else
            log_warn "[Step09] CSI Provisioner镜像加载失败，尝试在线拉取"
        fi
        
        # 安装Chart
        ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" helm install volcengine-vfs \"$chart_file\" --namespace kube-system \
            --set driver.image.repository=\"volcengine/vfs-csi-driver\" \
            --set driver.image.tag=\"${STEP09_CLOUD_CSI_VERSION:-v1.2.0}\" \
            --set provisioner.image.repository=\"registry.k8s.io/sig-storage/csi-provisioner\" \
            --set provisioner.image.tag=\"${STEP09_CLOUD_CSI_VERSION:-v3.4.0}\"'"
    else
        # 在线安装
        ssh_exec "$master_node_idx" "bash -lc 'helm repo add volcengine https://volcengine.github.io/helm-charts 2>/dev/null || true'"
        ssh_exec "$master_node_idx" "bash -lc 'helm repo update'"
        ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" helm install volcengine-vfs volcengine/vfs-csi-driver --namespace kube-system \
            --set driver.image.tag=\"${STEP09_CLOUD_CSI_VERSION:-v1.2.0}\" \
            --set provisioner.image.tag=\"${STEP09_CLOUD_CSI_VERSION:-v3.4.0}\"'"
    fi
    
    # 等待部署完成
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl wait --for=condition=available deployment/volcengine-vfs-controller -n kube-system --timeout=300s'"
    
    log_info "[Step09] 火山引擎VFS CSI驱动安装完成"
}

_create_cloud_storage_class(){
    local master_node_idx="$1"
    
    log_info "[Step09] 创建云存储StorageClass"
    
    # 删除旧的StorageClass
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl delete storageclass \"${STEP09_CLOUD_STORAGE_CLASS_NAME}\" --ignore-not-found'"
    
    # 根据选择的云厂商获取对应配置
    local cloud_filesystem_id cloud_region storage_class_name
    
    case "${STEP09_CLOUD_PROVIDER}" in
        aliyun)
            cloud_filesystem_id="${STEP09_ALIYUN_NAS_FILESYSTEM_ID}"
            cloud_region="${STEP09_ALIYUN_REGION}"
            storage_class_name="${STEP09_CLOUD_STORAGE_CLASS_NAME:-aliyun-nas}"
            ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl apply -f -'" <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ${storage_class_name}
  annotations:
    storageclass.kubernetes.io/is-default-class: "${STEP09_CLOUD_STORAGE_DEFAULT_CLASS}"
provisioner: nasplugin.csi.alibabacloud.com
volumeBindingMode: ${STEP09_CLOUD_STORAGE_VOLUME_BINDING_MODE}
reclaimPolicy: ${STEP09_CLOUD_STORAGE_RECLAIM_POLICY}
parameters:
  server: "${cloud_filesystem_id}"
  path: "/"
  vers: "3"
EOF
            ;;
        volcengine)
            cloud_filesystem_id="${STEP09_VOLCENGINE_VFS_FILESYSTEM_ID}"
            cloud_region="${STEP09_VOLCENGINE_REGION}"
            storage_class_name="${STEP09_CLOUD_STORAGE_CLASS_NAME:-volcengine-vfs}"
            ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl apply -f -'" <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ${storage_class_name}
  annotations:
    storageclass.kubernetes.io/is-default-class: "${STEP09_CLOUD_STORAGE_DEFAULT_CLASS}"
provisioner: vfs.csi.volcengine.com
volumeBindingMode: ${STEP09_CLOUD_STORAGE_VOLUME_BINDING_MODE}
reclaimPolicy: ${STEP09_CLOUD_STORAGE_RECLAIM_POLICY}
parameters:
  filesystemId: "${cloud_filesystem_id}"
  path: "${STEP09_VOLCENGINE_VFS_PATH:-/}"
  mountOptions: "${STEP09_VOLCENGINE_VFS_MOUNT_OPTIONS:-nfsvers=3}"
  subdirPrefix: "${STEP09_VOLCENGINE_VFS_SUBDIR_PREFIX:-k8s-pvc}"
EOF
            ;;
        tencent)
            cloud_filesystem_id="${STEP09_TENCENT_CFS_FILESYSTEM_ID}"
            cloud_region="${STEP09_TENCENT_REGION}"
            storage_class_name="${STEP09_CLOUD_STORAGE_CLASS_NAME:-tencent-cfs}"
            ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl apply -f -'" <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ${storage_class_name}
  annotations:
    storageclass.kubernetes.io/is-default-class: "${STEP09_CLOUD_STORAGE_DEFAULT_CLASS}"
provisioner: cfs.csi.tencentcloud.com
volumeBindingMode: ${STEP09_CLOUD_STORAGE_VOLUME_BINDING_MODE}
reclaimPolicy: ${STEP09_CLOUD_STORAGE_RECLAIM_POLICY}
parameters:
  filesystemId: "${cloud_filesystem_id}"
  path: "/"
  mountOptions: "nfsvers=3"
EOF
            ;;
        *)
            log_error "[Step09] 不支持的云存储提供商: ${STEP09_CLOUD_PROVIDER}"
            return 1
            ;;
    esac
    
    log_info "[Step09] 云存储StorageClass创建完成"
}

# ============================================================================
# 验证函数
# ============================================================================

_verify_storage_classes(){
    local master_node_idx="$1"
    
    log_info "[Step09] 验证StorageClass"
    
    # 显示所有StorageClass
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl get storageclass'"
}

_validate_storage_functionality(){
    local master_node_idx="$1"
    
    log_info "[Step09] 验证存储功能"
    
    # 本地存储验证
    if [[ "${STEP09_LOCAL_STORAGE_ENABLED:-false}" == "true" ]]; then
        _validate_local_storage "$master_node_idx"
    fi
    
    # NFS存储验证
    if [[ "${STEP09_NFS_STORAGE_ENABLED:-false}" == "true" ]]; then
        _validate_nfs_storage "$master_node_idx"
    fi
    
    # 云存储验证
    if [[ "${STEP09_CLOUD_STORAGE_ENABLED:-false}" == "true" ]]; then
        _validate_cloud_storage "$master_node_idx"
    fi
}

_validate_local_storage(){
    local master_node_idx="$1"
    
    log_info "[Step09] 验证本地存储功能"
    
    # 清理可能存在的旧测试资源
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl delete pod test-local-pod -n \"${STEP09_VALIDATION_NAMESPACE}\" --ignore-not-found'"
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl delete pvc test-local-pvc -n \"${STEP09_VALIDATION_NAMESPACE}\" --ignore-not-found'"
    
    # 创建测试PVC和Pod（local-path需要WaitForFirstConsumer模式）
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl apply -f -'" <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-local-pvc
  namespace: ${STEP09_VALIDATION_NAMESPACE}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: ${STEP09_LOCAL_STORAGE_CLASS_NAME}
---
apiVersion: v1
kind: Pod
metadata:
  name: test-local-pod
  namespace: ${STEP09_VALIDATION_NAMESPACE}
spec:
  containers:
  - name: test
    image: docker.io/calico/node:v3.28.2
    command: ["/bin/sh"]
    args: ["-c", "sleep 3600"]
    volumeMounts:
    - name: test-volume
      mountPath: /data
  volumes:
  - name: test-volume
    persistentVolumeClaim:
      claimName: test-local-pvc
  restartPolicy: Never
EOF
    
    # 等待Pod就绪（这会触发PVC绑定）
    if ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl wait --for=condition=ready pod/test-local-pod -n \"${STEP09_VALIDATION_NAMESPACE}\" --timeout=\"${STEP09_VALIDATION_TIMEOUT}\"s'"; then
        log_info "[Step09] 本地存储验证通过"
    else
        log_error "[Step09] 本地存储验证失败"
    fi
    
    # 清理测试资源
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl delete pod test-local-pod -n \"${STEP09_VALIDATION_NAMESPACE}\" --ignore-not-found'"
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl delete pvc test-local-pvc -n \"${STEP09_VALIDATION_NAMESPACE}\" --ignore-not-found'"
}

_validate_nfs_storage(){
    local master_node_idx="$1"
    
    log_info "[Step09] 验证NFS存储功能"
    
    # 根据配置动态选择StorageClass
    local test_storage_class
    if [[ "${STEP09_NFS_CREATE_SEPARATE_STORAGE_CLASSES:-false}" == "true" ]]; then
        # 分离模式：自动检测第一个可用的NFS StorageClass
        test_storage_class=$(ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl get storageclass -o name | grep \"^storageclass.storage.k8s.io/nfs-\" | head -1 | cut -d/ -f2'")
        if [[ -z "$test_storage_class" ]]; then
            log_error "[Step09] 分离模式：未找到可用的NFS StorageClass"
            return 1
        fi
        log_info "[Step09] 分离模式：自动检测到StorageClass $test_storage_class 进行验证"
    else
        # 统一模式：使用统一的StorageClass
        test_storage_class="${STEP09_NFS_STORAGE_CLASS_NAME:-nfs-storage}"
        log_info "[Step09] 统一模式：使用StorageClass $test_storage_class 进行验证"
    fi
    
    # 清理可能存在的旧测试资源
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl delete pod test-nfs-pod -n \"${STEP09_VALIDATION_NAMESPACE}\" --ignore-not-found'"
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl delete pvc test-nfs-pvc -n \"${STEP09_VALIDATION_NAMESPACE}\" --ignore-not-found'"
    
    # 创建测试PVC和Pod
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl apply -f -'" <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-nfs-pvc
  namespace: ${STEP09_VALIDATION_NAMESPACE}
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  storageClassName: $test_storage_class
---
apiVersion: v1
kind: Pod
metadata:
  name: test-nfs-pod
  namespace: ${STEP09_VALIDATION_NAMESPACE}
spec:
  containers:
  - name: test
    image: docker.io/calico/node:v3.28.2
    command: ["/bin/sh"]
    args: ["-c", "sleep 3600"]
    volumeMounts:
    - name: test-volume
      mountPath: /data
  volumes:
  - name: test-volume
    persistentVolumeClaim:
      claimName: test-nfs-pvc
  restartPolicy: Never
EOF
    
    # 等待Pod就绪（确保存储正常工作）
    if ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl wait --for=condition=ready pod/test-nfs-pod -n \"${STEP09_VALIDATION_NAMESPACE}\" --timeout=\"${STEP09_VALIDATION_TIMEOUT}\"s'"; then
        log_info "[Step09] NFS存储验证通过"
    else
        log_error "[Step09] NFS存储验证失败"
    fi
    
    # 清理测试资源
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl delete pod test-nfs-pod -n \"${STEP09_VALIDATION_NAMESPACE}\" --ignore-not-found'"
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl delete pvc test-nfs-pvc -n \"${STEP09_VALIDATION_NAMESPACE}\" --ignore-not-found'"
}

_validate_cloud_storage(){
    local master_node_idx="$1"
    
    log_info "[Step09] 验证云存储功能: ${STEP09_CLOUD_PROVIDER}"
    
    case "${STEP09_CLOUD_PROVIDER}" in
        aliyun)
            _validate_aliyun_nas_storage "$master_node_idx"
            ;;
        volcengine)
            _validate_volcengine_vfs_storage "$master_node_idx"
            ;;
        tencent)
            _validate_tencent_cfs_storage "$master_node_idx"
            ;;
        *)
            log_warn "[Step09] 未知的云存储提供商: ${STEP09_CLOUD_PROVIDER}，跳过验证"
            ;;
    esac
}

_validate_aliyun_nas_storage(){
    local master_node_idx="$1"
    
    log_info "[Step09] 验证阿里云NAS存储功能"
    
    # 创建测试PVC
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl apply -f -'" <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-aliyun-nas-pvc
  namespace: ${STEP09_VALIDATION_NAMESPACE}
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  storageClassName: ${STEP09_CLOUD_STORAGE_CLASS_NAME}
EOF
    
    # 等待PVC绑定
    if ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl wait --for=condition=bound pvc/test-aliyun-nas-pvc -n \"${STEP09_VALIDATION_NAMESPACE}\" --timeout=\"${STEP09_VALIDATION_TIMEOUT}\"s'"; then
        log_info "[Step09] 阿里云NAS存储验证通过"
    else
        log_error "[Step09] 阿里云NAS存储验证失败"
    fi
    
    # 清理测试资源
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl delete pvc test-aliyun-nas-pvc -n \"${STEP09_VALIDATION_NAMESPACE}\" --ignore-not-found'"
}

_validate_volcengine_vfs_storage(){
    local master_node_idx="$1"
    
    log_info "[Step09] 验证火山引擎VFS存储功能"
    
    # 创建测试PVC
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl apply -f -'" <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-volcengine-vfs-pvc
  namespace: ${STEP09_VALIDATION_NAMESPACE}
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  storageClassName: ${STEP09_CLOUD_STORAGE_CLASS_NAME}
EOF
    
    # 等待PVC绑定
    if ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl wait --for=condition=bound pvc/test-volcengine-vfs-pvc -n \"${STEP09_VALIDATION_NAMESPACE}\" --timeout=\"${STEP09_VALIDATION_TIMEOUT}\"s'"; then
        log_info "[Step09] 火山引擎VFS存储验证通过"
    else
        log_error "[Step09] 火山引擎VFS存储验证失败"
    fi
    
    # 清理测试资源
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl delete pvc test-volcengine-vfs-pvc -n \"${STEP09_VALIDATION_NAMESPACE}\" --ignore-not-found'"
}

_validate_tencent_cfs_storage(){
    local master_node_idx="$1"
    
    log_info "[Step09] 验证腾讯云CFS存储功能（待实现）"
}

_show_storage_status(){
    local master_node_idx="$1"
    
    log_info "[Step09] 显示存储状态"
    
    echo ""
    log_info "StorageClass:"
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl get storageclass'"
    
    echo ""
    log_info "PersistentVolume:"
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl get pv'"
    
    echo ""
    log_info "PersistentVolumeClaim:"
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl get pvc --all-namespaces'"
    
    echo ""
    log_info "存储相关Pod:"
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl get pods --all-namespaces | grep -E \"(storage|provisioner|local-path|nfs|csi)\" || echo \"未找到存储相关Pod\"'"
    echo ""
}

# ============================================================================
# 主函数

# ============================================================================
# 主函数
# ============================================================================

main(){ 
    precheck
    ensure_resources
    for_each_node "$TARGET" execute
    verify
}

main "$@"
