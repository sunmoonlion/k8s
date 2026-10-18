# qwen-007 续跑（旧钉）＋补二（新钉）回执

本地 2026-10-18 20:51。执行者 Qwen。卡：`docs/dev-investment-agent/switch-test/inbox/qwen/2026-10-18-qwen-007-release.md`（含 Opus 补一 3b00ddf4、补二 4e4f46d5）。

## 0. 提交链与推送

| 轮 | 提交 | 推送 |
| --- | --- | --- |
| 停点回执 | `a9779263` | 已双推 |
| 续跑旧钉 deploy / 晋级 | `e8c3e8e4` / `1121704b` | 当时被拒（origin 已含 Opus 补一，分叉），未强推 |
| 补二合并（含上两提交入库） | `a4fcdf47`（merge --no-edit origin/qwen @4e4f46d5） | 已双推 |
| 补二 deploy / 晋级 | `dcadd598` / `6cc5c0c2` | 已双推，HEAD=origin/qwen=`6cc5c0c2` |

分叉经过：续跑指令无 pull 步，按旧钉 `95c437bb` 跑完三四节并应用集群；Opus 中途推补一/补二。所有者选 A，按卡「补二：滚前进」只补差，不整张重走。

## 1. 停点轮（容量闸门，详见 qwen-007.20261018-1902.md）

第一、二节全 0（pin 31 行）；第三节 build knowlab **exit=2** 停：`capacity.yaml:47` 闸门 `remaining 8129286144 < minimum 10737418240`、`passes:false`。不重试不退回，停点回执闭环。

## 2. 续跑旧钉轮（第三、四节，旧钉 95c437bb）

容量读数（所有者要求写进回执）：
- 第三节开头按同参数直跑 `windows-capacity.ps1`（platform-status 只装 helper 不打印读数，取数方式如实注明）：`checked_at 2026-10-18T11:26:04Z`、`c_free_bytes 94256074752`、`remaining_after_growth_and_plan_bytes 21447151616`、`passes:true`（终端记录，无 /tmp 日志）。
- 同轮 build 内闸门首读：`11:37:28Z`、`c_free 144382640128`、`remaining 76875317248`、`passes:true`（/tmp/q007-s3b.log L214-229）。

第三节（五构建五暂存五计划）全 exit=0。13 镜像锁 source_revision（旧钉）：

```
knowbase  admin f0974950  backend ad1e2edc  web 8c338db2
knowbench backend 68b59249  web 96323721
knowfeed  admin b344c106  backend 6239d224  web bca159f7
knowlab   admin fc445354  backend 836587c8  web e9bb849c
knowmart  backend c00eebf3  web 5ef6a080
```

knowbench web runtime diff = `+ # 内部接口不经公网…` `+ - path: /api/internal` `+ pathType: Prefix` + backend 三行；knowbase runtime `grep -c knowbase-sandboxes-in` = 1；五计划迁移头 `20261017_0020 / 20261018_0007 / 20261018_0006 / 20261015_0014 / 20260927_0007`，均 ok=16 failed=0。

第四节：deploy `e8c3e8e4` → flux-release 0 → 晋级 `1121704b` → apply 0 → wait 0 → `delete networkpolicy knowbase-sandboxes-in` 成功 → 残留 `investment-sandboxes-in` + `knowbench-sandboxes-in`（观察 O3）→ check×5 全 0（knowbench/knowlab admin 面 `admin_list_read: true`）→ 测试电脑 `1/1 Running` 抹码日志仅启动+relay → 公网 `/api/internal` **404**。推送被拒后停手报所有者。

## 3. 补二轮（新钉 4e4f46d5）

三父仓：knowbench `57a67be`、knowlab `81a589a`、knowmart `a7f6847` ✓。
第二节：pin exit=0，`git diff … | grep -c '^+ '` = **11** ✓。
第三节（只做三应用）：build/stage/plan 全 0；**变的镜像锁恰 4 个**：knowbench-web `4b177c13`、knowlab-web `a41861d7`、knowlab-admin `9865e3bb`、knowmart-web `50e280ea`；暂存改动只在这四个前端 workload（各 2 文件）；三迁移头不变；后端/knowfeed/knowbase 无镜像锁变化 ✓。
第四节：deploy `dcadd598` → release 0 → 晋级 `6cc5c0c2` → apply 0 → wait 0（三应用）→ np 删除确认行（`--ignore-not-found`，exit 0，残留同 O3）→ check×3 全 0（knowbench/knowlab `admin_list_read: true`，knowmart admin 面 null×2 照旧）→ 测试电脑 `knowbench-test-computer-58bdd469cf-zdrt9 1/1 Running 3h34m`，抹码日志仅启动+relay 行、无新连接码 → 公网 `/api/internal` **404** → push `a4fcdf47..6cc5c0c2` 双推。

## 4. 迁移头对照

| 应用 | 旧钉轮 | 补二轮 |
| --- | --- | --- |
| knowbench | 20261017_0020 | 20261017_0020（不变） |
| knowlab | 20261018_0007 | 20261018_0007（不变） |
| knowmart | 20261018_0006 | 20261018_0006（不变） |
| knowfeed | 20261015_0014 | （补二未跑） |
| knowbase | 20260927_0007 | （补二未跑） |

## 5. 第五节走查九行判词

| # | 判词 | 证据 |
| --- | --- | --- |
| 1 | 过 | 截图：卡「读表报营收」写「未分类 · 第 1 版」、左树「未分类·1」、页头「全部/未分类」 |
| 2 | 过 | 截图：候选只「读表报营收」、链接「去 knowmart 选专家」、页面无「分身」二字 |
| 3 | 过 | 截图：设置页模型/审批块下无「MCP 连接」块 |
| 4 | 过 | 截图＋集群：点「更新沙箱」后 provision 审计 `12:31:30 owner=c17de2d4-243c-… status=ready`；新沙箱 `sandbox-u-c17de2d4243c-6f9fb5d58f-8hhvv` 1/1 Running；exec codex 容器取 78 个环境变量**名**：`KNOWBASE_MCP_URL`/`KNOWBASE_MCP_TOKEN` 命中 **0**（仅工作台自有 `WORKBENCH_MCP_URL/TOKEN`）；值未取未贴 |
| 5 | 过 | 所有者确认、免截图；源码核 `50e280e`：拉伸链接整卡可点（`after:absolute after:inset-0`），底行 `relative z-10`「去工作台请」只跳工作台 |
| 6 | **未通过——平台 F2**（非专家质量） | 见下 |
| 7 | 证据与卡预期不符（同 F2 根） | exec#1（点前）/#2（跑中 12:39-12:42）/#3（12:49:30 跑后）`/workspace/runs` 均不存在；卡预期「跑中有一个 2026…-<测试号> 目录」未出现，因测试从未开跑 |
| 8 | 未触发 | 测试未跑，无「待回答的问题」冒出 |
| 9 | 过 | 截图：sig-am 侧栏 zymun「离线」、无「就是这台」、下句「你现在用的这台电脑（zymun）连在别的账号上……」 |

### F2 证据链（第 6 行）

- 12:36:23 建草稿 201（第 2 版修订 3）、12:36:35 rules-review 204、**12:37:08 `POST …/drafts/0b562094…/test` 200 + knowbench `test-runs` 202**（受理成功）；
- 12:37:14 测试电脑收到 3 个 fs 调用：`fs/readDirectory` code -32012、2× `method unknown` -32601——与 `_finish` 删目录清理（folders.remove）形态吻合；**此后 runner 与测试电脑全静默**；
- knowbench-runner 自 12:36 起**零日志**（conductor 5s 一轮；以往开跑会打 `took over sandbox`/`advisor stopped`）；源码中唯一「无日志终态」路径为 [advance→_account 抛 KnowbotTestUnconfigured→_finish(error)](knowbench-backend app/app/application/workbench/test_runs.py L412-415)；
- 部署清单 `KNOWBOT_TEST_SUBJECT: 1929b2c2-…`、`KNOWBOT_TEST_WORKSPACE: /workspace` 均在（gitops workload.yaml L54-55）→ 抛点收窄为「测试账号从未登录」或「测试电脑未配对」两句之一；具体句在 knowbench 测试记录 error 列，**不挖库**，原样交 Opus；
- 管理端卡「测试未通过 · 已发起 1 次」、**无 c1 明细块**（与「一条用例都没跑」吻合）；
- 按纪律不重试、不改清单。怀疑 qwen-006/007 knowbench 后端换钉引入的回归（qwen-005 同链路曾跑通 SUCCEEDED），请 Opus 比对 `68b5924` 与旧钉的 `actor_for_subject`/`list_environments` 语义。
- 附带观察：清理时 2× `method unknown`(-32601) 提示 folders.remove 调了 agent 0.5.0 未实现的 fs 方法；本次目录本不存在，无实际危害。

## 6. 交 Opus 的发现/观察汇总

- **F1**（qwen-006 续跑回执 `e6b993d0`）：failed 草稿 UI 与后端双拦、无重测通路。
- **F2**（本轮）：分身测试在 `_account` 静默 error 终态，从未开跑。
- **O1 已修复**：knowmart 网页 `50e280e` 整卡可点（旧钉仅标题可点）。
- **O3**：np 精删后残留 `investment-sandboxes-in`（改名前遗留，集群 prune:false）；卡预期只列 `knowbench-sandboxes-in`。两轮一致。

## 7. 各轮 exit 汇总

停点轮：一/二节 0、build knowlab 2（停）。续跑旧钉轮：三节 15 步全 0、四节全 0（push 被拒另记）。补二轮：二节 0、三节 9 步全 0、四节全 0、push 0。走查：6 行过、1 行未通过（F2）、1 行证据不符（同根）、1 行未触发。
