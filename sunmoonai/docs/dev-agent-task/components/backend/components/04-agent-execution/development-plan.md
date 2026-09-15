# 开发计划

> 迁自 `dev-plan/development-plan.md`（tag `dev-plan-final`） 的以下各节（`49d4ecb7`，2026-09-14）。节号沿用原文件；原文件其余各节的去向见 MIGRATION.md（2026-09-15 删除，原文见提交 `e7ab0e0b`）。

### 执行层租用，不自建

通用部分的执行层采用 Codex 的 Python SDK（`openai-codex`，Apache 2.0）：
不自建多方竞争生命周期、隔离进程、中断恢复、审批协议、工具与沙箱。

**依赖边界严格限定在 SDK，不得直接依赖其 app-server 裸协议。**依据实测：

| 层 | 近 3 个月提交 | 破坏性变更 |
| --- | --- | --- |
| `app-server-protocol`（裸协议） | 280 次 | 12 处 |
| `sdk/python`（门面） | **10 次** | **0** |

执行层须通过 Port 隔离——理由不是"将来可能要换"，而是：有该接口才能用 fake
执行器测试纪律层（隔离是否生效、吸收有没有留处置记录），否则每次测试都要真起
harness 并需凭据。

**harness 只给执行原语，不给运作纪律**：N 路隔离、多方竞争、中断恢复、审批、工具、
沙箱它有；三阶段可见性、提案包构造、评审协议、吸收处置记录、重叠分歧判据——
这些在 [`competition-protocol.md`](../../../../composition/protocol/competition-protocol.md)，必须自建。
