# knowlab-app 与 knowmart-app 开工：建仓、实例化、跑通空应用

> **状态：所有者 2026-10-16 批准（「批准」），下面「要所有者先定的」四项按默认。**A 段过（`scripts/results/qwen-003-A.*`，gitee 空仓不能公开，暂私有）；B 段过（`scripts/results/opus-003-B.*`，顺带修好了 tpl-app 的 `init.sh`）。gitee 8 个仓已改公开（匿名 ls-remote 能取到提交号）；C 段过（`scripts/results/opus-003-C.*`）。**现在做 D 段。** Opus 2026-10-16 在远程机写。设计：[0026 knowlab](../../../design/SDD/modules/0026-knowlab.md)、[0018 knowmart](../../../design/SDD/modules/0018-advisor-market.md)（私有模式）。本卡只做到「两个空应用在本地集群跑起来、能登录」，不写任何业务功能。
>
> 分四段，一段一停：A（Qwen 建远端仓）→ B（Opus 实例化并推代码）→ C（Opus 写部署声明、改各处仓清单）→ D（Qwen 在本地集群发布并在浏览器核对）。每段交回执，Opus 审过再开下一段。A、D 两段 Qwen 做；B、C 两段 Opus 做，这里写出来是让所有者一次看全。

## 要所有者先定的（批准时一起答）

| 项 | 默认 | 说明 |
| --- | --- | --- |
| 仓的可见性 | **公开**，与现有各仓一致（GitHub、gitee 上 tpl-app、knowfeed-*、k8s 等都是公开的） | 要私有就说一声，A 段按私有建 |
| gitee 镜像 | 8 个仓都建（同 knowfeed、knowbase 的父仓与子仓） | |
| 对外域名 | 先**不上公网边缘**，和 knowfeed、knowbase 一样只在所有者机器上可用：`knowlab.sunmoonai.com`、`knowlab-admin.sunmoonai.com`、`knowmart.sunmoonai.com`、`knowmart-admin.sunmoonai.com` | knowlab 要给外部用户用时，另开一张卡把它加到边缘 |
| knowmart 的界面叫法 | 「我的分身」，不出现「市场」「上架」「购买」「价格」（`C-L4`、`C-L5`） | 本卡只建空壳，叫法在后面的功能卡里落实 |

## A 段（Qwen，本地机）：建 8 个远端仓

在 GitHub 组织 `sunmoonlion` 与 gitee `sunmoonlion` 下各建 8 个**空仓**（不要勾选 README、.gitignore、LICENSE，否则 B 段推送会冲突）：

```text
knowlab-app   knowlab-backend   knowlab-web-frontend   knowlab-admin-frontend
knowmart-app  knowmart-backend  knowmart-web-frontend  knowmart-admin-frontend
```

用 R2 改名时那套权限（GitHub 组织管理员、gitee API 令牌）。**令牌不进回执、不进 git、不进日志。**

- 被测仓：无（只动远端）
- 跑：用 `gh repo create sunmoonlion/<名> --public`（可见性按上表）与 gitee API 逐个建；建完 `git ls-remote https://github.com/sunmoonlion/<名>.git`、`git ls-remote https://gitee.com/sunmoonlion/<名>.git` 逐个核：能连上、没有任何引用（空仓）
- 预计：15 分钟；要联网
- 看什么：16 个地址都存在且为空；任何一个已存在且非空就停，不覆盖
- 前提：所有者批准本卡
- 回传：`k8s/scripts/results/qwen-003-A.<时间>.md`（每个仓一行：平台、名字、可见性、`ls-remote` 是否为空）

## B 段（Opus，远程机）：实例化并推代码

1. 在临时目录各克隆一份 tpl-app（连子仓），按 `tpl-app/init.sh` 实例化成 `knowlab`、`knowmart`；先在临时目录跑通各后端测试与前端构建检查。
2. 推送：三个子仓先、父仓后，`master` 分支；推送地址 GitHub + gitee 两个（同 knowfeed 子仓）。
3. 两个应用的 `AGENTS.md`、`CLAUDE.md` 指向 k8s 的现行文档，README 写明定位（knowlab：用户的 idea 与数据做成分身；knowmart：分身的存放与「请」，私有模式）。
4. 回执 `k8s/scripts/results/opus-003-B.<时间>.md`。

## C 段（Opus，远程机）：部署声明与各处仓清单

1. `k8s/gitops/components/app-platform/knowlab-app/`、`knowmart-app/`：照 tpl-app 的组件（`database`、`migration`、`redis`、`rabbitmq`、`identity`、`runtime`、前后端），共用 `app-platform/common/`；`infrastructure/applications/sources.yaml` 加两个应用的钉；Casdoor 两套浏览器应用（管理端 `built-in`、网页端 `sunmoonai`）。
2. 渲染比对：除新增的两个应用，现有对象**一个都不变**（同改名时的比对方法，Git 历史 `3951246c:docs/rename-tools/r5_render_diff.py`）。
3. 各处写死的仓清单加上两个新仓：同步脚本 `switch-test/human-local.sh`、`human-remote.sh` 的父仓与子仓列表，对齐工具 `docs/process/switch-test/align_workstations.sh` 的 `REPOS`。两台机器上不在 Git 里的配置由所有者自己加：`~/five-repos-sync/config.sh` 的 `REPOS`，`toolboxes` 里 `model-switch/repos.conf`（`mb` 注册仓）。
4. 两台机器五个工位挂出两个新仓（`mb worktree add`，子仓初始化）。
5. 回执 `k8s/scripts/results/opus-003-C.<时间>.md`。

## D 段（Qwen，本地机）：发布与浏览器核对

必须用 bash。每一步出 `exit` 不为 0、`STOP`、或与「要看到」不符就停，把输出原样交上来，不修、不重跑。命令里不贴口令与令牌。

**D0 前提**（所有者先做）：两台机器上，`toolboxes` 的 `Vlinux/utils/set-up-tools/model-switch/repos.conf` 末尾加两行 `$HOME/master/knowlab-app`、`$HOME/master/knowmart-app`；`~/five-repos-sync/config.sh` 的 `REPOS=( … )` 里加 `"knowlab-app"`、`"knowmart-app"`。远程机的两个新仓 Opus 已挂好。

**D1 本地机挂上两个新仓**（布局同 `mb`：`~/master/<仓>` 在 master，五个工位各一个同名分支，子仓推送地址 GitHub + gitee；本地机连不上 GitHub 的 SSH，地址一律用 https，和现有各仓一样）：

```bash
for a in knowlab knowmart; do
  M=~/master/$a-app; [ -e "$M" ] && { echo "STOP $M 已存在"; break; }
  git clone -q --recurse-submodules https://github.com/sunmoonlion/$a-app.git "$M" || { echo "STOP clone $a"; break; }
  sp() { git -C "$1" config --unset-all remote.origin.pushurl 2>/dev/null; git -C "$1" config --add remote.origin.pushurl https://github.com/sunmoonlion/$2.git; git -C "$1" config --add remote.origin.pushurl https://gitee.com/sunmoonlion/$2.git; }
  sp "$M" $a-app
  for c in backend web-frontend admin-frontend; do git -C "$M/$a-$c" checkout -q -B master; git -C "$M/$a-$c" remote set-url origin https://github.com/sunmoonlion/$a-$c.git; sp "$M/$a-$c" $a-$c; done
  for ws in cursor fable kimi luna qwen; do
    W=~/worktrees/$ws/$a-app; [ -e "$W" ] && { echo "STOP $W 已存在"; continue; }
    git -C "$M" worktree add -q -b $ws "$W" master && git -C "$W" submodule update --init -q
    for c in backend web-frontend admin-frontend; do git -C "$W/$a-$c" checkout -q -B $ws; git -C "$W/$a-$c" remote set-url origin https://github.com/sunmoonlion/$a-$c.git; sp "$W/$a-$c" $a-$c; done
    echo "mounted $ws/$a-app $(git -C "$W" rev-parse --short HEAD)"
  done
done
cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen && git log --oneline -1
bash docs/process/switch-test/align_workstations.sh list 2>&1 | grep -E 'know(lab|mart)' | grep -v ' ok ' ; echo list-done
```

要看到：10 行 `mounted`（两个应用 × 五个工位）；最后除了 `list-done` 没有别的行。

**D2 现有应用一个都不变**（同改名时的验法：重新 stage 现有应用，`git status` 里它们的文件不该有任何变动；**不要跑 `platform-stage OBJECT=all`**，见待办账 97）：

```bash
cd ~/worktrees/qwen/k8s
make -C infrastructure topology-stage OBJECT=all; echo "topology exit=$?"
for o in app-platform/tpl-app app-platform/knowfeed-app app-platform/knowbase-app app-platform/investment-app; do
  echo "===== stage $o"; make -C infrastructure platform-stage OBJECT=$o; rc=$?; echo "exit=$rc"; [ "$rc" = 0 ] || break
done
git status --short gitops | awk '{print $2}' | sed -E 's#^gitops/(components/[^/]+/[^/]+(/[^/]+)?|clusters/kind)/.*#\1#' | sort | uniq -c
```

要看到：全是 `exit=0`；`git status` 只有 `clusters/kind`（`stages.yaml` 加了两个应用的阶段）与两个新应用目录，tpl、knowfeed、knowbase、investment **没有任何一行**。有就停。

第一次跑停在 `stages.py graph`（两个新后端少 `database`、`migration`、`redis` 三个目录，C 段漏交）；已补（各放一份说明，生成文件由 D3 的 stage 写进去），pull 后 D2 原样重跑。

第二次停在 tpl-app 的 stage 读 knowlab 的 `image.lock.yaml`。根因不是缺锁，是**本地机进了 nsenter 模式**（用户会话和 PID 1 的挂载命名空间不一致，Makefile 改用 `sudo … nsenter … sudo … ansible-playbook`），sudo 清空环境，`OBJECT` 没传进剧本，剧本按 `all` 跑了全部对象；「选择对象等于 OBJECT」的校验读到的是以前留下的旧选择文件，没拦住。已修：nsenter 命令显式带上剧本读的五个环境变量；选择前先删旧选择文件；剧本读不到 `OBJECT` 就停。pull 后先跑 D2-0 留证据，再原样从头重跑 D2。工作区里 topology 改的 `gitops/clusters/kind/stages.yaml` 不用动，D2 会再写一遍同样内容。

**D2-0 只读留证据**（不改任何东西）：

```bash
cd ~/worktrees/qwen/k8s
[ "$(readlink /proc/self/ns/mnt)" = "$(sudo -n readlink /proc/1/ns/mnt)" ] && echo "ns same" || echo "ns differ（nsenter 模式）"
ls -l --time-style=+%m-%d_%H:%M infrastructure/.build/host/selections/ | awk '{print $6, $7}'
make -n -C infrastructure platform-selection OBJECT=app-platform/tpl-app 2>/dev/null | grep -o 'OBJECT="$OBJECT"' | head -1; echo d2-0-done
```

要看到：第一行照实（预计 `ns differ`）；第二段是选择文件和时间，照抄；第三段在 `ns differ` 时应打印 `OBJECT="$OBJECT"`（`ns same` 时不打印，属正常）。

**D2b 待办 97 的修法实跑**（prepare 改为按阶段依赖排序；ragflow 单独 stage 时只读 valkey 已有的私有输入，不生成）：

```bash
cd ~/worktrees/qwen/k8s
make -C infrastructure platform-stage OBJECT=data-platform/ragflow; echo "ragflow exit=$?"
git status --short gitops/components/data-platform; echo status-done
```

要看到：`ragflow exit=0`（以前报 `'valkey_credentials' is undefined`）；`status-done` 前没有任何行（ragflow、valkey 的文件都不变）。有就停。

**D3 构建两个新应用并 stage**：

```bash
for o in app-platform/knowlab-app app-platform/knowmart-app; do
  echo "===== build $o"; make -C infrastructure platform-build OBJECT=$o 2>&1 | tail -n 12; rc=${PIPESTATUS[0]}; echo "exit=$rc"; [ "$rc" = 0 ] || break
done
for o in app-platform/knowlab-app app-platform/knowmart-app; do
  echo "===== stage $o"; make -C infrastructure platform-stage OBJECT=$o; rc=$?; echo "exit=$rc"; [ "$rc" = 0 ] || break
done
for a in knowlab knowmart; do make -C infrastructure application-deployment-plan APP=$a; echo "plan $a exit=$?"; done
git status --short gitops | awk '{print $2}' | sed -E 's#^gitops/(components/[^/]+/[^/]+(/[^/]+)?|clusters/kind)/.*#\1#' | sort | uniq -c
grep -rln "BEGIN PRIVATE KEY\|BEGIN PUBLIC KEY" gitops/ | head -3; echo key-check-done
sudo ls /etc/sunmoon/applications/sunmoon-kind/
```

要看到：全是 `exit=0`；`git status` 只有 `clusters/kind` 与两个新应用（含 `image.lock.yaml`、`workload.yaml`、`*.sops.yaml`）；`key-check-done` 前没有任何文件名；私有目录里多了 `knowlab`、`knowmart`。

**D4 提交、发布、晋级**（同改名 R5.2）：

```bash
git add gitops && git -c core.editor=true commit -m "deploy: knowlab、knowmart 两个空应用上线（qwen-003 D）"
make -C infrastructure flux-release; echo "exit=$?"
sudo cat infrastructure/.build/flux/source-candidate.yaml | sudo tee infrastructure/environments/kind/flux-source.yaml >/dev/null
sudo chown "$(id -u):$(id -g)" infrastructure/environments/kind/flux-source.yaml 2>/dev/null; git diff --stat infrastructure/environments/kind/flux-source.yaml
git add infrastructure/environments/kind/flux-source.yaml && git -c core.editor=true commit -m "release(kind): 晋级到 $(git rev-parse --short HEAD)（qwen-003 D）"
make -C infrastructure flux-source-apply; echo "exit=$?"
export KUBECONFIG=~/.kube/sunmoon-kind.config; K=$(command -v kubectl || echo infrastructure/.tools/bin/kubectl)
$K -n flux-system get kustomizations -o name | grep -E '/know(lab|mart)-' | xargs $K -n flux-system wait --for=condition=Ready --timeout=40m; echo "wait exit=$?"
$K -n flux-system get kustomizations | grep -v True
git push origin qwen
```

要看到：`flux-release`、`flux-source-apply`、`wait` 都是 0；`get kustomizations | grep -v True` 只剩表头。

**D5 入口加两个应用的域名**（HAProxy 只是加两条分流，现有分流不变；会停几秒）：

```bash
make -C infrastructure entry-plan 2>&1 | grep -E "knowlab|knowmart" | head
make -C infrastructure entry-preview; echo "exit=$?"
make -C infrastructure entry-stop; echo "exit=$?"
make -C infrastructure entry-deploy; echo "exit=$?"
make -C infrastructure entry-status; echo "exit=$?"
```

**D6 Windows hosts 加四个域名**（先在副本上演练；真改弹 UAC，所有者点「是」）：

```bash
cp docs/process/switch-test/windows_hosts_add.ps1 /mnt/c/Users/zymun/hosts-add.ps1
N="'knowlab.sunmoonai.com','knowlab-admin.sunmoonai.com','knowmart.sunmoonai.com','knowmart-admin.sunmoonai.com'"
cat /mnt/c/Windows/System32/drivers/etc/hosts > /mnt/c/Users/zymun/hosts-add-rehearsal
powershell.exe -NoProfile -Command "\$env:HOSTS_FILE='C:\Users\zymun\hosts-add-rehearsal'; \$env:HOSTS_OUT='C:\Users\zymun\hosts-add-rehearsal.txt'; powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\zymun\hosts-add.ps1 knowlab.sunmoonai.com knowlab-admin.sunmoonai.com knowmart.sunmoonai.com knowmart-admin.sunmoonai.com; 'exit=' + \$LASTEXITCODE"
iconv -f GBK -t UTF-8 /mnt/c/Users/zymun/hosts-add-rehearsal.txt; diff /mnt/c/Windows/System32/drivers/etc/hosts /mnt/c/Users/zymun/hosts-add-rehearsal
# 演练 exit=0、diff 只多一行 127.0.0.1 加四个域名，才做真改：
powershell.exe -NoProfile -Command "Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','C:\Users\zymun\hosts-add.ps1',$N"
iconv -f GBK -t UTF-8 "/mnt/c/Users/zymun/AppData/Local/Temp/hosts-add-result.txt"
rm -f /mnt/c/Users/zymun/hosts-add-rehearsal /mnt/c/Users/zymun/hosts-add-rehearsal.bak-add-* /mnt/c/Users/zymun/hosts-add-rehearsal.txt
```

**D7 检查**：

```bash
for a in tpl knowfeed knowbase investment knowlab knowmart; do echo "===== check $a"; make -C infrastructure application-check APP=$a; echo "exit=$?"; done
make -C infrastructure platform-status; echo "exit=$?"
```

要看到：六个 `application-check` 与 `platform-status` 都是 0。

**D8 浏览器**（所有者自己登录，Qwen 只核截图，截图不截地址栏里的 `code=` 等回跳参数）：`https://knowlab.sunmoonai.com:30443`、`https://knowmart.sunmoonai.com:30443` 用 sunmoonai 账号登录进 dashboard；`https://knowlab-admin.sunmoonai.com:30443`、`https://knowmart-admin.sunmoonai.com:30443` 用 admin 登录进治理控制台。

- 回传：`k8s/scripts/results/qwen-003-D.<时间>.md`（各步输出与截图描述），提交推送后停下等 Opus 审。

## 不做的

业务功能（受理、工程化、测试、分身登记、「请」接口）、公网边缘、对外上架——都在后面的卡里。
