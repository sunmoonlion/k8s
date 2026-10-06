# fable 的应用进新体系（第 10 步在新体系里怎么做）

> 状态：**设计，2026-10-06**，等所有者看一眼就动手。新体系（`infrastructure/`、`gitops/`）部署的是 master 版应用；这一份说清把 fable 上的应用（9 月以来的后端、页面、迁移、沙箱、会合点）搬进去要改什么、按什么顺序、怎么验。
> 对应迁移账本第 1 至 44 行的落点（[`platform-kind-v1-review.md`](../../platform-kind-v1-review.md) 第四节）。旧 `sunmoonai/` 树冻结不删，只当对照。

## 一、新体系现在缺什么

| 缺的 | 现状 | 来源 |
| --- | --- | --- |
| 应用自己的配置项 | 后端模板只渲染数据库、Celery、RabbitMQ、S3、服务身份这些共用项；`domain_runtime_env` 只准放 `STORAGE_BACKEND`、`SEARCH_BACKEND` 两个键。`CROSS_APP_*`、`WORKBENCH_*`、`KNOWLEDGE_MCP_*`、`KNOWLEDGE_DATASET_*`、`SECURITY_*` 没有地方放 | `common/backend/prepare.yaml` 的断言、`runtime/workload.yaml.j2` |
| 应用自己的秘密 | 只有共用的几类（库、Redis、Rabbit、浏览器身份、S3、服务身份）。工作台的凭据密钥、令牌签名私钥、供给器令牌、会合点管理口令，知识服务的 MCP 验签公钥，没有地方放 | 同上 |
| investment 的第四个角色 `runner` | 模板只有 api / worker / scheduler；旧体系有 `investment-backend-runner`（`python -m app.bootstrap.runner`，是每个用户沙箱里 app-server 的唯一客户端） | 旧 `20-runtime.yaml` |
| 网络放行 | 新体系默认拒绝、按标签放行。缺：investment api → 供给器（8080）与会合点管理口（47100）；runner → 沙箱 Pod（47800）；沙箱 Pod → investment api 的 `/api/mcp/workbench`、→ knowledge api 的 `/api/mcp/knowledge`、→ 会合点；info worker → 巨潮、东方财富（公网） | 旧 `render_investment_release_base.py` 的 egress 函数 |
| 会合点镜像 | 钉的是旧集群的 `app-images/relay` v1-r3，来历没核实；新体系自己的构建链只会构建四个应用的 backend/web/admin | `relay/image.lock.yaml`、`applications/build.yaml` |
| 沙箱供给器 | 默认关：现有镜像把沙箱的网络策略写死在 `edge` 命名空间、动态 Pod 不满足 restricted PSS。沙箱镜像还要带上 Codex 配置的改动（关 `multi_agent`、`goals`；新的 `sunmoon_workbench` 工具服务） | `sandbox-platform/provisioner/README.md`、迁移账本 31、32 |
| 源码与迁移版本 | `sources.yaml` 钉 master；`expected_schema_revision` 是 master 的（info `0009`、knowledge `0006`、investment `0011`） | — |
| investment → knowledge 的检索身份 | `knowledge_service.enabled: true`，所有者已定撤销 | 迁移账本 21 |

## 二、机制上加什么（共用模板，一次做好，四个应用都用）

| 加的 | 做法 | 守住的 |
| --- | --- | --- |
| `domain_env` | 各后端 `config.yaml` 新增一个 map，渲染进 `<app>-runtime` ConfigMap。键名 `^[A-Z][A-Z0-9_]{2,63}$`，值是字符串；不许和模板已经管的键重名（列一张清单断言） | 明文配置只在 Git 里一处；不碰秘密 |
| `domain_secrets` | 各后端 `private_dir/domain.yaml`（root 0600，主备非覆盖、逐字节比对，和 `redis.yaml` 一个做法），内容是 `ENV: 值`。prepare 加密成 `runtime/domain.sops.yaml`（Secret `<app>-domain-runtime`），按角色 `envFrom`。首次生成的随机值由 prepare 写（和 identity 的 `web_secret` 一样） | 秘密只在私有输入和 SOPS 密文 |
| 跨组件共享的秘密 | 三样要两边一致：供给器令牌（investment ↔ 供给器）、会合点管理口令（investment ↔ relay）、令牌签名密钥对（investment 私钥 ↔ knowledge、relay 公钥）。前两样已经是平台级组件输入（`services_config_dir/sandbox-provisioner.yaml`、`relay.yaml`），investment 的 prepare 读它们（有先例：storage 的 prepare 读 `object-storage.yaml`）。签名密钥对新加一个平台级输入 `workbench-signing.yaml`（ES256，`openssl ecparam` 生成一次，主备），investment、knowledge、relay 三处 prepare 都读它 | 一处生成、三处引用，不复制值 |
| `runner` 角色 | 模板的角色循环加 `runner`，只在 `cfg.runner_replicas | default(0) > 0` 时渲染：命令 `python -m app.bootstrap.runner`，不开端口，探针用进程存活，`envFrom` 同 api 再加 `domain`，独立 ServiceAccount 与出站策略 | 其他三个应用渲染不变（`runner_replicas` 不写就是 0） |
| 跨应用链接 | 不手配。模板从三个应用的网页端 `origin` 推出 `CROSS_APP_TARGETS_JSON` 与 `CROSS_APP_SOURCES_JSON`（info、knowledge 认 investment 带来的用户，回跳 `<investment origin>/zh-CN/workbench?ref={ref}`） | 地址只在 `*-web-frontend/config.yaml` 一处 |
| 应用级出站策略 | `domain_egress` 列表（目标命名空间、Pod 标签、端口），渲染成 NetworkPolicy；公网目标用 `ipBlock`（Calico 的标准策略不认域名，巨潮、东方财富的地址段写进 info 的配置并注明日期；换地址是改配置） | 默认拒绝不变 |
| 非应用的自研镜像构建 | `platform-build` 加一类「组件镜像」：源码在 k8s 仓里（`sunmoonai/relay-platform/relay`、`sunmoonai/sandbox-platform/{image,provisioner}`），钉 k8s 仓的提交，产物发到 `platform/relay`、`platform/sandbox`、`platform/sandbox-provisioner`，写各组件的 `image.lock.yaml` | 和四个应用同一条链、同一种锁 |

机制改完，先在 tpl 上渲染，核对四个应用「不写新字段时」生成的声明一个字节不变（和 A2 切片的验法相同）。

## 三、每个应用改什么

| 应用 | 配置（`domain_env`） | 秘密（`domain.yaml`） | 其他 |
| --- | --- | --- | --- |
| investment | `WORKBENCH_ENABLED`、`WORKBENCH_REDIS_KEY_PREFIX`、`WORKBENCH_ENVIRONMENT_KEY`、`WORKBENCH_POLL_SECONDS`、`WORKBENCH_PROVISIONER_URL`、`WORKBENCH_RELAY_ADMIN_URL`、`WORKBENCH_RELAY_PUBLIC_URL`（会合点的公共 wss 地址）、`WORKBENCH_TOKEN_ISSUER`、`WORKBENCH_SANDBOX_MODEL_PROVIDER/MODEL/PROVIDER_BASE_URL`、`WORKBENCH_RECORDS_MCP_ENABLED/URL`、`WORKBENCH_MODEL_PRICES_JSON`（可不配）；去掉旧的 `AGENT_*`、`KNOWLEDGE_RETRIEVAL_*` | `WORKBENCH_CREDENTIAL_KEY`（首次随机）、`WORKBENCH_PROVISIONER_TOKEN`（读供给器输入）、`WORKBENCH_RELAY_ADMIN_TOKEN`（读 relay 输入）、`WORKBENCH_TOKEN_SIGNING_KEY`（读签名输入的私钥） | `runner_replicas: 1`；`knowledge_service.enabled: false`；迁移 `0011 → 0012`，`migration_job_revision` v2 → v3；出站：api → 供给器、会合点管理口；runner → 沙箱 Pod 47800；入站：沙箱 Pod → api |
| knowledge | `KNOWLEDGE_MCP_JWT_ISSUER`、`KNOWLEDGE_MCP_RATE_PER_MINUTE`、`KNOWLEDGE_CATALOG_RATE_PER_MINUTE`、`KNOWLEDGE_DATASET_REGISTRY_ENABLED=true`、`KNOWLEDGE_DATASET_ALLOWED_BUCKETS=info-originals`、`KNOWLEDGE_DATASET_CACHE_DIR`、`KNOWLEDGE_SEMANTIC_ENGINE_ENABLED=true`、`KNOWLEDGE_SEMANTIC_CACHE_DIR`、`KNOWLEDGE_DATASET_TITLE` | `KNOWLEDGE_MCP_JWT_PUBLIC_KEY`（读签名输入的公钥）；`KNOWLEDGE_MCP_TOKENS_JSON` 留 `{}`（只认 JWT） | 数据集文件从 info 的桶读：provider 已有的只读身份把 `source_prefix` 从 `info/original/` 放宽到 `info/`（或加第二个前缀 `info/securities/`）；缓存目录给 emptyDir（容量上限按数据集大小定）；迁移 `0006 → 0007`；入站：沙箱 Pod → api 的 MCP |
| info | `KNOWLEDGE_APP_DATASET_URL`（从服务关系推出，和 `KNOWLEDGE_APP_INGEST_URL` 一样）、`SECURITY_*` 都可不配 | 无 | 迁移 `0009 → 0013`；worker 内存上限按 1.2 GB 核（账本 14、19）；出站：worker → 巨潮、东方财富 |
| tpl | 无 | 无 | 只换源码钉版和镜像 |

网页端、管理端：只换源码钉版和镜像；`origin` 不变。

## 四、会合点与沙箱

| 项 | 做法 |
| --- | --- |
| relay | 用第二节的「组件镜像构建」从 fable 的 `sunmoonai/relay-platform/relay` 构建，发到 `platform/relay`；`auth.sops.yaml` 多一个 `RELAY_JWT_PUBLIC_KEY`（读签名输入）；公共地址 `relay.sunmoonai.com:30443`（已有 IngressRoute） |
| 沙箱镜像 | 从 fable 的 `sunmoonai/sandbox-platform/image` 构建（带上账本 31、32 的 Codex 配置改动），发到 `platform/sandbox` |
| 供给器 | 代码改两处再构建：命名空间与会合点地址从环境变量来（不再写死 `edge`、`sandbox-pool`）；拉起的沙箱 Pod 补 restricted PSS 要求的字段（非 root、只读根、drop ALL、seccomp）。然后 `services_sandbox_provisioner_enabled: true` |
| 沙箱 Pod 的网络策略 | 由供给器创建：出站只到会合点、investment api 的 MCP、knowledge api 的 MCP、模型厂商的公网地址；入站只来自 runner |

## 五、顺序（每一步一轮或几轮，Cursor 跑，我改）

| 步 | 做什么 | 验什么 |
| --- | --- | --- |
| 0 | 待办 21、22：开机恢复闭合 | 真实重启后平台自己回来 |
| 1 | 机制：第二节全部，先在 tpl 上渲染 | 四个应用不写新字段时声明逐字节不变；`platform-stage OBJECT=app-platform/tpl-app` 退出 0 |
| 2 | 源码钉版到 fable、构建 12 个镜像、写 `image.lock` | `platform-build` 各退出 0；Harbor 里有 12 个新摘要 |
| 3 | 三个应用的配置与秘密（第三节）、迁移版本；`application-stage` 三个应用 | 候选里 Secret 全是密文；`application-deployment-plan` 核到 fable 的迁移 head |
| 4 | relay、沙箱、供给器的构建与配置（第四节） | 三个镜像在 Harbor；供给器开关打开后阶段图多 `sandbox-provisioner` |
| 5 | 提交 → `flux-release` → 显式晋级 → `platform-deploy OBJECT=all` | 这次会把重构后多出的 7 个阶段一起上；63 → 71 阶段全 Ready；四应用迁移 Job 成功 |
| 6 | `platform-check`、`application-check(-public)` 四个应用 | 退出 0 |
| 7 | 人手点：登录、登记 key、拉起沙箱、本地代理接入、聊天、专家、数据目录、申请入库 | 按 `PRD/apps/*.md` 的验收条 |

第 5 步是新体系第一次承载 fable 的应用，要一个维护窗口（2 小时制）。

## 六、不做、待定

| 项 | 说明 |
| --- | --- |
| Argo | 不在这一步。第 5 步仍走 Flux 的现成链（所有者 2026-10-06 定：Flux 不再加功能，但现网用它到退役） |
| 本地代理的安装包 | 另一条线（只做 Windows，还没开工）。第 7 步用开发形态的代理接入 |
| 公网出站的域名放行 | 标准 NetworkPolicy 不认域名。先用地址段；要精确到域名得用 Calico 的 GlobalNetworkPolicy + DNS 策略，等上云时再定 |
| 旧 `sunmoonai/` 树 | 不删。relay、沙箱、供给器的源码还在那里面，构建链指过去 |

## 七、要所有者定的

1. 第二节第四行：签名密钥对放平台级输入（我建议），还是放 investment 的私有目录让另外两处去读。
2. 第三节 knowledge：数据集从 info 的桶读，用 provider 现成的只读身份放宽前缀（我建议），还是另开一个身份。
3. 第五节第 5 步的维护窗口什么时候给。
