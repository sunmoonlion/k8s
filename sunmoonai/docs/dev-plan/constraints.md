# 开发必须遵守的规则

> 最后更新：2026-08-29
>
> **动代码前先读这里。**本文件是唯一的规则来源——`../project-guide/` 只描述
> 现状（改了代码它跟着改），本文件规定**代码必须符合什么**（违反了要改代码）。
>
> 两组：**约束**来自决策，**不变量**来自代码。两组都要遵守，
> 用法见文末「提方案前的自检」。

## 一 · 约束（来自决策，18 条）

以下是项目此前已定的决策，**在本计划中直接作为约束**，不再重新讨论。
这里是**全文**，不是索引——原 `decisions/` 目录已删除，因为"留着仅作参考"
的文档不会被执行。未被吸收的条目去向见文末附录。

**领域与数据**

1. 按长期业务领域划分 App，不按页面或部署组件划分
2. **每类业务数据只有一个权威主档**，其余存储只保存引用、快照或可重建副本
3. 同步 API 与异步事件并用：即时查询走版本化同步 API，长耗时走事件
4. 对象存储按领域拥有：物理可共享，Bucket / 凭据 / 生命周期必须隔离
5. **RAGFlow 是可重建的派生系统**，不保存唯一原文
6. 每个 App 收敛一个逻辑数据库和一条迁移链

**拓扑**

7. 模板组件不定义领域边界；运行角色不等于领域服务
8. **每个领域 App 只有一个规范 Backend**
9. 以现有 Admin Backend 的 Git 历史主线收敛规范 Backend 仓库
10. **Admin / Web / Internal 是接口分面，不是三套应用层**
11. **一个 Backend 代码库按运行角色部署**（API / Worker / Scheduler / Migration）

**发布**

12. **模板优先**：公共能力先进模板过门禁，再完整同步实例
13. 源码、镜像、部署与数据基线**共同发布**；仅靠 Git 标签不能恢复运行环境

**接口与身份**

14. **Next.js 可以承担浏览器同源 BFF/session 边界，但不得成为领域数据所有者**
15. **session/BFF 与 FastAPI 的最终授权分工必须有显式契约**；Backend 必须自行复核
    资源所有权、Origin/CSRF、租户与工具权限——**不信任任何上游声明的身份**
16. Internal API 按**提供方能力**命名（`ingestions`、`retrievals`、`citations`），
    **不按调用方命名**（不出现 `/internal/info-app/...`）
17. 浏览器、服务、数据库凭据**禁止复用**

**智能体**

18. 分通用与专用、纪律两边都要有、四本账落 PG、执行层租用——即本文上一节

## 二 · 不变量（来自代码，19 条）

上面十八条来自**决策**；下面这些来自**代码**——已经这样了，改动不得违反。
原先散在 `../project-guide/topics/` 的正文里，但**投影没有强制阅读的机制**，
写在那儿就等于没写。搬到这里，一并纳入「提方案前的自检」。

**「谁在执行」这一栏是重点**：标 ⚠ 的目前没有载体，它只是约定，会漂。

四条 ⚠ 里有两条是**程序性**的（迁移七步、先修模板再同步实例），
一条是**环境事实**（KIND 不执行 NetworkPolicy），
一条**静态查不出**（fail-closed 要看运行时行为）。
它们不是"还没来得及做载体"，是这类规则本身机械判定不了——
所以只能靠自检和评审，别指望它们自动被守住。

**契约**

| 不变量 | 谁在执行 |
| --- | --- |
| schema 真源在 **provider** 仓，consumer 只持锁文件；两处都改会产生第二真源 | 双端 `test_provider_contract_lock_matches_authoritative_schemas` |
| citation `source_href` 七处同形，改一处必须七处一起改 | `test_citation_source_href_resolves_to_a_real_route` 及 consumer 侧对照 |
| 契约 DTO `extra=forbid`，未声明字段一律拒收 | Pydantic 模型定义 |
| 跨仓契约测试**在单仓 CI 里不会自动跑**——provider 改 schema、consumer 锁没跟，两边各自都绿 | `check-cross-repo.py` 的「双端契约测试通过」显式两边一起跑 |

**身份**

| 不变量 | 谁在执行 |
| --- | --- |
| 浏览器身份与服务身份**互不通用**；前端不得持有后端或数据库凭据 | `core/config.py` 启动期校验 |
| 非安全方法必须同时满足 `Origin ∈ frontend_origins` **且** CSRF token 匹配 | 中间件 |
| 服务令牌的 subject 必须命中 `service_auth_subject_bindings` 的精确键 | `core/config.py` + 依赖 |
| `DownstreamServiceClient` 的路径必须命中 allowlist 前缀 | `core/config.py` |
| 生产期约 35 处配置硬校验：配错**进程起不来**，不是运行期降级 | `core/config.py` |

**数据**

| 不变量 | 谁在执行 |
| --- | --- |
| 物理资源可共享，但必须独立逻辑库、角色、Secret | 部署清单 + `check-cross-repo.py` 凭据检查 |
| 改迁移**必须同步改** `test_kernel_invariants.py` 的文件名清单 | 该测试逐字比对 |
| 迁移链单链线性，恰好一个 `down_revision = None` | 同上 |
| 数据迁移走 `expand→backfill→reconcile→switch read→switch write→observe→contract` | ⚠ 无载体，程序见 `../project-guide/topics/data.md` |
| 旧写路径切换必须 **fail-closed**，不得无期限双写 | ⚠ 无载体 |

**发布**

| 不变量 | 谁在执行 |
| --- | --- |
| bundle 只允许 `repo@sha256:<64hex>`，不允许可变 tag | 门禁正则 + `check-cross-repo.py` |
| `.conf` **不得覆盖** bundle 里的镜像、副本、origin，值须与 `release.json` 完全一致 | `ConfigError` |
| `1.0.0` / `2.0.0` 是发布 tag，本地构建脚本不得推 | `build-push-app-images.sh` 的 `PROTECTED_TAGS` |
| **公共缺陷先修模板、过门禁，再同步实例**；不得先改实例 | ⚠ 无载体 |
| KIND 不执行 NetworkPolicy，包级验证必须另起 Calico 集群 | ⚠ 无载体（是环境事实，不是可测规则） |

## 提方案前的自检

**提任何方案前，先对照上面两组——十八条约束与主题不变量——并写出对照结果。**
违反其中任何一条的方案**不进入讨论**——不是"不推荐"，是不提出。

不必每次都过全部。按**你要动什么**取对应的组：

| 你要动 | 至少对照 |
| --- | --- |
| 跨 App 接口、契约 | 约束 3、10、16 + 契约不变量 |
| 登录、权限、服务调用 | 约束 14–17 + 身份不变量 |
| 表、迁移、存储 | 约束 2、4、6 + 数据不变量 |
| 部署、发版、镜像 | 约束 12、13 + 发布不变量 |
| 智能体 | 约束 18 + [`agent-discipline.md`](agent-discipline.md) |

这条来自同一天的两次失败：

1. 讨论 U1 时提出的"web 面自持会话与投影"方案，同时违反第 2 条（第二份 run
   状态就是第二个主档）与第 10 条（按调用方复制了一层应用）
2. 紧接着又断言"BFF 已被 ADR-0007 取消"——**恰好写反了**，ADR-0007 说的是
   Next.js 可以做 BFF、只是不能拥有数据（现为第 14 条）

两次都是"约束就在眼前却没回头对照"。靠记性不行，得有机械动作。

对照只需一张小表，把相关条目和结论写出来即可：

| 约束 | 结论 |
| --- | --- |
| 10 接口分面共享 application 用例 | ✅ 共享 `PilotService`，只在 interfaces 层分身份 |
| 2 单一主档 | ✅ 不新增状态 |

**不相关的条目不必列**，但相关的漏列一条，方案就得重提。

## 附：原 `decisions/` 的 106 条去哪了

| 去向 | 条数 | 说明 |
| --- | --- | --- |
| **已是现状** | ~60 | 投影里已写（`../project-guide/` 的 `repos/` `topics/` 与总览），不重复 |
| **升为上面的约束** | 18 | 即本节，全文在此 |
| **变成可执行检查** | 6 | 见 `../project-guide/check-cross-repo.py` 与四仓 `test_kernel_invariants.py` |
| **挂到动作触发点** | ~12 | 写进做那个动作时会读的文档，见下表 |
| **已过期** | ~10 | 仓库重命名期、v1 回滚窗等一次性过程，事已完成 |

挂到触发点的那些：

| 动作 | 规则写在 | 内容 |
| --- | --- | --- |
| 改数据层 / 做数据迁移 | [`../project-guide/topics/data.md`](../project-guide/topics/data.md) | `expand → backfill → reconcile → switch read → switch write → observe → contract` 七步；切换必须 fail-closed，不得无期限双写；六条验收项 |
| 发版 / 清理镜像 | [`../project-guide/topics/release.md`](../project-guide/topics/release.md) | Harbor 删除保护范围、删除前 dry-run 与人工审计、观察窗内不得删旧资产 |
| 改模板 / 同步实例 | [`../project-guide/repos/tpl-app.md`](../project-guide/repos/tpl-app.md) | 「完整同步」包含哪些能力、实例领域代码用 extension point 保留而非清空覆盖、每实例出对齐报告并把差异分四类、**一个实例失败不得推进下一个** |
| 拆分 Worker | [`../project-guide/repos/`](../project-guide/repos/) 对应仓 | 五条拆分判据（攻击面/时长语义/独立身份/容量指标/故障隔离），以及各 App 的观测重点 |
| 接 Outbox | [`../project-guide/overall-architecture.md`](../project-guide/overall-architecture.md) §9.2 | 消费者必须实现幂等、死信、重放与周期性对账 |

## 怎么保证这些被遵守

三层，从弱到强：

| 层 | 覆盖 | 触发时机 |
| --- | --- | --- |
| **指针** | 全部 | 五仓根 `AGENTS.md`、`.cursor/rules/`、八个组件 `CLAUDE.md`（**进目录自动注入**）都指向本文件 |
| **自检** | 全部 | 提方案前逐组对照，见上一节 |
| **检查** | 可机械判定的那些 | `../project-guide/check-cross-repo.py`（7 条，约 5 秒）、四仓 `test_kernel_invariants.py`、`check-docs.py` |

**只有第三层不依赖人。**前两层是纪律，纪律会被忘——本文件的自检那节就记着
两次"约束在眼前却没对照"的失败。所以：**一条规则如果能机械判定，就别停在文字上。**

推送前建议跑一次：

```bash
python3 k8s/sunmoonai/docs/project-guide/check-cross-repo.py --repos <五仓父目录>
```
