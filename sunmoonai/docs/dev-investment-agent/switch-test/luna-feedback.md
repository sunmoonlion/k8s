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
