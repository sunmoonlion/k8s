# 代理的服务流：文件只读 + 设置写入（0022，账 87）

> 状态：所有者 2026-10-12 「开工 87」，远程写设计；astra 实施代理侧，远程实施会合点、后端、网页。前提事实：Codex app-server 的 `fs/*` 只读云端沙箱自己的文件系统，到不了用户电脑（0015 §五，2026-10-12 读源码核实）。所以网页要看用户电脑上的目录与文件、要从网页改代理侧设置，都得代理自己开一条路。

## 一、决定

| 问 | 定 |
| --- | --- |
| 会合点要不要第三种客户 | **要**。工作台作为第三种出站客户连会合点（路径 `/service`，角色 `workbench`），会合点像配沙箱一样把它配到该用户的代理，之后逐帧透传。会合点仍无状态、不解析正文 |
| 协议 | JSON-RPC 2.0 文本帧，方法名沿用 exec-server 的 `fs/*` 形状（`fs/readDirectory`、`fs/readFile`、`fs/getMetadata`），加 `settings/*`。字段按本篇第三节，不照搬 exec-server 的全部参数 |
| 鉴权 | 工作台自己签 `aud=relay`、`sub=<会合点用户名>`、`role=workbench`、`exp ≤ 10 分钟` 的 JWT，会合点用现有公钥就地验（`F-RELAY-01`）。代理那头不再验令牌（它只认会合点配过来的流），但**每个请求都过白名单与只读检查** |
| 能做什么 | **读**白名单目录与本地知识库目录下的目录与文件；**读写**代理侧设置（白名单、上限、自启、本地知识库目录）。**不能**起进程、不能写文件（0019 N2 的 `采集/` 写入与 0017 K5 拉取仓库另记，见第七节） |
| 「云端不能改本地上限」怎么守 | 守住。设置写入里**凡是放宽的**（加目录、抬沙箱、开网络、换知识库目录）代理都在本机弹确认窗（与本机权限弹窗同一套：随机码、60 秒、无 TTY/超时/断线即拒），用户点了才写；**收窄的**（去目录、降沙箱、关网络、关自启）直接写。网页只是把「用户想改成什么」送到他自己的电脑上，最后一步仍是他在电脑上点 |
| 限速与大小 | 每用户同时至多 2 条服务流；每流同时 4 个未完成请求、每秒 50 个；单帧 ≤ 1 MiB；`fs/readFile` 一次 ≤ 1 MiB，大文件分段读；目录一次 ≤ 2000 项 |
| 不碰的 | `codex-home`、代理配置目录、`.sandbox-secrets`、`auth.json`、任何白名单外的路径；符号链接 / junction / 8.3 短名 / 设备名 / ADS 一律按现有 helper 的身份检查拒绝 |

channels.md 里那句「没有工作台 → 本地代理下发任务这条通道」仍成立：这条流**不下发任务**，不起进程；它是「看一眼、改设置」。

## 二、形状

```text
浏览器 ──HTTPS──▶ 工作台 ──WSS 出站 /service（role=workbench）──▶ 会合点 ◀──WSS 出站── 本地代理（控制通道收到 open{kind:"service"} 后开 /agent-data）
                                                                   │ 配对后逐帧透传（JSON-RPC 2.0 文本帧）
                                                                   ▼
                                                        代理内的服务处理器（不是 exec-server）：白名单检查 → 读文件 / 读写设置
```

与现有数据流的差别只有两处：会合点的 `open` 多一个 `kind`（没有 `kind` = 沙箱流，照旧接 exec-server；`kind:"service"` = 接服务处理器）；工作台这一端的角色是 `workbench`，不是 `sandbox`，不检查 Codex 版本成对，但检查**代理能力**：代理控制通道 hello 的 `capabilities` 里要有 `service-v1`，没有就拒绝工作台（`agent has no service channel`），网页据此说「这台电脑的代理要升级」。

## 三、方法（工作台 → 代理）

所有路径都是用户电脑上的绝对路径（Windows 原样 `C:\...`），不是 URI；代理按 `canonicalPath` 规整后再判在不在白名单（白名单 = `roots` ∪ 本地知识库目录）。

| 方法 | 参数 | 结果 | 规矩 |
| --- | --- | --- | --- |
| `service/hello` | — | `{ agent, version, roots, libraryDir, capabilities }` | 流建好后工作台先发这一条；代理回它此刻的白名单，网页据此画树根 |
| `fs/readDirectory` | `{ path }` | `{ entries: [{ name, type: "file"\|"dir"\|"link"\|"other", size, mtime }], truncated }` | 只列一层；≤ 2000 项，多了 `truncated:true`；`link` 不解析目标；`path` 不在白名单回 `-32010 outside_whitelist` |
| `fs/getMetadata` | `{ path }` | `{ type, size, mtime }` | 同上 |
| `fs/readFile` | `{ path, offset?, length? }` | `{ content: base64, size, mtime, eof }` | `length` 默认与上限都是 1 MiB；超过 64 MiB 的文件拒绝（`-32011 too_large`）；代理不判文本还是二进制，网页按前 8 KiB 判 |
| `settings/read` | — | `{ machineName, roots, rootChoices, ceiling, autostart, libraryDir, version }` | 与托盘「设置」窗显示的同一份 |
| `settings/write` | `{ roots?, rootChoices?, ceiling?, autostart?, libraryDir? }` | `{ applied: true, restart: boolean }` 或 `{ applied: false, reason: "local_denied"\|"invalid"\|"busy" }` | 校验同 `preferences set`（目录存在、≤ 32、选项 ⊆ 候选、沙箱只在 `read-only`/`workspace-write`）；**放宽项先本机确认**（见第四节）；写 `config.json` 后代理自己重启常驻进程，控制通道重连时 hello 重报 roots 与 ceiling；一条流上同时只处理一个 `settings/write`，第二个回 `busy` |

错误码：`-32010 outside_whitelist`、`-32011 too_large`、`-32012 not_found`、`-32013 rate_limited`、`-32014 local_denied`、`-32600`/`-32601`/`-32602` 照 JSON-RPC。错误 `message` 固定英文短句，不带路径。

## 四、设置写入的「放宽」判定

| 项 | 放宽（要本机确认） | 收窄（直接写） |
| --- | --- | --- |
| `roots` | 新增目录 | 去掉目录 |
| `ceiling.sandbox` | `read-only` → `workspace-write` | 反向 |
| `ceiling.network` | `false` → `true` | 反向 |
| `libraryDir` | 新设或换成另一个目录 | 清空 |
| `autostart` | 开 | 关 |
| `rootChoices`、`machineName` | 不算放宽，直接写 | — |

确认窗文案（与本机权限弹窗同一套机制，随机码、60 秒）：「网页要把这台电脑的设置改成：加目录 D:\资料；允许联网。只有你自己刚在网页上点了保存才输入下面的码。」一次 `settings/write` 里有多项放宽，合成一窗问一次。拒绝或超时整条不写（不做一半）。

记录：代理本地日志一条（不含路径）；工作台在 `workbench_environments` 上记 `last_settings_change_at`，网页「我的电脑」显示「上次从网页改：时间」。不走 `permission_report` 那条审计路（那条是针对 thread 的）。

## 五、代理侧实现要点（astra）

| 处 | 要点 |
| --- | --- |
| `relayProtocol.ts` | `ControlMessage.open` 加可选 `kind?: "service"`；hello `capabilities: ["service-v1"]`（控制通道 hello 新增字段，旧会合点忽略） |
| `relayClient.ts` | `openStream(conn, kind)`：`kind === "service"` 时不连 exec-server，把上行帧交给 `ServiceHandler`；统计分开（`stats.service`）；最多 2 条服务流，第 3 条直接关 |
| `service.ts`（新） | JSON-RPC 分发、限速（令牌桶 50/s，4 并发）、路径规整与白名单检查、`fs/*` 读；Windows 上读文件经**现有的沙箱内文件助手**（`WindowsFiles.call`，它已经有目录钉住与身份检查），Linux 上直接 `fs`（只为测试）；`settings/*` 复用 `preferences()` 的校验与写入，放宽判定 + `windowsConfirm`/`localConfirm` |
| 重启 | `settings/write` 应用后回包，再触发常驻进程重启（现有 `stop-request` + 自启任务 / `startResident`）；重启期间服务流断，网页重连即可 |
| 不改 | `filter.ts`、`windowsPolicy.ts`、`windowsBridge.ts`（沙箱流一个字节不动）；配对协议；令牌处理 |
| 测试 | `service.test.ts`：白名单外路径、符号链接逃逸、超大文件、分段读、目录截断、限速、并发上限、`settings/write` 放宽需确认 / 收窄直写 / 拒绝不写一半 / busy；`relayClient.test.ts` 加 `open{kind:"service"}` 分流；真机：在网页文件树里打开白名单下的中文文件名文件、读一个 5 MiB 文件、从网页加一个目录看到确认窗、拒绝后配置不变、同意后托盘设置窗里出现新目录 |

## 六、会合点、后端、网页（远程）

| 侧 | 改什么 |
| --- | --- |
| 会合点 `relay.py` | 新路径 `/service`：hello `role=workbench`，验签同前；找该用户代理，无则 `agent offline`；代理 hello 的 `capabilities` 不含 `service-v1` 则 `agent has no service channel`；每用户服务流 ≤ 2（`RELAY_MAX_SERVICE_STREAMS_PER_USER`）；向代理发 `{"type":"open","conn":ID,"kind":"service"}`；其余与 `/sandbox` 相同（透传、关闭计数）。单帧 ≤ 1 MiB。`/admin` 的 `agents` 回包加 `capabilities` |
| 后端 | `tokens.workbench_token(relay_user)`（`role=workbench`，10 分钟）；`ServiceClient`：按用户懒建一条到会合点 `/service` 的 WS，空闲 60 秒关，请求带 id、30 秒超时；HTTP：`GET /api/workbench/machines/{env}/fs/dir?path=`、`GET …/fs/file?path=&offset=&length=`、`GET …/settings`、`PUT …/settings`；只允许环境的主人；代理离线 503 `agent_offline`，能力不够 409 `agent_outdated`，白名单外 403 `outside_whitelist`；不缓存文件内容 |
| 网页 | 右边栏「文件」：树根 = `service/hello` 的 roots + libraryDir，当前项目默认展开，目录懒加载，点文件看内容（≤ 1 MiB 文本、Markdown 渲染；二进制或更大只给大小）；本地知识库页（0019 N1）同一棵树组件，根 = libraryDir；「我的电脑」块可编辑：目录勾选（候选来自 `rootChoices`，可加新目录——输入绝对路径）、沙箱模式、联网、自启、知识库目录；保存后显示「等你在电脑上确认」直到回包；代理离线或版本旧时只显示并说明 |

## 七、不在这一篇里的

| 事 | 去哪 |
| --- | --- |
| `fs/writeFile` 只写本地知识库 `采集/` 子目录 | 0019 N2，服务流上加一个写方法，白名单加「只许写该子目录」一种权限；本篇通了再加 |
| 拉取仓库（`git clone`） | 0017 K5：要起进程、要凭据，和本篇「不起进程」相抵，另写；所有者先定凭据怎么给 |
| `fs/watch` | 第一期网页在面板打开时每 5 秒重读当前目录，不要 watch；代价摸清再加 |
| 成稿「写了没有」的硬检查（0015） | 本篇通了后，后端在验收时经服务流 `fs/getMetadata` 核实文件存在，把软检查改硬 |

## 八、顺序与停点

| 段 | 谁 | 做什么 | 停点 |
| --- | --- | --- | --- |
| 0 | 远程 | 会合点 `/service` + `open.kind`；本地可跑的会合点供 astra 测 | 会合点单测过、k8s fable 有提交号 |
| 1 | astra | 服务流 + `service/hello` + `fs/*` 三个只读方法 | Linux 单测 + Windows 真机读到文件；回执 |
| 2 | astra | `settings/read`、`settings/write`（放宽确认、收窄直写、重启重报） | 真机：网页加目录 → 确认窗 → 托盘里看到；拒绝不变 |
| 3 | 远程 | 后端四个端点 + 网页文件树、本地知识库页、我的电脑可编辑 | 预览与测试；真机由所有者验 |
| 4 | 远程 | 0015 硬检查、0019 N1 Codex `reads` 加知识库目录 | — |

版本：代理 **0.4.0**（协议能力 `service-v1`）；会合点 `RELAY_PROTOCOL` 不变（新路径、新 `open` 字段向后兼容）。

## 九、做出来的样子（滚动记）

| 段 | 时间 | 做了 | 和上面的出入 |
| --- | --- | --- | --- |
| 0 会合点 | 2026-10-12 下午 | `relay.py` `/service`、`open.kind`、`capabilities`，8 项测试 | 无 |
| 3 骨架 | 2026-10-12 晚 | 后端：`agent_service.py`（`WsAgentService` 一问一答、拒绝与错误码照搬成 HTTP、`validate_path`）、`tokens.workbench_token`（10 分钟）、五个端点 `GET /environments/{id}/service`、`/fs/dir`、`/fs/file`、`GET/PUT /settings`；归属看环境主人，连谁看该账号的会合点身份；没配即 503 `agent_service_unconfigured`，没配对即 503 `agent_offline`。网页：`lib/workbench/file-tree.ts`（路径算术、树根、排序、文本判定）、`components/workbench/file-tree.tsx` + `file-view.tsx`，右边栏「文件」接上：根 = 白名单 + 本地知识库，当前项目默认展开，目录懒加载，点文件看内容（Markdown 渲染，二进制只给大小），代理离线 / 版本旧 / 通道没配各说一句。测试：后端 12、网页 9 | ① 端点挂在 `/environments/{id}/…` 而不是 `/machines/{env}/…`（网页里电脑就叫 environment）；② 后端不复用连接，一问开一条流，省连接以后再做；③ 「我的电脑」可编辑与本地知识库页还没做，等 astra 段 2 回执 |

真流联调（Windows 代理 0.4.0 + 本机 relay）等 astra 段 1 回执；骨架的对接点是 `WsAgentService.call`，形状按第三节，不改。

