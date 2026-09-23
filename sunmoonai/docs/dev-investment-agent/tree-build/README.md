# `tree-build/`

**这个项目要建什么、切成哪些块、每块的定稿与委托记录。**
一条求助怎么走完九站见 [`../pipeline.md`](../pipeline.md)；一问一答怎么走见 [`../turn/`](../turn/README.md)。

> 2026-09-23 从头重写。上一棵树在 [`../tree-build-v1/`](../tree-build-v1/README.md)（tag `tree-build-v1-retired-2026-09-23`），只作取证，不再维护。
> 重写依据：[合并稿](human-ai-turn/prd/discussion-final.md) §一到§五，以及 §六 的三项改判（架构 C、隐私不作约束、界面回到网页）。

| | 是什么 |
| --- | --- |
| [`PRD/requirement.md`](PRD/requirement.md) | **先读这一份**：产品是什么、两层决策权、六条前提、整体功能、切块、在什么基础上开发 |
| [`PRD/value.md`](PRD/value.md) | 三元组、四臂检验、卖点与入口分开、评测一等公民、`F-POS-*`、第一切口 |
| [`PRD/knowledge.md`](PRD/knowledge.md) | 数据与用户资料 |
| [`PRD/acceptance.md`](PRD/acceptance.md) | 产品验收矩阵 `AT-01`–`AT-28` |
| [`decisions.md`](decisions.md) | 待定决策 `D1`–`D16` 与未验证事项 |
| [`rules/constraints.md`](rules/constraints.md) | 动代码前必读的规则 `C-*` |
| [`SDD/architecture/`](SDD/architecture/README.md) | 模块之间怎么连：组成、拓扑、通道、对象、方向盘、契约、状态机、审批、工作区、安全、方法、Profile、不变量、责任、工程 |
| [`SDD/modules/`](SDD/modules/) | 七块各自是什么：`0001-workbench`、`0002-web`、`0003-sandbox`、`0004-relay`、`0005-agent`、`0006-knowledge`、`0007-eval` |
| [`human-ai-turn/`](human-ai-turn/prd/discussion-final.md) | 值得留档的讨论：合并稿、四家评审、luna 本地环境 |

## 一句话

用户在网页里用自己的 Codex 做研究；做不好时把方向盘交给顾问，顾问按方法驾驶同一个 Codex，把可验收的底稿交回，结果就在用户的工作区里。循环在我们的沙箱，工具在用户机器，界面是网页，公网只有薄边缘。

## 建的顺序

1. **探针**（[工程](SDD/architecture/engineering.md)「第一段的探针」）：本地上限、BYOK、透传、断线、Windows；
2. `0005-agent` 与 `0003-sandbox` 的最小对：一台用户机器、一个沙箱、一个哑会合点；
3. `0001-workbench` 的会话与方向盘、账房收窄；`0002-web` 的对话与求助页；
4. 问数专家包 + `0006` 的 MCP + `0007` 的二十题；
5. `0004-relay` 正式版；边缘部署；
6. 勾稽切口。

每一步是一次或几次委托，走 [`../turn/`](../turn/README.md)。
