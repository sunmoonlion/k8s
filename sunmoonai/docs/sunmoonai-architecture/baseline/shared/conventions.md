# 四仓共同约定

> 最后更新：2026-08-15 ｜ 验证时点：2026-08-15
> 指 tpl / info / knowledge / investment 四个 App 仓。`k8s` 仓是脚本仓，不适用本文。

## 1. 仓库形态

每个 App 父仓固定三个 Git 子模块（各仓 `.gitmodules:1-9`）：

| 子模块 | 内容 |
| --- | --- |
| `<app>-backend` | Python 3.12 + FastAPI 统一后端 |
| `<app>-admin-frontend` | Next.js 管理端 |
| `<app>-web-frontend` | Next.js 用户端 |

后端一个镜像跑四种进程角色，靠 bootstrap 入口区分：
`app/app/bootstrap/{api,worker,scheduler,migration}.py`。

## 2. 后端分层

```text
app/app/
├── domain/          领域模型、枚举、状态机、命令
├── application/     服务编排、DTO、Port（接口定义）
├── infrastructure/  ORM、外部系统适配、Celery、存储（Port 实现）
└── interfaces/      HTTP 路由、中间件、Schema
```

**依赖方向单向**：`application` 不得 import `app.interfaces`，由
`app/tests/test_kernel_invariants.py` 强制（info `:32-36`、knowledge `:33-36`）。

Port 定义在 `application/ports/`，实现在 `infrastructure/`。
这个模式的一个后果是：**Port 与实现都在、却没人注入**的情况很常见（见各仓 §8）。

## 3. 内核不变量测试

各仓 `app/tests/test_kernel_invariants.py` 是一组结构性门禁，改架构必看：

| 检查 | 位置示例 |
| --- | --- |
| 分层依赖方向 | info `:32-36` |
| 迁移单链线性 + 顺序清单 | info `:39-59`、investment `:39-57` |
| 镜像构建上下文排除 `.env` 与 `tests` | info `:81-85` |
| Outbox 原语存在性 | info `:62-76` |

改迁移必须同步改这个文件里的 revision 顺序清单，否则 CI 失败。

## 4. 三件套命令

| 目标 | 后端 | 前端 |
| --- | --- | --- |
| 装依赖 | `uv sync --frozen` | `corepack pnpm install --frozen-lockfile` |
| 静态检查 | `uv run ruff check .` | 含在 `pnpm check` |
| 类型 | `uv run pyright` | `pnpm typecheck` |
| 测试 | `uv run pytest -q` | `pnpm test` / `pnpm test:e2e` |
| 全检 | 上述三条 | `corepack pnpm check` |

依赖一律冻结安装：后端 `uv.lock`，前端 `pnpm-lock.yaml`。

## 5. 配置与环境变量

| 位置 | 作用 |
| --- | --- |
| `<backend>/app/core/config.py` | Pydantic Settings，含生产期硬校验（见 [`identity.md`](identity.md) §5） |
| `<backend>/app/.env.example` | 环境变量清单模板 |
| `<frontend>/app/env/server-schema.ts` | 前端服务端环境变量的 Zod 校验，启动即失败 |
| `db-access-bootstrap/`（knowledge、investment） | 本地 PG/Redis 参数合并进 `.env` 的脚本 |

配置错误的表现是**启动期抛异常**，不是运行期降级。改配置后先启一次进程验证。

## 6. Celery 约定

| 事项 | 现状 |
| --- | --- |
| 任务模块 | `app/app/tasks/` 下按主题分文件 |
| 事件循环 | 每个异步任务各自 `asyncio.run`（例 `info-app/app/tasks/crawl.py:11-14`）；`ping` 是同步的（`tasks/ping.py:4-7`） |
| broker 缺失 | Worker / Scheduler 启动即 `RuntimeError`（`info-app/app/worker.py:29-30`） |
| 周期任务 | **四仓都有 Scheduler bootstrap，但都没有 `beat_schedule` 定义** |
| 未配 broker 时的 API 行为 | 建任务成功但不执行（`enqueued=False`），例 `investment-app/run_service.py:36-44` |

## 7. 四仓一致的未接线项

这三处在四个仓里表现一致，读任何一仓都会遇到：

| 项 | 状态 | 详见 |
| --- | --- | --- |
| 共享 Outbox / Inbox | 表、仓库类、Port 全在，业务层零调用 | [`data.md`](data.md) §4 |
| web-interaction 生产适配器 | 默认 `UnavailableWebInteractionAdapter` → 503 | [`contracts.md`](contracts.md) §6 |
| Celery beat 周期任务 | 无调度定义 | 上表 §6 |

它们都源自模板：tpl-app 里就是这个状态，三个实例照样继承。
改模板时要意识到这一点——模板里的未接线项会被复制到所有实例。

## 8. 文档在仓内的位置

各 App 仓的 `docs/` 与 `dev-to-prod-deploy/` 存历史与操作材料。
`info-app/README.md:23-24` 明确 `docs/` 非运行时真源。
判断某件事的当前真相，按本目录 [`../README.md`](../README.md) 的任务索引走，
或直接读代码。
