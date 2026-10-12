# 代理的两条路：回环口（文件只读 + 设置）与服务流（云端自用）（0022，账 87）

> 状态：所有者 2026-10-12 「开工 87」，远程写第一版（全部经会合点）；同日晚所有者问「要读用户的文件不是要传到云上吗」，远程给出甲（经云端过一下）/ 乙（回环直连，一个字节不出电脑）两案，**所有者选乙**。本篇按乙重写；第一版的会合点服务流保留给云端自己要用的两件事。astra 实施代理侧，远程实施后端、网页。
>
> 前提事实：Codex 干活时读写项目文件是经会合点把**命令**送到用户电脑执行，只有命令输出回云端（0015 §五）；app-server 自己的 `fs/*` 只读云端沙箱。所以「网页上看用户电脑的文件」要另开路。

## 一、决定

| 问 | 定 |
| --- | --- |
| **用户文件走哪** | **不出用户电脑**。网页（在装着代理的那台电脑上打开）直接问代理在本机回环口 `127.0.0.1:47811`（占则 47812，账 92 已为「这台电脑在不在」开的那个口）读目录与文件。工作台、会合点都不经手文件内容 |
| 谁能敲回环口 | 两道门：① 请求头 `Origin` 恰好等于站点 `web_origin`（已有）；② 请求带工作台签的**本机访问票**（`Authorization: Bearer <JWT>`，`aud=local-agent`、`sub=<会合点用户名>`、10 分钟）。代理用站点公钥（`GET {web_origin}/api/workbench/token-keys`，JWKS，缓存 10 分钟）就地验签，`sub` 必须等于它自己的 `userId`。票由网页向工作台要（`GET /api/workbench/environments/{id}/local-ticket`，只给环境主人） |
| 别的设备上开网页 | 探不到回环口，网页说「你现在用的这台电脑上没有在运行的代理」（账 92 的那句），文件树不显示。一个账号同一时刻一台电脑（91 甲），这正好 |
| 设置写入 | 同样走回环口（`PUT /local/v1/settings`）；凡是放宽的（加目录、抬沙箱、开网络、设知识库目录、开自启）代理在本机弹确认窗，用户点了才写；收窄直接写（第四节不变） |
| 会合点服务流（第一版的路）留给什么 | **云端自己要用的**、量小的两件：成稿「写了没有」的硬检查（`fs/getMetadata`）、以后信息采集往本地知识库 `采集/` 写回（0019 N2）。会合点 `/service` 段 0 已做，代理侧放到后面的任务页，不在 0.4.0 |
| 限额 | 回环口：同秒 > 20 次回 429（已有）；`fs/readFile` 一次 ≤ 1 MiB 原文（HTTP 没有帧上限，回原始字节不 base64）；目录一次 ≤ 2000 项；文件 > 64 MiB 拒绝 |
| 不碰的 | `codex-home`、代理配置目录、`.sandbox-secrets`、`auth.json`、白名单外任何路径；符号链接 / junction / 8.3 短名 / 设备名 / ADS 按现有 helper 身份检查拒 |

channels.md「没有工作台 → 本地代理下发任务」仍成立：回环口是浏览器到代理的本机请求，不起进程、不写用户文件；服务流只做云端那两件小事。

## 二、形状

```text
同一台电脑：
  浏览器（网页来自 web_origin） ──HTTP 127.0.0.1:47811──▶ 代理回环口：Origin 检查 → 验票 → 白名单检查 → 读文件 / 读写设置
  浏览器 ──HTTPS──▶ 工作台：只要一张票（GET …/local-ticket），工作台不碰文件

云端自用（少）：
  工作台 ──WSS /service──▶ 会合点 ──▶ 代理服务流（fs/getMetadata、以后的 采集/ 写入）
```

## 三、回环口的接口（浏览器 → 代理）

所有接口：只绑 `127.0.0.1`；`Origin` 必须等于 `web_origin`，否则 403 且不带 CORS 头；预检 `OPTIONS` 回 `Access-Control-Allow-Methods: GET, POST, PUT`、`Access-Control-Allow-Headers: Authorization, Content-Type`、`Access-Control-Allow-Private-Network: true`；除 `/presence` 外都要票，票不对 401。路径是用户电脑上的绝对路径，代理 `canonicalPath` 规整后判在不在白名单（`roots` ∪ 本地知识库目录）。错误一律 JSON `{ "code": "...", "message": "..." }`，`message` 固定英文短句不带路径。

| 方法与路径 | 参数 | 回 | 规矩 |
| --- | --- | --- | --- |
| `GET /presence` | — | `{ agent, version, machine_name, connected }` | 已有（账 92），不要票 |
| `GET /local/v1/info` | — | `{ agent, version, userId, roots, libraryDir, capabilities: ["local-fs-v1", …] }` | 网页据此画树根；`userId` 让网页核对是不是自己账号的电脑 |
| `GET /local/v1/fs/dir?path=` | `path` | `{ path, entries: [{ name, type: "file"\|"dir"\|"link"\|"other", size, mtime }], truncated }` | 只列一层；≤ 2000 项；白名单外 403 `outside_whitelist`；不存在 404 `not_found` |
| `GET /local/v1/fs/meta?path=` | `path` | `{ type, size, mtime }` | 同上 |
| `GET /local/v1/fs/file?path=&offset=&length=` | `length` 默认与上限 1 MiB | **原始字节**，`Content-Type: application/octet-stream`，头 `X-File-Size`（总长）、`X-File-Mtime`、`X-File-Eof: true\|false` | 文件 > 64 MiB 回 413 `too_large`；`length` 超上限 400 `invalid_params`；代理不判文本二进制，网页按前 8 KiB 判 |
| `GET /local/v1/settings` | — | `{ machineName, roots, rootChoices, ceiling, autostart, libraryDir, version }` | 与托盘「设置」窗同一份 |
| `PUT /local/v1/settings` | JSON `{ roots?, rootChoices?, ceiling?, autostart?, libraryDir? }` | `{ applied: true, restart }` 或 409 `local_denied` / 400 `invalid` / 409 `busy` | 校验同 `preferences set`；放宽先本机确认（第四节）；写完回包再重启常驻进程 |

错误码：`401 ticket_invalid`、`403 origin_rejected` / `outside_whitelist` / `local_denied`、`404 not_found`、`413 too_large`、`429 rate_limited`、`400 invalid_params`、`409 busy`。

**票的形状**：ES256 JWT，`iss` = 工作台、`aud = "local-agent"`、`sub` = 会合点用户名、`jti`、`iat`、`exp ≤ 10 分钟`。代理验：签名（JWKS 按 `kid` 选钥，取不到钥就 503 `keys_unavailable`）、`aud`、`sub == config.userId`、`exp`。不查吊销（10 分钟够短）。网页在票过期前 1 分钟重取。

## 四、设置写入的「放宽」判定

| 项 | 放宽（要本机确认） | 收窄（直接写） |
| --- | --- | --- |
| `roots` | 新增目录 | 去掉目录 |
| `ceiling.sandbox` | `read-only` → `workspace-write` | 反向 |
| `ceiling.network` | `false` → `true` | 反向 |
| `libraryDir` | 新设或换成另一个目录 | 清空 |
| `autostart` | 开 | 关 |
| `rootChoices`、`machineName` | 不算放宽，直接写 | — |

确认窗文案（与本机权限弹窗同一套机制，随机码、60 秒）：「网页要把这台电脑的设置改成：加目录 D:\资料；允许联网。只有你自己刚在网页上点了保存才输入下面的码。」多项放宽合成一窗问一次；拒绝或超时整条不写。记录：代理本地日志一条（不含路径）；网页「我的电脑」显示「上次从网页改：时间」（代理在 `info` 里带 `lastSettingsChange`）。

## 五、代理侧实现要点（astra，0.4.0）

| 处 | 要点 |
| --- | --- |
| `presence.ts` → `localApi.ts` | 同一个回环服务器上加 `/local/v1/*`；Origin 检查与限速共用；票验证单独一个 `ticket.ts`（JWKS 取自 `${webOrigin}/api/workbench/token-keys`，10 分钟缓存，Node 自带 `crypto.verify` + `createPublicKey({ key: jwk, format: "jwk" })`，不加依赖） |
| 文件读取 | Windows 经现有沙箱内文件助手（`WindowsFiles.call`：目录钉住、身份检查都在）；Linux 直接 `fs`（只为单测）；`fs/file` 回原始字节流 |
| `settings` | 复用 `preferences()` 的校验与写入；放宽判定 + `windowsConfirm`/`localConfirm`；一次只处理一个写，第二个 409 `busy`；写完回包再触发常驻进程重启 |
| `libraryDir` | `config.json` 新字段（可空），`validate` 校验；加入白名单检查的集合，**不**加进 `roots`；托盘「设置」窗加「本地知识库目录」一项 |
| 不改 | `filter.ts`、`windowsPolicy.ts`、`windowsBridge.ts`、沙箱流、配对协议、令牌处理；会合点服务流的代理侧（`open.kind=service`）**本轮不做** |
| 测试 | `localApi.test.ts`：无票 401、错 `sub` 401、过期 401、Origin 错 403 无 CORS 头、白名单外 403、符号链接逃逸、超大文件 413、分段读拼回、目录截断、限速 429、预检头；`settings` 放宽需确认 / 收窄直写 / 拒绝不写一半 / busy。真机：在投资网页「文件」里打开白名单下中文文件名的文件、读 5 MiB 文件分 5 段、从网页加目录看到确认窗、拒绝后配置不变 |

## 六、后端与网页（远程）

| 侧 | 改什么 |
| --- | --- |
| 后端 | `tokens.local_agent_ticket(relay_user)`（`aud=local-agent`，10 分钟）；`GET /api/workbench/environments/{id}/local-ticket` → `{ ticket, expires_at, relay_user }`（只给环境主人；没签名私钥 503）。第一版做的 `/fs/*`、`/settings` 端点**撤掉**（文件不经工作台）；`WsAgentService` 与 `/environments/{id}/service` 留着给硬检查用 |
| 网页 | `lib/workbench/local-agent.ts`：探回环口（47811 → 47812，`fetch(url, { targetAddressSpace: "loopback" })`，2 秒超时）、取票并缓存、`info / dir / file / settings` 五个调用；文件树与文件内容组件改用它；探不到 → 「你现在用的这台电脑上没有在运行的代理」（账 92 那半顺带做了：侧边栏电脑行旁的提示、`machine_name` 对得上标「就是这台」）；票 401 → 重取一次；`info.userId` 与账号的会合点名对不上 → 「这台电脑接的是别的账号」 |

## 七、不在这一篇里的

| 事 | 去哪 |
| --- | --- |
| 云端写本地知识库 `采集/` | 0019 N2，服务流上加写方法 |
| 拉取仓库（`git clone`） | 0017 K5，另写 |
| `fs/watch` | 面板打开时每 5 秒重读当前目录 |
| 成稿硬检查 | 服务流 `fs/getMetadata`，代理侧放后面的任务页 |

## 八、顺序与停点

| 段 | 谁 | 做什么 | 停点 |
| --- | --- | --- | --- |
| 0 | 远程 | 会合点 `/service`（已做，留给云端自用） | 已过 |
| 1 | astra | 回环口 `/local/v1/info`、`fs/dir`、`fs/meta`、`fs/file` + 验票 | Linux 单测 + Windows 真机在网页里读到文件；回执 |
| 2 | astra | `GET/PUT /local/v1/settings`（放宽确认、收窄直写、重启重报）+ `libraryDir` | 真机：网页加目录 → 确认窗 → 托盘里看到；拒绝不变 |
| 3 | 远程 | 票端点；网页回环客户端、文件树改直连、账 92 网页那半、「我的电脑」可编辑、本地知识库页 | 预览与测试；真机由所有者验 |
| 4 | 远程 + astra | 服务流代理侧（`fs/getMetadata`）+ 成稿硬检查 + Codex `reads` 加知识库目录 | 另开任务页 |

## 九、做出来的样子（滚动记）

| 段 | 时间 | 做了 | 和上面的出入 |
| --- | --- | --- | --- |
| 0 会合点 | 2026-10-12 下午 | `relay.py` `/service`、`open.kind`、`capabilities`，8 项测试 | 无；按乙案它留给云端自用 |
| 3 骨架（甲案） | 2026-10-12 晚 | 后端五端点 + `WsAgentService`；网页文件树经工作台 | **已按乙案改**：`/fs/*`、`/settings` 撤，留 `/service` 与票端点；网页改直连回环（见下一行） |
| 合同改一处 | 2026-10-12 17:38 | astra 实测 1 MiB 原文 base64 超会合点帧上限 | 乙案下回环口回原始字节，不再有这个问题；服务流那边仍是 512 KiB |
| 3 骨架（乙案） | 2026-10-12 夜 | 后端：撤 `/fs/*`、`/settings`，加 `GET /environments/{id}/local-ticket`（`aud=local-agent`、10 分钟，只给环境主人且已配对），`/service` 留给云端自用；网页：`lib/workbench/local-agent.ts`（探口 → 要票 → `info`，`userId` 核对账号；`fs/dir`、`fs/file` 原始字节、`settings` 读写），右边栏文件树与文件内容改直连；测试里核了工作台只被要一张票。后端 `22f8247`、网页本提交 | 账 92 网页那半（侧边栏「这台电脑还没接入」）与「我的电脑」可编辑、本地知识库页还没接，等 astra 段 1/2 真流 |

