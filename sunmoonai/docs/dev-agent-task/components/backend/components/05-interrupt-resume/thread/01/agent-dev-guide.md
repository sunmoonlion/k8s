# Agent 开发指导：一个产品运行时，一套开发纪律

### 4.3 直接沿用实际中断/恢复原语

当前基座已经提供足够原语：

- `investment-backend/app/app/infrastructure/graph/pilot_graph.py:59-66` 调用
  `interrupt({...})`，出向值就是任意字典；
- `investment-backend/app/app/infrastructure/graph/langgraph_runtime.py:14-21` 用
  `Command(resume=user_input)` 接收任意恢复值；
- `investment-backend/app/app/application/agent/graph_runtime_service.py:14-23` 将同一 `session_id`
  映射为同一 `thread_id`；
- `investment-backend/app/app/tasks/agent_graph.py:106-128` 在同一 thread 配置和 PostgreSQL
  checkpointer 上首次执行或恢复。

**中断恢复在本项目已经端到端跑通**，不只是「库有原语」：

| 层 | 状态 | 取证 |
| --- | --- | --- |
| 抽象基类 `GraphRuntimeService.resume` | `raise NotImplementedError(...)` | `graph_runtime_service.py:26-31`——这是**抽象方法的正确写法**，不是功能缺失 |
| 适配器 `LangGraphRuntimeService.resume` | **已实现**：`Command(resume=…)` + 同 `thread_id` | `langgraph_runtime.py:13-21` |
| 端到端 | **通过**：中断 → `resume` → 原地续跑并产生副作用 | `test_graph_runtime_service.py:18-35`，`uv run pytest` → **2 passed** |

⚠ **这一段容易写反，教训比结论有用。**只据抽象基类那行 `NotImplementedError`
断定「端到端未接线」是错的——**错在只读了基类 18 行就停**，没搜谁继承、没搜谁调用、没跑测试。
把「留给实现方的空位」（**接口契约**）读成了「功能缺失」。

> **「打开文件自验」也会失败**：验了，但**验的范围是自己划的**，而范围划错了。
> 这与「没验就下结论」是两种错，**后者好防，前者难防**。

因此实现应把产品 Interaction 的 `question_or_action / audience / expires_at / resume_token_hash /
idempotency_key / consumed_at / resume_target` 绑定到这些原语，字段真源仍是
`request-lifecycle.md @ ed0b5136:247-277`。中断节点返回业务需要的 dict；恢复端鉴别主体、校验
Task 与状态版本、原子消费令牌，然后把经验证的响应作为 `Command(resume=value)` 送回同一 thread。
checkpoint 原地续跑时是同一 Attempt 的 `WAITING → RUNNING`，不因“人给了内容”另开 Attempt。

**`dev.change` 的 H8 具体这样接**（五步，缺一步就会长回自造协议）：

1. 需要人时，adapter 调库的 `interrupt(payload)`；**payload 的形状由 Task Profile 的入向约定声明**，
   不写进内核绑定字段——形状归 Profile，字段归内核，这样扩展不必动内核；
2. 人的答复经 **principal channel** 到达后，adapter 调 `Command(resume=答复)`，
   **同一 `thread_id` 原地续跑**；
3. **这不是新 Attempt，也不建新 Task。**内核 Attempt 状态机走 `WAITING → RUNNING`；
4. **只有**当答复实质改变了目标、口径、授权范围或 Profile 版本，才按内核建带 `supersedes`
   的新 Task——**四个条件之外的答复一律回原 Task**；
5. 过期、异键、跨 Task 的恢复**由库与内核既有校验拒绝**，不在 Profile 层再造一套。

⚠ **「需要载荷」这个需求，是被「恢复必须开新 Attempt」自己造出来的。**
库的恢复不换 Attempt，载荷就是 `resume` 的那个值。取消掉那个不该有的执行边界，
围绕它长出来的一整支设计（载荷、schema、过期校验、Task 级暂停）就一并消失。

若未来业务确需结构化编辑，先拿一个真实 Task Profile 的前端 payload、拒收用例和迁移数据立规范修订；
不要从自由 `resume` 值反推一套平台级 patch/replace 协议。修改目标、授权范围或 Profile 版本仍按产品
“终态、刷新与重新处理”建立新 Task；普通澄清只恢复原 Task。

**按问询类型展示信息，避免轻问题背重合同。**补缺失参数只展示具体问题与必要上下文；
批准某个产物则展示其版本、证据等级、允许改动范围和各选项后果；依赖/资源/外部事件按已有合同。
业务内容放在 Profile 的 payload 内，不另造内核字段。

人指出错误、由 agent 继续修订时，把反馈作为恢复值交回同一执行；
人亲自提供新 Artifact 版本时，保存人的作者归属并把引用绑定到经验证的响应。
**谁写下一版不决定是否新开 Attempt**：可原地续跑就仍是原 Attempt；旧执行已终态、
需重试或换执行器才新开；目标/授权/Profile 改变则按合同新建 Task。
这保留“人可以贡献内容”，排除旧稿“人写新版本必然换 Attempt”的额外执行边界。

### 4.7 四档审批

> 依据的通用规范：[人的批准点「四档审批」](../../../../../../../dev-agent-standards/approvals.md)

审批策略固定四档，具体动作由 Task/Profile 风险分类映射：

| 档 | 适用 | 决策者 | 纪律 |
| --- | --- | --- | --- |
| `auto-deny` | 未声明、越权、不可满足门禁 | 确定性 policy | 直接拒绝并留 reason code |
| `auto-allow` | 冻结政策明确的低风险、可逆、范围内动作 | 确定性 policy | 仍逐次验权、记预算/副作用 |
| `llm-review` | 只需语义检查且政策明确允许委托的中风险动作 | 独立受限 reviewer | **必须落账**模型/版本/输入摘要/判定/理由；否则等于产出者自我批准 |
| `human-approval` | 高风险、不可逆、发布、扩权、追加预算 | principal 经 Interaction | 一次性、短时、精确绑定，**不可转授** |

每份批准绑定 `task/attempt/action/target/policy_version` 与待执行 canonical payload、
计划/diff/Artifact 的内容哈希；**执行前重算，任一字节、目标、权限或版本漂移即作废**。
批准有短 TTL，超时 fail-closed。

⚠ **不得把 Codex 默认 accept 当任何一档批准**（`client.py:773-779`，见 [§2.7](../../../04-agent-execution/composition/agent-dev-guide.md)），
**也不得让生成候选的同一 Agent 充当 `llm-review`**。

⚠ **超时是独立的审计结果与 reason code，不折成 `auto-deny`。**两者行为后果相同
（都不放行、都 fail-closed），**审计含义不同**：`auto-deny` 是策略作出了拒绝判断，
超时是**没有任何人作出判断**。压成同一个 reason code 会污染审计账——
事后无法区分「策略拒绝率上升」和「审批链路卡死」。落账写 `approval_timeout`，
带等待时长与待审对象哈希。

⚠ **四档与 [§4.2](../../../../composition/agent-dev-guide.md) 权力表是两条正交的轴，不是一张表的两种写法。**权力表回答
「**哪个 principal** 可以走**哪条合法边**」；四档回答「**一次具体动作**经过**什么样的审批
形态**」。`llm-review` 在权力表里没有行，因为它不是 principal 的权力——
⚠ 它是否可用于任何 `auto_policy = 无` 的行，**本文不裁**，登记 [§7.4](../../../../../../composition/agent-dev-guide.md) 未决。

### 4.10 人这一侧的义务

> 依据的通用规范：[人的批准点「人这一侧的义务」](../../../../../../../dev-agent-standards/approvals.md)

⚠ **不只是执行者有纪律。人这边同样有，而且被违反时后果更大——因为 agent 会照做。**

| 人的义务 | 违反会怎样 |
| --- | --- |
| 请求写清**边界**：含什么、不含什么、不含的归谁 | 执行者会自行扩大范围，或漏掉本该做的 |
| 给**可判定的验收标准**，不给倾向性结论 | 候选向你的结论收敛，**等于白问** |
| 并行提案时**不泄露其他方案** | 独立信号退化成改写（[§2.11](../../../../composition/agent-dev-guide.md)） |
| 派活前先建好各自的 worktree 和命名分支 | 多个执行者写同一工作区，后写覆盖先写（[§3.6](../../../04-agent-execution/composition/agent-dev-guide.md)） |
| 收到「我不确定」时**不追问到它给出确定答案** | **逼出的确定性是编的** |
| 执行者说「没查过某处」时**当作真话对待** | 声明盲区的动力被消灭，下次它不说了 |

⚠ **最后一条最容易被忽略：盲区声明是自愿的，只要说了就受罚，很快就没人说了。**
这与 [§9.2](../../../../../../../dev-agent-standards/deliverables/uat/uat-rules.md)「如实写『不能排除』不扣分，隐瞒才扣」是同一条规则的两侧——
一侧约束写的人，一侧约束读的人。

**委派转移的是执行，不是最终责任。**派活时必须给出范围、权限、预算、停止条件和可验收
输出；对超范围、追加成本、不可逆动作和规范修改及时批准或拒绝；**亲自验收，或指定未参与
实施的验收方**（[§4.5](../../../../composition/agent-dev-guide.md) 责任归属表）。
