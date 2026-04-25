$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
Import-Module (Join-Path $root 'modules/GitGlideGUI.Core/GitHistoryOperations.psm1') -Force

Describe 'Temporary repository history workflows' {
    BeforeEach {
        $script:TempRepo = Join-Path ([System.IO.Path]::GetTempPath()) ('GitGlideGUI-history-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:TempRepo | Out-Null
        git -C $script:TempRepo init -b main | Out-Null
        git -C $script:TempRepo config user.email 'git-glide-gui@example.invalid' | Out-Null
        git -C $script:TempRepo config user.name 'Git Glide GUI Tests' | Out-Null
        Set-Content -Path (Join-Path $script:TempRepo 'README.md') -Value '# history test repo'
        git -C $script:TempRepo add README.md | Out-Null
        git -C $script:TempRepo commit -m 'initial commit' | Out-Null
    }

    AfterEach {
        if ($script:TempRepo -and (Test-Path $script:TempRepo)) {
            Remove-Item -LiteralPath $script:TempRepo -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'loads read-only graph output from a temporary repository' {
        $plan = Get-GghGraphCommandPlan -MaxCount 20
        $gitArgs = @('-C', $script:TempRepo) + @($plan.Arguments)
        $graph = & git @gitArgs
        $LASTEXITCODE | Should -Be 0
        ($graph -join "`n") | Should -Match 'initial commit'
    }

    It 'parses merge commits from git log model output' {
        git -C $script:TempRepo switch -c feature/history | Out-Null
        Set-Content -Path (Join-Path $script:TempRepo 'feature.txt') -Value 'feature work'
        git -C $script:TempRepo add feature.txt | Out-Null
        git -C $script:TempRepo commit -m 'feature history work' | Out-Null
        git -C $script:TempRepo switch main | Out-Null
        Set-Content -Path (Join-Path $script:TempRepo 'main.txt') -Value 'main work'
        git -C $script:TempRepo add main.txt | Out-Null
        git -C $script:TempRepo commit -m 'main history work' | Out-Null
        git -C $script:TempRepo merge --no-ff feature/history -m 'merge feature history' | Out-Null
        $LASTEXITCODE | Should -Be 0

        $plan = Get-GghHistoryModelCommandPlan -MaxCount 30
        $gitArgs = @('-C', $script:TempRepo) + @($plan.Arguments)
        $lines = & git @gitArgs
        $LASTEXITCODE | Should -Be 0
        $commits = ConvertFrom-GghCommitLog -Lines $lines
        @($commits | Where-Object { $_.IsMerge }).Count | Should -Be 1
        (@($commits | Where-Object { $_.IsMerge })[0].ParentCount) | Should -Be 2
    }
}
