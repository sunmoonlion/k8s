# dev-plan — 代码要符合什么、接下来建什么、一件事怎么做完

> 最后更新：2026-09-14（按 [dev-plan-architecture.md](dev-plan-architecture.md) 正式切换）

本目录管**开发**。判据是：**改了这里的东西，代码要跟着改。**
项目现在长什么样在 [`../project-guide/`](../project-guide/)（那里改了，只说明代码先变了）。

**先读 [`pipeline.md`](pipeline.md)**：一项需求从提出到上线的七个阶段（S0–S6），每个阶段产出什么、
过什么门、不过往哪回。下表按阶段列文档；每份文档的内部栏目、归属理由和逐节来源见
[`dev-plan-architecture.md`](dev-plan-architecture.md)。

| 文件 | 类型 | 写什么 | 什么时候读 |
| --- | --- | --- | --- |
| [`working/request-lifecycle.md`](working/request-lifecycle.md) | PRD / 产品合同 | 产品必须实现、能验收的对象、状态、F/I/AT | S1 定需求；设计和验收都引用它 |
| [`design/runtime-tld.md`](design/runtime-tld.md) | TLD | 运行时的边界、组件责任与派工接口、内核在开发场景的投影、已决定的取舍 | S2 设计；想知道系统怎么搭时 |
| [`design/executor-sdd.md`](design/executor-sdd.md) | SDD / 执行器 | 租用边界与 SDK 能力、Port 与准入门、进程恢复与功能矩阵 | 动执行层前 |
| [`design/authority-sdd.md`](design/authority-sdd.md) | SDD / 授权 | 主体与权力、动作门与审批、执行中的限制和凭据 | 涉及人的批准、裁量或终审时 |
| [`design/evidence-sdd.md`](design/evidence-sdd.md) | SDD / 证据与观测 | 观测与采信、载体与等效、成本与遗漏观察面 | 要拿证据下结论前 |
| [`development-plan.md`](development-plan.md) | 路线图 | 产品建设顺序、运行时演进与退出门 | 想知道方向时 |
| [`implementation-plan.md`](implementation-plan.md) | 实施计划 | **任务本体**：具体工作单元的目标、依赖、验收、回滚 | 要动手时 |
| [`agent-dev-guide.md`](agent-dev-guide.md) | 操作手册 | 一个工作单元怎么做完：受理→开工→执行与失败→评审批准→发布→续接 | **每次干活** |
| [`delivery/verification.md`](delivery/verification.md) | 验证计划 | 完成判据、验证层次与证据、独立整合与门禁质量、覆盖声明 | S1 定判据；S4 验收 |
| [`handoff.md`](handoff.md) | 交接 | **状态**：当前观察与游标、未决输入、跨阶段风险 | 接手时先读 |
| [`constraints.md`](constraints.md) | 开发纪律 | **代码必须符合的规则**，39 条，每条标注谁在执行 | **动代码前** |
| [`protocol/`](protocol/) | 协作规程 | 多家并行出稿的轮次协议与 `round-status.py` | 开一轮前 |
| [`records/development-history.md`](records/development-history.md) | 记录 | 历史取值与实例、旧路线、吸收审计、旧版入口 | 追溯时 |
| [`rounds/`](rounds/) | 决定与证据 | 各轮的工单、评审、裁定、验收 | 查某个决定从哪来时 |
| [`archive/`](archive/) | 历史稿 | 已被取代的旧稿，无规范效力 | 追溯来龙去脉时 |
| `~/codex-reference-archive/` | 调研材料 | 各助手的历史调研（仓外，按助手分目录），引用时注明是谁的稿 | 定 U1–U5 时 |

同一条规则只在一处展开；别处出现的是投影，必须指回展开处。谁能改、何时改，见
architecture 第三节。

## 门禁与检查

| 文件 | 做什么 | 什么时候用 |
| --- | --- | --- |
| [`doc-gate.py`](doc-gate.py) | 仓内链接、章节引用、表格列数；由 `.githooks/pre-commit` 自动触发 | 提交文档时它自己会说话 |
| [`anchor-gate.py`](anchor-gate.py) | `` `文件.md:行` `` 这类纯文本锚点：钉 commit 的在该 commit 内解析，裸路径对当前索引解析，`rounds/**` 按归档软判 | 删或改被引用的文档前 |
| [`scripts/check-no-owner-creds.sh`](scripts/check-no-owner-creds.sh) | 凭据卫生检查（不是边界）：明文凭据、无口令 key、主仓是否对本机可写、提权面 | 边界变更前后 |
