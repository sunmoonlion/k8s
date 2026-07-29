# MoocManus v5 当前交接文档

> 文件名保留最初快照日期以避免旧链接失效；本文内容已于 **2026-07-29
> （Asia/Shanghai）更新至经 Codex 独立复验的 P0-009E ACCEPTED**。Cursor 续作的历史
> 自评不能覆盖本交接、严格证据和 alignment lock。
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
6. `sunmoonai/docs/mooc-manus-v5/adr/ADR-018-unified-next-frontend-surfaces.md`
7. 本文当前游标、仓库事实和禁止项
8. `sunmoonai/docs/evidence/v5/` 对应任务的原始证据

`mooc-manus-langgraph-longterm-plan-v4.md` 已归档，只能作为历史设计输入。聊天、旧镜像
tag、Pod Running、单个 smoke 或本文中的提交快照都不能覆盖 v5、Accepted ADR、任务状态
和当前只读核验结果。

## 2. 2026-07-26 已确认的架构决定

### 2.1 前端运行形态

- Admin/Web 默认均为 React 19 + Next 16 App Router；public route 可 static/SSG/受控
  ISR，受权 workspace dynamic/no-store，Client Component 承担交互；最终都以
  `standalone` Node 24.18.0 运行。
- 现有 React Router 8 Framework Mode `ssr:false` + Nginx Admin 已完成历史能力链，但
  不再是目标模板。它必须先在 P0-007D 与 B5 Admin Backend 最终配对并原子改名为
  `tpl-admin-frontend-react`，只作 legacy/reference。
- 渲染模式不决定身份模式。Admin/Web 都使用 backend-owned BFF session，浏览器不保存
  Provider token；前端守卫只改善 UX，最终授权在对应 Backend。

### 2.2 配对关系

```text
tpl-admin-frontend + tpl-admin-backend        # Next Node + FastAPI Admin（默认）
tpl-web-frontend   + tpl-web-backend          # Next Node + FastAPI Web（默认）
tpl-web-frontend   + tpl-web-backend-nest     # Next Node + Nest Web（可选 profile）
tpl-admin-frontend-react + tpl-admin-backend  # React Router/Nginx legacy（仅审计/恢复）
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

canonical `tpl-admin-backend` 的旧认证原型已在 B5 被替换为固定安全内核
`456bd65`；旧原型的 state 未持久/校验、缺少 PKCE/nonce/JWKS、只 base64 decode ID
Token、完整 Provider token 写 Redis、登录路径 DDL、GET logout 和原始 session 返回等
缺陷均已退出当前模板。以下顺序已经执行并由 B5 证据固定：

顺序必须是：

1. 从 Info/Knowledge/Research 已通过 P0-005 的代码中只回收通用安全/基础设施能力，
   反向补齐并验收 `tpl-admin-backend`。
2. 不得带入 Document、Ingestion、Run 等领域代码。
3. 由修复后 `tpl-admin-backend` 的固定 commit 初始化新的 FastAPI `tpl-web-backend`。
4. 立即替换成 Web surface/audience/cookie/Redis namespace/API allowlist/downstream
   relation；Admin Backend 不能直接充当 Web BFF。

### 2.5 Next 与 BFF 边界

- Browser `/`, `/_next/*` -> 对应 surface 的 Next；Browser `/api/*` -> 对应 surface
  的 FastAPI Backend。
- Server Component 只经 `server-only` DAL 调用配对 backend 内部 Service URL，只转发
  allowlist cookie、locale、correlation ID，返回最小 DTO。
- Next Route Handler 不复制 `/auth/*`、通用代理、领域写模型或 durable Run 状态。
- Admin/Web BFF 只负责 session/token mediation、授权、DTO、命令转发和受控 SSE；
  LangGraph
  长任务及 Run/Artifact/Retrieval/Citation 真相仍归 Runtime/领域数据库。

### 2.6 模板先行与实例立即收敛

- `tpl-app` B6 与四默认组件统一 `template_release_id` 已接受；React Router Admin 和 Nest
  Web Backend 只保留为 legacy/可选 profile。
- P0-009 已按 Info -> Knowledge -> Research 串行完成共同底座原地同步，并经 Codex
  重新构建 12 个镜像、六组真实配对、三套四组件真实回滚、完整 tree clean-room 和
  fail-closed P0-009E 总门禁复验。
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
- P0-008B/B3：Web interaction v1、Next SSE projection/reconcile、Citation/HITL 中性面和
  测试专用 Next+Nest 进程级配对门禁 accepted；不代表 B4 真实部署固化完成。
- P0-008B/B4：真实 Casdoor、严格 TLS、Next+Nest 2+2 Pod、CSP/CSRF/资源授权、SSE、
  Redis 跨副本、滚动/version-skew、回滚、immutable digest 和 Git tag 全部 accepted；
  Nest 仓与父仓 gitlink 已改名为 `tpl-web-backend-nest`。
- P0-008B/B5：canonical FastAPI Admin 内核与默认 FastAPI Web BFF 已固定；来源 tree、
  Web surface 隔离、interaction/downstream、源码、迁移、Docker、生产负向和 KIND 两
  副本门禁 accepted。
- ADR-017：模板统一 release 后立即按 Info -> Knowledge -> Research 收敛三个实例，
  共同底座对齐前冻结普通业务开发。
- ADR-018：Admin/Web 默认前端统一 Next；React Router Admin 先最终配对并改名 legacy，
  再以固定 Next Web 工程树和 React Router 完整能力矩阵建立新 canonical Next Admin。
- P0-007D：legacy `0b58adc`、父仓 `a280ea2`、双 frontend/单 backend immutable
  digest、真实 Casdoor 严格 TLS、105/75 连续滚动探测、18/18 跨版本资产、双向回滚和
  父仓递归 clean clone accepted；证据为
  `sunmoonai/docs/evidence/v5/V5-P0-007D/result.md`。
- P0-007E：Next Admin release `fb69795`、FastAPI Admin `69e634b`、父仓 `7089e19`、
  三份 Git tag、前后端 immutable digest、42+10 测试、真实 Casdoor 严格 TLS、2+2 Pod、
  41/44 连续滚动探测、18/18 跨版本资源与递归 clean clone accepted；证据为
  `sunmoonai/docs/evidence/v5/V5-P0-007E/result.md`。

### 当前状态

```text
P0-007D = ACCEPTED
P0-007E = ACCEPTED
P0-008B = ACCEPTED / B6_ACCEPTED
P0-009  = ACCEPTED / P0-009A_ACCEPTED / P0-009B_ACCEPTED / P0-009C_ACCEPTED / P0-009D_ACCEPTED / P0-009E_ACCEPTED
P0-008C = NOT_STARTED / P0-008C_NEXT
三个业务 Admin/Web 实例 = Info/Knowledge/Research INSTANCE_FOUNDATION_ALIGNED（未切流）
```

架构讨论已经收口。**唯一下一任务是 P0-008C**：在已对齐 Research 上做真实 Web 试点与
Next v2 冻结；common 缺陷必须回流 `tpl-app` 再传播。P0-009E 证据见
`sunmoonai/docs/evidence/v5/V5-P0-009E/result.md`。未切业务流量；正式分支与冻结标签
已推送，精确远端 ref 见 `sunmoonai/docs/evidence/v5/V5-P0-009E/remote-publish.json`。

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

### B3 UI/Query/Stream/Citation + Nest Pair — ACCEPTED

固定 `tpl-web-backend@e1876a4`、`tpl-web-frontend@d10cffa`、`tpl-app@8b1df6a`。已完成
严格 interaction v1、Next Query/SSE projection、cursor 去重与 gap reconcile、Citation
授权解析、HITL 和中性状态面；36+2 个 Nest 测试、31 个 Next 测试、6 个 Next+Nest
进程级 Playwright 通过。fixture 只在 Nest `test/fixtures`，未进入生产 AppModule；该结果
不冒充真实 Run/Retrieval、Casdoor/KIND 或正式 release。证据：
`sunmoonai/docs/evidence/v5/V5-P0-008B/B3/result.md`。

### B4 Nest Security/Paired Test/Deploy/Freeze — ACCEPTED

固定 Nest `947021c` / `p0-008b-b4-nest-20260726`、Next `f746255` /
`p0-008b-b4-next-20260726`、父仓改名后 `bc4c03f`。双 Pod、真实浏览器、
PKCE/CSRF/audience、SSE、CSP、滚动/version-skew、回滚和不可变 digest 门禁均通过；
现有远端和父仓路径已改名为 `tpl-web-backend-nest`。证据：
`sunmoonai/docs/evidence/v5/V5-P0-008B/B4/result.md`。

首轮滚动实际发现 asset 502，已用 preStop 排空、termination grace 和
minReadySeconds 修复；最终升级 72 次、回滚 87 次严格 TLS 连续探测均通过。Casdoor
`v3.42.0` 的 application-specific discovery issuer 与实际 token issuer 不一致，当前
严格使用标准 discovery 的唯一基础 issuer，禁止双 issuer 放宽；详见 ADR-005。

### B5 FastAPI Canonical Kernel + Default Web BFF — ACCEPTED

固定 Admin `456bd65`、FastAPI Web `6b6c71e`、父仓 `bd19ee2`；新 Web 初始化 commit
与固定 Admin tree 相同，随后只实施 Web surface/audience/cookie/namespace/API/
downstream 适配。Admin `34 passed`、Web `43 passed`，迁移 roundtrip、生产负向、
Docker 和 KIND 两副本门禁通过。证据：
`sunmoonai/docs/evidence/v5/V5-P0-008B/B5/result.md`。

### B6 Dual-profile Contract/Paired/Release Gate

状态：`B6.1_ACCEPTED / B6.2_ACCEPTED / B6.3_CURRENT_UNIQUE_TASK`。
P0-007E 已接受；COMMON 能力核与 Vue reference 配对已经关闭。

B6 必须按以下顺序完成，不能只做最后一项：

1. `B6.1 Frontend Common Kernel Parity`：`ACCEPTED`；能力已标为
   `COMMON/ADMIN_ONLY/WEB_ONLY/DEFERRED`，Next Web 7 项 COMMON 及独立测试已补齐；
   组件能力门与配对门继续分离。
2. `B6.2 Vue Legacy Intake + Admin Pair`：`ACCEPTED`；`tpl-admin-frontend-vue@9b3d29b`
   已纳入父仓，真实 Casdoor、严格 TLS、两副本、session/CSRF/logout、无远程 CDN 及
   Vue→Next→Vue 恢复通过；固定为 `REFERENCE_ONLY`。
3. `B6.3 Dual Web Profile Pair`：同一 Next Web 分别对 FastAPI/Nest 跑共享 consumer
   vectors 和配对 E2E。FastAPI 获得默认 release tuple；Nest 获得可选 tuple。
4. `B6.4 Unified Release/Clean-room`：递归 clean clone 七个子模块；默认 release 只含
   Next Admin、FastAPI Admin、Next Web、FastAPI Web，React Router Admin、Vue Admin、
   Nest Web 仅在 compatibility manifest 中列出。

每个 tuple 记录 contract version、前后端 digest、audience、profile、兼容矩阵和独立
回滚。B1~B6 全部接受后 P0-008B 才结束，并立即进入 P0-009。

模板配对唯一清单是 `tpl-app/frontend-pairing-matrix.json`，当前共五条：
Next Admin+FastAPI Admin（默认）、React Router Admin+FastAPI Admin（备查）、
Vue Admin+FastAPI Admin（备查）、Next Web+FastAPI Web（默认）和
Next Web+Nest Web（可选）。P0-007D 的 React 配对不得因为它已退出默认仓名而从矩阵遗漏。

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

## 5. 当前仓库事实（2026-07-28）

### k8s

- 分支：`codex-1`；本地包含 B4 deploy/identity/strict verifier/rollout verifier、ADR/
  plan/handoff/evidence 更新，必须以本轮最终 k8s commit 为准。
- KIND 保留隔离的 `tpl-web-backend-b4` 与 `tpl-web-frontend-b4` 各 2 个副本，最终状态为
  Nest r5 + Next v1；三个业务 Deployment 在 B4 全程未变化。

### tpl-app

- 父仓：`master@7089e19`；P0-007E 正式父标签与 6 子模块递归 clean clone 通过。
- `tpl-admin-backend@69e634b`：canonical FastAPI 安全母版及 Admin scope 修复；tag
  `p0-007e-admin-backend-20260728`。
- `tpl-admin-frontend-react@0b58adc`：React Router/Nginx legacy/reference；tag
  `p0-007d-react-legacy-20260728`；P0-007E 已消费其能力矩阵，此后只作审计和恢复输入。
- `tpl-admin-frontend@fb69795`：canonical Next Admin；tag
  `p0-007e-next-admin-20260728`，accepted 镜像 digest
  `sha256:b426551c0e027b25965995e23486c590c29fa52047779dd14721d93a245a74f1`。
- `tpl-web-backend-nest@947021c`：Nest B4 可选 profile；远端、tag、镜像 digest、真实
  identity/paired deploy/rollback 证据均已固定。
- `tpl-web-frontend@f746255`：Next B4 输入；server-only DAL/DTO、typed stream、
  Citation/HITL、nonce CSP 与 deployment identity 已接受。
- `tpl-web-backend@6b6c71e`：默认 FastAPI Web BFF；tag
  `p0-008b-b5-fastapi-web-20260726`，镜像 digest
  `sha256:f47f1ddd633cb3e8fa8561780a05e53c2f660193aed672d6b553d700dc9f2773`。
- 已清除父仓中未提交且与 React 默认方案冲突的旧 Vue 子模块暂存残留；未修改其远端 Git
  历史。

### 业务仓

- `info-app/codex-1@37988c8`：本次未修改。
- `research-app/codex-1@8121595`：本次未修改。
- `knowledge-app/codex-1@2e410ad`：本地相对 `origin/codex-1` ahead 3；这是进入本轮前已存在
  的提交，不得被 Web 模板任务重写、reset 或顺带包装。恢复时先独立核对是否已推送。

## 6. 集群、Harbor 与发布边界

本文 2026-07-28 已重新核验 P0-007E live cluster/Harbor，但业务 App 的旧 Pod/tag 仍不能
仅凭 handoff 推断为当前事实。任何 B6 build/push/rollout 前必须只读确认：

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

- [ ] 阅读 v5、implementation plan、ADR-014、ADR-016、ADR-017、ADR-018 和本文。
- [ ] 确认 v4 顶部是归档声明，不从 v4 恢复任务。
- [ ] 确认 k8s 文档变更已检查/提交，未混入运行代码。
- [ ] 确认 `tpl-app@7089e19` 的 gitlink、`.gitmodules` 和本地目录一致；Web Next 必须是
      `f746255`，FastAPI Web 必须是 `6b6c71e`，Nest profile 必须是 `947021c`。
- [ ] 确认 `tpl-web-backend-nest` 新远端、Git tag 和本地 origin 一致，旧
      `tpl-web-backend` 远端名称已释放，不能把 Nest 改回默认仓名。
- [ ] 确认 `tpl-admin-backend@69e634b` 与 `tpl-web-backend` 初始化 commit 使用同一固定
      tree，且 Web 后续差异只属于 surface 适配。
- [ ] 确认三个业务 Admin/Web 未被统一模板任务修改、部署或打上完成标签。
- [ ] 确认 P0-007D 的 legacy/parent tag、immutable tuple、双向回滚、改名和递归
      clean clone 证据仍成立，不把 legacy 放入业务发布矩阵。
- [ ] 确认 P0-007E 的三份 tag、前后端 digest、完整能力矩阵、clean-room、真实配对和
      双向回滚证据仍成立；将 B6 设为唯一任务。
- [ ] B6 未接受前不生成统一模板 release 或修改三个业务 App。
- [x] B6.1 COMMON 能力在 Next Admin/Web 均有实现与测试；ADMIN_ONLY/WEB_ONLY 未被
      错误复制；组件能力门与配对门分别有证据。
- [x] B6.2 Vue legacy 已作为父仓子模块固定，package/repo 身份无歧义；Vue+FastAPI
      Admin 真实配对和独立回滚通过，但未进入默认 release 或实例传播清单。
- [x] React Router Admin+FastAPI Admin 的 P0-007D 固定 tuple、真实浏览器、严格 TLS、
      2+2 和双向回滚证据已进入现行配对矩阵；它仍为 `REFERENCE_ONLY`。
- [ ] B6.3 Next Web+FastAPI 默认与 Next Web+Nest 可选均通过同一 consumer vectors 和
      独立真实配对。
- [ ] B6.4 七子模块递归 clean clone 可重放，统一 manifest 明确四默认/三非默认 tuple。
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
- 禁止把已固定的 React Router Admin 改回默认仓名，或让 P0-007E 新 Next Admin 继承其
  Git 历史/runtime。
- 禁止让新 Next Admin 继承 Web 仓 Git 历史、Web audience/cookie/namespace 或遗漏
  React Router 完整能力矩阵中的 MUST 项。
- 禁止在同一生产入口随机混跑 FastAPI/Nest backend。
- 禁止撤销 B4 已完成的 Nest 原子改名或让新 FastAPI 默认仓继承 Nest Git 历史；在 B6
  前不得把 FastAPI 作为已冻结业务模板推广。
- 禁止 B6 后跳过 P0-009继续开发业务、Runtime 产品面、Memory/Subagent 或 P0-008C。
- 禁止用模板整树覆盖领域 Backend，或把基础同步误报为业务等价/正式切流。
- 禁止用 Nest profile 代替 P0-008C 或三个业务 Web 的 FastAPI 默认主线证据。

## 9. 2026-07-29 P0-008C 恢复增量（当前权威入口）

P0-009A~E、统一 `1.0.0` 发布、凭据轮换、Harbor 安全裁剪和 GC 已完成。当前唯一激活
任务为 `V5-P0-008C`，实施清单以
`mooc-manus-langgraph-v5-implementation-plan.md` 的 `P0-008C.0~.7` 为准。

恢复时必须先接受以下代码事实：

- Research Next Web 当前有两套交互面：旧 `AgentConsole` 直连 `/api/agent`，以及只在
  Reference 开关下展示的 typed `/api/runs` 工作区。前者绕过 Web BFF，后者使用固定
  fixture Run；二者都不是 P0-008C 最终路径。
- Research FastAPI Web Backend 默认返回 `provider_unavailable`，目前没有真实
  `WebInteractionPort` Runtime adapter。
- Research Admin Worker 当前仍固定运行 Walking Skeleton。ADR-001 已接受的是 Custom
  Runtime 责任边界及隔离 spike 证据，不是该 worker 已取得生产资格。

因此不得直接把现有 `1.0.0` 镜像部署后宣布 P0-008C 完成。正确顺序是：

1. 冻结 Web Browser DTO、Runtime internal contract、service identity 与用户 delegation。
2. 实现默认关闭、可废弃的隔离 Custom Runtime candidate；真实使用 PostgreSQL durable
   state、Redis live signal、LangGraph interrupt/resume、Knowledge retrieval/citation。
3. 让 FastAPI Web BFF 通过独立服务身份适配该 candidate；浏览器只访问同源 Web BFF。
4. Next 页面统一到 typed `/api/runs`，移除验收路径对旧 `/api/agent` 与固定 fixture 的
   依赖。
5. 只在隔离 Host/Deployment 运行真实浏览器、故障、滚动和回滚矩阵；稳定入口保持不变。
6. common 缺陷先回流模板并重放 P0-009；Research-only 代码不得进入模板。

P0-008C 与 M1 的边界：本任务证明真实产品竖线及契约可行，不提前实现或宣称
M1-301~312 完成。正式 outbox/Attempt lease/reconciler/SSE v2 生产主链仍在 Gate P0
之后；试点 candidate 必须默认关闭、隔离部署、可删除且不得被稳定流量引用。

### 9.1 2026-07-29 C2~C4 代码完成增量

- C2 隔离 Runtime、C3 FastAPI Web BFF adapter、C4 typed Next workspace 已完成代码和
  本地测试；准确状态是 `CODE_ACCEPTED`，不是环境 `ACCEPTED`。
- Runtime internal-only 部署不得借用稳定 Admin/Web 浏览器 client secret；新增
  `BROWSER_IDENTITY_ENABLED=false` 只允许与完整 pilot 配置同时启用，默认稳定行为不变。
- 下一游标固定为 C5：先由 `build_p0_008c_images.sh --all` 取得三项 digest，再运行
  `provision_p0_008c_identities.sh --apply`，最后由
  `deploy_p0_008c_research_pilot_kind.sh --apply` 只部署隔离资源。
- C5 前必须由受控 Secret 提供真实 LLM base URL/key/model。不得把 key 写入命令、文档、
  `.env`、generated YAML、镜像 ARG/ENV 或日志；脚本不会猜测 Provider 凭据。
- 当前尚无候选镜像/digest/隔离资源/真实竖线证据，稳定 `1.0.0` tuple 与流量未改变。
