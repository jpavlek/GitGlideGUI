# Minimal Windows smoke-launch test for Git Glide GUI.
# This intentionally uses -SmokeTest so it parses the full GUI script and imports modules,
# but exits before opening the WinForms window.

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot 'GitGlideGUI-v3.6.9.ps1'
if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Main GUI script not found: $scriptPath"
}

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath -SmokeTest
if ($LASTEXITCODE -ne 0) {
    throw "Smoke launch failed with exit code $LASTEXITCODE"
}

Write-Host 'Windows smoke-launch test passed.'
