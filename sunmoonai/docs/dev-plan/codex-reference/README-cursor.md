# codex-reference（cursor）

> 最后更新：2026-09-02
>
> 性质：本分支自己的调研底稿，非 baseline、非 REQ。各分支只放自己写的那份。

对照其他助手的**题目清单**补全本目录。2026-08-22 只交了架构总稿和 SQLBot
取舍；沙箱、WrenAI、Codex 编排复核、可迁移机制当时没写成专文。本轮按同一
套结论补上，取证钉到本机仓库提交号。

## 文档

| 文件 | 管什么 |
| --- | --- |
| [`investment-app-agent-architecture-cursor.md`](investment-app-agent-architecture-cursor.md) | **总稿**：一个 Agent、熟路/生路一套地基、借思想不借工具名 |
| [`sqlbot-cursor.md`](sqlbot-cursor.md) | SQLBot 不换路线；借术语 / few-shot / ChartSpec / MCP |
| [`wrenai-financial-analysis-integration-cursor.md`](wrenai-financial-analysis-integration-cursor.md) | Wren 是语义层工具包；`dry_plan` 与 `query` 必须分开；默认防护不够 |
| [`sandbox-extension-advice-cursor.md`](sandbox-extension-advice-cursor.md) | 该做，但不做 Landlock；Host 就是 Docker；网络单独一维 |
| [`codex-orchestration-assessment-cursor.md`](codex-orchestration-assessment-cursor.md) | 复核《Codex 编排能力完全指南》；默认是 V1，文章写的是 V2 |
| [`codex-mechanisms-for-investment-agent-cursor.md`](codex-mechanisms-for-investment-agent-cursor.md) | 哪些机制能搬进 investment-app，哪些只作对照 |

## 取证基准（2026-09-02）

| 仓库 | 提交 | 用途 |
| --- | --- | --- |
| `/home/zym/repo/codex` | `7d6f808b97` | 编排、沙箱策略、多智能体 V1/V2 |
| `/home/zym/repo/WrenAI` | `5f8bc24e` | MDL、SDK 工具、SQL policy |
| `/home/zym/repo/SQLBot` | `59ca0970` | 已在 `sqlbot-cursor.md` 评过，本轮不重写 |
| `worktrees/cursor/investment-app` | 当前 worktree | Port / 休眠能力 |

## 和总稿的关系

总稿已经定了形态：浏览器是入口，服务端是控制面，Docker 是 Host；问数走受管
SQL，任意代码走容器。后面四篇是把这句话拆开写清楚，不是另立一套。

撰写时读了其他助手的**目录和结论摘要**以对齐题目。正文按本分支 8 月总稿
续写，不把别人的框架当自己的发现。
