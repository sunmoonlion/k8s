# qwen-016 回执（本地机 Qwen）

卡：`docs/dev-investment-agent/switch-test/inbox/qwen/2026-10-19-qwen-016-idea-avatar-expert.md`（创意、分身、专家三栏；测试结果带回成稿与各步交回物；先 knowbench 后 knowlab）。qwen-015 暂停不做（所有者令）。

## 〇、开头快照（所有者要求附）

取于 HEAD=`526fbc57` 那一刻（一节核对时，本地 2026-10-19 21:38 前后）的原样输出：

```text
$ git -C ~/worktrees/qwen/k8s status --short
（空）
$ git -C ~/worktrees/qwen/k8s log --oneline -3
526fbc57 docs(rename-tools): qwen-005 走查 8 张与 R5.4 a/b 2 张截图入库（所有者定入库，了结 qwen-005 回执悬项）
e3c68a29 0037 评审采纳与发版准备：qwen-016 发布卡填新 SHA；……
dcaa3cbb 0037 代码已写：qwen-016 发布卡（先 knowbench 迁移头 20261019_0021，后 knowlab 迁移头 20261019_0009，……）
```

两点说明：

- 写本回执时 HEAD 已因 qwen-016 一段提交前进（commit1 `1caa88d7`、晋级 `30b08381`），上列是 `526fbc57` 为 HEAD 那一刻的快照；此后各节提交号逐节记录在下方。
- 「补交截图」**没有用 stash**：10 张 png 是 `git add` 恰好这 10 条路径后提交成 `526fbc57` 的，暂存清单为 10 条 `A`、不含任何被跟踪文件的修改；`git show --stat 526fbc57` = `10 files changed, 0 insertions(+), 0 deletions(-)`（全为 Bin 0 -> N bytes 的 png）。因此不存在「放回暂存时把卡、清单或 config 改回旧样子」的通路。

## 一、核对（只读）——全对卡

| 项 | 卡要 | 实测 | 判 |
| --- | --- | --- | --- |
| k8s 与远端 | HEAD 为本卡提交或更新 | ahead/behind = 0/0；HEAD=`526fbc57`（含本卡提交 `e3c68a29`）；status 空 | 对 |
| knowbench 父/后端 | `c38dca6c…` / `44888e23…` | `c38dca6c913eaceef23f5fac6a7d611c42cb0246` / `44888e23934fc50479fb0ddba978e794f62236a4` | 对 |
| knowbench 网页/管理端（不变） | `4748b94e…` / `26964553…` | `4748b94ebf589ee870ca5efa097f212a59a1d04e` / `26964553ed9d581ac855c38edeaee8e65add792f` | 对 |
| knowlab 父/后端/网页/管理端 | `aa51ed9e…`/`7c9731cd…`/`6da5cef5…`/`d46b6bd5…` | `aa51ed9eb8ca1decf6124b0a1c93c1a68b6cf515` / `7c9731cdbe79f8be7f00bf6c73ebcf7a70dffd8e` / `6da5cef54da34d616146530a09cbf8ae73c21acd` / `d46b6bd5ad03c3675f165f573713c82e4cafb5bf` | 对 |
| config 迁移头 | `'20261019_0021'` 与 `'20261019_0010'` | knowbench 第 10 行 `'20261019_0021'`；knowlab 第 9 行 `'20261019_0010'` | 对 |
| `/zh-CN/avatars` 计数 | 1 | 1 | 对 |
| platform-status | exit=0 | `status exit=0` | 对 |

## 二、一段：knowbench

### 2.1 部署前查询（只读）——0 行，放行

```text
 id | state | updated_at | kind | request_id
----+-------+------------+------+------------
(0 rows)
```

### 2.2 改钉（3 行）

`pin exit=0`；`git diff --stat` 仅 `infrastructure/applications/sources.yaml | 6 +++---`（3 插入 3 删除）；`+` 计数 = **3**。

### 2.3 构建、暂存、计划

- `build knowbench exit=0`；变了的镜像锁 **1 个**：`knowbench-backend/image.lock.yaml: source_revision: 44888e23934fc50479fb0ddba978e794f62236a4`。
- `stage knowbench exit=0`；`key-check-done` 前无任何文件名（无密钥泄漏）。
- 暂存改动落点 `uniq -c`：`9 components/app-platform/knowbench-app/knowbench-backend`（只有 knowbench 后端）。
- 运行时 workload diff 除镜像/摘要外仅：`DEPLOYMENT_ID: knowbench-backend-58a09f4ae62400a6` → `knowbench-backend-c507cdfa9ff24ae1`。
- 迁移 workload diff：`DEPLOYMENT_ID` 值 `29d69eb671a9e45a9b47543569b570c60bdff9ef` → `44888e23934fc50479fb0ddba978e794f62236a4`；`EXPECTED_SCHEMA_REVISION` `20261017_0020` → **`20261019_0021`**；Job 名 `knowbench-migrate-c507cdfa9ff2-v7`（workload 第 61 行）。
- `plan knowbench exit=0`；计划核到 `"schema": "20261019_0021"`；`ok=16 changed=0 failed=0`。

### 2.4 提交、发布、晋级、等待、检查

- commit1 `1caa88d7`「deploy(knowbench): 每条用例的成稿与各步交回物（qwen-016 一段）」（10 files, 31+/31-）；`commit1 exit=0`。
- `release exit=0`（`ok=30 changed=8 failed=0`）；候选：`digest: sha256:ffe143deb97f200b5138f5db6efb48aae09dac99952da3cfd8de6432e1240705`、`revision: 1caa88d733bfb71b5c3f2095e01b5ec910799f03`（= commit1 全号）、`repository: oci://harbor.sunmoonai.com:30443/platform/deployments-kind`、`requires_sops: true`。
- 候选照抄进 `infrastructure/environments/kind/flux-source.yaml`（`cp exit=0`，1 file 2+/2-）；commit2 `30b08381`「release(kind): 晋级到 1caa88d7（qwen-016 一段）」。
- `apply exit=0`（`ok=38 changed=3 failed=0`）；`wait exit=0`：**14** 个 knowbench kustomization 全 Ready。
- `check exit=0`：`"admin_list_read": true`、`ok=50 changed=0 failed=0`。
- 迁移 Job 按名直查：`knowbench-migrate-c507cdfa9ff2-v7 complete=Complete succeeded=1`（`get jobs | grep | sort | tail -3` 回显 c507/f38d/ff76 三个，新 Job 按名直查为准）。
- 真上线对齐：`knowbench-api / runner / scheduler / worker` 四 deploy 镜像摘要均 `sha256:c507cdfa9ff24ae1f3e7037997c812b2e5498066ac24a4801f797028ffe6373f` == `image.lock` 的 `digest` 同一值。
- Pod：`knowbench-runner-67b965bd9-8txg2 1/1 Running 68s`（新）、`knowbench-test-computer-58bdd469cf-ckl47 1/1 Running 12h`。

## 三、二段：knowlab

### 3.1 改钉（7 行）

`pin exit=0`；`git diff --stat` 仅 `infrastructure/applications/sources.yaml | 14 +++++++-------`（7 插入 7 删除）；`+` 计数 = **7**。

### 3.2 构建、暂存、计划

- `build knowlab exit=0`；变了的镜像锁 **3 个**：后端 `7c9731cdbe79f8be7f00bf6c73ebcf7a70dffd8e`、网页 `6da5cef54da34d616146530a09cbf8ae73c21acd`、管理端 `d46b6bd5ad03c3675f165f573713c82e4cafb5bf`。
- `stage knowlab exit=0`；`key-check-done` 前无文件名。
- 暂存改动落点：`knowlab-admin-frontend 2 + knowlab-backend 8 + knowlab-web-frontend 2 = 12` 文件，只有 knowlab。
- 后端运行时 diff 除镜像/摘要外两行：`DEPLOYMENT_ID: knowlab-backend-b6d4ff2ab13195c2` → `knowlab-backend-afca9881f01d4a94`；`WEB_AUTH_ALLOWED_RETURN_PATHS` 由 6 条变 **16 条**（原 dashboard/login/knowbots 中英各一，新增 questions、ideas、avatars、experts、data 中英各一；暂存重渲染出来，非手改）。
- 网页、管理端运行时 diff（`workload.yaml`）除镜像/摘要外仅 `DEPLOYMENT_ID`：web `dfd59622…`→`a89b38ec…`、admin `b3e728ea…`→`8f830323…`。
- 迁移 workload diff：`DEPLOYMENT_ID` `7e1a3cfb…`→`7c9731cd…`；`EXPECTED_SCHEMA_REVISION` `20261019_0008` → **`20261019_0010`**；Job 名 `knowlab-migrate-afca9881f01d-v1`（workload 第 61 行）。
- `plan knowlab exit=0`；计划核到 `"schema": "20261019_0010"`；`ok=16 changed=0 failed=0`。

### 3.3 提交、发布、晋级、等待、检查

- commit1 `ed8e8314`「deploy(knowlab): 创意、分身、专家三栏，成稿与各步交回物（qwen-016 二段）」（13 files, 42+/42-）；`commit1 exit=0`。
- `release exit=0`（`ok=30 changed=8 failed=0`）；候选：`digest: sha256:b986f3976dd5f2687671167c4f51d12da1d3356e51e0e6b91a16901061b4d908`、`revision: ed8e83144fbbe02cabd64d8f8ae287245339e822`（= commit1 全号）。
- 候选照抄进 `flux-source.yaml`（`cp exit=0`，1 file 2+/2-）；commit2 `aa703181`「release(kind): 晋级到 ed8e8314（qwen-016 二段）」。
- `apply exit=0`（`ok=38 changed=3 failed=0`）；`wait exit=0`：**12** 个 knowlab kustomization 全 `condition met`。
- `check exit=0`：`"admin_list_read": true`、`ok=50 changed=0 failed=0`。
- 迁移 Job 按名直查：`knowlab-migrate-afca9881f01d-v1 complete=Complete succeeded=1`。
- 真上线对齐：`knowlab-api / worker / scheduler` 三 deploy 镜像摘要均 `sha256:afca9881f01d4a94…` == 后端 `image.lock` digest；`knowlab-web` = `sha256:a89b38ec…` == 网页 lock；`knowlab-admin` = `sha256:8f830323…` == 管理端 lock。

## 四、上线后核

### 第 1 行（Qwen）

- `logs deploy/knowbench-runner --since=10m | grep -E "advance failed|Traceback|outputs failed"`：**无命中**（grep exit=1）。
- `logs deploy/knowlab-api --since=10m | grep -E "Traceback|outputs not fetched"`：**无命中**（grep exit=1）。
- `logs deploy/knowlab-scheduler --since=10m | grep -c knowbot_outputs`：暂 **0**（beat 于 13:59:11 UTC 随新 Pod 起步，每小时任务尚未到点）。按所有者改用的判据，以 beat 登记证明（输出原样）：

```text
$ $K -n app-platform-dev exec deploy/knowlab-scheduler -- python -c "from app.worker import celery_app; print(sorted(celery_app.conf.beat_schedule))"
['durable-delivery', 'knowbot-outputs-expire']
exec exit=0
```

输出含 `knowbot-outputs-expire` → **第三条过**。后台轮询仍挂着：14:59 UTC 前后若看到第一条 `Sending due task knowbot-outputs-expire` 就补记本节，没等到不影响本回执。

### 第 2–11 行收尾（所有者令，2026-10-19）

- qwen-016 **已审过**；第 2–10 行所有者已亲自走查完毕；**第 11 行截图描述免**（不再写截图描述进回执）。
- beat 那条**不用再补**：后台轮询已停（进程 terminated），/tmp 下 q016-* 日志与轮询脚本已删；`scripts/tmp-q016-*` 一次性脚本此前已删。
- 本回执到此收尾；qwen-015（第 3 稿测试）仍暂停，等 Opus 改写后再发。
