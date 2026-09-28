' Non-console task entry. Runs only the pinned storage checker, waits and returns its exit code.
' Publish with Administrators/SYSTEM write access and owner read/execute access.
Option Explicit
Dim shell, command, powershell, result
Set shell = CreateObject("WScript.Shell")
powershell = shell.ExpandEnvironmentStrings("%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe")
command = "if ((Get-FileHash -LiteralPath 'C:\wsl-disks\scripts\storage-20260928-v3\ensure-sunmoon-data.ps1' -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'cbe8539916c9908d6cff33d4f347942f4495efe30ca7900a3a689028551c1b1b') { exit 3 }; & 'C:\wsl-disks\scripts\storage-20260928-v3\ensure-sunmoon-data.ps1' -Apply"
result = shell.Run(Chr(34) & powershell & Chr(34) & " -NoProfile -NonInteractive -WindowStyle Hidden -Command " & Chr(34) & command & Chr(34), 0, True)
WScript.Quit result
