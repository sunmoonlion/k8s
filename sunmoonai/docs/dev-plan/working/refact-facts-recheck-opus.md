# refact-task §4 八条事实复核（裁决方备料）

> 复核：2026-09-04 ｜ 执行：opus（裁决方）｜ 环境：`~/worktrees/opus`
>
> **性质**：这不是候选、不是评审。是裁决方在环节 ① 期间对 `refact-task.md` §4
> 「已经查实、不必重新论证的事实」逐条回源复核，为后面逐条整合备料。
> **未读任何其他 worktree，未读 `~/codex-reference-archive/` 下 `opus/` 以外的目录。**
>
> 结论先说：**八条全部成立**，但其中 **3 条的措辞不精确，会误导提案方**，
> 见 §9「任务书需要修的三处」。

---

## 1. 复核方法

每条只认两种证据：仓内 `file:line` 原文，或可复跑的命令。
凡任务书里给了行号的，逐个回原文比对；凡只给了定性的，自己去仓里找锚点。

复核对象仓：`~/repo/deepseek-harness`、`~/repo/codex`、`~/repo/openclaw`、
`~/worktrees/opus/investment-app`、`~/worktrees/opus/k8s`。

---

## 2. ① dsh 能构建专业 agent —— **成立**，锚点比任务书更硬

| 断言 | 锚点 | 原文 |
| --- | --- | --- |
| 一 preset = 一目录一份 `agent.cordis.yml` | `packages/preset/README.md:12` | "an agent preset is a directory holding one `agent.cordis.yml`" |
| 按会话组合 tools/prompt/skills | 同上 | "a session composed from a preset runs that preset's tools, prompt sections, and skills while every other session keeps its own" |
| **一个进程可同时跑多个不同组合的 agent** | 同上（该段末句） | "Together they let one process run several differently composed agents at once." |
| persona 可换身份而不只是换工具 | `packages/preset/README.md:28`（Packages 表 `persona` 行） | "the composable persona row a preset mounts to shadow or replace the deployment persona" |
| 设计理由与备选方案 | `packages/preset/README.md:38` → `.agents/notes/implemented/architecture/2026-08-03-per-session-agent-presets.md` | — |
| 一切皆插件 | `docs/cookbook/adding-a-tool.md:38` | "Registration is effect-based: disposing the plugin fiber unregisters the tool." |
| 策略应挂扩展点而非写死在工具里 | `docs/cookbook/adding-a-tool.md:59` | `tools/pre-execute` / `ctx.tools.guard()` / `tools/execute` / `tools/post-execute` / `tools/result` 五个扩展点 |

**新增可用素材**：`adding-a-tool.md:59` 那条对 §8 第 6 块（门禁三道正交）直接有用——
dsh 侧「被拒绝的工具应当不存在而不是存在但被禁」的会话组装层落点，就是 preset 组合 +
`ctx.tools.guard()` 的单调 deny。

**⚠ 后半句要改**：任务书写「Codex 无 preset 概念，**只有进程级配置**」——
前半成立，后半**不成立**，见 §9.1。

---

## 3. ② dsh SDK wire 控制面不足 —— **成立**，且能落到字段级

公开方法集，`packages/sdk/protocol/src/types.ts:115-119`（`HarnessSdkRequestMap`）：

```text
initialize      | InitializeParams      → InitializeResult
session/prompt  | SessionPromptParams   → SessionPromptResult
shutdown        | undefined             → {}
```

四个服务端→客户端通知，`types.ts:107-112`：`session.event` / `session.status` /
`subagent.started` / `subagent.finished`。

逐条兑现任务书列的缺口：

| 任务书说缺 | 锚点 | 复核 |
| --- | --- | --- |
| 无 cancel | `packages/sdk/protocol/README.md:115`；`packages/sdk/server/README.md:125` | 成立。原文："No cancel or session-close methods — a client abandons a turn by closing the runtime process"；"SDK-created agents remain live until process shutdown" |
| 无 session close/resume/read | 同上 + `types.ts:115-119` 无对应方法 | 成立 |
| 无逐 Turn 结果归属 | `types.ts:56-59` | 成立，**且有更硬的原文**：`SessionPromptResult` 只有 `messageId`；`README.md:52` 明写它 "does not identify a later assistant message, turn ending, or prompt result" |
| 无 per-session preset 选择 | `types.ts:16-27` `InitializeParams` 只有 `cwd/provider/model/reasoningEffort/maxTokens`；`types.ts:36-41` `SessionPromptParams` 只有 `sessionId/contentBlocks` | 成立，**且更严重**：注释写 `InitializeParams` 是 "the process-wide SDK handshake"，`provider`/`model` 是 "every SDK-created agent runs on"——**模型路由是进程级的，不是会话级的** |
| 无模型不可篡改的 tenant/actor/policy 绑定 | `types.ts:16-41` 两个 params 字段全集内无任何此类字段 | 成立 |
| 无 `output_schema` 对等参数 | dsh 侧 `types.ts:36-41` 无；Codex 侧有，见 §5 | 成立 |
| 服务端→客户端请求是死能力 | `packages/sdk/protocol/README.md:116` | 成立。原文："the transport supports them, but the server never sends one; the Python SDK's responder surface exists for future approval flows" |

**给 §8 第 3 块的直接产出**：`InitializeParams` 是进程级、`SessionPromptParams`
只带 `sessionId`——这就是「能力探针必须三态」的实证来源：dsh 的 per-session 模型选择
不是 `explicit_unsupported`（协议没说不支持），而是 `implicit_fallback`（协议根本没这一层，
你传什么都会被进程级配置吃掉）。**布尔探针在这里必然误判成「支持」。**

**⚠ 提醒整合时别写错**：`submit_result` 在 dsh 仓内**不存在**
（`grep -rn submit_result ~/repo/deepseek-harness/python/sdk/` 零命中）。
它是提案里给出的**我们自建的约定**，新稿里必须写成「我们要建的显式提交工具」，
不能写成 SDK 现有 API。

---

## 4. ③ dsh 不需要系统 Node.js —— **成立**，原文一字未变

| 锚点 | 原文 |
| --- | --- |
| `python/sdk-runtime/README.md:5` | "It packages the normal `dsh` CLI and its closed Node dependency tree into a native executable, so **SDK use requires no system Node.js**. This package publishes wheels only." |
| `python/sdk-runtime/platforms.json:2-4` | `"linux-x64": { "tag": "manylinux_2_28_x86_64", "executable": "deepseek-harness-sdk-runtime-linux-x64" }` |
| `python/sdk-runtime/README.md:13` | 那个 carrier："It runs `node runtime/node/node_modules/@deepseek-ai/dsh/lib/bin.js` on system Node 22.19 or newer. **It is never selected automatically and is excluded from wheels and sdists.**" |

第三次复核确认，措辞与任务书 §4③ 完全一致。**「dsh 需要系统 Node」这条不得复活**
（验收标准 §12.9）。

**仍未验证**：该 wheel 能否从内网 PyPI 镜像装到。这不是文档问题，是供应链问题，
新稿里必须标 ⚠ 而不是当成已门禁化。

---

## 5. ④ Codex 被钉死在 Responses API —— **成立**，行号精确

| 锚点 | 内容 |
| --- | --- |
| `codex-rs/model-provider-info/src/lib.rs:57` | `CHAT_WIRE_API_REMOVED_ERROR`：``` `wire_api = "chat"` is no longer supported.\nHow to fix: set `wire_api = "responses"` ``` |
| `codex-rs/model-provider-info/src/lib.rs:64-67` | `pub enum WireApi { #[default] Responses }` —— **枚举只剩一个变体**，比报错字符串更硬 |
| `codex-rs/model-provider-info/src/lib.rs:87` | 反序列化处 `"chat" => Err(...)`，配置里写 `chat` 直接启动失败 |
| `codex-rs/model-provider-info/src/lib.rs:58` | `LEGACY_OLLAMA_CHAT_PROVIDER_ID` 同样被移除 |

任务书给的 `:57` 正确。补一条更强的：**`WireApi` 枚举已退化为单变体**，
所以这不是「默认值」而是「唯一值」——要跑 Chat Completions 模型必须自建翻译代理这一结论加强，
不减弱。

---

## 6. ⑤ Codex 默认 approval_handler 自动 accept —— **成立**，且比任务书更危险

| 锚点 | 内容 |
| --- | --- |
| `sdk/python/src/openai_codex/client.py:773-779` | `_default_approval_handler`，docstring 原文 "Accept approval requests when the caller did not provide a handler"；`item/commandExecution/requestApproval` → `{"decision": "accept"}`；`item/fileChange/requestApproval` → 同 |
| `sdk/python/src/openai_codex/client.py:221` | `self._approval_handler = approval_handler or self._default_approval_handler` —— **兜底发生在构造函数**，不传就自动装上，没有任何告警 |
| `sdk/python/src/openai_codex/client.py:831` | 调用点，审批请求直接进这个 handler |

任务书 `:773-779` 正确。补 `:221`——**「忘了传」和「显式选了自动批准」在代码里长得一样**，
这正是新稿门禁小节要写死的：Adapter 构造时必须显式传 handler，不许走默认路径，
并且这一条要能被测试逮住（对应 `constraints.md` 的 T 系列）。

---

## 7. ⑥ 生产环境里现在没有 agent —— **成立**，但判据要换个写法

复核命令与结果（`~/worktrees/opus/investment-app/investment-backend/app`）：

```bash
grep -rln "ToolExecutionPort" app/   # → app/domain/agent/tools.py            仅定义处
grep -rln "SandboxPort"       app/   # → app/domain/agent/sandbox.py          仅定义处
grep -rn  "CancelRunCommand"  app/interfaces/ | wc -l   # → 0
grep -rln "RunBudget"         app/   # → app/domain/agent/runtime.py
                                     #   app/infrastructure/graph/first_m1_graph.py
```

`AGENT_V4_TRAFFIC_ENABLED: 'false'` 在
`k8s/sunmoonai/app-platform/investment-app/deployment/bundle/00-prerequisites.yaml:111`，
同处 `:112` 还有 **`AGENT_PILOT_ENABLED: 'false'`**（任务书没提，是同一条结论的第二个证据）。

**⚠ 「`RunBudget` 引用数为 0」不准确**，见 §9.2。

**重大发现——本仓已有机器可判的休眠能力登记表**：
`investment-backend/app/tests/test_dormant_capabilities.py`。
它把「代码在、没接线」的能力写成**两个方向都能失败**的判据：
`anchor_exists`（锚点还在吗，为假说明判据自己失效了）+ `still_dormant`（还休眠着吗，
为假说明能力已接线、声明过期）。文件头注释原文点破了本项目反复踩的坑：
**「把『没找到』当成『不存在』」**。

相关条目（`tests/test_dormant_capabilities.py`）：

全表十一条（行号为该条 `name=` 所在行）：

| 条目 | kind | 行 |
| --- | --- | --- |
| `domain/{models,repositories,services}` 仍是模板空壳 | pending | 105 |
| Outbox/Inbox 消费链路 | deliberate | 119 |
| web-interaction 运行时（默认 `UnavailableWebInteractionAdapter`，生产必定 503） | deliberate | 129 |
| Celery 周期任务（全仓无 `beat_schedule`） | deliberate | 142 |
| `RunBudget` 在生产生效 | pending | 154 |
| Web 面接 Agent/Pilot | pending | 172 |
| `Attempt / Invocation` 落库 | pending | 182 |
| `AgentMemoryService` | pending | 198 |
| `CancelRunCommand` 的 HTTP 端点 | pending | 208 |
| `first_m1_graph` 与两个 spike 不在生产链 | deliberate | 219 |
| **`AgentProfile` 在执行期生效** | pending | 240 |

**最后一条是本次复核最有价值的意外收获**，`tests/test_dormant_capabilities.py:240-258`
的 evidence 原文：

> `RunService.create_run` 解析 profile 并把 key/version 写进 run 行，
> 但 `dispatch_agent_graph` 只传 `run_id` / `user_input` / `security_context`——
> `effective_config` 到不了图里。两条生产图对 `allowed_tools`、`denied_tools`、
> `model_key`、`system_prompt_id`、`memory_policy` 的引用数均为 0。
> 即：**Profile 被记录，不被执行；它现在是审计字段，不是约束。**

这给 `refact-task.md` §10「不要写具体 Profile 字段表」补了**第二条、且是代码级的理由**：
任务书原来的理由是「业务数据 0 张表，那些工具表从没跑过真实输入」；
现在还可以说——**Profile 连执行期约束力都还没有**，
`allowed_tools` / `denied_tools` 在生产图里引用数为 0。
在这个前提下把某个 Profile 的六个工具表写进开发指南，
等于把一个当前根本不生效的机制的实例细节固化成纪律。
建议整合时把这条并进 §10 的理由链。

其中 `RunBudget` 那条的 evidence 字段已经把话说全了：
「生产链路 pilot_service 只有一行 `budget_exceeded→failed` 的状态映射，从不构造也不消费预算，
故 `budget_exceeded` 在生产中不可达」。

**这对新稿的价值超出 §4⑥ 本身**：§8 第 5 块要写的「恢复有界」、第 3 块要写的「能力探针三态」，
都可以直接沿用这套「判据两个方向都能失败」的形状，而不是新发明一套。
**建议整合时把它作为既有资产引用，而不是重写一套清单。**

⚠ 本次未跑通该测试：环境无 pytest（`python -m pytest` → `No module named pytest`），
上表是**手工复算每条 `still_dormant` 的判据表达式**得到的，结论一致，但不等于测试通过。

---

## 8. ⑦ 部署侧四条硬阻断 —— **四条全部成立**

bundle 根：`k8s/sunmoonai/app-platform/investment-app/deployment/bundle/`

| # | 阻断 | 锚点 | 复核 |
| --- | --- | --- | --- |
| 1 | worker 无任何 `ipBlock`，两个模型 API 都连不出去 | `30-network-policies.yaml:224-267`（`investment-backend-worker-egress`）；`grep -rn ipBlock .` **零命中** | 成立。worker 出向白名单只有三处：data-platform 命名空间 5432/6379/5672、casdoor `:8000`、knowledge backend-api `:8000`。另有 `investment-default-deny`（`:4`）兜底 |
| 2 | `readOnlyRootFilesystem: true` | `20-runtime.yaml:363`（worker；api `:178`、scheduler `:469`、另两处 `:581`/`:739`；migration 见 `10-migration.yaml:73`） | 成立，且是全组件一致的基线，不是 worker 特例 |
| 3 | 内存上限 768Mi | `20-runtime.yaml:358-360`（worker `limits.memory: 768Mi`，`requests` 192Mi，`limits.cpu: '1'`） | 成立，与 backend-api 同额度 |
| 4 | `AGENT_PILOT_LLM_*` 在 bundle 里根本没配 | `grep -rn "AGENT_PILOT" bundle/` → **仅 1 命中**，是 `00-prerequisites.yaml:112` 的 `AGENT_PILOT_ENABLED: 'false'` | 成立。bundle 内 `AGENT_` 前缀共三项：`AGENT_V4_TRAFFIC_ENABLED`（`:111`）、`AGENT_PILOT_ENABLED`（`:112`）、`AGENT_REDIS_KEY_PREFIX`（`:113`） |

`AGENT_PILOT_LLM_BASE_URL/API_KEY/MODEL` 三个变量只出现在 kind 环境的一次性脚本里
（`sunmoonai/docs/mooc-manus-v5/scripts/deploy_p0_008c_research_pilot_kind.sh:46-48,161-162`），
**没进 bundle 的 desired state**。这正好是新稿要说的「凭据不下发到 harness 进程」的
反面证据：现在连下发路径都不存在，是从零建，不是改造。

---

## 9. ⑧ 财务数据是死穴 —— **成立**，13 张表可逐张点名

```bash
grep -rn "create_table(" investment-backend/app/alembic/versions/ | wc -l   # → 13
```

四个迁移，十三张表，逐张分类：

| 迁移 | 表 | 性质 |
| --- | --- | --- |
| `20260708_0001_agent_phase0.py` | `agent_sessions`、`agent_runs`、`session_events`、`tool_side_effects`、`checkpoints`、`checkpoint_blobs`、`checkpoint_writes`、`checkpoint_migrations` | Agent 运行时 + LangGraph checkpoint 基础设施 |
| `20260712_0002_auth_identity.py` | `auth_user` | 身份 |
| `20260729_0003_agent_pilot.py` | `agent_pilot_requests`、`agent_pilot_controls` | Agent 运行时 |
| `20260809_0004_outbox_primitives.py` | `outbox_message`、`inbox_message` | 消息原语 |

**业务数据表 0 张**：没有任何标的、行情、财报、基本面、持仓、研报的表。
ORM 侧同样只有三个 `__tablename__`（`auth_user` / `inbox_message` / `outbox_message`，
`app/infrastructure/models/` 下仅 `auth.py`、`outbox.py`）。

结论原样成立：**没有数据，专业 agent 的选型再对也无米下锅。**
这条直接支撑 §10「不要写具体 Profile 字段表」的理由链。

---

## 10. 任务书需要修的三处

复核中发现 §4 有三处措辞会把提案方带偏。**建议在 ① 截止前修**，
因为它们分别会污染 §8 的第 1、2、3 块。

### 10.1 ①「Codex 无 preset 概念，只有进程级配置」—— 后半句不成立

Codex 的会话与轮次配置面**相当宽**，`sdk/python/src/openai_codex/generated/v2_all.py`：

| 参数类 | 行 | 可覆盖的东西 |
| --- | --- | --- |
| `ThreadStartParams` | 8546-8578 | `model`、`modelProvider`、`sandbox`、`approvalPolicy`、`approvalsReviewer`、`cwd`、`baseInstructions`、`developerInstructions`、`personality`、`serviceTier`、`ephemeral`、`config` |
| `ThreadResumeParams` | 4974-4997 | 同上大部分 + `threadId` |
| `TurnStartParams` | 8640-8701 | **逐轮**覆盖 `model`、`effort`、`sandboxPolicy`、`approvalPolicy`、`cwd`、`personality`、`summary`、`serviceTier`，外加 **`outputSchema`**（"Optional JSON Schema used to constrain the final assistant message for this turn"） |

准确说法应是：

> Codex 没有 **preset**——把 tools + prompt + skills + persona 打包成可复用、
> 可发现、可挂载的单元这件事它不做；但它的**每线程/每轮次覆盖面很宽**
> （模型、provider、沙箱、审批策略、cwd、指令、`outputSchema` 都能逐轮改）。
> 缺的是**组合复用**，不是**配置粒度**。

**为什么必须改**：现在的写法会让提案方在 §8 第 1、3 块里把 Codex 写成「粗粒度、不可调」，
从而低估它——而事实恰好相反，**控制面这个轴上 Codex 强、dsh 弱；
专业组合那个轴上 dsh 强、Codex 弱**。这正是 §12.10 要求的「两个轴分开」，
任务书自己这一句却把两个轴混了。

### 10.2 ⑥「`RunBudget`、`SandboxPort`、`CancelRunCommand` 引用数同为 0」—— 对两个、错一个

- `SandboxPort`：仅定义处，**0 个使用方，成立**；
- `CancelRunCommand`：`app/interfaces/` 下 0，**成立**（但领域层有定义与测试，共 6 处引用）；
- `RunBudget`：**不是 0**。`app/` 下两处：`domain/agent/runtime.py`（定义）与
  `infrastructure/graph/first_m1_graph.py:9,33`（**有真实构造与消费**）。

「引用数为 0」的写法会被 `grep` 一次就推翻，反而削弱结论。建议改成登记表里那句已经站得住的：

> 生产链路 `pilot_service` 只有一行 `budget_exceeded→failed` 的状态映射，
> 从不构造也不消费预算，故 `budget_exceeded` 在生产中不可达；
> `first_m1_graph` 不在生产链（`tests/test_dormant_capabilities.py` 有机器可判的登记）。

顺带：`tests/test_dormant_capabilities.py` 文件头那句
**「把『没找到』当成『不存在』」是本项目反复踩过的坑**，
建议在任务书 §12 验收标准里加一条对应要求——新稿凡用 `grep` 计数当证据的，
必须同时给出锚点存在性判据，否则改个名字证据就假性通过。

### 10.3 §8 第 4 块的 `submit_result` 会被读成 SDK 现有能力

`~/repo/deepseek-harness` 全仓无 `submit_result`。它是提案里给出的自建约定。
任务书 §8 第 4 块把它和「杀进程取消」「分层审批」并列写在「门禁未过期间的补法」里，
不加限定会被提案方当成 dsh 已有的 API 去引用。建议加半句：
**「`submit_result` 是我们要自建的显式提交工具约定，不是 SDK 现有方法。」**

---

## 11. 本次复核的边界

- **未验证**：dsh sdk-runtime wheel 能否从内网 PyPI 镜像装到（供应链，需要网络）；
- **未跑通**：`tests/test_dormant_capabilities.py`（环境无 pytest），§7 的表是手工复算判据；
- **未读**：其他四家的 worktree、`~/codex-reference-archive/` 下 `opus/` 以外的目录——
  提案期隔离（`refact-task.md` §0.3、§11）；
- **未涉及**：§8 第 7 块 OpenClaw 的完整取证。只顺手确认了两条会用到的：
  `~/repo/openclaw/SECURITY.md:146` "Exec behavior is host-first by default:
  `agents.defaults.sandbox.mode` defaults to `off`"，
  以及 `~/repo/openclaw/docs/cli/policy.md:415` "Policy treats missing `sandbox.mode`
  as its implicit default `off`" —— **两处独立文档同指一个危险默认**，
  比任务书只说「`sandboxing off by default`」更硬。`VISION.md` 存在，本次未通读。
