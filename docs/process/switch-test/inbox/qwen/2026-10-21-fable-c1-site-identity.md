# qwen 卡 fable-c1：集群身份与路径参数化——开发站点渲染字节不变（0039 停点 C1）

> 状态：**可执行**（远程 Fable 2026-10-21 写）。C1 改了 59 个文件、一行业务逻辑都没加：把写死的集群名 `sunmoon-kind`、`kind-` 上下文前缀、`/mnt/sunmoon-data`、`/home/zymun` 收进 `environments/kind/site.yaml`，模块配置改成按站点值派生，守卫改成跨字段核对。**这种改法唯一的验收就是「改前改后结果一模一样」**，所以这张卡的核心是你在本地先按现在的代码渲染一遍存下来，再拉新代码渲染一遍，逐字节比。
>
> 工位 **WS=fable**：`~/worktrees/fable/sunmoonun`，分支 fable（不是 qwen 工位）。只读集群，不部署、不改 gitops 声明、不碰 Harbor/Jenkins 数据。卡命令本身的笔误可以改并写进回执；代码不对就**停**，把输出写进 `inbox/fable/`，不就地改代码。

```text
前提：开发集群在跑。先 make -C infrastructure platform-status OBJECT=all 看一眼；WSL 空闲停过机的话 platform-start 拉起来再开始
耗时：components-render OBJECT=all 两遍各约 3–6 分钟；render-check 约 6–7 分钟
产物目录：~/sunmoon-probe-runs/c1-<时间戳>/（不进 git）
```

## 一、改前基线（先别拉代码）

```bash
cd ~/worktrees/fable/sunmoonun && git status --short && git log --oneline -1
P=~/sunmoon-probe-runs/c1-$(date +%Y%m%d-%H%M); mkdir -p $P/before $P/after; echo "P=$P"
cd infrastructure
make components-render OBJECT=all > $P/before/render.log 2>&1; tail -2 $P/before/render.log
cp -a .build/components $P/before/components
make platform-plan OBJECT=all > $P/before/plan.log 2>&1; tail -1 $P/before/plan.log
make config > $P/before/config.txt
```

要看到：工作区干净；`git log` 的提交是 `c2d0dbb5` 或更早（**不能**已经是 C1 的提交，否则基线就不是「改前」——真是那样就停，写 inbox/fable）；两个 log 末尾 `failed=0`。

## 二、拉代码，改后再来一遍

```bash
cd ~/worktrees/fable/sunmoonun && git pull --ff-only origin fable && git log --oneline -1
cd infrastructure
make components-render OBJECT=all > $P/after/render.log 2>&1; tail -2 $P/after/render.log
cp -a .build/components $P/after/components
make platform-plan OBJECT=all > $P/after/plan.log 2>&1; tail -1 $P/after/plan.log
make config > $P/after/config.txt
```

## 三、比

```bash
diff -r $P/before/components $P/after/components && echo RENDER-IDENTICAL
diff $P/before/plan.log $P/after/plan.log && echo PLAN-IDENTICAL
diff $P/before/config.txt $P/after/config.txt && echo CONFIG-IDENTICAL
grep -rl -E "kind-sunmoon-kind|/mnt/sunmoon-data|sunmoon-kind" $P/after/components | head -5
```

`RENDER-IDENTICAL`、`PLAN-IDENTICAL`、`CONFIG-IDENTICAL` 三个都要出现。最后一条 grep 列出的是渲染结果里**本来就含**站点值的文件（比如备份路径、集群名），只是看一眼，不是判据——before 里同样有。有任何 diff 就停：把 `diff -r` 的完整输出存到 `$P/diff.txt`，写 inbox/fable。

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

`scripts/results/fable-c1.<YYYYMMDD-HHMM>.md`：三个 IDENTICAL 的原文、第四节五条命令的末尾输出、render-check 构建号；卡移 `done/`；`git add` 回执与卡 → commit → `git push origin fable`。不通过就停，写 `inbox/fable/`，把 `$P/diff.txt` 或失败命令的输出贴进去。
