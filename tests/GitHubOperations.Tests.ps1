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
