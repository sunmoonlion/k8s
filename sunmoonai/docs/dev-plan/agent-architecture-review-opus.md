# 架构走向复核：租执行运行时是否更好，以及 OpenClaw 的门禁模型

> 取证时点：2026-09-02 ｜ 作者：opus
> 取证对象：`/home/zym/repo/openclaw`（本机 HEAD）、`/home/zym/repo/codex`、
> `/home/zym/repo/deepseek-harness`、`worktrees/opus/investment-app`
>
> 回答两个问题：**① 改成租外部执行运行时，比原来的自研架构更好吗？
> ② OpenClaw 的 gate 做法，我们该借鉴还是转向？**
>
> 前置：[`investment-agent-architecture-opus.md`](investment-agent-architecture-opus.md)（总体架构）、
> [`agent-architecture-feasibility-opus.md`](agent-architecture-feasibility-opus.md)（外部后端可行性）。
> 每条断言附取证命令或行号，见 §7 边界。

## 第一部分 · 改成租外部运行时，更好吗

## 1. 结论

**问题本身包含一个假二分。**

"自研 vs 租用"不是可选的两条路。真正的选择是 **在哪一层自研**。而且有一个事实
必须先摆正：

> **原来的"自研架构"从来没有被建出来。**
> `ToolExecutionPort` 生产层引用数是 **0**——不存在"模型调工具、看结果、再决定"的循环。

```bash
cd investment-app/investment-backend/app
grep -rln ToolExecutionPort app/tasks/ app/application/ | wc -l    # 0
```

所以现在**不是**"放弃一个能跑的自研系统去租别人的"，而是**"第一件事先做哪个"**。
这让判断完全不同。

**我的判断：**

| | 判定 |
| --- | --- |
| 作为**补充**（多一种执行后端） | ✅ **更好**，而且现在就该规划 |
| 作为**替代**（不自研执行层了） | ❌ **更差**，且会把产品契约架空 |
| 作为**第一步**（先接外部再补基础） | ❌ **顺序错**，五处部署阻断全砸在这条路上 |

**一句话**：租用是对的,但它必须是**第二实现**,不是**新体系**。

## 2. 为什么"作为替代"更差：四条

### 2.1 最难的部分你**逃不掉**，租了也得自己做

`constraints.md` A3：**四本账（预算/幂等/副作用/证据）必须落 PostgreSQL。**
产品契约 §6.2 说得更死：

> 所有要求"进程被杀后仍正确"的事实必须由持久化与并发控制承担……
> **不能把这些事实仅保存在 worker 内存或外部执行 harness 中。**

Codex 的 thread 状态在它的 `CODEX_HOME`，dsh 的 session 在它的 `DSH_HOME`。
**租了以后，你还是得把它们的事件流翻译成你的四本账。**

也就是说：**租用省掉的是"工具循环"，省不掉"记账"**。而记账是难的那一半——
幂等、副作用一次性、租约、fencing、预算扣减，全在这一半。

**推论**：如果记账无论如何要自研，那么"顺手把工具循环也自研"的**边际成本远低于**
"再养一条把外部事件流翻译成本地账"的管道。

### 2.2 能力下限被最弱的那个后端锁死

实测三家的能力：

| 能力 | 自研(LangGraph) | Codex SDK | dsh SDK |
| --- | :-: | :-: | :-: |
| 中途取消 | ✅ 已有(Pilot 的 cancel) | ✅ `interrupt()` | ❌ **无** |
| 人工审批 | ✅ 已有(`interrupt()`+`WAITING`) | ✅ `approval_handler` | ❌ **无** |
| 异步 | ✅ | ✅ `AsyncCodex` | ❌ 纯同步 |

```bash
sed -n '113,120p' /home/zym/repo/deepseek-harness/packages/sdk/protocol/src/types.ts
#   'initialize' | 'session/prompt' | 'shutdown'   —— 只有三个方法
grep -rn 'cancel\|interrupt' /home/zym/repo/deepseek-harness/python/sdk/src/   # 无输出
```

产品契约 §4.1 要求 `RUNNING → CANCELLED` 合法，§4.2 要求 `WAITING(APPROVAL)`。
**如果只租 dsh，这两条对那条路径直接不可实现。**

而**自研那条路上，这两件事我们已经有了**——Pilot 链的 `interrupt()` + `WAITING` +
原子 resume 是全仓质量最高的一处实现。**放弃自研 = 把已有的能力扔掉。**

### 2.3 产品契约会被供应商节奏绑架

`request-lifecycle.md` 是**我们的**契约：九态状态机、五种等待原因码、十五条不变量。
如果唯一的执行路径是别人的进程：

- 想加一个等待原因码 → 看它的协议支不支持；
- 想改 fencing 语义 → 它的 SDK 没有这个概念；
- 它发一个 breaking change（dsh README 原文：**"THERE WILL BE COMPATIBILITY-BREAKING
  CHANGES"**）→ 我们的产品跟着停。

```bash
grep -n 'COMPATIBILITY-BREAKING' /home/zym/repo/deepseek-harness/README.md
#   DeepSeek Harness is in _developer preview_ … THERE WILL BE COMPATIBILITY-BREAKING CHANGES.
```

**dsh 自己声明是 developer preview。**把产品的唯一执行路径压在一个 preview 上，
不是架构选择，是风险选择。

### 2.4 部署阻断全部只砸在租用这条路上

五处硬阻断（详见另一份 §3）：出网被 NetworkPolicy 全禁、镜像无 Node、
根文件系统只读、内存 768Mi、无凭据通道。

**其中前四条，自研路线一条都不占**——自研工具循环跑在现有 worker 里，
用现有 LLM 端点，不需要子进程、不需要可写 home、不需要 Node。

## 3. 但"作为补充"确实更好：三条

### 3.1 有一类工作我们**不该**自研

Codex 在"改代码、跑测试、看输出、再改"这件事上做了很多年。
我们要做的是投资研究，不是重做一个编码 agent。**这部分租是对的。**

### 3.2 沙箱、压缩、重试是无差别工作

`SandboxPort` 定义了含 `shell`/`python` 的动作集，但**引用为 0**——
真做起来是一整个子系统。Codex 有三档沙箱（`read_only`/`workspace_write`/`full_access`），
dsh 有完整的 sandbox/approval 层。**这类没有领域差异的东西，租比自研划算。**

### 3.3 多后端本身就是一种抗风险

单一后端（无论自研还是租用）都是单点。
**能在 Profile 里换后端**，本身就是价值——某个模型涨价、某个 SDK 出问题、
某类任务换个后端效果更好，都是改一行配置。

## 4. 有第三方证据：OpenClaw 两个都做

这不是我的推理，是一个成熟系统的实际选择。OpenClaw 明确**自己拥有内置运行时**：

> OpenClaw owns the built-in agent runtime. Runtime code lives under `src/agents/`……
> **no external agent framework packages remain.**

**同时**注册外部 harness：

> The built-in runtime id is `openclaw`……**Plugin harnesses register additional
> runtime ids (for example `codex`)**。
> `auto` selects a registered plugin harness that supports the effective provider
> route, **otherwise the built-in OpenClaw runtime**.

```bash
head -30 /home/zym/repo/openclaw/docs/agent-runtime-architecture.md
ls /home/zym/repo/openclaw/src/agents/harness/    # registry/selection/policy/availability…
```

**注意最后半句**：外部 harness 不支持时，**回落到自建运行时**。
自建的那个是**默认值兼兜底**，外部的是**可选加速器**。

**这正是我建议的形状,而且它已经在生产系统里跑着。**

## 5. 第一部分的结论

```
❌ 不是    自研 → 租用
✅ 而是    自研（Port + 四本账 + 契约 + 一个内置运行时）
           ＋ 租用（Codex / dsh 作为同一 Port 后面的可替换实现）
```

**顺序上,自建那个内置运行时必须先有**——它是默认、是兜底、是唯一不受五处
部署阻断影响的路径。这与
[`investment-agent-architecture-opus.md`](investment-agent-architecture-opus.md) §8
的第 8 步（路线 A）一致。

---

# 第二部分 · OpenClaw 的门禁模型

## 6. 它到底做了什么

### 6.1 四道**正交**的门

OpenClaw 把"这个工具能不能跑"拆成**四件互不替代的事**：

| # | 门 | 决定 | 配置位 |
| --- | --- | --- | --- |
| 1 | **Sandbox** | 工具在**哪里**跑（沙箱后端 vs 宿主） | `agents.*.sandbox.*` |
| 2 | **Tool policy** | **哪些**工具存在/可调 | `tools.*`、`tools.byProvider[p].*`、`tools.sandbox.tools.*` |
| 3 | **Elevated** | exec 专用的逃生门（本身也被门控） | `tools.elevated.enabled` + `allowFrom.<provider>` |
| 4 | **Permission mode** | 文件系统边界 + **谁来审批升级** | 会话级 |

```bash
head -20 /home/zym/repo/openclaw/docs/gateway/sandbox-vs-tool-policy-vs-elevated.md
head -25 /home/zym/repo/openclaw/docs/gateway/permission-modes.md
```

**关键在"正交"**：它们不是同一件事的三个开关，是三个不同问题。
我们现在的 `AgentProfile` 把它们**混成一件**——只有 `allowed_tools` / `denied_tools`。

### 6.2 判定规则写得很硬

> - `deny` always wins.
> - If `allow` is non-empty, everything else is treated as blocked.
> - **Tool policy is the hard stop: `/exec` cannot override a denied `exec` tool.**
> - Elevated does **not** grant extra tools.
> - Tool policy filters by name; **it does not inspect side effects inside `exec`**。
>   If `exec` is allowed, denying `write`/`edit` does not make shell commands read-only.

最后一条尤其诚实：**它明说自己的门禁有边界**——允许 `exec` 就等于允许一切写操作，
禁 `write` 是自欺欺人。**这句话值得抄进我们的约束。**

### 6.3 审批可以不是人

`permission-modes.md` 的第四道门里有一列叫 **Exec escalation reviewer**：

| 模式 | 文件系统 | **升级审查者** |
| --- | --- | --- |
| `read-only` | 只读 | 无；exec 直接拒 |
| `guarded` | 读写 | **人**（走完 allowlist 快路径之后） |
| `workspace` | 读写 | **LLM 审查，人兜底** |
| `full` | 无限制 | 无 |

**这是对"`WAITING(APPROVAL)` 要求人一直在线"的一个真答案。**
不是所有批准都必须是人；有一档可以是"另一个模型先审，够不着才叫人"。

### 6.4 路由是**确定性配置**，不是 LLM

这是我最没预料到的一条,也是对你原方案最直接的反证。

OpenClaw 的路由分两级,**两级都不是模型判断**：

- **消息 → agent**：靠 **binding**（渠道账号 → agent 的声明式映射）；
- **agent → 执行运行时**：靠 `resolveAgentHarnessPolicy`——模型条目优先于
  提供方条目，未配置则 `auto`。

```bash
sed -n '1,25p' /home/zym/repo/openclaw/src/agents/harness/policy.ts
head -12 /home/zym/repo/openclaw/docs/concepts/multi-agent.md
```

它们的架构主张原话是三个词：**trusted gateway, untrusted execution,
deterministic policy**。**"确定性策略"是明写的支柱之一。**

而且有一条专门的防呆：

> **A provider or model prefix alone never selects a harness.**

即"看起来像"不足以选中——必须显式支持。

### 6.5 能力探针 + **分级**降级

`availability.ts` 的判定结果是一个带类型的决定，不是布尔：

```ts
kind: "available" | "implicit-unavailable" | "implicit-unsupported" | "declared-fallback"
```

规则：

- `harness.supports(context)` 返回 `{ supported, fallbackRuntime }`——**能力探针**；
- 不支持时，**只有隐式选中或 harness 自己声明了 fallback**，才回落到内置运行时；
- **`forcedByEnvironment`（显式钉死）时不回落**——显式指定就要失败要响。

**这比我上一份提的"永远 fail loud"更好，也比 dsh 的"永远拒绝"更好**：

| | 显式指定了后端 | 系统自动选的 |
| --- | --- | --- |
| dsh 的做法 | 拒绝 | 拒绝 |
| 我上一份提的 | 拒绝 | 拒绝 |
| **OpenClaw** | **拒绝（要响）** | **优雅降级到内置** |

用户明确要 dsh 却拿不到取消能力 → 应该报错；系统自己选的 → 应该悄悄换成能干的那个。
**这个区分是对的，我上一份漏了。**

### 6.6 可解释性：**说出该改哪个配置键**

```bash
openclaw sandbox explain --session … --json
```

它打印：有效沙箱模式、工具 allow/deny **以及这条规则来自 agent 还是全局还是默认**、
elevated 门、**fix-it key paths**（该改哪个键）。

日志侧同样：`agents/tool-policy` 审计条目带**规则标签、配置键、受影响的工具名**。

**这是整个门禁模型里最值钱、也最便宜的一件事。**没有它，
"为什么这个工具没跑"要靠翻代码。

## 7. 借鉴还是转向

**借鉴，不转向。** 理由是信任模型根本不同。

| | OpenClaw | investment-app |
| --- | --- | --- |
| 部署形态 | 单机/小团队 Node 常驻网关 | k8s 多副本，API/Worker/Scheduler 分角色 |
| 信任边界 | **网关运维者 = 用户本人** | **浏览器用户 ≠ 运维者**，多租户 |
| 状态载体 | 每 agent 一个 SQLite | 单一 PostgreSQL 逻辑库（D2/A3） |
| 网络 | 主机自由出网 | default-deny + 白名单 |
| 门禁归宿 | 配置文件 + 日志 | **必须是可查询的持久账**（I11/I15） |

**转向的三个致命处**：

1. 它的 `full` 模式和 `elevated` 逃生门，前提是"操作者就是本人"。
   我们的用户是浏览器端的租户，**任何会话内可达的逃生门都是越权面**。
2. 每 agent 一个 SQLite 会话库，直接违反 D1（单一权威主档）、A3（四本账落 PG）。
3. 引入它 = 引入 Node 常驻网关 = **第六套栈**（我们已经有两套要收敛），
   且撞上 §2.4 的部署阻断。

它是 MIT，代码可以抄——**但值钱的是设计，不是代码**。
代码是 TypeScript 且深度绑在它的配置系统上。

## 8. 该借鉴的五条（按性价比排序）

### ① 门禁决定要**可解释**，并说出该改哪个键 —— 最值钱最便宜

**做法**：一个 `GET /web/v1/runs/{id}/explain`，返回：

```json
{
  "tool": "web_fetch",
  "decision": "denied",
  "gate": "tool_policy",
  "rule": "profile.denied_tools",
  "source": "profile:financial_analysis@v3",
  "fix": "改 Profile 的 denied_tools，或换一个 Profile"
}
```

**建议在写门禁的同时做，不要事后补**——事后补要重新推导每条规则的来源。

### ② 我们比 OpenClaw 该多做一步：**门禁决定是一条事件，不是一行日志**

OpenClaw 把门禁决定写进日志。**我们应该写进 `session_events`。**

理由是契约 I11（证据账）：结论必须绑来源、时点、转换、执行者。
**"某个工具被挡了"是这条结论证据链的一部分**——为什么这份分析没引用某个数据源？
可能不是模型没想到，是工具被 Profile 禁了。日志里查不到，事件流里查得到。

```
gate_decision { gate, rule_label, config_key, decision, subject, profile_version }
```

成本：门禁本来就要写，多发一个事件几乎零成本。**这是我们能做得比 OpenClaw 好的地方。**

### ③ 四道门**正交拆开**，别混进一个 `allowed_tools`

现状 `AgentProfile` 只有 `allowed_tools` / `denied_tools`。建议拆成：

```python
class AgentProfile(BaseModel):
    tool_policy: ToolPolicy        # 哪些工具存在（deny 优先；allow 非空即默认拒）
    execution_scope: ExecScope     # 在哪里跑（in-process / sandbox / 外部后端）
    approval_policy: ApprovalPolicy  # 谁审批（见 ④）
    # 不要 elevated —— 见 §9
```

并把 OpenClaw 那三条判定规则**写进 `constraints.md`**：
`deny` 优先；`allow` 非空即默认拒；**工具门是硬停，任何会话级开关不得越过**。

连同那句诚实话一起写：**门禁按名字过滤，不检查 `exec` 内部的副作用**——
允许了 shell 就等于允许写。

### ④ 审批分级：**不是所有批准都必须是人**

抄 OpenClaw 的 reviewer 分档，映射到我们的 `WAITING(APPROVAL)`：

| 档 | 审批者 | 我们的用法 |
| --- | --- | --- |
| `none` | 无（直接拒绝该动作） | 只读研究 Profile |
| `auto-allowlist` | 白名单快路径 | 已知安全的检索类工具 |
| `llm-review` | **模型审查 + 人兜底** | 中风险；解决"人不能一直在线" |
| `human` | 人 | 高风险、不可逆、对外副作用 |

**注意**：`llm-review` 那一档必须落账（谁审的、哪个模型、什么时点），
否则就成了自我批准。契约里"agent 不得自我批准"约束的是**同一个 agent**，
一个独立的审查模型 + 人兜底是另一回事——**但必须留痕才成立**。

### ⑤ 能力探针 + 分级降级（修正我上一份的建议）

`AgentBackendPort` 的选择结果应该是带类型的决定，不是布尔：

```python
class BackendDecision(StrEnum):
    available            = "available"              # 直接用
    explicit_unsupported = "explicit_unsupported"   # 显式指定但不支持 → REJECTED，要响
    implicit_fallback    = "implicit_fallback"      # 自动选的不支持 → 回落内置，记事件
```

**规则**：Profile 显式写了 `backend_key` → 能力不足就在 `VALIDATING` 拒；
`backend_key = "auto"` → 回落到内置运行时，并**发一条事件说明为什么回落**。

**这条修正了我在
[`agent-architecture-feasibility-opus.md`](agent-architecture-feasibility-opus.md) §3.2
写的"能力缺失一律受理时拒绝"**——那对显式指定是对的，对自动选择过严。

## 9. 明确**不**借鉴的三条

| 不借鉴 | 理由 |
| --- | --- |
| **`elevated` 逃生门** | 它的前提是操作者=用户本人。我们是多租户浏览器用户，**任何会话内可达的提权面都是越权入口**。我们的"升级"只能走 Interaction 记录交给人，不能是一个会话开关 |
| **`full` 无限制模式** | 同上。而且 §6.2 那句"允许 exec 就等于允许写"意味着 `full` 实际上是无门禁 |
| **按 provider/model 分层的路由粒度** | 它有几十个模型提供方才需要 `tools.byProvider[p]` 这种粒度。我们现在一个 Profile 一个模型，**上来就做这个粒度是过度设计** |

## 10. 我的建议：路由用确定性，别用模型

这是第二部分对你原方案最直接的一条修正。

你原来的设想是 supervisor **判断**任务是通用还是专业。OpenClaw 的证据说明：
**成熟系统在这一层不用模型。**它的三支柱之一就叫 `deterministic policy`。

建议的路由优先级：

```
1. 前端显式选择        用户自己选"财务分析" —— 最准，也最可解释
2. 规则匹配            关键词/来源渠道/入口页 → profile_key
3. 模型分类            只在 1、2 都没命中时兜底，且必须落事件记录判据
```

**理由不是"模型不准"，是三条别的**：

1. **路由错的代价不对称**：跑错 agent = 整条任务的结果都错，而且用户看不出为什么；
2. **不可解释**：确定性路由能回答"为什么是这个 agent"，模型分类只能回答"模型这么说的"；
3. **它自己也要预算**：一次分类调用也是模型调用，而**预算账现在引用数是 0**——
   在有预算闸门之前，多一处不受控的模型调用是净负债。

真到了 Profile 多到规则维护不动，再上模型分类。**那时它也应该是一个正常的 Task，
落账、可复核，而不是一个隐形的路由层。**

## 11. 边界

| 边界 | 说明 |
| --- | --- |
| OpenClaw 只读了约 2% | 读了 `docs/agent-runtime-architecture.md`、`docs/gateway/sandbox-vs-tool-policy-vs-elevated.md`、`docs/gateway/permission-modes.md`、`docs/concepts/{architecture,multi-agent,delegate-architecture,parallel-specialist-lanes}.md`、`src/agents/harness/{policy,availability}.ts` 全文 + 目录清单。**未读**：`selection.ts`(1021 行)、`registry.ts`、沙箱实现、网关协议 |
| 未运行 OpenClaw | 未起进程、未跑 `sandbox explain`，其行为描述全部来自文档与源码 |
| "四道门正交"是我的归纳 | 文档写的是"three related but different controls" + 另一篇的 permission modes。**把它数成四道是我的合并**，OpenClaw 自己没这么表述 |
| 未评估 OpenClaw 的许可与供应链 | MIT，但依赖树未审计。若真要抄代码而非设计，需另做一轮 |
| §2.1 的"边际成本"论证未量化 | "自研工具循环的边际成本低于翻译管道"是推断，**没有工时估算支撑** |
| 未与其他助手交叉 | 本文是单方判断，未看其他分支对同一问题的意见 |
