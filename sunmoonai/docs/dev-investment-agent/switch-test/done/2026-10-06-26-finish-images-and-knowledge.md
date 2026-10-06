# 新体系：重建沙箱镜像、再暂存会合点与供给器、暂存 knowledge、本地提交（本地机；24、25 的收尾）

```text
被测仓：k8s，本地路径 ~/worktrees/fable/k8s
跑：按编号步骤做（拉最新 → 沙箱镜像重建 → 会合点、供给器再暂存 → knowledge 暂存 → 四个部署计划 → 本地提交）
仓与提交：k8s 本条待办所在的 fable 头（含 0559d44d：构建链四处修正、沙箱镜像钉到带 DEBIAN_MIRROR 的提交 e3ce871f；以及 knowledge 供给器前缀放宽、代次 v2）
预计：60–80 分钟，大头是沙箱镜像在线构建（上限 60 分钟）；不停服；不碰现网
看什么：沙箱构建退出 0，沙箱锁改成 platform/sandbox 的新摘要；供给器候选的 SANDBOX_IMAGE 跟着换；会合点暂存退出 0；knowledge 暂存退出 0，runtime/domain.sops.yaml 是密文，供给器策略的前缀成 info/；四个部署计划退出 0
前提：Harbor 在；没有残留的 stash；不 flux-release、不晋级、不 deploy
回传：k8s/sunmoonai/scripts/results/finish-images-and-knowledge.<时间>.md
```

## 24、25 查到的和远程的处理

| 24/25 的问题 | 处理（已在 fable 头上） |
| --- | --- |
| 会合点构建写了锁之后，沙箱、供给器的构建因「工作区不干净」拒绝（24 用 stash 绕过） | 组件镜像的脏树检查只看它自己的源码目录（`component.context`），别处的锁不算脏；不用再 stash |
| 沙箱构建 1200 秒超时，什么日志都没留下 | 构建输出边跑边落到 `infrastructure/.build/applications/<名>-build-<模式>.log`（超时被杀也留尾部）；超时可按镜像配，沙箱 3600 秒 |
| 沙箱要装 apt 包，Debian 官方源在国内慢 | 下载模式带 Debian 源（国内 tuna），沙箱 Dockerfile 接 `DEBIAN_MIRROR`；因此沙箱镜像单独钉到 e3ce871f（会合点、供给器仍钉 b23ea80b，锁不变） |
| 会合点暂存因阶段图漂移拒绝（供给器刚打开、尚未暂存） | 供给器已在 24 里暂存、stages.yaml 已提交，这次重跑应过 |
| knowledge 暂存断言 `source_prefix == 'info/original/'` | 放宽为 `info/` 名下的任意前缀（所有者决定：知识应用读 info 的原文和登记的数据集文件）；策略要在现网重建，供给 Job 代次 v1 → v2，并容忍「策略已挂在用户上」 |
| 25 回传说 info 没有 `runtime/domain.sops.yaml` | 这是对的：info 没有声明 `domain_secrets`，就不该有这个文件；knowledge 有一项（验签公钥），应该有 |

## 一、拉最新

```bash
cd ~/worktrees/fable/k8s && git log --oneline -3 && git status --short | head -5 && git stash list
grep -n "timeout_seconds: 3600\|revision: e3ce871f" infrastructure/applications/component-images.yaml
grep -n "job_revision: v2" gitops/components/app-platform/knowledge-app/knowledge-backend/config.yaml
```

头应是 `0559d44d` 或它之后；工作区干净；`git stash list` 为空（24 留了 stash 的话先 `git stash pop`，看一眼里面只有会合点的锁，再确认已和提交里的一样后 `git stash drop`）。三行 grep 都要有。

## 二、沙箱镜像重建（最长 60 分钟，期间别动这个工位）

```bash
echo "=== sandbox $(date +%T)"; make -C infrastructure platform-build OBJECT=sandbox-platform/sandbox; echo "exit=$? $(date +%T)"
sudo ls -la infrastructure/.build/applications/ | grep -i "build-.*log"
git status --short gitops/components/sandbox-platform
git diff gitops/components/sandbox-platform/sandbox/image.lock.yaml
```

要看到：退出 0；锁从 `app-images/sandbox@…ba14b8d3…` 改成 `platform/sandbox`、新摘要、`source_revision: e3ce871f…`。

失败就贴：退出码、失败任务名、`sudo tail -n 60 infrastructure/.build/applications/sandbox-build-*.log`（两种下载模式各一份，哪份有就贴哪份），然后停下，不做后面的。

## 三、会合点、供给器再暂存

```bash
make -C infrastructure platform-stage OBJECT=relay-platform/relay; echo "exit=$?"
make -C infrastructure platform-stage OBJECT=sandbox-platform/provisioner; echo "exit=$?"
git status --short gitops/components/relay-platform gitops/components/sandbox-platform gitops/clusters
git diff gitops/components/sandbox-platform/provisioner | grep -E '^[-+].*(SANDBOX_IMAGE|image:|value:)' | head -10
git diff gitops/components/relay-platform | grep -E '^[-+].*(image:|RELAY_JWT)' | head -10
```

要看到：两个都退出 0；供给器 workload 里 `SANDBOX_IMAGE` 变成 `…/platform/sandbox@sha256:<第二节的新摘要>`；会合点的候选与 24 已提交的一致（diff 为空或只有锁头注释）。

## 四、knowledge 暂存

```bash
make -C infrastructure platform-stage OBJECT=app-platform/knowledge-app; echo "exit=$?"
git status --short gitops/components/app-platform/knowledge-app
f=gitops/components/app-platform/knowledge-app/knowledge-backend/runtime/domain.sops.yaml; echo "$f: $(grep -c 'ENC\[' $f) 段密文, sops 头=$(grep -c '^sops:' $f)"
grep -rn "BEGIN PRIVATE KEY\|BEGIN PUBLIC KEY" gitops/ | head -3   # 必须没有
git diff gitops/components/app-platform/knowledge-app/knowledge-backend/provider/workload.yaml | grep -E '^[-+].*(info-originals|knowledge-source-|already in effect)' | head -12
git diff gitops/components/app-platform/knowledge-app/knowledge-backend/runtime/workload.yaml | grep -E '^\+.*(KNOWLEDGE_[A-Z_]+:|CROSS_APP|sizeLimit|NetworkPolicy|ARTIFACT_S3_ALLOWED_PREFIXES)' | head -20
```

要看到：退出 0；`domain.sops.yaml` 一段密文、一个 sops 头；供给器策略的 Resource 从 `info-originals/info/original/*` 变成 `info-originals/info/*`，Job 与 ConfigMap 名字带 `v2`；runtime 里 `ARTIFACT_S3_ALLOWED_PREFIXES: "info/"`、`sizeLimit: 2Gi`、`KNOWLEDGE_DATASET_REGISTRY_ENABLED`、`CROSS_APP_*`、沙箱入站的 NetworkPolicy。别的 sops 文件不该只因重加密而变。

## 五、部署计划（只读）

```bash
for a in tpl info knowledge investment; do echo "=== $a"; make -C infrastructure application-deployment-plan APP=$a; echo "exit=$?"; done
make -C infrastructure platform-plan OBJECT=all; echo "exit=$?"
```

要核到 info `20260929_0013`、knowledge `20260927_0007`、investment `20260929_0012`、tpl `20260911_0003`；`platform-plan` 退出 0。

## 六、本地提交

```bash
git add gitops/components gitops/clusters
git -c core.editor=true commit -m "test(local): 待办 26 沙箱锁、会合点与供给器再暂存、knowledge 候选"
git log --oneline -1; git status --short | head -5
```

## 七、回传里要有的

1. 每步退出码与用时；第二节沙箱构建的用时和日志文件名。
2. 第二节的锁 diff；第三节供给器 `SANDBOX_IMAGE` 的新旧两行。
3. 第四节的密文核对、两段 diff 摘录。
4. 第五节五个计划的结论行。
5. 结论：通过 / 不通过 / 判断不了。
