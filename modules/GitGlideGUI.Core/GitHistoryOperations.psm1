<#
GitHistoryOperations.psm1
UI-free history/graph helpers for Git Glide GUI.

This module prepares read-only history command plans and parses compact Git log
records into graph-ready objects. The WinForms UI can display the graph text now,
while later versions can use the parsed model for a richer visual graph.
#>

Set-StrictMode -Version 2.0

function ConvertTo-GghQuotedGitArgument {
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

function New-GghGitCommandPlan {
    param(
        [Parameter(Mandatory=$true)][string]$Verb,
        [Parameter(Mandatory=$true)][object[]]$Arguments,
        [string]$Description = '',
        [string]$Display = ''
    )

    $argsArray = @($Arguments | ForEach-Object { [string]$_ })
    if ([string]::IsNullOrWhiteSpace($Display)) {
        $Display = 'git ' + (($argsArray | ForEach-Object { ConvertTo-GghQuotedGitArgument ([string]$_) }) -join ' ')
    }

    return [pscustomobject]@{
        FileName = 'git'
        Verb = $Verb
        Arguments = @($argsArray)
        Display = $Display
        Description = $Description
    }
}

function ConvertTo-GghCommandPreview {
    param([object[]]$Plans)
    $plansArray = @($Plans | Where-Object { $_ })
    if (@($plansArray).Count -eq 0) { return 'git log --graph --decorate --oneline --all' }
    return (($plansArray | ForEach-Object { [string]$_.Display }) -join "`r`n")
}

function Get-GghGraphCommandPlan {
    param([int]$MaxCount = 80)
    if ($MaxCount -lt 1) { $MaxCount = 1 }
    if ($MaxCount -gt 1000) { $MaxCount = 1000 }
    return New-GghGitCommandPlan -Verb 'history-graph' -Arguments @('log','--graph','--decorate','--oneline','--all','-n',[string]$MaxCount) -Description 'Read a human-readable branch/history graph.'
}

function Get-GghHistoryModelCommandPlan {
    param([int]$MaxCount = 160)
    if ($MaxCount -lt 1) { $MaxCount = 1 }
    if ($MaxCount -gt 5000) { $MaxCount = 5000 }
    return New-GghGitCommandPlan -Verb 'history-model' -Arguments @('log',('--max-count=' + $MaxCount),'--date=iso-strict','--format=%H%x1f%P%x1f%an%x1f%ae%x1f%ad%x1f%D%x1f%s','--all') -Display ('git log --max-count=' + $MaxCount + ' --date=iso-strict --format=<graph-model-fields> --all') -Description 'Read compact commit records for graph/history analysis.'
}

function ConvertFrom-GghCommitLogLine {
    param([AllowNull()][string]$Line)

    if ([string]::IsNullOrWhiteSpace($Line)) { return $null }
    $parts = @($Line -split [char]0x1f, 7)
    if (@($parts).Count -lt 7) { return $null }

    $parents = @()
    if (-not [string]::IsNullOrWhiteSpace($parts[1])) {
        $parents = @($parts[1] -split ' ' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }

    $decorations = @()
    if (-not [string]::IsNullOrWhiteSpace($parts[5])) {
        $decorations = @($parts[5] -split ',\s*' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }

    $hash = [string]$parts[0]
    $shortHash = if ($hash.Length -gt 12) { $hash.Substring(0, 12) } else { $hash }
    $decorationModel = Get-GghDecorationModel -Decorations $decorations

    return [pscustomobject]@{
        Hash = $hash
        ShortHash = $shortHash
        Parents = @($parents)
        ParentCount = @($parents).Count
        IsMerge = (@($parents).Count -gt 1)
        AuthorName = $parts[2]
        AuthorEmail = $parts[3]
        AuthorDate = $parts[4]
        Decorations = @($decorations)
        DecorationModel = $decorationModel
        RefKind = [string]$decorationModel.RefKind
        IsHead = [bool]$decorationModel.IsHead
        HeadBranch = [string]$decorationModel.HeadBranch
        Branches = @($decorationModel.Branches)
        RemoteBranches = @($decorationModel.RemoteBranches)
        Tags = @($decorationModel.Tags)
        Subject = $parts[6]
    }
}

function ConvertFrom-GghCommitLog {
    param([AllowNull()][string[]]$Lines)
    $items = @()
    foreach ($line in @($Lines)) {
        $item = ConvertFrom-GghCommitLogLine -Line $line
        if ($item) { $items += $item }
    }
    return @($items)
}


function Get-GghDecorationModel {
    param([AllowNull()][string[]]$Decorations)

    $branches = New-Object System.Collections.Generic.List[string]
    $remoteBranches = New-Object System.Collections.Generic.List[string]
    $tags = New-Object System.Collections.Generic.List[string]
    $otherRefs = New-Object System.Collections.Generic.List[string]
    $isHead = $false
    $headBranch = ''

    foreach ($raw in @($Decorations)) {
        $decor = ([string]$raw).Trim()
        if ([string]::IsNullOrWhiteSpace($decor)) { continue }

        if ($decor -match '^HEAD\s*->\s*(.+)$') {
            $isHead = $true
            foreach ($target in @($Matches[1] -split ',\s*')) {
                $target = ([string]$target).Trim()
                if ([string]::IsNullOrWhiteSpace($target)) { continue }
                if ([string]::IsNullOrWhiteSpace($headBranch)) { $headBranch = $target }
                if ($target -match '^(origin|upstream)/.+') {
                    if (-not $remoteBranches.Contains($target)) { [void]$remoteBranches.Add($target) }
                } else {
                    if (-not $branches.Contains($target)) { [void]$branches.Add($target) }
                }
            }
            continue
        }

        if ($decor -eq 'HEAD') {
            $isHead = $true
            if (-not $otherRefs.Contains($decor)) { [void]$otherRefs.Add($decor) }
            continue
        }

        if ($decor -match '^tag:\s*(.+)$') {
            $tag = $Matches[1].Trim()
            if (-not [string]::IsNullOrWhiteSpace($tag) -and -not $tags.Contains($tag)) { [void]$tags.Add($tag) }
            continue
        }

        if ($decor -match '^(origin|upstream)/.+') {
            if (-not $remoteBranches.Contains($decor)) { [void]$remoteBranches.Add($decor) }
            continue
        }

        if ($decor -match '^[A-Za-z0-9._/-]+$') {
            if (-not $branches.Contains($decor)) { [void]$branches.Add($decor) }
            continue
        }

        if (-not $otherRefs.Contains($decor)) { [void]$otherRefs.Add($decor) }
    }

    $refKind = 'none'
    if ($isHead) { $refKind = 'head' }
    elseif (@($tags).Count -gt 0) { $refKind = 'tag' }
    elseif (@($branches).Count -gt 0) { $refKind = 'branch' }
    elseif (@($remoteBranches).Count -gt 0) { $refKind = 'remote' }
    elseif (@($otherRefs).Count -gt 0) { $refKind = 'other' }

    return [pscustomobject]@{
        IsHead = [bool]$isHead
        HeadBranch = $headBranch
        Branches = @($branches)
        RemoteBranches = @($remoteBranches)
        Tags = @($tags)
        OtherRefs = @($otherRefs)
        RefKind = $refKind
    }
}

function Format-GghRefSummary {
    param([Parameter(Mandatory=$true)][object]$DecorationModel)
    $parts = New-Object System.Collections.Generic.List[string]
    if ($DecorationModel.IsHead -and -not [string]::IsNullOrWhiteSpace([string]$DecorationModel.HeadBranch)) { [void]$parts.Add('HEAD -> ' + [string]$DecorationModel.HeadBranch) }
    foreach ($branch in @($DecorationModel.Branches)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$branch) -and ([string]$branch) -ne ([string]$DecorationModel.HeadBranch)) { [void]$parts.Add([string]$branch) }
    }
    foreach ($remote in @($DecorationModel.RemoteBranches)) { if (-not [string]::IsNullOrWhiteSpace([string]$remote)) { [void]$parts.Add([string]$remote) } }
    foreach ($tag in @($DecorationModel.Tags)) { if (-not [string]::IsNullOrWhiteSpace([string]$tag)) { [void]$parts.Add('tag: ' + [string]$tag) } }
    foreach ($other in @($DecorationModel.OtherRefs)) { if (-not [string]::IsNullOrWhiteSpace([string]$other)) { [void]$parts.Add([string]$other) } }
    return (@($parts) -join ', ')
}

function Format-GghHistorySummary {
    param([AllowNull()][object[]]$Commits)
    $items = @($Commits | Where-Object { $_ })
    if (@($items).Count -eq 0) { return 'No commits found.' }
    $mergeCount = @($items | Where-Object { $_.IsMerge }).Count
    $decoratedCount = @($items | Where-Object { @($_.Decorations).Count -gt 0 }).Count
    $headCount = @($items | Where-Object { $_.IsHead }).Count
    $tagCount = @($items | Where-Object { @($_.Tags).Count -gt 0 }).Count
    $remoteCount = @($items | Where-Object { @($_.RemoteBranches).Count -gt 0 }).Count
    return ('{0} commits loaded, {1} merge commits, {2} decorated commits/tags/heads, {3} HEAD rows, {4} tag rows, {5} remote rows.' -f @($items).Count, $mergeCount, $decoratedCount, $headCount, $tagCount, $remoteCount)
}

function Format-GghVisualGraphRow {
    param(
        [Parameter(Mandatory=$true)][object]$Commit,
        [int]$Index = 0
    )
    $kind = if ($Commit.IsMerge) { 'merge' } else { 'commit' }
    $model = if ($Commit.PSObject.Properties['DecorationModel'] -and $Commit.DecorationModel) { $Commit.DecorationModel } else { Get-GghDecorationModel -Decorations @($Commit.Decorations) }
    $refs = Format-GghRefSummary -DecorationModel $model
    $parents = (@($Commit.Parents) | ForEach-Object {
        $p = [string]$_
        if ($p.Length -gt 12) { $p.Substring(0,12) } else { $p }
    }) -join ' '

    $lane = '*'
    if ($Commit.IsMerge -and $model.IsHead) { $lane = 'HM' }
    elseif ($Commit.IsMerge) { $lane = 'M*' }
    elseif ($model.IsHead) { $lane = 'H*' }
    elseif (@($model.Tags).Count -gt 0) { $lane = 'T*' }
    elseif (@($model.RemoteBranches).Count -gt 0) { $lane = 'R*' }
    elseif (@($model.Branches).Count -gt 0) { $lane = 'B*' }
    elseif (($Index % 2) -ne 0) { $lane = '|*' }

    $hint = switch ([string]$model.RefKind) {
        'head' { 'current branch tip or checked-out HEAD' }
        'tag' { 'tagged release point' }
        'branch' { 'local branch tip' }
        'remote' { 'remote-tracking branch tip' }
        'other' { 'decorated ref' }
        default { 'ordinary commit' }
    }
    if ($Commit.IsMerge) { $hint = 'merge commit; inspect parents before reverting/cherry-picking' }

    return [pscustomobject]@{
        Lane = $lane
        Kind = $kind
        RefKind = [string]$model.RefKind
        Hash = [string]$Commit.ShortHash
        FullHash = [string]$Commit.Hash
        Parents = $parents
        Refs = $refs
        Branches = (@($model.Branches) -join ', ')
        Remotes = (@($model.RemoteBranches) -join ', ')
        Tags = (@($model.Tags) -join ', ')
        Author = [string]$Commit.AuthorName
        Date = [string]$Commit.AuthorDate
        Subject = [string]$Commit.Subject
        Hint = $hint
    }
}

function ConvertTo-GghVisualGraphRows {
    param([AllowNull()][object[]]$Commits)
    $rows = @()
    $index = 0
    foreach ($commit in @($Commits | Where-Object { $_ })) {
        $rows += (Format-GghVisualGraphRow -Commit $commit -Index $index)
        $index++
    }
    return @($rows)
}

Export-ModuleMember -Function `
    ConvertTo-GghQuotedGitArgument, `
    New-GghGitCommandPlan, `
    ConvertTo-GghCommandPreview, `
    Get-GghGraphCommandPlan, `
    Get-GghHistoryModelCommandPlan, `
    ConvertFrom-GghCommitLogLine, `
    ConvertFrom-GghCommitLog, `
    Format-GghHistorySummary, `
    Get-GghDecorationModel, `
    Format-GghRefSummary, `
    Format-GghVisualGraphRow, `
    ConvertTo-GghVisualGraphRows
