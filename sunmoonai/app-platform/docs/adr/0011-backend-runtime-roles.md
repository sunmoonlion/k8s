# ADR-0011：一个 Backend 代码库按运行角色部署

- 状态：已接受
- 日期：2026-08-01

## 背景

API、异步任务、定时扫描、迁移和 Agent 执行具有不同生命周期，但把每个角色理解为独立
Backend 会再次分裂领域所有权。反过来把所有角色塞进一个进程，则会阻塞请求、混淆扩缩容
和故障边界。

## 决策

同一 Backend 代码库提供以下启动入口：API、Worker、Scheduler/Scanner、Migration、CLI；
Research 另有 Agent Worker。默认由同一 source commit 和同一候选镜像以不同 command 启动。

只有以下触发条件满足时才建立同仓、同 release manifest 的角色镜像变体或独立队列：

- 浏览器、GPU、沙箱等依赖显著扩大攻击面或镜像体积；
- 任务时长、重试或取消语义显著不同；
- 需要独立网络/服务身份；
- 有持续容量指标支持独立扩缩容；
- 故障隔离无法通过队列和 Pod 边界实现。

角色变体不获得独立领域模型、数据库所有权或迁移链。

## 初始容量策略

- 每个 App 先建立一个通用 Worker Deployment；
- Info 重点观测网络/浏览器/文件与 Outbox；
- Knowledge 重点观测长摄取、RAGFlow、索引与对账；
- Research 重点观测 LLM、工具、checkpoint、HITL、取消和沙箱；
- 以队列延迟、运行时长、资源、失败率和权限证据触发拆分。

## 结果

代码与数据所有权统一，进程、Pod、队列和容量仍可独立治理。
