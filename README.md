# SunMoonAI 部署与运维入口

本仓是平台的部署仓：宿主、集群、Harbor、入口、Flux 与各应用的部署声明都在这里。代码与应用开发规则的入口是 [AGENTS.md](AGENTS.md)。

## 从哪里操作

日常操作统一走 `infrastructure/` 的 Make 入口（底层是 Ansible 与 Flux）：

```bash
make -C infrastructure help                       # 全部入口
make -C infrastructure platform-status            # 平台状态
make -C infrastructure application-check APP=<应用>
```

| 要找的 | 在哪 |
| --- | --- |
| 架构、职责与配置归属 | [docs/platform/architecture.md](docs/platform/architecture.md) |
| 已验证范围与验收记录 | [docs/platform/verification.md](docs/platform/verification.md) |
| 宿主（WSL、数据盘、开机服务、空间） | [infrastructure/host/](infrastructure/host/README.md) |
| 集群、Harbor、入口、边缘机 | `infrastructure/` 下各目录的 README |
| 应用构建与自研组件镜像 | [infrastructure/applications/](infrastructure/applications/README.md) |
| 部署声明（Flux） | [gitops/](gitops/) |
| 我们在建什么、做到哪了 | [docs/dev-investment-agent/pipeline.md](docs/dev-investment-agent/pipeline.md) |
| 项目总览 | [docs/project-guide/overall-architecture.md](docs/project-guide/overall-architecture.md) |
| 通用参考资料（行业、采集、技术笔记、运维笔记） | [docs/reference/](docs/reference/) |

旧体系（`sunmoonai/` 下的旧部署、`utils/`、`legacy/`、`./sunmoon` 命令行）已于 2026-10-16 删除，要查看时按 Git 历史取（最后一个包含它们的提交是 `9a2abf12`）。
