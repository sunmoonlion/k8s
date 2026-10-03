# 应用对象存储机制

由原生 application-stage/bootstrap 按后端 config.yaml 的 object_storage.enabled 选用；没有独立部署器。

- 用户名、桶、初始化 Job revision 与该应用后端配置同处。必须是 <APP>_storage / <APP>-originals。
- 密码第一次生成到 /etc/sunmoon/applications/sunmoon-kind/<APP>/s3.yaml，非覆盖独立备份；已声明账号的两份输入同时丢失时停止，不能默默重置。
- 端点、端口、区域来自对象存储组件配置与共享命名空间。TLS CA 校验保持开启。
- root 仅在 data-platform-dev 的一次性初始化 Job 中使用；app-platform-dev 的运行 Secret 只有该应用身份与公共 CA。
- 独立桶启用版本控制。应用只能访问自己的桶、读写对象及创建删除标记，不能管理服务、修改桶版本策略或删除历史版本。
- 首次部署须完成初始化阶段，API/Worker/Scheduler 再通过 Flux 启动；Completed Job 是幂等声明，变更输入需要新 revision。
- 原生 application-check 在实际 API 进程配置下调用业务 ObjectStorage 实现，核对两版本读回摘要、跨桶拒绝、版本策略管理拒绝。仅由独立 root 验收程序删除该次 UUID 探针的两个指定版本，不清理业务数据。

不要把可写当前对象等同于整个爬取、检索和跨应用分发已验收。存储生命周期、版本删除和备份轮换需另外确定策略。
