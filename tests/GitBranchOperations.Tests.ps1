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


    It 'builds Git Flow merge and publish workflow plans' {
        (Get-GgbBranchTrackingCommandPlan).Display | Should -Be 'git branch -vv'
        (ConvertTo-GgbCommandPreview -Plans (Get-GgbPushBranchWithUpstreamCommandPlan -BranchName 'feature/test' -RemoteName 'origin')) | Should -Be 'git push -u origin feature/test'
        $syncPreview = ConvertTo-GgbCommandPreview -Plans (Get-GgbSyncMainIntoBaseCommandPlan -MainBranch 'main' -BaseBranch 'develop')
        $syncPreview | Should -Match 'git switch main'
        $syncPreview | Should -Match 'git merge main'
        $syncPreview | Should -Match 'git push -u origin develop'
        $mergePreview = ConvertTo-GgbCommandPreview -Plans (Get-GgbMergeNamedFeatureIntoBaseCommandPlan -FeatureBranch 'feature/github-remote-parser' -BaseBranch 'develop')
        $mergePreview | Should -Match 'git merge --no-ff feature/github-remote-parser'
        $guide = Get-GgbGitFlowMergeAndPublishGuide -MainBranch 'main' -BaseBranch 'develop' -FeatureBranch 'feature/github-remote-parser'
        $guide | Should -Match 'run-quality-checks.bat'
        $guide | Should -Match 'git merge --no-ff develop'
    }


    It 'warns before committing directly on workflow branches' {
        (Test-GgbWorkflowProtectedBranch -BranchName 'main' -MainBranch 'main' -BaseBranch 'develop') | Should -BeTrue
        (Test-GgbWorkflowProtectedBranch -BranchName 'feature/test' -MainBranch 'main' -BaseBranch 'develop') | Should -BeFalse
        $mainGuidance = Get-GgbProtectedBranchCommitGuidance -BranchName 'main' -MainBranch 'main' -BaseBranch 'develop'
        $mainGuidance.ShouldWarn | Should -BeTrue
        $mainGuidance.Message | Should -Match 'Create a feature branch'
        $featureGuidance = Get-GgbProtectedBranchCommitGuidance -BranchName 'feature/test' -MainBranch 'main' -BaseBranch 'develop'
        $featureGuidance.ShouldWarn | Should -BeFalse
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
