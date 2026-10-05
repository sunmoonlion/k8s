# 宿主存储与容量

本模块负责宿主预检、容量守卫及[整套生命周期](lifecycle.md)编排；部署入口已实际验证，启停/开机候选待维护安装与实测。数据盘附加、整套开机恢复和运行期监控的交付状态见[验收边界](../../docs/platform-kind-v1/verification.md#未完成项)。

## 数据布局

动态ext4数据盘为`C:\wsl-disks\sunmoon-data.vhdx`，上限230GiB；文件系统挂到`/mnt/sunmoon-data`，子目录分别bind到`/data/kind-clusters`和`/data/harbor`。UUID、挂载点、fsroot以[config.yaml](config.yaml)为准。严禁在原始`/data/kind-local-storage`上覆盖挂载。

各节点自己的static/dynamic目录由[cluster](../cluster/README.md)管理；Harbor实例独立于节点。数据盘和WSL系统盘最终同在C盘物理硬盘，同盘备份防误删和升级失败，不能防硬件故障。机器外数据库、对象原文和身份备份落点待所有者指定。

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

数据盘扩容、Windows磁盘文件压缩需要另定维护步骤；压缩前停止服务并关闭WSL、确认发行版停止，压缩后核对物理文件长度及C盘实际空闲，再启动/附盘和恢复服务。WSL自动收缩未启用。当前模块没有自动压缩或扩盘入口。

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
| `windows_script_directory` | 文本/表达式 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |

`data_vhd_maximum_gib`须与真实VHD一致，改数字不会扩盘；`windows_powershell`和`windows_script_directory`用于只读容量采集，不是管理员附盘或自动挂载调度器。UUID/目录属于存储身份，变更必须重新核对各服务可见性。

## 长期空间管理状态

已有：操作前峰值预算及部分容器日志轮转。待实现：常态容量监控与告警、统一查看/预览/执行、Harbor保留与GC、构建缓存、日志索引与备份轮换。策略先由所有者批准，保护在用镜像、回退版本和必要备份。

禁止把`docker system prune`、`docker volume prune`或`docker container prune`用于一般清理；旧kind节点/卷与新正式资产保持保护。Completed初始化Job也不是普通缓存。当前手册不启用新增定时删除。
