# 开发生命周期 · Agent 重写稿 · 本轮选定

> 评审日期：2026-09-02
>
> **评审对象是各助手 worktree 里的未提交文件，不是冻结 commit。**按各稿自己的
> 纪律，这只能叫「对照审 / 本轮选定」，不能叫「已证明正确」，也不能当最终整合。
> 最终收主线仍须：选定稿落到可达 commit、独立整合、人终审。
>
> 评审方是 **cursor**，同时是候选 C 的作者。候选作者不拥有最终有效票；本文件是
> 对照意见和吸收清单，决策权在人。为降低自评偏差，硬门禁先于偏好，并单独列出
> 「cursor 稿明显弱于别人的地方」。

## 1. 候选清单

对照时读的是各 worktree 工作区文件（2026-09-02 16:19 前后）。qwen 按自己的命名
约定把稿放在带后缀的文件名下，其余三路文件名相同、工作区不同。

| ID | 助手 | 路径 | 约行数 | 工作区 mtime |
| --- | --- | --- | ---: | --- |
| L | luna | `worktrees/luna/k8s/sunmoonai/docs/dev-plan/working/development-lifecycle-agent-new.md` | 908 | 16:09 |
| K | kimi | `worktrees/kimi/k8s/sunmoonai/docs/dev-plan/working/development-lifecycle-agent-new.md` | 609 | 16:12 |
| C | cursor | `worktrees/cursor/k8s/sunmoonai/docs/dev-plan/working/development-lifecycle-agent-new.md` | 756 | 16:05 |
| Q | qwen3.8 | `worktrees/qwen3.8/k8s/sunmoonai/docs/dev-plan/working/development-lifecycle-agent-new-qwen3.8.md` | ~729 | 较早一版后扩 §5 |

opus 该路径无 `-new` 稿，不进入比较。

早期事故：C 与 L 曾有过字节级相同的拷贝（写进人的主 checkout 后互拷）。**当前四份
正文已分叉，按独立候选比较。**那次拷贝本身按各稿纪律应记为污染窗口，不因此取消
后来各自改写的资格，但说明「磁盘上最后一版」不能当交卷。

## 2. 硬门禁（先于偏好）

用户给的对照与后来的覆盖教训，当作本轮硬门禁：

| ID | 门禁 | 不通过则 |
| --- | --- | --- |
| G1 | 人与 agent 的 **supervisor 地位等同**；FastAPI / 建仓者不是 supervisor | 对照写反 |
| G2 | Agent 路径：前端 → FastAPI 整理成 Task → 复杂任务在 sandbox **构建 git 并按任务塞入** → 其后按需 worktree | 建仓主体写错 |
| G3 | 人路径：人建 git、人建 worktree | 同构失败 |
| G4 | 本文须写全共享纪律（内核、fan-out、范围门禁、证据、停止、失败实例），因 agent 文开发结束后会删 | 删掉后无着落 |
| G5 | 产出物 / commit 按场景隔离；**隔离单位是 worktree + 命名分支，不是共享目录上的文件名** | 会再覆盖 |
| G6 | 不把产品状态机（`QUEUED`、租约、fencing）搬进开发侧当同一套机制 | 两套生命周期缠死 |
| G7 | 不得自我批准、证据先于投票、评审绑 commit | 原 agent 文内核 |

逐项裁决：

| 主张 | L | K | C | Q | 结论 |
| --- | --- | --- | --- | --- | --- |
| G1 supervisor 等同，建仓者 ≠ supervisor | 写清：FastAPI 是受理/物化入口，派活选优归 supervisor | **未过**：把「人建仓、人建 worktree」整体映射成「agent 在 sandbox 建仓、建 worktree」，把供给方和 supervisor 合成一个 agent | 写清：FastAPI 建顶层仓，supervisor 建后续 worktree | 写清：平台建仓，supervisor 编排 | K 不入选主线 |
| G2 谁构建 sandbox git | 后端 / provisioner 物化，Attempt 启动前过门禁 | **未过**：正文多次写「复杂任务由 agent 在 sandbox 中构建 git 仓库」 | FastAPI 构建并塞材料 | 「fastapi / sandbox 基础设施」构建 | K 不入选主线 |
| G3 人建仓建 worktree | §1.2 同构，入口差到可写工作区为止 | 对照表有，但建仓主体与 G2 连错 | §0.2 对照表 | §0.3 对照表 | L/C/Q 过 |
| G4 写全原 agent 文落地纪律 | 内核与 fan-out **压缩**；无独立 Investment App 门禁；2026-08-27 实例大多不在 | 保留 fan-out 骨架与证据账；**无 Investment App 专节**；无 `parallel-proposals.py` | 保留原 §1–§4、§6–§10 结构、Investment App、2026-08-27、parallel-proposals | 与 C 同族，原结构保留最完整 | L/K 在 G4 上偏弱，未到「不进入比较」，但是减分 |
| G5 隔离靠 worktree+分支 | §0.4「私有产生、单写者发布」；同相对路径允许、同物理工作区禁止；共享目录时用 owner namespace，否则串行 | §7 归属先行；场景表较短但「后到者赢不成立」 | 四种载体 + S1–S27；明确「文件名不是隔离」 | **未过作为主线**：§5.2 律 3 把「文件名带助手标识」写成与 worktree 并列的硬律，并声称本次事故根因是「没用带标识的公共文件名」。事故根因是写入 `~/master` 共享工作区；Q 自己能幸存是因为写在 `worktrees/qwen3.8`，不是因为后缀 | Q 的律 3 不得进入主线 |
| G6 不搬产品状态机 | 偏弱：把 Submission→Delivery、租约/fencing 冷启动核对写进本文主流程，和 request-lifecycle 边界过近 | 声明不复制状态机，但仍用 `QUEUED` 等产品名解释冻结点 | 保持「相邻不是上下级」；迟到靠 commit 不是租约 | 与原稿一致，边界清楚 | L 需收窄后才能当主线正文 |
| G7 自我批准 / 绑 commit | 过 | 过 | 过 | 过 | 全过 |

**硬门禁后仍可作主线候选的：L、C。** K 因 G1/G2 退出主线。Q 因 G5 的错误控制律退出主线；其清单和对照表仍可作改进输入。

## 3. 偏好比较（仅 L vs C）

维度在比较前取：正确性（对照是否可执行）、完整性（原纪律 + 覆盖场景）、可维护性
（人以后只留一份时是否还能用）、实施成本（runtime 能否按条文落地）。

| 维度 | L | C | 说明 |
| --- | --- | --- | --- |
| 正确性：文档身份 | 更贴用户原话「前端→FastAPI→Task→sandbox git」 | 仍偏「开发助手 SOP + 一节对照」 | 用户要的是 **agent 路径与人路径同构**，不是只在旧文开头加对照。L 胜 |
| 正确性：物化 | §4 有步骤、manifest、门禁；半成品仓不得开 Attempt | 有对照和禁止 `git init`，无物化清单 | L 胜 |
| 正确性：产出物 | 分类（源码/草稿/生成物/证据/副作用/秘密）；候选状态机；发布协议（candidate path ≠ publication path）；CAS/ETag；事故 8 步 | 四种覆盖语义更利落；S 表贴本仓 `~/master` 与 `~/worktrees/<助手>`；「已发生时」列可操作 | 产出物模型 L 更深；本仓落地纪律 C 更贴。偏好 L 作主干，C 作必须吸收 |
| 完整性：原 agent 内核 | fan-out、两阶段审、匿名随机、claim-id 分支、Investment App、2026-08-27 实例被压缩或删 | 基本整段保留 | C 胜。G4 要求写全，主线若不吸 C 会丢开发期已验证的失败控制 |
| 完整性：覆盖场景 | §7.6 最宽：共享物理目录降级、Attempt 重试、CI 单槽、symlink、敏感物、PR 追加 commit、崩溃恢复 | S1–S27 含 handoff 单写者、拷别人未提交稿、误写主仓怎么撤 | 并集才够；单份都不满分 |
| 可维护性 | 908 行，产品+开发缠在一起，agent 文删除后更像一份开发 Profile 合同 | 756 行，结构仍是原稿，人那份以后好对位迁入 | 长期保存若在人那份，C 的章节更易搬；L 的物化章人也需要 |
| 实施成本 | 需要 provisioner、manifest、publication CAS，偏目标架构 | 当前 worktree 布局立刻能执行 | 近期防覆盖用 C；产品建 sandbox 用 L |

未决偏好（证据无法分出唯一正确）：L 把冷启动租约/fencing 写进 agent 文，是产品纪律前移还是越界，交人裁。建议：**产品机制只引用 request-lifecycle，本文只写 Git/worktree/产出物不变量。**

## 4. 本轮选定

**选定主线：L（luna）。**

一句话理由：它把「人 ≡ supervisor、FastAPI 供给工作仓、复杂任务先物化再执行、产出私有产生且单写者发布」写成可执行合同，最接近用户要求的对照；产出物与 commit 的场景覆盖也最深。

**不得整文件采用。**必须做胜者改进，否则 G4/G6 不满足。

### 4.1 必须从 C 吸收

1. **四种载体表**（未提交文件 / commit / 分支指针 / 远端与主 checkout）放到产出物章最前。L 的 7.5 有对象语义，缺「未提交文件后写覆盖先写、无冲突无历史」这一条——而这正是 2026-09-02 的机制。
2. **明确：文件名、`-new`、助手后缀都不是隔离。**相对路径可以相同，前提是 worktree 不同。
3. **本仓具体落点：**读可在 `~/master/<仓>`；写只在 `~/worktrees/<助手>/<仓>`。人的主 checkout 不是投稿箱。S1/S4/S21 的「已发生时」处置（移走共享路径上的文件、不要在主仓 commit 补救、污染稿不计入独立候选）。
4. **派工字段** `workspace_path` / `exclusive_branch` / `forbidden_write_paths`；动手前 cwd 对不上则停写。
5. **Investment App 范围门禁**整节（原稿 §4），以及 `parallel-proposals.py` 的验证边界。
6. **2026-08-27 失败实例**（只写分支名、优胜作者拒改进、验收标准无人跑）和 dormant 四级词典。这些是已发生的项目实例，L 删了会让「写全」落空。
7. **handoff 单写者**：执行者写自己 checkpoint，supervisor 才写共享 `handoff.md`。

### 4.2 必须从 K 吸收

1. 「**后到者赢在任何场景都不成立**」写成硬句。
2. 覆盖事后四步的紧凑版：保全现场 → 恢复归属分支 → 判定重复/互补/无关 → 记入证据账。可与 L §7.8 合并，不要两套事故流程。
3. 「本文删除后，仍有效的纪律必须已落成代码/测试/门禁」——对应用户「agent 文会删、人那份要留」；人那份写全之外，能门禁的不要只留在 md。

### 4.3 可以从 Q 吸收（不得吸收律 3）

1. 写入前五问清单（路径是否归我、是否在自己 worktree、目标是否已有他人产物、覆盖物是否已落账、是否宽泛写入）。
2. 对照表的「工作区由谁建 / 批准权归谁」两句压缩，可作 §0 导读。
3. **拒绝：**把 `<主题>-new-<assistant>.md` 写成硬律。它最多是共享物理目录时的降级（L 的 owner namespace），不能替代 worktree。Q 对事故的归因（luna 覆盖 cursor、根因是没加后缀）与哈希事实不符：当时 C 与 L 内容相同，是共享路径上的拷贝/覆盖；Q 能留下是因为写在自己的 worktree。

### 4.4 L 自己必须改掉的

1. 开发侧迟到与取消 **不要用租约/fencing 当机制**；写「产品侧见 request-lifecycle；开发侧靠冻结 commit 与整合方核对」。
2. 恢复独立的 Investment App 门禁，或把等价核对写回硬表，避免 G4 缺口。
3. fan-out 补回：匿名随机展示、两阶段独立审的输入差、claim 级改进分支命名、角色利益冲突表的禁止项。L §6 能用，但比原稿薄。
4. 选定结果的用语保持「本轮选定」，已做到；整合章须写明源是 commit 哈希，禁止拷未提交工作区进 `master`（C S12）。

## 5. 不选 K、Q 作主线的可复核理由

**K**

- 建仓主体写反：用户链路是 FastAPI 整理 Task，复杂任务在 sandbox 建仓并塞材料；K 写成 agent 自己 `构建 git 仓库`。
- 有权主体写成「前端用户经 Interaction」，把产品用户和开发期人类维护者拧成一个词，人那份的批准权对不齐。
- 产出物章可用，但场景少于 L/C，且建立在错误的建仓模型上。

**Q**

- 对照与原结构好，几乎是「原稿 + §0.3 + §5」。
- 把文件名标识升级成与 worktree 并列的第三律，会在下一次「都写 master、只是文件名不同」时制造虚假安全感；若文件名再撞上（本次四路里三路都叫 `development-lifecycle-agent-new.md`），仍覆盖。
- 事故叙述不准确，不能当证据账的权威记录。

## 6. cursor 自评（供人打折扣）

C 相对 L 的真实弱点，不粉饰：

- 文档身份仍是「开发助手怎样闭环」，用户要的对照主轴是产品 agent 路径；§0.2 有对照，后面章节没有把 FastAPI 受理、物化门禁写成主流程。
- 产出物分类不如 L（没有秘密/大文件/CI 单槽/发布 CAS）。
- 没有「只能共享一个物理目录时」的降级 namespace，也没有「平台连 namespace 都做不到则必须串行」。
- S 表长，但条目偏本仓开发助手，产品 Attempt 重试、外部副作用 owner 不如 L。

C 相对 L 仍值得保留的，已列入 §4.1，不因作者是 cursor 就升格为主线。

## 7. 建议的整合顺序（人批准后才做）

在 **cursor 或指定整合方** 的 `integrate/` 分支上，不要在 `~/master` 拼文件：

1. 以 L 的 §0–§4、§7 为骨架（对照、受理、简单/复杂、物化、产出物生命周期）。
2. 嵌入 C 的四种载体、本仓 worktree 落点、S 表中 L 没有的行（S6 拷贝污染、S20 handoff、S21 人正在主仓写）。
3. 嵌回原稿级 fan-out 与 Investment App（从 C 或原 `development-lifecycle-agent.md`）。
4. 合并 K 的覆盖事后处置与「后到者不赢」。
5. 采用 Q 写入前五问；删除其文件名硬律。
6. 全文只保留一套事故流程、一套词汇表。
7. 交卷报 **integrate 分支的 commit 哈希**，并声明未覆盖项。

未做完上述吸收前，不要把 L 原文直接换掉现行 `development-lifecycle-agent.md`。

## 8. 本评审自身的落点

| | |
| --- | --- |
| 写入面 | `worktrees/cursor/k8s/.../development-lifecycle-agent-new-review.md` |
| 不是 | `~/master/k8s/...`，也不是 luna/kimi/qwen 的 worktree |
| 权威性 | 对照意见；无独立验收；无 commit 则仍是草稿 |
| 下一步 | 人裁定是否采纳 §4；若采纳，指定非 cursor 的整合方更干净 |
