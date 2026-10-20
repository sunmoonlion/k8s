# 给 astra：代理 0.4.0 回环口——文件只读 + 设置写入（账 87，SDD 0022 乙案）

> 所有者 2026-10-12 「开工 87」后远程写第一版（全部经会合点）；同日晚所有者定**乙案：用户文件一个字节不出电脑**，本页按乙案重写，**之前那版作废**（你 17:38 发现的帧上限问题在乙案里不存在了，谢谢；你那条回执提交留着即可）。**你 18:31 交审的服务流段 1（`9d96980`）远程已审过、收下**：它在乙案里是「云端自用」那条路的代理侧，不用拆；`service.ts`、`relayClient.ts` 的分流、`helper.mjs` 的投影都保留，版本已是 0.4.0。下面两段在它之上做。设计全文在 [`tree-build/SDD/modules/0022-agent-service-channel.md`](../../../design/SDD/modules/0022-agent-service-channel.md)，**接口路径、字段、错误码、限额以它第三节为准；设计走不通先停下写清楚交远程**。`runtime` 仓，fable 分支，基线 = 你自己的 `9d96980`（含服务流段 1）。本地提交，不 push；版本三处改 **0.4.0**。做完写回执，所有者同步回去，远程审读。

## 一、要做的（两段，段 1 过了再做段 2）

### 段 1：回环口加文件只读 + 验票

| 处 | 做什么 |
| --- | --- |
| `presence.ts` → 扩成 `localApi.ts` | 同一个回环服务器（47811 → 47812）上加 `GET /local/v1/info`、`GET /local/v1/fs/dir?path=`、`GET /local/v1/fs/meta?path=`、`GET /local/v1/fs/file?path=&offset=&length=`；`/presence` 原样不动。Origin 检查与每秒 20 次限速共用；预检加 `Access-Control-Allow-Methods: GET, POST, PUT` 与 `Access-Control-Allow-Headers: Authorization, Content-Type`，`Access-Control-Allow-Private-Network: true` 照旧；不发 credentials |
| `ticket.ts`（新） | 验 `Authorization: Bearer <JWT>`：ES256，JWKS 取自 `${webOrigin}/api/workbench/token-keys`（缓存 10 分钟，取不到 503 `keys_unavailable`），按 `kid` 选钥；查 `aud === "local-agent"`、`sub === config.userId`、`exp` 未过、`iss` 存在。用 Node 自带 `crypto.createPublicKey({ key: jwk, format: "jwk" })` + `crypto.verify("sha256", …, { dsaEncoding: "ieee-p1363" })`，**不加依赖**。票不对 401 `ticket_invalid`，无票也 401 |
| 白名单 | 路径是用户电脑上的绝对路径（不是 URI）；`canonicalPath` 规整后必须在 `roots` 之下（段 2 再加 `libraryDir`）；`codexHome`、`CONFIG_DIR`、`.sandbox-secrets`、`auth.json` 一律 403；符号链接 / junction / 8.3 短名 / 设备名 / ADS 按现有 helper 身份检查拒 |
| 读 | Windows 经**现有沙箱内文件助手**（`WindowsFiles.call`）；Linux 直接 `node:fs`（只为单测）。`fs/file` 回**原始字节**（`application/octet-stream`，头 `X-File-Size`、`X-File-Mtime`、`X-File-Eof`），`length` 默认与上限 1 MiB，文件 > 64 MiB 回 413；目录 > 2000 项截断并 `truncated: true` |
| `info` | `{ agent, version, userId, roots, libraryDir: null, capabilities: ["local-fs-v1"] }` |
| 日志 | 只记路径类别与错误码、次数，不记路径与内容、不记票 |

**单测**（`test/localApi.test.ts`、`test/ticket.test.ts`，用本地生成的 P-256 钥对和假 JWKS 服务器）：无票 / 错 `sub` / 错 `aud` / 过期 / 坏签名各 401；JWKS 取不到 503；Origin 错 403 且无 CORS 头；白名单外 403；`..` 与大小写 / 短名变体；符号链接指向白名单外；超大文件 413；`length` 超上限 400；分段读拼回原文；目录截断；每秒第 21 次 429；预检头齐全；`/presence` 仍不要票。

**真机**（Windows，会话须 Full Access）：在投资网页里打开一个工作对话，右边栏「文件」能看到白名单目录树、点开一个中文文件名的 Markdown 看到内容（网页那半远程今晚做，你联调前 `git -C ~/worktrees/fable/investment-app pull` 拿最新，或先用浏览器控制台：先 `fetch('/api/workbench/environments/<环境id>/local-ticket')` 拿票，再带 `Authorization` 去敲 `http://127.0.0.1:47811/local/v1/info`）；读 5 MiB 文件分 5 段；读 `%USERPROFILE%\.codex` 下的文件 403；`curl` 不带票 401、不带 Origin 403。

### 段 2：设置读写 + 本地知识库目录

| 处 | 做什么 |
| --- | --- |
| 候选口 | 固定口改成按序试 **47811、47812、47813、47814、47815**（所有者机器上 47811 被 Cursor.exe 长期占着，现装 0.3.1 退到了 47812；再多备三个）；五个都占才记日志放弃。预检与 `/presence` 不变 |
| 验票小补 | 遇到没见过的 `kid` 且上次取钥已超过 60 秒，重取一次 JWKS 再判（工作台换钥时不用等 10 分钟） |
| `localApi.ts` | `GET /local/v1/settings`（与托盘「设置」窗同一份：`machineName, roots, rootChoices, ceiling, autostart, libraryDir, version, lastSettingsChange`）；`PUT /local/v1/settings`：校验复用 `preferences()`（目录存在、≤ 32、选项 ⊆ 候选、沙箱只 `read-only`/`workspace-write`）；**放宽判定按 0022 第四节**——有放宽项就弹本机确认窗（前台 `localConfirm`、后台 `windowsConfirm`，随机码、60 秒），一次合成一窗；拒绝或超时整条不写、回 409 `local_denied`；收窄直接写；同时只处理一个写，第二个 409 `busy` |
| 应用 | 写 `config.json` 后先回 `{ applied: true, restart: true }`，再触发常驻进程重启（现有 stop-request + 自启 / `startResident`），重连时控制通道 hello 重报 roots 与 ceiling |
| `libraryDir` | `config.json` 新字段（可空），`validate` 校验是本地绝对路径且存在；加入白名单检查集合；**不**加进 `roots`；`info` 里带出来 |
| 托盘「设置」窗 | 加「本地知识库目录」一项（选目录 / 清空），和白名单同一处 |

**单测**：放宽项各一例需确认；收窄项各一例直写；多项放宽只问一次；确认拒绝后 `config.json` 字节不变；`busy`；无效输入 400 且不弹窗。
**真机**：网页「我的电脑」里加目录 → 确认窗出现、文案含目录名 → 同意 → 代理重启 → 托盘「设置」里出现该目录 → hello 的 roots 含它；去掉该目录不弹窗直接生效；抬沙箱但在窗里拒绝 → 配置不变、回 409。

## 二、不在本轮的

会合点服务流的代理侧（`open.kind=service`，给云端做成稿硬检查用）另开任务页；本轮不碰。

## 三、规矩

- 不改 `filter.ts`、`windowsPolicy.ts`、`windowsBridge.ts`、配对协议、令牌处理；回环口**不起进程、不写用户文件**（`PUT settings` 只写 `config.json`）。
- 路径、文件内容、票不进日志、不进回执。
- 不结束与 SunMoon 无关的进程；zip 与回退目录放 `~/sunmoon-probe-runs/`，不进 git；不动现装（真机用源码 `start` 或装到临时目录）。
- 回执放 `runtime/scripts/results/windows-agent-0.4.0-*.<日期>.md`：每段原文输出、真机证据、没做到的明说。
- 版本：`agent/package.json`、`src/cli.ts` 的 `VERSION`、`distribution/windows-x64.json` 改 **0.4.0**。
