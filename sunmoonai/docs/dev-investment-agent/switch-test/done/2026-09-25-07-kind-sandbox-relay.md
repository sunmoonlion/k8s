# KIND：沙箱 pod 与会合点进集群，本地代理连上，网页走通一条 SMOKE 委托（本地机，要 KIND、Harbor、Docker）

```text
被测仓：k8s，本地路径 ~/worktrees/fable/k8s（还要 runtime：本地代理）
跑：按下面编号步骤做
仓与提交：k8s 本条待办所在的 fable 头；runtime 60120a5 或更新；investment-app 含子仓 investment-backend 的 workbench_register 提交（06 B 段部署的镜像必须已含它，否则第 6 步没有该命令）
预计：40 分钟；要联网（Kimi）；要 Docker、KIND、Harbor；要 ~/.codex-probe-kimi/auth.json 里的 Kimi key
看什么：第 5 步沙箱 pod Running 且日志有 listening on；第 7 步代理日志 relay connected；第 8 步网页里机器与沙箱下拉有值；第 9 步委托到 SUCCEEDED
前提：06 B 段已部署（runner Running）；04 已 pass（镜像在本机能跑）
回传：k8s/sunmoonai/scripts/results/kind-sandbox-relay.<时间>.md
```

## 步骤

1. 推两个镜像进 KIND Harbor：
   `cd ~/worktrees/fable/k8s/sunmoonai/sandbox-platform && docker build --build-arg NODE_IMAGE=harbor.sunmoonai.com:30443/k8s-images/node:24.18.0-alpine@sha256:4ba75f835bb8802193e4c114572113d4b26f95f6f094f4b5229d2a77773e0afc -t harbor.sunmoonai.com:30443/app-images/sandbox:0.155.1-r1 -f image/Dockerfile . && docker push harbor.sunmoonai.com:30443/app-images/sandbox:0.155.1-r1`
   `cd ../relay-platform/relay && docker build -t harbor.sunmoonai.com:30443/app-images/relay:v1-r1 . && docker push harbor.sunmoonai.com:30443/app-images/relay:v1-r1`
   记下两个 RepoDigests。
2. 把 digest 写进清单（C-R2 只允许 digest）：`sandbox-platform/resources/demo-user.yaml` 与 `relay-platform/resources/relay.yaml` 里 `REPLACE_WITH_BUILT_DIGEST` 换成实际值。这两个文件改动留在工作区回传。
3. 令牌与 key（都不进 git、不进回传）：
   ```bash
   export KUBECONFIG=~/.kube/kind-config
   AGENT_TOKEN=$(head -c 32 /dev/urandom | base64 | tr -d '=+/'); SANDBOX_TOKEN=$(head -c 32 /dev/urandom | base64 | tr -d '=+/'); APP_TOKEN=$(head -c 32 /dev/urandom | base64 | tr -d '=+/')
   kubectl create ns edge; kubectl -n edge create secret generic relay-tokens --from-literal=tokens.json="{\"demo\":{\"agent\":\"$AGENT_TOKEN\",\"sandbox\":\"$SANDBOX_TOKEN\"}}"
   kubectl apply -f ~/worktrees/fable/k8s/sunmoonai/sandbox-platform/resources/demo-user.yaml   # 先建 namespace（带标签）
   kubectl -n sandbox-pool create secret generic sandbox-demo-relay --from-literal=token="$SANDBOX_TOKEN"
   kubectl -n sandbox-pool create secret generic sandbox-demo-model-key --from-literal=key="$(python3 -c "import json;print(json.load(open('$HOME/.codex-probe-kimi/auth.json'))['OPENAI_API_KEY'])")"
   kubectl -n sandbox-pool create secret generic sandbox-demo-app-server --from-literal=token="$APP_TOKEN"
   kubectl -n app-platform-dev create secret generic sandbox-demo-app-server --from-literal=token="$APP_TOKEN"   # 同一个值给工作台 runner
   echo "$AGENT_TOKEN" > ~/private/demo-agent-token && chmod 600 ~/private/demo-agent-token; unset AGENT_TOKEN SANDBOX_TOKEN APP_TOKEN
   ```
4. `kubectl apply -f ~/worktrees/fable/k8s/sunmoonai/relay-platform/resources/relay.yaml`；`kubectl -n edge get pods` 应 Running；`kubectl -n edge get svc relay-nodeport` 应有 30471。
5. `kubectl -n sandbox-pool get pods -w`：sandbox-demo Running；`kubectl -n sandbox-pool logs deploy/sandbox-demo | grep -v sk-` 里有 `listening on: ws://0.0.0.0:47800` 和桥的 `paired`/`connected`（会合点侧 `kubectl -n edge logs deploy/relay` 也有 sandbox 连入）。
6. 让 runner 拿到令牌：`kubectl -n app-platform-dev rollout restart deploy/investment-backend-runner`（Secret 是可选引用，重启后才注入）。然后登记机器与沙箱（先在浏览器登录一次 `https://investment.sunmoonai.com:30443`，用你平时的账号）：
   `kubectl -n app-platform-dev exec deploy/investment-backend-api -- python -m app.cli.workbench_register --email <你登录用的邮箱> --environment-name this-pc --root /home/zymun/research --sandbox-url ws://sandbox-demo.sandbox-pool.svc:47800 --token-ref env:SANDBOX_DEMO_APP_SERVER_TOKEN`
   应打印一行 JSON 含 environment_id 与 sandbox_id。`--root` 用 WSL 里真实存在的目录（先 mkdir）。
7. 本地代理（WSL）：取 KIND 节点 IP `NODE_IP=$(kubectl get node kind-control-plane -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')`，然后
   `cd ~/worktrees/fable/runtime && SUNMOON_AGENT_HOME=~/.sunmoon-agent-kind node agent/dist/cli.js init --relay ws://$NODE_IP:30471 --user demo --token "$(cat ~/private/demo-agent-token)" --root /home/zymun/research && SUNMOON_AGENT_HOME=~/.sunmoon-agent-kind node agent/dist/cli.js start`
   日志应有 `relay connected`；`kubectl -n edge logs deploy/relay` 应有 agent control up user=demo。前台跑着别关。
8. 浏览器 `https://investment.sunmoonai.com:30443/zh-CN/workbench`：新建会话（机器 this-pc、沙箱 ws://sandbox-demo…、项目目录 /home/zymun/research 下一个子目录）→ 会话页时间线出现「Codex 会话已建立」。
9. 输入框：`在当前目录写一个 hello.txt，内容 hello，然后 cat 它` → 时间线出现命令与回答，WSL 目录里出现文件。然后「问专家」→ SMOKE、预算 5 → 委托卡走到 SUCCEEDED → 「打开底稿」能看到结果与结论草稿框。
10. 回传：每步做到没有与屏幕内容；`kubectl -n sandbox-pool logs deploy/sandbox-demo --tail=30 | grep -v sk-`；`kubectl -n app-platform-dev logs deploy/investment-backend-runner --tail=40`；代理日志末 20 行。

失败停在那步。第 5 步 pod 起不来常见原因：镜像 digest 没换、Secret 名不对、NetworkPolicy 挡了 443（看 `kubectl -n sandbox-pool describe pod`）。
