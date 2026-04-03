# RabbitMQ 队列创建说明

## 问题

队列名称（如 `llmops-queue`, `incubator-queue`）是否需要在 RabbitMQ 中预先创建？

## 答案

**不需要！RabbitMQ 会自动创建队列**

## 队列创建机制

### 自动创建（推荐）

RabbitMQ 支持队列的**自动创建**机制：

1. **消费者首次监听队列时**：
   - 如果队列不存在，RabbitMQ 会自动创建
   - Celery Worker 启动时会自动创建它监听的队列

2. **生产者首次发送消息到队列时**：
   - 如果队列不存在，RabbitMQ 会自动创建
   - 后端服务发送任务时会自动创建目标队列

### 自动创建的特点

- ✅ **无需手动操作**：队列会在首次使用时自动创建
- ✅ **配置简单**：只需在配置中指定队列名称
- ✅ **灵活方便**：添加新队列只需修改配置，无需手动创建

### 自动创建的队列属性

自动创建的队列使用默认属性：
- **持久化**：取决于 Celery 配置（通常非持久化）
- **自动删除**：否
- **排他性**：否
- **参数**：无特殊参数

---

## 何时需要手动创建队列

### 场景1：需要特殊队列属性

如果需要设置队列的特殊属性，需要手动创建：

```bash
# 创建持久化队列
rabbitmqadmin declare queue name=llmops-queue durable=true

# 创建带 TTL 的队列
rabbitmqadmin declare queue name=llmops-queue arguments='{"x-message-ttl":3600000}'

# 创建优先级队列
rabbitmqadmin declare queue name=llmops-queue arguments='{"x-max-priority":10}'
```

### 场景2：需要队列权限控制

如果需要为不同用户设置队列权限：

```bash
# 设置队列权限
rabbitmqctl set_permissions -p / username '^llmops-queue$' '^llmops-queue$' '^llmops-queue$'
```

### 场景3：需要监控和管理

如果需要在队列创建前就进行监控和管理：

```bash
# 预先创建队列以便监控
rabbitmqadmin declare queue name=llmops-queue
rabbitmqadmin declare queue name=incubator-queue
```

---

## Celery 队列配置

### Celery 自动创建队列

Celery 在以下情况下会自动创建队列：

1. **Worker 启动时**：
   ```python
   # Celery Worker 启动时会自动创建监听的队列
   celery -A app worker --queues=llmops-queue,incubator-queue
   ```

2. **发送任务时**：
   ```python
   # 如果队列不存在，发送任务时会自动创建
   task.delay(args, queue='llmops-queue')
   ```

### Celery 队列配置选项

可以在 Celery 配置中设置队列属性。**这些配置应该在后端服务的代码中**，因为 Worker 会从后端镜像提取代码。

#### 配置位置

配置应该在后端服务的 Celery 配置文件中，通常位于：
- `app/core/celery.py` 或 `app/core/celeryconfig.py`
- `app/worker/__init__.py` 或 `app/worker/celery_app.py`

#### 配置示例

```python
# app/core/celery.py 或 app/core/celeryconfig.py
from kombu import Queue

# 定义队列
task_queues = (
    Queue('llmops-queue', routing_key='llmops.#'),
    Queue('incubator-queue', routing_key='incubator.#'),
)

# 设置队列属性
task_queue_durable = True  # 队列持久化（RabbitMQ 重启后队列仍然存在）
task_queue_auto_delete = False  # 队列不自动删除
task_queue_exclusive = False  # 队列不排他（允许多个消费者）

# 或者使用环境变量配置
import os
task_queue_durable = os.getenv('CELERY_QUEUE_DURABLE', 'True').lower() == 'true'
```

#### 为什么在后端服务中配置？

1. **代码提取机制**：Worker 通过 Init Container 从后端镜像提取代码
2. **配置一致性**：确保 Worker 和 Backend 使用相同的队列配置
3. **统一管理**：队列配置与任务定义在一起，便于维护

#### 配置生效流程

```
1. 后端服务代码中定义队列配置
   ↓
2. 后端服务构建镜像（包含队列配置）
   ↓
3. Worker Init Container 从后端镜像提取代码（包含队列配置）
   ↓
4. Worker 启动时使用提取的配置创建队列
```

#### 当前架构中的配置位置

根据代码提取配置（`deploy-multi-celeryworker.conf`）：
- 提取目录：`core`（通常包含 Celery 配置）
- 配置应该在：`/app/app/core/celery.py` 或类似位置
- Worker 提取后会挂载到：`/app/app/core/`（在 Worker 容器中）

---

## 推荐做法

### 方案A：完全自动（推荐）⭐

**适用场景**：大多数场景

- ✅ 无需手动创建队列
- ✅ 队列在首次使用时自动创建
- ✅ 配置简单，维护方便

**配置**：
```bash
# 只需在配置中指定队列名称
CELERY_QUEUES="llmops-queue,incubator-queue"
```

### 方案B：预先创建（可选）

**适用场景**：
- 需要特殊队列属性
- 需要队列权限控制
- 需要提前监控队列

**步骤**：
1. 使用 `rabbitmqadmin` 或管理界面创建队列
2. 设置队列属性（持久化、TTL 等）
3. 配置 Celery 使用这些队列

---

## 实际使用示例

### 当前配置（自动创建）

```bash
# deploy-multi-celeryworker.conf
CELERY_QUEUES="llmops-queue,incubator-queue"
```

**工作流程**：
1. Celery Worker 启动
2. 连接到 RabbitMQ
3. 自动创建 `llmops-queue` 和 `incubator-queue`（如果不存在）
4. 开始监听这些队列

### 验证队列创建

```bash
# 查看队列列表
rabbitmqctl list_queues

# 输出示例：
# llmops-queue    0
# incubator-queue 0
```

---

## 注意事项

### 1. 队列名称一致性

确保队列名称在以下地方保持一致：
- ✅ Celery Worker 配置：`CELERY_QUEUES`
- ✅ 后端服务发送任务时指定的队列名称
- ✅ RabbitMQ 中实际创建的队列名称

### 2. 队列持久化

如果需要队列持久化（RabbitMQ 重启后队列仍然存在）：

**方式1：Celery 配置**
```python
# celeryconfig.py
task_queue_durable = True
```

**方式2：手动创建**
```bash
rabbitmqadmin declare queue name=llmops-queue durable=true
```

### 3. 队列权限

如果 RabbitMQ 启用了权限控制，确保用户有创建队列的权限：

```bash
# 授予用户创建队列的权限
rabbitmqctl set_permissions -p / username '.*' '.*' '.*'
```

---

## 总结

**推荐做法**：
- ✅ **不需要预先创建队列**
- ✅ RabbitMQ 会在首次使用时自动创建
- ✅ 只需在配置中指定队列名称即可

**何时需要手动创建**：
- ⚠️ 需要特殊队列属性（持久化、TTL、优先级等）
- ⚠️ 需要队列权限控制
- ⚠️ 需要提前监控和管理队列

**当前配置**：
- ✅ 使用自动创建机制
- ✅ 队列名称：`llmops-queue`, `incubator-queue`
- ✅ Worker 启动时会自动创建这些队列

