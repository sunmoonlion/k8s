# 环境变量映射关系说明

本文档说明 `auth-app-bff` 和业务 BFF（`portal-app-bff`、`incubator-app-bff`、`llmops-app-bff`）之间的环境变量映射关系。

## 核心原则

**业务 BFF 需要知道 `auth-app-bff` 的访问地址和路径配置，才能正确调用它。**

当 `auth-app-bff` 的环境变量改变时，**业务 BFF 中的 `AUTH_SERVICE_URL` 环境变量需要相应调整**。

---

## auth-app-bff 环境变量

### 关键配置

| 环境变量 | 默认值 | 说明 | 影响范围 |
|---------|--------|------|---------|
| `PORT` | `3030` | HTTP 服务端口 | 业务 BFF 需要知道此端口 |
| `PREFIX` | `/api` | API 前缀 | 业务 BFF 需要知道此前缀 |
| `VERSION` | `v1` | API 版本 | 业务 BFF 需要知道此版本 |

### 实际访问地址

根据 `auth-app-bff` 的配置，完整的 API 地址为：

```
http://{HOST}:{PORT}{PREFIX}/{VERSION}/auth/me
```

**示例：**
- 开发环境：`http://localhost:3030/api/v1/auth/me`
- 生产环境（K8s）：`http://auth-app-bff:3030/api/v1/auth/me`

---

## 业务 BFF 环境变量配置

### portal-app-bff (NestJS)

**文件：`src/common/auth-client/auth-client.service.ts`**

```typescript
constructor(private configService: ConfigService) {
  this.baseUrl =
    this.configService.get<string>('AUTH_SERVICE_URL') ||
    'http://localhost:3030';  // 默认值需要与 auth-app-bff 的 PORT 一致
}
```

**环境变量配置：**

```bash
# .env.development
AUTH_SERVICE_URL=http://localhost:3030

# .env.production (K8s)
AUTH_SERVICE_URL=http://auth-app-bff:3030
```

**⚠️ 重要：**
- `AUTH_SERVICE_URL` 只需要包含 **基础地址**（协议 + 主机 + 端口）
- **不需要**包含 `/api/v1` 路径，因为代码中已经硬编码了路径

**代码中的使用：**

```typescript
// ✅ 正确：baseUrl 只包含基础地址
const response = await this.httpClient.get(
  `${this.baseUrl}/api/v1/auth/me`,  // 路径在代码中硬编码
  { headers }
);
```

### incubator-app-bff / llmops-app-bff (FastAPI)

**文件：`app/core/config.py`**

```python
class Settings(BaseSettings):
    AUTH_SERVICE_URL: str = "http://localhost:3030"  # 默认值需要与 auth-app-bff 的 PORT 一致
```

**环境变量配置：**

```bash
# .env
AUTH_SERVICE_URL=http://localhost:3030

# 生产环境 (K8s)
AUTH_SERVICE_URL=http://auth-app-bff:3030
```

**代码中的使用：**

```python
# ✅ 正确：base_url 只包含基础地址
response = await client.get(
    f"{self.base_url}/api/v1/auth/me",  # 路径在代码中硬编码
    headers=headers
)
```

---

## 环境变量变更场景

### 场景 1：auth-app-bff 端口改变

**如果 `auth-app-bff` 的 `PORT` 从 `3030` 改为 `8080`：**

```bash
# auth-app-bff .env
PORT=8080  # 改变了
```

**那么业务 BFF 的 `AUTH_SERVICE_URL` 也需要改变：**

```bash
# portal-app-bff .env
AUTH_SERVICE_URL=http://localhost:8080  # 需要更新端口

# incubator-app-bff .env
AUTH_SERVICE_URL=http://localhost:8080  # 需要更新端口

# llmops-app-bff .env
AUTH_SERVICE_URL=http://localhost:8080  # 需要更新端口
```

### 场景 2：auth-app-bff 前缀改变

**如果 `auth-app-bff` 的 `PREFIX` 从 `/api` 改为 `/v1/api`：**

```bash
# auth-app-bff .env
PREFIX=/v1/api  # 改变了
```

**那么业务 BFF 的代码需要修改：**

```typescript
// portal-app-bff: 需要修改代码中的路径
const response = await this.httpClient.get(
  `${this.baseUrl}/v1/api/v1/auth/me`,  // 需要更新路径
  { headers }
);
```

**⚠️ 注意：** 这种情况下，不仅环境变量需要改，**代码也需要改**。

### 场景 3：auth-app-bff 版本改变

**如果 `auth-app-bff` 的 `VERSION` 从 `v1` 改为 `v2`：**

```bash
# auth-app-bff .env
VERSION=v2  # 改变了
```

**那么业务 BFF 的代码需要修改：**

```typescript
// portal-app-bff: 需要修改代码中的路径
const response = await this.httpClient.get(
  `${this.baseUrl}/api/v2/auth/me`,  // 需要更新版本号
  { headers }
);
```

**⚠️ 注意：** 这种情况下，不仅环境变量需要改，**代码也需要改**。

### 场景 4：K8s 服务名称改变

**如果 `auth-app-bff` 的 K8s Service 名称从 `auth-app-bff` 改为 `auth-service`：**

```yaml
# auth-app-bff k8s service
apiVersion: v1
kind: Service
metadata:
  name: auth-service  # 改变了
```

**那么业务 BFF 的 `AUTH_SERVICE_URL` 需要改变：**

```bash
# portal-app-bff .env (生产环境)
AUTH_SERVICE_URL=http://auth-service:3030  # 需要更新服务名称
```

---

## 环境变量配置检查清单

### ✅ 开发环境

- [ ] `auth-app-bff` 的 `PORT` 配置
- [ ] 业务 BFF 的 `AUTH_SERVICE_URL` 是否指向正确的 `auth-app-bff` 地址
- [ ] 端口号是否一致

### ✅ 生产环境（K8s）

- [ ] `auth-app-bff` 的 `PORT` 配置
- [ ] `auth-app-bff` 的 K8s Service 名称
- [ ] 业务 BFF 的 `AUTH_SERVICE_URL` 是否使用正确的 K8s Service 名称
- [ ] 端口号是否一致

---

## 当前配置映射表

### auth-app-bff

| 环境变量 | 默认值 | 说明 |
|---------|--------|------|
| `PORT` | `3030` | HTTP 服务端口 |
| `PREFIX` | `/api` | API 前缀 |
| `VERSION` | `v1` | API 版本 |

### portal-app-bff

| 环境变量 | 默认值 | 说明 | 对应 auth-app-bff |
|---------|--------|------|-------------------|
| `AUTH_SERVICE_URL` | `http://localhost:3030` | 认证服务地址 | `PORT=3030` |

### incubator-app-bff / llmops-app-bff

| 环境变量 | 默认值 | 说明 | 对应 auth-app-bff |
|---------|--------|------|-------------------|
| `AUTH_SERVICE_URL` | `http://localhost:3030` | 认证服务地址 | `PORT=3030` |

---

## 最佳实践

### 1. 使用环境变量而非硬编码

**✅ 推荐：**
```typescript
// 使用环境变量
this.baseUrl = this.configService.get<string>('AUTH_SERVICE_URL') || 
               'http://localhost:3030';
```

**❌ 不推荐：**
```typescript
// 硬编码地址
this.baseUrl = 'http://localhost:3030';
```

### 2. 提供合理的默认值

**✅ 推荐：**
```typescript
// 默认值与 auth-app-bff 的默认配置一致
this.baseUrl = this.configService.get<string>('AUTH_SERVICE_URL') || 
               'http://localhost:3030';  // 与 auth-app-bff 的 PORT=3030 一致
```

### 3. 文档化环境变量依赖关系

在 README 或配置文档中明确说明：
- 业务 BFF 依赖 `auth-app-bff` 的哪些配置
- 当 `auth-app-bff` 配置改变时，需要同步更新哪些环境变量

### 4. 使用配置中心（可选）

对于大型系统，可以考虑使用配置中心（如 Consul、Nacos）来管理服务发现和配置，避免手动同步环境变量。

---

## 总结

**回答：如果在 `auth-app-bff` 中使用环境变量，那么在 `portal-app-bff` 中的环境变量要改吗？**

**答案：需要改，但只改 `AUTH_SERVICE_URL` 中的地址部分（协议 + 主机 + 端口）。**

**具体规则：**

1. **如果 `auth-app-bff` 的 `PORT` 改变** → 需要更新业务 BFF 的 `AUTH_SERVICE_URL` 中的端口
2. **如果 `auth-app-bff` 的 `PREFIX` 或 `VERSION` 改变** → 需要更新业务 BFF 的**代码**（因为路径是硬编码的）
3. **如果 `auth-app-bff` 的 K8s Service 名称改变** → 需要更新业务 BFF 的 `AUTH_SERVICE_URL` 中的主机名

**建议：**
- 保持 `auth-app-bff` 的默认配置稳定（`PORT=3030`、`PREFIX=/api`、`VERSION=v1`）
- 如果必须改变，同时更新所有业务 BFF 的配置和代码
- 在文档中明确记录这些依赖关系

