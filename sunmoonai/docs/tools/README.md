# `tools/` —— 文档门禁与检查脚本

管全仓文档，不属于某一个任务。2026-09-15 从 `dev-plan/` 移来。

| 文件 | 作用 | 怎么跑（在仓根） |
| --- | --- | --- |
| `doc-gate.py` | 检查 `sunmoonai/docs/` 下 markdown 的链接与 `§` 引用；两个 git 钩子在提交和合并前调用它 | `python3 sunmoonai/docs/tools/doc-gate.py --all`（钩子用 `--staged`） |
| `task-status.py` | 从任务目录推出进度视图：每个 turn 待派、已派工、已交回、已通过、被打回…；只读不写 | `python3 sunmoonai/docs/tools/task-status.py`（`--json` 机器可读） |
| `anchor-gate.py` | 检查 `文件.md:行` 与 `文件.md @ <提交>:行` 形式的锚点能否解析 | `python3 sunmoonai/docs/tools/anchor-gate.py` |
| `check-no-owner-creds.sh` | VM 上的凭据卫生检查：查有没有混进所有者的凭据。是卫生检查，不是边界 | `bash sunmoonai/docs/tools/check-no-owner-creds.sh` |

钩子在 `.githooks/`，装一次即对本仓全部 worktree 生效：`git config core.hooksPath .githooks`。
doc-gate 另查任务目录下的 turn：编号连续、`user-message.md` 与 `turn.md` 的字段齐全合法（每次都查），交回即冻结（提交与合并时查）。
钩子找不到 `doc-gate.py` 时会直接放行，所以移动或改名这个脚本时必须同步改两个钩子。
