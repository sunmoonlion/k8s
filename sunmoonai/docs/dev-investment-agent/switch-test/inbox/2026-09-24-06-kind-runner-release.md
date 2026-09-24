# KIND 开发包：带工作台的后端 + runner 角色（本地机，要 KIND、Harbor、Docker）

```text
被测仓：k8s，本地路径 ~/worktrees/fable/k8s（还要并列的 tpl-app、investment-app 两个仓；investment-app 的三个子仓要按父仓 gitlink 检出、干净）
跑：按下面 A 段的编号步骤做（每步一条命令），B 段等所有者定
仓与提交：k8s 本条待办所在的 fable 头；tpl-app 74ff0c5；investment-app a50e939（子仓 investment-backend 5f0a037、investment-web-frontend f11cb56、investment-admin-frontend 2e1f5c6）
预计：A 段 30 到 45 分钟（建两个镜像各 10 分钟、渲染 1 分钟）；要联网；要 Docker 与 KIND 内 Harbor 可推；不要模型 key
看什么：A6 的 diff 只应有四类变化——镜像 digest、runner 相关资源（Deployment/PDB/ServiceAccount/NetworkPolicy）与 ConfigMap 里的 WORKBENCH_* 四个键、api 容器里对 investment-workbench Secret 的可选引用、release.json 里的锁与哈希；A7 门禁 rc=0；A8 单测里 investment 与 info 过，knowledge 那条已知红（knowledge-backend 源码已前进而其开发包未重渲染，属第四步）
前提：本地 human-local.sh 已同步到上面的提交；三个子仓工作区干净；KIND 起着；Harbor 登录凭据在本地（build-push 脚本自己读）
回传：k8s/sunmoonai/scripts/results/kind-runner-release.<时间>.md（写下即可；A6 生成的 bundle、development-input.json、development-source-lock.json 一并留在工作区由所有者提交）
```

## A 段：建镜像、更新锁、渲染开发包（不碰集群）

1. `cd ~/worktrees/fable/k8s/sunmoonai/app-platform/scripts && CLUSTER=KIND APPS=investment COMPONENTS="backend web-frontend" SOURCE_ROOT=$HOME/worktrees/fable bash build-push-app-images.sh`（脚本用环境变量选 App 与组件，见其头部 CONFIGURABLE_VARS；目标 `harbor.sunmoonai.com:30443/app-images/investment-backend:architecture-v2-dev` 与 `investment-web-frontend:architecture-v2-dev`）。应该看到两次 push 成功。SOURCE_ROOT 指向含 investment-app 的目录，脚本默认是 ~。
2. 取 digest：`docker inspect --format '{{index .RepoDigests 0}}' harbor.sunmoonai.com:30443/app-images/investment-backend:architecture-v2-dev`，web 同理。记下两串 `@sha256:…`。admin 前端没改，沿用 development-input.json 里现有的 admin digest。
3. 更新 `~/worktrees/fable/investment-app/development-source-lock.json`：三个 components 的 `commit` 与 `tree` 改成本地检出的实际值（`git -C <子仓> rev-parse HEAD` 与 `rev-parse 'HEAD^{tree}'`），`remote_branch` 保持 `origin/master`（已合并）。`task` 改成 `workbench-runner-kind-20260925`。
4. 更新 `~/worktrees/fable/k8s/sunmoonai/app-platform/investment-app/deployment/development-input.json`：`images.backend` 与 `images.web` 换成第 2 步的 digest；`migration_head` 改成 `20260924_0009`；`development_source_lock` 整段与第 3 步的文件完全一致。
5. 渲染到空目录：`cd ~/worktrees/fable/k8s/sunmoonai/app-platform/investment-app && python3 -B deployment/render.py --output-dir /tmp/investment-dev --release-id kind-wb-20260925 --development-input deployment/development-input.json`。应该以 `"result": "rendered"` 结束。
6. `diff -ru deployment/bundle /tmp/investment-dev | less`：只看「看什么」里列的三类变化。确认后 `rm -rf deployment/bundle && cp -r /tmp/investment-dev deployment/bundle`。
6b. 同步部署声明（README 要求「更新 .conf」，先前漏写）：`deploy-investment-app-all/deploy-investment-app-all.conf` 里 `RELEASE_ID=kind-wb-20260925`，`BACKEND_IMAGE` 与 `WEB_IMAGE` 换成第 2 步的 digest 全名，`ADMIN_IMAGE` 不变，`RUNNER_REPLICAS=1` 已在。
7. 门禁：`python3 -B ../scripts/verify-formal-instance.py --bundle deployment/bundle`，rc 应为 0。
8. 单测：`cd ../scripts && python3 -m unittest tests.test_committed_development_candidates tests.test_investment_runner_role tests.test_formal_component_deploy tests.test_development_release tests.test_deployment_config`；应全过（committed 那条会真的重渲染三个 App 并逐字比对）。
9. `./deploy-investment-app-all/deploy-investment-app-all.sh plan --cluster KIND`（在 investment-app 目录）：只读，应通过。把输出贴进回传。

## B 段：部署到 KIND（所有者已定：只换镜像的升级门，身份准备复用、备份回执按本次 release 新出）

前提（2026-09-26 起）：本地那轮按 0009 建的镜像与 bundle 作废，B 段从第 0 步重做；后端与网页镜像用 investment-app 30fece4（子仓 investment-backend e44dc1f、investment-web-frontend 9eb4c01）或更新的 fable 头建一次，就同时满足 06、09、10 三条待办，不用再建。仓已同步到 tpl-app 3317c84、investment-app 同步时的 fable 头（子仓 investment-backend 与 investment-web-frontend 取父仓 gitlink：含 0008 改 UUID、0010 会合点身份、0011 runner 租约、沙箱拉起接口，所以后端与网页镜像都要重建）、k8s 本条待办所在的 fable 头。

0. B7 的私有身份准备目录已丢（原在 `~/worktrees/luna/.local/kind-cutover-20260919`，工作区重建时没了）。先从集群现状重建一份，放在工作区之外：
   `mkdir -p ~/private && cd ~/worktrees/fable/k8s/sunmoonai/app-platform/scripts && python3 kind_identity_recover.py --app investment --kubeconfig ~/.kube/kind-config --cluster-uid $(kubectl --kubeconfig ~/.kube/kind-config get ns kube-system -o jsonpath='{.metadata.uid}') --prepared-release-id kind-b7-20260919 --output ~/private/investment-identity-recovered-20260925`
   应该以一行 JSON 结束，含 `plan_sha256`、`database_probes`（18）、`amqp.authenticated_roles`（3）、`old_identities_retired: true`。它不写集群不写库。这个 `plan_sha256` 就是第 2 步要填的 `preparation_plan_sha256`；第 7 步 `--identity-preparation` 指向这个新目录。

1. 重做 A1（backend 与 web-frontend：`COMPONENTS="backend web-frontend"`）、A2（取新 backend digest）、A3（锁：三个子仓 commit/tree 换成本地检出的实际值）。
2. 改 `development-input.json`：`images.backend` 换新 digest；加一段
   `"runtime_identity_upgrade": {"prepared_release_id": "kind-b7-20260919", "preparation_plan_sha256": "<第 0 步输出的 plan_sha256>"}`；`migration_head` 改成 `20260925_0011`。
3. 重做 A5 到 A9（渲染到空目录、diff、替换 bundle、门禁、单测、plan）。diff 里新增的只应有：backend digest、release.json 里的 `runtime_identity_upgrade`。A8 里 `test_runtime_rendering` 与 `test_committed_development_candidates` 的 investment/info 两条这次应该过。conf 里 `BACKEND_IMAGE` 跟着换。
4. 维护窗口（README 第 2 步）：`kubectl -n app-platform-dev scale deploy investment-backend-api investment-backend-worker investment-backend-scheduler --replicas=0`，等 `kubectl -n app-platform-dev get pods -l sunmoonai.com/app=investment` 里 backend 三类 Pod 全部消失。前端可以不停。
5. 备份回执（README 第 3、4 步，一条命令）：
   `python3 kind_database_rehearsal.py --app investment --kubeconfig ~/.kube/kind-config --cluster-uid $(kubectl get ns kube-system -o jsonpath='{.metadata.uid}') --image <新 backend digest 全名> --head 20260925_0011 --output <git 之外的私有目录，如 ~/private/investment-wb-20260925> --cutover-release ../investment-app/deployment/bundle/release.json`（在 `app-platform/scripts` 下跑）。应该以 `cutover_receipt` 一行结束，目录里有 `cutover-receipt.json` 与 `database.dump`。要 Docker（它起一次性 Postgres 做两次恢复演练）。
6. `./deploy-investment-app-all/deploy-investment-app-all.sh server-dry-run --cluster KIND`，应通过。
7. `./deploy-investment-app-all/deploy-investment-app-all.sh deploy --cluster KIND --backup-receipt <私有目录>/cutover-receipt.json --identity-preparation ~/private/investment-identity-recovered-20260925`。应该看到：迁移 Job 完成；`database-upgrade-kind-wb-20260925/complete.json` 出现在准备目录里（`grants_only: true`）；六个 Deployment 的 rollout 都 ok（含 `investment-backend-runner`）；末尾 JSON `"result": "passed"`。
8. 看：`kubectl -n app-platform-dev get pods -l sunmoonai.com/app=investment`（runner 1/1 Running）；`kubectl -n app-platform-dev logs deploy/investment-backend-runner --tail=20`（应是在轮询命令，没有异常）；浏览器登录 `https://investment.sunmoonai.com:30443` 后打开 `/zh-CN/workbench`，应看到「工作台」页，机器与沙箱下拉为空（沙箱与会合点是下一步）。
9. `./deploy-investment-app-all/deploy-investment-app-all.sh drift --cluster KIND` 与 `status --cluster KIND`。

失败就停在那一步，把命令输出原样写进回传（过滤含密码、含 `sk-` 的行）。第 7 步失败后**不要重跑**：迁移与激活各自留有记录，把准备目录里新出现的文件名列出来即可。

## 回传里要有

A 段每步的结果；B 段第 3 步的 diff 摘要、第 5 步的末行、第 7 步的完整输出、第 8 步的三项截图或文字、第 9 步的输出。
