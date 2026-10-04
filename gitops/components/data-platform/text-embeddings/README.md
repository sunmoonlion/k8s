# CPU 文本向量服务

用户配置在同目录 `config.yaml`，运行模板与固定模型安装在同目录。原生 Make → Ansible → Flux 没有新增部署 CLI。

所有者选择本机 CPU。使用 **Qwen/Qwen3-Embedding-0.6B**，固定模型修订 `97b0c614be4d77ee51c0cef4e5f07c00f9eb65b3`，1024 维；**官方 TEI cpu-1.9.4** 固定 amd64 manifest `sha256:8419f533857b503ebf6ec292a95d4f1cf9c0464ac8b8abeef39518cf110e5726`。模型与镜像的完整身份唯一在 `infrastructure/artifacts/files.lock.json`、`upstream-images.lock.json`，本目录引用锁，不维护第二套摘要。

## 参数与安全边界

| 参数 | 用途 |
| --- | --- |
| `services_text_embeddings_enabled` | 是否渲染运行组件；关开关不自动删除已有数据 |
| `text_embeddings_model` / `text_embeddings_model_revision` | 必须对应完整、已校验的固定模型文件；升级须先更新物料锁并验收 |
| `text_embeddings_volume` | worker2 的独立宿主目录，静态 Retain 卷；4Gi 是声明容量，不是文件系统硬配额 |
| `text_embeddings_resources` | 默认请求 1 CPU / 3Gi，限制 4 CPU / 6Gi；按实际耗时调整 |
| `text_embeddings_batch_tokens` | 默认 2048；长输入由 TEI 截断，RAG 文档分块与查询必须遵守该上限，不能假定完整 32k 上下文 |
| `text_embeddings_client_batch_size` / `concurrent_requests` | 单批 8 条、最多 4 个并发请求，限制 CPU 堆积 |
| `text_embeddings_port` | 集群内部 8080；没有 Ingress/NodePort，不开放到公网 |

API 使用 OpenAI `/v1/embeddings` 协议。不要求用户提供外部模型服务密钥。服务内部不配置 Bearer 密钥，依赖 Kubernetes RBAC、默认拒绝网络策略及仅 RAGFlow 标签允许访问；不能把此无密钥端点直接公开。后续如对外提供服务，先实现 TLS 与认证再发布。

Pod 使用 UID/GID 1000，根文件系统只读，模型只读，无 GPU、特权、额外能力或服务账号令牌。没有公网出口；`HF_HUB_OFFLINE=1`，从已校验宿主文件启动，不在启动时追踪 main 下载模型。使用 float32 在 CPU 运行，权重来源为官方 safetensors，不加载自定义远程 Python。

查询按模型官方说明加检索指令，文档不加查询指令；不能为所有请求统一强加查询前缀。

## 操作

在 `k8s` 下执行：

```bash
make -C infrastructure services-plan SERVICE_IMAGES=text-embeddings-inference
make -C infrastructure services-materials SERVICE_IMAGES=text-embeddings-inference
make -C infrastructure services-publish SERVICE_IMAGES=text-embeddings-inference
# 模型文件选择其 qwen3-embedding-* 锁 ID，通过 plan/fetch/check-artifacts 处理。
# services-stage 产生声明，提交、发布并晋级 Flux 源后才运行 services-bootstrap。
make -C infrastructure services-check
```

`services-render` 从已验证物料复制缺失模型文件到对应 worker2 静态目录，拒绝已有字节漂移和软链；再次渲染不覆盖模型。`services-check` 复核实际镜像 ID、Retain 卷绑定、模型修订，再实际请求健康检查和中文向量，核对维度、有限数值、归一化、两组相关性排序及重复输出。管理验收使用经 kubeconfig 授权的临时 port-forward，不能因此宣称已验 RAGFlow 的实际网络/入库/检索链。

当前安装、推理实测、RAGFlow 检索的结果以 `CHECKPOINT.md` 与实际回执为准；本文件的配置说明不是验收通过声明。

官方依据：[模型说明](https://huggingface.co/Qwen/Qwen3-Embedding-0.6B)、[TEI 1.9.4](https://github.com/huggingface/text-embeddings-inference/releases/tag/v1.9.4)、[CPU 官方部署](https://github.com/huggingface/text-embeddings-inference/blob/v1.9.4/README.md)。
