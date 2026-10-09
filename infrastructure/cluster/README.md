# KIND集群维护

共享身份来自[site](../environments/kind/site.yaml)，参数在[config](config.yaml)，工具和节点身份取[artifacts锁](../artifacts/README.md)。当前正式开发环境sunmoon-kind；原始kind是受保护旧环境，不由此入口接管。

## 配置和存储
当前值以[config.yaml](config.yaml)为准，手册维护字段职责，不再复制一套默认值。

| 字段 | 类型 | 维护条件 |
|---|---|---|
| `cluster_enabled` | 开关 | 部署/渲染准入；不代替停止、卸载或删除数据。 |
| `cluster_api_port` | 整数 | 与客户端、TLS、入口/Service及网络策略联动；既有节点端口映射不能热改。 |
| `cluster_ingress_port` | 整数 | 与客户端、TLS、入口/Service及网络策略联动；既有节点端口映射不能热改。 |
| `cluster_pod_subnet` | 文本/表达式 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `cluster_service_subnet` | 文本/表达式 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `cluster_data_root` | 文本/表达式 | 目录责任；已有输入/数据需完整恢复和路径守卫，不能换空目录重建身份。 |
| `cluster_kubeconfig` | 文本/表达式 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `cluster_operator` | 文本/表达式 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `cluster_create_budget_bytes` | 整数 | 操作预算/限时；调整须匹配真实峰值及当前容量检查。 |

一个控制面、两个worker，每个节点都挂自己的宿主目录：`cluster_data_root/cluster_name/<节点>/static`→节点`/data/kind-local-storage`；`dynamic`→节点动态存储目录；公共CA目录只读挂载。完整对应以[kind.yaml.j2](kind.yaml.j2)为准。旧宿主`/data/kind-local-storage`不覆盖挂载。

API loopback27443，控制面的NodePort30443映射为宿主loopback29443，公共域名另由[entry](../entry/README.md)分流。节点端口、extraMounts、网段属于建群参数，修改文本不会改变既有节点，必须有明确重建计划。

## 建群和检查

前提：数据盘已可见；工具/节点归档与Calico已核验；API/入口端口空闲；Harbor/入口及CA已就绪。按[物料](../artifacts/README.md)准备后：

```sh
make -C infrastructure cluster-plan
make -C infrastructure cluster-deploy
make -C infrastructure cluster-status
make -C infrastructure cluster-pull-check
```

`cluster-status`还会检查三个KIND节点的`/etc/resolv.conf`搜索域是否合法，并从一个就绪的应用API Pod连续解析PostgreSQL服务FQDN；任一次超过200ms或宿主搜索域含CIDR/路径都会失败，并提示检查宿主DNS后缀与WSL DNS隧道。长期运行的应用 Deployment（API、Worker、Scheduler、Runner、Web、Admin）和 Casdoor 主服务将`ndots`设为2，减少短服务名解析时把宿主搜索域带入查询的影响；初始化及迁移 Job 保持 Kubernetes 默认值，避免为不可变 Job 变更而重复运行数据库和身份初始化。短服务名仍使用 Kubernetes 默认搜索域解析。此配置需随模板候选晋级后才会进入集群。

plan检查现有环境并显示计划；deploy只创建/协调本集群，节点不存在时才创建。receipt在`cluster_data_root/cluster_name/bootstrap/identity.json`，保存节点容器身份及kube-system UID，同目录kind.yaml保存建群参数；已有对象缺receipt、节点或UID漂移时拒绝接管。create中断时保留现场，不能删除receipt绕过守卫。

控制面基础镜像内置于节点镜像；Calico从归档导入三个节点，再原生apply对应配置。建群不依赖现场公网拉镜像；平台和应用镜像随后从Harbor取得。节点镜像生成与本机归档身份见[node.yaml](node.yaml)及[build-node.yaml](build-node.yaml)。

## 日常kubectl

从k8s根目录，独立工具只作用指定kubeconfig：

```sh
export KUBECONFIG="$HOME/.kube/sunmoon-kind.config"
infrastructure/.tools/bin/kubectl --context=kind-sunmoon-kind get nodes
infrastructure/.tools/bin/kubectl --context=kind-sunmoon-kind get pods -A
infrastructure/.tools/bin/kubectl --context=kind-sunmoon-kind get pv,pvc -A
```

配置可修改路径，但当前代码有明确sunmoon-kind身份守卫，不承诺任意名称可直接复用。就绪检查包含节点Ready与系统工作负载rollout；pull-check还做三节点证书/认证真实拉取、运行imageID和DNS，避免已有缓存伪造“仓库可达”。详细身份核验实现见[pull-check.yaml](pull-check.yaml)。

## 重启、重建和失败恢复

本模块没有cluster-start/stop/delete统一target，也没有任意删除旧集群后自动认领同名新UID的流程。整套启停、开机顺序、重启DNS/IP更新和Harbor跨删群持久化验收属于[未完成项](../../docs/platform-kind-v1/verification.md#未完成项)。

不得为了清运行状态直接删节点或Docker卷。重建先明确数据处理/备份、receipt新旧身份、节点存储映射、Flux/SOPS恢复、Harbor完整摘要及新节点拉取验收；目录挂载正确不等于这些已验证。失败检查保留节点与证据，按[宿主诊断](../host/troubleshooting.md)和[Flux诊断](../flux/README.md#故障与退回)定位。
