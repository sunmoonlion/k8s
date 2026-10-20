# qwen 卡 fable-b5-4：根仓改名 k8s → sunmoonun（本地机这一半）

> 状态：**可执行，但有三个前提**（远程 Fable 2026-10-21 写，SDD 0038 第五节；所有者点名由 Qwen 做）。前提：① 所有者已在 **GitHub 和 Gitee 网页上**把仓 `k8s` 改名 `sunmoonun`（两站都改完再开始）；② 本地机上没有别的助手在 fable 工位里干活（luna 的 b5-2 已并入本卡，不用再做）；③ 没有构建在跑。仓里的改动已推上：`jenkins_root_repo: sunmoonun`、同步脚本默认值、活文档路径。这张卡做机器上的事：改远端地址、改目录名、修工作树、Jenkins 代理克隆改名、重装控制器与代理、跑一次 render-check、重写所有者的转发器。
>
> 文档树上一张卡拆过了：**收件箱在 `docs/process/switch-test/inbox/<名>/`**，回执在 `scripts/results/`。
>
> 临时就地修授权：卡改到的文件（`infrastructure/jenkins/**`、`docs/process/switch-test/*.sh`、本卡命令）里让步骤过不去的错可以就地改、验、续跑并推 `origin/fable`；判据、安全约束、设计、集群、gitops、Harbor 已有镜像不碰；**目录改名这类动作做错了先停**，别自己回滚。

```text
被测仓：根仓（改名前 k8s，改名后 sunmoonun）；工位 WS=fable，改名后在 ~/worktrees/fable/sunmoonun，分支 fable 不变
改动（机器上）：~/master/k8s 与五个 ~/worktrees/<ws>/k8s 目录名、它们的远端地址、Jenkins 代理克隆、控制器首启引导、~/switch-test 转发器
不碰：六个应用仓、sunmoon-link、集群、gitops 声明、Harbor
```

## 一、前提核对（只读）

```bash
git ls-remote --heads https://github.com/sunmoonlion/sunmoonun.git fable | cut -c1-12; echo "github exit=$?"
git ls-remote --heads https://gitee.com/sunmoonlion/sunmoonun.git fable | cut -c1-12; echo "gitee exit=$?"
cd ~/worktrees/fable/k8s && git status --short | head -3 && git log --oneline -1
for ws in cursor fable kimi luna qwen; do printf '%-7s ' $ws; git -C ~/worktrees/$ws/k8s status --short | wc -l; done
git -C ~/master/k8s worktree list
sudo -n bash -c 'grep -l "<duration>0</duration>" /mnt/sunmoon-data/jenkins/home/jobs/*/builds/*/build.xml 2>/dev/null || echo "no build in progress"'
```

要看到：两站 `ls-remote` 都 exit 0（新名字已生效）；fable 工位干净、HEAD 是本卡这次提交或更新；五个工位都干净（有不干净的先停，告诉所有者，那是别人没交的活）；`worktree list` 六行；没有在跑的构建。

## 二、先停 Jenkins（它的代理克隆要改名）

```bash
make -C ~/worktrees/fable/k8s/infrastructure jenkins-agent-stop; echo "agent stop exit=$?"
make -C ~/worktrees/fable/k8s/infrastructure jenkins-stop; echo "stop exit=$?"
```

## 三、改远端地址（主仓一处就够，五个工作树共用它的配置）

```bash
bash <<'SH'
set -e
cd ~/master/k8s
git remote -v
for u in $(git remote get-url --all origin) $(git remote get-url --push --all origin); do :; done
git remote set-url origin "$(git remote get-url origin | sed 's#/k8s\(\.git\)\?$#/sunmoonun.git#')"
git remote set-url --delete --push origin '.*' 2>/dev/null || true
git remote set-url --add --push origin https://github.com/sunmoonlion/sunmoonun.git
git remote set-url --add --push origin https://gitee.com/sunmoonlion/sunmoonun.git
git remote -v
git fetch -q origin && echo fetch-ok
SH
```

要看到：改后 `remote -v` 三行都是 `sunmoonun.git`（fetch 一行、push 两行，和改前同一组站点）；`fetch-ok`。**改前 `remote -v` 的三行原文抄进回执**，万一要改回去用。

## 四、改目录名、修工作树

```bash
bash <<'SH'
set -e
mv ~/master/k8s ~/master/sunmoonun
for ws in cursor fable kimi luna qwen; do mv ~/worktrees/$ws/k8s ~/worktrees/$ws/sunmoonun; done
git -C ~/master/sunmoonun worktree repair ~/worktrees/cursor/sunmoonun ~/worktrees/fable/sunmoonun ~/worktrees/kimi/sunmoonun ~/worktrees/luna/sunmoonun ~/worktrees/qwen/sunmoonun
git -C ~/master/sunmoonun worktree list
for ws in cursor fable kimi luna qwen; do printf '%-7s ' $ws; git -C ~/worktrees/$ws/sunmoonun status --short | wc -l; git -C ~/worktrees/$ws/sunmoonun rev-parse --abbrev-ref HEAD; done
cd ~/worktrees/fable/sunmoonun && git pull --ff-only origin fable && git log --oneline -1
SH
```

要看到：`worktree list` 六行全是新路径；五个工位干净、分支名各自没变；fable 工位能拉（`Already up to date` 或快进）。

## 五、Jenkins 代理克隆改名，重装控制器与代理

```bash
bash <<'SH'
set -e
cd /mnt/sunmoon-data/jenkins/repos
sudo -n -u zymun mv k8s sunmoonun
sudo -n -u zymun rm -rf k8s@tmp
cd sunmoonun
git remote set-url origin https://github.com/sunmoonlion/sunmoonun.git
git remote get-url mirror >/dev/null 2>&1 && git remote set-url mirror https://gitee.com/sunmoonlion/sunmoonun.git
git remote -v
ls /mnt/sunmoon-data/jenkins/repos
SH
cd ~/worktrees/fable/sunmoonun
make -C infrastructure jenkins-deploy; echo "deploy exit=$?"
make -C infrastructure jenkins-agent-deploy; echo "agent deploy exit=$?"
make -C infrastructure jenkins-agent-start; echo "agent start exit=$?"
make -C infrastructure jenkins-status; echo "status exit=$?"
make -C infrastructure jenkins-agent-status; echo "agent status exit=$?"
sudo -n bash -c 'grep -c "repos/sunmoonun" /mnt/sunmoon-data/jenkins/home/jobs/render-check/config.xml /mnt/sunmoon-data/jenkins/home/jobs/release/config.xml'
```

要看到：代理仓目录里是 `sunmoonun` 加六个应用仓（没有 `k8s`、`k8s@tmp`）；五个 make 都是 0；两份任务配置里都有 `repos/sunmoonun`（引导自更新生效）。

## 六、真跑一次 render-check，重写转发器

```bash
cd ~/worktrees/fable/sunmoonun
make -C infrastructure jenkins-agent-check; echo "check exit=$?"
bash <<'SH'
set -e
mkdir -p "$HOME/switch-test"
for name in human-local.sh human-remote.sh; do
  cat > "$HOME/switch-test/$name" <<SHIM
#!/usr/bin/env bash
# 转发器：跑仓里 WS 工位的最新版（WS 必须给，不猜）；本文件由 human-local.sh 生成，不要手改
if [ -z "\${WS:-}" ]; then echo "✗ 要指定工位：WS=<fable|cursor|kimi|luna|qwen> bash ~/switch-test/$name" >&2; exit 2; fi
exec bash "\$HOME/worktrees/\$WS/sunmoonun/docs/process/switch-test/$name" "\$@"
SHIM
  chmod +x "$HOME/switch-test/$name"
done
grep -n "sunmoonun/docs/process" "$HOME/switch-test/"*.sh
SH
make -C infrastructure platform-status; echo "platform status exit=$?"
```

要看到：`check exit=0`，结果 SUCCESS 或 NOT_BUILT（分支头没变就是 NOT_BUILT，也算过——它证明代理在新路径下能更新仓、加载脚本）；两个转发器各一行新路径；platform-status 0。

## 七、回执与推回

`scripts/results/fable-b5-4.<时间>.md`：每节命令与 exit、第三节改前改后的 `remote -v`、第四节 `worktree list`、第五节目录与计数、第六节结果、「就地修了什么」。

```bash
cd ~/worktrees/fable/sunmoonun && git pull --ff-only origin fable && git add scripts/results/fable-b5-4.*.md && git mv docs/process/switch-test/inbox/qwen/2026-10-21-fable-b5-4-rename-sunmoonun.md docs/process/switch-test/done/ && git commit -m "fable-b5-4 回执：根仓改名 sunmoonun，本地机（qwen）" && git push origin fable; echo "push exit=$?"
```

推不上去就停下告诉所有者（远端地址第三节改过，`push` 走的是新地址）。
