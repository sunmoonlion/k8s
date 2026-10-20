# luna 卡 fable-b5-1：入口收敛（0038 停点 1）——验新名字、render-check 走新入口

> 状态：**可执行**（远程 Fable 2026-10-21 写）。B 段第 5 步第一个停点：Makefile 删了 3 个转接名（`application-render/stage/validate-release`），`services-render/stage/validate-release` 改叫 `components-render/stage/validate-release`，`help` 按层重写；render-check 的任务体改调新名。不动集群、不动 gitops 声明、不重启控制器（任务体在仓里，下一次构建自动用新的）。远程已验 `make -n`；本卡在真机验一遍并跑一次 render-check。
>
> 临时就地修授权同 b4 卡头（只对卡改到的文件：Makefile、ci/*.groovy、infrastructure/jenkins/**、README；判据、安全约束、设计、集群不碰）。

```text
被测仓：k8s；工位 WS=fable：~/worktrees/fable/k8s，分支 fable
改动（本次）：infrastructure/Makefile、ci/render-check.groovy、infrastructure/jenkins/templates/03-render-check.groovy.j2、applications/deploy.yaml 提示语、19 份 README/地图
不碰：控制器（不重启）、集群、gitops、Harbor；不读、不抄口令
```

## 一、核对与拉取

```bash
cd ~/worktrees/fable/k8s && git pull --ff-only origin fable && git log --oneline -1 && git status --short | head -3
cd infrastructure
for t in platform-plan platform-config platform-status platform-stage platform-build platform-deploy platform-check platform-start platform-stop components-render components-stage components-validate-release application-deployment-plan application-check application-check-public application-bootstrap services-bootstrap flux-release flux-source-apply flux-source-status jenkins-agent-check jenkins-release-run topology-render; do printf '%-32s ' $t; make -n $t OBJECT=app-platform/tpl-app APP=tpl >/dev/null 2>&1 && echo ok || echo FAIL; done
for t in application-render application-stage application-validate-release services-render services-stage services-validate-release; do printf '%-32s ' $t; make -n $t APP=tpl OBJECT=app-platform/tpl-app >/dev/null 2>&1 && echo STILL-THERE || echo gone; done
make help | head -3
cd ..
```

要看到：HEAD 是本卡这次提交或更新；23 个 `ok`；6 个 `gone`；`help` 第一行是「== 公开入口」。

## 二、render-check 用新入口跑一次

```bash
make -C infrastructure jenkins-agent-check; echo "check exit=$?"
bash <<'SH'
log=$(ls -t infrastructure/.build/jenkins/render-check-*.log | head -1); echo "$log"
grep -n "components-render OBJECT=\|application-render\|Finished:" "$log" | head -8
SH
make -C infrastructure platform-status; echo "status exit=$?"
```

要看到：`check exit=0`，结果 SUCCESS；日志里有 `make -C infrastructure components-render OBJECT=app-platform/tpl-app` 这样的行、没有 `application-render`；`Finished: SUCCESS`；platform-status 0。

## 三、回执与推回

`scripts/results/fable-b5-1.<时间>.md`：两节命令与 exit、23 个 ok 与 6 个 gone 的表、日志那几行、「就地修了什么」。

```bash
cd ~/worktrees/fable/k8s && git pull --ff-only origin fable && git add scripts/results/fable-b5-1.*.md && git mv docs/dev-investment-agent/switch-test/inbox/luna/2026-10-21-fable-b5-1-entries.md docs/dev-investment-agent/switch-test/done/ && git commit -m "fable-b5-1 回执：入口收敛验证（luna）" && git push origin fable; echo "push exit=$?"
```
