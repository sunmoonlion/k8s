# KIND：后端补丁发版——会话事件流不带事件名，网页才能实时看到（本地机）

```text
被测仓：k8s，本地路径 ~/worktrees/fable/k8s（还要 investment-app）
跑：按下面编号步骤做（就是 06 B 段的只换镜像升级，只换 backend 一个镜像）
仓与提交：investment-app c38e616（子仓 investment-backend e1312c0）；k8s 本条待办所在的 fable 头
预计：40 分钟；要 Docker、KIND、Harbor
看什么：第 9 步网页发一句话后，不刷新页面，「过程」里实时出现命令与回答
前提：07 已做完（第 8、9 步可以靠刷新页面看结果先过）；06 的私有身份准备目录 ~/private/investment-identity-recovered-20260926 还在
回传：k8s/sunmoonai/scripts/results/kind-backend-sse-fix.<时间>.md（写下后在被测仓提交）
```

## 为什么有这一条

07 第 9 步网页发送后「过程」一直空白，诊断（`kind-sandbox-relay.20260925-034108.step9-diag.txt`）显示后端全通：命令已领、Codex 线程已建、turn 完成、66 条事件已入库。
毛病在事件流：后端每帧带 `event: <类型名>`，浏览器 `EventSource` 的 `onmessage` 只收无名帧，带名的帧全被静默丢掉。页面打开时已有的事件走另一个接口，所以**刷新页面就能看到**。
修法是后端帧不带事件名（investment-backend e1312c0，加了回归测试）。网页不用改。

## 步骤（照 06 B 段，差别写在每步里）

0. 不用重建身份准备：沿用 `~/private/investment-identity-recovered-20260926`，它的 `plan_sha256` 与 `development-input.json` 里现有的 `runtime_identity_upgrade` 一致，不动那一段。
1. 只建 backend：`cd ~/worktrees/fable/k8s/sunmoonai/app-platform/scripts && CLUSTER=KIND APPS=investment COMPONENTS="backend" SOURCE_ROOT=$HOME/worktrees/fable bash build-push-app-images.sh`；取新 backend digest。
2. 锁：`~/worktrees/fable/investment-app/development-source-lock.json` 里只有 backend 那个 component 的 `commit`/`tree` 换成 `e1312c0…` 的全长值（`git -C ~/worktrees/fable/investment-app/investment-backend rev-parse HEAD` 与 `rev-parse 'HEAD^{tree}'`）；web 与 admin 不动。
3. `development-input.json`：只换 `images.backend` 与 `development_source_lock` 里 backend 那段；`migration_head` 仍是 `20260925_0011`（没有新迁移）。
4. 渲染到空目录（`--release-id kind-wb-20260926-sse`），`diff -ru deployment/bundle <新目录>`：**只应有** backend 镜像 digest（api、worker、scheduler、runner、迁移 Job）、backend 源码锁与注解、派生哈希、release id。别的变化就停，贴 diff。然后替换 bundle，跑 A7 门禁、A8 单测、A9 plan（同 06）。
5. 维护窗口：这次 **runner 也要停**：`kubectl -n app-platform-dev scale deploy investment-backend-api investment-backend-worker investment-backend-scheduler investment-backend-runner --replicas=0`，等四类 Pod 全部消失。
6. 备份回执：同 06 B 段第 5 步的命令，`--image` 换新 backend digest，`--head 20260925_0011`，`--output ~/private/investment-wb-20260926-sse`（新目录）。
7. `server-dry-run`，再 `deploy --cluster KIND --backup-receipt ~/private/investment-wb-20260926-sse/cutover-receipt.json --identity-preparation ~/private/investment-identity-recovered-20260926`。
8. 看：四类 Pod Running（runner 1/1）；`kubectl -n app-platform-dev logs deploy/investment-backend-runner --tail=20` 有 `sandbox link up`。本地代理保持运行。
9. 浏览器（所有者）：打开 07 建的那个会话（`/home/zymun/research/smoke1`），发 `再写一个 hello2.txt，内容 hello2，然后 cat 它`。**不刷新页面**，「过程」里应在几秒内陆续出现命令与回答。
10. 回传：每步结果；第 9 步屏幕上看到了什么；`drift`/`status` 输出。

失败停在那步。
