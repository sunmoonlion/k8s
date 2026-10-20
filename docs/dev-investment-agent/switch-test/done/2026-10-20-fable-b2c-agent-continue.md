# luna 卡 fable-b2c：接续第 2 步——子仓、工具、代理单元、render-check（从 b2b 第二节 deploy 起）

> 状态：**可执行**（远程 Fable 2026-10-20 夜写，第三版）。b2b 回执 `scripts/results/fable-b2b.20261020-184120.md`：半截仓已清，七个父仓从本机工位拷对象一分钟内克隆成功、无 alternates；停在子仓：我的剧本（1）剥子仓名的正则没生效，（2）按父仓 `modules/<名>` 推导子仓对象库的位置不对——工位是 linked worktree，子仓对象库在 `<common>/worktrees/<名>/modules/<子仓>`。已改成问源工位里每个子仓自己的 `git-common-dir`，源工位没检出的子仓就只从 GitHub 拉；不再用正则。远程这边在同样的 worktree 布局上排练过：父仓 2 秒、每个子仓 4 秒内、拷完没有 alternates。物料、控制器、七个父仓都不重做（deploy 对已存在的父仓只 fetch）。18 个子仓，上版写九个是我的笔误。
>
> 原卡第六节的 `curl -sk` 关了证书校验，不对；本卡第四节用不关校验的验法。

```text
被测仓：k8s；工位 WS=fable（所有者指定）：~/worktrees/fable/k8s，分支 fable；远程和本地都只推拉这个分支
改动（本次）：infrastructure/jenkins/tasks/workspace.yaml（子仓对象库按源子仓自己的 git-common-dir 定位）、templates/sunmoon-jenkins-agent.service.j2（SuccessExitStatus=143）、README
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

要看到：HEAD 是本卡这次提交或更新；`insteadOf` 计数 5（两处注释、克隆、取回、子仓）；控制器 `status exit=0`；ssh 那行 `successfully authenticated`。

## 二、宿主代理（接原卡第四节）

父仓已在（b2b 做的），这轮 deploy 对它们只 fetch，然后检出 18 个子仓（每个几秒）、装 `.venv` 与工具、写代理单元。

```bash
make -C infrastructure jenkins-agent-plan; echo "plan exit=$?"
make -C infrastructure jenkins-agent-deploy; echo "deploy exit=$?"
make -C infrastructure jenkins-agent-status; echo "status exit=$?"
bash <<'SH'
systemctl show sunmoon-jenkins-agent.service --property=ActiveState,UnitFileState,User,WantedBy | cat
ls /mnt/sunmoon-data/jenkins/repos
ls -d /mnt/sunmoon-data/jenkins/repos/k8s/infrastructure/.venv /mnt/sunmoon-data/jenkins/repos/k8s/infrastructure/.tools/bin
git -C /mnt/sunmoon-data/jenkins/repos/knowbench-app submodule status | cut -c1-60
find /mnt/sunmoon-data/jenkins/repos -name alternates | wc -l
SH
```

要看到：deploy 退出 0（子仓一两分钟，装 .venv 与工具要联网下载，几分钟到十来分钟）；`ActiveState=active`、`UnitFileState=enabled`、`User=zymun`、`WantedBy=sunmoon-platform.target`；`repos` 下七个目录；`.venv`、`.tools/bin` 在；knowbench 的三个子仓有提交号（不是 `-` 开头）；最后一行 `0`（没有 alternates）。

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

`scripts/results/fable-b2c.<时间>.md`：每节命令与 exit、第二节四行、第三节日志尾部、第四节三行、停在哪（若有）。不拍、不抄任何口令。

```bash
cd ~/worktrees/fable/k8s && git pull --ff-only origin fable && git add scripts/results/fable-b2c.*.md scripts/results/fable-b2c.*.txt && git mv docs/dev-investment-agent/switch-test/inbox/luna/2026-10-20-fable-b2c-agent-continue.md docs/dev-investment-agent/switch-test/done/ && git commit -m "fable-b2c 回执：子仓、代理单元与 render-check 接续（luna）" && git push origin fable; echo "push exit=$?"
```

拉不下来（非快进）或推不上去就停下，把输出告诉所有者，不强推。
