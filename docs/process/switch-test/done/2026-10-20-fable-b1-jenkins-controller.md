# luna 卡 fable-b1：宿主上的 Jenkins 控制器（0033 B 段第 1 步）

> 状态：**可执行**（远程 Fable 2026-10-20 写；所有者「可以开始 B」）。设计 [0033](../../../design/SDD/modules/0033-jenkins-on-host.md) 第八节第 1 步，手册 [`infrastructure/jenkins/README.md`](../../../../../infrastructure/jenkins/README.md)。
> 这一步只把控制器起来、入口加一条路由、管理员口令导入。不碰集群、不发版、不动 Harbor 里的东西、不改任何应用。
>
> **第二次接续（2026-10-20 晚）**：第一、二节和第三节的 plan/deploy/status 已过（回执 `scripts/results/fable-b1.20261020-173741.md`：归档 sha256 与锁一致、预设已导入、控制器 active 且 enabled、剧本内三项核对都过）。停在第三节的独立 curl：`/etc/sunmoon/registry/tls/` 是 root 0700，普通用户读不到 CA，退出 77。这是卡写错了执行身份，不是控制器的问题。**从第三节的 bash 块接着跑**（curl 改成 `sudo -n`），不要重跑 deploy；然后第四节。

```text
被测仓：k8s；工位 WS=fable（所有者定本卡在 fable 工位跑）：~/worktrees/fable/k8s，分支 fable。换工位就把下面命令里的 fable 换成那个工位名
改动：infrastructure/jenkins/（新模块）、Makefile（jenkins-* 目标、config 清单）、artifacts 两份锁与 image-archives 选择、entry/config.yaml 加 jenkins 路由、host/accounts.yaml 加 jenkins 账号、host/lifecycle.yaml 停与状态清单加 jenkins
会停的东西：第四节 entry-stop 到 entry-deploy 之间内网入口 30443 断几十秒（Harbor、各应用的内网域名都走它）。选个没人在用的时候做；边缘不受影响。
停下的规则：任何一步 exit 不是 0 就停，输出原样进回执，不重试、不退回；带管道的命令包进 bash <<'SH' … SH 里跑
不碰：集群、应用、Harbor 数据；不写库；不替所有者在界面里点
```

## 一、核对（只读）

```bash
cd ~/worktrees/fable/k8s && git pull --ff-only origin fable && git log --oneline -1 && git status --short | head -3
ls infrastructure/jenkins/ && grep -n "jenkins" infrastructure/Makefile | head -3
make -C infrastructure platform-status; echo "status exit=$?"
```

要看到：k8s HEAD 是本卡这次提交或更新；`infrastructure/jenkins/` 有 `config.yaml service.yaml README.md tasks templates`；`status exit=0`。

## 二、物料与口令预设

```bash
make -C infrastructure prepare-host-materials; echo "materials exit=$?"
make -C infrastructure platform-account-plan OBJECT=jenkins; echo "plan exit=$?"
make -C infrastructure platform-account-import OBJECT=jenkins; echo "import exit=$?"
```

要看到：三个 exit 都是 0；materials 这一步会拉 Jenkins 镜像（约 250 MB，走 HTTPS_PROXY）并归档、导入 haproxy 与 skopeo 时「已存在」；account-plan 打印 jenkins/admin 的私有路径与能力（不打印口令）；import 打印 `preset_changed: true`（第一次）。

**可能停在这**：materials 报 `Export differs from the frozen artifact`。归档的 sha256 是我在远程机上用 docker 29.1 导出算的，本地机是 docker 29.8；格式一样时字节相同，不一样就停。停了把回执里 `archive_path.json` 没写出来、但任务输出里 `export_identity` 的 checksum 与 size 贴给我，我改锁再来，不要手改锁。

## 三、部署控制器

```bash
make -C infrastructure jenkins-plan; echo "plan exit=$?"
make -C infrastructure jenkins-deploy; echo "deploy exit=$?"
make -C infrastructure jenkins-status; echo "status exit=$?"
bash <<'SH'
sudo -n ss -ltnp | grep -E ':18443|:18080|:50000' ; echo "ports listed above must all be 127.0.0.1"
# CA 在 root 0700 的目录里，独立 curl 用 sudo 读（和剧本里 become 的检查同一身份）；判据不变
sudo -n curl -sS -o /dev/null -w 'tls login %{http_code}\n' --cacert /etc/sunmoon/registry/tls/ca.crt https://127.0.0.1:18443/login
curl -sS -o /dev/null -w 'http login %{http_code}\n' http://127.0.0.1:18080/login
sudo -n curl -sS -o /dev/null -w 'anonymous api %{http_code}\n' --cacert /etc/sunmoon/registry/tls/ca.crt https://127.0.0.1:18443/api/json
systemctl show sunmoon-jenkins.service --property=ActiveState,UnitFileState,WantedBy | cat
SH
```

要看到：deploy 退出 0（第一次启动要等一两分钟，剧本自己等）；三个端口都只在 `127.0.0.1`；两个 login 都是 `200`、匿名 api 是 `403`；`ActiveState=active`、`UnitFileState=enabled`、`WantedBy=sunmoon-platform.target`。

deploy 不是 0 时，把最后一个失败任务的名字和它的输出贴给我；`journalctl -u sunmoon-jenkins.service --since '10 min ago' | tail -50` 一并贴（里面没有口令）。

## 四、入口加路由（会短暂断内网入口）

```bash
make -C infrastructure entry-preview; echo "preview exit=$?"
make -C infrastructure entry-stop; echo "stop exit=$?"
make -C infrastructure entry-deploy; echo "deploy exit=$?"
bash <<'SH'
sudo -n curl -sS -o /dev/null -w 'via entry %{http_code}\n' --cacert /etc/sunmoon/registry/tls/ca.crt --resolve jenkins.sunmoonai.com:30443:127.0.0.1 https://jenkins.sunmoonai.com:30443/login
sudo -n curl -sS -o /dev/null -w 'harbor still %{http_code}\n' --cacert /etc/sunmoon/registry/tls/ca.crt --resolve harbor.sunmoonai.com:30443:127.0.0.1 https://harbor.sunmoonai.com:30443/api/v2.0/health
SH
make -C infrastructure platform-status; echo "status exit=$?"
```

要看到：preview 的路由计划里多了 `jenkins -> 127.0.0.1:18443`；stop、deploy 退出 0；经入口 `200`，Harbor `200`；platform-status 的清单里多了 `sunmoon-jenkins.service active enabled`。

## 五、所有者走查（不急）

浏览器开 `https://jenkins.sunmoonai.com:30443/`，用密码表第 13 项登录；看到的应是空的 Jenkins（没有任务、没有插件、执行器 0）。边缘那边同一域名应是 404。

## 六、回执

`scripts/results/fable-b1.<时间>.md`（第二次用新时间戳，另起一份，不改第一次的）：每节命令与 exit、第三节四行 curl 与 systemctl 输出、第四节两行 curl、停在哪（若有）。不拍、不抄任何口令。

## 七、推回（新规矩，不再经所有者的脚本；推的是本卡工位的分支）

```bash
cd ~/worktrees/fable/k8s && git pull --ff-only origin fable && git add scripts/results/fable-b1.*.md && git mv docs/process/switch-test/inbox/luna/2026-10-20-fable-b1-jenkins-controller.md docs/process/switch-test/done/ && git commit -m "fable-b1 回执：宿主 Jenkins 控制器（luna）" && git push origin fable; echo "push exit=$?"
```

拉不下来（非快进）或推不上去就停下，把输出告诉所有者，不强推。
