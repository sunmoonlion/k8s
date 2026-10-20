# qwen 卡 fable-b3（第二版，从第二节续跑）：release 流水线到「计划」为止（0033 第八节第 3 步）

> 状态：**可执行**（远程 Fable 2026-10-20 夜改）。第一版第二节停在「render-check 没装上并发闸」，Qwen 的根因对：首启脚本挂的是镜像的 ref 目录，镜像入口只拷 home 里不存在的文件，改过的 `03` 进不去。查了锁定镜像里的 `jenkins-support`：ref 里带 `.override` 后缀的文件总是覆盖，所以四份脚本现在都按 `0X-名字.groovy.override` 落盘，进 home 后名字不带后缀，每次启动都是新版；「只建一次」仍由脚本自己判断。顺带把计数判据改成只数开标签。
>
> 第一节已过不重做；第二节再做一次（这次停控制器用的是新单元，`Result` 该是 `success`）；然后第三节起照旧。

```text
被测仓：k8s；工位 WS=fable：~/worktrees/fable/k8s，分支 fable；远程和本地都只推拉这个分支
改动（本次）：ci/release.groovy、ci/pin-sources.py、infrastructure/jenkins/{agent.yaml,service.yaml,templates/04-release.groovy.j2,templates/sunmoon-jenkins.service.j2}、Makefile（jenkins-release-run）、README、使用说明
会联网的：构建拉已锁的基础镜像（本地 Harbor）、应用仓 git fetch（SSH）、推镜像到本地 Harbor
停下的规则：任何一步 exit 不是 0 就停，输出原样进回执，不重试、不退回；ssh 用 -n
不碰：入口、集群、应用现网、Harbor 里已有的镜像；不写库；不替所有者在界面里点；不读、不抄口令与 crumb；不在代理的仓目录里手改任何文件
```

## 一、核对与拉取（只读）

```bash
cd ~/worktrees/fable/k8s && git pull --ff-only origin fable && git log --oneline -1 && git status --short | head -3
ls ci/release.groovy ci/pin-sources.py infrastructure/jenkins/templates/04-release.groovy.j2
grep -n "SuccessExitStatus" infrastructure/jenkins/templates/sunmoon-jenkins.service.j2
make -C infrastructure jenkins-status; echo "status exit=$?"
make -C infrastructure jenkins-agent-status; echo "agent status exit=$?"
sudo -n bash -c 'for f in /mnt/sunmoon-data/jenkins/home/jobs/*/builds/*/build.xml; do grep -q "<result>" "$f" || echo "running: $f"; done; echo builds-scan-done'
```

要看到：HEAD 是本卡这次提交或更新；三个文件在；`SuccessExitStatus=130 143`；两个 status 都是 0；最后只有 `builds-scan-done`（没有在跑的构建；有就等它结束再往下，重启会打断它）。

## 二、控制器重启（装新首启脚本与单元）

代理单元 `Requires=` 控制器，停控制器会一起停代理，所以先停代理再停控制器，装完各自起来。

```bash
make -C infrastructure jenkins-agent-stop; echo "agent stop exit=$?"
make -C infrastructure jenkins-stop; echo "stop exit=$?"
systemctl show sunmoon-jenkins.service --property=ActiveState,Result | cat
make -C infrastructure jenkins-deploy; echo "deploy exit=$?"
make -C infrastructure jenkins-agent-start; echo "agent start exit=$?"
make -C infrastructure jenkins-status; echo "status exit=$?"
make -C infrastructure jenkins-agent-status; echo "agent status exit=$?"
sudo -n bash <<'SH'
ls /opt/sunmoon/jenkins/init.groovy.d/
for f in /opt/sunmoon/jenkins/init.groovy.d/*.override; do b=$(basename "$f" .override); printf '%s ' "$b"; cmp -s "$f" "/mnt/sunmoon-data/jenkins/home/init.groovy.d/$b" && echo same || echo DIFFERENT; done
ls /mnt/sunmoon-data/jenkins/home/init.groovy.d/
test -f /mnt/sunmoon-data/jenkins/home/jobs/release/config.xml && echo "release job: present"
grep -c '<org.jenkinsci.plugins.workflow.job.properties.DisableConcurrentBuildsJobProperty>' /mnt/sunmoon-data/jenkins/home/jobs/render-check/config.xml /mnt/sunmoon-data/jenkins/home/jobs/release/config.xml
SH
```

要看到：四个 make 都是 0；停完那行 `ActiveState=inactive`、`Result=success`（这次停的是上一版装上的新单元）；`/opt` 下四个 `*.groovy.override`，四行都 `same`（home 里是覆盖后的新版）；home 的 `init.groovy.d/` 里只有四个不带后缀的 `.groovy`（要是还多出旧的 `03-render-check.groovy` 以外的东西，照实记）；`release job: present`；两份 config.xml 的开标签计数都是 1。

deploy 不是 0 就停：贴失败任务那段与 `journalctl -u sunmoon-jenkins.service --since '10 min ago' | tail -30`（没有口令）。

## 三、release 试跑：tpl，PIN=keep，到第 5 阶段

```bash
make -C infrastructure jenkins-release-run APPS="tpl" PIN=keep NOTE="B3 试跑 tpl 到计划为止"; echo "release exit=$?"
bash <<'SH'
log=$(ls -t infrastructure/.build/jenkins/release-*.log | head -1); echo "$log"
grep -n "^\[Pipeline\] { (\|Finished:\|total=\|changed lines\|gitops 变更" "$log" | tail -14
SH
```

要看到：`release exit=0`，`Report the build result` 里 `result: SUCCESS`，说明里「到第 5 阶段为止（B3）；gitops 变更 N 个文件，未提交」；日志里七个阶段都进了（`1 核对`…`5 计划`、`秘密样子核查与产物`、`工作区回到干净`），`total=0`，`Finished: SUCCESS`。大约十几分钟（三个镜像构建）。

不是 0：把日志路径与倒在哪个阶段写进回执，日志留 `.build/`，不进 git；不要重跑。

## 四、看产物与收尾（只读）

```bash
bash <<'SH'
n=$(ls -t infrastructure/.build/jenkins/release-*.log | head -1 | sed -E 's/.*release-([0-9]+)\.log/\1/')
d=/mnt/sunmoon-data/jenkins/repos/k8s/infrastructure/.build/release/$n; echo "$d"; ls "$d"
echo "== 2-sources.diff: $(wc -l < "$d/2-sources.diff") 行（keep 应为 0）"
echo "== 3-image-locks.txt"; cat "$d/3-image-locks.txt"
echo "== 4-gitops-touched.txt"; cat "$d/4-gitops-touched.txt"
echo "== 4-gitops.stat"; cat "$d/4-gitops.stat"
echo "== 4-workload.diff: $(wc -l < "$d/4-workload.diff") 行，前 60 行"; head -60 "$d/4-workload.diff"
echo "== 代理仓是否干净"; git -C /mnt/sunmoon-data/jenkins/repos/k8s status --short --untracked-files=no | head; echo clean-check-done
SH
```

要看到：`2-sources.diff` 0 行；镜像锁变了 **3 个**，都是 `tpl-app/` 下的（后端、网页、管理端），`source_revision` 等于 `sources.yaml` 里钉的号；`4-gitops-touched.txt` 只有 tpl-app 的组件；`4-workload.diff` 里除 `DEPLOYMENT_ID` 和 Job 名之外，预期还有两段 ingress 的 `/api/internal`（b2e 的 diff.txt 就看到了，是模板比 tpl 已提交的声明新，B3 不发它）；别的行照实贴，不判断；`clean-check-done` 前为空（工作区干净）。

## 五、所有者走查（不急）

浏览器开 Jenkins：首页有两个任务；`release` 的构建历史里有这次 SUCCESS，构建页 **Build Artifacts** 下 `infrastructure/.build/release/<号>/` 里那些文件能点开；Stage View 七列都绿。`render-check` 照常每 10 分钟灰一次。

## 六、回执与推回

`scripts/results/fable-b3.<时间>.md`：每节命令与 exit、第二节 `ls` 与计数、第三节日志那 14 行、第四节各文件内容（4-workload.diff 前 60 行）、停在哪（若有）。不拍、不抄任何口令与 crumb。

```bash
cd ~/worktrees/fable/k8s && git pull --ff-only origin fable && git add scripts/results/fable-b3.*.md && git mv docs/process/switch-test/inbox/qwen/2026-10-20-fable-b3-release-to-plan.md docs/process/switch-test/done/ && git commit -m "fable-b3 回执：release 到计划为止（qwen）" && git push origin fable; echo "push exit=$?"
```

拉不下来（非快进）或推不上去就停下，把输出告诉所有者，不强推。
