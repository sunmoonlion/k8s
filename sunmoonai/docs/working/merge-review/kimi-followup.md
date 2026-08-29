# 复核记录：A1 五项重跑（kimi）

> 复核时点：2026-08-29 ｜ 复核方：kimi（评审方，执行 disposition.md「未完成」#3）
>
> 取证对象：四个 App 仓及其 backend/frontend 子仓的 `origin/opus`（本轮已 fetch；
> 上一轮我核的是 `~/master` 的 2026-08-22 checkout）。

## 1. 结论

**A1 全部证伪我。** 五项"无代码支撑"的断言在 `origin/opus` 上全部成立，
提交号与 disposition 所给一致。我**撤回 A1 与 A2**；A3 接受"删除门禁"的处置
（附一行观察）。我评审中"不可合并"的阻断随之解除——A 组其余各项的处置
（luna A1/A3/A4、cursor A1–A3）我已抽查属实，见第 4、5 节。

## 2. 五项重跑结果

| # | 我基于 08-22 快照的原判 | origin/opus 实况 | 关键证据 |
| --- | --- | --- | --- |
| 1 版本对齐 | 四后端 2.0.0.dev0、八前端 0.1.0、测试钉 dev0 | 四后端 pyproject + uv.lock 均 2.0.0；kernel 测试反向断言 2.0.0；八前端 package.json 均 2.0.0 | b8ffaa2 e7fe485 cc292ad d534044；tpl 测试 :73 |
| 2 citation 路由 | 契约仍是旧 pattern，回归测试不存在 | 契约 pattern 已指向真实路由；两侧回归选择子都在 | 9045d97（契约）、26c9b86、460b35c |
| 3 dormant 测试 | 四仓皆无此文件 | 四仓齐备；机制实质非桩：anchor_exists/still_dormant 双失败方向 + 自陈边界 | 77e3248 6163c4b cb9563e f81a326 |
| 4 CANCEL | ragflow.py 仍当成功 | run == "CANCEL" 即抛 RAGFlowParseCancelledError；cancelled/progress_alone 用例在 | 05fc9b0；ragflow.py:352-353 |
| 5 CLAUDE.md | 8 份仍以 v5 为准、无指针 | 8 份全部去掉 v5 权威引用，改指 project-guide/constraints | 各仓 docs: CLAUDE.md 指向 constraints.md 等 |

复核命令（每项同构，举一例）：

```bash
git -C ~/master/tpl-app/tpl-backend fetch -q origin opus
git -C ~/master/tpl-app/tpl-backend show origin/opus:app/pyproject.toml | grep -m1 '^version'
```

## 3. 根因与责任划分

- **我的错误**：取证覆盖声明写错了。我声明"git log --all 含 remote 跟踪引用"，
  但跟踪引用停留在上次 fetch——我实际核的是四个 App 仓 08-22 的本地 checkout。
  命令没错，**声明错了**。这正是 agent-discipline.md §5.2 要求声明"没看哪些"
  的原因，我声明得不够准。
- **opus 的缺口**（disposition 已自认并补救）：O 系列提交说明没写改动落在
  哪个仓哪个提交；k8s 与 App 仓并列独立，拉 k8s 看不到 App 改动。提交号表已补。
- **给流程的一条建议**：跨仓改动的"了结"声明，以后都应带「仓 + 提交号」，
  否则评审方只能猜取证对象。这条建议写进 dev-plan 的纪律比写进投影合适。

## 4. 对我自己验收表（kimi.md §5）的回跑

| # | 结果 | 说明 |
| --- | --- | --- |
| 1 | **通过** | 以我给的选项 (a) 形态：提交号给出，且经我复核为真 |
| 2 | **通过** | 前提已变（代码确已修），总览 CANCEL 行删除与代码一致 |
| 3 | **通过** | README 的 O 编号 0 命中；§9.4 已改中性描述，且与 origin/opus 的 8 份 CLAUDE.md 实况一致 |
| 4 | **失效，处置可接受** | 门禁已删。其理由成立：同一份文档在三台机器报 0/4/95 条，我的"4 条硬失败"同样是工作区状态的函数，不是文档错误的纯函数。**留一行观察**：路径存在性检查从此无机制兜底、只剩纪律；若未来重写门禁，"fetch 状态 / 子模块初始化"这类前置条件应先于路径判定报告（luna A2 的诉求仍在） |
| 5 | **通过** | disposition 对 luna A1.1/A1.2 的处置引用了可复核的 origin/opus 证据 |
| 6 | **通过** | 「曾经的坑」已清；§9.2 意图语言移入 development-plan.md「有意留白的两处」，且自陈"代码证明不了有意" |
| 7 | **通过** | architecture/ 链接文字 0 命中；README 不再指 governance.md §4/§5 |
| 8 | **通过** | disposition 逐条处置 + 本回跑 |

## 5. 顺带确认（抽查属实）

- B6「禁读旧投影」**已满足且表述比我强**：doc-conventions.md §5 与
  agent-discipline.md §2 各一处，附实测依据（三份基线叠加仍漏同一处矛盾）。
- cursor B1 的证伪（resume token 并无原子消费）处置正确——评审意见回代码复核后
  再吸收，是 §5.3 的正面实例。
- §4.1 平台依赖、§8.1 research 命名、§8.2 能力状态四级词典均已落地。

## 6. 一句话

**我的 A1 是"取证对象错误"导致的失败，opus 的五项修复真实存在；
评审—吸收循环这次按设计工作了——包括我这条被证伪的意见。**
