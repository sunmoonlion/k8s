# Qwen 发布卡 qwen-016：创意、分身、专家三栏；测试结果带回成稿与各步交回物（先 knowbench 后 knowlab）

> 状态：**已完成**（回执 `scripts/results/qwen-016.20261019-2149.md`：一段 knowbench、二段 knowlab 各步 exit=0，钉、镜像锁、迁移头 `20261019_0021` / `20261019_0010`、迁移 Job、线上摘要都对，Opus 审过；第四节第 2–10 行所有者看过（2026-10-19「我都查过了，都符合要求，不要截图了吧」），第 11 行截图描述免了；第 1 行第三条原判据写错了（每小时的任务启动满一小时才第一次发，10 分钟内必为 0），改用 `beat_schedule` 登记证明，已改在表里）。原状态：可执行（Opus 2026-10-19 写；所有者「都按你的建议，交回物也带上，先写设计」「创意、新手、专家，按这个写设计」「就叫分身」「好，按这个改设计」「好，开始写代码」；Astra、远程 Fable 评审后「按建议，然后完成代码完善。最后删除三份文档然后发版」）。
> 设计 [0037](../../../design/SDD/modules/0037-idea-avatar-expert.md)。qwen-015（第 3 稿测试）暂停着，本卡上线后改写再发。

```text
被测仓：k8s，qwen 工作树 ~/worktrees/qwen/k8s，分支 qwen
两段发布，先 knowbench 后 knowlab（knowlab 要调 knowbench 新加的产出接口）：
  一段 knowbench：父仓、后端，3 行钉；一个镜像（后端）；一个迁移
  二段 knowlab：父仓、后端、网页、管理端，7 行钉；三个镜像（后端、网页、管理端）；一个迁移
迁移：knowbench 新迁移头 20261019_0021（workbench_test_cases 加 outputs 列）；knowlab 两个新迁移，新迁移头 20261019_0010
  （0009 新表 knowbot_test_output，0010 knowbot_request 加 consent_version、老数据回填 1）；两边 config 的 expected_schema_revision 已由本卡同一提交改好
knowlab 后端另加一个定时任务（beat 每小时：分身交付或被取代满 90 天清掉产出正文），同一镜像，不加组件
knowlab 后端 config 另改一处：WEB_AUTH_ALLOWED_RETURN_PATHS 加 web端新页（questions、ideas、avatars、experts、data，中英两份）
停下的规则：任何一步 exit 不是 0 就停，输出原样进回执，不重试、不退回；带管道的命令包进 bash <<'SH' … SH 里跑
不碰：测试电脑、沙箱、knowmart；不写库；不替所有者在 web端填写或提交；受 flux 管的部署不用 rollout restart
```

## 这一轮上什么

| 改了什么 | 为什么 | 出处 |
| --- | --- | --- |
| knowbench 每条用例跑完那一刻取它的**成稿**（只读这条用例这次真写了的文件）与**各步交回物**（通过的那一版；没过的最后一次交回原文与逐条验收；没走到的），存 30 天；新接口给 knowlab 取 | 写清单的是测试人员，看不到成稿验证不了这一稿；用例共用工作区，晚了成稿被下一条盖掉，测完目录就删 | 0037 §五 |
| knowlab 刷新结果时每条有结论的用例取一次产出，存新表，跟着分身留着；管理端看全部，web端只看自己的（接口上就挡，不是自己的 404） | 运营验证这一稿；用户作验收依据（`C-L3`）；0027「不回任何分析内容」改掉 | 0037 §五、§六 |
| 管理端拆成「创意 / 分身 / 专家」三栏，各带「要我们动手」的数；分身一页走完四段（孵化 → 核出处 → 测试 → 交付），孵化是一整块（现在是手工孵化：贴清单）；测完看每条用例的成稿（排版显示）与各步交回物；对照材料进右边可折叠栏；治理控制台加「要我们动手」 | 所有者「把seed infant和bot分三栏」「像knowbench那样加折叠边栏」「建分身将来是一个很大的工程……我们要为将来考虑」 | 0037 §三 |
| web端加外壳与导航（首页、待我回答、创意、分身、专家、我的数据），按用户的事排，不照搬管理端；分身页成稿放最前；提交时的同意文字改成「只给你自己和做测试的工作人员看」 | 所有者「现在的knowlab好像太简单，也太潦草……但干净完全一样好像不太对」 | 0037 §四 |
| 叫法：创意、分身、专家；「第 1 版 · 第 3 稿」→「分身 1.3」；旧的 `/knowbots` 两端都转到「创意」 | 所有者定 | 0037 §二 |

knowbench 后端全量（真库）1293 过、8 跳过（跳过数同以前）；knowlab 后端全量（真库）558 过；管理端 68 条、网页 115 条，两边类型检查、lint、i18n、prettier 都过（两个前端的生产构建在远程机上内存不够，本地机构建时会完整跑一遍）。

## 一、核对（只读）

```bash
cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen && git log --oneline -1 && git status --short | head -3
for a in knowbench-app knowlab-app; do git -C ~/worktrees/qwen/$a fetch -q origin && git -C ~/worktrees/qwen/$a pull -q --ff-only origin qwen && git -C ~/worktrees/qwen/$a submodule update --init -q; echo "== $a $(git -C ~/worktrees/qwen/$a rev-parse HEAD)"; git -C ~/worktrees/qwen/$a submodule status; done
grep -n "expected_schema_revision" gitops/components/app-platform/knowbench-app/knowbench-backend/config.yaml gitops/components/app-platform/knowlab-app/knowlab-backend/config.yaml
grep -c "/zh-CN/avatars" gitops/components/app-platform/knowlab-app/knowlab-backend/config.yaml
make -C infrastructure platform-status; echo "status exit=$?"
```

要看到：k8s HEAD 是本卡这次提交或更新；knowbench 父仓 `c38dca6c…`、后端 `44888e23…`（网页 `4748b94e…`、管理端 `26964553…` 不变）；knowlab 父仓 `aa51ed9e…`、后端 `7c9731cd…`、网页 `6da5cef5…`、管理端 `d46b6bd5…`；config 是 `'20261019_0021'` 与 `'20261019_0010'`；`/zh-CN/avatars` 计数 `1`；`status exit=0`。

## 二、一段：knowbench

### 2.1 部署前看一眼（只读，SDD 0034 §三.4）

跑 qwen-013 的 3.1 那条查询。要看到：**0 行**（没有在跑的测试）。有任何一行就停，把结果贴给所有者定。

### 2.2 改钉（3 行）

```bash
python3 - <<'PY'
import re, pathlib
p = pathlib.Path('infrastructure/applications/sources.yaml'); s = p.read_text()
want = {
  'knowbench': {'parent_revision': 'c38dca6c913eaceef23f5fac6a7d611c42cb0246',
      'backend_parent_revision': '44888e23934fc50479fb0ddba978e794f62236a4', 'backend_revision': '44888e23934fc50479fb0ddba978e794f62236a4'},
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

要看到：`pin exit=0`；只动 `sources.yaml`；最后一行是 `3`。（Opus 已在 sources.yaml 的副本上空跑过：3 行。）

### 2.3 构建、暂存、计划

```bash
bash <<'SH'
make -C infrastructure platform-build OBJECT=app-platform/knowbench-app > /tmp/q016-build-knowbench.log 2>&1; rc=$?; tail -n 5 /tmp/q016-build-knowbench.log; echo "build knowbench exit=$rc"; [ "$rc" = 0 ] || exit 1
for f in $(git diff --name-only gitops | grep image.lock); do echo "$f: $(grep -E '^source_revision' $f)"; done
make -C infrastructure platform-stage OBJECT=app-platform/knowbench-app; echo "stage knowbench exit=$?"
grep -rn "BEGIN PRIVATE KEY\|BEGIN PUBLIC KEY" gitops/ | head -3; echo key-check-done
git status --short gitops | awk '{print $2}' | sed -E 's#^gitops/(components/[^/]+/[^/]+(/[^/]+)?|clusters/kind)/.*#\1#' | sort | uniq -c
git diff gitops/components/app-platform/knowbench-app/knowbench-backend/runtime/workload.yaml | grep '^[-+] ' | grep -v 'sha256\|digest\|image:'
git diff gitops/components/app-platform/knowbench-app/knowbench-backend/migration/workload.yaml | grep '^[-+] ' | grep -v 'sha256\|digest\|image:'
make -C infrastructure application-deployment-plan APP=knowbench > /tmp/q016-plan-knowbench.log 2>&1; echo "plan knowbench exit=$?"; grep -E "schema|revision|ok=|failed=" /tmp/q016-plan-knowbench.log | tail -3
SH
```

要看到：构建、暂存、计划都是 0；变了的镜像锁 **1 个**（knowbench 后端 `44888e23…`）；`key-check-done` 前没有文件名；暂存产物只有 knowbench 后端；运行时 diff 除镜像与摘要外只有 `DEPLOYMENT_ID`；迁移 workload 里 `EXPECTED_SCHEMA_REVISION` 从 `20261017_0020` 变成 `20261019_0021`（另有 Job 名与 `DEPLOYMENT_ID`）；计划核到 `20261019_0021`。knowlab 或别的应用有变化就停。

### 2.4 提交、发布、晋级、检查

照 qwen-014 二段的 3.4，提交说明换成 `deploy(knowbench): 每条用例的成稿与各步交回物（qwen-016 一段）`、`release(kind): 晋级到 …（qwen-016 一段）`。另加只读三行：

```bash
$K -n app-platform-dev get jobs -o name | grep knowbench-migrate | sort | tail -3
$K -n app-platform-dev get deploy knowbench-api knowbench-runner knowbench-scheduler knowbench-worker -o jsonpath='{range .items[*]}{.metadata.name}={.spec.template.spec.containers[0].image}{"\n"}{end}'
$K -n app-platform-dev get pods | grep -E "knowbench-test-computer|knowbench-runner"
```

要看到：各步都是 0；新的迁移 Job `Complete`（按新 Job 名直查）；`application-check` 过、`admin_list_read: true`；四个 deploy 镜像摘要与 `image.lock` 一致；测试电脑与新 runner Pod `1/1 Running`。先把一段写进回执、提交推送，再做二段。

## 三、二段：knowlab

### 3.1 改钉（7 行）

```bash
python3 - <<'PY'
import re, pathlib
p = pathlib.Path('infrastructure/applications/sources.yaml'); s = p.read_text()
want = {
  'knowlab': {'parent_revision': 'aa51ed9eb8ca1decf6124b0a1c93c1a68b6cf515',
      'backend_parent_revision': '7c9731cdbe79f8be7f00bf6c73ebcf7a70dffd8e', 'backend_revision': '7c9731cdbe79f8be7f00bf6c73ebcf7a70dffd8e',
      'web_parent_revision': '6da5cef54da34d616146530a09cbf8ae73c21acd', 'web_revision': '6da5cef54da34d616146530a09cbf8ae73c21acd',
      'admin_parent_revision': 'd46b6bd5ad03c3675f165f573713c82e4cafb5bf', 'admin_revision': 'd46b6bd5ad03c3675f165f573713c82e4cafb5bf'},
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

要看到：`pin exit=0`；只动 `sources.yaml`；最后一行是 `7`。（Opus 已在副本上接着一段空跑过：7 行。）

### 3.2 构建、暂存、计划

照 qwen-014 一段的 2.2（日志名换成 `q016-*-knowlab`）。要看到：变了的镜像锁 **3 个**（knowlab 后端 `7c9731cd…`、网页 `6da5cef5…`、管理端 `d46b6bd5…`）；暂存产物只有 knowlab 的后端、网页、管理端；网页、管理端运行时 diff 除镜像与摘要外只有 `DEPLOYMENT_ID`；**后端运行时 diff 另有一行 `WEB_AUTH_ALLOWED_RETURN_PATHS`**（多了 questions、ideas、avatars、experts、data 中英各一）；迁移 workload 里 `EXPECTED_SCHEMA_REVISION` 从 `20261019_0008` 变成 `20261019_0010`；计划核到 `20261019_0010`。走查时核一眼 `knowlab-backend/runtime/workload.yaml` 那一行 `WEB_AUTH_ALLOWED_RETURN_PATHS` 确实变成了 16 条（暂存重渲染出来的，不是手改的）。knowbench 或别的应用有变化就停。

### 3.3 提交、发布、晋级、检查

照 qwen-014 一段的 2.3，提交说明换成 `deploy(knowlab): 创意、分身、专家三栏，成稿与各步交回物（qwen-016 二段）`、`release(kind): 晋级到 …（qwen-016 二段）`；新迁移 Job 按 Job 名直查 `Complete`；三个后端 deploy 镜像摘要与 `image.lock` 一致。

## 四、上线后核

| # | 谁 | 做什么 | 要看到 |
| --- | --- | --- | --- |
| 1 | Qwen | `$K -n app-platform-dev logs deploy/knowbench-runner --since=10m \| grep -E "advance failed\|Traceback\|outputs failed"`；`$K -n app-platform-dev logs deploy/knowlab-api --since=10m \| grep -E "Traceback\|outputs not fetched"`；`$K -n app-platform-dev logs deploy/knowlab-scheduler --since=10m \| grep -c knowbot_outputs`（beat 登记了新任务） | 前两条没有命中；第三条：每小时的任务从 beat 启动满一小时才第一次发，刚上线必为 0，改用 `$K -n app-platform-dev exec deploy/knowlab-scheduler -- python -c "from app.worker import celery_app; print(sorted(celery_app.conf.beat_schedule))"`，输出里有 `knowbot-outputs-expire` 就过 |
| 2 | 所有者 | 管理端硬刷新 | 左边一级导航「治理控制台 / 创意 / 分身 / 专家 / CRUD 参考 / 富能力参考 / 设置」；治理控制台多一块「要我们动手」 |
| 3 | 所有者 | 管理端「创意」→「财务分析与预测」 | 状态标签；主栏「照这个创意孵化一个分身」、补充方法、「它的分身」列出分身 1.1、1.2；右边可折叠栏有「用户的方法 / 验收用例 / 用户的数据 / 答过的问题」，能收起、展开 |
| 4 | 所有者 | 点「分身 1.2」 | 进分身页那一个；四段进度「✓ 孵化 → 核对出处 → 测试 → 交付」；测试报告在；「成稿与各步交回物」一块写「这个创意是在旧的测试数据说明下提交的……」（sig-am 的创意是旧说明下提交的，正常）；右边栏有「规则出处 / 清单原文 / … / 历次分身」 |
| 5 | 所有者 | 分身页右上「孵化一个分身」，看一眼就点「先不孵化」 | 出现「孵化」一块：选创意、手工孵化的说明、贴清单的框；**不贴不点孵出** |
| 6 | 所有者 | 开一个**没登录**的窗口（无痕），直接打开 `https://knowlab.sunmoonai.com:30443/zh-CN/avatars`，用 sig-am 登录 | 登录完回到「分身」页，不是首页（外壳不再吃掉回跳） |
| 7 | 所有者 | 在 sig-am 的 web端：左边导航 | 「首页 / 待我回答 / 创意 / 分身 / 专家 / 我的数据」；「分身」里能看到分身 1.1、1.2 的结论 |
| 8 | 所有者 | web端「创意」→「财务分析与预测」：读那段「新说明」，同意就点「同意新说明」 | 提示消失；以后第 3 稿的测试才会取、才会显示成稿与各步结果（**这一步是你本人的同意，Qwen 不代点**） |
| 9 | 所有者 | 「提交一个创意」页看一眼同意文字，**不提交** | 文字是新的：只给你自己和做测试的工作人员看、不拿去训练、不给别的用户、90 天后清掉 |
| 10 | 所有者 | 两端各在地址栏打开旧的 `/zh-CN/knowbots` | 转到 `/zh-CN/ideas` |
| 11 | Qwen | 把第 2–10 行的截图描述写进回执（截图不带地址栏里的 code=、token=、state=） | — |

第 3 稿测试（qwen-015 改写）时多看一行：测完任一用例「成稿与各步交回物」里成稿不为空，或写的原因是什么；原因里有 `-32010` 就查测试电脑上 `/workspace` 到底稿的路径有没有经过符号链接（代理读文件不跟链接）。

## 回执

`scripts/results/qwen-016.<时间>.md`：一段、二段各步 `exit`、镜像锁、运行时与迁移 diff、迁移头、迁移 Job、两个 `application-check`；2.1 查询结果原文；第四节各行。提交推送后停下等 Opus 审。审过之后 Opus 改写 qwen-015（第 3 稿测试），那一次是第一次真跑出成稿与交回物。
