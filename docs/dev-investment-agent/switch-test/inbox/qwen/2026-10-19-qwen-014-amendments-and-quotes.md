# Qwen 发布卡 qwen-014：用户补充方法、平台核引文、平台收尾的用例记出错（先 knowlab 后 knowbench）

> 状态：**可执行**（Opus 2026-10-19 写；所有者「好，先写补充方法和引文核的设计」「三处都同意，开始写代码」「好，两处一起改」）。
> 第 2 稿测试已结束（c1 未通过、c2 c3 通过，52 元），现在发版不会打断测试。

```text
被测仓：k8s，qwen 工作树 ~/worktrees/qwen/k8s，分支 qwen
先补 qwen-013 回执第四节第 6 行（第 2 稿最终结论），再做本卡
两段发布，先 knowlab 后 knowbench（契约 knowbot-data/v1 加了核引文接口，提供方先上）：
  一段 knowlab：父仓、后端、网页、管理端，7 行钉；三个镜像（后端、网页、管理端）；一个迁移
  二段 knowbench：父仓、后端，3 行钉；一个镜像（后端）；没有迁移
迁移：knowlab 新迁移头 20261019_0008（新表 knowbot_amendment），config 的 expected_schema_revision 已由本卡同一提交改好；knowbench 迁移头 20261017_0020 不变
停下的规则：任何一步 exit 不是 0 就停，输出原样进回执，不重试、不退回；带管道的命令包进 bash <<'SH' … SH 里跑
不碰：测试电脑、沙箱、knowmart；不写库；不替所有者在 web端填写；受 flux 管的部署不用 rollout restart
```

## 这一轮上什么

| 改了什么 | 为什么 | 出处 |
| --- | --- | --- |
| web端「我在做的专家」每个想法下可以写**补充方法**（哪一步、改成什么、为什么），写下不能改；管理端想法详情加「补充方法」页签，用进出处（`amendment:<id>`）或写理由不照做；核对出处时建稿前写的补充没处理完就挡住 | 用户看了测试结果想改某一步，原来没有地方说，只能对话里转述，规则出处拿不出用户原话 | SDD 0035 |
| knowlab 加核引文接口：PDF 第 N 页里有没有这段字（去空白、全半角统一后一字不差，可跨到下一页）；knowbench 验收加 `quoted`：判「支持」的必须引到原文，引了的都要找得到 | 第 6 步改成拿分析结论对照管理层讨论，判断是模型做的，引文是不是年报里真有由平台核 | SDD 0036 |
| 对账收尾、推它的程序崩了的委托，测试结果里记**出错**并写原因；别的失败也写原因 | 第 2 稿 c1 是平台的事，却记成「未通过 · 在时限内交回」 | 待办账 138 |

knowlab 后端全量（真库）537 过；knowbench 后端全量（真库）1274 过；网页 98 条、管理端 60 条，两边类型检查、lint、i18n、prettier 都过（两个前端的生产构建在远程机上内存不够，本地机构建时会完整跑一遍）。Opus 已在远程机用一份真年报（187 页）跑过核引文：对的页找到、错一页找不到、改一个字找不到、字间插空格找到、跨页找到。

## 〇、先补 qwen-013 回执

所有者截给 Opus 的第 2 稿结论（原文）：

```text
测试报告 · 第 1 版 · 第 2 稿  花费 52 元 · 结束于 2026/10/19 12:44
c1 · 未通过 · 期望满足 0/2 · 第 official 步没过：在时限内交回 · the run ended as failed
c2 · 通过 · 期望满足 1/1
c3 · 通过 · 期望满足 2/2
（三条都附「本次测试没有隔离：测试电脑的本地代理还不支持建、删目录，在共用的工作区里跑」）
```

写进 `scripts/results/qwen-013.20261019-1131.md` 第 6 行，注明「c1 记成未通过而不是平台错误，由待办账 138 修，随 qwen-014 发」，提交推送。

## 一、核对（只读）

```bash
cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen && git log --oneline -1 && git status --short | head -3
for a in knowbench-app knowlab-app; do git -C ~/worktrees/qwen/$a fetch -q origin && git -C ~/worktrees/qwen/$a pull -q --ff-only origin qwen && git -C ~/worktrees/qwen/$a submodule update --init -q; echo "== $a $(git -C ~/worktrees/qwen/$a rev-parse HEAD)"; git -C ~/worktrees/qwen/$a submodule status; done
grep -n "expected_schema_revision" gitops/components/app-platform/knowlab-app/knowlab-backend/config.yaml
make -C infrastructure platform-status; echo "status exit=$?"
```

要看到：k8s HEAD 是本卡这次提交或更新；knowlab 父仓 `6d395c8e…`、后端 `7e1a3cfb…`、网页 `badd0174…`、管理端 `20d6908a…`；knowbench 父仓 `8b4d8e4c…`、后端 `29d69eb6…`（网页 `4748b94e…`、管理端 `26964553…` 不变）；config 是 `'20261019_0008'`；`status exit=0`。

## 二、一段：knowlab

### 2.1 改钉（7 行）

```bash
python3 - <<'PY'
import re, pathlib
p = pathlib.Path('infrastructure/applications/sources.yaml'); s = p.read_text()
want = {
  'knowlab': {'parent_revision': '6d395c8e41b1c3d034c8e8b8d1732424abf62dca',
      'backend_parent_revision': '7e1a3cfbc7b963f0563617a1eba2e97c806d89c8', 'backend_revision': '7e1a3cfbc7b963f0563617a1eba2e97c806d89c8',
      'web_parent_revision': 'badd01742a27870b369255562acfe51604f2d7ee', 'web_revision': 'badd01742a27870b369255562acfe51604f2d7ee',
      'admin_parent_revision': '20d6908a10a25901fa50789806f32f89bc1b118d', 'admin_revision': '20d6908a10a25901fa50789806f32f89bc1b118d'},
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

要看到：`pin exit=0`；只动 `sources.yaml`；最后一行是 `7`。（Opus 已在 sources.yaml 的副本上空跑过：7 行。）

### 2.2 构建、暂存、计划

```bash
bash <<'SH'
make -C infrastructure platform-build OBJECT=app-platform/knowlab-app > /tmp/q014-build-knowlab.log 2>&1; rc=$?; tail -n 5 /tmp/q014-build-knowlab.log; echo "build knowlab exit=$rc"; [ "$rc" = 0 ] || exit 1
for f in $(git diff --name-only gitops | grep image.lock); do echo "$f: $(grep -E '^source_revision' $f)"; done
make -C infrastructure platform-stage OBJECT=app-platform/knowlab-app; echo "stage knowlab exit=$?"
grep -rn "BEGIN PRIVATE KEY\|BEGIN PUBLIC KEY" gitops/ | head -3; echo key-check-done
git status --short gitops | awk '{print $2}' | sed -E 's#^gitops/(components/[^/]+/[^/]+(/[^/]+)?|clusters/kind)/.*#\1#' | sort | uniq -c
for f in knowlab-app/knowlab-backend/runtime/workload.yaml knowlab-app/knowlab-web-frontend/workload.yaml knowlab-app/knowlab-admin-frontend/workload.yaml; do echo "== $f"; git diff gitops/components/app-platform/$f | grep '^[-+] ' | grep -v 'sha256\|digest\|image:'; done
git diff gitops/components/app-platform/knowlab-app/knowlab-backend/migration/workload.yaml | grep '^[-+] ' | grep -v 'sha256\|digest\|image:'
make -C infrastructure application-deployment-plan APP=knowlab > /tmp/q014-plan-knowlab.log 2>&1; echo "plan knowlab exit=$?"; grep -E "schema|revision|ok=|failed=" /tmp/q014-plan-knowlab.log | tail -3
SH
```

要看到：构建、暂存、计划都是 0；变了的镜像锁 **3 个**（knowlab 后端 `7e1a3cfb…`、网页 `badd0174…`、管理端 `20d6908a…`）；`key-check-done` 前没有文件名；暂存产物只有 knowlab 的后端、网页、管理端；运行时 diff 除镜像与摘要外各只有 `DEPLOYMENT_ID` 一行（网页、管理端的 workload 路径若不同，照实找到贴出）；迁移 workload 里 `EXPECTED_SCHEMA_REVISION` 从 `20261018_0007` 变成 `20261019_0008`（另有 Job 名与 `DEPLOYMENT_ID`）；计划核到 `20261019_0008`。knowbench 或别的应用有变化就停。

### 2.3 提交、发布、晋级、检查

照 qwen-013 的 2.3，提交说明换成 `deploy(knowlab): 用户补充方法、核引文接口（qwen-014 一段）`、`release(kind): 晋级到 …（qwen-014 一段）`。另加两行只读：

```bash
$K -n app-platform-dev get jobs | grep knowlab-migrate | tail -2
$K -n app-platform-dev get deploy knowlab-api knowlab-worker knowlab-scheduler -o jsonpath='{range .items[*]}{.metadata.name}={.spec.template.spec.containers[0].image}{"\n"}{end}'
```

要看到：各步都是 0；新的迁移 Job `Complete`；`application-check` 过、`admin_list_read: true`；三个 deploy 镜像摘要与 `image.lock` 一致。先把一段写进回执、提交推送，再做二段。

## 三、二段：knowbench

### 3.1 部署前看一眼（只读，SDD 0034 §三.4）

跑 qwen-013 的 3.1 那条查询。要看到：**0 行**（第 2 稿已结束，没有要人推的委托）。有任何一行就停，把结果贴给所有者定。

### 3.2 改钉（3 行）

```bash
python3 - <<'PY'
import re, pathlib
p = pathlib.Path('infrastructure/applications/sources.yaml'); s = p.read_text()
want = {
  'knowbench': {'parent_revision': '8b4d8e4c317083691b0e156250e941f430d46b65',
      'backend_parent_revision': '29d69eb671a9e45a9b47543569b570c60bdff9ef', 'backend_revision': '29d69eb671a9e45a9b47543569b570c60bdff9ef'},
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

照 qwen-013 的 3.3（日志名换成 `q014-*-knowbench`）。要看到：变了的镜像锁 **1 个**（knowbench 后端 `29d69eb6…`）；暂存产物只有 knowbench 后端；运行时 diff 除镜像与摘要外只有 `DEPLOYMENT_ID`；迁移头 `20261017_0020`。

### 3.4 提交、发布、晋级、检查

照 qwen-013 的 3.4，提交说明换成 `deploy(knowbench): 验收核引文、平台收尾的用例记出错（qwen-014 二段）`、`release(kind): 晋级到 …（qwen-014 二段）`，最后看一眼测试电脑 `1/1 Running`、runner 新 Pod `1/1 Running`。

## 四、上线后核

| # | 谁 | 做什么 | 要看到 |
| --- | --- | --- | --- |
| 1 | Qwen | `$K -n app-platform-dev logs deploy/knowbench-runner --since=5m \| grep -E "took over\|advisor stopped\|reconcile\|advance failed\|Traceback"` | 有 `took over sandbox=…`；没有 `advisor stopped`（没有要收尾的委托）、没有 `advance failed`、`reconcile keeps failing`、`Traceback` |
| 2 | 所有者 | 用 sig-am 登录 web端，「我在做的专家」→「财务分析与预测」下面点「写一条补充」，写自己的补充方法并提交 | 列表里出现这一条，状态「待处理」 |
| 3 | 所有者 | 管理端「专家草稿」→「财务分析与预测」→ 页签「补充方法」 | 看到第 2 行写的那一条、「待处理」、下面一行「出处写：amendment:…」和「不照做」的输入框（**不要点不照做**） |
| 4 | Qwen | 把第 2、3 行的截图描述写进回执（不抄补充的原文全文，写前 20 个字即可；截图不带地址栏里的 code=、token=、state=） | — |

第 2 行的补充由所有者自己写（方法只来自用户，C-L1），Qwen 不代填、不在管理端改由我们写。

## 回执

`scripts/results/qwen-014.<时间>.md`：先写〇（qwen-013 回执已补）；一段、二段各步 `exit`、镜像锁、运行时与迁移 diff、迁移头、迁移 Job、两个 `application-check`；3.1 查询结果原文；第四节各行。提交推送后停下等 Opus 审。第 3 稿由 Opus 照补充建，不在本卡。
