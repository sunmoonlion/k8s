#!/usr/bin/env python3
"""On-demand WSL attachment before service startup. Default prints only.

Use the existing elevated owner task, never register tasks or prompt for UAC.
The independently pinned Linux guard is authoritative after the task completes.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess

UUID = 'a28de356-4ba1-4a21-93f5-744b9b9d8be0'
PUBLISHED = Path('/opt/sunmoon/admin/storage/storage-20260927-v2')
PINS = {
    'check-storage-mounts.sh': 'be63dddb1ce85d7de949d35b2a439c25aae8b27d6c3f7e5cc8ef748105515407',
    'sunmoon-data-storage.py': 'e542c9cdbc68abe291d5ab47af466540e632627201d7ac0d1e9e04e30fab99c5',
}
POWERSHELL = Path('/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe')
MAINTENANCE = Path('/mnt/c/wsl-disks/sunmoon-data.maintenance')

# No dynamic command fragments or secrets; the registered task already has the
# necessary Windows privileges. This request does not change task configuration.
REQUEST = r'''
$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'
$Name='sunmoon-data-mount'
$Launcher='C:\wsl-disks\scripts\storage-automation-20260928-v2\run-sunmoon-data-hidden.vbs'
if (Test-Path -LiteralPath 'C:\wsl-disks\sunmoon-data.maintenance') { throw 'Maintenance active' }
if ((Get-FileHash -LiteralPath $Launcher -Algorithm SHA256).Hash.ToLowerInvariant() -ne '131877883b2ac97a9bd0220b444ef3433792a035ad36e289b5be59e5b66c3b8e') { throw 'Launcher changed' }
$Task=Get-ScheduledTask -TaskName $Name -TaskPath '\'
$PrincipalId=[string]$Task.Principal.UserId
if ($PrincipalId -match '^S-1-') { $Sid=([Security.Principal.SecurityIdentifier]$PrincipalId).Value }
else {
    if ($PrincipalId -notmatch '[\\@]') { $PrincipalId=$env:COMPUTERNAME+'\'+$PrincipalId }
    $Sid=([Security.Principal.NTAccount]$PrincipalId).Translate([Security.Principal.SecurityIdentifier]).Value
}
if ($Sid -ne [Security.Principal.WindowsIdentity]::GetCurrent().User.Value -or $Task.Principal.LogonType -ne 'Interactive' -or $Task.Principal.RunLevel -ne 'Highest') { throw 'Task principal differs' }
if (-not $Task.Settings.Enabled -or @($Task.Actions).Count -ne 1 -or $Task.Actions[0].Execute -ne (Join-Path $env:SystemRoot 'System32\wscript.exe') -or $Task.Actions[0].Arguments -ne ('//B //Nologo "'+$Launcher+'"')) { throw 'Task disabled or action differs' }
if ($Task.State -eq 'Running') { throw 'Attachment task already running; retry after completion' }
$Requested=Get-Date
Start-ScheduledTask -TaskName $Name -TaskPath '\'
$Deadline=(Get-Date).AddSeconds(50)
do {
    Start-Sleep -Seconds 1
    if (Test-Path -LiteralPath 'C:\wsl-disks\sunmoon-data.maintenance') { throw 'Maintenance began; do not start services' }
    $Info=Get-ScheduledTaskInfo -TaskName $Name -TaskPath '\'
    $Task=Get-ScheduledTask -TaskName $Name -TaskPath '\'
    if ($Info.LastRunTime -ge $Requested.AddSeconds(-1) -and $Task.State -ne 'Running') {
        if ($Info.LastTaskResult -ne 0) { throw 'Attachment task failed' }
        exit 0
    }
} while ((Get-Date) -lt $Deadline)
throw 'Attachment request timed out; task may still be running, do not start services'
'''


def pinned_guard():
    for name, expected in PINS.items():
        path = PUBLISHED / name
        info = path.lstat()
        if (path.resolve() != path or not stat.S_ISREG(info.st_mode)
                or info.st_uid != 0 or info.st_mode & 0o022
                or hashlib.sha256(path.read_bytes()).hexdigest() != expected):
            raise ValueError('Published storage guard identity differs')
    return ['bash', str(PUBLISHED / 'check-storage-mounts.sh'), '--layout', 'sunmoon-data',
            '--expected-uuid', UUID, '--require-service-visibility']


def ensure():
    if os.geteuid() != 0:
        raise ValueError('Run the lifecycle entry as root; no automatic sudo or UAC')
    if 'microsoft' not in Path('/proc/sys/kernel/osrelease').read_text().lower():
        raise ValueError('WSL attachment applies only to this local WSL installation')
    if not Path('/mnt/c/wsl-disks').is_dir():
        raise ValueError('Windows publication directory unavailable')
    if MAINTENANCE.exists():
        raise ValueError('Storage maintenance active; service startup refused')
    command = pinned_guard()
    result = subprocess.run(command, capture_output=True, timeout=25)
    requested = False
    if result.returncode:
        if not POWERSHELL.is_file():
            raise ValueError('Windows task request unavailable; storage guard still blocks startup')
        encoded = base64.b64encode(REQUEST.encode('utf-16le')).decode('ascii')
        result = subprocess.run([str(POWERSHELL), '-NoProfile', '-NonInteractive',
                                 '-WindowStyle', 'Hidden', '-EncodedCommand', encoded],
                                capture_output=True, timeout=60)
        if result.returncode:
            raise ValueError('On-demand attachment failed; inspect Windows task status, no service started')
        requested = True
    if MAINTENANCE.exists():
        raise ValueError('Storage maintenance began; service startup refused')
    # Do not trust task exit code, a stale status file or a skipped task result.
    result = subprocess.run(pinned_guard(), capture_output=True, timeout=25)
    if result.returncode:
        raise ValueError('Final UUID/service mount guard failed; no service startup admitted')
    return {'storage_verified': True, 'task_requested': requested, 'services_started': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    if not args.apply:
        print(json.dumps({'dry_run': True, 'uuid': UUID, 'task': 'sunmoon-data-mount',
                          'policy': 'check; request existing task only on failure; recheck',
                          'polling_installed': False, 'services_started': False}))
        return
    print(json.dumps(ensure()))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('Storage startup blocked: ' + (str(error) if isinstance(error, ValueError)
                         else type(error).__name__ + '; no service startup admitted')) from None
