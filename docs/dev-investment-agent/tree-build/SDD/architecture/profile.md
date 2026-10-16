# Profile 与扩展

> Task Profile 是委托的产品契约；专家包是执行它的方法（[方法](methods.md)）。工作台定，网页按它渲染，沙箱按它限定能力。

## Task Profile

```text
profile_id + version
input_schema / output_schema / renderer_contract
normalization_rules
required_context / attachments
acceptance / evidence / freshness rules
positioning_check_rules              F-POS-04 的确定性检查
allowed_capabilities / data sources
default budget / retry / approval policy
sandbox_policy                       顾问驾驶时要求的沙箱模式（不得高于本地上限）
expert_pack_ref                      执行它的专家包
```

Task 固定 Task Profile 版本与专家包版本；每次 Attempt 记录 Codex 版本与代理版本。升级任一版本不得静默改变已受理 Task 的解释或历史结果（`AT-17`）。

新增领域是新增 Task Profile 与专家包，不修改通用状态语义。确需改变通用骨架时，先过有证据与迁移方案的规范修订（[改判](../../../turn/approvals.md)）。

## 第一层没有 Profile

用户自驾不建单、不走 Profile。第一层的配置是 thread 级：模型、`approvalPolicy`、沙箱模式（不高于本地上限）。

## Profile 示例

| Profile | 至少固定 |
| --- | --- |
| `DATA_QUERY`（最小实例） | 数据集、指标口径、时间区间、结果形态、查询链、`truth_queries` 格式 |
| `RECONCILE`（第一切口） | 公司与报告期、附注表清单、三大表版本、勾稽规则集版本、差异清单 schema、引用格式、结论栏留空 |
| `RESEARCH` | 研究问题、资料范围、时间边界、证据等级、覆盖要求、底稿结构与结论栏 |

示例不是冻结契约；每个 Profile 的第一项开发工作单元必须用真实输入、输出、渲染与验收用例确认字段，之后才发布首个版本。
