# 待办 30 回传：knowledge 后端重建（默认数据集可以没有）

时间：2026-10-07 09:40。没有退回。没有贴口令。

## 一、核对

头是 `9b32abb9`，工作区干净。knowledge-backend 头是 `ee3b0b0`。

## 二、重建与暂存

`platform-build OBJECT=app-platform/knowledge-app/knowledge-backend` 退出 0，86 秒。`platform-stage OBJECT=app-platform/knowledge-app` 退出 0，84 秒。没有 sops 变化。锁从 `sha256:be3c4269…` / `f75996bb…` 换成 `sha256:f9cccfe6a8448d19d2e0f786ce3ae06789424d716ecbd7ec71e7de21c812c7e2` / `ee3b0b0cf9b62f19acab6b4529d921f482e5d9fa`。五个 workload 的镜像都换成这个摘要。提交 `c68e360b`。

## 三、发布、晋级、应用

`flux-release` 退出 0，32 秒。候选：

```yaml
digest: sha256:872ee94d14aafbed01e9985fe309efce529edea08441f1cc7c013b0b39576399
path: ./clusters/kind
repository: oci://harbor.sunmoonai.com:30443/platform/deployments-kind
requires_sops: true
revision: c68e360b11c5fc999dcbb14874a4c597745a7a76
```

diff 只有 digest 和 revision。提交 `a1971b7f`，消息 `release(kind): 晋级到 c68e360b（待办 30）`。`flux-source-apply` 退出 0，225 秒。`flux-source-status` 退出 0，4 秒。

## 四、检查

新进程都是 1/1 Running（当时约 1 分钟）：`knowledge-api-5585cd875f-s9j4s`、`knowledge-scheduler-7c878777b7-bwd25`、`knowledge-worker-7844855968-tqpsk`。新身份 Job `knowledge-identity-f9cccfe6a844-v2-66nd9` 和新迁移 Job `knowledge-migrate-f9cccfe6a844-v2-bdn47` 都是 Completed。`application-check APP=knowledge` 退出 0，56 秒。

`knowledge-api` 最近 200 行里没有 `dataset_unavailable`，也没有 `mcp`。

## 五、对象存储控制台登录 500

Pod 是 `object-storage-0`，只有一个容器 `object-storage`。最近 60 行按 `login|console|x509|certificate|dial|refused|timeout` 过滤，一条都没有。进程日志停在启动横幅：API 是 `https://object-storage.data-platform-dev.svc.cluster.local:9000`，WebUI 是 `https://aistor.sunmoonai.com:30443`。

按卡片原样执行 `kubectl get pod $P` 时，`$P` 带了 `pod/` 前缀，kubectl 拒绝了。去掉前缀后标签是 `app.kubernetes.io/name=object-storage`，没有 `sunmoonai.com/object-storage-client`。

网络策略：

| 策略 | 作用 |
| --- | --- |
| `default-deny` | 本命名空间全部 Pod 默认拒绝进出 |
| `allow-cluster-dns` | 只放行到 kube-dns 的 53 |
| `object-storage-ui-access` | 只放 Traefik 进控制台端口 9001 |
| `object-storage-clients` | 只放带 `sunmoonai.com/object-storage-client=true` 的 Pod 进 API 端口 9000 |
| `object-storage-client-egress` | 只放那些客户端 Pod 出去访问 9000 |

控制台和 API 在同一个 Pod 里。声明里 `MINIO_SERVER_URL` 指向集群内 9000。这个 Pod 自己没有客户端标签，也没有允许它访问 9000 的出站策略。浏览器能打开登录页（入口到 9001），登录时控制台再去连 9000，连接被丢掉，所以页面回 500 `unable to login due to network error`，而 API 日志里看不到这次登录。

## 结论

knowledge 重建、发布、应用和检查通过。对象存储控制台的 500 对得上：控制台所在的 Pod 连不上自己的 API 端口。
