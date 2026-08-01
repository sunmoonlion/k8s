# V5-P0-009C Knowledge Foundation Adoption

日期：2026-07-29（Asia/Shanghai）  
最终集成分支：`k8s/codex-1`；Knowledge 父仓及四子仓 `codex-1`
远端 Git：**未推送**

## 结论

P0-009C **经 Codex 复核后本地 ACCEPTED**（全量源码门禁 + 干净源码镜像 +
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

**原地同步底座**（与 009B 相同）：不整仓 tpl 实例化。  
Admin FE：Vue legacy → Next Admin + 最小 Knowledge ingestions 域壳。  
Admin BE：FastAPI 内核同步 + Dataset/Ingestion/Retrieval 领域保留（含 alembic `20260715_0003`）。  
Web FE：Next Web 底座。  
Web BE：Nest → FastAPI Web BFF。

## 候选镜像（Harbor Kind）

复核 tag：`p0-009e-audit-r2-20260729`（验收引用只认 digest）

| 镜像 | digest |
|------|--------|
| knowledge-admin-frontend | `sha256:85b66d68d54784e6a70f3f5d51a7893db62dea4d2a64a91672c66a037d8e3efb` |
| knowledge-admin-backend | `sha256:0b8b949fd2247395f5df329dc705b32b39c33af9d195adf43f3a50865fe8701d` |
| knowledge-web-frontend | `sha256:597193f3d16334e2d81b24c6cd00b54e361fa810f284ba7c11db72f5f34a7cd4` |
| knowledge-web-backend | `sha256:a2718a1b254eddc81b096836c8bb2e86e8be52a3dfa25c6da6295b04bcb545f1` |

## 门禁

| 门禁 | 结果 | 证据 |
|------|------|------|
| Admin FE typecheck/lint/unit/i18n/build | passed | 本地运行 |
| Web FE typecheck/lint/unit/i18n/build | passed | build 需 `NEXT_PUBLIC_API_URL=/api` |
| Admin BE ruff/pytest/pyright | passed | 81 pytest；pyright 0 errors |
| Web BE ruff/pytest | passed | 43 passed / 2 skipped |
| Admin 隔离配对（Casdoor 严格 TLS） | passed | `admin-pair.json` |
| Web 隔离配对（Casdoor 严格 TLS + SSE） | passed | `web-pair.json` |
| 四组件真实回滚及回滚后复验 | passed | `rollback.json` + pair JSON |
| 24 个非隔离 Deployment 完整 spec/generation 未变 | passed | `business-deployments-unchanged.json` |
| cleanup | passed | `cleanup.log` |

## 关键修复 / 缝合

1. Admin BE：tpl 内核同步后合并双 service boundary（ingest/retrieve）、RAGFlow、S3 artifact 配置。  
2. 补回 `dispatch_knowledge_ingestion` + `_delivery_options`；公开 `OidcProviderClient.get_key_set`。  
3. 复制 `audit_context.py`；`tasks_routes` → `require_knowledge_admin`；挂载 tasks + knowledge routers。  
4. 测试身份 `knowledge` / cookie / session prefix；internal 路由允许 service-auth deps。  
5. Admin FE：新建 `/knowledge/ingestions` 最小域壳（Vue 无既有 Dataset 页可迁）。  
6. 隔离 Deploy：**`AUTH_APP=knowledge`**；verify 脚本 `user.app === 'knowledge'`。

## 回滚语义

- Git：`p0-009a-pre-20260729`（本地 annotated tag，未 push）。  
- 镜像：四组件已执行候选 → 兼容冻结模板 digest → 原候选 digest，并完成恢复后复验。
- 流量：本任务未切换业务 Ingress/Deployment。  
- 本轮隔离资源已 cleanup。

## 下一任务

历史下一任务为 P0-009D；当前总游标以 `V5-P0-009E/result.md` 为准。
