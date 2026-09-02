# codex-reference（opus）

> 最后更新：2026-08-28

## 这是什么

研读 Codex 源码（`/home/zym/repo/codex`），为 investment-app 的 agent 架构找可迁移的机制。

| 文件 | 内容 |
| --- | --- |
| [`codex-mechanisms-for-investment-agent-opus.md`](codex-mechanisms-for-investment-agent-opus.md) | **主文**：七个机制的取证、可迁移性判定、落地顺序、盲区 |
| [`codex-orchestration-assessment-opus.md`](codex-orchestration-assessment-opus.md) | 用**最新版源码**复核那篇指南；解开 V1/V2 悬案 |
| [`investment-app-agent-architecture-opus.md`](investment-app-agent-architecture-opus.md) | 我们自己的现状诊断：四个真缺口、四件做对的事、落地顺序 |
| [`sandbox-extension-advice-opus.md`](sandbox-extension-advice-opus.md) | 沙箱该不该做；含对我自己一处判断的更正 |
| [`sqlbot-opus.md`](sqlbot-opus.md) | SQLBot 能不能接、安全边界够不够 |
| [`wrenai-opus.md`](wrenai-opus.md) | WrenAI **已转型为语义层**；安全机制默认不开 |

**版本基准**：Codex `main` @ `7d6f808b97`（2026-08-28）。
初稿基于落后 449 个提交的旧 checkout，已更新并逐条复核，七个机制全部仍成立。

## 方法

**筛选判据**不是"Codex 有什么功能"，而是本项目已立的那条
（`k8s/sunmoonai/docs/architecture/request-lifecycle.md` §7）：

> 跨 run、或跨进程死亡仍须正确的不变量，必须由存储承担，不能靠执行者自律。

凡 Codex 在这个判据上有实现的才收；纯提示词层面的约定不收。
这样筛出来的东西才对 investment-app 已知的两处真缺口（`RunBudget` 未接线、证据账缺失）有用。

**隔离**：撰写时未读其他助手（cursor / kimi / luna / qwen3.8）的 codex-reference 正文，
只看了文件名以确定选题范围。理由见
`k8s/sunmoonai/docs/architecture/multi-assistant-workflow.md` §2——
提案阶段互相可见会让产出向先读到的方案收敛，那样问 N 家的成本花了却只拿到一家的信息量。

**取证**：每条断言附可跑的命令，工作目录 `/home/zym/repo/codex`。
本轮关键命令已逐条实跑验证；更新到最新版后又复核一遍。

## 与 `~/note/Codex编排能力完全指南.md` 的关系

那份 1009 行的指南写于 2026-08-15，比本轮早 12 天。**两者定位互补，不重复**：

| | 那份指南 | 本文 |
| --- | --- | --- |
| 视角 | 外向：**能用 Codex 做什么**（三层编排原语、八种拓扑、CLI 脚本化） | 内向：**它内部怎么保证不变量**，什么能搬进 investment-app |
| 判据 | 能力全景 | 跨 run / 跨进程死亡的不变量是否由存储承担 |

**交叉核对结果**：它列的七个 subagent 原语与我独立数出的完全一致。
它有两处我初稿漏了，我回源码独立验证后补入（M6）：

- `output_schema` 是 **turn 级**参数（`v2/turn.rs:146`），不是全局契约——已验证
- `turn/steer` 与 `turn/start`、`turn/interrupt` 是三个独立 RPC——已验证

## 四次被推翻的判断（全是同一类错误）

1. 初稿 §3 断言 Codex "告诉模型的并发上限与强制的上限不同源"——**证伪**。
   两者由 `effective_agent_max_threads()` 绑定，差一个 `saturating_sub(1)`（根不计入配额）。
2. 核对上述指南时，我按工具名 grep，判定 `handoff_thread` 等五个原语"不存在"——**证伪**。
   换关键词后 `handoff` 命中 43 个文件：**指南写的是工具面名字，Rust 内部标识符不同。**

3. 更新到最新版后，用 `git show <新提交>:<路径>` 查 `registry.rs` 的符号，
   全返回空，我一度以为机制被删——实际是 `git show` 静默失败，`git grep` 一查全在。
4. 见 Cargo.toml 消失就判定 `ext/guardian` **被删除**——实际是
   `e741cd9ace` 合并为 `guardian-v2`，全树 220 个文件仍引用它。

**四次同因：把"工具没返回结果"当成"事实不存在"。**
grep 范围、关键词、文件移动、命令静默失败，都会产生假阴性。

**已确立的做法**：结论涉及"某东西不存在/被删除"时，必须
（a）换 2–3 个关键词复验，且（b）用 `git log --diff-filter=A/D -- <路径>`
查提交历史——它能区分"删除"与"移动/改名"，而 grep 不能。

第 1 条的更正记录保留在主文 §3 内，说明结论是怎么被推翻的。

## 与 kimi / qwen3.8 两份考证的关系

它们（2026-08-17）考证的对象是**那份指南 + 当时的 Codex 运行环境**，
证据来自活会话实测（kimi）与磁盘取证（qwen3.8）——**这两类证据我拿不到**，
它们的结论在那两层上比我强。

我的对象是**源码本身**，因此能做它们做不到的两件事：

1. **量化了版本前提**：本地 checkout 落后上游 449 个提交（8 天），
   并逐条复核出本文七个机制在最新版全部仍成立（正文 §0.0）。
   它们的分析写于比这个 checkout 更早的状态，未量化该风险。
2. **解开了它们留作悬案的一个问题**：工具名对不上，kimi 判为"版本漂移"，
   qwen3.8 采纳未再追查。实际是 **V1/V2 两代实现并存**，
   由 `Feature::Collab` 默认落到 V1、V2 需显式 override（正文 §0.1）。

**一处方法上的观察**：qwen3.8 明确引用并采纳了 kimi 的框架（"按 kimi 的 C 级清单打折"）。
这在定向审核模式下是合理的，但代价是该条上没有第二个独立判断——
恰好印证 `multi-assistant-workflow.md` §5.5：**继承他人框架会让重叠虚高、盲区照旧**。
本轮我在隔离下产出、事后才交叉核对，两边发现的集合基本不相交，
按同一条判据这说明**整体覆盖率仍低**，不是"审得全"。

## 边界

Codex 最新版是 3430 个 Rust 文件 / 153 万行，本轮读了约 5%（`protocol` `core/agent`
`core/session` `core/tools/handlers` `state` `rollout`）。全部结论来自静态读码，
未编译、未跑测试、未实跑 Codex。

**各篇另有自己的边界节**，其中两处空白值得单独点名：
- **SQLBot 与 WrenAI 的准确率均未评估**——那是选型的核心指标，两篇都没碰
- WrenAI 盘上版本**落后上游 202 个提交 / 3 个月**，且该项目**已转型**
  （GenBI 应用被冻结在 `legacy/v1`），此前基于旧形态的分析可能整体失效（`wrenai-opus.md` §0.2）

**本机另有 `FinRobot` 与 `ragflow` 两个仓未分析。**`ragflow` 与本项目直接相关——
knowledge-app 就把它当派生系统用（ADR-0005），却从未做过源码级分析。
