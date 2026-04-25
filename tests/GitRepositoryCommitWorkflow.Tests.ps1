$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
Import-Module (Join-Path $root 'modules/GitGlideGUI.Core/GitCommitOperations.psm1') -Force

Describe 'Temporary repository commit workflows' {
    BeforeEach {
        $script:TempRepo = Join-Path ([System.IO.Path]::GetTempPath()) ('GitGlideGUI-commits-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:TempRepo | Out-Null
        git -C $script:TempRepo init -b main | Out-Null
        git -C $script:TempRepo config user.email 'git-glide-gui@example.invalid' | Out-Null
        git -C $script:TempRepo config user.name 'Git Glide GUI Tests' | Out-Null
    }

    AfterEach {
        if ($script:TempRepo -and (Test-Path $script:TempRepo)) {
            Remove-Item -LiteralPath $script:TempRepo -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    function Invoke-TestPlan {
        param([object[]]$Plans)
        foreach ($plan in @($Plans)) {
            $gitArgs = @('-C', $script:TempRepo) + @($plan.Arguments | Where-Object { $_ -ne '<temp-commit-message-file>' })
            & git @gitArgs | Out-Null
            $LASTEXITCODE | Should -Be 0
        }
    }

    It 'creates an initial commit through generated stage and commit plans' {
        Set-Content -Path (Join-Path $script:TempRepo 'README.md') -Value '# commit test repo'
        $messagePath = Join-Path $script:TempRepo '.gitglide-message.txt'
        Set-Content -Path $messagePath -Value 'Initial commit'
        $plan = Get-GgcInitialCommitCommandPlan -Subject 'Initial commit'

        foreach ($step in @($plan.Plans)) {
            $stepArgs = @($step.Arguments)
            $stepArgs = @($stepArgs | ForEach-Object { if ($_ -eq '<temp-commit-message-file>') { $messagePath } else { $_ } })
            $gitArgs = @('-C', $script:TempRepo) + @($stepArgs)
            & git @gitArgs | Out-Null
            $LASTEXITCODE | Should -Be 0
        }

        (git -C $script:TempRepo rev-list --count HEAD) | Should -Be '1'
    }

    It 'creates a normal second commit through generated plans' {
        Set-Content -Path (Join-Path $script:TempRepo 'README.md') -Value '# commit test repo'
        git -C $script:TempRepo add -A | Out-Null
        git -C $script:TempRepo commit -m 'Initial commit' | Out-Null

        Set-Content -Path (Join-Path $script:TempRepo 'README.md') -Value '# updated'
        $messagePath = Join-Path $script:TempRepo '.gitglide-message.txt'
        Set-Content -Path $messagePath -Value 'fix: update README'
        $plan = Get-GgcCommitCommandPlan -Subject 'fix: update README' -StageAll

        foreach ($step in @($plan.Plans)) {
            $stepArgs = @($step.Arguments)
            $stepArgs = @($stepArgs | ForEach-Object { if ($_ -eq '<temp-commit-message-file>') { $messagePath } else { $_ } })
            $gitArgs = @('-C', $script:TempRepo) + @($stepArgs)
            & git @gitArgs | Out-Null
            $LASTEXITCODE | Should -Be 0
        }

        (git -C $script:TempRepo rev-list --count HEAD) | Should -Be '2'
    }

    It 'builds amend preview without executing the amend' {
        $plan = Get-GgcCommitCommandPlan -Subject 'fix: amend preview only' -Amend -PushAfter -UseForceWithLease
        $preview = Get-GgcCommitPreviewText -CommitPlan $plan
        $preview | Should -Match 'git commit --amend -F <temp-commit-message-file>'
        $preview | Should -Match 'git push --force-with-lease'
    }

    It 'plans soft undo after a commit' {
        Set-Content -Path (Join-Path $script:TempRepo 'README.md') -Value '# commit test repo'
        git -C $script:TempRepo add -A | Out-Null
        git -C $script:TempRepo commit -m 'Initial commit' | Out-Null
        $undo = Get-GgcSoftUndoLastCommitCommandPlan
        (@($undo[-1].Arguments) -contains '--soft') | Should -BeTrue
        (@($undo[-1].Arguments) -contains 'HEAD~1') | Should -BeTrue
    }
}
