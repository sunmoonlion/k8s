#!/usr/bin/env bash
# 所有者在本地机上跑的（推）：本地助手说「跑完了」之后，把它写下的结果和其它改动提交，并同步回远程。
# 用法：bash ~/switch-test/human-remote.sh    （先推子仓与 runtime，再由 sync-five-repos.sh 同步父仓）
# 跑完把最后打印的「仓 提交号」告诉远程助手。
set -euo pipefail
WS="${WS:-fable}"
WORKTREE_ROOT="${WORKTREE_ROOT:-$HOME/worktrees/$WS}"
SYNC_SCRIPT="${SYNC_SCRIPT:-$HOME/five-repos-sync/sync-five-repos.sh}"
FIVE="k8s info-app investment-app knowledge-app tpl-app"
OTHERS="investment-app/investment-backend knowledge-app/knowledge-backend runtime"
changed=()

check_repo() { # 仓目录 标签 是否允许 detached HEAD
  local d="$1" tag="$2" allow_detached="${3:-no}" branch
  [ -e "$d/.git" ] || { echo "✗ $tag 不存在：$d"; return 1; }
  branch=$(git -C "$d" branch --show-current) || return 1
  if [ "$branch" != "$WS" ] && { [ -n "$branch" ] || [ "$allow_detached" != yes ]; }; then
    echo "✗ $tag 当前分支 ${branch:-detached HEAD}，预期 $WS"
    return 1
  fi
}

commit_if_dirty() { # 仓目录 标签
  local d="$1" tag="$2" status
  status=$(git -C "$d" status --porcelain) || return 1
  if [ -n "$status" ]; then
    echo "--- $tag 有改动："; git -C "$d" status --short || return 1
    git -C "$d" add -A || return 1
    git -C "$d" commit -q -m "test(local): $tag 本地改动" || return 1
    changed+=("$tag $(git -C "$d" rev-parse --short HEAD)")
    echo "    已提交 $(git -C "$d" rev-parse --short HEAD)"
  fi
}

echo "===== 1. 检查本地仓库（工位 $WS）"
for r in $FIVE runtime; do check_repo "$WORKTREE_ROOT/$r" "$r" || exit 1; done
for r in investment-app/investment-backend knowledge-app/knowledge-backend; do
  check_repo "$WORKTREE_ROOT/$r" "$r" yes || exit 1
done

echo "===== 2. 先提交并推送子仓与 runtime"
for r in $OTHERS; do
  d="$WORKTREE_ROOT/$r"
  commit_if_dirty "$d" "$r" || { echo "✗ $r 提交失败"; exit 1; }
  # 子模块 update 后通常 detached；推当前 HEAD，不能依赖可能不存在或过期的本地分支。
  git -C "$d" push -q origin "HEAD:refs/heads/$WS" || { echo "✗ $r push 失败，停止回传"; exit 1; }
  echo "  已推 $r"
done

echo "===== 3. 提交并同步父仓（子仓提交已推送）"
for r in $FIVE; do commit_if_dirty "$WORKTREE_ROOT/$r" "$r" || { echo "✗ $r 提交失败"; exit 1; }; done
if [ ${#changed[@]} -eq 0 ]; then echo "没有改动要提交（可能本地助手已经自己提交了）。"; fi
if [ -x "$SYNC_SCRIPT" ]; then
  "$SYNC_SCRIPT" to-remote "$WS" || { echo "父仓 to-remote 失败，把上面的输出贴给远程助手"; exit 1; }
else
  for r in $FIVE; do git -C "$WORKTREE_ROOT/$r" push -q origin "$WS" || { echo "✗ $r push 失败"; exit 1; }; done
fi

echo "===== 4. 告诉远程助手这一句："
line="本地回来了"
for r in $FIVE $OTHERS; do d="$WORKTREE_ROOT/$r"; line="$line；$r $(git -C "$d" rev-parse --short HEAD)"; done
echo "$line"
