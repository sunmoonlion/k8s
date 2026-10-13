# Cursor 发布卡：investment 网页热修——CSP 放行本机代理回环口（文件树探不到的根子）

```text
被测仓：k8s，fable 工作树 `~/worktrees/fable/k8s`，分支 fable
跑：按编号步骤做（核对 → 改钉 → 构建 → 暂存与计划 → 提交 → 发布晋级应用 → 检查 → 回传）
仓与提交：投资父仓 102054b4d74fcb9d4dbd033b367caa4772564827；网页 309e73d5a810c684096f3a9f4cc72ba1b0a682fd；后端 e73ffa5e7f117627003b698b17f64e89b92b21d1（**不变**，与现网相同）；管理端不动
预计：20–30 分钟；只换网页一个镜像；一次现网变更；没有迁移，config 不动；API 不中断
看什么：只有网页 image.lock 变（锁里 source_revision = 309e73d5…）、后端锁不变、计划核到 '20261012_0018'（不变）、application-check 退出 0
前提：所有者已通知执行；~/worktrees/fable/k8s 在 fable 且干净；platform-status 0；Harbor 在；不碰旧 kind；不退回
回传：k8s/sunmoonai/scripts/results/web-hotfix-csp-cursor.<时间>.md，最后一行 exit=<码>；本地提交，不 push
```

## 这一轮是什么

卡 42 上线后所有者真机验：工作对话右边栏「文件」说「这台电脑上没有在运行的代理」，控制台里是网页自己的内容安全策略（CSP）`connect-src 'self'` 把到 `http://127.0.0.1:4781x/presence` 的请求拦了。改一行：`connect-src` 加五个回环口。网页 `309e73d5`，测试 253 过、构建过。只动网页。

**停下的规则**：任何一步退出码不是 0，就停在那一步，把输出贴进回传，不做退回。

## 一、核对（只读）

```bash
cd ~/worktrees/fable/k8s && git branch --show-current && git log --oneline -1 && git status --short | head -5
grep -n "investment:" -A6 infrastructure/applications/sources.yaml
make -C infrastructure platform-status; echo "exit=$?"
```

要看到：`fable`；干净；现在钉的是父仓 `99e92f56…`、后端 `e73ffa5e…`、网页 `27f6b9b3…`；`platform-status` 0。

## 二、改钉（只动父仓与网页三行；后端与 config 不动）

```bash
python3 - <<'PY2'
import re,pathlib
p=pathlib.Path('infrastructure/applications/sources.yaml'); s=p.read_text()
m=re.search(r'(?ms)^  investment:\n(?:(?!^  \S).*\n?)*', s); assert m
block=m.group(0); new=block
new=re.sub(r'(?m)^(    parent_revision: )\w+', r'\g<1>102054b4d74fcb9d4dbd033b367caa4772564827', new, count=1)
new=re.sub(r'(?m)^(    web_parent_revision: )\w+', r'\g<1>309e73d5a810c684096f3a9f4cc72ba1b0a682fd', new)
new=re.sub(r'(?m)^(    web_revision: )\w+', r'\g<1>309e73d5a810c684096f3a9f4cc72ba1b0a682fd', new)
assert new!=block; p.write_text(s.replace(block,new,1))
PY2
git diff --stat; git diff infrastructure/applications/sources.yaml | grep "^[-+]" | grep -v "^+++\|^---"
```

要看到：只动这一份文件、三行；`backend_*` 两行仍是 `e73ffa5e…`。

## 三、构建、暂存、计划

```bash
make -C infrastructure platform-build OBJECT=app-platform/investment-app 2>&1 | tail -n 12; echo "exit=${PIPESTATUS[0]}"
git status --short gitops/components/app-platform/investment-app | grep image.lock
make -C infrastructure platform-stage OBJECT=app-platform/investment-app; echo "exit=$?"
grep -rn "BEGIN PRIVATE KEY\|BEGIN PUBLIC KEY" gitops/ | head -3   # 必须没有
make -C infrastructure application-deployment-plan APP=investment 2>&1 | grep -E "schema|revision|ok=|failed=" | tail -4; echo "exit=${PIPESTATUS[0]}"
```

要看到：**只有网页的** `image.lock.yaml` 变（`source_revision` = `309e73d5…`）；后端锁不变；没有 PEM；计划核到 `20261012_0018`、没有新迁移 Job。

## 四、提交、发布、晋级、检查

```bash
git add infrastructure/applications/sources.yaml gitops/components/app-platform/investment-app
git -c core.editor=true commit -m "deploy(investment): 网页热修 CSP 放行本机代理回环口（待办 43）"
make -C infrastructure flux-release; echo "exit=$?"
sudo cat infrastructure/.build/flux/source-candidate.yaml; git rev-parse HEAD
sudo cat infrastructure/.build/flux/source-candidate.yaml | sudo tee infrastructure/environments/kind/flux-source.yaml >/dev/null
sudo chown "$(id -u):$(id -g)" infrastructure/environments/kind/flux-source.yaml 2>/dev/null; git diff infrastructure/environments/kind/flux-source.yaml
git add infrastructure/environments/kind/flux-source.yaml && git -c core.editor=true commit -m "release(kind): 晋级到 $(git rev-parse --short HEAD)（待办 43）"
make -C infrastructure flux-source-apply; echo "exit=$?"
make -C infrastructure flux-source-status; echo "exit=$?"
make -C infrastructure application-check APP=investment; echo "exit=$?"
kubectl -n investment get pods | head -12
```

要看到：候选 `revision` = 提交后 HEAD；三次退出 0；网页 Pod 换新、后端 Pod 不重启。

## 验收

钉 = 父仓 `102054b4…`、网页 `309e73d5…`，后端不变；只换网页镜像；`application-check` 0。**真人验收由所有者做**：刷新网页后，工作对话右边栏「文件」出现白名单目录树。

## 失败回退与交回

任一步失败停在原步。需恢复时把 `sources.yaml` 三行改回 `99e92f56…` / `27f6b9b3…`，重走构建到晋级。报告写 `k8s/sunmoonai/scripts/results/web-hotfix-csp-cursor.<时间>.md`，最后一行 `exit=<码>`；本地提交，不 push、不移动本待办。
