# 裁定记录：refact-fable（开发框架重构方案）

> 本目录记录方案 `refact-fable.md` 自身的裁定。方案内 R0–R5 各自开轮，各有自己的 `rounds/<id>/rulings.md`。
> 字段按 `round-protocol.md`「裁定记录」。**人确认 = 是** 的行，以所有者 commit 为生效时刻；commit 前本文件是草稿。
> 冻结对象哈希：`refact-fable.md` sha256 前 16 位 `89303624bfd9ef27`（12:58 版，927 行）；commit 后可复算。

| 编号 | 事由 | 依据 | 处置 | 方向 | 人确认 | 影响到谁 |
| --- | --- | --- | --- | --- | --- | --- |
| `R1` | 冻结 `refact-fable.md` §8 九条验收标准、3.1.1 状态映射表、3.13 威胁模型（H1） | 五家终审全部同意冻结：`reviews/review-final-opus.md`「建议冻结 §8，但先改一处取证错误」（已改，3.13.0）；`reviews/review-final-cursor.md`「骨架可以冻」（F1–F3 已改）；`reviews/review-final-kimi.md`「同意冻结 §8」；`reviews/review-final-qoder.md`「条件通过」（C3 驳回有据，其余已吸收）；`reviews/review-final-luna.md` REQUEST CHANGES 于 12:49 撤销（终端记录：「12:40 版已落实全部阻断项，我撤销 REQUEST CHANGES，同意按 bootstrap 例外冻结 §8 九条并启动 R0 / S1」）。逐条处置见 `reviews/review-final-fable-response.md` | 三处进入 FROZEN；此后只能经 H6 改，改动追加于本文件不覆盖 | 更严谨 | **是** | 全部后续轮（R0、R0′、S1、R1–R5）；五家执行者 |
| `R2` | R1 的回执形态：回执仓尚未建成（S1 产物），本次冻结无法按 3.13 用回执仓签名回执 | 3.13.3 的回执仓与 §6 S1 互为前后：S1 要在 §8 冻结后跑，回执仓在 S1 里建。这是 §6 已登记的 `bootstrap` 情形 | 本次 H1 回执 = 本文件 R1 行 + 所有者 commit；S1 建成回执仓后，所有者补一份 `transitions: [H1]`、`target_commit` = 本 commit 的回执，把 bootstrap 例外收口 | **更省事**（回执弱于 3.13 标准） | **是** | 本方案自身；S1 验收加「补签 R1 回执」一项 |
| `R3` | T0 的 H1 与「开工前零触点」矛盾如何解（kimi D2 / qoder B2） | fable 11:52 提出四选一之外的第四种：T0 验收条只能来自已签策略，H1 在策略签名时一次完成 | 采纳第四种；12:40 版细化为命名任务类包（3.6）。所有者 11:56 裁定 | 更严谨 | **是** | T0 口径；策略文件 `policies/tier-defaults.toml` |
| `R4` | 私有仓 GitHub ruleset 需付费计划，签名回执信任锚选什么（kimi D1 / qoder B1） | GitHub 官方文档「About rulesets」：私有仓需 Pro / Team / Enterprise；已核 | 选「回执仓」：所有者名下独立仓，VM 只读。所有者 11:56 裁定；12:40 版按 luna C1 改为仓内签名 commit + yaml | 更严谨 | **是** | 3.13、S1、R1 |
| `R5` | H2/H3/H4/H6 回执是否全部改回执仓签名（cursor C1） | 3.3 规则三「回执必须不可伪造」主语是全表；`rulings.md` 在工作仓 agent 可写 | 全表锚定，H7「取消」为唯一例外（失败安全）。所有者 12:13 点头 | 更严谨 | **是** | 权力表全部行；签名次数观察值 |
| `R6` | T0「可逆出口」（免 H5）是否加入权力表（cursor D5） | 无签名次数数据；留在 worktree 的成果无状态，堆积后批量 push 即绕过 H5 | 本轮不加，登记 §7-13；S1/R1 后看两周观察值再定。所有者 12:13 点头 | 更严谨 | **是** | T0 |
| `R7` | 主仓写权限是否移出 VM（luna C2 / opus §3） | 3.13.1：VM `id_rsa` 对主仓可写，agent 可绕过回执直接 push；VM 上 hook 与脚本可改，不是强制点 | 移出：主仓对 VM 只读，agent 推候选仓，⑦ 由 Windows 在签 H5 同一会话执行。所有者 12:34 裁定「移」 | 更严谨 | **是** | 3.13.2 ②、3.13.5、S1 ②、H5 强制点 |
| `R8` | 往 `round-protocol.md` 补「机器可读块」是否算改协议（原 R0 旁注 / §7-12） | round-protocol「流程档位」：改协议命中权威层即 T2；按方向不对称，它朝严谨方向但仍是协议正文变更 | 算改协议，拆出 R0′ 按 T2 开轮；R0 只改脚本。所有者 12:34 裁定「要」 | 更严谨 | **是** | R0 范围；opus（R0 执行者） |
| `R9` | R1 所冻结的三处对象在 `runtime` 轮前提下重新处置 | 所有者 2026-09-05 指出「没有开发过程和产品运行时这两个 profile，只能有一个产品运行时」；`refact-fable.md` §1.1 杀第三个 Profile 的论证（「五格全同…那是档位不是 Profile」）对 A/B 同样成立；内核 `working/request-lifecycle.md:505`「新增领域应新增 Task Profile 和相容 Agent Profile，不修改通用状态语义」与 `:580` 反模式表 | §8：七条留、**第 7 条作废**、第 3 条改归因、第 4(c) 条扩为手工/运行时共用同一 schema；3.1.1 映射表**解冻重画**；3.13 威胁模型**留且升格为架构组件**。逐条见 `../runtime/task.md`「refact-fable.md §8 九条的处置」一节 | 混合：§8-7 作废朝**省事**，3.13 升格朝严谨 | **是** | `runtime` 轮全部参与方；R0–R5 路线（§5 目标文件树随 3.1.1 一起失效） |

## 备注

- **R9 已生效**（所有者签发）：收件箱条目 `../runtime/inbox-owner.md` 的 `I-01`。
  按本文件抬头的规则，人确认 = 是 的行才以所有者 commit 为生效时刻。
  R1 规定其冻结物「此后只能经 H6 改，**改动追加于本文件不覆盖**」——故 R9 是追加行，R1 原文一字未动。
- R3–R8 是当日会话中已做出、此前只记录在对话里的所有者裁定，此处**回填**为记录——按「未记录的裁定无效」，回填是让它们生效，不是追认。
- 本文件、`refact-fable.md`、`reviews/` 下九份评审与处置表应在**同一个所有者 commit** 里进 master。评审原文保留在 `reviews/`，
  理由：R1 的依据必须能独立成立，不能只剩方案作者的转述；上一轮 refact 也把全部提案与评审保留在 tag 里。
