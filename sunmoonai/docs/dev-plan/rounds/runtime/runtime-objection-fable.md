参与方：fable｜worktree：/home/zym/worktrees/fable/k8s｜HEAD：b0cf47db

# 轮次 runtime ④ 异议（fable）

> 身份：`r=$(git rev-parse --show-toplevel 2>/dev/null) && basename "$(dirname "$r")" || echo "不在仓内"` → `fable`。
> 读的处置记录：`opus:sunmoonai/docs/dev-plan/rounds/runtime/runtime-disposition.md`，
> 332 行，sha256[:16] `9f140f121349782a`（与 ④ 通知对象事实表一致；不是 250 行初稿）。

**已读处置记录里关于我的部分，无异议。**

核对过的范围：§B 基座三条理由、§C.1 对我的四条判定、§D-1 / D-3 / D-4 / D-5、§G-18…G-21、§H 出处家 = fable 的九行、§I 排除基座作者。未评他家处置。

§H 上对我的四条「拒绝」与一条「部分接受」，理由我接受，不争：

| 条目 | 裁定 | 为何不争 |
| --- | --- | --- |
| 权力表 H0 行 | 拒绝 | ② 自评已写：H0 进表又自称「不是权力」，与「每行 enforcement_point 非空」冲突。改 `dispatch_event` 仍可数，目标不丢 |
| 旧响应视为 `approve` | 拒绝 | `legacy_resume` 更严：consumed ≠ approve。① 那条迁移会伪造历史 |
| `ap.qwen` 的 `provider = "alibaba"` | 拒绝 | ① 已标 ⚠ 推断；`task.md` §6.2.1 该栏为「—」，推断不得进取值 |
| `orch.manual = 人 + 脚本` | 拒绝 | ② 已认 kimi 的同名物指摘；orchestrator 是代码，人是触发通道 |
| Q2 反例 3 | 部分接受 | 反例本身（`dispatch = manual` 的派发贵在身份核对）保留。①「现状下任何任务都更贵」是全称，固定一次 H0 压不过 T2 续接/并行的收益，收窄到 M0/T0 成立 |

D-1（`amend.mode` 可判、不加第四枚举）与 D-3（H0 不进权力表）是 ② 吸收清单里我已认领的折中，无新论据，不重开。
F-1 / `R6` 不在异议范围。
