#!/bin/bash

# =============================================================================
# Step11: 初始镜像加载（仅远程集群）
# 用途：加载基础设施必需的初始镜像到所有节点的k8s.io命名空间
# 说明：在使用 Harbor 前需先部署 Traefik 和 Harbor，故先将所需镜像从本机目录加载到各节点
# Kind：不执行本步骤。Kind 用户在创建集群后、部署 Traefik/Harbor 前，在宿主机执行
#       sunmoonai/kind-infrastructure/load-initial-images-kind.sh（docker pull + kind load）
# =============================================================================

set -euo pipefail

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 导入通用函数（必须在加载配置之前，因为 load_config_file 在 common.sh 中）
if [[ -f "$PROJECT_ROOT/utils/common.sh" ]]; then
    source "$PROJECT_ROOT/utils/common.sh"
else
    log_error "[Step11] 通用函数库不存在: $PROJECT_ROOT/utils/common.sh"
    exit 1
fi

# 加载配置（使用 load_config_file 函数，它会自动处理集群配置映射）
if ! load_config_file; then
    log_error "[Step11] 配置加载失败"
    exit 1
fi

# 步骤标识
STEP_NAME="step11"
STEP_DESC="初始镜像加载"

# 补充日志函数
log_success(){ echo -e "\033[32m[SUCCESS]\033[0m $*"; }

# 默认配置
DEFAULT_IMAGES_DIR="~/packages-to-be-installed/images"
DEFAULT_CONTAINER_NAMESPACE="k8s.io"
DEFAULT_LOAD_TIMEOUT=300

# Harbor DNS 映射默认配置
DEFAULT_HARBOR_DOMAIN="harbor.sunmoonai.local"
DEFAULT_HARBOR_IP="192.168.2.50"  # 默认使用第一个master节点的IP
DEFAULT_HARBOR_PORT="30443"

# 从配置文件加载步骤配置
load_step_config() {
    # 步骤开关
    STEP11_ENABLED="${STEP11_ENABLED:-true}"
    STEP11_TARGET="${STEP11_TARGET:-all}"
    
    # 镜像配置
    STEP11_IMAGES_DIR="${STEP11_IMAGES_DIR:-$DEFAULT_IMAGES_DIR}"
    # 展开家目录路径
    if [[ "$STEP11_IMAGES_DIR" =~ ^~ ]]; then
        STEP11_IMAGES_DIR="${STEP11_IMAGES_DIR/#\~/$HOME}"
    fi
    STEP11_CONTAINER_NAMESPACE="${STEP11_CONTAINER_NAMESPACE:-$DEFAULT_CONTAINER_NAMESPACE}"
    STEP11_LOAD_TIMEOUT="${STEP11_LOAD_TIMEOUT:-$DEFAULT_LOAD_TIMEOUT}"
    
    # 功能开关配置
    STEP11_ENABLE_IMAGE_LOADING="${STEP11_ENABLE_IMAGE_LOADING:-true}"
    STEP11_ENABLE_HARBOR_DNS="${STEP11_ENABLE_HARBOR_DNS:-true}"
    
    # Harbor DNS 映射配置
    # 注意：STEP11_HARBOR_LOCAL_IP 和 STEP11_HARBOR_PUBLIC_IP 应该已经被 apply_cluster_config_mapping 设置了
    # 如果没有设置，才使用默认值（这通常不应该发生，除非配置有问题）
    STEP11_HARBOR_DOMAIN="${STEP11_HARBOR_DOMAIN:-$DEFAULT_HARBOR_DOMAIN}"
    
    # 获取私网IP
    if [[ -z "${STEP11_HARBOR_LOCAL_IP:-}" ]]; then
        # 如果 STEP11_HARBOR_LOCAL_IP 未设置，尝试从集群配置中获取
        local cluster_selected="${CLUSTER:-C1}"
        if [[ "$cluster_selected" =~ ^C[0-9]+$ ]]; then
            local cluster_ip_var="${cluster_selected}_STEP11_HARBOR_LOCAL_IP"
            if [[ -n "${!cluster_ip_var:-}" ]]; then
                STEP11_HARBOR_LOCAL_IP="${!cluster_ip_var}"
                log_info "[Step11] 从集群配置读取 Harbor 私网IP: ${STEP11_HARBOR_LOCAL_IP}"
            else
                # 向后兼容：尝试读取旧的 STEP11_HARBOR_IP
                local old_ip_var="${cluster_selected}_STEP11_HARBOR_IP"
                if [[ -n "${!old_ip_var:-}" ]]; then
                    STEP11_HARBOR_LOCAL_IP="${!old_ip_var}"
                    log_info "[Step11] 从旧配置读取 Harbor IP（作为私网IP）: ${STEP11_HARBOR_LOCAL_IP}"
                else
                    STEP11_HARBOR_LOCAL_IP="$DEFAULT_HARBOR_IP"
                    log_warn "[Step11] 未找到集群配置 ${cluster_ip_var}，使用默认值: ${STEP11_HARBOR_LOCAL_IP}"
                fi
            fi
        else
            STEP11_HARBOR_LOCAL_IP="$DEFAULT_HARBOR_IP"
            log_warn "[Step11] 无效的集群标识，使用默认值: ${STEP11_HARBOR_LOCAL_IP}"
        fi
    else
        log_info "[Step11] 使用配置的 Harbor 私网IP: ${STEP11_HARBOR_LOCAL_IP}"
    fi
    
    # 获取公网IP（可选）
    if [[ -z "${STEP11_HARBOR_PUBLIC_IP:-}" ]]; then
        local cluster_selected="${CLUSTER:-C1}"
        if [[ "$cluster_selected" =~ ^C[0-9]+$ ]]; then
            local cluster_public_ip_var="${cluster_selected}_STEP11_HARBOR_PUBLIC_IP"
            if [[ -n "${!cluster_public_ip_var:-}" ]]; then
                STEP11_HARBOR_PUBLIC_IP="${!cluster_public_ip_var}"
                log_info "[Step11] 从集群配置读取 Harbor 公网IP: ${STEP11_HARBOR_PUBLIC_IP}"
            else
                log_info "[Step11] 未配置 Harbor 公网IP，将只添加私网IP映射"
            fi
        fi
    else
        log_info "[Step11] 使用配置的 Harbor 公网IP: ${STEP11_HARBOR_PUBLIC_IP}"
    fi
    
    STEP11_HARBOR_PORT="${STEP11_HARBOR_PORT:-$DEFAULT_HARBOR_PORT}"
    
    # 要加载的镜像列表（从配置文件中读取）
    # 自动收集所有以 STEP_IMAGE_ 开头的变量
    STEP11_IMAGE_LIST=()
    
    # 获取所有以 STEP_IMAGE_ 开头的变量
    local image_vars
    image_vars=$(compgen -v | grep '^STEP_IMAGE_' || true)
    
    if [[ -n "$image_vars" ]]; then
        for var in $image_vars; do
            if [[ -n "${!var:-}" ]]; then
                STEP11_IMAGE_LIST+=("${!var}")
                log_info "[Step11] 发现镜像配置: $var=${!var}"
            fi
        done
    fi
    
    # 如果没有配置任何镜像，使用默认列表
    if [[ ${#STEP11_IMAGE_LIST[@]} -eq 0 ]]; then
        STEP11_IMAGE_LIST=(
            "traefik:v3.5.2"
            "bitnami/harbor-core:2.13.2-debian-12-r3"
            "bitnami/harbor-portal:2.13.2-debian-12-r1"
            "bitnami/harbor-jobservice:2.13.2-debian-12-r3"
            "bitnami/harbor-registry:2.13.2-debian-12-r2"
            "bitnami/harbor-registryctl:2.13.2-debian-12-r3"
            "bitnami/harbor-adapter-trivy:2.13.2-debian-12-r2"
            "bitnami/harbor-exporter:2.13.2-debian-12-r2"
            "bitnami/nginx:1.29.1-debian-12-r0"
            "bitnami/redis:8.2.1-debian-12-r0"
            "bitnami/postgresql:17.6.0-debian-12-r4"
        )
    fi
    
    log_info "[Step11] 配置加载完成"
    log_info "[Step11] 镜像加载功能: ${STEP11_ENABLE_IMAGE_LOADING}"
    log_info "[Step11] Harbor DNS映射功能: ${STEP11_ENABLE_HARBOR_DNS}"
    log_info "[Step11] 镜像目录: $STEP11_IMAGES_DIR"
    log_info "[Step11] 容器命名空间: $STEP11_CONTAINER_NAMESPACE"
    log_info "[Step11] 加载超时: ${STEP11_LOAD_TIMEOUT}秒"
    log_info "[Step11] 镜像数量: ${#STEP11_IMAGE_LIST[@]}"
    # 显示实际使用的IP（优先私网IP）
    if [[ -n "${STEP11_HARBOR_LOCAL_IP:-}" ]]; then
        log_info "[Step11] Harbor域名映射: ${STEP11_HARBOR_DOMAIN} -> ${STEP11_HARBOR_LOCAL_IP}:${STEP11_HARBOR_PORT} (使用私网IP)"
    elif [[ -n "${STEP11_HARBOR_PUBLIC_IP:-}" ]]; then
        log_info "[Step11] Harbor域名映射: ${STEP11_HARBOR_DOMAIN} -> ${STEP11_HARBOR_PUBLIC_IP}:${STEP11_HARBOR_PORT} (使用公网IP)"
    fi
}

# 预检查
precheck() {
    log_info "[Step11] 开始预检查..."
    
    # 检查步骤是否启用
    if [[ "$STEP11_ENABLED" != "true" ]]; then
        log_info "[Step11] 步骤已禁用，跳过执行"
        return 0
    fi
    
    # 获取目标节点 - 动态解析可用节点
    local target_nodes=()
    local indices; indices="$(get_defined_server_indices)"
    
    
    case "${STEP11_TARGET:-all}" in
        master) 
            for i in $indices; do
                if [[ "$(get_server_var "$i" TYPE)" == "master" ]]; then
                    target_nodes+=("$i")
                fi
            done
            ;;
        worker)
            for i in $indices; do
                if [[ "$(get_server_var "$i" TYPE)" == "worker" ]]; then
                    target_nodes+=("$i")
                fi
            done
            ;;
        all)
            for i in $indices; do
                target_nodes+=("$i")
            done
            ;;
        *) log_error "无效的STEP11_TARGET: ${STEP11_TARGET}"; return 1 ;;
    esac
    
    if [[ ${#target_nodes[@]} -eq 0 ]]; then
        log_error "[Step11] 未找到目标节点"
        return 1
    fi
    
    log_info "[Step11] 目标节点: ${target_nodes[*]}"
    
    # 检查镜像列表
    if [[ "$STEP11_ENABLE_IMAGE_LOADING" == "true" ]] && [[ ${#STEP11_IMAGE_LIST[@]} -eq 0 ]]; then
        log_warn "[Step11] 未配置要加载的镜像"
        return 1
    fi
    
    log_success "[Step11] 预检查通过"
    return 0
}

# 确保资源
ensure_resources() {
    log_info "[Step11] 确保资源可用..."
    
    # 获取目标节点
    local target_nodes=()
    local indices; indices="$(get_defined_server_indices)"
    
    case "${STEP11_TARGET:-all}" in
        master) 
            for i in $indices; do
                if [[ "$(get_server_var "$i" TYPE)" == "master" ]]; then
                    target_nodes+=("$i")
                fi
            done
            ;;
        worker)
            for i in $indices; do
                if [[ "$(get_server_var "$i" TYPE)" == "worker" ]]; then
                    target_nodes+=("$i")
                fi
            done
            ;;
        all)
            for i in $indices; do
                target_nodes+=("$i")
            done
            ;;
    esac
    
    for node in "${target_nodes[@]}"; do
        log_info "[Step11] 检查节点 $node 的镜像目录..."
        
        if ! ssh_exec "$node" "test -d '$STEP11_IMAGES_DIR'"; then
            log_error "[Step11] 节点 $node 镜像目录不存在: $STEP11_IMAGES_DIR"
            return 1
        fi
        
        # 检查镜像文件是否存在
        local missing_images=()
        for image in "${STEP11_IMAGE_LIST[@]}"; do
            local image_file="${image//\//_}.tar"
            # 将冒号也替换为下划线
            image_file="${image_file//:/_}"
            if ! ssh_exec "$node" "test -f '$STEP11_IMAGES_DIR/$image_file'"; then
                missing_images+=("$image_file")
            fi
        done
        
        if [[ ${#missing_images[@]} -gt 0 ]]; then
            log_warn "[Step11] 节点 $node 缺少以下镜像文件:"
            for img in "${missing_images[@]}"; do
                log_warn "[Step11]   - $img"
            done
        fi
    done
    
    log_success "[Step11] 资源检查完成"
    return 0
}

# 设置 Harbor DNS 映射
setup_harbor_dns_mapping() {
    local node="$1"
    
    if [[ "$STEP11_ENABLE_HARBOR_DNS" != "true" ]]; then
        log_info "[Step11] Harbor DNS映射已禁用，跳过"
        return 0
    fi
    
    log_info "[Step11] 节点 $node: 设置Harbor DNS映射"
    
    # 检查是否已经存在映射
    if ssh_exec "$node" "grep -q '${STEP11_HARBOR_DOMAIN}' /etc/hosts"; then
        log_info "[Step11] 节点 $node: Harbor域名映射已存在，更新中..."
        # 删除旧的映射
        ssh_exec_sudo "$node" "sed -i '/${STEP11_HARBOR_DOMAIN}/d' /etc/hosts"
    fi
    
    # 选择要使用的IP（优先使用私网IP，如果私网IP存在则使用私网，否则使用公网IP）
    # 注意：/etc/hosts 中同一个域名有多个IP时，系统只使用第一个匹配的条目
    # 因此只添加一个IP映射，优先使用私网IP（内网访问更快更安全）
    local harbor_ip_to_use=""
    local ip_type=""
    
    if [[ -n "${STEP11_HARBOR_LOCAL_IP:-}" ]]; then
        harbor_ip_to_use="${STEP11_HARBOR_LOCAL_IP}"
        ip_type="私网"
        log_info "[Step11] 节点 $node: 使用私网IP进行DNS映射（优先选择）"
    elif [[ -n "${STEP11_HARBOR_PUBLIC_IP:-}" ]]; then
        harbor_ip_to_use="${STEP11_HARBOR_PUBLIC_IP}"
        ip_type="公网"
        log_info "[Step11] 节点 $node: 使用公网IP进行DNS映射（私网IP未配置）"
    else
        log_error "[Step11] 节点 $node: 未配置 Harbor IP（私网或公网IP至少需要配置一个）"
        return 1
    fi
    
    # 添加IP映射（只添加一个）
    local hosts_entry="${harbor_ip_to_use} ${STEP11_HARBOR_DOMAIN}"
    if ssh_exec_sudo "$node" "echo '$hosts_entry' >> /etc/hosts"; then
        log_success "[Step11] 节点 $node: Harbor DNS映射（${ip_type}）设置成功"
        log_info "[Step11] 节点 $node: $hosts_entry"
    else
        log_error "[Step11] 节点 $node: Harbor DNS映射（${ip_type}）设置失败"
        return 1
    fi
    
    # 验证映射是否生效
    if verify_harbor_dns_mapping "$node"; then
        log_success "[Step11] 节点 $node: Harbor DNS映射验证通过"
        return 0
    else
        log_warn "[Step11] 节点 $node: Harbor DNS映射验证失败"
        return 1
    fi
}

# 验证 Harbor DNS 映射
verify_harbor_dns_mapping() {
    local node="$1"
    
    log_info "[Step11] 节点 $node: 验证Harbor DNS映射"
    
    # 确定期望使用的IP（优先私网IP）
    local expected_ip=""
    if [[ -n "${STEP11_HARBOR_LOCAL_IP:-}" ]]; then
        expected_ip="${STEP11_HARBOR_LOCAL_IP}"
    elif [[ -n "${STEP11_HARBOR_PUBLIC_IP:-}" ]]; then
        expected_ip="${STEP11_HARBOR_PUBLIC_IP}"
    else
        log_error "[Step11] 节点 $node: 未配置 Harbor IP"
        return 1
    fi
    
    # 检查 /etc/hosts 文件中的映射
    if ssh_exec "$node" "grep -q '${STEP11_HARBOR_DOMAIN}' /etc/hosts"; then
        local mapped_ip
        mapped_ip=$(ssh_exec "$node" "grep '${STEP11_HARBOR_DOMAIN}' /etc/hosts | awk '{print \$1}' | head -1")
        
        if [[ "$mapped_ip" == "$expected_ip" ]]; then
            log_success "[Step11] 节点 $node: /etc/hosts中配置正确: ${STEP11_HARBOR_DOMAIN} -> $mapped_ip"
        else
            log_warn "[Step11] 节点 $node: /etc/hosts中IP不匹配: 期望 $expected_ip, 实际 $mapped_ip"
            return 1
        fi
        
        # 实际测试DNS解析（使用getent或host命令）
        local resolved_ip
        resolved_ip=$(ssh_exec "$node" "getent hosts ${STEP11_HARBOR_DOMAIN} 2>/dev/null | awk '{print \$1}' | head -1" || echo "")
        
        if [[ -n "$resolved_ip" ]]; then
            if [[ "$resolved_ip" == "$expected_ip" ]]; then
                log_success "[Step11] 节点 $node: DNS解析结果正确: ${STEP11_HARBOR_DOMAIN} -> $resolved_ip"
            else
                log_warn "[Step11] 节点 $node: DNS解析结果异常: ${STEP11_HARBOR_DOMAIN} -> $resolved_ip (期望: $expected_ip)"
            fi
        else
            log_warn "[Step11] 节点 $node: 无法解析域名 ${STEP11_HARBOR_DOMAIN}"
        fi
        
        return 0
    else
        log_warn "[Step11] 节点 $node: 未找到Harbor域名映射"
        return 1
    fi
}

# 清理 Harbor DNS 映射
cleanup_harbor_dns_mapping() {
    local node="$1"
    
    log_info "[Step11] 节点 $node: 清理Harbor DNS映射"
    
    if ssh_exec "$node" "grep -q '${STEP11_HARBOR_DOMAIN}' /etc/hosts"; then
        if ssh_exec_sudo "$node" "sed -i '/${STEP11_HARBOR_DOMAIN}/d' /etc/hosts"; then
            log_success "[Step11] 节点 $node: Harbor DNS映射清理成功"
        else
            log_warn "[Step11] 节点 $node: Harbor DNS映射清理失败"
        fi
    else
        log_info "[Step11] 节点 $node: 未找到Harbor DNS映射，无需清理"
    fi
}

# 批量设置 Harbor DNS 映射
# 注意：DNS 映射应该在所有节点上设置（包括控制平面节点），不受 STEP11_TARGET 影响
setup_harbor_dns_mapping_all() {
    log_info "[Step11] 开始批量设置Harbor DNS映射（所有节点）..."
    
    # DNS 映射应该在所有节点上设置，不受 STEP11_TARGET 影响
    # 因为 Harbor 部署脚本需要在控制平面节点上检查 Harbor API
    local target_nodes=()
    local indices; indices="$(get_defined_server_indices)"
    
    # 始终包括所有节点
    for i in $indices; do
        target_nodes+=("$i")
    done
    
    local success_count=0
    local total_count=${#target_nodes[@]}
    
    log_info "[Step11] 将在 $total_count 个节点上设置 Harbor DNS 映射"
    
    for node in "${target_nodes[@]}"; do
        local node_type
        node_type="$(get_server_var "$node" TYPE)"
        log_info "[Step11] 节点 $node ($node_type): 设置 Harbor DNS 映射"
        if setup_harbor_dns_mapping "$node"; then
            success_count=$((success_count + 1))
        fi
    done
    
    log_info "[Step11] Harbor DNS映射设置完成: $success_count/$total_count"
    
    if [[ $success_count -eq $total_count ]]; then
        log_success "[Step11] 所有节点Harbor DNS映射设置成功"
        return 0
    else
        log_warn "[Step11] 部分节点Harbor DNS映射设置失败"
        return 1
    fi
}

# 批量清理 Harbor DNS 映射
# 注意：DNS 映射清理应该在所有节点上执行，不受 STEP11_TARGET 影响
cleanup_harbor_dns_mapping_all() {
    log_info "[Step11] 开始批量清理Harbor DNS映射（所有节点）..."
    
    # DNS 映射清理应该在所有节点上执行
    local target_nodes=()
    local indices; indices="$(get_defined_server_indices)"
    
    # 始终包括所有节点
    for i in $indices; do
        target_nodes+=("$i")
    done
    
    local success_count=0
    local total_count=${#target_nodes[@]}
    
    log_info "[Step11] 将在 $total_count 个节点上清理 Harbor DNS 映射"
    
    for node in "${target_nodes[@]}"; do
        if cleanup_harbor_dns_mapping "$node"; then
            success_count=$((success_count + 1))
        fi
    done
    
    log_info "[Step11] Harbor DNS映射清理完成: $success_count/$total_count"
    
    if [[ $success_count -eq $total_count ]]; then
        log_success "[Step11] 所有节点Harbor DNS映射清理成功"
        return 0
    else
        log_warn "[Step11] 部分节点Harbor DNS映射清理失败"
        return 1
    fi
}

# 执行镜像加载
execute() {
    log_info "[Step11] 开始执行镜像加载..."
    
    # 获取目标节点
    local target_nodes=()
    local indices; indices="$(get_defined_server_indices)"
    
    case "${STEP11_TARGET:-all}" in
        master) 
            for i in $indices; do
                if [[ "$(get_server_var "$i" TYPE)" == "master" ]]; then
                    target_nodes+=("$i")
                fi
            done
            ;;
        worker)
            for i in $indices; do
                if [[ "$(get_server_var "$i" TYPE)" == "worker" ]]; then
                    target_nodes+=("$i")
                fi
            done
            ;;
        all)
            for i in $indices; do
                target_nodes+=("$i")
            done
            ;;
    esac
    
    # 1. 首先在所有节点上设置 Harbor DNS 映射（不受 STEP11_TARGET 影响）
    # 因为 Harbor 部署脚本需要在控制平面节点上检查 Harbor API
    if [[ "$STEP11_ENABLE_HARBOR_DNS" == "true" ]]; then
        log_info "[Step11] 在所有节点上设置 Harbor DNS 映射..."
        local all_nodes=()
        for i in $indices; do
            all_nodes+=("$i")
        done
        for node in "${all_nodes[@]}"; do
            local node_type
            node_type="$(get_server_var "$node" TYPE)"
            log_info "[Step11] 节点 $node ($node_type): 设置 Harbor DNS 映射"
            if ! setup_harbor_dns_mapping "$node"; then
                log_warn "[Step11] 节点 $node: Harbor DNS映射设置失败，继续执行"
            fi
        done
    fi
    
    # 2. 执行镜像加载（根据 STEP11_TARGET 选择节点）
    for node in "${target_nodes[@]}"; do
        log_info "[Step11] 节点 $node: 开始处理"
        
        # 检查节点类型
        local node_type
        node_type="$(get_server_var "$node" TYPE)"
        log_info "[Step11] 节点 $node ($node_type): 开始处理"
        
        # 2. 执行镜像加载（如果启用）
        local loaded_count=0
        local failed_count=0
        
        if [[ "$STEP11_ENABLE_IMAGE_LOADING" == "true" ]]; then
            log_info "[Step11] 节点 $node: 开始加载镜像"
            
            for image in "${STEP11_IMAGE_LIST[@]}"; do
                local image_file="${image//\//_}.tar"
                # 将冒号也替换为下划线
                image_file="${image_file//:/_}"
                local image_path="$STEP11_IMAGES_DIR/$image_file"
                
                log_info "[Step11] 节点 $node: 加载镜像 $image"
                
                # 检查镜像文件是否存在
                if ! ssh_exec "$node" "test -f $image_path"; then
                    log_warn "[Step11] 节点 $node: 镜像文件不存在，跳过: $image_file"
                    failed_count=$((failed_count + 1))
                    continue
                fi
                
                # 检查镜像是否已经加载
                if ssh_exec "$node" "sudo nerdctl -n $STEP11_CONTAINER_NAMESPACE images --format '{{.Repository}}:{{.Tag}}' | grep -Fx '$image'"; then
                    log_info "[Step11] 节点 $node: 镜像已存在，跳过: $image"
                    loaded_count=$((loaded_count + 1))
                    continue
                fi
                
                # 加载镜像
                log_info "[Step11] 节点 $node: 正在加载 $image_file..."
                if ssh_exec "$node" "sudo nerdctl -n $STEP11_CONTAINER_NAMESPACE load -i '$image_path'"; then
                    log_success "[Step11] 节点 $node: 镜像加载成功: $image"
                    loaded_count=$((loaded_count + 1))
                else
                    log_error "[Step11] 节点 $node: 镜像加载失败: $image"
                    failed_count=$((failed_count + 1))
                fi
            done
            
            log_info "[Step11] 节点 $node: 镜像加载完成 - 成功: $loaded_count, 失败: $failed_count"
        else
            log_info "[Step11] 节点 $node: 镜像加载功能已禁用，跳过"
        fi
    done
    
    log_success "[Step11] 镜像加载和Harbor DNS映射执行完成"
    return 0
}

# 验证镜像加载结果
verify() {
    log_info "[Step11] 开始验证镜像加载结果..."
    
    # 获取目标节点
    local target_nodes=()
    local indices; indices="$(get_defined_server_indices)"
    
    case "${STEP11_TARGET:-all}" in
        master) 
            for i in $indices; do
                if [[ "$(get_server_var "$i" TYPE)" == "master" ]]; then
                    target_nodes+=("$i")
                fi
            done
            ;;
        worker)
            for i in $indices; do
                if [[ "$(get_server_var "$i" TYPE)" == "worker" ]]; then
                    target_nodes+=("$i")
                fi
            done
            ;;
        all)
            for i in $indices; do
                target_nodes+=("$i")
            done
            ;;
    esac
    
    local total_verified=0
    local total_expected=0
    local dns_verified=0
    local dns_total=0
    
    for node in "${target_nodes[@]}"; do
        log_info "[Step11] 节点 $node: 验证镜像加载和DNS映射结果"
        
        # 验证镜像加载（如果启用）
        local node_verified=0
        local node_expected=0
        
        if [[ "$STEP11_ENABLE_IMAGE_LOADING" == "true" ]]; then
            node_expected=${#STEP11_IMAGE_LIST[@]}
            
            for image in "${STEP11_IMAGE_LIST[@]}"; do
                if ssh_exec "$node" "sudo nerdctl -n $STEP11_CONTAINER_NAMESPACE images --format '{{.Repository}}:{{.Tag}}' | grep -Fx '$image'"; then
                    log_success "[Step11] 节点 $node: ✅ 镜像 $image"
                    node_verified=$((node_verified + 1))
                else
                    # 自愈：若镜像被后期 prune 删除，则优先使用本节点 tar 补载；若本节点无 tar，则从其他节点复制一份再补载
                    local image_file="${image//\//_}.tar"
                    image_file="${image_file//:/_}"
                    local image_path="$STEP11_IMAGES_DIR/$image_file"
                    
                    # 1) 优先使用当前节点上的 tar
                    if ssh_exec "$node" "test -f '$image_path'"; then
                        log_info "[Step11] 节点 $node: 镜像 $image 缺失，尝试从本节点 $image_file 补载..."
                        if ssh_exec "$node" "sudo nerdctl -n $STEP11_CONTAINER_NAMESPACE load -i '$image_path'"; then
                            if ssh_exec "$node" "sudo nerdctl -n $STEP11_CONTAINER_NAMESPACE images --format '{{.Repository}}:{{.Tag}}' | grep -Fx '$image'"; then
                                log_success "[Step11] 节点 $node: ✅ 镜像 $image（本节点补载后通过）"
                                node_verified=$((node_verified + 1))
                                continue
                            else
                                log_warn "[Step11] 节点 $node: ❌ 镜像 $image（本节点补载后仍缺失）"
                            fi
                        else
                            log_warn "[Step11] 节点 $node: ❌ 镜像 $image（本节点补载失败）"
                        fi
                    fi

                    # 2) 本节点没有或补载失败时，从集群其他节点复制 tar
                    local src_idx=""
                    local indices_all
                    indices_all="$(get_defined_server_indices)"
                    for src in $indices_all; do
                        if [[ "$src" == "$node" ]]; then
                            continue
                        fi
                        if ssh_exec "$src" "test -f '$image_path'"; then
                            src_idx="$src"
                            break
                        fi
                    done

                    if [[ -n "$src_idx" ]]; then
                        # 解析目标节点连接信息（优先使用内网 IP）
                        local target_ip
                        target_ip="$(get_server_var "$node" LOCAL_IP)"
                        if [[ -z "$target_ip" ]]; then
                            target_ip="$(get_server_var "$node" PUBLIC_IP)"
                        fi
                        local target_user
                        target_user="$(get_server_var "$node" USER)"
                        local target_port
                        target_port="$(get_server_var "$node" SSH_PORT)"; target_port="${target_port:-22}"

                        if [[ -z "$target_ip" || -z "$target_user" ]]; then
                            log_warn "[Step11] 节点 $node: ❌ 镜像 $image（找到 $image_file 源节点 $src_idx，但无法解析目标节点连接信息）"
                        else
                            log_info "[Step11] 节点 $node: 镜像 $image 缺失，尝试从节点 $src_idx 复制 $image_file ..."
                            # 确保目标节点目录存在
                            ssh_exec "$node" "mkdir -p '$STEP11_IMAGES_DIR'" || true
                            # 在源节点上通过内网 scp 把 tar 拷贝到目标节点
                            ssh_exec "$src_idx" "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P $target_port '$image_path' '$target_user@$target_ip:$STEP11_IMAGES_DIR/'" || true

                            # 复制完成后，再次尝试在目标节点补载
                            if ssh_exec "$node" "test -f '$image_path'"; then
                                log_info "[Step11] 节点 $node: 已从节点 $src_idx 获取 $image_file，尝试补载..."
                                if ssh_exec "$node" "sudo nerdctl -n $STEP11_CONTAINER_NAMESPACE load -i '$image_path'"; then
                                    if ssh_exec "$node" "sudo nerdctl -n $STEP11_CONTAINER_NAMESPACE images --format '{{.Repository}}:{{.Tag}}' | grep -Fx '$image'"; then
                                        log_success "[Step11] 节点 $node: ✅ 镜像 $image（跨节点补载后通过）"
                                        node_verified=$((node_verified + 1))
                                    else
                                        log_warn "[Step11] 节点 $node: ❌ 镜像 $image（跨节点补载后仍缺失）"
                                    fi
                                else
                                    log_warn "[Step11] 节点 $node: ❌ 镜像 $image（跨节点补载失败）"
                                fi
                            else
                                log_warn "[Step11] 节点 $node: ❌ 镜像 $image（已尝试从节点 $src_idx 复制 $image_file，但目标节点仍无该文件）"
                            fi
                        fi
                    else
                        log_warn "[Step11] 节点 $node: ❌ 镜像 $image（集群内无 $image_file，无法补载）"
                    fi
                fi
            done
        else
            log_info "[Step11] 节点 $node: 镜像加载功能已禁用，跳过验证"
        fi
        
        # 验证 Harbor DNS 映射
        if [[ "$STEP11_ENABLE_HARBOR_DNS" == "true" ]]; then
            dns_total=$((dns_total + 1))
            if verify_harbor_dns_mapping "$node"; then
                log_success "[Step11] 节点 $node: ✅ Harbor DNS映射"
                dns_verified=$((dns_verified + 1))
            else
                log_warn "[Step11] 节点 $node: ❌ Harbor DNS映射"
            fi
        fi
        
        log_info "[Step11] 节点 $node: 验证结果 - 镜像: $node_verified/$node_expected"
        total_verified=$((total_verified + node_verified))
        total_expected=$((total_expected + node_expected))
    done
    
    # 输出总体验证结果
    if [[ $total_verified -eq $total_expected ]]; then
        log_success "[Step11] 所有镜像加载验证通过: $total_verified/$total_expected"
    else
        log_warn "[Step11] 部分镜像加载验证失败: $total_verified/$total_expected"
    fi
    
    if [[ "$STEP11_ENABLE_HARBOR_DNS" == "true" ]]; then
        if [[ $dns_verified -eq $dns_total ]]; then
            log_success "[Step11] 所有Harbor DNS映射验证通过: $dns_verified/$dns_total"
        else
            log_warn "[Step11] 部分Harbor DNS映射验证失败: $dns_verified/$dns_total"
        fi
    fi
    
    # 综合判断
    if [[ $total_verified -eq $total_expected ]] && [[ "$STEP11_ENABLE_HARBOR_DNS" != "true" || $dns_verified -eq $dns_total ]]; then
        return 0
    else
        return 1
    fi
}

# 显示镜像列表
show_image_list() {
    log_info "[Step11] 要加载的镜像列表:"
    for i in "${!STEP11_IMAGE_LIST[@]}"; do
        local image="${STEP11_IMAGE_LIST[$i]}"
        local image_file="${image//\//_}.tar"
        # 将冒号也替换为下划线
        image_file="${image_file//:/_}"
        log_info "[Step11]   $((i+1)). $image -> $image_file"
    done
}

# 显示帮助信息
show_help() {
    cat << EOF
Step11: 初始镜像加载和Harbor DNS映射

用途：
  1. 加载基础设施必需的初始镜像到所有节点的k8s.io命名空间
  2. 在Harbor启动前，预先加载Traefik等关键组件的镜像
  3. 设置Harbor镜像域名的局域网IP地址映射

配置参数：
  STEP11_ENABLED=true|false                    # 是否启用此步骤（总开关）
  STEP11_TARGET=master|worker|all              # 目标节点类型
  STEP11_IMAGES_DIR=~/packages-to-be-installed/images  # 镜像文件目录
  STEP11_CONTAINER_NAMESPACE=k8s.io            # 容器命名空间
  STEP11_LOAD_TIMEOUT=300                      # 加载超时时间（秒）
  STEP11_IMAGE_LIST=(                          # 要加载的镜像列表
    "traefik:v3.5.2"
    "bitnami/harbor-core:2.13.2-debian-12-r3"
    # ... 更多镜像
  )

功能开关：
  STEP11_ENABLE_IMAGE_LOADING=true|false       # 是否启用镜像加载功能
  STEP11_ENABLE_HARBOR_DNS=true|false          # 是否启用Harbor DNS映射功能

Harbor DNS映射配置：
  STEP11_HARBOR_DOMAIN=harbor.sunmoonai.local  # Harbor域名
  STEP11_HARBOR_LOCAL_IP=192.168.2.50          # Harbor私网IP地址（优先使用）
  STEP11_HARBOR_PUBLIC_IP=101.126.151.0        # Harbor公网IP地址（仅在私网IP未配置时使用）
  STEP11_HARBOR_PORT=30443                     # Harbor端口
  # 注意：/etc/hosts 中同一个域名有多个IP时，系统只使用第一个匹配的条目
  # 因此脚本会优先使用私网IP（如果配置了），否则使用公网IP

执行流程：
  1. 预检查 - 验证配置和目标节点
  2. 确保资源 - 检查镜像文件是否存在
  3. 执行加载 - 使用nerdctl加载镜像到k8s.io命名空间
  4. 设置DNS映射 - 在/etc/hosts中添加Harbor域名映射
  5. 验证结果 - 确认镜像加载和DNS映射成功

支持的操作：
  precheck          # 预检查
  ensure_resources  # 确保资源
  execute          # 执行完整流程
  verify           # 验证结果
  show_config      # 显示配置
  setup_dns        # 仅设置Harbor DNS映射
  cleanup_dns      # 仅清理Harbor DNS映射
  help             # 显示此帮助信息

注意事项：
  - 镜像文件格式：image_name:tag -> image_name_tag.tar
  - 使用sudo nerdctl确保有足够权限
  - 加载到k8s.io命名空间供Kubernetes使用
  - 支持跳过已存在的镜像
  - Harbor DNS映射会修改/etc/hosts文件
  - 支持更新已存在的Harbor域名映射

EOF
}

# 主函数
main() {
    local action="${1:-}"
    
    # 如果没有提供参数，默认执行完整流程
    if [[ -z "$action" ]]; then
        log_info "[Step11] 开始执行初始镜像加载流程..."
        load_step_config
        
        # 执行完整流程
        # 注意：即使镜像加载功能禁用，也要确保 DNS 映射在所有节点上设置
        if precheck && ensure_resources && execute && verify; then
            # 额外确保：如果 Harbor DNS 映射功能启用，确保在所有节点上设置（即使镜像加载失败）
            if [[ "$STEP11_ENABLE_HARBOR_DNS" == "true" ]]; then
                log_info "[Step11] 确保所有节点上的 Harbor DNS 映射已设置..."
                setup_harbor_dns_mapping_all
            fi
            log_success "[Step11] 初始镜像加载完成！"
            return 0
        else
            # 即使执行失败，也要确保 DNS 映射在所有节点上设置
            if [[ "$STEP11_ENABLE_HARBOR_DNS" == "true" ]]; then
                log_info "[Step11] 执行过程中出现错误，但确保所有节点上的 Harbor DNS 映射已设置..."
                setup_harbor_dns_mapping_all
            fi
            log_error "[Step11] 初始镜像加载失败！"
            return 1
        fi
    fi
    
    case "$action" in
        "precheck")
            load_step_config
            precheck
            ;;
        "ensure_resources")
            load_step_config
            ensure_resources
            ;;
        "execute")
            load_step_config
            execute
            ;;
        "verify")
            load_step_config
            verify
            ;;
        "show_config")
            load_step_config
            show_image_list
            ;;
        "setup_dns")
            load_step_config
            setup_harbor_dns_mapping_all
            ;;
        "cleanup_dns")
            load_step_config
            cleanup_harbor_dns_mapping_all
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            log_error "未知操作: $action"
            log_info "支持的操作: precheck, ensure_resources, execute, verify, show_config, setup_dns, cleanup_dns, help"
            exit 1
            ;;
    esac
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
