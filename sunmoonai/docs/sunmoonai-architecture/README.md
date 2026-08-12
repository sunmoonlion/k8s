# SunMoonAI Architecture · 总索引

> 最后更新：2026-08-12
>
> 本目录（`k8s/sunmoonai/docs/sunmoonai-architecture`，git 管理）是 SunMoonAI App Platform 的提示文档集。**两组结构**：`baseline/`（平台级基线：overall/ = App 之间 + apps/ = 各 App 内部，时期内稳定、评估后按需手动更新）+ `requests/`（开发任务请求，一次请求一个 REQ 文件夹，闭环：提议→审核→定任务→实施→评估→按需更新 baseline）。权威链：代码 > baseline > request。

## 文档清单与阅读顺序

| 文档 | 职责 | 何时读 |
| --- | --- | --- |
| `AGENTS.md` | 协作总入口：权威排序、请求闭环、进度单面、三约定与编辑自检、requests 评审、收口机制、Git 纪律 | **任何开发者动手前第一份必读** |
| `baseline/overall/app-platform-architecture.md` | App Platform 目标架构：核心决策、标准 App 拓扑、统一 Backend、数据所有权、跨 App 契约、模板治理、禁止事项 | 了解全貌第一步 |
| `baseline/overall/sunmoonai·-architecture.md` | 全平台分层：九平台职责、依赖方向、请求/异步数据流、CI/CD 与可观测性 | 了解全貌第二步 |
| `baseline/apps/k8s/项目摘要.md` | 部署编排仓 + Architecture v2 重构控制面（R0-R8 阶段链、门禁、发布治理） | 涉及部署、阶段门禁、发布时 |
| `baseline/apps/tpl-app/项目摘要.md` | 母模板：四角色一镜像、认证体系、web-interaction 契约、Outbox 原语、scaffold、发布 manifest | 涉及公共底座、模板同步时 |
| `baseline/apps/info-app/项目摘要.md` | 资讯采集与内容治理域：采集-抽取链、治理审计、delivery outbox、→Knowledge 分发 | 动 info-app 前 |
| `baseline/apps/knowledge-app/项目摘要.md` | 知识库域：artifact/retrieval 双契约、RAGFlow 摄入链、检索链、双关系 service identity | 动 knowledge-app 前 |
| `baseline/apps/investment-app/项目摘要.md` | 投资研究与智能体域：Agent 领域模型、LangGraph 图族、pilot/agent v4 双链、契约消费锁 | 动 investment-app 前 |
| `requests/TEMPLATE.md` | request 五段模板：原始需求（原话不改）→ 架构评审 → 落地去向 → 状态流转 | 用户提出新开发需求时 |
| `requests/<请求>/`（v6 开写时创建） | 闭环产物（按需产生）：baseline.md（目标态）+ plan-*（开发任务）+ handoff.md（进度游标） | 接手某请求实施时 |

**阅读原则**：改某个项目前，先读 baseline/overall/ 两篇中相关章节 + 该项目摘要；跨项目问题（契约、身份、发布）以 baseline/overall/ 为准。

## 协作规则（唯一权威：AGENTS.md）

权威排序、请求闭环、进度单面、三条维护约定与编辑自检、requests 评审流程、收口机制、
Git 与推送纪律，全部见 [`AGENTS.md`](./AGENTS.md)；本索引不复述（约定 1）。
