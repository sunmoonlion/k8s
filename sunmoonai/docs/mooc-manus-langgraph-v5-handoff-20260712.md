# MoocManus v5 当前交接文档

> 文件名保留最初快照日期以避免旧链接失效；本文内容已于 **2026-07-22
> （Asia/Shanghai）整体重写**，旧 2026-07-12/13 状态不再有效。
>
> 适用分支：`k8s/info-app/knowledge-app/research-app` 的 `codex-1`；`tpl-app` 及模板
> 子仓当前为 `master`。

## 1. 权威顺序

恢复工作时依次阅读：

1. `sunmoonai/docs/mooc-manus-langgraph-longterm-plan-v5.md`
2. `sunmoonai/docs/mooc-manus-langgraph-v5-implementation-plan.md`
3. `sunmoonai/docs/mooc-manus-v5/adr/ADR-014-next-web-template-rebaseline.md`
4. `sunmoonai/docs/mooc-manus-v5/adr/ADR-016-web-bff-implementation-profiles.md`
5. `sunmoonai/docs/mooc-manus-v5/adr/ADR-017-template-first-instance-adoption.md`
6. 本文当前游标、仓库事实和禁止项
7. `sunmoonai/docs/evidence/v5/` 对应任务的原始证据

`mooc-manus-langgraph-longterm-plan-v4.md` 已归档，只能作为历史设计输入。聊天、旧镜像
tag、Pod Running、单个 smoke 或本文中的提交快照都不能覆盖 v5、Accepted ADR、任务状态
和当前只读核验结果。

## 2. 2026-07-18 已确认的架构决定

### 2.1 前端运行形态

- Admin：React 19 + React Router 8 Framework Mode，`ssr:false`，最终运行镜像只有 Nginx。
- Web：React 19 + Next 16 App Router，public route 可 static/SSG/受控 ISR，受权 workspace
  dynamic/no-store，Client Component 承担交互；`standalone` Node 24.18.0 运行。
- 渲染模式不决定身份模式。Admin/Web 都使用 backend-owned BFF session，浏览器不保存
  Provider token；前端守卫只改善 UX，最终授权在对应 Backend。

### 2.2 配对关系

```text
tpl-admin-frontend + tpl-admin-backend        # React SPA/Nginx + FastAPI Admin
tpl-web-frontend   + tpl-web-backend          # Next Node + FastAPI Web（默认）
tpl-web-frontend   + tpl-web-backend-nest     # Next Node + Nest Web（可选 profile）
```

“配对”由 surface、Casdoor client/audience、cookie、contract、双镜像 digest、部署和回滚
tuple 定义，不由前后端是否采用不同语言定义。Admin 与 Web 即使都使用 FastAPI，仍是
独立仓库、信任面、Deployment、session namespace 和发布单元；不得互相替代 E2E。

### 2.3 Web Backend 双实现与默认主线

- 现有 `tpl-web-backend` 先完成 Nest 生产模板，再固化并改名
  `tpl-web-backend-nest`，作为受维护可选 profile。
- 新的 `tpl-web-backend` 使用 FastAPI，成为 `tpl-app` 默认 Web BFF。
- FastAPI 与 Nest 消费同一语言无关 Auth/Principal/CSRF/Error/SSE/Citation contract；
  Next typed client/DAL 不得按语言分叉。
- 若 Nest 后续不能持续通过共享门禁，必须降级为 `REFERENCE_ONLY`，不得声称可直接使用。
- P0-009 的三个业务 Web 基础同步、P0-008C 和后续业务等价/切流都只使用 FastAPI 默认
  profile。

### 2.4 FastAPI 母版来源

当前 canonical `tpl-admin-backend` 仍是旧认证原型，不能直接复制为新 Web 主线。已核实的
阻断缺陷包括：state 未持久/校验、无 PKCE/nonce/JWKS、ID Token 只 base64 decode、完整
Provider token 写 Redis、登录路径 DDL、GET logout、`/auth/me` 返回原始 session 或
`200 + null`。

顺序必须是：

1. 从 Info/Knowledge/Research 已通过 P0-005 的代码中只回收通用安全/基础设施能力，
   反向补齐并验收 `tpl-admin-backend`。
2. 不得带入 Document、Ingestion、Run 等领域代码。
3. 由修复后 `tpl-admin-backend` 的固定 commit 初始化新的 FastAPI `tpl-web-backend`。
4. 立即替换成 Web surface/audience/cookie/Redis namespace/API allowlist/downstream
   relation；Admin Backend 不能直接充当 Web BFF。

### 2.5 Next 与 BFF 边界

- Browser `/`, `/_next/*` -> Next；Browser `/api/*` -> 选中的配对 Web Backend。
- Server Component 只经 `server-only` DAL 调用配对 backend 内部 Service URL，只转发
  allowlist cookie、locale、correlation ID，返回最小 DTO。
- Next Route Handler 不复制 `/auth/*`、通用代理、领域写模型或 durable Run 状态。
- Web BFF 只负责 session/token mediation、授权、DTO、命令转发和受控 SSE；LangGraph
  长任务及 Run/Artifact/Retrieval/Citation 真相仍归 Runtime/领域数据库。

### 2.6 模板先行与实例立即收敛

- 当前只开发 `tpl-app` 的模板/契约/门禁，B2 已接受，唯一代码游标是 P0-008B/B3。
- React Admin Frontend 虽已达到 `TEMPLATE_MIGRATION_READY`，但 B5 还要修复
  `tpl-admin-backend`；现在只同步 Admin Frontend 会形成混代底座并导致第二次迁移。因此
  先完成 B2~B6 的四默认组件统一 release，不是在推迟模板优先原则。
- B2~B6 完成后必须冻结四个默认组件统一 `template_release_id`，紧接执行 P0-009；不得先
  做 P0-008C、产品功能、Memory/Subagent 或 Agent 主链扩建。
- P0-009 按 Info -> Knowledge -> Research 串行把 Admin/Web 前后端共同底座原地同步；
  任一实例失败即停止，不做三个 App 同时覆盖。
- Frontend 同步基础并重接领域页面；Backend 只同步通用内核，不覆盖领域模型、migration
  lineage、worker 和数据所有权。
- P0-009 只产生 `INSTANCE_FOUNDATION_ALIGNED`，不自动切流、不删除旧 Vue/Next/Backend
  镜像；完整业务等价和切流仍由 M1-411B/C/D、M1-413 完成。

## 3. 当前任务游标

### 已接受且不能倒退的关键输入

- P0-003 Artifact Contract：真实 S3 artifact 完整性和 403/404/hash mismatch。
- P0-004 Retrieval/Citation：真实 RAGFlow retrieval、独立服务身份、Citation lineage 和
  负向/故障矩阵。
- P0-005 Identity：三 Admin、服务身份、PKCE/JWKS/session/CSRF/所有权边界；Web consumer
  语义由 P0-008 落地。
- P0-006 Reliable Delivery：Info -> Knowledge outbox 参考实现。
- P0-007C React Admin v1：`TEMPLATE_MIGRATION_READY`；不代表三个业务 Admin 已迁移。
- P0-001：Custom Runtime selected。
- P0-002：Execution Identity model accepted。
- P0-008A/ADR-014：Next Web 架构矩阵 accepted；ADR-016 于 2026-07-18 修订 backend profile。
- P0-008B/B1：Node 24.18.0、pnpm 10.24.x、JOSE 6.2.3、Next/Nest clean-room、非 root、
  standalone、fail-fast 和 Playwright 基线 accepted。
- P0-008B/B2：Nest identity kernel、Next server-only DAL/DTO、严格 browser session
  contract 和受控 Next+Nest 配对门禁 accepted。
- ADR-017：模板统一 release 后立即按 Info -> Knowledge -> Research 收敛三个实例，
  共同底座对齐前冻结普通业务开发。

### 当前状态

```text
P0-008B = IN_PROGRESS / B2_ACCEPTED / B3_NEXT
P0-009  = NOT_STARTED / BLOCKED_BY_P0_008B_B3_TO_B6
P0-008C = NOT_STARTED
三个业务 Web 实例 = 未应用 Web v2
```

架构讨论已经收口。**唯一下一代码任务是 B3**；不能跳到仓库改名、FastAPI 创建、
P0-009、P0-008C 或业务 App。B3~B6 完成后，P0-009 自动成为唯一任务。

## 4. P0-008B 串行施工包

### B1 Repo/Env/Rendering/Test Baseline — ACCEPTED

- 固定 `tpl-web-frontend@f5340ac`、`tpl-web-backend@f5bedfb`、`tpl-app@fe29739`。
- Node 基础镜像 digest：
  `sha256:4ba75f835bb8802193e4c114572113d4b26f95f6f094f4b5229d2a77773e0afc`。
- 证据：`sunmoonai/docs/evidence/v5/V5-P0-008B/B1/result.md`。
- 旧 Node 20 基线为 `SUPERSEDED / NO_NEW_RELEASE`。

### B2 Nest BFF Identity + Next DAL/DTO — ACCEPTED

只修改 canonical `tpl-web-backend`、`tpl-web-frontend`、必要 contract/evidence 和
`tpl-app` gitlink：

- Nest：PKCE S256、一次性 state/nonce transaction、JWKS/issuer/audience/time 校验、
  最小 Principal session、Web 专属 cookie/namespace、CSRF/Origin、POST logout、稳定错误。
- Next：真正的 server-only DAL/DTO、受权 dynamic/no-store route、浏览器同源 typed client；
  不建立第二套 auth store/BFF。
- 共享输入：ADR-005、ADR-014、ADR-016 和 security contract vectors。
- 固定：`tpl-web-backend@839ea09`、`tpl-web-frontend@b1730a6`、`tpl-app@4cae61d`。
- 证据：`sunmoonai/docs/evidence/v5/V5-P0-008B/B2/result.md`。
- B2 的受控 fixture 不是 Casdoor/KIND/真实业务证据；这些门禁仍属于 B4。

### B3 UI/Query/Stream/Citation + Nest Pair — NEXT

完成中性 public/authenticated/stream/HITL/citation/error surfaces 和共享 contract adapter；
fixture 只能验证 UI/错误，不得冒充真实 Run/Retrieval 成功。

### B4 Nest Security/Paired Test/Deploy/Freeze

Next+Nest 完成双 Pod、真实浏览器、PKCE/CSRF/audience、SSE、CSP、滚动/version-skew、
回滚和不可变 digest 证据后，才将现有仓原子改名为 `tpl-web-backend-nest`。改名前必须
固定 Git tag、镜像 digest、远端 URL 和恢复步骤；改名后必须核对 `.gitmodules`、本地路径、
gitlink 和远端一致。失败时回滚，不得留下两个同名或错指远端。

### B5 FastAPI Canonical Kernel + Default Web BFF

先修 `tpl-admin-backend` 通用母版，再创建新的 `tpl-web-backend`。完成 Web 专属语义后运行
独立 typecheck/lint/unit/contract、Docker/KIND、身份负向和 clean-room 门禁。原样复制当前
旧 Admin 认证代码属于阻断错误。

### B6 Dual-profile Contract/Paired/Release Gate

同一 Next 分别对 FastAPI/Nest 跑共享 consumer vectors 和配对 E2E。FastAPI 获得默认
release tuple；Nest 获得可选 tuple。记录双方 contract version、前后端 digest、audience、
profile、兼容矩阵和独立回滚。B1~B6 全部接受后 P0-008B 才结束，并立即进入 P0-009。

### P0-009 统一模板发布与三实例立即收敛

1. P0-009A：冻结四默认组件 release manifest、三实例保留/替换/删除清单、迁移前
   tag/digest/DB revision 与逐实例回滚。
2. P0-009B：Info 原地同步并完成 Admin/Web 配对、Docker/KIND、配置/migration 和回滚。
3. P0-009C：Knowledge 同步，保留 Dataset/Ingestion/Retrieval 领域边界。
4. P0-009D：Research 同步，保留 Run/Runtime 领域边界，不提前做真实产品试点。
5. P0-009E：clean-room 重放、共享 contract、六组基础配对、漂移报告和总回滚门。

五步必须串行；P0-009E 接受前禁止普通业务开发。三个 App 都记录同一
`template_release_id` 后，才解锁 P0-008C。

计划顺序静态门禁：

```bash
python sunmoonai/docs/mooc-manus-v5/scripts/verify_template_first_plan.py \
  --k8s /home/zymun/k8s
```

### P0-008C Research 真实试点

只在 P0-009 已对齐的 Research 基线上使用 FastAPI 默认 Research Web Backend + Custom
Runtime adapter，证明真实 Run/SSE/cancel/resume/HITL/citation、刷新/断线/多标签、跨用户
拒绝和滚动版本。通过前禁止把基础同步当成完整 Web 产品能力或切正式流量。

## 5. 当前仓库事实（2026-07-22）

### k8s

- 分支：`codex-1`；本轮文档修订前 HEAD `0348025`，与 `origin/codex-1` 同步。
- 2026-07-18 提交 `0348025` 已同步远端。本轮新增 ADR-017 并调整 v5、implementation
  plan、ADR-013/014/016 和本文的任务顺序；未修改运行代码、Deployment、Secret、Harbor
  或 KIND。

### tpl-app

- 父仓：`master@4cae61d`；B2 gitlink 已本地固定，待本包证据提交后统一推送。
- `tpl-admin-backend@2760862`：当前仍是旧认证原型，B5 前不得作为安全母版复制。
- `tpl-admin-frontend@1561e5d`。
- `tpl-web-backend@839ea09`：当前 Nest/B2 输入；身份内核已接受，尚未达到 B4 生产冻结标准。
- `tpl-web-frontend@b1730a6`：Next/B2 输入；server-only DAL/DTO 已接受，B3 产品中性面待完成。
- 当前 `.gitmodules` 仍只有原 `tpl-web-backend`；`tpl-web-backend-nest` 尚未创建，这是正确
  状态，必须等 B4。

### 业务仓

- `info-app/codex-1@37988c8`：本次未修改。
- `research-app/codex-1@8121595`：本次未修改。
- `knowledge-app/codex-1@2e410ad`：本地相对 `origin/codex-1` ahead 3；这是进入本轮前已存在
  的提交，不得被 Web 模板任务重写、reset 或顺带包装。恢复时先独立核对是否已推送。

## 6. 集群、Harbor 与发布边界

本文 2026-07-22 修订没有重新部署或重新核验 live cluster/Harbor，因此不能沿用旧 handoff
的 Pod/tag 描述作为当前事实。任何 build/push/rollout 前必须只读确认：

```bash
git -C /home/zymun/k8s status --short --branch
git -C /home/zymun/tpl-app status --short --branch
git -C /home/zymun/tpl-app submodule status

KUBECONFIG="$HOME/.kube/kind-config" kubectl get pods -A
KUBECONFIG="$HOME/.kube/kind-config" kubectl get deploy -A \
  -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image'
```

保持以下规则：

- `AGENT_V4_TRAFFIC_ENABLED=false`，除非未来 Gate 明确授权。
- 候选内容不得覆盖已有稳定 tag；tag 与 digest 一一记录。
- 不删除仍被 Deployment、回滚清单或证据引用的镜像、Secret、PVC、migration 或 RS。
- “构建成功”“push 成功”“Pod Running”都不等于任务 ACCEPTED。
- 任何 OIDC/Secret/浏览器验证不得打印 token、cookie、code、verifier 或 client secret。

## 7. 恢复检查清单

- [ ] 阅读 v5、implementation plan、ADR-014、ADR-016、ADR-017 和本文。
- [ ] 确认 v4 顶部是归档声明，不从 v4 恢复任务。
- [ ] 确认 k8s 文档变更已检查/提交，未混入运行代码。
- [ ] 确认 tpl-app 四个 gitlink与本文最新固定值一致；Web Frontend/Backend 必须是 B2 commit。
- [ ] 确认当前不存在 `tpl-web-backend-nest`；只有 B4 接受后才能改名。
- [ ] 确认当前 `tpl-admin-backend` 未被误当成 P0-005 安全母版。
- [ ] 确认三个业务 Web 未被修改、部署或打上 Web v2 完成标签。
- [ ] 将 B3 设为唯一代码任务；完成测试、证据、状态、提交后再激活 B4。
- [ ] B4 前不开始 B5；B5 前先验收 canonical FastAPI 母版。
- [ ] B6 后立即激活 P0-009A；P0-009E 前不开始 P0-008C 或普通业务开发。
- [ ] P0-009 严格按 Info -> Knowledge -> Research 串行，不同时覆盖三个 App。
- [ ] P0-008C 只使用 FastAPI 默认 profile；Nest 只保留模板契约门。
- [ ] 每个包关闭时同时记录 Git SHA、image digest、contract version、测试、部署、故障和
      回滚，不以聊天结论代替证据。

## 8. 禁止项

- 禁止 `git reset --hard`、`git clean -fd`、强制 push 或顺带处理业务仓已有提交。
- 禁止直接整树复制当前 `tpl-admin-backend` 后声称 FastAPI Web 完成。
- 禁止把 Admin 与 Web 合为一个 FastAPI 服务或共用 audience/cookie/session namespace。
- 禁止让 Next Route Handler 成为第三套通用 BFF。
- 禁止在同一生产入口随机混跑 FastAPI/Nest backend。
- 禁止在 B4 前改名远程仓，在 B6 前把 FastAPI 作为已冻结业务模板推广。
- 禁止 B6 后跳过 P0-009继续开发业务、Runtime 产品面、Memory/Subagent 或 P0-008C。
- 禁止用模板整树覆盖领域 Backend，或把基础同步误报为业务等价/正式切流。
- 禁止用 Nest profile 代替 P0-008C 或三个业务 Web 的 FastAPI 默认主线证据。
