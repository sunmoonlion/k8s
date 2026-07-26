# V5-P0-008B/B5 FastAPI Canonical Kernel + Default Web BFF 证据

状态：`ACCEPTED / B6_NEXT`

验收日期：2026-07-26（Asia/Shanghai）

## 1. 固定输入与产物

| 产物 | 固定值 |
|---|---|
| canonical Admin kernel commit | `456bd65be77140f07c46ab00b955ab376f3052d2` |
| Admin kernel tree | `c558e13aa7740baa78413c4dfe7c687f33f5c54e` |
| Admin Git tag | `p0-008b-b5-admin-kernel-20260726` |
| Admin 镜像 tag | `tpl-admin-backend:p0-008b-b5-admin-kernel-20260726` |
| Admin 镜像 digest | `sha256:0fe898a76e33fd72fba53c1c1c4cd9f9d51ea0a8632c75c16705f41efa8e29ba` |
| FastAPI Web 初始化 commit | `6b9bd404169468676e7f78ebb68548e410827197` |
| FastAPI Web 最终 commit | `6b6c71ee83c36e3071aa9b885d750ad6d47901f0` |
| FastAPI Web Git tag | `p0-008b-b5-fastapi-web-20260726` |
| FastAPI Web 远端 | `https://gitee.com/sunmoonlion/tpl-web-backend.git` |
| FastAPI Web 镜像 tag | `tpl-web-backend:p0-008b-b5-fastapi-web-20260726` |
| FastAPI Web 镜像 digest | `sha256:f47f1ddd633cb3e8fa8561780a05e53c2f660193aed672d6b553d700dc9f2773` |
| B5 父仓 commit/tag | `bd19ee21c1b095fe40846b6df4d9570411cd10c4` / `p0-008b-b5-parent-20260726` |
| interaction contract | `1` |

新 Web 仓的初始化 commit 与固定 Admin kernel 使用相同 tree
`c558e13aa7740baa78413c4dfe7c687f33f5c54e`。这证明初始化来源是已验收母版，而不是旧
Admin 认证原型、Nest 历史或任一业务 App 整树。随后只在新仓提交 Web surface 适配。

## 2. canonical FastAPI Admin 母版

Admin 母版已从三个 P0-005 实现中回收并统一通用安全能力，且没有带入
Document、Dataset、Ingestion、Run 或 Runtime 领域代码。固定能力包括：

- Authorization Code + PKCE S256、持久化且一次性消费的 state/nonce transaction；
- discovery/JWKS/issuer/audience/算法/时间声明严格校验；
- backend-owned 最小 Principal session，不保存或返回 Provider token；
- Admin 专属 audience、cookie 和 Redis namespace；
- CSRF/Origin、POST logout、Trusted Host、CORS、安全响应头和稳定错误；
- canonical identity binding migration、PostgreSQL/Redis readiness、非 root 镜像。

源码门禁为 Ruff、format、Pyright 及 `34 passed`；PostgreSQL migration、Docker
production smoke 与安全负向矩阵均通过。固定 commit、tag 和镜像 digest 已推送。

## 3. 默认 FastAPI Web BFF

新 `tpl-web-backend` 没有把 Admin Backend 直接作为 Web 服务运行。Web 适配显式替换：

- `surface=web`、Web Casdoor application/audience、Web cookie 和 Redis namespace；
- 登录、注册、callback、continue、POST logout 的 Web return path；
- `/api/runs/{run_id}`、SSE events、actions 和 Citation source 的 interaction v1；
- SSE `id/event/data`、cursor 冲突/过期、provider preflight 和稳定错误映射；
- 独立 downstream client credentials、固定 origin 与路径 allowlist，不转发浏览器 token；
- 默认 adapter 失败关闭；reference adapter 只允许非生产配对测试；
- `/api/health`、`/api/version`、`/health`、`/ready` 和 production docs 关闭。

Admin-only task route已从默认 API 删除；可选 Celery 基础设施仍保留为模板能力，但没有
伪装为 Web 业务 API。

源码门禁：

```text
ruff check: passed
ruff format --check: passed
pyright: 0 errors
pytest: 43 passed
git diff --check: passed
```

## 4. Docker 与迁移门禁

最终镜像从已提交的 Web commit 重建，构建阶段执行 Ruff、format 和 Pyright。运行镜像：

- `USER appuser`，实际 UID/GID `1001/1001`；
- 不包含 Node、测试目录、`.git` 或 `.env`；
- PostgreSQL migration `upgrade -> downgrade base -> upgrade head` 可逆；
- Redis/PostgreSQL readiness 为 200；
- `/api/health` 与 `/api/version` 返回 Web/contract/deployment identity；
- 匿名 `/api/auth/me` 与 Run 返回稳定 401 envelope；
- production `/docs` 与 `/openapi.json` 返回 404；
- CSP/CORS/安全响应头门禁通过。

生产配置负向矩阵确认以下配置均拒绝启动：production reference adapter、HTTP Provider、
wildcard host、不安全 session cookie、跨来源 callback。

## 5. KIND 两副本门禁

在隔离 namespace `tpl-web-b5` 中使用最终不可变 digest 完成：

1. 临时 PostgreSQL/Redis 就绪；
2. 独立 migration Job 应用 `20260726_0001`；
3. 两副本 FastAPI Web BFF rollout；
4. 集群内 consumer 连续 20 次 Service 请求；
5. 匿名拒绝、production docs 关闭与 interaction contract v1；
6. 静态检查 immutable digest、非 root、只读根文件系统、drop `ALL`、禁止
   ServiceAccount token、readiness/liveness、PDB 和 `maxUnavailable=0`。

验证器结果：

```json
{"anonymous":401,"contract_version":1,"credentials_printed":false,"deployment_id":"b5-kind","docs":404,"health":200,"ready":200,"result":"passed","service_samples":20,"task":"V5-P0-008B-B5-KIND","tokens_printed":false}
```

验收后已删除整个 `tpl-web-b5` namespace；没有遗留 Job、Secret、数据库或 Service。

## 6. 范围与下一游标

B5 没有修改 Info、Knowledge 或 Research：

```text
info-app      37988c873e8d
knowledge-app 2e410ad0ba8f  # 进入 B5 前已有本地 ahead 3，未被改写
research-app  81215951809e
```

B5 只证明 canonical FastAPI Admin 内核与默认 FastAPI Web BFF 各自成立。它尚未证明同一
Next 对 FastAPI/Nest 的共享 consumer vectors、真实双 profile 配对、版本偏斜和统一
release tuple；这些是 B6 的门槛。

因此 B5 状态为 `ACCEPTED`，唯一下一任务切换到 B6。B6 未接受前禁止生成 P0-009 release
manifest 或修改三个业务 App；B6 接受后必须立即进入 P0-009A。
