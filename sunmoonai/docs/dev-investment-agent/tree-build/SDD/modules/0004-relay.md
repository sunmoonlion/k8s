# `0004-relay` 会合点

> 边缘上唯一的自研组件。三类出站客户的认证、配对、透传。无状态。

## 做什么

```text
本地代理 ──WSS 出站──▶ 会合点 ◀──WSS 出站── 沙箱出站桥
                          │ 按 sub 配对，透传字节流（Codex 远端环境协议）
工作台 ──WSS 出站（/admin）──▶ 会合点：登记令牌、推公钥、吊销
（浏览器的 HTTP 进内网不经会合点，走 frp 隧道，见 topology「边缘到内网」）
```

## 协议

| 帧 | 谁发 | 内容 |
| --- | --- | --- |
| `hello` | 客户 | 令牌、客户类型（agent / sandbox）、协议版本、软件版本；管理通道另有 `role=admin` |
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
| `F-RELAY-07` | 多站点：用户到站点的映射由工作台下发，会合点按用户把沙箱配到该用户的代理；站点本身的 HTTP 入口由 frp 承担（2026-09-26 起不再有"站点"客户与站点令牌）；第一期单站点 |

## 部署

边缘 VM 上与 Traefik 同机；无卷。第一期单实例；水平扩展靠无状态。

## 实现状态（2026-09-24）

v1 在 `k8s/sunmoonai/relay-platform/relay/relay.py`：hello、静态令牌表、协议版本、两端 Codex 版本成对、按用户配对、逐消息透传、`/healthz`；10 个行为测试；Dockerfile 与边缘清单 `resources/relay.yaml`。一机与容器形态联调 pass（`runtime/scripts/results/integration-*.txt`）。未做：`D10` JWT、按用户限带宽、多站点。

## 探针已知

回环透传成立（`runtime/probe/REPORT-2026-09-23-relay-passthrough.md`；原型 `relay_dumb.py`、`agent_bridge.py`、`sandbox_bridge.py`）。每 turn 约 45 个串行 JSON-RPC 来回，九成是 `fs/getMetadata`，所以**边缘必须与用户同区域**；跨境边缘不成立。Codex 自带一套 rendezvous（`exec-server --remote`，HTTP 注册 + protobuf 多路复用 + 续传 + noise 加密），第一期不兼容（`D17`）。

## 待定

`D16` 仓位置；`D17` 兼容 Codex rendezvous。（`D10` 已定，公网延迟已测，见下。）

## 实现状态（2026-09-25）

`/admin` 管理通道：工作台用 `RELAY_ADMIN_TOKEN` 登记每用户的代理与沙箱令牌（`set_tokens`/`revoke`/`list`），登记结果落 `RELAY_TOKENS_STATE` 重启回读；撤销关掉在线代理。KIND 里加了 NodePort 30471 给宿主机上的代理。两机公网延迟已测（`runtime/probe/REPORT-2026-09-24-two-machine-latency.md`）：境外单跳每请求约 420 ms，边缘必须同区。

**D10 已做（2026-09-25）**：令牌是三段式且会合点有工作台公钥（`RELAY_JWT_PUBLIC_KEY` 或管理通道 `set_public_key` 推来、落状态文件）时就地验签（ES256、`aud=relay`、`sub=hello.user`、`role=` 路径角色、`exp`、可选 `iss`），不回源不查表（`F-RELAY-01`）；吊销按 `jti`（`revoke_jti`）与按用户（`revoke`）内存持有并落状态文件（`F-RELAY-06`）。静态表与登记表仍是没公钥时的退路，两种令牌共存。只多一个依赖 `cryptography`。测试 28（14 个配对测试在 JWT 上再跑一遍 + 拒绝矩阵 + 吊销与状态回读）。未做：限带宽、多站点（`F-RELAY-07`）。
