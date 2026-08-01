# ADR-017：模板先行与三实例立即收敛门禁

状态：ACCEPTED
日期：2026-07-22
决策者：项目负责人、架构评审

## 1. 背景

此前计划让 Admin/Next Web 模板先取得迁移资格，但把三个业务 App 的基础替换留到
Gate P0 之后的 M1-411/M1-413。这会产生两个问题：

1. 模板继续演进，而 Info/Knowledge/Research 长期停留在旧 Vue、旧 Next、旧认证或不同
   基础设施版本，后续业务代码继续建立在即将被替换的底座上。
2. 模板缺陷只能在很晚的业务迁移中暴露，修复后又要二次回流模板、二次同步三仓，增加
   漂移、返工和回滚组合。

项目负责人明确要求：模板是代码开发的前置基础；模板完成后必须立即同步三个实例，实例
收敛后才能继续业务与 Agent 主链开发。

## 2. 决策

### 2.1 模板先行硬门

当前唯一开发主线保持在 `tpl-app`，直至以下默认组件形成同一个可追溯模板发布清单：

```text
tpl-admin-frontend   Next App Router / Node standalone
tpl-admin-backend    FastAPI Admin
tpl-web-frontend     Next App Router / Node standalone
tpl-web-backend      FastAPI Web BFF（默认）
```

`tpl-web-backend-nest` 同期完成为受维护可选 profile，但三个业务 App 不采用它作为主线。
`tpl-admin-frontend-react` 是 ADR-018 固定的 legacy/reference，也不进入业务实例。
`tpl-app` 父仓的初始化、命名替换、配置生成、子模块 URL/gitlink 和部署接口也属于模板
release 控制面，必须能从干净目录生成上述组件，不能只验收四个子仓各自可构建。
模板发布清单必须固定各子仓 commit、父仓 gitlink、contract/schema version、依赖锁、镜像
digest、生成/迁移清单、兼容矩阵和回滚步骤。任何组件只有骨架、工作树未提交或仅 smoke
通过时，都不构成“模板完成”。

在模板发布清单冻结前，只允许：

- P0-007D/E、P0-008B/B6 所需的模板代码、契约、测试、证据和阻断修复；
- 为提取通用能力而只读审计三个业务 App；
- 修复会阻断模板构建、安全或迁移的 P0 缺陷。

禁止在三个业务 App 新增普通产品功能、扩建 Agent 主链、分别修补模板级能力或提前切换
技术栈。

### 2.2 模板完成后的“立即同步”

P0-007E 与 P0-008B/B6 全部接受后，下一任务必须是 P0-009，不得在其间插入 P0-008C、
M1 产品功能、Memory/Subagent、Provider 扩展或其他非阻断开发。P0-009 按以下顺序串行：

1. P0-009A：冻结统一 template release manifest、三仓迁移/保留/删除清单和回滚基线。
2. P0-009B：Info 全部默认模板组件原地收敛并验收。
3. P0-009C：Knowledge 全部默认模板组件原地收敛并验收。
4. P0-009D：Research 全部默认模板组件原地收敛并验收。
5. P0-009E：跨三仓漂移、clean-room、配对 contract 和回滚总门禁。

“立即”指依赖上的紧邻关系，不表示同时覆盖三个 App，也不允许省略逐仓验证。任一实例
失败只回滚该实例并停止后续实例；前一实例未接受，不开始下一实例。

### 2.3 同步的技术语义

同步不是对所有目录做无条件文件覆盖：

- Frontend：在现有子仓原地替换共同基础，保留并重新接入领域 route/page/DTO；通过映射
  清单区分模板文件、实例配置和业务扩展点。
- Backend：同步经验证的配置、日志、错误、数据库/Alembic、Redis、OIDC、Principal、
  CSRF/CORS、服务身份、审计、health/readiness、测试、Docker/Kubernetes 等通用内核；
  保留各 App 的领域模型、表、migration 历史、API、worker 和数据所有权。
- Web：三个实例只采用 FastAPI 默认 Web Backend；Admin/Web audience、cookie、session
  namespace、ServiceAccount 和 release tuple 继续分离。
- K8s：使用候选 Deployment/隔离 Host 验证，不覆盖稳定 tag，不以基础同步自动切流量。

每个实例必须先创建迁移前 Git tag，记录当前镜像 digest、数据库 revision、环境/config
schema、route/API 清单和恢复命令；实例提交必须记录 `template_release_id` 与四个模板源
commit。禁止从任一业务 App 反向复制整树成为模板来源。

### 2.4 同步完成与业务解锁

P0-009 的完成条件是三个 App 的共同底座均可从同一模板 release 追溯，独立构建、单元/
contract 测试、Frontend/Backend 配对 E2E、Docker/KIND、配置负向、migration compatibility、
父仓 clean-room 实例化、漂移检查和逐实例回滚全部通过。
三个 App 全部满足时状态命名为 `INSTANCE_FOUNDATION_ALIGNED`；任一 App 未通过时 P0-009
保持 `IN_PROGRESS`，不得用部分收敛解锁业务开发。

基础同步不等于完整业务等价、生产流量切换或旧实现删除：

- P0-009 后才允许 P0-008C 在已收敛的 Research 基线上做真实 Run/SSE/HITL/citation 试点。
- M1-411B/C/D 和 M1-413A/B/C 继续负责完整业务 route 等价、产品能力、canary/切流和旧
  Vue/旧 Web 退出；它们不得再次替换共同底座。
- P0-009 未接受前，M1a、M1a.5 和其他新增业务功能保持锁定。

### 2.5 后续模板升级纪律

本次一次性收敛后，任何模板通用变更仍必须遵循：模板先修复并发布新
`template_release_id`，再按 Info -> Knowledge -> Research 串行传播；不得先在某个业务
App 修复后长期不回流。紧急安全修复可缩短门禁，但不能绕过来源、测试和回滚记录。

## 3. 对既有任务的影响

1. P0-008 的执行顺序调整为 `P0-008A -> P0-008B -> P0-009 -> P0-008C`；编号不表示
   可以跳过依赖。
2. 原 M1-411A“固定模板替换三个 App 基础前端”职责并入 P0-009，标记
   `SUPERSEDED_BY_P0_009`。
3. M1-411B/C/D 保留为 Admin 领域页面等价、切流和退出旧 Vue/React Router；
   M1-413 保留为三个 Web
   的业务等价、真实配对和切流，不再承担共同基础首次同步。
4. Gate P0 新增 P0-009 ACCEPTED，且 P0-008C 必须使用 P0-009 已收敛的 Research 基线。

## 4. 拒绝的替代方案

1. **等 Gate P0 后再同步模板**：拒绝。会允许新代码继续建立在旧底座上。
2. **三个 App 同时批量覆盖**：拒绝。无法隔离失败和证明逐实例回滚。
3. **只同步前端，不同步配对后端**：拒绝。身份、契约和发布 tuple 会继续错配。
4. **用模板整树覆盖领域 Backend**：拒绝。会破坏领域代码、migration lineage 和数据所有权。
5. **同步完成即切正式流量或删除旧镜像**：拒绝。基础收敛与业务等价/切流是不同门禁。

## 5. 接受条件

ADR-018 再次修订当前游标：B5 接受后先执行 P0-007D/E，再执行 P0-008B/B6；两条模板
门全部接受后必须进入 P0-009，P0-009 完成后才能进入 P0-008C 和后续业务开发。
