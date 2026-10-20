# 远程审读与交接记录（2026-10-12 起）

> 只追加，不改旧条。2026-10-07 到 10-12 中午的旧记录（luna 工位时期的 `luna-feedback.md`）已删除，只在 git 历史里（`git log --all -- '*/switch-test/luna-feedback.md'`）；里面写的分工已不是现行约定。

## 2026-10-12 · 现行分工（所有者定，取代以前一切「luna 工位」说法）

| 谁 | 在哪 | 只做什么 |
| --- | --- | --- |
| 远程助手（Fable） | 远程机 `~/worktrees/fable/*`，分支 `fable` | 写代码、文档、设计；写 `inbox/cursor/` 的发布卡与 `inbox/astra/` 的任务页；审读本地提交 |
| Cursor（本地） | 本地机 `~/worktrees/fable/k8s`，分支 `fable` | **只跑 `inbox/cursor/` 里的卡**，回执写 `k8s/scripts/results/`，本地提交；不从账本领活，不改产品代码 |
| astra（本地） | 本地机 `~/worktrees/fable/runtime`，分支 `fable` | **只改 `runtime/agent`**，而且只按 `inbox/astra/` 里的 `astra-NNN.md` 做；箱子空就没有任务；不碰别的仓 |
| 所有者 | 两边 | `WS=<工位> human-local.sh` 拉、`WS=<工位> human-remote.sh` 推（工位必须给，不猜）；传话；真机验收；决定合并 |

**五个工位地位一样**（`fable`、`cursor`、`kimi`、`luna`、`qwen`；所有者 2026-10-12 定「luna 没必要冻结，它的地位和其它一样」）。2026-10-12 15:20 起六个仓在五个分支上对齐到同一提交；远程每次推都推五个分支，所有者 `sync-five-repos.sh … -all` 一次同步全部。本地助手各用自己名字的工位。

## 2026-10-12 · astra 0.3.1 审读（runtime luna `5ccca65`，四个提交）：通过；六仓已对齐，工位切到 fable，发布卡 41

| 条 | 做出来的样子 | 核到 | 判定 |
| --- | --- | --- | --- |
| 1 乱码根治（账 88） | `windowsEncoding.ts` 纯函数：PowerShell/pwsh 的 `-Command`/`-c` 脚本前加 Codex 同一句前缀（已带不重复），cmd 的 `/c`、`/d /c`、`/c /d` 命令前加 `chcp 65001>nul & `，其它可执行不动；env 补 `PYTHONUTF8=1`、`PYTHONIOENCODING=utf-8`（大小写不敏感地不覆盖）。`windowsBridge.ts` 在 `windowsDecision` 判完原 argv 之后、转发前才改写 | 改写点在判定之后（看了 diff 的位置）；`process/start` 真实帧字段里确有 `env`；两个新 env 键不在保留键里；表驱动单测 9 组 + 桥转发 1 组 | 通过 |
| 2 配对页收尾（账 89） | 「去网站允许」、复制连接码（点码也复制，失败退到选中，「已复制」两秒）、三处文案、托盘状态窗加一句；CSP 没动 | 页面合同测试 6 项 | 通过 |
| 3 本机探测小口（账 92） | `presence.ts`：只绑 `127.0.0.1`，47811 占则 47812，都占只记日志；`Origin` 恰等于 `site.json` 的 `web_origin`（https、无 userinfo、`url.origin === value`）否则 403 无 CORS 头；只 `/presence`（带查询串也 404）、GET 与 GET 预检（`Access-Control-Allow-Private-Network: true`，不发 credentials）；四个键；同秒 >20 回 429，日志只记次数；只在常驻进程里开，退出时关 | 与 astra-031 合同逐项对；gitops 校验 `web_origin` 必须是 `^https://[a-z0-9.-]+:30443$`，与小口的严格比对一致；单测 6 项含两口都占、限速、错来源 | 通过 |
| 顺手 | `siteTrust.test` 子进程退出 9 时 skip | 本机 Node 24.21 上该项已 skip | 通过 |
| 版本三处 | `package.json`、`cli.ts`、`windows-x64.json` 都 0.3.1 | — | 通过 |

**本机重跑**（scratch worktree，`pnpm install --frozen-lockfile`）：`tsc` 0；vitest 23 文件 244 过 / 34 跳（第一遍 6 个 `cli.test` 失败是没编译 `dist/`，`tsc -p .` 之后全过）；发行包三套 48 项 46 过 2 跳。

**没验的**（astra 自己写明，它在 Linux 壳里做的；放到发布后由所有者亲自验）：真机第一条命令中文；本机页按钮与复制；浏览器 `fetch` 回环与 `curl` 403；干净候选组包（Windows 物料不在它手边，发布卡里由 Cursor 组）。

**两点备忘，不挡发布**：① Chrome 新版正在把「私有网络访问」换成「本地网络访问」权限提示，网页探测那半（远程做）要用 `fetch(url, { targetAddressSpace: 'loopback' })` 并把被拒当「探不到」；② 小口对无 `Origin` 的本机请求一律 403，所以 `curl` 看到 403 是对的，不是坏了。

**六仓对齐（15:20）**：按 10-11 夜的约定，审读过后把 luna 与 fable 对齐——runtime fable 快进到 `5ccca65`；其余九个仓（三个 app 父仓、三个后端、投资后端/网页/父仓）各做一次「树取 fable、两个父」的合并提交推到 luna 与 fable，内容一行不变，只是把 luna 上多出的提交（U2 摘抄、设置页第 1 步的 `-s ours`、以及 15:10 同步脚本自动提交的 `592fe03`——它把投资父仓指针指回了被弃用的 `7afe64b`/`ea8d6d3`）收进历史。k8s 本来就相同。现在十一个仓 luna == fable：runtime `5ccca65`、投资父仓 `0bb0b72`、后端 `3a70280`（树 = `30a89d2`）、网页 `80d6833`（树 = `a972023`）、knowfeed `dc02a53`、knowbase `f79b43b`、tpl `631316b`、k8s `6f488ddf`。

**工位切换**：从现在起所有者两个同步脚本不带 `WS=`（默认就是 fable）；Cursor 在 `~/worktrees/fable/k8s` 跑卡；astra 在 runtime 的 fable 分支上做；五个工位一样，每次推五个分支。发布卡 41（应用批 3 + 代理 0.3.1）已写在 inbox，按 fable 工作树写的。

## 2026-10-12 · 两个本地助手各一个收件箱（所有者定「给它们各自的 inbox，否则容易乱」）

`inbox/cursor/`（发布与测试卡）、`inbox/astra/`（代理任务页），各看各的；`done/` 仍共用。`human-local.sh` 分别列出两箱；卡 41 已在 `inbox/cursor/`，`inbox/astra/` 现在是空的。

补：所有者同日定「一次性为各工位都建上自己的 inbox」——再加 `inbox/kimi/`、`inbox/qwen/`（现在都空）；luna 照样设（`inbox/luna/`）；fable 也设（`inbox/fable/`，所有者定「方便以后在其它工位向 fable 派活」），远程读到就做。`human-local.sh` 改成自动列出 `inbox/` 下所有箱子。

## 2026-10-12 · 卡 41 回执核对：通过，归档；现网 = 应用批 3 + 代理 0.3.1

| 部分 | 核到 | 判定 |
| --- | --- | --- |
| 应用批 3 | 五处钉 = 父仓 `b27ed92e`、后端 `3a702802`、网页 `80d68331`；`v7` / `'20261012_0018'`；迁移 Job `investment-migrate-f47ea47f23f7-v7`；后端镜像 `sha256:f47ea47f…`、网页 `sha256:9f97bfbe…`；`application-check` 0；16:28 上线 | 通过 |
| 代理 0.3.1 | zip `sunmoon-agent-0.3.1-5ccca65-windows-x64.zip` sha `8542e315…`、manifest `ce7a0ded…`、102 文件、size 175320303；windows-candidate pass；upload `readback_verified`；config 六项与仓里一致；晋级 digest `sha256:594583a4…`；后端镜像未换；`application-check` 0；16:38 上线 | 通过 |
| 仓 | 无私钥；回执里的提交号（`4602b53d`、`7f908cce` 等）是回传时 rebase 前的，fable 上现在是 `2f7d2877`、`34198129`、`fe16b8ff`、`a237aa74`；Flux 按 OCI 摘要取，不受影响 | 通过 |

Cursor 顺手记了一条：Windows 侧组包首次 tsc 缺 `smol-toml`，从 0.3.0 的完整 `node_modules` 复制后通过——以后组包前提里要写「依赖目录须完整（含 smol-toml）」。

**所有者真机验**（上线后）：① 中文目录里第一条 `Get-ChildItem` 不乱码；② 托盘「重新连接账号」开出的页有「去网站允许」和「复制连接码」；③ 投资网页控制台 `fetch('http://127.0.0.1:47811/presence')` 四个键，`curl` 无 Origin 403；④ 设置页三栏、项目页「专家交回」、时间线里本机上限那一行（要触发一次本机权限弹窗才有）；⑤ 之前没试完的：侧边栏删除、审批四个按钮、专家排队、长期记忆。

## 2026-10-12 · 0.3.1 真机：托盘「重新连接账号」起不来接入页 → 0.3.2 修了；卡 42

所有者升 0.3.1 后：装完提示「请在自动打开的浏览器页面继续」但没开页（已接入的电脑装完本来只开托盘，那句话误导）；托盘「重新连接账号」报「本机接入页未打开」。astra 只读排查定位：`desktop.ps1` 的 `New-AgentProcess` 在 `Detached` 分支关掉了 stdout 重定向却留着 `StandardOutputEncoding`，.NET `Process.Start` 抛异常；它在内存里试改验证过（隐藏启动 `--version` 退出 0），没动源码，交远程。远程改一行、安装提示改文案、版本 0.3.2、发行包测试加回归断言（runtime fable `ef6f33f`；vitest 243 过、tsc 过、发行包 46/2）。**这个毛病 0.3.0 起就有**（托盘重连是 0.3.0 加的，当时真机只验了安装器那条路）。

顺带记一笔：astra 这次会话在 Codex 的 Default 沙箱里，WSL 到 Windows 的 vsock 通道被隔开，起不了 `powershell.exe`；之前能做真机实测是会话开着 Full Access。已告诉所有者在 `/permissions` 里切，或用 `!` 前缀跑命令。

卡 42（`inbox/cursor/2026-10-12-42-web-batch4-agent-032.md`）：网页批 4（账 94 + 95 ②③，网页 `8ccc52c`，后端不变、无迁移）+ 代理 0.3.2。临时绕法：PowerShell 里 `& "$env:LOCALAPPDATA\Programs\sunmoon-agent\sunmoon-agent.cmd" pair --page`。

## 2026-10-12 · astra 0.4.0 服务流段 1 审读（runtime fable `9d96980`）：通过，收作「服务流代理侧」；接着按乙案做回环口

astra 在我改乙案之前（它手里是 512 KiB 那版合同）把**服务流**的段 1 做完了：`service.ts`（JSON-RPC 只开 `service/hello` 与三个只读 `fs/*`，令牌桶 50/s、4 并发，白名单 + 配置目录 / codex-home / `auth.json` / `.sandbox-secrets` 排除，Linux 路径逐级查符号链接与打开后身份），`relayClient.ts` 按 `open.kind=service` 分流（服务流独立计数、上限 2、控制断开即关），`helper.mjs` 加私有投影 `service/getMetadata|readDirectory|readFile`（复用目录钉住与身份检查，没有写方法），`windowsRuntime.ts` 管道 `setEncoding("utf8")` 修中文目录名跨块损坏。Linux 258 过、发行包 46/2；**Windows 真机 + 真实 `relay.py` 配对**：中文文件读取、5 MiB 十段重组、2001 项中文目录截断、junction / 硬链接 / 别名 / `.codex` / 代理 home 全拒、无令牌 reject。沙箱流与 `filter.ts`、`windowsPolicy.ts`、`windowsBridge.ts` 逐字节未动。

| 看了 | 看到 | 判定 |
| --- | --- | --- |
| 只读、白名单、受保护目录、链接逃逸 | Windows 走现有沙箱内 helper，Linux 路径只为单测 | 过 |
| 限额 | 512 KiB 原文、目录按条数与字节双重截断、回包 > 1 MiB 直接断流而不是硬发 | 过 |
| 流管理 | 第 3 条服务流发 hello 后 1008 关；控制通道断开关掉全部服务流 | 过 |
| 日志 | 只有方法名与错误码 | 过 |

**这段活没白做**：乙案（0022 重写）里服务流留给云端自用（成稿硬检查、以后 `采集/` 写回），这正是它。收下，记为 0022 段 4 的代理侧已成。接下来 astra 按重写后的 `astra-032.md` 做乙案：段 1 回环口四个只读接口 + 验票，段 2 设置读写。它那条 17:38 的合同阻塞回执也对：当时 1 MiB 原文确实超帧。

## 2026-10-12 · astra 0.4.0 乙案段 1 审读（runtime fable `5403c06`）：通过，进段 2

| 看了 | 看到 | 判定 |
| --- | --- | --- |
| `ticket.ts` | 只认 `Bearer` 三段 JWT；`alg` 只许 ES256、`kid` 必填、拒 `crit`；`aud=local-agent`、`sub` 等于自己的 `userId`、`iss` 非空、`exp` 未过、`iat` 不超前 30 秒、票期 ≤ 600 秒、签名 64 字节；JWKS 只从固定站点 `/api/workbench/token-keys` 取（不认票里的 `jku`），≤ 64 KiB、≤ 64 把钥、只收 P-256 公钥、缓存 10 分钟、并发合并；取不到 503 `keys_unavailable`。Node 自带 crypto，没加依赖 | 过。一处小毛病：遇到没见过的 `kid` 直接 401，不重取 JWKS——工作台换钥后最长 10 分钟内票都会被拒。段 2 顺手改：未知 `kid` 且上次取钥超过 60 秒就重取一次 |
| `localApi.ts` | `/presence` 与 `/local/v1/*` 同一个监听；Origin 不对 403 无 CORS 头；同秒 > 20 回 429；预检三个头齐、不发 credentials；业务路径先验票再路由；`fs/file` 回原始字节 + `X-File-Size/Mtime/Eof` 并 `Access-Control-Expose-Headers`（我网页那头正好靠这三个头，它想到了）；错误固定 JSON | 过 |
| `localFiles.ts` | 白名单 + 配置目录 / codex-home / `auth.json` / `.sandbox-secrets` 排除；Windows 经现有沙箱助手（`local/readFile` 投影，1 MiB），Linux 路径逐级查链接与打开后身份；> 64 MiB 413；目录 2000 项截断 | 过 |
| 不动的 | `service.ts` 等已过审文件与三个安全文件逐字节相同；`presence.ts` 只剩转发 | 过 |
| 测试 | Linux 274 过、发行包 46/2；Windows 原生 + **隔离 Edge 在真实站点 Origin 下带自签票跨源读到本机文件**，缺票 401、缺 Origin 403、错 Origin 无 CORS、链接 / 别名 / 受保护目录全拒、5 MiB 五段重组、2001 项中文目录截断 | 过。没验的它写明：现网发票→本机验、真实网页文件树（等发布）、Chrome、elevated |

顺带：它在真机上发现 47811 被 Cursor.exe 占、47812 被另一个 node.exe 占（没动它们，改随机口测）。**这是个真问题**：Cursor 编辑器会占 47811？要查清是巧合还是 Cursor 固定用这个口；若固定，正式版的端口要换或多备几个。记账 95 ⑤，所有者机器上看一眼 `netstat -ano | findstr 4781`。

**段 2 开工**：`GET/PUT /local/v1/settings`、`libraryDir`、放宽确认、重启重报，按 032。

## 2026-10-12 · astra 0.4.0 乙案段 2 审读（runtime fable `f85fe31`）：通过；代理侧 0.4.0 齐了，等下次发布联调

| 看了 | 看到 | 判定 |
| --- | --- | --- |
| `localSettings.ts` | PUT 只收五个字段；校验与托盘共用 `validatePreferences`（目录存在、≤ 32、选中 ⊆ 候选、无别名、沙箱只两档、受保护目录）；放宽判定与 0022 第四节逐条对得上（加目录 / 抬沙箱 / 开网 / 设或换知识库目录 / 开自启），合成一窗、随机码 60 秒、拒绝 / 超时 / 断线 409 `local_denied`，第二个写 409 `busy`；确认后**再校验一次并比对文件没被本地改过**；自启失败回滚；临时文件原子替换、0600；先回包再由独立生命周期子进程重启 | 过 |
| `preferences.ts` / `resident.ts` | 托盘 `settings set` 与回环口同一套校验；加 `restart-resident` 子命令走现有 stop-request + startResident | 过 |
| `config.ts` / `cli.ts` | `libraryDir` 可空、校验是存在的本地目录；启动时钉住它、只进回环文件助手的读集合，**不进** exec-server / relay 的 `roots`；`info` 带 `libraryDir` 与 `lastSettingsChange` | 过 |
| `ticket.ts` | 未知 `kid` 且距上次取钥 > 60 秒重取一次，失败也计入节流 | 过 |
| `localApi.ts` | 五个候选口；`settings` 路由 GET/PUT、PUT 只认 JSON、正文 ≤ 64 KiB；请求断开即取消等待中的确认 | 过 |
| `desktop.ps1` | 设置窗加「本地知识库目录」只读框 + 选目录 / 清空 | 过 |
| 测试 | Linux 308 过、发行包 46/2；Windows 真机：五口落到 47813、设置投影、知识库只读（控制通道写知识库被拒）、删目录 / 清知识库不弹窗直接重启、**所有者亲手在确认窗允许一次、拒绝一次**（拒绝后 `config.json` 字节相同、PID 相同）、换钥 61 秒后重取成功；Windows 发行测试 48/48。探针自己的两处夹具错误它都写明并修了，没有拿它冒充产品行为 | 过 |

没验的（它写明）：现网发票→本机验、网页「我的电脑」真实联调、Chrome、elevated、干净机器升级——都等发布。

**代理侧 0.4.0 到此齐了**（服务流段 1 + 回环口段 1、2 + 0.3.2 托盘修复），runtime fable `f85fe31`。按攒批规矩不单独发；下次发布卡 = 网页批 4 + 0.4.0。astra 眼下没有新任务页。

## 2026-10-13 · 远程：87 的网页与后端半边做完，整条等发布联调

网页 `f279a67`：我的电脑可编辑（经回环口）、本地知识库页、侧边栏「就是这台 / 还没接入」；后端：成稿硬检查经服务流问代理。下次发布 = 网页批 4（含这些）+ 后端（票端点 + 硬检查）+ 代理 0.4.0。astra 在发布后做真机联调：网页文件树、我的电脑改设置弹窗、本地知识库页、侧边栏提示。

## 2026-10-13 · 专家「财务分析与预测」占位（账 96）

所有者要在下次发布里先看到这位专家。远程加了专家包的「筹备中」一档：`FIN_FORECAST` 进清单（首页、专家首页、请专家页三处都显示，带「筹备中」标和「数据和方法正在接入……」一句），请不了（后端 409 `expert_not_ready`，页面上按钮也不可选）。五步按样子写好（定范围 → 取数 → 分析 → 预测 → 成稿），六问答了，交回物字段与底稿块都齐，能过专家包的全部规矩测试。Qwen 做真包时填方法、工具与数据，`status` 改 `ready`。预览样例重录（含这位专家）。

## 2026-10-13 · 卡 42 回执核对：通过，归档；现网 = 应用批 4 + 代理 0.4.0（里程碑）

| 部分 | 核到 | 判定 |
| --- | --- | --- |
| 应用批 4 | 五处钉 = 父仓 `99e92f56`、后端 `e73ffa5e`、网页 `27f6b9b3`；config 未动（`v7` / `'20261012_0018'`，迁移 Job 名不变）；后端镜像 `sha256:6a189617…`、网页 `sha256:668f539e…`；`application-check` 0；09:07 上线 | 通过 |
| 代理 0.4.0 | zip `sunmoon-agent-0.4.0-f85fe31-windows-x64.zip` sha `54ee3666…`、manifest `bf3b43a5…`、108 文件、size 175334353；candidate pass；upload `readback_verified`；config 六项与仓里一致；晋级 digest `sha256:1e8a3032…` / revision `f4919b79`；后端镜像未换；`application-check` 0；09:20 上线 | 通过 |
| 仓 | 无私钥；提交 `b5baa3e0`、`768d43c3`、`f4919b79`、`1822a8fb`、回执 `250fc81b` 都在 fable 上 | 通过 |

**会合点镜像没发**（本卡写明）：成稿硬检查在现网自动退成软检查；另开卡时一起发 `/service`。

**所有者真机验**（先升到 0.4.0：网页「我的电脑」复制安装命令重装）：① 托盘「重新连接账号」能开出接入页；② 工作对话右边栏「文件」看到白名单目录树、点开中文文件名的 Markdown；③ 设置 → 我的电脑下面「这台电脑上的设置」是表单，勾一个目录保存 → 电脑上弹确认窗 → 允许后托盘设置里有它；④ 侧边栏底部「本地知识库」页（先在我的电脑里设目录）；⑤ 侧边栏电脑行「就是这台」；⑥ 请专家页「财务分析与预测 · 筹备中」点不动；⑦ 工作页顶上没有状态带、输入框下有花费小字。astra 之后做真机联调回执。

## 2026-10-13 · 卡 42 真机第一条就卡住：CSP 拦了回环口，热修卡 43

所有者在工作对话点「文件」得到「这台电脑上没有在运行的代理」；控制台原文：`Fetch API cannot load http://127.0.0.1:47811/presence. Refused to connect because it violates the document's Content Security Policy`（`connect-src 'self'`）。是远程漏的：设计写了「浏览器直连回环口」，网页的 CSP 没跟着放行；astra 真机测的是站点的 JWKS 页面不是我们的应用页，所以它那边通了。改 `lib/security/content-security-policy.ts` 的 `connect-src` 加五个回环口（与 `LOCAL_PORTS` 同一张表），网页 `309e73d`，只换网页镜像，卡 43。

## 2026-10-13 · 卡 43 回执核对：通过，归档（10:21 上线）

只换网页镜像（`sha256:a5bfbb79…` / `309e73d5`），后端锁「已是这一份」；钉 = 父仓 `102054b4`、网页 `309e73d5`、后端 `e73ffa5e`；晋级 digest `sha256:cc073bda…` / `191a4332`；`application-check` 0。所有者刷新网页点右边栏「文件」即可验。


## 2026-10-13 · Opus 第 1 段远程部分复查：通过；qwen 工位已并上 origin/qwen

| 看了什么 | 核到 | 判定 |
| --- | --- | --- |
| knowbase-backend qwen `94a3a72` | 只加四个文件（`datasets/olist/olist.yml` 401 行、`scripts/build_olist_dataset.py` 323 行、`tests/test_olist_dataset.py` 387 行、`docs/dataset-registry.md` 一节）；`app/app/` 运行代码一行没改 | 通过 |
| 生成脚本 | 下载先写 `.part` 再核 sha256，不符就删不覆盖；缓存不符停下；列名与定义逐个比对；时间列统一 `%Y-%m-%d %H:%M:%S`；`.part` 写完 `os.replace`；写完按服务自己的 `read_description`+`build_manifest`+`WrenPlanner` 自检；`data_version` 把定义文件 sha256 算进去（改定义版本就变，不撞 409） | 通过 |
| 测试 | 远程机重跑 `tests/test_olist_dataset.py`：8 passed；Opus 回执里全量 807 passed / 174 skipped，ruff 只剩原有 1 条 | 通过 |
| 回执 `results/fin-forecast-1-remote-20261013.md` | 真实数据两次同版本 `olist-ecommerce-5f4af057bf031216`；经 `KnowledgeMcp.handle` 11 项全过，按月 GMV 20 行与直读 SQLite 相同；没做的写明（KIND 链归 Qwen、174 个跳过没核原因、生产样例桶未定） | 通过 |
| k8s qwen | Opus 的五个提交落后 origin/qwen 四个（我早先快进的）；`merge-tree` 无冲突，我在 qwen 工位做了 `git merge origin/qwen`（`8866ae44`），现在能快进推送 | 已处理 |
| knowbase-app qwen `f7e5aba` / knowbase-backend qwen | 都只比 origin 多一个提交，能快进 | 通过 |

小瑕疵，不挡：`qwen-001.md` 与回执里链到 `inbox/opus/opus-001.md`，那页已按所有者意思删掉，链接会断；历史在 git 里。

下一步：所有者 `from-remote qwen` 推远程 qwen、拉到本地，对本地 Qwen 说「请看 inbox/qwen」；Qwen 做 KIND 联调链一截（样例桶、`run.sh sample olist`、`driver verify-sample olist`），回执交 Opus。

## 2026-10-18 · 所有者让我审 Opus 10-13 至 10-18 的全部工作：意见 16 条

写在 `tree-build/review-2026-10-18-fable.md`（2026-10-19 已删，原文见 git 历史；取舍见 `decisions.md`「采纳远程 Fable 10-18 审读」）。要改的三条：内部接口经公网 Ingress 可达（只靠令牌）；有人值守里运营能答开步前提问并被记成用户预设（C-L1）；测试结果里看不到验收为什么没过、平台故障记成用例没过（qwen-005 第 10 行就是这样卡住的）。其余是角色绕过权限、表格列重名、knowmart 公开开关与默认类目、三处清单校验、百分号读法、连接复用、清单上限，以及文档对不上现状的几处。审的是源码，不是回执；采不采纳由 Opus 定。
