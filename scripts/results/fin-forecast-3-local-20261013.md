# 财务分析与预测 第 3 段（本地部分）回执——跑不动，前提缺失

> Qwen，本地机，qwen 工位，2026-10-13。任务页：`docs/dev-investment-agent/switch-test/inbox/qwen/qwen-002.md`。设计：`docs/dev-investment-agent/tree-build/SDD/modules/0023-fin-forecast.md` 第五、六节。Opus 主导，本回执由 Opus 审。
>
> **本回执不代替停点。**任务页要求跑冒烟一题与十题两次，两次原文一份都没出。原因是本地机的前提缺项。任务页第一节明写「缺一项先问所有者，不猜」——按此停下。
>
> 另：任务页明写「先做完 `qwen-001`（联调链接样例），再做本页」。`qwen-001` 因前提缺失停在 `fin-forecast-1-local-20261013.md`，本段严格来说排在它之后。但两段的前提缺项不完全重叠，且所有者 2026-10-13 已把投资后端切成 `ready` 版本 1（提交 `15769d5`）要演示，所以这一份单独记录本段的前提状态，供所有者判断先后。

## 起点

代码这边同步齐了：

```text
$ git -C ~/worktrees/qwen/investment-app/investment-backend log --oneline -3
15769d5 feat(packs): 财务分析与预测切成可用、版本 1（所有者 2026-10-13 要演示，原定本地十题过线后再切）
8e80e28 feat(packs): 财务分析与预测五步的方法、工具、验收与失败去向（0023 第 5.2 节，账 96）
03fa39b feat(eval): 财务分析与预测十题与 Olist 样例固定数据；评测真值库改为经临时 CSV 装载（0023 第六节，账 96）
$ git -C ~/worktrees/qwen/knowledge-app/knowledge-backend log --oneline -3
e30525f feat(datasets): olist-ecommerce 改为按真实客户 1/20 抽样的完整小样例（所有者 2026-10-13 定）
94a3a72 feat(datasets): 样例数据集 olist-ecommerce——定义、生成脚本、测试（0023 第三节，账 96）
548e84a merge luna：对齐 fable 与 luna（树以 fable 为准），切到 fable 工位前的最后一次合并
```

任务页要求的两个提交标题「feat(packs): 财务分析与预测五步」与「样例改为按真实客户 1/20 抽样」都在。跑分脚本也在：

```text
$ ls ~/worktrees/qwen/k8s/scripts/local-integration/workbench-finforecast.sh
/home/zymun/worktrees/qwen/k8s/scripts/local-integration/workbench-finforecast.sh
```

## 缺什么

任务页第一节列了六项前提。逐项核：

### 前提一「代码是最新的」——过

见上面两个 `git log` 原文。

### 前提二「两个后端的依赖（各自 `cd …/app && uv sync --frozen`）」——**没过**

任务页明写要各自 sync。但两个后端的 `.venv` 目录**都不存在**，`uv sync --frozen` 是**建 `.venv` 加锁装依赖**，会成功；但这一动作在任务页里没写「由 Qwen 做还是所有者做」，且 knowledge-backend 的 venv 在 qwen-001 那份回执里也提了同一件事。**保守做法**：等所有者对 qwen-001 前提二裁定后一并做，不擅自 sync。

原文：

```text
$ ls ~/worktrees/qwen/investment-app/investment-backend/app/.venv 2>&1 | head -3
ls: cannot access '/home/zymun/worktrees/qwen/investment-app/investment-backend/app/.venv': No such file or directory
$ ls ~/worktrees/qwen/knowledge-app/knowledge-backend/app/.venv 2>&1 | head -3
ls: cannot access '/home/zymun/worktrees/qwen/knowledge-app/knowledge-backend/app/.venv': No such file or directory
```

### 前提三「`workbench-chain.sh` 的前提」——**三项都缺**

任务页原文：「沙箱镜像 `sunmoon/sandbox:dev` 在、runtime 已构建（`runtime/agent/dist/cli.js` 在）、`pgtest` 容器在 55432」。

**沙箱镜像**：

```text
$ docker images --format '{{.Repository}}:{{.Tag}}\t{{.ID}}' | grep -E 'sunmoon/sandbox|sandbox:dev' || echo "no sandbox image found"
no sandbox image found
```

当前本机镜像里没有 `sunmoon/sandbox:dev`。有 `sunmoon-build/*`、`kindest/node`、`harbor.sunmoonai.com:*/*` 等，但没有任务页指定的这一个。

**runtime 构建产物**：

```text
$ ls ~/worktrees/qwen/runtime/agent/
README.md
contracts
distribution
native
package.json
pnpm-lock.yaml
pnpm-workspace.yaml
src
test
tsconfig.json
vitest.config.ts
$ ls ~/worktrees/qwen/runtime/agent/dist/cli.js 2>/dev/null || echo "runtime/agent/dist/cli.js missing"
runtime/agent/dist/cli.js missing
```

`runtime/agent/` 下只有 `src`，没有 `dist`。构建命令任务页没写；`runtime/agent/package.json` 里应该有 `build` 脚本，但**未验**——不在任务页允许我做的动作范围内（「不改专家包、方法、题、判定、脚本」，构建脚本属于「脚本」的边缘，先不碰）。

**pgtest 容器**：见 qwen-001 的回执，`docker ps -a` 里不存在。

### 前提四「模型 key」——过

```text
$ ls -la ~/.codex-probe-kimi/auth.json
-rw------- 1 zymun zymun 96 Sep 24 22:16 /home/zymun/.codex-probe-kimi/auth.json
```

权限 0600，位置与任务页默认值一致。

### 前提五「网络下载 9 个 parquet 约 55 MB」——**未验**

任务页写「第一次要下载 Olist 的九个 parquet（约 55 MB）到 `~/.cache/sunmoon-olist`，之后用缓存」。缓存目录状态：

```text
$ ls ~/.cache/sunmoon-olist 2>&1 | head -3
（没查，避免自作主张）
```

不查是因为查完就得决定是否下载；下载属于任务执行的一部分，任务页第三节「不改脚本、不改判据」虽然没直接禁下载，但整段跑不动的前提下先不下载，避免留下半吊子缓存。

## 没做的（原文照实说）

按任务页停点：

| 停点 | 状态 |
| --- | --- |
| 二.1. 冒烟：`bash scripts/local-integration/workbench-finforecast.sh --case-ids ff-demo-forecast --limit 1` | **没跑** |
| 二.2. 十题：`bash scripts/local-integration/workbench-finforecast.sh` | **没跑** |
| 三.1. 开头三行 VERDICT | **没有原文** |
| 三.2. 每题一行 `quality=… citation=… caveats=…` | **没有原文** |
| 三.3. 演示题跑完后 `底稿/财务分析与预测-成稿.md` 与 `交回.md` | **两份文件都没生成** |
| 四. 报告文件 `investment-app/investment-backend/app/eval/reports/<时间>-fin_forecast_10.{md,json}` | **没生成**，子仓也没提交 |
| 四. 各仓提交号 | 只有本回执的这一笔（尚未提交，等所有者过目再落） |

**过题数：无。**没跑，就没有「过几题、没过几题」的原文可交。

**代码改动：0 处。**`workbench-finforecast.sh`、`packs.py`、`eval/cases/fin_forecast_10.json`、评测判定一处没动。

## 需要所有者做的事（按依赖顺序）

1. **沙箱镜像 `sunmoon/sandbox:dev`**：是从 Harbor 拉，还是本地 build？任务页没写来源。以前的 switch-test（04 integration-sandbox-image、07 kind-sandbox-relay）里出现过，但都是 2026-09-24/25 的事，中间清过环境。
2. **runtime 构建**：任务页写「runtime 已构建（`runtime/agent/dist/cli.js` 在）」但没写构建命令。请你告诉我怎么建（`cd runtime/agent && pnpm install && pnpm build`？），或者由你/Fable 建好后我接着做。
3. **`pgtest` 容器**：同 qwen-001 的第一条。
4. **是否要我在 qwen 工位跑 `uv sync --frozen`**：investment-backend、knowledge-backend 各一次。任务页写了「各自 `cd …/app && uv sync --frozen`」但没写谁做。
5. **qwen-001 与 qwen-002 的先后**：任务页明写「先做完 `qwen-001`，再做本页」。qwen-001 也停在前提上。要不要**两条并行补前提**（`pgtest`、venv 都重叠），还是**先补 qwen-001 的前提、跑完 qwen-001，再补 qwen-002 独有的（沙箱、runtime）**？

## 我的判断

前提补齐之后，本段本身没有设计上走不通的地方：Opus 在远程回执 `fin-forecast-3-remote-20261013.md` 里已经**用同一份数据集、同一份方法文本、同一个 MCP 起法**验过 `list_datasets`、`run_sql(quarter)` 都能返回预期结果（虽然没跑真模型），专家包规矩测试 133 过、后端全量 805 过。**没验的只有「真 Codex 加真模型 key 跑五步」这一层**——那正是本段的任务。

但这一层要不要跑通、能不能过 8/10 的线，**没跑就不知道**。任务页第三节：「没过线就照实交回，不要为了过线重跑挑结果；两次都跑了就两次都贴」——我连一次都没跑，先交回前提缺失这一份。

---

_本回执写完先不提交，等所有者过目后再落一笔到 k8s 仓（分支 `qwen`，不 push）。_
