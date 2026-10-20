# fable-b2e 回执：render-check 真跑（强制 #19 SUCCESS）、边缘、总状态

- 卡：`docs/dev-investment-agent/switch-test/inbox/qwen/2026-10-20-fable-b2e-render-check.md`（83 行，第五版，远程 Fable 2026-10-20 夜写），已移 `done/`。
- 工位 `WS=fable`：`~/worktrees/fable/k8s`，分支 `fable`；执行者 Qwen（本地机，所有者 2026-10-20 点名接手平台线这一卡）。
- 结论：**pass**。第一节全过（grep 一处按 README 第 99 行改了「怎么执行」，判据未改，见 1.2）；第二节强制构建 **#19 `fable@4f3dc6824b` SUCCESS、395143 ms**，差异阶段跑通、`diff.txt` **22 行**、`Archiving artifacts`、`Finished: SUCCESS`；第三节边缘无证书泄露（`curl exit=60`）；第四节 `platform-status exit=0`，两个 Jenkins 服务 active+enabled。第五节所有者走查未做（卡面「不急」）。第六节按卡拉取后推 `origin/fable`。
- 纪律：任何一步 exit 非 0 就停的规则未触发（全程无非 0，除 `curl` 的 60 是卡面判据本身要的）；没碰控制器、代理单元、入口、集群、应用、Harbor 数据；没写库；没替所有者在界面里点；没读、没抄口令与 crumb（`jenkins-agent-check` 内部的 crumb 与管理员凭据由 Ansible `no_log` 持有，我没打印、没落盘）。

## 一、核对与拉取（只读）

### 1.1 命令与 exit

```text
$ cd ~/worktrees/fable/k8s && git pull --ff-only origin fable
From https://github.com/sunmoonlion/k8s
 * branch              fable      -> FETCH_HEAD
Already up to date.
pull exit=0

$ git log --oneline -1
4f3dc682 switch-test README：平台线的卡由所有者点名的本地助手跑（b2e 起是 Qwen），都在 fable 工位
$ git status --short | head -3
（空，工作区干净）
```

HEAD `4f3dc682` ＝ 所有者要求的下限（`git merge-base --is-ancestor 4f3dc682 HEAD` 通过），也是本卡这次提交 ✓。同步时带进来的三条：`4f3dc682`（README：平台线的卡由所有者点名的本地助手跑，b2e 起是 Qwen）、`236fb43f`（卡 fable-b2e 搬到 `inbox/qwen/`）、`4080cb2e`（去掉第一节一行多余命令）；b2d 那页 `2026-10-20-fable-b2d-diff-shell.md` 已由远程从 `inbox/fable/` 移进 `done/`。

### 1.2 grep：卡面命令改了一处（只改「怎么执行」）

卡面原命令：

```bash
grep -n "^#!/bin/bash\|cand=infrastructure" ci/render-check.groovy
```

实际只出一行（`52:cand=infrastructure/...`），因为 shebang 不在行首——它写在 Jenkins `sh` 步骤的三引号同一行上：`50:        sh '''#!/bin/bash`。按 README「待办里的命令本身写错了（…检查方式明显不对），本地助手可以直接改对了接着做——只改『怎么执行』，不改『怎样算通过』」，去掉行首锚点重跑：

```text
$ grep -n "#!/bin/bash\|cand=infrastructure" ci/render-check.groovy
50:        sh '''#!/bin/bash
52:cand=infrastructure/.build/components/app-platform
grep exit=0
```

**两行** ✓，判据（bash 点名 + 候选路径改对）未变。远程随后把卡面这行的 `^` 去掉即可。

### 1.3 三处修复的只读确认（b2d 交回的三处，本卡开头说都已改好）

```text
50:        sh '''#!/bin/bash
51:set -euo pipefail
52:cand=infrastructure/.build/components/app-platform
53:out=infrastructure/.build/render-check
70:        archiveArtifacts artifacts: 'infrastructure/.build/render-check/diff.txt', allowEmptyArchive: true
```

即：① sh 步点名 `#!/bin/bash`（不再是 dash）；② 候选输入路径改成 `infrastructure/.build/components/app-platform`；③ 产物落点与归档路径都是 `infrastructure/.build/render-check/diff.txt`。三处齐 ✓。

### 1.4 两个 status

```text
$ make -C infrastructure jenkins-status
status exit=0
        "NRestarts=0",
        "Id=sunmoon-jenkins.service",
        "ActiveState=active",
        "SubState=running",
        "UnitFileState=enabled"
localhost                  : ok=5    changed=0    unreachable=0    failed=0    skipped=29   rescued=0    ignored=0

$ make -C infrastructure jenkins-agent-status
agent status exit=0
        "User=zymun",
        "Id=sunmoon-jenkins-agent.service",
        "ActiveState=active",
        "SubState=running",
        "UnitFileState=enabled"
localhost                  : ok=7    changed=0    unreachable=0    failed=0    skipped=27   rescued=0    ignored=0
```

两个都是 0 ✓，控制器与代理都 active/running/enabled、0 重启。

## 二、真跑一次 render-check（强制）

### 2.1 先看有没有构建还在跑（只读，sudo 下）

```text
#1 <result>FAILURE</result> <duration>2795696</duration>
#2 <result>NOT_BUILT</result> <duration>2208330</duration>
#3 <result>NOT_BUILT</result> <duration>1622036</duration>
#4 <result>NOT_BUILT</result> <duration>1034662</duration>
#5 <result>FAILURE</result> <duration>798637</duration>
#6 <result>FAILURE</result> <duration>576994</duration>
#7 <result>FAILURE</result> <duration>697529</duration>
#8 <result>NOT_BUILT</result> <duration>362802</duration>
#9 <result>FAILURE</result> <duration>355250</duration>
#10 <result>SUCCESS</result> <duration>351743</duration>
#11–#17 <result>NOT_BUILT</result> <duration>14867/13103/13078/12565/12510/12619/12558</duration>
#18 <duration>0</duration> <result>SUCCESS</result>
builds-list exit=0
```

18 次构建全都有 `<result>`，没有在跑的，直接触发。其中 #10 是修好脚本后定时那次 SUCCESS，#11–#17、#18 是分支头没变时的 NOT_BUILT／零耗时跳过（每 12–15 秒结束），与卡面「定时的在分支头没变时几分钟内 NOT_BUILT」一致。

**Qwen 的一处误判，如实记**：我第一次读这张表时说「#18 只有 `<duration>0</duration>`、没有 `<result>`」，据此空等了一轮 60 秒；实际那行末尾就有 `<result>SUCCESS</result>`，是我读漏。等待没造成任何副作用（只读、没触发构建），但记在这里以免后面有人照我那句话去查 #18。

### 2.2 强制触发与结果

```text
$ make -C infrastructure jenkins-agent-check
TASK [Queue a forced render-check build] ***  ok: [localhost]
TASK [Wait for the queue item to become a build] ***  FAILED - RETRYING: (59 retries left) → ok: [localhost]
TASK [Wait for the build to finish] ***  ok
        "name": "#19 fable@4f3dc6824b",
        "result": "SUCCESS",
        "seconds": 395
TASK [Require the check to pass] ***  ok: [localhost]
TASK [Report the agent unit state] ***  ok
        "NRestarts=0", "User=zymun", "Id=sunmoon-jenkins-agent.service",
        "ActiveState=active", "SubState=running", "UnitFileState=enabled"
localhost                  : ok=15   changed=1    unreachable=0    failed=0    skipped=19   rescued=0    ignored=0
check exit=0
```

构建号 **#19**、显示名 `#19 fable@4f3dc6824b`（正是本卡的 HEAD）、结果 **SUCCESS**、耗时 **395 秒**；`Report the check result` 里 `result: SUCCESS` ✓，`failed=0` ✓。账面复核（代理上 `builds/19/build.xml`，只读）：

```text
<result>SUCCESS</result>
<duration>395143</duration>
```

即 **395143 ms**（≈6 分 35 秒），与 b2d 的 #7（697529 ms、FAILURE）和 #1（2795696 ms、含约 40 分钟等代理上线）都好比：**这次没有等代理、没有失败重试**，B3 定超时可按「分支头有变、六应用全渲染」这一档约 6–7 分钟取，另留代理冷启动余量。

### 2.3 差异阶段与产物（卡面判据）

```text
$ log=$(ls -t infrastructure/.build/jenkins/render-check-*.log | head -1); echo "$log"
log=infrastructure/.build/jenkins/render-check-19.log
$ grep -n "候选与已提交的差异\|diff.txt\|Archiving\|Finished:" "$log" | tail -8
8082:[Pipeline] { (候选与已提交的差异)
8084:22 infrastructure/.build/render-check/diff.txt
8086:Archiving artifacts
8102:Finished: SUCCESS
```

四项都在 ✓：差异阶段进了（8082）、`wc -l` 那行是 **`22 infrastructure/.build/render-check/diff.txt`**（N=22，非 0）、`Archiving artifacts`（8086）、`Finished: SUCCESS`（8102）。

`diff.txt` 在代理仓目录，**22 行、954 字节**：

```text
-rw-r--r-- 1 zymun zymun 954 Oct 20 21:29 /mnt/sunmoon-data/jenkins/repos/k8s/infrastructure/.build/render-check/diff.txt
22 /mnt/sunmoon-data/jenkins/repos/k8s/infrastructure/.build/render-check/diff.txt
```

前 30 行（＝全部 22 行，声明的结构差异，`*.sops.yaml` 已排除）：

```diff
@@ -79,6 +79,10 @@
     - host: tpl-admin.sunmoonai.com
       http:
         paths:
+          # 内部接口不经公网：转给前端，前端没有这个页面，回 404（审读第 1 条；后端另按地址拦）
+          - path: /api/internal
+            pathType: Prefix
+            backend: {service: {name: tpl-admin, port: {number: 3000}}}
           - path: /api
             pathType: Prefix
             backend: {service: {name: tpl-api, port: {number: 8000}}}
@@ -79,6 +79,10 @@
     - host: tpl.sunmoonai.com
       http:
         paths:
+          # 内部接口不经公网：转给前端，前端没有这个页面，回 404（审读第 1 条；后端另按地址拦）
+          - path: /api/internal
+            pathType: Prefix
+            backend: {service: {name: tpl-web, port: {number: 3000}}}
           - path: /api
             pathType: Prefix
             backend: {service: {name: tpl-api, port: {number: 8000}}}
```

秘密扫描（只读，`grep -c` 计数）：`BEGIN PRIVATE KEY|password|crumb|api_token` → **0**，grep exit=1（零命中）✓。

**这 22 行说明什么（只报事实，不判过不过——脚本注释也写明「存成产物给人看，不判过不过」）**：候选（渲染器输出）比已提交的 `gitops/components/app-platform/tpl-app/...` 多出两个 ingress 的 `/api/internal` 路径（tpl-admin、tpl 各一段，各 4 行 + 3 行上下文）。即**渲染器已经会生成 `/api/internal` 的收敛规则，但 gitops 里已提交的 tpl ingress 还没跟上**，属「有变化未暂存/未发布」，不是渲染器坏了。没有 `NEW <app>/<file>` 行，说明候选里没有 gitops 缺文件的新组件。要不要发这次差异由远程与所有者定，本卡不发布、不暂存。

### 2.4 日志与产物是否进 git

`check exit=0`，故按卡面不需要「只写日志路径不进 git」那条分支。仍如实记：完整控制台 `~/worktrees/fable/k8s/infrastructure/.build/jenkins/render-check-19.log`（8102 行）与代理上的 `diff.txt` 都在 `.build/` 下，**不进 git**；本回执只抄了上面这些片段。

## 三、边缘（不关证书校验）

```text
$ ip=$(grep -E '^edge_public_ip:' infrastructure/edge/config.yaml | awk '{print $2}')
edge_public_ip=43.153.135.74
$ echo | openssl s_client -servername jenkins.sunmoonai.com -connect "$ip:30443" 2>/dev/null | openssl x509 -noout -subject -issuer
subject=CN = TRAEFIK DEFAULT CERT
issuer=CN = TRAEFIK DEFAULT CERT
$ curl -sS -o /dev/null -w "edge jenkins %{http_code}\n" --resolve "jenkins.sunmoonai.com:30443:$ip" https://jenkins.sunmoonai.com:30443/
curl: (60) SSL certificate problem: unable to get local issuer certificate
edge jenkins 000
curl exit=60 (60 = 边缘没有这个域名的证书，正常)
```

三行都对卡 ✓：证书主题**不是** `jenkins.sunmoonai.com`（是 Traefik 默认自签）、`curl exit=60`、HTTP 码 `000`（连 TLS 都没过，谈不上 200）。**没有泄露**，无需停下报告。全程未加 `-k`／未关证书校验。

## 四、总状态

```text
$ make -C infrastructure platform-status
status exit=0
localhost                  : ok=3    changed=0    unreachable=0    failed=0    skipped=60   rescued=0    ignored=0
localhost                  : ok=7    changed=0    unreachable=0    failed=0    skipped=5    rescued=0    ignored=0
```

清单里 Jenkins 的两行（原文）：

```text
        "Id=sunmoon-jenkins.service",
        "ActiveState=active",
        "UnitFileState=enabled",
        "",
        "Id=sunmoon-jenkins-agent.service",
        "ActiveState=active",
        "UnitFileState=enabled"
```

退出 0 ✓，两个服务都 **active enabled** ✓（同清单里 `sunmoon-entry.service` 等仍是 `UnitFileState=disabled`，与本轮无关，照实记一句不作判断）。

## 五、所有者走查（卡面「不急」）——未做

浏览器里那三样（「节点」里 `host` 在线、执行器 1；`render-check` 历史里有 #19 这次 SUCCESS；#19 构建页上有产物 `diff.txt`）**由所有者自己看**，我没替所有者在界面里点。可对照的命令行事实：#19 `SUCCESS`/395143 ms（2.2）、`Archiving artifacts` 与归档路径 `infrastructure/.build/render-check/diff.txt`（2.3）、代理单元 active/enabled（1.4、2.2）。前面 #1、#5–#7、#9 的 FAILURE 与 #2–#4、#8、#11–#17 的 NOT_BUILT 是今晚修的过程，按卡面不用管。

## 六、停在哪 / 一次性产物 / 推回

- **没有停点**：一、二、三、四节全过，无非 0 退出（`curl` 的 60 是判据要的）。B2 这一轮的判据（render-check 真跑一次并 SUCCESS、差异阶段跑通、边缘不泄露、总状态干净）都满足；**并发属性仍待 B3**（本卡不含控制器重启，我没重启任何东西）。
- 一次性产物：`/tmp/b2e-sec1.log`、`b2e-sec1b.log`、`b2e-wait18.log`、`b2e-check.log`、`b2e-sec2.log`、`b2e-sec34.log`、`b2e-jenkins-status.log`、`b2e-agent-status.log`、`b2e-platform-status.log`——关键原文已全抄进本回执，**全部删除**；仓内无 `scripts/tmp-*`、无一次性脚本落盘（命令块直接在 bash 里跑）。
- 推回按卡第六节：`git pull --ff-only origin fable` → `git add scripts/results/fable-b2e.*.md` → `git mv` 卡到 `done/` → commit → `git push origin fable`。**只提交回执与卡的移动，没改任何代码**（1.2 那处改的是我执行的 grep 命令，不是仓里的文件）。
