Set-StrictMode -Version Latest

function ConvertTo-GgbcQuotedArgument {
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
            if ($backslashes -gt 0) { [void]$builder.Append(('\' * ($backslashes * 2))); $backslashes = 0 }
            [void]$builder.Append('\"')
            continue
        }
        if ($backslashes -gt 0) { [void]$builder.Append(('\' * $backslashes)); $backslashes = 0 }
        [void]$builder.Append($ch)
    }

    if ($backslashes -gt 0) { [void]$builder.Append(('\' * ($backslashes * 2))) }
    [void]$builder.Append('"')
    return $builder.ToString()
}

function Test-GgbcSafeBranchName {
    param([string]$BranchName)

    if ([string]::IsNullOrWhiteSpace($BranchName)) { return $false }
    if ($BranchName.StartsWith('-')) { return $false }
    if ($BranchName -match '[\s~^:?*\[\]\\]') { return $false }
    if ($BranchName -match '\.\.|^\.|\.$|@{|^/|/$|//|\.lock$') { return $false }
    if ($BranchName -match '(^|/)\.($|/)') { return $false }
    return $true
}

function ConvertFrom-GgbcRemoteBranchName {
    param([string]$RemoteBranch, [string]$RemoteName = 'origin')

    $name = ([string]$RemoteBranch).Trim()
    if ([string]::IsNullOrWhiteSpace($name)) { return '' }
    $prefix = "$RemoteName/"
    if ($name.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) { return $name.Substring($prefix.Length) }
    return $name
}

function Test-GgbcProtectedBranch {
    param([string]$BranchName, [string]$MainBranch = 'main', [string]$BaseBranch = 'develop', [string]$CurrentBranch = '')

    $name = ConvertFrom-GgbcRemoteBranchName -RemoteBranch $BranchName
    if ([string]::IsNullOrWhiteSpace($name)) { return $true }
    if ($name -ieq $MainBranch) { return $true }
    if ($name -ieq $BaseBranch) { return $true }
    if (-not [string]::IsNullOrWhiteSpace($CurrentBranch) -and $name -ieq $CurrentBranch) { return $true }
    if ($name -like 'release/*') { return $true }
    if ($name -like 'hotfix/*') { return $true }
    return $false
}

function New-GgbcCommandPlan {
    param([string[]]$Arguments, [string]$Description, [bool]$RequiresConfirmation = $false, [string]$Risk = 'read-only')

    $display = 'git ' + ((@($Arguments) | ForEach-Object { ConvertTo-GgbcQuotedArgument -Value ([string]$_) }) -join ' ')
    return [pscustomobject]@{
        Arguments = @($Arguments)
        CommandLine = $display
        Display = $display
        Description = $Description
        RequiresConfirmation = $RequiresConfirmation
        Risk = $Risk
    }
}

function Get-GgbcFetchPruneCommandPlan {
    param([string]$RemoteName = 'origin')
    if (-not (Test-GgbcSafeBranchName -BranchName $RemoteName)) { throw "Unsafe remote name: $RemoteName" }
    return New-GgbcCommandPlan -Arguments @('fetch', $RemoteName, '--prune') -Description 'Fetch remote refs and prune stale remote-tracking branches.' -RequiresConfirmation $false -Risk 'network-read'
}

function Get-GgbcBranchVerboseCommandPlan {
    return New-GgbcCommandPlan -Arguments @('branch', '-vv') -Description 'List local branches with upstream and ahead/behind information.'
}

function Get-GgbcRemoteBranchesCommandPlan {
    return New-GgbcCommandPlan -Arguments @('branch', '-r') -Description 'List remote-tracking branches.'
}

function Get-GgbcMergedLocalBranchesCommandPlan {
    param([string]$BaseBranch = 'main')
    if (-not (Test-GgbcSafeBranchName -BranchName $BaseBranch)) { throw "Unsafe base branch: $BaseBranch" }
    return New-GgbcCommandPlan -Arguments @('branch', '--merged', $BaseBranch) -Description "List local branches already merged into $BaseBranch."
}

function Get-GgbcMergedRemoteBranchesCommandPlan {
    param([string]$RemoteName = 'origin', [string]$BaseBranch = 'main')
    if (-not (Test-GgbcSafeBranchName -BranchName $RemoteName)) { throw "Unsafe remote name: $RemoteName" }
    if (-not (Test-GgbcSafeBranchName -BranchName $BaseBranch)) { throw "Unsafe base branch: $BaseBranch" }
    return New-GgbcCommandPlan -Arguments @('branch', '-r', '--merged', "$RemoteName/$BaseBranch") -Description "List remote branches already merged into $RemoteName/$BaseBranch."
}

function ConvertFrom-GgbcBranchVerboseLine {
    param([string]$Line)

    if ([string]::IsNullOrWhiteSpace($Line)) { return $null }

    $text = $Line.Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }

    $isCurrent = $false
    if ($text.StartsWith('*')) {
        $isCurrent = $true
        $text = $text.Substring(1).Trim()
    }

    # PowerShell 5.1 / .NET Framework compatible parsing.
    # Avoid StringSplitOptions.TrimEntries and avoid String.Split overload ambiguity.
    $match = [regex]::Match($text, '^(?<name>\S+)\s+(?<hash>\S+)(?:\s+(?<rest>.*))?$')
    if (-not $match.Success) { return $null }

    $name = $match.Groups['name'].Value.Trim()
    $hash = $match.Groups['hash'].Value.Trim()
    $rest = $match.Groups['rest'].Value.Trim()

    $upstream = ''
    $tracking = ''
    $subject = $rest

    if ($rest -match '^\[(?<inside>[^\]]+)\]\s*(?<subject>.*)$') {
        $inside = $Matches['inside']
        $subject = $Matches['subject']

        if ($inside -match '^(?<upstream>[^:]+):\s*(?<tracking>.*)$') {
            $upstream = $Matches['upstream'].Trim()
            $tracking = $Matches['tracking'].Trim()
        } else {
            $upstream = $inside.Trim()
        }
    }

    [pscustomobject]@{
        Name           = $name
        Hash           = $hash
        Upstream       = $upstream
        UpstreamStatus = $tracking
        Subject        = $subject
        IsCurrent      = $isCurrent
    }
}

function ConvertFrom-GgbcBranchVerboseText {
    param([string]$Text)
    $items = @()
    foreach ($line in @(([string]$Text) -split "`r?`n")) {
        $parsed = ConvertFrom-GgbcBranchVerboseLine -Line $line
        if ($null -ne $parsed) { $items += $parsed }
    }
    return @($items)
}

function ConvertFrom-GgbcRemoteBranchText {
    param([string]$Text, [string]$RemoteName = 'origin')
    $items = @()
    foreach ($line in @(([string]$Text) -split "`r?`n")) {
        $name = ([string]$line).Trim()
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        if ($name -match ' -> ') { continue }
        $shortName = ConvertFrom-GgbcRemoteBranchName -RemoteBranch $name -RemoteName $RemoteName
        if ([string]::IsNullOrWhiteSpace($shortName)) { continue }
        $items += [pscustomobject]@{ Name = $shortName; RemoteName = $RemoteName; RemoteBranch = $name }
    }
    return @($items)
}

function ConvertFrom-GgbcMergedBranchText {
    param([string]$Text, [switch]$Remote, [string]$RemoteName = 'origin')
    $items = @()
    foreach ($line in @(([string]$Text) -split "`r?`n")) {
        $name = ([string]$line).Trim()
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        if ($name.StartsWith('*')) { $name = $name.Substring(1).Trim() }
        if ($name -match ' -> ') { continue }
        if ($Remote) { $name = ConvertFrom-GgbcRemoteBranchName -RemoteBranch $name -RemoteName $RemoteName }
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        $items += $name
    }
    return @($items | Select-Object -Unique)
}

function Get-GgbcDeleteLocalBranchCommandPlan {
    param([string]$BranchName, [switch]$Force, [string]$MainBranch = 'main', [string]$BaseBranch = 'develop', [string]$CurrentBranch = '')
    if (-not (Test-GgbcSafeBranchName -BranchName $BranchName)) { throw "Unsafe local branch name: $BranchName" }
    if (Test-GgbcProtectedBranch -BranchName $BranchName -MainBranch $MainBranch -BaseBranch $BaseBranch -CurrentBranch $CurrentBranch) { throw "Protected branch cannot be deleted by this assistant: $BranchName" }
    $deleteFlag = if ($Force) { '-D' } else { '-d' }
    $risk = if ($Force) { 'destructive-force-delete-local-branch' } else { 'destructive-delete-local-branch-if-merged' }
    return New-GgbcCommandPlan -Arguments @('branch', $deleteFlag, $BranchName) -Description "Delete local branch $BranchName." -RequiresConfirmation $true -Risk $risk
}

function Get-GgbcDeleteRemoteBranchCommandPlan {
    param([string]$BranchName, [string]$RemoteName = 'origin', [string]$MainBranch = 'main', [string]$BaseBranch = 'develop')
    $shortName = ConvertFrom-GgbcRemoteBranchName -RemoteBranch $BranchName -RemoteName $RemoteName
    if (-not (Test-GgbcSafeBranchName -BranchName $RemoteName)) { throw "Unsafe remote name: $RemoteName" }
    if (-not (Test-GgbcSafeBranchName -BranchName $shortName)) { throw "Unsafe remote branch name: $BranchName" }
    if (Test-GgbcProtectedBranch -BranchName $shortName -MainBranch $MainBranch -BaseBranch $BaseBranch) { throw "Protected branch cannot be deleted by this assistant: $shortName" }
    return New-GgbcCommandPlan -Arguments @('push', $RemoteName, '--delete', $shortName) -Description "Delete remote branch $RemoteName/$shortName." -RequiresConfirmation $true -Risk 'destructive-delete-remote-branch'
}

function Get-GgbcBranchCleanupCandidate {
    param([string]$BranchName, [string[]]$MergedIntoMain = @(), [string[]]$MergedIntoDevelop = @(), [string[]]$RemoteBranches = @(), [string]$MainBranch = 'main', [string]$BaseBranch = 'develop', [string]$CurrentBranch = '')
    $protected = Test-GgbcProtectedBranch -BranchName $BranchName -MainBranch $MainBranch -BaseBranch $BaseBranch -CurrentBranch $CurrentBranch
    $mergedMain = @($MergedIntoMain) -contains $BranchName
    $mergedDevelop = @($MergedIntoDevelop) -contains $BranchName
    $hasRemote = @($RemoteBranches) -contains $BranchName
    $recommendation = 'review'
    $reason = 'Branch needs manual review before cleanup.'
    if ($protected) { $recommendation = 'keep'; $reason = 'Protected workflow branch or current branch.' }
    elseif ($mergedMain) { $recommendation = 'safe-delete'; $reason = 'Branch is already merged into main.' }
    elseif ($mergedDevelop) { $recommendation = 'wait-or-review'; $reason = 'Branch is merged into develop but not confirmed merged into main.' }
    elseif (-not $hasRemote) { $recommendation = 'local-only-review'; $reason = 'Local branch has no matching remote-tracking branch.' }
    return [pscustomobject]@{ Branch = $BranchName; Protected = [bool]$protected; MergedIntoMain = [bool]$mergedMain; MergedIntoDevelop = [bool]$mergedDevelop; HasRemote = [bool]$hasRemote; Recommendation = $recommendation; Reason = $reason }
}

function Format-GgbcBranchCleanupSummary {
    param([object[]]$Candidates, [object[]]$RemoteCandidates = @())
    $safeLocal = @($Candidates | Where-Object { $_.Recommendation -eq 'safe-delete' })
    $keepLocal = @($Candidates | Where-Object { $_.Recommendation -eq 'keep' })
    $reviewLocal = @($Candidates | Where-Object { $_.Recommendation -ne 'safe-delete' -and $_.Recommendation -ne 'keep' })
    $lines = @()
    $lines += 'Branch Cleanup and Remote Branch Hygiene Assistant'
    $lines += ''
    $lines += ('Local safe-delete candidates: {0}' -f $safeLocal.Count)
    $lines += ('Local protected/keep branches: {0}' -f $keepLocal.Count)
    $lines += ('Local review/wait candidates: {0}' -f $reviewLocal.Count)
    if (@($RemoteCandidates).Count -gt 0) { $lines += ('Remote candidates listed: {0}' -f @($RemoteCandidates).Count) }
    if ($safeLocal.Count -gt 0) {
        $lines += ''; $lines += 'Safe local delete candidates:'
        foreach ($candidate in $safeLocal | Select-Object -First 20) { $lines += ('- {0}: {1}' -f $candidate.Branch, $candidate.Reason) }
    }
    if ($reviewLocal.Count -gt 0) {
        $lines += ''; $lines += 'Needs review:'
        foreach ($candidate in $reviewLocal | Select-Object -First 20) { $lines += ('- {0}: {1}' -f $candidate.Branch, $candidate.Reason) }
    }
    return ($lines -join [Environment]::NewLine)
}

Export-ModuleMember -Function @(
    'ConvertTo-GgbcQuotedArgument', 'Test-GgbcSafeBranchName', 'ConvertFrom-GgbcRemoteBranchName', 'Test-GgbcProtectedBranch',
    'Get-GgbcFetchPruneCommandPlan', 'Get-GgbcBranchVerboseCommandPlan', 'Get-GgbcRemoteBranchesCommandPlan',
    'Get-GgbcMergedLocalBranchesCommandPlan', 'Get-GgbcMergedRemoteBranchesCommandPlan',
    'ConvertFrom-GgbcBranchVerboseLine', 'ConvertFrom-GgbcBranchVerboseText', 'ConvertFrom-GgbcRemoteBranchText', 'ConvertFrom-GgbcMergedBranchText',
    'Get-GgbcDeleteLocalBranchCommandPlan', 'Get-GgbcDeleteRemoteBranchCommandPlan', 'Get-GgbcBranchCleanupCandidate', 'Format-GgbcBranchCleanupSummary'
)
