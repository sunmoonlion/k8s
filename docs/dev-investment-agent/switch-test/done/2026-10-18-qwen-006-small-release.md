# Qwen 发布卡 qwen-006：专家目录 + runner 读用户数据 + 测试隔离 + 一批修复（小发布）

> 状态：**已完成**（回执 `scripts/results/qwen-006.20261018-1459.md`、`qwen-006.20261018-1845.md`：第四节全过，走查 7 过；第 8 行是卡写错了——未通过的草稿按设计不在原地重测——与第 9、10 行没走完的一半挪进 qwen-007）。原状态：可执行。Opus 2026-10-18 写，所有者「好的」。qwen-005 已通过（回执 `scripts/results/qwen-005.20261018-1106.md`），本卡接着上它走查第 10 行没过的修复，以及之后攒下的改动。
> 依据：SDD 0032（knowmart 专家目录）、待办账 129（测试隔离）、130（受理关口）、131（北京时间）、133（配对确认页）、134（管理端认角色）；qwen-005 走查第 10 行（runner 读不了 knowlab）与 6.2（交回行指向空的底稿）。

```text
被测仓：k8s，qwen 工作树 ~/worktrees/qwen/k8s，分支 qwen
改钉三个应用：knowbench（父仓、后端、网页、管理端）、knowlab（父仓、网页、管理端；后端不变）、knowmart（父仓、后端、网页、管理端）
迁移：只有 knowmart 新增一条（20261018_0005，专家目录）；knowbench、knowlab 迁移头不变
配置：knowbench 的「读 knowlab」服务身份加给 runner；knowmart 可以带人去工作台（跨应用目标）
停下的规则：任何一步 exit 不是 0 就停，输出原样进回执，不重试、不退回
```

## 这一轮上什么

| 应用 | 提交 | 内容 |
| --- | --- | --- |
| knowbench 后端 | `f9129c8`（含 `e18a8a3`、`edb5669`、`43db3a6`、`8526613`） | 分身测试同时只跑一个、按时间隔离（每次测试独立目录 `runs/…`，开跑前清掉别的、测完即删）、测试电脑不在线不开跑；测试报告写明「专家认为问题不归它」；「专家交回」事件带 `writes_files` |
| knowbench 网页 | `59e1956`（含 `0e7cb97`、`be9fd8d`、`332b5cf`、`73487f6`、`ca7c043` 与北京时间） | 配对确认页写明连到哪个账号；右栏收起后能点开（面板图标）；交回行对不写文件的专家不提底稿；主页「请哪一位」旁边加「请我的分身」；侧栏电脑名后写「在线 / 离线」，电脑配在别的账号上时不再说「就是这台」；北京时间 |
| knowbench 管理端 | `2696455` | 北京时间 |
| knowlab 网页 | `699ddb7` | 北京时间 |
| knowlab 管理端 | `ef4fe7f` | 分身草稿没权限时说清楚；北京时间 |
| knowmart 后端 | `360effd`（含管理端认角色 `c4750ee`） | 专家目录：类目、可见范围、发布主体与资质骨架（迁移 `20261018_0005`）、目录 / 类目 / 详情三个接口；公开开关默认关 |
| knowmart 网页 | `85e7877`（含当前用户 `0239b6e` 与北京时间） | 专家目录首页（一级类目、二级类目、筛选条、已选条件、分页）与详情页；撤「我的分身」页（地址仍是 `/knowbots`） |
| knowmart 管理端 | `107fda2` | 北京时间 |
| 三个父仓 | knowbench `e154758`、knowlab `72c6247`、knowmart `b1cbe7d` | 子仓指针 |
| k8s（本卡拉到的提交里） | `f858689e` 等 | knowbench runner 拿到读 knowlab 的身份与出站放行；服务身份注册脚本连 Casdoor 失败自动重试；测试电脑兜底清理 `runs/`；knowmart 跨应用目标加 knowbench |

Opus 在远程机核过：knowbench 后端全量（真库）1226 过、网页 `pnpm check` 303 过；knowlab 管理端与网页 `pnpm check` 全过；knowmart 后端全量（真库）426 过、分层与类型检查干净，网页 `pnpm check` 95 过；改钉脚本在 `sources.yaml` 副本上实跑：正好 19 行，knowlab 后端不动。

**不在本卡里**：ELK 采集加 knowlab、knowmart（`a1ed64ad`，平台对象另卡）；knowfeed、knowbase 的同类修复（各自下次发布）。

## 一、核对（只读）

```bash
cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen && git log --oneline -1 && git status --short | head -3
for r in knowlab-app knowbench-app knowmart-app; do git -C ~/worktrees/qwen/$r fetch -q origin && git -C ~/worktrees/qwen/$r checkout -q qwen && git -C ~/worktrees/qwen/$r pull -q --ff-only origin qwen && git -C ~/worktrees/qwen/$r submodule update --init -q; done
for r in knowbench-app knowlab-app knowmart-app; do echo "== $r $(git -C ~/worktrees/qwen/$r rev-parse HEAD)"; git -C ~/worktrees/qwen/$r submodule status; done
make -C infrastructure platform-status; echo "status exit=$?"
```

要看到：

| 父仓 | 后端 | 网页 | 管理端 |
| --- | --- | --- | --- |
| knowbench `e1547582…` | `f9129c84…` | `59e1956d…` | `26964553…` |
| knowlab `72c62475…` | `4e39358a…` | `699ddb71…` | `ef4fe7f3…` |
| knowmart `b1cbe7d3…` | `360effd1…` | `85e7877e…` | `107fda29…` |

不是就停，请所有者同步 qwen；`status exit=0`。

## 二、改钉（三个应用，共 19 行）

```bash
python3 - <<'PY'
import re, pathlib
p = pathlib.Path('infrastructure/applications/sources.yaml'); s = p.read_text()
want = {
  'knowbench': {'parent_revision': 'e15475827519130dd3eaa9343b6ee38011aa9f83',
                'backend_parent_revision': 'f9129c84aba21fd5666379bed2342f33d9553021', 'backend_revision': 'f9129c84aba21fd5666379bed2342f33d9553021',
                'web_parent_revision': '59e1956db154b8ac29c8b95ac3d23bf2832a870e', 'web_revision': '59e1956db154b8ac29c8b95ac3d23bf2832a870e',
                'admin_parent_revision': '26964553ed9d581ac855c38edeaee8e65add792f', 'admin_revision': '26964553ed9d581ac855c38edeaee8e65add792f'},
  'knowlab': {'parent_revision': '72c6247530c40d9caf148d677e27af21d5490db3',
              'web_parent_revision': '699ddb71cfde571308e5ebde2e8e4fea886695f9', 'web_revision': '699ddb71cfde571308e5ebde2e8e4fea886695f9',
              'admin_parent_revision': 'ef4fe7f3f7e93df122bc10881e3c2a50ca4846e5', 'admin_revision': 'ef4fe7f3f7e93df122bc10881e3c2a50ca4846e5'},
  'knowmart': {'parent_revision': 'b1cbe7d3a8f9fa1d3189a328fe4cb4a4cbc426e0',
               'backend_parent_revision': '360effd1110241a1f020d968f1096b3815307f76', 'backend_revision': '360effd1110241a1f020d968f1096b3815307f76',
               'web_parent_revision': '85e7877e4e5a1d92fb632faffa0ca9a4e6e24cfb', 'web_revision': '85e7877e4e5a1d92fb632faffa0ca9a4e6e24cfb',
               'admin_parent_revision': '107fda29642e9bf7259af274fa6d6c991302bfeb', 'admin_revision': '107fda29642e9bf7259af274fa6d6c991302bfeb'},
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

要看到：`pin exit=0`；只动这一份文件；最后一行是 `19`；knowlab 的 `backend_*` 两行不在改动里。

## 三、构建、暂存、计划（三个应用挨个来）

```bash
for o in app-platform/knowbench-app app-platform/knowlab-app app-platform/knowmart-app; do
  echo "===== build $o"; make -C infrastructure platform-build OBJECT=$o 2>&1 | tail -n 12; rc=${PIPESTATUS[0]}; echo "exit=$rc"; [ "$rc" = 0 ] || break
done
for f in $(git diff --name-only gitops | grep image.lock); do echo "$f: $(grep -E '^source_revision' $f)"; done
for o in app-platform/knowbench-app app-platform/knowlab-app app-platform/knowmart-app; do
  echo "===== stage $o"; make -C infrastructure platform-stage OBJECT=$o; rc=$?; echo "exit=$rc"; [ "$rc" = 0 ] || break
done
grep -rn "BEGIN PRIVATE KEY\|BEGIN PUBLIC KEY" gitops/ | head -3; echo key-check-done
git status --short gitops | awk '{print $2}' | sed -E 's#^gitops/(components/[^/]+/[^/]+(/[^/]+)?|clusters/kind)/.*#\1#' | sort | uniq -c
git diff gitops/components/app-platform/knowbench-app/knowbench-backend/runtime/workload.yaml | grep '^[-+] ' | grep -v 'sha256\|digest\|image:' | head -20
git diff gitops/components/app-platform/knowbench-app/knowbench-backend/test-computer/workload.yaml | grep '^[-+] '
git diff gitops/components/app-platform/knowmart-app/knowmart-backend/runtime/workload.yaml | grep 'CROSS_APP_TARGETS'
for a in knowbench knowlab knowmart; do make -C infrastructure application-deployment-plan APP=$a 2>&1 | grep -E "schema|revision|ok=|failed=" | tail -4; echo "plan $a exit=${PIPESTATUS[0]}"; done
```

要看到：

- 三个构建、三个暂存都是 0；变了的镜像锁 **8 个**（knowbench 后端、网页、管理端；knowlab 网页、管理端；knowmart 后端、网页、管理端），`source_revision` 等于上面的钉；`key-check-done` 前没有文件名。
- knowbench 运行时的改动里有：runner 的 `envFrom` 多一行 `knowbench-knowlab-read-service`，出站网络策略的 `values` 多了 `knowbench-runner`；配置摘要跟着变。别的行（除镜像与摘要）有变就停。
- 测试电脑：多一行清理 `runs` 的 `find`，`sunmoonai.com/scripts` 摘要跟着变；别的行有变就停。
- knowmart 运行时：`CROSS_APP_TARGETS_JSON` 从 `{}` 变成带 `knowbench` 的地址。
- knowbench 的服务身份注册 ConfigMap（`knowbench-service-provision-…`）里的脚本变了（连 Casdoor 失败自动重试），这是预期的。
- 计划核到：knowbench `20261017_0020`、knowlab `20261016_0006`（不变），**knowmart `20261018_0005`**（新的一条）。迁移 Job 名带后端镜像摘要，换镜像就换名，不撞不可变 Job。

## 四、提交、发布、晋级、检查

```bash
git add infrastructure/applications/sources.yaml gitops && git -c core.editor=true commit -m "deploy: knowmart 专家目录、runner 读用户数据、测试隔离与一批修复（qwen-006）"
make -C infrastructure flux-release; echo "release exit=$?"
sudo cat infrastructure/.build/flux/source-candidate.yaml | sudo tee infrastructure/environments/kind/flux-source.yaml >/dev/null
sudo chown "$(id -u):$(id -g)" infrastructure/environments/kind/flux-source.yaml 2>/dev/null
git add infrastructure/environments/kind/flux-source.yaml && git -c core.editor=true commit -m "release(kind): 晋级到 $(git rev-parse --short HEAD)（qwen-006）"
make -C infrastructure flux-source-apply; echo "apply exit=$?"
export KUBECONFIG=~/.kube/sunmoon-kind.config; K=$(command -v kubectl || echo infrastructure/.tools/bin/kubectl)
$K -n flux-system get kustomizations -o name | grep -E '/know(lab|bench|mart)-' | xargs $K -n flux-system wait --for=condition=Ready --timeout=30m; echo "wait exit=$?"
for a in knowbench knowlab knowmart; do make -C infrastructure application-check APP=$a; echo "check $a exit=$?"; done
$K -n app-platform-dev get pod -l app.kubernetes.io/name=knowbench-test-computer
$K -n app-platform-dev logs deploy/knowbench-test-computer -c agent --tail=15 | sed -E 's/(user_code|code=)[^",&]*/\1<码>/g'
git push origin qwen
```

要看到：各步都是 0；knowbench、knowlab 的 `application-check` 输出里 admin 那一面 `admin_list_read: true`；测试电脑 `1/1 Running`，日志里**没有新的连接码**（重启后配对还在；出了连接码就停）。

## 五、浏览器走查（所有者操作，Qwen 核截图与集群侧证据；截图不截 `code=`、`state=`）

knowmart 与工作台这几行用 **zymun**（「读表报营收」在它名下）；knowlab 管理端用 **admin**。

| # | 地址（账号） | 做什么 | 要看到 |
| --- | --- | --- | --- |
| 1 | knowmart `/zh-CN/knowbots`（zymun） | 打开 | 新的专家目录：页头有「全部」「金融」；左侧「金融 → 证券 / 期货投资咨询」，后面的数等于 zymun 名下交付过的专家数；卡片「读表报营收」写着「证券 / 期货投资咨询 · 第 1 版」；页头右边「当前用户：zymun 的显示名」；卡片上有「去工作台请」 |
| 2 | 同上 | 改「更新时间」为「近 7 天」，再点「重置筛选」；点左侧「收起」再展开；刷新 | 地址栏跟着变（`?updated=7d`），已选条件出现小标签；重置后地址回到 `/zh-CN/knowbots`；收起状态刷新后还在 |
| 3 | 同上 | 点卡片名进详情 | 五个页签里没有「发布主体」；「能做什么」「需要的数据」（`ca0749ac-…`、第 1 版）「交回什么」「版本记录」都有内容；「能做什么」下面有「方法的步骤（只有你自己看得到）」 |
| 4 | 工作台主页（zymun） | 切到「专家」，点「请哪一位」旁边的「请我的分身」 | 新标签页打开 knowmart，上方写「从工作台来」，卡片上是「请这位」；点了回到工作台，「请哪一位」里能选「读表报营收」 |
| 5 | 工作台（zymun） | 用「读表报营收」问「2024 年的营业收入是多少？」 | 回答有 100 和出处；交回那一行写「这位专家不写成稿文件」，没有「打开工作底稿」 |
| 6 | 工作台（zymun） | 右栏点收起，再点顶上的展开图标（方框加竖线） | 能展开，回到收起前那一栏 |
| 7 | 工作台「设置 → 我的电脑」（zymun） | 看「最近一次联系」 | 是北京时间（和手机上的时间对得上，不再慢 8 小时） |
| 8 | knowlab 管理端「分身草稿」（admin） | 打开 qwen-005 时没过的第 2 版草稿（`35f953ca…`），重新「发起测试」，隔一两分钟「刷新结果」 | **通过**：用例 c1 满足 1/1（「取出的数与表里一致」这次能过）；同比约 0.1111 |
| 9 | Qwen 在集群侧（第 8 行跑测试时与跑完后） | `$K -n app-platform-dev exec deploy/knowbench-test-computer -c agent -- ls /workspace/runs` | 跑测试时有一个 `2026…-<测试号>` 目录（时间在前）；跑完后为空（测完即删） |
| 10 | 工作台侧栏（先 sig-am，再 zymun；本地代理现在配在 zymun 下） | 看「我的电脑与项目」 | sig-am：电脑名后写「离线」，没有「就是这台」，下面一句「你现在用的这台电脑（zymun）连在别的账号上……」；zymun：写「在线」和「就是这台」，没有那一句 |

## 回执

`scripts/results/qwen-006.<时间>.md`：各步 `exit`、镜像锁八行、三处暂存改动的原样摘录（runner、测试电脑、knowmart 跨应用目标）、三个计划的迁移头、`application-check` 的 `admin_list_read`、测试电脑日志（码抹掉）、走查每行的截图描述与第 9 行的输出。提交推送后停下等 Opus 审。

## 补：第三节续跑（Opus 2026-10-18，回执 `qwen-006.20261018-1459.md` 停在暂存 knowmart）

**原因**：卡漏了一步。knowmart 后端钉到 `360effd`，它带新迁移 `20261018_0005`，`knowmart-backend/config.yaml` 的 `expected_schema_revision` 却还是 `20261016_0004`，暂存前的断言拦下了。本提交把它改成 `20261018_0005`。迁移 Job 名带后端镜像摘要（`bind.yaml`），换镜像就换名，`migration_job_revision` 不用动。

**现场照留**：你没提交的 `sources.yaml`（19 行）与 knowbench、knowlab 的暂存产物、三个应用的镜像锁都留着，不退回、不重建。下面只补 knowmart 的暂存与计划，接着做第四、五节。

```bash
cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen && git log --oneline -1
grep -n expected_schema_revision gitops/components/app-platform/knowmart-app/knowmart-backend/config.yaml
bash <<'SH'
make -C infrastructure platform-stage OBJECT=app-platform/knowmart-app; echo "stage knowmart exit=$?"
git diff gitops/components/app-platform/knowmart-app/knowmart-backend/runtime/workload.yaml | grep 'CROSS_APP_TARGETS'
make -C infrastructure application-deployment-plan APP=knowmart > /tmp/q006-plan-knowmart.log 2>&1; echo "plan knowmart exit=$?"; grep -E "schema|revision|ok=|failed=" /tmp/q006-plan-knowmart.log | tail -4
git diff gitops/components/app-platform/knowlab-app/knowlab-backend/runtime/workload.yaml | grep '^[-+] ' | grep -v 'sha256\|digest\|image:'
git status --short gitops | awk '{print $2}' | sed -E 's#^gitops/(components/[^/]+/[^/]+(/[^/]+)?|clusters/kind)/.*#\1#' | sort | uniq -c
SH
```

要看到：

- 拉下来的提交是本卡这次补的那个；`config.yaml` 第 9 行是 `'20261018_0005'`。
- `stage knowmart exit=0`；`CROSS_APP_TARGETS_JSON` 从 `{}` 变成带 `knowbench` 的地址。
- `plan knowmart exit=0`，迁移头 `20261018_0005`。
- knowlab 运行时除镜像与摘要外只有 `DEPLOYMENT_ID` 一行变（配置摘要把出站客户的配置也算进去了，这次给它们加了 `roles` 字段，默认值不变）；knowlab 的 `knowbench-testrun-identity`、`knowmart-deliver-identity` 两处变化是共用的服务身份注册脚本加了连 Casdoor 失败自动重试，Job 跟着换名——都是预期的，你上一份回执的观察就是这个。别的行有变就停。
- knowmart 那几处也一样：运行时、迁移、出站身份（若有）跟着变。

然后照原卡第四节、第五节往下做。第四节的 `git add infrastructure/applications/sources.yaml gitops` 不用管 `config.yaml`，它已在本次提交里。zsh 没有 `PIPESTATUS`，第四节带管道的命令同样包进 `bash <<'SH' … SH` 里跑。
