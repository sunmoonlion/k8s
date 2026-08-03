# 仿 Wind 的数据库报表体系设计

状态：草案（参考设计）  
归属：`info-app`（主档与库表权威）  
日期：2026-08-03  
相关文档：

- `docs/info-app-spider-architecture.md`（采集与资讯治理）
- `sunmoonai/docs/mooc-manus-v5/adr/ADR-003-info-knowledge-artifact-contract.md`（Info→Knowledge 分发）
- `sunmoonai/docs/mooc-manus-langgraph-longterm-plan-v5.md`（App 边界）

---

## 1. 目的与非目标

### 1.1 目的

参考 Wind 研报/资讯检索站的**产品形态**（左栏分类、多维筛选、全文检索、列表排序），在 `info-app` 内设计一套：

- **规模可从小做起**
- **库表可长期扩展**
- **不阻塞后续 ES 检索、Knowledge RAG、Research 消费**

的数据库「报表/资讯文档」体系。

此处「报表体系」指：**研报/资讯类文档主档 + 维度字典 + 关联 + 检索同步字段**，不是 BI 宽表报表。

### 1.2 非目标

- 不是还原 Wind 真实库表（闭源，不可得）。
- 不是一期做成 Wind 体量或全量筛选项。
- 不是把 ES / RAGFlow 当作权威主档。
- 不是在 `knowledge-app` / `research-app` 再建第二套原文库。

### 1.3 核心原则（与 app-platform 一致）

```text
开始规模小，骨架按长期扩展建。
主档唯一、维度可加、检索可外挂、下游可分发。
能力分期交付，范式不推倒重来。
```

---

## 2. 产品参考：UI 条件 → 数据诉求

以下筛选项来自典型 Wind 研报站交互，仅作**维度清单**，不代表一期全做。

| UI 能力 | 数据诉求 | M1 | 演进 |
|---------|----------|----|------|
| 左栏类别（宏观/策略/行业/公司…） | 类别字典 + 主档外键 | ✅ | 可增类别 |
| 关键词（标题/全文） | 可检索文本 + ES | ✅ 标题/摘要；正文摘录 | 全文加重 |
| 来源机构 | 机构字典 + 外键 | ✅ 可先少量机构 | 机构目录扩张 |
| 主题标签（ESG 等） | 主题字典 + 多对多 | ✅ | 运营可配 |
| 行业格子 | 行业字典 + 多对多 | ⬜ M2 | 接入分类体系后 |
| 页数/日期/市场/语言 | 主档标量字段 | ✅ 日期+页数；市场/语言可空 | 补齐枚举 |
| 首次覆盖/评级变动 | 评级事件表 | ⬜ M2 | |
| 最新发布 / 最多点击 | `published_at` / 统计表 | ✅ 时间；点击 M2 | |
| 含公众号等渠道 | `source_channel` | ✅ 枚举预留 | |
| 收藏/下载 | 用户行为表 | ⬜ M1b/M2 | |
| Agent 引用问答 | 分发到 Knowledge，非本库向量 | 通路预留 | Research 消费 |

---

## 3. 与 Info 领域对象的对齐

本设计**优先复用**资讯治理对象，避免平行再造一套「研报表」与 `document` 双真相。

| 本设计逻辑名 | Info 领域对象 | 说明 |
|--------------|---------------|------|
| 信息源 | `source` | 研报源、公告源、上传入口等 |
| 研报/资讯主档 | `document` | 一篇一权威主档 |
| 版本 | `document_version` | 内容变化可追溯 |
| 正文/文件 | `raw_artifact` + `extracted_content` + 对象存储 | 大文件不进主表行 |
| 主题/行业/证券等 | `entity_link`（或专用关联表，见下） | 多对多标注 |
| 分发记录 | `distribution_record` | 同步 ES / Knowledge |
| Knowledge 侧映射 | `knowledge_mapping`（在 knowledge-app） | 不在 Info 主库扮向量库 |

命名策略：

- **逻辑讨论 / 对外说明**可用「研报 reports」说法。
- **落库物理表**建议与现有 Info 命名统一为 `document*`；若研报需要强类型，用 `document.doc_type = 'research_report'`（或等价枚举），而不是另起无关主表。

下文 DDL 使用 `document_*` 物理名，并在注释中标明研报语义。

---

## 4. 总体结构

```text
【字典 / 维度】          稳定、可运营、可扩展
【核心事实】            document 主档 + 版本 + 内容指针
【关联】                多对多标注（主题等）
【检索投影】            ES 索引文档（非权威）
【统计 / 用户】         热度与行为（可后期）
【分发】                向 ES / Knowledge 的投递记录
```

权威顺序：

```text
PostgreSQL 主档（Info） > 对象存储原文 > ES 检索副本 > Knowledge/RAG 派生索引
```

---

## 5. 库表设计

### 5.1 字典 / 维度

#### `dim_institution`（机构）

| 列 | 类型 | 说明 |
|----|------|------|
| id | BIGSERIAL PK | |
| code | VARCHAR(64) UNIQUE | 稳定业务码 |
| name | VARCHAR(256) | 展示名 |
| sort_order | INT | |
| is_active | BOOLEAN | |
| created_at / updated_at | TIMESTAMPTZ | |

#### `dim_category`（类别，对应左栏）

| 列 | 类型 | 说明 |
|----|------|------|
| id | BIGSERIAL PK | |
| code | VARCHAR(64) UNIQUE | macro / strategy / industry / company… |
| name | VARCHAR(128) | |
| parent_id | BIGINT NULL FK | 预留树形，M1 可扁平 |
| sort_order | INT | |
| is_active | BOOLEAN | |

#### `dim_theme`（主题标签）

| 列 | 类型 | 说明 |
|----|------|------|
| id | BIGSERIAL PK | |
| code | VARCHAR(64) UNIQUE | esg / semiconductor… |
| name | VARCHAR(128) | |
| sort_order | INT | |
| is_active | BOOLEAN | |

#### `dim_industry`（行业，M2）

结构同主题字典；M1 可不建表，避免空壳运营负担。

#### 市场 / 语言

M1 可用主档上的 `VARCHAR`/`TEXT` 枚举约束；若需运营可配，再升为 `dim_market` / `dim_language`。

---

### 5.2 核心事实

#### `document`（主档 ≈ 研报/资讯头）

**只存轻量元数据与多对一外键，不存主题列表、不存正文大字段。**

| 列 | 类型 | 说明 |
|----|------|------|
| id | UUID / BIGSERIAL PK | 领域稳定 ID |
| doc_type | VARCHAR(32) | `research_report` / `news` / `announcement`… |
| title | VARCHAR(512) | |
| summary | TEXT | 列表与 ES 摘要 |
| category_id | BIGINT NULL FK → dim_category | 左栏类别 |
| institution_id | BIGINT NULL FK → dim_institution | 来源机构 |
| source_id | BIGINT NULL | 可选，对齐采集 source |
| source_channel | VARCHAR(32) | wind_like_report / wechat / upload… |
| language | VARCHAR(16) | 可空 |
| market | VARCHAR(32) | 可空 |
| page_count | INT | 可空 |
| published_at | TIMESTAMPTZ | 列表「最新发布」 |
| status | VARCHAR(32) | draft / published / withdrawn… |
| current_version_id | UUID/BIGINT NULL | 指向当前版本 |
| created_at / updated_at | TIMESTAMPTZ | |

建议索引：

```text
(published_at DESC)
(category_id, published_at DESC)
(institution_id, published_at DESC)
(doc_type, status, published_at DESC)
```

#### `document_version`（版本）

| 列 | 类型 | 说明 |
|----|------|------|
| id | PK | |
| document_id | FK → document | |
| version_no | INT | 单调递增 |
| title | VARCHAR(512) | 版本上的标题快照（可选） |
| change_note | TEXT | |
| content_hash | CHAR(64) | 去重/完整性 |
| created_at | TIMESTAMPTZ | |

#### `document_content`（内容指针，替代「正文进主表」）

| 列 | 类型 | 说明 |
|----|------|------|
| document_version_id | PK/FK | 一对一版本 |
| storage_uri | TEXT | s3://bucket/key |
| storage_version | TEXT | 对象版本 ID（分发契约需要） |
| content_type | VARCHAR(128) | |
| byte_size | BIGINT | |
| sha256 | CHAR(64) | |
| text_plain_excerpt | TEXT | 可选，供早期检索；全量正文仍在对象存储 |
| clean_markdown_uri | TEXT | 可选派生件 URI |

大文件与完整 Markdown 以对象存储为准；库表只保指针与校验信息。

---

### 5.3 关联（多对多）

#### `document_theme`（文档 ↔ 主题）

```text
document_id  FK → document
theme_id     FK → dim_theme
PRIMARY KEY (document_id, theme_id)
INDEX (theme_id, document_id)
```

**主档不需要 `tags` 字段。** 打标 = 写关联行；改标 = 删插关联行。

#### `document_industry`（M2）

同 `document_theme` 结构。

#### `document_author` / `document_security`（M2+）

作者、证券标的等多对多，按需加表，不提前堆空表。

#### `document_rating_event`（M2）

| 列 | 说明 |
|----|------|
| id | PK |
| document_id | FK |
| event_type | first_coverage / rating_change / … |
| security_id | 可空 |
| payload | JSONB 可空（评级从到、目标价等） |
| occurred_at | TIMESTAMPTZ |

筛「首次覆盖」= 存在对应 `event_type`。

---

### 5.4 统计 / 用户（可后期）

#### `document_stats`

| 列 | 说明 |
|----|------|
| document_id | PK/FK |
| click_count | BIGINT |
| download_count | BIGINT |
| updated_at | TIMESTAMPTZ |

高频计数与主档分离，避免点击写放大锁主表。

#### `user_document_favorite` / `user_document_download`

用户行为；主体是用户，不把收藏数组塞进 `document`。

---

### 5.5 分发与检索投影

#### `distribution_record`（已有治理对象，库表落实）

记录向 ES、Knowledge 等下游的投递：状态、契约版本、correlation/distribution id、错误分类。  
权威内容仍以 `document_version` + 对象存储为准。

#### Elasticsearch 索引（非表，但是体系一部分）

建议索引名：`info_documents_v1`（别名 `info_documents`）。

**M1 最小字段：**

```text
document_id          keyword
doc_type             keyword
title                text（分词）
summary              text
category_id          keyword
institution_id       keyword
theme_ids            keyword[]
source_channel       keyword
language             keyword
market               keyword
page_count           integer
published_at         date
status               keyword
```

同步规则：

```text
document / 关联 / 版本发布成功
  → upsert ES 文档
document 撤稿/删除
  → delete 或标记 status 不可检索
```

ES **不得**成为唯一真相；重建索引必须能从 PG + 对象存储回放。

---

## 6. 关联关系示意

```text
dim_category ──┐
dim_institution┤
               ├── document ──1:N── document_version ──1:1── document_content
dim_theme ───── document_theme ──┘
                      │
                      ├──▶ ES info_documents（投影）
                      └──▶ distribution_record ──▶ knowledge-app（派生）
```

主题与文档：

```text
打标签:  INSERT document_theme(document_id, theme_id)
查某主题: JOIN document_theme WHERE theme_id = ?
主表:     无 tags 列
```

---

## 7. 分期落地（小规模完备 → Wind 式演进）

### 7.1 M1「小型完备」（必须可扩展）

**表：**

- `dim_category`, `dim_institution`, `dim_theme`
- `document`, `document_version`, `document_content`
- `document_theme`
- `distribution_record`（至少能记 ES 同步；Knowledge 可先一条金丝雀通路）

**能力：**

- 上传或简单入库 → 主档 + 版本 + 对象存储
- 类别 / 机构 / 主题筛选 + 时间排序
- ES 列表检索（标题/摘要 + 上述 filter）
- 详情读摘要与正文指针

**不做：** 行业大盘、评级事件、点击热度、复杂采集、全量 PDF 进 ES。

### 7.2 M2

- `dim_industry` + `document_industry`
- `document_rating_event`
- `document_stats`、收藏/下载
- ES 字段扩展、正文摘录加长
- 采集源与去重治理加深（见 spider 架构文档）

### 7.3 长期（Wind 模式演进，非体量追平）

- 维度与源持续加厚，**不改主档范式**
- Knowledge 多 Dataset；Research 稳定消费 retrieval/citation
- 评测与标注运营成为常规工作，而不是一次性项目

---

## 8. 扩展铁律（防死胡同）

1. **禁止**在 `document` 上用逗号拼接主题/行业字符串作为长期方案。  
2. **禁止**把完整正文/PDF 字节存进主表行。  
3. **禁止**让 ES 或 RAGFlow ID 成为业务主键。  
4. **新筛选维度**：先加字典表 + 关联表（或多对一外键），再扩展 ES mapping（版本化索引）。  
5. **doc_type** 区分研报/新闻/公告，共用主档范式，避免每类文档一套库。  
6. 与 Knowledge 分发必须带齐对象版本、hash、size、content type（见 ADR-003），库表指针字段预留对齐。

---

## 9. M1 参考 DDL（PostgreSQL 草案）

> 实施前与现有 Info schema 合并命名；以下为逻辑草案，可改前缀/类型以贴合仓库现状。

```sql
CREATE TABLE dim_category (
  id          BIGSERIAL PRIMARY KEY,
  code        VARCHAR(64) NOT NULL UNIQUE,
  name        VARCHAR(128) NOT NULL,
  parent_id   BIGINT REFERENCES dim_category(id),
  sort_order  INT NOT NULL DEFAULT 0,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE dim_institution (
  id          BIGSERIAL PRIMARY KEY,
  code        VARCHAR(64) NOT NULL UNIQUE,
  name        VARCHAR(256) NOT NULL,
  sort_order  INT NOT NULL DEFAULT 0,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE dim_theme (
  id          BIGSERIAL PRIMARY KEY,
  code        VARCHAR(64) NOT NULL UNIQUE,
  name        VARCHAR(128) NOT NULL,
  sort_order  INT NOT NULL DEFAULT 0,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE document (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  doc_type         VARCHAR(32) NOT NULL,
  title            VARCHAR(512) NOT NULL,
  summary          TEXT,
  category_id      BIGINT REFERENCES dim_category(id),
  institution_id   BIGINT REFERENCES dim_institution(id),
  source_channel   VARCHAR(32),
  language         VARCHAR(16),
  market           VARCHAR(32),
  page_count       INT,
  published_at     TIMESTAMPTZ,
  status           VARCHAR(32) NOT NULL DEFAULT 'published',
  current_version_id UUID,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_document_published ON document (published_at DESC);
CREATE INDEX idx_document_category_published ON document (category_id, published_at DESC);
CREATE INDEX idx_document_institution_published ON document (institution_id, published_at DESC);
CREATE INDEX idx_document_type_status_published ON document (doc_type, status, published_at DESC);

CREATE TABLE document_version (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id  UUID NOT NULL REFERENCES document(id) ON DELETE CASCADE,
  version_no   INT NOT NULL,
  content_hash CHAR(64),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (document_id, version_no)
);

CREATE TABLE document_content (
  document_version_id UUID PRIMARY KEY REFERENCES document_version(id) ON DELETE CASCADE,
  storage_uri         TEXT NOT NULL,
  storage_version     TEXT,
  content_type        VARCHAR(128),
  byte_size           BIGINT,
  sha256              CHAR(64),
  text_plain_excerpt  TEXT,
  clean_markdown_uri  TEXT
);

CREATE TABLE document_theme (
  document_id UUID NOT NULL REFERENCES document(id) ON DELETE CASCADE,
  theme_id    BIGINT NOT NULL REFERENCES dim_theme(id),
  PRIMARY KEY (document_id, theme_id)
);

CREATE INDEX idx_document_theme_theme ON document_theme (theme_id, document_id);
```

---

## 10. 验收口径（M1）

1. 能入库至少一类 `doc_type=research_report` 文档，含版本与对象存储指针。  
2. 能通过关联表打主题，主表无 tags 字符串列。  
3. 能按类别、机构、主题、时间筛选列表（经 ES）。  
4. 从 PG 可重建 ES 索引。  
5. 表结构无需迁移即可增加新主题/新机构；新增行业维度时只加字典+关联+ES 字段，不推翻 `document`。

---

## 11. 总结

| 问题 | 答案 |
|------|------|
| 仿的是什么 | Wind **交互与维度**，不是 Wind 真表 |
| 权威在哪 | Info PostgreSQL 主档 + 对象存储 |
| 主题如何挂 | `document_theme`，主表无标签列 |
| 为何可演进 | 字典可加、关联可加、ES/Knowledge 为投影与派生 |
| 与平台关系 | 符合 app-platform「小起步、可长期扩展」 |

本文是库表与检索投影的根据地设计；采集细节见 spider 架构文档，跨 App 分发见 ADR-003。
