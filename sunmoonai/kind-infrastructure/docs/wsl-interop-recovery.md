# WSL调用Windows程序：检查与恢复

2026-09-28维护后发现PowerShell调用报`Exec format error`。现场`/etc/wsl.conf`的interop.enabled=true、binfmt全局enabled、/init及会话套接字存在，但`/proc/sys/fs/binfmt_misc/WSLInterop`缺失。谁删除了注册项尚未查明；不能把它归因于家庭网络。

WSL在/run/systemd/generator中已生成`:WSLInterop:M::MZ::/init:P`恢复规则，但本机Ubuntu的systemd-binfmt附加条件`ConditionVirtualization=!wsl`使该服务跳过，因此该恢复规则未执行。依据[微软互操作实现说明](https://github.com/microsoft/WSL/blob/master/doc/docs/technical-documentation/interop.md)和[systemd保护说明](https://github.com/microsoft/WSL/blob/master/doc/docs/technical-documentation/systemd.md)，本次仅补回缺失注册；未覆盖其它binfmt条目或重启WSL/Docker/集群。

实际隐藏窗口PowerShell调用返回5.1.26100.9444，退出0。首次stderr含中文CLIXML进度消息，Python text=True按UTF8解码报错；再次按原始字节捕获，确认Windows命令本身成功。项目容量查询只解析stdout，避免进度文本被当成业务JSON；不要把编码异常说成互操作仍断开。

## 日常入口

```bash
# 默认只检查；缺失时给出计划。
python3 -B sunmoonai/kind-infrastructure/mount/wsl_interop.py
# 仅在确认需要恢复时，使用已发布的固定副本。
sudo python3 -B /opt/sunmoon/admin/wsl-interop/3aa688cbe9135143/wsl_interop.py --apply
systemctl status sunmoon-wsl-interop.service
```

已启用`sunmoon-wsl-interop.service`，每次开机执行一次，在Docker之前、原systemd-binfmt之后检查。没有定时器、轮询或Windows程序调用。脚本核对WSL环境、用户未禁用interop及WSL生成规则，只补缺失的WSLInterop；遇到已有但不同/停用条目或全局禁用则拒绝，不自行覆盖。

本次服务实际执行成功，现有条目被保留；**尚未为此再做完整重启验收**。若运行中其它程序再次删除注册，开机检查不会实时修复，需用上面的显式入口并追查删除者。Linux可调用Windows不等于获得Windows管理员权限；管理员操作仍需已有授权及对应Windows权限。

撤销开机检查：`sudo systemctl disable sunmoon-wsl-interop.service`。这不删除当前WSLInterop、不停服务。固定发布副本和本次私有回执先保留到迁移收尾。
