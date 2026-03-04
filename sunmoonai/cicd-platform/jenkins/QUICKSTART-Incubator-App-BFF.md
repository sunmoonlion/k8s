# Incubator App BFF Pipeline 快速配置指南

## 5 分钟快速配置

### 步骤 1: 在 Jenkins 中创建 Pipeline 任务

1. 登录 Jenkins Web UI
2. 点击 "新建任务" → 输入任务名称（如：`incubator-app-bff`）→ 选择 "流水线" → 确定

### 步骤 2: 配置代码仓库

在 Pipeline 配置页面：

- **Pipeline 定义**：选择 "Pipeline script from SCM"
- **SCM**：选择 "Git"
- **Repository URL**：输入你的代码仓库地址
- **Credentials**：选择 Git 认证凭据（如果需要）
- **Branch Specifier**：`*/main` 或 `*/master`
- **Script Path**：`k8s/sunmoonai/cicd-platform/jenkins/incubator-app-bff-pipeline.groovy`

### 步骤 3: 配置定时构建（可选）

在 "构建触发器" 部分：

- 勾选 "Poll SCM"
- 输入：`H/15 * * * *`（每 15 分钟检查一次）

### 步骤 4: 保存并测试

1. 点击 "保存"
2. 点击 "立即构建" 测试 Pipeline

## 配置说明

### 必需配置

- ✅ 代码仓库地址
- ✅ Pipeline 脚本路径（相对于代码仓库根目录）

### 可选配置

- ⏰ 定时构建（Poll SCM）
- 🔔 Webhook 触发（推荐）
- 📝 构建参数（可在首次构建时设置）

## 工作流程

```
代码推送 → Jenkins 检测到变更 → 拉取代码 → 构建镜像 → 部署到 K8s
```

## 常见问题快速解决

### Q: Pipeline 脚本找不到？

**A**: 确保 Pipeline 脚本路径正确，路径是相对于代码仓库根目录的。

### Q: 构建脚本找不到？

**A**: 确保代码仓库中有 `mybuild/build-image.sh` 文件。

### Q: 部署脚本找不到？

**A**: 确保部署脚本路径正确：`~/k8s/sunmoonai/incubator-app/incubator-app-bff/deploy-incubator-bff/app/deploy-app/deploy-incubator-bff.sh`

### Q: 如何跳过构建或部署？

**A**: 在构建时选择 "Build with Parameters"，然后勾选 `SKIP_BUILD` 或 `SKIP_DEPLOY`。

## 下一步

- 查看详细文档：[README-Incubator-App-BFF-Pipeline.md](./README-Incubator-App-BFF-Pipeline.md)
- 配置 Webhook 自动触发（推荐）
- 配置构建通知（邮件、Slack 等）

