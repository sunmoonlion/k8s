# Cursor 回执：卡 38 investment 批 1

时间：2026-10-12 09:25（UTC+8）。只在 luna 的 k8s 工作树。没有 push。浏览器侧边栏树形与标签由所有者目视，这里不记通过。

## 一、核对

| 项 | 结果 |
| --- | --- |
| HEAD（开工） | `951e8134` |
| 工作区 | 干净 |
| investment 原钉 | 后端 `982b216d…`、网页 `18e4268b…`；管理端 `b0f4c5de…` 不动 |
| config | `v4` / `'20261009_0014'` |
| `platform-status` | exit=0 |

卡内 Python 用 `\n  ` 截块会误匹配四空格缩进，sources 未改上；已按同一目标 revision 用正则只改 investment 块五处钉。

## 二、改钉与迁移号

只动两份文件。investment：`parent=fbfa61af…`、`backend=9174af2f…`、`web=91f9f9f7…`；`v5` / `'20261012_0016'`；管理端两行不变。

本地 investment 源仓原先无这些对象：已 `git fetch` 并 checkout 到钉住提交（父仓 `fbfa61af`，后端 `9174af2`，网页 `91f9f9f`）。

## 三、构建

裸 `make platform-build` 时 nsenter 的 `env PATH=…` 丢掉 `OBJECT`（exit=2）。在 PID 1 挂载命名空间注入 `OBJECT=app-platform/investment-app` 后：

| 项 | 结果 |
| --- | --- |
| BUILD_EXIT | 0 |
| backend lock | digest `sha256:9282cde9c6f79d371c225c290f2caab029ef19f23bf148cd14069fe671f00e9c`，source_revision `9174af2f…` |
| web lock | digest `sha256:759204edfab06810dcf635b6242adef760cd80f1c05b75ecc7587bccd65bc097`，source_revision `91f9f9f7…` |
| admin lock | 未变 |

## 四、暂存与计划

| 步骤 | exit |
| --- | --- |
| `platform-stage OBJECT=app-platform/investment-app`（注入 OBJECT） | 0 |
| PEM 扫描 | 无 |
| `application-deployment-plan APP=investment` | 0，schema `20261012_0016` |

迁移 Job：`investment-migrate-9282cde9c6f7-v5`；后端镜像换成 `9282cde9…`。

## 五、提交

`44cd7b1d` deploy(investment): 批 1 …（待办 38）

## 六、发布与晋级

| 步骤 | exit |
| --- | --- |
| `flux-release` | 0 |
| 候选 revision | `44cd7b1d0a7f8ed81bfce844ab5d7454ee3437e3` |
| 候选 digest | `sha256:df74f9a122302ff69bb558095b2fa40ed4153017932220b6e2ca1758cd47f11e` |
| 晋级提交 | `ca439e5d` release(kind): 晋级到 44cd7b1d（待办 38）；flux-source revision 仍为 stage 摘要 |
| `flux-source-apply` | 0 |
| `flux-source-status` | 0 |

回退材料：`~/sunmoon-probe-runs/apps-batch1-038/flux-source.yaml.before`（不入库）。

## 七、检查

| 步骤 | exit |
| --- | --- |
| `application-check APP=investment` | 0 |
| 迁移 Job | `investment-migrate-9282cde9c6f7-v5-59vxh` Completed |
| 运行中 | `investment-api-c5b9c7686-ktp5t`、既有 admin 等 Running |

浏览器侧边栏「电脑 → 工作区 → 项目」与顶部三标签未在本回执做目视确认。

## 本地提交

`44cd7b1d` stage/部署，`ca439e5d` 晋级；本回执另提一次。不 push。

exit=0
