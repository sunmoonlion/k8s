# `refact-fable.md` §8 九条的处置对齐（runtime 轮）

> 本节原在 runtime 轮最终稿 §7。**移出理由**：它是**轮次处置**，不是架构内容——
> 架构文档不应依赖一份已被推翻、且即将从活跃文档集中删除的文档。
> 移出后 `runtime-architecture.md` 自足：对 `refact-fable.md` 的引用全部钉 `@ 7e8464c2`，
> 删除该文件不影响任何一条可复跑。
>
> 被引对象：`refact-fable.md @ 7e8464c2`（927 行，sha256[:16] `89303624bfd9ef27`）。
> 该文件已于本工作单元从 `dev-plan/` 删除；内容在 commit `7e8464c2` 与轮次归档
> `rounds/refact-fable/` 中，`git show 7e8464c2:sunmoonai/docs/dev-plan/refact-fable.md` 可取。


| 条 | `task.md` §7 处置 | 本稿落点 |
| --- | --- | --- |
| 1 五词唯一、router / orchestrator 无 agent 实现 | 留 | §2.1；登记表 `roles_allowed` 无此二词 |
| 2 权力表 ≤10 行、强制点在凭据层或回执仓 | 留且变强 | §2.4 八行；H5 凭据层；**无强制点的行不进表**（H0 已移出） |
| 3 `RUNNING` 判据留、归因改 | 改 | §4.3 第 4 条 |
| 4 (a)(b)(c) 只有一套状态机 | (c) 扩为两态共用同一 schema | §2.5 映射表；§2.7 轨迹 schema 两态共用 |
| 5 T0/T1/T2 = 0/1/2 触点 | 留 | §2.2；⚠ **本轮 H1+H2 实发 1 次触点，与「T2 = 2」不符**，登记为观察值 |
| 6 判据锚在 credential domain 之外 | 留变强 | §4.6：principal 通道也登记等级 |
| 7 `migration-map.md` | **作废** | 本稿不画文件树（`task.md` §4 不受理） |
| 8 新判据首跑与人工对照 | 留 | §2.6 拆除条件 validator 行 |
| 9 取证栏冻结前重跑 | 留 | §4.5 两则现场证据 |

---

