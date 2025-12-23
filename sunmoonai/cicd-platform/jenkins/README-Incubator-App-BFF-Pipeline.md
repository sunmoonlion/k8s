# Incubator App BFF Jenkins Pipeline 使用说明

## 概述

这个 Pipeline 实现了以下功能：

1. **代码拉取**：使用 Jenkins 的 SCM 功能从代码仓库拉取代码
2. **镜像构建**：调用项目自己的构建脚本（`mybuild/build-image.sh`）构建 Docker 镜像
3. **自动部署**：构建完成后调用部署脚本（`deploy-incubator-bff.sh`）部署到 Kubernetes

## 特点

- ✅ **不使用 Jenkins Agent 构建**：直接调用项目自己的构建脚本
- ✅ **支持定时拉取代码**：通过 Jenkins 的 Poll SCM 功能实现
- ✅ **灵活配置**：支持通过 Jenkins 参数自定义镜像标签、部署环境等
- ✅ **可选步骤**：支持跳过构建或部署步骤

## 文件说明

- **incubator-app-bff-pipeline.groovy**：Pipeline 脚本文件
- **README-Incubator-App-BFF-Pipeline.md**：本使用说明文档

## 前置要求

### 1. Jenkins 配置

确保 Jenkins 已部署并可以访问 Kubernetes 集群：

```bash
# 检查 Jenkins 部署状态
kubectl get pods -n cicd-platform-dev -l app.kubernetes.io/name=jenkins

# 检查 Jenkins 是否可以访问 Kubernetes
kubectl auth can-i get pods --as=system:serviceaccount:cicd-platform-dev:jenkins
```

### 2. 构建脚本要求

确保构建脚本路径正确：
- 代码仓库根目录下应有 `mybuild/build-image.sh`
- 构建脚本应支持 `--tag` 参数指定镜像标签

### 3. 部署脚本要求

确保部署脚本路径正确：
- 部署脚本路径：`/home/zym/k8s/sunmoonai/incubator-app/incubator-app-bff/deploy-incubator-bff/app/deploy-app/deploy-incubator-bff.sh`
- 部署脚本应支持参数：`deploy <project_id> <namespace> <environment>`
- 部署脚本应支持 `--cluster` 参数（可选）

### 4. 权限要求

Jenkins 节点需要：
- 执行构建脚本的权限（读取代码仓库、执行 Docker/nerdctl 构建）
- 执行部署脚本的权限（访问 Kubernetes 集群）
- 访问镜像仓库的权限（如果启用自动推送）

## 配置步骤

### 步骤 1: 在 Jenkins 中创建 Pipeline 任务

1. 登录 Jenkins Web UI
2. 点击 "新建任务"
3. 输入任务名称（如：`incubator-app-bff`）
4. 选择 "流水线" (Pipeline)
5. 点击 "确定"

### 步骤 2: 配置 SCM（代码仓库）

在 Pipeline 配置页面：

1. **Pipeline 定义**：选择 "Pipeline script from SCM"
2. **SCM**：选择 "Git"
3. **Repository URL**：输入代码仓库地址
   ```
   https://your-git-repo/incubator-app-bff.git
   # 或
   git@your-git-server:incubator-app-bff.git
   ```
4. **Credentials**：选择 Git 认证凭据（如果需要）
5. **Branch Specifier**：输入分支（如：`*/main` 或 `*/master`）
6. **Script Path**：输入 Pipeline 脚本路径
   ```
   k8s/sunmoonai/cicd-platform/jenkins/incubator-app-bff-pipeline.groovy
   ```
   注意：路径是相对于代码仓库根目录的

### 步骤 3: 配置定时构建（可选）

在 Pipeline 配置页面的 "构建触发器" 部分：

1. 勾选 "Poll SCM"
2. 输入定时表达式，例如：
   - `H/15 * * * *`：每 15 分钟检查一次
   - `H * * * *`：每小时检查一次
   - `H 2 * * *`：每天凌晨 2 点检查一次
   - `H 9 * * 1-5`：工作日上午 9 点检查一次

### 步骤 4: 配置构建参数（可选）

Pipeline 支持以下参数（可在首次构建时设置默认值）：

- **IMAGE_TAG_PARAM**：自定义镜像标签（留空则使用 `BUILD_NUMBER-GIT_COMMIT`）
- **DEPLOY_PROJECT_ID_PARAM**：部署项目ID（默认：`sunmoonai`）
- **DEPLOY_NAMESPACE_PARAM**：部署命名空间（默认：`app-platform-dev`）
- **DEPLOY_ENVIRONMENT_PARAM**：部署环境（`development` 或 `production`）
- **CLUSTER_PARAM**：集群标识（如 `C1`, `C2`，留空则不指定）
- **SKIP_BUILD**：跳过构建步骤（仅部署）
- **SKIP_DEPLOY**：跳过部署步骤（仅构建）
- **PUSH_IMAGE_AFTER_BUILD**：构建后自动推送镜像（默认：`true`）

## 使用方法

### 方法 1: 手动触发构建

1. 在 Jenkins 任务页面点击 "立即构建"
2. 如果需要自定义参数，点击 "Build with Parameters"
3. 设置参数后点击 "构建"

### 方法 2: 定时自动构建

配置 Poll SCM 后，Jenkins 会定期检查代码仓库，如果有新提交则自动触发构建。

### 方法 3: Webhook 触发（推荐）

在代码仓库配置 Webhook，当有代码推送时自动触发 Jenkins 构建：

1. 在代码仓库的 Webhook 设置中添加：
   - URL: `http://your-jenkins-url/github-webhook/`
   - 或: `http://your-jenkins-url/git/notifyCommit?url=<repository-url>`
2. 在 Jenkins 任务配置中勾选 "GitHub hook trigger for GITScm polling"

## Pipeline 执行流程

```
1. Checkout（拉取代码）
   ↓
2. Build Image（构建镜像）
   - 检查构建脚本
   - 执行 mybuild/build-image.sh --tag <IMAGE_TAG>
   - 可选：自动推送镜像到仓库
   ↓
3. Deploy to Kubernetes（部署到 K8s）
   - 检查部署脚本
   - 执行 deploy-incubator-bff.sh deploy <project_id> <namespace> <environment>
   - 可选：指定集群参数 --cluster=<CLUSTER>
   ↓
4. 完成
```

## 构建配置说明

### 镜像标签规则

默认镜像标签格式：`BUILD_NUMBER-GIT_COMMIT`

例如：
- `123-abc1234`：构建号 123，Git 提交前 7 位为 abc1234

可以通过参数 `IMAGE_TAG_PARAM` 自定义标签。

### 构建脚本配置

构建脚本使用 `mybuild/build.conf` 配置文件，Pipeline 会自动：
- 如果 `PUSH_IMAGE_AFTER_BUILD=true`，临时修改配置为自动推送
- 构建完成后恢复原配置

### 部署脚本配置

部署脚本使用 `deploy-incubator-bff.conf` 配置文件，Pipeline 通过命令行参数传递：
- `project_id`：项目ID
- `namespace`：命名空间
- `environment`：环境（development/production）
- `--cluster`：集群标识（可选）

## 常见问题

### 1. 构建脚本找不到

**问题**：Pipeline 报错 "构建脚本不存在"

**解决**：
- 检查代码仓库中是否有 `mybuild/build-image.sh`
- 检查 Pipeline 脚本路径中的 `BUILD_SCRIPT_PATH` 是否正确
- 确保代码已正确拉取到工作空间

### 2. 部署脚本找不到

**问题**：Pipeline 报错 "部署脚本不存在"

**解决**：
- 检查部署脚本路径是否正确：`/home/zym/k8s/sunmoonai/incubator-app/incubator-app-bff/deploy-incubator-bff/app/deploy-app/deploy-incubator-bff.sh`
- 确保 Jenkins 节点可以访问该路径
- 检查文件权限：`chmod +x deploy-incubator-bff.sh`

### 3. 镜像构建失败

**问题**：构建脚本执行失败

**解决**：
- 检查构建脚本是否有执行权限
- 检查 Docker/nerdctl 是否可用
- 检查构建配置文件 `mybuild/build.conf` 是否正确
- 查看构建日志获取详细错误信息

### 4. 部署失败

**问题**：部署脚本执行失败

**解决**：
- 检查 Kubernetes 连接是否正常
- 检查部署脚本是否有执行权限
- 检查部署配置文件 `deploy-incubator-bff.conf` 是否正确
- 检查命名空间是否存在
- 查看部署日志获取详细错误信息

### 5. 镜像推送失败

**问题**：镜像推送失败

**解决**：
- 检查镜像仓库配置是否正确（`mybuild/build.conf`）
- 检查是否已登录镜像仓库：
  ```bash
  docker login harbor.sunmoonai.com:30443
  # 或
  sudo nerdctl login harbor.sunmoonai.com:30443
  ```
- 检查网络连接是否正常

## 高级配置

### 自定义构建脚本路径

如果需要修改构建脚本路径，编辑 Pipeline 脚本中的：

```groovy
BUILD_SCRIPT_PATH = "mybuild/build-image.sh"
```

### 自定义部署脚本路径

如果需要修改部署脚本路径，编辑 Pipeline 脚本中的：

```groovy
DEPLOY_SCRIPT_PATH = "/home/zym/k8s/sunmoonai/incubator-app/incubator-app-bff/deploy-incubator-bff/app/deploy-app/deploy-incubator-bff.sh"
```

### 添加构建后通知

在 Pipeline 的 `post` 部分添加通知逻辑，例如：

```groovy
post {
    success {
        // 发送成功通知（邮件、Slack 等）
        emailext(
            subject: "✅ Incubator App BFF 构建成功",
            body: "构建号: ${env.BUILD_NUMBER}\n镜像标签: ${env.IMAGE_TAG}",
            to: "team@example.com"
        )
    }
    failure {
        // 发送失败通知
        emailext(
            subject: "❌ Incubator App BFF 构建失败",
            body: "构建号: ${env.BUILD_NUMBER}\n请查看构建日志",
            to: "team@example.com"
        )
    }
}
```

## 最佳实践

1. **使用 Webhook 触发**：比 Poll SCM 更及时，减少不必要的检查
2. **设置合理的镜像标签**：使用有意义的标签便于追踪
3. **分离构建和部署**：可以分别触发构建和部署，便于测试
4. **配置通知**：及时了解构建和部署状态
5. **定期清理**：定期清理旧的构建记录和镜像

## 相关文档

- [Jenkins Pipeline 文档](https://www.jenkins.io/doc/book/pipeline/)
- [Incubator App BFF 构建脚本说明](../incubator-app-bff/mybuild/README.md)
- [Incubator App BFF 部署脚本说明](../../incubator-app/incubator-app-bff/CONFIG_CHECKLIST.md)

