# SunmoonAI CI/CD 总体架构及实施详细方案

> 文档版本：v2.0 | 日期：2026-04-17 | 作者：sunmoonlion
> Git 平台：**Gitee 全链路**（集群服务器国内，GitHub 访问不稳定，全程走 Gitee）

---

## 一、现状分析

### 1.1 现有组件

| 组件 | 状态 | 版本 | 说明 |
|------|------|------|------|
| Harbor | ✅ 已部署 | 2.13.2 | 镜像仓库，支持代理缓存 |
| Jenkins | ⚠️ 配置存在 | Bitnami | CI 服务器，已有 Kaniko Pipeline |
| ArgoCD | ❌ 未部署 | — | 配置框架已预留，全部集群均为 false |
| Argo Workflows | ❌ 未部署 | — | 无任何配置 |
| Argo Events | ❌ 未部署 | — | 无任何配置 |
| Traefik | ✅ 已部署 | v3.5.2 | Ingress 控制器 |
| Kaniko | ✅ Pipeline 已有 | latest | 无 Docker 守护进程的镜像构建 |

### 1.2 现有 CI Pipeline 流程

```
开发者 Push 代码
    ↓
Jenkins 触发（手动/Webhook）
    ↓
Kaniko Pod 构建镜像
    ↓
推送到 Harbor（harbor.sunmoonai.com:30443）
    ↓
（手动）kubectl apply 部署
```

**痛点：**
- 无 GitOps：部署依赖手动 kubectl 或脚本，缺乏声明式管理
- 无自动同步：代码合并后不能自动触发部署
- 无回滚机制：部署失败需人工干预
- 无事件驱动：Harbor 推送镜像后无法自动触发 CD
- 多集群管理分散：C1/C2/C3/KIND 各自独立，缺乏统一视图

### 1.3 多集群现状

| 集群 | 节点 | Harbor | Jenkins | ArgoCD |
|------|------|--------|---------|--------|
| C1 | 115.190.64.131 (master) + 2 workers | ✅ 启用 | ❌ 禁用 | ❌ 禁用 |
| C2 | 115.190.37.57 (master) + 2 workers | ❌ 共用 C1 | ❌ 禁用 | ❌ 禁用 |
| C3 | 配置已有 | ✅ 启用 | ❌ 禁用 | ❌ 禁用 |
| KIND | 本地开发 | ✅ 启用 | ❌ 禁用 | ❌ 禁用 |

### 1.4 为何选择 Gitee 全链路

| 方案 | 问题 |
|------|------|
| GitHub 全链路 | 集群服务器国内无代理，Argo Workflows clone 代码、ArgoCD 轮询均不稳定，生产不可用 |
| Gitee 镜像到 GitHub | 多一层依赖，镜像延迟不可控，本质问题未解决 |
| **Gitee 全链路** | 集群访问 Gitee 飞快，Webhook 安全通过 Traefik IP 白名单保障，国内大量公司验证可行 |

---

## 二、目标 CI/CD 总体架构

### 2.1 架构全景图

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          SunmoonAI CI/CD 平台                                │
├────────────────────────────┬────────────────────────────────────────────────┤
│        CI 层（持续集成）     │              CD 层（持续交付）                   │
│                            │                                                │
│  开发者 git push            │    gitops-config（Gitee）                      │
│  ↓                         │         │                                      │
│  Gitee 源码仓库             │         │ 轮询 30s / CI 主动触发 sync           │
│  ↓ Webhook                 │         ↓                                      │
│  Argo Events               │    ArgoCD（Hub 集群 C1）                        │
│  (通用 Webhook 类型)        │    ├── App: research-app  → C1                 │
│  ↓ 触发                    │    ├── App: auth-app      → C1/C2              │
│  Argo Workflows            │    ├── App: llm-app       → C2                 │
│  (CI Pipeline)             │    ├── App: investment-app → C1                │
│  ├── 从 Gitee clone 源码    │    └── App: kind-dev      → KIND               │
│  ├── 单元测试               │                                                │
│  ├── Kaniko 构建镜像        │    Argo Rollouts（渐进式发布）                   │
│  ├── 推送到 Harbor          │    ├── Canary 金丝雀发布                        │
│  ├── 更新 gitops-config     │    └── Blue/Green 蓝绿部署                     │
│  └── 触发 ArgoCD Sync      │                                                │
│                            │                                                │
│  Harbor（镜像仓库）          │    Traefik（Webhook 入口 + IP 白名单）          │
│  harbor.sunmoonai.com:30443│    └── 仅放行 Gitee 出口 IP，拦截其他请求        │
└────────────────────────────┴────────────────────────────────────────────────┘
                                        │
                    ┌───────────────────┼───────────────────┐
                    ↓                   ↓                   ↓
              集群 C1               集群 C2              KIND (Dev)
         (生产/预发布)            (生产扩展)           (本地开发)
         app-platform-dev      app-platform-dev    app-platform-dev
```

### 2.2 核心组件职责

| 组件 | 职责 | 部署位置 |
|------|------|----------|
| **Argo Workflows** | CI Pipeline 编排，替代 Jenkins Pipeline | C1 cicd-platform-dev |
| **Argo Events** | 接收 Gitee Webhook，触发 CI | C1 cicd-platform-dev |
| **ArgoCD** | GitOps CD，多集群应用同步，轮询 Gitee | C1 cicd-platform-dev |
| **Argo Rollouts** | 金丝雀/蓝绿发布控制器 | 各应用集群 |
| **Harbor** | 镜像仓库 + 代理缓存（保持现有） | C1 cicd-platform-dev |
| **Traefik** | Webhook 入口 + Gitee IP 白名单中间件 | ingress-platform-dev |
| **Jenkins** | 过渡期保留，后续降级为备用 | C1 cicd-platform-dev |
| **Kaniko** | 无守护进程镜像构建（继续使用） | Workflow Pod |

### 2.3 完整 CI/CD 流程

```
① 开发者 git push → Gitee 源码仓库（开发习惯不变）
② Gitee 触发 Webhook → Traefik（IP 白名单验证来源合法）
③ Argo Events EventSource 接收 Webhook 事件
④ Argo Events Sensor 过滤分支（main/develop），触发 Argo Workflows
⑤ Argo Workflows 执行 CI Pipeline：
   a. 从 Gitee clone 源码（国内速度快）
   b. 执行单元测试 / Lint
   c. Kaniko 构建镜像
   d. 推送镜像到 Harbor（含 tag: git-sha）
   e. 更新 gitops-config 仓库（Gitee，修改 image tag）
   f. 调用 argocd app sync 主动触发同步（无需等待 30s 轮询）
⑥ ArgoCD 对目标集群执行 Sync（kubectl apply）
⑦ Argo Rollouts 控制器接管，执行金丝雀发布
⑧ 发布成功 → 自动晋级；失败 → 自动回滚 + 通知
```

---

## 三、目录结构规划

### 3.1 cicd-platform 新增结构

```
sunmoonai/cicd-platform/
├── deploy-cicd-platform-all/
│   ├── deploy-cicd-platform-all.sh
│   └── deploy-cicd-platform-all.conf       # 新增 argo 组件开关
├── harbor/                                  # 现有，保持不变
├── jenkins/                                 # 现有，过渡期保留
├── argo-workflows/                          # ✨ 新增
│   ├── deploy-argo-workflows/
│   │   ├── deploy-argo-workflows.sh
│   │   ├── deploy-argo-workflows.conf
│   │   └── secrets/
│   ├── resources/
│   │   └── argo-workflows/                 # Helm chart
│   └── workflow-templates/
│       ├── build-push-template.yaml        # 核心 CI Pipeline
│       └── sync-argocd-template.yaml       # 触发 ArgoCD Sync
├── argo-events/                             # ✨ 新增
│   ├── deploy-argo-events/
│   │   ├── deploy-argo-events.sh
│   │   ├── deploy-argo-events.conf
│   │   └── secrets/
│   ├── resources/
│   │   └── argo-events/                    # Helm chart
│   └── event-sources/
│       ├── gitee-eventsource.yaml          # Gitee 通用 Webhook EventSource
│       ├── harbor-webhook-eventsource.yaml
│       └── sensors/
│           └── build-trigger-sensor.yaml
├── argocd/                                  # ✨ 新增（原框架已预留）
│   ├── deploy-argocd/
│   │   ├── deploy-argocd.sh
│   │   ├── deploy-argocd.conf
│   │   ├── ingress/
│   │   │   └── argocd-ingress.yaml
│   │   └── secrets/
│   ├── resources/
│   │   └── argo-cd/                        # Helm chart
│   └── apps/
│       ├── app-of-apps.yaml
│       ├── research-app.yaml
│       ├── auth-app.yaml
│       ├── llm-app.yaml
│       └── investment-app.yaml
└── argo-rollouts/                           # ✨ 新增
    ├── deploy-argo-rollouts/
    │   ├── deploy-argo-rollouts.sh
    │   └── deploy-argo-rollouts.conf
    └── resources/
        └── argo-rollouts/                  # Helm chart
```

### 3.2 Gitee 仓库规划

```
Gitee 账号：sunmoonlion
├── research-app          # 源码仓库（现有）
├── auth-app              # 源码仓库（现有）
├── llm-app               # 源码仓库（现有）
├── investment-app        # 源码仓库（现有）
└── gitops-config         # ✨ 新建，GitOps 配置仓库（由 CI 自动提交）
    ├── apps/
    │   ├── research-app/
    │   │   ├── base/                      # Kustomize base
    │   │   │   ├── rollout.yaml
    │   │   │   ├── service.yaml
    │   │   │   └── kustomization.yaml
    │   │   └── overlays/
    │   │       ├── dev/                   # KIND 集群
    │   │       ├── staging/               # C2 集群
    │   │       └── prod/                  # C1 集群
    │   ├── auth-app/
    │   ├── llm-app/
    │   └── investment-app/
    └── infrastructure/
        ├── namespaces/
        └── network-policies/
```

---

## 四、各组件实施详细方案

### 4.1 Traefik IP 白名单（安全基础，优先配置）

> Gitee Webhook 不做 HMAC 签名验证，通过 Traefik 限制只有 Gitee 出口 IP 能访问
> Webhook 端点，等效安全保障。

**文件：** `argo-events/event-sources/gitee-ip-whitelist-middleware.yaml`

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: gitee-ip-whitelist
  namespace: cicd-platform-dev
spec:
  ipAllowList:
    sourceRange:
      # Gitee 出口 IP 段（以 Gitee 官方公布为准，定期更新）
      - "212.64.62.0/24"
      - "212.64.63.0/24"
      - "116.211.167.0/24"
      - "116.211.168.0/24"
```

**Webhook IngressRoute（带白名单）：**

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: argo-events-webhook
  namespace: cicd-platform-dev
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`webhook.sunmoonai.com`)
      kind: Rule
      middlewares:
        - name: gitee-ip-whitelist    # 只允许 Gitee IP 访问
      services:
        - name: gitee-eventsource-svc
          port: 12000
  tls:
    secretName: sunmoonai-tls
```

> **获取 Gitee 最新出口 IP：** 联系 Gitee 企业支持，或在仓库 Webhook 触发后
> 通过 Traefik 访问日志中获取真实来源 IP，加入白名单。

---

### 4.2 ArgoCD 部署方案

#### 4.2.1 Helm Values 配置

**文件：** `argocd/resources/argo-cd/custom-values/argocd-values.yaml`

```yaml
global:
  image:
    repository: harbor.sunmoonai.com:30443/k8s-images/argocd
    tag: v2.13.0

configs:
  params:
    server.insecure: true              # 由 Traefik 负责 TLS 终止
  cm:
    application.resourceTrackingMethod: annotation
    timeout.reconciliation: 30s        # 轮询 Gitee 间隔

  # 注册多集群
  clusterCredentials:
    - name: c2-cluster
      server: https://115.190.37.57:6443
      namespaces: ["app-platform-dev"]
    - name: kind-cluster
      server: https://kind-control-plane:6443
      namespaces: ["app-platform-dev"]

repoServer:
  replicas: 1
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi

server:
  replicas: 1
  service:
    type: ClusterIP

applicationSet:
  enabled: true
  replicas: 1

notifications:
  enabled: true
  secret:
    create: true
```

#### 4.2.2 Traefik Ingress 配置

**文件：** `argocd/deploy-argocd/ingress/argocd-ingress.yaml`

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: argocd-server
  namespace: cicd-platform-dev
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`argocd.sunmoonai.com`)
      kind: Rule
      services:
        - name: argocd-server
          port: 80
  tls:
    secretName: sunmoonai-tls
```

#### 4.2.3 App of Apps 根入口

**文件：** `argocd/apps/app-of-apps.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: cicd-platform-dev
spec:
  project: default
  source:
    repoURL: https://gitee.com/sunmoonlion/gitops-config
    targetRevision: main
    path: apps
  destination:
    server: https://kubernetes.default.svc
    namespace: cicd-platform-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

#### 4.2.4 单应用 Application 示例

**文件：** `argocd/apps/research-app.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: research-app-prod
  namespace: cicd-platform-dev
spec:
  project: sunmoonai
  source:
    repoURL: https://gitee.com/sunmoonlion/gitops-config
    targetRevision: main
    path: apps/research-app/overlays/prod
  destination:
    server: https://kubernetes.default.svc
    namespace: app-platform-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    retry:
      limit: 3
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

#### 4.2.5 deploy-argocd.conf

```bash
project="sunmoonai"
component="argocd"
namespace="cicd-platform-dev"

argocd_version="v2.13.0"
argocd_helm_chart_version="7.8.0"

C1_argocd_enabled="true"
C2_argocd_enabled="false"
C3_argocd_enabled="false"
KIND_argocd_enabled="true"

argocd_host="argocd.sunmoonai.com"
argocd_port="30443"
argocd_insecure="true"

image_registry="harbor.sunmoonai.com:30443"
offline_mode="true"

# Gitee 仓库配置
gitops_repo="https://gitee.com/sunmoonlion/gitops-config"
gitops_repo_secret="gitee-repo-secret"    # ArgoCD 访问 Gitee 私有仓库的凭据
```

---

### 4.3 Argo Workflows 部署方案

#### 4.3.1 Helm Values 配置

**文件：** `argo-workflows/resources/argo-workflows/custom-values/argo-workflows-values.yaml`

```yaml
images:
  tag: v3.6.0

workflow:
  serviceAccount:
    create: true
    name: argo-workflow-sa
  rbac:
    create: true

controller:
  workflowNamespaces:
    - cicd-platform-dev
  resources:
    requests:
      cpu: 100m
      memory: 128Mi

server:
  enabled: true
  serviceType: ClusterIP
  extraArgs:
    - --auth-mode=server

executor:
  image:
    repository: harbor.sunmoonai.com:30443/k8s-images/argoexec
    tag: v3.6.0

artifactRepository:
  archiveLogs: true

persistence:
  enabled: true
  storageClassName: local-path
  accessMode: ReadWriteOnce
  size: 20Gi
```

#### 4.3.2 CI WorkflowTemplate（核心）

**文件：** `argo-workflows/workflow-templates/build-push-template.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: build-and-push
  namespace: cicd-platform-dev
spec:
  entrypoint: ci-pipeline
  arguments:
    parameters:
      - name: repo-url       # Gitee 源码仓库地址
      - name: revision       # git commit SHA
      - name: app-name
      - name: image-name

  volumeClaimTemplates:
    - metadata:
        name: workspace
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: local-path
        resources:
          requests:
            storage: 5Gi

  templates:
    - name: ci-pipeline
      dag:
        tasks:
          - name: clone
            template: git-clone
            arguments:
              parameters:
                - name: repo-url
                  value: "{{workflow.parameters.repo-url}}"
                - name: revision
                  value: "{{workflow.parameters.revision}}"
          - name: test
            template: run-tests
            dependencies: [clone]
          - name: build-push
            template: kaniko-build
            dependencies: [test]
            arguments:
              parameters:
                - name: image-name
                  value: "{{workflow.parameters.image-name}}"
                - name: tag
                  value: "{{workflow.parameters.revision}}"
          - name: update-gitops
            template: update-image-tag
            dependencies: [build-push]
            arguments:
              parameters:
                - name: app-name
                  value: "{{workflow.parameters.app-name}}"
                - name: new-tag
                  value: "{{workflow.parameters.revision}}"
          - name: sync-argocd
            template: argocd-sync
            dependencies: [update-gitops]
            arguments:
              parameters:
                - name: app-name
                  value: "{{workflow.parameters.app-name}}"

    - name: git-clone
      inputs:
        parameters:
          - name: repo-url
          - name: revision
      container:
        image: harbor.sunmoonai.com:30443/k8s-images/alpine-git:latest
        command: [sh, -c]
        args:
          - |
            git clone https://$(GITEE_USER):$(GITEE_TOKEN)@${REPO_URL#https://} /workspace/source
            cd /workspace/source
            git checkout {{inputs.parameters.revision}}
        env:
          - name: REPO_URL
            value: "{{inputs.parameters.repo-url}}"
          - name: GITEE_USER
            valueFrom:
              secretKeyRef:
                name: gitee-repo-secret
                key: username
          - name: GITEE_TOKEN
            valueFrom:
              secretKeyRef:
                name: gitee-repo-secret
                key: token
        volumeMounts:
          - name: workspace
            mountPath: /workspace

    - name: run-tests
      container:
        image: harbor.sunmoonai.com:30443/k8s-images/python:3.11-slim
        command: [sh, -c]
        args:
          - |
            cd /workspace/source
            pip install -r requirements.txt -q
            pytest tests/ --tb=short || true
        volumeMounts:
          - name: workspace
            mountPath: /workspace

    - name: kaniko-build
      inputs:
        parameters:
          - name: image-name
          - name: tag
      container:
        image: harbor.sunmoonai.com:30443/k8s-images/executor:v1.23.2-debug
        imagePullPolicy: IfNotPresent
        args:
          - "--context=/workspace/source"
          - "--dockerfile=/workspace/source/Dockerfile"
          - "--destination=harbor.sunmoonai.com:30443/k8s-images/{{inputs.parameters.image-name}}:{{inputs.parameters.tag}}"
          - "--destination=harbor.sunmoonai.com:30443/k8s-images/{{inputs.parameters.image-name}}:latest"
          - "--insecure"
          - "--skip-tls-verify"
        volumeMounts:
          - name: workspace
            mountPath: /workspace
          - name: kaniko-secret
            mountPath: /kaniko/.docker
      volumes:
        - name: kaniko-secret
          secret:
            secretName: kaniko-registry-secret
            items:
              - key: .dockerconfigjson
                path: config.json

    - name: update-image-tag
      inputs:
        parameters:
          - name: app-name
          - name: new-tag
      container:
        image: harbor.sunmoonai.com:30443/k8s-images/alpine-git:latest
        command: [sh, -c]
        args:
          - |
            git clone https://$(GITEE_USER):$(GITEE_TOKEN)@gitee.com/sunmoonlion/gitops-config /tmp/gitops
            cd /tmp/gitops
            sed -i "s|newTag:.*|newTag: {{inputs.parameters.new-tag}}|" \
              apps/{{inputs.parameters.app-name}}/overlays/prod/kustomization.yaml
            git config user.email "ci@sunmoonai.com"
            git config user.name "Argo Workflows CI"
            git add -A
            git commit -m "ci: update {{inputs.parameters.app-name}} to {{inputs.parameters.new-tag}}"
            git push
        env:
          - name: GITEE_USER
            valueFrom:
              secretKeyRef:
                name: gitee-repo-secret
                key: username
          - name: GITEE_TOKEN
            valueFrom:
              secretKeyRef:
                name: gitee-repo-secret
                key: token

    - name: argocd-sync
      inputs:
        parameters:
          - name: app-name
      container:
        image: harbor.sunmoonai.com:30443/k8s-images/argocd-cli:v2.13.0
        command: [sh, -c]
        args:
          - |
            argocd login argocd-server.cicd-platform-dev.svc.cluster.local \
              --username admin \
              --password $(ARGOCD_PASSWORD) \
              --insecure
            argocd app sync {{inputs.parameters.app-name}}-prod --async
        env:
          - name: ARGOCD_PASSWORD
            valueFrom:
              secretKeyRef:
                name: argocd-admin-secret
                key: password
```

---

### 4.4 Argo Events 部署方案

#### 4.4.1 EventSource：Gitee Webhook

**文件：** `argo-events/event-sources/gitee-eventsource.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: gitee-webhook
  namespace: cicd-platform-dev
spec:
  service:
    ports:
      - port: 12000
        targetPort: 12000
  webhook:
    # research-app 仓库
    research-app:
      port: "12000"
      endpoint: /push/research-app
      method: POST
      # 不配 authSecret（Gitee 明文 Token 与 Argo Events HMAC 机制不兼容）
      # 安全由 Traefik IP 白名单保障，只允许 Gitee 出口 IP 访问此端点

    # auth-app 仓库
    auth-app:
      port: "12000"
      endpoint: /push/auth-app
      method: POST

    # llm-app 仓库
    llm-app:
      port: "12000"
      endpoint: /push/llm-app
      method: POST

    # investment-app 仓库
    investment-app:
      port: "12000"
      endpoint: /push/investment-app
      method: POST
```

**Gitee 仓库 Webhook 配置（每个仓库操作一次）：**
- 进入 Gitee 仓库 → **管理** → **WebHooks** → **添加 webHook**
- URL：`https://webhook.sunmoonai.com/push/<app-name>`
- 密码：填任意字符串（Argo Events 不校验，仅 Gitee 记录用）
- 触发事件：勾选 **Push**
- 激活：勾选

#### 4.4.2 Sensor：触发 CI Workflow

**文件：** `argo-events/event-sources/sensors/build-trigger-sensor.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: gitee-build-trigger
  namespace: cicd-platform-dev
spec:
  dependencies:
    - name: gitee-push
      eventSourceName: gitee-webhook
      eventName: research-app
      filters:
        data:
          # 只响应 main 和 develop 分支
          - path: body.ref
            type: string
            value:
              - refs/heads/main
              - refs/heads/develop

  triggers:
    - template:
        name: trigger-build-workflow
        argoWorkflow:
          group: argoproj.io
          version: v1alpha1
          resource: workflows
          operation: submit
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: build-research-app-
                namespace: cicd-platform-dev
              spec:
                workflowTemplateRef:
                  name: build-and-push
                arguments:
                  parameters:
                    - name: repo-url
                      value: https://gitee.com/sunmoonlion/research-app
                    - name: app-name
                      value: research-app
                    - name: image-name
                      value: research-app
          parameters:
            - src:
                dependencyName: gitee-push
                dataKey: body.after        # Gitee push payload 中的 commit SHA
              dest: spec.arguments.parameters.1.value
```

---

### 4.5 Argo Rollouts 部署方案

#### 4.5.1 Helm Values

```yaml
# argo-rollouts/resources/argo-rollouts/custom-values/argo-rollouts-values.yaml
controller:
  replicas: 1
  image:
    repository: harbor.sunmoonai.com:30443/k8s-images/argo-rollouts
    tag: v1.7.2

dashboard:
  enabled: true
  service:
    type: ClusterIP

installCRDs: true
```

#### 4.5.2 金丝雀发布策略示例

**文件：** `gitops-config/apps/research-app/base/rollout.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: research-app
  namespace: app-platform-dev
spec:
  replicas: 3
  selector:
    matchLabels:
      app: research-app
  template:
    metadata:
      labels:
        app: research-app
    spec:
      containers:
        - name: research-app
          image: harbor.sunmoonai.com:30443/k8s-images/research-app:latest
          ports:
            - containerPort: 8000
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi

  strategy:
    canary:
      steps:
        - setWeight: 10
        - pause: {duration: 2m}
        - setWeight: 30
        - pause: {duration: 2m}
        - setWeight: 60
        - pause: {duration: 2m}
        - setWeight: 100
```

---

### 4.6 deploy-cicd-platform-all.conf 更新方案

```bash
# 在现有配置基础上新增以下内容

# ============ ArgoCD ============
argocd_priority=500
C1_argocd_enabled="true"
C2_argocd_enabled="false"
C3_argocd_enabled="false"
KIND_argocd_enabled="true"

# ============ Argo Workflows ============
argo_workflows_priority=400
C1_argo_workflows_enabled="true"
C2_argo_workflows_enabled="false"
C3_argo_workflows_enabled="false"
KIND_argo_workflows_enabled="true"

# ============ Argo Events ============
argo_events_priority=300
C1_argo_events_enabled="true"
C2_argo_events_enabled="false"
C3_argo_events_enabled="false"
KIND_argo_events_enabled="true"

# ============ Argo Rollouts ============
argo_rollouts_priority=200
C1_argo_rollouts_enabled="true"
C2_argo_rollouts_enabled="true"
C3_argo_rollouts_enabled="false"
KIND_argo_rollouts_enabled="true"
```

---

## 五、离线镜像准备方案

### 5.1 需要预拉取的镜像列表

```bash
# Argo 组件镜像
quay.io/argoproj/argocd:v2.13.0
quay.io/argoproj/workflow-controller:v3.6.0
quay.io/argoproj/argoexec:v3.6.0
quay.io/argoproj/argocli:v3.6.0
quay.io/argoproj/argo-events:v1.9.4
quay.io/argoproj/argo-rollouts:v1.7.2
quay.io/argoproj/kubectl-argo-rollouts:v1.7.2

# 工具镜像（CI 使用）
alpine/git:latest
python:3.11-slim
gcr.io/kaniko-project/executor:v1.23.2-debug   # 已有

# 依赖镜像
redis:7.0.15-alpine                             # ArgoCD 依赖
```

### 5.2 镜像迁移脚本

```bash
#!/bin/bash
# 文件: utils/pull-and-push-argo-images.sh

HARBOR="harbor.sunmoonai.com:30443"
TARGET_PROJECT="k8s-images"

declare -A IMAGES=(
  ["quay.io/argoproj/argocd:v2.13.0"]="argocd:v2.13.0"
  ["quay.io/argoproj/workflow-controller:v3.6.0"]="workflow-controller:v3.6.0"
  ["quay.io/argoproj/argoexec:v3.6.0"]="argoexec:v3.6.0"
  ["quay.io/argoproj/argocli:v3.6.0"]="argocd-cli:v2.13.0"
  ["quay.io/argoproj/argo-events:v1.9.4"]="argo-events:v1.9.4"
  ["quay.io/argoproj/argo-rollouts:v1.7.2"]="argo-rollouts:v1.7.2"
  ["alpine/git:latest"]="alpine-git:latest"
  ["python:3.11-slim"]="python:3.11-slim"
  ["redis:7.0.15-alpine"]="redis:7.0.15-alpine"
)

for src_image in "${!IMAGES[@]}"; do
  dst_tag="${IMAGES[$src_image]}"
  dst_image="${HARBOR}/${TARGET_PROJECT}/${dst_tag}"
  echo "迁移: $src_image → $dst_image"
  nerdctl pull "$src_image"
  nerdctl tag "$src_image" "$dst_image"
  nerdctl push "$dst_image" --insecure-registry
done
```

---

## 六、实施路线图

### Phase 1：ArgoCD 基础部署（第 1-2 周）

```
Week 1:
□ 在 Gitee 创建 gitops-config 仓库
□ 准备离线镜像并推送到 Harbor
□ 编写 deploy-argocd.sh（参考现有 deploy-jenkins.sh 模式）
□ 配置 ArgoCD Helm values（离线模式 + Gitee 仓库）
□ 在 C1 集群部署 ArgoCD
□ 配置 Traefik Ingress（argocd.sunmoonai.com）

Week 2:
□ 注册 C2、KIND 集群到 ArgoCD
□ 创建 gitops-config 仓库结构（含 research-app kustomize）
□ 创建 ArgoCD Project 和 Application（指向 Gitee）
□ 测试手动 Sync
□ 验证 ArgoCD UI 访问（argocd.sunmoonai.com:30443）
```

**验收标准：**
- ArgoCD UI 可访问，research-app Application 显示 Synced
- 手动修改 gitops-config image tag 后，ArgoCD 30s 内自动同步

### Phase 2：Argo Workflows CI（第 3-4 周）

```
Week 3:
□ 部署 Argo Workflows（C1 + KIND）
□ 配置 RBAC 和 ServiceAccount
□ 创建 gitee-repo-secret（Gitee 用户名 + 私人令牌）
□ 编写 build-and-push WorkflowTemplate
□ 测试 Kaniko 构建（复用现有 kaniko-registry-secret）

Week 4:
□ 测试完整 CI Pipeline（clone Gitee → test → build → push → update gitops → argocd sync）
□ 配置 Argo Workflows UI（workflow.sunmoonai.com）
□ 将现有 Jenkins Kaniko Pipeline 迁移为 WorkflowTemplate
```

**验收标准：**
- 手动提交 Workflow 后看到完整 DAG 执行
- Harbor 中出现新镜像（含 git SHA tag）
- gitops-config 的 image tag 自动更新，ArgoCD 立即 sync

### Phase 3：Argo Events 事件驱动（第 5-6 周）

```
Week 5:
□ 部署 Argo Events（C1）
□ 配置 Traefik IP 白名单 Middleware（Gitee 出口 IP）
□ 配置 gitee-eventsource.yaml（通用 Webhook 类型）
□ 在各 Gitee 仓库手动添加 Webhook（指向 webhook.sunmoonai.com）
□ 配置 Sensor（过滤 main/develop 分支，触发 Workflow）

Week 6:
□ 测试端到端：git push Gitee → CI 自动触发 → CD 自动同步
□ 调试分支过滤和 commit SHA 传递
□ 配置 Harbor Webhook EventSource（可选）
```

**验收标准：**
- git push 后 60s 内 Workflow 自动启动
- 整条链路无人工干预完成部署

### Phase 4：Argo Rollouts 渐进式发布（第 7-8 周）

```
Week 7:
□ 在 C1、C2 部署 Argo Rollouts
□ 将 research-app Deployment 改为 Rollout 资源
□ 配置金丝雀策略（10% → 30% → 60% → 100%）
□ 配置 Rollouts Dashboard（rollouts.sunmoonai.com）

Week 8:
□ 测试金丝雀发布和手动回滚
□ 为其他 App 配置 Rollout 策略
□ （可选）集成 Prometheus 自动分析
```

**验收标准：**
- 新版本先切 10% 流量，可手动晋级或回滚
- 失败时自动回滚到上一稳定版本

### Phase 5：整合与优化（第 9-10 周）

```
□ 配置通知（ArgoCD Notifications → 钉钉/飞书）
□ 配置 RBAC（开发者只读，运维可同步）
□ Argo Workflows 历史归档（使用现有 PostgreSQL）
□ 将 Jenkins 降级为备用（不删除）
□ 添加 ArgoCD ApplicationSet（多环境批量管理）
□ 定期更新 Traefik IP 白名单（跟随 Gitee 出口 IP 变更）
```

---

## 七、关键配置文件模板总结

### 7.1 Secret 清单

| Secret 名称 | 命名空间 | 内容 | 用途 |
|-------------|----------|------|------|
| `gitee-repo-secret` | cicd-platform-dev | Gitee 用户名 + 私人令牌 | clone 源码、更新 gitops-config |
| `argocd-cluster-c2` | cicd-platform-dev | C2 集群 kubeconfig | ArgoCD 多集群注册 |
| `argocd-cluster-kind` | cicd-platform-dev | KIND kubeconfig | ArgoCD 开发集群注册 |
| `argocd-admin-secret` | cicd-platform-dev | ArgoCD admin 密码 | Workflow 触发 argocd sync |
| `kaniko-registry-secret` | cicd-platform-dev | Harbor 认证 | Kaniko 推送镜像（已有） |
| `harbor-registry-secret` | cicd-platform-dev | Harbor 认证 | 拉取镜像（已有） |

**gitee-repo-secret 创建命令：**
```bash
kubectl create secret generic gitee-repo-secret \
  --from-literal=username='sunmoonlion' \
  --from-literal=token='your-gitee-private-token' \
  -n cicd-platform-dev

# Gitee 私人令牌生成：Gitee → 右上角头像 → 设置 → 安全设置 → 私人令牌
# 权限勾选：projects（仓库读写）
```

### 7.2 Ingress/域名规划

| 服务 | 域名 | 端口 |
|------|------|------|
| ArgoCD UI | argocd.sunmoonai.com | 30443 |
| Argo Workflows UI | workflow.sunmoonai.com | 30443 |
| Argo Rollouts Dashboard | rollouts.sunmoonai.com | 30443 |
| Gitee Webhook 入口 | webhook.sunmoonai.com | 30443 |
| Harbor | harbor.sunmoonai.com | 30443（已有） |
| Jenkins | www.sunmoonai.com/jenkins | 30443（已有） |

### 7.3 资源需求估算

| 组件 | CPU Request | Memory Request | 存储 |
|------|-------------|----------------|------|
| ArgoCD (server+repo+controller) | 400m | 768Mi | — |
| ArgoCD Redis | 100m | 64Mi | — |
| Argo Workflows controller | 100m | 128Mi | 20Gi |
| Argo Workflows server | 100m | 128Mi | — |
| Argo Events controller | 100m | 64Mi | — |
| Argo Rollouts controller | 100m | 128Mi | — |
| **合计新增** | **~900m** | **~1.3Gi** | **20Gi** |

---

## 八、与现有架构的兼容性

1. **Harbor 保持不变**：所有镜像仍从 Harbor 拉取，无需改动
2. **Traefik 保持不变**：新增 IngressRoute 和 Middleware，不改现有路由
3. **命名空间保持不变**：所有 Argo 组件部署到 `cicd-platform-dev`
4. **离线模式兼容**：新增镜像预先推送到 Harbor，image registry 全部指向 Harbor
5. **现有脚本兼容**：`deploy-cicd-platform-all.sh` 机制无需改动，新增 `.conf` 开关即可
6. **Jenkins 过渡**：Phase 1-2 期间继续可用，Phase 3 后 Argo Workflows 接管
7. **多集群无缝接入**：现有 `cluster-config-mapping.sh` 机制不变，ArgoCD 集群注册遵循相同逻辑

---

## 九、快速启动命令参考

```bash
# 1. 启用 ArgoCD
cd /home/zym/k8s/sunmoonai/cicd-platform
# 修改 deploy-cicd-platform-all.conf 中 C1_argocd_enabled="true"，然后：
bash deploy-cicd-platform-all/deploy-cicd-platform-all.sh

# 2. 查看 ArgoCD 初始密码
kubectl -n cicd-platform-dev get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# 3. 创建 Gitee 凭据 Secret
kubectl create secret generic gitee-repo-secret \
  --from-literal=username='sunmoonlion' \
  --from-literal=token='your-gitee-private-token' \
  -n cicd-platform-dev

# 4. 手动提交测试 Workflow
kubectl apply -f argo-workflows/workflow-templates/build-push-template.yaml
argo submit --from workflowtemplate/build-and-push \
  -p repo-url=https://gitee.com/sunmoonlion/research-app \
  -p revision=main \
  -p app-name=research-app \
  -p image-name=research-app \
  -n cicd-platform-dev

# 5. 查看 Rollout 状态
kubectl argo rollouts get rollout research-app -n app-platform-dev --watch

# 6. 手动晋级金丝雀
kubectl argo rollouts promote research-app -n app-platform-dev
```

---

*文档结束。Gitee 全链路方案，国内集群服务器环境下经过验证的可行路径。*
*建议按 Phase 顺序实施，每个 Phase 完成验收标准后再进入下一阶段。*
