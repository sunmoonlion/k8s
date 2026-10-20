# `process/` 目录（2026-10-21 前是 `dev-investment-agent/` 的过程部分）

**事情怎么做：一次求助怎么走完九站、一问一答怎么定稿、活怎么派给两台机器上的助手、提交前过哪些门禁。**
项目要建什么、设计成什么样在 [`../design/`](../design/README.md)；给所有者看的运维说明在 [`../ops/`](../ops/README.md)。

| | 是什么 |
| --- | --- |
| [`pipeline.md`](pipeline.md) | **主干**：九站、每一站现在谁做（人还是脚本）、走完的判据 |
| [`turn/`](turn/README.md) | **一次一问一答怎么走完**：问什么、怎么答、怎么定稿、怎么验、谁批、派几家；跨项目通用 |
| [`switch-test/`](switch-test/README.md) | **派活与同步**：远程写、本地跑的约定，每个助手一个收件箱 `inbox/<名>/`，做完归 `done/`；回执落 `scripts/results/` |
| [`tools/`](tools/README.md) | 门禁与整理脚本：`doc-gate.py`、`anchor-gate.py`（由 `.githooks/` 在提交与合并前调用）、`check-links.py`、`relocate-links.py` |
| [`rename-2026-10-15/`](rename-2026-10-15/README.md) | 10-15 那次改名（investment → knowbench 等）的手册、回执与工具，已完成，只作取证 |

`turn/` 与 `pipeline.md` 的九站**本身不绑定投资**——换个项目、换个领域，规矩照样成立。别的项目要用就复制一份过去；⚠ 复制即分叉，两份各自演进，不再互为真源，不要跨目录引用。
