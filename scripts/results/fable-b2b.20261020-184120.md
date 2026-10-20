# fable-b2b：父仓本机对象复用通过，子仓引用路径失败

2026-10-20，Asia/Shanghai；WS=fable，k8s 分支 fable。卡：[B2b 接续](../../docs/dev-investment-agent/switch-test/done/2026-10-20-fable-b2b-agent-continue.md)。**未完成 B2b，停在第二节 agent-deploy，exit=2；代理、render-check、边缘和总状态步骤未执行。** 既有 B2 物料和控制器通过证据保留，没有重做控制器安装或启停。

## 两个执行版本

1. 初始版本 `c126a36e0acb2413a43113039054404a0c055852`：前置、SSH、plan 通过。19:00 左右 GitHub SSH 克隆 k8s 下载停在 30,957,579 字节，Git/SSH 进程等待网络。此前本机同仓已打包对象 220.5 MiB 只是体量参考，并非已确认本次传输总大小。所有者随后明确要求停止当前 Make、拉取 f15a3e9f 的同一卡。通过原执行会话发送 Ctrl-C，中断后外层记录 exit=141，原日志未改写成 130 或删除；确认旧的 clone、SSH、index-pack 及部署进程全部退出。没有在旧进程仍运行时清目录。
2. 接续版本 `f15a3e9f59aec241ded5ebb3bb20e9f42766cdc5`：正常 --ff-only 拉取。按更新卡检查并清理代理 repos；当时目录已由 Git 中断清理为空，删除循环没有目标，最终数量 0。未触碰人的工位、主仓或应用文件。前置、SSH、plan 再通过，19:03:04 执行本机 reference 版 agent-deploy；七个父仓约一分钟全部克隆成功，随后子仓引用路径失败，19:04:18 Make exit=2。按卡停止，没有改源码、手工更新子仓或重跑失败 Make。

## 原始 stdout/stderr

| 日志 | 内容 | exit |
| --- | --- | --- |
| [01-preflight](fable-b2b.20261020-184120.01-preflight.txt) | c126a36e：HEAD、insteadOf、控制器 status、SSH | 0 |
| [02-agent-plan](fable-b2b.20261020-184120.02-agent-plan.txt) | c126a36e：代理 plan | 0 |
| [03-agent-deploy](fable-b2b.20261020-184120.03-agent-deploy.txt) | c126a36e：远端全量克隆，被所有者要求中断 | 141 |
| [04-refresh-and-cleanup](fable-b2b.20261020-184120.04-refresh-and-cleanup.txt) | f15a3e9f：旧进程均已退出、代理目录清理前后 | 0 |
| [05-preflight-and-plan](fable-b2b.20261020-184120.05-preflight-and-plan.txt) | f15a3e9f：HEAD、控制器 status、SSH、代理 plan | 0 |
| [06-agent-deploy-local-reference](fable-b2b.20261020-184120.06-agent-deploy-local-reference.txt) | f15a3e9f：七个父仓成功，18 个子仓引用路径失败 | 2 |
| [07-stop-diagnostics](fable-b2b.20261020-184120.07-stop-diagnostics.txt) | 停点进程列表、代理 journal、服务状态、父仓 HEAD、两个子仓实际对象库、入口检查 | 0 |
| [08-source-child-reference](fable-b2b.20261020-184120.08-source-child-reference.txt) | 18 个源子仓实际 common-dir 与父仓推导路径，只读核对 | 0 |
| [09-submodule-state](fable-b2b.20261020-184120.09-submodule-state.txt) | 六个父仓的 18 个子仓均为 `-` 开头，尚未初始化成功 | 0 |

所有原文完整保存，未裁剪失败输出。原生 `git submodule update` 自身在缺少 reference 时打印了 Retry scheduled 和第二次失败；没有在 Make 外增加重试。07 的卡原命令 `ps ... | grep 'git '` 会命中诊断包装 shell 自己，08 又按精确可执行名核对，实际 Git/SSH/Make/Ansible 进程均无残留。

执行方式修正：卡中 `grep -c insteadOf` 实际为 5，因为包括两行注释；排除注释后三条实际 Git 命令都有改写，按同一判据核对为 3。SSH 不经 head 管道，使用 `-n` 并检查真实退出码 1 及 successfully authenticated，避免记录到 head 的退出码。没有改通过标准。

## 新失败与远程需修之处

失败任务 `Check out each submodule over SSH, objects copied from the source workspace`，源 `infrastructure/jenkins/tasks/workspace.yaml:77`。第 92 行构造 reference 时，名称剥离没有生效，实际参数与错误为：

```text
--reference /home/zymun/master/tpl-app/.git/modules/submodule.tpl-web-frontend.path
fatal: reference repository '/home/zymun/master/tpl-app/.git/modules/submodule.tpl-web-frontend.path' is not a local repository.
make: *** [Makefile:195: jenkins-agent-deploy] Error 2
```

只修名字还不够：源工位是 Git worktree，实际子仓对象库不能统一按父仓 common-dir + modules 推导。只读执行子仓自身的 `rev-parse --path-format=absolute --git-common-dir`，例如：

```text
/home/zymun/master/tpl-app/.git/worktrees/tpl-app1/modules/tpl-backend
/home/zymun/master/knowbench-app/.git/worktrees/knowbench-app1/modules/knowbench-backend
```

父仓 common-dir 推导出的 `/home/zymun/master/tpl-app/.git/modules/tpl-backend` 与 tpl-admin-frontend 位置不存在；其它部分推导路径虽存在，也不是当前源工位子仓实际返回的位置。08 保留全部 18 个子仓的原始核对，交远程修复，未在本地改实现或复制对象补洞。卡中“九个子仓”为数量笔误，实际六个应用各三个，共 18 个。

## 已有副作用与保留状态

- 七个代理父仓均已克隆，k8s 为 f15a3e9f。七者 `objects/info/alternates` 均不存在，已与源工位对象库断开依赖；其余父仓 HEAD 见 07。保留它们供接续，不再删除。
- 子模块初始化操作已尝试但全部失败，可能已写父仓本地子模块注册配置和空目录；09 全部为 `-`，不能宣称子仓已就绪。
- `.venv`、`.tools/bin`、代理单元均不存在；代理 `LoadState=not-found`、`ActiveState=inactive`，journal 无条目。尚未进入工具安装和启动步骤。
- JRE、agent.jar 和节点密钥沿用 B2 既有准备，由原剧本验证；本轮未生成应用身份，未运行渲染。
- 控制器 `active/enabled`、WantedBy=sunmoon-platform.target；证书正常校验的经入口检查：Jenkins login 200、Harbor health 200。未动控制器启停、内网入口、集群或 Harbor 数据。

第三节无成功构建或 diff.txt，第四节边缘证书与 platform-status 未执行，所有者走查也未执行。本轮仅提交回执、原始日志、卡归档与远程请求；归档是交回本轮执行，不代表通过。已请求远程保留父仓、修复子仓路径再给接续卡。原始日志保留工具自带的行尾空白，未为格式检查改写；秘密模式扫描只作有限检查，不读取实际秘密比对。

exit=2
