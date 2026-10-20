# luna 卡 fable-b3（第三版，从第三节起）：release 流水线到「计划」为止（0033 第八节第 3 步）

> 状态：**可执行**（远程 Fable 2026-10-20 夜写）。前两版由 Qwen 跑：第一、二节已全过（控制器重启、四份首启脚本按 `.override` 落盘、`release` 任务在、两个任务都带「同时只跑一个」、新单元停机 `Result=success`），不重做。第三节撞了两处我的错，已修：① `agent.yaml` 里等构建的 `retries` 表达式没先把字符串转整数（`make` 立刻 exit 2）；② `PIN=keep` 时流水线第 1 阶段把应用仓检到分支头，而构建链要求子仓 HEAD 恰等于 `sources.yaml` 钉的号，钉落后于头就撞「拒绝构建未复核的修订」的闸——现在第 2 阶段末尾加了「按钉对齐检出」（`ci/align-sources.py`），远程在 tpl 的临时克隆上排练过：从头 2100a568 对齐到钉 65b8b11d，工作区干净。顺带修了部署时删旧首启脚本那条的正则（没删掉是因为它没选中任何文件）。
>
> **本卡的临时授权（所有者 2026-10-20 夜定，只对这张卡和之后平台线的卡，不是长期规矩）**：跑的过程中撞到**这张卡改到的文件**（`ci/*.groovy`、`ci/*.py`、`infrastructure/jenkins/**`、`infrastructure/Makefile` 的 jenkins 段、本卡的命令）里让步骤过不去的错，你可以**就地改、自己验、接着跑**，代码改动直接提交推 `origin/fable`。**不能自己定的**：改「怎样算通过」；碰安全约束（不关证书校验、不打印口令与 crumb、不读 `ca.key`）；改设计（东西放哪、分几步、用什么机制）；碰产品线代码、`gitops/` 声明、集群、Harbor 已有镜像——这些停下来写 `inbox/fable/`。回执里单列一节「就地修了什么」：每处的提交号、改前错在哪、改后怎么验过的；远程逐个审。

```text
被测仓：k8s；工位 WS=fable：~/worktrees/fable/k8s，分支 fable；远程和本地都只推拉这个分支
改动（本次）：ci/align-sources.py（新）、ci/release.groovy（第 2 阶段末尾对齐）、infrastructure/jenkins/agent.yaml（retries）、service.yaml（删旧脚本的正则）、README
会联网的：构建拉已锁的基础镜像（本地 Harbor）、应用仓 git fetch（SSH）、推镜像到本地 Harbor
停下的规则：任何一步 exit 不是 0，先看是不是授权范围内能修的；能修就修、记下、续跑；不能就停，输出原样进回执
不碰：入口、集群、应用现网、Harbor 里已有的镜像；不写库；不替所有者在界面里点；不读、不抄口令与 crumb；不在代理的仓目录里手改任何文件（对齐检出由流水线做）
```

## 一、核对与拉取（只读）

```bash
cd ~/worktrees/fable/k8s && git pull --ff-only origin fable && git log --oneline -1 && git status --short | head -3
grep -n "2-align\|align-sources" ci/release.groovy
grep -n "jenkins_run_timeout_seconds | int" infrastructure/jenkins/agent.yaml
make -C infrastructure jenkins-status; echo "status exit=$?"
make -C infrastructure jenkins-agent-status; echo "agent status exit=$?"
sudo -n bash <<'SH'
grep -l '<duration>0</duration>' /mnt/sunmoon-data/jenkins/home/jobs/*/builds/*/build.xml 2>/dev/null || echo "no build in progress"
grep -c 'BuildableItem\|WaitingItem' /mnt/sunmoon-data/jenkins/home/queue.xml 2>/dev/null || echo "queue empty"
SH
```

要看到：HEAD 是本卡这次提交或更新；两个 grep 各有命中；两个 status 都是 0；没有进行中的构建、队列空（有就等它结束，render-check 的 NOT_BUILT 十几秒、全跑六七分钟）。

顺带一条只读：`ls /opt/sunmoon/jenkins/init.groovy.d/` 现在应仍是 8 个文件（旧的 4 个要下次 `jenkins-deploy` 才删，本卡不重装控制器；照实记就行）。

## 二、release 试跑：tpl，PIN=keep，到第 5 阶段

```bash
make -C infrastructure jenkins-release-run APPS="tpl" PIN=keep NOTE="B3 试跑 tpl 到计划为止"; echo "release exit=$?"
bash <<'SH'
log=$(ls -t infrastructure/.build/jenkins/release-*.log | head -1); echo "$log"
grep -n "^\[Pipeline\] { (\|Finished:\|total=\|changed lines\|gitops 变更\|parent .* backend " "$log" | tail -16
SH
```

要看到：`release exit=0`，`Report the build result` 里 `result: SUCCESS`，说明里「到第 5 阶段为止（B3）；gitops 变更 N 个文件，未提交」；日志里七个阶段都进了（`1 核对`…`5 计划`、`秘密样子核查与产物`、`工作区回到干净`），第 2 阶段有一行 `tpl: parent 65b8b11d3c backend ab7139389c …`（对齐到钉），`total=0`，`Finished: SUCCESS`。十几分钟（三个镜像构建）。

不是 0：日志在 `infrastructure/.build/jenkins/release-<n>.log`（`make` 没等到的话在控制器 `/mnt/sunmoon-data/jenkins/home/jobs/release/builds/<n>/log`，sudo 读）。按授权判断能不能就地修；修了就再跑一次，回执里两次都记。

## 三、看产物与收尾（只读）

```bash
bash <<'SH'
n=$(ls -t infrastructure/.build/jenkins/release-*.log | head -1 | sed -E 's/.*release-([0-9]+)\.log/\1/')
d=/mnt/sunmoon-data/jenkins/repos/k8s/infrastructure/.build/release/$n; echo "$d"; ls "$d"
echo "== 2-sources.diff: $(wc -l < "$d/2-sources.diff") 行（keep 应为 0）"
echo "== 2-align.log"; grep "^tpl:" "$d/2-align.log"
echo "== 3-image-locks.txt"; cat "$d/3-image-locks.txt"
echo "== 4-gitops-touched.txt"; cat "$d/4-gitops-touched.txt"
echo "== 4-gitops.stat"; cat "$d/4-gitops.stat"
echo "== 4-workload.diff: $(wc -l < "$d/4-workload.diff") 行，前 60 行"; head -60 "$d/4-workload.diff"
echo "== 代理仓是否干净"; git -C /mnt/sunmoon-data/jenkins/repos/k8s status --short --untracked-files=no | head; echo clean-check-done
SH
```

要看到：`2-sources.diff` 0 行；对齐行 `tpl: parent 65b8b11d3c backend ab7139389c web 479c7e6ce6 admin b89e474191`；镜像锁变了 **3 个**，都在 `tpl-app/` 下，`source_revision` 等于钉的号；`4-gitops-touched.txt` 只有 tpl-app 的组件；`4-workload.diff` 里除 `DEPLOYMENT_ID` 和 Job 名外，预期还有两段 ingress 的 `/api/internal`（模板比 tpl 已提交的声明新，B3 不发它）；别的行照实贴；`clean-check-done` 前为空。

## 四、所有者走查（不急）

浏览器开 Jenkins：`release` 的构建历史里有这次 SUCCESS（前面 #1 是 FAILURE，是修的过程），构建页 **Build Artifacts** 下 `infrastructure/.build/release/<号>/` 里的文件能点开；Stage View 七列都绿。

## 五、回执与推回

`scripts/results/fable-b3.<时间>.md`：每节命令与 exit、第二节日志那 16 行、第三节各文件内容（4-workload.diff 前 60 行）、**「就地修了什么」一节**（没修就写「没有」）、停在哪（若有）。不拍、不抄任何口令与 crumb。

```bash
cd ~/worktrees/fable/k8s && git pull --ff-only origin fable && git add scripts/results/fable-b3.*.md && git mv docs/dev-investment-agent/switch-test/inbox/luna/2026-10-20-fable-b3-release-to-plan-v3.md docs/dev-investment-agent/switch-test/done/ && git commit -m "fable-b3 回执：release 到计划为止（luna）" && git push origin fable; echo "push exit=$?"
```

代码改动（若有）单独提交在回执之前，说明写清改了什么；拉不下来（非快进）或推不上去就停下，把输出告诉所有者，不强推。
