# 宿主与容量

本目录的 `config.yaml` 是数据盘 UUID、绑定挂载、Windows 路径和常规容量底线的唯一输入；`preflight.yaml`、`tasks/capacity.yaml` 和 `windows-capacity.ps1` 直接消费这些参数。

从 `infrastructure/` 执行 `make preflight`。各部署入口继续调用现有容量门禁；配置归拢不降低 50 GiB 底线，不扩大历史临时例外。

TLS 分流属于独立的 [entry 模块](../entry/README.md)，包括其配置、模板和生命周期。
首次管理员附盘、开机编排与重启持久化验收仍按正式操作卡推进，目录整理不等于这些工作完成。
