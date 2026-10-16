# 待办 27 回传续十二：Neo4j 内部证书加公网名字，重签、发布、晋级、应用

时间：2026-10-06 21:21。没有退回。没有贴私钥或口令。

## 一、核对

头是 `321f58f7`，工作区干净。

## 二、重签

备份目录就是 `/mnt/sunmoon-data/backups/services/sunmoon-kind/neo4j-tls`。只删了两份 `public.crt`，主备 `private.key` 都还在。

## 三、暂存

`platform-stage OBJECT=data-platform/neo4j` 退出 0，34 秒。新证书 SAN：`DNS:neo4j`、`DNS:neo4j.data-platform-dev.svc.cluster.local`、`DNS:neo4j.sunmoonai.com`。

变的只有三份：`auth.sops.yaml`（新证书）、`ui/workload.yaml`（路由不再写 `passHostHeader`）、`workload.yaml`（`input-sha256` 换成 `00ed6657…`）。别的 sops 没动。提交 `cc7b2287`，消息 `deploy(neo4j): 内部证书加公网名字（第 27 轮续十二）`。

## 四、发布与晋级

`flux-release` 退出 0，25 秒。候选：

```yaml
digest: sha256:9edd08a34dfacc6d3989cb65f6ee4ff93882a3b4c822c409c6f429f277b2a2e7
path: ./clusters/kind
repository: oci://harbor.sunmoonai.com:30443/platform/deployments-kind
requires_sops: true
revision: cc7b2287bc6eded9d5571a21f136779dc5a39615
```

diff 只有 digest 和 revision。提交 `16983ee0`，消息 `release(kind): 晋级到 cc7b2287（0010 第 5 步，第六次）`。

## 五、应用源

`flux-source-apply` 退出 0，163 秒。`flux-source-status` 退出 0，4 秒。`lastAppliedRevision` 是 `sha256:9edd08a34dfacc6d3989cb65f6ee4ff93882a3b4c822c409c6f429f277b2a2e7`，根阶段 Ready。

`neo4j-0` 已换成新 Pod，1/1 Running，启动时间 `2026-10-06T13:16:51Z`。

## 六、检查

`curl https://neo4j.sunmoonai.com:30443/browser/` 返回 `200`。

`platform-check OBJECT=all` 退出 2，83 秒。Neo4j 那一项过了（`browser_html: true`，`passed: true`）。停在下一项：

- 任务：`Require object storage console acceptance without printing private inputs`（`infrastructure/services/verify.yaml:293`）
- 断言：`object_storage_ui_acceptance.rc == 0`
- fail_msg：`{"passed": false, "reason": "Invalid console credentials must be denied"}`

## 七、网页上的沙箱

这个会话没有接上浏览器，我没有点「回收沙箱」和「拉起沙箱」。核对集群时，用户沙箱已经是新 Pod `sandbox-u-f1cee6277692-5cc8b8bc89-9vrwt`，创建于 `2026-10-06T13:01:41Z`，1/1 Running，0 次重启，拉取凭据名是 `registry-puller`。续十一里那个 ImagePullBackOff 的旧 Pod 已经不在。

## 结论

不通过。Neo4j 证书、路由、新 Pod 和 `/browser/` 的 200 都到了；整套 `platform-check` 停在对象存储控制台「错误口令必须被拒绝」。没有退回。
