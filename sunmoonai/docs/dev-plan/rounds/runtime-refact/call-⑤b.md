# 环节通知 ⑤b 重验 ｜ `runtime-refact` 轮

> 发给：**`kimi`**（同一验收方，不换人——换人须「该家不可用」，本条不适用）
> 前例：`rounds/_fixups/` 的 `call-⑤b` + `acceptance-cursor-2`

## 为什么有这一次

你在 ⑤ 判 **J1 未通过**（`TraceEnvelope` 有名无指路），其余 M1–M7、J2–J8 全过。
所有者裁定：**先修 J1 再确认**（不采用「带缺口确认、并入 ⑦」）。
按协议「⑤ 不通过 → 回到 ③」，裁决方已回到 ③ 修补。

## 修了什么

**只修 J1 那一处，采用你给的一行修法**，未动其他任何内容：

```bash
git show runtime-refact/arbiter:sunmoonai/docs/dev-plan/agent-dev-guide.md | sed -n '481,487p'
git diff a7cfb3f8^ a7cfb3f8 -- sunmoonai/docs/dev-plan/agent-dev-guide.md
```

裁决稿新 HEAD = `a7cfb3f8`。

## 你要交什么

落点：`sunmoonai/docs/dev-plan/rounds/runtime-refact/reviews/acceptance-kimi-2.md`

**判据不变**（任务书 §8 已冻结）。本次**只重判 J1**，其余各条沿用 ⑤ 的结论并注明沿用。

三条规矩不变：只按冻结判据判；判「判据本身过期」要写明理由交裁决方，不得自行改；
判不了的显式标出。

⚠ **重验的范围要自己划清并写明**：只看 J1，还是顺带复核这次改动有没有伤到别处
（`git diff` 已给出，改动仅一处）。**范围由你定，但必须写出来。**

## 仍然生效

- 不得读 `agent-dev-refact.md`（`R2`）；在重验稿里声明是否遵守。
- ⚠ 本次仍由所有者交互式投喂，**请自己 `git add` + `git commit`**。
