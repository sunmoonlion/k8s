# fable-b3 第二版续跑回执：停在第三节（make exit=2；release #1 自行跑完为 FAILURE）

- 卡：`docs/dev-investment-agent/switch-test/inbox/qwen/2026-10-20-fable-b3-release-to-plan.md`（第二版，标题即写「从第二节续跑」）
- 工位：`~/worktrees/fable/k8s`，分支 `fable`，HEAD `0999ea79 jenkins-deploy：删掉早先不带 .override 落盘的旧首启脚本`
- 跑的时段：2026-10-20 22:25–22:50（本机 CST）
- 第一版停点回执：`scripts/results/fable-b3.20261020-221234.md`（停在第二节「render-check 没装上并发闸」，根因是首启脚本挂镜像 ref 目录、ref→home 只拷不存在的文件）。远程已按此改成 `.override` 落盘（`ed015c1f`、`0999ea79`），并把 Qwen 那页移进 `done/`。
- 一句话结论：**第二节全过（并发闸这次真装上了，`Result=success` 也验到了）；第三节 `make` 因 Ansible 模板 bug 立刻 exit=2，但它排上的 `release #1` 后来自己跑起来又 FAILURE——倒在「拒绝构建未复核的修订」这道闸门上，因为 `PIN=keep` 用的钉与流水线第 1 阶段检出的分支头是两套号。没有镜像被构建或推送，`gitops/` 与 `sources.yaml` 一字未动。按卡面不重跑。**

## 一、第一节：未重做，只记两件与它有关的事

卡面第二版写「第一节已过不重做」。续跑前 HEAD 已是 `0999ea79`（`git pull --ff-only origin fable` exit=0，快进 `6497a008..0999ea79`，工作区干净）。

重启前我按第一节那条安全前提（「没有在跑的构建；有就等它结束再往下，重启会打断它」）又扫了一次：

```text
HEAD=0999ea79 jenkins-deploy：删掉早先不带 .override 落盘的旧首启脚本
14:25:29（UTC，= 22:25:29 CST）第 1 轮: builds-scan-done
  → 无在跑，可以重启
render-check 最新三个构建号: 23 24 25    release: （无构建）
```

两条必须如实记的发现：

1. **这次扫描没能挡住打断**。扫描在 22:25:29 报「无在跑」，`render-check` 的定时器在 22:26:00 触发了 `#26`，我在 22:26:5x 停控制器——差 31 秒。`#26` 被打断后自动恢复，最终 `FAILURE`（详见第六节）。这不是扫描方法的问题，是「扫一次 → 再动手」之间本来就有窗口，定时器每 10 分钟一发。
2. **卡面这个扫描方法本身也不可靠**。它用 `grep -q "<result>" || echo running`，但 Jenkins 的 `build.xml` 在构建**进行中**就写着 `<duration>0</duration>` 和 `<result>SUCCESS</result>` 占位。直接证据：22:33 时 `release #1` 明明还在队列里等执行器（`queue.xml` 挂着 `PlaceholderTask job=release id=1`、log 停在 `Waiting for next available executor`），它的 `build.xml` 却已是 `<result>SUCCESS</result> <duration>0</duration>`；同一时刻 `render-check #26` 正在跑，账面也是同一形态，结束后才变成 `<duration>689275</duration> <result>FAILURE</result>`。所以「有没有 `<result>`」判不出活体，应看 `<building>true</building>`、或 `duration` 是否为 0、或 `builds/<n>/log` 的 mtime 是否在长。

**连带更正一处我此前写错的话**：b2e 回执 `scripts/results/fable-b2e.20261020-213201.md` 第 2.1 节里，我先说 `#18` 在跑、随后「自纠」说自己误读、判定它已完成——**那次自纠是错的，最初的判断才对**。现在 `#18` 的账面是 `<duration>397530</duration> <result>SUCCESS</result>`、log 431325 字节、mtime 21:22:37，即它在 21:21 那会儿确实正在跑，我看到的 `duration 0 + SUCCESS` 就是占位。后果不严重（我等了一轮后触发的强制构建 `#19` 仍 `SUCCESS 395143ms`），但那份回执里那段话会误导后人，我在该文件末尾追加了一节更正，未改动原文。

## 二、第二节（重做）：全过

卡面命令与 exit（每条原样执行，未改一字）：

```text
make -C infrastructure jenkins-agent-stop   → agent stop exit=0
make -C infrastructure jenkins-stop         → stop exit=0
systemctl show sunmoon-jenkins.service --property=ActiveState,Result
                                            → Result=success
                                              ActiveState=inactive
make -C infrastructure jenkins-deploy       → deploy exit=0
   localhost : ok=69 changed=3 unreachable=0 failed=0 skipped=10 rescued=0 ignored=0
make -C infrastructure jenkins-agent-start  → agent start exit=0
make -C infrastructure jenkins-status       → status exit=0
make -C infrastructure jenkins-agent-status → agent status exit=0
sudo 块                                     → sudo-block exit=0
```

卡面 sudo 块的输出原文：

```text
01-platform.groovy
01-platform.groovy.override
02-agent-node.groovy
02-agent-node.groovy.override
03-render-check.groovy
03-render-check.groovy.override
04-release.groovy
04-release.groovy.override
01-platform.groovy same
02-agent-node.groovy same
03-render-check.groovy same
04-release.groovy same
01-platform.groovy
02-agent-node.groovy
03-render-check.groovy
04-release.groovy
release job: present
/mnt/sunmoon-data/jenkins/home/jobs/render-check/config.xml:1
/mnt/sunmoon-data/jenkins/home/jobs/release/config.xml:1
```

判据逐条：

| 判据 | 结果 |
| --- | --- |
| 四个 make 都是 0 | 过（agent stop / stop / deploy / agent start 全 0；deploy `changed=3 failed=0`） |
| 停完 `ActiveState=inactive`、`Result=success` | **过**（第一版那次是旧单元，只能记 `Result=exit-code`；这次停的是新单元，`SuccessExitStatus=130 143` 验到了） |
| `/opt` 下四个 `*.groovy.override`、四行都 `same` | 过 |
| home 的 `init.groovy.d/` 里只有四个不带后缀的 `.groovy` | 过（正好四个，没有多余） |
| `release job: present` | 过 |
| 两份 `config.xml` 的开标签计数都是 1 | **过**（`render-check:1`、`release:1`；第一版是 `0` 与 `2`） |

我另外做的只读确证（卡面没要求，为的是不只看「脚本 Executing、无异常」）：

- `/opt` 下并存 8 个文件（4 个不带后缀 + 4 个 `.override`），四对 `cmp` **全部同内容**；不带后缀那 4 个的 mtime 是早先落盘的（17:40:54 / 18:32:41 / 21:57:57 / 21:57:57），`.override` 那 4 个是这次部署写的（22:26:52–22:26:53）。照实记：`0999ea79` 说明写「删掉早先不带 `.override` 落盘的旧首启脚本」，`/opt` 里那 4 个不带后缀的仍在（home 里那 4 个不带后缀的是入口拷过去的产物，属正常）。因内容相同，本次对运行无影响。
- home 里 `03-render-check.groovy` 现在是 **2680 字节、sha256 `d4cc9ff94cd40bc97d02da7ab91d5e9132924c42dde3cb5f3150e63a205f181d`**、mtime 22:26:52——第一版时它是 1890 字节、`ae317404…`、mtime 18:32:41 的旧版。四份都被覆盖成新版了。
- 控制器 `ExecMainStartTimestamp=Tue 2026-10-20 22:26:56 CST`、`NRestarts=0`；journal 里 22:27:01–22:27:02 四条 `GroovyHookScript#execute: Executing /var/jenkins_home/init.groovy.d/0X-….groovy`，无 `SEVERE`/`Exception`。
- **模板 `03` 的 else 分支这次真跑了**：`jobs/render-check/config.xml` 被重写在 **22:27:02**（2438 → 2656 字节；第一版时它停在 18:32:51 没动过）。这就是 `addProperty(new DisableConcurrentBuildsJobProperty())` + `save()` 的落点。
- 代理：`active`，`ActiveEnterTimestamp=22:27:21`，日志 `INFO: Connected`、`Remote identity confirmed`。

## 三、第三节（停点 A）：`make` exit=2，Ansible 模板 bug

```text
make -C infrastructure jenkins-release-run APPS="tpl" PIN=keep NOTE="B3 试跑 tpl 到计划为止"
→ release exit=2
```

倒在哪个任务（日志 `/tmp/b3v2-release.log`，Ansible 输出，已按纪律用完删除；内容原样抄在下面）：

```text
TASK [Wait for the build to finish] ********************************************
[ERROR]: Task failed: Error processing keyword 'retries': Error rendering template:
         unsupported operand type(s) for /: '_AnsibleTaggedStr' and 'int'
Origin: /home/zymun/worktrees/fable/k8s/infrastructure/jenkins/agent.yaml:289:11
287           retries: 60
288           delay: 5
289         - name: Wait for the build to finish
              ^ column 11
<<< caused by >>>
Origin: /home/zymun/worktrees/fable/k8s/infrastructure/jenkins/agent.yaml:303:20
301           no_log: true
302           until: not build.json.building
303           retries: '{{ (jenkins_run_timeout_seconds / 15) | int }}'
                       ^ column 20
fatal: [localhost]: FAILED! => {"censored": "the output has been hidden due to the fact that
       'no_log: true' was specified for this result", "changed": false}
PLAY RECAP *********************************************************************
localhost : ok=8 changed=0 unreachable=0 failed=1 skipped=19 rescued=0 ignored=0
make: *** [Makefile:204: jenkins-release-run] Error 2
```

读法：`jenkins_run_timeout_seconds` 到 Jinja 里是字符串（`_AnsibleTaggedStr`），不能直接 `/ 15`；得先 `| int` 再除（或把它在 vars 里写成整数）。这与 `release.groovy` 无关，是 `jenkins/agent.yaml` 第 303 行的模板写法问题。

它前面的任务是过的：`Queue the build` ok、`Wait for the queue item to become a build` 两轮 `FAILED - RETRYING`（59、58 retries left）后 ok——**构建已经排上了**；然后 `Wait for the build to finish` 一进来就炸，所以 Ansible 既没等它、也没去取日志（`infrastructure/.build/jenkins/` 下没有新的 `release-*.log`，只有 b2e 那轮留下的 `render-check-19.log` 等）。

按卡面第 65 行「不是 0：把日志路径与倒在哪个阶段写进回执……不要重跑」——**没有重跑**。

## 四、第三节（停点 B）：构建自己跑起来了，结果 FAILURE

`make` 挂了不等于什么都没发生。查现场：

- 22:29:31 的 `queue.xml` 里有 `hudson.model.Queue_-BuildableItem id=58`，task 是 `ExecutorStepExecution$PlaceholderTask`、`<job>release</job><id>1</id>` → `release #1` 的 `node('host')` 在等执行器。
- 它等的执行器被 `render-check #26` 占着（见第六节）。22:38 那一轮 `#26` 收尾（`duration=689275`），`#1` 随即开跑；22:39 时 log 已 751284 字节、`Finished:` 出现、队列清空。

`release #1` 账面与卡面那 14 行（log 是 Jenkins 自己写的 `/mnt/sunmoon-data/jenkins/home/jobs/release/builds/1/log`，不是 `make` 拉下来的那份——`make` 没跑到取日志；`ha:////…` 身份串已打码，不外抄）：

```text
<timestamp>1792506518729</timestamp>   （= 22:28:38 CST，排队时刻）
<result>FAILURE</result>
<duration>569439</duration>            （约 9.5 分钟）

15:    [Pipeline] { (ci/release.groovy)
23:    [Pipeline] { (1 核对)
13705: [Pipeline] { (2 改钉)
13834: [Pipeline] { (3 构建)
13925: [Pipeline] { (秘密样子核查与产物)
13928: total=0
13934: [Pipeline] { (工作区回到干净)
13946: ERROR: script returned exit code 2
13947: Finished: FAILURE
```

判据逐条：

| 卡面判据 | 结果 |
| --- | --- |
| `release exit=0` | **不符**（exit=2，见停点 A） |
| `Report the build result` 里 `result: SUCCESS` | **没有这一步**（Ansible 在 `Wait for the build to finish` 就 fatal，没走到报告） |
| 七个阶段都进（`1 核对`…`5 计划` + 两个收尾） | **不符**：只进了 `1 核对`、`2 改钉`、`3 构建`，加两个收尾；`4 暂存`、`5 计划` 从未进 |
| `total=0`（秘密样子核查） | 过（第 13928 行） |
| `Finished: SUCCESS` | **不符**（`Finished: FAILURE`） |

### 4.1 倒在哪儿：`3 构建` 里的 backend

```text
TASK [Refuse unreviewed source revisions or dirty checkout] ********************
[ERROR]: Task failed: Action failed: Assertion failed
Origin: /mnt/sunmoon-data/jenkins/repos/k8s/infrastructure/applications/build.yaml:114:7
114     - name: Refuse unreviewed source revisions or dirty checkout
fatal: [localhost]: FAILED! => {"assertion": "build_kind == 'component' or
        source_state.results[0].stdout == component_revision",
        "changed": false, "evaluated_to": false, "msg": "Assertion failed"}
PLAY RECAP *** localhost : ok=4 changed=0 unreachable=0 failed=1 skipped=0 rescued=0 ignored=0
make[2]: *** [Makefile:368: application-build-backend] Error 2
make[1]: *** [Makefile:517: platform-build-selected] Error 2
make: *** [Makefile:514: platform-build] Error 2
```

`changed=0` → **没有任何构建动作执行过**，也就没有镜像被推。旁证：本机 `docker images` 里的 tpl 标签全是 3 天前与 5 天前的（`tpl-backend:ab7139389cbc-2b56d6fc9877`、`tpl-web-frontend:479c7e6ce6e6-3ce104366faf`、`tpl-admin-frontend:b89e47419110-bb2ca13c2631` 等），**没有今天新建的**。

### 4.2 为什么会撞这道闸：`PIN=keep` 与「第 1 阶段检到分支头」互相矛盾

只读取证（都在代理仓，未改任何东西）：

```text
代理仓 /mnt/sunmoon-data/jenkins/repos/tpl-app：
  父仓 HEAD = 2100a56869edcf0cc8e39c2d56652bf49ec1e5bf（detached；fable 与 origin/fable 的头都是 2100a56）
    2100a56 2026-10-18 后端子仓指针：管理角色换算成权限、内部接口只认集群内地址（审读第 1、4 条）
  父仓钉的 gitlink：tpl-backend 497b422d… / tpl-web-frontend 76b50b6c… / tpl-admin-frontend 722c6b80…
  三个子仓实际 HEAD 与上述 gitlink 逐一相同；仓干净（status --short 为空）

k8s 仓 infrastructure/applications/sources.yaml 里 tpl 的钉（= PIN=keep 用的）：
  parent_revision: 65b8b11d3c21717a0c768490e329e5e19e43e020   （2026-10-17）
  backend_revision: ab7139389cbc40a04459a3403ffc5ee4c8e26d89  （2026-10-17）
  web_revision: 479c7e6ce6e69a5e4daf41bb55aed5f3b95a87c7
  admin_revision: b89e474191109d807cdd50d56ecea971c0269a4a
  65b8b11 2026-10-17 rename（0028 R1）：investment → knowbench、runtime 仓 → sunmoon-link
  65b8b11d 是 2100a568 的祖先，两者相差 4 个提交（钉落后于头）
  ab713938 是 497b422d 的祖先（钉落后于 checkout）
```

对上流水线（`ci/release.groovy`）：

```groovy
stage('1 核对') {                       // 第 31–33 行
    for (app in apps) { dir("${reposDir}/${app}-app") {
        sh "git fetch -q origin '+refs/heads/*:refs/remotes/origin/*' \
            && git checkout -q --detach 'origin/${branch}' && git submodule update --init -q" } }
}
stage('2 改钉') {                       // 第 39–43 行
    if (params.PIN == 'heads') { logged('2-pin', "python3 ci/pin-sources.py …") }
    else { echo 'PIN=keep：sources.yaml 按已提交的钉，不改' }
}
stage('3 构建') { … make -C infrastructure platform-build OBJECT=app-platform/${app}-app … }
```

即：**第 1 阶段无条件把应用仓检到 `origin/fable` 的头**，而 `PIN=keep` 明确不改钉，于是第 3 阶段拿「头的修订」去比「钉的修订」，只要钉不等于分支头，`build.yaml:114` 那道闸必挂。tpl 的钉停在 2026-10-17，fable 头已到 2026-10-18，正好撞上。

这不是环境坏、也不是我操作错：闸门本身是对的（拒绝构建未复核的修订），撞它的是 `keep` 的语义与第 1 阶段的检出策略。此前 qwen 线那几张发布卡都是「先把钉改到最新、再构建」，钉与头一致，所以从没暴露。

顺带说明产物名对不上阶段号的原因：`2-plan-tpl.log` 来自第 2 阶段末尾的前置核对（第 47 行 `logged("2-plan-${app}", "make … application-deployment-plan APP=${app}")`），它**过了**（`ok=16 changed=0 failed=0`）——plan 用钉的号只读渲染，不校验 checkout，所以它能过而构建不能过。

候选修法（我只读判断，未动手，交远程定）：

- (a) `PIN=keep` 时，第 1 阶段按 `sources.yaml` 的钉检出（父仓 `parent_revision`、各子仓 `*_revision`），而不是一律检到 `origin/${branch}`；
- (b) 第 3 阶段前加一步「按钉对齐 checkout + `submodule update`」，与 (a) 等价但改动面更小；
- (c) 本卡改用 `PIN=heads`——但它会改 `sources.yaml`，第四节判据「`2-sources.diff` 0 行」就不成立，且「改钉」是发布动作，超出本卡「到计划为止、不动集群」的意图；
- (d) 先把 tpl 的钉在 k8s 仓里更到 fable 头、提交，再用 `keep` 跑——同样是改钉，得所有者/远程决定。

我倾向 (a) 或 (b)：让 `keep` 真的「按已提交的钉构建」，闸门照旧。

## 五、第四节：产物（只读，多数文件不存在，因为阶段没进）

卡面第四节命令的 `n` 取自 `infrastructure/.build/jenkins/release-*.log`，那份日志没生成（停点 A），所以我直接用 `release #1` 的号 `1` 拼出产物目录，其余原样执行：

```text
/mnt/sunmoon-data/jenkins/repos/k8s/infrastructure/.build/release/1
1-platform-status.log
2-plan-tpl.log
2-sources.diff
3-build-tpl.log

2-sources.diff: 0 行（keep 应为 0）           → 符合判据
3-image-locks.txt   → No such file or directory（第 3 阶段末尾那步没跑到）
4-gitops-touched.txt→ No such file or directory（第 4 阶段没进）
4-gitops.stat       → No such file or directory
4-workload.diff     → No such file or directory
代理仓是否干净：clean-check-done 前为空      → 符合判据
```

判据里能核的两条（`2-sources.diff` 0 行、代理仓干净）都过；镜像锁 3 个、`4-gitops-touched.txt` 只有 tpl-app、`4-workload.diff` 含两段 ingress `/api/internal` 这些**无从核**，因为流水线没走到那儿。没有拿别的东西冒充。

我的工位：`git status --short` 为空、HEAD 仍 `0999ea79`。

## 六、副作用与现场净变化（含一处我造成的失败）

**`render-check #26` FAILURE，是我的重启打断的。** log 原文链条：

```text
Started by timer                                          （22:26:00 触发）
+ git fetch -q origin +refs/heads/*:refs/remotes/origin/*
host seems to be removed or offline (hudson.remoting.RequestAbortedException:
  java.nio.channels.ClosedChannelException); will wait for 5 min 0 sec for it to come back online
Pausing (shutting down)
Resuming build at Tue Oct 20 22:27:03 CST 2026 after Jenkins restart
Waiting for reconnection of host before proceeding with build
Ready to run at Tue Oct 20 22:27:22 CST 2026
wrapper script does not seem to be touching the log file in
  /mnt/sunmoon-data/jenkins/repos/k8s@tmp/durable-004d44cb
This may occur if the durable task process was terminated externally…（JENKINS-48300）
ERROR: script returned exit code -1
Finished: FAILURE
账面：<timestamp>1792506360450</timestamp> <result>FAILURE</result> <duration>689275</duration>
```

即：它第一步 `git fetch` 正在代理上跑，我停代理+停控制器把它的 durable task 进程终止了；恢复后 Jenkins 发现 wrapper 不再写日志，判 `exit code -1`。这正是卡面第一节「有就等它结束再往下，重启会打断它」要防的事，只因定时器在扫描后 31 秒才触发而没防住（见第一节第 1 条）。

平台随后自行恢复，不需要人干预：

```text
#25 （重启前最后一次定时）SUCCESS  duration=358532
#26 （被打断那次）        FAILURE  duration=689275
#27 （22:37:29 触发）     SUCCESS  duration=423659   → Finished: SUCCESS
#28 （22:46:00 触发）     正在跑（22:48:42 时 log 192592 字节、仍在长，账面是 duration 0 + SUCCESS 占位）
队列 22:48:42 时为空（BuildableItem 计数 0）
```

其余净变化：

- 控制器与代理各停一次、`jenkins-deploy` 一次（`changed=3`）、代理起一次；两个服务此刻都 `active`，代理 `Connected`。
- home 的 `init.groovy.d/` 四份被覆盖成新版（这是本卡第二节的目的）；`jobs/render-check/config.xml` 被重写（22:27:02，多了并发闸）——**并发闸自此真装上了**。
- `release` job 多了一次构建记录 `#1`（FAILURE），零产物镜像。
- Harbor 没有新镜像；`gitops/`、`infrastructure/applications/sources.yaml` 一字未动；代理仓 `k8s` 与 `tpl-app` 都干净（`tpl-app` 处于 detached `2100a568`，这是第 1 阶段本来就会做的事）。
- 我没有 abort 任何构建（abort 要 crumb 与凭据，卡面禁止），也没有手改 `/opt`、`jenkins_home`、`gitops/` 或任何仓。

## 七、第五节：未做

所有者走查（浏览器看两个任务、`release` 的构建历史、Build Artifacts、Stage View 七列全绿）这次没有可看的成功构建：`release #1` 是 FAILURE、只进了三个 stage，Artifacts 下只有 4 个文件。等修好重跑一次成功再看。`render-check` 照常每 10 分钟一次（`#27` SUCCESS、`#28` 在跑）。

## 八、纪律与清理

- 卡面命令一字未改；只读的补充核对都注明了是我另做的。
- 第三节 exit=2 后**没有重跑**、没有退回、没有手工去补 `sources.yaml` 的钉或手工 checkout 对齐。
- 一次性日志：`/tmp/b3v2-{sec2,agent-stop,stop,deploy,agent-start,status,agent-status,release,sec34}.log` 用完即删（删除后 `ls` 无匹配，见第十节）。
- 不拍屏、不抄任何口令与 crumb；Jenkins log 里的 `ha:////…` 身份串一律打码后再引用。
- 长输出先落 `/tmp` 再切片读，避免终端折行截断。

## 九、给远程的一页

`docs/dev-investment-agent/switch-test/inbox/fable/2026-10-20-fable-b3-v2-two-faults.md`：两条独立故障（`agent.yaml:303` 的 `retries` 模板、`release.groovy` 第 1 阶段检出策略与 `PIN=keep` 冲突）＋两条判据/方法建议（第一节扫活体的写法、重启与定时器之间的窗口）＋ `#26` 被打断的实情。请远程修好后重发第三版卡（从第三节起），我不擅自重跑。

## 十、第六节：回执入库与推回

卡面第六节的命令含 `git mv …inbox/qwen/…-fable-b3-release-to-plan.md …done/`。**我没有移动这张卡**：卡没做完（第三节两个停点、第四节多数产物无从核），与第一版停点时的处置一致（远程当时也保留了卡在 `inbox/qwen/`，只把我那页移进 `done/`）。等第三版卡来了、真跑到 `Finished: SUCCESS` 再移。

实际执行（`git add` 只加真实存在的 `.md`；卡面那条 glob 里 `fable-b3.*.md` 会同时匹配第一版回执，但它已入库未改动，故只会加进本次这一份）：

```bash
cd ~/worktrees/fable/k8s && git pull --ff-only origin fable \
  && git add scripts/results/fable-b3.20261020-2250.md \
             scripts/results/fable-b2e.20261020-213201.md \
             docs/dev-investment-agent/switch-test/inbox/fable/2026-10-20-fable-b3-v2-two-faults.md \
  && git commit -m "fable-b3 第二版停在第三节：agent.yaml retries 模板与 PIN=keep 检出冲突（qwen）" \
  && git push origin fable
```

推回输出原文见下方「推回原文」小节（提交号、两个远端的记号、推后 `git status` 与领先/落后数）。

### 推回原文

（推送后补写）
