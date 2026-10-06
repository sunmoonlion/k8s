# 新体系搬到 fable 工位：把工具装起来，只读地把链路走一遍（本地机）

```text
被测仓：k8s，本地路径 ~/worktrees/fable/k8s（新体系 infrastructure/、gitops/ 已从 platform-kind-v1 合进 fable，内容逐字相同）
跑：按下面编号步骤做（装工具 → 只读入口 → 现网只读状态 → 查 relay 镜像的来历 → 写一段接手说明）
仓与提交：k8s 本条待办所在的 fable 头；四个应用父仓 fable 头（tpl 6579f30、info 6729dd0、investment 8bb0a42、knowledge 116930f）
预计：30 分钟；要 WSL、Docker、Harbor 在跑、sunmoon-kind 在跑；不需要停服，不需要维护窗口
看什么：第 2 步 help/config/preflight 退出 0；第 3 步 platform-plan/status 退出 0 且 status 看到的阶段数、Pod 数和 CHECKPOINT.md「已完成的运行状态」一致；第 4 步 relay 镜像的标签里有没有源码提交号
前提：luna 的工位 ~/worktrees/platform-kind-v1 保持原样不动；新体系的私有输入（/etc/sunmoon/…、/mnt/sunmoon-data/backups/…）和 root 副本 /opt/sunmoon/host/sunmoon-kind 不依赖工位目录，按 CHECKPOINT.md 的说法可以直接用
回传：k8s/sunmoonai/scripts/results/new-system-on-fable.<时间>.md（写下后在被测仓提交；每条命令写退出码；口令、令牌一律不贴）
```

## 为什么有这一轮

新体系的代码在 luna 的 `platform-kind-v1` 分支上做出来，2026-10-06 合进了 `fable`。以后的改动都在 `fable` 上做、在 `fable` 工位上跑。这一轮只证明一件事：**从 fable 工位能把新体系的入口跑起来，看到的现网状态和 luna 记的一样**。不改配置、不部署、不发布、不晋级。

## 一、装工具（只装进 fable 工位，不碰全局）

新工位没有 `infrastructure/.venv`、`.tools`。按 `infrastructure/tools/README.md`：

```bash
cd ~/worktrees/fable/k8s
git log --oneline -1                       # 记下提交号
make -C infrastructure tools
make -C infrastructure install-binaries BINARIES=kind,kubectl,kubeadm
make -C infrastructure install-flux
make -C infrastructure install-secrets-tools
make -C infrastructure services-tools
ls infrastructure/.tools/bin
infrastructure/.tools/bin/kubectl version --client
```

每条命令记退出码。哪一条失败就停下，把它的完整输出写进回传（去掉口令），后面的不做。工具物料在 `~/k8s-packages`，缺了就写明缺什么，不要联网另下。

## 二、只读入口

```bash
make -C infrastructure help
make -C infrastructure config
make -C infrastructure preflight
```

`preflight` 只读核验宿主挂载。三条都要退出 0。

## 三、现网只读状态

```bash
make -C infrastructure platform-plan OBJECT=all
make -C infrastructure platform-status OBJECT=all
export KUBECONFIG=~/.kube/sunmoon-kind.config
infrastructure/.tools/bin/kubectl get nodes
infrastructure/.tools/bin/kubectl get kustomizations -A --no-headers | wc -l
infrastructure/.tools/bin/kubectl get pods -A --field-selector=status.phase=Running --no-headers | wc -l
infrastructure/.tools/bin/kubectl get pv --no-headers | wc -l
```

把 status 的输出整段放进回传（去掉口令）。节点、阶段、Pod、PV 的数量和 `CHECKPOINT.md`「已完成的运行状态」对一下，不一样就写明哪里不一样，不要去改。

**不要跑** `platform-check`、`platform-stage`、`platform-deploy`、`flux-release`、任何 `account-*`：这一轮不要写入。

## 四、relay 镜像是从哪次提交构建的

新体系钉的 relay 镜像是旧 KIND 的 `app-images/relay@sha256:dfc4d0e0…`（`gitops/components/relay-platform/relay/image.lock.yaml`）。要知道它是不是 fable 上现在这份 `sunmoonai/relay-platform/relay/relay.py` 构建的：

```bash
D=$(grep '^digest:' gitops/components/relay-platform/relay/image.lock.yaml | awk '{print $2}')
docker pull harbor.sunmoonai.com:30443/app-images/relay@$D
docker inspect --format '{{json .Config.Labels}}' harbor.sunmoonai.com:30443/app-images/relay@$D
docker inspect --format '{{.Created}}' harbor.sunmoonai.com:30443/app-images/relay@$D
docker run --rm --entrypoint sh harbor.sunmoonai.com:30443/app-images/relay@$D -c 'sha256sum /app/relay.py 2>/dev/null || find / -name relay.py -not -path "*/site-packages/*" 2>/dev/null | head -3'
sha256sum ~/worktrees/fable/k8s/sunmoonai/relay-platform/relay/relay.py
```

通过：镜像里 `relay.py` 的 sha256 和工位里的一致，或者标签里的提交号是 fable 上 `ff71c76a` 或它之后的。不一致也不要改，写下两个值就行。

## 五、回传里要有的

1. 每一步的命令、退出码；失败的那一步的完整输出。
2. `platform-status OBJECT=all` 的整段输出。
3. 四个数量（节点、阶段、Running Pod、PV）和 CHECKPOINT.md 的对照。
4. relay 镜像的标签、创建时间、`relay.py` 两个 sha256。
5. 装工具一共用了多少磁盘（`du -sh infrastructure/.venv infrastructure/.tools`）。

结论只写「通过 / 不通过 / 判断不了」，三种之一。

## 六、接手说明（本地助手自己写，放在回传的最后）

所有者说明：新体系后半段的重构（`CHECKPOINT.md`「重构检查点（接手后，2026-10-05起）」以后的部分）是本地助手做的，远程只读过文档。所以请本地助手把**文档里没写、只在你脑子里或只在本地工位里的事**写下来，远程接着开发时照它做：

1. 没做完的事：A 段「离线收口」里哪些做了一半（检查点提到「聚合源码清理、入口收敛未做」），各停在哪个文件、哪一步。
2. 只在本地、没进 Git 的东西：`~/worktrees/platform-kind-v1/k8s` 里没提交的改动（`git status --short` 整段贴上，口令不贴）、`infrastructure/.build/` 里现在有哪些候选、`.build/flux/source-candidate.yaml` 的内容（摘要和修订号）。
3. 现网 `sunmoon-kind` 的工作区 `gitops/` 和已晋级对象是不是一致（`validate-release` 现在会不会拒绝 `platform-deploy`）；不一致的话差在哪些文件。
4. 原始旧 kind 集群现在的状态：停着还是删了，哪些东西还引用它（入口的默认后端、旧 Harbor、旧物料根）。
5. 冷建 `sunmoonai-kind` 时定过但没写进文档的决定，例如命名空间、入口端口、存储路径。
6. 你认为远程接手后最容易踩的三个坑。

写成一段 Markdown，放在回传文件最后一节「接手说明」里。不用改代码，不用改文档。

