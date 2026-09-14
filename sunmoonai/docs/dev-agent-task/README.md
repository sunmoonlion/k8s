# agent 开发任务

每一层都是同一个模式，各家任务通用：

- `composition/`：本层的组成设计——整体怎么划分、各部分承担什么、彼此怎么交互；
- `components/`：各组成部分，每个部分是一个子任务，内部递归同一模式；叶子任务没有 `components/`。

任何一层用到哪个开发阶段，按 [`dev-process/`](../dev-process/) 的规范写。

本任务的生命周期见 [request-lifecycle.md](../dev-plan/working/request-lifecycle.md) 第 5 节；叶子目录名保留阶段编号。
第一层分前端与后端，Agent / runtime 与验收器归后端（所有者 2026-09-14 定）；责任划分依合同第 9 节。

```text
composition/                      前后端的划分与交互、总体设计
components/
├── frontend/
│   ├── composition/
│   └── components/  01-submit · 05-interaction · 07-result
└── backend/
    ├── composition/
    └── components/  02-intake · 03-queue-delivery · 04-agent-execution
                     05-interrupt-resume · 06-acceptance-commit · 07-delivery-retry
```
