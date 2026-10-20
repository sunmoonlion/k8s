# fable-b4b 回执：镜像站 remote 与推送干跑（luna）

WS=fable，分支 fable，2026-10-21 Asia/Shanghai。起始干净，快进至 `e392b80bc`（含 B4b 与 B5-1 变更）。结果 **pass**。

## 一、核对与计划

`git pull --ff-only origin fable` exit=0。源工位 `git remote get-url --push --all origin` 两行：GitHub / Gitee。`make -C infrastructure jenkins-agent-plan` exit=0；sudo 只读核对无进行中构建、queue_items=0。

原始输出 `fable-b4b.20261021-011143.01-preflight.txt`，exit=0。

## 二、代理准备

`make -C infrastructure jenkins-agent-deploy`、`make -C infrastructure jenkins-agent-status` 均 exit=0，代理 active/running/enabled、User=zymun、NRestarts=0。原生准备安装工具、按源工位第二个 push 地址设置 mirror；未重启控制器。

`git -C /mnt/sunmoon-data/jenkins/repos/k8s remote -v` 原文：

```text
mirror	https://gitee.com/sunmoonlion/k8s.git (fetch)
mirror	https://gitee.com/sunmoonlion/k8s.git (push)
origin	https://github.com/sunmoonlion/k8s.git (fetch)
origin	https://github.com/sunmoonlion/k8s.git (push)
```

原始输出 `fable-b4b.20261021-011143.02-agent-prepare.txt`，exit=0。

## 三、推送干跑

按卡使用 `sudo -n -u zymun -H env -i HOME=/home/zymun PATH=/usr/bin:/bin bash`，在代理克隆运行：

```bash
git -c url.git@github.com:.insteadOf=https://github.com/ push --dry-run origin HEAD:refs/heads/fable
git push --dry-run mirror HEAD:refs/heads/fable
```

每个命令外层加 `timeout 90s`，没有触发超时；保留全部输出，没有按卡 tail 截掉。结果：

```text
origin push --dry-run:
Everything up-to-date
origin dry-run exit=0
mirror push --dry-run:
Everything up-to-date
mirror dry-run exit=0
```

原始输出 `fable-b4b.20261021-011143.03-push-dry-run.txt`，exit=0。干跑未改远端，没有配置、读取或抄录凭据。

## 四、就地修了什么

没有。未动集群、gitops 或 Harbor。B4 的自动回执归档修复按卡留待下一次真发布验证，本卡没有为此造发布；推送干跑也不替代将来真实 mirror 推送的验证。

回执、3 份原始输出和本卡归档一并本地提交并推 origin/fable；继续同箱 B5-1 卡。

exit=0
