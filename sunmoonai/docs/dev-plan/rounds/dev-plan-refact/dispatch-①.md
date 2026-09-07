# ① 投喂清单 ｜ 所有者执行

> 2026-09-07。**五家工作区已就位并验证**：分支 `dev-plan-refact/<家>`、
> HEAD `08d138f1`、零脏文件、`call-①.md` 已在各家树内。
> ⚠ 本文件只列命令，**不执行**。

## 投喂前的两句话

- 发出去的话是**固定的那一句**，不逐轮改写——环节通知在各家树内，各家自取；
- ⚠ **成功判据是产物出现，不是命令返回 0。**`cursor` 未加 `--trust` 时会拒绝执行却仍返回 0。

## 四家 CLI

```bash
# luna
cd /home/zym/worktrees/luna/k8s && env CODEX_HOME=/home/zym/.codex-official \
  codex exec --skip-git-repo-check -s workspace-write --cd /home/zym/worktrees/luna/k8s \
  '按 round-protocol 定位当前环节，做你该做的那一步。' < /dev/null

# kimi
cd /home/zym/worktrees/kimi/k8s && env CODEX_HOME=/home/zym/.codex-kimi \
  codex exec --skip-git-repo-check -s workspace-write --cd /home/zym/worktrees/kimi/k8s \
  '按 round-protocol 定位当前环节，做你该做的那一步。' < /dev/null

# cursor
cd /home/zym/worktrees/cursor/k8s && agent -p \
  '按 round-protocol 定位当前环节，做你该做的那一步。' \
  --output-format text --trust --model cursor-grok-4.6-high

# qwen
cd /home/zym/worktrees/qwen/k8s && qoder -p \
  '按 round-protocol 定位当前环节，做你该做的那一步。' \
  -w /home/zym/worktrees/qwen/k8s --permission-mode accept_edits
```

⚠ `codex exec` **会阻塞等 stdin**，故带 `< /dev/null`。
⚠ `qoder` 交互较多；若你觉得烦，可只对它改用交互式，产物判据不变。

## 第五家：opus

opus 在本会话里，**投喂 = 在会话中说一句**，例如：

> 按 `call-①` 做你的候选。

⚠ 它与四家**同一条件**：同一通知、同一基线、同一路径、同样不得读他家候选。

## 核对（任何时候可跑，投喂后必跑）

```bash
cd /home/zym/master/k8s && python3 sunmoonai/docs/dev-plan/protocol/round-status.py
```

看的是**产物是否出现**，不是命令返回码。五家的候选路径都是

```
sunmoonai/docs/dev-plan/dev-plan-architecture.md
```

各自提交在自己的 `dev-plan-refact/<家>` 分支上。

## 观察窗

`W` = 已交付各家用时的中位数。逾期记该家 Attempt `FAILED(timeout)`，**Task 不失败**——
少一家不影响本轮成立。
