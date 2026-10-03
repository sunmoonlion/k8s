# 模板浏览器身份注册

Web与Admin的`origin`、`casdoor_application`、`casdoor_client_id`分别在各自前端组件config.yaml；后端config.yaml只定义共享组织identity_organization及Job修订identity_revision。回调地址由origin加`/api/auth/web/callback`或`/api/auth/admin/callback`生成，不手工维护第二份地址。

私有identity.yaml保存两个独立client secret，root0600并逐字节备份；丢失后从备份恢复，不重新生成。Git只有SOPS密文。生成的tpl-browser-identity ConfigMap与tpl-browser-secrets Secret供后续后端角色使用，浏览器前端不能得到client secret。

原生application-stage生成声明，提交/发布/晋级后application-bootstrap协调tpl-identity阶段，依赖tpl-rabbitmq和casdoor。Job复用已固定的后端镜像，通过Casdoor官方管理API创建两个客户端，不写Casdoor数据库。管理密码从现有casdoor-initial-identity挂载，只有初始化Job获得；不复制进业务Secret。

新客户端只允许authorization_code，使用现有平台签名证书、独立客户端凭据与精确HTTPS回调，不启用注册或访客登录。同名应用或client ID已被占用/配置漂移则停止，不能覆写已有客户端。既有built-in组织和管理员不改变。组织用户与业务角色授权仍需后续运行验收，客户端注册不等于授予业务权限。

初始化Job在同一命名空间经受限NetworkPolicy访问Casdoor内部HTTP8000；公共issuer仍是https://casdoor.sunmoonai.com:30443。初始化验收涵盖管理会话、注册回读、两个密钥匹配、issuer、PKCE S256和JWKS；它不代表浏览器授权码/回调/会话链已跑通，也不代表内部mTLS已实现。

重复部署保留成功Job；不要直接删除或加TTL。回退声明不会删除Casdoor中的客户端或用户；停用或轮换需显式流程，禁止随机重设密钥。用户侧完整登录在API及前端上线后验证。

接口依据：[Casdoor选定版本Application实现](https://github.com/casdoor/casdoor/blob/v4.12.0/object/application.go)。
