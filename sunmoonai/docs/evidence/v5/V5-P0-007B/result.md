# V5-P0-007B Info Admin 真实业务试点

状态：`IN_PROGRESS`（迁移前基线已冻结，尚未替换业务前端）

## 迁移前基线

- Info Admin 子仓库：`info-admin-frontend`
- 远程仓库：`https://gitee.com/sunmoonlion/info-admin-frontend.git`
- 当前分支：`codex-1`
- Vue 源码提交：`c12022ee24a248477ebd6b7b37fbc9818d9693ff`
- 迁移前 tag：`p0-007b-info-admin-vue-baseline-20260714`
- 父仓指针：`info-app@cd488aa`
- 当前 Deployment 镜像：`harbor.sunmoonai.com:30443/app-images/info-admin-frontend:1.0.1`
- 当前运行 Pod digest：`sha256:3ce28192f97bd38a46d47b3bc357b9d826f219cff79fa47bd05dbdb84180bc98`
- 当前 Pod：`info-admin-frontend-7669774c99-jj2zj`，Ready=`true`
- 当前 Deployment generation：`9`

创建 tag 和读取 Deployment 均未修改业务代码、Deployment 或流量配置。

## 业务迁移范围

React Admin v1 只消费已冻结的 `tpl-admin-frontend@f24500f6d8f437a0162fa4939d3ed6b9b8ddbcf1`，然后在 Info 现有仓库内增加领域页面与 typed adapter。Vue `src/pages/info/crawl.vue` 的真实业务薄切包含：

- 文档列表：关键词/状态筛选、刷新、选中和版本列表。
- 来源/Collector/URL crawl/文件上传创建操作。
- 文档审核：单条、批量、审核人、原因、状态。
- 实体链接与摘要画像保存。
- Knowledge 分发：创建、查询、详情、dispatch、retry。
- 对应 API：`/documents`、`/documents/{id}/versions`、`/documents/{id}/review`、`/documents/{id}/entity-links`、`/documents/{id}/summary-profile`、`/admin/crawl-jobs`、`/admin/sources`、`/admin/collectors`、`/admin/collectors/{id}/discover`、`/admin/uploads`、`/admin/distributions`、`/admin/distributions/knowledge`、`/admin/distributions/{id}/dispatch`、`/admin/distributions/{id}/retry`。

模板中的富组件、菜单、权限、Query、错误、审计 mutation、上传/下载等通用能力必须复用；业务 DTO 和 Info 规则只进入 Info 子仓库，不能回流模板。

## 不进入本任务

- Vue `components/**`、`directives/**` 纯展厅页不复制；能力已由模板矩阵和 A2.4/A2.5 证据覆盖。
- PWA/Electron、纯 about/demo 页面不进入业务迁移主链。
- 不修改 Knowledge/Research Admin，不批量同步，不切换正式入口流量。

## 回滚基线

1. 删除/回退隔离的 React Info Deployment，不触碰现有 Vue Deployment。
2. 将父仓 `info-app` 子模块恢复到 `c12022ee24a248477ebd6b7b37fbc9818d9693ff` 或 tag `p0-007b-info-admin-vue-baseline-20260714`。
3. 重新部署并确认镜像 tag `1.0.1`、digest `sha256:3ce28192f97bd38a46d47b3bc357b9d826f219cff79fa47bd05dbdb84180bc98`。
4. 通过现有 Info Admin 严格 TLS、session、403 和业务 smoke 后，才可关闭试点回滚窗口。

下一证据必须同时包含：React Info 实例提交、父仓指针、迁移镜像 tag+digest、隔离 Deployment/Ingress、真实后端 contract/E2E、失败矩阵和回滚演练。
