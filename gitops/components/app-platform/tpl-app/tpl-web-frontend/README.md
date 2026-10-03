# tpl-web-frontend

`config.yaml` 是域名、端口、副本与资源的用户入口；`image.lock.yaml` 固定镜像和源码。
`../../common/web/workload.yaml.j2` 渲染 Deployment、Service、NetworkPolicy 与 Ingress；已生成的
`workload.yaml` 随 GitOps 发布，勿直接修改。统一运行命名空间由环境 app_namespace 指定。

`make -C infrastructure application-stage APP=tpl` 准备候选，审阅提交后
`flux-release` 发布，晋级固定源后 `application-bootstrap APP=tpl` 部署并核验。
来源仍是并列业务仓中的同名子模块。前端没有数据库、Redis、RabbitMQ 或 OAuth 客户端密钥。

`/healthz` 校验进程、surface 与 deployment_id；SSR 经内部 tpl-api Service 查询会话。
新入口验收通过不代表公开30443已切换，更不代表完整登录已验收。

共用模板与初始化/验收脚本的唯一来源已归 gitops/components/app-platform/common；本组件配置、镜像锁与生成声明仍在本目录。入口仍为原生Make/Ansible/Flux；不再通过tpl专属模板部署实例。
