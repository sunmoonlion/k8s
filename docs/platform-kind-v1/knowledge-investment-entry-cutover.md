# 知识与投资应用正式入口切换

状态：候选已完成，尚未获得本单元入口维护批准，未切换。2026-10-04复核。

## 范围与配置真源

仅 knowledge、knowledge-admin、investment、investment-admin 四个域名的30443流量改为新集群127.0.0.1:29443。域名从各前端config.yaml读取，端口从集群config.yaml读取。infrastructure/entry/config.yaml保存路由组合；同目录模板生成运行配置。

Harbor继续11443，Casdoor/tpl/info既有精确路由保持，其余域名仍走172.18.0.5:30443。入口保持TLS直通。只重启sunmoon-entry代理，不重启数据库、Harbor、KIND节点，不启动原kind控制面。

## 切换前已完成

- 两应用各自五个运行角色Ready，独立数据库/runtime/migrator、Redis、RabbitMQ、Casdoor客户端与固定镜像验收通过。
- 真实API授权码/PKCE回调、SSR、会话隔离、CSRF、退出、Worker实际消息投递消费和Scheduler tick通过，后端连接使用29443但保留真实主机名和CA验证。
- 当前38个Flux阶段均Ready且为同一晋级源sha256:03af36ab4ba8f768680bd7d9c6a94ba98e4dafd49dae2bfd0ff6a11c396d08aa。
- 知识与信息应用完整重复部署、模板正式入口回归通过；投资完整重复部署四段零变更成功，平台services-check也通过（唯一变更是验收回执）。
- 投资首次迁移已执行到20260925_0011，旧配置却期望20260924_0009，导致验收失败。现按固定源码修正，v2迁移Job成功；原始失败记录保留，失败v1 Job已按UID/归属/无PVC条件删除。所有应用在渲染前核对固定源码迁移head。
- HAProxy候选用锁定镜像隔离校验通过；挂载复核与三文件回退副本检查必须在执行前再次成功。

## 回退备份与维护约束

私有备份：/mnt/sunmoon-data/backups/entry/sunmoon-kind/knowledge-investment-cutover-20261003T153516Z。

保存haproxy.cfg、compose.yaml、sunmoon-entry.service，逐字节与SHA256核对，不保存到Git。preapproval-recheck.json记录复核时间。批准后记录本单元window.json，维护上限2小时，容量底线10GiB，计入230GiB数据盘未来增长。代理预计短断数秒至1分钟。任一准入失败不停止现有入口。

## 批准后的原生执行与实际验收

从本工作树运行，不拼接另一套部署配置：

```sh
make -C infrastructure entry-stop
make -C infrastructure entry-deploy
make -C infrastructure application-check-public APP=knowledge
make -C infrastructure application-check-public APP=investment
make -C infrastructure application-check-public APP=tpl
make -C infrastructure application-check-public APP=info
make -C infrastructure registry-publish-check
make -C infrastructure entry-deploy
```

前四项应用检查必须实际连接正式30443，验证登录、认证SSR和安全边界；Harbor需验证独立认证完整镜像拉取与摘要。最后重复入口部署须零变更。记录实际切换时间、结果和维护关闭时间，不把候选检查当作公开入口已通过。

失败恢复原三文件，再启原生入口：

```sh
make -C infrastructure entry-stop
sudo install -o root -g root -m 0644 /mnt/sunmoon-data/backups/entry/sunmoon-kind/knowledge-investment-cutover-20261003T153516Z/haproxy.cfg /etc/sunmoon/entry/haproxy.cfg
sudo install -o root -g root -m 0644 /mnt/sunmoon-data/backups/entry/sunmoon-kind/knowledge-investment-cutover-20261003T153516Z/compose.yaml /opt/sunmoon/entry/compose.yaml
sudo install -o root -g root -m 0644 /mnt/sunmoon-data/backups/entry/sunmoon-kind/knowledge-investment-cutover-20261003T153516Z/sunmoon-entry.service /etc/systemd/system/sunmoon-entry.service
sudo systemctl daemon-reload
make -C infrastructure entry-start
```

备份副本0600，运行的三份非秘密配置原权限均0644。恢复用install显式还原运行权限，避免把备份0600带到非特权代理读取的文件。

恢复后核Harbor健康、tpl/info公开登录与原路由。候选代码与回退运行状态不同，失败未修正前不要再次entry-deploy。失败记录独立保留。

## 验收边界

本单元验运行、身份、数据库及基础消息和正式入口。未宣称浏览器全UI点击、知识检索/索引/RAGFlow、跨应用授权调用、投资模型Key/执行环境与完整投资业务通过。不配置虚假provider、不授予多余业务权限制造成功。整套一键启停、开机恢复、Harbor重启/删除重建持久化与长期空间管理仍需后续实际交付。

证据在忽略目录infrastructure/.build/applications/runtime-unit-20261003/；保留原始日志，不提交凭据或日志。
