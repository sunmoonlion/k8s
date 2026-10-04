# 知识应用 Backend

用户参数、镜像锁、生成声明与加密 Secret 同处，由原生 `application-stage/bootstrap APP=knowledge` 部署，直接使用 common 机制。口令在应用私有目录与独立非覆盖备份；不借用其它应用身份。

`config.yaml/knowledge_provider` 控制 RAGFlow 派生索引及 Info 原文读取；配置、身份准备、初始化声明和实际验收位于 [provider](provider/README.md)。地址从环境和平台组件配置组合，运行期不会创建数据集。原文仍由 Info 管理，Knowledge 只按固定 VersionId 读取并核对摘要。

当前已实际验证基础登录、独立数据库、消息、TLS 入口，以及持久入库任务由真实 Scheduler/Outbox/Worker 完成解析、中文领域检索和权限边界。配置 knowledge_service_receiver.enabled 后，验收已接通Info→Knowledge真实HTTPS认证摄入及Investment→Knowledge领域Port HTTPS检索，并核对服务身份日记与关系/租户/数据集拒绝；调用方配置分别在自己的后端config.yaml/knowledge_service，机制见common/backend/service-identity。完整Info爬取投递及投资Agent工具执行另行验收。

日常核验：

```sh
make -C infrastructure application-check APP=knowledge
```

已有固定发布的一键部署使用 `application-bootstrap APP=knowledge`。改配置走 stage→本地提交→flux-release→核对并晋级固定源→bootstrap；不手工 patch Pod，不将就绪状态代替业务验收。每次只清理该轮 UUID 验收对象，保留正式数据集和其它业务数据。
