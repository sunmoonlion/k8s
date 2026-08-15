# 发布与门禁

> 最后更新：2026-08-15 ｜ 验证时点：2026-08-15
> 全部机制在 `k8s` 仓；细节与逐行位置见 [`../repos/k8s.md`](../repos/k8s.md) §4–§6。

## 1. 发布单元

一个 App 的一次发布 = 一份 `deployment/bundle/`，含**五份 YAML + 一份 `release.json`**：

| 文件 | 资源 kind |
| --- | --- |
| `00-prerequisites.yaml` | ServiceAccount、ConfigMap、Service |
| `10-migration.yaml` | Job |
| `20-runtime.yaml` | Deployment、PodDisruptionBudget、HorizontalPodAutoscaler |
| `30-network-policies.yaml` | NetworkPolicy（独立文件，不在 prerequisites 内） |
| `40-ingress.yaml` | IngressRoute |

`release.json` 是这次发布的**不可变输入**：镜像 digest、五文件的 sha256、副本数、
Ingress 路由结构、须预先存在的 Secret 名、禁止出现的字符串。字段全表见
[`../repos/k8s.md`](../repos/k8s.md) §5。

auth-app（Casdoor）不走这套模型，是 Helm 部署，无 bundle 与 release.json。

## 2. digest 纪律

**bundle 里只允许 `repo@sha256:…`，不允许可变 tag**
（`app-platform/scripts/verify-formal-instance.py:22-23,99-102`）。

但要注意链条的两端不一致：**构建脚本推的是可变 tag**
（`build-push-app-images.sh:108-158` 的 `docker push …:${TAG}`），
digest 是在 render 阶段被解析并写入 bundle 的（`<app>/deployment/render.py:191-204`）。
也就是说 tag 只是构建产物的临时把手，进入发布视野的一律是 digest。

`.conf` 配置文件**不得覆盖** bundle 里的镜像、副本、origin 等字段
（`deployment_config.py:119-144`），值必须与 `release.json` 完全一致，否则 `ConfigError` 退出码 2。
这条保证了「配置改不动发布内容」。

## 3. apply 的真实顺序

| 步骤 | 内容 |
| --- | --- |
| 0 | 外部对账（Investment / Knowledge 有，Info 无）+ 检查 `external_secrets` 全部存在 |
| 1 | `00-prerequisites.yaml` |
| 2 | **`30-network-policies.yaml`**（先于 runtime） |
| 3 | `10-migration.yaml`：删旧 Job → apply → 等完成 → 删 Job |
| 4 | `20-runtime.yaml` |
| 5 | `40-ingress.yaml` |
| 6 | 等五个 Deployment rollout |
| 7 | `legacy_deployments` 缩容至 0 |

逐行位置与三 App 差异见 [`../repos/k8s.md`](../repos/k8s.md) §4.2。

两个易错点：网络策略在迁移**之前**就 apply；`server-dry-run all` 按 `release.json.resources`
数组顺序走，**与 apply 的真实顺序不同**（`deploy.py:136-137` vs `:235-240`）。

## 4. 门禁是分层的，没有单一入口

| 层 | 脚本 | 需要活集群 |
| --- | --- | --- |
| 静态：schema、sha256、digest、副本与 Ingress 契约、禁用标记 | `app-platform/scripts/verify-formal-instance.py` | 否 |
| 静态：`.conf` 与 `release.json` 逐字段一致 | `deployment_config.py` + `formal_deploy_entry.py` | 否 |
| 集群态：副本、镜像 digest、迁移 head、无残留 Job、Ingress 集合、outbox 静止 | `docs/architecture-v2/scripts/verify_r7_release_kind.py` | 是 |
| 集群态：跨 App 纵切真实链路（info→knowledge→investment） | `verify_r6_cross_app_vertical_kind.py` | 是 |
| 浏览器：strict TLS + Casdoor 登录 | `verify_r3_template_browser.mjs` | 是 |
| 网络：NetworkPolicy 包级 allow/deny | `verify_r3_network_policy_calico.sh` | 是，**另起一个临时 Calico 集群** |
| 串联 | `run_r7_instance_release_gate.sh`、`run_r7_1_retirement_gate.sh` | 是 |

**不存在一个跑一次就全覆盖的门禁脚本。**尤其是网络策略：KIND 默认 kindnet 不执行
NetworkPolicy，所以包级验证必须另起 Calico 集群；
`production_network_policy_gate_satisfied` 是门禁脚本的 JSON 输出字段与 evidence 内容，
不是集群里的持久配置，KIND 上通常为 `false`。

## 5. 环境与 profile

| profile | 状态 |
| --- | --- |
| KIND 本地 | 可用，命名空间 `app-platform-dev` |
| C1 / production | 三 App 的 `profiles/production.conf` 均 `PROFILE_ENABLED=false`，直接部署会报 `deployment profile is disabled` |

正式发布也不可经默认入口执行 uninstall / cleanup（`formal_deploy_entry.py:80-83`）。

## 6. 资源命名稳定性

render 会把历史的 `*-r5` 前缀替换为稳定名（`<app>/deployment/render.py:300-307`），
且 bundle 文本中禁止出现 candidate / legacy 标记（`release.json.forbidden_markers`
+ `verify-formal-instance.py:131-133`）。
旧资源的退场是显式动作：`legacy_deployments` 缩容至 0，Investment 另删两条旧 IngressRoute。
