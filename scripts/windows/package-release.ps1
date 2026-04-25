# Git Glide GUI mandatory release packaging gate.
# Run this from Windows PowerShell. It refuses to package when static checks,
# the WinForms smoke-launch parser/import check, Pester, or ScriptAnalyzer fail.
# The final ZIP is created from a clean staging folder so test temp files,
# logs, user config, nested archives, and repository metadata are excluded.

param(
    [string]$Version = '3.6.7',
    [string]$OutputZip = ''
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Push-Location $root
try {
    Write-Host "=== Git Glide GUI v$Version release packaging gate ==="

    Write-Host "`n[1/4] Static package smoke test"
    python tests\static_smoke_test.py
    if ($LASTEXITCODE -ne 0) { throw 'Static smoke test failed.' }

    Write-Host "`n[2/4] Mandatory Windows smoke launch test"
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\windows\smoke-launch.ps1
    if ($LASTEXITCODE -ne 0) { throw 'Mandatory smoke launch failed; release package will not be created.' }

    Write-Host "`n[3/4] Pester tests"
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\windows\run-pester-tests.ps1
    if ($LASTEXITCODE -ne 0) { throw 'Pester tests failed.' }

    Write-Host "`n[4/4] ScriptAnalyzer checks"
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\windows\run-scriptanalyzer.ps1
    if ($LASTEXITCODE -ne 0) { throw 'ScriptAnalyzer checks failed.' }

    if ([string]::IsNullOrWhiteSpace($OutputZip)) {
        $OutputZip = Join-Path (Split-Path $root -Parent) ("GitGlideGUI_v{0}_functional.zip" -f ($Version -replace '\.', '_'))
    }

    if (Test-Path -LiteralPath $OutputZip) {
        Remove-Item -LiteralPath $OutputZip -Force
    }

    $stage = Join-Path ([System.IO.Path]::GetTempPath()) ('GitGlideGUI-package-' + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stage -Force | Out-Null

    $excludeDirs = @('.git', '.gitglide-test-temp', 'logs', 'dist', 'release', 'packages', 'node_modules')
    $excludeFiles = @('*.bak.*', '*.backup.*', '*.tmp', '*.log', '*.zip', '*.7z', '*.rar', '*.nupkg', 'GitGlideGUI-Config.json', 'GitFlowGUI-Config.json')

    Write-Host "`nStaging clean package content..."
    $robocopyArgs = @($root.Path, $stage, '/E', '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/XD') + $excludeDirs + @('/XF') + $excludeFiles
    & robocopy @robocopyArgs | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE" }

    Write-Host "Packaging release: $OutputZip"
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $OutputZip -Force
    Write-Host 'Release package created only after mandatory smoke-launch and Pester gates passed.'
}
finally {
    if ($stage -and (Test-Path -LiteralPath $stage)) { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue }
    Pop-Location
}
