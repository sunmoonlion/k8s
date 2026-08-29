# 合并前评审与补充（cursor）

> 取证时点：2026-08-29 ｜ 作者：cursor（本轮作为独立评审方）
> 所审提交：`k8s` `f8b10832`（`opus` 分支 HEAD）
>
> 背景：当初各助手各自投影现状；cursor 的投影在
> `docs/sunmoonai-architecture/baseline/`（平台间 + App 间 + 一仓一文件），
> opus 被指定为最终撰稿人，把结构改成现在的 `project-guide/` + `working/` + `dev-plan/`。
> 项目前期主要由 cursor 落地，本文件据此对照 opus 现行投影，指出应吸收什么、
> 不应从旧 baseline 搬回来什么。
>
> 写法对齐 [`qoder.md`](qoder.md)：结论 → 阻塞项 → 补充建议 → **可粘贴吸收的条文** → 验收标准。
> 本文所有断言附取证方式。

## 覆盖与盲区（评审自身必须声明）

| 看了 | 没看（勿把未审区当成已审） |
| --- | --- |
| `project-guide/` 全部 12 个 md | 活集群运行态、NetworkPolicy 包级生效 |
| cursor 旧 baseline：`sunmoonai/architecture.md`、`inter-apps/app-platform.md`、各 intra-app 的 §1–§2 | 八个前端约 570 个 ts/tsx 的逐文件核对 |
| `working/{README,doc-conventions,collaboration,check-docs.py}`、`dev-plan/{README,constraints,agent-discipline §5}` | `architecture-v2/` evidence、`app-platform/docs/` 下 ADR 是否仍被引用 |
| 代码侧抽查：`tpl-backend/db-provisioner`、`*-access-bootstrap`、五仓并列与 remote | 旧 baseline 各仓 §3 全文（细节 opus 已按 2026-08-29 代码重取证，不拿过期细节顶现行） |

## 结论

**结构改动应保留，投影作为现状缓存已经比旧 baseline 更贴代码。**
但总入口仍带着已删除目录名；平台层丢掉了几条**写在依赖方向里、grep 源码搜不回来**的原则；
`research` 命名护栏在现行投影里消失，而 `docs/` 下大量历史材料仍在用 `research-app`。

**可继续作为最终投影，但先消化 A 组。** B 组给条文，本轮消化不完的登记去向即可。
旧 baseline 里一批已过期的具体值**禁止搬回来**（见 §拒绝吸收）。

---

## 我认同、不要改回去的部分

这些是 opus 相对旧 baseline 的实质进步，吸收方不要为了“还原 cursor 结构”而打掉：

1. **三分目录**（`project-guide` = 现状，`dev-plan` = 代码必须跟着改的规则，`working` = 协作）比
   旧的 baseline/requests 一团更可维护。
2. **按代码取证重写**，挖出了旧三份投影都没钉死的事实：`2.0.0.dev0` 与
   `formal_release: true` 的时间差、RAGFlow `CANCEL` 当成功、共享 Outbox 有表零调用、
   apply 真实顺序与 `server-dry-run` 不一致、citation 七处同形。
3. **`repos/` 只写相对模板多出来的东西** + **`topics/` 写跨仓事实**，符合
   `doc-conventions.md`「每个事实一个权威位置」。
4. **已知未实现**写成一等事实（且 tpl 用 `test_dormant_capabilities.py` 守着）。
5. **GitHub 权威 / Gitee 镜像**已正确放到 `working/collaboration.md`，不必再写进
   `project-guide`（旧 k8s.md §2.8 的位置过时了）。

---

## 拒绝吸收（旧 baseline 里不要搬回来的东西）

对照代码与 opus 现行文，下列旧文已错或已搬家。**吸收 cursor 不等于回滚这些：**

| 旧文 | 为什么不搬 |
| --- | --- |
| Harbor 地址带 `:30443` | 现行入口已去端口；写进去会教错 |
| citation `source_href` = `/api/citations/...` 或 `/api/citation-sources/...` | 现行全平台 `/api/web/v1/citations/{id}/source`（`topics/contracts.md` C6） |
| 源码版本仍是 `2.0.0.dev0` | 源码已对齐 `2.0.0`；未重建镜像内部仍报 `.dev0` 这一条 opus §9.1 已经写对 |
| 迁移 head / schema sha256 写进正文 | 易腐值，写作约定禁止 |
| 强制恢复「概要→重要点→架构→关联」四段骨架 | opus 的「定位 / 硬规则 / 关键机制 / 已知未实现」更贴代码；只要补回**可扫的重要点**，不必改骨架 |
| 把 Gitee 纪律再写进 `repos/k8s.md` | 已在 `working/collaboration.md`，两处都写=漂移 |

---

## A. 阻塞项（建议吸收进投影后再当最终稿）

### A1. 唯一入口仍在指向已删除的目录名 `architecture/`

`overall-architecture.md` 自称「进入这个项目的唯一入口」，但指路标签全部写成
`architecture/topics/...`、`architecture/repos/...`。相对链接本身是好的
（`(topics/contracts.md)` 能点开），**显示名指向一个不存在的目录**。

这和 qoder A1 是同一类入口伤害：当时是空链接；现在目录已改名为 `project-guide/`，
标签没跟上。新人会去找 `docs/architecture/`，找不到就以为文档集失踪。

取证：

```bash
grep -n 'architecture/' sunmoonai/docs/project-guide/overall-architecture.md
# 当前命中约 11 处，全是链接文字，不是 href
ls sunmoonai/docs/architecture 2>/dev/null || echo '无此目录'
```

另：`working/check-docs.py` 模块 docstring 仍写「从 `architecture/` 目录内跑」。

修法：标签改为 `topics/...` / `repos/...`（或「同目录 README 所列」）；
`check-docs.py` 注释改为 `project-guide/`。不要用空链接，不要用已删目录名。

### A2. 平台层丢掉了三条原则，它们不是目录清单能替代的

opus 把九（八）个平台收成一张「装什么 / 命名空间」表（总览 §4、`repos/k8s.md` §2），
这张表**作为地图是对的**。旧 baseline 多出来、现在整份 `project-guide/` 里搜不到的是
三条**依赖方向上的禁令**：

1. **基础能力向上提供，领域所有权不向下泄漏。**
   Data / Messaging / Ingress 提供能力，不拥有 info/knowledge/investment 的业务事实。
2. **部署顺序 ≠ 运行时耦合。**
   总控按 infra → data → messaging → app → ops 排，只满足启动前置；每个 App 仍必须自备
   超时、有界重试、幂等、Outbox/Inbox 或对账、readiness / 降级。
   **CI/CD 或 Ops 挂了，不应立刻打断已发布业务**；Ingress / 数据 / 消息 / 身份挂了，
   才必须由 SLO 与降级覆盖。
3. **`deploy-sunmoonai-all` 只做编排，不拥有领域。**
   opus 已把它标成「非平台」，但没写这句禁令——后人会把总控脚本当成「可以改 App 内部所有权」的入口。

这三条在源码里没有单一符号可 grep（不像 `BrowserSurfaceProfile`），
**覆盖式重写若只读文件树，会系统性漏掉**。它们是搭平台时定下的运行合同。

取证：

```bash
grep -n '运行时耦合\|不向下泄漏\|不拥有领域' sunmoonai/docs/project-guide/
# 现应无命中
```

建议落点：总览 §4 加一小节（条文见下方 C1），`repos/k8s.md` 用一句话引用，不要两处展开。

### A3. `research` 命名护栏从投影中消失，历史文档会把人带回去

旧 `inter-apps/app-platform.md` §10 把三个完全不同的东西钉开：

- 历史 **`research-app`**：投资研究 / Agent 已由 **`investment-app` 取代**；残留名不是活动 App
- Investment **内部的「研究」**：业务模块，不是独立 App
- 未来若再建 **`research-app`**：通用跨领域研究，新有界上下文，独立仓/身份/库/契约，
  **不得**复用历史身份，也不得把 Investment 数据自动划过去

现行 `project-guide/` 与 `constraints.md` **零命中** `research-app` 护栏。
同时 `docs/` 下 v5 计划、handoff、evidence 仍大量写 `research-app`。
入口若不声明，接手演练（`governance.md` §2）第一天就会把历史目录当成现行仓。

取证：

```bash
grep -n 'research-app' sunmoonai/docs/project-guide/ sunmoonai/docs/dev-plan/constraints.md
# 现应无命中
grep -l 'research-app' sunmoonai/docs/*.md sunmoonai/docs/mooc-manus-*.md 2>/dev/null | head
```

建议落点：总览 §8 红线表加一行 + `repos/investment-app.md` 定位段两句（条文见 C2）。
不要在投影里写改名编年史（违反「不写演进叙事」）；只写**现行该怎么用这个词**。

---

## B. 补充建议

### B1. 各仓缺「30 秒重要点」（建议本轮消化）

旧 intra-app 每篇 §2 是扫读层：不是「违反会抛什么」，而是「读代码前先别理解反」。
opus 的「硬规则」偏失败模式，二者不重叠。例如旧文有、现行需从长文里抠的：

| 仓 | 仍应出现在该仓文首页附近的事实 |
| --- | --- |
| info | sha256 + simhash64(0.84)；仅 clean_markdown/text_plain、有对象存储 version 才可分发；**delivery `completed` = 业务完成**，broker 故障不使 API 5xx |
| knowledge | 一请求恰好一个不可变带版本对象；浏览器只见 citation 投影，永不见 provider 原始 URL；RAGFlow id 不是领域身份 |
| investment | 无授权证据 = 失败不是空答案；resume token 原子消费后永不复用；Run 四终态不可转出 |
| k8s | 迁移失败不得继续 runtime；**smoke 通过不得宣称发布完成**；KIND kindnet 不执行 NetworkPolicy |

后几条在「关键机制」里其实有，但总览接手演练问的是「红线 + 去哪查」，仓文件缺一屏表。
条文见 C3（只加表，不改现有骨架）。

### B2. 每个 Backend 仓里的供给脚本未进投影

opus 只写了 `k8s/sunmoonai/utils/db-provisioner/`。代码里模板与实例 Backend **各自带一份**：

```
<app>-backend/
├── db-provisioner/
├── db-access-bootstrap/
├── search-access-bootstrap/
└── storage-access-bootstrap/
```

`tpl-app` 仓库拓扑若只列 `app/` + `k8s-deployment/`，会让人以为供给只在 k8s 仓。
落点：`repos/tpl-app.md` 结构表加四行，并写明「k8s 仓那份是平台侧入口，Backend 仓那份随模板同步」。

取证：

```bash
ls tpl-app/tpl-backend/db-provisioner tpl-app/tpl-backend/db-access-bootstrap \
   tpl-app/tpl-backend/search-access-bootstrap tpl-app/tpl-backend/storage-access-bootstrap
```

### B3. 总览 §9.4 与 §9.2 口径打架

§9.2 写共享 Outbox / `beat_schedule` **是有意留白**；§9.4 说 CLAUDE.md 是「本节唯一已处置项，
**其余各项仍未解决**」。读者会把有意留白读成缺陷清单。

修法：§9.4 只谈文档层（CLAUDE.md）；§9.2 保持「有意 / 有风险」分类，不要用「未解决」统称。

### B4. 「smoke ≠ 完成」与证据分层

旧 k8s.md 的 L1–L7 梯子可以不原样搬（opus `topics/release.md` §4 的门禁分层表已经更好、且钉到脚本）。
缺的是那句**产品判断**：某一层绿了不等于发布完成。建议在 `topics/release.md` §4 表下加一句
（见 C4），不必恢复 L1–L7 命名。

### B5. 跨 App 消息里放什么

旧总体架构：事件只带稳定 ID、版本、必要摘要；大对象走 Artifact 引用 + 内容哈希。
现行 `topics/data.md` 写了「跨 App 走 HTTP 契约、禁止读表」，没写**载荷形状**。
共享 Outbox 尚未接线，这条现在就能防止第一个事件把 markdown 正文塞进 RabbitMQ。
落点：`topics/data.md` 或 `topics/contracts.md` 一小节，见 C5。

### B6. 总览 §4 平台表缺「明确不负责」列

旧表每行有「核心职责 / 明确不负责」。现在只有「装什么」。加一列成本低，能挡住
「Ingress 做授权」「Data 决定业务表结构」「Ops 进同步关键路径」这类设计回潮。
条文并进 C1，不必另起一节。

---

## C. 建议吸收的条文（cursor 版本，供 opus 覆盖进投影）

以下按「可粘贴」写。吸收方应回代码核对后写入对应文件，**不要整段当第二真源再复制一份到别处**。

### C1. 写入 `overall-architecture.md` §4 之后（平台原则）

```markdown
### 4.1 平台之间怎么依赖

基础能力向上提供，领域所有权不向下泄漏：Data / Messaging / Ingress / CI/CD / Ops
提供能力，不拥有 info / knowledge / investment 的业务事实。
`deploy-sunmoonai-all` 只按依赖顺序编排，不改写各平台内部资源所有权。

| 平台 | 明确不负责 |
| --- | --- |
| ingress-platform | 用户认证、资源授权、业务 API |
| data-platform | 定义业务主档归属（逻辑库仍归各 App） |
| messaging-platform | 把消息当业务事实主档 |
| cicd-platform | 生产请求处理与业务数据 |
| ops-platform | 成为业务同步关键路径（删掉 Ops 工具不得打断已发布请求） |
| deploy-sunmoonai-all | 领域所有权 |

部署顺序不是运行时耦合：总控顺序只保证启动前置。每个 App 仍须自备超时、
有界重试、幂等、对账或 Outbox/Inbox、readiness 与降级。
CI/CD 或 Ops 故障不应立刻中断已发布业务。
```

`repos/k8s.md` 结构表下加一句：「平台禁令见总览 §4.1，此处不复述。」

### C2. 写入总览 §8 红线表 + `repos/investment-app.md` §1

总览表新增一行：

```markdown
| 用历史 `research-app` 指代现行投资研究 / Agent，或把 Investment 内部「研究」当成独立 App | 认错仓、认错身份与数据库 |
| 未先立领域定义就把未来 `research-app` 做成 Investment 的改名/迁仓 | 两个有界上下文被揉在一起 |
```

`investment-app.md` 定位段末：

```markdown
合法领域概念可以保留 `research` 字样（例如图名 `research_web_pilot`），
但应用与基础设施身份必须是 `investment-*`。
历史目录/镜像里的 `research-app` 不是当前活动 App。
未来若出现通用研究 App，必须从当时已验收的 tpl-app 全新实例化，
独立仓库、身份、数据库、对象空间、消息与契约，不继承旧 Research 身份，
也不得把本仓数据自动归属给它。
```

### C3. 各 `repos/*.md` 在「定位」后加「重要点」表（示例：info）

```markdown
## 1.1 重要点

- 去重：sha256 精确 + simhash64 近似（阈值 0.84）
- 可分发：仅 `clean_markdown` / `text_plain`，且必须有对象存储 version，否则 409
- `delivery_outbox_message.completed` 表示**下游业务完成**，不是「消息已进 broker」；
  broker 故障不把 API 打成 5xx
- 运行时下游只接受 `knowledge-app`
```

knowledge / investment / k8s 按 B1 表各写 4 条，避免与「硬规则」表格重复长文。

### C4. 写入 `topics/release.md` §4 表后

```markdown
门禁分层是「这一层查什么」，不是「跑绿一层就算发完」。
静态通过、配对通过、浏览器 smoke 通过，都不能单独宣称正式发布完成；
跨 App 纵切与（另起 Calico 集群的）NetworkPolicy 包级验证仍缺时，只能写明验证边界。
```

### C5. 写入 `topics/data.md`（主档节后）

```markdown
跨 App 传递稳定 ID、版本、内容哈希和必要摘要；大对象用 Artifact 引用，不进消息体。
消费者必须幂等；失败进入可观察状态，并有对账或补偿路径。
```

### C6. 机械文字替换（A1）

- `overall-architecture.md`：所有链接文字里的 `architecture/` 前缀去掉
- `working/check-docs.py` docstring：`architecture/` → `project-guide/`（或「文档根」）

---

## 验收标准（本评审自身）

吸收方按 `agent-discipline.md` §5.3–§5.4：每条接受 / 部分接受 / 拒绝须带理由，
然后回跑本表并公布结果。

| # | 判定 |
| --- | --- |
| 1 | `grep -n 'architecture/' project-guide/overall-architecture.md` 无显示名残留（代码围栏除外） |
| 2 | `check-docs.py` 文件头不再写从 `architecture/` 跑 |
| 3 | 总览出现「不向下泄漏」或等价句，以及「部署顺序不是运行时耦合」 |
| 4 | `project-guide` 内出现现行 `research`/`research-app` 用法的边界声明（不是改名故事） |
| 5 | B1–B6 各有去向：本轮写入 / 立请求 / 拒绝并留理由 |
| 6 | 拒绝吸收表中的过期值未被写回投影 |

**本评审不构成「架构已在集群验证」的背书**（同 `agent-discipline.md` §5.6）。
