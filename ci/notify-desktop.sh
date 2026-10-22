#!/bin/bash
# 桌面通知：在所有者 Windows 屏幕右下角弹一条通知并响一声，点「打开」进链接。
# 只尽力而为：powershell 不在、通知被系统关掉、30 秒没返回……都静默放过，退出码恒为 0，不影响调用方。
# 用法：ci/notify-desktop.sh "<标题>" "<正文>" ["<链接>"] ["sticky"]
#   sticky：一直留在屏幕上直到点掉（用于等人批）；不给则是普通通知，几秒后收进通知中心。
# 值经 base64 传进 PowerShell，不拼进命令行，中文、引号、& 都安全；XML 由 PowerShell 侧转义。
ps=/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
[ -x "$ps" ] || exit 0
b64() { printf '%s' "$1" | base64 -w0; }
t=$(b64 "${1:-SunMoon}"); m=$(b64 "${2:-}"); u=$(b64 "${3:-}"); s=$([ "${4:-}" = sticky ] && echo 1 || echo 0)
code=$(cat <<EOF
\$ErrorActionPreference = 'Stop'
function D([string]\$v) { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(\$v)) }
\$t = [Security.SecurityElement]::Escape((D '$t')); \$m = [Security.SecurityElement]::Escape((D '$m')); \$u = [Security.SecurityElement]::Escape((D '$u'))
[void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
[void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
\$head = '<toast'; if ($s -eq 1) { \$head += ' scenario="reminder"' }; if (\$u) { \$head += ' activationType="protocol" launch="' + \$u + '"' }; \$head += '>'
\$acts = ''; if (\$u) { \$acts += '<action content="打开" activationType="protocol" arguments="' + \$u + '"/>' }; if ($s -eq 1) { \$acts += '<action content="稍后" activationType="system" arguments="dismiss"/>' }
if (\$acts) { \$acts = '<actions>' + \$acts + '</actions>' }
\$x = New-Object Windows.Data.Xml.Dom.XmlDocument
\$x.LoadXml(\$head + '<visual><binding template="ToastGeneric"><text>' + \$t + '</text><text>' + \$m + '</text></binding></visual>' + \$acts + '<audio src="ms-winsoundevent:Notification.Reminder"/></toast>')
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe').Show([Windows.UI.Notifications.ToastNotification]::new(\$x))
EOF
)
enc=$(printf '%s' "$code" | iconv -f UTF-8 -t UTF-16LE | base64 -w0)
timeout 30 "$ps" -NoProfile -NonInteractive -EncodedCommand "$enc" </dev/null >/dev/null 2>&1 || true
exit 0
