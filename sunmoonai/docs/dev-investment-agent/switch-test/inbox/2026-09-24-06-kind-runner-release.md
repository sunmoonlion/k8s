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

## B 段：部署到 KIND（等所有者定流程后再做）

正式路的 apply 要 `--backup-receipt` 与 `--identity-preparation`，两者都绑定本次 release 的内容摘要（见 `app-platform/scripts/README.md`「KIND 开发包部署」1 到 5 步）。是每次都走完整流程，还是给"只换镜像、身份不变"的升级定一条更轻的路，由所有者定，定了再补这一段。

## 回传里要有

每步做到没有、屏幕上是什么；第 2 步的两个 digest；第 6 步 diff 里 `20-runtime.yaml` 与 `release.json` 的变化摘要；第 8、9 步的完整输出。
