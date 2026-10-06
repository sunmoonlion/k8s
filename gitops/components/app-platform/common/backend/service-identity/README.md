# 跨应用服务身份

调用方配置来自各自后端config.yaml的knowledge_service；Knowledge使用knowledge_service_receiver.enabled启用接收，接收绑定由调用方字段派生，避免重复维护。原生application-stage/bootstrap编排[prepare.yaml](prepare.yaml)与[初始化模板](workload.yaml.j2)。

## 配置与秘密

Info仅有knowledge:ingest，Investment仅有knowledge:retrieve；每条关系独立organization、application、client_id、secret及token_seconds。当前仅client_credentials，禁止browser/login/register/refresh grant。Casdoor服务凭据在所属组织内具有管理能力，因此这些组织保持没有人类账号或其它应用，不能放built-in组织。

service-identity.yaml保存到调用方private_dir，root0600；backup_dir逐字节、非覆盖保存。Git仅SOPS。API/Worker持自己出站秘密，Scheduler及前端不持；Knowledge不持消费者secret。平台管理员输入只给一次性初始化Job。

现有同名身份或配置漂移拒绝自动接管，文件编辑不是轮换。输入丢失时先恢复原备份；不能新生成secret覆盖既有Casdoor身份。

## TLS和授权

服务地址由[Traefik service-access](../../../../ingress-platform/traefik/service-access/README.md)派生，走集群内HTTPS、保留CA/SNI/域名验证，精确出站只到Traefik8443，不走宿主代理或硬编码节点IP。

Knowledge核验签名、issuer、audience及精确subject，按本地关系绑定授予能力，不能仅相信调用方声明scope。初始化还核对每关系唯一scope、组织和坏密码/越权拒绝。

## 核验和停止

application-check APP=info/investment读取各自初始化回执；APP=knowledge进一步验证实际Info客户端HTTPS投递、持久日记、Scheduler/Outbox/Worker及实际Investment领域Port HTTPS检索。浏览器身份、关系交叉、租户/数据集边界同时检查。完整爬取和Agent工具执行尚未由此证明。

停用需分别处理调用方运行配置、接收绑定及远端客户端；enabled=false和Git回退不会撤销已发令牌或删除远端身份。当前没有自动密码轮换/客户端删除入口。操作流程见[应用手册](../../../../../../infrastructure/applications/README.md)，实际探针清理见[Knowledge provider](../../../knowledge-app/knowledge-backend/provider/README.md)。
