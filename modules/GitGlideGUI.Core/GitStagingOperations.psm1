<#
GitStagingOperations.psm1
UI-free staging and changed-file helpers for Git Glide GUI.

This module intentionally does not call WinForms. It builds predictable command
plans and text previews so the main GUI can execute them and tests can validate
behavior without launching the application.
#>

Set-StrictMode -Version 2.0

function ConvertTo-GggQuotedGitArgument {
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

function Get-GggStatusItemPath {
    param($Item)
    if ($null -eq $Item) { return '<selected-file>' }
    try {
        if ($Item.PSObject.Properties['Path'] -and -not [string]::IsNullOrWhiteSpace([string]$Item.Path)) { return [string]$Item.Path }
    } catch {}
    return '<selected-file>'
}

function Get-GggDiffTargetPaths {
    param($Item)

    $paths = New-Object System.Collections.Generic.List[string]
    if ($null -ne $Item) {
        try { if ($Item.PSObject.Properties['OriginalPath'] -and $Item.OriginalPath) { [void]$paths.Add([string]$Item.OriginalPath) } } catch {}
        try { if ($Item.PSObject.Properties['Path'] -and $Item.Path) { [void]$paths.Add([string]$Item.Path) } } catch {}
    }
    return @($paths | Select-Object -Unique)
}



function New-GggTrackedFileStatusItem {
    param([string]$Path)
    return [pscustomobject]@{
        Status = '  '
        IndexStatus = ' '
        WorkTreeStatus = ' '
        Path = [string]$Path
        RawPath = [string]$Path
        OriginalPath = $null
        IsTracked = $true
        IsCleanTracked = $true
    }
}

function ConvertFrom-GggTrackedFileList {
    param([AllowNull()][string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
    $items = @()
    foreach ($line in @($Text -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $items += (New-GggTrackedFileStatusItem -Path $line.Trim())
    }
    return @($items)
}

function Get-GggStatusDisplayText {
    param($Item)
    if ($null -eq $Item) { return '[unknown] <selected-file>' }
    $path = Get-GggStatusItemPath -Item $Item
    $status = try { [string]$Item.Status } catch { '' }
    if ($status -eq '??') { return ('[untracked] ' + $path) }
    $index = try { [string]$Item.IndexStatus } catch { ' ' }
    $work = try { [string]$Item.WorkTreeStatus } catch { ' ' }
    if ([string]::IsNullOrEmpty($index) -or $index -eq ' ') { $index = '-' }
    if ([string]::IsNullOrEmpty($work) -or $work -eq ' ') { $work = '-' }
    return ('[index:{0} work:{1}] {2}' -f $index, $work, $path)
}

function Get-GggStatusMeaning {
    param([string]$Status)

    switch ($Status) {
        '??' { return 'Untracked file. Git has not staged or compared it yet.' }
        default {
            if ([string]::IsNullOrEmpty($Status)) { return 'Changed file.' }
            $x = if ($Status.Length -ge 1) { $Status.Substring(0,1) } else { ' ' }
            $y = if ($Status.Length -ge 2) { $Status.Substring(1,1) } else { ' ' }
            $parts = New-Object System.Collections.Generic.List[string]
            switch ($x) {
                'M' { [void]$parts.Add('staged modification') }
                'A' { [void]$parts.Add('staged addition') }
                'D' { [void]$parts.Add('staged deletion') }
                'R' { [void]$parts.Add('staged rename') }
                'C' { [void]$parts.Add('staged copy') }
                'U' { [void]$parts.Add('staged conflict marker') }
            }
            switch ($y) {
                'M' { [void]$parts.Add('unstaged modification') }
                'D' { [void]$parts.Add('unstaged deletion') }
                'U' { [void]$parts.Add('working-tree conflict marker') }
            }
            if (@($parts).Count -eq 0) { return 'Changed file.' }
            return ($parts -join '; ') + '.'
        }
    }
}

function New-GggGitCommandPlan {
    param(
        [Parameter(Mandatory=$true)][string]$Verb,
        [Parameter(Mandatory=$true)][object[]]$Arguments,
        [string]$Description = ''
    )

    $display = 'git ' + (($Arguments | ForEach-Object { ConvertTo-GggQuotedGitArgument ([string]$_) }) -join ' ')
    return [pscustomobject]@{
        Verb = $Verb
        Arguments = @($Arguments)
        Display = $display
        Description = $Description
    }
}

function Get-GggStageSelectedCommandPlan {
    param([object[]]$Items)

    $itemsArray = @($Items | Where-Object { $_ })
    if (@($itemsArray).Count -eq 0) {
        return @(New-GggGitCommandPlan -Verb 'stage-selected' -Arguments @('add','--','<selected-file>') -Description 'Stage the selected file.')
    }
    return @($itemsArray | ForEach-Object {
        New-GggGitCommandPlan -Verb 'stage-selected' -Arguments @('add','--',(Get-GggStatusItemPath -Item $_)) -Description 'Stage the selected file.'
    })
}

function Get-GggUnstageSelectedCommandPlan {
    param(
        [object[]]$Items,
        [switch]$RepositoryHasNoCommits
    )

    $itemsArray = @($Items | Where-Object { $_ })
    $commandArgsForPath = {
        param([string]$Path)
        if ($RepositoryHasNoCommits) {
            return @('rm','--cached','--',$Path)
        }
        return @('restore','--staged','--',$Path)
    }

    if (@($itemsArray).Count -eq 0) {
        $gitArgs = & $commandArgsForPath '<selected-file>'
        return @(New-GggGitCommandPlan -Verb 'unstage-selected' -Arguments $gitArgs -Description 'Unstage the selected file but keep the working-tree file.')
    }
    return @($itemsArray | ForEach-Object {
        $path = Get-GggStatusItemPath -Item $_
        $gitArgs = & $commandArgsForPath $path
        New-GggGitCommandPlan -Verb 'unstage-selected' -Arguments $gitArgs -Description 'Unstage the selected file but keep the working-tree file.'
    })
}


function Get-GggRemoveFromGitCommandPlan {
    param([object[]]$Items)
    $itemsArray = @($Items | Where-Object { $_ })
    if (@($itemsArray).Count -eq 0) {
        return @(New-GggGitCommandPlan -Verb 'remove-from-git-and-disk' -Arguments @('rm','--','<selected-file>') -Description 'Remove the selected tracked file from Git and disk, staging the deletion.')
    }
    return @($itemsArray | ForEach-Object {
        New-GggGitCommandPlan -Verb 'remove-from-git-and-disk' -Arguments @('rm','--',(Get-GggStatusItemPath -Item $_)) -Description 'Remove the selected tracked file from Git and disk, staging the deletion.'
    })
}

function Get-GggStopTrackingCommandPlan {
    param([object[]]$Items)
    $itemsArray = @($Items | Where-Object { $_ })
    if (@($itemsArray).Count -eq 0) {
        return @(New-GggGitCommandPlan -Verb 'stop-tracking-keep-local' -Arguments @('rm','--cached','--','<selected-file>') -Description 'Remove the selected file from Git tracking while keeping the local working-tree file.')
    }
    return @($itemsArray | ForEach-Object {
        New-GggGitCommandPlan -Verb 'stop-tracking-keep-local' -Arguments @('rm','--cached','--',(Get-GggStatusItemPath -Item $_)) -Description 'Remove the selected file from Git tracking while keeping the local working-tree file.'
    })
}

function Get-GggStageAllCommandPlan {
    return @(New-GggGitCommandPlan -Verb 'stage-all' -Arguments @('add','-A') -Description 'Stage every changed, deleted, and untracked file in the repository.')
}

function ConvertTo-GggCommandPreview {
    param([object[]]$Plans)

    $plansArray = @($Plans | Where-Object { $_ })
    if (@($plansArray).Count -eq 0) { return 'git <command>' }
    return (($plansArray | ForEach-Object { [string]$_.Display }) -join "`r`n")
}

function Get-GggShowDiffCommandPreview {
    param($Item)

    if ($null -eq $Item) { return 'git diff HEAD -- <selected-file>' }

    $paths = @(Get-GggDiffTargetPaths -Item $Item)
    if (@($paths).Count -eq 0) { $paths = @('<selected-file>') }
    $quotedPaths = ($paths | ForEach-Object { ConvertTo-GggQuotedGitArgument ([string]$_) }) -join ' '

    $status = [string]$Item.Status
    if ($status -eq '??') { return "# untracked file preview for $quotedPaths" }

    $indexStatus = [string]$Item.IndexStatus
    $workTreeStatus = [string]$Item.WorkTreeStatus
    $commands = New-Object System.Collections.Generic.List[string]

    if ($indexStatus -ne ' ' -and $indexStatus -ne '?') {
        [void]$commands.Add('git diff --no-ext-diff --no-color --find-renames --cached -- ' + $quotedPaths)
    }
    if ($workTreeStatus -ne ' ' -and $workTreeStatus -ne '?') {
        [void]$commands.Add('git diff --no-ext-diff --no-color --find-renames -- ' + $quotedPaths)
    }
    if (@($commands).Count -eq 0) {
        [void]$commands.Add('git diff --no-ext-diff --no-color --find-renames HEAD -- ' + $quotedPaths)
    }
    return ($commands -join "`r`n")
}

Export-ModuleMember -Function `
    ConvertTo-GggQuotedGitArgument, `
    Get-GggStatusItemPath, `
    Get-GggDiffTargetPaths, `
    Get-GggStatusMeaning, `
    Get-GggStatusDisplayText, `
    New-GggTrackedFileStatusItem, `
    ConvertFrom-GggTrackedFileList, `
    New-GggGitCommandPlan, `
    Get-GggStageSelectedCommandPlan, `
    Get-GggUnstageSelectedCommandPlan, `
    Get-GggStageAllCommandPlan, `
    Get-GggRemoveFromGitCommandPlan, `
    Get-GggStopTrackingCommandPlan, `
    ConvertTo-GggCommandPreview, `
    Get-GggShowDiffCommandPreview
