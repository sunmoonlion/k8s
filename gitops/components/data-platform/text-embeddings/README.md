# CPU中文文本向量服务

本机CPU服务采用config固定模型/revision和dimensions，文件/镜像身份取artifacts锁；TEI与官方safetensors从已验证宿主目录启动，HF_HUB_OFFLINE，无启动下载/远程Python/GPU。

## CPU与协议参数

UID1000、模型只读、根只读、禁SA token/cap，内部8080没有公网入口。服务本身无Bearer密钥，依靠仅RAGFlow标签允许的网络策略；不将其直接公开或宣称已有TLS认证。

float32、batch_tokens、client_batch_size、concurrent_requests、tokenization_workers及resources控制CPU/内存/堆积；当前1024维，长输入截断须与文档分块协调，不能假设完整32k都处理。查询加官方检索指令、文档不加，禁止统一给所有输入强加查询前缀。

## 模型变更与验收

render核所有模型文件/hash，只复制缺失内容到静态Retain卷，拒绝链接/漂移/覆盖。模型升级需匹配文件锁与revision/维度、重新索引派生数据并重新验收；后续外部模型服务切换尚未实现。

services-check实际请求health/info、OpenAI embeddings及TEI native embed，核固定修订/版本/float32、有限数值/归一化/维度、两组中文相关性、重复输出。四样本检查不是模型benchmark；实际RAG/业务检索另外由相应验收覆盖。模型资源与未验能力见验收边界。

## 配置字段

当前值以[config.yaml](config.yaml)为准，手册维护字段职责，不再复制一套默认值。

| 字段 | 类型 | 维护条件 |
|---|---|---|
| `services_text_embeddings_enabled` | 开关 | 部署/渲染准入；不代替停止、卸载或删除数据。 |
| `text_embeddings_model` | 文本/表达式 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `text_embeddings_model_revision` | 文本/表达式 | 固定身份或初始化代次；变更前审核来源/迁移，不用递增代次掩盖失败。 |
| `text_embeddings_dimensions` | 整数 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `text_embeddings_port` | 整数 | 与客户端、TLS、入口/Service及网络策略联动；既有节点端口映射不能热改。 |
| `text_embeddings_volume.name` | 文本/表达式 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `text_embeddings_volume.node` | 文本/表达式 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `text_embeddings_volume.size` | 文本/表达式 | PV声明容量；不构成ext4目录硬配额，不自动扩盘。 |
| `text_embeddings_volume.uid` | 整数 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `text_embeddings_volume.gid` | 整数 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `text_embeddings_resources.requests.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `text_embeddings_resources.requests.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `text_embeddings_resources.limits.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `text_embeddings_resources.limits.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `text_embeddings_batch_tokens` | 整数 | 身份相关参数；秘密值留私有输入，不作为文件编辑即完成轮换的承诺。 |
| `text_embeddings_client_batch_size` | 整数 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `text_embeddings_concurrent_requests` | 整数 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `text_embeddings_tokenization_workers` | 整数 | 身份相关参数；秘密值留私有输入，不作为文件编辑即完成轮换的承诺。 |

## 部署、检查与退回

共同平台操作走[services维护](../../../../infrastructure/services/README.md)的候选→审阅→stage/提交→发布晋级→bootstrap/check；组件没有另一套部署入口。版本/摘要取[物料锁](../../../../infrastructure/artifacts/README.md)，运行namespace取共享site。关闭开关不会自动停服或清数据。

配置、身份或卷不符时保留现场；退回固定源的方法见[Flux维护](../../../../infrastructure/flux/README.md)，schema/账号/持久数据不随Git自动回滚。日期结果与未覆盖范围在[验收边界](../../../../docs/platform-kind-v1/verification.md)。
