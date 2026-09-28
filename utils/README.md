# 公共库、人工工具与模板

部署与日常总控从仓库根 `./sunmoon` 进入，配置位置见 [配置对照](../sunmoonai/operations/configuration.md)。这里保存有实际用途的公共能力，不存废弃入口的转发副本。

**工具不一定有代码调用方。** 是否保留，要同时看人工用途、模板生成用途、动态加载和替代是否完整；搜索不到文件名不能作为删除依据。
本次 131 个原文件的处置见 [逐文件清单](../sunmoonai/operations/utils-refactor-inventory.md)。这是结构与依赖整理，不代表保留的旧工具已经通过新版集群验收。

## 目录与职责

| 内容 | 用途和调用方式 |
| --- | --- |
| `unified-deployment-template.sh`、`cluster-arg-parser.sh`、`cluster-config-mapping.sh` | 组件共享的连接、集群参数与配置映射。参数解析只保留一份实现；仍有大量实际部署调用方 |
| `k8s-admin.conf`、`kubeconfig-path-for-cluster.sh`、`deploy-runtime-helpers.sh`、`prepend-dev-cli-path.sh` | 现有组件的连接配置、路径和子脚本环境。配置保留；不得因整理擅自改变当前集群目标 |
| `secret-management/` | 参数化 Secret 数据准备/YAML 生成、基于已有 CA 签发叶证书，供组件调用 |
| `unified-cert-secret-management/` | 按服务端/客户端组合分发证书，包含动态加载的 Traefik 插件；与上一目录接口不同，不能按同名函数直接合并 |
| `components-images/` | 通过组件名动态读取的 19 份镜像清单；文件名没有固定调用也不能删除。与最终部署摘要锁的对齐仍待迁移完成 |
| `db-provisioner/` | k8s 平台组件的建库/授权公共实现；Casdoor 仍使用它。模板仓和实例仓使用各自 backend 自带版本，不指向这里 |
| `auth-integration-template/` | Nuxt/Vite 和 FastAPI/Flask/NestJS 的接入样例，供人工复制/改造；不是当前 Next.js/Casdoor 平台的自动安装入口 |
| `*-gate.sh`、`app-dependency-preflight.sh` | 身份、迁移和依赖校验函数，属于可复用组件能力，不因当前没有直接引用删除 |
| `prepare-secrets-from-examples.sh` | 只补缺失的占位文件，保留已有 Secret 文件；占位内容不等于部署凭据 |
| `app-config-checklist-template.md` | 人工配置检查模板，保留 |

## 人工工具保留

| 工具 | 保留的操作能力 | 当前边界 |
| --- | --- | --- |
| `k8s-connection-manager.sh` / `.ps1` | Linux/WSL 和 Windows 的 SSH 直连、跳板、隧道及交互查询 | 不是废弃转发脚本；参见 [连接工具说明](k8s-admin-README.md)。会修改连接状态，云新流程未经实机验证 |
| `packages-management/` | 自定义 deb 打包、手工镜像导出、tar/chart 下载和远程分发菜单 | [工具能力说明](packages-management/README.md)列出哪些已有新版替代、哪些仍需保留。整工具不能因无自动调用就删除 |
| `check-local-images.sh` | 当前主机 Docker/CRI/nerdctl 镜像盘点 | 保留只读用途，已移除全局 prune 建议 |
| `check-node-images.sh`、`check-remote-node-images.sh` | Kubernetes API 所见 Pod/Deployment、镜像 ID、节点分布 | 不是完整节点缓存审计；使用前显式设置 kubeconfig 与匹配 kubectl；已移除删 Pod/节点镜像建议 |
| `fix-local-path-helper-image.sh` | 人工修复旧 local-path helper 镜像和拉取 Secret | 属于会修改集群的修复工具；新建群使用锁定 storage 流程。不是自动建群依赖，不自动执行 |

## 已合并/删除

- `harbor-image-check.sh` 删除，唯一活动调用方 Document Converter 直接使用 `registry-platform/images.py` 的严格 TLS/摘要检查，认证或网络失败不再放行。
- 删除旧 KIND 教程和不存在的 storage-manager 菜单说明。建群见 [formal](../sunmoonai/kind-infrastructure/formal/README.md)，存储见 [mount](../sunmoonai/kind-infrastructure/mount/README.md)。
- 删除旧 `CALLERS_ANALYSIS.md` 静态分析快照；调用处置以本次清单及源码为准。
- 相同的证书规范/模板只留在 `secret-management/lib/`，证书分发模块直接引用这些说明，不留复制品。
- 删除 `sunmoonai/utils/db-provisioner/` 仓内重复副本；唯一平台实现是本目录下的 `db-provisioner/`。模板仓与实例仓版本未动。

旧镜像发布目录此前已删除。需暂存的旧云代码仍集中在 `legacy/`，不是日常操作入口。代码整理不清理镜像、节点、卷、数据库或实际物料。
