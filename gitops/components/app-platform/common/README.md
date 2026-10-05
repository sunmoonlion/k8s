# 应用共用机制

此目录由[原生应用编排](../../../../infrastructure/applications/README.md)直接渲染，四应用都使用它，不通过模板应用转接。各应用自己的config、image.lock、生成声明及SOPS仍在所属应用/前后端目录。

## 模板归属

| 路径 | 维护责任 |
|---|---|
| backend/database、migration | 建库/运行与迁移账号隔离、schema核对 |
| backend/redis、rabbitmq | 应用持久身份、键前缀/vhost与真实拒绝检查 |
| backend/identity | Web/Admin注册与精确回调，不授予业务权限 |
| [backend/service-identity](backend/service-identity/README.md) | Info摄入和Investment检索的独立服务身份 |
| [backend/storage](backend/storage/README.md) | 应用原文桶、版本与受限S3身份 |
| backend/runtime、stages.yaml.j2 | API/Worker/Scheduler运行声明与Flux依赖 |
| web、admin | 分面独立的前端运行声明 |

模板不定义第二套用户名、域名、镜像版本。修改共用模板前查看四应用的生成差异；不能只检查tpl，把其它应用作为未经审阅的副作用。初始化Python模板经渲染进入所属Job的ConfigMap。

## 更新与不可变Job

后端镜像由各应用源码提交及锁定构建产生。生产async_sessionmaker需expire_on_commit=False，实际API检查此行为，避免异步任务访问提交后回执触发MissingGreenlet；此约束属于业务源码，不由部署模板修补运行容器。

已完成Job内容不可原地修改。初始化输入或引用的后端镜像改变时，审阅受影响阶段并显式更新该阶段revision；迁移Job同时按镜像摘要命名。复用原身份与逐字节备份，不能以新Job代次冒充密码轮换。

成功Job留作Flux期望对象；直接删除或加TTL会使Flux可能重建。旧Job退役须确认已从晋级声明移出、依赖不再引用，保存结果后按具体UID/resourceVersion清理；不按Completed状态批量删。

## 维护流程

先在一个受影响应用准备候选并审阅，再核对其他应用；提交、发布、显式晋级和执行方法统一见[应用手册](../../../../infrastructure/applications/README.md)。验收既查初始化回执，也查实际角色/登录/消息，范围见[应用与业务链路](../../../../docs/platform-kind-v1/verification.md#应用与业务链路)。

业务schema、持久身份或远端数据变化不能仅靠Git回退；此目录不增加另一个部署CLI、业务启动脚本或删除策略。
