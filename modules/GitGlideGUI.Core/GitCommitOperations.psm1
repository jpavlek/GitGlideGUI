<#
GitCommitOperations.psm1
UI-free commit workflow helpers for Git Glide GUI.

The module builds command plans, validates commit messages, and prepares a
minimal history model that can later feed the visual graph. The GUI remains
responsible for collecting user input, confirmations, temporary message-file
creation, and command execution.
#>

Set-StrictMode -Version 2.0

function ConvertTo-GgcQuotedGitArgument {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) { return '""' }
    if ($Value.Length -eq 0) { return '""' }
    if ($Value -notmatch '[\s"`;&|<>^]') { return $Value }

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

function New-GgcGitCommandPlan {
    param(
        [Parameter(Mandatory=$true)][string]$Verb,
        [Parameter(Mandatory=$true)][object[]]$Arguments,
        [string]$Description = '',
        [string]$Display = ''
    )

    $argsArray = @($Arguments | ForEach-Object { [string]$_ })
    if ([string]::IsNullOrWhiteSpace($Display)) {
        $Display = 'git ' + (($argsArray | ForEach-Object { ConvertTo-GgcQuotedGitArgument ([string]$_) }) -join ' ')
    }

    return [pscustomobject]@{
        FileName = 'git'
        Verb = $Verb
        Arguments = @($argsArray)
        Display = $Display
        Description = $Description
    }
}

function ConvertTo-GgcCommandPreview {
    param([object[]]$Plans)
    $plansArray = @($Plans | Where-Object { $_ })
    if (@($plansArray).Count -eq 0) { return 'git commit <options>' }
    return (($plansArray | ForEach-Object { [string]$_.Display }) -join "`r`n")
}

function New-GgcCommitMessageText {
    param(
        [AllowNull()][string]$Subject,
        [AllowNull()][string]$Body = ''
    )

    $subjectText = if ($null -eq $Subject) { '' } else { $Subject.Trim() }
    if ([string]::IsNullOrWhiteSpace($subjectText)) { return '<missing-subject>' }

    $bodyText = if ($null -eq $Body) { '' } else { $Body.TrimEnd() }
    if ([string]::IsNullOrWhiteSpace($bodyText)) { return $subjectText }
    return $subjectText + "`r`n`r`n" + $bodyText
}

function Test-GgcCommitMessage {
    param(
        [AllowNull()][string]$Subject,
        [int]$MaxSubjectLength = 72,
        [switch]$ConventionalCommits
    )

    $subjectText = if ($null -eq $Subject) { '' } else { $Subject.Trim() }
    if ([string]::IsNullOrWhiteSpace($subjectText)) {
        return [pscustomobject]@{ Valid = $false; Error = 'Commit subject cannot be empty.'; Warning = ''; Guidance = 'Write a short sentence explaining why this change exists.' }
    }

    $warning = ''
    $guidance = ''
    if ($subjectText.Length -gt $MaxSubjectLength) {
        $warning = "Subject is long ($($subjectText.Length) chars, recommended max: $MaxSubjectLength)."
    }

    if ($subjectText -match '\.$') {
        $guidance = 'Commit subjects usually omit the final period.'
    }

    if ($ConventionalCommits) {
        $pattern = '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([A-Za-z0-9_.\/-]+\))?!?: .+'
        if ($subjectText -notmatch $pattern) {
            $conv = 'Conventional Commits example: feat(parser): handle quoted paths'
            if ([string]::IsNullOrWhiteSpace($warning)) { $warning = 'Subject does not match the optional Conventional Commits style.' }
            if ([string]::IsNullOrWhiteSpace($guidance)) { $guidance = $conv } else { $guidance += ' ' + $conv }
        }
    }

    return [pscustomobject]@{ Valid = $true; Error = ''; Warning = $warning; Guidance = $guidance }
}

function Get-GgcCommitCommandPlan {
    param(
        [AllowNull()][string]$Subject,
        [AllowNull()][string]$Body = '',
        [switch]$StageAll,
        [switch]$Amend,
        [switch]$PushAfter,
        [switch]$UseForceWithLease,
        [string]$DefaultRemoteName = 'origin',
        [int]$MaxSubjectLength = 72,
        [switch]$ConventionalCommits
    )

    $plans = @()
    if ($StageAll) {
        $plans += New-GgcGitCommandPlan -Verb 'stage-all' -Arguments @('add','-A') -Description 'Stage all tracked and untracked changes before committing.'
    }

    $commitArgs = @('commit')
    if ($Amend) { $commitArgs += '--amend' }
    $commitArgs += '-F'
    $commitArgs += '<temp-commit-message-file>'
    $commitDisplay = 'git ' + (($commitArgs | ForEach-Object { if ($_ -eq '<temp-commit-message-file>') { $_ } else { ConvertTo-GgcQuotedGitArgument ([string]$_) } }) -join ' ')
    $plans += New-GgcGitCommandPlan -Verb 'commit' -Arguments $commitArgs -Display $commitDisplay -Description 'Create a commit using a temporary message file.'

    if ($PushAfter) {
        if ($Amend -and $UseForceWithLease) {
            $plans += New-GgcGitCommandPlan -Verb 'push-after-amend' -Arguments @('push','--force-with-lease') -Description 'Push amended history using force-with-lease.'
        } else {
            $plans += New-GgcGitCommandPlan -Verb 'push-after-commit' -Arguments @('push','-u',$DefaultRemoteName,'HEAD') -Description 'Push the current branch and set upstream tracking.'
        }
    }

    $messageText = New-GgcCommitMessageText -Subject $Subject -Body $Body
    $validation = Test-GgcCommitMessage -Subject $Subject -MaxSubjectLength $MaxSubjectLength -ConventionalCommits:$ConventionalCommits

    return [pscustomobject]@{
        Subject = if ($null -eq $Subject) { '' } else { $Subject.Trim() }
        Body = if ($null -eq $Body) { '' } else { $Body }
        Amend = [bool]$Amend
        StageAll = [bool]$StageAll
        PushAfter = [bool]$PushAfter
        MessageText = $messageText
        Plans = @($plans)
        Commands = @($plans | ForEach-Object { [string]$_.Display })
        Validation = $validation
        ConventionalCommits = [bool]$ConventionalCommits
    }
}

function Get-GgcInitialCommitCommandPlan {
    param(
        [string]$Subject = 'Initial commit',
        [switch]$PushAfter,
        [string]$DefaultRemoteName = 'origin'
    )

    return Get-GgcCommitCommandPlan -Subject $Subject -Body '' -StageAll -PushAfter:$PushAfter -DefaultRemoteName $DefaultRemoteName
}

function Get-GgcSoftUndoLastCommitCommandPlan {
    return @(
        (New-GgcGitCommandPlan -Verb 'show-last-commit' -Arguments @('log','-1','--oneline') -Description 'Show the commit that would be undone.')
        (New-GgcGitCommandPlan -Verb 'soft-undo-last-commit' -Arguments @('reset','--soft','HEAD~1') -Description 'Undo the last commit while keeping changes staged.')
    )
}

function Get-GgcCommitPreviewText {
    param([Parameter(Mandatory=$true)][object]$CommitPlan)

    $commands = if ($CommitPlan.Commands) { @($CommitPlan.Commands) -join "`r`n" } else { ConvertTo-GgcCommandPreview -Plans $CommitPlan.Plans }
    $text = $commands + "`r`n`r`nCommit message file content:`r`n--------------------------------`r`n" + [string]$CommitPlan.MessageText
    try {
        if ($CommitPlan.Validation) {
            if (-not [string]::IsNullOrWhiteSpace([string]$CommitPlan.Validation.Warning)) { $text += "`r`nWarning: $($CommitPlan.Validation.Warning)" }
            if (-not [string]::IsNullOrWhiteSpace([string]$CommitPlan.Validation.Guidance)) { $text += "`r`nGuidance: $($CommitPlan.Validation.Guidance)" }
        }
    } catch {}
    return $text
}

function Get-GgcCommitHistoryCommandPlan {
    param([int]$MaxCount = 80)
    return New-GgcGitCommandPlan -Verb 'history-model' -Arguments @('log',('--max-count=' + $MaxCount),'--date=iso-strict','--format=%H%x1f%P%x1f%an%x1f%ae%x1f%ad%x1f%s','--all') -Display ('git log --max-count=' + $MaxCount + ' --date=iso-strict --format=<graph-model-fields> --all') -Description 'Read a compact commit/history model for the future visual graph.'
}

function ConvertFrom-GgcCommitLogLine {
    param([AllowNull()][string]$Line)

    if ([string]::IsNullOrWhiteSpace($Line)) { return $null }
    $parts = @($Line -split [char]0x1f, 6)
    if (@($parts).Count -lt 6) { return $null }
    $parents = @()
    if (-not [string]::IsNullOrWhiteSpace($parts[1])) { $parents = @($parts[1] -split ' ' | Where-Object { $_ }) }
    return [pscustomobject]@{
        Hash = $parts[0]
        Parents = @($parents)
        AuthorName = $parts[2]
        AuthorEmail = $parts[3]
        AuthorDate = $parts[4]
        Subject = $parts[5]
    }
}

Export-ModuleMember -Function `
    ConvertTo-GgcQuotedGitArgument, `
    New-GgcGitCommandPlan, `
    ConvertTo-GgcCommandPreview, `
    New-GgcCommitMessageText, `
    Test-GgcCommitMessage, `
    Get-GgcCommitCommandPlan, `
    Get-GgcInitialCommitCommandPlan, `
    Get-GgcSoftUndoLastCommitCommandPlan, `
    Get-GgcCommitPreviewText, `
    Get-GgcCommitHistoryCommandPlan, `
    ConvertFrom-GgcCommitLogLine
