# WrenAI：能不能、该不该接进 investment-app

> 取证时点：2026-08-28 ｜ 作者：opus
> 源码：`/home/zym/repo/WrenAI` @ `5f8bc24e`（2026-05-24，`sunmoonlion/WrenAI` fork）
>
> 本文取代此前的 `wrenai-not-assessed-opus.md`（当时本机无源码，故有意留空）。

## 0. ⚠ 两条必须先说的版本事实

### 0.1 盘上这份落后上游 202 个提交 / 3 个月

```
本地（fork HEAD）  5f8bc24e  2026-05-24
上游 Canner/WrenAI 56e007da9b 2026-08-27   ← 落后 202 个提交
```

本文对**盘上这份**取证。上游三个月的变化未纳入，
下述结论在上游是否仍成立**未复核**（复核方法见 §7）。

```bash
cd /home/zym/repo/WrenAI
git remote add upstream https://github.com/Canner/WrenAI.git 2>/dev/null
git fetch -q upstream && git rev-list --count HEAD..$(git ls-remote upstream HEAD | cut -f1)
```

### 0.2 更要紧：WrenAI 已经转型，此前基于旧版的分析可能整体失效

README 自述（2026-05-07 公告）：

> **The open context layer for AI agents over business data.**
> Wren Engine has merged into this repo under `core/`.
> **The previous WrenAI GenBI app is preserved on the `legacy/v1` branch (tag `v1-final`).**

即：**过去那个 GenBI / Text-to-SQL 应用已被冻结在 `legacy/v1`**，
现在的 WrenAI 是**给 agent 用的语义上下文层 + SDK**。

**这条对本项目有直接影响**：kimi 与 qwen3.8 的
`wrenai-financial-analysis-integration-*.md` 写于 2026-08-17。
若它们分析的是 GenBI 形态，那分析的是一个**已被冻结的分支**；
若分析的是新形态，则与本文可比。**我没有读它们的正文，无法判断是哪种**——
这一点需要人来核对。

## 1. 它现在是什么

```
core/wren           88 个 py    主服务与 CLI
core/wren-core      68 个 rs    SQL 引擎（DataFusion 53）
core/wren-mdl       mdl.schema.json  ← MDL：建模定义语言，就是"语义层"本身
sdk/wren-pydantic   给 Pydantic AI 的工具包
sdk/wren-langchain  给 LangChain 的工具包
skills/             wren-dlt-connector
```

**核心概念是 MDL**——用一份声明描述"你的数据是什么意思"（模型、列、关系、度量），
agent 拿着 MDL 而不是裸表结构去生成 SQL。

**与 SQLBot 的本质区别**：

| | SQLBot | WrenAI v2 |
| --- | --- | --- |
| 形态 | **应用**：问答 UI + 后端，自带 chat 流程 | **库/工具包**：给你的 agent 用 |
| 集成方式 | 调它的 MCP 端点 | `pip install` 它的 SDK，拿到 toolset |
| 谁编排 | 它自己 | **你的 agent** |
| 语义层 | RAG 检索 schema | MDL 显式声明 |

**这个区别决定了选型**：投资研究 agent 的编排逻辑在我们自己手里
（LangGraph），SQLBot 那种"自带 chat 流程"的形态是重复；
WrenAI 的"给你三个工具"形态更贴合。

## 2. 集成面：三个运行时工具

`sdk/wren-pydantic/src/wren_pydantic/_tools.py` 的模块 docstring 直接写明：

```
Runtime tools (wren_query, wren_dry_plan, wren_list_models) for Pydantic AI.
```

| 工具 | 作用 |
| --- | --- |
| `wren_query` | 经语义层执行 SQL，返回行 |
| `wren_dry_plan` | 经 MDL 规划，返回**目标方言的 SQL**（不执行） |
| `wren_list_models` | 列出本项目的模型与列数 |

另有记忆侧（`_tools_memory.py` / `_memory_api.py`）：`wren_store_query` 可持久化查询，
且提供**只读模式**——`include_memory_write=False` 会把它从工具集里去掉。

**两个设计细节值得抄**：

1. **`wren_dry_plan` 与 `wren_query` 分开**——"只规划不执行"是一等能力。
   这让 agent 可以先拿到 SQL 给人看、批准后再执行，天然适配 human-in-the-loop。
   investment-app 的 pilot 链已有 approval 环节，这个分离正好对得上。
2. **行数上限带引导语**：

```python
if limit < 1 or limit > MAX_QUERY_ROWS:
    raise ModelRetry(
        f"limit must be between 1 and {MAX_QUERY_ROWS} (got {limit}). "
        "Aggregate in SQL if you need more rows."   # ← 告诉模型该怎么改
    )
```

错误经 `ModelRetry` 回喂模型并附带**可执行的修正建议**，
而不是简单报错。这比"拒绝 + 错误码"对 agent 友好得多。

```bash
sed -n '1,20p' sdk/wren-pydantic/src/wren_pydantic/_tools.py
sed -n '/def _run_query/,/row_count/p' sdk/wren-pydantic/src/wren_pydantic/_tools.py
```

## 3. 安全边界：机制不错，但**默认不开**

### 3.1 它的防护长什么样

`core/wren/src/wren/policy.py` 的 `validate_sql_policy()`，两条策略：

```python
if config.strict_mode:
    _check_tables(ast, model_names)      # 只允许引用 MDL 里声明的模型
if config.denied_functions:
    _check_functions(ast, config.denied_functions)
```

`_check_tables` 用 **sqlglot AST** 遍历所有 `exp.Table` 节点，
不在 MDL 模型集、也不是可见 CTE 的一律拒绝。
**还专门处理了表值函数**（`read_csv()`、`generate_series()` 这类 name 为空的节点）——
strict 模式下直接封杀。这是想过绕过路径的实现。

### 3.2 但默认值是关的

```python
strict_mode: bool = False                                    # config.py:26
denied_functions: frozenset[str] = field(default_factory=frozenset)   # :27
```

**两条防护默认都不生效。**

### 3.3 与 SQLBot 的对比

| | SQLBot | WrenAI |
| --- | --- | --- |
| 语句类型白名单（只允许 SELECT/WITH…） | **有**，且默认开 | **无** |
| 写操作黑名单（INSERT/DROP/…） | **有** | **无** |
| 表/模型白名单 | 无 | **有**（strict_mode，默认关） |
| AST 解析 | sqlglot，按方言 | sqlglot |

**两者的防护是不同维度、互不覆盖的**：
SQLBot 管"能做什么操作"，WrenAI 管"能碰哪些表"。
**WrenAI 没有阻止 `DELETE FROM <MDL 里声明的模型>`** ——
只要那张表在 MDL 里，strict_mode 也不会拦。

我没有在 SDK 或 Rust 引擎侧找到语句类型限制
（换了 `read_only` / `readonly` / `statement` / `DML` / `is_query` 等 9 个关键词查）。
**但按本轮的教训，"没找到"是最弱的证据**——若有我没找到的路径，本节结论会被推翻。

```bash
sed -n '/def validate_sql_policy/,/_check_functions/p' core/wren/src/wren/policy.py
grep -n "strict_mode\|denied_functions" core/wren/src/wren/config.py | head -4
```

## 4. 判定

| 问题 | 判定 |
| --- | --- |
| 能接吗 | **能**，且形态比 SQLBot 更贴合——它是工具包，编排权留在我们手里 |
| 该接吗 | **该，但排在预算之后**，理由同 SQLBot |
| 与 SQLBot 二选一？ | **不是二选一，是先选一个试**。两者定位不同（应用 vs 工具包），但解决的都是"结构化数据"这一半 |

**倾向 WrenAI 的理由**：

1. investment-app 的编排在 LangGraph 里，不需要 SQLBot 自带的 chat 流程
2. `wren_dry_plan` / `wren_query` 分离，天然适配已有的 approval 环节
3. MDL 是显式声明的语义层，比 RAG 检索 schema 更可控、更可审计——
   投资研究要能答"这个数字怎么来的"，显式建模比向量召回好交代

**倾向 SQLBot 的理由**：它的 SQL 安全防护开箱即用且默认开启，WrenAI 要自己配。

## 5. 接入时必须做的四件事

1. **`strict_mode = True`**（§3.2）——默认关着等于没有防护
2. **自己补语句类型白名单**——WrenAI 不管这一层（§3.3）。
   最稳的是**只读数据库账号**，与 SQLBot 那篇同一条建议
3. **SQL 与结果进证据账**——投资结论引用的每个数字要能答"哪个模型、哪天、什么 SQL"。
   `wren_dry_plan` 返回的目标方言 SQL 正好是可留档的证据
4. **计入预算**——每次 `wren_query` 是一次数据库查询，`wren_store_query` 还会写入

## 6. 一条方法上的收获（与 investment-app 无关但值得记）

WrenAI 的 `ModelRetry` 模式——**错误不是终止，而是带修正建议回喂模型**——
比本项目 pilot 链现在的做法好。现状 pilot 链的失败是直接落 `failed`，
模型没有机会按提示自我修正。

这与 [`codex-mechanisms-for-investment-agent-opus.md`](codex-mechanisms-for-investment-agent-opus.md)
M3 里 Codex 的 `Denied { rejection: String }`（拒绝但继续，且带理由回给模型）
是同一个思路，两个独立项目都这么做，说明它是个真模式。

## 7. 边界

| 边界 | 说明 |
| --- | --- |
| **落后上游 202 个提交 / 3 个月** | 本文对 fork HEAD 取证。复核上游：`git fetch upstream && git grep -l validate_sql_policy $(git ls-remote upstream HEAD \| cut -f1)` |
| 未运行 | 静态读码，未装 SDK、未起服务、未实跑任何工具 |
| **未评估准确率** | 与 SQLBot 那篇同一个空白——语义层的召回质量是选型核心指标，本文完全没碰 |
| 未读 Rust 引擎 | 68 个 rs 文件只看了 Cargo.toml 确认是 DataFusion 53 |
| 未读 MDL schema 本体 | 只确认 `mdl.schema.json` 存在 |
| §3.3 的"无语句类型限制"是"没找到" | 换了 9 个关键词，仍属最弱证据等级 |
| 未与 kimi / qwen3.8 的同名文章比对 | 未读其正文；**它们可能分析的是已冻结的 `legacy/v1` 形态**，需人工核对（§0.2） |
