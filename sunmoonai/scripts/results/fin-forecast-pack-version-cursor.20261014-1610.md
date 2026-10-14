# Cursor 回执：卡 47 新委托绑现在上架的专家版本 + 打回说出为什么

时间：2026-10-14 16:10（UTC+8）。`application-check APP=investment` 退出 0。没有 push，没有移动本待办。真人验收由所有者做。

先前停步回执 `fin-forecast-pack-version-cursor.20261014-1551.md`（`exit=1`）：当时工位 HEAD 已超前到卡 48 钉。续跑时临时检出卡 47 三钉后发布，结束后已拨回 `qwen` 尖。回退材料在 `~/sunmoon-probe-runs/fin-forecast-pack-version-047/`，未使用。

## 前提

`~/worktrees/qwen/k8s` 分支 `qwen`。改钉：父仓 `cf7dfaaa…`、后端 `e937bbaa…`、网页 `6321e7c8…`；管理端仍 `b0f4c5de…`。config 仍 `v7` / `'20261012_0018'`。无新迁移。`platform-status` 0。

## 步骤

| 步骤 | exit | 结果 |
| --- | --- | --- |
| 改钉（父仓 + 后端两行 + 网页两行） | — | admin 未动 |
| `platform-build OBJECT=app-platform/investment-app` | 0 | 后端 `sha256:02f1054f…` / `e937bbaa…`；网页 `sha256:ef7b59b3…` / `6321e7c8…`；管理端「已是这一份」 |
| `platform-stage` / `application-deployment-plan` | 0 / 0 | 迁移 `investment-migrate-02f1054f2a0f-v7`；schema `20261012_0018` |
| stage 提交 | `b368c6cf` | `deploy(investment): 新委托绑现在上架的专家版本，打回时说出为什么（待办 47）` |
| `flux-release` | 0 | 候选 digest `sha256:a5741c88…`，revision `b368c6cf…` |
| 晋级提交 | `8de81580` | flux-source = 候选 |
| `flux-source-apply` / `status` | 0 / 0 | |
| `application-check APP=investment` | 0 | PLAY RECAP failed=0；迁移 Job Complete；网页 Pod 已换新 |

## 本地提交

`b368c6cf` stage，`8de81580` 晋级；本回执另提。投资父仓/后端/网页已拨回 `qwen`。不 push。

exit=0
