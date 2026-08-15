# 跨 App 契约

> 最后更新：2026-08-15 ｜ 验证时点：2026-08-15
> 仓内细节见各 [`../repos/`](../repos/) 的 §6。

## 1. 现有三套契约

| 契约 | provider（schema 真源） | consumer（锁文件） | 传输 |
| --- | --- | --- | --- |
| artifact v1 | `knowledge-app/contracts/artifact/v1/info-knowledge-artifact.schema.json` | `info-app/contracts/knowledge-provider-lock.json` | info → knowledge HTTP ingest |
| retrieval v1 | `knowledge-app/contracts/retrieval/v1/`（请求 / 响应 / citation 三份 schema） | `investment-app/contracts/knowledge-retrieval-provider-lock.json` | investment → knowledge HTTP retrieve |
| web-interaction v1 | `tpl-app/contracts/web-interaction-v1.consumer-vectors.json` | 各 App 后端 DTO + 各 Web 前端 Zod | 同 App 内后端 ↔ Web 前端 |

**规律**：schema 真源放在**被调方**（provider）仓；锁文件放在**调用方**（consumer）仓。
web-interaction 是例外——它不跨仓，模板仓持共享测试向量，各实例双端各自对齐。

## 2. 谁消费谁，写在 manifest 里

`knowledge-app/contracts/retrieval/v1/contract-manifest.json:5-6` 显式列出消费方：
`service_consumers: ["investment-app"]`、`browser_consumers: ["investment-web-frontend"]`。
改这套契约前先看这一行，它就是影响面清单。

artifact 契约的 producer 记在 `knowledge-app/contracts/README.md:12-13`（即 info-app）。

## 3. 双端对齐怎么测

| 契约 | provider 侧 | consumer 侧 |
| --- | --- | --- |
| retrieval v1 | `knowledge-app` DTO 对 manifest digest：`tests/test_knowledge_retrieval.py:63-68` | `investment-app` 对锁文件：`KNOWLEDGE_RETRIEVAL_CONTRACT_DIR=... uv run pytest tests/test_knowledge_retrieval_contract.py -q`（`:30-37`） |
| artifact v1 | `knowledge-app/tests/test_knowledge_ingestion.py:115-117` | `info-app/tests/test_distribution_helpers.py:110-157` |
| web-interaction v1 | 后端 `tests/test_interaction_consumer_vectors.py:26-27` | 前端 `interaction-consumer-vectors.test.ts:39`，向量路径由 `WEB_INTERACTION_CONSUMER_VECTORS` 注入 |

consumer 侧测试需要环境变量指向 provider 仓的契约目录，因此**跨仓契约测试在单仓 CI 里不会自动跑**，
需显式提供路径。

## 4. DTO 的共同约束

所有契约 DTO 为 Pydantic 模型，`extra=forbid`（例 `knowledge-app/app/app/application/dto/retrieval.py:39-69`），
未声明字段一律拒收。前端侧对应为 Zod schema（例 `tpl-app/tpl-web-frontend/app/contracts/interaction.ts:15-31`）。

`contract_version` / `major` 版本号写在 manifest 与 DTO 两处，两处须一致，由 §3 的测试保证。

## 5. Citation 的 `source_href`：契约与路由不匹配

这是一处容易读错的地方，三个相似路径实际是不同的东西：

| 路径 | 它是什么 | 位置 |
| --- | --- | --- |
| `^/api/citations/[0-9a-fA-F-]{36}/source$` | **契约 schema 里的正则约束**，服务间 retrieval 响应用 | `knowledge-app/contracts/retrieval/v1/citation.schema.json:31-34`；DTO `dto/retrieval.py:124-127` |
| `/citations/{evidence_id}/source` | **knowledge-app 里唯一真实存在的路由**，挂在 web 路由前缀下 | `knowledge-app/.../interfaces/http/web/interactions.py:128` |
| `^/api/web/v1/citations/...` | 浏览器面 DTO 的正则约束 | `knowledge-app/.../application/dto/interaction.py:32-42` |

即：契约里那个 `/api/citations/...` **在 provider 仓中没有对应的 HTTP 路由**
（验证：`rg 'citations/' knowledge-app/knowledge-backend/app/app/interfaces` 只命中 web 那一条）。
消费方若照字面拼路径去 GET，会 404。

## 6. 未接线的契约面

web-interaction v1 在四个仓里都有完整的 DTO、Port 与前端 Zod，但**四个仓的默认适配器都是
`UnavailableWebInteractionAdapter`，返回 503**（各仓 `application/ports/web_interaction.py`
的 `get_web_interaction_port`）。唯一的替代实现是 reference fixture，且生产环境禁止开启。

因此：**契约定义齐全 ≠ 链路已通**。判断某个契约面是否真的能用，看该仓 `repos/*.md` §8。
