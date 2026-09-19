# 本轮同步与部署边界

用户明确恢复同步：先合 master、推送并同步五仓及云端，再处理本地 KIND 部署。
本地 Opus 工作树可更新，不启动 Opus 助手；不创建新分支，不 force/reset/realign。

本轮同步候选父仓：tpl `a53d565bdbe4683daeddaeca9f7cc482455132a1`、
Info `372a698126991dbe27376193e12f9c4f1cb72a1c`、
Knowledge `4799485468b331ec4c2808417ff9f7ca2ab714e5`、
Investment `f0b63481aec4d3d0ae1114b3122b29175bc03cc9`；
k8s 以 `0bf94e545d157b39b1bf6a486a97837d5bc0eeba` 之后加入本请求记录的固定提交为准，执行前取完整 SHA。

预检：两端六工位五父仓无未提交改动，Luna 的本地提交未同步；十二子仓 GitHub/Gitee
master 都是本地候选的祖先。Gitee 八个前端均存在此前落后，不只模板管理前端；没有发现
需要强推的分叉。先普通推子仓并复核远端对象，再更新父仓、master 和各工位，运行 -all。
以上是执行前检查，不提前宣称同步成功。

部署范围是 KIND/app-platform-dev，非云集群或 production；不覆盖 1.0.0/2.0.0。
源码同步后重新核现场，固定新镜像 digest、源码锁、bundle、数据/账号切换与恢复对象。
真实备份恢复、Info 迁移冲突、Knowledge 摄入绑定/历史回执、独立 DB/broker 角色及共享
启动定义保护不得绕过；实际切换须绑定具体版本与回滚。不能拿旧 bundle 重 apply 当新部署。
完成条件和保护要求沿用 legacy-backlog/deployment-checklist.md，不扩展成数据清理或监控安装。
