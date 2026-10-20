# qwen-012 回执（本地机 Qwen）

卡：`docs/dev-investment-agent/switch-test/inbox/qwen/2026-10-19-qwen-012-k21-hire.md`（K21：sig-am 在工作台请「财务分析与预测」、真问一句；**不改钉、不构建、不部署，只走查**）。

纪律与边界：全程只读 SELECT，不写库、不碰集群/配置/部署声明；不导出 cookie、令牌；模型 key、连接码、代理令牌一律不入回执、不截图、不出现在对话里（第 3 行只记「已有 / 所有者新登记」）；截图不拍 `code=`、`token=`、`state=`。回执在 k8s 本地提交后**停下不推**（推回由所有者 `human-remote.sh`），等 Opus 审。

## 一、前置

### 库内凭据（Qwen 只读，2026-10-20 02:4x UTC 取；data-platform-dev/postgresql-0）

第 1、2 行——knowmart 里这位专家与交付版：

```text
select id, owner_subject, name, category, visibility, current_version, created_at from knowbot where id::text like '084acc72%';
                  id                  |            owner_subject             |      name      |   category    | visibility | current_version |          created_at
 084acc72-f396-453f-ad70-d300695678dc | 721f2c10-db3f-4ca4-b6bf-093bb4420ea7 | 财务分析与预测 | uncategorized | private    | 1               | 2026-10-19 17:02:45.800791+00

select knowbot_id, version, status, digest, delivery_id, delivered_at from knowbot_version where knowbot_id::text like '084acc72%';
              knowbot_id              | version | status |                                 digest                                  |                    delivery_id                     |         delivered_at
 084acc72-f396-453f-ad70-d300695678dc | 1       | active | sha256:068ea80e27ff262732ff2f8eded55fbe7e5c5d8801ce08b74677a9b2269f1f32 | knowlab-draft-1d4122f0-6e13-4ac4-9473-5f79f079e992 | 2026-10-19 17:02:45.800791+00

select jsonb_array_length(manifest->'data_bindings') as bindings from knowbot_version where knowbot_id::text like '084acc72%';
 bindings
        6
（6 个 dataset_id：98ebc9fc-3cf0-40cb-9065-1a3ffbfb0d50（Excel 工作簿）、35da3157…、538285ed…、f4703e18…、3103d049…、d1bfb7a8…（2021–2025 五份年报））
```

对卡：`owner_subject=721f2c10-db3f-4ca4-b6bf-093bb4420ea7` 即 sig-am（knowbench `auth_user` 里 id `9d82c9f9-1895-4e77-8b12-c07c9d6f0c02`、username `sig-am`），故第 2 行 sig-am 在 knowmart 能看到这位专家（visibility=private、作者本人）；`current_version=1`、`knowbot_version` 第 1 版 `status=active`、digest 与 qwen-015 记录的 delivery digest `sha256:068ea80e…` 一致、`delivery_id` 指向分身 1.3 草稿 `1d4122f0-6e13-4ac4-9473-5f79f079e992`；「需要的数据」为 **6 份**（1 个 Excel + 5 份年报），与卡面第 2 行一致。

第 3 行——sig-am 自己的模型 key 与云端沙箱：

```text
select provider, status, created_at, revoked_at from workbench_credentials where owner_actor_id='9d82c9f9-1895-4e77-8b12-c07c9d6f0c02';
 provider | status |          created_at          | revoked_at
 kimi     | active | 2026-10-17 15:07:01.25149+00 |

select id, status, provisioned, codex_version, relay_user, updated_at from workbench_sandboxes where owner_actor_id='9d82c9f9-1895-4e77-8b12-c07c9d6f0c02';
                  id                  | status | provisioned | codex_version |   relay_user   |          updated_at
 c678ec57-a068-4365-9aac-999ab276cb7e | ready  | t           | 0.155.1       | u-9d82c9f91895 | 2026-10-18 01:50:36.468587+00
```

对卡：模型 key **已有一把**（provider `kimi`、status `active`，2026-10-17 登记）→ 按卡面口径记「已有」，不需所有者新登记（key 内容不记）；云端沙箱库侧 `status=ready`、`provisioned=true`（codex 0.155.1、relay_user `u-9d82c9f91895`），页面是否显示「在运行」以所有者第 3 行所见为准。

第 4 行——本机代理改连前状态：

```text
select p.machine_name, p.status, p.agent_version, coalesce(u.username,'(空)') as owner_name, p.last_polled_at, p.created_at
from workbench_agent_pairings p left join auth_user u on u.id=p.owner_actor_id order by p.created_at desc limit 3;
 machine_name |  status   | agent_version | owner_name |        last_polled_at         |          created_at
 zymun        | delivered | 0.5.0         | zymun      | 2026-10-18 03:28:46.043446+00 | 2026-10-18 03:28:39.970377+00
 zymun        | delivered | 0.5.0         | sig-am     | 2026-10-18 01:50:20.898611+00 | 2026-10-18 01:48:46.909306+00
 zymun        | delivered | 0.5.0         | zymun      | 2026-10-17 16:10:42.392132+00 | 2026-10-17 16:10:36.311181+00
```

对卡：最近一次配对（2026-10-18 03:28Z）owner 是 **zymun**，与卡面「它现在连在 zymun 下」一致；本卡第 4 行由所有者亲手把它改连到 **sig-am**（托盘「重新连接账号」→ 浏览器用 sig-am 登录 → 确认页写「允许后，这台电脑连到账号「sig-am」」→ 点「允许」）。走完是否改回 zymun 由所有者定。配对表只是历史配对记录，代理当前在线与否以工作台「设置 → 我的电脑」页面为准。

### 第 1–4 行（所有者操作）——待回报

| # | 要看到（卡面） | 所有者所见 |
| --- | --- | --- |
| 1 | 管理端「专家」→「财务分析与预测」：「各版本」里有第 1 版、「knowmart 编号 084acc72-f396-453f-ad70-d300695678dc」、出自分身 1.3 | 待填 |
| 2 | knowmart（sig-am）页头「专家」→「财务分析与预测」：第 1 版「可用」；「需要的数据」6 份（1 Excel、5 年报） | 待填 |
| 3 | 工作台（sig-am）「设置」：模型 key 已登记一把；「我的电脑」里云端沙箱在运行。用的是**已有**还是**所有者新登记**（只记这两字，不写是哪把） | 待填 |
| 4 | 托盘「重新连接账号」→ sig-am 登录 →「允许」；工作台「设置 → 我的电脑」（sig-am）里这台电脑在线、「最近一次联系」是刚才（北京时间） | 待填 |

## 二、请专家、问一句（第 5–9 行）——待

| # | 谁 | 做什么 | 结果 |
| --- | --- | --- | --- |
| 5 | 所有者 | 工作台（sig-am）新建项目 →「专家」→「去 knowmart 选专家」→ knowmart 上方写「从工作台来」→「财务分析与预测」点「请这位」→ 回工作台 | 待填（「请哪一位」里能否选到） |
| 6 | 所有者 | 问：「贵州茅台近三年的营业收入和归母净利润走势如何？预测下两个季度。」（与第 3 稿 c1 同问） | 所有者已问出去。Qwen 侧地面真相：任务 `0d1b7cd2-ff15-488b-8eca-6f819c025f03` created_at `2026-10-20 05:48:58.858917+00`，05:48:59Z runner `took over sandbox=c678ec57-a068-4365-9aac-999ab276cb7e`（即库里 sig-am 那个云端沙箱）、`sandbox link up ws://sandbox-u-9d82c9f91895.sandbox-platform-dev…:47800`；「请哪一位」能否选到仍待所有者回报 |
| 7 | Qwen | 开跑后每半小时 runner 日志核 | 见第三节（首核 05:50Z/05:53Z：在跑） |
| 8 | 所有者 | 跑完看交回那一行 →「打开工作底稿」 | 待填（成稿实际路径、各分节实际标题、有无「目标价/评级/建议买入」字样） |
| 9 | 所有者 + Qwen | 成稿与第三节参照值逐项对 | 见第四节 |

## 三、第 7 行日志核（Qwen，开跑后每半小时）——首核已做，在跑

命令（卡面原文）：

```bash
$K -n app-platform-dev logs deploy/knowbench-runner --since=40m | grep -E "advisor (stopped|crashed)|budget exhausted|workbench_mcp_result_too_large"
```

判据：没有 `advisor crashed`、没有 `workbench_mcp_result_too_large`；跑完有 `advisor stopped task=… state=SUCCEEDED`。若问出去 10 分钟还没开始第一步、runner 也没有这次的日志：多半是代理卡在半开连接（待办账 136），告知所有者由其在托盘重启代理，**不动集群**。

### 首核 #1（05:50:41Z，问出去约 1 分半后）

卡面命令 `--since=40m` 结果：**零命中**（三条坏判据都没出现，也还没有 `advisor stopped`）。runner 近 15 分钟原始尾（截断到工具描述前）：

```text
2026-10-20 05:48:59 - app.application.workbench.runner - INFO - took over sandbox=c678ec57-a068-4365-9aac-999ab276cb7e expired_approvals=0
2026-10-20 05:48:59 - app.application.workbench.runner - INFO - sandbox link up sandbox=c678ec57-a068-4365-9aac-999ab276cb7e url=ws://sandbox-u-9d82c9f91895.sandbox-platform-dev.svc.cluster.local:47800
2026-10-20 05:49:06 - … - INFO - mcp elicitation sandbox=c678ec57-… mode=form message=Allow the sunmoon_workbench MCP server to run tool "list_my_data"? meta={… "tool_params": {"task": "0d1b7cd2-ff15-488b-8eca-6f819c025f03"} …}
2026-10-20 05:49:13 / 05:49:35 / 05:50:25 - … - mcp elicitation … tool "read_my_table"?
2026-10-20 05:49:54 - … - mcp elicitation … tool "compute"?
```

runner/api Pod 均 1/1 Running、0 重启（16h）。

审批询问行按纪律不单独当「在跑」的证据，故补只读库活体信号：

```text
T1 05:51:13Z  workbench_tasks id=0d1b7cd2-…  state=RUNNING state_version=10 current_step=1 waiting_reason=(空) created_at=2026-10-20 05:48:58.858917+00 updated_at=2026-10-20 05:50:10.773573+00
T1  workbench_sandbox_leases  sandbox_id=c678ec57-… runner_id=sunmoon-kind-r1 acquired_at=2026-10-18 01:51:07.16302+00 expires_at=2026-10-20 05:51:43.321403+00
T1  最近事件（新→旧，8 条）
  05:50:31.196250  item/reasoning/summaryPartAdded
  05:50:31.190241  item/started
  05:50:25.498782  thread/tokenUsage/updated
  05:50:25.481878  item/completed
  05:50:25.435170  thread/status/changed
  05:50:25.407276  records/read
  05:50:25.392917  serverRequest/resolved
  05:50:25.386501  thread/status/changed
T2 05:52:28Z  state=RUNNING state_version=10 current_step=1 updated_at=2026-10-20 05:50:10.773573+00
```

（`workbench_sessions` 无 `state` 列，该查询报 `ERROR: column s.state does not exist`，未改口径，改以事件流与租约判活体。）

### 首核 #2（05:53:14Z）

```text
最近 6 条事件（新→旧）
  05:53:05.190441  item/completed
  05:53:03.975875  item/started
  05:53:03.968604  item/completed
  05:52:52.846458  item/reasoning/summaryPartAdded
  05:52:52.840306  item/started
  05:52:47.193550  item/completed
近 3 分钟事件计数 last3m=49
租约 runner_id=sunmoon-kind-r1 expires_at=2026-10-20 05:53:44.775257+00 updated_at=2026-10-20 05:53:14.775257+00（每约 30 秒续一次）
runner --since=3m 尾：05:50:25 之后无新的 elicitation 行（审批已解决、工具结果在回填），无坏判据
```

判定：**在跑**（有执行类条目 + 事件流活跃 + 租约在续），未终态。`state_version`/`current_step` 在步内取数期间不动，属正常；活体以事件流与租约续期为准。

后续：`/tmp/q012-line7-poll.sh`（pid 1989631）每 1800 秒记一轮到 `/tmp/q012-line7.log`，命中 `advisor stopped` 自停，最多 8 轮；用完删除。轮询只在本地记日志，Qwen 不能主动说话，故跑完由所有者叫一声后 Qwen 补写终态——这一点在上一张卡（qwen-015）上是 Qwen 的漏，已按同一坦白口径写在这里。

## 四、第 9 行：成稿与参照值逐项对照——待成稿

| 哪一项 | 参照值（卡面第三节） | 成稿里写的 | 对不对 |
| --- | --- | --- | --- |
| 勾稽 | 三表各 22 期、期初期末 4 年全部平（差额 0），无剔除期 | 待填 | 待填 |
| 对照官方披露（管理层讨论） | 五份年报都找得到，PDF 第 7–17、7–19、7–20、7–21、8–22 页；抽验：归母净利 2024 同比「同比增长15.38%」（2024 年报第 8 页）、营收 2025 −1.21（2025 年报第 9 页变动分析表） | 待填 | 待填 |
| 毛利率 2021–2025 | 0.9154、0.9187、0.9196、0.9193、0.9118 | 待填 | 待填 |
| 净利率 | 0.494、0.5054、0.506、0.5046、0.4876 | 待填 | 待填 |
| 净资产收益率 2022–2025 | 0.3241、0.3618、0.3843、0.3446（2021 不适用） | 待填 | 待填 |
| 经营现金流 / 归母净利润 | 1.2205、0.5852、0.8911、1.0723、0.7474 | 待填 | 待填 |
| 营收同比 2022–2025 | 0.1687、0.1901、0.1571、−0.0121 | 待填 | 待填 |
| 归母净利润同比 | 0.1955、0.1916、0.1538、−0.0453 | 待填 | 待填 |
| 预测用增速（最近 4 季同比中位数；8 季最小、最大） | 营收 −0.022887（−0.194294 ～ 0.152937）；归母净利润 −0.032121（−0.303429 ～ 0.162081） | 待填 | 待填 |
| 营收预测 2026Q3 | 点 38,170,287,386.44；区间 31,474,383,790.80 ～ 45,038,738,230.34 | 待填 | 待填 |
| 营收预测 2026Q4 | 点 39,460,117,213.79；区间 32,537,949,244.21 ～ 46,560,663,055.47 | 待填 | 待填 |
| 归母净利润预测 2026Q3 | 点 18,606,297,234.92；区间 13,390,730,733.10 ～ 22,339,594,615.70 | 待填 | 待填 |
| 归母净利润预测 2026Q4 | 点 17,124,993,245.27；区间 12,324,653,877.03 ～ 20,561,071,451.55 | 待填 | 待填 |
| 回测（2025Q3、2025Q4、2026Q1、2026Q2）相对误差 | 营收 0.110568、0.351758、0.024542、0.091641，平均 0.14462725；归母净利润 0.11861、0.556255、0.013721、0.084644，平均 0.1933075；8 个回测点 4 个落在区间里（末位差 1 算对上） | 待填 | 待填 |

对不上的只记「哪一项、成稿写的是多少」，不自己改，交 Opus 判是方法执行偏了还是参照值口径不同。

## 五、花费与用时——待

这次请专家页面显示的花费与用时（参照：第 3 稿测试这一问约 52 分钟、约三十元上下）。
