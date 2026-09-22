# 发布与门禁

> 更新：2026-09-20，本机 KIND 已切换固定开发候选及独立运行身份 ｜ 相关规则见 [`../../dev-agent/rules/constraints.md`](../../dev-agent/rules/constraints.md)「发布」C-R1–C-R7
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

**auth-app（Casdoor）不走这套 bundle 模型**——Helm 部署，无 bundle 与 release.json；
这不豁免正式制品的不可变性与可追溯要求。

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
   KIND 首次身份切换            核静止备份回执 → 激活独立 DB 身份 → 真实权限探针
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
| 集群态：副本 / digest / 迁移 head / 无残留 Job / Ingress 集 | 当前 release + 现场核验，未提供覆盖全部项目的新聚合器 | 是 |
| 集群态：跨 App 纵切真实链路 | 本次发布的真实 Provider 回执与业务结果 | 是 |
| 浏览器：strict TLS + 真实 Casdoor 登录 | 本次发布的双端真实旅程验收 | 是 |
| 网络：NetworkPolicy 包级 allow/deny | `app-platform/scripts/validation/verify_r3_network_policy_calico.sh` | 是，**另起临时集群** |

旧 R3/R6/R7 发布脚本随历史目录清退，原版本仍可从 Git 读取；旧 R7 检查写死旧迁移 head
并要求正式包，不能用于当前 KIND 开发包。不能因工具清退省略上述验收；工具移动后仅完成
离线回归，不冒充真实发布实测。

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
该 manifest 原文不随目录清理重写；`test_evidence` 中的旧路径按
[v5 历史索引](v5-history.md#architecture-v2-目录清退) 的固定提交查询。

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

## 7. 包版本、源码提交与已部署制品不能混同

以下标识承担不同职责；取值同为 `2.0.0` 不证明最新源码已经发布：

| 层 | 声明 |
| --- | --- |
| 代码 | 四个后端 `pyproject.toml` 与 `uv.lock` 均 `2.0.0`；八个前端 `package.json` 亦 `2.0.0`；`test_package_version_matches_the_formal_release` **主动断言**须与发布别名一致 |
| 当前开发 bundle | 三个 `release.json` 均 `formal_release: false`、目标 KIND；不把它们误认成 R7 正式发布 |
| 历史模板发布 | 模板 manifest 的正式发布声明只为其固定 tuple 背书，不能替后续开发提交背书 |

包版本与发布别名一致不是矛盾。判断部署必须核对对应提交、构建产物 digest、
冻结 bundle/manifest 与实际 Pod imageID，并关联该版本的门禁证据。
历史正式 manifest 不能为了同步开发提交而改写为尚未构建的新 HEAD。
当前 `kind-b7-20260919` 已按 Harbor digest 部署本机 KIND；云端仅同步源码，未部署。
镜像构建、Harbor 推送、bundle 生成和实际部署各自核验，不由 Git 同步自动完成。

复核包版本和历史发布声明（不能代替 live 核验）：
```bash
grep -h '^version' */[a-z]*-backend/app/pyproject.toml
python3 -c "import json;print(json.load(open('k8s/sunmoonai/app-platform/info-app/deployment/bundle/release.json'))['formal_release'])"
```

## 8. 当前 KIND 切换事实与剩余验收

数据库 API/Worker/Scheduler/Migration 权限策略、独立连接键与 broker 预声明拓扑候选
已在本机 KIND 完成 Info → Knowledge → Investment 串行切换：停写备份、每 App 两次
实际隔离恢复、独立迁移、运行身份授权与探针、新服务就绪后精确退出旧身份。
三个 head 分别为 `20260913_0009`、`20260911_0006`、`20260911_0007`；三个 App
API 2 / Worker 1 / Scheduler 1 / 两个前端各 2 就绪，drift 无差异。9 个新 DB 登录
跨 App 数据库的 18 次连接被拒绝；三个旧 DB 登录和旧 broker vhost 访问实际拒绝。
共享启动 definitions 同步撤权、非目标资源保持不变；未重启共享设施验证重启过程。
精确载荷摘要、固定提交与私有证据位置保存在 k8s
`547a8f6d83cc296a86a7604697057465620c7edc` 的
`sunmoonai/docs/tasks/B7-B9-closeout/thread/0001-imp-none/0015-none/others/preparation.md`；
它是历史切换回执，不是当前操作指令。

当前入口是一次性身份 bootstrap，不是既有角色通用协调器。退役后不能盲目重跑准备/
激活，或恢复旧权限来满足旧目录指纹；后续新版本须显式核对既有身份与新发布回执。
完整浏览器真实登录、跨 App Provider 回执、故障回滚/前滚和 Calico 包级门禁尚未闭合。
三 App `/api/version` 的 deploymentId 正确，但 version 为 `0+unknown`：镜像缺少
已安装的项目 distribution metadata；不能把它解释为 digest 漂移，也不能视为已修复。
运行探针、指标输出仍不等于已接监控告警；本次没有 production 晋级或云端部署。

---

**动发布、清镜像前**，先读 [`../../dev-agent/rules/constraints.md`](../../dev-agent/rules/constraints.md)「发布」——本页只写现状。
