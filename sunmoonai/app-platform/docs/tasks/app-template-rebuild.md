# 任务：统一 App 模板并重新实例化业务 App

## 1. 目标

以 `tpl-app` 为唯一工程模板，完整保留 Python/FastAPI、NestJS、Vue 和 Next.js
四个组件，并统一数据库、S3、Elasticsearch、构建和 Kubernetes 部署能力。

## 2. 当前进度

- [x] `tpl-app` 两个 Backend 默认具备 PostgreSQL、MongoDB、Redis、S3 和 Elasticsearch 接入能力。
- [x] 新增完整 App Kubernetes 脚手架和 `deploy-<app>-all` 统一入口。
- [x] 支持 `KIND`、`C1` 等集群分别控制四个组件是否运行。
- [x] 从当前模板重新实例化 `info-app`、`research-app`、`investment-app` 和 `tools-app`。
- [x] 四个 App 均保持父仓库加四个子仓库的 Git 结构。
- [x] 四个 App 的 Kubernetes 部署目录已重新生成。
- [x] Kind 中八个 Backend 的 PostgreSQL、MongoDB、Redis、S3 和 Elasticsearch 资源已创建。
- [ ] 完成四个 App 的具体业务配置、镜像构建与 Pod 部署验证。
- [ ] 检查平台对 `llm-app` 的依赖后删除其源码、Kubernetes 部署和文档引用。
- [ ] 全部验证完成后统一整理提交并覆盖远程历史。

## 3. Git 操作约束

在全部改造和验证完成前：

- 不向远程仓库推送。
- 不删除本地重建备份。
- 不提前改写父仓库或子仓库的远程历史。

最终发布时按以下顺序执行：

1. 先提交并推送各 App 的四个子仓库。
2. 再提交父仓库，使 Gitlink 指向已经存在于远程的子仓库提交。
3. 核对 `.gitmodules`、远程地址和父仓库 Gitlink。
4. 经人工确认后，才对目标远程分支执行强制覆盖。

强制覆盖必须使用带租约保护的方式，并在执行前再次确认目标仓库、分支和远程状态。

## 4. 备份

本轮重新实例化前的源码和 Kubernetes 目录保存在：

```text
/home/zymun/.local/share/sunmoonai/rebuild-backups/20260612-1610
```

远程覆盖完成且新版本稳定运行前，不删除该备份。

## 5. 后续删除 llm-app

`llm-app` 暂不在本轮直接删除。删除前必须先完成：

1. 搜索 `info-app`、`research-app`、`investment-app`、`tools-app` 和平台部署入口中的调用与配置引用。
2. 明确 RAGFlow 及其他大模型能力迁移后的归属。
3. 删除 App Platform 总部署入口中的组件注册。
4. 删除源码和 Kubernetes 资源后更新总体架构、数据所有权、ADR 和任务文档。
5. 分别验证 Kind 和远程集群重建流程不再依赖 `llm-app`。
