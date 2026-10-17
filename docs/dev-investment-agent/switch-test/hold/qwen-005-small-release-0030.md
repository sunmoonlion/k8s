# Qwen 发布卡 qwen-005：0030 计算工具与数值验收 + 成稿导出 + 分栏可拖 + 提示语（小发布）

> 状态：**写好，暂缓**（放在 `hold/`）。**0028 R5、R6 都写了「通过」之后**移进 `inbox/qwen/` 才做。Opus 2026-10-17 写。
> 依据：0030（C3：随 R5 之后的下一次发布上线）、0031（成稿导出）、待办账 121（Windows 工作说明）、124（分栏）、K17、K18；所有者 2026-10-17「把能做的先做」。

```text
被测仓：k8s，qwen 工作树 ~/worktrees/qwen/k8s，分支 qwen
改钉两个应用：knowlab（父仓、后端、网页）、knowbench（父仓、后端、网页）；两个管理端不动
没有新迁移、没有配置改动（Opus 核过：两边 alembic 与 core/config.py 都没变）；compute 与按格子读走现有的 knowlab:read 关系与 knowlab 内部入口（路径前缀 /api/internal/v1/knowlab 已涵盖）
停下的规则：任何一步 exit 不是 0 就停，输出原样进回执，不重试、不退回
```

## 这一轮上什么

| 应用 | 提交 | 内容 |
| --- | --- | --- |
| knowlab 后端 | `c979112` | 契约 `knowbot-data/v1` 加 `table`、`cells`：CSV、Excel 按格子读，数一律十进制字符串（0030 C1） |
| knowlab 网页 | `0da34a3` | 「我的数据」提示数字类尽量传表格（K17）；验收用例写明期望值只能由用户填（K18） |
| knowbench 后端 | `b2b9dc9`（含 `2e861ce`、`5f8e39e`、`b227b9c`） | 分身的 `compute`、`read_my_table`、计算记录、数值验收 `computed`/`identity`/`sourced`（0030 C1）；重做提示带上没过的各条；Windows 上写文件、跑脚本的说明（待办 121） |
| knowbench 网页 | `537743d`（含 `4acd320`、`37ada6a`） | 成稿导出 Word、Excel、PDF（0031）；左右分栏可拖、左侧导航可折叠、输入框长高上限放宽（待办 124） |
| knowlab 父仓 | `117bea9` | 契约 schema 四份新增、子仓指针 |
| knowbench 父仓 | `2959564` | 契约锁、子仓指针 |

Opus 在远程机核过：knowlab 后端全量 396 过；knowbench 后端全量（真库）1121 过；knowbench 网页 `pnpm check` 全过（295 条测试）；knowlab 网页类型、lint、92 条测试过。

## 一、核对（只读）

```bash
cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen && git log --oneline -1 && git status --short | head -3
for r in knowlab-app knowbench-app; do git -C ~/worktrees/qwen/$r fetch -q origin && git -C ~/worktrees/qwen/$r checkout -q qwen && git -C ~/worktrees/qwen/$r pull -q --ff-only origin qwen && git -C ~/worktrees/qwen/$r submodule update --init -q; done
git -C ~/worktrees/qwen/knowlab-app rev-parse HEAD; git -C ~/worktrees/qwen/knowlab-app submodule status
git -C ~/worktrees/qwen/knowbench-app rev-parse HEAD; git -C ~/worktrees/qwen/knowbench-app submodule status
make -C infrastructure platform-status; echo "status exit=$?"
```

要看到：knowlab 父仓 `117bea97…`、后端 `c979112c…`、网页 `0da34a36…`、管理端 `371abcee…`；knowbench 父仓 `2959564b…`、后端 `b2b9dc9f…`、网页 `537743d9…`、管理端 `45fcf79a…`（不是就停，请所有者同步 qwen）；`status exit=0`。

## 二、改钉（只动这两个应用的父仓、后端、网页，共十行）

```bash
python3 - <<'PY'
import re, pathlib
p = pathlib.Path('infrastructure/applications/sources.yaml'); s = p.read_text()
want = {
  'knowlab': {'parent_revision': '117bea97fffb975995604edb023f482288eb083b',
              'backend_parent_revision': 'c979112c67f8cfd9a3cfbeaed7d36740ee27fed4', 'backend_revision': 'c979112c67f8cfd9a3cfbeaed7d36740ee27fed4',
              'web_parent_revision': '0da34a36a950df4e423432e6d05173d294c26882', 'web_revision': '0da34a36a950df4e423432e6d05173d294c26882'},
  'knowbench': {'parent_revision': '2959564bca85919db5b17f616cd03685c976ed6c',
                'backend_parent_revision': 'b2b9dc9fdd124bd1fb9e07808218c0feb890a4ba', 'backend_revision': 'b2b9dc9fdd124bd1fb9e07808218c0feb890a4ba',
                'web_parent_revision': '537743d9aaa34dee14b3fa8ad01ead86e4a13d52', 'web_revision': '537743d9aaa34dee14b3fa8ad01ead86e4a13d52'},
}
for app, keys in want.items():
    m = re.search(rf'(?ms)^  {app}:\n(?:(?!^  \S).*\n?)*', s); assert m, app
    block = new = m.group(0)
    for k, v in keys.items():
        new, n = re.subn(rf'(?m)^(    {k}: )\w+', rf'\g<1>{v}', new); assert n == 1, (app, k)
    s = s.replace(block, new, 1)
p.write_text(s)
PY
git diff --stat; git diff infrastructure/applications/sources.yaml | grep '^[-+] '
```

要看到：只动这一份文件、十行；两个 `admin_*` 不变。

## 三、构建、暂存、计划（两个应用挨个来）

```bash
for o in app-platform/knowlab-app app-platform/knowbench-app; do
  echo "===== build $o"; make -C infrastructure platform-build OBJECT=$o 2>&1 | tail -n 12; rc=${PIPESTATUS[0]}; echo "exit=$rc"; [ "$rc" = 0 ] || break
done
for f in $(git diff --name-only gitops | grep image.lock); do echo "$f: $(grep -E '^source_revision' $f)"; done
for o in app-platform/knowlab-app app-platform/knowbench-app; do
  echo "===== stage $o"; make -C infrastructure platform-stage OBJECT=$o; rc=$?; echo "exit=$rc"; [ "$rc" = 0 ] || break
done
grep -rn "BEGIN PRIVATE KEY\|BEGIN PUBLIC KEY" gitops/ | head -3; echo key-check-done
git status --short gitops | awk '{print $2}' | sed -E 's#^gitops/(components/[^/]+/[^/]+(/[^/]+)?|clusters/kind)/.*#\1#' | sort | uniq -c
for a in knowlab knowbench; do make -C infrastructure application-deployment-plan APP=$a 2>&1 | grep -E "schema|revision|ok=|failed=" | tail -4; echo "plan $a exit=${PIPESTATUS[0]}"; done
```

要看到：两个构建、两个暂存都是 0；变了的镜像锁 4 个（两个应用的后端、网页），`source_revision` 等于上面的钉；`key-check-done` 前没有文件名；计划核到 knowlab `20261016_0006`、knowbench `20261017_0020`（迁移头不变）。迁移 Job 名里带后端镜像摘要，换镜像就换名，不撞不可变 Job。

## 四、提交、发布、晋级、检查

```bash
git add infrastructure/applications/sources.yaml gitops && git -c core.editor=true commit -m "deploy: 0030 计算工具与数值验收、0031 成稿导出、分栏可拖、提示语（qwen-005）"
make -C infrastructure flux-release; echo "release exit=$?"
sudo cat infrastructure/.build/flux/source-candidate.yaml | sudo tee infrastructure/environments/kind/flux-source.yaml >/dev/null
sudo chown "$(id -u):$(id -g)" infrastructure/environments/kind/flux-source.yaml 2>/dev/null
git add infrastructure/environments/kind/flux-source.yaml && git -c core.editor=true commit -m "release(kind): 晋级到 $(git rev-parse --short HEAD)（qwen-005）"
make -C infrastructure flux-source-apply; echo "apply exit=$?"
export KUBECONFIG=~/.kube/sunmoon-kind.config; K=$(command -v kubectl || echo infrastructure/.tools/bin/kubectl)
$K -n flux-system get kustomizations -o name | grep -E '/know(lab|bench)-' | xargs $K -n flux-system wait --for=condition=Ready --timeout=30m; echo "wait exit=$?"
for a in knowlab knowbench; do make -C infrastructure application-check APP=$a; echo "check $a exit=$?"; done
git push origin qwen
```

要看到：各步都是 0。

## 五、浏览器走查（所有者操作，Qwen 核截图；截图不截 `code=`、`state=`）

| 地址 | 做什么 | 要看到 |
| --- | --- | --- |
| knowlab web端「我的数据」 | 打开 | 多了一段「数字类尽量传表格」的提示 |
| knowlab web端 新建分身 | 看验收用例那一栏 | 写着期望值只能由你自己填 |
| knowbench 工作台 | 拖左侧导航与右栏的分割线；双击复原；点左侧导航的折叠钮再展开；刷新页面 | 宽度跟着变、刷新后还在；折叠状态记住 |
| knowbench 工作台 | 在结果栏或底稿里打开一份 `.md` 成稿，点「下载 Word」「下载 Excel」「导出 PDF」 | Word 有标题与表格；Excel 每张表一张工作表、数是数字；PDF 打印框里只有成稿 |
| 计算工具（用 R5.4 的测试账号与 `r54-walk`） | knowlab 管理端照 R5.4 第 5 步建第 2 版草稿，这次贴 `docs/rename-tools/r54-walk/manifest-compute.json`（替换 `data_bindings` 占位），发起测试 | 测试通过；在 knowbench 测试账号那边打开这次委托，交回物里有 `raw` 的格子地址与 `growth` 的编号，同比约 0.1111 |

## 回执

`k8s/scripts/results/qwen-005.<时间>.md`（各步 `exit`、镜像锁四行、计划的迁移头、走查截图描述、测试结果），提交推送后停下等 Opus 审。
