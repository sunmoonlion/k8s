# `dev-plan-refact` 轮

这一轮的全部东西都在这个目录。**本轮已结束（⑦）**，定稿在 `sunmoonai/docs/dev-plan/pipeline.md` 与 `dev-plan-architecture.md`。

## 组织者的文件

| 文件 | 是什么 |
| --- | --- |
| `round.md` | 工单；toml 块给脚本读 |
| `dev-plan-refact.md` | 任务书，第二版；第一版在 `superseded/` |
| `call-①.md` … `call-④b.md` | 各环节通知 |
| `rulings.md` | 裁定 R1–R8，及「人确认登记」表 |
| `findings.md` | 本轮登记的发现，只追加不改 |
| `inventory.md` · `make-inventory.py` | 260 节清单，及生成它的脚本 |
| `disposition.md` · `disposition-objections.md` | ③ 处置记录与 ④b 异议处置（裁决方 `cursor`，从其分支逐字节归档） |
| `inputs/` | 参考输入（原 `docs/ai-dev-readiness/`），不是标准答案 |
| `superseded/` | 被取代的任务书 |

## 参赛方的产物

权威在各家分支的提交上（留底标签见 `round.md`「结束」）；`candidates/<家>/` 是逐字节取出的归档副本。
`reviews/` 里是 ② 评审 `review-<家>.md`、④ 异议 `objection-<家>.md` 与 ⑤ 验收 `acceptance-opus.md`。

| 家 | 分支 commit | ①a `pipeline.md` | ①b `dev-plan-architecture.md` | ② 评审 |
| --- | --- | --- | --- | --- |
| **opus** | `84b18d27` | 387 行 `bc29ce3619cb` | 801 行 `f8b67fb2eb5b` | 283 行 `1cf204496d8a` |
| **luna** | `40f5fceb` | 213 行 `781dcc882b9f` | 733 行 `4d4349400d97` | 337 行 `f9eb975cdb53` |
| **kimi** | `9d6691e0` | 181 行 `1201d96a8115` | 569 行 `71d337c83d26` | 231 行 `0a7c88e58253` |
| **cursor** | `2cb62e08` | 426 行 `cb3020aff059` | 526 行 `e6833fa8541a` | 294 行 `8b7ed5c9a854` |
| **qwen** | `b0aaa400` | 173 行 `ff32c64fdb1f` | 465 行 `49fbbfccee9f` | 216 行 `6efcb3905635` |

③ 与 ④b 之后的定稿在标签 `dev-plan-refact/arbiter-final`（`3e093ede`）；发布版另按 R8 修正了 `I08-009`。

## 重建 `candidates/`

```bash
cd ~/master/k8s
P=sunmoonai/docs/dev-plan/rounds/dev-plan-refact
for w in opus luna kimi cursor qwen; do
  mkdir -p "$P/candidates/${w}"
  for f in pipeline.md dev-plan-architecture.md; do
    git show "dev-plan-refact/${w}:sunmoonai/docs/dev-plan/${f}" > "$P/candidates/${w}/${f}"
  done
done
```

`${w}` 的花括号不能省：zsh 会把裸 `$w:` 当成修饰符，吃掉后面的路径。

## 本轮之后的遗留事项

本轮进行中和结束后撞到的改进项，统一记在这里。**状态以本表为准。**
「改规则」一类须所有者拍板，建议合成下一轮的题目。

| # | 事项 | 来源 | 状态 |
| --- | --- | --- | --- |
| 1 | ③ 定稿、处置记录、异议处置、验收稿归档进本轮目录 | 所有者 2026-09-10「检视面一定是脚本类这些吗」 | 已做（⑦，`d8caf018`） |
| 2 | 拆掉 `~/review/` 下的整仓检视面，删除 `protocol/round-review.py` | 同上 | 已做（`b3e93b27`） |
| 3 | 本轮 README 与任务书第 310 行的相关引用 | 同上 | 已做（⑦ 与 `b3e93b27`；任务书只加注） |
| 4 | `round-status.py` 判 ⑥ 先读主线的 `rulings.md` | `findings.md` F-25 第 1 条 | 已做（`233f2abd`） |
| 5 | ① 认目录式候选归档 `candidates/<家>/` | `findings.md` F-26 | 已做（`5a41eefd`） |
| 6 | `--verify` 的处置对账同时读 `disposition-objections.md` | `findings.md` F-25 第 2 条 | 已做（`411c0187`） |
| 7 | 协议 §7.2 / §7.3：检视面由「开临时 worktree」改为「读轮目录归档」；规则改为「已交产物归档进轮目录，在制品仍不复制进主线」；⑥ 前「必须开好检视面」改为「必须已归档」 | 所有者 2026-09-10，同第 1 项 | **待做，改规则，待所有者拍板** |
| 8 | 以后各环节的取件位置一律指向轮目录归档 | 同上 | 待做（随第 7 项） |
| 9 | 环节通知不再临时手写：每个环节交什么、交到哪、按什么判、规则见哪一节，只在协议里写一处，由 `round-status.py` 在打印当前环节时一并打印；`call-*.md` 改为可选，只在有判断要补充时才写 | 所有者 2026-09-10「这种 call 是不是都要临机写」 | **待做，改规则** |
| 10 | 新规范下通知基本不再需要，协议里不再设「通知代写方」；与 §6.1「裁决方即参赛方时由发起人写」合并改 | 所有者 2026-09-10「通知不是写进协议，基本不再需要通知了吗，所以也就不需代写方」 | **待做，改规则**（随第 9 项） |
| 11 | 定稿 `dev-plan-architecture.md` 内置的 `verify` 要求工作区源文件与冻结输入相同，发布进主线后在仓根跑必失败；改工具（按冻结提交读源文件）还是改文中说明 | `findings.md` F-25 第 3 条 | **待做，要改已发布定稿，走一轮** |
