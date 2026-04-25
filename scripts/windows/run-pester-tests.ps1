$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$tests = Join-Path $root 'tests'

function Remove-InvalidPathEntriesFromEnvVar {
    param([Parameter(Mandatory=$true)][string]$Name)
    $value = [Environment]::GetEnvironmentVariable($Name, 'Process')
    if ([string]::IsNullOrWhiteSpace($value)) { return }

    $valid = New-Object System.Collections.Generic.List[string]
    foreach ($entry in @($value -split ';')) {
        if ([string]::IsNullOrWhiteSpace($entry)) { continue }
        $trimmed = $entry.Trim()
        $expanded = [Environment]::ExpandEnvironmentVariables($trimmed)
        if (Test-Path -LiteralPath $expanded) {
            [void]$valid.Add($trimmed)
        } else {
            Write-Host "Ignoring invalid $Name path for Pester: $entry" -ForegroundColor DarkYellow
        }
    }
    [Environment]::SetEnvironmentVariable($Name, ($valid -join ';'), 'Process')
}

function Convert-GitGlideTestsForPester3 {
    param(
        [Parameter(Mandatory=$true)][string]$SourceRoot,
        [Parameter(Mandatory=$true)][string]$PackageRoot
    )

    $compatRoot = Join-Path $PackageRoot '.gitglide-test-temp\pester3'
    if (Test-Path -LiteralPath $compatRoot) { Remove-Item -LiteralPath $compatRoot -Recurse -Force }
    New-Item -ItemType Directory -Path $compatRoot | Out-Null
    Copy-Item -LiteralPath (Join-Path $PackageRoot 'modules') -Destination (Join-Path $compatRoot 'modules') -Recurse -Force
    Copy-Item -LiteralPath $SourceRoot -Destination (Join-Path $compatRoot 'tests') -Recurse -Force

    foreach ($testFile in Get-ChildItem -LiteralPath (Join-Path $compatRoot 'tests') -Filter '*.ps1' -Recurse) {
        $content = Get-Content -LiteralPath $testFile.FullName -Raw

        # Pester 3's "Should Contain" checks file content, not collection membership.
        # Convert modern collection assertions into explicit boolean expressions.
        $content = [regex]::Replace($content, '(?m)^(\s*)(.+?)\s*\|\s*Should\s+-Not\s+-Contain\s+(.+?)\s*$', '$1(@($2) -notcontains $3) | Should Be $true')
        $content = [regex]::Replace($content, '(?m)^(\s*)(.+?)\s*\|\s*Should\s+-Contain\s+(.+?)\s*$', '$1(@($2) -contains $3) | Should Be $true')

        $content = $content -replace '\| Should -Not -Match', '| Should Not Match'
        $content = $content -replace '\| Should -BeNullOrEmpty', '| Should BeNullOrEmpty'
        $content = $content -replace '\| Should -BeGreaterThan', '| Should BeGreaterThan'
        $content = $content -replace '\| Should -BeTrue', '| Should Be $true'
        $content = $content -replace '\| Should -BeFalse', '| Should Be $false'
        $content = $content -replace '\| Should -Throw', '| Should Throw'
        $content = $content -replace '\| Should -Match', '| Should Match'
        $content = $content -replace '\| Should -Be', '| Should Be'
        Set-Content -LiteralPath $testFile.FullName -Value $content -Encoding UTF8
    }

    return (Join-Path $compatRoot 'tests')
}

function Invoke-GitGlidePesterCompat {
    param([Parameter(Mandatory=$true)][string]$Path)

    $cmd = Get-Command Invoke-Pester -ErrorAction Stop
    $parameters = $cmd.Parameters
    $invokeArgs = @{ Path = $Path }

    # Avoid -Output unless the exact parameter exists.
    # Pester 5+ supports -Output Detailed. Pester 3.x/4.x can treat -Output
    # as ambiguous, so only pass it when the exact parameter exists.
    if ($parameters.ContainsKey('Output')) {
        $invokeArgs['Output'] = 'Detailed'
    }

    Write-Host "Running Pester tests in: $Path" -ForegroundColor Cyan
    $pesterModule = Get-Module Pester | Select-Object -First 1
    if ($pesterModule) {
        Write-Host ("Using Pester {0}" -f $pesterModule.Version) -ForegroundColor DarkGray
    }

    if ($parameters.ContainsKey('PassThru')) {
        $invokeArgs['PassThru'] = $true
        $result = Invoke-Pester @invokeArgs
        if ($null -ne $result) {
            $failed = 0
            foreach ($propertyName in @('FailedCount', 'Failed', 'TotalFailed')) {
                if ($result.PSObject.Properties.Name -contains $propertyName) {
                    $failed = [int]$result.$propertyName
                    break
                }
            }
            if ($failed -gt 0) { exit 1 }
        }
        exit 0
    }

    Invoke-Pester @invokeArgs
    if ($?) { exit 0 }
    exit 1
}

# Pester 3.x compiles small C# helpers during import. On some developer machines
# stale GTK/Visual Studio paths in LIB/INCLUDE are treated as compiler warnings-as-errors.
# Cleaning only the current process environment keeps the user profile unchanged.
Remove-InvalidPathEntriesFromEnvVar -Name 'LIB'
Remove-InvalidPathEntriesFromEnvVar -Name 'INCLUDE'
Remove-InvalidPathEntriesFromEnvVar -Name 'LIBPATH'

if (-not (Get-Module -ListAvailable -Name Pester)) {
    Write-Host 'Pester is not installed. Install-Module Pester -Scope CurrentUser to run PowerShell tests.' -ForegroundColor Yellow
    exit 0
}

try {
    Import-Module Pester -ErrorAction Stop
} catch {
    Write-Host 'Pester could not be imported after sanitizing LIB/INCLUDE/LIBPATH.' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

$pesterModule = Get-Module Pester | Select-Object -First 1
$testsToRun = $tests
if ($pesterModule -and $pesterModule.Version.Major -lt 4) {
    Write-Host 'Detected Pester 3.x. Creating compatibility test copy with legacy Should syntax.' -ForegroundColor DarkYellow
    $testsToRun = Convert-GitGlideTestsForPester3 -SourceRoot $tests -PackageRoot $root
}

Invoke-GitGlidePesterCompat -Path $testsToRun
