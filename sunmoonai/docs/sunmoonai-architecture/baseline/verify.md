# 验证

> 最后更新：2026-08-15
> 本投影的唯一质量指标是对代码的保真度，而保真度只有配上「何时验证过」才有意义。

## 1. 验证时点总表

| 文件 | 最后更新 | 验证时点 | 取证方式 |
| --- | --- | --- | --- |
| [`map.md`](map.md) | 2026-08-15 | 2026-08-15 | 目录 listing + `deploy-sunmoonai-all.conf` 逐行读 |
| [`repos/tpl-app.md`](repos/tpl-app.md) | 2026-08-15 | 2026-08-15 | 全仓读码，逐条取 `file:line` |
| [`repos/info-app.md`](repos/info-app.md) | 2026-08-15 | 2026-08-15 | 同上 |
| [`repos/knowledge-app.md`](repos/knowledge-app.md) | 2026-08-15 | 2026-08-15 | 同上 |
| [`repos/investment-app.md`](repos/investment-app.md) | 2026-08-15 | 2026-08-15 | 同上，另复核 `RunBudget` 引用点 |
| [`repos/k8s.md`](repos/k8s.md) | 2026-08-15 | 2026-08-15 | 清单与脚本逐行读，`rg '^kind:'` 核资源 |
| [`shared/contracts.md`](shared/contracts.md) | 2026-08-15 | 2026-08-15 | 跨仓综合，另复核 citation 路由 |
| [`shared/identity.md`](shared/identity.md) | 2026-08-15 | 2026-08-15 | 跨仓综合 |
| [`shared/data.md`](shared/data.md) | 2026-08-15 | 2026-08-15 | 跨仓综合，另复核 outbox 调用点 |
| [`shared/release.md`](shared/release.md) | 2026-08-15 | 2026-08-15 | k8s 仓脚本与 release.json |
| [`shared/conventions.md`](shared/conventions.md) | 2026-08-15 | 2026-08-15 | 四仓对比 |

本轮验证时五仓均在 `opus` 分支。

## 2. 易腐值真源速查

本目录正文不写下列任何具体值。要查当前值，去这里：

| 我要查 | 去哪 | 命令 |
| --- | --- | --- |
| 某 App 当前镜像 digest | `k8s/sunmoonai/app-platform/<app>-app/deployment/bundle/release.json` 的 `images` | `rg -A4 '"images"' <release.json>` |
| 某 App 当前 release_id | 同上文件的 `release_id` | — |
| bundle 五文件的 sha256 | 同上文件的 `sha256` | — |
| 某仓迁移 head | 该仓 `alembic/versions/` 中最新 revision 文件 | `ls -1 <repo>/app/alembic/versions/ \| tail -1` |
| 契约 schema 的 digest | 各 `contracts/*/contract-manifest.json` | — |
| 集群中实际跑的副本与镜像 | 活集群 | `kubectl -n app-platform-dev get deploy -o wide` |
| 五仓当前分支与提交 | 各仓 git | `for d in tpl info knowledge investment; do git -C ~/$d-app branch --show-current; done` |

## 3. 怎么重做一次验证

本轮采用的方法，可原样重跑：

1. **按仓切分**，五个单元互不依赖，全并行。
2. 每个单元只读**代码**，**禁止读本文档集**。否则产出会退化为对旧文本的改写，
   无法保证与代码一致。这是本方法最要紧的一条。
3. 每条断言必须给出 `file:line` 或可执行命令；给不出的一律删除，不靠推测补全。
4. 强制产出「已知未实现」一节，主动找占位、未接线、TODO、空实现、被 flag 关掉的东西。
5. **产出方不自验**。高影响断言由另一方复核——本轮复核了三条，其中一条推翻了此前文档中
   关于 `RunBudget` 生效范围的说法（见 §4）。

四类结论：符合 / 不符 / 已过期 / 无法定位证据。最后一类按第 3 条处理。

## 4. 本轮复核过的高影响断言

| 断言 | 复核命令 | 结果 |
| --- | --- | --- |
| `RunBudget` 未在 investment-app 的两条生产链生效 | `rg -l RunBudget investment-app/investment-backend/app/app` | 成立：仅命中 `domain/agent/runtime.py`（定义）与 `infrastructure/graph/first_m1_graph.py`（非生产图） |
| 四仓共享 outbox 均未接线 | `rg 'SqlOutbox\|\.enqueue\(\|claim_batch' <repo>/app/app --glob '!**/tests/**'` | 成立：四仓均只命中 `__init__.py` 再导出 |
| knowledge-app 无 `/api/citations/...` 路由 | `rg 'citations/' knowledge-app/knowledge-backend/app/app/interfaces` | 成立：唯一路由 `web/interactions.py:128` 挂在 web 前缀下，与契约 schema 的正则不匹配 |

## 5. 已知的验证盲区

| 盲区 | 原因 |
| --- | --- |
| 集群运行态与 bundle 是否一致 | 本轮为静态读码，未连集群；需跑 `deploy.py drift` |
| NetworkPolicy 是否真被执行 | KIND 默认 kindnet 不 enforce，需 `verify_r3_network_policy_calico.sh` 另起 Calico 集群 |
| 前端页面的实际渲染结果 | 本轮只读源码，未跑 Playwright |
| 远程 C1 集群的实际状态 | 三 App 的 `production.conf` 均 `PROFILE_ENABLED=false`，无法从本地取证 |
