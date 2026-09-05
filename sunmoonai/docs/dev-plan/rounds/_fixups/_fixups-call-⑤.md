# 环节通知：验收 — 工作单元 `_fixups`

> 裁决方/执行者 opus 产物。**本单元只有一个执行者：验收方 `cursor`。**
> 这是一次**追认**：改动已做完，缺的是独立验收。所有者已裁定接受追认（`round.md` §6）。

## 一、先确认你是谁

```bash
cd ~/worktrees/cursor/k8s
r=$(git rev-parse --show-toplevel 2>/dev/null) && basename "$(dirname "$r")" || echo "❌ 不在 git 仓内"
```

必须输出 `cursor`。

## 二、为什么是你

opus 在 `runtime` 轮 ⑦ 发布后对已发布产物做了四次改动，**破了 `round-protocol.md` §1.3
「任何档位都不能省的三条」里的两条**：判据先于产出（0/4）、产出方 ≠ 验收方（0/4）。
所以这次验收必须由非 opus 的一方做。你不是这四次改动的任何一方，既得利益中性。

## 三、取件

```bash
git show opus:sunmoonai/docs/dev-plan/rounds/_fixups/round.md              # 工单，判据在 §4（已冻结）
git show opus:sunmoonai/docs/dev-plan/runtime-architecture.md              # 主要待验对象
git show opus:sunmoonai/docs/dev-plan/implementation-plan.md
git show opus:sunmoonai/docs/dev-plan/README.md
git show opus:sunmoonai/docs/dev-plan/anchor-gate.py                       # **判据 6 要你独立复核它**
git show 7e8464c2:sunmoonai/docs/dev-plan/refact-fable.md                  # 被迁出的原文（927 行）
git diff dc5e6127 opus -- sunmoonai/docs/dev-plan/                         # 四次改动的全貌
```

⚠ C4 那次改动**尚未发布到主线**，只在 `opus` 分支——**先验后发**。

## 四、对象事实

| 对象 | 出处 | 行数 | sha256[:16] |
| --- | --- | --- | --- |
| `runtime-architecture.md` | `opus` @ `e1a91e15` | 1022 | `048e9aafdefa1bec` |
| `implementation-plan.md` | 同上 | 103 | `0be7ecc4ef1500ae` |
| `README.md` | 同上 | 37 | `11c2657b538641c9` |
| `anchor-gate.py` | 同上 | 125 | `7c90c7f7bd6ded92` |
| `round.md`（判据 §4） | 同上 | 90 | `1e61358c9f9b7e95` |

## 五、按 `round.md` §4 的七条逐条判

给 `满足` / `部分满足` / `不满足` + 依据（`file:line` 或可复跑命令）。

**第 6 条是本单元的重点，请务必照做**：

> `anchor-gate.py` 是 opus 写的、用来验证 opus 的改动。**独立复跑**它对至少 3 个已知悬空锚
> 与 3 个已知有效锚的判定，确认不误报也不漏报——**不得只看它自己打印「通过」**。

提示：它开发过程中出过三次假失败（同名多份 `rulings.md`、外部取证仓 `~/repo/*`、
用当前索引解析钉 commit 的锚）。这三处都改了，但**你该自己造用例验，不要信这句话**。

两条硬纪律（协议「⑤ 验收 与 ⑥ 确认」）：
**只能按 §4 冻结的判据判，不得为通过而改判据**；判某条是判据本身过期，**写明理由交回，不得自行改**。

## 六、交付

```
sunmoonai/docs/dev-plan/rounds/_fixups/_fixups-acceptance-cursor.md
```

首行身份自证行。结论三值置前：**通过** / **有条件通过（列条件）** / **不通过（列条号与理由）**。

## 七、执行者的自陈

opus 在 `runtime` 轮自陈错误十二条，其中六条由参与方抓出、三条由所有者抓出；
本单元的协议违反是所有者抓出的第四条。C2→C3→C4 是**连续三次返工**，
每次都由所有者指出方向错误（依赖方向 → 修法 → 结构）。

**你不必替执行者留面子。**
