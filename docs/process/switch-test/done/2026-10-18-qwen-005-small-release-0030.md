# Qwen 发布卡 qwen-005：0030 计算工具与数值验收 + 成稿导出 + 分栏可拖 + 受理关口 + 提示语（小发布）

> 状态：**已完成**（回执 `scripts/results/qwen-005.20261018-1106.md`；走查第 10 行转 qwen-006 重测）。原状态：可执行。所有者 2026-10-18 定提前到 0028 R5.4 第 5 步 c 之前做（「就这样」）：R5.4 走查 c 卡在 knowlab 管理端读不出列表（账 134），修复在本卡的 knowlab 后端里；本卡做完回到 R5.4 第 5 步从 c 接着走，R6 在那之后。Opus 2026-10-17 写，10-18 改钉。
> 依据：0030（C3：随 R5 之后的下一次发布上线）、0031（成稿导出）、待办账 121（Windows 工作说明）、124（分栏）、130（受理关口）、134（管理端认管理角色）、K17、K18；所有者 2026-10-17「把能做的先做」，受理关口「这个很重要。演示时已经出过这个洋相了」。

```text
被测仓：k8s，qwen 工作树 ~/worktrees/qwen/k8s，分支 qwen
改钉两个应用：knowlab（父仓、后端、网页）、knowbench（父仓、后端、网页）；两个管理端不动
没有新迁移、没有配置改动（Opus 核过：两边 alembic 与 core/config.py 都没变）；compute 与按格子读走现有的 knowlab:read 关系与 knowlab 内部入口（路径前缀 /api/internal/v1/knowlab 已涵盖）
停下的规则：任何一步 exit 不是 0 就停，输出原样进回执，不重试、不退回
```

## 这一轮上什么

| 应用 | 提交 | 内容 |
| --- | --- | --- |
| knowlab 后端 | `4e39358`（含 `c979112`） | 契约 `knowbot-data/v1` 加 `table`、`cells`：CSV、Excel 按格子读，数一律十进制字符串（0030 C1）；管理端业务接口认管理角色 admin、operator（账 134，同步自 tpl `45f4da9`） |
| knowlab 网页 | `0151475`（含 `0da34a3`） | 「我的数据」提示数字类尽量传表格（K17）；验收用例写明期望值只能由用户填（K18）；页头显示登录的是谁（同步自 tpl `aa93036`） |
| knowbench 后端 | `7f5aa4e`（含 `2e861ce`、`5f8e39e`、`b227b9c`、`b2b9dc9`、`ba92ce6`） | 分身的 `compute`、`read_my_table`、计算记录、数值验收 `computed`/`identity`/`sourced`（0030 C1）；重做提示带上没过的各条；Windows 上写文件、跑脚本的说明（待办 121）；受理关口：问了不归这位专家的问题，停下问「照做 / 不做了」，不硬做、不报错（待办 130）；管理端认管理角色（账 134） |
| knowbench 网页 | `13f15c3`（含 `4acd320`、`37ada6a`、`537743d`、`e90ad98`） | 成稿导出 Word、Excel、PDF（0031）；左右分栏可拖、左侧导航可折叠、输入框长高上限放宽（待办 124）；审查面的问题保留换行（待办 130）；侧栏底部显示登录的是谁 |
| knowlab 父仓 | `65860ae` | 契约 schema 四份新增、子仓指针 |
| knowbench 父仓 | `f661434` | 契约锁、子仓指针 |
| k8s | `check-browser.py` | application-check 用 admin 读一张管理端列表（knowlab 分身草稿、knowbench 缺数据），读得出才算过（账 134） |

Opus 在远程机核过：knowlab 后端全量 401 过；knowbench 后端全量（真库，含投递库与契约锁）1212 过、5 跳过（消息队列探针与跨仓向量，本来就不跑；含受理关口 8 条），加管理角色后不连库的全量 918 过；knowbench 网页 `pnpm check` 全过（296 条测试）；knowlab 网页 `pnpm check` 全过（94 条测试）。

## 一、核对（只读）

```bash
cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen && git log --oneline -1 && git status --short | head -3
for r in knowlab-app knowbench-app; do git -C ~/worktrees/qwen/$r fetch -q origin && git -C ~/worktrees/qwen/$r checkout -q qwen && git -C ~/worktrees/qwen/$r pull -q --ff-only origin qwen && git -C ~/worktrees/qwen/$r submodule update --init -q; done
git -C ~/worktrees/qwen/knowlab-app rev-parse HEAD; git -C ~/worktrees/qwen/knowlab-app submodule status
git -C ~/worktrees/qwen/knowbench-app rev-parse HEAD; git -C ~/worktrees/qwen/knowbench-app submodule status
make -C infrastructure platform-status; echo "status exit=$?"
```

要看到：knowlab 父仓 `65860ae8…`、后端 `4e39358a…`、网页 `01514759…`、管理端 `371abcee…`；knowbench 父仓 `f6614342…`、后端 `7f5aa4e4…`、网页 `13f15c3d…`、管理端 `45fcf79a…`（不是就停，请所有者同步 qwen）；`status exit=0`。

## 二、改钉（只动这两个应用的父仓、后端、网页，共十行）

```bash
python3 - <<'PY'
import re, pathlib
p = pathlib.Path('infrastructure/applications/sources.yaml'); s = p.read_text()
want = {
  'knowlab': {'parent_revision': '65860ae8d84af36f638aa548a568796b90f6c0ae',
              'backend_parent_revision': '4e39358a0e5f8fb346cb3370c6e409f6f5e7b2f4', 'backend_revision': '4e39358a0e5f8fb346cb3370c6e409f6f5e7b2f4',
              'web_parent_revision': '01514759355d2a6b7ae22ddcd910987753df9325', 'web_revision': '01514759355d2a6b7ae22ddcd910987753df9325'},
  'knowbench': {'parent_revision': 'f6614342b1250347d2549a3f311963da8a516cab',
                'backend_parent_revision': '7f5aa4e4e653848d396d4a2779384f87dc2eee93', 'backend_revision': '7f5aa4e4e653848d396d4a2779384f87dc2eee93',
                'web_parent_revision': '13f15c3d01548ebb9a307a06807b3b9578cd1702', 'web_revision': '13f15c3d01548ebb9a307a06807b3b9578cd1702'},
}
for app, keys in want.items():
    m = re.search(rf'(?m)^  {app}:\n(?:^    .*\n)*', s); assert m, app
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

要看到：两个构建、两个暂存都是 0；变了的镜像锁 4 个（两个应用的后端、网页），`source_revision` 等于上面的钉；`key-check-done` 前没有文件名；`test-computer/workload.yaml` 不该再变（脚本摘要注解 R5.4 已经带上；变了就停）；计划核到 knowlab `20261016_0006`、knowbench `20261017_0020`（迁移头不变）。迁移 Job 名里带后端镜像摘要，换镜像就换名，不撞不可变 Job。

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

要看到：各步都是 0；两个 `application-check` 的输出里，admin 那一面 `admin_list_read: True`（admin 读得出管理端列表）。

## 五、浏览器走查（所有者操作，Qwen 核截图；截图不截 `code=`、`state=`）

| 地址 | 做什么 | 要看到 |
| --- | --- | --- |
| knowlab 管理端「分身草稿」（admin） | 打开 | 两个列表读得出来（R5.4 时是「读取失败」）；R5.4 走查 b 提交的「走查用：读我的表回答营收」在「用户的提交」里 |
| knowlab web端「我的数据」 | 打开 | 多了一段「数字类尽量传表格」的提示 |
| knowlab web端 新建分身 | 看验收用例那一栏 | 写着期望值只能由你自己填 |
| knowlab web端 各页 | 看页头右边 | 「退出登录」左边写着「当前用户：你的显示名」，停上去看到邮箱；新建分身那页也有 |
| knowbench 工作台 | 看侧栏底部；把侧栏折叠起来 | 「退出登录」上面写着「当前用户：你的显示名」，鼠标停上去看到邮箱；折叠后底下是一个头像字，停上去看到全名 |
| knowbench 工作台 | 拖左侧导航与右栏的分割线；双击复原；点左侧导航的折叠钮再展开；刷新页面 | 宽度跟着变、刷新后还在；折叠状态记住 |
| knowbench 工作台 | 在结果栏或底稿里打开一份 `.md` 成稿，点「下载 Word」「下载 Excel」「导出 PDF」 | Word 有标题与表格；Excel 每张表一张工作表、数是数字；PDF 打印框里只有成稿 |
| knowbench 工作台（受理关口） | 请「财务分析与预测」，问一个无关的问题，例如「今天北京天气怎么样」 | 不报错；停下来说这个问题看起来不归这位专家、为什么、建议去哪问，两个按钮「照做」「不做了」；点「不做了」，委托显示「已取消」，说明是「专家看这个问题不归它，你选择了不做」 |
| knowbench 工作台（受理关口） | 再请一次，问它本来做的事，例如「近两年按月收入怎么走，预测下两个季度」 | 照常往下做，不停下来问归不归 |
| 计算工具（用 R5.4 的测试账号与 `r54-walk`） | knowlab 管理端照 R5.4 第 5 步建第 2 版草稿，这次贴 `docs/process/rename-2026-10-15/tools/r54-walk/manifest-compute.json`（替换 `data_bindings` 占位），发起测试 | 测试通过；在 knowbench 测试账号那边打开这次委托，交回物里有 `raw` 的格子地址与 `growth` 的编号，同比约 0.1111 |

## 回执

`k8s/scripts/results/qwen-005.<时间>.md`（各步 `exit`、镜像锁四行、计划的迁移头、走查截图描述、测试结果），提交推送后停下等 Opus 审。
