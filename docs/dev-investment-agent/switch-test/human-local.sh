#!/usr/bin/env bash
# 所有者在本地机上跑的（拉）：把全部仓和副本同步到远程助手推上来的最新状态，并列出待办。跑完之后的推回见 human-remote.sh。
# 跑完后对 Cursor 说「请看 inbox/cursor」、对 astra 说「请看 inbox/astra」。本地助手不同步、不推；每条做完自己在被测仓本地提交（README「3c」）。
# 用法：WS=<工位> bash ~/switch-test/human-local.sh    （工位必须给，不猜；同步该工位的五仓 + 子仓 + sunmoon-link）
# ~/switch-test 里的两个脚本只是转发器（本脚本生成），永远跑仓里当前工位的最新版；第一次或转发器还没生成时，
# 直接跑仓里这份：WS=fable bash ~/worktrees/fable/k8s/docs/dev-investment-agent/switch-test/human-local.sh
set -uo pipefail
if [ -z "${WS:-}" ]; then
  echo "✗ 要指定工位：WS=<fable|cursor|kimi|luna|qwen> bash ~/switch-test/$(basename "$0")   （不猜，和 five-repos-sync 一样）" >&2
  exit 2
fi
WS="$WS"
K8S="$HOME/worktrees/$WS/k8s"; ST="$K8S/docs/dev-investment-agent/switch-test"
FIVE="k8s knowfeed-app knowbench-app knowbase-app tpl-app knowlab-app knowmart-app"
# 父仓下的全部子仓（与 human-remote.sh 同一份）
SUBS="knowfeed-app/knowfeed-backend knowfeed-app/knowfeed-web-frontend knowfeed-app/knowfeed-admin-frontend
  knowbench-app/knowbench-backend knowbench-app/knowbench-web-frontend knowbench-app/knowbench-admin-frontend
  knowbase-app/knowbase-backend knowbase-app/knowbase-web-frontend knowbase-app/knowbase-admin-frontend
  tpl-app/tpl-backend tpl-app/tpl-web-frontend tpl-app/tpl-admin-frontend
  knowlab-app/knowlab-backend knowlab-app/knowlab-web-frontend knowlab-app/knowlab-admin-frontend
  knowmart-app/knowmart-backend knowmart-app/knowmart-web-frontend knowmart-app/knowmart-admin-frontend"

pull() { # 仓目录 标签
  [ -e "$1/.git" ] || { echo "⚠ $2 不存在：$1"; return 1; }
  git -C "$1" pull -q --ff-only origin "$WS" && printf "  %-28s %s\n" "$2" "$(git -C "$1" rev-parse --short HEAD)" || { echo "✗ $2 拉取失败（工作区有改动？分支不对？）"; return 1; }
}

if [ "${1:-}" != "--after-sync" ]; then
echo "===== 0. 先看本地有没有没推回的东西"
# 本地助手的提交还没推回、或者还在做（有未提交改动）时，拉取只会报 git 的分叉错误；这里先说人话再停
blocked=0
for r in $FIVE $SUBS sunmoon-link; do
  d="$HOME/worktrees/$WS/$r"; [ -e "$d/.git" ] || continue
  # 先取远端：远程助手把本地提交合并进去后，旧的 origin/$WS 会把它们误报成「没推回」
  git -C "$d" fetch -q origin "$WS" 2>/dev/null || true
  dirty=$(git -C "$d" status --porcelain --ignore-submodules=all | head -1)
  ahead=$(git -C "$d" rev-list --count "origin/$WS..HEAD" 2>/dev/null || echo 0)
  # 子仓按父仓 gitlink 检出，可能来自另一工位；与 human-remote.sh 一样，
  # 已在远端分支上的提交不算「没推回」。父仓和 sunmoon-link 仍须对齐本工位。
  if [[ "$r" == */* ]] && [ -n "$(git -C "$d" branch -r --contains HEAD --list 'origin/*' 2>/dev/null)" ]; then
    ahead=0
  fi
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
pull "$HOME/worktrees/$WS/knowbench-app/knowbench-backend" "knowbench-app/knowbench-backend" || exit 1
pull "$HOME/worktrees/$WS/knowbase-app/knowbase-backend" "knowbase-app/knowbase-backend" || exit 1
pull "$HOME/worktrees/$WS/sunmoon-link" sunmoon-link || exit 1

# 1b. 子仓接回工位分支。five-repos-sync 的 submodule update 按父仓指针检出，子仓必然游离（detached）；
# 游离状态下本地助手要先自己建分支才能提交，容易出错。这里把每个子仓接到本地 <工位> 分支：
#   - 子仓当前提交等于、或领先于本地已有的 <工位> 分支：在当前提交上建/移到该分支（内容不动）；
#   - 本地 <工位> 分支有没推回的提交（领先于当前提交）：不动，提示先回传。
echo "===== 1b. 子仓接回 $WS 分支"
for r in $SUBS; do
  d="$HOME/worktrees/$WS/$r"; [ -e "$d/.git" ] || continue
  [ "$(git -C "$d" branch --show-current)" = "$WS" ] && continue
  head=$(git -C "$d" rev-parse HEAD)
  if git -C "$d" show-ref --verify --quiet "refs/heads/$WS" && ! git -C "$d" merge-base --is-ancestor "refs/heads/$WS" "$head"; then
    echo "  ⚠ $r 本地 $WS 分支有没推回的提交，没动；先跑 human-remote.sh 回传"; continue
  fi
  git -C "$d" checkout -q -B "$WS" "$head" || { echo "  ⚠ $r 接不回 $WS 分支"; continue; }
  git -C "$d" fetch -q origin "$WS" 2>/dev/null && git -C "$d" branch -q --set-upstream-to="origin/$WS" "$WS" 2>/dev/null
  printf "  %-44s %s\n" "$r" "$(git -C "$d" rev-parse --short HEAD)"
done
fi

# 同步完成后，把控制权交给仓里的最新版（自己可能是旧副本）
if [ "${1:-}" != "--after-sync" ]; then
  [ -f "$ST/human-local.sh" ] || { echo "✗ 仓里没有 $ST/human-local.sh"; exit 1; }
  exec bash "$ST/human-local.sh" --after-sync
fi

echo "===== 2. 刷新 ~/switch-test：两个脚本只是转发器，永远跑仓里当前工位的最新版（副本没有内容可过期）"
mkdir -p "$HOME/switch-test"
for name in human-local.sh human-remote.sh; do
  cat > "$HOME/switch-test/$name" <<SHIM
#!/usr/bin/env bash
# 转发器：跑仓里 WS 工位的最新版（WS 必须给，不猜）；本文件由 human-local.sh 生成，不要手改
if [ -z "\${WS:-}" ]; then echo "✗ 要指定工位：WS=<fable|cursor|kimi|luna|qwen> bash ~/switch-test/$name" >&2; exit 2; fi
exec bash "\$HOME/worktrees/\$WS/k8s/docs/dev-investment-agent/switch-test/$name" "\$@"
SHIM
  chmod +x "$HOME/switch-test/$name"
done
# 旧机制留下的整目录副本（inbox、README 等）不再需要；只留两个转发器
find "$HOME/switch-test" -mindepth 1 -maxdepth 1 ! -name human-local.sh ! -name human-remote.sh -exec rm -rf {} +

for box in "$ST"/inbox/*/; do
  who=$(basename "$box")
  echo "===== 3. 待办：$who（$ST/inbox/$who）"
  n=0
  for f in "$box"2*.md "$box"astra-*.md; do
    [ -e "$f" ] || continue
    n=$((n+1)); echo "  - $(basename "$f")：$(sed -n '1s/^# //p' "$f")"
  done
  [ $n -eq 0 ] && echo "  （空）"
done
echo; echo "===== 同步完成。对哪个助手说「请看 inbox/<它的名字>」，它就只看那个箱子。（每条做完自己本地提交；推回用 human-remote.sh）"
