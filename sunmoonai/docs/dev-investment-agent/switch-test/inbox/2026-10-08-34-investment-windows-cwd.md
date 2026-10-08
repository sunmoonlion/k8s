# 新体系：investment 后端修 Windows 目录（顶层 cwd），重建、发布晋级应用（本地机）

```text
被测仓：k8s，本地路径 ~/worktrees/fable/k8s
跑：构建 investment 后端 → 暂存 investment → 提交 → 发布晋级应用 → 检查
预计：15 分钟；一个镜像；没有迁移；investment 的 API 与工作台管理者滚动一次
看什么：后端锁的 source_revision 等于 sources.yaml 钉的提交；application-check(-public) APP=investment 退出 0
前提：platform-status 退出 0；工作区干净
回传：k8s/sunmoonai/scripts/results/investment-windows-cwd.<时间>.md
```

## 这一轮是什么

Windows 代理联调查出：工作台把项目目录同时发在顶层 `cwd` 和 `environments[].cwd`；沙箱里的 app-server 把顶层的 Windows 路径拼成 `/data/C:\...`，权限里多出解析不了的一条，Windows 代理把命令全拒。后端改为 Windows 目录只放 `environments[].cwd`；Linux 目录照旧（investment-backend `7ac05d2a`）。

## 一、构建、暂存、提交

```bash
cd ~/worktrees/fable/k8s && git log --oneline -1 && git status --short | head -3
make -C infrastructure platform-status; echo "exit=$?"
make -C infrastructure platform-build OBJECT=app-platform/investment-app/investment-backend 2>&1 | tail -n 8; echo "exit=${PIPESTATUS[0]}"
grep -E "source_revision|digest" gitops/components/app-platform/investment-app/investment-backend/image.lock.yaml
make -C infrastructure platform-stage OBJECT=app-platform/investment-app; echo "exit=$?"
git status --short gitops/components/app-platform | head -20
git add gitops/components/app-platform && git -c core.editor=true commit -m "deploy(investment): Windows 目录不放顶层 cwd（待办 34）"
```

要看到：只有 investment 后端的锁和它的几个 workload 变（镜像摘要）；迁移 Job 名里的摘要跟着变、revision 仍是 v4；没有 sops 变化。

## 二、发布、晋级、应用

照待办 32 第五节，提交消息写「待办 34：Windows cwd」。

## 三、检查

```bash
make -C infrastructure application-check APP=investment 2>&1 | tail -n 6; echo "exit=${PIPESTATUS[0]}"
make -C infrastructure application-check-public APP=investment 2>&1 | tail -n 6; echo "exit=${PIPESTATUS[0]}"
```

## 四、回传并本地提交

每步退出码、锁两行、候选整份、两项检查结果。文件名 `investment-windows-cwd.<时间>.md`。
