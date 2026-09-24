#!/usr/bin/env bash
# 所有者在本地机上跑的：把仓和副本同步到远程助手推上来的最新状态，并列出待办。
# 跑完后对本地助手说一句「请看 inbox」。本地助手自己不同步，只看、只跑。
# 用法：bash ~/switch-test/human-do.sh     （~/switch-test 是副本；本脚本跑完会把副本刷新成仓里的最新版）
set -uo pipefail
WS="${WS:-fable}"
K8S="$HOME/worktrees/$WS/k8s"; ST="$K8S/sunmoonai/docs/dev-investment-agent/switch-test"

echo "===== 1. 同步（工位 $WS）"
if [ -x "$HOME/five-repos-sync/sync-five-repos.sh" ]; then
  "$HOME/five-repos-sync/sync-five-repos.sh" from-remote "$WS" || { echo "同步失败，停在这里，把上面的输出贴给所有者"; exit 1; }
else
  for r in k8s info-app investment-app knowledge-app tpl-app; do
    [ -e "$HOME/worktrees/$WS/$r/.git" ] && { git -C "$HOME/worktrees/$WS/$r" pull -q --ff-only origin "$WS" || { echo "$r 拉取失败，停"; exit 1; }; }
  done
fi
for p in investment-app knowledge-app; do
  d="$HOME/worktrees/$WS/$p/${p%-app}-backend"; [ -e "$d/.git" ] && { git -C "$d" pull -q --ff-only origin "$WS" || echo "⚠ $p 子仓拉取失败"; }
done
[ -e "$HOME/worktrees/$WS/runtime/.git" ] && { git -C "$HOME/worktrees/$WS/runtime" pull -q --ff-only origin "$WS" || echo "⚠ runtime 拉取失败"; }
for r in k8s runtime; do d="$HOME/worktrees/$WS/$r"; [ -e "$d/.git" ] && printf "%-10s %s\n" "$r" "$(git -C "$d" rev-parse --short HEAD)"; done

echo "===== 2. 刷新副本 ~/switch-test"
rm -rf "$HOME/switch-test" && cp -r "$ST" "$HOME/switch-test"

echo "===== 3. 待办（$ST/inbox）"
n=0
for f in "$ST"/inbox/2*.md; do
  [ -e "$f" ] || continue; n=$((n+1))
  echo; echo "----- $(basename "$f")"; cat "$f"
done
[ "$n" = 0 ] && echo "没有待办。"
echo; echo "===== 同步完成。现在对本地助手说：请看 inbox。"
