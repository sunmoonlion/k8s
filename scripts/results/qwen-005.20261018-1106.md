# qwen-005 小发布回执（本地机 Qwen）

- 派活卡：`docs/dev-investment-agent/switch-test/inbox/qwen/2026-10-18-qwen-005-small-release-0030.md`
- 执行者：Qwen（本地机）；浏览器走查由所有者亲手操作，Qwen 核截图与集群侧证据
- 时间：2026-10-18 00:5x 首轮停点 → 01:0x 续跑二~四节 → 02:1x–11:0x 第五节走查闭环
- 首轮停点：第二节 exit=1（卡内 python 块正则带 `re.S` 跨块吞到 knowmart），停点回执 `scripts/results/qwen-005.20261018-0052.md`（提交 ba1a2f51）；Opus 修卡后 `git pull --ff-only` 到 c5e443da，自第二节续跑，第一节不重做

## 1. 各步 exit（续跑轮）

| 节 | 命令 | exit |
| --- | --- | --- |
| 一 | `git pull --ff-only origin qwen`（f48b1aff）；两仓 HEAD/submodule 与卡逐字一致；`make -C infrastructure platform-status` | 0（PLAY RECAP failed=0） |
| 一（停点轮） | 同上核对 | 0 |
| 二（停点轮） | 卡内 python 改钉脚本 | **1**（AssertionError: ('knowlab','parent_revision')；sources.yaml 未改） |
| 二（续跑轮） | 修卡后 python 改钉脚本 | 0（sources.yaml 恰改 10 行：knowlab/knowbench 各 父/后/网 五字段；两个 `admin_*` 不在 diff） |
| 三 | `application-build` ×2、`application-stage` ×2、`migration-plan` ×2、key-check | 全 0 |
| 四 | deploy commit → `flux-release` → 晋级 commit → `flux-source-apply` → wait → `application-check` ×2 | 全 0 |
| 四 | `git push origin qwen`（c5e443da..f3d0251f，双远程） | 0 |
| 五 | 浏览器走查 10 行 | 行 1–9 过；**行 10 未通过**（见 §5、§6） |

## 2. 镜像锁 / 迁移头 / 产物范围（第三节证据）

- 镜像锁 `source_revision` 四行（与 sources.yaml 钉一致）：knowbench-backend `7f5aa4e4`、knowbench-web `13f15c3d`、knowlab-backend `4e39358a`、knowlab-web `01514759`
- 计划迁移头不变：knowlab `20261016_0006`、knowbench `20261017_0020`
- key-check-done 之前无密钥文件（无 `BEGIN PRIVATE/PUBLIC KEY`）
- `git status` 仅两应用 backend+web 共 21 文件；`test-computer/workload.yaml` 与两 admin 前端均未变

## 3. 提交与推送链（第四节证据）

- deploy 提交 `638fe465` → `make flux-release` exit=0 → 晋级提交 `f3d0251f` → `flux-source-apply` exit=0
- wait exit=0：`knowbench-*` 与 `knowlab-*` 共 24 个 kustomization 全部 condition met
- `application-check` APP=knowlab exit=0、APP=knowbench exit=0
- 推送：`c5e443da..f3d0251f` 双远程（GitHub+gitee），HEAD=origin/qwen，本地领先 0

## 4. 关键验收（知账 134 修复生效）

两个 `application-check` 输出的 admin 面均出现 `admin_list_read: true`（web 面为 null 属正常，该项只测 admin 面）。走查行 1 复证：管理端「分身草稿」两列表正常加载，`POST /api/admin/v1/knowbot-requests/{id}/drafts` 返回 201。

## 5. 第五节走查逐行结论

| 行 | 结论 | 证据要点 |
| --- | --- | --- |
| 1 管理端两列表 | 过 | 两列表读得出；R5.4 提交「走查用：读我的表回答营收」在「用户的提交」；截图 01 |
| 2 knowlab web 我的数据 | 过 | 多「数字类尽量传表格」提示 |
| 3 新建分身验收用例栏 | 过 | `/zh-CN/knowbots/new`「验收用例」栏说明含「期望值只能由你自己填（比如从年报里查到的数），我们不代填」；截图 05 |
| 4 knowlab 页头当前用户 | 过 | 「退出登录」左为「当前用户：<显示名>」，停上去见邮箱 |
| 5 knowbench 侧栏当前用户+折叠 | 过 | 侧栏底「当前用户：<显示名>」；折叠后头像字、停上去见全名 |
| 6 分割线/双击复原/折叠钮/刷新 | 过 | 宽度跟变、双击复原、折叠态与宽度刷新后记住（所有者实操） |
| 7 导出 Word/Excel/PDF | 过 | 见 §6 硬核验；截图 06/07/08 |
| 8 受理关口无关问题 | 过 | 问「今天北京天气怎么样」：不报错、停下说明不归它/为什么/建议去哪问、给「照做」「不做了」；点「不做了」→ 委托「已取消」+「专家看这个问题不归它，你选择了不做」 |
| 9 本职问题不触发关口 | 过 | 问本职问题照常往下做，无「归不归」黄框 |
| 10 计算工具第二版 | **未通过** | 见 §6；截图 02/03/04 |

截图归档：`docs/rename-tools/qwen005-walk/01…08.png`（8 张共 2.7MB，**本提交不入库**，是否入库由 Opus 定）；R5.4 a/b 两张仍在 `docs/rename-tools/r54-walk/walk-a-b-*.png`（同样未入库）。

## 6. 行 10 与行 7 的详细证据

### 6.1 行 10：v2 测试未通过（发现，原样记录）

- 链路受理全正常：建 v2 草稿 201（02:24:44）→ 逐条核对 `rules-review` 204 → `…/test` 200 → knowbench `test-runs` 202
- 工具链按清单：`list_my_data` → `read_my_table` → `compute` → 复核取数 → 再 `compute`，未手算
- compute 正确：`{"id":"c103","name":"营业收入同比增长率","value":"0.1111","formula":"(cur - prev) / prev"}`，refs `…:data!营业收入@2024-12-31`(100) 与 `@2023-12-31`(90)，与 `r54-walk/data.csv` 逐格相符；截图 02
- 管理端判定：**c1 未通过 · 期望满足 0/1 · 「第 answer 步没过：取出的数与表里一致」**（`sourced` 验收失败）；运行终态 `stopped for a decision in the workbench (input)`（runner：`advisor stopped task=26c4b377… state=WAITING` + `step answer handed to human interaction=f7c9ded0…`）
- 与卡「要看到：测试通过 … 同比约 0.1111」不符：**值对（0.1111）、判定没过**
- 定位边界：判定分级不落 knowlab-api / knowbench-api / scheduler 的 INFO 日志；最终 answer JSON（`raw`/`growth` 原文）在测试账号侧页面亦不可见（见 6.2），故 `sourced` 失败的具体差异（地址串/值串写法）本次未能 pinpoint，不猜，交 Opus
- 对照基线（R5.4 c 首版）：v1 草稿 `479b1809` 测试 **c1 通过 · 期望满足 1/1**、状态「已交付 · 已发起 1 次」、规则出处三条逐条核对（核对人 d1c8037c…）；截图 01

### 6.2 发现：交回行文案与工作底稿空态矛盾

- v2 对话工作页「专家交回了」行写「已经写出来的底稿在右边栏『工作底稿』里。打开工作底稿」；右栏「工作底稿」实际显示「这段对话还没有请过专家，或者请的专家不写底稿。」（截图 03）
- 同类矛盾组件测试记过旧现网案例：`knowbench-web-frontend/app/tests/component/handback-line.test.tsx`（停下/打回时页面仍指向右边栏底稿）
- 测试账号侧入口补充记录：专家首页「等我决定的」琥珀色行整行不可点（设计如此），仅行右端按钮可跳且仅当委托挂得上对话才渲染；本次经侧栏「最近」的「分身测试 c1」进入（截图 04）

### 6.3 行 7 硬核验（导出产物拆包）

- 查看器三钮在：右栏打开 `财务分析与预测-成稿.md`（10.8KiB）见「下载 Word / 下载 Excel / 导出 PDF」（截图 06）
- Word（`财务分析与预测-成稿.docx`）：`word/document.xml` 含 `Heading1` 标题「上海机场（600009）财务分析与 2026 年第三季度预测」+ **6 个 `<w:tbl>` 表格** → 有标题与表格
- Excel（`财务分析与预测-成稿.xlsx`）：7 张工作表（`数据`、`数据(2)`…`数据(6)`、`出处`）= 每张表一张工作表；真数字格（无 `t="s"`）如 `0.4061`、`5750882944.36`、`2014` → 数是数字
- PDF：打印框共 5 页，预览只有成稿（页眉日期+标题+正文），无页面杂项（截图 07）；下载面板见 .docx/.xlsx 产物（截图 08）

## 7. 未决 / 交 Opus

1. 行 10 `sourced` 失败根因（交回物 `raw` 写法与表格的差异）需后端/契约侧定位；本次 UI 与日志均取不到 answer 原文
2. 6.2 的交回行文案与底稿空态矛盾是否立项修
3. v2 委托仍停在「待我决定」，所有者未点任何决定钮（走查纪律：只看不点）；是否由测试账号侧收尾由 Opus 定
4. 走查截图（qwen005-walk 8 张 + r54-walk 2 张）是否入库

## 8. 与 R5.4 的衔接

- R5.4 第 5 步 c（管理端建首版草稿并测试）已随本走查完成：v1 草稿建成、测试 1/1 通过、已交付
- R5.4 第 5 步余下各步待 qwen-005 审过后从 c 之后续走；`r54-walk/manifest.json`、`manifest-compute.json` 的 `data_bindings` 占位已替换为真值（dataset_id `ca0749ac-a810-4e06-ab7e-952b9cefe7e3`、version `"1"`、sha256 `c31ef87a…3ac06f`），随本提交入库

exit=0（第一~四节全部命令闸门；第五节走查行 10 未通过，见 §6.1）
