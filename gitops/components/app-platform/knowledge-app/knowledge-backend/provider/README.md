# Knowledge原文与检索接入

用户配置唯一在上级[config.yaml](../config.yaml)的knowledge_provider与knowledge_service_receiver；此目录保存远端准备、Job声明及实际验收。RAGFlow为派生索引，Info对象原文仍为权威，不在此建立第二份权威副本。

## 字段和私有输入

dataset_key/name、tenant_id、source_user/bucket/prefix及job_revision界定知识集和Info原文读权限。平台RAGFlow地址/端口及命名空间组合，token引用已保存RAGFlow知识身份，不要求用户复制，也不借浏览器/Info写账号。

private_dir/provider-source.yaml为原文读取口令，provider-binding.json为远端数据集绑定；root0600并在backup_dir非覆盖逐字节保存，Git只存SOPS。API/Worker获得RAGFlow token和源只读身份；Scheduler仅挂公共CA。

只允许GetObject/GetObjectVersion到info-originals/info/original/*，拒绝写、列桶、读派生桶及管理。严格核VersionId、大小、媒体类型、SHA和TLS。任何摘要/范围不符停止，不用最新对象代替指定历史版本。

## 准备与部署

```sh
make -C infrastructure application-deployment-plan APP=knowledge
make -C infrastructure application-stage APP=knowledge
```

plan只读；stage除了私有输入/候选文件，还调用已运行RAGFlow官方API准备私有中文纯文本数据集，不能当纯预览。现有绑定须匹配远端ID/名称；同名未记录对象或丢失绑定拒绝认领。创建POST结果不明停止，按已有输入与远端核对，不自动重发创建。列表查找有分页边界。

提交、发布、审核显式晋级后application-bootstrap完成候选核对、Flux及真实验收；运行角色不负责创建数据集。方法见[应用维护](../../../../../../infrastructure/applications/README.md)及[服务身份](../../../common/backend/service-identity/README.md)。

## 真实业务探针

接收启用时，实际Info ObjectStorage适配器创建随机原文，Info实际客户端携独立Casdoor令牌HTTPS投递；检查Knowledge持久摄入日记的认证主体，由真实Scheduler/Outbox/Worker完成解析，再由实际Investment领域Port持另一身份HTTPS获取中文证据与原文引用。

同时检查幂等/冲突、缺失/篡改令牌、服务关系交叉、浏览器分面拒绝、租户/数据集与版本过滤；未启接收时仅既有L2检查。不能由此推定完整Info爬取、Agent工具执行、PDF或浏览器全集通过。

## 失败保留与精确清理

开始前private_dir写acceptance-<correlation UUID>.json，root0600，仅随机探针ID、原文引用及清理状态，不含令牌。失败保留日记、原文和摄入Job，先确认Worker消费状态，不能抢先删输入。

成功只清本次UUID指定的成功摄入Job、对应领域记录/已结束投递与Outbox、精确RAGFlow文档及S3版本；再删除原文指定VersionId与日记。不删正式数据集、其它原文/桶或未知对象。清理失败按日记恢复精确处理，不全目录批删，也不把删除日记当恢复完成。

检查入口application-check APP=knowledge会有上述写入/精确删除副作用；纯状态先看Flux/Pod。恢复仍需源原文、平台数据库、派生状态与身份配套，当前完整灾备未验收，见[验收边界](../../../../../../docs/platform-kind-v1/verification.md#未完成项)。
