# `dev-plan-refact` 轮 · 该轮全部 artifact

> **一轮的东西全在这一个目录下。**参赛方的产物按家分目录，组织者的产物平铺在根下。
>
> ⚠ **`candidates/` 是归档副本，权威是各家分支上的 commit。**
> 副本用 `git show <分支>:<路径>` 逐字节取出，落盘时已逐份对拍一致（见下表 sha256）。
> 环节判定一律以 `round-status.py` 为准，不看本目录。

## 参赛方产物

| 家 | 分支 commit | ①a `pipeline.md` | ①b `dev-plan-architecture.md` | ② `review-<家>.md` |
| --- | --- | --- | --- | --- |
| **opus** | `84b18d27` | 387 行 `bc29ce3619cb` | 801 行 `f8b67fb2eb5b` | 283 行 `1cf204496d8a` |
| **luna** | `9a2b999c` | 213 行 `781dcc882b9f` | 733 行 `4d4349400d97` | ⬜ 未交 |
| **kimi** | `9d6691e0` | 181 行 `1201d96a8115` | 569 行 `71d337c83d26` | 231 行 `0a7c88e58253` |
| **cursor** | `2cb62e08` | 426 行 `cb3020aff059` | 526 行 `e6833fa8541a` | 294 行 `8b7ed5c9a854` |
| **qwen** | `b0aaa400` | 173 行 `ff32c64fdb1f` | 465 行 `49fbbfccee9f` | 216 行 `6efcb3905635` |

## 组织者产物

| 文件 | 是什么 |
| --- | --- |
| `round.md` | 工单：档位、参与方、最终路径、机械缺席条 |
| `dev-plan-refact.md` | 任务书（第二版）。⚠ 第一版在 `superseded/` |
| `call-①.md` · `call-②.md` | 环节通知，各自在本环节冻结 |
| `rulings.md` | 裁定：R1 作废重开 · R2 起草者即参赛方 · R3 供给留痕 |
| `findings.md` | 本轮登记的发现 F-1 … F-13 |
| `inventory.md` | 260 节清单（脚本生成，五家共用输入） |
| `make-inventory.py` | 生成上表的脚本 |
| `inputs/` | 参考输入（原 `docs/ai-dev-readiness/`，⚠ 非基准） |
| `superseded/` | 被取代的任务书 |

## 为什么补这个目录

`runtime` 轮把候选、评审、异议、验收全部归档在 `rounds/runtime/reviews/` 下——**那是对的**。
`runtime-refact` 轮的 `reviews/` 是空的；本轮此前 ① 候选只活在各家分支、② 评审在轮目录，
**分散两处**。所有者 2026-09-08 指出：**每个参赛方每轮的 artifact 应该放在该轮下面。**

`final_path` 是候选**活着时**的位置（为了能成为主线文件）；本目录是它**归档**的位置。
两者不冲突，但归档此前只在 ⑦ 做，且做漏过一次——所以本轮改为**产物一交齐就归档**。

重建本目录的 `candidates/`：

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

⚠ `${w}` 的花括号不能省——裸 `$w:` 会被 zsh 当成 `:s` 修饰符吃掉路径。
