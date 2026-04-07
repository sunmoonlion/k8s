param(
    [string]$Cluster,
    [string]$Mode
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Info([string]$m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Ok([string]$m) { Write-Host "[ OK ] $m" -ForegroundColor Green }
function Warn([string]$m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Err([string]$m) { Write-Host "[ERR ] $m" -ForegroundColor Red }

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigFile = Join-Path $ScriptDir "k8s-admin.conf"
$PidFile = Join-Path $ScriptDir ".k8s-tunnel.pid"

function Expand-UserPath([string]$p) {
    if ([string]::IsNullOrWhiteSpace($p)) { return $p }
    $v = $p.Trim()
    if ($v.StartsWith("~/")) { return Join-Path $HOME ($v.Substring(2)) }
    return [Environment]::ExpandEnvironmentVariables($v)
}

function Parse-ClusterFromArgs([string[]]$argv, [string]$clusterIn) {
    $clusterOut = $clusterIn
    for ($i = 0; $i -lt $argv.Count; $i++) {
        $a = $argv[$i]
        if ($a -match '^(?i)--cluster=(.+)$') {
            $clusterOut = $Matches[1]
        } elseif ($a -match '^(?i)--cluster$|^(?i)-c$') {
            if ($i + 1 -ge $argv.Count) { throw "--cluster/-c missing value" }
            $i++
            $clusterOut = $argv[$i]
        } elseif ($a -match '^(?i)-c(\d+)$') {
            $clusterOut = "C$($Matches[1])"
        }
    }
    if ($clusterOut) {
        $clusterOut = $clusterOut.ToUpperInvariant()
        if ($clusterOut -match '^\d+$') { $clusterOut = "C$clusterOut" }
    }
    return $clusterOut
}

function Parse-Ini([string]$path) {
    if (!(Test-Path $path)) { throw "config not found: $path" }
    $r = @{}
    $sec = ""
    foreach ($line in Get-Content -Path $path -Encoding UTF8) {
        $t = $line.Trim()
        if (!$t -or $t.StartsWith("#") -or $t.StartsWith(";")) { continue }
        if ($t -match '^\[(.+)\]$') {
            $sec = $Matches[1].Trim()
            if (-not $r.ContainsKey($sec)) { $r[$sec] = @{} }
            continue
        }
        if ($sec -and $t -match '^([^=]+)=(.*)$') {
            $k = $Matches[1].Trim()
            $v = $Matches[2].Trim()
            $r[$sec][$k] = $v
        }
    }
    return $r
}

function Getv($cfg, [string]$sec, [string]$key, [string]$def = "") {
    if ($cfg.ContainsKey($sec) -and $cfg[$sec].ContainsKey($key)) { return $cfg[$sec][$key] }
    return $def
}

function Split-HostPort([string]$hostPort, [int]$defaultPort = 22) {
    $hostName = $hostPort
    $port = $defaultPort
    if ($hostPort -match '^(.+):(\d+)$') {
        $hostName = $Matches[1]
        $port = [int]$Matches[2]
    }
    return @{ Host = $hostName; Port = $port }
}

function Ensure-Command([string]$name) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) { throw "command not found: $name" }
}

function Stop-TunnelQuietly {
    if (Test-Path $PidFile) {
        $idRaw = (Get-Content $PidFile -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($idRaw -and ($idRaw -as [int])) {
            $id = [int]$idRaw
            try { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue } catch { }
        }
        Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
    }
}

function Build-SshAuthArgs([string]$secretPath) {
    $sshArgs = New-Object System.Collections.Generic.List[string]
    if ($secretPath) {
        $sshArgs.Add("-i")
        $sshArgs.Add($secretPath)
    }
    $sshArgs.Add("-o"); $sshArgs.Add("StrictHostKeyChecking=no")
    $sshArgs.Add("-o"); $sshArgs.Add("UserKnownHostsFile=NUL")
    $sshArgs.Add("-o"); $sshArgs.Add("LogLevel=ERROR")
    return $sshArgs
}

function Start-SshTunnel([string[]]$baseAuthArgs, [string]$sshUser, [string]$sshHost, [int]$sshPort, [int]$localPort, [string]$remoteHost, [int]$remotePort, [int]$timeoutSec) {
    Stop-TunnelQuietly
    $cmdArgs = New-Object System.Collections.Generic.List[string]
    $baseAuthArgs | ForEach-Object { $cmdArgs.Add($_) }
    $cmdArgs.Add("-o"); $cmdArgs.Add("ConnectTimeout=$timeoutSec")
    $cmdArgs.Add("-o"); $cmdArgs.Add("ServerAliveInterval=30")
    $cmdArgs.Add("-o"); $cmdArgs.Add("ServerAliveCountMax=3")
    $cmdArgs.Add("-o"); $cmdArgs.Add("TCPKeepAlive=yes")
    $cmdArgs.Add("-L"); $cmdArgs.Add("$localPort`:$remoteHost`:$remotePort")
    $cmdArgs.Add("-p"); $cmdArgs.Add("$sshPort")
    $cmdArgs.Add("$sshUser@$sshHost")
    $cmdArgs.Add("-N")

    $p = Start-Process -FilePath "ssh" -ArgumentList $cmdArgs -WindowStyle Hidden -PassThru
    Start-Sleep -Seconds 2
    if ($p.HasExited) { throw "ssh tunnel failed, exit=$($p.ExitCode)" }
    "$($p.Id)" | Set-Content -Path $PidFile -Encoding ASCII
    return $p.Id
}

function Invoke-SshCommand([string[]]$baseAuthArgs, [string]$sshUser, [string]$sshHost, [int]$sshPort, [int]$timeoutSec, [string]$remoteCommand) {
    $cmdArgs = New-Object System.Collections.Generic.List[string]
    $baseAuthArgs | ForEach-Object { $cmdArgs.Add($_) }
    $cmdArgs.Add("-o"); $cmdArgs.Add("ConnectTimeout=$timeoutSec")
    $cmdArgs.Add("-p"); $cmdArgs.Add("$sshPort")
    $cmdArgs.Add("$sshUser@$sshHost")
    $cmdArgs.Add($remoteCommand)
    & ssh @cmdArgs
}

function Update-KubeconfigForLocalTunnel([string]$kubeconfigPath, [int]$localPort) {
    if (!(Test-Path $kubeconfigPath)) { throw "kubeconfig not found: $kubeconfigPath" }
    $content = Get-Content -Path $kubeconfigPath -Raw -Encoding UTF8
    $content = [Regex]::Replace($content, '(?m)^\s*server:\s*https://[^\s]+', "    server: https://127.0.0.1:$localPort")
    $content = [Regex]::Replace($content, '(?m)^\s*certificate-authority-data:.*\r?\n?', "")
    $content = [Regex]::Replace($content, '(?m)^\s*certificate-authority:.*\r?\n?', "")
    if ($content -notmatch '(?m)^\s*insecure-skip-tls-verify:\s*true\s*$') {
        $content = [Regex]::Replace($content, "(?m)^(\s*server:\s*https://127\.0\.0\.1:$localPort\s*)$", "`$1`r`n    insecure-skip-tls-verify: true")
    }
    Set-Content -Path $kubeconfigPath -Value $content -Encoding UTF8
}

function Test-KubeConnection([string]$kubeconfigPath) {
    $old = $env:KUBECONFIG
    try {
        $env:KUBECONFIG = $kubeconfigPath
        & kubectl get nodes | Out-Null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    } finally {
        $env:KUBECONFIG = $old
    }
}

function Show-Menu([string]$kubeconfigPath) {
    while ($true) {
        Write-Host ""
        Write-Host "1) kubectl get nodes -o wide"
        Write-Host "2) kubectl get pods -A"
        Write-Host "3) kubectl get svc -A"
        Write-Host "4) kubectl cluster-info"
        Write-Host "q) quit"
        $choice = Read-Host "choose"

        $old = $env:KUBECONFIG
        $env:KUBECONFIG = $kubeconfigPath
        try {
            switch ($choice) {
                "1" { & kubectl get nodes -o wide }
                "2" { & kubectl get pods -A }
                "3" { & kubectl get svc -A }
                "4" { & kubectl cluster-info }
                "q" { return }
                default { Warn "invalid choice" }
            }
        } finally {
            $env:KUBECONFIG = $old
        }
    }
}

try {
    Ensure-Command "ssh"
    Ensure-Command "kubectl"

    $cfg = Parse-Ini -path $ConfigFile
    $Cluster = Parse-ClusterFromArgs -argv $args -clusterIn $Cluster

    $globalDefaultMode = Getv $cfg "GLOBAL" "default_mode" "direct"
    $globalTimeout = [int](Getv $cfg "GLOBAL" "timeout" "30")
    $defaultCluster = Getv $cfg "GLOBAL" "default_cluster" "C1"

    if (-not $Cluster) { $Cluster = $env:CLUSTER }
    if (-not $Cluster) { $Cluster = $defaultCluster }
    $Cluster = $Cluster.ToUpperInvariant()

    if ($Cluster -notmatch '^C\d+$') { throw "cluster must be C{number}" }

    $bSection = "${Cluster}_BASTION"
    $dSection = "${Cluster}_DIRECT"
    if (-not $cfg.ContainsKey($bSection)) { $bSection = "BASTION" }
    if (-not $cfg.ContainsKey($dSection)) { $dSection = "DIRECT" }

    $bHost = Getv $cfg $bSection "host" ""
    $bUser = Getv $cfg $bSection "user" ""
    $bSecret = Expand-UserPath (Getv $cfg $bSection "secret" "")
    $bApiServer = Getv $cfg $bSection "api_server" ""
    $bApiUser = Getv $cfg $bSection "api_user" $bUser
    $bApiPort = [int](Getv $cfg $bSection "api_port" "6443")
    $bLocalPort = [int](Getv $cfg $bSection "local_port" "6441")
    $bKubeconfig = Expand-UserPath (Getv $cfg $bSection "kubeconfig" "~/.kube/cluster-admin.conf")

    $dHost = Getv $cfg $dSection "host" ""
    $dUser = Getv $cfg $dSection "user" ""
    $dSecret = Expand-UserPath (Getv $cfg $dSection "secret" "")
    $dRemoteApiHost = Getv $cfg $dSection "remote_api_host" "127.0.0.1"
    $dRemoteApiPort = [int](Getv $cfg $dSection "remote_api_port" "6443")
    $dLocalPort = [int](Getv $cfg $dSection "local_port" "6441")
    $dKubeconfig = Expand-UserPath (Getv $cfg $dSection "kubeconfig" "~/.kube/cluster-admin.conf")

    $available = New-Object System.Collections.Generic.List[string]
    if ($bHost -and $bUser -and $bApiServer) { $available.Add("bastion") }
    if ($dHost -and $dUser) { $available.Add("direct") }
    if ($available.Count -eq 0) { throw "no available mode" }

    Info "cluster: $Cluster"
    Info "available mode: $($available -join ', ')"

    $defaultMode = if ($available -contains $globalDefaultMode) { $globalDefaultMode } else { $available[0] }
    if (-not $Mode) {
        $Mode = Read-Host "mode (bastion/direct, default: $defaultMode)"
    }
    if ([string]::IsNullOrWhiteSpace($Mode)) { $Mode = $defaultMode }
    $Mode = $Mode.ToLowerInvariant().Trim()
    if (-not ($available -contains $Mode)) { throw "invalid mode: $Mode" }

    if ($Mode -eq "direct") {
        $hp = Split-HostPort -hostPort $dHost -defaultPort 22
        $auth = Build-SshAuthArgs -secretPath $dSecret
        Info "start direct tunnel: localhost:$dLocalPort -> ${dRemoteApiHost}:$dRemoteApiPort"
        $tunnelPid = Start-SshTunnel -baseAuthArgs $auth -sshUser $dUser -sshHost $hp.Host -sshPort $hp.Port -localPort $dLocalPort -remoteHost $dRemoteApiHost -remotePort $dRemoteApiPort -timeoutSec $globalTimeout
        Ok "tunnel started, pid=$tunnelPid"

        $dir = Split-Path -Parent $dKubeconfig
        if (!(Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
        Info "fetch /etc/kubernetes/admin.conf"
        Invoke-SshCommand -baseAuthArgs $auth -sshUser $dUser -sshHost $hp.Host -sshPort $hp.Port -timeoutSec $globalTimeout -remoteCommand "sudo cat /etc/kubernetes/admin.conf" | Set-Content -Path $dKubeconfig -Encoding UTF8
        Update-KubeconfigForLocalTunnel -kubeconfigPath $dKubeconfig -localPort $dLocalPort
        $env:KUBECONFIG = $dKubeconfig
        Ok "KUBECONFIG=$dKubeconfig"

        if (Test-KubeConnection -kubeconfigPath $dKubeconfig) { Ok "connection test ok" } else { Warn "connection test failed" }
        try { Show-Menu -kubeconfigPath $dKubeconfig } finally { Stop-TunnelQuietly }
    } else {
        $bastion = Split-HostPort -hostPort $bHost -defaultPort 22
        $target = Split-HostPort -hostPort $bApiServer -defaultPort 22
        $auth = Build-SshAuthArgs -secretPath $bSecret
        Info "start bastion tunnel: localhost:$bLocalPort -> $($target.Host):$bApiPort"
        $tunnelPid = Start-SshTunnel -baseAuthArgs $auth -sshUser $bUser -sshHost $bastion.Host -sshPort $bastion.Port -localPort $bLocalPort -remoteHost $target.Host -remotePort $bApiPort -timeoutSec $globalTimeout
        Ok "tunnel started, pid=$tunnelPid"

        $dir = Split-Path -Parent $bKubeconfig
        if (!(Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
        $apiUser = if ($bApiUser) { $bApiUser } else { $bUser }
        $remoteCmd = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p $($target.Port) $apiUser@$($target.Host) 'sudo cat /etc/kubernetes/admin.conf'"
        Invoke-SshCommand -baseAuthArgs $auth -sshUser $bUser -sshHost $bastion.Host -sshPort $bastion.Port -timeoutSec $globalTimeout -remoteCommand $remoteCmd | Set-Content -Path $bKubeconfig -Encoding UTF8
        Update-KubeconfigForLocalTunnel -kubeconfigPath $bKubeconfig -localPort $bLocalPort
        $env:KUBECONFIG = $bKubeconfig
        Ok "KUBECONFIG=$bKubeconfig"

        if (Test-KubeConnection -kubeconfigPath $bKubeconfig) { Ok "connection test ok" } else { Warn "connection test failed" }
        try { Show-Menu -kubeconfigPath $bKubeconfig } finally { Stop-TunnelQuietly }
    }
}
catch {
    Err $_.Exception.Message
    exit 1
}