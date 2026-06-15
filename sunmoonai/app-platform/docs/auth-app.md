# Auth App 架构

## 1. 系统定位

`auth-app` 是 App Platform 的统一身份与访问管理系统，负责用户、组织、服务身份、认证和平台级授权能力。

当前以 Casdoor 作为 OIDC/OAuth 2.0 身份提供方。长期架构不把业务系统绑定到 Casdoor 私有数据结构，其他 App 只依赖标准身份协议和平台授权契约。

## 2. 职责边界

负责：

- 用户、组织、成员关系和账号生命周期。
- OIDC/OAuth 2.0 登录、Token 和 MFA。
- 应用客户端与服务身份。
- 平台角色、权限和授权策略。
- 登录、授权和管理操作审计。

不负责：

- 资讯、投资组合等业务数据。
- 各领域对象的业务规则。
- 业务 App 的页面会话实现。
- 代替业务 App 判断具体资源是否可访问。

业务 App 可以基于统一身份定义本领域角色和资源级权限，但不得自行建立另一套用户主档。

## 3. 核心模型

```text
User
Organization
OrganizationMembership
IdentityProvider
ApplicationClient
ServiceIdentity
Role
Permission
Policy
SessionReference
AuditEvent
```

用户和组织使用稳定内部 ID。邮箱、手机号、用户名和外部身份 ID 都是可变属性或映射，不能作为跨系统永久主键。

## 4. 认证架构

推荐使用 Authorization Code Flow 和 PKCE。

```text
Browser
  -> Business BFF / Backend
  -> Casdoor
  -> callback
  -> server-side session
```

- 有 BFF 的应用由 BFF 完成 OIDC 流程。
- 纯 SPA 由业务后端完成 OIDC 流程。
- 浏览器优先只保存 HttpOnly、Secure、SameSite Cookie。
- OIDC Token 和业务 Session 分离。
- 服务间调用使用服务身份，不模拟普通用户登录。

现有详细接入说明继续保留在 `auth-app/README.md`。

## 5. 授权模型

授权分为两层：

### 平台级授权

由 `auth-app` 管理：

- App 访问权。
- 平台管理员和组织管理员。
- 服务身份及其 Scope。
- 通用角色和权限定义。

### 领域级授权

由业务 App 执行：

- 某个资讯源是否可见。
- 某个投资组合是否允许修改。
- 某项决策是否允许审批。

领域 App 使用 `subject_id`、组织关系、平台权限和本地资源关系完成最终判断。

## 6. 对外契约

提供或支持：

- 标准 OIDC Discovery、Authorization、Token、JWKS 和 UserInfo。
- 用户与组织的受控查询接口。
- 服务身份和客户端凭据管理。
- 用户禁用、组织关系变化等领域事件。

建议事件：

```text
auth.user.created.v1
auth.user.disabled.v1
auth.organization.membership-changed.v1
auth.service-identity.revoked.v1
```

业务 App 必须验证 Token 的签名、Issuer、Audience、有效期和必要 Scope。

## 7. 数据与安全

- 用户、组织和身份映射是 A 级权威数据。
- Session 可以存储在 Redis，但 Redis 不是用户主档。
- 密码、客户端密钥和 MFA Secret 必须采用适当的哈希或加密。
- 生产密钥进入专用 Secret 管理系统。
- 登录、提权、禁用、授权变更和管理操作必须审计。
- Token 和 Session 具有明确过期、刷新和吊销策略。

## 8. 当前部署与目标组件

当前组件：

```text
auth-app
├── casdoor
├── auth-app-backend
├── auth-app-front
└── deploy-auth-app-all
```

当前 Kind 主要启用 Casdoor，其余组件尚未作为完整身份门户启用。

长期可以演进为：

```text
casdoor
auth-management-api
auth-management-ui
authorization-service
audit-exporter
```

只有出现独立扩缩容或维护需求时才拆分服务。

## 9. 分阶段建设

### 第一阶段

- 固定 OIDC 接入规范。
- 建立统一用户、组织和服务身份。
- 为各 App 配置独立 Client、Audience 和 Scope。
- 统一服务端 Session 方案。

### 第二阶段

- 建立平台角色和权限目录。
- 支持用户禁用、组织变更事件。
- 完成认证授权审计和管理界面。

### 第三阶段

- MFA、外部身份源和账号恢复。
- 细粒度策略、职责分离和定期权限复核。
- 高可用、密钥轮换和灾难恢复。

## 10. 验收标准

- 各 App 不保存独立用户主档。
- 用户禁用后，现有会话能在约定时间内失效。
- 服务间调用使用独立服务身份。
- 权限判断和关键管理操作可以审计。
- Casdoor 替换不会要求重写业务领域模型。
