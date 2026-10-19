# 请 Fable、Astra 评审：Opus 2026-10-19 的工作（0035、0036、待办账 138、K19 第 3 稿、0037）

> 所有者 2026-10-19：「你写个总结文档，我要提交fable和astra评审」。
> 这份是给评审看的总结与索引，不是任务卡。请读源码与设计，不必读回执。意见照 [`review-2026-10-18-fable.md`](review-2026-10-18-fable.md) 的格式写成 `tree-build/review-2026-10-<日>-<名字>.md`：按轻重排，每条写在哪、为什么、建议怎么改；采不采纳由 Opus 定，拿不准的问所有者。
>
> **最要紧的是第一部分 0037**：代码已写完、已推送，**还没发版**（发版卡 qwen-016 等评审）。第二部分（0035、0036、138）已经上线（qwen-014）。第三部分是一份专家清单，不是代码。

## 零、读哪些提交

全部在各仓 `origin/qwen`。「已上线」是 k8s `infrastructure/applications/sources.yaml` 现在钉着的版本。

| 仓 | 已上线 | 这次评审的头 | 看 diff |
| --- | --- | --- | --- |
| knowbench-backend | `29d69eb`（含 0036、138） | `53fdf22`（0037） | `git diff a0181b2..53fdf22`（0036 + 138 + 0037）；只看 0037：`29d69eb..53fdf22` |
| knowbench-app（父仓：契约锁） | `8b4d8e4` | `26a2c8c` | `contracts/knowlab-test-run-lock.json` |
| knowlab-backend | `7e1a3cf`（含 0035、0036） | `8d0c6ef`（0037） | 0037：`7e1a3cf..8d0c6ef`；0035/0036：`7298030..7e1a3cf` |
| knowlab-admin-frontend | `20d6908` | `ad86749` | 0037：`20d6908..ad86749` |
| knowlab-web-frontend | `badd017` | `233a13a` | 0037：`badd017..233a13a` |
| knowlab-app（父仓：契约） | `6d395c8` | `ce56928` | `contracts/knowbot-test-run/v1/` |
| k8s（设计、配置、发版卡） | — | `origin/qwen` 头 | 见下面各节点名的文件 |

## 一、0037：创意、分身、专家；测试结果带回成稿与各步交回物（未发版）

设计：[`SDD/modules/0037-idea-avatar-expert.md`](SDD/modules/0037-idea-avatar-expert.md)（所有者原话在页首）。发版卡：[`switch-test/inbox/qwen/2026-10-19-qwen-016-idea-avatar-expert.md`](../switch-test/inbox/qwen/2026-10-19-qwen-016-idea-avatar-expert.md)。决定记录：`decisions.md`「已定」第一条；词汇表 `turn/glossary.md`「创意、分身、专家」。

### 1. 为什么做

- 测试结果原来只回「每步过没过」（0027「不回任何分析内容」）。写清单的是我们的测试人员，看不到成稿就验证不了这一稿（所有者：「草稿毕竟要测试人员写啊，看不到成稿如何验证草稿」）。
- 成稿写在测试电脑上，knowbench 只核文件在不在、从不读内容；三条用例共用工作区，后一条的成稿盖掉前一条；测完目录就删；交回物 7 天后删。
- 叫法乱（种子、雏形、想法、专家草稿、第 N 稿），管理端一页压着所有东西，web端潦草。

### 2. 做了什么

**叫法**：创意（`knowbot_request`）→ 分身（`knowbot_draft`，「分身 1.3」）→ 专家（`knowbot`）。孵化是分身的第一段，不单独占一栏，但页面上留一整块给将来的大工程（所有者「建分身将来是一个很大的工程……我们要为将来考虑」）。代码、表名、接口路径不改名。「分身」10-16 至 10-18 的文档里指专家，词汇表写明以 10-19 为界。

**knowbench（运行方）** `53fdf22`
- `application/workbench/test_runs.py` `KnowbotTestConductor._record`、`_outputs`、`_deliverable`：每条用例记结果的那一刻取产出；超时收尾的用例（`_time_out`）也取。
- `domain/workbench/test_runs.py` `step_output`、`case_outputs`：纯函数，取每步最后一次尝试（通过的交回物；没过的交回内容、原文 2 万字、逐条验收；没走到的 `not_reached`）；上限成稿 20 万字、每步交回物 20 万字节（超了不带、记原大小）、每条用例合计 2 MB（先拿掉最大的交回物，再截成稿）。
- `application/workbench/deliverable_check.py` `AgentDeliverableCheck.read`：经会合点服务流 `fs/readFile` 读成稿，一次 ≤ 512 KiB；**只读这条用例这次验收时记下了 `workspace_path` 的文件**，不读碰巧在那儿的（可能是上一条用例的）。
- 存 `workbench_test_cases.outputs`（迁移 `20261019_0021`），整次测试收尾 30 天后 `clear_test_outputs` 清空，结果本身留着。
- 新接口 `GET /internal/v1/knowbot-runtime/test-runs/{run_id}/cases/{case_id}/outputs`（`knowbench:testrun`，内部主机），没有就 404。

**契约** knowbot-test-run/v1 只加不改：knowlab `domain/knowbots/test_run.py` `CaseOutputsV1`（真源）→ `contracts/knowbot-test-run/v1/test-run-case-outputs.schema.json`；knowbench 锁更新，两边锁测试都过。原有三份 schema 逐字没变。

**knowlab（编排方）** `0a6a9be` + `8d0c6ef`
- `application/services/knowbot_service.py` `_collect_outputs`：刷新时，每条有结论的用例取一次，存 `knowbot_test_output`（迁移 `20261019_0009`，主键 draft_id + run_id + case_id，重测不混；CHECK 产出与原因至少一样）；运行方不可达下次刷新再取（测完的也补取）；运行方 404 记一句原因，不再取。
- `infrastructure/external/service_client.py`：`request(..., accept=(404,))` 让调用方自己处理 404（旧版运行方没这个接口时也走这里）。
- web 新接口（`interfaces/endpoints/knowbot_routes.py`）：创意详情（方法原文、用例）、分身详情（规则出处只给 `rule` 与 `ref`）、分身产出、做出来的专家；**不是自己的与没有的一样 404**（`my_request`、`my_draft`）。web 问题列表加 `draft_id`（用户自己的分身）。
- 管理端新接口：分身产出、清单原文；分身列表加 `delivered_at`；交付时在 `delivery` 里记 `delivered_at`。
- k8s 配置：`WEB_AUTH_ALLOWED_RETURN_PATHS` 加 web端新页（前缀匹配，已用 knowlab 的 `Settings` 解析核过）；两个后端 `expected_schema_revision` 已改。

**管理端** `ad86749`
- 一级导航「创意 / 分身 / 专家」（`lib/navigation.ts`），各带「要我们动手」的数（`components/knowbots/shared.tsx` `todoCounts`）；治理控制台加同一块（`todo.tsx`）；旧 `/knowbots` 转 `/ideas`。
- `avatars-view.tsx`：分身一页走完四段（孵化 → 核出处 → 测试 → 交付）；孵化一块现在是手工孵化（选创意、贴清单）；`outputs.tsx`：每条用例的成稿（`markdown.tsx`：react-markdown + remark-gfm，同 knowbench 网页端，不渲染原始 HTML）与各步交回物。
- `side-panel.tsx`：右边可折叠对照栏（照 knowbench `components/workbench/side-panel.tsx`）；宽度进界面设置（`store/ui.ts`），窄屏默认收起（`useSyncExternalStore`）。
- `ideas-view.tsx`（补充方法处理、它的分身）、`experts-view.tsx`（各版本、交付重试）。原 `knowbot-drafts.tsx`（1074 行）拆掉。

**web端** `233a13a`（子代理写、Opus 审过并改了两处）
- `app/[locale]/(dashboard)/layout.tsx` + `components/shell/web-shell.tsx`：同一套外壳，不照搬管理端（没有多页签；「待我回答」「我的数据」单列）。
- 页面：首页（进展一览 `overview.tsx`）、待我回答（按创意分组）、创意、分身（成稿放最前，「每一步的结果」默认收起；平台的错写「不是你方法的问题，我们会重测」）、专家（按专家名列，不叫「我的专家」）、我的数据；旧 `/knowbots`、`/knowbots/new` 转走。
- 提交创意时的同意文字改了（见下面 3.1）。

### 3. 请重点看

1. **合规（C-L1 / C-L3 / C-L5）**：0027「不回任何分析内容」改成运营看全部产出（验证这一稿）、用户只看自己的（验收依据）。改动见 0037 §六、0027「结果」「产出与保留」两行。用户提交时的同意文字从「测试产出不给任何人看，7 天后删除」改成「只给你自己和做测试的工作人员看……不给别人，不作别的用途」（`knowlab-web-frontend/app/messages/*.json` `knowbotRequests.form.consent`）。**之前提交的创意是在旧说法下同意的**（目前只有我们自己的 sig-am 一个）。这样改、这样说够不够？
2. **越权**：web 四个新接口只认主人、别人 404（`knowbot_service.py` `my_request`、`my_draft`、`my_knowbots`；接口测试 `test_ideas_avatars_outputs_and_experts_through_the_api`）。管理端产出接口对 operator 也开放（看得到用户的分析内容）——要不要只给 admin？
3. **读成稿这条路**：路径是 `session.project_root` + 验收时记下的 `workspace_path`（来自清单的 `output_file`，经 `placed(...)`）。清单是我们写的，但若 `output_file` 带 `../` 会怎样？代理一侧只放行白名单根目录（`sunmoon-link/agent/src/service.ts` `dispatch`），这一道够不够，knowbench 要不要自己再挡？**另：`service.ts` 的 Linux 分支注释写着「Linux path is for tests」，而测试电脑是 Linux 容器里的代理**——现有的成稿硬检查（`fs/getMetadata`）走的同一条路；`fs/readFile` 在测试电脑上真能用吗？（Astra 熟悉代理，请特别看这一条。）读不到的话照实写原因、不影响结论，但这一版的主要价值就没了。
4. **存储与保留**：knowbench 留 30 天、knowlab 跟着分身一直留；每条用例上限 2 MB 存 JSONB。合理吗？knowlab 那边要不要也定一个期限（K26「留多久待定」）？
5. **并发与幂等**：两次刷新同时取同一条用例的产出（`put_test_output` 用 `on_conflict_do_nothing`）；重测换 run_id；`_record` 里取产出抛异常会不会拖累记结果（现在整个 `_outputs` 包了 try，异常记进 `error`）。
6. **契约演进**：新接口放在 v1 里「只加不改」，旧版运行方 404 当「没有产出」。还是该开 v2？
7. **页面分工**：管理端三栏怎么分（孵化与测试交付都在分身页、补充在创意页）；web端和管理端哪些该一样、哪些该不同（0037 §四的对照表）。子代理报告的偏差：手机上右栏入口是右下角按钮（两端共用组件）；web 右栏没做「用到的数据」页签；`/toolkit` 也套了外壳（已去掉里面那层 `<main>`）。

### 4. 测过什么、没测什么

- knowbench 后端全量（真 PostgreSQL）1285 过、8 跳过（跳过数同以前）；新测试：`test_knowbot_case_outputs.py`（纯函数与截断）、`test_knowbot_test_run_lock.py`（产出合提供方 schema）、`test_knowbot_test_runs_db.py`（写了才读、读失败照实写、超时也取、30 天清空）、`test_deliverable_check.py`（读成稿的映射、太大）、`test_knowbot_runtime_routes.py`（404/422）。
- knowlab 后端全量（真库）549 过；新测试：`test_knowbot_test_outputs.py`、`test_knowbot_clients.py`（404 当没有、契约不合、答错用例）、`test_knowbot_creation_routes.py`（隔离、清单原文、问题带 draft_id）、`test_knowbot_repository_db.py`（约束、迁移退进）。
- 管理端 66 条、web端 112 条；类型检查、lint、i18n、prettier 都过。
- **没做**：两个前端的生产构建（远程机 3.7 GB 内存不够，本地机发版时构建）；浏览器里看真页面；e2e；web 预览样例（预览本来就一个业务接口都没录）；**测试电脑上真读一次成稿**（第一次会是第 3 稿测试）。测试环境里给 Node 25 不能写的 localStorage 加了兜底（`vitest.setup.ts`，Node 24 不触发）。

## 二、已上线（qwen-014），未经评审

### 0035 用户补充方法

设计 [`SDD/modules/0035-method-amendment.md`](SDD/modules/0035-method-amendment.md)。用户看了测试结果想改某一步，在 web端写补充（写下不改、不删）；运营要么用进下一稿的规则出处（`amendment:<id>`，来源 `user_text`），要么写理由不照做；建稿前写的补充没处理完，核对出处被挡（`amendments_open`）。knowlab `domain/knowbots/drafts.py`（`amendment_refs`、`amendment_status`、`amendments_to_handle`）、`knowbot_service.py`（`amend`、`decline_amendment`、`review_rules` 的关口）、迁移 `20261019_0008`。
**请看**：状态全从各稿清单推（P2，不另存）对不对；「按这一稿」挡（建稿后写的不挡这一稿）的边界；CHECK 约束（先判非空再比长度）。

### 0036 引文由平台核

设计 [`SDD/modules/0036-quote-check.md`](SDD/modules/0036-quote-check.md)。专家判「支持」的结论要引年报原文（数据 id、PDF 第几页、原话），knowlab 回那份 PDF 那一页找：NFKC、去所有空白、一字不差子串，可跨到下一页开头；10–1000 字。knowlab `domain/knowbots/data_read.py`（`find_quote`、`pdf_pages`）、接口 `POST /internal/v1/knowlab/knowbot-data/quotes`；knowbench 验收 `quoted`（`application/workbench/acceptance_numbers.py` `_quoted`），knowlab 拒了、不可达记平台错。
**请看**：「去所有空白」会不会让本不相同的两段字相等（中文里风险小，英文与数字串呢）；跨页只接下一页开头 `len-1` 个字的写法；页码用 PDF 物理页而不是印刷页码的取舍。

### 待办账 138 平台收尾的用例记出错

knowbench `domain/workbench/test_runs.py` `case_result`：委托停下原因里 `platform` 为真（对账收尾 `settle_unattended`、推它的程序崩了 `fail_after_crash`）记「出错」并写原因；别的失败也写原因。

## 三、K19 第 3 稿清单（不是代码，但守 C-L1）

[`SDD/modules/0029-sample-fin-forecast/manifest-v1-draft3.json`](SDD/modules/0029-sample-fin-forecast/manifest-v1-draft3.json)（`manifest_v1.py` 生成）；样本 README 第 5 条、预演 `rehearsal/README.md`「第 3 稿」。第 6 步照 sig-am 的补充（原话见样本 README）改成拿分析结论对照年报的管理层讨论。

**请看工程化有没有替用户补方法**（Opus 自己标出的三处）：
1. 补充没说读哪几年，按字面读所有年报的管理层讨论（五份约 31 万字节，读 10 次）；
2. 为了不改 sig-am 填的用例 1（期望 `official.official_by_year.2024.revenue`），第 6 步仍把「主要会计数据」表的营业收入抄一遍，平台回表核——只为对数，不是方法；
3. 判断写成「部分支持」之类，`quoted` 规则不要求引文（规则只认「支持」）；方法里写明只许两种。

预演（远程机，五份真年报，knowlab 真抽取与找原话、knowbench 真判分）：6 步判分全过；第 6 步做错的六种（没引原文、页码错一页、改一个数字、引了没绑的数据、太短、判不支持却引假话）都不过，该过的三种都过。

## 四、Opus 自己没把握、想听意见的

1. 0037 读成稿走测试电脑上代理的 `fs/readFile`（第一部分 3.3）。
2. 管理端产出给不给 operator（3.2）。
3. 同意文字改了，之前的同意怎么办（3.1）。
4. knowlab 产出要不要定保留期（3.4）。
5. 第 3 稿第 6 步一次读五份管理层讨论，上下文会不会太大（第 2 稿第 6 步读同样五份年报的前部，c2 一次过；这次约一倍）。
