# Pester tests for UI-free GitHub publish helpers.
$modulePath = Join-Path $PSScriptRoot '..\modules\GitGlideGUI.Core\GitHubOperations.psm1'
Import-Module $modulePath -Force

Describe 'GitHubOperations module' {
    It 'validates GitHub owner and repository names conservatively' {
        Test-GghubOwnerName -Owner 'jpavlek' | Should -BeTrue
        Test-GghubOwnerName -Owner 'my-org' | Should -BeTrue
        Test-GghubOwnerName -Owner '-bad' | Should -BeFalse
        Test-GghubRepositoryName -Repository 'GitGlideGUI' | Should -BeTrue
        Test-GghubRepositoryName -Repository 'repo.name_1' | Should -BeTrue
        Test-GghubRepositoryName -Repository 'bad repo' | Should -BeFalse
        Test-GghubRepositoryName -Repository 'repo.git' | Should -BeFalse
    }

    It 'builds HTTPS and SSH GitHub remote URLs' {
        New-GghubRemoteUrl -Owner 'jpavlek' -Repository 'GitGlideGUI' -Protocol HTTPS | Should -Be 'https://github.com/jpavlek/GitGlideGUI.git'
        New-GghubRemoteUrl -Owner 'jpavlek' -Repository 'GitGlideGUI' -Protocol SSH | Should -Be 'git@github.com:jpavlek/GitGlideGUI.git'
    }

    It 'builds publish previews with optional push' {
        $preview = Get-GghubPublishCommandPreview -Owner 'jpavlek' -Repository 'GitGlideGUI' -RemoteName 'origin' -PushAfter
        $preview | Should -Match 'https://github.com/jpavlek/GitGlideGUI.git'
        $preview | Should -Match 'git remote add origin'
        $preview | Should -Match 'git push -u origin HEAD'
    }

    It 'returns privacy checklist lines' {
        $lines = Get-GghubPrivacyChecklist -PrivateRepositoryRecommended -ReviewCopilotTrainingOptOut
        (@($lines) -join ' ') | Should -Match 'Private visibility'
        (@($lines) -join ' ') | Should -Match 'Copilot'
        (@($lines) -join ' ') | Should -Match 'do not initialize'
    }
}

Describe 'GitHub remote diagnostics helpers' {
    It 'parses git remote -v output and converts GitHub remotes to web URLs' {
        $rows = ConvertFrom-GghubRemoteList -Text "origin https://github.com/jpavlek/GitGlideGUI.git (fetch)`norigin https://github.com/jpavlek/GitGlideGUI.git (push)"
        @($rows).Count | Should -Be 2
        $rows[0].Name | Should -Be 'origin'
        Get-GghubRepositoryWebUrl -RemoteUrl 'https://github.com/jpavlek/GitGlideGUI.git' | Should -Be 'https://github.com/jpavlek/GitGlideGUI'
        Get-GghubRepositoryWebUrl -RemoteUrl 'git@github.com:jpavlek/GitGlideGUI.git' | Should -Be 'https://github.com/jpavlek/GitGlideGUI'
    }

    It 'builds remote diagnostics command plans' {
        (Get-GghubRemoteListCommandPlan).Display | Should -Be 'git remote -v'
        (Get-GghubUpstreamCommandPlan).Display | Should -Match '@\{u\}'
        (Get-GghubRemoteAccessTestCommandPlan -RemoteName 'origin').Arguments | Should -Be @('ls-remote','--heads','origin')
        (Get-GghubSetUpstreamPushCommandPlan -RemoteName 'origin').Arguments | Should -Be @('push','-u','origin','HEAD')
    }


    It 'extracts GitHub pull request URLs from push output' {
        $text = "remote: Create a pull request for 'feature/x' on GitHub by visiting:`nremote:      https://github.com/jpavlek/GitGlideGUI/pull/new/feature/x`n"
        $urls = @(Get-GghubPullRequestUrlsFromText -Text $text)
        $urls.Count | Should -Be 1
        $urls[0] | Should -Be 'https://github.com/jpavlek/GitGlideGUI/pull/new/feature/x'
    }

    It 'diagnoses GitHub remote failures with repository not found guidance' {
        $g = Get-GghubRemoteFailureGuidance -ExitCode 128 -StdErr "remote: Repository not found.`nfatal: repository 'https://github.com/jpavlek/GitGlideGUI.git/' not found" -RemoteName 'origin' -Operation 'push with upstream'
        $g.Kind | Should -Be 'repository-not-found'
        $g.Message | Should -Match 'may not exist'
        (@($g.RecoverySteps) -join ' ') | Should -Match 'owner'
    }
}
