# Cursor 发布卡：会合点补上 `/service` 服务流（卡 42 说「会合点另开卡」，一直没开）

```text
被测仓：k8s，**qwen 工作树 `~/worktrees/qwen/k8s`，分支 qwen**
跑：按编号步骤做（核对现网 → 改源码锁 → 构建 → 暂存 → 提交 → 发布晋级 → 检查 → 回传）
仓与提交：会合点源码 k8s 4028d32de4801ef958806962c72502da0135a744（relay.py 加 /service；之后会合点源码没再变）
          投资应用、知识服务、沙箱、供给器都不动
预计：20–30 分钟；只重建会合点一个镜像；一次现网变更；没有迁移、config 不动；
      **会合点重启时，已连上的电脑和沙箱会断开、自动重连（约 1 分钟）**
看什么：现网 relay.py 的 sha256 先对上 1dfe7ff4…；只有会合点的 image.lock 变（source_revision = 4028d32d…）；
        换新后 relay.py 的 sha256 = cd42e245…；platform-check 0；用户那台电脑重连后服务流问得通
前提：所有者已通知执行；**页面上没有在跑的专家任务、没有正在干活的对话**（会合点一重启，正在跑的一轮会断）；
      已跑过 WS=qwen 的同步，~/worktrees/qwen/k8s 在 qwen 且干净、含本卡；platform-status 0；Harbor 在；不碰旧 kind；不退回
      与卡 45 互不依赖，先后都行；同一个维护窗口里跑最好
回传：k8s/scripts/results/relay-service-cursor.<时间>.md，最后一行 exit=<码>；本地提交，不 push
```

## 这一轮是什么

工作台问用户电脑上的代理「成稿文件在不在」，走的是会合点的 `/service` 服务流（0022 段 0、段 4，账 87）。代码早就有了：后端（卡 42 已发）、代理 0.4.0（卡 42 已发，会报 `service-v1` 能力）、会合点 `relay.py`（k8s `4028d32d`）。卡 42 写明「会合点镜像本卡不发，另开卡」，但后来没人开。所以现网会合点没有这条路，后端去问时收到 `1008 unknown path`，成稿检查一直只能走软检查。10-14 本地核查实测到了这一点：`step/deliverable` 记的是 `seen=false, checked=events`。

**现网到底是哪一版**：现网会合点镜像的锁写着 `source_revision 4d0ff043…`。那是 10-08 luna 工作树上的提交（luna stage-2 卡），后来被改写，任何分支里都找不到了。时间上它夹在 `1d01771f`（10-08 21:20，会合点源码最后一次改动，加权限回执）和 `7e1cb283`（21:40，发布）之间，内容应该就是 `1d01771f`。第一步先在集群里核对这个判断：现网 `relay.py` 的 sha256 应该等于 `1d01771f` 那份。对上了，这次的变化就只有 `4028d32d` 一个提交。

**`4028d32d` 改了什么**（Opus 在远程逐行看过；会合点测试 47 个全过）：
- 只新增，不改旧路：`/agent`、`/agent-data`、`/sandbox`、`/admin` 的行为不变。
- 新增 `/service`：工作台身份来连，配到同一用户的代理，要求代理自报 `service-v1`；每个用户最多 2 条，单帧不超过 1 MiB。
- 代理在线清单多一个 `capabilities` 字段。
- Dockerfile、依赖、`permission_reports.py` 都没变。

**另一个附带的坑**：`component-images.yaml` 里会合点的源码锁还钉在 `4d0ff043…`，而构建链要求「HEAD 是它的后代」。所以眼下谁在 qwen 或 fable 上重建会合点都会失败，这张卡顺手把它改到 `4028d32d`。

**停下的规则**：任何一步退出码不是 0，或者「要看到」的对不上，就停在那一步，把输出贴进回传，不做退回。

## 一、核对现网（只读）

```bash
cd ~/worktrees/qwen/k8s && git branch --show-current && git log --oneline -1 && git status --short | head -5
git cat-file -t 4028d32de4801ef958806962c72502da0135a744 && git merge-base --is-ancestor 4028d32d HEAD; echo "descendant=$?"
grep -n "relay:" -A4 infrastructure/applications/component-images.yaml
cat gitops/components/relay-platform/relay/image.lock.yaml | grep -E "digest|source_revision"
export KUBECONFIG=~/.kube/sunmoon-kind.config; K=$(command -v kubectl || echo infrastructure/.tools/bin/kubectl)
$K -n relay-platform-dev get pods -o wide | grep relay
$K -n relay-platform-dev exec deploy/relay -- sha256sum /opt/relay/relay.py /opt/relay/permission_reports.py
make -C infrastructure platform-status; echo "exit=$?"
```

要看到：`qwen`；干净；`descendant=0`；锁现在是 `4d0ff043…`、摘要 `sha256:04421137…`；现网两份文件的 sha256：

- `relay.py` = `1dfe7ff41c9f6422a6c0ef5586deed7b63755b0d51dd9e04446ef0439078012d`（即 `1d01771f` 那份）
- `permission_reports.py` = `d223ea71c51b565007beb0edd4214ebf7bc967d6e72a726e7d7e85a589f7933f`

**`relay.py` 对不上就停**：说明现网跑的东西和我们以为的不一样，把两行 sha256 贴回来，由 Opus 判断。另外记下顺手查的：`git -C ~/worktrees/luna/k8s cat-file -t 4d0ff043 2>&1`（本地机上那个提交还在不在，在不在都照实写）。

## 二、改会合点源码锁（只动一行）

```bash
sed -i 's/^\(    revision: \)4d0ff0433628b8e821ca6239eebd8cf46f0a4fe3$/\14028d32de4801ef958806962c72502da0135a744/' infrastructure/applications/component-images.yaml
git diff infrastructure/applications/component-images.yaml | grep "^[-+]" | grep -v "^+++\|^---"
```

要看到：只有 `relay:` 下面那一行 `revision` 从 `4d0ff043…` 变成 `4028d32d…`，sandbox、供给器的锁不变。

## 三、构建、暂存

```bash
make -C infrastructure platform-build OBJECT=relay-platform/relay 2>&1 | tail -n 12; echo "exit=${PIPESTATUS[0]}"
git diff gitops/components/relay-platform/relay/image.lock.yaml | grep -E '^[-+].*(digest|source_revision)'
make -C infrastructure platform-stage OBJECT=relay-platform/relay; echo "exit=$?"
git status --short gitops/ infrastructure/ | head -10
grep -rn "BEGIN PRIVATE KEY\|BEGIN PUBLIC KEY" gitops/ | head -3   # 必须没有
git diff gitops/components/relay-platform/relay/workload.yaml | grep -E '^[-+]' | grep -v "^+++\|^---" | head -8
```

要看到：两个退出 0；会合点锁的 `source_revision` = `4028d32d…`、摘要换新；改动只有 `component-images.yaml`、会合点的 `image.lock.yaml` 和 `workload.yaml`（只有镜像摘要那一行变）；没有 PEM；没有 sops 文件只因重新加密而变。

## 四、提交、发布、晋级、检查

```bash
git add infrastructure/applications/component-images.yaml gitops/components/relay-platform/relay
git -c core.editor=true commit -m "deploy(relay): 会合点补上 /service 服务流，源码锁 4d0ff04 → 4028d32d（待办 46）"
make -C infrastructure flux-release; echo "exit=$?"
sudo cat infrastructure/.build/flux/source-candidate.yaml; git rev-parse HEAD
sudo cat infrastructure/.build/flux/source-candidate.yaml | sudo tee infrastructure/environments/kind/flux-source.yaml >/dev/null
sudo chown "$(id -u):$(id -g)" infrastructure/environments/kind/flux-source.yaml 2>/dev/null; git diff infrastructure/environments/kind/flux-source.yaml
git add infrastructure/environments/kind/flux-source.yaml && git -c core.editor=true commit -m "release(kind): 晋级到 $(git rev-parse --short HEAD)（待办 46）"
make -C infrastructure flux-source-apply; echo "exit=$?"
make -C infrastructure flux-source-status; echo "exit=$?"
make -C infrastructure platform-check OBJECT=relay-platform/relay; echo "exit=$?"
make -C infrastructure application-check APP=investment; echo "exit=$?"
$K -n relay-platform-dev get pods | grep relay
$K -n relay-platform-dev exec deploy/relay -- sha256sum /opt/relay/relay.py
sleep 60; $K -n relay-platform-dev logs deploy/relay --since=3m | grep -E "agent up|welcome|hello|service" | grep -v -i "token" | tail -8
```

要看到：候选 `revision` = 提交后 HEAD；四次退出 0；会合点是新 Pod、Running；`relay.py` 的 sha256 = `cd42e245039628a61add166e24a570efff93714ed3468f0f6ac4de9137a21ef0`；一分钟内日志里有用户那台电脑的代理重新连上（日志里出现令牌样的长串就不要贴）。

## 验收

- 源码锁与镜像锁都是 `4028d32d…`；现网 `relay.py` = `cd42e245…`；`platform-check`、`application-check` 都是 0。
- **真人验收由所有者做，不在本卡**：
  1. 托盘里那台电脑显示已连接（会合点重启后它自己会重连；一分钟后还没连上，就点托盘「重新连接账号」）。
  2. 登录投资站点后，在浏览器地址栏打开 `/api/workbench/environments`，找到那台电脑的 `id`，再打开 `/api/workbench/environments/<id>/service`：回一段 JSON（代理的 `service/hello` 回答）就是服务流通了；回 `agent_outdated` 说明代理没报 `service-v1`（要 0.4.0）；回 `agent_service_failed` 就把原文贴给 Opus。
  3. 之后请专家时，成稿那一步的检查才真正生效：Codex 没报写文件的，工作台会去电脑上问文件在不在，不在就判验收不过（不再只记一条事件放过去）。

## 失败回退与交回

任一步失败停在原步，保留错误输出与候选。需恢复时把 `component-images.yaml` 那一行改回 `4d0ff043…`，**并把 `image.lock.yaml` 改回旧摘要 `sha256:04421137f2a2fb2bf07b3bb20c582c6a83626e5a438c8b7708eee98add913672`**（4d0ff043 不在仓里，不能重建，只能用旧摘要），再重走暂存到晋级。报告写 `k8s/scripts/results/relay-service-cursor.<时间>.md`，最后一行 `exit=<码>`；本地提交，不 push、不移动本待办。
