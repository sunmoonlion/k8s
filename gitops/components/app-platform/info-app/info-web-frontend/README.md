# 信息应用 Web前端


本目录config.yaml、image.lock.yaml、生成的workload/kustomization与说明共同维护。共用模板来自[web模板](../../common/web/workload.yaml.j2)，直接渲染Deployment、Service、NetworkPolicy、Ingress；生成声明不手工patch。

## 域名、端口与身份

origin含公开HTTPS域名和30443端口；port是前端容器/Service端口，二者不能混淆。replicas/resources控制调度与运行；app_namespace取环境配置，不在这里改名。casdoor_application/client_id是公开字段；对应client_secret只进入后端身份输入/SOPS，浏览器和前端不持数据库、Redis、RabbitMQ或OAuth秘密。

回调由origin与分面路径派生，Web为/api/auth/web/callback，Admin为/api/auth/admin/callback；改域名须一起审核Casdoor注册、后端browser配置、TLS SAN、Traefik及宿主entry路由，不只改Ingress。旧身份漂移拒绝覆写，轮换另定流程。

Web是用户分面，SSR会话必须与后端状态一致；检查退出与Admin对侧分面隔离，不能接受对侧会话。

## 构建、上线与真实检查

源码来自并列业务仓同名前端子模块，按干净固定提交构建；npm下载采用应用统一国内直连/官方代理回退，不使用离线依赖冒充成功。构建与发布见[应用手册](../../../../../infrastructure/applications/README.md)，成品Harbor摘要写image.lock。

stage→审阅提交→发布/显式晋级→application-bootstrap APP=info使用共同应用入口。/healthz检查进程、surface和deployment_id；SSR通过内部API Service查询会话。Ready或直连新Traefik通过不代表公共30443已切换，也不代表登录/权限已验；完整检查包括PKCE、回调、会话、退出、CSRF与分面隔离。

检查公开入口使用application-check-public APP=info，有真实身份/探针副作用；配置切换按[入口维护](../../../../../infrastructure/entry/README.md)先备份、预览、限定切换并验证。历史验收范围见[记录](../../../../../docs/platform-kind-v1/verification.md#应用与业务链路)。

## 前端字段

当前值以[config.yaml](config.yaml)为准，手册维护字段职责，不再复制一套默认值。

| 字段 | 类型 | 维护条件 |
|---|---|---|
| `info_web_deployment.origin` | 文本/表达式 | 与客户端、TLS、入口/Service及网络策略联动；既有节点端口映射不能热改。 |
| `info_web_deployment.casdoor_application` | 文本/表达式 | 账号名或业务边界；已有远端身份/数据须显式核对，禁止静默认领/迁移。 |
| `info_web_deployment.casdoor_client_id` | 文本/表达式 | 账号名或业务边界；已有远端身份/数据须显式核对，禁止静默认领/迁移。 |
| `info_web_deployment.port` | 整数 | 与客户端、TLS、入口/Service及网络策略联动；既有节点端口映射不能热改。 |
| `info_web_deployment.replicas` | 整数 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `info_web_deployment.resources.requests.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `info_web_deployment.resources.requests.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `info_web_deployment.resources.limits.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `info_web_deployment.resources.limits.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
