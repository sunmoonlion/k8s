$ErrorActionPreference = "SilentlyContinue"
Start-Sleep -Seconds 20

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
& wsl -u zymun -e /mnt/c/Users/zymun/Desktop/k8s/sunmoonai/kind-infrastructure/deploy-kind/check-storage-mounts.sh
if ($LASTEXITCODE -ne 0) {
  Notify-Failure $LASTEXITCODE
  exit $LASTEXITCODE
}

exit 0
