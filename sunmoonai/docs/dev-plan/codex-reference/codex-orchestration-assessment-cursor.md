# 《Codex 编排能力完全指南》复核（Cursor 版）

> 最后更新：2026-09-02
>
> 考证对象：`~/note/Codex编排能力完全指南.md`（2026-08-15）
> 取证：`/home/zym/repo/codex` @ `7d6f808b97`（2026-08-28）
> 总稿已用过这篇文章：借控制环，不借工具名，不把八种拓扑写成引擎。

## 结论

文章描述的能力在这份源码里**大体还在**，没有整段虚构。但用它当施工图会踩
三件事：

1. **文章写的是 V2，默认跑的是 V1。** 工具名对不上不是漂移。
2. **没有 Supervisor 模块。** 拆不拆、派谁、等谁，在模型推理里；代码只强制
   边界（并发、深度、预算中止）。
3. **八种拓扑是作者总结，不是内置类型。** 总稿已经按这个写了：能事先画的边
   写成静态图，画不出来的才走控制环。

因此：熟路继续静态图；生路只借文章的控制环语义；**任何工具名不得进 API**。

## 1. V1 / V2 同时在树上

```text
codex-rs/core/src/tools/handlers/multi_agents/      # V1
  send_input.rs  resume_agent.rs  spawn.rs  wait.rs  close_agent.rs

codex-rs/core/src/tools/handlers/multi_agents_v2/   # V2
  send_message.rs  followup_task.rs  message_tool.rs
  spawn.rs  wait.rs  interrupt_agent.rs  list_agents.rs
```

今日 `ls` 两套目录都在。文章用的 `send_message` / `followup_task` /
`fork_turns` 是 V2。默认开 `Collab` 落到 V1（`send_input` / `resume_agent` /
布尔 `fork_context`）。活会话对不上文章，两边都没错。

investment-app **两套都不实现成工具名**。要参照语义，写明参照 V2：
`fork_turns` 的 all / none / N，比布尔继承有用。

```bash
ls /home/zym/repo/codex/codex-rs/core/src/tools/handlers/multi_agents \
   /home/zym/repo/codex/codex-rs/core/src/tools/handlers/multi_agents_v2
rg -n "fn multi_agent_version_from_features|Feature::Collab" \
  /home/zym/repo/codex/codex-rs/core/src/config/mod.rs
```

## 2. 文章核心断言（对照这份源码）

| 文章说法 | 今日 |
| --- | --- |
| 多智能体工具集存在 | ✓ 两代目录都在 |
| 内核级沙箱 | ✓ `SandboxPolicy` + linux-sandbox / windows-sandbox-rs |
| 会话 jsonl rollout | ✓ `rollout` crate |
| `output_schema` | ✓ 存在；按协议注释是 **turn 级**，不是全局契约 |
| Goal / 预算中止 | ✓ `ThreadGoalStatus` 含 `BudgetLimited` / `UsageLimited` |
| `enable_fanout` 已 removed | 当兼容残留看，不要当能力宣传 |

没有一条被整段证伪。**「源码有」不等于「默认路径会跑到」。** V1/V2 就是例子。

## 3. 总稿已经写对、这里只加钉的

总稿 §2：「文章里的八种拓扑是用法，不是引擎。Codex 自己也没有一个叫
Supervisor 的运行时模块。」

源码侧补一句限定：并发上限会写进提示词，**也会**经占位失败硬拒绝。编排
**决策**在模型里，编排**边界**在代码里，两者该同源。我们搬边界（预算、
取消、并发槽），不搬「模型现场规划整张图」当整机。

总稿还写过：文章用名可能和源码漂移，不得锁进契约。现在可以写得更准——
不是漂移，是两代并存。禁令不变。

## 4. 文章之后仓里多出来的（它覆盖不到）

这份 `7d6f808b97` 相对文章日期已经走过大量提交。和编排相关、值得知道的：

- `worktree` 抽成独立 crate：桌面独占的边界在变，不改变「我们 Host 只用 Docker」
- `guardian` 合并为 `guardian-v2`：是改名合并，不是删除
- agent registry 增加环境驱逐追踪

以后再写对照，必须钉提交号。本文钉 `7d6f808b97`。

## 5. 边界

- 未实跑 Codex，无会话 jsonl、无 `features list` 输出
- 只读 handlers / protocol / config 关键路径，不是全仓
- 「八种拓扑」不作源码证伪，当设计模式看
- 未核对文章每一条 CLI 示例是否仍能跑通
