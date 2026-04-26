# This file is part of Git Glide GUI v3.7.0 split-script architecture.
# It is dot-sourced by GitGlideGUI-v3.7.0.ps1.

#region Command Preview Builders

function Build-FeatureBranchCommandPreview {
    $name = if ($script:FeatureBranchTextBox) { $script:FeatureBranchTextBox.Text.Trim() } else { '' }
    if ([string]::IsNullOrWhiteSpace($name)) { $name = $script:Config.FeatureBranchPrefix + 'your-name' }

    $baseFromBase = (($script:BaseFromDevelopCheckBox) -and $script:BaseFromDevelopCheckBox.Checked)
    if (Get-Command Get-GgbCreateFeatureBranchCommandPlan -ErrorAction SilentlyContinue) {
        return (ConvertTo-GgbCommandPreview -Plans (Get-GgbCreateFeatureBranchCommandPlan -Name $name -BaseBranch $script:Config.BaseBranch -BaseFromBaseBranch:$baseFromBase))
    }

    if ($baseFromBase) {
        return @(
            "git switch $($script:Config.BaseBranch)"
            'git pull --ff-only'
            ('git switch -c ' + $name)
        ) -join "`r`n"
    }
    return ('git switch -c ' + $name)
}

function Build-SwitchBranchPreview {
    $targetBranch = Get-SelectedBranchName
    if (Get-Command Get-GgbSwitchBranchCommandPlan -ErrorAction SilentlyContinue) {
        return (ConvertTo-GgbCommandPreview -Plans (Get-GgbSwitchBranchCommandPlan -TargetBranch $targetBranch))
    }
    return ('git switch ' + $targetBranch)
}

function Build-PullPreview {
    if (Get-Command Get-GgbPullCurrentBranchCommandPlan -ErrorAction SilentlyContinue) {
        return (ConvertTo-GgbCommandPreview -Plans (Get-GgbPullCurrentBranchCommandPlan))
    }
    return 'git pull --ff-only'
}

function Build-BuildPreview([switch]$WithWeb) {
    $args = @('build-test-run.bat', '--force', '--yes', '--stop-running')
    if (-not $WithWeb) { $args += '--no-web' }
    return ($args -join ' ')
}

function Build-PushPreview {
    if ($script:Config.UseForceWithLease -and $script:CommitAmendCheckBox -and $script:CommitAmendCheckBox.Checked) {
        return 'git push --force-with-lease'
    }
    if (Get-Command Get-GgbPushCurrentBranchCommandPlan -ErrorAction SilentlyContinue) {
        return (ConvertTo-GgbCommandPreview -Plans (Get-GgbPushCurrentBranchCommandPlan))
    }
    return 'git push -u origin HEAD'
}

function Build-MergeFeaturePreview {
    $featureBranch = Get-CurrentBranchNameOrPlaceholder
    if (Get-Command Get-GgbMergeFeatureIntoBaseCommandPlan -ErrorAction SilentlyContinue) {
        return (ConvertTo-GgbCommandPreview -Plans (Get-GgbMergeFeatureIntoBaseCommandPlan -FeatureBranch $featureBranch -BaseBranch $script:Config.BaseBranch))
    }
    return @(
        "git switch $($script:Config.BaseBranch)"
        'git pull --ff-only'
        ('git merge --no-ff ' + $featureBranch)
        "git push origin $($script:Config.BaseBranch)"
    ) -join "`r`n"
}

function Build-MergeDevelopPreview {
    if (Get-Command Get-GgbMergeBaseIntoMainCommandPlan -ErrorAction SilentlyContinue) {
        return (ConvertTo-GgbCommandPreview -Plans (Get-GgbMergeBaseIntoMainCommandPlan -BaseBranch $script:Config.BaseBranch -MainBranch $script:Config.MainBranch))
    }
    return @(
        "git switch $($script:Config.MainBranch)"
        'git pull --ff-only'
        "git merge --no-ff $($script:Config.BaseBranch)"
        "git push origin $($script:Config.MainBranch)"
    ) -join "`r`n"
}

function Build-StageSelectedPreview {
    $items = Get-SelectedStatusItems
    if (Get-Command Get-GggStageSelectedCommandPlan -ErrorAction SilentlyContinue) {
        return (ConvertTo-GggCommandPreview -Plans (Get-GggStageSelectedCommandPlan -Items $items))
    }
    if ($items.Count -le 1) {
        return ('git add -- ' + (Quote-Arg (Get-SelectedStatusPath)))
    }
    return ($items | ForEach-Object {
        'git add -- ' + (Quote-Arg $_.Path)
    }) -join "`r`n"
}

function Build-UnstageSelectedPreview {
    $items = Get-SelectedStatusItems
    $hasCommits = Test-GitHasCommits
    if (Get-Command Get-GggUnstageSelectedCommandPlan -ErrorAction SilentlyContinue) {
        return (ConvertTo-GggCommandPreview -Plans (Get-GggUnstageSelectedCommandPlan -Items $items -RepositoryHasNoCommits:(-not $hasCommits)))
    }
    if ($items.Count -le 1) {
        $path = Get-SelectedStatusPath
        $gitArgs = Get-UnstageGitArgumentsForPath -Path $path
        return ('git ' + (($gitArgs | ForEach-Object { Quote-Arg ([string]$_) }) -join ' '))
    }
    return ($items | ForEach-Object {
        $gitArgs = Get-UnstageGitArgumentsForPath -Path $_.Path
        'git ' + (($gitArgs | ForEach-Object { Quote-Arg ([string]$_) }) -join ' ')
    }) -join "`r`n"
}


function Build-RemoveSelectedFromGitPreview {
    return (Build-RemoveFromGitPreviewForItems -Items (Get-SelectedStatusItems))
}

function Build-StopTrackingSelectedPreview {
    return (Build-StopTrackingPreviewForItems -Items (Get-SelectedStatusItems))
}

function Build-ShowDiffPreview {
    $item = Get-SelectedStatusItem
    if (Get-Command Get-GggShowDiffCommandPreview -ErrorAction SilentlyContinue) {
        return (Get-GggShowDiffCommandPreview -Item $item)
    }
    if (-not $item) { return 'git diff HEAD -- <selected-file>' }

    $paths = Get-DiffTargetPaths -Item $item
    $quotedPaths = ($paths | ForEach-Object { Quote-Arg $_ }) -join ' '

    if ($item.Status -eq '??') {
        return "# untracked file preview for $quotedPaths"
    }

    $commands = New-Object System.Collections.Generic.List[string]
    if ($item.IndexStatus -ne ' ' -and $item.IndexStatus -ne '?') {
        [void]$commands.Add('git diff --no-ext-diff --no-color --find-renames --cached -- ' + $quotedPaths)
    }
    if ($item.WorkTreeStatus -ne ' ' -and $item.WorkTreeStatus -ne '?') {
        [void]$commands.Add('git diff --no-ext-diff --no-color --find-renames -- ' + $quotedPaths)
    }
    if ($commands.Count -eq 0) {
        [void]$commands.Add('git diff --no-ext-diff --no-color --find-renames HEAD -- ' + $quotedPaths)
    }
    return ($commands -join "`r`n")
}

function Build-StashPushPreview {
    $message = if ($script:StashMessageTextBox) { $script:StashMessageTextBox.Text.Trim() } else { '' }
    $includeUntracked = ($script:StashIncludeUntrackedCheckBox -and $script:StashIncludeUntrackedCheckBox.Checked)
    $keepIndex = ($script:StashKeepIndexCheckBox -and $script:StashKeepIndexCheckBox.Checked)
    if (Get-Command Get-GgsStashPushCommandPlan -ErrorAction SilentlyContinue) {
        return (ConvertTo-GgsCommandPreview -Plan (Get-GgsStashPushCommandPlan -Message $message -IncludeUntracked:$includeUntracked -KeepIndex:$keepIndex))
    }
    $parts = New-Object System.Collections.Generic.List[string]
    [void]$parts.Add('git stash push')
    if ($includeUntracked) { [void]$parts.Add('-u') }
    if ($keepIndex) { [void]$parts.Add('--keep-index') }
    if (-not [string]::IsNullOrWhiteSpace($message)) {
        [void]$parts.Add('-m')
        [void]$parts.Add((Quote-Arg $message))
    }
    return ($parts -join ' ')
}

function Build-StashPushIncludeUntrackedPreview {
    $message = if ($script:StashMessageTextBox) { $script:StashMessageTextBox.Text.Trim() } else { '' }
    if (Get-Command Get-GgsStashPushCommandPlan -ErrorAction SilentlyContinue) {
        return (ConvertTo-GgsCommandPreview -Plan (Get-GgsStashPushCommandPlan -Message $message -IncludeUntracked))
    }
    if ([string]::IsNullOrWhiteSpace($message)) { return 'git stash push -u' }
    return 'git stash push -u -m ' + (Quote-Arg $message)
}

function Build-StashPushKeepIndexPreview {
    $message = if ($script:StashMessageTextBox) { $script:StashMessageTextBox.Text.Trim() } else { '' }
    if (Get-Command Get-GgsStashPushCommandPlan -ErrorAction SilentlyContinue) {
        return (ConvertTo-GgsCommandPreview -Plan (Get-GgsStashPushCommandPlan -Message $message -KeepIndex))
    }
    if ([string]::IsNullOrWhiteSpace($message)) { return 'git stash push --keep-index' }
    return 'git stash push --keep-index -m ' + (Quote-Arg $message)
}

function Build-StashListPreview {
    if (Get-Command Get-GgsStashListCommandPlan -ErrorAction SilentlyContinue) { return (ConvertTo-GgsCommandPreview -Plan (Get-GgsStashListCommandPlan)) }
    return 'git stash list'
}

function Build-StashShowPreview {
    $stashRef = Get-SelectedStashRef -DefaultLatest
    if (-not $stashRef) { $stashRef = 'stash@{0}' }
    if (Get-Command Get-GgsStashShowPatchCommandPlan -ErrorAction SilentlyContinue) { return (ConvertTo-GgsCommandPreview -Plan (Get-GgsStashShowPatchCommandPlan -StashRef $stashRef)) }
    return "git stash show --stat --patch $stashRef"
}

function Build-StashApplyPreview {
    param([switch]$RestoreIndex)
    $stashRef = Get-SelectedStashRef
    if (-not $stashRef) { $stashRef = '<selected-stash>' }
    if ((Get-Command Get-GgsStashApplyCommandPlan -ErrorAction SilentlyContinue) -and (Get-Command Test-GgsStashRef -ErrorAction SilentlyContinue) -and (Test-GgsStashRef $stashRef)) {
        return (ConvertTo-GgsCommandPreview -Plan (Get-GgsStashApplyCommandPlan -StashRef $stashRef -RestoreIndex:$RestoreIndex))
    }
    $indexPart = if ($RestoreIndex) { ' --index' } else { '' }
    return "git stash apply$indexPart $stashRef"
}

function Build-StashApplyIndexPreview { return (Build-StashApplyPreview -RestoreIndex) }

function Build-StashNameStatusPreview {
    $stashRef = Get-SelectedStashRef -DefaultLatest
    if (-not $stashRef) { $stashRef = 'stash@{0}' }
    if (Get-Command Get-GgsStashShowNameStatusCommandPlan -ErrorAction SilentlyContinue) { return (ConvertTo-GgsCommandPreview -Plan (Get-GgsStashShowNameStatusCommandPlan -StashRef $stashRef)) }
    return "git stash show --name-status $stashRef"
}

function Build-StashPopPreview {
    param([switch]$RestoreIndex)
    $stashRef = Get-SelectedStashRef -DefaultLatest
    if (-not $stashRef) { $stashRef = 'stash@{0}' }
    if ((Get-Command Get-GgsStashPopCommandPlan -ErrorAction SilentlyContinue) -and (Get-Command Test-GgsStashRef -ErrorAction SilentlyContinue) -and (Test-GgsStashRef $stashRef)) {
        return (ConvertTo-GgsCommandPreview -Plan (Get-GgsStashPopCommandPlan -StashRef $stashRef -RestoreIndex:$RestoreIndex))
    }
    $indexPart = if ($RestoreIndex) { ' --index' } else { '' }
    return "git stash pop$indexPart $stashRef"
}

function Build-StashPopIndexPreview { return (Build-StashPopPreview -RestoreIndex) }

function Build-StashDropPreview {
    $stashRef = Get-SelectedStashRef
    if (-not $stashRef) { $stashRef = '<selected-stash>' }
    if ((Get-Command Get-GgsStashDropCommandPlan -ErrorAction SilentlyContinue) -and (Get-Command Test-GgsStashRef -ErrorAction SilentlyContinue) -and (Test-GgsStashRef $stashRef)) {
        return (ConvertTo-GgsCommandPreview -Plan (Get-GgsStashDropCommandPlan -StashRef $stashRef))
    }
    return "git stash drop $stashRef"
}

function Build-StashBranchPreview {
    $stashRef = Get-SelectedStashRef -DefaultLatest
    if (-not $stashRef) { $stashRef = 'stash@{0}' }
    $branchName = if ($script:StashBranchTextBox -and -not [string]::IsNullOrWhiteSpace($script:StashBranchTextBox.Text)) { $script:StashBranchTextBox.Text.Trim() } else { '<new-branch>' }
    if ((Get-Command Get-GgsStashBranchCommandPlan -ErrorAction SilentlyContinue) -and (Get-Command Test-GgsStashRef -ErrorAction SilentlyContinue) -and (Test-GgsStashRef $stashRef) -and $branchName -ne '<new-branch>') {
        return (ConvertTo-GgsCommandPreview -Plan (Get-GgsStashBranchCommandPlan -BranchName $branchName -StashRef $stashRef))
    }
    return "git stash branch $(Quote-Arg $branchName) $stashRef"
}

function Build-CustomGitPreview {

    $cmd = if ($script:CustomGitCommandTextBox) { $script:CustomGitCommandTextBox.Text.Trim() } else { '' }
    if ([string]::IsNullOrWhiteSpace($cmd)) { return 'git <custom arguments>' }
    try {
        return (Format-GitCommandArgs -Arguments (Convert-GitCommandTextToArgs -CommandText $cmd))
    } catch {
        return "git <invalid custom command>`r`n# $($_.Exception.Message)"
    }
}

function Build-StatusPreview {
    return 'git status'
}

function Build-HistoryPreview {
    $max = [int]$script:Config.MaxHistoryLines
    if ($script:HistoryMaxCountUpDown) { $max = [int]$script:HistoryMaxCountUpDown.Value }
    if (Get-Command Get-GghGraphCommandPlan -ErrorAction SilentlyContinue) { return (ConvertTo-GghCommandPreview -Plans (Get-GghGraphCommandPlan -MaxCount $max)) }
    return "git log --graph --decorate --oneline --all -n $max"
}

function Build-HistoryModelPreview {
    $max = [int]$script:Config.MaxHistoryLines
    if ($script:HistoryMaxCountUpDown) { $max = [int]$script:HistoryMaxCountUpDown.Value }
    if (Get-Command Get-GghHistoryModelCommandPlan -ErrorAction SilentlyContinue) { return (ConvertTo-GghCommandPreview -Plans (Get-GghHistoryModelCommandPlan -MaxCount ([Math]::Max($max, 80)))) }
    return 'git log --date=iso-strict --format=<graph-model-fields> --all'
}

#endregion

#region Commit Functions

function Get-CommitPlan {
    $subject = if ($script:CommitSubjectTextBox) {
        $script:CommitSubjectTextBox.Text.Trim()
    } else { '' }

    $body = if ($script:CommitBodyTextBox) {
        $script:CommitBodyTextBox.Text
    } else { '' }

    $amend = if ($script:CommitAmendCheckBox) {
        [bool]$script:CommitAmendCheckBox.Checked
    } else { $false }

    $stageAll = if ($script:CommitStageAllCheckBox) {
        [bool]$script:CommitStageAllCheckBox.Checked
    } else { $false }

    $pushAfter = if ($script:CommitPushAfterCheckBox) {
        [bool]$script:CommitPushAfterCheckBox.Checked
    } else { $false }

    $enableConventional = if ($script:CommitConventionalGuidanceCheckBox) { [bool]$script:CommitConventionalGuidanceCheckBox.Checked } else { [bool]$script:Config.ConventionalCommitGuidanceEnabled }

    if (Get-Command Get-GgcCommitCommandPlan -ErrorAction SilentlyContinue) {
        return Get-GgcCommitCommandPlan -Subject $subject -Body $body -StageAll:$stageAll -Amend:$amend -PushAfter:$pushAfter -UseForceWithLease:([bool]$script:Config.UseForceWithLease) -DefaultRemoteName ([string]$script:Config.DefaultRemoteName) -MaxSubjectLength ([int]$script:Config.CommitSubjectMaxLength) -ConventionalCommits:$enableConventional
    }

    $messageText = if ([string]::IsNullOrWhiteSpace($subject)) {
        '<missing-subject>'
    } else {
        $msg = $subject
        if (-not [string]::IsNullOrWhiteSpace($body)) {
            $msg += "`r`n`r`n" + $body.TrimEnd()
        }
        $msg
    }

    $commands = New-Object System.Collections.Generic.List[string]
    if ($stageAll) { [void]$commands.Add('git add -A') }

    $commitParts = New-Object System.Collections.Generic.List[string]
    [void]$commitParts.Add('git commit')

    if ($amend) {
        [void]$commitParts.Add('--amend')
    }

    [void]$commitParts.Add('-F')
    [void]$commitParts.Add('<temp-commit-message-file>')
    [void]$commands.Add(($commitParts -join ' '))

    if ($pushAfter) {
        if ($amend -and $script:Config.UseForceWithLease) {
            [void]$commands.Add('git push --force-with-lease')
        } else {
            [void]$commands.Add('git push -u origin HEAD')
        }
    }

    return [pscustomobject]@{
        Subject = $subject
        Body = $body
        Amend = $amend
        StageAll = $stageAll
        PushAfter = $pushAfter
        MessageText = $messageText
        Commands = @($commands)
        Validation = (Validate-CommitSubject $subject)
        Plans = @()
    }
}

function Build-CommitMessageText {
    return (Get-CommitPlan).MessageText
}

function Build-CommitPreview {
    $plan = Get-CommitPlan
    $commandsText = if ($plan.Commands) { @($plan.Commands) -join "`r`n" } else { 'git commit -F <temp-commit-message-file>' }
    $guidance = ''
    try {
        if ($plan.Validation) {
            $validation = $plan.Validation
            if (-not [string]::IsNullOrWhiteSpace([string]$validation.Warning)) { $guidance += "`r`nWarning: $($validation.Warning)" }
            if (-not [string]::IsNullOrWhiteSpace([string]$validation.Guidance)) { $guidance += "`r`nGuidance: $($validation.Guidance)" }
        }
    } catch {}
    return $commandsText + "`r`n`r`nCommit message file content:`r`n--------------------------------`r`n" + $plan.MessageText + $guidance
}

function Update-CommitPreview {
    Set-CommandPreview -Title 'Commit preview' -Commands (Build-CommitPreview) -Notes 'Edit the subject/body or options to update this preview.'
}

#endregion

#region Preview Helper Functions

function Invoke-PreviewBuilder {
    param(
        [scriptblock]$Builder,
        [string]$Fallback = '(preview unavailable)'
    )

    try {
        $result = & $Builder
        if ([string]::IsNullOrWhiteSpace([string]$result)) {
            return $Fallback
        }
        return [string]$result
    } catch {
        return "$Fallback`r`nError: $($_.Exception.Message)"
    }
}

function New-TooltipText {
    param(
        [string]$Title,
        [string]$Description = '',
        [string]$Commands = ''
    )

    $parts = New-Object System.Collections.Generic.List[string]
    if ($Title) { [void]$parts.Add($Title) }
    if ($Description) {
        [void]$parts.Add('')
        [void]$parts.Add($Description)
    }
    if ($Commands) {
        [void]$parts.Add('')
        [void]$parts.Add('Git command preview:')
        [void]$parts.Add($Commands)
    }
    return ($parts -join "`r`n")
}

function Set-ControlPreview {
    param(
        [System.Windows.Forms.Control]$Control,
        [scriptblock]$Builder,
        [string]$Title,
        [string]$Notes = ''
    )
    if (-not $Control) { return }
    if (-not $script:ToolTip) { return }

    $initialCommands = Invoke-PreviewBuilder -Builder $Builder
    $script:ToolTip.SetToolTip($Control, (New-TooltipText -Title $Title -Description $Notes -Commands $initialCommands))

    $Control.Add_MouseEnter({
        $commands = Invoke-PreviewBuilder -Builder $Builder
        Set-CommandPreview -Title $Title -Commands $commands -Notes $Notes
        if ($script:ToolTip -and $Control) {
            $script:ToolTip.SetToolTip($Control, (New-TooltipText -Title $Title -Description $Notes -Commands $commands))
        }
    }.GetNewClosure())
}

#endregion

#region Git Operations

function Load-LocalBranches {
    if (-not (Test-GitRepository)) { return }
    try {
        $result = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'for-each-ref', '--format=%(refname:short)', 'refs/heads') -Caption 'git for-each-ref --format=%(refname:short) refs/heads' -AllowFailure

        if ($result.ExitCode -ne 0) { return }

        $branches = @($result.StdOut -split "`r?`n" | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_)
        })

        $currentText = if ($script:BranchSwitchComboBox) {
            $script:BranchSwitchComboBox.Text
        } else { '' }

        if ($script:BranchSwitchComboBox) {
            $script:BranchSwitchComboBox.BeginUpdate()
            $script:BranchSwitchComboBox.Items.Clear()
            foreach ($branch in $branches) {
                [void]$script:BranchSwitchComboBox.Items.Add($branch.Trim())
            }

            if ($script:CurrentBranch -and $script:BranchSwitchComboBox.Items.Contains($script:CurrentBranch)) {
                $script:BranchSwitchComboBox.SelectedItem = $script:CurrentBranch
            } elseif ($currentText -and $script:BranchSwitchComboBox.Items.Contains($currentText)) {
                $script:BranchSwitchComboBox.SelectedItem = $currentText
            } elseif ($script:BranchSwitchComboBox.Items.Count -gt 0) {
                $script:BranchSwitchComboBox.SelectedIndex = 0
            }

            $script:BranchSwitchComboBox.EndUpdate()
        }
        if ($script:IntegrationFeatureBranchComboBox) {
            $currentFeatureText = [string]$script:IntegrationFeatureBranchComboBox.Text
            $script:IntegrationFeatureBranchComboBox.BeginUpdate()
            $script:IntegrationFeatureBranchComboBox.Items.Clear()
            foreach ($branch in $branches) {
                $b = $branch.Trim()
                if ($b -and $b -ne [string]$script:Config.BaseBranch -and $b -ne [string]$script:Config.MainBranch) {
                    [void]$script:IntegrationFeatureBranchComboBox.Items.Add($b)
                }
            }
            if ($currentFeatureText -and $script:IntegrationFeatureBranchComboBox.Items.Contains($currentFeatureText)) {
                $script:IntegrationFeatureBranchComboBox.SelectedItem = $currentFeatureText
            } elseif ($script:CurrentBranch -and $script:IntegrationFeatureBranchComboBox.Items.Contains($script:CurrentBranch)) {
                $script:IntegrationFeatureBranchComboBox.SelectedItem = $script:CurrentBranch
            } elseif ($script:IntegrationFeatureBranchComboBox.Items.Count -gt 0) {
                $script:IntegrationFeatureBranchComboBox.SelectedIndex = 0
            }
            $script:IntegrationFeatureBranchComboBox.EndUpdate()
        }
    } catch {
        Append-Log -Text ('Branch list refresh failed: ' + $_.Exception.Message) -Color ([System.Drawing.Color]::Firebrick)
    }
}

function Load-StashList {
    if (-not (Test-GitRepository)) {
        $script:StashList = @()
        if ($script:StashListBox) { $script:StashListBox.Items.Clear(); [void]$script:StashListBox.Items.Add('(Open a Git repository first)') }
        if ($script:StashCountLabel) { $script:StashCountLabel.Text = '0' }
        return
    }
    try {
        $result = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'stash', 'list') -Caption 'git stash list' -AllowFailure

        if ($result.ExitCode -ne 0) { return }

        $stashes = @($result.StdOut -split "`r?`n" | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_)
        })

        $script:StashList = $stashes

        if ($script:StashListBox) {
            $script:StashListBox.BeginUpdate()
            $script:StashListBox.Items.Clear()
            foreach ($stash in $stashes) {
                [void]$script:StashListBox.Items.Add($stash)
            }
            $script:StashListBox.EndUpdate()
        }

        if ($script:StashCountLabel) {
            $script:StashCountLabel.Text = [string]$stashes.Count
        }
    } catch {
        Append-Log -Text ('Stash list refresh failed: ' + $_.Exception.Message) -Color ([System.Drawing.Color]::Firebrick)
    }
}

function ConvertTo-RepositoryStatusSnapshotFallback {
    $statusResult = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'status', '--porcelain=v1', '--branch') -Caption 'git status --porcelain=v1 --branch' -AllowFailure
    if ($statusResult.ExitCode -ne 0) {
        return [pscustomobject]@{
            Success = $false
            ExitCode = $statusResult.ExitCode
            Error = $statusResult.StdErr
            Branch = '(unknown)'
            Upstream = '(none)'
            BranchState = 'unknown'
            Items = @()
            Summary = [pscustomobject]@{ Total = 0; Staged = 0; Unstaged = 0; Untracked = 0; Conflicted = 0; IsClean = $true }
            Suggestion = 'Git status failed. Check that this folder is a Git repository and that Git is available.'
        }
    }

    $lines = @($statusResult.StdOut -split "`r?`n" | Where-Object { $_ -ne '' })
    $branchLine = $lines | Select-Object -First 1
    $rawItems = @($lines | Select-Object -Skip 1)

    $branch = '(detached?)'
    $upstream = '(none)'
    $state = 'unknown'
    if ($branchLine -match '^##\s+No commits yet on (?<newbranch>.+)$') {
        $branch = $matches['newbranch']
        $upstream = '(none)'
        $state = 'no commits yet'
    } elseif ($branchLine -match '^##\s+(?<branch>[^\.\s]+)(?:\.\.\.(?<upstream>[^\s]+))?(?:\s+(?<state>\[[^\]]+\]))?') {
        $branch = $matches['branch']
        if ($matches['upstream']) { $upstream = $matches['upstream'] }
        if ($matches['state']) { $state = $matches['state'].Trim('[',']') }
        elseif ($matches['upstream']) { $state = 'up to date' }
    }

    $items = @($rawItems | ForEach-Object { Convert-GitPorcelainStatusLine -Line $_ } | Where-Object { $_ })
    $staged = 0; $unstaged = 0; $untracked = 0; $conflicted = 0
    foreach ($item in $items) {
        if ($item.Status -eq '??') { $untracked++; continue }
        if ($item.Status -match 'U' -or $item.Status -in @('AA','DD')) { $conflicted++ }
        if ($item.IndexStatus -ne ' ' -and $item.IndexStatus -ne '?') { $staged++ }
        if ($item.WorkTreeStatus -ne ' ' -and $item.WorkTreeStatus -ne '?') { $unstaged++ }
    }
    $summary = [pscustomobject]@{ Total = $items.Count; Staged = $staged; Unstaged = $unstaged; Untracked = $untracked; Conflicted = $conflicted; IsClean = ($items.Count -eq 0) }
    $suggestion = Get-SuggestedNextAction -Branch $branch -Upstream $upstream -BranchState $state -Summary $summary

    return [pscustomobject]@{
        Success = $true
        ExitCode = 0
        Error = ''
        Branch = $branch
        Upstream = $upstream
        BranchState = $state
        Items = $items
        Summary = $summary
        Suggestion = $suggestion
    }
}

function Get-RepositoryStatusSnapshot {
    try {
        $cmd = Get-Command Get-GfgRepositoryStatus -ErrorAction SilentlyContinue
        if ($cmd) { return Get-GfgRepositoryStatus -RepositoryPath $script:RepoRoot }
    } catch {
        Append-Log -Text ('Repository status service failed, using fallback parser: ' + $_.Exception.Message) -Color ([System.Drawing.Color]::DarkOrange)
    }
    return ConvertTo-RepositoryStatusSnapshotFallback
}

function Get-SuggestedNextAction {
    param(
        [string]$Branch,
        [string]$Upstream,
        [string]$BranchState,
        [object]$Summary
    )

    try {
        $cmd = Get-Command Get-GfgRepositoryStatusSuggestion -ErrorAction SilentlyContinue
        if ($cmd) { return Get-GfgRepositoryStatusSuggestion -Branch $Branch -Upstream $Upstream -BranchState $BranchState -Summary $Summary }
    } catch {}

    if ($BranchState -eq 'no commits yet') {
        return 'This repository has no commits yet. Use Setup > First commit... to create .gitignore, stage files, and create the initial commit.'
    }
    if ($Branch -eq '(detached?)') { return 'You are in detached HEAD. Create a branch from this commit or switch back before making normal commits.' }
    if ($Summary -and [int]$Summary.Conflicted -gt 0) { return 'Resolve merge conflicts first, then stage the resolved files and continue the merge/rebase.' }
    if ($Summary -and [int]$Summary.Staged -gt 0) { return 'Review the staged changes and commit them. Use the preview/output panes before pushing.' }
    if ($Summary -and ([int]$Summary.Unstaged -gt 0 -or [int]$Summary.Untracked -gt 0)) { return 'Stage the intended files, or stash the work-in-progress before switching branches.' }
    if ($BranchState -match 'ahead') { return 'Your branch has local commits. Push with normal push or force-with-lease only when intentionally rewriting remote history.' }
    if ($BranchState -match 'behind') { return 'Your branch is behind upstream. Pull/rebase before new work to reduce conflict risk.' }
    if ([string]::IsNullOrWhiteSpace($Upstream) -or $Upstream -eq '(none)') { return 'No upstream is configured. Push and set upstream when this branch is ready to share.' }
    return 'Working tree is clean. Start a feature branch, fetch updates, or create a release/tag when appropriate.'
}

function Set-SuggestedNextAction {
    param(
        [string]$Text,
        [string]$Action = ''
    )
    if ([string]::IsNullOrWhiteSpace($Text)) { $Text = 'Refresh repository status to get a suggestion.' }
    $script:SuggestedNextActionKind = $Action
    if ($script:SuggestedNextActionLabel) {
        $script:SuggestedNextActionLabel.Text = $Text
    }
    if ($script:SuggestedNextActionButton) {
        if ([string]::IsNullOrWhiteSpace($Action)) {
            $script:SuggestedNextActionButton.Enabled = $false
            $script:SuggestedNextActionButton.Text = 'Do it'
        } else {
            $script:SuggestedNextActionButton.Enabled = $true
            $script:SuggestedNextActionButton.Text = 'Do it'
        }
    }
}

function Set-SuggestedNextActionFromSnapshot {
    param([object]$Snapshot)

    if (-not $Snapshot) {
        Set-SuggestedNextAction -Text 'Refresh repository status to get a suggestion.'
        return
    }

    $text = [string]$Snapshot.Suggestion
    $action = ''
    $summary = $Snapshot.Summary
    $branchState = [string]$Snapshot.BranchState
    $branch = [string]$Snapshot.Branch
    $upstream = [string]$Snapshot.Upstream

    if ($branchState -eq 'no commits yet') {
        $action = 'first-commit'
    } elseif ($summary -and [int]$summary.Conflicted -gt 0) {
        $action = 'show-diff'
    } elseif ($summary -and [int]$summary.Staged -gt 0) {
        $action = 'focus-commit'
    } elseif ($summary -and ([int]$summary.Unstaged -gt 0 -or [int]$summary.Untracked -gt 0)) {
        $stashSuggestion = $null
        if (Get-Command Get-GgsDirtyWorkTreeStashSuggestion -ErrorAction SilentlyContinue) { $stashSuggestion = Get-GgsDirtyWorkTreeStashSuggestion -Summary $summary }
        if ($stashSuggestion) {
            $text = [string]$stashSuggestion.Message
            $action = [string]$stashSuggestion.Action
        } else {
            $action = 'stage-tab'
        }
    } elseif ($branchState -match 'ahead') {
        $action = 'push-current'
    } elseif ($branchState -match 'behind') {
        $action = 'pull-current'
    } elseif (([string]::IsNullOrWhiteSpace($upstream) -or $upstream -eq '(none)') -and -not [string]::IsNullOrWhiteSpace($branch) -and $branch -ne '(detached?)') {
        $action = 'remote-setup'
    } elseif ($summary -and [int]$summary.Total -eq 0) {
        $action = 'branch-tab'
    }

    Set-SuggestedNextAction -Text $text -Action $action
}
function Invoke-SuggestedNextAction {
    $action = [string]$script:SuggestedNextActionKind
    switch ($action) {
        'choose-repo' { [void](Ensure-RepositorySelected); break }
        'first-commit' { [void](Invoke-FirstCommitWizard); break }
        'focus-commit' {
            if ($script:CommitSubjectTextBox) { $script:CommitSubjectTextBox.Focus() }
            Update-CommitPreview
            break
        }
        'stage-tab' {
            if ($script:ActionsTabs -and $script:StageTabPage) { $script:ActionsTabs.SelectedTab = $script:StageTabPage }
            if ($script:ChangedFilesList -and $script:ChangedFilesList.Items.Count -gt 0) { $script:ChangedFilesList.Focus() }
            break
        }
        'branch-tab' {
            if ($script:ActionsTabs -and $script:BranchTabPage) { $script:ActionsTabs.SelectedTab = $script:BranchTabPage }
            if ($script:FeatureBranchTextBox) { $script:FeatureBranchTextBox.Focus() }
            break
        }
        'push-current' { Push-CurrentBranch -ConfirmBeforePush; break }
        'recovery-tab' {
            if ($script:ActionsTabs -and $script:RecoveryTabPage) { $script:ActionsTabs.SelectedTab = $script:RecoveryTabPage }
            break
        }
        'history-tab' {
            if ($script:ActionsTabs -and $script:HistoryTabPage) { $script:ActionsTabs.SelectedTab = $script:HistoryTabPage }
            break
        }
        'pull-current' { Pull-CurrentBranch -ConfirmBeforePull; break }
        'stash-dirty-work' { Invoke-StashDirtyWorkSuggestedAction; break }
        'remote-setup' { [void](Show-RemoteSetupDialog); break }
        'open-pr-url' { Open-LastPullRequestUrl; break }
        'show-diff' { Show-SelectedDiff; break }
        default {
            Set-CommandPreview -Title 'Suggested next action' -Commands '(no safe one-click action is available for this state)' -Notes 'The suggestion is informational because automatically executing this Git workflow could surprise the user.'
        }
    }
}

function Get-BranchRoleInfo {
    param([AllowNull()][string]$BranchName)
    $branch = [string]$BranchName
    if ([string]::IsNullOrWhiteSpace($branch)) {
        return [pscustomobject]@{ Role = 'unknown'; Severity = 'neutral'; Description = 'No branch detected.'; Recommended = 'Select or initialize a repository.' }
    }
    if ($branch -eq [string]$script:Config.MainBranch) {
        return [pscustomobject]@{ Role = 'protected release branch'; Severity = 'danger'; Description = 'main is the protected release/shipping branch.'; Recommended = 'Create a feature/fix branch before committing normal work.' }
    }
    if ($branch -eq [string]$script:Config.BaseBranch) {
        return [pscustomobject]@{ Role = 'integration branch'; Severity = 'warning'; Description = 'develop integrates finished feature/fix branches.'; Recommended = 'Merge feature branches here, run quality checks, then promote to main.' }
    }
    if ($branch -like 'feature/*') {
        return [pscustomobject]@{ Role = 'feature branch'; Severity = 'safe'; Description = 'feature branches are the normal place for product work.'; Recommended = 'Commit, push with upstream, then merge into develop.' }
    }
    if ($branch -like 'fix/*') {
        return [pscustomobject]@{ Role = 'fix branch'; Severity = 'safe'; Description = 'fix branches are the normal place for bug fixes and stabilization.'; Recommended = 'Commit, push with upstream, then merge into develop.' }
    }
    if ($branch -like 'hotfix/*') {
        return [pscustomobject]@{ Role = 'hotfix branch'; Severity = 'warning'; Description = 'hotfix branches usually target urgent release fixes.'; Recommended = 'Review carefully, run quality checks, then merge to main and back into develop.' }
    }
    if ($branch -like 'release/*') {
        return [pscustomobject]@{ Role = 'release branch'; Severity = 'warning'; Description = 'release branches prepare a tested version for main.'; Recommended = 'Run quality checks and keep changes focused on release stabilization.' }
    }
    return [pscustomobject]@{ Role = 'custom branch'; Severity = 'neutral'; Description = 'Custom branch naming is allowed.'; Recommended = 'Make sure this branch fits your intended workflow before committing.' }
}

function Update-ChangedFilesContextBanner {
    param([AllowNull()][object]$Snapshot)
    if (-not $script:ChangedFilesContextLabel) { return }
    $branch = [string]$script:CurrentBranch
    $upstream = [string]$script:CurrentUpstream
    $branchState = [string]$script:CurrentBranchState
    $changed = if ($Snapshot -and $Snapshot.Items) { @($Snapshot.Items).Count } else { @($script:StatusItems).Count }
    $role = Get-BranchRoleInfo -BranchName $branch
    $upstreamText = if ([string]::IsNullOrWhiteSpace($upstream)) { '(no upstream)' } else { $upstream }
    $stateText = if ([string]::IsNullOrWhiteSpace($branchState)) { '-' } else { $branchState }
    $mode = Get-UiMode
    $bannerParts = @(
        "Mode: $mode"
        "Branch: $branch"
        "Role: $($role.Role)"
        "Upstream: $upstreamText"
        "State: $stateText"
        "Changed: $changed"
        "Next: $($role.Recommended)"
    )
    $bannerText = $bannerParts -join '  |  '
    $script:ChangedFilesContextLabel.Text = $bannerText
    try {
        if ($role.Severity -eq 'danger') { $script:ChangedFilesContextLabel.BackColor = [System.Drawing.Color]::MistyRose; $script:ChangedFilesContextLabel.ForeColor = [System.Drawing.Color]::DarkRed }
        elseif ($role.Severity -eq 'warning') { $script:ChangedFilesContextLabel.BackColor = [System.Drawing.Color]::LemonChiffon; $script:ChangedFilesContextLabel.ForeColor = [System.Drawing.Color]::SaddleBrown }
        elseif ($role.Severity -eq 'safe') { $script:ChangedFilesContextLabel.BackColor = [System.Drawing.Color]::Honeydew; $script:ChangedFilesContextLabel.ForeColor = [System.Drawing.Color]::DarkGreen }
        else { $script:ChangedFilesContextLabel.BackColor = [System.Drawing.Color]::AliceBlue; $script:ChangedFilesContextLabel.ForeColor = [System.Drawing.Color]::MidnightBlue }
    } catch {}
    Resize-ChangedFilesContextBanner
}

function New-SuggestedBranchName {
    param([string]$Kind = 'fix')
    $raw = [string]$script:CommitSubjectTextBox.Text
    if ([string]::IsNullOrWhiteSpace($raw)) { $raw = 'work-in-progress' }
    $slug = $raw.ToLowerInvariant() -replace '[^a-z0-9]+','-' -replace '(^-+|-+$)',''
    if ([string]::IsNullOrWhiteSpace($slug)) { $slug = 'work-in-progress' }
    if ($slug.Length -gt 48) { $slug = $slug.Substring(0,48).Trim('-') }
    return ('{0}/{1}' -f $Kind, $slug)
}

function Invoke-CreateBranchBeforeProtectedCommit {
    param([string]$SuggestedName)
    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = 'Create branch before committing'
    $dialog.Size = New-Object System.Drawing.Size(620, 240)
    $dialog.StartPosition = 'CenterParent'
    $dialog.MinimizeBox = $false; $dialog.MaximizeBox = $false
    $dialog.FormBorderStyle = 'FixedDialog'
    $dialog.Font = $script:UiFont

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = 'Fill'; $layout.Padding = New-Object System.Windows.Forms.Padding(12); $layout.ColumnCount = 1; $layout.RowCount = 4
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100)))
    $dialog.Controls.Add($layout)

    $info = New-Object System.Windows.Forms.Label
    $info.AutoSize = $true; $info.MaximumSize = New-Object System.Drawing.Size(570,0)
    $info.Text = "You are on '$($script:CurrentBranch)'. Normal work should usually be committed on a feature/fix branch. Uncommitted changes will stay in your working tree when the new branch is created."
    $layout.Controls.Add($info,0,0)

    $label = New-Object System.Windows.Forms.Label
    $label.AutoSize = $true; $label.Text = 'New branch name:'; $label.Margin = New-Object System.Windows.Forms.Padding(0,12,0,2)
    $layout.Controls.Add($label,0,1)

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Dock = 'Top'; $textBox.Text = $SuggestedName
    $layout.Controls.Add($textBox,0,2)

    $buttons = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttons.Dock = 'Bottom'; $buttons.FlowDirection = 'RightToLeft'; $buttons.AutoSize = $true
    $layout.Controls.Add($buttons,0,3)
    $cancel = New-Object System.Windows.Forms.Button; $cancel.Text='Cancel'; $cancel.Width=90; $cancel.DialogResult=[System.Windows.Forms.DialogResult]::Cancel; $buttons.Controls.Add($cancel)
    $create = New-Object System.Windows.Forms.Button; $create.Text='Create branch'; $create.Width=120; $create.DialogResult=[System.Windows.Forms.DialogResult]::OK; $buttons.Controls.Add($create)
    $dialog.AcceptButton = $create; $dialog.CancelButton = $cancel

    $result = $dialog.ShowDialog($form)
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) { return $false }
    $name = $textBox.Text.Trim()
    if (Get-Command Test-GgbBranchName -ErrorAction SilentlyContinue) {
        $v = Test-GgbBranchName -Name $name
        if (-not $v.Valid) { [System.Windows.Forms.MessageBox]::Show($v.Error, 'Invalid branch name', 'OK', 'Warning') | Out-Null; return $false }
    }
    $cmd = @('-C', $script:RepoRoot, 'switch', '-c', $name)
    [void](Run-External -FileName 'git' -Arguments $cmd -Caption ('git switch -c ' + (Quote-Arg $name)))
    Refresh-Status
    return $true
}

function Confirm-ProtectedBranchWorkflowAction {
    param([string]$ActionName = 'continue')
    if (-not $script:CurrentBranch) { Refresh-Status }
    $branch = [string]$script:CurrentBranch
    if ([string]::IsNullOrWhiteSpace($branch)) { return $true }
    $role = Get-BranchRoleInfo -BranchName $branch
    if ($role.Severity -ne 'danger' -and $role.Severity -ne 'warning') { return $true }

    $message = "You are on '$branch' ($($role.Role)).`r`n`r`n$($role.Description)`r`n`r`nRecommended: $($role.Recommended)`r`n`r`nFor normal feature/fix work, create a branch first, commit there, merge feature/fix -> $($script:Config.BaseBranch), run quality checks, then promote $($script:Config.BaseBranch) -> $($script:Config.MainBranch).`r`n`r`nChoose Yes to create a new branch first, No to $ActionName on '$branch' anyway, or Cancel."
    $answer = [System.Windows.Forms.MessageBox]::Show($message, 'Protected branch workflow guard', [System.Windows.Forms.MessageBoxButtons]::YesNoCancel, [System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($answer -eq [System.Windows.Forms.DialogResult]::Cancel) { return $false }
    if ($answer -eq [System.Windows.Forms.DialogResult]::No) { return $true }
    $suggested = New-SuggestedBranchName -Kind 'fix'
    return (Invoke-CreateBranchBeforeProtectedCommit -SuggestedName $suggested)
}


function Refresh-Status {
    try {
        if (-not (Test-GitRepository)) {
            if ($script:RepoPathValueLabel) { $script:RepoPathValueLabel.Text = if ([string]::IsNullOrWhiteSpace($script:RepoRoot)) { '(no repository selected)' } else { $script:RepoRoot } }
            if ($script:BranchValueLabel) { $script:BranchValueLabel.Text = '-' }
            if ($script:UpstreamValueLabel) { $script:UpstreamValueLabel.Text = '-' }
            if ($script:BranchStateValueLabel) { $script:BranchStateValueLabel.Text = '-' }
            if ($script:WorkingTreeValueLabel) { $script:WorkingTreeValueLabel.Text = 'not a repository' }
            if ($script:ChangedCountValueLabel) { $script:ChangedCountValueLabel.Text = '0' }
            if ($script:ChangedFilesList) { $script:ChangedFilesList.Items.Clear() }
            $script:StatusItems = @()
            Update-ChangedFilesContextBanner
            Set-SuggestedNextAction -Text 'Open existing repo or init new repo before running Git operations.' -Action 'choose-repo'
            return
        }

        $script:BranchValueLabel.Text = 'loading...'
        $script:WorkingTreeValueLabel.Text = 'loading...'
        Set-SuggestedNextAction -Text 'Refreshing repository status...'
        $script:ChangedFilesList.Items.Clear()
        $script:StatusItems = @()

        $snapshot = Get-RepositoryStatusSnapshot
        if (-not $snapshot -or -not $snapshot.Success) {
            $message = if ($snapshot -and $snapshot.Error) { $snapshot.Error } else { 'git status failed.' }
            Append-Log -Text ('Refresh failed: ' + $message) -Color ([System.Drawing.Color]::Firebrick)
            Set-SuggestedNextAction -Text 'Git status failed. Check that this folder is a Git repository and that Git is available.'
            return
        }

        $items = @($snapshot.Items)
        $script:CurrentBranch = [string]$snapshot.Branch
        $script:CurrentUpstream = [string]$snapshot.Upstream
        $script:CurrentBranchState = [string]$snapshot.BranchState

        $script:BranchValueLabel.Text = $script:CurrentBranch
        $script:UpstreamValueLabel.Text = $script:CurrentUpstream
        $script:BranchStateValueLabel.Text = $script:CurrentBranchState
        $script:WorkingTreeValueLabel.Text = if ($items.Count -gt 0) { 'changed' } else { 'clean' }
        $script:RepoPathValueLabel.Text = $script:RepoRoot
        $script:ChangedCountValueLabel.Text = [string]$items.Count
        Set-SuggestedNextActionFromSnapshot -Snapshot $snapshot
        Update-ChangedFilesContextBanner -Snapshot $snapshot

        Load-LocalBranches
        Load-StashList

        $script:SuppressDiffPreview = $true
        $script:ChangedFilesList.BeginUpdate()
        try {
            foreach ($parsed in $items) {
                if (-not $parsed) { continue }
                $display = if (Get-Command Get-GggStatusDisplayText -ErrorAction SilentlyContinue) { Get-GggStatusDisplayText -Item $parsed } else { ('[{0}] {1}' -f $parsed.Status, $parsed.RawPath) }
                # Pure PowerShell row payload. DisplayMember shows Display, while
                # StatusItem keeps the parsed git status available for diff/stage/unstage.
                $listItem = [pscustomobject]@{
                    Display = $display
                    StatusItem = $parsed
                    Path = [string]$parsed.Path
                    RawPath = [string]$parsed.RawPath
                    Status = [string]$parsed.Status
                }
                [void]$script:ChangedFilesList.Items.Add($listItem)
                $script:StatusItems += $parsed
            }
        } finally {
            $script:ChangedFilesList.EndUpdate()
            $script:SuppressDiffPreview = $false
        }

        if ($script:StatusItems.Count -eq 0) {
            $script:DiffTextBox.Text = ('Working tree is clean on branch {0}. No file diff to preview.`r`nLast refreshed: {1}`r`nIf this differs from git status, click Refresh.' -f $script:CurrentBranch, (Get-Date -Format 'HH:mm:ss'))
        } else {
            if ($script:ChangedFilesList.SelectedIndex -lt 0) { $script:ChangedFilesList.SelectedIndex = 0 }
            if (Get-ConfigBool -Name 'AutoPreviewDiffOnSelection' -DefaultValue $true) { Show-SelectedDiff }
        }

        Set-StatusBar("Ready. Branch: $($script:CurrentBranch)")
    } catch {
        Append-Log -Text ('Refresh failed: ' + $_.Exception.Message) -Color ([System.Drawing.Color]::Firebrick)
        Set-SuggestedNextAction -Text 'Refresh failed. Check the Output tab for details.'
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Refresh failed', 'OK', 'Error') | Out-Null
    }
}

function Show-SelectedDiff {
    if ($script:SuppressDiffPreview) { return }

    if ($script:ChangedFilesList -and $script:ChangedFilesList.Items.Count -gt 0 -and $script:ChangedFilesList.SelectedIndex -lt 0) {
        # Make the Show diff button forgiving: if there are changed files but no
        # selected item according to WinForms, use the first row instead of showing
        # the unhelpful placeholder.
        $script:ChangedFilesList.SelectedIndex = 0
    }

    $item = Get-SelectedStatusItem
    if (-not $item) {
        $debug = ''
        if ($script:ChangedFilesList) {
            $debug = "`r`n`r`nDebug: Items=$($script:ChangedFilesList.Items.Count), SelectedIndex=$($script:ChangedFilesList.SelectedIndex), StatusItems=$(@($script:StatusItems).Count). Click Refresh, then select a row."
        }
        $script:DiffTextBox.Text = "(Select a changed file to preview its diff.)$debug"
        return
    }

    $oldCursor = $form.Cursor
    try {
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        Set-StatusBar('Loading diff preview...')

        $path = [string]$item.Path
        $paths = Get-DiffTargetPaths -Item $item
        $sections = New-Object System.Collections.Generic.List[string]

        $header = New-Object System.Collections.Generic.List[string]
        [void]$header.Add(('File:   ' + $item.RawPath))
        [void]$header.Add(('Status: [{0}] {1}' -f $item.Status, (Get-StatusMeaning -Status $item.Status)))
        if ($item.OriginalPath) { [void]$header.Add(('Rename: ' + $item.OriginalPath + ' -> ' + $item.Path)) }
        [void]$header.Add('')

        if ($item.Status -eq '??') {
            [void]$header.Add((Get-UntrackedFilePreview -RelativePath $path))
            $script:DiffTextBox.Text = ($header -join "`r`n")
            Set-StatusBar('Ready. Untracked file preview loaded.')
            return
        }

        if ($item.Status -match 'U') {
            $ccArgs = @('diff', '--no-ext-diff', '--no-color', '--cc', '--') + $paths
            $ccText = Invoke-GitDiffText -DiffArguments $ccArgs -Caption ('git diff --cc -- ' + ($paths -join ' '))
            Add-DiffSection -Sections $sections -Title 'Conflict diff' -Text $ccText
        } else {
            if ($item.IndexStatus -ne ' ' -and $item.IndexStatus -ne '?') {
                $cachedArgs = @('diff', '--no-ext-diff', '--no-color', '--find-renames', '--cached', '--') + $paths
                $cachedText = Invoke-GitDiffText -DiffArguments $cachedArgs -Caption ('git diff --cached -- ' + ($paths -join ' '))
                Add-DiffSection -Sections $sections -Title 'Staged changes (index)' -Text $cachedText
            }

            if ($item.WorkTreeStatus -ne ' ' -and $item.WorkTreeStatus -ne '?') {
                $workArgs = @('diff', '--no-ext-diff', '--no-color', '--find-renames', '--') + $paths
                $workText = Invoke-GitDiffText -DiffArguments $workArgs -Caption ('git diff -- ' + ($paths -join ' '))
                Add-DiffSection -Sections $sections -Title 'Unstaged changes (working tree)' -Text $workText
            }
        }

        if ($sections.Count -eq 0) {
            $headArgs = @('diff', '--no-ext-diff', '--no-color', '--find-renames', 'HEAD', '--') + $paths
            $headText = Invoke-GitDiffText -DiffArguments $headArgs -Caption ('git diff HEAD -- ' + ($paths -join ' '))
            Add-DiffSection -Sections $sections -Title 'Changes compared with HEAD' -Text $headText
        }

        if ($sections.Count -eq 0) {
            [void]$sections.Add('(No textual diff output for selected file. This can happen for binary files, mode-only changes, or a clean path after refresh.)')
        }

        $script:DiffTextBox.Text = (@($header.ToArray()) + @($sections.ToArray()) -join "`r`n")
        Set-CommandPreview -Title 'Selected file diff preview' -Commands (Build-ShowDiffPreview) -Notes 'The preview separates staged and unstaged changes so you can see exactly what will be committed.'
        Set-StatusBar('Ready. Diff preview loaded.')
    } catch {
        Append-Log -Text ('Diff failed: ' + $_.Exception.Message) -Color ([System.Drawing.Color]::Firebrick)
        $script:DiffTextBox.Text = "Diff failed:`r`n$($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Diff failed', 'OK', 'Error') | Out-Null
    } finally {
        $form.Cursor = $oldCursor
    }
}

function Stage-SelectedFile {
    $items = Get-SelectedStatusItems
    if ($items.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('Select one or more changed files first.', 'No file selected', 'OK', 'Information') | Out-Null
        return
    }

    try {
        if (Get-Command Get-GggStageSelectedCommandPlan -ErrorAction SilentlyContinue) {
            foreach ($plan in @(Get-GggStageSelectedCommandPlan -Items $items)) {
                $gitArgs = @('-C', $script:RepoRoot) + @($plan.Arguments)
                [void](Run-External -FileName 'git' -Arguments $gitArgs -Caption $plan.Display)
            }
            Refresh-Status
            return
        }
        foreach ($item in $items) {
            [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'add', '--', $item.Path) -Caption ('git add -- ' + $item.Path))
        }
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Stage failed', 'OK', 'Error') | Out-Null
    }
}

function Unstage-SelectedFile {
    $items = Get-SelectedStatusItems
    if ($items.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('Select one or more changed files first.', 'No file selected', 'OK', 'Information') | Out-Null
        return
    }

    try {
        $hasCommits = Test-GitHasCommits
        if (Get-Command Get-GggUnstageSelectedCommandPlan -ErrorAction SilentlyContinue) {
            foreach ($plan in @(Get-GggUnstageSelectedCommandPlan -Items $items -RepositoryHasNoCommits:(-not $hasCommits))) {
                $gitArgs = @('-C', $script:RepoRoot) + @($plan.Arguments)
                [void](Run-External -FileName 'git' -Arguments $gitArgs -Caption $plan.Display -AllowFailure)
            }
            Refresh-Status
            return
        }
        foreach ($item in $items) {
            $unstageArgs = Get-UnstageGitArgumentsForPath -Path $item.Path
            [void](Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($unstageArgs)) -Caption ('git ' + (($unstageArgs | ForEach-Object { Quote-Arg ([string]$_) }) -join ' ')) -AllowFailure)
        }
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Unstage failed', 'OK', 'Error') | Out-Null
    }
}


function Invoke-RemoveFilesFromGitAndDisk {
    param([object[]]$Items)
    $items = @($Items | Where-Object { $_ })
    if ($items.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('Select one or more tracked files first. Use Browse tracked files if the file is clean and not listed under Changed Files.', 'No file selected', 'OK', 'Information') | Out-Null
        return
    }
    $preview = Build-RemoveFromGitPreviewForItems -Items $items
    $ok = Confirm-GuiAction -Title 'Remove from Git and disk' -Message ("This deletes the selected file(s) from the working folder and stages the deletion.`r`n`r`n$preview`r`n`r`nUse Stop tracking instead if the file should stay on disk.") -Icon ([System.Windows.Forms.MessageBoxIcon]::Warning)
    if (-not $ok) { return }
    try {
        if (Get-Command Get-GggRemoveFromGitCommandPlan -ErrorAction SilentlyContinue) {
            foreach ($plan in @(Get-GggRemoveFromGitCommandPlan -Items $items)) {
                $result = Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($plan.Arguments)) -Caption ([string]$plan.Display) -AllowFailure -ShowProgress
                if ($result.ExitCode -ne 0) { Show-GitFailureGuidance -Result $result -Operation 'remove file from Git and disk' -ShowDialog }
            }
        } else {
            foreach ($item in $items) { [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'rm', '--', $item.Path) -Caption ('git rm -- ' + $item.Path) -AllowFailure -ShowProgress) }
        }
        Refresh-Status
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Remove from Git failed', 'OK', 'Error') | Out-Null }
}

function Invoke-StopTrackingFilesKeepLocal {
    param([object[]]$Items)
    $items = @($Items | Where-Object { $_ })
    if ($items.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('Select one or more tracked files first. Use Browse tracked files if the file is clean and not listed under Changed Files.', 'No file selected', 'OK', 'Information') | Out-Null
        return
    }
    $preview = Build-StopTrackingPreviewForItems -Items $items
    $ok = Confirm-GuiAction -Title 'Stop tracking but keep local files' -Message ("This removes the selected file(s) from the Git index but keeps them on disk.`r`n`r`n$preview`r`n`r`nTypical use: replacing tracked files, accidentally committed config/log/build output, or local settings. Add them to .gitignore if they should stay untracked.") -Icon ([System.Windows.Forms.MessageBoxIcon]::Question)
    if (-not $ok) { return }
    try {
        if (Get-Command Get-GggStopTrackingCommandPlan -ErrorAction SilentlyContinue) {
            foreach ($plan in @(Get-GggStopTrackingCommandPlan -Items $items)) {
                $result = Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($plan.Arguments)) -Caption ([string]$plan.Display) -AllowFailure -ShowProgress
                if ($result.ExitCode -ne 0) { Show-GitFailureGuidance -Result $result -Operation 'stop tracking file but keep local copy' -ShowDialog }
            }
        } else {
            foreach ($item in $items) { [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'rm', '--cached', '--', $item.Path) -Caption ('git rm --cached -- ' + $item.Path) -AllowFailure -ShowProgress) }
        }
        Refresh-Status
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Stop tracking failed', 'OK', 'Error') | Out-Null }
}

function Remove-SelectedFilesFromGitAndDisk { Invoke-RemoveFilesFromGitAndDisk -Items (Get-SelectedStatusItems) }
function Stop-TrackingSelectedFilesKeepLocal { Invoke-StopTrackingFilesKeepLocal -Items (Get-SelectedStatusItems) }

function Show-TrackedFilesDialog {
    if (-not (Test-GitRepository)) { [System.Windows.Forms.MessageBox]::Show('Open or initialize a Git repository first.', 'No repository', 'OK', 'Information') | Out-Null; return }
    $trackedItems = @()
    try { $trackedItems = @(Get-TrackedFileItemsFromGit) } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Could not list tracked files', 'OK', 'Error') | Out-Null; return }

    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = 'Browse tracked files'
    $dialog.StartPosition = 'CenterParent'
    $dialog.Size = New-Object System.Drawing.Size(760, 560)
    $dialog.MinimumSize = New-Object System.Drawing.Size(620, 420)

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = 'Fill'; $layout.ColumnCount = 1; $layout.RowCount = 4; $layout.Padding = New-Object System.Windows.Forms.Padding(10)
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
    $dialog.Controls.Add($layout)

    $help = New-Object System.Windows.Forms.Label
    $help.Text = 'Clean tracked files are not shown in Changed Files. Select tracked files here when you need to replace, remove, or stop tracking a file that has not been modified yet.'
    $help.AutoSize = $false; $help.Height = 42; $help.Dock = 'Fill'
    $layout.Controls.Add($help, 0, 0)

    $filterPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $filterPanel.Dock = 'Fill'; $filterPanel.AutoSize = $true; $filterPanel.WrapContents = $false
    $layout.Controls.Add($filterPanel, 0, 1)
    $filterLabel = New-Object System.Windows.Forms.Label
    $filterLabel.Text = 'Filter:'; $filterLabel.AutoSize = $true; $filterLabel.Margin = New-Object System.Windows.Forms.Padding(0, 7, 8, 4)
    $filterPanel.Controls.Add($filterLabel)
    $filterBox = New-Object System.Windows.Forms.TextBox
    $filterBox.Width = 420; $filterBox.Margin = New-Object System.Windows.Forms.Padding(0, 3, 8, 4)
    $filterPanel.Controls.Add($filterBox)
    $countLabel = New-Object System.Windows.Forms.Label
    $countLabel.AutoSize = $true; $countLabel.Margin = New-Object System.Windows.Forms.Padding(8, 7, 4, 4)
    $filterPanel.Controls.Add($countLabel)

    $list = New-Object System.Windows.Forms.CheckedListBox
    $list.Dock = 'Fill'; $list.CheckOnClick = $true; $list.HorizontalScrollbar = $true; $list.DisplayMember = 'Display'
    $layout.Controls.Add($list, 0, 2)

    $buttonPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttonPanel.Dock = 'Fill'; $buttonPanel.FlowDirection = 'RightToLeft'; $buttonPanel.AutoSize = $true; $buttonPanel.WrapContents = $false
    $layout.Controls.Add($buttonPanel, 0, 3)
    $closeButton = New-Object System.Windows.Forms.Button; $closeButton.Text = 'Close'; $closeButton.Width = 90; $closeButton.Height = 32; $buttonPanel.Controls.Add($closeButton)
    $removeButton = New-Object System.Windows.Forms.Button; $removeButton.Text = 'Remove from Git and disk'; $removeButton.Width = 170; $removeButton.Height = 32; $buttonPanel.Controls.Add($removeButton)
    $stopButton = New-Object System.Windows.Forms.Button; $stopButton.Text = 'Stop tracking, keep local'; $stopButton.Width = 170; $stopButton.Height = 32; $buttonPanel.Controls.Add($stopButton)
    $checkAllButton = New-Object System.Windows.Forms.Button; $checkAllButton.Text = 'Check visible'; $checkAllButton.Width = 110; $checkAllButton.Height = 32; $buttonPanel.Controls.Add($checkAllButton)
    $refreshButton = New-Object System.Windows.Forms.Button; $refreshButton.Text = 'Refresh'; $refreshButton.Width = 90; $refreshButton.Height = 32; $buttonPanel.Controls.Add($refreshButton)

    $populate = {
        $list.BeginUpdate()
        try {
            $list.Items.Clear(); $needle = $filterBox.Text.Trim()
            foreach ($item in @($trackedItems)) {
                if (-not $item) { continue }
                $path = [string]$item.Path
                if (-not [string]::IsNullOrWhiteSpace($needle) -and $path.IndexOf($needle, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
                $row = [pscustomobject]@{ Display = (Get-TrackedFileDialogDisplayText -Item $item); StatusItem = $item; Path = $path }
                [void]$list.Items.Add($row)
            }
            $countLabel.Text = ('{0} shown / {1} tracked' -f $list.Items.Count, @($trackedItems).Count)
        } finally { $list.EndUpdate() }
    }
    $getPicked = {
        $picked = @()
        foreach ($checked in @($list.CheckedItems)) { try { if ($checked.StatusItem) { $picked += $checked.StatusItem } } catch {} }
        if (@($picked).Count -eq 0) { foreach ($selected in @($list.SelectedItems)) { try { if ($selected.StatusItem) { $picked += $selected.StatusItem } } catch {} } }
        return @($picked)
    }
    $filterBox.Add_TextChanged({ & $populate })
    $refreshButton.Add_Click({ try { $trackedItems = @(Get-TrackedFileItemsFromGit); & $populate } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Refresh tracked files failed', 'OK', 'Error') | Out-Null } })
    $checkAllButton.Add_Click({ for ($i = 0; $i -lt $list.Items.Count; $i++) { $list.SetItemChecked($i, $true) } })
    $stopButton.Add_Click({ $picked = @(& $getPicked); if ($picked.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show('Check or select one or more tracked files first.', 'No tracked file selected', 'OK', 'Information') | Out-Null; return }; Invoke-StopTrackingFilesKeepLocal -Items $picked; $trackedItems = @(Get-TrackedFileItemsFromGit); & $populate })
    $removeButton.Add_Click({ $picked = @(& $getPicked); if ($picked.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show('Check or select one or more tracked files first.', 'No tracked file selected', 'OK', 'Information') | Out-Null; return }; Invoke-RemoveFilesFromGitAndDisk -Items $picked; $trackedItems = @(Get-TrackedFileItemsFromGit); & $populate })
    $closeButton.Add_Click({ $dialog.Close() })
    & $populate
    [void]$dialog.ShowDialog($form)
}

function Stage-AllChanges {
    try {
        if (-not (Confirm-ProtectedBranchWorkflowAction -ActionName 'stage all changes here')) { return }
        if (Get-Command Get-GggStageAllCommandPlan -ErrorAction SilentlyContinue) {
            foreach ($plan in @(Get-GggStageAllCommandPlan)) {
                $gitArgs = @('-C', $script:RepoRoot) + @($plan.Arguments)
                [void](Run-External -FileName 'git' -Arguments $gitArgs -Caption $plan.Display)
            }
            Refresh-Status
            return
        }
        [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'add', '-A') -Caption 'git add -A')
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Stage all failed', 'OK', 'Error') | Out-Null
    }
}

function Show-GitStatus {
    try {
        $result = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'status') -Caption 'git status' -AllowFailure

        if ($result.ExitCode -eq 0) {
            $script:DiffTextBox.Text = if ([string]::IsNullOrWhiteSpace($result.StdOut)) {
                '(No status output.)'
            } else {
                $result.StdOut
            }
        }
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'git status failed', 'OK', 'Error') | Out-Null
    }
}

function Show-GitHistoryGraph {
    try {
        if (-not (Test-GitRepository)) {
            Set-SuggestedNextAction -Text 'Open or initialize a repository before loading history.' -Action 'choose-repo'
            return
        }

        $max = [int]$script:Config.MaxHistoryLines
        if ($script:HistoryMaxCountUpDown) { $max = [int]$script:HistoryMaxCountUpDown.Value }
        $plan = $null
        if (Get-Command Get-GghGraphCommandPlan -ErrorAction SilentlyContinue) { $plan = Get-GghGraphCommandPlan -MaxCount $max }
        $args = if ($plan) { @('-C', $script:RepoRoot) + @($plan.Arguments) } else { @('-C', $script:RepoRoot, 'log', '--graph', '--decorate', '--oneline', '--all', '-n', [string]$max) }
        $caption = if ($plan) { [string]$plan.Display } else { "git log --graph --decorate --oneline --all -n $max" }
        $result = Run-External -FileName 'git' -Arguments $args -Caption $caption -AllowFailure -QuietOutput

        $text = if ($result.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($result.StdOut)) { $result.StdOut } else { '(No history output.)' }
        if ($script:HistoryGraphTextBox) { $script:HistoryGraphTextBox.Text = $text }
        if ($script:DiffTextBox) { $script:DiffTextBox.Text = $text }
        if ($script:HistorySummaryLabel) { $script:HistorySummaryLabel.Text = "Read-only graph loaded: $max commits requested." }
        Refresh-HistoryVisualGraph
        Set-CommandPreview -Title 'History / Graph' -Commands (Build-HistoryPreview) -Notes 'Read-only command. It does not modify the repository.'
        Set-SuggestedNextAction -Text 'History graph loaded. Inspect branch tips, tags, and merges before risky operations.'
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'git log failed', 'OK', 'Error') | Out-Null
    }
}

function Refresh-HistoryModelSummary {
    try {
        if (-not (Test-GitRepository)) { return }
        $max = [int]$script:Config.MaxHistoryLines
        if ($script:HistoryMaxCountUpDown) { $max = [int]$script:HistoryMaxCountUpDown.Value }
        if (-not (Get-Command Get-GghHistoryModelCommandPlan -ErrorAction SilentlyContinue)) { return }
        $plan = Get-GghHistoryModelCommandPlan -MaxCount ([Math]::Max($max, 80))
        $result = Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($plan.Arguments)) -Caption $plan.Display -AllowFailure -QuietOutput
        if ($result.ExitCode -ne 0) { return }
        $lines = @($result.StdOut -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        $commits = ConvertFrom-GghCommitLog -Lines $lines
        $summary = Format-GghHistorySummary -Commits $commits
        if ($script:HistorySummaryLabel) { $script:HistorySummaryLabel.Text = $summary }
        Refresh-HistoryVisualGraph
    } catch {
        if ($script:HistorySummaryLabel) { $script:HistorySummaryLabel.Text = 'History model summary unavailable. The graph text can still be used.' }
    }
}

#endregion

#region Branch Operations

function Create-FeatureBranch {
    $name = $script:FeatureBranchTextBox.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($name)) {
        [System.Windows.Forms.MessageBox]::Show('Enter a feature branch name first.', 'Missing branch name', 'OK', 'Warning') | Out-Null
        return
    }

    $validation = if (Get-Command Test-GgbBranchName -ErrorAction SilentlyContinue) { Test-GgbBranchName -Name $name } else { Validate-BranchName $name }
    if (-not $validation.Valid) {
        [System.Windows.Forms.MessageBox]::Show($validation.Error, 'Invalid branch name', 'OK', 'Warning') | Out-Null
        return
    }

    if (Test-BranchExists $name) {
        [System.Windows.Forms.MessageBox]::Show("Branch '$name' already exists.", 'Branch exists', 'OK', 'Warning') | Out-Null
        return
    }

    try {
        $baseFromBase = (($script:BaseFromDevelopCheckBox) -and $script:BaseFromDevelopCheckBox.Checked)
        if ($baseFromBase -and -not (Test-CleanWorkingTree -Operation "switch/pull before creating branch '$name'")) { return }

        if (Get-Command Get-GgbCreateFeatureBranchCommandPlan -ErrorAction SilentlyContinue) {
            foreach ($plan in @(Get-GgbCreateFeatureBranchCommandPlan -Name $name -BaseBranch $script:Config.BaseBranch -BaseFromBaseBranch:$baseFromBase)) {
                $gitArgs = @('-C', $script:RepoRoot) + @($plan.Arguments)
                [void](Run-External -FileName 'git' -Arguments $gitArgs -Caption $plan.Display -ShowProgress)
            }
        } elseif ($baseFromBase) {
            [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'switch', $script:Config.BaseBranch) -Caption "git switch $($script:Config.BaseBranch)" -ShowProgress)
            [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'pull', '--ff-only') -Caption 'git pull --ff-only' -ShowProgress)
            [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'switch', '-c', $name) -Caption ('git switch -c ' + $name))
        } else {
            [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'switch', '-c', $name) -Caption ('git switch -c ' + $name))
        }
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Create branch failed', 'OK', 'Error') | Out-Null
    }
}

function Switch-SelectedBranch {
    $targetBranch = $script:BranchSwitchComboBox.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($targetBranch)) {
        [System.Windows.Forms.MessageBox]::Show('Choose or enter a branch name first.', 'Missing branch', 'OK', 'Warning') | Out-Null
        return
    }

    try {
        if (-not (Test-CleanWorkingTree -Operation "switch to branch '$targetBranch'" -AllowContinue)) { return }

        $msg = "This will run:`r`n`r`n$(Build-SwitchBranchPreview)`r`n`r`nContinue?"
        $answer = [System.Windows.Forms.MessageBox]::Show($msg, 'Confirm branch switch', 'YesNo', 'Question')
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }

        if (Get-Command Get-GgbSwitchBranchCommandPlan -ErrorAction SilentlyContinue) {
            foreach ($plan in @(Get-GgbSwitchBranchCommandPlan -TargetBranch $targetBranch)) {
                $gitArgs = @('-C', $script:RepoRoot) + @($plan.Arguments)
                [void](Run-External -FileName 'git' -Arguments $gitArgs -Caption $plan.Display -ShowProgress)
            }
        } else {
            [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'switch', $targetBranch) -Caption ('git switch ' + $targetBranch) -ShowProgress)
        }
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Branch switch failed', 'OK', 'Error') | Out-Null
    }
}

function Pull-CurrentBranch {
    param([switch]$ConfirmBeforePull)
    try {
        if (-not (Test-CleanWorkingTree -Operation 'pull current branch')) { return }

        if ($ConfirmBeforePull) {
            $msg = "This will run:`r`n`r`n$(Build-PullPreview)`r`n`r`nContinue?"
            $answer = [System.Windows.Forms.MessageBox]::Show($msg, 'Confirm pull current branch', 'YesNo', 'Question')
            if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        }

        if (Get-Command Get-GgbPullCurrentBranchCommandPlan -ErrorAction SilentlyContinue) {
            foreach ($plan in @(Get-GgbPullCurrentBranchCommandPlan)) {
                $gitArgs = @('-C', $script:RepoRoot) + @($plan.Arguments)
                $result = Run-External -FileName 'git' -Arguments $gitArgs -Caption $plan.Display -ShowProgress -AllowFailure
                if ($result.ExitCode -ne 0) { Show-GitFailureGuidance -Result $result -Operation 'pull current branch' -ShowDialog; Refresh-Status; return }
            }
        } else {
            $result = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'pull', '--ff-only') -Caption 'git pull --ff-only' -ShowProgress -AllowFailure
            if ($result.ExitCode -ne 0) { Show-GitFailureGuidance -Result $result -Operation 'pull current branch' -ShowDialog; Refresh-Status; return }
        }
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Pull failed', 'OK', 'Error') | Out-Null
    }
}
#endregion
#region Build Operations

function Run-Build {
    param([switch]$WithWeb)

    try {
        $args = @('/c', 'build-test-run.bat', '--force', '--yes', '--stop-running')
        if (-not $WithWeb) { $args += '--no-web' }

        [void](Run-External -FileName 'cmd.exe' -Arguments $args -WorkingDirectory $script:RepoRoot -Caption ('build-test-run.bat ' + (($args | Select-Object -Skip 2) -join ' ')) -ShowProgress)
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Build failed', 'OK', 'Error') | Out-Null
    }
}

#endregion
