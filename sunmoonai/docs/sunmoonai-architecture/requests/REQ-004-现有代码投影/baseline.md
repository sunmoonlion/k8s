# REQ-004 目标态：代码投影

> 最后更新：2026-08-15
> 性质：本次请求的**目标态**，不是 `baseline/`。实施后长期有效部分吸收进 `baseline/`，
> 本文件随 REQ 冻结归档（AGENTS.md §0）。
> 源自 REQ-004。取代 REQ-003 的目标态。

## 1. 定位：投影的纯度

### 1.1 一项承诺

`baseline/` 是**现有代码的投影**，唯一用途是让人与智能体快速了解五仓现状以便开发。
唯一质量指标是**对代码的保真度**，附带一个**验证时点**。

投影没有独立权威。它与代码冲突时，永远是投影错（AGENTS.md §1）。

### 1.2 三项排除

| 排除项 | 理由 | 去向 |
| --- | --- | --- |
| **不写将来** | 投影只映射已存在的代码 | 各 REQ 的目标态文件 |
| **不写设计意图与理由** | 意图是「为什么」，投影是「是什么」 | `decisions/`（ADR），见 REQ-004 ④ D3 |
| **不写进度** | 已由 AGENTS.md §3 规定，此处重申 | `handoff.md` / 任务文件 |

**可证伪性判据**：baseline 中每一条断言都必须能落到 `file:line` 或可执行的验证命令。
写不出定位证据的句子，一律不属于投影——移入 ADR 或删除。

该判据可直接堵住 REQ-002 中那 7–8 条「意图被当成事实」的来路：
「`00-prerequisites.yaml` 含 NetworkPolicy」在写下时就无法给出 `file:line`。

### 1.3 禁止「吸收」

请求实施完成后，**回读代码重写投影的相应章节，不得搬运该请求目标态文件中的文字**。

这是本 REQ 最便宜也最要紧的一条政策。现行 `AGENTS.md` 第 25 行与第 175 行规定的
「吸收」通道，是意图以事实身份进入 baseline 的机制性来源。

对应的 `AGENTS.md` 修订（属治理文件，须共享分支进行）：
§2 第六步「更新 baseline」改为「按漂移检出重写投影」；删除第 175 行「目标态事实必须
写进基线」；第 25 行的「吸收」改为「按需重新投影」。

### 1.4 命名

`baseline` 一词只保留给这一份投影。REQ 文件夹内的目标态文件不得再叫 `baseline.md`
（现行 §5 固定名），建议改为 `target.md`。

`AGENTS.md` 第 23 行专门写一句「request 文件夹内的 `baseline.md` 不是另一级基线」来消除
误解——需要一句解释来防止自身命名造成的误会，即为命名不当的证据。改名后该句可删。

## 2. 结构：两轴

轴的选择服从 §1 的纯度目标，不为组织美观。

**寿命轴**决定一条事实是否手写：变化速率低于人的维护频率者写 markdown；
高于者不进 markdown（只写规则并指向真源，或由 `facts/` 机器采集，见 ④ D2）。

**归属轴**决定它住在哪：平台级 / 跨切面 / 仓级三类，各自独立目录，不再嵌套于某一个平台之下。

```text
baseline/
├── README.md                 阅读地图 + 各文件的验证时点总表
├── platform/                 一平台一文件
│   ├── overview.md           九平台职责、依赖方向、全局禁止事项
│   ├── app-platform.md       data-platform.md       messaging-platform.md
│   ├── ingress-platform.md   cicd-platform.md       ops-platform.md
│   └── infrastructure.md     kind-infrastructure.md
├── cross-cutting/            按主题，取代 inter-apps
│   ├── contracts.md          契约治理、provider-lock、双测规则
│   ├── identity.md           Casdoor application/audience/cookie、服务身份、auth-app
│   ├── data-ownership.md     主档归属、派生系统、数据库双角色
│   └── release.md            发布单元、digest 纪律、门禁分层、证据 L1-L7
└── repos/                    一仓一文件，轴即 git 仓
    ├── tpl-app.md            info-app.md            knowledge-app.md
    └── investment-app.md     k8s.md
```

三点说明：

- `repos/` 取代 `app-platform/intra-apps/<app>/<app>.md`。现行分类把 k8s（部署编排仓）与
  tpl-app（模板仓）归入「app-platform 的内部」，名实不符；改为按 git 仓组织后该异常消失，
  且路径由四层降为两层、去掉只含单文件的同名文件夹。
- `cross-cutting/` 按主题拆现行 `inter-apps/app-platform.md`（324 行）为四份。auth-app
  的内容落入 `identity.md`，无须为其单开 App 文档——它不套模板、非领域 App。
- `platform/` 补齐八个平台。现状下改 Harbor 保留策略或 RabbitMQ vhost 的人在本文档集中
  无可读内容。每平台即使只有职责 / 不负责 / 关键约束 / 配置位置四项也应建立。

`decisions/`（ADR）与 `baseline/` **平级**，不在其下：ADR 追加不覆盖，baseline 覆盖式重写，
两种修改语义不共处一目录。索引含「影响的 baseline §」一列，接通「为什么 → 是什么」。

## 3. 验证机制

投影的核心机制，非附属检查项。

**验证 = 逐条断言回代码取证**，产出四类结论：符合 / 不符 / 已过期 / 无法定位证据。
最后一类按 §1.2 判据处理（移出或删除）。

**验证时点**记在每份文件头（`最后更新` = 文档被改，`验证时点` = 对代码取证的日期），
并在 `baseline/README.md` 汇总为一张总表，使「投影有多旧」一眼可见。

**可重复性**：REQ-002 的五仓并行核对是该操作的原型——每仓一个智能体，读对应投影文件，
逐条断言取证并按四类归档。该方式应固化为标准作业，而非一次性评审。
详见 REQ-005（智能体集群的第一个真实案例即此次核对）。

**更新触发器**改为漂移检出，不再是请求完成。`AGENTS.md` §1.1 的漂移尺子已是此思路，
本 REQ 只需把 §2 第六步对齐过去。

**允许写「未实现」**。投影描述现状，故「静态占位页」「未接线」是合法且必要的事实陈述。
REQ-002 已按此改法处理 knowledge 面板与 investment Web 面。

## 4. 迁移映射

| 现路径 | 目标路径 | 动作 |
| --- | --- | --- |
| `baseline/sunmoonai/architecture.md` | `baseline/platform/overview.md` + 各 `platform/*.md` | 拆分：职责表、依赖方向、全局禁止留 overview；平台专属条文下沉 |
| `baseline/app-platform/inter-apps/app-platform.md` | `baseline/cross-cutting/*.md` ×4 | 按主题拆 |
| `baseline/app-platform/intra-apps/<app>/<app>.md` ×5 | `baseline/repos/<app>.md` ×5 | 移动，去掉同名文件夹层 |
| 无 | `baseline/platform/*.md` ×8 | 新建，补平台盲区 |
| 无 | `baseline/cross-cutting/identity.md` 的 auth-app 章节 | 新建，解决 auth-app 缺位 |
| `app-platform/docs/adr/0001…0013` | `decisions/` | 迁入（编号处置沿用 REQ-003 D4 的结论：保留原号，避免既有引用失效） |
| `app-platform/docs/*.md` 14 份（2717 行） | 取决于决策 | 与 REQ-002 的 S1 是同一件事：吸收进 `cross-cutting/` 并将仓外改为一行指针（推荐），或保留但措辞降级为「实现参考（非权威）」 |
| baseline 正文中的易腐值 | 真源指针或 `facts/` | 见 REQ-004 ④ D2 |
| baseline 正文中不可证伪的设计话语 | `decisions/` 或删除 | 按 §1.2 判据逐条过 |

**迁移期约束**：不得新旧并存。每份文档只允许存在于一处，搬完即删旧址（`AGENTS.md`
§4 约定 1）。

**`AGENTS.md` 的路径不动**：五仓共 10 个指针文件硬编码其绝对路径（各仓根 `AGENTS.md`
与 `.cursor/rules/sunmoonai-architecture.mdc`），且均在各仓 master 上。其路径视为稳定接口，
只改内容不迁位置。

## 5. 验收标准

1. `baseline/` 下每一条断言均可落到 `file:line` 或可执行验证命令；无「将来」「应该」
   「计划」类表述（可脚本抽检关键词）。
2. `baseline/` 下无 digest / sha256 / commit / Alembic head 等易腐值（脚本可判）。
3. 目录树与 §2 一致；相对链接 0 坏链（REQ-002 `plan-baseline.md` §7 脚本）。
4. 九平台各有一份 `platform/*.md`；`cross-cutting/identity.md` 覆盖 auth-app。
5. 每份文件头有 `验证时点`，且 `baseline/README.md` 有汇总总表。
6. `decisions/README.md` 索引齐全，每条 ADR 至少被一处 baseline 回指。
7. 通过 `AGENTS.md` §6 的**接手演练**：未接触过项目的智能体只读本目录，能说出九平台职责、
   四 App 边界、发布纪律，以及当前 digest 应到何处查。
