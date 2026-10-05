# 应用对象存储

原生应用流程按后端object_storage.enabled调用[prepare.yaml](prepare.yaml)，不增加独立部署器。当前Info开启；用户名、bucket、job_revision在Info后端config.yaml，要求遵循应用独立身份/原文桶的命名边界。

## 配置和凭据

S3端点、端口、区域来自[对象存储组件](../../../../data-platform/object-storage/README.md)及共享data_namespace。密码首次保存于应用private_dir/s3.yaml，root0600；backup_dir非覆盖并逐字节核对。已有声明后主备同时丢失必须停止，不能随机重置。Git只保存SOPS。

平台root仅由data_namespace一次性初始化Job使用；app_namespace运行Secret只含应用身份与公共CA。独立桶启用版本控制，应用可读写自己桶的对象/创建删除标记，禁止服务管理、修改桶版本策略或删除历史版本。HTTPS严格CA验证。

## 顺序和真实检查

初始化完成后Flux才启动API/Worker/Scheduler。修改初始化内容先审核已有桶/身份，再更新job_revision；成功Job保留，不加TTL。

application-check在实际API配置下调用业务ObjectStorage适配器，核对两个指定VersionId及读回SHA，检查跨桶/版本策略管理拒绝。root验收程序只删除本轮UUID的两个指定版本，不删除业务对象；文件夹挂载或S3登录成功不能代替业务适配器验收。

原文生命周期、历史版本删除和备份轮换尚未实现自动策略。停用不能回退容器本地文件系统；配置变更与部署见[应用手册](../../../../../../infrastructure/applications/README.md)，原文只读接入见[Knowledge provider](../../../knowledge-app/knowledge-backend/provider/README.md)。
