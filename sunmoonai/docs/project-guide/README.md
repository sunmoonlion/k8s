# 项目指南 · 导航

> 重构与文档入口更新：2026-09-19；后端源码、隔离验证和业务部署分开记录，前端基础结构沿用原取证。
>
> **入口是同目录下的 [`overall-architecture.md`](overall-architecture.md)**，先读它。
> 本文件只是 `repos/` `topics/` 两个子目录的导航：
> 总览回答「去哪看」，子目录回答「锚点在哪、规则是什么」。
>
> 本目录只回答**「项目现在是什么样」**，随代码覆盖式重写。另外两处：
>
> | 目录 | 管什么 | 改了之后 |
> | --- | --- | --- |
> | [`../dev-agent-task/`](../dev-agent-task/) | 代码必须符合的规则、接下来建什么（agent 项目） | **代码要跟着改** |
> | [`../dev-agent-standards/`](../dev-agent-standards/) | 我们怎么共事：任务、交付、多方竞争、人的批准点 | 协作方式变，代码不变 |
>
> **本目录不放规则，也不放脚本**——只描述现状。
> 规则在 [`../dev-agent-task/composition/constraints.md`](../dev-agent-task/SDD/constraints.md)，
> 文档检查脚本在 [`../tools/`](../tools/)。

## 本集之外：`docs/` 下的其他目录是什么

本目录自称"现状的权威投影"，但 `docs/` 下并存着若干历史材料。
**不声明它们的关系，入口声明就是空话**——读者会同时撞到多份看起来权威的文档。
逐项定性如下（均**不是现状权威**，与本集冲突时以本集与代码为准）：

| 位置 | 是什么 | 最近变动 | 定性 |
| --- | --- | --- | --- |
| `architecture-v2/` | Architecture v2 重构（R0–R7）的门禁脚本与 evidence | 2026-08 | **门禁脚本仍在用**（见 [`topics/release.md`](topics/release.md)）；其中的结果文档属过程记录 |
| [`legacy-backlog/`](../legacy-backlog/README.md) | 旧任务、部署清单、精简验证索引三个入口 | 2026-09-19 | 未来旧任务等架构讨论后接收；当前运行欠账单列，源码完成不代表已部署 |
| [`tasks/B7-B9-closeout/`](../tasks/B7-B9-closeout/thread/0001-imp-none/0002-none/user-message.md) | 逐次请求、固定候选、测试原始输出与回执 | 2026-09-19 | 历史 turn 已冻结，按其提交理解；不把早先断点当当前任务指令 |
| `evidence/` | v5 时期的验收 evidence | 2026-08 | 历史留档 |
| 旧 `mooc-manus-v5/` | 111 份旧 ADR、契约和脚本已退出当前工作树 | 2026-09-19 | 仅按 [固定 Git 历史索引](../legacy-backlog/verification-index.md) 查询，不作现行契约或部署入口 |
| `ai-tools/` | 工具调研笔记 | 2026-08 | 参考 |
| 旧 v4/v5 计划、实施计划、handoff 与 24 份旧账散报告 | 已退出当前工作树 | 2026-09-19 | 必要目标/部署约束已收拢，完整原文按 [固定 Git 索引](../legacy-backlog/verification-index.md) 取回，不再另建备份目录 |
| 旧 Architecture v2 重构计划、Knowledge Provider 解耦报告 | 已退出当前工作树 | 2026-09-19 | 当前架构看本指南，切换前置和解耦证据见 legacy-backlog；完整过程按固定 Git 版本查询 |
| `docs/` 下其余散落 md | Harbor、Celery、YAML 生成、k8s 连接等主题笔记 | 不一 | **参考，未逐条与代码核对**。主题都还活着，但断言可能已漂移——用之前先回代码验一遍 |
| `app-platform/docs/`（本目录之外） | 14 份目标态设计文档 | — | **已标注为"实现参考，非权威"**——它自陈"描述长期边界和目标状态" |

**2026-08-29 已清理一轮**：删掉 10 项 6989 行，判据是"描述的对象已不存在"——

- 六份环境变量说明写的是 NestJS BFF / Nuxt / Vite 时代；现行八个前端全是
  Next.js 16，后端全是 FastAPI（admin/web backend 早已并成单一 backend）
- `APP组件开发.md`、`bff-config-differences-analysis.md` 全文以
  `incubator-app-bff` / `llmops-app-bff` 为例，二者已不是活组件
- `Dockerfile构建优化-从inboard到标准Python镜像.md`：inboard 时代已过
- `recursive-architecture/`：2025-12 旧设计，本表原已定性"已失效"

删的都是**活引用为 0** 的。取回：`git log --diff-filter=D -- sunmoonai/docs/<路径>`。

当前保留 `architecture-v2/` 等仍在使用的发布门禁、冻结的历史证据，以及主题笔记。
旧计划的交互目标与 Profile 概念已提取到待接收清单；删除旧散文档不删除代码或 Git 历史。

## 按任务找

| 我要… | 读 |
| --- | --- |
| **动手前必读的规矩** | [`governance.md`](governance.md) |
| 改某个仓的代码 | [`repos/`](repos/) 下对应文件的「硬规则」+「已知未实现」两节 |
| 加或改跨 App 契约 | [`topics/contracts.md`](topics/contracts.md) |
| 动登录、权限、服务间调用 | [`topics/identity.md`](topics/identity.md) |
| 加表、改迁移 | [`topics/data.md`](topics/data.md) |
| 发版、改部署清单 | [`topics/release.md`](topics/release.md) + [`repos/k8s.md`](repos/k8s.md) |
| 确认某个能力是否真的接线了 | 对应仓文件的**「已知未实现」**一节 |
| **动代码前必读的规则** | [`../dev-agent-task/composition/constraints.md`](../dev-agent-task/SDD/constraints.md)（39 条，按主题分组） |
| 让多个助手/智能体对同一需求各出方案、审核、吸收 | [`../dev-agent-task/composition/protocol/competition-protocol.md`](../dev-agent-task/protocol/competition-protocol.md) |
| 推送改动、跨机拉取、子模块的坑 | `~/five-repos-sync/sync-five-repos.sh`；规则见 [`../dev-agent-task/composition/constraints.md`](../dev-agent-task/SDD/constraints.md) T4 |
| 知道接下来要建什么 | [`../dev-agent-task/`](../dev-agent-task/) |
| 继续重构的部署工作 | [当前部署清单](../legacy-backlog/deployment-checklist.md)，先同步再工作 |
| 讨论新架构前找旧需求 | [旧任务待接收清单](../legacy-backlog/README.md)，不提前搬入正式模块树 |
| 查旧修复的测试或原文 | [验证与历史索引](../legacy-backlog/verification-index.md)，按固定版本取证 |
| 复核本文档集的某条断言 | **读代码**，别的都不算数 |
| 本轮查出的缺口都怎么处置了 | 结论已在各自投影里；过程 `git log --grep 'O[0-9]'` |

## 目录

```
project-guide/
├── README.md      本文件（导航 + 本集之外的目录定性）
├── governance.md  动手前必读：权威排序、接手演练、什么不属于本文档集
├── repos/         一仓一文件
│   ├── tpl-app.md          模板仓：定义标准形态，无领域
│   ├── info-app.md         资讯域：采集→治理→分发
│   ├── knowledge-app.md    知识域：两套契约的唯一 provider
│   ├── investment-app.md   智能体域：状态机 / 检查点 / 事件流
│   └── k8s.md              部署编排：bundle / apply 顺序 / 门禁
├── topics/        跨仓主题
│   ├── contracts.md   契约治理、provider-lock、双端测试
│   ├── identity.md    浏览器身份 vs 服务身份、Casdoor、scope
│   ├── data.md        主档归属、派生系统、迁移纪律、Outbox
│   └── release.md     发布单元、digest 纪律、门禁分层
```

## 两种修改语义，别混

| 目录 | 语义 | 怎么改 |
| --- | --- | --- |
| `overall-architecture.md` `repos/` `topics/` | **现状投影** | **覆盖式重写**：直接替换旧条文，只反映当前有效事实；历史由 git 承担 |
| 协作机制（请求流程、推送、文档约定、评审） | **已移出** | 见 [`../dev-agent-standards/`](../dev-agent-standards/) |
| `governance.md` | **规则** | 改动前应有共识；改完要检查依赖它的文档 |

## 写作约定

见 [人的批准点](../dev-agent-standards/detailed-rules/approvals.md)「改判」与 [任务的生命周期](../dev-agent-standards/lifecycle.md)「交给 agent 的活，八条都成立」。
本处不复述——引用而非复制，是那份文件自己的第二条维护约定。

## 本轮的已知缺口（读之前先知道）

- **源码不等于运行态**：最近的业务 KIND 只读快照与独立临时环境测试分别列在
  [部署清单](../legacy-backlog/deployment-checklist.md) 和 [验证索引](../legacy-backlog/verification-index.md)。本目录不将这些证据
  推定为当前业务镜像已升级、权限已切换或 NetworkPolicy 已执行；继续工作时重查。
- **前端未逐文件深读**：约 570 个 ts/tsx，核到了结构、入口、契约与关键配置层。
- **新架构尚未落代码**：三部分职责划分仍保留 B-S；产品合同与正式任务树将在随后讨论中对齐。
- 本文档集**不写进度**。哪些缺口修过、怎么修的，见 git 历史。
