# V5-P0-009B Info Foundation Adoption

日期：2026-07-29（Asia/Shanghai）  
最终集成分支：`k8s/codex-1`；Info 父仓及四子仓 `codex-1`
远端 Git：**未推送**

## 结论

P0-009B **经 Codex 复核后本地 ACCEPTED**（全量源码门禁、由当前干净源码重建的
digest 镜像、严格 TLS/Casdoor Admin 与 Web 隔离配对、四组件真实回滚、回滚后复验及
零残留清理）。业务 Info/Knowledge/Research 稳定 Deployment **未切流量**。

## 模板基线

`template_release_id=p0-008b-b6-unified-20260729`

| 组件 | 模板 commit |
|------|-------------|
| Admin FE | `fb69795` |
| Admin BE | `69e634b` |
| Web FE | `1db9377` |
| Web BE | `289f2c4` |

## 候选镜像（Harbor Kind）

复核 tag：`p0-009e-audit-r2-20260729`（验收引用只认 digest）

| 镜像 | digest |
|------|--------|
| info-admin-frontend | `sha256:3cb6966c4f0eef9d2121333318b94a05cce60630809578a222215fb72a4b6954` |
| info-admin-backend | `sha256:06baa0ba2c0deb7bf9408bab3a4ecc1d459dafdc19611d8ecd77041acbc5b43a` |
| info-web-frontend | `sha256:b3429e8aa06a2bf156e816ffe7c86f644c6d30754c633768a0813231d4ae66d5` |
| info-web-backend | `sha256:b6a5a2e26f2409ed732c06179b3cbeabdbf29f61daf1aa7ac145df52b3b01c48` |

## 门禁

| 门禁 | 结果 | 证据 |
|------|------|------|
| Admin FE typecheck/lint/unit/i18n/build | passed | 本地运行日志 |
| Web FE typecheck/lint/unit/i18n/build | passed | 本地运行日志（build 需 `NEXT_PUBLIC_API_URL=/api`） |
| Admin BE ruff/pytest/pyright | passed | 87 pytest；领域 E501/B008/UP046 已 ignore |
| Web BE ruff/pytest | passed | 43 passed / 2 skipped |
| Admin 隔离配对（Casdoor 严格 TLS） | passed | `admin-pair.json` |
| Web 隔离配对（Casdoor 严格 TLS + SSE） | passed | `web-pair.json` |
| 四组件候选→冻结基线→候选回滚 | passed | `rollback.json` |
| 回滚后 Admin/Web 配对 | passed | `admin-pair.json` / `web-pair.json` |
| 业务 Deployment 未变 | passed（早期基线明确只覆盖所捕获的 9 个） | `business-deployments-unchanged.json` |
| 隔离资源零残留 | passed | KIND 总门禁 |

## 关键修复

1. Admin BE：合并领域 config（crawl/S3/ES/Knowledge/outbox）；补回 Celery `dispatch_*`；同步 `main.py` / `principal.py` / exception handlers；挂载受保护 `/internal/tasks`。
2. 身份测试：cookie/prefix/scope/`app` 改为 `info`。
3. 隔离 Deploy：`AUTH_APP=info`（曾误留 `tpl` 导致登录后无法进入 dashboard）。
4. Web BE：`uv.lock` 包名 `info-web-backend`。

## 回滚语义

- Git：`p0-009a-pre-20260729`（本地 annotated tag，未 push）。
- 镜像：四组件均已执行候选 → 与当前清单兼容的冻结模板 digest → 原候选 digest，
  且恢复后重跑 Admin/Web 配对。
- 流量：本任务未切换业务 Ingress/Deployment。

## 下一任务

历史下一任务为 P0-009C；当前总游标以 `V5-P0-009E/result.md` 为准。
