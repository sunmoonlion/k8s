# KIND 诊断：沙箱持久卷是不是随 Pod 换了节点 — 2026-09-26

被测仓 k8s `68dedce9`（fable）。只读，没有发版，没有改任何资源，没有改产品代码。

结论：不是换节点。卷有 `nodeAffinity`，必须在 `kind-worker2`。回收前的 `bg8gp` 和拉起后的 `gq6fh` 都被调度到 `kind-worker2`。三个 kind 节点的 hostPath 里都没有 `rollout-2026-09-26T03-28-32-01a0dbc1-e34d-7ed1-964a-172d1c030222.jsonl`。`kind-worker2` 上那份目录仍是 9 月 25 日的，里面的 `codex` 是空的。

待办三条里，对得上的前提是第二条：有亲和、两个 Pod 在同一节点、hostPath 里找不到文件。文件不是从持久卷上被删掉的。Pod 里看到的 `/data/codex` 不是持久卷里的那个子目录，而是镜像声明的匿名卷，盖在持久卷子目录上面。03:31 新建的是这个匿名卷。旧容器一删，上一份匿名卷连同 rollout 一起没了。持久卷根目录还是 9 月 25 日那份。

第 3 步的 `docker` 在当时的 shell 里不在 PATH 上（`command not found: docker`），改用 `/usr/bin/docker` 再跑。通过标准没改。

## 1. 卷的定义

`storageClassName` 是 `standard`。`hostPath.path` 是 `/var/local-path-provisioner/pvc-7fdb9035-f4d0-4471-9109-769a9edb9f2c_sandbox-pool_sandbox-u-a63d03b16693-codex-home`，类型 `DirectoryOrCreate`。有 `nodeAffinity`，`kubernetes.io/hostname` In `kind-worker2`。local-path 配置只有 `DEFAULT_PATH_FOR_NON_LISTED_NODES` → `/var/local-path-provisioner`，没有 `sharedFileSystemPath`。

```text
spec:
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 2Gi
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    name: sandbox-u-a63d03b16693-codex-home
    namespace: sandbox-pool
  hostPath:
    path: /var/local-path-provisioner/pvc-7fdb9035-f4d0-4471-9109-769a9edb9f2c_sandbox-pool_sandbox-u-a63d03b16693-codex-home
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - kind-worker2
  persistentVolumeReclaimPolicy: Delete
  storageClassName: standard
  volumeMode: Filesystem
status:
  phase: Bound

NAME                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-path           rancher.io/local-path   Retain          WaitForFirstConsumer   false                  95d
standard (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  95d

{
        "nodePathMap":[
        {
                "node":"DEFAULT_PATH_FOR_NON_LISTED_NODES",
                "paths":["/var/local-path-provisioner"]
        }
        ]
}
```

## 2. 前后两个 Pod 的节点

`gq6fh` 在 `kind-worker2`。events 没过期：`bg8gp` 和 `gq6fh` 都是 Successfully assigned 到 `kind-worker2`。

```text
NAME                 STATUS   ROLES           AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION                      CONTAINER-RUNTIME
kind-control-plane   Ready    control-plane   95d   v1.27.3   172.18.0.3    <none>        Debian GNU/Linux 11 (bullseye)   6.6.114.1-microsoft-standard-WSL2   containerd://1.7.1
kind-worker          Ready    <none>          95d   v1.27.3   172.18.0.2    <none>        Debian GNU/Linux 11 (bullseye)   6.6.114.1-microsoft-standard-WSL2   containerd://1.7.1
kind-worker2         Ready    <none>          95d   v1.27.3   172.18.0.4    <none>        Debian GNU/Linux 11 (bullseye)   6.6.114.1-microsoft-standard-WSL2   containerd://1.7.1

NAME                                     READY   STATUS    RESTARTS   AGE   IP             NODE           NOMINATED NODE   READINESS GATES
sandbox-demo-5ff45bb6d8-g2tcz            1/1     Running   0          22h   10.244.2.50    kind-worker2   <none>           <none>
sandbox-provisioner-6b784bd4cd-vxkqq     1/1     Running   0          12h   10.244.2.69    kind-worker2   <none>           <none>
sandbox-u-a63d03b16693-56c87f6b5-gq6fh   1/1     Running   0          14m   10.244.2.108   kind-worker2   <none>           <none>

36m   Scheduled   sandbox-u-a63d03b16693-65476d4dc9-bg8gp   Successfully assigned sandbox-pool/sandbox-u-a63d03b16693-65476d4dc9-bg8gp to kind-worker2
14m   Scheduled   sandbox-u-a63d03b16693-56c87f6b5-gq6fh    Successfully assigned sandbox-pool/sandbox-u-a63d03b16693-56c87f6b5-gq6fh to kind-worker2
```

## 3. 每个 kind 节点上的 hostPath

三个节点都没有 `rollout-*.jsonl`。只有 `kind-worker2` 有这个目录，目录时间是 Sep 25 14:57，子目录 `codex` 是空的，也是 Sep 25 14:57。不是 03:31 新建的那份。

```text
== kind-control-plane
ls: cannot access '/var/local-path-provisioner/pvc-7fdb9035-f4d0-4471-9109-769a9edb9f2c_sandbox-pool_sandbox-u-a63d03b16693-codex-home': No such file or directory
--- rollouts ---
== kind-worker2
total 12
drwxrwxrwx  3 root root 4096 Sep 25 14:57 .
drwxr-xr-x 13 root root 4096 Sep 25 17:21 ..
drwxr-xr-x  2 root root 4096 Sep 25 14:57 codex
--- rollouts ---
== kind-worker
ls: cannot access '/var/local-path-provisioner/pvc-7fdb9035-f4d0-4471-9109-769a9edb9f2c_sandbox-pool_sandbox-u-a63d03b16693-codex-home': No such file or directory
--- rollouts ---
```

## 4. 另一个用户卷

`sandbox-demo-codex-home` 的卷同样有 `nodeAffinity`，hostname In `kind-worker2`。hostPath 是 `/var/local-path-provisioner/pvc-9e5b113e-0b82-4558-b953-6f165db84728_sandbox-pool_sandbox-demo-codex-home`。demo Pod `sandbox-demo-5ff45bb6d8-g2tcz` 也在 `kind-worker2`。

## 补充：03:31 那份目录在哪

Pod 规格里只有一个业务挂载：`codex-home` → `/data`（PVC）。容器里 `/proc/self/mountinfo` 还有第二条，盖在 `/data/codex`：

```text
/data        …/local-path-provisioner/pvc-7fdb9035-…-codex-home
/data/codex  …/containerd/…/containers/1a22ff97dbbfb53b753c004babcb0ac01a878e3522ef110b1e5d680d0bce9084/volumes/0d42cf957b8ba9d6f8cb392593dfc03148a9a2881ee6a12681ac037e522c7016
```

`1a22ff97…` 就是当前容器 `gq6fh` 的 containerd id。这条匿名卷的 inode 是 `14112322`，和 Pod 里的 `/data/codex` 相同，目录时间 Sep 26 03:31，里面是 auth.json、config.toml、sqlite，没有 `sessions`，也没有 rollout。持久卷自己的 `codex` 子目录 inode 是 `12685119`，仍是空的。

镜像 `sandbox@sha256:ba14b8d3f69e4359a4b13dc78c1078b2ef2ec1498e54eeda8dd62e100c219a2f` 的配置里有 `"Volumes": {"/data/codex": {}}`，`WorkingDir` 是 `/data`，`CODEX_HOME=/data/codex`。containerd 按这个声明在 `/data/codex` 挂了一个随容器生灭的卷，把持久卷里的同名子目录挡住了。

停在这里，没有改任何东西。
