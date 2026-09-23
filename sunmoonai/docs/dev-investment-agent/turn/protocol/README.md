# `protocol/` —— 多方竞争的规范与操作

这里的东西分**两类**，性质不同，不要混：

| 类 | 文件 | 什么时候会变 |
| --- | --- | --- |
| **规则** | [`competition-protocol.md`](competition-protocol.md) | 改规则时才变。**与「谁做」无关**——这一格脚本化之后，规则照样是这一份 |
| **操作** | [`GO.md`](GO.md)、[`competition-operations.md`](competition-operations.md) | ⚠ **随「派发这一格谁做」而变**。现在这一格是人做（人投喂、人组织、人确认），所以有这两份；那一格脚本化之后，**它们退役，不是被另一份取代** |

哪一格现在谁做，见 [九站](../../pipeline.md) 那张表。

| 文件 | 是什么 |
| --- | --- |
| [`competition-protocol.md`](competition-protocol.md) | **规范本体**：一次多方竞争怎么走、谁能做什么、判据是什么 |
| [`GO.md`](GO.md) | 各家每个环节的入口：你是谁 → 哪个环节 → 读通知 → 四条不能违反的 → 卡住怎么办 → 交卷 |
| [`competition-operations.md`](competition-operations.md) | 操作闭环：各环节谁做、产物放哪、投喂怎么投、所有者的确认怎么认 |

**要不要开一次竞争**（档位判据）见 [多方竞争](../competition.md)。
谁参赛、谁裁决、谁验收，写在每次竞争自己的 `round.md` 里，不另设登记表。
每次竞争的记录放在所属任务的目录里。

⚠ **产品侧怎么把这件事做成能力**，不在这里；第一期不做（`C-A10`），旧设计见
[`tree-build-v1` 的 `0008-competition`](../../tree-build-v1/SDD/submodules/0001-backend/SDD/modules/0008-competition.md)。
两者要满足的意图相同，但**操作步骤不可互抄**：这里写的是人怎么做，那里写的是程序怎么做。
