# ④ 异议 ｜ `dev-plan-refact` 轮 ｜ kimi

就处置记录 §二 中出处为 `kimi` 的 4 条可异议条目：2 条有异议，2 条无异议。

## 异议 1

| 项 | 内容 |
| --- | --- |
| 条目 | kimi｜S3/S6 把工单字段齐全、落点齐全归 round-status｜拒绝 |
| 为什么错 | 拒绝理由（处置记录 §一 第 4 行）反驳的是「普通工作单元字段齐全检查」和「260 行落点检查」——这两个说法来自 `review-luna.md` K1 的转述，不在我原文 L127/L131 里。我 L131 的原文是「S6 落点齐全 / 状态推导｜机器｜`round-status.py`（从产物反推，不看声明）」，而 `round-status.py` 的 `stage_table` 恰好就是按工单配置的产物路径逐条查 `committed()`（git 提交，不看工作区）、环节状态全部由提交推导——与我的断言逐字吻合。裁决稿自己也在 `pipeline.md:74` 写下「`round-status.py` 只判轮次产物是否作为 git 提交出现」，即接受了我 S6 断言的全部内容；处置记录却以同一断言为由拒绝该条目，处置内部不一致。S3 一侧，脚本 `main()` 对 `round.md` toml 块缺 `final_path`/`round_dir`/`prefix` 直接拒绝判定、输出首行印出从工单解析的档位，「`round-status.py` 解析 `round.md`」这一载体断言成立；但「字段齐全」按全部协议字段理解确实超出实现，此部分我认超称。 |
| 应当是什么 | 改判**部分接受**。接到：round-status 判轮次产物按工单配置落点作为 git 提交出现、环节状态从提交推导不看声明、`round.md` 缺必需字段即拒绝判定、档位从工单解析留痕。止于：普通任务工单（目标/实施/测试/验收/回滚）字段齐全检查、260 节逐项安置检查——此两项我原文未主张，脚本也确实没有。 |
| 证据 | 可复跑：`( cd ~/master/k8s && python3 sunmoonai/docs/dev-plan/protocol/round-status.py )`——输出「缺：opus、luna、kimi…」即从 git 提交推导的落点状态。`~/master/k8s/sunmoonai/docs/dev-plan/protocol/round-status.py:73`（`committed`：查提交不看工作区）、`:325`（`stage_table` 文档字符串「判据即命令，结论只依赖 git 提交」）、`:628`（缺字段 `die`）。我原文 `~/worktrees/kimi/k8s/sunmoonai/docs/dev-plan/pipeline.md:131`。裁决稿自认 `~/review/dev-plan-refact-③裁决稿/sunmoonai/docs/dev-plan/pipeline.md:74`。 |

## 异议 2

| 项 | 内容 |
| --- | --- |
| 条目 | kimi｜决定索引文件 `rounds/decisions-index.md`｜部分接受 |
| 为什么错 | 处置写「双失败检查并进 luna 已有检索器」，但并进后的检查与已被**接受**的我方 Q9 条目（「索引两个方向都能失败」）冲突：裁决稿检索器里唯一的断言是 `assert old == 26 and len(ids) == len(set(ids))`——`old == 26` 只钉死旧三轮计数，全局无重复只覆盖「索引无重复 ID」一个方向；对**本轮及今后轮次**的裁定（`current`）只计数、不设任何断言，删掉或新增一条当前轮裁定行，检查照样通过。「锚点存在」方向因索引是现算生成而恒真，等于没有检查。luna 在 ② 也已指出该检索器「锁在四份冻结 rulings……不能自动发现之后的新轮外决定」。即：并进后的形态不满足我自己已被接受的判据。 |
| 应当是什么 | 维持部分接受，但把「接到哪」改为：检索器对当前轮裁定同样设可失败断言（把当前轮裁定条数或逐条 ID 钉进可核对配置），使「档案→索引」方向对当前轮也能失败；否则保留一份受同样双向核对的索引文件。 |
| 证据 | `~/review/dev-plan-refact-③裁决稿/sunmoonai/docs/dev-plan/dev-plan-architecture.md:736`（唯一断言，只对旧三轮计数与全局去重）；同文件 `:738`（`current` 只打印不断言）。旁证 `~/master/k8s/sunmoonai/docs/dev-plan/rounds/dev-plan-refact/reviews/review-luna.md:165`。 |

## 无异议的条目

- **kimi｜protocol 不是实施计划｜部分接受**：接到「调用附件 + 横切常驻 + 物理独立、不并进 IMPL 目录」为止，与我三条举证（生命周期/读者/内容种类）的结论一致，裁决稿 `pipeline.md:211` 落实无误。
- **kimi｜Q8 落 `docs/evidence/<task-id>/`｜部分接受**：产品仓 `docs/evidence/` 原地保留与我的举证（`implementation-plan.md` 交付规则已定义该位置）一致；轮外工作改落 `records/work/` 属裁决方裁量内的设计取舍，无事实冲突。
