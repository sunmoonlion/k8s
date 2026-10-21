# fable-c0c 回执：固定 eth0 后两次开机网络验收通过（luna）

WS=fable，分支 fable；按 `cf426f066` 卡执行。目标仅为 `sunmoon-prod`（`sunmoon@192.168.80.10`）。执行前 `vmrun -T ws list` 确认该 VM 正在运行，SSH 可连。

在来宾 `/etc/default/grub` 保留原文件备份 `/etc/default/grub.before-c0c`，配置 `GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0 "` 并运行 `update-grub`，exit=0。未禁用 wait-online、未 reset-failed、未改 netplan 或 WSL/开发集群。

之后两次通过 SSH 执行 `sudo systemctl reboot`。来宾 journal 的启动记录（UTC）为 11:17:40 与 11:18:35，即 CST 19:17:40 与 19:18:35。两轮均在约 45 秒后恢复 SSH。两轮都通过卡片标准：内核命令行含两个参数；wait-online 为 active；失败单元 0；journal 无超时、无网卡改名记录；`network-online.target` 分别在 9.575 秒和 9.794 秒到达；`eth0` 为 `192.168.80.10/24`，默认路由经 `192.168.80.2`。

## 第一轮原始输出

见 [第一轮原始输出](fable-c0c.round1.20261021-1917.txt)，逐字保留命令输出。

## 第二轮原始输出

见 [第二轮原始输出](fable-c0c.round2.20261021-1918.txt)，逐字保留命令输出。

## 应答 ISO

模板已经包含 `updates: none` 与 GRUB late-command。更新 `C:\iso\sunmoon-prod-seed.iso` 时，为避免把控制台口令读出或写入命令记录，基于旧 ISO 中已有的口令哈希保留身份字段，只合并模板中的 `updates: none` 和 GRUB late-command，再重建 ISO。重新提取 YAML 验证了这两个字段和原口令哈希相同；口令和哈希均未进入回执。旧镜像备份为 `C:\iso\sunmoon-prod-seed.iso.before-c0c`。

新 ISO：380928 bytes，SHA256 `3770d53859dee1a1eeaa78cda33016ee3c498f482dcc4dbbcaf1b0886cf773ae`。备份 SHA256 `397392dc97a40d93fec134225242b54249af9a4596db39e69a17bfdd5359cc39`。

## 结论

两次重启均符合卡片验收项；保留原样的 wait-online 在两轮中都正常完成，失败单元为 0。没有就地修改仓库模板或其他运行机制。卡移到 `done/`。

exit=0
