$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
Import-Module (Join-Path $root 'modules/GitGlideGUI.Core/GitBranchOperations.psm1') -Force

Describe 'GitBranchOperations module' {
    It 'validates safe branch names' {
        (Test-GgbBranchName -Name 'feature/v2-9-branch-module').Valid | Should -BeTrue
        (Test-GgbBranchName -Name '').Valid | Should -BeFalse
        (Test-GgbBranchName -Name 'feature/bad:name').Valid | Should -BeFalse
        (Test-GgbBranchName -Name 'feature/ends-with-dot.').Valid | Should -BeFalse
    }

    It 'builds feature-branch plans with a fast-forward-only pull' {
        $plans = @(Get-GgbCreateFeatureBranchCommandPlan -Name 'feature/test' -BaseBranch 'develop' -BaseFromBaseBranch)
        $plans.Count | Should -Be 3
        $plans[0].Display | Should -Be 'git switch develop'
        $plans[1].Display | Should -Be 'git pull --ff-only'
        $plans[2].Display | Should -Be 'git switch -c feature/test'
    }

    It 'builds switch, pull, push and merge previews' {
        (ConvertTo-GgbCommandPreview -Plans (Get-GgbSwitchBranchCommandPlan -TargetBranch 'feature/test')) | Should -Be 'git switch feature/test'
        (ConvertTo-GgbCommandPreview -Plans (Get-GgbPullCurrentBranchCommandPlan)) | Should -Be 'git pull --ff-only'
        (ConvertTo-GgbCommandPreview -Plans (Get-GgbPushCurrentBranchCommandPlan)) | Should -Be 'git push -u origin HEAD'
        (ConvertTo-GgbCommandPreview -Plans (Get-GgbMergeFeatureIntoBaseCommandPlan -FeatureBranch 'feature/test' -BaseBranch 'develop')) | Should -Match 'git merge --no-ff feature/test'
    }

    It 'explains dirty working tree risks' {
        $summary = [pscustomobject]@{ Total = 2; Staged = 1; Unstaged = 1; Untracked = 0; Conflicted = 0 }
        $guidance = Get-GgbDirtyWorkingTreeGuidance -Summary $summary -Operation 'switch branches'
        $guidance.IsClean | Should -BeFalse
        $guidance.Message | Should -Match 'Before switch branches'
        $guidance.Details | Should -Match 'Staged: 1'
    }

    It 'prioritizes conflict guidance over normal dirty guidance' {
        $summary = [pscustomobject]@{ Total = 1; Staged = 0; Unstaged = 0; Untracked = 0; Conflicted = 1 }
        $guidance = Get-GgbDirtyWorkingTreeGuidance -Summary $summary -Operation 'pull current branch'
        $guidance.Severity | Should -Be 'conflict'
        $guidance.RecommendedAction | Should -Be 'show-diff'
    }
}
