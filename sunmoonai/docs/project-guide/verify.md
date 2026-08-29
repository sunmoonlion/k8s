# 验证

> 取证时点：2026-08-29
>
> 本文档集的唯一质量指标是**对代码的保真度**，而保真度只有配上「何时验证过、怎么验的」
> 才有意义。**复核者不需要信任作者，跑命令即可。**

## 1. 明确未核对的部分（不背书）

| 盲区 | 原因 |
| --- | --- |
| **集群运行态** | 本轮未连 KIND。namespace 是否已部署、Pod 是否 Ready、运行时门禁当前是否通过，均未验证 |
| **NetworkPolicy 是否真被执行** | KIND 默认 kindnet 不 enforce；需另起 Calico 集群跑 `verify_r3_network_policy_calico.sh` |
| **前端页面实际渲染** | 只读源码与配置，未跑 Playwright E2E |
| **远程 C1 / production 集群** | 三 App 的 `production.conf` 均 `PROFILE_ENABLED=false`，无法从本地取证 |
| **需要活数据库的用例** | 完整套件在无 DB 环境下通过，说明这类用例被 skip 或以 fake 运行；未在有 DB 环境复跑 |
| **双远端 SHA 对齐** | 无远端网络访问，未比对 GitHub / Gitee |
| **八个前端的逐文件深读** | 约 570 个 ts/tsx，本轮核到结构、入口、契约与关键配置层，未逐文件读 |

## 2. 逐份文档的复核命令

| 文档 | 怎么复核 |
| --- | --- |
| [`repos/tpl-app.md`](repos/tpl-app.md) | `cat tpl-backend/app/tests/test_kernel_invariants.py`（5 项全文）；`sed -n '/async def get_web_interaction_port/,/return Unavailable/p' tpl-backend/app/app/application/services/web_interaction.py`（默认适配器选择）；`grep -rn uuid5 tpl-backend/app/app/`（应无结果） |
| [`repos/info-app.md`](repos/info-app.md) | `sed -n '/adapters: dict/,/}/p' info-backend/app/app/application/collectors/registry.py`（采集器表）；`grep -n 'search_backend' info-backend/app/core/config.py`（默认 disabled）；`grep -n 'target_app' info-backend/app/app/application/services/info_crawl_service.py \| grep 1177` |
| [`repos/knowledge-app.md`](repos/knowledge-app.md) | `sed -n '/terminal = /,/return last_doc/p' knowledge-backend/app/app/infrastructure/external/ragflow.py`（CANCEL 处理）；`sed -n '/requested_datasets = set/,/ForbiddenError("retrieval service relation/p' knowledge-backend/app/app/application/services/knowledge_retrieval_service.py`（三重授权） |
| [`repos/investment-app.md`](repos/investment-app.md) | `grep -rln RunBudget investment-backend/app/app investment-backend/app/tests`（应恰好 3 处）；`sed -n '/^RUN_STATUS_TRANSITIONS/,/^}/p' investment-backend/app/app/domain/agent/runtime.py`（状态机） |
| [`repos/k8s.md`](repos/k8s.md) | `awk '/^def apply\(/,/^def drift\(/' sunmoonai/app-platform/info-app/deployment/deploy.py`（apply 真实顺序）；`ls -1d sunmoonai/*/`（平台清单） |
| [`topics/contracts.md`](topics/contracts.md) | `uv run pytest tests/test_knowledge_retrieval.py -k resolves_to_a_real_route`（契约正则须匹配真实路由） |
| [`topics/identity.md`](topics/identity.md) | `grep -n 'required_scopes=' tpl-app/tpl-backend/app/core/config.py`（admin/web 不对称） |
| [`topics/data.md`](topics/data.md) | 四仓 `ls alembic/versions/`；`grep -rn 'SqlOutbox' <app>-backend/app/app --include='*.py'`（应只命中再导出） |
| [`topics/release.md`](topics/release.md) | `grep -h '^version' */[a-z]*-backend/app/pyproject.toml`（应全为 2.0.0） |

## 3. 易腐值：本文档集不记，去这里查

| 我要查 | 去哪 |
| --- | --- |
| 某 App 当前镜像 digest / release_id | `k8s/sunmoonai/app-platform/<app>-app/deployment/bundle/release.json` |
| bundle 五文件 sha256 | 同上文件的 `sha256` 字段 |
| 某仓迁移 head | 该仓 `app/alembic/versions/` 中最新 revision |
| 契约 schema 的 sha256 | 各 consumer 仓的 `*-provider-lock.json`，或 provider 的 `contract-manifest.json` |
| 集群里实际跑的副本与镜像 | 活集群：`kubectl -n app-platform-dev get deploy -o wide` |

## 4. 怎么重做一次验证

1. **按仓切分**，五个单元互不依赖，可全并行。
2. 每个单元**只读代码**，**禁止读本文档集**——否则产出会退化为对旧文本的改写，
   无法保证与代码一致。这是本方法最要紧的一条。
3. 每条断言必须给出**位置或可执行命令**；给不出的一律删除，不靠推测补全。
4. **实际跑测试**，不满足于静态读码。
5. 强制产出「已知未实现」一节，主动找占位、未接线、TODO、空实现、被 flag 关掉的东西。
6. **产出方不自验**：高影响断言由另一方复核。

## 5. 休眠能力的声明与校验

四个后端各有 `app/tests/test_dormant_capabilities.py`，把"代码在、没接线"的能力
声明成**可执行判据**。每条两个方向都能失败：

| 检查 | 失败的含义 | 该做什么 |
| --- | --- | --- |
| `anchor_exists` | 判据锚点没了（改名/删除），**判据已空转** | 先把判据改到新位置 |
| `still_dormant` | 能力已接线，**声明过期** | 删该条声明，并同步 `repos/*.md` |

```bash
cd <repo>/<app>-app/<app>-backend/app && uv run pytest tests/test_dormant_capabilities.py -q
```

**判据必须查真实状态，不能做文本匹配。**这一点是踩出来的：`/api/internal/v1`
那条最初写成 `"internal" not in routes.py`，而前缀定义在被引入的 endpoints 模块里，
`routes.py` 里根本没有这个词——判据永远通过。改成查 `create_app()` 的真实路由表后，
立刻发现 **investment 实际有 5 条 internal 路由**，那条声明本身就是错的。

**机制的边界**：它保证已声明的条目不变陈旧，**发现不了新出现的休眠能力**——
那要判断"这段代码本该接线却没接"，不可机械判定。新增时手工加一条。
