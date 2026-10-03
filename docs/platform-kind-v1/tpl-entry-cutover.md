# 模板域名接入新集群

状态：候选已准备，尚未切换。维护按所有者当前开发阶段的2小时约定，容量底线10GiB。

当前运行30443：Harbor→127.0.0.1:11443，其它域名→旧kind-worker 172.18.0.5:30443。
候选只新增三个精确SNI：Casdoor、tpl Web和Admin→127.0.0.1:29443。
全部名称引用组件配置，入口不终止TLS、不保存私钥。Harbor仍按独立路由提供服务；
未部署的新应用继续走当前默认路由。

## 准入

1. `make -C infrastructure entry-preview` 使用锁定镜像成功校验候选配置。
2. 新集群13个Flux阶段当前代次Ready，API/worker/scheduler/Web/Admin均Ready。
3. `make -C infrastructure application-check APP=tpl` 验证新后端TLS、数据库/Redis、
   worker/scheduler和真实消息；新Casdoor发现文档issuer必须为原域名HTTPS30443。
4. 新Harborhealthy，原入口active；保存 /etc/sunmoon/entry/haproxy.cfg、
   /opt/sunmoon/entry/compose.yaml、systemd unit及摘要，保留原来的默认后端。
5. 这是一次30443短断：停止代理会中断仓库和应用的既有TLS连接，预计数秒至1分钟。
   仅变更本机入口，不重启数据库、不删除数据、节点、容器或卷。

## 按现有原生入口执行

在k8s工作树内：

```sh
make -C infrastructure entry-stop
make -C infrastructure entry-deploy
```

同一候选配置来自提交过的 entry/config.yaml 和模板。部署动作写配置、启动
既有systemd服务并验Harbor真实TLS健康；不能绕过声明临时拼一份运行配置。

后续通过真正的30443（不再连接29443）验三个域名：Casdoor公开issuer、两前端healthz、
API readiness/deploymentId、实际授权码+PKCE回调/SSR会话/跨端拒绝/CSRF/退出。
Harbor健康和私有镜像摘要认证拉取仍须通过。其它域名原证书/后端不变。
成功后重复entry-deploy须changed=0。原入口默认后端退出由其余应用迁移验收决定。

## 失败回退

维护前备份保存在独立维护目录，必须先核对备份摘要和原文件身份。
停止本次入口，恢复该目录的 haproxy.cfg、compose.yaml、sunmoon-entry.service 到原路径，
执行systemctl daemon-reload，再 `make -C infrastructure entry-start`。
验证Harbor健康和三个域名呈现维护前证书/路由；源码配置暂时与旧运行状态不同，
记录失败并在修复前不要再次运行entry-deploy。无需启动旧控制面或另一个代理。

备份/操作日志不入Git。成功记录与失败恢复记录都保留原结果。

## 验收边界

模板生产设置拒绝启用reference交互；实际业务交互provider和业务delivery handlers
当前没有实现。应用管理scope也未配置，登录成功不自动授予业务管理权限。
这些事实必须记入交付，不能通过放宽权限或启用测试fixture宣称业务已完成。
