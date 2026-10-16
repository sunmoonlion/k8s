# Task 契约

> 提交信封由网页产出、持久化主档在工作台、结果由顾问在验收后封装。跨模块的接口形状，和 [通道](channels.md) 同类。

## 提交信封（求助）

```text
idempotency_key       调用者作用域内稳定
session_id            在哪个 Session 上求助；thread、项目目录、环境由它决定
profile_id            专家包 / Task Profile；用户所选；判不出交用户选，不默认
profile_version       可请求；最终版本由工作台固定
original_input        用户的问题与结构化输入（明文）
attachments[]         显式上传的资料引用（已入知识服务）
budget_limit          用户设定的费用上限（必填；有默认值）
requested_deadline    可选
client_context        locale、timezone 等非授权上下文
```

工作台从会话确定 `requester`、`tenant`、角色与数据作用域，不信任客户端自报。`tenant` 指付费客户单位，不是 Casdoor 的"组织"（后者只是账号分组）；落为 `sunmoonai` 组织下的顶层 Casdoor 群组，从登录令牌的 `groups` 映射（`D21`）；第一期一律 `default`，隔离按个人。幂等唯一性至少包含 `tenant + requester + profile + idempotency_key`；同键同摘要返回原 `task_id`，同键异摘要返回冲突。

## 持久化主档

```text
task_id, session_id, requester, tenant, idempotency_key, request_digest
task_profile_id, task_profile_version, expert_pack_version
original_input_ref, normalized_goal
thread_id, environment_id, project_root        执行绑定：哪个 thread、哪台机器、哪个目录
state, state_version, created_at, updated_at
workflow_version, current_step
acceptance_contract, execution_policy, budget
active_attempt_id, terminal_result_ref
retry_of, refresh_of, supersedes
waiting_reason, active_interaction_id
cancel_requested_at, cancel_requested_by
```

`state` 是事件流的受约束投影；`state_version` 用于比较交换。`thread_id` 是执行绑定不是真源（`C-D11`）。

## 完成契约

Task 进入 `QUEUED` 前必须固定：归一化目标；包含与不包含；输出 schema（含用户填写的结论栏）；可判定的验收条目；新鲜度、证据与引用要求；预算、deadline、重试、停止与取消策略；允许的能力、数据源、自动放行范围与外部副作用；必须由用户批准的动作；不确定性、降级与部分结果是否允许。

简单 Task 由固定 Profile 自动生成契约。只有歧义会实质改变结果、权限、成本或风险时才请求澄清。

## 结果信封

```text
task_id, task_profile_id, task_profile_version, expert_pack_version
result_id, result_version, result_type
structured_result, human_summary          研究底稿；结论栏由用户填写或标为用户草稿
evidence[] / citations[]                  每条带来源、时点、数据版本
limitations[] / uncertainty
data_as_of
artifacts[]                               入库版本 + 工作区路径
workspace_changes[]                       改了哪些文件、备份版本在哪
side_effect_summary[]
handback                                  做了什么、什么已核实、什么未知、工作区怎么恢复
accepted_attempt_id, environment_id
completed_at
```

失败、拒绝或取消结果至少包含稳定错误码、用户可理解的说明、是否允许重新提交、已发生副作用及其状态。界面文案不得泄露内部异常、路径、凭据或其他用户的信息。

## 步骤交回物

专家包把 Task 拆成步骤，每步一个 `step_contract`：

```text
step_id, step_version
input_refs[]          只以 Artifact 版本引用
method_text_ref       这一步的方法文本（版本化）
tools[]               这一步允许的 MCP 工具
output_schema
acceptance[]
evidence_rules
on_reject             重做本步、回到指定前一步、或交人
max_reworks
mode                  single | compete（第一期只允许 single；compete 时下面两项生效）
compete               { arms: 模型清单, judge: deterministic | acceptance_turn, objection: bool }
```

- 交回物是固定版本的 Artifact；重做产生新版本，不就地覆盖；
- 执行端不保证交回物满足 `output_schema`；格式合规由验收判定；
- 步骤不合格不等于 Task 失败：按 `on_reject` 处置；`max_reworks` 用尽交人（`AT-24`）；
- 步骤之间不得靠自然语言转述传递结果；下一步的输入只能是固定版本的 Artifact 与 turn 输入里的字段；
- 一步通常是一个 turn；顾问在 turn 结束后取产物、验收、决定下一步。
