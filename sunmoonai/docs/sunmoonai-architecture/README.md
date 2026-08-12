# SunMoonAI Architecture · 目录说明

> 最后更新：2026-08-12
>
> 本目录（`k8s/sunmoonai/docs/sunmoonai-architecture`，git 管理）是 SunMoonAI App Platform 的提示文档集。**两组结构**：`baseline/`（基线：overall/ = App 之间 + apps/ = 各 App 内部，时期内稳定、评估后按需手动更新）+ `requests/`（开发任务请求，一次请求一个 REQ 文件夹，闭环：提议→审核→定任务→实施→评估→按需更新 baseline）。权威链：代码 > baseline > request。

## 目录内容

```
sunmoonai-architecture/
├── AGENTS.md                          协作规则总入口
├── baseline/
│   ├── overall/
│   │   ├── app-platform-architecture.md     App Platform 目标架构：核心决策、标准 App 拓扑、
│   │   │                                    统一 Backend、数据所有权、跨 App 契约、模板治理、禁止事项
│   │   └── sunmoonai·-architecture.md       全平台分层：九平台职责、依赖方向、请求/异步数据流、
│   │                                        CI/CD 与可观测性
│   └── apps/
│       ├── tpl-app/项目摘要.md               母模板：四角色一镜像、认证体系、web-interaction 契约、
│       │                                    Outbox 原语、scaffold、发布 manifest
│       ├── info-app/项目摘要.md              资讯采集与内容治理域：采集-抽取链、治理审计、
│       │                                    delivery outbox、→Knowledge 分发
│       ├── knowledge-app/项目摘要.md         知识库域：artifact/retrieval 双契约、RAGFlow 摄入链、
│       │                                    检索链、双关系 service identity
│       ├── investment-app/项目摘要.md        投资研究与智能体域：Agent 领域模型、LangGraph 图族、
│       │                                    pilot/agent v4 双链、契约消费锁
│       └── k8s/项目摘要.md                   部署编排仓：各平台部署声明、领域 App 部署 bundle、
│                                            发布输入与验收门禁
└── requests/
    ├── TEMPLATE.md                    request 模板
    └── REQ-<编号>-<短名>/              一次请求一个文件夹：request.md + 按需派生
                                       baseline.md / plan-*.md / handoff.md
```

## 协作规则（唯一权威：AGENTS.md）

权威排序、请求闭环、进度单面、三条维护约定与编辑自检、requests 评审流程、收口机制、
Git 与推送纪律，全部见 [`AGENTS.md`](./AGENTS.md)；本索引不复述（约定 1）。
