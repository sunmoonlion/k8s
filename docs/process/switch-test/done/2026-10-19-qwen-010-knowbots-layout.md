# Qwen 发布卡 qwen-010：knowlab 管理端「专家草稿」页重排（一个镜像）

> 状态：**已完成**（回执 `scripts/results/qwen-010.20261019-0054.md`：各步 exit=0）。原状态：可执行（Opus 2026-10-19 写；所有者「页面布局实在太差，比如看状态，点击创建后又要翻到前面，然后刷新结果又到后面。。。总之很乱，你重新设置一下」）。
> 排在 qwen-009 之后、qwen-009 第五节（K19 重测）之前：重测时用新页面。

```text
被测仓：k8s，qwen 工作树 ~/worktrees/qwen/k8s，分支 qwen
改钉一个应用：knowlab（父仓、管理端，共 3 行；后端、网页不变）
迁移：没有；配置不改；后端接口不变（只动页面）
停下的规则：任何一步 exit 不是 0 就停，输出原样进回执，不重试、不退回；带管道的命令包进 bash <<'SH' … SH 里跑
不碰：K19 那次挂着的测试（「财务分析与预测 · 第 1 版 · 第 1 稿」），照 qwen-009 等它 22:55Z 自己超时收尾
```

## 这一轮上什么

| 哪里 | 提交 | 内容 |
| --- | --- | --- |
| knowlab 管理端 | `a940b30` | 「专家草稿」页重排。以前「草稿」（按状态筛）和「用户的提交」上下两块分开，一个专家的事要来回翻：建完草稿翻回上面，刷新结果又在别处。现在：**左边**列用户的提交，有问题待回答的、测试中的、要我们动手的排前面，可按「全部 / 要我们动手 / 测试中 / 未通过 / 已交付」筛；**右边**一次只看一个想法，从上到下是：进度（建草稿 → 核对出处 → 测试 → 交付）、**下一步**卡片（这一步要填的、要点的都在里面：贴清单建草稿、逐条核出处、预算与超时并发起测试、刷新结果与超时退回、重试交付；测试中显示开跑时间、已跑几分钟、上次刷新时间）、这个想法的待回答问题、测试结果（花费、结束时间、每条用例的结论与没过的原因）；没过时先列结果、再建下一稿。对照材料放进页签：用户的方法、验收用例（表格，不再是原始 JSON）、用户的数据（附 data_bindings 可照抄）、规则出处、答过的问题、历次草稿。手机宽度下左右叠成上下 |
| knowlab 父仓 | `cf675d7` | 子仓指针（相对线上的 `81a589a` 只多这一处） |
| k8s（本卡拉到的提交里） | — | 本卡 |

Opus 在远程机核过：管理端 `pnpm check` 全过（类型、lint、多语言、58 条测试、生产构建）；组件测试改成新布局并加 4 条（左边排序与筛选、切换想法、测试中显示已跑多久与上次刷新、没过后下一稿与历次草稿、用例表格）；用本地生产构建加假数据截图核过「测试中带问题」「没通过」「待核出处」三种状态的 1440 与 390 宽度。部署检查 `check-browser.py` 只核管理端列表接口能读（`admin_list_read`），不认页面文字，不受影响。

## 一、核对（只读）

```bash
cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen && git log --oneline -1 && git status --short | head -3
git -C ~/worktrees/qwen/knowlab-app fetch -q origin && git -C ~/worktrees/qwen/knowlab-app pull -q --ff-only origin qwen && git -C ~/worktrees/qwen/knowlab-app submodule update --init -q
echo "== knowlab $(git -C ~/worktrees/qwen/knowlab-app rev-parse HEAD)"; git -C ~/worktrees/qwen/knowlab-app submodule status
make -C infrastructure platform-status; echo "status exit=$?"
```

要看到：knowlab 父仓 `cf675d71…`，管理端 `a940b301…`、后端 `836587c8…`、网页 `a41861d7…`；`status exit=0`。

## 二、改钉（3 行）

```bash
python3 - <<'PY'
import re, pathlib
p = pathlib.Path('infrastructure/applications/sources.yaml'); s = p.read_text()
want = {
  'knowlab': {'parent_revision': 'cf675d71b7c2a0a20381380a3aabff2c1c94effb',
      'admin_parent_revision': 'a940b301d43edd900075e75edf96136aeb5cc7c7', 'admin_revision': 'a940b301d43edd900075e75edf96136aeb5cc7c7'},
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
make -C infrastructure platform-build OBJECT=app-platform/knowlab-app > /tmp/q010-build.log 2>&1; rc=$?; tail -n 8 /tmp/q010-build.log; echo "build exit=$rc"; [ "$rc" = 0 ] || exit 1
for f in $(git diff --name-only gitops | grep image.lock); do echo "$f: $(grep -E '^source_revision' $f)"; done
make -C infrastructure platform-stage OBJECT=app-platform/knowlab-app; echo "stage exit=$?"
grep -rn "BEGIN PRIVATE KEY\|BEGIN PUBLIC KEY" gitops/ | head -3; echo key-check-done
git status --short gitops | awk '{print $2}' | sed -E 's#^gitops/(components/[^/]+/[^/]+(/[^/]+)?|clusters/kind)/.*#\1#' | sort | uniq -c
make -C infrastructure application-deployment-plan APP=knowlab > /tmp/q010-plan.log 2>&1; echo "plan exit=$?"; grep -E "schema|revision|ok=|failed=" /tmp/q010-plan.log | tail -3
SH
```

要看到：构建、暂存、计划都是 0；变了的镜像锁**1 个**（knowlab 管理端 `a940b301…`）；`key-check-done` 前没有文件名；暂存产物只有 knowlab 管理端；迁移头 `20261018_0007` 不变。后端、网页或别的应用有变化就停。

## 四、提交、发布、晋级、检查

```bash
bash <<'SH'
git add infrastructure/applications/sources.yaml gitops && git -c core.editor=true commit -m "deploy: knowlab 管理端专家草稿页重排（qwen-010）"
make -C infrastructure flux-release; echo "release exit=$?"
sudo cat infrastructure/.build/flux/source-candidate.yaml | sudo tee infrastructure/environments/kind/flux-source.yaml >/dev/null
sudo chown "$(id -u):$(id -g)" infrastructure/environments/kind/flux-source.yaml 2>/dev/null
git add infrastructure/environments/kind/flux-source.yaml && git -c core.editor=true commit -m "release(kind): 晋级到 $(git rev-parse --short HEAD)（qwen-010）"
make -C infrastructure flux-source-apply; echo "apply exit=$?"
export KUBECONFIG=~/.kube/sunmoon-kind.config; K=$(command -v kubectl || echo infrastructure/.tools/bin/kubectl)
$K -n flux-system get kustomizations -o name | grep -E '/knowlab-' | xargs $K -n flux-system wait --for=condition=Ready --timeout=30m; echo "wait exit=$?"
make -C infrastructure application-check APP=knowlab; echo "check exit=$?"
git push origin qwen
SH
```

要看到：各步都是 0；`application-check` 过、`admin_list_read: true`。

## 五、走查（所有者看，Qwen 核截图；浏览器先硬刷新，免得还是旧页面）

| # | 地址（账号） | 做什么 | 要看到 |
| --- | --- | --- | --- |
| 1 | knowlab 管理端「专家草稿」（admin） | 打开页面 | 左边是提交列表，上面一排筛选（全部 / 要我们动手 / 测试中 / 未通过 / 已交付，各带个数）；右边是选中的那个想法 |
| 2 | 同上 | 点「财务分析与预测」 | 右边标题旁是状态；下面一排进度；「下一步」卡片里是现在能做的事（22:55Z 前是「测试中」，有「刷新结果」「超时退回」、开跑时间与已跑几分钟） |
| 3 | 同上 | 点「刷新结果」 | 页面不跳、不用往回翻；按钮旁出现「上次刷新 …」 |
| 4 | 同上 | 点下面页签「验收用例」「用户的数据」「历次草稿」 | 用例是表格（第 1 条 2024 营业收入 170899152276.34、允许误差 0.001）；数据下面有可照抄的 data_bindings；历次草稿列出各稿状态 |
| 5 | 同上（22:55Z 之后，接 qwen-009 第五节） | 第 1 稿超时收尾后刷新 | 状态「测试未通过」；结果在上，「建下一稿」的清单框在下；在这里贴清单建第 2 稿，接着核出处、发起测试都在同一张卡片里 |

## 回执

`scripts/results/qwen-010.<时间>.md`：各步 `exit`、镜像锁一行、迁移头、`application-check`、走查每行的截图描述。提交推送后停下等 Opus 审。
