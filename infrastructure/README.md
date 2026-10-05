# 部署与维护入口

日常任务从[维护导航](../docs/README.md)选择；架构见[职责与约束](../docs/platform-kind-v1/architecture.md)，已验证范围与缺项见[验收边界](../docs/platform-kind-v1/verification.md)。

## 运行前提

在五仓并列的`platform-kind-v1/k8s`根目录执行本文命令。已有宿主需要WSL Ubuntu、Docker、systemd、OpenSSL、jq、uv、宿主Python及可用的非交互sudo；新数据盘的首次管理员附盘由Windows侧完成。当前没有从空Windows主机开始的完整一键引导。

```sh
make -C infrastructure help
make -C infrastructure config
make -C infrastructure preflight
```

`help`查看真实target；`config`列出权威输入文件；`preflight`只读核验宿主挂载。协议检查与部署入口会有写入，使用前阅读所属模块。

## 配置和入口归属

| 维护任务 | 配置/说明 |
|---|---|
| 共享集群名、命名空间、仓库地址、物料根 | [环境配置](environments/kind/README.md) |
| 数据盘/容量/Windows与WSL | [host](host/README.md) |
| 工具与不可变物料 | [tools](tools/README.md)、[artifacts](artifacts/README.md) |
| 外置Harbor启停、认证、扫描、恢复 | [registry](registry/README.md) |
| 公共30443 TLS直通与切换 | [entry](entry/README.md) |
| 三节点KIND、证书和节点拉取 | [cluster](cluster/README.md) |
| Flux、发布候选、显式晋级、SOPS | [flux](flux/README.md) |
| 平台的共同部署链 | [services](services/README.md) |
| 四应用在线构建、发布、部署和检查 | [applications](applications/README.md) |
| 平台组件/应用参数 | [组件目录](../gitops/components/README.md) |

Makefile显式加载模块与组件配置，再加载`SITE`（默认`environments/kind/site.yaml`）。模块专属字段与共享字段各维护一个来源；用户参数、模板、声明、说明按职责就近放置。`APP`须明确选择`tpl/info/knowledge/investment`；`COMPONENT`用于源码计划，选择`backend/web/admin`。

## 部署的依赖顺序

宿主挂盘与工具 → 校验物料 → Harbor后端与身份 → TLS入口 → KIND与私有拉取 → Flux/SOPS/foundations → 平台服务 → 应用构建/发布/身份/迁移/运行 → 真实公共入口检查。

已有已晋级环境的服务、应用分别有`services-bootstrap`和`application-bootstrap APP=...`编排。它们复用Make/Ansible/Flux，校验配置与晋级声明一致后才部署；没有自动批准本地新配置。整套宿主到所有应用的一键部署、整套统一启停和开机恢复仍是[未完成交付项](../docs/platform-kind-v1/verification.md#未完成项)。

## 变更与停止条件

编辑权威配置 → 计划/准备候选 → 审閱结构与秘密语义差异 → stage并本地提交 → 发布声明候选 → 审核并显式晋级 → 部署 → 组件协议与真实入口检查。发布和晋级的方法只在[Flux手册](flux/README.md#发布与显式晋级)维护。

已有输入丢失、目录/集群身份不符、摘要漂移、源不一致或容量不够时，保留现场并处理原因；不能强制接管字段、关闭TLS/哈希校验或删除卷使流程继续。关闭enabled不会自动停止Flux持有的已有对象。

当前开发维护窗口2小时，容量底线来自[host配置](host/config.yaml)，为10GiB；仍扣除数据盘未来增长与本操作预算。容量授权不包含数据删除。进入对外服务阶段重新确定可用性和维护约束。
