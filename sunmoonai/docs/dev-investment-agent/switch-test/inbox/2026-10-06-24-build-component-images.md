# 新体系：按 fable 源码构建会合点、沙箱、供给器三个镜像，暂存它们的候选（本地机；在 23 之后做）

```text
被测仓：k8s，本地路径 ~/worktrees/fable/k8s
跑：按编号步骤做（核对 → 构建发布三个镜像 → 暂存 relay 与供给器 → 本地提交）
仓与提交：k8s 本条待办所在的 fable 头（含 component-images.yaml 钉的提交 b23ea80b 及其后的构建链改动）
预计：40 分钟；三次在线构建；不停服；不碰现网
看什么：三次构建退出 0；三个 image.lock.yaml 改成 platform/<名字> 的新摘要；relay 的 auth.sops.yaml 多了验签公钥（密文）；供给器候选的 env 里有 APP_NAMESPACE / RELAY_NAMESPACE
前提：Harbor 在；不 flux-release、不晋级、不 deploy。**供给器开关这次已打开**（它的平台级输入要靠它自己的 prepare 生成，investment 的暂存要读；镜像在本待办里先重建）
回传：k8s/sunmoonai/scripts/results/build-component-images.<时间>.md
```

## 这一轮是什么

0010 第 4 步：会合点、沙箱、供给器三个自研镜像第一次走新体系的构建链（源码在本仓 `sunmoonai/` 的三个目录，钉本仓提交）。供给器这次改成按环境参数化、拉起的沙箱满足 restricted PSS；沙箱入口关了子代理和「目标」、接上工作台的记录工具服务；relay 多了验签公钥。镜像发到 Harbor 的 `platform/`，锁改写进 `gitops/`。供给器开关已在配置里打开（23c 发现它关着时平台级输入 `sandbox-provisioner.yaml` 生成不出来，investment 暂存卡住），所以这轮它进阶段图：先构建新镜像，再暂存。

## 一、核对

```bash
cd ~/worktrees/fable/k8s && git log --oneline -1 && git status --short | head -5
grep -n "revision:" infrastructure/applications/component-images.yaml
git merge-base --is-ancestor $(grep '^revision:' infrastructure/applications/component-images.yaml | awk '{print $2}') HEAD && echo "pin is ancestor: ok"
make -C infrastructure platform-plan OBJECT=relay-platform/relay; echo "exit=$?"
```

工作区要干净。

## 二、构建并发布三个镜像

```bash
for o in relay-platform/relay sandbox-platform/sandbox sandbox-platform/provisioner; do
  echo "=== $o $(date +%T)"; make -C infrastructure platform-build OBJECT=$o; echo "exit=$? $(date +%T)"
done
git status --short gitops/components/relay-platform gitops/components/sandbox-platform
for f in gitops/components/relay-platform/relay/image.lock.yaml gitops/components/sandbox-platform/sandbox/image.lock.yaml gitops/components/sandbox-platform/provisioner/image.lock.yaml; do echo "== $f"; grep -vE '^#' $f; done
```

某个退出不是 0：贴 `.build/applications/<名字>-build.log` 的最后 60 行（去口令）和 Ansible 的失败任务名，其余继续。通过的样子：三个锁都没有 `harbor_project` 行（默认 platform），`digest` 是新的，`source_revision` 等于清单钉的提交。

沙箱镜像基底从 alpine 换成了 Debian trixie-slim，第一次构建要装 apt 包；慢是正常的，失败贴日志。

## 三、暂存 relay 与供给器的候选

```bash
make -C infrastructure platform-stage OBJECT=relay-platform/relay; echo "exit=$?"
make -C infrastructure platform-stage OBJECT=sandbox-platform/provisioner; echo "exit=$?"
git status --short gitops/components/relay-platform gitops/components/sandbox-platform
grep -c 'ENC\[' gitops/components/relay-platform/relay/auth.sops.yaml
git diff gitops/components/relay-platform/relay/workload.yaml | grep '^[-+]' | grep -vE '^(\+\+\+|---)' | head -20
git diff gitops/components/sandbox-platform/provisioner/workload.yaml | grep '^[-+]' | grep -vE '^(\+\+\+|---)' | head -20
sudo ls -la /etc/sunmoon/services/sunmoon-kind/workbench-signing.yaml 2>&1 | sed 's/ [0-9]* [A-Z][a-z]* .*//'
```

relay 的改动应只有镜像行和一个 `RELAY_JWT_PUBLIC_KEY` 的 env；供给器是新进阶段图的（`gitops/clusters/kind/stages.yaml` 多一个 `sandbox-provisioner` 阶段），它的 `workload.yaml`、`auth.sops.yaml` 是新文件。暂存完再查一次 `sudo find /etc/sunmoon -maxdepth 3 -name sandbox-provisioner.yaml`，这次应该在。

## 四、本地提交

```bash
git add gitops/components/relay-platform gitops/components/sandbox-platform gitops/clusters
git -c core.editor=true commit -m "test(local): 待办 24 构建三个自研镜像并暂存 relay、供给器"
git log --oneline -1
```

## 五、回传里要有的

1. 三次构建的退出码、用时、新 digest 前 12 位；失败的日志尾部。
2. 第三节的两段 diff 和密文计数。
3. 结论：通过 / 不通过 / 判断不了。
