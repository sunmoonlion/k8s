# 手工 NAT 工具与新版入口

新版部署入口见[共用 Traefik 流程](../../infrastructure/docs/ingress-bootstrap.md)，
证书见[统一签发与安装](../../registry-platform/docs/certificates.md)。
原 `deploy-traefik/deploy-traefik.sh` 转发入口已删除，不再提供自动 iptables 设置。
原“只有节点 2 可访问 Harbor”的记录描述旧云集群；历史文档和旧命令已移入
[云端归档](../../../legacy/cloud/README.md)，不能作为新集群的故障结论。

## 当前日常入口

从 `k8s` 根目录运行，以下仅打印计划：

```bash
bash sunmoonai/registry-platform/deploy-certificates.sh --cluster KIND --dry-run
bash sunmoonai/ingress-platform/deploy-ingress-platform-all/deploy-ingress-platform-all.sh --cluster KIND --dry-run
```

实际安装需按上述文档提供固定工具、kubeconfig、UID、CA 和物料闭包；
本地宿主 `30443` 由 SNI 代理按域名分流，应用进入 KIND `19443` 映射，Harbor 进入独立宿主服务。
云上 Harbor 在独立主机，不复用 WSL 入口代理。这里没有启动这些服务或完成入口切换。

## 为什么还保留 setup-iptables-forward.sh

它是管理员手工网络诊断/修复工具，有独立用途；不是当前平台、建群、证书或 Harbor 流程的依赖。
当前脚本可将主机 80/443 转到 30080/30443，处理 PREROUTING/OUTPUT 规则，
会删除匹配的旧规则，并包含规则持久化及公网 IP 查询。它自动选择接口/地址，
这些历史策略尚未按新拓扑整改、尚未在新版集群验证。

只能把它的 `--dry-run` 当请求摘要：不会列出实际防火墙差异。脚本真实运行需要 root，
并会改变主机网络，不因这个文档更新就获准在当前 WSL 或旧节点执行。
用户的主机端口入口需求已由统一 SNI/Ingress 流程承接；不要把它用于恢复旧的 Harbor 节点路由。
后续如有独立主机 NAT 需求，先按具体接口/地址形成规则差异和回退步骤，再完成该工具的独立整改。

本批只整理代码和说明，未查询公网 IP、修改 iptables、写持久化规则或重启网络。
