# `turn/` 目录

**一次一问一答怎么走完**——问什么、怎么答、怎么定稿、怎么验、谁批、派几家。
**新人先读这里**,再读 [`../tree/`](../tree/)(这个项目建了什么)。

这里的规矩**跨项目通用**:换个项目、换个领域照样用。改这里,代码不用跟着改。

整条链有九站,每一站谁做(人还是脚本)见 [九站](../pipeline.md)。
**本目录讲的是走一次这条链要遵守什么**,不讲每一站现在谁在做。

## 按三件事读

一次一问一答,人实际要做的是三件事。**按你现在要干哪件事找文件**:

### 一、投喂:把这一问送出去

| 文件 | 内容 |
| --- | --- |
| [`prd/message-rules.md`](prd/message-rules.md) | **PRD** 要什么、做到什么算满足 |
| [`sdd/message-rules.md`](sdd/message-rules.md) | **SDD** 怎样满足、问到能开工为止 |
| [`imp/message-rules.md`](imp/message-rules.md) | **IMP** 工作区、工作单元、交回与证据 |
| [`uat/message-rules.md`](uat/message-rules.md) | **UAT** 验哪个提交、按哪几条判 |
| [`competition.md`](competition.md) | 一问派几家:多方竞争的规则 |
| [`protocol/`](protocol/README.md) | 多方竞争在本平台怎么做:规范本体、各环节入口、操作闭环 |

⚠ 四种 message 是**四个问题**,不是四份模板:委托什么(PRD)、分几步做(SDD)、
怎么做(IMP)、做的对不对(UAT)。**一个 turn 只问一件事。**

### 二、投影:把问与答落成看得见的东西

| 文件 | 内容 |
| --- | --- |
| [`turn-project.md`](turn-project.md) | **先读这一份**:任务目录、thread 与 turn 两级、三个文件的形状与字段、编号;四个种类与「一问属于哪一类」;用户消息写多严;交给 agent 的活八条都成立;worktree 与返工 |
| [`user-message.md`](user-message.md) · [`turn.md`](turn.md) | 两个模板,建 turn 时直接复制 |
| [`naming.md`](naming.md) | 命名与编号:目录名、编号、与运行时的对应,以及门禁的判据 |

⚠ **载体就是投影**——做到哪、谁在做、第几次返工,一律从这些目录与提交读出来,不另写进度文件。

### 三、看投影:读答、把关、定稿

| 文件 | 内容 |
| --- | --- |
| [`finalize.md`](finalize.md) | 定稿的通则:人怎么采纳 response——与批准、验收是**三件事** |
| [`prd/finalize.md`](prd/finalize.md) · [`sdd/finalize.md`](sdd/finalize.md) · [`imp/finalize.md`](imp/finalize.md) · [`uat/finalize.md`](uat/finalize.md) | 四种各自怎么定稿:人把关时对照什么 |
| [`uat/verify-rules.md`](uat/verify-rules.md) | 怎么验:三种结论、门的三档、证据采信、覆盖声明 |
| [`approvals.md`](approvals.md) | 人的批准点:对**动作**的放行——谁负责什么、批准绑定什么、裁量底线、改判 |

## 通用的两份

| 文件 | 内容 |
| --- | --- |
| [`glossary.md`](glossary.md) | 词汇表:用词的唯一定义、编号的归属、仓的两组、规范用语。**改名须人确认** |
| [`naming.md`](naming.md) | 见上「投影」 |

## 这里**没**讲什么

⚠ **本目录只覆盖上面那三件事,不是「人怎么用 AI 开发」的全部。**以下都还没写:

- **怎么拆题**:一件大事怎么切成几问、切到多细才合适;
- **什么时候该止损**:一问答了三轮还不对,是继续返工还是推倒重写一问;
- **并行几家怎么收**:多方竞争有规则,但「什么时候值得开一次竞争」只有档位判据,没有经验法则;
- **怎么选派给谁**:各家擅长什么、什么活该给谁,没有记录。

读完这里能走完一次 turn,**但走得好不好还得靠人**。缺的这几条不要当成「规范里没写就是不重要」。
