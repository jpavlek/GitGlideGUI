# Pester tests for UI-free staging and changed-file helpers.
$modulePath = Join-Path $PSScriptRoot '..\modules\GitGlideGUI.Core\GitStagingOperations.psm1'
Import-Module $modulePath -Force

Describe 'GitStagingOperations module' {
    It 'quotes paths with spaces for preview text' {
        $item = [pscustomobject]@{ Path = 'docs/my file.md'; RawPath = 'docs/my file.md'; Status = ' M'; IndexStatus = ' '; WorkTreeStatus = 'M'; OriginalPath = $null }
        $preview = ConvertTo-GggCommandPreview -Plans (Get-GggStageSelectedCommandPlan -Items @($item))
        $preview | Should -Be 'git add -- "docs/my file.md"'
    }

    It 'builds stage and unstage command plans' {
        $item = [pscustomobject]@{ Path = 'src/app.ps1'; RawPath = 'src/app.ps1'; Status = 'M '; IndexStatus = 'M'; WorkTreeStatus = ' '; OriginalPath = $null }
        (Get-GggStageSelectedCommandPlan -Items @($item))[0].Arguments | Should -Be @('add','--','src/app.ps1')
        (Get-GggUnstageSelectedCommandPlan -Items @($item))[0].Arguments | Should -Be @('restore','--staged','--','src/app.ps1')
        (Get-GggUnstageSelectedCommandPlan -Items @($item) -RepositoryHasNoCommits)[0].Arguments | Should -Be @('rm','--cached','--','src/app.ps1')
    }

    It 'uses git rm cached for unstaging before the first commit' {
        $item = [pscustomobject]@{ Path = 'README.md'; RawPath = 'README.md'; Status = 'A '; IndexStatus = 'A'; WorkTreeStatus = ' '; OriginalPath = $null }
        $plan = (Get-GggUnstageSelectedCommandPlan -Items @($item) -RepositoryHasNoCommits)[0]
        $plan.Display | Should -Be 'git rm --cached -- README.md'
        $plan.Description | Should -Match 'working-tree'
    }

    It 'builds stage-all plan' {
        $plan = (Get-GggStageAllCommandPlan)[0]
        $plan.Display | Should -Be 'git add -A'
        $plan.Arguments | Should -Be @('add','-A')
    }

    It 'builds staged and unstaged diff preview for mixed status' {
        $item = [pscustomobject]@{ Path = 'src/app.ps1'; RawPath = 'src/app.ps1'; Status = 'MM'; IndexStatus = 'M'; WorkTreeStatus = 'M'; OriginalPath = $null }
        $preview = Get-GggShowDiffCommandPreview -Item $item
        $preview | Should -Match '--cached'
        $preview | Should -Match 'git diff --no-ext-diff --no-color --find-renames -- src/app.ps1'
    }

    It 'uses both old and new paths for renamed files' {
        $item = [pscustomobject]@{ Path = 'new/name.txt'; RawPath = 'old/name.txt -> new/name.txt'; Status = 'R '; IndexStatus = 'R'; WorkTreeStatus = ' '; OriginalPath = 'old/name.txt' }
        $paths = Get-GggDiffTargetPaths -Item $item
        (@($paths) -contains 'old/name.txt') | Should -BeTrue
        (@($paths) -contains 'new/name.txt') | Should -BeTrue
    }

    It 'builds untracked single-file diff preview without strict-mode Count failure' {
        $item = [pscustomobject]@{ Path = 'README.md'; RawPath = 'README.md'; Status = '??'; IndexStatus = '?'; WorkTreeStatus = '?'; OriginalPath = $null }
        $preview = Get-GggShowDiffCommandPreview -Item $item
        $preview | Should -Be '# untracked file preview for README.md'
    }
}
