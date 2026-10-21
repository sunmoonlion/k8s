# cursor 卡 fable-c1：集群身份与路径参数化——开发站点渲染字节不变（0039 停点 C1）

> 状态：**可执行**（远程 Fable 2026-10-21 写；**第二版** 2026-10-21 晚：第一节改为从父提交的临时工作树取基线，答 qwen 的停点；**改派 Cursor** 2026-10-21 晚，qwen 配额用尽，所有者定；**第三版**：Cursor 第一次改后渲染在 private_dir 断言失败——应用配置被 `lookup("file")` 重读不过 Jinja，是 C1 的 bug，已修（两个路径字段改由加载处推出），**改前基线复用你上次渲染好的，不用再开临时工作树**；**第四版**：第二次比对的三类差异都已处理——配置摘要的键序改回原位、改后渲染改从干净的 `.build/components` 起步以排除主工作树残留（旧名应用目录、旧 sops 候选））。C1 改了 59 个文件、一行业务逻辑都没加：把写死的集群名 `sunmoon-kind`、`kind-` 上下文前缀、`/mnt/sunmoon-data`、`/home/zymun` 收进 `environments/kind/site.yaml`，模块配置改成按站点值派生，守卫改成跨字段核对。**这种改法唯一的验收就是「改前改后结果一模一样」**，所以这张卡的核心是你在本地先按现在的代码渲染一遍存下来，再拉新代码渲染一遍，逐字节比。
>
> 工位 **WS=fable**：`~/worktrees/fable/sunmoonun`，分支 fable（不是 cursor 自己的工位）。只读集群，不部署、不改 gitops 声明、不碰 Harbor/Jenkins 数据。卡命令本身的笔误可以改并写进回执；代码不对就**停**，把输出写进 `inbox/fable/`，不就地改代码。

```text
前提：开发集群在跑。先 make -C infrastructure platform-status OBJECT=all 看一眼；WSL 空闲停过机的话 platform-start 拉起来再开始
耗时：components-render OBJECT=all 两遍各约 3–6 分钟；render-check 约 6–7 分钟
产物目录：~/sunmoon-probe-runs/c1-<时间戳>/（不进 git）
```

## 一、改前基线：复用上一轮的

上一轮你在 `~/sunmoon-probe-runs/c1-20261021-2008/before/` 已经把 `c2d0dbb5` 的渲染、plan、config 存好了（补了 `services-chart` 和旁路应用仓软链后 failed=0），直接用它：

```bash
P=~/sunmoon-probe-runs/c1-20261021-2008; ls $P/before/components | head -3; tail -1 $P/before/plan.log; wc -l $P/before/config.txt
```

要看到有文件、`failed=0`、62 行。目录不在了才按上一版卡（git 历史里 3558f402 的第一节）重做基线：临时工作树 + 软链 `.venv`/`.tools` + 旁路应用仓软链 + 先 `make services-chart`。

## 二、改后：在主工作树（拉到本次修复之后）渲染

```bash
cd ~/worktrees/fable/sunmoonun && git pull --ff-only origin fable && git status --short && git log --oneline -1
cd infrastructure
grep -c "private_dir" ../gitops/components/app-platform/tpl-app/tpl-backend/config.yaml || echo "0 (字段已不在配置里，由加载处推出)"
# 主工作树的 .build/components 里有历次渲染的残留（旧名应用目录、旧的 sops 候选），改前基线是冷目录没有这些；
# 为了两边对称，改后也从空目录起步。.build 不进 git，渲染会重新生成；sops 候选不在时从已提交的密文播种，和基线一样。
rm -rf .build/components
make services-chart > $P/after/chart.log 2>&1; tail -1 $P/after/chart.log
make components-render OBJECT=all > $P/after/render.log 2>&1; tail -2 $P/after/render.log
cp -a .build/components $P/after/components
make platform-plan OBJECT=all > $P/after/plan.log 2>&1; tail -1 $P/after/plan.log
make config > $P/after/config.txt
```

要看到：提交在本次修复（卡头提到的第三版提交）或之后；render 末尾 `failed=0`。`$P/after` 里上一轮失败的 render.log 会被覆盖，无妨。

渲染结果或日志里可能带工作树的绝对路径，上一轮 before 来自临时工作树，先把它的路径替换成主工作树的再比（已经替换过就是空操作）：

```bash
grep -rl "$P/base" $P/before | xargs -r sed -i "s#$P/base#$HOME/worktrees/fable/sunmoonun#g"
```

## 三、比

```bash
diff -r $P/before/components $P/after/components && echo RENDER-IDENTICAL
diff $P/before/plan.log $P/after/plan.log && echo PLAN-IDENTICAL
diff $P/before/config.txt $P/after/config.txt && echo CONFIG-IDENTICAL
grep -rl -E "kind-sunmoon-kind|/mnt/sunmoon-data|sunmoon-kind" $P/after/components | head -5
```

`RENDER-IDENTICAL`、`PLAN-IDENTICAL`、`CONFIG-IDENTICAL` 三个都要出现。最后一条 grep 列出的是渲染结果里**本来就含**站点值的文件（比如备份路径、集群名），只是看一眼，不是判据——before 里同样有。有任何 diff 就停：把 `diff -r` 的完整输出存到 `$P/diff.txt`，写 inbox/fable。

> **第三节判定（远程 Fable，2026-10-21 21:40）：通过，从第四节继续。** 你第三次比对只剩 knowbench `domain.sops.yaml` 一个文件。远程经隧道用备份 age 身份把 before、after 和已提交的三份密文各解一次、只比明文的 sha256（明文不落地、不打印）：**before 与 after 明文相同**（`40e4198783be2cc2`），两者都不同于已提交那份（`0a0310dad870afd6`）。所以两次渲染都重新加密了同一份明文，sops 每次加密的 nonce 和 `lastmodified` 不同，密文自然不同——这是 sops 的不确定性，不是 C1 的改动。六个 workload、全部其他文件逐字节相同，PLAN、CONFIG 相同。**RENDER 视为 IDENTICAL。**
>
> 顺带观察（不是本卡的事）：knowbench 的 domain 明文已和已提交的密文不一致，说明某个输入（relay 管理口令或 provisioner 口令之类）自上次 stage 后变过，下次 `platform-stage` 会把它带上。远程记账。

## 四、改到的入口各跑一次（只读）

```bash
cd ~/worktrees/fable/sunmoonun/infrastructure
make cluster-dns-check 2>&1 | tail -3                      # check-dns.py 现在只读站点文件，要 "passed": true
make platform-status OBJECT=all 2>&1 | grep -E "failed=|msg" | tail -4
make platform-account-plan OBJECT=registry 2>&1 | grep -E "failed=|msg" | tail -3   # 账号路径守卫改读 SUNMOON_DATA_ROOT
make platform-check OBJECT=data-platform/object-storage 2>&1 | tee $P/object-storage-check.log | grep -E "failed=|passed|FAILED" | tail -3   # verify.py 现在收 --context
make jenkins-agent-check 2>&1 | tail -3                    # Jenkins 上的 render-check 要 SUCCESS
```

render-check 结束后把 Jenkins 构建号、结果和 `diff.txt` 行数写进回执（看法同 b2 卡：`infrastructure/jenkins/使用说明` 已搬到 `docs/ops/jenkins-使用说明.md`）。

## 五、回执

上一轮临时工作树已删；`git worktree list` 确认没有残留即可。`$P/before`、`$P/after` 留着。

`scripts/results/fable-c1.<YYYYMMDD-HHMM>.md`：三个 IDENTICAL 的原文、第四节五条命令的末尾输出、render-check 构建号；卡移 `done/`；`git add` 回执与卡 → commit → `git push origin fable`。不通过就停，写 `inbox/fable/`，把 `$P/diff.txt` 或失败命令的输出贴进去。
