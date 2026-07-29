# Cursor 续作 Wave-4：P0-009D Research 原地基础采纳

> **审计状态（2026-07-29）**：本文是 Cursor 的历史施工记录；其中旧候选 digest、
> `domain-keep` 和初版内核漂移结论不再有效。当前事实见
> [`evidence/v5/V5-P0-009D/result.md`](./evidence/v5/V5-P0-009D/result.md)
> 及 [`codex审查-cursor续作-20260729.md`](./codex审查-cursor续作-20260729.md)。

> **文档族索引**：[`cursor续作.md`](./cursor续作.md)  
> **上一波（009C Knowledge）**：[`cursor续作-P0-009C.md`](./cursor续作-P0-009C.md)  
> 本文件只服务 Codex 拣选 **P0-009D Research**；勿与 Info/Knowledge/B6 混并。

日期：2026-07-29（Asia/Shanghai）  
作者侧：Cursor 在 `k8s/cursor-1` + Research `p0-009d-research`  
策略：继续**原地同步底座**；**禁止**提前做 P0-008C。

---

## 0. 一句话结论

完成 **P0-009D**：Research 四默认组件原地同步 + 候选镜像 + KIND 隔离 Admin/Web 配对 + cleanup。  
本波结论已收口；**下一任务见** [`cursor续作-P0-009E.md`](./cursor续作-P0-009E.md)（009E ACCEPTED 后解锁 008C）。远端 **未推**；业务流量 **未切**。

---

## 1. 与前几波差异

| 维度 | 009B Info | 009C Knowledge | **009D Research** |
|------|-----------|----------------|-------------------|
| Admin FE 起点 | React | Vue（无域页） | Vue（无 Runtime 页）→ 新建最小壳 |
| Admin BE 领域 | crawl/index | ingestion/retrieval resource server | **agent/runtime client** + LangGraph |
| Celery | crawl/index/distribution | `dispatch_knowledge_ingestion` | **`dispatch_agent_graph`** |
| Web FE 域 UI | 无 | 无 | **回迁 `AgentConsole`** |
| 身份 | `info` | `knowledge` | **`research`** |
| 跨 App | 调 Knowledge ingest | 双 internal 边界 | **`sunmoonai-research-knowledge-retrieve`（勿改）** |

---

## 2. tip（本地未 push）

| 仓 | 分支 | tip（约） |
|----|------|-----------|
| `research-app` | `p0-009d-research` | `222a2dd` |
| `research-admin-frontend` | `p0-009d-research` | `6fba4bd` |
| `research-admin-backend` | `p0-009d-research` | `01c969c` |
| `research-web-frontend` | `p0-009d-research` | `2ad34ba` |
| `research-web-backend` | `p0-009d-research` | `b64d23c` |
| `k8s` | `cursor-1` | 含 `V5-P0-009D` |

---

## 3. 脚本 / 证据

```text
apply_p0_009d_research_foundation.sh
stitch_p0_009d_research_foundation.py
deploy_p0_009d_research_{admin,web}_pair_kind.sh
provision_p0_009d_research_{admin,web}_identity.sh
verify_p0_009d_research_{admin_browser,web_pair}.mjs
evidence/v5/V5-P0-009D/
```

候选 tag：`p0-009d-research-candidate-20260729`（digest 见 `result.md`）。

---

## 4. 坑（009D 特有）

1. Vue **无** Runtime/evaluation 页 → 新建 `/research/runtime`。  
2. `knowledge_retrieval_*` relation **不要** sed 成 research-*。  
3. Web FE 整页覆盖会冲掉 pairing 所需的「控制台」标题 → dashboard 必须保留模板壳 + `AgentConsole`。  
4. `kubectl set image` 必须带 **全仓库前缀** `harbor.sunmoonai.com:30443/app-images/...`。  
5. 隔离 **`AUTH_APP=research`**；verify `user.app === 'research'`。  
6. **不要**在 009D 做真实 Research 产品试点（属 P0-008C，前置 P0-009E）。

---

## 5. Codex 最短行动

1. 拣选本波脚本/证据/Research tip。  
2. 源码门禁 +（可选）KIND cleanup 重放。  
3. 下一任务只开 **P0-009E**，勿跳 P0-008C。  
4. 未经授权：**不 push**。
