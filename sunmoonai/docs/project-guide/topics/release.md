# 发布与门禁

> 取证时点：2026-08-29 ｜ 相关规则见 [`../../dev-plan/constraints.md`](../../dev-plan/constraints.md)「发布」R1–R7
> 逐行位置见 [`../repos/k8s.md`](../repos/k8s.md) §4–§5

## 1. 发布单元

一个 App 的一次发布 = 一份 `deployment/bundle/`，含**五份 YAML + 一份 `release.json`**：

| 文件 | 资源 kind |
| --- | --- |
| `00-prerequisites.yaml` | ServiceAccount · ConfigMap · Service |
| `10-migration.yaml` | Job |
| `20-runtime.yaml` | Deployment · PDB · HPA |
| `30-network-policies.yaml` | NetworkPolicy（**独立文件**） |
| `40-ingress.yaml` | IngressRoute |

`release.json` 是这次发布的**不可变输入**：镜像 digest、五文件 sha256、副本数、
Ingress 路由结构、须预先存在的 Secret 名、禁止出现的字符串、renderer 输入指纹。

**auth-app（Casdoor）不走这套模型**——Helm 部署，无 bundle 与 release.json。

## 2. digest 纪律

**bundle 里只允许 `repo@sha256:<64hex>`，不允许可变 tag**
（门禁正则 `^[^\s]+@sha256:[0-9a-f]{64}$`）。

但链条两端不一致，这点必须知道：

```
构建脚本 docker push …:${TAG}   ← 推的是可变 tag
        ↓
render.py 解析出 digest 写入 bundle
        ↓
门禁只认 digest
```

即 **tag 只是构建产物的临时把手，进入发布视野的一律是 digest。**

唯一例外是**正式发布别名**：`2.0.0` 由 R7 打给已过门禁的 digest
（`release_policy.promotion_method: exact-digest-alias`），`1.0.0` 同理属于 v1。
这两个 tag 是发布制品的名字，不是构建把手——
`build-push-app-images.sh` 会**拒绝**推到它们上面（`PROTECTED_TAGS`），
除非显式 `ALLOW_PROTECTED_TAG=true`。本地构建的默认 tag 是 `architecture-v2-dev`。

`.conf` 配置文件**不得覆盖** bundle 里的镜像、副本、origin 等字段，
值必须与 `release.json` 完全一致，否则 `ConfigError`。这条保证了「配置改不动发布内容」。

## 3. apply 的真实顺序

```
0  external_secret_gate         检查 external_secrets 全部已存在
1  00-prerequisites.yaml
2  30-network-policies.yaml     ← 网络策略先于迁移
3  10-migration.yaml            删旧 Job → apply → 等完成 → 删 Job
4  20-runtime.yaml
5  40-ingress.yaml
6  rollout status（按 deployment_replicas 逐个等）
7  legacy_deployments 缩容至 0
```

**三个易错点**：

1. 网络策略在**迁移之前**——按直觉顺序手工部署会留下无策略窗口。
2. `server-dry-run` 按 `release.json.resources` 数组顺序走，**与 apply 顺序不同**。
3. `drift` 只比对 `STEADY_FILES` 四份（**不含 `10-migration`**，Job 跑完即删）。

## 4. 门禁是分层的，没有单一入口

| 层 | 脚本 | 需活集群 |
| --- | --- | --- |
| 静态：schema / sha256 / digest / 标签 / 禁用标记 | `app-platform/scripts/verify-formal-instance.py` | 否 |
| 静态：`.conf` 与 `release.json` 逐字段一致 | `deployment_config.py` + `formal_deploy_entry.py` | 否 |
| 集群态：副本 / digest / 迁移 head / 无残留 Job / Ingress 集 | `verify_r7_release_kind.py` | 是 |
| 集群态：跨 App 纵切真实链路 | `verify_r6_cross_app_vertical_kind.py` | 是 |
| 浏览器：strict TLS + 真实 Casdoor 登录 | `verify_r3_template_browser.mjs` | 是 |
| 网络：NetworkPolicy 包级 allow/deny | `verify_r3_network_policy_calico.sh` | 是，**另起临时集群** |

**smoke 通过 ≠ 发布完成。**smoke 只覆盖一条路径；上表六层缺一层就不算发过。
证据也要分层留：静态层留 sha256 与 digest，集群层留副本/迁移 head/Ingress 集，
浏览器层留真实登录，网络层留另起集群的 allow/deny 结果——
**用低层证据替高层结论，是这套门禁最常见的绕过方式。**

**不存在一个跑一次就全覆盖的门禁脚本。**尤其是网络策略：KIND 默认 kindnet
**不执行 NetworkPolicy**，所以包级验证必须另起 Calico 集群；
`production_network_policy_gate_satisfied` 是门禁脚本的输出字段，不是集群里的持久配置，
在 KIND 上通常为 `false`。

## 5. 模板发布与实例同步

模板自身有一套独立的发布锁：`tpl-app/template-release-manifest.json`
（schema 2）+ `verify_template_release.py`，锁定三个组件的 commit / tree / digest。

**实例同步顺序锁定为 `info → knowledge → investment`。**

变更顺序固定（约束第 12 条「模板优先」）：

```
模板设计与实现 → 模板过门禁 → 冻结 release manifest
  → Info → Knowledge → Investment 串行同步 → 每个实例独立验收
```

**公共缺陷必须先修模板、过门禁，再同步实例**；不得先改实例，也不得用模板覆盖实例的领域代码。

## 6. 环境与 profile

| profile | 状态 |
| --- | --- |
| KIND 本地 | 可用，命名空间 `app-platform-dev` |
| C1 / production | 三 App 的 `profiles/production.conf` 均 `PROFILE_ENABLED=false`；直接部署报 `deployment profile is disabled` |

正式发布也不可经默认入口执行 uninstall / cleanup。

## 7. ⚠ 一处未澄清的矛盾

**代码层被测试强制钉死为候选版本，部署层却宣称正式发布：**

| 层 | 声明 |
| --- | --- |
| 代码 | 四个后端 `pyproject.toml` 与 `uv.lock` 均 `2.0.0`；八个前端 `package.json` 亦 `2.0.0`；`test_package_version_matches_the_formal_release` **主动断言**须与发布别名一致 |
| 部署 | 三个 `release.json` 全部 `formal_release: true`；模板 manifest `status: FORMAL_RELEASE`、`template_release: 2.0.0` |

两者取值互相矛盾，且有测试**阻止**代码层追平部署层。
**在澄清之前，不要依据任何一侧断言"本项目已正式发布"。**

复核：
```bash
grep -h '^version' */[a-z]*-backend/app/pyproject.toml
python3 -c "import json;print(json.load(open('k8s/sunmoonai/app-platform/info-app/deployment/bundle/release.json'))['formal_release'])"
```

---

**动发布、清镜像前**，先读 [`../../dev-plan/constraints.md`](../../dev-plan/constraints.md)「发布」——本页只写现状。
