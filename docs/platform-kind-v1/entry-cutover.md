# 新入口与 Harbor 切换操作卡

状态：2026-10-01 已获批准并实际切换；skopeo 推拉通过，但宿主 Docker 拉取失败，**已回退，30443 当前仍是旧入口**。新入口恢复候选 32443。修复与下一次维护见 [Docker 维护方案](docker-maintenance.md)。

## 范围与已有证据

- 新 Harbor：`sunmoon-registry.service`，127.0.0.1:11443，独立数据目录 `/data/harbor/platform-kind-v1/data`。
- 新入口：官方 HAProxy 3.4.6 固定摘要，`sunmoon-entry.service`，候选 127.0.0.1:32443。
- Harbor 域名经候选入口到新 Harbor：TLS 信任与域名检查、健康接口已通过。
- 其他域名按现有入口转到 **172.18.0.5:30443（kind-worker）**；不能提前改为 main 的 19443，main 尚无应用入口。候选、旧入口和该后端的应用证书 SHA256 已一致；这仅验证分流身份，不代替应用登录或证书信任验收。
- 旧代理：`sunmoon-sni-transition-main-20260928`，host 网络，监听 0.0.0.0:30443，Harbor 后端 18443。旧代理配置不修改，保留供回退。

本次不迁移旧镜像或账号。切换后正式域名访问新的仓库；旧集群若需重新拉取仅存在于旧仓库的镜像会失败。旧工作负载本身不重启。新业务镜像需重新构建发布，这是已确认的新体系目标。

## 停服影响与准入

停止旧代理到新代理接管期间，30443 上的 Harbor 和所有应用 TLS 连接会中断，预计约 1 分钟；维护上限 10 分钟，故障回退另留 5 分钟。80、Kubernetes API 和其他端口不切换。无 WSL 关机，无数据/容器/卷清理。

执行前：检查新 Harbor 健康、旧 Harbor 各组件实际基线、新入口候选检查通过、旧代理和 kind-worker 身份/路由未变、30443 仍由指定旧代理占用；暂停镜像发布。新增准入：宿主 Docker 至少 29.5.0，且通过候选入口真实拉取。原卡写“两个 Harbor 健康”过于笼统：本次回退复核发现旧 jobservice 从未启动，旧聚合健康 unhealthy，其他组件正常，不能宣称旧仓库完整健康。若现场漂移，停止操作并重新评估。

## 执行顺序（所有者批准后由助手执行）

在 `/home/zymun/worktrees/platform-kind-v1/k8s/platform`：

1. 给宿主 Docker 的 `/etc/docker/certs.d/harbor.sunmoonai.com:30443/` 增加独立文件 `platform-kind-v1-ca.crt`，内容来自新 `/etc/sunmoon/registry/tls/ca.crt`。保留原证书；不重启 Docker。专用 skopeo 凭据与 CA 由新仓库代码管理，不复用旧管理员口令。
2. `make entry-stop` 停止候选。站点仅将 `entry_listen_address` 改为 `0.0.0.0`、`entry_port` 改为 `30443`，应用后端仍保持 172.18.0.5:30443。
3. `docker stop --timeout 30 sunmoon-sni-transition-main-20260928`。仅停止，保留容器与配置。
4. `make entry-deploy`。入口生成和启动采用正式原生链，命令会实际核验新 Harbor 的 SNI、CA 与健康。
5. 验收：正式域名证书属于新 CA；新 Harbor 管理员认证成功；新项目发布与只读机器人分别通过 skopeo 真实推送/拉取及 manifest 摘要比对，只读身份推送被拒；宿主 Docker 以只读身份真实拉取成功；普通应用域名仍到相同后端。记录本次发布引用，不把新仓库空数据误认为旧仓库恢复成功。
6. 若其中任何条件失败、不能在窗口内修复，执行下面回退。成功后旧代理保持停止，不删除；两个新 unit 暂不启用开机自启，待挂载与启动验收。

## 明确回退

```sh
make entry-stop
docker start sunmoon-sni-transition-main-20260928
```

确认旧 30443 恢复旧证书、旧 Harbor 原组件状态和原应用路由；已有 jobservice 异常单独记录。保留新增信任证书不会破坏旧 CA 信任。将站点恢复 `127.0.0.1:32443`，候选入口是否重新启动按排错需要处理。新 Harbor 后端仍可保留运行，其数据不删除。

本卡是一次性现场切换操作，不成为日常部署对旧容器的依赖。日常入口为 `make entry-plan/entry-deploy/entry-start/entry-stop/entry-status`；全新部署只使用新服务。旧代理退出清理另按既定保护条件批准。


## 本次结果

首次被空仓库错误格式拦住并回退；第二次被只读发布容器读取归档权限拦住并回退。修正为已校验公开归档 0644，并为 skopeo 的 `/var/tmp` 提供有上限 tmpfs，离线读取通过后再次执行。

第三次切换及 skopeo 完整验收用时 18 秒；发布 `platform/haproxy@sha256:5924fd69580b75444653595c750080fdde968097baaba62b8cade154511a0272`，6 层、8 个 blob 校验通过，puller 推送被拒。正式域名新 CA、管理员认证、健康和应用分流证书一致性均通过。

随后追加宿主 Docker 拉取，29.4.3 在 token 请求上报未知 CA；因此最终按失败条件回退，未将正式切换标为完成。新 Harbor 及镜像保留，旧入口已恢复原证书，候选入口新 CA 检查通过。Docker 门禁已前移，升级后的完整验收尚待新维护窗口。
