# 跨 App 契约

> 取证时点：2026-08-29 ｜ 决策来由见 [ADR-0003](../decisions/0003-sync-and-event-integration.md)

## 1. 三套契约

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

## 5. 一处契约与路由不匹配（读文档时最容易踩的坑）

三条相似路径其实是三个不同的东西：

| 路径 | 它是什么 |
| --- | --- |
| `^/api/citations/[0-9a-fA-F-]{36}/source$` | **契约 schema 里的正则约束**，服务间 retrieval 响应用 |
| `/citations/{evidence_id}/source` | knowledge-app 里**唯一真实存在**的路由，挂在 **web 前缀**下 |
| `^/api/web/v1/citations/...` | 浏览器面 DTO 的正则约束 |

即：契约里那个 `/api/citations/...` **在 provider 仓中没有对应的 HTTP 路由**。
消费方若照字面拼路径去 GET，会 **404**。

复核：
```bash
grep -rn 'citations/' knowledge-app/knowledge-backend/app/app/interfaces/
# 只会命中 web/interactions.py 一条
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
