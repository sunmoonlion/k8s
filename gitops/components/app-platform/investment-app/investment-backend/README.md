# 投资应用backend

用户参数、镜像锁、生成声明与加密Secret同处；原生 application-stage/bootstrap APP=investment 直接使用common机制。独立数据库、账号和非覆盖备份，不借用其它应用身份。

已验基础登录、数据库、消息和运行入口；知识检索领域Port已使用独立Casdoor身份通过集群内HTTPS取得中文原文引用。模型Key、执行环境、投资Agent工具执行和信息查询仍须另行验收。

config.yaml.knowledge_service 是知识检索关系配置真源；口令独立保存在private_dir/service-identity.yaml及非覆盖backup_dir，仅SOPS入Git。关系scope为knowledge:retrieve，令牌900秒，独立空组织；API/Worker持有，Scheduler与前端不持有。原生application-bootstrap/check核验身份任务；APP=knowledge对实际Investment领域Port执行检索及跨租户/数据集/反向摄入/浏览器分面拒绝。共享机制见common/backend/service-identity。
