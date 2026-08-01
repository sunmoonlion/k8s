# ADR-0007：每个领域 App 只有一个规范 Backend

- 状态：已接受
- 日期：2026-08-01
- 取代：ADR-0006 中默认保留 Admin/Web 两个 Backend 的部分

## 背景

旧模板按前端表面拆出 `admin-backend` 和 `web-backend`。实例化后，两套 Backend 重复
认证、配置、存储、审计和基础设施能力，并可能对同一领域数据形成双写、迁移分叉和不同
授权规则。Admin/Web 是调用表面，不是稳定领域边界。

Info、Knowledge、Research 本身则有不同语言、数据生命周期、容量、故障和复用边界，
仍是有效的领域 App。

## 决策

- 保留 Info、Knowledge、Research 三个独立领域 App；
- 每个 App 只有一个规范 FastAPI Backend 和一个逻辑 PostgreSQL 数据库所有者；
- Admin 与 Web 两个 Next.js 前端可独立部署，但调用同一 Backend；
- Backend 内以 `interfaces/http/admin`、`web`、`internal` 表达入口差异；
- application 按用例组织，不按调用表面复制；
- 跨 App 继续通过版本化契约、服务身份和 Outbox 协作，禁止共享表；
- Next.js 可以承担浏览器同源 BFF/session 边界，但不成为领域数据所有者。

## 未选择的方案

- 不把三个领域 App 合并成一个 App 或一个数据库；
- 不继续让 Admin/Web Backend 各自拥有数据；
- 不建立一个所有 App 共用的“platform backend”。

## 结果

- App 的部署角色可多于一个，但代码和数据所有权只有一个；
- 旧 Web Backend 能力需迁入规范 Backend，旧仓在回滚窗后归档；
- 每个 App 只有一条 Alembic migration head；
- 两个前端必须分别和共同 Backend 做配对门禁。
