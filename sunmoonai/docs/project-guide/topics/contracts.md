# 契约

> 取证时点：2026-08-29 ｜ 相关规则见 [`../../dev-plan/constraints.md`](../../dev-plan/constraints.md)「契约」C1–C6

## 1. 三套契约：两跨 App，一同 App 共享

分类先说清，否则容易误以为 web-interaction 有一个跨四仓的运行时 provider：

| | 契约 |
| --- | --- |
| **跨 App** | artifact v1、retrieval v1 |
| **模板共享、各实例 App 内消费** | web-interaction v1 |

后者是同 App 内「后端 ↔ Web 前端」，模板发下去四份——这解释了为什么它
DTO / Port / 前端 zod 都齐全，却仍能在**每个实例里各自未接线**。


| 契约 | provider（schema 真源） | consumer（锁文件） | 传输 |
| --- | --- | --- | --- |
| **artifact v1** | `knowledge-app/contracts/artifact/v1/info-knowledge-artifact.schema.json` | `info-app/contracts/knowledge-provider-lock.json` | info → knowledge，HTTP 摄入 |
| **retrieval v1** | `knowledge-app/contracts/retrieval/v1/`（request / response / citation 三份 schema） | `investment-app/contracts/knowledge-retrieval-provider-lock.json` | investment → knowledge，HTTP 检索 |
| **web-interaction v1** | `tpl-app/contracts/web-interaction-v1.consumer-vectors.json` | 各 App 后端 DTO + 各 Web 前端 zod | **同 App 内**后端 ↔ Web 前端 |

**规律**：schema 真源放在**被调方**（provider）仓；锁文件放在**调用方**（consumer）仓。

web-interaction 是例外——它不跨仓，模板持共享测试向量（含 valid 与 invalid 两组），
各实例双端各自对齐。

## 2. 锁机制

consumer 仓**只放锁文件，不放 schema 副本**。锁文件 pin 三样东西：契约 major 版本、
schema 文件路径、schema 的 sha256。

升级的合法路径**只有一条**：

```
provider 改 schema → 双端（provider + consumer）测试都通过 → 才允许更新锁文件的 sha256
```

**「只改锁不跑测试」不是合法升级。**同理，在 consumer 仓生成或复制一份 schema
会产生第二真源，禁止。

破坏性变更 = 新 major + 双版本迁移窗口。

## 3. 双端怎么测

| 契约 | provider 侧 | consumer 侧 |
| --- | --- | --- |
| artifact v1 | knowledge 的摄入测试对 manifest digest | info 的分发辅助测试 |
| retrieval v1 | knowledge 的检索测试对 manifest digest | investment 设 `KNOWLEDGE_RETRIEVAL_CONTRACT_DIR` 后跑契约测试 |
| web-interaction v1 | 后端消费向量测试 | 前端 vitest，向量路径由 `WEB_INTERACTION_CONSUMER_VECTORS` 注入 |

**注意**：consumer 侧测试需要环境变量指向 provider 仓的契约目录，
所以**跨仓契约测试在单仓 CI 里不会自动跑**，必须显式提供路径。这是一个已知的松点。

## 4. DTO 的共同约束

所有契约 DTO 是 Pydantic 模型，`extra=forbid`——**未声明的字段一律拒收**。
前端侧对应为 zod schema。`contract_version` 写在 manifest 与 DTO 两处，须一致，由 §3 的测试保证。

## 5. citation 的 `source_href` 只有一个形状

**全平台统一为 `/api/web/v1/citations/{evidence_id}/source`**，相对路径，
由消费方在**自己的 origin** 下解析——knowledge 与 investment 各自都有这条路由。

同形的地方共七处，改一处必须七处一起改：

| 位置 | 角色 |
| --- | --- |
| `knowledge-app/contracts/retrieval/v1/citation.schema.json` | 契约真源 |
| `knowledge:application/dto/retrieval.py` `Citation` | provider 投影 |
| `knowledge:application/dto/interaction.py` `BrowserCitation` | 浏览器面 |
| `investment:domain/agent/knowledge.py` `Citation` | consumer 投影 |
| `investment:application/dto/pilot_runtime.py` `BrowserCitation` | 内部 pilot 面 |
| `investment:application/dto/interaction.py` `BrowserCitation` | 浏览器面 |
| `investment-web-frontend:contracts/interaction.ts` | 前端 zod |

**其中两处经事件存储首尾相接**：`tasks/pilot_agent_graph.py` 用
`domain/agent/knowledge.Citation` 写 citation 事件，`agent/pilot_service.py`
再用 `dto/pilot_runtime.BrowserCitation` 读回来。两者 pattern 不一致会让
`model_validate` 在运行时直接抛。

### 复核这七处仍然同形

```bash
# provider 侧：契约正则必须匹配真实路由
cd knowledge-app/knowledge-backend/app
uv run pytest tests/test_knowledge_retrieval.py -k resolves_to_a_real_route
# consumer 侧：两个经事件存储首尾相接的类必须同形
cd investment-app/investment-backend/app
uv run pytest tests/test_knowledge_retrieval_contract.py -k matches_investment_own
```

## 6. 契约定义齐全 ≠ 链路已通

web-interaction v1 在四个仓里都有完整的 DTO、Port 与前端 zod，
但**四个仓的默认适配器都是 `UnavailableWebInteractionAdapter`，返回 503**；
唯一的替代实现是 reference fixture，且生产环境禁止开启。

**判断某个契约面是否真的能用，看对应仓 `repos/*.md` 的「已知未实现」一节，
不要看契约文件是否齐全。**

## 7. 另有一批历史契约

`k8s/sunmoonai/docs/mooc-manus-v5/contracts/` 下存有 v5 时期的契约
（`research-agent-web` / `research-runtime` / `web-interaction` / `security`）。
它们**不在上述三套现行契约之列**，属历史归档；引用前先确认是否仍有效。

## 8. 跨 App 消息里放什么

共享 Outbox 目前 defined 未 wired（见总览 §9.2）。**第一个事件落地前先定下形状**，
否则最容易发生的事是把 markdown 正文直接塞进消息体：

- 事件只带**稳定 ID、契约版本、必要摘要**；
- 大对象走 **artifact 引用 + 内容哈希**，不进消息体；
- 消费方按引用去对象存储取，取不到就是取不到——**不要因此把正文塞回消息**。

理由与"主档只有一份"同源：消息体里的正文是第二份内容，且无版本、无生命周期。
