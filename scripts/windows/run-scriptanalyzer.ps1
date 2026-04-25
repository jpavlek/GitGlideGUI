param(
    [switch]$Strict,
    [switch]$IncludeTests,
    [switch]$FailOnWarning
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$settingsPath = Join-Path $root 'PSScriptAnalyzerSettings.psd1'

if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Write-Host 'PSScriptAnalyzer is not installed. Install-Module PSScriptAnalyzer -Scope CurrentUser to run lint checks.' -ForegroundColor Yellow
    exit 0
}

Import-Module PSScriptAnalyzer -ErrorAction Stop

$paths = @(
    (Join-Path $root 'modules'),
    (Join-Path $root 'scripts'),
    (Join-Path $root 'git-glide-gui.bat')
) | Where-Object { Test-Path -LiteralPath $_ }

if ($IncludeTests) { $paths += (Join-Path $root 'tests') }

$results = @()
foreach ($path in $paths) {
    if ($Strict -or -not (Test-Path -LiteralPath $settingsPath)) {
        $results += @(Invoke-ScriptAnalyzer -Path $path -Recurse -Severity Warning,Error)
    } else {
        $results += @(Invoke-ScriptAnalyzer -Path $path -Recurse -Settings $settingsPath)
    }
}

# Exclude generated or transient paths even when a caller runs from a dirty working tree.
$results = @($results | Where-Object {
    $name = [string]$_.ScriptPath
    ($name -notmatch '\\.gitglide-test-temp\\|/\\.gitglide-test-temp/') -and
    ($name -notmatch '\\.git\\|/\\.git/') -and
    ($name -notmatch '\\node_modules\\|/node_modules/') -and
    ($name -notmatch '\\dist\\|/dist/') -and
    ($name -notmatch '\\release\\|/release/') -and
    ($name -notmatch '\\packages\\|/packages/')
})

$errorCount = @($results | Where-Object { $_.Severity -eq 'Error' }).Count
$warningCount = @($results | Where-Object { $_.Severity -eq 'Warning' }).Count

if (@($results).Count -eq 0) {
    Write-Host 'PSScriptAnalyzer completed: no findings in the curated quality gate.' -ForegroundColor Green
    exit 0
}

$results | Sort-Object Severity, ScriptName, Line | Format-Table -AutoSize
Write-Host ("PSScriptAnalyzer completed: {0} error(s), {1} warning(s)." -f $errorCount, $warningCount)

if ($errorCount -gt 0) { exit 1 }
if ($FailOnWarning -and $warningCount -gt 0) { exit 1 }
exit 0
