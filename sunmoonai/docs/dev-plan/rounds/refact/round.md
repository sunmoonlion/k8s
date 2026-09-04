# 轮次 refact：重写 `working/development-lifecycle-agent.md`

> 本文件是本轮**唯一**的可变参数来源。不变的流程规则在
> [`../../round-protocol.md`](../../round-protocol.md)，不在这里重复。
>
> ⚠ **本轮开始于 `round-protocol` 改造之前**，产物落在旧路径 `working/` 而非
> `rounds/refact/`；本文件是**回填**的，用于让 `round-status.py` 能判定这一轮。
> 路径迁移不在本轮做——协议自己规定「任务书冻结后不得中途修改」。

```toml
round_id  = "refact"
status    = "ACTIVE"
tier      = "T2"
final_path = "sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md"
round_dir  = "sunmoonai/docs/dev-plan/working"
prefix     = "refact"
baseline   = "f8bc48e3"
proposers  = ["luna", "kimi", "cursor", "qwen"]
arbiter        = "opus"
arbiter_branch = "refact-integration"
acceptor       = "qwen"
excused_objection = ["kimi"]
```

## 档位裁定

**T2**，命中两条判据：**权威层**（本文是 `AGENTS.md` 指定「开发 Agent 接任务前必须读取」
的文档，会成为后续开发的依据）与**已知对立**（五份 2026-09-02 提案稿对执行层路线已有互不
相容的主张）。

## 题目与验收标准

见 [`../../refact-task.md`](../../refact-task.md)。验收标准是该文 §12 的 11 条，**已冻结**。

## 角色

| 角色 | 谁 | 依据 |
| --- | --- | --- |
| 提案 / 评优 | luna、kimi、cursor、qwen | 任务书 §13 |
| 裁决与整合 | opus（不参赛、不写评审、不验收） | 任务书 §13 |
| 验收 | **qwen** | 裁定 R2：原指定 kimi 经 R1 免除属「不可用」，按顺位 `kimi(4)→qwen(5)→cursor(12)` |
| 确认 | 项目所有者 | 人，手动 |

裁定记录：`refact-integration:sunmoonai/docs/dev-plan/working/refact-rulings.md`（R1、R2、R3）。
**跨分支产物不写成 markdown 链接**——`doc-gate.py` 按当前分支的 git 索引判定，链到别的分支必然失败；
按「取件与检视面」的规矩写「分支:路径」即可。

## 待自动化

按 `round-protocol.md`「执行者与触发方式」，本轮实际由人做、但归类为「可自动」的动作：

| 动作 | 本轮由谁做 | 阻塞点 |
| --- | --- | --- |
| 把「继续」送到各参与方 | 项目所有者手动粘贴 | **阻塞在通道，不在脚本**：cursor 与 qoder(qwen) 是 GUI 应用，无命令行入口；kimi 与 luna 走 VS Code 插件、由 cc-switch 全局切换配置，并行调用会串号。四家里最多覆盖一到两家 |

**空着不等于没有，等于没记**——上表是本轮的自动化欠账，附具体阻塞原因。
