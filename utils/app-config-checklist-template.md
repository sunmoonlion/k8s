# K8s 应用配置完整性检查清单（通用模板）

> 每个新 app 上 K8s 时，复制此文件到该 app 的 k8s 目录，按步骤填写。
> 目标：确保应用代码需要的每个环境变量，在 ConfigMap / Secret / 模板 / 脚本中都有对应。

---

## 使用方式

1. 阅读应用的配置源码（如 `config.py` / `.env.example` / `app.module.ts`）
2. 逐条列出所有环境变量，填入下方 Section 1
3. 逐项打勾 Section 2–5，发现缺失则补充后再打勾
4. Section 6 全部通过后，此 checklist 即为该应用的配置基准文档

---

## Section 1：应用代码字段需求

> 来源：应用配置文件（`config.py` / `.env.example` / NestJS ConfigService 等）

### ConfigMap 字段（非敏感，明文存储）

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `APP_NAME` | — | 应用名称 |
| `SERVER_HOST` | — | 服务监听地址 |
| `PORT` | — | 服务端口 |
| `CORS_ORIGINS` | — | 允许的跨域来源 |
| `DB_HOST` | — | 数据库地址 |
| `DB_PORT` | — | 数据库端口 |
| `DB_NAME` | — | 数据库名 |
| `DB_USER` | — | 数据库用户名 |
| `REDIS_HOST` | — | Redis 地址 |
| `REDIS_PORT` | `6379` | Redis 端口 |
| *(按应用实际需求增删)* | | |

### Secret 字段（敏感，加密存储）

| 变量名 | 说明 |
|--------|------|
| `DB_PASSWORD` | 数据库密码 |
| `DB_URL` | 完整数据库连接字符串（含密码） |
| `REDIS_PASSWORD` | Redis 密码（如有） |
| `SECRET_KEY` | 应用密钥 |
| *(按应用实际需求增删)* | |

---

## Section 2：ConfigMap 配置文件检查

> 文件：`resources/k8s-resource/custom-values/configMap/{app}-config/generate-{app}-config/generate-{app}-config.conf`

- [ ] Section 1 中所有 ConfigMap 字段均已出现在 `.conf` 文件中
- [ ] 有默认值的字段已填入合理默认值
- [ ] `NAMESPACE` / `ENVIRONMENT` / `ENV` 已包含

---

## Section 3：Secret 配置文件检查

> 文件：`resources/k8s-resource/custom-values/secret/{app}-secret/generate-{app}-secret/generate-{app}-secret.conf`

- [ ] Section 1 中所有 Secret 字段均已出现在 `.conf` 文件中
- [ ] 完整连接字符串（如 `DB_URL`）由生成脚本自动组装，而不是手填
- [ ] `NAMESPACE` / `ENVIRONMENT` / `ENV` 已包含

---

## Section 4：YAML 模板文件检查

> 文件：`resources/k8s-resource/templates/configMap/{app}-config.yaml`
> 文件：`resources/k8s-resource/templates/secret/{app}-secret.yaml`

- [ ] ConfigMap 模板中每个 key 与 `.conf` 文件中的变量名一一对应
- [ ] Secret 模板中每个 key 与 `.conf` 文件中的变量名一一对应
- [ ] 模板中无硬编码的敏感值

---

## Section 5：生成脚本检查

> 文件：`generate-{app}-config.sh` / `generate-{app}-secret.sh`

- [ ] 所有 ConfigMap 变量已在脚本中 `export`
- [ ] 所有 Secret 变量已在脚本中 `export`
- [ ] Secret 脚本从 ConfigMap conf 读取非敏感信息（避免重复维护）
- [ ] 连接字符串由脚本自动拼接（`DB_URL="${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"`）

---

## Section 6：职责分离验证

- [ ] **ConfigMap 只含非敏感信息**：无密码、无密钥、无 token
- [ ] **Secret 只含敏感信息**：不重复存储非敏感字段（连接字符串除外）
- [ ] **生成脚本不硬编码值**：所有值来自 `.conf` 文件或环境变量
- [ ] **模板文件无实际值**：只有占位符变量（`${VAR_NAME}`）

---

## Section 7：部署组件完整性

对照应用实际需求，确认以下 K8s 组件已就绪：

- [ ] Namespace
- [ ] ConfigMap
- [ ] Secret（应用 secret + harbor-registry-secret）
- [ ] Deployment + Service（app）
- [ ] Ingress
- [ ] Middleware（rate-limit 等，按需）
- [ ] PVC（如需持久化存储）

---

## 最终结论

| 检查项 | 结果 |
|--------|------|
| ConfigMap 字段覆盖率 | — / — |
| Secret 字段覆盖率 | — / — |
| 模板映射完整性 | ✅ / ❌ |
| 职责分离 | ✅ / ❌ |
| 部署组件完整性 | ✅ / ❌ |

> **结论**：配置完整 / 待补充（列出缺失项）
