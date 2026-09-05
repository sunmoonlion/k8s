# 实施计划

> 最后更新：2026-08-29
>
> **这里是任务本体：每件事怎么做、怎么算做完。**
>
> 现在到哪了、什么不能倒退，见 [`handoff.md`](handoff.md)；
> 为什么这么建见 [`development-plan.md`](development-plan.md)；
> 代码必须符合的规则见 [`constraints.md`](constraints.md)。

## 任务条目格式

每条任务固定这几栏，**缺栏视为未定义，不开工**：

| 栏 | 写什么 |
| --- | --- |
| 类型/优先级 | `ARCH` / `FEAT` / `FIX` / `OPS` + `P0`–`P2` |
| 仓库 | 涉及哪几个仓——跨仓任务必须列全，否则漏推 |
| 前置 | 依赖哪些任务或哪条未决项定了才能开工 |
| 目标 | 一句话说清做完之后什么变了 |
| 实施 | 具体动什么。**不写"完善 X"这种没有终点的表述** |
| 测试 | 适用的测试层次（见下），**不能只写"补测试"** |
| 验收 | 可判定的条件。做完能一条条对着勾 |
| 回滚 | 出问题怎么退回去 |
| 状态 | `NOT_STARTED` / `IN_PROGRESS` / `BLOCKED` / `ACCEPTED` + 日期与证据 |

## 测试层次

```
L1 Unit                    L5 Failure Injection
L2 Component Integration   L6 Evaluation/Quality
L3 Contract                L7 Deployment/Operations
L4 Cross-app E2E
```

P0 / P1 任务必须写明适用层次。

## 交付规则

**分支与提交**——父仓不得出现悬空 gitlink（规则 T4）。五仓同步用
`~/five-repos-sync/sync-five-repos.sh`；它只推父仓，子仓的提交仍须自己推，
否则同步在拉取侧对齐子模块时报错。

**证据**——完成的任务在 `docs/evidence/<task-id>/` 留去敏后的：`result.md`、
测试输出、关键 request/response、migration revision、image digest。
**不得提交 token、Cookie、数据库密码或 API key。**

**单一权威**——架构语义以 [`development-plan.md`](development-plan.md) 为准，
本文件只描述执行增量、依赖与验收；API/Schema 以各仓 `contracts/` 发布物为准，
本文件里的字段只用于解释，不作为机器契约。
**发现重复且可能漂移的定义时，删副本改引用，禁止两处同步维护。**

## 阶段〇 · 开发框架自身的实施路线（R0–R5）

> 迁自 `refact-fable.md @ 7e8464c2` §6。**每轮一个工单，前置不可跳**；档位按 `round-protocol.md` 判据自判。
> 进度：R0 未做；R0′ 未开；**S1 进行中**（④⑤ 已完成，见 `rounds/_spike-sign/forensics.md`；①②③ 待所有者）；R1–R5 未开。
> ⚠ 取证给 S1 加了一条本表未写的前置：**所有者需要一个 agent 够不着的本地 shell**（Cursor / Qoder 均 Remote 连入 VM）。
> ⚠ H5 未区分「最终稿发布」与「轮内产物发布」，见 `rounds/runtime/runtime-disposition.md` §L.1。

每轮一个工单，前置不可跳。档位按 round-protocol 判据自判，**本路线不含任何降档**。

| # | 轮 | 档 | 产物 | 前置 | 机械验收判据 |
| --- | --- | --- | --- | --- | --- |
| R0 | 修 `protocol-v2` 的脚本↔协议不一致（命名、`--stage`、退出码）——**只改脚本，不改协议正文**。**由 opus 直接修，不走轮次** | **bootstrap** | 合并 `protocol-v2` | 无 | 新建空 `rounds/_smoke/` 按协议字面写 `round.md`，`round-status.py` 能解析且判 ① 未开始 |
| R0′ | 往 `round-protocol.md` 补「机器可读块」一节（`round.md` 的 toml 块进协议）。**所有者裁定 2026-09-05：这是改协议，按 T2 开轮**（§7-12 已决） | **T2** | `round-protocol.md` 一节 | R0 | 协议正文与 `round.md` 字段表一一对应；`round-status.py` 解析规则以协议为准，脚本单测覆盖每个字段 |
| S1 | **边界 spike**（`security-boundaries.md` §2）：① 建回执仓、建候选仓；② VM 换三把 key（候选仓读写、主仓只读、回执仓只读），撤销原 `id_rsa`；③ 所有者在 Windows 提交两份测试回执（`[H5]` 含 `acceptance`、`[H3]` 含 `ruling_sha256`），用带口令 key 推；④ 首版 `check-no-owner-creds.sh`；⑤ 按 `security-boundaries.md` §2.0 在宿主 shell 重跑取证 | **bootstrap**（可逆、可丢弃） | `rounds/_spike-sign/` 留痕 | **§8 判据已冻结**（冻结判据 ≠ 判据已满足——qoder C3 的循环不存在；3.13 随之冻结） | ⓪ 回执仓与候选仓建成，VM 身份对**主仓与回执仓** `git push --dry-run` 均被拒（配置导出留痕）；VM 身份对候选仓 push 成功；两份测试回执 `round-status.py` 判成立（签名 ∈ 在线公钥集、schema 合法、`acceptance` 集合完整 / `ruling_sha256` 匹配）；用 VM 上未登记的 key 签一份回执推候选仓再伪装路径，判不成立；`check-no-owner-creds.sh` 零命中；断网重跑判未确认且退出码为「查询失败」；取证栏每行附 `hostname; id; cat /proc/self/uid_map` 输出 |
| R1 | 权力表全表回执仓锚定 + 收件箱字段分级 + 回执内容门；`round-status.py` 读回执仓 yaml 并在线验签、状态推导输出边并按 `state-machine.toml` 校验；T0 两道门；`check-policy.py`；orchestrator 写 `events.jsonl` | **T2**（权威层、不可逆） | `authority.md`、`policies/tier-defaults.toml` 首版（所有者签 `policy/1`）、`policies/state-machine.toml`、`scripts/check-policy.py`、`scripts/gates/`、脚本改动 | R0、S1、原文 §3.1.1 映射表（已由 `runtime-architecture.md` §2.5 取代）冻结 | `round-status.py --round refact` 对历史轮次输出唯一状态机的词与合法边；对 S1 测试回执判 H5 / H3 成立、对缺 `acceptance` 或签名不在公钥集的回执判不成立；无回执的 `rulings.md` 裁定行被判不存在；伪造 T0 工单四种（包名不存在 / 自拼门禁列表 / 完工 diff 越出 paths / 引用一个 paths 覆盖 `constraints.md` 的包）各被拒绝，其中第四种在 `check-policy.py` 层就拒绝签策略；`intake_author` 兼 proposer 的配置被拒发 |
| R2 | 执行架构迁出（含 `human` kind 一小节，3.2） | T1（大搬家但方向无争议） | `executor-architecture.md`；agent 文相应节改为指针 | R0（**不依赖 R1**：S1/R1 受阻不阻塞本轮） | `doc-gate` 通过；§11.3 八条逐条可寻 |
| R3 | 登记表加 `principal` / `provider` / `runtime` / `model_family` / `roles_allowed`；分发前机械拦角色冲突（含 `intake_author`）；独立性折算首版进 `authority.md` | T1 | `agents.toml`、`round-dispatch.py` | R1 | 故意配置「裁决方兼提案方」，分发拒绝并给 reason；正常配置放行；折算表存在且 3.2 的示例（1 家独立带证 vs 3 家同 runtime 无证）按表算出前者胜；luna 与 kimi 按表落同一组 |
| R4 | 工单一般化为 Artifact + T0/T1 guard 表与必需产物表 + 三值路由 + `status` 改推导 | **T2** | `round-protocol.md` 改版、`policies/tier-defaults.toml`、脚本读 tier | R1、R3 | 用一个**可丢弃的小题目**（`automation-roadmap.md` §4.1 要求）分别跑一次 T0、T1；每次 H2 都有落账；脚本输出无一处非唯一状态机的词 |
| R5 | 两份 lifecycle 合并为 `lifecycle.md`；`request-lifecycle.md` 边界声明修订；13 文件引用清理；`doc-gate.py` 配置 | **T2** | `lifecycle.md`、`migration-map.md`、删两份旧文 | R1–R4 | 5.3 五条全部通过 |

调整说明：S1 是 luna 建议的 spike，插在 R1 前；R3（角色冲突检查）按 luna 建议前移到实跑 T0/T1 之前；
R4/R5 与 `automation-roadmap.md`「处理顺序」第 4、6 步一致。3.1.1 状态映射表是 R1 前置，因为权力表的转换列用的就是它的词。
qoder B1 说 R1 把文档重构扩成了基础设施改造——扩的部分只有「建一个仓 + 配一把只读 key」，且 R2 不等它；
但「把签名回执降为可选」不采纳：⑥ 不可机械判是 1.4 的核心诊断，去掉它，本方案只剩文档搬家。

**`bootstrap` 档**（cursor C3）：R0 与 S1 不适用 §2.1 的 T0 定义——T0 要求验收条引用已签策略里的包，而策略首版是 R1 的产物，
S1 的验收条（回执仓建成、越权被拒……）不可能在尚不存在的策略里。它们的验收条就是本表「机械验收判据」列，
效力来自本文被所有者按 §8 冻结，不来自 `policy/1`。`bootstrap` 只用于这两行，之后不再出现；R1 起全部按 T0/T1/T2 自判。
qoder C3 说「所有者凭什么在 S1 前冻结 §8」——这把**冻结判据**与**判据已满足**混为一谈：先冻结验收标准再干活正是 H1 的定义，
S1 的产出是 §8 第 6 条的实证材料，不是冻结 §8 的前提。opus 4.2 说「新增档位说明档位判据偏紧」有道理，但判据在 round-protocol，是它的 T2，登记 §7-14。
原 R0 旁注（协议补「机器可读块」是否算改协议）**所有者已裁定**：算，按 T2 开轮，即 R0′。

---

## 阶段一 · 前后端对接

### 任务清单

**空。**U1（web 面生产适配器的形状）未定——薄转发还是自持投影，决定了要写
什么、测什么、有没有迁移。现在列出来的任何任务都会作废。

U1 一定，本节即刻填充。U1 的已知输入见 [`handoff.md`](handoff.md)。

## 阶段二 · agent 开发

未开工。见 [`development-plan.md`](development-plan.md)。

## 阶段三 · 结构化数据问答

未开工，且有一个开工前置：投资仓现在没有任何业务数据表。
见 [`development-plan.md`](development-plan.md)。
