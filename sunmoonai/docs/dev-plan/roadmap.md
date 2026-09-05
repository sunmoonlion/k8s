# 实施路线与各轮的输入规格

> 迁出自 `refact-fable.md`（`7e8464c2`）§6、§3.6、§3.7。原文已删，历史在 `7e8464c2` 与
> `rounds/refact-fable/` 归档里。
>
> **进度更新（迁出时）**：R0 未做；R0′ 未开；**S1 进行中**——④ `check-no-owner-creds.sh` 与
> ⑤ 宿主取证已完成（`rounds/_spike-sign/forensics.md`），①②③ 待所有者；R1–R5 未开。
> ⚠ 取证给 S1 加了一条本表未写的前置：**所有者需要一个 agent 够不着的本地 shell**
> （Cursor / Qoder 均 Remote 连入 VM，其中的终端就是 VM 的 shell）。见 `runtime` 轮 `rulings.md` `R2`。
> ⚠ 另一条本表未处置的缺口：H5 未区分「最终稿发布」与「轮内产物发布」，
> 见 `rounds/runtime/runtime-disposition.md` §L.1。

---

## 1. 路线表

每轮一个工单，前置不可跳。档位按 round-protocol 判据自判，**本路线不含任何降档**。

| # | 轮 | 档 | 产物 | 前置 | 机械验收判据 |
| --- | --- | --- | --- | --- | --- |
| R0 | 修 `protocol-v2` 的脚本↔协议不一致（命名、`--stage`、退出码）——**只改脚本，不改协议正文**。**由 opus 直接修，不走轮次** | **bootstrap** | 合并 `protocol-v2` | 无 | 新建空 `rounds/_smoke/` 按协议字面写 `round.md`，`round-status.py` 能解析且判 ① 未开始 |
| R0′ | 往 `round-protocol.md` 补「机器可读块」一节（`round.md` 的 toml 块进协议）。**所有者裁定 2026-09-05：这是改协议，按 T2 开轮**（§7-12 已决） | **T2** | `round-protocol.md` 一节 | R0 | 协议正文与 `round.md` 字段表一一对应；`round-status.py` 解析规则以协议为准，脚本单测覆盖每个字段 |
| S1 | **边界 spike**（`security-boundaries.md` §2）：① 建回执仓、建候选仓；② VM 换三把 key（候选仓读写、主仓只读、回执仓只读），撤销原 `id_rsa`；③ 所有者在 Windows 提交两份测试回执（`[H5]` 含 `acceptance`、`[H3]` 含 `ruling_sha256`），用带口令 key 推；④ 首版 `check-no-owner-creds.sh`；⑤ 按 `security-boundaries.md` §2.0 在宿主 shell 重跑取证 | **bootstrap**（可逆、可丢弃） | `rounds/_spike-sign/` 留痕 | **§8 判据已冻结**（冻结判据 ≠ 判据已满足——qoder C3 的循环不存在；3.13 随之冻结） | ⓪ 回执仓与候选仓建成，VM 身份对**主仓与回执仓** `git push --dry-run` 均被拒（配置导出留痕）；VM 身份对候选仓 push 成功；两份测试回执 `round-status.py` 判成立（签名 ∈ 在线公钥集、schema 合法、`acceptance` 集合完整 / `ruling_sha256` 匹配）；用 VM 上未登记的 key 签一份回执推候选仓再伪装路径，判不成立；`check-no-owner-creds.sh` 零命中；断网重跑判未确认且退出码为「查询失败」；取证栏每行附 `hostname; id; cat /proc/self/uid_map` 输出 |
| R1 | 权力表全表回执仓锚定 + 收件箱字段分级 + 回执内容门；`round-status.py` 读回执仓 yaml 并在线验签、状态推导输出边并按 `state-machine.toml` 校验；T0 两道门；`check-policy.py`；orchestrator 写 `events.jsonl` | **T2**（权威层、不可逆） | `authority.md`、`policies/tier-defaults.toml` 首版（所有者签 `policy/1`）、`policies/state-machine.toml`、`scripts/check-policy.py`、`scripts/gates/`、脚本改动 | R0、S1、原文 §3.1.1 映射表（已由 `runtime-architecture.md` §2.5 取代）冻结 | `round-status.py --round refact` 对历史轮次输出唯一状态机的词与合法边；对 S1 测试回执判 H5 / H3 成立、对缺 `acceptance` 或签名不在公钥集的回执判不成立；无回执的 `rulings.md` 裁定行被判不存在；伪造 T0 工单四种（包名不存在 / 自拼门禁列表 / 完工 diff 越出 paths / 引用一个 paths 覆盖 `constraints.md` 的包）各被拒绝，其中第四种在 `check-policy.py` 层就拒绝签策略；`intake_author` 兼 proposer 的配置被拒发 |
| R2 | 执行架构迁出（含 `human` kind 一小节，3.2） | T1（大搬家但方向无争议） | `executor-architecture.md`；agent 文相应节改为指针 | R0（**不依赖 R1**：S1/R1 受阻不阻塞本轮） | `doc-gate` 通过；§11.3 八条逐条可寻 |
| R3 | 登记表加 `principal` / `provider` / `runtime` / `model_family` / `roles_allowed`；分发前机械拦角色冲突（含 `intake_author`）；独立性折算首版进 `authority.md` | T1 | `agents.toml`、`round-dispatch.py` | R1 | 故意配置「裁决方兼提案方」，分发拒绝并给 reason；正常配置放行；折算表存在且 3.2 的示例（1 家独立带证 vs 3 家同 runtime 无证）按表算出前者胜；luna 与 kimi 按表落同一组 |
| R4 | 工单一般化为 Artifact + T0/T1 guard 表与必需产物表 + 三值路由 + `status` 改推导 | **T2** | `round-protocol.md` 改版、`policies/tier-defaults.toml`、脚本读 tier | R1、R3 | 用一个**可丢弃的小题目**（`automation-roadmap.md` §4.1 要求）分别跑一次 T0、T1；每次 H2 都有落账；脚本输出无一处非唯一状态机的词 |
| R5 | 两份 lifecycle 合并为 `lifecycle.md`；`request-lifecycle.md` 边界声明修订；13 文件引用清理；`doc-gate.py` 配置 | **T2** | `lifecycle.md`、`migration-map.md`、删两份旧文 | R1–R4 | 5.3 五条全部通过 |

调整说明：S1 是 luna 建议的 spike，插在 R1 前；R3（角色冲突检查）按 luna 建议前移到实跑 T0/T1 之前；
R4/R5 与 `automation-roadmap.md`「处理顺序」第 4、6 步一致。3.1.1 状态映射表是 R1 前置，因为权力表的转换列用的就是它的词。
qoder B1 说 R1 把文档重构扩成了基础设施改造——扩的部分只有「建一个仓 + 配一把只读 key」，且 R2 不等它；
但「把签名回执降为可选」不采纳：⑥ 不可机械判是 1.4 的核心诊断，去掉它，本方案只剩文档搬家。

**`bootstrap` 档**（cursor C3）：R0 与 S1 不适用 §2.1 的 T0 定义——T0 要求验收条引用已签策略里的包，而策略首版是 R1 的产物，
S1 的验收条（回执仓建成、越权被拒……）不可能在尚不存在的策略里。它们的验收条就是本表「机械验收判据」列，
效力来自本文被所有者按 §8 冻结，不来自 `policy/1`。`bootstrap` 只用于这两行，之后不再出现；R1 起全部按 T0/T1/T2 自判。
qoder C3 说「所有者凭什么在 S1 前冻结 §8」——这把**冻结判据**与**判据已满足**混为一谈：先冻结验收标准再干活正是 H1 的定义，
S1 的产出是 §8 第 6 条的实证材料，不是冻结 §8 的前提。opus 4.2 说「新增档位说明档位判据偏紧」有道理，但判据在 round-protocol，是它的 T2，登记 §7-14。
原 R0 旁注（协议补「机器可读块」是否算改协议）**所有者已裁定**：算，按 T2 开轮，即 R0′。

---


---

## 2. 各轮的输入规格（迁出自原文 §3.6 / §3.7）

以下两节不是路线本身，是 R1 / R2 的**输入规格**：R1 要实现 T0 的两道门与任务类包，
R2 要把执行架构迁出并带上 provision 函数。它们在被各自的轮次吸收之前留在本文。

### 2.1 工单：一个冻结的 Artifact，一次确认

把 round-protocol 的 `round.md` 一般化为**工单**（Work Order）。**工单是 Artifact，不是 Task 状态。**
它只有 Artifact 的两个状态词 `DRAFT → FROZEN`（沿用《候选状态机》），Task 自身的状态由产物推导。任何档位都有工单，字段固定：

```toml
[order]
id, tier                    # tier 只选 guard 表，不是状态
artifact_state              # DRAFT | FROZEN
route_proposal              # 3.5 的输出：模型证据 + 确定性规则结果，含 policy_version（luna D1：建议与决定分开）
route_effective             # T0：= proposal，由策略放行；T1/T2：H2 回执确认后的值
route_delta                 # 人相对 proposal 改了哪些字段；空 = 全盘沿用（这是观察值「改动项数」的来源）
intent_restatement          # 执行者用自己的话复述需求 + 决策点清单 + 标出的歧义
acceptance = [...]          # 逐条编号，冻结后不改；每条尽量指向一个未来的机械检查；T0 为一个包名
frozen_sections = [...]
[executors]
intake_author               # 起草 intent_restatement / acceptance 的执行者（luna D2）：同票禁任 proposer / arbiter / acceptor，分发前机械拦；
                            # T2 的题目与验收条可由 owner 直接提供，此时 intake_author = owner
proposers, arbiter, acceptor, approver
[workspace]
source, baseline_commit, write_actors, review_needed, submodule_plan   # 3.7 的输入
[budget]
observation_window_rule, max_rounds, max_rollbacks
```

**档位 = 三张表，不是三套状态。**每个 tier 在 `round-protocol.md` 里对应：
一张 **guard 表**（哪些转换要过哪些门）、一张**必需产物表**（哪个 Attempt 组要交什么）、一份 **interrupt 策略**
（H2 能否默认）。T2 是现有七环节；T1 是「出稿 → 独立评审 → 验收 → 确认」；T0 是「做 → 独立验收 → 确认」。
三者读同一个工单 schema，脚本按 `tier` 取表。

**T0 的定义收紧：验收条只能来自已签策略里的机械门禁**（所有者裁定 2026-09-05，回应 kimi D2 / qoder B2）。
kimi 与 qoder 同时指出 11:30 版的矛盾：H1「无默认」× 「T0 开工前零触点」× 「T0/T1 一签两用」三者不能同时成立——
H2 默认放行了，工单却因 H1 无人签而停在 `DRAFT`。解法不是给 H1 加默认，而是让 T0 **不产生需要单独冻结的东西**：

- `policies/tier-defaults.toml` 定义若干**命名任务类包**（cursor C2：扁平门禁列表 + 任意子集会被「合法零件架空意图」——
  「修登录失败」配 `[lint, doc-gate]` 脚本全绿、意图为空）。每个包三项：

  ```toml
  [bundle.readiness-docs-typo]
  paths  = ["sunmoonai/docs/ai-dev-readiness/**/*.md"]   # 允许触及的文件（机械判：完工 diff 的文件集 ⊆ paths）
  gates  = ["gates/doc-gate", "gates/link-check"]         # 必须通过的门禁（机械判）；门禁脚本集中在 scripts/gates/
  covers = "仅改 readiness 文档的笔误与链接"               # 人读；策略签名时所有者签的就是这句话

  [bundle.round-scripts-fix]
  paths  = ["sunmoonai/docs/dev-plan/round-*.py"]         # 不含 doc-gate.py、不含 scripts/gates/
  gates  = ["gates/unit:round-scripts", "gates/lint"]
  covers = "仅改已有测试罩住的 round-* 脚本，不新增行为"
  ```

- **包纪律，加在包定义上、由 `check-policy.py` 在策略签名前校验**（cursor F3 / opus 4.3 / kimi F2 三家同点）：
  任何 T0 包的 `paths` 展开集**不得覆盖**权威层文件（`doc-gate.py` 的 `SELF_CONTAINED` 元组、`round-protocol.md`、
  `request-lifecycle.md`、`authority.md`、`lifecycle.md`、本文）、`policies/**`、以及 `scripts/gates/**` 与各 gate 的依赖文件——
  否则「改门禁」与「被门禁判」落在同一可写面，diff ⊆ paths 照样成立。12:15 版示例 `docs/**/*.md` 把 `constraints.md`、
  `round-protocol.md` 全包进去了，`covers` 不判等于没挡；示例已收窄。**宽包不许，多个窄包可以**（qoder C2 的「多放宽松包」不采纳）。
- **两道门，不是一道**（cursor F1：12:15 版把 `diff ⊆ paths` 绑在分发时，而分发时还没有 diff，空集 ⊆ 任何 paths 恒真）：

  | 何时 | 查什么 | 失败则 |
  | --- | --- | --- |
  | **开工门**（H2 / 分发） | 包名 ∈ 已签策略；T0 + `decide` 有 `RouteDecision` 落账；T1/T2 有回执仓回执 | 拒发 |
  | **完工门**（L0 / L1 / H5 前） | 实际 diff 文件集 ⊆ `paths`；`gates` 全过；H5 内容门 | 不进 H5，不判确认 |

- T0 工单的 `acceptance` 必须是**一个包名**，不得自拼门禁子集；
- **不**做 `covers` 与 `intent_restatement` 的字面匹配——自然语言包含判不了。T0 的诚实定义由此是：
  「题目能被『改动限于路径 X、通过门禁 Y』完全表达」；表达不了的就不是 T0，升 T1；跨包的题目**升 T1 而不是塞进宽包**；
- 于是 T0 的 H1 在策略签名时一次完成，不是被默认掉：所有者签的是「这类题目用这组门禁就够」，不是一张可任意挑选的零件清单；
- 包的增删改按 T2（策略修改本就是 T2）；策略文件首版由所有者签 `policy/1`（§7 风险 5）。
- 代价是 T0 口径变窄。这是正确方向：不能机械验收的东西本来就不该全自动。
- **T0 的承诺只是「开工前零触点」**（cursor D5）：它仍是「做 → 独立验收 → 确认」，发布仍要 H5 签名。
  「可逆、不写共享最终路径、免 H5」的出口是一条新的权力表行、属省事方向，本轮不加，登记 §7 未决，有签名次数数据后再定。

**开工确认（H2）**同时完成所有者思路里的四件事：确认路由、确认（或更换）arbiter
与参赛者、确认任务 list 与是否 fan-out、确认仓库与 worktree 计划。收件箱按 3.4 的字段分级呈现：
executors 名单与 tier 留空待人填，workspace 与预算预填默认。这同时也是 `ai-pipeline.md`「意图确认」那一格（AI 复述 + 决策点 + 人确认）。

工单冻结（H1，Artifact 转换）与开工确认（H2，Task 转换）是两个转换，**开工前触点数按档位是 0 / 1 / 2**（luna C4 指出 12:15 版
「T1/T2 恰好一次」与正文矛盾）：T0 = 0（H1 由已签策略承担，H2 按策略放行）；T1 = 1（H1+H2 合并为一份回执）；
T2 = 2（H1 与 H2 分离，因为 T2 的验收标准要在参赛者看到题目之前冻结，而参赛者名单本身可能要人再定）。§8 第 5 条随此改。


### 2.2 工作区供给：纯函数，判据是独占与干净

```text
provision(task_id, source, baseline_commit, write_actors, review_needed, submodule_plan) →

  前置判据（任一不成立即新建，不复用）：
    现有工作区 owner == task_id 且 == 该执行者      # 独占
    git status --porcelain 为空                    # 干净；有人的未提交改动时按现文「用户工作树已有脏改动」处理：绕开，不 stash
    HEAD == baseline_commit                        # 基线一致

  数量规则：
    |write_actors| = 0   → 不建可写工作区；单文件 git show 即可，整仓只读时开 detached worktree
    |write_actors| = 1   → 一个独占工作区、一条命名分支
    |write_actors| = N   → 同一 baseline_commit 上 N 个 worktree、N 条命名分支 + 一个整合 worktree
    review_needed        → 额外一个 ~/review/<分支> 检视 worktree，用完删（round-protocol「检视面」）
    submodule_plan       → 多仓时逐仓钉 commit 并记父仓 gitlink（现文《物化步骤》第 3 步；constraints T4）
```

与所有者思路不同的判断：

- **worktree 的数量看写者数，要不要新建看独占与干净，两者都不看复杂度。**现文《命名空间》的判据是
  「同一 Task 出现第二名可写执行者时，supervisor 必须先建好各自的 worktree 和命名分支再派活」；
  luna 补的是「写者数 = 1 也可能撞上别的 Task 或人的脏改动」——所以独占与干净是前置判据。三者都可机械判定，复杂度不可。
- **「事先创建好的仓库」只能是 `source`，不能是工作区。**无仓任务从 `scratch_template@commit` clone 或开独占分支，
  Task 结束按清理策略回收（清理属现文《保留与垃圾回收》，不进本函数）。多个 Task 塞进同一个预建仓违反
  《物化门禁》「workspace 唯一归属本 Task」与《按 Task 塞入材料》「上一 Task 的仓库不得复用给下一 Task」。
- **来源一律钉 commit，不钉地址或分支。**「直接引用仓库地址」「拉取 master」都要落 `baseline_commit`；
  现文反模式表「只固定分支名 → 评审对象漂移」。

