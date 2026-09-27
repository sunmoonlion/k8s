# Compatibility entry only: SUNMOON_DATA_LAYOUT_V1. No independent mount logic.
$ErrorActionPreference = 'Stop'
$Entry = Join-Path $PSScriptRoot '..\deploy-kind\attach-vhds.ps1'
if (-not (Test-Path -LiteralPath $Entry -PathType Leaf)) { throw 'Use the full reviewed checkout; canonical attach script missing' }
& $Entry @args
