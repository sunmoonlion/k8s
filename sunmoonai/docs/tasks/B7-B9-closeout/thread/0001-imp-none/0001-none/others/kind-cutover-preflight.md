# B7：KIND 切换前只读核对（未执行切换）

2026-09-19，显式 kubeconfig `/home/zymun/.kube/kind-config`、context `kind-kind`；
未改默认 context，未读取 Secret 值，未连接业务数据库或执行 SQL，未更改集群对象。
以下是核对时点的观测，执行前必须再次核 UID/版本，不是长期有效的部署授权。

## 已部署对象

namespace 均为 `app-platform-dev`；三组 API/Worker/Scheduler Ready 分别为 2/1/1。

| App | API UID | Worker UID | Scheduler UID | Backend 镜像 digest |
| --- | --- | --- | --- | --- |
| Info | `056282c3-b463-4925-95df-104016dea451` | `68491199-57da-4348-acba-d561bb423738` | `f97e8bb8-d779-4562-8baf-ee33153c2f34` | `884dc222c2c7c3fc86787592ec03a5bb306a44a8bf069df10e3c9ed38806f1b9` |
| Knowledge | `c20f1898-1b0c-4164-a06e-73252f68e305` | `1c548189-2b2e-47d9-a8f2-833708a2ff3f` | `9e4136e3-d947-4c30-a5b3-f82b74424821` | `36bc1dd6ac4631339070d29825f16373aa65a1f9fe65385d0f90a4564f87af17` |
| Investment | `0c3e309c-f734-4c02-8e01-c92fe8eaf2d9` | `899c856b-9139-4e70-995f-9e9aee16d2c6` | `0be1e90e-7d97-4da3-aea1-adbde3c0cb69` | `6a30e2d50eb47735ba8cf449fb776a5d1c848d84311c7e4ce69e99ab8719a434` |

镜像仓库前缀 `harbor.sunmoonai.com:30443/app-images/<app>-backend@sha256:`。
API/Scheduler release-id 分别为 `kind-info-dd-20260911`、`kind-know-dd-20260911`、
`kind-invest-dd-20260911`；三 Worker 没有该 Pod template 注解。
这说明源码同步不能替代部署，但未查询镜像内部 revision，不凭标签推断镜像包含哪些提交。

三组仍引用 `<app>-backend-postgresql-conn:DATABASE_URL` 和
`<app>-backend-broker:CELERY_BROKER_URL`，同一 App 的三运行角色共用这些引用。
这不是角色化 `<app>-backend-runtime` 新 Secret 的接线；本轮没有取值核真实用户名。
Worker 还引用 `CELERY_RESULT_BACKEND`，后续须核它的实际配置与当前无 result backend 的
候选合同是否相符，不能只替换镜像。

共享依赖：

- `data-platform-dev/postgresql-sunmoonai` StatefulSet UID
  `020ee03a-5641-44a1-9885-84104fddf5f6`；镜像 tag `17.6.0-debian-12-r4`。
- `messaging-platform-dev/rabbitmq-sunmoonai` StatefulSet UID
  `093f67ec-ecdf-4cad-9f10-37002e4bdedb`；镜像 tag `4.1.3-debian-12-r1`。
  启动 definitions 来自 Secret `rabbitmq-app-definitions`；未读取其内容。

## 尚不能发起精确发布批准的原因

B7v 是一次性数据库/容器演练，不是业务库备份，也没有生成可发布的业务供给包。
下面对象尚未固定；因此不提出一个范围模糊的“允许部署一切”请求：

1. 三 App 新 release.json、镜像 digest、配置摘要，以及新身份/Secret 的安全供给入口。
2. 业务 schema/owner/继承/PUBLIC/default ACL、旧连接和队列积压的新鲜只读核对。
3. 共享 `rabbitmq-app-definitions` 中所有非目标租户的保留证明，及 live 与启动定义的
   同步方案；不得拿单 App 测试 definitions 覆盖共享 Secret。
4. 业务数据库与对象存储备份的准确对象、恢复实测、可接受停机/RPO/RTO，以及外部
   副作用的对账方式。本轮只恢复合成 Outbox/Inbox，不能替代这些业务证据。
5. 每 App 的排空、停止受理/调度窗口，新旧凭据观察和撤销窗口。NOLOGIN 或改密码
   不会自动赶走 PG 旧连接；应先固定完整身份与连接归属，避免撤错共享账号。
6. 与同一 schema revision 兼容的回滚镜像/配置，旧身份保留期限与恢复条件；失败即停
   后续 App，不通过宽权限兜底，也不先撤旧身份制造停机。

建议下一授权单元是：允许准备**仅本地 KIND、三 App、共享依赖只改目标条目**的切换
候选与业务备份方案；候选固定后再单独批准实际切换。远端云集群不在这个单元范围。
不把这一建议当作已获用户批准。

## 复核命令（只读、不含 Secret 值）

```sh
kubectl --kubeconfig=/home/zymun/.kube/kind-config --context=kind-kind \
  get deployments,statefulsets -A \
  -o custom-columns='NS:.metadata.namespace,KIND:.kind,NAME:.metadata.name,UID:.metadata.uid,GEN:.metadata.generation,READY:.status.readyReplicas,IMAGES:.spec.template.spec.containers[*].image'
```

Secret 引用按 Deployment 的 `env[].valueFrom.secretKeyRef` 读取；broker 挂载来源按
StatefulSet 的 `volumes[].secret.secretName` 读取。不得将命令替换成打印 Secret YAML。
