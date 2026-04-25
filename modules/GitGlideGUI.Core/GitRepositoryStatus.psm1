# GitGlideGUI.Core - Repository status helpers for Git Glide GUI
# PowerShell 5.1 compatible. Keep this module UI-free so it can be tested without WinForms.

Set-StrictMode -Version 2.0

function ConvertFrom-GfgPorcelainStatusLine {
    param([string]$Line)

    if ([string]::IsNullOrWhiteSpace($Line) -or $Line.Length -lt 4) { return $null }

    $status = $Line.Substring(0, 2)
    $rawPath = $Line.Substring(3)
    $path = $rawPath
    $originalPath = $null

    # Porcelain v1 represents renames/copies as: old/path -> new/path.
    # Keep the raw display path, but use the new path for path-specific git calls.
    if ($rawPath -match '^(?<old>.+) -> (?<new>.+)$') {
        $originalPath = $matches['old']
        $path = $matches['new']
    }

    return [pscustomobject]@{
        Status = $status
        IndexStatus = $status.Substring(0,1)
        WorkTreeStatus = $status.Substring(1,1)
        Path = $path
        RawPath = $rawPath
        OriginalPath = $originalPath
    }
}

function ConvertFrom-GfgStatusBranchLine {
    param([string]$BranchLine)

    $branch = '(detached?)'
    $upstream = '(none)'
    $state = 'unknown'

    if ($BranchLine -match '^##\s+No commits yet on (?<newbranch>.+)$') {
        $branch = $matches['newbranch']
        $upstream = '(none)'
        $state = 'no commits yet'
    } elseif ($BranchLine -match '^##\s+(?<branch>[^\.\s]+)(?:\.\.\.(?<upstream>[^\s]+))?(?:\s+(?<state>\[[^\]]+\]))?') {
        $branch = $matches['branch']
        if ($matches['upstream']) { $upstream = $matches['upstream'] }
        if ($matches['state']) {
            $state = $matches['state'].Trim('[',']')
        } elseif ($matches['upstream']) {
            $state = 'up to date'
        }
    }

    return [pscustomobject]@{
        Branch = $branch
        Upstream = $upstream
        State = $state
    }
}

function Get-GfgRepositoryStatusSummary {
    param([object[]]$Items)

    $itemsArray = @($Items)
    $staged = 0
    $unstaged = 0
    $untracked = 0
    $conflicted = 0

    foreach ($item in $itemsArray) {
        if (-not $item) { continue }
        $status = [string]$item.Status
        $x = if ($status.Length -ge 1) { $status.Substring(0,1) } else { ' ' }
        $y = if ($status.Length -ge 2) { $status.Substring(1,1) } else { ' ' }

        if ($status -eq '??') {
            $untracked++
            continue
        }
        if ($status -match 'U' -or $status -in @('AA','DD')) { $conflicted++ }
        if ($x -ne ' ' -and $x -ne '?') { $staged++ }
        if ($y -ne ' ' -and $y -ne '?') { $unstaged++ }
    }

    return [pscustomobject]@{
        Total = $itemsArray.Count
        Staged = $staged
        Unstaged = $unstaged
        Untracked = $untracked
        Conflicted = $conflicted
        IsClean = ($itemsArray.Count -eq 0)
    }
}

function Get-GfgRepositoryStatusSuggestion {
    param(
        [string]$Branch,
        [string]$Upstream,
        [string]$BranchState,
        [object]$Summary
    )

    if ($BranchState -eq 'no commits yet') {
        return 'This repository has no commits yet. Use Setup > First commit... to create .gitignore, stage files, and create the initial commit.'
    }
    if ($Branch -eq '(detached?)') {
        return 'You are in detached HEAD. Create a branch from this commit or switch back before making normal commits.'
    }
    if ($Summary -and [int]$Summary.Conflicted -gt 0) {
        return 'Resolve merge conflicts first, then stage the resolved files and continue the merge/rebase.'
    }
    if ($Summary -and [int]$Summary.Staged -gt 0) {
        return 'Review the staged changes and commit them. Use the preview/output panes before pushing.'
    }
    if ($Summary -and ([int]$Summary.Unstaged -gt 0 -or [int]$Summary.Untracked -gt 0)) {
        return 'You have unstaged or untracked work. Review it, stage it, or use Do it to stash the work-in-progress with confirmation before switching, pulling, or merging.'
    }
    if ($BranchState -match 'ahead') {
        return 'Your branch has local commits. Push with normal push or force-with-lease only when intentionally rewriting remote history.'
    }
    if ($BranchState -match 'behind') {
        return 'Your branch is behind upstream. Pull/rebase before new work to reduce conflict risk.'
    }
    if ([string]::IsNullOrWhiteSpace($Upstream) -or $Upstream -eq '(none)') {
        return 'No upstream is configured. Push and set upstream when this branch is ready to share.'
    }
    return 'Working tree is clean. Start a feature branch, fetch updates, or create a release/tag when appropriate.'
}

function Get-GfgRepositoryStatus {
    param(
        [Parameter(Mandatory=$true)][string]$RepositoryPath
    )

    $output = & git -C $RepositoryPath status --porcelain=v1 --branch 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        return [pscustomobject]@{
            Success = $false
            ExitCode = $exitCode
            Error = ($output -join [Environment]::NewLine)
            Branch = '(unknown)'
            Upstream = '(none)'
            BranchState = 'unknown'
            Items = @()
            Summary = (Get-GfgRepositoryStatusSummary -Items @())
            Suggestion = 'Git status failed. Check that this folder is a Git repository and that Git is available.'
            RawOutput = ($output -join [Environment]::NewLine)
        }
    }

    $lines = @($output | Where-Object { $_ -ne '' })
    $branchLine = $lines | Select-Object -First 1
    $branchInfo = ConvertFrom-GfgStatusBranchLine -BranchLine $branchLine
    $items = @($lines | Select-Object -Skip 1 | ForEach-Object { ConvertFrom-GfgPorcelainStatusLine -Line $_ } | Where-Object { $_ })
    $summary = Get-GfgRepositoryStatusSummary -Items $items
    $suggestion = Get-GfgRepositoryStatusSuggestion -Branch $branchInfo.Branch -Upstream $branchInfo.Upstream -BranchState $branchInfo.State -Summary $summary

    return [pscustomobject]@{
        Success = $true
        ExitCode = 0
        Error = ''
        Branch = $branchInfo.Branch
        Upstream = $branchInfo.Upstream
        BranchState = $branchInfo.State
        Items = $items
        Summary = $summary
        Suggestion = $suggestion
        RawOutput = ($output -join [Environment]::NewLine)
    }
}

Export-ModuleMember -Function `
    ConvertFrom-GfgPorcelainStatusLine, `
    ConvertFrom-GfgStatusBranchLine, `
    Get-GfgRepositoryStatusSummary, `
    Get-GfgRepositoryStatusSuggestion, `
    Get-GfgRepositoryStatus
