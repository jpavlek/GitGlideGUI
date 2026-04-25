<#
GitConflictRecovery.psm1
UI-free conflict and recovery helpers for Git Glide GUI.

This module classifies failed Git operations and prepares recovery-oriented
command plans. The GUI decides when to show dialogs/panels and when to execute
these plans.
#>

Set-StrictMode -Version 2.0

function ConvertTo-GgrQuotedGitArgument {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) { return '""' }
    if ($Value.Length -eq 0) { return '""' }
    if ($Value -notmatch '[\s"`;&|<>^{}]') { return $Value }

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

function New-GgrGitCommandPlan {
    param(
        [Parameter(Mandatory=$true)][string]$Verb,
        [Parameter(Mandatory=$true)][object[]]$Arguments,
        [string]$Description = '',
        [string]$Display = ''
    )

    $argsArray = @($Arguments | ForEach-Object { [string]$_ })
    if ([string]::IsNullOrWhiteSpace($Display)) {
        $Display = 'git ' + (($argsArray | ForEach-Object { ConvertTo-GgrQuotedGitArgument ([string]$_) }) -join ' ')
    }

    return [pscustomobject]@{
        FileName = 'git'
        Verb = $Verb
        Arguments = @($argsArray)
        Display = $Display
        Description = $Description
    }
}

function ConvertTo-GgrCommandPreview {
    param([object[]]$Plans)
    $plansArray = @($Plans | Where-Object { $_ })
    if (@($plansArray).Count -eq 0) { return 'git status --short' }
    return (($plansArray | ForEach-Object { [string]$_.Display }) -join "`r`n")
}

function Get-GgrConflictStatusCommandPlan {
    return New-GgrGitCommandPlan -Verb 'conflict-status' -Arguments @('status','--short') -Description 'Show conflicted and changed files.'
}

function Get-GgrUnmergedFilesCommandPlan {
    return New-GgrGitCommandPlan -Verb 'unmerged-files' -Arguments @('diff','--name-only','--diff-filter=U') -Description 'List files with unresolved merge conflicts.'
}

function Get-GgrAbortMergeCommandPlan {
    return New-GgrGitCommandPlan -Verb 'merge-abort' -Arguments @('merge','--abort') -Description 'Abort the in-progress merge and return to the pre-merge state when possible.'
}

function Get-GgrAbortCherryPickCommandPlan {
    return New-GgrGitCommandPlan -Verb 'cherry-pick-abort' -Arguments @('cherry-pick','--abort') -Description 'Abort the in-progress cherry-pick.'
}

function Get-GgrContinueCherryPickCommandPlan {
    return New-GgrGitCommandPlan -Verb 'cherry-pick-continue' -Arguments @('cherry-pick','--continue') -Description 'Continue cherry-pick after conflicts are resolved and staged.'
}

function Get-GgrAbortRebaseCommandPlan {
    return New-GgrGitCommandPlan -Verb 'rebase-abort' -Arguments @('rebase','--abort') -Description 'Abort the in-progress rebase.'
}

function Get-GgrRecoveryGuidance {
    param(
        [string]$Operation = 'Git operation',
        [int]$ExitCode = 1,
        [AllowNull()][string]$StdOut = '',
        [AllowNull()][string]$StdErr = ''
    )
    # v3.6.2 hotfix: normalize Git conflict detection across Git versions.
    # Some Git builds return non-zero cherry-pick conflicts without the exact
    # stderr/stdout wording used by the original classifier. We feed a generic
    # conflict marker into the existing classifier instead of replacing its
    # guidance object shape.
    $__gghConflictProbeText = ''
    foreach ($__gghVarName in @('Output', 'ErrorOutput', 'GitOutput', 'GitError', 'StdOut', 'StdErr', 'Message', 'Text', 'RawOutput', 'OutputText', 'ErrorText')) {
        $__gghVar = Get-Variable -Name $__gghVarName -Scope Local -ErrorAction SilentlyContinue
        if ($null -ne $__gghVar -and $null -ne $__gghVar.Value) {
            $__gghConflictProbeText = (@($__gghConflictProbeText, [string]$__gghVar.Value) | Where-Object { $_ }) -join [Environment]::NewLine
        }
    }

    $__gghLooksLikeConflict = (($__gghConflictProbeText -match '(?i)(^|\n)\s*CONFLICT\b|merge conflict|automatic merge failed|could not apply|after resolving the conflicts|fix conflicts and run|cherry-pick failed|patch failed') -or (Test-GghActiveGitConflictState))
    if ($__gghLooksLikeConflict) {
        $__gghConflictMarkerText = ('CONFLICT (content): Merge conflict detected.' + [Environment]::NewLine + 'Automatic merge failed; fix conflicts and then commit the result.')
        foreach ($__gghVarName in @('Output', 'ErrorOutput', 'GitOutput', 'GitError', 'StdOut', 'StdErr', 'Message', 'Text', 'RawOutput', 'OutputText', 'ErrorText')) {
            $__gghVar = Get-Variable -Name $__gghVarName -Scope Local -ErrorAction SilentlyContinue
            if ($null -ne $__gghVar) {
                Set-Variable -Name $__gghVarName -Value ((@([string]$__gghVar.Value, $__gghConflictMarkerText) | Where-Object { $_ }) -join [Environment]::NewLine) -Scope Local
            }
        }
    }

    $output = ((@($StdOut, $StdErr) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }) -join "`n")
    $lower = $output.ToLowerInvariant()
    $steps = @()
    $plans = @((Get-GgrConflictStatusCommandPlan), (Get-GgrUnmergedFilesCommandPlan))
    $kind = 'unknown-failure'
    $severity = 'warning'
    $title = 'Git operation failed'
    $message = "The $Operation command failed. Inspect git status and the command output before retrying."
    $recommendedAction = 'recovery-tab'

    if ($lower -match 'merge conflict|fix conflicts|resolve all conflicts|unmerged paths|both modified|both added|both deleted|conflict \(') {
        $kind = 'conflict'
        $severity = 'conflict'
        $title = 'Conflicts need manual resolution'
        $message = "The $Operation command stopped because Git found conflicts. Resolve the conflicted files, stage the resolved files, then continue or abort."
        $steps = @(
            'Open the conflicted files and decide which lines to keep.',
            'Run or use: git status --short to verify unresolved files.',
            'Stage each resolved file after editing.',
            'Continue the operation if Git offers a continue command, or abort to return to the previous state.'
        )
        if ($Operation -match 'cherry') { $plans += Get-GgrContinueCherryPickCommandPlan; $plans += Get-GgrAbortCherryPickCommandPlan }
        elseif ($Operation -match 'rebase') { $plans += Get-GgrAbortRebaseCommandPlan }
        else { $plans += Get-GgrAbortMergeCommandPlan }
    } elseif ($lower -match 'untracked working tree files would be overwritten|the following untracked working tree files|untracked.*would be overwritten') {
        $kind = 'untracked-would-be-overwritten'
        $severity = 'dirty'
        $title = 'Untracked files would be overwritten'
        $message = "Git blocked $Operation because untracked files would be overwritten. Add, move, delete, or stash them first."
        $steps = @(
            'Review the untracked files carefully.',
            'Add and commit them if they belong to the project.',
            'Move them outside the repository if they are temporary.',
            'Or stash including untracked files before retrying.'
        )
        $recommendedAction = 'stash-dirty-work'
    } elseif ($lower -match 'would be overwritten|local changes.*would be overwritten|please commit your changes or stash them') {
        $kind = 'local-changes-would-be-overwritten'
        $severity = 'dirty'
        $title = 'Local changes would be overwritten'
        $message = "Git blocked $Operation because local changes could be overwritten. Commit or stash the changes first."
        $steps = @(
            'Review the changed files.',
            'Commit the changes if they belong to the current work.',
            'Or stash the changes if you only need to switch/pull/merge temporarily.',
            'Retry the operation after the working tree is clean.'
        )
        $recommendedAction = 'stash-dirty-work'
    } elseif ($lower -match 'not possible to fast-forward|non-fast-forward|fetch first|rejected') {
        $kind = 'remote-history-diverged'
        $severity = 'warning'
        $title = 'Local and remote history diverged'
        $message = "Git could not complete $Operation with a simple fast-forward or push. Inspect history before merging, rebasing, or force-pushing."
        $steps = @(
            'Open History / Graph and compare local and remote branch tips.',
            'Fetch latest remote state.',
            'Decide with the team whether to merge, rebase, or push with force-with-lease.',
            'Avoid destructive history changes unless you understand the shared branch impact.'
        )
        $recommendedAction = 'history-tab'
    } else {
        $steps = @(
            'Run git status --short.',
            'Read the command output in the Output tab.',
            'Avoid running reset --hard or clean unless you deliberately want to discard work.',
            'Use stash or commit before retrying risky operations.'
        )
    }

    if ([string]::IsNullOrWhiteSpace($output)) { $output = '(No Git output captured.)' }

    return [pscustomobject]@{
        Operation = $Operation
        ExitCode = $ExitCode
        Kind = $kind
        Severity = $severity
        Title = $title
        Message = $message
        Details = $output.Trim()
        RecoverySteps = @($steps)
        RecommendedAction = $recommendedAction
        Plans = @($plans)
        Preview = ConvertTo-GgrCommandPreview -Plans $plans
    }
}

function Format-GgrRecoveryGuidance {
    param([Parameter(Mandatory=$true)][object]$Guidance)

    $lines = @()
    $lines += [string]$Guidance.Title
    $lines += ''
    $lines += [string]$Guidance.Message
    $lines += ''
    $lines += 'Recommended steps:'
    foreach ($step in @($Guidance.RecoverySteps)) { $lines += ('- ' + [string]$step) }
    $lines += ''
    $lines += 'Useful commands:'
    foreach ($plan in @($Guidance.Plans)) { $lines += ('- ' + [string]$plan.Display) }
    $lines += ''
    $lines += 'Git output:'
    $lines += [string]$Guidance.Details
    return ($lines -join "`r`n")
}

function ConvertFrom-GgrConflictFileList {
    param([AllowNull()][string]$Text)
    $items = @()
    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
    foreach ($line in @($Text -split "`r?`n")) {
        $value = [string]$line
        if (-not [string]::IsNullOrWhiteSpace($value)) { $items += $value.Trim() }
    }
    return @($items)
}

function Format-GgrConflictFileGuidance {
    param([AllowNull()][string[]]$Files)
    $filesArray = @($Files | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if (@($filesArray).Count -eq 0) { return 'No unresolved conflict files were reported by git diff --name-only --diff-filter=U.' }
    $lines = @('Unresolved conflict files:', '')
    foreach ($file in $filesArray) { $lines += ('- ' + [string]$file) }
    $lines += ''
    $lines += 'Open each file, resolve conflict markers, save, stage the resolved file, then continue or abort the interrupted operation.'
    return ($lines -join "`r`n")
}

function ConvertFrom-GgrConflictState {
    param(
        [AllowNull()][string]$StatusPorcelain = '',
        [AllowNull()][string]$UnmergedText = '',
        [switch]$MergeInProgress,
        [switch]$CherryPickInProgress,
        [switch]$RebaseInProgress
    )

    $unmergedFromDiff = @()
    if (-not [string]::IsNullOrWhiteSpace($UnmergedText)) {
        $unmergedFromDiff = @($UnmergedText -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { ([string]$_).Trim() })
    }

    $unresolved = New-Object System.Collections.Generic.List[string]
    $resolvedCandidates = New-Object System.Collections.Generic.List[string]
    $unmergedCodes = @('DD','AU','UD','UA','DU','AA','UU')

    if (-not [string]::IsNullOrWhiteSpace($StatusPorcelain)) {
        foreach ($line in @($StatusPorcelain -split "`r?`n")) {
            if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -lt 3) { continue }
            $code = $line.Substring(0,2)
            $path = $line.Substring(3).Trim()
            if ($path -match ' -> ') { $path = ($path -split ' -> ')[-1].Trim() }
            if ([string]::IsNullOrWhiteSpace($path)) { continue }
            if ($unmergedCodes -contains $code) {
                if (-not $unresolved.Contains($path)) { [void]$unresolved.Add($path) }
            } elseif ($code[0] -ne ' ' -and $code[0] -ne '?' -and $code[0] -ne '!') {
                if (-not $resolvedCandidates.Contains($path)) { [void]$resolvedCandidates.Add($path) }
            }
        }
    }

    foreach ($path in $unmergedFromDiff) {
        if (-not $unresolved.Contains($path)) { [void]$unresolved.Add($path) }
    }

    $continueKind = ''
    if ($CherryPickInProgress) { $continueKind = 'cherry-pick-continue' }
    elseif ($RebaseInProgress) { $continueKind = 'rebase-continue' }
    elseif ($MergeInProgress) { $continueKind = 'merge-continue' }

    return [pscustomobject]@{
        UnresolvedFiles = @($unresolved)
        ResolvedCandidateFiles = @($resolvedCandidates)
        UnresolvedCount = @($unresolved).Count
        ResolvedCandidateCount = @($resolvedCandidates).Count
        MergeInProgress = [bool]$MergeInProgress
        CherryPickInProgress = [bool]$CherryPickInProgress
        RebaseInProgress = [bool]$RebaseInProgress
        AnyOperationInProgress = [bool]($MergeInProgress -or $CherryPickInProgress -or $RebaseInProgress)
        ContinueCommandKind = $continueKind
        CanContinue = [bool]((@($unresolved).Count -eq 0) -and ($MergeInProgress -or $CherryPickInProgress -or $RebaseInProgress))
    }
}

function Format-GgrConflictState {
    param([Parameter(Mandatory=$true)][object]$State)
    $operation = if ($State.CherryPickInProgress) { 'cherry-pick' } elseif ($State.RebaseInProgress) { 'rebase' } elseif ($State.MergeInProgress) { 'merge' } else { 'none' }
    $status = if ($State.UnresolvedCount -gt 0) { 'unresolved conflicts remain' } elseif ($State.AnyOperationInProgress) { 'no unresolved conflicts detected; continue may be possible' } else { 'no interrupted merge/cherry-pick/rebase detected' }
    return ('Operation: {0}; unresolved files: {1}; staged/resolved candidates: {2}; state: {3}' -f $operation, [int]$State.UnresolvedCount, [int]$State.ResolvedCandidateCount, $status)
}


function Get-GgrConflictMarkerScan {
    param([AllowNull()][string]$Text)

    $lines = @()
    if ($null -ne $Text) { $lines = @([string]$Text -split "`r?`n") }

    $markerLines = New-Object System.Collections.Generic.List[string]
    $hasOpen = $false
    $hasSeparator = $false
    $hasClose = $false
    $lineNumber = 0

    foreach ($line in $lines) {
        $lineNumber++
        $value = [string]$line
        $trimmed = $value.TrimStart()
        $isMarker = $false

        if ($trimmed -match '^<<<<<<<(\s|$)') { $hasOpen = $true; $isMarker = $true }
        elseif ($trimmed -match '^=======(\s*)$') { $hasSeparator = $true; $isMarker = $true }
        elseif ($trimmed -match '^>>>>>>>(\s|$)') { $hasClose = $true; $isMarker = $true }
        elseif ($trimmed -match '^\|\|\|\|\|\|\|(\s|$)') { $isMarker = $true }

        if ($isMarker) { [void]$markerLines.Add(('{0}: {1}' -f $lineNumber, $value.Trim())) }
    }

    $hasMarkers = [bool]($hasOpen -and $hasSeparator -and $hasClose)
    $summary = if ($hasMarkers) {
        ('Conflict markers remain at: {0}' -f ((@($markerLines) | Select-Object -First 8) -join '; '))
    } else {
        'No complete Git conflict marker block detected.'
    }

    return [pscustomobject]@{
        HasMarkers = $hasMarkers
        MarkerCount = @($markerLines).Count
        MarkerLines = @($markerLines)
        HasOpenMarker = $hasOpen
        HasSeparatorMarker = $hasSeparator
        HasCloseMarker = $hasClose
        Summary = $summary
        Readable = $true
        ReadError = ''
    }
}

function Get-GgrConflictMarkerScanForFile {
    param([Parameter(Mandatory=$true)][string]$Path)

    try {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            return [pscustomobject]@{
                HasMarkers = $false
                MarkerCount = 0
                MarkerLines = @()
                HasOpenMarker = $false
                HasSeparatorMarker = $false
                HasCloseMarker = $false
                Summary = 'File not found.'
                Readable = $false
                ReadError = 'File not found.'
                Path = $Path
            }
        }
        $text = [System.IO.File]::ReadAllText($Path)
        $scan = Get-GgrConflictMarkerScan -Text $text
        $scan | Add-Member -NotePropertyName Path -NotePropertyValue $Path -Force
        return $scan
    } catch {
        return [pscustomobject]@{
            HasMarkers = $false
            MarkerCount = 0
            MarkerLines = @()
            HasOpenMarker = $false
            HasSeparatorMarker = $false
            HasCloseMarker = $false
            Summary = 'Could not read file for conflict marker verification.'
            Readable = $false
            ReadError = $_.Exception.Message
            Path = $Path
        }
    }
}

function Format-GgrConflictMarkerScan {
    param([Parameter(Mandatory=$true)][object]$Scan)

    if (-not $Scan.Readable) {
        return ('Conflict marker verification could not read the file. {0}' -f [string]$Scan.ReadError)
    }
    if (-not $Scan.HasMarkers) { return 'No complete Git conflict marker block detected.' }

    $lines = @()
    $lines += 'Conflict markers still appear to be present in the selected file.'
    $lines += ''
    $lines += 'Marker lines:'
    foreach ($line in @($Scan.MarkerLines | Select-Object -First 12)) { $lines += ('- ' + [string]$line) }
    if (@($Scan.MarkerLines).Count -gt 12) { $lines += ('- ... {0} more marker line(s)' -f (@($Scan.MarkerLines).Count - 12)) }
    $lines += ''
    $lines += 'Open the file, remove the conflict markers, save it, then stage it as resolved.'
    return ($lines -join "`r`n")
}

function Get-GgrStageResolvedFileCommandPlan {
    param([Parameter(Mandatory=$true)][string]$Path)
    return New-GgrGitCommandPlan -Verb 'stage-resolved-file' -Arguments @('add','--',$Path) -Description 'Stage a file after conflict markers were resolved.'
}

function Get-GgrContinueMergeCommandPlan {
    return New-GgrGitCommandPlan -Verb 'merge-continue' -Arguments @('commit','--no-edit') -Description 'Complete an in-progress merge after all resolved files are staged.'
}

function Get-GgrContinueRebaseCommandPlan {
    return New-GgrGitCommandPlan -Verb 'rebase-continue' -Arguments @('rebase','--continue') -Description 'Continue an in-progress rebase after conflicts are resolved and staged.'
}

function Get-GgrContinueOperationCommandPlan {
    param([AllowNull()][string]$Kind = '')
    switch ([string]$Kind) {
        'cherry-pick-continue' { return Get-GgrContinueCherryPickCommandPlan }
        'rebase-continue' { return Get-GgrContinueRebaseCommandPlan }
        'merge-continue' { return Get-GgrContinueMergeCommandPlan }
        default { return Get-GgrConflictStatusCommandPlan }
    }
}

function Split-GgrCommandLine {
    param([AllowNull()][string]$CommandLine)
    $tokens = New-Object System.Collections.Generic.List[string]
    if ([string]::IsNullOrWhiteSpace($CommandLine)) { return @() }
    $current = New-Object System.Text.StringBuilder
    $inQuote = $false
    foreach ($ch in $CommandLine.ToCharArray()) {
        if ($ch -eq '"') { $inQuote = -not $inQuote; continue }
        if ([char]::IsWhiteSpace($ch) -and -not $inQuote) {
            if ($current.Length -gt 0) { [void]$tokens.Add($current.ToString()); [void]$current.Clear() }
            continue
        }
        [void]$current.Append($ch)
    }
    if ($current.Length -gt 0) { [void]$tokens.Add($current.ToString()) }
    return @($tokens)
}

function Get-GgrExternalMergeToolCommandPlan {
    param([AllowNull()][string]$ToolCommand = 'git mergetool')
    if ([string]::IsNullOrWhiteSpace($ToolCommand)) { $ToolCommand = 'git mergetool' }
    $tokens = @(Split-GgrCommandLine -CommandLine $ToolCommand)
    if (@($tokens).Count -eq 0) { $tokens = @('git','mergetool') }
    if (([string]$tokens[0]).ToLowerInvariant() -eq 'git') {
        $args = @($tokens | Select-Object -Skip 1)
        if (@($args).Count -eq 0) { $args = @('mergetool') }
        if (([string]$args[0]).ToLowerInvariant() -ne 'mergetool') { throw 'For safety, only git mergetool or a direct executable path is supported as the merge tool command.' }
        return New-GgrGitCommandPlan -Verb 'external-merge-tool' -Arguments $args -Description 'Launch configured git mergetool.'
    }
    $fileName = [string]$tokens[0]
    $args2 = @($tokens | Select-Object -Skip 1)
    return [pscustomobject]@{
        FileName = $fileName
        Verb = 'external-merge-tool'
        Arguments = @($args2)
        Display = (($tokens | ForEach-Object { ConvertTo-GgrQuotedGitArgument ([string]$_) }) -join ' ')
        Description = 'Launch configured external merge tool.'
    }
}

function Test-GghActiveGitConflictState {
    try {
        $gitDir = (& git rev-parse --git-dir 2>$null | Select-Object -First 1)
        if (-not $gitDir) { return $false }

        $gitDir = [string]$gitDir
        if (-not [System.IO.Path]::IsPathRooted($gitDir)) {
            $top = (& git rev-parse --show-toplevel 2>$null | Select-Object -First 1)
            if ($top) {
                $gitDir = Join-Path ([string]$top) $gitDir
            }
        }

        foreach ($marker in @('MERGE_HEAD', 'CHERRY_PICK_HEAD', 'REVERT_HEAD', 'REBASE_HEAD')) {
            if (Test-Path -LiteralPath (Join-Path $gitDir $marker) -PathType Leaf) {
                return $true
            }
        }

        if (Test-Path -LiteralPath (Join-Path $gitDir 'rebase-merge') -PathType Container) { return $true }
        if (Test-Path -LiteralPath (Join-Path $gitDir 'rebase-apply') -PathType Container) { return $true }
    } catch {}

    return $false
}

Export-ModuleMember -Function `
    ConvertTo-GgrQuotedGitArgument, `
    New-GgrGitCommandPlan, `
    ConvertTo-GgrCommandPreview, `
    Get-GgrConflictStatusCommandPlan, `
    Get-GgrUnmergedFilesCommandPlan, `
    Get-GgrAbortMergeCommandPlan, `
    Get-GgrAbortCherryPickCommandPlan, `
    Get-GgrContinueCherryPickCommandPlan, `
    Get-GgrAbortRebaseCommandPlan, `
    Get-GgrRecoveryGuidance, `
    Format-GgrRecoveryGuidance, `
    ConvertFrom-GgrConflictFileList, `
    Format-GgrConflictFileGuidance, `
    ConvertFrom-GgrConflictState, `
    Format-GgrConflictState, `
    Get-GgrConflictMarkerScan, `
    Get-GgrConflictMarkerScanForFile, `
    Format-GgrConflictMarkerScan, `
    Get-GgrStageResolvedFileCommandPlan, `
    Get-GgrContinueMergeCommandPlan, `
    Get-GgrContinueRebaseCommandPlan, `
    Get-GgrContinueOperationCommandPlan, `
    Split-GgrCommandLine, `
    Get-GgrExternalMergeToolCommandPlan
