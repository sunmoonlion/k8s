# 合并前独立评审与吸收建议（luna）

> 评审时点：2026-08-29 ｜ 评审方：luna
>
> 所审主仓提交：`k8s@f8b10832a99c28b152ab1cb2f8a440fc51033144`
>
> 定位：本文件供最终投影撰稿人吸收，不是另一套并列权威，也不要求恢复旧
> `sunmoonai-architecture/` 的目录结构。

## 0. 覆盖范围与边界

本轮阅读并比较了：

- `project-guide/` 全集（总览、五仓投影、四个跨仓主题、治理入口）；
- `dev-plan/constraints.md`、`dev-plan/agent-discipline.md`；
- `working/doc-conventions.md`、`working/check-docs.py`、现有 qoder 评审；
- luna 原 `sunmoonai-architecture/baseline/` 的平台、App 公共形态与五仓投影。

本轮实际执行了当前 `check-docs.py` 的无仓检查和 `--repos` 检查。

边界：opus 工作树的 App 子模块未初始化（`git submodule status` 为 `-<sha>`），因此本轮
**没有重新逐文件审计四个 App 的当前子模块源码，也没有连接集群**。本文对具体实现事实的
意见，主要针对文档内部是否自洽、断言是否越过它自己声明的取证边界；平台与领域边界建议
同时来自此前对五仓的开发和基线取证经验。

## 1. 结论

**赞成以 Opus 当前结构作为最终投影骨架，不赞成恢复 luna 旧结构作为第二套基线。**

Opus 已经做对了最重要的改变：把“现状投影”“强制约束”“开发计划”“协作机制”分开，
并主动记录未接线能力。它比旧 baseline 更适合作为新人和智能体的工作入口。

但当前版本还不能直接宣告收口。建议先处理 A 组四项：其中 A1 是已经发生的正文漂移，
A2 是新门禁在常见工作树形态下不可用，A3/A4 关系到整套投影最核心的语义边界。
B 组是建议吸收的架构信息和表达调整。

## 2. A 组：建议收口前处理

### A1. 聚合页已经与仓投影、专题页互相矛盾

这不是代码与文档的潜在漂移，而是**当前文档集内部已经能直接证明的矛盾**。

#### A1.1 Knowledge `CANCEL` 风险仍留在总览

`overall-architecture.md` §9.3 仍断言：RAGFlow `CANCEL` 被当作成功。
但 `repos/knowledge-app.md` §7 已不再把它列为风险，§8 反而明确写着：

> `CANCEL` 必须抛错，并有 `cancelled` 回归测试。

两者不能同时代表当前事实。若 O 系列修改已经修复代码，应从总览删除旧风险；若尚未修复，
则仓投影和测试说明必须改回真实状态。不能靠日期排序解决，因为两页取证时点相同。

复核：

```bash
sed -n '/### 9.3/,/### 9.4/p' project-guide/overall-architecture.md
sed -n '/## 7\./,$p' project-guide/repos/knowledge-app.md
```

#### A1.2 发布专题中的“版本矛盾”在表内已经不存在

`topics/release.md` §7 的两行事实都是 `2.0.0` / `FORMAL_RELEASE`，正文却仍写：

- “代码层被钉死为候选版本”；
- “两者取值互相矛盾”；
- “测试阻止代码层追平部署层”。

按该表自身内容，代码层已经追平。这里显然是 O1 修值后留下的旧结论。建议删除整节；若真正
想表达“已发布 digest 对应的旧镜像内仍是 `2.0.0.dev0`”，应只在版本真源附近陈述，并明确
这是“已发布制品与当前源码”的差异，不是“当前代码与 release manifest”的差异。

复核：

```bash
sed -n '/## 7\. ⚠/,/$p' project-guide/topics/release.md
sed -n '/### 9.1/,/### 9.2/p' project-guide/overall-architecture.md
```

#### A1.3 README 指向不存在的章节

`project-guide/README.md` 的“写作约定”仍指向 `governance.md §4` 和“编辑自检 §5”，
但当前 `governance.md` 只有 §1–§3。相关内容实际已经移动到
`working/doc-conventions.md` §3/§4。

这是普通 Markdown 坏链检查发现不了的**语义坏链**。建议改为直接指向
`../working/doc-conventions.md`，并给 `check-docs.py` 增加轻量的同文件章节锚点检查，
或者以后统一使用可解析的 Markdown heading fragment。

复核：

```bash
grep -n '^## ' project-guide/governance.md
sed -n '/## 写作约定/,/## 本轮/p' project-guide/README.md
```

### A2. `check-docs.py --repos` 把“无法扫描”误报为“路径不存在”

在当前 opus 工作树执行：

```bash
python3 k8s/sunmoonai/docs/working/check-docs.py --repos /home/zymun/worktrees/opus
```

会报 75 个硬失败；例如 `app/bootstrap/api.py`、`core/config.py`、
`tests/test_kernel_invariants.py` 均被判为不存在。原因不是这些引用已被证明错误，而是四个 App
父仓的子模块未初始化，`git ls-files --recurse-submodules` 只返回父仓文件。脚本既不检查
subprocess return code，也不检查 `git submodule status` 的 `-` 状态，于是把取证前置条件失败
翻译成正文失败。

无 `--repos` 时又会输出“全部通过”，因此目前存在两个都容易误读的结果：

- 不给 `--repos`：根本没检查代码路径，却显示全部通过；
- 给未初始化的 `--repos`：无法扫描源码，却声称 75 条路径不存在。

建议二选一：

1. 检测到未初始化子模块或 `ls-files` 非零时，立即以一条明确的“取证前置条件不满足”失败，
   不生成路径级误报；
2. 支持显式传入已经初始化的五仓父目录，并在输出中打印实际扫描的仓和文件数。

验收至少覆盖三种 fixture：完整初始化、子模块未初始化、缺少某一父仓。任何一种都不得静默
降级。提交说明里“当前 99 处引用全部命中”也应附实际使用的 repos 根，避免把某台机器的
布局当作脚本通用性。

### A3. “现状投影”中仍混入无法从代码推出的意图和未来决策

`overall-architecture.md` §9.2 对共享 Outbox 和 Celery beat 写道：

- “这是有意的”；
- “没有业务需要之前接上去等于凭空增加维护面”；
- “第一个跨 App 异步事件/定时任务落地时重新审视”。

代码只能证明“原语存在、业务零调用”和“Scheduler 存在、无 schedule”；代码本身不能证明
用户为何这样决定，也不能授权未来在哪个触发点重新评审。这些话属于 ADR、请求或开发计划，
与 `doc-conventions.md` 的“只从代码重写现状投影”相冲突。

建议现状页只保留中性事实：

> 模板提供该原语，当前无生产调用/调度定义；不构成已上线能力。

若“有意留白”确实是用户决策，把理由和触发条件移入 `dev-plan/` 或可追加的决策载体，再由
投影给一句指针。不要让投影作者替项目所有者补写意图。

同理，README 的“O1–O10、十项缺口全部了结”和总览的 CLAUDE.md 修复经过属于本轮过程，
不应长期留在“只反映当前有效事实”的正文。当前事实可以写成“组件级助手指令仅保存局部规则
并指向本集”；修复史交给 Git 与 merge-review。

### A4. 运行态措辞越过了本集自陈的验证边界

README 明确写着“未连集群，本文档集不断言运行态”，但总览 §9.1 写“当前运行中的镜像内部
仍报 `2.0.0.dev0`”。未连集群时，最多能从发布 evidence、镜像构建时点和 Dockerfile 推断
某个**已发布 digest 对应的制品**包含什么，不能断言它当前正在运行。

建议改成下列二者之一：

- 有镜像制品证据：写“R7 锁定 digest 对应的镜像制品预计/经离线检查报告……”并给真源；
- 没有镜像检查：只写“源码已更新但未为此次版本改动重建，下一次构建才会带入新版本”。

“当前运行”只留给 `kubectl` 或运行态证据。

## 3. B 组：建议吸收的架构补充与结构调整

### B1. 恢复一张真正的“全平台依赖图”，但不要恢复旧 baseline 全文

当前总览对三个领域 App 的请求链、数据链和发布链表达得很好；对 `k8s/sunmoonai/` 的八个
平台目录则主要是清单，缺少平台间依赖方向。作为“总体架构唯一入口”，读者还应一眼看懂：

```text
Ingress -> App -> Data / Messaging / Auth
CI/CD -> build and release artifacts
Ops -> observe/administer Data, Messaging and App
infrastructure / kind-infrastructure -> cluster foundation
deploy-sunmoonai-all -> deployment orchestration only
```

尤其应保留旧 luna 基线中两个长期有效的判断：

1. **部署顺序不等于运行时耦合**；
2. **CI/CD 与 Ops 不应成为已发布业务的同步关键依赖**。

建议只把这张小图和两句边界吸收到总览 §4 或 `repos/k8s.md`，不要搬回旧文中的版本、组件参数、
环境快照和长篇目标态描述。

### B2. “五个 Git 仓”应改成“五个顶层协作仓”

总览先说“五个 Git 仓”，随后又说四个 App 仓各含三个 Git 子模块。严格说项目不只有五个
Git repository；五个是必须并列放置的**顶层父仓/协作仓**，其中四个父仓再通过 gitlink
引用组件仓。

这个差别不是措辞洁癖，它直接关系到：

- 子仓先推、父仓后更新 gitlink；
- 为什么一个工作树可以出现“父仓在、组件源码未初始化”；
- 门禁锁的是父仓、组件 commit 还是二者。

建议总览统一使用“五个顶层协作仓”，在标准 App 结构处明确“backend/admin/web 是 Git
子模块”。

### B3. “完全相同”改成“共享同一正式骨架”

总览两次用“完全一致/完全相同”描述四个 App。实际应该表达的是：它们共享模板规定的父仓
拓扑、四运行角色、安全边界和发布脚手架；领域目录、路由、迁移、依赖和允许差异并不相同。

建议改为：

> 四个 App 共享同一正式模板骨架；实例在受控的领域扩展点上分化。

并指向模板同步/漂移门禁。这样既保留同构性，也不会让开发者误以为实例差异本身就是违规。

### B4. 契约应明确分成“两套跨 App + 一套同 App 共享契约”

`topics/contracts.md` 标题是“跨 App 契约”，§1 却列三套并立契约；表格自己又承认
web-interaction v1 是“同 App 内后端 ↔ Web 前端”，不是跨 App。

建议在标题或首段直接给出分类：

- 跨 App：artifact v1、retrieval v1；
- 模板共享、各实例 App 内消费：web-interaction v1。

这能避免读者误认为 web-interaction 有一个跨四仓运行时 provider，也能解释为什么它有完整
DTO/向量却仍可在每个实例中独立未接线。

### B5. 引入最小“能力状态词典”，代替“文件存在 = 能力完成”的二元判断

Opus 已经通过“已知未实现”解决了一半问题，建议再向前一步，在总览只定义一次四级状态：

| 状态 | 含义 |
| --- | --- |
| defined | schema、DTO、Port 或表已经存在 |
| wired | 有生产调用方/适配器，主链可达 |
| deployable | 配置、Secret、profile 与门禁允许部署 |
| runtime-verified | 有对应环境的运行态证据 |

不要求给全项目每个功能做大矩阵，只给最容易误读的能力标状态。例如：web-interaction 是
defined/not wired；共享 Outbox 是 defined/not wired；info delivery outbox 是 wired；C1 profile
disabled 则不是 deployable；未连集群的项目不能标 runtime-verified。

这样“契约齐全 ≠ 链路已通”会从一条警告升级为全套文档可复用的语言。

### B6. auth-app 的表述应区分“未受 App bundle 门禁”与“无需不可变制品治理”

总览和身份专题现在的推导是：auth-app 由 Helm 部署、没有 `release.json`，**因此不受 digest
纪律约束**。前半句是机制事实，后半句容易被读成架构豁免。

更准确的表达应是：

> auth-app 不进入三个领域 App 的 bundle/release.json 门禁；其 chart/version/image 固定与晋级
> 由 auth-app 自己的 Helm 发布链负责。若当前仍使用可变 tag，应明确列为未覆盖风险，而不是
> 从“没有 bundle”推出“无需 digest”。

### B7. 继续压缩总览与仓/主题页的重复

当前 `overall-architecture.md` 已重复不少 `repos/` 和 `topics/` 的易变细节：精确版本口径、
9/9 数量、四仓共同缺口、单仓具体缺口、配置校验数量等。总览应负责：

- 系统边界和五个顶层协作仓；
- 平台与领域依赖方向；
- 三条主链；
- 能力状态语言；
- 去哪查真源。

具体缺口只在对应仓页维护；跨仓共同缺口只在对应 topic 维护。总览用一句摘要和链接，不再复制
表格。否则总览必然再次出现 A1 这种“仓页已修、聚合页仍旧”的漂移。

### B8. 从旧 luna 基线吸收“为什么”，拒绝吸收“快照值”

建议保留或补回的解释性内容只有四类：

- Admin/Web 为什么仍是两个独立安全边界；
- 统一 Backend 为什么不等于取消接口、身份和权限分面；
- 共享物理数据库为什么不改变领域数据所有权；
- 平台部署顺序为什么不构成运行时可靠性。

明确不应吸收：旧 baseline 中的 commit、digest、迁移 head、文件行数、依赖小版本、固定
release_id、精确文件数量，以及“目标态已经实现”的措辞。这些正是旧投影最容易制造虚假完整感
和后续漂移的部分。

## 4. 对当前结构的最终建议

建议最终权威关系保持为：

```text
代码与机器真源                         当前事实
        ^
dev-plan/constraints.md               必须达到的规则
        ^
project-guide/                         代码现状的可丢弃投影

working/                               协作过程与维护方法
dev-plan/development-plan + handoff    将来工作与当前施工入口
merge-review/                          临时评审材料，闭环后删除
```

这里不建议再增加一个长期“architecture principles”权威目录。真正需要保留的设计理由：

- 能机械表达的，进入 constraints；
- 是重大取舍且需要历史语境的，进入可追加决策记录；
- 只是帮助理解当前代码的，放在 project-guide 对应事实旁边。

关键是不要重新制造“现状 baseline”和“目标 architecture”两套都看起来权威的正文。

## 5. 验收标准

| # | 判定 |
| --- | --- |
| 1 | 总览与 knowledge 仓页对 `CANCEL` 的结论一致，并能由测试或代码复核 |
| 2 | `topics/release.md` 不再出现“两边都是 2.0.0 却互称矛盾”的段落 |
| 3 | README 不再引用不存在的 `governance.md §4/§5` |
| 4 | `check-docs.py --repos` 遇未初始化/缺失仓时明确报告前置条件，不生成路径级误报 |
| 5 | 现状投影中的“有意如此/未来何时重审”均有决策真源指针，否则改为中性事实 |
| 6 | 未连接集群时不使用“当前运行中”措辞 |
| 7 | 总览使用“五个顶层协作仓”，不再把项目仓库总数写成五个 Git repo |
| 8 | 契约分类明确为“两套跨 App + 一套同 App 共享契约” |
| 9 | auth-app 只声明“不受 App bundle 门禁”，不把它扩大成不可变镜像治理豁免 |
| 10 | 平台依赖图或等价文字明确“部署顺序不等于运行时耦合” |
| 11 | 每条意见都有接受/部分接受/拒绝及理由；吸收后回跑本表并留处置记录 |

## 6. 一句话意见

**Opus 的方向是对的：它应成为唯一最终投影；本轮需要做的不是把 luna 旧基线合回来，而是用
旧基线中仍有效的架构解释补足“为什么”，同时用 Opus 自己制定的取证纪律清掉当前已经出现的
聚合漂移、意图越界和工具误报。**
