# 新体系：统一目标改 Wants，重装运行副本，验证单独停入口不再连带（本地机；**在待办 27 通过之后**，需维护批准）

```text
被测仓：k8s，本地路径 ~/worktrees/fable/k8s
跑：按编号步骤做（计划看差异 → 重装运行副本 → 单独停启入口验证不连带 → 回传）
仓与提交：k8s 本条待办所在的 fable 头（host/templates/sunmoon-platform.target.j2 Requires → Wants）
预计：20 分钟；入口中断约 1 分钟；Harbor、集群不该动
看什么：host-lifecycle-plan 的差异只有 target 的那一行；重装退出 0；entry-stop 后 registry、cluster 仍 active；entry-start 退出 0
前提：待办 27 通过（现网在新声明包上）；所有者批准这次维护
回传：k8s/sunmoonai/scripts/results/target-wants.<时间>.md
```

## 为什么

第 27 轮 `entry-stop` 把 Harbor 和集群一起停了：`sunmoon-platform.target` 用 `Requires=` 牵三个服务，systemd 把「显式停一个被 Requires 的单元」传播成「停目标」，目标再按 drop-in 的 `PartOf=` 停另外两个。改成 `Wants=` 后：`platform-stop` 仍逐个停（它本来就是逐个 stop），`boot.sh` 仍逐个启，但单独停一个不再传播。

## 一、计划（只读）

```bash
cd ~/worktrees/fable/k8s && git log --oneline -1 && git status --short | head -3
make -C infrastructure host-lifecycle-plan 2>&1 | tail -n 40; echo "exit=${PIPESTATUS[0]}"
```

要看到：候选里 target 的 `Wants=` 那一行；别的单元文件、脚本、Windows 任务没有差异。有别的差异就贴出来停下。

## 二、重装运行副本

```bash
make -C infrastructure platform-install-lifecycle; echo "exit=$?"
systemctl cat sunmoon-platform.target | grep -E "Wants|Requires"
make -C infrastructure platform-status; echo "exit=$?"
```

要看到：退出 0；`Wants=` 三个服务、没有 `Requires=`；状态里 target、registry、entry、cluster 都 active。

## 三、验证单独停入口不连带

```bash
make -C infrastructure entry-stop; echo "exit=$?"
systemctl is-active sunmoon-registry.service sunmoon-cluster.service sunmoon-platform.target
docker ps --filter name=sunmoon-registry --format '{{.Names}} {{.Status}}' | head -3
make -C infrastructure entry-start; echo "exit=$?"
make -C infrastructure platform-status; echo "exit=$?"
```

要看到：entry-stop 后 registry、cluster 仍 active（target 也仍 active）；Harbor 容器 Up；entry-start 退出 0；状态全 active。

## 四、回传

每步退出码、第一节差异摘录、第三节三个单元的状态；结论：通过 / 不通过。本地提交结果文件。
