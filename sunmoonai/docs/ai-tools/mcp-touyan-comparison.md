# 金融 AI 投研 MCP/Skills 平台行业对比笔记

> 整理时间：2026-08-05（第二版，扩充同花顺、东方财富）
> 对比对象：同花顺 iFinD MCP、东方财富妙想、万得 AIFin Market、华创金工 MCP、社区版 wind-mcp
> 背景：华创金工于 2026-08-04 发布研报《AI 投研工具研究之一：华创金工 MCP 配置与使用》，外界评价"万得早就公布了"。经调研，万得、同花顺、东方财富三大金融数据终端在 2026 年 3-5 月已集体入场，全部采用 MCP + Skills 双轨制。本文做全行业结构化对比。

---

## 一、行业背景与事件时间线

### 1.1 背景："养虾大战"蔓延至金融数据行业

- 2024-11-25：Anthropic 推出 MCP 协议，成为 AI Agent 连接外部数据的标准
- 2025 年："DeepSeek 时刻"后，三大终端先后发布自研大模型——万得 **Wind Alice**、东方财富**妙想**、同花顺**问财 HithinkGPT**
- 2026 年春：OpenClaw 类 AI Agent 爆火（"养虾大战"），券商分析师盯盘、基金经理写研报、银行客户经理尽调，但通用 Agent 缺专业金融数据——"逻辑推理强，数据匮乏"
- 2026-03-10：国家互联网应急中心（CNCERT）发布 OpenClaw 安全风险提示；多家券商内部收紧，限制/禁止/审批制管理 OpenClaw 安装使用
- 行业判断：金融终端竞争从"卖水"（卖数据）转向"卖铲"（卖 AI 工具），"未来的软件竞争，是谁能更好地被 AI 驱动的竞争"

### 1.2 关键时间线

| 时间 | 事件 |
|---|---|
| 2026-03-11 | 万得官宣 **WindClaw** 上线（"专业版 OpenClaw"，公测） |
| 2026-03-12 | 同花顺连夜上线 **iFinD 金融 MCP**；同日晚东方财富发布 **东方财富 Skills** |
| 2026-03-13 | 东方财富发布《妙想Skills重磅发布》新闻稿，六大能力矩阵 |
| 2026-03-23 | 同花顺发布**快查 Skill**（企业数据，"行业首发！一个 Skill 掌握企业全维度数据"） |
| 2026-05 下旬 | 万得发布 **AIFin Market**（金融 AI 生态平台，MCP + Skills + Alice） |
| 2026-05-22 | 同花顺宣传 iFinD MCP & Skill 双平台生态（扩至港美股/债券/指数/板块） |
| 2026-06-01 | 万得 AIFin Market 积分充值上线 |
| 2026-06-29 | 东方财富**妙想 Claw 全面开放 + 妙想 MCP 正式上线 + 积分体系启用** |
| 2026-07-16 | 妙想 MCP 上架阿里云市场（API 交付，0.01 元/积分后付费） |
| 2026-08-04 | 华创金工发布 MCP 配置与使用研报（23 个工具） |

### 1.3 三家终端的路线选择

| 厂商 | 切入路线 | 代表产品 |
|---|---|---|
| 万得 | 直接打造"专业版 OpenClaw" + 生态市场 | WindClaw、AIFin Market、Alice |
| 同花顺 | 优先从"数据"接入，充当专业金融数据源 | iFinD MCP、快查 Skill、iFinD Claw |
| 东方财富 | 以"技能（Skills）"为抓手，投资决策辅助 | 东方财富 Skills、妙想 MCP、妙想 Claw |

---

## 二、五方速览对比

| 维度 | 同花顺 iFinD MCP | 东方财富妙想 | 万得 AIFin Market | 华创金工 MCP | 社区版 wind-mcp |
|---|---|---|---|---|---|
| 提供方 | 同花顺 | 东方财富 | 万得（Wind） | 华创证券金工团队 | 个人开发者（MIT） |
| 首发时间 | 2026-03-12 | 2026-03-12（Skills）/ 2026-06-29（MCP） | 2026-05 下旬 | 2026-08-04 | 早于官方（社区封装） |
| 产品形态 | MCP + Skill 广场 + iFinD Claw | Skills + 妙想 MCP + 妙想 Claw | MCP 市场 + Skills 市场 + Alice Agent | 单一远程 MCP 服务 | 极简本地 MCP Server |
| MCP 工具数 | 32+（7 大数据域） | 11 个（mx_* 系列） | 32 个（7 个 MCP 服务） | 23 个（7 组） | 8 个（核心 2 个） |
| Skills | 金融取数/快查企业/产业链等 | 6 个官方 + 更多 | 90 个（官方+社区+第三方） | 无 | 无 |
| 自研 Agent | iFinD Claw | 妙想 Claw | Wind Alice / WindClaw | 无 | 无 |
| 数据底座 | iFinD 数据库（20+ 年）+ 快查 3.7 亿企业 | Choice 数据库 + 妙想大模型 | Wind 数据库（26 年） | 华创内部知识库/财务库 | 本地 Wind 终端 |
| 接入方式 | 终端获取密钥/官网个人中心 JSON | 一句话安装/阿里云市场 | 一键安装/npx/手工 JSON | 定向分发域名+secret | clone 仓库本地启动 |
| 计费 | 免费 2000 次、个人版 ¥40/月、企业版 | 积分制（登录送 300、0.01 元/积分） | 免费试用 + 积分充值 | 定向授权 | 免费开源 |
| 开放性 | 开放注册 | 开放（每日限量 5000 免费 API KEY） | 开放注册、双源托管 | 封闭定向 | 完全开源 |
| 定位 | 专业金融数据源 + 企业数据 | 投资决策辅助技能 + 研究流程封装 | 权威数据底座 + 生态市场 | 券商研究视角二次加工 | 底层原语最小封装 |

---

## 三、同花顺 iFinD MCP

### 3.1 基本信息

- **官网**：<https://mcp.51ifind.com/>
- **定位**："链接 AI 与金融，通过 MCP 标准协议为智能投研应用提供稳定、准确、可被模型直接调用的数据引擎"
- **发布**：2026-03-12 凌晨（主打"给 OpenClaw 们配上专业的金融数据"）
- **特点**：纯自然语言交互；智能语义匹配（股票别名、行业分类、主题概念、指数成分股）；内置数据清洗与 Token 优化机制（控制返回长度，避免上下文溢出）
- **数据底座**：iFinD 投研级数据库（20+ 年积累）

### 3.2 MCP 覆盖（7 大数据域、32+ 工具）

| 数据域 | 能力 |
|---|---|
| A股股票分析 | 智能选股、日/周/月行情与技术指标、财务报表及衍生估值、定量风险模型（Alpha/Beta/Sharpe/VaR）、重大事件（定增、解禁、增减持）、ESG 评级 |
| 公募基金分析 | 智能基金筛选、基本信息、历史业绩、份额结构、持仓配置、财报、分红、管理人指标 |
| 债券数据 | 从发行到估值的全生命周期数据 |
| 港美股数据 | 5 大港美股专业工具，跨市场研究 |
| 指数/板块 | 股票/基金/债券/ESG/期货指数全谱系；市场分类板块、申万/中信行业板块、概念板块 |
| 宏观经济与行业 | 全球/中国/区域宏观指标、行业数据、大宗商品（产量/进出口/库存/价格）全链条 |
| 公告与资讯 | A股/基金/港美股公告语义检索、财经新闻摘要、事件驱动资讯（时效性/情感倾向/行业过滤） |

### 3.3 Skill 生态

1. **金融取数 Skill**：依托 iFinD 全域数据库，7 大 MCP 专业数据服务，AI 一键取数、智能检索
2. **快查 Skill**（2026-03-23，行业首发）：企业数据查询，覆盖 **3.7 亿+ 中国组织实体、300+ 数据维度、100+ 查询工具**（工商、司法风险、经营、招投标、知识产权）；复制安装指令即装、工具无感热更新；兼容 ClaudeCode、OpenClaw、KimiClaw、QClaw、MaxClaw
   - 典型场景：新成立企业追踪、区域产业分析、银行信贷客户挖掘、招投标机会分析、舆情监控定时推送、批量数据补全导出
   - 获取：iFinD 终端→工具→常用工具→数据MCP节点；或快查开放平台 <https://open.kuaicha365.com/skills/>（内测送 1000 次调用）
3. **产业链 Skill**：覆盖 iFinD 产业链中心 **100+ 条产业链**，横跨 8 大基金行业和 28 个申万一级行业，7 分钟完成全链路经济指标调取（主打银行信贷场景）

### 3.4 接入方式

**标准接入**（原生 MCP 客户端：Copaw、Cursor、Trae、阿里百炼、Claude 系列、CherryStudio 等）：登录 iFinD 终端获取专属配置密钥，客户端 MCP 管理界面一键导入；对话中说"使用 iFinD 数据源"激活。

**高级本地部署**（OpenClaw 等非原生环境）：Skill 压缩包（ifind-finance-data）解压复制到 skills 目录 → 对话指令将密钥写入 `mcp_config.json` → 启动测试。官网个人中心也可直接获取配置 JSON。

### 3.5 计费与配套产品

- **计费**：免费版（注册送 2000 次）、个人版 ¥40/月、企业版联系开通
- **iFinD Claw**：自研一体化方案，零配置、一键本地/云端部署，原生集成 iFinD 全量数据库，预置投研场景模板（"开箱即用"）

---

## 四、东方财富妙想（Skills / 妙想 MCP / 妙想 Claw）

### 4.1 基本信息

- **大模型底座**：妙想金融大模型（"智取万数，慧算千机"），超千亿参数多模态，覆盖数百万金融指标、全品类行情（股/债/基/期货/现货/期权/港美/外汇/利率/理财）
- **数据底座**：Choice 数据库（273 条产业链图谱、3.8 亿企业主体、经济数据库）
- **Skills 首发**：2026-03-12，为 OpenClaw 安装"投资决策辅助技能"
- **MCP 上线**：2026-06-29 妙想 Claw 全面开放 + 妙想 MCP 正式上线 + 积分体系启用

### 4.2 东方财富 Skills（2026-03-12 首发 3 个，后扩至 6 个）

| Skill | 能力 |
|---|---|
| 妙想资讯搜索 | 多权威资讯源、实时新闻搜索、事件追踪、舆情监控 |
| 妙想金融数据 | 自然语言查询股/板块/指数/基/债的行情、主力资金、估值；上市/非上市公司基本信息、财务、高管、股东、融资 |
| 妙想智能选股 | 按行情、技术、财务指标选股；按指标、技术信号、主营业务、主要产品筛选 |
| 妙想模拟组合管理 | 组合查询、持仓查询、买卖、历史记录 |
| 妙想自选股管理 | 链接东方财富通行证自选股（A股） |
| 妙想AI社区 | AI 分身、人设配置、自动财经内容生成 |

**六大能力矩阵**：MX_StockPick 智能股票筛选、MX_MacroData 宏观数据洞察（百万级数据维度）、MX_FinData 金融数据查询、MX_FinSearch 财经资讯穿透（分钟级预警）、MX_API 量化API（多语言跨平台）、Financial_Ask 妙想问答。

### 4.3 妙想 MCP（基于 Choice 数据，11 个工具）

> 官方定义："将专业数据、研究动作、结果输出与权限治理统一封装，让模型获得更接近真实研究流程的调用体验。" 让模型从"背诵预训练知识硬猜"变为有专业数据库权限的"开卷考试"，遏制数据幻觉。

| 工具 | 覆盖 |
|---|---|
| `mx_ashare_finance_data` | A股：基本资料、行情技术指标、财务估值、股本股东、公司事件、量化风险指标（alpha/beta/夏普），单次最多 500 只 |
| `mx_hk_finance_data` | 港股（含 IPO/回购/分红） |
| `mx_us_finance_data` | 美股 |
| `mx_fund_finance_data` | 基金：发行信息、业绩绩效、分红、持有人结构、持仓明细、基金公司维度 |
| `mx_bond_finance_data` | 债券：发行兑付、估值（久期/凸性）、发债主体、信用评级、可转债条款 |
| `mx_index_block_finance_data` | 指数/板块：行情、技术指标、财务估值、成分股聚合 |
| `mx_comprehensive_finance_data` | 综合查询（非上市企业等主体） |
| `mx_macro_data` | 宏观/行业/大宗商品高频指标（GDP、CPI、M2、社融、多晶硅、碳酸锂、原油、铜、螺纹钢等） |
| `mx_stocks_screener` | 条件筛选（选股/选基/选债，A股/港股/美股/基金/债券） |
| `mx_finance_search_news` | 新闻/研报检索（评级观点、目标价、盈利预测、风险提示） |
| `mx_finance_search_notice` | 公告披露搜索（定期报告、并购重组、问询函等） |

### 4.4 接入方式

**两步接入**：
1. 登录妙想官网（ai.eastmoney.com）获取 API KEY（限时免费，每日限量 5000 名）
2. 一句话安装：把 `帮我按照 https://mxapi.eastmoney.com/mxds/doc/mcp-install.md 来配置妙想 MCP Server` 贴给本地 Agent

兼容 OpenClaw 等主流平台；阿里云市场已上架（2026-07-16，支持一键同步阿里云百炼 MCP 或生成专属 MCP URL）。

### 4.5 计费（积分体系）

- 统一计量 Claw 问答与 MCP/Skill 调用
- 获取路径：每日登录奖励（首期送 300 积分）、Choice 终端权限折算、Choice 量化 API 权限折算、积分套餐包
- 阿里云市场后付费：0.01 元/积分
- 客服 400-620-1818；运营主体：上海奇思信息技术有限公司

---

## 五、万得 AIFin Market

### 5.1 基本信息

- **官网**：<https://aifinmarket.wind.com.cn/>
- **发布**：2026 年 5 月下旬（首次向外部 Agent 开放 MCP 能力）；2026-06-01 积分充值上线
- **定位**："为 AI Agent 接入专业金融能力"的开放金融能力市场
- **配套**：WindClaw（2026-03-11 上线，专业版 OpenClaw：盯大盘/盯个股/盯消息/股票分析师/宏观研究员/策略挖掘机）；Wind Alice 旗舰 Agent
- **注册**：手机号+短信验证码，免费试用；个人中心领 `WIND_API_KEY`

### 5.2 MCP 服务（7 个 / 32 个工具）

| MCP 服务 | 工具数 | 覆盖 |
|---|---|---|
| 万得股票数据服务 | 9 | 行情、分钟级、历史日线、技术指标、基本面财务、股本股东、公司事件、风险波动 |
| 万得基金数据服务 | 9 | 档案、持仓配置、持有人结构、业绩排名、分红、管理公司 |
| 万得指数数据服务 | 6 | 行情、K线、估值、资金流向、盈利预测、成份股 |
| 万得债券数据服务 | 4 | 发行详情、发债主体、估值风险收益、信用债/可转债专项 |
| 万得金融文档检索 | 2 | 媒体新闻 + 公告披露原文 |
| 万得宏观经济（EDB） | 1 | 宏观指标与经济数据库 |
| 万得金融数据计算 | 1 | AI 驱动跨实体聚合计算（汇总、加权、排名） |

### 5.3 Skills 生态（90 个）

- **万得官方（Wind Alice 出品）14 个**：一页纸投资报告、可比公司分析、信用分析、财报点评、基金筛选、宏观数据解读、主题选股、债券利率走势研判等
- **金融技能（社区/WindClaw）70 个**：DCF 估值、板块轮动雷达、市场主线识别、选股筛选、仓位风控、盘后复盘、公告影响解读、回测验证等
- **数据获取 2 个**：万得金融数据（wind-mcp-skill）、Tushare（220+ 接口，第三方接入）
- **人设技能 4 个**：芒格、塔勒布、纳瓦尔、巴菲特思维框架

### 5.4 完整接入配置

**一键接入**：`阅读 https://aifinmarket.wind.com.cn/skill.md 安装万得金融能力`

**命令行**：

```bash
npx skills add https://gitee.com/wind_info/wind-skills.git --skill wind-mcp-skill -g -y
npx skills add https://gitee.com/wind_info/wind-skills.git --skill wind-alice -g -y
```

**手工 MCP 配置**：

```json
{
  "mcpServers": {
    "wind_stock_data": {
      "type": "http",
      "url": "https://mcp.wind.com.cn/vserver_stock_data/mcp/",
      "headers": {
        "Authorization": "Bearer YOUR_WIND_KEY",
        "Accept": "application/json, text/event-stream"
      }
    }
  }
}
```

**密钥**：全局 `$HOME/.wind-aifinmarket/config`（`WIND_API_KEY=<Key>`）或项目级 `.agents/skills/wind-mcp-skill/config.json`；CLI 调用 `node scripts/cli.mjs call <server_type> <tool_name> '<params_json>'`（server_type：stock_data/fund_data/financial_docs/economic_data/analytics_data）。Skills 双源托管：Gitee（wind_info/wind-skills）+ GitHub（Wind-Information-Co-Ltd/wind-skills）。

### 5.5 计费

免费试用 + 积分扣费制（2026-06-01 上线充值）；具体额度需登录查看；用户协议保留免费服务转收费权利。联系：AIFinMarket@wind.com.cn。

---

## 六、华创金工 MCP

### 6.1 基本信息

- **发布**：2026-08-04 研报《AI 投研工具研究之一：华创金工 MCP 配置与使用》
- **架构**：远程 Streamable HTTP + JSON-RPC 2.0；端点 `POST https://<域名>/mcp/rpc`
- **鉴权**：`Authorization: Bearer <client_secret>`，每客户唯一，定向分发
- **工具**：23 个，分 7 组；更多工具见 <https://www.hcquant.com/MCP.html>

### 6.2 工具全景（23 个 / 7 组）

| 分组 | 工具 | 用途 |
|---|---|---|
| 投研分析（3） | `company_one_pager`、`industry_one_pager`、`run_morphology` | 公司/行业投研报告、形态学量化择时信号 |
| 数据查询（4） | `query_financial_db`、`query_holdings`、`query_supply_chain`、`query_fund_manager_profile` | A股财务库 T-SQL 直查（仅内部）、公募重仓、产业链、基金经理档案 |
| 知识与舆情（1） | `search_knowledge_base` | 知识库全文检索 |
| 资讯与公众号（4） | `query_news`、`search_wechat_accounts`、`query_wechat_articles`、`query_wechat_article_detail` | 财经新闻 + 公众号搜号→文章→正文闭环 |
| 实用工具（5） | `utility_idcard`、`utility_areacode`、`utility_lunar`、`utility_weather`、`utility_phone` | 身份证/区号/农历/天气/手机号 |
| 首席与大师（4） | `list_chiefs`、`list_masters`、`ask_chief`、`ask_master` | 22 位首席 + 29 位大师 AI 人设对话 |
| 文件（2） | `save_to_workspace`、`read_workspace_file` | 工作区保存/读取，CSV 自动转 Excel |

### 6.3 接入配置（修复版）

> ⚠️ 原研报此处配置 JSON 被图片占位符吞掉，以下为按官方协议说明补齐的标准配置：

```json
{
  "mcpServers": {
    "huachuang-jingong": {
      "type": "http",
      "url": "https://<你的域名>/mcp/rpc",
      "headers": {
        "Authorization": "Bearer <你的client_secret>",
        "Accept": "application/json, text/event-stream"
      }
    }
  }
}
```

不支持直连远程 HTTP 的客户端可用 mcp-remote 桥接：

```json
{
  "mcpServers": {
    "huachuang-jingong": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://<你的域名>/mcp/rpc",
               "--header", "Authorization: Bearer <你的client_secret>"]
    }
  }
}
```

### 6.4 注意事项

1. `ask_chief`/`ask_master` 真实调用大模型，有延迟与成本
2. `query_financial_db` 为 T-SQL：限行用 `TOP N`，表名字段名大写
3. 公众号链路顺序依赖：搜号（拿 biz）→ 文章列表（拿 url）→ 正文
4. `query_supply_chain` 用 `code` 或 `name` 二选一；`ask_master` 传 slug（如 `lynch`）
5. client_secret 勿泄露；过量访问封禁
6. `query_holdings.top` ≤ 100、`query_news.days` ≤ 90

### 6.5 优劣势

**优势**：券商研究视角二次加工（买方速览、形态学信号）；公募重仓/产业链/基金经理档案差异化数据；公众号舆情完整链路。

**劣势**：财务库直查仅限华创内部；研报关键配置被图片吞掉；摘要"23 种"与总结"24 种"数字不一致；实用工具组与投研场景关联弱；固定 secret 不轮换 + 任意 T-SQL 传入的安全说明不足；通篇未提三大终端竞品；发布时间最晚（比同花顺/东财晚近 5 个月）。

---

## 七、社区版 wind-mcp

- **仓库**：<https://github.com/abuttoncc/wind-mcp>（MIT 协议，Python + FastMCP）
- **前提**：Windows 机器已安装并登录 Wind 金融终端
- **工具（8 个，核心仅 2 个）**：
  - 核心数据：`wind_wsd`（日时间序列）、`wind_wss`（日截面）——Wind 体系的两大万能取数入口，靠 `fields` 参数查任意指标
  - 辅助：`wind_wses`（板块序列）、`wind_tdays`/`wind_tdaysoffset`/`wind_tdayscount`（交易日历）、`get_today_date`、`search_windpy_doc`（文档检索帮模型自学 API）
- **设计哲学**：不封装专用工具，只暴露底层原语 + 文档检索，把组合权交给模型
- **接入**：

```bash
pip install -r requirements.txt
python src/wind_mcp_direct_server.py --host 0.0.0.0 --port 8888
```

```json
{
  "mcpServers": {
    "wind_mcp": {
      "url": "http://localhost:8888/mcp/",
      "transport": "streamable-http"
    }
  }
}
```

- **优劣势**：开源免费、覆盖面理论全量；但依赖本地终端、模型需熟悉 Wind 指标代码、无鉴权限流，仅适合个人本地使用

---

## 八、横向分析与结论

### 8.1 时间线结论

同花顺、东方财富（2026-03-12）→ 万得 AIFin Market（2026-05 下旬）→ 华创金工（2026-08-04）。"Wind 早就公布了"的评价属实，且**同花顺、东方财富比万得更早**；华创属于券商阵营的跟进者，研报回避三大终端先行者的竞争格局，叙事短板明显。

### 8.2 路线分野

| 玩家 | 路线 |
|---|---|
| 万得 | 数据底座 + 生态市场（MCP 管数据、Skills 管工作流、Alice 管编排），三层全做 |
| 同花顺 | 专业数据源优先（MCP 先行），企业数据（快查）做差异化，Claw 补齐 |
| 东方财富 | Skills 先行（投资决策辅助），MCP 后补，绑定自家账户体系（通行证/自选股/模拟组合） |
| 华创 | 券商研究加工层，专用工具降低模型出错率，主打报告/信号/人设 |
| 社区版 | 底层原语极简封装 |

### 8.3 行业共识

1. **MCP + Skills 双轨制已成标配**：华创研报"为什么选 MCP 而非 Skills"的二选一论述，被同行的实际产品证伪——业界答案是两者都做，"Skills 描述工作流，MCP 提供执行引擎"
2. **三家终端全部配齐"三件套"**：数据 MCP + 技能 Skills + 自研 Claw/Agent（WindClaw、iFinD Claw、妙想 Claw）
3. **积分制成为主流计费模式**：万得、东方财富均上线积分体系，同花顺按次/订阅
4. **安全是暗线**：CNCERT 风险提示 + 券商内部收紧 OpenClaw，金融 Agent 的数据安全、合规审计（黑箱外延风险）将是下一阶段竞争焦点

### 8.4 选型建议

| 需求 | 推荐 |
|---|---|
| 权威全量数据 + 生态最完整 | 万得 AIFin Market |
| 性价比个人用户（¥40/月）+ 企业尽调数据 | 同花顺 iFinD MCP + 快查 Skill |
| 东财账户体系深度用户 + 阿里云集成 | 东方财富妙想 MCP |
| 券商视角研究结论与量化信号 | 华创金工 MCP |
| 个人已有 Wind 终端、零成本本地取数 | 社区 wind-mcp |

### 8.5 风险提示

各平台返回内容均仅供研究参考，不构成投资建议；密钥（client_secret / WIND_API_KEY / iFinD 密钥 / 妙想 API KEY）勿泄露、勿入代码仓库；金融机构内部使用 Agent 类工具需遵守所在机构合规要求。

---

## 附：资料来源

- 华创证券研报《AI 投研工具研究之一：华创金工 MCP 配置与使用》（2026-08-04），本地存档：`./mcp-huachuang`
- 万得 AIFin Market 官网：<https://aifinmarket.wind.com.cn/>
- 同花顺 iFinD MCP 官网：<https://mcp.51ifind.com/>；《iFinD金融MCP正式上线》（2026-03-12）；《行业首发！一个Skill掌握企业全维度数据》（2026-03-23）；《养龙虾缺数据？iFinD MCP & Skill》（2026-05-22）
- 东方财富：妙想官网（ai.eastmoney.com）、Choice 官网（choice.eastmoney.com）、《妙想Skills重磅发布》（2026-03-13）、《妙想Claw全面开放，搭载MCP直击投研深水区》（2026-06-29）、阿里云市场商品页（2026-07-16 上架）
- 21 世纪经济报道：《炒股"小龙虾"来了，三大金融数据终端大厂集体官宣》
- 华尔街见闻：《当Agent重构入口：三家金融信息服务商的十字路口》
- GitHub 社区项目：<https://github.com/abuttoncc/wind-mcp>
