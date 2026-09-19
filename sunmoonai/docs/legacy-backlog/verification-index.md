# 重构验证与历史索引

这是精简索引，不是新一轮测试报告，也不是部署验收。
当前入口：[待接收任务](README.md)、[部署清单](deployment-checklist.md)、
[项目指南](../project-guide/README.md)。历史原文通过 Git 获取，不另建备份/归档目录。

## 可直接复核的近期证据

- [B7v 固定候选、命令和 JUnit](../tasks/B7-B9-closeout/thread/0001-imp-none/0001-none/others/verification.md)：
  tpl-app `09ff4a9268db5006f5d32a2953f58c95b1369819`；四后端各 6 项生命周期实测；
  模板另验 3 联合、30 broker、完整后端 258 项，普通部署单元 18 项；未部署。
- [Knowledge Provider 解耦](../knowledge-provider-decoupling-luna.md)：
  Backend `26aa0715f15e2c8df4713559063a9a2e3215a1c8`，完整 450 项及独立角色 27 项；
  默认 RAGFlow，未接 WeKnora，未改变跨 App 契约，不是替换供应商运行验收。
- [KIND 时点快照](../tasks/B7-B9-closeout/thread/0001-imp-none/0001-none/others/kind-cutover-preflight.md)：
  2026-09-19 只读 UID、镜像及 Secret 引用，不读取凭据值；部署前须重取。

上列测试数字各自对应固定版本/范围，不相加为“全部产品通过”。四后端固定源码与
父仓版本详见 B7v 附件；依赖、权限策略、运行镜像变化后需按影响重验。

## 被收拢的 24 份旧账报告

下表旧文件均在 k8s 提交 **`6757974b4084c92c8df62af637b020d998d4a160`** 的
`sunmoonai/docs/` 下可完整取回。表中短名补成 `v5-backlog-<短名>-luna.md`。
该固定提交包含原始命令、代码 SHA、失败与修复经过；不使用浮动 HEAD 指向删除前版本。

| 原短名 | 原范围 / 保留的结论 |
| --- | --- |
| disposition | B1～B9 处置与原任务映射；未来目标转待接收清单，运行欠账转部署清单 |
| coverage | B7b 覆盖矩阵与 API schema readiness；代码接线不等于部署完成 |
| scheduling | B6a 持久 available_at 与预约、并发/重放语义 |
| parse-polling | B6b Knowledge 单次持久轮询、协议标记、代次、deadline；旧任务不能自动升级 |
| logging | B7a 公共 SQL/HTTP 日志降噪，不是全日志敏感信息治理完成 |
| distribution-identity | B7c Info 版本/目标/dataset 逻辑去重、并发唯一性、0009 迁移与隔离恢复 |
| delivery-observation | B7d 只读投递观测；ACK、Inbox 与业务成功分开 |
| worker-readiness | B7e 节点队列/注册探针、测试连接恢复，以及宿主/WSL 双重校时故障处理 |
| clock-regression | B7f 确定性重现释放后租约回生/立即任务等待；负无穷释放与真实预约语义分开 |
| network-gate | B7g Calico 门禁自身的归属清理、证据保留、DNS 前置及 allow/deny 验证；非业务 KIND 策略生效证明 |
| metrics-http | B7h 服务身份限定的指标 HTTP；浏览器 Cookie 不授权，未接实际采集/告警 |
| scheduler-activity | B7i 本机 Beat 活动观测；不是 Worker 进展或业务成功 |
| worker-progress | B7j 精确匹配的已提交 Inbox gauge；可随保留下降，不是单调成功计数 |
| retention-audit | B7k 去重/恢复/Provider/epoch/旧归档引用审计；无保留窗、无删除授权 |
| runtime-preflight | B7l 9 月 13 日旧镜像、共享身份、Info revision、Knowledge 历史任务的只读快照 |
| runtime-rendering | B7m 实例保留模板角色 Secret/探针/release 关联与领域挂载；未重写历史 bundle |
| runtime-permissions | B7n 九角色 PG 目录和 broker 授权审计；实际旧权限、default ACL 及供给副作用 |
| template-database-policy | B7o 模板精确六表/列 GRANT、独立四登录和真实拒绝；不是旧角色撤权工具 |
| info-database-policy | B7p Info 15 表策略与真实领域用例/拒绝 |
| knowledge-database-policy | B7q Knowledge 10 表策略、操作账及轮询/回执权限 |
| investment-database-policy | B7r Investment 18 表策略、PG Saver、审批恢复/取消与事务权限 |
| template-broker-policy | B7s 三角色预建拓扑、生产/消费隔离及真实 Celery 拒绝 |
| instance-broker-alignment | B7t 模板→三实例串行拓扑承接、目标 venv 与辅助服务隔离 |
| joint-runtime-identity | B7u 四仓独立 DB/broker 的真实 Beat/Worker、事务/ACK/杀进程恢复；仍非业务切换 |

例如，在 k8s 仓根直接查看或恢复引用所需片段：

```sh
git show 6757974b4084c92c8df62af637b020d998d4a160:sunmoonai/docs/v5-backlog-distribution-identity-luna.md
git show 6757974b4084c92c8df62af637b020d998d4a160:sunmoonai/docs/v5-backlog-runtime-permissions-luna.md
```

这里删除的是文档工作树文件，不删除实现、测试、迁移、制品或 Git 历史。
已冻结的 `tasks/**/thread/` 与 `dev-agent-task/**/thread/` 原文不改；其中旧相对链接应按
其原提交或上面的固定快照解释，不是假装在当前工作树仍有效。

## 退出当前目录的四份旧计划

同一固定提交下可查：

| 原文件 | 留存位置与用途 |
| --- | --- |
| `mooc-manus-langgraph-longterm-plan-v4.md` | 历史方案；第 20 节 Profile 的可复用概念已摘要到待接收清单，不恢复旧 Graph/ModelGateway 技术前提 |
| `mooc-manus-langgraph-longterm-plan-v5.md` | 历史阶段划分与需求来源，不再是当前架构依据 |
| `mooc-manus-langgraph-v5-implementation-plan.md` | 原任务编号与详细条件；N1～N6 保留原编号，设计时可按固定 Git 版本追溯 |
| `mooc-manus-langgraph-v5-handoff-20260712.md` | 当年停在 P0-008C.5：构建/身份探测不等于部署接受，C6/C7 未完，正式 M1 未启动 |

`mooc-manus-v5/` 的旧 ADR/脚本及 `evidence/v5/` 本轮未删除。特别是
`mooc-manus-v5/scripts/verify_template_first_plan.py` 是校验旧计划文字的历史脚本，
其输入随旧计划退出当前工作树；只能在完整历史 checkout 复现，**不是当前发布门禁**。
当前门禁真源仍为 `architecture-v2/` 与 `app-platform/scripts/`，本轮不改其实现。
