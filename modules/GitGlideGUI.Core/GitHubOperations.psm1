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


function Get-GghubRemoteListCommandPlan {
    return [pscustomobject]@{ Arguments = @('remote','-v'); Display = 'git remote -v'; Description = 'Show configured Git remotes.' }
}

function Get-GghubCurrentBranchCommandPlan {
    return [pscustomobject]@{ Arguments = @('branch','--show-current'); Display = 'git branch --show-current'; Description = 'Show the current branch.' }
}

function Get-GghubUpstreamCommandPlan {
    return [pscustomobject]@{ Arguments = @('rev-parse','--abbrev-ref','--symbolic-full-name','@{u}'); Display = 'git rev-parse --abbrev-ref --symbolic-full-name @{u}'; Description = 'Show upstream tracking branch or fail when missing.' }
}

function Get-GghubRemoteAccessTestCommandPlan {
    param([string]$RemoteName = 'origin')
    if ([string]::IsNullOrWhiteSpace($RemoteName)) { $RemoteName = 'origin' }
    return [pscustomobject]@{ Arguments = @('ls-remote','--heads',$RemoteName); Display = "git ls-remote --heads $RemoteName"; Description = 'Test whether the remote can be reached and authenticated.' }
}

function Get-GghubSetUpstreamPushCommandPlan {
    param([string]$RemoteName = 'origin')
    if ([string]::IsNullOrWhiteSpace($RemoteName)) { $RemoteName = 'origin' }
    return [pscustomobject]@{ Arguments = @('push','-u',$RemoteName,'HEAD'); Display = "git push -u $RemoteName HEAD"; Description = 'Push the current branch and set upstream tracking.' }
}

function ConvertFrom-GghubRemoteList {
    param([string]$Text)

    # Use a plain PowerShell array instead of a generic .NET List here.
    # Windows PowerShell 5.1 can throw "Argument types do not match" when a
    # generic List[object] containing PSCustomObject values is returned through
    # a Pester 3 compatibility test run.
    $rows = @()
    foreach ($line in @(([string]$Text) -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line -match '^([^\s]+)\s+([^\s]+)\s+\((fetch|push)\)') {
            $rows += [pscustomobject]@{
                Name = [string]$Matches[1]
                Url = [string]$Matches[2]
                Direction = [string]$Matches[3]
            }
        }
    }
    return $rows
}

function Get-GghubRepositoryWebUrl {
    param([string]$RemoteUrl)
    $url = ([string]$RemoteUrl).Trim()
    if ($url -match '^https://github\.com/([^/]+)/(.+?)(?:\.git)?/?$') { return "https://github.com/$($Matches[1])/$($Matches[2])" }
    if ($url -match '^git@github\.com:([^/]+)/(.+?)(?:\.git)?$') { return "https://github.com/$($Matches[1])/$($Matches[2])" }
    return ''
}


function Get-GghubPullRequestUrlsFromText {
    param([AllowNull()][string]$Text)
    $urls = @()
    foreach ($match in [regex]::Matches([string]$Text, 'https://github\.com/[^\s]+/pull/new/[^\s]+')) {
        $value = ([string]$match.Value).TrimEnd('.', ',', ';', ')', ']')
        if ($urls -notcontains $value) { $urls += $value }
    }
    return @($urls)
}

function Get-GghubRemoteFailureGuidance {
    param(
        [int]$ExitCode = 1,
        [string]$StdOut = '',
        [string]$StdErr = '',
        [string]$RemoteName = 'origin',
        [string]$Operation = 'GitHub remote operation'
    )
    $text = (($StdOut + "`n" + $StdErr).Trim())
    $kind = 'remote-failure'
    $message = "The $Operation failed. Inspect the remote URL, authentication, and upstream branch."
    $steps = @('Run git remote -v.', 'Check that the GitHub owner and repository name are correct.', 'Check authentication and repository visibility.', "Retry with git push -u $RemoteName HEAD when ready.")
    $preview = "git remote -v`r`ngit branch --show-current`r`ngit rev-parse --abbrev-ref --symbolic-full-name @{u}`r`ngit ls-remote --heads $RemoteName`r`ngit push -u $RemoteName HEAD"

    if ($text -match 'Repository not found') {
        $kind = 'repository-not-found'
        $message = 'GitHub reported repository not found. The repository may not exist yet, the owner/name may be misspelled, it may be private, or your credentials may not have access.'
        $steps = @('Open GitHub and create the empty repository first.', 'Verify the owner and repository spelling in the remote URL.', 'If the repository is private, verify you are signed in with an account that has access.', 'Review HTTPS token/Git Credential Manager or SSH key authentication.', "Retry with git push -u $RemoteName HEAD.")
    } elseif ($text -match 'no upstream branch|has no upstream') {
        $kind = 'missing-upstream'
        $message = 'The current branch has no upstream tracking branch yet.'
        $steps = @("Run git push -u $RemoteName HEAD to push the current branch and set upstream.", 'After that, normal git push can be used for this branch.')
    } elseif ($text -match 'Authentication failed|could not read Username|Invalid username or password') {
        $kind = 'authentication-failed'
        $message = 'Git authentication failed. GitHub HTTPS pushes require Git Credential Manager or a personal access token, not an account password.'
        $steps = @('Sign in through Git Credential Manager when prompted.', 'For HTTPS, use a GitHub token where required.', 'For SSH, verify your SSH key is added to GitHub.', "Retry with git push -u $RemoteName HEAD.")
    } elseif ($text -match 'Permission denied \(publickey\)|Could not read from remote repository') {
        $kind = 'ssh-authentication-failed'
        $message = 'SSH access failed. The SSH key may be missing, not loaded, or not authorized for this GitHub account/repository.'
        $steps = @('Check ssh -T git@github.com.', 'Add or load the correct SSH key.', 'Verify the repository exists and your account has access.', "Retry with git push -u $RemoteName HEAD.")
    } elseif ($text -match 'remote .* already exists') {
        $kind = 'remote-exists'
        $message = 'The remote already exists. Update its URL instead of adding it again.'
        $steps = @("Run git remote set-url $RemoteName <url>.", 'Then test remote access and push with upstream if needed.')
    }

    return [pscustomobject]@{
        Kind = $kind
        Severity = 'warning'
        Title = 'GitHub remote guidance'
        Message = $message
        Details = $text
        RecoverySteps = @($steps)
        Preview = $preview
        ExitCode = $ExitCode
    }
}

Export-ModuleMember -Function `
    Test-GghubOwnerName, `
    Test-GghubRepositoryName, `
    New-GghubRemoteUrl, `
    Get-GghubNewRepositoryUrl, `
    Get-GghubCopilotSettingsUrl, `
    Get-GghubDefaultRepositoryDescription, `
    Get-GghubRemoteListCommandPlan, `
    Get-GghubCurrentBranchCommandPlan, `
    Get-GghubUpstreamCommandPlan, `
    Get-GghubRemoteAccessTestCommandPlan, `
    Get-GghubSetUpstreamPushCommandPlan, `
    ConvertFrom-GghubRemoteList, `
    Get-GghubRepositoryWebUrl, `
    Get-GghubPullRequestUrlsFromText, `
    Get-GghubRemoteFailureGuidance, `
    Get-GghubPrivacyChecklist, `
    Get-GghubPublishCommandPreview
