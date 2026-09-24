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

## 平台

第一期 Linux 与 macOS。Windows 第二期，已探明可做（`runtime/probe/REPORT-2026-09-24-windows-exec-server.md`）：exec-server 原生可跑、`workspace-write` 挡得住；安装器要含一次 UAC 提权跑 `codex sandbox setup --elevated --current-user`；随包带原生 exe 而不是 npm 垫片；回环端口动态选（47001 会被 Cursor 之类占）；Defender + 火绒样本未拦。Windows 上外沙箱的实现待探。

## 本地上限由谁挡

已定（探针 2026-09-23）：exec-server 不挡，代理挡，两层：OS 级外沙箱包住 exec-server 进程，加出站桥内的协议过滤。细节见 [安全](../architecture/security.md)「本地上限」。

## 探针已知

本地上限：执行端 `config.toml`/`requirements.toml` 不限制编排端要求（`probe/REPORT-2026-09-23-local-ceiling.md`）。exec-server 可远端执行、可改本地文件、沙箱在 executor 侧生效、审批请求带 `environmentId`、stdin 关闭即退出（须 `setsid … < /dev/null`）、listen 模式无认证。见 `runtime/probe/REPORT-2026-09-23-remote-exec.md`。

## 不做

驱动完整 Codex；本地知识库；加密；设备密钥；桌面窗口以外的任何界面。
