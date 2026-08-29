# 已知缺口

> 最后更新：2026-08-29
>
> 从五仓代码投影中查出、**发现但未处置**的八项。原先埋在
> [`../project-guide/history.md`](../project-guide/history.md)（那是归档，写完即冻结），
> 移到这里因为它们是活的待办。
>
> 按 [`../project-guide/request-lifecycle.md`](../project-guide/request-lifecycle.md) R6：
> 每条要么立请求，要么写一条 ADR 声明"已知并接受"。**当前状态：全部待定。**

编号 O 系列，与 [`README.md`](README.md)「下一步」的 U 系列（智能体设计未决）不同：
U 是"还没想清楚"，O 是"已经查实、等着处理"。

| # | 事项 | 出处 | 性质 |
| --- | --- | --- | --- |
| ~~O1~~ | ~~代码层 `2.0.0.dev0` 与部署层 `formal_release: true` 矛盾~~ | [总览](../project-guide/overall-architecture.md) §9.1 | **已了结 2026-08-29**，见下 |
| ~~O2~~ | ~~RAGFlow `CANCEL` 被当作成功，被取消的摄入标记为 succeeded~~ | [`repos/knowledge-app.md`](../project-guide/repos/knowledge-app.md) §7 | **已修复 2026-08-29**，见下 |
| O3 | `RunBudget` 生产未接线，`budget_exceeded` 状态不可达 | [`repos/investment-app.md`](../project-guide/repos/investment-app.md) §4.5 | 已设计未接线 |
| O4 | 共享 Outbox/Inbox 四仓零业务调用 | [总览](../project-guide/overall-architecture.md) §9.2 | 模板有意留白，倾向"声明接受" |
| O5 | 四仓均无 `beat_schedule`，Scheduler 空转 | [总览](../project-guide/overall-architecture.md) §9.2 | 同上 |
| O6 | 契约 `source_href` 与真实路由不匹配，照字面 GET 会 404 | [`topics/contracts.md`](../project-guide/topics/contracts.md) §5 | 契约缺陷 |
| O7 | REQ-009 的"休眠能力声明+校验"机制未落地 | [来历记录](../project-guide/history.md) §3.3 | 机制缺口 |
| O8 | `docs/` 下并存的历史目录尚未清理 | [`README.md`](../project-guide/README.md) §本集之外 | 见该节 |
| O9 | Harbor 上 `:2.0.0` 别名是否物理存在未核实 | O1 了结记录 | 需在能访问 Harbor 的机器上确认 |
| O10 | 构建脚本默认 tag 与发布口径脱节：`build-push-app-images.conf` 默认 `TAG=1.0.0`，与 manifest `overwrite_v1_1_0_0: false` 的 v1 保护位相撞；且该脚本组件名仍是 v1 的 `admin-backend`/`web-backend`（目录已随 ADR-0007 消失），当前必然失败 | `k8s:sunmoonai/app-platform/scripts/` | 现为哑火状态；修好脚本会立刻兑现风险 |

## O1 了结记录（2026-08-29）

**结论：机制无误，是一条没收尾的护栏。**

发布采用 `exact-digest-alias`：不重建镜像，给已过 R7 门禁的 digest 打 `2.0.0`
别名。`mybuild/Dockerfile` 逐字 `COPY app/`、无版本注入，所以 2026-08-13 那次
构建忠实带入了当时源码里的 `2.0.0.dev0`。而
`test_candidate_does_not_claim_the_formal_release` 是 2026-08-01 重构期的护栏，
发布后无人回头解除。它从未阻碍发布——Dockerfile 只跑 `ruff` + `pyright`，
**不跑 pytest**。

制品层本来就是对齐的：R7 清单 12 个镜像记为 `:2.0.0`，其 digest 与三个部署
bundle **9/9 逐字一致**。

**处置：**

1. 四后端 `pyproject.toml` + `uv.lock`、八前端 `package.json` → `2.0.0`
2. 护栏反向并改名为 `test_package_version_matches_the_formal_release`，
   新增 `uv.lock` 同步断言（不同步则 `uv sync --frozen` 会在构建时失败）
   与"版本只能来自 `importlib.metadata`、不得硬写"的断言
3. **不重建镜像**——正在跑的 digest 经过完整 R7 验证，不为一个字符串作废。
   当前运行中的镜像内部仍报 `2.0.0.dev0`，下次实质发版时自然带上

**验证：**365 passed / 8 skipped（与改动前基线一致）；ruff + pyright 全绿；
三条新断言逐条反向验证过能真失败（`uv run --no-sync`，否则 uv 会自动改回
`uv.lock` 使反向验证失效）。

**遗留两条，已另立：**

- **O9**：Harbor 上 `:2.0.0` 别名是否物理存在未核实。
  `build_r7_release_manifest.py` 的 `tagged_image()` 只拼字符串写入清单，
  仓库内无任何脚本执行 `docker tag` 或等价推送。需在能访问 Harbor 的机器上确认；
  若缺失，补打别名即可，digest 不变，不影响运行中的负载
- **O10**：构建脚本的默认 tag 与发布口径脱节（详见下表）

## O2 了结记录（2026-08-29）

**影响比原描述更大。**取证链：

```
ragflow.py       terminal = {DONE, FAIL, CANCEL}，只有 FAIL 抛错
      ↓          CANCEL 正常 return
knowledge_ingestion_service.py  complete_ragflow_ingestion()
      ↓
  KnowledgeDocumentVersion.status = "indexed"，indexed_at = now
  job.status = "succeeded"，last_error = None
```

两处后果：

1. **被取消的文档进入检索候选集**——`knowledge_retrieval_service.py`
   的 `_eligible_versions` 正是按 `status == "indexed"` 过滤。内容残缺却照常
   参与检索，下游（investment-app 走 retrieval 契约）完全无感：不报错，
   只是答案变差
2. **连补救入口都没有**——`retry_ingestion_job` 明确拒绝 `succeeded`
   （`succeeded ingestion job cannot be retried`），只能人工改库

**顺带查出两条原描述没有的：**

- **`progress >= 1.0` 是独立的成功条件**，与 `run` 并列。读 RAGFlow
  `api/db/services/document_service.py`：`progress = 1` 与 `run = DONE`
  在同一次更新里写入，progress 不会先于 run 到 1——所以这条只有坏处
- **`run` 在 RAGFlow 库里是数字**（`common/constants.py` 的 `TaskStatus`：
  `2=CANCEL 3=DONE 4=FAIL`），HTTP 列表端点经 `map_doc_keys()` 映射为文本
  才返回。本仓只认文本，一旦 RAGFlow 版本改变映射行为，**判定会静默失效**
  ——所有取值都落不进终态，只会一路轮询到超时

**处置：**

1. 终态逐值判定：`DONE` 返回、`FAIL` 抛 `RAGFlowParseError`、
   `CANCEL` 抛新增的 `RAGFlowParseCancelledError`
2. `RAGFlowParseCancelledError` 继承 `RAGFlowParseError`，因此沿用
   `ragflow_parse_failed` 这个**可重试**状态（它不在 `RETRY_BLOCKED_STATUSES`
   里）；`error_type` 单独记为 `ragflow_parse_cancelled` 以便区分排查方向
3. 删掉 `progress >= 1.0` 这条独立成功条件
4. 数字与文本两种 `run` 取值都接受

**验证：**新增 5 个测试；其中 3 个在旧实现下逐条确认会失败。
四仓 370 passed / 8 skipped；`ruff format --check app core`（Dockerfile 的实际
检查范围）四仓全净；pyright 0 errors。

**过程中的一个自查：**`test_progress_alone_does_not_signal_completion` 初版用
`timeout_seconds=0`，导致轮询循环一次都不进，新旧实现都走超时分支——**测试是
空转的**。改为 `timeout_seconds=1` 后才真正区分出新旧行为。

## 与智能体计划的交叉

**O3 就是 [`README.md`](README.md) 下一步表里的 U3。**同一件事的两面：
O3 是"投资仓已经有 `RunBudget` 设计但没接线"，U3 是"四本账要落 PG 的表结构未定"。
做 U3 时直接把 O3 一并了结，不要另起一套预算表。

其余七项与智能体架构无关，可独立处理。

## 优先级判断

**O6 是剩下的真缺陷**（O2 已修复）。

- **O6** 契约缺陷：`source_href` 照字面 GET 会 404，任何按契约文档实现的 consumer 都会踩

~~O1~~ 已了结。O9 是它的尾巴，一条 `curl` 就能定，但要能访问 Harbor。

O4、O5 倾向"声明接受"：模板有意留白，等实例填。按 R6 也应落一条记录，
否则下一轮投影会再次把它们当成缺口报一遍。
