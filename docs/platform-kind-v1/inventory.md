# KIND 部署输入盘点

本盘点限定于新工作区的父仓、子模块和选定源码入口，供架构设计使用。没有连接现场集群或查询私有凭据；不是逐文件审计，也不是运行态验收。

## 五仓基线

五仓分支均为 `platform-kind-v1`，创建时与各自本地 master 相同。四个应用仓的 12 个组件子模块已按 gitlink 初始化，五仓工作树创建后均干净；没有联网 fetch。

| 仓库 | 固定提交 |
| --- | --- |
| k8s | `4156a8b0a7b93b16fc8f77eadfcda36332eb0aff` |
| tpl-app | `3317c84d984fdd6dbeb4ab490685f9fcdff569a3` |
| info-app | `244f724dce91d373bd6dd35362d471c565ebf7a9` |
| knowledge-app | `b4e6f66624e91b2dbc720cdcc9615b0c73dbb349` |
| investment-app | `b66223cf89092ac4056c523358763f5cf2500b1a` |

当前 luna 与这些提交有差异。新体系接入前必须审查业务契约差异；本次没有执行 cherry-pick 或修改应用仓。同步脚本依据工作区白名单选择五仓，新工作区尚未登记，也未向远端推送。

## 已核源码角色与配置入口

四个后端均存在 `app/app/bootstrap/{api,worker,scheduler,migration}.py`。Knowledge 另有 `mcp.py`，Investment 另有 `runner.py`，后者检查工作台开关后才启动。角色存在不等于当前环境已经启用。

以下根据配置字段和启动源码确认接口存在，未据此推断所有可选能力默认开启：

| 应用 | 配置入口 | 已核依赖接口 |
| --- | --- | --- |
| tpl | `tpl-app/tpl-backend/app/core/config.py` | PostgreSQL、Redis、Celery broker、Casdoor |
| info | `info-app/info-backend/app/core/config.py` | 上述公共依赖、S3 对象存储、Elasticsearch |
| knowledge | `knowledge-app/knowledge-backend/app/core/config.py` | 公共依赖、S3、RAGFlow、跨应用身份 |
| investment | `investment-app/investment-backend/app/core/config.py` | 公共依赖、工作台/智能体 Redis 配置、Knowledge 调用所需身份待逐项核 |

路径均相对于五仓共同父目录。前端为各 App 的 Admin/Web 子模块，后续需核实构建期和运行期环境变量；不在部署层重写业务登录或数据迁移逻辑。

## 组件范围建议

| 类别 | 第一批候选 | 需要继续核对 |
| --- | --- | --- |
| 宿主与集群 | Docker、Harbor、TLS 入口、KIND、CNI、存储与交付控制器 | 版本锁、离线闭包、宿主资源、现有实例纳管 |
| 公共业务依赖 | PostgreSQL、Redis、RabbitMQ、Casdoor、对象存储、Traefik | 固定版本、角色权限、数据恢复、DNS/TLS |
| 现有业务 | Info、Knowledge、Investment；模板作公共能力验证 | 全部运行角色及跨应用功能场景 |
| 搜索与知识增强 | Elasticsearch、RAGFlow、文档转换、OnlyOffice | 实际业务开关、额外依赖及资源，不能凭旧目录名直接纳入或删除 |
| 运维工具 | pgAdmin、RedisInsight、Flower；Kibana、Logstash | 现有用途与新可观测性方案的职责区别 |
| 其他历史组件 | MongoDB、Neo4j、Nodebull Redis、Jenkins 等 | 谁在使用、是否仍需支持；暂不裁定删除 |

基线平台总控配置开启 PostgreSQL、Redis、Nodebull Redis、对象存储、Elasticsearch、Kibana、Logstash；MongoDB 关闭。CI/CD 配置仍开启集群内 Harbor，Jenkins 和 Argo CD 关闭。应用层配置开启认证及三个业务 App。上述只是旧配置事实，不能作为新体系的默认启用清单。

基线项目总览提到四种后端角色，但源码还有 MCP/Runner；基线文档的 kindnet、旧集群和内置 Harbor 描述也不能代表当前现场。本轮优先以源码说明接口，现场状态待执行前重新核对。

## 已确认的约束

继承项目业务合同：每 App 独立逻辑库与身份；数据库迁移由独立 Job 执行；镜像以摘要固定；同一发布绑定源码、镜像、部署和数据基线；跨 App 契约不得被部署重构改变。来源为 `sunmoonai/docs/dev-investment-agent/tree-build/rules/constraints.md` 的 C-D2、C-D3、C-D8、C-R1、C-R2、C-R4、C-R6。

用户已确定：Harbor 在集群外；本地入口域名和端口维持；数据盘 230 GiB；新体系不调用旧部署脚本；正式一键操作及组件开关必须保留；完整重启/重建验收与长期空间管理纳入交付；云端另验。

## 旧代码去留的处理边界

本轮不删除任何文件。实施前生成逐文件清单，依据职责与实际引用决定处置，不用目录名批量推断。

| 内容 | 处理原则 |
| --- | --- |
| 旧建群、旧平台总控、旧连接及推送脚本 | 新实现完成后移出正式调用链，确认替代覆盖后在新分支删除；历史由 Git 保存 |
| 本次迁移和修复工具 | 保留在 luna 参考工作区，新实现不依赖；运行数据与脚本去留分开决定 |
| `sunmoonai/scripts/local-integration/` | 其他人的业务验收工作，明确保护，不删不改 |
| `sunmoonai/utils/db-provisioner/` 与应用中的副本 | 核对调用者和实际行为，再决定新体系如何满足相同身份要求；不得视为无引用备份直接删除 |
| 应用源码、契约与迁移 | 保留，不因部署重写删除 |
| 云上旧流程与旧节点/卷 | 沿用此前保护条件，退出前不得清理；代码、容器、卷不是同一种对象 |
| 旧文档、运行记录、测试 | 分别判断适用性；正式回归测试保留，历史运行产物退出正式说明 |

下一轮需要补齐：全部组件使用关系、精确版本/摘要、同步基线业务差异、物料覆盖、宿主资源及旧文件引用。当前清单只能支持结构讨论，尚不能授权全面删除或宣称物料齐备。
