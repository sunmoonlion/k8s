# Knowledge 的 RAGFlow 与原文读取接入

配置唯一在上级 `config.yaml/knowledge_provider`。地址从环境命名空间、平台组件端口组合，token从已保存的RAGFlow知识服务身份引用；不复用浏览器、数据库或Info写账号。用户不手工复制token。源读取密码在应用私有目录 `provider-source.yaml`，数据集绑定在 `provider-binding.json`，两者root0600及独立逐字节备份；Git仅SOPS。

`make -C infrastructure application-stage APP=knowledge` 沿用原生准备与渲染，除私有输入外会通过已运行RAGFlow的官方API准备一个私有中文纯文本数据集；这是明确的外部身份/数据集准备副作用，不是纯预览。纯计划用 `application-deployment-plan APP=knowledge`。已有绑定必须与远端ID/名称一致；丢失或同名未记录对象拒绝静默认领。POST结果未知时停止，按原私有输入与远端核对后再恢复，不重复创建。

提交、`flux-release`、核对并晋级固定源后，`application-bootstrap APP=knowledge` 串联候选核对、Flux及真实验收。源读取账号由独立Job配置，只能GetObject/GetObjectVersion `info-originals/info/original/*`；不能写、列桶、读派生桶或管理。只给Knowledge API/Worker RAGFlow token和原文只读身份，Scheduler只挂公共CA。RAGFlow数据是派生索引，不创建Knowledge原文权威副本。原文VersionId、大小、媒体类型、SHA始终严格核对，TLS不开跳过。

验收复用真实Info ObjectStorage适配器创建本轮随机原文，再调用Knowledge现有应用服务提交持久意图；实际Scheduler/Outbox/Worker执行解析，Knowledge领域检索返回中文证据和原文引用。校验幂等、冲突、来源只读、租户/数据集/关系scope和版本过滤。它是组件集成，不能称为Info HTTP授权投递、Investment HTTP消费或浏览器全集验收；这些还须独立接通服务身份。

只清理本轮UUID原文VersionId、成功摄入Job、对应领域记录/已结束投递记录和精确RAGFlow文档及S3版本；不删正式数据集或任何其它对象。失败摄入不删除以便查明，秘密不进输出。删除保留策略不在此处实现。
