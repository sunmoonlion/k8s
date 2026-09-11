参与方：luna｜worktree：/home/zym/worktrees/luna/k8s｜HEAD：dfaeb8d57d0557e3cc435527fcc1718c44fbef4f
# runtime 轮 ② 互评：luna

> 利益冲突声明：我是 luna 候选的作者，同时评审全部五份候选。下文对自己的缺口使用与别家相同的
> 冻结标准；排序把自己列第一，但明确列出其未覆盖的人类冻结动作与历史 trace 推导缺口。

## A. 自述

### A1. 自己的候选做了什么

luna 候选相对基线只新增共享候选文件，主要内容是：

- 把开发落为 `dev.change.v1` Task Profile，把五家落为五个 Agent Profile；
- 用四序列 + `TraceEnvelope` 定义等效，避免忽略授权策略和 Side Effect；
- 给 Interaction 定义出向 Artifact 引用、renderer、editable scope 与三值响应，并给出不伪造旧响应语义的迁移；
- 用 E0–E4 区分自报、重推导、进程观察、工具观察与外部权威；
- 用独立 sink 的分母计算 bypass，而不是让运行时账本自证完整。

候选没有基座正文可改，所以是新建文件；结构分为对象/Task Profile、trace、Interaction、
Agent Profile/证据、必答 Q、OP 表态与盲区。

### A2. 分歧、未验证与故意放弃

- 与 OP-1 分歧：四序列是必要条件，不是充分条件；授权、契约和 Side Effect 放在比较 envelope。
- 与 OP-2 分歧：amend 正文属于 Artifact，Interaction 保存引用和消费关系。
- 与 OP-3 分歧：绕过的分母必须来自运行时之外，允许结论为 `UNKNOWN`。
- 未验证：历史 `refact-fable` 没有逐版 commit、Attempt started Event 或 state_version；候选将这些标成 GAP。
- 未验证：CLI 的外层 OS 隔离尚未做拒绝实验，实际未启用时只能登记为 convention。
- 故意不写：文件树、实施路线重排、protocol-v2 待决与 pipeline-task；它们均不在本轮范围。
- 故意不把旧 token 消费回填成 approve/reject；历史只可标 `legacy_resume`。

### A3. 自评发现的新缺口

luna 候选 `1ddff5c2:runtime-architecture.md:91-110` 的权力表没有单列“冻结题目与验收标准”；
`AUTH-CONTRACT` 只覆盖补充/修订，不能证明最终 freeze。并且 `AUTH-CANCEL` 写“任一非终态 → CANCELLED”，
不是单独一条边。故 §8-2 只能判“部分满足”，不能用 `:520-529` 的自检表代替事实。

另一个文字边界在 `:105`：`AUTH-BUDGET` 写“追加预算或执行范围”。授权范围改变按
`request-lifecycle.md@70a7dd50:292-301` 应建新 Task；最终稿应把它收窄为“冻结授权范围内的预算/资源额度”。

## B. 候选集冻结

五份均从通知钉定的 commit 取件；没有读取任何分支工作区。

| 候选 | worktree | commit | 行数 | 字节数 | SHA-256 |
| --- | --- | --- | ---: | ---: | --- |
| luna | `/home/zym/worktrees/luna/k8s` | `1ddff5c26c55c2be0e00ae56587f267add5f9534` | 544 | 32955 | `03785aabb3a631f68a3cd499eefdeb44b5a479b67a5fff38e9b88c4123fb49bf` |
| kimi | `/home/zym/worktrees/kimi/k8s` | `29b4f804bda7be6c60b760b4502095b55288aba7` | 538 | 39376 | `f0226bffd75170854c364f26dde68791d7d31bb33693dd0aca8d0ec075dc4544` |
| cursor | `/home/zym/worktrees/cursor/k8s` | `13f3d52bc0d6b225e5a9a0bab33ee97329c5199b` | 586 | 38613 | `5ba7ce8b14775aeb60da7af146dc8f2ff1ce2436dfded5cd18e62b216ea8be76` |
| fable | `/home/zym/worktrees/fable/k8s` | `f053bd84e1569b9c352e71c966ed8c9d76a6271e` | 646 | 59897 | `b9bd7800cdcbcb059967abd2e43fdf97e7954249fe5e2c1e89db344279a30276` |
| qwen | `/home/zym/worktrees/qwen/k8s` | `1ae5b4208a6aaf7531e6435bbe0faecc25022e24` | 441 | 21202 | `49380ab0427d8ad8904fc47522c8a1f8e2528912a8d82fa22cffd2c911ff2291` |

复跑命令：

```bash
git show <commit>:sunmoonai/docs/dev-plan/runtime-architecture.md | wc -l -c
git show <commit>:sunmoonai/docs/dev-plan/runtime-architecture.md | sha256sum
git diff --name-only 7e8464c2 <commit> -- \
  sunmoonai/docs/dev-plan/refact-fable.md \
  sunmoonai/docs/dev-plan/working/request-lifecycle.md
```

五家最后一条命令均零输出；禁词与人的禁用 kind 正则也均零命中。

## C. 逐份评审

判定记号：`通过` = 已满足；`部分` = 形状存在但有实质缺口；`不通过` = 缺失、对象不实或直接冲撞冻结条款。

### C1. luna

| §8 | 判定 | 依据 |
| --- | --- | --- |
| 1 | 通过 | `profile_id: dev.change` 在 `1ddff5c2:runtime-architecture.md:47-85`；五家名单在 `:371-382`。 |
| 2 | **部分** | 人作为 principal 且有七行映射（`:91-110`），但缺 freeze 行；cancel 也没有展开成唯一 source edge。 |
| 3 | 通过（带 GAP） | 四序列字段 `:140-180`；真实归档 metadata/trace `:193-274`；全部状态在内核集合内。缺证据状态明确标 GAP。 |
| 4 | 通过 | 字段 `:276-298`、原子路径 `:300-315`、修订边界/影响/迁移 `:317-341` 齐全。 |
| 5 | 通过 | schema 与五家逐项 `:343-385`；自报拒收、运行时重推导 `:387-402`；R2 `:419-433`。 |
| 6 | 通过 | 四问 `:435-497`；一次性解释和 formatter 两个成立的反例 `:459-466`。 |
| 7 | 通过 | OP-1/2/3 均改写且逐条给理由，`:499-516`。 |
| 8 | 通过 | 现状事实使用 commit + file:line 或复跑命令；目标设计与事实分开；盲区 `:537-544`。 |
| 9 | 通过 | 相对 `7e8464c2` 两份只读输入 diff 为零。 |
| 10 | 通过 | 首行名、worktree、HEAD 均匹配通知。 |

可复核指摘：

```bash
git show 1ddff5c2:sunmoonai/docs/dev-plan/runtime-architecture.md | \
  nl -ba | sed -n '91,110p'
```

这里找不到冻结 acceptance contract 的明确动作；最终稿必须加 `AUTH-FREEZE`，并把取消按当前源状态记录具体边。

OP 处理成立：特别是 OP-1 的反例——同形 trace 可能一份获权、一份越权——证明 envelope 不是装饰。
OP-2 把大载荷留在 Artifact，迁移用 `legacy_resume`，比把旧布尔消费解释为批准安全。
OP-3 用独立 sink 分母，覆盖声明最完整。

必答 Q 的反例成立；它准确区分“无需留痕的一次性解释”与有证据/依赖的短问题。

### C2. fable

| §8 | 判定 | 依据 |
| --- | --- | --- |
| 1 | 通过 | `dev.change/1` 与五家完整登记在 `f053bd84:runtime-architecture.md:86-172`。 |
| 2 | **不通过** | `:197` 自己列出“不是任何边 / 行为 —”，却在 `:209` 宣称无缺项；`:180` 又把明确不是权力的传输 H0 塞进权力表且 enforcement 为空。 |
| 3 | 通过 | `:254-324` 是五稿里最完整的真实归档 trace，区分 attested/reported/inferred，并如实承认六版零 commit。 |
| 4 | **部分** | 三值、载荷、新版本、下一 Attempt 与修订工作单元齐；但 `:400` 把旧响应视为 approve，给不存在的历史语义造事实。 |
| 5 | 通过 | `:118-172,408-486` 把 observability/enforcement/sandbox 拆开，五家均填，GUI 极端与 R2 都有落点。 |
| 6 | **部分** | 三类反例本身成立；但 `:493` 断言 fable 在现状下“任何任务”都更贵不成立——固定一次 H0 不会压过任意大的续接/并行收益。 |
| 7 | 通过 | 三项均有实质改写；OP-2 用 `amend.full_content` 保留三值尤其好。 |
| 8 | 通过（有边界） | 现状断言大多有 file:line/源码锚，头部主动声明沙箱/宿主身份；未核项标 ⚠。 |
| 9 | 通过 | 两份只读输入 diff 为零。 |
| 10 | 通过 | 首行匹配 fable worktree。 |

可复核指摘：

```bash
git show f053bd84:sunmoonai/docs/dev-plan/runtime-architecture.md | \
  nl -ba | sed -n '174,210p;390,402p'
git show runtime/protocol:sunmoonai/docs/dev-plan/round-protocol.md | \
  nl -ba | sed -n '188,201p'
```

协议第 197 行已把“送继续”定为可自动传输欠账。fable 将它命名为权力行 H0，会让“谁有权”与“谁暂时代传”
再次同名；正确吸收方式是 `DispatchEvent{mode=human_bridge}`，不进入 authority table。

迁移时，旧 token 只证明 consumed，不能证明 approve。应吸收 luna 的 `legacy_resume` 语义。
此外 `:369` 的整份替代把 `base_version` 设空会丢被替代方案的血缘；应仍保留 `supersedes=subject.version`，
用 `amend.mode=replace` 表示整份替代。

OP 处理整体成立且加分：来源等级、权力行、claimed/attested 作者拆分使 OP-1 可审计；OP-2 证明三值足够；
OP-3 指出成本属于 `(task, orchestrator)`。必答 Q 的三个具体反例均满足门槛，但“任何任务”需收窄为 T0/M0 类。

### C3. cursor

| §8 | 判定 | 依据 |
| --- | --- | --- |
| 1 | 通过 | `DEV_ROUND` 与五个 Agent Profile 在 `13f3d52b:runtime-architecture.md:35-101`。 |
| 2 | **不通过** | `:368-371` 给 H3/H4/H6 写“不改边”，H5 写发布终态边而非人的批准恢复边；不是每次介入的一条唯一边。 |
| 3 | **部分** | 字段与 S/R 两层清楚，真实归档 trace 在 `:384-449`；但 Artifact 六个中间版本无 digest/不可变对象，只能算 reported。 |
| 4 | **不通过** | `:202-251` 明确把 render 移出 Interaction，并把入向改四值；直接冲撞冻结的“出向含渲染、入向三值”。`:281` 还把旧消费解释成 approve。 |
| 5 | 通过 | tool/process/session 三档与五家登记完整，`:288-356`。 |
| 6 | **部分** | 笔误反例成立；但 `:459-476` 用 `tier∈{T1,T2}` 作为“运行时更便宜”的输入，tier 本就是路由结果，形成循环；新增布尔缺省 false 也会 fail-open。 |
| 7 | 通过 | 三项都给出可攻击理由，尤其 S/R 分层与 Q4 外部采样。 |
| 8 | 部分 | 多数有行锚；仍有若干标题式 `file:3.13` 引用而非行号，覆盖不如 luna/fable。 |
| 9 | 通过 | 只读输入 diff 为零。 |
| 10 | 通过 | 首行身份匹配 cursor worktree。 |

可复核指摘：

```bash
git show 13f3d52b:sunmoonai/docs/dev-plan/runtime-architecture.md | \
  nl -ba | sed -n '200,251p;275,283p;358,373p'
```

冻结 §8-4 不允许以架构偏好移走 render，也不允许加第四个 decision。cursor 的“整份替代”需求是对的，
但可落为三值中的 `amend.mode=replace`；render 可同时保留为 Interaction 的 pinned render contract，
Delivery 再决定具体 UI 实现，两者不冲突。

OP-1 的 S(schema)/R(run)+投影 Π 是强主张，值得吸收；它把边补回状态序列，也避免工具 Event 混入人类 Interaction。
OP-2 的问题诊断成立，具体 schema 不满足冻结标准。OP-3 的外部采样成立。
必答 Q 反例成立；分类规则需删除 tier 自指和默认 false。

### C4. kimi

| §8 | 判定 | 依据 |
| --- | --- | --- |
| 1 | 通过 | `profile_id="DEV"` 与五家名单在 `29b4f804:runtime-architecture.md:32-95`。 |
| 2 | **不通过** | H5 把人的批准映射为 `RUNNING→SUCCEEDED`（`:499-521`），实际批准先恢复 `WAITING→QUEUED`；`:523-526` 又把 INPUT/amend 排除在权力行外。 |
| 3 | **不通过** | `:170-210` 声称是 refact-fable trace，却引用 `refact/luna`、`refact/integration`；这些标签属于另一轮，且归档目录没有五家候选。 |
| 4 | 通过（迁移偏薄） | 三值、scope 强制、新 Artifact 输入与 `legacy` 历史标记均有；工作单元影响和迁移仅两步，缺 active-v1 drain/cutover 条件。 |
| 5 | 通过 | 三档与五家逐项 `:305-378,472-489`，R2 明确标 bootstrap-zero。 |
| 6 | 通过 | 一次性问答、目标未定探索两个反例成立；四维上界可数。`est_exchanges` 是自报预测，应用作观察值而非硬授权。 |
| 7 | 通过 | OP-1/2/3 都是实质改写，尤其 editable_scope 必须入向强制。 |
| 8 | 部分 | 有大量行锚，也有 `task.md §6.1`、`refact-fable.md §3.7` 等标题锚，不完全达到 file:line。 |
| 9 | 通过 | 只读输入 diff 为零。 |
| 10 | 通过 | 首行匹配 kimi worktree。 |

可复核指摘：

```bash
git show 29b4f804:sunmoonai/docs/dev-plan/runtime-architecture.md | \
  nl -ba | sed -n '170,210p'
git ls-tree -r --name-only 7e8464c2 \
  sunmoonai/docs/dev-plan/rounds/refact-fable
git for-each-ref 'refs/tags/refact/*' \
  --format='%(refname:short) %(objectname:short)'
```

第二条只列九份 review、response 与 rulings；第三条列出的 `refact/*` 是另一轮，故这不是题目要求的真实 trace。

OP-1 对不同可见粒度取较粗投影、权限归因 bootstrap-zero 的处理成立；OP-2 对 scope 做服务器端强制成立；
OP-3 对不可见范围的质疑成立。反例门槛已满足。

值得保留的独有点：`:116-122` 指出“人 + shell 是 orchestrator”会把触发者与确定性代码再次混名；
最终稿应坚持 orchestrator=代码、人只是触发/通道。

### C5. qwen

| §8 | 判定 | 依据 |
| --- | --- | --- |
| 1 | 通过 | `DEVELOPMENT` 与五家表在 `1ae5b420:runtime-architecture.md:21-93`。 |
| 2 | **不通过** | 没有权力表与逐次介入清单；`:393-395` 只有“全部映射 H1-H7”的声明，声明不是可判产物。 |
| 3 | **不通过** | `:129-162` 给 refact-fable 编出本轮五家 candidate、opus final 及 H1/H2/H5；真实归档没有这些对象。 |
| 4 | **部分** | 必填字段、三值和下一 Attempt 路径齐；但 `:231-236` 给 v1 历史保留 approve/reject 语义，旧 schema 实际只有 consumed 布尔，迁移造义。 |
| 5 | **不通过** | `:82-88` 给 fable 填 `process`，`:278-286` 又承认无 argv/stdout、仅 fs diff；同一 Profile 自相矛盾。 |
| 6 | 通过 | README 笔误反例成立，三维上界可数，绕过方案至少承认账外盲区。 |
| 7 | 通过 | 三项均表态；OP-2 对轻/重 Interaction 分型有价值，但不能据此取消冻结字段。 |
| 8 | 部分 | 有行号，也有 `refact-fable.md:3.13` 这类章节伪装成行号；“现状均有锚”声明过强。 |
| 9 | 通过 | 只读输入 diff 为零。 |
| 10 | 通过 | 首行匹配 qwen worktree。 |

可复核指摘：

```bash
git show 1ae5b420:sunmoonai/docs/dev-plan/runtime-architecture.md | \
  nl -ba | sed -n '80,95p;129,165p;225,236p;278,287p'
git ls-tree -r --name-only 7e8464c2 \
  sunmoonai/docs/dev-plan/rounds/refact-fable
```

真实归档只有九份评审、fable response 和 rulings；qwen trace 的五家 candidate 是把本轮形状倒灌到历史，
不能作为 §8-3 的证据。

OP-1 只加静态检查，攻击力度较弱；OP-2 指出轻量 INPUT 不应强制大正文是好点，但 Artifact 引用可空即可，
无需另造会漂移的平行 schema；OP-3 复合向量成立。必答 Q 反例成立。

## D. 评优与吸收建议

### D1. 排序

1. **luna**：十条中八条完整通过、两条有诚实边界，其中 Interaction 迁移、Evidence authority 与外部 bypass 分母最安全。
   排第一不是因为作者相同，而是其核心缺口可局部补一行/收窄一词，不需要推翻数据模型。
2. **fable**：历史 trace 与 P3 最强，来源等级尤其关键；但 H0 污染 authority table、旧响应造 approve、全称成本断言必须修。
3. **cursor**：S/R 两层和 session 粒度很强；然而明确移走 render、增加第四值，直接不满足冻结 §8-4，不能原样作基座。
4. **kimi**：覆盖完整、OP 攻击有效；但核心验收 trace 混入另一个 round，§8-3 是硬失败，且人的批准边映射错误。
5. **qwen**：表达简洁且 Q 完整；但历史 trace 是虚构形状、fable 粒度自相矛盾、人的介入只有声明，三项核心标准失败。

若裁决方以 fable 为基座也可成立，但必须先删除 H0 权力行、修 legacy migration 和全称成本断言；
这三处改动大于在 luna 上补 freeze/边映射。因此推荐以 luna 为基座。

### D2. 值得吸收的具体主张

| 出处 | 位置 | 主张 | 吸收方式 |
| --- | --- | --- | --- |
| fable | `f053bd84:runtime-architecture.md:254-324` | trace 每条带 attested/reported/inferred，作者拆 claimed/attested | 并入 luna TracePoint；不要把来源等级在比较前无痕丢掉，报告最低可声明等级与 attested 计数 |
| fable | `:410-448` | observability、enforcement、sandbox 是三个轴；tool.reported 只作索引 | 替换 luna 单一粒度上限公式，保留 E0–E4 作为证据等级 |
| fable | `:587-595` | 登记表字段 `runtime` 与产品运行时同词多义，改名 `harness` | 作为命名修订建议；不在本轮直接改文件树/协议 |
| cursor | `13f3d52b:runtime-architecture.md:126-178` | schema 层与 run 层分开，中间投影 Π；边必须进入状态序列 | 并入等效算法，和 luna TraceEnvelope 组合 |
| cursor | `:295-319` | GUI 比 process 更粗，需 session/fs-only 档 | 采用 fable 的 `fs-only` 名称；不得把 GUI 填 process |
| kimi | `29b4f804:runtime-architecture.md:116-122` | orchestrator 只能指确定性代码，人是触发通道 | 并入术语约束，避免新同名物 |
| kimi | `:245-275,455-463` | editable scope 是服务器端入向约束；stale state_version 和 supersedes 必须校验 | 并入 Interaction v2 验收用例 |
| qwen | `1ae5b420:runtime-architecture.md:368-375` | 轻量 INPUT 不应被迫存大正文 | 将 Artifact/ref/render/editable 做按 class 条件必填，但仍共用一个 Interaction schema |
| luna | `1ddff5c2:runtime-architecture.md:178-191` | TraceEnvelope 防止同形越权的假等效 | 作为 OP-1 必要补强 |
| luna | `:332-341` | 历史 token 只能标 legacy_resume，不能回填决策 | 替换 cursor/fable/qwen 的 synthetic approve 迁移 |
| luna | `:387-433` | E0–E4 + R2 的 `UNVERIFIED` principal channel | 与 fable 三轴合并；当前回执不得称已验证 |
| luna | `:484-497` | bypass 分母取独立 sink，纯本地活动明确不可见 | 作为 Q4 主方案；git commit 对账只是其中一个 sink |

### D3. cursor / fable 独立性观察

可复跑的精确行观察：

```bash
diff --unchanged-line-format='%L' --old-line-format='' --new-line-format='' \
  /tmp/runtime-cursor.md /tmp/runtime-fable.md | sed '/^[[:space:]]*$/d' | wc -l
```

结果为 17；cursor/fable 分别有 438/501 个非空行。排序去重后的精确公共非空行仅 13。
更重要的是实质分歧：cursor 用四值并把 render 放 Delivery（`:202-251`），fable 坚持三值、
以 amend 血缘表达整份替代且把 render 固定在 Interaction（`:340-388`）；cursor 用 S/R+Π，fable 用来源等级与
attested 计数。共同主张主要来自冻结题目（三块、R2、Q4）。

结论：**没有发现可据以折并为同一信号的文本雷同**。这只是精确行与结构差异观察，不证明两套 harness
独立；语义相关性仍是通知所述的未验证项。

### D4. 建议裁决前必须修的四点

1. 人的介入表必须新增 freeze，并把 H3/H4/H5/H6 的“批准动作”映射到实际 WAITING 恢复边；传输 H0 只记 Event，不进权力表。
2. Interaction 保持三值；整份替代用 `amend.mode=replace`，render contract 留在出向绑定；旧布尔响应只标 legacy。
3. 历史 trace 只使用 `7e8464c2` 真正存在的 artifacts；每条带 provenance，缺对象写 GAP，不得借 `refact/*` 或本轮五候选补洞。
4. Q1 删除 `tier` 自指和“任何任务”全称；Q4 以独立 sink 为分母，git 对账作为一个有覆盖边界的实例。
