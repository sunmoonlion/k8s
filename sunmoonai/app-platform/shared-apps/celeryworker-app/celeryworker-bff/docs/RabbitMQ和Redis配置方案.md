# RabbitMQ 和 Redis 配置方案

## 一、需求分析

### 当前场景
- **多后端 Worker**：处理来自 `llmops-service` 和 `incubator-service` 的任务
- **队列需求**：需要监听 `llmops-queue` 和 `incubator-queue`
- **结果存储**：需要存储两个后端的任务执行结果

### 关键问题
1. RabbitMQ 是否需要多个实例？
2. Redis 是否需要多个实例？
3. 如何实现隔离和扩展？

---

## 二、RabbitMQ 配置方案

### 方案A：单个 RabbitMQ + 多个队列（推荐）⭐

#### 架构
```
┌─────────────────────────────────────┐
│      RabbitMQ (单个实例)             │
│  ┌───────────────────────────────┐  │
│  │ llmops-queue                  │  │
│  │ incubator-queue               │  │
│  │ (未来可扩展: scrapy-queue)    │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
         │         │
         ▼         ▼
    Worker-1  Worker-2
```

#### 配置
```bash
# 所有后端共享同一个 RabbitMQ
CELERY_BROKER_URL="amqp://admin:admin123@rabbitmq-sunmoonai.messaging-platform-dev:5672//"

# Worker 监听多个队列
CELERY_QUEUES="llmops-queue,incubator-queue"
```

#### 优点
- ✅ **资源占用少**：只需一个 RabbitMQ 实例
- ✅ **管理简单**：统一管理，统一监控
- ✅ **队列隔离**：RabbitMQ 的队列机制天然隔离
- ✅ **易于扩展**：可以动态创建新队列
- ✅ **成本低**：减少资源占用

#### 缺点
- ⚠️ **单点故障风险**：一个 RabbitMQ 故障影响所有后端（可通过高可用部署解决）

#### 适用场景
- ✅ 推荐用于大多数场景
- ✅ 后端数量 < 10 个
- ✅ 不需要完全隔离

---

### 方案B：多个 RabbitMQ（完全隔离）

#### 架构
```
┌─────────────────┐
│  RabbitMQ-1     │ ──> llmops-queue → celeryworker-multi
│  (llmops)       │
└─────────────────┘

┌─────────────────┐
│  RabbitMQ-2     │ ──> incubator-queue → celeryworker-multi
│  (incubator)    │
└─────────────────┘
```

#### 配置
```bash
# 方案B1: 使用不同的 RabbitMQ 实例
CELERY_BROKER_URL_LLMOPS="amqp://admin:admin123@rabbitmq-llmops.messaging-platform-dev:5672//"
CELERY_BROKER_URL_INCUBATOR="amqp://admin:admin123@rabbitmq-incubator.messaging-platform-dev:5672//"

# 方案B2: 使用同一个 RabbitMQ 的不同 Virtual Host
CELERY_BROKER_URL_LLMOPS="amqp://admin:admin123@rabbitmq-sunmoonai.messaging-platform-dev:5672/llmops"
CELERY_BROKER_URL_INCUBATOR="amqp://admin:admin123@rabbitmq-sunmoonai.messaging-platform-dev:5672/incubator"
```

#### 优点
- ✅ **完全隔离**：每个后端使用独立的 RabbitMQ 或 Virtual Host
- ✅ **故障隔离**：一个 RabbitMQ 故障不影响其他后端
- ✅ **独立配置**：可以为每个 RabbitMQ 设置不同的配置

#### 缺点
- ❌ **资源占用多**：需要多个 RabbitMQ 实例
- ❌ **管理复杂**：需要管理多个 RabbitMQ
- ❌ **成本高**：资源占用增加
- ❌ **配置复杂**：Worker 需要连接多个 RabbitMQ

#### 适用场景
- ⚠️ 安全合规要求完全隔离
- ⚠️ 不同后端在不同集群/网络
- ⚠️ 需要独立的 RabbitMQ 配置

---

### 方案C：单个 RabbitMQ + Virtual Host（折中方案）

#### 架构
```
┌─────────────────────────────────────┐
│      RabbitMQ (单个实例)             │
│  ┌───────────────────────────────┐  │
│  │ Virtual Host: llmops           │  │
│  │   └─ llmops-queue              │  │
│  │ Virtual Host: incubator        │  │
│  │   └─ incubator-queue            │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

#### 配置
```bash
# 使用不同的 Virtual Host
CELERY_BROKER_URL="amqp://admin:admin123@rabbitmq-sunmoonai.messaging-platform-dev:5672/llmops"
# 或
CELERY_BROKER_URL="amqp://admin:admin123@rabbitmq-sunmoonai.messaging-platform-dev:5672/incubator"
```

#### 优点
- ✅ **逻辑隔离**：Virtual Host 提供逻辑隔离
- ✅ **资源占用少**：只需一个 RabbitMQ 实例
- ✅ **管理相对简单**：统一管理，逻辑隔离

#### 缺点
- ⚠️ **配置复杂**：Worker 需要知道所有 Virtual Host
- ⚠️ **Celery 限制**：Celery 一个 Worker 只能连接一个 Broker URL

#### 适用场景
- ⚠️ 需要逻辑隔离但不需要物理隔离
- ⚠️ 不推荐：Celery Worker 限制，难以实现

---

## 三、Redis 配置方案

### 方案A：单个 Redis + 结果键前缀（推荐）⭐

#### 架构
```
┌─────────────────────────────────────┐
│      Redis (单个实例)                │
│  ┌───────────────────────────────┐  │
│  │ celery-task-meta-llmops-*     │  │  ← llmops-service 的结果
│  │ celery-task-meta-incubator-*  │  │  ← incubator-service 的结果
│  │ celery-task-meta-scrapy-*     │  │  ← scrapy-service 的结果（未来）
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

#### 配置
```bash
# 所有后端共享同一个 Redis
CELERY_RESULT_BACKEND="redis://redis-service.data-platform:6379/0"

# Celery 自动使用应用名称作为结果键前缀
# llmops-service → celery-task-meta-llmops-{task-id}
# incubator-service → celery-task-meta-incubator-{task-id}
```

#### 优点
- ✅ **资源占用少**：只需一个 Redis 实例
- ✅ **管理简单**：统一管理，统一监控
- ✅ **键隔离**：通过应用名称自动区分结果键
- ✅ **易于扩展**：可以动态添加新的后端
- ✅ **成本低**：减少资源占用

#### 缺点
- ⚠️ **单点故障风险**：一个 Redis 故障影响所有后端（可通过高可用部署解决）

#### 适用场景
- ✅ 推荐用于大多数场景
- ✅ 后端数量 < 20 个
- ✅ 不需要完全隔离

---

### 方案B：单个 Redis + 不同数据库（折中方案）

#### 架构
```
┌─────────────────────────────────────┐
│      Redis (单个实例)                │
│  ┌───────────────────────────────┐  │
│  │ DB 0: llmops 结果              │  │
│  │ DB 1: incubator 结果           │  │
│  │ DB 2: scrapy 结果（未来）       │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

#### 配置
```bash
# 使用不同的数据库编号
CELERY_RESULT_BACKEND_LLMOPS="redis://redis-service.data-platform:6379/0"
CELERY_RESULT_BACKEND_INCUBATOR="redis://redis-service.data-platform:6379/1"
```

#### 优点
- ✅ **数据库隔离**：不同数据库之间完全隔离
- ✅ **资源占用少**：只需一个 Redis 实例
- ✅ **管理相对简单**：统一管理，数据库隔离

#### 缺点
- ⚠️ **配置复杂**：Worker 需要知道所有数据库编号
- ⚠️ **Celery 限制**：Celery 一个 Worker 只能连接一个 Result Backend
- ⚠️ **集群模式不支持**：Redis 集群模式不支持数据库功能

#### 适用场景
- ⚠️ 需要进一步隔离但不需要多个 Redis
- ⚠️ 不推荐：Celery Worker 限制，难以实现

---

### 方案C：多个 Redis（完全隔离）

#### 架构
```
┌─────────────────┐
│  Redis-1 (DB 0) │ ──> llmops 结果
│  (llmops)       │
└─────────────────┘

┌─────────────────┐
│  Redis-2 (DB 0) │ ──> incubator 结果
│  (incubator)    │
└─────────────────┘
```

#### 配置
```bash
# 使用不同的 Redis 实例
CELERY_RESULT_BACKEND_LLMOPS="redis://redis-llmops.data-platform:6379/0"
CELERY_RESULT_BACKEND_INCUBATOR="redis://redis-incubator.data-platform:6379/0"
```

#### 优点
- ✅ **完全隔离**：每个后端使用独立的 Redis
- ✅ **故障隔离**：一个 Redis 故障不影响其他后端
- ✅ **独立配置**：可以为每个 Redis 设置不同的配置

#### 缺点
- ❌ **资源占用多**：需要多个 Redis 实例
- ❌ **管理复杂**：需要管理多个 Redis
- ❌ **成本高**：资源占用增加
- ❌ **配置复杂**：Worker 需要连接多个 Redis

#### 适用场景
- ⚠️ 安全合规要求完全隔离
- ⚠️ 不同后端在不同集群/网络
- ⚠️ 需要独立的 Redis 配置

---

## 四、推荐方案

### 推荐配置（方案A + 方案A）

```
RabbitMQ: 单个实例 + 多个队列
  ├── llmops-queue
  └── incubator-queue

Redis: 单个实例 + 结果键前缀
  ├── celery-task-meta-llmops-*
  └── celery-task-meta-incubator-*
```

#### 配置示例

```bash
# RabbitMQ 配置
CELERY_BROKER_URL="amqp://admin:admin123@rabbitmq-sunmoonai.messaging-platform-dev:5672//"
CELERY_QUEUES="llmops-queue,incubator-queue"

# Redis 配置
CELERY_RESULT_BACKEND="redis://redis-service.data-platform:6379/0"
```

#### 理由
1. **简单高效**：配置简单，易于维护
2. **资源节约**：只需一个 RabbitMQ 和一个 Redis
3. **天然隔离**：队列和结果键自动隔离
4. **易于扩展**：可以动态添加新队列和后端
5. **符合最佳实践**：大多数 Celery 部署采用此方案

---

## 五、高可用性考虑

### RabbitMQ 高可用
- 使用 RabbitMQ 集群模式
- 配置镜像队列（Mirrored Queues）
- 使用负载均衡器

### Redis 高可用
- 使用 Redis Sentinel 或 Redis Cluster
- 配置主从复制
- 使用负载均衡器

---

## 六、方案对比表

| 方案 | RabbitMQ | Redis | 资源占用 | 管理复杂度 | 隔离性 | 推荐度 |
|------|----------|-------|----------|------------|--------|--------|
| **推荐方案** | 单个+多队列 | 单个+键前缀 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 方案B | 多个实例 | 多个实例 | ⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| 方案C | 单个+VHost | 单个+多DB | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |

---

## 七、实施建议

### 当前阶段（2-3 个后端）
- ✅ 使用推荐方案：单个 RabbitMQ + 多个队列，单个 Redis + 结果键前缀
- ✅ 配置简单，维护成本低
- ✅ 满足隔离需求

### 未来扩展（5+ 个后端）
- 如果后端数量增加，仍然可以使用推荐方案
- 如果出现性能瓶颈，考虑：
  - RabbitMQ 集群
  - Redis 集群
  - 分片策略

### 特殊需求
- 如果需要完全隔离（安全合规），考虑方案B
- 如果资源紧张，优先考虑推荐方案

---

## 八、待确认问题

1. **RabbitMQ 方案**：
   - [ ] 选择方案A（单个+多队列）✅ 推荐
   - [ ] 选择方案B（多个实例）
   - [ ] 选择方案C（单个+VHost）

2. **Redis 方案**：
   - [ ] 选择方案A（单个+键前缀）✅ 推荐
   - [ ] 选择方案B（单个+多DB）
   - [ ] 选择方案C（多个实例）

3. **高可用性**：
   - [ ] 是否需要 RabbitMQ 集群？
   - [ ] 是否需要 Redis 集群/Sentinel？

4. **其他需求**：
   - [ ] 是否有安全合规要求？
   - [ ] 是否有性能要求？
   - [ ] 是否有成本限制？

---

## 九、配置示例（推荐方案）

### 配置文件
```bash
# deploy-multi-celeryworker.conf

# RabbitMQ 配置（单个实例 + 多个队列）
CELERY_BROKER_URL="amqp://admin:admin123@rabbitmq-sunmoonai.messaging-platform-dev:5672//"
CELERY_QUEUES="llmops-queue,incubator-queue"

# Redis 配置（单个实例 + 结果键前缀）
CELERY_RESULT_BACKEND="redis://redis-service.data-platform:6379/0"
REDIS_URL="redis://redis-service.data-platform:6379"
```

### YAML 配置
```yaml
env:
  - name: CELERY_BROKER_URL
    value: "${CELERY_BROKER_URL}"
  - name: CELERY_RESULT_BACKEND
    value: "${CELERY_RESULT_BACKEND}"
  - name: CELERY_QUEUES
    value: "${CELERY_QUEUES}"
  - name: REDIS_URL
    value: "${REDIS_URL}"
```

---

## 十、总结

**推荐使用**：
- **RabbitMQ**：单个实例 + 多个队列（`llmops-queue`, `incubator-queue`）
- **Redis**：单个实例 + 结果键前缀（自动区分 `llmops` 和 `incubator`）

**优势**：
- ✅ 配置简单
- ✅ 资源节约
- ✅ 易于维护
- ✅ 天然隔离
- ✅ 易于扩展

**请确认后，我将按照此方案实施配置。**

