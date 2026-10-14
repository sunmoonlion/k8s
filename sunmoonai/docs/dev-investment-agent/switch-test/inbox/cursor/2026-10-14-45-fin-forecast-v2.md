# Cursor 发布卡：财务分析与预测第 2 版 + 成稿步修复 + 底稿按次分开存、工作底稿栏（2026-10-14 现网问题的修复）

```text
被测仓：k8s，**qwen 工作树 `~/worktrees/qwen/k8s`，分支 qwen**（所有者 2026-10-13 定：财务分析与预测的活以后都在 qwen 工位，含发布）
跑：按编号步骤做（核对 → 改钉 → 构建 → 暂存与计划 → 提交 → 发布晋级 → 检查 → 回传）
仓与提交：投资父仓 ad7b9bcd8c6227a26c2e7863f0102560ade2d3a8；后端 61f02667060ebc93df57b49650b9d9bcc49d215c；网页 a4f53965d01649c4ec49af62c0657cb7fe806d29；管理端不动；知识服务不动
预计：30–45 分钟；后端与网页两个镜像；一次现网变更；没有新迁移，config 不动；API 中断约 1 分钟
看什么：后端与网页两个 image.lock 变（source_revision = 61f02667… / a4f53965…）、计划核到 '20261012_0018'、迁移 Job 名结尾仍 -v7、application-check 0
前提：所有者已通知执行；页面上没有还在跑的财务分析与预测任务（旧版的任务新版上线后接不上）；
      已跑过 WS=qwen 的同步，~/worktrees/qwen/k8s 在 qwen 且干净、含本卡；platform-status 0；Harbor 在；不碰旧 kind；不退回
回传：k8s/sunmoonai/scripts/results/fin-forecast-v2-cursor.<时间>.md，最后一行 exit=<码>；本地提交，不 push
```

## 这一轮是什么

10-13、10-14 所有者在本地机实跑「预测这个公司下个季度的表现」，暴露四件事，Opus 在远程修好，一张卡发：

1. **定范围误选财报**（后端 `c0f99e4`）：第 1 版挑了 600009 财报，取数按月铺开 1994–2026 年，两次撞 15 分钟单步时限。第 2 版只认按期汇总的数据（Olist 这类），财报类在定范围停下并说「财报类请用财报体检」；没点名时只剩一份符合就用它，不止一份就问；取数不细于数据存的粒度。专家版本 1 → 2。
2. **超时被报成「不是 JSON 对象」**（后端 `f89de88`）：到点停下后，工作台拿最后一句进度说明去验。现在记成「在时限内交回」不过、其余「没有验」，照常返工或交人。
3. **Windows 上写不出成稿文件**（后端 `ee5ee62`）：Codex 不给 kimi-k3 这类它不认识的模型 apply_patch 工具，只能经命令行调，而它只在整条命令恰好是 `apply_patch <<'EOF' … EOF` 时自己接住（PowerShell 也一样）。说明里把补丁格式与这条命令的样子写死，整份 Add File 写。
4. **底稿覆盖、对话页看不懂**（所有者 10-14 提，后端 `61f0266`、网页 `a4f5396`）：每次委托的底稿写进 `底稿/对话-<对话编号前 8 位>/<开始时间>-<专家名>/`（成稿与 `交回.md` 同处），不再覆盖别的对话和前几次；对话页在专家那一段照常摆过程（查数、命令、改文件、它说的话），只藏每步交回的 JSON，每步一行标题、重做不数第几次；交回那一行说结果并带「打开工作底稿」；右边栏新增「工作底稿」，列这段对话各次委托的底稿，点开经本机回环口读。

后端全量 814 过、0 失败；网页 typecheck、lint、i18n、单测 256 过、`next build` 过。设计 `tree-build/SDD/modules/0023-fin-forecast.md` 第 5.2 节末。

**停下的规则**：任何一步退出码不是 0，就停在那一步，把输出贴进回传，不做退回。

## 一、核对（只读）

```bash
cd ~/worktrees/qwen/k8s && git branch --show-current && git log --oneline -1 && git status --short | head -5
grep -n "investment:" -A7 infrastructure/applications/sources.yaml
grep -n "expected_schema_revision\|migration_job_revision" gitops/components/app-platform/investment-app/investment-backend/config.yaml
git -C ~/worktrees/qwen/investment-app rev-parse HEAD
git -C ~/worktrees/qwen/investment-app/investment-backend rev-parse HEAD
git -C ~/worktrees/qwen/investment-app/investment-web-frontend rev-parse HEAD
make -C infrastructure platform-status; echo "exit=$?"
```

要看到：`qwen`；干净；现在钉的是父仓 `93462322…`、后端 `15769d59…`、网页 `309e73d5…`（卡 44 上线的那一版）；config 是 `v7` / `'20261012_0018'`；三个 `rev-parse` 分别是 `ad7b9bcd…`、`61f02667…`、`a4f53965…`（不是就停，请所有者先同步 qwen）；`platform-status` 0。

## 二、改钉（只动父仓、后端、网页五行）

```bash
python3 - <<'PY2'
import re,pathlib
p=pathlib.Path('infrastructure/applications/sources.yaml'); s=p.read_text()
m=re.search(r'(?ms)^  investment:\n(?:(?!^  \S).*\n?)*', s); assert m
block=m.group(0); new=block
new=re.sub(r'(?m)^(    parent_revision: )\w+', r'\g<1>ad7b9bcd8c6227a26c2e7863f0102560ade2d3a8', new, count=1)
new=re.sub(r'(?m)^(    backend_parent_revision: )\w+', r'\g<1>61f02667060ebc93df57b49650b9d9bcc49d215c', new)
new=re.sub(r'(?m)^(    backend_revision: )\w+', r'\g<1>61f02667060ebc93df57b49650b9d9bcc49d215c', new)
new=re.sub(r'(?m)^(    web_parent_revision: )\w+', r'\g<1>a4f53965d01649c4ec49af62c0657cb7fe806d29', new)
new=re.sub(r'(?m)^(    web_revision: )\w+', r'\g<1>a4f53965d01649c4ec49af62c0657cb7fe806d29', new)
assert new!=block; p.write_text(s.replace(block,new,1))
PY2
git diff --stat; git diff infrastructure/applications/sources.yaml | grep "^[-+]" | grep -v "^+++\|^---"
```

要看到：只动这一份文件、五行；`admin_*` 不变。

## 三、构建、暂存、计划

```bash
make -C infrastructure platform-build OBJECT=app-platform/investment-app 2>&1 | tail -n 12; echo "exit=${PIPESTATUS[0]}"
git status --short gitops/components/app-platform/investment-app | grep image.lock
for f in $(git diff --name-only gitops/components/app-platform/investment-app | grep image.lock); do echo "$f: $(grep -E 'source_revision' $f | head -1)"; done
make -C infrastructure platform-stage OBJECT=app-platform/investment-app; echo "exit=$?"
grep -rn "BEGIN PRIVATE KEY\|BEGIN PUBLIC KEY" gitops/ | head -3   # 必须没有
git diff gitops/components/app-platform/investment-app/investment-backend/runtime/workload.yaml | grep -E '^[-+].*(investment-migrate-|image: )' | head -8
make -C infrastructure application-deployment-plan APP=investment 2>&1 | grep -E "schema|revision|ok=|failed=" | tail -4; echo "exit=${PIPESTATUS[0]}"
```

要看到：后端与网页两个 `image.lock.yaml` 变（`source_revision` 分别 = `61f02667…`、`a4f53965…`）；管理端锁不变；没有 PEM；迁移 Job 名里镜像摘要那一段随后端镜像变、结尾仍是 `-v7`（没有新迁移）；计划核到 `20261012_0018`。

## 四、提交、发布、晋级、检查

```bash
git add infrastructure/applications/sources.yaml gitops/components/app-platform/investment-app
git -c core.editor=true commit -m "deploy(investment): 财务分析与预测第 2 版、成稿步修复、底稿按次分开存与工作底稿栏（待办 45）"
make -C infrastructure flux-release; echo "exit=$?"
sudo cat infrastructure/.build/flux/source-candidate.yaml; git rev-parse HEAD
sudo cat infrastructure/.build/flux/source-candidate.yaml | sudo tee infrastructure/environments/kind/flux-source.yaml >/dev/null
sudo chown "$(id -u):$(id -g)" infrastructure/environments/kind/flux-source.yaml 2>/dev/null; git diff infrastructure/environments/kind/flux-source.yaml
git add infrastructure/environments/kind/flux-source.yaml && git -c core.editor=true commit -m "release(kind): 晋级到 $(git rev-parse --short HEAD)（待办 45）"
make -C infrastructure flux-source-apply; echo "exit=$?"
make -C infrastructure flux-source-status; echo "exit=$?"
make -C infrastructure application-check APP=investment; echo "exit=$?"
export KUBECONFIG=~/.kube/sunmoon-kind.config; K=$(command -v kubectl || echo infrastructure/.tools/bin/kubectl)
$K -n app-platform-dev get pods | grep -E "investment-(backend|migrate|web)" | head -14
```

要看到：候选 `revision` = 提交后 HEAD；三次退出 0；后端各角色 Pod 与网页 Pod 换新、迁移 Job 完成。

## 验收

- 钉 = 父仓 `ad7b9bcd…`、后端 `61f02667…`、网页 `a4f53965…`；管理端不变；`application-check` 0。
- **真人验收由所有者做，不在本卡**（新开一段对话，项目目录照旧）：
  1. 问「预测这个公司下个季度的表现」：定范围选 Olist 样例（600009 不再是候选），假设里写明「问题没点名，按唯一符合的数据集」。对话页在专家那一段看得到每一步的标题和查数、写文件的过程，看不到 JSON 原样、看不到「第 1 次 / 第 2 次」；交回那一行写「专家做完了……」并有「打开工作底稿」。
  2. 点「打开工作底稿」：右边栏列出这一次（专家名、开始时间、做完了），下面两份文件，点开能读；项目目录里多出 `底稿/对话-<8 位>/<时间>-财务分析与预测/` 一格，里面是成稿与 `交回.md`。同一段对话再请一次，多出新的一格，前一格不变。
  3. 成稿那一步看它是不是一次就用 `apply_patch <<'EOF'` 写进去（展开写文件那一行看命令）。
  4. 问「上海机场下季度营收怎么样」：在定范围停下交你，不往下取数。页面说明是两种之一，都算对：「没有找到能回答这个问题的数据集」，或「这份数据不是按期汇总的经营数据……财报类请用『财报体检』」。

## 失败回退与交回

任一步失败停在原步，保留错误输出与候选。需恢复时把 `sources.yaml` 五行改回 `93462322…` / `15769d59…` / `309e73d5…`，重走构建到晋级。报告写 `k8s/sunmoonai/scripts/results/fin-forecast-v2-cursor.<时间>.md`，最后一行 `exit=<码>`；本地提交，不 push、不移动本待办。
