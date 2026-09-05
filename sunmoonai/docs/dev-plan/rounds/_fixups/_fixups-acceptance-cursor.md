参与方：cursor｜worktree：/home/zym/worktrees/cursor/k8s｜HEAD：cd4c7a67dc2037324f11818f8c541e68a95a2b33

# ⑤ 验收：工作单元 `_fixups`（验收方 cursor）

> 按 `_fixups-call-⑤.md` 交付。验收方由所有者 2026-09-05 指派，非 opus，非本单元执行者。
> 判定对象：`opus` @ `e1a91e15`（C4 已落入该树；环节通知发于 `a1b09e77`）。
> 判定标准：`round.md` §4 七条（90 行，sha256[:16] `1e61358c9f9b7e95`），**未改任何一条**。
> 身份判别：`basename "$(dirname "$(git rev-parse --show-toplevel)")"` → `cursor`。

## 结论（置前）

**不通过。** 七条中两条不满足（§4-1、§4-4），一条部分满足（§4-3），四条满足（§4-2、§4-5、§4-6、§4-7）。
不满足项是产出未达标，不是判据过期——判据仍是对的，交回执行者补产出后重验。

| 条号 | 判定 | 一句话 |
| --- | --- | --- |
| 1 内容零缺口 | **不满足** | 11 节里 2 节只剩空标题，正文仍只在 git 历史 |
| 2 无第二真源 | **满足** | 验收对象（opus 树）顶层已无三份旧文，活跃文档无全文双写 |
| 3 分工合规 | **部分满足** | 落点方向对，但实施计划阶段〇写入了进度与裁定论证 |
| 4 引用形态 | **不满足** | 活跃文档对已删 `security-boundaries.md` 仍有规范性引用 |
| 5 门禁 | **满足** | 在含 C4 的 opus 树上 `doc-gate --all` 与 `anchor-gate.py` 均退出 0 |
| 6 脚本自身可信 | **满足** | 独立沙箱 4 个有效锚 + 6 个悬空锚，不误报不漏报（含三次历史假失败回归） |
| 7 未动冻结物 | **满足** | `rounds/runtime/task.md` 相对 `runtime/h1` 逐字节一致 |

**回交执行者的缺口（对应条号）**：

1. **§4-1**：把 `refact-fable.md @ 7e8464c2` §3.7 的 `provision(...)` 函数、数量规则与三条判断写入 `runtime-architecture.md` §4.5.1（现仅有标题，752–754 行之间为空）；把 §3.13.6 剩余风险表写入 §4.6.3（现仅有标题，833–835 行之间为空）。写进去之后，不经 `git show` 必须能读到与原文同等的可执行内容。
2. **§4-4**：`implementation-plan.md` 阶段〇 S1 行两处规范性引用 `security-boundaries.md` §2 / §2.0 改为新落点（§4.4 / §4.7，以补完后的节号为准）。
3. **§4-3**（不单独构成不通过，但应一并清）：阶段〇去掉进度句与裁定论证，进度归 `handoff.md`，论证归架构文档或处置记录。

---

## 一、取件与对象事实

在 `/home/zym/worktrees/opus/k8s`（`HEAD a1b09e77`，含 `e1a91e15`）复跑：

| 对象 | 通知钉版 | 本人复跑 | 判 |
| --- | --- | --- | --- |
| `runtime-architecture.md` | 1022 行 `048e9aafdefa1bec` | 一致 | ✓ |
| `implementation-plan.md` | 103 行 `0be7ecc4ef1500ae` | 一致 | ✓ |
| `README.md` | 37 行 `11c2657b538641c9` | 一致 | ✓ |
| `anchor-gate.py` | 125 行 `7c90c7f7bd6ded92` | 一致 | ✓ |
| `round.md`（§4） | 90 行 `1e61358c9f9b7e95` | 一致 | ✓ |

C4 尚未进主线，验收在 opus 树上进行，不在 cursor 工作区跑门禁（cursor 分支仍跟踪 C3 的 `security-boundaries.md` / `roadmap.md`，那是未合并状态，不是本条对象）。

「仍有效 11 节」的枚举：C2 抬头表 8 行（§3.13.2–3.13.5、§3.4、§3.6、§3.7、§6）+ C3 声明随 §3.13 全节迁出的另外 3 节（§3.13.0 取证声明、§3.13.1 现状事实、§3.13.6 剩余风险）。C3 提交说明写「11 节逐条确认有新落点」。

---

## 二、七条逐条判定

### 1. 内容零缺口 — **不满足**

对照表（新落点均可在 opus 树当前文件打开，不经 `git show`）：

| 原文 @ `7e8464c2` | 声称新落点 | 不经历史能否读到正文 |
| --- | --- | --- |
| §3.13.2 三道边界 | `runtime-architecture.md` §4.4.1 | **能**（:665 起有表） |
| §3.13.3 回执仓对象模型 | 同文件 §4.4.2 | **能**（:681 起有目录树与规则） |
| §3.13.4 回执 schema | 同文件 §4.4.3 | **能**（:706 起有 yaml） |
| §3.13.5 两台机器身份 | 同文件 §4.6.2 | **能**（:803 起有分布图） |
| §3.4 收件箱字段分级 | 同文件 §4.6.1 | **能**（:770 起有分级表） |
| §3.6 工单与 T0 任务类包 | 同文件 §2.2.1 | **能**（:119 起有 schema 与包纪律） |
| §3.7 工作区供给 provision | 同文件 §4.5.1 | **不能**。:752 只有标题，:753 空行，:754 已是 §4.6。原文 `provision(...)` 函数体、`\|write_actors\|` 数量规则、三条「与所有者思路不同的判断」均不在活跃文档。§4.5 正文只剩一句「前置判据两边都用」（:736），不是 §3.7 |
| §6 实施路线 R0–R5 | `implementation-plan.md` 阶段〇 | **能**（:53 起有路线表）。规范性引用问题记在第 4 条，不在本条重复判失败 |
| §3.13.0 取证声明 | `runtime-architecture.md` §4.7 | **能**（:837 起） |
| §3.13.1 现状事实 | 同文件 §4.7 | **能**（:848 起有表） |
| §3.13.6 剩余风险 | 同文件 §4.6.3 | **不能**。:833 只有标题，:834 空行，:835 已是 §4.7。原文 8 行风险表（「人被 agent 的输出误导而签了错的 commit」等）活跃文档零命中 |

C3 的 `roadmap.md` §2.2 与 `security-boundaries.md` §2.6 当时是有正文的；C4 并回时建了节号、没贴内容。这正是 C2 抬头要防的事：`git show <commit>:<路径>` 是可复核性，不是可读性。

本条要求「11 节」且「不经 git 历史即可读到」。2/11 读不到，零缺口不成立。**不是判据过期。**

### 2. 无第二真源 — **满足**

```
git ls-tree --name-only opus:sunmoonai/docs/dev-plan/
```

无 `refact-fable.md`、`security-boundaries.md`、`roadmap.md`。
`git cat-file -e opus:sunmoonai/docs/dev-plan/{refact-fable,security-boundaries,roadmap}.md` 均不存在于该树。

同一内容未在两份活跃文档全文并存：架构文档持边界 / 工单 / 通道，实施计划持路线表，无第二份 `provision(...)` 或剩余风险表（它们是**零真源**，记在第 1 条，不改判本条）。

### 3. 分工合规 — **部分满足**

`README.md`「三份文档的分工」表（opus :26–34）：

| 文件 | 应写 | 不应写 |
| --- | --- | --- |
| `runtime-architecture.md` | 架构：怎么搭、为什么 | 任务清单、进度 |
| `implementation-plan.md` | 任务：怎么做、怎么算做完 | 状态叙述、架构论证 |

落点方向符合 C4 自己的声明：边界 / 回执 / provision / 工单进架构，路线进实施计划。§2.2.1 是 Task Profile 的 `input_schema`，不是任务清单。

未完全合规处在实施计划阶段〇：

- :56「进度：R0 未做……**S1 进行中**」是状态叙述，按分工应在 `handoff.md`。
- :73–83 对 qoder B1 / C3、`bootstrap` 档效力来源的裁定论证，不是「怎么做、怎么算做完」。

不把本条升为不满足：混写的是随 §6 原文一并迁来的伴随段落，主落点没有放错文件。

### 4. 引用形态 — **不满足**

三条合取，一条失败即本条不满足。

**证据性引用钉 `@ 7e8464c2`**：活跃文档（`dev-plan/*.md`，不含 `rounds/**`）里所有 `refact-fable.md` 引用均为 `refact-fable.md @ 7e8464c2`（架构文档 :17、:52、:61、:82、:201、:347、:442–463、:984；实施计划 :55）。通过。

**裸路径行号锚 `refact-fable.md:<行>`**：活跃文档计数为 0。`rounds/**` 里的裸锚按 `anchor-gate.py` 归档软判，不在本条「活跃文档」范围。通过。

**规范性引用指向新落点**：失败。`implementation-plan.md:66` S1 行两处：

- 「边界 spike（`security-boundaries.md` §2）」
- 「按 `security-boundaries.md` §2.0 在宿主 shell 重跑取证」

`security-boundaries.md` 已随 C4 从顶层删除。这不是「当时那份稿子写了什么」的证据引用，而是任务「按哪节做」的规范指向。新落点应是 `runtime-architecture.md` §4.4 / §4.7（且 §4.4.1 补完、§4.6.3 补完之后，节号还需再核）。读者按现文字去打开 `security-boundaries.md`，活跃树里没有这份文件。

`:70` / `:74` 的 `automation-roadmap.md` 是另一份既有文档，不在本条范围。

### 5. 门禁 — **满足**

必须在含 C4 的树上跑。命令与结果：

```
cd /home/zym/worktrees/opus/k8s
python3 sunmoonai/docs/dev-plan/doc-gate.py --all
# doc-gate: 148 份文档通过
# 退出码 0

python3 sunmoonai/docs/dev-plan/anchor-gate.py
# 钉 commit 锚 13 通过；裸路径行号锚 95 通过；章节号引用 144 处（软判）
# 归档 rounds/** 92 处软判（其中 refact-fable.md 86 处），不计失败
# 退出码 0
```

本条只要求两门禁退出 0。脚本是否可信是第 6 条，不把「它打印通过」自动记入第 6 条。

### 6. `anchor-gate.py` 自身可信 — **满足**

脚本是 opus 写的、用来验 opus 的改动。本人把 `7c90c7f7bd6ded92` 这份脚本拷到**独立 git 仓** `/tmp/ag-sandbox-cursor`，自造文件与 commit，不信任它对全库打印的「通过」。

沙箱基线：commit `2d64f0f01d16414b24da99887caac89814a26e02`（下称 SHA1）含 10 行 `pinned-target.md`、5 行 `live-target.md`、两份同名 `rounds/r{1,2}/rulings.md`、两份同名 `foo.md`；下一 commit 删除 `pinned-target.md`（当前索引无此文件）。脚本对 `~/repo/{codex,deepseek-harness,openclaw}` 的外部解析沿用其硬编码路径；本机 `~/repo/deepseek-harness/docs/cookbook/adding-a-tool.md` 唯一命中、101 行。

**已知有效锚（期望退出 0，且计数 +1）——4/4 符合，不少于 3：**

| # | 用例 | 锚 | 期望 | 实际 |
| --- | --- | --- | --- | --- |
| V1 | 钉 commit、文件已从当前索引删除（历史假失败之三） | `` `pinned-target.md @ SHA1:5` `` | 退出 0，「钉 commit 锚 1 通过」 | 是 |
| V2 | 当前索引裸路径、行存在 | `` `live-target.md:3` `` | 退出 0，「裸路径行号锚 1 通过」 | 是 |
| V3 | 同目录多份 `rulings.md`（历史假失败之一） | `rounds/r1/note.md` 内 `` `rulings.md:2` `` | 退出 0，消歧到 r1，不报「不唯一」 | 是 |
| V4 | 外部取证仓唯一命中（历史假失败之二） | `` `adding-a-tool.md:1` `` | 退出 0，「裸路径行号锚 1 通过」 | 是 |

**已知悬空锚（期望退出 1，且硬失败信息对）——6/6 符合，不少于 3：**

| # | 用例 | 锚 | 期望 | 实际 |
| --- | --- | --- | --- | --- |
| D1 | 钉 commit、行号超出该版本 | `` `pinned-target.md @ SHA1:999` `` | 退出 1，「超出该版本行数 10」 | 是 |
| D2 | 裸路径、索引与外部皆无 | `` `never-existed-xyz.md:1` `` | 退出 1，「目标不在 git 索引里」 | 是 |
| D3 | 裸路径、行号超出当前文件 | `` `live-target.md:999` `` | 退出 1，「超出当前行数 5」 | 是 |
| D4 | 钉 commit、该版本无此文件 | `` `never-in-sha1.md @ SHA1:1` `` | 退出 1，「找不到唯一路径」 | 是 |
| D5 | 同名两份、参照方无法消歧 | `sunmoonai/docs/guide/ref.md` 内 `` `foo.md:1` `` | 退出 1，「无法消歧」 | 是 |
| D6 | 外部仓命中但行号超出 | `` `adding-a-tool.md:151` `` | 退出 1，「外部仓 … 只有 101 行」 | 是 |

对照用例：从活跃文档写 `` `rulings.md:1` ``（两份同名、不在同目录）硬失败，说明 V3 的通过不是「凡 `rulings.md` 都放行」。

未发现误报（有效当失败）或漏报（悬空当通过）。三次历史假失败对应的回归（V1/V3/V4）均按「应通过」通过。

复跑：仓在 `/tmp/ag-sandbox-cursor`，脚本即 opus 的 `anchor-gate.py` 逐字节拷贝。

### 7. 未动冻结物 — **满足**

```
git diff runtime/h1 opus -- sunmoonai/docs/dev-plan/rounds/runtime/task.md
```

空，退出 0，字节数 0。

---

## 三、未改判据的说明

第 1、4 条失败是产出缺口，不是标准腐坏：

- 第 1 条「不经 git 历史可读」是 C2 抬头自己立的删除条件，C4 提交说明声称已经满足。空标题说明声称不成立。
- 第 4 条「规范性引用改指新落点」是 C3 提交说明里的原则。S1 行未改。

两条都不构成「判据过期」。不建议改 §4；建议补产出后由同一验收方按同一七条重验。

---

## 四、覆盖声明

**查了**：对象哈希；opus 顶层文件清单；11 节原文（`7e8464c2`）与 C3/C4 落点对照；活跃文档对 `refact-fable.md` / `security-boundaries.md` 的引用；`task.md` vs `runtime/h1`；opus 树上两道门禁；独立沙箱 10 个锚点用例。

**没查**：`anchor-gate.py` 对路径含空格、短 sha 碰撞、`rounds/**` 软判汇总是否漏计硬失败之外的行为；C1–C3 各自单独是否曾满足过当时自陈的判据（本单元验收的是 C4 之后的树）；cursor / master 工作区残留的 C3 两份文件是否应在发布时删除（发布是 ⑦，不是本环节）。
