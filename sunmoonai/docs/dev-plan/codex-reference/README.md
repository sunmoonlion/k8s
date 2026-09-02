# Codex 独立源码研究索引

> 研究日期：2026-08-28

本目录是 Codex 对本机源码的独立阅读结果。其他助手目录只用于确认题目清单；正文、结构、判断和建议均不以其他助手的文档为依据，也不引用它们。

## 研究基线

| 仓库 | 本地提交 | 用途 |
| --- | --- | --- |
| `/home/zymun/repo/codex` | `3929c99a97` | 多 Agent、上下文继承、权限与沙箱 |
| `/home/zymun/repo/SQLBot` | `59ca0970` | Text-to-SQL 产品链与安全边界 |
| `/home/zymun/repo/WrenAI` | `49a6e7f3` | 语义层、MDL、查询执行与 Agent SDK |
| `luna/investment-app` | `535736d` | 目标 App 父仓与子模块锁 |

`luna/investment-app` 锁定 backend `175a1d7`、admin `4a7053b`、web `e463809`。由于该工作树的子模块未初始化，源码从 `/home/zymun/master/investment-app` 阅读；其中 backend `ad74a54` 和 admin `44912ab` 相比锁定提交仅修改文档/脚本中的仓库根路径，相关运行代码无差异，web 与锁定提交一致。

## 文档

- [Codex 编排评估](./codex-orchestration-assessment-codex.md)
- [Codex 动态图结论](./codex-dynamic-graph-findings-codex.md)
- [Codex 沙箱扩展建议](./sandbox-extension-advice-codex.md)
- [Investment Agent 架构评估](./investment-app-agent-architecture-codex.md)
- [SQLBot 源码评估](./sqlbot-codex.md)
- [WrenAI 金融分析集成建议](./wrenai-financial-analysis-integration-codex.md)

## 证据规则

- “已实现”只用于源码或测试可直接证明的能力。
- README/注释表达的路线但源码尚不完整时，标为“规划”或“仓库自述”。
- 方案建议与现状事实分开写，不把建议伪装成现状。
- 源码引用采用本机绝对路径和行号，便于在当前环境复核。
