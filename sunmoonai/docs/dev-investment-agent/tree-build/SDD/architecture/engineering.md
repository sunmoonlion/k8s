# 工程落点与共同约束

## 仓与技术栈

| 模块 | 仓 | 技术栈 | 新旧 |
| --- | --- | --- | --- |
| 工作台后端 | `investment-app/investment-backend` | Python、FastAPI、SQLAlchemy、PostgreSQL、Outbox；app-server 客户端用 `websockets` | 改造 |
| 网页 | `investment-app/investment-web-frontend` | Next.js 16、同源 `/api/`、事件流 | 改造 |
| 沙箱池 | `k8s` 仓新部署单元 + 一个小镜像（Codex CLI 钉版 + 出站桥） | 容器；出站桥 Python 或 Node，与代理共用协议实现 | 新 |
| 会合点 | 新仓 `relay`（或先放 `k8s/platforms/`，`D16` 待定） | Python asyncio + websockets 起步；延迟不达标再换 Go | 新 |
| 本地代理 | `runtime` 仓 | TypeScript/Node（Codex CLI 是 npm 包，同一运行时）；随包带钉版 Codex；签名分发 | 新（仓已有，内容换） |
| 知识服务 | `knowledge-app` | 现状 + MCP 服务端 + 用户资料入库 | 改造 |
| 评测 | 先落 `investment-backend` 的 `eval/` | Python | 新 |

**退役仓**：`desktop-app`（本地 worktree、`~/master` 副本、`repos.conf` 条目一并删；GitHub 仓由所有者删）。

## 共同约束

- 状态机只有一套，场景差异只体现在 Profile 与专家包（`P0`）；
- 同一事实只有一个权威写入面（`P1`）；Codex thread 不是真源；
- 跨进程仍须正确的不变量由 PostgreSQL 承担，不放在沙箱或代理进程里；
- 执行引擎租用不自建，只经 app-server 与 exec-server 的公开协议（`C-A4`、`C-C7`）；
- 接口契约单一真源：网页与代理都从工作台的 OpenAPI 生成客户端；
- 版本成对：Codex 版（app-server 与 exec-server 同版）、会合点协议版、代理版随发布清单钉（`C-R8`）；不匹配拒绝连接（`AT-28`）；
- 领域概念不进 Port 签名（`C-A5`）。

## 第一期切法

| 项 | 第一期 | 之后 |
| --- | --- | --- |
| 委托 | 单委托、串行、只读为主（写只落项目目录） | 并行、写范围扩大 |
| 沙箱池 | 一个演示用户的常驻 pod | 按需拉起、PVC、配额 |
| 会合点 | 单实例、单站点 | 多实例、多站点分片 |
| 本地代理 | Linux、macOS；Windows 随 spike | Windows 全量、信创 |
| 用户资料 | 显式上传 | 目录同步 |
| 评测 | 问数二十题 + 勾稽首批 | 持续沉淀 |
| 离线模式 | 无 | 第二期（`D13`） |
| 计费 | 只记账 | 收费（`D12`） |

## 第一段的探针（动代码前）

按顺序，每个都有可证伪的判据，结果落 `runtime/probe/`：

1. **本地上限**：~~exec-server 侧配置能否拒绝 harness 的要求~~ 已验：不能，代理自己挡（`security.md`）；
2. **BYOK**：~~`OPENAI_API_KEY` 与一个国产厂商 key~~ 已验：Kimi K3 经 `model_provider` 直连，远端环境、`apply_patch`、审批全过（`REPORT-2026-09-23-byok-kimi.md`）；OpenAI key 路径待有 key 再补；
3. **会合点透传**：~~两端各出站、中间一个哑透传~~ 回环已验成立（`REPORT-2026-09-23-relay-passthrough.md`）；每 turn 约 45 个串行来回，公网数字要两台机器测（luna）；
4. **断线恢复**：~~25 秒内重连接回原会话；超窗行为~~ 已验（`REPORT-2026-09-23-reconnect.md`）：窗内无损，超窗或代理重启丢会话但自动重连，新 Attempt 可接续；
5. **Windows exec-server**（luna，本地）。

任一失败都改设计，不改判据。
