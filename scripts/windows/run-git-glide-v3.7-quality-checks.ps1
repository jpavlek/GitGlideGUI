param(
    [string]$ScriptPath = "scripts/windows/GitGlideGUI-v3.7.0.ps1"
)

$ErrorActionPreference = 'Stop'

function Write-Check {
    param([string]$Name, [bool]$Ok, [string]$Details = '')
    $prefix = if ($Ok) { '[OK] ' } else { '[FAIL] ' }
    Write-Host ($prefix + $Name)
    if (-not [string]::IsNullOrWhiteSpace($Details)) { Write-Host ('      ' + $Details) }
    if (-not $Ok) { $script:Failed = $true }
}

$script:Failed = $false

if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
    Write-Check -Name 'Script exists' -Ok $false -Details $ScriptPath
    exit 1
}

Write-Check -Name 'Script exists' -Ok $true -Details $ScriptPath

$content = Get-Content -Raw -LiteralPath $ScriptPath

$markers = Select-String -Path $ScriptPath -Pattern '^<<<<<<< .+$|^=======$|^>>>>>>> .+$'
Write-Check -Name 'No unresolved Git conflict marker lines' -Ok (-not $markers) -Details ($(if ($markers) { ($markers | Select-Object -First 5 | ForEach-Object { "$($_.LineNumber): $($_.Line.Trim())" }) -join '; ' } else { '' }))

try {
    [scriptblock]::Create($content) > $null
    Write-Check -Name 'PowerShell parser accepts GUI script' -Ok $true
} catch {
    Write-Check -Name 'PowerShell parser accepts GUI script' -Ok $false -Details $_.Exception.Message
}

Write-Check -Name 'AppVersion is 3.7.0' -Ok ($content -match "\$script:AppVersion\s*=\s*'3\.7\.0'")
Write-Check -Name 'Repository State Doctor exists' -Ok ($content -match 'function\s+Get-RepositoryStateDoctorSnapshot')
Write-Check -Name 'Conflict marker scanner exists' -Ok ($content -match 'function\s+Show-ConflictMarkerScan')
Write-Check -Name 'Dynamic banner resize helper exists' -Ok ($content -match 'function\s+Resize-ChangedFilesContextBanner')

if ($script:Failed) {
    Write-Host ''
    Write-Host 'Git Glide v3.7 quality checks failed.'
    exit 1
}

Write-Host ''
Write-Host 'Git Glide v3.7 quality checks passed.'
exit 0
