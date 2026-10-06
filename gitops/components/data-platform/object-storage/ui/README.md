# AIStor Console 浏览器入口

用户参数在[config.yaml](config.yaml)。独立hostname、平台CA证书、IngressRoute（校验上游9001 HTTPS）与NetworkPolicy，登录使用新体系object-storage root私有输入（`sunmoon_storage_root`，密码表第19项）。S3 API不经公共入口，应用继续走集群内9000。

关闭`object_storage_ui_enabled`停止新增声明，不删除桶、root或内部证书。
