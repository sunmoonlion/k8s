# KIND：沙箱按需拉起——供给器上线、会合点管理通道、从设置页拉起自己的沙箱（本地机）

```text
被测仓：k8s，本地路径 ~/worktrees/fable/k8s（还要 runtime：本地代理；investment-app 的 06 B 段部署必须已含 8a3505d 的后端与 46d792a 的网页）
跑：按下面编号步骤做
仓与提交：k8s 本条待办所在的 fable 头
预计：40 分钟；要 Docker、KIND、Harbor；要 Kimi key（用户在设置页录入）
看什么：第 6 步设置页「我的沙箱」从「还没有沙箱」变「启动中」再「运行中」，并出现一次代理接入命令；第 8 步会话页能用自动拉起的沙箱走一条 SMOKE 委托
前提：06 B 段（含 0010 迁移）已部署；07 已过（会合点在 edge、沙箱镜像已推）；08 可先不做（不用 DATA_QUERY 就不需要 MCP）
回传：k8s/sunmoonai/scripts/results/kind-sandbox-provisioning.<时间>.md
```

## 步骤

1. 供给器镜像：`cd ~/worktrees/fable/k8s/sunmoonai/sandbox-platform/provisioner && docker build -t harbor.sunmoonai.com:30443/app-images/sandbox-provisioner:v1-r1 . && docker push harbor.sunmoonai.com:30443/app-images/sandbox-provisioner:v1-r1`；取 digest，填进 `resources/provisioner.yaml` 的两个 `REPLACE_WITH_BUILT_DIGEST`（供给器自己的，和 07 已推的沙箱镜像 digest）。
2. 会合点镜像重建并推（relay.py 加了 /admin）：`cd ../../relay-platform/relay && docker build -t harbor.sunmoonai.com:30443/app-images/relay:v1-r2 . && docker push …`；digest 填 `resources/relay.yaml`。
3. 令牌（不进 git、不回传）：
   ```bash
   export KUBECONFIG=~/.kube/kind-config
   PROV=$(head -c 32 /dev/urandom | base64 | tr -d '=+/'); ADMIN=$(head -c 32 /dev/urandom | base64 | tr -d '=+/')
   kubectl -n sandbox-pool create secret generic sandbox-provisioner --from-literal=token="$PROV" --from-literal=knowledge-token="$(cat ~/private/demo-mcp-token 2>/dev/null || echo '')"
   kubectl -n edge create secret generic relay-admin --from-literal=token="$ADMIN"
   kubectl -n app-platform-dev get secret investment-workbench >/dev/null 2>&1 || kubectl -n app-platform-dev create secret generic investment-workbench --from-literal=WORKBENCH_CREDENTIAL_KEY="$(python3 -c 'import base64,os;print(base64.urlsafe_b64encode(os.urandom(32)).decode())')"
   kubectl -n app-platform-dev patch secret investment-workbench -p "{\"stringData\":{\"WORKBENCH_PROVISIONER_TOKEN\":\"$PROV\",\"WORKBENCH_RELAY_ADMIN_TOKEN\":\"$ADMIN\"}}"
   unset PROV ADMIN
   ```
4. `kubectl apply -f ~/worktrees/fable/k8s/sunmoonai/relay-platform/resources/relay.yaml && kubectl apply -f ~/worktrees/fable/k8s/sunmoonai/sandbox-platform/resources/provisioner.yaml`；`kubectl -n sandbox-pool get pods`：sandbox-provisioner Running；`kubectl -n edge logs deploy/relay --tail=3` 里 `listening`。
5. 让工作台 api 拿到新 Secret 键：`kubectl -n app-platform-dev rollout restart deploy/investment-backend-api`（可选引用，重启后注入）。
6. 浏览器登录 → 设置页：先在「模型 key」提交你的 Kimi key（厂商 kimi）；再在「我的沙箱」点「拉起沙箱」。应该看到：状态变「启动中」，一段代理接入命令出现（只这一次，先复制到 `~/private/agent-init.txt`）；1 分钟内状态变「运行中」。`kubectl -n sandbox-pool get pods` 里多了 `sandbox-u-xxxxxxxxxxxx`。
7. 本地代理：把第 6 步的命令里 `--relay` 换成 NodePort 地址 `ws://$NODE_IP:30471`（集群内地址宿主机连不上；正式拓扑才是 wss 边缘地址），`--root` 换成 WSL 里真实目录，前缀 `SUNMOON_AGENT_HOME=~/.sunmoon-agent-kind2 node ~/worktrees/fable/runtime/agent/dist/cli.js init …`，然后 `… start`。日志 `relay connected`；`kubectl -n edge logs deploy/relay` 有 `admin set tokens user=u-…` 与 `agent up user=u-…`。
8. 会话页：新建会话时沙箱下拉里应出现 `ws://sandbox-u-….sandbox-pool.svc.cluster.local:47800`（机器仍用第 07 步登记的 this-pc，或用 `workbench_register` 给新 relay 用户登记一台）→ 发一个 turn → 问专家 SMOKE → SUCCEEDED。
9. 更新与回收：设置页再点「更新沙箱」（不应再显示代理命令，pod 不重启除非 key 变）；「回收沙箱」后 `kubectl -n sandbox-pool get deploy,pvc`：Deployment 没了、PVC 还在。
10. 回传：每步结果；`kubectl -n sandbox-pool logs deploy/sandbox-provisioner --tail=30`；`kubectl -n edge logs deploy/relay --tail=20`；过滤含 sk-、token 的行。

失败停在那步。第 6 步 503 = 工作台没读到 Secret 键（看第 5 步）；502 = 供给器或会合点管理通道不通（看两边日志与 api 的出站策略）。
