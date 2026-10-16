# 待办 27 回传续三：Harbor 为何退出，拉起后再部署

时间：2026-10-06 17:31。没有动 `/data/harbor`。没有退回晋级指针。第六节后半和整套发布没有做完。

## 一、谁停了 Harbor

`docker.service` 没有重启。17:16:25.595 systemd 停 `sunmoon-entry.service`，下一毫秒 17:16:25.596 停 `sunmoon-registry.service`。`ExecStop` 是 compose 项目 `sunmoon-registry` 的 `stop`（进程 1021165，退出 0）。17:16:37 单元 `Stopped`，`Deactivated successfully`。容器是被这个 stop 停掉的，不是自己退出。

关系：`sunmoon-platform.target` 的 `Requires` / `ConsistsOf` 包含 `sunmoon-registry.service`、`sunmoon-entry.service`、`sunmoon-cluster.service`。入口和 Harbor 的 drop-in 都是 `PartOf=sunmoon-platform.target`。停入口把目标一起停了，目标再停 Harbor。

同一秒集群也被停了：17:16:25.550 `Stopped sunmoon-cluster.service`。三个 `sunmoon-kind-*` 容器退出（control-plane、worker 137，worker2 130）。`127.0.0.1:27443` 拒绝连接。

诊断时 `sunmoon-registry.service` 是 inactive (dead)。反向依赖：`sunmoon-entry.service` 被 `docker.service` 和 `sunmoon-platform.target` 牵着。Harbor 容器全部 Exited；入口容器 `sunmoon-entry-proxy-1` Up。`platform-deploy-20261006-170830.log` 的 `changed=` 只有最后一段是 `changed=1 failed=1`，那次部署在 17:09 就停了，不是 17:16 这次停 Harbor 的原因。

## 二、拉起 Harbor

诊断时单元是 inactive，只跑了 `registry-start`。开始前 `is-active` 已变成 active。`registry-start` 退出 0，40 秒。`registry-status` 退出 0。十个 `sunmoon-registry-*` 容器后来都是 Up (healthy)。`127.0.0.1:11443` 和 `0.0.0.0:30443` 都在听。

## 三、核入口

`entry-status` 退出 0。`ActiveState=active`，`SubState=running`。健康检查退出 0，正文 `status` 为 `healthy`。

## 四、部署

`platform-deploy OBJECT=all` 退出 2，53 秒（17:29:39–17:30:32）。日志 `infrastructure/.build/platform-deploy-20261006-172939.log`。失败任务：`Require saved API identity before any existing cluster changes`（`cluster/deploy.yaml:107`）。`kubectl get namespace kube-system` 连不上 `127.0.0.1:27443`。`flux-source-status` 退出 2，同样是 API 拒绝连接。

第六节前三条也连不上 API，没有 Kustomization、Pod、Job 输出。后面的检查没有做。

## 结论

不通过。Harbor 和入口已经恢复。集群在 17:16:25 和它们一起被 `sunmoon-platform.target` 停掉，部署停在 API 不在。
