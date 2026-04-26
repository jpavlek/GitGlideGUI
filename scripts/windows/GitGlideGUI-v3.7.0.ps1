# Git Glide GUI - Enhanced Version v3.7.0
# Split entrypoint. The implementation is intentionally divided into smaller
# files to reduce technical debt and avoid copying another 8k+ line script.

param(
    [string]$RepositoryPath = '',
    [switch]$SmokeTest
)

$ErrorActionPreference = 'Stop'
$script:GitGlideGuiVersion = '3.7.0'
$script:GitGlideGuiScriptDirectory = $PSScriptRoot

$script:GitGlideGuiParts = @(
    'GitGlideGUI-v3.7.0.part01-bootstrap-config.ps1',
    'GitGlideGUI-v3.7.0.part02-state-selection.ps1',
    'GitGlideGUI-v3.7.0.part03-previews-basic-ops.ps1',
    'GitGlideGUI-v3.7.0.part04-recovery-push-stash-tags.ps1',
    'GitGlideGUI-v3.7.0.part05-ui.ps1'
)
$script:GitGlideGuiRunPart = 'GitGlideGUI-v3.7.0.part06-run.ps1'

foreach ($partName in $script:GitGlideGuiParts) {
    $partPath = Join-Path $PSScriptRoot $partName
    if (-not (Test-Path -LiteralPath $partPath -PathType Leaf)) {
        throw "Git Glide GUI script part missing: $partPath"
    }

    if ($partName -eq 'GitGlideGUI-v3.7.0.part01-bootstrap-config.ps1') {
        . $partPath -RepositoryPath $RepositoryPath -SmokeTest:$SmokeTest
    } else {
        . $partPath
    }
}

$runPartPath = Join-Path $PSScriptRoot $script:GitGlideGuiRunPart
if (-not (Test-Path -LiteralPath $runPartPath -PathType Leaf)) {
    throw "Git Glide GUI run part missing: $runPartPath"
}

# Parse the run part during smoke tests without showing the WinForms window.
[scriptblock]::Create((Get-Content -Raw -LiteralPath $runPartPath)) > $null

if ($SmokeTest) {
    Write-Host 'Git Glide GUI v3.7.0 smoke launch OK. Split script parts parsed and initialized.'
    exit 0
}

. $runPartPath
