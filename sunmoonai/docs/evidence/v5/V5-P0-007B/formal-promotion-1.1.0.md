# P0-007B Info Admin 正式镜像固化清单（已撤回草案）

状态：`WITHDRAWN_BLOCKED_BY_VERSION_POLICY`

> 本文件中的 `1.1.0` promotion 命令禁止执行。它是版本决策完成前生成的旧草案，保留仅用于审计，不能作为 Runbook。

## 范围

本清单只固化已经完成 P0-007B 真实业务试点并通过 P0-007C 模板冻结的 Info
React Admin。它不固化 Knowledge/Research；两者当前仍是 Vue 基线，必须等待各自
React 等价迁移和独立验收。

旧正式版本 `1.0.1` 继续保留为 Vue 回滚基线，不覆盖、不删除。`p0-*` candidate
也保留为审计和回滚证据，不作为普通部署默认值。当前不产生 `1.1.0`，也不允许
用 React 镜像覆盖 `1.0.1`；统一 release version 必须在三个 Admin React 迁移完成
后通过单独决策确定。

## Candidate 输入（不可变）

| 组件 | candidate | 期望 manifest digest |
| --- | --- | --- |
| Info Admin backend + celeryworker | `info-admin-backend:p0-007b-concurrency-20260714` | `sha256:d665089b011e798d2be0da2ad3f17c182259869fb970a7abfb14872214707dea` |
| Info Admin frontend | `info-admin-frontend:p0-007b-concurrency-20260714` | `sha256:3c1a7e4ad40d5e0abea4f7ad629ac6362216c4ea7cd910f3d1f2c8620ee6cd8b` |

这些 digest 已通过严格 TLS、浏览器身份、CSP、mutation、并发、恢复和无外连矩阵。
Promotion 前仍必须由执行者通过 registry inspect 复核，不能只相信本地 tag。

## 原草案规则（禁止执行）

本节只说明为什么草案被撤回：Info 单独提升为 `1.1.0` 会造成阶段版本和组件版本混淆；复用或覆盖
`1.0.1` 又会破坏不可变 tag 与 Vue 回滚资产。因此在版本治理 ADR/统一 release manifest
完成前，不执行任何 retag、push 或正式 Deployment 切换。

## 原执行流程（已禁用）

旧草案中的 pull/tag/push、KIND 部署和回滚命令已从本文件移除，防止误复制执行。下一版正式 Runbook
必须在版本决策后重新生成，并包含统一的 release manifest、不可变 digest 和回滚观察期。
正式路径仍必须核对 Deployment imageID/digest，保持 `V5_FRONTEND_TEST_MODE=false`，禁止用隔离测试开关绕过 `p0-*` tag 门禁。

旧 Vue 回滚基线、candidate digest 和正式切换命令将在统一版本决策后另行生成；在此之前不得删除 candidate、旧 `1.0.1` 或通过复用 tag 隐藏版本。
