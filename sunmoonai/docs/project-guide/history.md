# 本文档集的来历与取代记录

> 最后更新：2026-08-29
>
> 本文件回答两件事：这套文档怎么来的、取代了什么。**归档，写完即冻结。**
> 它只追加不覆写——与 `repos/` `topics/` 的覆盖式重写语义不同。
>
> 本轮查出的八项已知缺口原在本文件 §4，已移到
> [`../dev-plan/open-issues.md`](../dev-plan/open-issues.md)——它们是活的待办，
> 不该埋在归档里。

## 1. 参与方与产出

2026-08 期间，五个 AI 助手在各自分支上就"给五仓写一份架构基线"独立产出过版本：

| 分支 | 产出 | 性质 |
| --- | --- | --- |
| `cursor` / `luna` / `qwen3.8` | `baseline/` | **三者逐字节完全相同**，是同一份原始版本，未经后续修订 |
| `kimi` | `baseline/`（重写） | 独立重写，自称"直接从五仓代码派生，未参考旧版" |
| `opus` | 本文档集 | 走完 REQ-002→010 流程后，2026-08-27 重新取证重写 |

**可对照的独立视角实际只有两个**（原始版本 + kimi），不是四个。

`qoder` 本轮作为**独立评审方**参与，未参与提案，评审记录见
[`merge-review/`](merge-review/)。

## 2. 关键分歧与取舍

综合时按"回代码取证"逐条判定，不按多数决：

| 分歧点 | 各版本说法 | 取舍与依据 |
| --- | --- | --- |
| 部署 apply 顺序 | 原始版本：`prerequisites→migration→runtime→network`；opus：网络策略在迁移**之前** | 取 opus。读 `deploy.py` 的 `apply()`，三 App 一致 |
| 版本状态 | 原始版本：正式 2.0.0；kimi：仍是候选 `2.0.0.dev0`；opus：**两者矛盾且有测试强制** | 取"矛盾"这一表述，见 [`overall-architecture.md`](overall-architecture.md) §9.1 |
| ReferenceAdapter 的 ID | 原始版本：`uuid5()` 生成 | 证伪。全仓无 `uuid5()` 调用，是硬编码 v5 格式常量 |
| 是否跑测试 | kimi 跑了内核不变量；原始版本与 opus 早期只静态读码 | **吸收 kimi 的做法**并扩大到完整套件（365 passed） |
| 结构 | 原始版本四层嵌套；kimi 扁平；opus 两层 | 取两层：总览回答"去哪看"，细节层回答"锚点在哪" |

**方法上的一条**：三份既有文档都读过同一批文件，都漏了 §9.1 的版本矛盾。
这是"不能靠拼接现有文档做整合"的直接证据，也是本轮坚持重新取证的理由。

## 3. 取代记录：旧 `sunmoonai-architecture/`

删除提交 **`d7af5c2b`**（k8s 仓），共 32 个文件。取回任一文件：

```bash
git -C k8s show 'd7af5c2b^:sunmoonai/docs/sunmoonai-architecture/<路径>'
git -C k8s show --name-status d7af5c2b | grep '^D'      # 完整删除清单
```

### 3.1 baseline/ → 本文档集

覆盖式重写，非拼接。旧 `baseline/{map,verify,repos/*,shared/*}` 的职责由
`overall-architecture.md` + `repos/` + `topics/` + `verify.md` 承接。

### 3.2 AGENTS.md → 拆分承接

| 旧章节 | 去向 |
| --- | --- |
| §1 权威排序、§1.1 漂移尺子、§4 维护约定与编辑自检、§6 接手演练 | [`governance.md`](governance.md) |
| §2 请求闭环、§3 进度单面、§5 评审流程与粒度 | [`request-lifecycle.md`](request-lifecycle.md) |
| §7 Git 与分支纪律、§8 多助手协作 | [`../dev-plan/agent-discipline.md`](../dev-plan/agent-discipline.md) |

### 3.3 requests/ REQ-001 ~ REQ-010 → 本节即取代记录

用户决定不保留原文件。十条的终态与去向如下；原文按 §3 开头的命令可取回。

| REQ | 终态 | 实质结论去了哪 |
| --- | --- | --- |
| 001 架构重构 | ADOPTED 但**从未落地**（声明六份产出物一件未出） | 目标由 004 + 008 从另一路径达成。**它是"僵尸请求"的原始样本**，[`request-lifecycle.md`](request-lifecycle.md) R6 双向登记规则即由它而来 |
| 002 基线核对整改 | 已执行 | 核出 14 条偏差；其方法（五仓并行、逐条取证、四类结论）固化为 [`verify.md`](verify.md) §7 |
| 003 文档集结构重组 | 不采纳，并入 004 | **双向登记的正面样本**（两侧都记了，故未僵尸化） |
| 004 现有代码投影 | PROPOSED，决策点从未拍板 | 核心结论"投影必须是纯投影、禁止吸收"进 [`governance.md`](governance.md) §8 |
| 005 智能体集群开发 | PROPOSED，两次大转向 | "技能/底座"判据与四本账进 [`request-lifecycle.md`](request-lifecycle.md) §7 |
| 006 投资研究编排 | PROPOSED | 四本账（预算/幂等/副作用/证据）进同上；缺口见 §4 |
| 007 核对流程技能化 | PROPOSED，未产出 | 未落地。核对方法本身已进 `verify.md` §7 |
| 008 五仓投影撰写 | 已执行 | 产出即 opus 分支上一版 baseline，本轮已被重写取代 |
| 009 休眠能力可识别 | PROPOSED，未产出 | 休眠项清单进各 `repos/*.md`「已知未实现」与总览 §9；**其"声明+校验"机制未落地**，见 §4 |
| 010 REQ 模板完善 | PROPOSED，未落地 | 七段式模板与八条横切规则进 [`request-lifecycle.md`](request-lifecycle.md) §4 §5 |

## 4. 未决事项（已移出）

本轮发现但未处置的八项，见
[`../dev-plan/open-issues.md`](../dev-plan/open-issues.md)（编号改为 O1–O8）。
本节保留为空壳以免旧引用失效。

## 5. 本轮的验证边界

**合并不等于架构已验证。**本文档集的运行态断言均**未经集群验证**：
集群实际状态、NetworkPolicy 是否真被 CNI 执行、远程 profile，全部未连集群核对。
完整盲区清单见 [`verify.md`](verify.md) §6。

已实际执行并通过的：四仓完整测试套件 365 passed / 8 skipped、
内核不变量 23 项、零凭据克隆全链路。
