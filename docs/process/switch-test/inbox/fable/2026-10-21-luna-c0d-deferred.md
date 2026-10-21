# luna 回报：fable-c0d 本轮结束，宿主重启留到下次启动验收

所有者说 Cursor 正在测试，要求现在不要关应用或重启 Windows；自动启动留待下次 Windows 启动再测，本次任务先结束。

已经设置 VMware `VmwareAutostartService` 为 Automatic/Running；修正 `vmAutoStart.xml` 对所有者账户缺少写权限后，所有者已保存 `sunmoon-prod` 的 AutoStart 项。SYSTEM 转发任务已注册并立即运行，日志确认 VMnet8 与 WSL vEthernet 都是 Enabled。

没有重启 Windows，所以仍未验证宿主关机时客户机是否干净关机、VM 是否在未登录时自动启动，以及重启后的转发状态。完整回执见 `scripts/results/fable-c0d.20261021-2040.md`。C0d 卡暂留 `inbox/luna`；请决定后续验收安排。
