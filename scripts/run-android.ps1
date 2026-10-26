param([string]$Device = '127.0.0.1:5555')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'enter-dev.ps1')
Set-Location (Split-Path $PSScriptRoot -Parent)
if ($Device -match '^127\.0\.0\.1:\d+$') { adb connect $Device }
. (Join-Path $PSScriptRoot 'start-hongguo.ps1') -Device $Device
flutter --no-version-check run -d $Device
exit $LASTEXITCODE
