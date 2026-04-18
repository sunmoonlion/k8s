# tpl-app 四子模块镜像构建方案（Cursor 版）

> 文档版本：v2.1 | 日期：2026-04-18 | 方案标识：**cursor**  
> **范围声明**：只讨论 **`/home/zym/tpl-app`** 内四个子项目的镜像构建与 CI 对接。**不涉及 Celery**、不涉及 `app-platform` / `generate-app.conf` 级部署细节。  
> **并列文档**：[build-images方案-claude.md](./build-images方案-claude.md)（Claude 版，含完整 Dockerfile 样例、Harbor 基础镜像缓存表、分模块 Kaniko 参数）；本文吸收其**可操作结论**，保持篇幅精炼。  
> **背景参考**（可选）：[cicd总体架构及实施详细方案.md](./cicd总体架构及实施详细方案.md)。

---

## 一、目标与验收标准（构建侧）

| 维度 | 验收要点 |
|------|----------|
| 可复现 | 固定基础镜像 tag、锁文件（`pnpm-lock.yaml` / `uv.lock` 等），同一 commit 构建可重复。 |
| 可追溯 | 镜像 tag 以 **`<git-sha>`** 为主；可另打 `:latest` 作移动引用（见 Claude 版 Kaniko 双 destination）。 |
| CI 可运行 | **Kaniko** 构建：**禁止** BuildKit 专有语法（`RUN --mount=type=cache` 等）；**禁止**依赖未在 Harbor/公网声明的私有基础镜像（如未预先推送的 `dev:1.0`）。 |
| 自包含 | 不在构建中假设已手工生成 `dist/`（除非流水线先执行 build stage）。 |
| 构建期环境变量 | **Vue `VITE_*`、Next `NEXT_PUBLIC_*`** 在构建时打进 bundle；不同环境 API 地址需 **不同 build-arg / 不同 tag 镜像**（或见 Claude 版附录「运行时注入」长期方案）。 |
| 对接 K8s（背景） | 镜像推 Harbor 后，`image:` 能引用即可；编排与 GitOps 见总体方案。 |

---

## 二、现状与差距（吸收 Claude 版结论）

### 2.1 四子模块速览

| 子模块 | 技术栈 | Dockerfile 位置 | 与 CI 关系 |
|--------|--------|-------------------|------------|
| tpl-admin-frontend | Vue 3 + Vite | 根目录多文件；`Dockerfile-prod` 使用 `FROM dev:1.0` | **阻断**：CI 无 `dev:1.0`；需多阶段自包含（样例见 Claude 版 §3.1）。 |
| tpl-admin-backend | FastAPI | [`app/Dockerfile`](../../../tpl-app/tpl-admin-backend/app/Dockerfile) | **规范**：Dockerfile 不在子模块根时，Kaniko 必须显式 `--dockerfile`；建议在根目录增加 CI 用 `Dockerfile`（Claude §3.2）。 |
| tpl-web-frontend | Next.js | [`mybuild/Dockerfile`](../../../tpl-app/tpl-web-frontend/mybuild/Dockerfile) + [`build.conf`](../../../tpl-app/tpl-web-frontend/mybuild/build.conf) | **基本合格**：需基础镜像改 Harbor、`REGISTRY` 参数化；`build.conf` 中镜像名 `tpl-app-ssr` 与目录名不一致，**实例化时统一**（§五）。 |
| tpl-web-backend | NestJS + pnpm | [`mybuild/Dockerfile`](../../../tpl-app/tpl-web-backend/mybuild/Dockerfile) | **以当前主 Dockerfile 为准**：主文件已用普通 `RUN pnpm install`（Kaniko 友好）。**勿**将 CI 指向 [`Dockerfile.original`](../../../tpl-app/tpl-web-backend/mybuild/Dockerfile.original)（内含 `--mount=type=cache`，Kaniko 失败）。 |

### 2.2 其他规范点（与 Claude 版一致）

- **Dockerfile 路径**：流水线默认若只认根目录 `Dockerfile`，四子模块需 **要么** 根目录提供 CI 用文件 **要么** 在模板里为每个子模块写清路径（见下节 Kaniko 表）。  
- **基础镜像走 Harbor**：内网构建应对齐 Claude 版 **§2.3 基础镜像缓存表**，避免直连 Docker Hub 失败。  
- **Harbor 项目名**：**`k8s-images`** 与独立 **`apps`** 二选一全局统一；Claude 版默认 **`k8s-images/<service-name>`**，与现有习惯一致。

---

## 三、Kaniko 参数一览（自 Claude 版 §四 精简）

> 以下为「每个子模块一条」的推荐约定；`context` 为**该子模块仓库根目录**（在 monorepo 中即对应子目录）。

| 子模块 | `--dockerfile`（相对 context） | `--target` | 关键 `--build-arg` |
|--------|-------------------------------|------------|---------------------|
| tpl-admin-frontend | `Dockerfile`（新建 CI 版后） | （默认最后阶段） | `VITE_API_URL`，等 |
| tpl-admin-backend | `Dockerfile`（根目录新建后）或 `app/Dockerfile` | — | — |
| tpl-web-frontend | `mybuild/Dockerfile` | `run-minimal`（按 Claude 样例） | `NEXT_PUBLIC_API_URL`、`REGISTRY` |
| tpl-web-backend | `mybuild/Dockerfile` | `run` | `REGISTRY` |

共性：`--destination=<registry>/<project>/<name>:<git-sha>`（及可选 `:latest`）；TLS 与 Harbor 认证按集群侧 Secret 配置。

---

## 四、统一原则（Cursor 归纳）

1. **黄金命令**：每个子模块在 README 或 `mybuild/README.md` 写清一条本地/CI 等价的 `docker build` / Kaniko 参数。  
2. **禁止隐式依赖**：无 `dev:1.0`、无预置 `dist/`、CI 不引用 `.original` 等备份 Dockerfile（除非明确改名并审查语法）。  
3. **不展开 Celery**：tpl-app 无 Worker 镜像；业务线 Celery 另文。  
4. **实施顺序**：按 [build-images方案-claude.md](./build-images方案-claude.md) **§五 实施步骤** checklist 执行即可。

---

## 五、命名与 `build.conf`

| 子模块 | 提示 | 建议 |
|--------|------|------|
| tpl-web-frontend | `TPL_SSR_IMAGE=tpl-app-ssr` | 实例化时用 `init.sh` 等改为与目录/业务一致（如 `xxx-web-frontend`）。 |
| 其余 | 缺统一 `build.conf` | 补最小字段：`IMAGE_NAME`、`REGISTRY`、`PROJECT`；**TAG 由 CI 注入 git SHA**。 |

镜像全名与 Claude 版 §2.2 对齐时：`harbor.sunmoonai.com:30443/k8s-images/<service-name>:<git-sha>`（若选 `apps` 项目则全局替换 `k8s-images`）。

---

## 六、与 Claude 版分工（v2.1 互补关系）

| 维度 | 本文（Cursor） | [build-images方案-claude.md](./build-images方案-claude.md) |
|------|----------------|-----------------------------------------------------------|
| 侧重 | 范围边界、差距分级、Kaniko 表、原则、与 K8s 弱耦合 | **完整 Dockerfile/nginx 示例**、Harbor 缓存清单、**实施 checklist**、构建期变量附录 |
| 读者 | 评审架构 / 快速对齐「缺什么」 | 开发按章节落地改文件 |

**合并评审**：四模块清单、最终 Dockerfile 路径、Harbor project、是否仍引用 `Dockerfile.original`、构建 arg 是否与 Ingress 规划一致。

---

## 七、附录：tpl-app 内路径

| 说明 | 路径（相对 `tpl-app/`） |
|------|-------------------------|
| Web 前端 mybuild | `tpl-web-frontend/mybuild/` |
| Web 后端 mybuild | `tpl-web-backend/mybuild/`（主：`Dockerfile`；勿用 CI 指向 `Dockerfile.original`） |
| Admin 后端 | `tpl-admin-backend/app/Dockerfile` |
| Admin 前端 | `tpl-admin-frontend/`（待新建根目录 CI 用 `Dockerfile`） |

从本文件所在目录到 tpl-app：`../../../tpl-app/`。

---

*Cursor 版；由 Cursor 侧独立维护。编写时参考同目录 [build-images方案-claude.md](./build-images方案-claude.md)（Claude 原文，请勿在 Cursor 会话中修改该文件）中的 Dockerfile 样例、Kaniko 表与实施步骤；本文增补差距分级、`Dockerfile.original` 注记与精炼表。*
