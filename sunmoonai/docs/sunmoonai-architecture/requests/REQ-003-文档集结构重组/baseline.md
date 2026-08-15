# REQ-003 目标态：文档集结构

> 最后更新：2026-08-15
> **状态：已冻结归档，不是活动目标态。**本请求于 2026-08-15 不采纳并入 REQ-004
> （见 `request.md` ② 复审）；活动目标态为 `REQ-004-现有代码投影/baseline.md`。
> 本文件仅作记录保留，不得据此实施。
> 源自 REQ-003。

## 1. 组织原则

按两个轴组织，取代现行的物理位置轴：

- **寿命轴**：长寿命事实（架构原则、边界规则、依赖方向）写 markdown，手动维护；
  易腐事实（每次发布即变的值）进 `facts/`，脚本生成，禁止手写。
- **归属轴**：平台级 / 跨切面 / 仓级三类，各有独立目录，不再嵌套在某一个平台之下。

三条不变量（继承自现结构，本次不动）：baseline 与 requests 的二分及生命周期；
权威排序「代码 > baseline/ADR > 任务 > request」；漂移义务只加在智能体一方。

## 2. 目标结构

```text
sunmoonai-architecture/
├── AGENTS.md                    路径不变（五仓 10 个指针硬编码），内容瘦身至 ≤80 行
├── workflow.md                  从 AGENTS.md 分出：REQ 流程/粒度/并行/Git 纪律
├── README.md                    唯一入口：这是什么 + 怎么读，≤40 行
├── decisions/                   ADR：追加不覆盖，与 baseline 平级
│   ├── README.md                索引：编号 / 标题 / 状态 / 影响的 baseline §
│   └── ADR-00XX-<短名>.md
├── baseline/                    只放长寿命事实
│   ├── README.md                阅读地图
│   ├── platform/                一平台一文件
│   │   ├── overview.md          九平台职责表 + 依赖方向 + 全局禁止事项
│   │   ├── app-platform.md      data-platform.md      messaging-platform.md
│   │   ├── ingress-platform.md  cicd-platform.md      ops-platform.md
│   │   └── infrastructure.md    kind-infrastructure.md
│   ├── cross-cutting/           按主题，取代 inter-apps
│   │   ├── contracts.md         Artifact/Retrieval 契约治理、provider-lock、双测规则
│   │   ├── identity.md          Casdoor application/audience/cookie、服务身份、auth-app
│   │   ├── data-ownership.md    主档归属、派生系统、数据库双角色
│   │   └── release.md           发布单元、digest 纪律、门禁分层、证据 L1-L7
│   └── repos/                   一仓一文件，轴即 git 仓
│       ├── tpl-app.md           info-app.md      knowledge-app.md
│       └── investment-app.md    k8s.md
├── facts/                       易腐事实，脚本生成
│   ├── README.md                本目录不手工编辑
│   ├── snapshot.json            见 §4
│   └── collect.py               生成脚本
└── requests/                    不变
    ├── TEMPLATE.md
    └── REQ-XXX-<短名>/
```

## 3. 迁移映射

| 现路径 | 目标路径 | 动作 |
| --- | --- | --- |
| `AGENTS.md` | `AGENTS.md` | 原地瘦身：保留 §0 目录定位、§1 权威排序、§1.1 漂移义务、§4 维护约定与编辑自检、§8 启动流程；其余移出 |
| `AGENTS.md` §2 §5 §6 §7 | `workflow.md` | 移出：请求闭环、评审流程与粒度、里程碑收口、Git 与分支纪律 |
| `README.md` | `README.md` | 瘦身：删目录树与逐文件摘要（与 `baseline/README.md` 重复），只留两组结构 + 指向 AGENTS.md 与 baseline/README.md；修正定位措辞（「App Platform 的」→「平台的」） |
| `baseline/sunmoonai/architecture.md` | `baseline/platform/overview.md` + 拆入各 `platform/*.md` | 拆分：§3 职责表与 §4 依赖方向与 §15 全局禁止留 overview；各平台专属条文下沉到对应文件 |
| `baseline/app-platform/inter-apps/app-platform.md` | `baseline/cross-cutting/{contracts,identity,data-ownership,release}.md` | 按主题拆 324 行为四份 |
| `baseline/app-platform/intra-apps/<app>/<app>.md` ×5 | `baseline/repos/<app>.md` ×5 | 移动 + 去掉重复的一层同名文件夹 |
| 无 | `baseline/platform/{data,messaging,ingress,cicd,ops}-platform.md` 等 8 份 | 新建，补齐平台盲区 |
| 无 | `baseline/cross-cutting/identity.md` 中的 auth-app 章节 | 新建，解决 auth-app 缺位（不另开 App 文档：它不套模板、非领域 App） |
| `app-platform/docs/adr/0001…0013` | `decisions/` | 迁入（编号处置见 request.md D4） |
| `app-platform/docs/*.md` 14 份 | 取决于 request.md D2 | A：有效条文吸收进 `cross-cutting/`，仓外改一行指针；B：保留但措辞降级 |
| baseline 正文中的易腐值 | `facts/snapshot.json` | 正文改为写规则 + 指向 facts |

迁移期约束：**不得新旧并存**。每份文档只允许存在于一处，搬完即删旧址，
避免制造第二真源（AGENTS.md §4 约定 1）。

## 4. `facts/` 设计

从 baseline 正文中撤出、改由脚本采集的值：

| 类别 | 现出处 | 真源 |
| --- | --- | --- |
| 三组件 commit / tree hash / 文件数 | `tpl-app.md` §3.1 §3.6 | `tpl-app/template-release-manifest.json` |
| 镜像 digest | `tpl-app.md`、`k8s.md` §3.2 | 各 App `deployment/bundle/release.json` |
| release_id、每文件 sha256 | `k8s.md` §3.2 | 同上 |
| 契约 schema sha256 | `info-app.md`、`investment-app.md` §3.3 | `contracts/*/contract-manifest.json`、`*-provider-lock.json` |
| Alembic head | 四份 repo 文档 | 各仓 `alembic/versions/` 最新文件 |
| 副本数、namespace | `k8s.md` | `release.json`、`deploy-*-app-all.conf` |

`snapshot.json` 形态（每项带 `source` 字段指回真源文件，便于复核）：

```json
{
  "generated_at": "YYYY-MM-DDThh:mm:ssZ",
  "repos": {
    "info-app": {
      "alembic_head": {"value": "...", "source": "info-backend/app/alembic/versions/"},
      "contract_schema_sha256": {"value": "...", "source": "contracts/.../contract-manifest.json"}
    }
  }
}
```

baseline 正文对应改写范式——只写规则，不写值：

> 三组件的 commit / tree / digest 由 `template-release-manifest.json` 锁定，
> `verify_template_release.py` 逐项核对；当前值见 `facts/snapshot.json`。

`collect.py` 的双重作用：既生成快照，也是**漂移检测器**——重跑后与上次 diff 非空
即说明发生了发布，提示评估是否需要手动更新 baseline（§0 的手动更新政策由此获得触发信号）。

## 5. `AGENTS.md` 瘦身后的内容边界

保留（动手前必读，目标 ≤80 行）：目录定位与两组结构、阅读路径、权威排序、
漂移检测尺子与义务归属、三条维护约定与编辑自检、启动流程与指针约定，
末尾一行指向 `workflow.md`。

移入 `workflow.md`（真要立 REQ 时才读）：请求闭环七步、进度单面、评审流程与四选一结论、
请求粒度与总盘/模块关系、实施顺序与并行依赖、命名规范、里程碑收口、Git 与多助手分支协作。

`AGENTS.md` 的**绝对路径不变**，五仓 10 个指针文件无需改动：

```text
tpl-app/AGENTS.md              tpl-app/.cursor/rules/sunmoonai-architecture.mdc
info-app/AGENTS.md             info-app/.cursor/rules/sunmoonai-architecture.mdc
knowledge-app/AGENTS.md        knowledge-app/.cursor/rules/sunmoonai-architecture.mdc
investment-app/AGENTS.md       investment-app/.cursor/rules/sunmoonai-architecture.mdc
k8s/AGENTS.md                  k8s/.cursor/rules/sunmoonai-architecture.mdc
```

## 6. 验收标准

1. 目录树与 §2 一致；`baseline/` 下无 markdown 含 digest / sha256 / commit / Alembic head
   等易腐值（脚本可判）。
2. 相对链接检查 0 坏链（REQ-002 `plan-baseline.md` §7 的脚本）。
3. 九个平台各有一份 `platform/*.md`；`cross-cutting/identity.md` 覆盖 auth-app。
4. `decisions/README.md` 索引齐全，且每条 ADR 至少被一处 baseline 回指。
5. `AGENTS.md` ≤80 行且绝对路径未变；五仓指针文件零改动。
6. 通过 AGENTS.md §6 的**接手演练**：一个未接触过项目的智能体只读本目录，
   能说出九平台职责、四 App 边界、发布纪律与当前 digest 出处。
