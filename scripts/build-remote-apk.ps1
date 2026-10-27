param(
  [string]$GatewayUrl = 'https://140.143.201.224:8443',
  [string]$TokenFile = 'artifacts\gateway\deploy-token.txt',
  [string]$FlutterArgs = ''
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$token = (Get-Content (Join-Path $root $TokenFile) -Raw).Trim()
if (-not $token) { throw "缺少网关令牌：$TokenFile" }
Push-Location $root
try {
  . (Join-Path $PSScriptRoot 'enter-dev.ps1')
  $defines = @(
    "--dart-define=ZOVV_GATEWAY=$GatewayUrl",
    "--dart-define=ZOVV_GATEWAY_TOKEN=$token",
    '--dart-define=ZOVV_STREAM_PLAYBACK=true'
  )
  if ($FlutterArgs) { $defines += $FlutterArgs.Split(' ') }
  $args = @('--no-version-check', 'build', 'apk', '--debug',
    '--target-platform', 'android-x64,android-arm64') + $defines
  & flutter @args
  if ($LASTEXITCODE -ne 0) { throw "构建失败：$LASTEXITCODE" }
  Write-Host '产物：build\app\outputs\flutter-apk\app-debug.apk'
  Write-Host "网关：$GatewayUrl"
} finally {
  Pop-Location
}
