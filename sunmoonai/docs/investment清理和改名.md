# Investment 应用清理与重建迁移方案

> 状态：旧 investment 清理已完成；`research-app` → `investment-app` 重构暂缓。
>
> 当前前置条件：新版 `tpl-app` 完成、验证并冻结后，才允许启动后续重构与迁移。

## 1. 目标

将现有 `research-app` 的业务能力迁移到一个以新版 `tpl-app` 为底座的全新 `investment-app`，并清理旧的 investment 实例与部署资源。

最终正式名称统一使用完整的 `investment`，不使用 `inv` 作为长期系统名称。

目标仓库和部署对象包括：

```text
investment-app
investment-admin-backend
investment-web-backend
investment-admin-frontend
investment-web-frontend
celeryworker-investment-admin-backend
nodebullworker-investment-web-backend
```

## 2. 当前状态与约束

- 当前开发基线为 `architecture-v2`。
- GitHub 为主 remote，Gitee 为备份/迁移 remote。
- GitHub 与 Gitee 的 `architecture-v2` 必须在执行前保持同一 SHA。
- 现有 `research-app` 在迁移验收完成前必须保留，作为业务来源和回滚基线。
- 旧 `investment-app` 的本地代码、KIND 运行资源、PVC/PV 和 Harbor 镜像仓库已完成清理；Gitee `investment-app` 源码仓库按计划保留，供未来新仓库覆盖使用。
- 清理操作仅针对 WSL 本机和当前 KIND 集群；不再主动维护或同步 aly-ecs。
- 本方案不允许在新版 `tpl-app` 冻结前执行。

## 3. 当前仍暂不执行的事项

在模板完成并冻结前，禁止执行以下后续操作：

- 删除 `research-app`；
- 覆盖 Gitee `investment-app` 仓库；
- 强制推送新的 investment 分支；
- 修改生产或共享环境中的域名和数据绑定。

已清理工作的临时归档目录 `/tmp/investment-app-cleanup-20260808` 在确认无回滚需求前保留，不作为新应用代码来源。

## 清理结果（已完成）

- WSL 本机旧 investment 工作区已移出，临时归档位于 `/tmp/investment-app-cleanup-20260808`。
- `k8s/sunmoonai/app-platform/investment-app` 及其旧部署配置已移除；平台默认应用列表已收敛为 `info`、`knowledge`、`research`。
- KIND 中旧 investment 的 Deployment、Service、IngressRoute、worker、配置、凭据、任务、RBAC、PVC 和释放后的 PV 已清理。
- Harbor 中四个旧 investment 镜像仓库已删除；Harbor 后台配额统计若未立即下降，需等待 registry 垃圾回收完成后再复核。
- Gitee `investment-app` 仓库未删除、未覆盖、未强推；待新模板应用验收完成后再按本方案执行覆盖。
- `research-app` 保持不变，继续作为业务迁移来源和回滚基线。

## 4. 阶段 A：执行前冻结与备份

启动迁移前必须完成：

1. 冻结新版 `tpl-app` 的 `architecture-v2` 提交。
2. 验证模板的前端、后端、worker、部署和配对测试。
3. 记录五个相关仓库的 HEAD、remote、分支和工作区状态。
4. 记录旧 `investment-app` 的所有远程分支、tag 和提交。
5. 对旧 Gitee 仓库创建备份 tag，并保存本地裸仓库和 `git bundle`。
6. 导出旧 investment 的 Kubernetes 资源清单。
7. 备份数据库、PVC、对象存储和 Redis 中需要保留的数据。

任何一项未完成，都不得进入清理阶段。

## 5. 阶段 B：清理旧 investment-app

### 5.1 代码目录

清理前确认以下目录是否存在，并完成归档：

```text
/home/zym/investment-app
/home/zymun/investment-app
```

不得直接删除未归档的工作区或 Git 仓库。

### 5.2 KIND 应用资源

清理旧的 investment 应用运行资源：

- Deployment；
- Service；
- IngressRoute/Ingress；
- ConfigMap；
- Secret；
- Job/CronJob；
- Celery worker；
- NodeBull worker；
- ServiceAccount、Role、RoleBinding；
- NetworkPolicy；
- PodDisruptionBudget。

### 5.3 数据资源

第一轮只清理应用运行资源，默认保留：

- PostgreSQL 数据库；
- PVC；
- 对象存储 bucket；
- Redis 数据和队列。

数据资源只有在备份、迁移和回滚窗口均通过后，才能单独审批删除。

### 5.4 清理退出条件

- KIND 中不再存在旧的 `investment-*` 工作负载；
- 没有旧入口、Service、worker 和定时任务；
- 数据库/PVC/对象存储的保留策略有记录；
- 清理前后资源清单已保存。

## 6. 阶段 C：从新版 tpl-app 创建 investment-app

新应用必须以冻结后的新版 `tpl-app` 为唯一底座，不得以旧 `research-app` 复制改名。

模板应先完成并冻结：

- Next.js admin 前端；
- Next.js web 前端；
- FastAPI admin/web 后端；
- 前后端配对协议；
- Casdoor 认证；
- 通用组件和布局；
- 请求层、错误边界、国际化和主题；
- 数据库迁移、健康检查和 worker 基线；
- Docker/Kubernetes 部署和测试脚本。

新 `investment-app` 初始只包含模板通用能力，暂不混入旧 research 代码。

## 7. 阶段 D：迁移 research 业务逻辑

`research-app` 仅作为业务来源，按边界迁移，不直接复制整个仓库。

### 7.1 后端迁移范围

迁移：

- 领域模型；
- API 路由；
- Service/use-case；
- Repository；
- 数据库迁移；
- 异步任务；
- 业务配置；
- 业务测试。

不直接迁移：

- research 仓库 Git 历史；
- 旧部署名称；
- 旧镜像标签；
- 已废弃的 Runtime/SSE 实验代码；
- 与模板能力重复的旧基础设施。

### 7.2 前端迁移范围

迁移：

- admin 业务页面；
- web 业务页面；
- 业务组件和交互；
- 表单、列表、详情和状态流；
- 业务 API 对接；
- 业务级菜单和权限。

继续使用模板提供的：

- Next.js 运行模式；
- 统一组件库；
- Layout；
- 认证流程；
- 请求层；
- 错误边界；
- 国际化和主题；
- 通用权限框架。

### 7.3 命名迁移范围

必须系统检查并按需替换：

- `research` 目录和包名；
- Python import/package；
- 环境变量；
- 数据库名和迁移标识；
- Redis key；
- S3/object-storage key 前缀；
- Kubernetes resource name 和 label；
- Service DNS；
- 镜像仓库和标签；
- API 路径；
- 前端路由；
- 文档、测试和 CI/CD 脚本。

## 8. 阶段 E：新 investment 验证

必须按以下顺序验收：

1. 模板基础测试；
2. 后端单元测试；
3. 前端 typecheck、lint、build；
4. 数据库迁移；
5. admin 前后端配对测试；
6. web 前后端配对测试；
7. Casdoor 登录和退出；
8. worker 和任务重试；
9. API 契约测试；
10. Docker/Nginx/Next 运行时测试；
11. KIND 部署测试；
12. E2E 和故障恢复测试。

退出条件：

- admin/web 前后端均能正常运行；
- 业务 API 完整连通；
- 数据迁移通过；
- 镜像使用不可变 digest；
- KIND 资源全部使用 `investment-*` 命名；
- 旧 research 仍可作为回滚基线。

## 9. 阶段 F：覆盖 Gitee investment-app 仓库

只有阶段 E 全部通过后才能覆盖旧 Gitee 仓库。

覆盖前必须：

1. 创建旧仓库备份 tag；
2. 保存旧分支和 tag 清单；
3. 保存裸仓库和 `git bundle`；
4. 确认没有其他开发者正在使用旧仓库；
5. 确认新仓库工作区干净；
6. 确认新分支 SHA 和验收记录一致。

强制推送使用：

```text
git push --force-with-lease
```

禁止无保护地使用 `git push --force`。

推荐远程结果：

```text
Gitee investment-app
  architecture-v2 = 新 investment 基线
  master          = 验收后的稳定基线
```

## 10. 阶段 G：迁移到 GitHub

Gitee 覆盖并验证成功后：

1. 创建或确认 GitHub `investment-app` 仓库；
2. 从 Gitee 拉取并核验提交；
3. 推送 `architecture-v2`、`master` 和必要 tag；
4. 将 GitHub 设置为 `origin`；
5. 将 Gitee 保留为 `gitee`；
6. 对比两个 remote 的分支 SHA；
7. 重新同步 aly-ecs、WSL 和其他开发机。

## 11. 阶段 H：最终清理 research-app

只有新 investment 稳定运行并完成回滚窗口后，才允许清理：

- research-app KIND 工作负载；
- research 入口和 Service；
- research 镜像；
- research 相关分支和部署脚本。

必须保留：

- research 最终迁移 tag；
- 数据迁移记录；
- 回滚说明；
- 旧镜像 digest；
- 迁移验收报告。

## 12. 总体执行顺序

```text
新版 tpl-app 完成并冻结
    ↓
旧 investment 备份
    ↓
清理旧 investment 运行资源
    ↓
从 tpl-app 创建新 investment-app
    ↓
迁移 research 业务逻辑
    ↓
完成前后端配对、数据、worker、E2E 验收
    ↓
备份并覆盖 Gitee investment-app
    ↓
迁移并核验 GitHub investment-app
    ↓
回滚窗口结束后清理 research-app
```

## 13. 最终门禁

以下任意条件不满足，都不得进入下一阶段：

- 模板未冻结；
- GitHub/Gitee 基线不一致；
- 旧仓库没有备份；
- 数据没有备份；
- 新 investment 配对测试未通过；
- KIND 验证未通过；
- 镜像没有不可变 digest；
- 迁移没有回滚方案；
- 未明确当前阶段的唯一工作分支。

## aly-ecs 同步策略

从本方案更新起，WSL 与 aly-ecs 不再做主动双向同步：

- 日常开发、提交和推送只在当前工作机的 `architecture-v2` 完成。
- 不再要求 Codex 主动 SSH 到 aly-ecs、复制工作区或执行镜像/代码同步。
- aly-ecs 需要使用最新代码时，在 aly-ecs 上按需执行 `git pull --ff-only`；先确认当前分支和远程，再拉取对应分支。
- 不使用 `reset --hard`、强推或覆盖 aly-ecs 未备份的本地改动。

示例（在 aly-ecs 上按需执行）：

```bash
cd /home/zym/k8s
git fetch origin --prune
git switch architecture-v2
git pull --ff-only origin architecture-v2
```
