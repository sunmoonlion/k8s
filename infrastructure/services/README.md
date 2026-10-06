# 平台服务部署与维护

本模块是所有启用平台组件的原生Make→Ansible→Flux/SOPS编排。组件参数、模板、生成声明、身份准备与说明在[各责任组件](../../gitops/components/README.md)；阶段与依赖在各组件`stage.yaml`（见[components](../components/README.md)）；[layout.yaml](layout.yaml)只剩命名空间与保留卷清单，不再集中维护重复端口/账号表。

## 输入与准备
当前值以[config.yaml](config.yaml)为准，手册维护字段职责，不再复制一套默认值。

| 字段 | 类型 | 维护条件 |
|---|---|---|
| `services_enabled` | 开关 | 部署/渲染准入；不代替停止、卸载或删除数据。 |
| `services_config_dir` | 文本/表达式 | 目录责任；已有输入/数据需完整恢复和路径守卫，不能换空目录重建身份。 |
| `services_backup_dir` | 文本/表达式 | 目录责任；已有输入/数据需完整恢复和路径守卫，不能换空目录重建身份。 |
| `service_image_ids` | 列表 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `service_material_timeout_seconds` | 整数 | 操作预算/限时；调整须匹配真实峰值及当前容量检查。 |

平台基础输入为`services_config_dir/credentials.yaml`，字段在`service_credentials`下。PG/Redis/Rabbit/Casdoor口令与cookie由此提供；AIStor、ELK、Neo4j、MongoDB、RAGFlow等另有组件独立输入/TLS。主目录root0700、文件0600，独立副本在`services_backup_dir`，仅同盘恢复保护。各组件README明确真实文件与账号归属。

```sh
make -C infrastructure services-credentials
make -C infrastructure services-plan
make -C infrastructure services-materials
make -C infrastructure services-verify-materials
make -C infrastructure services-publish
make -C infrastructure services-tools
make -C infrastructure services-chart
make -C infrastructure services-render
```

依赖Harbor/入口、拥有的KIND、Flux/SOPS与完整物料。credentials保留已有输入、缺主时恢复备份；已有声明而两份均丢失则拒绝生成。platform口令和业务口令分开。轮换需服务器/客户端/Secret/备份同步，不能只编辑输入。

render会核唯一kube-system UID，准备静态目录/模型、身份备份、证书和`.build/services`候选；ELK prepare还设置宿主sysctl。它不直接部署Kubernetes，但有宿主/文件副作用。目录属主/链接/输入漂移时拒绝，不递归改已有数据。

## 修改配置并发布

```sh
make -C infrastructure services-render
make -C infrastructure services-stage
```

审查`.build/services`公开对象与秘密语义；stage拷贝已生成候选至各组件，并经`topology-stage`更新clusters/kind/stages.yaml。提交工作树后按[Flux发布与晋级](../flux/README.md#发布与显式晋级)生成、审核并晋级同一产物。stage不代表声明已生效。

服务开关控制新声明资源和阶段；`prune:false`保留已有对象，不自动停服/卸载。静态PV/PVC、初始化代次、目录/账号变更另看组件限制；不要用增加Job代次重置已有数据。

## 已晋级环境的一键部署

```sh
make -C infrastructure services-bootstrap
```

原生链串联凭据检查→完整镜像校验/发布→必要RAGFlow派生build/publish→工具/mc/chart→render→validate-release→Flux源apply→services-check。配置、候选公开对象及解密后的秘密须与已提交晋级版本一致；不自动部署未批准修改。Git对象差异核对仅排除组件README说明，配置、模板、镜像锁及部署文件仍严格匹配；整个GitOps工作区仍须已提交。此target覆盖平台，不等于宿主到所有应用全链路部署。

## 实际检查与副作用

```sh
make -C infrastructure services-check
```

检查UID、当前Flux代次Ready、实际imageID、启用Retain卷绑定/目录，再做真实PG事务、RedisTTL唯一键、Rabbit管理API消息、CasdoorTLS登录；临时网络Pod核app→PG标签允许/拒绝。启用组件还执行S3版本/字节、中文向量、ELK写入/读取/真实采集、图事务、Mongo事务和RAGFlow解析检索。

这些检查会创建本轮随机Pod/队列/对象/图节点/集合/dataset，按精确身份清理；失败清理保留信息而不扩大删除。业务AMQP和跨应用HTTP由[applications](../applications/README.md)验，不把管理API成功代替应用链。ELK data-view由声明Job初始化，check只读确认，不修复。

## 失败、退回和数据

声明差异先修配置/源码并重新审阅发布；字段冲突不force接管。Job失败保留代次与错误，查其前置依赖/schema/身份；已有同名账号/卷不符须显式处理。Neo4j限定rollout恢复见[组件说明](../../gitops/components/data-platform/neo4j/README.md)。

退回按[Flux](../flux/README.md#故障与退回)恢复原固定源并做真实检查；schema/身份/持久数据需匹配备份，不自动随Git回滚。业务备份/轮换、统一停用、WSL/删群持久化和长期空间管理见[未完成项](../../docs/platform-kind-v1/verification.md#未完成项)。

## Kibana浏览器访问

浏览器配置、身份准备、声明和验收集中在[同一组件](../../gitops/components/data-platform/elk/kibana/ui/README.md)，共享services-render/stage/bootstrap/check原生链。启用时services-check从新集群入口验证实际TLS、登录会话、权限和退出；主机30443切换后运行`make -C infrastructure services-check-public`，同一playbook引用entry_port验证真实入口。Kibana公开入口的切换仍单独确认，不能把29443后端通过写成30443已通过。
