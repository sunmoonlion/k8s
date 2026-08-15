# 全局地图

> 最后更新：2026-08-15 ｜ 验证时点：2026-08-15
> 目的：一屏看清五仓分工、平台构成与依赖方向。细节不在本文件，按表中指针跳转。

## 1. 五个 Git 仓

| 仓 | 角色 | 含业务源码 | 详见 |
| --- | --- | --- | --- |
| `tpl-app` | 模板仓，其余三个 App 从它实例化；另含 K8s 部署脚手架 | 是（模板） | [`repos/tpl-app.md`](repos/tpl-app.md) |
| `info-app` | 信息域：采集、文档版本、去重、向 knowledge 分发 | 是 | [`repos/info-app.md`](repos/info-app.md) |
| `knowledge-app` | 知识域：摄入、索引、检索；两套契约的 provider | 是 | [`repos/knowledge-app.md`](repos/knowledge-app.md) |
| `investment-app` | 投资研究与智能体域；检索契约的 consumer | 是 | [`repos/investment-app.md`](repos/investment-app.md) |
| `k8s` | 部署编排；正式 bundle 与门禁脚本；本文档集也在此 | **否** | [`repos/k8s.md`](repos/k8s.md) |

每个 App 父仓固定三个子模块：backend、admin-frontend、web-frontend（各仓 `.gitmodules:1-9`）。
`k8s` 仓的 render 脚本引用与它同级的 `../tpl-app/k8s-deployment`
（`sunmoonai/app-platform/investment-app/deployment/render.py:120`），因此五仓需并列放置。

## 2. 依赖方向

```text
info-app ──分发 artifact v1──▶ knowledge-app ──检索 retrieval v1──▶ investment-app
                                     ▲
tpl-app ──模板实例化──▶ 三个 App      │ 都经 Casdoor（auth-app）取身份
                                      │
k8s ──构建镜像 / 渲染 bundle / apply──▶ 三个 App 的运行态
```

- 没有反向依赖：knowledge 不调 info，info 不调 investment。
- 契约的 provider 一律是被调方；锁文件放在 consumer 仓。见 [`shared/contracts.md`](shared/contracts.md)。
- 实例同步顺序锁定为 `info → knowledge → investment`（`tpl-app/verify_template_release.py:77`）。

## 3. 平台构成

`k8s` 仓 `sunmoonai/` 下实际有**八个平台目录**与三个非平台目录（`ls sunmoonai/`）：

| 目录 | 装什么 | 命名空间 | 配置真源 |
| --- | --- | --- | --- |
| `app-platform/` | 三 App 正式 bundle + auth-app（Casdoor）+ 共享脚本 | `app-platform-dev` | `app-platform/*-app/deployment/bundle/` |
| `data-platform/` | postgresql、redis、mongodb、neo4j、elasticsearch、kibana、logstash、object-storage | `data-platform-dev` | 各子目录的 `deploy-*` 脚本 |
| `messaging-platform/` | RabbitMQ（Celery broker） | `messaging-platform-dev` | `messaging-platform/rabbitmq/` |
| `ingress-platform/` | Traefik Helm 与 CRD，TLS 终止 | `ingress-platform-dev` | `ingress-platform/` |
| `cicd-platform/` | Harbor 镜像仓库、Jenkins | `cicd-platform-dev` | `cicd-platform/` |
| `ops-platform/` | pgAdmin、RedisInsight 等运维 UI | `ops-platform-dev` | `ops-platform/` |
| `infrastructure/` | 远程 kubeadm 分步脚本（OS → CNI → 命名空间 → Harbor） | — | `infrastructure/steps/step00…step13` |
| `kind-infrastructure/` | 本地 KIND 集群定义与节点镜像 | — | `kind-infrastructure/deploy-kind/kind-cluster.yaml` |
| `deploy-sunmoonai-all/` | 全平台总控（非平台） | — | `deploy-sunmoonai-all.sh` / `.conf` |
| `utils/` | db-provisioner 等跨平台工具（非平台） | — | `utils/db-provisioner/` |
| `docs/` | architecture-v2 门禁与 evidence；本文档集（非平台） | — | `docs/` |

命名空间取自 `deploy-sunmoonai-all/deploy-sunmoonai-all.conf:66-92`。

**部署优先级**在 `deploy-sunmoonai-all.conf:50-56` 定义（数值越大越先）：
infrastructure 1000、data 700、messaging 500、app 450、ops 400。
`ingress_platform_priority`（900）与 `cicd_platform_priority`（800）两行**被注释掉**（`:51-52`），
其生效值须查 `deploy-sunmoonai-all.sh`。脚本自身的平台遍历顺序见 `deploy-sunmoonai-all.sh:203-243`，
与优先级不是同一件事，勿混。

## 4. 一个 App 在集群里长什么样

每个 App 部署出**五个 Deployment**（backend-api、backend-worker、backend-scheduler、
admin、web），副本数由 `release.json.deployment_replicas` 锁定；
迁移是一次性 Job，跑完即删。资源清单分五份文件，apply 顺序见
[`repos/k8s.md`](repos/k8s.md) §4.2 与 [`shared/release.md`](shared/release.md)。

后端四种进程角色共用同一个镜像，靠 bootstrap 入口区分
（例 `tpl-app/tpl-backend/app/app/bootstrap/{api,worker,scheduler,migration}.py`）。

## 5. 跨仓共同规则去哪读

| 我关心 | 读 |
| --- | --- |
| 契约怎么定、锁文件在哪、双端怎么测 | [`shared/contracts.md`](shared/contracts.md) |
| 登录、scope、服务间调用凭据 | [`shared/identity.md`](shared/identity.md) |
| 库归属、双角色、迁移纪律、派生系统 | [`shared/data.md`](shared/data.md) |
| digest 纪律、bundle、门禁分层 | [`shared/release.md`](shared/release.md) |
| 四仓共同的目录与代码约定 | [`shared/conventions.md`](shared/conventions.md) |
