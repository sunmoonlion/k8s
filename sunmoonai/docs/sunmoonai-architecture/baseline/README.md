# baseline 阅读地图

baseline 是 SunMoonAI 项目的唯一基线：只反映当前有效事实，覆盖式更新（政策见 AGENTS.md
§0/§2）。阅读分三层，按需取用：

| 目的 | 读什么 | 耗时 |
| --- | --- | --- |
| 平台之间 / App 之间的关系与典型流 | `sunmoonai/architecture.md` | 约 10 分钟 |
| 约束所有 App 的公共规则（形态/Backend/DB/契约/模板/禁止事项） | `app-platform/app-platform-architecture/架构.md` | 约 10 分钟 |
| 快速把握某个 App（定位/拓扑/关键入口/运行验证/与 tpl 差异） | `app-platform/<app>/摘要.md` | 每个约 3 分钟 |
| 深入某个 App（分层/核心流程/数据模型/配置/契约/部署） | `app-platform/<app>/架构.md` | 按需 |

## 文件索引

- `sunmoonai/architecture.md`——九平台分层与职责、依赖方向、典型在线请求流与异步
  跨 App 数据流、CI/CD、Ops、Ingress、Data、Messaging、环境身份网络隔离、平台侧禁止事项。
- `app-platform/app-platform-architecture/架构.md`——核心决策、领域地图与 Research 命名治理、标准 App
  拓扑、统一 Backend 与四运行角色、数据所有权、跨 App 三类契约、身份与安全、模板治理、K8s
  目标形态、App 侧约束；同目录 `摘要.md` 为其快层。
- `app-platform/{tpl-app,info-app,knowledge-app,investment-app,k8s}/`——每项两文件：`摘要.md`
  （快层）+ `架构.md`（深刻层）。
- 未来 ADR 落 `sunmoonai/adr/`（随首条落地创建）。

## 更新政策

- 仅在评估认定需要时手动更新，且永远在评估之后；覆盖式，不留修订叙事。
- 目标态先写进所属请求文件夹的 baseline.md，验收吸收后才进入 baseline/。
