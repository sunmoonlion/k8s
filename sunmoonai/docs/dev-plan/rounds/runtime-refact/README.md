# `runtime-refact` 轮 · 该轮全部 artifact

> **补建于 2026-09-08**（该轮 `status = DONE`，⑦ 已发布）。
> 起因：本轮 `dev-plan-refact` 讨论中查出 —— 协议 §16 ⑦ 写「各提案方候选：删除。
> **内容在各自分支的提交里，git 历史可取**」，而实际做法**回收分支**。
> `refact` 轮已因此**永久丢失候选**（其轮目录只剩一个 `round.md`，分支 0 条）。
> 本轮的候选与 ② 评审当时**只在分支上**，是下一个会丢的。
>
> ⚠ **`candidates/` 与 `reviews/review-*.md` 是归档副本，权威是各 ref 上的 commit。**
> 每份落盘时逐份 sha256 对拍一致。

## ① 候选（四家 + 裁决稿）

⚠ 该轮 `final_path` 是 `agent-dev-guide.md`，各家候选即各自分支上的那一份。
主线现在那份是**整合后的定稿（3082 行）**，与任何一家候选都不同。

| 家 | 源 ref | 行 | 归档为 |
| --- | --- | --- | --- |
| luna | `runtime-refact/luna` | 648 | `candidates/candidate-luna.md` |
| kimi | `runtime-refact/kimi` | 917 | `candidates/candidate-kimi.md` |
| cursor | `runtime-refact/cursor` | 921 | `candidates/candidate-cursor.md` |
| qwen | `runtime-refact/qwen` | 187 | `candidates/candidate-qwen.md` |
| **arbiter** | `runtime-refact/arbiter` | 808 | `candidates/arbiter-draft.md`（③ 裁决稿） |

⚠ **`luna` 那份的 blob 在 master 历史里能命中 1 次**（它是被选中的基座，已整合进主线）；
**`kimi` / `cursor` / `qwen` 三份在 master 历史里命中 0 次——它们此前只存在于分支上。**

## ② 评审

⚠ **这四份此前只在裸家名分支 `luna` / `kimi` / `cursor` / `qwen` 上**，
master 历史里从未有过（`git log --diff-filter=A master -- .../reviews/review-*.md` 为空）。
裸家名分支比轮次分支更容易被当成陈旧分支清掉，风险更高。

| 家 | 源 ref | 行 | 归档为 |
| --- | --- | --- | --- |
| luna | `luna` | 210 | `reviews/review-luna.md` |
| kimi | `kimi` | 169 | `reviews/review-kimi.md` |
| cursor | `cursor` | 333 | `reviews/review-cursor.md` |
| qwen | `qwen` | 270 | `reviews/review-qwen.md` |

## ④ 异议 与 ⑤ 验收：**不需要归档**

这六份在 **master 自己的历史里可达**（⑦ 清理时删除，但提交还在），故不复制：

| 产物 | 取件命令 |
| --- | --- |
| `objection-{luna,kimi,cursor,qwen}.md` | `git log --diff-filter=A --name-only master -- '<本目录>/reviews/objection-*.md'` 找到 commit 后 `git show <commit>:<路径>` |
| `acceptance-kimi.md` · `acceptance-kimi-2.md` | 同上 |

⚠ **这正是协议 §16 那句「git 历史可取」成立的情形**——
它对**主线上出现过**的产物成立，对**只在分支上**的产物不成立。
`refact` 轮丢失、本轮四家候选与四份评审曾处于险境，都是后一种。

## 组织者产物（本来就在主线，未动）

`round.md` · `runtime-refact-task.md` · `call-①/②/④/⑤/⑤b.md` ·
`disposition.md` · `disposition-objections.md` · `arbiter-selfcheck.md` ·
`mechanical-results.md` · `check-mechanical.py` · `observations-opus.md` · `rulings.md`

## 复核

```bash
cd ~/master/k8s
R=sunmoonai/docs/dev-plan/rounds/runtime-refact
P=sunmoonai/docs/dev-plan/agent-dev-guide.md
for w in luna kimi cursor qwen; do
  printf '%-8s 候选 %s / %s   评审 %s / %s\n' "$w" \
    "$(git show "runtime-refact/${w}:${P}" | sha256sum | cut -c1-12)" \
    "$(sha256sum "$R/candidates/candidate-${w}.md" | cut -c1-12)" \
    "$(git show "${w}:${R}/reviews/review-${w}.md" | sha256sum | cut -c1-12)" \
    "$(sha256sum "$R/reviews/review-${w}.md" | cut -c1-12)"
done
```

⚠ `${w}` 的花括号不能省——裸 `$w:` 会被 zsh 当成 `:s` 修饰符吃掉路径。
