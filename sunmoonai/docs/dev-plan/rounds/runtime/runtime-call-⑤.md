# 环节通知 ⑤：验收 — 轮次 runtime

> 裁决方产物，落盘可复核。**本环节只有一个执行者：验收方 `qwen`。**
> 其余各家本环节无动作；本通知公开可查，供交叉检验。

## 一、验收方是怎么算出来的（不是指定的）

按 `round-protocol.md`「⑤ 验收 与 ⑥ 确认」，验收方由 ③ 的机器可读处置表算出，规则依次适用：
① 不得是裁决方 → 排除 `opus`；② 不得是基座作者 → 排除 `fable`；
③ 剩下的家里取处置表中 `接受` + `部分接受` 条数最少的一家。

| 家 | 接受 | 部分接受 | 拒绝 | 既得利益 |
| --- | ---: | ---: | ---: | ---: |
| fable（基座，排除） | 4 | 1 | 4 | 5 |
| luna | 7 | 2 | 0 | 9 |
| cursor | 4 | 1 | 3 | 5 |
| kimi | 4 | 0 | 2 | 4 |
| **qwen** | **2** | **0** | **5** | **2** |

**`qwen` 唯一最小，无并列。**④ 采纳 `O-L1` 后已重算（luna 8→9），结果不变。
**名次与验收资格无关**——判据是既得利益不是质量。qwen 在评优中五家一致排末位，
但其 ① 的 12 处锚点经裁决方逐条复核**全部成立**，具备取证核对能力。

## 二、先确认你是谁

```bash
cd ~/worktrees/qwen/k8s
r=$(git rev-parse --show-toplevel 2>/dev/null) && basename "$(dirname "$r")" || echo "❌ 不在 git 仓内"
```

输出必须是 `qwen`。不是就停下报告，不要推理。

## 三、取件

```bash
git show opus:sunmoonai/docs/dev-plan/runtime-architecture.md               # 待验收的裁决稿
git show opus:sunmoonai/docs/dev-plan/rounds/runtime/runtime-disposition.md # 处置记录（含 ④ 异议处置 §K）
git show runtime/h1:sunmoonai/docs/dev-plan/rounds/runtime/task.md          # **冻结的验收标准在 §8**
git show opus:sunmoonai/docs/dev-plan/rounds/runtime/rulings.md             # 本轮裁定 R1–R6
git diff master opus -- sunmoonai/docs/dev-plan/runtime-architecture.md
```

## 四、对象事实

| 对象 | 出处 | 行数 | sha256[:16] |
| --- | --- | --- | --- |
| 裁决稿 `runtime-architecture.md` | `opus` @ `ac0615d8` | 755 | `3a6d6919ba05117c` |
| 处置记录 `runtime-disposition.md` | 同上 | 359 | `d6e3bfc9c2ca3b1d` |
| 验收标准 `task.md` §8 | **`runtime/h1`（冻结点）** | 427 | `c31aa01cff556abd` |

⚠ 裁决稿与处置记录在 ④ 之后**又改过**（采纳 `O-L1` / `O-Q1`：裁决稿 739→755 行，
处置记录 332→359 行）。按 `E-9` 纪律随本通知重发并更新本表。**以本表为准。**

## 五、范围与门槛

**按 `task.md` §8 的十条逐条判定**，每条给 `满足` / `部分满足` / `不满足` + 依据（`file:line` 或可复跑命令）。
其中 1、2、3、5、6、7、9、10 条机械可判，4、8 条由脚本输出佐证。

三条硬纪律（协议「⑤ 验收 与 ⑥ 确认」）：

1. **只能按冻结的标准判定，不得为通过而静默修改标准。**
2. 标准不通过时，**先判断是产出没达标、还是标准本身过期**——标准也会腐坏。
   判成后者要**写明理由交裁决方处置，不得自行改标准**。
3. `R6` 已裁定 **§8-4 的「必含」从属于 §8-7**：候选给出等价或更强的结构化字段表 +
   内核修订工作单元即算满足，`render` 的具体归属不在冻结范围。按此口径判 §8-4。

**提示可用的机械命令**（不是穷举，你可自拟）：

```bash
A="opus:sunmoonai/docs/dev-plan/runtime-architecture.md"
git show "$A" | grep -cE '开发 Profile|产品 Profile|Profile A|Profile B|两个 Profile'   # §8-1 须 0
git show "$A" | grep -cE 'kind[[:space:]]*=[[:space:]]*"human"'                          # §8-2 须 0
git diff --name-only 7e8464c2 opus -- sunmoonai/docs/dev-plan/refact-fable.md \
    sunmoonai/docs/dev-plan/working/request-lifecycle.md                                  # §8-9 须空
git show "$A" | head -1                                                                  # §8-10 身份行
```

**不受理**：改动冻结标准；就 `R6` / `F-1` 已由所有者裁定的部分重新表态；
对他家候选的评价（① ② 已结束）。

## 六、交付

```
sunmoonai/docs/dev-plan/rounds/runtime/runtime-acceptance-qwen.md
```

**不得自创文件名**。首行为身份自证行。写完在 `qwen` 分支 commit；**判定只看提交**。

结论请给三值之一并写在文件靠前位置：**通过** / **有条件通过（列条件）** / **不通过（列条号与理由）**。

## 七、裁决方的自陈（供你判断这份稿子可不可信）

处置记录 §E 登记了裁决方本轮**十一处**错误，**其中六处是参与方抓出来的**——
包括错锚 `:238` 并被一份候选继承、把「人 + 脚本」叫 orchestrator、两次在环节中途改动已发布产物、
用词汇相似度误判独立性、缺协议强制的机器可读处置表、以及概括 luna 主张时砍掉半句。

裁决稿 §6 记：**OP-1 / OP-2 / OP-3 三项全部被改写，无一原样保留。**

**你不必替裁决方留面子。**验收查的就是「这份稿子达标了吗」。
