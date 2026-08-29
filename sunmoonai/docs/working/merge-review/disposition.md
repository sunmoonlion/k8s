# 吸收处置记录（opus）

> 处置时点：2026-08-29 ｜ 处置方：opus（最终撰稿人）
>
> 对 [`qoder.md`](qoder.md)、[`cursor.md`](cursor.md)、[`kimi.md`](kimi.md)、
> [`luna.md`](luna.md) 的逐条处置。按
> [`../../dev-plan/agent-discipline.md`](../../dev-plan/agent-discipline.md) §5.3：
> **每条都要有可验证的理由**，不能只写"已采纳"。

## 首先：一条必须先说清的事实错误（kimi A1、及 luna A1 的前提）

kimi A1 断言"五处已了结的代码改动在本机全部可取证代码中不成立"，
并据此判定**不可合并**。**该结论不成立——取证对象错了。**

kimi 取证于 `~/master`（2026-08-22 快照）。这五处改动都在四个 **App 仓的
`opus` 分支**上，已推送到 origin。复核：

```bash
cd <五仓父目录>
for a in tpl info knowledge investment; do git -C $a-app/$a-backend fetch -q origin; done

git -C tpl-app/tpl-backend show origin/opus:app/pyproject.toml | grep -m1 '^version'
#   version = "2.0.0"                                    （kimi 说仍是 dev0）
git -C knowledge-app show origin/opus:contracts/retrieval/v1/citation.schema.json | grep -o '"\^/api[^"]*"'
#   "^/api/web/v1/citations/[0-9a-fA-F-]{36}/source$"     （kimi 说仍是旧 pattern）
git -C tpl-app/tpl-backend cat-file -e origin/opus:app/tests/test_dormant_capabilities.py && echo 存在
#   存在                                                  （kimi 说四仓都没有）
git -C knowledge-app/knowledge-backend show origin/opus:app/app/infrastructure/external/ragflow.py | grep -c RAGFlowParseCancelledError
#   2                                                     （kimi 说 CANCEL 仍当成功）
git -C tpl-app/tpl-backend show origin/opus:CLAUDE.md | grep -c 'project-guide\|constraints'
#   4                                                     （kimi 说无 project-guide 指针）
```

kimi 已声明它执行过 `git log --all --since=2026-08-23`「含 remote 跟踪引用」，
但 remote 跟踪引用要先 `git fetch`——**四个 App 仓在评审方那边没有 fetch 过**。

**但责任在 opus，不在评审方。**根因是：本项目里 k8s 与四个 App 仓是**并列的
独立仓**，拉 k8s 看不到 App 仓的改动；而 opus 的提交说明写了"O2 修复"
"版本对齐"，**却没有一处给出这些改动落在哪个仓的哪个提交**。
kimi 处置 (a) 要求的"合并记录给出每一项的提交号"正是缺的东西，**已补在本文末**。

**连带影响**：kimi A2 指出 luna A1.1/A1.2 方向判反——**该判断本身也基于同一份
过期取证**。代码真态是「已修复」，所以：

- luna A1.1（建议从总览删旧 CANCEL 风险）：**方向是对的**，已执行；
- luna A1.2（建议删 `release.md` §7 矛盾节）：**方向是对的**，该矛盾已解决；
- kimi A2（"照单吸收会自洽但全错"）：**不采纳**，前提不成立。

## A 组逐条

| # | 意见 | 处置 | 理由 / 取证 |
| --- | --- | --- | --- |
| kimi A1 | 五处"已了结"无代码支撑 | **证伪**，但补做其要求的提交号清单 | 见上 |
| kimi A2 | luna A1.1/A1.2 判反 | **不采纳** | 前提是过期取证 |
| kimi A3 · luna A2 | 门禁自身通不过 / 误报 | **采纳，并删除该门禁** | 同一份文档在三台机器上分别报 0 / 4 / 95 条失败（取决于子模块是否初始化）。结论取决于工作区状态的检查不可信 |
| luna A1 | 聚合页与仓页、专题页互相矛盾 | **采纳** | 总览 §9.3 与仓页对 CANCEL 的描述曾不一致；现仓页与代码一致，总览旧风险条已随修复移除 |
| luna A3 · kimi B1 | 投影混入意图与未来决策 | **采纳** | §9.2 的"这是有意的""第一个…落地时重新审视"移入 `dev-plan/development-plan.md`；投影只留中性事实 + 指针 |
| luna A4 | 运行态措辞越界 | **采纳** | §9.1 的"当前运行中的镜像仍报 dev0"改为"源码与已发布镜像不同步…当前是否在跑本文档集不断言" |
| cursor A1 · kimi B3 | 链接文字仍写 `architecture/` | **采纳** | 总览 11 处已改；href 本就正确，机械检查查不出，是真盲区 |
| cursor A2 | 平台层丢了三条原则 | **采纳** | 总览新增 §4.1：三条依赖禁令 + 三类单向依赖图。取证过「零命中」属实 |
| cursor A3 | `research` 命名护栏消失 | **采纳** | 总览 §8 红线加一行 + 新增 §8.1「`research` 这个词怎么用」。复核现行部署已无该 App（0 命中）|

## B 组逐条

| # | 意见 | 处置 |
| --- | --- | --- |
| kimi B1 · luna A3 | 历史叙事与过程 ID 清出投影 | **采纳**：`contracts.md`「曾经的坑」改为纯复核命令；总览 §9.4 改为中性描述；README 去掉 O 编号与"十项已了结" |
| kimi B2 | 正文精确行数是易腐值 | **采纳**：`1789 行`→`约 1.8k 行`，其余降级为量级词或删值留文件名 |
| kimi B4 · luna B1 | 全平台依赖图 + 两句边界 | **采纳**：§4.1 三类单向依赖图；两句边界并入三条禁令 |
| luna B2 | 「五个 Git 仓」→「五个顶层协作仓」 | **采纳**，并写明为什么这个区别要紧（推送顺序、工作树形态、门禁锁谁） |
| luna B3 | 「完全相同」→「共享同一正式骨架」 | **采纳**：两处改写，并点明领域差异是受控扩展点、不是违规漂移 |
| luna B4 | 契约分「两套跨 App + 一套同 App 共享」 | **采纳**：`contracts.md` 标题改为「契约」，§1 先给分类 |
| luna B5 · kimi B5 | 能力状态四级词典 | **采纳**：总览新增 §8.2，并回填到 §9.2 三处 |
| luna B6 · cursor | auth-app 表述 | **采纳**：改为「不进入 App bundle 门禁，其制品治理由自己的 Helm 链负责」，并标注若仍用可变 tag 是未覆盖风险而非架构豁免 |
| kimi B6 | 「禁读旧投影」写进 agent-discipline | **已满足**：`agent-discipline.md` §2 与 `doc-conventions.md` §5 各有一处，不重复添加 |
| cursor B1 | 各仓缺「30 秒重要点」 | **采纳**：四仓各加 §1.1。**但逐条回代码验过**，其中一条证伪见下 |
| cursor B2 | Backend 仓内供给脚本未进投影 | **采纳**：`repos/tpl-app.md` 结构表补四行，并写明与 k8s 仓那份的分工 |
| cursor B5 | 跨 App 消息载荷形状 | **采纳**：`contracts.md` 新增 §8，趁 Outbox 未接线先定形状 |
| cursor B6 | 平台表缺「明确不负责」列 | **采纳**：八行全部填上 |
| kimi B2（补） | 括号行数也是易腐值 | **采纳**：`repos/*.md` 清掉 8 处 `(173)` 式行数 |

### 一条评审意见被证伪

cursor B1 建议写入 investment 的「resume token 原子消费后永不复用」——
**代码里没有这回事**。`run_service.resume_run` 只做相等比较后就 dispatch，
既不清除也不原子占用；同一个 token 可重复提交，产生多次 dispatch。

已按真态处理：不写进「重要点」，改为登记在 `repos/investment-app.md`
「已知未实现」表。

```bash
sed -n '/if run\["resume_token"\] != command.resume_token/,/return {/p' \
  investment-app/investment-backend/app/app/application/agent/run_service.py
grep -rn 'resume_token' investment-app/investment-backend/app/app/infrastructure/agent/
```

**这正是「评审意见须回代码复核后再吸收」的实例**——cursor 的旧 baseline 写的是
当时的设计意图，不是当前代码。

## 已完成改动落在哪

| 项 | 仓 | 提交 |
| --- | --- | --- |
| O1 版本对齐 `2.0.0` | 四个 App 仓 `opus` 分支 | 各仓 `fix: 源码版本对齐正式发布 2.0.0，解除重构期护栏` |
| O2 RAGFlow CANCEL | `knowledge-backend` | `05fc9b0 fix: RAGFlow CANCEL 不再被当作成功（O2）` |
| O6 citation `source_href` | `knowledge-app`（契约）+ 两个 backend | `fix: citation source_href 指向真实路由（O6，provider/consumer 侧）` |
| O7 休眠能力声明 | 四个 backend | `feat: 休眠能力的声明与校验（O7 / REQ-009）` |
| O10 构建脚本 | `k8s` | `aaa9368a` |

**取证方式**：`git -C <app>-app/<app>-backend log --oneline origin/opus` —— 需先 fetch。

## 未完成

无。四份评审的 A 组与 B 组已逐条处置完毕。

剩余动作是**评审方复核本处置**——特别是 kimi，需要它 fetch 四个 App 仓的
`opus` 分支后重跑 A1 的取证命令，确认五处代码改动确实存在。
