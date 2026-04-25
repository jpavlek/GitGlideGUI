<#
ensure-psscriptanalyzer.ps1

Safe optional bootstrapper for PSScriptAnalyzer.

Default behavior:
- If PSScriptAnalyzer is installed: exit 0.
- If missing and no install flag/env var is set: print instructions and exit 0.
- If missing and install is explicitly enabled: install for CurrentUser.

Explicit install options:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\ensure-psscriptanalyzer.ps1 -InstallIfMissing -Diagnose

  set GITGLIDE_AUTO_INSTALL_TOOLS=1
  run-quality-checks.bat

Optional strict mode:
  set GITGLIDE_REQUIRE_SCRIPT_ANALYZER=1
#>

[CmdletBinding()]
param(
    [switch]$InstallIfMissing,
    [switch]$Required,
    [switch]$TrustPSGallery,
    [switch]$Diagnose
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-GghToolInfo {
    param([string]$Message)
    Write-Host "[GitGlide tools] $Message"
}

function Test-GghTruthyEnv {
    param([string]$Name)
    $value = [Environment]::GetEnvironmentVariable($Name)
    return ($value -match '^(1|true|yes|on)$')
}

function Get-GghKnownModuleRoots {
    $roots = New-Object System.Collections.Generic.List[string]

    foreach ($path in @($env:PSModulePath -split ';')) {
        if (-not [string]::IsNullOrWhiteSpace($path)) { $roots.Add($path.Trim()) }
    }

    $docs = [Environment]::GetFolderPath('MyDocuments')
    if (-not [string]::IsNullOrWhiteSpace($docs)) {
        $roots.Add((Join-Path $docs 'WindowsPowerShell\Modules'))
        $roots.Add((Join-Path $docs 'PowerShell\Modules'))
    }

    if (-not [string]::IsNullOrWhiteSpace($env:ProgramFiles)) {
        $roots.Add((Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules'))
        $roots.Add((Join-Path $env:ProgramFiles 'PowerShell\Modules'))
    }

    return @($roots | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
}

function Add-GghModuleRootForCurrentProcess {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    $existing = @($env:PSModulePath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($existing -notcontains $Path) {
        $env:PSModulePath = ($existing + $Path) -join ';'
    }
}

function Add-GghKnownUserModuleRootsForCurrentProcess {
    foreach ($root in Get-GghKnownModuleRoots) {
        Add-GghModuleRootForCurrentProcess -Path $root
    }
}

function Get-GghPSScriptAnalyzerModule {
    Add-GghKnownUserModuleRootsForCurrentProcess
    $modules = @(Get-Module -ListAvailable -Name PSScriptAnalyzer -ErrorAction SilentlyContinue)
    if ($modules.Count -eq 0) { return $null }
    return ($modules | Sort-Object Version -Descending | Select-Object -First 1)
}

function Show-GghDiagnostics {
    Write-GghToolInfo "PowerShell: $($PSVersionTable.PSVersion)"
    Write-GghToolInfo "PSHOME: $PSHOME"
    Write-GghToolInfo "MyDocuments: $([Environment]::GetFolderPath('MyDocuments'))"
    Write-GghToolInfo 'PSModulePath entries:'
    foreach ($path in @($env:PSModulePath -split ';')) {
        if (-not [string]::IsNullOrWhiteSpace($path)) {
            Write-Host "  $path  exists=$(Test-Path -LiteralPath $path)"
        }
    }

    Write-GghToolInfo 'Known PSScriptAnalyzer folders:'
    foreach ($root in Get-GghKnownModuleRoots) {
        $candidate = Join-Path $root 'PSScriptAnalyzer'
        if (Test-Path -LiteralPath $candidate) {
            Write-Host "  FOUND: $candidate"
            Get-ChildItem -LiteralPath $candidate -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    $($_.FullName)" }
        } else {
            Write-Host "  missing: $candidate"
        }
    }

    Write-GghToolInfo 'PowerShellGet commands:'
    foreach ($cmdName in @('Install-Module','Save-Module','Find-Module','Install-PSResource')) {
        $cmd = Get-Command -Name $cmdName -ErrorAction SilentlyContinue
        if ($null -eq $cmd) { Write-Host "  ${cmdName}: missing" } else { Write-Host "  ${cmdName}: $($cmd.Source) $($cmd.Version)" }
    }

    Write-GghToolInfo 'Registered repositories:'
    try { Get-PSRepository | Format-Table -AutoSize | Out-String | Write-Host } catch { Write-Host "  Get-PSRepository failed: $($_.Exception.Message)" }

    Write-GghToolInfo 'Package providers:'
    try { Get-PackageProvider | Format-Table -AutoSize | Out-String | Write-Host } catch { Write-Host "  Get-PackageProvider failed: $($_.Exception.Message)" }
}

function Enable-GghTls12ForWindowsPowerShell {
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        try {
            $currentProtocol = [Net.ServicePointManager]::SecurityProtocol
            [Net.ServicePointManager]::SecurityProtocol = $currentProtocol -bor [Net.SecurityProtocolType]::Tls12
        } catch {
            Write-GghToolInfo "TLS 1.2 setup warning: $($_.Exception.Message)"
        }
    }
}

function Ensure-GghPSGalleryAvailable {
    $repo = $null
    try { $repo = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue } catch {}
    if ($null -eq $repo) {
        Write-GghToolInfo 'PSGallery is not registered. Registering default repository...'
        Register-PSRepository -Default -ErrorAction Stop
    }

    if ($TrustPSGallery -or (Test-GghTruthyEnv -Name 'GITGLIDE_TRUST_PSGALLERY')) {
        try {
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
            Write-GghToolInfo 'PSGallery was marked as trusted because TrustPSGallery/GITGLIDE_TRUST_PSGALLERY was used.'
        } catch {
            Write-GghToolInfo "Could not update PSGallery trust policy: $($_.Exception.Message)"
        }
    }
}

function Ensure-GghNuGetProvider {
    try {
        $nuget = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
        if ($null -eq $nuget) {
            Write-GghToolInfo 'NuGet provider is missing. Installing NuGet provider for CurrentUser...'
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force -ErrorAction Stop | Out-Null
        }
    } catch {
        Write-GghToolInfo "NuGet provider bootstrap warning: $($_.Exception.Message)"
    }
}

function Get-GghWindowsPowerShellUserModuleRoot {
    $docs = [Environment]::GetFolderPath('MyDocuments')
    if ([string]::IsNullOrWhiteSpace($docs)) { throw 'Could not resolve MyDocuments folder.' }
    return (Join-Path $docs 'WindowsPowerShell\Modules')
}

function Install-GghPSScriptAnalyzer {
    Enable-GghTls12ForWindowsPowerShell
    Ensure-GghPSGalleryAvailable

    $installPSResource = Get-Command -Name Install-PSResource -ErrorAction SilentlyContinue
    if ($null -ne $installPSResource -and $PSVersionTable.PSVersion.Major -ge 7) {
        Write-GghToolInfo 'Trying Install-PSResource...'
        Install-PSResource -Name PSScriptAnalyzer -Scope CurrentUser -Reinstall -TrustRepository -ErrorAction Stop
    } else {
        $installModule = Get-Command -Name Install-Module -ErrorAction SilentlyContinue
        if ($null -eq $installModule) {
            throw 'Install-Module is not available in this PowerShell session.'
        }

        Ensure-GghNuGetProvider
        Write-GghToolInfo 'Trying Install-Module...'
        Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force -AllowClobber -Repository PSGallery -ErrorAction Stop -Verbose
    }

    $installed = Get-GghPSScriptAnalyzerModule
    if ($null -ne $installed) { return $installed }

    $saveModule = Get-Command -Name Save-Module -ErrorAction SilentlyContinue
    if ($null -eq $saveModule) {
        throw 'Install completed but PSScriptAnalyzer still cannot be found, and Save-Module is not available for fallback.'
    }

    $targetRoot = Get-GghWindowsPowerShellUserModuleRoot
    if (-not (Test-Path -LiteralPath $targetRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null
    }
    Add-GghModuleRootForCurrentProcess -Path $targetRoot

    Write-GghToolInfo "Install-Module did not produce a discoverable module. Trying Save-Module fallback into: $targetRoot"
    Save-Module -Name PSScriptAnalyzer -Path $targetRoot -Repository PSGallery -Force -ErrorAction Stop -Verbose

    $installed = Get-GghPSScriptAnalyzerModule
    if ($null -eq $installed) {
        throw 'Save-Module fallback completed but PSScriptAnalyzer still cannot be found by Get-Module -ListAvailable.'
    }
    return $installed
}

Add-GghKnownUserModuleRootsForCurrentProcess

if ($Diagnose -or (Test-GghTruthyEnv -Name 'GITGLIDE_DIAGNOSE_TOOLS')) {
    Show-GghDiagnostics
}

$existing = Get-GghPSScriptAnalyzerModule
if ($null -ne $existing) {
    Write-GghToolInfo "PSScriptAnalyzer is installed: version $($existing.Version) at $($existing.ModuleBase)"
    try {
        Import-Module PSScriptAnalyzer -Force -ErrorAction Stop
        $command = Get-Command Invoke-ScriptAnalyzer -ErrorAction Stop
        Write-GghToolInfo "Invoke-ScriptAnalyzer available from: $($command.Source)"
    } catch {
        Write-GghToolInfo "PSScriptAnalyzer was found but could not be imported: $($_.Exception.Message)"
        exit 1
    }
    exit 0
}

$autoInstall = $InstallIfMissing -or (Test-GghTruthyEnv -Name 'GITGLIDE_AUTO_INSTALL_TOOLS') -or (Test-GghTruthyEnv -Name 'GITGLIDE_AUTO_INSTALL_PSSCRIPTANALYZER')
$mustHave = $Required -or (Test-GghTruthyEnv -Name 'GITGLIDE_REQUIRE_SCRIPT_ANALYZER')

if (-not $autoInstall) {
    Write-GghToolInfo 'PSScriptAnalyzer is not installed. Lint checks will be skipped.'
    Write-GghToolInfo 'Manual install options:'
    Write-Host '  Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force -AllowClobber -Repository PSGallery'
    Write-Host '  # or, for Windows PowerShell 5.1 fallback:'
    Write-Host '  $p = Join-Path ([Environment]::GetFolderPath(''MyDocuments'')) ''WindowsPowerShell\Modules''; Save-Module -Name PSScriptAnalyzer -Path $p -Force'
    Write-GghToolInfo 'Or run this bootstrapper with -InstallIfMissing -Diagnose.'
    if ($mustHave) { exit 2 }
    exit 0
}

Write-GghToolInfo 'PSScriptAnalyzer is missing and automatic install was explicitly enabled.'
try {
    $installed = Install-GghPSScriptAnalyzer
    Write-GghToolInfo "PSScriptAnalyzer installed: version $($installed.Version) at $($installed.ModuleBase)"
    Import-Module PSScriptAnalyzer -Force -ErrorAction Stop
    $command = Get-Command Invoke-ScriptAnalyzer -ErrorAction Stop
    Write-GghToolInfo "Invoke-ScriptAnalyzer available from: $($command.Source)"
    exit 0
} catch {
    Write-GghToolInfo "Failed to install PSScriptAnalyzer: $($_.Exception.Message)"
    Write-GghToolInfo 'Run diagnostics with:'
    Write-Host '  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\ensure-psscriptanalyzer.ps1 -InstallIfMissing -Diagnose'
    exit 1
}