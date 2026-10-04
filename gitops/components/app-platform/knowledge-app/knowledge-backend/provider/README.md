# Knowledge 的 RAGFlow 与原文读取接入

配置唯一在上级 `config.yaml/knowledge_provider`。地址从环境命名空间、平台组件端口组合，token从已保存的RAGFlow知识服务身份引用；不复用浏览器、数据库或Info写账号。用户不手工复制token。源读取密码在应用私有目录 `provider-source.yaml`，数据集绑定在 `provider-binding.json`，两者root0600及独立逐字节备份；Git仅SOPS。

`make -C infrastructure application-stage APP=knowledge` 沿用原生准备与渲染，除私有输入外会通过已运行RAGFlow的官方API准备一个私有中文纯文本数据集；这是明确的外部身份/数据集准备副作用，不是纯预览。纯计划用 `application-deployment-plan APP=knowledge`。已有绑定必须与远端ID/名称一致；丢失或同名未记录对象拒绝静默认领。POST结果未知时停止，按原私有输入与远端核对后再恢复，不重复创建。

提交、`flux-release`、核对并晋级固定源后，`application-bootstrap APP=knowledge` 串联候选核对、Flux及真实验收。源读取账号由独立Job配置，只能GetObject/GetObjectVersion `info-originals/info/original/*`；不能写、列桶、读派生桶或管理。只给Knowledge API/Worker RAGFlow token和原文只读身份，Scheduler只挂公共CA。RAGFlow数据是派生索引，不创建Knowledge原文权威副本。原文VersionId、大小、媒体类型、SHA始终严格核对，TLS不开跳过。

验收复用真实Info ObjectStorage适配器创建本轮随机原文。当上级 knowledge_service_receiver.enabled 启用时，使用Info实际客户端通过HTTPS及独立Casdoor服务令牌投递，核对Knowledge摄入日记中的认证身份，真实Scheduler/Outbox/Worker执行解析，再由Investment实际领域Port使用另一身份HTTPS检索中文证据与原文引用。核验HTTP幂等/冲突、缺失/篡改令牌、关系交叉调用、浏览器分面拒绝、租户/数据集及版本过滤，同时保留源只读与领域检查。未启用服务接收时只做既有L2组件验收；完整Info爬取发布链、投资Agent工具执行、浏览器全集另行验收。服务身份机制与配置归属见common/backend/service-identity/README.md。

只清理本轮UUID原文VersionId、成功摄入Job、对应领域记录/已结束投递记录和精确RAGFlow文档及S3版本；不删正式数据集或任何其它对象。失败摄入不删除以便查明，秘密不进输出。删除保留策略不在此处实现。

验收开始前在Knowledge私有目录建立 acceptance-<correlation UUID>.json（root0600），仅保存随机探针ID、原文引用与清理状态，不保存令牌。失败时保留该记录及原文，避免删除尚在Worker消费的输入；成功完成领域和派生清理后才删除原文版本和记录。依据精确记录处理失败探针，不能按桶或目录批量删除。
