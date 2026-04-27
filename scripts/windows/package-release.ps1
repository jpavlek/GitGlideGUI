param(
    [string]$Version = '',
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$Output = ''
)
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'GitGlideVersion.ps1')

$Version = Resolve-GitGlideVersion -RepositoryRoot $Root -ExplicitVersion $Version

if ([string]::IsNullOrWhiteSpace($Output)) {
    $parent = Split-Path -Parent $Root
    $Output = Join-Path $parent ("GitGlideGUI_v$($Version.Replace('.', '_'))_functional.zip")
}

$stage = Join-Path ([System.IO.Path]::GetTempPath()) ("GitGlideGUI_package_$([Guid]::NewGuid().ToString('N'))")
New-Item -ItemType Directory -Path $stage | Out-Null
try {
    $excludeDirs = @('.git','.gitglide-test-temp','logs','dist','release','packages','node_modules')
    Get-ChildItem -LiteralPath $Root -Force | Where-Object { $excludeDirs -notcontains $_.Name } | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $stage -Recurse -Force
    }
    Get-ChildItem -LiteralPath $stage -Recurse -Force -File | Where-Object {
        $_.Name -like '*.bak.*' -or $_.Name -like '*.backup.*' -or $_.Name -like '*.tmp' -or $_.Name -like '*.log' -or $_.Name -like '*.zip' -or $_.Name -like '*.7z' -or $_.Name -like '*.rar' -or $_.Name -like '*.nupkg' -or $_.Name -eq 'GitGlideGUI-Config.json' -or $_.Name -eq 'GitFlowGUI-Config.json'
    } | Remove-Item -Force
    if (Test-Path -LiteralPath $Output) { Remove-Item -LiteralPath $Output -Force }
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $Output -Force
    Write-Output "Created: $Output"
} finally {
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
}
