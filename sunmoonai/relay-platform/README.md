# relay-platform：会合点（0004-relay）

边缘上唯一的自研组件：三类出站客户（本地代理、沙箱、内网站点）的认证、配对、透传。无状态。
设计见 [`../docs/dev-investment-agent/tree-build/SDD/modules/0004-relay.md`](../docs/dev-investment-agent/tree-build/SDD/modules/0004-relay.md)。

| 目录 | 内容 |
| --- | --- |
| `relay/relay.py` | 会合点 v1：`/agent`（代理控制）、`/agent-data?conn=`（代理数据流）、`/sandbox`（沙箱流）、`GET /healthz` |
| `relay/tests/test_relay.py` | 28 个行为测试：配对、透传、坏令牌、协议版本、版本成对、代理离线、跨用户、超时、替换、健康、管理通道；同一套再跑在 JWT 上，加 JWT 拒绝矩阵与吊销 |
| `relay/requirements.txt` | `websockets`、`cryptography`（验 ES256） |
| `relay/Dockerfile` | python 3.12 slim |
| `resources/relay.yaml` | 边缘上的 Deployment + Service（Traefik 路由另配） |

## 协议 v1

两端第一帧都是 hello：

```json
{"type":"hello","proto":1,"role":"agent|sandbox","user":"<user>","token":"<token>","codex":"0.155.1","software":"sunmoon-agent/0.1.0","conn":"<仅数据流>"}
```

会合点回 `{"type":"welcome",...}` 或 `{"type":"reject","reason":...}`；沙箱连上时会合点向代理控制通道发 `{"type":"open","conn":ID}`，代理开 `/agent-data?conn=ID`，配对后逐消息透传。
拒绝条件：坏令牌、协议版本不符、代理离线、**两端 Codex 版本不一致**、代理没在 15 秒内开流、每用户流数超限。

## 管理通道（工作台动态登记）

`/admin`：第一帧 `{"type":"hello","role":"admin","token":<RELAY_ADMIN_TOKEN>}`，通过后发
`{"type":"set_tokens","user":U,"agent":A,"sandbox":S}`、`{"type":"revoke","user":U}`、`{"type":"list"}`、
`{"type":"set_public_key","pem":PEM}`、`{"type":"revoke_jti","jtis":[...]}`；每条回 `ok|error|tokens`。
撤销会关掉该用户在线的代理，且对该用户的 JWT 也拒到重新 `set_tokens` 为止；`revoke_jti` 会当场断开用被吊销令牌在线的代理（4003，代理收到后不再重连）。登记、公钥、吊销表都写 `RELAY_TOKENS_STATE`（emptyDir），重启回读；静态表里的同名用户以静态为准。
工作台在每次拉起沙箱时先推公钥再重新登记，会合点换机器也能收敛。

## 令牌（D10）

两种共存：

1. **工作台签发的 JWT**（正式）：三段式、ES256。会合点有公钥（`RELAY_JWT_PUBLIC_KEY`，或管理通道推来）时就地验签：`aud=relay`、`sub` = hello 的 `user`、`role` = 路径角色（agent/sandbox）、`exp` 未过、`iss` 匹配（配了 `RELAY_JWT_ISSUER` 时）、`jti` 不在吊销表、用户不在按用户吊销表。不回源、不查表。
2. **静态/登记表**（退路，没公钥时或非 JWT 令牌）：环境变量 `RELAY_TOKENS_JSON` 或文件 `RELAY_TOKENS_FILE`：

```json
{"<user>": {"agent": "<代理令牌>", "sandbox": "<沙箱令牌>"}}
```

令牌不进日志。公钥生成见 investment-backend `app.cli.workbench_token_keys`。

## 跑与测

```bash
cd sunmoonai/relay-platform/relay
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
RELAY_HOST=0.0.0.0 RELAY_PORT=47100 RELAY_TOKENS_JSON='{"local":{"agent":"a","sandbox":"s"}}' .venv/bin/python relay.py
.venv/bin/python -m unittest tests/test_relay.py
```

## 边缘上的位置

Traefik 把 `wss://edge.example.com/relay/*` 转到本服务；同一台边缘还放网页静态产物与 `/api/` 隧道入口（`topology.md`）。边缘无状态：换机器只要令牌表一致。

## 待办

`D17` 是否兼容 Codex 自带 rendezvous；按用户限带宽（`F-RELAY-05` 只做了流数）；多站点（`F-RELAY-07`）。
