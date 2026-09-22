# 责任投影

**这是所有者索引，不产生第二套规范。**键是稳定 ID：各模块 `functions.md` 的 `F-*`、 [`approval.md`](approval.md)、[`invariants.md`](invariants.md) 的 `I*`，以及 [验收矩阵](../../PRD/acceptance.md) 的 `AT-*`。

| 所有者 | 负责的要求 |
| --- | --- |
| 桌面应用 | `F-INTAKE-*`；`F-APPROVE-02`、`F-APPROVE-05` 的界面；`F-REVIEW-*`；`F-DELIVERY-*` 的订阅、回放、解密与展示侧；`F-CRYPTO-03`、`F-CRYPTO-04`、`F-CRYPTO-05` 的界面；[`0002-desktop/PRD/security.md`](../submodules/0002-desktop/PRD/security.md) 的安全与登录 |
| 本地 runtime | `F-EXEC-*`；`F-APPROVE-01`、`F-APPROVE-03`、`F-APPROVE-04`；[`approval.md`](approval.md)「两层审批」；`F-GUARD-01`、`F-GUARD-02` 的执行侧、`F-EXEC-12` 的执行侧；`F-ACCEPT-02` 的检查与回执；`F-CRYPTO-01`；[`discipline.md`](../submodules/0003-runtime/PRD/discipline.md)；I14、I16、I18、I19、I20 的执行侧；[`0003-runtime/PRD/`](../submodules/0003-runtime/PRD/requirement.md) 下的 `codex.md`、`isolation.md`、`models-and-keys.md`、`device.md` |
| 后端 supervisor | `F-ADMIT-*`；`F-DISPATCH-*`；`F-INTERACT-*`；`F-ACCEPT-01`、`F-ACCEPT-03` 至 `F-ACCEPT-06`；`F-DELIVERY-*` 的服务端；`F-CRYPTO-02`；`F-GUARD-01` 的签名发布、`F-GUARD-04`、`F-GUARD-05`；[`0001-backend/SDD/architecture/blocks.md`](../submodules/0001-backend/SDD/architecture/blocks.md) 与 [`SDD/modules/`](../submodules/0001-backend/SDD/modules/) 下的七块；[`architecture/routing.md`](routing.md)、[`architecture/methods.md`](methods.md) 的服务端落地；I1 至 I15 与 I17 的存储与并发载体 |
| 知识服务 | [资料与知识服务](../../PRD/knowledge.md) 的自有数据、按上下文下发与防批量抓取；`F-GUARD-04` 的取数侧；`F-POS-01` |
| 验收器与 Profile | `F-ACCEPT-*` 的规则；Profile schema 与版本；内容检查规则；`F-POS-02` 至 `F-POS-04` 的规则 |
| 运维与管理后台 | 非终态 Task、过期租约、离线设备、悬空投递与失败 Delivery 的扫描与告警；Profile、失败码、Attempt、设备与预算的可观测性；设备吊销；只见元数据 |
| 产品与合规 | `F-POS-05`；定位的法务确认；推荐模型清单与对比评测（[核心价值与价值检验](../../PRD/value.md)） |
| 测试与维护者 | `AT-*`；实现矩阵；无法自动验证条款的人工门禁及理由 |

当前覆盖状态只记录在实现矩阵或 [project-guide](../../../../project-guide/overall-architecture.md)，不写回本文。
