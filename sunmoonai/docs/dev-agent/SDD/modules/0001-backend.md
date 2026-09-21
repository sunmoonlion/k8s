# 0001-backend：后端

**承担**：受理、路由、编排、派发、中断与批准、验收、交付，以及持久化账与审计——
合同里归后端的那部分。它是**确定性控制面**：按 workflow 推进，状态与账只有一份、
在它自己的库里。

**不承担**：

- **不调用生成式模型**，也不请执行端代为判断；需要语义判断的环节派 Attempt 出去；
- 不中转模型请求，不接触用户 key；
- **看不到本地资料、文件名与结果正文**——结果到它这里已是密文（`F-CRYPTO-02`）。

**跑在**服务器上（FastAPI）。**信任域**：持久化账的**唯一权威写入面**。

**内部切七块**：`ledger` · `router` · `orchestrator` · `bridge` · `interrupt` ·
`acceptance` · `delivery`。中心与内部判断不朝外，其余各对一侧；只有 `ledger` 能改状态与写账。
关系与它们对着九站哪几站，见
[子任务的 `SDD/architecture/`](../submodules/0001-backend/SDD/architecture/README.md)。

**怎么建**：状态机加 outbox，**不引入图执行框架**——那会多出一份 checkpoint 状态，
与这里的状态机成为两个真源（`I13`）。后端不驻留内存状态，重启扫非终态对象即可恢复。

**和谁交互**：经通道 ④ 与桌面应用（提交、查询、取消、Task 级审查、结果密文），
经通道 ① 与本地 runtime（派发、续约、事件、副作用意图与回执）。接口见
[通道](../architecture/channels.md)，边界见 [数据流与信任边界](../architecture/trust.md)。

**要满足什么**见子任务 [`submodules/0001-backend/`](../submodules/0001-backend/PRD/requirement.md)。
