# k8s（部署编排仓）

> 取证时点：2026-08-27 ｜ 总览见 [`../overall-architecture.md`](../overall-architecture.md)

## 1. 定位

五仓中**唯一不含应用源码**的仓：全部平台的部署声明、三个 App 的部署 bundle、
发布门禁脚本、ADR，以及本文档集。它不拥有任何领域逻辑。

规模：约 960 个 yaml、380 个 shell、77 个 python。

构建脚本从 `{SOURCE_ROOT}/{app}-app/` 读源码，render 脚本引用同级的
`../tpl-app/k8s-deployment`——**因此五仓必须并列放置**。

## 2. 结构

`sunmoonai/` 下 **8 个平台 + 3 个非平台**目录：

| 目录 | 装什么 |
| --- | --- |
| `app-platform/` | 三 App 的 bundle + auth-app（Casdoor）+ 共享脚本 + `utils/` |
| `data-platform/` | postgresql · redis · mongodb · neo4j · elasticsearch · kibana · logstash · **object-storage**（不叫 minio/s3） |
| `messaging-platform/` | RabbitMQ |
| `ingress-platform/` | Traefik Helm 与 CRD |
| `cicd-platform/` | Harbor · Jenkins |
| `ops-platform/` | flower · pgadmin · redisinsight · mongo-express |
| `infrastructure/` | 远程 kubeadm 分步脚本（`steps/step00…step13`） |
| `kind-infrastructure/` | 本地 KIND 集群定义与节点镜像 |
| `deploy-sunmoonai-all/` | 全平台总控（**非平台**） |
| `utils/` | 跨平台工具，如 `db-provisioner`（**非平台**） |
| `docs/` | 本文档集 + `architecture-v2/` 门禁与 evidence（**非平台**） |

仓根另有 `utils/`（集群参数解析、Secret 占位生成、Harbor 包等）。

## 3. 一个 App 的部署单元

以 `app-platform/info-app/` 为例——**7 个 deploy 入口 + 1 个 deployment 目录**：

```
deploy-info-app-all/            App 总入口
deploy-info-backend-api/        ┐
deploy-info-backend-worker/     │ Backend 四角色
deploy-info-backend-scheduler/  │
deploy-info-migration/          ┘
deploy-info-admin-frontend/     ┐ 双前端
deploy-info-web-frontend/       ┘

deployment/
├── render.py       渲染 bundle（解析镜像 digest 写入）
├── deploy.py       执行（plan / apply / server-dry-run / drift / cleanup）
└── bundle/         渲染产物：五份 YAML + release.json
```

三个领域 App 同构。**auth-app 例外**：只有 Casdoor 一个组件，Helm 部署，
**无 `deployment/bundle/release.json`**，因此不受发布链的 digest 纪律约束。

## 4. 发布

### 4.1 bundle 五文件

| 文件 | 资源 kind |
| --- | --- |
| `00-prerequisites.yaml` | ServiceAccount · ConfigMap · Service |
| `10-migration.yaml` | Job |
| `20-runtime.yaml` | Deployment · PodDisruptionBudget · HorizontalPodAutoscaler |
| `30-network-policies.yaml` | NetworkPolicy（**独立文件，不在 prerequisites 内**） |
| `40-ingress.yaml` | IngressRoute |

### 4.2 apply 的真实顺序

`deployment/deploy.py` 的 `apply()`，三 App 一致：

```python
external_secret_gate(args, data)          # 0  release.external_secrets 须全部已存在
apply_file(args, "00-prerequisites.yaml") # 1
apply_file(args, "30-network-policies.yaml")  # 2  ← 网络策略先于迁移
run_migration(args, data)                 # 3  删旧 Job → apply → 等完成 → 删 Job
apply_file(args, "20-runtime.yaml")       # 4
apply_file(args, "40-ingress.yaml")       # 5
# 6  逐个 rollout status（按 deployment_replicas）
# 7  legacy_deployments 缩容至 0
```

**两个易错点**：

1. 网络策略在**迁移之前**就 apply——按"prerequisites→migration→runtime→network"
   的直觉顺序手工部署，会在无 NetworkPolicy 的窗口内跑迁移与运行态。
2. `STEADY_FILES` = `[00-prerequisites, 20-runtime, 30-network-policies, 40-ingress]`，
   **不含 `10-migration`**（Job 跑完即删，不是稳态资源）。`drift` 只比对这四份。
   `server-dry-run` 又按 `release.json.resources` 数组顺序走，**与 apply 顺序不同**。

三 App 差异：Investment 与 Knowledge 有步骤 0a 外部对账（RabbitMQ vhost / Redis ACL /
knowledge active binding），Info 没有；Investment 在迁移前另有一步用 SQL 改 PG 角色 LOGIN 状态。

### 4.3 `release.json` 是发布的不可变输入

| 字段 | 含义 |
| --- | --- |
| `schema_version` | 须为 `2` |
| `architecture` | 须为 `app-platform-v2-formal` |
| `formal_release` | 须 `true` |
| `images` | backend / admin / web 三个 **digest** |
| `sha256` | 五份 YAML 的内容哈希 |
| `deployment_replicas` | 五个 Deployment 的副本契约 |
| `ingress_routes` | 路由结构契约 |
| `external_secrets` | 集群须预先存在的 Secret 名 |
| `legacy_deployments` | 须缩容至 0 的旧 Deployment |
| `forbidden_markers` | bundle 全文禁止出现的字符串 |
| `renderer_inputs_sha256` | render 输入文件指纹 |
| `contains_credentials` | 须 `false` |

App 特有：Investment 有 `knowledge_binding`；Knowledge 有 `retrieval_dataset_allowlist`
与 `protected_provider_resources`。

## 5. 门禁

**不存在一个跑一次就全覆盖的脚本。**静态与运行时分属不同脚本，网络策略还需另起集群。

| 层 | 脚本 | 需活集群 |
| --- | --- | --- |
| 静态：schema / sha256 / digest / 标签 / 禁用标记 | `app-platform/scripts/verify-formal-instance.py` | 否 |
| 静态：`.conf` 与 `release.json` 逐字段一致 | `deployment_config.py` + `formal_deploy_entry.py` | 否 |
| 集群态：副本 / digest / 迁移 head / 无残留 Job / Ingress 集 | `docs/architecture-v2/scripts/verify_r7_release_kind.py` | 是 |
| 集群态：跨 App 纵切真实链路 | `verify_r6_cross_app_vertical_kind.py` | 是 |
| 浏览器：strict TLS + 真实 Casdoor 登录 | `verify_r3_template_browser.mjs` | 是 |
| 网络：NetworkPolicy 包级 allow/deny | `verify_r3_network_policy_calico.sh` | 是，**另起临时 Calico 集群** |

`verify-formal-instance.py` 实际检查（逐条可查）：
`schema_version == 2` · `architecture == "app-platform-v2-formal"` · `formal_release is True` ·
`renderer_inputs_sha256` · 五文件 sha256 逐份重算比对 ·
所有资源须带 `sunmoonai.com/managed-by: app-platform-v2` 标签 ·
镜像须匹配 `^[^\s]+@sha256:[0-9a-f]{64}$` · `forbidden_markers` 全文扫描

## 6. 集群

| 事项 | 现状 |
| --- | --- |
| KIND 拓扑 | 1 control-plane + 2 worker |
| **KIND CNI** | 默认 kindnet，**不执行 NetworkPolicy**——所以包级验证必须另起 Calico 集群 |
| 远程 CNI | 默认 calico |
| 命名空间 | 各平台 `<platform>-dev` |
| production profile | 三 App 的 `profiles/production.conf` 均 `PROFILE_ENABLED=false`，直接部署报 `deployment profile is disabled` |

`production_network_policy_gate_satisfied` 是**门禁脚本的 JSON 输出字段与 evidence 内容**，
不是集群里的持久配置；在 KIND 上通常为 `false`。

## 7. 已知未实现或易误解

| 容易误认为 | 实际 |
| --- | --- |
| `infrastructure/` 含 cert-manager | **无**。该目录只有 steps/utils/deploy-*/docs；TLS 由 Traefik + 各 App `*-tls` Secret 承担 |
| 对象存储目录叫 minio 或 s3 | 实际是 `data-platform/object-storage/` |
| 构建脚本推 digest | **推可变 tag**；digest 由 `render.py` 解析后写入 bundle，门禁只认 digest |
| 构建脚本默认覆盖四个 App | 默认 `APPS="info research knowledge"`——**不含 investment，且仍留已废弃的 research** |
| `server-dry-run all` 顺序 = apply 顺序 | 不同，见 §4.2 |
| auth-app 与三 App 同模型 | auth-app 是 Helm，无 bundle/release.json |
| R7 终检覆盖网络策略包级行为 | 不覆盖，那是独立脚本 + 独立集群 |

仓根另有两份历史便签值得注意：`接着做.txt`（2026-07-07 的暂停交接，属历史快照，
**非现行规则**）与 `密码修改表.md`（其存在本身说明密钥轮换未脚本化）。

## 8. 验证

```bash
cd <repo>/k8s/sunmoonai

# 平台目录清单（应为 8 平台 + deploy-sunmoonai-all + utils + docs）
ls -1d */

# 静态门禁
python3 app-platform/scripts/verify-formal-instance.py --app info

# apply 真实顺序（权威）
awk '/^def apply\(/,/^def drift\(/' app-platform/info-app/deployment/deploy.py

# bundle 各文件的资源 kind
grep -h '^kind:' app-platform/info-app/deployment/bundle/*.yaml | sort -u
```
