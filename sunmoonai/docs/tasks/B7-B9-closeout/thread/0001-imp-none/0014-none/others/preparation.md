# 部署入口防回写与固定候选

2026-09-19，承接 0013；本轮所有集群操作目前均只读。业务仍运行旧镜像，
没有缩容、迁移、新账号/Secret 供给或撤权；四对象补回不重复执行。

## 已完成的准备

- 旧 Investment broker helper、RabbitMQ Helm writer 在任何旧写入前加只读门禁：
  新 runtime Secret、接管 annotation 或启动 definitions 内新用户任一存在即拒绝；
  查询失败/损坏定义也拒绝，不能把查不到当成未接管。稳定路径以 RabbitMQ 自身目录解析。
- 开发 apply 显式要求 `independent-v1`。每 App 六个 DB/broker URL 键校验账号、
  相异非空密码、固定内部端点/端口、逻辑库/vhost；不使用 result backend。
  这只是结构校验，不能代替真实认证、权限或完整消费者盘点。
- Investment 开发路径不再重跑 broker/Redis 旧供给、不再开启旧数据库 LOGIN。
  Knowledge/Investment 只读比对既有检索绑定，不在部署中隐式重写/重启；正式路径保留。
- 四父仓 source lock 对齐既有十二组件提交；三个 KIND bundle/input/.conf 固定到
  `kind-b7-20260919`，九业务镜像沿用 [已入 Harbor 候选](../../0011-none/others/image-candidate.json)。
  没有组件源码修改、不重建镜像。启用预建拓扑模式；Knowledge 只启用获准 codex-smoke 绑定。
- 新增自动测试逐字重生成已提交三套 bundle，同时验证 `.conf` 与 release 一致，
  不靠人工记住单独运行渲染检查。

## 现场只读结果

显式 kind-kind/context、既有 kubeconfig。各 App API 2/Worker 1/Scheduler 1、前端各 2
均 ready。实际 RabbitMQ HTTP API 只 GET；三 App 方案在启动 Secret 与 live definitions
均通过精确合并兼容检查；没有应用方案。既有 active retrieval binding 与 Investment
来源逐值一致，调用方与来源元数据符合约束。

一次队列快照 Info ready=0、unacknowledged=1，Knowledge/Investment 均 0/0；
这不是排空证据，也未将瞬时在途消息判作故障。切换前须重查实际任务/连接并正常排空，
禁止 purge。三个 vhost 连接仍是旧账号，新身份尚未投入使用。

十二组件 GitHub `refs/heads/master` 经 `ls-remote` 重新验证，均精确等于镜像候选提交。
第一次锁生成依赖本地 origin/master 断言失败：检查发现本地子模块跟踪引用陈旧；
直接查询远端确认提交在库后才生成，未把失败当作成功、也未强制覆盖分支。

第一次候选渲染在 Knowledge 失败：重复包含 App 名的 release_id 超模板 24 字符限制。
定位到 `scaffold.py:dns_label` 后统一缩短为 `kind-b7-20260919`，三包完整重生成并逐字测试通过；
未放宽命名约束。数据库 URL 校验按 Backend 实际 asyncpg 协议，不接受 psycopg URL。

## 验证与边界

- k8s：`python3 -B -m unittest discover -s sunmoonai/app-platform/scripts/tests -q`，81 tests passed。
- tpl-app：`python3 -B -m unittest discover -s k8s-deployment/tests -q`，25 tests passed。
- 两处旧 broker shell `bash -n` 通过；三 App 现有 shell 入口 `plan --cluster KIND` 通过。
- `doc-gate.py --all`、`git diff --check` 通过；提交前还须跑 staged 门禁。

待办仍是：在线窄供给/认证拒绝实测、停机新备份与实际恢复回执、独立迁移及迁移后 grant，
Info→Knowledge→Investment 串行启动与旧身份撤销、真实业务和回滚验收。
备份 `online_preparation_only` 不能改字段冒充停机回执。现有 SQL/broker 编译器与准备演练
不能直接称作在线切换器；在该接入完成前不进入维护窗口。
本记录先提交源码准备；合并/推送/两机各工位同步结果将在本 turn 补充实际提交号。

## 提交、同步和交回检查点

`five-repos-sync/sync-five-repos.sh to-remote -all` 已退出 0；此前本地 master 与五工位
均经干净状态、分支和祖先校验后逐仓 `merge --ff-only`。没有新建分支、force、reset、
realign 或启动 Opus 助手；云端只同步 Git，不运行部署。

| 仓 | 本轮源码交付提交 |
| --- | --- |
| k8s | 30463b7b48956fc6429022427be7cff2499f4772 |
| tpl-app | 6e42d9e9603e42af84008169ad8890434a125a55 |
| info-app | 25959b677b6930de1b6a5c9bbbb7fb77cc90f8d2 |
| knowledge-app | b3d5dda05adee2d62df3cc0e6fdb913799a96347 |
| investment-app | 3b3c9381aa9d204a5e9cf1eb11def667cbac5762 |

同步后重新核验 GitHub/Gitee 五仓各六分支，全部精确对应上表；两机各 30 个父仓
工作树、72 个子模块实例的 HEAD/分支/干净状态全部符合。本节和 turn.md 是随后补充的
文档回执，将追加同步，不改变上述代码/镜像候选；最终 docs 提交不写成自己的父提交。

本地 master 再跑 k8s 81 tests passed。三 App 的五类候选资源分别执行
`kubectl --context kind-kind apply --dry-run=server` 全通过；这是 Kubernetes 资源校验，
不是绕过 deploy.py Secret/备份门禁的实际 apply，也不证明缺失的新账号可登录。
复核当前各服务副本数全部 ready，仍是旧业务运行态。

Info Worker 后续定点 inspect：active/reserved/scheduled 均为空；未打印任务参数、
未发业务任务、未清队列。它只说明后续这个采样时刻无任务，不代替切换前再次排空确认。
Investment 现有独立 Redis 用户 `investment_backend` 使用现有凭据 PING 成功，
未读写业务键、未重做 Redis ACL 供给。检索绑定与 broker 兼容性结果见上文。

`doc-gate.py --selfcheck` 仍提示 hook 未安装；本轮手动执行 all/staged 门禁，不声称自动
pre-commit 已生效。源码准备在此落盘；在线身份供给尚未实现完整接入，所以未停旧服务。
下一轮从新的同步基线接续：先实现并测试窄供给/迁移后授权和真实权限验证流程，
再按批准维护窗口执行新备份与串行部署；不能直接运行旧供给器或伪造 backup receipt。
