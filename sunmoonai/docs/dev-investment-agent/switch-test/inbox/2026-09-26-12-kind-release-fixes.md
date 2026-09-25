# KIND：发版——事件流、key 列表、沙箱按钮反馈、换令牌当场断开（本地机）

```text
被测仓：k8s，本地路径 ~/worktrees/fable/k8s（还要 investment-app、runtime）
跑：按下面编号步骤做（投资后端 + 网页走 06/07b 那套只换镜像的正式升级；会合点单独重建）
仓与提交：investment-app d1ee4e0（子仓 investment-backend a14b070、investment-web-frontend a480433）；runtime d6d9d7c；k8s 本条待办所在的 fable 头
预计：60 分钟；要 Docker、KIND、Harbor
看什么：第 8 步设置页能看到 key 列表（尾号 dDK6 一条生效）；按钮点了有文字反馈；换令牌要先确认、确认后旧代理当场被断开；第 9 步委托卡片与状态不刷新就出现
前提：08 的 DATA_QUERY 先做完（它不依赖这些修复）；10 的"换代理令牌"那一步放到本条第 8 步里做
回传：k8s/sunmoonai/scripts/results/kind-release-fixes.<时间>.md（写下后在被测仓提交）
```

## 这次发的是什么（都已在远程测过，KIND 里还没生效）

- 后端：事件流改为"数据库定顺序、Redis 只唤醒"——委托状态、专家步骤、你发的话都能实时到，不会漏；空闲保活（a14b070 及之前的 a14b070）；凭据列表字段的契约测试。
- 网页：设置页 key 列表能显示（之前严格校验拒收了创建时间、撤销时间两个字段）；沙箱各按钮有"正在…"与完成后的说明；换令牌、回收先确认；沙箱满了有中文提示；一次性接入命令带「复制命令」按钮（a480433）。
- 会合点：按 jti 吊销时当场断开用旧令牌在线的代理（4003）。
- 本地代理（runtime d6d9d7c）：被顶掉（4000）或令牌被吊销（4003）时停下、不再重连；`<子命令> --help` 只打印帮助。

## 步骤

1. 身份准备沿用 `~/private/investment-identity-recovered-20260926`，不动 `development-input.json` 里的 `runtime_identity_upgrade`。
2. 建两个镜像：`cd ~/worktrees/fable/k8s/sunmoonai/app-platform/scripts && CLUSTER=KIND APPS=investment COMPONENTS="backend web-frontend" SOURCE_ROOT=$HOME/worktrees/fable bash build-push-app-images.sh`，取两个新 digest。
3. 锁与输入：`development-source-lock.json` 里 backend、web 两个 component 的 commit/tree 换成本地检出的实际值（admin 不动）；`development-input.json` 换 `images.backend`、`images.web` 与锁的那两段；`migration_head` 仍是 `20260925_0011`。
4. 渲染到空目录（`--release-id kind-wb-20260926-fixes`），diff 只应有：两个镜像 digest、两段锁与注解、派生哈希、release id。别的变化就停，贴 diff。替换 bundle，跑门禁、单测、plan（同 06）。
5. 维护窗口：api、worker、scheduler、runner 四类都停（`--replicas=0`），等 Pod 全部消失；备份回执输出到新目录 `~/private/investment-wb-20260926-fixes`；`server-dry-run`，再 `deploy --backup-receipt … --identity-preparation ~/private/investment-identity-recovered-20260926`。
6. 会合点：`cd ~/worktrees/fable/k8s/sunmoonai/relay-platform/relay && docker build -t harbor.sunmoonai.com:30443/app-images/relay:v1-r4 . && docker push …`，digest 填 `resources/relay.yaml`，`kubectl apply -f` 它，rollout 等就绪。会合点重启后本地代理会自己重连。
6b. **（2026-09-26 补：上一轮停在这里）** 会合点换镜像时 pod 重建，旧版把公钥、登记表、吊销表存在临时卷里，全丢了，kind2 代理的令牌验不过被拒（状态 rejected，不会自己重试）。远程已改：公钥改从 Secret 读，状态放持久卷。按顺序：
   ```bash
   export KUBECONFIG=~/.kube/kind-config
   # 公钥进 Secret（10 生成的那个公钥文件；这是公钥，但照样不贴进对话）
   kubectl -n edge create secret generic relay-jwt --from-file=public.pem=$HOME/private/wb-public.pem --dry-run=client -o yaml | kubectl apply -f -
   # 同步 k8s 后应用新清单（持久卷 relay-state + Recreate 策略；digest 保持 v1-r4 那个不变）
   kubectl apply -f ~/worktrees/fable/k8s/sunmoonai/relay-platform/resources/relay.yaml
   kubectl -n edge rollout status deploy/relay --timeout=180s
   kubectl -n edge get pvc relay-state
   kubectl -n edge logs deploy/relay --tail=10 | grep -i "jwt verification enabled"
   ```
   最后一条应有 `jwt verification enabled`。然后按家目录找到 kind2 的代理 PID，`kill` 它，再按 09 的方式后台 `start`（不重新 init），确认 `relay connected`、会合点里 u-a63d03b16693 一次 agent up。之后继续第 7 步。
   （注意：旧会合点吊销过的令牌记录已随临时卷丢失；第 8 步会重新换一次令牌，之后吊销表存在持久卷里，不会再丢。）
7. 本地代理用新版：`cd ~/worktrees/fable/runtime/agent && node node_modules/typescript/bin/tsc -p tsconfig.json`；按家目录找到 kind2 的代理 PID，`kill` 它，再按 09 的方式在后台起一个（不重新 init），确认只有 1 个、会合点里该用户只有一次 agent up。
8. 浏览器（所有者，同一个登录过的标签页）：
   - 设置页：模型 key 列表里有 dDK6（生效）和四条已撤销；点「更新沙箱」，按钮先显示"正在更新…"，完了出现一行绿色说明。
   - 点「换代理令牌」：先出现确认框写明后果；点「确定更换」后出现新的接入命令和一行说明；点「复制命令」应显示"已复制"。把新命令存到 `~/private/agent-init.txt`（覆盖，0600，方法同 09），交给本地助手。
   - 本地助手看：kind2 代理的日志里出现 "token revoked" 且进程停下、不再重连；`kubectl -n edge logs deploy/relay --tail=20` 有 `admin revoke jti count=2 closed_agents=1`。然后用新命令 init（家目录 kind2）并后台 start，确认 agent up。（这就是 10 的撤换那一步。）
9. 会话页：新建会话（this-pc、sandbox-u-a63d03b16693），发一句话，再问专家 SMOKE。**不刷新**：你发的话、委托卡片、"委托 RECEIVED → …"这些行都应自己出现。
10. 回传：每步结果与屏幕上看到的；`drift`/`status`；过滤含 sk-、token=、password 的行。

失败停在那步。
