# Profile、Artifact 与扩展

> Task Profile 与 Agent Profile 的契约。**后端定、runtime 按它限定能力**（`F-EXEC-12`）、桌面按它渲染。

## Task Profile 与 Agent Profile

Task Profile 是版本化产品契约：

```text
profile_id + version
input_schema / output_schema / client_renderer_contract
normalization_rules
required_context / artifacts
acceptance / evidence / freshness rules
content_check_rules                   本地内容检查规则（含 F-POS-04）
allowed_capabilities / data sources
default budget / retry / approval / privacy policy
device_policy                         是否允许改派设备
workflow_ref                          专业 Profile 对应的 workflow
step_contract                         workflow 各步骤的输入、输出 schema、验收与返工去向（[步骤契约](../submodules/0001-backend/SDD/modules/0003-orchestrator.md)）
```

Agent Profile 声明执行能力：工具绑定、权限边界、自动放行范围、方法、记忆策略与支持的 Task Profile；签名发布（F-GUARD-01）。Task 固定 Task Profile 版本；每次 Attempt 记录所选 Agent Profile 与运行时版本。升级任一 Profile 不得静默改变已受理 Task 的解释或历史结果。

新增领域应新增 Task Profile、相容的 Agent Profile 与 workflow，不修改通用状态语义。确需改变通用骨架时，必须先通过有证据与迁移方案的规范修订（§15）。

## 通用与专业 Profile

- **通用 Profile**：能力收紧；只自动放行只读动作与独立工作区内的写入；不开领域工具；
- **专业 Profile**：对应一个 workflow，带领域工具、方法、验收与内容检查规则。

## Profile 示例

| Profile | 至少固定 |
| --- | --- |
| `DATA_QUERY` | 对象范围、指标口径、单位、币种、复权、时间区间、频率、时区、截至时点、数据源、缺失规则、结果形态、查询与转换链、引用 |
| `RESEARCH` | 研究问题、资料范围（本地资料、自有数据、公开资料）、时间边界、证据等级、反证、覆盖要求、不确定性、引用格式、研究底稿结构与结论栏 |
| `ACTION` | 目标、授权主体、预期副作用、动作幂等键、批准点、回执、补偿与不可逆声明 |

这些是示例，不是已冻结的业务契约；每个 Profile 的第一项开发工作单元必须用真实输入、输出、渲染与验收用例确认字段，之后才发布首个版本。

