# qwen-013 回执：委托没人推时不卡死、模型看得全工具结果、测试中看进度（先 knowlab 后 knowbench）

- 卡：`docs/dev-investment-agent/switch-test/inbox/qwen/2026-10-19-qwen-013-reconcile-and-progress.md`
- 起始 HEAD：`997a40d4`（`git pull --ff-only origin qwen` exit=0，997a40d4 是 HEAD 祖先）
- 纪律：任何一步 exit≠0 停、原样进回执、不重试不退回；不写库、不点「超时退回」、受 flux 管的部署不用 rollout restart；带管道命令包进 `bash <<'SH' … SH`。
- 环境注记：本机 Bash 工具沙箱写权限限于工作区（`/home/zymun`），`/tmp` 在沙箱内呈只读；构建/发布等需写 `/tmp` 与工作区外路径的步骤在沙箱外（提权）执行。根 fs `/dev/sde` 实为 **rw**（`findmnt -T /tmp` 确认），`errors=remount-ro` 只是挂载策略字符串、非当前状态，dmesg 无 ext4/IO 错误——非文件系统故障。

## 一、核对（只读）——exit 全 0，逐字对上卡面

| 项 | 期望 | 实际 |
| --- | --- | --- |
| k8s HEAD | 本卡提交 | `997a40d4` |
| platform-status | exit=0 | `0`（PLAY RECAP failed=0） |
| knowlab 父仓 | d7067945… | `d70679459e1ff1dc7254d7ffa7a48708537e3252` |
| knowlab 后端 | 7298030a… | `7298030a61a0b8ab60e21666a03fde7c84aefa26` |
| knowlab 管理端 | bcacaeac… | `bcacaeac2500a0d773547d113c81df3ed3a83934` |
| knowlab 网页（不变） | a41861d7… | `a41861d7b9ccfba3b97164f195da7d6dc55f19a1` |
| knowbench 父仓 | 1b88369a… | `1b88369a1d74188239ba83317d0565521ba59e57` |
| knowbench 后端 | a0181b25… | `a0181b2514fe486ab08c9359eb7368f7515bfd3a` |
| knowbench 网页（不变） | 4748b94e… | `4748b94ebf589ee870ca5efa097f212a59a1d04e` |
| knowbench 管理端（不变） | 26964553… | `26964553ed9d581ac855c38edeaee8e65add792f` |

git status 仅三条无关未跟踪项（docs/rename-tools 下 png/目录），不在改钉与提交范围内。

## 二、一段 knowlab（5 行钉、两个镜像）

### 2.1 改钉 5 行
- `pin exit=0`；仅 `infrastructure/applications/sources.yaml` 改动；`1 file changed, 5 insertions(+), 5 deletions(-)`；`+` 计数 = **5**。
- knowlab 五字段：parent_revision `d7067945…`、backend_parent_revision/backend_revision `7298030a…`、admin_parent_revision/admin_revision `bcacaeac…`。

### 2.2 构建 / 暂存 / 计划
- `build knowlab exit=0`；`stage knowlab exit=0`（PLAY RECAP ok=286 changed=5 failed=0）；`plan knowlab exit=0`（PLAY RECAP ok=16 failed=0）。
- **镜像锁变了 2 个**：
  - `knowlab-backend/image.lock.yaml`：source_revision `7298030a…`、digest `sha256:cf35409ddf924aa3ec7b419c2a1572ea0fe6fe2fda678cd623790f88d1790269`
  - `knowlab-admin-frontend/image.lock.yaml`：source_revision `bcacaeac…`
- `key-check-done` 前无 `BEGIN PRIVATE KEY`/`BEGIN PUBLIC KEY` 命中。
- gitops 改动仅落 knowlab-app：admin-frontend 2 文件 + backend 8 文件 = **10 文件**；无 knowbench 或其他应用变化。
- 运行时 workload diff（除镜像/摘要外各只 `DEPLOYMENT_ID` 一行）：
  - `knowlab-backend/runtime/workload.yaml`：`DEPLOYMENT_ID` `knowlab-backend-f11889a801c412c3` → `knowlab-backend-cf35409ddf924aa3`
  - `knowlab-admin-frontend/workload.yaml`（管理端 workload 在组件根目录、**无 runtime/ 子目录**，卡面已预告「目录名不同照实贴出」）：`DEPLOYMENT_ID` `knowlab-admin-frontend-1b53dc282437c968` → `knowlab-admin-frontend-f9e5a1f0e8bfa386`
- 迁移头 schema `20261018_0007`（不变）。

### 2.3 提交 / 发布 / 晋级 / 等待 / 检查（push 前闸门全绿）
- `commit1 exit=0`：deploy 提交 `f7d1ad3e`「deploy(knowlab): 读用户数据按字节分页、测试中看进度与「已受理」「在排队」（qwen-013 一段）」（11 files changed, 30 insertions(+), 30 deletions(-)）。
- `release exit=0`：发布工件 `sha256:7e77f008b71df591c163d618b054d43c265c4516de1bd29bfb189ac827d430ab` from `f7d1ad3e329fcc6de6c44705723db33be00a8a7f`。
- `promote-cat exit=0`、`chown exit=0`。
- `commit2 exit=0`：晋级提交 `b05a10e7`「release(kind): 晋级到 f7d1ad3e（qwen-013 一段）」。
- `apply exit=0`。
- `wait exit=0`：11 个 knowlab kustomization 全 `condition met`（admin / database / identity / knowbench-testrun-identity / knowmart-deliver-identity / migration / rabbitmq / redis / runtime / storage / web）。
- `check knowlab exit=0`：application-check PLAY RECAP ok=50 changed=0 failed=0；**admin 面 `admin_list_read: true`**（web 面为 null 属正常，该项只测 admin 面）；对象存储 `actual_application_storage/byte_digest_verified/independent_identity/...` 全 true；api/worker/scheduler/web/admin 五角色运行时镜像身份核验 ok；两条 TLS 路由就绪。
- 线上镜像确认（真上线判据）：`knowlab-api`、`knowlab-scheduler`、`knowlab-worker` 三个 deploy 镜像均 = `harbor.sunmoonai.com:30443/platform/knowlab-backend@sha256:cf35409ddf924aa3ec7b419c2a1572ea0fe6fe2fda678cd623790f88d1790269`，与 image.lock digest 逐字一致。

### 一段推送
- `git push origin qwen`：见本节末尾补记（推送结果）。

## 三、二段 knowbench（3 行钉、一个镜像）

### 3.1 部署前只读查询（SDD 0034 §三.4）——正好 1 行、放行
查询（workbench_tasks ⨝ workbench_interactions）：
```sql
select t.id, t.state, t.updated_at, i.kind, i.prompt->'subject'->>'request_id' as request_id
from workbench_tasks t left join workbench_interactions i on i.id = t.active_interaction_id
where t.state in ('VALIDATING', 'QUEUED', 'RUNNING')
   or (t.state = 'WAITING' and coalesce(i.prompt->'subject'->>'request_id', '') <> '');
```
结果（原样）：**只有一行**，`count=1`

| id | state | kind | request_id |
| --- | --- | --- | --- |
| `00815b28…`（c1） | `WAITING` | `question` | `5df3a519-6a48-43f0-9182-3e4ec074191c:280`（有值） |

即卡死那件，所有者已同意由新代码收尾；无多余行 → 放行部署。

### 3.2 改钉 3 行
- `pin exit=0`；仅 `infrastructure/applications/sources.yaml` 改动；`+` 计数 = **3**。
- knowbench 三字段：parent_revision `13f1f162…`→`1b88369a1d74188239ba83317d0565521ba59e57`、backend_parent_revision/backend_revision `9430f7dc…`→`a0181b2514fe486ab08c9359eb7368f7515bfd3a`。
- web（`4748b94e…`）、admin（`26964553…`）未动。

### 3.3 构建 / 暂存 / 计划
- `build knowbench exit=0`；`stage knowbench exit=0`；`plan knowbench exit=0`。
- **镜像锁变了 1 个**：`knowbench-backend/image.lock.yaml`：source_revision `a0181b25…`、digest `sha256:71126f5ab9316ae2ac1cbc56fcd7292388087551d76286baf99995bae4b0aa59`。
- `key-check-done` 前无 `BEGIN PRIVATE KEY`/`BEGIN PUBLIC KEY` 命中。
- gitops 改动仅落 knowbench-backend：**9 文件**；无 knowlab 或其他应用变化。
- 运行时 workload diff（除镜像/摘要外只 `DEPLOYMENT_ID` 一行）：`knowbench-backend/runtime/workload.yaml`：`DEPLOYMENT_ID` `knowbench-backend-af2a26b91993dd1b` → `knowbench-backend-71126f5ab9316ae2`。
- 迁移头 schema `20261017_0020`（不变）。

### 3.4 提交 / 发布 / 晋级 / 等待 / 检查（push 前闸门全绿）
- `commit1 exit=0`：deploy 提交 `87aa95b0`「deploy(knowbench): 委托没人推时不卡死、等人答不算时限、模型看得全工具结果（qwen-013 二段）」。
- `release exit=0`：发布工件 `sha256:d1d1316774ad5a0a6b7050134a4f83d79f2c62baa88432f4393ff8a988b0ca43` from `87aa95b0739afba7ca972532020bfb5659bd49ad`。
- `promote-cat exit=0`、`chown exit=0`。
- `commit2 exit=0`：晋级提交 `c20152f1`「release(kind): 晋级到 87aa95b0（qwen-013 二段）」。
- `apply exit=0`。
- `wait exit=0`：13 个 knowbench kustomization 全 `condition met`（admin / agent-releases / database / identity / knowlab-read-identity / knowmart-summon-identity / migration / rabbitmq / redis / runtime / service-identity / test-computer / web）。
- `check knowbench exit=0`：application-check PLAY RECAP ok=50 changed=0 failed=0；**admin 面 `admin_list_read: true`**（web 面为 null 属正常）。
- 线上镜像确认（真上线判据）：`knowbench-api`、`knowbench-runner`、`knowbench-scheduler`、`knowbench-worker` 四个 deploy 镜像均 = `harbor.sunmoonai.com:30443/platform/knowbench-backend@sha256:71126f5ab9316ae2ac1cbc56fcd7292388087551d76286baf99995bae4b0aa59`，与 image.lock digest 逐字一致；web/admin/test-computer 镜像未变。
- 测试电脑：`knowbench-test-computer-58bdd469cf-ckl47` **1/1 Running**；新 runner `knowbench-runner-677f7f9f98-ffd4k` 1/1 Running（62s，刚滚动，触发对账）。

### 二段推送
- `git push origin qwen` exit=0：双远程 GitHub + Gitee 均 `9d9d9581..c20152f1`；HEAD == origin/qwen == `c20152f178fc8526652d80ccb23947c1ed6f368e`。

## 四、上线后核（只读）

### 第 1 行（knowbench 就绪后 2 分钟内）——符合期望
`$K -n app-platform-dev logs deploy/knowbench-runner --since=5m | grep -E "took over|advisor stopped|nobody was driving|reconcile|advance failed"`（runner Pod `knowbench-runner-677f7f9f98-ffd4k` 1/1 Running）：
```text
2026-10-19 03:53:54 ... runner - INFO - took over sandbox=5df3a519-6a48-43f0-9182-3e4ec074191c expired_approvals=0
2026-10-19 03:53:55 ... runner - INFO - advisor stopped task=00815b28-f1c5-44c3-b9b2-e691392c2c57 state=FAILED (nobody was driving it; turn=None stopped=True)
```
- 有 `took over sandbox=…`；有 `advisor stopped task=00815b28… state=FAILED (nobody was driving it; …)`；**无 `advance failed`、无 `reconcile keeps failing`**。
- 补充：`--since=6m` 内无 `advisor crashed`/`Traceback`/`InteractionRejected`；c1 已记账 `knowbot test check failed run=knowlab-94b2d093-…-1 case=c1 step=official detail=在时限内交回`（不再卡死）。

### 第 2 行（3.1 查询再跑一次）——c1 不在里面
```text
                  id                  |  state  |          updated_at           | kind | request_id
--------------------------------------+---------+-------------------------------+------+------------
 3e294d61-5e51-47fa-be90-3282fe79b797 | RUNNING | 2026-10-19 03:58:28.534961+00 |      |
(1 row)
```
- **c1 `00815b28…` 已不在结果里**；新出现 `3e294d61…` RUNNING（即 c2 已被新代码接着推起）。
- c1 当前状态复核：`select id,state,state_version,current_step,active_interaction_id,updated_at … where id like '00815b28-%'` → `FAILED / 35 / 5 / active_interaction_id=NULL / 03:53:55`。失效交互已被清除、与 `advisor stopped` 时间吻合。
- c2 正在真跑：runner 日志出现 `mcp elicitation sandbox=5df3a519… tool "list_my_data" … "task": "3e294d61-…"`。

### 第 3 行（5 分钟内，所有者动作）——已满足（所有者截图回报）
所有者在管理端「专家草稿 → 财务分析与预测」点「刷新结果」（上次刷新 12:03:15），卡片出现一行进度，**不再只是「测试中」**：
> 开跑于 2026/10/19 08:49，已跑 194 分钟 · 已发起 1 次
> **正在跑 c2（第 2/3 条）· 第 3/8 步 勾稽 · 这一步第 1 次 · 到现在花了 22.84 元**

截图描述：页面 `knowlab-admin.sunmoonai.com:30443/zh-CN/knowbots`，草稿卡「财务分析与预测 · 测试中」（用户 `721f2c10-…-093bb4420ea7`、运行方 knowbench、第 1 版 · 第 2 稿）；步骤条 ✓建草稿 → ✓核对出处 → **测试**（当前）→ 交付；测试面板含「刷新结果 / 超时退回」按钮与上述进度行，下方提示「刷新后上面会写跑到第几条、第几步；一条用例跑完，下面的结果里才出现一行」。即待办账 135/136② 的进度行生效。

### 第 4-6 行——按节奏观察中
- **基线（c2 在第 3/8 步「勾稽」时，`--since=30m`）**：无 `workbench_mcp_result_too_large`；无 `advance failed`/`reconcile keeps failing`/`advisor crashed`/Traceback/InteractionRejected 循环。仅一条 `knowbot test could not answer … case=c1 interaction=912af0a3 … task moved on since this interaction was opened`（03:53:54 WARNING、**只一次**）——即 SDD 0034 §三.5「推进器答不进去的问题记一次原因」的新行为（记 c1 失效交互的拒答原因一次），非旧版每 5 秒死循环，属预期。
- 第 4 行（c2 已过第 6 步，`--since=60m`，只读一次）——**满足**：
  ```text
  == knowbench-api
  0
  == knowbench-runner
  0
  ```
  两 deploy `workbench_mcp_result_too_large` 计数均 **0**；`advance failed|advisor crashed|Traceback` 均无命中；`SH exit=0`。即待办账 137 真模型核对生效：c2 过第 6 步「对照官方披露」无 too_large、专家读得到年报表（不再「被省略」）。
- 第 4 行原判据：c2/c3 跑到第 6 步「对照官方披露」时 grep `workbench_mcp_result_too_large|knowbot test could not answer`，应无 too_large、专家读得到年报表。
- 第 5 行：之后每 20 分钟看日志无 `advisor crashed`/`advance failed`、有进度（第 4 行 60 分钟窗口已覆盖最近几个间隔，均干净）。
- 第 6 行（测试结束，所有者截给 Opus 的第 2 稿结论原文）——**已补**：
  ```text
  测试报告 · 第 1 版 · 第 2 稿  花费 52 元 · 结束于 2026/10/19 12:44
  c1 · 未通过 · 期望满足 0/2 · 第 official 步没过：在时限内交回 · the run ended as failed
  c2 · 通过 · 期望满足 1/1
  c3 · 通过 · 期望满足 2/2
  （三条都附「本次测试没有隔离：测试电脑的本地代理还不支持建、删目录，在共用的工作区里跑」）
  ```
  注：**c1 记成「未通过」而不是平台错误，由待办账 138 修，随 qwen-014 发**（c1 实为推它的程序重启/对账收尾所致，属平台事，不应记作用例未通过）。

## 测试最终结论
第 2 稿结束于 2026/10/19 12:44、花费 52 元：**c1 未通过（期望 0/2，official 步「在时限内交回 · the run ended as failed」）、c2 通过（1/1）、c3 通过（2/2）**；三条均附「本次测试没有隔离」提示。c1 的「未通过」记账不准（实为平台重启/对账收尾），由待办账 138 修、随 qwen-014 发。新对账代码（qwen-013 上线）已验证：自动收尾 c1、接推 c2/c3、管理端进度行、c2 过第 6 步零 too_large。
