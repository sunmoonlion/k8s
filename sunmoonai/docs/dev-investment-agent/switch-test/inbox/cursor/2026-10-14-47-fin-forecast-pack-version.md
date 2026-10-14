# Cursor 发布卡：新委托绑现在上架的专家版本 + 打回时说出为什么（卡 45 上线后第一单被打回的修复）

```text
被测仓：k8s，**qwen 工作树 `~/worktrees/qwen/k8s`，分支 qwen**（财务分析与预测的活都在 qwen 工位，含发布）
跑：按编号步骤做（核对 → 改钉 → 构建 → 暂存与计划 → 提交 → 发布晋级 → 检查 → 回传）
仓与提交：投资父仓 cf7dfaaa5a4d4967dbef36c4b7536e98ee18f32e；后端 e937bbaafe3320a3e7d6f5b36aa345df15c4036b；网页 6321e7c80a51f62ca8eca74aef79a95d48a91eb9；管理端不动；知识服务不动
预计：30–45 分钟；后端与网页两个镜像；一次现网变更；没有新迁移，config 不动；API 中断约 1 分钟
看什么：后端与网页两个 image.lock 变（source_revision = e937bbaa… / 6321e7c8…）、计划核到 '20261012_0018'、迁移 Job 名结尾仍 -v7、application-check 0
前提：所有者已通知执行；页面上没有还在跑的专家委托；
      已跑过 WS=qwen 的同步，~/worktrees/qwen/k8s 在 qwen 且干净、含本卡；platform-status 0；Harbor 在；不碰旧 kind；不退回
回传：k8s/sunmoonai/scripts/results/fin-forecast-pack-version-cursor.<时间>.md，最后一行 exit=<码>；本地提交，不 push
```

## 这一轮是什么

卡 45 上线后，所有者第一次请「财务分析与预测」（13:52，任务 `3dc4e13d`）就被打回：建单记的专家版本是 "1"，受理时找不到第 1 版专家包，REJECTED / `no_expert_pack`，一步没做、没写底稿。对话页交回那一行却照「没做完」说「已经写出来的底稿在右边栏」。

根子：网页和委托入口都不传版本，账房 `handover` 默认写死 "1"；卡 45 把这位专家升到第 2 版时没跟着改。

1. **后端 `e937bba`**：没点名版本就绑现在上架的那一版。专家还在、只是绑的那一版已换下时，打回原因记 `pack_version_gone`，说「这个委托是按专家的旧版建的，旧版已经换下，请重新请一次专家」，不再说成「不在专家范围」。交回事件 `wheel/return` 带 `reason_text`。
2. **网页 `6321e7c`**：打回那一行写「专家没有接这个委托，一步也没做，没有写底稿：<为什么>」，不摆「打开工作底稿」。

后端全量 1002 个通过（连真 PostgreSQL，含库测试；新增两条，旧代码下都失败）、pyright 只有原有 4 处；网页 typecheck、lint、i18n、单测 258 个通过，`next build` 通过。设计记在 `tree-build/SDD/modules/0023-fin-forecast.md` 第 5.2 节「卡 45 上线后第一单就被打回」。

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

要看到：分支是 `qwen`，工作区干净；现在钉的是父仓 `f5aaeba3…`、后端 `d177b5e9…`、网页 `e6963ddc…`（卡 45 上线的那一版）；config 是 `v7` / `'20261012_0018'`；三个 `rev-parse` 是 `cf7dfaaa…`、`e937bbaa…`、`6321e7c8…`，**或者**是卡 48 那一版 `dad00410…`、`260c3d90…`、`9337a290…`（qwen 已往前走，2026-10-14 15:51 第一次执行就停在这里）——是后者就做下面「一之二」；两者都不是就停；`platform-status` 0。

## 一之二、把投资三仓临时检出到本卡的三钉（只在 HEAD 是卡 48 那一版时做）

构建要求源码目录的 HEAD **恰好**是钉的提交（`infrastructure/applications/build.yaml`「Refuse unreviewed source revisions」），而卡 48 那一版的网页要等代理 0.4.1 才能用，不能直接发。所以本卡期间把三仓临时检出到本卡的提交，第五步再切回 `qwen`。**这期间别人不要动 `~/worktrees/qwen/investment-app`。**

```bash
cd ~/worktrees/qwen/investment-app
git status --porcelain --ignore-submodules=none | wc -l          # 必须 0
for s in investment-backend investment-web-frontend investment-admin-frontend; do echo "$s $(git -C $s branch --show-current) $(git -C $s status --porcelain --untracked-files=all | wc -l)"; done   # 都应是 qwen 0
git merge-base --is-ancestor cf7dfaaa5a4d4967dbef36c4b7536e98ee18f32e HEAD && echo ancestor-ok
git checkout --detach cf7dfaaa5a4d4967dbef36c4b7536e98ee18f32e && git submodule update --checkout
git rev-parse HEAD; git -C investment-backend rev-parse HEAD; git -C investment-web-frontend rev-parse HEAD
```

要看到：`ancestor-ok`；三个 `rev-parse` = `cf7dfaaa…`、`e937bbaa…`、`6321e7c8…`；管理端子仓仍是 `b0f4c5de…`（gitlink 没变）。远程 2026-10-14 已在自己那份 qwen 工位上实跑过这一步和第五步，可逆、不留改动。

## 二、改钉（只动父仓、后端、网页五行）

```bash
python3 - <<'PY2'
import re,pathlib
p=pathlib.Path('infrastructure/applications/sources.yaml'); s=p.read_text()
m=re.search(r'(?ms)^  investment:\n(?:(?!^  \S).*\n?)*', s); assert m
block=m.group(0); new=block
new=re.sub(r'(?m)^(    parent_revision: )\w+', r'\g<1>cf7dfaaa5a4d4967dbef36c4b7536e98ee18f32e', new, count=1)
new=re.sub(r'(?m)^(    backend_parent_revision: )\w+', r'\g<1>e937bbaafe3320a3e7d6f5b36aa345df15c4036b', new)
new=re.sub(r'(?m)^(    backend_revision: )\w+', r'\g<1>e937bbaafe3320a3e7d6f5b36aa345df15c4036b', new)
new=re.sub(r'(?m)^(    web_parent_revision: )\w+', r'\g<1>6321e7c80a51f62ca8eca74aef79a95d48a91eb9', new)
new=re.sub(r'(?m)^(    web_revision: )\w+', r'\g<1>6321e7c80a51f62ca8eca74aef79a95d48a91eb9', new)
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

要看到：后端与网页两个 `image.lock.yaml` 变（`source_revision` 分别 = `e937bbaa…`、`6321e7c8…`）；管理端锁不变；没有 PEM；迁移 Job 名里镜像摘要那一段随后端镜像变、结尾仍是 `-v7`（没有新迁移）；计划核到 `20261012_0018`。

## 四、提交、发布、晋级、检查

```bash
git add infrastructure/applications/sources.yaml gitops/components/app-platform/investment-app
git -c core.editor=true commit -m "deploy(investment): 新委托绑现在上架的专家版本，打回时说出为什么（待办 47）"
make -C infrastructure flux-release; echo "exit=$?"
sudo cat infrastructure/.build/flux/source-candidate.yaml; git rev-parse HEAD
sudo cat infrastructure/.build/flux/source-candidate.yaml | sudo tee infrastructure/environments/kind/flux-source.yaml >/dev/null
sudo chown "$(id -u):$(id -g)" infrastructure/environments/kind/flux-source.yaml 2>/dev/null; git diff infrastructure/environments/kind/flux-source.yaml
git add infrastructure/environments/kind/flux-source.yaml && git -c core.editor=true commit -m "release(kind): 晋级到 $(git rev-parse --short HEAD)（待办 47）"
make -C infrastructure flux-source-apply; echo "exit=$?"
make -C infrastructure flux-source-status; echo "exit=$?"
make -C infrastructure application-check APP=investment; echo "exit=$?"
export KUBECONFIG=~/.kube/sunmoon-kind.config; K=$(command -v kubectl || echo infrastructure/.tools/bin/kubectl)
$K -n app-platform-dev get pods | grep -E "investment-(backend|migrate|web)" | head -14
```

要看到：候选 `revision` = 提交后 HEAD；三次退出 0；后端各角色 Pod 与网页 Pod 换新、迁移 Job 完成。

## 五、把投资三仓切回 qwen（做过「一之二」才做；成功、失败都要做）

```bash
cd ~/worktrees/qwen/investment-app
git checkout qwen && for s in investment-backend investment-web-frontend investment-admin-frontend; do git -C $s checkout qwen; done
git branch --show-current; git rev-parse --short HEAD; git submodule status
for s in investment-backend investment-web-frontend investment-admin-frontend; do echo "$s $(git -C $s branch --show-current)"; done
git status --porcelain --ignore-submodules=none | wc -l
```

要看到：父仓在 `qwen`、`dad0041`；`submodule status` 三行行首没有 `+`、`-`（后端 `260c3d9…`、网页 `9337a29…`、管理端 `b0f4c5d…`）；三个子仓都在 `qwen`；最后一行 0。

## 验收

- 钉 = 父仓 `cf7dfaaa…`、后端 `e937bbaa…`、网页 `6321e7c8…`；管理端不变；`application-check` 0。
- **真人验收由所有者做，不在本卡**：刷新页面，新开一段对话，按卡 45 的七条再试。第 1 条「预测这个公司下个季度的表现」这回要真开工：专家页能看到第一步「定范围」在做，不会马上打回。

## 失败回退与交回

任一步失败停在原步，保留错误输出与候选，**然后照样做第五步把投资三仓切回 qwen**。需恢复时把 `sources.yaml` 五行改回 `f5aaeba3…` / `d177b5e9…` / `e6963ddc…`，重走构建到晋级。报告写 `k8s/sunmoonai/scripts/results/fin-forecast-pack-version-cursor.<时间>.md`，最后一行 `exit=<码>`；本地提交，不 push、不移动本待办。
