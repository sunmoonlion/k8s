# Kibana浏览器访问与只读账号

用户参数在[config.yaml](config.yaml)：入口开关、HTTPS地址、人工只读用户名、初始化代次及会话期限。当前地址由该配置唯一指定；宿主入口引用同一地址的hostname，不另外维护域名常量。

本组件由原生services-render/stage/bootstrap管理，Flux的elk-kibana-ui阶段在ELK运行和日志视图阶段之后执行。已有账号/角色必须带本集群所有权且权限一致，未知或被扩大权限的对象拒绝接管；不会重置既有口令。修改已完成Job输入须明确新代次。

## 身份与访问

人工账号独立于elastic管理员、kibana_system、旧内部reader和视图初始化身份。只允许default空间的Kibana只读功能与sunmoon-logs-*索引read/view_index_metadata，不允许日志写入、外国索引、账号管理或保存视图。使用Kibana原生用户名/密码登录；未配置Casdoor单点登录。

真实密码保存在`services_config_dir/elk-kibana-ui.yaml`，独立非覆盖副本在`services_backup_dir/elk-kibana-ui.yaml`；主副本root0600且逐字节一致。只在本机受控读取，禁止贴入口令、提交明文或复用管理员密码。Git仅保存SOPS密文；管理员只挂短暂身份初始化Job，Kibana/Traefik运行容器不挂载本组件管理员口令。

公开TLS证书独立保存在服务私有根下的kibana-ui/tls，主备一致，沿用平台CA。Traefik通过同命名空间ServersTransport验证Kibana内部证书的CA与完整服务DNS名；不关闭证书校验。标准Traefik CRD来自锁定chart，CRD provider只看入口和数据命名空间，不允许跨命名空间引用或ExternalName后端。

## 部署与维护

从[平台维护](../../../../../../infrastructure/services/README.md)走候选→审阅→stage/提交→发布/显式晋级→services-bootstrap。这个组件不提供第二套部署CLI。公开30443切换属于[入口维护](../../../../../../infrastructure/entry/README.md)的限定维护，完成后核对Harbor和其它应用路由。

`services-check`检查集群入口，`services-check-public`检查宿主公开入口；均核验实际TLS登录页面、独立账号、权限拒绝、session cookie、会话读视图及退出。验证会创建/注销临时登录会话，并尝试写一个UUID视图确认403；如果意外被准许，只删除该UUID视图并报失败。不会修改正式视图/日志。它不等于真实浏览器界面渲染或Windows/WSL DNS已核验；当前实际完成状态见[验收边界](../../../../../../docs/platform-kind-v1/verification.md)。

关闭kibana_ui_enabled停止新增声明，不自动删除已部署账号、路由、Secret或CRD。退回旧Flux源不会自动撤销新增身份，按明确对象另行退役；数据卷和旧账号不能跟着清空。

角色边界依据[Elastic Kibana权限](https://www.elastic.co/docs/deploy-manage/users-roles/cluster-or-deployment-auth/kibana-privileges)，内部TLS依据[Traefik ServersTransport](https://doc.traefik.io/traefik/reference/routing-configuration/kubernetes/crd/http/serverstransport/)。

## 配置字段

| 字段 | 作用 |
|---|---|
| kibana_ui_enabled | 浏览器入口与初始化阶段准入；不代替卸载。 |
| kibana_ui_origin | 对外HTTPS地址，端口须等于共享entry_port；证书、路由和Kibana publicBaseUrl共用它。 |
| kibana_ui_viewer_user | 独立人工只读账号；已有账号改名需另定身份迁移。 |
| kibana_ui_generation | 初始化Job/脚本配置代次；不可变输入改变时明确递增。 |
| kibana_ui_session_idle_timeout | 闲置会话期限，正整数m或h；发布后生效。 |
| kibana_ui_session_lifespan | 会话总期限，正整数m或h；发布后生效。 |

Ingress控制器仍具有其监视命名空间的Secret读取权限；不挂载管理员Secret不代表RBAC层完全不可读取。生产安全审查应覆盖控制器身份与命名空间隔离。

验收的登录请求按当前固定Kibana版本携带内部来源标记；注销调用官方实际注销API，并采用浏览器导航请求头。它们用于会话验收，不是业务集成API。未来升级须重新核实其契约；不得通过关闭内部API限制或放宽注销检查解决失败。依据[官方API验收说明](https://github.com/elastic/kibana/blob/main/docs/extend/testing/api-auth.md)，当前镜像server/routes/authentication/common.js及can_redirect_request.js也已核对。
