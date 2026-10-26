$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$toolRoot = Join-Path $projectRoot '.toolchain'
$env:FLUTTER_ROOT = Join-Path $toolRoot 'flutter'
$env:ANDROID_HOME = Join-Path $toolRoot 'android-sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$jdk = Get-ChildItem (Join-Path $toolRoot 'java') -Directory | Select-Object -First 1
if (!$jdk) { throw 'Java installation is incomplete.' }
$env:JAVA_HOME = $jdk.FullName
$env:PUB_CACHE = Join-Path $toolRoot 'pub-cache'
$env:GRADLE_USER_HOME = Join-Path $toolRoot 'gradle'
$gitCommand = Get-Command git.exe -ErrorAction SilentlyContinue
if (!$gitCommand) {
  $bundledGit = Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\native\git\cmd'
  if (Test-Path (Join-Path $bundledGit 'git.exe')) { $env:Path = "$bundledGit;$env:Path" }
}
$env:Path = "$env:FLUTTER_ROOT\bin;$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:ANDROID_HOME\cmdline-tools\latest\bin;$env:Path"
Write-Host 'ZOVV Flutter/Android environment loaded.'
