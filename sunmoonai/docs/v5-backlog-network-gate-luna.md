# B7g：旧 Calico 放行失败与门禁修复

日期：2026-09-13。Luna 单人开发、自测；本地候选及全新集群复验通过，不宣称独立评审。
接 [B7f](v5-backlog-clock-regression-luna.md) 后发现的独立旧失败，范围与授权见
[处置清单](v5-backlog-disposition-luna.md)。不更新 master、Git 远端或云端工作区。

## 1. 旧问题与本次实际现场

Info 2026-09-11 模板对齐报告记录：Calico 首次允许探针失败，第二次全量通过，但
原因未证实。它不是投递租约用例，不能用 B7f 时钟修复销账。

原门禁存在两个可确认的诊断/安全缺陷：探针日志送 `/dev/null`，判定前删除 Pod；
清理 trap 在“是否已有同名集群”的检查前注册，错误退出仍会执行同名集群删除。
本轮先只修资源所有权护栏和现场保留，不改探针命令、等待或策略，再复验。
用假 CLI 的真实 shell 测试，在旧脚本得到 2 failures / 1 error，修复后 3 tests OK。
未实际对已有集群执行破坏测试。

实际复验仅新建 `luna-b7g-info-policy` 两节点 Calico v3.28.2，独立 kubeconfig，
使用当前 Info bundle 的 `30-network-policies.yaml` 与合成 HTTP 服务，不加载业务
Deployment、数据库、Secret 或应用镜像。NetworkPolicy SHA-256：
`e16fc0e4a350a598c561c1637a73060d24f5ad9d94162930e2efb5454c3dd539`。
常驻 `kind` 集群没有应用任何配置。

首次即复现相同首探针失败：

```text
network probe r3-policy-internal expected=Succeeded actual=Failed
wget: bad address 'info-backend:8000'
```

现场目录 `/tmp/architecture-v2-r3-calico.o7ileS` 保留 Pod JSON、日志、资源/事件及
CoreDNS/Calico 日志。Pod `c7d260ce-a243-4681-9830-fd7c6f059bfa` 在
06:22:25 UTC 启动并于同秒 exit 1；尚未发起后端 TCP/HTTP 访问，不是 HTTP 拒绝证据。
CoreDNS 两实例日志起点 06:22:23.390 / 06:22:24.214 UTC；CoreDNS Available 条件
为 06:22:24，合成后端 Endpoints 与 Available 为 06:22:25。

未修改策略/DNS 配置，06:23:43 UTC 后续独立诊断 Pod 解析同一短名及 FQDN 得到
Service IP `10.96.138.96`，随后 GET 返回 HTTP 200。真实无授权标签探针得到
`wget: download timed out`，exit 1 / reason Error（06:25:46～06:25:51 UTC）。
这区分了 DNS 阶段失败与实际网络拒绝，不能再把两者都归为 Pod Failed。

可确认的根因层次：原门禁没有“新建 Service 的 DNS 已可解析”前置条件，首次 DNS
失败直接被当作网络放行失败。时间线与后续不改配置即恢复支持启动阶段服务发现未收敛；
**没有抓到首次 DNS 包的 RCODE，不编造究竟是 CoreDNS watch、端点传播还是缓存的
唯一内部触发点，也不声称恢复了 2026-09-11 原始现场。**
[CoreDNS 官方说明](https://coredns.io/plugins/kubernetes/)区分了进程启动、对象同步与
尚未同步记录的服务失败；这支持需要实际记录就绪检查，不替代本轮现场证据。

## 2. 修复与验收口径

- 只在本次创建成功后允许自动删除集群；预先存在/创建前失败不清理同名集群。
  创建失败的部分资源不盲删，须按现场另核所有权；清理只用本次独立 kubeconfig，
  删除失败须非零退出并保留诊断，不能宣称成功或继续删除工作目录。
- 失败先保留 Pod JSON、完整探针输出及必要集群诊断；不再先删现场。
- 等待 CoreDNS rollout，再在合成服务创建后用独立无令牌 Pod 校验两个 FQDN 解析结果
  精确等于本轮 Service IP。使用单调时钟 30 秒 DNS 启动预算及 Pod 45 秒 deadline；
  所有 DNS 观察保留日志。未就绪是前置门禁失败，不能记为 NetworkPolicy 拒绝。
- DNS 就绪后，原 HTTP/策略断言各执行一次，**不循环重试网络断言至通过**。
- 拒绝验收不再只看 phase=Failed：本门禁缓存 BusyBox wget 的实际策略超时特征必须
  同时符合 exit 1、reason Error 和明确 download timed out 日志。DNS 错误、连接拒绝、
  OOM、外层 timeout、Pending、命令失败都不算“拒绝通过”。未来更换探针需重新核合同。

新增 8 项 unittest（含 8 个判定子例）通过，覆盖资源所有权、清理失败/独立 kubeconfig、
现场、DNS 临时/永久
未就绪、错误 IP 与非网络失败误报；Bash 语法、Python Ruff E9/F/I 及 diff 检查通过。
本包共享的是测试门禁，不修改四后端运行代码或模板生成的应用配置。

## 3. 新环境复验与剩余边界

第二个全新集群 `luna-b7g-info-fixed` 完整候选退出 0，现场目录
`/tmp/architecture-v2-r3-calico.7hGbWw`。两个 DNS 记录第一次观察即精确匹配本轮 Service
IP，六个原 HTTP 探针各执行一次，全通过；不是在已稳定旧集群上循环至绿。

| 流向 | 结果 |
| --- | --- |
| internal → Backend | HTTP 200 |
| frontend → Backend | HTTP 200 |
| 无放行标签 → Backend | 明确 wget 连接超时，exit 1 |
| Worker → Knowledge 合成目标 | HTTP 200 |
| API → Knowledge 合成目标 | 明确 wget 连接超时，exit 1 |
| Scheduler → Knowledge 合成目标 | 明确 wget 连接超时，exit 1 |

[机器可读证据](backlog-evidence/luna-b7g-network-gate.json)保存首败与六个最终 Pod 的
UID、退出状态、时间、镜像 ID、日志，以及实际 DNS 观察，不包含 kubeconfig/凭据。
本次以当前 Info 策略声明验证网络边界，未改写历史 release 或新造发布回执。
关键证据保存后按精确归属清理本轮自建资源，不清理常驻 kind 或业务数据。
实际清理已完成：两个临时集群的四个节点已删除，`kind get clusters` 只返回原有
`kind`。十个临时镜像导出 tar 副本已清理，Docker 原镜像未删；两个现场目录中的
诊断文本/JSON 继续保留，仓内机器证据不依赖这些临时目录才能阅读。
Info 包级网络通过不等于其他 App、新业务镜像、实际身份/部署或 B7 运行观测全验收。
旧任务其余运行门禁与 B8 正式接收仍按总清单推进，最终一起同步。
