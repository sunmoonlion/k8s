# 「财务分析与预测」第 1 版的数据是怎么准备的

所有者 2026-10-18「你帮我准备不行吗」，Opus 按所有者的指定（贵州茅台、2021 年一季报到 2026 年半年报共 22 期、2021–2025 年报）从**巨潮资讯网的报告原件**取回、整理成表。这是新的 C-L2「平台不提供数据，只按用户指定取回公开披露」的手工做法（代采做出来之前）：只用法定披露渠道的原件，不用财经网站整理过的数，不用 knowfeed 里平台的数（数据拓扑第十一节）。上传由所有者以 sig-am 做。

| 脚本 | 做什么 |
| --- | --- |
| `query.py` | 向巨潮查茅台 2021 年起的年报、半年报、一季报、三季报 |
| `pick.py` | 挑出 22 期报告全文（去掉摘要、英文版、正文） |
| `extract.py` | 用 pdfplumber 从每份原件抽合并三张表的「本期」那一栏，和年报「主要会计数据和财务指标」五项 |
| `build.py` | 写成 Excel（资产负债表、利润表、现金流量表、主要会计数据、出处五张工作表），并自查 |

```bash
python3 -I query.py > list.json && python3 -I pick.py list.json > reports.json
# 下载 reports.json 里的 url 到 raw/<报告期>.pdf，然后：
uv run --no-project --with pdfplumber python -I extract.py reports.json raw extracted.json
uv run --no-project --with openpyxl python -I build.py extracted.json 贵州茅台-三张表与主要会计数据.xlsx
```

2026-10-18 跑出来的结果：22 期、资产负债表 57 行、利润表 43 行、现金流量表 36 行；自查 0 处问题——四条勾稽（资产 = 负债 + 所有者权益；归母 + 少数 = 净利润；期末现金 = 期初 + 净增加；今年期初现金 = 去年期末现金）每期都在 1 元以内，报表里的营业收入、归母净利润、经营现金流与年报「主要会计数据」逐年一致；平台的读表代码（knowlab `table_extract`）读出来与此一致。

文件放在远程机 `/home/zym/sig-am-data/财务分析与预测/`：Excel 一份，加 2021–2025 年报 PDF 五份。
