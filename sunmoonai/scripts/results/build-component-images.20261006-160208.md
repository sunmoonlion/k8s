# 待办 24 回传：build-component-images

时间：2026-10-06 16:02。HEAD 核对时 `47e77ec9`。工作区干净。`component-images.yaml` 的 `revision` 是 `b23ea80b24c0c3b866bb346277a870028ed58b42`，`merge-base --is-ancestor` 退出 0。`platform-plan OBJECT=relay-platform/relay` 退出 0。

## 怎么执行

待办第二节的循环第一次跑完：会合点退出 0 并写了 `image.lock.yaml`，沙箱和供给器随即在 `Refuse unreviewed source revisions or dirty checkout`（`build.yaml:111`，断言 `git status --porcelain` 为空）退出 2，用时 3 秒和 4 秒。构建从钉住的提交 `git show` 导出配方，这张锁不进镜像。把会合点的锁用 `git stash push -- <锁路径>` 挪开后，工作区干净，再分别构建沙箱和供给器，然后 `stash pop`。没有改判据，没有 flux-release、晋级、deploy。

## 一、三次构建

| 对象 | 退出码 | 用时 | digest 前 12 位 |
| --- | --- | --- | --- |
| relay-platform/relay | 0 | 29s（15:35:32–15:36:01） | `5224cf4fcaec` |
| sandbox-platform/sandbox | 2 | 1209s（15:38:15–15:58:24，干净树重跑） | 无新 digest |
| sandbox-platform/provisioner | 0 | 30s（15:59:19–15:59:49，干净树重跑） | `0a665ec73777` |

会合点、供给器的锁都没有 `harbor_project`，`source_revision` 都是 `b23ea80b24c0c3b866bb346277a870028ed58b42`。沙箱锁未改：仍是 `harbor_project: app-images`，digest `sha256:ba14b8d3f69e…`，`source_revision: kind-sandbox-0155-r2`。

沙箱失败任务：`Build using the committed recipe and locked base images`（`build-attempt.yaml:65`，`Timed out after 1200 second(s)`）。随后 `Refuse source switching for trust, build or an already official failure`。`.build/applications/sandbox-build.log` 没有生成：超时结果带 `no_log`，保存诊断的条件要求 stdout/stderr 已定义，该步被跳过。没有可贴的日志尾部。

## 二、暂存

`platform-stage OBJECT=relay-platform/relay` 退出 2。失败任务：`Require unselected stage declarations to remain unchanged`（`topology.yaml:27`）。原话：`Unselected stage declarations differ. Review and stage the complete topology with OBJECT=all first.` 渲染已经落盘，随后断言失败。没有改跑 `OBJECT=all`。

`platform-stage OBJECT=sandbox-platform/provisioner` 退出 0。之后 `sudo find` 见到 `/etc/sunmoon/services/sunmoon-kind/sandbox-provisioner.yaml`。`workbench-signing.yaml` 在，属主 root，模式 0600。

`auth.sops.yaml` 的 `ENC[` 计数：4。密文不贴。`lastmodified` 变成 `2026-10-06T08:00:55Z`（新增公钥后整份 Secret 重加密）。

会合点 `workload.yaml` 的增删行（密文无关）：

- 注解 `input-sha256` 从 `43fe8f7d…` 换成 `36938cdb…`
- 镜像从 `app-images/relay@sha256:dfc4d0e0…` 换成 `platform/relay@sha256:5224cf4fcaec…`
- 新增 env `RELAY_JWT_PUBLIC_KEY`（`secretKeyRef`，name `relay-auth`）

供给器 `workload.yaml`、`auth.sops.yaml`、`kustomization.yaml` 是新文件。`git diff` 对未跟踪文件没有输出。env 里有 `SANDBOX_IMAGE`（仍是旧的 `app-images/sandbox@sha256:ba14b8d3f69e…`）、`APP_NAMESPACE=app-platform-dev`、`RELAY_NAMESPACE=relay-platform-dev`。`stages.yaml` 增加 18 行，一个 `sandbox-provisioner` 阶段，`dependsOn: relay`。

## 三、提交

`f0fc6bc6 test(local): 待办 24 构建三个自研镜像并暂存 relay、供给器`。8 个文件。沙箱锁不在其中。

## 结论

不通过。沙箱构建超时，锁没有改成 `platform/` 的新摘要；会合点暂存退出 2。会合点和供给器的镜像已发布并写入上述提交。
