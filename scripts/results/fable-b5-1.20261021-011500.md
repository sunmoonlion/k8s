# fable-b5-1 回执：入口收敛验证（luna）

WS=fable，分支 fable，2026-10-21 Asia/Shanghai。基线 `50364e31b`（B5-1 实现在 e392b80bc，前一张 B4b 回执随后提交）。起始只有本卡新原始输出，既有工作区干净。结果 **pass**。

## 一、公开入口与旧名

`git pull --ff-only origin fable` exit=0，已是最新。按卡对新旧目标运行 `make -n <目标> OBJECT=app-platform/tpl-app APP=tpl`：

| 目标 | 结果 | exit |
| --- | --- | --- |
| platform-plan | ok | 0 |
| platform-config | ok | 0 |
| platform-status | ok | 0 |
| platform-stage | ok | 0 |
| platform-build | ok | 0 |
| platform-deploy | ok | 0 |
| platform-check | ok | 0 |
| platform-start | ok | 0 |
| platform-stop | ok | 0 |
| components-render | ok | 0 |
| components-stage | ok | 0 |
| components-validate-release | ok | 0 |
| application-deployment-plan | ok | 0 |
| application-check | ok | 0 |
| application-check-public | ok | 0 |
| application-bootstrap | ok | 0 |
| services-bootstrap | ok | 0 |
| flux-release | ok | 0 |
| flux-source-apply | ok | 0 |
| flux-source-status | ok | 0 |
| jenkins-agent-check | ok | 0 |
| jenkins-release-run | ok | 0 |
| topology-render | ok | 0 |
| application-render | gone（No rule to make target） | 2 |
| application-stage | gone（No rule to make target） | 2 |
| application-validate-release | gone（No rule to make target） | 2 |
| services-render | gone（No rule to make target） | 2 |
| services-stage | gone（No rule to make target） | 2 |
| services-validate-release | gone（No rule to make target） | 2 |

合计 23 ok、6 gone。旧目标的 exit=2 是卡要求的正常删除结果，额外精确检查报错包含 No rule，避免把其它失败误判为 gone。`make help` exit=0，第一行为：

```text
== 公开入口（按总纲的层；各模块底层入口见对应 README）==
```

原始输出 `fable-b5-1.20261021-011500.01-entry-verification.txt`，exit=0；保留完整 help 文本，没有用 head 管道引入 SIGPIPE。这里使用 Python 逐项捕获 make 的返回值，执行与卡同一组目标和参数；没有实际 build/deploy/start/stop。

## 二、render-check 与平台状态

实际命令 `make -C infrastructure jenkins-agent-check`，本机原始输出 `fable-b5-1.20261021-011500.02-render-check.txt`，exit=0。仅触发一次，默认 FORCE=true；等待日志里的 RETRYING 是同一次构建轮询。

```text
build: 43
name: #43 fable@50364e31ba
result: SUCCESS
seconds: 366
console: infrastructure/.build/jenkins/render-check-43.log
```

完整 consoleText 保留本机忽略目录，不提交整份控制台。六个应用迁移头核对及候选渲染完成；日志核对原文：

```text
827:+ make -C infrastructure components-render OBJECT=app-platform/tpl-app
1815:+ make -C infrastructure components-render OBJECT=app-platform/knowfeed-app
3004:+ make -C infrastructure components-render OBJECT=app-platform/knowbase-app
4199:+ make -C infrastructure components-render OBJECT=app-platform/knowbench-app
5766:+ make -C infrastructure components-render OBJECT=app-platform/knowlab-app
7071:+ make -C infrastructure components-render OBJECT=app-platform/knowmart-app
8084:Finished: SUCCESS
```

精确核对六个新调用按约定应用顺序齐全、整份日志不含 application-render；代理 k8s 的 `git status --short --untracked-files=no` 为空；差异产物 `infrastructure/.build/render-check/diff.txt` 0 字节、0 行。原始核对输出 `fable-b5-1.20261021-011500.03-render-evidence.txt`，exit=0。

`make -C infrastructure platform-status` exit=0，原始完整输出 `fable-b5-1.20261021-011500.04-platform-status.txt`。最后一项原生部署状态查询 recap：ok=7 changed=0 unreachable=0 failed=0；只是读状态，没有部署。

## 三、就地修了什么

没有。未重启控制器，任务体从分支读取新入口即可执行；本卡没有验证 03 引导模板下次重启时的自更新。未改集群、gitops 或 Harbor，也没有为旧构建选择测试的既有失败扩展测试范围。

前一张 B4b 已单独在 `50364e31b` 提交并推到 GitHub/Gitee。此卡回执、4 份原始输出与卡移动同样独立提交推 origin/fable，最终核对两个服务器分支；不同步其它工位。

exit=0
