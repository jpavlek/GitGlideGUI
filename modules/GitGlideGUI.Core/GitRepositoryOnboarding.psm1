<#
GitRepositoryOnboarding.psm1
UI-free onboarding helpers for Git Glide GUI.

The WinForms script owns dialogs and execution; this module owns predictable,
testable onboarding decisions and generated content.
#>

function Get-GggGitIgnoreTemplateNames {
    return @('General / Windows', 'PowerShell', 'C++ / CMake', 'Unreal Engine', 'Python', 'Node / Web', 'Visual Studio')
}

function Get-GggGitIgnoreTemplateContent {
    param([string]$TemplateName)

    switch -Regex ([string]$TemplateName) {
        'Unreal' {
            $lines = @(
                '# Git Glide GUI .gitignore template: Unreal Engine',
                'Binaries/',
                'DerivedDataCache/',
                'Intermediate/',
                'Saved/',
                '.vs/',
                '*.sln',
                '*.VC.db',
                '*.opensdf',
                '*.sdf',
                '*.suo',
                '*.user',
                '*.userosscache',
                '*.sln.docstates',
                'Plugins/*/Intermediate/',
                'Plugins/*/Binaries/'
            )
            break
        }
        'C\+\+|CMake' {
            $lines = @(
                '# Git Glide GUI .gitignore template: C++ / CMake',
                'build/',
                'out/',
                'cmake-build-*/',
                'CMakeFiles/',
                'CMakeCache.txt',
                'compile_commands.json',
                '*.obj',
                '*.o',
                '*.exe',
                '*.dll',
                '*.lib',
                '*.pdb',
                '.vs/',
                '.vscode/'
            )
            break
        }
        'PowerShell' {
            $lines = @(
                '# Git Glide GUI .gitignore template: PowerShell',
                '*.log',
                '*.tmp',
                '*.bak',
                '*.ps1xml.bak',
                '.vscode/',
                'TestResults/',
                'coverage/',
                'GitGlideGUI-Audit.log',
                'GitGlideGUI-Config.json'
            )
            break
        }
        'Python' {
            $lines = @(
                '# Git Glide GUI .gitignore template: Python',
                '__pycache__/',
                '*.py[cod]',
                '.pytest_cache/',
                '.mypy_cache/',
                '.ruff_cache/',
                '.venv/',
                'venv/',
                'dist/',
                'build/',
                '*.egg-info/'
            )
            break
        }
        'Node|Web' {
            $lines = @(
                '# Git Glide GUI .gitignore template: Node / Web',
                'node_modules/',
                'dist/',
                'build/',
                '.next/',
                '.vite/',
                'coverage/',
                '.env',
                '.env.*',
                'npm-debug.log*',
                'yarn-debug.log*',
                'pnpm-debug.log*'
            )
            break
        }
        'Visual Studio' {
            $lines = @(
                '# Git Glide GUI .gitignore template: Visual Studio',
                '.vs/',
                'bin/',
                'obj/',
                '*.user',
                '*.suo',
                '*.VC.db',
                '*.pdb',
                '*.cache',
                'TestResults/'
            )
            break
        }
        default {
            $lines = @(
                '# Git Glide GUI .gitignore template: General / Windows',
                '.DS_Store',
                'Thumbs.db',
                'Desktop.ini',
                '*.log',
                '*.tmp',
                '*.bak',
                '.vscode/',
                '.idea/',
                'build/',
                'dist/'
            )
            break
        }
    }

    return (($lines -join "`r`n") + "`r`n")
}

function Test-GggRemoteName {
    param([string]$RemoteName)
    return -not [string]::IsNullOrWhiteSpace($RemoteName) -and $RemoteName -match '^[A-Za-z0-9._-]+$'
}

function Get-GggRepositoryInitCommandPlan {
    param([string]$InitialBranch = 'main')

    if ([string]::IsNullOrWhiteSpace($InitialBranch)) { $InitialBranch = 'main' }
    return [pscustomobject]@{
        Preferred = @('git', 'init', '-b', $InitialBranch)
        Fallback = @(
            @('git', 'init'),
            @('git', 'branch', '-M', $InitialBranch)
        )
        Preview = "git init -b $InitialBranch`r`nfallback: git init; git branch -M $InitialBranch"
    }
}

function Get-GggFirstCommitCommandPreview {
    param(
        [string]$RemoteName = 'origin',
        [switch]$WithGitIgnore,
        [switch]$WithRemote,
        [switch]$PushAfter
    )

    if ([string]::IsNullOrWhiteSpace($RemoteName)) { $RemoteName = 'origin' }
    $lines = New-Object System.Collections.Generic.List[string]
    if ($WithGitIgnore) { [void]$lines.Add('create or update .gitignore') }
    [void]$lines.Add('git add -A')
    [void]$lines.Add('git commit -F <temp-commit-message-file>')
    if ($WithRemote) { [void]$lines.Add("git remote add $RemoteName <url>") }
    if ($WithRemote -and $PushAfter) { [void]$lines.Add('git push -u origin HEAD') }
    return ($lines -join "`r`n")
}

Export-ModuleMember -Function Get-GggGitIgnoreTemplateNames, Get-GggGitIgnoreTemplateContent, Test-GggRemoteName, Get-GggRepositoryInitCommandPlan, Get-GggFirstCommitCommandPreview
