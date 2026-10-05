# 组件配置与维护导航

目录保持平台→应用→组件；用户config、实现、生成声明和README同职责放置。入口用[services](../../infrastructure/services/README.md)或[applications](../../infrastructure/applications/README.md)，共享环境用[site](../../infrastructure/environments/kind/README.md)，发布晋级用[Flux](../../infrastructure/flux/README.md)。

## 对应物料在哪里

本地批次的`components/`沿用本目录的平台→应用→组件归属，组件下再分images/charts/models等类型。共用基础镜像和工具在批次shared，建群/宿主/Harbor物料各有独立归属，不强行放进组件树。

在k8s根运行`make -C infrastructure material-inventory MATERIAL_OWNER=components/data-platform`，或指定完整组件归属，查看物料ID、路径和Harbor目标。版本/摘要以[artifacts锁](../../infrastructure/artifacts/README.md)及各组件成品锁为准；应用依赖在线下载，成品在Harbor，不要求每个组件有离线文件。

## 文件应该怎么改

| 文件 | 谁维护/怎样生效 |
|---|---|
| config.yaml | 用户普通参数，含开关/用户名/port/资源/代次；改后准备候选、审阅、发布晋级 |
| stage.yaml | 本对象的Flux阶段、依赖与所需物料；所在目录即`OBJECT`，写法见[components](../../infrastructure/components/README.md) |
| workload/config/provision等模板 | 维护实现，消费同目录或共享参数；common只保存共用机制 |
| workload/kustomization等生成YAML | render/stage输出并提交，由Flux拥有；不散改默认值 |
| *.sops.yaml | 私有输入加密结果；不是明文密码编辑入口 |
| image.lock.* | 固定成品/必要派生镜像身份；上游版本取artifacts锁 |
| prepare/verify等程序 | 专用输入准备/协议检查，保留真实职责；不另建部署CLI |

## 平台组件

| 平台 | 组件维护说明 |
|---|---|
| 基础 | [foundations](foundations/README.md)；core只组合资源，不维护第二份用户配置 |
| 数据 | [PostgreSQL](data-platform/postgresql/README.md)、[Redis](data-platform/redis/README.md)、[对象存储](data-platform/object-storage/README.md) |
| 检索 | [向量模型](data-platform/text-embeddings/README.md)、[RAGFlow](data-platform/ragflow/README.md)、[Infinity](data-platform/infinity/README.md)、[Valkey](data-platform/valkey/README.md) |
| 日志/图/文档库 | [ELK](data-platform/elk/README.md)、[Neo4j](data-platform/neo4j/README.md)、[MongoDB](data-platform/mongodb/README.md) |
| 消息 | [RabbitMQ](messaging-platform/rabbitmq/README.md) |
| 入口 | [Traefik](ingress-platform/traefik/README.md)、[内部HTTPS](ingress-platform/traefik/service-access/README.md) |
| 身份/应用 | [Casdoor](app-platform/auth-app/casdoor/README.md)、[Tpl](app-platform/tpl-app/README.md)、[Info](app-platform/info-app/README.md)、[Knowledge](app-platform/knowledge-app/README.md)、[Investment](app-platform/investment-app/README.md) |
| 共享机制 | [common](app-platform/common/README.md) |

目录归属与运行namespace分开，例如Casdoor数据库Job仍在data_namespace；四应用及Casdoor服务统一app_namespace。用户名在config或注明固定实现处，真实口令在私有主备/SOPS；端口标明内部Service、NodePort、宿主映射或公共TLS层。

开关不代替stop/uninstall，prune=false不自动删旧对象，Retain不自动迁移PV。初始化完成Job仍由Flux持有，改不可变输入须新代次，不能为清列表通配删除。模块真实检查可能写入临时探针；读其权限/清理边界。
