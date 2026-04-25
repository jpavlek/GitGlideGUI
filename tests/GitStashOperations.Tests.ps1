$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
Import-Module (Join-Path $root 'modules/GitGlideGUI.Core/GitStashOperations.psm1') -Force

Describe 'GitStashOperations module' {
    It 'builds stash push plans with optional flags and message' {
        $plan = Get-GgsStashPushCommandPlan -Message 'save work' -IncludeUntracked -KeepIndex
        $plan.Display | Should -Be 'git stash push -u --keep-index -m "save work"'
        (@($plan.Arguments) -contains 'stash') | Should -BeTrue
        (@($plan.Arguments) -contains '-u') | Should -BeTrue
        (@($plan.Arguments) -contains '--keep-index') | Should -BeTrue
    }

    It 'validates stash references before destructive or applying commands' {
        Test-GgsStashRef 'stash@{0}' | Should -BeTrue
        Test-GgsStashRef 'stash@{12}' | Should -BeTrue
        Test-GgsStashRef 'HEAD' | Should -BeFalse
        { Get-GgsStashDropCommandPlan -StashRef 'HEAD' } | Should -Throw
    }

    It 'builds apply, pop, branch, show and clear previews' {
        (ConvertTo-GgsCommandPreview -Plan (Get-GgsStashApplyCommandPlan -StashRef 'stash@{0}' -RestoreIndex)) | Should -Be 'git stash apply --index "stash@{0}"'
        (ConvertTo-GgsCommandPreview -Plan (Get-GgsStashPopCommandPlan -StashRef 'stash@{0}')) | Should -Be 'git stash pop "stash@{0}"'
        (ConvertTo-GgsCommandPreview -Plan (Get-GgsStashBranchCommandPlan -BranchName 'feature/recover' -StashRef 'stash@{0}')) | Should -Be 'git stash branch feature/recover "stash@{0}"'
        (ConvertTo-GgsCommandPreview -Plan (Get-GgsStashShowPatchCommandPlan -StashRef 'stash@{0}')) | Should -Match 'stash show --stat --patch'
        (ConvertTo-GgsCommandPreview -Plan (Get-GgsStashClearCommandPlan)) | Should -Be 'git stash clear'
    }

    It 'explains conflict and overwrite failure recovery' {
        $guidance = Get-GgsStashFailureGuidance -Operation 'stash pop' -StdErr 'CONFLICT (content): Merge conflict in file.txt'
        $guidance.Message | Should -Match 'conflict'
        ($guidance.RecoverySteps -join ' ') | Should -Match 'Prefer Apply over Pop'

        $overwrite = Get-GgsStashFailureGuidance -Operation 'stash apply' -StdErr 'Your local changes to the following files would be overwritten'
        $overwrite.Message | Should -Match 'overwritten'
    }

    It 'suggests safe stash action only for non-conflicted unstaged or untracked work' {
        $dirty = [pscustomobject]@{ Total = 1; Staged = 0; Unstaged = 1; Untracked = 0; Conflicted = 0 }
        (Get-GgsDirtyWorkTreeStashSuggestion -Summary $dirty).Action | Should -Be 'stash-dirty-work'
        $staged = [pscustomobject]@{ Total = 1; Staged = 1; Unstaged = 0; Untracked = 0; Conflicted = 0 }
        Get-GgsDirtyWorkTreeStashSuggestion -Summary $staged | Should -BeNullOrEmpty
        $conflict = [pscustomobject]@{ Total = 1; Staged = 0; Unstaged = 0; Untracked = 0; Conflicted = 1 }
        Get-GgsDirtyWorkTreeStashSuggestion -Summary $conflict | Should -BeNullOrEmpty
    }
}
