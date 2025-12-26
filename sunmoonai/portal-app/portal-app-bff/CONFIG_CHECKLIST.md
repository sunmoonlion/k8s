# Portal App BFF 配置检查清单

本文档列出 Portal App BFF 部署前需要检查的配置项。

## 联动环境变量（必须配置）

### 服务自身配置
- [ ] `PORT=3000` - HTTP 服务端口（SSR 的 BFF_URL 需要与此端口一致）
- [ ] `PREFIX=/api` - API 前缀（SSR 调用时使用）
- [ ] `VERSION=v1` - API 版本（SSR 调用时使用）
- [ ] `SESSION_COOKIE_NAME=sunmoonai_session` - Session Cookie 名称（必须与 auth-app-bff 和 SSR 一致）

### 认证服务配置
- [ ] `AUTH_SERVICE_URL=http://auth-app-bff:3030` - 认证服务地址（必须与 auth-app-bff 的 PORT 一致）

## 其他配置（业务特定）

- [ ] `CORS=true` - CORS 配置
- [ ] `ERROR_FILTER=true` - 错误过滤器
- [ ] `JWT_SECRET` - JWT 密钥（Secret）
- [ ] `DATABASE_URL` - 数据库连接字符串（Secret）

## 部署前检查

1. ✅ 确认 `AUTH_SERVICE_URL` 的端口与 `auth-app-bff` 的 `PORT` 一致（3030）
2. ✅ 确认 `SESSION_COOKIE_NAME` 与所有服务一致（`sunmoonai_session`）
3. ✅ 确认镜像已构建并推送到 Harbor
4. ✅ 确认 ConfigMap 和 Secret 已创建
5. ✅ 确认命名空间已创建

