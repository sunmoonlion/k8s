#!/usr/bin/env bash
# 所有者在本地机上跑的（拉）：把全部仓和副本同步到远程助手推上来的最新状态，并列出待办。跑完之后的推回见 human-remote.sh。
# 跑完后对本地助手说一句「请看 inbox」。本地助手不同步、不推；每条做完自己在被测仓本地提交（README「3c」）。
# 用法：bash ~/switch-test/human-local.sh    （没有参数，总是同步全部：五仓 + 两个子仓 + runtime）
# ~/switch-test 是副本，不在 git 里，不会自己更新：本脚本同步完仓之后，切换到仓里的最新版继续跑，
# 由它重建副本。所以副本里的这份即使旧了也没关系，只要它还能同步 k8s。
set -uo pipefail
WS="${WS:-fable}"
K8S="$HOME/worktrees/$WS/k8s"; ST="$K8S/sunmoonai/docs/dev-investment-agent/switch-test"
FIVE="k8s info-app investment-app knowledge-app tpl-app"

pull() { # 仓目录 标签
  [ -e "$1/.git" ] || { echo "⚠ $2 不存在：$1"; return 1; }
  git -C "$1" pull -q --ff-only origin "$WS" && printf "  %-28s %s\n" "$2" "$(git -C "$1" rev-parse --short HEAD)" || { echo "✗ $2 拉取失败（工作区有改动？分支不对？）"; return 1; }
}

if [ "${1:-}" != "--after-sync" ]; then
echo "===== 0. 先看本地有没有没推回的东西"
# 本地助手的提交还没推回、或者还在做（有未提交改动）时，拉取只会报 git 的分叉错误；这里先说人话再停
blocked=0
for r in $FIVE investment-app/investment-backend knowledge-app/knowledge-backend runtime; do
  d="$HOME/worktrees/$WS/$r"; [ -e "$d/.git" ] || continue
  dirty=$(git -C "$d" status --porcelain --ignore-submodules=all | head -1)
  ahead=$(git -C "$d" rev-list --count "origin/$WS..HEAD" 2>/dev/null || echo 0)
  [ -n "$dirty" ] && { echo "  ✗ $r 有没提交的改动（本地助手还在做？）"; blocked=1; }
  [ "$ahead" != 0 ] && { echo "  ✗ $r 有 $ahead 个本地提交还没推回"; blocked=1; }
done
if [ "$blocked" = 1 ]; then
  echo; echo "现在不能拉。等本地助手说「跑完了」，跑 bash ~/switch-test/human-remote.sh 推回（它会自动接上远程的新提交），推完再跑本脚本。"
  exit 2
fi
echo "  干净，可以拉"
echo "===== 1. 同步全部（工位 $WS）"
if [ -x "$HOME/five-repos-sync/sync-five-repos.sh" ]; then
  "$HOME/five-repos-sync/sync-five-repos.sh" from-remote "$WS" || { echo "五仓同步失败，停在这里，把上面的输出贴给远程助手"; exit 1; }
  for r in $FIVE; do printf "  %-28s %s\n" "$r" "$(git -C "$HOME/worktrees/$WS/$r" rev-parse --short HEAD 2>/dev/null)"; done
else
  for r in $FIVE; do pull "$HOME/worktrees/$WS/$r" "$r" || exit 1; done
fi
pull "$HOME/worktrees/$WS/investment-app/investment-backend" "investment-app/investment-backend" || exit 1
pull "$HOME/worktrees/$WS/knowledge-app/knowledge-backend" "knowledge-app/knowledge-backend" || exit 1
pull "$HOME/worktrees/$WS/runtime" runtime || exit 1
fi

# 同步完成后，把控制权交给仓里的最新版（自己可能是旧副本）
if [ "${1:-}" != "--after-sync" ]; then
  [ -f "$ST/human-local.sh" ] || { echo "✗ 仓里没有 $ST/human-local.sh"; exit 1; }
  exec bash "$ST/human-local.sh" --after-sync
fi

echo "===== 2. 刷新副本 ~/switch-test（用仓里的最新版覆盖）"
rm -rf "$HOME/switch-test" && cp -r "$ST" "$HOME/switch-test"

echo "===== 3. 待办（$ST/inbox）"
n=0
for f in "$ST"/inbox/2*.md; do
  [ -e "$f" ] || continue; n=$((n+1))
  echo; echo "----- $(basename "$f")"; cat "$f"
done
[ "$n" = 0 ] && echo "没有待办。"
echo; echo "===== 同步完成。现在对本地助手说：请看 inbox。（它每条做完自己本地提交；推回用 human-remote.sh）"
