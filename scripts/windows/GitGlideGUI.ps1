# Git Glide GUI stable split entrypoint.
# Runtime script names are intentionally version-independent. Product version
# comes from the repository-level VERSION file to reduce release churn.

param(
    [string]$RepositoryPath = '',
    [switch]$SmokeTest
)

$ErrorActionPreference = 'Stop'

function Get-GitGlideVersion {
    param([string]$ScriptDirectory = $PSScriptRoot)

    $repoRoot = Resolve-Path (Join-Path $ScriptDirectory '..\..')
    $versionPath = Join-Path $repoRoot 'VERSION'
    if (Test-Path -LiteralPath $versionPath -PathType Leaf) {
        $candidate = (Get-Content -LiteralPath $versionPath -Raw).Trim()
        if (-not [string]::IsNullOrWhiteSpace($candidate)) { return $candidate }
    }

    return '0.0.0-dev'
}

$script:GitGlideGuiVersion = Get-GitGlideVersion -ScriptDirectory $PSScriptRoot
$script:GitGlideGuiScriptDirectory = $PSScriptRoot

$script:GitGlideGuiParts = @(
    'GitGlideGUI.part01-bootstrap-config.ps1',
    'GitGlideGUI.part02-state-selection.ps1',
    'GitGlideGUI.part03-previews-basic-ops.ps1',
    'GitGlideGUI.part04-recovery-push-stash-tags.ps1',
    'GitGlideGUI.part05-ui.ps1'
)
$script:GitGlideGuiRunPart = 'GitGlideGUI.part06-run.ps1'

foreach ($partName in $script:GitGlideGuiParts) {
    $partPath = Join-Path $PSScriptRoot $partName
    if (-not (Test-Path -LiteralPath $partPath -PathType Leaf)) {
        throw "Git Glide GUI script part missing: $partPath"
    }

    if ($partName -eq 'GitGlideGUI.part01-bootstrap-config.ps1') {
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
    Write-Host ("Git Glide GUI v{0} smoke launch OK. Split script parts parsed and initialized." -f $script:GitGlideGuiVersion)
    exit 0
}

. $runPartPath
