$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
Import-Module (Join-Path $root 'modules/GitGlideGUI.Core/GitTagOperations.psm1') -Force

Describe 'Temporary repository tag workflows' {
    BeforeEach {
        $script:TempRepo = Join-Path ([System.IO.Path]::GetTempPath()) ('GitGlideGUI-tags-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:TempRepo | Out-Null
        git -C $script:TempRepo init -b main | Out-Null
        git -C $script:TempRepo config user.email 'git-glide-gui@example.invalid' | Out-Null
        git -C $script:TempRepo config user.name 'Git Glide GUI Tests' | Out-Null
        Set-Content -Path (Join-Path $script:TempRepo 'README.md') -Value '# tag test repo'
        git -C $script:TempRepo add README.md | Out-Null
        git -C $script:TempRepo commit -m 'initial commit' | Out-Null
    }

    AfterEach {
        if ($script:TempRepo -and (Test-Path $script:TempRepo)) {
            Remove-Item -LiteralPath $script:TempRepo -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'creates an annotated tag using the generated plan' {
        $plan = Get-GgtCreateTagCommandPlan -TagName 'v3.1.0' -Message 'Release v3.1.0' -Annotated
        $gitArgs = @('-C', $script:TempRepo) + @($plan.Arguments)
        & git @gitArgs | Out-Null
        $LASTEXITCODE | Should -Be 0

        $type = git -C $script:TempRepo for-each-ref refs/tags/v3.1.0 --format='%(objecttype)'
        $type | Should -Be 'tag'
    }

    It 'creates a lightweight tag using the generated plan' {
        $plan = Get-GgtCreateTagCommandPlan -TagName 'v3.1-light' -Annotated:$false
        $gitArgs = @('-C', $script:TempRepo) + @($plan.Arguments)
        & git @gitArgs | Out-Null
        $LASTEXITCODE | Should -Be 0

        $type = git -C $script:TempRepo for-each-ref refs/tags/v3.1-light --format='%(objecttype)'
        $type | Should -Be 'commit'
    }

    It 'deletes only the selected local tag through the safe delete plan' {
        git -C $script:TempRepo tag v3.1-delete | Out-Null
        $guidance = Get-GgtTagDeleteSafetyGuidance -TagName 'v3.1-delete'
        $guidance.Preview | Should -Match 'git tag -d v3.1-delete'
        foreach ($plan in @($guidance.Plans)) {
            $gitArgs = @('-C', $script:TempRepo) + @($plan.Arguments)
            & git @gitArgs | Out-Null
            $LASTEXITCODE | Should -Be 0
        }
        $exists = git -C $script:TempRepo tag --list v3.1-delete
        @($exists).Count | Should -Be 0
    }

    It 'builds tag command previews without executing remote push commands' {
        (Get-GgtPushTagCommandPlan -TagName 'v3.1.0').Display | Should -Be 'git push origin v3.1.0'
        (Get-GgtPushAllTagsCommandPlan).Display | Should -Be 'git push origin --tags'
        (Get-GgtDeleteRemoteTagCommandPlan -TagName 'v3.1.0').Display | Should -Be 'git push origin --delete v3.1.0'
    }
}
