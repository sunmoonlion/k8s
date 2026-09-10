# 环节通知 ④b 异议处置 ｜ `dev-plan-refact` 轮

发给：`cursor`（裁决方）。④ 五家已交齐，其中两家提了实质异议。按协议 §12，裁决方可以驳回异议，
但**必须逐条给理由，连同异议原文写进处置记录**，而且**必须在 ⑤ 验收之前**。

## 取件

五份异议稿已从各家分支逐字节归档到主线：

```bash
A=~/master/k8s/sunmoonai/docs/dev-plan/rounds/dev-plan-refact/reviews
$A/objection-kimi.md     # 2 条异议、2 条无异议
$A/objection-qwen.md     # 3 条异议、1 条无异议
$A/objection-opus.md     # 无异议
$A/objection-luna.md     # 无异议
$A/objection-cursor.md   # 无异议（你自己的）
```

## 要处置的 5 条

| # | 家 | 异议的条目 | 位置 |
| --- | --- | --- | --- |
| K1 | `kimi` | S3/S6 把工单字段齐全、落点齐全归 round-status（原裁定：拒绝） | `objection-kimi.md` 第 5 行起 |
| K2 | `kimi` | 决定索引文件 `rounds/decisions-index.md`（原裁定：部分接受，异议的是「接到哪」） | `objection-kimi.md` 第 14 行起 |
| Q1 | `qwen` | 发布后运行反馈与契约旧版并行（原裁定：部分接受） | `objection-qwen.md` 第 19 行起 |
| Q2 | `qwen` | 稳定落点编码 `REQ-05.3`（原裁定：部分接受） | `objection-qwen.md` 第 30 行起 |
| Q4 | `qwen` | DoD「已记录或已获授权」析取（原裁定：拒绝） | `objection-qwen.md` 第 51 行起 |

`qwen` 的第 3 条（约束委员会）写的是无异议，不用处置。

## 交什么

落点：`sunmoonai/docs/dev-plan/rounds/dev-plan-refact/disposition-objections.md`，提交在你自己的分支 `dev-plan-refact/cursor` 上。

每条写四样：

1. **异议原文**：引用，或写出完整路径和行号；
2. **裁定**：采纳 / 部分采纳 / 驳回；
3. **理由**：与什么事实相符或冲突，附可复跑的命令或完整路径 `file:line`；
4. **改了什么**：采纳或部分采纳的，要改在两份裁决稿上，一条异议一个提交，提交信息写异议编号（如 `K1`）。

另外写两段：

- **验收方复算**：按改判后的处置表重算一次 §13。验收方**不得事后更换**（§13），重算结果与原来不同时，写明并交所有者裁定。
- **是否要回到 ③**：采纳的异议如果触及基座结构，按协议「停止、超时与回退」判断要不要回到 ③，写明判断和理由。

## 请特别注意

这 5 条针对的都是你自己的处置。你既是被异议的一方，又是处置它的一方（R6 的后果）。
所以**每条驳回的理由都必须是事实，不能是「我仍然认为」**。验收方 `qwen` 在 ⑤ 会读到这些理由，
而 `qwen` 自己提了其中 3 条。

## 约束

- 只写你自己的工作区；不写主线，不写别家。
- 提交用 `--author="cursor <cursor@agents.local>"` 署自己的名（见 `protocol/GO.md` 第六节）。
- 提交后不再改。

## 交完之后

```bash
( cd ~/master/k8s && python3 sunmoonai/docs/dev-plan/protocol/round-status.py )
```

`④b 异议处置` 那一格变 ✅ 才算交了。
