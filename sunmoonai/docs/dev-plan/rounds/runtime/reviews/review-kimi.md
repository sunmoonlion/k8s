参与方：kimi｜worktree：/home/zym/worktrees/kimi/k8s｜HEAD：91942c1b3bc170582a9aea4b54edb677397986a3

# 轮次 runtime ② 评审（kimi）

> 按 `round-protocol.md`「② 互评」四块（自述 / 候选集冻结 / 评优 / 值得吸收的点）。
> 逐份评五份候选，含自己那份。利益冲突声明：评优方同时是候选作者，这不是独立终审；
> 我把自己排在第四，依据与评别家同标准（见 C 块排序）。事实题用证据裁：本评审全部关键指摘附
> `分支:路径:行` 或可复跑命令，行号以 B 块冻结的 commit 为准。

## A. 自述（关于 kimi 候选）

- **改了什么**：无基座，新建 `runtime-architecture.md`（538 行）。结构：P1（DEV Task Profile +
  五 Agent Profile + 两种 orchestrator 实现 + 三条脚手架拆除条件 + 等效判据四条比对规则）/
  P2（Interaction 出向三必填 + 入向三值 + 内核修订工作单元）/ P3（粒度三档 + 证据推论 + 三道边界 +
  R2 三层处理）/ 必答 Q / OP 表态（改写、改写含一处反对、采纳但改写过强预设）/ 登记表 / 权力表与人的介入对照。
- **与基线材料的分歧**：把 `refact-fable.md:238` 的 `RUNNING` 归因改正为执行者属性（task.md §7 第 3 条要求的动作）；
  指出 task.md §3.1「今天的 orchestrator 是人 + shell 脚本」与 `refact-fable.md` §3.9 硬约束的同名物冲突。
- **未验证、已标 ⚠**：`agent/sdk-*` 行是形态声明非能力证据；trace 样例是 git 重建投影；
  cursor/fable 差异程度无数据。
- **放弃了什么**：未写实施排期与文件树（§4 不受理）；未展开财务 Profile 字段。
- **自评缺陷（互评口径，不护短）**，三条，均可复核：
  1. 我的 `editable_scope` 写成 `{scope: none | regions[...] | full_replace}`（kimi 候选 :253）——
     `regions` 没有给出机械可判的表示法，比我批评 OP-2 的标准还松。luna 的 JSON Pointer /
     path glob 方案（luna 候选 3.1 节 `editable_scope[]`）严格更好。
  2. 我的 trace 样例（kimi 候选 §1.6）没有逐条来源等级；fable 的 23 行样例带来源等级与
     attested 计数（fable 候选 §2.8），luna 的带 GAP 标注（luna 候选 §2.2），我的处于两者之间偏薄。
  3. 我把渲染形式放进了内核绑定字段（kimi 候选 §2.2 `presentation`）；cursor 主张渲染属
     Delivery / `client_context`（cursor 候选 §2.2「渲染形式不在此」），这条攻击对我成立，
     我在 C 块 cursor 条下记为有效。

## B. 候选集冻结

核对命令（已实跑，五行全部与通知一致）：

```bash
for w in luna kimi cursor fable qwen; do
  git show "${w}:sunmoonai/docs/dev-plan/runtime-architecture.md" | sha256sum | cut -c1-16
done
```

| 候选 | worktree | 分支 / commit | 行数 | 字节数 | sha256[:16] |
| --- | --- | --- | --- | --- | --- |
| luna | `~/worktrees/luna/k8s` | `luna` / `1ddff5c2` | 544 | 32955 | `03785aabb3a631f6` |
| kimi | `~/worktrees/kimi/k8s` | `kimi` / `29b4f804` | 538 | 39376 | `f0226bffd7517085` |
| cursor | `~/worktrees/cursor/k8s` | `cursor` / `13f3d52b` | 586 | 38613 | `5ba7ce8b14775aeb` |
| fable | `~/worktrees/fable/k8s` | `fable` / `f053bd84` | 646 | 59897 | `b9bd7800cdcbcb05` |
| qwen | `~/worktrees/qwen/k8s` | `qwen` / `1ae5b420` | 441 | 21202 | `49380ab0427d8ad8` |

五份，无缺口。机械项实跑结果：五份禁词（那对部署形态词组）全部零命中、`kind = "human"` 全部零命中、
首行身份行全部存在且与目录名一致——§8-1 / §8-2（前半）/ §8-10 五家全过，下表不再重复。

## C. 评优

### C.0 §8 十条逐份扫描（只记问题与边界情形，全过的条不重复列）

| 候选 | 有问题的条 | 说明（出处可复核） |
| --- | --- | --- |
| luna | 无 disqualifying；§8-3 边界 | trace 是「带 GAP 的追溯投影」并如实声明（luna 候选 §2.2），符合但非完整通过证明 |
| kimi | §8-3 偏弱 | 样例行数最少、无来源等级列（A 块自评 2） |
| cursor | §8-3 边界 | 样例标 ⚠ 重建、并主张 R 层暂不可机械判——诚实，但「OP-1 当本轮核心验收循环」的批评对 §8-3 的实际要求（样例 + 状态 ⊆ 内核）略过强，§8-3 并没有要求现在就能比 R 层 |
| fable | 无 disqualifying | §8-2 逐条清单 11 行，含「没有边」的第 1 行并论证其非缺项，成立 |
| qwen | **§8-3 不满足**；§8-5 自相矛盾 | 见 C.5 两条指摘 |

### C.1 fable（646 行）——排第 1

**强项**：
- trace 样例是五份中唯一**量化**的：23 行逐条带来源等级，`attested` 仅 2 条，并给出
  「等效只能在两条轨迹的最低来源等级上宣称」的比对规则（§2.7–2.8）。实证基础可复跑：
  `git log --format='%h %ad' --date=iso 7e8464c2 -1 -- <两个路径>` 确为单一 commit
  `7e8464c2 2026-09-05 13:05:50`——「整轮产物落在一个 commit 里」属实。
- 粒度拆三字段（observability / enforcement / sandbox）+ 四档，且 `tool.reported` 一档有真实代码锚：
  `~/repo/codex/codex-rs/exec/src/cli.rs:60` 确为 `--json`（"Print events to stdout as JSONL"，已复跑 sed 验证）。
  「可见 ≠ 可拦 ≠ 沙箱归谁」是五份中对 P3 最精确的分解。
- 权力表加 H8（谁有权回答 INPUT 类 Interaction、能否带内容改动）——直指上一轮 R3–R8 六次所有者裁决
  在账本上没有落点的真实缺口（§3.1）；H0 把 manual dispatch 变成可数对象，直接服务 Q3/Q4。
- §8-2 的 11 行实际介入清单是五份中唯一拿两轮真实事件逐条对边对行的，且顺手登记了一个真观察值：
  本轮 H1+H2 合并实发 1 次触点，与 `refact-fable.md` §8 第 5 条「T2 = 2」不符（§2.4 表第 3 行）。
- 同名物发现成立：分组键 `runtime` 与「产品运行时」、内核「Agent runtime」一词三义，建议改 `harness`——
  `refact-fable.md:253` 该字段注释本来就写「执行 harness」，证据自洽。
- 利益申报（§1）与「盲区」节（§8）按规矩自陈既得利益，是五份中唯一明确请裁决方折算的。

**指摘（可复核）**：
- **H0 行违反权力表自身的不变量**。`task.md` §7 第 2 条（上一轮 §8 第 2 条幸存且变强）要求
  「每行 `enforcement_point` 非空，且强制点在凭据层或回执仓」；fable 候选 :180 的 H0 行
  `enforcement_point = 无`。作者自知（「它不是权力，是欠账」）——但欠账的正确落点是
  round-protocol「待自动化」表，不是权力表；把非权力行写进权力表，表内「没有强制点的行不许进表」
  （`refact-fable.md` §3.3）即被破坏。可数目标用 H0 事件计数即可达成，不必占一行。
- 登记表给 qwen 填 `provider = "alibaba"` 标为推断（§2.3 ⚠）——诚实，但 `task.md` §6.2.1 该栏为「—」，
  推断不宜进登记表，应留空标 ⚠。
- 646 行，为五份最长；§2.6 拆除条件与 §7 对齐表有少量内容与前文重复（观察值，非判据）。

**OP 处理**：三项均改写且有实证理由（provenance、options[] 与 evidence_grade、开销是 (任务, orchestrator) 的函数）；
「开销是二元函数」一点是五份中唯一把 fable 自身处境（manual dispatch）变成反例 3 的，成立且刺痛。
**Q2 反例**：三个，其中「对 `dispatch = manual` 执行者的任何分发」是本轮正在发生的实例，最强。

### C.2 luna（544 行）——排第 2

**强项**：
- 证据等级 E0–E4 + `min(可见上限, 隔离强度, 验收独立性, 覆盖)` 的采信算法（§4.3），把 P3 的
  「粒度决定证据权威」做成了可计算的规则，并正确处理 R2：`author=owner` 降为 E0、
  回执通道登记 `UNVERIFIED`、 waiver 必须落 Event（§4.5）。
- 对 OP-1 的改写（TraceEnvelope：契约/策略/身份/副作用摘要）有一个五份中最好的反例论证：
  「两次运行四序列全同，但一次用未获权凭据发布」——同形轨迹不同授权，四要素单独不充分，成立。
- Artifact 版本表的哈希抽查属实（已复跑：`review-refact-fable-cursor.md` = `77df40f4c8aa1622`，
  `rulings.md` = `ab115a5b2b3a847d`）。
- Interaction v2 的迁移方案（additive + version gate、双读期分指标、v1 活动归零后下线）是五份中最工程化的；
  `editable_scope` 用 JSON Pointer / cell ID（§3.1），机械可判性最好。

**指摘（可复核）**：
- **对 OP-2 的反对部分是稻草人**。luna 候选 :509 写「反对把任意 amend blob 直接塞进 Interaction 行」，
  但 task.md §3.2 的 OP-2 原文就是「该载荷成为一个新 Artifact 版本」——OP-2 并没有主张 blob 入行。
  luna 的细化（引用 + digest + renderer registry）仍有价值，但「反对」的框定夸大了分歧；
  三项 OP 全部表态「改写」，其中这一条的理由强度低于另两条。
- §1.4 拆除条件 5「无命令入口者要么经 `human_bridge`…要么从可路由集合移除」——「移除」与 task.md
  §6.4 要求处理的「存在但不可自动分发」这一类相悖；fable 的 H0/可数欠账方案更对。
- Task 状态样例 seq 2→3 由 `VALIDATING` 直接到 `QUEUED`（§2.2），而同一轮 `rulings.md` R1 记的是
  先冻结后归档——细分次序属推断，已标 GAP，但「推导」与「观测」的混排在表里只靠注脚区分。

**OP 处理**：三改写，OP-1 最强，OP-2 有稻草人瑕疵（见上）。**Q2 反例**：两个，成立；
「formatter 已覆盖的空白修复不应调 agent」一条有独到性（路由应能选非 agent 执行器）。

### C.3 cursor（586 行）——排第 3

**强项**：
- S 层 / R 层 + 投影 Π 是五份中最干净的形式化：「谁在哪条边上有权」是静态约束（S 层），
  不该塞进一次 run 的轨迹；边必须进状态序列字段（防 D1 类漏检）；Π 丢执行者私有事件，
  使「允许粒度不同」与「Interaction 形状不许不同」不再打架（§1.5）。这比我的「比对粒度取较粗一腿」
  更精确。
- 对 OP-2 的一处攻击对我（也对 luna/fable）成立：**渲染形式属 Delivery / `client_context`，不进内核绑定**，
  否则每次 UI 改动都变规范修订（§2.2）。我认领这条（A 块自评 3）。
- 「轨迹不是内核对象」「绕过不是内核对象」两条防膨胀警告（§7）方向正确；
  Q4 按「外部采样面 + 覆盖声明」作答（§5.4 四采样面表），并如实把自己（`agent -p` 手工调用）列入采样面。
- 同名物发现：内核 `:26-27` 仍指向过时落点名——属实，且给出修订单元归并方案（§2.5）。

**指摘（可复核）**：
- **分类规则把 `tier ∈ {T1,T2}` 作为「走运行时更便宜」的判据（cursor 候选 :464）有近循环之嫌**：
  档位由不可逆性/权威层等风险判据定（round-protocol「流程档位」），不由成本定；用档位反推成本，
  规则退化为「重活走运行时」——它回答的是「什么任务重要」，不是「什么任务走运行时净成本低」。
  机械可判性是真的，判的是代理变量。
- `replace` 第四值与 fable 的「血缘表达替代」方案（fable 候选 §3.3 第 2 条）冲突，两者只能留一个；
  cursor 给的理据（所有者原话第三项是整份替代）成立，但 fable 的方案不增枚举值、血缘信息更多，
  cursor 未回应这一替代（各家隔离写作，情有可原，裁决时需裁）。
- 首行 HEAD 用短 sha `4513bcbd`，其余四家用全 40 位——机械判若按全等比对可能误判（轻微）。

**OP 处理**：改写、改写、部分反对，质量均高；OP-2 的 render 归属点是本轮最好的单点论证之一。
**Q2 反例**：T0 包内笔误仍被强制走全手续，成立，且正确引用上一轮 §8 第 5 条「只管住审批一项」。

### C.4 kimi（自家，538 行）——排第 4

按同一标准评：形式要件全过；OP 表态有实质内容（OP-2 的 editable_scope 入向约束、OP-3 的 Q4 预设批评）；
权力表与人的介入对照完整；R2 处理与 luna/fable 同向但更早写进比对规则。
不足即 A 块自评三条：`editable_scope` 表示法不如 luna 严格、trace 无来源等级列、render 位置被 cursor 有效攻击。
另补一条互评视角的：我的拆除条件第 1 条「连续 3 轮零不允许差异」依赖我的比对规则先被采纳，
自指程度高；fable 把它降为「服务态来源等级不低于手工态」，更可判。

### C.5 qwen（441 行）——排第 5

**强项**：结构完整、十条自检表清楚；OP-2 的 `interaction_class` 限定（重型载荷只加给
`APPROVAL_WITH_ARTIFACT` 类，轻量 INPUT 不背 Artifact 版本）是五份中唯一正面处理内核
`:180-181`「只有歧义实质改变结果/权限/成本/风险时才澄清」纪律的，方向正确，值得吸收；
Q3 的复合开销向量（任一维超标即不标 T0）比单数上界更难被 gaming。

**指摘（可复核，两条都是事实错误级）**：
1. **§8-3 的样例不是从真实产物导出，是凭印象生成**。qwen 候选 :131「以 refact-fable 轮为源」，
   但 :154 起列出 `candidate-luna@v1 author=luna` 等五份候选 Artifact——`refact-fable` 轮没有五家候选，
   它是 fable 起草 + 各家评审的一轮。可复跑：
   `git ls-tree -r 7e8464c2 --name-only -- sunmoonai/docs/dev-plan/rounds/refact-fable/`
   输出只有 9 份 review + 1 份 rulings（已实跑，10 行），没有任何 candidate 文件。
   样例同时虚构了 H1/H2/H5 三次独立 `WAITING(APPROVAL)`——而真实账本是 H1 与 H5 合于同一 commit
   （fable 候选 §2.8 第 23 行正确指出了这一点）。§8-3 要求「用真实产物导出」，此条不满足。
2. **登记表自相矛盾**：qwen 候选 :87 把 fable 的 `observability_granularity` 填为 `process`，
   而自家 :280-284（§3.5）正确写明 fable「看不到 argv、看不到 stdin/stdout、只能看到文件系统前后差异」——
   那按 §3.1 自己的定义就不是 `process`。§8-5 要求五家逐条填上该字段（机械判无空缺），
   填了但与正文定义冲突，等于填错。

另：对 R2（方案须处理的极端案例）仅在拆除条件第 5 条一笔带过，无机制；OP-1「采纳，但须补充」
的补充（静态结构检查）与 OP-1 本身无关，属附和（§5 纪律：附和不计分）；
Q4 的「人报告通道」依赖自报，与自家 §3.2「自报不采信」的原则相碰。
**Q2 反例**：README 笔误，成立，是合格的反例。

### C.6 排序与依据

**fable > luna > cursor > kimi > qwen。**

依据（与评别家同强度，含对己）：本轮验收的重心是「可机械复核」——等效判据、证据权威、反例。
fable 的 trace 是唯一直接量化了「手工模式可复原性」的（attested 2/23），且每条关键断言有实跑锚；
luna 的证据等级算法与迁移工程性紧随其后；cursor 的形式化最优雅但两处核心主张（tier 成本代理、
replace 四值）各有未闭合的对立方案；我自己的候选形式要件齐、OP 表态有内容，但三处被别家严格超越
（自评三条）；qwen 有两处事实错误级指摘，且 OP-1 附和。把自己排第四：前三份各有一处明确优于我的
可点名产物（fable 的 provenance、luna 的 E 级算法与 JSON Pointer、cursor 的 Π 与 render 归属），
我没有任何一处可点名的反向超越。

**利益声明**：我是 kimi 候选作者；fable 是被推翻稿的作者（其候选 §1 已自报既得利益，排序时我已知悉）。
上一轮我在 refact 轮的评审引用过 fable 稿为基座——不存在需要回避的反向利益。

### C.7 cursor 与 fable 的相似性观察（通知 §五 要求的观察值）

**结论：不雷同，实质差异显著。**逐点对：

- 共同点是任务书强制项（RUNNING 归因改正、三道边界、粒度字段、反例必须给）——五家全中，不构成相关性证据。
- 差异点（各自独有、对方完全没有）：fable 有 provenance 三值 / H0 / H8 / options[] /
  `runtime→harness` 改名 / 23 行量化 trace；cursor 有 S/R 分层 / Π 投影 / `replace` 第四值 /
  render 归 Delivery / 内核 `:26-27` 残留 / 四采样面绕过表。两套论证骨架互不包含。
- 对同一问题的答案相反：fable 用血缘表达「替代」（三值够用），cursor 专设 `replace`（四值）；
  fable 把 render 留在内核绑定并加 `evidence_grade`，cursor 把 render 踢出内核。
  同厂两个产品若在共享同一套 harness 内核，在被迫表态的开放题上不应出现系统性反向。

按 `task.md` §6.2.1 的字面分组键（两个 runtime），本观察**支持**维持两组；但这是单轮单题的
观察值，「共用多少 harness 内核未知」的 ⚠ 不因此消除。

## D. 值得吸收的点

不管谁当基座，以下各条值得并进最终稿（出处精确到节）：

1. **fable §2.7–2.8：trace 条目加 `provenance`（attested/reported/inferred）+ 「等效只能在最低来源等级宣称」
   + attested 计数进拆除条件。**这是把 R2 从风险登记变成可判字段的最短路径，且已被真实数据验证（2/23）。
2. **fable §2.4 H8 行（INPUT 类 Interaction 的应答权与 amend 权限进权力表）**——补上上一轮 R3–R8 六次裁决
   无账本落点的洞；但 **H0 不占权力表行**（违反 enforcement_point 非空），改作 orchestrator 欠账 + 事件计数。
3. **fable §6.4：分组键字段 `runtime` 改名 `harness`**，一词三义就地拆除，零成本。
4. **fable §5.2 反例 3：`dispatch = manual` 执行者对运行时是净负担**——必答 Q 的最佳实例，应进最终稿的反例节。
5. **luna §4.3：E0–E4 证据等级 + min() 采信算法**——把「粒度决定权威」从规则变成计算；
   与 fable 的 provenance 是同一思想的两面，最终稿应统一（建议：等级用 luna 的 E 标，轨迹字段用 fable 的三值，
   映射写明 E0=reported、E1–E4=attested 的子档）。
6. **luna §2.1：TraceEnvelope（契约/策略/身份/副作用摘要作为比较上下文）**——补四要素的授权盲区，
   其「同形但越权」反例应原文进最终稿。
7. **luna §3.1：`editable_scope` 用 JSON Pointer / path glob 的机械表示**——优于我候选与 OP-2 的自然语言写法。
8. **luna §3.3：Interaction v2 的 additive + version gate 迁移细案**（双读分指标、v1 归零下线）——
   五份中最完整，直接可用。
9. **cursor §1.5：S 层 / R 层分离 + 投影 Π**——最终稿的等效判据应采用此结构；权力表归 S 层不进轨迹，
   边进状态序列字段。与我候选的「粒度取较粗一腿」规则兼容且更严格。
10. **cursor §2.2：渲染形式归 Delivery / `client_context`，不进内核绑定**——我认领此批评；
    最终稿内核侧只留 `subject_artifact_ref` 与 `amend_schema`。
11. **cursor §7：「轨迹 / 绕过 不是内核对象」防膨胀警告**——等效判据与绕过观测都必须声明自己是投影/观察事件。
12. **qwen §5.2：`interaction_class` 把重型载荷限定在 APPROVAL_WITH_ARTIFACT 类**——守住内核 `:180` 的
    澄清纪律，与 luna 的 v2 字段表兼容（轻量类 = v1 形状）。
13. **qwen §4.3：T0 开销用复合向量（任一维超标即不标 T0）**——优于单数上界，与我候选的表兼容，直接替换。

**留给裁决方/所有者裁的两处对立**（各家方案互斥，评审不替裁）：
- 「以自己的方案替代」：cursor 的 `replace` 第四值 vs fable 的 amend + `base_version` 血缘。
- render 位置：cursor（Delivery）vs fable/luna/我（内核绑定，fable 另加 `evidence_grade`）。
  我已被 cursor 说服，但 `evidence_grade`（人批之前先看证据等级）独立于 render 位置，两边都该留。
