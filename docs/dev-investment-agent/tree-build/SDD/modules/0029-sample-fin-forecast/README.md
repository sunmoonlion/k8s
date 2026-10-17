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

## 用真代码核过（2026-10-17）

| 核什么 | 结果 |
| --- | --- |
| 工作台按分身规则完整校验专家包（`knowbots.pack_from_manifest`：ExpertPack 全量、只许比平台更严、只许 `list_my_data`/`read_my_data`、不许 `requires_tools`） | 通过：8 步，工具只有这两个 |
| knowlab 受理提交（`KnowbotRequestIn`） | 通过：六问、3 条用例、同意测试 |
| knowlab 建草稿前的核对（`draft_manifest_problems`） | **拒**：「each rule source must be user_text or user_confirmed with a ref」——11 条 `pending_user` |
| knowmart 交付时的外层校验（`KnowbotManifestV1`） | **拒**：恰好那 11 条 `rule_sources[6..16].source` |

后两条拒收是预期的：**没有用户出处的规则，现有代码在建草稿和交付两处都过不去**，`C-L1` 已经由程序守着。

## 还差什么才能真测

1. 所有者答 [`02-gaps.md`](02-gaps.md)；答复写进 `rule_sources`（`user_confirmed` + 原话），改过的提议照改 `method_text` 与用例。
2. G10 的期望值由所有者从年报填（例如 2024 年营业收入），我们不代填；`request.json` 里现在的期望只是「有季度」「写明算不出来」「写明没有数据」这类形状检查。
3. 按 G1 准备并上传数据（knowlab「我的数据」），把数据 id、版本、sha256 写进 `data_bindings`。
4. `03-engineering.md` 的平台空白 1、2（计算工具、数值验收）不补，这个分身能跑但算不准、验不出算错——建议在第一条实测前后补上（0029 第五节）。
5. 之后照 0027 走：knowlab 建草稿（贴 `manifest.json`）→ 核出处 → 发起测试 → 有人值守 → 通过即交付 → 工作台「请」。
