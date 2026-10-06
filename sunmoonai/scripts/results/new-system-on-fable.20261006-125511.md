# 待办 18：fable 工位走新体系

- 工位：`~/worktrees/fable/k8s`
- 分支：`fable`
- HEAD：`3e067706`
- 时间：2026-10-06 12:55 +0800
- 结论：**不通过**。工具已装上，`platform-plan OBJECT=all` 退出 0。`preflight` 和 `platform-status` 退出 2。现网 API、Harbor、入口都没在听，节点和仓库容器都是退出状态，所以 CHECKPOINT「已完成的运行状态」里的节点 / Pod / 阶段 / PV 数字这次对不上，也读不到 relay 镜像标签。没有改产品代码，没有 stage / deploy / flux-release，没有 push。

## 一、装工具

在 `~/worktrees/fable/k8s` 执行，全部退出 0，用的是工位里已有的锁和物料，没有再下载：

- `make -C infrastructure tools`
- `make -C infrastructure install-binaries BINARIES=kind,kubectl,kubeadm`
- `make -C infrastructure install-flux`
- `make -C infrastructure install-secrets-tools`
- `make -C infrastructure services-tools`

`infrastructure/.tools/bin` 里有 age、age-keygen、flux、helm、kind、kubeadm、kubectl、sops。`kubectl version --client` 为 v1.36.5，Kustomize v5.8.1。磁盘：`.venv` 37M，`.tools` 481M。

## 二、只读入口

| 命令 | 退出码 |
| --- | --- |
| `make -C infrastructure help` | 0 |
| `make -C infrastructure config` | 0 |
| `make -C infrastructure preflight` | 2 |

`preflight` 在核对 `/data/kind-clusters`、`/data/harbor` 时失败。`findmnt` 把这两个路径解析到根文件系统 `/`（`/dev/sdd`，uuid `693faed3-cebb-473e-81ae-fd88f1fc76b4`），断言要求的独立挂载点不成立。当时只有数据盘本身还挂着：

```
TARGET            SOURCE   FSTYPE OPTIONS
/mnt/sunmoon-data /dev/sde ext4   rw,relatime
```

`/data/kind-clusters` 和 `/data/harbor` 没有出现在 `findmnt` 结果里。PLAY RECAP：`ok=2 changed=0 unreachable=0 failed=1`。`make: *** [Makefile:107: preflight] Error 2`。

## 三、现网

| 命令 | 退出码 |
| --- | --- |
| `make -C infrastructure platform-plan OBJECT=all` | 0 |
| `make -C infrastructure platform-status OBJECT=all` | 2 |
| `infrastructure/.tools/bin/kubectl get nodes` | 1 |
| `infrastructure/.tools/bin/kubectl get kustomizations -A --no-headers` | 1 |
| Running Pod 计数 | 无法取得，命令退出 1，计数写成 0 |
| PV 计数 | 无法取得，命令退出 1，计数写成 0 |
| Flux Kustomization 计数 | 无法取得，命令退出 1，计数写成 0 |

`platform-plan` 选出整套对象，`blocked_dependencies` 为空。`platform-status` 停在「Read actual selected Flux stages without repairing or starting anything」：kubectl 访问 `https://127.0.0.1:27443` 被拒绝。PLAY RECAP：`ok=5 changed=0 unreachable=0 failed=1 skipped=2`。`make: *** [Makefile:419: platform-status] Error 2`。后面的 `kubectl get` 都是同一句：`dial tcp 127.0.0.1:27443: connect: connection refused`。`ss` 看不到 27443 在听。

容器状态（只读 `docker ps -a`，没有启动任何容器）：

- `sunmoon-kind-control-plane`、`sunmoon-kind-worker`、`sunmoon-kind-worker2`：Exited (255)，约 4 小时前
- `kind-control-plane`：Exited (137)，约 3 天前
- `kind-worker`、`kind-worker2`：Exited (255)，约 4 小时前
- `sunmoon-entry-proxy-1` 以及全部 `sunmoon-registry-*`：Exited (255)，约 4 小时前
- `kind get clusters` 仍列出 `kind` 和 `sunmoon-kind`，集群定义还在，进程不在

CHECKPOINT「已完成的运行状态」写的是：新三节点 Ready；旧 kind 控制面停、两个 worker 运行；57 个 Running Pod；51 个 Flux 阶段 Ready；13 组 PV Bound/Retain。这次三个计数都拿不到。对照结果是现网没在跑，不是数字变成 0。

## 四、relay 镜像

`gitops/components/relay-platform/relay/image.lock.yaml` 钉的是：

`harbor.sunmoonai.com:30443/app-images/relay@sha256:dfc4d0e08fc83f846ceb1d3024a7f944b688f1283f886a89fb0c8c5b0702b647`

`docker pull` 退出 1：`dial tcp 127.0.0.1:30443: connect: connection refused`。本机没有这份镜像，`docker image inspect` 也是 No such image。镜像创建时间、标签、镜像内 `relay.py` 的哈希都没有读到，不能和源码或 `ff71c76a` 比较。没有改 lock。

工位里源码 `sunmoonai/relay-platform/relay/relay.py` 的 sha256 是 `550019baa1a677a3a10c0ca3878384ac294d85627fe6381e049af10675ac6d62`。这只是文件哈希，不是镜像摘要。

## 五、判断

新体系的本机入口能在 fable 工位装起来，只读计划能跑通。验收要求的 `preflight` 和现网状态没有退出 0，因为数据盘的两个 bind 不在，集群、Harbor、入口容器都已退出。这不是这次改代码能修的，也没有修。

## 六、接手说明

1. A 段离线工作已经在 workstation `platform-kind-v1` 提交为 `fb55eced`（`refactor: publish the component renderer and added platform contracts`），并推到各仓的 `platform-kind-v1` 分支。当时还没做完的：聚合源清理、入口收敛、这次重构的 `flux-release` / 晋级 / 部署、`make ci`、环境参数化。Traefik 全量重渲染依赖 `services-chart`，那一轮没有跑。
2. `~/worktrees/platform-kind-v1/k8s` 唯一未提交文件是 `密码修改表.md`。内容不能进 Git，也不能写进回传。同目录 `infrastructure/.build/components/` 里有渲染候选。`infrastructure/.build/flux/source-candidate.yaml` 仍是 digest `sha256:e26d2a19932686a64a7226cbf64666c457d797450fdf92f462b184a1ca7a2aef`、revision `e59bdc006a2eaca8c7b3af367ad7e801a6136547`，和已晋级指针相同，不是 `fb55eced` 之后新打出来的发布候选。
3. fable 工位 `infrastructure/environments/kind/flux-source.yaml` 也是上述 revision 和 digest。当前 HEAD 是 `3e067706`。现网 API 连不上，没有跑 `validate-release`。指针和当前 Git 不是同一次提交，集群起来之后也不要直接 `platform-deploy` 这次重构。
4. 旧 kind 没有删除。控制面 `kind-control-plane` 已退出约 3 天；两个 worker 和入口容器 `sunmoon-entry-proxy-1` 约 4 小时前退出。未知域名现在没有在转发。旧物料根仍只作参照。
5. 冷建约定还没做，也不要在这次待办里做：新集群名 `sunmoonai-kind`；首次初始化读密码表预设；不要先把这次重构部署到 `sunmoon-kind`；命名空间按 `*-platform-dev`；`30443` / `29443` / `27443` 是当前 KIND 事实，参数化留到后面。
6. 接手时容易踩的地方：`services-stage` 这个 Make 名字还在，实际和 `platform-stage` 走同一个组件渲染器；已有拉取密钥如果被 foundations prepare 重加密，要按等载荷把原来的密文恢复回去；晋级时 revision 必须是 OCI 包对应的 Git SHA，不是改指针那次提交；`密码修改表.md` 不能提交、不能推送；fable 检查点后文提到的 Jenkins / Argo 和本机这次对话的结论不一致，本机结论是先不引入 Jenkins、先留 Flux，不要把那两句当成已经开工的迁移。
