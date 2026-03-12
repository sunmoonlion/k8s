#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Kubernetes 基础设施部署脚本
# - 提供完整的 Kubernetes 集群部署流程
# - 支持在线/离线两种部署模式
# - 每个步骤都有独立的资源检查和错误处理
# =============================================================================

export LC_ALL=C
export LANG=C
export LANGUAGE=C

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$THIS_DIR")"   # k8s-deploy 根目录
# k8s 根目录：.../k8s（用于引用 utils 下的通用脚本）
# THIS_DIR=.../k8s/sunmoonai/infrastructure/deploy-infrastructure-all
K8S_ROOT_DIR="$(cd "$THIS_DIR/../../.." && pwd)"

# 集群参数解析（轻量，无连接副作用）
source "$K8S_ROOT_DIR/utils/cluster-arg-parser.sh"


# 变量路径
SCRIPT_DIR="$PROJECT_ROOT"
STEPS_DIR="$SCRIPT_DIR/steps"

# 颜色输出函数
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }
bold() { echo -e "\033[1m$*\033[0m"; }

# 日志函数
log_info() { echo "ℹ️  $*"; }
log_success() { green "✅ $*"; }
log_warn() { yellow "⚠️  $*"; }
log_error() { red "❌ $*"; }

banner(){
    echo "========================================"
    echo "🚀 Kubernetes 基础设施部署"
    echo "========================================"
    echo "📋 支持完整的 Kubernetes 集群部署流程"
    echo "🔧 每个步骤都有独立的资源检查和错误处理"
    echo "🌐 支持在线/离线两种部署模式"
    echo "========================================"
}

need(){ command -v "$1" >/dev/null 2>&1 || return 1; }

# 解析命令行参数（优先于配置文件加载，确保命令行参数优先级最高）
declare -a PARSED_ARGS

# 先解析命令行参数（如果提供）
# 保存原始参数，以便在 main 函数中使用
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    unified_parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

load_config(){
    local loaded=""
    if [[ -f "$PROJECT_ROOT/deploy-infrastructure-all/deploy-infrastructure-all.conf" ]]; then
        # shellcheck disable=SC1090
        source "$PROJECT_ROOT/deploy-infrastructure-all/deploy-infrastructure-all.conf"; loaded="deploy-infrastructure-all.conf"
    else
        log_error "未找到配置文件：deploy-infrastructure-all/deploy-infrastructure-all.conf"
        return 1
    fi
    
    # 集群选择逻辑（使用 CLUSTER，从环境变量、全局配置或默认值获取）
    # 注意：CLUSTER 已经在文件开头通过命令行参数解析设置，这里只作为后备
    # 如果 CLUSTER 未设置，尝试从全局配置读取
    if [[ -z "${CLUSTER:-}" ]]; then
        # 加载集群配置映射函数（如果尚未加载）
        if [[ ! "$(type -t get_default_cluster)" == "function" ]]; then
            if [[ -f "$PROJECT_ROOT/../../utils/cluster-config-mapping.sh" ]]; then
                source "$PROJECT_ROOT/../../utils/cluster-config-mapping.sh"
            fi
        fi
        # 从全局配置读取默认集群（支持 C1/C2/.../KIND）
        if command -v get_default_cluster &>/dev/null; then
            export CLUSTER=$(get_default_cluster)
        fi
    fi
    local cluster_selected="${CLUSTER:-C1}"
    # 验证集群值格式：必须是 C{数字} 格式（如 C1, C2, C3, C10 等）
    # 支持不连续的集群编号（如只有 C1 和 C3，没有 C2）
    if [[ ! "$cluster_selected" =~ ^C[0-9]+$ ]]; then
        log_error "无效的集群值: $cluster_selected (格式必须为 C{数字}，如 C1, C2, C3 等)"
        return 1
    fi
    
    log_info "🎯 使用集群配置: $cluster_selected"
    
    # 将 C*_SERVER_n_* 变量映射到 SERVER_n_*
    # 支持所有可能的字段：TYPE, PUBLIC_IP, LOCAL_IP, USER, SECRET, PASS, SSH_PORT, DIR, 
    #                     CURRENT_HOSTNAME, CLUSTER_HOSTNAME, EXTRA_LABELS, TAINTS
    local server_num=1
    local cluster_prefix="${cluster_selected}_"
    
    while true; do
        # 检查是否存在对应集群的 SERVER_n_PUBLIC_IP（作为判断是否有该节点的依据）
        local cluster_pub_ip_var="${cluster_prefix}SERVER_${server_num}_PUBLIC_IP"
        
        if [[ -z "${!cluster_pub_ip_var:-}" ]]; then
            # 该节点不存在，停止映射
            break
        fi
        
        # 映射所有字段
        local fields=("TYPE" "PUBLIC_IP" "LOCAL_IP" "USER" "SECRET" "PASS" "SSH_PORT" "DIR" 
                      "CURRENT_HOSTNAME" "CLUSTER_HOSTNAME" "EXTRA_LABELS" "TAINTS")
        
        for field in "${fields[@]}"; do
            local cluster_var="${cluster_prefix}SERVER_${server_num}_${field}"
            local server_var="SERVER_${server_num}_${field}"
            
            if [[ -n "${!cluster_var:-}" ]]; then
                # 使用间接变量赋值
                eval "$server_var=\"${!cluster_var}\""
            fi
        done
        
        server_num=$((server_num+1))
    done
    
    # 清空后续的 SERVER_n_* 变量（如果有的话）
    local check_var_name="SERVER_${server_num}_PUBLIC_IP"
    while [[ -n "${!check_var_name:-}" ]]; do
        local fields=("TYPE" "PUBLIC_IP" "LOCAL_IP" "USER" "SECRET" "PASS" "SSH_PORT" "DIR" 
                      "CURRENT_HOSTNAME" "CLUSTER_HOSTNAME" "EXTRA_LABELS" "TAINTS")
        for field in "${fields[@]}"; do
            eval "unset SERVER_${server_num}_${field}"
        done
        server_num=$((server_num+1))
        check_var_name="SERVER_${server_num}_PUBLIC_IP"
    done
    
    # 应用集群配置映射（使用 utils 中的通用函数）
    if [[ -f "$PROJECT_ROOT/../../utils/cluster-config-mapping.sh" ]]; then
      source "$PROJECT_ROOT/../../utils/cluster-config-mapping.sh"
      apply_cluster_config_mapping "$cluster_selected"
    fi
    
    log_success "已加载配置：$loaded (集群: $cluster_selected, 节点数: $((server_num-1)))"
}

# 检查步骤脚本是否存在
check_step_script(){
    local step="$1"
    local script="$STEPS_DIR/$step"
    if [[ ! -f "$script" ]]; then
        log_error "步骤脚本不存在: $script"
        return 1
    fi
    if [[ ! -x "$script" ]]; then
        log_error "步骤脚本无执行权限: $script"
        return 1
    fi
    return 0
}

# 执行步骤
execute_step(){
    local step="$1"
    local description="$2"
    
    log_info "开始执行: $description"
    log_info "脚本: $STEPS_DIR/$step"
    
    if ! check_step_script "$step"; then
        return 1
    fi
    
    if bash "$STEPS_DIR/$step"; then
        log_success "$description 执行完成"
        return 0
    else
        log_error "$description 执行失败"
        return 1
    fi
}

# 步骤执行函数
step12_ca_generation(){
    load_config || return 1
    execute_step "step12_ca_generation.sh" "统一根 CA 证书生成/轮换"
}

step00_reset(){
    load_config || return 1
    execute_step "step00_reset.sh" "重置集群（清理所有组件）"
}

step01_os_baseline(){
    load_config || return 1
    execute_step "step01_os_baseline.sh" "操作系统基线配置"
}

step02_runtime(){
    load_config || return 1
    execute_step "step02_runtime.sh" "容器运行时安装（containerd + nerdctl）"
}

step03_k8s_binaries(){
    load_config || return 1
    execute_step "step03_k8s_binaries.sh" "Kubernetes 二进制文件安装"
}

step04_kubeadm_init(){
    load_config || return 1
    execute_step "step04_kubeadm_init.sh" "Master 节点初始化（kubeadm init）"
}

step05_cni_install(){
    load_config || return 1
    execute_step "step05_cni_install.sh" "CNI 网络插件安装（Calico）"
}

step06_join_nodes(){
    load_config || return 1
    execute_step "step06_join_nodes.sh" "Worker 节点加入集群"
}

step07_create_namespaces(){
    load_config || return 1
    execute_step "step07_create_namespaces.sh" "命名空间管理"
}

step08_validate(){
    load_config || return 1
    execute_step "step08_validate.sh" "集群验证和状态检查"
}

step09_storage(){
    load_config || return 1
    execute_step "step09_storage.sh" "存储配置（本地存储 + NFS存储）"
}

step10_k8s_nodes_management(){
    load_config || return 1
    execute_step "step10_k8s_nodes_management.sh" "Kubernetes节点管理"
}

step11_load_initial_images(){
    load_config || return 1
    execute_step "step11_load-initial-images.sh" "初始镜像加载"
}

step13_ingress_and_harbor(){
    load_config || return 1
    execute_step "step13_ingress_and_harbor.sh" "Ingress (Traefik) 与 Harbor 部署"
}

# 完整部署流程
deploy_all(){
    log_info "开始完整部署流程..."
    echo ""
    
    # 加载配置以获取开关状态
    load_config || return 1
    
    # 定义所有步骤及其开关（按执行顺序）
    local steps=(
        "step00_reset:集群重置:STEP00_ENABLED"
        "step01_os_baseline:操作系统基线配置:STEP01_ENABLED"
        "step02_runtime:容器运行时安装:STEP02_ENABLED"
        "step03_k8s_binaries:Kubernetes二进制文件安装:STEP03_ENABLED"
        "step04_kubeadm_init:Master节点初始化:STEP04_ENABLED"
        "step05_cni_install:CNI网络插件安装:STEP05_ENABLED"
        "step06_join_nodes:Worker节点加入集群:STEP06_ENABLED"
        "step07_create_namespaces:命名空间管理:STEP07_ENABLED"
        "step08_validate:集群验证和状态检查:STEP08_ENABLED"
        "step09_storage:存储配置:STEP09_ENABLED"
        "step10_k8s_nodes_management:Kubernetes节点管理:STEP10_ENABLED"
        "step11_load-initial-images:初始镜像加载:STEP11_ENABLED"
        "step12_ca_generation:统一根 CA 证书生成/轮换:STEP12_ENABLED"
        "step13_ingress_and_harbor:Ingress (Traefik) 与 Harbor 部署:STEP13_ENABLED"
    )
    
    # 部署前：同步离线包至各节点（如存在包准备脚本）
    if [[ "${PACKAGE_SYNC_ENABLED:-true}" == "true" ]]; then
        # 尝试多个可能的路径（PROJECT_ROOT 指向 infrastructure 目录）
        local sync_script=""
        if [[ -x "$PROJECT_ROOT/utils/package-preparation/package-sync.sh" ]]; then
            sync_script="$PROJECT_ROOT/utils/package-preparation/package-sync.sh"
        elif [[ -x "$SCRIPT_DIR/../utils/package-preparation/package-sync.sh" ]]; then
            sync_script="$SCRIPT_DIR/../utils/package-preparation/package-sync.sh"
        elif [[ -x "$THIS_DIR/../utils/package-preparation/package-sync.sh" ]]; then
            sync_script="$THIS_DIR/../utils/package-preparation/package-sync.sh"
        fi
        
        if [[ -n "$sync_script" ]]; then
            log_info "执行离线包同步（all）..."
            # 确保 CLUSTER 环境变量被传递到包同步脚本
            CLUSTER="${CLUSTER:-C1}" "$sync_script" sync-packages-to-all-nodes all || log_warn "离线包同步返回非零，继续部署"
        else
            log_warn "包同步脚本不存在或无可执行权限，跳过包同步"
            log_warn "  尝试的路径："
            log_warn "    - $PROJECT_ROOT/utils/package-preparation/package-sync.sh"
            log_warn "    - $SCRIPT_DIR/../utils/package-preparation/package-sync.sh"
            log_warn "    - $THIS_DIR/../utils/package-preparation/package-sync.sh"
        fi
    else
        log_error "本次部署，没有把本地安装包同步到远程各节点！"
    fi

    # 执行所有启用的步骤
    for step_info in "${steps[@]}"; do
        local step_name="${step_info%%:*}"
        local step_desc="${step_info#*:}"
        local step_desc="${step_desc%:*}"
        local step_enabled_var="${step_info##*:}"
        
        # 检查步骤是否启用
        if [[ "${!step_enabled_var:-true}" == "true" ]]; then
            echo ""
            log_info "执行步骤: $step_desc"
            if ! bash "$STEPS_DIR/$step_name.sh"; then
                log_error "步骤执行失败: $step_desc"
                log_error "请检查错误信息并手动修复后重新运行"
                return 1
            fi
            log_success "步骤完成: $step_desc"
        else
            log_info "跳过步骤: $step_desc (已禁用)"
        fi
    done
    
    # 部署后：可选清理各节点包文件（如需要可在此处调用 cleanup-node-packages）
    # 示例（按需开启）：
    # if [[ -x "$PROJECT_ROOT/utils/package-preparation/package-sync.sh" ]]; then
    #     log_info "部署完成，清理各节点包文件（可选）..."
    #     # 这里若需全量清理可扩展 package-sync.sh 增加批量清理命令
    # fi

    log_success "🎉 完整部署流程执行完成！"
    log_info "请使用以下命令验证集群状态："
    echo "  kubectl get nodes"
    echo "  kubectl get pods -A"
}

# 显示步骤状态
show_step_status(){
    log_info "检查各步骤脚本状态..."
    echo ""
    
    local steps=(
        "step12_ca_generation.sh:统一根 CA 证书生成/轮换"
        "step00_reset.sh:重置集群"
        "step01_os_baseline.sh:操作系统基线"
        "step02_runtime.sh:容器运行时"
        "step03_k8s_binaries.sh:K8s二进制文件"
        "step04_kubeadm_init.sh:Master初始化"
        "step05_cni_install.sh:CNI网络插件"
        "step06_join_nodes.sh:节点加入"
        "step07_create_namespaces.sh:命名空间管理"
        "step08_validate.sh:集群验证"
        "step09_storage.sh:存储配置"
        "step10_k8s_nodes_management.sh:Kubernetes节点管理"
        "step11_load-initial-images.sh:初始镜像加载"
        "step13_ingress_and_harbor.sh:Ingress (Traefik) 与 Harbor 部署"
    )
    
    for step_info in "${steps[@]}"; do
        local step_file="${step_info%%:*}"
        local step_desc="${step_info##*:}"
        local step_path="$STEPS_DIR/$step_file"
        
        if [[ -f "$step_path" ]]; then
            if [[ -x "$step_path" ]]; then
                log_success "✅ $step_file - $step_desc"
            else
                log_warn "⚠️  $step_file - $step_desc (无执行权限)"
            fi
        else
            log_error "❌ $step_file - $step_desc (文件不存在)"
        fi
    done
}

# 解析命令行参数（支持 --cluster 或 -c）
main(){
    banner
    
    # 检查必要工具
    if ! need bash; then
        log_error "bash 未安装"
        exit 1
    fi
    
    # 检查项目结构
    if [[ ! -d "$STEPS_DIR" ]]; then
        log_error "步骤脚本目录不存在: $STEPS_DIR"
        exit 1
    fi
    
    # 使用解析后的参数（已移除 --cluster 参数）
    set -- "${ORIGINAL_ARGS[@]}"
    
    # 显示当前集群配置（如果设置了）
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    # 加载配置（注意：必须在解析参数后调用，因为 load_config 会读取 CLUSTER）
    if ! load_config; then
        log_error "配置加载失败，请检查配置文件"
        exit 1
    fi
    
    # 命令行参数处理
    if [[ $# -gt 0 ]]; then
        case "$1" in
            full|deploy|all) deploy_all ;;
            help|--help|-h)
                echo "用法: $0 [--cluster C1|C2] [命令]"
                echo ""
                echo "参数:"
                echo "  --cluster, -c   集群选择 (格式：C{数字}，如 C1, C2, C3 等)，也可以通过环境变量 CLUSTER 设置"
                echo ""
                echo "命令:"
                echo "  full, deploy, all  完整部署流程（默认）"
                echo "  help               显示此帮助"
                echo ""
                echo "示例:"
                echo "  $0 --cluster C1 deploy"
                echo "  $0 -c C2 deploy"
                echo "  CLUSTER=C1 $0 deploy"
                echo ""
                echo "注意：重置功能通过配置文件中的 STEP00_ENABLED 参数控制"
                ;;
            *) log_error "未知命令: $1"; exit 1 ;;
        esac
    else
        # 默认执行完整部署流程
        log_info "未指定命令，执行完整部署流程"
        deploy_all
    fi
}

main "$@"



