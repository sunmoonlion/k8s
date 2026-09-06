# ② 互评 ｜ cursor ｜ `runtime-refact`

> 作者：cursor。身份命令输出 `cursor`（工作目录 `/home/zym/worktrees/cursor/k8s`）。
> 隔离在 ① 结束后解除。本评审只读冻结 commit 上的 blob，不看各家工作区文件。
>
> **利益冲突**：评优方同时是候选作者。这不是独立终审。把自己排进排序是允许的，
> 比较依据与评别家同一套冻结标准（任务书 §8）。本评审把 cursor 放在第三，理由写在 C.5。

**裁定 R2**：本评审未读 `sunmoonai/docs/dev-plan/agent-dev-refact.md`，
未对其做打开 / `git show` / `grep` / `rg`，也未以其为比较尺子。
② 解除的是候选之间的隔离，不解除这一条。

---

## A. 自述（cursor 自己那份）

冻结对象：`runtime-refact/cursor:sunmoonai/docs/dev-plan/agent-dev-guide.md`
@ `d8fdb32a`（完整 `d8fdb32a94c678f489481b861a9cc63e72184298`）。

**写了哪些节**：§0 读法与身份；§1 硬约束 / 原则 / 不得淡化的验收边界；
§2 唯一运行时；§3 `dev.change/1`（字段、工单、档位三表、产物映射、路由）；
§4 登记表 / 粒度 / 证据 / 独立性；§5 人与权力表 H1–H8 / 通道；
§6 工作区、状态判定、git 载体；§7 中断恢复接库原语；§8 等效 / 开销 / 绕过；
§9 L0–L3 与五词；§10 文档职责与删除条件；§11 六个仍成立的结构问题；
§12 六条被证伪设计（独立复核）；§13 未决；§14 64 行落点表；§15 覆盖声明。

**标了 ⚠、未独立复跑的**：外部三仓源码行号；luna/kimi 的实际 `--model`、fable GUI 模型、
qwen 的 provider/model；CLI 工具级事件是否真有；托管方 key；Windows 侧；
历史轮次评审逐句；T0 上界四个数字未经实测；同 harness 不同模型的相关性；
M4 正则能否区分「复活」与「被证伪语境」。

**与其他家的结构性分歧**（① 期间未见他家，此处是评完才写）：

| 分歧 | cursor | 他家 |
| --- | --- | --- |
| `GraphRuntimeService.resume` 是 `NotImplementedError` | 写成 A4 适配器合同，不是恢复缺口（§7；`langgraph_runtime.py:17-20` 已翻译） | luna / kimi 未写该锚点；qwen 写成「抽象层尚未完成适配」 |
| 登记表取值 | 形状在指南，取值声明以 `agents.toml` 为准 | kimi 把当前六条写进正文 |
| 被证伪词的写法 | 在 §12「被证伪」语境里直接出现 | luna / qwen 用 HTML 实体躲 M4 正则 |
| 将删源稿的链接 | 不链 `refact-fable.md` / `runtime-architecture.md` 当现行文件 | kimi 文首链了这两份即将删除的文件 |

**故意没写、以及为什么**：

- 财务 Task Profile 的字段与验收用例——任务书 §4.2 明确不含；§1.3 只钉「不能外推」。
- 协议七环节逐步操作——权威在 `round-protocol.md`，重写即第二真源（B3）。
- 自定义入向字段表、独立仓、换钥匙、把人写成执行者——§12 已证伪，不进现行设计。
- 把 `resume()` 的 `NotImplementedError` 当成「库不能恢复」——基类抛错是适配器合同。

---

## B. 候选集冻结

取件命令按 `call-②.md`：`git cat-file -p runtime-refact/<家>:sunmoonai/docs/dev-plan/agent-dev-guide.md`。
哈希用 Python `hashlib.sha256` 对 blob 字节计算（不用 zsh 的 `"$w:path"`——冒号会被当成修饰符，
`git show` 会取错对象）。四份全部与环节通知表对得上。

| 家 | 路径 | 行 | 字节 | commit | sha256 |
| --- | --- | --- | --- | --- | --- |
| luna | `runtime-refact/luna:sunmoonai/docs/dev-plan/agent-dev-guide.md` | 648 | 43921 | `39889605f21bd41d22501a426bc690e0df76f5a2` | `cc47d068c39c9bcd68b5f120a9794b4eecb3aacf60a2c1d8c72502afdb8dcfea` |
| kimi | `runtime-refact/kimi:sunmoonai/docs/dev-plan/agent-dev-guide.md` | 917 | 71858 | `dc8efd599e007ebe8c3e87e0209d317866cd61ef` | `913ccb082320b8e6470dc3d8566590c157aad6488fd15cb373b773e7f4a84774` |
| cursor | `runtime-refact/cursor:sunmoonai/docs/dev-plan/agent-dev-guide.md` | 921 | 70095 | `d8fdb32a94c678f489481b861a9cc63e72184298` | `926a974e02df238f3a180dc1afa20aa89333a2ba3fdebd2d24a18269971d5138` |
| qwen | `runtime-refact/qwen:sunmoonai/docs/dev-plan/agent-dev-guide.md` | 187 | 22316 | `7d31265a8c0c0f905b0a420a39d0740602175ee5` | `e783ce080489c83783e99ee576cdaacfd508c80d47decc73437562b8d2213198` |

四份都在。不少一份。正文从上述 blob 读，不从 `~/worktrees/<家>/` 工作区读。

---

## C. 评优

比较对象是任务书 §8。篇幅本身不是判据（Q5）。

### C.1 机械条（M1–M7）

落点表行数：luna `refact-fable` 31 + `runtime-architecture` 33；kimi 同；cursor `| F |` 31 + `| R |` 33；qwen 同。四家都是 64。

| # | luna | kimi | cursor | qwen |
| --- | --- | --- | --- | --- |
| M1 | 过 | 过 | 过 | 过 |
| M2 | 过。撤销项同时给落点章与故意不要理由 | 过。runtime §3.x / §4.4 的故意不要超过 15 字且指出被什么取代 | 过 | 过。理由够长 |
| M3 | 人判。未把别家 blob checkout 进本 worktree 跑两门禁 | 同左 | ① 提交时 `doc-gate.py --all` 与 `anchor-gate.py` 均 0 | 人判 |
| M4 | **零命中**（D2 用 HTML 实体：`am&#101;nd`、`三道&#36793;界`）。机械过 | 命中均在 §1.1「被证伪」表与 D2 故意不要行，标 **已证伪** | 命中均在 §12 被证伪表与 D2 源标题 | **零命中**（`两个&#32;Profile`、`三&#36947;边界`） |
| M5 | 正文明确「不是两套运行时」。D2 源标题用实体 | D2「两个 Profile」出现在故意不要行，结论已推翻 | D2 源标题保留，正文不沿用分层 | 故意不要该双部署用词 |
| M6 | 无 `kind = "human"` | 无 | 无 | 无 |
| M7 | 过。§9.2 具体到 GitHub 管理面、外部仓、产品测试、旧轮全文、GUI | 过。§13 | 过。§15 | 过。§7 |

M4 的 luna / qwen 写法：任务书允许「零命中」或「被证伪语境」。零命中机械过。
代价是源标题不可检索，看起来像在躲门禁。kimi / cursor 的「出现 + 明确标注」更利于后人搜「不要再做这些」。
**不因此扣 luna / qwen 的 M4**，记为吸收时的写法选择。

luna §9.2 另声明：依 `AGENTS.md` 强制入口，在读任务书前读了未列入只读输入的
`working/development-lifecycle-agent.md`，并声明未据其结构起稿。这是输入边界偏差，不是 F2
（F2 管的是禁读参考作品且不声明）。

### C.2 判断条（J1–J8）

**J1 新读者可读**（抽三个专有名词）：

| 抽查 | luna | kimi | cursor | qwen |
| --- | --- | --- | --- | --- |
| Task / Attempt | §1.1 指路内核 `@ ed0b5136` | §2 文档地图，定义在内核 | §0「定义就是内核核心对象表」 | §1 表指路内核 |
| 权力表 / H5 | §4.2 有完整 H1–H8 表（本评审读到 `:299-306`） | §5.4 有完整表（`:360-367`） | §5.2 有完整表（`:381-388`） | §2.1 只说「权力必须有强制点」，**无表、无 H 行** |
| `dev.change` | §0 / §2.3–§2.4 | §4.2–§4.3 | §2.2 / §3 | §2 一句话，无字段表 |

luna 另有 §0.2「为什么分成这些章」，是四家唯一把「多一章的理由」写出来的（对齐 Q2）。
kimi 文首链了两份即将删除的源稿，新读者点进去会看到将被清掉的文件。
qwen 对「权力表」「粒度三字段」「等效」没有可定位定义，J1 抽查会失败。

**J2 落点表属实**（各抽 8 条声称落点，打开对应节核对）：

luna（8/8 方向属实，1 条偏薄）：

1. F 3.3 权力表 → §4.2：有 H1–H8。属实。
2. F 3.11 git 载体 → §5.4：有「能证明 / 不能证明」。属实。
3. F 3.12 验证分层 → §5.5：有 L0–L3。属实。
4. R 2.7 等效 → §5.3：有 S 层 / R 层与六条比较规则。属实。
5. R 4.1 粒度三字段 → §5.1：有 observability / enforcement / sandbox。属实。
6. R 5.3 T0 上界 → §6.2：有复合向量。属实。
7. F 3.6 工单 → §2.4：有 TOML 形状。属实。
8. R 2.3 登记表 → §2.3：有字段清单，**没有当前六家取值表**。方向属实，比 kimi / cursor 薄。

kimi（8/8 属实，1 条自指错误）：

1. F 3.3 → §5.4：有表。属实。
2. F 3.9 五词 → §5.1：有五词表。属实。
3. R 2.7 → §6.5：有 S/R/投影/TraceEnvelope。属实。
4. R 4.1 → §6.1：有三字段。属实。
5. R 5.3 → §8.3：有复合上界。属实。
6. F 3.7 工作区 → §7.3：有纯函数供给。属实。
7. R 3.2 字段表 → 故意不要：与 §1.1 第 1 条一致。属实。
8. 摘要第 6 点把「最难的一半」标成 **§10.1**。§10.1 实际是「文档分工与本稿不含什么」；
   该边界正文在 §2 第 85–88 行。**内容在，指针错。**不算 F3（不是无内容），但是伪取证的轻型。

cursor（8/8 属实；自评，标准同左）：

1. F 3.3 → §5.2。2. F 3.9 → §9.2。3. R 2.7 → §8.1。
4. R 4.1 → §4.2。5. R 3.2 / 3.3 → 故意不要，与 §7、§12 一致。
6. F 3.7 → §6.1。7. R 5.3 → §8.2。8. F 1.2 → §9.2 / §11.1。

qwen（抽 8 条，**至少 5 条有表无正文**——J2 计零的形态）：

1. F 3.3 权力表 → §2.1、§5：§2.1 是角色/组件列表，§5 是验收/成本。**无 H1–H8。**
2. R 4.1 粒度三字段 → §4.1：§4.1 标题是「断言的最低形状」（自述/可重算/进程观察/外部权威），
   **不是** observability / enforcement / sandbox。全文 `observability|enforcement|sandbox` 零命中。
3. R 2.7 等效 → §4.1、§4.3：无 S 层 / R 层，无 TraceEnvelope。
4. R 2.3 五个 Agent Profile 登记表 → §2.1、§4.1：无登记表、无 harness/dispatch 字段。
5. R 2.5 产物 → 状态机 → §2：无投影表。
6. R 5.3 T0 开销上界 → §2.2、§5：§5 提到成本，**无复合向量、无四维上界**。
7. F 3.12 验证分层 → §5：有「机械 / 独立 acceptor / 异议 / 人确认」顺序，未用 L0–L3 名，薄但方向对。
8. F 3.11 git 载体 → §4.3：**属实**，这是 qwen 少数真正搬过来的节。

qwen 的 64 行表填满了，但权力表、粒度、等效、登记表、产物映射、T0 上界这些
`runtime-architecture.md` 里**立得住**的部分没有进正文。这是任务书 F3。
J2 对 qwen **计零**。不触发 §8.3 第 1 条（表在），也不触发第 3 条（正文有锚点，不是无锚散文）。

**J3 §1.1 六条处置有据**：

| # | luna | kimi | cursor | qwen |
| --- | --- | --- | --- | --- |
| 1 自造 Interaction 协议 | `pilot_graph.py:59-66` + `langgraph_runtime.py:14-21` | `pilot_graph.py:59`；自称 **`Command(resume=` 25 处全部单参数** | 引用 `pilot_graph.py:59-68`；`rg Command(resume=` | `pilot_graph.py:53-66`；另引 **spike 测试** |
| 2 恢复开新 Attempt | 同一 `session_id→thread_id`；`agent_graph.py:106-128` | `graph_runtime_service.py:40-46` | 同左 + 内核「原地恢复」句 | 同左；并指出 `resume()` 基类抛错 |
| 3 独立仓 | 宿主重跑 `sudo -n -l` → `NOPASSWD: ALL`；forensics `@ ed0b5136` | `id` 已跑；**sudo 在沙箱被 no-new-privileges 拦，如实标部分复核** | 宿主复跑 sudo；附 `uid_map` 恒等映射 | 声称本次复跑 `id && sudo -n -l` |
| 4 隔离仓 | `git branch -vv` 仅 master 有 upstream | 五家无 upstream；`ls-remote` 沙箱断网不可跑 | `branch -vv` + `ls-remote --heads` | 未单列「agent 从不 push」的命令 |
| 5 换 key | `ls-remote --tags` 远端只有 `2.0.0` 与 `pre-architecture-v2-final-20260813` | master ahead origin 93 作旁证；远端 tag 沙箱不可查 | 与 luna 同类的 tags 证据 | 未单列 tags 命令 |
| 6 外层边界当安全架构 | 由 K3–K5 推出「动作不经过那些设施」 | 由 3–5 互证 | 由 3–5 + forensics F1/F2 | 由 §4.2 宿主权限推出 |

qwen 对第 1–2 条的取证不劣于任务书给的两处，并且多了
`tests/test_runtime_selection_spike.py`。本评审在 cursor 的 `investment-app`
（子模块 `18d88c7c`）核过：

- `graph_runtime_service.py:26-31` 确为 `NotImplementedError`；
- `test_runtime_selection_spike.py:42` 确有同一 config 上 `Command(resume="approved")`；
- `:96` 确有 `old_graph.invoke(Command(resume="approved"), ...)` 按钉定图版本恢复。

这是 qwen 独有、且锚点支持断言的一条（J5 正例）。luna / kimi / cursor 都没引这组测试。

kimi 把沙箱拦 sudo 写成「部分复核」而不是假装跑过，符合 J5。luna 区分「沙箱最初失败、宿主只读复核成功」，同样合格。

**J4 立得住 vs 站不住**：

立得住（对象模型、粒度、证据等级、权力表、等效判据）在 luna / kimi / cursor 三家
都有独立专节。qwen 只保留了对象模型的指针和证据纪律的骨架，粒度 / 权力表 / 等效 **正文缺失**，
J4 对 qwen 不成立。

站不住的六条，四家都没有当作现行设计写回来。luna 的建设性替代最清楚：
产品 Interaction 字段绑定到 `interrupt` / `Command(resume=)`，强制点画在真实写路径上。

**J5 取证质量**（抽现状句）：

- luna `forensics.md @ ed0b5136:18-45` + 宿主重跑 sudo：锚点存在且支持「本机脚本不是强制点」。
- kimi「25 处 `Command(resume=` 均为单参数」：形状成立，**精确计数不采信**。
  本评审在 cursor 的 `investment-app` 用 `Command\(resume=` 扫 `investment-backend/**/*.py`，
  得 **21 处**（测试 9 + 脚本 9 + 生产 3：`langgraph_runtime.py:19`、
  `agent_graph.py:128`、`pilot_agent_graph.py:209`），全部单参数，无第二套入向协议。
  21 ≠ 25，故「25」标候选自报；「全部单参数」独立成立。
- cursor `uid_map 0 0 4294967295`：支持「这次取证是宿主不是沙箱伪 root」。
- qwen 对 spike 测试的行号 **支持断言**（已核）。
- qwen「`GraphRuntimeService.resume()` 仍明确抛出 `NotImplementedError` …
  不能据此宣称端到端恢复能力已经落地」：锚点存在，**断言半对**——基类未实现不等于
  `langgraph_runtime.py` 没有恢复。cursor 把同一锚点读成适配器合同。
  「锚点存在但不完全支持那句更强的结论」，按任务书比没有锚点扣得更重。
  不否决 qwen 的测试发现，只否决「抽象层尚未完成适配」这句外推。

**J6 不重写权威定义**：

四家都把内核 / 协议列为只引用。luna 与 cursor 列出合法转换子集（⊆ 内核表），
是投影不是重定义，但有漂移风险。kimi §10.4「内核按 commit 引用」把这个风险写成了规则。
qwen 几乎不复述状态词，J6 最干净，但也因此没把开发投影写出来。

**J7 §4.3 边界（开发验收机械且便宜 / 财务判断且昂贵）**：

- luna §1.4，未淡化。过。
- kimi 正文在 §2:85-88，未淡化；摘要误指 §10.1。过（指针瑕疵见 J2）。
- cursor §1.3，未淡化。过。
- qwen §5 两句加粗，未淡化。过。

**J8 自增内容**：

- luna：Interaction 字段 → 库原语的最小绑定；安全改为「逐动作画真实路径」；
  R0–R5 改成 G0–G5（先原语 spike 与身份强制）。三条都有 §4.3 / §4.4 / §8.1 锚点。**加分。**
- kimi：独立性折算算法（分组键 = harness，带取证 ×2）；`dispatch_event` 可数但不是批准；
  收件箱字段分级。**加分。**
- cursor：强制点必须落在动作经过的路径上；`resume()` NotImplementedError 的 A4 读法；
  登记集合 ≠ 自动路由候选集。有锚点。**加分。**
- qwen：几乎没有超出「纪律摘要」的新条款。spike 测试是取证增量，不是新设计条款。中性。

### C.3 一票否决

四家都有 D2 表；都不是大段重定义内核；luna / kimi / cursor 的本仓事实与编号密度足够；
交付路径都是共享最终路径同名文件。qwen 正文短，但有 `file:line`，不够成第 3 条
「频次接近零」。**无一家触碰一票否决。**

qwen 不进主干，是因为 J2 计零 + J4 立得住部分没搬过来，不是否决条款。

### C.4 预判失败形态

| # | 命中 |
| --- | --- |
| F1 无锚散文 | 无一家以散文为主体 |
| F2 读了禁读文件不声明 | 无。qwen 声明规划子代理可能宽泛搜索见过匹配，未提供内容——这是声明，不是隐瞒 |
| F3 表填满内容没搬 | **qwen**。luna / kimi / cursor 抽查属实 |
| F4 「已过时」四字当理由 | 无。四家故意不要都说了被什么取代 |
| F5 同一信息说三遍 | kimi 917 与 cursor 921 有重叠。luna 648 更干净。不按行数给分，只记：同等覆盖下 luna 更短 |
| F6 六条照抄不跑 | 无一家完全照抄。kimi / luna 对跑失败的命令有环境说明。qwen 第 4–5 条偏薄 |

### C.5 完整排序与基座

**利益冲突再声明一次**：下面把 cursor 放在第三。不是谦虚——luna 的新读者结构与证伪后的可执行替代，
是 kimi / cursor 两份近乎同构的完整目录所没有的增量。cursor 独有证据放到 D 块吸收。

| 名次 | 家 | 一句话 |
| --- | --- | --- |
| 1 | **luna** | 立得住的部分都有正文，新读者路径最好，证伪之后有可执行的替代，篇幅没有明显第三次重复 |
| 2 | kimi | 目录最全，独立性折算与登记取值可直接用；摘要误指 §10.1，文首链了将删文件 |
| 3 | cursor | 与 kimi 同阶完整；NotImplementedError 的读法与宿主 `uid_map` 应被吸收，不需要整份当基座 |
| 4 | qwen | 纪律骨架与 spike 测试值得摘；权力表 / 粒度 / 等效 / 登记表有表无文，不能当主干 |

**选 luna 当基座的理由（事实差，不是票数）**：

1. J1：§0 先读结论 + §0.2 每章为什么独立存在，是四家唯一对齐 Q2 的写法。
2. J2：抽查 8 条 7 条实、1 条偏薄，没有 qwen 那种系统性空转。
3. J3/J4：六条有独立观察表（K1–K6），立得住的权力表 / 粒度 / 证据 / 等效 / L0–L3 / T0 上界
   都在对应节里，不是「见 §1–§5」这种无法抽查的落点。
4. J8：证伪之后写了「绑到现有原语」和 G0–G5，而不是只删。
5. F5：覆盖与 kimi / cursor 同级时更短。任务书写明同等质量下更短的更好。

不选 kimi 当基座：完整度足够当基座，但（a）摘要把 J7 指到错误节号；
（b）文首把将删源稿当现行链接，发布后即死链；（c）登记取值写进指南，
与 `agents.toml` 形成第二真源。这些是整合时要改的，不是否决。

不选 cursor 当基座：与 kimi 重复度高，当基座没有 luna 的新读者结构，
也没有 luna 的 Interaction 字段绑定。独有证据放到 D 块吸收。

不选 qwen 当基座：J2 计零。可摘不可座。

---

## D. 值得吸收的点

基座按上面定为 luna。下列主张无论最终基座是谁都值得并进。

### 出自 kimi

1. **§5.6 独立性折算算法**（分组键 = `harness`，同组带 `file:line` 则权重 ×2，
   先比独立信号数再比带取证组数）。luna / cursor 只有「按字段推导」的方向，没有可执行规则。
2. **§1.1「本候选的复核」列**：把「已复核 / 部分 / 沙箱不可跑」写成表。
   luna 的 K 表接近，但 kimi 把失败环境（no-new-privileges、DNS）写进同一格。
3. **runtime §6 / §7 / §8 故意不要的理由**：轮次裁定过程与自检表是档案，不是指导文档。
4. **§10.4 内核按 commit 引用**：防指南与内核 HEAD 双向耦合。luna 已经在用 `@ ed0b5136`，
   把三条规则（钉 commit、改状态词走 T2、对称差为空才合并）写死更好。
5. **H5 拆 `H5-final` / `H5-round` 只登记不擅自加行**（kimi §5.4 ⚠）。luna §7.4 也点了，
   保留「不改行数、留给所有者」这一句。

### 出自 cursor

1. **`GraphRuntimeService.resume` 的 `NotImplementedError` 是适配器合同，不是恢复缺口**
   （§7，`graph_runtime_service.py:26-31` + `langgraph_runtime.py:17-20`）。
   qwen 发现了同一锚点但外推过了；luna 没写。吸收 cursor 的读法，保留 qwen 的测试。
2. **取证必须附 `hostname; id; cat /proc/self/uid_map`**（§6.2）。luna 区分了沙箱与宿主，
   但没有把伪 root（`uid_map: 0 1003 1`）写成可复跑手续。
3. **登记集合 ≠ 自动路由候选集**（§4.1）。luna §2.3 有同方向一句；cursor 把 `dispatch_event`
   明确排除出权力表。与 kimi 的 `dispatch_event` 可数合并。
4. **取值以 `protocol/agents.toml` 为准，指南只固定字段形状**（§4.1）。
   吸收 kimi 的 ⚠ 项（qwen provider 留空、fable 不可机械核验），不要把六条快照写死在指南里。
5. **合法转换子集明示「内核没有 `WAITING → SUCCEEDED`」**（§1.1）。luna 权力表已写
   「H5 不是把 Task 从 WAITING 写成成功」；把禁止边点名，新读者更不容易发明捷径。

### 出自 qwen

1. **`test_runtime_selection_spike.py:42`**：同一 thread 上 `Command(resume="approved")`。
   这是第 1–2 条比 `pilot_graph.py` 更强的行为证据——luna / kimi / cursor 都停在源码形状。
2. **同文件 `:96`**：等待中的检查点按钉定图版本恢复。源稿和任务书都没点这处。
3. **覆盖声明里写「规划子代理可能宽泛搜索见过禁读文件」**：即便没有内容泄露，
   这条比「我没读」更可审计。基座的覆盖声明应保留「机制无法证明隔离」。

### 出自 luna（若基座改选别人，这些不得丢）

1. §0.2 每章独立存在的理由。
2. §4.3 把内核 Interaction 字段绑到 `interrupt` / `Command(resume=)` 的最小方案，
   以及「不要从自由 resume 反推平台级 patch 协议」。
3. G0–G5 依赖顺序（G1 = 原语 spike，不先发明字段）。
4. 确定性组件（router / orchestrator / interaction service / validator）与内容角色
   （proposer / reviewer / …）分两张表——kimi / cursor 的「五词」把代码组件和 agent 角色挤在一起，
   luna 拆开更不容易把人写成 orchestrator。

---

## 本评审的盲区

- M3：未把 luna / kimi / qwen 的 blob checkout 进本 worktree 跑 `doc-gate.py` / `anchor-gate.py`。
- 未把 64 行落点表每一行都打开对正文；J2 是各抽 8 条。luna 的「登记表偏薄」可能不是唯一薄点。
- 未读 `agent-dev-refact.md`，因此不能判断谁在结构上向它收敛——按 R2 这不是本环节该做的。
- 评优方是 cursor，对「cursor 与 kimi 同构」的判断可能偏严（避免把自己排第一），
  也可能偏松（对自己的 NotImplementedError 读法更熟）。裁决方应按 commit 重核 D 块各条，
  不要采信排序本身。
