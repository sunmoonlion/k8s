# Cursor 发布卡：财务分析与预测第 2 版——定范围不再误选财报数据（2026-10-14 现网事故的修复）

```text
被测仓：k8s，**qwen 工作树 `~/worktrees/qwen/k8s`，分支 qwen**（所有者 2026-10-13 定：财务分析与预测的活以后都在 qwen 工位，含发布）
跑：按编号步骤做（核对 → 改钉 → 构建 → 暂存与计划 → 提交 → 发布晋级 → 检查 → 回传）
仓与提交：投资父仓 3b1d482164f7bb3a6b6af45dd4a76e70669b0cd0；后端 c0f99e4a9f92c21cff21af9c4a407ebb85c26a01；网页 309e73d5…（不变）；管理端不动；知识服务不动
预计：20–30 分钟；只换后端一个镜像；一次现网变更；没有新迁移，config 不动；API 中断约 1 分钟
看什么：只有后端 image.lock 变（source_revision = c0f99e4a…）、计划核到 '20261012_0018'、application-check 0
前提：所有者已通知执行，且**已在页面上停掉 10-14 那个还在跑的财务分析与预测任务**（它用的是第 1 版，新版上线后接不上）；
      已跑过 WS=qwen 的同步，~/worktrees/qwen/k8s 在 qwen 且干净、含本卡；platform-status 0；Harbor 在；不碰旧 kind；不退回
回传：k8s/sunmoonai/scripts/results/fin-forecast-v2-cursor.<时间>.md，最后一行 exit=<码>；本地提交，不 push
```

## 这一轮是什么

10-14 现网：所有者问「预测这个公司下个季度的表现」。知识服务里有 Olist 样例与 600009 财报两份数据；第 1 版专家的定范围自己挑了 600009，取数按月把 1994–2026 年铺开，两次撞 15 分钟单步超时，验收不过。设计里 A 股财报是「以后再接」，第 1 版没拦住。

第 2 版（后端 `c0f99e4`，全量 809 过、0 失败）：定范围先按口径种类筛数据集，本版只认按期汇总的（Olist 这类），财报类不支持；问题没点名时只剩一份符合就用它，不止一份就问用户；新增一条确定性验收，口径种类不是按期汇总的就交人并说明「财报类请用财报体检」；取数不许拆得比数据存的粒度更细。专家版本 1 → 2。设计 `tree-build/SDD/modules/0023-fin-forecast.md` 第 5.2 节。

**停下的规则**：任何一步退出码不是 0，就停在那一步，把输出贴进回传，不做退回。

## 一、核对（只读）

```bash
cd ~/worktrees/qwen/k8s && git branch --show-current && git log --oneline -1 && git status --short | head -5
grep -n "investment:" -A7 infrastructure/applications/sources.yaml
grep -n "expected_schema_revision\|migration_job_revision" gitops/components/app-platform/investment-app/investment-backend/config.yaml
git -C ~/worktrees/qwen/investment-app rev-parse HEAD; git -C ~/worktrees/qwen/investment-app/investment-backend rev-parse HEAD
make -C infrastructure platform-status; echo "exit=$?"
```

要看到：`qwen`；干净；现在钉的是父仓 `93462322…`、后端 `15769d59…`、网页 `309e73d5…`（卡 44 上线的那一版）；config 是 `v7` / `'20261012_0018'`；两个 `rev-parse` 分别是 `3b1d4821…`、`c0f99e4a…`（不是就停，请所有者先同步 qwen）；`platform-status` 0。

## 二、改钉（只动父仓与后端三行）

```bash
python3 - <<'PY2'
import re,pathlib
p=pathlib.Path('infrastructure/applications/sources.yaml'); s=p.read_text()
m=re.search(r'(?ms)^  investment:\n(?:(?!^  \S).*\n?)*', s); assert m
block=m.group(0); new=block
new=re.sub(r'(?m)^(    parent_revision: )\w+', r'\g<1>3b1d482164f7bb3a6b6af45dd4a76e70669b0cd0', new, count=1)
new=re.sub(r'(?m)^(    backend_parent_revision: )\w+', r'\g<1>c0f99e4a9f92c21cff21af9c4a407ebb85c26a01', new)
new=re.sub(r'(?m)^(    backend_revision: )\w+', r'\g<1>c0f99e4a9f92c21cff21af9c4a407ebb85c26a01', new)
assert new!=block; p.write_text(s.replace(block,new,1))
PY2
git diff --stat; git diff infrastructure/applications/sources.yaml | grep "^[-+]" | grep -v "^+++\|^---"
```

要看到：只动这一份文件、三行；`web_*`、`admin_*` 不变。

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

要看到：**只有后端的** `image.lock.yaml` 变（`source_revision` = `c0f99e4a…`）；网页锁不变；没有 PEM；迁移 Job 名里镜像摘要那一段随后端镜像变、结尾仍是 `-v7`（没有新迁移）；计划核到 `20261012_0018`。

## 四、提交、发布、晋级、检查

```bash
git add infrastructure/applications/sources.yaml gitops/components/app-platform/investment-app
git -c core.editor=true commit -m "deploy(investment): 财务分析与预测第 2 版，定范围不误选财报数据（待办 45）"
make -C infrastructure flux-release; echo "exit=$?"
sudo cat infrastructure/.build/flux/source-candidate.yaml; git rev-parse HEAD
sudo cat infrastructure/.build/flux/source-candidate.yaml | sudo tee infrastructure/environments/kind/flux-source.yaml >/dev/null
sudo chown "$(id -u):$(id -g)" infrastructure/environments/kind/flux-source.yaml 2>/dev/null; git diff infrastructure/environments/kind/flux-source.yaml
git add infrastructure/environments/kind/flux-source.yaml && git -c core.editor=true commit -m "release(kind): 晋级到 $(git rev-parse --short HEAD)（待办 45）"
make -C infrastructure flux-source-apply; echo "exit=$?"
make -C infrastructure flux-source-status; echo "exit=$?"
make -C infrastructure application-check APP=investment; echo "exit=$?"
export KUBECONFIG=~/.kube/sunmoon-kind.config; K=$(command -v kubectl || echo infrastructure/.tools/bin/kubectl)
$K -n app-platform-dev get pods | grep -E "investment-(backend|migrate)" | head -12
```

要看到：候选 `revision` = 提交后 HEAD；三次退出 0；后端各角色 Pod 换新、迁移 Job 完成；网页 Pod 不重启。

## 验收

- 钉 = 父仓 `3b1d4821…`、后端 `c0f99e4a…`，网页不变；只换后端镜像；`application-check` 0。
- **真人验收由所有者做，不在本卡**：在一个项目里请「财务分析与预测」，问「预测这个公司下个季度的表现」——定范围应选 Olist 样例（600009 不再是候选），并在假设里写明「问题没点名，按唯一符合的数据集」；再问「上海机场下季度营收怎么样」——应在定范围停下交你，不往下取数。页面上的说明是两种之一，都算对：「没有找到能回答这个问题的数据集」（模型按方法把数据集留空），或「这份数据不是按期汇总的经营数据……财报类请用『财报体检』」（模型硬选了 600009，被新加的验收拦下）。

## 失败回退与交回

任一步失败停在原步，保留错误输出与候选。需恢复时把 `sources.yaml` 三行改回 `93462322…` / `15769d59…`，重走构建到晋级。报告写 `k8s/sunmoonai/scripts/results/fin-forecast-v2-cursor.<时间>.md`，最后一行 `exit=<码>`；本地提交，不 push、不移动本待办。
