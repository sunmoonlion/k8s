# qwen-014 回执：用户补充方法、平台核引文、平台收尾的用例记出错（先 knowlab 后 knowbench）

- 卡：`docs/dev-investment-agent/switch-test/inbox/qwen/2026-10-19-qwen-014-amendments-and-quotes.md`
- 起始 HEAD：`c38f9ed8`（`git pull --ff-only origin qwen` exit=0，c38f9ed8 即 HEAD/其祖先，满足「不早于 c38f9ed8」）
- 纪律：任何一步 exit≠0 停、原样进回执、不重试不退回；不写库、不替所有者在 web端填写、受 flux 管的部署不用 rollout restart；带管道命令包进 `bash <<'SH' … SH`。
- 环境注记：同 qwen-013——Bash 沙箱写权限限于工作区，`/tmp` 在沙箱内呈只读；构建/发布等需写 `/tmp`、sudo、网络的步骤在沙箱外（提权）执行。

## 〇、先补 qwen-013 回执第 6 行——已补并推送

第 2 稿结论原文（所有者截给 Opus）已写入 `scripts/results/qwen-013.20261019-1131.md` 第 6 行与「测试最终结论」，并注明「c1 记成未通过而不是平台错误，由待办账 138 修，随 qwen-014 发」；提交 `386450d4` 已推送双远程。

## 一、核对（只读）——exit 全 0，逐字对上卡面

| 项 | 期望 | 实际 |
| --- | --- | --- |
| k8s HEAD | 本卡提交或更新 | `c38f9ed8`（=下限） |
| platform-status | exit=0 | `0`（PLAY RECAP ok=7 failed=0） |
| knowlab 父仓 | 6d395c8e… | `6d395c8e41b1c3d034c8e8b8d1732424abf62dca` |
| knowlab 后端 | 7e1a3cfb… | `7e1a3cfbc7b963f0563617a1eba2e97c806d89c8` |
| knowlab 网页 | badd0174… | `badd01742a27870b369255562acfe51604f2d7ee` |
| knowlab 管理端 | 20d6908a… | `20d6908a10a25901fa50789806f32f89bc1b118d` |
| knowbench 父仓 | 8b4d8e4c… | `8b4d8e4c317083691b0e156250e941f430d46b65` |
| knowbench 后端 | 29d69eb6… | `29d69eb671a9e45a9b47543569b570c60bdff9ef` |
| knowbench 网页（不变） | 4748b94e… | `4748b94ebf589ee870ca5efa097f212a59a1d04e` |
| knowbench 管理端（不变） | 26964553… | `26964553ed9d581ac855c38edeaee8e65add792f` |
| config expected_schema_revision | '20261019_0008' | 第 9 行 `expected_schema_revision: '20261019_0008'` |

## 二、一段 knowlab（7 行钉、三个镜像、一个迁移）

### 2.1 改钉 7 行
- `pin exit=0`；仅 `infrastructure/applications/sources.yaml`；`1 file changed, 7 insertions(+), 7 deletions(-)`；`+` 计数 = **7**。
- knowlab 七字段：parent `6d395c8e…`、backend_parent/backend `7e1a3cfb…`、web_parent/web `badd0174…`、admin_parent/admin `20d6908a…`。

### 2.2 构建 / 暂存 / 计划
- `build knowlab exit=0`；`stage knowlab exit=0`；`plan knowlab exit=0`（PLAY RECAP ok=16 failed=0，`"schema": "20261019_0008"`）。
- **镜像锁变了 3 个**：
  - `knowlab-backend/image.lock.yaml`：source_revision `7e1a3cfb…`、digest `sha256:b6d4ff2ab13195c2af1f76ca22d1d140e15f2ed65de213d98864d19ac81dd338`
  - `knowlab-web-frontend/image.lock.yaml`：source_revision `badd0174…`
  - `knowlab-admin-frontend/image.lock.yaml`：source_revision `20d6908a…`
- `key-check-done` 前无 `BEGIN PRIVATE KEY`/`BEGIN PUBLIC KEY` 命中。
- gitops 改动仅落 knowlab-app：admin 2 + backend 8 + web 2 = **12 文件**；无 knowbench 或其他应用变化。
- 运行时 workload diff（除镜像/摘要外各只 `DEPLOYMENT_ID` 一行；网页/管理端 workload 均在组件根目录 `workload.yaml`、无 runtime/ 子目录）：
  - `knowlab-backend/runtime/workload.yaml`：`knowlab-backend-cf35409ddf924aa3` → `knowlab-backend-b6d4ff2ab13195c2`
  - `knowlab-web-frontend/workload.yaml`：`knowlab-web-frontend-995b77e5824dbaef` → `knowlab-web-frontend-dfd59622d350c4ea`
  - `knowlab-admin-frontend/workload.yaml`：`knowlab-admin-frontend-f9e5a1f0e8bfa386` → `knowlab-admin-frontend-b3e728ea3d2d0b5f`
- 迁移 workload diff（`knowlab-backend/migration/workload.yaml`）：Job 名 `knowlab-migrate-cf35409ddf92-v1` → `knowlab-migrate-b6d4ff2ab131-v1`；镜像 digest `cf35409d…` → `b6d4ff2a…`；`DEPLOYMENT_ID` `7298030a…` → `7e1a3cfb…`；**`EXPECTED_SCHEMA_REVISION` `20261018_0007` → `20261019_0008`**。

### 2.3 提交 / 发布 / 晋级 / 等待 / 检查（push 前闸门全绿）
- `commit1 exit=0`：deploy 提交 `1a66f62c`「deploy(knowlab): 用户补充方法、核引文接口（qwen-014 一段）」。
- `release exit=0`：发布工件 `sha256:0e1d3fecd021d283f71e118ece69eeeb239eb02d7917219fa558dea453c92b8f` from `1a66f62c5fdec57fb6a7f258a71c2434ca168816`。
- `promote-cat exit=0`、`chown exit=0`。
- `commit2 exit=0`：晋级提交 `a28f98ca`「release(kind): 晋级到 1a66f62c（qwen-014 一段）」。
- `apply exit=0`。
- `wait exit=0`：11 个 knowlab kustomization 全 `condition met`。
- `check knowlab exit=0`：application-check PLAY RECAP ok=50 changed=0 failed=0；**admin 面 `admin_list_read: true`**（web 面 null 属正常）。
- 只读·迁移 Job：新 Job `knowlab-migrate-b6d4ff2ab131-v1` = **Complete 1/1**（8s）。卡面 `get jobs | grep knowlab-migrate | tail -2` 因字母序只回显 e498/f118 两个旧 Job，故另按新 Job 名直查确认（照实贴出）。
- 只读·后端镜像对齐（真上线判据）：`knowlab-api`/`knowlab-worker`/`knowlab-scheduler` 三 deploy 镜像均 = `harbor.sunmoonai.com:30443/platform/knowlab-backend@sha256:b6d4ff2ab13195c2af1f76ca22d1d140e15f2ed65de213d98864d19ac81dd338`，与 image.lock digest 逐字一致。

### 一段推送
- 见本节末尾补记（推送结果）。

## 三、二段 knowbench（3 行钉、一个镜像）

### 3.1 部署前只读查询——**0 行**、放行
跑 qwen-013 的 3.1 查询（workbench_tasks ⨝ workbench_interactions 非终态/挂问题委托）：
```text
 id | state | updated_at | kind | request_id
----+-------+------------+------+------------
(0 rows)
```
count = **0**。第 2 稿已结束、没有要人推的委托 → 放行部署。

### 3.2 改钉 3 行
- `pin exit=0`；仅 `infrastructure/applications/sources.yaml`；`+` 计数 = **3**。
- knowbench 三字段：parent_revision→`8b4d8e4c317083691b0e156250e941f430d46b65`、backend_parent_revision/backend_revision→`29d69eb671a9e45a9b47543569b570c60bdff9ef`；web（`4748b94e…`）、admin（`26964553…`）未动。

### 3.3 构建 / 暂存 / 计划
- `build knowbench exit=0`；`stage knowbench exit=0`；`plan knowbench exit=0`（PLAY RECAP ok=16 failed=0，`"schema": "20261017_0020"`）。
- **镜像锁变了 1 个**：`knowbench-backend/image.lock.yaml`：source_revision `29d69eb6…`、digest `sha256:58a09f4ae62400a61ff2e12c2b53d05e809a81c1d97682237d2c1295c8a6d940`。
- `key-check-done` 前无密钥命中；gitops 改动仅落 knowbench-backend：**9 文件**。
- 运行时 workload diff 除镜像/摘要外只 `DEPLOYMENT_ID` 一行：`knowbench-backend-71126f5ab9316ae2` → `knowbench-backend-58a09f4ae62400a6`。
- 迁移头 `20261017_0020`（不变）。

### 3.4 提交 / 发布 / 晋级 / 等待 / 检查（push 前闸门全绿）
- `commit1 exit=0`：deploy 提交 `b84eeaf1`「deploy(knowbench): 验收核引文、平台收尾的用例记出错（qwen-014 二段）」。
- `release exit=0`：发布工件 `sha256:d21d5fa3c9ad8c444ba5a3de1c5778a3a9aeb2275def12d0e4dae52ce9779907` from `b84eeaf10dee96f89566ce60ca7c1d8b71022d78`。
- `promote-cat exit=0`、`chown exit=0`。
- `commit2 exit=0`：晋级提交 `d1b9061b`「release(kind): 晋级到 b84eeaf1（qwen-014 二段）」。
- `apply exit=0`。
- `wait exit=0`：13 个 knowbench kustomization 全 `condition met`。
- `check knowbench exit=0`：application-check PLAY RECAP ok=50 changed=0 failed=0；**admin 面 `admin_list_read: true`**（web 面 null 属正常）。
- 测试电脑 `knowbench-test-computer-58bdd469cf-ckl47` **1/1 Running**；新 runner Pod `knowbench-runner-b76d49467-gwn7m` **1/1 Running**。
- 线上镜像确认（真上线判据）：`knowbench-api`/`runner`/`scheduler`/`worker` 四 deploy 镜像均 = `harbor.sunmoonai.com:30443/platform/knowbench-backend@sha256:58a09f4ae62400a61ff2e12c2b53d05e809a81c1d97682237d2c1295c8a6d940`，与 image.lock digest 逐字一致。

### 二段推送
- `git push origin qwen` exit=0：双远程 `72b851bd..d1b9061b`；HEAD == origin/qwen == `d1b9061b42c564c4bb36b9db610ca432124d8a7d`。

## 四、上线后核

### 第 1 行（Qwen，runner 就绪后 2 分钟内）——负判据全满足；`took over` 因无可接管而未出现（照实）
`$K -n app-platform-dev logs deploy/knowbench-runner --since=5m | grep -E "took over|advisor stopped|reconcile|advance failed|Traceback"` → **无任何命中**。
runner 原始日志（06:18:58Z 启动）仅干净启动行：`service_starting service=knowbench-runner role=runner`、`workbench runner starting id=sunmoon-kind-r1`、`machine sync starting interval=10.0s`、`knowbot test conductor starting interval=5.0s`。
- **没有 `advisor stopped`**（没有要收尾的委托）、**没有 `advance failed`、没有 `reconcile keeps failing`、没有 `Traceback`** —— 满足。
- 卡面正判据「有 `took over sandbox=…`」**未出现**：因 3.1 查询 0 行、集群里没有非终态委托/挂着问题的沙箱任务，新 runner 无可接管对象，属正确空态而非缺陷（对照 qwen-013 当时有卡死的 c1 才有 took over）。照实贴出。

### 第 2-4 行——待所有者 / 待截图
- 第 2 行（所有者）：用 sig-am 登录 web端，「我在做的专家」→「财务分析与预测」下点「写一条补充」，写自己的补充方法并提交；列表应出现该条、状态「待处理」。Qwen 不代填。
- 第 3 行（所有者）：管理端「专家草稿」→「财务分析与预测」→ 页签「补充方法」；应看到第 2 行那条、「待处理」、下面「出处写：amendment:…」与「不照做」输入框（**不要点不照做**）。
- 第 4 行（Qwen）：把第 2、3 行截图描述写进回执（补充原文只写前 20 字；截图不带地址栏 code=/token=/state=）。

## 测试最终结论——待续（第 3 稿由 Opus 照补充建，不在本卡）
