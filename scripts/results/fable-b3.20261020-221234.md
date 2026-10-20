# fable-b3 回执：停在第二节——控制器重启做完了，但 render-check 的「同时只跑一个」没装上（根因已只读确证）

- 卡：`docs/dev-investment-agent/switch-test/inbox/qwen/2026-10-20-fable-b3-release-to-plan.md`（95 行，远程 Fable 2026-10-20 夜写，第五版之后的 0033 第八节第 3 步）。**卡未做完，仍留在 `inbox/qwen/`，没移 `done/`**（所有者 2026-10-20 夜裁定：先不跑第三节，等远程修好再接着跑）。
- 工位 `WS=fable`：`~/worktrees/fable/k8s`，分支 `fable`；执行者 Qwen（所有者点名）。
- 结论：**停在第二节**。第一节全过；第二节四个 `make` 全 0、`init.groovy.d/` 四份齐、`release job: present`，但**并发闸判据不符**——卡面要「两份 config.xml 的计数都是 1」，实际 `render-check:0`、`release:2`。`release:2` 是判据写法问题（开标签+闭标签各数一次，实际一个 property，实质满足）；`render-check:0` 是真没有。根因不在渲染、不在部署，在**首启脚本的落盘方式**：`/opt/sunmoon/jenkins/init.groovy.d` 挂到容器的是镜像的 **ref 目录** `/usr/share/jenkins/ref/init.groovy.d`，而 Jenkins 入口把 ref 拷进 `/var/jenkins_home` 时**只拷目标不存在的文件**，所以新版 `03-render-check.groovy` 没能覆盖 home 里 18:32 的旧版，21:58:05 执行的是旧版（没有 else 补属性分支）。
- 第三节（tpl、`PIN=keep`、构建三个镜像推 Harbor）、第四节（产物只读）、第五节（所有者走查）**全部未做**。
- 纪律：没手改 `/opt`、jenkins_home、代理仓目录里任何文件；没做第二次重启；没构建、没推任何镜像；没写库；没替所有者在界面里点；没读、没抄口令与 crumb（`jenkins-*` 各 make 内部的凭据由 Ansible `no_log` 持有）。所有排查都是只读（`ls`/`grep`/`sha256sum`/`docker inspect`/`journalctl`/`systemctl show`/`git log`）。

## 一、核对与拉取（只读）——全过

```text
$ cd ~/worktrees/fable/k8s && git pull --ff-only origin fable
Already up to date.
pull exit=0
$ git log --oneline -1
6cfd59c8 release.groovy：参数校验改成 for 循环与普通字符串正则（避开 CPS 的 each 与含 $ 的斜线串）
$ git status --short | head -3
（空，工作区干净）

$ ls ci/release.groovy ci/pin-sources.py infrastructure/jenkins/templates/04-release.groovy.j2
ci/pin-sources.py
ci/release.groovy
infrastructure/jenkins/templates/04-release.groovy.j2
ls exit=0

$ grep -n "SuccessExitStatus" infrastructure/jenkins/templates/sunmoon-jenkins.service.j2
20:SuccessExitStatus=130 143
grep exit=0

$ make -C infrastructure jenkins-status
status exit=0
localhost : ok=5    changed=0    unreachable=0    failed=0    skipped=29   rescued=0    ignored=0
$ make -C infrastructure jenkins-agent-status
agent status exit=0
localhost : ok=7    changed=0    unreachable=0    failed=0    skipped=27   rescued=0    ignored=0

$ sudo -n bash -c 'for f in /mnt/sunmoon-data/jenkins/home/jobs/*/builds/*/build.xml; do grep -q "<result>" "$f" || echo "running: $f"; done; echo builds-scan-done'
builds-scan-done
scan exit=0
```

判据逐条：HEAD `6cfd59c8` 是本卡这次提交或更新 ✓（拉的时候远端比 b2e 那轮又多了一笔，就是它）；三个文件在 ✓；`SuccessExitStatus=130 143` ✓；两个 status 都是 0 ✓；构建扫描只出 `builds-scan-done`、没有 `running:` 行 ✓（所以重启不会打断任何构建）。

## 二、控制器重启——四个 make 全 0，但判据不符，停

按卡先停代理再停控制器（代理单元 `Requires=` 控制器）：

```text
$ make -C infrastructure jenkins-agent-stop
agent stop exit=0
localhost : ok=6    changed=1    unreachable=0    failed=0    skipped=28   rescued=0    ignored=0
$ make -C infrastructure jenkins-stop
stop exit=0
localhost : ok=6    changed=1    unreachable=0    failed=0    skipped=28   rescued=0    ignored=0
$ systemctl show sunmoon-jenkins.service --property=ActiveState,Result | cat
Result=exit-code
ActiveState=failed
$ make -C infrastructure jenkins-deploy
deploy exit=0
localhost : ok=69   changed=3    unreachable=0    failed=0    skipped=9    rescued=0    ignored=0
$ make -C infrastructure jenkins-agent-start
agent start exit=0
localhost : ok=8    changed=1    unreachable=0    failed=0    skipped=26   rescued=0    ignored=0
$ make -C infrastructure jenkins-status
status exit=0
localhost : ok=5    changed=0    unreachable=0    failed=0    skipped=29   rescued=0    ignored=0
$ make -C infrastructure jenkins-agent-status
agent status exit=0
localhost : ok=7    changed=0    unreachable=0    failed=0    skipped=27   rescued=0    ignored=0

$ sudo -n bash <<'SH'
ls /opt/sunmoon/jenkins/init.groovy.d/
test -f /mnt/sunmoon-data/jenkins/home/jobs/release/config.xml && echo "release job: present"
grep -c DisableConcurrentBuildsJobProperty /mnt/sunmoon-data/jenkins/home/jobs/render-check/config.xml /mnt/sunmoon-data/jenkins/home/jobs/release/config.xml
SH
01-platform.groovy
02-agent-node.groovy
03-render-check.groovy
04-release.groovy
release job: present
/mnt/sunmoon-data/jenkins/home/jobs/render-check/config.xml:0
/mnt/sunmoon-data/jenkins/home/jobs/release/config.xml:2
sudo-block exit=0
```

判据逐条：

| 判据 | 实际 | 结论 |
| --- | --- | --- |
| 四个 make 都是 0 | agent stop 0、stop 0、deploy 0（`ok=69 changed=3 failed=0`）、agent start 0；两个 status 也 0 | ✓ |
| 停完 `ActiveState=inactive`、`Result=success` | `ActiveState=failed`、`Result=exit-code` | **照卡面记，不算失败**：卡面明写「旧单元会是 failed…这次停用的还是旧单元，`Result=exit-code` 也照实记」。新的 `SuccessExitStatus=130 143` 要**下次停**才看得出，本卡无法验证 |
| `init.groovy.d/` 里 01 到 04 四个 | 四个都在 | ✓（但内容与 `/opt` 不一致，见下） |
| `release job: present` | present | ✓ |
| 两份 config.xml 的计数都是 1 | `render-check:0`、`release:2` | **✗ 停在这里** |

`release:2` 的实情（只读核）：那两行是同一个 property 的开标签与闭标签——

```text
37:    <org.jenkinsci.plugins.workflow.job.properties.DisableConcurrentBuildsJobProperty>
39:    </org.jenkinsci.plugins.workflow.job.properties.DisableConcurrentBuildsJobProperty>
```

即 release job **确实带一条**并发闸，`grep -c` 数的是行数不是元素个数。远程把判据改成「数元素」或 `grep -c '<org.jenkinsci.plugins.workflow.job.properties.DisableConcurrentBuildsJobProperty>'`（只匹配开标签）即可。

`render-check:0` 的实情：整份 config.xml 里连 `concurrent` 字样都零命中（`grep -in concurrent` exit=1），properties 段只有 `ParametersDefinitionProperty`（BRANCH/APPS/FORCE）与 `PipelineTriggersJobProperty`，**没有** `DisableConcurrentBuildsJobProperty`；且它的 mtime 停在 **18:32:51**，这次 21:58 的重启根本没重写它（对照：`release/config.xml` 是 21:58:05 新建）。

## 三、停点根因（全部只读取证）

### 3.1 挂载关系：`/opt` 挂的是镜像 ref 目录，不是 jenkins_home

```text
$ sudo -n docker inspect sunmoon-jenkins-jenkins-1 --format '{{range .Mounts}}{{.Source}} -> {{.Destination}} ({{.Type}}){{end}}'
/mnt/sunmoon-data/jenkins/home -> /var/jenkins_home (bind)
/opt/sunmoon/jenkins/secrets/admin-password -> /run/secrets/admin-password (bind)
/opt/sunmoon/jenkins/init.groovy.d -> /usr/share/jenkins/ref/init.groovy.d (bind)
/opt/sunmoon/jenkins/ref-plugins -> /usr/share/jenkins/ref/plugins (bind)
```

`init.groovy.d` 落在 **`/usr/share/jenkins/ref/init.groovy.d`**。Jenkins 官方镜像的入口把 ref 里的东西拷进 `$JENKINS_HOME` 时是**只拷目标不存在的**（`--ignore-existing` 语义），已存在的同名文件不覆盖。

### 3.2 两边文件对不上：新的没进去，跑的是旧的

```text
== 容器内 /var/jenkins_home/init.groovy.d ==
-rw-r--r-- 1 jenkins jenkins 1559 10-20_17:40:54 01-platform.groovy
-rw-r--r-- 1 jenkins jenkins 1348 10-20_18:32:41 02-agent-node.groovy
-rw-r--r-- 1 jenkins jenkins 1890 10-20_18:32:41 03-render-check.groovy     ← 旧版，1890 字节
-rw-r--r-- 1 jenkins jenkins 2286 10-20_21:57:57 04-release.groovy           ← 新文件，进去了
209fa0f2389bdd4f2cc315d0441a35dceac7ecbb8eb0b2de42a250fb867bef49  01-platform.groovy
024bc06469190271f586c0c72171a3e8123b046683856709094dfd3b76a53514  02-agent-node.groovy
ae31740442d1fbcab974eb57e251d0a786745a053e90652f83d9444db3edee21  03-render-check.groovy
c79a0c7145adaa3ccb65397de6e611b1a4b31e2eb149f4055f7de774b723b9f2  04-release.groovy

== 宿主 /opt/sunmoon/jenkins/init.groovy.d ==
-rw-r--r-- 1 root root 1559 10-20_17:40:54 01-platform.groovy
-rw-r--r-- 1 root root 1348 10-20_18:32:41 02-agent-node.groovy
-rw-r--r-- 1 root root 2680 10-20_21:57:57 03-render-check.groovy            ← 新版，2680 字节
-rw-r--r-- 1 root root 2286 10-20_21:57:57 04-release.groovy
209fa0f2389bdd4f2cc315d0441a35dceac7ecbb8eb0b2de42a250fb867bef49  01-platform.groovy   （两边同）
024bc06469190271f586c0c72171a3e8123b046683856709094dfd3b76a53514  02-agent-node.groovy （两边同）
d4cc9ff94cd40bc97d02da7ab91d5e9132924c42dde3cb5f3150e63a205f181d  03-render-check.groovy ← 两边不同
c79a0c7145adaa3ccb65397de6e611b1a4b31e2eb149f4055f7de774b723b9f2  04-release.groovy    （两边同）
```

`01`、`02`、`04` 两边 sha256 相同；**只有 `03` 不同**——正是这次唯一改过内容、且 home 里已有同名旧文件的那份。`04` 因为是新文件（home 里原先没有）才被拷进去，这也解释了为什么 release job 建成了、render-check 的属性却没补上。

### 3.3 部署与执行都对，就是执行的那份是旧的

```text
== /opt 里新版 03 确实含 else 补属性分支 ==
14:if (jenkins.getItem('render-check') == null) {
18:    job.addProperty(new DisableConcurrentBuildsJobProperty())
36:    job.save()
37:} else {
39:    def job = jenkins.getItem('render-check')
40:    if (job instanceof WorkflowJob && job.getProperty(DisableConcurrentBuildsJobProperty) == null) {
41:        job.addProperty(new DisableConcurrentBuildsJobProperty())
42:        job.save()
（44 行，与仓里模板 03-render-check.groovy.j2 同形；import 段 jenkins.model.Jenkins / WorkflowJob / DisableConcurrentBuildsJobProperty 都齐）

== 控制器这次启动与首启脚本执行（journalctl，无口令）==
ExecMainStartTimestamp=Tue 2026-10-20 21:58:00 CST
ActiveEnterTimestamp=Tue 2026-10-20 21:58:00 CST
NRestarts=0
21:58:05 j.util.groovy.GroovyHookScript#execute: Executing /var/jenkins_home/init.groovy.d/01-platform.groovy
21:58:05 j.util.groovy.GroovyHookScript#execute: Executing /var/jenkins_home/init.groovy.d/02-agent-node.groovy
21:58:05 j.util.groovy.GroovyHookScript#execute: Executing /var/jenkins_home/init.groovy.d/03-render-check.groovy
21:58:05 j.util.groovy.GroovyHookScript#execute: Executing /var/jenkins_home/init.groovy.d/04-release.groovy
（grep -inE "init\.groovy|init hook|SEVERE|Exception|Failed to run" 只出这四条 INFO，无任何异常/SEVERE）
```

四份都执行了、没报错——因为跑的 `03` 是旧版，旧版只有 `if (getItem == null) {…}`，任务已存在就什么也不做，自然既不 addProperty 也不 save()，config.xml 的 mtime 也就停在 18:32:51。

### 3.4 时间线佐证（`git log`，只读）

```text
$ git log --oneline -3 -- infrastructure/jenkins/templates/03-render-check.groovy.j2
eca20738 jenkins-agent-check 提交构建回 400 的根因：… render-check 任务加「同时只跑一个」（控制器重启后生效）；接续卡 fable-b2d；luna 的收件移 done
d549d18b 平台线 B 段第 2 步：宿主代理、插件闭包装入控制器、只读 render-check（SDD 0033 第八节第 2 步）

$ git log --oneline -S "} else {" -- …/03-render-check.groovy.j2
eca20738（同上）
$ git log --oneline -1 --before="2026-10-20 18:33" -- …/03-render-check.groovy.j2
d549d18b
```

即：`addProperty` 与 else 补属性分支是 `eca20738`（b2c 那笔）才加的，提交说明写「控制器重启后生效」；而 **18:32 那次部署时工位上还是 `d549d18b` 版**（无这两段）。这次 21:57 是新版**第一次**被部署，也就第一次撞上 ref→home「只拷不存在」的语义。

### 3.5 连带隐患（不只影响 render-check）

`01`、`02` 现在两边 sha 相同，所以看不出症状；但按同一语义，**以后改 `01-platform.groovy`、`02-agent-node.groovy`、`03-render-check.groovy` 任何一份，重启后都不会生效**，除非换落盘方式。这次是 `03` 先撞上，因为它恰好是「已存在 + 内容改了」的组合。

### 3.6 我确证不到的部分（不猜，交远程）

运行时 render-check 到底有没有这条属性，只能问 Jenkins API/CLI，而那要 crumb 与凭据——卡面明令不读不抄，**我没查**。盘上 config.xml 的证据（零命中 + mtime 未变 + 容器里跑的是旧版 03）已足以说明「没装上」；但「旧版 03 在更早某次是否曾以别的方式加过这条属性」我无法只读排除——从 `eca20738` 才引入这两段代码看，答案应是「从没加过」，这句是推断不是实测，标明在此。

## 四、第三、四、五节——未做

- **第三节（release 试跑 tpl、`PIN=keep`、到第 5 阶段）未做**：卡面第 3 行把「顺带让第 2 步留下的『同时只跑一个』生效」写成这次重启的目的之一，而它没生效；第三节要跑十几分钟、构建三个 tpl 镜像，render-check 定时 10 分钟一次且**无并发闸**，两者可能抢代理那唯一的执行器（b2c 回执记过这个现象：#1 在跑、#2–#5 挂着排队），会搅乱第三节的判据（七阶段、`total=0`、`Finished: SUCCESS`）。所有者 2026-10-20 夜裁定：**先不跑，等远程修好再跑**。所以 Harbor 里没多任何镜像，`gitops/`、`sources.yaml` 我一个字没动（`git status --short` 全程为空）。
- **第四节（产物只读）未做**：依赖第三节。
- **第五节（所有者走查）未做**：卡面「不急」，且没替所有者在界面里点。可对照的命令行事实：首页现在应有两个任务（`release job: present`、render-check 的 config.xml 在）、`init.groovy.d/` 四份、控制器与代理 active/running/enabled（第二节两个 status=0）。**注意**：走查时若看 render-check 的「同时只跑一个」，界面上应该仍是**没勾**的，与 3.2/3.3 一致。

## 五、纪律与清理

- 未做的动作：没跑 `jenkins-release-run`；没构建、没推任何镜像；没提交/发布/动集群；没写库；没 `rollout restart`；没碰入口、应用现网、Harbor 里已有的镜像；没手改 `/opt`、`/var/jenkins_home`、代理仓目录里任何文件；没做第二次重启；没替所有者点界面。
- 现场净变化只有卡面第二节授权的那些：代理与控制器各停一次、`jenkins-deploy`（`changed=3`：新单元 `SuccessExitStatus=130 143`、新首启脚本 `04-release.groovy` 等）、代理起一次；副作用是 Jenkins 多了一个 `release` job（带并发闸，未跑过任何构建）。
- 一次性产物：`/tmp/b3-sec1.log`、`b3-sec2.log`、`b3-jenkins-status.log`、`b3-agent-status.log`、`b3-agent-stop.log`、`b3-stop.log`、`b3-deploy.log`、`b3-agent-start.log`、`b3-status2.log`、`b3-agent-status2.log`——关键原文已全抄进本回执，**全部删除**；仓内无 `scripts/tmp-*`、无一次性脚本落盘（命令块直接在 bash 里跑）。
- 推回：平台线例外条款，`git pull --ff-only origin fable` 后 `git push origin fable`。**本次只提交两样：本回执 + 给远程的一页 `inbox/fable/2026-10-20-fable-b3-init-ref-copy.md`；卡不移 `done/`**（未做完）。

## 六、请远程做什么

见 `docs/dev-investment-agent/switch-test/inbox/fable/2026-10-20-fable-b3-init-ref-copy.md`：三条候选修法（直挂 `/var/jenkins_home/init.groovy.d`／部署时先删 home 里的同名旧份／文件名带版本号）与各自的顾虑，以及修好后请把 b3 第三节起重新发一张接续卡（或在本卡上标注从第三节续跑）。修法选哪条由远程定，Qwen 不自己改实现。
