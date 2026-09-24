# `0003-sandbox` 沙箱池

> 内网 k8s 里每用户一个 `codex app-server` 进程。持有用户 key 的进程环境；不执行用户工具（工具在用户机器上，经③）。

## 一个沙箱里有什么

```text
pod（每用户）
├── codex app-server（钉版）── stdio/WS ──▶ 工作台（②）
│     CODEX_HOME=/data/codex   config.toml、environments.toml、会话记录
│     OPENAI_API_KEY / 国产厂商 key（从 Secret 注入进程环境）
├── 出站桥（sidecar）：把会合点隧道暴露成本地 ws://127.0.0.1:PORT，供 execServerUrl 指向
└── NetworkPolicy：只出站到会合点、知识服务、模型厂商
```

`environments.toml` 由工作台在 Session 建立时写入或经 `environment/add` 注册；`default` 指向该用户的环境；`include_local=false`。

沙箱 `CODEX_HOME` 里我们控制的还有：`config.toml` 的 `[mcp_servers.sunmoon]`（知识服务，token 经环境变量注入）与 `skills/sunmoon-data/`（怎么用我们的数据）。这两样随镜像版本发，入口脚本生成，不手改；用户的模型与审批偏好也写在这里，来源是网页设置页（`methods.md`「MCP 与 skills」）。

## 功能义务

| ID | 义务 |
| --- | --- |
| `F-SBX-01` | 每用户一个 pod；pod 之间不可互访；`CODEX_HOME` 不共享 |
| `F-SBX-02` | key 只以进程环境注入；不落镜像、不落日志；撤换后重启 pod |
| `F-SBX-03` | Codex 版本钉在镜像里，与代理版本成对；不匹配时拒绝 `environment/add` 并上报 |
| `F-SBX-04` | 执行环境不可达时不退回本地执行（`include_local=false`，`C-A12`） |
| `F-SBX-05` | 出站桥只接受该用户令牌配对的连接；令牌到期前续签 |
| `F-SBX-06` | 资源限额：内存与 CPU 上限；超限 OOM 时工作台看到断连并进 `SUSPENDED` |
| `F-SBX-07` | 沙箱不存 Task 真源；会话记录只作执行绑定与调试 |

## 实现状态（2026-09-24）

镜像 `k8s/sunmoonai/sandbox-platform/image/`（node 22 + `@openai/codex@0.155.1` + 桥），入口脚本生成 `config.toml`/`environments.toml`、把 `OPENAI_API_KEY` 落成 `auth.json` 后 unset、起桥、前台起 `app-server --listen ws://0.0.0.0:47800 --ws-auth capability-token`；桥 `bridge/sandbox_bridge.py`；演示用户清单 `resources/demo-user.yaml`（Deployment + PVC + NetworkPolicy）。容器形态联调 pass：工作台角色经 ws + 令牌连入，turn 经会合点到本机代理执行（`runtime/scripts/integration-sandbox-image.sh`）。镜像 1.38 GB，待瘦身。

## 第一期

一个演示用户的常驻 pod，手工部署清单。正式版按需拉起、PVC、配额（`D9`）。

## 探针已知

BYOK：key 以 `CODEX_HOME/auth.json`（`auth_mode="apikey"`）或 `OPENAI_API_KEY` 注入即可，Kimi K3 经 `model_providers.kimi`（`wire_api="responses"`）跑通远端环境、`apply_patch`、审批；每 turn 有 `thread/tokenUsage` 可入预算账。app-server 134 MB 常驻（本机测）；`environment/add` 与 `environment/status` 可用；25 秒恢复窗。未验：多会话共用一个 exec-server、冷启动时间。

## 实现状态（2026-09-25，按需拉起）

`sandbox-platform/provisioner/`：供给器（FastAPI，直接调 API server，RBAC 限 sandbox-pool）；`PUT/GET/DELETE /sandboxes/{user}`，一用户一个沙箱，Secret 含厂商 key、会合点令牌、能力令牌、知识 MCP 令牌，PVC 保留（D18 先"不删"），Secret 摘要进 pod 注解只在变化时滚动。工作台 `POST /api/workbench/sandboxes/provision` 把设置页登记的 key 解密后经内网送到供给器（所有者 2026-09-25 点头）。镜像基础改为平台钉版 node 24.18.0 alpine。未做：配额、按需缩容、CODEX_HOME 备份、按用户签发知识 MCP 令牌（D10，现共用）。
