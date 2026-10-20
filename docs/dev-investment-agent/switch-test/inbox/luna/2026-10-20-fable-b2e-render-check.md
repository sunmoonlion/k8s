# luna 卡 fable-b2e：接续第 2 步——再跑 render-check、边缘、总状态（从 b2d 第三节起）

> 状态：**可执行**（远程 Fable 2026-10-20 夜写，第五版）。b2d 回执 `scripts/results/fable-b2d.20261020-192854.md`：手动触发已通（400 没再出现），强制 #7 把六个应用的迁移头核对和渲染都走完（12 份 recap failed=0），停在最后的差异阶段——**两处都是我 `ci/render-check.groovy` 的错**：（1）sh 步默认 /bin/sh，本机是 dash，不认 `set -o pipefail`；现在脚本第一行点名 `#!/bin/bash`。（2）候选路径写成了仓根的 `.build/`，实际渲染器写在 `infrastructure/.build/components/`（和 `gitops/components/` 同形）；已改，产物也放 `infrastructure/.build/render-check/diff.txt`。远程这边把这段 shell 在假目录上排练过：dash 下复现原错，bash 下出差异与 NEW 行。
>
> 任务体在仓里，代理每次构建先把 k8s 更新到分支头再 load，所以**不用重启、不用重装**任何东西，直接再触发一次就是新脚本。

```text
被测仓：k8s；工位 WS=fable：~/worktrees/fable/k8s，分支 fable；远程和本地都只推拉这个分支
改动（本次）：ci/render-check.groovy（差异阶段：bash、候选路径、产物路径）
会联网的：render-check 里各应用仓 git fetch（走 SSH）
停下的规则：任何一步 exit 不是 0 就停，输出原样进回执，不重试、不退回
不碰：控制器、代理单元、入口、集群、应用、Harbor 数据；不写库；不替所有者在界面里点；不读、不抄口令与 crumb
```

## 一、核对与拉取（只读）

```bash
cd ~/worktrees/fable/k8s && git pull --ff-only origin fable && git log --oneline -1 && git status --short | head -3
grep -n "^#!/bin/bash\|cand=infrastructure" ci/render-check.groovy
make -C infrastructure jenkins-status; echo "status exit=$?"
make -C infrastructure jenkins-agent-status; echo "agent status exit=$?"
```

要看到：HEAD 是本卡这次提交或更新；grep 两行；两个 status 都是 0。

## 二、真跑一次 render-check（强制）

先只读看一眼有没有构建还在跑（和上卡第二节一样，整段在 sudo 下）：

```bash
sudo -n bash <<'SH'
for f in /mnt/sunmoon-data/jenkins/home/jobs/render-check/builds/*/build.xml; do
  n=$(basename "$(dirname "$f")"); printf '#%s ' "$n"; grep -o -E '<(result|duration)>[^<]*</(result|duration)>' "$f" | tr '\n' ' '; echo
done
SH
```

有构建没 `<result>` 就等它结束（定时的在分支头没变时几分钟内 NOT_BUILT）。然后：

```bash
make -C infrastructure jenkins-agent-check; echo "check exit=$?"
bash <<'SH'
log=$(ls -t infrastructure/.build/jenkins/render-check-*.log | head -1); echo "$log"
grep -n "候选与已提交的差异\|diff.txt\|Archiving\|Finished:" "$log" | tail -8
SH
```

要看到：`check exit=0`，`Report the build result` 里 `result: SUCCESS`；日志里差异阶段有 `N infrastructure/.build/render-check/diff.txt` 一行（N 可以是 0）、`Archiving artifacts`、`Finished: SUCCESS`。把 `diff.txt` 的行数记进回执；它在代理的仓目录 `/mnt/sunmoon-data/jenkins/repos/k8s/infrastructure/.build/render-check/diff.txt`，前 30 行贴进回执（是声明的结构差异，不含秘密；`*.sops.yaml` 已排除）。不是 0：日志路径写进回执，不进 git。

## 三、边缘（不关证书校验）

```bash
bash <<'SH'
ip=$(grep -E '^edge_public_ip:' infrastructure/edge/config.yaml | awk '{print $2}')
echo | openssl s_client -servername jenkins.sunmoonai.com -connect "$ip:30443" 2>/dev/null | openssl x509 -noout -subject -issuer
curl -sS -o /dev/null -w "edge jenkins %{http_code}\n" --resolve "jenkins.sunmoonai.com:30443:$ip" https://jenkins.sunmoonai.com:30443/ ; echo "curl exit=$? (60 = 边缘没有这个域名的证书，正常)"
SH
```

要看到：证书主题不是 `jenkins.sunmoonai.com`（Traefik 默认自签）；curl 退出 60。证书主题是 jenkins.sunmoonai.com 且回 200 才是泄露，停下报告。

## 四、总状态

```bash
make -C infrastructure platform-status; echo "status exit=$?"
```

要看到：退出 0，清单里 `sunmoon-jenkins.service` 和 `sunmoon-jenkins-agent.service` 都 active enabled。

## 五、所有者走查（不急）

浏览器开 Jenkins：「节点」里 `host` 在线、执行器 1；`render-check` 的构建历史里有第二节这次 SUCCESS，构建页上有产物 `diff.txt`；前面几次 FAILURE/NOT_BUILT 是今晚修的过程，不用管。

## 六、回执与推回

`scripts/results/fable-b2e.<时间>.md`：每节命令与 exit、第二节的构建号、结果、耗时（ms）、diff.txt 行数与前 30 行、第三节三行、第四节清单里 Jenkins 的两行、停在哪（若有）。不拍、不抄任何口令与 crumb。

```bash
cd ~/worktrees/fable/k8s && git pull --ff-only origin fable && git add scripts/results/fable-b2e.*.md scripts/results/fable-b2e.*.txt && git mv docs/dev-investment-agent/switch-test/inbox/luna/2026-10-20-fable-b2e-render-check.md docs/dev-investment-agent/switch-test/done/ && git commit -m "fable-b2e 回执：render-check 真跑、边缘、总状态（luna）" && git push origin fable; echo "push exit=$?"
```

拉不下来（非快进）或推不上去就停下，把输出告诉所有者，不强推。
