# qwen-009 回执：判分遇到算出 0 就崩、崩了委托一直挂着（knowbench 后端一个镜像）

时间：2026-10-19 00:09（本地 UTC+8）／集群 UTC 2026-10-18 16:09／执行者：Qwen（本地机）
卡：`docs/dev-investment-agent/switch-test/inbox/qwen/2026-10-18-qwen-009-judge-crash.md`
本回执覆盖**第一到四节（部署）**；第五节走查（K19 重测第 2 稿）等挂着的第 1 稿 22:55Z 超时收尾后由所有者操作，届时补记。

提交链（rebase 后，双远程 GitHub＋Gitee 均已到 `27b835a3`）：
- 拉取基线 `df988432`（卡要求 HEAD 到 df988432 或更新，达标）
- 部署提交 `e8ed3920`（rebase 前为 `7371fa81`）
- 晋级提交 `27b835a3`（rebase 前为 `d07f3958`）
- 其间远端被 Opus 推进一条只改待办账的提交 `3459a3aa`（详见第四节「推送被拒与处置」）

---

## 一、核对（只读，全 exit=0）

- `git pull --ff-only origin qwen`：exit=0，HEAD `df988432`。
- knowbench 父仓/子仓指针对卡逐字一致：
  - 父仓 `dfdc7f4`（dfdc7f4313bac6ef92660a60496c7e75e026a824）
  - 后端 `ad6d6b4`（ad6d6b41615287fd76061f8cdf8d881a1811b6c4）
  - 网页 `4748b94e`（不变）
  - 管理端 `26964553`（不变）
- `make -C infrastructure platform-status`：exit=0（ok=7 failed=0）。

## 二、改钉（3 行，exit=0）

- 卡内 python 改钉脚本 exit=0；`git diff --stat` 只动 `infrastructure/applications/sources.yaml`；`git diff … | grep -c '^+ '` = **3**（knowbench 块：parent_revision 1 + backend_parent_revision 1 + backend_revision 1）。
- 网页、管理端及其它应用字段未动。

## 三、构建、暂存、计划（全 exit=0）

- `platform-build OBJECT=app-platform/knowbench-app`：exit=0（日志 `/tmp/q009-build.log`；管理端 `已是这一份（sha256:8d87f3e4937c）`，未重建）。
- 变了的镜像锁 **1 个**：
  - `gitops/components/app-platform/knowbench-app/knowbench-backend/image.lock.yaml`：`source_revision: ad6d6b41615287fd76061f8cdf8d881a1811b6c4`，`digest: sha256:ac83f0eac23f116a3f4611a3e241bc23e100641da4c175313bf9f2f8813b2cd0`
- `platform-stage`：exit=0；`key-check-done` 前无文件名（无私钥/公钥泄漏）。
- 暂存产物分布 `uniq -c`：`9 components/app-platform/knowbench-app/knowbench-backend`（只后端，无别的应用）。
- 运行时 diff（除镜像与摘要外）只有 `DEPLOYMENT_ID` 一行：
  ```
  -  DEPLOYMENT_ID: "knowbench-backend-a93d38dd53e44a24"
  +  DEPLOYMENT_ID: "knowbench-backend-ac83f0eac23f116a"
  ```
  （尾段 `ac83f0eac23f116a` 即新镜像 digest 前缀，一致）
- `application-deployment-plan APP=knowbench`：exit=0（日志 `/tmp/q009-plan.log`）；迁移头 `20261017_0020`（无新迁移，与卡一致）；`PLAY RECAP ok=16 changed=0 failed=0`。

## 四、提交、发布、晋级、检查（各步 exit=0）

- 部署提交：`git add infrastructure/applications/sources.yaml gitops` → commit `deploy: 判分遇到算出 0 不再崩、崩了收尾记出错（qwen-009）`，exit=0（原 `7371fa81`）。
- `flux-release`：exit=0（`PLAY RECAP ok=30 changed=8 failed=0`）。
- 晋级：`sudo tee` 写 `infrastructure/environments/kind/flux-source.yaml` → commit `release(kind): 晋级到 7371fa81（qwen-009）`，exit=0（原 `d07f3958`）。
- `flux-source-apply`：exit=0（`PLAY RECAP ok=38 changed=3 failed=0`）。
- kustomization 等待：`wait exit=0`，13 个 `knowbench-*` kustomization 全部 `condition met`。
- `application-check APP=knowbench`：exit=0；`admin_list_read: true`（另一处 null）；`PLAY RECAP ok=50 changed=0 failed=0`。
- 测试电脑：`knowbench-test-computer-58bdd469cf-zdrt9  1/1  Running  0  7h19m`。
- **后端新镜像在线核实**（补证）：`knowbench-api` 容器镜像 `harbor.sunmoonai.com:30443/platform/knowbench-backend@sha256:ac83f0eac23f116a3f4611a3e241bc23e100641da4c175313bf9f2f8813b2cd0`，与镜像锁逐字一致；`app-platform-dev` 内跑该 digest 的 Pod 共 **9** 个（api/runner/scheduler/worker 等 knowbench-backend 组件），**含 runner**（判分/验收所在），qwen-009 修复确已生效。

### 推送被拒与处置（所有者授权）

- 首次 `git push origin qwen`（origin 双 URL：GitHub＋Gitee）被拒：
  ```
  error: failed to push some refs to 'https://gitee.com/sunmoonlion/k8s.git'
  hint: Updates were rejected because the remote contains work that you do not have locally.
  ```
  原因：我拉取 `df988432` 后，Opus 推了一条只改待办账的提交 `3459a3aa`（「待办账 135：测试跑着时看不到进度…」），两远端 qwen 前进到 `3459a3aa`，与我基于 `df988432` 建的部署提交分叉（非快进）。该提交只动待办账一个文件，与部署提交不冲突。
- 按纪律 exit≠0 先停、只读查清分叉，未重试未退回；所有者随后转来处置指令，授权 `git pull --rebase origin qwen` 后再 `git push origin qwen`。
- **`git pull --rebase origin qwen` 输出（原样）**：
  ```
  From https://github.com/sunmoonlion/k8s
   * branch              qwen       -> FETCH_HEAD
  Successfully rebased and updated refs/heads/qwen.
  rebase exit=0
  ```
  我的两条部署提交重放到 `3459a3aa` 之上：部署提交 `7371fa81`→`e8ed3920`，晋级提交 `d07f3958`→`27b835a3`（哈希因父提交改变而重写，内容不变）。
- **`git push origin qwen` 输出（原样，双远程各一段）**：
  ```
  To https://github.com/sunmoonlion/k8s.git
     3459a3aa..27b835a3  qwen -> qwen
  To https://gitee.com/sunmoonlion/k8s.git
     3459a3aa..27b835a3  qwen -> qwen
  push exit=0
  ```
- 双远程核对：`git rev-parse HEAD` = `git rev-parse origin/qwen` = `27b835a39cb3bee8f9cb205a31d1f7eb46164c62`；GitHub 与 Gitee 均在 `27b835a3`。

### rebase 副作用如实报（不影响集群，交 Opus 判是否需整饰）

- `flux-source.yaml` 是 **OCI 摘要式**晋级：
  ```
  repository: oci://harbor.sunmoonai.com:30443/platform/deployments-kind
  digest:     sha256:811a5e43ba5030d0390db125a5fd7b5872ea70d5fbdc9c470e8e2e16cc58e484
  revision:   7371fa81ac105ae8ef8ad0ace31f4b1ac9ecc882
  ```
  flux 靠 **digest** 从 Harbor 取工件 reconcile，`revision` 只是「该工件由哪个 git 提交构建」的标签，**不是** git checkout 目标。
- rebase 把部署提交号从 `7371fa81` 改成 `e8ed3920`，于是 `flux-source.yaml` 里的 `revision: 7371fa81…` 与晋级提交说明「晋级到 7371fa81」都指向一个**未推上远端的孤儿哈希**。
- **判定：不破坏集群。** digest（`sha256:811a5e…`）才是真指针，已在 apply 时生效，wait/check 全过、后端 9 Pod 已在新镜像；且下一轮 `flux-release` 会用新 HEAD 重生成 `source-candidate.yaml` 覆盖此标签，属自愈。此处仅为号面标签与实际部署提交对不上，未改动，交 Opus 决定是否需整饰（如需，我可重跑 flux-release→晋级→apply 让 revision 对上 `e8ed3920`）。

## K19 挂着那次测试（未动）

- 卡与所有者均要求不碰第 1 稿挂着的那次测试。全程未点「超时退回」、未改库。
- 只读核库确认仍原样：`knowlab-433a5349-5301-41da-ad59-3c5db794c4c2-1 | status=running | started 2026-10-18 14:55:29Z | finished 空`，将到 28800 秒超时（约 22:55Z／本地 06:55）自行收尾。

## exit 汇总

| 步骤 | exit |
| --- | --- |
| pull --ff-only | 0 |
| platform-status | 0 |
| 改钉 pin | 0 |
| platform-build | 0 |
| platform-stage | 0 |
| application-deployment-plan | 0 |
| 部署 commit | 0 |
| flux-release | 0 |
| 晋级 commit | 0 |
| flux-source-apply | 0 |
| kustomization wait | 0 |
| application-check | 0 |
| 首次 push（被拒） | 非 0（远端分叉，已停并只读查清） |
| pull --rebase（授权后） | 0 |
| push（授权后） | 0 |

## 第五节走查（待补）

挂着的第 1 稿 22:55Z 超时收尾后，由所有者在 knowlab 管理端（admin，登录由所有者输入）操作：刷新第 1 稿见「测试未通过」→ 同一份 `manifest-v1.json`（sha256 `7dffd795…4a54`）建第 2 稿 → 核出处（14 条）→ 预算 300、超时 28800 发起测试。我在集群侧按卡第 4 行定时取 runner 日志（`logs deploy/knowbench-runner --since=70m | grep -E "advisor (stopped|crashed)|knowbot test|budget exhausted"`），核没有 `advisor crashed`、有 `advisor stopped`、终态 `knowbot test run finished`。走查齐后补记三条用例结论、期望满足数、没过步骤原因原文、页面显示的花费与用时，再提交推送停等 Opus 审。
