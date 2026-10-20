# luna 卡 fable-b2：宿主代理、插件、只读 render-check（0033 B 段第 2 步）

> 状态：**可执行**（远程 Fable 2026-10-20 晚写）。设计 [0033](../../../tree-build/SDD/modules/0033-jenkins-on-host.md) 第八节第 2 步，手册 [`infrastructure/jenkins/README.md`](../../../../../infrastructure/jenkins/README.md)。
> 这一步给第 1 步的控制器装插件、起宿主代理、建只读的 render-check 任务并真跑一次。不发版、不暂存、不碰 Harbor 里的东西、不改集群声明。render 会像人跑时一样读写宿主私有目录（已有环境不会生成新身份；要是生成了就是发现，写进回执）。

```text
被测仓：k8s；工位 WS=fable（所有者指定）：~/worktrees/fable/k8s，分支 fable；远程和本地都只推拉这个分支
改动：infrastructure/jenkins/{agent.yaml,tasks/plugins.yaml,tasks/workspace.yaml,config.yaml,service.yaml,templates/*}、ci/render-check.groovy、Makefile（jenkins-materials、jenkins-agent-*）、host/lifecycle.yaml
会停的东西：第三节 jenkins-stop 到 jenkins-deploy 之间控制器重启（只影响 Jenkins 自己）；内网入口、集群、Harbor 不动
会联网的：jenkins-materials 下载 76 个插件（约 110 MB）与 JRE（52 MB）；代理部署时克隆七个仓（走宿主用户的 GitHub SSH）、uv 装 .venv、下载工具二进制
停下的规则：任何一步 exit 不是 0 就停，输出原样进回执，不重试、不退回；带管道的命令包进 bash <<'SH' … SH 里跑
不碰：集群、应用、Harbor 数据；不写库；不替所有者在界面里点；不改别的工位
```

## 一、核对与拉取（只读）

```bash
cd ~/worktrees/fable/k8s && git pull --ff-only origin fable && git log --oneline -1 && git status --short | head -3
ls infrastructure/jenkins/agent.yaml ci/render-check.groovy && grep -c "jenkins-agent" infrastructure/Makefile
make -C infrastructure jenkins-status; echo "status exit=$?"
bash <<'SH'
# 代理要用宿主用户已有的 git 凭据：GitHub SSH 非交互要能通（exit 1 且提示 successfully authenticated 就是通）
ssh -o BatchMode=yes -T git@github.com 2>&1 | head -2; echo "ssh exit=${PIPESTATUS[0]:-?}"
git config --global --get-regexp 'url\..*insteadof' || echo "no insteadOf (fine: the playbook sets it per command)"
SH
```

要看到：HEAD 是本卡这次提交或更新；三个文件都在；控制器 `status exit=0`；ssh 那行有 `successfully authenticated`。ssh 不通（Permission denied）就停：把输出贴给所有者，代理克隆不了仓。

## 二、物料

```bash
make -C infrastructure jenkins-materials; echo "materials exit=$?"
bash <<'SH'
ls ~/k8s-packages/host/jenkins/packages | wc -l
ls -la ~/k8s-packages/host/jenkins/packages | grep -c hpi
SH
```

要看到：exit 0；目录里 77 个文件（76 个 `.hpi` 加一个 `.tar.gz`）。某个插件下载失败（镜像站跳转、超时）就停，贴它的 id 和 curl 输出。

## 三、控制器装插件（会重启控制器）

```bash
make -C infrastructure jenkins-stop; echo "stop exit=$?"
make -C infrastructure jenkins-deploy; echo "deploy exit=$?"
make -C infrastructure jenkins-status; echo "status exit=$?"
bash <<'SH'
sudo -n ls /opt/sunmoon/jenkins/ref-plugins | wc -l
sudo -n ls /opt/sunmoon/jenkins/init.groovy.d
sudo -n test -s /mnt/sunmoon-data/jenkins/home/secrets/sunmoon/agent-host.secret && echo "node secret written"
sudo -n ls /mnt/sunmoon-data/jenkins/home/plugins | grep -c '\.jpi$'
SH
```

要看到：三个 exit 都 0（deploy 里新加的那项核对会等插件加载完、节点 `host` 出现，最多两分钟）；`ref-plugins` 76；三份 groovy；`node secret written`；JENKINS_HOME/plugins 里 `.jpi` 76 个。

deploy 不是 0：贴最后一个失败任务与 `journalctl -u sunmoon-jenkins.service --since '10 min ago' | tail -60`（里面没有口令）。

## 四、宿主代理

```bash
make -C infrastructure jenkins-agent-plan; echo "plan exit=$?"
make -C infrastructure jenkins-agent-deploy; echo "deploy exit=$?"
make -C infrastructure jenkins-agent-status; echo "status exit=$?"
bash <<'SH'
systemctl show sunmoon-jenkins-agent.service --property=ActiveState,UnitFileState,User,WantedBy | cat
ls /mnt/sunmoon-data/jenkins/repos
ls -d /mnt/sunmoon-data/jenkins/repos/k8s/infrastructure/.venv /mnt/sunmoon-data/jenkins/repos/k8s/infrastructure/.tools/bin
SH
```

要看到：deploy 退出 0（克隆七个仓、装 .venv 与工具，十来分钟）；`ActiveState=active`、`UnitFileState=enabled`、`User=zymun`、`WantedBy=sunmoon-platform.target`；`repos` 下七个目录；`.venv`、`.tools/bin` 在。

deploy 不是 0：贴失败任务与 `journalctl -u sunmoon-jenkins-agent.service --since '10 min ago' | tail -40`。

## 五、真跑一次 render-check

```bash
make -C infrastructure jenkins-agent-check; echo "check exit=$?"
bash <<'SH'
ls -t infrastructure/.build/jenkins/ | head -2
tail -n 40 "$(ls -t infrastructure/.build/jenkins/render-check-*.log | head -1)"
SH
```

要看到：`check exit=0`，结果 `SUCCESS`（六个应用的迁移头核对与渲染都过）。日志尾部贴进回执（没有口令）。不是 0 就把整份日志路径写进回执，日志本身留在 `.build/`，不进 git。

## 六、边缘与总状态

```bash
bash <<'SH'
ip=$(grep -E '^edge_public_ip:' infrastructure/edge/config.yaml | awk '{print $2}')
curl -sk -o /dev/null -w "edge jenkins %{http_code}\n" --resolve jenkins.sunmoonai.com:30443:$ip https://jenkins.sunmoonai.com:30443/
SH
make -C infrastructure platform-status; echo "status exit=$?"
```

要看到：边缘 `404`；platform-status 退出 0，清单里多了 `sunmoon-jenkins-agent.service active enabled`。

## 七、所有者走查（不急）

Jenkins 页面：「节点」里 `host` 在线、执行器 1；任务 `render-check` 有一次成功构建，产物 `diff.txt`；「插件」里 76 个。

## 八、回执与推回

`scripts/results/fable-b2.<时间>.md`：每节命令与 exit、第三节四行、第四节三行、第五节日志尾部、第六节两行、停在哪（若有）。不拍、不抄任何口令。

```bash
cd ~/worktrees/fable/k8s && git pull --ff-only origin fable && git add scripts/results/fable-b2.*.md scripts/results/fable-b2.*.txt && git mv docs/dev-investment-agent/switch-test/inbox/luna/2026-10-20-fable-b2-agent-render-check.md docs/dev-investment-agent/switch-test/done/ && git commit -m "fable-b2 回执：宿主代理与 render-check（luna）" && git push origin fable; echo "push exit=$?"
```

拉不下来（非快进）或推不上去就停下，把输出告诉所有者，不强推。
