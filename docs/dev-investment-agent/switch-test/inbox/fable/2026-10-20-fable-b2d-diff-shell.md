# B2d：触发修复通过，强制 #7 在差异 shell 阶段失败

WS=fable，执行 eca20738。控制器/代理 status=0；定时 #1 已 FAILURE（duration=2795696 ms），按卡允许继续第三节。一次手动触发成功，#7 FORCE=true，执行 eca20738；六应用的 deployment-plan 与 render 均走过，12 份 Ansible recap failed=0。最后 #7 FAILURE、duration=697529 ms，Make exit=2，已停止，无构建重试或代码改动。

直接失败：`ci/render-check.groovy:48` 的 sh 块未指定 Bash，第 49 行 `set -o pipefail` 在本机默认 /usr/bin/dash 下报 `Illegal option -o pipefail`。定时 #1 与强制 #7 都有该证据。请远程修实现后给第三节接续卡；代理安装、物料和控制器不重做。

请顺便核对差异输入路径：第 53 行读取 repo 根 `.build/components/app-platform/`，实际存在的候选为 `infrastructure/.build/components/app-platform/`，前者不存在。因 pipefail 先失败，该循环尚未执行，未擅自改形状或把这一点写成已跑出的第二次失败。diff.txt 未创建，产物归档未到达。

完整控制台保留在本机 `/home/zymun/worktrees/fable/k8s/infrastructure/.build/jenkins/render-check-7.log`，不进 Git；[回执与八份原始输出](../../../../../scripts/results/fable-b2d.20261020-192854.md) 含末 40 行、#1–#8 结果与 duration、12 个应用命令核对、路径事实和身份任务状态观测。#1 duration 包含约 40 分钟等代理上线，实际上线后至结束约 6 分半，B3 定超时请区分；#7 也含等待 #6 的时间。

第四节边缘、第五节 platform-status、第六节所有者走查均未执行。控制器和代理 active/enabled，入口 Jenkins/Harbor 仍 200；代理跟踪文件干净，gitops/sources 无 diff。并发属性仍待 B3 的控制器重启流程，本轮没重启。卡归档只是本轮交回，B2 未通过。
