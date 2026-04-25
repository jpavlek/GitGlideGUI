<#
GitCherryPickOperations.psm1
UI-free cherry-pick helpers for Git Glide GUI.
#>

Set-StrictMode -Version 2.0

function ConvertTo-GgcpQuotedGitArgument {
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

function New-GgcpGitCommandPlan {
    param(
        [Parameter(Mandatory=$true)][string]$Verb,
        [Parameter(Mandatory=$true)][object[]]$Arguments,
        [string]$Description = '',
        [string]$Display = ''
    )

    $argsArray = @($Arguments | ForEach-Object { [string]$_ })
    if ([string]::IsNullOrWhiteSpace($Display)) {
        $Display = 'git ' + (($argsArray | ForEach-Object { ConvertTo-GgcpQuotedGitArgument ([string]$_) }) -join ' ')
    }
    return [pscustomobject]@{
        FileName = 'git'
        Verb = $Verb
        Arguments = @($argsArray)
        Display = $Display
        Description = $Description
    }
}

function ConvertTo-GgcpCommandPreview {
    param([object[]]$Plans)
    $plansArray = @($Plans | Where-Object { $_ })
    if (@($plansArray).Count -eq 0) { return 'git cherry-pick <commit>' }
    return (($plansArray | ForEach-Object { [string]$_.Display }) -join "`r`n")
}

function Test-GgcpCommitish {
    param([AllowNull()][string]$Commitish)

    $value = if ($null -eq $Commitish) { '' } else { $Commitish.Trim() }
    if ([string]::IsNullOrWhiteSpace($value)) { return [pscustomobject]@{ Valid = $false; Error = 'Commit hash or ref cannot be empty.' } }
    if ($value -match '[\r\n;&|<>`]' -or $value -match '\.\.' -or $value -match '@\{') { return [pscustomobject]@{ Valid = $false; Error = 'Commit hash/ref contains unsafe characters for a cherry-pick operation.' } }
    if ($value.Length -gt 255) { return [pscustomobject]@{ Valid = $false; Error = 'Commit hash/ref is too long.' } }
    return [pscustomobject]@{ Valid = $true; Error = '' }
}

function Get-GgcpCherryPickCommandPlan {
    param(
        [Parameter(Mandatory=$true)][string]$Commitish,
        [switch]$NoCommit,
        [switch]$Mainline,
        [int]$MainlineParent = 1
    )

    $validation = Test-GgcpCommitish -Commitish $Commitish
    if (-not $validation.Valid) { throw $validation.Error }
    $args = @('cherry-pick')
    if ($NoCommit) { $args += '--no-commit' }
    if ($Mainline) { $args += @('-m', [string]([Math]::Max(1, $MainlineParent))) }
    $args += $Commitish.Trim()
    return New-GgcpGitCommandPlan -Verb 'cherry-pick' -Arguments $args -Description 'Apply one selected commit onto the current branch.'
}

function Get-GgcpCherryPickContinueCommandPlan {
    return New-GgcpGitCommandPlan -Verb 'cherry-pick-continue' -Arguments @('cherry-pick','--continue') -Description 'Continue cherry-pick after resolving and staging conflicts.'
}

function Get-GgcpCherryPickAbortCommandPlan {
    return New-GgcpGitCommandPlan -Verb 'cherry-pick-abort' -Arguments @('cherry-pick','--abort') -Description 'Abort an in-progress cherry-pick.'
}

function Get-GgcpCherryPickSkipCommandPlan {
    return New-GgcpGitCommandPlan -Verb 'cherry-pick-skip' -Arguments @('cherry-pick','--skip') -Description 'Skip the current commit during a multi-commit cherry-pick.'
}

function Get-GgcpSelectedCommitFromHistoryLine {
    param([AllowNull()][string]$Line)
    if ([string]::IsNullOrWhiteSpace($Line)) { return '' }
    if ($Line -match '(?<hash>[0-9a-fA-F]{7,40})') { return $matches['hash'] }
    return ''
}

Export-ModuleMember -Function `
    ConvertTo-GgcpQuotedGitArgument, `
    New-GgcpGitCommandPlan, `
    ConvertTo-GgcpCommandPreview, `
    Test-GgcpCommitish, `
    Get-GgcpCherryPickCommandPlan, `
    Get-GgcpCherryPickContinueCommandPlan, `
    Get-GgcpCherryPickAbortCommandPlan, `
    Get-GgcpCherryPickSkipCommandPlan, `
    Get-GgcpSelectedCommitFromHistoryLine
