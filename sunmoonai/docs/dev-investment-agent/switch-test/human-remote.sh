#!/usr/bin/env bash
# 所有者在本地机上跑的（推）：本地助手说「跑完了」之后，把它写下的结果和其它改动提交，并同步回远程。
# 用法：bash ~/switch-test/human-remote.sh    （没有参数：五仓走 sync-five-repos.sh to-remote，子仓与 runtime 直接 push）
# 跑完把最后打印的「仓 提交号」告诉远程助手。
set -uo pipefail
WS="${WS:-fable}"
FIVE="k8s info-app investment-app knowledge-app tpl-app"
OTHERS="investment-app/investment-backend knowledge-app/knowledge-backend runtime"
changed=()

commit_if_dirty() { # 仓目录 标签
  local d="$1" tag="$2"
  [ -e "$d/.git" ] || return 0
  if [ -n "$(git -C "$d" status --porcelain)" ]; then
    echo "--- $tag 有改动："; git -C "$d" status --short | head -20
    local files; files=$(git -C "$d" status --porcelain | awk '{print $2}' | grep -E 'results/' | xargs -r -n1 basename | tr '\n' ' ')
    git -C "$d" add -A && git -C "$d" commit -q -m "test(local): ${files:-本地改动}" && changed+=("$tag $(git -C "$d" rev-parse --short HEAD)") && echo "    已提交 $(git -C "$d" rev-parse --short HEAD)"
  fi
}

echo "===== 1. 提交本地改动（工位 $WS）"
for r in $FIVE; do commit_if_dirty "$HOME/worktrees/$WS/$r" "$r"; done
for r in $OTHERS; do commit_if_dirty "$HOME/worktrees/$WS/$r" "$r"; done
[ ${#changed[@]} -eq 0 ] && echo "没有改动要提交（可能本地助手已经自己提交了）。"

echo "===== 2. 同步回远程"
if [ -x "$HOME/five-repos-sync/sync-five-repos.sh" ]; then
  "$HOME/five-repos-sync/sync-five-repos.sh" to-remote "$WS" || { echo "五仓 to-remote 失败：常见原因是远程工位不干净，把上面的输出贴给远程助手"; exit 1; }
else
  for r in $FIVE; do git -C "$HOME/worktrees/$WS/$r" push -q origin "$WS" || { echo "✗ $r push 失败"; exit 1; }; done
fi
for r in $OTHERS; do
  d="$HOME/worktrees/$WS/$r"; [ -e "$d/.git" ] || continue
  git -C "$d" push -q origin "$WS" && echo "  已推 $r" || echo "✗ $r push 失败"
done

echo "===== 3. 告诉远程助手这一句："
line="本地回来了"
for r in $FIVE $OTHERS; do d="$HOME/worktrees/$WS/$r"; [ -e "$d/.git" ] && line="$line；$r $(git -C "$d" rev-parse --short HEAD)"; done
echo "$line"
