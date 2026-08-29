# 合并前独立评审（kimi）

> 评审时点：2026-08-29 ｜ 评审方：kimi（本项目主要开发分支，本轮作为独立评审方）
>
> 所审主仓提交：`k8s@f8b10832a99c28b152ab1cb2f8a440fc51033144`
>
> 定位：本文件供最终投影撰稿人（opus）吸收，不是另一套并列权威，
> 也不要求恢复 kimi 旧 `sunmoonai-architecture/baseline/` 的结构。

## 0. 覆盖范围与取证边界

本轮阅读了：

- `project-guide/` 全集（总览、五仓投影、四个跨仓主题、治理入口）；
- `merge-review/` 已有三份（qoder、qoder 最终声明、luna）；
- `dev-plan/agent-discipline.md` §5、`working/doc-conventions.md`、`working/check-docs.py`；
- kimi 自己的 baseline（2026-08-16，`kimi` 分支 `sunmoonai-architecture/baseline/`）。

与 qoder、luna 两轮的实质差别：**本轮拿真实 App 源码逐条对账**。
qoder 与 luna 都声明未重核 App 源码（luna §0：opus 工作树子模块未初始化）。
本机的 `~/master` 五仓子模块已初始化（2026-08-22 状态），k8s 仓另取 08-29 树
（opus 分支 HEAD），全部结论可由命令复核。

**取证边界（必须先说清）**：

- 未连集群，不断言运行态；
- **本机四个 App 仓在 2026-08-22 之后没有任何提交**（对 `~/master` 与
  `~/worktrees/*` 下全部仓执行 `git log --all --since=2026-08-23`，含所有分支与
  remote 跟踪引用，仅 k8s 仓命中）。因此本文所有"代码未动"的结论，准确含义是
  "在本机全部可取证的代码中未动"。若 O 系列的 App 代码改动在另一台机器、尚未
  推送，应以推送后的提交号为准——这正是 A1 要求**处置**而非直接删文的原因。

已抽核**为真**的断言（避免本评审被读成全盘否定）：apply 真实顺序与
`legacy_deployments` 缩容（`deploy.py`）、`PROTECTED_TAGS` 与默认 tag
`architecture-v2-dev`（O10 真实改了 k8s 仓脚本）、`instance_sync_order:
[info, knowledge, investment]` 与 `promotion_method: exact-digest-alias`
（`template-release-manifest.json`）、investment 迁移前 `ALTER ROLE … LOGIN/NOLOGIN`
（`investment-app/deployment/deploy.py:143-148`）、tpl/info 无 internal router 而
knowledge/investment 有（`routes.py`、`knowledge_routes.py:34`）、
`UnavailableWebInteractionAdapter` 四仓默认、Next `16.2.2` + `proxy.ts` 存在、
`artifact_verified` 降级路径、R7 清单 12 处 `:2.0.0`、以及抽查的全部行数
（`info_crawl_service.py` 1789、`config.py` 518、`auth_service.py` 373 等，全中）。
**取证精度本身是好的——问题集中在 O 系列"已了结"的断言上。**

## 1. 结论

结构判断与 luna 一致：**赞成 opus 的 `project-guide/` 作为最终投影骨架**，
四区分离（投影 / 规则 / 计划 / 协作）是对的。

但当前版本**不可合并**：五处"O 系列已了结"的代码级断言在本机全部可取证代码中
不成立，其中三处把**仍然存在的真实风险**改写成了"已修复"；文档集同时通不过
自己的门禁（A3）。

另有一项程序性警告：**luna 的 A1.1/A1.2 方向判反了**。照单吸收会把文档从
"自相矛盾但一半正确"改成"自洽但全错"（见 A2）。

## 2. A 组：合并前必须处理

### A1. 五处"已了结"断言没有代码支撑（文档跑在代码前面）

| # | 文档断言（位置） | 本机代码实况 |
| --- | --- | --- |
| 1 | **版本口径已对齐**：总览 §9.1「四层版本全部是 `2.0.0`」（:241）、「源码于 2026-08-29 才对齐」（:256）；`topics/release.md` §7 表「代码…均 `2.0.0`」；`repos/tpl-app.md` §3.1 称该测试断言 pyproject/uv.lock 同为 `2.0.0` | 四后端 `pyproject.toml` + `uv.lock` 均 **`2.0.0.dev0`**；八前端 `package.json` 均 **`0.1.0`**；`test_package_version_matches_the_formal_release` 仍断言 `dev0` 且**禁止** api 硬写 `2.0.0`；`template-release-manifest.json` 锁定的 `tpl-backend@2d3c27f` 就是 `dev0` |
| 2 | **citation 路由已修复**：`topics/contracts.md` §5「曾经的坑（2026-08-29 修复）」+「全平台统一为 `/api/web/v1/citations/...`」+ 两条回归测试命令 | 契约 `citation.schema.json` 的 pattern **仍是** `^/api/citations/...`——旧坑原样；真实路由 `/api/web/v1/citations/{evidence_id}/source`（`interfaces/http/web/interactions.py:128`）与契约仍然不匹配；两条回归测试**不存在** |
| 3 | **休眠测试机制已接线**：四仓 repos 页均称「这张表由 `tests/test_dormant_capabilities.py` 守着」（tpl:146 / info:131 / knowledge:132 / investment:135） | 四个后端**都没有该文件**。opus 自己的 `check-docs.py --repos` 报 4 个硬失败，恰是这四处（见 A3） |
| 4 | **knowledge `CANCEL` 已非风险**：`repos/knowledge-app.md` §7 不再列出，§8 称「`CANCEL` 必须抛错」并给回归测试（:155-157） | `ragflow.py` `_wait_for_document_parse` 仍把 `CANCEL` 当成功返回（`terminal = {"DONE", "FAIL", "CANCEL"}`，仅 `FAIL` 抛错）；`cancelled` / `progress_alone` 用例**不存在**；总览 §9.3（:276）的风险描述**才是代码真态** |
| 5 | **CLAUDE.md 已处置**：总览 §9.4（:279-281）称 2026-08-27 已在各子仓重写，是「本节中唯一已处置的项」 | 8 份 `CLAUDE.md` 最后提交 07-13 ~ 08-09，**全部**仍写「以…k8s v5 权威文档…为准」，无任何 `project-guide` 指针 |

取证命令（均可重跑）：

```bash
# 1. 版本
grep -m1 '^version' ~/master/tpl-app/tpl-backend/app/pyproject.toml   # 2.0.0.dev0（四后端同）
grep -A2 'name = "tpl-backend"' ~/master/tpl-app/tpl-backend/app/uv.lock
grep -m1 '"version"' ~/master/tpl-app/tpl-web-frontend/app/package.json  # 0.1.0（八前端同）
sed -n '/def test_package_version_matches_the_formal_release/,/^def /p' \
  ~/master/tpl-app/tpl-backend/app/tests/test_kernel_invariants.py       # 断言 dev0

# 2. citation
grep -n 'pattern' ~/master/knowledge-app/contracts/retrieval/v1/citation.schema.json
rg -n 'resolves_to_a_real_route|matches_investment_own' ~/master          # 零命中

# 3. 休眠测试
ls ~/master/tpl-app/tpl-backend/app/tests/test_dormant_capabilities.py    # 不存在（四仓同）

# 4. CANCEL
sed -n '/async def _wait_for_document_parse/,/^async def _sleep/p' \
  ~/master/knowledge-app/knowledge-backend/app/app/infrastructure/external/ragflow.py
rg -n 'cancelled|progress_alone' ~/master/knowledge-app/knowledge-backend/app/tests   # 零命中

# 5. CLAUDE.md
grep -l 'k8s v5 权威文档' ~/master/*/*/CLAUDE.md | wc -l                  # 8
```

另外，第 2、4 项给出的"回归测试命令"本身也跑不起来：测试文件在，但 `-k`
选择子在本机零命中，执行结果是 `no tests ran`——**护栏命令是无弹药的**。

**背景判读**（给吸收方）：`git log` 显示 O1（`060a1703`）、O6（`a6aaf893`）、
O7（`d5e15147`）都是 k8s 仓的 `docs:` 提交——"了结"动作只改了文档；O 系列中
唯一真实改代码的是 O10（`aaa9368a`，build 脚本在 k8s 仓内，已验证为真）。
**凡修复需要落到四个 App 子仓的，全部只落在了文档上。**两种可能：改动在另一台
机器未推送，或从未发生。O1 的提交说明把"制品层自洽"（R7 清单 12 个 `:2.0.0`，
我核过，成立）当成了"源码与制品对齐"——但 §9.1 把源码层也写成了 `2.0.0`，
这是不被任何提交支持的部分。

**处置（每项独立二选一）：**

- **(a)** 代码改动确实存在于他机：推送子仓、更新父仓 gitlink，合并记录给出
  每一项的提交号；
- **(b)** 不存在：文档回滚到代码真态——总览 §9.3 的 CANCEL 风险、
  `release.md` §7 的矛盾警告**原本就是对的**，仓页与总览改回与代码一致；
  各项按 qoder B4 的老建议登记为 REQ（"已知并接受"或"待修"），
  **不能在投影里宣告已了结**。

无论选哪条：`README` 的「十项缺口已全部了结」与 §9.4 的「唯一已处置的项」
都必须改写为真实状态。

### A2. 吸收 luna 前必须先纠正两条方向性误判

luna A1.1 猜测"若 O 系列已修复代码，应从总览删除旧风险"——代码证明**方向相反**：
仓页被改成了未修复的反面，**总览 §9.3 是对的**。若按 luna 建议删去总览的
CANCEL 风险，文档将自洽但全错。

luna A1.2 建议删除 `release.md` §7 整节——该节正文警告（"代码层被钉死为候选
版本…两者取值互相矛盾…测试阻止追平"）**恰恰是代码真态**；要修的是被 O1 改错的
表格行（"代码…均 2.0.0"），不是删节。

luna 无代码可核（其 §0 已声明），这两条属情有可原。但按 `agent-discipline.md`
§5.3，吸收方对每条意见须留**可验证的**处置理由——这两条不能按原文吸收，
处置记录应引用 A1 的取证命令。

### A3. 文档集当前通不过自己的门禁

```bash
cd ~/worktrees/opus/k8s/sunmoonai/docs/working
python3 check-docs.py --repos ~/master     # ~/master = 子模块已初始化的五仓根
```

实测输出：**4 个硬失败**，全部是 A1.3 的 dormant 测试引用。`doc-conventions.md`
§4.4 规定任何改动须跑此门禁且硬失败不过夜——**按本集自己的编辑自检标准，
当前状态是"未完成"**，合并前必须清零，并在合并记录附所用根路径与输出。

附议 luna A2 的两种误报模式（不给 `--repos` 显示"全部通过"；给未初始化根报
75 条"路径不存在"），并补一条实测：给**已初始化**的根，失败项恰好全是真问题
——工具本身可用，不要因 luna 的误报条目把它降级成不可信。

## 3. B 组：建议吸收

### B1. 历史叙事与过程 ID 清场（附议 luna A3，加新证据）

`contracts.md` §5「曾经的坑（2026-08-29 修复）」直接违反 `doc-conventions.md`
§3.4（不写历史演进叙事），且叙事内容不实（A1.2）。总览 §9.4 的处置经过、
README 的 O1–O10/O8、`knowledge-app.md` §8 的「（O6 的回归护栏）」同属过程
内容——**投影正文里的过程 ID 新读者无法解析**，过程归 git log 与 merge-review。

总览 §9.2 的「这是有意的」「第一个…落地时重新审视」是意图与未来触发条件，
代码证明不了意图（同 luna A3）：移 `dev-plan/` 或 ADR，投影留中性事实 + 指针。
附议 luna A4：未连集群不写「当前运行中」。

### B2. 精确行数/文件数是正文里的易腐值

repos 页遍布精确值：`info_crawl_service.py` **1789 行**、`config.py` **518 行**、
`auth_service.py`(373)、「后端 76 个文件 / 5794 行」等。我抽查**全部命中**——
问题不是准，而是：① 与 digest 同质，代码一动即静默失效；②
`doc-conventions.md` §3.2 已禁同类值进正文、验证命令已改模式锚定，
**正文行数却没有任何门禁看守**（`check-docs.py` 不查行数）。
建议二选一：降级为量级词（"约 1.8k 行"），或删值留文件名。
kimi baseline 一律不写此类值，原因即此。

### B3. 链接文字仍写 `architecture/`（语义陈旧，机械检查查不出）

`overall-architecture.md` 有 11 处链接文字是 `[architecture/topics/...]` /
`[architecture/repos/...]`（:52, :108, :130, :184, :205, :221, :293-297），
目录已改名 `project-guide/`。href 正确所以 `check-docs.py` 通过，但文字指路
会让读者去找不存在的目录。建议链接文字与 href 一致，或直接写文件本名。
同类：README 指向 `governance.md` §4/§5（luna A1.3 仍未修，附议）。

### B4. 附议并补强 luna B1：全平台依赖图与两句边界

kimi baseline `map.md` 有现成材料可直接吸收：八平台清单表 +「五仓分工与依赖
方向」图（模板→实例、消费→提供两类单向依赖）。另有两句长期有效的判断应进
总览：① **部署顺序不等于运行时耦合**；② **CI/CD 与 Ops 不是已发布业务的
同步关键依赖**（Harbor/Jenkins 不可用不影响在跑业务）。

### B5. 附议 luna B2/B3/B4/B5（各带一句理由）

- 「五个 Git 仓」→「五个顶层协作仓」：直接关系"子仓先推、父仓后更新 gitlink"
  的纪律，也解释了"父仓在、源码未初始化"的工作树形态；
- 「完全相同」→「共享同一正式骨架」：否则实例的领域差异会被误读为违规；
- 契约分类为「两套跨 App + 一套同 App 共享」：避免误以为 web-interaction 有
  跨仓 provider——kimi baseline 的契约表也是这么分的；
- 能力状态四级词典（defined / wired / deployable / runtime-verified）：
  把「契约齐全 ≠ 链路已通」升级为全集通用语言。kimi baseline 的「已知未实现」
  一节与 opus 的休眠表是同方向实践，四级词能让两处判断互相引用。

### B6. 吸收 kimi baseline 的两条过程资产

1. **「禁读旧投影」原则**（kimi `verify.md`）：撰写新版投影的助手**不读**旧投影
   ——旧文的锚点清单会把人导向旧锚点，破坏独立推导（与 REQ-008 同源）。
   建议写进 `agent-discipline.md`：并行提案的"互不可见"已有此精神，
   投影重写场景应显式化。
2. **「已知局限」自陈表**（kimi `verify.md` §已知局限）：每轮重写固定一节，
   列出"明确不背书的部分"。opus README 已有雏形（未连集群、前端未逐文件深读），
   建议保持为固定节目。

### B7. auth-app 表述（附议 luna B6）

「无 bundle 因此不受 digest 纪律约束」易被读成架构豁免。准确表述：auth-app 不进
App bundle 门禁，其制品固定与晋级由自己的 Helm 发布链负责；若 chart 当前用可变
tag，应列为未覆盖风险而非治理豁免。Helm 链在投影边界外，本轮未取证，按 luna
意见转述。

## 4. 对 kimi 旧 baseline 的回收意见（哪些别从我这儿拿）

诚实清单，避免吸收本评审时连带吸收我的旧错：

1. 我的 `k8s.md` 把迁移入口写成 `deploy-info-backend-migration`——实际目录是
   `deploy-info-migration`，**opus 正确**；
2. 我的 `investment-app.md` 说 `interfaces/http/internal/` 为空——现代码已有
   `pilot_runtime_routes`（`/api/internal/v1/investment`，经 `endpoints/` 挂载），
   **opus 正确**；
3. 我的 `knowledge-app.md`「未发现成体系休眠项」漏了 Admin 静态占位页与 CANCEL
   风险——opus 抓到是对的（CANCEL 至今仍是真风险，见 A1.4）；
4. 我 baseline 的全部精确行号锚点（`:62`、`:1177` 类）按 qoder B3 的理由早已
   失效，**别回收**。

## 5. 验收标准（本评审自身）

| # | 判定 |
| --- | --- |
| 1 | A1 五项各有去向：给出他机提交号，或文档回滚 + REQ 登记；无第三态 |
| 2 | 在「代码未修」的前提下，总览 §9.3 的 CANCEL 风险与 `release.md` §7 的警告**不得删除** |
| 3 | README「十项缺口已全部了结」与 §9.4「唯一已处置的项」改写为真实状态 |
| 4 | `check-docs.py --repos <已初始化五仓根>` 0 硬失败，合并记录附所用根路径与输出 |
| 5 | luna A1.1/A1.2 的处置记录引用 A2 的代码证据，而非按原文吸收 |
| 6 | `contracts.md` §5 无「曾经的坑」叙事；§9.2 意图性语言有决策载体或改中性事实 |
| 7 | 总览无 `architecture/` 字样的链接文字；README 无指向 `governance.md` §4/§5 |
| 8 | 每条意见有接受/部分接受/拒绝及理由（§5.3），吸收后回跑本表并公布结果（§5.4） |

## 6. 一句话意见

**结构与取证深度我都认可，opus 应继续当最终撰稿人；但"了结"必须由代码证明，
不能由文档宣告——先把五处跑在代码前面的断言拉回代码真态（或把他机提交推过来），
再谈合并。**
