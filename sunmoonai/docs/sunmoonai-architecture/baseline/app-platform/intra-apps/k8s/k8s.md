# k8s

> 仓库路径 `/home/zymun/k8s`。深读基线：2026-08-13（`sunmoonai/` 各平台部署编排、三个领域
> App 的部署 bundle）。App 之间的公共形态见 `baseline/app-platform/inter-apps/app-platform.md`。

## 1. 概要

sunmoonai 平台的**部署编排与治理仓**，不含任何 App 源码：KIND 集群上各平台的部署清单与
运维脚本 + 领域 App 的声明式部署 bundle、发布输入与验收门禁。源码在 ~/tpl-app、~/info-app、
~/knowledge-app、~/investment-app 独立维护。

### 顶层结构（`sunmoonai/` 九平台目录）

| 目录 | 内容 |
| --- | --- |
| `app-platform/` | 全部领域 App 的部署声明：auth-app（Casdoor，不套三仓模板）、info-app、knowledge-app、investment-app；`scripts/`（build-push-app-images.sh、verify-formal-instance.py 通用门禁、formal_deploy_entry.py/formal_component_deploy.py 正式部署入口、各 App render_*_release_base.py）；`docs/`（平台文档与历史记录） |
| `cicd-platform/` | harbor、jenkins |
| `data-platform/` | postgresql、redis、elasticsearch、minio、mongodb、neo4j、kibana、logstash |
| `infrastructure/` | 基础设施（cert-manager 等） |
| `ingress-platform/` | traefik（严格 TLS、高优先级 /api 路由） |
| `messaging-platform/` | rabbitmq |
| `kind-infrastructure/` | KIND 集群配置（长期 kindnet；一次性 Calico 集群用于报文级 NetworkPolicy 验证） |
| `ops-platform/`、`deploy-sunmoonai-all` | 运维与一键部署入口 |

### 运行与验证

每 App `deployment/bundle/` 五件套 YAML 按固定顺序部署；通用门禁
`app-platform/scripts/verify-formal-instance.py`；正式部署入口 `formal_deploy_entry.py`。
本仓 `sunmoonai/docs/sunmoonai-architecture/` 即本文档集（AGENTS.md / baseline/ /
requests/）的所在目录。

## 2. 重要点

1. **不含源码**：本仓只有部署声明与运维脚本；四个 App 源码各自独立仓维护。
2. **五件套 + 固定部署顺序**：prerequisites → migration → runtime → network-policies →
   ingress；**迁移失败不得继续部署运行角色**。
3. **release.json schema 2 只收 digest**：三镜像只收 `repository@sha256`，禁重构建打 tag、
   禁可变 tag；每文件 sha256 钉住。
4. **证据分层 L1-L7**：L1 静态 → L2 单元 → L3 契约 → L4 角色/DB 集成 → L5 配对 →
   L6 KIND/严格 TLS/真实 Casdoor/回滚 → L7 跨 App E2E；**smoke 通过不得宣称完成**。
5. **Calico 门禁诚实标记**：长期 kindnet 不执行 NetworkPolicy，不得伪报；一次性 Calico
   集群做报文级验证后删除，长期集群保留
   `production_network_policy_gate_satisfied=false`。
6. **数据库双角色**：`{app}_backend_user`（DML 无 DDL）+ `{app}_backend_user_migration`
   （唯一 DDL/owner）。
7. **auth-app 不套模板**：Casdoor 单独部署，提供 OIDC 但不替代各 Backend 的资源级授权。
8. **双远程纪律**：GitHub 权威、Gitee 镜像 SHA 对齐。

## 3. 架构

### 3.1 领域 App 部署 bundle 结构（每 App 一份，在 `{app}/deployment/` 下）

五件套 YAML 在 `deployment/bundle/`：`00-prerequisites.yaml`（ServiceAccount/Secret 引用/NetworkPolicy）、
`10-migration.yaml`（一次性 Job）、`20-runtime.yaml`（API/Worker/Scheduler + HPA/PDB）、
`30-network-policies.yaml`、`40-ingress.yaml`（严格 TLS、`/api` 高优先级 + `/` 低优先级双路由）；
加 `bundle/release.json`、`deployment/render.py`、`deployment/deploy.py`。资源名为稳定命名
（如 `info-backend-api`，无阶段/过渡后缀）。通用门禁：`app-platform/scripts/verify-formal-instance.py`。

部署顺序固定：prerequisite/secret/network -> migration -> runtime -> ingress；迁移失败不得
继续部署运行角色。

平台职责与依赖方向的权威定义见总体架构文档（`../../../sunmoonai/architecture.md`）；
本仓实现遵循同一原则：基础能力向上提供、领域所有权不向下泄漏，部署顺序≠运行时耦合。

### 3.2 发布输入与版本语义

每 App 发布输入 `deployment/bundle/release.json`（schema_version 2、architecture
`app-platform-v2-formal`）：logical_app/resource_app、namespace、release_id（如
`v20-{app}-stable-001`）、formal_release、三镜像 digest（只收 `repository@sha256`）、
每文件 sha256。

流程：源码仓构建不可变镜像 digest → 写入 release.json → 脚手架 render/deploy
（模板仓 `tpl-app/k8s-deployment`）→ 门禁通过后正式发布。三个领域 App 均为正式发布
2.0.0（formal_release=true）。禁止为正式版本重新构建再打 tag、禁止用可变 tag 替代 digest。

### 3.3 验收门禁与证据分层

**证据分层 L1-L7**：L1 静态 → L2 单元 → L3 契约 → L4 角色/DB 集成 → L5 配对 →
L6 KIND/严格 TLS/真实 Casdoor/回滚 → L7 跨 App E2E。smoke 通过不得宣称完成。

**每 App 门禁项**：隔离 KIND namespace、数据库角色 principal、HPA + PDB + NetworkPolicy、
严格 TLS 双端真实 Casdoor 验证、原生 `rollout undo` 回滚再前滚。双远端 GitHub 权威、
Gitee 镜像 SHA 对齐。

**Calico 门禁**：长期 KIND 用 kindnet（不执行 NetworkPolicy），不得伪报运行态通过；用一次性
`disableDefaultCNI:true` KIND + Calico 做报文级矩阵验证，验证后删除集群；长期 KIND 诚实保留
`production_network_policy_gate_satisfied=false`。

### 3.4 数据库角色模型

每 App 两个运行凭据：`{app}_backend_user`（DML 无 DDL）+ `{app}_backend_user_migration`
（唯一 DDL/owner）。数据所有权与迁移链规则见总体架构文档 §7
（`../../../sunmoonai/architecture.md`）。

### 3.5 边界与衔接

- auth-app（Casdoor）是身份提供方，不套三仓模板，单独部署；它提供 OIDC 但不替代各 Backend
  的资源级授权。
- 未来 research-app/tools-app 必须从已验收模板全新实例化，不从历史目录复制。
- 当前集群为 KIND 开发环境（namespace `app-platform-dev`），生产 NetworkPolicy 门禁由一次性
  Calico 集群单独闭合。

## 4. 关联

- 九大平台之间的职责与依赖：`../../../sunmoonai/architecture.md`
- App 之间的公共形态与契约治理：`../../inter-apps/app-platform.md`
- 各 App 源码内部架构：`../tpl-app/tpl-app.md`、`../info-app/info-app.md`、
  `../knowledge-app/knowledge-app.md`、`../investment-app/investment-app.md`
- 平台部署文档与历史记录：本仓 `sunmoonai/app-platform/docs/`
