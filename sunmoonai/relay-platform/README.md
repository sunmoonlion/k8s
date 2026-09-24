# relay-platform：会合点（0004-relay）

边缘上唯一的自研组件：三类出站客户（本地代理、沙箱、内网站点）的认证、配对、透传。无状态。
设计见 [`../docs/dev-investment-agent/tree-build/SDD/modules/0004-relay.md`](../docs/dev-investment-agent/tree-build/SDD/modules/0004-relay.md)。

| 目录 | 内容 |
| --- | --- |
| `relay/relay.py` | 会合点 v1：`/agent`（代理控制）、`/agent-data?conn=`（代理数据流）、`/sandbox`（沙箱流）、`GET /healthz` |
| `relay/tests/test_relay.py` | 10 个行为测试（配对、透传、坏令牌、协议版本、版本成对、代理离线、跨用户、超时、替换、健康） |
| `relay/requirements.txt` | `websockets` |
| `relay/Dockerfile` | python 3.12 slim |
| `resources/relay.yaml` | 边缘上的 Deployment + Service（Traefik 路由另配） |

## 协议 v1

两端第一帧都是 hello：

```json
{"type":"hello","proto":1,"role":"agent|sandbox","user":"<user>","token":"<token>","codex":"0.155.1","software":"sunmoon-agent/0.1.0","conn":"<仅数据流>"}
```

会合点回 `{"type":"welcome",...}` 或 `{"type":"reject","reason":...}`；沙箱连上时会合点向代理控制通道发 `{"type":"open","conn":ID}`，代理开 `/agent-data?conn=ID`，配对后逐消息透传。
拒绝条件：坏令牌、协议版本不符、代理离线、**两端 Codex 版本不一致**、代理没在 15 秒内开流、每用户流数超限。

## 令牌（第一期）

静态令牌表，环境变量 `RELAY_TOKENS_JSON` 或文件 `RELAY_TOKENS_FILE`：

```json
{"<user>": {"agent": "<代理令牌>", "sandbox": "<沙箱令牌>"}}
```

工作台签发、公钥就地验的 JWT 是 `D10`，第一期不做。令牌不进日志。

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

`D10` 令牌形制与吊销；`D17` 是否兼容 Codex 自带 rendezvous；公网延迟实测；按用户限带宽（`F-RELAY-05` 只做了流数）。
