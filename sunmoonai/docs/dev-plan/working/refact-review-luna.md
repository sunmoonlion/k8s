# refact 环节 ② 互评 · luna

评审日期：2026-09-04。本文只评冻结提交中的候选，不读取各 worktree 的活动文件；基座为
`3555ad7ebdf4027d6ebcee1ea2ad534ab2775aa1` 中的
`sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md`。

## A. 自述

### A.1 我改了什么

我的候选 `luna` 在基座上做了这些增量：

- 重写导言与 §0.3，把产品侧确定性调度定名为 **Attempt Admission / Dispatcher**，把基座
  §6 定名为 **Attempt 内执行监督 Agent**，并写清后者不能改路由、换执行器或扩权；
- 在 §4 后追加 §4.5–§4.11：路线转向、双 SDK 事实、统一 Port 与三态探针、Harness 上游
  门禁及过渡补法、双 runtime 部署/恢复、专用 Agent 构建判据、OpenClaw 借鉴与不转向；
- 在 §8.1 追加完整 `F-EXEC-*` / `F-INTERACT-*` 双腿映射；
- 在 §9.1–§9.2 追加三道正交门、工具不可见、四档审批、哈希绑定、代理凭据和 Attempt 级
  短 TTL 令牌；
- 重估 §11 的存续性质和删除条件，补齐引用清理清单。

任务书冻结的 §5、§7、§12、§13、§14、附录 A、附录 B 均未改正文。新版内容分散到原有
主题附近，而不是另起一整块 §15；这是有意让 Port、权限、恢复分别落在其长期归属章节。

### A.2 未验证并标了 ⚠ 的断言

- 新执行器架构尚未接入 production，双腿部署门禁和 Harness wire 门禁均无运行证据；
- dsh wheel 能否从内网 PyPI 镜像取得未验证；
- 两个 SDK 在 investment-app 内的集成、负载和故障注入未跑；
- 财务数据源仍未到位，专用 Profile 的真实输入和评测集不存在；
- 推理代理、Attempt 级短 TTL 令牌和对应撤销链尚未实现；
- OpenClaw 只做了固定提交上的源码/文档取证，没有与本产品联调。

### A.3 与基座的分歧

- 基座把本文视作可能随开发结束删除的开发期文档；我改判为长期开发指南，只有架构内容迁入
  长期真源且清理完引用后才可删除。
- 基座两处使用 `supervisor` 指不同层；我不只追加说明，还改了 §0.3 与 §6 标题以消除歧义。
- 基座保持执行器无关；我把 A4 的“执行层租用不自建”具体化为 Codex 通用腿、dsh 专业腿，
  但业务控制面、四本账和验收仍由本项目拥有。
- 我对 dsh 能力状态采取较严格口径：全量事件不等于逐 Turn 归属，杀进程不等于原生取消，
  新进程 restore 不等于 session resume。

### A.4 故意没写什么

- 没写任何具体财务 Profile 的字段、工具清单、角色数量或金标准题量：真实数据与首轮输入尚无，
  现在冻结会把假设升级成纪律，且违反 `request-lifecycle.md` §7.2。
- 没替下游决定“一个窄 Profile”还是“analyst/checker/awaiter 多角色”：这是数据源和 Gate 0
  之后的独立决策。
- 没写数据库 schema、迁移和具体实现类：本轮是架构指南重构，不应越权重定义四本账或把目标态
  冒充已接线实现。
- 没修改 human 文档、`request-lifecycle.md`、`AGENTS.md` 或部署 bundle：任务书只要求列清理与
  后续落点，本轮改这些会扩大冻结面。
- 没建议维护 dsh 私有 wire fork 或复制协议类型：A4 要求只依赖公开 SDK，上游缺口必须回到上游。

### A.5 自陈盲区

我是 `luna` 候选作者，以下评优存在直接利益冲突，不是独立终审。取证范围是四个固定提交、
基座 diff、仓内合同和外部仓固定提交的静态源码/文档；没有实跑 SDK、Kubernetes、网络策略、
审批回环或崩溃恢复。负向搜索只能证明钉版源码中未找到公开面，不能证明未来版本永远没有。
裁决方应以本节 B 的哈希重新取件，并可推翻我的结论，但应指出对应验收项和证据。

## B. 候选集冻结

枚举命令严格使用：

```sh
ls ~/worktrees/*/k8s/sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md
```

命中 5 个路径；按本轮规则排除一字未改的 `opus` 基座，只冻结以下 4 份。行数和字节数来自
相应提交的 blob，不来自活动工作区；内容用 `git show <commit>:<path>` 取件。

| 候选 | worktree 路径 | 行数 | 字节数 | SHA-256 | 所在 commit |
| --- | --- | ---: | ---: | --- | --- |
| luna | `/home/zym/worktrees/luna/k8s/sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md` | 1439 | 96181 | `3749a0c00bfe6258525f809ec7cc4cb396e4b9c7cc6877d88abfc10f27a5e3e2` | `f8bc48e3b4bc24fc0aec13065c3f7f9f4303c7ff` |
| kimi | `/home/zym/worktrees/kimi/k8s/sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md` | 1605 | 107909 | `83f1d8f8caa346a3688724b2bdb5ad7c96dd8a5b85a629699ededf9044c0c99e` | `9fe438089ff11e52edd1f2101a880b845524534a` |
| cursor | `/home/zym/worktrees/cursor/k8s/sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md` | 1649 | 113596 | `98da6c5bceedc9ddef9191a6f34af44a49dc34a8e77ee0556bdcf6f2aefc780b` | `65cd113a4c82991fa45c81233f91c01a631c694f` |
| qwen | `/home/zym/worktrees/qwen/k8s/sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md` | 1560 | 105425 | `ea2bb7abf2d96047b4a203c24a2c0467107919c21d92fbfa2938e155468675fd` | `0c6f0fc362d1a61dd6ec39bdebc1b5def0304ff5` |

冻结区机械校验以基座相同小节为输入逐段算 SHA-256。四份候选的下列值全部相同：§5
`6445745b…974faf9`、§7 `d1a07a8b…29cb9`、§12 `aa0b566a…43ace`、§13
`05904907…e566`、§14 `9e20bbe6…9ca8`、附录 A `8a38203e…7635`、附录 B
`8a23f304…3e86`。cursor 在附录 B 之后追加新章，附录 B 自身的 59 行仍逐字相同。

## C. 评优

### C.1 逐条验收比较

图例：`通过` 表示该项完整且事实口径可接受；`部分` 表示形状交付了但有会影响实施判断的错误
或缺口；`不通过` 表示硬要求缺失。这里不按多数表决：状态判断以候选内的源码锚点和产品合同为准。

| # | 验收项 | luna | kimi | cursor | qwen |
| ---: | --- | --- | --- | --- | --- |
| 1 | 冻结 §5/§7/§12–§14/附录 A/B | 通过 | 通过 | 通过 | 通过 |
| 2 | 七块齐全且核心断言可复跑取证 | 通过；§4.5–§4.11 均给固定提交、`file:line` 或命令 | 部分；七块齐，但若干事实被后文映射表误读 | 部分；七块齐，但 OpenClaw 第二层路由断言错误 | 部分；七块齐，但只取证 channel binding，没有交付第二层 runtime route |
| 3 | 新内容以 F/I/AT/constraints 编号锚定 | 通过；各门禁同时落 A/I/F/AT | 通过；§15 各节持续引用 A3/A4、I、F | 通过；§15–§23 有 A/F/I 锚点 | 通过；§15.0–§15.9 有 A/F/I/AT 锚点 |
| 4 | 双腿 `F-EXEC-*` / `F-INTERACT-*` 表 | 通过；§8.1 对原生能力、平台责任和降级分开 | 部分；§15.9 把 dsh `F-EXEC-02` 写成“已支持（设计）”，与其 §15.3/§15.5 的 `messageId` 非结果 ID、G2 缺口自相矛盾 | 部分；§22 把 Codex `thread_resume` 直接写成 `F-EXEC-05` 已支持，少了业务 checkpoint；同类过报也见 `F-EXEC-03` | 部分；§15.8 同样把 Codex `thread_resume/thread_fork` 和 per-turn approval 写成 `F-EXEC-05/03` 已支持，实际仍需平台 checkpoint/逐动作重新授权 |
| 5 | supervisor 消歧、上层确定性 | 通过；§0.3、§6 标题及关系一体化 | 部分；§0.5 消歧清楚，但 §15.2 又允许自由文本“受限分类器 + 兜底通用档”，弱化了确定性路由和风险歧义 fail-closed | 通过；§0.5、§15.3、§6.9 清楚 | 通过；§0.3/§6.0/§15.0 明确定名 Dispatcher 与内层 supervisor |
| 6 | §11 存续声明与引用清理 | 通过；改判长期指南并列 5 类清理落点 | 通过；增加执行器架构先迁出这一删除条件 | 通过；§23.1–§23.3 显式处理 | 通过；§11.1–§11.2 显式处理 |
| 7 | 不写具体 Profile 字段表 | 通过 | 通过；§15.10 明确只留判据 | 通过；§23.3 明确拒写 | 通过；§15.9 明确拒写 |
| 8 | 不重定义产品对象和状态机 | 通过；Port DTO 只存引用/opaque binding | 部分；“一 Attempt 一进程一独立 home”等实现约束偏强，但未系统重写对象 | 不通过；§20.3 发明审批超时“独立成态”，而产品合同规定超时行为由 Profile 决定，不能在本指南另造状态语义 | 通过；引用责任投影，不重写对象 |
| 9 | 不出现“dsh 需要系统 Node”误判 | 通过；§4.6 明确 wheel 不需要 | 通过；§15.3 明确不需要 | 通过；§16.2 明确不需要 | 通过；§15.2 明确不需要 |
| 10 | 专业构建轴与生产控制轴分开 | 通过；§4.6 明确两轴 | 通过；§15.4 明确两轴 | 通过；§15.4 明确两轴 | 通过；§15.0 明确两轴 |
| 11 | 未验证结论显式标 ⚠ | 通过；生产、供应链、联调均标出 | 通过；Gate 0 与供应链标出 | 通过；§23.4 集中列盲区 | 通过；§15.2、§15.4、§15.9 标出 |

第 4 项是本轮最关键的事实裁决。dsh protocol 的 `messageId` 只确认用户消息入队，不标识
assistant result 或 turn end；因此“`session.event` 全量可采”不能推出证据能逐 Turn 关联 Attempt。
同理，Codex 的 `thread_resume` 只是恢复原语，不等于 `F-EXEC-05` 要求的、执行进程死亡后仍由
业务持久载体恢复的 checkpoint。luna §8.1 把两者分别判为 `explicit_unsupported` 和
`implicit_fallback`，没有用 SDK 名词替代产品义务。

OpenClaw 事实题也有可判定差异。任务要求的两层是确定性的 channel/account binding，以及
provider/model 到 agent runtime 的选择。luna §4.11 给出 `resolve-route.ts:57-80,745-793` 与
`selection.ts:102-124,221-260` 两组源码锚点；qwen §15.7 只展开第一层；cursor §21.2 把第二层
写成 sandbox/gateway host/node 的工具执行位置，答成了另一件事。这里不能因多份候选都写了
“两层”就算通过。

### C.2 各候选强项与缺陷

#### luna

强项：事实口径最保守且内部一致；§8.1 是四份中唯一没有把 SDK 恢复/事件/审批原语过报为产品
义务已完成的映射。§4.11 对 OpenClaw 两层路由给到源码行；§4.9 的熔断键包含
`failure_fingerprint + profile_version + runtime_version`，确实是防 crash loop 的断路器，
不只是版本漂移兼容检查。§11 同时保留长期价值和删除出口。

缺陷：增量散在 §4、§8、§9、§11，裁决整合时不如单一 §15 易搬运；改了 §0.3 和 §6 标题，
结构触达面大于只追加方案。Port 签名是架构级草案，尚未用 Fake/契约测试证明可实现；部署角色、
代理和 token 撤销链也均未运行验证。以上缺陷没有被我作为作者身份抵消。

#### kimi

强项：§15 单块组织最连贯；§15.1 把“更好”写成可证伪 Gate 0 条件；§15.5 给出上游门禁与
真 runtime 契约测试要求；§15.6 的进程纪律和 §15.10 的下游留判很适合实施交接。

缺陷：§15.9 的 dsh `F-EXEC-02` 结论与同稿前文证据直接矛盾，是会让门禁提前放行的错误；
`F-INTERACT-*` 标为“已支持（我们层）”也容易把后端责任误读成执行腿能力。§15.1 提出不合格时
“退回自研 LangGraph 循环”，与 A4 执行层租用不自建冲突；§15.2 的自由文本分类器和默认通用档
让确定性、风险敏感路由出现例外。部分 OpenClaw/部署锚点只到文件或“worker 段”，粒度弱于
精确 `file:line`。

#### cursor

强项：§17 的 Port/DTO、可序列化 handle 和职责边界最具体；§18 把 dsh 上游缺口列成 7 项，
§19 的部署/进程/恢复操作性强；§23.4 是四份中最完整的集中盲区自陈。对 dsh
`F-EXEC-02/03/05` 的缺失判定比 kimi 准确。

缺陷：§21.2 把 OpenClaw 第二层路由错写为工具执行位置；§20.3 的审批超时“独立成态”越界定义
产品状态语义，并与 fail-closed/Profile 决策合同不一致。§22 把 `thread_resume` 当作 Codex
`F-EXEC-05` 已支持，也把 `approval_mode` 当作逐动作重新授权已支持，均漏掉平台义务。
§20.2 先把 `llm-review` 用于“高风险动作”，又说高风险至少模型复核，与四档中高风险应由有权人
批准的边界不稳。把 §15–§23 放在附录 B 之后虽然不改冻结正文，但成稿层级不自然。

#### qwen

强项：单一 §15 是四份中结构最紧凑的一份；§15.2 用 dormant capability 测试精确证明
`RunBudget`、Attempt/Invocation、Cancel endpoint 尚未生产接线，证据强于单纯“引用数为 0”；
§15.6 对双层工具不可见、四档审批、代理凭据解释清楚；§15.9 明确把角色数量留给下游。

缺陷：§15.7 声称“两层路由”却只展开 channel/account → agent binding，没有说明
provider/model → agent runtime，七块中的 OpenClaw 核心要求未完整交付。§15.8 把 Codex 的
per-turn approval 和 thread resume/fork 分别判为 `F-EXEC-03/05` 已支持，混淆执行器原语与产品
义务。§15.5 所谓“Profile 版本熔断”主要是版本漂移后拒绝 restore，属于兼容门禁，不是对同版
重复崩溃的有界断路器。G1 把 cancel 主要锚到 `F-EXEC-07`，也弱化了取消/授权义务的准确投影。

### C.3 基座建议

我建议选 **luna** 作为裁决基座。理由不是作者票，而是两个可复核的决定性差异：

1. 它是唯一在双腿映射中同时没有把 dsh 全量事件、Codex `thread_resume`、Codex approval 原语
   过报为产品义务已支持的候选；
2. 它是唯一用两组源码 `file:line` 准确交付 OpenClaw 两层路由，并把 Profile 熔断写成同版本
   crash-loop 断路器而非仅版本漂移检查的候选。

所有候选都守住冻结区、存续处理、无具体 Profile 表和两轴分离，因此应以局部事实准确性决胜。
鉴于直接利益冲突，裁决方若希望降低偏差，也可选结构更集中的 qwen 作排版基座，但必须先吸收
luna 的 §4.11、§8.1 和 §4.9 对应段并修正上述硬缺口；不能原样发布 qwen。

## D. 值得吸收的点

以下只列落选候选的独有或表达明显更好的点；“吸收”不等于照抄其相邻错误。

1. **kimi，§15.1“更好成立的硬条件”**：吸收 Gate 0 的可证伪对照设计，尤其用金标准比较
   dsh `submit_result + preset` 与 Codex `output_schema`，以及给启动失败率、内存、僵尸进程设阈值。
   它把路线偏好变成退出条件；但不要吸收“退回自研 LangGraph”，失败时应换公开 SDK 路线或
   重新走约束变更。
2. **kimi，§15.2 Router 的版本化配置与事件字段**：吸收“命中规则/配置版本/落档/reason”随
   RouteDecision 落账，便于 I1/I4/I15 审计；只吸收确定性表驱动部分，不吸收自由文本分类器的
   默认通用兜底。
3. **kimi，§15.5 门禁验收方式**：吸收“每项上游 wire 缺口对应真 SDK、真 runtime 的协议契约测试，
   固定金标准会话进 CI”。它补足 luna 目前只有门禁条款、没有明确测试载体的不足。
4. **cursor，§17.1–§17.3 Port 细化**：吸收 `FakeAgentWorker`、可序列化 `WorkerHandle`、
   `submit_result`、三态 `probe`，以及 TaskRouter/Adapter/runtime 的职责表。它让纪律层可以不依赖
   真凭据和真 runtime 测试；字段仍应在实施时以契约测试定稿，避免变成具体 Profile 表。
5. **cursor，§18.1 七项上游缺口表**：吸收编号 G1–G7 及“trusted tenant/actor/policy context、
   per-session preset、output_schema、server→client request”逐项对产品义务的映射。这比散文门禁
   更适合做上游 issue 和验收清单。
6. **cursor，§19.2 并发槽与 teardown**：吸收“先占槽后启动、槽位落 PostgreSQL、失败回滚”及
   `interrupt → timeout → terminate → close home → release slot` 顺序；它补齐双 runtime 在 Celery
   prefork 下的资源泄漏边界。
7. **cursor，§23.4 盲区清单**：吸收集中列出未跑 SDK E2E、未验证内网 wheel、未联调 OpenClaw、
   未做负载/故障注入的写法。分散的 ⚠ 仍保留，但集中清单更利于 Gate 0 建单。
8. **qwen，§15.2 事实⑥“生产没有 agent”**：吸收
   `test_dormant_capabilities.py:154/182/208` 对 RunBudget、Attempt/Invocation、Cancel endpoint 的
   休眠登记证据，以及 `AGENT_V4_TRAFFIC_ENABLED` 默认关闭的锚点。它比代码引用数更能证明
   `defined, not wired`。
9. **qwen，§15.6“被拒工具不存在”的解释**：吸收“会话组装层不暴露 + 网关调用层再挡”的双层
   做法，以及“存在但描述为禁止会诱发反复尝试和扩大越权面”的理由；这让 Tool Policy 的硬停
   语义比一句 deny-first 更可操作。
10. **qwen，§15.7 明确不借清单**：吸收对 OpenClaw `elevated/full`、SQLite、channel binding
    语义、重编排层的逐项拒绝，以及 `VISION.md:133/141` 的自证锚点；同时用 luna 的 runtime
    selection 源码补全第二层路由。
11. **qwen，§15.9 下游线前置**：吸收“财务数据源、Gate 0、四本账 PostgreSQL +
    ToolExecutionPort 生产接线”三项前置，并保留不在本轮决定专用 Agent 数量的边界。

本评审仍有与 A.5 相同的盲区：未执行 runtime 级验证，且对外部源码的解释可能随固定提交之后的
版本变化。裁决时应先复跑 B 的 blob 哈希，再把 D 中吸收项逐条绑定到最终稿 diff，避免只凭整体
印象整合。
