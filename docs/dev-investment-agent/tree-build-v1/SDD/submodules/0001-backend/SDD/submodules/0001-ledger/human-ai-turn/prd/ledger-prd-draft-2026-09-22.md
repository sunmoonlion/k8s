> 材料：2026-09-22 按旧 thread 机制写的账房 PRD 答（原 turn 0001 的 response.md），未定稿。
> 新机制下账房的需求应直接写成本目录上一级的 PRD/requirement.md，本文只作输入。

# 账房要满足什么

> 答 turn 0001。以什么为底：[`0001-ledger.md`](../../../../modules/0001-ledger.md)（边界）、
> [`blocks.md`](../../../../architecture/blocks.md)（八块怎么连、先做哪块）、上一层的
> [状态机](../../../../../../../architecture/state-machine.md)、[不变量与持久化记录](../../../../../../../architecture/invariants.md)、
> [Task 契约](../../../../../../../architecture/task-contract.md)、[核心对象](../../../../../../../architecture/objects.md)，
> 以及 [代码规则](../../../../../../../../rules/constraints.md)。取证时点 2026-09-22，`k8s` 仓 `87d29c50`。
>
> 本文只写**要什么、什么算满足**，不写怎么实现。上一层定的边界一处不动；边界上读不出答案的两处，在第十二节单列请上一层确认，答里按标明的假设推进。
>
> 用词按 [规范用语](../../../../../../../../../turn/glossary.md)：**必须** / **应该** / **可以** / ⚠。
> 事实、推断、假设分开标：未标的是从上层定稿直接引出的要求；「事实」是本次回读代码或文档核过的；「假设」是未核前提。

## 一、这一块是什么、不是什么（一句话）

账房是后端里**唯一有权改状态、写账的地方**：其余七块（含 `0008-competition`）把「决定」递过来，
它把决定**落成一次转换**——要么整个成立，要么什么都没发生。它不朝外、不决定、不投递、不读正文。

所以这一块的义务几乎都是「**别人的义务里，由存储与并发承担的那一半**」。
下面第二节逐条列出它承担的是哪一半，避免和主要承担方各写一份（`P1`）。

## 二、归这一块的义务

### 2.1 功能义务 `F-*`：承担「存储与并发」那一半

定义都在主要承担方那一份，ID 不变。这里只写账房要为它保证什么。

| ID | 主要承担方 | 账房必须保证的那一半 |
| --- | --- | --- |
| `F-ADMIT-01` | `0002-router` | 身份绑定、幂等占位、Task 建单、首事件**在一个提交边界内**落库；幂等账记作用域、键、请求摘要、`task_id`、首次与重复响应 |
| `F-ADMIT-02` | `0002-router` | `REJECTED` 是一次合法转换，带安全理由入账。协议层拒绝（未分配 `task_id`）**不产生任何记录** |
| `F-ADMIT-04` | `0002-router` | 路由决定记录（依据类型、规则集版本、命中规则、置信度与理由、所选设备、所选模型或多方分配、改判）与它引起的状态改**同提交** |
| `F-ADMIT-06` | `0002-router` | `WAITING(INPUT)` 与对应 Interaction 同提交（与 `F-INTERACT-01` 同一条要求） |
| `F-DISPATCH-01` | `0004-bridge` | outbox 行与进 `QUEUED`、建 Attempt **同事务**；未投递的行可被扫出，没有「状态说派了、表里没有」的窗口 |
| `F-DISPATCH-02` | `0004-bridge` | `task_id + attempt_id` 唯一；「标记已投递」幂等，重复标记不产生第二次事实 |
| `F-DISPATCH-04` | `0004-bridge` | `WAITING(DEVICE)` 带原因码；等待期间 outbox 行不丢、不重复 |
| `F-DISPATCH-03` `F-DISPATCH-05` `F-DISPATCH-06` | `0003-orchestrator` | workflow 游标**只在改状态的同一事务里改**；领域识别结论（命中领域、依据、置信度）作元数据入账，不进结果密文 |
| `F-INTERACT-01` | `0005-interrupt` | 创建 Interaction、登记副作用意图、Task 或 Attempt 进等待，**三者一个提交边界**；恢复时校验主体、`expected_state_version`、`subject_digest`、过期、幂等键，**原子标记消费**，同一令牌只能消费一次 |
| `F-INTERACT-02` | `0005-interrupt` | 消费与「消费之后要派什么」（outbox 行）同提交；后续投递失败时消费记录仍在、可恢复，不悬空 |
| `F-INTERACT-03` | `0005-interrupt` | 工具级审批只存**摘要、结论、决定来源、时间**；不进 Interaction 表，两条提交逻辑在存储上也分开 |
| `F-ACCEPT-04` | `0006-acceptance` | `acceptance_contract` 与 `task_profile_version` 进 `QUEUED` 后**不可改**；改动请求被拒绝并可观测 |
| `F-ACCEPT-05` | `0006-acceptance` | **`SUCCEEDED` 的原子提交**：终态、结果密文与元数据、证据、Artifact 关系、验收判定、预算结算、终态事件——一次转换，全成或全无；提交前对外读不到任何一部分 |
| `F-ACCEPT-06` | `0006-acceptance` | 独立工作区外的写入逐条进副作用账，且每条带批准引用 |
| `F-DELIVERY-02` | `0007-delivery` | 事件的形状：`event_id`、Task 内单调 `sequence_no`、`payload_schema_version`、时间、主体、可见级别；缺一条拒收 |
| `F-DELIVERY-03` | `0007-delivery` | 事件**提交后**才对任何读者可见；没有「推了但没落」的可能 |
| `F-DELIVERY-04` | `0007-delivery` | 按 cursor 读：读者取到序号 n 之后，**不会再出现序号小于等于 n 的新事件**（见第八节「可见性」） |
| `F-DELIVERY-07` | `0007-delivery` | 终态与失败原因是结构化字段（`failure_code`、`retryable`、失败类别），不是文案 |
| `F-DELIVERY-10` | `0007-delivery` | Delivery 记录与 Task 终态分离；终态**没有出边**，任何来源的转换请求都被拒 |
| `F-CRYPTO-02` | `0002-desktop` 定义，后端承担 | 结果记录只有**密文、密文摘要、密钥标识、本地内容检查回执**；不存在任何能放明文或解密材料的字段 |
| `F-CRYPTO-07` | `0002-router` | 明文字段是**封闭 schema**，未声明字段一律拒收（`C-C5`）；账房拦得住形状，拦不住内容——内容由 router 校验 |
| `F-EXEC-04` / `I10` | `0003-runtime` | 预算账：Task 总额、预留、已用、释放、追加批准与拒绝原因；**派发时预留、验收时结算**；子 Task 的预留从父额度出，不凭空新增 |
| `F-GUARD-01` | `0003-runtime` | Task 固定 `task_profile_version`、`workflow_version`；Attempt 固定 `agent_profile_id/version`、`runtime_version`、`codex_version`、`model`、`model_provider`；升级 Profile 不改已受理 Task 的记录 |

⚠ `F-DELIVERY-12`、`F-REVIEW-07` 所需的领域识别结论，账房只作**元数据**保存（`F-DISPATCH-06` 那一行），怎么下发是 `0007-delivery` 的事。

### 2.2 不变量 `I*`：账房是这些的载体

[责任投影](../../../../../../../architecture/ownership.md) 把 `I1` 至 `I15` 与 `I17` 的「存储与并发载体」给了后端；在后端里，载体就是账房。

| ID | 账房必须做到 |
| --- | --- |
| `I1` | 原始输入、调用者、受理时间、Profile 版本一经写入**不可覆盖**；后续解释只能追加 |
| `I2` | 幂等唯一性以「租户 + 请求方 + Profile + 幂等键」为作用域；同键同摘要返回原 `task_id`，同键异摘要返回冲突，**两种情况都不写第二条** |
| `I3` | 每条记录都带 `requester`、`tenant`，让每个读写面能重新校验授权；校验本身在各面，不在账房 |
| `I4` | 所有状态转换经**同一个转换函数**集中校验；事件只追加，不更新、不删除；`state` 是事件流的投影 |
| `I5` | Task 与 Attempt 的终态**无出边**；重新处理只能建新实体（`retry_of` / `refresh_of` / `supersedes`） |
| `I6` | `SUCCEEDED` 提交时结果密文与验收证据已在**同一事务**内；不存在「成功了但结果还没到」的读窗口 |
| `I7` | 通知与连接失败不构成任何合法转换的输入 |
| `I8` | Attempt 终态**不自动**引起 Task 转换；Task 走向何处是 `0003-orchestrator` 另发一次请求 |
| `I9` | 副作用账每条有稳定幂等键、状态、回执、补偿信息；批量记录带批次与「补偿依赖本地」标记 |
| `I10` | 预算账覆盖 Task 的全部 Attempt、子 Task 与工具调用；子级只是父级的预留 |
| `I11` | 证据账每条带主张、来源、时点、数据版本、转换、生成者、Attempt 与验收者、执行内容指纹、口径表版本 |
| `I12` | 事件、账、日志投影的 schema 里**没有**能装凭据、正文、文件名的字段 |
| `I13` | 账房是这些事实的**唯一写入面**；不存第二份可写副本（含图框架的 checkpoint） |
| `I14` | 带租约或 fencing 的写入，只在租约有效且 fencing 不落后时被接受；迟到写入被拒且可观测 |
| `I15` | 本块每条义务都有稳定 ID、代码位置与自动测试的登记（登记表由 SDD 产出，验收时对照，见第九节） |
| `I17` | 没有解密能力：不存私钥、不存对称密钥、不存明文 |

另外三条不归后端，但账房有一小半：

- `I19`：执行端离线时暂存的材料，**上报时**才由账房记账，记的是「上报时间」，不承认执行端自报的「发生时间」为权威时间；
- `I20`：不设能装本地资料内容与文件名的字段（与 `I12` 同一条形状要求）；
- `I18`：工具级审批结论只有存档面，账房上没有任何路径能把它变成 Task 级批准（与 `F-INTERACT-03` 同）。

### 2.3 验收矩阵里落在账房的

`AT-01` `AT-02`（幂等）、`AT-04`（`REJECTED`）、`AT-07`（令牌原子消费）、`AT-08`（投递窗口）、
`AT-09` 的后端侧（迟到写入被拒）、`AT-10` `AT-11`（Attempt 终态不等于 Task 终态）、`AT-12`（副作用账）、
`AT-13`（预算耗尽的 Attempt 终态与 Task 去向可记）、`AT-14`（取消竞争只有一个终态）、`AT-15`（服务重启可重建）、
`AT-18`（通知失败终态不变）、`AT-19`（事件 schema 版本）、`AT-20`（Profile 版本固定）、`AT-21`（子 Task 预算不放大）、
`AT-22`（协调 Task 的图与 `supersedes`）、`AT-38`（熔断所需的连续失败计数可从账推出）、`AT-39`（步骤交回物是固定版本 Artifact）。

## 三、输入与输出

### 3.1 谁来请求什么

账房只有一种输入：**转换请求**。谁发、请求什么，按块列出；它们**不写表**，只发请求。

| 从谁 | 请求什么 |
| --- | --- |
| `0002-router` | 建单（含幂等占位与首事件）；`RECEIVED → VALIDATING`；固定契约并进 `QUEUED`；`REJECTED`；进 `WAITING(INPUT)` 并建 Interaction；写路由决定 |
| `0003-orchestrator` | 建 Attempt 并进 `RUNNING`（含预算预留、派发意图落 outbox）；推进游标；Attempt 交回后的 Task 去向（重排 `QUEUED`、`WAITING(<原因>)`、`FAILED`）；`escalate` 改判入账；子 Task 与协调 Task 的建立与 `supersedes`；领域识别结论入账 |
| `0004-bridge` | 标记 outbox 行已投递；租约签发、续约、撤销、提高 fencing；执行端回传的事件、副作用意图与回执、用量、工具级审批摘要、结果密文与回执——**每条都带租约与 fencing** |
| `0005-interrupt` | 建 Interaction 并进等待；消费 Interaction 并给出恢复后的去向；批准后执行的副作用意图与回执 |
| `0006-acceptance` | 验收判定入账；`SUCCEEDED` 的原子提交（结果、证据、Artifact 关系、判定、预算结算、终态事件）；验收失败时的 Attempt 终态 |
| `0007-delivery` | Delivery 记录（目标、通道、cursor、尝试、确认或失败）⚠ 见第十节 |
| `0008-competition` | 候选冻结（绑不可变提交与摘要）、处置记录、验收方算出结果、异议记录 |
| 各块的扫描 | 只读：非终态 Task、非终态 Attempt、过期租约、未投递 outbox 行、到期 Interaction、未结算预算 |
| 管理后台（经 ⑦） | 只读元数据；设备吊销这类写入按第十节的归属定 |

### 3.2 一次转换请求至少带什么

- 对象与**当前认为的状态版本**（`state_version`）：用于比较交换；
- 请求方与请求身份（哪一块、以谁的名义）；
- 请求的幂等键（同一请求重发时不产生第二次事实）；
- 带租约的写入另带 `attempt_id`、`lease_owner`、`fencing_token`；
- 要写的事实：状态目标、要追加的事件、要写的账目、要落的 outbox 行。

### 3.3 一次转换请求至少回什么

- 结果三选一：**applied**（这次成立）、**replayed**（幂等重放，返回首次的结果）、**rejected**（未成立，什么也没写）；
- applied 时：新的 `state_version`、分配的 id（`task_id`、`attempt_id`、`interaction_id`、事件序号范围、outbox 消息 id、副作用幂等键）；
- rejected 时：**机器可读的原因**，至少能区分：版本冲突、非法转换、对象已终态、fencing 落后或租约失效、幂等冲突（同键异摘要）、预算不足、Interaction 已消费或已过期或摘要不符或主体不符、schema 拒收（未声明字段）、存储不可用。原因不带正文、不带别人的数据。

### 3.4 读出去的东西

其余块与管理后台读账房，读到的**形状稳定、版本化**：Task 主档、Attempt、事件（按 cursor）、四本账、Interaction、outbox 未投递行、路由决定、结果的元数据。读不到：结果正文（本来就没有）、设备私钥、模型 key（本来就没有）。

## 四、正向场景：做对了是什么样

| # | 场景 | 做对了的样子 |
| --- | --- | --- |
| S1 | **建单** | router 一次请求带身份、信封、请求摘要。结果：幂等账一行、Task `RECEIVED` 一行（`state_version = 1`）、首事件 `sequence_no = 1`——三者同时出现或同时不出现。同键同摘要再来：回原 `task_id`，事件表**不多一条**。同键异摘要：回幂等冲突，**什么也不写** |
| S2 | **契约固定并入队** | 归一化目标、`acceptance_contract`、`execution_policy`、预算总额、路由决定、`task_profile_version` 与 `workflow_version` 随 `VALIDATING → QUEUED` 一次落下。此后这几项不可改 |
| S3 | **派发** | orchestrator 请求「建 Attempt + 预留预算 + 进 `RUNNING`」。结果：Attempt `CREATED`、预算账多一条预留、outbox 多一行派发意图、Task `RUNNING`、游标不变——同一事务。bridge 之后来「标记已投递」，重复标记回 replayed |
| S4 | **带租约的回传** | bridge 转来执行端的事件，带 `attempt_id`、`lease_owner`、`fencing_token`。租约有效且 fencing 等于当前值：事件追加、序号递增、Attempt 状态按请求转。执行端重发同一批（同幂等键）：replayed，不重复追加 |
| S5 | **续约与失去租约** | 续约成功：过期时刻后移，不产生 Task 事件。到期未续：扫描能扫出「过期租约的 Attempt」，由 orchestrator 请求 `PAUSED`；重连对账时 fencing 未变则 `RUNNING`，已变则 `ABANDONED` 并由新 Attempt 接续 |
| S6 | **等人** | interrupt 请求「建 Interaction + 登记副作用意图 + Attempt 进 `WAITING`（Task 是否进 `WAITING(APPROVAL)` 由请求方按状态机判）」。三者同一事务。用户响应：消费请求带令牌、`expected_state_version`、`subject_digest`。全部匹配：`consumed_at` 置位、状态转换、后续派发落 outbox——同一事务。同一令牌第二次：rejected（已消费） |
| S7 | **验收通过、成功** | acceptance 请求 `SUCCEEDED`，带结果密文、密文摘要、密钥标识、内容检查回执、证据、Artifact 关系、验收判定、预算结算。**全部同一事务**。提交之前，任何读者读这个 Task 都还是 `RUNNING` 且没有结果；提交之后，一次读能取到全部 |
| S8 | **验收不通过** | Attempt `FAILED(retryable)` 或 `COMPLETED` 但判定为不合格入账；Task **不动**；orchestrator 另发请求决定 `QUEUED`、`WAITING` 或 `FAILED`。`acceptance_contract` 一字不改 |
| S9 | **取消** | 先落取消意图（`cancel_requested_at/by`）并提高 fencing——这一步不是终态。随后 orchestrator 走完收敛，请求 `CANCELLED`，附已发生副作用的处置。若 `SUCCEEDED` 抢先提交，`CANCELLED` 请求 rejected（对象已终态），取消方能看到「完成先到」 |
| S10 | **重启** | 进程无内存状态。重启后各块扫描：非终态 Task、非终态 Attempt、过期租约、未投递 outbox、到期 Interaction——每一项都是一次普通转换请求。不存在「只在内存里」的事实 |
| S11 | **按 cursor 读事件** | delivery 从 cursor n 读，得到 n 之后已提交的事件，序号严格递增。之后再读，不会出现序号 ≤ n 的「新」事件 |
| S12 | **预算** | 派发时按 Attempt 预留；Attempt 终态时把自报用量记为「已用（自报）」、未用部分释放；`SUCCEEDED` 或其他 Task 终态时结算。预留超过可用额度：rejected（预算不足），由 orchestrator 决定 `WAITING(APPROVAL)` 还是 `FAILED`。子 Task 建立时的预留从父额度扣，父额度看得到子级占用 |
| S13 | **副作用** | 先登记意图拿幂等键；回执到了写回执与状态；结果未知的写「未知」而不是猜；补偿完成写补偿状态。批量记账：一个运行时 turn 一条意图、一条回执，带批次与「补偿依赖本地」 |
| S14 | **证据** | 每条主张带来源、时点、数据版本、转换、生成者、Attempt；验收后补验收者；执行内容指纹与口径表版本随 Attempt 一起落 |
| S15 | **协调 Task** | 图（节点、边、并行组、责任、`graph_version`）作为一个 `COORDINATION` Task 的主档落；验收通过即 `SUCCEEDED`；新图建新 Task 并 `supersedes` 旧图，被协调 Task 只改 `coordination_task_id` |

## 五、反向场景：不对的时候该是什么样

| # | 情形 | 必须发生的 | 不得发生的 |
| --- | --- | --- | --- |
| N1 | 请求的转换不在合法边内（如 `SUCCEEDED → RUNNING`、`RECEIVED → RUNNING`） | rejected，原因「非法转换」；对象不变 | 「尽量执行」、部分写入 |
| N2 | `state_version` 与当前不符 | rejected，原因「版本冲突」；请求方重读再来 | 后写覆盖先写 |
| N3 | fencing 落后或租约已过期 | rejected，原因可区分；**被拒次数与原因可观测**（`AT-09` 要证据） | 静默丢弃；接受后再回滚 |
| N4 | 通知失败、连接断开 | 只有 Delivery 记录变化 | Task 或 Attempt 状态变化 |
| N5 | Attempt 失败 | 只有 Attempt 终态 | Task 自动 `FAILED` |
| N6 | 同幂等键异摘要 | 幂等冲突，**不写任何东西** | 静默复用、另建 Task |
| N7 | 同令牌重复消费、过期、跨 Task、跨用户、摘要不符 | rejected，各自原因可区分；首次消费结果不变 | 第二次生效；过期被当成拒绝或同意 |
| N8 | 事务中途崩溃（进程被杀、存储断开） | 整个请求视为未发生；重启后扫描看到的是请求前的状态 | 半状态：`WAITING` 无 Interaction、Interaction 有而 Task 仍 `RUNNING`、`QUEUED` 无 outbox 行、outbox 有行但状态未改、`SUCCEEDED` 无结果 |
| N9 | 存储不可用 | 所有请求 rejected，原因「存储不可用」；**fail-closed** | 内存暂存、写到别处稍后补、先应答后落库 |
| N10 | 结果密文摘要与所交密文不符 | rejected | 以自报摘要为准入账 |
| N11 | 请求带未声明字段，或事件缺 `payload_schema_version` 等必填 | rejected，原因「schema 拒收」 | 忽略多余字段后接受（多余字段可能就是正文或文件名） |
| N12 | 请求改 `acceptance_contract`、`task_profile_version`、原始输入 | rejected | 就地改写 |
| N13 | 预留超出可用额度 | rejected，原因「预算不足」，额度不变 | 允许负额度；自动追加 |
| N14 | 自报用量超过预留 | 记为「已用（自报）」并标超出，可观测 | 静默截断到预留值 |
| N15 | Task 已终态后 Attempt 结果才到 | Attempt 记终态（如 `ABANDONED`），Task 不动 | Task 被重开 |
| N16 | 请求方以「执行端本地记录」为权威时间回填 | 记上报时间；执行端时间只作自报字段 | 权威记账被执行端时间覆盖 |
| N17 | 扫描与在线入口对同一对象同时请求 | 只有一个 applied，另一个版本冲突 | 两个都 applied |
| N18 | 时钟回拨或跨实例时钟偏差 | 租约到期、fencing 先后的判断**不因此反转** | 已释放的租约复活；较新的 fencing 被判为旧 |

## 六、非目标：这一轮明确不做

- **不决定**：路由（`0002`）、下一步派什么（`0003`）、做对没有（`0006`）、哪一份更好（`0008`）——账房只落已做出的决定；
- **不投递、不通知**：outbox 的表在这里，读它送出去的是 `0004`，通知是 `0007`；
- **不读正文、不做内容检查**：结果是不透明密文；内容检查在执行端，回执在这里只是一条记录；
- **不验签**：Profile、派发、方法的签名验证在各自承担方；账房只记版本引用；
- **不做保留与回收**：事件与账只追加；GC、归档、保留期本轮不做（现状：无自动回执与租约墓碑 GC，见 [项目总览](../../../../../../../../../../project-guide/overall-architecture.md) §9.2），但**必须能在不动业务语义的前提下后加**；
- **不做指标与告警接线**：账房必须能算出被拒次数、未投递 outbox 最老时间、过期租约数、到期 Interaction 数（第八节），但采集与告警按 [`repos/k8s.md`](../../../../../../../../../../project-guide/repos/k8s.md)「监控与告警」另做；
- **不引入图执行框架的 checkpoint**：现有 LangGraph 的四张 checkpoint 表不属于账房，也不能成为它的一部分（`I13`）；现有 Pilot 链的去留见第十节；
- **不做团队协作、跨设备共享、多租户分库**（后置能力）；
- **不做管理后台**：只保证元数据可读。

## 七、约束

### 7.1 上一层已经定死的

- **不朝外**：没有任何客户端或执行端能直接到账房；一切经其余七块；
- **只有它能动库**：其余七块不写表，只发转换请求；所有入口共用同一个转换函数，以状态版本比较交换；
- **派发与状态改同事务落 outbox**；
- **预算派发时扣、验收时结算，都在这里**；
- **状态词只有那一套**（`P0`）：Task 九个、Attempt 九个，见 [状态机](../../../../../../../architecture/state-machine.md)；workflow 游标不是状态；任何 Profile 不得新增状态词；
- **不驻留内存状态**，重启扫非终态恢复；
- 四本账**必须落 PostgreSQL**（`C-A3`）；一个逻辑库、一条迁移链、独立 Job 执行迁移（`C-D2` `C-D6` `C-D7` `C-D8`）；
- 领域概念不进它的接口（`C-A5`）：它只认 Task、Attempt、Interaction、Artifact、Event、Side Effect、Delivery 这套词，没有「持仓」「研报」。

### 7.2 只对这一块成立的

- **全成或全无是它的全部意义**：任何一次转换请求要么整个成立要么整个不成立；不接受「先写状态、稍后补事件」这类分两次的请求形状；
- **拒绝是正常结果，不是异常**：版本冲突、fencing 落后、幂等重放都是可预期的输出，请求方据此行动；账房自己不重试；
- **拒绝可观测**：至少 fencing 落后、租约失效、非法转换、版本冲突四类被拒能按 Task 与时间统计——没有它，`AT-09`「迟到写入被拒绝」拿不出证据；⚠ 载体（审计表还是指标）是 SDD 的事；
- **事件不带正文**：事件 payload 只能装元数据与引用，不装 Artifact 内容、不装结果片段（`objects.md`：Event「不含结果正文」）；
- **时间与序**：Task 内事件序号单调；fencing 在同一 Task 内单调、**比较不依赖时钟**；租约到期用**一个**时间源判定（见第十节）；
- **能力状态如实**：本块的每条义务在 [四个词](../../../../../../../../../../project-guide/overall-architecture.md) 里处于哪一级（defined / wired / deployable / runtime-verified）随实现登记，不以「表在」当「接线了」。

## 八、非功能

| 项 | 要求 | 怎么判 |
| --- | --- | --- |
| 一致性 | 优先于吞吐。任何转换请求的可见效果都是提交后的完整效果 | 并发与故障注入测试（第九节） |
| 并发 | 同一对象的两个入口同时请求，恰好一个成立 | 并发测试可复现 |
| 可见性 | 读者按 cursor 读到序号 n 后，不会再看到序号 ≤ n 的新事件；提交前读不到任何部分效果 | 并发读写测试 |
| 恢复 | 重启后**零**丢失：所有非终态对象、未投递 outbox、到期 Interaction、过期租约都能被扫出 | 重启测试（`AT-15`） |
| 可观测 | 能算出：被拒转换按原因计数、未投递 outbox 最老时间、过期租约数、到期未处置 Interaction 数、未结算预算数 | 每项有一条能跑出非平凡结果的读法 |
| 容量 | 事件与账只增；单 Task 事件数、Attempt 数上限由 Profile 的执行策略给出，账房不设隐性上限 | ⚠ 上限值未定，见第十节 |
| 延迟 | 一次转换请求的耗时可测量、可按类型统计 | ⚠ 阈值未定，见第十节 |
| 安全 | schema 上没有能装凭据、正文、文件名的字段；每条记录带 `tenant` 与 `requester` | schema 审查 + `AT-28` `AT-31` 的后端侧 |

## 九、什么算满足

**验收口径**：下面每一条都能写出一条跑得出非平凡结果的命令或测试；判不了的停在 `undecidable`。测试层次按 [IMP 规则](../../../../../../../../../turn/imp/message-rules.md)。

| # | 判据 | 怎么验 | 对应 |
| --- | --- | --- | --- |
| A1 | 同作用域同键同摘要只建一个 Task，事件表只有一份首事件；同键异摘要返回冲突且零写入 | L1 + L2：并发 N 次同请求 | `AT-01` `AT-02` `I2` |
| A2 | 建单的三样（幂等行、Task 行、首事件）在故障注入下同生同灭 | L5：在三者之间任一点杀进程，重启后要么全有要么全无 | `F-ADMIT-01` |
| A3 | 合法边之外的每一条转换请求都被拒，且对象不变；合法边内的每一条都能成立 | L1：枚举状态机全部 9×9 与 Attempt 全部边，正反例齐全 | `I4` `I5` `P0` |
| A4 | 终态对象对任何请求（含通知失败路径）都不变 | L1 + L2 | `I5` `I7` `AT-18` |
| A5 | `QUEUED`/`RUNNING` 与 outbox 行同生同灭；未投递行可扫出；标记已投递幂等 | L5：状态改与 outbox 之间杀进程 | `F-DISPATCH-01` `F-DISPATCH-02` `AT-08` |
| A6 | fencing 落后或租约失效的写入被拒，且被拒事实可查 | L2 + L5：老执行端迟到写入 | `I14` `AT-09` |
| A7 | Interaction 创建与等待状态同生同灭；令牌只消费一次；重复、过期、异键、跨 Task、跨用户、摘要不符各自被拒 | L1 反例齐全 + L2 并发消费 | `F-INTERACT-01` `AT-07` |
| A8 | `SUCCEEDED` 的全部组成部分同一事务；提交前任何读者读不到其中任何一部分 | L5：在各组成部分之间杀进程；并发读 | `F-ACCEPT-05` `I6` |
| A9 | `acceptance_contract`、`task_profile_version`、原始输入进 `QUEUED` 后改不动 | L1 | `F-ACCEPT-04` `I1` `AT-20` |
| A10 | 取消意图先于 `CANCELLED` 落；完成与取消并发只有一个终态成立 | L2 并发 | `AT-14` |
| A11 | Attempt 任一终态都不引起 Task 转换 | L1 | `I8` `AT-10` `AT-11` |
| A12 | 预算：预留不超可用额度；子 Task 预留从父额度扣；自报超出被标出不截断；终态时结算 | L1 + L2 | `I10` `AT-13` `AT-21` |
| A13 | 副作用账：同意图重复登记回同键；未知状态可存；批量记录带批次与标记 | L1 | `I9` `AT-12` |
| A14 | 事件：必填字段缺一拒收；Task 内序号严格递增；cursor 之后不出现更小序号 | L1 + L2 并发追加与读取 | `F-DELIVERY-02` `F-DELIVERY-04` `AT-16` 后端侧 `AT-19` |
| A15 | 重启后非终态 Task、Attempt、过期租约、未投递 outbox、到期 Interaction 全部能扫出，数量与重启前一致 | L5 | `AT-15` |
| A16 | 存储不可用时全部请求被拒，没有任何请求被「接受后补写」 | L5：断存储 | N9 |
| A17 | schema 里不存在能装明文、文件名、凭据、私钥的字段；未声明字段拒收 | 静态审查 + L1 | `I12` `I17` `I20` `F-CRYPTO-02` `F-CRYPTO-07` |
| A18 | 密文摘要与所交密文不符时拒收 | L1 | N10 |
| A19 | 时钟回拨不使已释放租约复活、不使 fencing 先后反转 | L5 注入时钟偏差 | N18 |
| A20 | 本块每条 `F-*`/`I*` 在登记表里有代码位置与测试；表中没有「未实现但写成已实现」 | 人工对照 + 测试守着登记表（现有 `test_dormant_capabilities.py` 的做法） | `I15` |
| A21 | 迁移链单链线性、独立 Job 执行、`test_kernel_invariants.py` 清单一致 | 现有 L1 | `C-D6` `C-D7` `C-D8` |

**整份的结论**：A1 至 A21 全 `pass` 才算满足；任一 `fail` 即 `fail`；有 `undecidable` 无 `fail` 停在 `undecidable`。
A20 是「规范有没有落成机制」（`P5`）的总判据，它不过，其余过了也只是文字。

## 十、允许的不确定性：可以先不定，以及不定会影响什么

| 项 | 现状 | 不定会影响什么 | 建议归谁 |
| --- | --- | --- | --- |
| **「库」的范围** | 上层说「只有它能动库」，但账房列的东西是状态机、事件、四本账、outbox；[持久化记录](../../../../../../../architecture/invariants.md) 另有**设备**（公钥、配对、在线、吊销）与 **Delivery**（cursor、尝试）。设备身份归 `0004-bridge`，Delivery 归 `0007`——它们写不写表？ | 影响 `0004` `0007` 的 PRD 那一栏「给谁什么」。**本答按假设推进**：⚠ 设备注册、吊销与 Delivery 记录都是「账」（`I13`），经账房；设备**在线状态**是易变的连接事实，不是账，不经账房。请上一层确认或改判 | 上一层 `blocks.md` |
| **现有表怎么接**（`agent_runs`、`agent_sessions`、`session_events`、`tool_side_effects`、`outbox_message`、`inbox_message`、`outbox_dead_letter`、`agent_execution_leases`、四张 checkpoint 表） | 现有 run 状态机（`created/running/waiting/completed/failed/cancelled/budget_exceeded`，**事实**，`app/domain/agent/runtime.py`）与目标 Task 状态机不同构；现有 Pilot 链仍在跑 | 影响迁移形状与共存期：是改造还是并行新建再切换。**PRD 只要求**：切换按 [代码规则](../../../../../../../../rules/constraints.md)「做数据迁移时」fail-closed，共存期不得出现两个可写真源；旧状态词不进新表 | SDD |
| **预算的维度与单位** | 现有 `RunBudget` 四维（步数、工具调用、模型调用、输入 token；**事实**）；目标写「总额、预留、已用、释放；步骤数、耗时、派发次数由后端控制；token 与费用自报」。费用币种、汇率、自报的可信度分级未定；与 `D13` `D18` `D23` 相关 | 预留与结算的字段形状 | 上一层或 `D23` 拍板；账房只要求每维都有「总额/预留/已用/释放」四个数 |
| **`D10b`** 并行 Attempt 是冗余还是竞争 | 未定 | **不影响账房**：两种形态账房都要能记 N 个活跃 Attempt、各自预留、各自终态；停止规则是 `0003`/`0008` 的事 | `decisions.md` |
| **拒绝的载体** | 要求被拒可观测，未定是审计表还是指标 | 影响 `AT-09` 的证据形态 | SDD |
| **事件序号是否允许空洞** | 要求单调与 cursor 之后无回填；密不密实未定 | 影响 delivery 判「无缺口」的方法（`AT-16`） | SDD，与 `0007` 一起定 |
| **时间源** | 租约到期、Interaction 到期用哪个时钟（存储时钟还是应用时钟） | `A19` 的做法 | SDD；现有 `docs/delivery-clock-semantics.md` 是参考（**事实**：文件存在，内容未据以定论） |
| **可见级别的取值** | `F-DELIVERY-02` 要求事件带可见级别；枚举未定 | 事件 schema 的一个字段 | `0007-delivery` 的 PRD |
| **执行内容指纹指什么** | `I11` 要求证据账带「执行内容的指纹」；指派发内容、工具调用序列还是别的 | 证据账的一个字段；账房只存摘要与算法标识 | `0003`/`0006` |
| **容量与延迟阈值** | 未定 | 第八节两项的数值 | 人定；本答不替它拍 |
| **保留期** | 本轮不做 GC | 长期磁盘；不影响语义 | 后置 |

## 十一、在什么基础上（本次核过的事实）

- **事实**：`investment-backend` 迁移链 7 个版本线性（`20260708_0001` … `20260911_0007`），目录 `app/alembic/versions/`；
- **事实**：现有 run 状态机四终态、出边为空（`RUN_STATUS_TRANSITIONS`）；`RunBudget` 是内存态 pydantic 模型；两条生产链不调用它（`project-guide/repos/investment-app.md` §4.5，2026-09-13 复核，本次未重跑 `test_dormant_capabilities.py`）；
- **事实**：共享 Outbox/Inbox、执行租约、死信 `outbox_dead_letter` 已在源码接线（`docs/durable-delivery-luna.md`）；[需求](../../../../../../../../PRD/requirement.md)「已经有的，要复用」要求账房**建在它上面，不重造**；
- **推断**：现有 `agent_runs` 的 `session_id + idempotency_key` 与 Pilot 的 `owner_actor_id + idempotency_key` 两套幂等键，都不等于目标的「租户 + 请求方 + Profile + 幂等键」，幂等账要重定义作用域；
- **假设** ⚠：现有 `agent_execution_leases` 的 epoch 语义可以承担 fencing，未据代码逐行核实——SDD 时核。

## 十二、请上一层确认的两处

不是推翻边界，是边界上读不出答案：

1. **「只有它能动库」的「库」是整个逻辑库，还是列出的那几样**——见 第十节第一行。本答按「整个逻辑库里凡是账的都经账房、易变的连接事实不经」推进；若上一层意在后者，`0004` 与 `0007` 的 PRD 里「给谁什么」要另加一栏「自己写什么表」，而 `I13` 的「唯一写入面」就要按表分别登记；
2. **Interaction 的「创建与原子消费」写在 `0005-interrupt` 的承担里，同时「只有账房能动库」**——本答的读法是：`0005` 决定问什么、问谁、何时过期、待决对象是什么，账房保证创建与消费各是一次原子转换。两块的文档措辞一致后，A7 才有唯一的所有者。
