# v5 重构历史索引

本文只负责定位已经退出工作树的 v4/v5 计划、Luna 旧账报告、Architecture v2 和历史证据，
不产生当前需求、任务或部署状态。当前产品目标以 [`dev-agent/`](../../dev-agent/README.md)
为准，当前源码与运行事实以[项目指南](../README.md)为准。

旧 N1～N6 已完成接收裁定：交互、执行、Profile、子任务与验收目标进入现行 [需求](../../dev-agent/PRD/requirement.md) 和
`dev-agent/`；知识生命周期回到 Knowledge 现行职责；发布缺口进入本指南“发布与门禁”；
监控告警的现状与接线判据并入 [`repos/k8s.md`](../repos/k8s.md)「监控与告警」，不单独立任务；按需扩展没有触发条件时不建任务。旧编号不再构成待办。

`tasks/B7-B9-closeout/` 已在 `547a8f6d83cc296a86a7604697057465620c7edc` 完成最后一次
本机 KIND 切换回执，随后整体退出活动工作树。需要复核时按该提交读取，不恢复成当前任务：

```sh
git show 547a8f6d83cc296a86a7604697057465620c7edc:sunmoonai/docs/tasks/B7-B9-closeout/thread/0001-imp-none/0015-none/others/preparation.md
git ls-tree -r --name-only 547a8f6d83cc296a86a7604697057465620c7edc -- sunmoonai/docs/tasks/B7-B9-closeout
```

## 可直接复核的近期证据

- B7v 固定候选、命令和 JUnit（按上方 `547a8f6d…` 提交读取）：
  tpl-app `09ff4a9268db5006f5d32a2953f58c95b1369819`；四后端各 6 项生命周期实测；
  模板另验 3 联合、30 broker、完整后端 258 项，普通部署单元 18 项；未部署。
- [Knowledge Provider 解耦](#knowledge-provider-内部解耦)：
  Backend `26aa0715f15e2c8df4713559063a9a2e3215a1c8`，完整 450 项及独立角色 27 项；
  默认 RAGFlow，未接 WeKnora，未改变跨 App 契约，不是替换供应商运行验收。
- KIND 时点快照（按上方 `547a8f6d…` 提交读取）：
  2026-09-19 只读 UID、镜像及 Secret 引用，不读取凭据值；部署前须重取。

上列测试数字各自对应固定版本/范围，不相加为“全部产品通过”。四后端固定源码与
父仓版本详见 B7v 附件；依赖、权限策略、运行镜像变化后需按影响重验。

## 被收拢的 24 份旧账报告

下表旧文件均在 k8s 提交 **`6757974b4084c92c8df62af637b020d998d4a160`** 的
`sunmoonai/docs/` 下可完整取回。表中短名补成 `v5-backlog-<短名>-luna.md`。
该固定提交包含原始命令、代码 SHA、失败与修复经过；不使用浮动 HEAD 指向删除前版本。

| 原短名 | 原范围 / 保留的结论 |
| --- | --- |
| disposition | B1～B9 当时的处置与原任务映射；旧接收清单和部署清单现已关闭 |
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
仍在工作树的冻结 turn 原文不改；已经整体退役的 B7-B9 turn 按上方固定提交解释。

## 退出当前目录的四份旧计划

同一固定提交下可查：

| 原文件 | 留存位置与用途 |
| --- | --- |
| `mooc-manus-langgraph-longterm-plan-v4.md` | 历史方案；Profile 的有效概念已进入现行 `dev-agent`，不恢复旧 Graph/ModelGateway 技术前提 |
| `mooc-manus-langgraph-longterm-plan-v5.md` | 历史阶段划分与需求来源，不再是当前架构依据 |
| `mooc-manus-langgraph-v5-implementation-plan.md` | 原任务编号与详细条件；N1～N6 只作历史追溯，不构成当前待办 |
| `mooc-manus-langgraph-v5-handoff-20260712.md` | 当年停在 P0-008C.5：构建/身份探测不等于部署接受，C6/C7 未完，正式 M1 未启动 |

## 第二批清退的历史材料

以下原文在 k8s 固定提交 **`6facaaaad8eded7f96ee54c4c62d20ff37cd234d`** 中可取回：

| 原路径（相对于 `sunmoonai/docs/`） | 处置与必要边界 |
| --- | --- |
| `mooc-manus-v5/`（111 个文件） | 旧 ADR、契约和脚本退出当前工作树；没有发现目录外现行代码按路径或脚本名调用它们。旧契约不替代 provider 仓的当前契约，旧部署/清理脚本不迁作新发布工具 |
| `app-platform-architecture-v2-refactor-plan.md` | 原状态停在 R5 阶段，退出当前施工入口；当前事实看 project-guide，规则看 dev-agent，发布缺口看“发布与门禁” |
| `knowledge-provider-decoupling-luna.md` | 实施过程按 Git 保留；适配义务由 Knowledge Backend 的 `docs/knowledge-provider.md` 维护，关键验证与限制见下节 |

例如，在 k8s 仓根读取单文件或列出原目录：

```sh
git ls-tree -r --name-only 6facaaaad8eded7f96ee54c4c62d20ff37cd234d -- sunmoonai/docs/mooc-manus-v5
git show 6facaaaad8eded7f96ee54c4c62d20ff37cd234d:sunmoonai/docs/mooc-manus-v5/adr/ADR-001-runtime-selection.md
git show 6facaaaad8eded7f96ee54c4c62d20ff37cd234d:sunmoonai/docs/app-platform-architecture-v2-refactor-plan.md
git show 6facaaaad8eded7f96ee54c4c62d20ff37cd234d:sunmoonai/docs/knowledge-provider-decoupling-luna.md
```

冻结 turn 保留原文；`evidence/v5/` 与 `architecture-v2/` 的后续清退见下节。历史命令或旧路径
按原提交解释；复现需要匹配当时完整源码和依赖，不能只恢复一个脚本就在当前集群执行。
例如旧 `verify_template_first_plan.py` 依赖已清退的旧计划，
`verify_architecture_v2_image_lock.py` 依赖旧晋级模块；均不是本批开发发布门禁。
清退文件不删除 Harbor 镜像、备份、数据库或 Git 历史，也不结束任何运行回滚保护窗口。

第二批清理当时保留了 `architecture-v2/`，之后用户明确要求处理该目录，结果见下节。
这不是授权直接执行其中的旧 apply/供给脚本。

### Knowledge Provider 内部解耦

2026-09-13 固定 Backend `26aa0715f15e2c8df4713559063a9a2e3215a1c8`：
完整后端 450 passed，独立真实 PG 角色 27 passed；Ruff/Pyright 通过。
Info 分发帮助函数 6 passed、Investment 检索契约 7 passed；这些是历史固定版本结果，
本轮删除文档没有重跑这些业务测试。原始命令、失败根因与修正经过见上方固定报告。

数据面 `KnowledgeProvider` Port 统一类型与异常；RAGFlowProvider 负责供应商协议转换，
事务、授权、幂等、未知回执恢复仍在应用层。非 RAGFlow 假实现验证内部边界，不是外部联调。
默认装配仍只允许 RAGFlow，retrieval v1 的 provider 仍限定 ragflow；旧持久键、状态、
绑定及 DTO 兼容保留。没有接入 WeKnora、改跨 App 契约、迁移业务数据或部署。
后续替换需适配器、契约扩展及消费者回归、索引/绑定/引用迁移和真实回执验证，不能只改 URL。

### Investment 改名历史

`investment清理和改名.md` 已按用户要求退出当前工作树。其描述的是 Research 保留 Git
历史、原地迁入 Investment 三组件拓扑的旧实施过程，不是当前发布操作指令。
`ResearchSession` 等仍可为合法领域术语，不能据历史改名要求全局替换 `research`。
本次只删文档并修正两处引用，不改仓名、业务数据、运行资源或历史备份。
现状见 [Investment 指南](../repos/investment-app.md)，当前发布边界见[发布与门禁](release.md)。
原文仍在上述固定 k8s 提交中：

```sh
git show 6facaaaad8eded7f96ee54c4c62d20ff37cd234d:sunmoonai/docs/investment清理和改名.md
```

### Architecture v2 目录清退

旧目录完整原文固定在 k8s **`82c709705aa92b1b44d9913b4416d4ca505a6665`**。
301 个受跟踪文件中，7 个可复用工具/测试迁到
[app-platform/scripts/validation](../../../app-platform/scripts/validation/README.md)，
其余 294 个历史脚本、SQL、锁文件、阶段报告和证据退出当前工作树；不再建备份副本。
迁移保留 Calico 同目录依赖、环境变量和同步工具 CLI。源码拓扑检查修正对已恢复纯文档
`dev-to-prod-deploy/` 的误判，仍拒绝脚本、可执行文件和软链接，未放开旧运行拓扑。

旧 R3/R5/R7 候选、供给、切流、退役和固化发布脚本基于当年的身份、schema、镜像和目录；
不作为本批开发发布工具。特别是 R7 检查要求正式包且写死旧迁移 head，与当前开发包不符。
旧 capability 清单验证依赖已经退出当前拓扑的双 Backend，也只在历史版本复现。
当前部署入口、静态 bundle 检查与剩余验收见[发布与门禁](release.md)，不因清理销账。

冻结的 `tpl-app/template-release-manifest.json` **保持逐字不变**：其中 `test_evidence`
以 `k8s/` 开头的九个旧路径都按此固定 k8s 快照解析（去掉开头的 `k8s/`）。目录项用
`git ls-tree`，文件项用 `git show`；这是历史证据定位，不承诺它们存在于当前工作树。
R7 release-manifest、重构前源码/镜像保护锁和 R7.1 退役回执也都保留于该快照：

```sh
git ls-tree -r --name-only 82c709705aa92b1b44d9913b4416d4ca505a6665 -- sunmoonai/docs/architecture-v2
git show 82c709705aa92b1b44d9913b4416d4ca505a6665:sunmoonai/docs/architecture-v2/evidence/R7-release/release-manifest.json
git show 82c709705aa92b1b44d9913b4416d4ca505a6665:sunmoonai/docs/architecture-v2/pre-refactor-image-lock.json
git show 82c709705aa92b1b44d9913b4416d4ca505a6665:sunmoonai/docs/architecture-v2/R7.1-legacy-retirement-closeout.md
```

历史证据里的路径、原命令与代码 SHA 按原版本理解，不能把新路径测试结果冒充旧版本重新验收。
不改发布 digest、清理 Harbor 镜像/缓存、删除业务备份或执行旧退役事务；镜像保护集仍须
结合最新运行引用与保护锁核对，删除文档不解除保护。

### 旧 evidence 目录清退

用户要求删除现存 `sunmoonai/docs/evidence/`，其中 78 份 v5 历史结果、快照和回执
已退出当前工作树。原文固定在 k8s **`29f8465312735895544b36b5475c4520881e9a06`**，
未删除 Git 历史、冻结 turn、本轮测试结果或任何业务/镜像资产。

```sh
git ls-tree -r --name-only 29f8465312735895544b36b5475c4520881e9a06 -- sunmoonai/docs/evidence
git show 29f8465312735895544b36b5475c4520881e9a06:sunmoonai/docs/evidence/v5/V5-RELEASE-1.0.0/result.md
```

这是历史材料清理，不取消未来任务保存验收证据的义务；现有计划中的证据目录约定
本轮不改。历史结论仅为其固定候选背书，不能用于当前开发包销账。
