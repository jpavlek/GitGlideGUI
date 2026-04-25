$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
Import-Module (Join-Path $root 'modules/GitGlideGUI.Core/GitCherryPickOperations.psm1') -Force

Describe 'GitCherryPickOperations module' {
    It 'validates safe commit refs' {
        (Test-GgcpCommitish -Commitish 'abc1234').Valid | Should -BeTrue
        (Test-GgcpCommitish -Commitish 'feature/branch').Valid | Should -BeTrue
        (Test-GgcpCommitish -Commitish 'abc1234; rm -rf .').Valid | Should -BeFalse
        (Test-GgcpCommitish -Commitish '').Valid | Should -BeFalse
    }

    It 'builds normal and no-commit cherry-pick plans' {
        $plan = Get-GgcpCherryPickCommandPlan -Commitish 'abc1234'
        $plan.Display | Should -Be 'git cherry-pick abc1234'
        $plan.Arguments[0] | Should -Be 'cherry-pick'

        $noCommit = Get-GgcpCherryPickCommandPlan -Commitish 'abc1234' -NoCommit
        $noCommit.Display | Should -Match '--no-commit'
    }

    It 'builds continue, abort, and skip plans' {
        (Get-GgcpCherryPickContinueCommandPlan).Display | Should -Be 'git cherry-pick --continue'
        (Get-GgcpCherryPickAbortCommandPlan).Display | Should -Be 'git cherry-pick --abort'
        (Get-GgcpCherryPickSkipCommandPlan).Display | Should -Be 'git cherry-pick --skip'
    }

    It 'extracts selected commit hashes from history lines' {
        $line = '* abcdef12345 (HEAD -> main) useful subject'
        (Get-GgcpSelectedCommitFromHistoryLine -Line $line) | Should -Be 'abcdef12345'
    }
}
