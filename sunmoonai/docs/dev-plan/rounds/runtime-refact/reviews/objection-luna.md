# ④ 异议：`runtime-refact` 轮 · luna

> 身份：`luna`，由 `/home/zym/worktrees/luna/k8s` 的父目录名确定。
>
> 禁读声明：本环节没有读取 `sunmoonai/docs/dev-plan/agent-dev-refact.md`，遵守裁定 `R2`。

## 异议 1

| 项 | 内容 |
| --- | --- |
| **条目** | `disposition.md` 的 `A-3`（「cursor 同样违反 B4」被推翻） |
| **为什么错** | `A-3` 只回应了 cursor §3.4 的 `publisher COMPLETED` 一行，把注文「Side Effect 由人执行本地合并」解释成物理动作描述；但 luna 原评审明确锚定的是 cursor §5.1 与 §5.2。cursor §5.1 逐字写「人的 Attempt 无 checkpoint 义务」，已把人放回 Attempt；§5.2 的 H5 又逐字写「人执行该动作」，并在随后正文重申「H5 = 人做合并」。这不是仅描述当下物理事实，而是写进长期指导稿的角色与强制点设计，直接冲突于冻结 B4「人不是执行者；人的位置是 requester 与 principal」。因此，`A-3` 的理由没有覆盖被裁主张的实际证据。 |
| **应当是什么** | 将 `A-3` 改判为**成立**：cursor §5.1 的「人的 Attempt」与 §5.2/H5 的「人执行该动作／人做合并」均按 B4 判为硬冲突，对应段落不计分且不得吸收。裁决稿以 luna 为基座，未吸收这两处，因此无需据此改动裁决稿正文；应修正处置记录，保留本次改判及理由。该改判不改变机器可读处置表的接受条数，故不改变验收方计算。 |
| **可复跑证据** | 见下列三条命令：冻结任务书给出 B4；cursor 冻结提交给出两处冲突原文；luna 冻结评审证明原指控确实锚定 §5.1/§5.2，而非仅针对 §3.4。 |

```bash
git show runtime-refact/arbiter:sunmoonai/docs/dev-plan/rounds/runtime-refact/runtime-refact-task.md \
  | nl -ba | sed -n '174,185p'

git show d8fdb32a94c678f489481b861a9cc63e72184298:sunmoonai/docs/dev-plan/agent-dev-guide.md \
  | nl -ba | sed -n '353,400p'

git show 1ad29edb66f05a1031280b3a08deb8798e473e30:sunmoonai/docs/dev-plan/rounds/runtime-refact/reviews/review-luna.md \
  | nl -ba | sed -n '117,125p'
```

## 覆盖边界

- **查了**：`A-3`、冻结 B4、cursor 冻结提交中被 luna 原评审点名的 §5.1/§5.2、luna 冻结评审原文。
- **没查**：没有复核不属于 luna 主张的其他处置条目；没有逐行核对 64 行落点表；没有参与 ⑤ 验收。
- **未验证 ⚠**：未重新运行裁决稿的机械门禁；本异议只判处置是否忠实覆盖原主张。
