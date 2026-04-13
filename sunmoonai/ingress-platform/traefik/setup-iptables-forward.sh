#!/bin/bash
# Traefik iptables 端口转发脚本
# 将标准端口 80/443 转发到 NodePort 30080/30443
# 这样外部可以通过标准端口访问，同时 Traefik 以非 root 用户运行

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Traefik iptables 端口转发设置 ===${NC}"

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}错误: 此脚本需要 root 权限运行${NC}"
    echo "请使用: sudo $0"
    exit 1
fi

# 获取节点 IP（从环境变量或自动检测）
NODE_IP="${NODE_IP:-$(hostname -I | awk '{print $1}')}"
HTTP_NODEPORT=30080
HTTPS_NODEPORT=30443

echo -e "${YELLOW}节点 IP: ${NODE_IP}${NC}"
echo -e "${YELLOW}HTTP NodePort: ${HTTP_NODEPORT}${NC}"
echo -e "${YELLOW}HTTPS NodePort: ${HTTPS_NODEPORT}${NC}"
echo ""

# 函数：添加转发规则
add_forward_rule() {
    local external_port=$1
    local nodeport=$2
    local protocol=$3
    
    echo -e "${GREEN}添加转发规则: ${external_port} -> ${nodeport} (${protocol})${NC}"
    
    # 检查规则是否已存在（检查是否在 KUBE-SERVICES 之前）
    # 获取物理网络接口
    local physical_interfaces=$(ip link show | grep -E "^[0-9]+: (eth|ens|enp|enx)" | awk -F': ' '{print $2}' | awk '{print $1}' | head -1)
    local iface=""
    if [[ -n "$physical_interfaces" ]]; then
        iface=$(echo "$physical_interfaces" | head -1)
    fi
    
    local kube_services_line=$(iptables -t nat -L PREROUTING --line-numbers | grep -i "KUBE-SERVICES" | head -1 | awk '{print $1}')
    
    # 检查带接口限制的规则是否存在
    if [[ -n "$iface" ]]; then
        if iptables -t nat -C PREROUTING -i "$iface" -p ${protocol} --dport ${external_port} -j REDIRECT --to-port ${nodeport} 2>/dev/null; then
            if [[ -n "$kube_services_line" ]]; then
                local existing_rule=$(iptables -t nat -L PREROUTING -n --line-numbers | grep -E "tcp dpt:${external_port}.*redir ports ${nodeport}" | grep "$iface" | head -1)
                if [[ -n "$existing_rule" ]]; then
                    local rule_line=$(echo "$existing_rule" | awk '{print $1}')
                    if [[ "$rule_line" -lt "$kube_services_line" ]]; then
                        echo -e "${YELLOW}规则已存在且位置正确，跳过${NC}"
                        return 0
                    fi
                fi
            else
                echo -e "${YELLOW}规则已存在，跳过${NC}"
                return 0
            fi
        fi
    fi
    
    # 删除所有不带接口限制的旧规则（无论位置，确保清理干净）
    # 这是为了修复之前可能存在的错误规则（拦截所有流量，包括集群内部通信）
    local old_rules_count=0
    while iptables -t nat -D PREROUTING -p ${protocol} --dport ${external_port} -j REDIRECT --to-port ${nodeport} 2>/dev/null; do
        old_rules_count=$((old_rules_count + 1))
    done
    if [[ $old_rules_count -gt 0 ]]; then
        echo -e "${YELLOW}已删除 $old_rules_count 条旧规则（无接口限制），将添加新的正确规则${NC}"
    fi
    
    # 添加 PREROUTING 规则（外部访问）
    # 重要：只匹配从物理网络接口进入的流量，排除 Pod 网络接口（cni0, flannel.*, veth* 等）
    # 这样可以避免拦截集群内部 Pod 之间的通信
    # 如果之前没有获取到 kube_services_line，现在获取
    if [[ -z "$kube_services_line" ]]; then
        kube_services_line=$(iptables -t nat -L PREROUTING --line-numbers | grep -i "KUBE-SERVICES" | head -1 | awk '{print $1}')
    fi
    
    # 获取物理网络接口（排除虚拟接口）
    local physical_interfaces=$(ip link show | grep -E "^[0-9]+: (eth|ens|enp|enx)" | awk -F': ' '{print $2}' | awk '{print $1}' | head -1)
    
    if [[ -n "$kube_services_line" ]]; then
        if [[ -n "$physical_interfaces" ]]; then
            # 只匹配从物理接口进入的流量
            local iface=$(echo "$physical_interfaces" | head -1)
            if ! iptables -t nat -C PREROUTING -i "$iface" -p ${protocol} --dport ${external_port} -j REDIRECT --to-port ${nodeport} 2>/dev/null; then
                iptables -t nat -I PREROUTING $kube_services_line -i "$iface" -p ${protocol} --dport ${external_port} -j REDIRECT --to-port ${nodeport}
            fi
        else
            # 如果找不到物理接口，使用原来的方式（但添加注释说明风险）
            echo -e "${YELLOW}警告: 未找到物理网络接口，使用通用规则（可能影响集群内部流量）${NC}"
            iptables -t nat -I PREROUTING $kube_services_line -p ${protocol} --dport ${external_port} -j REDIRECT --to-port ${nodeport}
        fi
    else
        # 如果找不到 KUBE-SERVICES，则追加到末尾
        if [[ -n "$physical_interfaces" ]]; then
            local iface=$(echo "$physical_interfaces" | head -1)
            if ! iptables -t nat -C PREROUTING -i "$iface" -p ${protocol} --dport ${external_port} -j REDIRECT --to-port ${nodeport} 2>/dev/null; then
                iptables -t nat -A PREROUTING -i "$iface" -p ${protocol} --dport ${external_port} -j REDIRECT --to-port ${nodeport}
            fi
        else
            iptables -t nat -A PREROUTING -p ${protocol} --dport ${external_port} -j REDIRECT --to-port ${nodeport}
        fi
    fi
    
    # 添加 OUTPUT 规则（本地访问）
    # 需要匹配所有可能的 IP（包括公网 IP 和内网 IP）
    local public_ip=$(curl -s ifconfig.me 2>/dev/null || curl -s ip.sb 2>/dev/null || echo "")
    if [[ -n "$public_ip" ]]; then
        # 检查公网 IP 规则是否已存在
        if ! iptables -t nat -C OUTPUT -p ${protocol} -d ${public_ip} --dport ${external_port} -j REDIRECT --to-port ${nodeport} 2>/dev/null; then
            iptables -t nat -A OUTPUT -p ${protocol} -d ${public_ip} --dport ${external_port} -j REDIRECT --to-port ${nodeport}
        fi
    fi
    # 添加内网 IP 规则（如果不存在）
    if ! iptables -t nat -C OUTPUT -p ${protocol} -d ${NODE_IP} --dport ${external_port} -j REDIRECT --to-port ${nodeport} 2>/dev/null; then
        iptables -t nat -A OUTPUT -p ${protocol} -d ${NODE_IP} --dport ${external_port} -j REDIRECT --to-port ${nodeport}
    fi
    
    echo -e "${GREEN}✓ 转发规则已添加${NC}"
}

# 函数：删除转发规则
remove_forward_rule() {
    local external_port=$1
    local nodeport=$2
    local protocol=$3
    
    echo -e "${YELLOW}删除转发规则: ${external_port} -> ${nodeport} (${protocol})${NC}"
    
    # 删除 PREROUTING 规则（包括带接口限制和不带接口限制的规则）
    # 先删除带接口限制的规则
    local physical_interfaces=$(ip link show | grep -E "^[0-9]+: (eth|ens|enp|enx)" | awk -F': ' '{print $2}' | awk '{print $1}' | head -1)
    if [[ -n "$physical_interfaces" ]]; then
        local iface=$(echo "$physical_interfaces" | head -1)
        while iptables -t nat -D PREROUTING -i "$iface" -p ${protocol} --dport ${external_port} -j REDIRECT --to-port ${nodeport} 2>/dev/null; do
            : # 空操作，继续删除
        done
    fi
    # 删除不带接口限制的规则（兼容旧版本）
    while iptables -t nat -D PREROUTING -p ${protocol} --dport ${external_port} -j REDIRECT --to-port ${nodeport} 2>/dev/null; do
        : # 空操作，继续删除
    done
    
    # 删除 OUTPUT 规则（包括公网 IP 和内网 IP）
    local public_ip=$(curl -s ifconfig.me 2>/dev/null || curl -s ip.sb 2>/dev/null || echo "")
    if [[ -n "$public_ip" ]]; then
        while iptables -t nat -D OUTPUT -p ${protocol} -d ${public_ip} --dport ${external_port} -j REDIRECT --to-port ${nodeport} 2>/dev/null; do
            : # 空操作，继续删除
        done
    fi
    while iptables -t nat -D OUTPUT -p ${protocol} -d ${NODE_IP} --dport ${external_port} -j REDIRECT --to-port ${nodeport} 2>/dev/null; do
        : # 空操作，继续删除
    done
    
    echo -e "${GREEN}✓ 转发规则已删除${NC}"
}

# 函数：列出当前规则
list_rules() {
    echo -e "${GREEN}当前 iptables 转发规则:${NC}"
    echo ""
    echo "PREROUTING 规则:"
    iptables -t nat -L PREROUTING -n --line-numbers | grep -E "REDIRECT|dpt:(80|443)" || echo "  无"
    echo ""
    echo "OUTPUT 规则:"
    iptables -t nat -L OUTPUT -n --line-numbers | grep -E "REDIRECT|dpt:(80|443)" || echo "  无"
}

# 函数：持久化 iptables 规则
persist_rules() {
    echo -e "${GREEN}配置 iptables 规则持久化...${NC}"
    
    # 方法1: 使用 iptables-persistent（推荐）
    if command -v netfilter-persistent >/dev/null 2>&1; then
        echo -e "${YELLOW}使用 netfilter-persistent 保存规则...${NC}"
        netfilter-persistent save
        echo -e "${GREEN}✓ 规则已通过 netfilter-persistent 保存${NC}"
        return 0
    fi
    
    # 方法2: 使用 iptables-save 保存到文件
    local rules_file="/etc/iptables/rules.v4"
    local rules_dir="/etc/iptables"
    
    # 确保目录存在
    if [[ ! -d "$rules_dir" ]]; then
        mkdir -p "$rules_dir"
    fi
    
    # 保存规则
    if iptables-save > "$rules_file" 2>/dev/null; then
        echo -e "${GREEN}✓ 规则已保存到 $rules_file${NC}"
        
        # 如果存在 iptables-persistent 服务，确保它会在启动时加载
        if systemctl list-unit-files | grep -q "netfilter-persistent.service"; then
            systemctl enable netfilter-persistent.service >/dev/null 2>&1 || true
        fi
        
        return 0
    else
        echo -e "${YELLOW}⚠️  无法保存规则到 $rules_file（可能需要安装 iptables-persistent）${NC}"
        return 1
    fi
}

# 主逻辑
case "${1:-add}" in
    add)
        add_forward_rule 80 ${HTTP_NODEPORT} tcp
        add_forward_rule 443 ${HTTPS_NODEPORT} tcp
        echo ""
        echo -e "${GREEN}✓ 所有转发规则已添加${NC}"
        echo ""
        
        # 自动持久化（如果指定了 --persist 参数或环境变量）
        if [[ "${2:-}" == "--persist" ]] || [[ "${AUTO_PERSIST:-false}" == "true" ]]; then
            persist_rules
        else
            echo -e "${YELLOW}注意: 这些规则在重启后会丢失${NC}"
            echo -e "${YELLOW}要持久化，请运行: ${NC}$0 add --persist"
            echo -e "${YELLOW}或安装 iptables-persistent: ${NC}apt-get install iptables-persistent"
        fi
        ;;
    remove)
        remove_forward_rule 80 ${HTTP_NODEPORT} tcp
        remove_forward_rule 443 ${HTTPS_NODEPORT} tcp
        echo ""
        echo -e "${GREEN}✓ 所有转发规则已删除${NC}"
        ;;
    list)
        list_rules
        ;;
    *)
        echo "用法: $0 {add|remove|list}"
        echo ""
        echo "  add    - 添加端口转发规则（默认）"
        echo "  remove - 删除端口转发规则"
        echo "  list   - 列出当前规则"
        exit 1
        ;;
esac

echo ""
list_rules

