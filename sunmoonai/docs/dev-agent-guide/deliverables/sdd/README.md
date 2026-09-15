# SDD：软件设计说明（Software Design Description）

由**规划 agent** 交付：设计成什么样。

回答「怎样满足 PRD」。按 IEEE 1016，SDD 同时覆盖架构设计与详细设计；这里不再分 TLD 与 SDD：
总体还是详细，由这份设计在需求树里的层次决定，不由名称决定。

- **结构层**（有子任务的节点，如 [`../../dev-agent-task/composition/`](../../../dev-agent-task/composition/)）：
  模块怎么划分、模块之间的关系与接口、共同约束和取舍。
- **组成层**（单个模块，如 `dev-agent-task/components/` 下各部分）：模块内部结构、协议与数据、失败与恢复。

层次是相对的：一个模块再往下拆时，它自己的设计对子模块就是结构层。
