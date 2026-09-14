# 开发必须遵守的规则

> 迁自 [`dev-plan/constraints.md`](../../dev-plan/constraints.md) 的以下各节（`49d4ecb7`，2026-09-14）。节号沿用原文件；原文件其余各节的去向见 [MIGRATION.md](../MIGRATION.md)。

> 最后更新：2026-08-29
>
> **动代码前先读这里。**违反其中任一条的方案**不进入讨论**——不是"不推荐"，
> 是不提出。
>
> 项目现在长什么样，见 [`../project-guide/`](../../project-guide/)；
> 要建什么见 [`development-plan.md`](../../dev-plan/development-plan.md)，
> 具体任务见 [`implementation-plan.md`](../../dev-plan/implementation-plan.md)，
> 当前状态见 [`handoff.md`](../../dev-plan/handoff.md)。

## 怎么用

不必每次通读。按**你要动什么**取对应的组，把相关条目和结论写出来：

| 你要动 | 读哪节 |
| --- | --- |
| 表、迁移、存储 | [数据](#数据) |
| 跨 App 接口、契约 | [契约](#契约) |
| 登录、权限、服务间调用 | [身份](#身份) |
| 仓库、组件、运行角色 | [拓扑](#拓扑) |
| 部署、发版、镜像 | [发布](#发布) |
| 智能体 | [智能体](#智能体) + [`round-protocol.md`](../components/backend/components/04-agent-execution/protocol/round-protocol.md) |

对照结果就是一张小表，两三行即可：

| 规则 | 结论 |
| --- | --- |
| 接口分面共享 application 用例 | ✅ 共享 `PilotService`，只在 interfaces 层分身份 |
| 单一主档 | ✅ 不新增状态 |

**不相关的不必列；相关的漏列一条，方案就得重提。**

**「谁在执行」那一栏是重点。**标 ⚠ 的没有自动载体——它只是约定，会漂，
只能靠这个自检和评审守住。

---

## 契约

| # | 规则 | 谁在执行 |
| --- | --- | --- |
| C1 | 即时查询走**版本化同步 API**，长耗时走事件；事件经 Transactional Outbox 发布 | ⚠ 自检 |
| C2 | 接 Outbox 的消费者必须实现**幂等、死信、重放、周期性对账**——四项缺一，Outbox 只是个表 | ⚠ 自检 |
| C3 | schema 真源在 **provider** 仓，consumer 只持锁文件。两处都改会产生第二真源 | 双端 `test_provider_contract_lock_matches_authoritative_schemas` |
| C4 | 改契约必须**双端一起测**——单仓 CI 只跑自己那半，provider 改了、consumer 锁没跟，两边各自都绿 | 双端契约测试（跑 investment 常规套件即带上） |
| C5 | 契约 DTO `extra=forbid`，未声明字段一律拒收 | Pydantic 模型 |
| C6 | citation `source_href` 全平台同形 `/api/web/v1/citations/{id}/source`，共七处，改一处必须七处一起改 | 双端路由表比对测试 |

## 身份

| # | 规则 | 谁在执行 |
| --- | --- | --- |
| I1 | **Admin / Web / Internal 是接口分面，不是三套应用层**——分面在 interfaces 层，共享 application 用例 | ⚠ 自检 |
| I2 | Internal API 按**提供方能力**命名（`ingestions`、`retrievals`、`citations`），**不按调用方命名** | ⚠ 自检 |
| I3 | 浏览器身份与服务身份**互不通用**；浏览器、服务、数据库凭据**禁止复用** | ⚠ 自检 |
| I4 | Next.js **可以**承担浏览器同源 BFF / session 边界，但**不得成为领域数据所有者** | ⚠ 自检 |
| I5 | session / BFF 与 FastAPI 的授权分工**必须有显式契约**；Backend 必须自行复核资源所有权、Origin/CSRF、租户与工具权限——**不信任任何上游声明的身份** | ⚠ 自检 |
| I6 | 非安全方法必须**同时**满足 `Origin ∈ frontend_origins` **且** CSRF token 匹配 | 中间件 |
| I7 | 服务令牌 subject 必须命中 `service_auth_subject_bindings` 的精确键；下游调用路径必须命中 allowlist 前缀 | `core/config.py` + 依赖 |
| I8 | 生产期约 35 处配置硬校验：**配错则进程起不来**，不是运行期降级 | `core/config.py` |

## 发布

| # | 规则 | 谁在执行 |
| --- | --- | --- |
| R1 | 源码、镜像、部署与数据基线**共同发布**；仅靠 Git 标签不能恢复运行环境 | ⚠ 自检 |
| R2 | bundle 只允许 `repo@sha256:<64hex>`，**不允许可变 tag** | 部署门禁正则 |
| R3 | 部署 bundle 的 digest 必须与发布清单一致——晋级靠打别名，**禁止重新构建** | ⚠ 自检（R7 清单与 bundle 手工比对） |
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

## 保证这些被遵守的三层

| 层 | 覆盖 | 在哪 |
| --- | --- | --- |
| **随测试自动跑** | 标了测试载体的那些 | 四仓 `tests/test_kernel_invariants.py`、`tests/test_dormant_capabilities.py`、双端契约测试——**跑 `uv run pytest` 就带上，不需要谁记得** |
| **随提交自动跑** | 本仓文档的三项机械不变量 | [`doc-gate.py`](../../dev-plan/doc-gate.py) 经版本化的 `.githooks/pre-commit` 触发——**提交就带上**。装一次 `git config core.hooksPath .githooks` 对全部 worktree 生效（共享同一个 `.git`），装没装用 `doc-gate.py --selfcheck` 判定 |
| **指针** | 全部 | 五仓根 `AGENTS.md`、`.cursor/rules/`、八个组件 `CLAUDE.md`（**进目录自动注入**） |
| **自检** | 全部 | 上面「怎么用」那节 |

**只有第一层不依赖人。**后两层是纪律，纪律会被忘——这份文件本身就出过两次
"规则在眼前却没回头对照"：一次提出了违反 D1 与 I1 的方案，一次把 I4 说反了
（断言不能用 BFF，实际是可以用、只是不能拥有数据）。

**曾经有过两个独立检查脚本，已删。**理由不是它们没用，而是**要人记得跑的检查
和写在文档里的规矩没有本质区别**——它们自己就落在"纪律"那层。更糟的是其中一条
路径检查的结论取决于工作区状态：同一份文档在三台机器上分别报 0 / 4 / 95 条失败
（子模块是否初始化）。**看起来在把关，其实不牢。**

规则要有载体，就做成**跟着测试跑**的；做不成的，老实标 ⚠。

> 与项目无关的原则（规则要有载体）见 [dev-process 总则](../../dev-process/README.md)。
