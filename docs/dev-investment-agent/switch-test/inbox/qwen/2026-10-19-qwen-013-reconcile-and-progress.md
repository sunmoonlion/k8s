# Qwen 发布卡 qwen-013：委托没人推时不卡死、模型看得全工具结果、测试中看得到进度（先 knowlab 后 knowbench）

> 状态：**可执行**（Opus 2026-10-19 写；所有者「好，按 0034 写代码」「好，去修那两项」，并同意「这次测试不救了，修完再测第 3 稿」）。
> 取代 qwen-011 第五节余下的行：第 2 稿那次测试不再人工救，由本卡上线的新代码自动收尾 c1，c2、c3 接着跑，当作新代码的第一次观察。

```text
被测仓：k8s，qwen 工作树 ~/worktrees/qwen/k8s，分支 qwen
两段发布，先 knowlab 后 knowbench（契约 knowbot-test-run/v1 加了可选字段，提供方先上）：
  一段 knowlab：父仓、后端、管理端，5 行钉；两个镜像（后端、管理端）
  二段 knowbench：父仓、后端，3 行钉；一个镜像（后端）
迁移：没有（knowbench 迁移头 20261017_0020、knowlab 20261018_0007 都不变）；配置不改；网页不变
停下的规则：任何一步 exit 不是 0 就停，输出原样进回执，不重试、不退回；带管道的命令包进 bash <<'SH' … SH 里跑
不碰：测试电脑、沙箱、knowmart；不点「超时退回」；不写库；受 flux 管的部署不用 rollout restart（要重启就删 Pod，本卡不需要）
```

## 这一轮上什么

| 改了什么 | 为什么 | 出处 |
| --- | --- | --- |
| runner 每一轮对账：本进程新拿到的沙箱都接管（含同名重启的上一任），排队的接着推，在跑的停下残留那一轮再收尾、不重开；取消直接收尾；Codex 那一轮确认结束才放行下一位（最多 900 秒）；放行锁项目再判 | 第 1 稿崩溃后委托卡在「运行中」，取消落实不了，挡住第 2 稿 c1 两小时（丙案人工解开） | SDD 0034 §三.1–三.2、评审 astra |
| 等人答的时间不算进一步的时限；那一轮结束时它里面挂着的问题作废、委托回到在跑；测试推进器答不进去的问题记一次原因 | 第 2 稿第 6 步：所有者思考作答的时间算进 15 分钟，这一步超时，问题挂着，推进器每 5 秒报错 | SDD 0034 §三.5 |
| 模型一次看得到的工具结果放到约 10 万字节（Codex `tool_output_token_limit` 25000）；超过 9 万字节的结果明说太大；knowlab 读文字与表格按字节分页、PDF 按页切 | Codex 对 kimi 默认只给 1 万字节，年报「主要会计数据」那页、三张表的中间几十行都被省掉。Opus 已用真的 Codex 0.155.1 + 假模型实测：新线程带这个设置收到全部 28,966 字节，不带只收到 12,094 字节、中间没了 | 待办账 137 |
| 测试中的卡片显示一行进度（第几条、第几步、步名、第几次、花了多少），已受理没开跑写「已受理，还没开跑」，排队写「在排队」 | 所有者「测试好像目前看不到测试状态和进程」「我们不能只看结果也要了解过程」 | 待办账 135、136 第 ② |

knowbench 后端全量（真库）1264 过；knowlab 后端 518 过；knowlab 管理端 59 条、类型检查、lint、i18n 检查过（管理端生产构建在远程机上内存不够没跑完，本地机构建时会完整跑一遍）。

## 一、核对（只读）

```bash
cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen && git log --oneline -1 && git status --short | head -3
for a in knowbench-app knowlab-app; do git -C ~/worktrees/qwen/$a fetch -q origin && git -C ~/worktrees/qwen/$a pull -q --ff-only origin qwen && git -C ~/worktrees/qwen/$a submodule update --init -q; echo "== $a $(git -C ~/worktrees/qwen/$a rev-parse HEAD)"; git -C ~/worktrees/qwen/$a submodule status; done
make -C infrastructure platform-status; echo "status exit=$?"
```

要看到：k8s HEAD 是本卡这次提交或更新；knowlab 父仓 `d7067945…`、后端 `7298030a…`、管理端 `bcacaeac…`（网页 `a41861d7…` 不变）；knowbench 父仓 `1b88369a…`、后端 `a0181b25…`（网页 `4748b94e…`、管理端 `26964553…` 不变）；`status exit=0`。

## 二、一段：knowlab

### 2.1 改钉（5 行）

```bash
python3 - <<'PY'
import re, pathlib
p = pathlib.Path('infrastructure/applications/sources.yaml'); s = p.read_text()
want = {
  'knowlab': {'parent_revision': 'd70679459e1ff1dc7254d7ffa7a48708537e3252',
      'backend_parent_revision': '7298030a61a0b8ab60e21666a03fde7c84aefa26', 'backend_revision': '7298030a61a0b8ab60e21666a03fde7c84aefa26',
      'admin_parent_revision': 'bcacaeac2500a0d773547d113c81df3ed3a83934', 'admin_revision': 'bcacaeac2500a0d773547d113c81df3ed3a83934'},
}
for app, keys in want.items():
    m = re.search(rf'(?m)^  {app}:\n(?:^    .*\n)*', s); assert m, app
    block = new = m.group(0)
    for k, v in keys.items():
        new, n = re.subn(rf'(?m)^(    {k}: )\w+', rf'\g<1>{v}', new); assert n == 1, (app, k)
    s = s.replace(block, new, 1)
p.write_text(s)
PY
echo "pin exit=$?"; git diff --stat; git diff infrastructure/applications/sources.yaml | grep -c '^+ '
```

要看到：`pin exit=0`；只动 `sources.yaml`；最后一行是 `5`。（Opus 已在 sources.yaml 的副本上空跑过：5 行。）

### 2.2 构建、暂存、计划

```bash
bash <<'SH'
make -C infrastructure platform-build OBJECT=app-platform/knowlab-app > /tmp/q013-build-knowlab.log 2>&1; rc=$?; tail -n 5 /tmp/q013-build-knowlab.log; echo "build knowlab exit=$rc"; [ "$rc" = 0 ] || exit 1
for f in $(git diff --name-only gitops | grep image.lock); do echo "$f: $(grep -E '^source_revision' $f)"; done
make -C infrastructure platform-stage OBJECT=app-platform/knowlab-app; echo "stage knowlab exit=$?"
grep -rn "BEGIN PRIVATE KEY\|BEGIN PUBLIC KEY" gitops/ | head -3; echo key-check-done
git status --short gitops | awk '{print $2}' | sed -E 's#^gitops/(components/[^/]+/[^/]+(/[^/]+)?|clusters/kind)/.*#\1#' | sort | uniq -c
for c in knowlab-app/knowlab-backend knowlab-app/knowlab-admin-frontend; do echo "== $c"; git diff gitops/components/app-platform/$c/runtime/workload.yaml | grep '^[-+] ' | grep -v 'sha256\|digest\|image:'; done
make -C infrastructure application-deployment-plan APP=knowlab > /tmp/q013-plan-knowlab.log 2>&1; echo "plan knowlab exit=$?"; grep -E "schema|revision|ok=|failed=" /tmp/q013-plan-knowlab.log | tail -3
SH
```

要看到：构建、暂存、计划都是 0；变了的镜像锁 **2 个**（knowlab 后端 `7298030a…`、管理端 `bcacaeac…`）；`key-check-done` 前没有文件名；暂存产物只有 knowlab 的后端与管理端；运行时 diff 除镜像与摘要外各只有 `DEPLOYMENT_ID` 一行（管理端若目录名不同，照实贴出）；迁移头 `20261018_0007`。knowbench 或别的应用有变化就停。

### 2.3 提交、发布、晋级、检查

```bash
bash <<'SH'
git add infrastructure/applications/sources.yaml gitops && git -c core.editor=true commit -m "deploy(knowlab): 读用户数据按字节分页、测试中看进度与「已受理」「在排队」（qwen-013 一段）"
make -C infrastructure flux-release; echo "release exit=$?"
sudo cat infrastructure/.build/flux/source-candidate.yaml | sudo tee infrastructure/environments/kind/flux-source.yaml >/dev/null
sudo chown "$(id -u):$(id -g)" infrastructure/environments/kind/flux-source.yaml 2>/dev/null
git add infrastructure/environments/kind/flux-source.yaml && git -c core.editor=true commit -m "release(kind): 晋级到 $(git rev-parse --short HEAD)（qwen-013 一段）"
make -C infrastructure flux-source-apply; echo "apply exit=$?"
export KUBECONFIG=~/.kube/sunmoon-kind.config; K=$(command -v kubectl || echo infrastructure/.tools/bin/kubectl)
$K -n flux-system get kustomizations -o name | grep -E '/knowlab-' | xargs $K -n flux-system wait --for=condition=Ready --timeout=30m; echo "wait exit=$?"
make -C infrastructure application-check APP=knowlab; echo "check knowlab exit=$?"
git push origin qwen
SH
```

要看到：各步都是 0；`application-check` 过、`admin_list_read: true`。先把一段写进回执、提交推送，再做二段。

## 三、二段：knowbench

### 3.1 部署前看一眼（只读，SDD 0034 §三.4）

部署会重启 runner。先看有没有正在要人推的委托：

```sql
select t.id, t.state, t.updated_at, i.kind, i.prompt->'subject'->>'request_id' as request_id
from workbench_tasks t left join workbench_interactions i on i.id = t.active_interaction_id
where t.state in ('VALIDATING', 'QUEUED', 'RUNNING')
   or (t.state = 'WAITING' and coalesce(i.prompt->'subject'->>'request_id', '') <> '');
```

要看到：**只有一行**，c1 `00815b28…`，`WAITING`、`question`、`request_id` 有值（就是卡死的那件，所有者已同意由新代码收尾）。多出任何一行就停，把结果贴给所有者定。

### 3.2 改钉（3 行）

```bash
python3 - <<'PY'
import re, pathlib
p = pathlib.Path('infrastructure/applications/sources.yaml'); s = p.read_text()
want = {
  'knowbench': {'parent_revision': '1b88369a1d74188239ba83317d0565521ba59e57',
      'backend_parent_revision': 'a0181b2514fe486ab08c9359eb7368f7515bfd3a', 'backend_revision': 'a0181b2514fe486ab08c9359eb7368f7515bfd3a'},
}
for app, keys in want.items():
    m = re.search(rf'(?m)^  {app}:\n(?:^    .*\n)*', s); assert m, app
    block = new = m.group(0)
    for k, v in keys.items():
        new, n = re.subn(rf'(?m)^(    {k}: )\w+', rf'\g<1>{v}', new); assert n == 1, (app, k)
    s = s.replace(block, new, 1)
p.write_text(s)
PY
echo "pin exit=$?"; git diff --stat; git diff infrastructure/applications/sources.yaml | grep -c '^+ '
```

要看到：`pin exit=0`；只动 `sources.yaml`；最后一行是 `3`。

### 3.3 构建、暂存、计划

照 2.2，把 `knowlab-app` 换成 `knowbench-app`、`APP=knowlab` 换成 `APP=knowbench`、日志名换成 `q013-*-knowbench`，运行时 diff 只看 `knowbench-app/knowbench-backend`。要看到：变了的镜像锁 **1 个**（knowbench 后端 `a0181b25…`）；暂存产物只有 knowbench 后端；运行时 diff 除镜像与摘要外只有 `DEPLOYMENT_ID`；迁移头 `20261017_0020`。

### 3.4 提交、发布、晋级、检查

照 2.3，提交说明换成 `deploy(knowbench): 委托没人推时不卡死、等人答不算时限、模型看得全工具结果（qwen-013 二段）`、`release(kind): 晋级到 …（qwen-013 二段）`，等的 kustomization 换成 `/knowbench-`，检查换成 `APP=knowbench`，最后再看一眼测试电脑 `1/1 Running`。

## 四、上线后核（只读）

| # | 什么时候 | 做什么 | 要看到 |
| --- | --- | --- | --- |
| 1 | knowbench 就绪后 2 分钟内 | `$K -n app-platform-dev logs deploy/knowbench-runner --since=5m \| grep -E "took over\|advisor stopped\|nobody was driving\|reconcile\|advance failed"` | 有 `took over sandbox=…`；有 `advisor stopped task=00815b28… state=FAILED (nobody was driving it; …)`（或 `CANCELLED`）；没有 `advance failed`、没有 `reconcile keeps failing` |
| 2 | 同上 | 3.1 那条查询再跑一次 | c1 不在里面了 |
| 3 | 5 分钟内 | 所有者在管理端「财务分析与预测」点「刷新结果」 | 卡片上有一行进度：「正在跑 c2（第 2/3 条）· 第 x/8 步 …」，或「已受理，还没开跑」「在排队」之一；不再只是「测试中」 |
| 4 | c2、c3 跑到第 6 步「对照官方披露」时 | `logs … --since=30m \| grep -E "workbench_mcp_result_too_large\|knowbot test could not answer"` | 没有 `workbench_mcp_result_too_large`；专家这次读得到年报的表（不再说「被省略」）——这就是待办账 137 的真模型核对 |
| 5 | 之后每 20 分钟 | 同 qwen-011 第 ⑦ 行看日志，加上所有者给的进度查询 | 没有 `advisor crashed`、`advance failed`；有进度 |
| 6 | 测试结束 | 所有者截图结论 | 三条用例的结论（c1 应是平台错误，原因写「推它的程序重启了」）、期望满足数、没过的步骤与原因原文、花费、结束时间 |

测试中若冒出「待回答的问题」：照旧不在管理端「改由我们答」，截图交所有者用 sig-am 在 web端回答。这次等人答的时间不算进一步的时限，不用赶。

## 回执

`scripts/results/qwen-013.<时间>.md`：一段、二段各步 `exit`、镜像锁、运行时 diff、迁移头、两个 `application-check`；3.1 查询结果原文；第四节每行的日志行与截图描述；测试的最终结论。提交推送后停下等 Opus 审。
