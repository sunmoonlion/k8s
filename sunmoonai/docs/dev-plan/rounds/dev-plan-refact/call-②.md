# ② 互评 ｜ `dev-plan-refact` 轮（第二版）

> 发出 2026-09-08 ｜ 起草：opus（受所有者指定代写；**opus 同为参赛方**，见 [`rulings.md`](rulings.md) R2）
> 题目与验收标准见 [`dev-plan-refact.md`](dev-plan-refact.md)，工单见 [`round.md`](round.md)。
> ⚠ **本通知在本环节冻结，不再改动。**

## 一句话

**读完其余四家的两份候选，写一份评审。四块，缺一块该评审不计入裁决。**

## ⚠ ① 的隔离到此解除

①期间不得读他家候选；**② 期间必须读全部**。你自己那份已经冻结在你的分支上，
现在读别人不影响你的候选——但**不得回头改自己的 ①**（改了即视为看过答案后重写）。

## 一、候选集冻结事实

⚠ 协议 §10 B：**少一份，你的评分作废。**下表是全集，五家十份。

| 家 | commit | 文件 | 行 | 字节 | sha256（前 16） |
| --- | --- | --- | --- | --- | --- |
| **opus** | `4810fa62` | `pipeline.md` | 387 | 23711 | `bc29ce3619cba262` |
| | | `dev-plan-architecture.md` | 801 | 68136 | `f8b67fb2eb5ba697` |
| **luna** | `9a2b999c` | `pipeline.md` | 213 | 22635 | `781dcc882b9fd80e` |
| | | `dev-plan-architecture.md` | 733 | 183574 | `4d4349400d971a6e` |
| **kimi** | `492458d2` | `pipeline.md` | 181 | 14810 | `1201d96a81155434` |
| | | `dev-plan-architecture.md` | 569 | 37516 | `71d337c83d269f10` |
| **cursor** | `8ed6348b` | `pipeline.md` | 426 | 28959 | `cb3020aff0593624` |
| | | `dev-plan-architecture.md` | 526 | 70939 | `e6833fa8541a502f` |
| **qwen** | `a7b0f104` | `pipeline.md` | 173 | 11837 | `ff32c64fdb1f7006` |
| | | `dev-plan-architecture.md` | 465 | 29098 | `49fbbfccee9fed8a` |

**自验这张表**（任一家跑，结果必须与上表逐字节一致）：

```bash
cd ~/master/k8s
for w in opus luna kimi cursor qwen; do
  for f in pipeline.md dev-plan-architecture.md; do
    printf '%-8s %-26s %5s 行  %s\n' "$w" "$f" \
      "$(git show "dev-plan-refact/${w}:sunmoonai/docs/dev-plan/${f}" | wc -l)" \
      "$(git show "dev-plan-refact/${w}:sunmoonai/docs/dev-plan/${f}" | sha256sum | cut -c1-16)"
  done
done
```

⚠ 对不上就**停下来说**，不要按自己看到的版本评——见 `GO.md` §5。

## 二、怎么取件

两条路，任选：

```bash
# A. 直接从分支读，不落盘（推荐；不占工作区，不会误改）
git show dev-plan-refact/luna:sunmoonai/docs/dev-plan/pipeline.md

# B. 检视面（已由组织者开好，只读）
ls ~/review/dev-plan-refact-*/sunmoonai/docs/dev-plan/pipeline.md
```

⚠ **不要 checkout 别人的分支**，那会把该家踢出它自己的 worktree（协议 §7.2）。
⚠ **不要往检视面里写。**

## 三、交什么

一份，落在**你自己分支**：

```
sunmoonai/docs/dev-plan/rounds/dev-plan-refact/reviews/review-<你的名字>.md
```

⚠ 文件名必须精确。2026-09-02 出过事故：一家用了别的名字，评审方按精确文件名枚举，
**漏掉一份，整轮评分作废重做**。不合命名的文件不进枚举，等同未交付。

**四块，缺一块该评审不计入裁决**（协议 §10）：

| 块 | 内容 |
| --- | --- |
| **A 自述** | 关于**你自己**的候选：①a 提出了什么流程结构、①b 怎么推导；哪些断言未验证（标 ⚠）；**放弃了哪些本可以写但故意没写的内容及理由**——这项能看出取舍是不是想过 |
| **B 候选集冻结** | 上表十份的路径、行数、字节数、sha256、commit。**少一份评分作废** |
| **C 评优** | 按 `dev-plan-refact.md` §6.1/§6.2 的 M1–M4、J1–J7 **逐条**给比较依据，对**全部五份（含你自己）**指出强项与缺陷，给完整排序及该选谁当基座的理由 |
| **D 值得吸收的点** | 不管你选谁当基座，逐条列出**其他候选里值得并进最终稿的具体主张**：出自谁、在哪一节、为什么值得。⚠ 这一块是裁决阶段最有用的输入 |

## 四、本轮评优的着力点

本轮 ①a 是新增的一件交付物，判据集中在这里。建议按 J1–J2 先筛：

| | 问什么 |
| --- | --- |
| **J1 完整性** | 阶段 / 门 / 文档类型 / 生命周期 / 判据归属 / AI 前提，六项是否各有答案。⚠ 缺一项就不是一套流程结构 |
| **J2 推导关系** | 文档类型是**从阶段推出来的**，还是并列另立的一套？⚠ 这是本轮作废重开的核心——先给分类再倒推流程按 §6.3 否决 |
| **J3–J5** | 归属判据是否先于结果；每份文档内部结构是否被论证（**不给理由的沿用等于没做**）；拆并是否给了代价 |
| **J6** | B2 锚点保全方案是否可执行 |
| **J7** | Q1/Q2/Q3/Q6/Q8/Q9 是否各有答案 |

⚠ **事实题用证据裁，不用票数裁**：多家说法一致但都没取证，输给一家带 `file:line` 的。

## 五、五条纪律

1. ⚠ **利益冲突必须声明。**你既是评优方又是候选作者，这不是独立终审。
   把自己排第一是允许的，但必须给出与评别家**同样标准**的比较依据。
2. ⚠ **不得回头改自己的 ① 候选。**
3. ⚠ **只写你自己的工作区。**
4. ⚠ 断言附可复跑证据或标 ⚠；不得写「我之前查过」。
5. ⚠ **卡住了就停下来说**（`GO.md` §5）——所有者开着窗口。

## 六、⚠ opus 的额外约束

本轮任务书、`inputs/` 四份参考、`inventory.md`、本通知**均由 opus 起草**，
而 opus 同为参赛方与评优方。评审时额外要求：

- opus 的 C 块**不得把「与任务书契合」当作给自己加分的理由**——任务书是它自己写的；
- opus 的 D 块必须**至少列出三条**来自其他候选、且自己那份没有的主张；
- 其余四家若认为任务书为 opus 量身定题，**在 C 块直说**，这属于本轮应当被记录的争议。

## 七、交卷

```bash
git add sunmoonai/docs/dev-plan/rounds/dev-plan-refact/reviews/review-<你的名字>.md
git commit -m "② dev-plan-refact 评审（<你的名字>）"
cd ~/master/k8s && python3 sunmoonai/docs/dev-plan/protocol/round-status.py
```

⚠ **提交后再跑一次状态脚本**，确认你那格变了。它认不出你的产物时，
你以为交了、其实没交——这种失败**不会有任何报错**。

⚠ **在 `~/master/k8s` 跑**。工作区无关性刚修复（`findings.md` F-13），
若你的工作区脚本还是旧版，判定会失真。

## 八、观察窗

`W` = 已交付各家用时的中位数。逾期记该家 Attempt `FAILED(timeout)`，**Task 不失败**。
