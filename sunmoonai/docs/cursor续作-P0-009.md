# Cursor 续作 Wave-2：P0-009A 冻结 + P0-009B Info 原地基础采纳

> **审计状态（2026-07-29）**：本文是 Cursor 的历史施工记录；其中旧候选 digest、回滚
> 语义和 ACCEPTED 描述已被 Codex 的干净源码重建、四组件真实回滚和严格总门禁取代。
> 当前证据见 [`evidence/v5/V5-P0-009B/result.md`](./evidence/v5/V5-P0-009B/result.md)
> 及 [`codex审查-cursor续作-20260729.md`](./codex审查-cursor续作-20260729.md)。

> **文档族索引**：[`cursor续作.md`](./cursor续作.md)  
> **上一波（B6）**：[`cursor续作-B6.md`](./cursor续作-B6.md) — 模板资格链，**不要**与本文件拣选清单混并  
> 策略确认（2026-07-29）：**继续原地同步底座**；不采用「整仓 tpl 实例化再搬领域」。

日期：2026-07-29（Asia/Shanghai）  
作者侧：Cursor 在 `k8s/cursor-1` + Info `p0-009b-info` 上续作  
读者：Codex（在 `codex-1` 拣选/重放；**不要** `merge -X theirs` 覆盖自有计划文案）  
Codex/Cursor 共享上游：B6 已 ACCEPTED（`template_release_id=p0-008b-b6-unified-20260729`）

---

## 0. 一句话结论

在 **不推 Gitee**、**不切 Info/Knowledge/Research 业务流量** 的约束下，Cursor 完成：

1. **P0-009A**：三 App 迁移冻结（清单 + 本地 tag `p0-009a-pre-20260729`）  
2. **P0-009B**：Info 四默认组件**原地**同步共同底座 + 候选镜像 + KIND **隔离** Admin/Web 配对 + 清理  
3. 计划游标推进到 **P0-009C Knowledge**（串行；勿并行 Research）

远端 Git：**仍未推**。Harbor：仅推 Info **candidate** tag，未覆盖业务稳定 tag。

---

## 1. 与 Wave-1（B6）的差异（Codex 必读）

| 维度 | Wave-1 B6 | Wave-2 P0-009 |
|------|-----------|----------------|
| 目标仓 | **`tpl-app` 模板** | **`info-app` 业务实例**（Knowledge/Research 未动） |
| 分支 | `k8s`/`tpl-*` → `cursor-1` | `k8s` → `cursor-1`；Info → **`p0-009b-info`**（自冻结 tag） |
| 产物 | pairing matrix、release manifest、B6 证据 | 009A freeze、009B Info 证据、实例脚本 |
| 集群 | 模板隔离拓扑（b63f / 复用 B4） | Info **隔离** `*-p0-009b`；业务 Deployment **未改** |
| 危险操作 | 勿污染 Nest/FastAPI 同名镜像 | 勿切业务 Ingress；勿整仓 tpl 覆盖 Info |
| 拣选重点 | `expires_at` Zod、Nest `build.conf`、B6 verify 修复 | Info 领域缝合、`AUTH_APP=info`、Celery domain dispatch、领域 config 合并 |
| 回滚资产 | 模板 candidate ↔ interim digest | Git tag `p0-009a-pre-20260729` + 同框架 interim；Nest/React **不能**直接滚进 Next/FastAPI 隔离清单 |

**合并建议**：先消化 Wave-1 的 `tpl-*` / B6 证据，再单独拣选本文件 Info / 009 脚本；两波提交混在一次 rebase 极易丢领域或丢模板修复。

---

## 2. Codex / 冻结基线（续作起点）

### 2.1 发布与冻结

| 项 | 值 |
|----|-----|
| `template_release_id` | `p0-008b-b6-unified-20260729` |
| 模板 commits | Admin FE `fb69795` / Admin BE `69e634b` / Web FE `1db9377` / Web BE `289f2c4` |
| 迁移前 tag（本地，未 push） | `p0-009a-pre-20260729`（15 仓：3 父 + 各 4 模块） |
| 009A 证据 | `k8s/sunmoonai/docs/evidence/v5/V5-P0-009A/` |
| 策略 | Info → Knowledge → Research **串行**；只迁四默认组件；React/Vue/Nest **不进实例** |

### 2.2 Info 工作分支（Cursor）

| 仓 | 分支 tip（约） | 说明 |
|----|----------------|------|
| `info-app` | `p0-009b-info` @ `ec8c7e9` | 父仓 submodule 指针 |
| `info-admin-frontend` | `5f14ff2` | Next Admin + 简化 crawl |
| `info-admin-backend` | `57af2d8` | FastAPI 内核刷新 + 领域保留 |
| `info-web-frontend` | `992f3cc` | Next Web 底座 |
| `info-web-backend` | `b3b8635` | Nest→FastAPI；Nest 在 `docs/p0-009b-domain-keep/` |
| `k8s` | `cursor-1` @ `5bda1a8` | 009B 证据 + 脚本 |

---

## 3. Cursor 完成了什么

### 3.1 P0-009A

- 脚本：`verify_p0_009a_freeze.py`  
- 证据：`freeze.json` / `result.md`  
- keep/replace/delete 冻结；Nest Web 仅 Info 计划替换为 FastAPI；业务代码/流量未改

### 3.2 P0-009B 里程碑

| 门禁 | 结果 | 证据 |
|------|------|------|
| 四模块源码门禁 | passed | Admin/Web FE：typecheck/lint/unit/i18n/build；BE：ruff/pytest（Admin 另 pyright） |
| Admin 隔离配对 | passed | `…/V5-P0-009B/admin-pair.json` |
| Web 隔离配对 | passed | `…/V5-P0-009B/web-pair.json` |
| 回滚演练 + cleanup | passed | `rollback.json` + `cleanup.log` |
| 业务 Deployment 未变 | passed | `business-deployments-unchanged.json` |

`result.md`：`P0-009B` 本地 ACCEPTED；下一任务 **P0-009C**。

### 3.3 Harbor 候选（Kind）

tag：`p0-009b-info-candidate-20260729`

| 镜像 | digest |
|------|--------|
| `info-admin-frontend` | `sha256:181c1ef518c9284872d291f44dc740dd3dd5b3b181a8f3c1d8a9ed40eab2fdfd` |
| `info-admin-backend` | `sha256:3e3ec67945c99924e9cae69bd069989de863b45bb0302a2e28988a8538a3ebb8` |
| `info-web-frontend` | `sha256:6c6858ad9d2c3e3744ed8feaf4906994caf2f147402b57fbd209de03f34f1fde` |
| `info-web-backend` | `sha256:43aadeb3a8811a4b84813c2f5be2f9245b30070a428b4796bf633b5a4bed77f0` |

### 3.4 Info 栈前后（意图）

| Surface | 迁移前 | 迁移后（候选） |
|---------|--------|----------------|
| admin-frontend | React Router + Ant Design crawl | Next Admin + 简化 crawl 页 |
| admin-backend | FastAPI + Info 领域 | FastAPI **内核刷新** + 领域保留 |
| web-frontend | 旧 Next | B6 Next Web 底座 |
| web-backend | Nest | FastAPI Web BFF |

完整 Ant Design crawl / Nest 树归档在各模块 `docs/p0-009b-domain-keep/`（业务等价后续 M1，不在 009B）。

---

## 4. Codex 拣选清单（Wave-2）

### 4.1 `k8s`（相对 `cursor-1`，关键提交）

```text
5bda1a8 test: accept P0-009B Info foundation isolation pairing
500be63 test: accept P0-009A migration freeze for three apps
```

（B6 相关仍见 Wave-1；`5a589d2` 为旧单文件 handoff，现已拆成文档族。）

必带路径：

```text
sunmoonai/docs/evidence/v5/V5-P0-009A/
sunmoonai/docs/evidence/v5/V5-P0-009B/
sunmoonai/docs/mooc-manus-v5/scripts/apply_p0_009b_info_foundation.sh
sunmoonai/docs/mooc-manus-v5/scripts/deploy_p0_009b_info_admin_pair_kind.sh
sunmoonai/docs/mooc-manus-v5/scripts/deploy_p0_009b_info_web_pair_kind.sh
sunmoonai/docs/mooc-manus-v5/scripts/provision_p0_009b_info_admin_identity.sh
sunmoonai/docs/mooc-manus-v5/scripts/provision_p0_009b_info_web_identity.sh
sunmoonai/docs/mooc-manus-v5/scripts/verify_p0_009b_info_admin_browser.mjs
sunmoonai/docs/mooc-manus-v5/scripts/verify_p0_009b_info_web_pair.mjs
sunmoonai/docs/mooc-manus-v5/scripts/verify_p0_009a_freeze.py   # 若尚未在 codex-1
sunmoonai/docs/cursor续作.md
sunmoonai/docs/cursor续作-B6.md
sunmoonai/docs/cursor续作-P0-009.md
# 计划游标（已改为 P0-009C_NEXT）
sunmoonai/docs/mooc-manus-langgraph-v5-implementation-plan.md
sunmoonai/docs/mooc-manus-langgraph-v5-handoff-20260712.md
sunmoonai/docs/mooc-manus-langgraph-longterm-plan-v5.md
sunmoonai/docs/mooc-manus-v5/scripts/verify_template_first_plan.py
```

### 4.2 Info 子仓（`p0-009b-info`，勿直接并进业务 `master` 流量）

按需 cherry-pick / 在 Codex 侧重放同等 diff；父仓只更新 gitlink。

### 4.3 应用脚本注意（`apply_p0_009b_info_foundation.sh`）

跑完 overlay **之后**还要手工/脚本补的缝合（Cursor 已做，重放勿丢）：

1. Admin BE：**合并领域 config**（crawl/S3/ES/Knowledge/outbox）；不要只覆盖 tpl `config.py`  
2. Admin BE：内核同步 `celery_producer.py` 后 **补回** `dispatch_crawl_url` / `dispatch_index_document_version` / `dispatch_distribution`  
3. Admin BE：同步 `main.py`、`principal.py`、`exception_handlers.py`；挂载受保护 `/internal/tasks`  
4. 四端测试里 cookie / `app` / `info:admin` scope 与默认 slug 对齐  
5. FE `build.conf` 需提供脚本仍读取的 `TPL_SSR_IMAGE`/`TPL_SSR_TAG` 别名  
6. 隔离 Deploy：**`AUTH_APP=info`**（误留 `tpl` 会导致登录后 SSR session 校验失败、看不到 dashboard）

---

## 5. 踩过的坑（009 特有；B6 坑见 Wave-1 §4）

### 5.1 `AUTH_APP` 与后端 `app` 不一致

前端 `loadBrowserSession` 要求 `user.app === AUTH_APP`。  
隔离脚本从 007E sed 出来时曾留下 `AUTH_APP=tpl`，后端已是 `info` → 登录回调 302 成功但 dashboard 空白/回登录。  
**部署与 verify 都必须 `AUTH_APP=info`。**

### 5.2 内核同步冲掉领域能力

只 rsync/cp 模板 `celery_producer` / `config` → pyright/运行期缺 Info dispatch 与 storage/search 配置。  
规则：**内核文件可覆盖，领域方法与领域 Settings 字段必须再合并。**

### 5.3 Admin Principal / 测试身份

Info `Principal.app` 曾是 `Literal["info"]`；模板测试写 `tpl`。  
宜采用模板的 slug pattern，或全面改测试为 `info`；cookie 名 `sunmoonai_info_{admin|web}_sid`。

### 5.4 隔离资源命名碰撞

Admin/Web 若都 sed 成 `p0-009b-postgresql` / 同一 `RUNTIME_SECRET` 会互踩。  
应用：`p0-009b-admin-*` vs `p0-009b-web-*`，runtime secret 分离。

### 5.5 Postgres 用户 vs `AUTH_APP`

勿把 `POSTGRESQL_USERNAME=tpl` 和 `AUTH_APP` 一起被 `sed 's/tpl/info/'` 误伤；DB 账号可仍为隔离库的 `tpl`，**应用身份**必须是 `info`。

### 5.6 栈换代回滚

- 旧 React Admin / Nest Web digest **不能**当作 Next/FastAPI 隔离 Deployment 的直接 rollback 目标  
- 用同框架 interim（如 `tpl-admin-*` / `tpl-web-backend` digest）做滚动演练  
- Git tag `p0-009a-pre-20260729` 才是整栈回退资产  
- **业务流量本任务未切**，cleanup 隔离资源即可

### 5.7 Web FE 本地 `pnpm build`

需 `NEXT_PUBLIC_API_URL=/api`（镜像 Dockerfile 已 ARG 默认）；裸跑会 Zod 失败。

### 5.8 运维环境（与 B6 相同，仍强制）

```bash
export KUBECONFIG="$HOME/.kube/kind-config"
export KUBECTL_BIN="$HOME/.local/bin/kubectl-kind-v1.27.3"
export CLUSTER=KIND
export PLAYWRIGHT_BROWSERS_PATH="$HOME/.cache/ms-playwright"
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy ALL_PROXY all_proxy DEBUG
```

镜像引用一律：

`harbor.sunmoonai.com:30443/app-images/<name>@sha256:<64hex>`

---

## 6. 建议 Codex 如何测试（009B 重放）

### 6.1 不碰集群

```bash
# Admin FE
cd /home/zymun/info-app/info-admin-frontend/app && pnpm typecheck && pnpm lint && pnpm test && pnpm check:i18n && pnpm build

# Web FE
cd /home/zymun/info-app/info-web-frontend/app && pnpm typecheck && pnpm lint && pnpm test && pnpm check:i18n
NEXT_PUBLIC_API_URL=/api pnpm build

# Admin BE
cd /home/zymun/info-app/info-admin-backend/app && uv sync --group dev && uv run ruff check . && uv run pyright && uv run pytest -q

# Web BE
cd /home/zymun/info-app/info-web-backend/app && uv sync --group dev && uv run ruff check . && uv run pytest -q
```

### 6.2 隔离配对（测完必须 cleanup）

```bash
ADMIN_BE='harbor.sunmoonai.com:30443/app-images/info-admin-backend@sha256:3e3ec67945c99924e9cae69bd069989de863b45bb0302a2e28988a8538a3ebb8'
ADMIN_FE='harbor.sunmoonai.com:30443/app-images/info-admin-frontend@sha256:181c1ef518c9284872d291f44dc740dd3dd5b3b181a8f3c1d8a9ed40eab2fdfd'
WEB_BE='harbor.sunmoonai.com:30443/app-images/info-web-backend@sha256:43aadeb3a8811a4b84813c2f5be2f9245b30070a428b4796bf633b5a4bed77f0'
WEB_FE='harbor.sunmoonai.com:30443/app-images/info-web-frontend@sha256:6c6858ad9d2c3e3744ed8feaf4906994caf2f147402b57fbd209de03f34f1fde'

bash …/provision_p0_009b_info_admin_identity.sh --apply
bash …/deploy_p0_009b_info_admin_pair_kind.sh --apply --backend-image "$ADMIN_BE" --frontend-image "$ADMIN_FE"
# 确认前端 AUTH_APP=info
node …/verify_p0_009b_info_admin_browser.mjs

bash …/provision_p0_009b_info_web_identity.sh --apply
bash …/deploy_p0_009b_info_web_pair_kind.sh --apply --backend-image "$WEB_BE" --frontend-image "$WEB_FE"
node …/verify_p0_009b_info_web_pair.mjs

# cleanup（含 identity）；勿删业务 info-* Deployment
bash …/deploy_p0_009b_info_admin_pair_kind.sh --cleanup   # 若脚本资源名已改为 admin- 前缀，按实际集群名清理
bash …/deploy_p0_009b_info_web_pair_kind.sh --cleanup
bash …/provision_p0_009b_info_admin_identity.sh --cleanup
bash …/provision_p0_009b_info_web_identity.sh --cleanup
```

注意：Cursor 首次 Admin apply 时 postgres/redis 名可能仍是 `p0-009b-postgresql`（未加 admin- 前缀）；cleanup 以集群实存名为准。

### 6.3 业务未碰校验

对比 `pre-isolation-business-deployments.json` 与 cleanup 后快照；或：

```bash
"$KUBECTL_BIN" -n app-platform-dev get deploy \
  info-admin-backend info-admin-frontend info-web-backend info-web-frontend \
  -o custom-columns=NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image,GEN:.metadata.generation
```

应仍为冻结时的稳定 tag（如 Admin FE `1.0.1`、Web BE Nest `1.0.0` 等），**不是** `p0-009b-info-candidate-*`。

---

## 7. 当前状态速查

| 项 | 值 |
|----|-----|
| 策略 | **原地同步底座**（不整仓 tpl 实例化） |
| P0-009A | 本地 ACCEPTED |
| P0-009B | 本地 ACCEPTED；隔离资源应已清理 |
| 下一任务 | **P0-009D Research**（同法串行；勿开 008C） |
| 远端推送 | **无** |
| 业务流量 | **未切** |

---

## 8. 给 Codex 的最短行动清单

1. 先确认 Wave-1 B6 / release manifest 已在 `codex-1` 落地。  
2. 拣选本文件 §4 路径与 Info `p0-009b-info` tip（或等价重放）。  
3. 跑 §6.1；对 KIND 存疑再跑 §6.2 并 **cleanup**。  
4. **不要**开始 Knowledge/Research，直到用户确认开 P0-009C。  
5. 用户授权前：**不 push** Gitee；不覆盖业务稳定镜像 tag。

---

## 9. 参考路径

- 索引：`k8s/sunmoonai/docs/cursor续作.md`  
- 本波：`k8s/sunmoonai/docs/cursor续作-P0-009.md`  
- B6 波：`k8s/sunmoonai/docs/cursor续作-B6.md`  
- 009A：`k8s/sunmoonai/docs/evidence/v5/V5-P0-009A/`  
- 009B：`k8s/sunmoonai/docs/evidence/v5/V5-P0-009B/result.md`  
- Release：`tpl-app/template-release-manifest.json`  
- Overlay：`…/scripts/apply_p0_009b_info_foundation.sh`
