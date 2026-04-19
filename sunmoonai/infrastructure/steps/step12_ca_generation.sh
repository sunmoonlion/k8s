#!/usr/bin/env bash
#
# Step12: CA Certificate Generation & Rotation
# 功能：检查并生成统一根 CA 证书（如果不存在），支持强制重建与轮换
# 
# 作者：AI Assistant
# 日期：2025
# 版本：1.1
#
# 说明：
# - 如果 CA 已存在且未开启强制/轮换，则跳过生成
# - 支持 STEP12_FORCE_REGENERATE=true 强制重建（删除旧CA后重建）
# - 支持 STEP12_CA_ROTATE=true 轮换（备份旧CA到 backup/ 并生成新CA）
# - 轮换后需要：重新签发各服务证书、分发新CA到所有需要信任的节点
#

set -euo pipefail

# 加载通用函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 加载配置
if [[ -f "$PROJECT_ROOT/deploy-infrastructure-all/deploy-infrastructure-all.conf" ]]; then
    source "$PROJECT_ROOT/deploy-infrastructure-all/deploy-infrastructure-all.conf"
elif [[ -f "$PROJECT_ROOT/config/deploy.conf" ]]; then
    source "$PROJECT_ROOT/config/deploy.conf"
elif [[ -f "$PROJECT_ROOT/config/cluster.conf" ]]; then
    source "$PROJECT_ROOT/config/cluster.conf"
fi

# 计算项目根目录（k8s目录）
# PROJECT_ROOT 是 infrastructure/，需要向上两级到 k8s/
# 路径：infrastructure/ -> sunmoonai/ -> k8s/（两级）
K8S_ROOT="$(cd "$PROJECT_ROOT/../.." && pwd)"

# 加载通用工具函数（获取 SSH 执行函数）
if [[ -f "$PROJECT_ROOT/utils/common.sh" ]]; then
    source "$PROJECT_ROOT/utils/common.sh"
fi

# 加载集群配置映射函数（用于将 C1_SERVER_* 或 C2_SERVER_* 映射为 SERVER_*）
if [[ -f "$K8S_ROOT/utils/cluster-config-mapping.sh" ]]; then
    source "$K8S_ROOT/utils/cluster-config-mapping.sh"
    # 应用集群配置映射（使用 CLUSTER 环境变量）
    if command -v apply_cluster_config_mapping &>/dev/null; then
        apply_cluster_config_mapping
    fi
fi

# 注意：CA 分发功能已由 unified-cert-secret-management 处理，不再需要 ca-management

# 颜色输出函数
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }

# 日志函数
log_info() { echo -e "$(blue "[INFO]") $*"; }
log_success() { echo -e "$(green "[SUCCESS]") $*"; }
log_warn() { echo -e "$(yellow "[WARN]") $*"; }
log_error() { echo -e "$(red "[ERROR]") $*"; }

# 预检函数
precheck() {
    log_info "[Step12] 预检：统一根 CA 证书生成/轮换"
    
    # 检查配置
    if [[ "${STEP12_ENABLED:-true}" != "true" ]]; then
        log_info "Step12 已禁用，跳过执行"
        exit 0
    fi
    
    # 检查证书生成工具是否存在
    if ! command -v openssl &>/dev/null; then
        log_error "未找到 openssl 命令，请先安装"
        return 1
    fi
    
    # 检查 unified-cert-secret-management 是否存在
    local unified_cert_dir="$K8S_ROOT/utils/unified-cert-secret-management"
    if [[ ! -d "$unified_cert_dir" ]]; then
        log_error "unified-cert-secret-management 目录不存在: $unified_cert_dir"
        log_error "请确保 unified-cert-secret-management 模块已正确安装"
        return 1
    fi
    
    local deploy_script="$unified_cert_dir/deploy-all.sh"
    if [[ ! -f "$deploy_script" ]]; then
        log_error "deploy-all.sh 不存在: $deploy_script"
        return 1
    fi
    
    if [[ ! -x "$deploy_script" ]]; then
        log_warn "deploy-all.sh 无执行权限，尝试添加执行权限"
        chmod +x "$deploy_script" || {
            log_error "无法添加执行权限: $deploy_script"
            return 1
        }
    fi
    
    log_info "[Step12] 预检通过"
}

# 确保资源函数
ensure_resources() {
    log_info "[Step12] 确保资源：检查 unified-cert-secret-management"
    # 资源由 unified-cert-secret-management 自动管理，无需手动创建目录
    return 0
}

# 执行函数
execute() {
    log_info "[Step12] 执行：调用 unified-cert-secret-management 生成和分发 CA 证书（init 模式）"
    
    # 检查 unified-cert-secret-management 是否存在
    local unified_cert_dir="$K8S_ROOT/utils/unified-cert-secret-management"
    if [[ ! -d "$unified_cert_dir" ]]; then
        log_error "[Step12] unified-cert-secret-management 目录不存在: $unified_cert_dir"
        return 1
    fi
    
    local deploy_script="$unified_cert_dir/deploy-all.sh"
    if [[ ! -f "$deploy_script" ]]; then
        log_error "[Step12] deploy-all.sh 不存在: $deploy_script"
        return 1
    fi
    
    # 设置 init 模式并调用 unified-cert-secret-management
    log_info "[Step12] 使用 unified-cert-secret-management 的 init 模式生成和分发 CA 证书"
    
    # 构建命令行参数
    local script_args=()
    
    # 传递集群配置（使用 CLUSTER）
    if [[ -n "${CLUSTER:-}" ]]; then
        script_args+=("--cluster" "${CLUSTER}")
        log_info "[Step12] 使用集群配置: CLUSTER=${CLUSTER}"
    fi
    
    # 强制重建模式映射为 force
    if [[ "${STEP12_FORCE_REGENERATE:-false}" == "true" ]]; then
        script_args+=("force")
        log_warn "[Step12] 启用强制重建模式（映射为 force）"
    elif [[ "${STEP12_CA_ROTATE:-false}" == "true" ]]; then
        script_args+=("rotate")
        log_warn "[Step12] 启用轮换模式（映射为 rotate）"
    else
        script_args+=("init")
    fi
    
    # 调用 unified-cert-secret-management
    cd "$unified_cert_dir" || {
        log_error "[Step12] 无法切换到目录: $unified_cert_dir"
        return 1
    }
    
    if bash "$deploy_script" "${script_args[@]}"; then
        log_success "[Step12] CA 证书生成和分发完成（通过 unified-cert-secret-management）"
    else
        log_error "[Step12] CA 证书生成和分发失败"
        return 1
    fi

    # force 模式重新生成了 CA，必须同步分发到所有其他共用此 Harbor 的集群
    # 否则这些集群的 nerdctl 将因 CA 不一致而无法验证 Harbor TLS
    # 配置方式：在 deploy-infrastructure-all.conf 中设置
    #   STEP12_ADDITIONAL_CLUSTERS="C2"        # 单个额外集群
    #   STEP12_ADDITIONAL_CLUSTERS="C2,C3"     # 多个额外集群
    if [[ "${STEP12_FORCE_REGENERATE:-false}" == "true" || "${STEP12_CA_ROTATE:-false}" == "true" ]]; then
        local additional_clusters="${STEP12_ADDITIONAL_CLUSTERS:-}"
        if [[ -n "$additional_clusters" ]]; then
            IFS=',' read -ra EXTRA_CLUSTERS <<< "$additional_clusters"
            for extra_cluster in "${EXTRA_CLUSTERS[@]}"; do
                extra_cluster="${extra_cluster// /}"  # 去除空格
                [[ -z "$extra_cluster" ]] && continue
                log_info "[Step12] 将新 CA 分发到额外集群: $extra_cluster"
                if CLUSTER="$extra_cluster" bash "$deploy_script" --cluster "$extra_cluster" init; then
                    log_success "[Step12] CA 已同步到集群 $extra_cluster"
                else
                    log_error "[Step12] CA 同步到集群 $extra_cluster 失败，请手动执行: CLUSTER=$extra_cluster bash $deploy_script init"
                    return 1
                fi
            done
        else
            log_warn "[Step12] force/rotate 模式：如有其他集群共用此 Harbor（如 C2），请配置 STEP12_ADDITIONAL_CLUSTERS 或手动执行: CLUSTER=C2 bash $deploy_script init"
        fi
    fi

    return 0
}

# 验证函数：校验本地归档 CA 与 K8s 部署的 CA 一致，防止 CA 分叉
verify() {
    log_info "[Step12] 验证：校验本地归档 CA 与 K8s secret 一致性"

    local sync_script="$K8S_ROOT/utils/unified-cert-secret-management/scripts/sync-ca-from-k8s.sh"
    if [[ ! -f "$sync_script" ]]; then
        log_warn "[Step12] 未找到 sync-ca-from-k8s.sh，跳过一致性校验"
        return 0
    fi

    local ca_dir="${TRAEFIK_K1_K1_LOCAL_CA_CERT_DIR:-}"
    ca_dir="${ca_dir/#\~/$HOME}"
    if [[ -z "$ca_dir" || ! -f "$ca_dir/ca.crt" ]]; then
        log_warn "[Step12] 本地归档 CA 不存在，跳过一致性校验"
        return 0
    fi

    # 调用 sync 脚本做只读验证（不写入，只比对）
    local secret_name="${TRAEFIK_K1_K1_CA_VALIDATE_SECRET_NAME:-traefik-tls-secret}"
    local secret_ns="${TRAEFIK_K1_K1_CA_VALIDATE_SECRET_NAMESPACE:-ingress-platform-dev}"
    local server_host="${TRAEFIK_K1_K1_SERVER_HOST:-}"
    local server_port="${TRAEFIK_K1_K1_SERVER_PORT:-1022}"
    local server_user="${TRAEFIK_K1_K1_SERVER_USERNAME:-zym}"
    local server_key="${TRAEFIK_K1_K1_SERVER_SSH_KEY:-~/.ssh/id_rsa}"
    server_key="${server_key/#\~/$HOME}"

    if [[ -z "$server_host" ]]; then
        log_warn "[Step12] 未配置 SERVER_HOST，跳过 K8s CA 一致性校验"
        return 0
    fi

    local k8s_fp
    k8s_fp=$(ssh -i "$server_key" -p "$server_port" -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
        "${server_user}@${server_host}" \
        "kubectl get secret ${secret_name} -n ${secret_ns} -o jsonpath='{.data.ca\.crt}' 2>/dev/null | base64 -d | openssl x509 -noout -fingerprint -sha256 2>/dev/null" 2>/dev/null || echo "")

    if [[ -z "$k8s_fp" ]]; then
        log_warn "[Step12] 无法从 K8s 获取 CA 指纹（可能集群未就绪），跳过校验"
        return 0
    fi

    local local_fp
    local_fp=$(openssl x509 -noout -fingerprint -sha256 -in "$ca_dir/ca.crt" 2>/dev/null || echo "")

    if [[ "$local_fp" != "$k8s_fp" ]]; then
        log_error "[Step12] CA 不一致！本地归档与 K8s 部署的 CA 指纹不同："
        log_error "  本地归档: $local_fp"
        log_error "  K8s secret: $k8s_fp"
        log_error "请先运行以下命令同步本地归档，再重新执行 Step12："
        log_error "  bash $sync_script --combo TRAEFIK_K1_K1"
        return 1
    fi

    log_info "[Step12] CA 一致性校验通过（本地归档与 K8s 指纹一致）"
    return 0
}

# CA 分发函数
distribute_ca() {
    log_info "[Step12] 分发：由 unified-cert-secret-management 处理"
    # CA 分发由 unified-cert-secret-management 在 init 模式下自动处理，此处无需重复分发
    return 0
}

# 主函数
main() {
    local action="${1:-all}"
    case "$action" in
        precheck)
            precheck
            ;;
        ensure)
            precheck || exit 1
            ensure_resources
            ;;
        execute)
            precheck || exit 1
            ensure_resources || exit 1
            execute
            ;;
        verify)
            verify
            ;;
        all)
            precheck || exit 1
            ensure_resources || exit 1
            execute || exit 1
            verify || exit 1
            distribute_ca || exit 1
            log_success "[Step12] CA 证书生成和分发完成（通过 unified-cert-secret-management）"
            ;;
        distribute)
            # 分发由 unified-cert-secret-management 处理，单独执行无意义
            log_info "[Step12] CA 分发由 unified-cert-secret-management 在 init 模式下自动处理"
            log_info "[Step12] 如需单独分发，请直接使用 unified-cert-secret-management"
            return 0
            ;;
        *)
            log_error "未知操作: $action"
            echo "用法: $0 [precheck|ensure|execute|verify|distribute|all]"
            exit 1
            ;;
    esac
}

main "$@"


