# `dev-plan/` 文档组织架构

> `dev-plan-refact` 轮 ① 候选 ｜ 目录名 `opus` ｜ 基线 = 本工作区 HEAD
>
> ⚠ **本文按 `B13` 自证。**每一处断言要么给可复跑命令，要么标 ⚠ 未验证。
> 裁决方**不必逐节读 260 节**——§9 给了「随便挑一节，怎么验它放对了」的方法。
>
> ⚠ **利益申报**：本文作者是 `agent-dev-guide.md` 现有 108 节中 42 节的作者，
> 且参与了本轮任务书起草。**凡涉及这两者的判断，请按 §5.2「任一未知即降级」折算。**

## 0. 一句话

⚠ **现有分类按「内容种类」（约束 / 目标 / 任务 / 状态），而决定一份文档怎么被对待的是
「变更规则」（谁能改、怎么改、旧版怎么办）。两者不一致，就会把不同生命周期的东西
装进同一个容器——而容器只能有一套规则。**

本文提出**按变更规则分类**，给出**可机械执行的归属判据**，并把 260 节安置进去。

## 1. 现状有三处缺陷，全部可机械验证

⚠ **不是「读起来乱」，是三条能用命令复现的事实。**

### 1.1 决定记录编号撞车，34 处裸引用无法解析

```bash
cd sunmoonai/docs/dev-plan
for f in $(find rounds -name rulings.md); do
  echo "$f: $(grep -oE '^\| *`?R[0-9]+' $f | grep -oE 'R[0-9]+' | tr '\n' ' ')"
done
```

实测：三个文件，`R1`–`R6` **在三个文件里全部重复**，共 26 条决定。

裸引用统计（排除定义处）：**带轮次限定 37 处，⚠ 裸引用 34 处**。

⚠ **同一份文件里就有一处限定、一处不限定**：

| 位置 | 写法 |
| --- | --- |
| `handoff.md:114` | `rounds/runtime/rulings.md` `R2` ✓ |
| `handoff.md:131` | `` `rulings.md` `R2` `` ⚠ **裸** |

而三个 `R2` 是三件不同的事：回执仓尚未建成（`refact-fable`）／回执形态不可验证（`runtime`）／
五家能不能读参考作品（`runtime-refact`）。

⚠ **`handoff.md:131` 那句「⑥ 确认的回执强度为零……其回执恰恰最不可验证」按内容对应
`runtime` 的 `R2`——但读者无从判定，因为同一记号在仓里指向至少两件事。**

### 1.2 三种生命周期被装进同一份会被覆盖的文件

`handoff.md` 自述「最后更新：2026-08-29」，`README.md` 的分工表给它的定位是
「**状态**：做到哪、卡在哪」。而它的 `## 不能倒退的输入` 一节装着：

| 内容 | 实际生命周期 |
| --- | --- |
| 五条「已经定了，接手时不要重新讨论」，各带「定于 2026-08-29」 | ⚠ **决定：只追加，永不修改** |
| 其中「四本账：幂等、副作用已接线；缺预算与证据」注明「**取证于** 2026-08-29」 | ⚠ **取证：带环境/版本/作者边界**（`agent-dev-guide.md` §5.13） |
| 当前阶段、已就位的、未决项 | 状态：**被覆盖** |

⚠⚠ **一份会被覆盖的文件里，装着五条永不该被覆盖的决定。**
这不是措辞问题：`handoff.md` 的更新方式是重写，而**重写会静默丢弃决定**。

复现：

```bash
awk '/^## 不能倒退的输入/{f=1;next} f&&/^## /{exit} f' handoff.md
grep -m1 '最后更新' handoff.md
```

### 1.3 工具散在三个位置，没有归属规则

```bash
find . -name '*.py' -o -name '*.sh' | grep -v rounds
```

实测：

| 位置 | 文件 |
| --- | --- |
| 根下 | `doc-gate.py`、`anchor-gate.py` |
| `protocol/` | `round-status.py`、`round-dispatch.py`、`round-review.py`、`agents.toml` |
| `scripts/` | `check-no-owner-creds.sh` |

⚠ **三处的划分依据不可复述**：`doc-gate.py` 与 `round-status.py` 都是判据脚本，
一个在根下一个在 `protocol/`；`check-no-owner-creds.sh` 单独占一个目录。
**新写一个脚本该放哪，现有规则答不了。**

### 1.4 三者同源

⚠ **现有目录是按「产生它的活动」分的**：`protocol/` 是流程活动的产物，
`rounds/` 是轮次活动的产物，根下是剩下的。
⚠ **而「只追加的账」这一类活动横跨所有目录**——决定产生于轮次（落 `rounds/*/rulings.md`），
原始需求产生于受理（落 `working/request-baseline/`），不可倒退的输入产生于交接（落 `handoff.md`）。
**它没有自己的位置，于是散落三处，编号各自从 R1 开始。**

## 2. 为什么现有的「分工表」不解决这三条

⚠ **`README.md` 里已经有一张架构表**（「各文档的分工，别混写」），按**写什么 / 不写什么**分：

| | 写什么 | 不写什么 |
| --- | --- | --- |
| `constraints.md` | 必须遵守的 | 现状、计划 |
| `agent-dev-guide.md` | 架构与开发纪律 | 任务清单、进度 |
| `development-plan.md` | 目标与理由 | 进度、任务 |
| `implementation-plan.md` | 任务：怎么做、怎么算做完 | 状态叙述、架构论证 |
| `handoff.md` | 状态：做到哪、卡在哪 | 论证与实施步骤 |

⚠ **按 `B12`，沿用它必须给理由；本文的判断是：这张表方向对，但不够，三条原因：**

1. **它只覆盖根下 5 份**，不覆盖 `protocol/`、`rounds/`、`working/`、`archive/`、脚本——
   而 §1 的三条缺陷**全部发生在它覆盖不到的地方**（决定在 `rounds/`，工具在三处，
   `working/` 混装）；
2. ⚠ **它说的是「装什么」，没说「怎么变」。**`handoff.md` 那一格写「状态」是对的，
   而「不能倒退的输入」**也是**状态的一部分（接手要知道）——**按内容判它不违规**。
   ⚠ **只有按变更规则判，才看得出「被覆盖的容器里装了不该被覆盖的东西」**；
3. **它是描述，不是判据。**「新写一份文档放哪」这个问题，它答不了——
   因为它是一张**已有文档的清单**，不是一条**可施加于未知文档的规则**。

⚠ **所以本文不是推翻它，是把它的维度换掉并补全：**
从「装什么」换成「**怎么变**」，并从 5 份扩到全树。

## 3. 架构：六类，按变更规则分

⚠ **判据是「变更规则」，因为它同时满足三个要求**：
可机械判（看动作，不看内容）、能解释 §1 三条缺陷、对未知文档可执行。

| 类 | 变更规则 | 旧版怎么办 | 现有实例 | 节数 |
| --- | --- | --- | --- | ---: |
| **A 合同** | ⚠ 改它必须走**修订工作单元**（原始请求/边界/影响/迁移/验收五件） | 保留，带 `supersedes` | `working/request-lifecycle.md` | 42 |
| **B 规范** | ⚠ **整份被一轮的产物取代** | **归档，且必须有逐节落点收据** | `agent-dev-guide.md`、`protocol/round-protocol.md`、`constraints.md` | 180 |
| **C 账** | ⚠ **只追加，任何人不得修改已有条目** | **全部保留**，纠错用新条目 `supersedes` 旧条目 | `rounds/*/rulings.md`、`working/request-baseline/`、`findings.md` | — |
| **D 计划** | 条目**追加 / 勾销**，不重写全文 | 勾销的留痕 | `development-plan.md`、`implementation-plan.md` | 19 |
| **E 状态** | ⚠ **覆盖**；**单写者面** | 不保留（git 里有） | `handoff.md` | 13 |
| **F 工具** | 代码流程：改要有测试、要过门禁 | git 历史 | 6 个脚本 + `agents.toml` | — |
| **G 归档** | ⚠ **不改** | — | `archive/` | — |

（`README.md` 2 节、`protocol/README.md` 4 节属**目录说明**，见 §4.3。合计 42+180+19+13+6 = 260。）

### 3.1 归属判据：⚠ **三问，可机械执行，不靠品味**

> **问一：改它，要不要另一份东西先批准？**
> 要 → **A 合同**（改内核要走修订单元）或 **B 规范**（改它属 T2，要一轮或一次裁定）。
> 再分：**外部有带行号的锚点** → A；否则 → B。
> ⚠ 判据可跑：`python3 anchor-gate.py` 报的「裸路径行号锚」指向谁。
>
> **问二：已有的条目会不会被改写？**
> **不会** → **C 账**。⚠ 判据：能不能指出「谁在什么时候有权改掉第 3 条」——答不出就是账。
> **会，而且是整份重写** → **E 状态**。
> **会，但只是勾销某条** → **D 计划**。
>
> **问三：它是不是可执行的？**
> 是 → **F 工具**（连带要求：有测试、进门禁）。
> ⚠ 文档里的代码块**不算**——判据是「`git` 里它有没有执行位或被 CI 调用」。

⚠ **`G 归档` 不由这三问决定**，它由**收录条件**决定（`archive/README.md`）：
① 已被现行文档取代 **且** ② 有逐节落点收据。**缺任一条不得入**。

### 3.2 ⚠ 这六类怎么解释 §1 的三条缺陷

| 缺陷 | 现有分类为什么看不出 | 本架构为什么看得出 |
| --- | --- | --- |
| §1.1 决定编号撞车 | 「决定」不是一个类，它是**轮次的副产品**，因而跟着轮次走、各自从 R1 开始 | ⚠ **C 账是一个类**，同类必须**共用一个编号空间**——见 §4.1 |
| §1.2 handoff 混装 | 按内容判，「不能倒退的输入」属于状态，**不违规** | ⚠ **E 覆盖 vs C 只追加是互斥规则**，同一容器不能两者兼有 |
| §1.3 工具三处 | 脚本按「服务于哪个活动」分（流程的进 `protocol/`，通用的进根下） | ⚠ **F 是一个类**，且判据（可执行 / 有测试 / 进门禁）与它服务谁无关 |

## 4. 落到目录：改三处，其余不动

⚠ **`B6`：不得把改名当重构。**本文只改三处，每一处都**直接对应 §1 的一条缺陷**，
且**都能事后机械验证是否生效**。

```
sunmoonai/docs/dev-plan/
├── README.md                 目录说明（含归属判据三问）
├── ledger/                   ⚠ 新增 —— C 账，唯一的只追加面
│   ├── decisions.md          ⚠ 26 条决定，统一编号 D-001…，注明原轮次与原编号
│   ├── findings.md           发现登记（现 rounds/dev-plan-refact/findings.md）
│   └── evidence/             取证记录（现散在 rounds/*/observations-*.md、forensics.md）
├── tools/                    ⚠ 新增 —— F 工具，六个脚本归一处
├── contract/  request-lifecycle.md            A 合同
├── norm/      agent-dev-guide.md  round-protocol.md  constraints.md   B 规范
├── plan/      development-plan.md  implementation-plan.md             D 计划
├── status/    handoff.md                                              E 状态
├── intake/    request-baseline/  ⚠ 见 §4.4（B7 冲突）
├── rounds/    轮次归档（不动）
└── archive/   G 归档（不动）
```

### 4.1 ⚠ 改动一：`ledger/decisions.md` —— 决定合并到一个编号空间

**这是唯一解决 §1.1 的办法，而且只有它能解决。**

| 做法 | 能不能解决 34 处裸引用 |
| --- | --- |
| 要求引用时都带轮次前缀 | ⚠ **不能**——它要求 34 处**全部改对且以后不再犯**，是自律不是机制（guide §1.6 P5） |
| 各轮次编号加前缀（`RF-R1`/`RT-R1`） | 能，但**旧的 34 处仍然是裸的**，且 26 条决定仍散在三处 |
| ⚠ **合并到一个 append-only 文件，统一编号** | ⚠ **能**，且**裸引用变成可解析的**——因为 `D-007` 全仓唯一 |

**迁移做法**（可机械执行、可验证）：

```
| D-001 | <原文> | 原：refact-fable R1 | 2026-09-05 |
```

⚠ **原轮次与原编号必须保留**——`rounds/*/rulings.md` 里的 26 条**原文不动**（它们是轮次归档，
属 G），`ledger/decisions.md` 是**投影**，两者由「原：<轮次> <编号>」列关联。

⚠ **代价，如实列**：
1. **产生了第二个写入面**，违反 `P1`「同一事实只有一个权威写入面」——
   ⚠ **必须指定哪一份是权威**。本文主张：**`ledger/decisions.md` 权威，`rounds/*/rulings.md` 降为轮次现场记录**，
   并在后者头部加一行指向前者；
2. **34 处裸引用要逐一改写**——⚠ **可机械核**：改完后
   `grep -rE '`R[0-9]+`' --include=*.md .` 应只在 `rounds/` 内命中；
3. ⚠ **新决定往哪写会有一段模糊期**：轮次进行中产生的裁定，是先写 `rulings.md` 再投影，
   还是直接写 `decisions.md`？**本文主张前者**（轮次现场先记，⑦ 清理时投影），
   理由是轮次进行中 `ledger/` 不该被并发写。

### 4.2 ⚠ 改动二：`tools/` —— 六个脚本归一处

解决 §1.3。⚠ **判据是「可执行」，与它服务谁无关。**

代价：`protocol/round-*.py` 移出会打断「规范与实现放在一起」——
⚠ **而那是所有者 2026-09-07 的明确指示**（「`round-protocol.md` 是指导，`round-*.py` 是实现，
它们应该在一起」）。

⚠ **本文因此不主张移动 `protocol/` 下的三个脚本**，改为：
`tools/` 只收**跨流程的门禁与检查**（`doc-gate.py`、`anchor-gate.py`、`check-no-owner-creds.sh`），
`protocol/` 保持「一套流程 + 它的实现」的完整性。

⚠ **这是本文对自己判据的一处让步，如实标明**：按 §3.1 问三，三个 `round-*.py` 也是 F 类，
应当同处；但所有者的指示是更强的输入。**判据与指示冲突时以指示为准，并记录冲突**——
建议记入 `ledger/findings.md`。

### 4.3 `README.md` 与 `protocol/README.md`：目录说明不是第七类

⚠ 它们描述所在目录，**随目录变而变**，本身没有独立生命周期。
**归属规则**：每个目录**至多一份** README，内容限于「本目录装什么、按什么规则变、新东西怎么判」。
⚠ **不得在 README 里放规范内容**——那会制造第二真源。

### 4.4 ⚠ `working/` 的处置：与 `B7` 有冲突，本文不擅自决定

现状 `working/` 装两样：`request-lifecycle.md`（A 合同，最稳定）与
`request-baseline/`（C 账，只追加）。⚠ **两种生命周期，一个容器。**

按本文架构应拆为 `contract/` 与 `intake/`。**但 `B7` 明写**：

> `working/request-baseline/` 15 份留在 `working/`，**路径不得变更**（所有者 2026-09-07 定）。

⚠ **三种可行处置，本文列出并给倾向，不擅自选：**

| 方案 | 代价 |
| --- | --- |
| 甲 保持 `working/`，只把 `request-lifecycle.md` 移出 | `working/` 变成只装 `request-baseline/`，名实不符；但 **`B7` 完全满足** |
| 乙 `working/` 改名 `intake/`，`request-baseline/` 相对路径不变 | ⚠ 改了父目录名，**`B7` 的字面是「路径不得变更」，改名即违反** |
| 丙 全按架构拆，`B7` 请所有者解除 | 需一次裁定 |

⚠ **本文取甲**——`B7` 是硬约束，而甲**不动 `request-baseline/` 一个字节**。
`request-lifecycle.md` 移到 `contract/`，代价见 §5.1。

## 5. 拆并的代价，逐条给数，⚠ 其中一条推翻了任务书的估计

### 5.1 移动 `request-lifecycle.md` 到 `contract/`：⚠ **比 `B2` 估的便宜得多**

`B2` 写：「内核有 **71 个带行号的外部锚点**、40 份文档引用它。任何涉及它的方案必须给出
**锚点保全方案**；无方案即视为不可行。」

⚠ **实测把这 71 拆开后，结论不同：**

```bash
grep -rhoE 'request-lifecycle\.md @ [0-9a-f]{6,}:[0-9-]+' . | wc -l   # 9
grep -rhoE 'request-lifecycle\.md:[0-9-]+' . | wc -l                 # 54
grep -rhoE '\]\([^)]*request-lifecycle\.md\)' . | wc -l              # 16
grep -rl 'request-lifecycle\.md' . | wc -l                           # 35
```

| 引用形态 | 数量 | 移动后会怎样 |
| --- | ---: | --- |
| 钉 commit 的行号锚 `@ <sha>:<行>` | 9 | ⚠ **不受影响**——在该 commit 内按旧路径解析 |
| 裸路径行号锚 `request-lifecycle.md:<行>` | 54 | ⚠ **不受影响**——见下 |
| markdown 链接 `](…/request-lifecycle.md)` | **16** | ⚠ **会断**，但 `doc-gate.py` **机械捕获** |

⚠ **关键证据**：`anchor-gate.py:42` 按 **basename** 解析裸路径锚：

```python
hits=[t for t in tracked if t.endswith("/"+name) or t==name]
```

而 `git ls-files | grep '/request-lifecycle\.md$'` 实测 **全仓唯一 1 个**。
**basename 不变 → 54 处裸路径锚移动后仍解析得到。**

⚠⚠ **所以 `B2` 的「71 个锚点」把两类合并计数了**：63 个是**移动安全的行号锚**，
只有 16 个 markdown 链接会断，**而那 16 个由 `doc-gate --all` 机械查出、无一遗漏**。

⚠ **按 `B3`，本文不改 `B2`，登记为发现**（建议记入 `ledger/findings.md`）：
`B2` 的成本估计过高，据它「视为不可行」会否掉本来可行的方案。
⚠ **但 `B2` 的要求本身仍然成立**——本节就是它要的那个「锚点保全方案」。

**保全方案（三步，每步可机械验证）：**

1. `git mv working/request-lifecycle.md contract/request-lifecycle.md`——⚠ **正文一字不动**，
   故 54 处行号**仍然有效**（行号跟内容走，不跟路径走）；
2. 16 处 markdown 链接改写，逐文件断言行数不变；
3. `python3 doc-gate.py --all && python3 anchor-gate.py`——⚠ **两道都必须绿**，
   否则回滚。**这一步是判据，不是检查。**

### 5.2 合并 26 条决定进 `ledger/decisions.md`

代价已在 §4.1 列（第二写入面、34 处改写、新决定的写入时机）。⚠ **补一条最容易漏的**：

⚠ **`rounds/*/rulings.md` 是轮次归档（G 类，不改）**，而 `ledger/decisions.md` 是投影。
**投影会陈旧**——这与 `agent-dev-guide.md` §5.9 记的「物化的投影会陈旧，非物化的不会」同形。
**必须有刷新判据**：⑦ 清理时把该轮 `rulings.md` 全部条目投影进 `ledger/`，
并跑一条机械检查——`rounds/` 内的条目数 == `ledger/` 内标注该轮的条目数。

### 5.3 `handoff.md` 拆出「不能倒退的输入」

**五条决定 + 一条取证移出，`handoff.md` 只剩状态。**

| 去哪 | 内容 |
| --- | --- |
| `ledger/decisions.md` | 五条「已经定了」，各带原日期 |
| `ledger/evidence/` | 「四本账：幂等、副作用已接线；缺预算与证据」——⚠ **它是取证，带 2026-08-29 的环境边界** |

⚠ **代价**：接手的人现在要读两处（`status/handoff.md` + `ledger/decisions.md`）。
**换来的是：决定不再被覆盖。**
⚠ **这个取舍要明说**：`handoff.md` 的价值恰恰在「一份就够」，
拆开是**牺牲便利换正确**。**若所有者更看重便利，可改为在 `handoff.md` 里
只放指向 `ledger/` 的链接**——但**不得放决定正文**，否则覆盖问题原样存在。

### 5.4 不动的部分，及理由（`B12`）

| 不动 | 理由 |
| --- | --- |
| `protocol/`（含三个脚本） | ⚠ 所有者 2026-09-07 明确指示「规范与它的实现放在一起」。⚠ 本文 §3.1 问三判它们属 F 类应归 `tools/`，**判据与指示冲突时以指示为准**，并登记冲突（§4.2） |
| `rounds/` 全部 | 轮次归档，属 G；⚠ **重排它会破坏已发布文档的证据锚**（`round-protocol.md` 与 `round-status.py` 都记着「改名等于让已发布的证据链失效」） |
| `archive/` | G 类，收录条件已在 `archive/README.md` 立好，本文不改 |
| `working/request-baseline/` | ⚠ `B7` 硬约束，一个字节不动 |
| `agent-dev-guide.md` 的内部章节划分 | ⚠ **本文不动它**，理由见 §6 |

## 6. 每份文档的内部结构：⚠ 本文只论证一份，其余明确不动

`B12`：沿用要给理由。⚠ **本文的立场是：内部结构不属本轮，理由如下。**

`agent-dev-guide.md` 现有 108 节，其二级章划分（§0–§14）经历了三轮取代仍保持稳定，
而 2026-09-08 那次再吸收**又在同一框架内加了 17 节**且未改二级章。
⚠ **这说明该框架有承载力，不是没人审过。**

⚠ **但本文必须指出一处它自己没解决的**：§3 现有 22 个三级节
（`awk '/^```/{b=!b;next} !b && /^### 3\./' agent-dev-guide.md | wc -l`）。
⚠ **而该文 §0.2「为什么分成这些章」只解释到二级章一层，从未解释 §3 凭什么装 22 件事。**

**本文不在本轮拆它**，三条理由：

1. ⚠ **拆它属于「改结论」的边缘**——章节归属会改变哪些规则被一起读，`B1` 禁；
2. **它是 `B9` 指出的高风险面**：§10 那 294 条落点**只抽查了 6 条**，
   ⚠ **在落点未验实之前重排章节，等于在未知基础上再加一层未知**；
3. **顺序应当是「先验落点，再谈内部结构」**——⚠ 本文把它列为**下一轮的题**，
   并建议判据：**每个二级章都要能回答「凭什么装这些三级节」**，
   §0.2 现在只答到章一级。

⚠ **本文对此的自我批评**：起草者是那 42 节的作者，
「不在本轮拆」这个结论**对起草者有利**（少一件活、少一次被否）。
**请裁决方按利益相关折算，本文不认为自己在这一条上是中立的。**

## 7. 新文档进来怎么判：⚠ 一条可执行的判定，不靠品味

```
新文档 X
  │
  ├─ X 可执行吗（有执行位或被 CI 调用）？ ── 是 ──► F 工具 → tools/ 或 protocol/
  │                                                （服务于某一套流程的，随该流程）
  ├─ 改 X 需要另一份东西先批准吗？
  │     ├─ 需要，且外部有带行号的锚点 ──► A 合同 → contract/
  │     └─ 需要，无行号锚 ────────────► B 规范 → norm/
  │
  ├─ X 里已有的条目会被改写吗？
  │     ├─ 不会（说不出谁有权改掉第 3 条）──► C 账 → ledger/
  │     ├─ 会，整份重写 ────────────────► E 状态 → status/
  │     └─ 会，只勾销某条 ───────────────► D 计划 → plan/
  │
  └─ X 已被取代 且 有逐节落点收据 ────────► G 归档 → archive/
```

⚠ **两条防退化的规矩：**

1. ⚠ **判不出就不许放。**落不进任何一类，说明它**混装了多种生命周期**——
   先拆，再放。§1.2 的 `handoff.md` 就是这种情形。
2. ⚠ **一个容器一套规则。**同一目录下的文件必须共享同一条变更规则；
   **发现例外时改的是文件不是规则**。

## 8. ⚠ 本文明确**不做**的（`B4` 的「故意不要 + 理由」）

| 不做 | 理由 |
| --- | --- |
| 拆 `agent-dev-guide.md` 的内部章节 | §6 三条理由，含起草者的利益自陈 |
| 移动 `protocol/round-*.py` | 所有者明确指示优先于本文判据（§4.2、§5.4） |
| 重排 `rounds/` | 会让已发布文档的证据锚失效（§5.4） |
| 动 `working/request-baseline/` | `B7` 硬约束 |
| 改 `B2` 的措辞 | ⚠ 已按 `B3` 登记为发现（§5.1），**本轮不改** |
| 加「按角色读哪几节」的阅读路径表 | ⚠ `B10` 明禁；且**它是症状缓解**——本文认为读不下去的根因是「一份 3082 行的文档同时是规范和沿革」，而那属 §6 说的下一轮 |

## 9. ⚠ 怎么验本文（`B13`：裁决方不必逐节读 260 节）

**三条抽查法，每条都是命令，都能在几分钟内跑完。**

### 9.1 验「问题是真的」——跑 §1 的三段命令

三条缺陷各附了可复跑命令。⚠ **任一条跑不出预期结果，本文 §1 即不成立，
后面的架构就失去依据。**

### 9.2 验「落点表没漏」——机械核

```bash
cd sunmoonai/docs/dev-plan
# 源节总数
python3 - <<'X'
import io,re
docs=['working/request-lifecycle.md','agent-dev-guide.md','protocol/round-protocol.md',
 'protocol/README.md','constraints.md','development-plan.md','implementation-plan.md',
 'handoff.md','README.md']
n=0
for d in docs:
    b=False
    for l in io.open(d,encoding='utf-8'):
        if l.lstrip().startswith('```'): b=not b; continue
        if not b and re.match(r'^#{1,4} ',l): n+=1
print(n)     # 应为 260
X
# 本文 §10 的落点行数 —— ⚠ 必须限定在 §10 之内
python3 - <<'X'
import io
s=io.open('dev-plan-architecture.md',encoding='utf-8').read()
st=s.index('## 10. 逐节落点')
print(sum(1 for l in s[st:].split(chr(10)) if l.startswith('| ') and l.count('|')>=5))
X
# 两数应相等，均为 260
```

⚠ **本节的检查命令自己出过一次错，如实记：**初稿用的是按行首匹配表格行的 grep，
得 **276** 而非 260——它把本文 §5.1 等处**其他表格**的行也数了进去。
**判据在边界上给了假答案**（`agent-dev-guide.md` §5.2「判据自身的质量」）。
⚠ **是起草者跑自证时发现的，不是被指出的**——但它恰好说明：
**「零丢弃」这类机械判据，其命令本身必须先被验证**（`round-protocol.md` §8.1 第四条）。

⚠ **骨架是脚本生成的**（`kimi` 在 `runtime-refact` 轮立的 `K1`：
「表的骨架机械生成，不手抄——手抄的表会漏行，而漏掉的那行不会有人发现」）。

### 9.3 ⚠ 验「落点放对了」——随便挑一节，三步

这是 `B11` 的核心：**落点齐全 ≠ 放对了地方**。抽查法：

1. **从 §10 随便挑一行**，看它的「类」；
2. **对照 §3 的变更规则表**问一句：**这一节的内容，符合那一类的变更规则吗？**
   例：挑到 `handoff.md` / `不能倒退的输入` → 表里写「移出至 `ledger/`」→
   验：那一节的内容是不是「只追加、不该被覆盖」的？**打开 `handoff.md` 看那五行带日期的决定**——是；
3. ⚠ **反向验一次**：随便挑一节表里写「留在原处」的，问「**它凭什么不动**」。
   答不出 → 该行是伪落点。

⚠ **本文自陈：起草者对 260 行只做了第 2 步的 3 次抽查、第 3 步的 2 次。**
按 `agent-dev-guide.md` §9.4 记的经验（85 行正文级抽查查出 50 处真缺），
⚠⚠ **本表很可能仍有数十处放错。发现一处即为有效发现，不必客气。**

### 9.4 ⚠ 本文没做的

| # | 没做 |
| --- | --- |
| 1 | ⚠ **没有实际移动任何文件**——本文是**方案**，不是执行。执行须过 §5.1 第 3 步的两道门 |
| 2 | ⚠ **没有验证 260 行落点中「留在原处」那些的正确性**（见 §9.3 自陈） |
| 3 | ⚠ **没有跑过 `ledger/decisions.md` 的合并**——26 条决定的实际冲突（同日期、同主题、互相引用）未查 |
| 4 | ⚠ **没有查 `rounds/` 内部是否也有生命周期混装**——本文只把它整体判为 G |
| 5 | ⚠ **`B14` 自查**：本文全部断言均来自本轮只读输入或附了可复跑命令；⚠ **但起草者带着本轮之外的上下文，可能在无意中依赖了未列出的事实——请裁决方按 `round.md` 三的利益申报折算** |

## 10. 逐节落点（骨架机械生成，人只填第四列）

> ⚠ **本表是覆盖的索引，不是覆盖的证明。**核它的办法见 §9.3——抽查落点、以正文为准。

| 源文件 | 类 | 节 | 落点 |
| --- | --- | --- | --- |
| `working/request-lifecycle.md` | A 合同 | Request Lifecycle：产品请求生命周期合同 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 0. 规范边界与条款筛选 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 0.1 只收产品要求 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 0.2 本文负责什么 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 0.3 规范用语 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 1. 生命周期全景 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 2. 核心对象 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 2.1 Task 不等于 Attempt | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 2.2 Submission 不一定产生 Task | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 3. Task 契约 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 3.1 提交信封 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 3.2 持久化主档 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 3.3 解释、边界与完成契约 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 3.4 最终结果信封 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 4. 两层状态机 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 4.1 Task 状态机 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 4.2 WAITING 与 Interaction | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 4.3 取消意图与终态 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 4.4 终态、刷新与重新处理 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 4.5 Attempt / Run 状态机 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 5. 七阶段产品功能 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 5.1 提交（前端） | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 5.2 受理与校验（后端） | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 5.3 排队与可靠投递 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 5.4 Agent 执行 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 5.5 中断、批准与恢复 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 5.6 验收与完成提交 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 5.7 返回前端、失败与重试 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 6. 跨进程纪律与持久化账 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 6.1 全程不变量 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 6.2 持久化记录 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 7. Profile、Artifact 与扩展 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 7.1 Task Profile 与 Agent Profile | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 7.2 Profile 示例 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 8. 子 Task 与依赖编排 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 9. 前端、后端与 Agent 责任投影 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 10. 反模式 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 11. 产品验收矩阵 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 12. 修订、落地与参考材料 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 12.1 修订纪律 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 12.2 参考材料边界 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `working/request-lifecycle.md` | A 合同 | 12.3 生效边界 | `contract/request-lifecycle.md`——**整份移动，正文一字不动**（§5.1） |
| `agent-dev-guide.md` | B 规范 | Agent 开发指导：一个产品运行时，一套开发纪律 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 0. 先读结论 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 0.0 原来是什么样，为什么非改不可 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 0.1 文档边界 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 0.2 为什么分成这些章 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 0.3 按工作阶段阅读，不按历史版本阅读 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 1. 不可变的契约与边界 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 1.1 唯一产品内核 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 1.2 四本账与单一权威写入面 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 1.3 Agent 硬约束自检 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 1.4 开发验收不可外推 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 1.5 执行者的共同纪律 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 1.6 七条设计原则 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 1.7 先核前提，也核控制面 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 2. 一个运行时的结构 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 2.1 确定性组件与适配层 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 2.2 内容角色 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 2.3 Task Profile 与 Agent Profile | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 2.4 `dev.change/1` 工单 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 2.5 路由只读可判字段 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 2.6 执行层：租用什么、自建什么 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 2.7 两个官方 SDK：两个轴、非对称能力 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 2.8 统一执行 Port 与三态能力探针 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 2.9 Harness 腿的前置门禁与过渡补法 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 2.10 双 runtime 的部署、进程与恢复 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 2.11 派工契约、角色补充与隔离的诚实边界 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 2.12 五家 Agent Profile 的历史取值示例 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 3. 一次开发 Task 怎样执行 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 3.1 受理与冻结 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 3.2 工作区供给 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 3.3 Attempt 与状态投影 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 3.4 T0/T1/T2 不是三套状态机 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 3.5 交付、清理和恢复 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 3.6 私有地产生，单写者发布 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 3.7 并发场景处置表 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 3.8 覆盖或来源不明时的事故规程 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 3.9 冻结、迟到与取消 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 3.10 物化门禁与写入前门禁 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 3.11 候选状态机 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 3.12 完成判据 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 3.13 执行形态、停止规则与成本 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 3.14 建立 worktree 的细则 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 3.15 发布协议：三个路径不是一个 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 3.16 保留与垃圾回收 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 3.17 内核对象 ↔ 开发载体对照 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 3.18 状态脚本的硬要求 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 3.19 T2 七环节的操作闭环 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 3.20 工作区能写，不代表 Git 能提交 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 3.21 通知、取件与人的检视面 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 3.22 停止、超时与回退不能省略 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 4. 人介入、Interaction 与权力 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 4.1 人的位置 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 4.2 权力表 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 4.3 直接沿用实际中断/恢复原语 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 4.4 身份、批准与强制点 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 4.5 权限公式与只有 principal 能做的动作 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 4.6 三道正交门 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 4.7 四档审批 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 4.8 principal 的裁量权与改判纪律 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 4.9 Attempt 内的三条硬禁令 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 4.10 人这一侧的义务 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 4.11 本轮已发生介入的实例级清单 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 4.12 人的收件箱：让批准具体、可读、可重取 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 4.13 执行器凭据、子进程与跨腿委派 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 5. 可观测性、证据与等效 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 5.1 三个粒度字段 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 5.2 证据等级与采信规则 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 5.3 手工态与服务态的等效判据 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 5.4 Git 载体能与不能证明什么 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 5.5 四层验证 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 5.6 `F-EXEC-*` / `F-INTERACT-*` 双腿落地矩阵 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 5.7 证据账按流程分级 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 5.8 上下文路由与能力四级词典 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 5.9 七种载体各能证明什么 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 5.10 事实裁决表与整合纪律 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 5.11 轨迹实测：23 条里 2 条 attested | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 5.12 检查本身也必须接受检查 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 5.13 历史取证怎样用于今天的开发 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 6. 什么时候运行时值得用 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 6.1 机械分类 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 6.2 三类反例与 T0 上界 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 6.3 绕过只能部分可观测 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 7. 演进与退出脚手架 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 7.1 依赖顺序 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 7.2 从手工态拆到服务态 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 7.3 删除与迁移门 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 7.4 风险和未决 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 7.5 跨会话续接 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 7.6 执行器架构的未验证清单 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 7.7 需要改内核时，提交明确的修订工作单元 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 8. 本轮核查裁定 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 8.1 六项逐条处置 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 8.2 保留与撤销 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 8.3 本次补吸收明确不采用的旧主张 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 9. 覆盖声明 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 9.1 查了什么 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 9.2 没查什么 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 9.3 自增内容及理由（`runtime-refact` 轮） | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 9.4 两份 lifecycle 的吸收轮（2026-09-07） | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 9.5 GPT-6 再吸收记录（2026-09-08） | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 9.6 取代前 opus 做的核验（2026-09-08） | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 10. 五份历史正文及目录说明的逐节处置 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 11. 反模式 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 12. 常见失败方式与项目实例 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 12.1 七种“检查给出假答案”的回归线索 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 12.2 并行评审的收益与盲区 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 13. 词汇对照 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `agent-dev-guide.md` | B 规范 | 14. 开发 Task 持久记录模板 | `norm/agent-dev-guide.md`——**只移动，内部章节不动**（§6） |
| `protocol/round-protocol.md` | B 规范 | 并行评优轮：流程 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 0. 收到「继续」时怎么办 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 1. 流程档位：这件事该走多重的流程 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 1.0 一套流程，靠参数覆盖三种协作形态 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 1.1 判据：命中任一条即 T2 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 1.2 升档随意，降档要理由——这条不对称是有意的 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 1.3 任何档位都不能省的三条 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 2. 裁量权：supervisor 可以临机决定什么 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 2.1 不可裁量的下限 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 2.2 可裁量的事项 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 2.3 方向不对称：这是本协议的统一原则 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 2.4 裁定记录：未记录的裁定无效 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 2.5 推翻 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 2.6 裁量是规则的孵化器 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 3. 执行者与触发方式：两个轴，不要混 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 3.1 两个轴 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 3.2 全部动作的归属 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 3.3 两类「人做」不可互相顶替 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 4. 七个环节（T2 专用） | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 5. 本轮定义：`round.md` | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 6. 产物、路径与命名 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 6.1 环节通知：组织者的产物，不是发起人的话术 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 7. 取件与检视面 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 7.1 取件：一律按 commit，不看工作区 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 7.2 检视面：需要人读时开临时 worktree | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 7.3 每个需要人读的环节都必须先有检视面 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 8. 环节判定：命令即判据 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 8.1 判据自身的质量：覆盖不全比没有更危险 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 8.2 立判据的人怎么约束自己 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 只写判据，不写答案 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 立据人的四条自我约束 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 难点清单：记下来是为了检验发起方 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 三条通用扣分规则 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 起草人回避 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 判据自身的失效条件 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 一票否决项要事先列 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 8b. 两个脚本怎么调 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 退出码 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 声明与计算对不上时 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 8c. 组织者的两条纪律 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 8c.1 环节进行中，组织者不得写入参与方的工作区 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 8c.2 代提交必须用 `--author`，且必须登记为欠账 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 9. ① 提案：隔离与冻结 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 9.1 隔离为什么是硬要求 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 9.2 工单发什么、不发什么 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 9.3 机制化隔离：曾经有过，已经删掉 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 10. ② 互评：评审文件写什么 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 11. ③ 裁决：定基座与吸收 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 12. ④ 异议：对整合权的唯一制衡 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 13. ⑤ 验收 与 ⑥ 确认 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 13.1 定向审核分两阶段，防止被产出方锚定 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 13.2 验收通过意味着什么，不意味着什么 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 14. 停止、超时与回退 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 14.1 参与方不可用：逾期、弃权与换人 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 15. 角色不分会怎样 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 16. ⑦ 清理与发布 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/round-protocol.md` | B 规范 | 17. 通用纪律 | **留在 `protocol/`**——规范与其实现同处（§5.4） |
| `protocol/README.md` | 目录说明 | `protocol/` —— 流程规范与它的实现 | 留在 `protocol/`；按 §4.3 限定为「装什么/怎么变/怎么判归属」 |
| `protocol/README.md` | 目录说明 | 三条设计约束，改这里的代码前先读 | 留在 `protocol/`；按 §4.3 限定为「装什么/怎么变/怎么判归属」 |
| `protocol/README.md` | 目录说明 | 单一真源 | 留在 `protocol/`；按 §4.3 限定为「装什么/怎么变/怎么判归属」 |
| `protocol/README.md` | 目录说明 | 已知不做的事 | 留在 `protocol/`；按 §4.3 限定为「装什么/怎么变/怎么判归属」 |
| `constraints.md` | B 规范 | 开发必须遵守的规则 | `norm/constraints.md` |
| `constraints.md` | B 规范 | 怎么用 | `norm/constraints.md` |
| `constraints.md` | B 规范 | 数据 | `norm/constraints.md` |
| `constraints.md` | B 规范 | 做数据迁移时 | `norm/constraints.md` |
| `constraints.md` | B 规范 | 契约 | `norm/constraints.md` |
| `constraints.md` | B 规范 | 身份 | `norm/constraints.md` |
| `constraints.md` | B 规范 | 拓扑 | `norm/constraints.md` |
| `constraints.md` | B 规范 | 什么时候才拆出专用 Worker | `norm/constraints.md` |
| `constraints.md` | B 规范 | 发布 | `norm/constraints.md` |
| `constraints.md` | B 规范 | 改模板、同步实例时 | `norm/constraints.md` |
| `constraints.md` | B 规范 | 清理镜像时 | `norm/constraints.md` |
| `constraints.md` | B 规范 | 一条环境事实 | `norm/constraints.md` |
| `constraints.md` | B 规范 | 智能体 | `norm/constraints.md` |
| `constraints.md` | B 规范 | 保证这些被遵守的三层 | `norm/constraints.md` |
| `constraints.md` | B 规范 | `doc-gate.py` 为什么不是第三个被删的脚本 | `norm/constraints.md` |
| `development-plan.md` | D 计划 | 开发计划 | `plan/development-plan.md` |
| `development-plan.md` | D 计划 | 起点：不延续 v5 | `plan/development-plan.md` |
| `development-plan.md` | D 计划 | 智能体分两部分 | `plan/development-plan.md` |
| `development-plan.md` | D 计划 | 四本账是两部分共用的地基 | `plan/development-plan.md` |
| `development-plan.md` | D 计划 | 执行层租用，不自建 | `plan/development-plan.md` |
| `development-plan.md` | D 计划 | 三个阶段 | `plan/development-plan.md` |
| `development-plan.md` | D 计划 | 一 · 前后端对接 | `plan/development-plan.md` |
| `development-plan.md` | D 计划 | 二 · agent 开发 | `plan/development-plan.md` |
| `development-plan.md` | D 计划 | 三 · 结构化数据问答（后期） | `plan/development-plan.md` |
| `development-plan.md` | D 计划 | 有意留白的两处 | `plan/development-plan.md` |
| `implementation-plan.md` | D 计划 | 实施计划 | `plan/implementation-plan.md` |
| `implementation-plan.md` | D 计划 | 任务条目格式 | `plan/implementation-plan.md` |
| `implementation-plan.md` | D 计划 | 测试层次 | `plan/implementation-plan.md` |
| `implementation-plan.md` | D 计划 | 交付规则 | `plan/implementation-plan.md` |
| `implementation-plan.md` | D 计划 | 阶段〇 · 开发框架自身的实施路线（R0–R5） | `plan/implementation-plan.md` |
| `implementation-plan.md` | D 计划 | 阶段一 · 前后端对接 | `plan/implementation-plan.md` |
| `implementation-plan.md` | D 计划 | 任务清单 | `plan/implementation-plan.md` |
| `implementation-plan.md` | D 计划 | 阶段二 · agent 开发 | `plan/implementation-plan.md` |
| `implementation-plan.md` | D 计划 | 阶段三 · 结构化数据问答 | `plan/implementation-plan.md` |
| `handoff.md` | E 状态 | 交接 | `status/handoff.md`——⚠ **两节例外，见逐节** |
| `handoff.md` | E 状态 | 当前阶段 | `status/handoff.md`——⚠ **两节例外，见逐节** |
| `handoff.md` | E 状态 | 已经就位的（不用再做） | ⚠ **部分移出**：其中标「取证于」的行移入 `ledger/evidence/`，带环境边界；其余留 `status/` |
| `handoff.md` | E 状态 | 未决项 | `status/handoff.md`——⚠ **两节例外，见逐节** |
| `handoff.md` | E 状态 | U1 的已知输入 | `status/handoff.md`——⚠ **两节例外，见逐节** |
| `handoff.md` | E 状态 | U3 的已知输入 | `status/handoff.md`——⚠ **两节例外，见逐节** |
| `handoff.md` | E 状态 | U4 的已知输入 | `status/handoff.md`——⚠ **两节例外，见逐节** |
| `handoff.md` | E 状态 | 不能倒退的输入 | ⚠ **移出**至 `ledger/decisions.md`——**五条带日期的决定，不属状态**（§1.2、§5.3） |
| `handoff.md` | E 状态 | 文档面待办 | `status/handoff.md`——⚠ **两节例外，见逐节** |
| `handoff.md` | E 状态 | 任务游标 | `status/handoff.md`——⚠ **两节例外，见逐节** |
| `handoff.md` | E 状态 | 开发框架自身（R0–R5 路线）的进度 | `status/handoff.md`——⚠ **两节例外，见逐节** |
| `handoff.md` | E 状态 | 已完成的轮次 | `status/handoff.md`——⚠ **两节例外，见逐节** |
| `handoff.md` | E 状态 | 不能倒退的两条（本轮新增） | `status/handoff.md`——⚠ **两节例外，见逐节** |
| `README.md` | 目录说明 | dev-plan — 代码要符合什么、接下来建什么 | `README.md` 留在根下；⚠ **新增归属判据三问**（§3.1） |
| `README.md` | 目录说明 | 各文档的分工，别混写 | ⚠ **改写**为 §3 的六类表 + §3.1 归属判据三问——**这是本轮唯一改内容的一处，且只改组织性描述，不改任何结论**（`B1`） |
