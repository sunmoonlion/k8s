# 最终评审：`refact-fable.md`

> 日期：2026-09-05  
> 评审者：luna  
> 评审对象：`refact-fable.md` 12:15 最终稿  
> 对象 SHA-256：`45c10e50e59d542a1f4f40ae7f09d5ad2969d175994e858bbfc0373ef6907214`  
> 结论：**方向通过，冻结前仍须修改（REQUEST CHANGES）**。

## 1. 总体判断

最终稿已经实质吸收前轮意见：

- 「一套 Task / Attempt 状态机，场景差异进入 Profile」已经贯彻到映射表、工单与验收标准；
- 工单降为 Artifact，`ACTIVE / DONE / ABORTED` 不再与 Task 状态竞争；
- router、orchestrator、arbiter、acceptor、approver 的职责基本拆开；
- 权力表补了 principal、强制点、取消和扩权；
- 工作区供给补了独占、干净、基线、多仓条件；
- 文档迁移改为全标题清单，行数降为观察值；
- 签名回执不再假定本地 Git/GPG 是信任边界。

这些改动已经让总体架构成立。本稿剩余问题主要集中在**回执仓的 Git 对象模型、真正的强制边界、状态可观测性和几处正文自相矛盾**。以下 C1–C6 在冻结 §8 前应处理。

---

## 2. 阻断冻结的问题

### C1：回执仓的 annotated tag 方案按文中命令不能成立

**位置**：§3.13.2–§3.13.4，尤其是「回执仓不需要含工作仓历史」与以下命令：

```text
git tag -s confirm/<id> <工作仓 commit>
git push receipts confirm/<id>
```

**为什么错**：Git tag 不是一个只保存任意哈希字符串的外部引用。annotated tag 指向 Git object；正常 `push` 会把被指向的 commit 及其可达历史一并传到目标仓。因此：

1. 从工作仓向空回执仓推该 tag，会把工作仓 commit/历史复制进回执仓；
2. `git ls-remote receipts refs/tags/confirm/<id>` 返回的是 **tag object OID**，不是 tag message；
3. 加 `^{}` 可以取得 peeled commit OID，但仍读不到 `receipt / transition / acceptance` 内容；
4. VM 若要解析 tag message，必须 fetch tag object；该 tag 又依赖工作仓 commit，不是文中描述的「回执仓只存 tag」。

**可复跑证据**：

```bash
tmp=$(mktemp -d)
git init -q "$tmp/work"
git init -q --bare "$tmp/receipts.git"
git -C "$tmp/work" -c user.name=x -c user.email=x@y commit --allow-empty -q -m baseline
oid=$(git -C "$tmp/work" rev-parse HEAD)
git -C "$tmp/work" -c user.name=x -c user.email=x@y tag -a confirm/demo "$oid" -m 'receipt: 1'
git -C "$tmp/work" push -q "$tmp/receipts.git" refs/tags/confirm/demo
git -C "$tmp/receipts.git" cat-file -t "$oid"     # 输出 commit，证明目标对象也被复制
git ls-remote "$tmp/receipts.git" 'refs/tags/confirm/demo*'
# 第一行是 tag OID，第二行 ^{} 才是 peeled commit OID；两者都不含 message
```

**应当是什么**：回执仓保存自己的 receipt object，而不是让 tag 跨仓指向工作仓 commit。推荐形状：

```text
receipt 仓中的一条签名 commit（或签名 tag 指向 receipt 仓自己的 commit）
└── receipt.yaml
    receipt_version
    work_repo_id / canonical_remote
    round
    transition
    target_commit                 # 普通字段，不是跨仓对象引用
    work_order_digest
    ruling_sha256
    policy_version
    expires
    acceptance
```

VM 只读 fetch 这条 receipt commit/tag，验证签名与 schema，再用 `target_commit` 字段对照本地工作仓。这样回执仓不会复制工作仓历史，message/schema 也真正可读取。

此项会连带修改 S1、R1 与 §8 第 6 条的验收命令。

### C2：回执仓防住了伪造回执，但没有强制阻止未经批准的主线 push

**位置**：§3.3 H5、§3.13.1–§3.13.2。

最终稿已取证：VM 上的工作仓凭据具有写权限。H5 的 `enforcement_point` 却是「主线 push hook 校验回执仓」。本地 hook 可以被改、删、跳过；Agent 也可以不用 orchestrator，直接执行 Git push。因此回执仓只能证明“有没有合规回执”，不能阻止“没有回执也发生 Side Effect”。

这与 §3.3「没有强制点的行不许进表」冲突。当前 H5 实际是审计点，不是强制点。

**应当是什么**：至少选择一种真正位于 Agent 权限边界之外的发布门：

- VM/Agent 只允许推到 fork 或候选仓，所有者机器持有唯一的主仓写权限；或
- 独立的 receive gateway/发布服务持主仓写凭据，收到有效 receipt 后才代推；或
- 托管端 protected branch/ruleset/pre-receive 强制。

若当前条件下做不到，应把 H5 明写为“可审计但不可强制”，不得用 `enforcement_point` 或“不可伪造”描述完整发布边界。最简单且与回执仓一致的 A 档，是**VM 不再持主仓写权限，只写候选 fork；Windows 在签回执后完成主仓 push**。

### C3：H7 是否需要仓外签名，修订记录、正文和验收标准互相矛盾

**位置**：

- 修订记录 12:15：写明「所有 `auto_policy = 无` 的行一律回执仓签名 tag（H7 取消例外）」；
- §3.3 H7：仍写“表内唯一例外，不要求仓外锚”；
- §3.3 统一规则开头：写“凡 `auto_policy = 无` 一律签名”，随后正文又排除 H7；
- §3.13.3 schema：写“H7 不进回执仓”；
- §8 第 6 条：再次写“H7 除外”。

**应当是什么**：冻结前只保留一个结论。按 12:15 的“所有者裁定”字面，应删除 H7 全部例外，让 H7 也使用签名 receipt；如果最终仍决定失败安全方向可例外，则必须改修订记录，不能把相反裁定留在文首。

### C4：T2 开工前不是“恰好一次触点”，正文明确要求 H1 与 H2 分开

**位置**：§3.6 与 §8 第 5 条。

§3.6 明确说：

- T1 的 H1 + H2 可以一签两用；
- T2 必须先单独 H1 冻结验收标准，再单独 H2 确认参赛者与开工。

因此 T2 在开工前有两个 APPROVAL Interaction/触点。§8 第 5 条却要求“T1/T2 恰好一次（H2）”，机械验收必然与正文冲突。

**应当是什么**：改成：

```text
T0：开工前 0 次（H1 由已签策略承担，H2 自动策略放行）
T1：开工前 1 次（H1+H2 合并 receipt）
T2：开工前 2 次（H1 与 H2 分离）
```

如果产品目标坚持 T2 也只触达一次，就不能再要求“参赛者名单在 H1 后确定”；需要在同一份冻结 receipt 中同时确定验收条和角色。

### C5：仅从现有 Git 产物无法区分 Attempt `CREATED / RUNNING / 卡死`

**位置**：§3.1.1、§3.8、§3.10。

映射表以 `call-<环节>.md` 推导 `QUEUED + Attempt CREATED`，以交付 commit 推导 `COMPLETED`，但中间没有任何权威产物证明 CLI 何时真正开始、是否仍运行、是否崩溃。缺交付可能同时表示：

- 尚未调用；
- 已调用正在运行；
- 进程退出但没有产物；
- 机器失联；
- 观察窗已超时。

因此 `round-status.py` 无法按 P2 可靠推导 `RUNNING`，也无法满足产品内核对 RUNNING“至少一个有效 Attempt 正在推进”的语义。§3.11 又明确承认 Git 载体没有租约；这不是仅少一个并发保证，而是当前 `RUNNING` 判据缺失。

**应当是什么**：开发 adapter 至少落下结构化执行事件：

```text
attempt-created
attempt-dispatched
attempt-started
attempt-finished | attempt-timeout | attempt-cancelled
```

每项带 `attempt_id / actor / input_commit / timestamp / observation_window`，由 orchestrator 单写。若不准备实现可判的 started/liveness，则开发 Profile 不应声称已经可精确反推 RUNNING；应在覆盖声明中明确此状态为不可判，而 §8 不能要求完整状态推导已经成立。

另一个语义问题也应同时裁定：内核 Attempt 是“一次为完成 Task 发起的执行”，而映射表把提案、互评、裁决、验收各家的每次交付全部叫 Attempt。评审/验收并不都产生用户候选结果。可选解法有二：

1. 每个环节建为有自己 Profile 的 child Task，CLI 调用才是该 child Task 的 Attempt；或
2. 正式扩充内核 Attempt 定义，使其可以产出 typed intermediate Artifact，而不只表示候选结果。

不能只在开发 Profile 中静默改变 Attempt 的语义。

### C6：当前环境事实已经与 §3.13.1 的取证结论不一致

**位置**：§3.13.1、§3.13.2 B 档。

最终稿记录“本 VM 所有进程都是 root”“`/home/zym` 属 root:root”。本轮复核结果是：

```text
$ id
uid=1003(zym) gid=1003(zym) groups=1003(zym),65534(nogroup)

$ stat -c '%U:%G %a %n' /home/zym /home/zym/.ssh
zym:zym 750 /home/zym
zym:zym 700 /home/zym/.ssh

$ ps -eo user=,comm= | rg 'codex'
zym      codex
```

底层安全结论仍大致成立——Agent 与人的 VM shell 同属 `zym`，所以本地私钥仍不是边界——但“全 root”的事实、B 档成本和凭据检查前提已经过期或取证环境不一致。

**应当是什么**：冻结前重新注明取证主机、执行身份和时间；S1 使用与生产 Agent 完全相同的 OS 用户/容器身份复跑权限测试。安全边界应写成“Agent 与人是否共享 credential domain”，不要绑定“必须是 root”这个偶然事实。

---

## 3. 应在实现前澄清的设计问题

### D1：路由建议与最终工单字段需要分开

§3.5 的 `decide` 会产生 `tier / executors / workspace_plan`；§3.4 又要求 T1/T2 的 `tier` 和 executors 留空、由人显式填写。现在同一个 `route_decision` 字段同时像“机器建议”又像“最终决定”。

建议工单明确区分：

```text
route_proposal     # 模型证据 + 确定性规则输出
route_effective    # 自动策略或 H2 receipt 确认后的值
route_delta        # 人相对建议修改了什么
```

否则 H2 后无法判断哪些字段是人明确选择、哪些只是沿用了建议。

### D2：T2 的出题者需要成为显式角色

T2 要求验收标准在参赛者看到题目前冻结，但当前工单的 `intent_restatement / acceptance` 必须先有人起草。如果由某个 Agent 起草，它已经看过题目并参与了“出题”，随后是否可以当 proposer、arbiter、acceptor 没有规则。

建议增加 `intake_author`（不一定成为长期执行角色），并机械禁止它在同票中担任 proposer/arbiter/acceptor；或者规定 T2 的题目与验收条只能由 owner 直接提供。

### D3：`independence` 的字段值与折算算法不匹配

示例把多家都登记为 `independence = "cross-vendor"`，算法却按“不同 independence 组的个数”计票。若按字段字面分组，所有 cross-vendor 执行者反而都落在同一组，只算一票。

建议拆成：

```toml
independence_group = "openai/codex/<model-family>"
provider           = "openai"
runtime            = "codex-cli"
```

“cross-vendor”是两个执行者之间的关系或算法结论，不应作为所有成员共享的组名。引用过其他候选后，可在本票的 evidence graph 中把对应主张关联起来，不修改静态登记身份。

### D4：状态集合验收应比较 schema，不应扫描正文词汇

§8 第 4 条若按文档文本做状态词对称差，会被历史说明、反例、Artifact 状态或代码示例干扰；反过来，也可能因为正文偶然提到某个词就误判“已实现”。

建议唯一状态与合法边生成一份机器可读 schema，例如：

```toml
[task]
states = [...]
edges = [...]

[attempt]
states = [...]
edges = [...]
```

产品与开发 adapter 都读它；文档只校验链接/生成片段未漂移。验收比较的是声明 schema 与实现表，不是全文 `rg` 命中。

### D5：禁止同义词的正则门禁会制造误报，不能证明职责已经消歧

§5.1 准备禁止 `supervisor / coordinator / organizer / dispatcher / integrator` 等词，但同一棵文件树仍有 `round-dispatch.py`，正文也需要引用历史术语和通用架构概念。禁词只能逼出新的绕词，不能机械证明职责唯一。

建议门禁真正检查：

- `agents.toml.roles_allowed` 只能取已注册角色；
- router/orchestrator 不得出现在 Agent 角色集合；
- 每个流程动作只能有一个 owner/enforcement point；
- 旧术语只在 glossary/historical context 中允许。

不要禁止 `dispatcher` 这类本身合法的组件词。

---

## 4. 建议处置顺序

1. 先修 C3、C4 两个纯正文矛盾，避免冻结相反规则；
2. 把 S1 改成验证“receipt manifest 仓”，解决 C1；
3. 同时裁定主仓发布权，解决 C2，否则 S1 只能证明回执不可伪造，不能证明 H5 被强制；
4. 重新取证实际 OS 身份与 credential domain，修 C6；
5. 在 R1 前冻结 Attempt 事件/状态推导方案，解决 C5；
6. 将 D1–D4 落入工单 schema、执行者登记表与机器状态 schema；
7. 再冻结 §8 并启动 bootstrap。

## 5. 最终结论

我赞成最终稿的主轴，也赞成继续推进实施；但当前不建议冻结 §8。最主要的原因不是理念分歧，而是两条关键机械保证尚未闭合：

1. 文中给出的跨仓 tag 命令不能实现它所描述的 receipt object；
2. Agent 仍持主仓写权限时，回执仓与本地 hook 不能强制 H5。

将回执改为**回执仓自己的签名 manifest**，并把**主仓写权限移出 Agent credential domain**后，签名回执这条线才真正闭环。再修掉 H7、T2 触点和 RUNNING 推导三处矛盾，本方案即可进入冻结与 bootstrap。
