# Cursor 续作 Wave-1：P0-008B / B6.3~B6.4

> **审计状态（2026-07-29）**：本文是 Cursor 的历史施工记录，不是当前验收真相源。
> Codex 已重新执行 B6 consumer vectors 与七模块 clean-room；审计结论和后续使用边界见
> [`codex审查-cursor续作-20260729.md`](./codex审查-cursor续作-20260729.md)。

> **文档族索引**：[`cursor续作.md`](./cursor续作.md)  
> **下一波（P0-009）**：[`cursor续作-P0-009.md`](./cursor续作-P0-009.md) — **当前游标以 Wave-2 为准**  
> 本文件只服务 Codex 拣选 **B6** 增量；勿与 P0-009 实例迁移混读。

日期：2026-07-29（Asia/Shanghai）  
作者侧：Cursor 在本地分支 `cursor-1` 上续作  
读者：Codex（建议在 `codex-1` 上拣选/重放，**不要**盲目 `merge -X theirs`）  
Codex 基线：`k8s/codex-1` @ `f5977a0`（B6.1/B6.2 + B6.3 脚本骨架）

---

## 0. 一句话结论

Codex 已把 **B6.1 / B6.2** 做完，并写好 **B6.3 门禁脚本与契约**，卡在「本机构建/推送候选镜像 + KIND 真实配对」。

Cursor 在 **不推 Gitee**、**不碰 Info/Knowledge/Research 业务 Deployment** 的约束下，完成了：

1. **B6.3F**：Next Web + FastAPI Web 隔离配对 + 独立回滚  
2. **B6.3N**：Next Web + Nest Web 重验 + 独立回滚（复用既有 B4 拓扑，验后恢复）  
3. **B6.4**：七子模块 clean-room + 统一四默认/三非默认 release  
4. 将证据与矩阵标为 **P0-008B / B6 本地 ACCEPTED**  
5. （历史）当时下一游标写到 **P0-009A**；**P0-009A/B 已由 Wave-2 完成**，见 [`cursor续作-P0-009.md`](./cursor续作-P0-009.md)

远端 Git：**全程未推**（`master` / `codex-1` / `cursor-1` 皆未 push）。  
Harbor：推了 **candidate tag**（未覆盖 `1.0.0` / `b4-*` / `p0-007e-*` 等正式验收 tag）。

---

## 1. Codex 留给 Cursor 的基线（续作起点）

### 1.1 仓库 / 分支事实

| 仓库 | Codex 侧 | Cursor 续作分支 | 说明 |
|------|----------|-----------------|------|
| `k8s` | `codex-1` @ `f5977a0`（脚本/证据骨架） | `cursor-1` 从该点拉出 | 证据与脚本增量都在这里 |
| `tpl-app` | 当时多在本地 `master` tip（含 B6.3 契约） | `cursor-1` | 矩阵 + release manifest |
| `tpl-web-frontend` 等 Web 子仓 | 已有 consumer vectors 等 | `cursor-1` | 关键产品修复见下文 |

Codex 已具备、Cursor **直接复用**的关键资产：

- `frontend-pairing-matrix.json` / `frontend-capability-matrix.json`
- `contracts/web-interaction-v1.consumer-vectors.json`
- `verify_b6_web_consumer_vectors.py`
- `deploy_b6_web_fastapi_pair_kind.sh` / `provision_b6_web_fastapi_identity.sh`
- `verify_b6_web_fastapi_pair.mjs`
- `verify_b6_web_pair_rollbacks.sh`（FastAPI + Nest 两 profile）
- B4：`deploy_p0_008b_b4_kind.sh` / `verify_p0_008b_b4.mjs` / identity provision
- B6.1/B6.2 证据：`common-kernel.json`、`vue-pair.json`、`vue-rollback.json`

### 1.2 Codex 卡住点（Cursor 接手处）

- 沙箱无 Docker socket → 无法构建/推 Harbor  
- B6.3 需要真实 KIND + Casdoor + 严格 TLS  
- 矩阵里 Web 两条仍是 `IN_PROGRESS` / `REVALIDATION_REQUIRED`

---

## 2. Cursor 完成了哪些工作

### 2.1 里程碑

| 门禁 | 结果 | 证据（均在 `k8s`） |
|------|------|-------------------|
| 共享 consumer vectors | passed | `…/B6/consumer-vectors.json` |
| B6.3F 配对 | passed | `…/B6/b63f-pair.json` |
| B6.3F 回滚 | passed | `…/B6/b63f-rollback.json` |
| B6.3N 配对 | passed | `…/B6/b63n-pair.json` |
| B6.3N 回滚 | passed | `…/B6/b63n-rollback.json` |
| B6.4 clean-room + release | passed | `…/B6/unified-clean-room.json` + `tpl-app/template-release-manifest.json` |

`result.md` 状态现为：

`B6.1_ACCEPTED / B6.2_ACCEPTED / B6.3_ACCEPTED / B6.4_ACCEPTED / P0-008B_ACCEPTED`

### 2.2 Harbor 候选镜像（digest 以证据为准）

| 镜像 | tag | digest |
|------|-----|--------|
| `tpl-web-backend` | `p0-008b-b63-candidate-20260729` | `sha256:41dc3a781033dda3e60cd3594ffac7caf767e3c8cb2295ac0b8a21986fbd2414` |
| `tpl-web-backend-nest` | 同上 | `sha256:8d17b350df03968c4a847a4f089a2145e3ba326cdbb16db1f2996146cb359536` |
| `tpl-web-frontend` | `…-r2` / `…-r3` | r2=`sha256:d695dc24…`；**最终 release 取 r3** `sha256:2a359c8d213813ecbc3b5dbf6a6ed828e73a4c26b6dffaa1d163a507756db2b3` |

构建约定：`CLUSTER=KIND`，`PUSH_IMAGES_AFTER_BUILD=true`。

### 2.3 集群侧操作与清理

- B6.3F：隔离名 `p0-008b-b63f`；测完执行 deploy + identity **cleanup**；业务 Deployment 快照未变。  
- B6.3N：**未新建**独立 Nest 拓扑；滚动既有 `tpl-web-*-b4` → 候选 → 回滚门禁 → **恢复验收前 digest**（Nest B4 + Next B4 v1），避免长期占用 Codex 的 B4 现场。  
- B6.4：只做本地 clean clone / 源码门禁 / digest 校验，**不再**改 KIND 业务资源。

### 2.4 本地提交（未 push）

**`k8s` `cursor-1`（相对 `f5977a0`）：**

```text
d10901a test: accept B6.4 unified clean-room and close P0-008B
0a4cdca test: accept B6.3 dual Web profile pairing and rollbacks
4651514 test: accept B6.3F Next Web FastAPI isolated pair gate
3859c3a fix: enable REFERENCE_UI_ENABLED for B6.3F isolated Next Web pair
```

**`tpl-app` `cursor-1`：**

```text
359c3e5 release: freeze B6.4 unified template release manifest
6ce3b89 test: accept B6.3 Next Web FastAPI and Nest pairing matrix
```

**子模块：**

```text
tpl-web-frontend@1db9377  fix: accept FastAPI RFC3339 expires_at offsets…
tpl-web-backend-nest@ecb01d9  fix: name Nest image tpl-web-backend-nest in build.conf
```

---

## 3. 改了哪些文件（Codex 拣选清单）

### 3.1 必须拣选的产品修复（否则 FastAPI 配对会挂）

#### `tpl-web-frontend`（commit `1db9377`）

| 文件 | 改动 |
|------|------|
| `app/contracts/auth.ts` | `expires_at: z.iso.datetime({ offset: true })` — FastAPI 返回 `+00:00`，原 Zod 只认 `Z`，登录后 dashboard SSR 崩 |
| `app/tests/unit/browser-session.test.ts` | 增补 `+00:00` / `Z` 用例 |

这与 Admin 007E 同类问题一致；**Web 端此前未修**。

#### `tpl-web-backend-nest`（commit `ecb01d9`）

| 文件 | 改动 |
|------|------|
| `mybuild/build.conf` | `WEB_BACKEND_IMAGE="tpl-web-backend-nest"`（原误写 `tpl-web-backend`，会覆盖 FastAPI 同名本地/Harbor tag） |

### 3.2 `k8s` 脚本修复 / 新增

| 文件 | 改动要点 |
|------|----------|
| `…/scripts/deploy_b6_web_fastapi_pair_kind.sh` | 前端 Deployment 增加 `REFERENCE_UI_ENABLED=true`（隔离 B6.3F 需要 reference workspace UI） |
| `…/scripts/verify_b6_web_fastapi_pair.mjs` | port-forward 调 `/api/auth/me` 时带 `Host: tpl-web-backend-p0-008b-b63f`（否则 TrustedHost 对 `127.0.0.1` 返回 400） |
| `…/scripts/verify_b6_web_pair_rollbacks.sh` | `kubectl rollout status` 改打 stderr；probe count 去空白 — 否则最终 `jq --argjson` 失败（五阶段其实都过了） |
| `…/scripts/verify_b6_unified_clean_room.py` | **新增** B6.4 七模块 clean-room + 写 release manifest / 证据 |

### 3.3 证据与矩阵

| 路径 | 说明 |
|------|------|
| `k8s/…/B6/b63f-pair.json` / `b63f-rollback.json` | FastAPI 配对与回滚 |
| `k8s/…/B6/b63n-pair.json` / `b63n-rollback.json` | Nest 配对与回滚 |
| `k8s/…/B6/consumer-vectors.json` | 三端共享向量 |
| `k8s/…/B6/unified-clean-room.json` | B6.4 |
| `k8s/…/B6/pairing-matrix.json` | Web 两条改为 accepted |
| `k8s/…/B6/result.md` | 游标写到 P0-009A |
| `tpl-app/frontend-pairing-matrix.json` | `next-web-fastapi-web` / `next-web-nest-web` → `ACCEPTED` |
| `tpl-app/template-release-manifest.json` | **新增**；`template_release_id=p0-008b-b6-unified-20260729` |
| `tpl-app` gitlink | `tpl-web-frontend` → `1db9377`；`tpl-web-backend-nest` → `ecb01d9` |

### 3.4 未改动的重要边界

- 未改 Info / Knowledge / Research 业务仓与 Deployment  
- 未推任何 Gitee remote  
- 未把 Nest / React / Vue 写入默认 release 传播清单  
- 计划文档大段（implementation-plan / handoff 里「B6_CURRENT」表述）**未全面改写**；以 `B6/result.md` + manifest 为准。静态门禁 `verify_template_first_plan.py` 仍可能显示 `current_code_task=P0-008B/B6`，进入 P0-009 时应由 Codex 同步改计划文案与该脚本期望值。

---

## 4. 踩过的坑（务必先读）

### 4.1 镜像命名污染

Nest `build.conf` 曾把镜像名写成 `tpl-web-backend`，构建时 **覆盖** FastAPI 同 tag。  
处理：改名为 `tpl-web-backend-nest`，重推 Nest，并 **重建** FastAPI candidate。

### 4.2 `expires_at` 时区拼写

FastAPI `datetime.isoformat()` → `…+00:00`；Next Zod 默认只接受 `Z`。  
症状：Casdoor 登录成功，但进 dashboard 挂（SSR session DTO 校验失败）。  
修复见 §3.1；修完需 **重建并滚动前端镜像**（本侧经历 r1→r2）。

### 4.3 镜像引用必须写全仓库名

`kubectl set image` / patch 时若写成 `tpl-web-frontend@sha256:…`（缺 `harbor…/app-images/`）会 **ImagePullBackOff**。  
一律使用：

`harbor.sunmoonai.com:30443/app-images/<name>@sha256:<64hex>`

### 4.4 kubectl 版本 skew

KIND 是 1.27；本机新 `kubectl`（例如 1.36）会 skew 失败。  
固定：

```bash
export KUBECTL_BIN="$HOME/.local/bin/kubectl-kind-v1.27.3"
export KUBECONFIG="$HOME/.kube/kind-config"
```

### 4.5 Playwright 浏览器路径

沙箱/非默认 path 下找不到 Chrome。固定：

```bash
export PLAYWRIGHT_BROWSERS_PATH="$HOME/.cache/ms-playwright"
```

### 4.6 代理干扰

构建 Next / 跑浏览器时，残留 `HTTP_PROXY` 可能导致 npm 或本机回环异常。  
门禁命令建议 `unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy ALL_PROXY all_proxy DEBUG`。  
kubectl 调用用 `env -i …` 或至少 `env -u DEBUG`（Codex 脚本已有类似模式）。

### 4.7 TrustedHost + port-forward

跨副本探测若 port-forward 到 Pod 且 `Host: 127.0.0.1`，FastAPI TrustedHost → 400。  
验证脚本需伪造允许的 Host（Service 名）。见 §3.2。

### 4.8 B4 Redis ACL 漂移

既有 B4 Nest 长时间未 reconcile 时会出现 `WRONGPASS`。  
不要只 `patch image`；对 Nest 重验应跑：

```bash
bash …/deploy_p0_008b_b4_kind.sh --apply \
  --backend-image '…nest@sha256:…' \
  --frontend-image '…frontend@sha256:…' \
  --deployment-id '…'
```

以刷新 Redis ACL / Secret。

### 4.9 FastAPI 前端回滚基线不能用 B4 旧 Next

B4 旧前端（无 `expires_at` offset 修复）+ FastAPI → dashboard 再挂。  
B6.3F 前端独立回滚应用 **两个都带修复的 digest**（本侧用 r2↔r3）；后端回滚可用 B5 FastAPI digest。

### 4.10 回滚脚本 stdout 污染

`rollout status` 的 Waiting 行若进 command substitution，最终 JSON 汇总的 `--argjson` 会炸。  
已修；若 Codex cherry-pick 漏了这行，会「五段都 passed 却脚本 exit≠0」。

### 4.11 B6.4 `ruff format` 工具漂移

冻结的 `tpl-admin-backend@69e634b` 在当前 lock 的 ruff 0.16.0 下，`ruff format --check` 有一处漂移；`ruff check` + pytest 通过。  
证据记为 `format: tool_skew_recorded`，**未改冻结 commit**。不要为了 format 强行改 007E 基线，除非单独开任务升 formatter 并重发 digest。

### 4.12 远端 clean-room 尚未做

B6.4 是 **本地 git clean clone**（因未授权 push）。  
Gitee 递归 clean clone 重放标记为 `deferred_until_push_authorized`。推远端后应再跑一次真正 remote replay。

---

## 5. 建议 Codex 在 `codex-1` 上如何改文件

### 5.1 推荐策略：拣选，不要整枝硬并

`cursor-1` 与 `codex-1` 可能已分叉。建议：

1. 在 `codex-1` 上 **cherry-pick / 手工移植** 下列提交（或等价 diff），按依赖顺序：  
   - `tpl-web-frontend@1db9377`（产品修复，优先）  
   - `tpl-web-backend-nest@ecb01d9`（build.conf）  
   - `k8s@3859c3a`（REFERENCE_UI）  
   - `k8s` 中 verify 脚本两处修复（Host header + rollback stdout）  
   - 证据 JSON + `result.md` + pairing matrix（可整目录同步 `…/B6/` 新增文件）  
   - `verify_b6_unified_clean_room.py`  
   - `tpl-app`：`frontend-pairing-matrix.json`、`template-release-manifest.json`、两个 gitlink  
2. 解决冲突时以 **本文件 §3 / §4** 为准；不要丢掉 Codex 在 `codex-1` 上更新的计划文案，但 **门禁结论以证据 JSON 为准**。  
3. **暂勿** force-push 覆盖 `codex-1` 远端历史；与用户确认后再 push。

### 5.2 合并后应出现的关键路径

```text
tpl-app/tpl-web-frontend/app/contracts/auth.ts          # offset: true
tpl-app/tpl-web-backend-nest/mybuild/build.conf         # IMAGE=tpl-web-backend-nest
tpl-app/frontend-pairing-matrix.json                    # 两条 Web ACCEPTED
tpl-app/template-release-manifest.json                  # 新建
k8s/sunmoonai/docs/mooc-manus-v5/scripts/verify_b6_*.   # 含 unified_clean_room + 两处 fix
k8s/sunmoonai/docs/evidence/v5/V5-P0-008B/B6/b63*.json
k8s/sunmoonai/docs/evidence/v5/V5-P0-008B/B6/unified-clean-room.json
```

### 5.3 进入 P0-009 前建议 Codex 补的文档债

- 更新 `mooc-manus-langgraph-v5-implementation-plan.md` / handoff：B6 → **ACCEPTED**，当前唯一任务 **P0-009A**  
- 同步修订 `verify_template_first_plan.py` 的期望字符串（否则静态门禁仍报 B6 current）  
- 用户授权后：打 Git tag、push、再跑 **远端** recursive clean clone 证据补强

---

## 6. 建议 Codex 如何测试

环境变量模板：

```bash
export KUBECONFIG="$HOME/.kube/kind-config"
export KUBECTL_BIN="$HOME/.local/bin/kubectl-kind-v1.27.3"
export CLUSTER=KIND
export PLAYWRIGHT_BROWSERS_PATH="$HOME/.cache/ms-playwright"
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy ALL_PROXY all_proxy DEBUG
```

### 6.1 不碰集群的快速回归

```bash
# 1) 前端 DTO / 单测
cd /home/zymun/tpl-app/tpl-web-frontend/app
pnpm test -- tests/unit/browser-session.test.ts

# 2) 共享 consumer vectors（三端）
cd /home/zymun/k8s
python3 sunmoonai/docs/mooc-manus-v5/scripts/verify_b6_web_consumer_vectors.py

# 3) B6.4 clean-room（耗时长；会写/覆盖 manifest 与证据）
python3 sunmoonai/docs/mooc-manus-v5/scripts/verify_b6_unified_clean_room.py \
  --clean-root /tmp/b64-clean-room-codex
```

### 6.2 B6.3F（FastAPI）隔离配对 — 需要时重放

```bash
BACKEND='harbor.sunmoonai.com:30443/app-images/tpl-web-backend@sha256:41dc3a781033dda3e60cd3594ffac7caf767e3c8cb2295ac0b8a21986fbd2414'
FRONTEND='harbor.sunmoonai.com:30443/app-images/tpl-web-frontend@sha256:2a359c8d213813ecbc3b5dbf6a6ed828e73a4c26b6dffaa1d163a507756db2b3'

bash sunmoonai/docs/mooc-manus-v5/scripts/provision_b6_web_fastapi_identity.sh --apply
bash sunmoonai/docs/mooc-manus-v5/scripts/deploy_b6_web_fastapi_pair_kind.sh \
  --apply --backend-image "$BACKEND" --frontend-image "$FRONTEND"

node sunmoonai/docs/mooc-manus-v5/scripts/verify_b6_web_fastapi_pair.mjs

# 独立回滚（前端 old 用 r2，new 用 r3；后端 old 用 B5 digest）
bash sunmoonai/docs/mooc-manus-v5/scripts/verify_b6_web_pair_rollbacks.sh \
  --profile fastapi \
  --old-backend 'harbor.sunmoonai.com:30443/app-images/tpl-web-backend@sha256:f47f1ddd633cb3e8fa8561780a05e53c2f660193aed672d6b553d700dc9f2773' \
  --new-backend "$BACKEND" \
  --old-frontend 'harbor.sunmoonai.com:30443/app-images/tpl-web-frontend@sha256:d695dc24c29890ebf58c327c0f19d31f9a2283d462777c36de632367aa39437a' \
  --new-frontend "$FRONTEND"

# 必做 cleanup
bash sunmoonai/docs/mooc-manus-v5/scripts/deploy_b6_web_fastapi_pair_kind.sh --cleanup
bash sunmoonai/docs/mooc-manus-v5/scripts/provision_b6_web_fastapi_identity.sh --cleanup
```

### 6.3 B6.3N（Nest）— 复用 B4，测完恢复

```bash
NEST='harbor.sunmoonai.com:30443/app-images/tpl-web-backend-nest@sha256:8d17b350df03968c4a847a4f089a2145e3ba326cdbb16db1f2996146cb359536'
NEXT_NEW='harbor.sunmoonai.com:30443/app-images/tpl-web-frontend@sha256:2a359c8d213813ecbc3b5dbf6a6ed828e73a4c26b6dffaa1d163a507756db2b3'
# 验收前基线（Cursor 离开时已恢复到此）
NEST_OLD='harbor.sunmoonai.com:30443/app-images/tpl-web-backend-nest@sha256:78b9929ddf6735341768093ae1093fd0f05420f581189af60913577d6f2f2e3a'
NEXT_OLD='harbor.sunmoonai.com:30443/app-images/tpl-web-frontend@sha256:61fc192219488bc315e431580b345d44e5d0f43bc73569db2e4c2b78769121c8'

bash sunmoonai/docs/mooc-manus-v5/scripts/provision_p0_008b_b4_identity.sh --apply
bash sunmoonai/docs/mooc-manus-v5/scripts/deploy_p0_008b_b4_kind.sh \
  --apply --backend-image "$NEST" --frontend-image "$NEXT_NEW" \
  --deployment-id 'p0-008b-b63n-codex'

node sunmoonai/docs/mooc-manus-v5/scripts/verify_p0_008b_b4.mjs

bash sunmoonai/docs/mooc-manus-v5/scripts/verify_b6_web_pair_rollbacks.sh \
  --profile nest \
  --old-backend "$NEST_OLD" --new-backend "$NEST" \
  --old-frontend "$NEXT_OLD" --new-frontend "$NEXT_NEW"

# 恢复 B4 现场（强烈建议）
bash sunmoonai/docs/mooc-manus-v5/scripts/deploy_p0_008b_b4_kind.sh \
  --apply --backend-image "$NEST_OLD" --frontend-image "$NEXT_OLD" \
  --deployment-id 'b4-v1'
```

### 6.4 业务 App 未碰校验

```bash
"$KUBECTL_BIN" -n app-platform-dev get deploy \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[0].image}{"\n"}{end}' \
  | rg -i 'info-|knowledge-|research-'
```

门禁前后快照应一致。

### 6.5 重建前端（若只拣了源码、镜像仍是旧的）

```bash
cd /home/zymun/tpl-app/tpl-web-frontend/mybuild
CLUSTER=KIND PUSH_IMAGES_AFTER_BUILD=true DOCKER_BUILD_NETWORK=host \
  env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy \
  ./build-image.sh --tag 'p0-008b-b63-candidate-codex-$(date +%Y%m%d)'
# 记录 RepoDigest，更新 manifest / 证据，勿覆盖他人正在用的正式 tag
```

---

## 7. Wave-1 结束时状态速查（历史快照）

> **全库当前游标以 [`cursor续作.md`](./cursor续作.md) / [`cursor续作-P0-009.md`](./cursor续作-P0-009.md) 为准**（下一任务已是 **P0-009C**）。下表仅记录 **B6 刚 ACCEPTED 时** 的现场。

| 项 | 值（Wave-1 结束时） |
|----|-----|
| Cursor 分支 | `k8s`/`tpl-app`/相关子仓：`cursor-1` |
| 远端推送 | **无** |
| P0-008B/B6 | 本地证据链 ACCEPTED |
| 当时下一任务 | **P0-009A**（已由 Wave-2 完成） |
| B4 集群现场 | 应仍为 Nest `78b9929d…` + Next `61fc1922…`（Cursor 已恢复） |
| B6.3F 隔离资源 | 应已清理干净（label `sunmoonai.com/task=v5-p0-008b-b63f`） |

---

## 8. 给 Codex 的最短行动清单（仅 Wave-1）

1. Cherry-pick / 移植 §3 文件与 §2.4 提交。  
2. 跑 §6.1 快速回归。  
3. 若对 KIND 证据存疑，按 §6.2 / §6.3 **择一重放**并 cleanup/恢复。  
4. 模板侧稳定后，再按 [`cursor续作-P0-009.md`](./cursor续作-P0-009.md) 拣选 Info / 009 增量（**不要**把两波揉进一次 rebase）。  
5. 未经用户授权：**不 push**；不要并行开 Knowledge/Research。

---

## 9. 参考路径

- 文档族索引：`k8s/sunmoonai/docs/cursor续作.md`  
- 本波全文：`k8s/sunmoonai/docs/cursor续作-B6.md`  
- 下一波：`k8s/sunmoonai/docs/cursor续作-P0-009.md`  
- B6 总证据：`k8s/sunmoonai/docs/evidence/v5/V5-P0-008B/B6/result.md`  
- Release manifest：`tpl-app/template-release-manifest.json`  
- 配对矩阵：`tpl-app/frontend-pairing-matrix.json`  
- Clean-room 脚本：`k8s/sunmoonai/docs/mooc-manus-v5/scripts/verify_b6_unified_clean_room.py`
