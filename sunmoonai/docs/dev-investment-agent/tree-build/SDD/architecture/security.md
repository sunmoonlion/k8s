# 安全模型

> 隐私不作产品约束，但**用户的机器不是我们的**。安全模型只守三件事：云端不能越权控制用户机器、用户的 key 不外泄、越权访问别的用户的东西不可能。

## 威胁与对策

| 威胁 | 后果 | 对策 | 验收 |
| --- | --- | --- | --- |
| 工作台或沙箱被攻破，借 Codex 协议在用户机器上跑命令 | 远程控制用户机器 | **本地上限**：exec-server 一侧限定沙箱模式、根目录、网络；云端要求更高权限被拒绝；越出的动作只能在本机被用户抬高（`C-A11`） | `AT-09` `AT-18` |
| 边缘被攻破 | 拿到流量与令牌 | 边缘无状态；令牌短期、按用户、可吊销；沙箱与代理的令牌不通用 | `AT-22` |
| 一个用户的沙箱连到别人的代理 | 跨用户执行 | 会合点按用户配对；两端令牌的 `sub` 必须一致 | `AT-05` |
| 用户 key 泄露 | 用户账单 | key 只在密钥库与沙箱进程环境；不进表、事件、日志、界面、执行环境（`C-D10`） | `AT-21` |
| exec-server 监听无认证 | 局域网内任何人驱动用户机器 | exec-server 只绑 `127.0.0.1`；唯一入口是代理的出站桥 | `0005-agent` 测试 |
| 执行端的家被云端读走 | 云端经 `fs/readFile` 拿到用户 Codex 登录态 | 执行端 `CODEX_HOME` 是代理自己的目录，不含凭据，与用户 `~/.codex` 隔离（`F-AGENT-10`） | `0005-agent` 测试 |
| 沙箱之间互访 | 跨用户读 `CODEX_HOME` | 每用户一个 pod，NetworkPolicy 只允许出站到会合点、知识服务、模型厂商 | `0003-sandbox` 测试 |
| 版本错配静默降级 | 协议行为不可知 | 成对钉版，不匹配拒绝 | `AT-28` |
| 定位失守 | 输出投资建议 | 云端确定性检查拦截并留痕 | `AT-20` |

## 本地上限

本地代理启动 exec-server 时声明三项，写进环境的登记：

| 项 | 默认 | 用户可抬到 |
| --- | --- | --- |
| 沙箱模式 | `workspace-write`，限 `cwd` | `danger-full-access`（本机确认，仅当前 Session） |
| 根目录 | 白名单 | 加目录（本机确认） |
| 网络 | 沙箱内禁网 | 放开（本机确认） |

**由谁挡已定（探针 2026-09-23，`runtime/probe/REPORT-2026-09-23-local-ceiling.md`）：exec-server 自己不挡，本地代理必须挡。**
执行端的 `config.toml`（`sandbox_mode="read-only"`）与 `requirements.toml`（`allowed_sandbox_modes=["read-only"]`）对编排端的要求毫无作用：
编排端要 `danger-full-access` 就能写 `$HOME`，要 `workspace-write` 就能写 cwd，cwd 放在声明根之外照样执行。沙箱策略、cwd、workspace roots 全部由编排端随每个 `process/start` 下发，执行端只负责实施。
所以本地代理要做两层：

| 层 | 做什么 | 守什么 |
| --- | --- | --- |
| 外沙箱（OS 级） | 代理把 exec-server 进程本身放进一个只能写白名单目录的 OS 沙箱。**Linux 已验**：用 Codex 包里自带的 bwrap 做外层（`--ro-bind / /`，白名单根与 `CODEX_HOME` 可写，`/tmp` 私有，不分离网络），内层 Codex 沙箱照常工作；不能用系统 `/usr/bin/bwrap`（Ubuntu 的 AppArmor 配置禁止其子进程再建命名空间），也不能用 Landlock（它禁止内层 mount）。见 `runtime/probe/REPORT-2026-09-24-outer-sandbox.md`。macOS 用 sandbox-exec（未验）；Windows（第一期首个用户平台）开工前先探（Codex 用受限令牌加独立沙箱账号，需一次提权初始化） | 硬上限：不依赖协议解析，Codex 升版也不失效；`fs/*`、`http/request`、`process/*` 一并盖住 |
| 协议过滤（桥内） | 出站桥解析 exec-server JSON-RPC：`process/start` 的沙箱意图高于上限、cwd 或 roots 在白名单外、`fs/*` 路径在白名单外、`http/request` 与 `network/policyRequest` 越出策略 → 直接回错误，不转发 | 干净的拒绝与可观测（`AT-09`）；抬高上限的弹窗就挂在这里 |

推论：不能用 Codex 自带的 `--remote`/noise 加密注册模式让沙箱直连执行端（桥看不见协议就过滤不了）；③ 在桥内是明文 JSON-RPC，加密由④⑤的 WSS 承担。

## key 的走向

```text
用户在网页录入 key ──HTTPS──▶ 工作台 ──▶ 密钥库（k8s Secret / Vault）
                                              │ 沙箱启动时注入进程环境
                                              ▼
                                        app-server ──HTTPS──▶ 模型厂商
```

用户可撤换；撤换后重启该用户的沙箱。不接受订阅登录搬上云端。国产厂商 key 走 `model_provider` 配置，同一条路。

## 令牌

| 令牌 | 签发给 | 携带 | 验证 |
| --- | --- | --- | --- |
| 浏览器会话 | 用户 | Casdoor OIDC | 工作台 |
| 代理令牌 | 用户 | JWT：`aud=relay`、`sub`（会合点用户名）、`role=agent`、`jti`、`exp` | 会合点用工作台公钥就地验；工作台签发 |
| 沙箱令牌 | 用户 + 沙箱 | JWT：`aud=relay`、`sub`、`role=sandbox`、`sandbox`、`jti`、`exp` | 同上 |
| frp 令牌 | 内网站点的 frpc | 共享密钥，≥32 字符，TLS 内传输 | 边缘 frps；边缘在 systemd 环境文件（0600），内网在 Secret；定期换（topology「边缘到内网」） |
| MCP token | 用户 + 沙箱 | JWT：`aud=knowledge`、`sub`、`sandbox`、可选 `tools`、`jti`、`exp` | 知识服务用同一把公钥就地验 |

**形制（`D10`，2026-09-25 定）**：ES256（P-256）签名，`iss=sunmoon-workbench`，`kid` 为公钥指纹；私钥只在工作台 Secret（`WORKBENCH_TOKEN_SIGNING_KEY`），公钥经 `GET /api/workbench/token-keys`（JWKS）与管理通道 `set_public_key` 到边缘、经 Secret 到知识服务。有效期 90 天——不是浏览器会话，是设备/沙箱级凭据，撤换靠吊销不靠短期。没配私钥时退回不透明随机令牌（会合点靠登记表配对）。
**吊销传播**：工作台在撤换时把旧 `jti` 经管理通道推到会合点（`revoke_jti`），会合点内存持有并落状态文件；按用户吊销（`revoke`）对 JWT 同样生效直到重新登记。推送失败时令牌到期自然失效（`F-RELAY-06`）。知识服务不收吊销推送：撤换会重签 MCP 令牌并滚动沙箱，旧的随沙箱一起消失。

## 账号与注册（2026-09-26 所有者定）

真实用户**自助注册**，第一期加三道闸；配额与计费就绪后去掉邀请码即全开。账号在 Casdoor 的 `sunmoonai` 组织里，只有投资网页（`sunmoonai-investment-web`）开注册；管理端与 info、knowledge 各应用照旧关闭。

| 闸 | 定法 | Casdoor 3.42 里怎么落 |
| --- | --- | --- |
| 邀请码 | 注册必须填；码由所有者在 Casdoor 后台发，每个码设可用次数（`quota`），可绑定到某个邮箱；用尽或停用即失效 | 应用的注册项 `Invitation code` 设为必填；`invitation` 对象（`code`、`quota`、`usedCount`、`application`、可选 `email`、`state`） |
| 邮箱验证 | 注册时向邮箱发验证码，填对才建号；登录可用用户名或邮箱（Casdoor 按用户名、邮箱、手机号依次匹配，已核源码）。同一地址 60 秒内只发一次（Casdoor 自带） | 注册项 `Email` 设为必填、规则为发验证码（非 `No verification`）；应用挂一个邮件（SMTP）提供方。当前用腾讯云邮件推送的 SMTP，企业邮箱走同一接口（`D20` 已定） |
| 手机号（留接口） | 第一期不收；合规若要求实名（手机号）再开，不改代码 | 注册项 `Phone` 现在隐藏；开时设为必填、规则为发验证码，应用挂短信提供方（需企业短信签名） |
| 人机校验 | 从公网来的请求要过图形验证码（登录与发验证码都是）；内网与本机来的不要，免得挡住集群内的测试脚本 | 应用挂 Casdoor 自带的 `provider_captcha_default`，规则 `Internet-Only`（可配成 `Always`）。上边缘后 Casdoor 看到的客户端地址取决于转发头，上线前要核 |

另外关掉 Casdoor 自带应用 `app-built-in` 的注册：它默认开着，任何人都能注册进 `built-in` 组织，也就是 Casdoor 自己的管理组织。

配套的资源闸在工作台，不在 Casdoor：一人一个沙箱（已做，`F-SBX-01`）；**全局沙箱上限**（`F-SBX-08`，已做，默认 20）；登记了模型 key 才能拉起沙箱（已做）。

这些都写进平台的 Casdoor 初始化脚本，不在后台手点；SMTP 口令进 Secret，不进 git。

**实现状态（2026-09-26）**：`auth-app/casdoor/deploy-casdoor/signup-setup.sh`，由 `post-deploy-setup.sh` 第六步调用；配置项见 `post-deploy-setup.local.conf.example` 的「自助注册」段。**没配邮件服务时注册保持关闭**（邮箱要验证码，开着只会让人卡在发码那一步）。在本机用真实的 Casdoor 3.42.0 + PostgreSQL + 本地收信服务（TLS）跑通：缺邀请码、错邀请码、缺邮箱码、错邮箱码都被拒；验证码邮件按配置的发信人、标题、正文送达；正确注册后账号进 `sunmoonai`、邮箱标记已验证、邀请码计数；额度用尽后拒绝（"Invitation code exhausted"）；用大小写混写的邮箱能登录；经 `app-built-in` 注册被拒；重跑不清零已用次数；手机号开关与各种错配置都有明确报错。没有用真实的腾讯云邮件推送发过信（服务未开通）。

发现（未处理）：本脚本用 SQL 直接建的应用没有 `signin_methods`，Casdoor 会拒绝这些应用的密码登录（"login with password is not enabled"）。KIND 里的投资网页能登录，说明那里的应用另有来源；在新环境里用本脚本从零建应用时，要补上登录方式，上线前核。

## 不再守的

资料保密、结果保密、后端不可读、设备身份证明、"让用户能验证"。这些是隐私约束的产物，随约束一起退役。
