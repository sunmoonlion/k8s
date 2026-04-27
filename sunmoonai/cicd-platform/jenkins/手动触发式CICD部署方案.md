# 手动触发式 CI/CD 部署方案

> 适用项目：investment-app（及基于 tpl-app 派生的同类项目）  
> 策略：**Jenkins 只做触发器 + 日志仓库，实际构建/推送/部署全部由 `mybuild/` 脚本完成**

---

## 一、设计思路

### 为什么不用标准 Jenkins Pipeline

标准 Pipeline（Jenkinsfile + 各阶段 DSL）的价值在于：多人协作的一致性执行、多环境流转、审批门控。对于当前小团队 + 自建基础设施的场景，引入完整 Pipeline 的代价大于收益：

- 需要把 mybuild 脚本的逻辑在 Jenkinsfile 里重写一遍，等于维护两套
- 本地和 CI 行为不同，调试成本高
- 项目迭代快，流程过早固化会变成拖累

### 当前方案分工

| 职责 | 谁来做 |
|------|--------|
| 监听仓库 push 事件（Gitee Webhook） | Jenkins |
| Harbor 凭据、SSH Key 安全存储 | Jenkins Credentials |
| 构建日志与历史记录 | Jenkins |
| 构建镜像、打 tag、推 Harbor | `mybuild/build-image.sh` + `push-image.sh` |
| 部署到 k8s | `mybuild/` 或 k8s deploy 脚本（待补充） |

Jenkins Job 本体只是一个薄薄的 shell 胶水，调 mybuild 脚本即可。

---

## 二、前置条件

### Jenkins Agent 环境要求

| 工具 | 说明 |
|------|------|
| `docker` | 构建并推送镜像，需能访问 Harbor |
| `kubectl` | 部署到 k8s（需配置 kubeconfig） |
| `git` | 拉取代码 |
| Harbor 登录 | `docker login harbor.sunmoonai.com:30443`（用 Jenkins Credentials 注入） |

### Jenkins Credentials 配置

在 Jenkins → Manage Credentials 中添加：

| ID | 类型 | 说明 |
|----|------|------|
| `harbor-credentials` | Username/Password | Harbor 登录凭据（推送镜像用） |
| `gitee-webhook-secret` | Secret text | Gitee Webhook 签名密钥（可选，用于验签） |

---

## 三、mybuild 脚本说明

每个子模块下的 `mybuild/` 目录结构一致：

```
mybuild/
├── build.conf          # 镜像名、tag、registry 等配置
├── build-image.sh      # 构建镜像（读 build.conf）
├── push-image.sh       # 推送到 Harbor（读 HARBOR_USER/HARBOR_PASSWORD 环境变量）
├── rebuild-and-run.sh  # 本地开发用：重建并直接 docker run
└── Dockerfile
```

### 四个子模块

| 子模块 | 目录 | Harbor 镜像名 |
|--------|------|--------------|
| investment-web-backend | `investment-web-backend/mybuild/` | `harbor.sunmoonai.com:30443/app-images/investment-web-backend:<tag>` |
| investment-admin-backend | `investment-admin-backend/mybuild/` | `harbor.sunmoonai.com:30443/app-images/investment-admin-backend:<tag>` |
| investment-web-frontend | `investment-web-frontend/mybuild/` | `harbor.sunmoonai.com:30443/app-images/investment-web-frontend:<tag>` |
| investment-admin-frontend | `investment-admin-frontend/mybuild/` | `harbor.sunmoonai.com:30443/app-images/investment-admin-frontend:<tag>` |

### 手动构建单个服务（本地操作）

```bash
# 以 web-backend 为例
cd investment-web-backend/mybuild

# 1. 构建镜像（tag 由 build.conf 控制，也可 --tag 覆盖）
./build-image.sh --tag 1.2.0

# 2. 推送到 Harbor
export HARBOR_USER=admin
export HARBOR_PASSWORD=<harbor密码>
./push-image.sh --tag 1.2.0
```

---

## 四、Jenkins Job 配置

每个子模块对应一个 Jenkins Job，以 `investment-web-backend` 为例。

### 4.1 Job 基本设置

- **Job 类型**：Freestyle Project（或 Pipeline，见 4.3）
- **源码管理**：Git，填入 Gitee 仓库地址，凭据选 SSH Key
- **构建触发器**：勾选 `Gitee Webhook`，记录生成的 Webhook URL

### 4.2 Gitee Webhook 配置

在 Gitee 仓库 → 管理 → Webhooks → 添加：

```
URL:    https://www.sunmoonai.com/jenkins/gitee-project/<job-name>/build?token=<token>
事件:   Push 事件（master 分支）
```

### 4.3 构建步骤（Execute Shell）

```bash
#!/bin/bash
set -euo pipefail

# 注入 Harbor 凭据（由 Jenkins Credentials Binding 插件提供）
# 在 Job 配置 → Bindings 中添加：Username/Password → HARBOR_USER / HARBOR_PASSWORD
# 对应 Credentials ID: harbor-credentials

# 确定镜像 tag：使用 git 短 SHA
GIT_TAG=$(git rev-parse --short HEAD)

cd investment-web-backend/mybuild

# 构建
./build-image.sh --tag "${GIT_TAG}"

# 推送
./push-image.sh --tag "${GIT_TAG}"

echo "✅ 构建推送完成: investment-web-backend:${GIT_TAG}"
```

> 部署步骤待 k8s deploy 脚本完善后在此追加 `./deploy.sh --tag ${GIT_TAG} --cluster C1`

### 4.4 Pipeline 写法（可选替代 Freestyle）

```groovy
pipeline {
    agent any
    environment {
        HARBOR_CREDS = credentials('harbor-credentials')
        HARBOR_USER  = "${HARBOR_CREDS_USR}"
        HARBOR_PASSWORD = "${HARBOR_CREDS_PSW}"
        GIT_TAG      = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
    }
    stages {
        stage('Build') {
            steps {
                sh 'cd investment-web-backend/mybuild && ./build-image.sh --tag ${GIT_TAG}'
            }
        }
        stage('Push') {
            steps {
                sh 'cd investment-web-backend/mybuild && ./push-image.sh --tag ${GIT_TAG}'
            }
        }
        // stage('Deploy') { ... }  // 待补充
    }
    post {
        success { echo "✅ investment-web-backend:${GIT_TAG} 部署完成" }
        failure { echo "❌ 构建失败，请检查日志" }
    }
}
```

---

## 五、当前部署方式（手动）

Jenkins Webhook 尚未完全打通时，手动操作流程：

```bash
# 1. 拉取最新代码
git pull origin master

# 2. 四个服务依次构建推送（或按需选择）
for svc in investment-web-backend investment-admin-backend \
           investment-web-frontend investment-admin-frontend; do
    echo "=== Building $svc ==="
    cd ${svc}/mybuild
    ./build-image.sh
    HARBOR_USER=admin HARBOR_PASSWORD=<密码> ./push-image.sh
    cd ../..
done

# 3. 重启 k8s Deployment（镜像 tag 固定时用 rollout restart）
KUBECONFIG=~/.kube/cluster-c1-admin.conf \
    kubectl rollout restart deployment/investment-web-backend -n app-dev
```

---

## 六、演进路径

当前方案足以支撑小团队日常迭代，后续按需升级：

| 阶段 | 触发条件 | 升级内容 |
|------|----------|---------|
| 现在 | - | Webhook + mybuild 手动触发，本文档描述的方案 |
| 近期 | Webhook 稳定后 | 补充 deploy 脚本，实现 push → 自动构建 → 自动部署 |
| 中期 | 团队扩大 / 需要测试门控 | 在 mybuild 前插入 `npm test` / `pytest`，失败则阻断 |
| 远期 | 多环境流转需求 | 引入完整 Pipeline，按分支区分 dev/staging/prod |
