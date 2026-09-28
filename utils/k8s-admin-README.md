# 连接配置与人工连接工具

`k8s-admin.conf` 是现有共享组件的连接配置，仍被总控、KIND 节点帮助工具和模板读取，不能随旧说明删除。

## 日常部署

新正式建群用 `./sunmoon kind …`，平台部署用 `./sunmoon platform …`；具体目标、kubeconfig、kubectl 和 UID 按 [统一配置说明](../sunmoonai/operations/configuration.md)显式选择。
当前旧 kind 与未来 main 的配置不能混用。`kubeconfig-path-for-cluster.sh` 仍供部署链解析本配置。

## 为什么保留两个连接工具

- `k8s-connection-manager.sh`：人工使用的交互菜单，支持 KIND、SSH 直接访问/跳板及隧道保活，保存 `.k8s-status` 等状态。
- `k8s-connection-manager.ps1`：Windows 侧连接与路径处理；不是 Shell 版本的简单转发。
- 两者的实际用途不依赖其他脚本调用。新版总控尚未完整替代人工隧道管理，所以保留原工具，不能标为无用副本。

这两个入口目前仍是旧连接实现：Shell 入口有工具安装、端口处理与 shell 配置修改，两者存在关闭 SSH 主机校验的路径；不是只读查看命令。此轮未运行它们，也未声明其已完成 Kubernetes 1.36 或云端实机适配。不要把运行旧菜单当作新集群的安装前置。

手动只读查询可以用明确的工具与配置：

```bash
/absolute/path/kubectl --kubeconfig /absolute/path/kubeconfig get nodes
```

旧 `storage-manager.sh` 在本仓不存在，其菜单说明已删除；存储操作见 [当前存储入口](../sunmoonai/kind-infrastructure/mount/README.md)。
