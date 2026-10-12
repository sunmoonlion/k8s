# 远程审读与交接记录（2026-10-12 起）

> 只追加，不改旧条。2026-10-07 到 10-12 中午的旧记录（luna 工位时期的 `luna-feedback.md`）已删除，只在 git 历史里（`git log --all -- '*/switch-test/luna-feedback.md'`）；里面写的分工已不是现行约定。

## 2026-10-12 · 现行分工（所有者定，取代以前一切「luna 工位」说法）

| 谁 | 在哪 | 只做什么 |
| --- | --- | --- |
| 远程助手（Fable） | 远程机 `~/worktrees/fable/*`，分支 `fable` | 写代码、文档、设计；写 `inbox/cursor/` 的发布卡与 `inbox/astra/` 的任务页；审读本地提交 |
| Cursor（本地） | 本地机 `~/worktrees/fable/k8s`，分支 `fable` | **只跑 `inbox/cursor/` 里的卡**，回执写 `k8s/sunmoonai/scripts/results/`，本地提交；不从账本领活，不改产品代码 |
| astra（本地） | 本地机 `~/worktrees/fable/runtime`，分支 `fable` | **只改 `runtime/agent`**，而且只按 `inbox/astra/` 里的 `astra-NNN.md` 做；箱子空就没有任务；不碰别的仓 |
| 所有者 | 两边 | `human-local.sh` 拉、`human-remote.sh` 推（都不带 `WS=`，默认 fable）；传话；真机验收；决定合并 |

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

**六仓对齐（15:20）**：按 10-11 夜的约定，审读过后把 luna 与 fable 对齐——runtime fable 快进到 `5ccca65`；其余九个仓（三个 app 父仓、三个后端、投资后端/网页/父仓）各做一次「树取 fable、两个父」的合并提交推到 luna 与 fable，内容一行不变，只是把 luna 上多出的提交（U2 摘抄、设置页第 1 步的 `-s ours`、以及 15:10 同步脚本自动提交的 `592fe03`——它把投资父仓指针指回了被弃用的 `7afe64b`/`ea8d6d3`）收进历史。k8s 本来就相同。现在十一个仓 luna == fable：runtime `5ccca65`、投资父仓 `0bb0b72`、后端 `3a70280`（树 = `30a89d2`）、网页 `80d6833`（树 = `a972023`）、info `dc02a53`、knowledge `f79b43b`、tpl `631316b`、k8s `6f488ddf`。

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

