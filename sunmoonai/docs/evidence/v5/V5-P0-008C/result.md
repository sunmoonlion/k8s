# V5-P0-008C Research Web 真实试点证据

日期：2026-07-29；阶段收口：2026-08-01

状态：`PAUSED_FOR_ARCHITECTURE_REVIEW / NOT_ACCEPTED /
P0-008C.0_ACCEPTED / P0-008C.1_ACCEPTED /
P0-008C.2_CODE_ACCEPTED / P0-008C.3_CODE_ACCEPTED /
P0-008C.4_CODE_ACCEPTED / P0-008C.5_BUILD_ACCEPTED /
P0-008C.5_DEPLOY_BLOCKED_MISSING_LLM_SECRET / P0-008C.6_NOT_RUN`

## 1. 已完成前置

- P0-008B、P0-009A~E：ACCEPTED。
- 三个实例：`INSTANCE_FOUNDATION_ALIGNED`。
- 统一 `1.0.0` 发布、凭据轮换、旧凭据拒绝与 Harbor 清理：
  `../V5-RELEASE-1.0.0/result.md`。
- Runtime 责任边界：ADR-001 `CANDIDATE_A_SELECTED`。
- Retrieval/Citation 与身份：P0-004、P0-005 ACCEPTED。

## 2. 2026-07-29 初始源码调用链审计

| 层 | 当前事实 | P0-008C 结论 |
|---|---|---|
| Next Web | 旧 `/api/agent` 控制台与固定 Reference Run 并存 | 两者均不得作为最终验收路径 |
| FastAPI Web BFF | production 默认 `UnavailableWebInteractionAdapter` | 必须实现真实 Runtime adapter |
| Custom Runtime | ADR-001 spike 可运行但明确可废弃 | 只复用语义/契约，不直接转正 spike |
| Admin Worker | 固定 `build_walking_skeleton_graph()` | 不能作为真实 Runner 或成功证据 |
| Retrieval | KnowledgePort/真实 RAGFlow/Citation 已有 P0-004 证据 | 必须在本轮真实 Run 内重新贯通 |

上述前三个代码断点已经由第 5 节的隔离 candidate、Web BFF adapter 和 Next product
surface 修复；本表保留为施工输入，不再代表当前 HEAD。

## 3. 不变量

- 浏览器只访问同源 Research Web Backend，不持有 Runtime service token。
- Web BFF 与 Runtime 使用独立 client-credentials，并携带受约束的用户 delegation。
- Reference Adapter、fake SSE、fake citation、hardcode Run success 不进入试点。
- 所有候选配置默认关闭，只在隔离 Host/Deployment 启用。
- 稳定 Deployment、Ingress、Secret、PVC 和 `1.0.0` tag 在最终切流任务前保持不变。
- common/template 缺陷先回流模板并重放 P0-009，禁止 Research-only patch 冒充模板修复。

## 4. Contract/Ownership Freeze

权威契约：

- `contracts/research-agent-web/v1/`：浏览器 create/cancel 命令；复用
  `web-interaction/v1` 的 snapshot/SSE/HITL/citation/error。
- `contracts/research-runtime/v1/`：Web BFF 到隔离 Runtime 的 internal route、delegated
  user 与 resume/cancel command。

已冻结：

- 浏览器只使用同源 HttpOnly Web session + mutation CSRF，不得获得 service token。
- Web BFF 只用独立 client-credentials；不得转发浏览器 token。
- delegated actor 只在 caller 通过 exact issuer/audience/subject/local relation 后接受，
  每个 Run/Citation 仍按 actor ownership 校验。
- Runtime candidate 默认关闭、不接稳定流量、不等于 M1 production Runtime、Gate P0 后
  可废弃。

门禁：

```text
python3 sunmoonai/docs/mooc-manus-v5/scripts/verify_p0_008c_contracts.py
{"browser_contract": "sunmoonai.research.agent-web", "browser_service_token": "forbidden", "result": "passed", "runtime_contract": "sunmoonai.research.runtime", "runtime_default_enabled": false, "stable_traffic": false, "task": "V5-P0-008C.1"}
```

## 5. C2~C4 代码门禁

### 5.1 C2 Isolated Runtime candidate

- Research Admin Backend commits：`a0ba9ec`（Runtime candidate）与 `fccf73d`
  （纯 internal Runtime 浏览器身份闭锁）。
- 使用独立 pilot repository、internal routes、Celery task 和 LangGraph graph；
  Walking Skeleton 未被接入试点路径。
- create/snapshot/SSE/cancel/resume/citation 使用真实 PostgreSQL journal、Redis
  live signal、LangGraph interrupt/resume、KnowledgePort 和 OpenAI-compatible
  Provider；未引入 fake success、fixture Evidence 或 Reference Adapter。
- resume dispatch unavailable/rejected 时，已消费命令会落 durable
  `resume_dispatch_failed` 终态；幂等重放不再次 dispatch。
- internal-only Runtime 不再借用 Admin/Web 浏览器 client secret；关闭浏览器身份的配置
  默认禁止，且只能在完整 `AGENT_PILOT_ENABLED` 闭锁通过时启用。

门禁：

```text
cd /home/zymun/research-app/research-admin-backend/app
uv run pytest -q && uv run ruff check . && uv run pyright
123 passed
All checks passed!
0 errors, 0 warnings, 0 informations
```

### 5.2 C3 FastAPI Web BFF

- Research Web Backend commit：`6e79f12`。
- 浏览器只访问同源 `/api/runs`；BFF 通过独立 service identity 访问 exact
  `/internal/v1/research` allowlist，并以约束 header/command 传递 delegated actor。
- create/get/SSE/action/cancel/citation 的 DTO、状态映射、超时、非缓冲 SSE 与断线清理
  均有测试；production 默认仍关闭，Reference 与 Runtime adapter 互斥。

```text
cd /home/zymun/research-app/research-web-backend/app
uv run pytest -q && uv run ruff check . && uv run pyright
48 passed, 2 skipped
All checks passed!
0 errors, 0 warnings, 0 informations
```

### 5.3 C4 Next Product Surface

- Research Web Frontend commit：`8f3d45b`。
- 产品 dashboard 已删除旧 `/api/agent` 控制台和固定 fixture Run，统一使用 typed
  `/api/runs`，实现 create、URL 恢复、snapshot/SSE reconciliation、HITL、cancel、
  citation 和新 Run。
- typecheck、lint、i18n 与 Vitest 已通过；2026-08-01 C5 Docker 内的 Next 16.2.2
  Turbopack production build 已通过并生成 standalone runtime。此前受限环境中的本地
  build 失败不再是当前阻塞。

```text
44 passed, 2 skipped
```

### 5.4 可重复 C5 施工入口

- `scripts/build_p0_008c_images.sh`：只接受三个干净 `codex-1` worktree，构建 Runtime、
  FastAPI Web BFF、Next standalone，检查镜像命令和 history，再输出 pushed digest。
- `scripts/provision_p0_008c_identities.sh`：分别建立浏览器 authorization-code 和
  BFF→Runtime client-credentials 应用；以真实 RS256 token 确认 exact
  issuer/audience/subject 后生成本地 binding，凭据/token 不输出。
- `scripts/deploy_p0_008c_research_pilot_kind.sh`：只接受 digest；部署相互隔离的 Web/
  Runtime PostgreSQL、Redis、migration、2×Runtime API、1×worker、2×BFF 和 2×Next；
  稳定 Deployment/Ingress/Secret/PVC 不变，并提供 task-scoped cleanup。
- 部署在变更集群前强制要求 `sunmoonai-p0-008c-llm`、浏览器/服务身份、
  Knowledge retrieval identity 和 broker Secret；不得由脚本猜测或生成 Provider key。

## 6. 2026-08-01 C5 构建、身份与闭锁结果

三项镜像均由已提交的干净 `codex-1` worktree 构建、推送并使用 Harbor 远端 manifest
按 digest 复验：

| 组件 | commit | 候选 tag | Harbor digest |
|---|---|---|---|
| Research Runtime API/worker | `fccf73d` | `p0-008c-runtime-20260801` | `sha256:2937158690143bd81c192c383c891f0b7b12e45c490e68d09069f73cdecad42c` |
| FastAPI Research Web BFF | `6e79f12` | `p0-008c-bff-20260801` | `sha256:a0ccb4b684d79a5fa14ae38f69cdb80a09b171d8dea82e50e0fa1ab3fd51d06d` |
| Next Research Web | `8f3d45b` | `p0-008c-next-20260801` | `sha256:8e04f030b4e060e251a1daf192ba72d721645f6ba871cb99832087ea80ef81ac` |

身份施工结果：

- 独立浏览器 authorization-code application reconciliation 通过。
- 独立 BFF→Runtime client-credentials application reconciliation 通过。
- 真实 RS256 token 的 issuer/audience/subject probe 通过；token、client secret 未输出。
- 部署预检发现 `app-platform-dev/sunmoonai-p0-008c-llm` 不存在并在创建任何运行资源前
  fail closed，退出码为 `1`。
- 集群及本地受控配置只发现示例文件；没有 `DASHSCOPE_API_KEY`、`OPENAI_API_KEY` 或
  `AGENT_PILOT_LLM_API_KEY` 的可用 Secret。RAGFlow/Knowledge 的现有凭据未被挪用。

清理结果：

- P0-008C Deployment、Service、IngressRoute、PDB、ConfigMap、runtime Secret：零残留。
- 两个 P0-008C Casdoor application 与三项 identity/binding Secret 已删除。
- label `sunmoonai.com/task=v5-p0-008c` 查询为空。
- 稳定 Research 六个 Deployment 均保持 `1/1 Ready`，镜像与入口未被本任务修改。
- 三项 Harbor 候选保留为本证据引用的可重建 artifact；未提升为 `1.0.0`、未被任何
  Deployment 引用。

## 7. 阶段结论与暂停边界

本轮已经完成 contract、Runtime/Web BFF/Next 代码、测试、生产镜像、服务身份及部署
fail-closed 机制，但**没有完成真实 LLM、真实竖线、浏览器/故障矩阵，因此
P0-008C 不得标记 ACCEPTED**。根据 2026-08-01 决策，任务在架构重新评审前暂停：

- 不补 dummy key，不复用 RAGFlow credential，不运行 fake/mock 竖线。
- 不部署候选、不切稳定流量、不提升 stable tag。
- 架构评审若保留本路径，恢复前先决定 LLM credential/provider governance，再从 C5
  digest 与隔离部署重放；若推翻 Runtime/BFF 边界，三项候选按可废弃试点处理。
- 暂停期间不开始 M1 Runtime、Memory/Subagent 或任何依赖 P0-008C ACCEPTED 的任务。

## 8. 门禁追踪

- [x] P0-008C.1 Browser/Internal contract 与身份边界。
- [x] P0-008C.2 隔离 Runtime candidate 代码单元、契约与故障测试。
- [x] P0-008C.3 FastAPI Web adapter 单元/contract/security。
- [x] P0-008C.4 Next product surface 单元测试与生产 Docker build。
- [x] P0-008C.5 固定 commit、三镜像 digest、身份和 fail-closed/cleanup；隔离运行部署
      因缺少专用 LLM Secret 未执行。
- [ ] P0-008C.6 真实竖线及完整故障/安全矩阵。
- [ ] P0-008C.7 模板回流判定、Next v2 freeze、clean-room 与零残留。
