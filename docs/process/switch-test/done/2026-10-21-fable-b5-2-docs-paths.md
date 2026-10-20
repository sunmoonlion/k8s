# luna 卡 fable-b5-2：docs 拆分后的新路径——验仓、重装所有者的转发器

> 状态：**可执行**（远程 Fable 2026-10-21 写）。B5 停点 2、3 已推上 fable：文档树按内容拆了——`docs/design/`（原 tree-build）、`docs/process/`（pipeline、turn、switch-test、tools）、`docs/ops/`（使用说明）；`infrastructure/` 加了分层对照表。**从这张卡起，收件箱在 `docs/process/switch-test/inbox/<名>/`**，回执仍在 `scripts/results/`。所有者的 `~/switch-test/` 两个转发器指着旧路径，要重写一次（第二节，不跑同步）。
>
> 临时就地修授权同前（只对卡改到的文件；判据、安全约束、设计、集群不碰）。

```text
被测仓：k8s；工位 WS=fable：~/worktrees/fable/k8s，分支 fable
改动（本次）：docs/ 整树搬家、链接重算、门禁根、钩子；infrastructure README 分层表；新工具 docs/process/tools/{relocate-links,check-links}.py
不碰：控制器、代理、集群、gitops、Harbor
```

## 一、核对与拉取

```bash
cd ~/worktrees/fable/k8s && git pull --ff-only origin fable && git log --oneline -1 && git status --short | head -3
ls docs/; ls docs/process/ docs/ops/; ls docs/dev-investment-agent 2>&1 | head -1
python3 docs/process/tools/check-links.py | head -1
git ls-files docs/process/switch-test/done | grep -c "fable-b5-1\|fable-b4b"
head -3 infrastructure/README.md | cut -c1-120
```

要看到：HEAD 是本卡这次提交或更新；`docs/` 下有 `design process ops project-guide reference 总纲 README.md`，没有 `dev-investment-agent`（`ls` 报 No such file）；`check-links: 12 broken link(s)`（都是 `done/` 里的历史卡，远程核过的基线）；你上两张卡在 `done/` 里（计数 2）；`infrastructure/README.md` 第三行是「地图位置」。

## 二、重写所有者的两个转发器（只写文件，不跑同步）

```bash
bash <<'SH'
set -e
mkdir -p "$HOME/switch-test"
for name in human-local.sh human-remote.sh; do
  cat > "$HOME/switch-test/$name" <<SHIM
#!/usr/bin/env bash
# 转发器：跑仓里 WS 工位的最新版（WS 必须给，不猜）；本文件由 human-local.sh 生成，不要手改
if [ -z "\${WS:-}" ]; then echo "✗ 要指定工位：WS=<fable|cursor|kimi|luna|qwen> bash ~/switch-test/$name" >&2; exit 2; fi
exec bash "\$HOME/worktrees/\$WS/k8s/docs/process/switch-test/$name" "\$@"
SHIM
  chmod +x "$HOME/switch-test/$name"
done
grep -n "docs/process" "$HOME/switch-test/human-local.sh" "$HOME/switch-test/human-remote.sh"
ls -l "$HOME/worktrees/fable/k8s/docs/process/switch-test/human-local.sh"
SH
```

要看到：两个转发器各有一行 `docs/process/switch-test/...`；仓里的脚本在。这两个转发器以后由 `human-local.sh` 自己再生成，内容和这里一样。

## 三、门禁从新路径跑一次（只读）

```bash
cd ~/worktrees/fable/k8s && git config core.hooksPath && python3 docs/process/tools/doc-gate.py docs/process/switch-test/README.md docs/ops/README.md 2>&1 | tail -1 && python3 docs/process/tools/anchor-gate.py 2>&1 | tail -1
```

要看到：`.githooks`；doc-gate「2 份检查通过」；anchor-gate 通过。

## 四、回执与推回

`scripts/results/fable-b5-2.<时间>.md`：三节命令与输出、「就地修了什么」。

```bash
cd ~/worktrees/fable/k8s && git pull --ff-only origin fable && git add scripts/results/fable-b5-2.*.md && git mv docs/process/switch-test/inbox/luna/2026-10-21-fable-b5-2-docs-paths.md docs/process/switch-test/done/ && git commit -m "fable-b5-2 回执：docs 新路径与转发器（luna）" && git push origin fable; echo "push exit=$?"
```
