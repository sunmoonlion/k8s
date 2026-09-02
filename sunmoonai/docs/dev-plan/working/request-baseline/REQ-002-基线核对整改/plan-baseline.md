# plan：baseline 核对结论与整改项

> 最后更新：2026-08-14
> 对应请求：`request.md`
> 核对分支：五仓 `opus`（tpl-app / info-app / knowledge-app / investment-app / k8s）

## 0. 取证方式与覆盖边界

两轮评审，依据不同，可信度不同，分开记：

| 轮次 | 范围 | 依据 | 产出 |
| --- | --- | --- | --- |
| 第一轮 | baseline 8 份文档自身 | 与 `AGENTS.md` 逐条对照 + 文件系统事实（链接解析、行数、ADR 计数） | §2 结构性问题 |
| 第二轮 | 五个源码仓 | 逐仓深读，每条论断落 `file:line` | §1 与代码不符、§3 代码疑点 |

第二轮按仓并行执行，每仓单独核对其对应的 `intra-apps/<app>/<app>.md`，
方式是：把文档中**每一条可证伪的事实断言**提出来，回代码找对应实现，
分为「不符 / 过期 / 遗漏 / 含糊 / 属实」五类。§5 列出**没能核对**的部分，不做背书。

总体结论：**baseline 的技术描述大体准确，抽查与深读都没发现整段编造**。
问题集中在三类——个别事实写反（§1）、结构上自我违约（§2）、以及把易腐值抄进正文。

---

## 1. 与代码不符（必改，按仓）

### 1.1 k8s.md

**C1｜§2.2 五件套部署顺序写错（本次最严重的一条）**

- 文档：`prerequisites → migration → runtime → network-policies → ingress`
- 代码：`prerequisites → network-policies → migration → runtime → ingress`
- network-policies 的真实位置是**第 2 步**，文档把它排到了第 4 步。
- 证据（三 App 的 `apply()` 完全一致）：
  - `sunmoonai/app-platform/info-app/deployment/deploy.py:185-191`
  - `sunmoonai/app-platform/knowledge-app/deployment/deploy.py:201-207`
  - `sunmoonai/app-platform/investment-app/deployment/deploy.py:235-241`
- 影响：按文档顺序手工部署，会在无 NetworkPolicy 的窗口内跑迁移与运行态。

**C2｜§3.1 称 `00-prerequisites.yaml` 含 Secret 引用与 NetworkPolicy**

- 实际该文件只有 6×ServiceAccount、3×ConfigMap、3×Service；无 Secret、无 NetworkPolicy。
- NetworkPolicy 在 `30-network-policies.yaml`（`info-default-deny`）。
- 证据：`bundle/00-prerequisites.yaml`（kind 枚举）；`bundle/30-network-policies.yaml:1-16`
- 顺带：文档也漏了该文件含 Service。

**C3｜§3.3 把运行时门禁归因于 `verify-formal-instance.py`**

- 该脚本只做 **bundle 静态校验**：schema、digest、sha256、副本数、镜像、IngressRoute/TLS、
  forbidden_markers。证据：`app-platform/scripts/verify-formal-instance.py:86-145`
- 文档所列「namespace 隔离 / DB principal / HPA+PDB+NetworkPolicy / Casdoor 双端 /
  `rollout undo` 回滚」**都不在其中**，它们属另一套需 live 集群的脚本：
  - `docs/architecture-v2/scripts/verify_r5_info_candidate_kind.py:470-502`（DB principal）
  - `docs/architecture-v2/scripts/verify_r3_template_rollback.sh:125`（rollout undo）
- 改法：拆成「静态 bundle 门禁」与「运行时门禁」两栏，各自标脚本。

**C4｜§1 称 `infrastructure/` 含 cert-manager**

- 实际是 kubeadm / CNI / namespace 等步骤脚本，无 cert-manager 清单。
- 证据：`sunmoonai/infrastructure/steps/step05_cni_install.sh`；全仓 cert-manager 仅见于
  第三方 Chart 注释（`messaging-platform/rabbitmq/resources/rabbitmq/README.md:143`）。

**C5｜§1 `data-platform/` 写 `minio`**

- 目录名为 `object-storage/`（内部提供 MinIO AIStor）。语义对、路径名不对。
- 证据：`sunmoonai/data-platform/object-storage/README.md:1-4`

### 1.2 tpl-app.md

**C6｜§3.5 cleanup selector 写成 `architecture-v2`**

- 实际 `app-platform-v2`。证据：`tpl-app/k8s-deployment/.../deploy.py:289`
- 已亲自复核。

**C7｜§3.3 称 ReferenceAdapter 的 ID 由 `uuid5()` 生成**

- 实际是**硬编码的 v5 格式常量**，代码里没有 `uuid5()` 调用。
- 归类为「含糊/误导」而非纯错误：值确实是 v5 格式，但「由 uuid5 生成」会让人去找不存在的
  namespace 与 name 参数。改为「固定 v5 格式常量」。

**C8｜§3.3 适配器类名 `UnavailableAdapter`**

- 实际类名 `UnavailableWebInteractionAdapter`。

### 1.3 info-app.md

**C9｜§3.1 称 `ping` 任务走 `asyncio.run`**

- 实际是同步实现，无 `asyncio.run`。

### 1.4 investment-app.md

**C10｜§3.6/§3.10 称 Web 面走「真 Pilot 产品链」**

- 实际 `/api/web/v1` 端点**未接线到 PilotService**。Web UI 走的不是 baseline 描述的那条链。
- 这条影响判断：读者会以为 Web 已具备 Pilot 能力。
- 已亲自复核。

**C11｜§3.5/§3.11 称红线写在 `CLAUDE.md`**

- `CLAUDE.md` 中**没有**所述红线条文（禁假 SSE、禁 mock 检索等）。出处标错。
- 已亲自复核。

**C12｜§3.8 称迁移 `20260708_0001_agent_phase0` 建「三张 LangGraph checkpoint 表 +
`agent_sessions`/`agent_runs`」**

- 实际该迁移建**八张表**，文档漏了 `checkpoint_migrations`、`session_events`、`tool_side_effects`。
- 已亲自复核。

**C13｜§1 称存在 Attempt / Invocation 表**

- 代码中无对应表。

### 1.5 跨仓一致的一条

**C14｜info/investment 的部署 Secret 模型已变**

- 文档：单个 `info-backend-runtime` Secret。
- 实际：已拆为多个粒度更细的 Secret。
- 两份文档（`info-app.md` §3.7、`investment-app.md`）都要改。

---

## 2. 结构性与治理问题（第一轮结论，保留）

### S1｜仓外存在并行文档集，baseline 还把它当权威引用

`k8s/sunmoonai/app-platform/docs/` 下有 14 份 md + 13 条 ADR，含与 `intra-apps/`
**同名同题**的 App 文档，且都是成篇正文不是指针：`info-app.md` 721 行、
`investment-app.md` 273 行、`data-ownership.md` 147 行。
**仓外合计 2717 行 vs baseline 1410 行**——被当作附属的那套，体量近权威的两倍。

两套已脱节的实锤：仓外 3 处链接指向 baseline 改版前的旧路径 `baseline/overall/`
（`app-platform/docs/README.md:4`、`:10`，`knowledge-app.md:71`），该路径已不存在。

这是 `AGENTS.md` §4 约定 1 最直接的反例。需用户在三个方案中选一个：
A 吸收进 baseline、仓外改指针（推荐）；B 措辞降级为「实现参考（非权威）」；
C 正式承认双层并改 `AGENTS.md` §1（等于放弃约定 1）。

### S2｜`auth-app` 在 baseline 缺位

`app-platform.md` §3 把 auth-app 列为四 App 之一，`k8s.md` §2 也给了它重要点，
但 `intra-apps/` 无 auth-app 目录，一屏表无 auth-app 行，其唯一文档在仓外。
结果 Casdoor application 划分、audience/cookie 配对这类跨 App 必知事实，
按 `AGENTS.md` §0 的阅读路径读不到。

### S3｜ADR 体系割裂

实存 13 条（`app-platform/docs/adr/0001…0013`），baseline 只引 4 条，
且位置与命名都不符 `AGENTS.md` §5 规定的 `baseline/sunmoonai/adr/ADR-<三位序号>-<短名>.md`。
未引用的 9 条中，`0002-system-of-record`、`0005-ragflow-as-derived-system`、
`0012-template-first-adoption`、`0013-release-artifact-lifecycle` 恰恰支撑着
baseline 正在复述却无出处的结论。

### S4｜同一事实最多复述四遍，且带数值

带具体数值的复述最危险：simhash 0.84（3 处）、≤50MiB（4 处）、
RunBudget 20/20/20/120000（3 处）、Alembic head（2 处）。
`AGENTS.md` §4 约定 3 要求「引用写'见 §X'+一句话结论」，现状是抄结论**加参数**。

### S5｜四段骨架只有 5/8 遵守，README 与 AGENTS.md 互相冲突

`inter-apps/app-platform.md`（§3–§12 平铺未收进「架构」）与
`sunmoonai/architecture.md`（无概要、无重要点）不合规。
`baseline/README.md:23` 说「每个文档」都要四段骨架，`AGENTS.md` §5 只要求两类文档——两处冲突。
后果：唯一的平台全景文档没有「3 分钟必知红线」那一节。

### S6｜时间戳一份缺失、术语与格式三不一致

`baseline/README.md` 无任何时间戳（而它是阅读入口）；`architecture.md` 用「最后更新」独立行；
`app-platform.md` 把它塞在引言块句尾；`intra-apps/` 五份用「深读**基线**」而规范写的是「深读**时间**」。
术语不统一会让 `AGENTS.md` 的编辑自检第 1 条无法脚本化。

### S7｜两个 README 内容重叠

`sunmoonai-architecture/README.md` 与 `baseline/README.md` 都画目录树、都逐文件写摘要。
前者还把定位写窄成「App Platform 的提示文档集」，而 baseline 已覆盖九大平台。

### S8｜两条坏链

`baseline/sunmoonai/architecture.md` §16 的 `../../../app-platform/docs/{data-ownership,
integration-standards}.md` 少算一级，应为 `../../../../`。
同目录 `app-platform.md` §13 的层级是对的，说明是复制时漏算。

### S9｜citation 路径三套并存，文档未消歧

三条路径**经代码核对都真实存在且各属不同层**，但没有一处说明关系，
导致 `investment-app.md` 内部看起来自相矛盾（§3.3 说必须匹配 `/api/citations/{uuid}/source`，
§2/§3.11 说只回 `/api/citation-sources/{evidence_id}`——实际一个是 DTO 字段约束、
一个是解析结果 location）：

| 路径 | 所属层 | 代码位置 |
| --- | --- | --- |
| `/api/web/v1/citations/{id}/source` | 模板 web-interaction v1 浏览器契约 | `investment-backend/app/app/application/dto/interaction.py:35` |
| `/api/citations/{uuid}/source` | knowledge retrieval/v1 Citation 投影 | `knowledge-app/contracts/retrieval/v1/citation.schema.json:33`；`domain/agent/knowledge.py:124` |
| `/api/citation-sources/{evidence_id}` | investment Pilot BFF 解析结果 location | `application/agent/pilot_service.py:214`；`dto/pilot_runtime.py:134` |

### S10｜高易腐事实被抄进正文

`tpl-app.md` 写死三个 commit、三个 digest 前缀、两个 tree hash、四个文件数；
`info-app.md` 写 schema sha256；`investment-app.md` 写三个 schema sha256 与 release_id。
**本次核对这些值与真源一致**，但每次发布都会变，而 baseline 是手动更新。
应改为指向真源文件路径。

### S11｜文档里写死个人机器绝对路径

五份 intra-apps 文件头写 `仓库路径 /home/zymun/<app>`，`k8s.md` §1 写「源码在 ~/tpl-app…」。
在别人机器、CI、容器里都不成立。

### S12｜骨架内部不统一

「关键边界规则速查表」只有 knowledge / investment 两份有。这张带「位置」列的表恰恰是
最有价值的结构——唯一能让漂移检测落到可 grep 锚点上。五份应补齐。

### S13｜历史叙事与「新起点原则」冲突

`AGENTS.md` §0 要求不写历史演进叙事，但存在「曾用名 research-app」「已由…取代」
「已移至 repo-backup」「已演进为 schema 2」等表述。
其中多数是**当前有效的护栏**不应删，问题只在表述方式，应改写为现状式祈使句。

### S14｜「九大平台」口径

`architecture.md` §3 列 9 行，其中 `deploy-sunmoonai-all` 是编排入口不是平台
（同文档 §2 已自陈「does not own domains」）。另 `k8s.md` §1 顶层结构表漏了
`sunmoonai/docs/`、`sunmoonai/utils/`，以及 `app-platform/deploy-app-platform-all/`、
`app-platform/utils/`。

---

## 3. 代码侧疑点（非文档问题，需用户决策）

核对中发现三处**代码本身可能有问题**的地方。按 `AGENTS.md` §1.1 提出，不擅自改：

**Q1｜RAGFlow `CANCEL` 状态被当作成功处理（knowledge-app）**

文档如实描述了代码行为，所以不是文档错误。但把「取消」计为成功，
意味着被取消的摄入任务会被标记为已完成，存在数据完整性风险。
需确认这是有意设计还是缺陷。

**Q2｜investment Web 面未接 Pilot（见 C10）**

除了改文档，还要确认这是**未完成的接线**还是**有意的产品分层**。
若是前者，应另立 REQ 补齐；若是后者，baseline 需明确写出 Web 面与 API 面的能力差异。

**Q3｜knowledge 运维面板是静态占位页**

`knowledge-ingestions-panel.tsx` 是静态占位 UI，不是可用的运维面板。
文档把它写成运维能力。需确认是否计划实现——若不实现，baseline 应改为「占位，未实现」。

---

## 4. 需在共享分支处理的项（本功能分支不动）

按 `AGENTS.md` §7，治理文件（`AGENTS.md`、`README.md`、`TEMPLATE.md`）的改动
须在共享分支经用户批准。以下项目触及治理文件，本次**只记录不执行**：

- S1 的方案选择（A/B/C 任一都要改 `AGENTS.md` §1 或权威措辞）
- S5 的骨架规范统一（`baseline/README.md:23` 与 `AGENTS.md` §5 二选一改）
- S6 中给 `baseline/README.md` 补时间戳、统一术语（`AGENTS.md` §4 约定 2 措辞）
- S7 顶层 `README.md` 瘦身与定位措辞
- S3 中若选择「修改 AGENTS.md 承认 ADR 现址与 `NNNN-短名.md` 命名」这一分支

---

## 5. 明确未核对的部分（不背书、不质疑）

- **集群运行态**：未连 KIND。namespace 是否已部署、Pod 是否 Ready、
  §3.3 所列运行时门禁当前是否仍可通过，均未验证。
- **kindnet 是否不执行 NetworkPolicy**：文档与 gate 脚本如此声明，本次未做 live CNI 验证。
- **双远端 GitHub 权威 / Gitee SHA 对齐**：无远端网络访问，未比对 SHA。
  但已知本地五仓 `git remote -v` **只配了 `gitee`，没有 `github`**，
  与 baseline「GitHub 权威、Gitee 镜像」的表述对不上。可能只是本地 clone 未配置，
  需用户确认后再决定是改文档还是补远端。
- **数据库双角色权限是否在现网 PG 生效**：角色定义在 provision 脚本，未连库验权。
- **CI/CD 端到端**：Harbor 含 Trivy 配置，但 `architecture.md` §11 所述
  `build → scan → digest promote` 是否在 Jenkins 发布路径中强制串联，未验证。
  已知偏差：`build-push-app-images.sh:108,158` 推的是**可变 tag** 而非 digest 晋级。
- **认证链细节**：OIDC/PKCE/CSRF/BrowserSurfaceProfile 的完整校验链未逐行走通。

---

## 6. 整改执行记录

本分支（五仓 `opus`）已执行：

| 项 | 动作 |
| --- | --- |
| C1 | `k8s.md` §2.2、§3.1 部署顺序改为 prerequisites → network-policies → migration → runtime → ingress，并标注权威定义在 `deploy.py` 的 `apply()` |
| C2 | `k8s.md` §3.1 `00-prerequisites.yaml` 内容改为 ServiceAccount/ConfigMap/Service |
| C3 | `k8s.md` §3.3 门禁拆为「bundle 静态」与「运行时」两栏表，各标脚本 |
| C4 C5 | `k8s.md` §1 `infrastructure/` 改为步骤脚本描述；`minio` 改为 `object-storage` |
| C6 C7 C8 | `tpl-app.md` selector 改 `app-platform-v2`；uuid5 改为硬编码 v5 常量；类名补全 |
| C9 C14 | `info-app.md` `ping` 改为同步；Secret 模型改为多 Secret，并标注 release.json 在 k8s 仓 |
| C10 | `investment-app.md` §3.6 加现状边界块，指向 §3 Q2 |
| C11 | `investment-app.md` §3.5、§3.11 去掉 CLAUDE.md 出处，改标「口头约定，无规范文件出处」 |
| C12 | `investment-app.md` §3.8 迁移 0001 改为八张表并列出表名 |
| C13 | `investment-app.md` §1 去掉不存在的 Attempt/Invocation |
| S8 | `architecture.md` §16 两条坏链层级 `../../../` → `../../../../`；复跑 15 条链接全通 |
| S9 | `investment-app.md` §3.3 新增 citation 三路径消歧表 |
| S11 | 五份 intra-apps 文件头绝对路径改为仓库名 `sunmoonlion/<app>` |
| S14 | `architecture.md` §3 表前加一句「八个平台 + 一个编排入口」；`k8s.md` §1 补 `docs/`、`utils/`、`deploy-app-platform-all/` |
| Q3 | `knowledge-app.md` §3.5 面板标注为静态占位、未接后端 |
| 顺带 | `architecture.md` §11 补 CI/CD 现状差距（推可变 tag 而非 digest 晋级）；`k8s.md` §3.2 release_id 改为「无统一构词规则」并补 App 特有字段；§3.5 补 4 条遗漏事实 |

时间戳按 `AGENTS.md` §4 约定 2 统一为「最后更新 ｜ 深读时间」两值并列
（前者=文档被改，后者=代码被读），五份 intra-apps 已改。

**未在本分支执行**（原因见 §4，或需用户先决策）：
S1（并行文档集 A/B/C 选型）、S2（新建 auth-app baseline）、S3（ADR 迁址）、
S4（去重与去数值）、S5（骨架统一）、S6 中 `baseline/README.md` 补时间戳、
S7（两个 README 瘦身）、S10（易腐值改指真源）、S12（速查表补齐）、S13（历史叙事改写）。

## 7. 复跑脚本

```bash
cd /home/zymun/k8s/sunmoonai/docs/sunmoonai-architecture

# 坏链检查（15 条相对链接，整改前 2 条坏）
python3 - <<'EOF'
import re, pathlib
root = pathlib.Path('.').resolve()
for p in root.rglob('*.md'):
    for m in re.finditer(r'\]\(([^)]+)\)', p.read_text(encoding='utf-8')):
        link = m.group(1).split('#')[0].strip()
        if not link or link.startswith(('http://','https://','mailto:')): continue
        if not (p.parent / link).resolve().exists():
            print('BROKEN', p.relative_to(root), '->', link)
EOF

# 部署顺序（权威口径）
rg -n 'apply_file|run_migration' \
   ../../app-platform/{info,knowledge,investment}-app/deployment/deploy.py

# 00-prerequisites 实际含哪些 kind
rg -n '^kind:' ../../app-platform/info-app/deployment/bundle/00-prerequisites.yaml | sort -u

# verify-formal-instance 的实际检查项
rg -n 'def check|assert|raise' ../../app-platform/scripts/verify-formal-instance.py

# 仓外并行文档集体量对比
wc -l ../../app-platform/docs/*.md ../../app-platform/docs/adr/*.md | tail -1
wc -l baseline/*.md baseline/**/*.md | tail -1
rg -n 'baseline/overall' ../../app-platform/docs/   # 应为空，当前 3 处
```
