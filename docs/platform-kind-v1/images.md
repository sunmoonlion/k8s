# 第一期镜像版本选定表

核对日期：2026-10-01。适用工作区：`platform-kind-v1`。本表确定新部署的版本目标，不表示已完成镜像下载、摘要锁定或应用兼容性验收。

所有者最新决定：没有需要迁移的业务数据，旧 Harbor 镜像也不再作为新部署输入；选择新的稳定版本，必要时适配业务代码并重新构建。此前保留 Harbor 2.13.2、PG 17.6、Redis 8.2.1 的约束取消。版本选择不触发现场删除或服务切换。

## 选择规则

采用正式发行，优先当前受支持的最新稳定版本；有配套约束时写明例外。排除 RC、Beta、nightly、开发版。正式发布使用 `repo@sha256:…`，不能只固定 tag，也不能凭发行号编造摘要。第一期目标架构为 `linux/amd64`。

下列是选定版本，不再列多个候选。表中地址用于物料准备；没有经过 Registry manifest 核验的引用不能当作已备齐物料。

## 集群与交付

| 组件 | 选定版本 / 镜像 | 配套说明与官方依据 |
| --- | --- | --- |
| Kubernetes | **1.36.5**；控制面、kube-proxy、kubectl、kubeadm、kubelet 同版 | [1.36 当前补丁](https://kubernetes.io/releases/1.36/)；选择 Calico 官方测试范围内的最新 minor 及其最新补丁 |
| KIND 工具 | **0.33.0** | [官方发行](https://github.com/kubernetes-sigs/kind/releases/tag/v0.33.0)；这不是容器镜像 |
| KIND 节点 | **Kubernetes 1.36.5，使用 KIND 0.33.0 官方构建命令生成** | 该 KIND 发行只列出 1.36.4 预制镜像，不能把它写成 1.36.5；自建产物使用本项目仓库名，不冒充官方发布 |
| Calico | **3.32.2**；`quay.io/calico/node:v3.32.2`、`cni:v3.32.2`、`kube-controllers:v3.32.2` | 使用同 tag 的部署清单；[发行](https://github.com/projectcalico/calico/releases/tag/v3.32.2)、[测试范围为 1.34–1.36](https://docs.tigera.io/calico/latest/getting-started/kubernetes/requirements) |
| Traefik | **3.7.13**；`docker.io/library/traefik:v3.7.13` | [官方镜像清单](https://raw.githubusercontent.com/docker-library/official-images/master/library/traefik) |
| 本地卷 provisioner | **0.0.37**；`docker.io/rancher/local-path-provisioner:v0.0.37` | [发行](https://github.com/rancher/local-path-provisioner/releases/tag/v0.0.37)；静态数据卷和宿主挂载另由站点声明控制 |
| 卷辅助镜像 | **1.37.0-glibc**；`docker.io/library/busybox:1.37.0-glibc` | 上游 provisioner 默认没有精确 tag；显式固定。官方镜像清单将 1.38.0 同时标记为 unstable，本次不选；[镜像清单](https://raw.githubusercontent.com/docker-library/official-images/master/library/busybox) |
| Flux | **2.9.5**，控制器整套配套 | [发行组件表](https://github.com/fluxcd/flux2/releases/tag/v2.9.5)、[1.36 兼容声明](https://github.com/fluxcd/flux2/releases/tag/v2.9.0) |
| 宿主 TLS 直通代理 | **HAProxy 3.4.6 LTS**；`docker.io/library/haproxy:3.4.6-trixie` | [官方镜像清单](https://raw.githubusercontent.com/docker-library/official-images/master/library/haproxy)；独立于集群 Traefik |

Kubernetes 1.37 已发行，但本次所选 Calico 官方测试矩阵没有覆盖它。因此选 1.36.5；不能称它为 Kubernetes 全部发行中的最新 minor，也不能因旧物料已有 1.36.4 就继续使用旧补丁。

节点镜像准备采用 KIND 原生命令 `kind build node-image --type release v1.36.5 --image sunmoon-kind-node:v1.36.5-kind0.33.0`。实施时还须固定 KIND base 镜像摘要、记录构建输入和最终镜像摘要，验证节点版本与重启；本轮未构建。[官方构建方式](https://kind.sigs.k8s.io/docs/user/quick-start/)

KIND 节点内的 containerd、runc 跟随固定 KIND base，不在节点启动后另装另一套运行时。CoreDNS、etcd、pause 跟随 kubeadm 1.36.5 的配套清单，物料阶段展开为逐镜像摘要。不能将这些子组件各自的最新大版混入 kubeadm 组合。云端运行时的精确安装包是下一阶段工具锁，不是已选定或已验收的云部署。

Flux 第一期开启四个镜像：`ghcr.io/fluxcd/source-controller:v1.9.5`、`ghcr.io/fluxcd/kustomize-controller:v1.9.5`、`ghcr.io/fluxcd/helm-controller:v1.6.4`、`ghcr.io/fluxcd/notification-controller:v1.9.4`。不启用自动镜像版本晋级。Flux 属于当前架构建议，本表选版不替代整体架构确认。

## Harbor 与业务平台

| 组件 | 选定版本 / 上游镜像 | 官方依据 |
| --- | --- | --- |
| Harbor | **2.15.2**，整套官方离线安装包 | [发行](https://github.com/goharbor/harbor/releases/tag/v2.15.2) |
| 业务 PostgreSQL | **18.6**；`docker.io/library/postgres:18.6-trixie` | [官方镜像清单](https://raw.githubusercontent.com/docker-library/official-images/master/library/postgres)；19beta4 不纳入 |
| 业务 Redis / Nodebull Redis | **8.10.2**；`docker.io/library/redis:8.10.2-trixie` | [官方镜像清单](https://raw.githubusercontent.com/docker-library/official-images/master/library/redis)；不同用途隔离身份和实例配置 |
| RabbitMQ | **4.3.6**；`docker.io/library/rabbitmq:4.3.6-management` | [官方镜像清单](https://raw.githubusercontent.com/docker-library/official-images/master/library/rabbitmq) |
| Casdoor | **4.12.0**；镜像目标 `docker.io/casbin/casdoor:4.12.0` | [正式发行](https://github.com/casdoor/casdoor/releases/tag/v4.12.0)；linux/amd64 manifest 已核实 |
| Elasticsearch | **9.5.4**；`docker.elastic.co/elasticsearch/elasticsearch:9.5.4` | [发行](https://github.com/elastic/elasticsearch/releases/tag/v9.5.4) |
| Kibana | **9.5.4**；`docker.elastic.co/kibana/kibana:9.5.4` | [发行](https://github.com/elastic/kibana/releases/tag/v9.5.4) |
| Logstash | **9.5.4**；`docker.elastic.co/logstash/logstash:9.5.4` | [发行](https://github.com/elastic/logstash/releases/tag/v9.5.4) |
| 对象存储 MinIO AIStor | **RELEASE.2026-09-19T17-05-25Z**；`quay.io/minio/aistor/minio:RELEASE.2026-09-19T17-05-25Z` | [官方发行与拉取地址](https://dl.min.io/releases) |
| MongoDB（可选） | **8.3.11**；`docker.io/library/mongo:8.3.11-noble` | [官方镜像清单](https://raw.githubusercontent.com/docker-library/official-images/master/library/mongo)；见下方版本例外 |
| Neo4j（可选） | **2026.09.0**；`docker.io/library/neo4j:2026.09.0-community-trixie` | [官方镜像清单](https://raw.githubusercontent.com/docker-library/official-images/master/library/neo4j) |

Harbor 新装使用安装包自带的 `goharbor` 组件、专用数据库、Valkey 和 Trivy adapter；不把业务 PostgreSQL/Redis 镜像塞进 Harbor 官方组合。主组件使用 v2.15.2；辅助镜像逐项以该安装包输出为准并锁摘要。官方模板已使用 `valkey-photon`，不能继续沿用旧 `redis-photon` 假设。[固定 Compose 模板](https://raw.githubusercontent.com/goharbor/harbor/v2.15.2/make/photon/prepare/templates/docker_compose/docker-compose.yml.jinja)

MongoDB 9.0 已于 9 月 29 日正式发布；本次查到的 Docker Official Images 清单仍为 8.3.11，厂商 9.0 正式镜像的 manifest 未核实成功。因此当前可准备的镜像选 8.3.11，明确不是 MongoDB 产品最新大版；不得拿 9.0 RC 镜像代替。若物料阶段核实 9.0 正式镜像及驱动支持，则单独更新此项选择。[9.0 官方公告](https://www.mongodb.com/products/updates/mongodb-9-0-is-now-available/)

AIStor 保持现有产品选择，第一期采用单节点部署，使用合法许可。Free 许可仅覆盖单节点形态；云上多节点不能自动照搬免费许可假设。本轮不申请许可、不购买服务。[官方 Kubernetes 部署与许可条件](https://docs.min.io/aistor/installation/kubernetes/install/deploy-aistor-on-kubernetes/)

## 运维、知识增强与应用构建

| 组件 | 选定镜像 | 依据或适配边界 |
| --- | --- | --- |
| pgAdmin | `docker.io/dpage/pgadmin4:9.18` | [9.18 容器文档](https://www.pgadmin.org/docs/pgadmin4/9.18/container_deployment.html) |
| RedisInsight | `docker.io/redis/redisinsight:3.8.0` | [正式发行](https://github.com/redis/RedisInsight/releases/tag/3.8.0) |
| Flower | `docker.io/mher/flower:2.1.0` | [正式发行](https://github.com/mher/flower/releases/tag/v2.1.0) |
| RAGFlow | `docker.io/infiniflow/ragflow:v0.27.2` | [正式发行](https://github.com/infiniflow/ragflow/releases/tag/v0.27.2)；1.0.0-rc1 是预览版，排除 |
| RAGFlow 文档引擎 | `docker.io/infiniflow/infinity:v0.7.3-x64-v3` | 选择上游提供的 Infinity profile；[固定配置](https://raw.githubusercontent.com/infiniflow/ragflow/v0.27.2/docker/docker-compose-base.yml)；宿主 CPU 指令集须核实 |
| RAGFlow 专用缓存 | `docker.io/valkey/valkey:8.1.10` | 将上游浮动 `valkey:8` 收敛为 8 系列补丁；[官方发行](https://valkey.io/download/releases/) |
| ONLYOFFICE | `docker.io/onlyoffice/documentserver:9.4.0` | [官方镜像](https://hub.docker.com/r/onlyoffice/documentserver/tags) |
| 自有后端构建基础 | `docker.io/library/python:3.13.15-slim-trixie` | [官方镜像清单](https://raw.githubusercontent.com/docker-library/official-images/master/library/python)；所有者指定 3.13 系列，采用 3.13.15；现有依赖锁优先保留 |
| 自有前端构建基础 | `docker.io/library/node:24.21.0-trixie`；运行层 `24.21.0-trixie-slim` | [官方镜像清单](https://raw.githubusercontent.com/docker-library/official-images/master/library/node)；采用当前 LTS，26 Current 不作为生产默认 |

RAGFlow 0.27.2 上游默认 Elasticsearch 仍为 8.11.3，不能声称直接兼容本平台 ES 9.5.4。本次选择它已提供的 Infinity 接口；元数据库选择上游支持的 PostgreSQL 接口，目标使用独立逻辑库的 PG 18.6；S3 接口使用平台 AIStor 独立身份和桶。这是本项目的集成选择，尚无整套实测结论。不得把官方默认组合的验证结果挪作该组合的通过证明。[固定环境配置及数据库类型](https://raw.githubusercontent.com/infiniflow/ragflow/v0.27.2/docker/.env)

旧 mongo-express 官方镜像条目因基础系统/Node EOL 已被注释，新发行又含 RC，第一期不纳入默认管理面，不能把旧 latest 称为新稳定生产镜像。[官方镜像维护清单](https://raw.githubusercontent.com/docker-library/official-images/master/library/mongo-express)

自有应用、sandbox、文档转换服务重新构建，以源码提交和构建摘要命名；它们没有可从第三方挑选的“最新生产镜像”。Python/Node 的选择仅是构建目标，现有依赖锁能否直接安装尚未验证。Jenkins、Argo CD 不作为本架构新增前置依赖。

## 从选定版本到可部署发布

后续物料工作必须完成：

1. 对每个目标查询 Registry manifest，确认平台、完整 digest 和发布方；缺失即停止，不能默默换 tag。KIND 自建产物另记构建来源。
2. 从固定 Harbor 安装包、kubeadm 输出、Calico 清单、Flux 发行和最终 chart 展开所有辅助镜像；记录 chart 版本与 chart 摘要，禁止隐藏浮动镜像。
3. 分开记录上游引用、Harbor 引用、OCI index digest、amd64 manifest digest、离线归档 SHA256；明确各类摘要不能互相代替。
4. 发布前完成依赖配置、认证、真实业务读写与重建恢复验收。新版本可能要求新 chart/初始化参数，不能仅替换旧 Bitnami chart 的 repository。

当前已完成版本选择和上述官方资料核对。未完成全部 Registry 摘要、工具/安装包锁、chart 锁、离线物料及实机集成。因此本文不是完整可执行 BOM，也不宣称“整套已达到生产验收标准”。

2026-10-01 实际 Registry 核验：43 个上游目标已全部确认 linux/amd64 manifest 摘要并复算原始 manifest SHA256，`make check-images` 返回 0。此前 4 项匿名限流缺口已关闭；Calico 三项统一采用[官方清单](https://raw.githubusercontent.com/projectcalico/calico/v3.32.2/manifests/calico.yaml)中的 `quay.io/calico/`，Casdoor 的真实 tag 为 `4.12.0`（不带 v）。记录见 `platform/artifacts/upstream-images.lock.json`，镜像层尚未全部下载，`offline_ready=false`。

宿主引导文件另锁于 `platform/artifacts/files.lock.json`：KIND 0.33.0、kubectl 1.36.5、Compose 5.5.1、SOPS 3.13.3、age 1.3.2、Flux 2.9.5、Harbor 2.15.2 官方离线安装包、Calico 3.32.2 清单。安装包摘要采用官方发布资产 SHA256，kubectl 使用官方校验文件，Calico 清单由固定版本源文件计算。选定 Compose 版本尚需与 Harbor 的实际生成配置联合验收；版本检查允许并不等于运行兼容已通过。[Compose 发行](https://github.com/docker/compose/releases/tag/v5.5.1)、[SOPS 发行](https://github.com/getsops/sops/releases/tag/v3.13.3)、[age 发行](https://github.com/FiloSottile/age/releases/tag/v1.3.2)。
