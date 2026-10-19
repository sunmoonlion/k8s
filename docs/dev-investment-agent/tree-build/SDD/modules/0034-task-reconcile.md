# 委托没人推时不卡死：runner 每轮对账（0034）

> 状态：**草案，待所有者与评审看过再写代码**（Opus 2026-10-19 起草）。排在 K19 之后、K21 之前。
> 起因：K19 第 2 稿受理后一直不开跑（qwen-011 第五节）。所有者：「好像不稳健啊，就断了一次，出这么多问题」；评审（所有者转来）：「别再打补丁，而是换掉一个前提……按状态对账，不靠信号」。本页照评审的方向写，Opus 补了代码核对与取舍；评审第二、三轮意见已并入，第三轮评审认为可以定稿。

## 一、出了什么事

| 时间（Z） | 事 | 代码 |
| --- | --- | --- |
| 10-18 15:08 | 第 1 稿 c1 判分崩溃（旧代码，qwen-009 之前），委托 `03e447a0` 停在 RUNNING，推它的协程没了 | 当时 `_drive` 崩了只记日志 |
| 10-18 16:09 起 | qwen-009 部署滚了 runner；新 Pod 与旧 Pod 同名 `sunmoon-kind-r1`（`WORKBENCH_RUNNER_ID` 是固定配置） | `config.yaml:78` |
| 同上 | 新 Pod 不接管：接管只在「首次建租约或换了 runner 名字」时做，靠 `acquired_at` 不到 1 秒判断；同名续租不重置 `acquired_at` | `repository.py` `acquire_leases`，`runner.py` `_take_over` |
| 同上 | 沙箱上没有待办命令就不拿租约，没驾驶者的委托没人看 | `acquire_leases` 的 `wanted` 只看 `workbench_commands` |
| 10-18 22:55 | 测试超时：给委托记了取消、发了一条 `turn.interrupt`（执行成功），但 RUNNING 的取消要等推它的程序下一步来落实——没有这个程序 | `ledger.py` `request_cancel`，`advisor.py` `_step_once` |
| 10-19 00:31 | 第 2 稿 c1 委托 `00815b28` 建好，因为同一个项目一次一位专家，排在 `03e447a0` 后面；放行只在前一位到终态的那一刻做 | `ledger.py` `_start_next_queued` |
| 10-19 01:4x | 所有者授权丙案：插一条 `task.drive`，runner 推一下，第一步看见取消，收成 CANCELLED，放行 c1 | — |

## 二、根子

「这个委托有没有人在推」只存在 runner 进程的内存里（`driving` 字典），库里没有。系统只能靠一次性的信号推动：一条命令、一次接管、`acquired_at` 不到 1 秒。信号丢一次——进程重启、协程崩了、同名接回租约——委托就永远停着，没人发现。

测试推进器（conductor）没卡，因为它本来就是每 5 秒按库里的状态算一遍该做什么；卡的是委托这一层，它靠命令触发。

**反例**：Opus 先写的补丁（重启后把手里的沙箱都当新接管，重推 RUNNING 的委托）在全量测试里挂了一条（`test_advisor_policy_lets_in_project_file_changes_through_without_asking`）。重推 RUNNING 的委托等于从当前步重开一轮，而 Codex 那一轮可能还在跑：双跑、双花钱，或者撞上还没结束的那一轮而失败。补丁没提交，存档在远程机草稿目录。

## 三、做法

前提：**现在只有一个 runner**（部署 `replicas: 1`、`strategy: Recreate`，新 Pod 起来前旧 Pod 已经停了）。所以「库里在跑、本进程没在推」就一定是没人推。多 runner 之前要先做第五节的心跳。

### 1. 取消、超时直接收尾，不等推它的人

- `request_cancel` 对 RUNNING 的委托：同一事务里带版本号（CAS）写成 CANCELLED，关掉打开的那一轮尝试（记 CANCELLED、`failure_code=cancelled`；这时不知道这一轮花了多少，`consumed` 填 0，这一轮的预留全部退掉），照常记事件、放行排队的下一位；`turn.interrupt` 照发，只算尽力而为。
- 推它的程序如果还活着，怎么判、怎么停（点名）：它这一轮跑完要写尝试与委托（`advisor.py` 345 的 `attempt_transition(…, RUNNING, turn_id)` 等），会撞上两种错——`StaleStateVersion`（`repository.py` 537、917）和从终态出发时状态机校验抛的错。`_drive` 接住这两种，重读一次委托：已是终态就**补记这一轮的费用**：同一事务里带版本号改委托的 `budget.used`（加上这一轮花费），并追加一条费用事件（花费、token、turn 编号）——今天的费用不只靠事件，`attempt_transition` 带 `consumed` 时会同时改 `budget.used`、退预留（`ledger.py` `attempt_transition`），只追加事件会让页面上的实时成本和事后对账偏低；预留已在取消方关尝试时退了，补记不再碰预留。记一行 info 返回；不是终态照旧往上抛。尝试已由取消方关掉，驾驶者不再改它。
- `fail_after_crash` 看到 `cancel_requested_at` 有值时写 CANCELLED，不写 FAILED。
- 测试超时（`test_runs.py` `_time_out`）走同一条路，不另写。

### 2. runner 每一轮对账

`run_once` 每轮在拿租约之后、领命令之前：

- **拿租约**：沙箱上有待办命令、**或者有委托在 QUEUED / RUNNING / WAITING**，都去拿（没有租约、租约过期、或本来就是这个名字的）。WAITING 要算上，不然下一条作废审批没机会跑。
- **作废随旧连接消失的工具审批**：进程第一轮，以及**每次实际重建某个沙箱的 app-server 连接时**（`ensure_connected` 重连那一刻，它本来就会清 `live_threads`；同一进程里断了再连也算），作废它上面 pending 的 `tool_approval`（`expire_pending_tool_approvals` 现成的，发 `interaction/expired`）。app-server 那边的请求随旧连接消失，Codex 会重问；不作废的话，等审批的委托重启后会永远等。这是今天 `_take_over` 做的另一件事，同名重启后同样从没跑过。
- **QUEUED 且本进程没在推**（`driving` 里没有，或协程已结束），**且这件委托没有 pending 或 claimed 的 `task.drive`**：排一条 `task.drive`。还没开工，推它不会双跑；后一个条件免得命令没被领走时每 5 秒排一条。
- **RUNNING 且本进程没在推**：**不重开**。先对那条线发一次中断（尽力而为，把可能还在跑的那一轮停下），再把委托收成 FAILED，原因「推它的程序重启了，这一步没做完」，reason 里带打开的尝试编号与 turn 编号（演练和管理端才分得清这是「重启没做完」还是真的平台错），`failure_code=platform`（同 qwen-009 的平台失败），关掉打开的尝试。测试里这一条用例记平台错误，不算专家数不对。
- **项目排队**：项目里没有活跃委托却有排队的，放行最早的一件（`_start_next_queued` 已有，改成每轮也调，不只在终态那一刻）。
- 去重照旧：`handle` 里 `driving` 有活着的协程就不再推。

推它的协程崩了而进程还活着（qwen-009 之后崩溃会收成 FAILED，但别的路径还可能漏），下一轮对账同样收住。

### 3. 有上限、看得见

- **测试超时不算排队时间，但排队有上限**：用例的委托 RECEIVED 且排在别人后面时，`waiting_since` 照问用户那样计入 `waited_seconds`（`test_runs.py` 已有这套记账）。排队本身超过这次测试的 `timeout_seconds` 就按超时收尾，原因写「排队过久，排在委托 X 后面」——挡路的若是测试账号另一件正常的长任务，测试也不会无限期「测试中」。
- **管理端看得见在等什么**：135 的 `progress` 再加一个可选字段 `queued_behind`（只有一个委托编号，C-L5），管理端写「排在前一个委托后面，等它结束」；测试停在「已受理」时写「已受理，等测试电脑接手」，不写「已跑 x 分钟」（账 136 第 ②）。契约照规矩先 knowlab 后 knowbench。

### 4. 部署前看一眼

发布卡在「提交、发布」之前加一步只读查询：有没有 RUNNING 的委托。有就停，交所有者定等它跑完还是照部署（照部署它会按第 2 条收成 FAILED、写明原因）。以后这就是 Jenkins 流水线第 1 步「核对」的一项（0033，fable 分支 `85265f5a`）；两页互相引用，不各写各的——0033 合进来后在它那边补一句指回本页。

## 四、故障演练（本地集群，正跑着测试时做）

每一种都要在**限定时间内**要么接着跑、要么结束并在管理端写清原因；不许「一直测试中、没原因」。

| # | 制造什么 | 应当看到 |
| --- | --- | --- |
| 1 | 删测试电脑 Pod | 代理用持久卷上的凭据连回；正跑的一轮断了之后怎么收（步骤时限 15 分钟到了是重试还是判失败）**由演练确认**——代码里 `_requeue` 只在几种可重试失败时调，没证实会重试 |
| 2 | 边缘断开 5 分钟（停远程机 frps 之外的办法另定，不碰现网边缘） | 代理在边缘回来后 30 秒内重连（账 136 代理修复，0.5.1） |
| 3 | runner 同名重启时正跑着任务（今天这个洞） | 下一轮对账把那件委托收成 FAILED（平台、原因写明），测试接着下一条用例 |
| 4 | 推它的协程崩了、进程还活着 | 同 3 |
| 5 | 正跑着时超时 | 委托直接 CANCELLED，不等推它的人 |
| 6 | 排在一个卡住的委托后面 | 管理端写「排在…后面」；排队时间不算进测试超时；排队超过测试时限按超时收、原因写明 |
| 7 | runner 同名重启时一件委托正等工具审批 | 旧审批作废、发 `interaction/expired`；Codex 重问，新审批能答 |
| 7b | 不重启 runner，只断它到沙箱 app-server 的连接（一件委托正等工具审批） | 同 7：重连时旧审批作废，Codex 重问 |

## 五、这一版不做

- **委托心跳**（`driver_id`、`driver_heartbeat_at`）：多 runner 之前必须有，单 runner 时对账已够。
- **接回正在跑的那一轮**：重启后不重开、也不判失败，而是接上 Codex 那一轮等它结束取结果。要先查 Codex app-server 能不能按 `turn_id` 查一轮的状态，单独设计。做之前，部署时正在跑的委托会明确失败（第三节第 2 条）。
- **runner 名字改用 Pod 名**：只修重启这一种情况，修不了协程崩了；对账之后不需要。

## 六、测试

- 同名重启：委托 RUNNING、记着取消、没有待办命令 → 一轮后 CANCELLED（第 1 条直接收尾，不靠重推）。
- 同名重启：委托 RUNNING、没取消 → 一轮后 FAILED（平台），reason 带尝试与 turn 编号；没有新开一轮（Codex 假服务端没收到第二个 `turn/start`）。
- 同名重启：委托 WAITING 等工具审批 → 一轮后旧审批 expired、有 `interaction/expired` 事件。
- 协程崩了进程活着 → 同上。
- 委托 QUEUED、没人推 → 一轮后有一条 `task.drive`；连跑三轮仍只有一条（命令没被领走时不重复排）。
- 取消时推它的程序还活着 → 只有取消方写成终态；推的那方撞 `StaleStateVersion` 后安静停下、补记费用，不记平台失败；补记后委托的 `budget.used` 比取消前多出这一轮的钱，`budget.reserved` 不变。
- 同一进程里沙箱连接断了再连、委托正等工具审批 → 旧审批 expired。
- 崩溃时委托记着取消 → `fail_after_crash` 写 CANCELLED。
- 项目里前一位已终态、排队的没放行 → 一轮后放行。
- 测试：排队时间不算进超时；排队超过时限按超时收、原因带挡路的委托编号；`progress.queued_behind` 过 knowlab 的 schema。
- 已有的全量测试照过，特别是上面那条反例。

## 七、代价

- knowbench 后端：`ledger.py`（取消直接收尾）、`runner.py`（对账、作废旧审批、`_drive` 撞终态安静停下）、`advisor.py`（`fail_after_crash` 见取消写 CANCELLED）、`repository.py`（租约、查没人推的委托）、`test_runs.py`（排队不计时、`queued_behind`）；knowlab 后端与管理端（契约可选字段、显示）。没有迁移。
- 部署时正在跑的委托会失败（原因写明），直到第五节「接回那一轮」做完。
