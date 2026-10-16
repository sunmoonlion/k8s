# 待办 27 回传续十一：供给器带拉取凭据、Neo4j 路由，重建、发布、晋级、应用

时间：2026-10-06 20:27。没有退回。

## 一、核对

头是 `205d173d`，工作区干净。

## 二、重建供给器

`platform-build OBJECT=sandbox-platform/provisioner` 退出 0，26 秒。锁从 `sha256:0a665ec7…` / `b23ea80b…` 换成 `sha256:3459b0b5…` / `30e965a1626270af1521c5fdc991debafa51464d`。

## 三、暂存

供给器暂存退出 0，15 秒。Neo4j 控制台暂存退出 0，32 秒。差异是：

- 供给器镜像换成新摘要，workload 多了 `SANDBOX_IMAGE_PULL_SECRET=registry-puller`
- neo4j 路由多了 `passHostHeader: false`

提交 `72113bee`，消息 `deploy: 供给器带拉取凭据、Neo4j 控制台不透传 Host（第 27 轮续十一）`。

## 四、发布与晋级

`flux-release` 退出 0，27 秒。候选：

```yaml
digest: sha256:a6575451abd52249a64239e8d5be29e7d44123f750435506ff29c0e8352bc7fa
path: ./clusters/kind
repository: oci://harbor.sunmoonai.com:30443/platform/deployments-kind
requires_sops: true
revision: 72113bee2c9a7a59f9077e6e8826ce81a0ac09a1
```

diff 只有 digest 和 revision。提交 `fc955a05`，消息 `release(kind): 晋级到 72113bee（0010 第 5 步，第五次）`。

## 五、应用源

`flux-source-apply` 退出 0，164 秒。`flux-source-status` 退出 0。`lastAppliedRevision` 是 `sha256:a6575451…`。

`sandbox-provisioner-7779867fd4-fjdbf` 1/1 Running，年龄约 2 分钟，镜像是新摘要 `sha256:3459b0b5…`。原来的沙箱 Pod `sandbox-u-f1cee6277692-6ddd9cc5b7-gs8gp` 仍是 ImagePullBackOff，没有被换成新的。

现网 `IngressRoute` `data-platform-dev/neo4j-ui` 已有 `passHostHeader: false`。

## 六、platform-check

退出 2，68 秒。失败任务仍是 `Require Neo4j Browser acceptance`（`infrastructure/services/verify.yaml:270`）。fail_msg：`{"passed": false, "reason": "Browser HTML is unavailable"}`。

路由改完后再探 `https://neo4j.sunmoonai.com:30443/` 和 `/browser/`，两个都还是 400，`Invalid SNI`。

## 结论

不通过。供给器新镜像已上，拉取凭据写进了声明，Neo4j 路由也已经不透传 Host。`platform-check` 的 Neo4j 项还是同样的失败，入口上这两个路径仍是 Invalid SNI。
