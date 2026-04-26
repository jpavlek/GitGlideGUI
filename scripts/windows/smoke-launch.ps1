# Minimal Windows smoke-launch test for Git Glide GUI.
# Uses -SmokeTest so split script parts are parsed and imported, but the
# WinForms window is not shown.

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$versionPath = Join-Path $repoRoot 'VERSION'
if (-not (Test-Path -LiteralPath $versionPath)) {
    throw "VERSION file not found: $versionPath"
}

$version = (Get-Content -LiteralPath $versionPath -Raw).Trim()
$scriptPath = Join-Path $PSScriptRoot "GitGlideGUI-v$version.ps1"

if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Main GUI script not found: $scriptPath"
}

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath -SmokeTest
if ($LASTEXITCODE -ne 0) {
    throw "Smoke launch failed with exit code $LASTEXITCODE"
}

Write-Host 'Windows smoke-launch test passed.'
