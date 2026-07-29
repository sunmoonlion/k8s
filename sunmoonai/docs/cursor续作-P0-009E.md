# Cursor 续作 Wave-5：P0-009E Convergence Gate

> **审计状态（2026-07-29）**：本文记录 Cursor 当时的自评，原 P0-009E 校验器存在
> fail-open，故原 ACCEPTED 已作废。Codex 已重写并重跑严格门禁；只有
> [`evidence/v5/V5-P0-009E/result.md`](./evidence/v5/V5-P0-009E/result.md)、
> `convergence.json` 和 `alignment-lock.json` 是当前验收依据。完整差异见
> [`codex审查-cursor续作-20260729.md`](./codex审查-cursor续作-20260729.md)。

> **文档族索引**：[`cursor续作.md`](./cursor续作.md)  
> **上一波（009D Research）**：[`cursor续作-P0-009D.md`](./cursor续作-P0-009D.md)  
> 本文件只服务 Codex 拣选 **P0-009E 收敛门**；勿与单 App 009B/C/D 施工包混并。

日期：2026-07-29（Asia/Shanghai）  
作者侧：Cursor 在 `k8s/cursor-1` + 三 App 迁移分支  
策略：收敛验证 + 对齐标记；**不切流、不 push、本波不开 P0-008C 实现**。

---

## 0. 一句话结论

完成 **P0-009E**：三 App clean-room / 漂移 / 六配对 / freeze 回滚 / KIND 卫生通过；  
标记 `INSTANCE_FOUNDATION_ALIGNED`。**P0-009 整体 ACCEPTED**。  
下一任务解锁 **P0-008C**（需用户明确开工）。远端 **未推**；业务流量 **未切**。

---

## 1. 与前几波差异

| 维度 | 009B–D | **009E** |
|------|--------|----------|
| 对象 | 单 App 原地同步 + KIND 配对 | **三 App 总收敛** |
| 产出 | 候选镜像 + pair.json | `convergence.json` + `drift-report.json` + 对齐标记 |
| 镜像构建 | 有 | **无**（复用 009B/C/D digest） |
| KIND 部署 | 隔离配对 | 仅检查 **无 p0-009 残留** |
| 下一锁 | 下一 App / 009E | **解锁 P0-008C** |

---

## 2. tip（本地未 push）

| 仓 | 分支 | 备注 |
|----|------|------|
| `info-app` | `p0-009b-info` | + `docs/INSTANCE_FOUNDATION_ALIGNED.json` |
| `knowledge-app` | `p0-009c-knowledge` | + 对齐标记 |
| `research-app` | `p0-009d-research` | + 对齐标记 |
| `k8s` | `cursor-1` | `V5-P0-009E` + 游标文档 |

---

## 3. 脚本 / 证据

```text
verify_p0_009e_convergence.py
evidence/v5/V5-P0-009E/
  result.md
  convergence.json
  drift-report.json
info|knowledge|research-app/docs/INSTANCE_FOUNDATION_ALIGNED.json
```

release：`p0-008b-b6-unified-20260729`  
freeze tag：`p0-009a-pre-20260729`

---

## 4. 坑（009E 特有）

1. clean-room 从 **freeze tag** clone，不是从迁移 tip；Web BE Nest 树无 FastAPI `config.py` 时，用模板 config 做**身份重放证明**即可。  
2. 内核漂移允许 identity/domain 扩展；`unexplained` 必须失败。  
3. Research 的 `knowledge_retrieval_*` 跨 App 名 **不得**被当成漂移错误。  
4. pair 证据禁止 secret 形输出；对齐标记 `traffic_cutover=false`。  
5. **不要**在本波开始 P0-008C 实现或业务切流。

---

## 5. Codex 最短行动

1. 拣选本波脚本/证据与三 App 对齐标记。  
2. 重跑 `verify_p0_009e_convergence.py`（可选）。  
3. 下一任务仅在授权后开 **P0-008C**；common 缺陷回流 `tpl-app` 再传播。  
4. 未经授权：**不 push**；**不切业务流量**。
