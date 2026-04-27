# Minimal Windows smoke-launch test for Git Glide GUI.
# Uses -SmokeTest so split script parts are parsed and imported, but the
# WinForms window is not shown.

$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'GitGlideGUI.ps1'
if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Main GUI script not found: $scriptPath"
}

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath -SmokeTest
if ($LASTEXITCODE -ne 0) {
    throw "Smoke launch failed with exit code $LASTEXITCODE"
}

Write-Host 'Windows smoke-launch test passed.'
