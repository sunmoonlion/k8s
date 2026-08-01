# 爬虫项目：MVP 技术组合

来源：`~/spider/爬虫项目 - mvp技术组合.html`

说明：本文由 ChatGPT 保存页提取并清理，只作为 Info App 采集与资讯治理设计参考；不是当前实现状态。

按你前面说的金融研究资讯收集/爬虫项目来理解，MVP 不要一开始做成“全网金融情报平台”，而是先做一个能真实解决研究问题的最小闭环。

## MVP定位

目标：自动收集金融研究所需的公开信息，完成“采集—清洗—入库—检索—摘要—预警”的最小闭环。

一句话版本：

>
做一个面向金融研究的资讯采集助手，先覆盖少量高价值信息源，自动抓取、结构化、去重、分类，并支持关键词检索和每日摘要。

## MVP第一版只做这5件事

### 1. 信息源先少而精

第一版不要追求覆盖所有网站，建议先选 4 类：

| 类目 | 信息源示例 | 价值

| 公司公告 | 交易所公告、上市公司公告 | 最核心、最权威

| 财经新闻 | 财联社、证券时报、东方财富等公开新闻 | 高频事件跟踪

| 研报/观点 | 券商研报标题、摘要、公开报告 | 投资逻辑与行业判断

| 宏观数据/政策 | 央行、统计局、发改委、财政部等 | 宏观环境判断

MVP 阶段可以先抓：
上市公司公告 + 财经新闻 + 政策信息。

研报可以放到第二阶段，因为研报版权和获取难度更高。

### 2. 每条信息结构化

每条资讯入库时至少保留这些字段：

标题
正文/摘要
来源网站
发布时间
抓取时间
原文链接
信息类型：公告/新闻/政策/研报
相关公司
相关股票代码
相关行业
关键词
情绪倾向：利好/利空/中性
重要性评分

第一版最重要的是：
标题、时间、来源、链接、正文、公司/行业标签。

### 3. 做去重和分类

金融资讯很容易重复，例如同一条公告会被多个网站转载。

MVP 要有两个基础能力：

标题相似去重
正文相似去重

分类先不用太复杂，可以先分成：

公司公告
行业新闻
宏观政策
市场异动
财务数据
监管处罚
并购重组
业绩预告

### 4. 做一个最简单的查询页面

MVP 不需要一开始做复杂前端。

可以先有一个简单 Web 页面：

搜索框
时间筛选
公司筛选
行业筛选
资讯类型筛选
结果列表
点击查看原文和摘要

页面能支持这些问题就够了：

最近7天，医药行业发生了什么重要事件？
某家公司最近有哪些公告？
某个关键词最近出现频率是否上升？
今天有哪些可能影响市场的重要政策？

### 5. 做每日摘要

这是金融研究场景里最容易体现价值的功能。

每天自动生成：

今日重要公司公告
今日重要行业新闻
今日重要宏观政策
高频关键词
重点风险事件
值得继续跟踪的公司/行业

这一步可以接入 LLM，生成类似：

>
今日医药行业重点关注：A公司发布业绩预告，B公司涉及集采风险，C政策可能影响院内药品销售节奏。建议后续关注终端销量、医院准入和医保支付变化。

## MVP不建议一开始做的功能

这些可以先不做：

不要一开始做全网爬虫
不要一开始做复杂知识图谱
不要一开始做股票预测
不要一开始做自动交易
不要一开始抓大量付费研报
不要一开始做太复杂的RAG
不要一开始做多用户权限系统

第一阶段核心是验证：

>
自动收集的信息是否足够稳定、准确、可检索、对研究有用。

## 推荐技术架构

### 简化版架构

爬虫层：Python + Scrapy / Playwright / requests
任务调度：APScheduler / Celery
数据清洗：BeautifulSoup + trafilatura
数据库：PostgreSQL
搜索：Meilisearch / Elasticsearch
向量检索：Qdrant / Milvus / pgvector
后端：FastAPI
前端：Next.js / Streamlit
LLM层：OpenAI API / 本地模型

### 最小可落地版本

我建议第一版用：

Python + FastAPI + PostgreSQL + Meilisearch + Streamlit

这样开发快，维护简单。

## MVP功能清单

### 第1版必须有

1. 定时抓取指定网站
2. 自动解析标题、时间、正文、链接
3. 入库
4. 去重
5. 按公司、行业、关键词检索
6. 自动生成摘要
7. 简单网页展示

### 第2版再加

1. 多源交叉验证
2. 事件分类
3. 公司画像
4. 行业专题追踪
5. 研报PDF解析
6. RAG问答
7. 微信/邮件预警

## MVP验收标准

第一版可以这样判断是否合格：

每天稳定抓取 500-3000 条资讯
抓取成功率 > 90%
重复率控制在 10% 以下
重要资讯延迟 < 30分钟
支持按公司/行业/关键词检索
每日自动生成一份摘要
摘要中至少70%的内容对研究人员有参考价值

## 我建议你的MVP范围

最适合你的第一版是：

>
金融资讯采集 + 公司/行业标签 + 每日智能摘要 + 简单搜索系统。

不要一开始做成“大而全”的金融智能体。

先做一个能帮你每天自动回答这三个问题的系统：

今天市场发生了什么？
哪些公司/行业值得关注？
有没有值得预警的风险事件？

这个 MVP 跑通以后，再逐步升级到：

研报解析
公告深度分析
财务报表结构化
RAG问答
投资研究智能体

#### 你说：
MVP 技术组合

如果以 A 股 + 研报/公告/新闻 + RAG 为主，我建议：

AkShare + TuShare：补行情、基本面、市场数据。
Scrapy：抓公告列表、新闻列表、公司 IR 页面。
Trafilatura：抽取新闻正文、标题、作者、发布时间。
Crawl4AI 或 Playwright：处理 JS 动态页面和 RAG 友好 Markdown。
changedetection.io：监控重点公司官网、交易所栏目、政策页面变化。
PostgreSQL/MySQL + MinIO + OpenSearch/Elasticsearch + RAGFlow/WeKnora：分别承担结构化元数据、原始文件、全文检索、知识问答。
对上面进行进一步细化

#### ChatGPT 说：

我会把这套组合拆成“采集层—解析层—存储层—检索/RAG层—监控调度层—MVP落地优先级”，并顺带指出哪些组件第一版必须上、哪些可以后置。

下面我把你这套 A股 + 研报/公告/新闻 + RAG 的 MVP 技术组合进一步细化。核心思路是：不要一上来做大而全的数据平台，而是先做“可稳定采集、可结构化入库、可搜索、可问答、可预警”的最小闭环。

# 一、整体技术架构建议

建议把系统拆成 7 层：

1. 数据源层：AkShare / TuShare / 交易所 / 公司官网 / 新闻源 / 政策源
2. 采集层：Scrapy / Playwright / Crawl4AI / changedetection.io
3. 解析层：Trafilatura / PDF解析 / HTML清洗 / Markdown转换
4. 存储层：PostgreSQL + MinIO
5. 检索层：OpenSearch 或 Elasticsearch
6. RAG层：RAGFlow 或 WeKnora
7. 应用层：FastAPI + 简单前端 + 定时摘要 + 预警

数据流可以这样设计：

数据源
↓
采集任务
↓
正文抽取 / PDF解析 / Markdown化
↓
去重 / 标准化 / 标签识别
↓
PostgreSQL 存元数据
MinIO 存原文/PDF/HTML/Markdown
OpenSearch 存全文索引
RAGFlow/WeKnora 建知识库
↓
搜索 / 问答 / 摘要 / 预警

# 二、各组件职责进一步细化

## 1. AkShare + TuShare：负责“标准金融数据补全”

这两个不要当成资讯爬虫的主力，而是作为金融结构化数据补全层。

AkShare 官方定位是 Python 金融数据接口库，覆盖股票、期货、债券、期权、外汇、货币、现货、利率等数据；TuShare 也面向金融数据分析、量化和投研场景，提供股票、基金、期货、宏观等接口。GitHub+2AKShare+2

### 在你的 MVP 里，它们主要做这些事：

1. 补充股票代码、公司名称、行业分类
2. 补充行情数据：收盘价、涨跌幅、成交额、市值等
3. 补充财务指标：营收、净利润、ROE、毛利率等
4. 补充公告相关公司基础信息
5. 为资讯做“影响判断”提供背景数据

### 典型使用场景

比如你抓到一条新闻：

>
某医药公司发布创新药获批公告。

系统应该自动补充：

股票代码
公司简称
所属行业
总市值
最近涨跌幅
近一年营收
近一年净利润
是否亏损
是否属于创新药/中药/医疗器械等细分赛道

这样 RAG 回答时就不会只停留在“新闻摘要”，而能进一步回答：

这条公告对公司基本面可能有什么影响？
该公司过去是否有类似管线？
这类事件在医药行业中重要性如何？

### MVP建议

第一版只需要用 AkShare/TuShare 做三类补全：

A股股票基础表
日行情表
财务摘要表

不要一开始抓太多量化数据，否则系统复杂度会上升。

## 2. Scrapy：负责“规则稳定、列表型页面”的主爬虫

Scrapy 官方定位是高层级网页抓取框架，适合爬取网站并提取结构化数据。docs.scrapy.org

在你的项目里，Scrapy 适合抓：

交易所公告列表
上市公司公告列表
财经新闻列表
政策网站栏目列表
公司 IR 新闻列表
券商公开研报列表

### Scrapy适合的页面类型

列表页结构稳定
分页规则清晰
URL规律明显
HTML静态加载
不需要复杂登录
不需要大量 JS 渲染

例如：

上交所公告列表
深交所公告列表
北交所公告列表
证监会新闻发布
国家统计局新闻
央行政策公告
上市公司官网新闻中心

### Scrapy在系统里的职责

1. 定期访问列表页
2. 发现新链接
3. 抓取详情页
4. 提取标题、时间、来源、正文链接
5. 将原始 HTML 保存到 MinIO
6. 将元数据写入 PostgreSQL
7. 将待解析任务推送到解析队列

### Scrapy不要做的事

不要让 Scrapy 直接承担 RAG 切片
不要让 Scrapy 直接做复杂正文清洗
不要让 Scrapy 直接做深度摘要
不要让 Scrapy 处理复杂 JS 页面

Scrapy 的定位应该是：高稳定、高频率、规则化采集。

## 3. Trafilatura：负责“新闻正文抽取”

Trafilatura 是 Python 包和命令行工具，主要用于网页文本采集、正文抽取、元数据抽取和文本处理，可输出常见格式。trafilatura.readthedocs.io

它适合处理：

财经新闻正文
政策文章正文
公司官网新闻正文
一般 HTML 文章页

### 在你的 MVP 中，Trafilatura 的作用

Scrapy 抓到详情页 HTML 后，不建议你自己写一堆 XPath 去抽正文。可以先把 HTML 交给 Trafilatura，抽取：

标题
正文
作者
发布时间
网站名称
正文纯文本
正文 HTML

### 建议处理逻辑

原始 HTML
↓
Trafilatura 抽正文
↓
清洗空行、广告、免责声明
↓
生成 cleaned_text
↓
生成 markdown_text
↓
写入 PostgreSQL + MinIO

### 需要注意

Trafilatura 对标准新闻页效果不错，但对下面几类页面可能不稳定：

公告 PDF
动态加载页面
表格很多的页面
研报 PDF
券商网页报告
扫描件

所以它不应该负责全部内容解析。它更适合做新闻正文抽取器。

## 4. Crawl4AI 或 Playwright：负责“动态页面 + RAG友好内容”

Crawl4AI 的定位是面向 LLM / RAG / Agent / 数据管道的网页爬虫，可以把网页转换成干净的 LLM-ready Markdown，并支持动态页面、CSS 抽取、内容过滤、缓存等能力。GitHub+2docs.crawl4ai.com+2

Playwright 更偏底层浏览器自动化，适合处理：

JS动态加载
点击展开
滚动加载
登录后页面
需要等待接口返回的页面
反爬较强页面

### 二者分工建议

| 场景 | 推荐

| 静态新闻页 | Scrapy + Trafilatura

| JS动态栏目 | Playwright

| 需要转 Markdown 给 RAG | Crawl4AI

| 单页复杂结构抽取 | Crawl4AI

| 需要模拟浏览器行为 | Playwright

| 高频大规模抓取 | Scrapy 优先

### MVP建议

第一版不建议同时重度使用 Scrapy、Playwright、Crawl4AI 三套。推荐这样分工：

Scrapy：负责 80% 稳定列表页
Trafilatura：负责新闻正文
Crawl4AI：负责少量 RAG 友好页面
Playwright：只作为兜底，不作为主爬虫

也就是说：

>
Scrapy 是主干，Crawl4AI 是 RAG 友好补充，Playwright 是动态页面兜底。

## 5. changedetection.io：负责“重点页面变化监控”

changedetection.io 适合做网站变更监控，并支持通过 Apprise 发送大量类型通知，如 email、Office365、自定义 API 等。GitHub

它不适合作为主爬虫，但非常适合作为重点页面预警器。

### 适合监控的页面

重点上市公司 IR 页面
交易所重点栏目
证监会政策页面
国家医保局政策页面
央行政策页面
财政部政策页面
发改委政策页面
公司产品/管线页面
公司投资者关系公告页面

### changedetection.io 在你的系统里的作用

1. 监控关键页面是否发生变化
2. 发生变化后通过 webhook 通知你的后端
3. 后端触发 Scrapy / Crawl4AI 定向抓取
4. 抓取后入库、摘要、预警

### 推荐使用方式

不要用 changedetection.io 监控所有新闻网站。

它应该只监控“低频但高价值”的页面。

例如：

某创新药公司官网产品管线页面
某上市公司投资者关系公告页
证监会处罚公告栏目
医保局药品目录调整页面
交易所监管函页面

# 三、存储层细化

## 1. PostgreSQL / MySQL：建议优先 PostgreSQL

你的组合里写了 PostgreSQL/MySQL，我建议 MVP 阶段不要两个都上，优先选 PostgreSQL。

原因是 PostgreSQL 对 JSON、全文检索、复杂查询、扩展能力都更适合这种“资讯 + 元数据 + RAG”的项目；PostgreSQL 官方也支持 JSON/JSONB 类型和相关操作。PostgreSQL+1

如果未来你想把部分向量也放在数据库里，pgvector 可以让 PostgreSQL 支持向量相似度搜索，包括精确/近似最近邻搜索、余弦距离、内积、L2 距离等。GitHub

### PostgreSQL主要存什么？

资讯元数据
公告元数据
研报元数据
公司表
股票代码表
行业表
事件表
标签表
采集任务表
解析状态表
去重指纹表
RAG文档映射表

### 建议核心表设计

#### source 表：数据源表

SQL
source_id
source_name
source_type -- 公告 / 新闻 / 政策 / 研报 / 公司官网
base_url
crawl_method -- scrapy / crawl4ai / playwright / api
frequency
enabled
created_at
updated_at

#### document 表：文档主表

SQL
doc_id
source_id
title
url
canonical_url
publish_time
crawl_time
doc_type -- news / announcement / report / policy
company_code
company_name
industry
raw_file_path -- MinIO路径
clean_file_path -- MinIO路径
content_hash
title_hash
status -- crawled / parsed / indexed / failed
created_at
updated_at

#### document_text 表：正文表

SQL
doc_id
clean_text
markdown_text
summary
keywords
entities_json
token_count
language

#### document_event 表：事件表

SQL
event_id
doc_id
event_type -- 业绩预告 / 并购重组 / 处罚 / 新药获批 / 政策变化
event_date
company_code
industry
sentiment -- positive / negative / neutral
importance_score
reason

#### chunk 表：RAG切片映射表

SQL
chunk_id
doc_id
chunk_index
chunk_text
chunk_hash
embedding_id
rag_dataset_id
start_position
end_position

#### crawl_log 表：采集日志表

SQL
task_id
source_id
url
status
http_status
error_message
started_at
finished_at
retry_count

## 2. MinIO：负责原始文件和大文件存储

MinIO 是高性能、S3 兼容的对象存储，适合 AI/ML、分析和数据密集型工作负载。MinIO+1

在你的系统里，MinIO 不存结构化数据，而是存这些东西：

原始 HTML
原始 PDF
研报 PDF
公告 PDF
清洗后的 TXT
清洗后的 Markdown
截图
附件
解析中间文件

### 推荐 Bucket 设计

raw-html
raw-pdf
clean-text
clean-markdown
screenshots
reports
announcements
failed-pages

### 为什么要保留原始文件？

因为金融研究场景必须可追溯。

当 RAG 回答有争议时，你要能回到：

原始链接
原始HTML
原始PDF
抽取正文
切片文本
回答引用

否则后续很难做可信问答。

# 四、全文检索层：OpenSearch / Elasticsearch

OpenSearch 和 Elasticsearch 都能做全文检索、向量检索和混合检索。OpenSearch 官方文档说明 hybrid search 会结合关键词和语义检索，并通过 search pipeline 对不同分数进行归一化和合并；Elastic 文档也说明 hybrid search 是把传统全文检索和 AI 语义检索结合起来。OpenSearch Documentation+1

### 在你的 MVP 中，全文检索层解决什么问题？

RAGFlow/WeKnora 主要解决“问答”。

OpenSearch/Elasticsearch 主要解决“可控检索”。

两者不是完全替代关系。

你需要 OpenSearch/Elasticsearch 来支持：

按标题搜索
按公司搜索
按股票代码搜索
按时间范围搜索
按资讯类型搜索
按来源搜索
按事件类型搜索
按关键词搜索
按行业搜索
按重要性排序

### 推荐索引字段

JSON
{
"doc_id": "xxx",
"title": "xxx",
"content": "xxx",
"summary": "xxx",
"source_name": "xxx",
"doc_type": "announcement",
"publish_time": "2026-06-02T10:00:00",
"company_code": "600000",
"company_name": "xxx",
"industry": "医药生物",
"event_type": "业绩预告",
"sentiment": "neutral",
"importance_score": 82,
"url": "xxx"
}

### MVP建议：OpenSearch vs Elasticsearch

| 维度 | OpenSearch | Elasticsearch

| 开源友好度 | 更适合纯开源路线 | 商业生态强

| 中文资料 | 较多 | 非常多

| 企业使用 | 较多 | 非常成熟

| 混合检索 | 支持 | 支持

| MVP推荐 | 更适合开源优先 | 更适合已有 Elastic 经验

如果你强调开源、自部署、成本控制，优先 OpenSearch。

如果你团队已经熟悉 Elastic，选 Elasticsearch 也可以。

# 五、RAG层：RAGFlow / WeKnora 如何选

RAGFlow 官方定位是基于深度文档理解的开源 RAG 引擎，支持从本地服务启动、创建数据集、干预文件解析，到建立基于数据集的 AI chat，并强调带引用的可信问答。RAGFlow

WeKnora 是腾讯开源的 LLM 知识框架，定位于企业级文档理解、语义检索和自主推理。GitHub

### 你的场景：A股 + 研报 + 公告 + 新闻

我建议这样判断：

| 场景 | 更推荐

| 研报 PDF 多、格式复杂 | RAGFlow 优先

| 需要快速搭知识库问答 | RAGFlow 优先

| 看重腾讯背景、Go 后端、企业文档框架 | WeKnora 可重点评估

| 想做长期国产化/中文文档理解路线 | WeKnora 值得 POC

| MVP 要尽快跑通 | RAGFlow 优先

| 想保留第二选择 | RAGFlow 主线 + WeKnora 平行测试

### 我的建议

第一阶段：

RAGFlow 作为 MVP 主 RAG 引擎
WeKnora 作为备选 POC

原因是你现在目标不是研究 RAG 框架本身，而是尽快跑通：

公告/研报/新闻 → 入库 → 检索 → 问答 → 引用 → 摘要

RAGFlow 更适合快速验证“复杂文档问答”的业务闭环；WeKnora 可以作为你后续的国产开源备选路线。

# 六、MVP技术组合最终推荐版

## 第一版最小组合

数据补全：AkShare + TuShare
主爬虫：Scrapy
正文抽取：Trafilatura
动态页面兜底：Playwright
RAG友好网页抽取：Crawl4AI
变化监控：changedetection.io
元数据存储：PostgreSQL
原始文件存储：MinIO
全文检索：OpenSearch
RAG问答：RAGFlow
后端：FastAPI
前端：Streamlit 或简单 Vue/React
任务调度：APScheduler / Celery；后期再上 Airflow

Apache Airflow 是用于开发、调度和监控批处理工作流的开源平台，适合后续任务多、依赖复杂时引入。Apache Airflow

### 我建议的 MVP 不要一开始太重

第一版可以先不上：

Kubernetes
复杂微服务
知识图谱
多租户权限
自动交易
复杂因子平台
全量研报抓取
全网新闻抓取

# 七、具体功能模块拆解

## 模块 1：数据源管理

### 功能

新增数据源
配置抓取频率
配置抓取方式
配置是否启用
配置数据类型
配置解析规则

### 示例

数据源名称：上交所公告
类型：公告
抓取方式：Scrapy
频率：每10分钟
是否启用：是
重要性：高

数据源名称：某上市公司IR页面
类型：公司官网
抓取方式：changedetection.io + Crawl4AI
频率：每6小时
是否启用：是
重要性：高

## 模块 2：采集任务管理

### 任务类型

定时抓取
手动抓取
变更触发抓取
失败重试
历史补抓
单URL抓取

### 任务状态

pending
running
success
failed
retrying
parsed
indexed
rag_ingested

### MVP要求

第一版至少要能看到：

哪些任务成功
哪些任务失败
失败原因是什么
抓到了多少条
解析成功多少条
入库多少条

## 模块 3：正文解析与清洗

### 新闻类

Trafilatura 抽取正文
清洗广告
清洗版权声明
清洗推荐阅读
提取发布时间
提取作者

### 公告类

下载 PDF
保存原文
抽取 PDF 文本
识别公告标题
识别股票代码
识别公司名称
识别公告类型

### 研报类

下载 PDF
识别标题
识别券商
识别分析师
识别行业
识别股票代码
识别发布日期
抽取正文
抽取目录
抽取表格
切分章节

研报解析是难点，所以 MVP 可以先只做：

研报 PDF 存储
标题/券商/日期/行业提取
全文粗解析
RAGFlow 入库问答

不要一开始就追求完美解析表格和图表。

## 模块 4：去重

金融资讯重复率很高，必须做去重。

### 第一层：URL去重

canonical_url

### 第二层：标题去重

title_hash

### 第三层：正文去重

content_hash

### 第四层：语义近似去重

后期再做，例如：

同一公告被多个新闻网站转发
同一政策被多个媒体转载
同一公司事件被多篇文章重复报道

### MVP规则

第一版先用：

URL + 标题 + 正文 hash

这就够用了。

## 模块 5：标签与事件识别

这个模块是你项目的核心价值之一。

### 基础标签

公司
股票代码
行业
来源
时间
资讯类型
关键词

### 事件标签

业绩预告
业绩快报
年报
半年报
季报
并购重组
股权激励
重大合同
监管处罚
诉讼仲裁
高管变动
产品获批
药品集采
医保政策
融资融券
减持增持
停复牌
风险提示

### 情绪/影响方向

利好
利空
中性
不确定

### 重要性评分

建议用 0-100 分：

90-100：重大事件，需要立即预警
70-89：较重要，进入每日摘要
40-69：一般关注
0-39：低价值归档

### 重要性评分规则示例

上市公司公告 > 普通新闻转载
监管处罚 > 普通经营新闻
业绩大幅预增/预亏 > 普通季报披露
创新药获批 > 普通产品宣传
国家级政策 > 地方普通通知
龙头公司事件 > 小市值公司普通新闻

# 八、RAG入库设计

你的 RAG 不应该直接吞“乱七八糟的网页”。

应该经过一层标准化。

## 推荐 RAG 文档格式

每篇文档进入 RAG 前，整理成：

Markdown
# 标题

## 基本信息
- 来源：
- 发布时间：
- 抓取时间：
- 文档类型：
- 公司：
- 股票代码：
- 行业：
- 原文链接：

## 摘要
这里是系统自动生成或抽取的摘要。

## 正文
这里是清洗后的正文。

## 事件标签
- 事件类型：
- 影响方向：
- 重要性评分：

## 原文引用
原始文件路径 / URL

这样做的好处是：

RAG 问答时不仅能读正文，也能读元数据。

# 九、你真正需要支持的查询问题

MVP 不要做泛泛问答，而要围绕金融研究问题设计。

## 第一类：公司跟踪

某公司最近30天有哪些公告？
某公司最近有哪些负面事件？
某公司近期是否有业绩变化？
某公司有没有监管处罚、减持、诉讼？

## 第二类：行业跟踪

最近7天医药行业发生了什么重要事件？
创新药板块最近有哪些政策和公告？
中药企业最近有哪些值得关注的变化？

## 第三类：政策跟踪

最近医保局有哪些政策影响医药行业？
最近央行政策对市场流动性有什么影响？
最近证监会发布了哪些监管信息？

## 第四类：研报问答

某券商最近怎么看医药行业？
多篇研报对某公司的分歧在哪里？
最近研报中高频提到哪些风险？

## 第五类：预警

今天有哪些重大利空？
今天有哪些公司被处罚？
今天有哪些公司发布业绩预亏？
今天有哪些政策可能影响市场？

# 十、推荐开发顺序

## 第 0 阶段：本地验证

目标：跑通单条链路。

抓一个公告
抓一条新闻
抓一篇 PDF
入 PostgreSQL
存 MinIO
进 OpenSearch
进 RAGFlow
能搜索
能问答

验收标准：

输入公司名称，可以查到相关公告/新闻
输入问题，可以基于原文回答并给出来源

## 第 1 阶段：MVP 核心闭环

目标：跑通 10-20 个高价值数据源。

A股公告
财经新闻
政策网站
重点公司官网
少量公开研报

功能：

定时抓取
正文解析
入库
全文搜索
RAG问答
每日摘要
重点预警

验收标准：

每天稳定抓取 500-3000 条
解析成功率 > 85%
重复率 < 15%
重要公告延迟 < 30 分钟
每日自动生成摘要
RAG回答能引用来源

## 第 2 阶段：研究增强

目标：从“资讯收集”变成“研究辅助”。

增加：

事件分类
公司画像
行业画像
多文档对比
研报观点聚合
政策影响分析
风险预警评分

## 第 3 阶段：智能体化

目标：变成金融研究 Agent。

增加：

自动生成公司跟踪报告
自动生成行业日报
自动生成政策解读
自动发现异常事件
自动提出研究问题
自动调用 AkShare/TuShare 补数据

# 十一、我建议你最终的 MVP 组合

如果只选一套最务实的，我建议：

Python
FastAPI
Scrapy
Trafilatura
Crawl4AI
Playwright
changedetection.io
PostgreSQL
MinIO
OpenSearch
RAGFlow
AkShare
TuShare
Streamlit

其中第一优先级是：

Scrapy + Trafilatura + PostgreSQL + MinIO + OpenSearch + RAGFlow

第二优先级是：

AkShare + TuShare + Crawl4AI + changedetection.io

第三优先级是：

Playwright + WeKnora + Airflow

# 十二、关键取舍建议

## 1. 不要把 RAGFlow 当数据库

RAGFlow/WeKnora 负责知识问答，但你的主数据资产应该放在：

PostgreSQL
MinIO
OpenSearch

这样未来你换 RAG 框架也不会伤筋动骨。

## 2. 不要只做 RAG，不做结构化数据

金融研究不能只靠向量问答。

你必须有结构化字段：

公司
股票代码
行业
日期
事件类型
来源
重要性评分

否则后续很难做：

趋势分析
事件统计
行业对比
公司监控
预警排序

## 3. 不要全靠爬虫，API数据也要用

行情、财务、股票基础信息尽量走 AkShare/TuShare。

新闻、公告、政策、公司官网信息再用爬虫。

## 4. 不要过早做知识图谱

你现在最需要的是：

稳定采集
准确解析
可搜索
可问答
可追溯
可预警

知识图谱可以等有足够事件数据后再做。

## 5. 第一版要强调“可追溯”

每个回答都要能追溯到：

原文链接
原始文件
抽取正文
发布时间
来源
RAG引用片段

这对金融研究非常关键。

# 最终一句话方案

你的 MVP 可以定义为：

>
基于 Scrapy + Trafilatura + PostgreSQL + MinIO + OpenSearch + RAGFlow 的 A 股金融资讯采集与研究问答系统，并用 AkShare/TuShare 补充行情和基本面数据，用 Crawl4AI/Playwright 处理动态页面，用 changedetection.io 监控重点页面变化。

最小可落地目标是：

每天自动采集公告、新闻、政策和少量研报；
自动结构化公司、行业、事件和时间；
支持全文搜索和 RAG问答；
每天生成金融研究摘要；
对重大公告、政策和风险事件做预警。

ChatGPT 也可能会犯错。请核查重要信息。
