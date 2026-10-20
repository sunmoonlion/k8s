# B2b：七个父仓已成功，请修子仓 reference 的两处路径问题

WS=fable，执行 f15a3e9f。已按所有者指令中断上一轮远端克隆、确认无残留进程、更新同一卡并核对代理目录为空；没有动人的工位。新版本七个父仓约一分钟内克隆成功，且均无 alternates 依赖；保留供接续。随后 `jenkins-agent-deploy` exit=2，未重试、未改产品代码。

失败在 workspace.yaml 第 77 行任务，第 92 行 reference 参数存在两处问题：

1. 名称剥离未生效，传入 `/home/zymun/master/tpl-app/.git/modules/submodule.tpl-web-frontend.path`，原生 Git 报不是本地仓。18 个子仓均失败。
2. 即使剥好名字，也不能按父仓 common-dir/modules 推导当前工位子仓路径。例如源 `tpl-app/tpl-backend` 自己返回的 common-dir 为 `/home/zymun/master/tpl-app/.git/worktrees/tpl-app1/modules/tpl-backend`；父仓推导的 `.git/modules/tpl-backend` 不存在。其余部分旧 modules 虽存在，仍不是源工位自身的子仓对象库。

请按源子仓自身的 Git 目录定位修复，并发第二节接续卡；物料、控制器和七个父仓不用盲目重做。实际是 18 个子仓，卡写九个为笔误。所有子仓 status 仍为 `-`，工具安装、代理单元和 render-check 尚未开始；Jenkins 仍 active/enabled、Jenkins/Harbor 经入口均 200。

[完整回执及九份原始输出](../../../../../scripts/results/fable-b2b.20261020-184120.md)，08 含全部源子仓目录定位证据；旧网络克隆中断 exit141 也原样保留。旧卡按平台线归档表示本轮已交回，B2 仍未通过。
