# 宿主与容量

本目录的 `config.yaml` 是数据盘 UUID、绑定挂载、Windows 路径和常规容量底线的唯一输入；`preflight.yaml`、`tasks/capacity.yaml` 和 `windows-capacity.ps1` 直接消费这些参数。

从 `infrastructure/` 执行 `make preflight`。各部署入口继续调用现有容量门禁；配置归拢不降低 50 GiB 底线，不扩大历史临时例外。

TLS 分流属于独立的 [entry 模块](../entry/README.md)，包括其配置、模板和生命周期。
首次管理员附盘、开机编排与重启持久化验收仍按正式操作卡推进，目录整理不等于这些工作完成。

## 配置字段与修改条件

配置真源为本目录 `config.yaml`，由现有Make入口明确传给Ansible。下表说明当前支持边界；有字段不等于已有实例可直接修改。

| 字段 | 用途 | 修改条件与限制 |
| --- | --- | --- |
| `storage_uuid` | 实际数据盘身份 | 必须与已附加ext4文件系统一致；改值不能换盘。 |
| `storage_mounts` | 精确挂载点及盘内子目录 | 三条挂载由预检核对；禁止在旧/data/kind-local-storage上覆盖挂载。 |
| `windows_powershell` | Windows容量读取工具位置 | 主机路径参数；必须可从WSL执行，改路径不能修复WSL互操作失效。 |
| `data_vhd_windows_path` | 实际VHDX文件位置 | 文件搬迁需Windows维护步骤，不能只改路径。 |
| `data_vhd_maximum_gib` | 数据盘最大容量事实 | 当前230GiB；只参与增长预算，不执行扩盘。 |
| `windows_minimum_free_gib` | C盘增长后最低保留量 | 常规50GiB；门禁拒绝低于50的普通值，例外走另有期限/范围的批准参数。 |
| `windows_script_directory` | Windows容量脚本发布目录 | 与容量任务共同维护；不是开机任务或数据目录。 |

本模块无应用username/password。自动附盘、开机顺序及重启验收尚未由此次配置归拢完成；长期容量告警、缓存/镜像/备份删除策略也不是改门槛就已实现。
