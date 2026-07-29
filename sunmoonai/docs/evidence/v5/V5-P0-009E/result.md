# V5-P0-009E Convergence Gate

日期：2026-07-29（Asia/Shanghai）  
最终集成分支：`k8s/codex-1`；Info / Knowledge / Research 父仓及 12 个组件均为 `codex-1`
远端 Git：**未推送**

## 结论

P0-009E **经 Codex 重新实现门禁并复核后本地 ACCEPTED**。原 Cursor 校验器存在
`or True`、KIND 不可达仍跳过、弱漂移比较和伪 clean-room 等 fail-open 问题，原结论不作为
验收依据。本次通过基于修正后的 fail-closed 校验器：12 个组件仓必须干净、完整
freeze→目标 binary patch 重放后的 Git tree 必须逐仓一致、六组配对必须引用 digest、
三 App 四组件真实回滚必须通过、共享内核漂移必须逐文件可解释、KIND 必须可达且零残留。
三 App 均标记 `INSTANCE_FOUNDATION_ALIGNED`。  
业务 Info/Knowledge/Research 稳定 Deployment **未切流量**；远端 **未推**。

**P0-009 整体 ACCEPTED**；下一任务解锁 **P0-008C**（本波未开工）。

## 模板基线

`template_release_id=p0-008b-b6-unified-20260729`  
预迁移冻结 tag：`p0-009a-pre-20260729`（12 个组件仓 tag 可解析）

| 组件 | 模板 commit |
|------|-------------|
| Admin FE | `fb69795` |
| Admin BE | `69e634b` |
| Web FE | `1db9377` |
| Web BE | `289f2c4` |

## 六组基础配对（汇总）

| 配对 | 结果 | 证据来源 |
|------|------|----------|
| info-admin | passed | `V5-P0-009B/admin-pair.json` |
| info-web | passed | `V5-P0-009B/web-pair.json` |
| knowledge-admin | passed | `V5-P0-009C/admin-pair.json` |
| knowledge-web | passed | `V5-P0-009C/web-pair.json` |
| research-admin | passed | `V5-P0-009D/admin-pair.json` |
| research-web | passed | `V5-P0-009D/web-pair.json` |

完整 digest 见 `convergence.json`；证据 blob 无 secret 输出。

## 门禁

| 门禁 | 结果 | 证据 |
|------|------|------|
| 009A freeze + release id | passed | `V5-P0-009A/freeze.json` |
| 009B/C/D ACCEPTED | passed | 各 `result.md` |
| 共享 contract / pairing matrix | passed | `tpl-app` manifest |
| 实例身份 + 领域针 + recovery manifest | passed | `convergence.json` → `identity_domain_recovery` |
| 内核漂移（可解释） | passed | `drift-report.json` |
| freeze-tag 可解析（12 repos） | passed | `convergence.json` → `rollback_tags` |
| freeze→目标完整 binary patch clean-room tree 重放 | passed | `convergence.json` → `clean_room` |
| 三 App 四组件运行时回滚 + 恢复后复验 | passed | 009B/C/D `rollback.json` + pair JSON |
| 归档、生成物、二进制与证据敏感信息卫生 | passed | `convergence.json` → `archive_hygiene` |
| KIND 隔离残留 | passed | `kind_hygiene` |
| `INSTANCE_FOUNDATION_ALIGNED` | written | 三 App `docs/INSTANCE_FOUNDATION_ALIGNED.json` |

脚本：`docs/mooc-manus-v5/scripts/verify_p0_009e_convergence.py`

## 对齐标记

| App | 状态 | 路径 |
|-----|------|------|
| info | `INSTANCE_FOUNDATION_ALIGNED` | `info-app/docs/INSTANCE_FOUNDATION_ALIGNED.json` |
| knowledge | `INSTANCE_FOUNDATION_ALIGNED` | `knowledge-app/docs/INSTANCE_FOUNDATION_ALIGNED.json` |
| research | `INSTANCE_FOUNDATION_ALIGNED` | `research-app/docs/INSTANCE_FOUNDATION_ALIGNED.json` |

`traffic_cutover=false`，`remote_git_push=false`。

`alignment-lock.json` 固定 12 个组件的 commit 与 tree；以后任一组件漂移都会使本门禁失败，
不能复用本次 ACCEPTED 结论。

## 边界（本波未做）

- 未切业务流量；未删旧 Vue/Nest 稳定镜像。  
- 未推 Gitee。  
- **未开始 P0-008C** Research 真实试点。

## 下一任务

**P0-008C** Research Web 真实试点与 Next v2 冻结（仅在已对齐 Research 上隔离入口；common 缺陷回流 `tpl-app`）。
