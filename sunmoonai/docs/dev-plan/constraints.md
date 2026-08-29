# 开发必须遵守的规则

> 最后更新：2026-08-29
>
> **动代码前先读这里。**违反其中任一条的方案**不进入讨论**——不是"不推荐"，
> 是不提出。
>
> 项目现在长什么样，见 [`../project-guide/`](../project-guide/)；
> 要建什么见 [`development-plan.md`](development-plan.md)，
> 具体任务见 [`implementation-plan.md`](implementation-plan.md)，
> 当前状态见 [`handoff.md`](handoff.md)。

## 怎么用

不必每次通读。按**你要动什么**取对应的组，把相关条目和结论写出来：

| 你要动 | 读哪节 |
| --- | --- |
| 表、迁移、存储 | [数据](#数据) |
| 跨 App 接口、契约 | [契约](#契约) |
| 登录、权限、服务间调用 | [身份](#身份) |
| 仓库、组件、运行角色 | [拓扑](#拓扑) |
| 部署、发版、镜像 | [发布](#发布) |
| 智能体 | [智能体](#智能体) + [`agent-discipline.md`](agent-discipline.md) |

对照结果就是一张小表，两三行即可：

| 规则 | 结论 |
| --- | --- |
| 接口分面共享 application 用例 | ✅ 共享 `PilotService`，只在 interfaces 层分身份 |
| 单一主档 | ✅ 不新增状态 |

**不相关的不必列；相关的漏列一条，方案就得重提。**

**「谁在执行」那一栏是重点。**标 ⚠ 的没有自动载体——它只是约定，会漂，
只能靠这个自检和评审守住。

---

## 数据

| # | 规则 | 谁在执行 |
| --- | --- | --- |
| D1 | **每类业务数据只有一个权威主档**，其余存储只保存引用、快照或可重建副本 | ⚠ 自检 |
| D2 | 每个 App 收敛**一个逻辑数据库、一条迁移链**；禁止跨 App 合并数据库或直接读表 | `check-cross-repo.py` 无跨 App 建表 |
| D3 | 物理资源可共享（同一 PostgreSQL 集群），但必须独立逻辑库、角色、Secret | 部署清单 + 凭据检查 |
| D4 | 对象存储按领域拥有：Bucket、凭据、生命周期必须隔离；**不以共享宿主机目录作交换协议** | `check-cross-repo.py` 无 hostPath |
| D5 | **RAGFlow 是可重建的派生系统**，不保存唯一原文 | ⚠ 自检 |
| D6 | 迁移链单链线性，恰好一个 `down_revision = None` | `test_kernel_invariants.py` |
| D7 | 改迁移**必须同步改** `test_kernel_invariants.py` 里那份文件名清单 | 该测试逐字比对 |
| D8 | 迁移由**独立 Job** 执行，API / Worker / Scheduler 启动**不得**隐式升级数据库 | `check-cross-repo.py` 启动不隐式迁移 |
| D9 | 前端**不得**持有后端或数据库凭据 | `core/config.py` 启动期校验 |

### 做数据迁移时

```
expand → backfill → reconcile → switch read → switch write → observe → contract
```

- 迁移前先出清单：表、约束、索引、revision、数据量、所有者、Secret、备份、消费者
- **旧写路径切换必须 fail-closed**，不得无期限双写
- 必要的双写必须有事务 Outbox、幂等、版本与对账，且有明确截止任务
- 回滚窗结束前保留旧库备份、旧角色定义与恢复演练证据

六条验收，缺一不可：可恢复备份 + 实际恢复演练 · 回填计数与业务不变量对账 ·
新旧读路径结果对比 · 旧凭据在切换后被拒绝 · `migration current` 只有一个 head ·
回滚与重新前滚均通过。

**这一整节 ⚠ 无自动载体**——是程序，静态查不出来。

## 契约

| # | 规则 | 谁在执行 |
| --- | --- | --- |
| C1 | 即时查询走**版本化同步 API**，长耗时走事件；事件经 Transactional Outbox 发布 | ⚠ 自检 |
| C2 | 接 Outbox 的消费者必须实现**幂等、死信、重放、周期性对账**——四项缺一，Outbox 只是个表 | ⚠ 自检 |
| C3 | schema 真源在 **provider** 仓，consumer 只持锁文件。两处都改会产生第二真源 | 双端 `test_provider_contract_lock_matches_authoritative_schemas` |
| C4 | 改契约必须**双端一起测**——单仓 CI 只跑自己那半，provider 改了、consumer 锁没跟，两边各自都绿 | `check-cross-repo.py` 双端契约测试 |
| C5 | 契约 DTO `extra=forbid`，未声明字段一律拒收 | Pydantic 模型 |
| C6 | citation `source_href` 全平台同形 `/api/web/v1/citations/{id}/source`，共七处，改一处必须七处一起改 | 双端路由表比对测试 |

## 身份

| # | 规则 | 谁在执行 |
| --- | --- | --- |
| I1 | **Admin / Web / Internal 是接口分面，不是三套应用层**——分面在 interfaces 层，共享 application 用例 | ⚠ 自检 |
| I2 | Internal API 按**提供方能力**命名（`ingestions`、`retrievals`、`citations`），**不按调用方命名** | ⚠ 自检 |
| I3 | 浏览器身份与服务身份**互不通用**；浏览器、服务、数据库凭据**禁止复用** | `check-cross-repo.py` 受管凭据不复用 |
| I4 | Next.js **可以**承担浏览器同源 BFF / session 边界，但**不得成为领域数据所有者** | ⚠ 自检 |
| I5 | session / BFF 与 FastAPI 的授权分工**必须有显式契约**；Backend 必须自行复核资源所有权、Origin/CSRF、租户与工具权限——**不信任任何上游声明的身份** | ⚠ 自检 |
| I6 | 非安全方法必须**同时**满足 `Origin ∈ frontend_origins` **且** CSRF token 匹配 | 中间件 |
| I7 | 服务令牌 subject 必须命中 `service_auth_subject_bindings` 的精确键；下游调用路径必须命中 allowlist 前缀 | `core/config.py` + 依赖 |
| I8 | 生产期约 35 处配置硬校验：**配错则进程起不来**，不是运行期降级 | `core/config.py` |

## 拓扑

| # | 规则 | 谁在执行 |
| --- | --- | --- |
| T1 | 按**长期业务领域**划分 App，不按页面或部署组件划分 | ⚠ 自检 |
| T2 | **每个领域 App 只有一个规范 Backend** | ⚠ 自检 |
| T3 | **一个 Backend 代码库按运行角色部署**（API / Worker / Scheduler / Migration）；模板组件不定义领域边界，运行角色不等于领域服务 | ⚠ 自检 |
| T4 | 父仓**不得出现悬空 gitlink**——子仓提交没推，别人克隆父仓会拉不到 | `check-cross-repo.py` gitlink 可达 |

### 什么时候才拆出专用 Worker

默认每个 App **只有一个通用 Worker**。满足下列任一条才拆，且要有证据
（队列延迟、运行时长、资源、失败率、权限证据），不是预感：

1. 浏览器、GPU、沙箱等依赖**显著扩大攻击面或镜像体积**
2. 任务时长、重试或取消语义**显著不同**
3. 需要**独立网络 / 服务身份**
4. 有**持续容量指标**支持独立扩缩容
5. 故障隔离**无法**通过队列和 Pod 边界实现

## 发布

| # | 规则 | 谁在执行 |
| --- | --- | --- |
| R1 | 源码、镜像、部署与数据基线**共同发布**；仅靠 Git 标签不能恢复运行环境 | ⚠ 自检 |
| R2 | bundle 只允许 `repo@sha256:<64hex>`，**不允许可变 tag** | 门禁正则 + `check-cross-repo.py` |
| R3 | 部署 bundle 的 digest 必须与发布清单一致——晋级靠打别名，**禁止重新构建** | `check-cross-repo.py` digest 一致 |
| R4 | `.conf` **不得覆盖** bundle 里的镜像、副本、origin，值须与 `release.json` 完全一致 | `ConfigError` |
| R5 | `1.0.0` / `2.0.0` 是发布 tag，本地构建脚本**不得**推上去 | `build-push-app-images.sh` 的 `PROTECTED_TAGS` |
| R6 | **模板优先**：公共能力先进模板过门禁，再完整同步实例；**不得先改实例** | ⚠ 自检 |
| R7 | 源码版本（`pyproject.toml` + `uv.lock`、`package.json`）必须与发布版本一致 | `test_package_version_matches_the_formal_release` |

### 改模板、同步实例时

- 同步顺序**串行固定**：Info → Knowledge → Investment。**一个实例失败不得推进下一个**
- 「完整同步」包含：工程、认证、授权、错误、日志、审计、配置、任务、存储、UI 通用能力
- **实例领域代码用显式 extension point / overlay 保留，禁止清空覆盖**
- 每个实例出**模板对齐报告**，差异分四类：领域扩展 · 配置 · 暂时兼容 · **违规漂移**
- 每个实例独立完成静态、单元、契约、配对、KIND、身份与回滚测试
- 父仓 gitlink 与 release manifest 必须一致

### 清理镜像时

- 删除保护 release、live、evidence、rollback 及其 OCI 引用闭包
- 删除前**重新采集**工作负载现状，执行 **dry-run** 并做**人工审计**；删除后才 GC
- 本地镜像只有在 Harbor 按 digest 可恢复、且 KIND 不再依赖本地候选后才能清理
- **旧架构资产在观察窗结束前不得删除**

### 一条环境事实

**KIND 默认不执行 NetworkPolicy**（kindnet 不 enforce）。包级验证必须另起
Calico 集群，否则"测过了"是假的。

## 智能体

| # | 规则 | 谁在执行 |
| --- | --- | --- |
| A1 | 分**通用**（执行编排）与**专用**（领域），新增业务智能体优先是新增一份 Profile，不是 fork 一套代码 | ⚠ 自检 |
| A2 | **两边都要有纪律**，不存在"通用部分不需要约束" | [`agent-discipline.md`](agent-discipline.md) |
| A3 | 四本账（预算 / 幂等 / 副作用 / 证据）**必须落 PostgreSQL**——跨 run、跨进程死亡仍须正确的不变量，必须由存储承担 | ⚠ 自检 |
| A4 | 执行层**租用不自建**，依赖边界严格限定在 SDK，不得直接依赖裸协议 | ⚠ 自检 |
| A5 | 领域概念**不得进入 Port 签名**（`run(sql, limit)` 可以，`run_portfolio_query(持仓ID)` 不可以） | ⚠ 自检 |

---

## 保证这些被遵守的三层

| 层 | 覆盖 | 在哪 |
| --- | --- | --- |
| **指针** | 全部 | 五仓根 `AGENTS.md`、`.cursor/rules/`、八个组件 `CLAUDE.md`（**进目录自动注入**） |
| **自检** | 全部 | 上面「怎么用」那节 |
| **检查** | 标了载体的那些 | 同目录 [`check-cross-repo.py`](check-cross-repo.py)（7 条，约 5 秒）、四仓 `test_kernel_invariants.py`、`../working/check-docs.py` |

**只有第三层不依赖人。**前两层是纪律，纪律会被忘——这份文件本身就出过两次
"规则在眼前却没回头对照"：一次提出了违反 D1 与 I1 的方案，一次把 I4 说反了
（断言不能用 BFF，实际是可以用、只是不能拥有数据）。

**所以：一条规则如果能机械判定，就别停在文字上。**

推送前跑一次：

```bash
python3 k8s/sunmoonai/docs/dev-plan/check-cross-repo.py --repos <五仓父目录>
```
