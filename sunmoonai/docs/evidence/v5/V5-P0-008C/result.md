# V5-P0-008C Research Web 真实试点证据

日期：2026-07-29

状态：`IN_PROGRESS / P0-008C.0_ACCEPTED / P0-008C.1_ACCEPTED /
P0-008C.2_IN_PROGRESS`

## 1. 已完成前置

- P0-008B、P0-009A~E：ACCEPTED。
- 三个实例：`INSTANCE_FOUNDATION_ALIGNED`。
- 统一 `1.0.0` 发布、凭据轮换、旧凭据拒绝与 Harbor 清理：
  `../V5-RELEASE-1.0.0/result.md`。
- Runtime 责任边界：ADR-001 `CANDIDATE_A_SELECTED`。
- Retrieval/Citation 与身份：P0-004、P0-005 ACCEPTED。

## 2. 2026-07-29 源码调用链审计

| 层 | 当前事实 | P0-008C 结论 |
|---|---|---|
| Next Web | 旧 `/api/agent` 控制台与固定 Reference Run 并存 | 两者均不得作为最终验收路径 |
| FastAPI Web BFF | production 默认 `UnavailableWebInteractionAdapter` | 必须实现真实 Runtime adapter |
| Custom Runtime | ADR-001 spike 可运行但明确可废弃 | 只复用语义/契约，不直接转正 spike |
| Admin Worker | 固定 `build_walking_skeleton_graph()` | 不能作为真实 Runner 或成功证据 |
| Retrieval | KnowledgePort/真实 RAGFlow/Citation 已有 P0-004 证据 | 必须在本轮真实 Run 内重新贯通 |

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

## 5. 待补证据

- [x] P0-008C.1 Browser/Internal contract 与身份边界。
- [ ] P0-008C.2 隔离 Runtime candidate 单元、契约与故障测试。
- [ ] P0-008C.3 FastAPI Web adapter 单元/contract/security。
- [ ] P0-008C.4 Next product surface 单元/浏览器测试。
- [ ] P0-008C.5 固定 commit、镜像 digest、隔离部署与回滚清单。
- [ ] P0-008C.6 真实竖线及完整故障/安全矩阵。
- [ ] P0-008C.7 模板回流判定、Next v2 freeze、clean-room 与零残留。
