# 换机测试：这台机写代码，本地跑测试

这台开发机磁盘与内存都小（3.6 GB 内存、2 核），**只用来写代码和文档**，不跑集群、不跑重服务。
需要真跑的测试在本地机器上做，输出进 git 回来。

本文放**怎么测的约定与模板**，长期有效。一次性的环境配置在 `../tree-build/human-ai-turn/imp/luna-local-setup.md`。
**现在要跑什么，只看 [`inbox/`](inbox/README.md)**：一个文件一条待办，没有文件就没有待办。

**以仓里这份为准**：`~/switch-test/README.md` 是它的副本，两边同内容。改了仓里的就覆盖副本。

## 本地助手：从这里开始

每次被叫到，只做这一个循环：

```bash
# 1. 同步（k8s 带着 inbox 一起来）
~/five-repos-sync/sync-five-repos.sh from-remote fable
for p in investment-app knowledge-app; do git -C ~/worktrees/fable/$p/${p%-app}-backend pull --ff-only origin fable; done
git -C ~/worktrees/fable/runtime pull --ff-only origin fable
# 2. 看待办
ls ~/worktrees/fable/k8s/sunmoonai/docs/dev-investment-agent/switch-test/inbox/
# 3. 逐个打开，按里面的四行做：核提交号 → 跑 → 输出进 results/ → 提交推回；「前提」没满足的先问
```

待办文件里写清了跑什么、在哪个提交、要什么、看什么。做完的文件由远程移到 `done/`，你不动它。

## 哪边跑什么

2026-09-23 在这台机实测过的边界：

| 在这台机跑 | 回本地跑 |
| --- | --- |
| 文档门禁、ruff、pyright（峰值 740 MB） | 浏览器里的一切界面检查 |
| 后端 pytest 全套，含数据库那部分（Postgres 容器实际 45 MB） | 本地代理 + 沙箱 + 工作台的真机联调；Windows 上的 exec-server |
| TypeScript 类型检查与单元测试 | KIND 上的任何东西、压测 |
| codex app-server / exec-server 探针（一台机扮两端，模型调用在远端） | 两台机器之间的公网延迟；要真机内存的长任务 |

一次只跑一样。这台机跑得动的，本地可以再跑一遍作**独立复核**，那是验收的事，不是必须。

## 三步

工位名当前是 `fable`（工位名 = 目录名 = 分支名，见 `layout.conf`）。换模型不换工位，名字变了所有者会说。

```bash
# 1. 本地拉最新（在本地机器上执行）：父仓走同步脚本，子仓要单独拉
~/five-repos-sync/sync-five-repos.sh from-remote fable
for p in investment-app knowledge-app; do
  git -C ~/worktrees/fable/$p/${p%-app}-backend pull --ff-only origin fable
done
git -C ~/worktrees/fable/runtime pull --ff-only origin fable        # 客户端仓不在同步脚本里（desktop-app 已退役）

# 2. 跑测试脚本，整份输出落到脚本旁边的 results/，文件名带时间，不覆盖上一次
cd ~/worktrees/fable/<仓>            # 子仓、跨仓的按「脚本放哪」进对应目录
mkdir -p scripts/results
out=scripts/results/<脚本名>.$(date +%Y%m%d-%H%M%S).txt
bash scripts/<脚本名>.sh > "$out" 2>&1; echo "exit=$?" >> "$out"; tail -3 "$out"

# 3. 提交、推回。不贴对话——原件进 git，远程 pull 就看到
git add scripts/results && git commit -m "test(local): <脚本名> $(tail -1 "$out")"
~/five-repos-sync/sync-five-repos.sh to-remote fable        # 父仓与 k8s
git push origin fable                                       # 子仓、runtime 要自己推
```

**不删、不改、不截输出**——失败信息常在你觉得不重要的那几行里。对话里只需一句「跑完了，`<仓>` `<提交号>`」。

远程这边收到后：`git -C ~/worktrees/fable/<仓> pull --ff-only origin fable`。
⚠ 同步脚本要求两端工作区干净：**远程发请求前先把工位上的改动提交并推上去**，否则本地 `to-remote` 会在远程拉取那一步停住。

## 一次请求长什么样

远程发来的每一次请求都是这个形状，缺一项就先问，不猜：

```text
跑：<仓>/scripts/<脚本名>.sh
仓与提交：<父仓> <提交号>；<子仓> <提交号>；（跨仓时逐仓列）
预计：<多久>、<要不要联网>、<要不要 Docker / Codex 登录>
看什么：<这次要判的一两件事>
```

**请求本身也进 git**：一条一个文件，放本目录 `inbox/<日期>-<序号>-<脚本名>.md`，随 k8s 推上去；本地同步后就看到了，对话里只需说一句「有新请求」。
`luna` 这类只看得见分支的助手，靠的就是这个目录。远程发之前要保证：脚本已推到被测仓、`仓与提交` 填的是那个提交号。

跑之前先核提交号，对不上就停，贴出来：

```bash
git -C ~/worktrees/fable/<父仓> rev-parse --short HEAD
git -C ~/worktrees/fable/<父仓>/<子仓> rev-parse --short HEAD
```

## 我这边给什么

- **给脚本，不给零散命令**。脚本写进仓里，跟着代码一起同步。这样它有版本、可复跑，失败了我们对着同一份东西改；
- **失败要响**：每条命令检查退出码，不把错误吞进管道；缺输入、权限不足、枚举失败一律报出来，不静默当通过；
- **先探环境再跑正事**：脚本开头打印环境事实（见下），这样输出一贴回来，我先知道那边是什么情况，不用来回问；
- **输出自带上下文**：打印用的是哪个提交、哪条分支、哪些版本，免得事后分不清这份输出属于哪一版；
- **只测一件事**：一个脚本对应请求里「看什么」那一两件事，不把整套回归塞进一个脚本。

## 脚本放哪

| 测什么 | 脚本在哪 |
| --- | --- |
| 单个仓自己的 | 被测仓的 `scripts/`（后端在 `app/scripts/`） |
| 跨仓联调（代理 + 沙箱 + 工作台） | `k8s` 仓 `sunmoonai/scripts/local-integration/`——只有它已经按相对路径引用全部仓 |
| 界面点击步骤 | 不是脚本，是文档：随请求给，见「界面类检查」 |

本目录不放测试脚本；只放约定、`inbox/`（待办）与 `done/`（已办）。

## 脚本开头的环境探测

每个测试脚本都以这一段开头，输出回来我先看它。工位名从环境变量 `WS` 取，默认 `fable`：

```bash
#!/usr/bin/env bash
set -uo pipefail
WS="${WS:-fable}"

echo "===== 环境 ====="
echo "主机        $(hostname)"
echo "时间        $(date -Is)"
echo "工位        ${WS}"
echo "内存        $(free -h 2>/dev/null | awk '/Mem:/{print $2" 总 / "$7" 可用"}')"
echo "磁盘        $(df -h / | awk 'NR==2{print $4" 可用 / "$5" 已用"}')"
echo "Python      $(python3 -V 2>&1)"
echo "Node        $(node --version 2>/dev/null || echo '无')"
echo "Docker      $(docker --version 2>/dev/null || echo '无')"
echo "kind        $(kind --version 2>/dev/null || echo '无')"
echo "Codex       $(codex --version 2>/dev/null || echo '无')  CODEX_HOME=${CODEX_HOME:-未设}"
for r in k8s info-app investment-app knowledge-app tpl-app runtime; do
  d="${HOME}/worktrees/${WS}/${r}"
  [ -d "${d}/.git" ] || [ -f "${d}/.git" ] || continue
  printf "%-22s %s  %s\n" "${r}" "$(git -C "${d}" rev-parse --short HEAD)" "$(git -C "${d}" branch --show-current)"
  for s in "${d}"/*-backend; do
    [ -e "${s}/.git" ] && printf "  %-20s %s  %s\n" "$(basename "${s}")" "$(git -C "${s}" rev-parse --short HEAD)" "$(git -C "${s}" branch --show-current)"
  done
done
echo "===== 开始 ====="
```

## 输出怎么回

- 一律落文件、进 git，路径 `scripts/results/<脚本名>.<时间>.txt`，最后一行是 `exit=<码>`；见「三步」。
- 不贴对话。对话里一句「跑完了，`<仓>` `<提交号>`」就够。
- 界面类的检查没有脚本，结果按「界面类检查」写成一份 markdown，同样放 `scripts/results/`。
- `results/` 只增不删。要清理由所有者定。

## 界面类检查

我给的是编号步骤，每步写清「做什么」和「应该看到什么」：

```text
1. 打开应用 → 主窗口标题应为「…」
2. 点「问专家」 → 弹出确认窗，文字含「将发往 …」
3. …
```

你报的是：**做到第几步和预期不一样、屏幕上实际是什么**（原文或截图）。前面各步一致就不用逐条复述。

## 结论怎么写

- 一次测试跑完，结论按三值写：`pass` / `fail` / `undecidable`。**判不了就写判不了**，不猜。
- 覆盖按三档写：**查了 / 没查 / 不能排除**。「没查」还要说是哪一类：环境事实（可当场复跑）、远端与授权（写权限不能只靠读来验）、执行者内部（结构上够不着）。
- 你只负责跑和报，**不改代码、不改判据**。发现脚本本身有问题，报出来，远程改。

## 我这边要守的纪律

**在这台机上跑不了的东西，一律标「未验证」，不写成「已验证」。**

给你的东西会分两类：

| 类 | 例 | 我怎么说 |
| --- | --- | --- |
| 这台机已跑通 | 文档门禁、纯 Python 逻辑、单元测试、数据库测试、探针 | 「已跑通，输出如下」 |
| 只能在你那边验 | 要界面、要三方联调、要集群、要真机内存、要外部服务 | 「**这一条我没跑过**，请跑了把输出推回来」 |

这一条对应 `turn/uat/verify-rules.md`「覆盖声明」的第三类——**结构上够不着**的观察，
不改变接入方式就永远查不了。把它和「没查」混在一起写，会让人以为再跑几条命令就能补上。

## 约定

- 测试脚本放**被测仓**的 `scripts/`（跨仓的放 `k8s` 仓 `sunmoonai/scripts/local-integration/`），输出放同级 `results/`，都跟代码一起走 git，不放本目录；
- 本目录放**怎么测**的约定与模板，待办在 `inbox/`，已办在 `done/`；一次性环境配置在 `../tree-build/human-ai-turn/imp/luna-local-setup.md`；
- 换模型不换工位：接手的模型继续用同一个工位名，所有者改名时会说；本文里 `fable` 按当时的名字替换；
- 测试用的 Codex 走独立的 `CODEX_HOME`（编排端 `~/.codex-probe` 有登录态；执行端 `~/.codex-probe-exec` 无登录态），与日常用的隔离；Postgres 用容器不装系统里；
- Windows 上没有 bash 的脚本用 PowerShell（`.ps1`），环境探测段等价，输出同样落 `scripts/results/`。
