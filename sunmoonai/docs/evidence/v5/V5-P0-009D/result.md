# V5-P0-009D Research Foundation Adoption

日期：2026-07-29（Asia/Shanghai）  
最终集成分支：`k8s/codex-1`；Research 父仓及四子仓 `codex-1`
远端 Git：**未推送**

## 结论

P0-009D **经 Codex 复核后本地 ACCEPTED**（全量源码门禁 + 干净源码镜像 +
KIND 严格 TLS/Casdoor Admin/Web 配对 + 四组件真实回滚 + 回滚后复验 + 零残留 cleanup）。
业务 Info/Knowledge/Research 稳定 Deployment **未切流量**；隔离候选已清理。

## 模板基线

`template_release_id=p0-008b-b6-unified-20260729`

| 组件 | 模板 commit |
|------|-------------|
| Admin FE | `fb69795` |
| Admin BE | `69e634b` |
| Web FE | `1db9377` |
| Web BE | `289f2c4` |

## 策略

**原地同步底座**（与 009B/009C 相同）。  
Admin FE：Vue → Next Admin + 最小 Runtime 域壳。  
Admin BE：FastAPI 内核同步 + agent/runtime 领域保留（alembic `20260712_0002`）。  
Web FE：Next Web 底座 + 回迁 `AgentConsole`。  
Web BE：Nest → FastAPI Web BFF。  
**未**提前做 P0-008C 产品试点。

## 候选镜像（Harbor Kind）

复核 tag：前端/Web 后端为 `p0-009e-audit-r2-20260729`；Admin Backend 为修正内核
漂移后的 `p0-009e-audit-r3-20260729`（验收引用只认 digest）。

| 镜像 | digest |
|------|--------|
| research-admin-frontend | `sha256:f4225868225bcffe9d34e482ebad132ee13c6ac000e31820bcfe7be6efdc1e4c` |
| research-admin-backend | `sha256:1b9c3b6b5e5af377961ff2e2b2ae861d6057e878663ab671674a1c25dd5c774b` |
| research-web-frontend | `sha256:e0ce9a48084a2506448a756bdb4b6fe92b1e210ab49c073781a4a832cf958851` |
| research-web-backend | `sha256:901ee1c2fd0ddcacc178a832ec215c84ad6237e81a02030300107030e9df8202` |

## 门禁

| 门禁 | 结果 | 证据 |
|------|------|------|
| Admin FE typecheck/lint/unit/i18n/build | passed | 本地 |
| Web FE typecheck/lint/unit/i18n/build | passed | 本地 |
| Admin BE pyright/pytest | passed | 113 passed |
| Web BE ruff/pytest | passed | 43 passed / 2 skipped |
| Admin 隔离配对 | passed | `admin-pair.json` |
| Web 隔离配对 | passed | `web-pair.json` |
| 四组件真实回滚及回滚后复验 | passed | `rollback.json` + pair JSON |
| 24 个非隔离 Deployment 完整 spec/generation 未变 | passed | `business-deployments-unchanged.json` |
| cleanup | passed | `cleanup.log` |

## 关键缝合

1. Admin BE：合并 `agent_*` + `knowledge_retrieval_*`（跨 App relation 名不改）。  
2. 补回 `dispatch_agent_graph` + `_delivery_options`；`get_key_set`；`audit_context`。  
3. routes：`tasks` + `agent` + `require_research_admin`。  
4. Admin FE：`/research/runtime` 最小域壳。  
5. Web FE：模板 dashboard + `AgentConsole`；隔离 **`AUTH_APP=research`**。

## 下一任务

P0-009E 已完成严格复核；当前总游标以 `V5-P0-009E/result.md` 为准。
