# Architecture v2 R2 模板仓库改名事务

日期：2026-08-01

结果：`PASSED`

## 事务

```text
Gitee: sunmoonlion/tpl-admin-backend -> sunmoonlion/tpl-backend
tpl-app: tpl-admin-backend -> tpl-backend
```

采用 Gitee 原地改名，没有创建空仓、复制历史或 force push。

## 前置锁

- 源 `architecture-v2`：`69e634b8e5b06da9d1dcd01c9b1350e0571d74bd`；
- source/master/architecture-v2/`pre-architecture-v2-20260801` 均已核对；
- 目标 `tpl-backend` 在改名前明确返回 404；
- 父仓和子仓均无未提交内容。

## 结果验证

- Gitee PATCH 返回 HTTP 200，目标 path 为 `tpl-backend`；
- 新旧 Git URL 的全部 9 个 refs 完全一致；
- 本地 `origin`、tpl-app `.gitmodules`、gitlink 与子模块配置均指向新 URL；
- tpl-app 改名提交：`2ed40a5`，已推送 `architecture-v2`；
- clean clone 后 `tpl-backend` 检出：

```text
head=69e634b8e5b06da9d1dcd01c9b1350e0571d74bd
origin=https://gitee.com/sunmoonlion/tpl-backend.git
parent_clean=true
```

旧 URL 当前由 Gitee redirect 到相同 refs，仅作为迁移兼容；所有新配置必须使用新 URL。

## 下一步边界

允许在 `tpl-backend/architecture-v2` 进入能力清单驱动的代码合并。`tpl-web-backend` 仍保持
`compatibility-only`，在模板配对、迁移链和 KIND 门禁完成前不得归档或删除。
