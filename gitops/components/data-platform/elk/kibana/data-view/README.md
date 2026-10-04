# Kibana 日志数据视图

用户配置、本组件原生prepare/Job和说明同处。elk-data-view阶段依赖elk-runtime，使用固定官方Kibana镜像内置Node，不安装依赖、不新增CLI。服务用户名/密码独立于人工日志读账号，在/etc/sunmoon/services/sunmoon-kind/elk-data-view.yaml及独立非覆盖备份中保留。限定default空间indexPatterns功能（已查询实际9.5.4 API确认）保存对象管理和sunmoon-logs-*索引元数据，无日志读取/写入或ES管理权限；初始化实际验证服务认证及日志读/用户管理403拒绝。

独立非root初始化Job通过验证链及主机名的TLS调用官方data_views API；仅不存在时创建固定ID/title/@timestamp视图，已存在时严格核对并保留。allowNoIndex允许先部署平台、后部署应用。短暂initContainer仅持ES管理员用于首次创建带所有权的独立角色/用户；已存在时严格核对，不重置密码或覆盖外国对象。主容器不挂管理员秘密，只持服务身份和公开CA。网络仅DNS、Kibana5601及ES9200；不含TLS私钥，不复用人类/服务秘密。services-check只读核对视图，缺失或篡改失败，不隐式修复。

重复部署不重跑成功Job。删除视图后需要显式提高elk_log_data_view_generation并发布新Job；改ID/凭据/初始化实现/不可变Job输入同样必须增加代次，不自动覆盖已有对象，不删日志/索引。凭据轮换必须同步主副本。公共Kibana域名入口尚未由本组件切换。

参考：[官方创建API](https://www.elastic.co/docs/api/doc/kibana/operation/operation-createdataviewdefaultw)、[官方读取API](https://www.elastic.co/docs/api/doc/kibana/operation/operation-getdataviewdefault)。当前采用已存在视图，首次空视图创建/整机重建另行验证。
