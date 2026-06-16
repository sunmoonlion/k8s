# Research App 架构

`research-app` 是 App Platform 的通用研究协作系统，负责跨领域研究项目、
研究任务、研究材料组织、研究过程记录和研究产物沉淀。

它不替代 `investment-app` 的投资领域判断，也不拥有 `info-app` 的资讯原文、
`knowledge-app` 的知识处理副本或 `tools-app` 的工具运行主档。

## 1. 领域定位

`research-app` 面向可复用的研究工作流：

- 研究项目、课题、任务和阶段。
- 研究资料清单、证据引用和版本关系。
- 研究过程记录、协作记录和结论草稿。
- 跨领域研究产物的状态、发布和审计。

投资专用的组合、标的、策略、评级和决策仍属于 `investment-app`。

## 2. 数据所有权

`research-app` 拥有通用研究协作数据。它引用其他 App 的稳定标识和版本：

- 引用 `info-app` 的 `info_id` 和 `version_id`。
- 引用 `knowledge-app` 的知识空间、检索任务或 AI 运行记录。
- 引用 `tools-app` 的工具任务结果。
- 引用 `auth-app` 的用户、组织和权限主体。

跨 App 引用不复制对方主档。需要历史可重现时，可以保存必要的只读快照，
但必须同时保留来源 App 的标识、版本和哈希。

## 3. 当前部署组件

```text
research-app
├── research-web-backend
├── research-admin-backend
├── nodebullworker-research-web-backend
├── celeryworker-research-admin-backend
├── research-web-frontend
├── research-admin-frontend
└── deploy-research-app-all
```

四个模板组件完整保留。具体业务职责在实现功能时按唯一写入原则分配给
对应 Backend；未承载业务的组件可以保留样板代码，但是否启动由 Kubernetes
部署配置决定。
