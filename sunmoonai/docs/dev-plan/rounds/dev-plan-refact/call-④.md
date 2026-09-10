# 环节通知 ④ 异议 ｜ `dev-plan-refact` 轮

发给：`opus` / `luna` / `kimi` / `cursor` / `qwen`。五家都被处置到，五家都要交。

## 取件

③ 由 `cursor` 裁决并整合（R4 指定整合方，R5 定基座为 `luna`，R6 裁决权全权委托 `cursor`）。
产物已做成只读检视面，钉在提交 `1f2d0651`：

```bash
R3=~/review/dev-plan-refact-③裁决稿/sunmoonai/docs/dev-plan
$R3/pipeline.md                            # 裁决稿 ①a   270 行
$R3/dev-plan-architecture.md               # 裁决稿 ①b   778 行
$R3/rounds/dev-plan-refact/disposition.md  # 处置记录    179 行
```

直接用读文件的方式打开。只读，不要在里面改。要核对字节：
`git show dev-plan-refact/cursor:sunmoonai/docs/dev-plan/pipeline.md | sha256sum`，应以 `c4b315911cbf7a60` 开头。

⚠ 不要读你自己 worktree 里的 `sunmoonai/docs/dev-plan/pipeline.md`——那是你自己的 ① 候选，不是裁决稿。

## 交什么

落点：`sunmoonai/docs/dev-plan/rounds/dev-plan-refact/reviews/objection-<你的名>.md`，提交在你自己的分支上。

**没有异议也要交**，写「无异议」。否则分不出「没人反对」和「没人看过」。

每条异议写四项，缺一项不予处置：

| 项 | 写什么 |
| --- | --- |
| 条目 | 处置记录 §二 的哪一行（照抄「出处家｜条目」），或 §三 验收方计算 |
| 为什么错 | 它和什么事实冲突，不是「我不同意」 |
| 应当是什么 | 你认为正确的处置 |
| 证据 | 一条可复跑的命令，或一处 `file:line` |

`file:line` 必须写完整路径，例如 `~/review/dev-plan-refact-③裁决稿/sunmoonai/docs/dev-plan/pipeline.md:150`。
只写 `pipeline.md:150` 按无证据计：这个文件名在五个 worktree 里是五份不同的文件。

## 你能提异议的条目

只能就**你自己的主张**被怎么处置提异议（协议 §12）。被「接受」的不算。

| 家 | 条数 | 条目 |
| --- | --- | --- |
| `opus` | 4 | 部分接受：F-9–F-12 判据自身必须先被验证／拒绝：①b 两行迁移表（:450 → WAITING）、本轮物理拆内核、按目录立 ROUND 类型 |
| `luna` | 1 | 部分接受：Q3 protocol 是 SDP 引用的执行附件 |
| `kimi` | 4 | 部分接受：protocol 不是实施计划、Q8 落 `docs/evidence/<task-id>/`、决定索引文件／拒绝：S3/S6 归 round-status |
| `qwen` | 4 | 部分接受：发布后运行反馈与契约旧版并行、稳定落点编码 `REQ-05.3`／拒绝：约束委员会、DoD「已记录或已获授权」析取 |
| `cursor` | 7，全是自处置 | 见下「重点 1」 |

## 请重点看的三处

1. **`cursor` 自己的 7 条，④ 里没人能查。**这 7 条的被处置方就是裁决方本人，自己驳自己没有意义。这是 R6 的已知后果：这 7 条直接进 ⑤，由验收方 `qwen` 重点看。
2. **验收方是 `qwen`。**排除 `cursor`（裁决兼整合）、`luna`（基座作者）后，取「接受 + 部分接受」最少的一家：`opus` 6 / `kimi` 8 / `qwen` 4。组织者已独立复算，结果一致。要推翻，请指出哪一条的出处或裁定判错了。
3. **裁决方自己说没查的三处**（处置记录 §五）：`luna` RUNNER 的双向核；`opus` 那组计数命令（58/44/49/10/8）；`doc-gate` 以外的产品仓测试。涉及你的，自己复跑。

## 约束

- 只写你自己的工作区；不写主线，不写别家。
- B14 不得照抄 `inputs/`，在 ④ 仍然有效。
- 提交后不再改。

## 交完之后

```bash
( cd ~/master/k8s && python3 sunmoonai/docs/dev-plan/protocol/round-status.py )
```

你那格变 ✅ 才算交了。
