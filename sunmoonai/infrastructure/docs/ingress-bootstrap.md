# 共用 Traefik 入口：3.7.13 / chart 41.6.0

日期：2026-09-27。状态：物料、代码、离线渲染和只打印演练已完成；本地运行时尚未部署，云端**未经实机验证**。不表示入口、业务路由或 Harbor 迁移验收完成。

## 决定与输入

所有者批准 Traefik 升级，并明确数据库及数据引擎保持既定版本；其他组件按维护和兼容性需要评估。Harbor 本次恢复仍为 2.13.2，部署方式从 Bitnami chart 改为宿主官方方式，不代表其应用版本已升级。

Traefik 3.5 系列已无安全维护，见[官方支持状态](https://doc.traefik.io/traefik/deprecation/releases/)；目标使用[chart 41.6.0 配套的 3.7.13](https://github.com/traefik/traefik-helm-chart/releases/tag/v41.6.0)。未因 Kubernetes 升级就假定所有平台组件必须升级。

输入真源：

- `ingress-platform/bootstrap/sources.lock.json`：获批版本、官方 chart URL、官方 HTTPS 索引提供的 SHA256。未宣称核过独立签名。
- `infrastructure/materials/ingress-images.lock.json`：官方 Docker Hub 多架构索引、amd64 manifest、config、归档摘要分别固定；不是用 Docker image ID 代替制品摘要。
- `ingress-resources.lock.json`：chart 归档、10 个 Proxy CRD、dev/prod 两份清单的大小与 SHA；主锁按 SHA 引用两份子锁，`bundle.py` 的 ingress 范围同时覆盖镜像、chart、清单。
- 唯一物料根：`~/packages-to-be-installed/releases/traefik-3.7.13-chart-41.6.0-linux-amd64/`。旧 3.5.2 镜像、旧 chart、原集群全部保留；验收结束再处理清理。

当前镜像为 `docker.io/library/traefik@sha256:3429c14149401de2ac82fc72ddc6a92642332b90deb3012301ff211b9d2d0f18`；归档 55,225,344 字节，6 个 OCI blob / 4 层本机完整校验通过。新物料存在不等于已经导入 KIND 节点。

## 同一实现、两种适配器

公共实现 `materials/ingress_resources.py`；云端 step13 经 cluster-step/control/node 调用，本地经 `materials/ingress_local.py` 调用。日常使用平台总入口；旧 `deploy-traefik.sh` 转发入口、其 Secret 总控/TLS 安装与每次重新签发脚本已从原路径删除，历史代码集中在 [legacy/cloud](../../../legacy/cloud/README.md)，拒绝运行，待云实机验证后退出。历史 ingress `.conf`/values 不再控制新版资源，资源来自锁定的 bootstrap values；云端启用/环境选择来自基础设施 `STEP13_ENABLED` / `STEP13_PROFILE`。

证书只由[统一证书流程](../../registry-platform/docs/certificates.md)签发/安装；普通部署不重新签发、不轮换 CA。
这次仅移动 Git 跟踪的历史源代码/配置/说明，**未移动或删除旧 CA、私钥、已生成证书/Secret、运行时文件**。
尚有独立的通用证书分发工具和手工 NAT 工具，不能把它们误当作新版安装步骤，其余调用方继续单独审阅。

```sh
# 默认只打印：无 SSH、集群 API、Helm 安装、服务操作。
CLUSTER=C1 bash sunmoonai/infrastructure/steps/step13_ingress_and_harbor.sh --dry-run
bash sunmoonai/ingress-platform/deploy-ingress-platform-all/deploy-ingress-platform-all.sh --cluster KIND --dry-run
```

云端 `--apply` / `--verify` 需完整闭包、已登记主机/集群身份、独立仓库 profile 及公开 CA。`--verify` 不修复集群资源，但远端公共控制代码、root 私有请求与审计记录仍会写入，不能称为整个主机零写。总控对 step13 显式传 `--apply`。C3 尚无本次集群适配器，不把空配置当支持。

本地实际调用必须显式传 `--kubectl`（绝对路径和锁定 SHA）、`--kubeconfig`（0600）、`--expected-uid`、`--ca-file`、`--ca-sha256`；可选 `--profile dev|prod`、`--timeout 1..600`、`--root`。这些值必须取正式建群/仓库配置的实际记录，不抄旧集群值。主锁目前仍 `closure_complete=false`，实际操作会在接触 API/SSH 前停止，不手工抬门禁绕过未完成接线。

执行顺序：

1. 物料 SHA、显式集群 UID、版本；云端额外核节点 machine-id/IP 集合，每次 API 前重查 UID/CA。
2. 目标 namespace 必须 Active 且归属匹配；读取受管 TLS Secret，只在内存中核证书链、SAN、有效期、私钥匹配与固定 CA。日志不含证书私钥/Secret 正文。
3. 所有 NodePort、默认 IngressClass、已有资源的归属与声明字段预检。已有不同资源拒绝覆盖/接管，不卸载 Helm，不改其他默认入口。
4. 只创建缺失 CRD，等待 Established，再检查 custom resources；只创建缺失的 SA/RBAC/Service/Deployment/IngressClass/TLSStore/Middleware。
5. 检查 Deployment observedGeneration 和完整副本 Ready/Available；最后复核声明资源。`--verify` 不补建；失败保留诊断现场。

这是一条新集群安装路径，不是原地升级既有 CRD/release 的工具。旧集群入口不会被它隐式接管。镜像用摘要及 `Never`，依赖先导入全部可调度节点；云端由 step11 导入，本地导入接线仍待完成。

## 配置与兼容性

根据[官方迁移说明](https://doc.traefik.io/traefik/v3.7/migrate/v3/)及固定 chart 的 Changelog 核对：

- chart 41 日志从 `logs.general/access` 改为 `log/accessLog`；HTTP 参数按新 `ports.*.http` 结构。保持路径规范化，不为兼容而关闭安全修复。
- 使用新版 chart 自带的 10 个 `traefik.io` CRD；不安装 Hub 或 Gateway API CRD，也不启用对应 provider。RBAC 包含 EndpointSlice。
- 开启 `core.strictTLSOptions`，TLS 配置冲突时拒绝路由；`defaultTLSResourcesNamespace` 固定到所选入口 namespace，跨 provider 引用仅允许入口 namespace。普通 IngressRoute 的同 namespace 中间件仍可使用。
- chart 中空 `crossProviderNamespaces` 不会输出参数；因此这里明确输出入口 namespace，不将空列表误报为“全部禁止”。旧 Harbor 的跨 namespace 中间件注解属于集群内历史部署；独立 Harbor 不经这条应用路由。实际业务引用仍需验收。
- dev 一个副本、prod 三个副本；同一集群只选一个 profile。统一 NodePort：30080、30443、30444、30445、30446。宿主 SNI 代理与 KIND 宿主 19443 映射由后续入口模块管理；本脚本不改 iptables、不启用 hostNetwork。
- 不挂 PVC、不用 ACME；证书由 step12/对应本地适配器提供。非 root、只读根文件系统、去掉 capabilities；临时数据用 emptyDir。
- 生产三副本还需结合节点容量/分散调度与维护窗口验收，不能仅据副本数宣称高可用。当前 chart 的集群级 Secret 读取权限仍需在生产准入时结合受管 namespace/RBAC 策略评估。

## 可重复准备

下载时使用已授权东京主机；只传公开 `sources.lock.json` 和 `prepare_public.py` / `prepare_images.py`。固定新目录，不传项目私有配置或源码包。

```sh
# 在公开下载主机，以实际绝对路径替换 SOURCE_LOCK、ARTIFACT_ROOT；默认只打印。
python3 prepare_public.py --manifest "$SOURCE_LOCK" --root "$ARTIFACT_ROOT"
python3 prepare_images.py --profile traefik --manifest "$SOURCE_LOCK" --root "$ARTIFACT_ROOT"
# 经授权准备时给上述两条各加 --apply；不启动容器或安装集群。
```

官方 chart SHA 来自发布索引；镜像首次解析后先冻结 registry 摘要再拉取。Docker 可能把 `docker.io/library/traefik@digest` 返回为 `traefik@digest`，下载器只做规范等价化，仍逐项核对完整摘要、架构和配置。断点复用本机已有且身份一致的镜像；新拉取保留 8 GiB 余量，其他导出操作保留 6 GiB，不自动清理下载主机。

回传用严格 known_hosts 的 rsync `--partial --append-verify`，在唯一物料根按锁重算完整 SHA，再用 `image_import.inspect_archive` 核全部 OCI blob，不能只相信 rsync 成功。

渲染需要准备机上的 Helm 3.19.0（本机已有 build `g3d8990f`，二进制 SHA 写入输出锁）及 PyYAML。它们是准备工具，节点部署不依赖 Helm/PyYAML；未将准备工具本身的供应闭包宣称完成。命令：

```sh
python3 -B sunmoonai/ingress-platform/bootstrap/render.py \
  --helm /home/zymun/.local/bin/helm --output /tmp/ingress-new-render --write
python3 -B sunmoonai/infrastructure/materials/bundle.py verify --scope ingress
```

脚本只从固定 chart 归档离线渲染，临时隔离 Helm 配置/插件，拒绝逃逸路径和符号链接，校验资源种类和镜像；生成目录不覆盖不同内容。审核输出后更新 resource 子锁、主锁 SHA，并把清单发布到对应批次，代码和锁一起提交。

## 证据与后续验收

`sunmoonai/scripts/results/luna-ingress-bootstrap.20260927.json`：133 个物料共 1,113,542,643 字节全 SHA，10 CRD + 两套各8资源离线生成；C1/C2 共26个步骤计划和6个平台/兼容入口计划通过。Python AST、4 个修改 Shell 的 bash -n/ShellCheck、主配置及历史兼容脚本 bash -n 通过。没有新增/运行测试套件，没有实际云部署。

首次本地/上云仍须检查：镜像导入、证书实际握手、HTTP/HTTPS/重定向、WebSocket/长连接、中文/编码路径、Casdoor 回调、中间件、三个数据库 TCP 入口、Pod 重建及入口重启。云端另核主机端口、防火墙和负载均衡配置；不复用 WSL 的代理配置。新正式 KIND、宿主 Harbor/SNI、CI/CD 与备份恢复闭环仍待完成。最终清理必须执行且放在迁移验收后，本单元未释放空间。
