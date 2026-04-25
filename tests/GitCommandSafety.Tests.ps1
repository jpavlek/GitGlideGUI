# Requires Pester 5.x when available. These tests are UI-free and can run without launching WinForms.
$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot '..\modules\GitGlideGUI.Core\GitCommandSafety.psm1'
Import-Module $modulePath -Force

Describe 'GitCommandSafety parser' {
    It 'strips optional leading git word' {
        Convert-GfgGitCommandTextToArgs 'git status -sb' | Should -Be @('status','-sb')
    }

    It 'strips user-supplied git -C path prefix' {
        Convert-GfgGitCommandTextToArgs 'git -C C:\repo status -sb' | Should -Be @('status','-sb')
    }

    It 'keeps quoted arguments together' {
        Convert-GfgGitCommandTextToArgs 'commit -m "hello world"' | Should -Be @('commit','-m','hello world')
    }

    It 'rejects shell operators' {
        { Convert-GfgGitCommandTextToArgs 'status && git clean -fdx' } | Should -Throw
    }

    It 'rejects multiline commands' {
        { Convert-GfgGitCommandTextToArgs "status`nclean -fdx" } | Should -Throw
    }
}

Describe 'GitCommandSafety allowlist and risk detection' {
    It 'allows configured safe subcommands' {
        Test-GfgCustomGitArgsAllowed -Arguments @('status','-sb') -AllowedSubcommands @('status','log') | Should -BeTrue
    }

    It 'rejects non-allowlisted subcommands' {
        { Test-GfgCustomGitArgsAllowed -Arguments @('gc','--aggressive') -AllowedSubcommands @('status','log') } | Should -Throw
    }

    It 'marks reset --hard as destructive' {
        Test-GfgGitArgsPotentiallyDestructive -Arguments @('reset','--hard','HEAD') | Should -BeTrue
    }

    It 'marks status as non-destructive' {
        Test-GfgGitArgsPotentiallyDestructive -Arguments @('status','-sb') | Should -BeFalse
    }

    It 'marks force push as destructive' {
        Test-GfgGitArgsPotentiallyDestructive -Arguments @('push','--force','origin','main') | Should -BeTrue
    }
}

Describe 'Git reference validation' {
    It 'accepts normal semantic version tags' {
        (Test-GfgGitRefName -Name 'v2.2.0' -Kind 'Tag').Valid | Should -BeTrue
    }

    It 'rejects tags with spaces' {
        (Test-GfgGitRefName -Name 'bad tag' -Kind 'Tag').Valid | Should -BeFalse
    }

    It 'rejects lock suffixes' {
        (Test-GfgGitRefName -Name 'release.lock' -Kind 'Tag').Valid | Should -BeFalse
    }
}
