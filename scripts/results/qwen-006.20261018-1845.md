# qwen-006 小发布回执（本地机 Qwen）——续跑轮：第三节补 knowmart、第四节全过、第五节走查

- 派活卡：`docs/dev-investment-agent/switch-test/inbox/qwen/2026-10-18-qwen-006-small-release.md`（含末尾「补：第三节续跑」）
- 执行者：Qwen（本地机）；续跑完成时间 2026-10-18 18:45
- 停点轮回执：`scripts/results/qwen-006.20261018-1459.md`（commit `93622c6d`）；续跑依据 `e1240dc9`（补卡 + knowmart 期望迁移头修复）
- 现场照留不退回：sources.yaml、knowbench/knowlab 暂存、镜像锁均承接停点轮

## 1. 续跑轮各步 exit

| 节 | 命令 | exit |
| --- | --- | --- |
| 补 | `git pull --ff-only origin qwen`（到 `e1240dc9`，与要求一致） | 0 |
| 补 | `platform-stage` knowmart | 0 |
| 补 | `application-deployment-plan` knowmart | 0（`ok=16 failed=0`，schema `20261018_0005`） |
| 补 | knowlab runtime diff 除镜像摘要外行数 | 0 行（比卡预期「只有 DEPLOYMENT_ID 一行」更严，不触发停） |
| 四 | deploy commit `e0289445`（32 文件）→ `make flux-release` → 晋级 commit `1cb30687` → `flux-source-apply` | 全 0 |
| 四 | `kubectl wait kustomizations` | 0（含 knowbench-test-computer condition met） |
| 四 | `application-check` knowbench / knowlab / knowmart | 0 / 0 / 0 |
| 四 | `git push origin qwen`（origin 双 URL，GitHub+Gitee 同到 `1cb30687`） | 0 |
| 五 | 走查 | 见 §4：7 过（4 行所有者确认无截图）、行 8 挡（F1）、行 9 依赖挡、行 10 半 |

带管道命令均按补卡要求包 `bash <<'SH' … SH` 执行（zsh 无 `PIPESTATUS`）。

## 2. 镜像锁八行（承接停点轮 §3，续跑未重锁）

```text
knowbench-admin-frontend: 26964553ed9d581ac855c38edeaee8e65add792f
knowbench-backend:        f9129c84aba21fd5666379bed2342f33d9553021
knowbench-web-frontend:   59e1956db154b8ac29c8b95ac3d23bf2832a870e
knowlab-admin-frontend:   ef4fe7f3f7e93df122bc10881e3c2a50ca4846e5
knowlab-web-frontend:     699ddb71cfde571308e5ebde2e8e4fea886695f9
knowmart-admin-frontend:  107fda29642e9bf7259af274fa6d6c991302bfeb
knowmart-backend:         360effd1110241a1f020d968f1096b3815307f76
knowmart-web-frontend:    85e7877e4e5a1d92fb632faffa0ca9a4e6e24cfb
```

## 3. 三处暂存摘录与三计划迁移头

knowbench runtime diff（停点轮 §3 原文，除镜像/摘要外）：

```diff
-  DEPLOYMENT_ID: "knowbench-backend-b98dc78340d87e4a"
+  DEPLOYMENT_ID: "knowbench-backend-502de707c13ef7cc"
+            - {secretRef: {name: knowbench-knowlab-read-service}}
-      - {key: app.kubernetes.io/name, operator: In, values: [knowbench-api, knowbench-worker]}
+      - {key: app.kubernetes.io/name, operator: In, values: [knowbench-api, knowbench-worker, knowbench-runner]}
```

knowlab runtime diff：除镜像摘要外 **0 行**；身份两处变化（`knowbench-testrun-identity`、`knowmart-deliver-identity` 的 workload.yaml）为共用注册脚本加重试，补卡说明属预期。

knowmart runtime diff（续跑新产出，`git diff e1240dc9 e0289445`）：

```diff
-  CROSS_APP_TARGETS_JSON: "{}"
+  CROSS_APP_TARGETS_JSON: "{\"knowbench\": {\"web_base_url\": \"https://knowbench.sunmoonai.com:30443\"}}"
```

计划迁移头：knowbench `20261017_0020`、knowlab `20261016_0006`（停点轮已核）、knowmart `20261018_0005`（续跑 plan 日志 `"schema": "20261018_0005"`、`ok=16 failed=0`）。

## 4. 第四节集群证据与第五节走查

`application-check` 报告：knowbench、knowlab 管理面 `"admin_list_read": true`（各 1 处，其余面 null）；knowmart 全 null（无管理面读项）。测试电脑 Pod 与抹码日志尾（`logs --tail=15` 抹 `user_code`/`code=` 后 grep 连接码零命中）：

```text
knowbench-test-computer-58bdd469cf-zdrt9   1/1     Running   0          5m10s
{"t":"2026-10-18T08:45:25.133Z","level":"info","msg":"sunmoon-link starting","version":"0.5.0","machine":"knowbot-test",…}
{"t":"2026-10-18T08:45:25.755Z","level":"info","msg":"relay connected"}
{"t":"2026-10-18T08:45:26.226Z","level":"info","msg":"stream closed","conn":"a8ceb572","why":"relay side close 1000"}
```

走查十行（所有者操作，Qwen 核截图与集群输出；截图避开 `code=`/`state=`）：

| 行 | 结论 | 证据 |
| --- | --- | --- |
| 1 目录首页 | 过 | 截图：页头全部/金融、左树证券/期货投资咨询·1、卡读表报营收·第 1 版·去工作台请、当前用户 zymun |
| 2 筛选与收起 | 过 | 三截图：`?updated=7d`+已选「近 7 天 ×」+重置筛选；重置后地址回 `/zh-CN/knowbots`、更新时间不限；收起→展开→刷新侧栏状态保持 |
| 3 详情页 | 过（所有者实操确认，无截图） | 五页签无「发布主体」、「方法的步骤（只有你自己看得到）」在；观察 O1：仅卡片标题字是链接（expert-catalog.tsx L386-390），所有者初点卡片空白无反应 |
| 4 跨应用请分身 | 过（所有者实操确认，无截图） | 工作台「请我的分身」→ knowmart「从工作台来」+「请这位」→ 回工作台候选可选读表报营收 |
| 5 真问一句 | 过 | 截图：工具链 list_my_data → read_my_data·ca0749ac-a810-4e06-ab7e-952b9cefe7e3（查了 2 次数据）；回块 text 含「营业收入,90,100」、citation{dataset_id,version:"1",sha256:c31ef87a…,page:1,pages:1}；交回行「这位专家不写成稿文件」且无「打开工作底稿」；runner `advisor stopped task=30bccaf0-38db-494b-8622-29fb16006639 state=SUCCEEDED`；观察 O2：回答以工具回块呈现、无独立总结段（与交回行口径一致，非缺陷判定） |
| 6 右栏收起/展开 | 过（所有者实操确认，无截图） | — |
| 7 北京时间 | 过（所有者实操确认，无截图） | — |
| 8 重测 v2 草稿 | **挡 → F1** | 见 §5；未重试、未绕道改状态 |
| 9 runs 目录证据 | **依赖挡** | 仅跑前基线：exec#1 18:29:37 `ls /workspace/runs` → `No such file or directory`（无目录）；本轮无测试运行 |
| 10 侧栏在线/离线 | 半 | zymun 半有据（行 4/5 截图侧栏「zymun 在线 就是这台」）；sig-am 半未做（所有者于行 8 挡后结束走查，是否补由 Opus 定） |

## 5. 发现 F1：failed 草稿无重测通路（行 8 挡根因，交 Opus）

- UI：`knowlab-admin-frontend app/components/knowbots/knowbot-drafts.tsx` L179-244 按钮行只按状态渲染——pending_test 未核对→核对、pending_test 已核对→发起测试、testing→刷新结果/退回、passed→交付；**failed 不渲染任何按钮**。
- 后端：`knowlab-backend app/app/application/services/knowbot_service.py` L170 状态机 `A {status} draft cannot become testing`；`reset_stuck` 只收 testing（L324）。
- 实测：所有者授权后以 admin 会话控制台发一次 `POST /api/admin/v1/knowbot-drafts/35f953ca-ced8-4c7d-8130-48799c871357/test`（即按钮同通路，预算 20/超时 1800）→ **409** `urn:sunmoonai:problem:draft_state`「A failed draft cannot become testing」。
- 结论：卡行 8「重测 v2 草稿 35f953ca」在当前钉住版本**无合法通路**（UI 与后端双拦）；需 Opus 定：给 failed 开重测（状态机+按钮），或改卡为按同清单建新草稿。qwen-005 的 sourced 修复是否生效因此**本轮未能验证**。

## 6. 现场与残留

- HEAD=`1cb30687`，origin 双远程同步；工作区无未提交改动；未跟踪仅走查截图目录 `docs/rename-tools/qwen005-walk/`、`r54-walk/walk-a-b-*.png`（按惯例不入库）。
- /tmp 残留一次性脚本与日志：`q006-s3.sh/.log`、`q006-status.log`、`q006-stage-knowmart.log`、`q006-plan-knowmart.log`、`q006-release.log`、`q006-apply.log`、`q006-s4.sh/.log`、`q006-check-{knowbench,knowlab,knowmart}.log`（DeleteFile 够不着 /tmp，按纪律不用 shell rm，如实报告；工位顶层无残留）。

第四节全 0、双推完成；走查 7 过（4 行所有者确认无截图）、行 8 挡（F1）、行 9 依赖挡、行 10 半。停下等 Opus 审。
