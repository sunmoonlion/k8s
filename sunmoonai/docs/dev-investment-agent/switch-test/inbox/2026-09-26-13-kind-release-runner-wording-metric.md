# KIND：发版——runner 重连换新令牌、「交给专家」措辞、知识库按中文名查口径（本地机）

```text
被测仓：k8s，本地路径 ~/worktrees/fable/k8s（还要 investment-app、knowledge-app、runtime）
跑：按下面编号步骤做（知识后端、投资后端 + 网页都走 06/08/12 那套只换镜像的正式升级；本地代理本地重建）
仓与提交：investment-app 3390156（子仓 investment-backend 23d321b、investment-web-frontend 319258d）；knowledge-app 6a48507（子仓 knowledge-backend dd68e6d）；runtime 5645e63；k8s 本条待办所在的 fable 头
预计：80 分钟；要 Docker、KIND、Harbor
看什么：第 4 步 metric_definitions 用「净营收」能查到 net_revenue_cents；第 10 步回收再拉起沙箱后，不重启 runner，发话不再报 HTTP 401；第 11 步网页上是「交给专家」，任何地方都没有「方向盘」
前提：无（KIND 现在是 12 发的版本：投资后端 a14b070、网页 a480433，知识后端 4d9804c 的 know-mcp-0925-r2）
回传：k8s/sunmoonai/scripts/results/kind-release-13.<时间>.md（写下后在被测仓提交）
```

## 这次发的是什么（都已在远程测过，KIND 里还没生效）

- 投资后端 23d321b：runner 要重连沙箱时先重读库里的沙箱记录。之前回收再拉起后沙箱换了能力令牌，runner 还拿缓存里的旧令牌连，每条命令都报 `HTTP 401`，只能重启 runner。和 12 之间只差这一个提交，没有数据库迁移。
- 网页 319258d：按钮与时间线改成「交给专家」「专家已交回」「专家正在处理」，去掉「方向盘」。
- 知识后端 dd68e6d：`metric_definitions` 用中文显示名（如「净营收」）也能查到；精确匹配优先，再按包含匹配。没有数据库迁移。
- 本地代理 runtime 5645e63：会合点拒绝（令牌错、被吊销、被新代理顶掉）时以退出码 3 退出，不再挂着；`status.json` 留下原因。

## 一、知识后端

1. 身份准备沿用 08 的 `~/private/knowledge-identity-recovered-20260925`，`knowledge-app/deployment/development-input.json` 里的 `runtime_identity_upgrade` 不动。
2. 镜像：`cd ~/worktrees/fable/k8s/sunmoonai/app-platform/scripts && CLUSTER=KIND APPS=knowledge COMPONENTS=backend SOURCE_ROOT=$HOME/worktrees/fable bash build-push-app-images.sh`，取新 digest。
3. 锁与输入、渲染、门禁、单测、plan、停写、回执、部署：同 08 的第 7 到 9 步，只有这些不同：
   - 锁 `~/worktrees/fable/knowledge-app/development-source-lock.json`：只改 knowledge-backend 一段的 commit/tree（换成本地检出的实际值，commit 应为 dd68e6d…），`remote_branch` 改成 `origin/fable`（这个提交只在 fable 上）；`task` 改 `knowledge-metric-kind-20260926`；admin、web 两段不动。
   - `k8s/sunmoonai/app-platform/knowledge-app/deployment/development-input.json`：只换 `images.backend` 与锁的那一段；`migration_head` 仍是 `20260911_0006`。
   - 渲染 `--release-id know-0926-metric`，到空目录。diff 只应有：backend digest、锁与注解、派生哈希、release id。别的变化就停，贴 diff。
   - 回执输出到新目录 `~/private/knowledge-0926-metric`；部署带 `--identity-preparation ~/private/knowledge-identity-recovered-20260925`。
4. 验（令牌从文件读，不贴出来）：
   ```bash
   export KUBECONFIG=~/.kube/kind-config
   kubectl -n app-platform-dev exec -i deploy/knowledge-backend-api -- env MCP_TOKEN="$(cat ~/private/demo-mcp-token)" python - <<'PY'
   import json, os, urllib.request
   body = {"jsonrpc": "2.0", "id": 1, "method": "tools/call",
           "params": {"name": "metric_definitions", "arguments": {"metric": "净营收"}}}
   req = urllib.request.Request("http://127.0.0.1:8000/api/mcp/knowledge", data=json.dumps(body).encode(),
       headers={"Content-Type": "application/json", "Authorization": "Bearer " + os.environ["MCP_TOKEN"]})
   out = json.load(urllib.request.urlopen(req, timeout=30))
   print(json.dumps(out, ensure_ascii=False)[:1500])
   PY
   ```
   通过：结果里有 `net_revenue_cents` 和 `净营收`，并带 `data_version`。结果是空列表就是失败。
   （`demo-mcp-token` 若已失效返回 401，这不算本条失败：写进结果，改在第 11 步用网页 DATA_QUERY 验。）

## 二、投资后端 + 网页

5. 身份准备沿用 `~/private/investment-identity-recovered-20260926`，不动 `development-input.json` 里的 `runtime_identity_upgrade`。
6. 建两个镜像：`cd ~/worktrees/fable/k8s/sunmoonai/app-platform/scripts && CLUSTER=KIND APPS=investment COMPONENTS="backend web-frontend" SOURCE_ROOT=$HOME/worktrees/fable bash build-push-app-images.sh`，取两个新 digest。
7. 锁与输入：`~/worktrees/fable/investment-app/development-source-lock.json` 里 backend、web 两段的 commit/tree 换成本地检出的实际值（backend 23d321b…，web 319258d…；admin 不动），`task` 改 `runner-token-kind-20260926`；`k8s/sunmoonai/app-platform/investment-app/deployment/development-input.json` 换 `images.backend`、`images.web` 与锁的那两段；`migration_head` 仍是 `20260925_0011`。
8. 渲染到空目录（`--release-id kind-wb-20260926-r13`），diff 只应有：两个镜像 digest、两段锁与注解、派生哈希、release id。别的变化就停，贴 diff。替换 bundle，跑门禁、单测、plan（同 06、12）。
9. 维护窗口：api、worker、scheduler、runner 四类都停（`--replicas=0`），等 Pod 全部消失；备份回执输出到新目录 `~/private/investment-wb-20260926-r13`；`server-dry-run`，再 `deploy --backup-receipt … --identity-preparation ~/private/investment-identity-recovered-20260926`。部署完 `drift`、`status`。

## 三、本地代理

10. 本地代理用新版：`cd ~/worktrees/fable/runtime/agent && node node_modules/typescript/bin/tsc -p tsconfig.json`；按家目录找到 kind2 的代理 PID，`kill` 它，再按 09 的方式后台 `start`（不重新 init），确认只有 1 个、会合点里该用户只有一次 agent up。

## 四、浏览器（所有者，同一个登录过的标签页）

11. 会话页与设置页：
   - 会话页的按钮是「交给专家」；点它问专家 SMOKE，时间线出现「交给专家」「专家已交回」一类字样。页面上任何地方都不应出现「方向盘」。
   - 第 4 步没验成的话：在会话里问专家 DATA_QUERY，问题里用「净营收」这个词（例如「按月列出净营收」），委托应 SUCCEEDED，结果里有数。
12. **这次的主要验证：回收再拉起，不重启 runner。**
   - 设置页点「回收沙箱」，确认后状态变「已回收」。
   - 点「拉起沙箱」，等状态变「运行中」（这一步不会给新的接入命令，本地代理不用动）。
   - 回到刚才的会话发一句话。通过：回答正常出现，时间线里没有 `InvalidStatus … HTTP 401`。
   - 本地助手这期间**不要**重启 runner。另外记一下：拉起前后各跑一次 `kubectl -n app-platform-dev get pods | grep investment-backend-runner`，两次 Pod 名一样、RESTARTS 没变，证明中途没有重启过。
13. 回传：每步结果与屏幕上看到的；`drift`/`status`；过滤含 sk-、kmcp-、token=、password 的行。

失败停在那步。
