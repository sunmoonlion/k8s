# MoocManus v5 交接文档

> 快照日期：2026-07-12（Asia/Shanghai）
> 适用分支：各仓库的 `codex-1`；`tpl-app` 当前为 `master`
> 目的：在较长时间暂停后，让下一位执行者能够从已验证状态安全恢复，而不把局部验证误判为生产完成。

## 1. 阅读顺序与事实优先级

本文件是当前状态快照，不是新的架构方案。恢复时依次阅读：

1. 目标架构：`sunmoonai/docs/mooc-manus-langgraph-longterm-plan-v5.md`
2. 施工顺序：`sunmoonai/docs/mooc-manus-langgraph-v5-implementation-plan.md`
3. 本文的当前事实、未完成项和恢复顺序
4. 对应任务证据：`sunmoonai/docs/evidence/v5/`
5. 相关 ADR：`sunmoonai/docs/mooc-manus-v5/adr/`

如本文与 live cluster 不一致，以只读核验命令、当前镜像 digest 和 Git 提交重新确认；不要凭旧聊天记录直接部署。

## 2. 目标和不可改变的边界

最终目标是在 `app-platform/research-app` 建立以 LangGraph 为编排内核、可长期维护、可扩展、支持多智能体和长期记忆的智能体平台，同时保持 Info、Knowledge、Research 三个领域的数据所有权边界。

在 M1b 之前不能改变：

- Redis 只能承担 live signaling/cache，不能成为 Run、用户数据或事件的持久真相源。
- `Session / Thread / Run / Attempt / Invocation` 必须显式区分。
- Artifact、Retrieval、Citation、Identity 和事件/投影必须有版本化跨仓契约；不能用 mock success 或临时 URL 代替真实契约。
- 浏览器只使用本 App/Surface 的 BFF session；不能保存 access token，也不能编排跨仓 internal API。
- 服务调用使用可验证、可撤销的 service identity；不能恢复静态 API key、Admin token 或匿名 internal route。
- `AGENT_V4_TRAFFIC_ENABLED` 仍为 `false`；KIND 验证不代表允许真实流量。
- 前端目标态为 React/TypeScript，但不强迫所有面使用同一运行框架：Admin 为 React Router Framework Mode + Vite 的静态 SPA，Web 为 React + Next.js App Router；Vue Admin 和旧 Next Web 作为迁移期回退。

## 3. 当前任务状态

| 任务 | 当前状态 | 已证明 | 仍未证明/下一步 |
|---|---|---|---|
| IMM-001 配置真相保护 | ACCEPTED | Git/K8s 配置漂移保护 | 后续由 M1-004 统一治理 |
| P0-001 Runtime 选型 | IN_PROGRESS / Candidate A partial | 自建候选的部分 interrupt/resume、旧 Graph 恢复、Postgres checkpointer 重连 | 同 Thread 并发、cancel、cursor 恢复、真实 kill/故障矩阵；B/C 尚未对照；ADR-001 不得标 ACCEPTED |
| P0-002 执行身份模型 | NOT_STARTED | 文档已有候选实体边界 | schema、状态转换、checkpoint mapping、并发条件更新和 lineage 测试 |
| P0-003 Artifact Contract | ACCEPTED | Info -> Knowledge 真实 S3 artifact、version/hash/size/media type、404/403/hash mismatch | 不等同于 Retrieval/Citation 或完整 Research E2E |
| P0-004 Retrieval/Citation | NOT_STARTED | 目标契约已写入 v5 | Knowledge Retrieval API、Evidence DTO、Research consumer 和服务授权 |
| P0-005 身份与服务调用 | IN_PROGRESS / partial | 三 Admin 匿名 401；真实 Casdoor client-credentials 边界；复验矩阵 401/401/422 | 浏览器 PKCE/CSRF/跨用户、伪造/过期 token、可重复 Secret、migration job gate、ADR-005 接受 |
| P0-005E 镜像/部署隔离 | ACCEPTED（本快照） | 三 Admin Backend API+worker 已验证 digest retag 为 1.0.1；临时 p0 tag 和无用零副本 RS 已清理 | 不要把 1.0.0 当旧垃圾删除；它仍被其他组件使用 |
| P0-006 可靠交付 | NOT_STARTED | v5 已定义 outbox、lease、reconciler 方向 | ADR、最小原型、重复投递/副作用恢复证据 |
| P0-007A React Admin 模板 | ACCEPTED | React 模板、静态构建、Nginx/base path、E2E/KIND smoke | 007B Info 真实业务试点、007C 模板修正/冻结 |
| P0-008 Next Web v2 | NOT_STARTED | ADR-014 仍为 Proposed，旧模板保留 | 等待 007C 及 P0-001/004/005 输出后再做 Next v2 |
| M1a/M1a.5/M1b | NOT_STARTED | 只有路线和 Gate 定义 | 不能因 Phase 0 smoke 通过而提前进入生产 Runner、记忆或多智能体产品化 |

### 3.1 已完成的关键证据

- `V5-P0-003`：`sunmoonai/docs/evidence/v5/V5-P0-003/result.md`
  - Artifact schema SHA-256：`a3219604ed3562c436336d4650c2a0fd08afd9a8829e1d17b12d6a929f499c81`
  - 真实 KIND 成功状态为 `artifact_verified`；hash mismatch、合法不存在对象的 404、权限拒绝 403 均通过。
  - 该任务只证明 Artifact transport/integrity，不证明 RAGFlow、Retrieval 或 Citation。
- `V5-P0-005`：`sunmoonai/docs/evidence/v5/V5-P0-005/result.md`
  - 三 Admin 匿名业务入口：401。
  - Knowledge internal route 无 service token：401；真实 service credential 请求到达业务校验：422。
  - token 未打印、未写入证据；Research traffic 验证后恢复为 `false`。
  - 浏览器 PKCE 矩阵尚未由该脚本覆盖。
- `V5-P0-007A`：`sunmoonai/docs/evidence/v5/V5-P0-007A/result.md`
  - tpl-app React Admin commit：`fe8fc5cfd2a9d23f4f8a1bcd0465440b2341d85e`
  - React 19.2.7、React Router Framework Mode 8.2.0、Vite 7.3.6、Ant Design 6.5.0、TanStack Query 5、Zustand 5。
  - 生产产物为 `ssr: false` 静态 SPA，运行镜像只有 Nginx，不含 Node runtime。

## 4. 仓库、分支和未提交内容

### 4.1 `/home/zymun/k8s`

- 分支：`codex-1`，当前与 `origin/codex-1` 同步，工作树干净。
- 最近关键提交：`7a091a7`、`459f0ff`、`c2b3790`。
- Info 部署脚本真实路径为 `sunmoonai/app-platform/info-app/deploy-info-app-all/deploy-info-app-all.sh`；不要在 `sunmoonai/app-platform/info-app` 目录直接假设脚本位于当前目录。

### 4.2 `/home/zymun/info-app`

- 分支：`codex-1`。
- 外层有待处理的 `info-admin-backend` 子模块指针：记录为 `7682237`，工作区指向 `c6af773`。
- 内层 `info-admin-backend`：`codex-1`，工作树干净且与远端同步；包含 artifact contract、service credentials、OIDC/Jose 校验和构建卫生修复。
- 不要直接丢弃外层 submodule pointer；先审阅 diff 再决定是否提交外层仓库。

### 4.3 `/home/zymun/knowledge-app`

- 分支：`codex-1`。
- 外层有待处理的 `knowledge-admin-backend` 子模块指针：记录为 `acc8f79`，工作区指向 `4214c6a`。
- 内层 `knowledge-admin-backend`：`codex-1`，工作树干净且与远端同步；包含 artifact ingestion contract、internal route、service principal journal、标准 discovery 和构建卫生修复。

### 4.4 `/home/zymun/research-app`

- 分支：`codex-1`。
- 外层有待处理的 `research-admin-backend` 子模块指针：记录为 `e77eed1`，工作区指向 `7724a58`。
- 内层 `research-admin-backend`：`codex-1`；已提交的身份/Session ownership 代码与远端同步，但有 4 个未跟踪的 Runtime Spike 文件：
  - `app/app/infrastructure/graph/runtime_selection_spike.py`
  - `app/scripts/run_runtime_selection_spike.py`
  - `app/scripts/run_runtime_selection_postgres_spike.py`
  - `app/tests/test_runtime_selection_spike.py`
- 这些文件是 P0-001 Candidate A partial 的重要证据来源，禁止 `git clean -fd`、`git reset --hard` 或随意删除；恢复时先审阅、测试、决定是否提交。

### 4.5 `/home/zymun/tpl-app`

- 分支：`master`，本地领先 `origin/master` 1 个提交：`fe8fc5c feat: add React admin production template`。
- 原 Vue `tpl-admin-frontend` 未改动；新增 `tpl-admin-frontend-react` 尚未完成 007B/007C，也未同步到三个 App。
- 恢复时再次确认是否已推送；不要重复推送或覆盖远端历史。

## 5. 当前 KIND / Harbor 事实

### 5.1 三个已验证 Admin Backend

| 组件 | 1.0.1 对应的已验证 digest |
|---|---|
| Info Admin Backend | `sha256:6c8041e83f96f4952718ecf63a8c8d8a5664d8343ecc135b1c1e0ad13a2ceb3d` |
| Knowledge Admin Backend | `sha256:7c55d2bfd130f0b68a8b8df3f338739c1570ceef36b6112da63f1bd740b9b7d4` |
| Research Admin Backend | `sha256:b10820a71218f5630cc519452c426a867a85ba5ed95870fae164e9d31fec6d5b` |

### 5.2 Harbor 清理结果

已删除三个后端仓库的临时 `p0-005-auth-20260712*` tag，以及两个只被旧 r2 tag 引用的 standalone artifact digest。r3 和 Research 临时 tag 与 `1.0.1` 共享 digest，因此只删 tag，artifact 仍由 `1.0.1` 保留。

当前三个后端 Harbor 仓库都保留 `1.0.0` 和 `1.0.1`。`1.0.0` 不能删除：当前 Info/Research Web、NodeBullWorker、Research Admin Frontend 等组件仍在使用它，并且它是可回滚基线。

### 5.3 当前部署边界

- 三个 Admin Backend API/worker：`1.0.1`。
- Info Admin Frontend：`1.0.1`；Research Admin Frontend：`1.0.0`。
- 未通过同一后端测试的 Web/Frontend/worker 保持原稳定标签；不能把 App 级 tag 作为全 App 发布开关。
- `app-platform-dev` 最后核验：无非 Running/Succeeded Pod、无 `p0-*` 镜像引用、无残留的零副本 `v5-p0-003` ReplicaSet。
- 这是 KIND/内部环境状态；没有 Ingress、生产流量或 M1b canary 授权。

## 6. 暂停后的推荐恢复顺序

恢复时不要一次展开全部 Phase 0。每一步完成后保存证据并重新确认工作树和集群。

### Step 0：只读复核环境

```bash
cd /home/zymun/k8s
git status --short --branch
export KUBECONFIG="$HOME/.kube/kind-config"
kubectl get pods -n app-platform-dev -o wide
kubectl get deploy -n app-platform-dev -o custom-columns='NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image'
```

同时检查五个工作区及三个 backend 子模块的 branch/status。若出现新提交、镜像或 Secret 变化，先更新状态，不直接继续旧任务。

### Step 1：先关闭 P0-005 的安全遗留项

优先完成浏览器 PKCE/state/nonce/CSRF、跨用户资源拒绝、伪造/过期 token、Secret 可重复注入和 migration job gate。保持 traffic off；测试命令不得输出 token、cookie、client secret 或完整响应正文。

P0-005 完整接受前，不得把 Admin 页面当作已生产化，也不得把“匿名 401”误判为完整身份闭环。

### Step 2：完成 P0-001 Runtime ADR

先审阅并测试 Research backend 中 4 个未跟踪 Spike 文件，再补齐 Candidate A 缺失矩阵。若软件源、许可和 egress 允许，使用同一 Graph 对 B/C 做隔离对照；否则明确记录淘汰理由，不能只凭文档评分选择 Agent Server/Hybrid。

只有 ADR-001 选定分支后，才激活 M1-301~314 对应任务；未选分支标记 `NOT_APPLICABLE`。

### Step 3：依次完成 P0-002、P0-004、P0-006

- P0-002：冻结 Execution Identity 和 lineage schema。
- P0-004：真正实现 Knowledge Retrieval API、Evidence/Citation DTO、allowlist 和 Research consumer；不能用 P0-003 artifact smoke 代替。
- P0-006：确定 outbox/dispatcher/lease/reconciler 和副作用幂等语义；不能先把当前 Celery dispatch 代码扩成生产 Runner。

### Step 4：再推进前端资格链

- 从 007A 固定 commit 推进 007B Info 真实业务薄切，再做 007C 模板冻结。
- 007B 必须使用真实 Artifact/Delivery API、真实授权失败和审计 correlation ID；Reference fixture 只能测试组件。
- 007C 通过后，按 P0-008A/B/C 重基线 `tpl-web-frontend` 的 Next Web v2；P0-001/004/005 没有执行输出前不要改造旧 Web 模板。
- 三个 App 的批量同步属于 Gate P0 之后的迁移动作，不要提前复制模板。

### Step 5：Gate P0 后才进入 M1

按 `M1a -> M1a.5 -> M1b -> M1c` 推进。M1a 允许内部测试身份和测试数据，但必须使用真实模型、真实工具、真实 Retrieval/Citation 和可恢复的服务端 Projection；禁止 fake LLM、mock ingestion、伪造 retrieval 或 fake SSE。

## 7. 恢复时的安全规则

- 任何安装、Docker build/push、Harbor 操作、KIND rollout 都先确认 registry、tag、digest、namespace 和回滚镜像；网络命令由项目负责人在本机执行。
- 不要把 `1.0.1` 改写到另一个 digest；发布新内容使用新候选 tag，验证后再不可变 retag。
- 不要删除 `1.0.0`、数据库 migration、Secret、PVC、Deployment 或非零副本 ReplicaSet 来“清理旧环境”。
- 不要使用 `git reset --hard`、`git clean -fd`、强制 push 或删除未跟踪 Spike 文件来消除工作树噪声。
- 先保存证据，再改状态；“代码写完”“镜像构建成功”“Pod Running”都不等于任务 ACCEPTED。
- 交接材料不得包含 access token、refresh token、cookie、authorization code、PKCE verifier、client secret 或完整 OIDC/JWKS 响应。

## 8. 恢复检查清单

- [ ] 阅读 v5 长期方案、实施计划、本文和目标 ADR。
- [ ] 确认五个顶层工作区以及三个 backend 子模块的分支、dirty 状态和远端关系。
- [ ] 确认 `AGENT_V4_TRAFFIC_ENABLED=false`，核对三个 Admin Backend 的实际 image digest。
- [ ] 确认 Harbor 中 `1.0.1` 指向本文记录的三个 digest；不删除仍被使用的 `1.0.0`。
- [ ] 确认 `app-platform-dev` 无异常 Pod、无 `p0-*` 引用和无意外 rollout。
- [ ] 将 P0-005 的浏览器安全遗留项列为当前优先安全工作，不把 partial 当作完整接受。
- [ ] 审阅 Research Runtime Spike 未跟踪文件，再决定提交和 P0-001 证据归档方式。
- [ ] 每完成一个任务更新对应 evidence/result.md、实施计划状态和本文快照；不要只更新聊天。

## 9. Git 收尾

交接文档提交后先查看：

```bash
cd /home/zymun/k8s
git status --short --branch
git diff --check
git log -3 --oneline
```

推送由项目负责人执行。不要在未审阅其他仓库 dirty 状态前批量提交 submodule pointer；Info、Knowledge、Research 的外层 pointer 变更、Research Runtime Spike 文件和 tpl-app React 模板提交必须分别确认、分别记录，避免把未完成内容误包装成生产发布。
