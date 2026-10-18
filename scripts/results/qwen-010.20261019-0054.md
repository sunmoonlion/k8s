# qwen-010 回执：knowlab 管理端「专家草稿」页重排（一个镜像）

时间：2026-10-19 00:54（本地 UTC+8）／集群 UTC 2026-10-18 16:37 部署完成／执行者：Qwen（本地机）
卡：`docs/dev-investment-agent/switch-test/inbox/qwen/2026-10-19-qwen-010-knowbots-layout.md`
本回执覆盖**第一到四节（部署）**；第五节走查等所有者早上看新页面时做（并接 qwen-009 第五节 K19 重测），届时补记。

提交链（双远程 GitHub＋Gitee 均已到 `cfd05c68`）：
- 拉取基线 `fb1b908e`（卡要求 HEAD 到 fb1b908e 或更新，达标）
- 部署提交 `2cbc50ad`
- 晋级提交 `cfd05c68`
- 本轮推送无分叉、一次到位；`flux-source.yaml` 的 `revision` 正好等于部署提交 `2cbc50ad`——qwen-009 遗留的孤儿 revision 标签随本轮 `flux-release` 重新生成而自然对上（Opus 预判一致），无需单独重跑。

---

## 一、核对（只读，全 exit=0）

- `git pull --ff-only origin qwen`：exit=0，HEAD `fb1b908e`（快进带入本卡文件）。
- knowlab 父仓/子仓指针对卡逐字一致：
  - 父仓 `cf675d71`（cf675d71b7c2a0a20381380a3aabff2c1c94effb）
  - 管理端 `a940b301`（a940b301d43edd900075e75edf96136aeb5cc7c7）
  - 后端 `836587c8`（不变）
  - 网页 `a41861d7`（不变）
- `make -C infrastructure platform-status`：exit=0（`PLAY RECAP ok=7 failed=0`）。

## 二、改钉（3 行，exit=0）

- 卡内 python 改钉脚本 exit=0；`git diff --stat` 只动 `infrastructure/applications/sources.yaml`（1 file changed, 3 insertions, 3 deletions）；`git diff … | grep -c '^+ '` = **3**（knowlab 块：parent_revision 1 + admin_parent_revision 1 + admin_revision 1）。
- 后端、网页及其它应用字段未动。

## 三、构建、暂存、计划（全 exit=0）

- `platform-build OBJECT=app-platform/knowlab-app`：exit=0（日志 `/tmp/q010-build.log`；管理端 `image.lock.yaml: digest sha256:1b53dc282437 source a940b301d43e`）。
- 变了的镜像锁 **1 个**：
  - `gitops/components/app-platform/knowlab-app/knowlab-admin-frontend/image.lock.yaml`：`source_revision: a940b301d43edd900075e75edf96136aeb5cc7c7`，`digest: sha256:1b53dc282437c968385c425448af1d03e36402823c9e99ec4a8891fc34edb854`
- `platform-stage`：exit=0；`key-check-done` 前无文件名（无私钥/公钥泄漏）。
- 暂存产物分布 `uniq -c`：`2 components/app-platform/knowlab-app/knowlab-admin-frontend`（只管理端，后端/网页/别的应用无变化）。
- `application-deployment-plan APP=knowlab`：exit=0（日志 `/tmp/q010-plan.log`）；迁移头 `20261018_0007`（无新迁移，与卡一致）；`PLAY RECAP ok=16 changed=0 failed=0`。

## 四、提交、发布、晋级、检查（各步 exit=0）

- 部署提交：`git add infrastructure/applications/sources.yaml gitops` → commit `deploy: knowlab 管理端专家草稿页重排（qwen-010）`，exit=0，得 `2cbc50ad`。
- `flux-release`：exit=0（`PLAY RECAP ok=30 changed=8 failed=0`）。
- 晋级：`sudo tee` 写 `infrastructure/environments/kind/flux-source.yaml` → commit `release(kind): 晋级到 2cbc50ad（qwen-010）`，exit=0，得 `cfd05c68`。
  - `flux-source.yaml`：`repository: oci://harbor.sunmoonai.com:30443/platform/deployments-kind`、`digest: sha256:60755aa6658967e1f97fb6d44034d32927f57f9f85521164d89a605e64f9f4d3`、`revision: 2cbc50add80c9c058cfc2724d7be4a29ea80e980`（= 部署提交，号面对上）。
- `flux-source-apply`：exit=0（`PLAY RECAP ok=38 changed=3 failed=0`）。
- kustomization 等待：`wait exit=0`，11 个 `knowlab-*` kustomization 全部 `condition met`。
- `application-check APP=knowlab`：exit=0；`admin_list_read: true`（另一处 null）；`PLAY RECAP ok=50 changed=0 failed=0`。
- `git push origin qwen`：一次成功无分叉，双远程各 `fb1b908e..cfd05c68  qwen -> qwen`；`git rev-parse HEAD` = `origin/qwen` = `cfd05c6852390fd800c81758a8e205d3e1e3193e`。
- **管理端新镜像在线核实**（补证）：`knowlab-admin` deploy 容器镜像 `harbor.sunmoonai.com:30443/platform/knowlab-admin-frontend@sha256:1b53dc282437c968385c425448af1d03e36402823c9e99ec4a8891fc34edb854`，与镜像锁逐字一致；Pod `knowlab-admin-584c476cd7-qsfjg 1/1 Running 6m18s`（本轮刚滚）。

## K19 挂着那次测试（未动）

- 照卡与 qwen-009，全程未点「超时退回」、未改库；等它 28800 秒到约 22:55Z（本地 06:55）自行超时收尾。

## exit 汇总

| 步骤 | exit |
| --- | --- |
| pull --ff-only | 0 |
| knowlab-app fetch/pull/submodule | 0 |
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
| application-check（knowlab） | 0 |
| git push | 0 |

## 第五节走查（待补）

等所有者早上看新页面时做，浏览器先硬刷新（免得还是旧包）。5 行：① 「专家草稿」页左边提交列表＋一排筛选（全部/要我们动手/测试中/未通过/已交付，各带个数）、右边选中想法；② 点「财务分析与预测」→ 右边标题旁状态、一排进度、「下一步」卡片（22:55Z 前是「测试中」，有「刷新结果」「超时退回」、开跑时间与已跑几分钟）；③ 点「刷新结果」→ 页面不跳、不用往回翻，按钮旁出现「上次刷新 …」；④ 页签「验收用例」（表格，第 1 条 2024 营业收入 170899152276.34、允许误差 0.001）「用户的数据」（附可照抄 data_bindings）「历次草稿」（各稿状态）；⑤（22:55Z 后接 qwen-009 第五节）第 1 稿超时收尾刷新→「测试未通过」，结果在上、「建下一稿」清单框在下，在同一张卡片里贴清单建第 2 稿→核出处→发起测试。走查齐后补记每行截图描述，再提交推送停等 Opus 审。
