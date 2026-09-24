# 换机测试：远程机写，本地机跑

## 零、先把人和机器叫清楚

两台机器、两个助手、一个人。本文通篇只用下面这几个名字：

| 名字 | 是什么 | 在哪 |
| --- | --- | --- |
| **远程机** | 云上的开发机 `43.153.135.74`，家目录 `/home/zym`；3.6 GB 内存、2 核，只写代码和文档，跑不动重东西 | 所有者用 Cursor 远程登录进去 |
| **本地机** | 所有者自己的电脑（Linux；另有 Windows 机做 Windows 专项） | 所有者桌上 |
| **远程助手** | 在远程机上工作的 AI 助手，不论是哪个模型、哪个工具；换模型不换工位 | 远程机 |
| **本地助手** | 在本地机上工作的 AI 助手，不论是哪个模型、哪个工具 | 本地机 |
| **所有者** | 人。两台机都能操作；在两个助手之间传话、批「前提」、决定合并 | 两边 |

分工只有一句：**远程助手写，本地助手跑。**远程助手写脚本、推仓、往 `inbox/` 放待办、读结果；本地助手同步、跑待办、把输出推回。
两个助手互相看不见对话，**只共享 git 分支**；所以一切请求与结果都进 git，对话只传一句话。

⚠ 本文的「本地」指**所有者的本地机**，不是产品文档里的「用户机器 / 本地代理」。做探针时本地机**扮演**用户机器，远程机**扮演**我们的云端。

本目录：`README.md`（本文，约定）、`inbox/`（**待办，一个文件一条，远程助手写、本地助手做**）、`done/`（已办）。测试脚本不放这里，放被测仓。
`~/switch-test/` 是本目录在两台机上的副本，以仓里为准。本地机要装什么见「六、固定事实」。

## 一、本地助手（在本地机上）：只做这一个循环

```bash
# 1. 同步
~/five-repos-sync/sync-five-repos.sh from-remote fable
for p in investment-app knowledge-app; do git -C ~/worktrees/fable/$p/${p%-app}-backend pull --ff-only origin fable; done
git -C ~/worktrees/fable/runtime pull --ff-only origin fable

# 2. 看待办：一个文件一条，没有文件就没有待办
ls ~/worktrees/fable/k8s/sunmoonai/docs/dev-investment-agent/switch-test/inbox/

# 3. 逐条做（每条文件里写了 跑什么 / 仓与提交 / 预计 / 看什么 / 前提 / 回传）
#    3a 核提交号，对不上就停，贴出来
git -C ~/worktrees/fable/<仓> rev-parse --short HEAD
#    3b 跑，整份输出落 results/，文件名带时间
cd ~/worktrees/fable/<仓> && mkdir -p scripts/results
out=scripts/results/<脚本名>.$(date +%Y%m%d-%H%M%S).txt
bash scripts/<脚本名>.sh > "$out" 2>&1; echo "exit=$?" >> "$out"; tail -3 "$out"
#    3c 提交、推回
git add scripts/results && git commit -m "test(local): <脚本名> $(tail -1 "$out")"
~/five-repos-sync/sync-five-repos.sh to-remote fable     # 五仓
git push origin fable                                    # 子仓、runtime 要自己推

# 4. 对话里一句：「跑完了，<仓> <提交号>」
```

规矩：**「前提」没满足先问**，不猜着跑；**不删、不改、不截输出**；不改代码、不改判据，脚本有问题报出来由远程改；`done/` 里的不动。
Windows 上跑 `.ps1`：`powershell -ExecutionPolicy Bypass -File scripts\<脚本名>.ps1 *> scripts\results\<脚本名>.<时间>.txt`，其余同上。

## 二、一条待办长什么样

文件名 `inbox/<日期>-<序号>-<脚本名>.md`，内容固定六项，缺一项本地助手先问：

```text
跑：<仓>/scripts/<脚本名>.sh   （或 .ps1）
仓与提交：<仓> <提交号>；<子仓> <提交号>（跨仓时逐仓列）
预计：<多久>；要不要联网；要不要 Docker / Codex 登录态
看什么：<这次要判的一两件事，以及怎么算 pass / fail>
前提：<要所有者先做的事，没有写「无」>
回传：<结果文件路径>；提交并推回哪个仓
```

界面类的检查没有脚本：待办里给编号步骤，每步写「做什么」和「应该看到什么」；本地助手报**做到第几步和预期不一样、屏幕上实际是什么**，写成 markdown 放同一个 `results/`。

## 三、远程助手（在远程机上）：发一条待办之前

1. **脚本先推到被测仓**，待办里的 `仓与提交` 填那个提交号；
2. 脚本放哪：单仓的放该仓 `scripts/`（后端在 `app/scripts/`）；跨仓联调放 `k8s` 仓 `sunmoonai/scripts/local-integration/`；
3. 脚本怎么写：开头打印环境段（下面模板）；每条命令查退出码，失败要响，不吞进管道；一个脚本只测「看什么」那一两件事；没有 bash 的 Windows 用 `.ps1`，环境段等价；
4. 待办文件随 k8s 推上去；**推之前远程工位必须干净**（同步脚本要求两端干净，否则本地 `to-remote` 会停在远程拉取那一步）；
5. 对话里只说一句「有新待办」。

收到结果后：`git -C ~/worktrees/fable/<仓> pull --ff-only origin fable`，读 `results/`，把待办文件移到 `done/`。

远程助手的用词纪律：在远程机上跑不了的东西一律写「**这一条我没跑过**」，不写「已验证」；远程机上跑通的写「已跑通，输出如下」。

## 四、结论怎么写

- 三值：`pass` / `fail` / `undecidable`，判不了就写判不了；
- 覆盖三档：**查了 / 没查 / 不能排除**。「没查」写清哪一类：环境事实（可当场复跑）、远端与授权（写权限不能只靠读来验）、执行者内部（结构上够不着）；
- `results/` 只增不删，清理由所有者定；每份结果最后一行是 `exit=<码>`。

## 五、什么在远程机跑、什么必须到本地机跑

判据是内存与环境：远程机跑得动的，远程助手自己跑，不发待办；跑不动或需要真机、界面、两台机器的，才写成待办让本地助手跑。

| 远程助手在远程机上跑 | 本地助手在本地机上跑 |
| --- | --- |
| 文档门禁、ruff、pyright（峰值 740 MB） | 浏览器里的一切界面检查 |
| 后端 pytest 全套，含数据库（Postgres 容器 45 MB） | 本地代理 + 沙箱 + 工作台的真机联调 |
| TypeScript 类型检查与单元测试 | Windows 上的 exec-server；两台机器之间的公网延迟 |
| Codex app-server / exec-server 探针（一台机扮两端） | KIND 上的任何东西、压测、要真机内存的长任务 |

远程机跑得动的，本地机可以再跑一遍作独立复核，那是验收的事，不是必须。

## 六、固定事实

本地机要有的工具（脚本的环境段会打印，缺了脚本自己会报）：

| 工具 | 版本 | 用在哪 |
| --- | --- | --- |
| Codex CLI | **0.155.1**，与远程机同版 | 探针与联调：`codex app-server`（云端角色）、`codex exec-server`（用户机器角色） |
| Python 3.10+、uv | 近期版 | 后端测试；探针的 `websockets` venv（`uv venv .venv && uv pip install --python .venv/bin/python websockets`） |
| Node.js 20+、pnpm 9+ | 近期版 | `runtime` 仓 |
| Docker | 近期版 | Postgres 容器：`docker run -d --rm --name pgtest -e POSTGRES_PASSWORD=t -e POSTGRES_USER=t -p 127.0.0.1:55432:5432 postgres:16-alpine` |
| kind + kubectl | 现有 | 集群相关测试 |

- 两台机上远程助手的工位名都是 `fable`（工位名 = 目录名 = 分支名，`~/worktrees/fable/<仓>`）；换模型、换助手都不换工位，改名时所有者会说；本地助手在这个工位里只跑不改；
- 测试用的 Codex 走独立 `CODEX_HOME`：编排端 `~/.codex-probe`（有登录态），执行端 `~/.codex-probe-exec`（无登录态）；与日常用的隔离；
- Postgres 用容器，不装到系统里。

## 附：脚本开头的环境段

参考实现 `runtime/scripts/env-header.sh`（`source` 即可）。最少打印这些：

```bash
#!/usr/bin/env bash
set -uo pipefail
WS="${WS:-fable}"
echo "===== 环境 ====="
echo "主机 $(hostname)  时间 $(date -Is)  工位 ${WS}  系统 $(uname -srm)"
echo "内存 $(free -h | awk '/Mem:/{print $2" 总 / "$7" 可用"}')  磁盘 $(df -h / | awk 'NR==2{print $4" 可用"}')"
echo "Python $(python3 -V 2>&1)  Node $(node --version 2>/dev/null || echo 无)  Docker $(docker --version 2>/dev/null || echo 无)"
echo "Codex $(codex --version 2>/dev/null || echo 无)  CODEX_HOME=${CODEX_HOME:-未设}"
for r in k8s info-app investment-app knowledge-app tpl-app runtime; do
  d="${HOME}/worktrees/${WS}/${r}"; [ -e "${d}/.git" ] || continue
  printf "%-16s %s  %s\n" "${r}" "$(git -C "${d}" rev-parse --short HEAD)" "$(git -C "${d}" branch --show-current)"
  for s in "${d}"/*-backend; do [ -e "${s}/.git" ] && printf "  %-14s %s  %s\n" "$(basename "${s}")" "$(git -C "${s}" rev-parse --short HEAD)" "$(git -C "${s}" branch --show-current)"; done
done
echo "===== 开始 ====="
```
