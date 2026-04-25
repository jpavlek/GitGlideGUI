<#
GitTagOperations.psm1
UI-free tag/release workflow helpers for Git Glide GUI.

The module builds command plans and safety guidance for release-tag operations
without calling WinForms. The GUI remains responsible for confirmations and
execution, while tests can validate tag behavior in temporary Git repositories.
#>

Set-StrictMode -Version 2.0

function ConvertTo-GgtQuotedArgument {
    param([AllowNull()][string]$Argument)

    if ($null -eq $Argument) { return '""' }
    if ($Argument -eq '') { return '""' }
    if ($Argument -notmatch '[\s"`;&|<>^]') { return $Argument }

    $builder = New-Object System.Text.StringBuilder
    [void]$builder.Append('"')
    $backslashes = 0
    foreach ($ch in $Argument.ToCharArray()) {
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

function New-GgtGitCommandPlan {
    param(
        [Parameter(Mandatory=$true)][string]$Verb,
        [Parameter(Mandatory=$true)][string[]]$Arguments,
        [string]$Description = '',
        [string]$Display = ''
    )

    $argsArray = @($Arguments | ForEach-Object { [string]$_ })
    if ([string]::IsNullOrWhiteSpace($Display)) {
        $Display = 'git ' + (($argsArray | ForEach-Object { ConvertTo-GgtQuotedArgument $_ }) -join ' ')
    }

    return [pscustomobject]@{
        FileName = 'git'
        Verb = $Verb
        Arguments = $argsArray
        Display = $Display
        Description = $Description
    }
}

function ConvertTo-GgtCommandPreview {
    param([object[]]$Plans)
    $plansArray = @($Plans | Where-Object { $_ })
    if (@($plansArray).Count -eq 0) { return 'git tag <command>' }
    return (($plansArray | ForEach-Object { [string]$_.Display }) -join "`r`n")
}

function Test-GgtTagName {
    param([AllowNull()][string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return [pscustomobject]@{ Valid = $false; Error = 'Tag name cannot be empty.' }
    }

    $trimmed = $Name.Trim()
    if ($trimmed -ne $Name) {
        return [pscustomobject]@{ Valid = $false; Error = 'Tag name cannot start or end with whitespace.' }
    }
    if ($Name -match '\s') {
        return [pscustomobject]@{ Valid = $false; Error = 'Tag name cannot contain spaces or whitespace.' }
    }
    if ($Name -match '[~^:?*\[\]\\]') {
        return [pscustomobject]@{ Valid = $false; Error = 'Tag name contains invalid Git reference characters: ~ ^ : ? * [ ] or backslash.' }
    }
    if ($Name -match '(^/|/$|//|\.\.|@\{|\.lock$|\.$|^\.|^-)') {
        return [pscustomobject]@{ Valid = $false; Error = 'Tag name format is invalid for a Git reference.' }
    }
    if ($Name -eq '@') {
        return [pscustomobject]@{ Valid = $false; Error = 'Tag name cannot be a single @ character.' }
    }
    if ($Name.Length -gt 255) {
        return [pscustomobject]@{ Valid = $false; Error = 'Tag name too long; use 255 characters or less.' }
    }

    return [pscustomobject]@{ Valid = $true; Error = '' }
}

function Get-GgtSelectedTagNameFromDisplayLine {
    param([AllowNull()][string]$DisplayLine)

    if ([string]::IsNullOrWhiteSpace($DisplayLine)) { return '' }
    $line = $DisplayLine.Trim()
    if ($line.StartsWith('(')) { return '' }
    if ($line -match '^([^|\s]+)') { return $Matches[1].Trim() }
    return ''
}

function Get-GgtTagListCommandPlan {
    return New-GgtGitCommandPlan -Verb 'list-tags' -Arguments @('tag', '--list', '--sort=-creatordate', '--format=%(refname:short) | %(objecttype) | %(creatordate:short) | %(subject)') -Display 'git tag --list --sort=-creatordate' -Description 'List release tags with lightweight/annotated tag metadata.'
}

function Get-GgtShowTagDetailsCommandPlan {
    param([Parameter(Mandatory=$true)][string]$TagName)
    return New-GgtGitCommandPlan -Verb 'show-tag-details' -Arguments @('show', '--no-patch', '--decorate', '--format=fuller', $TagName) -Description 'Show selected tag metadata without printing the full patch.'
}

function Get-GgtCreateAnnotatedTagCommandPlan {
    param(
        [Parameter(Mandatory=$true)][string]$TagName,
        [string]$Message = ''
    )

    if ([string]::IsNullOrWhiteSpace($Message)) { $Message = $TagName }
    return New-GgtGitCommandPlan -Verb 'create-annotated-tag' -Arguments @('tag', '-a', $TagName, '-m', $Message) -Display ('git tag -a ' + (ConvertTo-GgtQuotedArgument $TagName) + ' -m <message>') -Description 'Create an annotated release tag.'
}

function Get-GgtCreateLightweightTagCommandPlan {
    param([Parameter(Mandatory=$true)][string]$TagName)
    return New-GgtGitCommandPlan -Verb 'create-lightweight-tag' -Arguments @('tag', $TagName) -Description 'Create a lightweight tag.'
}

function Get-GgtCreateTagCommandPlan {
    param(
        [Parameter(Mandatory=$true)][string]$TagName,
        [string]$Message = '',
        [switch]$Annotated
    )

    if ($Annotated) { return Get-GgtCreateAnnotatedTagCommandPlan -TagName $TagName -Message $Message }
    return Get-GgtCreateLightweightTagCommandPlan -TagName $TagName
}

function Get-GgtVerifyTagDoesNotExistCommandPlan {
    param([Parameter(Mandatory=$true)][string]$TagName)
    return New-GgtGitCommandPlan -Verb 'verify-tag-missing' -Arguments @('rev-parse', '--verify', ('refs/tags/' + $TagName)) -Description 'Check whether the tag already exists before creating it.'
}

function Get-GgtPushTagCommandPlan {
    param([Parameter(Mandatory=$true)][string]$TagName)
    return New-GgtGitCommandPlan -Verb 'push-tag' -Arguments @('push', 'origin', $TagName) -Description 'Push one selected tag to origin.'
}

function Get-GgtPushAllTagsCommandPlan {
    return New-GgtGitCommandPlan -Verb 'push-all-tags' -Arguments @('push', 'origin', '--tags') -Description 'Push all local tags to origin. Use only when all local tags are intentional.'
}

function Get-GgtDeleteLocalTagCommandPlan {
    param([Parameter(Mandatory=$true)][string]$TagName)
    return New-GgtGitCommandPlan -Verb 'delete-local-tag' -Arguments @('tag', '-d', $TagName) -Description 'Delete the selected local tag.'
}

function Get-GgtDeleteRemoteTagCommandPlan {
    param([Parameter(Mandatory=$true)][string]$TagName)
    return New-GgtGitCommandPlan -Verb 'delete-remote-tag' -Arguments @('push', 'origin', '--delete', $TagName) -Description 'Delete the selected tag from origin.'
}

function Get-GgtCheckoutTagCommandPlan {
    param([Parameter(Mandatory=$true)][string]$TagName)
    return New-GgtGitCommandPlan -Verb 'checkout-tag' -Arguments @('checkout', $TagName) -Description 'Checkout a tag in detached HEAD state.'
}

function Get-GgtBranchFromTagCommandPlan {
    param(
        [Parameter(Mandatory=$true)][string]$BranchName,
        [Parameter(Mandatory=$true)][string]$TagName
    )
    return New-GgtGitCommandPlan -Verb 'branch-from-tag' -Arguments @('checkout', '-b', $BranchName, $TagName) -Description 'Create and switch to a branch from the selected tag.'
}

function Get-GgtTagDeleteSafetyGuidance {
    param(
        [Parameter(Mandatory=$true)][string]$TagName,
        [switch]$DeleteRemote
    )

    $plans = @(Get-GgtDeleteLocalTagCommandPlan -TagName $TagName)
    $severity = 'warning'
    $message = "Delete local tag '$TagName'? This removes the local release marker, but does not delete commits."
    $details = 'Recreate the tag manually if needed.'
    if ($DeleteRemote) {
        $plans += (Get-GgtDeleteRemoteTagCommandPlan -TagName $TagName)
        $severity = 'danger'
        $message = "Delete local and remote tag '$TagName'? Remote tag deletion affects teammates and automation."
        $details = 'Only delete a remote tag when the release marker is clearly wrong and the team expects it.'
    }

    return [pscustomobject]@{
        Severity = $severity
        Message = $message
        Details = $details
        Plans = @($plans)
        Preview = ConvertTo-GgtCommandPreview -Plans $plans
    }
}

Export-ModuleMember -Function `
    ConvertTo-GgtQuotedArgument, `
    New-GgtGitCommandPlan, `
    ConvertTo-GgtCommandPreview, `
    Test-GgtTagName, `
    Get-GgtSelectedTagNameFromDisplayLine, `
    Get-GgtTagListCommandPlan, `
    Get-GgtShowTagDetailsCommandPlan, `
    Get-GgtCreateAnnotatedTagCommandPlan, `
    Get-GgtCreateLightweightTagCommandPlan, `
    Get-GgtCreateTagCommandPlan, `
    Get-GgtVerifyTagDoesNotExistCommandPlan, `
    Get-GgtPushTagCommandPlan, `
    Get-GgtPushAllTagsCommandPlan, `
    Get-GgtDeleteLocalTagCommandPlan, `
    Get-GgtDeleteRemoteTagCommandPlan, `
    Get-GgtCheckoutTagCommandPlan, `
    Get-GgtBranchFromTagCommandPlan, `
    Get-GgtTagDeleteSafetyGuidance
