# fable-b5-4 回执：根仓改名 k8s → sunmoonun（本地机这一半）

- 卡：`docs/process/switch-test/inbox/qwen/2026-10-21-fable-b5-4-rename-sunmoonun.md`（做完已移 `done/`）
- 工位：WS=fable，改名后 `~/worktrees/fable/sunmoonun`，分支 `fable`，HEAD `fc9f47c8b`（全程未变）
- 执行时段：2026-10-21 01:52–02:26（本机 CST）
- 一句话结论：**七节全过，改名落地**。两站新名字都已生效；主仓远端地址改成 GitHub SSH 拉取 + GitHub SSH/Gitee https 双推送；`~/master` 与五个工作树目录都改名并 `worktree repair` 成功（六行全新路径、分支与提交号各自没变、五工位全干净）；Jenkins 代理克隆改名并按所有者指示把 origin 设成 SSH，控制器与代理重装后 `render-check #51 fable@fc9f47c8bb` **SUCCESS 423 秒**、确实在 `/mnt/sunmoon-data/jenkins/repos/sunmoonun` 下跑；两个转发器重写成新路径；`platform-status` 0。**没有就地修任何仓里文件**；发现一处卡面范围外的遗留（所有者的 `~/five-repos-sync/config.sh` 里 `REPOS` 仍写 `"k8s"`），未动，已报所有者。

## 一、前提核对（只读）

### 1.1 卡面命令与结果

```text
git ls-remote --heads https://github.com/sunmoonlion/sunmoonun.git fable | cut -c1-12
  → fatal: unable to access '…/sunmoonun.git/': gnutls_handshake() failed:
    The TLS connection was non-properly terminated.
  → 卡面回显 github exit=0
git ls-remote --heads https://gitee.com/sunmoonlion/sunmoonun.git fable | cut -c1-12
  → fc9f47c8bbb0    gitee exit=0
cd ~/worktrees/fable/k8s && git status --short | head -3 && git log --oneline -1
  → （空）  fc9f47c8b services README 的 layout.yaml 链接改指 components/…
for ws in cursor fable kimi luna qwen; do … status --short | wc -l; done
  → cursor 0 / fable 0 / kimi 0 / luna 0 / qwen 0
git -C ~/master/k8s worktree list
  → 六行（/home/zymun/master/k8s f1248c16d [master]、cursor 7e9619db0、fable fc9f47c8b、
     kimi 7e9619db0、luna 7e9619db0、qwen 5a8e99a9a）
sudo -n bash -c 'grep -l "<duration>0</duration>" …/builds/*/build.xml || echo "no build in progress"'
  → no build in progress
```

### 1.2 两处「怎么执行」的改动（判据未改）

1. **`| cut -c1-12` 吃掉了退出码**：卡面 `git ls-remote … | cut -c1-12; echo "github exit=$?"` 里 `$?` 取到的是 `cut` 的码，所以 GitHub 那次明明 `fatal` 却回显 `exit=0`。改为**裸跑不接管道、单独取码**（或用 `${PIPESTATUS[0]}`），所有者已确认这一条。
2. **GitHub 核验与拉取改走 SSH**：本机到 GitHub 的 https 握手会被掐（这次核验如此，所有者说 b4 取 tag 也是这么倒的；本机 git 对 github.com 配了代理 `http://192.168.32.1:7890`）。所有者指示改用：

```text
git ls-remote --heads git@github.com:sunmoonlion/sunmoonun.git fable; echo "exit=$?"
  → fc9f47c8bbb08e609b3b08fb85e9510711acf6d3        refs/heads/fable
    exit=0
```

（`~/.ssh/config` 里 `Host github.com` 用 `~/.ssh/id_rsa`、`IdentitiesOnly yes`；私钥无口令。）

### 1.3 前提①「两站都已改名」的证据

| 核验 | 结果 |
| --- | --- |
| GitHub 新名 `sunmoonun`（HTTPS，重试后） | `exit=0`，返回 `refs/heads/fable`；HTTP `code=200`（仓就叫这名） |
| GitHub 旧名 `k8s` | `exit=0` 仍能取到同一 ref；HTTP `code=301 redirect=https://github.com/sunmoonlion/sunmoonun` → 是改名后的重定向，不是没改名 |
| GitHub 新名（SSH，所有者指定通路） | `exit=0`，`fc9f47c8bbb0…` |
| Gitee 新名 `sunmoonun` | `exit=0`，`fc9f47c8bbb0…` |
| Gitee 旧名 `k8s` | `exit=0` 也仍通（Gitee 同样保留旧路径） |
| 所有者提供的两条 | `gh repo rename` 回「Renamed repository sunmoonlion/sunmoonun」；远程机从 `git@github.com:sunmoonlion/sunmoonun.git` 拉取成功 |

### 1.4 前提②③与我另加的只读核对

- 五个工位 `status --short | wc -l` 全 0，`worktree list` 六行 ✓；没有在跑的构建 ✓。
- 我另扫了「有没有进程的工作目录在待改名目录里」（卡面没要求）：`gnome-keyring-daemon`（cwd `~/worktrees/qwen/k8s`）与我这个会话的 `zsh -il`（cwd `~/worktrees/fable/k8s`）。目录 rename 后 inode 不变、cwd 不会失效，但**后续命令一律用新的绝对路径**，第四节脚本开头我先 `cd ~` 免得踩自己的 cwd。
- mv 前留底：`~/master/k8s` 与 `~/worktrees/{cursor,fable,kimi,luna,qwen}/k8s` 六个目录都在。
- 工作树的 `.git` 是文件指针，改前内容：`gitdir: /home/zymun/master/k8s/.git/worktrees/k8s1`。

## 二、先停 Jenkins

```text
make -C ~/worktrees/fable/k8s/infrastructure jenkins-agent-stop → agent stop exit=0
make -C ~/worktrees/fable/k8s/infrastructure jenkins-stop       → stop exit=0
systemctl is-active sunmoon-jenkins.service sunmoon-jenkins-agent.service → inactive / inactive
systemctl show sunmoon-jenkins.service --property=ActiveState,Result → Result=success / ActiveState=inactive
```

停之前我按前提③又扫了一遍活体（`grep -l "<duration>0</duration>"`，这条判据是远程采纳了 b3 那轮的看法改的，能真判活体），确认无在跑构建、`queue.xml` 里 `BuildableItem` 为 0 才停。**照实记一处我自己的 bug**：我那个「等空档」循环里写了 `q=$(… grep -c "BuildableItem" queue.xml || echo 0)`，无匹配时 `grep -c` 已打印 `0` 且退出码非 0，`|| echo 0` 又打印一个，`q` 成了两行的 `"0\n0"`，`[ "$q" = "0" ]` 永不成立 → break 不生效，白跑满 20 轮约 14 分钟（01:54:48–02:09:04）。后果不坏：期间 02:06 触发的 `#49` 是 `NOT_BUILT`（13931 ms，分支头没变的定时跳过）且在我停之前已结束，最后一轮（02:09:04）确认无在跑才动手，**没有打断任何构建**（对照 b3 那轮 `#26` 被打断成 FAILURE）。

## 三、改远端地址（主仓一处）

卡面第 43–46 行把 origin 设成 https；按所有者指示改为 **SSH 拉取 + 「GitHub SSH 在前、Gitee https 在后」两个推送地址**（顺序要紧：代理准备那步按工位 origin 的推送地址重设 mirror，取到的第二个正好是 Gitee）。其余照卡面。

**改前 `git remote -v` 原文（万一要改回去用）**：

```text
gitee   https://gitee.com/sunmoonlion/k8s.git (fetch)
gitee   https://gitee.com/sunmoonlion/k8s.git (push)
origin  https://github.com/sunmoonlion/k8s.git (fetch)
origin  https://github.com/sunmoonlion/k8s.git (push)
origin  https://gitee.com/sunmoonlion/k8s.git (push)
```

**实际执行的命令**（`set -e`）：

```bash
cd ~/master/k8s
git remote set-url origin git@github.com:sunmoonlion/sunmoonun.git
git remote set-url --delete --push origin '.*' 2>/dev/null || true
git remote set-url --add --push origin git@github.com:sunmoonlion/sunmoonun.git
git remote set-url --add --push origin https://gitee.com/sunmoonlion/sunmoonun.git
git remote -v
git fetch -q origin && echo fetch-ok
```

**改后 `git remote -v` 原文**：

```text
gitee   https://gitee.com/sunmoonlion/k8s.git (fetch)
gitee   https://gitee.com/sunmoonlion/k8s.git (push)
origin  git@github.com:sunmoonlion/sunmoonun.git (fetch)
origin  git@github.com:sunmoonlion/sunmoonun.git (push)
origin  https://gitee.com/sunmoonlion/sunmoonun.git (push)
```

判据：origin 三行都是 `sunmoonun`（fetch 一行、push 两行，站点组合与改前一致：GitHub + Gitee）✓；`fetch-ok`、`fetch exit=0` ✓。另用状态类证据交叉复核：`git rev-parse HEAD` 与 `git rev-parse origin/master` 同为 `f1248c16dcb51432e3f33be79c37e87b99d9b03d`。

**照实记两处未动**：① 主仓还有一个**独立的 `gitee` 远程**仍指旧名 `k8s.git`——卡面第三节只改 origin，我问过所有者、未获指示，故未动；实测 Gitee 旧地址目前仍通（`exit=0`），但改名生效后随时可能断，建议后续一并改。② 卡面第 42 行那个 `for u in $(…); do :; done` 是空转循环，原样保留未删。

## 四、改目录名、修工作树

卡面脚本原样执行（`set -e`），只在开头加 `cd ~`（见 1.4）：

```text
mv ~/master/k8s ~/master/sunmoonun
for ws in cursor fable kimi luna qwen; do mv ~/worktrees/$ws/k8s ~/worktrees/$ws/sunmoonun; done
git -C ~/master/sunmoonun worktree repair …五个新路径…
```

`worktree repair` 的输出（它修了两侧共 10 处）：

```text
repair: gitdir incorrect: .git/worktrees/k8s/gitdir
repair: gitdir incorrect: .git/worktrees/k8s1/gitdir
repair: gitdir incorrect: .git/worktrees/k8s2/gitdir
repair: gitdir incorrect: .git/worktrees/k8s3/gitdir
repair: gitdir incorrect: .git/worktrees/k8s5/gitdir
repair: .git file broken: /home/zymun/worktrees/kimi/sunmoonun
repair: .git file broken: /home/zymun/worktrees/cursor/sunmoonun
repair: .git file broken: /home/zymun/worktrees/fable/sunmoonun
repair: .git file broken: /home/zymun/worktrees/qwen/sunmoonun
repair: .git file broken: /home/zymun/worktrees/luna/sunmoonun
```

**改后 `worktree list`（六行全新路径，分支与提交号各自没变）**：

```text
/home/zymun/master/sunmoonun            f1248c16d [master]
/home/zymun/worktrees/cursor/sunmoonun  7e9619db0 [cursor]
/home/zymun/worktrees/fable/sunmoonun   fc9f47c8b [fable]
/home/zymun/worktrees/kimi/sunmoonun    7e9619db0 [kimi]
/home/zymun/worktrees/luna/sunmoonun    7e9619db0 [luna]
/home/zymun/worktrees/qwen/sunmoonun    5a8e99a9a [qwen]
```

五工位干净度与分支（每个都 `0` + 分支名没变）：`cursor 0/cursor`、`fable 0/fable`、`kimi 0/kimi`、`luna 0/luna`、`qwen 0/qwen`。旧路径已不存在（`ls -d ~/master/k8s ~/worktrees/*/k8s` → `No such file or directory`）。fable 工位拉取：

```text
From github.com:sunmoonlion/sunmoonun
 * branch                fable      -> FETCH_HEAD
Already up to date.
fc9f47c8b services README 的 layout.yaml 链接改指 components/…
```

工作树 `.git` 指针改后为 `gitdir: /home/zymun/master/sunmoonun/.git/worktrees/k8s1`（`.git/worktrees/` 下的**内部工作树名仍叫 k8s1**，`repair` 不改名，不影响使用；照实记）。

## 五、Jenkins 代理克隆改名，重装控制器与代理

**改前代理克隆 `remote -v`**：

```text
mirror  https://gitee.com/sunmoonlion/k8s.git (fetch)
mirror  https://gitee.com/sunmoonlion/k8s.git (push)
origin  https://github.com/sunmoonlion/k8s.git (fetch)
origin  https://github.com/sunmoonlion/k8s.git (push)
```

执行（卡面第一段，`origin` 按所有者指示设 SSH；`mirror` 与卡面一致仍 Gitee https）：

```text
sudo -n -u zymun mv k8s sunmoonun                     → ok
sudo -n -u zymun rm -rf 'k8s@tmp'                     → ok（改前它存在，mtime 02:06）
git remote set-url origin git@github.com:sunmoonlion/sunmoonun.git
git remote set-url mirror https://gitee.com/sunmoonlion/sunmoonun.git
```

**改后**：

```text
mirror  https://gitee.com/sunmoonlion/sunmoonun.git (fetch)
mirror  https://gitee.com/sunmoonlion/sunmoonun.git (push)
origin  git@github.com:sunmoonlion/sunmoonun.git (fetch)
origin  git@github.com:sunmoonlion/sunmoonun.git (push)
```

**代理克隆 origin 按远程指示设为 SSH**（卡面写的是 https）。可行性我先实测过：`sudo -n -u zymun env -i HOME=/home/zymun PATH=/usr/bin:/bin git ls-remote … git@github.com:…` → `exit=0`（干净环境、无 `SSH_AUTH_SOCK`、无代理变量），私钥无口令，且 `sunmoon-jenkins-agent.service` 是 `User=zymun`、`Environment=HOME=/home/zymun`，正好对得上；改名后又以 zymun 身份实跑 `git fetch -q origin` → `agent-fetch-ok`。所有者另说明：卡面写 https 是因为流水线每条 git 命令都带 `url.git@github.com:.insteadOf=https://github.com/` 改写（仓内实证：`ci/release.groovy:175`、`:225`，`infrastructure/jenkins/tasks/workspace.yaml:47`、`:90`），https 实际也走 SSH，直接设 SSH 更直白、改写规则对它只是空转。

**目录计数**（`ls -1 /mnt/sunmoon-data/jenkins/repos`）：`sunmoonun` + 六个应用仓（`knowbase-app`、`knowbench-app`、`knowfeed-app`、`knowlab-app`、`knowmart-app`、`tpl-app`）与各自的 `@tmp`；**没有 `k8s`、没有 `k8s@tmp`** ✓。

**五个 make 与计数**：

```text
make -C infrastructure jenkins-deploy        → deploy exit=0
   localhost : ok=70  changed=3  unreachable=0  failed=0  skipped=9  rescued=0  ignored=0
make -C infrastructure jenkins-agent-deploy  → agent deploy exit=0
   localhost : ok=41  changed=3  unreachable=0  failed=0  skipped=15 rescued=0  ignored=0
make -C infrastructure jenkins-agent-start   → agent start exit=0
make -C infrastructure jenkins-status       → status exit=0
make -C infrastructure jenkins-agent-status → agent status exit=0

grep -c "repos/sunmoonun" …/render-check/config.xml …/release/config.xml
  → render-check:1  release:1        （判据：两份都有 ✓）
grep -c "repos/k8s" 同两份
  → render-check:0  release:0        （无旧路径残留）
grep -rn "repos/k8s|master/k8s|worktrees/$WS/k8s" /opt/sunmoon/jenkins/init.groovy.d/
  → 无命中（opt-scan-done）
```

配置里的原文（`&apos;` 是 XML 转义）：`render-check/config.xml: repos/sunmoonun&apos;`、`release/config.xml: repos/sunmoonun&apos;`。

顺带一处**上一轮的遗留这次没了**：b3 第二版那轮我报「`/opt/sunmoon/jenkins/init.groovy.d/` 并存 8 个文件（4 个不带后缀 + 4 个 `.override`）」，`62d44f99e` 把删旧首启脚本的正则改成不用反斜杠之后，这次 `ls` **只有四个 `.override`**（`01-platform`、`02-agent-node`、`03-render-check`、`04-release`）。

## 六、真跑一次 render-check，重写转发器

```text
make -C infrastructure jenkins-agent-check → check exit=0
TASK [Report the build result] ok:
    "build": 51,
    "console": "/home/zymun/worktrees/fable/sunmoonun/infrastructure/jenkins/../.build/jenkins/render-check-51.log",
    "name": "#51 fable@fc9f47c8bb",
    "result": "SUCCESS",
    "seconds": 423
TASK [Require the check to pass] ok
TASK [Report the agent unit state] ok
TASK [Display only non-secret state] →
    NRestarts=0 / User=zymun / Id=sunmoon-jenkins-agent.service /
    ActiveState=active / SubState=running / UnitFileState=enabled
PLAY RECAP localhost : ok=15 changed=1 unreachable=0 failed=0 skipped=19 rescued=0 ignored=0
```

判据 `check exit=0` + 结果 SUCCESS ✓（比 NOT_BUILT 更强）。中途 `Wait for the build to finish` 有 6 行 `FAILED - RETRYING`（137→132 retries left），是 `until` 轮询等构建结束的正常表现，最终 `ok`；b3 那轮炸掉的 `retries` 模板已由 `62d44f99e` 修好（`agent.yaml:305` 现在是 `'{{ ((jenkins_run_timeout_seconds | int) / 15) | int }}'`）。

**构建确实在新路径下跑**（`builds/51/log`）：

```text
7:  Running in /mnt/sunmoon-data/jenkins/repos/sunmoonun
87: make: Entering directory '/mnt/sunmoon-data/jenkins/repos/sunmoonun/infrastructure'
205:make: Leaving directory '/mnt/sunmoon-data/jenkins/repos/sunmoonun/infrastructure'
收尾：Finished: SUCCESS
账面：<timestamp>1792520226458</timestamp> <result>SUCCESS</result> <duration>423654</duration>、Started by user
```

console 日志文件在（`.build/` 不进 git）：`-rw-r--r-- 1 root root 405927 Oct 21 02:24 …/infrastructure/.build/jenkins/render-check-51.log`。构建后 `sunmoonun@tmp` 重新长出，仍无 `k8s*`。

**转发器**（`~/switch-test/human-local.sh`、`human-remote.sh`，各一行新路径）：

```text
/home/zymun/switch-test/human-local.sh:4:exec bash "$HOME/worktrees/$WS/sunmoonun/docs/process/switch-test/human-local.sh" "$@"
/home/zymun/switch-test/human-remote.sh:4:exec bash "$HOME/worktrees/$WS/sunmoonun/docs/process/switch-test/human-remote.sh" "$@"
```

`human-remote.sh` 全文（4 行，与卡面模板逐字一致）：

```bash
#!/usr/bin/env bash
# 转发器：跑仓里 WS 工位的最新版（WS 必须给，不猜）；本文件由 human-local.sh 生成，不要手改
if [ -z "${WS:-}" ]; then echo "✗ 要指定工位：WS=<fable|cursor|kimi|luna|qwen> bash ~/switch-test/human-remote.sh" >&2; exit 2; fi
exec bash "$HOME/worktrees/$WS/sunmoonun/docs/process/switch-test/human-remote.sh" "$@"
```

被转发的目标存在且可执行：`human-local.sh`（7393 字节）、`human-remote.sh`（5800 字节），都在 `~/worktrees/fable/sunmoonun/docs/process/switch-test/`。仓里那份的默认值也已是新名：`ROOT_REPO="${ROOT_REPO:-sunmoonun}"`、`FIVE="$ROOT_REPO knowfeed-app …"`。

```text
make -C infrastructure platform-status → platform status exit=0
   localhost : ok=7 changed=0 unreachable=0 failed=0 skipped=5 rescued=0 ignored=0
```

## 七、就地修了什么

**没有就地修任何仓里文件**（`git status --short` 全程为空，HEAD 始终 `fc9f47c8b`）。卡面第 7 行给的临时就地修授权这轮没用到。

改「怎么执行」的四处，都在上面各自小节记了原命令/改后命令/原因：① 退出码不接管道取（1.2）；② GitHub 核验与拉取走 SSH（1.2、所有者指示）；③ 第三节 origin 与第五节代理克隆 origin 用 SSH、推送地址按「GitHub SSH 在前、Gitee https 在后」（三、五，所有者指示）；④ 第四节脚本开头 `cd ~`（1.4）。判据、安全约束、设计、集群、gitops、Harbor 已有镜像一律未碰。

## 八、副作用与未动清单

- Jenkins 停机窗口：控制器 02:09:3x 停 → **02:13:28** 起（`NRestarts=0`），代理 **02:16:04** `active`（`UnitFileState=enabled`）。期间的定时构建：`#49`（02:06 触发，`NOT_BUILT` 13931 ms）在停之前已结束；`#50`（02:16 触发，`NOT_BUILT` 31354 ms）是重启后第一次定时，说明定时器恢复正常；`#51`（02:17，`Started by user`）是本卡强制的那次，`SUCCESS` 423654 ms。**没有构建被打断**。
- 未碰：六个应用仓（`~/master/{knowbase,knowbench,knowfeed,knowlab,knowmart,tpl}-app` 目录名与远端地址都没动）、`sunmoon-link`、集群、gitops 声明、Harbor；代理仓里六个应用仓的 origin 仍是各自 `https://github.com/sunmoonlion/<名>-app.git`（只读了一眼，未改）。
- **卡面范围外的一处遗留（未动，已报所有者）**：`~/five-repos-sync/config.sh` 的 `REPOS` 数组第 20 行仍是 `"k8s"`，而 `sync-five-repos.sh` 按这份清单逐仓逐工位操作（第 169/180/212 行 `for repo in "${REPOS[@]}"`）→ 改名后它会找不到 `k8s` 目录，**所有者 qwen 线用的 `human-remote.sh` / `remote-pull` 会受影响**。这不在卡面「改动（机器上）」清单里，也不在仓内，我没改；建议改成 `"sunmoonun"`（一行），等所有者发话。
- 主仓那个独立 `gitee` 远程仍指旧名（三节末已记）。
- 一次性日志：`/tmp/b54-{sec1,sec2,sec3,sec4,sec5,sec5b,sec6,gitee-old,gitee-new,ssh-clean,agent-stop,stop,deploy,agent-deploy,agent-start,status,agent-status,check,platform}.log` 共 19 个，回执写完即删（删除结果见第十节）。

## 九、第五节所有者走查（本卡无此节，附核验入口）

本卡卡面第五节是「Jenkins 代理克隆改名，重装控制器与代理」，没有所有者走查节。若要在浏览器核：Jenkins 首页两个任务；`render-check` 构建历史里 `#51 fable@fc9f47c8bb` SUCCESS（约 7 分钟）、`#50`/`#49` 是 NOT_BUILT；`release` 仍是 `#1`（b3 那轮的历史，本卡未跑 release）。

## 十、第六节…第七节：回执入库与推回

卡面第七节的命令原样执行（路径已是新名）：

```bash
cd ~/worktrees/fable/sunmoonun && git pull --ff-only origin fable \
  && git add scripts/results/fable-b5-4.20261021-0226.md \
  && git mv docs/process/switch-test/inbox/qwen/2026-10-21-fable-b5-4-rename-sunmoonun.md \
            docs/process/switch-test/done/ \
  && git commit -m "fable-b5-4 回执：根仓改名 sunmoonun，本地机（qwen）" \
  && git push origin fable
```

（卡面那条 `git add scripts/results/fable-b5-4.*.md` 的 glob 本轮只匹配到本回执一个文件，故直接写实文件名，避免 glob 无匹配时断掉 `&&` 链——这是 b2e 那轮踩过的坑。）

### 推回原文

```text
$ git pull --ff-only origin fable
From github.com:sunmoonlion/sunmoonun
 * branch                fable      -> FETCH_HEAD
Already up to date.
pull exit=0

$ git add … && git mv … && git status --short
R  docs/process/switch-test/inbox/qwen/2026-10-21-fable-b5-4-rename-sunmoonun.md -> docs/process/switch-test/done/2026-10-21-fable-b5-4-rename-sunmoonun.md
A  scripts/results/fable-b5-4.20261021-0226.md

$ git commit -m "fable-b5-4 回执：根仓改名 sunmoonun，本地机（qwen）"
[fable 4a3bf74ab] fable-b5-4 回执：根仓改名 sunmoonun，本地机（qwen）
 2 files changed, 305 insertions(+)
 rename docs/process/switch-test/{inbox/qwen => done}/2026-10-21-fable-b5-4-rename-sunmoonun.md (100%)
 create mode 100644 scripts/results/fable-b5-4.20261021-0226.md
commit exit=0

$ git push origin fable
To github.com:sunmoonlion/sunmoonun.git
   fc9f47c8b..4a3bf74ab  fable -> fable
remote: Powered by GITEE.COM [1.1.23]
remote: Set trace flag 1d477da7
To https://gitee.com/sunmoonlion/sunmoonun.git
   fc9f47c8b..4a3bf74ab  fable -> fable
push exit=0

$ git status --short                                   → 空
$ git rev-list --left-right --count origin/fable...HEAD → 0  0
$ git log --oneline -1                                  → 4a3bf74ab (HEAD -> fable, origin/fable)
```

只有两样改动：回执新增（`A`）与卡移 `done/`（`R`，100% 相同）✓，符合「只提交回执与卡的移动」。**推送走的是第三节改过的新地址**：GitHub 那条是 SSH（`To github.com:sunmoonlion/sunmoonun.git`）、Gitee 那条是 https，两站同一号 `fc9f47c8b..4a3bf74ab`，一条 `git push origin fable` 同时到双远程。本节这段推回原文是推完之后补写的，故还有一笔只动本回执的补写提交。

`/tmp/b54-*.log` 19 个一次性日志已删（删除后 `ls /tmp/b54-*` 报 `no matches found`）；`infrastructure/.build/jenkins/render-check-51.log` 是 make 链自己的产物，按规矩留在 `.build/`、不进 git。
