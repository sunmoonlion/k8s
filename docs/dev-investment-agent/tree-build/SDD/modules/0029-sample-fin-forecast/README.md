# 样本：「中国A股上市公司财务分析与预测」从想法写出专家包（0029）

> 2026-10-17 所有者：「样本和设计文档都做」。这是 [0029](../0029-pack-authoring.md) 的第一份样本：Opus 当起草的人，按 0029 设想的步骤**手工**走一遍，把每一处判断都记下来，作为以后自动起草的样板和测试用例。用户是我们自己（以普通用户身份，所有者 2026-10-16 定）。

## 文件

| 文件 | 是什么 | 对应 0029 的哪一步 |
| --- | --- | --- |
| [`01-idea.md`](01-idea.md) | 用户的想法：六问，每句标出处（所有者原话或确认过的提议）；用户没说的空着 | 第 1 步 抽结构、标出处 |
| [`02-gaps.md`](02-gaps.md) | 要回问用户的 12 个缺口（G0–G11），每条带我们的提议 | 第 2 步 列缺口回问 |
| [`03-engineering.md`](03-engineering.md) | 我们定的：八步怎么切、交回物、验收、工具、额度；写的过程中发现的四个平台空白 | 第 3 步 工程化 |
| [`request.json`](request.json) | 交给 knowlab 网页端的提交（`KnowbotRequestIn`）：标题、六问、运行方、3 条验收用例、同意测试 | 用户提交 |
| [`manifest.json`](manifest.json) | 清单草稿 v0（`knowbot-manifest/v1`）：八步专家包、17 条规则出处（6 条有用户出处，11 条 `pending_user` 等用户答） | 第 4 步 出处把关 |
| [`manifest-v1.json`](manifest-v1.json) | 第 1 版第 2 稿的清单（K19 第 2 稿测的就是它），留作对照 | — |
| [`manifest-v1-draft3.json`](manifest-v1-draft3.json) | 第 1 版**第 3 稿**的清单（`manifest_v1.py` 现在生成的就是它）：第 6 步照 sig-am 的补充方法改成对照管理层讨论 | 用户补充方法（[0035](../0035-method-amendment.md)） |

## 用真代码核过（2026-10-17）

| 核什么 | 结果 |
| --- | --- |
| 工作台按分身规则完整校验专家包（`knowbots.pack_from_manifest`：ExpertPack 全量、只许比平台更严、只许 `list_my_data`/`read_my_data`、不许 `requires_tools`） | 通过：8 步，工具只有这两个 |
| knowlab 受理提交（`KnowbotRequestIn`） | 通过：六问、3 条用例、同意测试 |
| knowlab 建草稿前的核对（`draft_manifest_problems`） | **拒**：「each rule source must be user_text or user_confirmed with a ref」——11 条 `pending_user` |
| knowmart 交付时的外层校验（`KnowbotManifestV1`） | **拒**：恰好那 11 条 `rule_sources[6..16].source` |

后两条拒收是预期的：**没有用户出处的规则，现有代码在建草稿和交付两处都过不去**，`C-L1` 已经由程序守着。

## 还差什么才能真测

1. ~~所有者答 [`02-gaps.md`](02-gaps.md)；答复写进 `rule_sources`（`user_confirmed` + 原话），改过的提议照改 `method_text` 与用例。~~：已答（决定单 `docs/财务分析与预测-待你定.md`（2026-10-20 已删，原文见 k8s aac11d42 之前的历史）），第 1 版清单 [`manifest-v1.json`](manifest-v1.json)（`manifest_v1.py` 生成）。
2. ~~G10 的期望值由所有者从年报填（例如 2024 年营业收入），我们不代填~~：所有者 2026-10-18 核过 2024 年报第 5 页，170,899,152,276.34 元；sig-am 已提交想法与用例（[`04-submission.md`](04-submission.md)）。
3. ~~按 G1 准备并上传数据（knowlab「我的数据」），把数据 id、版本、sha256 写进 `data_bindings`~~：2026-10-18 sig-am 传了 6 个文件（Excel 一个、年报 PDF 五份），管理端抄回的 sha256 与远程机原件逐个一致；`manifest-v1.json` 的 `data_bindings` 填好 6 条，knowbench `pack_from_manifest`、knowlab `draft_manifest_problems`、knowmart `parse_manifest` 都过。 **2026-10-19 夜**：重测前预演（照方法造出各步交回物、走工作台真实的计算与判分）查出 Excel 里 2025 年报一个科目名折成两行，修好的文件见 [`data-prep/README.md`](data-prep/README.md)「2026-10-19 修订」，由 qwen-011 第五节重新上传、换绑定；清单说明文字补两句（写法不同的同一科目照用、不是第二个口径；成稿不写「目标价」「评级」，连否定句也不写），方法、规则出处、验收不变。
4. ~~平台空白 1、2（计算工具、数值验收）~~：已由 [0030](../0030-knowbot-compute.md) 补上，本样本的方法与验收已改用（2026-10-17，0030 第九节；演练脚本 `c2-drill.py`）；随 R5 之后的小发布上线。
5. **第 3 稿（2026-10-19）**：sig-am 在 web端写了一条补充方法（`amendment:e6df96db-a92c-43ce-8039-84d7ebcd65b6`）：「第 6 步改成拿分析结论对照管理层讨论：只读管理层讨论那一节，按标题在目录里找；每条结论判支持或不支持，没提到算不支持，判支持的要引原文；找不到这一节就照实说。」第 3 稿只改两步：
   - 第 6 步「对照官方披露」：结论 = 第 5 步的 `indicators.findings`；每份年报从头读到目录、按标题（管理层讨论与分析 / 经营情况讨论与分析 / 董事会报告）找到那一节，只读这一节；每条结论 `{finding, verdict, quotes, why}`，判支持的至少一条引文 `{dataset_id, page, text}`，页码是 PDF 第几页；找不到这一节进 `sections_missing`，照实写。验收用平台核引文（`quoted`，`field: verdict`、`equals: 支持`，[0036](../0036-quote-check.md)）。原来的「核抄的主要会计数据」「四项相对差」「加权平均净资产收益率并列」去掉（抄得准不准改归入库时核，[`总纲/数据拓扑.md`](../../../../../总纲/数据拓扑.md) §十之一），规则出处里 G6 那条换成这条补充（来源 `user_text`，出处 `amendment:…`），仍是 14 条。
   - 第 8 步「成稿」：「勾稽与对照」一节改写每条结论的判断与引文（写明「引文平台核过在原件里；判断是模型做的」），局限里列没找到管理层讨论的年报。
   - 为了不动 sig-am 填的用例 1（期望 `official` 的 `official_by_year.2024.revenue`），第 6 步仍按年把「主要会计数据」那张表的营业收入抄进 `official_values`（平台回表核）与 `official_by_year`。这只是给用例对数用的，不是方法，「主要会计数据」这张表本来就在第 1 条的数据里。
   - 其余六步、数据绑定、用例一字没动。三个应用的清单检查都过（knowbench `pack_from_manifest`、knowlab `draft_manifest_problems` 与 `amendment_ref_problems`、knowmart `parse_manifest`）。预演见 [`rehearsal/README.md`](rehearsal/README.md)「第 3 稿」。
   - 评审后（Astra、远程 Fable 10-19）第 6 步加了工程层验收：`each_has`（每条结论有原话、判断、引文、理由，判断只许「支持」「不支持」；找到、没找到的管理层讨论各项齐全）与 `covers`（第 5 步的每条结论都对照、一条不多不少；`scope.reports` 的每份年报在「找到」或「没找到」里各交代一次）。原先空交、缺判断、「部分支持」都能过，现在都挡。这些只核形状与对得上上游，判支持还是不支持仍归模型、用户看。
   - 核不了的：判得对不对、判不支持的是不是真没提（0036 §二.5）。
   - 第 4 稿再做（所有者 10-19「按建议」）：用补充方法问 sig-am 对照哪几年的管理层讨论；去掉第 6 步末尾「为测试抄营业收入」，改用例 1 的期望（要用户同意）。
6. 之后照 0027 走：knowlab 建草稿（贴 `manifest.json`）→ 核出处 → 发起测试 → 有人值守 → 通过即交付 → 工作台「请」。
