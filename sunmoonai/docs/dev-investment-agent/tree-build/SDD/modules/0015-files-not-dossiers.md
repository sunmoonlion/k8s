# 产出就是项目文件：撤底稿页与结果页，「改动」面板是唯一产出视图（0015）

> 状态：所有者 2026-10-11 定方向，远程写设计，未实施。取代 `PRD/apps/investment.md` 5.6「底稿页」、`PRD/apps/investment-expert.md` 七「E4 底稿」作为页面的部分、账 54（底稿边栏）；改 `SDD/architecture/workspace.md`「结果落两处」的说法；对 0011 知识库留一个所有者决定。

## 一、决定

所有者原话大意：自驾和专家都有工作空间、都在项目里工作，所以不论改文件、删文件、新增文件，都在项目里进行即可；不需要单独的结果页或工作底稿。工作对话和专家对话里要有本次对话的**改动文件列表**（新增的和改的放一起），展示在右边可开合的边栏；第一次出现改动时若边栏没开，自动弹开到那份 diff；边栏有开闭按钮。基本和 Qwen Code 边改边给你看 diff 一个路数。

一句话：**产出 = 项目里的文件；看产出 = 看改动面板；不再有第二份「结果」。**

## 二、现状（2026-10-11）

| 处 | 现在 |
| --- | --- |
| 工作对话页 | 右侧已有 `ResultsPanel` + `ChangesPanel`：列 Codex `fileChange` 项（补丁改的文件）、每项可展开 diff、做完那一刻自动展开。页面上自己写着「命令行里改的文件列不出来」 |
| 专家对话页 | 右侧是「底稿」边栏（账 54），分节显示回答、数据、验过什么……；另有独立底稿页 `routes.dossier`，可导出 Markdown，有「我的结论」草稿框 |
| 专家步骤产出 | 模型把 JSON 写在回复正文里，`judge()` 验收后存 `workbench_artifacts`（数据库）。**从未写进项目目录**；交回物里写的是「顾问没有直接改动工作区文件」。`workspace_path` 列存在但没用 |
| 聊天页 | 也挂了一个 `results.tsx`（聊天不改文件，内容是空话） |
| 知识库（0011） | 第一期的内容来源就是自动归入的底稿与交回物 |
| Codex 侧能给的 | `fileChange` 项带 diff（只覆盖 apply_patch）；`turn/diff/updated` 同样只算 apply_patch；app-server 另有 `fs/readFile`、`fs/readDirectory`、`fs/getMetadata`、`fs/watch` → `fs/changed`（改动路径列表）。本地代理过滤器放行全部 `fs/` 读方法，`fs/watch` 不在清单里但按「其他」放行 |

## 三、机制

### 3.1 改动从哪来

两路合一，按路径去重：

| 路 | 覆盖 | 拿到什么 |
| --- | --- | --- |
| `fileChange` 项 | 模型用补丁改的 | 路径、增删改、现成 diff |
| `fs/watch` 项目目录 | 命令行里改的、脚本写出的、新建的、删掉的 | 只有路径。工作台随后 `fs/readFile` 读现文，与上一次见到的内容比出 diff；第一次见到的文件按「新增」显示全文；读不到按「删除」 |

工作台在对话开始（或页面打开）时对项目目录下 `fs/watch`，对话结束 `fs/unwatch`。「上一次见到的内容」按对话缓存在工作台，只存文本文件、单文件上限 1 MB；超限或二进制只显示「二进制 / 过大，N 字节」不显示 diff。

### 3.2 面板

| 项 | 规则 |
| --- | --- |
| 位置 | 对话右侧，开闭按钮常驻；聊天页不挂 |
| 标题 | 「改动 · N 个文件」，N 随改动实时变 |
| 列表 | 新增、修改、删除三组；每行路径 + `+a −b` |
| 点一行 | 右侧展开统一 diff；再点收起 |
| 自动弹开 | **本次打开页面后第一次出现改动**时，若面板关着，自动打开并选中那份文件。之后只更新列表与数字，不再抢焦点。「做完自动展开」这条撤掉 |
| 来源标注 | 命令行改的在行尾标「命令行」，补丁改的不标 |
| 不显示 | 任何 JSON 原样、任何「结果」「底稿」字样 |

### 3.3 专家步骤的产出改为文件

| 项 | 改法 |
| --- | --- |
| `StepContract` | 加 `output_file`：相对项目目录的路径（如 `底稿/02-数据摸底.md`）。`output_artifact` / `output_schema` / `acceptance` 保留，用于机器验收 |
| `advisor.compose` | 多一节「Deliverable file」：把这一步给人看的成稿写到 `output_file`；结构化结果仍按 `output_schema` 作为 ONE JSON object 回在正文里 |
| 验收 | 不变：`judge(final_text)`。另加一条硬检查：`output_file` 存在且非空（`fs/getMetadata`），缺了按验收不过走 `on_reject` |
| 证据（`I6`） | 验收过后工作台 `fs/readFile` 读成稿，连同 JSON 一起存 `workbench_artifacts`，填 `workspace_path` 与摘要。这份只作回放、验收证据、跨设备恢复，**不再给用户看** |
| 交回物（`AT-25`） | 成稿文件 `交回.md`：做了什么、验过什么、未知、改了哪些文件、怎么恢复。写进项目；`handback` 行照旧存库作证据 |
| 底稿怎么排 | 原 PRD 七的区块规则（回答、数据带角标、专家验过什么、局限、出处；不显示评级与买卖建议）改为**对成稿文件的写法要求**，写进各专家包的成稿步骤 `method_text`。每个专家包声明它会写哪些文件 |
| 「我的结论」草稿框 | 撤。用户要写就写在文件里或对话里 |
| 导出 | 撤。成稿已是项目里的 Markdown |

### 3.4 撤掉什么

| 项 | 处置 |
| --- | --- |
| 底稿页 `routes.dossier`、`dossier-screen.tsx`、`dossier-parts.tsx` | 撤 |
| 专家页「底稿」边栏（`features/expert/ui/results.tsx` 的内容） | 换成与工作页同一个 `ChangesPanel` |
| 聊天页 `results.tsx` | 撤 |
| 项目页「底稿列表」（PRD 5.7 ④） | 改为「专家交回」列表：专家包、终态、费用、时间，点开回到那段对话 |
| MCP `list_project_dossiers` / `read_project_dossier` | 撤。成稿在项目目录里，Codex 自己读；对话记录工具 `list_project_conversations` / `read_project_conversation` 保留 |
| `GET /tasks/{id}/artifacts` | 保留给证据与回放，不进页面 |

### 3.5 不变

`I6`（成功前证据已持久化）、验收条、`AT-25` 交回物契约的内容要求、`workspace.md`「谁能改文件」、方向盘。`workspace.md`「结果落两处」改为：**项目目录那份是给用户的唯一一份；工作台那份只是证据，不成页面。**

## 三之二、做出来的样子（2026-10-12 下午，fable；卡 F2/F3）

| 项 | 做法 | 与 §三的出入 |
| --- | --- | --- |
| `output_file` | `StepContract.output_file`；SMOKE `底稿/烟测-回答.md`、DATA_QUERY `底稿/数据查询-成稿.md`、FIN_REVIEW `底稿/财报体检-成稿.md`；`ExpertPack.deliverable_files()` | 无 |
| compose | 「Deliverable file」一节：路径、用补丁工具写（不要重定向）、写法要求 `DELIVERABLE_RULES`（回答 / 数据带角标 / 专家验过什么 / 局限 / 出处；不给评级与买卖建议；不贴 JSON）；最后一步另加「Handback file」写 `交回.md` | `交回.md` 由模型写：工作台到不了用户电脑，自己写不了 |
| 存在性检查 | 只认这一轮 Codex 报的 `fileChange` 路径（runner 在 turn 内收集进 `TurnResult.files`）；写了就在 `workbench_artifacts.workspace_path` 记路径并发 `step/deliverable` 事件，没写也只记事件 | **软检查，不按验收不过走 `on_reject`**：`fs/getMetadata` 到不了用户电脑（§五），命令行写的又看不见，硬判会误伤；硬检查等账 87 |
| 证据副本 | 只记路径，不复制内容 | 同上，等 87 |
| handback | 加 `files`（各步 `workspace_path`）；`workspace_restore` 列出成稿路径 | 无 |
| 撤掉 | `GET /tasks/{id}/dossier`、`/dossier/export`、`PUT /tasks/{id}/conclusion`；MCP `list_project_dossiers` / `read_project_dossier`；网页底稿页与路由、`dossier-parts`、专家页 `results.tsx`、聊天页 `results.tsx`、`ResultsPanel`、`useAutoOpen`；文案里的「底稿」 | `ExpertDesk.dossier()` / `dossier_export()` 与 `DossierBlock` **暂留**：知识库页（0011）读它们；0011 作废后随账 85 N1 一起撤 |
| 专家页右边栏 | 与工作页同一个 `WorkSidePanel`（搬到 `components/workbench/`，时间线模型搬到 `lib/workbench/timeline.ts`） | 无 |
| 项目页 | 「底稿」列表改「专家交回」：专家、终态、费用、时间，点开回到那段对话 | 无 |

## 四、知识库（0011）怎么办——已定

2026-10-11 晚：0011 的用户私有云端库作废（0018，「用户已经不会上传资料了」），底稿与交回物不再自动归入任何库；侧边栏那一项改为「本地知识库」（0019）。A/B 两案不用选。

## 五、实施前要验的（2026-10-12 已验一条）

**`fs/*` 到不了用户电脑**（2026-10-12 读 Codex 源码核实）：app-server v2 的 `fs/readFile`、`fs/readDirectory`、`fs/getMetadata`、`fs/watch` 一律走 `EnvironmentManager.try_local_environment()`，即 app-server 自己所在的文件系统（我们这里是云端沙箱），没有 `environmentId` 参数，不会经 exec-server 转到远程环境。核心（core）读远程 AGENTS.md 用的是 exec-server 协议里的 `fs/readFile`，那是 Codex 内部的通道，不对客户端开放。

因此本篇分两步落地：

| 步 | 做法 | 状态 |
| --- | --- | --- |
| 一 | 改动面板只用 `fileChange` 事件（补丁改的文件、diff 齐全）；「命令行改的列不出来」照实写在面板上；专家步骤的成稿存证改为让模型在该步输出里带上文件内容（现有 `output_artifact` 机制），不再靠 `fs/readFile` | 可做，不需要代理改动 |
| 二 | 「命令行改的也列出来」、右边栏文件树、本地知识库页：都需要本地代理开一条文件通道给工作台（经会合点，受代理白名单限制）。记账 87，归 astra，排在 0.3.0 之后 | 等代理 |

其余要验的：watch 的代价（第二步再说）；Windows 路径在面板上的显示。

## 六、卡

| 卡 | 内容 | 验收 |
| --- | --- | --- |
| F1 | 工作页与专家页同一个改动面板：两路来源合一、三组列表、首次改动自动弹开、命令行标注、大小与二进制限制；聊天页撤 `results.tsx` | 同一对话里补丁改一个文件、命令行写一个新文件，面板两个都列出、diff 正确、第一次自动弹开、之后不抢焦点 |
| F2 | 专家步骤 `output_file`、compose 新节、存在性检查、证据复制、`交回.md`、各专家包成稿步骤写法 | 跑一次财报体检：项目目录里出现各步成稿与 `交回.md`，面板列出；数据库里有证据副本与 `workspace_path` |
| F3 | 撤底稿页、底稿边栏、导出、我的结论、MCP 两个工具；项目页改「专家交回」列表 | 路由与页面不存在；MCP 工具列表里没有；测试全过 |
| F4 | 知识库按所有者选的 A 或 B | 按选项 |

F1 先于 F2；F3 与 F2 同批；F4 等所有者定。记账 80。
