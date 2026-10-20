# luna 卡 fable-b2d：接续第 2 步——真跑 render-check、边缘、总状态（从 b2c 第三节起）

> 状态：**可执行**（远程 Fable 2026-10-20 夜写，第四版）。b2c 回执 `scripts/results/fable-b2c.20261020-191232.md`：代理部署整节通过（七父仓、18 子仓、工具、代理单元 active/enabled、节点在线）。第三节 `jenkins-agent-check` 提交构建回 400：**是我剧本的错**——Ansible 不模板化字典的键，`headers: {'{{ crumb.json.crumbRequestField }}': …}` 把头名原样带着花括号发了出去，HAProxy 边车按非法头名回 `400 Bad request`（小写 r 是 HAProxy 的错误页，Jetty 写 Bad Request；远程这边用同版 Ansible 复现了「键不模板化」）。已改成一个表达式算整个 headers。
>
> 同时发现定时触发的构建会在 node() 里排队（代理只有一个执行器，#1 在跑，#2–#5 都已开始挂着等）。给任务加了「同时只跑一个」属性，但它在控制器首启脚本里，**要等控制器重启才生效，本卡不重启控制器**（B3 改单元时一起）。这轮里排队的几个定时构建在 #1 结束后会一个个很快结束为 NOT_BUILT（分支头没变），是预期的。

```text
被测仓：k8s；工位 WS=fable：~/worktrees/fable/k8s，分支 fable；远程和本地都只推拉这个分支
改动（本次）：infrastructure/jenkins/agent.yaml（crumb 头的拼法）、templates/03-render-check.groovy.j2（同时只跑一个；重启后才生效）
会联网的：render-check 里各应用仓 git fetch（走 SSH）
停下的规则：任何一步 exit 不是 0 就停，输出原样进回执，不重试、不退回；ssh 用 -n
不碰：控制器（不 stop/deploy/重启）、代理单元（不重装）、入口、集群、应用、Harbor 数据；不写库；不替所有者在界面里点；不读、不抄口令与 crumb
```

## 一、核对与拉取（只读）

```bash
cd ~/worktrees/fable/k8s && git pull --ff-only origin fable && git log --oneline -1 && git status --short | head -3
grep -n "combine({'Cookie'" infrastructure/jenkins/agent.yaml | cut -c1-60
make -C infrastructure jenkins-status; echo "status exit=$?"
make -C infrastructure jenkins-agent-status; echo "agent status exit=$?"
```

要看到：HEAD 是本卡这次提交或更新；grep 有一行；两个 status 都是 0。

## 二、定时 #1 跑完了吗（只读，看持久化的元数据，不发请求）

```bash
bash <<'SH'
for n in 1 2 3 4 5 6 7 8; do
  f=/mnt/sunmoon-data/jenkins/home/jobs/render-check/builds/$n/build.xml
  [ -f "$f" ] || continue
  printf '#%s ' "$n"; sudo -n grep -o -E '<(result|duration|displayName)>[^<]*</(result|duration|displayName)>' "$f" | tr '\n' ' '; echo
done
SH
```

要看到：#1 有 `<result>`（SUCCESS 是正常；FAILURE 也先记下，继续第三节——第三节的强制跑会给出完整控制台）。还有构建没 `<result>` 就是还在跑或在排队：等到 #1 有结果再做第三节（它会占着唯一的执行器）。#1 的 duration（毫秒）记进回执，B3 要用它定超时。

## 三、真跑一次 render-check（强制）

```bash
make -C infrastructure jenkins-agent-check; echo "check exit=$?"
bash <<'SH'
ls -t infrastructure/.build/jenkins/render-check-*.log | head -1
tail -n 40 "$(ls -t infrastructure/.build/jenkins/render-check-*.log | head -1)"
SH
```

要看到：`check exit=0`，剧本末尾 `Report the build result` 一行里 `result: SUCCESS`（排在前面的定时构建先各自很快结束，然后才轮到它；剧本最多等 40 分钟）。日志尾部贴进回执（没有口令）。不是 0：日志路径写进回执，日志留在 `.build/`，不进 git。

## 四、边缘（不关证书校验）

```bash
bash <<'SH'
ip=$(grep -E '^edge_public_ip:' infrastructure/edge/config.yaml | awk '{print $2}')
echo | openssl s_client -servername jenkins.sunmoonai.com -connect "$ip:30443" 2>/dev/null | openssl x509 -noout -subject -issuer
curl -sS -o /dev/null -w "edge jenkins %{http_code}\n" --resolve "jenkins.sunmoonai.com:30443:$ip" https://jenkins.sunmoonai.com:30443/ ; echo "curl exit=$? (60 = 边缘没有这个域名的证书，正常)"
SH
```

要看到：证书主题不是 `jenkins.sunmoonai.com`（Traefik 默认自签）；curl 退出 60。要是证书主题是 jenkins.sunmoonai.com 且回 200，那是泄露，停下报告。

## 五、总状态

```bash
make -C infrastructure platform-status; echo "status exit=$?"
```

要看到：退出 0，清单里有 `sunmoon-jenkins.service` 和 `sunmoon-jenkins-agent.service`，都 active enabled。

## 六、所有者走查（不急）

浏览器开 Jenkins（本机 hosts 已有 `jenkins.sunmoonai.com`）：「节点」里 `host` 在线、执行器 1；任务 `render-check` 的构建历史里有定时的几次（NOT_BUILT 灰色是正常）和第三节这次 SUCCESS，产物 `diff.txt`；「插件」里 76 个。

## 七、回执与推回

`scripts/results/fable-b2d.<时间>.md`：每节命令与 exit、第二节各构建的结果与 #1 的 duration、第三节日志尾部、第四节三行、第五节清单里 Jenkins 的两行、停在哪（若有）。不拍、不抄任何口令与 crumb。

```bash
cd ~/worktrees/fable/k8s && git pull --ff-only origin fable && git add scripts/results/fable-b2d.*.md scripts/results/fable-b2d.*.txt && git mv docs/dev-investment-agent/switch-test/inbox/luna/2026-10-20-fable-b2d-render-check.md docs/dev-investment-agent/switch-test/done/ && git commit -m "fable-b2d 回执：render-check 真跑、边缘、总状态（luna）" && git push origin fable; echo "push exit=$?"
```

拉不下来（非快进）或推不上去就停下，把输出告诉所有者，不强推。
