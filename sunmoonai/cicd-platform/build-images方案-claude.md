# tpl-app 镜像构建方案（Claude 版）

> 版本：v3.0 | 日期：2026-04-18  
> **范围**：`/home/zym/tpl-app` 四个子模块的镜像构建。不涉及 Celery、`app-platform` 部署树、`generate-app.conf`。  
> 背景：构建产物最终接入 Argo Workflows + Kaniko + Harbor；本文聚焦 **Dockerfile 实现与 Kaniko 参数**，不展开流水线 YAML。  
> 并列文档：[build-images方案-cursor.md](./build-images方案-cursor.md)（范围边界、差距分级、原则归纳）。

---

## 一、目标与验收标准

| 维度 | 验收要点 |
|------|----------|
| **可复现** | 固定基础镜像 tag + 锁文件（`pnpm-lock.yaml` / `uv.lock`），同一 commit 构建出相同 digest |
| **可追溯** | 主 tag 为不可变 `<git-sha>`；`latest` 仅作移动引用用于开发联调，生产以 SHA 为准 |
| **Kaniko 兼容** | 禁止 BuildKit 专属语法（`RUN --mount=type=cache` 等）；禁止依赖未预先推送 Harbor 的私有基础镜像 |
| **自包含** | 不在构建中假设已手工生成 `dist/`；所有构建步骤在 Dockerfile 内完成 |
| **离线可用** | 所有基础镜像走 Harbor 缓存，内网环境无需访问 DockerHub |
| **GitOps 衔接** | CI 构建后更新 gitops-config 中对应服务的 image tag，ArgoCD 可 sync |
| **过渡期兼容** | Argo Workflows 上线前，Jenkins + Kaniko 按同一命名/tag 规则执行，语义不分裂 |

---

## 二、现状评估

### 2.1 四子模块速览

| 子模块 | 技术栈 | Dockerfile 位置 | CI 就绪度 |
|--------|--------|-----------------|-----------|
| tpl-admin-frontend | Vue 3 + Vite (CSR) | 根目录（3 个文件）| ❌ 阻断 |
| tpl-admin-backend | FastAPI + Python 3.12 | `app/Dockerfile` | ⚠️ 路径不规范 |
| tpl-web-frontend | Next.js 16 (SSR) | `mybuild/Dockerfile` | ✅ 小改即可 |
| tpl-web-backend | NestJS + TypeScript | `mybuild/Dockerfile` | ⚠️ 注意勿用备份文件 |

### 2.2 问题详情

#### ❌ 阻断：tpl-admin-frontend

`Dockerfile-prod` 依赖未在 Harbor 中预置的自定义镜像：
```dockerfile
FROM dev:1.0 as build-stage   # CI Pod 中不存在，构建直接失败
```
`Dockerfile`（简单版）要求 `dist/` 预先构建好，同样不可用于 CI。

**解法**：新建根目录自包含多阶段 `Dockerfile`（见 §三）。

#### ⚠️ 路径不规范：tpl-admin-backend

Dockerfile 在 `app/Dockerfile` 而非子模块根目录，Kaniko `--dockerfile` 需单独指定。

**解法**：在子模块根目录新建 CI 用 `Dockerfile`，原 `app/Dockerfile` 保留供本地开发。

#### ⚠️ 注意备份文件：tpl-web-backend

当前主文件 **`mybuild/Dockerfile`** 已用普通 `RUN pnpm install`（Kaniko 友好）。  
**`mybuild/Dockerfile.original`** 仍含 `RUN --mount=type=cache`（Kaniko 不支持）。

**结论**：主 Dockerfile 本身无需改造，**CI 必须只引用主 `Dockerfile`，严禁指向 `.original`**。

#### ⚠️ 共性：基础镜像未走 Harbor

所有 Dockerfile 直接引用 DockerHub，内网/离线构建失败。需替换为 Harbor 缓存路径（见 §四）。

#### ⚠️ 共性：前端构建时环境变量

`VITE_*` / `NEXT_PUBLIC_*` 在构建时静态嵌入 bundle，不同环境须构建不同镜像，CI 通过 `--build-arg` 注入真实值。

---

## 三、各子模块 Dockerfile 方案

### 3.1 tpl-admin-frontend（Vue 3 + Vite）

**新建**：`tpl-admin-frontend/Dockerfile`

```dockerfile
# ── Stage 1: Build ──────────────────────────────────────────────────────────
FROM harbor.sunmoonai.com:30443/k8s-images/node:18-alpine AS build

WORKDIR /app

RUN npm install -g pnpm --registry=https://registry.npmmirror.com

COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

COPY . .

# VITE_* 构建时静态嵌入，CI 通过 --build-arg 注入
ARG VITE_API_URL
ARG VITE_MOCK_ENABLE=false
ARG VITE_PWA_DEBUG=false
ENV VITE_API_URL=$VITE_API_URL \
    VITE_MOCK_ENABLE=$VITE_MOCK_ENABLE \
    VITE_PWA_DEBUG=$VITE_PWA_DEBUG

RUN pnpm run build

# ── Stage 2: Serve ───────────────────────────────────────────────────────────
FROM harbor.sunmoonai.com:30443/k8s-images/nginx:stable-alpine AS run

COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

**新建**：`tpl-admin-frontend/nginx.conf`

```nginx
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /health {
        return 200 "ok";
        add_header Content-Type text/plain;
    }
}
```

---

### 3.2 tpl-admin-backend（FastAPI + Python 3.12）

**新建**：`tpl-admin-backend/Dockerfile`（子模块根目录，多阶段）

```dockerfile
# ── Stage 1: Builder ─────────────────────────────────────────────────────────
FROM harbor.sunmoonai.com:30443/k8s-images/python:3.12-slim AS builder

WORKDIR /app

RUN pip install uv --no-cache-dir

COPY app/pyproject.toml app/uv.lock* ./
RUN uv sync --no-dev --no-cache

# ── Stage 2: Runtime ─────────────────────────────────────────────────────────
FROM harbor.sunmoonai.com:30443/k8s-images/python:3.12-slim AS run

WORKDIR /app

COPY --from=builder /app/.venv ./.venv
COPY app/ ./

ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

> 原 `app/Dockerfile` 保留，供本地在 `app/` 目录内直接使用。

---

### 3.3 tpl-web-frontend（Next.js 16）

**改造**：`tpl-web-frontend/mybuild/Dockerfile`  
改动点：基础镜像替换为 Harbor 路径；通过 `ARG REGISTRY` 参数化。

```dockerfile
ARG NODE_VERSION=20.18.0
ARG REGISTRY=harbor.sunmoonai.com:30443/k8s-images

# ── Stage 1: Build ───────────────────────────────────────────────────────────
FROM ${REGISTRY}/node:${NODE_VERSION} AS build

RUN apt-get update && apt-get install -y --no-install-recommends \
    libvips-dev libglib2.0-dev python3 make g++ \
    && rm -rf /var/lib/apt/lists/*

RUN corepack enable && corepack prepare pnpm@9.12.3 --activate

WORKDIR /app
COPY app/package.json app/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

COPY app/ .

ARG NEXT_PUBLIC_API_URL
ARG NEXT_PUBLIC_APP_NAME=tpl
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL \
    NEXT_PUBLIC_APP_NAME=$NEXT_PUBLIC_APP_NAME

RUN pnpm build

# ── Stage 2: Minimal Runtime ─────────────────────────────────────────────────
FROM ${REGISTRY}/node:${NODE_VERSION}-alpine AS run-minimal

RUN apk add --no-cache vips

WORKDIR /app
ENV NODE_ENV=production

COPY --from=build /app/.next/standalone ./
COPY --from=build /app/.next/static ./.next/static
COPY --from=build /app/public ./public

EXPOSE 3000
CMD ["node", "server.js"]
```

---

### 3.4 tpl-web-backend（NestJS + TypeScript）

**改造**：`tpl-web-backend/mybuild/Dockerfile`  
改动点：基础镜像替换为 Harbor 路径；通过 `ARG REGISTRY` 参数化。（主文件已无 `--mount`，无需其他改动）

```dockerfile
ARG NODE_VERSION=18.20.0
ARG REGISTRY=harbor.sunmoonai.com:30443/k8s-images

# ── Stage 1: Base ────────────────────────────────────────────────────────────
FROM ${REGISTRY}/node:${NODE_VERSION}-alpine AS base

RUN corepack enable && corepack prepare pnpm@latest --activate
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app

# ── Stage 2: 生产依赖 ────────────────────────────────────────────────────────
FROM base AS prod-deps

COPY app/package.json app/pnpm-lock.yaml ./
RUN pnpm install --prod --frozen-lockfile

# ── Stage 3: 构建 ────────────────────────────────────────────────────────────
FROM base AS build

COPY app/package.json app/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

COPY app/ .
RUN pnpm run build:clients && pnpm run build:prod

# ── Stage 4: 运行时 ──────────────────────────────────────────────────────────
FROM ${REGISTRY}/node:${NODE_VERSION}-alpine AS run

WORKDIR /app
ENV NODE_ENV=production

COPY --from=prod-deps /app/node_modules ./node_modules
COPY --from=build /app/prisma ./prisma
COPY --from=build /app/dist ./dist

USER appuser
EXPOSE 8000
CMD ["node", "dist/main.js"]
```

---

## 四、基础镜像 Harbor 预缓存清单

构建前须将以下镜像推送到 Harbor `k8s-images` 项目：

| 原始镜像 | Harbor 缓存路径 |
|----------|----------------|
| `node:18-alpine` | `harbor.sunmoonai.com:30443/k8s-images/node:18-alpine` |
| `node:20.18.0` | `harbor.sunmoonai.com:30443/k8s-images/node:20.18.0` |
| `node:20.18.0-alpine` | `harbor.sunmoonai.com:30443/k8s-images/node:20.18.0-alpine` |
| `node:18.20.0-alpine` | `harbor.sunmoonai.com:30443/k8s-images/node:18.20.0-alpine` |
| `python:3.12-slim` | `harbor.sunmoonai.com:30443/k8s-images/python:3.12-slim` |
| `nginx:stable-alpine` | `harbor.sunmoonai.com:30443/k8s-images/nginx:stable-alpine` |

---

## 五、镜像命名规范

```
harbor.sunmoonai.com:30443/k8s-images/<service-name>:<tag>
```

| 子模块 | 镜像名 | Tag |
|--------|--------|-----|
| tpl-admin-frontend | `k8s-images/tpl-admin-frontend` | `<git-sha>` + `latest` |
| tpl-admin-backend | `k8s-images/tpl-admin-backend` | `<git-sha>` + `latest` |
| tpl-web-frontend | `k8s-images/tpl-web-frontend` | `<git-sha>` + `latest` |
| tpl-web-backend | `k8s-images/tpl-web-backend` | `<git-sha>` + `latest` |

> tpl-app 实例化后 `tpl-` 前缀随 `init.sh` 自动替换。  
> `tpl-web-frontend/mybuild/build.conf` 中历史镜像名 `tpl-app-ssr` 与上表不一致，实例化时一并修正。

---

## 六、Kaniko 构建参数汇总

| 子模块 | `--dockerfile` | `--target` | 关键 `--build-arg` |
|--------|----------------|------------|---------------------|
| tpl-admin-frontend | `Dockerfile` | — | `VITE_API_URL` |
| tpl-admin-backend | `Dockerfile` | — | — |
| tpl-web-frontend | `mybuild/Dockerfile` | `run-minimal` | `NEXT_PUBLIC_API_URL`、`REGISTRY` |
| tpl-web-backend | `mybuild/Dockerfile` | `run` | `REGISTRY` |

所有子模块公共参数：

```
--context=/workspace/source
--destination=harbor.sunmoonai.com:30443/k8s-images/<name>:<git-sha>
--destination=harbor.sunmoonai.com:30443/k8s-images/<name>:latest
--insecure
--skip-tls-verify
```

---

## 七、安全规范

- **Harbor 认证**：Kaniko 使用 `kaniko-registry-secret`（Robot Account）以 Secret 挂载至 `/kaniko/.docker/config.json`，不写入 Dockerfile 或 Git 历史
- **运行时密钥**：数据库密码、Redis ACL、Casdoor Secret 等仅通过 K8s Secret / ConfigMap 注入，不 `COPY .env` 进镜像（`.dockerignore` 已排除）
- **非 root**：NestJS 运行时镜像使用非特权用户 `appuser`
- **代理**：如需构建代理通过 `--build-arg HTTP_PROXY=...` 传入；`NO_PROXY` 须包含 Harbor 与 Gitee 内网地址

---

## 八、实施步骤

```
□ 1. 将基础镜像推送到 Harbor k8s-images（见 §四）
□ 2. tpl-admin-frontend：新建 Dockerfile + nginx.conf（见 §3.1）
□ 3. tpl-admin-backend：新建根目录 Dockerfile（见 §3.2）
□ 4. tpl-web-frontend：改造 mybuild/Dockerfile 替换镜像源（见 §3.3）
□ 5. tpl-web-backend：改造 mybuild/Dockerfile 替换镜像源；确认 CI 只引用主 Dockerfile（见 §3.4）
□ 6. 本地验证：docker build 各子模块，确认容器可正常启动
□ 7. 推送测试镜像到 Harbor，验证 <name>:<git-sha> 格式正确
□ 8. 接入 Argo Workflows WorkflowTemplate，按 §六 配置各子模块参数
□ 9. 过渡期：Jenkins Pipeline 按相同命名/tag 规则执行，与新方案语义对齐
```

---

## 附录：前端构建时变量的长期改进方向

`VITE_*` / `NEXT_PUBLIC_*` 静态嵌入 bundle，导致"一个环境一套镜像"。  
若后续需要"同一镜像多环境部署"，可改为运行时注入：

- **Vue**：nginx 启动时生成 `window.__ENV__` JS 文件，内容由 K8s ConfigMap 挂载的环境变量填充
- **Next.js**：去掉 `NEXT_PUBLIC_` 前缀，改在服务端读取 `process.env`，由 K8s 运行时注入

当前阶段维持构建时注入，实例化到具体项目后按需改造。
