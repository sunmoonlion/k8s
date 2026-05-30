#!/usr/bin/env bash
#
# Step09: Storage Configuration
# 功能：配置 Kubernetes 集群存储（本地存储、云存储）
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

required_artifacts(){
    if [[ "$PACKAGES_DEPLOY_MODE_EFFECTIVE" == "offline" ]]; then
        # 本地存储资源
        if [[ "${STEP09_LOCAL_STORAGE_ENABLED:-false}" == "true" ]]; then
            echo "type=images image='rancher/local-path-provisioner:${LOCAL_PATH_VERSION}'"
            if [[ -n "${STEP09_HELPER_IMAGE:-}" ]]; then
                echo "type=images image='${STEP09_HELPER_IMAGE}'"
            fi
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
    
}

_prepare_local_storage_on_node(){
    local node_idx="$1"
    local enabled_var="STEP09_LOCAL_STORAGE_SERVER_${node_idx}_ENABLED"

    if [[ "${!enabled_var:-false}" == "true" ]]; then
        log_info "[Step09] 在节点 $node_idx 准备本地存储"
        local storage_path="${STEP09_LOCAL_STORAGE_PATH:-/data/local-storage}"
        ssh_exec_sudo "$node_idx" "mkdir -p '$storage_path' && chmod 755 '$storage_path'"
        log_info "[Step09] 节点 $node_idx 本地存储目录已创建: $storage_path"

        # 离线模式：预加载所需镜像到每个节点（provisioner 和 helper pod 都可能调度到任意节点）
        if [[ "$PACKAGES_DEPLOY_MODE_EFFECTIVE" == "offline" ]]; then
            local dir; dir="$(resolve_remote_dir "$(get_server_var "$node_idx" DIR)")";
            dir="${dir:-$REMOTE_DIR_FALLBACK}"

            _load_image_on_node(){
                local node="$1" image="$2" dir="$3"
                local tar; tar="$(echo "$image" | sed 's|/|_|g' | sed 's|:|_|g').tar"
                local user; user="$(get_server_var "$node" USER)"
                # 用 ssh_exec_sudo（带密码 sudo）而非 ssh_exec（无 TTY 时 sudo 会失败）
                # 路径用 ~username 展开，避免 sudo 下 $HOME 指向 /root
                if ! ssh_exec_sudo "$node" "nerdctl -n k8s.io images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -Fx '${image}'"; then
                    log_info "[Step09] 节点 $node 加载镜像: $image"
                    if ssh_exec_sudo "$node" "nerdctl -n k8s.io load -i ~${user}${dir#\~}/images/$tar"; then
                        log_info "[Step09] 节点 $node 镜像加载成功: $image"
                    else
                        log_error "[Step09] 节点 $node 镜像加载失败: $image"
                        return 1
                    fi
                else
                    log_info "[Step09] 节点 $node 镜像已存在，跳过: $image"
                fi
            }

            # 加载 local-path-provisioner 镜像（provisioner pod 可能调度到此节点）
            local provisioner_image="rancher/local-path-provisioner:${LOCAL_PATH_VERSION}"
            _load_image_on_node "$node_idx" "$provisioner_image" "$dir"

            # 加载 helper pod 镜像（helperPod 在 PVC 所在节点运行）
            local helper_image="${STEP09_HELPER_IMAGE:-}"
            if [[ -n "$helper_image" ]]; then
                _load_image_on_node "$node_idx" "$helper_image" "$dir"
            fi
        fi
    fi
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
    
    # 离线模式：直接内联生成 YAML，无需网络
    local storage_path="${STEP09_LOCAL_STORAGE_PATH:-/opt/local-path-provisioner}"
    local helper_image="${STEP09_HELPER_IMAGE:-busybox}"
    local helper_pull_policy="${STEP09_HELPER_IMAGE_PULL_POLICY:-IfNotPresent}"
    log_info "[Step09] 生成 local-path-storage.yaml（storePath=$storage_path, helperImage=$helper_image, helperPullPolicy=$helper_pull_policy）"
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl apply -f -'" <<YAML
apiVersion: v1
kind: Namespace
metadata:
  name: local-path-storage
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: local-path-provisioner-service-account
  namespace: local-path-storage
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: local-path-provisioner-role
rules:
  - apiGroups: [""]
    resources: ["nodes", "persistentvolumeclaims", "configmaps", "pods", "pods/log"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "patch", "delete"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "patch"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: local-path-provisioner-bind
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: local-path-provisioner-role
subjects:
  - kind: ServiceAccount
    name: local-path-provisioner-service-account
    namespace: local-path-storage
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: local-path-provisioner-role
  namespace: local-path-storage
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch", "create", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: local-path-provisioner-bind
  namespace: local-path-storage
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: local-path-provisioner-role
subjects:
  - kind: ServiceAccount
    name: local-path-provisioner-service-account
    namespace: local-path-storage
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: local-path-provisioner
  namespace: local-path-storage
spec:
  replicas: 1
  selector:
    matchLabels:
      app: local-path-provisioner
  template:
    metadata:
      labels:
        app: local-path-provisioner
    spec:
      serviceAccountName: local-path-provisioner-service-account
      containers:
        - name: local-path-provisioner
          image: ${image_name}
          imagePullPolicy: Never
          command:
            - local-path-provisioner
            - --debug
            - start
            - --config
            - /etc/config/config.json
          volumeMounts:
            - name: config-volume
              mountPath: /etc/config/
          env:
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
      volumes:
        - name: config-volume
          configMap:
            name: local-path-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-path-config
  namespace: local-path-storage
data:
  config.json: |-
    {
      "nodePathMap": [
        {
          "node": "DEFAULT_PATH_FOR_NON_LISTED_NODES",
          "paths": ["${storage_path}"]
        }
      ]
    }
  helperPod.yaml: |-
    apiVersion: v1
    kind: Pod
    metadata:
      name: helper-pod
    spec:
      priorityClassName: system-node-critical
      tolerations:
        - key: node.kubernetes.io/disk-pressure
          operator: Exists
          effect: NoSchedule
      containers:
        - name: helper-pod
          image: ${helper_image}
          imagePullPolicy: ${helper_pull_policy}
          securityContext:
            runAsUser: 0
  setup: |-
    #!/bin/sh
    set -eu
    mkdir -m 0777 -p "\$VOL_DIR"
  teardown: |-
    #!/bin/sh
    set -eu
    rm -rf "\$VOL_DIR"
YAML
    
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
    
    # 验证用镜像：优先使用 helper 镜像（离线已加载），fallback 到 busybox
    local validation_image="${STEP09_HELPER_IMAGE:-busybox}"
    local pull_policy="Never"
    if [[ "${PACKAGES_DEPLOY_MODE_EFFECTIVE:-online}" != "offline" ]]; then
        pull_policy="IfNotPresent"
    fi

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
    image: ${validation_image}
    imagePullPolicy: ${pull_policy}
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
        log_info "[Step09] === 诊断信息 ==="
        log_info "[Step09] Pod 状态:"
        ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl describe pod test-local-pod -n \"${STEP09_VALIDATION_NAMESPACE}\" 2>/dev/null | tail -30'" || true
        log_info "[Step09] PVC 状态:"
        ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl describe pvc test-local-pvc -n \"${STEP09_VALIDATION_NAMESPACE}\" 2>/dev/null | tail -20'" || true
        log_info "[Step09] local-path-provisioner 日志:"
        ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl logs -n local-path-storage -l app=local-path-provisioner --tail=30 2>/dev/null'" || true
        log_info "[Step09] ==============="

        # 清理测试资源后返回失败
        ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl delete pod test-local-pod -n \"${STEP09_VALIDATION_NAMESPACE}\" --ignore-not-found'"
        ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl delete pvc test-local-pvc -n \"${STEP09_VALIDATION_NAMESPACE}\" --ignore-not-found'"
        return 1
    fi

    # 清理测试资源
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl delete pod test-local-pod -n \"${STEP09_VALIDATION_NAMESPACE}\" --ignore-not-found'"
    ssh_exec "$master_node_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl delete pvc test-local-pvc -n \"${STEP09_VALIDATION_NAMESPACE}\" --ignore-not-found'"
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
