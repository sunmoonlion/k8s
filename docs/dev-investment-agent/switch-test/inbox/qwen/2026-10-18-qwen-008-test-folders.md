# Qwen 发布卡 qwen-008：测试先不隔离、修好测试一开跑就出错；项目里的聊天与项目页加右栏（knowbench 后端、网页两个镜像）

> 状态：**可执行**（Opus 2026-10-18 写；所有者选甲）。
> 依据：qwen-007 回执 `qwen-007.20261018-2051.md` 的 F2 与 O3；待办账 129。

```text
被测仓：k8s，qwen 工作树 ~/worktrees/qwen/k8s，分支 qwen
改钉一个应用：knowbench（父仓、后端、网页，共 5 行；管理端不变）
迁移：没有新迁移（knowbench 迁移头 20261017_0020 不变）；配置不改
集群 prune: false：改名前留下的 investment-sandboxes-in 精确删除
停下的规则：任何一步 exit 不是 0 就停，输出原样进回执，不重试、不退回；带管道的命令包进 bash <<'SH' … SH 里跑
```

## 这一轮上什么

| 哪里 | 提交 | 内容 |
| --- | --- | --- |
| knowbench 后端 | `51b72eb` | **F2 的根因**：qwen-006 加的「每次测试用自己的目录」，要经服务流请测试电脑的代理建、删目录，可代理 0.5.0 的服务流只读（`sunmoon-link/agent/src/service.ts` 只认 readDirectory、getMetadata、readFile），建目录回「方法不认识」，qwen-007 又加了「被拒立刻报错」，测试一开跑就出错。Opus 实现时没核代理支持哪些方法。修法（所有者选甲）：新开关 `KNOWBOT_TEST_ISOLATE` 默认关——关着时在工作区本身里跑（qwen-005 的老办法），每条用例的结果写明「本次测试没有隔离」；测试电脑换上代理 0.5.1 再打开。测试结束时 runner 记一行 INFO（run、status、error） |
| knowbench 网页 | `4748b94` | 项目里的聊天、项目页也有右栏，只摆「文件」「终端」（聊天不改文件，0017「挂在项目下可只读看项目文件」）；窗口窄于 1024 时窄轨照留、展开后浮在上层，不再整个藏起来（所有者 2026-10-18）。终端仍是占位（账 83） |
| knowbench 父仓 | `2c504ef` | 子仓指针 |
| k8s（本卡拉到的提交里） | — | 待办账 129 记下；本卡 |

Opus 在远程机核过：knowbench 后端全量（真库）1242 过，含新加的「隔离没打开就在工作区本身里跑、结果写明没有隔离」；网页 `pnpm check` 304 过（新加：项目里的聊天有右栏、只有文件与终端，不属于项目的没有；项目页有右栏），预览里 900 像素宽截图核过浮层；改钉脚本在 qwen-007 补二的 `sources.yaml` 上实跑 5 行。

## 一、核对（只读）

```bash
cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen && git log --oneline -1 && git status --short | head -3
git -C ~/worktrees/qwen/knowbench-app fetch -q origin && git -C ~/worktrees/qwen/knowbench-app pull -q --ff-only origin qwen && git -C ~/worktrees/qwen/knowbench-app submodule update --init -q
echo "== knowbench $(git -C ~/worktrees/qwen/knowbench-app rev-parse HEAD)"; git -C ~/worktrees/qwen/knowbench-app submodule status
make -C infrastructure platform-status; echo "status exit=$?"
```

要看到：knowbench 父仓 `2c504efe…`，后端 `51b72eb5…`、网页 `4748b94e…`、管理端 `26964553…`；`status exit=0`。

## 二、改钉（5 行）

```bash
python3 - <<'PY'
import re, pathlib
p = pathlib.Path('infrastructure/applications/sources.yaml'); s = p.read_text()
want = {
  'knowbench': {'parent_revision': '2c504efe19702d8bf45550b68642c78488d82c8c',
      'backend_parent_revision': '51b72eb5f09aca2ee426fb02897d19bef73855f4', 'backend_revision': '51b72eb5f09aca2ee426fb02897d19bef73855f4',
      'web_parent_revision': '4748b94ebf589ee870ca5efa097f212a59a1d04e', 'web_revision': '4748b94ebf589ee870ca5efa097f212a59a1d04e'},
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

要看到：`pin exit=0`；只动 `sources.yaml`；最后一行是 `5`。

## 三、构建、暂存、计划

```bash
bash <<'SH'
make -C infrastructure platform-build OBJECT=app-platform/knowbench-app > /tmp/q008-build.log 2>&1; rc=$?; tail -n 8 /tmp/q008-build.log; echo "build exit=$rc"; [ "$rc" = 0 ] || exit 1
for f in $(git diff --name-only gitops | grep image.lock); do echo "$f: $(grep -E '^source_revision' $f)"; done
make -C infrastructure platform-stage OBJECT=app-platform/knowbench-app; echo "stage exit=$?"
grep -rn "BEGIN PRIVATE KEY\|BEGIN PUBLIC KEY" gitops/ | head -3; echo key-check-done
git status --short gitops | awk '{print $2}' | sed -E 's#^gitops/(components/[^/]+/[^/]+(/[^/]+)?|clusters/kind)/.*#\1#' | sort | uniq -c
git diff gitops/components/app-platform/knowbench-app/knowbench-backend/runtime/workload.yaml | grep '^[-+] ' | grep -v 'sha256\|digest\|image:'
make -C infrastructure application-deployment-plan APP=knowbench > /tmp/q008-plan.log 2>&1; echo "plan exit=$?"; grep -E "schema|revision|ok=|failed=" /tmp/q008-plan.log | tail -3
SH
```

要看到：构建、暂存、计划都是 0；变了的镜像锁**2 个**（knowbench 后端 `51b72eb5…`、网页 `4748b94e…`）；`key-check-done` 前没有文件名；运行时 diff 除镜像与摘要外只有 `DEPLOYMENT_ID` 一行；迁移头 `20261017_0020`。管理端或别的应用有变化就停。

## 四、提交、发布、晋级、检查

```bash
bash <<'SH'
git add infrastructure/applications/sources.yaml gitops && git -c core.editor=true commit -m "deploy: 测试先不隔离、修好一开跑就出错；聊天与项目页加右栏（qwen-008）"
make -C infrastructure flux-release; echo "release exit=$?"
sudo cat infrastructure/.build/flux/source-candidate.yaml | sudo tee infrastructure/environments/kind/flux-source.yaml >/dev/null
sudo chown "$(id -u):$(id -g)" infrastructure/environments/kind/flux-source.yaml 2>/dev/null
git add infrastructure/environments/kind/flux-source.yaml && git -c core.editor=true commit -m "release(kind): 晋级到 $(git rev-parse --short HEAD)（qwen-008）"
make -C infrastructure flux-source-apply; echo "apply exit=$?"
export KUBECONFIG=~/.kube/sunmoon-kind.config; K=$(command -v kubectl || echo infrastructure/.tools/bin/kubectl)
$K -n flux-system get kustomizations -o name | grep -E '/knowbench-' | xargs $K -n flux-system wait --for=condition=Ready --timeout=30m; echo "wait exit=$?"
$K -n app-platform-dev delete networkpolicy investment-sandboxes-in --ignore-not-found; echo "np delete exit=$?"
$K -n app-platform-dev get networkpolicy -o name | grep sandboxes-in
make -C infrastructure application-check APP=knowbench; echo "check exit=$?"
$K -n app-platform-dev get pod -l app.kubernetes.io/name=knowbench-test-computer
git push origin qwen
SH
```

要看到：各步都是 0；名字带 `sandboxes-in` 的只剩 `knowbench-sandboxes-in`（`investment-sandboxes-in` 是改名前留下的，部署声明里早已没有，这次精确删掉，O3）；`application-check` 过、admin 面 `admin_list_read: true`；测试电脑 `1/1 Running`。

## 五、走查（所有者操作；Qwen 核截图与集群侧证据）

| # | 地址（账号） | 做什么 | 要看到 |
| --- | --- | --- | --- |
| 1 | knowlab 管理端「专家草稿」（admin） | qwen-007 第 6 行那份草稿（修订 3，`0b562094…`）已是「未通过」，按设计不在原地重测。在它所在的想法上点「看方法并建草稿」，贴 `docs/rename-tools/r54-walk/manifest-compute.json` 全文，点「建草稿」（第 2 版、修订 4）；「已逐条核对出处」→「发起测试」，隔一两分钟「刷新结果」 | **通过**：用例 c1 满足 1/1（「取出的数与表里一致」能过，验 qwen-005 第 10 行的修复）；结果里写着「本次测试没有隔离……」 |
| 2 | Qwen 在集群侧（第 1 行跑测试时与跑完后） | `$K -n app-platform-dev logs deploy/knowbench-runner --since=30m \| grep 'knowbot test'` | 有 `knowbot test run finished run=… status=passed error=`；测试电脑上 `/workspace/runs` 不存在（这次本来就不建） |
| 3 | knowlab 管理端（admin） | 第 1 行的测试里若冒出「待回答的问题」：看那条问题 | 开步前的提问、反问写着「在用户那里，等用户回答」，有「改由我们答」和理由框 |
| 4 | 工作台某个项目页（zymun） | 看右边；点「文件」 | 右边有窄轨；展开后只有「文件」「终端」两栏，没有「改动」；文件栏里能看到这个项目的文件（电脑在线时） |
| 5 | 工作台：项目里的一段**聊天**（zymun；没有就在项目页点「新聊天」问一句） | 同上 | 有右栏，只有「文件」「终端」；不属于项目的聊天没有右栏 |
| 6 | 任一有右栏的页面（zymun） | 把浏览器窗口拉窄到不到 1024 像素宽 | 窄轨还在；点开后右栏浮在内容上面，不挤压中间 |

## 回执

`scripts/results/qwen-008.<时间>.md`：各步 `exit`、镜像锁两行、运行时那段 diff、迁移头、`sandboxes-in` 删前删后、`application-check`、走查每行的截图描述与第 2 行的日志行。提交推送后停下等 Opus 审。
