# 全部组件部署入口的干运行边界

本次修复覆盖平台总控、组件主入口和独立运行的 Secret、Ingress、中间件脚本，
不能只在几个数据库组件的 Helm 命令上加 `--dry-run`。

逐文件位置与参数契约保存在 [deployment-dry-run-inventory.json](deployment-dry-run-inventory.json)。
清单包含六个平台目录的全部 168 个 `deploy-*.sh` / `deploy.sh`，以及总控、部署辅助工具和独立 Harbor 入口，合计 189 项。
这是入口及分支的静态覆盖清单，不是 189 项实机验收记录。

## 覆盖方式

| 入口 | 数量 | 处理 |
| --- | ---: | --- |
| 活动旧 Shell 组件、子组件及辅助工具 | 148 | 第一个公共调用即进入 `utils/deploy-plan.sh`，在配置、凭据、连接库、临时文件和 EXIT trap 之前判断计划；计划直接退出 |
| Info / Knowledge / Investment 总入口及六个角色入口 | 21 | 共用 `formal_deploy_entry.py`；位置 `true` 和命名 `--dry-run` 转到本地 plan，保留发布配置、namespace、镜像/发布门禁 |
| 根平台、Data Platform 总控 | 2 | 同一请求校验后继续现有本地配置计划；不会递归执行组件 |
| 统一 Ingress 与 Traefik 转入入口 | 2 | 保留默认计划及显式 `--apply/--verify`，参数冲突拒绝；本地 Python 使用 `-B` |
| 云基础设施总控 | 1 | 保留 `--dry-run`；补齐 status/steps/materials 的只打印分支，云上未经实机验证 |
| 共享证书入口 | 1 | 保留默认计划与显式执行；拒绝在继承计划模式时执行 apply/verify |
| 独立 Harbor 准备、启停、恢复、备份、SNI、扫描器 | 6 | 原生默认计划、显式 `--apply`；审阅其本地计划分支，保留现有生命周期协议 |
| Document Converter 本地配置生成器 | 2 | Secret/ConfigMap 单资源渲染，--dry-run 在配置之前返回；不使用 kubectl 验证 |
| 私有拉取 Secret 导出 | 1 | 默认计划，--apply 仅写 ~/private 新文件；不读取集群 |
| ONLYOFFICE 本地资源生成器 | 1 | --dry-run 或继承计划在加载配置前退出；默认只生成非 Secret，Secret 必须逐项显式选择 |
| 原集群内 Harbor 三个入口、原 KIND 建群入口 | 4 | 仍拒绝执行；本次不会把停用入口重新启用 |

148 个旧入口包括 PostgreSQL、MongoDB、Neo4j、Redis/NodeBull、对象存储、Elasticsearch、Kibana、Logstash、
RabbitMQ、Jenkins、pgAdmin、RedisInsight、Mongo Express、Flower、Casdoor、OnlyOffice、Document Converter、RagFlow，
及其 Secret、路由和中间件。另补入问数 Demo、Casdoor 初始化/数据库访问工具、手动 Traefik NAT 工具。
这些辅助工具保留原用途；增加计划模式不代表其真实执行方式已符合新版集群的全部要求。

`signup-setup.sh` 是供 Casdoor 初始化脚本 source 的函数库，仍由已纳入清单的调用入口保护。
Chart 内脚本、容器启动脚本、应用代码、数据库 provisioner 的内部 API、全部通用运维工具不属于平台部署 CLI 清单；
不能把入口保护当作对任意函数调用或任意 Shell 配置代码的沙箱。

## 调用约定

旧 Shell 组件推荐统一使用 `--dry-run`，无需记忆各自布尔参数的位置：

```bash
bash sunmoonai/cicd-platform/deploy-cicd-platform-all/deploy-cicd-platform-all.sh --dry-run --cluster KIND deploy
bash sunmoonai/ops-platform/flower/deploy-flower/deploy-flower.sh --dry-run --cluster KIND deploy
bash sunmoonai/app-platform/question-data-demo/deploy.sh --dry-run
```

`--dry-run` / `--dry-run=true` / `--dry-run true` 表示只打印；`false` 保留原实际调用方式。
**没有参数的旧脚本仍保持原行为，不能以为它们默认只打印。**实际部署继续读取原 `.conf` 和 values，
这次没有更改数据库、Harbor 等平台版本、镜像、数据路径、开关值或凭据。

公共入口支持的旧位置契约在清单中逐项标明：

| profile | 位置参数 |
| --- | --- |
| action | action / project / namespace / environment / dry_run |
| action-logs-tail | RabbitMQ 与 action 相同；logs 的第五位数字保留为日志行数，布尔 true 仍表示计划 |
| project | project / namespace / environment / dry_run |
| deploy-project | 43 个只写 Secret 的入口：可选 deploy / project / namespace / environment / dry_run；只支持部署，其他动作提前拒绝 |
| optional-action | 原脚本接受的可选 action，后跟 project / namespace / environment / dry_run |
| namespace | action / namespace / dry_run；也识别父级完整五参数格式中的 dry_run，真实目标参数仍按各原脚本处理 |
| named | 辅助工具保留原参数，只通过命名 `--dry-run` 或继承模式控制计划 |
| root | action / project / environment / dry_run，根总控不接收 namespace |

### Secret 入口的动作边界

清单中 `deploy-project` 的 43 个入口只负责部署 Secret。支持原来的四个位置参数和可选 `deploy` 前缀；
公共层在加载配置前去掉前缀，保留 `--cluster` 交给原集群解析器。`--help` / `help` 在加载配置前显示用法。
`status`、`uninstall`、`delete`、`logs`、`upgrade`、`apply`、`generate`、`restart`、`start`、`stop`、
`cleanup`、`plan`、`verify`、`install` 和重复的 `deploy` 均拒绝，不能把这些词当作项目 ID。
这修复了原来移除 `status/uninstall` 后仍执行 Secret 创建的问题。
有真实动作分支的 OnlyOffice、Document Converter、Jenkins Secret 子入口、Redis/Neo4j Secret 总控等保留原接口；
需要查询或卸载时按对应组件总控的能力操作，不为只写入口伪造成功的状态/卸载结果。

Casdoor 和 Elasticsearch Secret 总控现在使用父级传入的 project、namespace、environment，显式参数优先于配置默认。
已启用的 Secret 子脚本缺失会失败；聚合层传播失败，不能靠最后的成功日志覆盖错误。
Elasticsearch 的 `APPLY_ELASTICSEARCH_MYAPP_SECRET=true` 只允许实际 `elasticsearch-myapp-secret.yaml`，
缺失即失败，不会再把 `.yaml.example` 作为真实凭据安装。默认关闭时不改变其行为。
pgAdmin 认证入口仅保留一套配置、生成和部署流程，移除了原来重复执行的第二套逻辑及密码片段日志。
9 个原先缺少默认值的 Secret 入口补齐直接调用默认值；Elasticsearch MyApp 入口补上遗漏的配置加载。
上述改动没有修改现有 `.conf` 的开关和凭据，实际部署仍须按目标集群准入执行。

普通组件计划只打印请求，不加载组件配置，因此不展示完整展开步骤，不检查真实目标、依赖、凭据、镜像或存储。
根总控和 Data Platform 的详细计划继续读取本地可信 Shell 配置列出开关/优先级；正式应用计划按数据读取发布配置并校验本地 bundle。
其他平台的细节可从现有 `.conf` 和对应组件入口查看。接口不是 Helm 渲染服务。

参数中的布尔值只接受 true/false；重复命名参数、命名与位置冲突、无效模式均拒绝。
`SUNMOON_DEPLOY_DRY_RUN=true` 用于共用 Shell、正式应用及已接入原生适配器的继承防护，子请求不能用 false 关闭它；
它不是覆盖全仓任意程序的安全开关。Harbor 原生 Python 工具仍以其显式 `--apply` 为执行边界。

正式应用现在支持：

```bash
bash sunmoonai/app-platform/info-app/deploy-info-app-all/deploy-info-app-all.sh \
  --cluster KIND deploy sunmoonai app-platform-dev development true
```

计划仍可能因发布配置、namespace 或 bundle 不合法而失败。`server-dry-run` 会访问 Kubernetes API，
属于另一种显式验证动作，不能等同于这里的本地 plan。

## 一并修复的调用错误

- 三个正式应用原来读取兼容位置参数，却忽略最后的 dry_run，deploy 会被映射为 apply；现已在动作映射之前处理。
- CI/CD 总控原来识别 status/uninstall 后仍无条件 deploy；现在按动作调用启用组件，卸载按相反优先级，未知动作拒绝。
- Ops 的 status 原来只有占位提示，现在调用启用组件的 status；卸载失败或脚本缺失返回失败，不再打印平台成功。
- CI/CD、Messaging、App、Ops 及 RabbitMQ Secret 聚合层显式传播子组件失败；启用组件的部署脚本缺失不再忽略。
- Mongo Express Secret 脚本删除原始参数回显；两份缺少首行 shebang 的路由脚本补齐 Bash 声明。
- 上轮六个组件的 main 内重复保护已收口到同一入口检查，避免一个组件维护两份计划分支。

## 验证与剩余边界

本批执行的是 Bash 语法、ShellCheck 错误级、Python AST、JSON、入口清单完整性和路径核对。
没有执行部署入口的计划/实际分支、行为测试、Helm、Docker、Kubernetes、SSH、Windows 或数据清理。
因此不能以此宣称所有组件已在新集群安装成功，或所有真实部署内部命令均已完成故障验证。

后续验收应覆盖命名/位置布尔参数、冲突参数、无效配置、子脚本失败、目标 UID 变更等路径；
云端仍须首次上云验收。实际部署中的凭据与版本准入继续沿既有迁移清单处理。
旧集群、节点、卷、Harbor 数据保护不变；最终本机重构临时文件和东京下载物料的清理仍是必做收尾项。

## 镜像拉取 Secret 后续收口

覆盖清单中的 17 个 Harbor/Kaniko Secret 部署入口现共用 [registry-platform 拉取身份实现](../registry-platform/docs/pull-secrets.md)，保留本页提前返回边界及 profile。13 个只写入口保留 deploy-project；Jenkins 两个 namespace 和 OnlyOffice/Document Converter 两个 action 入口保留 deploy/status/uninstall。Document Converter 拉取 Secret 的 generate 动作从部署入口退役；旧独立生成器已删除，人工用途改用 [统一私有导出](../registry-platform/docs/export-pull-secret.md)。真实部署的地址/凭据和目标检查按该说明执行。

## ONLYOFFICE 上层生成调用

路由与四个业务 Secret 的生成范围已按调用方收敛，见[操作说明](../app-platform/knowledge-app/components/onlyoffice-docs-bff/docs/deployment-resources.md)。Ingress 只生成自己的路由和 Middleware；status/uninstall 不调用生成器；JWT 缺值不会自动随机生成。修改只完成静态核对，真实部署尚未验收。

## Document Converter 配置资源

Secret/ConfigMap 的 status/uninstall 不生成文件，两个本地生成器已加入清单；
父级按实际配置键扫描、隔离子配置并传播失败。范围及待办见[操作说明](../app-platform/knowledge-app/components/document-converter-backend/docs/deployment-resources.md)。
