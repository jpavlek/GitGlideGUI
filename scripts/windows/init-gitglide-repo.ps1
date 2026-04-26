param(
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$Version = '3.6.11',
    [string]$RemoteUrl = '',
    [switch]$SkipQualityChecks
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-GitGlideGit {
    param([string[]]$Arguments, [switch]$AllowFailure)
    & git -C $RepositoryRoot @Arguments
    $code = $LASTEXITCODE
    if ($code -ne 0 -and -not $AllowFailure) { throw "git $($Arguments -join ' ') failed with exit code $code" }
    return $code
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'git.exe was not found on PATH.' }
if (-not (Test-Path $RepositoryRoot)) { throw "Repository root does not exist: $RepositoryRoot" }

Write-Host "Git Glide GUI repository root: $RepositoryRoot"

if (-not (Test-Path (Join-Path $RepositoryRoot '.git'))) {
    Write-Host 'Initializing new Git repository...'
    & git -C $RepositoryRoot init -b main
    if ($LASTEXITCODE -ne 0) {
        & git -C $RepositoryRoot init
        if ($LASTEXITCODE -ne 0) { throw 'git init failed.' }
        & git -C $RepositoryRoot branch -M main
        if ($LASTEXITCODE -ne 0) { throw 'git branch -M main failed.' }
    }
} else {
    Write-Host 'Existing Git repository detected.'
}

if (-not $SkipQualityChecks) {
    $quality = Join-Path $RepositoryRoot 'run-quality-checks.bat'
    if (Test-Path $quality) {
        Write-Host 'Running quality checks before initial commit...'
        & $quality
        if ($LASTEXITCODE -ne 0) { throw "Quality checks failed with exit code $LASTEXITCODE. Commit aborted." }
    }
}

Invoke-GitGlideGit -Arguments @('add','-A') | Out-Null
$status = & git -C $RepositoryRoot status --porcelain=v1
if ($status) {
    Invoke-GitGlideGit -Arguments @('commit','-m',"chore: initialize Git Glide GUI repository at v$Version") | Out-Null
} else {
    Write-Host 'No changes to commit.'
}

$existingTag = & git -C $RepositoryRoot tag --list "v$Version"
if (-not $existingTag) {
    Invoke-GitGlideGit -Arguments @('tag','-a',"v$Version",'-m',"Git Glide GUI v$Version") | Out-Null
    Write-Host "Created tag v$Version"
} else {
    Write-Host "Tag v$Version already exists."
}

if ($RemoteUrl.Trim()) {
    $remote = & git -C $RepositoryRoot remote get-url origin 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $remote) {
        Invoke-GitGlideGit -Arguments @('remote','add','origin',$RemoteUrl) | Out-Null
    } else {
        Invoke-GitGlideGit -Arguments @('remote','set-url','origin',$RemoteUrl) | Out-Null
    }
    Write-Host 'Remote origin configured.'
}

Write-Host 'Repository bootstrap completed.'
Write-Host 'Next commands:'
Write-Host '  git status'
Write-Host '  git log --oneline --decorate -n 5'
Write-Host '  git push -u origin main'
Write-Host '  git push origin --tags'
