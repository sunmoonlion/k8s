# 0012 · Windows 本地代理：安装与首次接入

> 2026-10-09 由远程（Fable）定稿，所有者授权「设计要你来定」。luna 按本文分卡实现，不改设计；
> 实现中发现本文行不通，停下写明证据交远程改本文，不自行另起方案。
> 前提与边界见 [0005-agent](0005-agent.md)；令牌 30 天、托管、入口见 [decisions](../../decisions.md) 2026-10-09 各条。

## 一、目标

普通用户只用鼠标走完：

1. 网页「设置 → 我的电脑」点「复制安装命令」。
2. `Win+X` 打开「终端」，粘贴、回车（**唯一一次碰命令行，只是粘贴一行**）；它自动下载、校验、安装，并弹出设置窗口。
3. 弹出的设置窗口里点「连接我的账号」：窗口显示一个 8 位连接码，并打开浏览器到确认页。
4. 在浏览器确认页**输入**这 8 位码，核对电脑名字与时间，点「允许」。
5. 设置窗口自动进入下一步：选文件夹（可多选）、开机自启（默认勾上）→「完成」。
6. 网页侧栏小点变绿。

除粘贴那一行外不碰终端；不复制令牌、不设环境变量、不需要管理员；正式站点不导入任何证书（开发站点见下文 1）。

## 二、定下的设计（不再讨论）

### 1. 安装包里带「站点文件」

每个环境出各自的包（开发包、将来正式包），包内 `site/site.json`：

```json
{
  "site": "dev-kind",
  "web_origin": "https://investment.sunmoonai.com:30443",
  "relay_url": "wss://relay.sunmoonai.com:30443",
  "trust": { "mode": "bundled-ca", "ca_file": "site/ca.pem", "ca_sha256": "<组包时算出的证书 DER SHA-256 全长>" }
}
```

- `trust.mode`：`system`（正式站点，公共证书，只用系统库）或 `bundled-ca`（开发站点）。
- `bundled-ca` 时，**只有代理自己**多信任这一张 CA：所有 Node 入口带 `--use-system-ca`，并设 `NODE_EXTRA_CA_CERTS=<安装目录>\site\ca.pem`。**不往 Windows 证书库导入任何东西**，不弹 Windows 安全警告。
- 理由：包是用户从登录后的网页下载、由安装器按网页给的摘要校验过的；包里的代码本身就有完全的本机权限，包里的 CA 并不比代码更需要另外的信任。往系统根证书导入会影响用户整台电脑的所有程序，范围过大。
- 网页「我的电脑」在开发站点同时显示该 CA 的指纹（后端配置给出），供会核对的人比对；安装器不要求普通用户核对指纹。
- `site.json` 进包清单、受清单摘要保护；组包时按环境写入，**不能**由用户或网页参数改。
- 浏览器访问开发网页时信不信这张 CA，是开发站点自己的事，不在代理范围内（所有者的电脑已经导入过）。

### 2. 安装入口：一行命令（2026-10-09 卡 A 后改定）

**卡 A 实测**（runtime `e57e2b9`）：浏览器下载的 ZIP 带「来自网络」标记（`ZoneId=3`），资源管理器解压后每个文件都继承；智能应用控制把 `.cmd`、`.vbs`、指向签名 `node.exe` 的 `.lnk` 全部拦下。而所有者此前用 PowerShell 下载/`Expand-Archive` 解压的同一个包能正常安装运行——**不带网络标记就放行**。所以入口改为不经浏览器落盘的一行命令（uv、Bun、Scoop 等通行做法），不买代码签名证书（2026-10-07「第一期不买」不变）。

**用户看到的命令**（网页一键复制）：

```powershell
irm 'https://investment.sunmoonai.com:30443/api/agent-install/<一次性凭证>/script' | iex
```

- 不改执行策略、不带 `-ExecutionPolicy Bypass`、不关应用控制；`irm | iex` 在内存里执行，`RemoteSigned` 不涉及。
- 凭证不是令牌：只能下载安装脚本与安装包，**接不进电脑**；接入仍须第 3 节的网页确认配对。

**后端（投资后端，新增）：**

| 接口 | 说明 |
| --- | --- |
| `POST /api/workbench/agent/install-command`（登录 + CSRF） | 签一个下载凭证：32 字节随机，库里只存摘要；绑定所有者；10 分钟有效；最多 5 次请求（允许断点续传重试）。回完整命令字符串。下载未配置时回 `agent_download_unavailable` |
| `GET /api/agent-install/{凭证}/script`（无登录） | 凭证有效则回渲染好的 `install.ps1`（`text/plain; charset=utf-8`、`no-store`），脚本里写死：包地址（带同一凭证）、版本、大小、ZIP 与清单 SHA256、Codex 版本；无效/过期/用尽一律 404 |
| `GET /api/agent-install/{凭证}/package`（无登录） | 与现有 `/api/workbench/agent/package` 同一实现（对象、长度、摘要只来自配置，Range/If-Range，边读边算摘要），只是鉴权换成凭证 |

凭证过期由现有调度清理；签发与使用计数在同一事务内；限速：每用户每小时签 10 个。

**`install.ps1`（随后端渲染，源码模板放 runtime `agent/distribution/install.ps1.tmpl`，后端只做字段替换）：**

1. `$ErrorActionPreference='Stop'`；检查 Windows x64、PowerShell 5.1+。
2. `Invoke-WebRequest` 下载到 `%TEMP%\sunmoon-agent-<随机>\pkg.zip`（不产生网络标记），断线用 Range 续传最多 3 次。
3. 核 ZIP 长度与 SHA256；`Expand-Archive` 到同一临时目录；核清单 SHA256。任一不符：删临时目录、用中文说明原因、退出非 0。
4. 已安装同版本：直接打开托盘与设置窗口，结束。已安装旧版本：先 `stop`，再按现有卸载逻辑**保留配置**卸载，再装新版本（升级）。
5. 用包内 `node\node.exe` 直接执行安装器（不经 `.cmd`）装到 `%LOCALAPPDATA%\Programs\sunmoon-agent`；建开始菜单「SunMoon 代理」。
6. 删临时目录；启动托盘并打开第 4 节的设置窗口；在终端打印一句「请在弹出的窗口里继续」。

**开发站点的前提：** `irm` 走 Windows 自己的证书库，所以开发站点要求这台 Windows 已信任开发 CA（所有者的电脑已导入）。网页在开发站点的「我的电脑」顶部显示一步「先导入开发证书」（下载 CA、显示 SHA-256 指纹、给出 `Import-Certificate … Cert:\CurrentUser\Root` 一行），正式站点不显示。代理自身仍按第 1 节用随包 CA，不依赖系统库。

**备用：** 网页「高级」里保留 ZIP 下载，并写明「下载后右键 ZIP → 属性 → 勾『解除锁定』→ 再解压，双击『安装』」；不作为主路径。

### 3. 浏览器确认配对

照设备授权流程（RFC 8628）的思路，但**码由用户在网页输入**（防「别人把码发给你骗你点允许」）。

**数据：** 投资后端新表 `workbench_agent_pairings`

| 列 | 说明 |
| --- | --- |
| `id` uuid | 请求号 |
| `code_hash` | 8 位连接码的 HMAC（服务端密钥），用于按码查找；明文码不入库 |
| `device_secret_hash` | 代理生成的 32 字节随机秘密的 SHA-256；轮询必须出示原秘密 |
| `machine_name`、`os`、`agent_version`、`codex_version` | 代理上报，网页展示用；长度、字符集校验 |
| `source_ip` | 创建请求的来源 IP（经入口的可信转发头） |
| `status` | `pending` → `approved` → `delivered`；或 `denied` / `cancelled` / `expired` |
| `owner_actor_id` | 允许时写入 |
| `token_ciphertext` | 允许时放入新代理令牌（现有 cipher 加密）；交付后立即清空 |
| `created_at`、`expires_at`（+5 分钟）、`decided_at`、`delivered_at`、`attempts` | |

**连接码：** 8 个字符，字母表去掉易混字符（`ABCDEFGHJKLMNPQRSTUVWXYZ23456789`），显示为 `XXXX-XXXX`；同一时刻全局唯一（pending 中）。

**接口：**（新 router，不挂在 `/workbench` 的登录依赖下；全部 `no-store`）

| 方法与路径 | 谁调 | 说明 |
| --- | --- | --- |
| `POST /api/agent-pairing/requests` | 代理，**无登录** | 体：`machine_name, os, agent_version, codex_version, device_secret_sha256`。回：`request_id, user_code, expires_in=300, interval=3, verify_url`（`verify_url` = 网页设置页地址，**不带码**）。按来源 IP 限速（每分钟 5、每小时 30）；全站 pending 上限（如 500）防灌满 |
| `POST /api/agent-pairing/requests/{id}/poll` | 代理，无登录 | 体：`device_secret`。回 `{status}`；`approved` 时回 `relay_url, relay_user, agent_token, agent_token_expires_at`，同一事务把状态改 `delivered`、清空 `token_ciphertext`。轮询快于 `interval` 回 429 `slow_down`。秘密不对一律 404（不暴露存在） |
| `POST /api/agent-pairing/requests/{id}/cancel` | 代理，无登录 | 体：`device_secret`。pending 才能取消 |
| `POST /api/workbench/agent-pairing/lookup` | 网页，**登录 + CSRF** | 体：`user_code`。回待确认请求的展示信息（电脑名、系统、版本、来源 IP、发起于几分钟前）与「会替换的当前电脑」（若有）。按用户限速（每分钟 5、每小时 20 次失败）；查不到统一回「码不对或已过期」 |
| `POST /api/workbench/agent-pairing/{id}/approve` | 网页，登录 + CSRF | 体：`user_code`（再交一次，防只凭 id 批准）。见下 |
| `POST /api/workbench/agent-pairing/{id}/deny` | 网页，登录 + CSRF | |

**允许时做什么（一个用户级咨询锁内，沿用 provisioning 的锁）：**

1. 请求仍 `pending`、未过期、码匹配；否则拒。
2. 该用户已有中转身份 → 走现有**轮换**（吊销旧令牌、签新一对、在线沙箱滚动）；没有 → 走现有 `ensure_relay_identity`（**不要求先有沙箱**；模型 key 未登记也允许接入电脑，干活时再提示登记 key）。
3. 新代理令牌加密写进这条请求，`status=approved, owner_actor_id, decided_at`。
4. 写一条工作台审计事件 `agent/paired`：电脑名、来源 IP、时间、请求号（不含令牌）。

**安全要点：**

- 令牌只经代理那条 TLS 轮询交付一次；不回给浏览器、不进 URL、不进日志与审计。
- 码只用于网页「找到这条请求」；真正拿令牌靠代理手里的 `device_secret`——偷看到码的人拿不走令牌。
- 确认页醒目写：「只有当这个码此刻正显示在**你自己的电脑**上时才点允许。别人发给你的码不要输。」并写清「当前连着的电脑『X』会断开；云端沙箱会重启几十秒」。
- 允许后，网页与托盘都显示「电脑『X』已于 HH:MM 连接」。
- 网页里原来的「换代理令牌」「首次领令牌」保留，收进「高级」折叠区，作手工备用。
- 过期请求由现有调度每 10 分钟清理为 `expired`，清空残余密文。
- `WORKBENCH_TRUSTED_PROXY_CIDRS` 默认留空；留空只记录直连对端地址，忽略所有 `X-Forwarded-For`。Card B 只实现这个配置和安全回退，不写入网段值。Card E 按现网核实 Traefik 到后端的直接来源地址及转发行为后再决定是否配置；无法取得可信来源时确认页显示「未知」。
- 配对连接码、轮询 `device_secret`、安装凭证及代理令牌不写日志。Uvicorn 访问日志、应用日志和异常处理统一脱敏；配对/安装相关应用日志只记请求号与结果，不记录请求体、凭证路径或异常栈内容。Card E 另核实 Traefik 访问日志是否启用、是否记录完整路径，以及是否会记录安装凭证；Card B 不改集群入口。

### 4. 代理与设置窗口

- 新命令 `sunmoon-agent pair`：读 `site.json` → 建请求 → 输出码与到期时间（JSON 给界面用）→ 每 3 秒轮询 → 拿到后写 `config.json`（`relayUrl`、`userId`、`token`；与 `init` 写的格式相同）→ 退出码 0。超时/拒绝/取消各有退出码与人话。`init --token-prompt` 保留作备用。
- 设置窗口（`desktop.ps1` 新增 `setup` 视图）四步：
  1. **连接账号**：按钮「连接我的账号」→ 调 `pair` → 大字显示 `XXXX-XXXX` 和倒计时 → 自动打开 `verify_url` → 成功后显示「已连接到 <账号>」。可「取消」「重新获取连接码」。
  2. **选文件夹**：沿用现有勾选列表；至少可以一个都不选（会提示「不选的话工作和专家碰不到你的文件」）。
  3. **开机自动运行**：默认勾上 → 调现有 `autostart enable`。
  4. **完成**：启动后台，等到 `connected`（最多 30 秒）显示「已在线」；连不上就显示人话原因与「重试」。
- 已接入过的电脑再次打开开始菜单入口，直接进托盘；托盘菜单里有「重新连接账号」（重走第 1 步）。
- **错误要说人话**（日志、`status.lastError`、托盘、设置窗口一致，带原始错误码，不带令牌）：

| 原始 | 人话 |
| --- | --- |
| TLS `UNABLE_TO_VERIFY_*`、`UNABLE_TO_GET_ISSUER_CERT*`、`SELF_SIGNED_*`、`DEPTH_ZERO_SELF_SIGNED_CERT`、`CERT_*`、`ERR_TLS_CERT_ALTNAME_INVALID`（2026-10-10 C1 审读补） | 「这台电脑不信任站点证书。请重新从网页下载安装包；若仍出现，联系管理员。」 |
| `ENOTFOUND` / `ECONNREFUSED` / 超时 | 「连不上 <主机>。检查网络或代理设置。」 |
| 401/吊销（4003） | 「这台电脑的连接已失效，请点『重新连接账号』。」 |
| 4000 被替换 | 「你的账号已在另一台电脑上连接，这台已断开。」 |
| 配对过期 / 被拒 | 「连接码已过期 / 已被拒绝，请重新获取。」 |

### 5. 网页

- 「我的电脑」整节并进「设置」（锚点 `#computer`），侧栏只留在线小点链接过去；各处「接入电脑」按钮跳这里。
- 这一节自上而下：在线状态与当前电脑 →「下载」（版本、大小；开发站点另显示 CA 指纹）→「连接一台电脑」（输入 8 位码 → 确认卡片 → 允许/拒绝）→ 已接入电脑列表 →「高级」（手工领令牌、换令牌）。
- **电脑连接与云端沙箱分成两块**：沙箱块只有「拉起 / 更新 / 回收」；原「换代理令牌」移到「我的电脑 → 高级」，改名「重新连接电脑」，旁边写清「会同时换掉电脑和云端沙箱的令牌：旧电脑断开，在跑的沙箱重启几十秒」。完成后用后端回的 `sandbox_rolled` 明确提示「云端沙箱已换用新令牌，正在重启」，不让人以为只换了一边（所有者 2026-10-09 撞到的困惑）。
- 五步引导改为三步：下载安装 → 在电脑上点「连接我的账号」并在这里输入码 → 选文件夹完成。完成状态由后端事实决定，不再让用户自己勾「我已下载」。

## 三、分卡与停点（每张做完停下交远程审）

| 卡 | 内容 | 验收 |
| --- | --- | --- |
| **A 实验** | 已完成（runtime `e57e2b9`）：浏览器下载 + 资源管理器解压后三种双击入口全被智能应用控制拦 | 结论见第 2 节 |
| **A2 一行命令验证** | 已通过（2026-10-09；详见 runtime 卡 A2 回执）。真实下载无 `Zone.Identifier`，清单核验通过，包内 Node 执行安装器并命中自身“已安装不能覆盖”保护；这不是 Smart App Control 拦截。所有者确认等价路径此前已打开 `desktop.ps1` 托盘。所有者网页已确认换令牌后 `agent_token_expires_at` 显示 2026-11-08。不安装、不改令牌 | 下载、解包、Node 执行路径与 30 天期限核对通过 |
| **B 后端配对与安装凭证** | 配对：表、迁移、六个接口、锁内允许、审计、过期清理、限速；复用现有签发与轮换。安装凭证：签发接口、脚本与包两个凭证接口、计数与过期 | 单测 + 真 PostgreSQL：并发两次允许只成一次、错用户/错码/过期/重放/取消竞态/限速/秘密错 404、交付后密文清空、旧令牌吊销；全套、ruff、import-linter 过 |
| **C 代理** | `site.json` 与信任、所有入口统一启动方式、`pair` 命令、设置窗口四步、错误人话、开始菜单与自启默认开、组包按环境写入站点文件、`install.ps1.tmpl`。升级实现 SDD 第 2 节第 4 步：旧版先 stop，再按现有卸载逻辑保留配置卸载，最后安装新版；同版本走打开托盘/设置的路径；不得因目标已存在而覆盖安装或绕开完整性保护 | Linux/Windows 全测；覆盖同版本、旧版升级（保留配置）、安装拒绝/失败回退；Windows 上真实对着本地起的后端走一遍配对；错误映射表逐条有测试 |
| **D 网页** | 并进设置、「复制安装命令」、开发站点的「先导入开发证书」一步、输入码与确认卡片、高级区（ZIP 备用与解除锁定说明、重新连接电脑）、三步引导、侧栏小点 | 组件测试；预览样例由后端录制（补 lookup/approve 样例）；Node 24 |
| **E 发行验收**（Cursor 发布 + 所有者真人） | 后端 + 网页 + 新包成对发布；所有者从「复制安装命令」开始走完（只粘贴一行，其余鼠标）；再分别验重启自启、取消/过期配对、换电脑被顶下线。上线前按现网核实 Traefik 到后端的直接来源网段与 XFF 行为后再配置 `WORKBENCH_TRUSTED_PROXY_CIDRS`；核实 Traefik 访问日志是否开启、是否记录完整路径及安装凭证，必要时按实际入口配置避免凭证泄露 | 所有者走完全程；干净 Windows 另约；可信来源与入口日志核对结果入发行记录 |

B、C、D 可以并行写，但**一起发布**（E）。C 里「所有入口统一启动方式 + 错误人话」可以先单独出一个 0.2.2 包让所有者那台先稳定用，不等配对。

## 四、不做（第一期）

多台电脑同时在线（账 63）；自动更新；代理侧令牌加密存储（DPAPI，记账待议）；浏览器扩展式登录。
