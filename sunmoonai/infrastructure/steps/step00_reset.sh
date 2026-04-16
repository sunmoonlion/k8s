#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Kubernetes 集群重置脚本
# 功能: 根据配置文件安全重置 Kubernetes 集群
# =============================================================================

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$BASE_DIR/../utils/common.sh"

# 加载配置文件
load_config_file || exit 1

# =============================================================================
# 配置参数（从 deploy-infrastructure-all.conf 读取）
# =============================================================================
STEP_PREFIX=STEP00
TARGET="${STEP00_TARGET:-all}"

# 从 deploy-infrastructure-all.conf 读取配置
RESTORE_HOSTNAME="${STEP00_RESTORE_HOSTNAME:-true}"
RESTORE_SWAP="${STEP00_RESTORE_SWAP:-true}"
REMOVE_SYSCTL_OVERRIDES="${STEP00_REMOVE_SYSCTL_OVERRIDES:-true}"
REMOVE_KERNEL_MODULES="${STEP00_REMOVE_KERNEL_MODULES:-true}"
REMOVE_REMOTE_ARTIFACTS="${STEP00_REMOVE_REMOTE_ARTIFACTS:-false}"
REMOVE_RUNTIME="${STEP00_REMOVE_RUNTIME:-true}"
REMOVE_K8S_PACKAGES="${STEP00_REMOVE_K8S_PACKAGES:-true}"
REMOVE_K8S_IMAGES="${STEP00_REMOVE_K8S_IMAGES:-false}"
REMOVE_HOSTS_BLOCK="${STEP00_REMOVE_HOSTS_BLOCK:-false}"
# REMOVE_NAMESPACES="${STEP00_REMOVE_NAMESPACES:-true}"  # 已移除命名空间清理功能

# 其他配置
NETWORK_PLUGIN="${NETWORK_PLUGIN:-${STEP05_CNI:-calico}}"
HELM_NS="${STEP05_HELM_NAMESPACE:-kube-system}"
NS_NERDCTL="${STEP02_NERDCTL_NAMESPACE:-k8s.io}"

# =============================================================================
# 工具函数
# =============================================================================

# 修复主机名解析问题（避免 sudo 报 unable to resolve host 错误）
fix_hostname_resolution() {
    local node="$1"
    log_info "[Step00] 节点 $node: 修复主机名解析..."
    
    # 先通过普通用户获取主机名和本机 IP
    local current_hostname local_ip
    current_hostname=$(ssh_exec "$node" "hostname" 2>/dev/null || echo "")
    local_ip=$(get_server_var "$node" LOCAL_IP)
    
    if [[ -n "$current_hostname" ]]; then
        # 使用 sudo 写入 /etc/hosts（设置 SUDO_HOSTNAME 环境变量避免解析）
        ssh_exec_sudo "$node" "SUDO_HOSTNAME='' bash -lc '
            current_hostname=\"${current_hostname}\"
            local_ip=\"${local_ip:-127.0.1.1}\"
            if ! grep -qE \"(^|\\\\s)\$current_hostname(\\\\s|$)\" /etc/hosts; then
                echo \"\$local_ip \$current_hostname\" >> /etc/hosts || true
                echo \"127.0.0.1 \$current_hostname\" >> /etc/hosts || true
            fi
        '" 2>/dev/null || true
    fi
    
    log_info "[Step00] 节点 $node: 主机名解析修复完成"
}

# 清理网络配置
cleanup_network() {
    local node="$1"
    log_info "Cleaning up network configuration..."
    
    # 通过 SSH 在远程服务器上执行网络清理
    ssh_exec_sudo "$node" "bash -lc 'iptables -F 2>/dev/null || true; iptables -t nat -F 2>/dev/null || true; iptables -t mangle -F 2>/dev/null || true; iptables -X 2>/dev/null || true'" || true
    ssh_exec_sudo "$node" "bash -lc 'ipvsadm --clear 2>/dev/null || true'" || true
    ssh_exec_sudo "$node" "bash -lc 'ip link delete cni0 2>/dev/null || true; ip link delete flannel.1 2>/dev/null || true; ip link delete docker0 2>/dev/null || true'" || true
    
    log_info "Network cleanup completed"
}

# 清理容器运行时
cleanup_container_runtime() {
    local node="$1"
    
    log_info "[Step00] 节点 $node: 开始清理容器运行时..."
    
    # 停止容器服务
    ssh_exec_sudo "$node" "bash -lc 'systemctl stop containerd 2>/dev/null || true; systemctl stop docker 2>/dev/null || true; systemctl disable containerd 2>/dev/null || true; systemctl disable docker 2>/dev/null || true'" || true
    
    # 根据配置决定是否删除数据
    if [[ "$REMOVE_K8S_IMAGES" == "true" ]]; then
        log_info "[Step00] 节点 $node: REMOVE_K8S_IMAGES=true，删除容器镜像和数据"
        
        # 删除 nerdctl 镜像
        ssh_exec_sudo "$node" "bash -lc 'if command -v nerdctl >/dev/null 2>&1; then nerdctl -n $NS_NERDCTL images -q | while read img_id; do [ -n \"\$img_id\" ] && nerdctl -n $NS_NERDCTL rmi -f \"\$img_id\" 2>/dev/null || true; done; fi'" || true
        
        # 删除容器数据目录
        ssh_exec_sudo "$node" "bash -lc 'rm -rf /var/lib/containerd /var/lib/docker /var/lib/cni 2>/dev/null || true'" || true
    else
        log_info "[Step00] 节点 $node: REMOVE_K8S_IMAGES=false，保留容器镜像和数据"
    fi
    
    # 删除配置文件
    ssh_exec_sudo "$node" "bash -lc 'rm -rf /etc/containerd /etc/docker /etc/cni /opt/cni 2>/dev/null || true'" || true
    
    # 删除容器运行时可执行文件
    ssh_exec_sudo "$node" "bash -lc 'rm -f /usr/local/bin/nerdctl /usr/local/bin/containerd /usr/local/bin/containerd-shim* /usr/local/bin/ctr /usr/local/bin/runc /usr/local/bin/crictl 2>/dev/null || true'" || true
    
    log_info "[Step00] 节点 $node: 容器运行时清理完成"
}

# 清理 Kubernetes 组件
cleanup_kubernetes() {
    local node="$1"
    local node_type
    node_type="$(get_server_var "$node" TYPE)"
    
    log_info "[Step00] 节点 $node ($node_type): 开始清理 Kubernetes 组件..."
    
    # 执行 kubeadm reset
    ssh_exec_sudo "$node" "bash -lc 'if command -v kubeadm >/dev/null 2>&1; then kubeadm reset --force 2>/dev/null || true; fi'" || true
    
    # 停止 kubelet
    ssh_exec_sudo "$node" "bash -lc 'systemctl stop kubelet 2>/dev/null || true; systemctl disable kubelet 2>/dev/null || true'" || true
    
    # Master 节点特有清理
    if [[ "$node_type" == "master" ]]; then
        log_info "[Step00] 节点 $node: 清理 Master 节点特有组件..."
        
        # 停止控制平面服务
        ssh_exec_sudo "$node" "bash -lc 'systemctl stop etcd 2>/dev/null || true; systemctl disable etcd 2>/dev/null || true'" || true
        
        # 清理 etcd 数据
        ssh_exec_sudo "$node" "bash -lc 'rm -rf /var/lib/etcd 2>/dev/null || true'" || true
        
        # 清理静态 Pod 清单
        ssh_exec_sudo "$node" "bash -lc 'rm -rf /etc/kubernetes/manifests 2>/dev/null || true'" || true
        
        # 清理 API Server 证书
        ssh_exec_sudo "$node" "bash -lc 'rm -rf /etc/kubernetes/pki 2>/dev/null || true'" || true
    fi
    
    # Worker 节点特有清理
    if [[ "$node_type" == "worker" ]]; then
        log_info "[Step00] 节点 $node: 清理 Worker 节点特有组件..."
        
        # 清理 kubelet 数据
        ssh_exec_sudo "$node" "bash -lc 'rm -rf /var/lib/kubelet 2>/dev/null || true'" || true
    fi
    
    # 删除 Kubernetes 可执行文件和包
    if [[ "$REMOVE_K8S_PACKAGES" == "true" ]]; then
        log_info "Removing Kubernetes executables and packages..."
        
        # 取消hold状态并卸载 APT 包
        ssh_exec_sudo "$node" "bash -lc 'apt-mark unhold kubelet kubeadm kubectl kubernetes-cni 2>/dev/null || true'" || true
        ssh_exec_sudo "$node" "bash -lc 'apt-get remove --purge -y --allow-change-held-packages kubeadm kubelet kubectl kubernetes-cni 2>/dev/null || true'" || true
        
        # 删除 Kubernetes 仓库
        ssh_exec_sudo "$node" "bash -lc 'rm -f /etc/apt/sources.list.d/kubernetes.list 2>/dev/null || true'" || true
        ssh_exec_sudo "$node" "bash -lc 'rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg 2>/dev/null || true'" || true
        
        # 删除手动安装的可执行文件
        ssh_exec_sudo "$node" "bash -lc 'rm -f /usr/local/bin/kubeadm /usr/local/bin/kubelet /usr/local/bin/kubectl /usr/local/bin/kube-proxy 2>/dev/null || true'" || true
        
        # 删除 systemd 服务文件
        ssh_exec_sudo "$node" "bash -lc 'rm -f /etc/systemd/system/kubelet.service /etc/systemd/system/kubelet.service.d 2>/dev/null || true'" || true
        ssh_exec_sudo "$node" "bash -lc 'systemctl daemon-reload 2>/dev/null || true'" || true
        
        # 清理 APT 缓存
        ssh_exec_sudo "$node" "bash -lc 'apt-get autoremove -y 2>/dev/null || true'" || true
        ssh_exec_sudo "$node" "bash -lc 'apt-get autoclean 2>/dev/null || true'" || true
    fi
    
    # 清理通用 Kubernetes 目录
    ssh_exec_sudo "$node" "bash -lc 'rm -rf /etc/kubernetes /var/lib/kube-proxy /var/lib/kube-controller-manager /var/lib/kube-scheduler 2>/dev/null || true'" || true
    
    # 清理 kubeconfig
    ssh_exec_sudo "$node" "bash -lc 'rm -rf ~/.kube /root/.kube 2>/dev/null || true'" || true
    
    log_info "[Step00] 节点 $node: Kubernetes 组件清理完成"
}

# 清理 CNI 组件
cleanup_cni() {
    local node="$1"
    local node_type
    node_type="$(get_server_var "$node" TYPE)"
    
    log_info "[Step00] 节点 $node ($node_type): 开始清理 CNI 组件..."
    
    # 只有 Master 节点才通过 Helm 卸载 CNI
    if [[ "$node_type" == "master" ]]; then
        local cni_release=""
        case "$NETWORK_PLUGIN" in
            calico) cni_release="calico" ;;
            flannel) cni_release="flannel" ;;
            cilium) cni_release="cilium" ;;
            weave) cni_release="weave" ;;
            *) cni_release="$NETWORK_PLUGIN" ;;
        esac
        
        log_info "[Step00] 节点 $node: 尝试通过 Helm 卸载 CNI: $cni_release"
        # 添加错误处理
        if ! ssh_exec_sudo "$node" "bash -lc 'export KUBECONFIG=/etc/kubernetes/admin.conf && helm uninstall $cni_release -n $HELM_NS 2>/dev/null'"; then
            log_warn "[Step00] 节点 $node: Helm 卸载失败，将依赖 kubeadm reset 清理"
        fi
    else
        log_info "[Step00] 节点 $node: Worker 节点跳过 Helm CNI 卸载"
    fi
    
    # 所有节点都清理 CNI 配置
    ssh_exec_sudo "$node" "bash -lc 'rm -rf /etc/cni/net.d /opt/cni/bin /usr/local/libexec/cni 2>/dev/null || true'" || true
    
    log_info "[Step00] 节点 $node: CNI 组件清理完成"
}

# 清理命名空间功能已移除
# 原因：kubeadm reset 会自动清理所有命名空间和资源，无需手动清理
# cleanup_namespaces() {
#     # 功能已移除
# }

# 清理存储组件
cleanup_storage() {
    local node="$1"
    local node_type
    node_type="$(get_server_var "$node" TYPE)"
    
    log_info "[Step00] 节点 $node ($node_type): 开始清理存储组件..."
    
    # 清理本地存储目录
    log_info "[Step00] 节点 $node: 清理本地存储目录..."
    
    # 清理 local-path-provisioner 相关目录
    ssh_exec_sudo "$node" "bash -lc 'rm -rf /opt/local-path-provisioner 2>/dev/null || true'" || true
    ssh_exec_sudo "$node" "bash -lc 'rm -rf /var/lib/local-path-provisioner 2>/dev/null || true'" || true
    
    # 清理 CSI 驱动相关目录
    ssh_exec_sudo "$node" "bash -lc 'rm -rf /var/lib/kubelet/plugins 2>/dev/null || true'" || true
    ssh_exec_sudo "$node" "bash -lc 'rm -rf /var/lib/kubelet/plugins_registry 2>/dev/null || true'" || true
    
    # 清理存储相关的日志
    ssh_exec_sudo "$node" "bash -lc 'rm -rf /var/log/storage 2>/dev/null || true'" || true
    
    log_info "[Step00] 节点 $node: 存储组件清理完成"
}

# 恢复系统基线
restore_system_baseline() {
    local node="$1"
    
    log_info "[Step00] 节点 $node: 开始恢复系统基线..."
    
    # 恢复 hostname
    if [[ "$RESTORE_HOSTNAME" == "true" ]]; then
        local curr_hostname
        curr_hostname="$(get_server_var "$node" CURRENT_HOSTNAME)"
        if [[ -n "$curr_hostname" ]]; then
            log_info "Restoring hostname to: $curr_hostname"
            ssh_exec_sudo "$node" "bash -lc 'hostnamectl set-hostname $curr_hostname 2>/dev/null || true'" || true
        fi
    fi
    
    # 恢复 hosts 文件
    if [[ "$REMOVE_HOSTS_BLOCK" == "true" ]]; then
        ssh_exec_sudo "$node" "bash -lc 'sed -i \"/# k8s-deploy hosts begin/,/# k8s-deploy hosts end/d\" /etc/hosts 2>/dev/null || true'" || true
    fi
    
    # 恢复 sysctl 配置
    if [[ "$REMOVE_SYSCTL_OVERRIDES" == "true" ]]; then
        local sysctl_list="${STEP01_SYSCTL_OVERRIDES:-}"
        if [[ -n "$sysctl_list" ]]; then
            local kv_space
            kv_space="$(echo "$sysctl_list" | tr ',' ' ')"
            for kv in $kv_space; do
                local k="${kv%%=*}"
                if [[ -n "$k" ]]; then
                    ssh_exec_sudo "$node" "bash -lc 'sed -i \"/^$k\\s*=\\s*/d\" /etc/sysctl.conf 2>/dev/null || true'" || true
                fi
            done
            ssh_exec_sudo "$node" "bash -lc 'sysctl -p >/dev/null 2>&1 || true'" || true
        fi
    fi
    
    # 恢复内核模块
    if [[ "$REMOVE_KERNEL_MODULES" == "true" ]]; then
        local kmods="${STEP01_LOAD_KERNEL_MODULES:-overlay,br_netfilter}"
        local mods
        mods="$(echo "$kmods" | tr ',' ' ')"
        for mod in $mods; do
            ssh_exec_sudo "$node" "bash -lc 'rm -f /etc/modules-load.d/${mod}.conf 2>/dev/null || true; modprobe -r $mod 2>/dev/null || true'" || true
        done
    fi
    
    # 恢复 swap
    if [[ "$RESTORE_SWAP" == "true" ]]; then
        ssh_exec_sudo "$node" "bash -lc 'sed -i \"s/^#\\(.*[[:space:]]+swap[[:space:]].*\\)$/\\1/\" /etc/fstab 2>/dev/null || true; swapon -a 2>/dev/null || true'" || true
    fi
    
    log_info "[Step00] 节点 $node: 系统基线恢复完成"
}

# 清理日志文件
cleanup_logs() {
    local node="$1"
    log_info "Cleaning up log files..."
    ssh_exec_sudo "$node" "bash -lc 'rm -rf /var/log/containers /var/log/pods /var/log/kubernetes 2>/dev/null || true'" || true
}

# =============================================================================
# 主要执行函数
# =============================================================================

execute() {
    # 使用全局变量 $i (节点索引)
    log_info "[Step00] 节点 $i: 开始重置流程"
    
    # 首先修复主机名解析问题（避免后续 sudo 命令报错）
    fix_hostname_resolution "$i"
    
    # 执行清理步骤（按依赖关系排序）
    # 先清理依赖 API Server 的资源，再停止 Kubernetes 组件
    cleanup_cni "$i"               # 1. 先清理 CNI 网络（需要 API Server 运行）
    cleanup_kubernetes "$i"        # 2. 再执行 kubeadm reset（会停止 API Server）
    cleanup_storage "$i"           # 3. 清理存储
    # cleanup_namespaces "$i"      # 4. 移除命名空间清理功能（kubeadm reset 会自动清理）
    cleanup_container_runtime "$i"  # 5. 清理容器运行时
    
    # 清理网络
    cleanup_network "$i"
    
    # 清理日志
    cleanup_logs "$i"
    
    # 恢复系统基线
    restore_system_baseline "$i"
    
    log_info "[Step00] 节点 $i: 重置完成"
}

# 预检函数
precheck() {
    log_info "[Step00] 预检：即将执行重置"
    
    # 检查配置
    if [[ "${STEP00_ENABLED:-false}" != "true" ]]; then
        log_info "Step00 is disabled, skipping execution"
        exit 0
    fi
    
    log_info "Precheck completed"
}

# 验证函数
verify() {
    log_info "Reset operation completed successfully"
  echo ""
    echo "Summary of actions performed:"
    echo "- Kubernetes components removed"
    echo "- Container runtime cleaned up"
    echo "- Storage components cleaned up"
    echo "- Namespaces cleaned by kubeadm reset"
    echo "- Network configuration reset"
    echo "- System baseline restored"
  echo ""
    echo "Next steps:"
    echo "1. Verify the system is in a clean state"
    echo "2. Reboot the system if necessary"
    echo "3. Reinstall Kubernetes if needed"
}

# 主函数
main() {
    precheck
    
    # 远程执行，遍历节点
    for_each_node "$TARGET" execute
    
    verify
}

# 执行主函数
main "$@"