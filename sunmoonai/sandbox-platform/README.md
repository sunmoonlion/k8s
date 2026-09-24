# sandbox-platform：沙箱池（0003-sandbox）

每用户一个 pod：钉版 `codex app-server`（模型循环，BYOK）+ 沙箱侧出站桥（到会合点）。设计见
[`../docs/dev-investment-agent/tree-build/SDD/modules/0003-sandbox.md`](../docs/dev-investment-agent/tree-build/SDD/modules/0003-sandbox.md)。

| 目录 | 内容 |
| --- | --- |
| `image/` | `Dockerfile`（node 22 + python3 + `@openai/codex@0.155.1`）、`entrypoint.sh`（生成 `config.toml`/`environments.toml`，起桥，前台起 app-server） |
| `bridge/` | `sandbox_bridge.py`：回环 `ws://127.0.0.1:47002` ↔ 会合点 `/sandbox`，第一帧 hello |
| `resources/` | `demo-user.yaml`：第一期演示用户的常驻 pod（Deployment + PVC + Service + NetworkPolicy） |

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

## 构建与部署（第一期手工）

```bash
cd sunmoonai/sandbox-platform
docker build --build-arg NODE_IMAGE=harbor.sunmoonai.com:30443/k8s-images/node:24.18.0-alpine@sha256:4ba75f835bb8802193e4c114572113d4b26f95f6f094f4b5229d2a77773e0afc \
  -t harbor.sunmoonai.com:30443/app-images/sandbox:0.155.1-r1 -f image/Dockerfile .
# 基础镜像与平台其它镜像同一钉版（node 24.18.0 alpine，Harbor 里的 k8s-images 镜像）；外网机器不传 --build-arg 即从 Docker Hub 拉同一 tag
docker push harbor.sunmoonai.com:30443/app-images/sandbox:0.155.1-r1        # 取 digest 填进 demo-user.yaml（C-R2 只允许 digest）
kubectl create ns sandbox-pool
kubectl -n sandbox-pool create secret generic sandbox-demo-relay --from-literal=token=<会合点给该用户沙箱的令牌>
kubectl -n sandbox-pool create secret generic sandbox-demo-model-key --from-literal=key=<用户的厂商 key>
head -c 32 /dev/urandom | base64 | tr -d '=+/' > /tmp/t && kubectl -n sandbox-pool create secret generic sandbox-demo-app-server --from-file=token=/tmp/t && rm /tmp/t
kubectl apply -f resources/demo-user.yaml
```

工作台连 `ws://sandbox-demo.sandbox-pool.svc:47800`，握手带能力令牌（同一个 Secret 也要给工作台）。

## 本机怎么验（不进集群）

```bash
docker run --rm -e RELAY_URL=ws://host.docker.internal:47100 -e RELAY_USER=local -e RELAY_TOKEN=sandbox-secret \
  -e OPENAI_API_KEY=sk-... -e MODEL_PROVIDER=kimi -e MODEL=kimi-k3 -e PROVIDER_BASE_URL=https://api.moonshot.cn/v1 \
  -e APP_SERVER_TOKEN_FILE=/tmp/token -v /tmp/token:/tmp/token:ro -p 127.0.0.1:47800:47800 --add-host=host.docker.internal:host-gateway \
  harbor.sunmoonai.com:30443/app-images/sandbox:0.155.1-r1
```

## 已知与待办

- 版本成对：镜像里的 Codex 版与本地代理随包带的版必须一致，会合点在 hello 里核对（`AT-28`）；
- `D9`：常驻还是按需拉起、`CODEX_HOME` 用 PVC 还是对象存储；
- 多会话共用一个 exec-server 未验；冷启动时间未测。
