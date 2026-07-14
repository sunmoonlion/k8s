# V5-P0-007B Info Admin 真实业务试点

状态：`IN_PROGRESS`（迁移前基线已冻结；React 业务竖切已在本地实现，尚待依赖安装、浏览器/构建、隔离部署和真实后端验收）

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

React Admin v1 完整消费已冻结的 `tpl-admin-frontend@f24500f6d8f437a0162fa4939d3ed6b9b8ddbcf1` 工作树及其全部已验收通用、安全和生产能力，然后在 Info 现有仓库内增加领域页面与 typed adapter；不是只复制 Shell 或部分组件。Vue `src/pages/info/crawl.vue` 的真实业务薄切包含：

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

## 当前实现快照（未验收）

- 本地实现提交：Info Admin `e34c1774480da8acd27b60a57e8a35f0c130912a`；父仓指针 `info-app@e297396985d57fa766b52f073de95a9463b7722b`；canonical 模板通用修正 `tpl-admin-frontend@76cfd6d065bd97eef1156c750edf9b8af0607823`（父仓 `tpl-app@ad7e18827b163ce0c1bfa569895be09973703f3d`）。这些都是本地提交，尚未推送或发布。
- React 基线已在现有 `info-admin-frontend` 子仓库原地替换；旧 Vue 源码保留在迁移前 Git tag，不作为当前工作树运行时。
- 新增 `app/lib/info-api.ts`：所有领域请求显式走 `/api`，JSON mutation 自动声明 `Content-Type`，上传保持浏览器 multipart boundary；审计 mutation 由 correlation/operation/reason headers 传递。
- 新增 `app/routes/info-crawl.tsx` 和 `/info/crawl` 导航：URL crawl、source、collector/discover、上传、文档筛选/选择/版本、单条/批量审核、实体链接、摘要画像、Knowledge 分发/详情/dispatch/retry 均使用真实 API，不提供 mock success。
- 通用 `apiRequest` 的 JSON Content-Type 修正同步回 canonical React Admin 模板及其单元测试；该修正属于 template/common，不能把 Info DTO 或页面回流模板。
- 已增加 Info API adapter、导航和通用请求头测试；操作员安装 React 依赖后，Info `typecheck`、`lint` 和 `test` 已通过（11 files / 43 tests）。Docker/build 与隔离浏览器/真实后端门禁仍未验收。

## 验收前明确禁止

- 不把当前本地提交标记为 `P0-007B ACCEPTED`，不覆盖现有 `info-admin-frontend:1.0.1`，不修改正式 Ingress/流量。
- 必须先构建新的 candidate tag，在隔离 Deployment/Ingress 上验证首页、`/info/crawl`、未知 asset 404、CSP、严格 TLS、无 Node runtime，再做真实 Info backend contract/E2E；失败时删除隔离资源即可回到 Vue 基线。

## 回滚基线

1. 删除/回退隔离的 React Info Deployment，不触碰现有 Vue Deployment。
2. 将父仓 `info-app` 子模块恢复到 `c12022ee24a248477ebd6b7b37fbc9818d9693ff` 或 tag `p0-007b-info-admin-vue-baseline-20260714`。
3. 重新部署并确认镜像 tag `1.0.1`、digest `sha256:3ce28192f97bd38a46d47b3bc357b9d826f219cff79fa47bd05dbdb84180bc98`。
4. 通过现有 Info Admin 严格 TLS、session、403 和业务 smoke 后，才可关闭试点回滚窗口。

下一证据必须同时包含：React Info 实例提交、父仓指针、迁移镜像 tag+digest、隔离 Deployment/Ingress、真实后端 contract/E2E、失败矩阵和回滚演练。
