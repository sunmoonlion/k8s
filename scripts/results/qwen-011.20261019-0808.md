# qwen-011 回执：K19 重测前排雷——读年报不再卡超时线、换修好的 Excel（两个后端镜像）

时间：2026-10-19 08:08（本地 UTC+8）／集群 UTC 2026-10-19 00:08／执行者：Qwen（本地机）
卡：`docs/dev-investment-agent/switch-test/inbox/qwen/2026-10-19-qwen-011-before-retest.md`
本回执覆盖**第一到四节（部署）**；第五节 K19 重测（取代 qwen-009 第五节）等所有者早上来一起做，届时补记。

提交链（双远程 GitHub＋Gitee 均已到 `ae40cf6b`）：
- 拉取基线 `7afccc85`（卡要求 HEAD 到 7afccc85 或更新，达标）
- 部署提交 `4d2894e3`
- 晋级提交 `ae40cf6b`
- 本轮推送无分叉、一次到位；`flux-source.yaml` 的 `revision: 4d2894e3…` 正好等于部署提交（号面对上）。

---

## 一、核对（只读，全 exit=0）

- `git pull --ff-only origin qwen`：exit=0，HEAD `7afccc85`。
- 两父仓/子仓指针对卡逐字一致：
  - **knowbench**：父仓 `13f1f162`、后端 `9430f7dc`（9430f7dcd8fa74d583de1f05cb53fd45ee433936）；网页 `4748b94e`、管理端 `26964553` 不变。
  - **knowlab**：父仓 `a9a42286`、后端 `ded0470e`（ded0470e937260ff47070c9b8b82cd66c37bc486）；管理端 `a940b301`、网页 `a41861d7` 不变。
- `make -C infrastructure platform-status`：exit=0（`PLAY RECAP ok=7 failed=0`）。

## 二、改钉（6 行，exit=0）

- 卡内 python 改钉脚本 exit=0；`git diff --stat` 只动 `infrastructure/applications/sources.yaml`（1 file changed, 6 insertions, 6 deletions）；`git diff … | grep -c '^+ '` = **6**（knowbench 块 parent＋backend_parent＋backend 三字段、knowlab 块同三字段）。
- 两应用的 web_*、admin_* 字段及其它应用未动。

## 三、构建、暂存、计划（全 exit=0）

- `platform-build`：knowbench-app exit=0、knowlab-app exit=0（日志 `/tmp/q011-build-*.log`）。
- 变了的镜像锁 **2 个**：
  - `knowbench-app/knowbench-backend/image.lock.yaml`：`source_revision: 9430f7dcd8fa74d583de1f05cb53fd45ee433936`，`digest: sha256:af2a26b91993dd1b75a9f6b6820fc5b61cb6bb3f44a02de61356b531c9c46c46`
  - `knowlab-app/knowlab-backend/image.lock.yaml`：`source_revision: ded0470e937260ff47070c9b8b82cd66c37bc486`，`digest: sha256:f11889a801c412c331cb461b895d6805adce85eaa4c4f72b39ef9c3c9e7ca0f0`
- `platform-stage`：knowbench-app exit=0、knowlab-app exit=0；`key-check-done` 前无文件名（无私钥/公钥泄漏）。
- 暂存产物分布 `uniq -c`：`9 knowbench-backend` ＋ `8 knowlab-backend`（只这两个后端，网页/管理端/别的应用无变化）。
- 两段运行时 diff（除镜像与摘要外）各只有 `DEPLOYMENT_ID` 一行：
  ```
  knowbench-backend:  -  DEPLOYMENT_ID: "knowbench-backend-ac83f0eac23f116a"
                      +  DEPLOYMENT_ID: "knowbench-backend-af2a26b91993dd1b"
  knowlab-backend:    -  DEPLOYMENT_ID: "knowlab-backend-18f461d9e0ab3e8c"
                      +  DEPLOYMENT_ID: "knowlab-backend-f11889a801c412c3"
  ```
- `application-deployment-plan`：knowbench exit=0（迁移头 `20261017_0020`）、knowlab exit=0（迁移头 `20261018_0007`），两头均不变；各 `PLAY RECAP ok=16 changed=0 failed=0`。

## 四、提交、发布、晋级、检查（各步 exit=0）

- 部署提交：`git add infrastructure/applications/sources.yaml gitops` → commit `deploy: 读年报不再卡在超时线上（knowlab 抽完必进缓存、knowbench 读数超时 45 秒）（qwen-011）`，exit=0，得 `4d2894e3`。
- `flux-release`：exit=0（`PLAY RECAP ok=30 changed=8 failed=0`）。
- 晋级：`sudo tee` 写 `flux-source.yaml` → commit `release(kind): 晋级到 4d2894e3（qwen-011）`，exit=0，得 `ae40cf6b`。
  - `flux-source.yaml`：`repository: oci://harbor.sunmoonai.com:30443/platform/deployments-kind`、`digest: sha256:731dbdd18098922339225a5dcd634846b092dcdbd014ee499bb684b9ca22a61c`、`revision: 4d2894e389b4bf96d6da42dac89344b27c54ff2a`（= 部署提交）。
- `flux-source-apply`：exit=0（`PLAY RECAP ok=38 changed=3 failed=0`）。
- kustomization 等待：`wait exit=0`，13 个 `knowbench-*` ＋ 11 个 `knowlab-*` 共 24 个全部 `condition met`。
- `application-check`：knowbench exit=0（`admin_list_read: true`，`ok=50 failed=0`）；knowlab exit=0（`admin_list_read: true`，`ok=50 failed=0`）。
- 测试电脑：`knowbench-test-computer-58bdd469cf-zdrt9  1/1  Running  0  15h`。
- `git push origin qwen`：一次成功无分叉，双远程各 `7afccc85..ae40cf6b  qwen -> qwen`；`git rev-parse HEAD` = `origin/qwen` = `ae40cf6be23813200433d81a6721ba4823e3f307`。
- **两后端新镜像在线核实**（补证）：
  - knowbench-backend `@sha256:af2a26b9…`（= 镜像锁）跑在 `knowbench-api`／`knowbench-runner`／`knowbench-worker`，全命名空间命中该 digest 的 Pod **9** 个——**含 runner**（判分/验收所在），qwen-009 判分修复＋本轮读数超时 45 秒均在。
  - knowlab-backend `@sha256:f11889a8…`（= 镜像锁）跑在 `knowlab-api`／`knowlab-worker`，命中该 digest 的 Pod **7** 个——**含 knowlab-api**（年报抽取所在），本轮「抽取单独跑成任务、抽完必进缓存」已在线。

## K19 挂着那次测试（未动，已自行超时收尾）

- 全程未点「超时退回」、未改库；只读核库确认它已按时自然收尾：
  `knowlab-433a5349-5301-41da-ad59-3c5db794c4c2-1 | status=timeout | started 2026-10-18 14:55:29Z | finished 2026-10-18 22:55:32Z | timeout_seconds=28800`
  （finished−started = 28800 秒整，与卡「约 22:55Z 自己超时收尾」一致；部署滚 runner 未影响它按时收尾。）
- 第五节重测的前提（第 1 稿已终态）因此已就绪。

## exit 汇总

| 步骤 | exit |
| --- | --- |
| pull --ff-only | 0 |
| knowbench-app / knowlab-app fetch·pull·submodule | 0 / 0 |
| platform-status | 0 |
| 改钉 pin | 0 |
| platform-build（knowbench / knowlab） | 0 / 0 |
| platform-stage（knowbench / knowlab） | 0 / 0 |
| application-deployment-plan（knowbench / knowlab） | 0 / 0 |
| 部署 commit | 0 |
| flux-release | 0 |
| 晋级 commit | 0 |
| flux-source-apply | 0 |
| kustomization wait | 0 |
| application-check（knowbench / knowlab） | 0 / 0 |
| git push | 0 |

## 第五节 K19 重测（待补，与所有者一起做）

第 1 稿已超时收尾，重测前提就绪。9 行（所有者操作、登录由所有者输入；我核截图、跑命令、看日志）：① 管理端硬刷新，「财务分析与预测」→「刷新结果」→ 第 1 稿「测试未通过」（超时收尾）；② web端（sig-am）「我的数据」上传修好的 Excel（远程机 `/home/zym/sig-am-data/财务分析与预测/修订-2026-10-19/贵州茅台-三张表与主要会计数据.xlsx`，sha256 `517c8810f36e2f2f7274510d163fcf0318396b6fb1602e81bd438f01b5ddec0c`）；③ 管理端「用户的数据」找 sha256 `517c8810…` 那行、抄 `dataset_id` 给我（sha256 逐字对上）；④ 我用新编号跑 `manifest_v1.py` 生成 `manifest-v1.json`（`data_bindings` 第 1 条为新编号＋sha256 `517c8810…`，5 份年报编号不变），检查合法后提交推送、回执写它的 sha256；⑤ 所有者把清单全文贴进「建下一稿」→「第 1 版 · 第 2 稿」、规则出处 14 条；⑥「已逐条核对出处」→ 预算 300、超时 28800 →「发起测试」；⑦ 我在集群侧开跑后约 15 分钟、之后每小时取 runner 日志（`logs deploy/knowbench-runner --since=70m | grep -E "advisor (stopped|crashed)|knowbot test|budget exhausted"`），核无 `advisor crashed`、有 `advisor stopped`、终态 `knowbot test run finished`；⑧ 所有者测试结束后截图三条用例结论、「期望满足 x/y」、没过的步骤与原因原文、花费与结束时间、状态；⑨ 测试中若冒「待回答的问题」不在管理端「改由我们答」，截图交所有者用 sig-am 在 web端回答。走查齐后补记，再提交推送停等 Opus 审。
