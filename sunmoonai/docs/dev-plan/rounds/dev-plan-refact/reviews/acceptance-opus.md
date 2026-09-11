# ⑤ 验收 · opus ｜ `dev-plan-refact` 轮

> 验收方：`opus`，依据 `rulings.md` R7（所有者决定由 `opus` 验收，替换 §13 算出的 `qwen`）。
> 验收对象：`dev-plan-refact/cursor` @ `3e093ede`（④b 之后的最终提交）。
> 取件：检视面 `~/review/dev-plan-refact-⑤定稿/`，与分支逐字节一致：
> `pipeline.md` 274 行 sha256 前 16 位 `af8abec6928b8cb0`；`dev-plan-architecture.md` 786 行 `468329f39c2903a7`。
> 下文 `file:line` 一律指这个检视面里的文件。

## 结论

**按任务书冻结的验收标准：通过。**M1–M4 全过；J1–J7 全过；§6.3 一票否决 0 条。

**但有一处缺陷，建议在 ⑥ 确认前先修（由所有者裁定）：**定稿自带的核验工具 `verify` 失败——
`I08-009` 在人读的落点表与机器配置里落点不一致；而正文仍写着工具「均通过」。
这一条不在任务书 §6 的判据里，按协议 §8.2「任务书没有的要求不得用于扣分」，不改变「通过」的结论；
但带着它发布，就是把一个失败的检查写成通过（协议 §8.1 那张表的下一行）。详见第五节。

⚠ 按协议 §13.2，本结论只表示「经过一次外部检视」，不表示「已验证」。

## 利益声明

`rulings.md` R7 已如实记录，这里只列与本稿判断直接相关的：

1. `opus` 在处置表中「接受＋部分接受」6 条，多于 §13 原选中的 `qwen`（4 条）；
2. 任务书、`inputs/`、`call-①`～`call-④b` 均由 `opus` 起草，本稿所对照的冻结标准是 `opus` 写的；
3. **§13.1 第一阶段对 `opus` 不独立**：④ 时 `opus` 作为组织者已读过并转述了产出方的自陈盲区
   （`disposition.md` §五，写进了 `call-④.md`）。第五节的缺陷，`opus` 事先就知道去哪里找，不能算独立发现。

## 一、机械条

| # | 判据 | 结论 | 证据 |
| --- | --- | --- | --- |
| M1 | 落点表覆盖 `inventory.md` 全部 260 节 | 通过 | 按「完整源路径 + 起行」比对：inventory 260 行、第八节表 260 行，缺 0、多 0；标题去掉反引号后 260 行全同 |
| M2 | 落点表无空落点 | 通过 | 260 行前 5 列均非空（表头见 `~/review/dev-plan-refact-⑤定稿/sunmoonai/docs/dev-plan/dev-plan-architecture.md:330`） |
| M3 | `doc-gate.py --all` 全绿 | 通过 | 在检视面仓根运行，216 份通过 |
| M4 | 候选文件按 §7 路径与命名 | 通过 | `dev-plan-refact/cursor:sunmoonai/docs/dev-plan/pipeline.md` 与 `…/dev-plan-architecture.md` 均存在 |

M3 复跑：

~~~bash
( cd ~/review/dev-plan-refact-⑤定稿 && python3 sunmoonai/docs/dev-plan/doc-gate.py --all )
~~~

## 二、判断条

| # | 判据 | 结论 | 依据（`file:line`） |
| --- | --- | --- | --- |
| J1 | ①a 六项完整 | 通过 | 阶段 `~/review/dev-plan-refact-⑤定稿/sunmoonai/docs/dev-plan/pipeline.md:36`；门与执行归属 `~/review/dev-plan-refact-⑤定稿/sunmoonai/docs/dev-plan/pipeline.md:61`、归属三档 `:91`；文档类型与生命周期 `~/review/dev-plan-refact-⑤定稿/sunmoonai/docs/dev-plan/pipeline.md:176`；AI 前提 `~/review/dev-plan-refact-⑤定稿/sunmoonai/docs/dev-plan/pipeline.md:20`；可以开工与做完 `~/review/dev-plan-refact-⑤定稿/sunmoonai/docs/dev-plan/pipeline.md:103`、`:121` |
| J2 | 类型从阶段推出 | 通过 | 每类标「首次需要它的阶段」`~/review/dev-plan-refact-⑤定稿/sunmoonai/docs/dev-plan/pipeline.md:176`；「至此流程已经成立，才决定文件组织」`~/review/dev-plan-refact-⑤定稿/sunmoonai/docs/dev-plan/pipeline.md:173`；双向检验 `~/review/dev-plan-refact-⑤定稿/sunmoonai/docs/dev-plan/pipeline.md:197`；两问压缩类型 `~/review/dev-plan-refact-⑤定稿/sunmoonai/docs/dev-plan/pipeline.md:194` |
| J3 | 归属判据先于归属结果 | 通过 | 先给「门消费 + 三问」判据 `~/review/dev-plan-refact-⑤定稿/sunmoonai/docs/dev-plan/dev-plan-architecture.md:21`、`:25`，再给目标文档 `:42` 与第八节表 `:323`；每个目标的每个栏目带「归属判据」列 |
| J4 | 每份文档内部结构被论证 | 通过 | 十四个目标各有一句排序理由与栏目判据，起于 `~/review/dev-plan-refact-⑤定稿/sunmoonai/docs/dev-plan/dev-plan-architecture.md:74`；任务书点名的 `agent-dev-guide.md` 按一个工作单元的动作顺序重排 `:123`；原位保留的内核给了沿用理由 `:36`、`:39` |
| J5 | 拆并代价写明 | 通过 | 拆并收益与代价表 `~/review/dev-plan-refact-⑤定稿/sunmoonai/docs/dev-plan/dev-plan-architecture.md:227`；正式迁移要扫的引用与阻断条件 `:237` |
| J6 | B2 锚点保全可执行 | 通过 | 内核原路径逐字节保留，旧行区间全部仍对 `~/review/dev-plan-refact-⑤定稿/sunmoonai/docs/dev-plan/dev-plan-architecture.md:233`、`:242`；`verify` 的受保护文件核对 16/16 一致（本稿复跑） |
| J7 | Q1/Q2/Q3/Q6/Q8/Q9 各有答案，异议举证充分 | 通过 | 逐问回答 `~/review/dev-plan-refact-⑤定稿/sunmoonai/docs/dev-plan/dev-plan-architecture.md:250`；对所有者 Q3 映射的异议有论证（调用关系成立、类型合并不成立）`~/review/dev-plan-refact-⑤定稿/sunmoonai/docs/dev-plan/pipeline.md:151` |

J4 附注：任务书 §6.4 F2「落点表填满但内容没安置」**不成立**——`I08-009` 的内容有安置（`render handoff.md` 含该单元），
正文与表也一致；不一致的是机器清单，见第五节。

## 三、一票否决、失败形态与约束

- **§6.3 一票否决：0 条。**有 ①a；先流程后类型（`~/review/dev-plan-refact-⑤定稿/sunmoonai/docs/dev-plan/pipeline.md:173`）；有归属判据；不是导读表；覆盖 260 节。
- **§6.4**：F1′、F1″ 不成立（参考材料逐份写了装得下与装不下 `~/review/dev-plan-refact-⑤定稿/sunmoonai/docs/dev-plan/pipeline.md:258`）；F3 不成立（零故意丢弃 `~/review/dev-plan-refact-⑤定稿/sunmoonai/docs/dev-plan/dev-plan-architecture.md:327`）；
  F4 不成立（`rounds/` 不重排 `:236`）；F5 不成立。F2 见上。
- **B 约束**：B1、B7、B13 由协议 `--verify` 机械判过，零命中；B7 另见 `~/review/dev-plan-refact-⑤定稿/sunmoonai/docs/dev-plan/dev-plan-architecture.md:235`；
  B9 未把旧 294 行当已验 `:313`；B10 不是导读表；B14 见上。
- **§4.2 与 `project-guide/` 的边界**：已说明 `~/review/dev-plan-refact-⑤定稿/sunmoonai/docs/dev-plan/dev-plan-architecture.md:261`。

## 四、协议 `round-status.py --verify` 各项

| 项 | 机器结论 | 验收方结论 |
| --- | --- | --- |
| 冻结区 | 🔶 未声明 `frozen_sections` | 不适用：本轮 `round.md` 未声明冻结区 |
| 提交→处置记录 | ❌ 4 个提交未登记 | **不是产物缺陷**：`396f5429`、`e39a4929`、`6770b106`、`a4bd8601` 均登记在 `disposition-objections.md`（各 1–3 处）；该检查只读 `disposition.md`。④b 这一步是本轮新加的，检查没有跟着扩到异议处置记录，属检查范围缺口，记入第七节 |
| 处置记录→提交 | ✅ | 同意 |
| 锚点路径与行号 / 锚点语义 / AT 计数 / 编号出处 | ✅ 0 处 / 🔶 | 定稿用「源路径 L行号」的写法，不是该检查识别的格式，所以机器数到 0。改为人工抽查三处事实断言，均成立：`protocol/` 975 行（冻结输入里 `round-protocol.md` 929 行加 `README.md` 46 行）、`implementation-plan.md` 93 行且无任务条目、`agent-dev-guide.md` §8–§10 占 698/3082 = 22.6%（均 `git show baa28858:…` 实测）|
| B1 / B7 / B13 | ✅ 0 处 | 同意 |

## 五、缺陷：`I08-009` 表与机器清单不一致，自带 `verify` 失败

**事实**：

| 面 | 阶段 | 落点 |
| --- | --- | --- |
| 第八节人读表 `~/review/dev-plan-refact-⑤定稿/sunmoonai/docs/dev-plan/dev-plan-architecture.md:585` | S3 | `implementation-plan.md` / 计划责任和产品工作单元 |
| 机器配置 CONFIG `~/review/dev-plan-refact-⑤定稿/sunmoonai/docs/dev-plan/dev-plan-architecture.md:601`、`show`、`render` | S0/S3 | `handoff.md` / 未决及开工输入 |

- `render implementation-plan.md` 不含 `来源单元 I08-009；`，`render handoff.md` 含（本稿在 `3e093ede` 复跑）；
- 正文两处都支持表的写法：实施计划栏写「handoff 里『文档面待办』D1/D2 的任务本体在此展开」`~/review/dev-plan-refact-⑤定稿/sunmoonai/docs/dev-plan/dev-plan-architecture.md:165`，
  交接栏写「文档面待办的任务本体在实施计划，这里只留游标和阻塞」`:174`——**过期的是机器清单**；
- `verify` 在表与配置的逐行比对处失败，`~/review/dev-plan-refact-⑤定稿/sunmoonai/docs/dev-plan/dev-plan-architecture.md:727`；逐行比对 260 行，只有这一行不一致；
  其余检查全过（受保护文件 16/16、旧三轮裁定 26 条、当前轮 2 条、ID 无重复）；
- **什么时候坏的**：luna 基座 `9a2b999c` 上 `verify` 通过；③ 的 `1f2d0651` 上已失败；`3e093ede` 上仍失败。
  是 ③ 整合改了表而没改配置，不是 ④b 引入的；
- **正文与此矛盾**：`~/review/dev-plan-refact-⑤定稿/sunmoonai/docs/dev-plan/dev-plan-architecture.md:45`「工具已对全部目标实际运行」、`:317`「本次实跑范围……均通过」。

**已知性**：产出方在 `disposition.md` §五 自陈「没查」；`disposition-objections.md` 写明「交 ⑤」；luna 在 ④ 已带证据报出（`reviews/objection-luna.md` 第 44 行起）。

**建议的修法**（一处，不涉及任何裁定）：把 CONFIG 中 `I08-009` 的 `target`、`group`、`stage` 改成与表一致，
并把它从 `handoff.md` 的「未决及开工输入」组移到 `implementation-plan.md` 的「计划责任和产品工作单元」组；
重跑 `verify` 与两个 `render`。按协议「⑤ 不通过回到 ③」的前例（`runtime-refact` 的 ⑤b），修后做一次 ⑤b 复核。

复跑（在检视面仓根）：

~~~bash
cd ~/review/dev-plan-refact-⑤定稿
python3 -c 'from pathlib import Path; import sys; p=Path("sunmoonai/docs/dev-plan/dev-plan-architecture.md"); s=p.read_text(); exec(s.split("<!-- RUNNER -->\n```python\n",1)[1].split("\n```\n<!-- END RUNNER -->",1)[0])' verify
~~~

## 六、第二阶段对照（协议 §13.1）

| 产出方自陈没查 | 本稿 |
| --- | --- |
| 1. luna RUNNER 在改过 `I08-009` 后能否双向核 | 复跑：失败，即第五节。⚠ 如利益声明第 3 条，不是独立发现 |
| 2. opus §8 那组计数命令（58/44/49/10/8） | 未复跑。定稿只吸收了其中「活跃裸锚 2 处」这一事实，且内核不拆，J6 不依赖这组数 |
| 3. `doc-gate --all` 以外的产品仓测试 | 未查。任务书 §4.2 本轮不含产品仓 |

本稿发现、产出方未自陈的：

- 正文「均通过」与自陈「没查」互相矛盾（第五节最后一条）；
- 定稿引用的 `F-LUNA-A2-01`（`~/review/dev-plan-refact-⑤定稿/sunmoonai/docs/dev-plan/dev-plan-architecture.md:308`）只在 `dev-plan-refact/luna` 分支的 `findings.md` 里，主线没有（第七节）；
- 协议 `--verify` 的「提交→处置记录」项不读异议处置记录（第四节，属检查缺口，不算产出方的缺陷）。

## 七、⑦ 之前或之时要处理的

1. 第五节的缺陷：修与不修、要不要 ⑤b，所有者裁定；
2. `F-LUNA-A2-01` 并入主线 `findings.md`，否则发布后该引用在主线上断开；
3. `round-status.py --verify` 的「提交→处置记录」项应同时读 `disposition-objections.md`（本轮结束后改，不在 ⑤ 改标准）。

## 八、覆盖声明

**查了**：任务书 §2、§4–§8 全文；两份定稿全文（第八节表逐行做了结构比对，未逐行做语义审）；M1–M4；
协议 `--verify`；定稿自带 `verify`（最终提交、③ 提交、luna 基座三处）；`I08-009` 的两个 `render`；
④b 期间两份定稿的全部改动与异议处置的四条「改了什么」逐一对应；三处事实断言。

**没查**：260 节的逐节语义归属（只核了结构与判据，以及 `I08-009` 一例）；十四个目标的 `render` 全文；
产品仓；opus §8 那组计数命令；所有者此前映射之外的分类是否更优（不在判据内）。
