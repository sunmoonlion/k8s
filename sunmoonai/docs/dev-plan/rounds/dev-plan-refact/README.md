# `dev-plan-refact` 轮

这一轮的全部东西都在这个目录。环节进行到哪，以 `round-status.py` 的输出为准，不看本目录。

## 组织者的文件

| 文件 | 是什么 |
| --- | --- |
| `round.md` | 工单；toml 块给脚本读 |
| `dev-plan-refact.md` | 任务书，第二版；第一版在 `superseded/` |
| `call-①.md` … `call-④.md` | 各环节通知 |
| `rulings.md` | 裁定 R1–R6 |
| `findings.md` | 本轮登记的发现，只追加不改 |
| `inventory.md` · `make-inventory.py` | 260 节清单，及生成它的脚本 |
| `inputs/` | 参考输入（原 `docs/ai-dev-readiness/`），不是标准答案 |
| `superseded/` | 被取代的任务书 |

## 参赛方的产物

权威在各家分支的提交上；`candidates/<家>/` 是逐字节取出的归档副本，`reviews/review-<家>.md` 是 ② 评审。
④ 异议交齐后也归档进 `reviews/`。

| 家 | 分支 commit | ①a `pipeline.md` | ①b `dev-plan-architecture.md` | ② 评审 |
| --- | --- | --- | --- | --- |
| **opus** | `84b18d27` | 387 行 `bc29ce3619cb` | 801 行 `f8b67fb2eb5b` | 283 行 `1cf204496d8a` |
| **luna** | `40f5fceb` | 213 行 `781dcc882b9f` | 733 行 `4d4349400d97` | 337 行 `f9eb975cdb53` |
| **kimi** | `9d6691e0` | 181 行 `1201d96a8115` | 569 行 `71d337c83d26` | 231 行 `0a7c88e58253` |
| **cursor** | `2cb62e08` | 426 行 `cb3020aff059` | 526 行 `e6833fa8541a` | 294 行 `8b7ed5c9a854` |
| **qwen** | `b0aaa400` | 173 行 `ff32c64fdb1f` | 465 行 `49fbbfccee9f` | 216 行 `6efcb3905635` |

③ 的裁决稿和处置记录在 `dev-plan-refact/cursor` 分支的 `1f2d0651`，只读检视面：`~/review/dev-plan-refact-③裁决稿/`。

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
