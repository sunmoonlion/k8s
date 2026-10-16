#!/usr/bin/env bash
# 「冻结解除之后」第 2 条（k8s/docs/rename.md）：两台机器 × ~/master 与五个工位 × 六组仓（含子仓）对齐到 master。
# 本版只有 list：只读（只 git fetch 更新远端跟踪分支），不改任何分支、不动工作区。每台机器各跑一次：
#   bash ~/worktrees/qwen/k8s/docs/rename-tools/align_workstations.sh list
# 每行一个检出：位置、当前分支、比 origin/master 多几个提交（ahead）、少几个（behind）、未提交改动数（dirty）、
# 既没推到 origin/<分支>、也不在 master 里的提交数（unpushed，会丢的）、该做什么（action）。子仓按各检出自己当前的 .gitmodules 找；
# 子仓目录名与 master 上不同（旧名 info-*/knowledge-*）的另标 rename。最后一段列出 ~/master 父仓里 .gitmodules 之外的子仓目录。
set -uo pipefail
WS_LIST=(master cursor fable kimi luna qwen)
REPOS=(k8s runtime knowfeed-app knowbase-app investment-app tpl-app)
[ "${1:-}" = list ] || { echo "用法: bash $0 list"; exit 2; }

base_of() { [ "$1" = master ] && echo "$HOME/master" || echo "$HOME/worktrees/$1"; }
fetch() { timeout 120 git -C "$1" fetch -q origin 2>/dev/null || echo "fetch-fail"; }

row() {  # row <标签> <目录> <期望分支> <master 上的路径或空>
  local tag=$1 d=$2 want=$3 target=$4 br ahead behind dirty unpushed action note=""
  if [ ! -e "$d/.git" ]; then printf "%-52s %s\n" "$tag" "MISSING"; return; fi
  [ -n "$(fetch "$d")" ] && note="$note fetch-fail"
  br=$(git -C "$d" branch --show-current); [ -n "$br" ] || br="(detached)"
  if ! git -C "$d" rev-parse -q --verify origin/master >/dev/null; then printf "%-52s %-10s no-origin/master\n" "$tag" "$br"; return; fi
  ahead=$(git -C "$d" rev-list --count origin/master..HEAD)
  behind=$(git -C "$d" rev-list --count HEAD..origin/master)
  dirty=$(git -C "$d" status --porcelain --ignore-submodules=all | wc -l)
  # 只数会丢的：既不在 origin/<分支>、也不在 origin/master 的提交（已进 master 的不算）
  if git -C "$d" rev-parse -q --verify "origin/$br" >/dev/null; then unpushed=$(git -C "$d" rev-list --count HEAD --not "origin/$br" origin/master)
  else unpushed=$ahead; fi
  [ "$br" = "$want" ] || note="$note branch≠$want"
  [ -n "$target" ] && note="$note rename→$target"
  if [ "$dirty" != 0 ]; then action=hold-dirty
  elif [ "$unpushed" != 0 ]; then action=hold-unpushed
  elif [ "$ahead" = 0 ] && [ "$behind" = 0 ]; then action=ok
  elif [ "$ahead" = 0 ]; then action=ff
  else action=merge; fi
  printf "%-52s %-10s ahead=%-4s behind=%-5s dirty=%-3s unpushed=%-3s %-13s%s\n" "$tag" "$br" "$ahead" "$behind" "$dirty" "$unpushed" "$action" "$note"
}

new_name() { echo "$1" | sed -E 's/^info-/knowfeed-/; s/^knowledge-/knowbase-/'; }

echo "== $(hostname) $(date '+%F %T')  HOME=$HOME"
for ws in "${WS_LIST[@]}"; do
  b=$(base_of "$ws")
  for r in "${REPOS[@]}"; do
    d="$b/$r"
    row "$ws/$r" "$d" "$ws" ""
    [ -f "$d/.gitmodules" ] || continue
    for p in $(git -C "$d" config -f .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}'); do
      n=$(new_name "$p"); [ "$n" = "$p" ] && n=""
      row "$ws/$r/$p" "$d/$p" "$ws" "$n"
    done
  done
done

echo "== ~/master 父仓里不在当前 .gitmodules 的子仓目录（对齐后的旧名残留）"
for r in "${REPOS[@]}"; do
  d="$HOME/master/$r"; [ -f "$d/.gitmodules" ] || continue
  paths=$(git -C "$d" config -f .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}')
  for e in "$d"/*/; do e=$(basename "$e"); [ -e "$d/$e/.git" ] || continue
    echo "$paths" | grep -qx "$e" || echo "  $r/$e"; done
done
echo "exit=0"
