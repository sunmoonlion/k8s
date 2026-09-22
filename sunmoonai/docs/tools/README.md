# `tools/` —— 文档门禁与检查脚本

管全仓文档，不属于某一个任务。

| 文件 | 作用 | 怎么跑（在仓根） |
| --- | --- | --- |
| `doc-gate.py` | 检查 `sunmoonai/docs/` 下 markdown 的链接、表格、turn 形状与冻结区；`§N` 只对 `SELF_CONTAINED` 名单里的文档查，且只查**本文件内**有没有那个标题——**跨文件的 `§` 引用它看不见**，所以协议要求引用按标题 | `python3 sunmoonai/docs/tools/doc-gate.py --all`（钩子用 `--staged`） |
| `anchor-gate.py` | 检查 `文件.md:行` 与 `文件.md @ <提交>:行` 形式的锚点能否解析；行号支持 `40`、`23-29`、`454/458/461` 三种写法 | `python3 sunmoonai/docs/tools/anchor-gate.py` |
| `check-no-owner-creds.sh` | VM 上的凭据卫生检查：查有没有混进所有者的凭据。是卫生检查，不是边界 | `bash sunmoonai/docs/tools/check-no-owner-creds.sh` |

钩子在 `.githooks/`，装一次即对本仓全部 worktree 生效：`git config core.hooksPath .githooks`。**两个钩子都调 `doc-gate.py --staged` 和 `anchor-gate.py`**。
doc-gate 另查任务目录下的 turn：`thread/` 下正好两级（文档 thread、文档 turn），目录名合乎「四位本地号-种类-运行时 id」与「四位本地号-运行时 id」、编号连续不复用、PRD/SDD 两类有 `response.md` 而 IMP/UAT 两类没有（回执里记 worktree 与提交）、`user-message.md` 与 `turn.md` 的字段齐全合法、模块编号在同一个 `modules/` 里连续且 PRD 与 SDD 两侧一致，交回即冻结（提交与合并时查）。判据表见 [`../dev-human/naming.md`](../dev-human/naming.md)。
⚠ 钩子找不到脚本时**判失败**（原先是直接放行，门会静默失效）。移动或改名脚本时必须同步改两个钩子；确需绕过用 `git commit --no-verify`，并在提交说明里写清理由。
