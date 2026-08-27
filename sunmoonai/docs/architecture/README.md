# 本目录导航

> 取证时点：2026-08-27
>
> **入口是同目录下的 [`overall-architecture.md`](overall-architecture.md)**，先读它。
> 本文件只是 `repos/` `topics/` `decisions/` 三个子目录的导航：
> 总览回答「去哪看」，子目录回答「锚点在哪、规则是什么」。
>
> 另有两份与架构描述无关、按需读的流程文档：
> [`request-lifecycle.md`](request-lifecycle.md)（提开发请求时读）与
> [`multi-assistant-workflow.md`](multi-assistant-workflow.md)（多助手并行提案、比较、推送拉取时读）。

## 本集之外：`docs/` 下的其他目录是什么

本目录自称"现状的权威投影"，但 `docs/` 下并存着若干历史材料。
**不声明它们的关系，入口声明就是空话**——读者会同时撞到多份看起来权威的文档。
逐项定性如下（均**不是现状权威**，与本集冲突时以本集与代码为准）：

| 位置 | 是什么 | 最近变动 | 定性 |
| --- | --- | --- | --- |
| `architecture-v2/` | Architecture v2 重构（R0–R7）的门禁脚本与 evidence | 2026-08 | **门禁脚本仍在用**（见 [`topics/release.md`](topics/release.md)）；其中的结果文档属过程记录 |
| `evidence/` | v5 时期的验收 evidence | 2026-08 | 历史留档 |
| `mooc-manus-v5/` | v5 架构的契约与脚本（111 文件） | 2026-08 | **已被 Architecture v2 取代**；其 `contracts/` 不在现行三套契约之列（见 [`topics/contracts.md`](topics/contracts.md) §7） |
| `recursive-architecture/` | 2025-12 的旧设计 | 2025-12 | 历史，已失效 |
| `ai-tools/` | 工具调研笔记 | 2026-08 | 参考 |
| `docs/` 下 23 份散落 md | 环境变量、Harbor、Celery 等主题笔记 | 不一 | 参考，未逐条与代码核对 |
| `app-platform/docs/`（本目录之外） | 14 份目标态设计文档 | — | **已标注为"实现参考，非权威"**——它自陈"描述长期边界和目标状态" |

清理动作本身未做，登记为 [`origin-record.md`](origin-record.md) §4 的 U8。

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
| 知道「当初为什么这么定」 | [`decisions/`](decisions/)（13 条 ADR） |
| 让多个助手对同一需求各出方案 | [`multi-assistant-workflow.md`](multi-assistant-workflow.md) §1–§3 |
| 审核别人的产出 | [`multi-assistant-workflow.md`](multi-assistant-workflow.md) §4 |
| 推送改动、跨机拉取 | [`multi-assistant-workflow.md`](multi-assistant-workflow.md) §5–§8 |
| 复核本文档集的某条断言 | [`verify.md`](verify.md)；机械检查跑 `python3 check-docs.py` |
| 这套文档怎么来的、取代了什么、有哪些未决事项 | [`origin-record.md`](origin-record.md) |

## 目录

```
architecture/
├── README.md      本文件（导航 + 本集之外的目录定性）
├── governance.md  动手前必读：权威排序、漂移尺子、维护与写作约定、编辑自检
├── origin-record.md  来历、取代记录、未决事项（只追加）
├── check-docs.py  机械检查：坏链/空链接/易腐值/取证时点保鲜
├── verify.md      验证方法、本轮实测结果、易腐值真源、明确的盲区
├── multi-assistant-workflow.md  并行提案与隔离、审核两阶段、推送拉取、子模块的坑
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
└── decisions/     13 条 ADR，追加不覆写
```

## 两种修改语义，别混

| 目录 | 语义 | 怎么改 |
| --- | --- | --- |
| `overall-architecture.md` `repos/` `topics/` `verify.md` | **现状投影** | **覆盖式重写**：直接替换旧条文，只反映当前有效事实；历史由 git 承担 |
| `decisions/` `origin-record.md` `merge-review/` | **历史记录** | **只追加**：推翻一条要写新的一条并在旧的上标注被取代，不删不改 |
| `governance.md` `request-lifecycle.md` `multi-assistant-workflow.md` | **规则** | 改动前应有共识；改完要检查依赖它的文档 |

## 写作约定

见 [`governance.md`](governance.md) §4；编辑自检见其 §5。
本处不复述（同 §3 维护约定第 3 条：引用而非复制）。

## 本轮的已知缺口（读之前先知道）

- **未连集群**：所有运行态断言（Pod 状态、NetworkPolicy 实际生效、远程 profile）
  均未验证，见 [`verify.md`](verify.md) §6。
- **前端未逐文件深读**：约 570 个 ts/tsx，核到了结构、入口、契约与关键配置层。
- **前端的 `CLAUDE.md` 是本轮重写的，但前端本身未逐文件深读**——这是本轮
  风险最高的组合，逐条核对见 [`verify.md`](verify.md) §5。
- **八项未决事项**（版本矛盾、RAGFlow CANCEL、RunBudget 未接线等）
  尚无去向，见 [`origin-record.md`](origin-record.md) §4。
