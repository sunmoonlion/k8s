# Qwen 发布卡 qwen-009：判分遇到算出 0 就崩、崩了以后委托一直挂着（knowbench 后端一个镜像）

> 状态：一到四节**已完成**（回执 `scripts/results/qwen-009.20261019-0009.md`）；**第五节作废，由 qwen-011 第五节取代**（换修好的 Excel、用新清单建第 2 稿，不要照本卡第五节贴旧清单）。原状态：可执行（Opus 2026-10-18 写；所有者「那现在就把卡转给qwen让它修吧」）。
> 依据：K19 第一次真测（run `knowlab-433a5349-5301-41da-ad59-3c5db794c4c2-1`）15:08:29Z `advisor crashed`，Qwen 报的栈与查库结果。

```text
被测仓：k8s，qwen 工作树 ~/worktrees/qwen/k8s，分支 qwen
改钉一个应用：knowbench（父仓、后端，共 3 行；网页、管理端不变）
迁移：没有新迁移（knowbench 迁移头 20261017_0020 不变）；配置不改
停下的规则：任何一步 exit 不是 0 就停，输出原样进回执，不重试、不退回；带管道的命令包进 bash <<'SH' … SH 里跑
不碰：K19 那次挂着的测试（knowlab 草稿「财务分析与预测 · 第 1 版 · 第 1 稿」）。不点「超时退回」、不改库；它到 28800 秒超时自己收尾（约 22:55Z）
```

## 这一轮上什么

| 哪里 | 提交 | 内容 |
| --- | --- | --- |
| knowbench 后端 | `ad6d6b4` | ① **崩的根因**：数值验收 `computed` 里拿 `calc.decimal_of(记录的值) or Decimal("NaN")` 判有没有数，算出来是 0 时 `Decimal(0)` 为假，落成 NaN，再比大小就抛 `InvalidOperation`。K19 第 3 步勾稽，差额平了就是 0，所以一判就崩。改成明确判 `None`；记录里不是一个数的，记这一项没过，不崩（`acceptance_numbers.py`）。② **崩了没人收尾**：顾问驾驶中抛了没接住的异常，以前只记一行日志，委托停在 RUNNING、再没人推，测试挂到超时。现在 runner 接住后把开着的尝试记失败（`failure_code=platform`）、委托记失败；测试结果里这条用例记「出错」并写明「某步：the platform failed during this step」，接着跑下一条（`runner.py`、`advisor.py` 的 `fail_after_crash`、`test_runs.py`）。真用户请专家时同样不再挂着 |
| knowbench 父仓 | `dfdc7f4` | 子仓指针 |
| k8s（本卡拉到的提交里） | — | 本卡 |

Opus 在远程机核过：两处各加一条测试，在旧代码上跑分别复现 `InvalidOperation`（`acceptance_numbers.py:41`）与「测试一直 running」，改后都过；knowbench 后端全量（真库）1244 过；改动文件 pyright 0 错。

已知的小缺口（不在本卡修）：崩溃那一轮模型已经花的钱，要判完分才记账，这一轮没判完，所以记不上；这次测试最后显示的花费会比实际略少。

## 一、核对（只读）

```bash
cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen && git log --oneline -1 && git status --short | head -3
git -C ~/worktrees/qwen/knowbench-app fetch -q origin && git -C ~/worktrees/qwen/knowbench-app pull -q --ff-only origin qwen && git -C ~/worktrees/qwen/knowbench-app submodule update --init -q
echo "== knowbench $(git -C ~/worktrees/qwen/knowbench-app rev-parse HEAD)"; git -C ~/worktrees/qwen/knowbench-app submodule status
make -C infrastructure platform-status; echo "status exit=$?"
```

要看到：knowbench 父仓 `dfdc7f4…`，后端 `ad6d6b4…`、网页 `4748b94e…`、管理端 `26964553…`；`status exit=0`。

## 二、改钉（3 行）

```bash
python3 - <<'PY'
import re, pathlib
p = pathlib.Path('infrastructure/applications/sources.yaml'); s = p.read_text()
want = {
  'knowbench': {'parent_revision': 'dfdc7f4313bac6ef92660a60496c7e75e026a824',
      'backend_parent_revision': 'ad6d6b41615287fd76061f8cdf8d881a1811b6c4', 'backend_revision': 'ad6d6b41615287fd76061f8cdf8d881a1811b6c4'},
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

## 三、构建、暂存、计划

```bash
bash <<'SH'
make -C infrastructure platform-build OBJECT=app-platform/knowbench-app > /tmp/q009-build.log 2>&1; rc=$?; tail -n 8 /tmp/q009-build.log; echo "build exit=$rc"; [ "$rc" = 0 ] || exit 1
for f in $(git diff --name-only gitops | grep image.lock); do echo "$f: $(grep -E '^source_revision' $f)"; done
make -C infrastructure platform-stage OBJECT=app-platform/knowbench-app; echo "stage exit=$?"
grep -rn "BEGIN PRIVATE KEY\|BEGIN PUBLIC KEY" gitops/ | head -3; echo key-check-done
git status --short gitops | awk '{print $2}' | sed -E 's#^gitops/(components/[^/]+/[^/]+(/[^/]+)?|clusters/kind)/.*#\1#' | sort | uniq -c
git diff gitops/components/app-platform/knowbench-app/knowbench-backend/runtime/workload.yaml | grep '^[-+] ' | grep -v 'sha256\|digest\|image:'
make -C infrastructure application-deployment-plan APP=knowbench > /tmp/q009-plan.log 2>&1; echo "plan exit=$?"; grep -E "schema|revision|ok=|failed=" /tmp/q009-plan.log | tail -3
SH
```

要看到：构建、暂存、计划都是 0；变了的镜像锁**1 个**（knowbench 后端 `ad6d6b4…`）；`key-check-done` 前没有文件名；暂存产物只有 knowbench-backend；运行时 diff 除镜像与摘要外只有 `DEPLOYMENT_ID` 一行；迁移头 `20261017_0020`。网页、管理端或别的应用有变化就停。

## 四、提交、发布、晋级、检查

```bash
bash <<'SH'
git add infrastructure/applications/sources.yaml gitops && git -c core.editor=true commit -m "deploy: 判分遇到算出 0 不再崩、崩了收尾记出错（qwen-009）"
make -C infrastructure flux-release; echo "release exit=$?"
sudo cat infrastructure/.build/flux/source-candidate.yaml | sudo tee infrastructure/environments/kind/flux-source.yaml >/dev/null
sudo chown "$(id -u):$(id -g)" infrastructure/environments/kind/flux-source.yaml 2>/dev/null
git add infrastructure/environments/kind/flux-source.yaml && git -c core.editor=true commit -m "release(kind): 晋级到 $(git rev-parse --short HEAD)（qwen-009）"
make -C infrastructure flux-source-apply; echo "apply exit=$?"
export KUBECONFIG=~/.kube/sunmoon-kind.config; K=$(command -v kubectl || echo infrastructure/.tools/bin/kubectl)
$K -n flux-system get kustomizations -o name | grep -E '/knowbench-' | xargs $K -n flux-system wait --for=condition=Ready --timeout=30m; echo "wait exit=$?"
make -C infrastructure application-check APP=knowbench; echo "check exit=$?"
$K -n app-platform-dev get pod -l app.kubernetes.io/name=knowbench-test-computer
git push origin qwen
SH
```

要看到：各步都是 0；`application-check` 过、`admin_list_read: true`；测试电脑 `1/1 Running`。

## 五、走查（K19 重测；所有者操作，Qwen 核截图与集群侧证据）

挂着的那次测试**要等它超时收尾**（约 22:55Z，本地 06:55）之后才做下面几行。

| # | 地址（账号） | 做什么 | 要看到 |
| --- | --- | --- | --- |
| 1 | knowlab 管理端「专家草稿」（admin） | 22:55Z 之后在第 1 稿上点「刷新结果」 | 第 1 稿变「测试未通过」（超时收尾）；不点「超时退回」 |
| 2 | 同上 | 在「财务分析与预测」想法上点「看方法并建草稿」，贴 `docs/design/SDD/modules/0029-sample-fin-forecast/manifest-v1.json` 全文（sha256 `7dffd795e480251ae73ca97960f5329e19a38d4de4c4df6b8eb8c39762514a54`，与第 1 稿同一份），点「建草稿」 | 「第 1 版 · 第 2 稿」，规则出处 14 条 |
| 3 | 同上 | 「已逐条核对出处」→ 预算上限 **300**、超时 **28800** →「发起测试」 | 状态「测试中」 |
| 4 | Qwen 在集群侧（开跑后约 15 分钟、之后每小时一次） | `$K -n app-platform-dev logs deploy/knowbench-runner --since=70m \| grep -E "advisor (stopped\|crashed)\|knowbot test\|budget exhausted"` | 没有 `advisor crashed`；用例跑完有 `advisor stopped task=… state=…`；全部跑完有 `knowbot test run finished run=… status=…` |
| 5 | knowlab 管理端（admin） | 测试结束后「刷新结果」 | 截图：三条用例各自的结论、「期望满足 x/y」；没过的那条「第几步没过」与原因全文；状态（「已交付」或「测试未通过」） |
| 6 | 测试中若冒出「待回答的问题」 | 不在管理端「改由我们答」；截图告诉所有者，由所有者用 sig-am 在 web端回答 | — |

## 回执

`scripts/results/qwen-009.<时间>.md`：各步 `exit`、镜像锁一行、运行时那段 diff、迁移头、`application-check`；走查每行的截图描述、第 4 行的日志行、第 5 行三条用例的结论与原因原文、测试结束时页面显示的花费与用时。提交推送后停下等 Opus 审。
