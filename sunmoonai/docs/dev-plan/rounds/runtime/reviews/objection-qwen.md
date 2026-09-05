参与方：qwen｜worktree：/home/zym/worktrees/qwen/k8s｜HEAD：d94df73519e6135461641d334ce6e6ff1428ed1b

# ④ 异议：轮次 runtime（qwen）

> 本文按 `runtime-call-④.md` 交付。读的是 332 行钉版处置记录（含 §H 机器可读处置表、
> §I 验收方计算、E-7 / E-8 / E-9，未读 250 行旧版）。结论：针对本候选的三条事实认定
> 经本人复跑全部成立，不提异议；G-16 / G-17 两条吸收经核对忠实落稿，不提异议；
> 仅登记一处证据描述错漏（O-1），不改变任何判定。

## 一、取件与对象事实核对

| 对象 | 钉版行数 | sha256[:16]（通知钉版） | 本人复跑 |
| --- | --- | --- | --- |
| `runtime-disposition.md` @ `opus` / `023bd75d` | 332 | `9f140f121349782a` | 一致 |
| `runtime-architecture.md` @ 同上 | 739 | `37a4a68c9cc590e6` | 一致 |
| `rulings.md` @ 同上 | 34 | `8c90937769c44da6` | 一致 |

复跑命令：`git show opus:<路径> | sha256sum | cut -c1-16`。

## 二、对 §C.5 三条事实认定：复跑成立，不提异议

④ 规则：已由三家以上独立复核且裁决方复跑确认的事实认定，非有新可复跑证据不受理。本人逐条复跑，与处置记录一致，无新证据：

1. **§8-3 不满足（§1.5.1 轨迹样例）**。复跑
   `git ls-tree -r --name-only 7e8464c2 -- sunmoonai/docs/dev-plan/rounds/refact-fable/`：
   仅 9 份评审 + `rulings.md`，候选 0、验收产物 0。我样例里的 `candidate-luna@v1` 等五份候选
   与 H2 开工确认在账本上不存在，且未作 ⚠ 声明。「不采用」成立。
2. **§8-5 不满足（登记表 fable = `process`）**。复跑
   `git show qwen:sunmoonai/docs/dev-plan/runtime-architecture.md | sed -n '87p;278,287p'`：
   `:87` 给 fable 填 `process`，而 §3.5 写 fable 看不到 argv / stdin / stdout——
   按我自己 §3.1 的定义即非 `process`，同文自相矛盾。「不采用」成立。
3. **违反冻结任务书（fable 任 acceptor）**。`task.md` §9 冻结「fable 不得担任验收」，
   我的登记表 `:87` 仍给 fable 填 `roles_allowed = proposer, acceptor`。「不采用」成立。

三条判定本人均接受。另一并确认：§C.5 对我 12 处锚点的复核通过与上述三条不满足**同时成立**——
取证能力与样例虚构是两回事，处置记录如实分开记，本人对这一点无异议。

## 三、对 G-16 / G-17 吸收的核对：忠实落稿，不提异议

1. **G-16（`interaction_class`）**：裁决稿 §3.2（`:378-393`，按钉版行号）三类分层表
   ——`APPROVAL_WITH_ARTIFACT` 全字段 + 三值 decision、`INPUT_LIGHT` 轻载荷、
   `DEPENDENCY` / `RESOURCE` / `EXTERNAL` 现行不变——与我 §5.2 的改写建议一致，
   内核 `:180-181` 澄清纪律的锚未丢。
2. **G-17（T0 复合向量）**：裁决稿 §5.3（`:606-616`）采纳复合向量并**增强**了它：
   第三维从我的 `commit_to_dispatch_steps` 改名 `request_to_dispatch_steps`（更准），
   新增第四维 `dispatch_events = 0`（T0 不得用 `dispatch = manual` 执行者），
   并加了「human_required_actions ≤ 手工同任务」的相对上界。增强合理，无异议。

## 四、O-1：§C.5 一处证据描述错漏（唯一异议，不改变判定）

**处置条目**：§C.5 §8-3 行——「`rulings.md` 中『H2』『⑤验收』『acceptance』命中各 **0 次**」。

**为什么错**：三个词并非各命中 0 次。「⑤验收」「acceptance」确为 0，但「H2」命中 **1 次**，
在 `rounds/refact-fable/rulings.md:13` 的 R5 行：「H2/H3/H4/H6 回执是否全部改回执仓签名
（cursor C1）」——这是**权力表行号列举**，不是开工确认事件。

**应当是什么**：该句应作「『⑤验收』『acceptance』命中 0 次；『H2』命中 1 次，但为权力表
行号引用，非开工确认 Interaction」。判定本身（§8-3 不满足）不受影响：候选文件 0 个、
验收产物 0 个两条主证据不变，我样例声称的「H2 开工确认」确实不存在。

**可复跑证据**：

```bash
git cat-file -p "7e8464c2:sunmoonai/docs/dev-plan/rounds/refact-fable/rulings.md" | grep -n 'H2'
# → 13:| `R5` | H2/H3/H4/H6 回执是否全部改回执仓签名（cursor C1） | …
git cat-file -p "7e8464c2:sunmoonai/docs/dev-plan/rounds/refact-fable/rulings.md" | grep -c 'acceptance'   # → 0
git cat-file -p "7e8464c2:sunmoonai/docs/dev-plan/rounds/refact-fable/rulings.md" | grep -c '⑤验收'       # → 0
```

**影响范围**：已核对裁决稿 `runtime-architecture.md`（钉版）未继承「命中 0 次」表述
（全文 grep「命中」无此句），错漏仅在处置记录 §C.5 的证据描述，不污染基座。
按处置记录 E-9 纪律（产物随环节通知发布后本环节内不得再改），本条作为勘误登记，
供 ⑤ 验收与下轮裁决方参考，不要求改动钉版。

## 五、结论

除 O-1 勘误登记外，已读 332 行钉版处置记录，对其余关于本候选的全部处置**无异议**。
D-1 / D-2 / D-3 三处对立裁决、基座选择及三条可复核差异、E-1…E-9 自陈错误登记，
均不提异议。他家处置非本人异议范围，不评。
