# `0004-relay` 会合点

> 边缘上唯一的自研组件。三类出站客户的认证、配对、透传。无状态。

## 做什么

```text
本地代理 ──WSS 出站──▶ 会合点 ◀──WSS 出站── 沙箱出站桥
                          │ 按 sub 配对，透传字节流（Codex 远端环境协议）
内网站点 ──WSS 出站──▶ 会合点 ◀── HTTPS ── 浏览器（/api/ /auth/ /mcp/ 经隧道到内网）
```

## 协议

| 帧 | 谁发 | 内容 |
| --- | --- | --- |
| `hello` | 客户 | 令牌、客户类型（agent / sandbox / site）、协议版本、软件版本 |
| `welcome` / `reject` | 会合点 | 配对结果或拒绝原因（令牌、版本不匹配） |
| `bind` | 会合点 | 通知双方已配对；之后为透传 |
| `ping` / `pong` | 双方 | 心跳；超时即断 |

配对规则：沙箱 `hello` 里的 `sub` 与代理 `hello` 里的 `sub` 一致，且两者版本成对（`AT-28`）；一个代理同一时刻只被一个沙箱绑定。

## 功能义务

| ID | 义务 |
| --- | --- |
| `F-RELAY-01` | 令牌用工作台公钥就地验；不回源、不查库 |
| `F-RELAY-02` | 无持久状态；重启后客户重连即恢复（`AT-22`） |
| `F-RELAY-03` | 只透传，不解析 Codex 协议正文 |
| `F-RELAY-04` | 版本不成对拒绝并回原因，不静默降级 |
| `F-RELAY-05` | 按用户限连接数与带宽；异常断连率上报 |
| `F-RELAY-06` | 吊销列表由工作台推送，会合点内存持有；推送失败时令牌到期自然失效 |
| `F-RELAY-07` | 多站点：站点令牌带 `site_id`；用户到站点的映射由工作台下发；第一期单站点 |

## 部署

边缘 VM 上与 Traefik 同机；无卷。第一期单实例；水平扩展靠无状态。

## 探针已知

回环透传成立（`runtime/probe/REPORT-2026-09-23-relay-passthrough.md`；原型 `relay_dumb.py`、`agent_bridge.py`、`sandbox_bridge.py`）。每 turn 约 45 个串行 JSON-RPC 来回，九成是 `fs/getMetadata`，所以**边缘必须与用户同区域**；跨境边缘不成立。Codex 自带一套 rendezvous（`exec-server --remote`，HTTP 注册 + protobuf 多路复用 + 续传 + noise 加密），第一期不兼容（`D17`）。

## 待定

`D10` 令牌形制与吊销；`D16` 仓位置；`D17` 兼容 Codex rendezvous。公网延迟未验。
