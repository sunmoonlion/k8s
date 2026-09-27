#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Kubernetes 基础设施部署脚本
# 云上升级路径未经实机验证；详见 ../docs/infrastructure-upgrade-audit.md。
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
K8S_ROOT_DIR=""
search_dir="$THIS_DIR"
while [[ "$search_dir" != "/" ]]; do
    if [[ -f "$search_dir/utils/cluster-arg-parser.sh" ]]; then
        K8S_ROOT_DIR="$search_dir"
        break
    fi
    search_dir="$(dirname "$search_dir")"
done
if [[ -z "$K8S_ROOT_DIR" ]]; then
    echo "[ERROR] 无法定位 k8s 根目录（未找到 utils/cluster-arg-parser.sh），THIS_DIR=$THIS_DIR" 1>&2
    exit 1
fi

# 集群参数解析（轻量，无连接副作用）
# shellcheck source=/dev/null
source "$K8S_ROOT_DIR/utils/cluster-arg-parser.sh"


# 变量路径
SCRIPT_DIR="$PROJECT_ROOT"
STEPS_DIR="$SCRIPT_DIR/steps"

# 总控、菜单和只打印预演共用此顺序；重置不属于部署。
DEPLOY_STEPS=(
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
    "step12_ca_generation:校验并安装已签发入口证书:STEP12_ENABLED"
    "step13_ingress_and_harbor:Ingress (Traefik) 部署（Harbor 在集群外）:STEP13_ENABLED"
)

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

# shellcheck source=/dev/null
source "$PROJECT_ROOT/utils/config.sh"
load_config(){
    infra_load_config
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
    local -a step_args=()
    case "$step" in
        step01_os_baseline.sh|step02_runtime.sh|step03_k8s_binaries.sh|step04_kubeadm_init.sh|step05_cni_install.sh|step06_join_nodes.sh|step07_create_namespaces.sh|step08_validate.sh|step09_storage.sh|step10_k8s_nodes_management.sh|step11_load-initial-images.sh|step12_ca_generation.sh)
            step_args=(--apply) ;;
    esac
    
    log_info "开始执行: $description"
    log_info "脚本: $STEPS_DIR/$step"
    
    if ! check_step_script "$step"; then
        return 1
    fi
    
    if bash "$STEPS_DIR/$step" "${step_args[@]}"; then
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
    execute_step "step12_ca_generation.sh" "校验并安装已签发入口证书"
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
    execute_step "step09_storage.sh" "存储配置（固定离线物料与独立数据盘）"
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
    execute_step "step13_ingress_and_harbor.sh" "Ingress (Traefik) 部署（Harbor 在集群外）"
}

# 安装必须使用新锁且依赖闭包已完整；不能因旧脚本尚在就静默跑旧版本。
require_deployment_materials(){
    python3 "$PROJECT_ROOT/materials/bundle.py" verify \
        --root "${INFRA_MATERIAL_ROOT:-$HOME/packages-to-be-installed}" \
        --expected-kubernetes "${STEP03_K8S_VERSION:-${CLUSTER_VERSION:-unset}}" \
        --require-complete >/dev/null
}

# 完整部署流程
deploy_all(){
    log_info "开始完整部署流程..."
    echo ""
    
    # 加载配置以获取开关状态，所有远端操作前完成物料准入。
    load_config || return 1
    require_deployment_materials || return 1

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
            log_info "执行锁定集群物料精确同步..."
            # 确保 CLUSTER 环境变量被传递到包同步脚本
            if ! CLUSTER="$CLUSTER" bash "$sync_script" sync-cluster-materials --apply; then
                log_error "离线包同步失败，停止部署"
                return 1
            fi
        else
            log_error "启用了包同步，但包同步脚本不存在或无可执行权限，停止部署"
            log_warn "  尝试的路径："
            log_warn "    - $PROJECT_ROOT/utils/package-preparation/package-sync.sh"
            log_warn "    - $SCRIPT_DIR/../utils/package-preparation/package-sync.sh"
            log_warn "    - $THIS_DIR/../utils/package-preparation/package-sync.sh"
            return 1
        fi
    else
        log_info "包同步已禁用；各步骤仍须检查目标节点的离线物料"
    fi

    # 执行所有启用的步骤
    for step_info in "${DEPLOY_STEPS[@]}"; do
        local step_name="${step_info%%:*}"
        local step_desc="${step_info#*:}"
        local step_desc="${step_desc%:*}"
        local step_enabled_var="${step_info##*:}"
        
        # 检查步骤是否启用
        if [[ "${!step_enabled_var:-true}" == "true" ]]; then
            echo ""
            log_info "执行步骤: $step_desc"
            if ! execute_step "$step_name.sh" "$step_desc"; then
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

# 执行单个步骤（命令名可用下划线或连字符，如 step11_load_initial_images / step11_load-initial-images）
run_single_step(){
    local cmd="${1//-/_}"
    if [[ "$cmd" == step00_reset ]]; then
        log_error "历史 reset 不属于本次升级入口；受保护节点/卷不可清理"
        return 1
    fi
    require_deployment_materials || return 1
    case "$cmd" in
        step00_reset|step01_os_baseline|step02_runtime|step03_k8s_binaries|step04_kubeadm_init|step05_cni_install|step06_join_nodes|step07_create_namespaces|step08_validate|step09_storage|step10_k8s_nodes_management|step11_load_initial_images|step12_ca_generation|step13_ingress_and_harbor)
            "$cmd"
            return $?
            ;;
    esac
    log_error "未知命令: $1"
    log_info "提示: 单步命令使用下划线，例如 step11_load_initial_images"
    log_info "或直接执行: CLUSTER=${CLUSTER:-C1} bash $STEPS_DIR/step11_load-initial-images.sh"
    return 1
}

# 显示步骤状态
show_step_status(){
    log_info "检查各步骤脚本状态..."
    echo ""
    
    local steps=(
        "step12_ca_generation.sh:校验并安装已签发入口证书"
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
        "step13_ingress_and_harbor.sh:Ingress (Traefik) 部署（Harbor 在集群外）"
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

# 只打印当前总控调用顺序；不调用任何步骤或同步脚本。
show_deployment_plan(){
    local info name enabled flag
    echo "[dry-run] 云上升级路径未经实机验证；本输出不表示新版已经可部署。"
    echo "cluster=$CLUSTER configured_kubernetes=${CLUSTER_VERSION:-unset}"
    echo "material_target=1.36.4; adapter/status=参见 docs/infrastructure-upgrade-audit.md"
    echo "package_sync=${PACKAGE_SYNC_ENABLED:-true}"
    for info in "${DEPLOY_STEPS[@]}"; do
        name="${info%%:*}"
        flag="${info##*:}"
        enabled="${!flag:-true}"
        printf '[dry-run] enabled=%s bash %q\n' "$enabled" "$STEPS_DIR/$name.sh"
    done
    echo "[dry-run] 实际执行前必须核对部署版本与物料锁一致、closure_complete=true；当前适配未完成。"
    echo "[dry-run] 不含 step00；未连接 SSH、未同步物料、未修改集群或容器。"
    echo "[dry-run] 独立 Harbor 前置步骤和统一平台调用链仍待接入，不可据此宣称迁移完成。"
}

usage(){
    echo "用法: $0 --cluster C1 [deploy|status|materials|stepNN_name] [--dry-run]"
    echo "无参数显示帮助；总控不自动调用 step00/清理。其他旧步骤仍待整改，禁止用于本次迁移。云上升级路径未经实机验证。"
    echo "deploy --dry-run 只打印当前调用顺序；单步 --dry-run 只打印目标脚本。"
}

main(){
    local action="" dry_run=false arg
    for arg in "${ORIGINAL_ARGS[@]}"; do
        case "$arg" in
            --dry-run) dry_run=true ;;
            *)
                [[ -z "$action" ]] || { log_error "多余参数: $arg"; return 1; }
                action="$arg"
                ;;
        esac
    done
    case "$action" in
        ""|help|--help|-h) usage; return 0 ;;
    esac
    [[ "${CLUSTER:-}" =~ ^C[0-9]+$ ]] || { log_error "必须用 --cluster Cn 或 CLUSTER=Cn 显式指定目标集群"; return 1; }
    load_config || return 1
    case "$action" in
        full|deploy|all)
            if [[ "$dry_run" == true ]]; then show_deployment_plan; else deploy_all; fi
            ;;
        status|steps) show_step_status ;;
        materials)
            python3 "$PROJECT_ROOT/materials/bundle.py" verify --root "${INFRA_MATERIAL_ROOT:-$HOME/packages-to-be-installed}"
            ;;
        step*)
            if [[ "$dry_run" == true ]]; then
                # 与实际执行使用同一白名单；预演不调用步骤。
                local command_name="${action//-/_}"
                case "$command_name" in
                    step00_reset|step01_os_baseline|step02_runtime|step03_k8s_binaries|step04_kubeadm_init|step05_cni_install|step06_join_nodes|step07_create_namespaces|step08_validate|step09_storage|step10_k8s_nodes_management|step11_load_initial_images|step12_ca_generation|step13_ingress_and_harbor)
                        printf '[dry-run] cluster=%s step=%s; 未执行；云上升级路径未经实机验证\n' "$CLUSTER" "$command_name" ;;
                    *) log_error "未知步骤: $action"; return 1 ;;
                esac
            else
                run_single_step "$action"
            fi
            ;;
        *) log_error "未知命令: $action"; return 1 ;;
    esac
}

main "$@"
