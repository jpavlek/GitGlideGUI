<#
GitBranchOperations.psm1
UI-free branch workflow helpers for Git Glide GUI.

The module builds command plans and guidance for branch operations without
calling WinForms. The GUI remains responsible for confirmation dialogs and
execution, while tests can validate the workflow logic in temporary repos.
#>

Set-StrictMode -Version 2.0

function ConvertTo-GgbQuotedGitArgument {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) { return '""' }
    if ($Value.Length -eq 0) { return '""' }
    if ($Value -notmatch '[\s"]') { return $Value }

    $builder = New-Object System.Text.StringBuilder
    [void]$builder.Append('"')
    $backslashes = 0
    foreach ($ch in $Value.ToCharArray()) {
        if ($ch -eq '\') { $backslashes++; continue }
        if ($ch -eq '"') {
            if ($backslashes -gt 0) { [void]$builder.Append(('\' * ($backslashes * 2))) }
            [void]$builder.Append('\"')
            $backslashes = 0
            continue
        }
        if ($backslashes -gt 0) {
            [void]$builder.Append(('\' * $backslashes))
            $backslashes = 0
        }
        [void]$builder.Append($ch)
    }
    if ($backslashes -gt 0) { [void]$builder.Append(('\' * ($backslashes * 2))) }
    [void]$builder.Append('"')
    return $builder.ToString()
}

function New-GgbGitCommandPlan {
    param(
        [Parameter(Mandatory=$true)][string]$Verb,
        [Parameter(Mandatory=$true)][object[]]$Arguments,
        [string]$Description = ''
    )

    $display = 'git ' + (($Arguments | ForEach-Object { ConvertTo-GgbQuotedGitArgument ([string]$_) }) -join ' ')
    return [pscustomobject]@{
        Verb = $Verb
        Arguments = @($Arguments)
        Display = $display
        Description = $Description
    }
}

function ConvertTo-GgbCommandPreview {
    param([object[]]$Plans)

    $plansArray = @($Plans | Where-Object { $_ })
    if (@($plansArray).Count -eq 0) { return 'git <command>' }
    return (($plansArray | ForEach-Object { [string]$_.Display }) -join "`r`n")
}

function Test-GgbBranchName {
    param([AllowNull()][string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return [pscustomobject]@{ Valid = $false; Error = 'Branch name cannot be empty.' }
    }
    if ($Name -match '[~^:?*\[\\]') {
        return [pscustomobject]@{ Valid = $false; Error = 'Branch name contains invalid characters: ~ ^ : ? * [ or backslash.' }
    }
    if ($Name -match '(^/|/$|//|\.\.|@\{|\.lock$|\.$)') {
        return [pscustomobject]@{ Valid = $false; Error = 'Branch name format is invalid.' }
    }
    if ($Name.Length -gt 255) {
        return [pscustomobject]@{ Valid = $false; Error = 'Branch name too long; use 255 characters or less.' }
    }
    return [pscustomobject]@{ Valid = $true; Error = '' }
}

function Get-GgbCreateFeatureBranchCommandPlan {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [string]$BaseBranch = 'develop',
        [switch]$BaseFromBaseBranch
    )

    $plans = @()
    if ($BaseFromBaseBranch) {
        $plans += New-GgbGitCommandPlan -Verb 'switch-base' -Arguments @('switch', $BaseBranch) -Description 'Switch to the configured base branch before creating the feature branch.'
        $plans += New-GgbGitCommandPlan -Verb 'pull-base' -Arguments @('pull', '--ff-only') -Description 'Fast-forward the base branch before branching.'
    }
    $plans += New-GgbGitCommandPlan -Verb 'create-feature-branch' -Arguments @('switch', '-c', $Name) -Description 'Create and switch to the new feature branch.'
    return @($plans)
}

function Get-GgbSwitchBranchCommandPlan {
    param([Parameter(Mandatory=$true)][string]$TargetBranch)
    return @(New-GgbGitCommandPlan -Verb 'switch-branch' -Arguments @('switch', $TargetBranch) -Description 'Switch to the selected local branch.')
}

function Get-GgbPullCurrentBranchCommandPlan {
    return @(New-GgbGitCommandPlan -Verb 'pull-current-branch' -Arguments @('pull', '--ff-only') -Description 'Pull using fast-forward only, avoiding automatic merge commits.')
}

function Get-GgbPushCurrentBranchCommandPlan {
    return @(New-GgbGitCommandPlan -Verb 'push-current-branch' -Arguments @('push', '-u', 'origin', 'HEAD') -Description 'Push the current branch and set upstream tracking.')
}

function Get-GgbMergeFeatureIntoBaseCommandPlan {
    param(
        [Parameter(Mandatory=$true)][string]$FeatureBranch,
        [string]$BaseBranch = 'develop'
    )

    return @(
        (New-GgbGitCommandPlan -Verb 'switch-base' -Arguments @('switch', $BaseBranch) -Description 'Switch to the integration branch.')
        (New-GgbGitCommandPlan -Verb 'pull-base' -Arguments @('pull', '--ff-only') -Description 'Fast-forward the integration branch before merging.')
        (New-GgbGitCommandPlan -Verb 'merge-feature' -Arguments @('merge', '--no-ff', $FeatureBranch) -Description 'Merge the feature branch with an explicit merge commit.')
        (New-GgbGitCommandPlan -Verb 'push-base' -Arguments @('push', '-u', 'origin', $BaseBranch) -Description 'Push the updated integration branch.')
    )
}

function Get-GgbMergeBaseIntoMainCommandPlan {
    param(
        [string]$BaseBranch = 'develop',
        [string]$MainBranch = 'main'
    )

    return @(
        (New-GgbGitCommandPlan -Verb 'switch-main' -Arguments @('switch', $MainBranch) -Description 'Switch to the main branch.')
        (New-GgbGitCommandPlan -Verb 'pull-main' -Arguments @('pull', '--ff-only') -Description 'Fast-forward main before merging.')
        (New-GgbGitCommandPlan -Verb 'merge-base' -Arguments @('merge', '--no-ff', $BaseBranch) -Description 'Merge the integration branch into main.')
        (New-GgbGitCommandPlan -Verb 'push-main' -Arguments @('push', '-u', 'origin', $MainBranch) -Description 'Push the updated main branch.')
    )
}


function Get-GgbBranchTrackingCommandPlan {
    return New-GgbGitCommandPlan -Verb 'branch-tracking' -Arguments @('branch', '-vv') -Description 'Show local branches, upstream branches, and ahead/behind tracking state.'
}

function Get-GgbPushBranchWithUpstreamCommandPlan {
    param([string]$BranchName = 'HEAD', [string]$RemoteName = 'origin')
    if ([string]::IsNullOrWhiteSpace($RemoteName)) { $RemoteName = 'origin' }
    if ([string]::IsNullOrWhiteSpace($BranchName)) { $BranchName = 'HEAD' }
    return @(New-GgbGitCommandPlan -Verb 'push-branch-upstream' -Arguments @('push', '-u', $RemoteName, $BranchName) -Description 'Push the branch and set upstream tracking so later git push works without extra arguments.')
}

function Get-GgbSyncMainIntoBaseCommandPlan {
    param([string]$MainBranch = 'main', [string]$BaseBranch = 'develop')
    return @(
        (New-GgbGitCommandPlan -Verb 'switch-main' -Arguments @('switch', $MainBranch) -Description 'Switch to the stable main branch.')
        (New-GgbGitCommandPlan -Verb 'pull-main' -Arguments @('pull', '--ff-only') -Description 'Fast-forward main before syncing it into develop.')
        (New-GgbGitCommandPlan -Verb 'switch-base' -Arguments @('switch', $BaseBranch) -Description 'Switch to the integration branch.')
        (New-GgbGitCommandPlan -Verb 'pull-base' -Arguments @('pull', '--ff-only') -Description 'Fast-forward develop before merging main into it.')
        (New-GgbGitCommandPlan -Verb 'merge-main-into-base' -Arguments @('merge', $MainBranch) -Description 'Bring main/hotfix/release corrections into develop.')
        (New-GgbGitCommandPlan -Verb 'push-base-upstream' -Arguments @('push', '-u', 'origin', $BaseBranch) -Description 'Push develop and set upstream if missing.')
    )
}

function Get-GgbMergeNamedFeatureIntoBaseCommandPlan {
    param([Parameter(Mandatory=$true)][string]$FeatureBranch, [string]$BaseBranch = 'develop')
    return @(
        (New-GgbGitCommandPlan -Verb 'switch-base' -Arguments @('switch', $BaseBranch) -Description 'Switch to the integration branch.')
        (New-GgbGitCommandPlan -Verb 'pull-base' -Arguments @('pull', '--ff-only') -Description 'Fast-forward the integration branch before merging the feature.')
        (New-GgbGitCommandPlan -Verb 'merge-feature' -Arguments @('merge', '--no-ff', $FeatureBranch) -Description 'Merge the selected feature branch with an explicit merge commit.')
        (New-GgbGitCommandPlan -Verb 'push-base-upstream' -Arguments @('push', '-u', 'origin', $BaseBranch) -Description 'Push develop and set upstream if missing.')
    )
}

function Get-GgbGitFlowMergeAndPublishGuide {
    param([string]$MainBranch = 'main', [string]$BaseBranch = 'develop', [string]$FeatureBranch = '<feature-branch>')
    if ([string]::IsNullOrWhiteSpace($FeatureBranch)) { $FeatureBranch = '<feature-branch>' }
    return @(
        'git status',
        'git branch -vv',
        ('git switch {0}' -f $FeatureBranch),
        'git push -u origin HEAD',
        ('git switch {0}' -f $BaseBranch),
        ('git merge {0}' -f $MainBranch),
        ('git merge --no-ff {0}' -f $FeatureBranch),
        'scripts\windows\run-quality-checks.bat',
        ('git push -u origin {0}' -f $BaseBranch),
        ('git switch {0}' -f $MainBranch),
        ('git merge --no-ff {0}' -f $BaseBranch),
        ('git push -u origin {0}' -f $MainBranch)
    ) -join "`r`n"
}
function Get-GgbBranchRole {
    param(
        [AllowNull()][string]$BranchName,
        [string]$MainBranch = 'main',
        [string]$BaseBranch = 'develop'
    )
    $branch = [string]$BranchName
    if ([string]::IsNullOrWhiteSpace($branch)) { return [pscustomobject]@{ Role='unknown'; Protected=$false; Recommended='Select a branch.' } }
    if ($branch -eq $MainBranch) { return [pscustomobject]@{ Role='protected release branch'; Protected=$true; Recommended='Create a feature/fix branch before committing normal work.' } }
    if ($branch -eq $BaseBranch) { return [pscustomobject]@{ Role='integration branch'; Protected=$true; Recommended='Merge finished features here and run quality checks before promoting to main.' } }
    if ($branch -like 'feature/*') { return [pscustomobject]@{ Role='feature branch'; Protected=$false; Recommended='Commit here, push upstream, then merge into develop.' } }
    if ($branch -like 'fix/*') { return [pscustomobject]@{ Role='fix branch'; Protected=$false; Recommended='Commit here, push upstream, then merge into develop.' } }
    if ($branch -like 'hotfix/*') { return [pscustomobject]@{ Role='hotfix branch'; Protected=$false; Recommended='Run checks, merge to main, then sync back into develop.' } }
    if ($branch -like 'release/*') { return [pscustomobject]@{ Role='release branch'; Protected=$false; Recommended='Use for release stabilization and quality checks.' } }
    return [pscustomobject]@{ Role='custom branch'; Protected=$false; Recommended='Confirm this branch fits the intended workflow.' }
}

function Get-GgbMoveCurrentChangesToBranchCommandPlan {
    param([Parameter(Mandatory=$true)][string]$BranchName)
    return @(New-GgbGitCommandPlan -Verb 'move-current-work-to-branch' -Arguments @('switch','-c',$BranchName) -Description 'Create a new branch while keeping the current working tree changes.')
}


function Test-GgbWorkflowProtectedBranch {
    param(
        [string]$BranchName,
        [string]$MainBranch = 'main',
        [string]$BaseBranch = 'develop'
    )
    if ([string]::IsNullOrWhiteSpace($BranchName)) { return $false }
    return (($BranchName -eq $MainBranch) -or ($BranchName -eq $BaseBranch))
}

function Get-GgbProtectedBranchCommitGuidance {
    param(
        [string]$BranchName,
        [string]$MainBranch = 'main',
        [string]$BaseBranch = 'develop'
    )

    $isProtected = Test-GgbWorkflowProtectedBranch -BranchName $BranchName -MainBranch $MainBranch -BaseBranch $BaseBranch
    if (-not $isProtected) {
        return [pscustomobject]@{
            ShouldWarn = $false
            Title = 'Feature branch workflow'
            Message = 'This commit is on a normal feature/work branch.'
            RecommendedAction = 'commit'
        }
    }

    $recommended = if ($BranchName -eq $MainBranch) {
        ('Create a feature branch from {0}, commit there, merge feature -> {0}, run quality checks, then merge {0} -> {1}.' -f $BaseBranch, $MainBranch)
    } else {
        ('Prefer committing feature work on a feature branch, then merge it back into {0} after review or validation.' -f $BaseBranch)
    }

    return [pscustomobject]@{
        ShouldWarn = $true
        Title = ('You are committing directly on {0}' -f $BranchName)
        Message = ('This can skip the intended Git Flow path. {0} Continue anyway?' -f $recommended)
        RecommendedAction = 'create-feature-branch'
    }
}

function Get-GgbDirtyWorkingTreeGuidance {
    param(
        [object]$Summary,
        [string]$Operation = 'this branch operation'
    )

    $staged = 0
    $unstaged = 0
    $untracked = 0
    $conflicted = 0
    $total = 0
    if ($Summary) {
        try { $staged = [int]$Summary.Staged } catch {}
        try { $unstaged = [int]$Summary.Unstaged } catch {}
        try { $untracked = [int]$Summary.Untracked } catch {}
        try { $conflicted = [int]$Summary.Conflicted } catch {}
        try { $total = [int]$Summary.Total } catch {}
    }

    if ($conflicted -gt 0) {
        return [pscustomobject]@{
            IsClean = $false
            Severity = 'conflict'
            Title = 'Resolve conflicts first'
            Message = "Cannot safely run $Operation while conflicts are present. Resolve the conflicted files, stage them, and then continue."
            Details = "Conflicted: $conflicted; staged: $staged; unstaged: $unstaged; untracked: $untracked."
            RecommendedAction = 'show-diff'
        }
    }

    if ($total -gt 0) {
        return [pscustomobject]@{
            IsClean = $false
            Severity = 'dirty'
            Title = 'Working tree not clean'
            Message = "Before $Operation, protect your work by committing it, stashing it, or intentionally discarding it. Switching, pulling, or merging with local changes can fail or mix unrelated work."
            Details = "Staged: $staged; unstaged: $unstaged; untracked: $untracked."
            RecommendedAction = 'stage-tab'
        }
    }

    return [pscustomobject]@{
        IsClean = $true
        Severity = 'clean'
        Title = 'Working tree clean'
        Message = "It is safe to continue with $Operation."
        Details = ''
        RecommendedAction = ''
    }
}


function Get-GgbUiModeTabNames {
    param([ValidateSet('Simple','Workflow','Expert')][string]$Mode = 'Simple')
    switch ($Mode) {
        'Simple' { return @('Setup','Stage','Branch','Stash','Inspect / Build') }
        'Workflow' { return @('Setup','Stage','Branch','Integrate','Recovery','History / Graph','Stash','Tags / Release','Learning') }
        default { return @('Setup','Inspect / Build','History / Graph','Recovery','Learning','Stage','Branch','Integrate','Stash','Custom Git','Appearance','Tags / Release') }
    }
}


function Get-GgbWorkflowChecklist {
    param(
        [string]$CurrentBranch = '',
        [string]$FeatureBranch = '<feature-branch>',
        [string]$MainBranch = 'main',
        [string]$BaseBranch = 'develop',
        [string]$Upstream = '',
        [string]$BranchState = ''
    )

    if ([string]::IsNullOrWhiteSpace($FeatureBranch)) { $FeatureBranch = '<feature-branch>' }
    $currentRole = Get-GgbBranchRole -BranchName $CurrentBranch -MainBranch $MainBranch -BaseBranch $BaseBranch
    $hasUpstream = -not [string]::IsNullOrWhiteSpace($Upstream)
    $isFeatureLike = (($FeatureBranch -like 'feature/*') -or ($FeatureBranch -like 'fix/*') -or ($FeatureBranch -like 'hotfix/*') -or ($FeatureBranch -like 'release/*'))

    return @(
        [pscustomobject]@{
            Step = 1
            Status = if ([string]::IsNullOrWhiteSpace($CurrentBranch)) { 'attention' } elseif ($currentRole.Protected) { 'attention' } else { 'ok' }
            Title = 'Work on a feature/fix branch'
            Command = if ($currentRole.Protected) { 'git switch -c feature/<name>' } else { ('current branch: {0}' -f $CurrentBranch) }
            Guidance = 'Normal work should happen outside main/develop so workflow steps are not skipped.'
        },
        [pscustomobject]@{
            Step = 2
            Status = if ($hasUpstream) { 'ok' } else { 'todo' }
            Title = 'Push branch with upstream'
            Command = 'git push -u origin HEAD'
            Guidance = 'Sets tracking so later git push works without extra arguments.'
        },
        [pscustomobject]@{
            Step = 3
            Status = if ($isFeatureLike) { 'todo' } else { 'attention' }
            Title = ('Merge feature/fix into {0}' -f $BaseBranch)
            Command = ('git switch {0}; git merge --no-ff {1}' -f $BaseBranch, $FeatureBranch)
            Guidance = 'Integrate finished work into the integration branch with an explicit merge commit.'
        },
        [pscustomobject]@{
            Step = 4
            Status = 'todo'
            Title = 'Run quality checks'
            Command = 'scripts\windows\run-quality-checks.bat'
            Guidance = 'Use the quality gate before promoting develop to main.'
        },
        [pscustomobject]@{
            Step = 5
            Status = 'todo'
            Title = ('Promote {0} into {1}' -f $BaseBranch, $MainBranch)
            Command = ('git switch {0}; git merge --no-ff {1}' -f $MainBranch, $BaseBranch)
            Guidance = 'Move validated integration work into the release branch.'
        },
        [pscustomobject]@{
            Step = 6
            Status = 'todo'
            Title = 'Push and tag release'
            Command = ('git push origin {0} {1}; git push origin --tags' -f $MainBranch, $BaseBranch)
            Guidance = 'Publish the release branches and tags after validation.'
        },
        [pscustomobject]@{
            Step = 7
            Status = 'optional'
            Title = 'Clean up merged feature/fix branch'
            Command = ('git branch -d {0}; git push origin --delete {0}' -f $FeatureBranch)
            Guidance = 'Clean up only after the branch is merged and pushed.'
        }
    )
}

function Format-GgbWorkflowChecklist {
    param([AllowNull()][object[]]$Items)

    $rows = @()
    foreach ($item in @($Items | Where-Object { $_ })) {
        $status = [string]$item.Status
        $mark = switch ($status) {
            'ok' { '[x]' }
            'attention' { '[!]' }
            'optional' { '[-]' }
            default { '[ ]' }
        }
        $rows += ('{0} {1}. {2}' -f $mark, [int]$item.Step, [string]$item.Title)
        if (-not [string]::IsNullOrWhiteSpace([string]$item.Command)) { $rows += ('    command: {0}' -f [string]$item.Command) }
        if (-not [string]::IsNullOrWhiteSpace([string]$item.Guidance)) { $rows += ('    why: {0}' -f [string]$item.Guidance) }
    }
    if (@($rows).Count -eq 0) { return 'No workflow checklist items available.' }
    return ($rows -join "`r`n")
}

function Get-GgbCleanupMergedBranchCommandPlan {
    param(
        [Parameter(Mandatory=$true)][string]$BranchName,
        [string]$RemoteName = 'origin',
        [switch]$DeleteRemote,
        [string]$MainBranch = 'main',
        [string]$BaseBranch = 'develop'
    )

    $validation = Test-GgbBranchName -Name $BranchName
    if (-not $validation.Valid) { throw $validation.Error }
    if ($BranchName -eq $MainBranch -or $BranchName -eq $BaseBranch) { throw 'Refusing to delete protected workflow branches.' }
    if ([string]::IsNullOrWhiteSpace($RemoteName)) { $RemoteName = 'origin' }

    $plans = @()
    $plans += New-GgbGitCommandPlan -Verb 'delete-merged-local-branch' -Arguments @('branch','-d',$BranchName) -Description 'Delete the local branch only if Git considers it merged.'
    if ($DeleteRemote) {
        $plans += New-GgbGitCommandPlan -Verb 'delete-merged-remote-branch' -Arguments @('push',$RemoteName,'--delete',$BranchName) -Description 'Delete the remote branch after the local branch was merged.'
    }
    return @($plans)
}


Export-ModuleMember -Function `
    ConvertTo-GgbQuotedGitArgument, `
    New-GgbGitCommandPlan, `
    ConvertTo-GgbCommandPreview, `
    Test-GgbBranchName, `
    Get-GgbCreateFeatureBranchCommandPlan, `
    Get-GgbSwitchBranchCommandPlan, `
    Get-GgbPullCurrentBranchCommandPlan, `
    Get-GgbPushCurrentBranchCommandPlan, `
    Get-GgbBranchTrackingCommandPlan, `
    Get-GgbPushBranchWithUpstreamCommandPlan, `
    Get-GgbSyncMainIntoBaseCommandPlan, `
    Get-GgbMergeNamedFeatureIntoBaseCommandPlan, `
    Get-GgbGitFlowMergeAndPublishGuide, `
    Get-GgbBranchRole, `
    Get-GgbMoveCurrentChangesToBranchCommandPlan, `
    Get-GgbUiModeTabNames, `
    Get-GgbCleanupMergedBranchCommandPlan, `
    Format-GgbWorkflowChecklist, `
    Get-GgbWorkflowChecklist, `
    Test-GgbWorkflowProtectedBranch, `
    Get-GgbProtectedBranchCommitGuidance, `
    Get-GgbMergeFeatureIntoBaseCommandPlan, `
    Get-GgbMergeBaseIntoMainCommandPlan, `
    Get-GgbDirtyWorkingTreeGuidance
