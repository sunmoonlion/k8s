# 交接（已迁出）

> **2026-09-14 已迁出**：本文件按 [MIGRATION.md](../dev-agent-task/MIGRATION.md) 把以下内容迁走——
>
> - [`dev-agent-task/components/backend/composition/handoff.md`](../dev-agent-task/components/backend/composition/handoff.md)（1 节）
> - [`dev-agent-task/composition/handoff.md`](../dev-agent-task/composition/handoff.md)（10 节）
>
> 这里仅剩：历史记录与留在原处的节。节号是原文件的节号。

## 开发框架自身（R0–R5 路线）的进度

> 路线表在 [`implementation-plan.md`](implementation-plan.md)「阶段〇」；本节只记**状态**。
> 最后更新：2026-09-05。

| 轮 | 状态 |
| --- | --- |
| R0 修脚本↔协议不一致 + 合并 `protocol-v2` | **已做**（2026-09-06）。主线 `round-protocol.md` = 七环节版；三个脚本进主线；四处脚本↔协议不一致已修（产物路径、调用方式、退出码、已完成轮次被判成刚开始）。判据与结果见 `rounds/_r0/criteria.md`。产出方 = 验收方（所有者 2026-09-06 裁定不追加外部复验：判据 C1–C9 全是可复跑命令） |
| R0′ 协议补机器可读块 | 未开（所有者已裁定按 T2） |
| **S1 边界 spike** | **进行中**。④ `check-no-owner-creds.sh` 与 ⑤ 宿主取证已完成（`rounds/_spike-sign/forensics.md`）；①②③ 待所有者 |
| R1–R5 | 未开 |

**S1 的两条卡点**：

1. ⚠ **一条路线表未写的前置**：所有者需要**一个 agent 够不着的本地 shell**。
   Cursor 与 Qoder 均 Remote 连入本 VM，其中的终端就是 VM 的 shell——
   在那里签名等于把私钥放在 agent 能 `sudo` 读到的地方。见 `rounds/runtime/rulings.md` `R2`。
2. ⚠ 宿主取证发现 `zym` 有免密 sudo 且在 docker 组，**本机一切本地强制点对 agent 无效**；
   只有托管方的 key 作用域有效。这使 S1 的 ② 成为唯一真正有效力的一步。

## 已完成的轮次

| 轮 | 结果 |
| --- | --- |
| `refact` | 已发布，最终稿 `archive/development-lifecycle-agent.md`（2026-09-07 归档）。其 118 节已于 2026-09-07 吸收进 `agent-dev-guide.md` §10。⚠ `refact-fable` §5.2 承诺的逐节映射表 `migration-map.md` **从未产出**，该欠账至今只清到标题级 |
| `refact-fable` | 已发布；其架构结论（两个 Profile）后被 `runtime` 轮推翻，原文已迁出并删除，内容在 `7e8464c2` 与 `rounds/refact-fable/` |
| `runtime` | 已发布，最终稿曾为 `runtime-architecture.md`；其 33 节已由 `runtime-refact` 轮全部落点到 `agent-dev-guide.md` §10，原文 2026-09-07 归档至 [`archive/`](archive/)。裁决方自陈错误十二条，六条由参与方抓出、三条由所有者抓出 |
| `_fixups` | 进行中：追认 `runtime` 发布后四次未走流程的改动，验收方 cursor |
