$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
Import-Module (Join-Path $root 'modules/GitGlideGUI.Core/GitStashOperations.psm1') -Force
Import-Module (Join-Path $root 'modules/GitGlideGUI.Core/GitRepositoryStatus.psm1') -Force

Describe 'Temporary repository stash workflows' {
    BeforeAll {
        $script:TempRepo = Join-Path ([System.IO.Path]::GetTempPath()) ('GitGlideGUI-stash-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:TempRepo | Out-Null
        git -C $script:TempRepo init -b main | Out-Null
        if ($LASTEXITCODE -ne 0) { git -C $script:TempRepo init | Out-Null; git -C $script:TempRepo branch -M main | Out-Null }
        git -C $script:TempRepo config user.email 'git-glide-gui@example.invalid' | Out-Null
        git -C $script:TempRepo config user.name 'Git Glide GUI Tests' | Out-Null
        Set-Content -Path (Join-Path $script:TempRepo 'README.md') -Value '# test repo'
        git -C $script:TempRepo add README.md | Out-Null
        git -C $script:TempRepo commit -m 'initial commit' | Out-Null
    }

    AfterAll {
        if ($script:TempRepo -and (Test-Path $script:TempRepo)) {
            Remove-Item -LiteralPath $script:TempRepo -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'creates a stash including untracked files using generated plans' {
        Add-Content -Path (Join-Path $script:TempRepo 'README.md') -Value 'dirty work'
        Set-Content -Path (Join-Path $script:TempRepo 'new-file.txt') -Value 'untracked'
        $plan = Get-GgsStashPushCommandPlan -Message 'workflow stash' -IncludeUntracked
        & git @(@('-C', $script:TempRepo) + @($plan.Arguments)) | Out-Null
        $LASTEXITCODE | Should -Be 0
        $stashes = git -C $script:TempRepo stash list
        ($stashes -join "`n") | Should -Match 'workflow stash'
        (Test-Path (Join-Path $script:TempRepo 'new-file.txt')) | Should -BeFalse
    }

    It 'applies the stash without dropping it' {
        $plan = Get-GgsStashApplyCommandPlan -StashRef 'stash@{0}'
        & git @(@('-C', $script:TempRepo) + @($plan.Arguments)) | Out-Null
        $LASTEXITCODE | Should -Be 0
        (Test-Path (Join-Path $script:TempRepo 'new-file.txt')) | Should -BeTrue
        $stashes = git -C $script:TempRepo stash list
        ($stashes -join "`n") | Should -Match 'workflow stash'
    }

    It 'drops the stash with a generated plan after cleanup' {
        git -C $script:TempRepo reset --hard HEAD | Out-Null
        Remove-Item -Path (Join-Path $script:TempRepo 'new-file.txt') -Force -ErrorAction SilentlyContinue
        $plan = Get-GgsStashDropCommandPlan -StashRef 'stash@{0}'
        & git @(@('-C', $script:TempRepo) + @($plan.Arguments)) | Out-Null
        $LASTEXITCODE | Should -Be 0
        $stashes = git -C $script:TempRepo stash list
        ($stashes -join "`n") | Should -Not -Match 'workflow stash'
    }

    It 'classifies stash conflict output for recovery guidance' {
        $guidance = Get-GgsStashFailureGuidance -Operation 'stash pop' -StdErr 'error: Your local changes to the following files would be overwritten by merge'
        $guidance.Message | Should -Match 'overwritten'
        @($guidance.RecoverySteps).Count | Should -BeGreaterThan 0
    }
}
