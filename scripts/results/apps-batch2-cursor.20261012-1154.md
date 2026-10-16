# Cursor 回执：卡 40 investment 批 2

时间：2026-10-12 11:54（UTC+8）。只在 luna 的 k8s 工作树。没有 push。浏览器侧边栏「全部 / + / 垃圾桶」目视与工作对话乱码、删对话/项目、托盘重连自动填码由所有者自测，不记本卡通过。

## 一、核对

| 项 | 结果 |
| --- | --- |
| HEAD（开工） | `a694f93a` |
| 工作区 | 干净 |
| investment 原钉 | 父 `fbfa61af…`、后端 `9174af2f…`、网页 `91f9f9f7…`；管理端 `b0f4c5de…` |
| config | `v5` / `'20261012_0016'` |
| 代理包 | 仍 `0.3.0` / `dbe5d01…` |
| `platform-status` | exit=0 |

## 二、改钉与迁移号

只动两份文件。investment：`parent=347e17a8…`、`backend=8d9bdd20…`、`web=c981e3a8…`；`v6` / `'20261012_0017'`；管理端两行不变。

本地源仓 `git fetch` 后 checkout：父 `347e17a`、后端 `8d9bdd2`、网页 `c981e3a`（做完后已切回 `luna` + submodule 复位）。

## 三、构建

PID 1 挂载命名空间注入 `OBJECT=app-platform/investment-app`：

| 项 | 结果 |
| --- | --- |
| BUILD_EXIT | 0 |
| backend | digest `sha256:227b7ae2a7e65bfca0a2e29bbe42933a95e85d160983e7c84d8feedc330455db`，source_revision `8d9bdd20…` |
| web | digest `sha256:c0c0076efb74316698bce651a56246cdc197ce6134a2dc3c22101923dae5a1a8`，source_revision `c981e3a8…` |
| admin lock | 未变（`sha256:7d8e65f69122…`） |

## 四、暂存与计划

| 步骤 | exit |
| --- | --- |
| `platform-stage`（注入 OBJECT） | 0 |
| PEM 扫描 | 无 |
| `application-deployment-plan` | 0，schema `20261012_0017` |

迁移 Job 名：`investment-migrate-227b7ae2a7e6-v6`。`agent-releases/config.yaml` 未改，仍 0.3.0。

## 五、提交

`b4be37fa` deploy(investment): 批 2 …（待办 40）

## 六、发布与晋级

| 步骤 | exit |
| --- | --- |
| `flux-release` | 0 |
| 候选 revision | `b4be37fa21f0bd18e5bb07c4826b363729fd4df5` |
| 候选 digest | `sha256:b42d976545c919fb299fd60b51fbf5244b04a1859bb7381fffb03e4f57f1f31a` |
| 晋级提交 | `dd02416d`；flux-source revision 仍为 stage 摘要 |
| `flux-source-apply` / `status` | 0 / 0 |

回退：`~/sunmoon-probe-runs/apps-batch2-040/`（不入库）。

## 七、检查

| 步骤 | exit |
| --- | --- |
| `application-check APP=investment` | 0 |
| 迁移 | check 核到 `investment-migrate-227b7ae2a7e6-v6` Completed |
| Pod | `investment-api-95b859f76-7dc7r`、`investment-web-d659655d5-8v28w`、admin/worker/scheduler Running |

## 本地提交

`b4be37fa` stage，`dd02416d` 晋级；本回执另提。不 push。

exit=0
