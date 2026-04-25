# Git Glide GUI v2.4 integration tests for repository status service.
# These tests create a temporary Git repository and do not touch the user's repository.

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot '..\modules\GitGlideGUI.Core\GitRepositoryStatus.psm1'
Import-Module $modulePath -Force

Describe 'GitRepositoryStatus integration' {
    BeforeAll {
        $script:GitAvailable = $false
        try {
            git --version | Out-Null
            $script:GitAvailable = ($LASTEXITCODE -eq 0)
        } catch {
            $script:GitAvailable = $false
        }
    }

    It 'reads clean and changed state from a temporary repository' -Skip:(-not $script:GitAvailable) {
        $repo = Join-Path ([System.IO.Path]::GetTempPath()) ('git-glide-status-test-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $repo | Out-Null
        try {
            git -C $repo init | Out-Null
            git -C $repo config user.email 'git-glide-tests@example.invalid' | Out-Null
            git -C $repo config user.name 'Git Glide Tests' | Out-Null
            Set-Content -Path (Join-Path $repo 'tracked.txt') -Value 'one' -Encoding UTF8
            git -C $repo add tracked.txt | Out-Null
            git -C $repo commit -m 'initial commit' | Out-Null

            $clean = Get-GfgRepositoryStatus -RepositoryPath $repo
            $clean.Success | Should -BeTrue
            $clean.Summary.IsClean | Should -BeTrue
            $clean.Suggestion | Should -Match 'Working tree is clean|No upstream'

            Add-Content -Path (Join-Path $repo 'tracked.txt') -Value 'two'
            Set-Content -Path (Join-Path $repo 'untracked.txt') -Value 'new' -Encoding UTF8

            $changed = Get-GfgRepositoryStatus -RepositoryPath $repo
            $changed.Success | Should -BeTrue
            $changed.Summary.Total | Should -Be 2
            $changed.Summary.Unstaged | Should -Be 1
            $changed.Summary.Untracked | Should -Be 1
            $changed.Suggestion | Should -Match 'Stage the intended files|stash'
        }
        finally {
            if (Test-Path -LiteralPath $repo) { Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}
