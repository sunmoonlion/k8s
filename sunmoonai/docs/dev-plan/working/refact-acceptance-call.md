# Refact 轮 · 环节 ⑤ 验收：致 qwen

> 发出：2026-09-04 ｜ 裁决与整合方：opus ｜ 本文自足，不需要额外指令
>
> ④ 异议已收口：三家参与（kimi 经裁定 R1 免除），**六条异议全部采纳，无一驳回**。
> 裁决稿至此**冻结**，除非本环节判定不通过而回到 ③。

---

## 1. 你为什么是验收方

裁定 **R2**（`refact-rulings.md`）：原指定 kimi 经 R1 免除参与，属「不可用」；
顺位在 ④ 通知中已预先声明，下一位是你。

判据是**既得利益最小**，不是质量：排除裁决方 opus、基座作者 luna 后，
按处置表采纳条数由少到多 `kimi(4) → qwen(5) → cursor(12)`。

**R2 已登记一条代价，请你正面接住**：你是本轮两处取证被纠正的家
（`profiles.py` 跨仓错位、`constraints.md` I12 编号出处）。
**这两类错恰恰是本轮暴露过的弱项，所以它们被列为本次验收的重点复核项（见 §4.4）。**

## 2. 取件与对象事实

```bash
git show refact-integration:sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md
git show refact-integration:sunmoonai/docs/dev-plan/working/refact-disposition.md
git show refact-integration:sunmoonai/docs/dev-plan/working/refact-rulings.md
git log  --oneline master..refact-integration
git diff f8bc48e3 refact-integration -- sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md
```

| 对象 | 事实 |
| --- | --- |
| **冻结点** | `refact-integration` `c501c723` |
| 裁决稿 | 1603 行，sha256 `a602b3443e59fb2e633b08de1d447455a81df63ae7e574d12f955e28def7009c` |
| 处置记录 | sha256 `f253009ccbd3e049fe8608fd98e9ddcf11cbb4bec0f1c60e9c4dcbeb69e2cf83` |
| 裁定记录 | sha256 `0551f2c019f6e7be56b8fc33dced91761d75df048bbbe37d88ce87a24997a742` |
| 基座 | luna `f8bc48e3` |
| 异议 | luna `2e1e4a53`(172 行) / cursor `6db57869`(65 行，无异议) / qwen `10267649`(87 行) |

**按 commit 取件，不看工作区。**你在验收稿里引用任何行号，请同时给冻结点。

## 3. 判据是冻结的

逐条判 [`refact-task.md`](../refact-task.md) §12 的 **11 条验收标准**，
每条给「通过 / 不通过」+ 证据（`file:line` 或可复跑命令）。两条硬规矩：

1. **只能按冻结的标准判定，不得为了让它通过而静默修改标准；**
2. 某条不通过时，先判断是**产出没达标**还是**标准本身过期**——标准也会腐坏。
   判成后者要写明理由**交裁决方处置**，不要自行改标准。

## 4. 五项独立复核

裁决方已自查，但**自查不算验收**。以下五项请独立复算。

### 4.1 冻结区逐字节

§5、§7、§12、§13、§14、附录 A、附录 B 与 master 逐字节一致。
裁决方的复算方式是按标题切段后比 sha256；你可以用自己的方法，**结论要能复现**。

### 4.2 处置记录与实际 diff 对账

`git log --oneline master..refact-integration` 共 25 个提交，一条主张一个提交。
逐条对照处置记录 §8 与 §10 的清单：

- **处置记录里写了「接受」、diff 里却没有** → 不通过；
- **diff 里有、处置记录没登记** → 不通过；
- 「部分接受」是否写清了接受到哪、为什么止于此。

### 4.3 有没有把「未验证」写成「已支持」

重点看 §8.1 矩阵的三档判定与 §11.3 未验证集中清单。
注意本轮刚加的三档对应表：`available→已支持`、`implicit_fallback→需补法`、
`explicit_unsupported→当前缺失`——**读表一律按三档判定**。
`F-EXEC-02` dsh 腿在 ④ 中经 O-L1 二次改判为 `implicit_fallback`，请确认它与对应表自洽。

### 4.4 锚点出处正确性（本次重点）

本轮出现过两类出处错误，**验收要专门扫这两类**：

| 类 | 本轮实例 | 怎么查 |
| --- | --- | --- |
| **跨仓错位** | 拿本仓自己的代码当租用 SDK 的能力证据（`profiles.py` 事件） | 抽查裁决稿中标注为 Codex/Harness/OpenClaw 能力的锚点，确认路径确在对应外部仓 |
| **编号出处** | `constraints.md` 是 `I1`–`I8`，`request-lifecycle.md` 是 `I1`–`I15`，区间重叠 | 抽查裸 `I*` 引用是否都写明了出处文档 |

抽查数量与选取方式由你定，但**要写明抽了哪些、怎么选的**。

### 4.5 ④ 六条异议是否真的落到稿上

| 异议 | 应落在 | 提交 |
| --- | --- | --- |
| O-L1 `F-EXEC-02` 改判 `implicit_fallback` | §8.1 | `f4ca8fd1` |
| O-L2 §0.3 关闭模型直接选路 | §0.3 | `7db445a8` |
| O-L3 Gate 0 第 3 条退路改按 constraints 拆 Worker | §4.5 | `2ee77993` |
| O-L4 超时改称审计结果/reason code，不新增状态 | §9.2 | `44863162` |
| O-L5 §4 标题改为「sandbox、Git 物化与执行器接入架构」 | §4 标题 | `2ee77993` |
| qwen-1 D-Q6 改挂 D-K8 | 处置记录 §5.3 | `cf57cb68` |

## 5. 交付

```text
sunmoonai/docs/dev-plan/working/refact-acceptance-qwen.md
```

四栏：

1. **11 条标准逐条判定** + 证据；
2. **§4 五项独立复核**的结果与方法；
3. **异议**（如有）：哪一条、为什么、你的判定是什么——验收方发现裁决错了，
   写在这里交裁决方处置，**不要直接改裁决稿**；
4. **盲区自陈**（`round-protocol.md`：验收同样是产出，同样要自陈盲区）。

提交到你自己的分支，回报 SHA-256 与 commit 号。

## 6. 截止判据与逾期后果

**截止是判据，不是时钟时间。**单一验收方不适用同侪基准，故用**停滞判据**：

```text
观察窗 W = 43 分钟
  —— 取自本轮 ④ 的实测数据：三家从通知提交（b20607f1，15:55）
     到交付（16:39）用时均为 43 分钟，中位数 43。
W 内 refact-acceptance-qwen.md 字节数无变化、且 qwen 分支无新提交 → 判为不可用。
```

**停滞判据优先：产物还在长就不算逾期。**裁决方在宣布不可用前会跑一次判据，
并把观测值（字节数、时间戳、分支 HEAD）写进裁定记录——「等太久了」不构成理由。

| 情况 | 后果 |
| --- | --- |
| 逾期 | 验收方视为**不可用**，按顺位换 **cursor**（`kimi(4) → qwen(5) → **cursor(12)**`）。**⑤ 不设默认通过**——最后的检查不允许超时放行 |
| 判定不通过 | 回到 ③ 重整合；理由与证据交裁决方处置 |
| 判定通过 | 进 ⑥，由项目所有者确认。**⑥ 不设逾期默认，人不确认就不发布** |

W 可延长（裁决方记录即可），**不可缩短**——缩短等于更容易把你判为不可用，方向危险。
