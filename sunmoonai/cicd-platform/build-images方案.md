# tpl-app 镜像构建方案（面向 CICD 平台）

> 文档版本：v1.0 | 日期：2026-04-18
> 上下文：本文基于 `cicd总体架构及实施详细方案.md`（Argo Workflows + Kaniko + Harbor + GitOps），
> 全面评估 tpl-app 四个子模块的现有构建配置是否满足 CI Pipeline 要求，并给出改造方案。

---

## 一、现状评估与差距分析

### 1.1 四个子模块现状一览

| 子模块 | 技术栈 | Dockerfile 位置 | 现状评分 | 主要问题 |
|--------|--------|-----------------|----------|----------|
| tpl-admin-frontend | Vue 3 + Vite | 根目录（3个文件） | ⚠️ 不满足 | 依赖外部自定义镜像 `dev:1.0` |
| tpl-admin-backend | FastAPI + Python | `app/Dockerfile` | ⚠️ 基本可用 | 路径不规范，单阶段构建 |
| tpl-web-frontend | Next.js 16 | `mybuild/Dockerfile` | ✅ 基本满足 | 需要对齐 CI 规范 |
| tpl-web-backend | NestJS | `mybuild/Dockerfile` | ❌ 不满足 | `--mount=type=cache` Kaniko 不支持 |

### 1.2 问题详细说明

#### 问题 1：tpl-admin-frontend — 依赖外部自定义镜像（阻断性）

`Dockerfile-prod` 第一行：
```dockerfile
FROM dev:1.0 as build-stage   # ← 必须预先存在，CI 环境无法保证
```
Kaniko 在 CI Pod 中构建时，若 Harbor 中没有 `dev:1.0` 镜像则直接失败。

`Dockerfile`（简单版）要求 `dist/` 已预构建好才能运行：
```dockerfile
COPY dist/* /usr/share/nginx/html/   # ← dist/ 不存在时构建失败
```
两个 Dockerfile 均**不能直接用于 Kaniko CI**。

#### 问题 2：tpl-web-backend — Kaniko 不支持 BuildKit 缓存挂载（阻断性）

`mybuild/Dockerfile` 中的 `prod-deps` 阶段使用了 BuildKit 特性：
```dockerfile
RUN --mount=type=cache,id=pnpm,target=/root/.local/share/pnpm/store \
    pnpm install --prod --frozen-lockfile
```
Kaniko **不是 BuildKit**，不支持 `RUN --mount=type=cache`，会报错退出。

#### 问题 3：Dockerfile 路径不统一（规范性）

Argo Workflows `build-and-push` WorkflowTemplate 默认：
```yaml
- "--dockerfile=/workspace/source/Dockerfile"
```
而各子模块实际路径：

| 子模块 | 实际 Dockerfile 路径 |
|--------|---------------------|
| tpl-admin-frontend | `/Dockerfile-prod`（有问题）|
| tpl-admin-backend | `/app/Dockerfile` |
| tpl-web-frontend | `/mybuild/Dockerfile` |
| tpl-web-backend | `/mybuild/Dockerfile`（有问题）|

没有一个子模块在根目录有可用的 `Dockerfile`，WorkflowTemplate 需要为每个子模块单独配置路径。

#### 问题 4：镜像命名规范不统一（规范性）

- tpl-web-frontend 的 `build.conf` 定义了镜像名 `tpl-app-ssr`，不反映子模块实际名称
- 其他三个子模块无任何镜像命名配置
- 与 CICD 方案中 `harbor.sunmoonai.com:30443/k8s-images/<app-name>:<git-sha>` 规范不一致

#### 问题 5：tpl-admin-backend Dockerfile 位于 `app/` 子目录（规范性）

构建上下文根目录是子模块根，但 Dockerfile 在 `app/Dockerfile`，Kaniko 需要指定 `--dockerfile` 路径。

---

## 二、解决方案

### 2.1 总体原则

1. **每个子模块根目录放一个 CI 专用 `Dockerfile`**（命名为 `Dockerfile` 或 `Dockerfile.ci`）
2. **完全自包含**：不依赖任何预构建产物和外部自定义基础镜像
3. **所有基础镜像走 Harbor**：确保离线/内网环境可用
4. **不使用 `--mount=type=cache`**：兼容 Kaniko
5. **多阶段构建**：分离构建依赖与运行时，控制最终镜像大小

### 2.2 统一镜像命名规范

```
harbor.sunmoonai.com:30443/apps/<service-name>:<git-sha>
harbor.sunmoonai.com:30443/apps/<service-name>:latest
```

> 使用独立的 `apps` 项目区分应用镜像和基础设施镜像（`k8s-images`）

| 子模块 | 镜像名 |
|--------|--------|
| tpl-admin-frontend | `harbor.sunmoonai.com:30443/apps/tpl-admin-frontend` |
| tpl-admin-backend | `harbor.sunmoonai.com:30443/apps/tpl-admin-backend` |
| tpl-web-frontend | `harbor.sunmoonai.com:30443/apps/tpl-web-frontend` |
| tpl-web-backend | `harbor.sunmoonai.com:30443/apps/tpl-web-backend` |

> 注：项目从 tpl-app 实例化为具体项目（如 investment-app）后，`tpl-` 前缀随 `init.sh` 自动替换。

---

## 三、各子模块 Dockerfile 改造方案

### 3.1 tpl-admin-frontend（Vue 3 + Vite）

**改造要点**：
- 基础镜像全部改为 Harbor 缓存地址
- 完全自包含的多阶段构建（无 `dev:1.0` 依赖）
- pnpm 从 npmjs 镜像站安装（国内网络）

**文件**：`tpl-admin-frontend/Dockerfile`（新建，替代 `Dockerfile-prod`）

```dockerfile
# ── Stage 1: Build ──────────────────────────────────────────────────────────
FROM harbor.sunmoonai.com:30443/k8s-images/node:18-alpine AS build

WORKDIR /app

# 安装 pnpm（使用淘宝镜像加速）
RUN npm install -g pnpm --registry=https://registry.npmmirror.com

# 先复制 lockfile，利用 Docker 层缓存
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

COPY . .

# 接受构建时环境变量（CI 通过 --build-arg 注入）
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

# 支持 Vue Router history 模式
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

**同时需要创建** `tpl-admin-frontend/nginx.conf`：

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

**构建时 API URL 注入说明**：

Vue/Vite 的 `VITE_*` 变量在**构建时**静态嵌入 JS bundle，不是运行时环境变量。
因此 Kaniko 构建时必须传入真实 URL：

```yaml
# WorkflowTemplate 中 Kaniko 步骤增加 --build-arg
- "--build-arg=VITE_API_URL=https://tpl-admin-api.sunmoonai.com"
```

> ⚠️ 这意味着每个部署环境（dev/staging/prod）对应不同的镜像构建，或改用运行时配置注入方案（见附录 A）。

---

### 3.2 tpl-admin-backend（FastAPI + Python）

**改造要点**：
- 在子模块根目录增加 `Dockerfile`（CI 入口），内容与 `app/Dockerfile` 合并
- 改为多阶段构建（减小镜像体积）
- 基础镜像走 Harbor

**文件**：`tpl-admin-backend/Dockerfile`（新建）

```dockerfile
# ── Stage 1: Builder ─────────────────────────────────────────────────────────
FROM harbor.sunmoonai.com:30443/k8s-images/python:3.12-slim AS builder

WORKDIR /app

# 安装 uv
RUN pip install uv --no-cache-dir

COPY app/pyproject.toml app/uv.lock* ./
RUN uv sync --no-dev --no-cache

# ── Stage 2: Runtime ─────────────────────────────────────────────────────────
FROM harbor.sunmoonai.com:30443/k8s-images/python:3.12-slim AS run

WORKDIR /app

# 仅复制虚拟环境和源码，不含构建工具
COPY --from=builder /app/.venv ./.venv
COPY app/ ./

ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

### 3.3 tpl-web-frontend（Next.js 16）

**评估**：`mybuild/Dockerfile` 已是合格的多阶段构建，基本满足 Kaniko 要求。

**需要的改造**：
1. 将基础镜像替换为 Harbor 缓存路径
2. 确认 `run-minimal` target 是 CI 使用的目标（最小化生产镜像）

**文件**：`tpl-web-frontend/mybuild/Dockerfile`（改造现有文件）

```dockerfile
ARG NODE_VERSION=20.18.0
ARG REGISTRY=harbor.sunmoonai.com:30443/k8s-images

# ── Stage 1: Build ───────────────────────────────────────────────────────────
FROM ${REGISTRY}/node:${NODE_VERSION} AS build

# Sharp 所需系统依赖
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

**Kaniko 构建参数**：

```yaml
- "--build-arg=REGISTRY=harbor.sunmoonai.com:30443/k8s-images"
- "--build-arg=NEXT_PUBLIC_API_URL=https://tpl-api.sunmoonai.com/api"
- "--target=run-minimal"
```

---

### 3.4 tpl-web-backend（NestJS + TypeScript）

**核心改造**：移除所有 `RUN --mount=type=cache`，兼容 Kaniko。

**文件**：`tpl-web-backend/mybuild/Dockerfile`（改造现有文件）

```dockerfile
ARG NODE_VERSION=18.20.0
ARG REGISTRY=harbor.sunmoonai.com:30443/k8s-images

# ── Stage 1: Base ────────────────────────────────────────────────────────────
FROM ${REGISTRY}/node:${NODE_VERSION}-alpine AS base

RUN corepack enable && corepack prepare pnpm@latest --activate
WORKDIR /app
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# ── Stage 2: Prod Dependencies ───────────────────────────────────────────────
FROM base AS prod-deps

COPY app/package.json app/pnpm-lock.yaml ./
# ⚠️ 去掉 --mount=type=cache，Kaniko 不支持 BuildKit cache mount
RUN pnpm install --prod --frozen-lockfile

# ── Stage 3: Build ───────────────────────────────────────────────────────────
FROM base AS build

COPY app/package.json app/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

COPY app/ .

# 生成 Prisma client，编译 TypeScript
RUN pnpm run build:clients && pnpm run build:prod

# ── Stage 4: Runtime ─────────────────────────────────────────────────────────
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

## 四、Argo Workflows WorkflowTemplate 改造

现有 `build-and-push` WorkflowTemplate 使用单一 `--dockerfile=/workspace/source/Dockerfile`，
需要扩展以支持四个子模块的不同路径和构建参数。

### 4.1 扩展参数列表

```yaml
spec:
  arguments:
    parameters:
      - name: repo-url
      - name: revision
      - name: app-name
      - name: image-name
      - name: dockerfile-path    # 新增：Dockerfile 相对路径
        value: "Dockerfile"      # 默认根目录
      - name: build-target       # 新增：多阶段构建 target
        value: ""                # 空 = 不指定 target
      - name: build-args         # 新增：构建参数（逗号分隔）
        value: ""
```

### 4.2 Kaniko 步骤改造

```yaml
- name: kaniko-build
  inputs:
    parameters:
      - name: image-name
      - name: tag
      - name: dockerfile-path
      - name: build-target
      - name: build-args
  container:
    image: harbor.sunmoonai.com:30443/k8s-images/executor:v1.23.2-debug
    args:
      - "--context=/workspace/source"
      - "--dockerfile=/workspace/source/{{inputs.parameters.dockerfile-path}}"
      - "--destination=harbor.sunmoonai.com:30443/apps/{{inputs.parameters.image-name}}:{{inputs.parameters.tag}}"
      - "--destination=harbor.sunmoonai.com:30443/apps/{{inputs.parameters.image-name}}:latest"
      - "--insecure"
      - "--skip-tls-verify"
      - "--build-arg=REGISTRY=harbor.sunmoonai.com:30443/k8s-images"
      # target 和 build-args 通过脚本动态拼接（见下方 shell 方案）
```

> 注：Kaniko 参数不支持条件渲染，推荐将动态参数通过 shell wrapper 脚本传入，
> 或为每个子模块创建独立的 WorkflowTemplate。

### 4.3 各子模块 Sensor 触发配置

```yaml
# tpl-admin-frontend
arguments:
  - name: repo-url
    value: https://gitee.com/sunmoonlion/tpl-admin-frontend
  - name: app-name
    value: tpl-admin-frontend
  - name: image-name
    value: tpl-admin-frontend
  - name: dockerfile-path
    value: Dockerfile
  - name: build-args
    value: "VITE_API_URL=https://tpl-admin-api.sunmoonai.com"

# tpl-admin-backend
arguments:
  - name: repo-url
    value: https://gitee.com/sunmoonlion/tpl-admin-backend
  - name: app-name
    value: tpl-admin-backend
  - name: image-name
    value: tpl-admin-backend
  - name: dockerfile-path
    value: Dockerfile          # 根目录新建的 CI Dockerfile

# tpl-web-frontend
arguments:
  - name: repo-url
    value: https://gitee.com/sunmoonlion/tpl-web-frontend
  - name: app-name
    value: tpl-web-frontend
  - name: image-name
    value: tpl-web-frontend
  - name: dockerfile-path
    value: mybuild/Dockerfile
  - name: build-target
    value: run-minimal
  - name: build-args
    value: "NEXT_PUBLIC_API_URL=https://tpl-api.sunmoonai.com/api"

# tpl-web-backend
arguments:
  - name: repo-url
    value: https://gitee.com/sunmoonlion/tpl-web-backend
  - name: app-name
    value: tpl-web-backend
  - name: image-name
    value: tpl-web-backend
  - name: dockerfile-path
    value: mybuild/Dockerfile
  - name: build-target
    value: run
```

---

## 五、Harbor 项目初始化

在 Harbor 中创建 `apps` 项目（与 `k8s-images` 分开管理应用镜像）：

```bash
# 通过 Harbor API 创建项目
curl -u admin:${HARBOR_PASSWORD} \
  -X POST "https://harbor.sunmoonai.com:30443/api/v2.0/projects" \
  -H "Content-Type: application/json" \
  -d '{
    "project_name": "apps",
    "public": false,
    "metadata": {"public": "false"}
  }'
```

---

## 六、基础镜像预缓存清单

CICD 平台离线模式下，以下镜像需预先拉取并推送到 Harbor（补充到 `cicd总体架构` 文档的 5.1 节）：

```bash
# 应用构建基础镜像
node:18-alpine          → harbor.sunmoonai.com:30443/k8s-images/node:18-alpine
node:20.18.0            → harbor.sunmoonai.com:30443/k8s-images/node:20.18.0
node:20.18.0-alpine     → harbor.sunmoonai.com:30443/k8s-images/node:20.18.0-alpine
node:18.20.0-alpine     → harbor.sunmoonai.com:30443/k8s-images/node:18.20.0-alpine
python:3.12-slim        → harbor.sunmoonai.com:30443/k8s-images/python:3.12-slim
nginx:stable-alpine     → harbor.sunmoonai.com:30443/k8s-images/nginx:stable-alpine
```

---

## 七、实施清单（按优先级）

### Phase 0：前置改造（在 Phase 1 ArgoCD 部署前完成）

```
□ 在 Harbor 创建 apps 项目
□ 将所需基础镜像缓存到 Harbor k8s-images 项目
□ tpl-admin-frontend：创建 Dockerfile + nginx.conf（根目录）
□ tpl-admin-backend：创建 Dockerfile（根目录，多阶段）
□ tpl-web-frontend：改造 mybuild/Dockerfile（替换镜像源为 Harbor）
□ tpl-web-backend：改造 mybuild/Dockerfile（移除 --mount=type=cache）
□ 手动测试：docker build 各子模块新 Dockerfile，确认产物正常
□ 推送测试镜像到 Harbor apps 项目，确认认证和推送正常
```

### Phase 1-2 期间（配合 Argo Workflows 接入）

```
□ 扩展 build-and-push WorkflowTemplate（增加 dockerfile-path、build-target、build-args 参数）
□ 创建四个子模块各自的 Sensor 配置（各有独立触发端点）
□ 更新 Argo Events EventSource，增加四个子模块的 Webhook 端点
□ 在各 Gitee 子模块仓库配置 Webhook（指向 webhook.sunmoonai.com/push/<service>）
□ gitops-config 仓库增加四个服务的 Kustomize 结构
```

### 关于前端构建时环境变量的长期方案

> 当前 tpl-app 的前端（Vue 和 Next.js）都使用构建时环境变量（`VITE_*`/`NEXT_PUBLIC_*`）
> 这导致不同环境需要构建不同镜像，违背"同一镜像多环境部署"的 12-factor 原则。
>
> **推荐长期方案**：将 API URL 等配置改为运行时注入（见附录 A），实现一个镜像跑所有环境。
> 当前阶段（Phase 0）先维持现状，后续版本迭代时改造。

---

## 附录 A：Vue 3 运行时配置注入方案（可选）

通过在 nginx 容器启动时生成 `window.__ENV__` 配置文件，避免构建时硬编码：

**`nginx-entrypoint.sh`**：
```bash
#!/bin/sh
cat > /usr/share/nginx/html/env-config.js <<EOF
window.__ENV__ = {
  API_URL: "${VITE_API_URL}",
};
EOF
exec nginx -g "daemon off;"
```

**index.html 引入**（在 `<head>` 最前面）：
```html
<script src="/env-config.js"></script>
```

**Vue 代码中读取**：
```typescript
const apiUrl = (window as any).__ENV__?.API_URL ?? import.meta.env.VITE_API_URL;
```

K8s 通过 `ConfigMap` 注入环境变量，实现同一镜像多环境部署。

---

## 附录 B：镜像大小参考目标

| 子模块 | 当前估算 | 目标（改造后）|
|--------|---------|--------------|
| tpl-admin-frontend | nginx:~50MB | ~30MB（alpine nginx）|
| tpl-admin-backend | python:3.12-slim ~200MB | ~180MB（多阶段去掉构建工具）|
| tpl-web-frontend | node:20 ~1GB | ~200MB（standalone模式+alpine）|
| tpl-web-backend | node:18 ~500MB | ~200MB（alpine+仅生产依赖）|

---

*本方案与 `cicd总体架构及实施详细方案.md` 配套使用。*
*Phase 0 改造完成后，四个子模块即可直接接入 Argo Workflows CI Pipeline。*
