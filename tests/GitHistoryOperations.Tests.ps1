$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
Import-Module (Join-Path $root 'modules/GitGlideGUI.Core/GitHistoryOperations.psm1') -Force

Describe 'GitHistoryOperations module' {
    It 'builds read-only graph and model command plans' {
        $graph = Get-GghGraphCommandPlan -MaxCount 40
        $graph.Display | Should -Be 'git log --graph --decorate --oneline --all -n 40'
        $graph.Arguments | Should -Contain '--graph'
        $graph.Arguments | Should -Contain '--all'

        $model = Get-GghHistoryModelCommandPlan -MaxCount 120
        $model.Display | Should -Match 'format=<graph-model-fields>'
        $model.Arguments | Should -Contain '--all'
    }

    It 'parses normal compact commit log lines' {
        $sep = [string][char]0x1f
        $line = ('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' + $sep + 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' + $sep + 'Ada Lovelace' + $sep + 'ada@example.invalid' + $sep + '2026-04-25T10:00:00+00:00' + $sep + 'HEAD -> main, tag: v1.0.0' + $sep + 'Initial graph parser')
        $commit = ConvertFrom-GghCommitLogLine -Line $line
        $commit.ShortHash | Should -Be 'aaaaaaaaaaaa'
        $commit.ParentCount | Should -Be 1
        $commit.IsMerge | Should -BeFalse
        $commit.Decorations | Should -Contain 'HEAD -> main'
        $commit.Decorations | Should -Contain 'tag: v1.0.0'
        $commit.IsHead | Should -BeTrue
        $commit.HeadBranch | Should -Be 'main'
        $commit.Tags | Should -Contain 'v1.0.0'
        $commit.Subject | Should -Be 'Initial graph parser'
    }

    It 'parses merge commits as graph-ready objects' {
        $sep = [string][char]0x1f
        $parents = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb cccccccccccccccccccccccccccccccccccccccc'
        $line = ('dddddddddddddddddddddddddddddddddddddddd' + $sep + $parents + $sep + 'Grace Hopper' + $sep + 'grace@example.invalid' + $sep + '2026-04-25T11:00:00+00:00' + $sep + 'main' + $sep + 'Merge branch feature/history')
        $commit = ConvertFrom-GghCommitLogLine -Line $line
        $commit.ParentCount | Should -Be 2
        $commit.IsMerge | Should -BeTrue
        $commit.Parents | Should -Contain 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
        $commit.Parents | Should -Contain 'cccccccccccccccccccccccccccccccccccccccc'
    }

    It 'summarizes history records' {
        $sep = [string][char]0x1f
        $lines = @(
            ('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' + $sep + ('bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb') + $sep + 'A' + $sep + 'a@example.invalid' + $sep + '2026-04-25T10:00:00+00:00' + $sep + 'HEAD -> main' + $sep + 'normal'),
            ('dddddddddddddddddddddddddddddddddddddddd' + $sep + (('bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb') + ' ' + ('cccccccccccccccccccccccccccccccccccccccc')) + $sep + 'B' + $sep + 'b@example.invalid' + $sep + '2026-04-25T11:00:00+00:00' + $sep + '' + $sep + 'merge')
        )
        $commits = ConvertFrom-GghCommitLog -Lines $lines
        $summary = Format-GghHistorySummary -Commits $commits
        $summary | Should -Match '2 commits loaded'
        $summary | Should -Match '1 merge commits'
    }
}

Describe 'History visual graph rows' {
    It 'converts parsed commits to visual graph rows' {
        $line = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' -replace ' ', [char]0x1f
        $line = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' + [char]0x1f + '' + [char]0x1f + 'Alice' + [char]0x1f + 'a@example.com' + [char]0x1f + '2026-04-25T12:00:00+00:00' + [char]0x1f + 'HEAD -> main' + [char]0x1f + 'Initial commit'
        $commit = ConvertFrom-GghCommitLogLine -Line $line
        $rows = ConvertTo-GghVisualGraphRows -Commits @($commit)
        @($rows).Count | Should -Be 1
        $rows[0].Hash | Should -Be 'aaaaaaaaaaaa'
        $rows[0].Refs | Should -Match 'main'
    }

    It 'classifies branch, tag, remote and HEAD decorations for visual rows' {
        $sep = [string][char]0x1f
        $line = ('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' + $sep + '' + $sep + 'Alice' + $sep + 'a@example.com' + $sep + '2026-04-25T12:00:00+00:00' + $sep + 'HEAD -> main, origin/main, tag: v3.6.4' + $sep + 'Release graph polish')
        $commit = ConvertFrom-GghCommitLogLine -Line $line
        $row = Format-GghVisualGraphRow -Commit $commit -Index 0
        $row.Lane | Should -Be 'H*'
        $row.Branches | Should -Match 'main'
        $row.Remotes | Should -Match 'origin/main'
        $row.Tags | Should -Match 'v3.6.4'
        $row.Refs | Should -Match 'HEAD -> main'
        $row.Refs | Should -Match 'tag: v3.6.4'
        $row.FullHash | Should -Be 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    }

    It 'uses ASCII-only visual graph lane badges' {
        $sep = [string][char]0x1f
        $mergeParents = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb cccccccccccccccccccccccccccccccccccccccc'
        $line = ('dddddddddddddddddddddddddddddddddddddddd' + $sep + $mergeParents + $sep + 'Bob' + $sep + 'b@example.com' + $sep + '2026-04-25T13:00:00+00:00' + $sep + 'origin/develop' + $sep + 'Merge branch feature/x')
        $commit = ConvertFrom-GghCommitLogLine -Line $line
        $row = Format-GghVisualGraphRow -Commit $commit -Index 1
        $row.Lane | Should -Be 'M*'
        $row.Hint | Should -Match 'merge commit'
        foreach ($ch in $row.Lane.ToCharArray()) { if ([int][char]$ch -ge 128) { throw 'Visual graph lane must be ASCII-only.' } }
    }

}
