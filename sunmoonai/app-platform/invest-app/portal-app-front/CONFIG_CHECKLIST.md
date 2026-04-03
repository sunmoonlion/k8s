# Portal App SSR 配置检查清单

本文档列出 Portal App SSR 部署前需要检查的配置项。

## 联动环境变量（必须配置）

### 业务 BFF 配置
- [ ] `VUE_APP_BFF_URL=http://portal-app-backend:3000` - 业务 BFF 地址（必须与 portal-app-backend 的 PORT 一致）
- [ ] `PORTAL_BFF_URL=http://portal-app-backend:3000` - 业务 BFF 地址（备用）
- [ ] `VUE_APP_API_PREFIX=/api` - API 前缀（必须与 portal-app-backend 的 PREFIX 一致）
- [ ] `VUE_APP_API_VERSION=v1` - API 版本（必须与 portal-app-backend 的 VERSION 一致）

### Session 配置
- [ ] `SESSION_COOKIE_NAME=sunmoonai_session` - Session Cookie 名称（必须与 auth-app-backend 和业务 BFF 一致）

## 其他配置（业务特定）

- [ ] `NODE_ENV=production` - Node 环境
- [ ] `SERVER_NAME=portal-front.sunmoonai.com` - 服务器名称
- [ ] `SERVER_HOST=https://portal-front.sunmoonai.com` - 服务器地址

## 部署前检查

1. ✅ 确认 `BFF_URL` 的端口与 `portal-app-backend` 的 `PORT` 一致（3000）
2. ✅ 确认 `API_PREFIX` 与 `portal-app-backend` 的 `PREFIX` 一致（`/api`）
3. ✅ 确认 `API_VERSION` 与 `portal-app-backend` 的 `VERSION` 一致（`v1`）
4. ✅ 确认 `SESSION_COOKIE_NAME` 与所有服务一致（`sunmoonai_session`）
5. ✅ 确认镜像已构建并推送到 Harbor
6. ✅ 确认 ConfigMap 和 Secret 已创建
7. ✅ 确认命名空间已创建

