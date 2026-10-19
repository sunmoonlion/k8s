# Qwen 发布卡 qwen-011：K19 重测前排雷——读年报不再卡在超时线上；换上修好的 Excel、用新清单建第 2 稿（两个后端镜像）

> 状态：**已完成**（回执 `scripts/results/qwen-011.20261019-0808.md`：各步 exit=0；第五节建的第 2 稿测试结果另看（c1 没过，第 3 稿见 qwen-015））。原状态：可执行（Opus 2026-10-19 夜里写；所有者「不仅做1，把能做的都做了」）。
> **取代 qwen-009 第五节**：重测按本卡第五节做，不再照 qwen-009 第五节贴旧清单。qwen-010 第五节（看新页面）照做，和本卡第五节一起走。

```text
被测仓：k8s，qwen 工作树 ~/worktrees/qwen/k8s，分支 qwen
改钉两个应用：knowbench（父仓、后端，3 行）、knowlab（父仓、后端，3 行），共 6 行；网页、管理端不变
迁移：没有（knowbench 迁移头 20261017_0020、knowlab 20261018_0007 都不变）；配置不改
停下的规则：任何一步 exit 不是 0 就停，输出原样进回执，不重试、不退回；带管道的命令包进 bash <<'SH' … SH 里跑
不碰：K19 挂着的第 1 稿，等它 22:55Z 自己超时收尾（部署会滚 runner，不影响它按时收尾）
```

## 为什么有这一轮：Opus 夜里的预演

Opus 在远程机照清单的方法，用真数据造出「做对了」的 8 步交回物，走工作台真实的计算工具与判分（`judge`、`judge_numbers`、用例期望）：5 个算数步骤全过、用例 1 的两个期望满足、共 260 次计算，**判分没有第二个会崩的地方**。但查出三件，这一轮一起处理：

| # | 查到什么 | 后果 | 怎么处理 |
| --- | --- | --- | --- |
| 1 | 工作台向 knowlab 读用户数据的超时是 20 秒；knowlab 第一次读一份两百页的年报要抽十几、二十秒文字（远程机实测 2021、2024、2025 三份：18.6、20.4、15.4 秒） | 第 6 步「对照官方披露」要读 5 份年报，第一次读很可能超时；更糟的是 knowlab 抽到一半被取消，结果不进缓存，下次又从头抽、又超时，可能一直读不到。这条路在集群上没走过（第 1 稿崩在第 3 步，qwen-006 只读过 Excel） | knowlab 后端 `ded0470`：抽取单独跑成任务，读的那头走了照样抽完进缓存（新测试在旧代码上复现「又抽一遍」）；knowbench 后端 `9430f7d`：读用户数据的超时放宽到 45 秒（仍短于模型调工具的 60 秒） |
| 2 | 已上传的 Excel 里，2025 年报的「归属于母公司所有者权益（或股东权益）合计」在 PDF 里折成两行，被抽成两行，主行 2025-12-31 是空的（2025 三季报的「负债和所有者权益（或股东权益）总计」同样）。这是 Opus 替所有者整理数据时留下的 | 第 5 步算不出 2025 年的净资产收益率（预演里这一次计算被拒），第 1 步还可能把两行当成「同一科目两个口径」停下来问用户 | 修好抽取脚本、重建 Excel（`0029/data-prep/README.md` 第「2026-10-19 修订」节）：只变这两处，自查加「方法用到的科目每期都有数」。修好的文件在远程机 `/home/zym/sig-am-data/财务分析与预测/修订-2026-10-19/贵州茅台-三张表与主要会计数据.xlsx`，sha256 `517c8810f36e2f2f7274510d163fcf0318396b6fb1602e81bd438f01b5ddec0c`。预演换成它：0 个问题，2025 年净资产收益率算得出 |
| 3 | 方法说明里的科目是标准叫法（「归属于母公司所有者的净利润」），茅台表里写「归属于母公司股东的净利润」；成稿里连「不提供目标价」这种否定句，判分也会拦 | 前者可能让专家以为是两个口径去问用户；后者让成稿多重做一轮 | 清单的说明文字补两句（只是措辞，你的方法、规则出处、验收一个字没动）：写法不同的同一科目照用、不是第二个口径；成稿里不写「目标价」「评级」，连否定句也不写。三个应用的清单检查都过 |

knowbench 后端全量（真库）1245 过；knowlab 后端全量 513 过。

## 一、核对（只读）

```bash
cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen && git log --oneline -1 && git status --short | head -3
for a in knowbench-app knowlab-app; do git -C ~/worktrees/qwen/$a fetch -q origin && git -C ~/worktrees/qwen/$a pull -q --ff-only origin qwen && git -C ~/worktrees/qwen/$a submodule update --init -q; echo "== $a $(git -C ~/worktrees/qwen/$a rev-parse HEAD)"; git -C ~/worktrees/qwen/$a submodule status; done
make -C infrastructure platform-status; echo "status exit=$?"
```

要看到：knowbench 父仓 `13f1f162…`、后端 `9430f7dc…`（网页 `4748b94e…`、管理端 `26964553…` 不变）；knowlab 父仓 `a9a42286…`、后端 `ded0470e…`（管理端 `a940b301…`、网页 `a41861d7…` 不变）；`status exit=0`。

## 二、改钉（6 行）

```bash
python3 - <<'PY'
import re, pathlib
p = pathlib.Path('infrastructure/applications/sources.yaml'); s = p.read_text()
want = {
  'knowbench': {'parent_revision': '13f1f16294eb86aba2eb90de3930a8ca34940db8',
      'backend_parent_revision': '9430f7dcd8fa74d583de1f05cb53fd45ee433936', 'backend_revision': '9430f7dcd8fa74d583de1f05cb53fd45ee433936'},
  'knowlab': {'parent_revision': 'a9a422864aab75598316cad5ce27b2c0fbf2ad73',
      'backend_parent_revision': 'ded0470e937260ff47070c9b8b82cd66c37bc486', 'backend_revision': 'ded0470e937260ff47070c9b8b82cd66c37bc486'},
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

要看到：`pin exit=0`；只动 `sources.yaml`；最后一行是 `6`。

## 三、构建、暂存、计划

```bash
bash <<'SH'
for o in knowbench-app knowlab-app; do
  make -C infrastructure platform-build OBJECT=app-platform/$o > /tmp/q011-build-$o.log 2>&1; rc=$?; tail -n 5 /tmp/q011-build-$o.log; echo "build $o exit=$rc"; [ "$rc" = 0 ] || exit 1
done
for f in $(git diff --name-only gitops | grep image.lock); do echo "$f: $(grep -E '^source_revision' $f)"; done
for o in knowbench-app knowlab-app; do make -C infrastructure platform-stage OBJECT=app-platform/$o; echo "stage $o exit=$?"; done
grep -rn "BEGIN PRIVATE KEY\|BEGIN PUBLIC KEY" gitops/ | head -3; echo key-check-done
git status --short gitops | awk '{print $2}' | sed -E 's#^gitops/(components/[^/]+/[^/]+(/[^/]+)?|clusters/kind)/.*#\1#' | sort | uniq -c
for c in knowbench-app/knowbench-backend knowlab-app/knowlab-backend; do echo "== $c"; git diff gitops/components/app-platform/$c/runtime/workload.yaml | grep '^[-+] ' | grep -v 'sha256\|digest\|image:'; done
for a in knowbench knowlab; do make -C infrastructure application-deployment-plan APP=$a > /tmp/q011-plan-$a.log 2>&1; echo "plan $a exit=$?"; grep -E "schema|revision|ok=|failed=" /tmp/q011-plan-$a.log | tail -3; done
SH
```

要看到：构建、暂存、计划都是 0；变了的镜像锁**2 个**（knowbench 后端 `9430f7dc…`、knowlab 后端 `ded0470e…`）；`key-check-done` 前没有文件名；暂存产物只有这两个后端；两段运行时 diff 除镜像与摘要外各只有 `DEPLOYMENT_ID` 一行；迁移头 knowbench `20261017_0020`、knowlab `20261018_0007`。网页、管理端或别的应用有变化就停。

## 四、提交、发布、晋级、检查

```bash
bash <<'SH'
git add infrastructure/applications/sources.yaml gitops && git -c core.editor=true commit -m "deploy: 读年报不再卡在超时线上（knowlab 抽完必进缓存、knowbench 读数超时 45 秒）（qwen-011）"
make -C infrastructure flux-release; echo "release exit=$?"
sudo cat infrastructure/.build/flux/source-candidate.yaml | sudo tee infrastructure/environments/kind/flux-source.yaml >/dev/null
sudo chown "$(id -u):$(id -g)" infrastructure/environments/kind/flux-source.yaml 2>/dev/null
git add infrastructure/environments/kind/flux-source.yaml && git -c core.editor=true commit -m "release(kind): 晋级到 $(git rev-parse --short HEAD)（qwen-011）"
make -C infrastructure flux-source-apply; echo "apply exit=$?"
export KUBECONFIG=~/.kube/sunmoon-kind.config; K=$(command -v kubectl || echo infrastructure/.tools/bin/kubectl)
$K -n flux-system get kustomizations -o name | grep -E '/(knowbench|knowlab)-' | xargs $K -n flux-system wait --for=condition=Ready --timeout=30m; echo "wait exit=$?"
for a in knowbench knowlab; do make -C infrastructure application-check APP=$a; echo "check $a exit=$?"; done
$K -n app-platform-dev get pod -l app.kubernetes.io/name=knowbench-test-computer
git push origin qwen
SH
```

要看到：各步都是 0；两个 `application-check` 都过、`admin_list_read: true`；测试电脑 `1/1 Running`。部署完先把一到四节写进回执、提交推送，停下等所有者早上来。

## 五、K19 重测（22:55Z 之后；所有者操作，登录由所有者输入；Qwen 核截图、跑命令、看日志）

| # | 谁、在哪 | 做什么 | 要看到 |
| --- | --- | --- | --- |
| 1 | 所有者，knowlab 管理端「专家草稿」（admin，先硬刷新） | 左边点「财务分析与预测」，「下一步」卡片里点「刷新结果」 | 第 1 稿变「测试未通过」（超时收尾） |
| 2 | 所有者（Qwen 可帮着点），knowlab web端「我的数据」（sig-am） | 上传远程机 `/home/zym/sig-am-data/财务分析与预测/修订-2026-10-19/贵州茅台-三张表与主要会计数据.xlsx`（文件名和原来一样，放在单独的目录里） | 上传成功；列表里有两份同名 Excel（旧的留着，第 1 稿还绑着它，删不掉也不用删） |
| 3 | 所有者，管理端「财务分析与预测」→ 页签「用户的数据」 | 找 sha256 是 `517c8810f36e2f2f7274510d163fcf0318396b6fb1602e81bd438f01b5ddec0c` 的那一行，把它的 `dataset_id` 抄给 Qwen | 有这一行；sha256 逐字对上（对不上就停：文件在拷贝中变了） |
| 4 | Qwen，k8s 工作树 | 用新的 Excel 编号生成清单（`<新编号>` 换成第 3 行抄来的；5 份年报的编号不变）：见下面的命令 | `manifest exit=0`；三处检查（若本机有三个应用的 venv）或至少 JSON 合法；`data_bindings` 第 1 条是新编号、sha256 `517c8810…`；提交并推送 `manifest-v1.json`，回执里写它的 sha256 |
| 5 | 所有者，管理端「下一步」卡片 | 把第 4 行生成的 `manifest-v1.json` 全文贴进「建下一稿」的框，点「建草稿」 | 「第 1 版 · 第 2 稿」，规则出处 14 条 |
| 6 | 同上 | 「已逐条核对出处」→ 预算上限 **300**、超时 **28800** →「发起测试」 | 「测试中」，有开跑时间 |
| 7 | Qwen，集群侧（开跑后约 15 分钟、之后每小时一次） | `$K -n app-platform-dev logs deploy/knowbench-runner --since=70m \| grep -E "advisor (stopped\|crashed)\|knowbot test\|budget exhausted"` | 没有 `advisor crashed`；用例跑完有 `advisor stopped task=… state=…`；全部跑完有 `knowbot test run finished run=… status=…` |
| 8 | 所有者，管理端（隔一阵点「刷新结果」） | 测试结束后截图 | 三条用例各自的结论、「期望满足 x/y」；没过的「第几步没过」与原因全文；花费、结束时间；状态（「已交付」或「测试未通过」） |
| 9 | 测试中若冒出「待回答的问题」 | 不在管理端「改由我们答」；截图告诉所有者，由所有者用 sig-am 在 web端回答 | — |

第 4 行的命令（在 `~/worktrees/qwen/k8s` 里跑）：

```bash
bash <<'SH'
cd docs/dev-investment-agent/tree-build/SDD/modules/0029-sample-fin-forecast
NEW='<新编号>'
python3 manifest_v1.py manifest-v1.json "$NEW" 1 517c8810f36e2f2f7274510d163fcf0318396b6fb1602e81bd438f01b5ddec0c \
 2021=35da3157-7472-4404-b7f7-fd4eb8128839:1:f65effdde58bcea99fd6bdb53f61b31d5c432e6dfb2661e5caf05156a433ea5a \
 2022=538285ed-c604-4110-9160-bfdd0ed4d262:1:de394171306b9f2c7d79f54990de2a9e9c99feb54413150180179e24f0d83358 \
 2023=f4703e18-4db5-4bb6-870f-efec5dd0ddac:1:2125ff97a452ea79b0d784e2432f7d224b6aecc330b644b593477d69e22f4ed1 \
 2024=3103d049-ec3f-452b-9a2b-56748cd6efe0:1:5299f4940e2ce4e91084b73dc457d558b9d335fa76fbfee6227e4254eb7f4a30 \
 2025=d1bfb7a8-6a24-47da-a2d1-7cc3e7859e4a:1:474905deeaf0f875fc0a1b097a626c0c7852c427faadc5d7fc7816cbf45ea288
echo "manifest exit=$?"
python3 -c "import json;m=json.load(open('manifest-v1.json'));print(m['data_bindings'][0])"
sha256sum manifest-v1.json
git add manifest-v1.json && git -c core.editor=true commit -m "财务分析与预测清单换上修好的 Excel（数据编号 $NEW）（qwen-011）" && git push origin qwen
SH
```

## 回执

`scripts/results/qwen-011.<时间>.md`：一到四节各步 `exit`、镜像锁两行、两段运行时 diff、迁移头、两个 `application-check`；第五节每行的截图描述、第 3 行的新编号、第 4 行清单的 sha256、第 7 行的日志行、第 8 行三条用例的结论与原因原文、花费与用时。提交推送后停下等 Opus 审。
