# 模板应用浏览器身份

Web/Admin的origin、casdoor_application及client_id在各自前端config；后端identity_organization及identity_revision在上级[后端config](../config.yaml)。回调由origin加/api/auth/web/callback或/api/auth/admin/callback生成，不维护第二套URL。

## 秘密与权限

private_dir/identity.yaml保存两个独立client_secret，root0600、backup_dir非覆盖逐字节核对；Git仅runtime/provision SOPS。浏览器前端不获秘密。Job使用现有casdoor-initial-identity管理员输入调用官方API，不直接写数据库，管理员不进入常驻业务Secret。

只允许authorization_code、PKCE S256、精确HTTPS回调及现有平台签名证书，不开注册/访客登录。同名应用/client_id漂移停止，不覆写built-in组织、管理员或既有客户端。客户端注册不等于授予用户业务角色。

## 部署和验收

application-stage APP=tpl→提交/发布/晋级→bootstrap协调identity阶段，依赖RabbitMQ及Casdoor；成功Job保留。Job核管理会话、注册回读、秘密匹配、issuer/JWKS/PKCE；实际Web/Admin授权码、回调、SSR/session、退出及CSRF由后续application-check/check-public另验。

初始化及普通应用backchannel当前受NetworkPolicy限制的内部HTTP；公开issuer为HTTPS，不能宣称内部mTLS。跨应用服务关系使用独立组织/身份，见[服务身份机制](../../../common/backend/service-identity/README.md)。

已实际完成模板公共登录，但新环境/改身份后仍需重新验。回退不会删除Casdoor客户端或撤销会话；输入丢失先恢复，停用/轮换另定明确步骤，不能重新随机密钥。

操作流程见[应用维护](../../../../../../infrastructure/applications/README.md)；共用源码为[identity模板](../../../common/backend/identity/workload.yaml.j2)。
