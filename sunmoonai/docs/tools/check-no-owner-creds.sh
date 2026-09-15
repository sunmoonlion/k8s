#!/usr/bin/env bash
# check-no-owner-creds.sh —— 首版（S1 动作 ④）
#
# **它是什么**：卫生检查。扫描 agent 进程可达的位置，看有没有所有者的可写凭据。
# **它不是什么**：**不是边界**。
#
#   本机 `zym` 拥有免密 sudo（`(ALL) NOPASSWD: ALL`）且在 docker 组——
#   agent 可提权到 root，因而**可以改写本脚本、改写它的退出码、或直接删掉它**。
#   实证见同目录 `rounds/_spike-sign/forensics.md` F1/F2。
#   真正的强制点只有一个位置：**托管方的 key 作用域与分支保护**（agent 够不着）。
#
#   所以：本脚本零命中 **不证明** 没有可写凭据；它只证明「没有以常见形态放在常见位置」。
#   把它当边界用，就是 round-protocol「判据自身的质量」点名的那类错——
#   覆盖不全的检查比没有检查更危险，因为它会报「通过」。
#
# 退出码：命中 → 1；零命中 → 0（含义见上，不等于安全）。
set -uo pipefail
HITS=0
say(){ printf '  %s\n' "$*"; }
hit(){ HITS=$((HITS+1)); printf '  ❌ %s\n' "$*"; }

echo "check-no-owner-creds（卫生检查，非边界）  host=$(hostname) id=$(id -un) uid_map=$(tr -s ' ' < /proc/self/uid_map)"
echo

echo "[1] 明文 git 凭据"
for f in "$HOME/.git-credentials" "$HOME/.netrc" /etc/netrc; do
  [ -e "$f" ] && hit "$f 存在（$(wc -l < "$f") 行，权限 $(stat -c %a "$f")）—— 明文可读，等于把写权限交给本机任何能读它的进程"
done
[ "$(git config --global credential.helper 2>/dev/null)" = "store" ] && \
  hit "credential.helper = store —— 凭据以明文落盘"

echo "[2] 无口令 ssh 私钥"
for k in "$HOME"/.ssh/id_*; do
  case "$k" in *.pub) continue;; esac
  [ -e "$k" ] || continue
  if ! head -c 400 "$k" | grep -qiE 'ENCRYPTED|aes-'; then
    hit "$k 无口令 —— 任何能读该文件的进程即可用它推送"
  fi
done

echo "[3] 主仓是否对本机身份可写（判据 ⓪）"
for r in origin gitee; do
  git remote get-url "$r" >/dev/null 2>&1 || continue
  if timeout 25 git push "$r" --dry-run HEAD:refs/heads/_creds_probe >/dev/null 2>&1; then
    hit "remote '$r' 接受本机身份的 push —— S1 判据 ⓪ 要求被拒"
  else
    say "✅ remote '$r' 拒绝本机身份的 push"
  fi
done

echo "[4] 签名私钥不得在本机"
n=$(gpg --list-secret-keys 2>/dev/null | grep -c '^sec' || true)
[ "${n:-0}" -gt 0 ] && hit "本机存在 $n 个 GPG 私钥 —— 签名私钥只能在所有者自己的设备上"

echo "[5] 提权面（决定上面各条有没有意义）"
sudo -n true 2>/dev/null && hit "免密 sudo 可用 —— **本脚本与本机一切本地检查对 agent 均无效**"
docker info >/dev/null 2>&1 && hit "docker 可用 —— 等价 root，同上"

echo
if [ "$HITS" -eq 0 ]; then
  echo "零命中。**注意：这不等于安全**——见文件头。"
  exit 0
else
  echo "命中 $HITS 项。"
  exit 1
fi
