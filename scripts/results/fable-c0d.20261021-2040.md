# fable-c0d 回执：自动启动与转发配置已设，Windows 重启验收延期（luna）

WS=fable，分支 fable。所有者明确要求：Cursor 当前在测试，本轮不关闭应用、不重启 Windows；留待下次 Windows 启动验收，本次任务先结束。故不把宿主重启、VM 无人值守启动、关机干净程度或重启后转发状态记为通过。

## 已完成

- 实测 VMware Workstation 26H1u1 的 `VmwareAutostartService` 存在。已将服务设为 Automatic 并启动，确认 `Running / Automatic`。
- 第一次保存 AutoStart 列表时 VMware 报错。截图显示 `vmAutoStart.xml` 不存在或无写权限。只读检查发现文件存在，所有者 SYSTEM，原有权限不允许 `zymun\zymun` 写入；仅对这个 XML 文件给该账户增加了 Write ACE。之后所有者重试成功，文件内容已确认包含 `C:\VMs\sunmoon-prod\sunmoon-prod.vmx`，startOrder=1。
- 已新增 `Enable-SunmoonForwarding.ps1` 与 `Register-SunmoonForwardingTask.ps1`。SYSTEM 计划任务 `Sunmoon-ProdVm-Forwarding` 已注册为开机触发，每 10 分钟重复一天，并立即运行。其日志确认仅操作两张目标接口：VMnet8 保持 Enabled；`vEthernet (WSL (Hyper-V firewall))` 从 Disabled 变为 Enabled。
- 注册器第一次执行末尾的验证因 `LastRunTime` 时间比较误判而返回 exit=1；但同一执行记录到任务 `State=Ready`、`LastTaskResult=0`，转发日志也记录两张接口成功。已修正仓库中的验证逻辑，改为核对本次新增的两条接口日志和任务 XML 中的开机/重复设置；修正后的验证逻辑本轮未重跑，避免再次打扰所有者的 Cursor 测试。

## 未完成的验收

本轮没有重启 Windows。下次宿主启动时需确认 VMware Autostart Service 实际启动 VM、来宾干净关机记录、来宾启动时间，以及转发任务启动后的两接口状态。卡片暂留 `inbox/luna`，请 Fable 按所有者要求决定后续续办方式。

exit=0
