# 《Codex 编排能力完全指南》复核：以最新版源码为准

> 取证时点：2026-08-28 ｜ 作者：opus
> 考证对象：`~/note/Codex编排能力完全指南.md`（1009 行，2026-08-15，下称"文章"）
> 取证基准：`/home/zym/repo/codex` @ `main` `7d6f808b97`（2026-08-28）
>
> **与 kimi / qwen3.8 两份考证的差别**：他们考证于 2026-08-17，
> 证据来自**活会话实测**（kimi）与**磁盘取证**（qwen3.8）；
> 我的证据是**最新版源码**，比他们的取证基准新约 11 天、449 个提交。
> 三者互补，不互相取代——**他们能看到运行时，我只能看到代码**。

## 0. 结论

**文章描述的能力在最新版源码里绝大多数仍然成立**，没有发现整段虚构。
但读它需要知道三件事，其中第一件是此前两份考证都没解决的。

## 1. 最要紧的一条：文章描述的是 V2，而默认跑的是 V1

kimi 实测到的工具名与文章对不上（`send_input`/`resume_agent`/`fork_context` 布尔
vs 文章的 `send_message`/`followup_task`/`fork_turns` 三档）。
kimi 判为"版本漂移"并列入 C 级证据；qwen3.8 写"按 kimi 的 C 级清单打折"，采纳未再追查。

**实际不是漂移。两代实现同时躺在代码里：**

| | V1 | V2 |
| --- | --- | --- |
| 目录 | `core/src/tools/handlers/multi_agents/` | `.../multi_agents_v2/` |
| 消息工具 | `send_input.rs` · `resume_agent.rs` | `send_message.rs` · `followup_task.rs` · `message_tool.rs` |
| 上下文继承 | `fork_context`（布尔两档） | `fork_turns`（`all` / `none` / 正整数） |

选择逻辑（`core/src/config/mod.rs`）：

```rust
fn multi_agent_version_from_features(&self) -> MultiAgentVersion {
    self.multi_agent_version_override().unwrap_or_else(|| {
        if self.features.enabled(Feature::Collab) { MultiAgentVersion::V1 }
        else { MultiAgentVersion::Disabled }
    })
}
```

**开启 `Collab` 时默认落到 V1，V2 必须显式 override。**
所以 kimi 的活会话看到 V1 是正常默认行为，文章描述的是 V2——**两边都没错**。

**这条对使用文章的人很重要**：照文章的工具名去调，在默认配置下会调不到。
要用 V2 语义，先确认 `multi_agent_version` 被显式设成 V2。

```bash
ls codex-rs/core/src/tools/handlers/multi_agents/ codex-rs/core/src/tools/handlers/multi_agents_v2/
sed -n '/fn multi_agent_version_from_features/,/^    }/p' codex-rs/core/src/config/mod.rs
```

## 2. 文章的核心断言逐条复核（最新版）

| 文章说法 | 复核结果 |
| --- | --- |
| 工具延迟加载 `defer_loading` | ✓ 65 个文件命中 |
| `multi_agent` 特性存在 | ✓ `Feature::Collab`，42 个文件 |
| Goal（跨 Turn 长期目标） | ✓ 6 个文件；且 `ThreadGoalStatus` 是**持久化状态**，含 `BudgetLimited`/`UsageLimited` |
| 内核级沙箱（非容器） | ✓ `seccomp` 19 文件、`Landlock` 74 文件 |
| Heartbeat / Cron | ✓ `automation` 32 文件 |
| `outputSchema` | ✓ 110 文件；且确认是 **turn 级参数**（`v2/turn.rs`："constrain the final assistant message for this turn"） |
| 七个 subagent 原语 | ✓ 逐个命中，与我独立数出的完全一致 |
| `enable_fanout` 已 removed | ✓ **确认**：`features/src/lib.rs` 仍有该键，但 CLI 测试名直接叫 `feature_toggles_accept_removed_enable_fanout_flag`——即"接受但已移除"，是兼容残留 |
| 会话以 jsonl rollout 落盘 | ✓ `rollout/src/recorder.rs` 首行自述 |

**没有一条被证伪。**

## 3. 文章的三层水分，我能补充的

kimi 总结的三层（转述链长 / 入口能力差 / "八种拓扑"是作者总结非内置）我认同，
其中第三层最要紧，kimi 的原话值得原样保留：

> **Codex 内部不存在一个叫 Supervisor 的模块——编排逻辑运行在模型的推理里，
> 不运行在 Codex 的代码里。**

我从源码侧能给这条加一个佐证，也能给它加一处限定：

**佐证**：多智能体的并发上限确实经由**提示词**告知模型
（`session/multi_agents.rs` 拼 "There are N available concurrency slots"）。

**限定**：但它**不只是**提示词——同一个配置值经
`effective_agent_max_threads()`（`saturating_sub(1)`，根 agent 不计入）
落到 `reserve_spawn_slot(max_threads)`，那里有 CAS 原子占位与
`AgentLimitReached` 硬失败。

**所以更准确的说法是**：编排的**决策**在模型的推理里，
但编排的**边界**（并发上限、深度上限）在代码里强制。
两者同源，不是纯自律。这一点文章与两份考证都没写到。

> 我初稿曾断言这两处"不同源"，是错的——一次范围过窄的 grep。
> 复核调用链后证伪，此处是更正后的结论。

```bash
sed -n '/fn effective_agent_max_threads/,/^    }/p' codex-rs/core/src/config/mod.rs
sed -n '/fn try_increment_spawned/,/^    }/p' codex-rs/core/src/agent/registry.rs
```

## 4. 文章写作后新增的东西（它不可能覆盖）

文章写于 2026-08-15，以下是之后新增、且与编排相关的：

| 新增 | 提交 | 说明 |
| --- | --- | --- |
| `worktree` crate | `f832b2fe7b` (#40624)、`#40716` | git worktree 设置解析 + **托管 worktree 的线程归属元数据**。文章说"Worktree 为桌面 App 独占"，现在它被抽成独立 crate，边界可能在变 |
| `agent-roles` crate | `fb9311db5c` (#40487) | agent 角色加载抽取为独立 crate（重构，非新功能） |
| `registry` 增加环境驱逐追踪 | — | `RegisteredAgent{path, evicted_environments}`，与 worktree 相关 |
| Guardian 合并为 `guardian-v2` | `e741cd9ace` (#39474) | **不是删除**。`core/src/guardian` 与 `ext/guardian-v2` 都在 |

**这说明一件事**：这个仓 8 天 449 个提交。任何针对它的分析都必须**声明取证提交号**，
否则读者无法判断结论是否还成立。文章、kimi、qwen3.8 三份都没有钉提交号——
这不是它们的错（当时没这个习惯），但**下一轮应当补上**。

## 5. 我这份考证的边界

| 边界 | 说明 |
| --- | --- |
| **拿不到运行时证据** | kimi 的活会话实测（Seccomp 值、工具搜索结果、`features list` 输出）与 qwen3.8 的磁盘取证（rollout jsonl、goals sqlite），我都无法复现。**这两层他们比我强** |
| 只读源码约 5% | 153 万行读了六个 crate 的关键路径 |
| 未编译未运行 | 全部结论来自静态读码 |
| "文章说 X，源码有 X" 不等于"运行时行为是 X" | 代码存在 ≠ 该路径被启用。V1/V2 那条正是这个道理的例子 |
| 未核对文章的"八种拓扑"章节 | 那是作者的设计模式总结，不是可对源码证伪的断言，本文不置评 |
