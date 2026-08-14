# baseline 阅读地图

baseline 是 SunMoonAI 项目的唯一基线：只反映当前有效事实，覆盖式更新（政策见 AGENTS.md
§0/§2）。

## 目录结构

```
baseline/
├── sunmoonai/
│   └── architecture.md                    # 九大平台之间：分层、职责、依赖方向、典型流
└── app-platform/
    ├── inter-apps/
    │   └── app-platform.md                # App 之间：公共形态、契约、模板治理
    └── intra-apps/                        # 各 App 内部，一项一文件
        ├── tpl-app/tpl-app.md
        ├── info-app/info-app.md
        ├── knowledge-app/knowledge-app.md
        ├── investment-app/investment-app.md
        └── k8s/k8s.md
```

每个文档统一四段骨架：**§1 概要**（定位 + 拓扑，30 秒）→ **§2 重要点**（必须知道的事实与
红线，3 分钟）→ **§3 架构**（全部机制细节，按需深读）→ **§4 关联**（上下游指针）。

## 阅读路径

| 目的 | 读什么 |
| --- | --- |
| 九大平台之间的关系与典型流 | `sunmoonai/architecture.md` |
| 约束所有 App 的公共规则（形态/Backend/DB/契约/模板/禁止事项） | `app-platform/inter-apps/app-platform.md` |
| 快速或深入把握某个 App（概要到全机制） | `app-platform/intra-apps/<app>/<app>.md` |
| 30 秒速览全项目关键事实 | 下方一屏表 |

## 全项目重要点一屏表

| 项 | 必须知道（§ 指回原文） |
| --- | --- |
| 九大平台 | 基础能力向上提供、领域所有权不向下泄漏；部署顺序≠运行时耦合（`sunmoonai/architecture.md`） |
| App 公共形态 | 标准五组件拓扑（backend+admin/web 前端+db-provisioner+access-bootstrap）；四运行角色同一不可变镜像；数据所有权归各 App，跨 App 只走契约；未来 App 必须从已验收模板实例化（`inter-apps/app-platform.md` §2、§10） |
| tpl-app | 三仓唯一模板源，禁伪造 fake 端点；Alembic 迁移只进不退（`intra-apps/tpl-app/tpl-app.md` §2） |
| info-app | sha256+simhash64(0.84) 去重；仅 clean_markdown/text_plain、≤50MiB、有 S3 version 才可分发；delivery outbox completed=业务完成，broker 故障不使 API 5xx（`intra-apps/info-app/info-app.md` §2） |
| knowledge-app | 摄入/检索契约唯一真源；一请求=恰好一个不可变带版本对象；浏览器只见 citation 投影，永不见 provider 原始 URL（`intra-apps/knowledge-app/knowledge-app.md` §2） |
| investment-app | resume token 原子消费后永不复用；citation source 只回同源 BFF 路径；无授权证据=失败不是空答案；Run 四终态不可转出（`intra-apps/investment-app/investment-app.md` §2） |
| k8s | 五件套固定部署顺序、迁移失败不得继续；release.json 只收 digest、禁重构建打 tag；证据分层 L1-L7，smoke 不算完成（`intra-apps/k8s/k8s.md` §2） |

## 更新政策

- 仅在评估认定需要时手动更新，且永远在评估之后；覆盖式，不留修订叙事。
- 目标态先写进所属请求文件夹的 baseline.md，验收吸收后才进入 baseline/。
- 未来 ADR 落 `sunmoonai/adr/`（随首条落地创建）。
