# 投喂命令 ｜ 直接敲

> ⚠ **本文件由 `round-dispatch.py --write-md` 从 `agents.toml` 生成，不要手改。**
> 真源是 `agents.toml`；改了那边就重新生成。核对是否漂移：
> `python3 round-dispatch.py --check-md`

> ⚠ **一份通用，不分环节。**发出去的话每个环节都一样——
> 「现在该做哪一步」由各家自己读该轮的 `call-<环节>.md` 判定。

> ⚠ **本文件列的是登记表里的全部执行者，不是某一轮的参赛方。**
> 某一轮投谁，以该轮 `round.md` 的 `proposers` 为准——
> 多敲一家不会报错，但那一家的产物会让 `round-status.py` 认不出，白跑一次。

## 敲之前知道两件事

1. ⚠ **成功判据是产物出现，不是命令返回 0。**
   `cursor` 未加 `--trust` 时会拒绝执行**却仍返回 0**；
   `codex exec` 默认 read-only 时会把活干完但写不进去，退出码同样是 0。
2. ⚠ **`codex exec` 会阻塞等 stdin**（打印 `Reading additional input from stdin...`）。
   下面 `luna` / `kimi` 两条末尾的 `< /dev/null` **不能省**——
   实测省掉后挂 17 分 29 秒、CPU 时间 00:00:00，一步没跑。

## 命令

### luna

```bash
cd /home/zym/worktrees/luna/k8s && env CODEX_HOME=/home/zym/.codex-official codex exec --skip-git-repo-check -s workspace-write --cd /home/zym/worktrees/luna/k8s '按 round-protocol 定位当前环节，做你该做的那一步。' < /dev/null
```

### kimi

```bash
cd /home/zym/worktrees/kimi/k8s && env CODEX_HOME=/home/zym/.codex-kimi codex exec --skip-git-repo-check -s workspace-write --cd /home/zym/worktrees/kimi/k8s '按 round-protocol 定位当前环节，做你该做的那一步。' < /dev/null
```

### cursor

```bash
cd /home/zym/worktrees/cursor/k8s && agent -p '按 round-protocol 定位当前环节，做你该做的那一步。' --output-format text --trust --model cursor-grok-4.6-high
```

### qwen

```bash
cd /home/zym/worktrees/qwen/k8s && qoder -p '按 round-protocol 定位当前环节，做你该做的那一步。' -w /home/zym/worktrees/qwen/k8s --permission-mode accept_edits
```

### fable —— 无命令行入口

⚠ **不能用命令投喂**：它没有一次性命令行入口。
把它的界面/会话打开在 `/home/zym/worktrees/fable/k8s`，然后发这一句：

```text
按 round-protocol 定位当前环节，做你该做的那一步。
```

### opus —— 无命令行入口

⚠ **不能用命令投喂**：它没有一次性命令行入口。
把它的界面/会话打开在 `/home/zym/worktrees/opus/k8s`，然后发这一句：

```text
按 round-protocol 定位当前环节，做你该做的那一步。
```

## 敲完之后

```bash
cd ~/master/k8s && python3 sunmoonai/docs/dev-plan/protocol/round-status.py
```

看的是**产物出现没有**。要读内容再开检视面：

```bash
python3 sunmoonai/docs/dev-plan/protocol/round-review.py --round <轮次>
python3 sunmoonai/docs/dev-plan/protocol/round-review.py --round <轮次> --close
```
