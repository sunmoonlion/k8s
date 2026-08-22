$ErrorActionPreference = "SilentlyContinue"
Start-Sleep -Seconds 20

# mount/ 备查副本（E 盘 VHDX + KIND_PV_STORAGE_MODE=vhd 时再启用计划任务）。
# 若计划任务指向桌面上的本脚本，请将下方 $CheckScript 改为该副本在 WSL 中的路径（通常为 /mnt/c/Users/<用户>/Desktop/.../mount/check-storage-mounts.sh）。
# native 模式请勿挂载 E 盘 vhdx；可禁用计划任务。
$WslUser = "zymun"
$CheckScript = "/home/zymun/master/k8s/sunmoonai/kind-infrastructure/mount/check-storage-mounts.sh"

function Notify-Failure($code) {
  $title = "docker-pv mount failed"
  $text = "WSL storage mount check failed (exit code: $code).`nRun: check-storage-mounts.sh"

  try {
    Add-Type -AssemblyName System.Windows.Forms
    [void][System.Windows.Forms.MessageBox]::Show($text, $title, "OK", "Error")
    return
  } catch {}

  try {
    & msg * "$title - $text" *> $null
  } catch {}
}

function Mount-Vhd-Idempotent($path) {
  # `wsl --mount` may return localized/unstable codes even when VHD is already attached.
  # Final success is determined by check-storage-mounts.sh at the end.
  & wsl --mount --vhd $path --bare *> $null
  return
}

Mount-Vhd-Idempotent "E:\wsl-disks\docker-data.vhd"
Mount-Vhd-Idempotent "E:\kind-local-storage\pv-kind-local-storage.vhdx"

# Cleanup possible stale stacked mounts (ignore failures).
& wsl -u root -e umount /data/kind-local-storage *> $null
& wsl -u root -e umount /mnt/pv-kind-ext4 *> $null
& wsl -u root -e umount /mnt/docker-ext4 *> $null

# Mount target points from /etc/fstab (ignore mount command failures, verify via check script).
& wsl -u root -e mount /mnt/docker-ext4 *> $null
& wsl -u root -e mount /mnt/pv-kind-ext4 *> $null
& wsl -u root -e mount /data/kind-local-storage *> $null

# Final truth source: repository storage check script.
& wsl -u $WslUser -e $CheckScript
if ($LASTEXITCODE -ne 0) {
  Notify-Failure $LASTEXITCODE
  exit $LASTEXITCODE
}

exit 0
