# SunMoonAI 部署与运维入口

**只有一套部署代码，加上两种建集群的方式。本地把平台和应用跑通，云上除了建集群那一步，其余走的是同一条路。**

当前正在按这个目标整理和迁移，不能把目标当成已经全部完成：正式 `sunmoon-kind-main` 尚未创建；公开 Harbor 和 inbox 仍使用旧 `kind`。云端新流程未经实机验证。完整现场续接见 [CHECKPOINT.md](CHECKPOINT.md)。

## 从这里操作

在仓库根运行 `./sunmoon help`。它转发到各模块唯一实现，不复制部署逻辑。先看计划/帮助，只有明确的 `--apply` 才进入相关实际分支；现有的摘要、存储、资源身份与切换门槛继续生效。

```bash
./sunmoon storage ensure                         # 只打印按需附盘计划
./sunmoon kind prepare                          # 正式 KIND 计划
./sunmoon kind cluster create                   # 建群计划，不执行
./sunmoon kind lifecycle start                  # 启动计划，不执行
./sunmoon harbor lifecycle --help               # 宿主仓库启停参数
./sunmoon harbor backup --help                  # 备份、校验、恢复准备参数
./sunmoon platform plan --cluster KIND          # 共享平台开关计划
./sunmoon cloud plan --cluster C1                # 云端只打印演练
```

Harbor `lifecycle start --apply` 与 KIND `lifecycle start --apply` 均先按需检查存储：正常挂载不调用 Windows；异常才请求已存在的附盘任务，再核 UUID 和服务可见性。它们不会重新创建磁盘或安装计划任务。停止路径不依赖自动附盘；不要因存储异常阻止必要停服。

平台和应用通过 `./sunmoon platform deploy --cluster KIND`（或 C1/C2/C3）使用同一总控，默认仍只打印。实际部署需加 `--apply --kubeconfig <绝对路径> --kubectl <绝对路径> --expected-uid <kube-system UID>`；总控核配置映射与显式目标一致后才生成文件/调用平台子脚本。当前映射仍保护旧 kind，main 的消费者未完成接线，不应为绕过核验临时改 UID。平台部署不会创建集群；整项目卸载已停用。启用 WAIT_READY 后，空 Pod 集合、非 Ready 或超时不再报告成功。

## 功能与当前边界

| 功能 | 唯一实现/说明 | 当前边界 |
| --- | --- | --- |
| 挂载、登录检查、启动前按需附盘、持久化 | [存储](sunmoonai/kind-infrastructure/mount/README.md) | 无一分钟轮询；完整 WSL 重启/缺盘恢复尚未实测 |
| 本地建群与节点启停 | [formal](sunmoonai/kind-infrastructure/formal/README.md) | 固定 main、三节点六挂载；未创建，不作用旧节点 |
| 云端建群与集群层物料 | [基础设施](sunmoonai/infrastructure/docs/infrastructure-upgrade-audit.md) | kubeadm 路径；真实云部署未验证，闭包门禁继续关闭 |
| 独立 Harbor 安装准备、启停、数据恢复 | [registry-platform](sunmoonai/registry-platform/README.md) | 候选恢复通过；公开入口未切换 |
| 入口、证书与消费者信任 | [入口与集成](sunmoonai/kind-infrastructure/docs/harbor-external-integration-plan.md) | SNI 候选验证通过；正式接管及新消费者接线待完成 |
| 平台和应用共享部署 | [项目总控](sunmoonai/deploy-sunmoonai-all/deploy-sunmoonai-all.sh) | 建群已从平台流程拆开；子脚本的目标配置仍须逐项对齐，不能对 main 宣称可用 |
| 镜像推拉、离线物料和 CI/CD | [唯一物料手册](sunmoonai/kind-infrastructure/docs/物料提交备齐方案和方法.md) | 保留既有功能，真实新仓库 Docker/CI 推拉仍待验；不靠候选 HTTP 结果替代 |
| 备份和独立恢复 | [宿主备份](sunmoonai/registry-platform/docs/host-backup.md) | 同盘恢复已验；机器外落点待定 |
| 空间回收、保留策略和 VHDX 压缩 | [回收方案](sunmoonai/kind-infrastructure/docs/wsl-space-reclamation-plan.md) | 最终必须清理，逐清单执行；无全局 prune；压缩由所有者在维护窗口操作 |
| 临时保留的旧代码/回退资源 | [legacy](legacy/README.md) | 文件归档与资源清理分开，有退出条件 |

统一入口没有新增“全卸载”或“全清理”命令。停止 KIND 不停止 Harbor；关闭 WSL 或 Docker 仍会影响二者。旧入口上的迁移提示不能作为回退执行器。

## 当前发版目标

仍是旧 `kind`、`~/.kube/kind-config`、对应 1.27.3 kubectl；具体 UID/工具绝对路径见 [交接目标](sunmoonai/kind-infrastructure/docs/luna-handoff-and-inbox-targets.md)。迁移验收前不要改 inbox 指向 main，也不要删除旧节点/卷。

架构与开发规则入口仍为 [AGENTS.md](AGENTS.md)，本页只收口部署运维，不复制产品设计规范。
