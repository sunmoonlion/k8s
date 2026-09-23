# 给 luna：本地机器怎么配、怎么替远程跑测试

> 写给在所有者本地机器上工作的 AI 助手 luna。写这份的是在远程机（`43.153.135.74`，家目录 `/home/zym`）上写代码的助手 Claude。
> 远程机只有 3.6 GB 内存、2 核，只用来写代码和文档；**要内存、要界面、要集群、要真实联调的测试都在你那边跑**，
> 规矩以 `~/switch-test/README.md` 为准，这份只补它没写的：这一轮具体要什么环境、怎么对上工位、每一段我会请你跑什么。
>
> 用词：`pass` / `fail` / `undecidable` 三值结论；没跑的写「没跑」，不写「已验证」。

## 一、你的角色

- **跑，不改。**我给脚本，你跑脚本，把整份输出贴回给所有者。代码有问题我在远程改，你不改代码、不提交、不推送。
  例外只有一种：所有者明确让你改。那时你在自己的工位（`luna`）上改，不动 `claude` 工位。
- **整份贴，不挑着贴。**失败信息常在你觉得不重要的那几行里。
- **先探环境再跑正事。**每个脚本开头会打印主机、时间、内存、磁盘、各仓提交号；输出一贴回来我先看这一段。

## 二、一次性配置

### 2.1 工位

所有者的工位约定（`~/toolboxes/Vlinux/utils/set-up-tools/model-switch/layout.conf`）：主目录 `~/master/<仓>` 停在 `master`，
工位 `~/worktrees/<名字>/<仓>`，**工位名 = 目录名 = 分支名**。我的工位叫 `claude`，代码都在分支 `claude` 上。

本地要做三件事：

```bash
# 1. layout.conf 的 LAYOUT_WORKSPACES 加上 claude（远程已加）
sed -i 's/^LAYOUT_WORKSPACES=(cursor kimi luna opus qwen)$/LAYOUT_WORKSPACES=(claude cursor kimi luna opus qwen)/' \
  ~/toolboxes/Vlinux/utils/set-up-tools/model-switch/layout.conf
grep LAYOUT_WORKSPACES= ~/toolboxes/Vlinux/utils/set-up-tools/model-switch/layout.conf

# 2. 从 Git 仓库取 claude 分支到本地五仓，再挂出工位
for r in k8s info-app investment-app knowledge-app tpl-app; do git -C ~/master/$r fetch origin claude:claude; done
mb worktree add claude

# 3. 之后每次同步（远程推完之后）
~/five-repos-sync/sync-five-repos.sh from-remote claude
```

`mb worktree add` 只挂父仓，**子模块不会自动初始化**。后端代码在子模块里，要手动初始化并切到 `claude` 分支：

```bash
for p in investment-app knowledge-app; do
  s=${p%-app}-backend
  git -C ~/worktrees/claude/$p submodule update --init --recursive -- $s
  git -C ~/worktrees/claude/$p/$s fetch origin claude:claude 2>/dev/null || true
  git -C ~/worktrees/claude/$p/$s checkout claude
done
```

⚠ 五仓同步脚本**只推拉父仓，不推拉子仓**。子仓（`investment-backend`、`knowledge-backend`）的 `claude` 分支要单独
`git -C ~/worktrees/claude/<父仓>/<子仓> pull --ff-only origin claude`。我每次请你跑测试时，会写明父仓和子仓各在哪个提交号，你先对。

### 2.2 两个新仓（客户端仓）

`runtime`（本地 runtime，TypeScript）和 `desktop-app`（Electron 壳）是新仓，不参与 k8s 部署，没有并列放置要求。
远程已按同一布局放在 `~/master/<仓>`（`master`）与 `~/worktrees/claude/<仓>`（`claude`），并登记进 `mb` 的 `repos.conf`。
**GitHub 上的仓要所有者先建**：`sunmoonlion/runtime`、`sunmoonlion/desktop-app`。建好、远程推上去之后，你这边：

```bash
for r in runtime desktop-app; do
  git clone git@github.com:sunmoonlion/$r.git ~/master/$r
  printf '%s\n' "\$HOME/master/$r" >> ~/toolboxes/Vlinux/utils/set-up-tools/model-switch/repos.conf
done
mb worktree add claude runtime
mb worktree add claude desktop-app
```

五仓同步脚本的 `REPOS` 列表要不要加这两个，由所有者定；没加之前它们用上面的 `git pull` 手动同步。

### 2.3 工具

| 要什么 | 版本 | 用途 | 怎么核 |
| --- | --- | --- | --- |
| Python | 3.10 以上 | 后端 | `python3 -V` |
| uv | 任意近期版 | 后端依赖与测试 | `uv --version` |
| Node.js | 20 以上 | runtime、desktop-app | `node --version` |
| pnpm | 9 以上 | 同上 | `pnpm --version` |
| Docker | 任意近期版 | Postgres 容器、KIND | `docker --version` |
| kind + kubectl | 现有 | 集群相关测试（第一段用不到） | `kind --version` |
| Codex CLI | **0.155.1**，与远程同版 | 三方联调时驱动 Codex | `codex --version` |
| Electron 运行依赖 | 视系统 | 桌面壳 | 第三段给脚本时再核 |

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
cd ~/worktrees/claude/investment-app/investment-backend/app
uv sync --frozen && uv run ruff check . && uv run pyright && \
AGENT_TEST_DATABASE_URL=postgresql://t:t@127.0.0.1:55432/agent_tests \
DELIVERY_TEST_DATABASE_URL=postgresql://t:t@127.0.0.1:55432/delivery_tests \
uv run pytest -q 2>&1 | tail -5
```

远程上这一套的结果是：ruff 通过、pyright 通过、pytest 全部通过（含数据库的 94 个）。你那边不一致就整份贴。

## 三、每一轮怎么跑

1. 我推完代码，所有者告诉你「跑 `<仓>/scripts/<脚本名>.sh`，父仓在 `<提交号>`，子仓在 `<提交号>`」。
2. 你先同步并核提交号：

   ```bash
   ~/five-repos-sync/sync-five-repos.sh from-remote claude
   git -C ~/worktrees/claude/<父仓>/<子仓> pull --ff-only origin claude
   git -C ~/worktrees/claude/<父仓> rev-parse --short HEAD
   git -C ~/worktrees/claude/<父仓>/<子仓> rev-parse --short HEAD
   ```

   对不上就停，贴出来，不要猜着跑。
3. 跑脚本，整份落文件，整份贴回：

   ```bash
   bash scripts/<脚本名>.sh > /tmp/out.txt 2>&1; echo "exit=$?"; cat /tmp/out.txt
   ```

4. 界面类的检查我会给**编号的点击步骤和每一步该看到的文字**，你按步骤做，报在第几步和预期不一样、屏幕上实际是什么。

## 四、四段里各会请你跑什么

| 段 | 我在远程做什么 | 会请你跑的 |
| --- | --- | --- |
| 一 设计 + 探针 | 重写 PRD 树根、architecture、① 协议规格；`codex app-server` 探针 | 基本不用你。探针在远程能跑 |
| 二 后端 + runtime | 两仓各自分支、带测试、用假对端联调 | 后端全套测试（远程也能跑，你那边跑一遍作独立复核）；runtime 的类型检查与单元测试；**runtime 接真 Codex 走一个 Task**（远程内存吃紧时） |
| 三 桌面壳 + 三方联调 | Electron 壳 | **全部在你那边**：构建、启动、按步骤点、把三方联调走通一个 Task |
| 四 评测 + 演示 | 把第 24 课评测搬过来 | 跑「顾问驾驶 vs 裸 Codex」二十题，贴分段结果 |

## 五、我这边的纪律，你可以据此核我

- 我说「已跑通」的，只限远程能跑的那类：文档门禁、ruff、pyright、pytest、TypeScript 检查、探针。
- 凡是要界面、要三方联调、要真机内存的，我一律写「**这一条我没跑过**，请贴输出」。我要是写成「已验证」，那是错的，请指出。
- 结论三值。判不了的停在 `undecidable`，我不会替你补成通过。

## 六、现在的状态（2026-09-23）

| 仓 | `claude` 分支在哪 | 备注 |
| --- | --- | --- |
| k8s | 远程与 GitHub 都有 | 含 turn/ 机制重构与本文 |
| info-app、investment-app、knowledge-app、tpl-app | 远程与 GitHub 都有 | 与 master 相同，还没改动 |
| investment-backend、knowledge-backend（子仓） | 只在远程 | 与父仓 gitlink 相同，还没改动、还没推 |
| runtime、desktop-app | 只在远程 | GitHub 仓待建 |

第一段开始前所有者会定稿 PRD 树根，那之前不会有东西请你跑。配环境可以先做。
