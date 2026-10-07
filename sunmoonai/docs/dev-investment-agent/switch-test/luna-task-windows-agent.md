# luna 的开发任务：Windows 本地代理（2026-10-07 起）

> 所有者 2026-10-07 定：Windows 版本地代理交给本地助手 luna 开发（远程额度有限，而且代理要在 Windows 上装和试，只有本地机能做）。远程写这份交接、审读、合并，不写代理代码。
> 设计先读：`k8s/sunmoonai/docs/dev-investment-agent/tree-build/SDD/modules/0005-agent.md`（代理）、`0004-relay.md`（会合点协议）、`SDD/architecture/security.md`「本地上限」。现状读 `runtime/CHECKPOINT.md` 和 `runtime/agent/README.md`。
> 这是**开发**任务：允许写代码、脚本、文档。每一件做到「停点」就停下，写结果、本地提交，等所有者同步给远程看过再做下一件。

## 一、在哪做、怎么回

- 全在 `~/worktrees/luna/runtime`（`luna` 分支）里做。开工前所有者先把本地 luna 工位对齐到远程（2026-10-07 远程已把五个工位、各仓的 `luna` 分支全部对齐到 `fable`；本地按所有者的办法 realign）。
- **只动 `runtime` 仓。**四个应用仓、k8s 仓不动。要改别处（会合点、工作台后端、沙箱镜像、部署）就停下，把「要改什么、为什么」写进结果，由远程改。
- 只本地提交，不 fetch / pull / rebase / push；同步是所有者的事。所有者同步回远程只是为了让远程看代码，远程的意见直接在对话里给，不经同步。
- 做完、远程看过、所有者同意后，远程把 `luna` 合进 `fable`。
- 仓改名 `runtime` → `agent`（账 52）**不在这里做**，放到合并之后由远程和所有者一起改（改名会牵动同步脚本）。

## 二、已经定了的，不再讨论

| 事 | 定法 |
| --- | --- |
| 平台 | 只做 Windows 10/11。Linux 现有形态留给开发联调，不加东西；macOS 不做 |
| 代码签名 | 第一期不买证书，安装包不签名；装包说明里写清 SmartScreen 要点「更多信息 → 仍要运行」 |
| Codex 版本 | 钉 0.155.1，随包带原生 `codex.exe`（`node_modules/@openai/codex/vendor/<平台>/codex/codex.exe`），不用 npm 的 `.cmd` 垫片；代理与沙箱版本成对，会合点核对 |
| 协议 | 会合点协议 v1 不变：`agent/src/relayProtocol.ts`（hello 带 `codex`、`software`、`machine {name, roots, ceiling}`），令牌是工作台签发的 ES256 JWT（`D10`），过滤规则见 `agent/src/filter.ts`。要加字段先写进结果，远程改会合点与工作台 |
| 执行端的家 | `~/.sunmoon-agent/codex-home`，与用户的 `~/.codex` 隔离，不含凭据（`F-AGENT-10`）；Windows 上是 `%USERPROFILE%\.sunmoon-agent\codex-home` |
| 令牌怎么来 | 第一期仍是用户在网页「设置 → 本地代理」里拿到带令牌的 `init` 命令，粘到本机；浏览器登录流程第二期 |
| 本地上限 | 两层：OS 外沙箱 + 桥内协议过滤。Windows 的外沙箱能做到哪一层，由探针定（第三节 0） |

## 三、顺序与停点

### 0. 探针：无管理员权限的沙箱（半天）

2026-09-24 的探针（`runtime/probe/REPORT-2026-09-24-windows-exec-server.md`，脚本 `runtime/scripts/probe-windows-exec-server.ps1`）用的是 `windows.sandbox = "elevated"`，要管理员跑一次 `codex sandbox setup --elevated --current-user`。Codex 另有 `windows.sandbox = "unelevated"`（受限令牌，不要管理员；`codex sandbox setup` 只对 `--elevated` 存在；这个模式不能做「禁读」覆盖）。要答两问：

1. 普通账号、执行端 `config.toml` 写 `[windows] sandbox = "unelevated"`、不跑 setup：L2（写 `%USERPROFILE%` 外的目录）挡不挡得住，L3（写 cwd）成不成。
2. exec-server 进程本身能不能也包进受限令牌（Linux 上 bwrap 那一层的对等物）：试 `codex sandbox`（或 `codex debug sandbox`）把 `codex exec-server` 当被沙箱的命令起；起不来就记「做不到」，本地上限在 Windows 只剩协议过滤，写进结果让所有者认。

改 `probe-windows-exec-server.ps1` 加一个 `SANDBOX_MODE` 变量即可，不重写。**停点**：报告 `runtime/probe/REPORT-<日期>-windows-unelevated.md`，两问各一个 pass / fail / undecidable。

### 1. 代理在 Windows 上起得来（一到两天）

- `agent/src/execServer.ts`：Windows 上用包内 `codex.exe` 原生起 exec-server；回环端口动态选；`outerSandbox.ts` 在 Windows 上按探针结论走（有外沙箱就包，没有就记日志「只有协议过滤」并在 `status.json` 里标明）；进程树清理用 `taskkill /T`（或 Node 的 `tree-kill`）。
- 执行端家的 `config.toml` 由代理写：`[windows] sandbox = "elevated"`（做过 setup）或 `"unelevated"`；`init` 时探测哪一种可用。
- `init | roots | ceiling | start | status` 在 PowerShell 下能用；路径处理（`paths.ts`、`pathuri.ts`）对 Windows 路径（盘符、反斜杠、`file:///C:/…`）有测试。
- 过滤规则对 Windows 路径的判断（白名单根的前缀比较要不分大小写、规范化分隔符）有测试，用真实抓到的帧。
- 在 Windows 上 `pnpm typecheck && pnpm test` 全过；对着现网会合点（`wss://relay.sunmoonai.com:30471`，令牌从网页设置页拿）连上，网页「我的机器」里出现这台机器、在线。

**停点**：结果写 `runtime/scripts/results/windows-agent-1.<时间>.md`；`CHECKPOINT.md` 更新。

### 2. 共用部分（两到三天）

- `F-AGENT-10` 合并 MCP：从用户 `~/.codex/config.toml` 只取 `[mcp_servers]` 里 HTTP 型条目，列出来本机确认（第一期 CLI 确认），写进代理的 codex-home；别的一概不读。
- `F-AGENT-04` 抬高上限的本机确认：先做 CLI 交互（沙箱发来高于上限的请求 → 本机提示 → 只对当前会话放行 → 经会合点上报）；托盘里的弹窗放到第 3 步。
- `F-AGENT-05`：会合点 reject（版本不成对、令牌吊销）时给用户一句能看懂的话和下一步（更新 / 重新取令牌），不静默。
- 日志：`%LOCALAPPDATA%\sunmoon-agent\logs\`，轮转；令牌、key 永远不进日志。

**停点**：`windows-agent-2.<时间>.md`；测试全过。

### 3. 安装与常驻（三到五天）

- 打包：单目录或单文件程序（Node 运行时 + `dist/` + `codex.exe`），不要求用户装 Node。做法自选（`pkg`、Node SEA、或 Electron 只当壳），写清理由。
- 安装器：每用户安装（`%LOCALAPPDATA%\Programs\sunmoon-agent`），不签名；安装末尾可选一步 UAC 提权跑 `codex sandbox setup --elevated --current-user`（对代理的 codex-home），跳过则走 `unelevated`。
- 开机自启：计划任务（登录时、当前用户），可关。
- 托盘：状态（在线 / 离线 / 原因）、白名单目录勾选、上限确认弹窗、退出。能用就行，不求好看。
- 卸载：干净，保留 `~/.sunmoon-agent`（配置与令牌）可选删除。

**停点**：`windows-agent-3.<时间>.md`，附安装包的位置与大小；所有者在一台没装过 Node 的 Windows 上装一次试一次。

### 4. 第二期（不在这次范围，留缝）

自动更新（更新包从边缘下载、验签后替换、失败回滚）、浏览器登录取令牌、勾选上送知识服务（`F-AGENT-08`）、网络硬禁。

## 四、验收（远程按这个看）

| 编号 | 要看到 |
| --- | --- |
| `AT-WA-01` | 普通账号装上、起来、网页「我的机器」在线；没有管理员也能用（unelevated），有管理员则 elevated |
| `AT-WA-02` | 沙箱里让它写白名单外的目录：被拒（exec-server 侧 `PermissionDenied` 或桥内 `-32001`），文件没建 |
| `AT-WA-03` | `danger-full-access` 高于上限：桥内拒，上报可见 |
| `AT-WA-04` | 断网 20 秒再连：同一个 exec-server 进程，会话不丢；代理重启则上报会话丢失 |
| `AT-WA-05` | 令牌吊销（网页「换代理令牌」）：代理退出码 3，`status.json` 有原因，提示用户重新取令牌 |
| `AT-WA-06` | 关掉托盘界面代理仍在跑；重启电脑后自己起来 |
| `AT-WA-07` | 日志、`status.json`、安装包里没有令牌和 key |
| `AT-WA-08` | `pnpm test` 在 Windows 与 Linux 都过；Linux 现有联调脚本 `scripts/integration-minimal-pair.sh` 仍 pass |

## 五、规矩

- 不把令牌、key、口令写进代码、测试、日志、结果；结果里引用令牌一律打码。
- 新依赖要写为什么；不引入需要原生编译的依赖，除非说明在 Windows 上怎么装。
- 测试用真实抓到的帧和真实路径，不用猜的。
- 每个停点一份结果文件 + `CHECKPOINT.md`，所有者同步后远程在对话里给意见；意见里要改的，改完在下一个停点一起交。
