# 审批

> 由产品合同搬入。工具级在 runtime 与桌面应用之间闭环，Task 级经后端 Interaction——拆开写三份必然漂。

## 两层审批

| 层 | 对象 | 发起 | 处理处 | 决定与记录 |
| --- | --- | --- | --- | --- |
| **工具级** | 单条命令、单个文件修改、联网 | Codex → 审批回调 → runtime | 桌面应用本地窗口 | runtime 按策略自动放行、拒绝或交用户决定；结论摘要经 ① 上报存档 |
| **Task 级** | 澄清输入、计划批准、不可逆或对外动作、合并到用户工作区、预算追加、待审文档 | 后端 | 桌面应用审查窗口 | 后端落 Interaction，按 [`state-machine.md`](state-machine.md)「WAITING 与 Interaction」原子消费 |

两层各自的功能义务 `F-APPROVE-*` 在 [runtime](../submodules/0003-runtime/PRD/functions.md) 与 [桌面应用](../submodules/0002-desktop/PRD/functions.md) 各自的 `functions.md`。

## 工具级请求升级为 Task 级

不可逆命令、需要云端决定的网络访问等，执行上仍是 Codex 发出的一条审批请求，但结论由后端给出：

1. runtime 按清单识别这类请求，暂不回答，令其挂起；
2. runtime 经 ① 登记副作用意图，请后端创建 Interaction。**挂起的是这一条工具调用，因而是它所在的那个 Attempt**；
   Task 是否进入 `WAITING(APPROVAL)`，按 [状态机](state-machine.md)「只有没有任何 Attempt 能继续推进时 Task 才进入 `WAITING`」判——
   并行 Attempt 仍有一路可推进时，Task 保持 `RUNNING`，等待记录在对应 Attempt 上；
   ⚠ 创建 Interaction、登记副作用意图与状态转换**必须在同一个提交边界内**，否则崩溃后会出现
   「等待状态没有待决 Interaction」或「Interaction 已在而 Task 仍显示运行」；
3. 用户在审查窗口批准或拒绝；后端原子消费，经 ① 下发结论与幂等键；
4. runtime 核对结论对应的正是挂起的那条请求（请求摘要一致、租约与 fencing 有效）后回答 Codex；拒绝即回答拒绝；
5. 等待期间 runtime 照常续约，不开始新的工具调用；超时或断线时挂起的请求作废，恢复后由 Codex 重新发起。

⚠ 审批请求能否长时间挂起取决于 SDK；不能时先中断运行时 turn，批准后在同一运行时 thread 中开新的运行时 turn 继续。

## Task 级审查

审查窗口必须表达：

| 要素 | 内容 |
| --- | --- |
| 问询定位 | Interaction、Task、适用的权力与合法转换、被询问的主体 |
| 待决内容 | 要决定什么、各选项的后果、证据等级与未知项 |
| 决定对象 | 每份文档的版本与摘要值、改动摘要；有验收条时附冻结的验收条与结论 |
| 时效 | 截止时间与目标状态版本；过期不等于拒绝，也不等于同意 |
| 决定记录 | 经鉴别的主体、响应、实际生效值、原建议与改动 |

- 窗口由主进程创建：必须先处理才能继续的作为模态子窗口；应用在后台时发系统通知；同一 Interaction 只开一个窗口；每次记录响应耗时与修改项数，只作观察，不自动放宽审批。

审查窗口的功能义务 `F-REVIEW-*` 在 [桌面应用的 `functions.md`](../submodules/0002-desktop/PRD/functions.md)。

## 被攻破的后端

后端派发的 Attempt 本身就是给 agent 的指令，被攻破的后端可以在自动放行范围内借 Attempt 让用户电脑执行命令。因此：

这一段的功能义务 `F-GUARD-*` 在 [runtime 的 `functions.md`](../submodules/0003-runtime/PRD/functions.md) 与 [`0002-router`](../submodules/0001-backend/SDD/modules/0002-router.md)。
