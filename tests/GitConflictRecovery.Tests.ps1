$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
Import-Module (Join-Path $root 'modules/GitGlideGUI.Core/GitConflictRecovery.psm1') -Force

Describe 'GitConflictRecovery module' {
    It 'classifies merge conflict output and offers abort guidance' {
        $g = Get-GgrRecoveryGuidance -Operation 'merge feature' -ExitCode 1 -StdErr 'CONFLICT (content): Merge conflict in src/app.cpp. Automatic merge failed; fix conflicts and then commit the result.'
        $g.Kind | Should -Be 'conflict'
        $g.Title | Should -Match 'Conflicts'
        (@($g.Plans | Where-Object { $_.Verb -eq 'merge-abort' }).Count -gt 0) | Should -BeTrue
        $text = Format-GgrRecoveryGuidance -Guidance $g
        $text | Should -Match 'git merge --abort'
    }

    It 'classifies local changes that would be overwritten' {
        $g = Get-GgrRecoveryGuidance -Operation 'pull current branch' -ExitCode 1 -StdErr 'error: Your local changes to the following files would be overwritten by merge: README.md Please commit your changes or stash them before you merge.'
        $g.Kind | Should -Be 'local-changes-would-be-overwritten'
        $g.RecommendedAction | Should -Be 'stash-dirty-work'
        $g.Message | Should -Match 'local changes'
    }

    It 'classifies untracked overwrite risk' {
        $g = Get-GgrRecoveryGuidance -Operation 'stash apply' -ExitCode 1 -StdErr 'The following untracked working tree files would be overwritten by merge: temp.txt'
        $g.Kind | Should -Be 'untracked-would-be-overwritten'
        $g.RecoverySteps.Count | Should -Be 4
    }

    It 'builds recovery command previews' {
        $preview = ConvertTo-GgrCommandPreview -Plans @((Get-GgrConflictStatusCommandPlan), (Get-GgrAbortCherryPickCommandPlan))
        $preview | Should -Match 'git status --short'
        $preview | Should -Match 'git cherry-pick --abort'
    }
}

Describe 'Conflict file listing helpers' {
    It 'parses unresolved conflict file lists' {
        $files = ConvertFrom-GgrConflictFileList -Text "src/app.cpp`nREADME.md`n"
        $files | Should -Contain 'src/app.cpp'
        $files | Should -Contain 'README.md'
    }

    It 'formats conflicted file guidance' {
        $text = Format-GgrConflictFileGuidance -Files @('src/app.cpp')
        $text | Should -Match 'Unresolved conflict files'
        $text | Should -Match 'src/app.cpp'
    }
}


Describe 'Conflict state and continue-operation helpers' {
    It 'detects resolved and unresolved conflict state' {
        $state = ConvertFrom-GgrConflictState -StatusPorcelain "UU src/app.cpp`nM  README.md" -UnmergedText "src/app.cpp" -MergeInProgress
        $state.UnresolvedCount | Should -Be 1
        $state.ResolvedCandidateCount | Should -Be 1
        $state.MergeInProgress | Should -BeTrue
        $state.CanContinue | Should -BeFalse
        $text = Format-GgrConflictState -State $state
        $text | Should -Match 'unresolved files: 1'
    }

    It 'allows continue when operation marker exists and no unresolved files remain' {
        $state = ConvertFrom-GgrConflictState -StatusPorcelain "M  README.md" -UnmergedText '' -CherryPickInProgress
        $state.UnresolvedCount | Should -Be 0
        $state.ContinueCommandKind | Should -Be 'cherry-pick-continue'
        $state.CanContinue | Should -BeTrue
        (Get-GgrContinueOperationCommandPlan -Kind $state.ContinueCommandKind).Display | Should -Be 'git cherry-pick --continue'
    }

    It 'builds stage-resolved and external merge tool previews' {
        (Get-GgrStageResolvedFileCommandPlan -Path 'src/app.cpp').Display | Should -Be 'git add -- src/app.cpp'
        (Get-GgrExternalMergeToolCommandPlan -ToolCommand 'git mergetool').Display | Should -Be 'git mergetool'
        (Get-GgrExternalMergeToolCommandPlan -ToolCommand 'git mergetool --tool vscode').Display | Should -Match 'git mergetool --tool vscode'
    }
}
