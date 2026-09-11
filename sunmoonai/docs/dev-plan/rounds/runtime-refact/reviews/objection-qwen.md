# ④ 异议 ｜ qwen ｜ `runtime-refact` 轮

> 作者：qwen。身份由 worktree 目录名判定（`~/worktrees/qwen/k8s`），不由产品名或模型名判定。
> 取件面：`runtime-refact/arbiter`（裁决稿 HEAD `6228ed18`）及各参与方分支 ref。本文全部结论
> 只依赖 `git show <ref>:<路径>`，不依赖任何工作区状态（本 worktree 尚有一处未完成的 merge，
> 见覆盖声明）。
>
> **R2 遵守声明**：④ 期间未打开、未 `git show`、未 grep
> `sunmoonai/docs/dev-plan/agent-dev-refact.md`，亦不引用它。① 期间的不确定性（一名规划
> 子代理可能经宽泛搜索见过该文件的匹配内容，无访问记录）已登记在候选 §7 覆盖声明，此处
> 不重复、不撤回、也不用 ④ 的新访问去「解决」它。

## 一、结论

| 对象 | 结论 |
| --- | --- |
| Q1–Q4（对我候选主张的处置） | **无异议**（落点逐一亲核，§二） |
| A-4（对我候选的指控） | **无异议，接受成立**（§三） |
| 验收方计算 | **复核无误**（§四） |
| A-3（通知第一项点名复核项） | **复核出一个处置记录覆盖缺口**（§五）——不是替 cursor 提异议，是记录完整性问题 |
| 两处措辞与计数事实 | 低优先级更正，供 ⑤（§六） |

## 二、Q1–Q4：无异议

处置表四条全部「接受」。落点逐条亲核（取件 ref：`runtime-refact/arbiter`）：

| 条目 | 落点（已亲核） | 核法与备注 |
| --- | --- | --- |
| Q1 抽象层 `resume()` 仍是 `NotImplementedError` | 裁决稿 §4.3「原语存在不等于端到端已接线」块（:370-382） | `git grep -n NotImplementedError runtime-refact/arbiter -- sunmoonai/docs/dev-plan/agent-dev-guide.md` 命中 :374、:382。与 C2 是同一发现、共用提交 `f6d248ab`；处置表分别记条（cursor 记 C2、qwen 记 Q1）——两份评审独立提出，双计有据 |
| Q2 权威文档地图短而清楚 | 裁决稿 §0.1 文档边界表 | `git diff runtime-refact/luna runtime-refact/arbiter -- sunmoonai/docs/dev-plan/agent-dev-guide.md`：§0.1 无任何改动——被夸的性质经基座进入最终稿。此项无独立吸收提交，由基座满足；如实记录，不构成异议 |
| Q3 覆盖声明如实披露不确定性 | 裁决稿 §9.2（:682-705：查了／没查／不能排除三档表 + 范本段） | 提交 `40794415`。范本段以「某轮一份产物」匿名引用本候选 §7 的披露，无失真 |
| Q4 结论措辞限定到「这台宿主、这个身份、这个时刻」 | 裁决稿 §4.4（:415） | 提交 `0390b874` |

对账事实一条（与 §六第 2 条相关）：`git log runtime-refact/arbiter --oneline` 里「③ 吸收」提交
共 12 个；Q1 落在 C2 的提交内、Q2 无需提交，处置表与提交记录对得上。

## 三、A-4：无异议，接受成立

裁决取证（三个粒度字段与 `H1`／`H8` 命中各 0）本会话在候选 commit 上复跑，同样零命中：

```bash
git grep -n -E "observability|enforcement|sandbox" 7d31265a -- sunmoonai/docs/dev-plan/agent-dev-guide.md
# 无命中
git grep -n -E "H1|H8" 7d31265a -- sunmoonai/docs/dev-plan/agent-dev-guide.md
# 无命中
```

且我 ② 评审已自查到同一件事：[review-qwen.md](review-qwen.md) 自报「J2 三处落点偏薄」
（R2.8 trace 读数、R4.2 五家取值表、R5.3 T0 复合上界——正文只有方法与要求、没有对应内容）
与 J3 4/6（:55-66）。A-4 与我自己的读数一致；② 时我自评第四的核心理由就是覆盖最薄。
无异议。

## 四、验收方计算：复核无误

从处置表逐行重数：`cursor` 接受 8（C1–C8）+ 不采纳 1（C9）；`kimi` 接受 2（K1/K2）+
部分接受 1（K3）+ 不采纳 1（K4）；`qwen` 接受 4；`luna` 接受 4 但按基座作者排除；
`opus` 按裁决方排除。余下三家最少者为 `kimi`（3），两项排除均与协议一致。
另核了一点：`K4` 的不采纳源于 A-2，而 A-3 没有对应的 C 行——**A-3 无论维持还是改判，
都不改变验收方人选**。这也是我把 §五 定性为「记录完整性问题」而非「异议」的原因之一。

## 五、A-3 独立复核结果：一处处置记录覆盖缺口

**边界先行**：A-3 的处置对象是 `cursor`，对它提异议的权利在 cursor，不在本文。本节是
[call-④.md](../call-④.md) 第一项点名要求的「独立复核而不是采信」的**复核结果**，按异议
四项形状书写，供裁决方处置异议、修正[处置记录](../disposition.md)与 ⑤ 验收时使用。
**若 cursor 本轮不提异议，本节不构成对 A-3 结论的自动推翻。**

| 项 | 内容 |
| --- | --- |
| 条目 | A-3（处置记录「二」表） |
| 为什么错（与什么事实冲突） | luna 的指控有**两个点**：① §5.1「人的 Attempt 无 checkpoint 义务」把人重新放回 Attempt；② §5.2 H5 的强制点是「人执行该动作」。A-3 的取证只覆盖了第 ② 点的实质与一条免责声明：它核的是「产物→状态机」表的注文（cursor:229「Side Effect 由人执行本地合并」——确属今天实际发生的物理动作描述）与 §4.1 免责声明（cursor:300）。**第 ① 点（cursor:373「人的 Attempt 无 checkpoint 义务……是它的 checkpoint」）在 A-3 里没有被处置。**而这一句与 kimi:342 近逐字相同——A-2 正是依同一句判 kimi 成立（「Attempt 是执行者跑的东西，给了人即违反 B4」）。kimi 稿有等价甚至更强的免责声明（kimi:23「人不是执行者，是 principal」、kimi:319「登记表没有任何条目以任何 kind 标人」）仍被判成立，故「登记表免责声明」不构成两案的区分理由。同一句式、相反裁定，记录里没有写出区分 |
| 应当是什么 | A-3 行应把 luna 指控的两点都处置掉：或给出 cursor:373 与 kimi:342 的实质差异（则推翻对两点都成立），或把 A-2 的理由延伸到 cursor:373（则该点成立）。裁决稿对两句均零命中（证据见下），两种改法都不动基座文本；受影响的只是处置记录的完整性，以及 luna 评审对 cursor 的 B4 计分口径是否与对 kimi 一致 |
| 可复跑证据 | 见下方四条命令 |

```bash
git grep -n "人的 Attempt" runtime-refact/cursor -- sunmoonai/docs/dev-plan/agent-dev-guide.md
# :373（§5.1 人与 agent 差异表「可跨会话续接」行，未处置的第 ① 点）
git grep -n "人的 Attempt" runtime-refact/kimi -- sunmoonai/docs/dev-plan/agent-dev-guide.md
# :342（A-2 判成立的同一句）
git grep -n -E "没有任何条目|人不是执行者" runtime-refact/kimi -- sunmoonai/docs/dev-plan/agent-dev-guide.md
# :23、:319（kimi 的等价免责声明——未能使它免责）
git grep -n -E "人的 Attempt|由人执行" runtime-refact/arbiter -- sunmoonai/docs/dev-plan/agent-dev-guide.md
# 无命中（裁决稿干净，两种改法都不动基座文本）
```

补充溯源：两句同出自 `refact-fable.md` 的「`kind = human` 四点差异」表
（`ed0b5136` 版 :315，原句以 human 开头）。在源稿里它属于「人是一种执行者」的旧设计，
语义自洽；搬进 B4 语境的新稿后，luna 读作旧错复活（其评审原话：「不能因为源稿曾写过就
继续保留」）。本文不裁定哪种读法对——那是裁决方的权力。本文只指出：**A-2 已经选了
luna 的读法，A-3 对同一句既没有给出另一种读法，也没有给出区分理由。**

## 六、两处低优先级事实更正（供 ⑤，不构成异议）

1. **「共识」措辞与事实不符。**处置记录「二」末行「A-3 是本轮唯一一处裁决方推翻**评审共识**
   的地方」，以及 call-④「裁决方推翻了**你们四家**的一处共识」。实测 B4 指控只出现在
   **luna 一家**的评审：对 kimi 与 cursor 的评审跑 `git grep -n "B4" runtime-refact/<家> --
   sunmoonai/docs/dev-plan/rounds/runtime-refact/reviews/review-<家>.md` 均无命中
   （cursor 评审唯一相关行 :45 是已证伪清单的转述，不是指控）；我自己的评审也无 B4 指控。
   A-3 推翻的是 luna 一家指控的一半，不是四家共识。⑤ 读记录时不宜把「共识被推翻」当作
   三家共识曾经存在的证据。
2. **吸收提交计数。**call-④ 称「吸收 11 条，一条主张一个提交」；
   `git log runtime-refact/arbiter --oneline` 实数 **12** 个「③ 吸收」提交（C1–C7、K1–K3、
   Q3、Q4 各一）。另有三项「接受」无独立提交：C8 落在 K2 的提交内（裁决稿 §7.4 第 4 行
   H5-final／H5-round 拆分）、Q1 落在 C2 的提交内、Q2 由基座 §0.1 满足。不影响处置表与
   验收方计算；对账时 11 与 12 对不上，如实登记。

## 覆盖声明

**查了**：`disposition.md` 全文（arbiter 分支版与工作区版 `git diff` 比对一致）；裁决稿全文
——经 `git diff runtime-refact/luna runtime-refact/arbiter -- sunmoonai/docs/dev-plan/agent-dev-guide.md`
逐块读完（即全部吸收差异），Q1/Q3/Q4 落点另以 git grep 核行号；`call-④.md`、`rulings.md`、
`arbiter-selfcheck.md`、`observations-opus.md`、`mechanical-results.md` 全文；cursor 候选全文；
kimi 候选的涉案段落（grep 命中行及上下文）；luna 候选全文（作为 diff 基准）；我自己的候选
（`7d31265a`）与 ② 评审；luna 评审全文（B4 指控两点的原文与出处）；`refact-fable.md` 涉案
源句（:315）；A-4 零命中复跑；验收方计算逐行重数。

**没查**：kimi 候选全文未通读（本异议只依赖其涉案段落）；A-1/A-1b 的取证未复跑（不涉我的
处置）；裁决稿 64 行落点表未逐行对照两份源稿——裁决方自检已声明只逐行核过 3 行，其余
61 行是 ⑤ 的验收范围，本异议不扩大它；kimi 与 cursor 的 ② 评审未重读全文（只跑了 B4
相关 grep——按「零命中要能区分『真的没有』与『没查到』」，该零命中的输入集合是整份评审
文件、枚举成功，故「无 B4 指控」是查到了，不是没查到）。

**未验证 ⚠**：本 worktree 的 merge 未完成（`agent-dev-guide.md` 处于未合并状态）——本文全部
结论只依赖分支 ref，不依赖工作区；A-3 复核是文本对照与记录完整性判定，不是对 cursor 是否
违反 B4 的实体裁定。
