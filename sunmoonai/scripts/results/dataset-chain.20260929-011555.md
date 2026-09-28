# 本机联调：证券代码 → info → 对象存储 → 知识服务 → MCP 查询

时间：2026-09-29 00:30 至 01:20（上海时间）。在远程开发机上跑，不连任何集群。

| 项 | 值 |
| --- | --- |
| info-backend | `1529b15` |
| knowledge-backend | `a3e115f` |
| 脚本 | `sunmoonai/scripts/local-integration/dataset-chain/` |
| 数据库 | PostgreSQL 16 容器里两个新建的空库，两边的迁移都从空库跑到最新（info `20260927_0012`，knowledge `20260927_0007`） |
| 对象存储 | MinIO 社区版 2025.7.23。平台用的 AIStor 同版本镜像拉到了，但没有许可证时拒绝一切读写，所以没用它 |
| 身份服务 | 替身（只做服务间令牌）。Casdoor 本身不在这次范围内 |
| 任务队列 | 用缓存容器代替。RabbitMQ 的容器在这台机器上起不来 |
| 采集 | 真实访问巨潮与东方财富 |

## 一、同步路径（命令行）：600009

| 步骤 | 结果 |
| --- | --- |
| 采集 | succeeded，80 个请求，28711980 字节，原件全部进对象存储 |
| 建库 | published，版本 `sh600009-financials-9fd91db79529e208`，sha256 `ac5cfd0805d0c7f99be5054c49d9aaf00e3e3f400d27884fe32e44e74fdbac23` |
| 与以前的结果比 | 版本与校验值和 2026-09-27 在本机目录上建的完全相同 |
| 登记 | 知识服务答复 201 |

## 经 MCP 核对：600009（31 项，未过 0 项）

| 检查 | 结果 | 说明 |
| --- | --- | --- |
| info 记下了登记成功 | 通过 | sh600009-financials-9fd91db79529e208 |
| 数据集文件带着版本标识存进了对象存储 | 通过 |  |
| 知识服务的账号能读到文件，校验值与登记的一致 | 通过 |  |
| 知识服务的账号不能写 info 的桶 | 通过 |  |
| 知识服务的账号不能列 info 的桶 | 通过 |  |
| MCP 握手 | 通过 |  |
| 五个工具都在，含按口径名查询 | 通过 | describe_schema、list_datasets、metric_definitions、query_metric、run_sql |
| 登记后专家能列出这个数据集 | 通过 |  |
| 列出的版本就是 info 发布的版本 | 通过 | sh600009-financials-9fd91db79529e208 |
| 列出的内容不含对象位置 | 通过 |  |
| 看得到三张报表 | 通过 | 11 张表 |
| 真值查询经 MCP 的结果与直接读文件逐条相同 | 通过 | 15/15 |
| 2025 年营业收入与文件里的数相同 | 通过 | 13346192164.12 |
| 上海机场 2025 年营业收入是年报上的 13346192164.12 | 通过 |  |
| 按口径名算出的毛利率与手算一致 | 通过 | 0.275143 |
| 毛利率带着是否适用 | 通过 |  |
| 按口径名算出的资产负债率与手算一致 | 通过 | 0.378627 |
| 资产负债率带着是否适用 | 通过 |  |
| 两张表的口径放在一次查询里：拒绝并说明要分开查 | 通过 | these metrics are based on different tables (balance_sheet, income_sta |
| 拒绝：写操作 | 通过 | exactly one read-only SELECT (or WITH ... SELECT) statement  |
| 拒绝：多条语句 | 通过 | exactly one read-only SELECT (or WITH ... SELECT) statement  |
| 拒绝：物理表名 | 通过 | unknown table: phys_income_statement; call describe_schema |
| 拒绝：读服务器上的文件 | 通过 | table functions are not allowed; query the tables by name |
| 没登记的数据集：明说没有，并提示先列清单 | 通过 | unknown dataset: sz000001-financials; call list_datasets to see what exists |
| 不带数据集参数仍然是默认数据集（问数二十题不受影响） | 通过 | 9 张表 |
| 清单里恰好有一个默认数据集，不是新登记的这个 | 通过 | lesson23-business-analysis |
| 清单里登记进来的数据集 | 通过 | sh600009-financials、sh600276-financials |
| 没被授予列清单的令牌列不了 | 通过 |  |
| 但它可以带数据集名查被授予的工具 | 通过 |  |
| 不带令牌访问 MCP 被拒绝 | 通过 | 401 |
| 知识服务取回的文件按校验值命名，内容一致 | 通过 | 2 个文件 |

## 经 MCP 核对：600276（30 项，未过 0 项）

| 检查 | 结果 | 说明 |
| --- | --- | --- |
| info 记下了登记成功 | 通过 | sh600276-financials-2e78fc5c9620dc1c |
| 数据集文件带着版本标识存进了对象存储 | 通过 |  |
| 知识服务的账号能读到文件，校验值与登记的一致 | 通过 |  |
| 知识服务的账号不能写 info 的桶 | 通过 |  |
| 知识服务的账号不能列 info 的桶 | 通过 |  |
| MCP 握手 | 通过 |  |
| 五个工具都在，含按口径名查询 | 通过 | describe_schema、list_datasets、metric_definitions、query_metric、run_sql |
| 登记后专家能列出这个数据集 | 通过 |  |
| 列出的版本就是 info 发布的版本 | 通过 | sh600276-financials-2e78fc5c9620dc1c |
| 列出的内容不含对象位置 | 通过 |  |
| 看得到三张报表 | 通过 | 11 张表 |
| 真值查询经 MCP 的结果与直接读文件逐条相同 | 通过 | 15/15 |
| 2025 年营业收入与文件里的数相同 | 通过 | 31629416193.83 |
| 按口径名算出的毛利率与手算一致 | 通过 | 0.862070 |
| 毛利率带着是否适用 | 通过 |  |
| 按口径名算出的资产负债率与手算一致 | 通过 | 0.115512 |
| 资产负债率带着是否适用 | 通过 |  |
| 两张表的口径放在一次查询里：拒绝并说明要分开查 | 通过 | these metrics are based on different tables (balance_sheet, income_sta |
| 拒绝：写操作 | 通过 | exactly one read-only SELECT (or WITH ... SELECT) statement  |
| 拒绝：多条语句 | 通过 | exactly one read-only SELECT (or WITH ... SELECT) statement  |
| 拒绝：物理表名 | 通过 | unknown table: phys_income_statement; call describe_schema |
| 拒绝：读服务器上的文件 | 通过 | table functions are not allowed; query the tables by name |
| 没登记的数据集：明说没有，并提示先列清单 | 通过 | unknown dataset: sz000001-financials; call list_datasets to see what exists |
| 不带数据集参数仍然是默认数据集（问数二十题不受影响） | 通过 | 9 张表 |
| 清单里恰好有一个默认数据集，不是新登记的这个 | 通过 | lesson23-business-analysis |
| 清单里登记进来的数据集 | 通过 | sh600009-financials、sh600276-financials |
| 没被授予列清单的令牌列不了 | 通过 |  |
| 但它可以带数据集名查被授予的工具 | 通过 |  |
| 不带令牌访问 MCP 被拒绝 | 通过 | 401 |
| 知识服务取回的文件按校验值命名，内容一致 | 通过 | 2 个文件 |

## 二、出错的情况

| 情况 | 结果 | 说明 |
| --- | --- | --- |
| 同一版本再登记一次（幂等） | 通过 | ok |
| 知识服务的登记表仍然只有一行 | 通过 |  |
| 知识服务的登记开关关着 | 通过 | knowledge_registry_disabled |
| 对象所在的桶不在知识服务的允许清单里 | 通过 | knowledge_refused_registration |
| info 的服务身份没有被知识服务绑定 | 通过 | knowledge_rejected_identity |
| info 拿错的口令去换令牌 | 通过 | service_token_unavailable |
| 身份服务不在 | 通过 | service_token_unavailable |
| 知识服务不在 | 通过 | knowledge_unreachable |
| 各项恢复后登记成功，之前记下的错误被清掉 | 通过 | ok |
| 身份服务换了签名密钥，知识服务不重启也能验 | 通过 | ok |
| 知识服务取不到文件时，专家得到的是「不可用」 | 通过 | dataset unavailable |
| 这句话里没有桶名、地址、键、报错原文 | 通过 |  |
| 默认数据集不受影响 | 通过 |  |
| 细节写进了知识服务自己的日志 | 通过 |  |
| 同一个键被写了新内容，成了新版本 | 通过 |  |
| 知识服务取到的仍是登记时的那个版本 | 通过 |  |
| 取回的文件校验值与登记的一致 | 通过 |  |
| info 的账号删不了已留存的版本 | 通过 |  |

每种出错的情况，info 这边得到的错误码与写进自己登记表的错误码一致。

## 三、排队的路径（生产上的走法）：600276

登记批次并排队 → 分发器 → 工作进程，三个任务接力：

| 任务 | 耗时 |
| --- | --- |
| 采集 | 269.6 秒 |
| 建库 | 32.0 秒 |
| 登记 | 0.3 秒 |

已排队：{"ingestion_id": "bdfbd935-a084-4c8f-b151-cb3da1159584", "status": "pending"}  
完成：succeeded|published/true/（280 秒）

## 四、没有覆盖的

| 项 | 原因 |
| --- | --- |
| Casdoor 签发与吊销服务间令牌 | 用了替身。两个后端取令牌、验令牌的代码是真的 |
| RabbitMQ | 容器起不来，用缓存容器当队列 |
| AIStor | 没有许可证 |
| 集群里的网络策略、出站放行、Secret 注入 | 不在集群里 |
| 管理接口（浏览器登录后触发采集） | 要 Casdoor。排队这一步直接调用了接口背后的同一个函数 |
| 专家（模型）自己调用 MCP | 要沙箱与模型的密钥。这里由脚本站在专家的位置上调用 |
