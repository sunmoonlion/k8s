#!/usr/bin/env bash
# 两台机器的全面对齐：一台机器上的 ~/master 与五个工位 × 各组仓（含子仓）对齐到 origin/master。所有者要求每个大阶段结束做一次
# （2026-10-16 改名收尾时写成，原在 docs/rename-tools/）。
# 两台机器各跑各的（Opus 跑远程机、Qwen 跑本地机），不经 SSH、不要所有者动手（所有者 2026-10-16 交 Opus 定）。必须用 bash：
#   bash ~/worktrees/qwen/k8s/docs/dev-investment-agent/switch-test/align_workstations.sh list             # 只读：每个检出的状态
#   bash ~/worktrees/qwen/k8s/docs/dev-investment-agent/switch-test/align_workstations.sh align            # 预演：逐个说要做什么，不改
#   bash ~/worktrees/qwen/k8s/docs/dev-investment-agent/switch-test/align_workstations.sh align --apply    # 执行
#   bash ~/worktrees/qwen/k8s/docs/dev-investment-agent/switch-test/align_workstations.sh push-branches [--apply]   # 只在一台机器跑一次：origin/<工位> 快进到 master
# 只做快进：父仓 merge --ff-only origin/master，子仓按新的 .gitmodules 初始化并接回工位分支，旧名子仓目录挪进
# ~/rename-backup/<时间>-old-subrepos/（不删），新建的子仓照 qwen 工位同名子仓配推送地址（GitHub + gitee）。
# 不重置、不强推。哪个父仓（连同它的子仓）有未提交改动、有既不在 origin/<分支> 也不在 master 里的提交、分支不对，整个父仓跳过并报 HOLD。
# 只 git fetch 与本地检出；push-branches 之外不推任何东西。
set -uo pipefail
WS_LIST=(master cursor fable kimi luna qwen)
REPOS=(k8s runtime knowfeed-app knowbase-app investment-app tpl-app)
MODE=${1:-}; APPLY=${2:-}
case "$MODE:$APPLY" in list:|align:|align:--apply|push-branches:|push-branches:--apply) ;; *) echo "用法: bash $0 list | align [--apply] | push-branches [--apply]"; exit 2 ;; esac
STAMP=$(date +%Y%m%d-%H%M%S)

base_of() { [ "$1" = master ] && echo "$HOME/master" || echo "$HOME/worktrees/$1"; }
fetch() { timeout 120 git -C "$1" fetch -q origin 2>/dev/null; }
subpaths() { git -C "$1" config -f "${2:-.gitmodules}" --get-regexp '^submodule\..*\.path$' 2>/dev/null | awk '{print $2}'; }
subpaths_at() { git -C "$1" show "$2:.gitmodules" 2>/dev/null | git config -f /dev/stdin --get-regexp '^submodule\..*\.path$' | awk '{print $2}'; }
# 会丢的提交：既不在 origin/<分支>、也不在 origin/master
lost_of() { local d=$1 br=$2
  if git -C "$d" rev-parse -q --verify "origin/$br" >/dev/null; then git -C "$d" rev-list --count HEAD --not "origin/$br" origin/master
  else git -C "$d" rev-list --count HEAD --not origin/master; fi; }
new_name() { echo "$1" | sed -E 's/^info-/knowfeed-/; s/^knowledge-/knowbase-/'; }

row() {  # list 的一行：row <标签> <目录> <期望分支> <master 上的路径或空>
  local tag=$1 d=$2 want=$3 target=$4 br ahead behind dirty unpushed action note=""
  if [ ! -e "$d/.git" ]; then printf "%-52s %s\n" "$tag" "MISSING"; return; fi
  fetch "$d" || note="$note fetch-fail"
  br=$(git -C "$d" branch --show-current); [ -n "$br" ] || br="(detached)"
  if ! git -C "$d" rev-parse -q --verify origin/master >/dev/null; then printf "%-52s %-10s no-origin/master\n" "$tag" "$br"; return; fi
  ahead=$(git -C "$d" rev-list --count origin/master..HEAD)
  behind=$(git -C "$d" rev-list --count HEAD..origin/master)
  dirty=$(git -C "$d" status --porcelain --ignore-submodules=all | wc -l)
  unpushed=$(lost_of "$d" "$br")
  [ "$br" = "$want" ] || note="$note branch≠$want"
  [ -n "$target" ] && note="$note rename→$target"
  if [ "$dirty" != 0 ]; then action=hold-dirty
  elif [ "$unpushed" != 0 ]; then action=hold-unpushed
  elif [ "$ahead" = 0 ] && [ "$behind" = 0 ]; then action=ok
  elif [ "$ahead" = 0 ]; then action=ff
  else action=ahead-pushed; fi   # 比 master 多、但都已在 origin/<分支>：等 master 跟上，这里不动
  printf "%-52s %-10s ahead=%-4s behind=%-5s dirty=%-3s unpushed=%-3s %-13s%s\n" "$tag" "$br" "$ahead" "$behind" "$dirty" "$unpushed" "$action" "$note"
}

# ------------------------------------------------------------------ push-branches
if [ "$MODE" = push-branches ]; then
  echo "== push-branches $(hostname) $(date '+%F %T') ${APPLY:-（预演）}"; bad=0
  for r in "${REPOS[@]}"; do q="$HOME/worktrees/qwen/$r"; dirs=("$q")
    [ -f "$q/.gitmodules" ] && for p in $(subpaths "$q"); do dirs+=("$q/$p"); done
    for d in "${dirs[@]}"; do fetch "$d" || { echo "  FAIL fetch ${d#$HOME/}"; bad=1; continue; }
      m=$(git -C "$d" rev-parse origin/master)
      for ws in cursor fable kimi luna; do
        cur=$(git -C "$d" rev-parse -q --verify "origin/$ws" || echo none)
        [ "$cur" = "$m" ] && continue
        if [ "$cur" != none ] && ! git -C "$d" merge-base --is-ancestor "$cur" "$m"; then echo "  HOLD ${d#$HOME/worktrees/qwen/} origin/$ws 有 master 之外的提交"; bad=1; continue; fi
        if [ "$APPLY" = --apply ]; then
          git -C "$d" push -q origin "$m:refs/heads/$ws" 2>/dev/null && echo "  PUSHED ${d#$HOME/worktrees/qwen/} $ws ${cur:0:10} -> ${m:0:10}" || { echo "  FAIL ${d#$HOME/worktrees/qwen/} $ws"; bad=1; }
        else echo "  WOULD ${d#$HOME/worktrees/qwen/} $ws ${cur:0:10} -> ${m:0:10}"; fi
      done; done; done
  echo "exit=$bad"; exit $bad
fi

# ------------------------------------------------------------------ list
if [ "$MODE" = list ]; then
  echo "== list $(hostname) $(date '+%F %T')  HOME=$HOME"
  for ws in "${WS_LIST[@]}"; do b=$(base_of "$ws")
    for r in "${REPOS[@]}"; do d="$b/$r"; row "$ws/$r" "$d" "$ws" ""
      [ -f "$d/.gitmodules" ] || continue
      for p in $(subpaths "$d"); do n=$(new_name "$p"); [ "$n" = "$p" ] && n=""; row "$ws/$r/$p" "$d/$p" "$ws" "$n"; done
      for e in "$d"/*/; do e=$(basename "$e"); [ -e "$d/$e/.git" ] || continue
        subpaths "$d" | grep -qx "$e" || echo "$(printf '%-52s' "$ws/$r/$e") 旧名子仓目录（不在 .gitmodules）"; done
    done; done
  echo "exit=0"; exit 0
fi

# ------------------------------------------------------------------ align
echo "== align $(hostname) $(date '+%F %T')  HOME=$HOME  ${APPLY:-（预演，不改）}"
held=0; done_n=0; failed=0
for ws in "${WS_LIST[@]}"; do b=$(base_of "$ws")
  for r in "${REPOS[@]}"; do d="$b/$r"; tag="$ws/$r"
    [ -e "$d/.git" ] || { echo "  HOLD $tag 不存在"; held=$((held+1)); continue; }
    fetch "$d" || { echo "  HOLD $tag fetch 失败"; held=$((held+1)); continue; }
    br=$(git -C "$d" branch --show-current)
    reason=""
    [ "$br" = "$ws" ] || reason="分支是 ${br:-游离}，应为 $ws"
    [ -z "$reason" ] && [ -n "$(git -C "$d" status --porcelain --ignore-submodules=all)" ] && reason="有未提交改动"
    [ -z "$reason" ] && [ "$(lost_of "$d" "$br")" != 0 ] && reason="有不在 origin/$br 也不在 master 的提交"
    oldsubs=$(subpaths "$d")
    for p in $oldsubs; do s="$d/$p"; [ -e "$s/.git" ] || continue; [ -n "$reason" ] && break
      fetch "$s" || { reason="子仓 $p fetch 失败"; break; }
      [ -n "$(git -C "$s" status --porcelain)" ] && { reason="子仓 $p 有未提交改动"; break; }
      [ "$(git -C "$s" rev-list --count HEAD --not --remotes)" != 0 ] && { reason="子仓 $p 有不在远端的提交"; break; }
      git -C "$s" show-ref -q --verify "refs/heads/$ws" && [ "$(git -C "$s" rev-list --count "refs/heads/$ws" --not --remotes)" != 0 ] && { reason="子仓 $p 的 $ws 分支有不在远端的提交"; break; }
    done
    if [ -n "$reason" ]; then echo "  HOLD $tag $reason"; held=$((held+1)); continue; fi
    ahead=$(git -C "$d" rev-list --count origin/master..HEAD); behind=$(git -C "$d" rev-list --count HEAD..origin/master)
    if [ "$behind" = 0 ]; then
      [ "$ahead" = 0 ] && echo "  ok   $tag" || echo "  ok   $tag（比 master 多 $ahead 个，都已推到 origin/$br，等 master 跟上）"; continue; fi
    [ "$ahead" = 0 ] || { echo "  HOLD $tag 与 master 分叉（多 $ahead、少 $behind），要合并，交 Opus"; held=$((held+1)); continue; }
    gone=""; [ -f "$d/.gitmodules" ] && for p in $oldsubs; do subpaths_at "$d" origin/master | grep -qx "$p" || gone="$gone $p"; done
    if [ "$APPLY" != --apply ]; then echo "  WOULD $tag 快进 $behind 个${gone:+；挪走旧子仓目录:$gone}"; done_n=$((done_n+1)); continue; fi
    # ---- 执行
    git -C "$d" merge --ff-only -q origin/master 2> >(grep -v "unable to rmdir" >&2) || { echo "  FAIL $tag 快进失败"; failed=$((failed+1)); continue; }
    if [ -f "$d/.gitmodules" ]; then
      git -C "$d" submodule sync -q --recursive && git -C "$d" submodule update --init -q --recursive || { echo "  FAIL $tag 子仓初始化失败"; failed=$((failed+1)); continue; }
      for p in $(subpaths "$d"); do s="$d/$p"; h=$(git -C "$s" rev-parse HEAD)
        # 新建的子仓：推送地址照 qwen 工位同名子仓（GitHub + gitee）
        ref="$HOME/worktrees/qwen/$r/$p"
        if [ "$s" != "$ref" ] && [ -e "$ref/.git" ] && [ "$(git -C "$s" remote get-url --push --all origin | sort)" != "$(git -C "$ref" remote get-url --push --all origin | sort)" ]; then
          git -C "$s" config --unset-all remote.origin.pushurl 2>/dev/null
          for u in $(git -C "$ref" remote get-url --push --all origin); do git -C "$s" config --add remote.origin.pushurl "$u"; done
        fi
        if git -C "$s" show-ref -q --verify "refs/heads/$ws" && ! git -C "$s" merge-base --is-ancestor "refs/heads/$ws" "$h"; then
          echo "  note $tag/$p 本地 $ws 分支不是当前提交的祖先，子仓留在游离"; continue; fi
        git -C "$s" checkout -q -B "$ws" "$h" && { git -C "$s" rev-parse -q --verify "origin/$ws" >/dev/null && git -C "$s" branch -q --set-upstream-to="origin/$ws" "$ws"; }
      done
      for p in $gone; do [ -e "$d/$p/.git" ] || continue
        mkdir -p "$HOME/rename-backup/$STAMP-old-subrepos/$ws/$r" && mv "$d/$p" "$HOME/rename-backup/$STAMP-old-subrepos/$ws/$r/$p" && echo "  moved $tag/$p -> ~/rename-backup/$STAMP-old-subrepos/$ws/$r/$p"
      done
    fi
    if [ "$(git -C "$d" rev-parse HEAD)" = "$(git -C "$d" rev-parse origin/master)" ] && [ -z "$(git -C "$d" status --porcelain)" ]; then
      echo "  DONE $tag 快进 $behind 个"; done_n=$((done_n+1))
    else echo "  FAIL $tag 做完仍不干净或不在 master：$(git -C "$d" status --porcelain | head -3 | tr '\n' ' ')"; failed=$((failed+1)); fi
  done; done
echo "done_or_would=$done_n held=$held failed=$failed"
[ "$held$failed" = 00 ] && { echo "exit=0"; exit 0; } || { echo "exit=3"; exit 3; }
