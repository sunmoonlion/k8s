# 环节通知 ①：提案 — 轮次 runtime

> 组织者产物，落盘可复核。**本通知自足**：取件、对象事实、范围门槛、交付路径四样都在下面。
> 冻结点：标签 `runtime/h1`（commit `94558713`，所有者 2026-09-05 18:33 签发 H1）。

## 一、你是谁：先跑这条，别凭印象

```bash
basename "$(git rev-parse --show-toplevel | xargs dirname)"
```

输出就是你的参与方名（`luna` / `kimi` / `cursor` / `fable` / `qwen`）。
**输出不是你名下的那个词，就停下报告，不要猜**——本轮有两个参与方来自同一厂商的两个产品
（`cursor` = Cursor CLI，`fable` = Cursor 应用），凭自我认知会串号。

你应当在自己的 worktree 里：

| 参与方 | worktree | 分支 |
| --- | --- | --- |
| luna | `~/worktrees/luna/k8s` | `luna` |
| kimi | `~/worktrees/kimi/k8s` | `kimi` |
| cursor | `~/worktrees/cursor/k8s` | `cursor` |
| fable | `~/worktrees/fable/k8s` | `fable` |
| qwen | `~/worktrees/qwen/k8s` | `qwen` |

五家基线一致：`7e8464c2`。

## 二、取件

```bash
git show runtime/h1:sunmoonai/docs/dev-plan/rounds/runtime/task.md        # 任务书（先读这份）
git show runtime/h1:sunmoonai/docs/dev-plan/rounds/runtime/round.md       # 工单
git show 7e8464c2:sunmoonai/docs/dev-plan/refact-fable.md                 # 只读输入：上一轮最终稿
git show 7e8464c2:sunmoonai/docs/dev-plan/working/request-lifecycle.md    # 只读输入：内核
git show opus:sunmoonai/docs/dev-plan/rounds/runtime/rulings.md           # 本轮裁定（R1-R3，必读）
git show runtime/protocol:sunmoonai/docs/dev-plan/round-protocol.md       # 流程规则（不在任务书里重复）
#   ⚠ **不是** 7e8464c2 上那份。master 上的 round-protocol.md 是 165 行的旧版，
#   本轮据以运行的是 601 行版，只在标签 runtime/protocol（protocol-v2 @ 8da46502）上。
```

## 三、对象事实（自证你读的是同一版）

| 对象 | 出处 | 行数 | sha256[:16] |
| --- | --- | --- | --- |
| `task.md` | `runtime/h1` | 427 | `c31aa01cff556abd` |
| `round.md` | `runtime/h1` | 109 | `27118cf7717cb737` |
| `refact-fable.md` | `7e8464c2` | 927 | `89303624bfd9ef27` |
| `request-lifecycle.md` | `7e8464c2` | 647 | `6fcd3973ede30b88` |
| `round-protocol.md` | **`runtime/protocol`** | 601 | 见下方 ⚠ |

⚠ **协议版本**：本轮按 `protocol-v2 @ 8da46502`（601 行）运行，**不是** master 上那份 165 行的旧版。
该版本尚未并入 master，也尚有五条待所有者裁定——本轮以标签 `runtime/protocol` 钉死的这一版为准。

核对命令：`git show <出处>:<路径> | sha256sum | cut -c1-16`

## 四、范围与门槛

**题目**：`task.md` §3 的三块 + 贯穿的必答 Q。

- **P1** 只有一个运行时，开发是它的一个 Task Profile
- **P2** Interaction 必须双向且带载荷
- **P3** 执行者的可观测粒度进 Agent Profile，及其对证据权威性的后果
- **必答 Q**（单独成节，四问全答，第 2 问必须给反例）

**不受理**（`task.md` §4）：文件树重画、R0–R5 路线重排、`protocol-v2` 的五条待决、`pipeline-task.md` 那一轮。

**验收标准 10 条已冻结**（`task.md` §8），其中 8 条机械可判。开工前请逐条读，尤其：

| 条 | 一句话 |
| --- | --- |
| §8-1 | 全文不得出现「开发 Profile / 产品 Profile / Profile A / Profile B / 两个 Profile」 |
| §8-2 | 登记表里不得出现 `kind = "human"` |
| §8-6 | 必答 Q 第 2 问**给不出反例按未回答处理** |
| §8-7 | 对 OP-1 / OP-2 / OP-3 逐个表态；**反对且有理由的按加分记** |
| §8-9 | 只读输入不得改动——要改把改法写进正文 |
| §8-10 | 候选稿首行必须是身份自证行 |

**特别提醒**：`task.md` §5 那三样（OP-1 等效判据、OP-2 Interaction 字段表、OP-3 必答 Q 形式）
是**裁决方提出的，是可攻击项不是前提**。「同意 opus 的框架」不计入优点。

## 五、交付

**候选**写到你自己 worktree 的：

```
sunmoonai/docs/dev-plan/runtime-architecture.md
```

首行必须是：

```
参与方：<名>｜worktree：<绝对路径>｜HEAD：<commit>
```

写完在自己分支 `git commit`。**判定只看提交，不看工作区、不看退出码。**
自查（脚本也只在那个标签上，master 没有）：

```bash
git show runtime/protocol:sunmoonai/docs/dev-plan/round-status.py > /tmp/rs.py && python3 /tmp/rs.py
```

## 六、隔离

① 期间**不得读他家候选**，也不得写他家 worktree。互评在 ② 才开始。
本环节只做属于你的那一份。

## 七、本轮的三条裁定（`rulings.md`，必读）

| | |
| --- | --- |
| `R1` | 本轮程序基础 = 标签 `runtime/protocol`（`protocol-v2` @ `8da46502`），**不是** master 上那份 |
| `R2` | 回执不可验证，且所有者当前不存在 agent 够不着的操作面——**这是 P3 的极端案例，方案须处理这一层** |
| `R3` | 固定投喂指令本轮打了指路补丁，因为工具链停在未合并分支上 |

`R2` 尤其要看：任务书 §8 冻结在标签 `runtime/h1` 上，**冻结后不再改**，
所以这条风险登记在 `rulings.md` 而不在任务书里——这不是遗漏，是冻结在起作用。

## 八、本轮的两条如实声明

1. **回执不可验证**：本机 git 无签名配置、无 GPG 密钥，所有者与各 agent 共用同一 git 身份
   `sunmoonlion <13701819268@163.com>`。H1 那笔签发在账本上与 agent 提交不可区分。
   这是登记在案的 bootstrap 弱点，不是可以据此绕过的口子。
2. **分发全手工**：所有者裁定本轮不追求自动分发，五家均由人投喂。
