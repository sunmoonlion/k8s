# Qwen 发布卡 qwen-017：knowlab 后端——测试通过不再随刷新自动交付（暂停前收口，只发后端）

> 状态：**可执行**（Opus 2026-10-20 写；所有者「好像一切正常你可以为让fable接手做准备了」；qwen-012 已结，回执免）。**等所有者在工作台那次请专家跑完（交回那一行出来）再开始**：发 knowlab 后端会重启 knowlab-api，请来的专家读数据要经过它。和 Fable 的 B（宿主 Jenkins）并行，不互相等。
> 为什么现在发：线上 knowlab 后端 `7c9731cd…` 还是「刷新结果时通过就自动交 knowmart」（分身 1.3 就是这样被交出去的，待办账 146）；接下来暂停几周、Fable 做平台线，这期间谁点一下「刷新结果」，通过的就又被交出去。

```text
被测仓：k8s，qwen 工作树 ~/worktrees/qwen/k8s，分支 qwen
一段发布：knowlab，父仓、后端，3 行钉；一个镜像（后端）；没有新迁移（迁移头仍是 20261019_0010，config 不用改）
网页、管理端的钉不动（仍是线上 6da5cef5…、d46b6bd5…）：两个前端的仓里撤掉了被否决的选择框，代码与线上一字不差，不重建
停下的规则：任何一步 exit 不是 0 就停，输出原样进回执，不重试、不退回；带管道的命令包进 bash <<'SH' … SH 里跑
不碰：knowbench、knowmart、测试电脑、沙箱；不写库；受 flux 管的部署不用 rollout restart
做完：在 k8s 本地提交后停下（不推；推回是所有者的 human-remote.sh），等 Opus 审
```

## 这一轮上什么

| 改了什么 | 为什么 | 出处 |
| --- | --- | --- |
| 「刷新结果」只记测试结论，**不再顺带交 knowmart** | 交付由用户定、上架前两道门（用户同意门、运营审核门）；两道门的页面随栏目改版第一期做，现在先保证谁都交不出去 | 决定记录「交付由用户定」与栏目方案那一条；knowlab 后端 `b7b7edb` |
| 管理端「交付 / 重试交付」：用户没要的回 409 `not_accepted` | 同上；暂停期间 web端没有「要这一版」的按钮，所以谁都交不出去，这正是想要的 | 同上 |
| 分身的返回里**不带** `accepted_at` | 线上两端按严格形状校验，多一个字段整页「读取失败」；形状与线上 `7c9731cd…` 完全一样（多了一个前端不调用的 `POST /web/v1/knowbot-drafts/{id}/accept`） | 待办账 144；knowlab 后端 `e3287024…` |

knowlab 后端全量（真库）555 过、8 跳过，pyright 0 错。

## 一、核对（只读）

```bash
cd ~/worktrees/qwen/k8s && git log --oneline -1 && git status --short | head -3
git -C ~/worktrees/qwen/knowlab-app fetch -q origin && git -C ~/worktrees/qwen/knowlab-app pull -q --ff-only origin qwen && git -C ~/worktrees/qwen/knowlab-app submodule update --init -q
echo "== knowlab-app $(git -C ~/worktrees/qwen/knowlab-app rev-parse HEAD)"; git -C ~/worktrees/qwen/knowlab-app submodule status
for d in knowlab-web-frontend:6da5cef54da34d616146530a09cbf8ae73c21acd knowlab-admin-frontend:d46b6bd5ad03c3675f165f573713c82e4cafb5bf; do r=${d%%:*}; live=${d##*:}; echo "$r 与线上差异: [$(git -C ~/worktrees/qwen/knowlab-app/$r diff $live HEAD --stat | tail -1)]"; done
grep -n "expected_schema_revision" gitops/components/app-platform/knowlab-app/knowlab-backend/config.yaml
make -C infrastructure platform-status; echo "status exit=$?"
```

要看到：knowlab 父仓 `43cd00fc7c930419474a86cee0317dfe54dad2f4`；子仓 后端 `e3287024050aef46b6d6954e5e8ab6f59294eaad`、网页 `d7589583436d7d42d90e390f91508acb6ed76a39`、管理端 `2d5c1124c0b3f76ec0efda2371fadbd5f13787b0`；两个前端「与线上差异」都是空的 `[]`；config 是 `'20261019_0010'`；`status exit=0`。

## 二、部署前看一眼（只读）

用 qwen-015 回执里只读查 knowlab 库的同一种方式（data-platform-dev/postgresql-0，库 knowlab）跑：

```sql
select id, status, run_id, updated_at from knowbot_draft where status = 'testing';
```

要看到 **0 行**（没有在测的分身）。有任何一行就停，贴给所有者定。另确认工作台里那次请专家已交回（所有者说一声）。

## 三、knowlab 后端

### 3.1 改钉（3 行）

```bash
python3 - <<'PY'
import re, pathlib
p = pathlib.Path('infrastructure/applications/sources.yaml'); s = p.read_text()
want = {
  'knowlab': {'parent_revision': '43cd00fc7c930419474a86cee0317dfe54dad2f4',
      'backend_parent_revision': 'e3287024050aef46b6d6954e5e8ab6f59294eaad', 'backend_revision': 'e3287024050aef46b6d6954e5e8ab6f59294eaad'},
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

要看到：`pin exit=0`；只动 `sources.yaml`；最后一行是 `3`；`web_*`、`admin_*` 四行没动。（Opus 已在 sources.yaml 的副本上空跑过：3 行。）

### 3.2 构建、暂存、计划

照 qwen-014 一段的 2.2（日志名换成 `q017-*-knowlab`）。要看到：构建、暂存、计划都是 0；变了的镜像锁 **只有 1 个**（knowlab 后端 `e3287024…`）——网页或管理端的锁也变了就停；`key-check-done` 前没有文件名；暂存产物只有 knowlab 后端；后端运行时 diff 除镜像与摘要外只有 `DEPLOYMENT_ID`；迁移 workload 里 `EXPECTED_SCHEMA_REVISION` **仍是** `20261019_0010`（只变 Job 名与 `DEPLOYMENT_ID`）；计划核到 `20261019_0010`。别的应用有变化就停。

### 3.3 提交、发布、晋级、检查

照 qwen-016 二段的 3.3（即 qwen-014 一段的 2.3），提交说明换成 `deploy(knowlab): 测试通过不再随刷新自动交付（qwen-017）`、`release(kind): 晋级到 …（qwen-017）`。要看到：各步都是 0；新的迁移 Job 按 Job 名直查 `Complete`（没有新迁移，Job 照样跑一次、什么都不改）；`application-check` 过、`admin_list_read: true`；`knowlab-api / worker / scheduler` 三个 deploy 镜像摘要与后端 `image.lock` 一致；`knowlab-web`、`knowlab-admin` 的镜像摘要**没变**。

## 四、上线后核

| # | 谁 | 做什么 | 要看到 |
| --- | --- | --- | --- |
| 1 | Qwen | `$K -n app-platform-dev logs deploy/knowlab-api --since=10m \| grep -E "Traceback\|ERROR"` | 没有命中 |
| 2 | 所有者 | knowlab 管理端 `https://knowlab-admin.sunmoonai.com:30443/zh-CN/avatars`，用 admin 登录，硬刷新，点分身 1.3 | 页面正常，**不出现「读取失败」**；分身 1.3 仍写「已交付 knowmart，专家编号 084acc72…」 |
| 3 | 所有者 | knowlab web端 `https://knowlab.sunmoonai.com:30443/zh-CN/avatars`，用 sig-am 登录 | 页面正常，不出现「读取失败」；看得到分身 1.3 |
| 4 | 所有者 | knowlab 管理端「专家」`https://knowlab-admin.sunmoonai.com:30443/zh-CN/experts` | 「财务分析与预测」第 1 版仍在 |

不做的：不去点「刷新结果」「交付」来试——现在没有通过而未交付的分身，点了也看不出什么；新行为由后端测试保证（刷新不交付、没要的交付回 409）。

## 回执

`scripts/results/qwen-017.<时间>.md`：第一节输出原文；第二节查询结果；3.1–3.3 各步 `exit`、镜像锁、运行时与迁移 diff、迁移 Job、`application-check`、各 deploy 镜像摘要；第四节各行（所有者看的写一句结果，不截图）。在 k8s 本地提交后停下（不推），等 Opus 审。
