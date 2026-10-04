# Neo4j Community：独立图实例

配置、模板、prepare和实际verify同处本目录；版本/摘要唯一在上游镜像锁。原生 services-stage→本地提交→flux-release晋级→services-bootstrap；没有独立部署脚本。

单节点，data-platform-dev，worker2独立10Gi静态Retain卷。UID/GID7474，认证数据与图数据在/data；非root、只读根，无联网安装插件。内网HTTPS7473、TLS必选Bolt7687，HTTP禁用；本单元不开放公共入口或业务访问网络策略。
管理员neo4j由独立/私有neo4j.yaml保存，位于/etc/sunmoon/services/sunmoon-kind，备份位于/mnt/sunmoon-data/backups/services/sunmoon-kind。Git只有SOPS密文；官方NEO4J_AUTH_FILE读取文件。证书和CA每次恢复均核对，不能以跳过验证连接。

Community不是细粒度多租户权限隔离方案：此实例目前只用于基础服务验收，不给四个业务共享管理员。若领域需要访问，须定唯一图拥有者和独立服务身份；需要数据库级/RBAC共享隔离时另选Enterprise或拆独立实例。无HA保证。

verify覆盖HTTPS主机名/CA、认证拒绝、真实节点关系提交/读回、事务回滚、Bolt TLS协议协商。只清除本次自建随机标记，不删业务图。重启/灾备、领域图接入、APOC等插件仍属后续验收。日志到stdout，不新增自动删除作业。

回退保存原flux-source.yaml后恢复原固定源并原生flux-source-apply；prune=false保留数据。停止新增服务用副本0声明晋级，绝不删除PVC/卷。规则：C-D1图派生副本不抢业务主档，C-D3身份/存储独立，C-R2镜像按摘要。

## 失败版本的滚动恢复

官方入口会把Kubernetes注入的NEO4J_PORT_*当数据库配置；模板设置enableServiceLinks=false，继续用DNS，保留严格配置校验。
StatefulSet滚动更新可能卡在旧失败Pod。原生flux-source-apply直接包含本组件recover-rollout.yaml：只在模板已修正、旧revision未Ready且已失败重启时，核对控制器UID、锁定镜像、节点、Retain卷，使用UID和resourceVersion前置条件正常删除该旧Pod。只让控制器重建Pod，不删除PVC/PV/数据、不强制终止。当前revision或健康Pod不会被删。
neo4j_failed_rollout_recovery可关闭该恢复；API前置条件冲突则报失败，重新入口核对，不能强行覆盖。这是声明调和的受控恢复，不另建部署入口。
