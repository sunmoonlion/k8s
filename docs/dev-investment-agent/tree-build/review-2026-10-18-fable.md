# 远程 Fable 对 Opus 2026-10-13 至 10-18 工作的审读与完善意见

> 所有者 2026-10-18 让远程 Fable 把这段时间 Opus 做的活审一遍、提完善意见。审的是 origin/qwen 上的代码与文档（k8s `954f5127`、knowbench-backend `f9129c8`、knowlab-backend `4e39358`、knowmart-backend `360effd`、sunmoon-link `750949f`），读的是源码，不是回执。意见按轻重排，每条写清在哪、为什么、建议怎么改；采不采纳由 Opus 定，拿不准的问所有者。
>
> 这份只是审读，不是任务卡；Opus 不必逐条回复，改了的在自己的提交里写明「审读第 N 条」即可。

## 零、总评

做得多、做得快，而且大部分做得对。值得肯定的几处：跨应用服务身份按「关系 × 调用方」各一个、接收方逐项核受众与主体；读用户数据在工作台和 knowlab 两边各核一遍；knowmart 版本只插不改有数据库触发器兜底；计算工具用语法树白名单加十进制，不碰 eval；Linux 包可复现打包；测试电脑只放行三条出站；交付、受理、回答三处都有幂等。回执和设计文档也写得清楚，出了问题能回溯。

下面 16 条里，前 3 条我认为要改，中间 7 条建议改，后面的是小问题和文档。

## 一、要改的（三条）

### 1. 内部接口经公网 Ingress 可达，只靠令牌挡

- **在哪**：每个应用的公网 Ingress 把 `path: /api` 整个转给 api（`gitops/components/app-platform/common/web/workload.yaml.j2`、`common/admin/workload.yaml.j2`），而 `/api/internal/v1/knowbot-runtime`（knowbench）、`/api/internal/v1/knowlab/knowbot-data`（knowlab）、`/api/internal/v1/knowmart`（knowmart）和原有的 `/api/internal/v1/knowledge`（knowbase）都挂在同一个 FastAPI 应用上（各仓 `app/app/interfaces/http/routes.py`）。knowbench 的 `ALLOWED_HOSTS` 同时列着公网名和 `knowbench-tls.…svc.cluster.local`，所以从 `knowbench.sunmoonai.com`（东京边缘对公网开放的那个）发到 `/api/internal/v1/knowbot-runtime/test-runs` 的请求会到达接口，只被服务令牌校验挡住。
- **为什么要改**：总览第 3 节的不变量是「公网只放工作台、casdoor、relay」，内部关系走 traefik service-access 的集群内入口；现在内部面在公网上多了一层可探测、可撞令牌的暴露。knowbase 原来就这样，不是这次引入的；但这次把工作台也加进去了，而工作台是唯一在公网边缘上的应用。
- **建议**：两道都做，便宜。① 应用层：内部路由加一个依赖，`request.url.hostname` 不是本应用的 `<应用>-tls.<命名空间>.svc.cluster.local` 就回 404（主机名已在 `ALLOWED_HOSTS` 里，模板的 TrustedHost 先过一遍，再在这里精确比）。② 入口层：公网 Ingress 在 `/api` 之前加一条 `/api/internal` 指向空服务（或 Traefik 中间件直接 404），边缘 Traefik 同样拒 `/api/internal` 前缀。渲染比对应当只多这几行。

### 2. 有人值守：运营能答「开步前的提问」，答案还被记成用户的预设

- **在哪**：knowlab `application/services/knowbot_questions.py`。`_answer(by="operator")` 对 `ask_before`、`question` 两类都放行（只有 `tool_approval` 是明确归运营的）；答完 `_remember` 不分谁答的，把答案写回 `request.cases[].input.answers`，下次重测就不再问。`to_user` 是运营手动点的，默认 `route` 为空。
- **为什么要改**：0027 §3.4 与 C-L1 的规矩是「投资判断转给用户，拿不准的一律转给用户」。开步前的提问正是分身清单里要用户决定的那类问题；现在默认落在运营手里，运营顺手一答就成了「用户确认过的出处」，这是平台替用户补投资判断，C-L1 守不住。
- **建议**：`ask_before` 与 `question` 两类默认 `route="user"`；运营只能把一条问题**改派给自己**并写一句理由（「这是跑法问题」）才能答；`_remember` 只在 `answered_by == "user"` 时写回用例；运营答的另存，不进 `rule_sources`。网页端「需要我回答的问题」已经有了，改动不大。

### 3. 测试结果里看不到验收为什么没过，平台故障也记成「用例没过」

- **在哪**：knowbench `domain/workbench/test_runs.py` 的 `case_result` 只带 `failed_checks` 的名字；`application/workbench/acceptance_numbers.py` 算出的 `detail`（哪个格子、两边各是多少、还是根本读不到）在这里丢掉。`_sourced` 遇到 `WorkbenchError` 时把异常消息当成一条「没过」返回，于是「reading the user's data is not configured」这种平台配置错误，最后呈现为「第 answer 步没过：取出的数与表里一致」。
- **为什么要改**：qwen-005 走查第 10 行就是这样卡住的：Qwen 在界面和日志里都拿不到原因，等到 Opus 查源码才知道是 runner 没有 `knowlab:read` 身份（`f858689e` 已修）。下一个用户遇到同类问题时，运营与用户都只会看到「没过」。
- **建议**：① 契约 `knowbot-test-run/v1` 的 `StepResult` 加可选字段 `details`（每条没过的验收一句话，截到 200 字；v1 冻结后允许只增可选字段），数值类写「地址 + 说了多少 + 实际多少」，这是用户自己数据里的数，不是分析内容，不违反 C-L5；② `_sourced` 里把 `UserDataUnavailable`、`RecordsRefused` 这类平台侧错误和「数对不上」分开：前者让这一步进 `error`、用例记 `error`，而不是 `failed`；③ knowbench 在 INFO 级别记一行 `run_id + case_id + step + detail`，排查不用翻库。

## 二、建议改的（七条）

### 4. 管理端：白名单里的角色绕过所有权限检查

- **在哪**：tpl `interfaces/http/middleware/auth.py` 的 `require_admin_scopes`（已同步到六个应用）：`principal.roles` 与 `ADMIN_AUTH_ROLE_ALLOWLIST`（部署里是 `admin,operator`）有交集就跳过 `require_scopes`。knowlab 的 `require_knowlab_admin` 就是它，所以 operator 能发起测试、交付、退回。
- **建议**：角色映射到权限，而不是绕过：`admin` → 全部，`operator` → 读与「发起测试 / 回答跑法问题」，交付与退回留给 admin。实现上把角色换算成一组 scope 再走原来的 `require_scopes`，一处改。

### 5. 表格解析：列标签重名会被静默覆盖，`.xls` 的日期列读成数字

- **在哪**：knowlab `infrastructure/documents/table_extract.py` 的 `_sheet`：行标签重名加 `#2`，列标签重名没有处理，`row_cells[column] = …` 后一列覆盖前一列。财报表里「合并 / 母公司」并排、同一报告期出现两次很常见。`.xls` 经 xlrd 读出的日期是浮点序列号，`_label` 把它写成 `45292`，列标签就不是 `2024-01-01`，地址对不上。
- **建议**：列标签同样加 `#2`、`#3`；xlrd 分支按 `cell_type == XL_CELL_DATE` 用 `xldate_as_datetime` 转成日期再 `_label`。顺带在 `read_my_table` 的说明里写明「列标签以这里返回的为准」，模型不用自己猜日期格式。

### 6. knowmart 公开市场只靠一个布尔开关，默认类目把所有专家标成「证券 / 期货投资咨询」

- **在哪**：knowmart `core/config.py` 的 `public_market_enabled`，`application/services/expert_catalog.py` 与 `repositories/knowbots.py` 的 `list_visible(public_market=…)`；`domain/knowbots/catalog.py` 的 `DEFAULT_CATEGORY = "finance.securities_advisory"`，迁移 `20261018_0005` 给现有行写了同样的默认值。
- **为什么**：C-L4 写的是「对外上架的能力不做或锁死，不靠界面隐藏」。一个环境变量算不算锁死，看谁能改：现在一次部署改一行就开了，没有任何「持牌了」的证据门。默认类目的问题是：一个只做办公表格的分身也会被记成「证券 / 期货投资咨询」类，而这个类正是整个定位要避开的那项业务。
- **建议**：① 开关之外再加一道只能由数据证明的门——至少有一条 `review_status = approved` 且未过期的资质记录，并且在决策记录里有所有者的开市决定（提交号写进配置注释）；两样都没有，`public_market=True` 也当 False，并加一个单元测试钉住「开关开着、没有资质时公开列表为空」。② 类目在 knowlab 交付时由运营选（0032 第八节已经列为待定），默认改成一个中性类目，或者没选就不显示类目，不默认成投资咨询。

### 7. 分身清单外层与 pack 的校验分在三处，容易各改各的

- **在哪**：knowmart `domain/knowbots/manifest.py`（外层严格）、knowlab `domain/knowbots/drafts.py` 的 `draft_manifest_problems`（几项）、knowbench `domain/workbench/knowbots.py` 的 `pack_from_manifest`（pack 完整）。三处对 `version`、`runtime`、`pack.version` 的检查各写了一遍，`rule_sources` 的形状只有 knowmart 核。
- **建议**：不是合并代码（三个应用不共享库是对的），而是把「外层 schema」生成 JSON Schema 放进 `knowmart-app/contracts/knowbot/v1/`（已有目录），knowlab、knowbench 的锁文件测试核自己的校验器和 schema 等价，像 `knowbot-test-run/v1` 那样。现在 knowlab 草稿能过、交付到 knowmart 却被 `manifest_invalid` 拒的情形是可能出现的（比如 `rule_sources` 多于 500 条、`data_bindings` 里同一数据绑两次）。

### 8. 百分号的读法三处不一致

- **在哪**：knowlab `number_of`：带 `%` 不算数（None）；knowbench `domain/workbench/test_runs.py` 的 `_number`：去掉 `%` 直接当数（`12%` → 12）；网页导出 `lib/workbench/export/markdown.ts` 的 `numberOf`：`12%` → 0.12。
- **建议**：定一条写进 0030：数据里的百分号格子不当数（用户要算比率就给小数或原值），期望值比较用字符串；网页导出保留现在的 0.12 加百分比格式（那是给人看的）。至少把测试期望那一处和 knowlab 对齐，免得「12%」在一处算过、在另一处算不过。

### 9. 跨应用客户端每次请求新建连接，没有连接复用

- **在哪**：各后端 `infrastructure/external/service_client.py` 的 `request()`：每次 `httpx.AsyncClient(...)` 新建、用完关掉，TLS 握手每次重来。`cells` 取 500 格是一次调用，不碍事；读表格分页、测试轮询会多很多次。
- **建议**：每条关系一个长期的 `AsyncClient`（带 `limits` 与 `timeout`），进程退出时关闭；连接错误对**幂等**的调用（GET、带契约幂等键的 POST）重试一次。不是现在必须做，上量前做。

### 10. 草稿清单在 knowlab 没有大小上限

- **在哪**：knowlab `interfaces/endpoints/knowbot_routes.py` 的 `add_draft`（`manifest: dict[str, Any]`，无上限）；knowmart 交付时限 1 MB（`MAX_MANIFEST_BYTES`）。
- **建议**：knowlab 入口同样限 1 MB、`rule_sources` ≤ 500、`data_bindings` ≤ 64，与 knowmart 一致，免得草稿测过了、交付时才被拒。

## 三、小问题（顺手改）

11. **Word 导出的超链接不筛协议**：`lib/workbench/export/docx.ts` 把 `node.url` 原样写进 `ExternalHyperlink`，Markdown 里的 `javascript:`、`file:` 链接会进 Word 文件。只放行 `http`、`https`、`mailto`，其余当纯文字。
12. **测试期望 `equals` 对布尔用 `is`**：`expectation_met` 里 `value is want`，`value` 来自 JSON 解析是真布尔没问题，但交回物里写成字符串 `"true"` 就永远不等。按字符串小写比一次更稳。
13. **计算记录按事件游标编号**：`knowbot_compute.computations` 用 `c<cursor>`，编号是会话级游标，同一委托内唯一就够；但用户看到的编号会跳（c3、c17、c42）。给模型的说明写一句「编号不连续是正常的」，免得它以为漏了。
14. **本地代理 clone 的 `remember`**：`agent/src/localProjects.ts` 的 `remember` 用 `git credential approve` 把令牌写进用户的凭据管理器。网页上那个勾选框的文案要写明「保存到这台电脑的 Git 凭据管理器」，并默认不勾。
15. **knowbench `TestFolders.prepare` 删 runs 下别的目录**：只删 `runs/` 下、且只在测试电脑上，范围对；但 `fs/remove` 失败时整次测试不开跑、等到超时才报错。建议第一次删不掉就在 run 的 `error` 里立刻写明哪个目录删不掉，不要等一整个超时。

## 四、文档与流程

16. **几处文档和现状对不上，要一次过一遍**：
    - 仓根 `AGENTS.md` 第一段的并列仓清单没有 `knowlab-app`、`knowmart-app`。
    - `switch-test/README.md`「现在的分工」还是 2026-10-12 的（Cursor、astra 两个本地助手），没有 Opus、Qwen，也没写「Opus 主导、fable 不审」。
    - 术语：10-16 定「专家不再用、叫分身」，10-18 改回「都叫专家」。0026、C-L5（「产品与宣传不出现…投资专家」）、`topics/knowbot.md`、本目录的几份 SDD 现在混用。建议按 10-18 的决定统一一遍，并在 C-L5 里写清「专家」可以用、「投资专家 / 顾问 / 荐股」不可以。
    - `docs/rename-tools/`、`docs/rename-receipts/`：改名已完成，按「历史回执不改」的惯例，建议从活文档目录挪到 `scripts/results/rename/`，`docs/` 下只留 `rename.md` 作索引。
    - 顺序：`staging.md` 的第 3、3½ 项（第一条实测、孵化能力）还没走通，0032 专家目录已经实现并排进 qwen-006。所有者看过截图认可，这里不反对；只提醒把 K19–K21（上传数据、改清单、第一条实测）排在 0032 的管理端与发布主体页之前，先证明主线。

## 五、我没有看、或只看了一半的

- knowlab、knowmart 的两个管理端与网页端（约 5500 行 TypeScript）：只核了导出那一块和有没有 `dangerouslySetInnerHTML` 之类，页面逻辑没有逐行读。
- `docs/rename-tools/` 下的改名工具、对齐工具：改名已完成且回执齐全，没有再审。
- knowfeed、knowbase 这次只有改名和样例数据集的变动，没有审。
- 单元测试只看了数量与覆盖的文件名，没有逐个读断言。

审读人：远程 Fable，2026-10-18。
