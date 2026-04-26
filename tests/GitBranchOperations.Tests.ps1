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

Describe 'Git Flow branch role helpers' {
    It 'classifies branch roles for workflow guidance' {
        (Get-GgbBranchRole -BranchName 'main').Role | Should Be 'protected release branch'
        (Get-GgbBranchRole -BranchName 'develop').Role | Should Be 'integration branch'
        (Get-GgbBranchRole -BranchName 'feature/x').Role | Should Be 'feature branch'
        (Get-GgbBranchRole -BranchName 'fix/y').Role | Should Be 'fix branch'
    }

    It 'builds move-current-work branch plans' {
        $plans = Get-GgbMoveCurrentChangesToBranchCommandPlan -BranchName 'fix/context-guard'
        $plans[0].Display | Should Be 'git switch -c fix/context-guard'
    }
}


Describe 'Git Glide UI mode helper' {
    It 'keeps simple mode focused while workflow and expert preserve access to advanced tools' {
        $simple = @(Get-GgbUiModeTabNames -Mode Simple)
        $workflow = @(Get-GgbUiModeTabNames -Mode Workflow)
        $expert = @(Get-GgbUiModeTabNames -Mode Expert)
        $simple -contains 'Custom Git' | Should Be $false
        $workflow -contains 'Integrate' | Should Be $true
        $workflow -contains 'Recovery' | Should Be $true
        $expert -contains 'Custom Git' | Should Be $true
        $expert.Count -gt $simple.Count | Should Be $true
    }
}



Describe 'Git Flow workflow checklist and cleanup helpers' {
    It 'builds a workflow checklist that keeps developer decision points explicit' {
        $items = @(Get-GgbWorkflowChecklist -CurrentBranch 'main' -FeatureBranch 'feature/x' -MainBranch 'main' -BaseBranch 'develop' -Upstream '')
        $items.Count | Should Be 7
        $items[0].Status | Should Be 'attention'
        $items[0].Title | Should Match 'feature/fix'
        $text = Format-GgbWorkflowChecklist -Items $items
        $text | Should Match 'git push -u origin HEAD'
        $text | Should Match 'run-quality-checks.bat'
        $text | Should Match 'git branch -d feature/x'
    }

    It 'builds safe cleanup plans for merged feature branches' {
        $plans = @(Get-GgbCleanupMergedBranchCommandPlan -BranchName 'feature/x' -DeleteRemote)
        $plans.Count | Should Be 2
        $plans[0].Display | Should Be 'git branch -d feature/x'
        $plans[1].Display | Should Be 'git push origin --delete feature/x'
    }

    It 'refuses cleanup plans for protected workflow branches' {
        { Get-GgbCleanupMergedBranchCommandPlan -BranchName 'main' } | Should Throw
        { Get-GgbCleanupMergedBranchCommandPlan -BranchName 'develop' } | Should Throw
    }
}
