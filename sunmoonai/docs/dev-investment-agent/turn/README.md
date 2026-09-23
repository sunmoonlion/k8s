# `turn/` 目录

**人（或将来代替人的脚本）和 AI 助手的一次一问一答怎么走完**——问什么、怎么答、怎么定稿、怎么验、谁批、派几家。
**新人先读这里**，再读 [`../tree-build/`](../tree-build/README.md)（这个项目建了什么）。

这里的规矩**本身不绑定投资**：换个项目、换个领域照样成立。改这里，代码不用跟着改。
⚠ 但它放在 [`dev-investment-agent/`](../README.md) 下，因为现在只有这一个项目用；
**别的项目要用就复制一份，复制即分叉**，见那一份的「别的项目要用怎么办」。

整条链有九站，每一站谁做（人还是脚本）见 [九站](../pipeline.md)。
**本目录讲的是走一次这条链要遵守什么**，不讲每一站现在谁在做。

## ⚠ 先说最要紧的一条：绝大多数问答不留痕

**默认形态是直接交互。**人在任何入口——命令行、IDE、脚本投给一个交互会话——把话说给 AI 助手，
AI 就在那个入口里答；要改文件就直接改，人看 diff、提交。
**没有目录、没有编号、没有回执、没有模板。**这是日常的绝大多数 turn。
本目录的规矩对它们只剩纪律那部分：[八条](turn-project.md)、不给倾向性结论、[批准点](approvals.md)——不要求任何文件。

**只有值得持久化的那一问，才在工作区建一个 `human-ai-turn/` 目录。**
什么算值得，见 [turn 的投影](turn-project.md)「什么时候值得留」。
把每一问都走目录，这套东西就太重了——上一版正是这么重，改掉它就是为了这一点。

## 按三件事读

一次一问一答，人实际要做的是三件事。**按你现在要干哪件事找文件**：

### 一、投喂：把这一问送出去

| 文件 | 内容 |
| --- | --- |
| [`prd/message-rules.md`](prd/message-rules.md) | **PRD** 要什么、做到什么算满足 |
| [`sdd/message-rules.md`](sdd/message-rules.md) | **SDD** 怎样满足、问到能开工为止 |
| [`imp/message-rules.md`](imp/message-rules.md) | **IMP** 工作区、工作单元、交回与证据 |
| [`uat/message-rules.md`](uat/message-rules.md) | **UAT** 验哪个提交、按哪几条判 |
| [`competition.md`](competition.md) | **先看这一份**：要不要开一次竞争（档位判据），44 行 |
| [`protocol/`](protocol/README.md) | ⚠ **只有 T2 才要读**：规范本体 1052 行 + 操作闭环。**T0/T1 不必读**——`competition.md` 那张表判完档位就够了 |

⚠ 四种 message 是**四个问题**，不是四份模板：委托什么（PRD）、分几步做（SDD）、
怎么做（IMP）、做的对不对（UAT）。**一个 turn 只问一件事。**

### 二、投影：值得留的那一问怎么落成看得见的东西

| 文件 | 内容 |
| --- | --- |
| [`turn-project.md`](turn-project.md) | **先读这一份**：默认不留痕；什么时候值得留；`human-ai-turn/` 长什么样、答落在哪、状态从 git 读；四个种类与「一问属于哪一类」；用户消息写多严；交给 agent 的活八条都成立；worktree 与追问 |
| [`user-message.md`](user-message.md) | 用户消息的模板，建 `human-ai-turn/` 时直接复制 |
| [`naming.md`](naming.md) | 命名：起新名之前先查；模块编号；门禁查什么 |

⚠ **载体就是投影**——做到哪、谁在做，从目录、diff 与提交读出来，不另写进度文件。

### 三、看投影：读答、把关、定稿

| 文件 | 内容 |
| --- | --- |
| [`finalize.md`](finalize.md) | 定稿的通则：人怎么采纳 AI 的答——与批准、验收是**三件事** |
| [`prd/finalize.md`](prd/finalize.md) · [`sdd/finalize.md`](sdd/finalize.md) · [`imp/finalize.md`](imp/finalize.md) · [`uat/finalize.md`](uat/finalize.md) | 四种各自怎么定稿：人把关时对照什么 |
| [`uat/verify-rules.md`](uat/verify-rules.md) | 怎么验：三种结论、门的三档、证据采信、覆盖声明 |
| [`approvals.md`](approvals.md) | 人的批准点：对**动作**的放行——谁负责什么、批准绑定什么、裁量底线、改判 |

## 通用的两份

| 文件 | 内容 |
| --- | --- |
| [`glossary.md`](glossary.md) | 词汇表：用词的唯一定义、编号的归属、仓的两组、规范用语。**改名须人确认** |
| [`naming.md`](naming.md) | 见上「投影」 |

## 上一版留下的东西

上一版每一问都落成 `thread/<号>-<种类>/<号>/` 目录，交回即冻结、编号只增不减。
那套目录**已退役**：已冻结的原件原样留在各任务目录的 `thread/` 下作历史，不再新增；
门禁对它们仍按旧规则查（只为防篡改历史），对新机制的 `human-ai-turn/` 不查形状。
要顺着旧原件读：

```bash
python3 sunmoonai/docs/dev-investment-agent/tools/doc-gate.py --frozen   # 列出全部
git log --all --follow --format='%h %ad %s' --date=short -- '**/<文件名>' # 按文件名找历史
```

## 这里**没**讲什么

⚠ **本目录只覆盖上面那三件事，不是「人怎么用 AI 开发」的全部。**以下都还没写：

- **怎么拆题**：一件大事怎么切成几问、切到多细才合适；
- **什么时候该止损**：一问答了三轮还不对，是继续追问还是推倒重问；
- **并行几家怎么收**：多方竞争有规则，但「什么时候值得开一次竞争」只有档位判据，没有经验法则；
- **怎么选派给谁**：各家擅长什么、什么活该给谁，没有记录。

读完这里能走完一次 turn，**但走得好不好还得靠人**。缺的这几条不要当成「规范里没写就是不重要」。
