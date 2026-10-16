# tpl-app：应用模板

> 最后更新：2026-10-16 ｜ 按代码现状重写 ｜ 总览见 [`../overall-architecture.md`](../overall-architecture.md)

一个标准应用长什么样由本仓规定；knowfeed、knowbase、investment 由它实例化，将来的 knowlab-app、knowmart-app 也一样。**公共缺陷先修模板，再同步到各实例。**

## 结构

```text
tpl-app/
├── tpl-backend/          FastAPI 后端（Admin / Web / Internal 三面一个工程）
│   └── app/              源码：app/{domain,application,infrastructure,interfaces}、core/、alembic/、tests/、Dockerfile
├── tpl-web-frontend/     Next.js 网页端（源码在 app/，构建文件 mybuild/Dockerfile）
├── tpl-admin-frontend/   Next.js 管理端（同上）
├── contracts/            模板自带的契约向量（web-interaction-v1）
├── init.sh               把一个全新的 tpl-app 克隆原地转换成实例父仓
├── template-release-manifest.json、verify_template_release.py   模板发布锁与同步前校验
└── frontend-capability-matrix.json、frontend-pairing-matrix.json  前端能力与配对矩阵
```

## 后端

- **分层**：`domain/`（领域模型与规则）、`application/`（服务、DTO、Port）、`infrastructure/`（ORM、外部适配、Celery、存储）、`interfaces/`（`http/` 是模板面：认证、会话、健康、审计等；`endpoints/` 是实例自己的领域面）。领域概念不进 Port 签名（`C-A5`）。
- **运行角色**：同一镜像起 API、Worker（Celery）、Scheduler（Celery beat，单副本）与 Migration（一次性 Job）；API / Worker / Scheduler 启动不得隐式升级数据库（`C-D8`）。
- **认证**：Admin 与 Web 两个面各自的 Casdoor client、回调、cookie 与会话命名空间；按令牌所属组织把关（管理端 `built-in`，网页端 `sunmoonai`）；`core/config.py` 启动期硬校验，配错进程起不来。
- **跨应用**：`domain/cross_app.py` 规定跳转链接的形状（业务参数、`from`、`ref`）；跨应用调用走服务身份与版本化契约。
- **测试**：`app/tests/`，其中 `test_kernel_invariants.py` 是结构不变量（迁移链单链、文件名清单等，`C-D6`、`C-D7`）。

## 前端

Next.js + React + Tailwind + shadcn + next-intl，`output: 'standalone'`；请求只走同源 `/api/`；会话由后端 cookie 承载，前端不持有后端或数据库凭据（`C-D9`）。

## 构建与部署

- 构建与部署都由 `k8s` 仓的发布链做（[总览](../overall-architecture.md) §6）：后端用 `app/Dockerfile`，两个前端用 `mybuild/Dockerfile`；`k8s/infrastructure/applications/sources.yaml` 钉各父仓与子仓的提交。
- 部署声明在 `k8s/gitops/components/app-platform/tpl-app/`，共用机制在 `app-platform/common/`（应用直接复用，不经模板转接）。
- 本仓里 `k8s-deployment/`、`dev-to-prod-deploy/`、后端的 `db-provisioner/`、`*-access-bootstrap/` 与 `mybuild/` 下除 `Dockerfile` 外的脚本是旧体系的部署材料，**现行部署不用**。

## 实例与模板的关系

| 能改什么 | 判据 |
| --- | --- |
| 领域目录、`interfaces/endpoints/`、迁移、领域依赖 | 实例自己的扩展点，可以不同 |
| `interfaces/http/`、认证、配置校验、运行角色、构建形状 | 模板面；要改先改模板，再同步到全部实例 |

同步前跑 `verify_template_release.py` 核模板发布锁。
