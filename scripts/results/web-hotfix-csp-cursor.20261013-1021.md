# Cursor 回执：卡 43 网页热修 CSP 放行本机代理回环口

时间：2026-10-13 10:21（UTC+8）。做完。没有 push，没有移动本待办。真人刷新网页看文件树由所有者做，不记为本卡通过。

完成到：`application-check APP=investment` 退出 0。回退材料在 `~/sunmoon-probe-runs/web-hotfix-csp-043/`，未使用。

## 前提

`~/worktrees/fable/k8s` 分支 `fable`，工作区干净。改钉前：父仓 `99e92f56…`、后端 `e73ffa5e…`、网页 `27f6b9b3…`。`platform-status` 0。

## 步骤

| 步骤 | exit | 结果 |
| --- | --- | --- |
| 改钉（父仓 + 网页两行） | — | 后端仍 `e73ffa5e…`；admin 未动 |
| `platform-build OBJECT=app-platform/investment-app` | 0 | 仅网页锁变：`sha256:a5bfbb79…` / `309e73d5…`；后端「已是这一份」`sha256:6a189617…` |
| `platform-stage` / `application-deployment-plan` | 0 / 0 | 只动 sources + 网页 lock/workload；schema `20261012_0018`；迁移仍 `investment-migrate-6a189617e8ee-v7` |
| stage 提交 | `191a4332` | `deploy(investment): 网页热修 CSP …（待办 43）` |
| `flux-release` | 0 | 候选 digest `sha256:cc073bda…`，revision `191a4332…` |
| 晋级提交 | `029033ad` | flux-source = 候选 |
| `flux-source-apply` / `status` | 0 / 0 | |
| `application-check APP=investment` | 0 | PLAY RECAP failed=0 |

## 本地提交

`191a4332` stage，`029033ad` 晋级；本回执另提。不 push。

exit=0
