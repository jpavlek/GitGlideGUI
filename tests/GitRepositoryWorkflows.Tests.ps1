# Temporary repository integration tests for core Git workflows used by Git Glide GUI.
$onboardingModule = Join-Path $PSScriptRoot '..\modules\GitGlideGUI.Core\GitRepositoryOnboarding.psm1'
Import-Module $onboardingModule -Force

function New-TempGitRepository {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('GitGlideGUI-Test-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    git -C $root init -b main *> $null
    if ($LASTEXITCODE -ne 0) {
        git -C $root init *> $null
        git -C $root branch -M main *> $null
    }
    git -C $root config user.email 'git-glide-gui-tests@example.invalid' *> $null
    git -C $root config user.name 'Git Glide GUI Tests' *> $null
    return $root
}

Describe 'Git Glide temporary repository workflows' {
    It 'initializes a temporary repository' -Skip:(-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $repo = New-TempGitRepository
        try {
            git -C $repo rev-parse --is-inside-work-tree | Should -Be 'true'
        } finally {
            Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'writes gitignore content and creates the first commit' -Skip:(-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $repo = New-TempGitRepository
        try {
            Set-Content -LiteralPath (Join-Path $repo '.gitignore') -Value (Get-GggGitIgnoreTemplateContent -TemplateName 'General / Windows') -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $repo 'README.md') -Value '# Test repository' -Encoding UTF8
            git -C $repo add -A *> $null
            git -C $repo commit -m 'Initial commit' *> $null
            $LASTEXITCODE | Should -Be 0
            git -C $repo log --oneline -n 1 | Should -Match 'Initial commit'
        } finally {
            Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'creates, lists, and drops a stash' -Skip:(-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $repo = New-TempGitRepository
        try {
            Set-Content -LiteralPath (Join-Path $repo 'file.txt') -Value 'one' -Encoding UTF8
            git -C $repo add -A *> $null
            git -C $repo commit -m 'Add file' *> $null
            Set-Content -LiteralPath (Join-Path $repo 'file.txt') -Value 'two' -Encoding UTF8
            git -C $repo stash push -m 'test stash' *> $null
            git -C $repo stash list | Should -Match 'test stash'
            git -C $repo stash drop 'stash@{0}' *> $null
            $LASTEXITCODE | Should -Be 0
        } finally {
            Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'creates and deletes an annotated tag' -Skip:(-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $repo = New-TempGitRepository
        try {
            Set-Content -LiteralPath (Join-Path $repo 'file.txt') -Value 'tag me' -Encoding UTF8
            git -C $repo add -A *> $null
            git -C $repo commit -m 'Add tag target' *> $null
            git -C $repo tag -a v0.1.0 -m 'Test tag' *> $null
            (@(git -C $repo tag --list) -contains 'v0.1.0') | Should -BeTrue
            git -C $repo tag -d v0.1.0 *> $null
            $LASTEXITCODE | Should -Be 0
        } finally {
            Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
