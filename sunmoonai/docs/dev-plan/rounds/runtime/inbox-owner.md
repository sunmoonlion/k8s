# 收件箱：所有者（轮次 runtime）

> 引擎写，人读。形状按 `refact-fable.md`「人的通道：收件箱 + 回执」。
> **回执只认落盘**——对话里说「同意」不算。
> ⚠ **bootstrap 例外**：回执仓尚未建成（S1 产物），本轮回执 = 对应 `rulings.md` 行 + 所有者 commit，
> 与 `rounds/refact-fable/rulings.md` 的 `R2` 同一处置；S1 建成后补签收口。

当前状态：Task `WAITING(APPROVAL)`，两条待决。**不设超时默认**——H1/H6 是最后一道关卡，
按「参与方不可用」规则等待，引擎不得替你放行。

---

## I-01 ｜ H6 ｜ 重新处置 refact-fable 轮 R1 的三处冻结物

| 字段 | 值 |
| --- | --- |
| interaction_id | `runtime/I-01` |
| transition | `refact-fable` 轮 R1 所冻结的三处对象：解冻并重新处置 |
| 权力表行 | **H6**（推翻已生效的裁定）——R1 自己规定「此后只能经 H6 改，改动追加不覆盖」 |
| 方向 | 混合：§8 第 7 条**作废**属朝省事，3.13 升格属朝严谨。**朝省事的那一半必须你确认** |
| target_commit | `5483721d`（opus 分支） |
| diff_stat | 2 files changed, 529 insertions(+) |
| 截止判据 | 无超时。等待你的 commit |

**待决内容**：R1 冻结了三处，本轮的前提（只有一个运行时）打掉了其中一处半：

| R1 冻结物 | 处置 | 理由 |
| --- | --- | --- |
| §8 九条验收标准 | **七条留、第 7 条作废、第 3 / 4 条需改** | 逐条见 `../runtime/task.md`「refact-fable.md §8 九条的处置」一节 |
| 3.1.1 状态映射表 | **解冻，需重画** | 表中「开发 Profile 里的东西」一列的前提是两个 Profile；改为 Task Profile / Agent Profile 两个正交维度 |
| 3.13 威胁模型 | **留，且升格** | 由「bootstrap 期安全措施」升为**架构组件**——进程粒度执行者事中拦不住副作用，外层边界是永久必需品，不随脚手架拆除 |

**冻结验收条编号表**（H1/H6 必附）：作废 `§8-7`；改写 `§8-3`（归因）、`§8-4(c)`（扩为手工/运行时共用同一 schema）；
保留 `§8-1 §8-2 §8-5 §8-6 §8-8 §8-9`。

**你要做的**：确认后我把 `R9` 行的「人确认」由 **待** 改 **是**，与你的 commit 一起生效。
草稿已写在 `rounds/refact-fable/rulings.md` 的 `R9` 行。

---

## I-02 ｜ H1 ｜ 冻结 runtime 轮的题目与验收标准

| 字段 | 值 |
| --- | --- |
| interaction_id | `runtime/I-02` |
| transition | 工单 `DRAFT → FROZEN`；Task `WAITING(APPROVAL) → VALIDATING → QUEUED`（开轮） |
| 权力表行 | **H1**（冻结题目与验收标准） |
| 方向 | 朝严谨 |
| target_commit | `5483721d`（opus 分支） |
| diff_stat | 2 files changed, 529 insertions(+) |
| 截止判据 | 无超时。等待你的 commit |

**冻结验收条编号表**（H1 必附）：`task.md` §8 共 **10 条**——
`§8-1` 只有一个运行时 ｜ `§8-2` 人不作为执行者 kind ｜ `§8-3` 等效判据可执行 ｜
`§8-4` Interaction 双向 ｜ `§8-5` 可观测粒度 ｜ `§8-6` 必答 Q 四问全答且有反例 ｜
`§8-7` 对 OP-1/2/3 表态 ｜ `§8-8` 锚定 ｜ `§8-9` 只读输入未被改动 ｜ `§8-10` 身份自证。
其中 1、2、3、5、6、7、9、10 机械可判。

**无默认、必须你显式填的三项**（`refact-fable.md` 字段分级表，预填等于把盖章做成阻力最小路径）：

| 项 | 现值 | 说明 |
| --- | --- | --- |
| 验收条 | 上列 10 条 | 你可增删改；**冻结后不得为了让产出通过而修改** |
| executors 名单 | 提案 luna / kimi / cursor / fable / qwen；裁决 opus；验收**留空待算**（fable 不得担任） | `round.md`「角色」 |
| `tier` | `T2` | 命中不可逆 + 权威层 + 已知对立，理由见 `round.md`「档位裁定」 |

**你要做的**：确认后 `round.md` 的 `status` 由 `DRAFT` 改 `ACTIVE`，本轮开工。

---

## 我已经替你做完、你只需知道的（不需回执）

| | 状态 |
| --- | --- |
| fable 独占 worktree `~/worktrees/fable/k8s` @ `7e8464c2` | ✅ 已建 |
| 身份判别命令，六处实测全对 | ✅ 已验 |
| `agents.toml` 登记 fable（无 argv）、cursor 钉 `--model cursor-grok-4.6-high` | ✅ `protocol-v2` `8e552cb6` |
| `round-dispatch.py` 容得下无命令行入口的执行者，不静默跳过 | ✅ 同上，已冒烟 |
| `protocol-v2` 工作位置由 `~/review/` 搬到 `~/worktrees/` | ✅ 撞协议「检视面不是产物落点」 |

⚠ **一处我擅自做的、你可以驳回**：`agents.toml` 与 `round-dispatch.py` 的改动落在 `protocol-v2` 分支，
而那个分支还压着你五条待决。我判断这两项是**增量且正交**（登记事实 + 修一个会 KeyError 的分支），
不影响那五条。若你认为不该动那个分支，说一声我摘出来。

---

## I-03 ｜ H5 ｜ ⑥ 确认：runtime 轮最终稿发布

| 字段 | 值 |
| --- | --- |
| interaction_id | `runtime/I-03` |
| interaction_class | `APPROVAL_WITH_ARTIFACT` |
| transition | Task `RUNNING → WAITING(APPROVAL)`；回执成立 → `WAITING → QUEUED` → publisher Attempt → `RUNNING → SUCCEEDED` |
| 权力表行 | **H5**（不可逆 Side Effect：写共享最终路径 / 推主线） |
| 方向 | 不可逆。**协议：全流程唯一不可逆的一步，不得由固定指令推进，不得由任何 agent 代行** |
| subject_artifact_ref | 裁决稿 `runtime-architecture.md` @ `opus`/`e8903566`，792 行，sha256[:16] `1cf51672933be328` |
| amend_schema | **空**——不可逆动作不接受 amend（裁决稿 §3.4 自己的规矩）。要改就打回 ③ |
| 允许的 decision | `approve` / `reject` |
| evidence_grade | `reported`（回执通道 `shared-credential`，见 `R2`；本条回执证据强度仍为零） |
| 截止判据 | 无超时。等待你的动作 |

### 检视面（协议要求：请求确认前必须已开好并给出路径）

```
/home/zym/review/opus/sunmoonai/docs/dev-plan/runtime-architecture.md                     792 行  ← 最终稿
/home/zym/review/opus/sunmoonai/docs/dev-plan/rounds/runtime/runtime-disposition.md       391 行  ← 处置全记录
/home/zym/review/opus/sunmoonai/docs/dev-plan/rounds/runtime/runtime-acceptance-qwen.md   131 行  ← 验收报告
```

### 本轮走到这里的账

| 环节 | 结果 |
| --- | --- |
| ① 提案 | 五家全交（544 / 538 / 586 / 646 / 441 行） |
| ② 互评 | 五家全交，含自评；排序高度收敛，三家自排非第一 |
| ③ 裁决 | 基座 fable，并入四家主张 21 条；**OP-1/2/3 三项全部被改写，无一原样保留** |
| ④ 异议 | 五家全交；两条实质异议（luna `O-L1`、qwen `O-Q1`）**全部采纳，无驳回**；不触基座结构 |
| ⑤ 验收 | qwen（由处置表算出，既得利益最小）判**有条件通过**；两条条件已补足、三处勘误已更正 |
| 裁决方自陈错误 | **十三条**（E-1…E-11 + C-1/C-2 暴露的两处），其中**八条由参与方抓出** |

### 你要做的

**`approve`** → ⑦ 清理与发布：把最终稿写入主线共享最终路径、归档全流程产物、
公开 `observations-opus.md`、登记观察值、删检视面与临时分支。
**`reject`** → 回到 ③ 重整合（协议「停止、超时与回退」）。

### 两件请你在批之前看一眼的

1. **§2.4.1 第 11 行**：本轮你五次执行 `publish-*.sh` 写主线，那些都是 H5 管辖的 Side Effect
   但**没有经过 H5 门**——权力表的 H5 只对准「⑦ 发布最终稿」，没区分最终稿与轮内产物。
   建议拆 `H5-final` / `H5-round`，但我**没有擅自改权力表行数**。这条要么你现在裁，要么进下一轮。
2. **本条回执本身的强度是零**（`R2`）：你的 commit 与 agent 的 commit 在账本上不可区分。
   ⑥ 是全流程唯一不可逆的一步，而它的回执恰恰是最不可验证的——**这个矛盾本轮没有解决**，
   S1 的前置（agent 够不着的操作面）仍未做。
