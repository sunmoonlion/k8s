# 宿主存储与容量

> 所在层：3 宿主层——数据盘与开机、账号维护、整个平台的对象选择（对象选择是交付链的事，D 段随渲染层搬）（[总览表](../README.md)）

本模块负责宿主预检、容量守卫及[整套生命周期](lifecycle.md)编排；部署入口已实际验证，统一启停及Windows任务已安装、实际停止/恢复已执行；开机与完整持久化验收仍待完成。数据盘附加、整套开机恢复和运行期监控的交付状态见[验收边界](../../docs/design/pending-after-migration.md)（104–109）。

## 数据布局

动态ext4数据盘为`C:\wsl-disks\sunmoon-data.vhdx`，上限230GiB；文件系统挂到`/mnt/sunmoon-data`，子目录分别bind到`/data/kind-clusters`和`/data/harbor`。UUID、挂载点、fsroot以[config.yaml](config.yaml)为准。严禁在原始`/data/kind-local-storage`上覆盖挂载。

各节点自己的static/dynamic目录由[cluster](../cluster/README.md)管理；Harbor实例独立于节点：停止或重建KIND不碰`/data/harbor`和Harbor容器，但关闭WSL、重启Docker或宿主磁盘故障仍会同时影响二者。数据盘和WSL系统盘最终同在C盘物理硬盘，同盘备份防误删和升级失败，不能防硬件故障。机器外数据库、对象原文和身份备份落点待所有者指定。

## 日常预检

```sh
make -C infrastructure preflight
```

前提是数据盘已由Windows侧附加。预检核对ext4、UUID和bind子目录；具体启动路径还会检查Docker可见的设备/inode，见[registry守卫](../registry/README.md#启动与故障恢复)。仅宿主findmnt正确不能证明Docker、systemd或节点所见目录正确。

检查失败时按[挂载与启动诊断](troubleshooting.md)处理。不得重新初始化已有VHDX或在缺失挂载时创建同名系统盘数据目录启动服务。

## 容量如何计算

容量任务读取Windows C盘实测剩余、VHDX实际分配量、配置最大230GiB及操作预算。计算：

`预计余量 = C盘实测剩余 - max(最大容量 - 数据盘实际分配量, 0) - 本操作新增预算`

当前开发底线为10GiB。底线校验与缓存/数据文件系统可用空间校验均需通过；释放ext4文件不意味着Windows VHDX立即缩小。容量读取失败须先修复WSL/Windows调用或数据来源，不能凭上次读数放行。

数据盘扩容与磁盘文件压缩是人工维护，步骤见下面两节；本模块没有自动压缩或扩盘入口，WSL自动收缩未启用。

## 字段与改动边界
当前值以[config.yaml](config.yaml)为准，手册维护字段职责，不再复制一套默认值。

| 字段 | 类型 | 维护条件 |
|---|---|---|
| `storage_uuid` | 文本/表达式 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `storage_mounts` | 列表 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `windows_powershell` | 文本/表达式 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `data_vhd_windows_path` | 文本/表达式 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `data_vhd_maximum_gib` | 整数 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `windows_minimum_free_gib` | 整数 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `windows_script_directory` | 路径 | 普通容量助手与管理员安装审阅副本；容量助手须与root运行副本一致。 |
| `host_runtime_dir` | 路径 | root持有的独立运行副本，变更须维护安装；不从worktree执行开机恢复。 |
| `wsl_distribution` | 文本 | 必须与所有者的Ubuntu发行版一致，不能更换账号创建另一套WSL。 |
| `host_boot_enabled` | 开关 | 经platform-enable-boot生效；只有单次开机恢复，无分钟调度。 |
| `windows_admin_directory` | 路径 | 管理员持有的不可变任务发布目录；与普通容量/审阅目录分开。 |

`data_vhd_maximum_gib`须与真实VHD一致，改数字不会扩盘；`windows_powershell`和`windows_script_directory`用于只读容量采集，不是管理员附盘或自动挂载调度器。UUID/目录属于存储身份，变更必须重新核对各服务可见性。

## 数据盘扩容

2026-09-28从100GiB扩到230GiB时的做法；要再扩时照此写维护卡，所有者批准后执行。任何一步检查不符就停：不重新格式化、不初始化磁盘、不缩回，部分完成后不盲目重跑。

1. 按上节公式用新上限重算容量；把数据库、对象原文、身份与密钥备份到**数据盘以外**（同盘备份不算扩盘前的保护）。
2. 停服务（`platform-stop`）；创建维护标记`C:\wsl-disks\sunmoon-data.maintenance`，禁用`sunmoon-data-mount`任务并等运行实例结束；`sync`后精确卸载`/data/kind-clusters`、`/data/harbor`、`/mnt/sunmoon-data`——PID 1和udevd、resolved、logind的私有挂载命名空间里都要卸干净，不用强制或lazy卸载。
3. Windows管理员：分离数据VHDX → DiskPart `expand vdisk maximum=<MiB>`（[要求已分离](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/expand-vdisk)）→ 重新bare附加。
4. Linux：按原UUID唯一定位块设备，核新大小与原ext4；未挂载时`e2fsck -f`再[`resize2fs`](https://man7.org/linux/man-pages/man8/resize2fs.8.html)（VHDX变大不等于文件系统变大）；恢复挂载与两处bind，按[registry守卫](../registry/README.md#启动与故障恢复)核Docker与PID 1看到的目录。
5. 改[config.yaml](config.yaml)的`data_vhd_maximum_gib`为真实上限（改数字本身不扩盘）。
6. 移除维护标记、启用任务，`platform-start`、`platform-status`，核各服务数据与镜像拉取。

当时的扩盘、备份脚本（`resize_data.py`、`resize_backup.py`）是那一次100→230 GiB的一次性脚本，2026-10-16随`sunmoonai/`移出没有收进来，要参考到Git历史`9a2abf12:sunmoonai/kind-infrastructure/mount/`取。

## 空间回收与系统盘压缩

每一轮都是：只读盘点 → 精确清单（ID、路径、大小、恢复来源）交所有者批准 → 只删批准的 → 再盘点，报实际释放量。批准只覆盖清单里的那一批。

- **看哪里占空间**：`docker system df -v`按API口径看镜像与构建缓存（两者共享层，不能相加）；`df -B1 /`；`du`要设时限，跑不完就如实写没跑完，不编数字。
- **构建缓存**：限定builder、只清7天以上、排除InUse与共享的，例如`docker buildx prune --builder default --filter until=168h --filter 'private=""'`，不用`--all`。清理会刷新父缓存的使用时间，剩下的要等下一轮。
- **镜像**：只删能证明有恢复来源的——Harbor里有同一manifest摘要（按描述符字节算SHA256比对，不认标签），或有核过的离线tar；不加force、不递归删父镜像。KIND节点、容器、卷一律不动。
- **重复物料**：大小、SHA256、独立inode都核过才删副本，保留正式副本与来源回执；唯一离线来源和唯一备份不删。
- **系统盘压缩**：ext4里删掉文件不会让C盘变大，WSL系统盘`ext4.vhdx`（`%LOCALAPPDATA%\Packages\CanonicalGroupLimited.Ubuntu_*\LocalState\`下）要在维护窗口手动压缩：`platform-stop` → 维护标记与禁用任务 → `sudo fstrim -v /`（数据盘另`fstrim /mnt/sunmoon-data`） → Windows管理员`wsl --shutdown`并确认没有运行的发行版 → DiskPart `select vdisk file="<ext4.vhdx>"`、`compact vdisk`（[要求已分离或只读附加](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/compact-vdisk)）→ 记录压缩前后的文件长度与C盘空闲（两者不一定相等）→ 启动Ubuntu、预检、`platform-start`。压缩没有撤销，中途不要打断；DiskPart输出里有失败字样时，即使退出码0也不算通过。当时的压缩脚本（停旧KIND六个节点那一版）没有收进来，在Git历史`9a2abf12:sunmoonai/kind-infrastructure/mount/system_compaction.py`。

## 长期空间管理状态

已有：操作前峰值预算及部分容器日志轮转。待实现：常态容量监控与告警、统一查看/预览/执行、Harbor保留与GC、构建缓存、日志索引与备份轮换。策略先由所有者批准，保护在用镜像、回退版本和必要备份。

禁止把`docker system prune`、`docker volume prune`或`docker container prune`用于一般清理；旧kind节点/卷与新正式资产保持保护。Completed初始化Job也不是普通缓存。当前手册不启用新增定时删除。

## 账号维护

人工登录、平台管理员与程序身份的区别，以及按对象查看、首次预设、表导入和轮换边界见[账号维护](accounts.md)。PostgreSQL/Redis等管理员同样进入账号目录；机器运行身份保持独立随机。
