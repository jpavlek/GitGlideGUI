$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
Import-Module (Join-Path $root 'modules/GitGlideGUI.Core/GitCommitOperations.psm1') -Force

Describe 'GitCommitOperations module' {
    It 'validates commit messages' {
        (Test-GgcCommitMessage -Subject 'feat(core): add parser').Valid | Should -BeTrue
        (Test-GgcCommitMessage -Subject '').Valid | Should -BeFalse
        (Test-GgcCommitMessage -Subject ('x' * 80) -MaxSubjectLength 72).Warning | Should -Match 'Subject is long'
    }

    It 'offers optional Conventional Commits guidance' {
        $bad = Test-GgcCommitMessage -Subject 'add parser' -ConventionalCommits
        $bad.Valid | Should -BeTrue
        $bad.Warning | Should -Match 'Conventional Commits'
        $bad.Guidance | Should -Match 'feat\(parser\)'

        $good = Test-GgcCommitMessage -Subject 'feat(parser): handle quoted paths' -ConventionalCommits
        $good.Warning | Should -Be ''
    }

    It 'builds normal commit preview with temporary message file' {
        $plan = Get-GgcCommitCommandPlan -Subject 'feat(ui): improve commit preview' -Body 'Longer body.'
        $plan.MessageText | Should -Match 'Longer body'
        (@($plan.Commands) -contains 'git commit -F <temp-commit-message-file>') | Should -BeTrue
    }

    It 'builds stage all, amend, and push command previews' {
        $plan = Get-GgcCommitCommandPlan -Subject 'fix: repair startup' -StageAll -Amend -PushAfter -UseForceWithLease
        (@($plan.Commands) -contains 'git add -A') | Should -BeTrue
        (@($plan.Commands) -contains 'git commit --amend -F <temp-commit-message-file>') | Should -BeTrue
        (@($plan.Commands) -contains 'git push --force-with-lease') | Should -BeTrue
    }

    It 'builds initial commit, soft undo, and history model plans' {
        (@((Get-GgcInitialCommitCommandPlan -Subject 'Initial commit').Commands) -contains 'git add -A') | Should -BeTrue
        (ConvertTo-GgcCommandPreview -Plans (Get-GgcSoftUndoLastCommitCommandPlan)) | Should -Match 'git reset --soft HEAD~1'
        (Get-GgcCommitHistoryCommandPlan -MaxCount 40).Display | Should -Match 'graph-model-fields'
    }

    It 'converts compact commit log lines into graph-ready objects' {
        $line = 'abc123' + [char]0x1f + 'parent1 parent2' + [char]0x1f + 'Tester' + [char]0x1f + 't@example.invalid' + [char]0x1f + '2026-04-25T00:00:00+00:00' + [char]0x1f + 'feat: test'
        $commit = ConvertFrom-GgcCommitLogLine -Line $line
        $commit.Hash | Should -Be 'abc123'
        $commit.Parents.Count | Should -Be 2
        $commit.Subject | Should -Be 'feat: test'
    }
}
