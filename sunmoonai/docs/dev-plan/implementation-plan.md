# 实施计划（已迁出）

> **2026-09-14 已迁出**：本文件按 [MIGRATION.md](../dev-agent-task/MIGRATION.md) 把以下内容迁走——
>
> - [`dev-agent-task/components/backend/components/06-acceptance-commit/implementation-plan.md`](../dev-agent-task/components/backend/components/06-acceptance-commit/implementation-plan.md)（1 节）
> - [`dev-agent-task/composition/implementation-plan.md`](../dev-agent-task/composition/implementation-plan.md)（7 节）
> - 第 2 步：「任务条目格式」写进 [`dev-agent-standards/deliverables/sdp`](../dev-agent-standards/deliverables/sdp/sdp-rules.md)
>
> 这里仅剩：历史记录与留在原处的节。节号是原文件的节号。

## 阶段〇 · 开发框架自身的实施路线（R0–R5）

> 迁自 `refact-fable.md @ 7e8464c2` §6。**每轮一个工单，前置不可跳**；档位按 `round-protocol.md` 判据自判。
> 进度与卡点见 [`handoff.md`](handoff.md)（分工：状态叙述不写在本文件）。
> ⚠ 取证给 S1 加了一条本表未写的前置：**所有者需要一个 agent 够不着的本地 shell**（Cursor / Qoder 均 Remote 连入 VM）。
> ⚠ H5 未区分「最终稿发布」与「轮内产物发布」，见 `rounds/runtime/runtime-disposition.md` §L.1。

每轮一个工单，前置不可跳。档位按 round-protocol 判据自判，**本路线不含任何降档**。

| # | 轮 | 档 | 产物 | 前置 | 机械验收判据 |
| --- | --- | --- | --- | --- | --- |
| R0 | 修 `protocol-v2` 的脚本↔协议不一致（命名、`--stage`、退出码）——**只改脚本，不改协议正文**。**由 opus 直接修，不走轮次** | **bootstrap** | 合并 `protocol-v2` | 无 | 新建空 `rounds/_smoke/` 按协议字面写 `round.md`，`round-status.py` 能解析且判 ① 未开始 |
| R0′ | 往 `round-protocol.md` 补「机器可读块」一节（`round.md` 的 toml 块进协议）。**所有者裁定 2026-09-05：这是改协议，按 T2 开轮**（§7-12 已决） | **T2** | `round-protocol.md` 一节 | R0 | 协议正文与 `round.md` 字段表一一对应；`round-status.py` 解析规则以协议为准，脚本单测覆盖每个字段 |
| S1 | **边界 spike**（`runtime-architecture.md` §4.4「三道边界」与 §4.6「principal 通道」）：① 建回执仓、建候选仓；② VM 换三把 key（候选仓读写、主仓只读、回执仓只读），撤销原 `id_rsa`；③ 所有者在 Windows 提交两份测试回执（`[H5]` 含 `acceptance`、`[H3]` 含 `ruling_sha256`），用带口令 key 推；④ 首版 `check-no-owner-creds.sh`；⑤ 按 `runtime-architecture.md` §4.7「取证纪律与当前事实」在宿主 shell 重跑取证 | **bootstrap**（可逆、可丢弃） | `rounds/_spike-sign/` 留痕 | **§8 判据已冻结**（冻结判据 ≠ 判据已满足——qoder C3 的循环不存在；`runtime-architecture.md` §4.4 随之冻结） | ⓪ 回执仓与候选仓建成，VM 身份对**主仓与回执仓** `git push --dry-run` 均被拒（配置导出留痕）；VM 身份对候选仓 push 成功；两份测试回执 `round-status.py` 判成立（签名 ∈ 在线公钥集、schema 合法、`acceptance` 集合完整 / `ruling_sha256` 匹配）；用 VM 上未登记的 key 签一份回执推候选仓再伪装路径，判不成立；`check-no-owner-creds.sh` 零命中；断网重跑判未确认且退出码为「查询失败」；取证栏每行附 `hostname; id; cat /proc/self/uid_map` 输出 |
| R1 | 权力表全表回执仓锚定 + 收件箱字段分级 + 回执内容门；`round-status.py` 读回执仓 yaml 并在线验签、状态推导输出边并按 `state-machine.toml` 校验；T0 两道门；`check-policy.py`；orchestrator 写 `events.jsonl` | **T2**（权威层、不可逆） | `authority.md`、`policies/tier-defaults.toml` 首版（所有者签 `policy/1`）、`policies/state-machine.toml`、`scripts/check-policy.py`、`scripts/gates/`、脚本改动 | R0、S1、原文 §3.1.1 映射表（已由 `runtime-architecture.md` §2.5 取代）冻结 | `round-status.py --round refact` 对历史轮次输出唯一状态机的词与合法边；对 S1 测试回执判 H5 / H3 成立、对缺 `acceptance` 或签名不在公钥集的回执判不成立；无回执的 `rulings.md` 裁定行被判不存在；伪造 T0 工单四种（包名不存在 / 自拼门禁列表 / 完工 diff 越出 paths / 引用一个 paths 覆盖 `constraints.md` 的包）各被拒绝，其中第四种在 `check-policy.py` 层就拒绝签策略；`intake_author` 兼 proposer 的配置被拒发 |
| R2 | 执行架构迁出（含 `human` kind 一小节，3.2） | T1（大搬家但方向无争议） | `executor-architecture.md`；agent 文相应节改为指针 | R0（**不依赖 R1**：S1/R1 受阻不阻塞本轮） | `doc-gate` 通过；§11.3 八条逐条可寻 |
| R3 | 登记表加 `principal` / `provider` / `runtime` / `model_family` / `roles_allowed`；判定前机械拦角色冲突（含 `intake_author`）；独立性折算首版进 `authority.md` | T1 | 各轮 `round.md`、`round-status.py`（原列 `agents.toml`、`round-dispatch.py`，均已于 2026-09-10 删除；登记改由各轮 `round.md` 承担，角色检查在 `role_checks()`） | R1 | 故意配置「裁决方兼提案方」，判定拒绝并给 reason；正常配置放行；折算表存在且 3.2 的示例（1 家独立带证 vs 3 家同 runtime 无证）按表算出前者胜；luna 与 kimi 按表落同一组 |
| R4 | 工单一般化为 Artifact + T0/T1 guard 表与必需产物表 + 三值路由 + `status` 改推导 | **T2** | `round-protocol.md` 改版、`policies/tier-defaults.toml`、脚本读 tier | R1、R3 | 用一个**可丢弃的小题目**（`automation-roadmap.md` §4.1 要求）分别跑一次 T0、T1；每次 H2 都有落账；脚本输出无一处非唯一状态机的词 |
| R5 | 两份 lifecycle 合并为 `lifecycle.md`；`request-lifecycle.md` 边界声明修订；13 文件引用清理；`doc-gate.py` 配置 | **T2** | `lifecycle.md`、`migration-map.md`、删两份旧文 | R1–R4 | 5.3 五条全部通过 |

> 本表的调整说明与 `bootstrap` 档的效力来源属架构论证，见 `runtime-architecture.md`
> 与 `rounds/refact-fable/rulings.md`；按 `README.md` 分工不写在本文件。
---
