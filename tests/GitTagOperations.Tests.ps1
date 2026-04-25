$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
Import-Module (Join-Path $root 'modules/GitGlideGUI.Core/GitTagOperations.psm1') -Force

Describe 'GitTagOperations module' {
    It 'validates tag names' {
        (Test-GgtTagName -Name 'v3.1.0').Valid | Should -BeTrue
        (Test-GgtTagName -Name 'release/2026-04-25').Valid | Should -BeTrue
        (Test-GgtTagName -Name '').Valid | Should -BeFalse
        (Test-GgtTagName -Name 'bad tag').Valid | Should -BeFalse
        (Test-GgtTagName -Name 'bad..tag').Valid | Should -BeFalse
        (Test-GgtTagName -Name '-bad').Valid | Should -BeFalse
    }

    It 'extracts selected tag names from display lines' {
        Get-GgtSelectedTagNameFromDisplayLine -DisplayLine 'v3.1.0 | tag | 2026-04-25 | Release v3.1' | Should -Be 'v3.1.0'
        Get-GgtSelectedTagNameFromDisplayLine -DisplayLine '(No tags found)' | Should -Be ''
    }

    It 'builds annotated and lightweight tag command previews' {
        $annotated = Get-GgtCreateTagCommandPlan -TagName 'v3.1.0' -Message 'Release v3.1.0' -Annotated
        $annotated.Display | Should -Be 'git tag -a v3.1.0 -m <message>'
        (@($annotated.Arguments) -contains '-a') | Should -BeTrue

        $lightweight = Get-GgtCreateTagCommandPlan -TagName 'v3.1-light' -Annotated:$false
        $lightweight.Display | Should -Be 'git tag v3.1-light'
        (@($lightweight.Arguments) -notcontains '-a') | Should -BeTrue
    }

    It 'builds push, delete, checkout and branch command previews' {
        (Get-GgtPushTagCommandPlan -TagName 'v3.1.0').Display | Should -Be 'git push origin v3.1.0'
        (Get-GgtDeleteLocalTagCommandPlan -TagName 'v3.1.0').Display | Should -Be 'git tag -d v3.1.0'
        (Get-GgtDeleteRemoteTagCommandPlan -TagName 'v3.1.0').Display | Should -Be 'git push origin --delete v3.1.0'
        (Get-GgtCheckoutTagCommandPlan -TagName 'v3.1.0').Display | Should -Be 'git checkout v3.1.0'
        (Get-GgtBranchFromTagCommandPlan -BranchName 'release/from-tag' -TagName 'v3.1.0').Display | Should -Be 'git checkout -b release/from-tag v3.1.0'
    }

    It 'explains local delete safety and remote delete risk' {
        $local = Get-GgtTagDeleteSafetyGuidance -TagName 'v3.1.0'
        $local.Severity | Should -Be 'warning'
        $local.Preview | Should -Match 'git tag -d v3.1.0'

        $remote = Get-GgtTagDeleteSafetyGuidance -TagName 'v3.1.0' -DeleteRemote
        $remote.Severity | Should -Be 'danger'
        $remote.Preview | Should -Match 'git push origin --delete v3.1.0'
    }
}
