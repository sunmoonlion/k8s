# 现有数据盘扩容至230 GiB

状态：Linux准备完成，可交Windows Cursor执行下节；尚未扩盘，原六节点停止。100 → 230 GiB，240/260 GiB方案作废。

## Windows管理员执行交接

Linux放行检查已返回ready=true、UUID正确、target_bytes=246960619520。Docker/socket/containerd与空间监控已停；PID1及udevd/resolved/logind私有命名空间中的三个新数据挂载均已正常卸载，无强制/lazy卸载。旧/data/kind-local-storage未动。

扩盘备份位于系统盘 `/var/backups/sunmoon-data/preexpand-230-20260928-v1`：18712文件、6432种内容均通过摘要核对，新增22910074564B；其清单引用已验证 `/var/backups/sunmoon-harbor/host-managed-20260927-v1` 的完整文件与归档成员，两个备份必须一起保留。新组合备份尚未独立整盘恢复演练；resize_backup.py restore仅写固定新系统盘目录，空间不足会拒绝。

交给Windows Cursor（已获所有者授权扩至230GiB）：

1. 使用Ubuntu所属用户的管理员PowerShell。保持sunmoon-data-mount禁用及maintenance标记；不关闭WSL、不再次压缩、不初始化磁盘。
2. 固定来源 `\\wsl.localhost\Ubuntu\opt\sunmoon\admin\storage\storage-20260928-v3`；目标 `C:\wsl-disks\scripts\storage-20260928-v3`。
3. 先核来源manifest.json SHA256为 `0f2f4eae32b2e43003e7be5b825090cd4c0ffa02438e47bb4add6e3fe77d10ec`。按manifest逐文件核SHA，复制到目标并再核；已存在文件只接受相同字节，不覆盖差异。manifest本身一并复制。不要复制工作树的未固定版本。
4. 目标目录ACL：Administrators与SYSTEM完全控制，所属用户读取/执行；子文件继承，普通用户不可写。只调整该新发布目录，不修改其它目录或旧副本。
5. 对目标下所有.ps1先用System.Management.Automation.Language.Parser检查语法，错误则停止反馈。随后执行：

```powershell
$ErrorActionPreference = 'Stop'
$Script = 'C:\wsl-disks\scripts\storage-20260928-v3\expand-sunmoon-data.ps1'
$Digest = '0f2f4eae32b2e43003e7be5b825090cd4c0ffa02438e47bb4add6e3fe77d10ec'
& $Script -ManifestSha256 $Digest
& $Script -ManifestSha256 $Digest -Apply
```

脚本重新检查真实C容量、所有摘要、禁用任务的身份与动作、Linux放行；再分离指定数据VHDX、DiskPart扩容、bare附加，Linux核原UUID和230GiB无分区块设备后执行离线e2fsck/resize2fs并恢复挂载。只把任务动作改到新版，仍保留禁用和维护标记。不会启任何业务服务，也不启Docker。任何错误停止并贴回；部分完成不能盲目重跑或缩回100GiB。

6. 贴回Parser结果、DiskPart结果、Linux grow/mount检查及最后JSON。由Luna核全量内容、恢复节点/Harbor并实际拉取后，才解除维护标记、启用新任务与监控。Windows步骤成功不能代替这些验收。

## Windows Cursor现在可做：只读容量检查

在Windows PowerShell执行以下只读脚本，把JSON结果贴回。不关闭WSL、不分离磁盘、不启动服务；扩盘执行放行另行通知。

```powershell
$ErrorActionPreference = 'Stop'
$Repo = '\\wsl.localhost\Ubuntu\home\zymun\worktrees\luna\k8s'
& "$Repo\sunmoonai\operations\space\windows-capacity.ps1"
Get-ScheduledTask -TaskName sunmoon-data-mount -TaskPath '\' |
    Select-Object State,@{N='Enabled';E={$_.Settings.Enabled}},Actions |
    ConvertTo-Json -Depth 4
```

Windows Cursor于2026-09-28T14:41:36Z只读回报：C空闲271665676288B，数据VHDX长度与实际占用均93050634240B。目标230GiB长满后预计C剩109.67GiB，再预留22GiB后剩87.67GiB，比50GiB底线多37.67GiB。旧查询脚本Math.Max的32位重载错误已改为显式int64，修正版尚待Windows重跑。挂载任务Disabled，动作仍为storage-automation-20260928-v2的隐藏launcher。正式门槛使用Windows实际分配量，扣除新增备份/临时空间、系统增长和元数据余量后仍保留至少50GiB。动态上限不代表立即占用230GiB；此盘与系统盘仍在同一块物理C盘，不防硬件故障。

## 待完成的执行准备

1. 核数据盘现有约60.4GiB内容的备份覆盖。备份不能只放在被扩容的数据盘上；记录镜像文件、数据库、密钥、配置的恢复来源。
2. 将原100GiB挂载限制及创建参数、监控容量预算、Harbor备份和正式建群门槛同步升级。固定管理副本发布新版本，连同自动任务的摘要引用更新，保持登录一次触发与隐藏窗口。
3. 服务保持停止，暂停只读监控，sync，精确卸载/data/kind-clusters、/data/harbor和/mnt/sunmoon-data；检查所有挂载命名空间无占用。不能使用强制或lazy卸载。
4. Windows管理员分离指定数据VHDX，扩至230GiB，重新bare附加。通过原UUID唯一定位设备，核230GiB和原ext4，未挂载检查后扩展文件系统。任何检查不符即停，绝不重新格式化。
5. 恢复两处绑定及PID1/Docker可见性，核镜像完整摘要、备份与配置，恢复原六节点、Harbor和实际拉取；再解除维护标记、启用挂载任务与监控。

禁止操作旧/data/kind-local-storage挂载、删除旧节点/卷、缩容或运行初始化脚本。当前旧入口保持，外置Harbor候选和SNI代理继续停止。完成此次维护不代表正式外置Harbor的三场景持久化验收通过。

规则核对：C-D1保留权威数据及恢复来源；C-I8身份/容量/挂载检查不通过即停止；发布规则保持既定服务版本，不变更镜像或入口。

官方依据：[DiskPart expand vdisk](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/expand-vdisk)要求虚拟磁盘已分离；[resize2fs](https://man7.org/linux/man-pages/man8/resize2fs.8.html)扩展ext4，不能以VHDX容量增加替代文件系统扩展。
