# fable-b2d：手动触发已通，强制构建 #7 在差异阶段失败

2026-10-20，Asia/Shanghai；WS=fable，k8s 分支 fable，执行版本 `eca20738276b5b4d179c261e3fa307053cd9bfe9`。任务卡：[B2d](../../docs/dev-investment-agent/switch-test/done/2026-10-20-fable-b2d-render-check.md)。

**B2 未通过。** 第一节服务核对通过；第二节定时 #1 已有终态，按卡允许其 FAILURE 后继续第三节。手动 POST 及队列轮询已通过，强制构建 #7（FORCE=true）执行 eca20738，结果 FAILURE、duration=697529 ms，`jenkins-agent-check` 最终 exit=2。失败位于六应用渲染之后的差异阶段，默认 sh 不支持 `set -o pipefail`。已按卡停止，没有重试构建、改代码、重启/重装控制器或代理。第四节边缘、第五节总状态、第六节所有者走查未执行。

## 原始输出

| 日志 | 范围 | exit |
| --- | --- | --- |
| [01-preflight](fable-b2d.20261020-192854.01-preflight.txt) | HEAD、请求头表达式、controller status、agent status 均通过 | 0 |
| [02-initial-build-state](fable-b2d.20261020-192854.02-initial-build-state.txt) | 第二节 #1–#8 持久化元数据，#1 已 FAILURE | 0 |
| [03-forced-render-check](fable-b2d.20261020-192854.03-forced-render-check.txt) | 唯一一次 `make -C infrastructure jenkins-agent-check`，构建 #7 FAILURE | 2 |
| [04-timer-identity-observations](fable-b2d.20261020-192854.04-timer-identity-observations.txt) | 定时 #1 身份准备任务名称/状态提取，不输出身份值 | 0 |
| [05-forced-console-tail](fable-b2d.20261020-192854.05-forced-console-tail.txt) | 保存的 #7 consoleText 原文末 40 行及完整日志路径 | 0 |
| [06-final-build-and-service-state](fable-b2d.20261020-192854.06-final-build-and-service-state.txt) | 最终 #1–#8 元数据、目录事实、单元及内网入口只读探针 | 0 |
| [07-render-stage-observations](fable-b2d.20261020-192854.07-render-stage-observations.txt) | #7 的 12 条应用命令及 recap、身份任务状态观测 | 0 |
| [08-agent-worktree-state](fable-b2d.20261020-192854.08-agent-worktree-state.txt) | 代理 k8s HEAD、跟踪文件状态、gitops/sources 无 diff | 0 |

原始 stdout/stderr 与实际退出码完整保留，未裁剪或覆盖；原生 Ansible 的等待重试是在轮询同一个构建，不是重新触发构建。未读取、抄写管理员口令或 crumb/cookie，保留 no_log 与证书校验。

## 定时构建与耗时

| 构建 | result | duration（ms） | 显示的提交 |
| --- | --- | --- | --- |
| #1 | FAILURE | 2795696 | a686ce59fe |
| #2 | NOT_BUILT | 2208330 | a686ce59fe |
| #3 | NOT_BUILT | 1622036 | a686ce59fe |
| #4 | NOT_BUILT | 1034662 | a686ce59fe |
| #5 | FAILURE | 798637 | 63f7fe6afb |
| #6 | FAILURE | 576994 | eca2073827 |
| #7（本次强制） | FAILURE | 697529 | eca2073827 |
| #8 | NOT_BUILT | 362802 | eca2073827 |

#1 start=18:36:00.195，finish=19:22:35.891；duration=46 分 35.696 秒。代理直到 19:16:03 才 Connected（上轮 B2c journal），所以这个 duration 包含约 40 分钟等待代理，不能直接当作纯渲染耗时；上线至完成约 6 分半，是时间点推算。#7 的 11 分 37.529 秒也包含等待 #6 释放执行器的时间。原始毫秒值供 B3 定超时。

第二节卡的 `[ -f "$f" ]` 在 sudo 之外，普通用户不能遍历私有 JENKINS_HOME，会跳过已有记录；改为整个只读元数据查询在 sudo -n 下完成，仅提取 result/duration/displayName 等字段，没有改判据。

## 第三节失败证据

完整控制台由原剧本保存，留本机 .build、不进 Git：

```text
/home/zymun/worktrees/fable/k8s/infrastructure/.build/jenkins/render-check-7.log
```

定时 #1 已完成控制台另留本机 `infrastructure/.build/jenkins/timer-render-check-1.final.log`（0600，不入 Git）。#7 的原始末 40 行见 05，关键原文：

```text
[Pipeline] { (候选与已提交的差异)
[Pipeline] sh
+ set -o pipefail
/mnt/sunmoon-data/jenkins/repos/k8s@tmp/durable-9f5af81c/script.sh.copy: 2: set: Illegal option -o pipefail
ERROR: script returned exit code 2
Finished: FAILURE
```

调用剧本 Report the build result 显示 build=7、name=#7 fable@eca2073827、result=FAILURE、seconds=697，随后 Require the check to pass 失败，Make exit=2。请求头修复已由真实触发验证，旧 HTTP 400 没有复现。

`ci/render-check.groovy:48` 的 sh 块没有选择 Bash，第 49 行用了 pipefail；本机 `/bin/sh` 解析为 `/usr/bin/dash`，与实际报错一致。此前 tpl、knowfeed、knowbase、knowbench、knowlab、knowmart 各跑一次 deployment-plan 和 render，12 份 Ansible recap 的 failed 均为 0；差异文件尚未创建、archiveArtifacts 与最后的工作区恢复阶段未到达，不能宣称有 diff.txt。

还发现一项需远程一并核对的路径事实：该差异脚本第 53 行读 repo 根的 `.build/components/app-platform/`，实际候选在 `infrastructure/.build/components/app-platform/`。06 的只读结果为前者不存在、后者存在。该循环尚未执行，本轮不声称已经运行证明其另一次失败，也不修改本地形状。

## 身份与当前状态

04 从 #1、07 从 #7 各提取到 119 条匹配的身份生成/恢复/备份任务状态，提取记录中 changed 均为 0。它们只是日志观测，不是对私有身份文件的前后逐字节比对；没有读取秘密来比较。渲染按模块约定准备私有输入和候选，不构建/发布镜像、不写库、不改集群或 Harbor 数据。

控制器和代理均 active/enabled，代理 User=zymun、NRestarts=0；WantedBy=sunmoon-platform.target。停点后的 CA 与主机名校验探针 Jenkins login 200、Harbor health 200，仅为内网只读诊断，未冒充卡的边缘/全局验收。代理工作树的跟踪文件干净，gitops 与 sources 无 diff。控制器并发属性补丁仍等待 B3 的重启流程生效，本轮未修改运行任务配置。

已写 `inbox/fable/2026-10-20-fable-b2d-diff-shell.md` 请求远程修流水线的 shell 和核对候选路径。旧卡归档表示本轮交回，B2 尚未通过；只提交回执、原始输出、卡移动和远程请求，不提交产品代码或完整控制台。秘密格式检查为有限扫描，不代表全面泄漏审计。

exit=2
