# Pester tests for UI-free repository onboarding helpers.
$modulePath = Join-Path $PSScriptRoot '..\modules\GitGlideGUI.Core\GitRepositoryOnboarding.psm1'
Import-Module $modulePath -Force

Describe 'GitRepositoryOnboarding module' {
    It 'returns expected gitignore templates' {
        $names = Get-GggGitIgnoreTemplateNames
        (@($names) -contains 'General / Windows') | Should -BeTrue
        (@($names) -contains 'Unreal Engine') | Should -BeTrue
        (@($names) -contains 'C++ / CMake') | Should -BeTrue
    }

    It 'generates a PowerShell gitignore template' {
        $content = Get-GggGitIgnoreTemplateContent -TemplateName 'PowerShell'
        $content | Should -Match 'Git Glide GUI .gitignore template: PowerShell'
        $content | Should -Match 'GitGlideGUI-Audit.log'
    }

    It 'validates remote names safely' {
        Test-GggRemoteName -RemoteName 'origin' | Should -BeTrue
        Test-GggRemoteName -RemoteName 'upstream-main_1' | Should -BeTrue
        Test-GggRemoteName -RemoteName 'bad remote' | Should -BeFalse
        Test-GggRemoteName -RemoteName 'bad;remote' | Should -BeFalse
    }

    It 'builds an init command plan with fallback' {
        $plan = Get-GggRepositoryInitCommandPlan -InitialBranch 'main'
        $plan.Preview | Should -Match 'git init -b main'
        $plan.Fallback.Count | Should -Be 2
    }

    It 'builds first-commit preview text' {
        $preview = Get-GggFirstCommitCommandPreview -RemoteName 'origin' -WithGitIgnore -WithRemote -PushAfter
        $preview | Should -Match 'git add -A'
        $preview | Should -Match 'git commit -F'
        $preview | Should -Match 'git remote add origin'
        $preview | Should -Match 'git push -u origin HEAD'
    }
}
