# 设计层：模块之间的结构与关系

> 依据：[需求](../../PRD/requirement.md) 与 [产品合同](../../../product/product-contract.md)。
> 本层定稿以 thread [0001/0001](../../thread/0001-prd-none/0001-none/user-message.md)、[0001/0002](../../thread/0001-prd-none/0002-none/user-message.md)、[0001/0003](../../thread/0001-prd-none/0003-none/user-message.md) 的 response 为底。

## 轮廓

[请求生命周期](lifecycle.md)：一条 message 从用户发出到用户看到 response 的完整往返，九站。
**先读它**——下面的模块、交互与约束都是这条线上的局部。

## 模块

本轮建三块，按**运行位置、信任域、发布方式**切——三者都不同就单列：

| 模块 | 承担什么 | 跑在哪 | 内部结构见 |
| --- | --- | --- | --- |
| [`0001-backend`](../modules/0001-backend/PRD/requirement.md) | 受理、路由、编排、派发、验收、持久化账与审计 | 服务器 | [设计](../modules/0001-backend/SDD/architecture/README.md) |
| [`0002-desktop`](../modules/0002-desktop/PRD/requirement.md) | Electron 桌面应用：提交、进度与结果、审批与审查、本地配置 | 用户电脑 | [设计](../modules/0002-desktop/SDD/architecture/README.md) |
| [`0003-runtime`](../modules/0003-runtime/PRD/requirement.md) | 本地 runtime：驱动 Codex、持 key、本地检查与加密、租约与回传 | 用户电脑 | 待设计 |

`0002` 与 `0003` 都在用户电脑上，但**信任域不同**：runtime 碰得到 key 与结果正文，桌面应用碰不到。
这是它们分开的唯一理由，也是不能合并的理由。

## 本轮范围外

系统不止这三块。下面这些**沿用现状、本轮不开发**，所以不占模块——部件全景见
[产品合同](../../../product/product-contract.md)「组成部分」：

| 范围外的部件 | 现在在哪 |
| --- | --- |
| 八个既有 Next.js 前端 | 四个 app 仓各一对：`tpl-`、`info-`、`knowledge-`、`investment-` 的 `*-web-frontend/` 与 `*-admin-frontend/` |
| 官网与下载页 | 上述 `*-web-frontend/` |
| 内部管理后台 | 上述 `*-admin-frontend/`，沿用平台模板 |
| 知识服务 | `info-app` 采集、`knowledge-app` 建库与 MCP；Codex 经通道 ⑤ 直接调它 |

**界面不共享**：网页前端用 Next.js，桌面应用用 Vite + React Router，各按各自技术栈。
**接口契约单一真源**：两端调同一个后端，形状以后端的 OpenAPI / schema 为准，各自生成客户端，不手写第二份。

同层的其他定稿：[`constraints.md`](../constraints.md) 是代码必须遵守的规则，[`agent-dev-guide.md`](../agent-dev-guide.md) 是开发指导，[`protocol/`](../../../dev-human/protocol/README.md) 是多方竞争在本平台的做法。

## 模块之间怎么交互

按 [产品合同](../../../product/product-contract.md) 的「通道」一节定，设计上只落实这几件事：

| 交互 | 设计要点 |
| --- | --- |
| 提交 | 客户端生成幂等键，后端在可靠边界内建单并写首事件（合同 `F-INTAKE-01`、`F-ADMIT-01`） |
| 事件与结果 | 先持久化后通知；客户端按 cursor 续传，重复事件幂等（`F-DELIVERY-02` 至 `F-DELIVERY-05`） |
| 审批与审查 | 工具级只在本机闭环，Task 级经后端 Interaction 原子消费；两条提交逻辑不得共用（`F-APPROVE-*` 与 `F-REVIEW-*`） |
| 结果 | 执行端本地检查后加密，后端只存密文与元数据，客户端本机解密（`F-CRYPTO-*`） |

- 客户端与后端只走合同「通道」一节的 ④，执行端与后端走 ①，客户端与执行端在同一台电脑上走本机通道 ③；
- 谁对哪条要求负责，以合同的「责任投影」为准，本文不复制第二份。

## 共同约束

- 状态机只有一套，场景差异只体现在 Profile 与 workflow（[SDD 规则](../../../dev-human/sdd/finalize.md) P0）；
- 同一事实只有一个权威写入面（P1）；
- 跨进程仍须正确的不变量由持久存储承担，不放在执行进程本地；
- 执行层租用不自建，领域概念不进执行端口的签名。

## 未决

知识服务与八个既有前端何时进入建设范围，未定；进入时按同一把尺子（运行位置、信任域、发布方式）判断要不要单列模块。
