# 给 astra：代理 0.3.1（2026-10-12）

> 所有者 2026-10-12 上午实测 0.3.0 与批 1 后定下三件，都在代理这头；所有者「开工」后远程写本页。`runtime` 仓，基线现网 0.3.0 = `dbe5d01`（luna 与 fable 同一提交）。本地提交，不 push，不合并别的分支；版本三处（`agent/package.json`、`src/cli.ts` 的 `VERSION`、`distribution/windows-x64.json`）改 **0.3.1**。每条一个提交，提交说明写清改了什么、怎么验的。做完写回执，所有者同步回去，远程审读，发布卡仍由 Cursor 跑。

## 一、改什么（按顺序）

### 1. Windows 执行端的命令输出切成 UTF-8（账 88）

**现象**：工作对话里让它列文件，第一条命令的输出每次都是乱码，模型自己再切 UTF-8 重跑一遍。
**原因**：中文 Windows 的 PowerShell 5.1 / cmd 往管道写 GBK（OEM 936），Codex 按 UTF-8 读。Codex 自带的 `prefix_powershell_script_with_utf8`（`codex-rs/core/src/tools/runtimes/unified_exec.rs`）只在**会话 shell** 是 PowerShell 时才加；我们的 app-server 在 Linux 沙箱里（会话 shell 是 bash），转到 Windows 执行端的 `process/start` 没有这一步。后端已在模式说明里嘱咐模型一句（权宜），根治在这里。

**改法**：`src/windowsBridge.ts` 转发 `process/start` 时，**过滤器按原 argv 判完、allow 之后**，紧挨着转发前改写 `argv`：

| 命令形状 | 改成 |
| --- | --- |
| `powershell[.exe] … -Command|-c <脚本>`（也包括 `pwsh`） | 脚本前加 Codex 同一句：`try { [Console]::OutputEncoding=[System.Text.Encoding]::UTF8 } catch {}\n`；已带这句的不重复加 |
| `cmd[.exe] /c|/d /c <命令>`（`/d /c` 顺序都认） | 命令前加 `chcp 65001>nul & ` |
| 其它可执行 | 不动 |

同时在 `env` 里补 `PYTHONUTF8=1`、`PYTHONIOENCODING=utf-8`（已有就不覆盖）。只改输出编码，不改命令本身；审批、过滤、权限协议都按原 argv，不许让改写后的 argv 进入判定。改写函数单独放一个文件（例如 `src/windowsEncoding.ts`），纯函数，带表驱动单测：PowerShell 五种写法（`-Command`、`-c`、`-NoProfile -Command`、已带前缀、无脚本串）、cmd 三种（`/c`、`/d /c`、无 `/c`）、非 shell 可执行不动、env 已有不覆盖。

**真机验**：在一个含中文文件名的白名单目录里，经工作对话让模型 `Get-ChildItem` 和 `dir`，第一条命令的输出就是正确的中文（看 `item/commandExecution` 事件里的 stdout 或后端记录），不再有「乱码→重跑」。

### 2. 本机配对页收尾（账 89 代理部分）

后端现在回给代理的 `verify_url` 已带 `?code=XXXX-XXXX`，网页读到码自动填、自动核对，用户只点允许——这条 0.3.0 已经受益，**配对逻辑不用改**。只改本机页和托盘的呈现（`src/pairPage.ts`、`native/desktop.ps1` 的连接状态窗）：

| 处 | 改成 |
| --- | --- |
| 本机页按钮「打开核对页」 | 改名「去网站允许」；地址就是带码的 `verify_url`，不变 |
| 本机页文案 | 出码后第一句改成：「网站页应该已经自动打开并填好了码，只要点「允许」。没有自动打开就点下面「去网站允许」。」把原来的「在核对页输入连接码」那句去掉；那句「只有这个码此刻显示在你自己的电脑上时才输」改成「别人发给你的码不要允许」 |
| 本机页加「复制连接码」 | 按钮 + 点码本身也复制；用 `navigator.clipboard.writeText`，失败退到选中文字；成功显示「已复制」两秒。CSP 不用放宽（`connect-src 'self'` 与剪贴板无关） |
| 托盘「连接状态」窗 | 显示页面地址与码那几行后面加一句「网站页会自动填码；没打开就复制上面的地址到浏览器」 |

**真机验**：托盘「重新连接账号」→ 浏览器开出本机页 → 网站页自动开且码已填好（这一步与所有者一起看，允许仍由所有者亲手点）；本机页「复制连接码」能复制、显示「已复制」；「去网站允许」打开的地址带 `?code=`。

### 3. 网页能认出「这台电脑没接入」（账 92，所有者 2026-10-12 定乙）

**现象**：所有者在第二台机器用同一账号登录，看到的是第一台电脑的名字，没有任何「这台电脑还没接入」的提示。网页看不出自己在哪台电脑上，要代理在本机开一个只读的回环小口让网页探一下。

**合同（网页那头照这个做，别改形状；要改先停下说）**：

| 项 | 定 |
| --- | --- |
| 谁开 | 后台常驻进程（`resident`）；它不在就探不到，网页把「没接入」和「代理没运行」合并说成「这台电脑上没有在运行的代理」 |
| 地址 | `http://127.0.0.1:47811/presence`；端口被占就用 `47812`；两个都占就不开并记日志。只绑 `127.0.0.1` |
| 方法 | `GET` 与预检 `OPTIONS`；其它路径 404、其它方法 405 |
| 来源 | 只认请求头 `Origin` 恰好等于 `site.json` 的 `web_origin`（现网 `https://investment.sunmoonai.com:30443`）。缺 `Origin` 或不等 → `403`，**不带任何 CORS 头**（浏览器里等于读不到） |
| 响应 | `200` JSON：`{"agent":"sunmoon-agent","version":"0.3.1","machine_name":"<本机名>","connected":true|false}`。四个键，不多一个；不含账号、令牌、目录、地址 |
| 头 | `Access-Control-Allow-Origin: <那个 Origin>`、`Vary: Origin`、`Cache-Control: no-store`、`Content-Type: application/json; charset=utf-8`；预检再加 `Access-Control-Allow-Methods: GET`、`Access-Control-Allow-Private-Network: true`（Chrome 的私有网络访问要这一句才放行从公网 https 页探回环）；不发 `Access-Control-Allow-Credentials` |
| 限速 | 同一秒超过 20 次请求回 `429`，防网页出错死循环 |
| 日志 | 只记次数，不记请求头 |

**为什么能探**：浏览器允许 https 页面请求 `127.0.0.1`（回环不算混合内容），Chrome 另要上面那句私有网络头。**真机验**：在所有者机器上，用现网投资网页的控制台 `fetch('http://127.0.0.1:47811/presence')` 能拿到 JSON；换一个来源（比如在 `https://example.com` 的控制台）同一请求被 CORS 拦住、代理回 403；`curl -i http://127.0.0.1:47811/presence`（无 Origin）403；`curl -i -H 'Origin: https://investment.sunmoonai.com:30443' …` 200 且只有那四个键；Edge 与 Chrome 各试一次。停掉代理再探，连接被拒。

网页那头（远程做）：侧边栏与设置页加载时探一次，2 秒超时、失败静默；探不到且账号下有电脑 → 电脑行旁提示「你现在用的这台电脑还没接入」+ 去设置页的链接；探到且 `machine_name` 与某台电脑同名 → 那一行标「就是这台」。等你的小口形状落地、回执给出真机证据后远程再接。

## 二、怎么验（真机，写进回执，缺一条不算完）

1. 每条配单测，vitest 全量过；`tsc` 过；`node --test distribution/test/bundle.test.mjs distribution/test/processes.test.mjs distribution/test/watchdog.test.mjs` 过（旁边要有 k8s 树，否则 `bundle.test` 读不到模板）。
2. `distribution/build.mjs` 在干净工作区组本机候选，装到临时目录，**不动现装**（所有者机器上现在是正式 0.3.0）。
3. 三条的真机证据各自列在回执里；没做到的明说，不写「应该可以」。
4. 顺手：`test/siteTrust.test.ts`「rejects the wrong CA path」在 Node ≥ 24.20 上会假失败（Node 拒绝同时给 `--use-system-ca` 与 `--use-openssl-ca`，退出 9、标准输出空）；加一句子进程退出 9 时跳过。

## 三、规矩

- 不改沙箱、协议过滤、配对协议、令牌处理；第 1 条的改写发生在过滤判定之后，判定仍看原 argv。
- 第 3 条的小口只读、只回四个键、只认一个来源；不开别的路径，不接受任何参数。
- 不贴 `config.json`；诊断状态目录里的凭据不进回执。
- 不结束与 SunMoon 无关的进程；zip 与回退目录放 `~/sunmoon-probe-runs/`，不进任何 git 仓。
- 回执放 `runtime/scripts/results/windows-agent-0.3.1-*.20261012.md`：原文输出、每条的证据、没做到的明说。
- 设计走不通（例如浏览器拦回环、端口被占）先停下写清楚交远程，不要绕。
