# KIND：D10 令牌签发——工作台签 JWT，会合点与知识服务用公钥就地验，设置页撤换（本地机）

```text
被测仓：k8s，本地路径 ~/worktrees/fable/k8s（还要 investment-app、knowledge-app、runtime 的 fable 头）
跑：按下面编号步骤做
仓与提交：k8s 本条待办所在的 fable 头；investment-backend 含 tokens.py 的 fable 头；knowledge-backend 含 JWT TokenTable 的 fable 头
预计：40 分钟；要 Docker、KIND、Harbor；09 已过（有沙箱、有会合点管理通道）
看什么：第 5 步会合点日志 `jwt verification enabled`；第 6 步拉起后 `admin set public key` 与 `agent up`，代理令牌是三段式；第 8 步撤换后旧代理被拒、新命令能连；第 9 步 DATA_QUERY 经按用户签的 MCP 令牌成功
前提：09 已过。08（知识 MCP）过了第 9 步才能做，否则跳过第 9 步
回传：k8s/sunmoonai/scripts/results/kind-token-signing.<时间>.md
```

## 步骤

1. 三个镜像重建并推（后端多了 tokens 与 rotate；会合点多了验签；知识多了 JWT 表）：按 06 B 段的方式重渲染并部署 investment-app 与 knowledge-app（只换镜像的升级门 `runtime_identity_upgrade`；迁移头仍是 0011，不需要迁移）；会合点 `cd ~/worktrees/fable/k8s/sunmoonai/relay-platform/relay && docker build -t harbor.sunmoonai.com:30443/app-images/relay:v1-r3 . && docker push …`，digest 填 `resources/relay.yaml`。
2. 签名钥对（不进 git、不回传；私钥只在本地机 `~/private/`）：
   ```bash
   cd ~/worktrees/fable/investment-app/investment-backend/app
   uv run python -m app.cli.workbench_token_keys --private-out ~/private/wb-signing.pem --public-out ~/private/wb-public.pem
   ```
   输出一行 `kid=… public=… private=…`，不含私钥内容。
3. 私钥进工作台 Secret，公钥进知识服务 Secret（会合点的公钥由工作台经管理通道推，不用手工给；想手工也可以建 `relay-jwt`）：
   ```bash
   export KUBECONFIG=~/.kube/kind-config
   kubectl -n app-platform-dev patch secret investment-workbench -p "{\"stringData\":{\"WORKBENCH_TOKEN_SIGNING_KEY\":\"$(awk '{printf "%s\\n",$0}' ~/private/wb-signing.pem)\"}}"
   kubectl -n app-platform-dev get secret knowledge-mcp-tokens >/dev/null 2>&1 || kubectl -n app-platform-dev create secret generic knowledge-mcp-tokens --from-literal=tokens.json='{}'
   kubectl -n app-platform-dev patch secret knowledge-mcp-tokens -p "{\"stringData\":{\"jwt-public-key.pem\":\"$(awk '{printf "%s\\n",$0}' ~/private/wb-public.pem)\"}}"
   ```
   `kubectl -n app-platform-dev get secret investment-workbench -o jsonpath='{.data.WORKBENCH_TOKEN_SIGNING_KEY}' | base64 -d | head -1` 应是 `-----BEGIN PRIVATE KEY-----`（只看这一行，别回传）。
4. 让两个 api 拿到新键：`kubectl -n app-platform-dev rollout restart deploy/investment-backend-api deploy/knowledge-backend-api`；`kubectl apply -f ~/worktrees/fable/k8s/sunmoonai/relay-platform/resources/relay.yaml`。
5. 验公钥出口：`curl -s http://$NODE_IP:<web NodePort>/api/workbench/token-keys`（需要登录 cookie 的话在浏览器里打开）应是 `{"keys":[{"kty":"EC","crv":"P-256",…,"kid":"…"}]}`，没有 `d`。会合点此时还没公钥（`kubectl -n edge logs deploy/relay --tail=5` 没有 `jwt verification enabled`，正常——公钥在第 6 步推来）。
6. 设置页「我的沙箱」→「更新沙箱」（已有身份的用户只会重新登记；想看首发就先「回收沙箱」再「换代理令牌」）。`kubectl -n edge logs deploy/relay --tail=10`：出现 `admin set public key` 与 `admin set tokens user=u-…`。
7. 撤换：设置页点「换代理令牌」。应出现新的接入命令（三段式令牌，`eyJ` 开头）；会合点日志 `admin revoke jti count=2`；沙箱 pod 滚动一次（`kubectl -n sandbox-pool get pods -w`）。旧代理（还在跑的 `sunmoon-agent start`）应被新 `set_tokens` 后的下一次重连拒掉：日志里 `reject`/`token revoked`；用新命令 `init` 后 `start`，`agent up user=u-…`。
8. 用 JWT 走一条 SMOKE 委托：会话页 → 发 turn → 问专家 SMOKE → SUCCEEDED。
9. （08 过了才做）DATA_QUERY 委托：应 SUCCEEDED，且 `kubectl -n sandbox-pool get secret sandbox-u-… -o jsonpath='{.data.knowledge-token}' | base64 -d | cut -c1-3` 是 `eyJ`（按用户签的 MCP 令牌，不是共用的）。
10. 回传：每步结果；`kubectl -n edge logs deploy/relay --tail=30`；`kubectl -n app-platform-dev logs deploy/investment-backend-api --tail=30 | grep -i "provision\|rotate\|relay"`；过滤含 `eyJ`、`sk-`、`token=` 的行。

失败停在那步。第 6 步会合点没有 `admin set public key` = 工作台没读到私钥（第 3/4 步）；第 7 步旧代理没被拒 = 会合点镜像没换（第 1 步）或公钥没推到。
