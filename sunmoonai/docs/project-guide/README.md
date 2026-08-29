# 项目指南 · 导航

> 取证时点：2026-08-29
>
> **入口是同目录下的 [`overall-architecture.md`](overall-architecture.md)**，先读它。
> 本文件只是 `repos/` `topics/` 两个子目录的导航：
> 总览回答「去哪看」，子目录回答「锚点在哪、规则是什么」。
>
> 本目录只回答**「项目现在是什么样」**，随代码覆盖式重写。另外两处：
>
> | 目录 | 管什么 | 改了之后 |
> | --- | --- | --- |
> | [`../dev-plan/`](../dev-plan/) | 代码必须符合的规则、接下来建什么 | **代码要跟着改** |
> | [`../working/`](../working/) | 我们怎么共事：提请求、推送、写文档、评审 | 协作方式变，代码不变 |
>
> **规则不写在本目录**——投影只描述现状。看到"必须/禁止"而想知道谁在执行它，
> 去 [`../dev-plan/constraints.md`](../dev-plan/constraints.md)。

## 本集之外：`docs/` 下的其他目录是什么

本目录自称"现状的权威投影"，但 `docs/` 下并存着若干历史材料。
**不声明它们的关系，入口声明就是空话**——读者会同时撞到多份看起来权威的文档。
逐项定性如下（均**不是现状权威**，与本集冲突时以本集与代码为准）：

| 位置 | 是什么 | 最近变动 | 定性 |
| --- | --- | --- | --- |
| `architecture-v2/` | Architecture v2 重构（R0–R7）的门禁脚本与 evidence | 2026-08 | **门禁脚本仍在用**（见 [`topics/release.md`](topics/release.md)）；其中的结果文档属过程记录 |
| `evidence/` | v5 时期的验收 evidence | 2026-08 | 历史留档 |
| `mooc-manus-v5/` | v5 架构的契约与脚本（111 文件） | 2026-08 | **已被 Architecture v2 取代**；其 `contracts/` 不在现行三套契约之列（见 [`topics/contracts.md`](topics/contracts.md) §7） |
| `ai-tools/` | 工具调研笔记 | 2026-08 | 参考 |
| **`mooc-manus-langgraph-longterm-plan-v5.md`** 及其实施计划、handoff | 上一轮的施工基线 | 2026-07 | **已降级为历史设计输入**，见 [`../dev-plan/development-plan.md`](../dev-plan/development-plan.md)「起点」。其**前后端对接**部分仍有效且详尽，相应工作启动时可引用；其 §14 多智能体（23 行）不作为智能体架构依据。任务游标停在 `P0-008C = PAUSED_FOR_ARCHITECTURE_REVIEW` |
| `mooc-manus-langgraph-longterm-plan-v4.md` | v5 的前身 | 2026-07 | 历史。但其 **§20 `AgentProfile` 结构（102 行）比 v5 §14 完整**，现重新生效为专用部分的载体，见 [`../dev-plan/implementation-plan.md`](../dev-plan/implementation-plan.md) U4 |
| `docs/` 下其余散落 md | Harbor、Celery、YAML 生成、k8s 连接等主题笔记 | 不一 | **参考，未逐条与代码核对**。主题都还活着，但断言可能已漂移——用之前先回代码验一遍 |
| `app-platform/docs/`（本目录之外） | 14 份目标态设计文档 | — | **已标注为"实现参考，非权威"**——它自陈"描述长期边界和目标状态" |

**2026-08-29 已清理一轮**（O8）：删掉 10 项 6989 行，判据是"描述的对象已不存在"——

- 六份环境变量说明写的是 NestJS BFF / Nuxt / Vite 时代；现行八个前端全是
  Next.js 16，后端全是 FastAPI（admin/web backend 早已并成单一 backend）
- `APP组件开发.md`、`bff-config-differences-analysis.md` 全文以
  `incubator-app-bff` / `llmops-app-bff` 为例，二者已不是活组件
- `Dockerfile构建优化-从inboard到标准Python镜像.md`：inboard 时代已过
- `recursive-architecture/`：2025-12 旧设计，本表原已定性"已失效"

删的都是**活引用为 0** 的。取回：`git log --diff-filter=D -- sunmoonai/docs/<路径>`。

留下的两类：`architecture-v2/` 等发布取证真源；v5 计划及其证据链
（前后端对接部分仍有效）。主题笔记按上表定性保留。

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
| **动代码前必读的规则** | [`../dev-plan/constraints.md`](../dev-plan/constraints.md)（39 条，按主题分组） |
| 让多个助手/智能体对同一需求各出方案、审核、吸收 | [`../dev-plan/agent-discipline.md`](../dev-plan/agent-discipline.md) |
| 推送改动、跨机拉取、子模块的坑 | [`../working/collaboration.md`](../working/collaboration.md) |
| 知道接下来要建什么 | [`../dev-plan/`](../dev-plan/) |
| 复核本文档集的某条断言 | [`verify.md`](verify.md)；机械检查跑 `python3 check-docs.py` |
| 本轮查出的缺口都怎么处置了 | 结论已在各自投影里；过程 `git log --grep 'O[0-9]'` |

## 目录

```
project-guide/
├── README.md      本文件（导航 + 本集之外的目录定性）
├── governance.md  动手前必读：权威排序、漂移尺子、维护与写作约定、编辑自检
├── check-docs.py  机械检查：坏链/空链接/易腐值/取证时点保鲜
├── verify.md      验证方法、本轮实测结果、易腐值真源、明确的盲区
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
└── check-cross-repo.py  跨仓硬规则：gitlink/digest/隐式迁移/跨 App 表/hostPath/凭据复用
```

## 两种修改语义，别混

| 目录 | 语义 | 怎么改 |
| --- | --- | --- |
| `overall-architecture.md` `repos/` `topics/` `verify.md` | **现状投影** | **覆盖式重写**：直接替换旧条文，只反映当前有效事实；历史由 git 承担 |
| 协作机制（请求流程、推送、文档约定、评审） | 已移出，见 [`../working/`](../working/) |
| `governance.md` | **规则** | 改动前应有共识；改完要检查依赖它的文档 |

## 写作约定

见 [`governance.md`](governance.md) §4；编辑自检见其 §5。
本处不复述（同 §3 维护约定第 3 条：引用而非复制）。

## 本轮的已知缺口（读之前先知道）

- **未连集群**：所有运行态断言（Pod 状态、NetworkPolicy 实际生效、远程 profile）
  均未验证，见 [`verify.md`](verify.md) §6。
- **前端未逐文件深读**：约 570 个 ts/tsx，核到了结构、入口、契约与关键配置层。
- **前端的 `CLAUDE.md` 是本轮重写的，但前端本身未逐文件深读**——这是本轮
  风险最高的组合，逐条核对见 [`verify.md`](verify.md) §5。
- 本轮查出的十项缺口**已全部了结**，结论落在各自对应的投影里；
  过程见 `git log --grep 'O[0-9]'`。
