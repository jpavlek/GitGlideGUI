$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
Import-Module (Join-Path $root 'modules/GitGlideGUI.Core/GitBranchOperations.psm1') -Force
Import-Module (Join-Path $root 'modules/GitGlideGUI.Core/GitRepositoryStatus.psm1') -Force

Describe 'Temporary repository branch workflows' {
    BeforeAll {
        $script:TempRepo = Join-Path ([System.IO.Path]::GetTempPath()) ('GitGlideGUI-branch-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:TempRepo | Out-Null
        git -C $script:TempRepo init -b main | Out-Null
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

    It 'creates and switches to a feature branch using generated plans' {
        foreach ($plan in @(Get-GgbCreateFeatureBranchCommandPlan -Name 'feature/branch-workflow')) {
            $gitArgs = @('-C', $script:TempRepo) + @($plan.Arguments)
            & git @gitArgs | Out-Null
            $LASTEXITCODE | Should -Be 0
        }
        $snapshot = Get-GfgRepositoryStatus -RepositoryPath $script:TempRepo
        $snapshot.Branch | Should -Be 'feature/branch-workflow'
    }

    It 'detects dirty work before branch switching' {
        Set-Content -Path (Join-Path $script:TempRepo 'dirty.txt') -Value 'dirty'
        $snapshot = Get-GfgRepositoryStatus -RepositoryPath $script:TempRepo
        $guidance = Get-GgbDirtyWorkingTreeGuidance -Summary $snapshot.Summary -Operation 'switch branches'
        $guidance.IsClean | Should -BeFalse
        $guidance.Message | Should -Match 'protect your work'
    }

    It 'stashes dirty work before switching to main' {
        git -C $script:TempRepo stash push -u -m 'test stash before switch' | Out-Null
        foreach ($plan in @(Get-GgbSwitchBranchCommandPlan -TargetBranch 'main')) {
            $gitArgs = @('-C', $script:TempRepo) + @($plan.Arguments)
            & git @gitArgs | Out-Null
            $LASTEXITCODE | Should -Be 0
        }
        $snapshot = Get-GfgRepositoryStatus -RepositoryPath $script:TempRepo
        $snapshot.Branch | Should -Be 'main'
    }
}
