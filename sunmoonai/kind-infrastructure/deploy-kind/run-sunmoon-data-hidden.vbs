' Non-console task entry. Runs only the pinned storage checker, waits and returns its exit code.
' Publish with Administrators/SYSTEM write access and owner read/execute access.
Option Explicit
Dim shell, command, powershell, result
Set shell = CreateObject("WScript.Shell")
powershell = shell.ExpandEnvironmentStrings("%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe")
command = "if ((Get-FileHash -LiteralPath 'C:\wsl-disks\scripts\storage-automation-20260928-v1\ensure-sunmoon-data.ps1' -Algorithm SHA256).Hash.ToLowerInvariant() -ne '70ca2d6693881940231bdd39acaad9b2853f96d0c7ddbf5e9d523747e0a4c2bd') { exit 3 }; & 'C:\wsl-disks\scripts\storage-automation-20260928-v1\ensure-sunmoon-data.ps1' -Apply"
result = shell.Run(Chr(34) & powershell & Chr(34) & " -NoProfile -NonInteractive -WindowStyle Hidden -Command " & Chr(34) & command & Chr(34), 0, True)
WScript.Quit result
