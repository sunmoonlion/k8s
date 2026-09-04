# Refact 轮 · 环节 ④ 异议 · qwen

> 作者：qwen（工作目录 `~/worktrees/qwen/k8s`，分支 `qwen`）｜日期：2026-09-04
> 依据：`refact-objection-call.md` §2（范围与门槛）、§3（交付）、§4.3（qwen 要看的处置）；取件规则见其 §1（按 commit，不看工作区）
> 取件（分支 + commit + sha256）：
> - 处置记录 `refact-integration`（HEAD `72604a72`）`refact-disposition.md` sha256 `1457d0004d2f3ea8267159eb47724dc3e1978fb2694968ef474dbeafa3a4900f`（D-Q6 在第 114 行，自 `f6937446` 起未改）
> - 裁决稿 `refact-integration` `development-lifecycle-agent.md` sha256 `ef20c8c6c5db5eb9a0722872b4d067766195951529658a29d5d915d618f881ea`（1593 行，未变）
> - 裁定记录 `refact-integration` `refact-rulings.md`（R1/R2/R3）
> - qwen 候选（环节① 冻结）`qwen` `0c6f0fc3` sha256 `ea2bb7abf2d96047b4a203c24a2c0467107919c21d92fbfa2938e155468675fd`；qwen 评审（环节② 冻结）`qwen` `d26166a5` sha256 `9fdce417413fd3d91e8b29ab57d7726ad8246bd56bfb66c8cb4ad71ef21070ad`——**本文件不动这两份**
>
> **范围自律（§2）**：只就 qwen 自己那条主张的处置表态；不评裁决稿整体好坏（那是 ⑤ 验收方的事）；不替别家喊冤。

## 0. 一句话结论

对 qwen 的全部处置——D-Q1/Q2/Q3/Q4/Q5/Q6、I12（D-C5）、基座未采 qwen 荐——**7 条无异议（其中 D-Q3、I12 两条纠正属实，qwen 自认此错），1 条据证异议：D-Q6 把 kimi §15.2 的主张错挂到了 qwen 名下。**

## 1. 异议（1 条，符合 §2 门槛）

### 异议 1 — D-Q6 出处误挂：「自由文本分类器的默认通用兜底」是 kimi §15.2 的主张，不是 qwen 的

- **处置条目**：处置记录 §5.3 第 114 行「D-Q6 ｜ qwen ｜ 自由文本分类器的默认通用兜底 ｜ **拒绝**：与 §9.1「上层必须确定性代码」冲突（luna 评审 D-2 同判）」。
- **为什么错**（四证，均可复跑，见 §1.1）：
  1. **qwen 候选全文无此主张**——对 `自由文本/分类器/通用兜底/默认通用/free-text/classifier` grep 零命中；qwen 候选里的「兜底」只有两类，`implicit_fallback`（Adapter 三态探针的第三态）与审批的进程内兜底，**没有一处在讲上层路由用自由文本分类器**。
  2. **qwen 候选恰恰力主相反**——§15.0 第 1139 行「**Dispatcher 必须是确定性代码，不能是模型**」（并注明这是五家一致论断）；第 1385、1387 行「**两层路由都不是语义分类**……连 OpenClaw 的路由都是确定性 binding」。D-Q6 的拒绝理由「与『上层必须确定性代码』冲突」，而这条原则在 qwen 候选里正是 qwen 自己论证的——把一条与 qwen 立场相反的主张记成 qwen 的被拒主张，内部不自洽。
  3. **该主张逐字在 kimi §15.2**——kimi 候选第 1206–1208 行「**自由文本走受限分类器（闭集标签 + 置信度阈值 + 兜底通用档）**，分类器只做选择不做创作……未命中进通用档并落事件」。
  4. **处置记录引为「同判」的 luna 评审 D-2，明确把它归给 kimi、并判 qwen 通过**——luna 评审 D 块第 2 条「**kimi，§15.2** Router 的版本化配置与事件字段……只吸收确定性表驱动部分，**不吸收自由文本分类器的默认通用兜底**」；luna 评审第 99 行验收项 5：kimi「部分；§15.2 又允许自由文本『受限分类器 + 兜底通用档』」，qwen「**通过**；§0.3/§6.0/§15.0 明确定名 Dispatcher」；第 175 行把「收紧分类器通用兜底」列为 **kimi** 的改进项。
- **应当是什么**：D-Q6 不应挂在 qwen 名下。请裁决方把这条拒绝**改挂到其真实出处（kimi §15.2）**，或从 qwen 的处置里撤掉。归属、以及「是否拒绝 / 如何拒绝」由裁决方定；qwen 只要求——不要把一条 qwen 从未提出、且与 qwen 亲自论证的原则正好相反的主张，记成 qwen 的被拒主张。
- **为什么这不是「替别家喊冤」**：qwen 不评价 kimi 那条主张该不该拒、拒得对不对——那是裁决方与 kimi 的事，qwen 不置一词。qwen 只要求把**错挂在 qwen 名下**的这一条移除；移除后归到谁名下，由裁决方定。
- **为什么值得受理（不是「读起来更好」）**：本轮自己立了 D-C5「编号必须写明出处文档」的纪律（因 qwen 把 `request-lifecycle.md` 的 I12 错记成 `constraints.md` 的 I12）。D-Q6 是同一类错误的镜像——把 kimi 的主张错记成 qwen 的主张。出处错挂会污染处置记录这条整合审计链；且 R1 的剩余缓解写明「⑤ 验收会独立复核『处置记录与实际 diff 是否对得上』」，一条出处错挂的被拒主张会让验收对不上账（qwen 恰是 R2 点名的验收方，更须先把自家账目理清）。

### 1.1 可复跑证据

```bash
P=sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md
RL=sunmoonai/docs/dev-plan/working/refact-review-luna.md
RD=sunmoonai/docs/dev-plan/working/refact-disposition.md

# (1) qwen 候选无「自由文本分类器 / 通用兜底」——零命中
git show "qwen:$P" | grep -nE "自由文本|分类器|通用兜底|默认通用|free.?text|classifier"   # → 无输出

# (2) qwen 候选力主相反：上层确定性代码、路由非语义分类
git show "qwen:$P" | sed -n '1139p;1385p;1387p'

# (3) 该主张逐字在 kimi §15.2
git show "kimi:$P" | sed -n '1206,1208p'

# (4) luna 评审 D-2 把它归给 kimi，并判 qwen 验收项 5 通过
git show "luna:$RL" | sed -n '99p;175p;207,209p'

# (5) 处置记录当前仍误挂（HEAD 72604a72，第 114 行）
git show "refact-integration:$RD" | sed -n '114p'
```

## 2. 明确无异议（并确认纠正属实）

### 2.1 D-Q3（跨仓取证错位）— 无异议，纠正属实，qwen 自认此错

qwen 候选 §15.8 第 1425 行给 F-EXEC-01 的 **dsh 腿**「已支持（进程内）」时，同时引了 `profiles.py:36-41` `permits_tool`——那确是**本仓 investment-app 自己的代码**（`app/app/domain/agent/profiles.py`，非 dsh），且该 `AgentProfile` 生产休眠（`app/tests/test_dormant_capabilities.py` 约第 239 行 `Dormant(name="AgentProfile 在执行期生效", kind="pending")` 明记 `effective_config` 到不了图里、两条生产图对 `allowed_tools`/`denied_tools` 引用为 0）。拿我方休眠代码当租来 SDK 的能力证据，是跨仓取证错位，裁决方纠正属实。裁决稿已把 `profiles.py` 降为反面实例（第 1145 行）、F-EXEC-01 dsh 腿改判 `implicit_fallback` 并用真 dsh 证据 `ctx.tools.guard()`（第 1149 行）——**qwen 认可这个收敛**：删去假证据后，wire 层缺 per-Task 可信上下文，正是 qwen §15.4 G4/G5 已登记的缺口，改判比原「已支持」更准。

### 2.2 I12 / D-C5（错引 `constraints.md` I12）— 无异议，纠正属实，qwen 自认此错

`constraints.md` 的 I 系列只有 I1–I8（第 86–93 行，§身份）；qwen 候选第 1373 行写的「`../constraints.md` `I12`：敏感信息、凭据不进入普通事件 / 日志 / 前端投影」，其内容逐字是 `request-lifecycle.md:459` 的 I12。两文档各有一套**编号重叠、语义不同**的 I 系列，qwen 混了。「编号必须写明出处文档」的纪律成立，qwen 无异议。

### 2.3 D-Q1 / D-Q2 / D-Q4 / D-Q5（已接受）— 无异议，已核裁决稿忠实并入

| 处置 | 裁决稿落点（`refact-integration`，sha256 `ef20c8c6…`） |
| --- | --- |
| D-Q1 用 dormant 登记表替代「引用数为 0」 | 第 374–375 行（§4.5 引 `test_dormant_capabilities.py` 登记表）+ 第 674–676 行（回跑 dormant 测试纪律） |
| D-Q2 dsh teardown ladder | 第 555 行（`client.py:94/117/124` close → terminate → kill） |
| D-Q4 prefork/OOM 事故锚点 | 第 543–545 行（12 进程打爆 768Mi + `CELERY_WORKER_CONCURRENCY:'2'` @ `00-prerequisites.yaml:109`） |
| D-Q5 `subagent-codex` 打穿凭据互斥 | 第 1260–1264 行（Adapter 层显式禁止跨腿委派） |

### 2.4 基座未采 qwen 荐（kimi）— 无异议

裁决方 §4 的反驳成立：qwen 的「as-delivered 免搬迁」批评对象是 cursor，而 luna 整合同样附录居末、免搬迁，故该理由不构成推翻 luna 的依据。且基座选择属稿子整体判断，按 §2「不评稿子整体好坏」本就在异议范围外；qwen 评审 C 块自己也已确认 luna 的 `AT-*` 锚定最强（11 个），与 §12.3 最重维度一致。qwen 无异议。

## 3. 关于 R2（⑤ 验收改派 qwen）的确认——非异议

qwen 已知悉 `refact-rulings.md` R2：⑤ 验收方由 kimi 改派 qwen（顺位 `kimi(4) → qwen(5) → cursor(12)`，kimi 经 R1 不可用）。qwen 对 R2 **无异议**（发起人直接指示、已人确认、顺位在 ④ 通知中预先声明、代价已如实登记）。按 ④ 通知 §4.4「先做完 ④ 异议，等裁决方处置完再开 ⑤ 验收，不要同时做：验收的对象必须是已冻结的稿子」——**本文件只做 ④**。⑤ 验收 qwen 将在「三家异议齐 + 裁决方逐条处置并更新处置记录 + 稿子冻结」之后另行开始，届时把 R2 点名的两项弱项（`profiles.py` 跨仓出处、`constraints.md` I12 编号出处）列为重点复核项。

## 4. 盲区自陈

1. 未实跑任何 SDK、未起部署、未对生产库核表；本文件所有判断处于 `defined` 层。
2. 异议 1 基于三证（qwen 候选/评审全文 grep 零命中 + kimi §15.2 逐字命中 + luna 评审 D-2 归属）。**若裁决方掌握 qwen 未见的、确属 qwen 的「自由文本分类器兜底」出处（具体 file:line），请指出，qwen 据以撤回本异议。**
3. qwen 读了 luna 评审 D-2 与 kimi 候选 §15.2，**仅为定位 D-Q6 的出处错误**，未据此评价 kimi/luna 候选整体优劣（守 §2「不替别家喊冤」「不评整体」）。
4. qwen 未读 cursor 的「无异议」（`6db57869`，65 行）与 luna 异议全文（`2e1e4a53`，172 行）——④ 各家异议是独立信号，qwen 只就自己的处置表态，避免从众。
5. 引用行号以本文件「取件」处所列 commit 为准；分支若再前进，行号可能漂移，故同时给了 sha256 与可复跑命令。
