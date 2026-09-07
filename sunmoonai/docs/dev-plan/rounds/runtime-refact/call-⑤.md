# 环节通知 ⑤ 验收 ｜ `runtime-refact` 轮

> 组织者产物。**收到就开工。**
> 发给：**`kimi`**（验收方，由 ③ 处置表算出：排除裁决方 opus、排除基座作者 luna，
> 余下取「接受+部分接受」最少者——cursor 8 / qwen 4 / **kimi 3**。计算过程见 `disposition.md` 三，
> ④ 复算后不变，见 `disposition-objections.md` 三。**不得事后更换。**）

## 第一件事：确认你是谁

```bash
r=$(git rev-parse --show-toplevel 2>/dev/null) && basename "$(dirname "$r")" || echo "❌ 不在 git 仓内"
```

## 取件（一律按 commit）

```bash
git show runtime-refact/arbiter:sunmoonai/docs/dev-plan/agent-dev-guide.md
git show runtime-refact/arbiter:sunmoonai/docs/dev-plan/rounds/runtime-refact/disposition.md
git show runtime-refact/arbiter:sunmoonai/docs/dev-plan/rounds/runtime-refact/disposition-objections.md
git show runtime-refact/arbiter:sunmoonai/docs/dev-plan/rounds/runtime-refact/mechanical-results.md
git show runtime-refact/arbiter:sunmoonai/docs/dev-plan/rounds/runtime-refact/arbiter-selfcheck.md
git show runtime-refact/arbiter:sunmoonai/docs/dev-plan/rounds/runtime-refact/observations-opus.md
```

裁决方分支 HEAD = `420c1f06`。

## 你要交什么

落点：`sunmoonai/docs/dev-plan/rounds/runtime-refact/reviews/acceptance-kimi.md`

**按任务书 §8 冻结的判据逐条给结论**，机械条 M1–M7 与判断条 J1–J8 一条不漏。

三条硬规矩：

1. **只能按冻结的判据判**，不得为通过而静默修改判据；
2. 判某条是「**判据本身过期**」要**写明理由交裁决方处置**，不得自行改；
3. **判不了的显式标出**，不许默认通过。

## 本轮请重点验的四处

⚠ **裁决方本轮自查错误已达六条，形态相同（覆盖不全 / 凭印象选检查点），
且两个方向都出现过——既冤枉过合规者，也替违规者开脱过。
请把「裁决方的判据」本身当作验收对象之一。**

1. **三条改判是否又过头。**④ 处置里三条全是推翻裁决方（`A-3`、`O-4a`、`O-4b`）。
   尤其 `A-3`：裁决方保留了「`cursor:229` 不构成违反」，只把 §5.1 判为成立——**这个区分对不对**；
2. **验收方计算**（cursor 8 / qwen 4 / kimi 3）。**你是被算出来的那一家**，
   若归属算错，人选就错。⚠ 这一条你有既得利益，**请写明你是怎么排除自身偏向的**；
3. **落点表 64 行，裁决方只打开正文逐行核过 3 行**。其余 61 行未核，是本轮覆盖的已知边界；
4. **`O-4b` 的后果尚未改进裁决稿正文**——§6 仍写并发语义「验不了」，
   而产品仓已有测试全过。这是**已知未完成项**，按「产物发布后本环节内不得再改」留到 ⑦ 或另起修订单元。
   **请判定：留到 ⑦ 是否可接受，还是必须在本轮内处理。**

## 仍然生效的约束

- **不得读 `agent-dev-refact.md`**（裁定 `R2`）。⑤ 不解除。在验收稿里声明是否遵守。
- 交付后不得再改。

## 交完之后

```bash
python3 sunmoonai/docs/dev-plan/protocol/round-status.py --round runtime-refact
```

⚠ **本次由所有者交互式投喂**（裁定 `R8`），因此**你能够自己提交**——
请自己 `git add` + `git commit`，不要留给组织者代提交。
自己提交的验收稿，作者归属可从提交推出，比代提交高一档。
