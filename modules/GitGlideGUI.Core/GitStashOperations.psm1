# GitGlideGUI.Core - Stash operation helpers for Git Glide GUI
# PowerShell 5.1 compatible. Keep this module UI-free so it can be tested without WinForms.

Set-StrictMode -Version 2.0

function ConvertTo-GgsQuotedArgument {
    param([AllowNull()][string]$Argument)

    if ($null -eq $Argument) { return '""' }
    if ($Argument -eq '') { return '""' }
    if ($Argument -notmatch '[\s"`;&|<>^{}]') { return $Argument }

    $escaped = $Argument -replace '"', '\"'
    # A trailing backslash before a closing quote can escape the quote in several shells.
    if ($escaped.EndsWith('\')) { $escaped += '\' }
    return '"' + $escaped + '"'
}

function New-GgsGitCommandPlan {
    param(
        [Parameter(Mandatory=$true)][string[]]$Arguments,
        [string]$Display = ''
    )

    $argsArray = @($Arguments | ForEach-Object { [string]$_ })
    if ([string]::IsNullOrWhiteSpace($Display)) {
        $Display = 'git ' + (($argsArray | ForEach-Object { ConvertTo-GgsQuotedArgument $_ }) -join ' ')
    }

    return [pscustomobject]@{
        FileName = 'git'
        Arguments = $argsArray
        Display = $Display
    }
}

function Test-GgsStashRef {
    param([AllowNull()][string]$StashRef)
    if ([string]::IsNullOrWhiteSpace($StashRef)) { return $false }
    return ($StashRef -match '^stash@\{\d+\}$')
}

function Get-GgsDefaultStashMessage {
    param([string]$Prefix = 'wip')
    $safePrefix = if ([string]::IsNullOrWhiteSpace($Prefix)) { 'wip' } else { $Prefix.Trim() }
    return ('{0}: {1:yyyy-MM-dd HH:mm}' -f $safePrefix, (Get-Date))
}

function Get-GgsStashPushCommandPlan {
    param(
        [string]$Message = '',
        [switch]$IncludeUntracked,
        [switch]$KeepIndex
    )

    $args = New-Object System.Collections.Generic.List[string]
    [void]$args.Add('stash')
    [void]$args.Add('push')
    if ($IncludeUntracked) { [void]$args.Add('-u') }
    if ($KeepIndex) { [void]$args.Add('--keep-index') }
    if (-not [string]::IsNullOrWhiteSpace($Message)) {
        [void]$args.Add('-m')
        [void]$args.Add($Message.Trim())
    }
    return New-GgsGitCommandPlan -Arguments @($args)
}

function Get-GgsStashListCommandPlan {
    return New-GgsGitCommandPlan -Arguments @('stash', 'list')
}

function Get-GgsStashShowPatchCommandPlan {
    param([string]$StashRef = 'stash@{0}')
    if ([string]::IsNullOrWhiteSpace($StashRef)) { $StashRef = 'stash@{0}' }
    return New-GgsGitCommandPlan -Arguments @('stash', 'show', '--stat', '--patch', $StashRef)
}

function Get-GgsStashShowNameStatusCommandPlan {
    param([string]$StashRef = 'stash@{0}')
    if ([string]::IsNullOrWhiteSpace($StashRef)) { $StashRef = 'stash@{0}' }
    return New-GgsGitCommandPlan -Arguments @('stash', 'show', '--name-status', $StashRef)
}

function Get-GgsStashApplyCommandPlan {
    param(
        [Parameter(Mandatory=$true)][string]$StashRef,
        [switch]$RestoreIndex
    )
    if (-not (Test-GgsStashRef $StashRef)) { throw "Invalid stash reference '$StashRef'. Expected format: stash@{0}." }
    $args = @('stash', 'apply')
    if ($RestoreIndex) { $args += '--index' }
    $args += $StashRef
    return New-GgsGitCommandPlan -Arguments $args
}

function Get-GgsStashPopCommandPlan {
    param(
        [Parameter(Mandatory=$true)][string]$StashRef,
        [switch]$RestoreIndex
    )
    if (-not (Test-GgsStashRef $StashRef)) { throw "Invalid stash reference '$StashRef'. Expected format: stash@{0}." }
    $args = @('stash', 'pop')
    if ($RestoreIndex) { $args += '--index' }
    $args += $StashRef
    return New-GgsGitCommandPlan -Arguments $args
}

function Get-GgsStashDropCommandPlan {
    param([Parameter(Mandatory=$true)][string]$StashRef)
    if (-not (Test-GgsStashRef $StashRef)) { throw "Invalid stash reference '$StashRef'. Expected format: stash@{0}." }
    return New-GgsGitCommandPlan -Arguments @('stash', 'drop', $StashRef)
}

function Get-GgsStashBranchCommandPlan {
    param(
        [Parameter(Mandatory=$true)][string]$BranchName,
        [Parameter(Mandatory=$true)][string]$StashRef
    )
    if ([string]::IsNullOrWhiteSpace($BranchName)) { throw 'Branch name is required.' }
    if (-not (Test-GgsStashRef $StashRef)) { throw "Invalid stash reference '$StashRef'. Expected format: stash@{0}." }
    return New-GgsGitCommandPlan -Arguments @('stash', 'branch', $BranchName.Trim(), $StashRef)
}

function Get-GgsStashClearCommandPlan {
    return New-GgsGitCommandPlan -Arguments @('stash', 'clear')
}

function ConvertTo-GgsCommandPreview {
    param([Parameter(Mandatory=$true)][object]$Plan)
    return [string]$Plan.Display
}

function Get-GgsStashFailureGuidance {
    param(
        [string]$Operation = 'stash operation',
        [string]$StdOut = '',
        [string]$StdErr = ''
    )

    $combined = (($StdOut, $StdErr) -join [Environment]::NewLine).Trim()
    $lower = $combined.ToLowerInvariant()
    $steps = New-Object System.Collections.Generic.List[string]
    $message = 'The stash command failed. Your repository may need manual recovery before continuing.'

    if ($lower -match 'conflict|needs merge|merge conflict|could not restore untracked files') {
        $message = 'The stash touched files that conflict with your current working tree.'
        [void]$steps.Add('Open the changed-file list and resolve conflicted files first.')
        [void]$steps.Add('Use git status to confirm which files are unmerged or modified.')
        [void]$steps.Add('After resolving, stage the resolved files and commit, or abort/retry the workflow intentionally.')
        [void]$steps.Add('Prefer Apply over Pop when unsure, because Apply keeps the stash until you explicitly drop it.')
    } elseif ($lower -match 'would be overwritten|local changes.*overwritten') {
        $message = 'Git refused to apply the stash because local files would be overwritten.'
        [void]$steps.Add('Commit or stash your current local changes first.')
        [void]$steps.Add('Then apply the selected stash again.')
        [void]$steps.Add('Inspect the stash diff before retrying if the files overlap.')
    } elseif ($lower -match 'untracked working tree files would be overwritten|already exists') {
        $message = 'Untracked files in the working tree block the stash operation.'
        [void]$steps.Add('Move, rename, commit, or stash the untracked files first.')
        [void]$steps.Add('Then retry the stash apply/pop operation.')
    } elseif ($lower -match 'index|staged|could not reset index') {
        $message = 'Git could not restore the staged/index state from the stash.'
        [void]$steps.Add('Retry without --index if restoring staged state is not required.')
        [void]$steps.Add('Use git status and git diff --cached to inspect the index.')
    } elseif ($lower -match 'not a valid reference|unknown revision|bad revision') {
        $message = 'The selected stash reference no longer exists.'
        [void]$steps.Add('Refresh the stash list.')
        [void]$steps.Add('Select an existing stash entry and retry.')
    } else {
        [void]$steps.Add('Read the command output above for the exact Git error.')
        [void]$steps.Add('Run git status before attempting another switch, pull, merge, apply, or pop.')
        [void]$steps.Add('Use Apply instead of Pop when you want to keep the stash as a safety copy.')
    }

    return [pscustomobject]@{
        Operation = $Operation
        Message = $message
        Details = $combined
        RecoverySteps = @($steps)
    }
}

function Get-GgsDirtyWorkTreeStashSuggestion {
    param([object]$Summary)
    if (-not $Summary) { return $null }
    $staged = [int]$Summary.Staged
    $unstaged = [int]$Summary.Unstaged
    $untracked = [int]$Summary.Untracked
    $conflicted = [int]$Summary.Conflicted
    if ($conflicted -gt 0) { return $null }
    if ($staged -eq 0 -and ($unstaged -gt 0 -or $untracked -gt 0)) {
        return [pscustomobject]@{
            Action = 'stash-dirty-work'
            Message = 'Stash current dirty work with confirmation so you can switch, pull, or merge more safely.'
        }
    }
    return $null
}

Export-ModuleMember -Function `
    ConvertTo-GgsQuotedArgument, `
    New-GgsGitCommandPlan, `
    Test-GgsStashRef, `
    Get-GgsDefaultStashMessage, `
    Get-GgsStashPushCommandPlan, `
    Get-GgsStashListCommandPlan, `
    Get-GgsStashShowPatchCommandPlan, `
    Get-GgsStashShowNameStatusCommandPlan, `
    Get-GgsStashApplyCommandPlan, `
    Get-GgsStashPopCommandPlan, `
    Get-GgsStashDropCommandPlan, `
    Get-GgsStashBranchCommandPlan, `
    Get-GgsStashClearCommandPlan, `
    ConvertTo-GgsCommandPreview, `
    Get-GgsStashFailureGuidance, `
    Get-GgsDirtyWorkTreeStashSuggestion
