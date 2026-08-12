# SunMoonAI Architecture · 总索引

> 最后更新：2026-08-12
>
> 本目录（`k8s/sunmoonai/docs/sunmoonai-architecture`，原名“项目总体提示”，曾位于家目录）是 SunMoonAI App Platform 的提示文档集。采用**三层结构**：总体架构层（慢变知识）+ 各项目摘要层（现状，快变知识）+ goals 层（目标需求输入，经架构评审后才进入权威链）。权威链：代码 > 架构基线 > goal。

## 文档清单与阅读顺序

| 文档 | 职责 | 何时读 |
| --- | --- | --- |
| `overall-architecture/app-platform-architecture.md`（原名 overall-architecture.md） | App Platform 目标架构：核心决策、标准 App 拓扑、统一 Backend、数据所有权、跨 App 契约、模板治理、禁止事项 | 了解全貌第一步 |
| `overall-architecture/sunmoonai·-architecture.md` | 全平台分层：九平台职责、依赖方向、请求/异步数据流、CI/CD 与可观测性 | 了解全貌第二步 |
| `k8s/项目摘要.md` | 部署编排仓 + Architecture v2 重构控制面（R0-R8 阶段链、门禁、发布治理） | 涉及部署、阶段门禁、发布时 |
| `tpl-app/项目摘要.md` | 母模板：四角色一镜像、认证体系、web-interaction 契约、Outbox 原语、scaffold、发布 manifest | 涉及公共底座、模板同步时 |
| `info-app/项目摘要.md` | 资讯采集与内容治理域：采集-抽取链、治理审计、delivery outbox、→Knowledge 分发 | 动 info-app 前 |
| `knowledge-app/项目摘要.md` | 知识库域：artifact/retrieval 双契约、RAGFlow 摄入链、检索链、双关系 service identity | 动 knowledge-app 前 |
| `investment-app/项目摘要.md` | 投资研究与智能体域：Agent 领域模型、LangGraph 图族、pilot/agent v4 双链、契约消费锁 | 动 investment-app 前 |
| `goals/TEMPLATE.md` | goal 五段模板：原始需求（原话不改）→ 架构评审 → 落地去向 → 状态流转 | 用户提出新开发需求时 |

**阅读原则**：改某个项目前，先读总体架构两篇中相关章节 + 该项目的摘要；跨项目问题（契约、身份、发布）以总体层为准。

## goals 层处理规则

- 用户的开发需求以 `goals/G-<编号>-<短名>.md` 落盘（按 `TEMPLATE.md`），**goal 是输入不是权威**。
- 每个 goal 必有书面评审结论：采纳 / 修改后采纳 / 不采纳 / 待澄清；与现有架构冲突时摆出两种代价由用户拍板。
- goal 采纳后，目标态事实写进架构基线或任务文件，goal 文件只留 `落地去向` 引用，不复述（约定 1）。

## 三条维护约定

### 约定 1：每个事实只有一个权威位置（防复述漂移）

- **跨项目事实**（阶段状态、R3.2 锁值、发布顺序、research 命名治理、契约链方向）→ 权威位置在总体层；项目摘要只引用、不复述细节。
- **项目内事实**（迁移 head、端点、配置段、commit/digest）→ 权威位置在该项目摘要；总体层不展开。
- 判断标准：**这个事实将来变了，应该在哪一处改**。两处都写 = 必然漂移。

### 约定 2：每份文档必须带时间戳

- 每份文档头部写"最后更新：YYYY-MM-DD"。
- 摘要头部写"深读时间"，表明摘要对应的源码阅读时点。
- 遇到文档间矛盾时：先比时间戳，再比层级（代码 > 新文档 > 旧文档），不盲目采信。

### 约定 3：层间引用而非层间复制

- 项目摘要涉及总体规则时，写“见总体架构文档 §X”式引用 + 一句话结论，不抄全文。
- 总体文档修订后，检查各摘要中引用它的注记是否仍成立（本次 2026-08-12 修订即同步更新了 tpl/k8s 摘要中的相关注记）。

### 执行保障（编辑自检，无需提醒）

任何一次新增/修改本目录文档，必须同时完成三件事，缺一项视为未完成：

1. 更新该文档头部“最后更新”时间戳；
2. 确认新写入的事实没有第二处复述（有则改为引用）；
3. 检查被改动章节在其它文档中的引用/注记是否仍成立。

该规则已写入长期记忆（跨会话自动生效），与用户提醒无关。

## 修订记录

- 2026-08-12：文档集迁入 k8s 仓 `sunmoonai/docs/sunmoonai-architecture/` 纳入 Git；删除仓内旧源 `app-platform/docs/overall-architecture.md` 与 `docs/sunmoonai·-architecture.md`（内容已并入本目录修订版），仓内活链接改指新位置。
- 2026-08-12：`项目总体架构提示/` 改名为 `overall-architecture/`；新建 `goals/` 层（含 TEMPLATE.md）；结构由两层升级为三层（总体架构 + 现状摘要 + goals）。
- 2026-08-12：目录“项目总体提示”改名为 `sunmoonai-architecture`；`overall-architecture.md` 改名为 `app-platform-architecture.md`（k8s 仓内 `app-platform/docs/overall-architecture.md` 源文件未动，其同步改名归 R8 文档重建）。
- 2026-08-12：创建本索引；修正总体文档两处漂移（Ant Design → shadcn/@base-ui；迁移快照更新至 R6 完成/R7 进行中）。
- 2026-08-11：五份项目摘要基于源码全量深读落盘；tpl-app 摘要重写。
