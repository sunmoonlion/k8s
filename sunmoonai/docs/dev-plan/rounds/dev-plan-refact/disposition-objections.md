# ④b 异议处置 ｜ `dev-plan-refact` 轮

> 裁决方 / 整合方 **cursor**（R6）。④ 五家已交齐；实质异议 5 条，逐条处置。
> ③ 处置记录不覆盖——改判记入本文（协议 §12、§176）。
> 驳回理由只写事实。验收方 `qwen` 提了其中 3 条。

取件（主线归档，与各家分支逐字节一致）：

```text
~/master/k8s/sunmoonai/docs/dev-plan/rounds/dev-plan-refact/reviews/objection-kimi.md
~/master/k8s/sunmoonai/docs/dev-plan/rounds/dev-plan-refact/reviews/objection-qwen.md
~/master/k8s/sunmoonai/docs/dev-plan/rounds/dev-plan-refact/reviews/objection-opus.md
~/master/k8s/sunmoonai/docs/dev-plan/rounds/dev-plan-refact/reviews/objection-luna.md
~/master/k8s/sunmoonai/docs/dev-plan/rounds/dev-plan-refact/reviews/objection-cursor.md
```

| # | 家 | 原裁定 | ④b | 原条目计入变化 |
| --- | --- | --- | --- | --- |
| K1 | kimi | 拒绝 | **部分采纳** → 改判部分接受 | 计入 8 → 9 |
| K2 | kimi | 部分接受 | **部分采纳**（维持部分接受，改接到哪） | 不变 |
| Q1 | qwen | 部分接受 | **部分采纳**（补裁「契约旧版并行」） | 不变 |
| Q2 | qwen | 部分接受 | **部分采纳**（改范畴说明，仍不引入 `REQ-05.3`） | 不变 |
| Q4 | qwen | 拒绝 | **驳回** | 不变 |

opus / luna / cursor：无异议。qwen「约束委员会」：无异议。均不处置。

---

## K1 · kimi｜S3/S6 把工单字段齐全、落点齐全归 round-status

### 异议原文

`~/master/k8s/sunmoonai/docs/dev-plan/rounds/dev-plan-refact/reviews/objection-kimi.md:5-12`

主张：拒绝理由打的是 luna ② 对「普通工作单元字段齐全 / 260 行落点」的转述，不是 kimi ① L127/L131 原文；裁决稿 `pipeline.md` 已写下脚本只判轮次产物是否作为 git 提交出现，与 S6 原文吻合，处置内部不一致。应当改判部分接受。

### 裁定

**部分采纳。**原条目由拒绝改判**部分接受**。

接到：`round-status.py` 判轮次产物按工单配置作为 git 提交出现、环节从提交推导不看声明、`round.md` 缺 `final_path`/`round_dir`/`prefix` 即拒绝判定、档位从工单解析留痕。

止于：普通任务工单（目标/实施/测试/验收/回滚）字段齐全检查、260 节逐项安置检查。

### 理由

1. kimi ① 原文 L127 是「S3 工单字段齐全 / 档位留痕｜机器｜`round-status.py` 解析 `round.md`」，L131 是「S6 落点齐全 / 状态推导｜机器｜`round-status.py`（从产物反推，不看声明）」。`git show dev-plan-refact/kimi:sunmoonai/docs/dev-plan/pipeline.md` 第 127、131 行。
2. luna ② 把这两行转述成「可判工单字段齐全/落点齐全」，再解释成普通任务「目标/实施/测试/验收/回滚」和「260 行逐项安置」。`~/master/k8s/sunmoonai/docs/dev-plan/rounds/dev-plan-refact/reviews/review-luna.md:170-172`。③ 处置记录 §一 第 4 行按 luna 的转述拒绝了 kimi 原文。
3. 脚本事实（`~/master/k8s/sunmoonai/docs/dev-plan/protocol/round-status.py`）：`committed` 在 `:73`，「不看工作区」；`stage_table` 在 `:343`，按工单产物路径查提交；缺字段 `die` 在 `:652-654`（`final_path`/`round_dir`/`prefix`）。可复跑：`( cd ~/master/k8s && python3 sunmoonai/docs/dev-plan/protocol/round-status.py )`，输出「缺：…」来自 git 提交不是工作区。
4. ③ 裁决稿已经按第 3 点写过能力边界（当时 `pipeline.md:74`）。用 luna 转述拒绝 kimi、同时在稿里接受 kimi S6 的实际内容，是处置内部不一致。kimi 自己认：「字段齐全」若指协议全部字段则超称——故止于上面那条，不改成全接受。

### 改了什么

提交 `396f5429`。`pipeline.md:74-78`；`dev-plan-architecture.md:141`。

---

## K2 · kimi｜决定索引文件 `rounds/decisions-index.md`

### 异议原文

`~/master/k8s/sunmoonai/docs/dev-plan/rounds/dev-plan-refact/reviews/objection-kimi.md:14-21`

主张：部分接受接到「双失败检查并进 luna 检索器」，但检索器唯一断言是 `assert old == 26 and len(ids) == len(set(ids))`，对当前轮 `current` 只打印不断言；与已被接受的 Q9「两个方向都能失败」冲突。应当维持部分接受，把当前轮条数或 ID 钉进配置。

### 裁定

**部分采纳。**原条目维持**部分接受**（仍不另建 `rounds/decisions-index.md`）。改「接到哪」：检索器对当前轮裁定同样设可失败断言。

### 理由

1. Q9「索引两个方向都能失败」在 ③ 处置表是**接受**。`~/review/dev-plan-refact-③裁决稿/sunmoonai/docs/dev-plan/rounds/dev-plan-refact/disposition.md:66`。
2. ③ 稿 RUNNER 的 `verify` 在对账完 260 落点后，对决定索引只做 `assert old == 26 and len(ids) == len(set(ids))`；`current` 只进入打印。在 `1f2d0651` 的 architecture 文内 RUNNER 可复现。冻结基座上实测 `old=26`、`current=2`（`round:dev-plan-refact:R1/R2`）。删掉或新增一条当前轮裁定行、并同步该文件的 sha256 钉死后，旧断言仍通过。
3. 因此「并进检索器」的落盘不满足已被接受的 Q9。这是两条处置之间的事实冲突，不是「读起来更好」。luna ② 已指出该检索器锁在冻结 rulings：`~/master/k8s/sunmoonai/docs/dev-plan/rounds/dev-plan-refact/reviews/review-luna.md:165-166`。

### 改了什么

提交 `e39a4929`。`pipeline.md:210-213`；`dev-plan-architecture.md` Q9 行、§六，以及 CONFIG 的 `current_ruling_count=2` / `current_ruling_ids` 与 `verify` 对应断言。

⚠ 该提交写入窗口与 Q1 类型表/生命周期句的写入重叠，故 `e39a4929` 的 diff 里同时含有 Q1 的 S2 类型表句与 architecture 生命周期句。Q1 的阶段表落盘在后面的 `6770b106`。不把 Q1 算进 K2 的改判范围。

---

## Q1 · qwen｜发布后运行反馈与契约旧版并行

### 异议原文

`~/master/k8s/sunmoonai/docs/dev-plan/rounds/dev-plan-refact/reviews/objection-qwen.md:19-26`

主张：部分接受只回应了「运行反馈」并接到 luna S6，没有回应同一条里的「契约旧版并行」。应当对 CONTRACT 旧版本保留到 consumer 锁升级完成单独裁定。

### 裁定

**部分采纳。**原条目维持**部分接受**（不另加 S7）。补裁：接受契约旧版本保留到所有 consumer 锁升级完成；不另立 CONTRACT 类型。

### 理由

1. ③ 处置「部分接受接到哪」只写了「qwen 运行反馈 → luna S6，不另加 S7」。`~/review/dev-plan-refact-③裁决稿/sunmoonai/docs/dev-plan/rounds/dev-plan-refact/disposition.md:103`。同一行条目标题含「与契约旧版并行」，后半未落裁定。这是覆盖不全，不是否决权争议。
2. qwen ① 生命周期表 CONTRACT 行原文：「旧版本保留到 consumer 全部升级」。`git show dev-plan-refact/qwen:sunmoonai/docs/dev-plan/pipeline.md` 类型生命周期表（异议稿里写的 `~/review/.../pipeline.md:44/:114` 指的是裁决稿行号，不是 ① 候选；主张本身在 qwen 分支成立）。
3. ③ 稿 S2 行当时只写「批准版本可被新版本取代」，没有 consumer 锁。补上保留规则并不创造新阶段或第十二类文档。

### 改了什么

- `e39a4929`（与 K2 同提交，见上）：类型表 S2 行、architecture 生命周期 TLD/SDD 行。
- `6770b106`：阶段表 S2 产物列。

运行反馈接到 S6、不另加 S7：维持。

---

## Q2 · qwen｜稳定落点编码 `REQ-05.3`

### 异议原文

`~/master/k8s/sunmoonai/docs/dev-plan/rounds/dev-plan-refact/reviews/objection-qwen.md:30-37`

主张：`Ixx-xxx` 是输入文档条款级地址，`REQ-05.3` 是需求基线章节级产品 ID，③ 把后者叫「第二套编号」是范畴错误。应当接受章节级编码，或至少写明拒绝的是「用 REQ 替代 Ixx-xxx」。

### 裁定

**部分采纳。**原条目维持**部分接受**。改理由：承认两套地址不在同一层；仍不引入 `REQ-05.3`。

### 理由

1. luna 基座把 `I02-021` 定义为「第二份输入的第 21 节」。`git show dev-plan-refact/luna:sunmoonai/docs/dev-plan/dev-plan-architecture.md` 第 37 行。这是本轮 inventory 地址。
2. qwen ① 把 `5.3 排队与可靠投递` 编码为 `REQ-05.3`。`git show dev-plan-refact/qwen:sunmoonai/docs/dev-plan/dev-plan-architecture.md` 约第 75 行。这是产品合同章节编码。范畴不同，③「第二套编号」那句把 inventory 地址当成了产品章节地址的替代物，这点异议成立。
3. 产品合同条款级稳定 ID **已经存在**：`working/request-lifecycle.md` 的 F/I/AT（如 `:450` 的 `I3`）。章节级人读坐标已经是标题「5.3 …」。再加 `REQ-05.3` 是第三套。本轮内核逐字节不拆（③ 已接受 luna「本轮内核逐字节不拆」），不在本轮给内核另立章节编码。拒绝的不是「章节可以有稳定称呼」，是「本轮不新增 `REQ-xx.x` 产品 ID 空间」。

### 改了什么

提交 `a4bd8601`。`pipeline.md:179`；`dev-plan-architecture.md:49-53`。

---

## Q4 · qwen｜DoD「已记录或已获授权」析取

### 异议原文

`~/master/k8s/sunmoonai/docs/dev-plan/rounds/dev-plan-refact/reviews/objection-qwen.md:51-58`

主张：③ 把析取读成「未授权动作只因留记录而算完成」是过度解读；原意是授权记录与执行/审计记录二者至少其一满足追溯。应当接受 D6，并附加「若需预先授权则授权记录必要」。

### 裁定

**驳回。**原条目维持**拒绝**。

### 理由

1. qwen ① D6 原文是「不可逆副作用已记录或已获授权」，同一行的机器列是「机器：副作用账有记录」。`git show dev-plan-refact/qwen:sunmoonai/docs/dev-plan/pipeline.md` 第 83 行。机器判据只有「账上有记录」，没有「该动作是否已获授权」这一支。③ 读的是这一列，不是把析取「过度解读」成记录替代授权——① 自己把机器通过条件写成了记录。
2. 异议「应当是什么」里的附加说明（若动作需要预先授权，则授权记录必要）**不在 ① 文本里**。④ 不能用新限定词把 ① 的无约束析取改写成另一条主张再要求接受。
3. 所引证据对不上这条 DoD。`constraints.md` 的 I5 是 session/BFF 与 FastAPI 的授权**分工契约**（产品不变量，不是完成门）。`agent-dev-guide.md:861` 是 master 发布「仅 integrator 在最终验收并获授权后更新」的事故表，禁止的是未获授权写主线，恰与「有记录即可过 DoD」相反。
4. ③ 稿已经写下独立原则：「执行前授权与执行后如实记账不能互相替代。」现 `pipeline.md:127-128`。luna ② 对同一析取的独立判断是「留下越权通过的口子」。`~/master/k8s/sunmoonai/docs/dev-plan/rounds/dev-plan-refact/reviews/review-luna.md:204`。

无裁决稿改动。

---

## 验收方复算（协议 §13）

改判后处置表「接受 + 部分接受」：

| 家 | 接受 | 部分接受 | 拒绝 | **计入** |
| --- | --- | --- | --- | --- |
| opus | 5 | 1 | 3 | **6** |
| kimi | 5 | 4 | 0 | **9**（K1 拒绝→部分接受） |
| qwen | 2 | 2 | 2 | **4** |
| cursor | 5 | 6 | 1 | 11（排除） |
| luna | 11 | 1 | 0 | 12（排除） |

排除裁决/整合方 `cursor` 与基座作者 `luna` 后，最少仍是 `qwen`（4），无并列。

> **验收方仍是 `qwen`。**与 ③ 指定相同，不触发「不得事后更换」的例外（§13：结果不同才交所有者裁定）。

---

## 是否回到 ③

**不回。**四条部分采纳都不触及基座结构：K1 是脚本能力边界的改判；K2 是已有检索器上补可失败断言；Q1 是 S2 契约生命周期注，不新增阶段或类型；Q2 是编号范畴说明，不改 260 节安置、不改内核。协议「④ 异议被采纳且触及基座结构 → 回到 ③」的前件不成立。

---

## 覆盖与未做

**查了：**五份异议全文；kimi/qwen ① 对应段落（`git show`）；luna ② K1/Q1 原文；`round-status.py` 的 `committed` / `stage_table` / 缺字段 `die`；③ RUNNER 对 `old`/`current` 的断言；`request-lifecycle.md` F/I/AT 与 5.3 标题。

**没查：**产品仓测试；I08-009 人表与 CONFIG 不一致（luna/cursor ④ 已留证，不在本通知 5 条内，交 ⑤）；qwen 异议里指向裁决稿行号的两处取件（已改从 qwen 分支取 ①）。

**没读作判据：**`inputs/` 正文（B14）。
