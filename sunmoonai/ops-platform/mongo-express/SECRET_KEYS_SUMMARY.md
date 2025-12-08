# Mongo Express Secret 键名配置清单

## 概述

**重要说明**：Mongo Express 使用 **1个 Secret 对象**（Kubernetes Secret 资源），这个 Secret 对象包含 **多个键值对**。

- **Secret 对象数量**: 1个（名称：`mongo-express-secrets`）
- **Secret 中的键数量**: 6个键值对
  - 5个是 Mongo Express 实际使用的必需键
  - 1个是辅助键（`mongo-express-admin-user`，用于存储管理员用户名）

**类比理解**：
- 就像 Python 字典或 JSON 对象：1个对象，包含多个键值对
- Secret 对象 = 容器
- 键（keys）= 容器中的字段名
- 值（values）= 容器中的字段值

### 与其他组件的对比

| 组件 | Secret 对象数 | Secret 中的键数 | 说明 |
|------|--------------|----------------|------|
| **mongo-express** | 1个 | **6个键** | 需要 MongoDB 密码、Basic Auth 密码、Cookie/Session 签名密钥 |
| **pgAdmin** | 1个 | **1个键** | 只需要密码，用户名在 values 文件中配置 |
| **RedisInsight** | 0个（认证） | - | 不需要认证 Secret，认证在应用层面处理 |

**为什么 mongo-express 需要这么多键？**

mongo-express 是一个完整的 Web 应用，需要：
1. **MongoDB 连接密码** - 连接 MongoDB 数据库
2. **Basic Auth 密码** - Web 界面登录认证
3. **Cookie Secret** - Cookie 签名密钥（安全要求）
4. **Session Secret** - Session 签名密钥（安全要求）
5. **MongoDB 认证密码** - 非管理员模式的数据库认证

而 pgAdmin 只需要密码，RedisInsight 不需要认证 Secret。

## Secret 基本信息
- **Secret 名称**: `mongo-express-secrets`
- **Secret 类型**: `Opaque`
- **Secret 命名空间**: `ops-platform-dev`（可配置）
- **Secret 中的键值对数量**: 6个

### 实际结构示例

这个 Secret 对象在 Kubernetes 中的结构类似于：

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mongo-express-secrets
  namespace: ops-platform-dev
type: Opaque
data:
  mongo-express-password: <base64编码的密码>
  mongo-express-admin-user: <base64编码的用户名>
  mongodb-auth-password: <base64编码的密码>
  site-cookie-secret: <base64编码的密钥>
  site-session-secret: <base64编码的密钥>
  basic-auth-password: <base64编码的密码>
```

**总结**：
- ✅ **1个 Secret 对象**（`mongo-express-secrets`）
- ✅ **6个键值对**（data 字段下的 6 个键）

---

## Secret 键名清单

### 1. MongoDB 管理员密码
- **键名**: `mongo-express-password`
- **用途**: MongoDB 管理员账户密码（用于连接 MongoDB）
- **环境变量**: `MONGODB_PASSWORD` (当 `mongodbEnableAdmin=true` 时使用)
- **配置位置**:
  - `dev-values.yaml` (第157行): `existingSecretKeyMongodbAdminPassword: "{{MONGO_EXPRESS_AUTH_SECRET_PASSWORD_KEY}}"`
  - `deploy-mongo-express.conf` (第35行): `MONGO_EXPRESS_AUTH_SECRET_PASSWORD_KEY="mongo-express-password"`
  - `deploy-mongo-express-secrets.conf` (第25行): `MONGO_EXPRESS_AUTH_SECRET_PASSWORD_KEY="mongo-express-password"`
- **生成方式**: 如果未提供，自动生成16位随机密码

### 2. MongoDB 认证密码
- **键名**: `mongodb-auth-password`
- **用途**: MongoDB 数据库认证密码（当不使用管理员模式时）
- **环境变量**: `MONGODB_PASSWORD` (当 `mongodbEnableAdmin=false` 时使用)
- **配置位置**:
  - `dev-values.yaml` (第158行): `existingSecretKeyMongodbAuthPassword: "mongodb-auth-password"`
  - `deploy-mongo-express-secrets.conf` (第31行): `MONGO_EXPRESS_MONGODB_AUTH_PASSWORD_KEY="mongodb-auth-password"`
- **生成方式**: 默认使用 `mongo-express-password` 的值
- **注意**: 当 `mongodbEnableAdmin=false` 时，还需要在 `dev-values.yaml` 中配置：
  - `mongodbAuthUsername`: 数据库用户名（**不在 Secret 中，直接在 values 文件中配置**）
  - `mongodbAuthDatabase`: 数据库名（**不在 Secret 中，直接在 values 文件中配置**）

### 3. Cookie Secret
- **键名**: `site-cookie-secret`
- **用途**: Cookie 签名密钥（用于 cookie-parser 中间件）
- **环境变量**: `ME_CONFIG_SITE_COOKIESECRET`
- **配置位置**:
  - `dev-values.yaml` (第159行): `existingSecretKeySiteCookieSecret: "site-cookie-secret"`
  - `deploy-mongo-express-secrets.conf` (第32行): `MONGO_EXPRESS_SITE_COOKIE_SECRET_KEY="site-cookie-secret"`
- **生成方式**: 自动生成32字符随机字符串

### 4. Session Secret
- **键名**: `site-session-secret`
- **用途**: Session 签名密钥（用于 express-session 中间件）
- **环境变量**: `ME_CONFIG_SITE_SESSIONSECRET`
- **配置位置**:
  - `dev-values.yaml` (第160行): `existingSecretKeySiteSessionSecret: "site-session-secret"`
  - `deploy-mongo-express-secrets.conf` (第33行): `MONGO_EXPRESS_SITE_SESSION_SECRET_KEY="site-session-secret"`
- **生成方式**: 自动生成32字符随机字符串

### 5. Basic Auth 密码
- **键名**: `basic-auth-password`
- **用途**: Mongo Express Web 界面登录密码
- **环境变量**: `ME_CONFIG_BASICAUTH_PASSWORD`
- **配置位置**:
  - `dev-values.yaml` (第168行): `existingSecretKeyBasicAuthPassword: "{{MONGO_EXPRESS_BASIC_AUTH_PASSWORD_KEY}}"`
  - `deploy-mongo-express.conf` (第42行): `MONGO_EXPRESS_BASIC_AUTH_PASSWORD_KEY="basic-auth-password"`
  - `deploy-mongo-express-secrets.conf` (第34行): `MONGO_EXPRESS_BASIC_AUTH_PASSWORD_KEY="basic-auth-password"`
- **生成方式**: 如果未提供，自动生成16位随机密码

### 6. 管理员用户名（辅助键，可选）
- **键名**: `mongo-express-admin-user`
- **用途**: 管理员用户名（存储用，实际从 values 文件读取）
- **配置位置**:
  - `deploy-mongo-express-secrets.conf` (第28行): `MONGO_EXPRESS_ADMIN_USER_KEY="mongo-express-admin-user"`
- **生成方式**: 默认值 `admin`

---

## 用户名配置说明

### 管理员模式（当前配置）

当 `mongodbEnableAdmin: true` 时（当前配置）：
- **用户名**: 在 `dev-values.yaml` 中配置 `mongodbAdminUsername: root`（**不在 Secret 中**）
- **密码**: 从 Secret 的 `mongo-express-password` 键读取

### 非管理员模式

当 `mongodbEnableAdmin: false` 时：
- **用户名**: 在 `dev-values.yaml` 中配置 `mongodbAuthUsername: "your-username"`（**不在 Secret 中**）
- **数据库名**: 在 `dev-values.yaml` 中配置 `mongodbAuthDatabase: "your-database"`（**不在 Secret 中**）
- **密码**: 从 Secret 的 `mongodb-auth-password` 键读取

**总结**：
- ✅ **密码**存储在 Secret 中
- ✅ **用户名和数据库名**直接在 `dev-values.yaml` 中配置（不在 Secret 中）

---

## 配置文件位置汇总

### 1. Secret 名称配置
- **文件**: `deploy-mongo-express/deploy-mongo-express.conf`
  - 第34行: `MONGO_EXPRESS_AUTH_SECRET_NAME="mongo-express-secrets"`
- **文件**: `deploy-mongo-express/secrets/mongo-express-secrets/deploy-mongo-express-secrets/deploy-mongo-express-secrets.conf`
  - 第12行: `SECRET_NAME="mongo-express-secrets"`

### 2. Secret 键名配置
- **文件**: `deploy-mongo-express/deploy-mongo-express.conf`
  - 第35行: `MONGO_EXPRESS_AUTH_SECRET_PASSWORD_KEY="mongo-express-password"`
- **文件**: `deploy-mongo-express/secrets/mongo-express-secrets/deploy-mongo-express-secrets/deploy-mongo-express-secrets.conf`
  - 第25行: `MONGO_EXPRESS_AUTH_SECRET_PASSWORD_KEY="mongo-express-password"`
  - 第28行: `MONGO_EXPRESS_ADMIN_USER_KEY="mongo-express-admin-user"`
  - 第31行: `MONGO_EXPRESS_MONGODB_AUTH_PASSWORD_KEY="mongodb-auth-password"`
  - 第32行: `MONGO_EXPRESS_SITE_COOKIE_SECRET_KEY="site-cookie-secret"`
  - 第33行: `MONGO_EXPRESS_SITE_SESSION_SECRET_KEY="site-session-secret"`
  - 第34行: `MONGO_EXPRESS_BASIC_AUTH_PASSWORD_KEY="basic-auth-password"`

### 3. Values 文件中的键名引用
- **文件**: `resources/custom-values/dev-values.yaml`
  - 第156行: `existingSecret: "{{MONGO_EXPRESS_AUTH_SECRET_NAME}}"`
  - 第157行: `existingSecretKeyMongodbAdminPassword: "{{MONGO_EXPRESS_AUTH_SECRET_PASSWORD_KEY}}"`
  - 第158行: `existingSecretKeyMongodbAuthPassword: "mongodb-auth-password"`
  - 第159行: `existingSecretKeySiteCookieSecret: "site-cookie-secret"`
  - 第160行: `existingSecretKeySiteSessionSecret: "site-session-secret"`
  - 第161行: `existingSecretKeyBasicAuthPassword: "basic-auth-password"`

### 4. Chart 模板中的默认键名
- **文件**: `resources/mongo-express/templates/_helpers.tpl`
  - 第106行: 默认 `mongodb-admin-password`（当不使用 existingSecret 时）
  - 第117行: 默认 `mongodb-auth-password`（当不使用 existingSecret 时）
  - 第128行: 默认 `site-cookie-secret`（当不使用 existingSecret 时）
  - 第139行: 默认 `site-session-secret`（当不使用 existingSecret 时）
  - 第150行: 默认 `basic-auth-password`（当不使用 existingSecret 时）

---

## 配置流程

1. **Secret 键名定义** → `deploy-mongo-express-secrets.conf`
2. **Secret 生成** → `deploy-mongo-express-secrets.sh` 使用配置的键名生成 Secret
3. **Values 文件引用** → `dev-values.yaml` 通过模板变量引用键名
4. **部署脚本替换** → `deploy-mongo-express.sh` 将模板变量替换为实际值
5. **Chart 使用** → Chart 模板从 Secret 中读取对应键的值

---

## 注意事项

1. **键名必须一致**: `dev-values.yaml` 中的键名必须与 `deploy-mongo-express-secrets.conf` 中定义的键名完全一致
2. **模板变量**: `dev-values.yaml` 中 `{{MONGO_EXPRESS_AUTH_SECRET_PASSWORD_KEY}}` 会在部署时被替换为实际键名
3. **硬编码键名**: `dev-values.yaml` 中其他键名（如 `mongodb-auth-password`）是硬编码的，必须与配置文件中的键名匹配
4. **Secret 生成**: 部署脚本会自动生成所有必需的 Secret 键值对

