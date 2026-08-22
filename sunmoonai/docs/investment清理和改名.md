# Research 原地改名为 Investment 的 Architecture v2 实施方案

状态：`COMPLETE / R4-R7.1 PASSED / 2.0.0 RELEASED`

日期：2026-08-09

分支：`architecture-v2`

模板唯一来源：`architecture-v2-r3.2-20260808`

## 1. 决策

不再从空仓重建 Investment。以现有 Research 仓库及其 Git 历史为迁移主体，原地改名并同步
R3.2 共同底座：

```text
research-app              -> investment-app
research-admin-backend    -> investment-backend
research-admin-frontend   -> investment-admin-frontend
research-web-frontend     -> investment-web-frontend
research-web-backend      -> 只读归档，不进入新拓扑
```

选择 `research-admin-backend` 作为统一 Backend 的历史主体，因为 LangGraph、Agent Runtime、
SSE、检索和长期记忆等 Python 领域能力位于该仓。旧 Research Web Backend 中仍有效的合同和逻辑
逐文件迁入统一 Backend，禁止整体复制旧基础设施。

源码保留历史并原地改名；Kubernetes 新拓扑必须从已验收模板重新生成，禁止机械改旧 YAML。

## 2. 命名边界

下列应用与基础设施身份必须改为 `investment-*`：

- 父子仓、本地目录、包和镜像仓库；
- K8s 资源、ServiceAccount、Secret、ConfigMap、Ingress 和 TLS Secret；
- 数据库目标名、角色、Redis namespace、对象存储前缀；
- Casdoor Application、Client ID、redirect URI、Cookie 和 policy namespace；
- 服务身份、审计 app 标识、前端应用名称。

禁止全局替换所有 `research`。`ResearchSession`、投资研究工作流和 deep-research Agent 等仍可能是
Investment 内部的合法领域术语，必须逐项分类。

## 3. 远端同名冲突

Gitee 已存在旧 `investment-*` 仓。首选服务器端 Legacy 改名，但当前环境没有可用的仓库管理 API
会话，因此采用受保护备用路径：

1. 旧 Investment 五仓均已完成 mirror、bundle、refs 和 SHA-256 备份；
2. 旧仓 `master` 保持不变；
3. 旧仓均保存 `legacy-pre-architecture-v2-20260809` 标签；
4. 新 Investment 只写入原仓不存在的 `architecture-v2` 分支；
5. 完整门禁前禁止改写 `master`；
6. 统一 Backend 已完成服务器端改名，GitHub 与 Gitee 均使用
   `investment-backend`；
7. GitHub 仓库在 Gitee 候选验收后创建或改名，随后恢复 `origin=GitHub`、`gitee=Gitee`。

任何已有分支若需要替换，只允许使用带精确旧 SHA 的 `--force-with-lease`；禁止裸 `--force`。

## 4. 备份与冻结门

备份根目录：

```text
/home/zymun/archives/investment-rename-20260809/
```

Research 五仓与旧 Investment 五仓必须同时具备：

- 可独立恢复的 Git bundle；
- 全量 refs 清单；
- SHA-256 校验和；
- `git bundle verify` 与 `git fsck` 通过；
- 远端不可变改名前标签。

证据见 `architecture-v2/evidence/I1-investment-rename-backup.json`。备份不完整时禁止改名或覆盖。

本地拓扑改名和远端隔离结果见
`architecture-v2/evidence/I3-investment-topology-rename.json`。旧 Investment 的四个 `master`
均保持原 SHA，新候选只新增 `architecture-v2`。

## 5. 本地原地改名事务

执行顺序：

1. 再次确认五个 Research 工作树 clean；
2. 把 Research 的 GitHub/Gitee remote 改名为 archive remote；
3. 将三个活动子仓目录改成 Investment 名；
4. 将旧 Web Backend 从活动 submodule 拓扑移除，但保留远端、bundle 和标签；
5. 更新 `.gitmodules`、gitlink 和父仓说明；
6. 将父目录 `/home/zymun/research-app` 改为 `/home/zymun/investment-app`；
   （2026-08-21 五仓再迁至 `~/master/`，现活路径为 `/home/zymun/master/investment-app`）
7. 提交纯拓扑改名，不混入业务修改；
8. 验证 bundle 可恢复和所有 archive remote 可达。

## 6. R4 模板同步与领域迁移

三个活动组件均以 R3.2 release 为唯一共同底座，执行：

```text
plan -> prohibited-drift=0 -> clean-room apply -> 测试
     -> 实例 apply -> 测试 -> 提交 -> steady-state plan
```

最终稳态必须同时满足：

```text
writes=0
deletes=0
prohibited-drift=0
```

Backend 必须保留并验证：

- LangGraph 图、State reducer 和 checkpoint；
- Session/Thread/Run/Attempt 映射；
- SSE、resume、cancel 和幂等；
- Knowledge retrieval 与证据引用；
- Agent Worker、工具副作用和长期记忆边界；
- 现有规范 Alembic 历史，模板 migration 只按 R4/R5 边界处理。

Admin/Web 继续使用两个独立 Next.js 表面，但共同调用一个 `investment-backend`。

## 7. 数据和运行边界

R4 只在隔离 namespace、全新测试数据库和独立 Casdoor Client 中验收。现有 Research 的数据库、
Secret、PVC、Casdoor Client、K8s Deployment 和 Harbor digest 全部保留为回滚面。

真实数据迁移、对账、切读、切写和旧写入封锁属于 R5，不得夹带进改名事务。

## 8. Investment R4 完整门禁

必须通过：

1. Backend Ruff、Pyright、pytest；
2. Admin/Backend 与 Web/Backend 两套真实配对；
3. Agent Runtime、SSE、resume、cancel、checkpoint 和 retrieval 合同测试；
4. 三个候选镜像与源码 commit/tree/digest 锁；
5. 连续 Alembic migration；
6. 同一 Backend 镜像的 API/Worker/Scheduler 多角色；
7. Admin/Web 严格 TLS 和真实 Casdoor 登录/退出；
8. 原生 Deployment 回滚和前滚；
9. Calico allow/deny 报文门禁；
10. 退出后 namespace、凭据 Secret 和临时集群无残留；
11. 旧 Research 运行拓扑前后快照哈希一致。

R4 已于 2026-08-09 完整通过。证据位于：

```text
architecture-v2/evidence/R4-investment-source-gate.json
architecture-v2/evidence/R4-investment-apply/
architecture-v2/evidence/R4-investment-gate/
```

门禁过程中发现 Celery 会继承节点 CPU 数并默认启动 12 个 prefork 进程，导致 768Mi Worker
OOMKilled。修复没有做 Investment 临时补丁，而是进入模板 `7f2942c`：Worker 并发默认显式锁定为
2，并保留水平扩容作为 Kubernetes 主容量策略。修复后重新从零执行门禁通过。

门禁退出后已确认隔离 namespace、临时身份 Secret 和临时 Calico 集群均无残留；旧 Research
运行拓扑未被门禁用作写入目标。

### 8.1 R4 后源码拓扑收口

R4 门禁通过后又发现父仓仍跟踪旧四组件时代的独立 Celery/NodeBull Worker、v1
`k8s-scaffold`、手工 dev-to-prod 工具和实例化 `init.sh`；统一 Backend 的数据库、搜索、对象存储
接入声明也仍使用 `research-admin-backend` 基础设施身份。这些内容不影响已完成的隔离门禁，但会
让维护者误判活动架构。

2026-08-09 已完成以下收口：

- `investment-backend` 提交 `40d09b6`：接入声明统一为 `investment-app` /
  `investment-backend`，仓库内开发口令改为不可用占位符，并增加自动回归门禁；
- `investment-app` 提交 `6230079`：只保留三个活动子模块，删除独立 Worker、Node BFF、v1
  脚手架和旧四组件初始化/发布说明；
- K8s `research-app` 目录显式标记为 `LEGACY-ROLLBACK-ONLY`，只允许 R7 前恢复旧基线；
- 历史文档中的 Research 名称保留为来源证据，不得重新解释为当前运行配置。

该收口不重建 R4 镜像、不修改 R4 digest 锁，也不提前执行 R5 数据迁移。后续任何模板同步都必须
同时通过三子模块拓扑门禁和 Backend 基础设施身份门禁。

## 9. 发布与归档

以下发布与归档操作均已完成：

- 把 Gitee `architecture-v2` 固化为验收提交；
- 将 `investment-admin-backend` 服务器端仓名改为 `investment-backend`；
- 创建或改名 GitHub Investment 父子仓；
- 设置 `origin=GitHub`、`gitee=Gitee` 并逐仓核对 SHA；
- 把 Research 仓库标记为只读归档。

旧 Research 远端、镜像、数据库和部署在 R7 观察窗结束前不得删除。正式 `2.0.0` 仍只能在 R7
晋级。

当前远端收口状态：GitHub 已创建四个私有正式仓，父仓 `.gitmodules` 已指向 GitHub；四仓本地、
GitHub、Gitee 的 `architecture-v2` SHA 均一致；五个旧 Research GitHub 仓已标记为只读归档。
Gitee Backend 已原地改名为 `investment-backend`，与 GitHub 同名；改名保留了完整
Git 历史，没有创建第二份 Backend 或重写业务历史。

## 10. 主线顺序

```text
Info R4 DONE
  -> Knowledge R4 DONE
  -> Investment Rename/Migration R4
  -> R5 数据迁移与切流
  -> R6 Info -> Knowledge -> Investment 真实竖线
  -> R7 2.0.0 晋级与旧 Research 退役
```
