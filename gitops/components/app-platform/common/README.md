# 应用共用部署机制

本目录保存四应用共用的数据库、Redis、RabbitMQ、Casdoor身份及API/Worker/Scheduler和前端声明模板。原生infrastructure/applications/deploy.yaml直接渲染本目录；不经过tpl应用，不复制部署脚本。

每个应用的开关、后端配置、Web/Admin配置、镜像锁、生成声明与说明仍在相应app/组件目录。模板只引用传入配置；用户名、域名、schema和镜像不在此复写。秘密保留在私有输入和SOPS中。平台共享namespace与版本仍来自环境及物料锁。

Python初始化/验收脚本为.py.j2，应用名渲染后嵌入对应ConfigMap。对于tpl，渲染须保持既有Job内容不变，避免改变不可变Job；新增应用独立对象和账号，不借用tpl身份。所有组件仍由同一Make/Ansible/Flux入口部署。

## 后端镜像更新与异步数据库

四应用的生产 `async_sessionmaker` 明确设置 `expire_on_commit=False`，避免异步任务读取已提交回执时触发隐式查询和 MissingGreenlet。`application-check` 在实际 API 镜像内验证该策略；代码按模板优先修复，再串行同步实例，由各自源码提交、原生构建和独立 Harbor 摘要发布。

初始化 Job 的模板不可原地修改。后端镜像或初始化内容改变时，增加各组件配置中的 identity/redis/rabbitmq 代次；迁移 Job 同时按镜像摘要命名。复用原私有输入、原账号与逐字节备份，不以重建 Job 代替密码轮换。新代次验收通过后，旧成功 Job 可先归档再按 UID/resourceVersion 精确退役；当前声明中的 Job 不删除，避免 Flux 重建。
