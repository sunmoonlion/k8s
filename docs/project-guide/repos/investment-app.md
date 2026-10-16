# investment-app：工作台

> 最后更新：2026-10-16 ｜ 按代码现状重写 ｜ 骨架继承 [`tpl-app.md`](tpl-app.md)，本文只写它多出来的 ｜ 总览见 [`../overall-architecture.md`](../overall-architecture.md)

用户在网页里用自己的 Codex 做研究、请自己的分身的地方。按 2026-10-16 的定位，它是**分身线**上「使用」的那一环：分身由 knowlab 创建、存在 knowmart，用户在这里「请」来用自己的数据跑（[0026](../../dev-investment-agent/tree-build/SDD/modules/0026-knowlab.md)）。现在 knowlab、knowmart 还没建，分身以「专家包」的形式内置在本仓。

## 后端（`investment-backend/app/app/`）

| 块 | 代码 | 说明 |
| --- | --- | --- |
| 对话与项目 | `application/workbench/session_service.py`、`project_service.py`；`domain/workbench/projects.py` | 三种对话（聊天、工作、「专家」——将改叫分身，[0017](../../dev-investment-agent/tree-build/SDD/modules/0017-three-kinds-of-conversation.md)）、项目、工作区 |
| 分身（现为内置专家包） | `domain/workbench/packs.py`、`pack_view.py`、`step_view.py`；`application/workbench/expert_desk.py`、`advisor.py`、`delegation.py` | 每个包：六问、步骤、每步验收、工具范围。代码里列给用户的有「问数」「财报体检」「财务分析与预测」（`listed_packs()`；前两个 2026-10-15 已定下架，代码还没撤），另有只给内部测机制的「机制烟测」。「财务分析与预测」是我们作为普通用户的分身（[0023](../../dev-investment-agent/tree-build/SDD/modules/0023-fin-forecast.md)）。**对全体用户可选，与 `C-L5` 冲突，对用户开放前改为归属用户** |
| 委托、验收、账 | `acceptance.py`、`deliverable_check.py`、`ledger.py`、`runner.py`、`records.py`、`run_files.py` | Task / Attempt、预算硬停（`C-A10`）、底稿与交付；四本账落 PostgreSQL（`C-A3`） |
| 沙箱 | `provisioning.py`、`tokens.py` | 设置页「拉起 / 更新沙箱」→ 签发会合点身份并登记 → 调供给器 `PUT /sandboxes/<用户>`；给沙箱签 knowbase MCP 与记录 MCP 的短期令牌 |
| 本地代理 | `agent_onboarding.py`、`agent_download.py`、`agent_service.py`、`agent_reports.py`、`machines.py` | 网页一行命令安装与配对、发放安装包（对象存储桶 `agent-releases`）、在线机器与权限回执 |
| 资料与记忆 | `library.py`；`domain/workbench/library.py`、`memory.py`、`missing_data.py` | 知识库条目、长期记忆、「缺数据的需求」 |
| 给沙箱的 MCP | `interfaces/mcp/workbench_mcp.py`（`/api/mcp/workbench`） | 沙箱里的 Codex 读本项目别的对话与底稿 |

表都在迁移链里，前缀 `workbench_`（项目、环境、交互、命令、Attempt、预算、审批、产物、记忆、代理配对与安装凭据、沙箱等）。运行角色比模板多一个**工作台管理者**（代码与 Pod 名仍叫 `runner`），经管理通道连会合点。

## 网页端（`investment-web-frontend/app/`）

`features/` 下：`chat`、`work`、`expert`（将改叫分身）、`projects`、`library`、`local-library`、`memory`、`settings`（个人偏好 / 云端与模型 / 我的电脑三类，[0021](../../dev-investment-agent/tree-build/SDD/modules/0021-settings-three-kinds.md)）、`usage`、`shell`。界面里本地程序叫「本地代理」「我的电脑」。

## 管理端

治理控制台、「缺数据的需求」（链去 knowfeed 管理端）、研究运行时；按应用角色显示，暂时看不到（总览「已知缺口」）。

## 和别的东西

| 对方 | 怎么连 |
| --- | --- |
| knowbase | 检索契约 v1 的调用方（服务身份 `knowbase:retrieve`，只持锁 `contracts/knowbase-retrieval-provider-lock.json`）；沙箱经 MCP 直连 knowbase |
| 会合点、供给器（`sandbox-platform`、`relay-platform`） | 集群内 Service：供给器 `:8080`、会合点管理通道 `:47100`；交给本地代理的是公网地址 `wss://relay.sunmoonai.com:30443` |
| 本地代理（`runtime`） | 经会合点；令牌由本应用签发、会合点就地验 |
| 模型厂商 | 不经本应用：用户的 key 只进他自己的沙箱，由沙箱里的 Codex 调（`C-A9`） |

## 部署

`k8s/gitops/components/app-platform/investment-app/`：`database`、`migration`、`redis`、`rabbitmq`、`identity`、`service-identity`、`agent-releases`（安装包上传与校验）、`runtime`。对外开放的三个公网域名之一 `investment.sunmoonai.com`。
