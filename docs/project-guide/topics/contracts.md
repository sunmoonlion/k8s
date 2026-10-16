# 契约

> 最后更新：2026-10-16 ｜ 按代码现状重写 ｜ 相关规则见 [`constraints.md`](../../dev-investment-agent/tree-build/rules/constraints.md)「契约」`C-C1`–`C-C11`

## 1. 有哪些

| 契约 | 提供方（真源） | 调用方 | 现状 |
| --- | --- | --- | --- |
| **artifact v1**：knowfeed 向 knowbase 登记一个新版本 | `knowbase-app/contracts/artifact/v1/` | knowfeed（锁 `knowfeed-app/contracts/knowbase-provider-lock.json`），服务身份 `knowbase:ingest` | 在用 |
| **retrieval v1**：检索与引用 | `knowbase-app/contracts/retrieval/v1/`（request、response、citation） | investment（锁 `investment-app/contracts/knowbase-retrieval-provider-lock.json`），服务身份 `knowbase:retrieve` | 提供方在；**investment 后端现在没有调用它的代码，只剩锁文件**——investment 取数据走的是沙箱里的 MCP（下一行） |
| **knowbase MCP**：`/api/mcp/knowledge`（服务名 `sunmoon_knowbase`） | knowbase `interfaces/mcp/knowbase_mcp.py` | 沙箱里的 Codex，带 investment 签发的短期令牌 | 在用；工作台对用户开放前改为默认不接（`C-L2`） |
| **knowbot-manifest v1**：分身清单外层 | `knowmart-app/contracts/knowbot/v1/`（由 knowmart 后端模型生成） | knowlab（交付，服务身份 `knowmart:deliver`；锁 `knowlab-app/contracts/knowmart-knowbot-manifest-lock.json`）、运行方（取清单，`knowmart:summon`；investment 锁 `investment-app/contracts/knowmart-knowbot-manifest-lock.json`） | 已写，未部署（[分身](knowbot.md)） |
| **knowbot-test-run v1**：运行方跑测试 | `knowlab-app/contracts/knowbot-test-run/v1/`（由 knowlab 后端模型生成） | 运行方实现，knowlab 调用（`<运行方>:testrun`） | knowlab 端已写，未部署；运行方（investment）方案待所有者定（[0027](../../dev-investment-agent/tree-build/SDD/modules/0027-knowbot-first-path.md) §3.4） |
| **工作台 MCP**：`/api/mcp/workbench` | investment `interfaces/mcp/workbench_mcp.py` | 沙箱里的 Codex（读本项目别的对话与底稿） | 在用 |
| **会合点协议**：本地代理、沙箱、工作台管理者的握手与透传 | 会合点源码 `k8s/infrastructure/applications/component-images/relay/`（`service-v1.md`、`local-permission-v1.md/.json`） | 本地代理（锁 `runtime/agent/contracts/relay-permissions.lock.json`）、沙箱、investment | 在用；协议字段（如 `role=agent`）不随产品改名 |
| **web-interaction v1**：同一个应用内后端 ↔ 网页端 | `tpl-app/contracts/web-interaction-v1.consumer-vectors.json`（共享测试向量） | 各应用后端 DTO 与网页端 zod | 定义齐全，但各实例默认适配器是 `UnavailableWebInteractionAdapter`（返回 503），**没接线** |

判断一个契约面能不能用，看上表「现状」与对应的 [`repos/`](../repos/) 文件，**不要看契约文件是否齐全**。

## 2. 锁怎么用

schema 真源放在**提供方**仓，调用方**只放锁文件、不放 schema 副本**。锁 pin 三样：契约 major 版本、schema 文件路径、schema 的 sha256（`C-C3`）。

升级只有一条路：提供方改 schema → 两端测试都过 → 才更新锁里的 sha256（`C-C4`）。「只改锁不跑测试」不算升级；在调用方生成或复制一份 schema 是第二真源，禁止。破坏性变更 = 新 major + 两版并存的迁移窗口（`C-C10`）。

调用方的测试要用环境变量指向提供方的契约目录，所以**跨仓契约测试在单仓 CI 里不会自动跑**，要显式给路径。

## 3. DTO 与引用

- 所有契约 DTO 是 Pydantic 模型，`extra=forbid`：未声明的字段一律拒收（`C-C5`）；前端对应 zod。`contract_version` 写在 manifest 与 DTO 两处，须一致。
- 引用的 `source_href` 全平台只有一个形状：`/api/web/v1/citations/{evidence_id}/source`，相对路径，由各自的 origin 解析（`C-C6`）。同形的地方现在有五处，改一处要一起改：`knowbase-app/contracts/retrieval/v1/citation.schema.json`（真源）、knowbase `application/dto/retrieval.py`、`application/dto/interaction.py`、investment `application/dto/interaction.py`、`investment-web-frontend/app/contracts/interaction.ts`。复核：knowbase `tests/test_knowledge_retrieval.py`、investment `tests/test_interaction_contract.py`。

## 4. 跨应用消息里放什么

- 事件只带**稳定标识、契约版本、必要摘要**；大对象走**引用 + 内容哈希**，不进消息体（`C-C11`）。
- artifact v1 只接受一个不可变、带版本的 `s3://` 对象；knowbase 用自己的只读身份去取，核存储版本、大小、类型与 SHA-256 后才进 RAGFlow，从不回调 knowfeed 的库。
- 投递走 Outbox / Inbox，消费方幂等、有死信、可重放、周期对账（`C-C2`）；每个跨应用集成写明超时、重试、幂等键、到上限后去哪、怎么对账（`C-C9`）。

## 5. 历史契约

旧 v5 契约（`research-agent-web`、`research-runtime`、`security` 等）已退出工作树，不在现行契约之列；原文按 [v5 历史索引](v5-history.md) 的固定 Git 版本查询。
