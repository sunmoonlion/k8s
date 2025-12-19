# Flower 使用文档

## 目录

1. [概述](#概述)
2. [架构原理](#架构原理)
3. [部署安装](#部署安装)
4. [配置说明](#配置说明)
5. [访问方式](#访问方式)
6. [界面功能](#界面功能)
7. [常用操作](#常用操作)
8. [监控功能](#监控功能)
9. [故障排查](#故障排查)
10. [最佳实践](#最佳实践)
11. [常见问题](#常见问题)

---

## 概述

### 什么是 Flower？

**Flower** 是 Celery 的实时 Web 监控工具，用于监控和管理 Celery Worker 和任务执行。

### 主要功能

- ✅ **实时监控**：监控所有 Celery Worker 的状态
- ✅ **任务管理**：查看任务执行情况、历史记录
- ✅ **性能分析**：任务执行时间、成功率统计
- ✅ **Worker 管理**：查看 Worker 健康状态、负载情况
- ✅ **任务控制**：取消、重试任务等操作

### 适用场景

- 监控 Celery 应用运行状态
- 排查任务执行问题
- 分析任务性能
- 管理 Worker 资源

---

## 架构原理

### Flower 工作原理

```
┌─────────────────────────────────────────────────┐
│              Flower 监控服务                    │
│  ┌──────────────────────────────────────────┐  │
│  │  Web UI (端口: 5555)                     │  │
│  │  - 实时监控界面                           │  │
│  │  - 任务管理界面                           │  │
│  └──────────────────────────────────────────┘  │
│         │                    │                  │
│         │                    │                  │
└─────────┼────────────────────┼──────────────────┘
          │                    │
          │ FLOWER_BROKER_URL  │ FLOWER_BROKER_API
          │ (AMQP 协议)        │ (HTTP API)
          │                    │
          ▼                    ▼
┌─────────────────────────────────────────────────┐
│           RabbitMQ (Broker)                    │
│  ┌──────────────────────────────────────────┐  │
│  │  AMQP 端口: 5672                         │  │
│  │  Management API: 15672                   │  │
│  └──────────────────────────────────────────┘  │
│         │                    │                  │
│         │                    │                  │
└─────────┼────────────────────┼──────────────────┘
          │                    │
          │ 连接               │ 连接
          │                    │
          ▼                    ▼
┌─────────────────┐  ┌─────────────────┐
│ Celery Worker 1 │  │ Celery Worker 2 │
│ (处理任务)       │  │ (处理任务)       │
└─────────────────┘  └─────────────────┘
```

### 关键连接

1. **FLOWER_BROKER_URL**：连接到 RabbitMQ AMQP 端口（5672）
   - 用于监听任务消息
   - 获取 Worker 注册信息

2. **FLOWER_BROKER_API**：连接到 RabbitMQ Management API（15672）
   - 用于查询队列状态
   - 获取连接和通道信息

### 监控机制

Flower 通过以下方式监控 Worker：

1. **Worker 发现**：通过 RabbitMQ Management API 查询所有连接
2. **任务监听**：通过 AMQP 连接监听任务消息
3. **状态跟踪**：跟踪任务从发送到完成的整个生命周期
4. **实时更新**：WebSocket 实时推送状态更新

---

## 部署安装

### 前置条件

1. ✅ RabbitMQ 已部署并运行
2. ✅ Celery Worker 已连接到 RabbitMQ
3. ✅ 网络连通性：Flower 能访问 RabbitMQ

### 部署步骤

#### 1. 配置部署参数

编辑配置文件：`deploy-flower/deploy-flower.conf`

```bash
# 基础配置
FLOWER_PROJECT_ID="sunmoonai"
FLOWER_NAMESPACE="ops-platform-dev"
ENVIRONMENT="development"

# Broker 配置（如果使用 Secret）
FLOWER_BROKER_URL_KEY=""      # 可选：从 Secret 读取
FLOWER_BROKER_API_URL_KEY=""  # 可选：从 Secret 读取

# 访问配置
FLOWER_UNIFIED_HOST="www.sunmoonai.com"
FLOWER_URL_PREFIX="/flower"
```

#### 2. 部署 Secrets（如果需要）

```bash
cd deploy-flower/secrets/deploy-secrets-all
./deploy-secrets-all.sh deploy
```

#### 3. 部署 Flower

```bash
cd deploy-flower
./deploy-flower.sh deploy
```

#### 4. 验证部署

```bash
# 检查 Pod 状态
kubectl get pods -n ops-platform-dev -l app.kubernetes.io/name=flower

# 检查 Service
kubectl get svc -n ops-platform-dev -l app.kubernetes.io/name=flower

# 检查 Ingress
kubectl get ingressroute -n ops-platform-dev flower-web-route
```

### 部署模式

#### 在线模式（推荐）

```bash
DEPLOYMENT_MODE="online"
ENABLE_OFFLINE_IMAGE_CHECK="false"
```

#### 离线模式

```bash
DEPLOYMENT_MODE="offline"
ENABLE_OFFLINE_IMAGE_CHECK="true"
FLOWER_FORCE_OFFLINE="true"
```

---

## 配置说明

### 核心配置项

#### 1. Broker 连接配置

**方式一：通过环境变量（推荐）**

在 `resources/custom-values/dev-values.yaml` 中配置：

```yaml
env:
  - name: FLOWER_BROKER_URL
    value: "amqp://admin:admin123@rabbitmq-sunmoonai.messaging-platform-dev:5672//"
  - name: FLOWER_BROKER_API
    value: "http://admin:admin123@rabbitmq-sunmoonai.messaging-platform-dev:15672/api/"
```

**方式二：通过 Secret**

1. 在 Secret 中存储 broker 信息：
```bash
kubectl create secret generic flower-secrets \
  --from-literal=broker-url="amqp://admin:admin123@rabbitmq-sunmoonai.messaging-platform-dev:5672//" \
  --from-literal=broker-api-url="http://admin:admin123@rabbitmq-sunmoonai.messaging-platform-dev:15672/api/" \
  -n ops-platform-dev
```

2. 在配置中指定 Secret 键名：
```bash
FLOWER_BROKER_URL_KEY="broker-url"
FLOWER_BROKER_API_URL_KEY="broker-api-url"
```

**方式三：通过命令行参数**

```yaml
args:
  - "--broker=amqp://admin:admin123@rabbitmq-sunmoonai.messaging-platform-dev:5672//"
  - "--broker_api=http://admin:admin123@rabbitmq-sunmoonai.messaging-platform-dev:15672/api/"
```

#### 2. URL 前缀配置

Flower 支持 URL 前缀，用于路径路由：

```yaml
args:
  - "--url_prefix=/flower"
```

**注意**：
- 访问时需要包含前缀：`https://www.sunmoonai.com/flower/`
- 路径必须以 `/` 结尾
- Flower 会自动处理所有 `/flower/*` 路径

#### 3. 认证配置

**Basic Auth（可选）**

```yaml
basicAuth:
  enabled: true
  username: "admin"
  password: "password"
```

或通过 Secret：

```bash
FLOWER_BASIC_AUTH_USER_KEY="basic-auth-user"
FLOWER_AUTH_SECRET_PASSWORD_KEY="flower-password"
```

#### 4. 资源限制

```yaml
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi
```

#### 5. 健康检查

```yaml
livenessProbe:
  httpGet:
    path: /flower/  # 注意：需要包含 url_prefix
    port: 5555
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /flower/  # 注意：需要包含 url_prefix
    port: 5555
  initialDelaySeconds: 5
  periodSeconds: 5
```

### 完整配置示例

```yaml
# resources/custom-values/dev-values.yaml
global:
  imageRegistry: "harbor.sunmoonai.com:30443"

image:
  registry: "harbor.sunmoonai.com:30443"
  repository: k8s-images/flower
  tag: "2.0.1"

service:
  type: ClusterIP
  port: 5555

ingress:
  enabled: true
  hosts:
    - host: "www.sunmoonai.com"
      paths:
        - path: /
          pathType: Prefix

env:
  - name: FLOWER_BROKER_URL
    value: "amqp://admin:admin123@rabbitmq-sunmoonai.messaging-platform-dev:5672//"
  - name: FLOWER_BROKER_API
    value: "http://admin:admin123@rabbitmq-sunmoonai.messaging-platform-dev:15672/api/"

args:
  - "--url_prefix=/flower"
  - "--port=5555"

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi
```

---

## 访问方式

### 1. 通过 Ingress 访问（推荐）

**统一域名访问**：
```
https://www.sunmoonai.com/flower/
```

**节点 IP 访问**：
```
https://115.190.153.150:30443/flower/
```

**注意**：
- 路径必须以 `/` 结尾
- 如果配置了 Basic Auth，需要输入用户名和密码

### 2. 通过 Port Forward 访问

```bash
# 获取 Pod 名称
POD_NAME=$(kubectl get pods -n ops-platform-dev -l app.kubernetes.io/name=flower -o jsonpath='{.items[0].metadata.name}')

# 端口转发
kubectl port-forward -n ops-platform-dev $POD_NAME 5555:5555

# 访问
http://localhost:5555/flower/
```

### 3. 通过 Service 访问（集群内）

```bash
# 获取 Service 名称
SERVICE_NAME=$(kubectl get svc -n ops-platform-dev -l app.kubernetes.io/name=flower -o jsonpath='{.items[0].metadata.name}')

# 在集群内访问
http://flower-service.ops-platform-dev.svc.cluster.local:5555/flower/
```

### 访问要求

1. ✅ RabbitMQ 必须运行
2. ✅ Flower Pod 必须运行
3. ✅ Ingress 必须配置正确
4. ✅ 网络连通性正常

---

## 界面功能

### 主界面概览

Flower Web UI 包含以下主要模块：

1. **Dashboard（仪表盘）**
2. **Workers（Worker 列表）**
3. **Tasks（任务列表）**
4. **Monitor（监控）**
5. **Broker（Broker 信息）**

### 1. Dashboard（仪表盘）

**功能**：
- 显示所有 Worker 的概览
- 任务统计（总数、成功、失败）
- 实时任务执行情况
- Worker 健康状态

**查看内容**：
- Active Workers：在线 Worker 数量
- Processed：已处理任务数
- Failed：失败任务数
- Succeeded：成功任务数
- Retries：重试任务数

### 2. Workers（Worker 列表）

**功能**：
- 列出所有连接到 Broker 的 Worker
- 显示每个 Worker 的详细信息

**Worker 信息**：
- **Name**：Worker 名称（如 `celeryworker-incubator@pod-123`）
- **Status**：状态（Online/Offline）
- **Active**：当前执行的任务数
- **Processed**：已处理任务总数
- **Failed**：失败任务数
- **Succeeded**：成功任务数
- **Load Average**：负载平均值
- **Uptime**：运行时间

**操作**：
- 点击 Worker 名称查看详细信息
- 查看 Worker 的注册信息
- 查看 Worker 的配置参数

### 3. Tasks（任务列表）

**功能**：
- 查看所有任务
- 按状态筛选（Pending、Started、Success、Failure、Retry）
- 查看任务详情

**任务信息**：
- **UUID**：任务唯一标识
- **Name**：任务名称
- **State**：任务状态
- **Worker**：执行任务的 Worker
- **Received**：接收时间
- **Started**：开始时间
- **Runtime**：执行时间
- **Result**：任务结果

**筛选选项**：
- All：所有任务
- Active：正在执行的任务
- Scheduled：计划执行的任务
- Reserved：已保留的任务
- Succeeded：成功的任务
- Failed：失败的任务

**操作**：
- 查看任务详情
- 取消任务
- 重试失败的任务
- 查看任务结果

### 4. Monitor（监控）

**功能**：
- 实时监控任务执行
- 查看任务速率
- 查看 Worker 负载

**监控指标**：
- Task Rate：任务执行速率
- Worker Load：Worker 负载
- Task Latency：任务延迟
- Task Success Rate：任务成功率

### 5. Broker（Broker 信息）

**功能**：
- 显示 Broker 连接信息
- 查看队列状态
- 查看连接数

**信息**：
- Broker URL：Broker 地址
- Broker API：Management API 地址
- Queues：队列列表
- Connections：连接数

---

## 常用操作

### 1. 查看所有 Worker

**步骤**：
1. 访问 Flower Web UI
2. 点击左侧菜单 "Workers"
3. 查看 Worker 列表

**信息解读**：
- **绿色**：Worker 在线
- **红色**：Worker 离线
- **黄色**：Worker 状态异常

### 2. 查看任务执行情况

**步骤**：
1. 点击左侧菜单 "Tasks"
2. 选择筛选条件（如 "Active"）
3. 查看任务列表

**查看任务详情**：
1. 点击任务 UUID
2. 查看任务详细信息：
   - 任务参数
   - 执行时间
   - 结果
   - 错误信息（如果有）

### 3. 取消任务

**步骤**：
1. 在 "Tasks" 页面找到要取消的任务
2. 点击任务 UUID
3. 点击 "Revoke" 按钮
4. 确认取消

**注意**：
- 只能取消未开始执行的任务
- 正在执行的任务无法取消（需要终止 Worker）

### 4. 重试失败的任务

**步骤**：
1. 在 "Tasks" 页面筛选 "Failed" 任务
2. 找到要重试的任务
3. 点击任务 UUID
4. 查看失败原因
5. 修复问题后，任务会自动重试（如果配置了自动重试）

### 5. 监控 Worker 健康状态

**步骤**：
1. 点击左侧菜单 "Workers"
2. 查看 Worker 状态
3. 点击 Worker 名称查看详细信息

**健康指标**：
- **Uptime**：运行时间（越长越好）
- **Load Average**：负载（越低越好）
- **Processed**：已处理任务数
- **Failed**：失败任务数（应该为 0 或很少）

### 6. 查看任务统计

**步骤**：
1. 点击左侧菜单 "Dashboard"
2. 查看统计信息

**统计内容**：
- 总任务数
- 成功任务数
- 失败任务数
- 重试任务数
- 平均执行时间

---

## 监控功能

### 1. 实时监控

Flower 提供实时监控功能：

- **WebSocket 连接**：实时推送状态更新
- **自动刷新**：页面自动更新状态
- **实时图表**：任务执行速率图表

### 2. 任务监控

**监控内容**：
- 任务发送时间
- 任务开始时间
- 任务完成时间
- 任务执行时间
- 任务结果
- 任务错误信息

### 3. Worker 监控

**监控内容**：
- Worker 在线/离线状态
- Worker 负载
- Worker 处理的任务数
- Worker 运行时间

### 4. 性能监控

**监控指标**：
- 任务执行速率（tasks/sec）
- 任务平均执行时间
- 任务成功率
- Worker 负载平均值

### 5. 告警功能

Flower 可以监控以下异常情况：

- Worker 离线
- 任务执行失败
- 任务执行超时
- Worker 负载过高

---

## 故障排查

### 问题 1：无法访问 Flower Web UI

**症状**：
- 浏览器无法打开 Flower 页面
- 显示 404 或连接错误

**排查步骤**：

1. **检查 Pod 状态**：
```bash
kubectl get pods -n ops-platform-dev -l app.kubernetes.io/name=flower
```

2. **检查 Pod 日志**：
```bash
POD_NAME=$(kubectl get pods -n ops-platform-dev -l app.kubernetes.io/name=flower -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n ops-platform-dev $POD_NAME
```

3. **检查 Service**：
```bash
kubectl get svc -n ops-platform-dev -l app.kubernetes.io/name=flower
```

4. **检查 Ingress**：
```bash
kubectl get ingressroute -n ops-platform-dev flower-web-route
kubectl describe ingressroute -n ops-platform-dev flower-web-route
```

5. **检查网络连通性**：
```bash
# 在 Pod 内测试 RabbitMQ 连接
kubectl exec -n ops-platform-dev $POD_NAME -- curl -s http://rabbitmq-sunmoonai.messaging-platform-dev:15672/api/overview
```

**常见原因**：
- Pod 未启动
- Broker 连接失败
- Ingress 配置错误
- 网络问题

### 问题 2：Flower 无法发现 Worker

**症状**：
- Flower 界面显示 "No workers"
- Worker 列表为空

**排查步骤**：

1. **检查 Worker 是否连接到 Broker**：
```bash
# 在 RabbitMQ Management UI 中查看连接
# 或使用命令行
kubectl exec -n messaging-platform-dev rabbitmq-pod -- rabbitmqctl list_connections
```

2. **检查 Broker 配置**：
```bash
# 检查 Flower 的 Broker URL 配置
kubectl get deployment -n ops-platform-dev flower -o yaml | grep -A 5 FLOWER_BROKER
```

3. **检查 Worker 配置**：
```bash
# 检查 Worker 的 Broker URL 是否与 Flower 一致
kubectl get configmap -n app-platform-dev celeryworker-config -o yaml | grep CELERY_BROKER_URL
```

4. **检查网络连通性**：
```bash
# 从 Flower Pod 测试连接 RabbitMQ
kubectl exec -n ops-platform-dev $POD_NAME -- nc -zv rabbitmq-sunmoonai.messaging-platform-dev 5672
```

**常见原因**：
- Worker 未连接到 Broker
- Broker URL 配置不一致
- 网络不通
- RabbitMQ 未运行

### 问题 3：任务状态不更新

**症状**：
- 任务状态一直显示 "Pending"
- 任务执行后状态不更新

**排查步骤**：

1. **检查 Worker 是否在线**：
   - 在 Flower 界面查看 Worker 状态

2. **检查任务是否被 Worker 接收**：
   - 在 RabbitMQ Management UI 查看队列消息

3. **检查 Worker 日志**：
```bash
kubectl logs -n app-platform-dev -l app=celeryworker-incubator --tail=100
```

4. **检查任务结果后端**：
   - 确认 `CELERY_RESULT_BACKEND` 配置正确
   - 检查 Redis 连接

**常见原因**：
- Worker 离线
- 任务序列化问题
- 结果后端连接失败

### 问题 4：Flower 连接 RabbitMQ 失败

**症状**：
- Flower Pod 启动失败
- 日志显示连接错误

**排查步骤**：

1. **检查 Broker URL**：
```bash
kubectl get deployment -n ops-platform-dev flower -o yaml | grep FLOWER_BROKER_URL
```

2. **测试连接**：
```bash
# 从 Flower Pod 测试 AMQP 连接
kubectl exec -n ops-platform-dev $POD_NAME -- python3 -c "
import pika
connection = pika.BlockingConnection(pika.URLParameters('amqp://admin:admin123@rabbitmq-sunmoonai.messaging-platform-dev:5672//'))
print('Connection successful')
connection.close()
"
```

3. **检查 RabbitMQ 状态**：
```bash
kubectl get pods -n messaging-platform-dev -l app.kubernetes.io/name=rabbitmq
```

4. **检查认证信息**：
   - 确认用户名和密码正确
   - 检查 Secret 配置

**常见原因**：
- Broker URL 配置错误
- 认证信息错误
- RabbitMQ 未运行
- 网络不通

### 问题 5：页面加载缓慢

**症状**：
- Flower 界面加载很慢
- 数据更新延迟

**排查步骤**：

1. **检查 Pod 资源使用**：
```bash
kubectl top pod -n ops-platform-dev -l app.kubernetes.io/name=flower
```

2. **检查网络延迟**：
```bash
# 测试到 RabbitMQ 的网络延迟
kubectl exec -n ops-platform-dev $POD_NAME -- ping -c 5 rabbitmq-sunmoonai.messaging-platform-dev
```

3. **检查 Worker 数量**：
   - 如果 Worker 数量很多，可能影响性能
   - 考虑增加 Flower 资源限制

**解决方案**：
- 增加 Pod 资源限制
- 优化网络配置
- 减少监控的 Worker 数量（如果可能）

---

## 最佳实践

### 1. 配置建议

**Broker 连接**：
- ✅ 使用 Secret 存储敏感信息（密码等）
- ✅ 配置正确的 Broker URL 和 API URL
- ✅ 确保网络连通性

**资源限制**：
- ✅ 根据 Worker 数量设置合适的资源限制
- ✅ 监控 Pod 资源使用情况
- ✅ 预留足够的 CPU 和内存

**健康检查**：
- ✅ 配置正确的健康检查路径（包含 url_prefix）
- ✅ 设置合理的检查间隔

### 2. 安全建议

**认证**：
- ✅ 启用 Basic Auth（生产环境）
- ✅ 使用强密码
- ✅ 定期更换密码

**网络**：
- ✅ 使用 HTTPS（通过 Ingress）
- ✅ 限制访问来源（如果可能）
- ✅ 使用内网访问（避免公网暴露）

### 3. 监控建议

**定期检查**：
- ✅ 每天检查 Worker 状态
- ✅ 监控任务失败率
- ✅ 查看任务执行时间趋势

**告警设置**：
- ✅ 设置 Worker 离线告警
- ✅ 设置任务失败率告警
- ✅ 设置任务执行时间告警

### 4. 性能优化

**资源优化**：
- ✅ 根据实际负载调整资源限制
- ✅ 监控 Pod 资源使用情况
- ✅ 避免资源不足导致的性能问题

**网络优化**：
- ✅ 确保 Flower 和 RabbitMQ 在同一网络
- ✅ 使用内网地址连接
- ✅ 避免跨区域网络延迟

---

## 常见问题

### Q1: Flower 需要多少个实例？

**A**: 通常 **1 个实例**即可。Flower 是轻量级监控工具，单个实例可以监控所有 Worker。如果需要高可用，可以部署 2-3 个实例。

### Q2: Flower 会影响 Worker 性能吗？

**A**: **不会**。Flower 只读取信息，不参与任务处理，对 Worker 性能影响极小。

### Q3: 如何监控多个 RabbitMQ Broker？

**A**: 每个 Flower 实例只能连接一个 Broker。如果需要监控多个 Broker，需要部署多个 Flower 实例。

### Q4: Flower 数据会持久化吗？

**A**: **不会**。Flower 不持久化数据，所有信息都是实时从 RabbitMQ 获取的。重启后历史数据会丢失。

### Q5: 如何查看历史任务？

**A**: Flower 只显示当前在内存中的任务。如果需要查看历史任务，需要：
- 使用任务结果后端（Redis）查询
- 使用日志系统
- 使用其他监控工具

### Q6: Flower 支持哪些 Broker？

**A**: Flower 支持：
- ✅ RabbitMQ（推荐）
- ✅ Redis
- ✅ Amazon SQS
- ✅ 其他 AMQP 兼容的 Broker

### Q7: 如何备份 Flower 配置？

**A**: Flower 配置存储在：
- `deploy-flower/deploy-flower.conf`
- `resources/custom-values/*.yaml`
- Kubernetes Secret

建议使用 Git 版本控制管理配置文件。

### Q8: Flower 可以监控多少个 Worker？

**A**: **理论上无限制**。实际建议：
- 少于 50 个 Worker：1 个 Flower 实例
- 50-200 个 Worker：1-2 个 Flower 实例
- 超过 200 个 Worker：考虑多个 Flower 实例或增加资源

### Q9: 如何更新 Flower 版本？

**A**: 
1. 修改 `deploy-flower.conf` 中的 `FLOWER_IMAGE_VERSION`
2. 重新部署：`./deploy-flower.sh deploy`
3. 验证新版本是否正常工作

### Q10: Flower 支持集群模式吗？

**A**: **不支持**。Flower 是单实例应用，不支持集群模式。如果需要高可用，可以部署多个独立实例。

---

## 附录

### 相关文档

- [Celery监控机制说明.md](../../app-platform/docs/Celery监控机制说明.md)
- [RabbitMQ 部署文档](../../messaging-platform/rabbitmq/README.md)

### 配置文件路径

- 部署配置：`deploy-flower/deploy-flower.conf`
- Helm Values：`resources/custom-values/dev-values.yaml`
- Chart Values：`resources/flower/values.yaml`

### 命令行工具

**查看 Flower 状态**：
```bash
kubectl get pods -n ops-platform-dev -l app.kubernetes.io/name=flower
kubectl logs -n ops-platform-dev -l app.kubernetes.io/name=flower --tail=100
```

**重启 Flower**：
```bash
kubectl rollout restart deployment -n ops-platform-dev flower
```

**查看配置**：
```bash
kubectl get deployment -n ops-platform-dev flower -o yaml
```

### 参考链接

- [Flower 官方文档](https://flower.readthedocs.io/)
- [Flower GitHub](https://github.com/mher/flower)
- [Celery 监控文档](https://docs.celeryq.dev/en/stable/userguide/monitoring.html)

---

**文档版本**: 1.0  
**最后更新**: 2025-12-19  
**维护者**: Platform Team
