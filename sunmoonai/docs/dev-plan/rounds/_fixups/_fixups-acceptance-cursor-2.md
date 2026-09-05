参与方：cursor｜worktree：/home/zym/worktrees/cursor/k8s｜HEAD：c545141ddef33fbe619b69dad5111002b4d919fc

# ⑤b 重验：工作单元 `_fixups`（验收方 cursor，第 2 轮）

> 按 `_fixups-call-⑤b.md` 交付。同一验收方、同一冻结判据，对象换到 `opus` @ `41d78b2c`。
> 判定标准：`round.md` §4 七条（90 行，sha256[:16] `1e61358c9f9b7e95`），与第 1 轮逐字节一致，**未改任何一条**。
> 身份判别：`basename "$(dirname "$(git rev-parse --show-toplevel)")"` → `cursor`。
> 七条全判，不只复判上轮失败的三条。

## 结论（置前）

**通过。** 七条均满足。上轮三条缺口已补，且补产出没有再切掉原先完好的节。

| 条号 | 第 1 轮 | 本轮 | 一句话 |
| --- | --- | --- | --- |
| 1 内容零缺口 | 不满足 | **满足** | 11 节均可在活跃文档读到正文；补回的两节与原文逐行一致 |
| 2 无第二真源 | 满足 | **满足** | opus 顶层仍无三份旧文 |
| 3 分工合规 | 部分满足 | **满足** | 进度进 `handoff.md`，论证改为指针 |
| 4 引用形态 | 不满足 | **满足** | S1 改指新落点；活跃文档无 `security-boundaries.md` |
| 5 门禁 | 满足 | **满足** | 含补丁的 opus 树上两门禁仍退出 0 |
| 6 脚本自身可信 | 满足 | **满足** | `anchor-gate.py` 哈希未变，沿用上轮独立沙箱结论 |
| 7 未动冻结物 | 满足 | **满足** | `task.md` 相对 `runtime/h1` 仍逐字节一致 |

无条件。无「判据过期」。

---

## 一、取件与对象事实

在 `/home/zym/worktrees/opus/k8s` 复跑（该 `HEAD` 含 `41d78b2c`；`41d78b2c..HEAD` 未再改下列对象）：

| 对象 | 通知钉版 | 本人复跑 | 判 |
| --- | --- | --- | --- |
| `runtime-architecture.md` | 1062 行 `84d6b30963eebd5a` | 一致 | ✓ |
| `implementation-plan.md` | 93 行 `7c0da00d2c1aaf04` | 一致 | ✓ |
| `handoff.md` | 131 行 `92ffe44a01b71fd0` | 一致 | ✓ |
| `README.md` | 37 行 `11c2657b538641c9` | 一致 | ✓（与上轮相同） |
| `anchor-gate.py` | 125 行 `7c90c7f7bd6ded92` | 一致 | ✓（与上轮相同，未改动） |
| `round.md`（§4） | 90 行 `1e61358c9f9b7e95` | 一致 | ✓（与上轮相同，未改判据） |

11 节枚举沿用上轮：C2 抬头 8 行 + C3 随 §3.13 全节迁出的 §3.13.0 / §3.13.1 / §3.13.6。

---

## 二、七条逐条判定

### 1. 内容零缺口 — **满足**

不经 `git show`、打开 opus 树当前文件即可读到：

| 原文 @ `7e8464c2` | 新落点 | 正文 |
| --- | --- | --- |
| §3.13.2 三道边界 | `runtime-architecture.md` §4.4.1 | :665 起有表 |
| §3.13.3 回执仓对象模型 | 同文件 §4.4.2 | :681 起有目录树与规则 |
| §3.13.4 回执 schema | 同文件 §4.4.3 | :706 起有 yaml |
| §3.13.5 两台机器身份 | 同文件 §4.6.2 | :830 起有分布图 |
| §3.4 收件箱字段分级 | 同文件 §4.6.1 | :797 起有分级表 |
| §3.6 工单与 T0 任务类包 | 同文件 §2.2.1 | :119 起有 schema 与包纪律 |
| §3.7 工作区供给 provision | 同文件 §4.5.1 | :752 起有 `provision(...)` 函数、数量规则、三条判断。与原文 §3.7 正文 27 行**逐行相等** |
| §6 实施路线 R0–R5 | `implementation-plan.md` 阶段〇 | :53 起有路线表 |
| §3.13.0 取证声明 | `runtime-architecture.md` §4.7 | :877 起 |
| §3.13.1 现状事实 | 同文件 §4.7 | :848 段落后的现状表仍在 |
| §3.13.6 剩余风险 | 同文件 §4.6.3 | :860 起有 8 行风险表。与原文 §3.13.6 正文**逐行相等** |

上轮空标题（§4.5.1 / §4.6.3）已消失。新稿无其它空节标题。

**防「补 A 切 B」**：把上轮已判可读的落点（§2.2.1、§4.4 整节、§4.5 引言、§4.6.1、§4.6.2、§4.7）与 `e1a91e15` 逐节比对，**全部 SAME**（行数与正文一致）。这次只在两个空节里贴回了原文，没有再切邻节。

### 2. 无第二真源 — **满足**

```
git ls-tree --name-only 41d78b2c:sunmoonai/docs/dev-plan/
```

无 `refact-fable.md`、`security-boundaries.md`、`roadmap.md`。
`provision(...)` 与剩余风险表只在架构文档各出现一次；实施计划只持路线表，handoff 只持状态，无全文双写。

### 3. 分工合规 — **满足**

对照 `README.md` :26–34：

- 上轮点名的进度句（原实施计划「S1 进行中」）已迁入 `handoff.md` :98–116，并带路线表指针。handoff 写状态、不写实施步骤，符合它自己 :11–12 的声明。
- 上轮点名的 `bootstrap` / qoder 裁定论证长段已改为实施计划 :73–74 的指针，指向架构文档与 `rounds/refact-fable/rulings.md`。
- 架构文档仍无任务清单；§2.2.1 仍是 Task Profile 的输入形状，不是进度。

路线表单元格里残留的「§8 已冻结」是该行的前置条件，不是再写一份论证。

### 4. 引用形态 — **满足**

三条合取，本轮均成立。

**证据性引用钉 `@ 7e8464c2`**：活跃文档（`dev-plan/*.md`，不含 `rounds/**`）里所有 `refact-fable.md` 引用均为 `refact-fable.md @ 7e8464c2`（架构文档多处；实施计划 :55）。通过。

**规范性引用指向新落点**：上轮失败的 S1 两处已改。`implementation-plan.md:66` 现为 `runtime-architecture.md` §4.4 / §4.6 / §4.7。活跃文档对 `security-boundaries.md` 计数为 0。`:70` 的 `automation-roadmap.md` 是另一份既有文档，不在本条范围。

**裸路径行号锚 `refact-fable.md:<行>`**：活跃文档计数为 0。`rounds/**` 归档裸锚仍由门禁软判，不在本条范围。

### 5. 门禁 — **满足**

在含补丁的 opus 树上重跑（对象未被后续 commit 改动）：

```
cd /home/zym/worktrees/opus/k8s
python3 sunmoonai/docs/dev-plan/doc-gate.py --all
# doc-gate: 148 份文档通过
# 退出码 0

python3 sunmoonai/docs/dev-plan/anchor-gate.py
# 钉 commit 锚 13 通过；裸路径行号锚 95 通过；章节号引用 145 处（软判）
# 归档 rounds/** 92 处软判，不计失败
# 退出码 0
```

章节号软判由上轮 144 变为 145，属计数，不影响退出码。

### 6. `anchor-gate.py` 自身可信 — **满足**

`41d78b2c` 与上轮对象 `e1a91e15` 的 `anchor-gate.py` 均为 125 行、sha256[:16] `7c90c7f7bd6ded92`，**未改动**。按通知：直接引用第 1 轮验收 `_fixups-acceptance-cursor.md` §4-6。

上轮独立沙箱 `/tmp/ag-sandbox-cursor`：4 个已知有效锚（钉 commit 后删文件 / 当前索引裸路径 / 同目录 `rulings.md` 消歧 / 外部仓唯一命中）退出 0；6 个已知悬空锚（行号超出钉版本 / 文件不存在 / 行号超出当前文件 / 该 commit 无此文件 / 同名无法消歧 / 外部仓行号超出）退出 1。三次历史假失败对应回归均按「应通过」通过。脚本未变，结论沿用。

### 7. 未动冻结物 — **满足**

```
git diff runtime/h1 41d78b2c -- sunmoonai/docs/dev-plan/rounds/runtime/task.md
```

空，退出 0，字节数 0。

---

## 三、覆盖声明

**查了**：对象哈希与判据哈希；11 节原文对照 + 上轮已通过落点相对 `e1a91e15` 的逐节 SAME；活跃文档对 `refact-fable.md` / `security-boundaries.md` 的引用；`task.md` vs `runtime/h1`；opus 树上两道门禁；`anchor-gate.py` 相对上轮的哈希。

**没查**：`rounds/_spike-sign/forensics.md` 仍写 `security-boundaries.md` §2.0（归档产物，不在第 4 条「活跃文档」范围，也不在本轮对象表）；cursor / master 工作区是否仍跟踪 C3 残留文件（发布是 ⑦）；脚本在哈希未变前提下未重造沙箱。

**观察（不构成不满足）**：迁回的剩余风险表单元格仍用原文内部节号「（3.4）」「（3.13.4）」，不是文件路径引用，第 4 条不管它。
