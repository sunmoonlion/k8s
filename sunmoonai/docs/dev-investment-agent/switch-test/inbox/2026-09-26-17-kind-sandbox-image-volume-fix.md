# KIND：修沙箱镜像的匿名卷——rollout 真正落到持久卷；顺带发 runner 的兜底文案修复（本地机）

```text
被测仓：k8s，本地路径 ~/worktrees/fable/k8s（第二段还要 investment-app）
跑：按下面编号步骤做（第一段：重建沙箱镜像、换供给器里的镜像引用、清掉老 PVC 里的 root 空目录、回收拉起验证；第二段：只换投资后端镜像，同 14）
仓与提交：k8s 本条待办所在的 fable 头（含 sandbox-platform/image 的两处改动）；investment-app db1d92c（子仓 investment-backend 6f45b33；web 仍是 319258d，不动）
预计：50 分钟；要 Docker、KIND、Harbor
看什么：第 6 步在 kind-worker2 的 hostPath 里能直接看到 rollout 文件；第 7 步回收再拉起后文件还在，同一会话发话有回答，runner 日志有 `thread resumed`
前提：无（KIND 现在：沙箱镜像 `ba14b8d3…`、投资后端 `4f639f78…`）
回传：k8s/sunmoonai/scripts/results/kind-sandbox-image-fix.<时间>.md（写下后在被测仓提交）
```

## 这次改的是什么

16 查明：镜像里的 `VOLUME ["/data/codex"]` 让 containerd 在 `/data/codex` 挂了一个随容器生灭的匿名卷，盖住了 PVC 里的同名子目录，rollout 全写在匿名卷里。改动两处（都在 `sandbox-platform/image/`）：

- `Dockerfile`：删掉 `VOLUME` 声明。
- `entrypoint.sh`：`CODEX_HOME` 不可写就打印属主并以退出码 4 退出，不再静默；`chmod 700` 失败不致命。

老 PVC 里留着 containerd 当年为挂匿名卷建的 `codex` 空目录（root 属主、755），新镜像的入口会因不可写退出，所以第 4 步要把它删掉（只在为空时 rmdir）。新用户的 PVC 没有这个问题。

`investment-backend` 6f45b33：runner 把 `no rollout found` 也当作线程没了（真 app-server 的文案），走另起线程的兜底；和 14 的 c89d8fe 之间只有这一处。

## 一、沙箱镜像与供给器

1. 建镜像并核对没有 VOLUME：
   ```bash
   cd ~/worktrees/fable/k8s/sunmoonai/sandbox-platform
   IMG=harbor.sunmoonai.com:30443/app-images/sandbox:0.155.1-r2
   docker build --build-arg NODE_IMAGE=harbor.sunmoonai.com:30443/k8s-images/node:24.18.0-alpine@sha256:4ba75f835bb8802193e4c114572113d4b26f95f6f094f4b5229d2a77773e0afc -t $IMG -f image/Dockerfile .
   docker inspect --format '{{json .Config.Volumes}}' $IMG     # 必须是 null；不是就停
   docker push $IMG
   docker inspect --format '{{index .RepoDigests 0}}' $IMG     # 取 digest
   ```
2. 换引用：`sandbox-platform/resources/provisioner.yaml` 里 `SANDBOX_IMAGE` 的 digest，和 `sandbox-platform/resources/demo-user.yaml` 里的 `image:` digest，都换成新的（两处都是 `app-images/sandbox@sha256:…`）。这两个文件的改动是待办明确让改的，随结果一起提交。
3. 应用供给器：
   ```bash
   export KUBECONFIG=~/.kube/kind-config
   kubectl apply -f ~/worktrees/fable/k8s/sunmoonai/sandbox-platform/resources/provisioner.yaml
   kubectl -n sandbox-pool rollout status deploy/sandbox-provisioner --timeout=120s
   kubectl -n sandbox-pool exec deploy/sandbox-provisioner -- sh -c 'echo $SANDBOX_IMAGE'   # 应是新 digest
   ```
   demo 沙箱这次不动（它是手工清单的常驻 pod，等下一次要用时再按新清单 apply）。
4. **所有者**先在设置页「回收沙箱」，等「已回收」（Deployment 没了，PVC 还在）。然后本地助手清掉老 PVC 里那个 root 空目录（只在为空时才删；不为空就停，贴 `ls -la`）：
   ```bash
   P=/var/local-path-provisioner/pvc-7fdb9035-f4d0-4471-9109-769a9edb9f2c_sandbox-pool_sandbox-u-a63d03b16693-codex-home
   /usr/bin/docker exec kind-worker2 sh -c "ls -la $P $P/codex && rmdir $P/codex && ls -la $P"
   ```
5. **所有者**点「拉起沙箱」，等「运行中」。本地助手核对新 Pod 用的是新镜像、`/data/codex` 不再是匿名卷：
   ```bash
   kubectl -n sandbox-pool get pod -l user=u-a63d03b16693 -o jsonpath='{.items[0].spec.containers[0].image}{"\n"}'
   kubectl -n sandbox-pool exec deploy/sandbox-u-a63d03b16693 -- sh -c 'grep " /data" /proc/self/mountinfo | cut -d" " -f5,10 ; ls -la /data/codex | head -5; id'
   ```
   通过：镜像是新 digest；mountinfo 里只有 `/data` 一条挂载（没有单独的 `/data/codex`）；`/data/codex` 属主是 uid 10001。Pod 起不来就 `kubectl logs`，看有没有 `not writable` 那行，贴出来停下。
6. **所有者**新建会话发「你好」，等回答。本地助手在节点上直接看持久卷：
   ```bash
   /usr/bin/docker exec kind-worker2 sh -c "find $P -name 'rollout-*.jsonl' -exec ls -la {} \;"
   ```
   通过：能看到这条线程的 rollout 文件。这是本轮的核心证据。
7. **所有者**回收再拉起（这次不用再做第 4 步），回同一会话发「你好」。通过：回答正常出现；第 6 步的文件还在（再跑一次第 6 步命令）；`kubectl -n app-platform-dev logs deploy/investment-backend-runner --since=20m | grep -E "thread resumed|no rollout|thread not found|gone on sandbox"` 里有 `thread resumed`，没有后三种。

## 二、投资后端 6f45b33（同 14 的步骤，只换 release id 与目录）

8. 身份准备沿用 `~/private/investment-identity-recovered-20260926`；只建后端镜像；锁只改 backend 一段（commit 6f45b33…，`task` 改 `resume-text-kind-20260926`）；输入只换 `images.backend`；`migration_head` 仍 `20260925_0011`；渲染 `--release-id kind-wb-20260926-r15`，diff 只应有后端 digest、backend 锁与注解、派生哈希、release id；门禁、单测、plan；维护窗口四类缩 0；回执到 `~/private/investment-wb-20260926-r15`；server-dry-run；deploy；`drift`、`status`。
9. 发完再在会话里发一句话确认正常（runner 重启后第一句会走 resume，日志应再多一行 `thread resumed`）。

10. 回传：每步结果与屏幕上看到的；过滤含 sk-、kmcp-、token=、password 的行。

失败停在那步。第一段没过就不要做第二段。
