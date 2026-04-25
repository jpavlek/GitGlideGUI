$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
Import-Module (Join-Path $root 'modules/GitGlideGUI.Core/GitCherryPickOperations.psm1') -Force
Import-Module (Join-Path $root 'modules/GitGlideGUI.Core/GitConflictRecovery.psm1') -Force

Describe 'Temporary repository cherry-pick workflows' {
    BeforeEach {
        $script:TempRepo = Join-Path ([System.IO.Path]::GetTempPath()) ('GitGlideGUI-cherry-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:TempRepo | Out-Null
        git -C $script:TempRepo init -b main | Out-Null
        git -C $script:TempRepo config user.email 'git-glide-gui@example.invalid' | Out-Null
        git -C $script:TempRepo config user.name 'Git Glide GUI Tests' | Out-Null
        Set-Content -Path (Join-Path $script:TempRepo 'README.md') -Value 'base'
        git -C $script:TempRepo add README.md | Out-Null
        git -C $script:TempRepo commit -m 'initial commit' | Out-Null
    }

    AfterEach {
        if ($script:TempRepo -and (Test-Path $script:TempRepo)) {
            Remove-Item -LiteralPath $script:TempRepo -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'cherry-picks a non-conflicting commit using the generated plan' {
        git -C $script:TempRepo switch -c feature/cherry | Out-Null
        Set-Content -Path (Join-Path $script:TempRepo 'feature.txt') -Value 'feature cherry-pick work'
        git -C $script:TempRepo add feature.txt | Out-Null
        git -C $script:TempRepo commit -m 'feature commit to cherry-pick' | Out-Null
        $hash = (& git -C $script:TempRepo rev-parse --short HEAD).Trim()
        git -C $script:TempRepo switch main | Out-Null
        $plan = Get-GgcpCherryPickCommandPlan -Commitish $hash
        $args = @('-C', $script:TempRepo) + @($plan.Arguments)
        & git @args | Out-Null
        $LASTEXITCODE | Should -Be 0
        Test-Path (Join-Path $script:TempRepo 'feature.txt') | Should -BeTrue
    }

    It 'classifies cherry-pick conflicts and can abort with generated plan' {
        git -C $script:TempRepo switch -c feature/conflict | Out-Null
        Set-Content -Path (Join-Path $script:TempRepo 'README.md') -Value 'feature change'
        git -C $script:TempRepo add README.md | Out-Null
        git -C $script:TempRepo commit -m 'feature conflicting change' | Out-Null
        $hash = (& git -C $script:TempRepo rev-parse --short HEAD).Trim()
        git -C $script:TempRepo switch main | Out-Null
        Set-Content -Path (Join-Path $script:TempRepo 'README.md') -Value 'main change'
        git -C $script:TempRepo add README.md | Out-Null
        git -C $script:TempRepo commit -m 'main conflicting change' | Out-Null

        $plan = Get-GgcpCherryPickCommandPlan -Commitish $hash
        $args = @('-C', $script:TempRepo) + @($plan.Arguments)
        $output = ''
        try {
            $output = (& git @args 2>&1 | Out-String)
        } catch {
            $output = $_.Exception.Message
        }
        if ($LASTEXITCODE -eq 0) { throw 'Expected cherry-pick conflict to return a non-zero exit code.' }
        $g = Get-GgrRecoveryGuidance -Operation 'cherry-pick' -ExitCode 1 -StdErr ($output -join "`n")
        $g.Kind | Should -Be 'conflict'
        (@($g.Plans | Where-Object { $_.Verb -eq 'cherry-pick-abort' }).Count -gt 0) | Should -BeTrue

        $abort = Get-GgcpCherryPickAbortCommandPlan
        $abortArgs = @('-C', $script:TempRepo) + @($abort.Arguments)
        & git @abortArgs | Out-Null
        $LASTEXITCODE | Should -Be 0
    }
}
