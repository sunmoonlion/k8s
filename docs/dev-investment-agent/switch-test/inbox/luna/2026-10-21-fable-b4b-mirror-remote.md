# luna 卡 fable-b4b：代理克隆加镜像站 remote，验推送通路（B4 的收尾小卡）

> 状态：**可执行**（远程 Fable 2026-10-21 凌晨写）。B4 已过。你交回的两个缺口已改：① 自动回执现在也拷进产物目录再归档——这个只有下一次真发布才验得到，不为它造一次发布；② 代理准备会读源工位 k8s 的 origin 的全部 push 地址，第二个（Gitee）设成克隆里的 remote `mirror`，流水线推完 GitHub 再尽力推它，推不上只记在 `12-push.txt` 和构建说明里、不算发布失败。本卡只验 ②：重跑代理准备、看 remote、干跑一次推送（`--dry-run`，不改远端）。
>
> 临时就地修授权同 b4 卡头（只对卡改到的文件；安全约束、判据、设计、集群不碰）。

```text
被测仓：k8s；工位 WS=fable：~/worktrees/fable/k8s，分支 fable
改动（本次）：infrastructure/jenkins/tasks/workspace.yaml（mirror remote）、ci/release.groovy（回执归档、镜像站尽力推、停下时的说明用 HEAD）、README、使用说明、0033
不碰：控制器（不重启）、集群、gitops、Harbor；不读、不抄口令
```

## 一、核对与拉取

```bash
cd ~/worktrees/fable/k8s && git pull --ff-only origin fable && git log --oneline -1 && git status --short | head -3
git remote get-url --push --all origin
make -C infrastructure jenkins-agent-plan; echo "plan exit=$?"
```

要看到：HEAD 是本卡这次提交或更新；push 地址两行（GitHub、Gitee）；plan 0。

## 二、重跑代理准备（对已有克隆只 fetch、设 mirror、装工具）

先确认没有构建在跑（和 b4 第一节同一段 sudo 检查），再：

```bash
make -C infrastructure jenkins-agent-deploy; echo "deploy exit=$?"
make -C infrastructure jenkins-agent-status; echo "agent status exit=$?"
git -C /mnt/sunmoon-data/jenkins/repos/k8s remote -v
```

要看到：两个都是 0；`remote -v` 里 `origin` 是 GitHub（fetch/push 各一行），`mirror` 是 Gitee（两行）。

## 三、干跑推送（不改远端）

以代理用户、模拟代理单元的环境（只带 HOME）跑：

```bash
sudo -n -u zymun -H env -i HOME=/home/zymun PATH=/usr/bin:/bin bash <<'SH'
cd /mnt/sunmoon-data/jenkins/repos/k8s
git -c url.git@github.com:.insteadOf=https://github.com/ push --dry-run origin HEAD:refs/heads/fable 2>&1 | tail -2; echo "origin dry-run exit=${PIPESTATUS[0]}"
git push --dry-run mirror HEAD:refs/heads/fable 2>&1 | tail -3; echo "mirror dry-run exit=${PIPESTATUS[0]}"
SH
```

要看到：两个 dry-run 都是 0（输出 `Everything up-to-date` 或 `[up to date]`）。**mirror 那条不是 0**（多半是 https 到 Gitee 没有非交互凭据）就照实记：这正是要知道的——说明流水线里镜像站会「尽力推、推不上」，GitHub 不受影响；把错误那两行（没有口令）写进回执交我定怎么给凭据，不要自己配凭据。

## 四、回执与推回

`scripts/results/fable-b4b.<时间>.md`：三节命令与 exit、`remote -v`、两个 dry-run 的输出、「就地修了什么」（没修写没有）。

```bash
cd ~/worktrees/fable/k8s && git pull --ff-only origin fable && git add scripts/results/fable-b4b.*.md && git mv docs/dev-investment-agent/switch-test/inbox/luna/2026-10-21-fable-b4b-mirror-remote.md docs/dev-investment-agent/switch-test/done/ && git commit -m "fable-b4b 回执：镜像站 remote 与推送干跑（luna）" && git push origin fable; echo "push exit=$?"
```
