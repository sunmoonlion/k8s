# 给 luna：本地机器怎么配、怎么替远程跑测试

> 写给在所有者本地机器上工作的 AI 助手 luna。写这份的是在远程机（`43.153.135.74`，家目录 `/home/zym`）上写代码的助手 Claude。
> 远程机只有 3.6 GB 内存、2 核，只用来写代码和文档；**要内存、要界面、要集群、要真实联调的测试都在你那边跑**，
> 规矩以 `~/switch-test/README.md` 为准，这份只补它没写的：这一轮具体要什么环境、怎么对上工位、每一段我会请你跑什么。
>
> 用词：`pass` / `fail` / `undecidable` 三值结论；没跑的写「没跑」，不写「已验证」。

## 一、你的角色

- **跑，不改。**我给脚本，你跑脚本，把整份输出贴回给所有者。代码有问题我在远程改，你不改代码、不提交、不推送。
  例外只有一种：所有者明确让你改。那时你在自己的工位（`luna`）上改，不动 `fable` 工位。
- **整份贴，不挑着贴。**失败信息常在你觉得不重要的那几行里。
- **先探环境再跑正事。**每个脚本开头会打印主机、时间、内存、磁盘、各仓提交号；输出一贴回来我先看这一段。

## 二、一次性配置

### 2.1 工位

所有者的工位约定（`~/toolboxes/Vlinux/utils/set-up-tools/model-switch/layout.conf`）：主目录 `~/master/<仓>` 停在 `master`，
工位 `~/worktrees/<名字>/<仓>`，**工位名 = 目录名 = 分支名**。我的工位叫 `fable`，代码都在分支 `fable` 上。

本地要做三件事：

```bash
# 1. layout.conf 的 LAYOUT_WORKSPACES 加上 fable（远程已加）
sed -i 's/^LAYOUT_WORKSPACES=(cursor kimi luna opus qwen)$/LAYOUT_WORKSPACES=(cursor fable kimi luna opus qwen)/' \
  ~/toolboxes/Vlinux/utils/set-up-tools/model-switch/layout.conf
grep LAYOUT_WORKSPACES= ~/toolboxes/Vlinux/utils/set-up-tools/model-switch/layout.conf

# 2. 从 Git 仓库取 fable 分支到本地五仓，再挂出工位
for r in k8s info-app investment-app knowledge-app tpl-app; do git -C ~/master/$r fetch origin fable:fable; done
mb worktree add fable

# 3. 之后每次同步（远程推完之后）
~/five-repos-sync/sync-five-repos.sh from-remote fable
```

`mb worktree add` 只挂父仓，**子模块不会自动初始化**。后端代码在子模块里，要手动初始化并切到 `fable` 分支：

```bash
for p in investment-app knowledge-app; do
  s=${p%-app}-backend
  git -C ~/worktrees/fable/$p submodule update --init --recursive -- $s
  git -C ~/worktrees/fable/$p/$s fetch origin fable:fable 2>/dev/null || true
  git -C ~/worktrees/fable/$p/$s checkout fable
done
```

⚠ 五仓同步脚本**只推拉父仓，不推拉子仓**。子仓（`investment-backend`、`knowledge-backend`）的 `fable` 分支要单独
`git -C ~/worktrees/fable/<父仓>/<子仓> pull --ff-only origin fable`。我每次请你跑测试时，会写明父仓和子仓各在哪个提交号，你先对。

### 2.2 一个新仓（客户端仓）

`runtime`（本地代理：包 `codex exec-server` + 出站桥 + 本地上限 + 弹窗）是新仓，不参与 k8s 部署，没有并列放置要求。
远程已按同一布局放在 `~/master/runtime`（`master`）与 `~/worktrees/fable/runtime`（`fable`），并登记进 `mb` 的 `repos.conf`。
GitHub 仓 `sunmoonlion/runtime` 有 `master` 与 `fable`。你这边：

```bash
git clone git@github.com:sunmoonlion/runtime.git ~/master/runtime
printf '%s\n' '$HOME/master/runtime' >> ~/toolboxes/Vlinux/utils/set-up-tools/model-switch/repos.conf
mb worktree add fable runtime
```

⚠ **`desktop-app` 已退役**（2026-09-23 下午架构改判：界面回到网页，不做 Electron）。远程已删本地副本与 `repos.conf` 条目；
GitHub 仓由所有者删。你那边如果已经克隆过，删掉即可，不要再挂工位。

五仓同步脚本的 `REPOS` 列表要不要加 `runtime`，由所有者定；没加之前它用 `git pull` 手动同步。

### 2.3 工具

| 要什么 | 版本 | 用途 | 怎么核 |
| --- | --- | --- | --- |
| Python | 3.10 以上 | 后端 | `python3 -V` |
| uv | 任意近期版 | 后端依赖与测试 | `uv --version` |
| Node.js | 20 以上 | runtime（本地代理） | `node --version` |
| pnpm | 9 以上 | 同上 | `pnpm --version` |
| Docker | 任意近期版 | Postgres 容器、KIND | `docker --version` |
| kind + kubectl | 现有 | 集群相关测试（第一段用不到） | `kind --version` |
| Codex CLI | **0.155.1**，与远程同版 | 探针与联调：`codex app-server`（云端角色）与 `codex exec-server`（用户机器角色） | `codex --version` |
| Python `websockets` | 17 | 探针里的会合点与两侧出站桥（`runtime/.venv`，`uv venv .venv && uv pip install --python .venv/bin/python websockets`） | `.venv/bin/python -c 'import websockets'` |

Codex 要**单独一个 `CODEX_HOME`** 给测试用，与你自己或所有者日常用的隔离：

```bash
mkdir -p ~/.codex-probe && cp ~/.codex-official/config.toml ~/.codex-probe/ 2>/dev/null
# 登录态：在这个 home 下登录一次，或所有者允许时复制 ~/.codex-official/auth.json 并 chmod 600
CODEX_HOME=$HOME/.codex-probe codex --version
```

Postgres 用容器，不装到系统里：

```bash
docker run -d --rm --name pgtest -e POSTGRES_PASSWORD=t -e POSTGRES_USER=t \
  -p 127.0.0.1:55432:5432 --memory=400m postgres:16-alpine
docker exec pgtest psql -U t -c 'CREATE DATABASE agent_tests;' -c 'CREATE DATABASE delivery_tests;'
```

### 2.4 配好之后跑一遍冒烟，贴回来

```bash
cd ~/worktrees/fable/investment-app/investment-backend/app
uv sync --frozen && uv run ruff check . && uv run pyright && \
AGENT_TEST_DATABASE_URL=postgresql://t:t@127.0.0.1:55432/agent_tests \
DELIVERY_TEST_DATABASE_URL=postgresql://t:t@127.0.0.1:55432/delivery_tests \
uv run pytest -q 2>&1 | tail -5
```

远程上这一套的结果是：ruff 通过、pyright 通过、pytest 全部通过（含数据库的 94 个）。你那边不一致就整份贴。

## 二之二、换模型接力：换模型不换分支

所有者可能中途换模型继续（例如 Fable 额度用完，换 Opus 或换你）。**接手的模型直接在 `fable` 工位、`fable` 分支上继续**，
不另开工位、不快进合并。作者归属看每条提交的 `Co-Authored-By`，不看分支名。

接手的一方知道什么、不知道什么：

| 怎么接 | 能看到 |
| --- | --- |
| 同一个 Claude Code 会话里切模型 | 之前的对话全部还在 |
| 远程机上新开 Claude Code 会话 | 对话看不见；能读远程机上的项目记忆、分支上的 `CHECKPOINT.md`、代码与文档 |
| **你（luna），或别的工具、别的机器** | 对话和记忆都看不见；**只有分支上落盘的东西** |

所以我每次停下都把状态写进分支上的 `CHECKPOINT.md`（IMP 规则），你接手时一切以它为准。
对你的影响：工位名始终是 `fable`，上面的命令不用改。

## 三、每一轮怎么跑

1. 我推完代码，所有者告诉你「跑 `<仓>/scripts/<脚本名>.sh`，父仓在 `<提交号>`，子仓在 `<提交号>`」。
2. 你先同步并核提交号：

   ```bash
   ~/five-repos-sync/sync-five-repos.sh from-remote fable
   git -C ~/worktrees/fable/<父仓>/<子仓> pull --ff-only origin fable
   git -C ~/worktrees/fable/<父仓> rev-parse --short HEAD
   git -C ~/worktrees/fable/<父仓>/<子仓> rev-parse --short HEAD
   ```

   对不上就停，贴出来，不要猜着跑。
3. 跑脚本，输出落到脚本旁边的 `scripts/results/<脚本名>.<时间>.txt`，提交、`to-remote fable`（子仓与两个客户端仓自己 `push`），
   **不贴对话**，说一句「跑完了，`<仓>` `<提交号>`」即可。命令与细则见 `../../../../switch-test/README.md`「三步」。

4. 界面类的检查我会给**编号的点击步骤和每一步该看到的文字**，你按步骤做，报在第几步和预期不一样、屏幕上实际是什么。

## 四、各段会请你跑什么

架构在 2026-09-23 下午改判（`tree-build/` 已重写）：Codex 的模型循环在我们的沙箱里跑，工具在用户机器上经 `codex exec-server` 执行，界面是网页，本地只装一个小代理。分段随之改：

| 段 | 我在远程做什么 | 会请你跑的 |
| --- | --- | --- |
| 一 探针 | 五个探针，四个远程已跑完（本地上限、BYOK/Kimi、会合点透传、断线恢复；报告在 `runtime/probe/REPORT-2026-09-23-*.md`） | **两件现在就能做**，见「四之二」：Windows 上的 exec-server；两台机器之间的真实延迟 |
| 二 代理 + 沙箱最小对 | `runtime` 代理（exec-server 封装、出站桥、本地上限、弹窗）；沙箱镜像；哑会合点 | 代理在你机器上装、连远程会合点、走一个 turn |
| 三 工作台 + 网页 | 会话与方向盘、账房收窄、app-server 客户端；网页页面 | 后端全套测试复核；浏览器按步骤点 |
| 四 评测 + 演示 | 问数专家包 + MCP + 二十题 | 跑「顾问驾驶 vs 裸 Codex」二十题，贴分段结果 |

## 四之二、每一轮的具体请求不在这里

本文只管**一次性环境**。每一轮跑什么，一律按 [`../../../switch-test/README.md`](../../../switch-test/README.md) 的约定：脚本在被测仓的 `scripts/`，
输出落 `scripts/results/`，请求用「跑 / 仓与提交 / 预计 / 看什么」四行。第一段剩下的两个探针（Windows 上的 exec-server、两机公网延迟）
的脚本在 `runtime` 仓 `scripts/`，请求由所有者转发。

## 五、我这边的纪律，你可以据此核我

- 我说「已跑通」的，只限远程能跑的那类：文档门禁、ruff、pyright、pytest、TypeScript 检查、探针。
- 凡是要界面、要三方联调、要真机内存的，我一律写「**这一条我没跑过**，请贴输出」。我要是写成「已验证」，那是错的，请指出。
- 结论三值。判不了的停在 `undecidable`，我不会替你补成通过。

## 六、现在的状态（2026-09-23）

| 仓 | `fable` 分支在哪 | 备注 |
| --- | --- | --- |
| k8s | 远程与 GitHub 都有 | 含 turn/ 机制重构与本文 |
| info-app、investment-app、knowledge-app、tpl-app | 远程与 GitHub 都有 | 与 master 相同，还没改动 |
| investment-backend、knowledge-backend（子仓） | 只在远程 | 与父仓 gitlink 相同，还没改动、还没推 |
| runtime | 远程与 GitHub 都有 | `master` 与 `fable` 都已推；`fable` 上有四份探针报告与原型脚本 |
| ~~desktop-app~~ | 已退役 | 远程本地副本已删；GitHub 仓由所有者删 |

远程上 cursor、fable、kimi、luna、qwen 五个工位 × 七个仓已用 `mb` 挂出（opus 工位已按「换模型不换分支」收掉，`layout.conf` 里也去了）；
除 `fable` 外都是从 `master` 新建、没有推到 GitHub——你那边的同名工位按所有者平时的 `to-remote <工位>` 流程对齐，不由远程先推。

树根已重写并推送（k8s `fable`）。每一段的请求都走 `switch-test/README.md` 的四行格式，不在本文里。
