# 工作台服务流（service-v1）

设计真源：`sunmoonai/docs/dev-investment-agent/tree-build/SDD/modules/0022-agent-service-channel.md`（账 87）。
会合点这一侧 2026-10-12 做完（`relay.py` 的 `/service`、`open.kind`、`capabilities`），代理侧（0.4.0）与工作台侧随后；现网会合点镜像未换，不能据此判断现网已支持。

## 会合点做什么

1. 代理控制通道 hello 可带 `capabilities: ["service-v1", …]`；会合点原样记下，`/admin` 的 `agents` 回包里带 `capabilities`。
2. 工作台出站到 `/service`，hello `role=workbench`（不带 `codex`），令牌与其它角色同一套验法（JWT 就地验签，或静态表里的 `workbench` 键）。
3. 找该用户在线的代理：没有 → `agent offline`；其 `capabilities` 不含 `service-v1` → `agent has no service channel`；服务流已达 `RELAY_MAX_SERVICE_STREAMS_PER_USER`（默认 2）→ `too many service streams`。
4. 向代理控制通道发 `{"type":"open","conn":ID,"kind":"service"}`；代理像沙箱流一样开 `/agent-data?conn=ID`，但把这条流接到自己的服务处理器，不接 exec-server。沙箱流的 `open` 没有 `kind`。
5. 配对后向工作台回 `welcome`（带 `conn` 与 `kind:"service"`），之后逐帧透传；单帧超过 1 MiB 关流（1009），不透传。
6. 服务流计数与沙箱流分开；`RELAY_PROTOCOL` 不变。

## 会合点不做什么

不解析 JSON-RPC 正文、不限速请求数（代理那头限）、不检查 Codex 版本成对。
