# 远程对 luna 的审读意见（Windows 代理）

> 只追加，不改旧条。每条对应 `luna-task-windows-agent.md` 的一个停点。luna 读到「可以进下一段」就进；要改的，改完在下一个停点一起交。

## 2026-10-07 · 第 0 段（runtime `e9f194b`）

**结论：第 0 段通过，可以进第 1 段。**两问的判定我这样定：

| 问 | luna 的结论 | 远程的判定 |
| --- | --- | --- |
| 1 无管理员、unelevated、不跑 setup | undecidable（模型认证 403） | 接受不用模型。**改用直接发 `process/start`**：连 exec-server，`environment/add` 后发 `process/start`（沙箱 `workspaceWrite`、网络关），命令是往 cwd 外写文件（用户目录内、用户目录外各一个），再往 cwd 内写一个；elevated（已做过 setup 的家）、unelevated（新家、不 setup）各跑一遍。看的是内层 Codex 沙箱挡不挡。这一项并入第 1 段的第一件事，不另设停点 |
| 2 exec-server 包进外层 | pass（文件写边界） | 接受。`codex.exe sandbox --permission-profile … -- codex.exe exec-server …` 就是 Windows 上 bwrap 那一层的对等物，第 1 段的 `outerSandbox.ts` 按这个做。结论「只改执行端 config 不能给 `sandbox:null` 的文件请求加上限」是对的：产品里始终是外层 + 桥内过滤两层，和 Linux 一样 |

做得好的：不把「文件没生成」当通过；对照组；真实帧入仓；清理清单；没动产品代码。

**第 1 段里一并处理的（来自这次报告）：**

1. 过滤的判定只看 `params.path`（`agent/src/filter.ts` 第 83 行），所以 `data_base64` 和实际的 `dataBase64` 不影响放行与拒绝；但 fixture 要换成这次抓到的真实帧（`clientName`、`initialized`、`dataBase64`、`file:///C:/…`），`probe/frames.jsonl` 空着的就删掉或填上。
2. Windows 路径判定：`file:///C:/Users/...` 与白名单根比较要规范化盘符大小写、分隔符，并且不分大小写；用真实帧写测试（任务书第 1 段已列）。
3. 外层沙箱下嵌套执行（`process/start` 在被包住的 exec-server 里起子进程）能不能跑、`arg0`/PATH 的 `os error 5` 警告是不是真有影响：第 1 段联调时核，核完写进结果。
4. 干净 Windows、Windows 10 的覆盖放到第 3 段装安装包时做，第 1、2 段不需要。
5. 「本机历史上做过 elevated setup」这一条记着：第 1 段 `init` 探测沙箱模式时，要能区分「本机有 elevated 环境」和「没有」，别只看配置文件。

不用改的：报告与 CHECKPOINT 的写法保持；`scripts/results/` 继续只追加。

## 2026-10-07 晚 · 第 1 段中途（runtime `36ec68b`）：沙箱承载方案定了

**决定（所有者 2026-10-07 采纳 luna 的意见）：同意按「内层沙箱 + 严格协议过滤」继续第 1 段。Windows 不做外层，两层嵌套在 0.155.1 上起不来（`CreateRestrictedToken failed: 87`、elevated 超时），不再试。** 但下面几条补齐并通过攻击性用例之后才放开 Windows 启动；不能只凭一次真实路径解析就认定安全。

| 要补的 | 内容 |
| --- | --- |
| 命令权限检查完整 | `process/start` 不只看模式、cwd、workspaceRoots：请求里每一项实际写权限都核；关闭内层沙箱（`sandbox: null` / `none`）、扩大可写目录、放开网络，高于上限的一律拒 |
| 协议入口收紧 | 只放行明确列出的方法；未知方法、二进制帧、没列的消息一律拒并记日志。**读也限在白名单 + 代理自己的 codex-home**（`fs/readFile`、`fs/open`、`fs/readDirectory`、`fs/walk` 等目标在外面就拒）；这一条比 Linux 现状严，Linux 以后跟上 |
| 文件操作的目录联接与竞态 | 检查时路径在白名单内、执行前被换成联接指向外面，这种「检查后替换」要堵。**优先把 `fs/writeFile|createDirectory|remove|copy` 改为由受限执行环境实施**：桥不直接转发，而是在 Codex 的 Windows 沙箱里（白名单可写的 profile）跑一个小助手完成写入，由 OS 挡，竞态自然没了；做不到或代价太大，就必须用攻击用例证明别的办法挡得住替换（联接、符号链接、硬链接、大小写、8.3 短名、`\\?\` 前缀各试） |
| 验收 | 加一组攻击性用例（上面每一项至少一个），全部被拒才算；写进 `agent/test/`，Windows 上跑 |

说明：「和 Codex 自己给 Windows 用户的做法一样」说过头了，只是复用了它的内层沙箱；我们的请求来自远端，安全性取决于桥。官方也说 `unelevated` 隔离较弱——所以 `init` 探测到本机有 elevated 环境时优先用 elevated，没有才用 unelevated，并在状态里写明用的是哪一种。

两处顺手的：

1. 任务书里会合点端口写错了：网页「设置」发的 `init` 命令是 `wss://relay.sunmoonai.com:30443`（走入口），不是 30471。任务书已改，以网页发的为准。
2. Windows 启动「准入没过就拒绝」是对的，保留；上面四条做完、用例全过，再放开。`--no-outer-sandbox` 这个开关在 Windows 上没有意义，去掉或忽略即可。

设计文档 `SDD/modules/0005-agent.md`「本地上限由谁挡」已加 Windows 一段。

## 2026-10-08 · 第 1 段中途：文件写助手不用 Python；应用控制拦未签名 exe

1. **不加 Python 依赖。** 用户机器上只装一个东西（`0005-agent`「分发与安装」），Node、Python、Git 都不要求。助手用我们本来就带的 Node 跑：一个 `helper.mjs`，写入命令是 `codex.exe sandbox --permission-profile <白名单可写> -- node.exe helper.mjs <参数>`。边界由 Codex 沙箱在 OS 层挡，助手里普通 `fs.writeFile` 即可，不需要句柄级接口——联接跟出去会被沙箱拒，这正是把写入放进沙箱的目的。开发时用本机 Node 24；安装包里带官方签名的 `node.exe`。攻击用例照样全跑。
2. **应用控制把新编译的未签名 exe 拦了，这是打包的硬约束。** 说明开着 Smart App Control / WDAC 的机器上，「不签名、点仍要运行」这条路也走不通。所以第 3 段打包**不编译自己的 exe**：包里只放签过名的 `node.exe`、`codex.exe` 和我们的 JS；启动与开机自启走计划任务拉 `node.exe`，快捷方式也指向它；托盘若必须是原生窗口再单独议。把这台机器的应用控制状态（`Get-MpComputerStatus`、Smart App Control 开关、是否有 WDAC 策略）记进结果，第 3 段要在这种机器上装一次。

## 2026-10-08 · 第 1 段（runtime `9d68ed9`）：代码审读通过，三件做完才算交付

**结论：实现方向对、边界做得实（逐项核权限、方法白名单、读限白名单、文件操作进沙箱助手、目录固定、攻击用例、真实会合点上线又恢复），代码审读通过。但还不能进第 2 段：下面三件做完、结果贴 `windows-agent-1b.<时间>.md`，第 1 段才算交付。**

| # | 要做的 | 为什么 |
| --- | --- | --- |
| 1 | **真机端到端一轮。** Windows 代理在线时，所有者在网页上真走：聊天「这个项目里有哪些文件？」；工作里让它建一个文件；请一次专家。结果里贴桥的 `denied` 计数和每一条被拒的方法与原因 | 现在只验了「连上、在线」，没有一轮真实流量过桥。真实轮次里 app-server 的客户端会调 `capabilityRoots/discoverV1`（0.155.1 的 `environmentInfo.capabilities.capabilityDiscoverySandbox: true`，客户端有 `discover_capability_roots`），可能发带 `sandbox` 的 fs 请求，开网时发 `http/request`；这些现在全部被拒。被拒了 app-server 是容忍还是整轮失败，只有实测知道。要加进允许清单的，照样逐字段核、路径限白名单，不是放行了事 |
| 2 | **命令的环境变量。** `windowsEnvironment` 只给 System32 和 node 目录，用户的 PATH 没了：沙箱里跑 `git`、`python`、`uv` 都会「找不到命令」。Linux 版给的是整份 `process.env`。改成：以用户当前环境为底，去掉保留项（`CODEX*`、`SUNMOON*`、`NODE_OPTIONS`、`NODE_PATH`、`RUST*`、`LD_*`），`CODEX_HOME` 固定为代理的家，再叠远端的 env（远端的仍按现在的保留项检查拦） | 安全靠受限令牌，不靠藏 PATH；藏了 PATH 产品就不能用 |
| 3 | **助手响应对着 0.155.1 的真回包核一遍。** 我按手头 Codex 源码（HEAD 的 `exec-server-protocol/src/protocol.rs`）核过：`dataBase64`、`handleId`、`chunk`/`eof`、`isDirectory`/`isFile`/`isSymlink`/`size`/`createdAtMs`/`modifiedAtMs`、`fileName`、walk 的 `entries`/`errors`/`truncated`、`kind: directory|file`，助手拼的都对得上。但我手里不是 0.155.1。luna 用本机 0.155.1 的 `codex exec-server` 对每个 fs 方法各抓一帧真回包，入 `probe/frames.jsonl`，和助手的输出逐字段比；差一个字段按 0.155.1 改 | 助手替 exec-server 答复，字段错一个 app-server 就解析失败 |

不阻塞、但记下的：

- `fs/readFile` 超过 8 MiB 直接拒绝：app-server 读大文件会不会先走 `readFile`，第 1 件实测时看；要是会，改成助手分块读完再答。
- `pinWindowsDirectories` 每个目录起一个 node 进程，一次 `process/start` 可能四五个，64 个并发就是几百个进程。建议改成一个常驻助手进程用 `fs.opendirSync` 持有多个目录句柄（Windows 上打开的目录句柄同样阻止重命名）；先用一个小实验确认句柄确实挡得住重命名，挡得住就改，挡不住保留现状并写明。
- `http/request` 在 Windows 全拒：开网（`ceiling.network=true`）时该和 Linux 一样放行并核字段；第 1 件实测里看它来不来。
- 报告、证据、清理、不扩大结论的写法都好；保持。

第 2 段的内容不变（MCP 合并、抬高上限的本机确认、reject 提示、日志轮转），等上面三件过了再开。

## 2026-10-08 · 第 1 段补验 1b（runtime `0c5779d`）：代理侧的修复接受；两处衔接由双方分头做

**结论：1b 的查法和修法都对**——环境变量继承、14 组 fs 回包逐字段对齐、握手/命令字段按真实 app-server 补齐、拒绝逐条留底、不用模拟轮次冒充验收。1b 仍未通过（三项网页验收没做成），原因是编排端两处要配合，不是代理的错。分工如下。

**远程已做 / 在做（编排端与工作台）：**

1. **编排端的 Windows 沙箱级别。** 你的本机对照说明了：app-server 按自己配置里的 `[windows] sandbox` 决定发给 Windows 执行器的级别，不配就是 disabled、一条 `process/start` 都不发。沙箱入口脚本已加 `[windows] sandbox = "unelevated"`（k8s `2fe6652c`），重建沙箱镜像上现网是待办 33（Cursor 跑），之后所有者回收并重新拉起沙箱。代理侧保持「远端的 `windowsSandboxLevel` 只接受 `restricted-token|elevated`，本机有 elevated 就升级」。
2. **`tmpdir` / `slash_tmp`：先走代理侧，不改工作台。** 0.155.1 的 `workspaceWrite` 自动追加这两个「特殊」可写项，是 exec-server 按执行端自己的 TEMP/TMP 解析的。所以代理可以：给 exec-server 进程设 `TEMP`/`TMP` 指向代理自己管的目录（`%LOCALAPPDATA%\sunmoon-agent\tmp`，代理建、代理清），策略**只在** `tmpdir` 特殊项解析到这个目录时接受它的写权限；`slash_tmp` 查 0.155.1 在 Windows 上实际解析成什么（`cfg!(unix)` 之外多半不生成或指向不存在的路径），按实际处理。这样命令写临时文件照常，白名单没扩到用户的全局 Temp。走不通再由远程改工作台 `turn_settings()` 加 `excludeTmpdirEnvVar` / `excludeSlashTmp`——那会让命令写不了临时文件，是退路。
3. 「＋新建」从项目里点应带上当前项目、独立聊天要说明没挂项目：记账 61，远程改网页端。

**luna 这一轮接着做（仍在第 1 段内）：**

| # | 要做的 |
| --- | --- |
| a | 上面第 2 条的代理侧临时目录方案，加攻击用例：`tmpdir` 指向别处（远端改 env 想改 TEMP 被保留项拦；执行端 TEMP 被换）时拒 |
| b | 白名单内**不存在**的路径：助手现在回「filesystem worker refused request」（5 次），真 exec-server 回的是 not-found 类错误。对着 0.155.1 抓一帧不存在路径的 `fs/getMetadata`/`fs/readFile` 真回包，助手照它答；app-server 探路径靠这个区分「没有」和「不许」 |
| c | 命令结束后客户端补发的 `process/terminate` 现在被当成 `unknown processId` 拒绝并计入 denied：guard 释放后仍认得这个 processId 一小段时间（或照 exec-server 对已结束进程的真回包答），不算 denied |
| d | `environmentConfig/read`：读的是执行端自己的 `config.toml`（代理写的，不含凭据）。第 2 段 MCP 合并要用它，现在先放行**只读这一个文件**（路径固定为代理 codex-home 的 config.toml，字段照 0.155.1 核），别的仍拒 |
| e | 待办 33 上现网、所有者重拉沙箱后，重连 Windows 代理，所有者从**项目页**走三项：新聊天列文件、新工作建 `browser-check.txt`（内容 `Windows stage1b OK`）、请一次专家。贴完整 denied 列表与三项结果；三项都成才把 1b 记通过，然后等审读进第 2 段 |

补一句：`capabilityRoots/discoverV1`、带 `sandbox` 的 fs 请求、`http/request` 这三个，第 e 项实测里看 app-server 发不发、拒了有没有影响；要放行就照「逐字段核、路径限白名单」加。

目录句柄实验（`opendirSync` 挡不住重命名、cwd 固定能挡）结论清楚，保留现状即可；并发进程数问题记着，第 3 段前再看。

## 2026-10-08 · 第 1 段补验第二轮（runtime `526401c`）：代理侧 a–d 接受；混合路径是工作台的错，已修

**结论：a–d 四项（受管临时目录、缺失路径回 not-found、结束后的 terminate、只读代理自己的 config）都做对了，攻击用例到位，接受。** 网页三项失败的两个原因都不在代理：

| 原因 | 处理 |
| --- | --- |
| 测试项目登记的目录 `…\workspace\myproject` 在 Windows 上不存在 | 测试准备的问题。下一轮先在 Windows 上建好目录再在网页建项目，或者项目相对路径留空直接用根目录。代理新加的「工作目录不存在」明确报错保留 |
| `/data/C:\Users\…` 混合路径 | **工作台的错，远程已修。** 顶层 `cwd` 被沙箱里的 app-server 当成它自己的本地路径解析（0.155.1 的 `resolve_request_cwd` 对非 POSIX 绝对路径按进程当前目录拼接），`environments[].cwd` 则按「POSIX 或 Windows 绝对路径」各自解析。investment-backend `7ac05d2a`：Windows 目录只放 `environments[].cwd`，不放顶层；Linux 目录照旧两处都发。待办 34（Cursor）重建上线。**代理不用改，也不要剥 `/data`** |

**修完后可能还剩的一种条目，代理可以这样处理：** 不发顶层 `cwd` 时，app-server 的「后备目录」是它自己的进程目录（POSIX 路径），`turn_context` 里可能仍出现一条 `<POSIX 路径>/.codex`、`access: "read"`、`missing_path_behavior: "skip"` 的权限项。这种项**只读、缺了就跳过、路径在 Windows 上根本解析不了**，给不出任何权限。策略可以对它「丢弃这一项后继续」（只限这三个条件同时成立：只读、skip、非 Windows 绝对路径），写或不带 skip 的照旧拒。加一条用例；实际出不出现，下一轮网页验收看。

**下一轮（待办 34 上线后）：**

1. Windows 上先建好测试目录，网页里用它建项目（项目相对路径留空最省事）。
2. 接 Windows 代理，所有者从项目页走三项：新聊天列文件、新工作建 `browser-check.txt`（内容 `Windows stage1b OK`）、请一次专家。
3. 贴完整 denied 列表与三项结果，恢复 Linux 代理。三项都成就把 1b 记通过，等审读进第 2 段。

`fs/getMetadata` 越白名单的探测（49 次）是 app-server 在找配置与技能文件，拒了不影响轮次，照拒不放。

## 2026-10-08 · 断线恢复修复（所有者临时授权，已上现网）与 1b 收尾：接受，1b 通过，可以进第 2 段

审读范围：investment-backend `ab4da30`+`0f0ae68`，investment-web-frontend `9c47e30`，k8s `dfe30caa`/`1fd485d3`/`0fd49141`，runtime `3bf4d3d`…`3e925e3`。远程已并入 fable：后端、网页的 fable 分支快进到你的提交，投资父仓指针跟上，k8s 合并（冲突只在镜像号与 flux 源，取你一侧——那就是现网；合并后 `gitops/`、`infrastructure/` 与你的发布树逐字节一致），晋级提交打 `release-20261008-2`。

**远程复跑：** 后端全套 854 过 / 5 跳过（两个测试库都接上），ruff、import-linter 4 条过；网页 192 过 / 2 跳过，typecheck、lint、i18n 过。

| 部分 | 结论 |
| --- | --- |
| 专家等环境的恢复 | 对。心跳只排探测、runner 用公开协议问 ready、账房在一个事务里查齐所有者/会话/环境/操作权/取消/活跃对象再 WAITING→QUEUED，重复与取消竞争只生效一次；保留失败 Attempt 走既有重试。没恢复 INPUT/RESOURCE 等待，范围收得对 |
| 断线通知按 thread 隔离、短断恢复清标记 | 对。原来一台机器断了会把所有在等的 turn 都判丢 |
| 网页：停止看任务状态、窄屏保留按钮、409 占用说明与入口、首句失败复用会话 | 对 |
| Redis 只开 `investment:workbench:*` 的 publish/subscribe/unsubscribe | 对。prepare 里卡死只能是本应用的工作台频道，初始化实收实发再验越界被拒，verify 也接上了 |
| runtime `3bf4d3d` 丢弃 POSIX 只读 skip 项 | 正是上轮允许的三条件，用例把写、非 skip、多字段、混合路径、UNC、`\\?\`、8.3 短名、ADS 都拒了，好 |
| 报告的「不能扩大的结论」 | 写得清楚，保持：运行中断线原命令输出不恢复；真实取消点击未实测；专家 Profile 与问题不配，只证状态机 |

**1b 记通过。** 三项都在 Windows 代理在线时由所有者从网页走过：新聊天列文件、新工作写文件（`browser-check.txt` 与重连后的追加）、专家（断线恢复后续完并交还）。可以进第 2 段。

**流程上的两点（不是代码问题）：**

1. 你的 k8s 提交基于旧的 `origin/luna`（少了远程 5 个提交），所有者回传时 rebase 冲突停下。以后**动 k8s 之前先 `fetch` 并对齐 `origin/luna`**；尤其要发布时，基线必须是现网那一版的提交。
2. 回传脚本原来只推两个后端子仓，你的网页提交没推上来。`human-remote.sh` 已改成：父仓下所有子仓有新提交就推（没新提交的不推）。

**留给后面的（记着，不阻塞第 2 段）：**

- `sources.yaml` 里投资的 `backend_parent_revision`/`web_parent_revision` 还指旧父仓指针；下次投资发布时远程一并对齐到新父仓提交，现在不为它重发。
- 真实网页「停止」点击取消，下次自然遇到时补一次实测。
- `environmentConfig/read` 那两次投影拒绝，第 2 段做 MCP 合并时一起定。
- 你本地的 `source-before.yaml` 回退锁已过时（现网就是新版本），不要再用它回退。

**下一步：** 所有者跑 `WS=luna bash ~/switch-test/human-local.sh` 对齐后，按任务书进第 2 段。

## 2026-10-08 深夜 · 第 2 段与第 3 段候选（runtime `a95910f`，k8s luna `2b37f36a`，investment-backend luna `db96b40`）：接受为交接点；明天起由 Fable 在 luna 分支接着做

luna 今晚到点停手。所有者定：之后由 Fable 在 runtime 的 `luna` 分支上接着开发，Cursor 在 Windows 上跑待办，仍是整体做完后一次性并进 fable。

**远程复跑：** 代理 typecheck 过；vitest 172 过 / 32 跳过（Windows 专用）——先 `pnpm build` 再跑，`cli --help` 四项依赖构建产物；发行包单测 27/27。

| 部分 | 结论 |
| --- | --- |
| 本机确认 → 工作台记账 → 会合点回执 → 才放行命令 | 对，真机走通（报告 `windows-agent-2.20261008-2315.md`）。回执只证明记过账，权限只能本机给；`danger-full-access` 后端直接拒，不能批准 |
| MCP 走用户电脑发 HTTP（`http/request`） | 发现对、改得对：只准本机确认、启用中的 MCP 地址**整串完全相等**；必须 `redirectPolicy=stop`；网络开关关着一律拒；不许改 Host/代理头；地址只从本机启动时读的确认文件来，云端给不了。这是本段最要紧的边界，接受 |
| 会合点权限报告（k8s `1d01771f`）与后端 `db96b40` | 设计对：先入库提交、再发回执；同 id 改内容拒；按所有者、机器、线程三项核对。已由 Cursor 发布上线（`4b6746bc`） |
| 第 3 段：后台常驻、托盘、登录自启、停止、卸载 | 代码在，源码形态在 Windows 上单项验过；**完整安装包没组过、没走过安装闭环** |

**仍待验（明天按顺序）：**

1. 组完整安装包，在你的 Windows 上走：安装 → 启动 → 关托盘（后台还在）→ 停止 → 卸载，配置保留。
2. 真实联网 MCP：本机回环起一个固定回显服务 → 确认导入 → 打开网络开关 → 云端实际调用拿回固定文字 → 关网、停代理、恢复。
3. 重启电脑后登录自启。
4. 干净的 Windows（Windows 沙盒或虚拟机）上从零安装。
5. 两次旧的 `environmentConfig/read` 投影拒绝：抓原始参数再定，不猜着放行。

**特别注意：** 现网的会合点和投资后端是 luna 分支发布的版本（`4b6746bc`），fable 的 k8s 里没有。**在 luna 并进 fable 之前，不能从 fable 发投资后端或会合点**，否则会把现网退回去、本机确认链就断了。

## 2026-10-09 · 第 2、3 段续做（runtime `9f2b5c6`…`60b17d1`）：接受；先更正上一节

**更正上一节：** 「明天起 Fable 在 luna 分支接着做、Cursor 跑 Windows」作废——所有者已定仍由 luna 开发、Fable 审读。上一节说「完整安装包没走过安装闭环」以 `a95910f` 为准，已被 `9f2b5c6`/`3d5b48e` 的实测推翻；「合并前不能从 fable 发投资后端或 relay」仍有效。

**远程复跑（`60b17d1`）：** 先 build 后 vitest 174 过 / 32 Windows 专用跳过；发行 27/27。

| 部分 | 结论 |
| --- | --- |
| 真实联网 MCP（`73bb78c`） | 接受：云端 app-server → relay → Windows 执行端 → 本机 MCP 拿回固定文字；`redirectPolicy=stop`；确认地址之外的请求被拒且不影响调用；网络、代理、凭据副本都已恢复。**请在报告里点名那次被拒请求的完整 URL 和来源**（是不是 Codex 自己探认证/元数据），说明拒掉为何无害 |
| 托盘状态与目录勾选（`b5ba251`/`21f864b`） | 接受：`rootChoices` 只记位置不授权，实际权限只看 `roots`；勾选项必须是候选之一、去重、控制目录与 codex-home 不能入候选；全部不勾时代理照常起、命令一律拒并告警。状态文案不再直接甩 JSON |
| 新包 `21f864b` 安装闭环 + 已装实例普通用户真实连上 relay | 接受。AT-WA-01 的「网页我的机器在线」还差所有者肉眼看一次 |

**仍待验（顺序不变）：** 托盘弹窗真人点「允许」→ 记账 → 执行；网页上看已装实例在线；重启后登录自启；可选 UAC 提权安装；干净 Windows；两次旧 `environmentConfig/read` 拒绝的原始参数。

**下一件开发（所有者 2026-10-09 提出，先只出方案不写代码）：** 用户从哪下载安装包、首次令牌怎么拿。牵涉网页「我的机器」页和后端，方案写成一页交 Fable，所有者定了再动手。

## 2026-10-09 · 下载与首次接入方案（runtime `55ff0e1`）：所有者已定，可以开工

方案整体接受。所有者定案（已记 `tree-build/decisions.md`）：

| # | 定案 |
| --- | --- |
| ① 路线 | 按你的最小路线：首次令牌随创建沙箱签发一次，先登记模型 key；浏览器登录配对留第二期 |
| ② 有效期 | **代理令牌 30 天**（不是 24 小时：每天重领会让开机自启没意义）。网页显示到期时间，可随时「重新领取并吊销旧令牌」；只改代理令牌的签发参数，其它令牌不动 |
| ③ 范围 | 先在开发站点走通；GUI 允许、网页在线、重启自启、UAC、干净 Windows 补齐前不算正式对外发行 |

**开工前先做一件小事：安装包 478 MiB 太大。** 列出最大的 10 个文件（路径 + 大小），查有没有重复的 Codex 可执行文件、调试符号、用不到的平台文件；能瘦就瘦，再报一次 ZIP 压缩后的实际下载大小。瘦身不得删安全相关的文件（沙箱辅助程序、许可证）。

**下载地址不要写死：** 边缘（东京那台）还没建，安装包放哪由远程定。后端只认一份配置——下载地址、版本、ZIP 与清单的 SHA256、兼容的 Codex 版本；没配就在「我的机器」显示「暂不可下载」。网页、后端、CLI 照这份配置做，托管位置之后由远程接上。

**开工顺序**同你方案：后端（30 天、防重复签发、`no-store`、身份/CSRF）→ CLI 隐藏输入令牌 → 网页把设置页的接入流程搬到「我的机器」→ 组包。每段本地提交；改到投资后端和网页属于跨仓，照旧只在 luna 分支，**要发布时先停下来说**，不要自己发。

### 补充（所有者 2026-10-09 定）：网页入口不只放在「我的机器」

用户不会想到去点「我的机器」。在**用得着的那一刻**带他去接入，几个入口都指向同一个接入页：

| 时机 | 做法 |
| --- | --- |
| 第一次登录、一台电脑都没接 | 首页顶上一张卡片：「第一步：把你的电脑接进来，工作和专家才能读写你的文件」+「接入电脑」按钮；接上后卡片消失 |
| 开始「工作」或「请专家」时没有电脑（现有 `noMachine` 拦截） | 拦下的提示里直接给「接入电脑」按钮 |
| 新建项目要选目录、却没有电脑 | 同上 |
| 侧栏状态「还没有登记机器」 | 可以点，点了去接入页 |

- 接入页按步骤带着走：下载 → 安装 → 领令牌 → 选目录 → 看到在线，每步完成打勾（可在现有 `machines.guide` 三步的基础上改）。
- 改名：「我的机器」→「**我的电脑**」，按钮统一叫「**接入电脑**」，中英文案一起改。
- **聊天不提示**：聊天在云端沙箱里跑，不需要用户电脑；只有工作、专家、新建项目时才出现入口。

## 2026-10-09 · 下载与首次接入候选（backend `8279c2c`+`ed77f73`、web `039fa96`、runtime `43182c6`…`b6f00c3`）：接受，未发布

**远程复跑：** 后端全套 881 过 / 5 跳过，ruff、import-linter 4 条过；网页（Node 24）205 过 / 2 跳过，typecheck、lint、i18n 过——Node 25 下 `localStorage` 那一项会挂，是环境不是代码，`engines` 已写 `<25`。

| 部分 | 结论 |
| --- | --- |
| 后端：代理令牌 30 天、首次只给一次、按身份版本号轮换、同一人的签发/轮换/撤销用 advisory 锁串行、下载走配置未配显示不可下载、`no-store` | 接受。注意 30 天只在 JWT 路径生效；现网已配签名密钥（`workbench-signing.yaml`），发布时核一下状态接口回的到期时间 |
| CLI 隐藏输入令牌 | 接受，令牌不进命令行与历史 |
| 包体审计 | 接受：大头是官方 `codex.exe`（307 MB），六个 exe 各不相同、无调试符号；不删官方程序。压缩后下载 166 MiB，可以 |
| 网页：接入流程从「设置」搬到「我的机器」 | 接受，但**还差上一节补充的入口**（你开工时没拉到）：首页首次卡片、工作/专家/新建项目缺电脑时的「接入电脑」按钮、侧栏状态可点、「我的机器」改名「我的电脑」、聊天不提示。下一步先做这个 |

**发布：** 停在发布前是对的。要发布的是后端 + 网页成对上线，外加安装包托管，托管位置远程来定。网页入口补完再一起发；到时先停下来说，由所有者安排。

**仍待验：** GUI 真人允许、网页肉眼在线、重启自启、UAC、干净 Windows、两次旧投影拒绝原始参数、MCP 那次被拒请求的完整地址（原探针没存，下次真实 MCP 时把完整 URL 记下来即可，不用为此专门重跑）。

### 安装包托管（所有者 2026-10-09 定：方案 A，后端转发；边缘建好再切）

集群对象存储（AIStor）只在集群内可达，浏览器连不上，所以第一期由投资后端转发；边缘（东京）建好后改成边缘静态下载，**只换下载配置**，网页和代理不动。

| 步 | 做法 |
| --- | --- |
| 1 桶与身份 | 对象存储建私有桶 `agent-releases`；投资后端一个**只读该桶**的身份，上传另一个**只写该桶**的身份。照 info/knowledge「每应用一桶一身份」的现成做法，凭据进私有输入与 SOPS，不进 Git 明文 |
| 2 下载接口 | 投资后端：登录后才可下；对象名与 SHA256 只取后端配置，用户参数不能指定文件；返回 `Content-Length`、校验值，支持 `Range` 断点续传；流式转发，不整包读进内存；未配置照旧「暂不可下载」 |
| 3 上传 | 一个上传命令（`infrastructure` 下的 make 目标）：先核 ZIP 的 SHA256 与清单，对上才传，传完读回再核一次；同名版本不覆盖 |
| 4 发布 | 网页入口补完后，后端 + 网页 + 桶与身份 + 上传安装包一起上线，从网页「下载 → 安装 → 领令牌 → 在线」整套走一遍；发布前停下来说，由所有者安排 Cursor |

全部在 luna 分支做（现网投资后端本就从 luna 分支发出）；k8s 的改动也算在内，我照常审。下载配置要能表达「后端转发」与「外部地址」两种，边缘建好时只改配置。

## 2026-10-09 · 「接入电脑」入口（web `2e62fcd`）：接受

远程复跑（Node 24）：网页 220 过 / 2 跳过，typecheck、lint、i18n 过。

首页首次卡片（接上就消失、聊天不出）、首页/专家/请专家缺电脑时的「接入电脑」按钮、新建项目缺电脑或缺目录的提示、侧栏可点并显示在线状态、「我的机器」→「我的电脑」、五步引导，都照定案做了；入口只导航，不替用户签令牌或授权目录，对。

小意见（不挡）：首页每 5 秒刷一次电脑列表——一旦有电脑接上就可以停掉，或只在卡片显示时刷。

**下一步：** 上一节的安装包托管四步（私有桶 + 两个身份、后端登录后转发、上传命令、成对发布），做完停在发布前。

## 2026-10-09 · 安装包托管候选（backend `a01db6f`、web `2095c04`、k8s `f9089310`、parent `231f305`）：接受，可以准备发布

**远程复跑：** 后端全套（两个测试库都接上）920 过 / 5 跳过，ruff、import-linter 4 条过——你那边 258 项因没配测试库跳过，这里补齐了；网页（Node 24）226 过 / 2 跳过，typecheck、lint、i18n 过。

| 部分 | 结论 |
| --- | --- |
| 后端下载转发 | 接受：登录才可下；对象名、长度、摘要只来自配置，带查询参数直接 400；每次请求单独建存储客户端；拒绝跳转与换主机；整包下载边读边算摘要，最后一块核对后才放出；单段 Range、206/416、If-Range 都有 |
| 桶与身份 | 接受：私有桶、关匿名、开版本；reader 只 `GetObject`、writer 只 `PutObject`；API 只拿 reader；凭据走私有输入与 SOPS |
| 上传 | 接受：先全包校验，`If-None-Match: *` 不覆盖，读回用另一身份重算摘要，再验两个反向拒绝；失败不清桶 |
| 四项页面修改 | 接受 |
| 两段开关（`enabled` 先开、读回成功后才 `download_available`） | 好，网页不会提前出现坏链接 |

**发布前请你补两件（远程这边改发布配置要所有者另行放行，所以仍由你做，我审）：**

1. 在 luna 的 k8s 钉版本：`sources.yaml` 的 investment 改为 parent `231f305d…`、backend/backend_parent `a01db6f1…`、web/web_parent `2095c049…`（两者都是现网 `db96b40`/`9c47e30` 的后代，我已核）。
2. 写 Cursor 发布卡 `inbox/2026-10-09-35-agent-release-hosting.md`，照你 README「发布顺序」分三段，每段失败即停：
   - **A：** 构建 investment 后端与网页 → `enabled: true`、`download_available: false` → stage → 提交 → flux-release → 晋级 → 应用 → `application-check(-public) APP=investment`；先存当前 flux-source 与两个 image.lock 作回退点（不用旧的 source-before.yaml）。
   - **B：** `agent-release-verify` → `agent-release-upload`，ZIP 用 `/mnt/c/Users/zymun/sunmoon-probe-runs/windows-agent-3-20261009/sunmoon-agent-0.2.1-6de6002-windows-x64.zip`；回传回执、两个拒绝结果、重复上传不新增版本。
   - **C：** `download_available: true` → stage → 提交 → 发布晋级 → 检查；未登录请求被拒、HEAD 长度对。浏览器真人闭环留给所有者。
   - 回传路径、不 push、不并 fable，照旧。顺手把已执行完的 `2026-10-08-luna-stage2-cursor.md` 挪到 `done/`。

做完提交，所有者同步回来，我先审卡，再交 Cursor。

## 2026-10-09 · 发布卡 35（k8s `87f56ec2`…`70528a59`）：审阅通过，可交 Cursor

- 版本锁：investment parent `231f305d`、backend/backend_parent `a01db6f1`、web/web_parent `2095c049`，admin 不动——与审过的提交一致，且都是现网版本的后代。
- 命令都在 Makefile 里；`application-publish-*` 会接着跑 `application-lock-*` 写进 `image.lock.yaml`，不会出现「镜像推了、声明没换」。
- A/B/C 三段、每段失败即停；回退点用本轮新存的 flux-source 与两个 image.lock，明写不用旧 `source-before.yaml`、不从 fable 发；B 失败不清桶；C 之后真人闭环留给所有者。对。
- 补一句给执行者：C 里「已登录 HEAD/下载」如果没有不经真人的登录办法，就只做未登录拒绝、HEAD 未登录拒绝、`application-check-public`，把「已登录下载」明确记为未做，留给所有者在浏览器里验，不要为此造会话或改登录。

所有者通知 Cursor 后按卡执行。回传后我核结果、给晋级提交打 tag。

## 2026-10-09 · 待办：集群重启后 DNS 拖慢，彻底修好（所有者定「按彻底修好做」）

Cursor 回执 `agent-release-hosting-cursor.20261009-1358.md` 停在 A 之前是对的：23/71 个 Kustomization 不 Ready，investment API/Worker 不可用。你的诊断接受（WSL `resolv.conf` 的搜索后缀是网段 `172.16.8.0/22`，经 Docker → KIND 节点 → Pod；`ndots:5` 让完整服务名先拼后缀、被转发上游超时，约 4 s，而就绪预算 2 s）。**发布卡 35 暂停，等本待办验收后再交 Cursor 重跑（卡不用改）。**

分三层，按顺序，每层验收过了再往下。

### 一、主机：去掉坏后缀，并让 WSL 不再受它影响

1. 查来源（只读）：Windows 上 `Get-DnsClientGlobalSetting`（SuffixSearchList）、`Get-DnsClient | Select InterfaceAlias,ConnectionSpecificSuffix`、VPN/虚拟网卡；WSL 的 `.wslconfig`（是否 `dnsTunneling`/mirrored）。在报告里写清是谁加的这条后缀。
2. 能在来源处改就改（例如某网卡误填的 DNS 后缀）；VPN 每次连上都会加回来的，不改 VPN，改第 3 步。
3. WSL 不再自动生成：`/etc/wsl.conf` 的 `[network] generateResolvConf = false`，自己写 `/etc/resolv.conf`：保留现在可用的 nameserver，`search` 只留合法域名或不写。改前备份原文件。
4. 重启 WSL（会整机停一次集群，**先跟所有者约时间**），让 Docker、KIND 节点、Pod 都拿到新的解析配置。不重建集群、不 `docker prune`、不碰老 kind 集群和维护标记。

验收：节点容器与任一 investment Pod 的 `/etc/resolv.conf` 里不再有 `172.16.8.0/22`；Pod 内解析 `postgresql.<data ns>.svc.cluster.local`、`redis.<data ns>.svc.cluster.local`（不带尾点）各 < 100 ms，连测 20 次贴分布；71 个 Kustomization 全 Ready；investment/info/knowledge API 与 Worker 可用；`application-check(-public)` 三个应用都过。

### 二、集群：以后主机 DNS 再出怪事，也拖不垮我们

1. 我们自己的工作负载（app-platform 下各应用的 api/worker/scheduler/runner/web/admin 及初始化 Job）统一加 `dnsConfig.options: [{name: ndots, value: "2"}]`，放在 common 模板里一处改；完整服务名（4 个点）就直接查，不再挨个拼后缀。确认集群内用到的短名（只写服务名的）在 `ndots:2` 下仍能解析，用到的都列出来核。
2. 平台检查加一项 DNS 体检：节点 `resolv.conf` 的搜索项必须是合法域名（不能含 `/`、不能是 IP 段）；从一个 Pod 里解析一个数据服务全名，超过 200 ms 判失败并给出「查主机 DNS 搜索后缀」的提示。挂到 `platform-status` 或 `platform-check`，失败要醒目。
3. 只做候选：render/stage、单测与 diff 交我审；**发布另写 Cursor 卡（36），在卡 35 之前发**，不与卡 35 合并。

### 三、MongoDB 的就绪超时

第一层做完再看：恢复了就记为同一原因；没恢复单独查（日志、探针、资源、卷），找到原因再提方案，不要先改探针阈值来「过」。

### 交回

报告写 runtime `scripts/results/cluster-dns-fix.<时间>.md`：来源、改了哪些主机文件（原文备份位置）、重启时间、每项验收的原始输出；第二层的候选提交号。只本地提交，所有者同步给我。主机文件不进 Git，私有内容不贴。

### 补：先做「零、和老集群对比」（只读，所有者问「之前的集群为何没有这个问题」）

在第一层动手前，只读核三件事，结果写进报告，回答「老集群为什么没出事」：

1. **当时有没有这个后缀**：老 kind 集群停着，不要启动它；只读它节点容器留下的 `resolv.conf`（`docker inspect -f '{{.ResolvConfPath}}' <老节点容器>` 指向的文件，是它上次启动时的快照）和新集群节点的对比，看搜索后缀有没有 `172.16.8.0/22`、各自的生成时间。
2. **转发去哪**：两边 CoreDNS 的 Corefile（老的从 Git 历史或节点快照里读，新的 `kubectl -n kube-system get cm coredns`）里 `forward` 指向哪里；同一个带坏后缀的名字，上游是「很快回不存在」还是「超时」，差别就在这儿。
3. **谁对慢解析敏感**：老集群上的应用有没有 2 秒级的就绪检查要连数据库/Redis；新体系 investment API 的就绪检查在 2 秒内要做完 Redis ping 和 schema 核对，慢 4 秒必挂。

不改老集群、不启动它、不碰维护标记。

## 2026-10-09 · DNS 修复回执（runtime `37d6e98`，k8s 候选 `92a7c0d2`）：第一层通过；第二层要改；先查 TLS 输入

**第一层（主机）通过。** 来源（Wi-Fi DHCP 下发 `172.16.8.0/22`）、`wsl.conf`/`resolv.conf`/`.wslconfig dnsTunneling=true` 三处改动与备份、重启后验收（节点无 search、Pod 无坏后缀、解析中位 1.5 ms、71/71 Ready、三个应用内外检查全过、MongoDB 同因已好）都清楚。`make cluster-dns-check` 只读体检好。路由器不用等。

**发布卡 35 现在可以交 Cursor 重跑**（集群已健康，卡不改）。顺序改为：**先 35，再做 ndots**——主机已修好，ndots 只是防再犯，不急；而且 investment 的渲染要等 35 把 `a01db6f` 的镜像构建出来才对得上源锁（你看到的 `source_revision == backend_revision` 断言就是这个，不是故障）。

**第二层候选要改：**

1. **只给长期运行的 Deployment/StatefulSet 加 `ndots`**（我们应用的 api/worker/scheduler/runner/web/admin，casdoor 主服务可留）；**初始化/迁移/身份/Redis/RabbitMQ/存储 Job 和 casdoor 的 database/init Job 都去掉**。Job 模板不可变，改了就得换名重跑一遍建库、建身份，这个风险换来的收益几乎为零（Job 慢几秒只是慢）。
2. `cluster-dns-check` 并进 `cluster-status` 可以；本工位缺 `kind` 用既有 `make install-binaries BINARIES=kind` 装，不另找来源。
3. 做完、35 发完后，另写卡 36 发布；那时 investment 渲染会自然通过。

**先查清一件意外（优先于上面）：** 你渲染时「info、knowledge 的 TLS 私有输入主备都缺」，流程就**新生成**了两套证书输入到 `/etc/sunmoon/applications/sunmoon-kind/{info,knowledge}/tls/`。现网这两个应用明明在用证书，所以「缺」本身就可疑——可能是路径/工位配置不同，也可能真丢了。在任何 stage 之前：

- 只读比对：新生成文件的证书指纹 vs 集群里这两个应用当前 TLS Secret 的指纹（只比指纹/序列号/到期，不输出私钥）。
- 查原来那份去哪了：同主机 fable/cursor 工位当时渲染用的是哪个路径；备份目录里有没有旧的。
- 结论写报告：如果是同一份或找回旧的，恢复旧的；如果新旧不同，**新生成的先移到带日期的隔离目录（root 0700），不要删、也不要用**，等所有者定。渲染 info/knowledge 前必须解决，否则一发布就是悄悄换证书。

### TLS 核对结论（所有者 2026-10-09 15:2x 在主机上只读跑出）：证书完好，解冻

| 应用 | 线上 Secret | 私有 `server.crt` | 备份 `server.crt` |
| --- | --- | --- | --- |
| info | `2B:FC:94:78…72:41`，到期 2031-10-02 | 同一指纹，修改于 2026-10-03 21:45 | 同一指纹，2026-10-03 21:45 |
| knowledge | `8C:B0:C1:1E…B3:8F`，到期 2031-10-02 | 同一指纹，2026-10-03 23:19 | 同一指纹，2026-10-03 23:19 |

三处一致，文件都是 10-03 建的，**今天没有生成新证书**——`tls-identity.yaml` 的生成步骤带 `creates:`，文件在就不会动。上一份回执里「主备都缺、已新生成」是误判：多半是没 sudo 时 `stat` 读不到被当成「不存在」。请在 DNS 回执里更正这一句；顺手 `sudo ls -la --time-style=full-iso` 两个 `tls/` 目录，看有没有今天留下的 `server.csr`/`extensions.cnf` 之类的中间文件，有就记下来（不删）。info、knowledge 解冻。以后读不到私有目录时写「读不到」，不要写「缺失」。

## 2026-10-09 · 网页：「我的电脑」并进「设置」（所有者定，第一期）

托盘管本机（目录、联网、允许、状态），网页这一页管托盘做不到的事（首次下载、领令牌、电脑丢了时吊销、在网页上看在线）。它装好后很少用，不值得占侧栏大入口：

- 侧栏去掉「我的电脑」一项，只留一个在线小点（绿/灰），点了进「设置 → 我的电脑」。
- 「设置」里加「我的电脑」一节，现有接入页的内容整体搬进去（五步引导、下载、领令牌与沙箱、在线机器列表）。
- 首页首次卡片、工作/专家/新建项目缺电脑时的「接入电脑」按钮，全部跳到这一节（用锚点或子路由）。
- 侧栏上方的「工作区」不动。
- 预览样例与测试跟着改；Node 24 跑。

**时机：** 等 Cursor 把卡 35 跑完、回执推回、我审完之后再动网页，不要和正在进行的发布混在一起。另：多台电脑同时在线记为第二期（账 63）。

## 2026-10-09 · 卡 35 回执（Cursor `agent-release-hosting-cursor.20261009-1540.md`）：A/B/C 全过，已打 `release-20261009-1`

- A：只构建了 investment 后端（`4cf3a939…`，源 `a01db6f`）与网页（`15be7010…`，源 `2095c049`），检查全过；投资长期服务顺带上了 `ndots: 2`（Job 没有），可以接受。
- B：私有桶上传、读回、两个反向拒绝、同名再传保留原版本、匿名 403、reader/writer 只有各自一个权限，全部实测。
- C：下载开启；未登录 401、登录后 HEAD/完整下载/206/416/If-Range 都对，下载 ZIP 摘要一致。72/72 Kustomization Ready。
- tag `release-20261009-1` 打在晋级提交 `87aadc26`；现网 Flux revision `f59286af` 在历史里（这次没被改写）。
- 仍待所有者：浏览器「接入电脑 → 下载 → 安装 → 领令牌 → 在线」真人闭环；GUI 允许、重启自启、UAC、干净 Windows 照旧待验。

**下一步（luna）：** 上一节「我的电脑」并进「设置」可以开始了。卡 36 范围缩小为 info、knowledge、tpl、casdoor 的 `ndots`，等网页这轮一起或之后再写，不急。

## 2026-10-09 · 所有者真人验收：链路通了，安装体验不合格——下一轮做「安装体验改造」（所有者同意方向）

**结果：** 所有者在自己的 Windows 上从网页下载 → 校验 → 安装 → 换代理令牌 → `init --token-prompt` → 托盘勾桌面 → 后台启动，**连上会合点**，网页里新工作真的列出了 `C:\Users\zymun\Desktop` 的内容。下载未被 SmartScreen/智能应用控制拦（注意：是在 PowerShell 里 `Expand-Archive` 后运行的，不是双击）。

**真人撞到的问题（都要修）：**

| # | 现象 | 改法 |
| --- | --- | --- |
| 1 | 连不上，只有 `relay connection failed` | 真实原因是 `UNABLE_TO_VERIFY_LEAF_SIGNATURE`：平台自签 CA（`CN=SunMoon Registry Local CA`，指纹 `31AB3C44…A92B`）不在 Node 内置库，也不在 Windows 库。`relayClient.ts` 的 `ws.on("error", () => …)` 把错误整个吞了。**把错误码与一句人话写进日志、`status.lastError` 和托盘**（不带令牌） |
| 2 | 导入 CA 进「当前用户\受信任根」后，仍要手设 `NODE_OPTIONS=--use-system-ca` 才连上；托盘、自启、新窗口启动都不会带 | 包内所有入口（cmd、托盘、登录任务、wscript）**默认用 `--use-system-ca`** |
| 3 | 用户不知道要导入开发 CA | 开发站点：随包或接入页提供 CA，安装时显示指纹、经用户确认导入「当前用户」根（不需管理员）。正式站点用公共证书，不出现这一步——做成按站点配置，不写死 |
| 4 | 每次进 `%LOCALAPPDATA%\Programs\sunmoon-agent` 敲命令 | 开始菜单快捷方式；装完自动起托盘与后台；托盘是主入口 |
| 5 | 网页显示的代理令牌到期仍是 2027-01-05（旧身份按 90 天签的） | 换令牌后核对 30 天是否生效（状态接口回的 `agent_token_expires_at`），报告里写清 |

**下一轮：安装体验改造（与「我的电脑并进设置」合成一轮，改的是同一个接入页）。先写一页方案交审，不写代码。** 目标体验：

> 网页「下载」→ 解压后**双击「安装」** → 自动弹出设置窗口 → 点「连接我的账号」，显示短码并打开浏览器确认页，用户点「允许」，令牌自动到本机 → 选文件夹 → 完成；默认开机自启（可关）。全程不碰 PowerShell、不复制令牌。

方案要写清：

1. **先实测（决定后面怎么做）：** 从浏览器真实下载的 ZIP（带「来自网络」标记），用资源管理器解压后**双击**安装入口，在智能应用控制开着的机器上，SmartScreen/智能应用控制/执行策略各会怎样；`.cmd`、`.ps1`、`.vbs`、`.lnk` 指向签名 `node.exe` 等几种入口各试一次。结果决定是否要重提「第一期买代码签名证书」。不得关应用控制或改执行策略来过。
2. **浏览器确认配对（原第二期，提前）：** 代理生成一次性短码与配对请求 → 网页登录态下确认 → 后端把本人代理令牌只发给这条配对（一次性、短时、绑定所有者、可审计、可取消；令牌不进 URL/浏览器存储）。复用现有签发与 30 天、轮换逻辑，不另建令牌体系；网页上的手动领令牌留作备用。
3. 安装器内置校验（ZIP/清单摘要），会核对的人仍可手工核。
4. 首次设置窗口：连接账号 → 选文件夹 → 自启开关 → 完成；出错用人话说明下一步。
5. 「我的电脑」并进「设置」那一节照前面定的做。
6. 跨仓范围（后端配对接口、网页确认页、代理）、验收办法（所有者从下载开始只用鼠标走完）、发布要分几张卡。

方案交来我先审，所有者定了再动手。

## 2026-10-09 · 安装体验改造方案（runtime `9d47f7d`）：接受，补四点后按四张卡推进

方案方向、范围、四张卡的顺序都对；「不绕过系统策略」「不盲目信任包内 CA」「手动领令牌留作备用」三条底线好。补四点：

1. **配对的防骗：** 这类「设备码」流程的典型风险是别人把他机器上的码发给用户、骗用户点允许，令牌就到了别人机器上。确认页必须显示：待连接机器的名字、系统、发起时间、来源 IP，以及醒目的一句「只在这个码此刻显示在你自己电脑上时才点允许」；码 5 分钟过期、只能确认一次；确认后托盘与网页都写一条「某机器已于某时连接」。用户在网页上**输入**电脑上显示的码（而不是网页给码让电脑填），才算确认。
2. **配对会换身份：** 每次配对都发新令牌、吊销旧的，云端沙箱跟着滚动。确认页一并说明「旧电脑会断开、沙箱会重启几十秒」。
3. **实验卡里补核一件事：** 换令牌后状态接口回的 `agent_token_expires_at` 是否已是 30 天（所有者那边网页显示的还是 2027-01-05，是旧身份的 90 天，换完要看到 11 月上旬）。
4. **实验用真浏览器下载：** 带网络标记的 ZIP 请所有者用 Edge 下载一次（不要手工造 `Zone.Identifier` 冒充）；之后的解压、双击矩阵你来做并记录。

另外，所有者现在这台装的是 0.2.1，证书靠当时那个 PowerShell 窗口的环境变量，**重启后不会自己连上**。第 3 张卡（代理改造）里的「所有入口默认系统证书库 + 错误人话」先做、先出包，不必等配对全部做完，让所有者这台尽早能稳定用。

**所有者确认后**按「实验卡 → 配对后端卡 → 网页与代理卡 → 发行验收卡」推进，每张做完停下交审；发布照旧交 Cursor。

## 2026-10-09 · 改由远程定设计：安装与首次接入以 SDD `0012-agent-onboarding.md` 为准

所有者定：设计由远程（Fable）来定，luna 按设计实现。你上一版方案的方向保留，具体做法以
`tree-build/SDD/modules/0012-agent-onboarding.md` 为准（与你方案不同的主要三处：开发 CA 随包、只给代理自己信任，不导入 Windows 证书库；连接码由用户在网页**输入**；接入电脑不要求先登记模型 key / 先有沙箱）。

**规矩：** 按卡 A → B/C/D → E 做，每张做完停下交审；实现中发现设计行不通，停下写证据交我改设计，不要自己改方案或另起做法。只本地提交；发布交 Cursor；不碰集群。

**现在做卡 A（实验）。** 需要所有者用 Edge 下载一次现网安装包，你在开工时告诉他。
