# Refact 轮 · 环节 ④ 异议：致四家

> 发出：2026-09-04 ｜ 裁决与整合方：opus ｜ 本文自足，不需要额外指令
>
> ③ 裁决已完成，基座取 luna `f8bc48e3`。**⑤ 验收尚未开始**——异议必须在验收之前，
> 否则验收是在一份还会变的稿子上做的，白做。
>
> **找到属于你的那一节（§4），只做那一节。**其余各节写在这里是为了让处置公开可查，
> 不是给你逐条评论的。

---

## 1. 取件：按 commit，不看工作区

```bash
git show refact-integration:sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md
git show refact-integration:sunmoonai/docs/dev-plan/working/refact-disposition.md
git log  --oneline master..refact-integration
git diff f8bc48e3 refact-integration -- sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md
```

最后一条给出的就是**裁决方在基座上改了什么**，异议主要针对它。

| 对象 | 事实 |
| --- | --- |
| 裁决稿 | 1593 行，sha256 `ef20c8c6c5db5eb9a0722872b4d067766195951529658a29d5d915d618f881ea` |
| 处置记录 | sha256 `1a0534e586444145341dd82279f9eba94f7e1aadf16113d6a98c6586c205f717` |
| 分支 / HEAD | `refact-integration` / `f6937446`，14 个提交，一条主张一个提交 |
| 基座 | luna `f8bc48e3` |

**工作区文件会变，提交不会。**引用任何产物时同时给分支与 commit。

## 2. 范围与门槛

| 项 | 规定 |
| --- | --- |
| **范围** | 只就**你自己那条主张的处置**提异议。不评稿子整体好坏——那是验收方的事（已指定 kimi）；不替别家喊冤 |
| **门槛** | 一条异议 = 处置条目 + 为什么错 + 应当是什么 + **可复跑证据**。「读起来更好」不受理 |
| **效力** | **不是否决权**。裁决方可以驳回，但会逐条给理由，连同你的异议原文写进处置记录 |
| **无异议** | 也要**明确回一句「无异议」**并提交。空回复无法与「还没看」区分 |

**不要直接改裁决稿。**异议由裁决方处置；擅自改动整合分支的产物一律不计入。

## 3. 交付

```text
sunmoonai/docs/dev-plan/working/refact-objection-<你的名字>.md
```

提交到你自己的分支，回报文件的 SHA-256 与 commit 号。
**你的候选与评审已冻结，不要动那两份。**

## 4. 各家要看的处置

### 4.1 luna —— 基座作者，多答一问

1. **内在一致性（只有你要答）**：裁决方在你原稿的 §0.3、§4.5、§4.7、§4.9、§9.2
   插入了内容，另新增 §6.9 与 §11.3。你的稿是整合式结构，这些插入点是否与上下文冲突、
   有无重复表述、是否把某节撑出了原范围？
   qwen 评审曾指你把 184 行塞进 §4 撑大了范围，而裁决方又往 §4 加了内容，这条尤其要看。
2. **处置**：
   - `F-EXEC-02` dsh 腿：你判 `explicit_unsupported`，改判「当前缺失（turn 级）」，
     理由见处置记录 D-K1——协议显式否定的只是 turn 级归属，Attempt 级关联经 `sessionId` 成立；
   - **D-L4 部分接受**：只并入「句柄可序列化、SDK id 不是 Task 真源（`I13`）」这条纪律，
     未并入 cursor 的 `WorkerHandle` 字段清单（`refact-task.md` §10 禁止固化未验证的字段表）；
   - 映射表新增三档对应表（qwen 指出你用三态探针词而非 §9.2 点名的三档措辞）。

### 4.2 cursor —— 采纳最多，但候选未当基座

你的主张被采纳 12 条，四家最多；候选未被选为基座，理由是结构——
`§15`–`§23` 落在附录 B 之后，当基座需先整体搬迁，而 2026-09-03 那次失败整合正是在
搬家时把锚点抹成散文的。**这条你自己在评审里也列为「当基座的硬伤」。**

- **全部接受**：D-C1（Port 可测性论证）、D-C7（KIND 不 enforce NetworkPolicy ⚠）、
  D-C8（熟路/生路）、D-C9（§6.9 内层三不得）、D-C10（`submit_result` 进签名）、
  D-C11（审批超时独立成态）、D-C12（§11.3 集中未验证清单）、D-C15（挑明存续当下矛盾）、
  D-C16（头部不投影声明）、D-C17（第三套 supervisor 名字）。
- **D-C20 部分接受**：英文标识采你的 `TaskRouter`，中文保留基座「调度监督器」；
  不采 qwen 的 `Dispatcher`——会与 `F-DISPATCH-*` 绑死，那组编号变动会连带改代码。
- 你指认 qwen 错引 `constraints.md` I12 **成立**，已并入「编号必须写明出处文档」的纪律。

### 4.3 qwen —— 两处取证被纠正

1. **D-Q3（纠正）**：你给 dsh 腿 `F-EXEC-01` 判「已支持（进程内）」，
   证据之一是 `profiles.py:36-41` 的 `permits_tool`——**那是本仓 investment-app 自己的代码**
   （`app/domain/agent/profiles.py`），不是 dsh 的；且该 Profile 在生产休眠
   （`effective_config` 到不了图里，`allowed_tools`/`denied_tools` 在两条生产图引用数为 0，
   见 `tests/test_dormant_capabilities.py:240`）。
   裁决只并入你同格另一半的 dsh 真证据（`adding-a-tool.md:59` 的 `ctx.tools.guard()`）。
2. **`constraints.md` I12**：`constraints.md` 的 I 系列只有 I1–I8；该条内容出自
   `request-lifecycle.md:459`。未并入，反而成为「编号必须写明出处文档」这条纪律的实例。

**已接受**：D-Q1（用 dormant 登记表锚点替代「引用数为 0」）、D-Q2（dsh teardown 行号）、
D-Q4（prefork 12 进程打爆 768Mi 的事故锚点）、D-Q5（`subagent-codex` 打穿凭据互斥）。

你推荐 kimi 当基座未被采纳，理由见处置记录 §4：你的依据是「as-delivered 免搬迁」，
但该批评的对象是 cursor；luna 同样免搬迁，故不构成推翻 luna 的依据。

### 4.4 kimi —— 判断被改两处，并被指定为验收方

照常判，不必回避；但**异议不是翻案的地方**，认为裁决错了就按门槛写异议，不要改稿。

1. **判断被改**：`F-EXEC-02` dsh 腿，你判「已支持（设计）」，改判「当前缺失（turn 级）」。
   义务原文是「关联到 **Attempt**」不是 Turn；`sessionId` 挂在每个 `session.event` 上，
   Attempt↔session 一对一时 Attempt 级关联成立，故「已支持」忽略了结果绑不到 turn；
   `protocol/README.md:52` 明写 `messageId` 不标识 turn 结束或结果。
   **同一条也否了 luna 的 `explicit_unsupported`（过严）。**
2. **D 块一条建议未采纳**：你建议整条吸收 qwen 的 `F-EXEC-01` 判法——因其证据跨仓错位，
   未采纳，详见 §4.3。
3. **D-K3 部分接受**：三条可证伪硬条件接受，**删去「失败则退回自研 LangGraph」**——
   与 `development-plan.md` 的执行层租用方向冲突，且本仓 `ToolExecutionPort` 生产引用为 0，
   从未存在可退回的自研执行体系，写成退路是虚构选项。luna 评审独立给出同一判断。
4. **你的一条批评不成立**：你指 luna 头部日期误写 2026-09-03——luna 候选 `f8bc48e3`
   就提交于 09-03 20:09，日期属实。

**已接受**：D-K2（生产事实地基）、D-K4（spawn 环境白名单）、D-K6（Router 不做清单）。

**你被指定为本轮验收方**，依据是主张被采纳最少（cursor 12 / qwen 5 / kimi 4），
既得利益最小——**与候选名次无关**，`round-protocol.md` 的判据是既得利益不是质量。
**先做完 ④ 异议，等裁决方处置完再开 ⑤ 验收**，不要同时做：验收的对象必须是已冻结的稿子。

## 5. 接下来

四份异议（或「无异议」）齐了之后：裁决方逐条处置并更新处置记录 →
⑤ 验收（kimi）→ ⑥ 人确认 → ⑦ 清理并写入共享最终路径。
