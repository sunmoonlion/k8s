# k8s

> 仓库 `sunmoonlion/k8s`
> 最后更新：2026-08-15 ｜ 验证时点：2026-08-15（对清单与脚本取证）
> 跨仓规则见 [`../shared/`](../shared/)；全局地图见 [`../map.md`](../map.md)

## 1. 这个仓是什么

Kubernetes 部署编排仓，**不含业务 App 源码**：构建脚本从 `{SOURCE_ROOT}/{app}-app/` 读源码
（`sunmoonai/app-platform/scripts/build-push-app-images.sh:106`），render 引用同级
`../tpl-app/k8s-deployment`（`investment-app/deployment/render.py:120`）。
正式 App 发布的真相在 `app-platform/*-app/deployment/bundle/`。本文档集也住在本仓
（`sunmoonai/docs/sunmoonai-architecture/`）。

## 2. 目录地图

| 路径（`/home/zymun/k8s/` 下） | 装什么 | 什么任务会动它 |
| --- | --- | --- |
| `sunmoonai/app-platform/` | 三 App 正式 bundle、Casdoor（auth-app）、共享脚本 | 改 App 发布、跑 `deploy.py` / `render.py` |
| `sunmoonai/kind-infrastructure/` | KIND 集群定义、节点镜像、Harbor 辅助 | 本地建或重建集群 |
| `sunmoonai/infrastructure/` | 远程 kubeadm 分步脚本（OS → CNI → 命名空间 → Harbor） | 远程集群 bootstrap |
| `sunmoonai/ingress-platform/` | Traefik Helm 与 CRD | 入口与 TLS 终止 |
| `sunmoonai/cicd-platform/` | Harbor、Jenkins | 镜像仓库与 CI |
| `sunmoonai/data-platform/` | PostgreSQL、Redis、MongoDB、Neo4j、ES、`object-storage` | 数据层 Helm 部署 |
| `sunmoonai/messaging-platform/` | RabbitMQ | Celery broker |
| `sunmoonai/ops-platform/` | pgAdmin、RedisInsight 等运维 UI | 运维工具 |
| `sunmoonai/deploy-sunmoonai-all/` | 全平台总控脚本与优先级配置 | 一键按序部署 |
| `sunmoonai/utils/` | db-provisioner 等跨平台工具 | 库、用户、Secret 供给 |
| `sunmoonai/docs/architecture-v2/` | 门禁脚本与验收 evidence | R3–R7 发布验收 |
| `sunmoonai/docs/sunmoonai-architecture/` | 本文档集 | 投影维护 |
| `utils/`（仓根） | 集群参数解析、Secret 占位生成、Harbor 包 | 总控与各 deploy 共享 |

## 3. 改动前必读的硬规则

| 规则 | 位置 | 违反后果 |
| --- | --- | --- |
| 镜像必须为 `repo@sha256:…` 且在 `release.json.images` 中 | `app-platform/scripts/verify-formal-instance.py:22-23,99-102` | 门禁 JSON `result: failed` |
| bundle 文件 sha256 须与 `release.json.sha256` 一致 | `verify-formal-instance.py:71-73` | `resource hash mismatch` |
| 所有资源须带 `sunmoonai.com/managed-by: app-platform-v2` | `verify-formal-instance.py:81-82` | 视为非 v2 资源 |
| `.conf` 不得覆盖 bundle 中的镜像/副本/origin | `deployment_config.py:119-144`；`formal_deploy_entry.py:55` | `ConfigError`，退出码 2 |
| 迁移 Job 失败或超时阻断 apply | `investment-app/deployment/deploy.py:197-199`（info 同：`info-app/deployment/deploy.py:148-150`） | `DeployError: migration Job failed` |
| `external_secrets` 中缺任一 Secret 阻断 apply | `investment-app/deployment/deploy.py:86-102` | `missing external Secrets` |
| 正式发布不可经默认入口 uninstall/cleanup | `formal_deploy_entry.py:80-83` | `ConfigError` |
| C1/production profile 默认禁用 | 各 `profiles/production.conf:3`；`deployment_config.py:100-102` | `deployment profile is disabled` |
| 资源命名稳定：render 将 `*-r5` 前缀替换为稳定名 | `investment-app/deployment/render.py:300-307` | 与 bundle 名不一致则门禁失败 |
| bundle 文本禁出现 candidate/legacy 标记 | `verify-formal-instance.py:131-133`；各 `release.json` 的 `forbidden_markers` | `forbidden candidate/legacy marker found` |

## 4. 每个 App 的部署 bundle

### 4.1 bundle 文件与资源 kind

用 `rg '^kind:' sunmoonai/app-platform/*/deployment/bundle/*.yaml` 核实：

| 文件 | 资源 kind（去重） | 位置 |
| --- | --- | --- |
| `00-prerequisites.yaml` | ServiceAccount、ConfigMap、Service | 三 App 同结构，例 `investment-app/deployment/bundle/00-prerequisites.yaml:2,62,153` |
| `10-migration.yaml` | Job | `investment-app/deployment/bundle/10-migration.yaml:2` |
| `20-runtime.yaml` | Deployment、PodDisruptionBudget、HorizontalPodAutoscaler | `investment-app/deployment/bundle/20-runtime.yaml:2,191,206` |
| `30-network-policies.yaml` | NetworkPolicy（Info/Investment/Knowledge 各 9 条） | `investment-app/deployment/bundle/30-network-policies.yaml:2` |
| `40-ingress.yaml` | IngressRoute（Info/Investment 各 4 条，Knowledge 3 条） | `knowledge-app/deployment/bundle/40-ingress.yaml:2` |

NetworkPolicy 是**独立的第四份文件**，不在 `00-prerequisites.yaml` 内。

### 4.2 `deploy.py apply --component all` 的实际顺序

| 步骤 | 文件或动作 | 该步做什么 | 代码位置 |
| --- | --- | --- | --- |
| 0a | 外部对账（仅 Investment / Knowledge） | Investment：RabbitMQ vhost、Redis ACL、Knowledge active binding | `investment-app/deployment/deploy.py:75-83`；`knowledge-app/deployment/deploy.py:124-135` |
| 0b | Secret 门禁 | 检查 `release.external_secrets` 均已存在 | `investment-app/deployment/deploy.py:86-102` |
| 1 | `00-prerequisites.yaml` | SA / ConfigMap / Service | `deploy.py:235` |
| 2 | `30-network-policies.yaml` | **NetworkPolicy 先于 runtime** | `deploy.py:236` |
| 3 | `10-migration.yaml` | 删旧 Job →（Investment 另设 PG 角色）→ apply → 等完成 → 删 Job | `deploy.py:172-200,238`；角色 SQL `:141-169` |
| 4 | `20-runtime.yaml` | Deployment / PDB / HPA | `deploy.py:240` |
| 5 | `40-ingress.yaml` | IngressRoute | `deploy.py:241` |
| 6 | rollout status | 等 `deployment_replicas` 就绪 | `deploy.py:242-251` |
| 7 | legacy scale 0 | 缩容 `legacy_deployments` | `deploy.py:252-263` |
| 8 | 删旧 IngressRoute（仅 Investment） | `investment-r5-admin` / `investment-r5-web` | `deploy.py:265-275` |

三 App 差异：Info 无步骤 0a、无 PG 角色处理、无步骤 8（`info-app/deployment/deploy.py:182-215`）；
Knowledge 有 0a binding、无 PG 角色（`knowledge-app/deployment/deploy.py:197-231`）；步骤 1–7 顺序一致。
`server-dry-run all` 按 `release.json.resources` 数组顺序 dry-run（`deploy.py:136-137`），
**与 apply 的真实顺序不同**。

## 5. 发布输入与版本语义

| 字段 | 含义 | 真源位置 |
| --- | --- | --- |
| `schema_version` | 须为 `2` | `verify-formal-instance.py:47-48`；各 `release.json:2` |
| `architecture` | 须为 `app-platform-v2-formal` | `verify-formal-instance.py:49-50` |
| `logical_app` / `resource_app` | 业务名与 K8s 资源前缀 | 各 `release.json:4-5` |
| `namespace` | 目标命名空间 | 各 `release.json:6` |
| `release_id` | 发布标识；**三 App 构词不一致**（Investment `v20-investment-001`，Knowledge/Info 带 `-stable-`） | 各 `release.json:7` |
| `formal_release` | 须 `true` | `verify-formal-instance.py:51-52` |
| `images` | backend / admin / web 三个 digest | 各 `release.json:9-13` |
| `origins` | admin / web / casdoor 的 HTTPS 基址 | 各 `release.json:14-18` |
| `resources` / `sha256` | 五文件清单与内容哈希 | 各 `release.json:19-32` |
| `deployment_replicas` | 五个 Deployment 的副本契约 | 各 `release.json:33-39` |
| `ingress_routes` | IngressRoute 路由结构契约 | 各 `release.json:40-109` |
| `legacy_deployments` | 须缩容至 0 的旧 Deployment | 各 `release.json:110` |
| `external_secrets` | 集群须预先存在的 Secret 名 | 各 `release.json:111-120` |
| `forbidden_markers` | bundle 全文禁止出现的字符串 | 各 `release.json:122-127` |
| `renderer_inputs_sha256` | render 输入文件指纹 | 各 `release.json:129-137` |
| `contains_credentials` | 须 `false` | 各 `release.json:128` |
| `knowledge_binding` | **Investment 特有**：active retrieval Secret 名 | `investment-app/.../release.json:121` |
| `retrieval_dataset_allowlist`、`protected_provider_resources` | **Knowledge 特有** | `knowledge-app/.../release.json:19,114-116` |

重新生成 bundle 用各 App 的 `deployment/render.py`。

## 6. 门禁与验证脚本

| 脚本 | 它实际检查什么 | 位置 | 需要活集群 |
| --- | --- | --- | --- |
| `verify-formal-instance.py` | schema、sha256、digest 镜像、副本与 Ingress 契约、legacy 泄漏、forbidden 标记 | `app-platform/scripts/verify-formal-instance.py:42-145` | 否 |
| `deployment_config.py` + `formal_deploy_entry.py` | `.conf` 与 `release.json` 字段逐项一致、profile 是否启用 | `deployment_config.py:119-144` | `config` 否 |
| `deploy.py plan / server-dry-run / drift` | 调上述门禁，另加集群 API | 各 `deployment/deploy.py:61-64,377-395` | dry-run 起需要 |
| `verify_r7_release_kind.py` | 集群内副本、镜像 digest、config sha256、迁移 head、无残留 Job、formal Ingress 集、evidence JSON、Info outbox 静止 | `docs/architecture-v2/scripts/verify_r7_release_kind.py:197-334` | 是 |
| `verify_r6_cross_app_vertical_kind.py` | Info→Knowledge→Investment 真实链路（outbox、ingest、retrieve、replay） | `.../verify_r6_cross_app_vertical_kind.py:111-154,542-644` | 是 |
| `verify_r3_template_browser.mjs` | Playwright strict TLS + Casdoor 登录 | `.../verify_r3_template_browser.mjs:301-332` | 是 |
| `verify_r3_network_policy_calico.sh` | **另起一个 disposable Calico KIND**，做 packet 级 allow/deny | `.../verify_r3_network_policy_calico.sh:3-6,51-54` | 是（临时集群） |
| `verify_r5_info_candidate_kind.py` | 运行时 NetworkPolicy 是否被 CNI 执行，输出 `production_network_policy_gate_satisfied` | `.../verify_r5_info_candidate_kind.py:380-391,594` | 是 |
| `run_r7_instance_release_gate.sh` | 串起三 App formal apply+drift、浏览器、R6 纵切、R7 终检 | `.../run_r7_instance_release_gate.sh:56-80` | 是 |
| `run_r7_1_retirement_gate.sh` | legacy 退役、三 App drift、浏览器、R6、R7.1 终检 | `.../run_r7_1_retirement_gate.sh:35-69` | 是 |

**不存在一个统一的单入口门禁脚本**：静态检查与运行时检查分属不同脚本，包级网络策略验证还需另起集群。

## 7. 集群与基础设施

| 组件 | 在哪配置 | 说明 |
| --- | --- | --- |
| KIND 拓扑 | `kind-infrastructure/deploy-kind/kind-cluster.yaml:31-67` | 1 control-plane + 2 worker，节点镜像 `kindest/node:v1.27.3-sunmoonai` |
| KIND 端口 | `kind-cluster.yaml:34-44` | HTTP 30080→80；HTTPS 30443→30443 |
| KIND 存储 | `kind-infrastructure/manifests/storageclass-local-path.yaml:1-9` | `local-path` StorageClass |
| KIND CNI | 默认 kindnet，**不执行 NetworkPolicy** | `verify_r3_network_policy_calico.sh:4-5`；`verify_r5_info_candidate_kind.py:390` |
| 远程 CNI | `infrastructure/steps/step05_cni_install.sh:12` | 默认 `STEP05_CNI=calico` |
| 远程 bootstrap | `infrastructure/steps/step00_reset.sh` … `step13_ingress_and_harbor.sh` | 由 `deploy-infrastructure-all.sh:38-39` 编排 |
| 命名空间 | `infrastructure/steps/step07_create_namespaces.sh:56-58` | 受 `STEP07_ENABLED` 控制 |
| 总控部署顺序 | `deploy-sunmoonai-all/deploy-sunmoonai-all.sh:203-243` | infrastructure → ingress → cicd → data → app → messaging → ops |
| DB 角色与库供给 | `utils/db-provisioner/drivers/postgresql.sh:3-11` | `dbctl` 驱动；Investment 另在 `deploy.py:141-169` 改 PG 角色 LOGIN 状态 |
| Secret 占位生成 | `utils/prepare-secrets-from-examples.sh:16-26` | 从 `*/secrets/*.yaml.example` 复制 |
| Investment broker Secret | `prepare-investment-broker-kind.sh:11-12,50-51` | patch RabbitMQ definitions + 写 `investment-backend-broker` |
| TLS 与镜像拉取 Secret | 各 App `external_secrets` 含 `{app}-tls` 与 `harbor-registry-secret` | 例 `info-app/.../release.json:112-113` |

## 8. 已知未实现或易误解

| 容易被误认为的情况 | 实际情况 | 位置 |
| --- | --- | --- |
| `infrastructure/` 含 cert-manager 清单 | 该目录只有 `steps/`、`utils/`、`deploy-infrastructure-all/`、`docs/`；`rg cert-manager infrastructure/` 无匹配。TLS 由 Traefik + 各 App `*-tls` Secret 承担 | 目录 listing |
| 对象存储目录叫 minio 或 s3 | 实际目录名为 **`data-platform/object-storage/`** | `data-platform/object-storage/deploy-object-storage/deploy-object-storage.sh` |
| 构建脚本推 digest | **推可变 tag**（`docker push …:${TAG}`）；digest 由 `render.py` 写入 bundle，门禁只认 digest | `build-push-app-images.sh:108-158`；`render.py:191-204` |
| `production_network_policy_gate_satisfied` 是集群持久配置 | 是**门禁脚本 JSON 输出与 evidence 里的字段**；KIND 上常为 `false`（kindnet 不 enforce） | `verify_r5_info_candidate_kind.py:594`；`evidence/R5-info-baseline/candidate-runtime-gate.json:47` |
| 构建脚本默认覆盖四个 App | 默认 `APPS="info research knowledge"`，**不含 investment，且仍留 research** | `build-push-app-images.conf:42` |
| auth-app 与三正式 App 同模型 | auth-app 是 Casdoor Helm 部署，**无 `deployment/bundle/release.json`** | `auth-app/deploy-auth-app-all/deploy-auth-app-all.conf:1-4` |
| production profile 可直接部署 | 三 App 的 `production.conf` 均为 `PROFILE_ENABLED=false` | `investment-app/deploy-investment-app-all/profiles/production.conf:3` |
| `server-dry-run all` 顺序等于 apply 顺序 | dry-run 按 `resources` 数组；apply 在 migration 前先 apply NetworkPolicy | `deploy.py:136-137` vs `235-240` |
| R7 终检覆盖 NetworkPolicy 包级行为 | R7 查资源名、副本、digest；包级 Calico 验证是独立脚本 | `verify_r7_release_kind.py:287-297` |
