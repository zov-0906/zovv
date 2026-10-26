param([int]$Port = 8765, [string]$Device = '127.0.0.1:5555', [switch]$MediaTrial = $true)
$ErrorActionPreference = 'Stop'
if ($Port -ne 8765) { throw 'The local gateway currently uses port 8765.' }
$projectRoot = Split-Path $PSScriptRoot -Parent
$nodePath = Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe'
$gatewayRoot = Join-Path $projectRoot 'tools\hongguo-gateway'
New-Item -ItemType Directory -Force (Join-Path $projectRoot 'artifacts\gateway') | Out-Null
$existing = $null
try { $existing = Invoke-RestMethod 'http://127.0.0.1:8765/health' -TimeoutSec 2 } catch {}
if ($existing -and $existing.service -ne 'zovv-hongguo') { throw 'Port 8765 is occupied by another service.' }
if (!$existing) {
  $previousMediaTrial = $env:HONGGUO_MEDIA_TRIAL
  $env:HONGGUO_MEDIA_TRIAL = if ($MediaTrial) { '1' } else { '0' }
  try {
  $process = Start-Process -FilePath $nodePath -ArgumentList 'server.cjs' -WorkingDirectory $gatewayRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $projectRoot 'artifacts\gateway\stdout.log') -RedirectStandardError (Join-Path $projectRoot 'artifacts\gateway\stderr.log')
  } finally { $env:HONGGUO_MEDIA_TRIAL = $previousMediaTrial }
  Write-Host "Hongguo local gateway PID: $($process.Id)"
  Start-Sleep -Milliseconds 600
}
. (Join-Path $PSScriptRoot 'enter-dev.ps1')
adb -s $Device reverse tcp:8765 tcp:8765
Invoke-RestMethod 'http://127.0.0.1:8765/health' -TimeoutSec 3
