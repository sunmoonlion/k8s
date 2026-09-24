#!/usr/bin/env bash
# 所有者在本地机上跑的：把仓和副本同步到远程助手推上来的最新状态，并列出待办。
# 跑完后对本地助手说一句「请看 inbox」。本地助手自己不同步，只看、只跑。
#
# 用法：bash ~/switch-test/human-do.sh [仓 ...]
#   不带参数或 all     同步全部：五仓（走 sync-five-repos.sh）+ 两个子仓 + runtime
#   带仓名             只同步这些仓，如：human-do.sh runtime   或   human-do.sh investment-app runtime
#                      k8s 总会同步（待办在它里面）；写了父仓就连带它的子仓
# 仓名：k8s info-app investment-app knowledge-app tpl-app runtime
set -uo pipefail
WS="${WS:-fable}"
K8S="$HOME/worktrees/$WS/k8s"; ST="$K8S/sunmoonai/docs/dev-investment-agent/switch-test"
FIVE="k8s info-app investment-app knowledge-app tpl-app"

pull() { # 仓目录 标签
  [ -e "$1/.git" ] || { echo "⚠ $2 不存在：$1"; return 1; }
  git -C "$1" pull -q --ff-only origin "$WS" && printf "  %-22s %s\n" "$2" "$(git -C "$1" rev-parse --short HEAD)" || { echo "✗ $2 拉取失败（工作区有改动？分支不对？）"; return 1; }
}
sub_of() { case "$1" in investment-app) echo investment-backend;; knowledge-app) echo knowledge-backend;; esac; }

if [ $# -eq 0 ] || [ "$1" = all ]; then
  echo "===== 1. 同步全部（工位 $WS）"
  if [ -x "$HOME/five-repos-sync/sync-five-repos.sh" ]; then
    "$HOME/five-repos-sync/sync-five-repos.sh" from-remote "$WS" || { echo "五仓同步失败，停在这里，把上面的输出贴给所有者"; exit 1; }
    for r in $FIVE; do printf "  %-22s %s\n" "$r" "$(git -C "$HOME/worktrees/$WS/$r" rev-parse --short HEAD 2>/dev/null)"; done
  else
    for r in $FIVE; do pull "$HOME/worktrees/$WS/$r" "$r" || exit 1; done
  fi
  for p in investment-app knowledge-app; do pull "$HOME/worktrees/$WS/$p/$(sub_of "$p")" "$p/$(sub_of "$p")" || true; done
  pull "$HOME/worktrees/$WS/runtime" runtime || true
else
  echo "===== 1. 只同步：k8s $*（工位 $WS）"
  pull "$K8S" k8s || exit 1
  for r in "$@"; do
    [ "$r" = k8s ] && continue
    case " $FIVE runtime " in *" $r "*) ;; *) echo "✗ 不认识的仓名：$r（可用：$FIVE runtime）"; exit 2;; esac
    pull "$HOME/worktrees/$WS/$r" "$r" || exit 1
    s=$(sub_of "$r"); [ -n "$s" ] && { pull "$HOME/worktrees/$WS/$r/$s" "$r/$s" || true; }
  done
fi

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
