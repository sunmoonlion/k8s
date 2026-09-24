# 持久化：什么存哪、谁是真源、留多久

> 真源只有一个写入面（`P1`、`I5`），其余都是可重建的投影。账在 PostgreSQL，正文在对象存储，会话在 Codex，密钥在密钥库，本机的在本机。

## 七类数据

| 类 | 内容 | 真源 | 存储 | 保留 |
| --- | --- | --- | --- | --- |
| **账与状态** | Task、Attempt、Interaction、方向盘、幂等账、预算账、副作用账、证据账、Environment、Sandbox、本地上限变更 | 工作台 | PostgreSQL，`investment-backend` 的逻辑库（`C-D2` 一个 App 一条迁移链） | 永久；法务留存是 `F-POS-05` 的依据 |
| **事件** | Session、Task、Attempt 的事件流；Outbox | 工作台 | PostgreSQL 事件表 + Outbox 表（现有） | 永久；网页按 cursor 回放（`AT-15`） |
| **产物 Artifact** | 步骤交回物、研究底稿、结果信封、覆盖前的备份版本 | 工作台 | 元数据在 PostgreSQL；正文在对象存储（`C-D4`，桶按领域归 investment）；**同时落用户工作区一份**，那份是用户的副本 | 永久；版本只增不改 |
| **会话记录** | Codex thread 的 rollout：第一层与第二层的全部 turn、工具调用、审批、token 用量 | **Codex**（`CODEX_HOME`） | 沙箱 pod 的 PVC | 与沙箱同寿命；PVC 丢了会话丢，账不丢 |
| **用户资料** | 显式上传或勾选上送的文件 | 知识服务 | `knowledge-app` 库 + 对象存储 | 用户删即删 |
| **密钥与令牌** | 用户模型 key、会合点令牌、app-server 能力令牌 | 密钥库 | k8s Secret（第一期）/ Vault | 撤换即失效；不入表、不入事件、不入日志（`I8`） |
| **本机** | 代理配置、白名单、上限、`status.json`、执行端 `CODEX_HOME` | 用户机器 | `~/.sunmoon-agent/` | 本机；卸载即无 |

## 第一层的会话怎么落

用户自驾时不建 Task，但两件事仍要持久：网页刷新后能看到历史，顾问接手时能看到用户做过什么。

- **给模型看的**是 Codex 自己的 thread（同一实例的机制，`wheel.md`）。它在沙箱的 `CODEX_HOME` 里，工作台不复制它的正文当真源（`C-D11`）。
- **给人看的**由工作台落成 **Session 事件**：只存 `item/completed`、`turn/started|completed`、审批请求与结论、`thread/tokenUsage` 这类**条目级**事件，流式的 delta 不存。每条带 cursor，网页回放靠它。
- 两者对不上时：显示以事件为准，模型行为以 thread 为准，两边都不改写对方。会话记录丢了（PVC 没了）用户只是不能"接着聊"，历史仍能看，账一分不少。

## 第二层多出来的

交出方向盘那一刻起，除 Session 事件外还写 Task 主档（`task-contract.md`）、Attempt、每步的 Artifact 版本、验收结论、预算流水。**交回物是版本化 Artifact 而不是聊天文本**（`AT-24`），所以第二层的持久内容不依赖会话记录存在。

## 真源与投影一览

```text
PostgreSQL（账、事件、Artifact 元数据） ──真源──▶ 网页视图、status、报表、评测样本      （可重建）
对象存储（Artifact 正文）               ──真源──▶ 用户工作区里的那一份                   （副本）
沙箱 CODEX_HOME（thread rollout）        ──真源──▶ 工作台的 Session 事件（条目级镜像）     （只增，不回写）
密钥库                                   ──真源──▶ 沙箱进程环境 / auth.json                （注入，撤换重启）
```

## 备份与恢复

| 存储 | 第一期 | 之后 |
| --- | --- | --- |
| PostgreSQL | 每日全量 + WAL；恢复演练是发布门（`constraints.md`「做数据迁移时」六条验收） | 同 |
| 对象存储 | 桶开版本化 | 跨机房复制 |
| 沙箱 PVC | **不备份**：会话可丢，账不可丢（`D18` 待定要不要备） | 看 `D9` 的资源模型 |
| 知识服务 | 随 `knowledge-app` 现有策略 | 同 |

## 与现有表的关系

`investment-backend` 现有 Run 状态机、事件表、Outbox/Inbox 是起点：Run 演进为 Task/Attempt 两层，事件表加 `session_id` 与 cursor，Outbox 不动。迁移按 `constraints.md`「做数据迁移时」的 expand → contract 走，不重建库。

## 未决

`D18`：沙箱会话记录（PVC）要不要备份、备多久；不备的代价是用户换沙箱后不能接着聊。
