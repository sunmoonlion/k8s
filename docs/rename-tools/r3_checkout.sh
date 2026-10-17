#!/usr/bin/env bash
# R3 检出换名（k8s/docs/rename.md R3）：一台机器上把一组仓的主目录与全部工位换成新名字。
#
# 用法（必须用 bash 跑；zsh 不拆分 $VAR，循环会把五个工位当成一个词）：
#   bash r3_checkout.sh investment-app knowbench-app
#   bash r3_checkout.sh runtime sunmoon-link
#
# 做的事：旧主目录与五个工位的旧检出整目录挪进 ~/rename-backup/（不删）→ 按新名重新 clone 主目录 →
# remote 照旧布局只换仓名（父仓：origin 推送地址逐条照抄、gitee remote；子仓：GitHub、gitee 两个推送地址）→
# 建跟踪 origin 的工位分支 → repos.conf 里这一行换成新名（保持 $HOME/... 写法）→ 挂出五个工位、初始化子仓、
# 子仓拨回同名分支。不用 mb worktree remove：git 不许摘下带子仓的工位。
#
# 可覆盖（演练用）：WS（工位列表）、MB（model-branch.sh 路径）。
set -euo pipefail

OLD=${1:?用法：bash r3_checkout.sh <旧名> <新名>}
NEW=${2:?用法：bash r3_checkout.sh <旧名> <新名>}
WS=${WS:-"cursor fable kimi luna qwen"}
MB=${MB:-$HOME/toolboxes/Vlinux/utils/set-up-tools/model-switch/model-branch.sh}
REPOS_CONF=$(dirname "$MB")/repos.conf

say() { printf '== %s\n' "$*"; }
newname() { basename "$1" | sed -e 's/^investment-/knowbench-/'; }

# 0. 前提：旧的都在、新的都不在；repos.conf 里恰有旧名一行
[ -d "$HOME/master/$OLD" ] || { echo "停：没有 ~/master/$OLD"; exit 1; }
[ ! -e "$HOME/master/$NEW" ] || { echo "停：~/master/$NEW 已存在"; exit 1; }
for ws in $WS; do
  [ -d "$HOME/worktrees/$ws/$OLD" ] || { echo "停：没有 ~/worktrees/$ws/$OLD（这台机器没有这个工位就从 WS 里去掉）"; exit 1; }
  [ ! -e "$HOME/worktrees/$ws/$NEW" ] || { echo "停：~/worktrees/$ws/$NEW 已存在"; exit 1; }
  [ -z "$(git -C "$HOME/worktrees/$ws/$OLD" status --porcelain --ignore-submodules=none)" ] || { echo "停：~/worktrees/$ws/$OLD 有未提交改动"; exit 1; }
done
# repos.conf 要么恰有旧名一行（本机还没改），要么已拉到改好的版本（恰有新名一行、没有旧名）
n_old=$(grep -cxF "\$HOME/master/$OLD" "$REPOS_CONF" || true); n_new=$(grep -cxF "\$HOME/master/$NEW" "$REPOS_CONF" || true)
case "$n_old/$n_new" in 1/0|0/1) ;; *) echo "停：$REPOS_CONF 里旧名 $n_old 行、新名 $n_new 行（应为 1/0 或 0/1）"; exit 1;; esac
[ -f "$MB" ] || { echo "停：没有 $MB"; exit 1; }

B=$HOME/rename-backup/$(date +%Y%m%d-%H%M)-$OLD
mkdir -p "$B"
say "备份目录 $B"

# 地址一律从旧主目录取、只换仓名，不写死协议（远程机 GitHub 走 ssh，本地机走 https）
GH=$(git -C "$HOME/master/$OLD" remote get-url origin); GH=${GH%"$OLD.git"}
GE=$(git -C "$HOME/master/$OLD" remote get-url gitee);  GE=${GE%"$OLD.git"}
S1=$(git -C "$HOME/master/$OLD" submodule foreach --quiet 'echo $sm_path' | sed -n 1p)
SUB=$(git -C "$HOME/master/$OLD/$S1" remote get-url origin); SUB=${SUB%/*}/
mapfile -t PUSH < <(git -C "$HOME/master/$OLD" remote get-url --push --all origin)
CFG=(); case "$SUB" in git@*) CFG=(-c "url.${SUB}.insteadOf=https://github.com/sunmoonlion/");; esac
say "GH=$GH GE=$GE SUB=$SUB"
say "旧 origin 推送地址：${PUSH[*]}"

# 子仓：remote 指向新仓名；推送地址 GitHub、gitee 各一；拨回给定分支并设上游（同步脚本按此推 HEAD:<工位>）
fix_subs() { local top=$1 branch=$2 p n
  for p in $(git -C "$top" submodule foreach --quiet 'echo $sm_path'); do
    n=$(newname "$p")
    git -C "$top/$p" remote set-url origin "${SUB}$n.git"
    git -C "$top/$p" config --unset-all remote.origin.pushurl || true
    git -C "$top/$p" remote set-url --add --push origin "${SUB}$n.git"
    git -C "$top/$p" remote set-url --add --push origin "${GE}$n.git"
    git -C "$top/$p" fetch -q origin
    git -C "$top/$p" checkout -q -B "$branch"
    git -C "$top/$p" branch -q --set-upstream-to="origin/$branch"
  done; }

# 1. 挪开五个工位的旧检出与旧主目录
for ws in $WS; do mv "$HOME/worktrees/$ws/$OLD" "$B/$ws"; done
mv "$HOME/master/$OLD" "$B/master"
say "旧检出已挪开"

# 2. 用新名字重新 clone 主目录（检出默认分支 master）
git "${CFG[@]}" clone -q --recurse-submodules "${GH}$NEW.git" "$HOME/master/$NEW"
[ "$(git -C "$HOME/master/$NEW" branch --show-current)" = master ] || { echo "停：主目录不在 master"; exit 1; }

# 3. 父仓 remote 照旧布局：gitee remote；origin 的推送地址逐条照抄旧仓的、只换仓名
git -C "$HOME/master/$NEW" remote add gitee "${GE}$NEW.git"
for u in "${PUSH[@]}"; do git -C "$HOME/master/$NEW" remote set-url --add --push origin "${u%"$OLD.git"}$NEW.git"; done
fix_subs "$HOME/master/$NEW" master

# 4. 先建跟踪 origin 的本地工位分支——mb 只认本地分支，没有就「从 master 新建」，会丢掉工位上的提交
for ws in $WS; do git -C "$HOME/master/$NEW" branch -q --track "$ws" "origin/$ws"; done

# 5. repos.conf：这一行换成新名，保持 $HOME 写法与位置（本地机与远程机路径不同，不能写绝对路径）
[ "$n_old" = 0 ] || sed -i "s#^\\\$HOME/master/$OLD\$#\$HOME/master/$NEW#" "$REPOS_CONF"
[ "$(grep -cxF "\$HOME/master/$NEW" "$REPOS_CONF")" = 1 ] || { echo "停：repos.conf 没改对"; exit 1; }

# 6. 挪出五个工位；mb 不管子仓，挂出后逐个初始化、拨回同名分支
for ws in $WS; do
  out=$(bash "$MB" worktree add "$ws" "$NEW")
  echo "$out"
  case "$out" in *"从 master 新建"*|*"失败"*|*"冲突"*) echo "停：$ws 没有按已有分支挂出"; exit 1;; esac
  git "${CFG[@]}" -C "$HOME/worktrees/$ws/$NEW" submodule update -q --init --recursive
  fix_subs "$HOME/worktrees/$ws/$NEW" "$ws"
done

# 7. 核对（进回执）
for ws in $WS; do d=$HOME/worktrees/$ws/$NEW
  printf '%-40s branch=%s head=%s origin=%s dirty=%s\n' "${d/#$HOME/~}" "$(git -C "$d" branch --show-current)" \
    "$(git -C "$d" rev-parse --short HEAD)" "$(git -C "$d" rev-parse --short "origin/$ws")" "$(git -C "$d" status --porcelain --ignore-submodules=none | wc -l)"
  git -C "$d" submodule foreach --quiet 'printf "  %-30s branch=%s up=%s head=%s origin=%s url=%s\n" "$sm_path" "$(git branch --show-current)" "$(git rev-parse --abbrev-ref @{u})" "$(git rev-parse --short HEAD)" "$(git rev-parse --short @{u})" "$(git remote get-url origin)"; git remote get-url --push --all origin | sed "s/^/      push /"'
done
say "主目录 remote（新）"; git -C "$HOME/master/$NEW" remote -v
say "主目录 remote（旧，备份）"; git -C "$B/master" remote -v
say "repos.conf"; grep -n "master/" "$REPOS_CONF"
