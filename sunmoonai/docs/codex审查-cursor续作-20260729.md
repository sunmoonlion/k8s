# Codex 对 Cursor 续作的独立审查与收敛

日期：2026-07-29（Asia/Shanghai）

## 结论

Cursor 完成了大量有效的模板传播、领域缝合和隔离配对工作，但它提交的 P0-009E 不能
直接接受。Codex 已逐仓审查、修复、从干净源码重建 12 个镜像并重新运行全部门禁。
修正后的 P0-009E 现已 fail-closed 通过，因此：

- P0-009A/B/C/D/E：`ACCEPTED`
- Info、Knowledge、Research：`INSTANCE_FOUNDATION_ALIGNED`
- P0-008C：仅“已解锁”，尚未开工
- 业务流量：未切换
- 远端 Git：本审查完成时尚未推送

## 否决并修正的内容

1. 原 `verify_p0_009e_convergence.py` 含无条件真值，允许关键检查失效后继续通过。
2. KIND 不可达或缺少运行环境时会被记为 skipped，但总结果仍可能通过。
3. 原 clean-room 只复制少量文件，并未证明从冻结点可确定性重放完整目标树。
4. 原共享内核漂移判断只比较弱特征，不能发现一行级非授权漂移。
5. “业务 Deployment 未改变”曾是硬编码结论，而非完整 spec/generation 比对。
6. `docs/p0-009*-domain-keep/` 复制了旧源码树，其中包含环境文件、生成物和二进制，
   不适合作为 Git 内领域归档。
7. Knowledge 回滚曾以 `passed_with_caveat` 收口，不满足生产门禁。
8. 初版 Research Admin Backend 与共享 OIDC 内核存在未解释的一行漂移。

这些问题均已修复；历史 apply/stitch 一次性覆盖脚本已退休，不能再作为迁移入口。

## 最终验证

### 源码和构建

- B6 consumer vectors：passed
- B6 七模块 clean-room：passed
- 六个前端：typecheck、lint、i18n、unit、production build 全部 passed
- 六个后端：依各仓约定执行 Ruff、Pyright、Pytest，全部 passed
- 12 个组件均由当前干净源码重新构建并推送审计候选镜像

### 六组真实配对

| App | Admin | Web |
|-----|-------|-----|
| Info | strict TLS + real Casdoor passed | strict TLS + session/SSE passed |
| Knowledge | strict TLS + real Casdoor passed | strict TLS + session/SSE passed |
| Research | strict TLS + real Casdoor passed | strict TLS + session/SSE/citation passed |

最终镜像 digest 只以各 `V5-P0-009B/C/D/*-pair.json` 为准。

### 回滚、隔离和业务不变性

- 三个 App 均完成四组件“候选 → 兼容冻结模板 digest → 原候选”的真实运行时回滚。
- 每次恢复候选后重新执行 Admin/Web 配对。
- P0-009C/D 的完整 24 个非隔离 Deployment，以 metadata.generation 和完整 spec
  SHA-256 比对，零新增、零删除、零变更。
- P0-009B 的早期快照只捕获 9 个 Deployment；证据明确限定为这 9 个名称，不伪称全量。
  随后的 P0-009C/D 全量基线补足了整个收敛期的全局不变性证明。
- 所有 P0-009 隔离 Deployment、Service、IngressRoute、Job、Secret、Pod 均已清零。

## 严格 P0-009E 的通过条件

修正后的总门禁同时要求：

1. 12 个组件仓无未提交或未跟踪文件；
2. 所有 pair/rollback 证据 task id、result 和镜像 digest 格式严格正确；
3. 三 App 身份、领域标记和恢复清单存在；
4. 共享内核逐文件一致；仅显式登记的 service JWKS accessor 扩展可接受；
5. 12 个组件仓均可解析冻结 tag；
6. 从冻结 tag 生成完整 binary patch，在独立 clone 中应用后 Git tree 必须与目标 commit
   完全一致；
7. 归档和证据无环境文件、生成二进制或 secret-like 内容；
8. KIND 必须可达、节点 Ready 且不存在 P0-009 隔离资源；
9. `alignment-lock.json` 固定 12 个目标 commit/tree；后续漂移必须失败。

权威输出：

- `sunmoonai/docs/evidence/v5/V5-P0-009E/convergence.json`
- `sunmoonai/docs/evidence/v5/V5-P0-009E/drift-report.json`
- `sunmoonai/docs/evidence/v5/V5-P0-009E/alignment-lock.json`
- 三个父仓 `docs/INSTANCE_FOUNDATION_ALIGNED.json`

## 后续纪律

- Cursor 续作文档只用于了解历史，不再按其中旧 commit、旧 digest 或旧 overlay 命令施工。
- `INSTANCE_FOUNDATION_ALIGNED` 不等于业务等价、流量切换或生产发布。
- 下一代码任务仍为 P0-008C；开始前必须以 alignment lock 为起点。
- P0-008C 发现的通用缺陷先回流 `tpl-app`，再按受控传播流程同步实例；不得直接制造新的
  三仓漂移。
