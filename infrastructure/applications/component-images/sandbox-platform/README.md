# 沙箱与供给器镜像源码（0003-sandbox）

每用户一个 pod：钉版 `codex app-server`（模型循环，BYOK）+ 沙箱侧出站桥（到会合点）。设计见
[`docs/design/SDD/modules/0003-sandbox.md`](../../../../docs/design/SDD/modules/0003-sandbox.md)。

| 目录 | 内容 |
| --- | --- |
| `image/` | `Dockerfile`（node 22 + python3 + `@openai/codex@0.155.1`）、`entrypoint.sh`（生成 `config.toml`/`environments.toml`，起桥，前台起 app-server） |
| `bridge/` | `sandbox_bridge.py`：回环 `ws://127.0.0.1:47002` ↔ 会合点 `/sandbox`，第一帧 hello |
| `provisioner/` | `provisioner.py`：沙箱供给器（FastAPI）——按用户建/查/删沙箱，直接调 API server；`tests/` 对假 API server 验 |

## 进程与端口

```text
pod
├── codex app-server --listen ws://0.0.0.0:47800 --ws-auth capability-token --ws-token-file /secrets/app-server/token   ← 工作台（唯一客户端）
│     CODEX_HOME=/data/codex（PVC）：config.toml、environments.toml（default=user-pc → ws://127.0.0.1:47002，include_local=false）、auth.json（BYOK）
└── sandbox_bridge.py  127.0.0.1:47002 ──出站──▶ 会合点 /sandbox（hello: user、token、codex 版本）
```

## key 怎么进去

- `OPENAI_API_KEY` 由 Secret 注入进程环境；入口脚本把它写成 `$CODEX_HOME/auth.json`（600）后从环境里 `unset`；
- 国产厂商：再给 `MODEL_PROVIDER`、`MODEL`、`PROVIDER_BASE_URL`（`wire_api` 默认 `responses`；Kimi 已验）；
- 没有 key 拒绝启动：不垫付 token 是硬杠。

## 构建与部署

构建：`make -C infrastructure platform-build OBJECT=sandbox-platform/sandbox`、`OBJECT=sandbox-platform/provisioner`（配置见上一级 [component-images.yaml](../../component-images.yaml)，产物发到 Harbor `platform/`，锁写进 `gitops/components/sandbox-platform/<对象>/image.lock.yaml`）。部署：供给器由 [`gitops/components/sandbox-platform/provisioner/`](../../../../gitops/components/sandbox-platform/provisioner) 声明；沙箱不单独部署，由供给器按用户拉起。

## 按需拉起（供给器）

工作台 `POST /api/workbench/sandboxes/provision`：取用户设置页登记的 key → 签发该用户的会合点身份并经 `/admin` 登记到会合点 →
`PUT sandbox-provisioner:8080/sandboxes/<relay_user>`（Bearer 共享令牌）→ 供给器建 Secret（key、会合点令牌、能力令牌）、PVC、
Deployment、Service、NetworkPolicy → 工作台把 `app_server_url` 与能力令牌登记为该用户的沙箱。再次调用是更新（换 key），
能力令牌不变，PVC 不动；`DELETE` 回收运行资源，PVC 保留（`?purge=1` 才删）。一用户一个沙箱。

供给器单测：

```bash
cd infrastructure/applications/component-images/sandbox-platform/provisioner && python3 -m pytest tests -q
```

## 已知与待办

- 版本成对：镜像里的 Codex 版与本地代理随包带的版必须一致，会合点在 hello 里核对（`AT-28`）；
- `D9`：按需拉起已由供给器实现（一用户一个，PVC 保留）；`CODEX_HOME` 备份（D18）与配额未做；
- 多会话共用一个 exec-server 未验；冷启动时间未测。
