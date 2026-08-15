# REQ-002：基线核对整改

> 状态：REVIEWED ｜ 提出日期：2026-08-14 ｜ 评审日期：2026-08-14

## ① 原始需求

> @baseline 是某个人写的，我觉得它写的不太好，你把相关文件读一下，指出它需要改进的，注意，
> 你单独写个改进md，不要动它的 @baseline

> 我奇怪，你没读原来的五个仓库，你review的依据从何而来

> 这样吧：你在5仓的master都开一分支opus分支，然后读5仓最后你改自己分支里的
> esunmoonai-architecture，好吗

## ② 架构评审

- 结论：**采纳**

- 理由：
  - 第一轮评审只做了结构核对（baseline 内部 + 与 AGENTS.md 对照），用户指出其依据不足，
    要求补足代码侧证据。这一质疑成立：baseline 定位是「代码现状的镜子」（AGENTS.md §0），
    未读代码的评审无法判断它是否还是镜子。
  - 补做五仓深读后，确认 baseline 的**技术描述总体准确**，但存在 5 条会误导实施者的事实性
    错误，以及若干过期与归因错误。按 AGENTS.md §1「代码是现状的唯一真相」，这些必须以代码为准修正。
  - 核对中另发现 3 条**代码侧疑点**（非文档问题），按 AGENTS.md §1.1 智能体义务向用户提出，
    不擅自改代码，见 `plan-baseline.md` §3。

- 冲突与代价对比：无架构冲突。本请求只做「文档追平代码」，不改变任何架构决策。
  唯一需要用户拍板的是 §3 的三条代码疑点，以及 `plan-baseline.md` §4 列出的、
  触及治理文件（AGENTS.md / README / TEMPLATE）因而按 §7 不能在功能分支上处理的条目。

- 评审依据的取证方式与覆盖边界见 `plan-baseline.md` §0，未核对项显式列在 §5，不做背书。

## ③ 落地去向

- 核对结果与整改项清单：本文件夹 `plan-baseline.md`
- baseline 修正：`baseline/app-platform/intra-apps/{tpl-app,info-app,knowledge-app,investment-app,k8s}/`
  与 `baseline/sunmoonai/architecture.md`，逐条对应 `plan-baseline.md` 的编号
- 代码疑点：`plan-baseline.md` §3，等用户决策，不在本请求内改代码
- 治理文件相关项：`plan-baseline.md` §4，按 AGENTS.md §7 留待共享分支处理

## ④ 状态流转

| 日期 | 状态 | 说明 |
| --- | --- | --- |
| 2026-08-14 | PROPOSED | 用户提出 baseline 质量评审 |
| 2026-08-14 | REVIEWED | 五仓深读完成，核对结论落 `plan-baseline.md`；采纳并开始整改 |
