# Cursor 续作 Wave-3：P0-009C Knowledge 原地基础采纳

> **审计状态（2026-07-29）**：本文是 Cursor 的历史施工记录；`domain-keep` 归档方案已
> 因包含环境文件、生成物和二进制而撤销，旧候选 digest 与回滚说明也已失效。当前事实见
> [`evidence/v5/V5-P0-009C/result.md`](./evidence/v5/V5-P0-009C/result.md)
> 及 [`codex审查-cursor续作-20260729.md`](./codex审查-cursor续作-20260729.md)。

> **文档族索引**：[`cursor续作.md`](./cursor续作.md)  
> **上一波（009A/B Info）**：[`cursor续作-P0-009.md`](./cursor续作-P0-009.md)  
> **更早（B6）**：[`cursor续作-B6.md`](./cursor续作-B6.md)  
> 本文件只服务 Codex 拣选 **P0-009C Knowledge** 增量；勿与 Info / B6 拣选集混并。

日期：2026-07-29（Asia/Shanghai）  
作者侧：Cursor 在 `k8s/cursor-1` + Knowledge `p0-009c-knowledge`  
读者：Codex（`codex-1` 拣选/重放；**不要** `merge -X theirs`）  
策略：继续**原地同步底座**（用户确认不采用整仓 tpl 实例化）

---

## 0. 一句话结论

在 **不推 Gitee**、**不切业务流量** 约束下，Cursor 完成 **P0-009C**：Knowledge 四默认组件原地同步共同底座 + 候选镜像 + KIND 隔离 Admin/Web 配对 + cleanup。  
计划游标推进到 **P0-009D Research**。

---

## 1. 与 Wave-1 / Wave-2 的差异（Codex 必读）

| 维度 | Wave-1 B6 | Wave-2 P0-009A/B | Wave-3 P0-009C |
|------|-----------|------------------|----------------|
| 对象 | `tpl-app` 模板 | `info-app` | **`knowledge-app`** |
| 分支 | `cursor-1` | Info `p0-009b-info` | Knowledge **`p0-009c-knowledge`** |
| Admin FE 起点 | Next | React Router | **Vue legacy**（无 Dataset 页可迁） |
| Admin BE 领域 | 无 | crawl/index/distribution | **ingestion/retrieval + RAGFlow + 双 internal 边界** |
| Web BE | Nest+FastAPI 双轨 | Nest→FastAPI | Nest→FastAPI |
| 身份 | `tpl` | `info` | **`knowledge`** |
| 证据 | `V5-P0-008B/B6` | `V5-P0-009A`/`009B` | **`V5-P0-009C`** |

**拣选顺序**：Wave-1 → Wave-2 → **本文件** → 再开 009D。

---

## 2. 工作 tip（Cursor 本地，未 push）

| 仓 | 分支 | tip（约） |
|----|------|-----------|
| `knowledge-app` | `p0-009c-knowledge` | `3fc9df6` |
| `knowledge-admin-frontend` | `p0-009c-knowledge` | `f5e2577` |
| `knowledge-admin-backend` | `p0-009c-knowledge` | `7e9bded` |
| `knowledge-web-frontend` | `p0-009c-knowledge` | `023ebdd` |
| `knowledge-web-backend` | `p0-009c-knowledge` | `36250a5` |
| `k8s` | `cursor-1` | `4339329` |

冻结起点 tag：`p0-009a-pre-20260729`。

---

## 3. 完成了什么

### 3.1 Overlay / 缝合脚本

```text
sunmoonai/docs/mooc-manus-v5/scripts/apply_p0_009c_knowledge_foundation.sh
sunmoonai/docs/mooc-manus-v5/scripts/stitch_p0_009c_knowledge_foundation.py
sunmoonai/docs/mooc-manus-v5/scripts/deploy_p0_009c_knowledge_{admin,web}_pair_kind.sh
sunmoonai/docs/mooc-manus-v5/scripts/provision_p0_009c_knowledge_{admin,web}_identity.sh
sunmoonai/docs/mooc-manus-v5/scripts/verify_p0_009c_knowledge_{admin_browser,web_pair}.mjs
```

领域归档：各模块 `docs/p0-009c-domain-keep/`。

### 3.2 候选镜像

tag：`p0-009c-knowledge-candidate-20260729`

| 镜像 | digest |
|------|--------|
| knowledge-admin-frontend | `sha256:974895ce3d89af222327f566106b77b340de19b5999c5c2a675103285000e2b8` |
| knowledge-admin-backend | `sha256:b25402aab5962eee954db8570060a4c04f270130f63a9b7b9971aacb5436b489` |
| knowledge-web-frontend | `sha256:41322c475f2163458691942f2598b3ccdf4cbabeed14335582251d2f3f7076f5` |
| knowledge-web-backend | `sha256:1ec4c91fd59cab5ae3e63492dddcc57574a1719522b281e840496fbbff3d06e8` |

### 3.3 门禁

见 `evidence/v5/V5-P0-009C/result.md`：源码门禁 + Admin/Web 隔离配对 **passed**；业务 Deployment **unchanged**；cleanup **passed**。

---

## 4. Codex 拣选清单（Wave-3）

### 4.1 `k8s`

```text
sunmoonai/docs/evidence/v5/V5-P0-009C/
sunmoonai/docs/mooc-manus-v5/scripts/apply_p0_009c_knowledge_foundation.sh
sunmoonai/docs/mooc-manus-v5/scripts/stitch_p0_009c_knowledge_foundation.py
sunmoonai/docs/mooc-manus-v5/scripts/deploy_p0_009c_knowledge_*.sh
sunmoonai/docs/mooc-manus-v5/scripts/provision_p0_009c_knowledge_*.sh
sunmoonai/docs/mooc-manus-v5/scripts/verify_p0_009c_knowledge_*.mjs
sunmoonai/docs/cursor续作.md
sunmoonai/docs/cursor续作-P0-009C.md
# 计划游标 → P0-009D_NEXT
sunmoonai/docs/mooc-manus-langgraph-v5-implementation-plan.md
sunmoonai/docs/mooc-manus-langgraph-v5-handoff-20260712.md
sunmoonai/docs/mooc-manus-langgraph-longterm-plan-v5.md
```

### 4.2 Knowledge 子仓

按 `p0-009c-knowledge` tip 拣选或等价重放 apply+stitch；**勿**直接并进业务 `master` 流量。

---

## 5. 踩过的坑（009C 特有；通用坑见 Wave-2 §5）

1. **Vue 无 Dataset/Ingestion/Retrieval 页**：freeze 文案是目标态；实际只能归档整棵 Vue，并**新建** Next 最小域壳。  
2. **双 service boundary 字段名含 info/research**：`sunmoonai-info-knowledge-ingest` / `sunmoonai-research-knowledge-retrieve` **不要** sed 成 knowledge。  
3. **内核 sync 冲掉**：`dispatch_knowledge_ingestion`、`get_key_set` 公有包装、`audit_context`、领域 Settings。  
4. **`tasks_routes` 仍引用 `require_tpl_admin`**：必须改 `require_knowledge_admin`。  
5. **Celery `_delivery_options`**：领域测试依赖；仅 `queue=` 不够。  
6. **verify 脚本从 009B 克隆后仍断言 `user.app === 'info'`**：必须改为 `knowledge`。  
7. **隔离 `AUTH_APP` YAML value 残留 `info`**：部署前强制核对 `AUTH_APP=knowledge`。  
8. **Web BE 测试身份**：`app="tpl"` 漏改会导致 reference interaction `403 resource_forbidden`。  
9. **KIND 缺口**：freeze 显示 Knowledge FE/Web 原本无业务 Deployment；隔离对从零创建。

---

## 6. 建议 Codex 如何测试

### 6.1 不碰集群

```bash
cd /home/zymun/knowledge-app/knowledge-admin-frontend/app && pnpm typecheck && pnpm lint && pnpm test && pnpm check:i18n && pnpm build
cd /home/zymun/knowledge-app/knowledge-web-frontend/app && pnpm typecheck && pnpm lint && pnpm test && pnpm check:i18n
NEXT_PUBLIC_API_URL=/api pnpm build
cd /home/zymun/knowledge-app/knowledge-admin-backend/app && uv sync --group dev && uv run ruff check . && uv run pyright && uv run pytest -q
cd /home/zymun/knowledge-app/knowledge-web-backend/app && uv sync --group dev && uv run ruff check . && uv run pytest -q
```

### 6.2 隔离配对（测完 cleanup）

```bash
export KUBECONFIG=$HOME/.kube/kind-config
export KUBECTL_BIN=$HOME/.local/bin/kubectl-kind-v1.27.3
export CLUSTER=KIND
export PLAYWRIGHT_BROWSERS_PATH=$HOME/.cache/ms-playwright
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy ALL_PROXY all_proxy DEBUG

ADMIN_BE='harbor.sunmoonai.com:30443/app-images/knowledge-admin-backend@sha256:b25402aab5962eee954db8570060a4c04f270130f63a9b7b9971aacb5436b489'
ADMIN_FE='harbor.sunmoonai.com:30443/app-images/knowledge-admin-frontend@sha256:974895ce3d89af222327f566106b77b340de19b5999c5c2a675103285000e2b8'
WEB_BE='harbor.sunmoonai.com:30443/app-images/knowledge-web-backend@sha256:1ec4c91fd59cab5ae3e63492dddcc57574a1719522b281e840496fbbff3d06e8'
WEB_FE='harbor.sunmoonai.com:30443/app-images/knowledge-web-frontend@sha256:41322c475f2163458691942f2598b3ccdf4cbabeed14335582251d2f3f7076f5'

bash …/provision_p0_009c_knowledge_admin_identity.sh --apply
bash …/deploy_p0_009c_knowledge_admin_pair_kind.sh --apply --backend-image "$ADMIN_BE" --frontend-image "$ADMIN_FE"
# 确认 AUTH_APP=knowledge
node …/verify_p0_009c_knowledge_admin_browser.mjs

bash …/provision_p0_009c_knowledge_web_identity.sh --apply
bash …/deploy_p0_009c_knowledge_web_pair_kind.sh --apply --backend-image "$WEB_BE" --frontend-image "$WEB_FE"
node …/verify_p0_009c_knowledge_web_pair.mjs

# cleanup（含 identity）；勿删业务 knowledge-*（若存在）
```

---

## 7. 当前状态速查

| 项 | 值 |
|----|-----|
| P0-009C | 本地 ACCEPTED |
| 下一任务 | **P0-009D Research** |
| 远端推送 | **无** |
| 业务流量 | **未切** |
| 隔离资源 | **已 cleanup** |

---

## 8. 给 Codex 的最短行动清单

1. 确认 Wave-1/2 已在 `codex-1` 落地。  
2. 拣选本文件 §4。  
3. 跑 §6.1；KIND 存疑再跑 §6.2 并 cleanup。  
4. **不要**开始 Research/008C，直到用户确认开 P0-009D。  
5. 用户授权前：**不 push**。
