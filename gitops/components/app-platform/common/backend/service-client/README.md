# 通用的跨应用服务身份（SDD 0027 P1）

一个应用的后端用服务身份调另一个应用的内部接口：调用方在自己的[后端config](../../../knowbench-app/knowbench-backend/config.yaml)写 `service_clients`（每项一条关系），接收方写 `service_receivers`（只写接受谁的哪种关系，身份从调用方配置推出来，不重复维护）。knowbase 那一对（knowfeed 摄入、knowbench 检索）仍走[旧机制](../service-identity/README.md)，不动。

## 配置

调用方，每项一条关系，名字按约定派生，[prepare](prepare.yaml)逐项核：

| 字段 | 约定 |
|---|---|
| `target`、`relation` | 目标应用名（须在 `application_names`、且在 traefik `service_access_routes` 有内部入口）；关系是小写字母数字 |
| `application` | `sunmoonai-<应用>-<目标>-<关系>` |
| `client_id` | `sunmoon-<应用>-<目标>-<关系>` |
| `organization` | `sunmoon-workload-<应用>-<目标>-<关系>`：一个组织只放这一个服务应用，没有人类账号 |
| `scope` | `<目标>:<关系>` |
| `token_seconds` | 900 |
| `job_revision` | 初始化 Job 代次；镜像一换 Job 名也换，不必手动升 |

接收方：`service_receivers: [{relation, caller, enabled}]`。[bind](../bind.yaml)读 caller 的 `service_clients`，找 target=本应用且 relation 相同、启用的那一项，必须恰好一项、scope 对得上，否则停。

阶段：调用方每条关系一个阶段 `<应用>-<目标>-<关系>-identity`（目录 `<目标>-<关系>-identity/`，依赖 casdoor、traefik），运行时阶段依赖它，资源带 `runtime/<目标>-<关系>-service.sops.yaml`。写法见 knowbench、knowlab 的 stage.yaml。

## 秘密

私有输入 `private_dir/service-client-<目标>-<关系>.yaml`，root 0600，backup_dir 逐字节、非覆盖；已发布（运行时密文已在 Git）而输入丢了就停，先恢复备份，绝不重新生成。密钥不得与浏览器、数据库、Redis、RabbitMQ 凭据或本应用其他服务身份重复。Git 只有 SOPS：初始化用 `<应用>-<目标>-<关系>-provision`（client_secret、ca.crt），运行时用 `<应用>-<目标>-<关系>-service`（默认给 api、worker；某个关系别的进程也要用时在这一项写 `roles`，必须含 api，网络策略跟着放行，例如 knowbench 读 knowlab 加了 runner，因为顾问在 runner 里做数值验收）。

## 运行时环境变量（应用代码按这些名字读）

调用方（api、worker，及 `roles` 里写的进程）：

| 变量 | 值 |
|---|---|
| `<目标>_INTERNAL_URL` | `https://<目标内部入口域名><内部前缀>`，例如 `KNOWMART_INTERNAL_URL` |
| `<目标>_<关系>_SERVICE_APPLICATION`、`_CLIENT_ID`、`_SCOPE` | 上表三项 |
| `<目标>_<关系>_SERVICE_DISCOVERY_URL`、`_BACKCHANNEL_ENDPOINT` | Casdoor 公网发现地址；集群内 HTTPS 换令牌地址 |
| `<目标>_<关系>_SERVICE_CLIENT_SECRET` | 来自运行时 Secret |

接收方（api）：一种关系可以有多个调用方。`SERVICE_AUTH_<关系>_CALLERS` 列出调用方；每个调用方一组 `SERVICE_AUTH_<关系>_<调用方>_CASDOOR_APPLICATION`、`_AUDIENCE`（调用方 client_id）、`_SUBJECT_ALLOWLIST`（`admin/<调用方 application>`）、`_REQUIRED_SCOPE`、`_DISCOVERY_URL`、`_BACKCHANNEL_ENDPOINT`（调用方名大写、`-` 换 `_`）；`ALLOWED_HOSTS` 加上自己的内部入口域名。校验通过后接收方知道是哪个调用方（knowmart 据此核分身的运行方）。令牌校验签名、issuer、audience、精确 subject 与 scope，不能只信调用方声明的 scope。

两边都挂共用 CA（`/etc/sunmoon/service/ca.crt`），出站只放行到 Traefik 8443。

## 验证

改动时用两份 k8s 树（改前、改后）在同一套假值下渲染比对：没写新字段的应用，生成的运行时、服务身份声明逐字不变（2026-10-16 tpl、knowfeed、knowbase 实测）；prepare 在替身加密下真跑过生成、主备、拒绝重生成。实际令牌签发与跨应用调用随 0027 P6 在本地集群验。
