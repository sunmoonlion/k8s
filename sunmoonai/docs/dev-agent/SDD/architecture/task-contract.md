# Task 契约

> 由产品合同搬入。提交信封由桌面应用产出、持久化主档在后端、最终结果信封由 runtime 产出——所以它是跨模块的接口形状，和 [通道](channels.md) 同类。

## 提交信封

桌面应用提交至少包含：

```text
idempotency_key       调用者作用域内稳定
profile_id            Task Profile 标识（用户所选，或本地预填经用户确认；缺省留给路由）
profile_version       可请求；最终版本由后端固定
original_input        用户原始文本与结构化输入（明文；不含本地资料正文）
local_refs[]          本地资料与工作区的稳定句柄（不上传内容，不含文件名）
target_device_id      可选；缺省由路由选择
client_context        locale、timezone、展示能力等非授权上下文
requested_deadline    可选
budget_limit          可选；用户设定的费用上限
```

后端必须从认证上下文确定 `requester`、`tenant`、角色和数据作用域，不信任客户端自报身份。幂等唯一性至少包含 `tenant + requester + profile + idempotency_key`。同一键重复且请求摘要相同时返回原 `task_id`；同一键不同摘要时必须返回幂等冲突，不能静默复用或另建 Task。

## 持久化主档

Task 至少持久化：

```text
task_id, requester, tenant, idempotency_key, request_digest
task_profile_id, task_profile_version
original_input_ref, normalized_goal
route_decision_ref, bound_device_id
state, state_version, created_at, updated_at
workflow_version, current_step         用哪一版步骤表、走到第几步；通用任务恒为单步
acceptance_contract, execution_policy
active_attempt_ids, terminal_result_ref
parent_task_id, coordination_task_id
retry_of, refresh_of, supersedes
waiting_reason, active_interaction_id
cancel_requested_at, cancel_requested_by
```

`state` 是事件流的受约束投影；`state_version` 用于比较交换，防止两个入口同时完成、取消或恢复 Task。原始输入是问题侧内容，明文持久化；`local_refs` 只有句柄，本地资料的内容与文件名不上传。结果正文按 §8.4 只存密文。

## 解释、边界与完成契约

Task 进入 `QUEUED` 前必须固定：

- 归一化目标：用户真正要什么结果；由已确认的类别与 Task Profile 模板确定性生成，只用任务文本，不得写入本地资料内容；
- 包含什么、不包含什么、不包含部分由谁处理；
- 输出 schema（研究底稿的结构，含由用户填写的结论栏）与客户端渲染契约；
- 可判定的验收条目；
- 新鲜度、证据与引用要求；
- 预算、deadline、重试、停止与取消策略；
- 允许的能力、数据源、自动放行范围与外部副作用；
- 必须由用户或授权角色批准的动作；
- 不确定性、降级与部分结果是否允许。

简单 Task 可以由固定 Profile 自动生成契约。只有歧义会实质改变结果、权限、成本或风险时才请求澄清，不得为填满栏目反复追问用户。

## 最终结果信封

成功结果至少包含（正文部分加密存放，§8.4）：

```text
task_id, task_profile_id, task_profile_version
result_id, result_version, result_type
structured_result, human_summary          研究底稿；结论栏由用户填写或标为用户草稿
evidence[] / citations[]                  每条带来源、时点、数据版本
limitations[] / uncertainty
data_as_of
artifacts[]
side_effect_summary[]
content_check_receipt                     本地内容检查的签名回执
accepted_attempt_id, device_id
completed_at
ciphertext_digest, key_id                 后端可见的元数据
```

失败、拒绝或取消结果至少包含稳定错误码、用户可理解的说明、是否允许重新提交、已发生副作用及其状态，以及仅供内部诊断的受限引用。界面文案不得泄露内部异常、路径、凭据或其他用户的信息。

## 步骤交回物

专业 Task 按 workflow 拆成步骤逐步派发。每个步骤在 Task Profile 的 `step_contract` 里声明：

```text
step_id, step_version
input_refs[]          输入，只以 Artifact 版本引用指定
output_schema         这一步交回物的结构
acceptance[]          可判定的验收条目
evidence_rules        这一步必须带的来源、时点与数据版本
on_reject             不合格的去向：重做本步、回到指定的前一步、或交人
max_reworks           本步的返工上限
```

- 步骤交回物是**固定版本的 Artifact**；下一步只以版本引用取用，上一步重做产生新版本，不就地覆盖；
- 执行端不保证交回物满足 `output_schema`：模型可能不受结构化输出约束、可能没有最终消息、产物也可能是工作区里的文件。**格式合规由验收判定，不由执行端声明**；
- 每一步按 §7.6 验收：需要读正文的检查在执行端加密前完成并进回执，后端核对回执并按 `acceptance[]` 做确定性判定；
- 步骤不合格不等于 Task 失败：按 `on_reject` 处置；`max_reworks` 用尽交人；
- 步骤之间不得靠自然语言转述传递结果；下一步的输入只能是固定版本的 Artifact 与派发内容里的字段。

