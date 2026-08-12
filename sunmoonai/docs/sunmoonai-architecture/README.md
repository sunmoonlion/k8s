# SunMoonAI Architecture · 总索引

> 最后更新：2026-08-12
>
> 本目录（`k8s/sunmoonai/docs/sunmoonai-architecture`，原名“项目总体提示”，曾位于家目录）是 SunMoonAI App Platform 的提示文档集。**三组结构**：`overall-architecture-summarizations/`（App 之间的结构与摘要）+ `apps-architecture-summarizations/`（各 App 的结构与摘要，均时期内稳定、手动刷新）+ `goals/`（需求输入与五环闭环：goal→baseline→plan→证据→handoff）。权威链：代码 > 架构基线 > goal。

## 文档清单与阅读顺序

| 文档 | 职责 | 何时读 |
| --- | --- | --- |
| `AGENTS.md` | 协作总入口：权威排序、五环链、进度单面、三约定与编辑自检、goals 评审、演进闭环、Git 纪律 | **任何开发者动手前第一份必读** |
| `overall-architecture-summarizations/app-platform-architecture.md`（原名 overall-architecture.md） | App Platform 目标架构：核心决策、标准 App 拓扑、统一 Backend、数据所有权、跨 App 契约、模板治理、禁止事项 | 了解全貌第一步 |
| `overall-architecture-summarizations/sunmoonai·-architecture.md` | 全平台分层：九平台职责、依赖方向、请求/异步数据流、CI/CD 与可观测性 | 了解全貌第二步 |
| `apps-architecture-summarizations/k8s/项目摘要.md` | 部署编排仓 + Architecture v2 重构控制面（R0-R8 阶段链、门禁、发布治理） | 涉及部署、阶段门禁、发布时 |
| `apps-architecture-summarizations/tpl-app/项目摘要.md` | 母模板：四角色一镜像、认证体系、web-interaction 契约、Outbox 原语、scaffold、发布 manifest | 涉及公共底座、模板同步时 |
| `apps-architecture-summarizations/info-app/项目摘要.md` | 资讯采集与内容治理域：采集-抽取链、治理审计、delivery outbox、→Knowledge 分发 | 动 info-app 前 |
| `apps-architecture-summarizations/knowledge-app/项目摘要.md` | 知识库域：artifact/retrieval 双契约、RAGFlow 摄入链、检索链、双关系 service identity | 动 knowledge-app 前 |
| `apps-architecture-summarizations/investment-app/项目摘要.md` | 投资研究与智能体域：Agent 领域模型、LangGraph 图族、pilot/agent v4 双链、契约消费锁 | 动 investment-app 前 |
| `goals/TEMPLATE.md` | goal 五段模板：原始需求（原话不改）→ 架构评审 → 落地去向 → 状态流转 | 用户提出新开发需求时 |
| `goals/<阶段>/`（v6 开写时创建） | 五环闭环三件套：baseline（做成什么样）+ plan-*（按 App 施工清单）+ handoff（进度游标） | 接手某阶段实施时 |

**阅读原则**：改某个项目前，先读 overall-architecture-summarizations/ 两篇中相关章节 + 该项目摘要；跨项目问题（契约、身份、发布）以 overall-architecture-summarizations/ 为准。

## 协作规则（唯一权威：AGENTS.md）

权威排序、五环链、进度单面、三条维护约定与编辑自检、goals 评审流程、演进闭环、
Git 与推送纪律，全部见 [`AGENTS.md`](./AGENTS.md)；本索引不复述（约定 1）。

## 修订记录

- 2026-08-12：按用户方案二次重构：`architecture/`→`overall-architecture-summarizations/`，`apps/`→`apps-architecture-summarizations/`（两套摘要定位：供 AI 快速了解项目、时期内稳定、手动刷新）；`phases/` 并入 `goals/`（五环全闭环）；AGENTS.md 新增 AI 助手自举流程（§8）。
- 2026-08-12：新建 `AGENTS.md` 协作总入口；三约定/goals 规则全文收敛进 AGENTS.md，本索引改为引用（消除双权威）。
- 2026-08-12：文档集迁入 k8s 仓 `sunmoonai/docs/sunmoonai-architecture/` 纳入 Git；删除仓内旧源 `app-platform/docs/overall-architecture.md` 与 `docs/sunmoonai·-architecture.md`（内容已并入本目录修订版），仓内活链接改指新位置。
- 2026-08-12：`项目总体架构提示/` 改名为 `overall-architecture/`；新建 `goals/` 层（含 TEMPLATE.md）；结构由两层升级为三层（总体架构 + 现状摘要 + goals）。
- 2026-08-12：目录“项目总体提示”改名为 `sunmoonai-architecture`；`overall-architecture.md` 改名为 `app-platform-architecture.md`（k8s 仓内 `app-platform/docs/overall-architecture.md` 源文件未动，其同步改名归 R8 文档重建）。
- 2026-08-12：创建本索引；修正总体文档两处漂移（Ant Design → shadcn/@base-ui；迁移快照更新至 R6 完成/R7 进行中）。
- 2026-08-11：五份项目摘要基于源码全量深读落盘；tpl-app 摘要重写。
