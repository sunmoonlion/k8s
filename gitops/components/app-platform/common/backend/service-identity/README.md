# 跨应用服务身份共用机制

调用方的用户配置位于各自后端 `config.yaml` 的 `knowledge_service`，Knowledge 的 `knowledge_service_receiver.enabled` 启用接收，绑定从两个调用方配置读取，单一来源。原生 application-stage/bootstrap 直接编排本模块；不增加部署CLI或业务运行脚本，不修改已有浏览器初始化Job。

Info只配置摄入URL，Investment只配置检索URL。每条关系使用独立Casdoor组织、client ID、secret和900秒令牌；仅client_credentials、禁止登录/注册/refresh/browser grant。Casdoor服务应用凭据在所属组织内具有管理能力，所以这些组织不含人类账号和其他应用；不能放built-in。初始化Job一次性持管理员输入，API/Worker只持自己出站凭据，Scheduler不持它，Knowledge不持消费者secret。

秘密保存在各APP私有 `service-identity.yaml`（root0600），并在其backup_dir逐字节非覆盖保存；Git仅SOPS。配置修改不是轮换，现有身份不符拒绝自动覆盖。TLS仅通过service-access的集群内路由，保留CA/SNI/主机名验证。精确网络出站只到Traefik8443。

Knowledge现有校验签名、issuer、audience和精确subject；关系能力依据本地绑定授予，不能仅靠调用者声明的scope。Casdoor配置仍限制并实际核验每条关系唯一scope。此模块不修改业务契约、schema和依赖。

核验由原生 application-check APP=info/investment 读取初始化Job的签名/组织/坏密码/越权拒绝回执；APP=knowledge 使用Info实际客户端摄入、真实Scheduler/Outbox/Worker，再由Investment领域Port HTTPS检索，核对中文原文版本/摘要和拒绝边界，只精确清理该轮随机探针。完整爬取发布与投资Agent工具执行仍须另外验收。

官方固定版本依据：[OAuth](https://casdoor.org/docs/how-to-connect/oauth/)、[公共API权限](https://casdoor.org/docs/basic/public-api/)、[v4.12.0令牌实现](https://github.com/casdoor/casdoor/blob/v4.12.0/object/token_oauth.go)。
