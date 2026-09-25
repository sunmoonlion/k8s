# `0005-agent` 本地代理

> 用户机器上唯一要装的东西。映射 `runtime` 仓。包 `codex exec-server`，出站连会合点，守本地上限。不跑模型循环，不接触 key。

## 一个代理里有什么

```text
本地代理（常驻，签名分发）
├── 外沙箱（Linux：随包带的 bwrap，`--ro-bind / /` + 白名单根可写 + `/tmp` 私有；macOS：sandbox-exec，未验）
│   └── codex exec-server --listen ws://127.0.0.1:PORT（钉版，随包带）
│         内层 Codex 沙箱照常（Linux: bwrap+seccomp；macOS: seatbelt）
│     白名单变更 = 重启 exec-server（bind 在启动时定）
├── 出站桥：WSS 到会合点；把隧道流量转到 127.0.0.1:PORT
├── 弹窗：本地上限变更的当面确认；结论经⑧回工作台
├── 登录：一次浏览器 OIDC 取代理令牌；之后自动续签
└── 状态：托盘或菜单栏；白名单管理；版本
```

## 功能义务

| ID | 义务 |
| --- | --- |
| `F-AGENT-01` | exec-server 只绑 `127.0.0.1`；唯一入口是出站桥 |
| `F-AGENT-02` | 根目录白名单由用户在本机维护；工作台只读它的摘要 |
| `F-AGENT-03` | 本地上限：沙箱要求高于上限的模式、白名单外的根、放开网络，一律拒绝并上报（`I13`、`AT-09`） |
| `F-AGENT-04` | 抬高上限只经本机弹窗，仅当前 Session 有效；变更带请求摘要上报 |
| `F-AGENT-05` | 版本成对：`hello` 带 Codex 版与代理版；不匹配时提示用户更新，不静默降级 |
| `F-AGENT-06` | 断连自动重连；重连必须接回**同一个** exec-server 进程（会话 id 在其内存里，25 秒窗内无损）；代理不得因断连重启 exec-server；代理自身重启即会话全丢，须上报 |
| `F-AGENT-07` | 不持有、不转发、不缓存用户 key（`I8`） |
| `F-AGENT-08` | 勾选上送：用户勾选的文件上送知识服务（第一期显式） |
| `F-AGENT-09` | 关掉界面仍在跑；开机自启可选 |
| `F-AGENT-10` | 执行端 `CODEX_HOME` 是代理自己的 `~/.sunmoon-agent/codex-home`，与用户的 `~/.codex` 隔离，**不含任何凭据**（外沙箱把它挂成可写，云端能读到里面的一切）；从用户 `~/.codex/config.toml` 只合并 `[mcp_servers]` 里 HTTP 型的条目，合并前本机确认并列出条目；模型、审批、沙箱偏好、全局 skills 一概不读（探针 `REPORT-2026-09-24-skills-mcp-resolution.md`） |

## 实现状态（2026-09-24）

`runtime/agent/`（`@sunmoon/agent` 0.1.0，TypeScript）：exec-server 守护（Linux 外沙箱 = 随包 bwrap）、出站桥（会合点协议 v1）、协议过滤（`process/start`、fs 写、`http/request`）、CLI `init|roots|ceiling|start|status`；27 个单元测试；一机与容器形态联调 pass。未做见 `runtime/CHECKPOINT.md`：弹窗、令牌签发、macOS 外沙箱、Windows 启动、勾选上送、网络硬禁。

## 平台

**第一期做 Windows，它是第一个面向用户的平台**（所有者 2026-09-26 定：目标用户是投资经理，国内大多用 Windows）。顺序：

| 顺序 | 平台 | 角色 | 现状 |
| --- | --- | --- | --- |
| 1 | Linux / WSL | 开发与联调用（本地 KIND 就跑在这上面），也给会用命令行的用户 | 已跑通，外沙箱已验 |
| 2 | **Windows 10/11** | 第一个面向用户的平台 | exec-server 原生可跑、`workspace-write` 挡得住（`runtime/probe/REPORT-2026-09-24-windows-exec-server.md`）；外沙箱与无管理员权限两件未探 |
| 3 | macOS | 其次 | sandbox-exec 外层未验 |
| 后置 | 信创 | — | — |

Windows 已知要做的：安装器含一次 UAC 提权跑 `codex sandbox setup --elevated --current-user`；随包带原生 `codex.exe`，不用 npm 垫片；回环端口动态选（47001 会被 Cursor 之类占）；`.ps1` 用带 BOM 的 UTF-8；进程清理用 `taskkill /T`；Defender + 火绒样本未拦（一台，不外推）。

Windows 开工前先探两件，都是上线门：

1. **没有管理员权限的办公机**（评审提出：国内投研终端常被锁定）。探 Codex 的非提权沙箱模式在执行端能否挡住白名单外写入；挡得住，就给这类机器一条"免提权安装"的路，功能相同、边界由非提权模式加桥内协议过滤共同守；挡不住，就明确写"需要管理员装一次"，由用户的 IT 装，不做降级放行。
2. **外沙箱**：能否把 exec-server 进程本身包进受限令牌或独立沙箱账号（Linux 上 bwrap 那一层的对等物）。做不到时，本地上限只剩桥内协议过滤一层，需在安全文档里写明并由所有者接受。

## 分发与安装

用户机器上只装一个东西，不要求装 Node、Python、Git。

| 块 | 定法 | 现状 |
| --- | --- | --- |
| 打包 | 单文件程序：Node 运行时 + 代理代码 + 钉版 `codex` 原生执行文件（Linux 另带 bwrap），按平台出包 | 未做；现在要 Node ≥20 + 源码编译 |
| 安装包 | Windows：签名安装器（每用户安装，提权只用于沙箱初始化那一步），代码签名证书；Linux：tar 包 + 安装脚本（systemd 用户服务），可加 deb；macOS：签名并公证的 pkg | 未做 |
| 首次登录 | 装完弹浏览器，用网站账号登录；工作台签发代理令牌（`D10` 已有签发与撤换），代理存进系统凭据库（Windows 凭据管理器 / Keychain / libsecret），不再让用户复制带令牌的命令 | 签发已做，登录流程未做 |
| 目录白名单 | 托盘（Windows）/ 菜单栏（macOS）里勾选；命令行 `roots` 保留给 Linux | 只有命令行 |
| 开机自启 | Windows 计划任务（登录时，当前用户）；Linux systemd 用户服务；macOS launchd | 未做 |
| 自动更新 | 代理的 Codex 版本必须与沙箱成对（`AT-28`），我们升级 Codex 时代理必须能自己更新；更新包从边缘下载、验签后替换，失败回滚到旧版 | 未做 |
| 下载入口 | 网页设置页「下载本地代理」，按浏览器识别的系统给对应安装包 | 未做 |

顺序：先把 Linux/WSL 的打包与浏览器登录做出来（联调就用它），然后直接做 Windows 安装器，macOS 在其后。

## 三份 Codex，一个程序

`codex` 是一个二进制，子命令决定角色。用户机器上可能有他自己装的 `codex`（任意版本，家 `~/.codex`，与我们无关）和我们随代理带的 `codex exec-server`（0.155.1，家 `~/.sunmoon-agent/codex-home`，只执行、无凭据）；沙箱里是同版本的 `codex app-server`（家 `/data/codex`，用户的 key、我们的 skill 与 MCP 配置、thread 记录）。产品说的"同一实例"指沙箱里的同一个 thread。exec-server 只从家里读 `[mcp_servers]`，别的配置对它无效。

## 本地上限由谁挡

已定（探针 2026-09-23）：exec-server 不挡，代理挡，两层：OS 级外沙箱包住 exec-server 进程，加出站桥内的协议过滤。细节见 [安全](../architecture/security.md)「本地上限」。

## 探针已知

本地上限：执行端 `config.toml`/`requirements.toml` 不限制编排端要求（`probe/REPORT-2026-09-23-local-ceiling.md`）。exec-server 可远端执行、可改本地文件、沙箱在 executor 侧生效、审批请求带 `environmentId`、stdin 关闭即退出（须 `setsid … < /dev/null`）、listen 模式无认证。见 `runtime/probe/REPORT-2026-09-23-remote-exec.md`。

## 不做

驱动完整 Codex；本地知识库；加密；设备密钥；桌面窗口以外的任何界面。
