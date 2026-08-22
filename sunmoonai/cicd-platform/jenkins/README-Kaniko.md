# Jenkins Kaniko 配置说明

## 文件说明

### 配置文件

1. **resources/custom-values/dev-values.yaml**
   - Kaniko Agent 配置（通过 CASC）
   - 在 `configAsCode.extraKubernetes` 中添加 Kaniko 模板
   - Jenkins 会自动读取并应用

2. **deploy-kaniko-registry-secret/** (目录)
   - Kaniko Registry 认证 Secret 部署脚本
   - 使用统一的部署模式创建 Secret

### Pipeline 脚本

3. **kaniko-build-pipeline.groovy**
   - Kaniko 构建 Pipeline 示例
   - 包含完整的构建和推送流程
   - 可根据实际项目修改

### 文档

4. **Kaniko实施指南.md**
   - 详细的实施步骤
   - 常见问题解答
   - 最佳实践

5. **Kaniko迁移方案.md**
   - 迁移方案对比
   - 架构说明
   - 配置示例


## 快速开始

### 1. 创建 Registry Secret

使用统一的部署脚本创建 Secret：

```bash
cd ~/master/k8s/sunmoonai/cicd-platform/jenkins/deploy-jenkins/secrets/kaniko-registry-secret/deploy-kaniko-registry-secret
./deploy-kaniko-registry-secret.sh deploy
```

或者使用统一部署脚本部署所有 Secret：

```bash
cd ~/master/k8s/sunmoonai/cicd-platform/jenkins/deploy-jenkins/secrets/deploy-secrets-all
./deploy-secrets-all.sh
```

### 2. 配置 Kaniko Agent（通过 CASC）

在 `resources/custom-values/dev-values.yaml` 中添加 Kaniko Agent 配置：

```yaml
configAsCode:
  enabled: true
  extraKubernetes: |
    templates:
      - name: kaniko-agent
        label: "kaniko-agent"
        namespace: cicd-platform-dev
        containers:
          - name: jnlp
            image: harbor.sunmoonai.com:30443/k8s-images/jenkins-agent:0.3327.0-debian-12-r1
            resourceRequestCpu: 200m
            resourceRequestMemory: 256Mi
            resourceLimitCpu: 1000m
            resourceLimitMemory: 1Gi
          - name: kaniko
            image: gcr.io/kaniko-project/executor:latest
            tty: true
            resourceRequestCpu: 500m
            resourceRequestMemory: 512Mi
            resourceLimitCpu: 2000m
            resourceLimitMemory: 2Gi
        volumes:
          - type: Secret
            secretName: kaniko-registry-secret
            mountPath: /kaniko/.docker
        imagePullSecrets:
          - name: harbor-registry-secret
```

### 3. 重新部署 Jenkins

```bash
cd ~/master/k8s/sunmoonai/cicd-platform/jenkins/deploy-jenkins
./deploy-jenkins.sh deploy
```

### 4. 创建测试 Pipeline

1. 创建新的 Pipeline 任务
2. 使用 `kaniko-build-pipeline.groovy` 作为 Pipeline 脚本
3. 根据实际项目修改配置

## 架构说明

### Kaniko Agent Pod 结构

```
Agent Pod
├── jnlp 容器
│   ├── 镜像: harbor.sunmoonai.com:30443/k8s-images/jenkins-agent:0.3327.0-debian-12-r1
│   ├── 职责: 连接 Jenkins Master，执行构建脚本
│   └── 资源: CPU 200m-1000m, Memory 256Mi-1Gi
│
└── kaniko 容器
    ├── 镜像: gcr.io/kaniko-project/executor:latest
    ├── 职责: 构建和推送 Docker 镜像
    ├── 资源: CPU 500m-2000m, Memory 512Mi-2Gi
    └── 认证: /kaniko/.docker (Secret Volume)
```

### 工作流程

```
1. Pipeline 开始执行
   ↓
2. Jenkins 创建 Agent Pod（包含 jnlp + kaniko）
   ↓
3. jnlp 容器连接 Jenkins Master
   ↓
4. Pipeline 在 jnlp 容器中执行（Checkout 等）
   ↓
5. 构建阶段切换到 kaniko 容器
   ↓
6. kaniko 容器执行 /kaniko/executor 构建镜像
   ↓
7. 镜像推送到 Harbor
   ↓
8. Pipeline 完成，Agent Pod 被清理
```

## 优势

1. **安全性高**：不需要 privileged 权限
2. **性能好**：比 dind 快 10-20%
3. **资源消耗低**：比 dind 节省约 1GB 内存
4. **适合 containerd**：不依赖 Docker daemon

## 注意事项

1. **Registry 认证**：必须创建 `kaniko-registry-secret`
2. **镜像拉取**：kaniko 镜像需要从 gcr.io 拉取（可能需要代理）
3. **缓存配置**：建议启用缓存以提升构建速度
4. **不支持 docker run**：如果需要运行容器，仍使用 dind

## 相关文档

- [Kaniko实施指南.md](./Kaniko实施指南.md) - 详细实施步骤
- [Kaniko迁移方案.md](./Kaniko迁移方案.md) - 迁移方案对比
- [Docker构建方案对比分析.md](./Docker构建方案对比分析.md) - 方案对比

