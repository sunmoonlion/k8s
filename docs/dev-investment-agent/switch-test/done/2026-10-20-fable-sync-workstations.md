# luna：把本地机的其它工位同步到新规矩（一次性）

> 远程 Fable 2026-10-20 写；WS=fable 上执行，只读别的工位、只快进，不改代码。背景：所有者要让「平台线的同步」新规矩（`switch-test/README.md`「现在的分工」一节）在每个工位都看得到。

## 远程已做的

k8s 仓的 origin 上，四个工位分支都已从 fable 快进到同一提交 `7e9619db`（cursor、kimi、luna、qwen；它们原先都停在 `f1248c16`，没有自己的提交）。远程机上的 cursor、kimi、luna 工作树已 `pull --ff-only`；qwen 工作树是 Opus 的，没碰。只动了 k8s 仓，六个应用仓与 sunmoon-link 没变。

## 本地机要做的

每个工位先只读核两条，都满足才快进；不满足就跳过并写进回执，不强推、不 reset、不 checkout 别的分支。

```bash
for ws in cursor kimi luna qwen; do
  d=~/worktrees/$ws/k8s
  echo "== $ws"
  git -C $d status --short | head -5
  git -C $d fetch -q origin $ws
  echo "branch=$(git -C $d rev-parse --abbrev-ref HEAD) local=$(git -C $d rev-parse --short HEAD) origin=$(git -C $d rev-parse --short origin/$ws) unpushed=$(git -C $d rev-list --count origin/$ws..HEAD)"
done
```

要看到：每个工位 `branch=<工位名>`、`status` 为空、`unpushed=0`。满足的才跑：

```bash
for ws in cursor kimi luna qwen; do
  d=~/worktrees/$ws/k8s
  [ -z "$(git -C $d status --short)" ] && [ "$(git -C $d rev-list --count origin/$ws..HEAD)" = 0 ] \
    && git -C $d pull --ff-only origin $ws && echo "$ws -> $(git -C $d rev-parse --short HEAD)" \
    || echo "$ws skipped"
done
```

要看到：四个都是 `-> 7e9619db`。

qwen 工位若有 Qwen 没推的提交或脏文件，跳过它并写明，由所有者定。

## 回执

`scripts/results/fable-sync-workstations.<时间>.md`：上面两段的原始输出。提交回执、把本页移到 `done/`，`git push origin fable`（本页按新规矩，在 fable 工位推 fable）。
