# SDD：软件设计说明（Software Design Description）

回答「怎样满足 PRD」。按 IEEE 1016，SDD 同时覆盖架构设计与详细设计；本阶段不再分 TLD 与 SDD：
总体还是详细，由这份设计在需求树里的层次决定，不由阶段名决定。

- **结构层**（有子任务的节点，如 [`../../dev-agent-task/architecture/`](../../dev-agent-task/architecture/)）：
  模块怎么划分、模块之间的关系与接口、共同约束和取舍。
- **组成层**（单个模块，如 `dev-agent-task/modules/` 下各目录）：模块内部结构、协议与数据、失败与恢复。

层次是相对的：一个模块再往下拆时，它自己的设计对子模块就是结构层。

本阶段的通用规范。尚未编写。
