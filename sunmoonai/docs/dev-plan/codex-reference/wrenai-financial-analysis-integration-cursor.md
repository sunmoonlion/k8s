# WrenAI × 问数主链（Cursor 版）

> 最后更新：2026-09-02
>
> 性质：个人决策底稿，非 baseline、非 REQ。
> 总稿已定：问数走受管 SQL（Wren 一类语义层）。`sqlbot-cursor.md` 已定：
> 不切换到 SQLBot 的 prompt 链。本文补「Wren 现在是什么、六个工具怎么挂、
> 防护缺哪一块」。
>
> 取证：`/home/zym/repo/WrenAI` @ `5f8bc24e`（2026-05-24，本机 fork）。

## 结论

WrenAI **能接、该接**，形态比 SQLBot 贴合：它是给 agent 用的语义层 + SDK，
编排权留在我们的 LangGraph 里。

必须同时做四件事，缺一不可：

1. `strict_mode = True`（默认是关的）
2. **自己补语句类型白名单**，最好再加只读库账号
3. `wren_dry_plan` 与 `wren_query` 分开走，中间可以对人批准
4. SQL、MDL 版本、as-of、结果引用进证据账，并计入 `RunBudget`

准确率本轮**未评估**。没有 20 题金标准之前，这是选型空话，不能当已验证能力。

## 0. 版本先说清楚

盘上这份停在 `5f8bc24e`（2026-05-24）。README 自述：Wren Engine 并进 `core/`，
旧 GenBI 应用冻在 `legacy/v1`。我们要接的是**现在的语义层**，不是冻住的
ChatBI 应用。

上游三个月的变化未纳入。结论只对这份 fork 负责。复核上游时重新跑 §5 的
命令，不要凭记忆。

## 1. 它现在是什么

```text
core/wren        Python 主服务 / CLI
core/wren-core   DataFusion SQL 引擎
core/wren-mdl    MDL：模型、列、关系、度量
sdk/wren-pydantic / sdk/wren-langchain   给 agent 的工具包
```

MDL 是「数据是什么意思」的声明。agent 拿 MDL 生成 SQL，不拿裸表。

| | SQLBot | WrenAI（这份） |
| --- | --- | --- |
| 形态 | 自带 chat 的应用 | 库 / 工具包 |
| 谁编排 | 它自己 | **我们的图** |
| 口径 | 提示词里的 DDL / 术语 / 示例 | MDL 显式声明 |
| 合不合我们 | 重复一条主链 | 挂在已选定的问数静态图上 |

投资研究要能答「这个数字怎么来的」。显式建模比向量召回好交代。这就是总稿
不换 SQLBot 路线的原因，这里给它钉死。

## 2. 六个工具，挂在已有问数图上

`sdk/wren-pydantic/src/wren_pydantic/_tools.py` 写明运行时三件套：
`wren_query` / `wren_dry_plan` / `wren_list_models`。记忆侧另有
`wren_fetch_context` / `wren_recall_queries` / `wren_store_query`。

和 `sqlbot-cursor.md` 那条挂法对齐，不要另开 ReAct 自由调用：

```text
术语解析（我们的节点）
  → list_models / fetch_context
  → 召回已确认示例（recall，可空）
  → 生成候选（只许对 MDL 提问）
  → wren_dry_plan          ← 硬门，不过就停
  → （可选）人批准
  → wren_query
  → 写查询 Artifact + ChartSpec
  → 人确认后才 wren_store_query
```

**`dry_plan` 与 `query` 分开是一等能力。** 只规划不执行，正好对上已有
approval。禁止为了「少一次 RPC」合成一个 `generate_and_run`。

`wren_query` 的行数上限会经 `ModelRetry` 回喂模型，并告诉它去聚合。错误
带修正建议，比 pilot 链直接 `failed` 对 agent 友好。可以学这个回喂，但
**不能用重试代替 dry_plan 硬门**。

`include_memory_write=False` 可去掉写入工具。生产默认关掉写，确认过的
few-shot 由我们的节点显式调用 `store`。

## 3. 防护：维度不错，默认等于没有

`core/wren/src/wren/config.py`：

```python
strict_mode: bool = False
denied_functions: frozenset[str] = field(default_factory=frozenset)
```

`policy.py` 的 `validate_sql_policy()`：`strict_mode` 才检查表是否在 MDL 里；
`denied_functions` 才封函数。两条默认都不生效。

即使打开 `strict_mode`，它管的是「能碰哪些模型」，**不管语句类型**。
`DELETE FROM <MDL 里的模型>` 过得了表白名单。SQLBot 默认开的是操作白名单，
两边互不覆盖。

接入清单：

1. 配置 `strict_mode = True`
2. 我们自己拒非 SELECT / WITH（sqlglot 或等价物）
3. 数据库账号只读
4. 出站只打 Wren，不把业务库连接串交给模型

## 4. 和总稿、SQLBot 文怎么接

- 术语库、few-shot、ChartSpec、MCP：仍按 `sqlbot-cursor.md`，落在 Wren 图上
- few-shot 用 Wren 已有的 store/recall，不另建一套 NL→SQL 库
- MCP 只是同一条受管问数控制面的另一扇门，不为它再做 `generate_sql`
- 排期：轨 B 有样例库 → 术语 + 手塞金标准 → dry_plan/query 接线 → ChartSpec
  → 主链 20 题过了再 MCP。沙箱和 Wren 不要抢同一份预算缺口

## 5. 复核命令

```bash
cd /home/zym/repo/WrenAI
git log -1 --oneline
sed -n '1,40p' core/wren/src/wren/config.py
sed -n '1,20p' sdk/wren-pydantic/src/wren_pydantic/_tools.py
rg -n "strict_mode|denied_functions" core/wren/src/wren
```

## 6. 边界

- 未评估准确率（与 SQLBot 文同一空白）
- 未装 SDK、未起服务、未跑工具
- 未读 Rust 引擎与 `mdl.schema.json` 本体
- 「无语句类型限制」是换关键词没找到，属最弱证据；以只读账号兜底
- 未跟踪上游 2026-05 之后的提交
