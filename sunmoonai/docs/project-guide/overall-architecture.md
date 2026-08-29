# SunMoonAI 项目总览

> 最后更新：2026-08-29 ｜ 取证时点：2026-08-29（对五仓源码直接取证）
>
> **本文件是进入这个项目的唯一入口。**读完它，你应当知道：改动落在哪个仓、
> 那里有什么不可违反的规则、以及去哪里查更细的东西。
>
> 它**不**试图覆盖全部细节——细节按主题分在同目录的 [`README.md`](README.md)
> 所列各处，每节末尾也给出指路。
> 与代码冲突时**永远以代码为准**，并请指出本文件需要更新。

---

## 1. 这个项目是什么

一条内容流水线，加上消费它的智能体：

```
外部信息源 ──采集──▶ 治理/去重 ──分发──▶ 知识库索引 ──检索──▶ 投资研究智能体
             info-app                  knowledge-app          investment-app
```

三个领域 App 形态完全一致，因为它们都从同一个模板实例化；另有一个仓只负责把它们部署到
Kubernetes。**五个 Git 仓，必须并列放置**（部署脚本按同级相对路径互相引用）。

| 仓 | 职责 | 含业务源码 |
| --- | --- | --- |
| `tpl-app` | 模板：定义"一个标准 App 长什么样"，并提供部署脚手架 | 是（无领域） |
| `info-app` | 资讯域：采集、抽取、去重、治理，向 knowledge 分发 | 是 |
| `knowledge-app` | 知识域：摄入与检索，两套跨仓契约的**唯一提供方** | 是 |
| `investment-app` | 智能体域：投资研究 run、检索证据、人机交互 | 是 |
| `k8s` | 部署编排：全部平台的部署声明、发布门禁；本文档也在此 | **否** |

规模（实测）：后端合计约 25.5k 行 Python；八个前端约 570 个 ts/tsx；
`k8s` 仓约 960 个 yaml、380 个 shell、77 个 python。

## 2. 依赖方向

```
tpl-app ──实例化──▶ info-app ──artifact v1──▶ knowledge-app ──retrieval v1──▶ investment-app
                        │                          │                              │
                        └──────────── 都经 Casdoor 取身份 ──────────────────────────┘

k8s ──构建镜像 / 渲染 bundle / apply──▶ 三个 App 的运行态
```

**没有反向依赖**：knowledge 不调 info，info 不知道 investment 存在，tpl 不知道任何实例存在。
跨 App 只经受版本控制的 HTTP 契约，**禁止跨 App 直接读写数据库**。

契约的规律：**schema 真源放在被调方（provider），锁文件放在调用方（consumer）**。

→ 细节：[`architecture/topics/contracts.md`](topics/contracts.md)

## 3. 一个标准 App 长什么样

四个 App 仓结构完全相同，各含三个 Git 子模块：

```
<app>-app/
├── <app>-backend/          FastAPI，Admin/Web/Internal 三面共用一个工程
├── <app>-admin-frontend/   Next.js 管理端
└── <app>-web-frontend/     Next.js 用户端
```

### 3.1 一个镜像，四个运行角色

后端**同一个不可变镜像**按不同命令启动四种进程，各有独立 ServiceAccount、
数据库 principal、消息凭据与扩缩容策略：

| 角色 | 入口 | K8s 形态 |
| --- | --- | --- |
| API | `app/bootstrap/api.py` | Deployment + Service |
| Worker | `app/bootstrap/worker.py`（Celery） | Deployment |
| Scheduler | `app/bootstrap/scheduler.py`（Celery beat） | 单副本 Deployment |
| Migration | `app/bootstrap/migration.py` | 一次性 Job，跑完即删 |

`app/main.py` 只有 5 行，是向后兼容的 ASGI 转发，**不是真正的入口**。

### 3.2 后端分层与两套接口面

```
app/app/
├── domain/          领域模型、状态机、命令
├── application/     服务编排、DTO、Port（接口定义）
├── infrastructure/  ORM、外部适配、Celery、存储（Port 实现）
└── interfaces/
    ├── http/        ← 模板面：admin/web 认证、diagnostics、web interaction
    └── endpoints/   ← 领域面：各实例自己的业务路由
```

**`http/` 与 `endpoints/` 的分工是本项目的实际约定**：模板提供的通用面在 `http/`，
实例自己的领域路由在 `endpoints/`。`tpl-app` 没有 `endpoints/`，因为它没有领域。

依赖方向单向：`application` 不得 import `app.interfaces`（由不变量测试断言）。

### 3.3 前端

两个前端技术栈同构（Next.js 16 + React 19 + Tailwind v4 + shadcn + next-intl，
`output: 'standalone'`），源码在内层 `app/` 目录：

- 路由：`app/[locale]/(auth|dashboard)/...`，`proxy.ts` 是 Next 16 的路由边界
  （**不是 `middleware.ts`**，Next 16 已改名）
- 请求：`lib/common/api-client.ts`，只允许同源 `/api/` 路径（**未使用 axios**）
- 会话：`lib/server/auth-session.ts` 经 server-only `BACKEND_INTERNAL_URL` 读取；
  **token 永不落 localStorage**
- **OIDC 全部在后端**，前端没有 auth 的 API Route

→ 细节：[`architecture/repos/tpl-app.md`](repos/tpl-app.md)

## 4. 平台层（`k8s/sunmoonai/`）

**八个平台目录 + 三个非平台目录**：

| 平台 | 装什么 | 命名空间 |
| --- | --- | --- |
| `app-platform` | 三个 App 的正式 bundle + auth-app（Casdoor） | `app-platform-dev` |
| `data-platform` | postgresql、redis、mongodb、neo4j、elasticsearch、kibana、logstash、object-storage | `data-platform-dev` |
| `messaging-platform` | RabbitMQ（Celery broker） | `messaging-platform-dev` |
| `ingress-platform` | Traefik，TLS 终止 | `ingress-platform-dev` |
| `cicd-platform` | Harbor、Jenkins | `cicd-platform-dev` |
| `ops-platform` | pgAdmin、RedisInsight、Flower 等 | `ops-platform-dev` |
| `infrastructure` | 远程 kubeadm 分步脚本 | — |
| `kind-infrastructure` | 本地 KIND 集群定义 | — |

非平台：`deploy-sunmoonai-all/`（总控）、`utils/`（跨平台工具）、`docs/`（含本文档）。

App 侧实际用到的数据组件只有：PostgreSQL、Redis、object-storage、RabbitMQ、
Elasticsearch（info 索引，**默认关闭**）。mongodb / neo4j / kibana / logstash 未见 App 引用。

→ 细节：[`architecture/repos/k8s.md`](repos/k8s.md)

## 5. 三条主链

### 5.1 请求链（在线）

```
浏览器 ──HTTPS──▶ Traefik ──┬─ Host 匹配 ──▶ Admin/Web Next.js（SSR）
                            └─ 同源 /api ──▶ 统一 Backend ──▶ PG / Redis / RabbitMQ
                                                    │
SSR 经 BACKEND_INTERNAL_URL ────────────────────────┘
```

浏览器拿不到内部地址、client secret、服务令牌或数据库凭据。
Next.js 可以做 SSR 与同源交互，但**最终授权永远在 Backend**。

### 5.2 数据链（异步，跨 App）

```
info 采集 → 治理/去重 → distribution_record + delivery_outbox_message
  → Celery dispatch_distribution → POST knowledge 摄入
  → RAGFlow 索引（派生系统，可重建）
  → investment 检索取证据 → Citation 投影回浏览器
```

约束：每一步只写自己 App 的库；跨 App 不用分布式事务；消费方必须幂等；
RAGFlow / Elasticsearch / 缓存都是**可重建的派生系统，不是权威主档**。

### 5.3 发布链

```
源码 → 镜像推 Harbor → render.py 解析 digest 写入 bundle → deploy.py apply
```

一次发布 = 一份 `deployment/bundle/`，含**五份 YAML + 一份 `release.json`**。
`release.json` 是不可变输入：镜像 digest、五文件 sha256、副本数、Ingress 结构、
须预先存在的 Secret 名、禁止出现的字符串。

**apply 的真实顺序**（`deployment/deploy.py` 的 `apply()`，三 App 一致）：

```
0  external_secret_gate         检查 release.external_secrets 全部存在
1  00-prerequisites.yaml        ServiceAccount / ConfigMap / Service
2  30-network-policies.yaml     ← 网络策略在迁移之前
3  10-migration.yaml            删旧 Job → apply → 等完成 → 删 Job
4  20-runtime.yaml              Deployment / PDB / HPA
5  40-ingress.yaml              IngressRoute
6  rollout status               等各 Deployment 就绪
7  legacy_deployments 缩容至 0
```

两个易错点：**网络策略先于迁移**；`server-dry-run` 按 `release.json.resources`
数组顺序走，**与 apply 的真实顺序不同**。

→ 细节：[`architecture/topics/release.md`](topics/release.md)

## 6. 身份

**两类身份，互不通用**：浏览器 cookie 不能用于服务间调用，服务 token 也不构成用户身份。

| 类别 | 机制 |
| --- | --- |
| 浏览器身份 | Casdoor OIDC（授权码 + PKCE）→ 后端会话 cookie |
| 服务身份 | 签名的 workload JWT，或 OAuth client credentials |

Casdoor 由 `auth-app` 以 Helm 单独部署，**不套 App 模板、无 bundle/release.json**，
因此不受发布链的 digest 纪律约束。

**Admin 与 Web 是两个独立的安全边界**（`BrowserSurfaceProfile`，不可变）：
各有独立 client、redirect、cookie 名、session namespace、Origin 策略。
关键不对称：**Admin 强制要求 `{app}:admin` scope，Web 不要求任何 scope**。

服务身份校验链：验 audience → subject 必须命中精确绑定表 →
`token_scopes ⊆ 允许集` 且 `required ⊆ token_scopes`。

→ 细节：[`architecture/topics/identity.md`](topics/identity.md)

## 7. 硬规则来自哪里

改动前要知道"什么会让我失败"。本项目的强制分三层，**强度递增**：

| 层 | 在哪 | 违反后果 |
| --- | --- | --- |
| **结构不变量** | 各仓 `app/tests/test_kernel_invariants.py`（5–6 项） | CI 失败 |
| **启动期配置校验** | 各仓 `core/config.py`（约 35 处 `raise ValueError`） | **进程起不来** |
| **部署门禁** | `k8s` 仓的 `verify-formal-instance.py`、`deployment_config.py` 等 | 部署被拒 |

注意一个常见误解：`test_kernel_invariants.py` 大多是**文件存在性与字符串缺席断言**
（例如"`app.interfaces` 不出现在 application/ 目录"），是结构性冒烟测试，
**不是深度架构校验**。真正严格的是第二层——配置错了服务直接起不来，不会降级运行。

→ 细节：各仓 `architecture/repos/*.md` 的「硬规则」一节

## 8. 动手前必知的红线

| 红线 | 违反会怎样 |
| --- | --- |
| 跨 App 直接读写对方数据库 / bucket / Redis key | 破坏领域所有权，无门禁能救 |
| 用可变 tag 代替 `repo@sha256:` digest | 部署门禁拒收 |
| 契约 schema 在 consumer 仓另建副本 | 产生第二真源；升级必须 provider 先改、双端测试通过后才动锁 |
| 生产开启 `REFERENCE_INTERACTION_ENABLED` | 启动 `ValueError`（四仓一致） |
| 生产 `ALLOWED_HOSTS` 用 `*`、`APP_ORIGIN` 非 HTTPS | 启动即失败（后端与前端各自校验） |
| 先改实例再改模板 | 违反"模板先行"；公共缺陷必须先修模板过门禁再同步实例 |
| 迁移链分叉 / 与测试清单不一致 | CI 失败 |

## 9. 当前状态与已知缺口

**这一节记录的是"看起来做完了、其实没有"的东西**，是新来者最需要先知道的。

### 9.1 版本口径

**四层版本全部是 `2.0.0`。**

| 层 | 取值 |
| --- | --- |
| 源码 | 四后端 `pyproject.toml` + `uv.lock`、八前端 `package.json` 均 `2.0.0` |
| 镜像别名 | R7 发布清单给 12 个镜像记为 `:2.0.0` |
| 部署 | bundle 用 digest 引用，与 R7 清单 **9/9 逐字一致** |
| 发布记录 | `release.json` `formal_release: true`；manifest `template_release: 2.0.0` |

**发布采用 `exact-digest-alias`**（manifest `release_policy.promotion_method`）：
不重建镜像，给已过 R7 门禁的 digest 打 `2.0.0` 别名。Dockerfile 逐字
`COPY app/`、无版本注入，镜像内的版本字符串来自构建时的源码。

两点会绊人，动版本号前须知道：

- **当前运行中的镜像内部仍报 `2.0.0.dev0`**——源码于 2026-08-29 才对齐，
  未为此重建（`/api/version` 读 `importlib.metadata`）。下次有实质改动
  重建时自然带上 `2.0.0`
- **改源码版本必须同时改 `uv.lock`**，否则 Dockerfile 的 `uv sync --frozen`
  会在构建阶段失败。`test_package_version_matches_the_formal_release` 会拦

### 9.2 四仓一致的未接线项

| 项 | 实际状态 |
| --- | --- |
| **web-interaction 契约** | DTO、Port、前端 zod 齐全，但默认适配器返回 **503**；唯一替代实现是 reference fixture，且**生产禁止开启**。即：生产环境该契约面**必定不可用** |
| **共享 Outbox/Inbox 原语** | 表、仓库类、Port 全在，业务层**零调用**。**这是有意的**：模板提供原语，实例按需启用；没有业务需要之前接上去等于凭空加一块要维护、要监控、要排障的面。**第一个跨 App 异步事件落地时重新审视**，届时一并定投递语义与去重键 |
| **Celery 周期任务** | 四仓都有 Scheduler 入口，**都没有 `beat_schedule` 定义**。**这是有意的**，理由同上。**第一个定时任务落地时重新审视**，届时须解决 beat 的多副本重复触发 |
| **`/api/internal/v1` 入站面** | tpl 与 info 只有中间件、无 router 挂载；只有 knowledge 与 investment 真正有内部路由 |

### 9.3 各 App 的具体缺口

| App | 缺口 |
| --- | --- |
| info | Elasticsearch 索引默认关闭（`SEARCH_BACKEND=disabled`），索引任务直接跳过；分发运行时**只接受 `knowledge-app`** 一个下游 |
| knowledge | RAGFlow 的 `CANCEL` 终态**被当作成功**（只有 `FAIL` 抛错）——被取消的摄入会标记为成功，存在数据完整性风险；Admin 入库运维页是**静态占位**，无 fetch 无操作 |
| investment | `RunBudget` 四维限额已实现，但**两条生产链都不调用**（全仓仅三处引用：定义处、非生产图、其测试），故 `budget_exceeded` 状态在生产中**不可达**；Web 面未接 Pilot 链 |

### 9.4 文档层的已知问题（一项已处置）

各组件目录下的 `CLAUDE.md`（共 8 份，会被 Claude Code 自动注入）**曾严重过期**：
描述的 `app/api/auth/`、`lib/request.ts`、`store/auth.ts`、`middleware.ts` 均不存在，
声称的 axios 不是依赖，并要求以已被取代的 v5 文档为准。2026-08-27 已在各子仓
重写为「局部编码规则 + 指向本文档集的指针」。**这是本节中唯一已处置的项**，
其余各项仍未解决。

→ 逐条核对记录与现状复核命令：[`architecture/verify.md`](verify.md) §5


## 10. 去哪查

| 我要做什么 | 读 |
| --- | --- |
| 改某个仓的代码 | [`architecture/repos/`](repos/) 下对应文件 |
| 加或改跨 App 契约 | [`architecture/topics/contracts.md`](topics/contracts.md) |
| 动登录、权限、服务间调用 | [`architecture/topics/identity.md`](topics/identity.md) |
| 加表、改迁移 | [`architecture/topics/data.md`](topics/data.md) |
| 发版、改部署清单 | [`architecture/topics/release.md`](topics/release.md) |
| **动代码前必读的规则** | [`../dev-plan/constraints.md`](../dev-plan/constraints.md)（39 条，按主题分组） |
| 提一个开发请求 | [`../working/request-lifecycle.md`](../working/request-lifecycle.md) |
| 查当前 digest / 迁移 head 等易变值 | 本文档不记这些值，见 [`architecture/verify.md`](verify.md) |

**易腐值一律不写进文档正文**（镜像 digest、schema sha256、commit、迁移 head、副本数）——
它们变化比文档维护快，写进来必然先于文档失效。文档只写规则并指向真源。
