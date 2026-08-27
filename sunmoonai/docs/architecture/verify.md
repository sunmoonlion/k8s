# 验证

> 取证时点：2026-08-27
>
> 本文档集的唯一质量指标是**对代码的保真度**，而保真度只有配上「何时验证过、怎么验的」
> 才有意义。**复核者不需要信任作者，跑命令即可。**

## 1. 本轮实际执行的验证

不是静态读码，是真跑。以下结果为 2026-08-27 在 `opus` 分支实测：

### 1.1 内核不变量（四仓全绿）

```bash
cd <repo>/<app>-app/<app>-backend/app && uv run --frozen pytest tests/test_kernel_invariants.py -q
```

| 仓 | 结果 |
| --- | --- |
| tpl-app | **5 passed** |
| info-app | **6 passed** |
| knowledge-app | **6 passed** |
| investment-app | **6 passed** |

### 1.2 完整测试套件（四仓全绿）

```bash
cd <repo>/<app>-app/<app>-backend/app && uv run --frozen pytest -q
```

| 仓 | 结果 |
| --- | --- |
| tpl-app | **43 passed, 2 skipped** |
| info-app | **96 passed, 2 skipped** |
| knowledge-app | **94 passed, 2 skipped** |
| investment-app | **132 passed, 2 skipped** |
| 合计 | **365 passed, 8 skipped** |

这些套件不需要活数据库即可跑通。

### 1.3 模板侧门禁

```bash
cd <repo>/tpl-app
python3 -m unittest discover -s k8s-deployment/tests   # 8 tests
python3 verify_template_release.py                     # formal_release: true
```

**已知环境坑**：`k8s-deployment/tests/test_deploy.py` 需要 **PyYAML**，
但 `k8s-deployment/` **没有任何依赖声明**（无 requirements.txt / pyproject.toml），
README 也未提及。裸跑会得到 `ModuleNotFoundError: No module named 'yaml'`。
装上 PyYAML 后 8 项全过。

## 2. 逐份文档的复核命令

| 文档 | 怎么复核 |
| --- | --- |
| [`repos/tpl-app.md`](repos/tpl-app.md) | `cat tpl-backend/app/tests/test_kernel_invariants.py`（5 项全文）；`sed -n '/async def get_web_interaction_port/,/return Unavailable/p' tpl-backend/app/app/application/services/web_interaction.py`（默认适配器选择）；`grep -rn uuid5 tpl-backend/app/app/`（应无结果） |
| [`repos/info-app.md`](repos/info-app.md) | `sed -n '/adapters: dict/,/}/p' info-backend/app/app/application/collectors/registry.py`（采集器表）；`grep -n 'search_backend' info-backend/app/core/config.py`（默认 disabled）；`grep -n 'target_app' info-backend/app/app/application/services/info_crawl_service.py \| grep 1177` |
| [`repos/knowledge-app.md`](repos/knowledge-app.md) | `sed -n '/terminal = /,/return last_doc/p' knowledge-backend/app/app/infrastructure/external/ragflow.py`（CANCEL 处理）；`sed -n '/requested_datasets = set/,/ForbiddenError("retrieval service relation/p' knowledge-backend/app/app/application/services/knowledge_retrieval_service.py`（三重授权） |
| [`repos/investment-app.md`](repos/investment-app.md) | `grep -rln RunBudget investment-backend/app/app investment-backend/app/tests`（应恰好 3 处）；`sed -n '/^RUN_STATUS_TRANSITIONS/,/^}/p' investment-backend/app/app/domain/agent/runtime.py`（状态机） |
| [`repos/k8s.md`](repos/k8s.md) | `awk '/^def apply\(/,/^def drift\(/' sunmoonai/app-platform/info-app/deployment/deploy.py`（apply 真实顺序）；`ls -1d sunmoonai/*/`（平台清单） |
| [`topics/contracts.md`](topics/contracts.md) | `grep -rn 'citations/' knowledge-app/knowledge-backend/app/app/interfaces/`（只应命中 web 一条） |
| [`topics/identity.md`](topics/identity.md) | `grep -n 'required_scopes=' tpl-app/tpl-backend/app/core/config.py`（admin/web 不对称） |
| [`topics/data.md`](topics/data.md) | 四仓 `ls alembic/versions/`；`grep -rn 'SqlOutbox' <app>-backend/app/app --include='*.py'`（应只命中再导出） |
| [`topics/release.md`](topics/release.md) | `grep -h '^version' */[a-z]*-backend/app/pyproject.toml`（应全为 2.0.0.dev0） |

## 3. 本轮复核过的高影响断言

| 断言 | 复核方式 | 结果 |
| --- | --- | --- |
| 四后端全部 `2.0.0.dev0`，且被测试强制 | `grep -h '^version' */*-backend/app/pyproject.toml`；读 `test_candidate_does_not_claim_the_formal_release` | **成立**，且与 `release.json` 的 `formal_release: true` 矛盾 |
| `RunBudget` 未在生产链接线 | `grep -rln RunBudget` | **成立**：仅定义处、非生产图 `first_m1_graph.py`、其测试三处 |
| apply 顺序中网络策略先于迁移 | 读三 App `deploy.py` 的 `apply()` | **成立**，三 App 一致 |
| RAGFlow `CANCEL` 被当作成功 | 读 `_wait_for_document_parse` | **成立**：`terminal = {"DONE","FAIL","CANCEL"}`，仅 `FAIL` 抛错 |
| 生产环境 web-interaction 必定 503 | 读 `get_web_interaction_port` + 生产禁 reference 的配置校验 | **成立** |
| ReferenceAdapter 的 ID 是硬编码常量而非 uuid5 生成 | `grep -rn uuid5 tpl-backend/app/app/` | **成立**：全仓无 `uuid5()` 调用 |
| 四仓 `<app>-backend/CLAUDE.md` 内容已过期 | 逐条核对其声称的文件是否存在 | **成立**，见 §5 |

## 4. 易腐值：本文档集不记，去这里查

| 我要查 | 去哪 |
| --- | --- |
| 某 App 当前镜像 digest / release_id | `k8s/sunmoonai/app-platform/<app>-app/deployment/bundle/release.json` |
| bundle 五文件 sha256 | 同上文件的 `sha256` 字段 |
| 某仓迁移 head | 该仓 `app/alembic/versions/` 中最新 revision |
| 契约 schema 的 sha256 | 各 consumer 仓的 `*-provider-lock.json`，或 provider 的 `contract-manifest.json` |
| 集群里实际跑的副本与镜像 | 活集群：`kubectl -n app-platform-dev get deploy -o wide` |

## 5. ⚠ 各组件目录下的 CLAUDE.md 已严重过期

**这些文件会被 Claude Code 自动注入**，优先级高于任何需要主动去读的文档，
因此它们的过期危害最大。逐条核对结果：

`<app>-web-frontend/CLAUDE.md`（55 行，四仓各一份）声称的：

| 声称 | 实际 |
| --- | --- |
| `app/api/auth/` 是 Next.js API Routes，承担 OIDC 回调与 session | **不存在**。OIDC 全在后端；前端唯一的 route 是 `app/healthz/route.ts` |
| `lib/request.ts`（axios 实例） | **不存在**。实际是 `lib/common/api-client.ts`；**axios 不是依赖** |
| `store/auth.ts`（Zustand auth store） | **不存在** |
| `middleware.ts` | **不存在**。Next 16 已改名 `proxy.ts` |

`<app>-backend/CLAUDE.md`（48 行，四仓各一份）声称的：

| 声称 | 实际 |
| --- | --- |
| `app/main.py` 是 FastAPI 入口 | `main.py` 只有 **5 行**，是向后兼容 shim；真入口 `app/bootstrap/api.py`（173 行） |
| 读 `app/interfaces/endpoints/` 确认路由 | 对实例部分成立，但**漏了模板面 `interfaces/http/`**；tpl-app 根本没有 `endpoints/` |
| 以 **k8s v5 权威文档 / v5 contracts** 为准 | v5 已被 Architecture v2 取代 |

复核：
```bash
cd <repo>/tpl-app/tpl-web-frontend/app
for p in app/api/auth lib/request.ts store/auth.ts middleware.ts proxy.ts; do
  [ -e "$p" ] && echo "存在: $p" || echo "不存在: $p"
done
grep -c axios package.json     # 0
wc -l ../../tpl-backend/app/app/main.py   # 5
```

## 6. 明确未核对的部分（不背书）

| 盲区 | 原因 |
| --- | --- |
| **集群运行态** | 本轮未连 KIND。namespace 是否已部署、Pod 是否 Ready、运行时门禁当前是否通过，均未验证 |
| **NetworkPolicy 是否真被执行** | KIND 默认 kindnet 不 enforce；需另起 Calico 集群跑 `verify_r3_network_policy_calico.sh` |
| **前端页面实际渲染** | 只读源码与配置，未跑 Playwright E2E |
| **远程 C1 / production 集群** | 三 App 的 `production.conf` 均 `PROFILE_ENABLED=false`，无法从本地取证 |
| **需要活数据库的用例** | 完整套件在无 DB 环境下通过，说明这类用例被 skip 或以 fake 运行；未在有 DB 环境复跑 |
| **双远端 SHA 对齐** | 无远端网络访问，未比对 GitHub / Gitee |
| **八个前端的逐文件深读** | 约 570 个 ts/tsx，本轮核到结构、入口、契约与关键配置层，未逐文件读 |

## 7. 怎么重做一次验证

1. **按仓切分**，五个单元互不依赖，可全并行。
2. 每个单元**只读代码**，**禁止读本文档集**——否则产出会退化为对旧文本的改写，
   无法保证与代码一致。这是本方法最要紧的一条。
3. 每条断言必须给出**位置或可执行命令**；给不出的一律删除，不靠推测补全。
4. **实际跑测试**，不满足于静态读码。
5. 强制产出「已知未实现」一节，主动找占位、未接线、TODO、空实现、被 flag 关掉的东西。
6. **产出方不自验**：高影响断言由另一方复核。
