# SESSION HANDOFF

> 每次对话结束时更新本文件。新对话开始先读这里。

---

## 当前状态（2026-04-01）

### 已完成

- [x] 全面分析 k8s 项目结构（2472 个文件）
- [x] 创建 `docs-claude/整体架构.md`（稳定架构描述）
- [x] 创建 `docs-claude/环境事实表.md`（可变环境事实，含真实 IP/凭据）
- [x] 域名统一：33 个 `.conf` / `.sh` 文件从 `llmops.sunmoonai.com` 改为 `www.sunmoonai.com`
- [x] 创建 `CLAUDE.md`（项目级规则）
- [x] 创建 `.cursor/rules/`（Cursor 规则）

### 基础设施状态

| 组件 | 状态 |
|------|------|
| Traefik（ingress-platform） | ✅ 完成 |
| Harbor（cicd-platform） | ✅ 完成 |
| PostgreSQL（data-platform） | ✅ 完成 |
| Redis（data-platform） | ✅ 完成 |
| MongoDB（data-platform） | ✅ 完成 |
| RabbitMQ（messaging-platform） | ✅ 完成 |
| ops-platform（pgAdmin 等） | ✅ 完成 |

### 应用开发状态

| 应用 | 源代码 | K8s 部署配置 | 状态 |
|------|--------|-------------|------|
| auth-app-bff（NestJS） | `Desktop/auth-app-backend` | `sunmoonai/auth-app/auth-app-bff/` | 🔜 下一步 |
| auth-app-ssr（Nuxt 3） | `Desktop/auth-app-frontend` | `sunmoonai/auth-app/auth-app-ssr/` | 🔜 下一步 |
| portal-app | 待定 | `sunmoonai/portal-app/` | ⏳ 待排期 |
| llmops-app | 待定 | `sunmoonai/llmops-app/` | ⏳ 待排期 |
| incubator-app | 待定 | `sunmoonai/incubator-app/` | ⏳ 待排期 |
| document-converter-app | 待定 | `sunmoonai/document-converter-app/` | ⏳ 待排期 |

---

## 下一步

1. **分析 auth-app-backend 和 auth-app-frontend**：读懂环境变量需求、健康检查端点、Prisma migration 流程
2. **完善 auth-app K8s 部署配置**：对照现有 data-platform 组件补全 `.conf`、`values.yaml`、Secret、Ingress
3. **联调 auth-app**：在 C1 集群跑通注册/登录流程

---

## 重要约定备忘

- 域名：统一 `www.sunmoonai.com`（历史上曾用 `llmops.sunmoonai.com`，已全面替换）
- Traefik：C1 单副本，Pod 在 Worker1（`101.126.151.0`），DNS 指向此节点
- auth-app BFF 实际是 NestJS（历史文档误写为 FastAPI）
- Nitro 多实例生产须配 `REDIS_URL`
