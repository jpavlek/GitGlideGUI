<#
GitHubOperations.psm1
UI-free GitHub publish helper functions for Git Glide GUI.

The WinForms layer owns dialogs and command execution. This module owns
validation, URL generation, privacy guidance text, and command previews.
#>

function Test-GghubOwnerName {
    param([string]$Owner)
    if ([string]::IsNullOrWhiteSpace($Owner)) { return $false }
    return ([string]$Owner) -match '^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$'
}

function Test-GghubRepositoryName {
    param([string]$Repository)
    if ([string]::IsNullOrWhiteSpace($Repository)) { return $false }
    return ([string]$Repository) -match '^[A-Za-z0-9._-]{1,100}$' -and ([string]$Repository) -notmatch '\.git$' -and ([string]$Repository) -notmatch '^\.'
}

function New-GghubRemoteUrl {
    param(
        [Parameter(Mandatory=$true)][string]$Owner,
        [Parameter(Mandatory=$true)][string]$Repository,
        [ValidateSet('HTTPS','SSH')][string]$Protocol = 'HTTPS'
    )

    $ownerText = ([string]$Owner).Trim()
    $repoText = ([string]$Repository).Trim()
    if (-not (Test-GghubOwnerName -Owner $ownerText)) { throw "Invalid GitHub owner or organization name: $ownerText" }
    if (-not (Test-GghubRepositoryName -Repository $repoText)) { throw "Invalid GitHub repository name: $repoText" }

    if ($Protocol -eq 'SSH') { return "git@github.com:$ownerText/$repoText.git" }
    return "https://github.com/$ownerText/$repoText.git"
}

function Get-GghubNewRepositoryUrl {
    return 'https://github.com/new'
}

function Get-GghubCopilotSettingsUrl {
    return 'https://github.com/settings/copilot'
}

function Get-GghubDefaultRepositoryDescription {
    return 'Git Glide GUI is a lightweight, privacy-first Windows Git interface for safer human and AI-assisted software development. It turns fast coding changes into clear versioning choices, helping developers stay in control and use their judgment with command previews, visual staging, recovery guidance, custom actions, and code & documentation checks.'
}

function Get-GghubPrivacyChecklist {
    param(
        [switch]$PrivateRepositoryRecommended,
        [switch]$ReviewCopilotTrainingOptOut
    )

    $lines = New-Object System.Collections.Generic.List[string]
    [void]$lines.Add('Create the GitHub repository before pushing from Git Glide GUI.')
    if ($PrivateRepositoryRecommended) {
        [void]$lines.Add('Use Private visibility for client, commercial, security-sensitive, or unfinished code.')
    } else {
        [void]$lines.Add('Use Public only when you intentionally want the source code visible to everyone.')
    }
    [void]$lines.Add('For an existing local repository, do not initialize the GitHub repository with README, .gitignore, or license.')
    [void]$lines.Add('Git Glide GUI only configures the local Git remote and push; GitHub visibility and AI settings remain GitHub account/repository settings.')
    if ($ReviewCopilotTrainingOptOut) {
        [void]$lines.Add('Review GitHub Copilot settings and opt out of AI training/data use where your GitHub plan allows it.')
    }
    return @($lines)
}

function Get-GghubPublishCommandPreview {
    param(
        [string]$Owner,
        [string]$Repository,
        [ValidateSet('HTTPS','SSH')][string]$Protocol = 'HTTPS',
        [string]$RemoteName = 'origin',
        [switch]$PushAfter
    )

    if ([string]::IsNullOrWhiteSpace($RemoteName)) { $RemoteName = 'origin' }
    $remoteUrl = '<github-remote-url>'
    try { $remoteUrl = New-GghubRemoteUrl -Owner $Owner -Repository $Repository -Protocol $Protocol } catch {}

    $lines = New-Object System.Collections.Generic.List[string]
    [void]$lines.Add('open https://github.com/new and create an empty repository')
    [void]$lines.Add("git remote add $RemoteName $remoteUrl")
    [void]$lines.Add("or: git remote set-url $RemoteName $remoteUrl")
    if ($PushAfter) { [void]$lines.Add("git push -u $RemoteName HEAD") }
    return ($lines -join "`r`n")
}

Export-ModuleMember -Function `
    Test-GghubOwnerName, `
    Test-GghubRepositoryName, `
    New-GghubRemoteUrl, `
    Get-GghubNewRepositoryUrl, `
    Get-GghubCopilotSettingsUrl, `
    Get-GghubDefaultRepositoryDescription, `
    Get-GghubPrivacyChecklist, `
    Get-GghubPublishCommandPreview
