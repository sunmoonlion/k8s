# 本地 TLS 直通入口

一套平台与应用部署代码，两种建集群方式。**此代理是 WSL 入口适配器，云端独立 Harbor 主机不安装它。**

## 已实现和实测的范围

续做：增加了38443的 `transition-candidate`，默认后端直达已固定身份的旧worker，已实际验收后停止。原28443候选继续保留。正式切换的影响、阶段和回退边界统一见[入口维护步骤](entry-maintenance.md)，旧API/80/30444–30446停服仍待具体窗口批准。

2026-09-27，候选 `sunmoon-sni-candidate-20260927` 在 `127.0.0.1:28443` 通过验收后停止保留，新 Harbor 也停止。旧 Harbor 30443 健康，旧控制面和两工作节点一直运行。没有正式切换，正式建群、自动启动、认证推拉、长连接/大层传输仍待后续验收。

| 项目 | 候选实际配置 | 正式配置预览，尚未应用 |
| --- | --- | --- |
| 监听 | 127.0.0.1:28443 | 0.0.0.0:30443，与旧 IPv4 监听范围相同 |
| 精确 Harbor SNI | 127.0.0.1:18443 | 127.0.0.1:18443 |
| 其余/无 SNI | 127.0.0.1:30443，旧入口 | 127.0.0.1:19443，新 KIND |
| 数据 | 只挂公开 nginx.conf | 同样不挂数据库、registry 或证书私钥 |

正式 KIND 必须把 NodePort30443 映到宿主 **127.0.0.1:19443**。代理不能再转自己的监听地址。正式profile现在允许prepare/create/check/stop，创建结果必须保持停止；公开30443的start仍在CLI与Proxy.start两层拒绝，等待单独维护执行器。不能改成candidate绕过，因为配置校验绑定模式、监听及两个后端。

原始 TLS 字节直通，认证地址保持 `https://harbor.sunmoonai.com:30443/service/token`。不解析 HTTP、不重写 Host、不解密、不注入 PROXY protocol。后端看到代理连接的源地址；本实现不保留客户端源 IP，今后审计不能把后端 peer IP 当原始用户地址。

依据：[NGINX ssl_preread](https://nginx.org/en/docs/stream/ngx_stream_ssl_preread_module.html)；[stream proxy](https://nginx.org/en/docs/stream/ngx_stream_proxy_module.html)。固定连接超时5秒、ClientHello等待10秒、传输空闲超时3600秒。3600秒是两次读写间的空闲限制，不是镜像整体上传时限；尚未以大层上传/WebSocket做验收。关闭下一上游重试，后端不可用直接失败，不回退到另一份 Harbor。

## 离线物料

外部代理独立固定 **NGINX 1.30.5-alpine，linux/amd64**，不替换 Harbor 自带的 nginx-photon/数据库。版本依据为[官方下载页](https://nginx.org/en/download.html)及[安全公告](https://nginx.org/en/security_advisories.html)，镜像发布源码固定为 `nginx/docker-nginx` 的 `a16f1329e13e7273c4103f75d863ca625b75109e`。这是版本/来源核对，不等于完整漏洞扫描或零漏洞证明。

锁为 [sni-image.lock.json](../sni-image.lock.json)，物料为：

```text
~/packages-to-be-installed/releases/nginx-sni-1.30.5-linux-amd64/nginx-linux-amd64.tar
26,112,000 bytes
sha256:cca17bf6af939d0ec69bfe92782e8e392cf50ae19cd2d1902fbed36aa028768d
amd64 manifest: sha256:8f84ed99befc3891b8f329c5c202785278a2cfb7c25107d57fb2a134a3117433
```

本次东京只有7,945,834,496字节余量，未执行需要8GiB的Docker pull。`prepare_sni.py`经匿名只读令牌与HTTPS直接下载固定index→amd64 manifest→config/8层，不解包或写Docker存储；该方法要求6GiB余量、压缩内容不超过512MiB。已有Docker pull门槛没有更改。令牌只在内存/curl stdin，不进命令行、日志或落盘；跨域重定向不携带Authorization。最多两次重试，连接/单次/进程均有上限，失败半文件留存；完整文件每次复核SHA。

本次公开脚本/缓存位于东京 `/home/zym/sunmoon-nginx-sni-20260927-v1/`。只传公开脚本，不传项目凭据或私有配置。回传用严格SSH和 `rsync --partial --append-verify`。本地再次核归档SHA及10个必要OCI内容（manifest、config、8层）；归档额外保留上游index作为来源证据。没有验证发行方独立签名，来源保证为官方HTTPS与锁定内容摘要。

## 操作

以下从k8s仓根执行。所有生命周期动作默认只打印；`render`只输出公开配置。需要实际执行时在已授权范围内加`--apply`。

```sh
python3 -B sunmoonai/registry-platform/prepare_sni.py --root /tmp/sni-material-plan
python3 -B sunmoonai/registry-platform/sni_proxy.py render --config sunmoonai/registry-platform/config/sni-local-candidate.json
python3 -B sunmoonai/registry-platform/sni_proxy.py render --config sunmoonai/registry-platform/config/sni-local-formal.preview.json

sudo -n python3 -B sunmoonai/registry-platform/sni_proxy.py prepare --config /home/zymun/worktrees/luna/k8s/sunmoonai/registry-platform/config/sni-local-candidate.json --apply
sudo -n python3 -B sunmoonai/registry-platform/sni_proxy.py create --config /home/zymun/worktrees/luna/k8s/sunmoonai/registry-platform/config/sni-local-candidate.json --apply
sudo -n python3 -B sunmoonai/registry-platform/sni_verify.py --config /home/zymun/worktrees/luna/k8s/sunmoonai/registry-platform/config/sni-local-candidate.json --harbor-config /home/zymun/worktrees/luna/k8s/sunmoonai/registry-platform/config/harbor-main-local.json --apply
sudo -n python3 -B sunmoonai/registry-platform/sni_proxy.py check --config /home/zymun/worktrees/luna/k8s/sunmoonai/registry-platform/config/sni-local-candidate.json --apply
```

`prepare`检查独立盘UUID/PID1/Docker可见性，只在新受管目录写入配置、核已准入归档后离线load。`create`只创建停止的代理。`start`要求精确配置/镜像/容器ID/标签/挂载/安全设置一致、候选端口空闲，启动后运行`nginx -t`。`stop`仅停止该ID，保留容器、网络与文件；磁盘余量低不阻止stop。

实际代理为host网络容器，UID/GID101、只读rootfs、丢弃所有capability、no-new-privileges、256MiB内存、128进程上限、两个tmpfs。日志只含上游、字节数、状态、耗时，不记录SNI、URL或凭据；Docker日志限制3×10MiB。restart=no；重启WSL/Docker后不会自动启用新入口，自启动将在挂盘门禁/正式生命周期中接通。

`sni_verify`先要求新代理和新Harbor停止；旧Harbor健康才开始。启动新只读Harbor和候选，严格CA/主机名验证，直连/经代理证书DER摘要一致；确认v2返回401及认证realm保持原30443。随后核六种真实ClientHello的上游日志：Harbor大小写走18443，普通/未知/伪装后缀/无SNI走旧30443。后四类只是路由观察，不声称后端TLS/应用验收通过。无SNI仅生成ClientHello时无主机名可校验，仍保留CERT_REQUIRED；正式Harbor握手始终严格校验。

无论验收成败，finally尝试停止代理与新Harbor；退出后复核旧Harbor健康和旧证书一致。强制杀进程/断电不保证finally执行，恢复后先用check逐一核对；只停止这两个受管部署，不清容器/卷。紧急停候选：

```sh
sudo -n python3 -B sunmoonai/registry-platform/sni_proxy.py stop --config /home/zymun/worktrees/luna/k8s/sunmoonai/registry-platform/config/sni-local-candidate.json --apply
sudo -n python3 -B sunmoonai/registry-platform/host_runtime.py stop --config /home/zymun/worktrees/luna/k8s/sunmoonai/registry-platform/config/harbor-main-local.json --apply
```

### 本次偏差如实保留

最初一次性检查旧nginx-photon 1.26.2模块时，没有用tmpfs覆盖其三个声明卷，Docker新增3个匿名卷。检查容器`sunmoon-sni-module-inspection-20260927`已退出，3卷保留；卷总数43→46，旧43卷未删除。后续候选使用无声明卷的新固定镜像，并在准入和容器检查中拒绝隐式卷；实际代理0卷。该偏差不以“全程无新卷”掩盖，也不擅自清理。

## 正式维护卡的前置清单

此节是待完成项，**不能据此现在执行入口切换**。当前30443属于`kind-control-plane`，它同时提供宿主80、30444–30446和旧API127.0.0.1:43001。停止它会影响旧发布、沙箱调度及这些入口；`kind-worker2`必须保留运行，其数据不能清理。

1. 先完成可写生命周期/备份恢复接口；取得旧仓库同一停写点的最新逻辑数据库、镜像层、配置/密钥及目录清单。不能把9月26日快照当最新。
2. 完成新仓库全量对账、隔离推拉/Jobservice验收；新写入前保留一键只读及可恢复快照。正式写入后回旧库必须反向同步，不能直接丢弃新增数据。
3. 固定旧控制面/worker容器ID、旧集群UID、80/30443–30446映射、旧worker实际NodePort和入口TLS健康。冻结发布/沙箱控制。过渡到旧worker的TCP转发若需要，须列出具体IP、端口、时限与停止回退命令；当前未实现、未承诺其他入口连续可用。
4. 明确旧API停机持续到哪个阶段。方案要求先独立Harbor/代理、后建main，不能把整个新集群平台部署时间冒充短暂的代理切换时间。若无法在批准窗口恢复必要能力，应回退旧入口，保留新副本继续准备。
5. 所有者维护窗口中执行WSL关闭/VHDX手动压缩，按数据盘操作卡重挂并验证服务可见性；不启用自动收缩。重新核验旧节点/卷/备份、服务状态和磁盘大小。
6. 备齐最终转发配置、启停/回退脚本后，再由所有者批准准确停服窗口。只停止已登记旧控制面，正式代理接管30443；失败在批准上限内停新代理、启动原控制面，核旧UID、端口、旧Harbor和各应用入口。现在的候选程序故意不包含此实际动作。
7. 正式main每节点独立宿主目录及双挂载、Harbor信任、共享平台/CI-CD、重建集群不影响仓库数据等验收继续；最终清理统一最后做，禁止容器/卷prune。

规则核对：C-I8要求漂移/未完成正式准入拒绝；C-R1/R2钉源码/镜像与物料摘要；C-D1候选只读、旧仓库仍为权威写入源。
