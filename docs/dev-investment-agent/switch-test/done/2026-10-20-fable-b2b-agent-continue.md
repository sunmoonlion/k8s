# luna 卡 fable-b2b：接续第 2 步——宿主代理、render-check（从原卡第四节起）

> 状态：**可执行**（远程 Fable 2026-10-20 夜写）。原卡 [fable-b2](../../done/2026-10-20-fable-b2-agent-render-check.md) 第二、三节已过（物料 77 件、控制器带 76 插件、三份首启脚本、节点密钥已写；回执 `scripts/results/fable-b2.20261020-182305.md`），停在第四节 `jenkins-agent-deploy` 的克隆任务：是我剧本里循环项多取了一层（`item.item.stdout`），没执行到克隆。已改；同时发现本地机各仓的 origin 是 https，剧本改成命令级 `insteadOf` 走你第一节探通的 GitHub SSH。物料与控制器不重做。
>
> 原卡第六节的 `curl -sk` 关了证书校验，不对；本卡第三节换成不关校验的验法。

```text
被测仓：k8s；工位 WS=fable（所有者指定）：~/worktrees/fable/k8s，分支 fable；远程和本地都只推拉这个分支
改动（本次）：infrastructure/jenkins/tasks/workspace.yaml（循环项、SSH 改写、对象从本机工位拷）、templates/sunmoon-jenkins-agent.service.j2（SuccessExitStatus=143）、README
会联网的：克隆七个仓（GitHub SSH）、uv 装 .venv、下载工具二进制
停下的规则：任何一步 exit 不是 0 就停，输出原样进回执，不重试、不退回；ssh 用 -n，别放进 heredoc 的 stdin
不碰：控制器（不 stop/deploy）、入口、集群、应用、Harbor 数据；不写库；不替所有者在界面里点
```

## 一、核对与拉取（只读）

```bash
cd ~/worktrees/fable/k8s && git pull --ff-only origin fable && git log --oneline -1 && git status --short | head -3
grep -c "insteadOf" infrastructure/jenkins/tasks/workspace.yaml
make -C infrastructure jenkins-status; echo "status exit=$?"
ssh -n -o BatchMode=yes -o ConnectTimeout=15 -T git@github.com 2>&1 | head -1; echo "ssh exit=$? (1 = ok)"
```

要看到：HEAD 是本卡这次提交或更新；`insteadOf` 计数 3；控制器 `status exit=0`；ssh 那行 `successfully authenticated`。

## 二、宿主代理（接原卡第四节）

先清掉上一轮没克隆完的半截仓（那一轮走 GitHub 只有几十 KB/s，所有者已叫停）。`repos/` 是代理的数据目录，不是人的工位，里面没有人的工作，可以删：

```bash
bash <<'SH'
ls -la /mnt/sunmoon-data/jenkins/repos
for d in /mnt/sunmoon-data/jenkins/repos/*/; do [ -d "$d" ] && sudo -n -u zymun rm -rf "$d"; done
ls -A /mnt/sunmoon-data/jenkins/repos | wc -l
SH
```

要看到：最后一行 `0`。

这次克隆不再从 GitHub 拉历史：对象从你工位 `~/worktrees/fable/<仓>` 的对象库拷（本机盘对盘，秒级），拷完断开，GitHub 只补工位里没有的新提交。七个仓加九个子仓一两分钟内该克隆完；要是又卡在克隆几分钟不动，停下，把 `ps -o pid,etime,args -u zymun | grep 'git '` 的输出（没有口令）贴进回执。

```bash
make -C infrastructure jenkins-agent-plan; echo "plan exit=$?"
make -C infrastructure jenkins-agent-deploy; echo "deploy exit=$?"
make -C infrastructure jenkins-agent-status; echo "status exit=$?"
bash <<'SH'
systemctl show sunmoon-jenkins-agent.service --property=ActiveState,UnitFileState,User,WantedBy | cat
ls /mnt/sunmoon-data/jenkins/repos
ls -d /mnt/sunmoon-data/jenkins/repos/k8s/infrastructure/.venv /mnt/sunmoon-data/jenkins/repos/k8s/infrastructure/.tools/bin
git -C /mnt/sunmoon-data/jenkins/repos/knowbench-app submodule status | cut -c1-60
SH
```

要看到：deploy 退出 0（克隆一两分钟，装 .venv 与工具要联网下载，几分钟到十来分钟）；`ActiveState=active`、`UnitFileState=enabled`、`User=zymun`、`WantedBy=sunmoon-platform.target`；`repos` 下七个目录；`.venv`、`.tools/bin` 在；knowbench 的三个子仓有提交号（不是 `-` 开头）。

deploy 不是 0：贴失败任务那段与 `journalctl -u sunmoon-jenkins-agent.service --since '20 min ago' | tail -40`（没有口令）。

## 三、真跑一次 render-check

```bash
make -C infrastructure jenkins-agent-check; echo "check exit=$?"
bash <<'SH'
ls -t infrastructure/.build/jenkins/ | head -2
tail -n 40 "$(ls -t infrastructure/.build/jenkins/render-check-*.log | head -1)"
SH
```

要看到：`check exit=0`，结果 `SUCCESS`（六个应用的迁移头核对与渲染都过，几分钟到十几分钟）。日志尾部贴进回执（没有口令）。不是 0：日志路径写进回执，日志留在 `.build/`，不进 git。

## 四、边缘与总状态（不关证书校验）

```bash
bash <<'SH'
ip=$(grep -E '^edge_public_ip:' infrastructure/edge/config.yaml | awk '{print $2}')
echo | openssl s_client -servername jenkins.sunmoonai.com -connect "$ip:30443" 2>/dev/null | openssl x509 -noout -subject -issuer
curl -sS -o /dev/null -w "edge jenkins %{http_code}\n" --resolve "jenkins.sunmoonai.com:30443:$ip" https://jenkins.sunmoonai.com:30443/ ; echo "curl exit=$? (60 = 边缘没有这个域名的证书，正常)"
SH
make -C infrastructure platform-status; echo "status exit=$?"
```

要看到：证书主题不是 `jenkins.sunmoonai.com`（Traefik 默认自签，`TRAEFIK DEFAULT CERT`）；curl 退出 60；platform-status 退出 0，清单里多了 `sunmoon-jenkins-agent.service active enabled`。要是证书主题是 jenkins.sunmoonai.com 且回 200，那是泄露，停下报告。

## 五、所有者走查（不急）

浏览器开 Jenkins（前置：本机 hosts 已有 `jenkins.sunmoonai.com`，你上次加过了）：「节点」里 `host` 在线、执行器 1；任务 `render-check` 有一次成功构建，产物 `diff.txt`；「插件」里 76 个。

## 六、回执与推回

`scripts/results/fable-b2b.<时间>.md`：每节命令与 exit、第二节四行、第三节日志尾部、第四节三行、停在哪（若有）。不拍、不抄任何口令。

```bash
cd ~/worktrees/fable/k8s && git pull --ff-only origin fable && git add scripts/results/fable-b2b.*.md scripts/results/fable-b2b.*.txt && git mv docs/dev-investment-agent/switch-test/inbox/luna/2026-10-20-fable-b2b-agent-continue.md docs/dev-investment-agent/switch-test/done/ && git commit -m "fable-b2b 回执：宿主代理与 render-check 接续（luna）" && git push origin fable; echo "push exit=$?"
```

拉不下来（非快进）或推不上去就停下，把输出告诉所有者，不强推。
