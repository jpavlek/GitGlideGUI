# This file is part of Git Glide GUI stable split-script architecture.
# It is dot-sourced by GitGlideGUI.ps1.

#region Recovery and Cherry-pick Operations

function Set-RecoveryGuidancePanel {
    param(
        [AllowNull()][object]$Guidance,
        [string]$FallbackText = ''
    )

    try {
        $text = $FallbackText
        if ($Guidance) {
            if (Get-Command Format-GgrRecoveryGuidance -ErrorAction SilentlyContinue) {
                $text = Format-GgrRecoveryGuidance -Guidance $Guidance
            } else {
                $steps = (@($Guidance.RecoverySteps) | ForEach-Object { '- ' + [string]$_ }) -join "`r`n"
                $text = [string]$Guidance.Title + "`r`n`r`n" + [string]$Guidance.Message + "`r`n`r`n" + $steps + "`r`n`r`nGit output:`r`n" + [string]$Guidance.Details
            }
            $script:LastRecoveryGuidance = $Guidance
        }
        if ([string]::IsNullOrWhiteSpace($text)) { $text = 'No recovery guidance is available yet. Run Refresh recovery status after a failed merge, pull, stash, or cherry-pick operation.' }
        if ($script:RecoveryTextBox) { $script:RecoveryTextBox.Text = $text }
        if ($script:RecoverySummaryLabel -and $Guidance) { $script:RecoverySummaryLabel.Text = ([string]$Guidance.Title + ' [' + [string]$Guidance.Kind + ']') }
        elseif ($script:RecoverySummaryLabel) { $script:RecoverySummaryLabel.Text = 'No active recovery guidance.' }
    } catch {
        Append-Log -Text ('Failed to update recovery panel: ' + $_.Exception.Message) -Color ([System.Drawing.Color]::Firebrick)
    }
}

function Show-GitFailureGuidance {
    param(
        [object]$Result,
        [string]$Operation = 'Git operation',
        [switch]$ShowDialog
    )

    try {
        $stdout = if ($Result -and $Result.StdOut) { [string]$Result.StdOut } else { '' }
        $stderr = if ($Result -and $Result.StdErr) { [string]$Result.StdErr } else { '' }
        $exitCode = if ($Result) { try { [int]$Result.ExitCode } catch { 1 } } else { 1 }
        if (Get-Command Get-GgrRecoveryGuidance -ErrorAction SilentlyContinue) {
            $guidance = Get-GgrRecoveryGuidance -Operation $Operation -ExitCode $exitCode -StdOut $stdout -StdErr $stderr
        } else {
            $guidance = [pscustomobject]@{
                Operation = $Operation
                ExitCode = $exitCode
                Kind = 'unknown-failure'
                Severity = 'warning'
                Title = 'Git operation failed'
                Message = "The $Operation command failed. Run git status and inspect the output."
                Details = (($stdout + "`n" + $stderr).Trim())
                RecoverySteps = @('Run git status --short.', 'Resolve conflicts or protect local changes.', 'Retry only when the working tree state is clear.')
                RecommendedAction = 'recovery-tab'
                Plans = @()
                Preview = 'git status --short'
            }
        }
        Set-RecoveryGuidancePanel -Guidance $guidance
        Set-CommandPreview -Title ('Recovery after failed ' + $Operation) -Commands ([string]$guidance.Preview) -Notes ([string]$guidance.Message)
        Set-SuggestedNextAction -Text ([string]$guidance.Message) -Action ([string]$guidance.RecommendedAction)
        Append-Log -Text ('Recovery guidance: ' + [string]$guidance.Message) -Color ([System.Drawing.Color]::DarkOrange)
        foreach ($step in @($guidance.RecoverySteps)) { Append-Log -Text ('  - ' + [string]$step) -Color ([System.Drawing.Color]::DarkOrange) }
        if ($ShowDialog) {
            [System.Windows.Forms.MessageBox]::Show(([string]$guidance.Message + "`r`n`r`n" + ((@($guidance.RecoverySteps) | ForEach-Object { '- ' + [string]$_ }) -join "`r`n")), 'Recovery guidance', 'OK', 'Warning') | Out-Null
        }
    } catch {
        Append-Log -Text ('Failed to build recovery guidance: ' + $_.Exception.Message) -Color ([System.Drawing.Color]::Firebrick)
    }
}

function Refresh-ConflictFiles {
    try {
        if (-not (Test-GitRepository)) { return }
        $plan = if (Get-Command Get-GgrUnmergedFilesCommandPlan -ErrorAction SilentlyContinue) { Get-GgrUnmergedFilesCommandPlan } else { [pscustomobject]@{ Arguments=@('diff','--name-only','--diff-filter=U'); Display='git diff --name-only --diff-filter=U' } }
        $result = Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($plan.Arguments)) -Caption ([string]$plan.Display) -AllowFailure -QuietOutput
        $files = if (Get-Command ConvertFrom-GgrConflictFileList -ErrorAction SilentlyContinue) { ConvertFrom-GgrConflictFileList -Text ([string]$result.StdOut) } else { @(([string]$result.StdOut) -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) }
        if ($script:ConflictFilesListBox) {
            $script:ConflictFilesListBox.Items.Clear()
            foreach ($file in @($files)) { [void]$script:ConflictFilesListBox.Items.Add([string]$file) }
        }
        if (@($files).Count -gt 0) {
            $msg = if (Get-Command Format-GgrConflictFileGuidance -ErrorAction SilentlyContinue) { Format-GgrConflictFileGuidance -Files $files } else { 'Unresolved conflict files found.' }
            Set-RecoveryGuidancePanel -FallbackText $msg
        }
        Update-RecoveryStatePanel -State (Get-RecoveryStateSnapshot)
    } catch {
        Append-Log -Text ('Failed to refresh conflict files: ' + $_.Exception.Message) -Color ([System.Drawing.Color]::Firebrick)
    }
}

function Get-SelectedConflictFilePath {
    if (-not $script:ConflictFilesListBox -or $script:ConflictFilesListBox.SelectedItem -eq $null) { return '' }
    $relative = [string]$script:ConflictFilesListBox.SelectedItem
    if ([string]::IsNullOrWhiteSpace($relative)) { return '' }
    return (Join-Path $script:RepoRoot $relative)
}

# v3.9.0: Conflict Resolution Assistant
# This adapter layer reuses the existing conflict recovery UI while routing
# selected-file checks and command previews through GitConflictAssistant helpers.

function Get-ConflictAssistantSelectedRelativePath {
    if (-not $script:ConflictFilesListBox -or $script:ConflictFilesListBox.SelectedItem -eq $null) {
        return ''
    }

    return [string]$script:ConflictFilesListBox.SelectedItem
}

function Get-ConflictAssistantSelectedFullPath {
    $relative = Get-ConflictAssistantSelectedRelativePath
    if ([string]::IsNullOrWhiteSpace($relative)) { return '' }

    if (Get-Command Get-SelectedConflictFilePath -ErrorAction SilentlyContinue) {
        return Get-SelectedConflictFilePath
    }

    return Join-Path $script:RepoRoot $relative
}

function Refresh-ConflictAssistant {
    try {
        if (Get-Command Refresh-ConflictFiles -ErrorAction SilentlyContinue) {
            Refresh-ConflictFiles
        }

        $notes = 'Conflict Resolution Assistant refreshed. Select a conflicted file, scan it, resolve markers, then stage only when markers are gone.'

        if (Get-Command Get-GgcaUnmergedFilesCommandPlan -ErrorAction SilentlyContinue) {
            $plan = Get-GgcaUnmergedFilesCommandPlan
            Set-CommandPreview -Title 'Conflict Resolution Assistant' -Commands ([string]$plan.CommandLine) -Notes $notes
        } else {
            Set-CommandPreview -Title 'Conflict Resolution Assistant' -Commands 'git diff --name-only --diff-filter=U' -Notes $notes
        }

        if ($script:RecoveryTextBox) {
            $script:RecoveryTextBox.Text = @(
                'Conflict Resolution Assistant'
                ''
                '1. List conflicted files.'
                '2. Select one conflicted file.'
                '3. Scan the selected file for conflict markers.'
                '4. Resolve the file manually.'
                '5. Stage only after markers are gone.'
                '6. Continue or abort the active operation intentionally.'
            ) -join [Environment]::NewLine
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Conflict assistant refresh failed', 'OK', 'Error') | Out-Null
    }
}

function Show-ConflictAssistantSelectedFileScan {
    try {
        $relative = Get-ConflictAssistantSelectedRelativePath
        $path = Get-ConflictAssistantSelectedFullPath

        if ([string]::IsNullOrWhiteSpace($path)) {
            [System.Windows.Forms.MessageBox]::Show('Select a conflicted file first.', 'No conflicted file selected', 'OK', 'Information') | Out-Null
            return
        }

        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            [System.Windows.Forms.MessageBox]::Show("The selected conflict file was not found:`r`n$path", 'File not found', 'OK', 'Warning') | Out-Null
            return
        }

        if (Get-Command Get-GgcaConflictMarkerScanForFile -ErrorAction SilentlyContinue) {
            $scan = Get-GgcaConflictMarkerScanForFile -Path $path
            $summary = if (Get-Command Format-GgcaConflictMarkerSummary -ErrorAction SilentlyContinue) {
                Format-GgcaConflictMarkerSummary -Scan $scan
            } else {
                "Conflict markers found: $($scan.BlockCount)"
            }

            if ($script:RecoveryTextBox) { $script:RecoveryTextBox.Text = $summary }

            $notes = if ($scan.HasMarkers) {
                'Conflict markers remain. Resolve all marker blocks before staging.'
            } else {
                'No conflict markers found. Review the resolved content before staging.'
            }

            Set-CommandPreview -Title 'Conflict assistant selected-file scan' -Commands ('git add -- ' + (Quote-Arg $relative)) -Notes $notes
            return
        }

        if (Get-Command Get-GgrConflictMarkerScanForFile -ErrorAction SilentlyContinue) {
            $scan = Get-GgrConflictMarkerScanForFile -Path $path
            $summary = if (Get-Command Format-GgrConflictMarkerScan -ErrorAction SilentlyContinue) {
                Format-GgrConflictMarkerScan -Scan $scan
            } else {
                [string]$scan.Summary
            }

            if ($script:RecoveryTextBox) { $script:RecoveryTextBox.Text = $summary }
            Set-CommandPreview -Title 'Conflict assistant selected-file scan' -Commands ('git add -- ' + (Quote-Arg $relative)) -Notes 'Legacy conflict marker scan used.'
            return
        }

        [System.Windows.Forms.MessageBox]::Show('No conflict marker scanner is available.', 'Scanner unavailable', 'OK', 'Warning') | Out-Null
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Conflict assistant scan failed', 'OK', 'Error') | Out-Null
    }
}

function Invoke-ConflictAssistantUseOurs {
    try {
        $relative = Get-ConflictAssistantSelectedRelativePath
        if ([string]::IsNullOrWhiteSpace($relative)) {
            [System.Windows.Forms.MessageBox]::Show('Select a conflicted file first.', 'No conflicted file selected', 'OK', 'Information') | Out-Null
            return
        }

        $plan = if (Get-Command Get-GgcaCheckoutOursCommandPlan -ErrorAction SilentlyContinue) {
            Get-GgcaCheckoutOursCommandPlan -Path $relative
        } else {
            [pscustomobject]@{
                CommandLine = 'git checkout --ours -- ' + (Quote-Arg $relative)
                Arguments = @('checkout', '--ours', '--', $relative)
                Description = 'Use current branch side for the selected file.'
            }
        }

        $ok = Confirm-GuiAction -Title 'Use ours for selected file' -Message ("This will choose the current branch side for:`r`n`r`n$relative`r`n`r`nCommand:`r`n$($plan.CommandLine)`r`n`r`nReview the file before staging.") -Icon ([System.Windows.Forms.MessageBoxIcon]::Warning)
        if (-not $ok) { return }

        $result = Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($plan.Arguments)) -Caption ([string]$plan.CommandLine) -AllowFailure
        if ($result.ExitCode -ne 0) { Show-GitFailureGuidance -Result $result -Operation 'use ours for conflict file' -ShowDialog; return }

        Show-ConflictAssistantSelectedFileScan
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Use ours failed', 'OK', 'Error') | Out-Null
    }
}

function Invoke-ConflictAssistantUseTheirs {
    try {
        $relative = Get-ConflictAssistantSelectedRelativePath
        if ([string]::IsNullOrWhiteSpace($relative)) {
            [System.Windows.Forms.MessageBox]::Show('Select a conflicted file first.', 'No conflicted file selected', 'OK', 'Information') | Out-Null
            return
        }

        $plan = if (Get-Command Get-GgcaCheckoutTheirsCommandPlan -ErrorAction SilentlyContinue) {
            Get-GgcaCheckoutTheirsCommandPlan -Path $relative
        } else {
            [pscustomobject]@{
                CommandLine = 'git checkout --theirs -- ' + (Quote-Arg $relative)
                Arguments = @('checkout', '--theirs', '--', $relative)
                Description = 'Use incoming branch side for the selected file.'
            }
        }

        $ok = Confirm-GuiAction -Title 'Use theirs for selected file' -Message ("This will choose the incoming branch side for:`r`n`r`n$relative`r`n`r`nCommand:`r`n$($plan.CommandLine)`r`n`r`nReview the file before staging.") -Icon ([System.Windows.Forms.MessageBoxIcon]::Warning)
        if (-not $ok) { return }

        $result = Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($plan.Arguments)) -Caption ([string]$plan.CommandLine) -AllowFailure
        if ($result.ExitCode -ne 0) { Show-GitFailureGuidance -Result $result -Operation 'use theirs for conflict file' -ShowDialog; return }

        Show-ConflictAssistantSelectedFileScan
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Use theirs failed', 'OK', 'Error') | Out-Null
    }
}

function Invoke-ConflictAssistantStageResolved {
    try {
        $relative = Get-ConflictAssistantSelectedRelativePath
        $path = Get-ConflictAssistantSelectedFullPath

        if ([string]::IsNullOrWhiteSpace($relative) -or [string]::IsNullOrWhiteSpace($path)) {
            [System.Windows.Forms.MessageBox]::Show('Select a conflicted file first.', 'No conflicted file selected', 'OK', 'Information') | Out-Null
            return
        }

        if (Get-Command Get-GgcaConflictMarkerScanForFile -ErrorAction SilentlyContinue) {
            $scan = Get-GgcaConflictMarkerScanForFile -Path $path
            $decision = Test-GgcaStageResolvedFileAllowed -Scan $scan

            if (-not $decision.Allowed) {
                $summary = if (Get-Command Format-GgcaConflictMarkerSummary -ErrorAction SilentlyContinue) {
                    Format-GgcaConflictMarkerSummary -Scan $scan
                } else {
                    [string]$decision.Reason
                }

                if ($script:RecoveryTextBox) { $script:RecoveryTextBox.Text = $summary }
                [System.Windows.Forms.MessageBox]::Show([string]$decision.Reason, 'Conflict markers still present', 'OK', 'Warning') | Out-Null
                Set-CommandPreview -Title 'Stage resolved blocked' -Commands ('git add -- ' + (Quote-Arg $relative)) -Notes ([string]$decision.Reason)
                return
            }
        }

        if (Get-Command Stage-SelectedConflictFileAsResolved -ErrorAction SilentlyContinue) {
            Stage-SelectedConflictFileAsResolved
            return
        }

        $plan = if (Get-Command Get-GgcaStageResolvedFileCommandPlan -ErrorAction SilentlyContinue) {
            Get-GgcaStageResolvedFileCommandPlan -Path $relative
        } else {
            [pscustomobject]@{
                CommandLine = 'git add -- ' + (Quote-Arg $relative)
                Arguments = @('add', '--', $relative)
            }
        }

        $ok = Confirm-GuiAction -Title 'Stage resolved file' -Message ("Stage this resolved file?`r`n`r`n$relative`r`n`r`nCommand:`r`n$($plan.CommandLine)") -Icon ([System.Windows.Forms.MessageBoxIcon]::Question)
        if (-not $ok) { return }

        $result = Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($plan.Arguments)) -Caption ([string]$plan.CommandLine) -AllowFailure
        if ($result.ExitCode -ne 0) { Show-GitFailureGuidance -Result $result -Operation 'stage resolved conflict file' -ShowDialog; return }

        Refresh-Status
        Refresh-ConflictAssistant
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Stage resolved failed', 'OK', 'Error') | Out-Null
    }
}

function Open-SelectedConflictFile {
    try {
        $path = Get-SelectedConflictFilePath
        if ([string]::IsNullOrWhiteSpace($path)) { [System.Windows.Forms.MessageBox]::Show('Select a conflicted file first.', 'No conflicted file selected', 'OK', 'Information') | Out-Null; return }
        if (-not (Test-Path -LiteralPath $path)) { [System.Windows.Forms.MessageBox]::Show("The selected file was not found:`r`n$path", 'File not found', 'OK', 'Warning') | Out-Null; return }
        Start-Process -FilePath $path | Out-Null
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Open conflicted file failed', 'OK', 'Error') | Out-Null }
}

function Open-SelectedConflictFolder {
    try {
        $path = Get-SelectedConflictFilePath
        if ([string]::IsNullOrWhiteSpace($path)) { [System.Windows.Forms.MessageBox]::Show('Select a conflicted file first.', 'No conflicted file selected', 'OK', 'Information') | Out-Null; return }
        $folder = Split-Path -Parent $path
        if (-not (Test-Path -LiteralPath $folder)) { $folder = $script:RepoRoot }
        Start-Process -FilePath explorer.exe -ArgumentList @($folder) | Out-Null
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Open conflict folder failed', 'OK', 'Error') | Out-Null }
}

function Get-GitPathForMarker {
    param([string]$Marker)
    try {
        if (-not (Test-GitRepository)) { return '' }
        $value = & git -C $script:RepoRoot rev-parse --git-path $Marker 2>$null | Select-Object -First 1
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace([string]$value)) { return [string]$value }
    } catch {}
    return ''
}

function Test-GitMarkerPath {
    param([string]$Marker)
    $path = Get-GitPathForMarker -Marker $Marker
    if ([string]::IsNullOrWhiteSpace($path)) { return $false }
    try { return (Test-Path -LiteralPath $path) } catch { return $false }
}

function Get-RecoveryOperationMarkers {
    $merge = Test-GitMarkerPath -Marker 'MERGE_HEAD'
    $cherry = Test-GitMarkerPath -Marker 'CHERRY_PICK_HEAD'
    $rebase = (Test-GitMarkerPath -Marker 'REBASE_HEAD') -or (Test-GitMarkerPath -Marker 'rebase-merge') -or (Test-GitMarkerPath -Marker 'rebase-apply')
    return [pscustomobject]@{
        MergeInProgress = [bool]$merge
        CherryPickInProgress = [bool]$cherry
        RebaseInProgress = [bool]$rebase
        AnyOperationInProgress = [bool]($merge -or $cherry -or $rebase)
    }
}

function Get-RecoveryStateSnapshot {
    try {
        if (-not (Test-GitRepository)) { return $null }
        $statusResult = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'status', '--porcelain=v1') -Caption 'git status --porcelain=v1' -AllowFailure -QuietOutput
        $unmergedResult = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'diff', '--name-only', '--diff-filter=U') -Caption 'git diff --name-only --diff-filter=U' -AllowFailure -QuietOutput
        $markers = Get-RecoveryOperationMarkers
        if (Get-Command ConvertFrom-GgrConflictState -ErrorAction SilentlyContinue) {
            return ConvertFrom-GgrConflictState -StatusPorcelain ([string]$statusResult.StdOut) -UnmergedText ([string]$unmergedResult.StdOut) -MergeInProgress:([bool]$markers.MergeInProgress) -CherryPickInProgress:([bool]$markers.CherryPickInProgress) -RebaseInProgress:([bool]$markers.RebaseInProgress)
        }
        $unresolved = @(([string]$unmergedResult.StdOut) -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        return [pscustomobject]@{ UnresolvedFiles=@($unresolved); ResolvedCandidateFiles=@(); UnresolvedCount=@($unresolved).Count; ResolvedCandidateCount=0; MergeInProgress=$markers.MergeInProgress; CherryPickInProgress=$markers.CherryPickInProgress; RebaseInProgress=$markers.RebaseInProgress; AnyOperationInProgress=$markers.AnyOperationInProgress; ContinueCommandKind='' }
    } catch {
        Append-Log -Text ('Failed to read recovery state: ' + $_.Exception.Message) -Color ([System.Drawing.Color]::Firebrick)
        return $null
    }
}


function Get-GgrConflictMarkerScanForFile {
    param([Parameter(Mandatory=$true)][string]$Path)

    $markers = @()
    try {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            return [pscustomobject]@{
                Path = $Path
                Readable = $false
                HasMarkers = $false
                MarkerCount = 0
                Markers = @()
                ReadError = 'File was not found.'
                Summary = 'Conflict marker scan failed: file was not found.'
            }
        }

        $lineNumber = 0
        foreach ($line in [System.IO.File]::ReadLines($Path)) {
            $lineNumber++
            if ($line -match '^(<<<<<<< .+|=======$|>>>>>>> .+)') {
                $markers += [pscustomobject]@{
                    Path = $Path
                    Line = $lineNumber
                    Marker = $Matches[1]
                    Text = $line.Trim()
                }
            }
        }

        return [pscustomobject]@{
            Path = $Path
            Readable = $true
            HasMarkers = (@($markers).Count -gt 0)
            MarkerCount = @($markers).Count
            Markers = @($markers)
            ReadError = ''
            Summary = if (@($markers).Count -gt 0) { "Conflict markers found: $(@($markers).Count)" } else { 'No conflict markers found.' }
        }
    } catch {
        return [pscustomobject]@{
            Path = $Path
            Readable = $false
            HasMarkers = $false
            MarkerCount = 0
            Markers = @()
            ReadError = $_.Exception.Message
            Summary = 'Conflict marker scan failed: ' + $_.Exception.Message
        }
    }
}

function Format-GgrConflictMarkerScan {
    param([AllowNull()][object]$Scan)

    if (-not $Scan) { return 'No conflict marker scan result is available.' }
    if (-not $Scan.Readable) { return "Could not read file:`r`n$($Scan.Path)`r`n`r`n$($Scan.ReadError)" }
    if (-not $Scan.HasMarkers) { return "No conflict markers were found in:`r`n$($Scan.Path)" }

    $lines = @(
        "Conflict markers still exist in:"
        [string]$Scan.Path
        ''
        "Marker count: $($Scan.MarkerCount)"
        ''
        'First markers:'
    )

    foreach ($marker in @($Scan.Markers | Select-Object -First 12)) {
        $lines += ('Line {0}: {1}' -f [int]$marker.Line, [string]$marker.Text)
    }

    if ([int]$Scan.MarkerCount -gt 12) { $lines += ('... plus {0} more marker(s).' -f ([int]$Scan.MarkerCount - 12)) }
    $lines += ''
    $lines += 'Remove all <<<<<<<, =======, and >>>>>>> blocks, save the file, then stage it as resolved.'
    return ($lines -join "`r`n")
}

function Get-RepositoryChangedPathsForScan {
    try {
        if (-not (Test-GitRepository)) { return @() }
        $status = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'status', '--porcelain=v1') -Caption 'git status --porcelain=v1' -AllowFailure -QuietOutput
        $paths = @()
        foreach ($line in @(([string]$status.StdOut) -split "`r?`n")) {
            if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -lt 4) { continue }
            $path = $line.Substring(3).Trim()
            if ($path -match '\s+->\s+') { $path = ($path -split '\s+->\s+')[-1].Trim() }
            $path = $path.Trim('"')
            if (-not [string]::IsNullOrWhiteSpace($path)) { $paths += $path }
        }
        return @($paths | Select-Object -Unique)
    } catch { return @() }
}

function Get-RepositoryConflictMarkers {
    param([AllowNull()][string[]]$RelativePaths)

    $markers = @()
    $paths = @($RelativePaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    if ($paths.Count -eq 0) { $paths = @(Get-RepositoryChangedPathsForScan) }
    foreach ($relative in @($paths | Select-Object -First 250)) {
        try {
            $fullPath = Join-Path $script:RepoRoot $relative
            $scan = Get-GgrConflictMarkerScanForFile -Path $fullPath
            if ($scan.Readable -and $scan.HasMarkers) {
                foreach ($marker in @($scan.Markers)) {
                    $markers += [pscustomobject]@{
                        File = $relative
                        Line = [int]$marker.Line
                        Marker = [string]$marker.Marker
                        Text = [string]$marker.Text
                    }
                }
            }
        } catch {}
    }
    return @($markers)
}

function Get-RepositoryStateDoctorSnapshot {
    try {
        if (-not (Test-GitRepository)) {
            return [pscustomobject]@{
                Severity = 'warning'
                State = 'No repository selected'
                Problem = 'Git Glide does not currently have a valid Git repository context.'
                Next = 'Open or initialize a repository.'
                Preview = 'git status'
                SuggestedAction = 'choose-repo'
                Branch = ''
                Upstream = ''
                Ahead = 0
                Behind = 0
                Changed = 0
                Untracked = 0
                Unmerged = 0
                ConflictMarkers = @()
                UntrackedGitItem = $false
                RawStatus = ''
            }
        }

        $branchResult = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'branch', '--show-current') -Caption 'git branch --show-current' -AllowFailure -QuietOutput
        $branch = ([string]$branchResult.StdOut).Trim()
        $headResult = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'rev-parse', '--short', 'HEAD') -Caption 'git rev-parse --short HEAD' -AllowFailure -QuietOutput
        $headShort = ([string]$headResult.StdOut).Trim()
        $detached = [string]::IsNullOrWhiteSpace($branch)
        if ($detached) { $branch = "(detached HEAD at $headShort)" }

        $upstreamResult = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}') -Caption 'git rev-parse --abbrev-ref --symbolic-full-name @{u}' -AllowFailure -QuietOutput
        $upstream = ([string]$upstreamResult.StdOut).Trim()
        if ([string]::IsNullOrWhiteSpace($upstream)) { $upstream = '(no upstream)' }

        $statusShort = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'status', '-sb') -Caption 'git status -sb' -AllowFailure -QuietOutput
        $rawStatus = ([string]$statusShort.StdOut).Trim()
        $branchLine = (@($rawStatus -split "`r?`n") | Select-Object -First 1)
        $ahead = 0
        $behind = 0
        if ($branchLine -match '\[([^\]]+)\]') {
            $tracking = [string]$Matches[1]
            if ($tracking -match 'ahead\s+(\d+)') { $ahead = [int]$Matches[1] }
            if ($tracking -match 'behind\s+(\d+)') { $behind = [int]$Matches[1] }
        }

        $porcelain = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'status', '--porcelain=v1') -Caption 'git status --porcelain=v1' -AllowFailure -QuietOutput
        $statusLines = @(([string]$porcelain.StdOut) -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        $changed = @($statusLines).Count
        $untracked = @($statusLines | Where-Object { $_ -like '?? *' }).Count

        $unmergedResult = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'diff', '--name-only', '--diff-filter=U') -Caption 'git diff --name-only --diff-filter=U' -AllowFailure -QuietOutput
        $unmergedFiles = @(([string]$unmergedResult.StdOut) -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        $markers = Get-RecoveryOperationMarkers
        $scanPaths = @($unmergedFiles)
        if ($scanPaths.Count -eq 0) { $scanPaths = @(Get-RepositoryChangedPathsForScan) }
        $conflictMarkers = @(Get-RepositoryConflictMarkers -RelativePaths $scanPaths)

        $untrackedGitItem = Test-Path -LiteralPath (Join-Path $script:RepoRoot 'git')
        $severity = 'safe'
        $state = 'Clean or normal working state'
        $problem = 'No blocking recovery condition was detected.'
        $next = 'Continue normal Git Flow work.'
        $preview = 'git status -sb'
        $suggestedAction = 'status'

        if ($markers.AnyOperationInProgress -and @($unmergedFiles).Count -gt 0) {
            $severity = 'danger'
            $state = 'Operation in progress with unresolved conflicts'
            $problem = "A merge, rebase, or cherry-pick is in progress and $(@($unmergedFiles).Count) file(s) still have unresolved Git conflicts."
            $next = 'Resolve the files, remove conflict markers, stage resolved files, then continue or abort the operation.'
            $preview = "git status -sb`r`ngit diff --name-only --diff-filter=U"
            $suggestedAction = 'recovery-tab'
        } elseif (@($conflictMarkers).Count -gt 0) {
            $severity = 'danger'
            $state = 'Conflict markers detected'
            $problem = "Git conflict markers remain in changed files even if Git may not list every file as unmerged."
            $next = 'Open the marker scan, remove all conflict blocks, save, validate, and stage only after markers are gone.'
            $preview = "git status -sb`r`nfindstr /n /c:`"<<<<<<<`" /c:`"=======`" /c:`">>>>>>>`" <file>"
            $suggestedAction = 'marker-scan'
        } elseif ($markers.AnyOperationInProgress) {
            $severity = 'warning'
            $state = 'Operation in progress'
            $problem = 'A merge, rebase, or cherry-pick marker exists, but no unresolved files were detected.'
            $next = 'Review status, stage any resolved files, then continue or abort deliberately.'
            $preview = 'git status -sb'
            $suggestedAction = 'recovery-tab'
        } elseif ($detached) {
            $severity = 'warning'
            $state = 'Detached HEAD'
            $problem = 'HEAD points to a commit instead of a branch. New commits can become hard to find unless you create or switch to a branch.'
            $next = 'Create a rescue branch if you need to keep this state, or switch to the intended branch.'
            $preview = ('git branch rescue/v3-7-detached-{0} HEAD' -f $headShort)
            $suggestedAction = 'history-tab'
        } elseif ($ahead -gt 0 -and $behind -gt 0) {
            $severity = 'warning'
            $state = 'Branch diverged from upstream'
            $problem = "Local branch has $ahead unique commit(s), and upstream has $behind unique commit(s)."
            $next = 'Fetch, inspect the graph, then merge or rebase intentionally. Do not force-push unless you fully understand the impact.'
            $preview = "git fetch origin`r`ngit log --oneline --graph --decorate --all -20"
            $suggestedAction = 'history-tab'
        } elseif ($behind -gt 0) {
            $severity = 'warning'
            $state = 'Branch behind upstream'
            $problem = "Upstream has $behind commit(s) not present locally."
            $next = 'Pull with fast-forward if your working tree is clean.'
            $preview = 'git pull --ff-only'
            $suggestedAction = 'pull-current'
        } elseif ($ahead -gt 0) {
            $severity = 'safe'
            $state = 'Branch ahead of upstream'
            $problem = "Local branch has $ahead commit(s) not pushed yet."
            $next = 'Push when ready.'
            $preview = 'git push'
            $suggestedAction = 'push-current'
        } elseif ($untrackedGitItem) {
            $severity = 'warning'
            $state = 'Suspicious untracked item named git'
            $problem = "An untracked item named 'git' exists in the repository root. This is often an accidental file created while copying commands."
            $next = "Inspect it. Delete it only if it is accidental."
            $preview = "dir git`r`ntype git"
            $suggestedAction = 'status'
        } elseif ($changed -gt 0) {
            $severity = 'neutral'
            $state = 'Working tree has changes'
            $problem = "$changed changed item(s) are present."
            $next = 'Review diffs, stage intentionally, then commit on the correct branch.'
            $preview = 'git status -sb'
            $suggestedAction = 'stage-tab'
        }

        return [pscustomobject]@{
            Severity = $severity
            State = $state
            Problem = $problem
            Next = $next
            Preview = $preview
            SuggestedAction = $suggestedAction
            Branch = $branch
            Upstream = $upstream
            Ahead = $ahead
            Behind = $behind
            Changed = $changed
            Untracked = $untracked
            Unmerged = @($unmergedFiles).Count
            ConflictMarkers = @($conflictMarkers)
            UntrackedGitItem = [bool]$untrackedGitItem
            RawStatus = $rawStatus
        }
    } catch {
        return [pscustomobject]@{
            Severity = 'warning'
            State = 'State doctor failed'
            Problem = $_.Exception.Message
            Next = 'Run git status manually and inspect Output.'
            Preview = 'git status -sb'
            SuggestedAction = 'status'
            Branch = ''
            Upstream = ''
            Ahead = 0
            Behind = 0
            Changed = 0
            Untracked = 0
            Unmerged = 0
            ConflictMarkers = @()
            UntrackedGitItem = $false
            RawStatus = ''
        }
    }
}

function Format-RepositoryStateDoctorSnapshot {
    param([AllowNull()][object]$Snapshot)

    if (-not $Snapshot) { return 'Repository State Doctor has no snapshot yet. Click State doctor or Refresh recovery status.' }

    $lines = @(
        "Repository state: $($Snapshot.State)"
        "Severity: $($Snapshot.Severity)"
        ''
        "Problem: $($Snapshot.Problem)"
        "Next safe action: $($Snapshot.Next)"
        ''
        "Branch: $($Snapshot.Branch)"
        "Upstream: $($Snapshot.Upstream)"
        "Ahead / behind: $($Snapshot.Ahead) / $($Snapshot.Behind)"
        "Changed / untracked / unmerged: $($Snapshot.Changed) / $($Snapshot.Untracked) / $($Snapshot.Unmerged)"
        "Conflict marker lines: $(@($Snapshot.ConflictMarkers).Count)"
    )

    if ($Snapshot.UntrackedGitItem) { $lines += "Warning: untracked root item named 'git' exists." }

    $lines += ''
    $lines += 'Suggested command preview:'
    $lines += [string]$Snapshot.Preview

    if (-not [string]::IsNullOrWhiteSpace([string]$Snapshot.RawStatus)) {
        $lines += ''
        $lines += 'git status -sb:'
        $lines += [string]$Snapshot.RawStatus
    }

    if (@($Snapshot.ConflictMarkers).Count -gt 0) {
        $lines += ''
        $lines += 'First conflict markers:'
        foreach ($marker in @($Snapshot.ConflictMarkers | Select-Object -First 12)) {
            $lines += ('{0}:{1}: {2}' -f [string]$marker.File, [int]$marker.Line, [string]$marker.Text)
        }
    }

    return ($lines -join "`r`n")
}

function Update-RepositoryStateDoctorPanel {
    param([AllowNull()][object]$Snapshot)

    if (-not $Snapshot) { $Snapshot = Get-RepositoryStateDoctorSnapshot }
    $text = Format-RepositoryStateDoctorSnapshot -Snapshot $Snapshot

    if ($script:RepositoryStateDoctorTextBox) { $script:RepositoryStateDoctorTextBox.Text = $text }
    if ($script:RepositoryStateDoctorSummaryLabel) { $script:RepositoryStateDoctorSummaryLabel.Text = ('Repository State Doctor: ' + [string]$Snapshot.State) }

    try {
        $back = [System.Drawing.Color]::AliceBlue
        $fore = [System.Drawing.Color]::MidnightBlue
        if ($Snapshot.Severity -eq 'danger') { $back = [System.Drawing.Color]::MistyRose; $fore = [System.Drawing.Color]::DarkRed }
        elseif ($Snapshot.Severity -eq 'warning') { $back = [System.Drawing.Color]::LemonChiffon; $fore = [System.Drawing.Color]::SaddleBrown }
        elseif ($Snapshot.Severity -eq 'safe') { $back = [System.Drawing.Color]::Honeydew; $fore = [System.Drawing.Color]::DarkGreen }
        if ($script:RepositoryStateDoctorTextBox) { $script:RepositoryStateDoctorTextBox.BackColor = $back; $script:RepositoryStateDoctorTextBox.ForeColor = $fore }
        if ($script:RepositoryStateDoctorSummaryLabel) { $script:RepositoryStateDoctorSummaryLabel.ForeColor = $fore }
    } catch {}

    return $Snapshot
}

function Show-RepositoryStateDoctor {
    try {
        $snapshot = Update-RepositoryStateDoctorPanel
        if ($snapshot) {
            Set-CommandPreview -Title 'Repository State Doctor' -Commands ([string]$snapshot.Preview) -Notes ([string]$snapshot.Next)
            Set-SuggestedNextAction -Text ([string]$snapshot.Next) -Action ([string]$snapshot.SuggestedAction)
        }
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'State doctor failed', 'OK', 'Error') | Out-Null }
}

function Show-ConflictMarkerScan {
    try {
        if (-not (Test-GitRepository)) { [void](Ensure-RepositorySelected); return }
        $snapshot = Get-RepositoryStateDoctorSnapshot
        $markers = @($snapshot.ConflictMarkers)
        if ($markers.Count -eq 0) {
            if ($script:RecoveryTextBox) { $script:RecoveryTextBox.Text = 'No conflict markers were found in changed/unmerged files.' }
            Set-CommandPreview -Title 'Conflict marker scan' -Commands "git status -sb" -Notes 'No conflict marker lines were detected in changed/unmerged files.'
            return
        }

        $lines = @('Conflict marker scan:', '')
        foreach ($marker in @($markers | Select-Object -First 100)) {
            $lines += ('{0}:{1}: {2}' -f [string]$marker.File, [int]$marker.Line, [string]$marker.Text)
        }
        if ($markers.Count -gt 100) { $lines += ('... plus {0} more marker line(s).' -f ($markers.Count - 100)) }
        $lines += ''
        $lines += 'Remove all conflict blocks, save the files, then stage resolved files.'
        if ($script:RecoveryTextBox) { $script:RecoveryTextBox.Text = ($lines -join "`r`n") }
        Set-CommandPreview -Title 'Conflict marker scan' -Commands "git status -sb`r`ngit diff --name-only --diff-filter=U" -Notes "$($markers.Count) conflict marker line(s) found."
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Conflict marker scan failed', 'OK', 'Error') | Out-Null }
}


function Get-GitGlideGuiScriptValidationPaths {
    $scriptDirectory = $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($scriptDirectory) -and -not [string]::IsNullOrWhiteSpace($script:RepoRoot)) {
        $scriptDirectory = Join-Path $script:RepoRoot 'scripts\windows'
    }

    $names = @(
        'GitGlideGUI.ps1',
        'GitGlideGUI.part01-bootstrap-config.ps1',
        'GitGlideGUI.part02-state-selection.ps1',
        'GitGlideGUI.part03-previews-basic-ops.ps1',
        'GitGlideGUI.part04-recovery-push-stash-tags.ps1',
        'GitGlideGUI.part05-ui.ps1',
        'GitGlideGUI.part06-run.ps1'
    )

    foreach ($name in $names) {
        $path = Join-Path $scriptDirectory $name
        if (Test-Path -LiteralPath $path -PathType Leaf) { $path }
    }
}

function Test-GuiScriptSyntax {
    try {
        $paths = @(Get-GitGlideGuiScriptValidationPaths)
        if ($paths.Count -eq 0) { throw 'No Git Glide GUI script files were found to validate.' }

        foreach ($path in $paths) {
            [scriptblock]::Create((Get-Content -Raw -LiteralPath $path)) > $null
        }

        $message = ("PowerShell parse OK for Git Glide GUI v{0} split script set:`r`n" -f $script:GitGlideGuiVersion) + ($paths -join "`r`n")
        if ($script:RecoveryTextBox) { $script:RecoveryTextBox.Text = $message }
        Set-CommandPreview -Title 'Validate GUI script' -Commands 'powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\smoke-launch.ps1' -Notes ('Validated {0} split script file(s).' -f $paths.Count)
        Append-Log -Text 'PowerShell parse OK for Git Glide GUI split script set.' -Color ([System.Drawing.Color]::DarkGreen)
    } catch {
        $message = "PowerShell parse failed:`r`n$($_.Exception.Message)"
        if ($script:RecoveryTextBox) { $script:RecoveryTextBox.Text = $message }
        Set-CommandPreview -Title 'Validate GUI script failed' -Commands 'Fix the reported parser error, then validate again.' -Notes $_.Exception.Message
        Append-Log -Text $message -Color ([System.Drawing.Color]::Firebrick)
        [System.Windows.Forms.MessageBox]::Show($message, 'GUI script validation failed', 'OK', 'Error') | Out-Null
    }
}

function Update-RecoveryStatePanel {
    param([AllowNull()][object]$State)
    try {
        if (-not $State) { $State = Get-RecoveryStateSnapshot }
        if (-not $State) { return }
        if ($script:ConflictStateLabel) {
            if (Get-Command Format-GgrConflictState -ErrorAction SilentlyContinue) { $script:ConflictStateLabel.Text = Format-GgrConflictState -State $State }
            else { $script:ConflictStateLabel.Text = ('Unresolved: {0}; staged/resolved candidates: {1}' -f [int]$State.UnresolvedCount, [int]$State.ResolvedCandidateCount) }
        }
        if ($script:RecoverySummaryLabel -and $State.AnyOperationInProgress) {
            $kind = if ($State.CherryPickInProgress) { 'cherry-pick' } elseif ($State.RebaseInProgress) { 'rebase' } elseif ($State.MergeInProgress) { 'merge' } else { 'recovery' }
            if ($State.UnresolvedCount -gt 0) { $script:RecoverySummaryLabel.Text = "In-progress ${kind}: resolve $($State.UnresolvedCount) unresolved file(s), stage them, then continue or abort." }
            else { $script:RecoverySummaryLabel.Text = "In-progress ${kind}: no unresolved files detected. Stage any resolved files, then continue or abort." }
        }
        if ($script:ContinueOperationButton) { $script:ContinueOperationButton.Enabled = [bool]$State.AnyOperationInProgress }
    } catch {}
}

function Stage-SelectedConflictFileAsResolved {
    try {
        if (-not (Test-GitRepository)) { [void](Ensure-RepositorySelected); return }
        $path = Get-SelectedConflictFilePath
        if ([string]::IsNullOrWhiteSpace($path)) { [System.Windows.Forms.MessageBox]::Show('Select a conflicted file first.', 'No conflicted file selected', 'OK', 'Information') | Out-Null; return }
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { [System.Windows.Forms.MessageBox]::Show("The selected conflict file was not found:`r`n$path", 'File not found', 'OK', 'Warning') | Out-Null; return }
        $relative = [string]$script:ConflictFilesListBox.SelectedItem

        if (Get-Command Get-GgrConflictMarkerScanForFile -ErrorAction SilentlyContinue) {
            $scan = Get-GgrConflictMarkerScanForFile -Path $path
            if ($scan.HasMarkers) {
                $message = if (Get-Command Format-GgrConflictMarkerScan -ErrorAction SilentlyContinue) { Format-GgrConflictMarkerScan -Scan $scan } else { [string]$scan.Summary }
                [System.Windows.Forms.MessageBox]::Show($message, 'Conflict markers still present', 'OK', 'Warning') | Out-Null
                Set-CommandPreview -Title 'Conflict markers still present' -Commands ('git add -- ' + (Quote-Arg $relative)) -Notes 'Git Glide blocked staging this file as resolved because conflict markers remain. Open the file, remove the markers, save, then stage again.'
                return
            }
            if (-not $scan.Readable) {
                $okRead = Confirm-GuiAction -Title 'Could not verify conflict markers' -Message ("Git Glide could not read this file to verify whether conflict markers remain:`r`n`r`n$path`r`n`r`nReason: $($scan.ReadError)`r`n`r`nStage anyway?") -Icon ([System.Windows.Forms.MessageBoxIcon]::Warning)
                if (-not $okRead) { return }
            }
        }

        $ok = Confirm-GuiAction -Title 'Stage resolved file' -Message ("Git Glide did not detect a complete conflict-marker block in:`r`n`r`n$relative`r`n`r`nThis will run:`r`n`r`ngit add -- $relative") -Icon ([System.Windows.Forms.MessageBoxIcon]::Question)
        if (-not $ok) { return }
        $plan = if (Get-Command Get-GgrStageResolvedFileCommandPlan -ErrorAction SilentlyContinue) { Get-GgrStageResolvedFileCommandPlan -Path $relative } else { [pscustomobject]@{ Arguments=@('add','--',$relative); Display=('git add -- ' + (Quote-Arg $relative)) } }
        $result = Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($plan.Arguments)) -Caption ([string]$plan.Display) -AllowFailure -ShowProgress
        if ($result.ExitCode -ne 0) { Show-GitFailureGuidance -Result $result -Operation 'stage resolved conflict file' -ShowDialog; return }
        Refresh-Status
        Refresh-RecoveryStatus
        Set-CommandPreview -Title 'Stage resolved file' -Commands ([string]$plan.Display) -Notes 'The file is staged. If all conflicts are resolved, use Continue operation.'
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Stage resolved file failed', 'OK', 'Error') | Out-Null }
}

function Invoke-ContinueCurrentRecoveryOperation {
    try {
        if (-not (Test-GitRepository)) { [void](Ensure-RepositorySelected); return }
        $state = Get-RecoveryStateSnapshot
        if (-not $state -or -not $state.AnyOperationInProgress) { [System.Windows.Forms.MessageBox]::Show('No merge, cherry-pick, or rebase operation appears to be in progress.', 'Nothing to continue', 'OK', 'Information') | Out-Null; return }
        if ($state.UnresolvedCount -gt 0) { [System.Windows.Forms.MessageBox]::Show("There are still $($state.UnresolvedCount) unresolved conflict file(s). Resolve and stage them before continuing.", 'Unresolved conflicts remain', 'OK', 'Warning') | Out-Null; return }
        $kind = if ($state.CherryPickInProgress) { 'cherry-pick-continue' } elseif ($state.RebaseInProgress) { 'rebase-continue' } elseif ($state.MergeInProgress) { 'merge-continue' } else { 'status' }
        Invoke-RecoveryCommandPlan -Kind $kind
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Continue operation failed', 'OK', 'Error') | Out-Null }
}

function Save-ExternalMergeToolCommand {
    try {
        $value = if ($script:ExternalMergeToolTextBox) { $script:ExternalMergeToolTextBox.Text.Trim() } else { '' }
        if ([string]::IsNullOrWhiteSpace($value)) { $value = 'git mergetool' }
        Set-ConfigValue -Name 'ExternalMergeToolCommand' -Value $value
        Save-Config -Config $script:Config
        Append-Log -Text ('External merge tool command saved: ' + $value) -Color ([System.Drawing.Color]::DarkGreen)
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Save merge tool failed', 'OK', 'Error') | Out-Null }
}

function Build-ExternalMergeToolPreview {
    $value = if ($script:ExternalMergeToolTextBox) { $script:ExternalMergeToolTextBox.Text.Trim() } else { [string]$script:Config.ExternalMergeToolCommand }
    if ([string]::IsNullOrWhiteSpace($value)) { $value = 'git mergetool' }
    if (Get-Command Get-GgrExternalMergeToolCommandPlan -ErrorAction SilentlyContinue) {
        try { return (Get-GgrExternalMergeToolCommandPlan -ToolCommand $value).Display } catch {}
    }
    return $value
}

function Launch-ExternalMergeTool {
    try {
        if (-not (Test-GitRepository)) { [void](Ensure-RepositorySelected); return }
        Save-ExternalMergeToolCommand
        $command = [string]$script:Config.ExternalMergeToolCommand
        if ([string]::IsNullOrWhiteSpace($command)) { $command = 'git mergetool' }
        $ok = Confirm-GuiAction -Title 'Launch merge tool' -Message ("Launch the configured merge tool?`r`n`r`n$command`r`n`r`nThis may open an external application. Use it to resolve conflicted files, then return here to stage and continue.") -Icon ([System.Windows.Forms.MessageBoxIcon]::Question)
        if (-not $ok) { return }
        $plan = if (Get-Command Get-GgrExternalMergeToolCommandPlan -ErrorAction SilentlyContinue) { Get-GgrExternalMergeToolCommandPlan -ToolCommand $command } else { [pscustomobject]@{ FileName='git'; Arguments=@('mergetool'); Display='git mergetool' } }
        if ([string]$plan.FileName -eq 'git') {
            $result = Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($plan.Arguments)) -Caption ([string]$plan.Display) -AllowFailure -ShowProgress
            if ($result.ExitCode -ne 0) { Show-GitFailureGuidance -Result $result -Operation 'external merge tool' -ShowDialog }
            else { Refresh-RecoveryStatus }
        } else {
            Start-Process -FilePath ([string]$plan.FileName) -ArgumentList @($plan.Arguments) -WorkingDirectory $script:RepoRoot | Out-Null
        }
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Launch merge tool failed', 'OK', 'Error') | Out-Null }
}

function Refresh-RecoveryStatus {
    try {
        if (-not (Test-GitRepository)) { [void](Ensure-RepositorySelected); return }
        $result = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'status', '--short') -Caption 'git status --short' -AllowFailure -QuietOutput
        $stdout = if ($result.StdOut) { [string]$result.StdOut } else { '' }
        $stderr = if ($result.StdErr) { [string]$result.StdErr } else { '' }
        $guidance = if (Get-Command Get-GgrRecoveryGuidance -ErrorAction SilentlyContinue) { Get-GgrRecoveryGuidance -Operation 'status/recovery inspection' -ExitCode $result.ExitCode -StdOut $stdout -StdErr $stderr } else { $null }
        if ($guidance -and -not [string]::IsNullOrWhiteSpace($stdout)) {
            Set-RecoveryGuidancePanel -Guidance $guidance
        } else {
            Set-RecoveryGuidancePanel -FallbackText ("Current git status --short:`r`n" + $(if ([string]::IsNullOrWhiteSpace($stdout)) { '(working tree appears clean or no short status output)' } else { $stdout }))
        }
        Update-RepositoryStateDoctorPanel | Out-Null
        Refresh-ConflictFiles
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Recovery status failed', 'OK', 'Error') | Out-Null
    }
}

function Invoke-RecoveryCommandPlan {
    param(
        [string]$Kind = 'status'
    )

    try {
        if (-not (Test-GitRepository)) { [void](Ensure-RepositorySelected); return }
        $plan = $null
        switch ($Kind) {
            'merge-abort' { if (Get-Command Get-GgrAbortMergeCommandPlan -ErrorAction SilentlyContinue) { $plan = Get-GgrAbortMergeCommandPlan } else { $plan = [pscustomobject]@{ Arguments=@('merge','--abort'); Display='git merge --abort' } } }
            'cherry-pick-abort' { if (Get-Command Get-GgcpCherryPickAbortCommandPlan -ErrorAction SilentlyContinue) { $plan = Get-GgcpCherryPickAbortCommandPlan } elseif (Get-Command Get-GgrAbortCherryPickCommandPlan -ErrorAction SilentlyContinue) { $plan = Get-GgrAbortCherryPickCommandPlan } else { $plan = [pscustomobject]@{ Arguments=@('cherry-pick','--abort'); Display='git cherry-pick --abort' } } }
            'cherry-pick-continue' { if (Get-Command Get-GgcpCherryPickContinueCommandPlan -ErrorAction SilentlyContinue) { $plan = Get-GgcpCherryPickContinueCommandPlan } elseif (Get-Command Get-GgrContinueCherryPickCommandPlan -ErrorAction SilentlyContinue) { $plan = Get-GgrContinueCherryPickCommandPlan } else { $plan = [pscustomobject]@{ Arguments=@('cherry-pick','--continue'); Display='git cherry-pick --continue' } } }
            'merge-continue' { if (Get-Command Get-GgrContinueMergeCommandPlan -ErrorAction SilentlyContinue) { $plan = Get-GgrContinueMergeCommandPlan } else { $plan = [pscustomobject]@{ Arguments=@('commit','--no-edit'); Display='git commit --no-edit' } } }
            'rebase-continue' { if (Get-Command Get-GgrContinueRebaseCommandPlan -ErrorAction SilentlyContinue) { $plan = Get-GgrContinueRebaseCommandPlan } else { $plan = [pscustomobject]@{ Arguments=@('rebase','--continue'); Display='git rebase --continue' } } }
            default { if (Get-Command Get-GgrConflictStatusCommandPlan -ErrorAction SilentlyContinue) { $plan = Get-GgrConflictStatusCommandPlan } else { $plan = [pscustomobject]@{ Arguments=@('status','--short'); Display='git status --short' } } }
        }
        if ($Kind -match 'abort') {
            $ok = Confirm-GuiAction -Title 'Confirm recovery command' -Message ("Run recovery command?`r`n`r`n" + [string]$plan.Display + "`r`n`r`nAbort commands usually return the repository to the state before the interrupted operation, but review the Output tab afterwards.") -Icon ([System.Windows.Forms.MessageBoxIcon]::Warning)
            if (-not $ok) { return }
        }
        $result = Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($plan.Arguments)) -Caption ([string]$plan.Display) -AllowFailure -ShowProgress
        if ($result.ExitCode -ne 0) { Show-GitFailureGuidance -Result $result -Operation ([string]$plan.Display) -ShowDialog }
        else { Refresh-Status; Refresh-RecoveryStatus }
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Recovery command failed', 'OK', 'Error') | Out-Null
    }
}

function Get-SelectedHistoryCommitish {
    if ($script:CherryPickCommitTextBox -and -not [string]::IsNullOrWhiteSpace($script:CherryPickCommitTextBox.Text)) { return $script:CherryPickCommitTextBox.Text.Trim() }
    if ($script:HistoryVisualListView -and $script:HistoryVisualListView.SelectedItems.Count -gt 0) {
        $tag = [string]$script:HistoryVisualListView.SelectedItems[0].Tag
        if (-not [string]::IsNullOrWhiteSpace($tag)) { return $tag }
    }
    if ($script:HistoryGraphTextBox -and -not [string]::IsNullOrWhiteSpace($script:HistoryGraphTextBox.SelectedText)) {
        $selected = $script:HistoryGraphTextBox.SelectedText.Trim()
        if (Get-Command Get-GgcpSelectedCommitFromHistoryLine -ErrorAction SilentlyContinue) {
            $hash = Get-GgcpSelectedCommitFromHistoryLine -Line $selected
            if (-not [string]::IsNullOrWhiteSpace($hash)) { return $hash }
        }
    }
    $line = Get-CurrentHistoryLine
    if (-not [string]::IsNullOrWhiteSpace($line)) {
        if (Get-Command Get-GgcpSelectedCommitFromHistoryLine -ErrorAction SilentlyContinue) {
            $hash = Get-GgcpSelectedCommitFromHistoryLine -Line $line
            if (-not [string]::IsNullOrWhiteSpace($hash)) { return $hash }
        }
    }
    return ''
}
function Get-CurrentHistoryLine {
    if (-not $script:HistoryGraphTextBox) { return '' }
    $idx = $script:HistoryGraphTextBox.SelectionStart
    try {
        $lineIndex = $script:HistoryGraphTextBox.GetLineFromCharIndex($idx)
        if ($lineIndex -ge 0 -and $lineIndex -lt @($script:HistoryGraphTextBox.Lines).Count) { return [string]$script:HistoryGraphTextBox.Lines[$lineIndex] }
    } catch {}
    return ''
}

function Set-CherryPickCommitFromHistorySelection {
    try {
        $commitish = Get-SelectedHistoryCommitish
        if ([string]::IsNullOrWhiteSpace($commitish)) { [System.Windows.Forms.MessageBox]::Show('Select or click a commit line in History / Graph first.', 'No commit selected', 'OK', 'Information') | Out-Null; return }
        if ($script:CherryPickCommitTextBox) { $script:CherryPickCommitTextBox.Text = $commitish }
        if ($script:ActionsTabs -and $script:RecoveryTabPage) { $script:ActionsTabs.SelectedTab = $script:RecoveryTabPage }
        Set-CommandPreview -Title 'Cherry-pick selected history commit' -Commands (Build-CherryPickPreview) -Notes 'Review the target branch and working tree before running cherry-pick.'
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'History selection failed', 'OK', 'Error') | Out-Null }
}

function Update-HistorySelectionPreview {
    try {
        $commitish = Get-SelectedHistoryCommitish
        if ([string]::IsNullOrWhiteSpace($commitish)) {
            Set-CommandPreview -Title 'History / Graph selection' -Commands (Build-HistoryPreview) -Notes 'Select a commit row to preview cherry-pick and show commands that can use the selected commit.'
            return
        }
        $noCommitSuffix = if ($script:CherryPickNoCommitCheckBox -and $script:CherryPickNoCommitCheckBox.Checked) { ' --no-commit' } else { '' }
        $commands = @(
            ('git show --stat ' + (Quote-Arg $commitish)),
            ('git cherry-pick' + $noCommitSuffix + ' ' + (Quote-Arg $commitish))
        ) -join "`r`n"
        Set-CommandPreview -Title ('Selected history commit: ' + $commitish) -Commands $commands -Notes 'Use Show/stat to inspect the commit. Use cherry-pick only when you deliberately want to copy this change onto the current branch.'
    } catch {}
}

function Show-SelectedHistoryCommitDetails {
    try {
        if (-not (Test-GitRepository)) { [void](Ensure-RepositorySelected); return }
        $commitish = Get-SelectedHistoryCommitish
        if ([string]::IsNullOrWhiteSpace($commitish)) { [System.Windows.Forms.MessageBox]::Show('Select a commit in History / Graph first.', 'No commit selected', 'OK', 'Information') | Out-Null; return }
        $result = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'show', '--stat', '--decorate', '--no-renames', $commitish) -Caption ('git show --stat --decorate ' + (Quote-Arg $commitish)) -AllowFailure -QuietOutput
        $text = if ($result.StdOut) { [string]$result.StdOut } else { [string]$result.StdErr }
        if ($script:HistoryGraphTextBox) { $script:HistoryGraphTextBox.Text = $text }
        if ($script:DiffTextBox) { Set-DiffPreviewText -Text $text }
        Set-CommandPreview -Title ('Show selected commit: ' + $commitish) -Commands ('git show --stat --decorate ' + (Quote-Arg $commitish)) -Notes 'Read-only inspection command.'
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Show selected commit failed', 'OK', 'Error') | Out-Null }
}

function Build-CherryPickPreview {
    $commitish = Get-SelectedHistoryCommitish
    if ([string]::IsNullOrWhiteSpace($commitish)) { $commitish = '<commit-hash-or-ref>' }
    try {
        $plan = Get-GgcpCherryPickCommandPlan -Commitish $commitish -NoCommit:($script:CherryPickNoCommitCheckBox -and $script:CherryPickNoCommitCheckBox.Checked)
        return $plan.Display
    } catch {
        return 'git cherry-pick ' + (Quote-Arg $commitish)
    }
}

function CherryPick-SelectedOrTypedCommit {
    try {
        if (-not (Test-GitRepository)) { [void](Ensure-RepositorySelected); return }
        if (-not (Test-CleanWorkingTree -Operation 'cherry-pick selected commit')) { return }
        $commitish = Get-SelectedHistoryCommitish
        if ([string]::IsNullOrWhiteSpace($commitish)) { [System.Windows.Forms.MessageBox]::Show('Enter a commit hash/ref or select/copy one from History / Graph first.', 'No commit selected', 'OK', 'Information') | Out-Null; return }
        $noCommit = ($script:CherryPickNoCommitCheckBox -and $script:CherryPickNoCommitCheckBox.Checked)
        if (Get-Command Test-GgcpCommitish -ErrorAction SilentlyContinue) {
            $validation = Test-GgcpCommitish -Commitish $commitish
            if (-not $validation.Valid) { [System.Windows.Forms.MessageBox]::Show($validation.Error, 'Invalid commit/ref', 'OK', 'Warning') | Out-Null; return }
        }
        $plan = if (Get-Command Get-GgcpCherryPickCommandPlan -ErrorAction SilentlyContinue) { Get-GgcpCherryPickCommandPlan -Commitish $commitish -NoCommit:$noCommit } else { [pscustomobject]@{ Arguments=@('cherry-pick', $commitish); Display=('git cherry-pick ' + (Quote-Arg $commitish)) } }
        $ok = Confirm-GuiAction -Title 'Cherry-pick commit' -Message ("Run cherry-pick?`r`n`r`n" + [string]$plan.Display + "`r`n`r`nCherry-pick applies one commit onto the current branch. It can create conflicts, so review the current branch and working tree first.") -Icon ([System.Windows.Forms.MessageBoxIcon]::Question)
        if (-not $ok) { return }
        $result = Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($plan.Arguments)) -Caption ([string]$plan.Display) -AllowFailure -ShowProgress
        if ($result.ExitCode -ne 0) { Show-GitFailureGuidance -Result $result -Operation 'cherry-pick' -ShowDialog; Refresh-Status; return }
        Set-SuggestedNextAction -Text 'Cherry-pick completed. Review the result and run tests before pushing.' -Action 'show-diff'
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Cherry-pick failed', 'OK', 'Error') | Out-Null
    }
}

function Build-CherryPickContinuePreview { if (Get-Command Get-GgcpCherryPickContinueCommandPlan -ErrorAction SilentlyContinue) { return (Get-GgcpCherryPickContinueCommandPlan).Display } return 'git cherry-pick --continue' }
function Build-CherryPickAbortPreview { if (Get-Command Get-GgcpCherryPickAbortCommandPlan -ErrorAction SilentlyContinue) { return (Get-GgcpCherryPickAbortCommandPlan).Display } return 'git cherry-pick --abort' }
function Build-RecoveryStatusPreview { if (Get-Command Get-GgrConflictStatusCommandPlan -ErrorAction SilentlyContinue) { return (Get-GgrConflictStatusCommandPlan).Display } return 'git status --short' }

#endregion
#region Push and Merge Operations

function Push-CurrentBranch {
    param([switch]$ConfirmBeforePush)
    try {
        if (-not $script:CurrentBranch) { Refresh-Status }

        if ($ConfirmBeforePush) {
            $msg = "This will run:`r`n`r`n$(Build-PushPreview)`r`n`r`nContinue?"
            $answer = [System.Windows.Forms.MessageBox]::Show($msg, 'Confirm push current branch', 'YesNo', 'Question')
            if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        }

        if ((Get-Command Get-GgbPushCurrentBranchCommandPlan -ErrorAction SilentlyContinue) -and -not ($script:Config.UseForceWithLease -and $script:CommitAmendCheckBox -and $script:CommitAmendCheckBox.Checked)) {
            foreach ($plan in @(Get-GgbPushCurrentBranchCommandPlan)) {
                $gitArgs = @('-C', $script:RepoRoot) + @($plan.Arguments)
                $result = Run-External -FileName 'git' -Arguments $gitArgs -Caption $plan.Display -AllowFailure -ShowProgress
                Show-GitHubPullRequestUrlFromResult -Result $result
                if ($result.ExitCode -ne 0) { Show-GitHubRemoteFailureGuidance -Result $result -Operation 'push current branch' -RemoteName ([string]$script:Config.DefaultRemoteName) }
            }
        } else {
            $args = @('-C', $script:RepoRoot, 'push', '-u', 'origin', 'HEAD')
            $caption = 'git push -u origin HEAD'
            if ($script:Config.UseForceWithLease -and $script:CommitAmendCheckBox -and $script:CommitAmendCheckBox.Checked) {
                $args = @('-C', $script:RepoRoot, 'push', '--force-with-lease')
                $caption = 'git push --force-with-lease'
            }
            $result = Run-External -FileName 'git' -Arguments $args -Caption $caption -AllowFailure -ShowProgress
            Show-GitHubPullRequestUrlFromResult -Result $result
            if ($result.ExitCode -ne 0) { Show-GitHubRemoteFailureGuidance -Result $result -Operation 'push current branch' -RemoteName ([string]$script:Config.DefaultRemoteName) }
        }
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Push failed', 'OK', 'Error') | Out-Null
    }
}

function Invoke-GitPlansWithRecovery {
    param(
        [Parameter(Mandatory=$true)][object[]]$Plans,
        [string]$Operation = 'Git operation'
    )

    foreach ($plan in @($Plans)) {
        $gitArgs = @('-C', $script:RepoRoot) + @($plan.Arguments)
        $result = Run-External -FileName 'git' -Arguments $gitArgs -Caption ([string]$plan.Display) -ShowProgress -AllowFailure
        if ($result.ExitCode -ne 0) { Show-GitFailureGuidance -Result $result -Operation $Operation -ShowDialog; Refresh-Status; return $false }
    }
    return $true
}


function Show-BranchTrackingOverview {
    try {
        $plan = if (Get-Command Get-GgbBranchTrackingCommandPlan -ErrorAction SilentlyContinue) { Get-GgbBranchTrackingCommandPlan } else { [pscustomobject]@{ Arguments=@('branch','-vv'); Display='git branch -vv' } }
        $result = Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($plan.Arguments)) -Caption ([string]$plan.Display) -AllowFailure -QuietOutput
        $text = if ([string]::IsNullOrWhiteSpace([string]$result.StdOut)) { [string]$result.StdErr } else { [string]$result.StdOut }
        Set-CommandPreview -Title 'Branch tracking overview' -Commands ([string]$plan.Display) -Notes $text.Trim()
        Append-Log -Text 'Branch tracking overview:' -Color ([System.Drawing.Color]::DarkBlue)
        foreach ($line in @($text -split "`r?`n")) { if (-not [string]::IsNullOrWhiteSpace($line)) { Append-Log -Text $line -Color ([System.Drawing.Color]::Black) } }
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Branch tracking failed', 'OK', 'Error') | Out-Null }
}

function Sync-MainIntoDevelop {
    try {
        if (-not (Test-CleanWorkingTree -Operation "sync $($script:Config.MainBranch) into $($script:Config.BaseBranch)")) { return }
        $msg = "This will run:`r`n`r`n$(Build-SyncMainIntoDevelopPreview)`r`n`r`nUse this before integrating features when main may have hotfixes or release corrections. Continue?"
        $answer = [System.Windows.Forms.MessageBox]::Show($msg, "Confirm sync: $($script:Config.MainBranch) -> $($script:Config.BaseBranch)", 'YesNo', 'Question')
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        $plans = if (Get-Command Get-GgbSyncMainIntoBaseCommandPlan -ErrorAction SilentlyContinue) { @(Get-GgbSyncMainIntoBaseCommandPlan -MainBranch $script:Config.MainBranch -BaseBranch $script:Config.BaseBranch) } else { @(
            [pscustomobject]@{ Arguments=@('switch',$script:Config.MainBranch); Display="git switch $($script:Config.MainBranch)" },
            [pscustomobject]@{ Arguments=@('pull','--ff-only'); Display='git pull --ff-only' },
            [pscustomobject]@{ Arguments=@('switch',$script:Config.BaseBranch); Display="git switch $($script:Config.BaseBranch)" },
            [pscustomobject]@{ Arguments=@('pull','--ff-only'); Display='git pull --ff-only' },
            [pscustomobject]@{ Arguments=@('merge',$script:Config.MainBranch); Display="git merge $($script:Config.MainBranch)" },
            [pscustomobject]@{ Arguments=@('push','-u','origin',$script:Config.BaseBranch); Display="git push -u origin $($script:Config.BaseBranch)" }
        ) }
        $ok = Invoke-GitPlansWithRecovery -Plans $plans -Operation "sync $($script:Config.MainBranch) into $($script:Config.BaseBranch)"
        if ($ok) { Refresh-Status }
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Sync main into develop failed', 'OK', 'Error') | Out-Null }
}

function Merge-SelectedFeatureIntoDevelop {
    try {
        $featureBranch = Get-SelectedIntegrationFeatureBranch
        if ([string]::IsNullOrWhiteSpace($featureBranch) -or $featureBranch -eq '<feature-branch>') { [System.Windows.Forms.MessageBox]::Show('Select or type a feature branch first.', 'No feature branch selected', 'OK', 'Information') | Out-Null; return }
        if ($featureBranch -eq [string]$script:Config.BaseBranch -or $featureBranch -eq [string]$script:Config.MainBranch) { [System.Windows.Forms.MessageBox]::Show('Choose a feature branch, not main or develop.', 'Invalid feature branch', 'OK', 'Warning') | Out-Null; return }
        if (-not (Test-CleanWorkingTree -Operation "merge '$featureBranch' into $($script:Config.BaseBranch)")) { return }
        $msg = "This will run:`r`n`r`n$(Build-MergeSelectedFeatureIntoDevelopPreview)`r`n`r`nContinue?"
        $answer = [System.Windows.Forms.MessageBox]::Show($msg, 'Confirm merge: selected feature -> develop', 'YesNo', 'Question')
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        $plans = if (Get-Command Get-GgbMergeNamedFeatureIntoBaseCommandPlan -ErrorAction SilentlyContinue) { @(Get-GgbMergeNamedFeatureIntoBaseCommandPlan -FeatureBranch $featureBranch -BaseBranch $script:Config.BaseBranch) } else { @(
            [pscustomobject]@{ Arguments=@('switch',$script:Config.BaseBranch); Display="git switch $($script:Config.BaseBranch)" },
            [pscustomobject]@{ Arguments=@('pull','--ff-only'); Display='git pull --ff-only' },
            [pscustomobject]@{ Arguments=@('merge','--no-ff',$featureBranch); Display=('git merge --no-ff ' + (Quote-Arg $featureBranch)) },
            [pscustomobject]@{ Arguments=@('push','-u','origin',$script:Config.BaseBranch); Display="git push -u origin $($script:Config.BaseBranch)" }
        ) }
        $ok = Invoke-GitPlansWithRecovery -Plans $plans -Operation "merge '$featureBranch' into $($script:Config.BaseBranch)"
        if ($ok) { Refresh-Status }
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Merge selected feature failed', 'OK', 'Error') | Out-Null }
}

function Run-QualityChecksForMergeGate {
    try {
        $scriptPath = Join-Path $script:RepoRoot 'scripts\windows\run-quality-checks.bat'
        if (-not (Test-Path -LiteralPath $scriptPath)) { [System.Windows.Forms.MessageBox]::Show("Could not find quality checks script:`r`n$scriptPath", 'Quality checks not found', 'OK', 'Warning') | Out-Null; return }
        [void](Run-External -FileName 'cmd.exe' -Arguments @('/c', $scriptPath) -WorkingDirectory $script:RepoRoot -Caption 'scripts\windows\run-quality-checks.bat' -ShowProgress -AllowFailure)
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Quality checks failed', 'OK', 'Error') | Out-Null }
}

function Show-MergeWorkflowGuide {
    try {
        $text = Build-MergeWorkflowGuidePreview
        Set-CommandPreview -Title 'Git Flow merge and publish guide' -Commands $text -Notes 'Use this as a deliberate promotion path: feature -> develop, quality checks, develop -> main, then push/tag.'
        Append-Log -Text 'Git Flow merge and publish guide:' -Color ([System.Drawing.Color]::DarkBlue)
        foreach ($line in @($text -split "`r?`n")) { if (-not [string]::IsNullOrWhiteSpace($line)) { Append-Log -Text $line -Color ([System.Drawing.Color]::Black) } }
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Merge workflow guide failed', 'OK', 'Error') | Out-Null }
}

function Show-MergeWorkflowChecklist {
    try {
        $text = Build-MergeWorkflowChecklistPreview
        Set-CommandPreview -Title 'Git Flow merge and publish checklist' -Commands $text -Notes 'Checklist status is advisory. Use it to avoid skipping feature -> develop -> quality checks -> main promotion.'
        Append-Log -Text 'Git Flow merge and publish checklist:' -Color ([System.Drawing.Color]::DarkBlue)
        foreach ($line in @($text -split "`r?`n")) { if (-not [string]::IsNullOrWhiteSpace($line)) { Append-Log -Text $line -Color ([System.Drawing.Color]::Black) } }
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Merge workflow checklist failed', 'OK', 'Error') | Out-Null }
}

function Cleanup-SelectedFeatureBranch {
    try {
        $featureBranch = Get-SelectedIntegrationFeatureBranch
        if ([string]::IsNullOrWhiteSpace($featureBranch) -or $featureBranch -eq '<feature-branch>') { [System.Windows.Forms.MessageBox]::Show('Select or type a merged feature/fix branch first.', 'No branch selected', 'OK', 'Information') | Out-Null; return }
        if ($featureBranch -eq [string]$script:Config.BaseBranch -or $featureBranch -eq [string]$script:Config.MainBranch) { [System.Windows.Forms.MessageBox]::Show('Cleanup is intended for merged feature/fix branches, not main or develop.', 'Protected branch', 'OK', 'Warning') | Out-Null; return }
        $preview = Build-CleanupSelectedFeatureBranchPreview
        $msg = "This cleanup should be done only after the branch was merged and pushed.`r`n`r`nRun:`r`n`r`n$preview`r`n`r`nContinue?"
        $answer = [System.Windows.Forms.MessageBox]::Show($msg, 'Confirm merged branch cleanup', 'YesNo', 'Warning')
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        $plans = if (Get-Command Get-GgbCleanupMergedBranchCommandPlan -ErrorAction SilentlyContinue) { @(Get-GgbCleanupMergedBranchCommandPlan -BranchName $featureBranch -DeleteRemote) } else { @(
            [pscustomobject]@{ Arguments=@('branch','-d',$featureBranch); Display=('git branch -d ' + (Quote-Arg $featureBranch)) },
            [pscustomobject]@{ Arguments=@('push','origin','--delete',$featureBranch); Display=('git push origin --delete ' + (Quote-Arg $featureBranch)) }
        ) }
        [void](Invoke-GitPlansSequentially -Plans $plans -Operation 'merged branch cleanup')
        Refresh-Status
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Branch cleanup failed', 'OK', 'Error') | Out-Null }
}

function Merge-CurrentFeatureIntoDevelop {
    try {
        if (-not $script:CurrentBranch) { Refresh-Status }
        $featureBranch = $script:CurrentBranch
        if ($featureBranch -eq $script:Config.BaseBranch -or $featureBranch -eq $script:Config.MainBranch) {
            [System.Windows.Forms.MessageBox]::Show('Switch to a feature branch first.', 'Invalid source branch', 'OK', 'Warning') | Out-Null
            return
        }
        if (-not (Test-CleanWorkingTree -Operation "merge '$featureBranch' into $($script:Config.BaseBranch)")) { return }
        $msg = "This will run:`r`n`r`n$(Build-MergeFeaturePreview)`r`n`r`nContinue?"
        $answer = [System.Windows.Forms.MessageBox]::Show($msg, 'Confirm merge: feature -> develop', 'YesNo', 'Question')
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        if (Get-Command Get-GgbMergeFeatureIntoBaseCommandPlan -ErrorAction SilentlyContinue) {
            $ok = Invoke-GitPlansWithRecovery -Plans @(Get-GgbMergeFeatureIntoBaseCommandPlan -FeatureBranch $featureBranch -BaseBranch $script:Config.BaseBranch) -Operation "merge '$featureBranch' into $($script:Config.BaseBranch)"
            if (-not $ok) { return }
        } else {
            $plans = @(
                [pscustomobject]@{ Arguments=@('switch', $script:Config.BaseBranch); Display="git switch $($script:Config.BaseBranch)" },
                [pscustomobject]@{ Arguments=@('pull','--ff-only'); Display='git pull --ff-only' },
                [pscustomobject]@{ Arguments=@('merge','--no-ff',$featureBranch); Display=('git merge --no-ff ' + (Quote-Arg $featureBranch)) },
                [pscustomobject]@{ Arguments=@('push','-u','origin',$script:Config.BaseBranch); Display="git push -u origin $($script:Config.BaseBranch)" }
            )
            $ok = Invoke-GitPlansWithRecovery -Plans $plans -Operation "merge '$featureBranch' into $($script:Config.BaseBranch)"
            if (-not $ok) { return }
        }
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Merge to develop failed', 'OK', 'Error') | Out-Null
    }
}

function Merge-DevelopIntoMain {
    try {
        if (-not (Test-CleanWorkingTree -Operation "merge $($script:Config.BaseBranch) into $($script:Config.MainBranch)")) { return }
        $msg = "This will run:`r`n`r`n$(Build-MergeDevelopPreview)`r`n`r`nContinue?"
        $answer = [System.Windows.Forms.MessageBox]::Show($msg, 'Confirm merge: develop -> main', 'YesNo', 'Question')
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        if (Get-Command Get-GgbMergeBaseIntoMainCommandPlan -ErrorAction SilentlyContinue) {
            $ok = Invoke-GitPlansWithRecovery -Plans @(Get-GgbMergeBaseIntoMainCommandPlan -BaseBranch $script:Config.BaseBranch -MainBranch $script:Config.MainBranch) -Operation "merge $($script:Config.BaseBranch) into $($script:Config.MainBranch)"
            if (-not $ok) { return }
        } else {
            $plans = @(
                [pscustomobject]@{ Arguments=@('switch', $script:Config.MainBranch); Display="git switch $($script:Config.MainBranch)" },
                [pscustomobject]@{ Arguments=@('pull','--ff-only'); Display='git pull --ff-only' },
                [pscustomobject]@{ Arguments=@('merge','--no-ff',$script:Config.BaseBranch); Display="git merge --no-ff $($script:Config.BaseBranch)" },
                [pscustomobject]@{ Arguments=@('push','-u','origin',$script:Config.MainBranch); Display="git push -u origin $($script:Config.MainBranch)" }
            )
            $ok = Invoke-GitPlansWithRecovery -Plans $plans -Operation "merge $($script:Config.BaseBranch) into $($script:Config.MainBranch)"
            if (-not $ok) { return }
        }
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Merge to main failed', 'OK', 'Error') | Out-Null
    }
}
#endregion
#region Stash Operations

function Show-StashFailureGuidance {
    param(
        [object]$Result,
        [string]$Operation = 'stash operation'
    )

    Show-GitFailureGuidance -Result $Result -Operation $Operation -ShowDialog
}

function Invoke-StashDirtyWorkSuggestedAction {
    try {
        if (-not (Test-GitRepository)) { [void](Ensure-RepositorySelected); return }
        $message = if ($script:StashMessageTextBox) { $script:StashMessageTextBox.Text.Trim() } else { '' }
        if ([string]::IsNullOrWhiteSpace($message)) {
            if (Get-Command Get-GgsDefaultStashMessage -ErrorAction SilentlyContinue) {
                $message = Get-GgsDefaultStashMessage -Prefix ([string]$script:Config.DefaultStashMessagePrefix)
            } else {
                $message = ('wip: {0:yyyy-MM-dd HH:mm}' -f (Get-Date))
            }
        }
        $answer = [System.Windows.Forms.MessageBox]::Show("Stash current unstaged and untracked work?`r`n`r`nMessage: $message`r`n`r`nThis is recoverable from the Stash tab, but it changes the working tree.", 'Confirm stash dirty work', 'YesNo', 'Question')
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        if ($script:StashMessageTextBox) { $script:StashMessageTextBox.Text = $message }
        Stash-ChangesPreset -IncludeUntracked
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Suggested stash failed', 'OK', 'Error') | Out-Null
    }
}


function Stash-Changes {
    try {
        $message = if ($script:StashMessageTextBox) { $script:StashMessageTextBox.Text.Trim() } else { '' }
        $includeUntracked = ($script:StashIncludeUntrackedCheckBox -and $script:StashIncludeUntrackedCheckBox.Checked)
        $keepIndex = ($script:StashKeepIndexCheckBox -and $script:StashKeepIndexCheckBox.Checked)
        if (Get-Command Get-GgsStashPushCommandPlan -ErrorAction SilentlyContinue) {
            $plan = Get-GgsStashPushCommandPlan -Message $message -IncludeUntracked:$includeUntracked -KeepIndex:$keepIndex
            $args = @('-C', $script:RepoRoot) + @($plan.Arguments)
            $caption = [string]$plan.Display
        } else {
            $args = @('-C', $script:RepoRoot, 'stash', 'push')
            if ($includeUntracked) { $args += '-u' }
            if ($keepIndex) { $args += '--keep-index' }
            if (-not [string]::IsNullOrWhiteSpace($message)) { $args += @('-m', $message) }
            $caption = Build-StashPushPreview
        }
        [void](Run-External -FileName 'git' -Arguments $args -Caption $caption)
        if ($script:StashMessageTextBox) { $script:StashMessageTextBox.Clear() }
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Stash failed', 'OK', 'Error') | Out-Null
    }
}

function Stash-ChangesPreset {
    param(
        [switch]$IncludeUntracked,
        [switch]$KeepIndex
    )
    try {
        $message = if ($script:StashMessageTextBox) { $script:StashMessageTextBox.Text.Trim() } else { '' }
        if (Get-Command Get-GgsStashPushCommandPlan -ErrorAction SilentlyContinue) {
            $plan = Get-GgsStashPushCommandPlan -Message $message -IncludeUntracked:$IncludeUntracked -KeepIndex:$KeepIndex
            $args = @('-C', $script:RepoRoot) + @($plan.Arguments)
            $caption = [string]$plan.Display
        } else {
            $args = @('-C', $script:RepoRoot, 'stash', 'push')
            if ($IncludeUntracked) { $args += '-u' }
            if ($KeepIndex) { $args += '--keep-index' }
            if (-not [string]::IsNullOrWhiteSpace($message)) { $args += @('-m', $message) }
            $caption = if ($IncludeUntracked) { Build-StashPushIncludeUntrackedPreview } elseif ($KeepIndex) { Build-StashPushKeepIndexPreview } else { Build-StashPushPreview }
        }
        [void](Run-External -FileName 'git' -Arguments $args -Caption $caption)
        if ($script:StashMessageTextBox) { $script:StashMessageTextBox.Clear() }
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Stash failed', 'OK', 'Error') | Out-Null
    }
}

function Pop-Stash {
    param([switch]$RestoreIndex)
    try {
        $stashRef = Get-SelectedStashRef -DefaultLatest
        if (-not $stashRef) {
            [System.Windows.Forms.MessageBox]::Show('No stash entries found.', 'No stashes', 'OK', 'Information') | Out-Null
            return
        }
        if (Get-Command Get-GgsStashPopCommandPlan -ErrorAction SilentlyContinue) {
            $plan = Get-GgsStashPopCommandPlan -StashRef $stashRef -RestoreIndex:$RestoreIndex
            $args = @('-C', $script:RepoRoot) + @($plan.Arguments)
            $caption = [string]$plan.Display
        } else {
            $args = @('-C', $script:RepoRoot, 'stash', 'pop')
            if ($RestoreIndex) { $args += '--index' }
            $args += $stashRef
            $caption = Build-StashPopPreview -RestoreIndex:$RestoreIndex
        }
        $result = Run-External -FileName 'git' -Arguments $args -Caption $caption -AllowFailure
        if ($result.ExitCode -ne 0) { Show-StashFailureGuidance -Result $result -Operation 'stash pop'; Refresh-Status; return }
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Stash pop failed', 'OK', 'Error') | Out-Null
    }
}

function Apply-Stash {
    param([switch]$RestoreIndex)
    try {
        $stashRef = Get-SelectedStashRef
        if (-not $stashRef) {
            [System.Windows.Forms.MessageBox]::Show('Select a stash entry first.', 'No stash selected', 'OK', 'Information') | Out-Null
            return
        }
        if (Get-Command Get-GgsStashApplyCommandPlan -ErrorAction SilentlyContinue) {
            $plan = Get-GgsStashApplyCommandPlan -StashRef $stashRef -RestoreIndex:$RestoreIndex
            $args = @('-C', $script:RepoRoot) + @($plan.Arguments)
            $caption = [string]$plan.Display
        } else {
            $args = @('-C', $script:RepoRoot, 'stash', 'apply')
            if ($RestoreIndex) { $args += '--index' }
            $args += $stashRef
            $caption = Build-StashApplyPreview -RestoreIndex:$RestoreIndex
        }
        $result = Run-External -FileName 'git' -Arguments $args -Caption $caption -AllowFailure
        if ($result.ExitCode -ne 0) { Show-StashFailureGuidance -Result $result -Operation 'stash apply'; Refresh-Status; return }
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Stash apply failed', 'OK', 'Error') | Out-Null
    }
}

function Drop-Stash {

    try {
        $stashRef = Get-SelectedStashRef
        if (-not $stashRef) {
            [System.Windows.Forms.MessageBox]::Show('Select a stash entry first.', 'No stash selected', 'OK', 'Information') | Out-Null
            return
        }

        $answer = [System.Windows.Forms.MessageBox]::Show("Drop ${stashRef}?`r`n`r`nThis cannot be undone.", 'Confirm drop', 'YesNo', 'Warning')

        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }

        if (Get-Command Get-GgsStashDropCommandPlan -ErrorAction SilentlyContinue) { $plan = Get-GgsStashDropCommandPlan -StashRef $stashRef; $dropArgs = @('-C', $script:RepoRoot) + @($plan.Arguments); $dropCaption = [string]$plan.Display } else { $dropArgs = @('-C', $script:RepoRoot, 'stash', 'drop', $stashRef); $dropCaption = "git stash drop $stashRef" }; [void](Run-External -FileName 'git' -Arguments $dropArgs -Caption $dropCaption)
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Stash drop failed', 'OK', 'Error') | Out-Null
    }
}

function Get-SelectedStashRef {
    param([switch]$DefaultLatest)

    if ($script:StashListBox -and $script:StashListBox.SelectedIndex -ge 0) {
        $selected = [string]$script:StashListBox.SelectedItem
        if ($selected -match 'stash@\{\d+\}') { return $matches[0] }
        return ('stash@{' + [string]$script:StashListBox.SelectedIndex + '}')
    }
    if ($DefaultLatest -and @($script:StashList).Count -gt 0) { return 'stash@{0}' }
    return $null
}

function Refresh-StashPanel {
    Load-StashList
    $count = @($script:StashList).Count
    if ($script:DiffTextBox) {
        Set-DiffPreviewText -Text "Stash list refreshed.`r`n`r`n$count stash entr$(if ($count -eq 1) { 'y' } else { 'ies' }) found."
    }
    Set-StatusBar("Ready. Stashes: $count")
}

function Show-SelectedStashDiff {
    try {
        $stashRef = Get-SelectedStashRef -DefaultLatest
        if (-not $stashRef) {
            Set-DiffPreviewText -Text '(No stash entries found.)'
            return
        }
        $result = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'stash', 'show', '--stat', '--patch', $stashRef) -Caption "git stash show --stat --patch $stashRef" -AllowFailure -QuietOutput
        Set-DiffPreviewText -Text $(if ([string]::IsNullOrWhiteSpace($result.StdOut)) { "(No stash diff output for $stashRef.)" } else { $result.StdOut })
        Set-CommandPreview -Title 'Show selected stash diff' -Commands (Build-StashShowPreview) -Notes 'Displays the selected stash patch without applying it.'
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Show stash diff failed', 'OK', 'Error') | Out-Null
    }
}


function Show-SelectedStashNameStatus {
    try {
        $stashRef = Get-SelectedStashRef -DefaultLatest
        if (-not $stashRef) {
            Set-DiffPreviewText -Text '(No stash entries found.)'
            return
        }
        $result = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'stash', 'show', '--name-status', $stashRef) -Caption "git stash show --name-status $stashRef" -AllowFailure -QuietOutput
        Set-DiffPreviewText -Text $(if ([string]::IsNullOrWhiteSpace($result.StdOut)) { "(No changed-file list for $stashRef.)" } else { $result.StdOut })
        Set-CommandPreview -Title 'Show files in selected stash' -Commands (Build-StashNameStatusPreview) -Notes 'Lists files captured in the selected stash without applying it.'
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Show stash files failed', 'OK', 'Error') | Out-Null
    }
}

function Create-BranchFromStash {
    try {
        $stashRef = Get-SelectedStashRef -DefaultLatest
        if (-not $stashRef) {
            [System.Windows.Forms.MessageBox]::Show('Select a stash entry first.', 'No stash selected', 'OK', 'Information') | Out-Null
            return
        }
        $branchName = if ($script:StashBranchTextBox) { $script:StashBranchTextBox.Text.Trim() } else { '' }
        if ([string]::IsNullOrWhiteSpace($branchName)) {
            [System.Windows.Forms.MessageBox]::Show('Enter a branch name for the stash branch first.', 'Missing branch name', 'OK', 'Warning') | Out-Null
            return
        }
        $validation = Validate-BranchName $branchName
        if (-not $validation.Valid) {
            [System.Windows.Forms.MessageBox]::Show($validation.Error, 'Invalid branch name', 'OK', 'Warning') | Out-Null
            return
        }
        if (Test-BranchExists $branchName) {
            [System.Windows.Forms.MessageBox]::Show("Branch '$branchName' already exists.", 'Branch exists', 'OK', 'Warning') | Out-Null
            return
        }
        [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'stash', 'branch', $branchName, $stashRef) -Caption "git stash branch $branchName $stashRef" -ShowProgress)
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Create branch from stash failed', 'OK', 'Error') | Out-Null
    }
}

function Clear-AllStashes {
    try {
        if (@($script:StashList).Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show('No stashes to clear.', 'No stashes', 'OK', 'Information') | Out-Null
            return
        }
        $answer = [System.Windows.Forms.MessageBox]::Show("Clear all stash entries?`r`n`r`nThis cannot be undone.", 'Confirm clear all stashes', 'YesNo', 'Warning')
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'stash', 'clear') -Caption 'git stash clear')
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Clear stashes failed', 'OK', 'Error') | Out-Null
    }
}

function Run-CustomGitCommand {
    param([string]$CommandText)

    try {
        $args = Convert-GitCommandTextToArgs -CommandText $CommandText
        if (@($args).Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show('Enter a git command, for example: status -sb', 'Missing command', 'OK', 'Information') | Out-Null
            return
        }
        if (Test-GitArgsPotentiallyDestructive -Arguments $args) {
            $ok = Confirm-GuiAction -Title 'Confirm potentially destructive custom Git command' -Message ("This custom command may change, remove, or rewrite repository state:`r`n`r`n{0}`r`n`r`nContinue?" -f (Format-GitCommandArgs -Arguments $args))
            if (-not $ok) {
                Append-Log -Text 'Custom Git command cancelled by user.' -Color ([System.Drawing.Color]::DarkOrange)
                return
            }
        }

        $result = Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($args)) -Caption (Format-GitCommandArgs -Arguments $args) -AllowFailure -ShowProgress
        $text = @()
        if (-not [string]::IsNullOrWhiteSpace($result.StdOut)) { $text += $result.StdOut.TrimEnd() }
        if (-not [string]::IsNullOrWhiteSpace($result.StdErr)) { $text += ''; $text += 'stderr:'; $text += $result.StdErr.TrimEnd() }
        if ($text.Count -eq 0) { $text += '(Command completed without output.)' }
        Set-DiffPreviewText -Text ($text -join "`r`n")
        Set-CommandPreview -Title 'Custom git command' -Commands (Format-GitCommandArgs -Arguments $args) -Notes 'Custom commands run as git arguments in the current repository, without shell operators.'
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Custom git command failed', 'OK', 'Error') | Out-Null
    }
}

function Add-CustomGitButtonFromFields {
    try {
        $label = if ($script:CustomGitLabelTextBox) { $script:CustomGitLabelTextBox.Text.Trim() } else { '' }
        $arguments = if ($script:CustomGitCommandTextBox) { $script:CustomGitCommandTextBox.Text.Trim() } else { '' }
        if ([string]::IsNullOrWhiteSpace($label)) {
            [System.Windows.Forms.MessageBox]::Show('Enter a button label first.', 'Missing label', 'OK', 'Information') | Out-Null
            return
        }
        [void](Convert-GitCommandTextToArgs -CommandText $arguments)
        $defs = @($script:CustomGitButtons)
        $defs += @{ Label = $label; Arguments = $arguments }
        Save-CustomGitButtonDefinitions -Definitions $defs
        Refresh-CustomGitButtonsPanel
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Add custom button failed', 'OK', 'Error') | Out-Null
    }
}


function Update-SelectedCustomGitButtonFromFields {
    try {
        if (-not $script:CustomGitButtonsListBox -or $script:CustomGitButtonsListBox.SelectedIndex -lt 0) {
            [System.Windows.Forms.MessageBox]::Show('Select a saved custom button first, then edit the label or arguments.', 'No button selected', 'OK', 'Information') | Out-Null
            return
        }
        $label = if ($script:CustomGitLabelTextBox) { $script:CustomGitLabelTextBox.Text.Trim() } else { '' }
        $arguments = if ($script:CustomGitCommandTextBox) { $script:CustomGitCommandTextBox.Text.Trim() } else { '' }
        if ([string]::IsNullOrWhiteSpace($label)) {
            [System.Windows.Forms.MessageBox]::Show('Enter a button label first.', 'Missing label', 'OK', 'Information') | Out-Null
            return
        }
        [void](Convert-GitCommandTextToArgs -CommandText $arguments)

        $idx = [int]$script:CustomGitButtonsListBox.SelectedIndex
        $defs = @($script:CustomGitButtons)
        if ($idx -lt 0 -or $idx -ge $defs.Count) { return }
        $defs[$idx] = @{ Label = $label; Arguments = $arguments }
        Save-CustomGitButtonDefinitions -Definitions $defs
        Refresh-CustomGitButtonsPanel
        if ($script:CustomGitButtonsListBox.Items.Count -gt $idx) { $script:CustomGitButtonsListBox.SelectedIndex = $idx }
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Update custom button failed', 'OK', 'Error') | Out-Null
    }
}

function Remove-SelectedCustomGitButton {
    if (-not $script:CustomGitButtonsListBox -or $script:CustomGitButtonsListBox.SelectedIndex -lt 0) {
        [System.Windows.Forms.MessageBox]::Show('Select a saved custom button first.', 'No button selected', 'OK', 'Information') | Out-Null
        return
    }
    $idx = [int]$script:CustomGitButtonsListBox.SelectedIndex
    $defs = @($script:CustomGitButtons)
    if ($idx -lt 0 -or $idx -ge $defs.Count) { return }
    $remaining = @()
    for ($i = 0; $i -lt $defs.Count; $i++) {
        if ($i -ne $idx) { $remaining += $defs[$i] }
    }
    Save-CustomGitButtonDefinitions -Definitions $remaining
    Refresh-CustomGitButtonsPanel
}


function New-CustomGitButtonDraft {
    if ($script:CustomGitLabelTextBox) { $script:CustomGitLabelTextBox.Text = 'My git command' }
    if ($script:CustomGitCommandTextBox) { $script:CustomGitCommandTextBox.Text = 'status -sb' }
    if ($script:CustomGitButtonsListBox) { try { $script:CustomGitButtonsListBox.ClearSelected() } catch {} }
    Set-CommandPreview -Title 'New custom Git button draft' -Commands 'git status -sb' -Notes 'Edit the label and Git arguments, then click Save as new button.'
}

function Add-RecommendedCustomGitButtons {
    $recommended = @(
        @{ Label = 'Short status'; Arguments = 'status -sb' },
        @{ Label = 'Changed file summary'; Arguments = 'diff --stat' },
        @{ Label = 'Staged summary'; Arguments = 'diff --cached --stat' },
        @{ Label = 'Recent commits'; Arguments = 'log --oneline --decorate -n 20' },
        @{ Label = 'Branch graph'; Arguments = 'log --graph --decorate --oneline --all -n 30' },
        @{ Label = 'List stashes'; Arguments = 'stash list --date=local' }
    )

    $defs = @($script:CustomGitButtons)
    foreach ($entry in $recommended) {
        $exists = $false
        foreach ($def in $defs) {
            if ([string]$def.Label -eq [string]$entry.Label -or [string]$def.Arguments -eq [string]$entry.Arguments) { $exists = $true; break }
        }
        if (-not $exists) { $defs += $entry }
    }
    Save-CustomGitButtonDefinitions -Definitions $defs
    Refresh-CustomGitButtonsPanel
    Set-StatusBar('Recommended custom Git buttons added or already present.')
}

function Refresh-CustomGitButtonsPanel {
    if (-not $script:CustomGitButtonsPanel) { return }

    $script:CustomGitButtonsPanel.Controls.Clear()
    if ($script:CustomGitButtonsListBox) {
        $script:CustomGitButtonsListBox.BeginUpdate()
        $script:CustomGitButtonsListBox.Items.Clear()
    }

    $script:CustomGitButtons = Get-CustomGitButtonDefinitions
    foreach ($def in @($script:CustomGitButtons)) {
        $label = [string]$def.Label
        $command = [string]$def.Arguments

        if ($script:CustomGitButtonsListBox) {
            [void]$script:CustomGitButtonsListBox.Items.Add(('{0}  ->  git {1}' -f $label, $command))
        }

        $btn = New-Object System.Windows.Forms.Button
        $btn.Text = $label
        $btn.Width = 145
        $btn.Height = 34
        $btn.Margin = New-Object System.Windows.Forms.Padding(4)
        $localCommand = $command
        $localLabel = $label
        $btn.Add_Click({ Run-CustomGitCommand -CommandText $localCommand }.GetNewClosure())
        Set-ControlPreview -Control $btn -Builder { 'git ' + $localCommand }.GetNewClosure() -Title ("Custom: $localLabel") -Notes 'Runs this saved custom git command in the current repository. Commands are passed to git directly, not through a shell.'
        $script:CustomGitButtonsPanel.Controls.Add($btn)
    }

    if ($script:CustomGitButtonsListBox) { $script:CustomGitButtonsListBox.EndUpdate() }
}

#endregion


#region Release Tag and Safety Functions

function Validate-TagName {
    param([string]$Name)
    try {
        $cmd = Get-Command Test-GgtTagName -ErrorAction SilentlyContinue
        if ($cmd) { return (Test-GgtTagName -Name $Name) }
        $legacyCmd = Get-Command Test-GfgGitRefName -ErrorAction SilentlyContinue
        if ($legacyCmd) { return (Test-GfgGitRefName -Name $Name -Kind 'Tag') }
    } catch { throw }
    if ([string]::IsNullOrWhiteSpace($Name)) { return @{ Valid = $false; Error = 'Tag name cannot be empty.' } }
    if ($Name -match '\s') { return @{ Valid = $false; Error = 'Tag name cannot contain spaces.' } }
    if ($Name -match '[~^:?*\[\]\\]') { return @{ Valid = $false; Error = 'Tag name contains invalid Git reference characters.' } }
    if ($Name -match '\.\.|^\.|\.$|/$|//|\.lock$|^-' ) { return @{ Valid = $false; Error = 'Tag name format is invalid for a Git reference.' } }
    return @{ Valid = $true; Error = '' }
}

function Build-UndoLastCommitPreview {
    if (Get-Command Get-GgcSoftUndoLastCommitCommandPlan -ErrorAction SilentlyContinue) { return (ConvertTo-GgcCommandPreview -Plans (Get-GgcSoftUndoLastCommitCommandPlan)) }
    return "git log -1 --oneline`r`ngit reset --soft HEAD~1"
}

function Undo-LastCommitSoft {
    try {
        $last = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'log', '-1', '--oneline') -Caption 'git log -1 --oneline' -AllowFailure -QuietOutput
        if ($last.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($last.StdOut)) {
            [System.Windows.Forms.MessageBox]::Show('No commit was found to undo in this repository.', 'Undo last commit', 'OK', 'Information') | Out-Null
            return
        }
        $parent = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'rev-parse', '--verify', 'HEAD~1') -Caption 'git rev-parse --verify HEAD~1' -AllowFailure -QuietOutput
        if ($parent.ExitCode -ne 0) {
            [System.Windows.Forms.MessageBox]::Show('The current commit has no parent. Soft undo is not available for the first commit.', 'Undo last commit', 'OK', 'Warning') | Out-Null
            return
        }
        $ok = Confirm-GuiAction -Title 'Undo last commit, keep changes staged' -Message ("This will run:`r`n`r`ngit reset --soft HEAD~1`r`n`r`nLast commit:`r`n{0}`r`n`r`nThe commit object is removed from the current branch tip, but its file changes stay staged so you can edit and recommit. Continue?" -f $last.StdOut.Trim())
        if (-not $ok) { return }
        [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'reset', '--soft', 'HEAD~1') -Caption 'git reset --soft HEAD~1' -ShowProgress)
        Append-Log -Text 'Last commit was undone with --soft; changes remain staged.' -Color ([System.Drawing.Color]::DarkGreen)
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Undo last commit failed', 'OK', 'Error') | Out-Null
    }
}

function Get-SelectedTagName {
    if (-not $script:TagListBox -or $script:TagListBox.SelectedIndex -lt 0) { return '' }
    $item = [string]$script:TagListBox.SelectedItem
    try {
        $cmd = Get-Command Get-GgtSelectedTagNameFromDisplayLine -ErrorAction SilentlyContinue
        if ($cmd) { return (Get-GgtSelectedTagNameFromDisplayLine -DisplayLine $item) }
    } catch {}
    if ([string]::IsNullOrWhiteSpace($item) -or $item.StartsWith('(')) { return '' }
    return (($item -split '\s+', 2)[0]).Trim()
}

function Build-SelectedTagPreview {
    param([string]$Action)
    $tag = Get-SelectedTagName
    if ([string]::IsNullOrWhiteSpace($tag)) { $tag = '<selected-tag>' }
    try {
        switch ($Action) {
            'Details' { $plan = Get-GgtShowTagDetailsCommandPlan -TagName $tag; return $plan.Display }
            'Push' { $plan = Get-GgtPushTagCommandPlan -TagName $tag; return $plan.Display }
            'Delete' { $plan = Get-GgtDeleteLocalTagCommandPlan -TagName $tag; return $plan.Display }
            'Checkout' { $plan = Get-GgtCheckoutTagCommandPlan -TagName $tag; return $plan.Display }
            default { $plan = Get-GgtTagListCommandPlan; return $plan.Display }
        }
    } catch {
        switch ($Action) {
            'Details' { return 'git show --no-patch --decorate --format=fuller ' + (Quote-Arg $tag) }
            'Push' { return 'git push origin ' + (Quote-Arg $tag) }
            'Delete' { return 'git tag -d ' + (Quote-Arg $tag) }
            'Checkout' { return 'git checkout ' + (Quote-Arg $tag) }
            default { return 'git tag --list --sort=-creatordate' }
        }
    }
}

function Load-TagList {
    if (-not $script:TagListBox) { return }
    $script:TagListBox.BeginUpdate()
    try {
        $script:TagListBox.Items.Clear()
        if (-not (Test-GitRepository)) { [void]$script:TagListBox.Items.Add('(Open a Git repository first)'); return }
        $tagListPlan = Get-GgtTagListCommandPlan
        $result = Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($tagListPlan.Arguments)) -Caption $tagListPlan.Display -AllowFailure -QuietOutput
        if ($result.ExitCode -ne 0) { [void]$script:TagListBox.Items.Add('(Could not load tags)'); return }
        $lines = @($result.StdOut -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($lines.Count -eq 0) { [void]$script:TagListBox.Items.Add('(No tags found)'); return }
        foreach ($line in $lines) { [void]$script:TagListBox.Items.Add($line.Trim()) }
    } finally { $script:TagListBox.EndUpdate() }
}

function Show-SelectedTagDetails {
    $tag = Get-SelectedTagName
    if ([string]::IsNullOrWhiteSpace($tag)) {
        if ($script:TagDetailsTextBox) { $script:TagDetailsTextBox.Text = 'Select a tag first.' }
        return
    }
    $detailsPlan = Get-GgtShowTagDetailsCommandPlan -TagName $tag
    $result = Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($detailsPlan.Arguments)) -Caption $detailsPlan.Display -AllowFailure -QuietOutput
    if ($script:TagDetailsTextBox) {
        $lines = @()
        if (-not [string]::IsNullOrWhiteSpace($result.StdOut)) { $lines += $result.StdOut.TrimEnd() }
        if (-not [string]::IsNullOrWhiteSpace($result.StdErr)) { $lines += ''; $lines += 'stderr:'; $lines += $result.StdErr.TrimEnd() }
        if ($lines.Count -eq 0) { $lines += '(No details returned.)' }
        $script:TagDetailsTextBox.Text = ($lines -join "`r`n")
    }
}

function Create-GitFlowTag {
    try {
        $tag = if ($script:TagNameTextBox) { $script:TagNameTextBox.Text.Trim() } else { '' }
        $message = if ($script:TagMessageTextBox) { $script:TagMessageTextBox.Text.Trim() } else { '' }
        $annotated = if ($script:TagAnnotatedCheckBox) { [bool]$script:TagAnnotatedCheckBox.Checked } else { $true }
        $pushAfter = if ($script:TagPushAfterCreateCheckBox) { [bool]$script:TagPushAfterCreateCheckBox.Checked } else { $false }
        $validation = Validate-TagName -Name $tag
        if (-not $validation.Valid) { [System.Windows.Forms.MessageBox]::Show($validation.Error, 'Invalid tag name', 'OK', 'Warning') | Out-Null; return }
        $existsPlan = Get-GgtVerifyTagDoesNotExistCommandPlan -TagName $tag
        $exists = Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($existsPlan.Arguments)) -Caption $existsPlan.Display -AllowFailure -QuietOutput
        if ($exists.ExitCode -eq 0) { [System.Windows.Forms.MessageBox]::Show("Tag '$tag' already exists. Delete it deliberately before recreating it.", 'Tag already exists', 'OK', 'Warning') | Out-Null; return }
        $createPlan = Get-GgtCreateTagCommandPlan -TagName $tag -Message $message -Annotated:([bool]$annotated)
        [void](Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($createPlan.Arguments)) -Caption $createPlan.Display -ShowProgress)
        if ($pushAfter) { Push-SelectedOrNamedTag -TagName $tag }
        Load-TagList
        if ($script:TagNameTextBox) { $script:TagNameTextBox.Clear() }
        if ($script:TagMessageTextBox) { $script:TagMessageTextBox.Clear() }
        Append-Log -Text ("Created tag '$tag'.") -Color ([System.Drawing.Color]::DarkGreen)
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Create tag failed', 'OK', 'Error') | Out-Null }
}

function Push-SelectedOrNamedTag {
    param([string]$TagName = '')
    $tag = if ([string]::IsNullOrWhiteSpace($TagName)) { Get-SelectedTagName } else { $TagName }
    if ([string]::IsNullOrWhiteSpace($tag)) { [System.Windows.Forms.MessageBox]::Show('Select a tag first, or create one with Push after create enabled.', 'No tag selected', 'OK', 'Information') | Out-Null; return }
    $ok = Confirm-GuiAction -Title 'Push tag to origin' -Message ("Push tag '$tag' to origin?`r`n`r`nTags are shared release markers. Only push tags that are intentional and ready for teammates or automation.") -Icon ([System.Windows.Forms.MessageBoxIcon]::Question)
    if (-not $ok) { return }
    $pushPlan = Get-GgtPushTagCommandPlan -TagName $tag
    [void](Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($pushPlan.Arguments)) -Caption $pushPlan.Display -ShowProgress)
    Append-Log -Text ("Pushed tag '$tag' to origin.") -Color ([System.Drawing.Color]::DarkGreen)
}

function Push-AllTags {
    $ok = Confirm-GuiAction -Title 'Push all tags to origin' -Message "This will run:`r`n`r`ngit push origin --tags`r`n`r`nUse this only when all local tags are intentional release markers. Continue?" -Icon ([System.Windows.Forms.MessageBoxIcon]::Warning)
    if (-not $ok) { return }
    $pushAllPlan = Get-GgtPushAllTagsCommandPlan
    [void](Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($pushAllPlan.Arguments)) -Caption $pushAllPlan.Display -ShowProgress)
}

function Delete-SelectedTag {
    $tag = Get-SelectedTagName
    if ([string]::IsNullOrWhiteSpace($tag)) { [System.Windows.Forms.MessageBox]::Show('Select a tag to delete.', 'No tag selected', 'OK', 'Information') | Out-Null; return }
    $deleteRemote = if ($script:TagDeleteRemoteCheckBox) { [bool]$script:TagDeleteRemoteCheckBox.Checked } else { $false }
    $guidance = Get-GgtTagDeleteSafetyGuidance -TagName $tag -DeleteRemote:([bool]$deleteRemote)
    $ok = Confirm-GuiAction -Title 'Delete selected tag' -Message ($guidance.Message + "`r`n`r`n" + $guidance.Details + "`r`n`r`nCommands:`r`n" + $guidance.Preview + "`r`n`r`nContinue?")
    if (-not $ok) { return }
    foreach ($plan in @($guidance.Plans)) {
        [void](Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($plan.Arguments)) -Caption $plan.Display -ShowProgress -AllowFailure:($plan.Verb -eq 'delete-remote-tag'))
    }
    Load-TagList
    if ($script:TagDetailsTextBox) { $script:TagDetailsTextBox.Clear() }
}

function Checkout-SelectedTag {
    $tag = Get-SelectedTagName
    if ([string]::IsNullOrWhiteSpace($tag)) { [System.Windows.Forms.MessageBox]::Show('Select a tag first.', 'No tag selected', 'OK', 'Information') | Out-Null; return }
    if (-not (Test-CleanWorkingTree)) { return }
    $branch = if ($script:TagBranchTextBox) { $script:TagBranchTextBox.Text.Trim() } else { '' }
    if (-not [string]::IsNullOrWhiteSpace($branch)) {
        $validation = Validate-BranchName $branch
        if (-not $validation.Valid) { [System.Windows.Forms.MessageBox]::Show($validation.Error, 'Invalid branch name', 'OK', 'Warning') | Out-Null; return }
        $branchPlan = Get-GgtBranchFromTagCommandPlan -BranchName $branch -TagName $tag
        [void](Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($branchPlan.Arguments)) -Caption $branchPlan.Display -ShowProgress)
    } else {
        $ok = Confirm-GuiAction -Title 'Checkout tag in detached HEAD' -Message ("Checking out tag '$tag' without a branch puts Git into detached HEAD state.`r`n`r`nFor experiments or fixes, enter a branch name first. Continue with detached checkout?")
        if (-not $ok) { return }
        $checkoutPlan = Get-GgtCheckoutTagCommandPlan -TagName $tag
        [void](Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($checkoutPlan.Arguments)) -Caption $checkoutPlan.Display -ShowProgress)
    }
    Refresh-Status
}

#endregion

#region Commit Template Functions

function Get-CommitTemplateValues {
    $choice = if ($script:CommitTemplateComboBox) {
        $script:CommitTemplateComboBox.Text
    } else { 'Custom' }

    $branch = Get-CurrentBranchNameOrPlaceholder

    switch ($choice) {
        'Feature' {
            return @{
                Subject = 'feat: summarize feature work'
                Body = "- implement the planned feature changes`r`n- keep existing behavior stable`r`n- add or update tests where needed"
            }
        }
        'Hotfix' {
            return @{
                Subject = 'fix: resolve targeted regression'
                Body = "- fix the identified regression`r`n- keep the existing workflow intact`r`n- update coverage for the failing path"
            }
        }
        'Release' {
            return @{
                Subject = 'release: prepare next version'
                Body = "- finalize implementation for the release`r`n- update docs and versioning`r`n- confirm build and test validation"
            }
        }
        'Refactor' {
            return @{
                Subject = 'refactor: simplify workflow and improve maintainability'
                Body = "- extract focused helpers/modules`r`n- preserve current behavior and contracts`r`n- add or update tests for refactored paths"
            }
        }
        'Docs' {
            return @{
                Subject = 'docs: update workflow guidance'
                Body = "- update help and examples`r`n- clarify recommended Git flow usage`r`n- align examples with current branch/release naming"
            }
        }
        'Test' {
            return @{
                Subject = 'test: strengthen coverage for current workflow'
                Body = "- add or update regression coverage`r`n- verify expected command flow`r`n- keep behavior unchanged"
            }
        }
        default {
            return @{
                Subject = ('chore: update ' + $branch)
                Body = "- summarize the change in one line`r`n- add technical details if useful`r`n- mention tests or validation"
            }
        }
    }
}

function Insert-CommitTemplate {
    $template = Get-CommitTemplateValues
    $script:CommitSubjectTextBox.Text = $template.Subject
    $script:CommitBodyTextBox.Text = $template.Body
    Update-CommitPreview
}

#endregion

#region Commit Operations

function Confirm-CommitOnWorkflowBranch {
    return (Confirm-ProtectedBranchWorkflowAction -ActionName 'commit here')
}

function Commit-Changes {
    param([switch]$PushAfterOverride)

    $plan = Get-CommitPlan
    $subject = $plan.Subject
    $stageAll = $plan.StageAll
    $amend = $plan.Amend
    $pushAfter = $PushAfterOverride.IsPresent -or $plan.PushAfter

    # Validate commit subject
    $validation = Validate-CommitSubject $subject
    if (-not $validation.Valid) {
        [System.Windows.Forms.MessageBox]::Show($validation.Error, 'Invalid commit message', 'OK', 'Warning') | Out-Null
        return
    }

    if ($validation.Warning) {
        $answer = [System.Windows.Forms.MessageBox]::Show($validation.Warning + "`r`n`r`nContinue anyway?", 'Commit message warning', 'YesNo', 'Warning')
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    }

    if (-not (Confirm-CommitOnWorkflowBranch)) { return }

    $tempFile = [System.IO.Path]::GetTempFileName()
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    try {
        if ($stageAll) {
            [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'add', '-A') -Caption 'git add -A')
        }

        [System.IO.File]::WriteAllText($tempFile, $plan.MessageText, $utf8NoBom)

        $commitArgs = @('-C', $script:RepoRoot, 'commit')
        if ($amend) { $commitArgs += '--amend' }
        $commitArgs += @('-F', $tempFile)

        $commitCaption = if ($amend) {
            'git commit --amend -F <temp-commit-message-file>'
        } else {
            'git commit -F <temp-commit-message-file>'
        }

        [void](Run-External -FileName 'git' -Arguments $commitArgs -Caption $commitCaption -ShowProgress)

        if ($pushAfter) {
            if ($amend -and $script:Config.UseForceWithLease) {
                [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'push', '--force-with-lease') -Caption 'git push --force-with-lease' -ShowProgress)
            } else {
                [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'push', '-u', 'origin', 'HEAD') -Caption 'git push -u origin HEAD' -ShowProgress)
            }
        }

        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Commit failed', 'OK', 'Error') | Out-Null
    } finally {
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }
}

#endregion

#region Utility Functions

function Save-LogToFile {
    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.Filter = 'Text files (*.txt)|*.txt|Log files (*.log)|*.log|All files (*.*)|*.*'
    $dialog.FileName = ('git-glide-gui-log-' + (Get-Date).ToString('yyyyMMdd-HHmmss') + '.txt')

    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }

    [System.IO.File]::WriteAllText($dialog.FileName, $script:LogTextBox.Text)
    Append-Log -Text ('Saved log to ' + $dialog.FileName) -Color ([System.Drawing.Color]::DarkGreen)
}

function Copy-LastCommand {
    if (-not [string]::IsNullOrWhiteSpace($script:LastCommandSummary)) {
        [System.Windows.Forms.Clipboard]::SetText($script:LastCommandSummary)
        Append-Log -Text 'Copied last command summary to clipboard.' -Color ([System.Drawing.Color]::DarkGreen)
    }
}

function Set-HelpExamples {
    if (-not $script:HelpTextBox) { return }

    $script:HelpTextBox.Text = @"
Git Glide GUI - Enhanced Version v$($script:AppVersion)
====================================

Configuration
-------------
Settings are stored in: $script:ConfigPath

Current settings:
- Base branch: $($script:Config.BaseBranch)
- Main branch: $($script:Config.MainBranch)
- Feature prefix: $($script:Config.FeatureBranchPrefix)
- Max history lines: $($script:Config.MaxHistoryLines)
- Commit subject max: $($script:Config.CommitSubjectMaxLength)

Typical workflow
----------------
1. Create feature branch from $($script:Config.BaseBranch)
2. Make changes
3. Stage selected or stage all
4. Write a commit subject and optional multiline body
5. Commit or Commit + push
6. Merge feature -> $($script:Config.BaseBranch)
7. Optionally merge $($script:Config.BaseBranch) -> $($script:Config.MainBranch)
8. Tag release outside this GUI or in a later iteration

Suggested branch names
----------------------
$($script:Config.FeatureBranchPrefix)v34-3-trust-observability-local-first
$($script:Config.HotfixBranchPrefix)v34-1-httpserver-logger-build-fix
$($script:Config.RefactorBranchPrefix)v34-2-3-restore-controller

Suggested commit subjects
-------------------------
v34.3: add trust, observability, and local-first foundation
v34.2.3: extract restore live-job orchestration into restoreController
v34.1.1: fix HttpServer logger calls for MinGW build

Suggested commit body style
---------------------------
- add restoreController.js
- move restore stream and polling orchestration out of app.js
- keep restore UI behavior unchanged
- add focused JS tests for restore controller behavior

Keyboard shortcuts
------------------
F5           - Refresh status
Ctrl+D       - Show diff
Ctrl+S       - Stage selected
Ctrl+U       - Unstage selected
Ctrl+Shift+S - Stage all
Ctrl+Enter   - Commit
Ctrl+P       - Push

New features in this version
-----------------------------
✓ Input validation for branch names and commits
✓ Configuration file support
✓ Progress indicators for long operations
✓ Cancel button for running operations
✓ Stash management panel with show/apply/pop/drop/branch/clear buttons
✓ Improved error messages
✓ Fixed Quote-Arg escaping bug
✓ Better git state verification
✓ Configurable branch names
✓ Commit subject length warnings
✓ Robust diff preview for staged, unstaged, renamed, deleted, conflicted, and untracked files
✓ Saved window size and splitter positions between sessions
✓ Richer tooltips with explanation before command preview
✓ Custom Git tab with visible create/update/remove controls and saved user-defined command buttons
✓ Appearance tab with persistent per-section colors
✓ Resizable repository/header, main work area, changed-file action, and log action sections
✓ Adaptive repository status rows and proportional action footers
✓ Functional Tags / Release tab for annotated tags, push, delete, checkout, and branch-from-tag
✓ Undo last commit safely with git reset --soft HEAD~1
✓ Audit log written to GitGlideGUI-Audit.log with command, exit code, and duration
✓ Safer custom Git command validation and confirmation for potentially destructive commands

Notes
-----
- Hover a button to see what it does first, then the exact commands in the Preview tab.
- The Output tab shows live stdout/stderr and exit codes.
- If you use Amend + Push, the GUI uses:
  git push --force-with-lease
  for safety (configurable).
- You can cancel long-running operations using the Cancel button.
- Use the Stash tab to save and restore work in progress.
- Drag visible splitters vertically or horizontally; the layout is saved on close and restored next time. The splitter between the upper workflow area and lower changed-files/diff/log area is now visible and persistent.
"@
}

function Set-SafeSplitterDistance {
    param(
        [System.Windows.Forms.SplitContainer]$Splitter,
        [int]$Distance,
        [int]$FallbackDistance = 300
    )
    if (-not $Splitter) { return }

    try {
        $available = if ($Splitter.Orientation -eq [System.Windows.Forms.Orientation]::Vertical) { $Splitter.Width } else { $Splitter.Height }
        if ($available -le 0) { return }

        $min = [Math]::Max(0, $Splitter.Panel1MinSize)
        $max = [Math]::Max($min, $available - $Splitter.Panel2MinSize - $Splitter.SplitterWidth)
        if ($max -lt $min) { return }

        $candidate = if ($Distance -gt 0) { $Distance } else { $FallbackDistance }
        $candidate = [Math]::Max($min, [Math]::Min($candidate, $max))
        $Splitter.SplitterDistance = $candidate
    } catch {
        Append-Log -Text ('Could not apply saved splitter distance: ' + $_.Exception.Message) -Color ([System.Drawing.Color]::DarkOrange)
    }
}

function Apply-SavedLayout {
    if (-not (Get-ConfigBool -Name 'RememberWindowLayout' -DefaultValue $true)) { return }

    Set-SafeSplitterDistance -Splitter $script:MainWorkSplit -Distance (Get-ConfigInt -Name 'MainWorkSplitDistance' -DefaultValue 470) -FallbackDistance 470
    Set-SafeSplitterDistance -Splitter $script:RootTopSplit -Distance (Get-ConfigInt -Name 'RootTopSplitDistance' -DefaultValue 38) -FallbackDistance 38
    Set-SafeSplitterDistance -Splitter $script:HeaderTopAreaSplit -Distance (Get-ConfigInt -Name 'HeaderTopAreaSplitDistance' -DefaultValue 120) -FallbackDistance 120
    Set-SafeSplitterDistance -Splitter $script:TopSplit -Distance (Get-ConfigInt -Name 'TopSplitDistance' -DefaultValue 650) -FallbackDistance 650
    Set-SafeSplitterDistance -Splitter $script:TopLeftSplit -Distance (Get-ConfigInt -Name 'TopLeftSplitDistance' -DefaultValue 185) -FallbackDistance 185
    Set-SafeSplitterDistance -Splitter $script:CommitPreviewSplit -Distance (Get-ConfigInt -Name 'CommitPreviewSplitDistance' -DefaultValue 470) -FallbackDistance 470
    Set-SafeSplitterDistance -Splitter $script:ContentSplit -Distance (Get-ConfigInt -Name 'ContentSplitDistance' -DefaultValue 430) -FallbackDistance 430
    Set-SafeSplitterDistance -Splitter $script:RightSplit -Distance (Get-ConfigInt -Name 'RightSplitDistance' -DefaultValue 250) -FallbackDistance 250
    Set-SafeSplitterDistance -Splitter $script:ChangedFilesActionSplit -Distance (Get-ConfigInt -Name 'ChangedFilesActionSplitDistance' -DefaultValue 520) -FallbackDistance 520
    Set-SafeSplitterDistance -Splitter $script:LogActionSplit -Distance (Get-ConfigInt -Name 'LogActionSplitDistance' -DefaultValue 245) -FallbackDistance 245
    Set-SafeSplitterDistance -Splitter $script:AppearanceMainSplit -Distance (Get-ConfigInt -Name 'AppearanceSplitDistance' -DefaultValue 280) -FallbackDistance 280
}

function Save-LayoutConfig {
    if (-not (Get-ConfigBool -Name 'RememberWindowLayout' -DefaultValue $true)) { return }

    try {
        if ($form.WindowState -eq [System.Windows.Forms.FormWindowState]::Normal) {
            Set-ConfigValue -Name 'WindowWidth' -Value ([int]$form.Width)
            Set-ConfigValue -Name 'WindowHeight' -Value ([int]$form.Height)
        }
        if ($script:RootTopSplit) { Set-ConfigValue -Name 'RootTopSplitDistance' -Value ([int]$script:RootTopSplit.SplitterDistance) }
        if ($script:MainWorkSplit) { Set-ConfigValue -Name 'MainWorkSplitDistance' -Value ([int]$script:MainWorkSplit.SplitterDistance) }
        if ($script:HeaderTopAreaSplit) { Set-ConfigValue -Name 'HeaderTopAreaSplitDistance' -Value ([int]$script:HeaderTopAreaSplit.SplitterDistance) }
        if ($script:TopSplit) { Set-ConfigValue -Name 'TopSplitDistance' -Value ([int]$script:TopSplit.SplitterDistance) }
        if ($script:TopLeftSplit) { Set-ConfigValue -Name 'TopLeftSplitDistance' -Value ([int]$script:TopLeftSplit.SplitterDistance) }
        if ($script:CommitPreviewSplit) { Set-ConfigValue -Name 'CommitPreviewSplitDistance' -Value ([int]$script:CommitPreviewSplit.SplitterDistance) }
        if ($script:ContentSplit) { Set-ConfigValue -Name 'ContentSplitDistance' -Value ([int]$script:ContentSplit.SplitterDistance) }
        if ($script:RightSplit) { Set-ConfigValue -Name 'RightSplitDistance' -Value ([int]$script:RightSplit.SplitterDistance) }
        if ($script:ChangedFilesActionSplit) { Set-ConfigValue -Name 'ChangedFilesActionSplitDistance' -Value ([int]$script:ChangedFilesActionSplit.SplitterDistance) }
        if ($script:LogActionSplit) { Set-ConfigValue -Name 'LogActionSplitDistance' -Value ([int]$script:LogActionSplit.SplitterDistance) }
        if ($script:AppearanceMainSplit) { Set-ConfigValue -Name 'AppearanceSplitDistance' -Value ([int]$script:AppearanceMainSplit.SplitterDistance) }
        Save-Config -Config $script:Config
    } catch {
        Write-Warning "Failed to save layout config: $_"
    }
}

# v3.9.1: Branch Cleanup Assistant
# Keeps branch cleanup visible, previewable, and confirmation-based.

function Get-BranchCleanupSelectedLocalBranch {
    if ($script:BranchCleanupLocalComboBox -and $script:BranchCleanupLocalComboBox.Text) {
        return ([string]$script:BranchCleanupLocalComboBox.Text).Trim()
    }

    return ''
}

function Get-BranchCleanupSelectedRemoteBranch {
    if ($script:BranchCleanupRemoteComboBox -and $script:BranchCleanupRemoteComboBox.Text) {
        return ([string]$script:BranchCleanupRemoteComboBox.Text).Trim()
    }

    return ''
}

function Invoke-BranchCleanupGitText {
    param([object]$Plan)

    if (-not $Plan -or -not $Plan.Arguments) { return '' }

    $result = Run-External `
        -FileName 'git' `
        -Arguments (@('-C', $script:RepoRoot) + @($Plan.Arguments)) `
        -Caption ([string]$Plan.Display) `
        -AllowFailure `
        -QuietOutput

    if ($result.ExitCode -ne 0) { return '' }

    return [string]$result.StdOut
}

function Refresh-BranchCleanupAssistant {
    try {
        if (-not (Test-GitRepository)) {
            [System.Windows.Forms.MessageBox]::Show(
                'Open a Git repository first.',
                'No repository',
                'OK',
                'Information'
            ) | Out-Null
            return
        }

        $remoteName = if ($script:Config.ContainsKey('DefaultRemoteName')) {
            [string]$script:Config.DefaultRemoteName
        } else {
            'origin'
        }

        $mainBranch = if ($script:Config.ContainsKey('MainBranch')) {
            [string]$script:Config.MainBranch
        } else {
            'main'
        }

        $baseBranch = if ($script:Config.ContainsKey('BaseBranch')) {
            [string]$script:Config.BaseBranch
        } else {
            'develop'
        }

        $currentBranch = if ($script:CurrentBranch) {
            [string]$script:CurrentBranch
        } else {
            ''
        }

        $branchText = Invoke-BranchCleanupGitText -Plan (Get-GgbcBranchVerboseCommandPlan)
        $remoteText = Invoke-BranchCleanupGitText -Plan (Get-GgbcRemoteBranchesCommandPlan)
        $mergedMainText = Invoke-BranchCleanupGitText -Plan (Get-GgbcMergedLocalBranchesCommandPlan -BaseBranch $mainBranch)
        $mergedDevelopText = Invoke-BranchCleanupGitText -Plan (Get-GgbcMergedLocalBranchesCommandPlan -BaseBranch $baseBranch)

        $localBranches = @(ConvertFrom-GgbcBranchVerboseText -Text $branchText)
        $remoteBranches = @(ConvertFrom-GgbcRemoteBranchText -Text $remoteText -RemoteName $remoteName)
        $remoteNames = @($remoteBranches | ForEach-Object { [string]$_.Name })

        $mergedMain = @(ConvertFrom-GgbcMergedBranchText -Text $mergedMainText)
        $mergedDevelop = @(ConvertFrom-GgbcMergedBranchText -Text $mergedDevelopText)

        $candidates = @()
        foreach ($branch in $localBranches) {
            $candidates += Get-GgbcBranchCleanupCandidate `
                -BranchName ([string]$branch.Name) `
                -MergedIntoMain $mergedMain `
                -MergedIntoDevelop $mergedDevelop `
                -RemoteBranches $remoteNames `
                -MainBranch $mainBranch `
                -BaseBranch $baseBranch `
                -CurrentBranch $currentBranch
        }

        $summary = Format-GgbcBranchCleanupSummary -Candidates $candidates -RemoteCandidates $remoteBranches

        if ($script:BranchCleanupLocalComboBox) {
            $script:BranchCleanupLocalComboBox.Items.Clear()

            foreach ($candidate in @($candidates | Where-Object { $_.Recommendation -eq 'safe-delete' })) {
                [void]$script:BranchCleanupLocalComboBox.Items.Add([string]$candidate.Branch)
            }

            if ($script:BranchCleanupLocalComboBox.Items.Count -gt 0) {
                $script:BranchCleanupLocalComboBox.SelectedIndex = 0
            }
        }

        if ($script:BranchCleanupRemoteComboBox) {
            $script:BranchCleanupRemoteComboBox.Items.Clear()

            foreach ($remote in $remoteBranches) {
                if (-not (Test-GgbcProtectedBranch -BranchName ([string]$remote.Name) -MainBranch $mainBranch -BaseBranch $baseBranch)) {
                    [void]$script:BranchCleanupRemoteComboBox.Items.Add([string]$remote.Name)
                }
            }

            if ($script:BranchCleanupRemoteComboBox.Items.Count -gt 0) {
                $script:BranchCleanupRemoteComboBox.SelectedIndex = 0
            }
        }

        if ($script:BranchCleanupTextBox) {
            $script:BranchCleanupTextBox.Text = $summary
        } elseif ($script:RecoveryTextBox) {
            $script:RecoveryTextBox.Text = $summary
        }

        Set-CommandPreview `
            -Title 'Branch Cleanup Assistant' `
            -Commands "git branch -vv`r`ngit branch -r`r`ngit branch --merged $mainBranch`r`ngit branch --merged $baseBranch" `
            -Notes 'Read-only branch hygiene refresh. Delete actions require separate confirmation.'
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message,
            'Branch cleanup refresh failed',
            'OK',
            'Error'
        ) | Out-Null
    }
}

function Show-BranchCleanupAssistant {
    Refresh-BranchCleanupAssistant
}

function Invoke-BranchCleanupFetchPrune {
    try {
        $remoteName = if ($script:Config.ContainsKey('DefaultRemoteName')) {
            [string]$script:Config.DefaultRemoteName
        } else {
            'origin'
        }

        $plan = Get-GgbcFetchPruneCommandPlan -RemoteName $remoteName

        $ok = Confirm-GuiAction `
            -Title 'Fetch and prune remote-tracking refs' `
            -Message ("Run:`r`n`r`n$($plan.CommandLine)`r`n`r`nThis updates remote-tracking refs and removes stale tracking refs. It does not delete remote branches.") `
            -Icon ([System.Windows.Forms.MessageBoxIcon]::Question)

        if (-not $ok) { return }

        $result = Run-External `
            -FileName 'git' `
            -Arguments (@('-C', $script:RepoRoot) + @($plan.Arguments)) `
            -Caption ([string]$plan.Display) `
            -AllowFailure

        if ($result.ExitCode -ne 0) {
            Show-GitFailureGuidance -Result $result -Operation 'fetch prune' -ShowDialog
            return
        }

        Refresh-BranchCleanupAssistant
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message,
            'Fetch prune failed',
            'OK',
            'Error'
        ) | Out-Null
    }
}

function Invoke-BranchCleanupDeleteSelectedLocal {
    try {
        $branch = Get-BranchCleanupSelectedLocalBranch

        if ([string]::IsNullOrWhiteSpace($branch)) {
            [System.Windows.Forms.MessageBox]::Show(
                'Select or type a local branch first.',
                'No local branch selected',
                'OK',
                'Information'
            ) | Out-Null
            return
        }

        $plan = Get-GgbcDeleteLocalBranchCommandPlan `
            -BranchName $branch `
            -MainBranch ([string]$script:Config.MainBranch) `
            -BaseBranch ([string]$script:Config.BaseBranch) `
            -CurrentBranch ([string]$script:CurrentBranch)

        $ok = Confirm-GuiAction `
            -Title 'Delete local branch' `
            -Message ("Delete local branch?`r`n`r`n$branch`r`n`r`nCommand:`r`n$($plan.CommandLine)") `
            -Icon ([System.Windows.Forms.MessageBoxIcon]::Warning)

        if (-not $ok) { return }

        $result = Run-External `
            -FileName 'git' `
            -Arguments (@('-C', $script:RepoRoot) + @($plan.Arguments)) `
            -Caption ([string]$plan.Display) `
            -AllowFailure

        if ($result.ExitCode -ne 0) {
            Show-GitFailureGuidance -Result $result -Operation 'delete local branch' -ShowDialog
            return
        }

        Refresh-BranchCleanupAssistant
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message,
            'Delete local branch failed',
            'OK',
            'Error'
        ) | Out-Null
    }
}

function Invoke-BranchCleanupDeleteSelectedRemote {
    try {
        $branch = Get-BranchCleanupSelectedRemoteBranch

        if ([string]::IsNullOrWhiteSpace($branch)) {
            [System.Windows.Forms.MessageBox]::Show(
                'Select or type a remote branch first.',
                'No remote branch selected',
                'OK',
                'Information'
            ) | Out-Null
            return
        }

        $remoteName = if ($script:Config.ContainsKey('DefaultRemoteName')) {
            [string]$script:Config.DefaultRemoteName
        } else {
            'origin'
        }

        $plan = Get-GgbcDeleteRemoteBranchCommandPlan `
            -BranchName $branch `
            -RemoteName $remoteName `
            -MainBranch ([string]$script:Config.MainBranch) `
            -BaseBranch ([string]$script:Config.BaseBranch)

        $ok = Confirm-GuiAction `
            -Title 'Delete remote branch' `
            -Message ("Delete remote branch?`r`n`r`n$remoteName/$branch`r`n`r`nCommand:`r`n$($plan.CommandLine)`r`n`r`nThis affects the shared remote repository.") `
            -Icon ([System.Windows.Forms.MessageBoxIcon]::Warning)

        if (-not $ok) { return }

        $result = Run-External `
            -FileName 'git' `
            -Arguments (@('-C', $script:RepoRoot) + @($plan.Arguments)) `
            -Caption ([string]$plan.Display) `
            -AllowFailure

        if ($result.ExitCode -ne 0) {
            Show-GitFailureGuidance -Result $result -Operation 'delete remote branch' -ShowDialog
            return
        }

        Refresh-BranchCleanupAssistant
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message,
            'Delete remote branch failed',
            'OK',
            'Error'
        ) | Out-Null
    }
}

#endregion
