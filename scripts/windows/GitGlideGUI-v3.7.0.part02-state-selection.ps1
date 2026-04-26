# This file is part of Git Glide GUI v3.7.0 split-script architecture.
# It is dot-sourced by GitGlideGUI-v3.7.0.ps1.

#region Script Variables

$script:RepoRoot = Get-RepoRoot -ScriptRoot $PSScriptRoot -RequestedRepositoryPath $RepositoryPath
$script:CurrentBranch = ''
$script:CurrentUpstream = ''
$script:CurrentBranchState = ''
$script:StatusItems = @()
$script:StashList = @()
$script:FontMono = New-Object System.Drawing.Font('Consolas', 10)
$script:UiFont = New-Object System.Drawing.Font('Segoe UI', 9)
$script:UiFontBold = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
$script:ToolTip = New-Object System.Windows.Forms.ToolTip
$script:ToolTip.AutoPopDelay = 30000
$script:ToolTip.InitialDelay = 200
$script:ToolTip.ReshowDelay = 100
$script:LastCommandSummary = ''
$script:LastCommandArgs = @()
$script:CurrentProcess = $null
$script:CancelRequested = $false
$script:SuppressDiffPreview = $false
$script:CustomGitButtons = Get-CustomGitButtonDefinitions
$script:ThemeCatalog = Get-ThemeColorCatalog

#endregion

#region Logging Functions

function Append-Log {
    param(
        [string]$Text,
        [System.Drawing.Color]$Color = [System.Drawing.Color]::Black
    )
    if ([string]::IsNullOrEmpty($Text)) { return }
    if (-not $script:LogTextBox) { return }

    if ($script:LogTextBox.InvokeRequired) {
        $action = [System.Action[string, System.Drawing.Color]]{
            param($value, $clr)
            Append-Log -Text $value -Color $clr
        }
        [void]$script:LogTextBox.BeginInvoke($action, $Text, $Color)
        return
    }

    $resolvedColor = $Color
    try {
        if ($Color.ToArgb() -eq [System.Drawing.Color]::Black.ToArgb()) {
            $resolvedColor = Get-ThemeColor -Key 'LogText' -Fallback '#111827'
        } elseif ($Color.ToArgb() -eq [System.Drawing.Color]::Firebrick.ToArgb() -or $Color.ToArgb() -eq [System.Drawing.Color]::DarkRed.ToArgb()) {
            $resolvedColor = Get-ThemeColor -Key 'ErrorText' -Fallback '#991B1B'
        } elseif ($Color.ToArgb() -eq [System.Drawing.Color]::DarkOrange.ToArgb()) {
            $resolvedColor = Get-ThemeColor -Key 'WarningText' -Fallback '#B45309'
        } elseif ($Color.ToArgb() -eq [System.Drawing.Color]::DarkGreen.ToArgb()) {
            $resolvedColor = Get-ThemeColor -Key 'SuccessText' -Fallback '#166534'
        } elseif ($Color.ToArgb() -eq [System.Drawing.Color]::DarkBlue.ToArgb()) {
            $resolvedColor = Get-ThemeColor -Key 'AccentText' -Fallback '#1D4ED8'
        } elseif ($Color.ToArgb() -eq [System.Drawing.Color]::DarkGray.ToArgb()) {
            $resolvedColor = Get-ThemeColor -Key 'MutedTextColor' -Fallback '#4B5563'
        }
    } catch {}

    $script:LogTextBox.SelectionStart = $script:LogTextBox.TextLength
    $script:LogTextBox.SelectionLength = 0
    $script:LogTextBox.SelectionColor = $resolvedColor
    $script:LogTextBox.AppendText($Text)
    if (-not $Text.EndsWith("`r`n")) {
        $script:LogTextBox.AppendText("`r`n")
    }
    $script:LogTextBox.SelectionColor = Get-ThemeColor -Key 'LogText' -Fallback '#111827'
    $script:LogTextBox.SelectionStart = $script:LogTextBox.TextLength
    $script:LogTextBox.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

function Set-StatusBar {
    param([string]$Text)
    if ($script:StatusValueLabel -and $script:StatusValueLabel.Owner -and $script:StatusValueLabel.Owner.InvokeRequired) {
        $action = [System.Action[string]]{ param($value) Set-StatusBar $value }
        [void]$form.BeginInvoke($action, $Text)
        return
    }
    if ($script:StatusValueLabel) {
        $script:StatusValueLabel.Text = $Text
    }
}

function Set-CommandPreview {
    param(
        [string]$Title,
        [string]$Commands,
        [string]$Notes = ''
    )
    if (-not $script:PreviewTextBox) { return }

    $normalizedCommands = if ($null -eq $Commands) { '' } else { [string]$Commands }
    $parts = @()
    if ($Title) { $parts += $Title }
    $parts += ('Repo: ' + $script:RepoRoot)
    $parts += ''
    $parts += 'Commands to run:'
    $parts += ($normalizedCommands -replace "`r?`n","`r`n")
    if ($Notes) {
        $parts += ''
        $parts += 'Notes:'
        $parts += $Notes
    }
    $script:PreviewTextBox.Text = ($parts -join "`r`n")
}

#endregion

#region Git State Verification

function Test-GitRepository {
    try {
        if ([string]::IsNullOrWhiteSpace($script:RepoRoot)) { return $false }
        $result = & git -C $script:RepoRoot rev-parse --git-dir 2>$null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function Set-RepositoryRoot {
    param(
        [string]$Path,
        [switch]$Refresh,
        [switch]$OfferInitialize
    )

    $resolvedRoot = Resolve-GitRepositoryRoot -Path $Path
    if (-not $resolvedRoot) {
        if ($OfferInitialize) {
            $choice = [System.Windows.Forms.MessageBox]::Show(
                "The selected folder is not inside a Git repository:`r`n$Path`r`n`r`nWould you like to initialize a new Git repository in this folder?",
                'Initialize new repository?',
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )
            if ($choice -eq [System.Windows.Forms.DialogResult]::Yes) {
                return (Initialize-NewRepository -Path $Path -Refresh:$Refresh)
            }
        }
        [System.Windows.Forms.MessageBox]::Show("The selected folder is not inside a Git repository:`r`n$Path", 'Not a Git repository', 'OK', 'Warning') | Out-Null
        Set-SuggestedNextAction -Text 'Open existing repo elsewhere, or init this folder as a new repository.' -Action 'choose-repo'
        return $false
    }

    $script:RepoRoot = $resolvedRoot
    Set-ConfigValue -Name 'LastRepositoryRoot' -Value $resolvedRoot
    Save-Config -Config $script:Config
    Write-AuditLog -Message ("REPOSITORY_SELECTED | RepoRoot='{0}'" -f $resolvedRoot)

    if ($script:RepoPathValueLabel) { $script:RepoPathValueLabel.Text = $resolvedRoot }
    if ($script:BranchValueLabel) { $script:BranchValueLabel.Text = '-' }
    if ($script:UpstreamValueLabel) { $script:UpstreamValueLabel.Text = '-' }
    if ($script:BranchStateValueLabel) { $script:BranchStateValueLabel.Text = '-' }
    if ($script:WorkingTreeValueLabel) { $script:WorkingTreeValueLabel.Text = '-' }
    if ($script:ChangedCountValueLabel) { $script:ChangedCountValueLabel.Text = '0' }
    Set-SuggestedNextAction -Text 'Repository selected. Refreshing status...'
    Append-Log -Text ("Repository selected: $resolvedRoot") -Color ([System.Drawing.Color]::DarkGreen)

    if ($Refresh) {
        Load-TagList
        Refresh-Status
    }

    return $true
}

function Initialize-NewRepository {
    param(
        [string]$Path,
        [switch]$Refresh
    )

    $resolvedPath = Resolve-ExistingDirectoryPath -Path $Path
    if (-not $resolvedPath) {
        [System.Windows.Forms.MessageBox]::Show("Select an existing folder before initializing a new repository:`r`n$Path", 'Folder not found', 'OK', 'Warning') | Out-Null
        Set-SuggestedNextAction -Text 'Choose an existing folder to initialize as a new Git repository.'
        return $false
    }

    $existingRoot = Resolve-GitRepositoryRoot -Path $resolvedPath
    if ($existingRoot) {
        return (Set-RepositoryRoot -Path $existingRoot -Refresh:$Refresh)
    }

    if (Test-DirectoryHasUserFiles -Path $resolvedPath) {
        $confirmNonEmpty = [System.Windows.Forms.MessageBox]::Show(
            "This folder already contains files:`r`n$resolvedPath`r`n`r`nInitializing Git here is usually safe, but it will create a .git folder and start tracking this folder as a repository. Continue?",
            'Initialize non-empty folder?',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($confirmNonEmpty -ne [System.Windows.Forms.DialogResult]::Yes) {
            Set-SuggestedNextAction -Text 'New repository initialization cancelled.'
            return $false
        }
    }

    $initialBranch = [string]$script:Config.MainBranch
    if ([string]::IsNullOrWhiteSpace($initialBranch)) { $initialBranch = 'main' }

    Append-Log -Text ("Initializing new Git repository in: $resolvedPath") -Color ([System.Drawing.Color]::DarkBlue)
    Write-AuditLog -Message ("INIT_REPOSITORY_REQUESTED | Path='{0}' | InitialBranch='{1}'" -f $resolvedPath, $initialBranch)

    $initResult = Run-External -FileName 'git' -Arguments @('init', '-b', $initialBranch) -WorkingDirectory $resolvedPath -Caption ("git init -b $initialBranch") -AllowFailure -ShowProgress
    if ($initResult.ExitCode -ne 0) {
        Append-Log -Text 'git init -b failed; retrying with git init and branch rename for older Git versions.' -Color ([System.Drawing.Color]::DarkOrange)
        $initResult = Run-External -FileName 'git' -Arguments @('init') -WorkingDirectory $resolvedPath -Caption 'git init' -AllowFailure -ShowProgress
        if ($initResult.ExitCode -eq 0) {
            [void](Run-External -FileName 'git' -Arguments @('-C', $resolvedPath, 'branch', '-M', $initialBranch) -Caption ("git branch -M $initialBranch") -AllowFailure)
        }
    }

    if ($initResult.ExitCode -ne 0) {
        Set-SuggestedNextAction -Text 'Git repository initialization failed. Check the Output tab.'
        [System.Windows.Forms.MessageBox]::Show('Git repository initialization failed. Check the Output tab for details.', 'git init failed', 'OK', 'Error') | Out-Null
        return $false
    }

    $script:RepoRoot = $resolvedPath
    Set-ConfigValue -Name 'LastRepositoryRoot' -Value $resolvedPath
    Save-Config -Config $script:Config
    Write-AuditLog -Message ("REPOSITORY_INITIALIZED | RepoRoot='{0}'" -f $resolvedPath)
    Append-Log -Text ("New Git repository initialized: $resolvedPath") -Color ([System.Drawing.Color]::DarkGreen)
    Set-SuggestedNextAction -Text 'New repository created. Add files, make the first commit, and optionally add a remote.' -Action 'first-commit'

    if ($script:RepoPathValueLabel) { $script:RepoPathValueLabel.Text = $resolvedPath }
    if ($script:BranchValueLabel) { $script:BranchValueLabel.Text = $initialBranch }
    if ($script:UpstreamValueLabel) { $script:UpstreamValueLabel.Text = '(none)' }
    if ($script:BranchStateValueLabel) { $script:BranchStateValueLabel.Text = 'new repository' }
    if ($script:WorkingTreeValueLabel) { $script:WorkingTreeValueLabel.Text = 'clean' }
    if ($script:ChangedCountValueLabel) { $script:ChangedCountValueLabel.Text = '0' }

    if ($Refresh) {
        Load-TagList
        Refresh-Status
    }

    return $true
}


function Get-GitIgnoreTemplateNames {
    try {
        $cmd = Get-Command Get-GggGitIgnoreTemplateNames -ErrorAction SilentlyContinue
        if ($cmd) { return @(Get-GggGitIgnoreTemplateNames) }
    } catch {}
    return @('General / Windows', 'PowerShell', 'C++ / CMake', 'Unreal Engine', 'Python', 'Node / Web', 'Visual Studio')
}

function Get-GitIgnoreTemplateContent {
    param([string]$TemplateName)

    try {
        $cmd = Get-Command Get-GggGitIgnoreTemplateContent -ErrorAction SilentlyContinue
        if ($cmd) { return (Get-GggGitIgnoreTemplateContent -TemplateName $TemplateName) }
    } catch {}

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

function Write-GitIgnoreTemplate {
    param(
        [string]$TemplateName,
        [switch]$Append
    )

    if (-not (Test-GitRepository)) {
        Set-SuggestedNextAction -Text 'Open or initialize a repository before creating .gitignore.' -Action 'choose-repo'
        [System.Windows.Forms.MessageBox]::Show('Open or initialize a Git repository first.', 'No repository selected', 'OK', 'Warning') | Out-Null
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($TemplateName)) { $TemplateName = [string]$script:Config.DefaultGitIgnoreTemplate }
    if ([string]::IsNullOrWhiteSpace($TemplateName)) { $TemplateName = 'General / Windows' }

    $gitignorePath = Join-Path $script:RepoRoot '.gitignore'
    $template = Get-GitIgnoreTemplateContent -TemplateName $TemplateName
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    try {
        if (Test-Path -LiteralPath $gitignorePath) {
            if (-not $Append) {
                $confirmReplace = [System.Windows.Forms.MessageBox]::Show(
                    ".gitignore already exists:`r`n$gitignorePath`r`n`r`nReplace it with the selected template?",
                    'Replace .gitignore?',
                    [System.Windows.Forms.MessageBoxButtons]::YesNo,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                )
                if ($confirmReplace -ne [System.Windows.Forms.DialogResult]::Yes) { return $false }
                [System.IO.File]::WriteAllText($gitignorePath, $template, $utf8NoBom)
            } else {
                $existing = [System.IO.File]::ReadAllText($gitignorePath)
                $templateLines = @($template -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
                $missing = @()
                foreach ($line in $templateLines) {
                    if ($existing -notlike "*$line*") { $missing += $line }
                }
                if ($missing.Count -eq 0) {
                    Append-Log -Text '.gitignore already contains the selected template entries.' -Color ([System.Drawing.Color]::DarkGray)
                } else {
                    $appendText = "`r`n# Added by Git Glide GUI: $TemplateName`r`n" + (($missing -join "`r`n") + "`r`n")
                    [System.IO.File]::AppendAllText($gitignorePath, $appendText, $utf8NoBom)
                }
            }
        } else {
            [System.IO.File]::WriteAllText($gitignorePath, $template, $utf8NoBom)
        }

        Set-ConfigValue -Name 'DefaultGitIgnoreTemplate' -Value $TemplateName
        Save-Config -Config $script:Config
        Write-AuditLog -Message ("GITIGNORE_TEMPLATE_APPLIED | RepoRoot='{0}' | Template='{1}'" -f $script:RepoRoot, $TemplateName)
        Append-Log -Text (".gitignore template applied: $TemplateName") -Color ([System.Drawing.Color]::DarkGreen)
        Set-SuggestedNextAction -Text '.gitignore is ready. Stage it with your intended project files and make the first commit.' -Action 'first-commit'
        Refresh-Status
        return $true
    } catch {
        Append-Log -Text ('Failed to write .gitignore: ' + $_.Exception.Message) -Color ([System.Drawing.Color]::Firebrick)
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Could not write .gitignore', 'OK', 'Error') | Out-Null
        return $false
    }
}

function Show-GitIgnoreTemplateDialog {
    if (-not (Test-GitRepository)) {
        [void](Ensure-RepositorySelected)
        if (-not (Test-GitRepository)) { return $false }
    }

    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = 'Create or update .gitignore'
    $dialog.StartPosition = 'CenterParent'
    $dialog.Width = 470
    $dialog.Height = 220
    $dialog.MinimizeBox = $false
    $dialog.MaximizeBox = $false
    $dialog.FormBorderStyle = 'FixedDialog'

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = 'Fill'
    $layout.Padding = New-Object System.Windows.Forms.Padding(12)
    $layout.ColumnCount = 2
    $layout.RowCount = 4
    [void]$layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize)))
    [void]$layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $dialog.Controls.Add($layout)

    $label = New-Object System.Windows.Forms.Label
    $label.Text = 'Template:'
    $label.AutoSize = $true
    $label.Margin = New-Object System.Windows.Forms.Padding(4, 8, 8, 4)
    $layout.Controls.Add($label, 0, 0)

    $combo = New-Object System.Windows.Forms.ComboBox
    $combo.DropDownStyle = 'DropDownList'
    [void]$combo.Items.AddRange((Get-GitIgnoreTemplateNames))
    $preferred = [string]$script:Config.DefaultGitIgnoreTemplate
    if (-not [string]::IsNullOrWhiteSpace($preferred) -and $combo.Items.Contains($preferred)) { $combo.SelectedItem = $preferred } else { $combo.SelectedIndex = 0 }
    $combo.Dock = 'Fill'
    $layout.Controls.Add($combo, 1, 0)

    $append = New-Object System.Windows.Forms.CheckBox
    $append.Text = 'Append missing entries if .gitignore already exists'
    $append.Checked = $true
    $append.AutoSize = $true
    $append.Margin = New-Object System.Windows.Forms.Padding(4, 8, 4, 4)
    $layout.Controls.Add($append, 1, 1)

    $help = New-WrappingLabel -Text 'Use this before the first commit to avoid committing build output, local settings, IDE caches, logs, or generated files.' -Height 45
    $layout.Controls.Add($help, 0, 2)
    $layout.SetColumnSpan($help, 2)

    $buttons = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttons.FlowDirection = 'RightToLeft'
    $buttons.Dock = 'Fill'
    $layout.Controls.Add($buttons, 0, 3)
    $layout.SetColumnSpan($buttons, 2)

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'Create / update .gitignore'
    $ok.Width = 180
    $ok.Height = 32
    $ok.Add_Click({ $dialog.DialogResult = [System.Windows.Forms.DialogResult]::OK; $dialog.Close() })
    $buttons.Controls.Add($ok)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Cancel'
    $cancel.Width = 90
    $cancel.Height = 32
    $cancel.Add_Click({ $dialog.DialogResult = [System.Windows.Forms.DialogResult]::Cancel; $dialog.Close() })
    $buttons.Controls.Add($cancel)

    $result = $dialog.ShowDialog($form)
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return (Write-GitIgnoreTemplate -TemplateName ([string]$combo.SelectedItem) -Append:([bool]$append.Checked))
    }
    return $false
}

function Test-GitHasCommits {
    if (-not (Test-GitRepository)) { return $false }
    try {
        $null = & git -C $script:RepoRoot rev-parse --verify HEAD 2>$null
        return $LASTEXITCODE -eq 0
    } catch { return $false }
}

function Get-UnstageGitArgumentsForPath {
    param([Parameter(Mandatory=$true)][string]$Path)

    # Before the first commit, HEAD does not exist. `git restore --staged`
    # fails with `fatal: could not resolve HEAD`. For an unborn repository,
    # unstaging a newly added file means removing it from the index while
    # keeping the working-tree file.
    if (-not (Test-GitHasCommits)) {
        return @('rm','--cached','--',$Path)
    }

    return @('restore','--staged','--',$Path)
}

function Get-GitHubDefaultDescription {
    try {
        $cmd = Get-Command Get-GghubDefaultRepositoryDescription -ErrorAction SilentlyContinue
        if ($cmd) { return (Get-GghubDefaultRepositoryDescription) }
    } catch {}
    return 'Git Glide GUI is a lightweight, privacy-first Windows Git interface for safer human and AI-assisted software development. It turns fast coding changes into clear versioning choices, helping developers stay in control and use their judgment with command previews, visual staging, recovery guidance, custom actions, and code & documentation checks.'
}

function Get-GitHubRemoteUrlSafe {
    param(
        [string]$Owner,
        [string]$Repository,
        [string]$Protocol = 'HTTPS'
    )
    try {
        $cmd = Get-Command New-GghubRemoteUrl -ErrorAction SilentlyContinue
        if ($cmd) { return (New-GghubRemoteUrl -Owner $Owner -Repository $Repository -Protocol $Protocol) }
    } catch { throw }
    $ownerText = ([string]$Owner).Trim()
    $repoText = ([string]$Repository).Trim()
    if ($Protocol -eq 'SSH') { return "git@github.com:$ownerText/$repoText.git" }
    return "https://github.com/$ownerText/$repoText.git"
}

function Show-GitHubPrivacyGuidance {
    try {
        $cmd = Get-Command Get-GghubPrivacyChecklist -ErrorAction SilentlyContinue
        if ($cmd) {
            $lines = Get-GghubPrivacyChecklist -PrivateRepositoryRecommended -ReviewCopilotTrainingOptOut
            [System.Windows.Forms.MessageBox]::Show(($lines -join "`r`n`r`n"), 'GitHub privacy checklist', 'OK', 'Information') | Out-Null
            return
        }
    } catch {}
    [System.Windows.Forms.MessageBox]::Show('Recommended: create the GitHub repository as Private for proprietary/client work, do not initialize it with README/.gitignore/license when pushing an existing local repository, and review GitHub Copilot settings if you want to opt out of AI training/data use where your plan allows it.', 'GitHub privacy checklist', 'OK', 'Information') | Out-Null
}

function Open-GitHubNewRepositoryPage {
    try {
        $url = 'https://github.com/new'
        $cmd = Get-Command Get-GghubNewRepositoryUrl -ErrorAction SilentlyContinue
        if ($cmd) { $url = Get-GghubNewRepositoryUrl }
        Start-Process $url
    } catch {
        [System.Windows.Forms.MessageBox]::Show('Open https://github.com/new in your browser.', 'Open GitHub', 'OK', 'Information') | Out-Null
    }
}

function Open-GitHubCopilotSettingsPage {
    try {
        $url = 'https://github.com/settings/copilot'
        $cmd = Get-Command Get-GghubCopilotSettingsUrl -ErrorAction SilentlyContinue
        if ($cmd) { $url = Get-GghubCopilotSettingsUrl }
        Start-Process $url
    } catch {
        [System.Windows.Forms.MessageBox]::Show('Open GitHub account settings, then review Copilot settings and AI/data training options.', 'Open Copilot settings', 'OK', 'Information') | Out-Null
    }
}

function Copy-GitHubRepositoryDescription {
    param([string]$Description)
    try {
        [System.Windows.Forms.Clipboard]::SetText([string]$Description)
        Set-SuggestedNextAction -Text 'GitHub repository description copied. Paste it into GitHub when creating the repository.'
    } catch {
        [System.Windows.Forms.MessageBox]::Show('Could not copy to clipboard. Select and copy the text manually.', 'Copy failed', 'OK', 'Warning') | Out-Null
    }
}

function Build-GitHubPublishPreview {
    try {
        $cmd = Get-Command Get-GghubPublishCommandPreview -ErrorAction SilentlyContinue
        if ($cmd) { return (Get-GghubPublishCommandPreview -Owner '<owner>' -Repository '<repo>' -Protocol 'HTTPS' -RemoteName ([string]$script:Config.DefaultRemoteName) -PushAfter) }
    } catch {}
    return "open https://github.com/new`r`ncreate an empty private repository`r`ngit remote add origin https://github.com/<owner>/<repo>.git`r`noptional: git push -u origin HEAD"
}


function Build-GitHubDiagnosticsPreview {
    return @(
        'git remote -v',
        'git branch --show-current',
        'git rev-parse --abbrev-ref --symbolic-full-name @{u}',
        'git ls-remote --heads origin',
        'git push -u origin HEAD'
    ) -join "`r`n"
}

function Get-CurrentRemoteUrl {
    param([string]$RemoteName = 'origin')
    try {
        $result = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'remote', 'get-url', $RemoteName) -Caption ("git remote get-url $RemoteName") -AllowFailure -QuietOutput
        if ($result.ExitCode -eq 0) { return ([string]$result.StdOut).Trim() }
    } catch {}
    return ''
}


function Build-BranchTrackingPreview {
    if (Get-Command Get-GgbBranchTrackingCommandPlan -ErrorAction SilentlyContinue) { return (Get-GgbBranchTrackingCommandPlan).Display }
    return 'git branch -vv'
}

function Build-SyncMainIntoDevelopPreview {
    if (Get-Command Get-GgbSyncMainIntoBaseCommandPlan -ErrorAction SilentlyContinue) {
        return (ConvertTo-GgbCommandPreview -Plans (Get-GgbSyncMainIntoBaseCommandPlan -MainBranch $script:Config.MainBranch -BaseBranch $script:Config.BaseBranch))
    }
    return "git switch $($script:Config.MainBranch)`r`ngit pull --ff-only`r`ngit switch $($script:Config.BaseBranch)`r`ngit pull --ff-only`r`ngit merge $($script:Config.MainBranch)`r`ngit push -u origin $($script:Config.BaseBranch)"
}

function Get-SelectedIntegrationFeatureBranch {
    $branch = ''
    if ($script:IntegrationFeatureBranchComboBox) { $branch = $script:IntegrationFeatureBranchComboBox.Text.Trim() }
    if ([string]::IsNullOrWhiteSpace($branch)) { $branch = '<feature-branch>' }
    return $branch
}

function Build-MergeSelectedFeatureIntoDevelopPreview {
    $featureBranch = Get-SelectedIntegrationFeatureBranch
    if (Get-Command Get-GgbMergeNamedFeatureIntoBaseCommandPlan -ErrorAction SilentlyContinue) {
        return (ConvertTo-GgbCommandPreview -Plans (Get-GgbMergeNamedFeatureIntoBaseCommandPlan -FeatureBranch $featureBranch -BaseBranch $script:Config.BaseBranch))
    }
    return "git switch $($script:Config.BaseBranch)`r`ngit pull --ff-only`r`ngit merge --no-ff $featureBranch`r`ngit push -u origin $($script:Config.BaseBranch)"
}

function Build-RunQualityChecksPreview {
    return 'scripts\windows\run-quality-checks.bat'
}

function Build-MergeWorkflowGuidePreview {
    if (Get-Command Get-GgbGitFlowMergeAndPublishGuide -ErrorAction SilentlyContinue) {
        return (Get-GgbGitFlowMergeAndPublishGuide -MainBranch $script:Config.MainBranch -BaseBranch $script:Config.BaseBranch -FeatureBranch (Get-SelectedIntegrationFeatureBranch))
    }
    return "git branch -vv`r`ngit push -u origin HEAD`r`ngit switch $($script:Config.BaseBranch)`r`ngit merge --no-ff <feature-branch>`r`nscripts\windows\run-quality-checks.bat`r`ngit switch $($script:Config.MainBranch)`r`ngit merge --no-ff $($script:Config.BaseBranch)"
}

function Build-MergeWorkflowChecklistPreview {
    $featureBranch = Get-SelectedIntegrationFeatureBranch
    if (Get-Command Get-GgbWorkflowChecklist -ErrorAction SilentlyContinue) {
        $items = @(Get-GgbWorkflowChecklist -CurrentBranch $script:CurrentBranch -FeatureBranch $featureBranch -MainBranch $script:Config.MainBranch -BaseBranch $script:Config.BaseBranch -Upstream $script:CurrentUpstream -BranchState $script:CurrentBranchState)
        if (Get-Command Format-GgbWorkflowChecklist -ErrorAction SilentlyContinue) {
            return (Format-GgbWorkflowChecklist -Items $items)
        }
    }
    return @(
        '[ ] Check branch tracking: git branch -vv',
        '[ ] Push feature branch: git push -u origin HEAD',
        ('[ ] Merge feature into {0}: git merge --no-ff {1}' -f $script:Config.BaseBranch, $featureBranch),
        '[ ] Run quality checks: scripts\windows\run-quality-checks.bat',
        ('[ ] Promote {0} into {1}: git merge --no-ff {0}' -f $script:Config.BaseBranch, $script:Config.MainBranch),
        '[ ] Push and tag release if appropriate'
    ) -join "`r`n"
}

function Build-CleanupSelectedFeatureBranchPreview {
    $featureBranch = Get-SelectedIntegrationFeatureBranch
    if ([string]::IsNullOrWhiteSpace($featureBranch) -or $featureBranch -eq '<feature-branch>') { return 'select a merged feature/fix branch first' }
    if (Get-Command Get-GgbCleanupMergedBranchCommandPlan -ErrorAction SilentlyContinue) {
        return (ConvertTo-GgbCommandPreview -Plans (Get-GgbCleanupMergedBranchCommandPlan -BranchName $featureBranch -DeleteRemote))
    }
    return "git branch -d $featureBranch`r`ngit push origin --delete $featureBranch"
}

function Get-GitHubRepositoryWebUrlFromRemote {
    param([string]$RemoteUrl)
    try {
        $cmd = Get-Command Get-GghubRepositoryWebUrl -ErrorAction SilentlyContinue
        if ($cmd) { return (Get-GghubRepositoryWebUrl -RemoteUrl $RemoteUrl) }
    } catch {}
    $url = ([string]$RemoteUrl).Trim()
    if ($url -match '^https://github\.com/([^/]+)/(.+?)(?:\.git)?/?$') { return "https://github.com/$($Matches[1])/$($Matches[2])" }
    if ($url -match '^git@github\.com:([^/]+)/(.+?)(?:\.git)?$') { return "https://github.com/$($Matches[1])/$($Matches[2])" }
    return ''
}

function Show-GitHubRemoteFailureGuidance {
    param(
        [object]$Result,
        [string]$Operation = 'GitHub remote operation',
        [string]$RemoteName = 'origin'
    )
    try {
        $stdout = if ($Result -and $Result.StdOut) { [string]$Result.StdOut } else { '' }
        $stderr = if ($Result -and $Result.StdErr) { [string]$Result.StdErr } else { '' }
        $exitCode = if ($Result) { try { [int]$Result.ExitCode } catch { 1 } } else { 1 }
        if (Get-Command Get-GghubRemoteFailureGuidance -ErrorAction SilentlyContinue) {
            $g = Get-GghubRemoteFailureGuidance -ExitCode $exitCode -StdOut $stdout -StdErr $stderr -RemoteName $RemoteName -Operation $Operation
            $steps = (@($g.RecoverySteps) | ForEach-Object { '- ' + [string]$_ }) -join "`r`n"
            $message = [string]$g.Message + "`r`n`r`n" + $steps
            Set-CommandPreview -Title ([string]$g.Title) -Commands ([string]$g.Preview) -Notes ([string]$g.Message)
            Set-SuggestedNextAction -Text ([string]$g.Message)
            Append-Log -Text ('GitHub guidance: ' + [string]$g.Message) -Color ([System.Drawing.Color]::DarkOrange)
            [System.Windows.Forms.MessageBox]::Show($message, [string]$g.Title, 'OK', 'Warning') | Out-Null
            return
        }
    } catch {}
    [System.Windows.Forms.MessageBox]::Show("The $Operation failed. Check that the GitHub repository exists, owner/name are correct, and authentication is valid.", 'GitHub remote guidance', 'OK', 'Warning') | Out-Null
}

function Show-CurrentGitRemotes {
    if (-not (Test-GitRepository)) { [void](Ensure-RepositorySelected); if (-not (Test-GitRepository)) { return } }
    $result = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'remote', '-v') -Caption 'git remote -v' -AllowFailure -QuietOutput
    $text = if ([string]::IsNullOrWhiteSpace([string]$result.StdOut)) { '(No Git remotes are configured yet.)' } else { [string]$result.StdOut }
    Set-CommandPreview -Title 'Current Git remotes' -Commands $text -Notes 'Use GitHub publish or Add remote to configure origin before pushing.'
    [System.Windows.Forms.MessageBox]::Show($text, 'Current Git remotes', 'OK', 'Information') | Out-Null
}

function Test-GitHubRemoteAccess {
    param([string]$RemoteName = 'origin')
    if (-not (Test-GitRepository)) { [void](Ensure-RepositorySelected); if (-not (Test-GitRepository)) { return } }
    $result = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'ls-remote', '--heads', $RemoteName) -Caption ("git ls-remote --heads $RemoteName") -AllowFailure -ShowProgress
    if ($result.ExitCode -eq 0) {
        $output = if ([string]::IsNullOrWhiteSpace([string]$result.StdOut)) { 'Remote is reachable, but no branch heads were returned.' } else { [string]$result.StdOut }
        Set-CommandPreview -Title 'Remote access OK' -Commands $output -Notes "Git can reach remote '$RemoteName'."
        Set-SuggestedNextAction -Text "Remote '$RemoteName' is reachable. Push with upstream if the branch is ready."
        [System.Windows.Forms.MessageBox]::Show("Remote '$RemoteName' is reachable.", 'Remote access OK', 'OK', 'Information') | Out-Null
    } else {
        Show-GitHubRemoteFailureGuidance -Result $result -Operation 'test remote access' -RemoteName $RemoteName
    }
}

function Push-CurrentBranchWithUpstream {
    param([string]$RemoteName = 'origin')
    if (-not (Test-GitRepository)) { [void](Ensure-RepositorySelected); if (-not (Test-GitRepository)) { return } }
    if (-not (Test-GitHasCommits)) {
        [System.Windows.Forms.MessageBox]::Show('Create the first commit before pushing to a remote.', 'No commits yet', 'OK', 'Information') | Out-Null
        return
    }
    $branch = ''
    try { $branch = (& git -C $script:RepoRoot branch --show-current 2>$null | Select-Object -First 1).Trim() } catch {}
    if ([string]::IsNullOrWhiteSpace($branch)) { $branch = 'current branch' }
    $ok = Confirm-GuiAction -Title 'Set upstream and push' -Message ("Run:`r`n`r`ngit push -u $RemoteName HEAD`r`n`r`nThis pushes $branch and records $RemoteName as its upstream remote.") -Icon ([System.Windows.Forms.MessageBoxIcon]::Question)
    if (-not $ok) { return }
    $result = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'push', '-u', $RemoteName, 'HEAD') -Caption ("git push -u $RemoteName HEAD") -AllowFailure -ShowProgress
    if ($result.ExitCode -ne 0) { Show-GitHubRemoteFailureGuidance -Result $result -Operation 'push with upstream' -RemoteName $RemoteName }
    Refresh-Status
}

function Open-GitHubRepositoryPage {
    param([string]$RemoteName = 'origin')
    $remoteUrl = Get-CurrentRemoteUrl -RemoteName $RemoteName
    $webUrl = Get-GitHubRepositoryWebUrlFromRemote -RemoteUrl $remoteUrl
    if ([string]::IsNullOrWhiteSpace($webUrl)) {
        [System.Windows.Forms.MessageBox]::Show("Could not derive a GitHub web URL from remote '$RemoteName'. Configure a GitHub remote first.", 'Open GitHub repository', 'OK', 'Information') | Out-Null
        return
    }
    Start-Process $webUrl
}


function Show-GitHubPullRequestUrlFromResult {
    param([AllowNull()][object]$Result)
    try {
        if (-not $Result) { return }
        $combined = (([string]$Result.StdOut) + "`n" + ([string]$Result.StdErr))
        $urls = @()
        if (Get-Command Get-GghubPullRequestUrlsFromText -ErrorAction SilentlyContinue) {
            $urls = @(Get-GghubPullRequestUrlsFromText -Text $combined)
        } else {
            $urls = @([regex]::Matches($combined, 'https://github\.com/[^\s]+/pull/new/[^\s]+') | ForEach-Object { $_.Value })
        }
        if (@($urls).Count -eq 0) { return }
        $url = [string]$urls[0]
        Set-ConfigValue -Name 'LastPullRequestUrl' -Value $url
        Append-Log -Text ('GitHub pull request URL detected: ' + $url) -Color ([System.Drawing.Color]::DarkGreen)
        Set-SuggestedNextAction -Text 'GitHub offered a pull request URL. Review the pushed branch and open the pull request when ready.' -Action 'open-pr-url'
    } catch { Append-Log -Text ('Could not parse GitHub pull request URL: ' + $_.Exception.Message) -Color ([System.Drawing.Color]::DarkOrange) }
}

function Open-LastPullRequestUrl {
    $url = if ($script:Config.ContainsKey('LastPullRequestUrl')) { [string]$script:Config.LastPullRequestUrl } else { '' }
    if ([string]::IsNullOrWhiteSpace($url)) {
        [System.Windows.Forms.MessageBox]::Show('No pull request URL was detected yet. Push a feature branch to GitHub first.', 'No pull request URL', 'OK', 'Information') | Out-Null
        return
    }
    Start-Process $url | Out-Null
}

function Show-GitHubRemoteDiagnosticsDialog {
    if (-not (Test-GitRepository)) { [void](Ensure-RepositorySelected); if (-not (Test-GitRepository)) { return $false } }

    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = 'GitHub remote diagnostics'
    $dialog.StartPosition = 'CenterParent'
    $dialog.Width = 780
    $dialog.Height = 520
    $dialog.MinimumSize = New-Object System.Drawing.Size(700, 440)
    $dialog.FormBorderStyle = 'Sizable'

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = 'Fill'
    $layout.Padding = New-Object System.Windows.Forms.Padding(12)
    $layout.ColumnCount = 1
    $layout.RowCount = 3
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
    $dialog.Controls.Add($layout)

    $intro = New-WrappingLabel -Text 'Diagnose GitHub remote setup: current remotes, current branch, upstream tracking, remote access, repository-not-found/authentication hints, and push-with-upstream.' -Height 48
    $layout.Controls.Add($intro, 0, 0)

    $output = New-Object System.Windows.Forms.RichTextBox
    $output.Dock = 'Fill'
    $output.Font = $script:FontMono
    $output.ReadOnly = $true
    $output.WordWrap = $false
    $layout.Controls.Add($output, 0, 1)

    $buttons = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttons.FlowDirection = 'RightToLeft'
    $buttons.Dock = 'Fill'
    $buttons.WrapContents = $true
    $layout.Controls.Add($buttons, 0, 2)

    function Refresh-GitHubDiagnosticsText {
        $lines = New-Object System.Collections.Generic.List[string]
        [void]$lines.Add('Repository: ' + [string]$script:RepoRoot)
        $branchResult = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'branch', '--show-current') -Caption 'git branch --show-current' -AllowFailure -QuietOutput
        $branchText = if ($branchResult.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace([string]$branchResult.StdOut)) { ([string]$branchResult.StdOut).Trim() } else { '(unknown)' }
        [void]$lines.Add('Current branch: ' + $branchText)
        $upstreamResult = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}') -Caption 'git rev-parse --abbrev-ref --symbolic-full-name @{u}' -AllowFailure -QuietOutput
        $upstreamText = if ($upstreamResult.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace([string]$upstreamResult.StdOut)) { ([string]$upstreamResult.StdOut).Trim() } else { '(missing - use Set upstream and push)' }
        [void]$lines.Add('Upstream: ' + $upstreamText)
        [void]$lines.Add('')
        [void]$lines.Add('Remotes:')
        $remoteResult = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'remote', '-v') -Caption 'git remote -v' -AllowFailure -QuietOutput
        if ($remoteResult.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace([string]$remoteResult.StdOut)) { [void]$lines.Add(([string]$remoteResult.StdOut).TrimEnd()) } else { [void]$lines.Add('(No remotes configured.)') }
        $output.Text = ($lines -join "`r`n")
    }

    $close = New-Object System.Windows.Forms.Button
    $close.Text = 'Close'
    $close.Width = 90
    $close.Height = 32
    $close.Add_Click({ $dialog.Close() })
    $buttons.Controls.Add($close)

    $push = New-Object System.Windows.Forms.Button
    $push.Text = 'Set upstream and push'
    $push.Width = 155
    $push.Height = 32
    $push.Add_Click({ Push-CurrentBranchWithUpstream -RemoteName ([string]$script:Config.DefaultRemoteName); Refresh-GitHubDiagnosticsText })
    $buttons.Controls.Add($push)

    $test = New-Object System.Windows.Forms.Button
    $test.Text = 'Test remote access'
    $test.Width = 145
    $test.Height = 32
    $test.Add_Click({ Test-GitHubRemoteAccess -RemoteName ([string]$script:Config.DefaultRemoteName); Refresh-GitHubDiagnosticsText })
    $buttons.Controls.Add($test)

    $showRemotes = New-Object System.Windows.Forms.Button
    $showRemotes.Text = 'Show remotes'
    $showRemotes.Width = 115
    $showRemotes.Height = 32
    $showRemotes.Add_Click({ Show-CurrentGitRemotes; Refresh-GitHubDiagnosticsText })
    $buttons.Controls.Add($showRemotes)

    $openRepo = New-Object System.Windows.Forms.Button
    $openRepo.Text = 'Open GitHub repo'
    $openRepo.Width = 135
    $openRepo.Height = 32
    $openRepo.Add_Click({ Open-GitHubRepositoryPage -RemoteName ([string]$script:Config.DefaultRemoteName) })
    $buttons.Controls.Add($openRepo)

    $openNew = New-Object System.Windows.Forms.Button
    $openNew.Text = 'Open new repo'
    $openNew.Width = 120
    $openNew.Height = 32
    $openNew.Add_Click({ Open-GitHubNewRepositoryPage })
    $buttons.Controls.Add($openNew)

    $refresh = New-Object System.Windows.Forms.Button
    $refresh.Text = 'Refresh'
    $refresh.Width = 90
    $refresh.Height = 32
    $refresh.Add_Click({ Refresh-GitHubDiagnosticsText })
    $buttons.Controls.Add($refresh)

    Refresh-GitHubDiagnosticsText
    [void]$dialog.ShowDialog($form)
    return $true
}

function Show-GitHubPublishDialog {
    if (-not (Test-GitRepository)) {
        [void](Ensure-RepositorySelected)
        if (-not (Test-GitRepository)) { return $false }
    }

    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = 'Publish to GitHub'
    $dialog.StartPosition = 'CenterParent'
    $dialog.Width = 760
    $dialog.Height = 560
    $dialog.MinimizeBox = $false
    $dialog.MaximizeBox = $false
    $dialog.FormBorderStyle = 'FixedDialog'

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = 'Fill'
    $layout.Padding = New-Object System.Windows.Forms.Padding(12)
    $layout.ColumnCount = 2
    $layout.RowCount = 10
    [void]$layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize)))
    [void]$layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $dialog.Controls.Add($layout)

    $intro = New-WrappingLabel -Text 'GitHub workflow: create an empty GitHub repository first, preferably Private for proprietary or unfinished work. Git Glide then configures the local remote and can push the current branch.' -Height 48
    $layout.Controls.Add($intro, 0, 0)
    $layout.SetColumnSpan($intro, 2)

    $ownerLabel = New-Object System.Windows.Forms.Label
    $ownerLabel.Text = 'GitHub owner/org:'
    $ownerLabel.AutoSize = $true
    $ownerLabel.Margin = New-Object System.Windows.Forms.Padding(4, 8, 8, 4)
    $layout.Controls.Add($ownerLabel, 0, 1)

    $ownerBox = New-Object System.Windows.Forms.TextBox
    $ownerBox.Dock = 'Fill'
    $ownerBox.Text = [string]$script:Config.DefaultGitHubOwner
    $layout.Controls.Add($ownerBox, 1, 1)

    $repoLabel = New-Object System.Windows.Forms.Label
    $repoLabel.Text = 'Repository name:'
    $repoLabel.AutoSize = $true
    $repoLabel.Margin = New-Object System.Windows.Forms.Padding(4, 8, 8, 4)
    $layout.Controls.Add($repoLabel, 0, 2)

    $repoBox = New-Object System.Windows.Forms.TextBox
    $repoBox.Dock = 'Fill'
    try { $repoBox.Text = Split-Path -Leaf $script:RepoRoot } catch { $repoBox.Text = 'GitGlideGUI' }
    $layout.Controls.Add($repoBox, 1, 2)

    $protocolLabel = New-Object System.Windows.Forms.Label
    $protocolLabel.Text = 'Remote protocol:'
    $protocolLabel.AutoSize = $true
    $protocolLabel.Margin = New-Object System.Windows.Forms.Padding(4, 8, 8, 4)
    $layout.Controls.Add($protocolLabel, 0, 3)

    $protocolBox = New-Object System.Windows.Forms.ComboBox
    $protocolBox.DropDownStyle = 'DropDownList'
    [void]$protocolBox.Items.Add('HTTPS')
    [void]$protocolBox.Items.Add('SSH')
    $protocolBox.SelectedItem = if ([string]$script:Config.DefaultGitHubProtocol -eq 'SSH') { 'SSH' } else { 'HTTPS' }
    $layout.Controls.Add($protocolBox, 1, 3)

    $descLabel = New-Object System.Windows.Forms.Label
    $descLabel.Text = 'GitHub description:'
    $descLabel.AutoSize = $true
    $descLabel.Margin = New-Object System.Windows.Forms.Padding(4, 8, 8, 4)
    $layout.Controls.Add($descLabel, 0, 4)

    $descBox = New-Object System.Windows.Forms.TextBox
    $descBox.Multiline = $true
    $descBox.Height = 78
    $descBox.Dock = 'Fill'
    $descBox.ScrollBars = 'Vertical'
    $descBox.Text = if ([string]::IsNullOrWhiteSpace([string]$script:Config.GitHubRepositoryDescription)) { Get-GitHubDefaultDescription } else { [string]$script:Config.GitHubRepositoryDescription }
    $layout.Controls.Add($descBox, 1, 4)

    $private = New-Object System.Windows.Forms.CheckBox
    $private.Text = 'Create the GitHub repository as Private for proprietary/client/unfinished code'
    $private.AutoSize = $true
    $private.Checked = $true
    $layout.Controls.Add($private, 1, 5)

    $copilot = New-Object System.Windows.Forms.CheckBox
    $copilot.Text = 'Review GitHub Copilot AI/data training settings and opt out where available'
    $copilot.AutoSize = $true
    $copilot.Checked = $true
    $layout.Controls.Add($copilot, 1, 6)

    $push = New-Object System.Windows.Forms.CheckBox
    $push.Text = 'After the empty GitHub repository exists, add/update origin and push current branch'
    $push.AutoSize = $true
    $push.Checked = $true
    $layout.Controls.Add($push, 1, 7)

    $warn = New-WrappingLabel -Text 'Privacy note: Git Glide GUI cannot change GitHub account policy. Private visibility and Copilot data/training choices must be reviewed in GitHub. The GUI only prepares local Git commands after your confirmation.' -Height 52
    $layout.Controls.Add($warn, 0, 8)
    $layout.SetColumnSpan($warn, 2)

    $buttons = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttons.FlowDirection = 'RightToLeft'
    $buttons.Dock = 'Fill'
    $buttons.WrapContents = $true
    $layout.Controls.Add($buttons, 0, 9)
    $layout.SetColumnSpan($buttons, 2)

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'Configure remote / push'
    $ok.Width = 165
    $ok.Height = 32
    $ok.Add_Click({ $dialog.DialogResult = [System.Windows.Forms.DialogResult]::OK; $dialog.Close() })
    $buttons.Controls.Add($ok)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Cancel'
    $cancel.Width = 90
    $cancel.Height = 32
    $cancel.Add_Click({ $dialog.DialogResult = [System.Windows.Forms.DialogResult]::Cancel; $dialog.Close() })
    $buttons.Controls.Add($cancel)

    $openGitHub = New-Object System.Windows.Forms.Button
    $openGitHub.Text = 'Open GitHub new repo'
    $openGitHub.Width = 155
    $openGitHub.Height = 32
    $openGitHub.Add_Click({ Open-GitHubNewRepositoryPage })
    $buttons.Controls.Add($openGitHub)

    $openCopilot = New-Object System.Windows.Forms.Button
    $openCopilot.Text = 'Open Copilot settings'
    $openCopilot.Width = 150
    $openCopilot.Height = 32
    $openCopilot.Add_Click({ Open-GitHubCopilotSettingsPage })
    $buttons.Controls.Add($openCopilot)

    $copyDesc = New-Object System.Windows.Forms.Button
    $copyDesc.Text = 'Copy description'
    $copyDesc.Width = 130
    $copyDesc.Height = 32
    $copyDesc.Add_Click({ Copy-GitHubRepositoryDescription -Description $descBox.Text })
    $buttons.Controls.Add($copyDesc)

    $privacyButton = New-Object System.Windows.Forms.Button
    $privacyButton.Text = 'Privacy checklist'
    $privacyButton.Width = 125
    $privacyButton.Height = 32
    $privacyButton.Add_Click({ Show-GitHubPrivacyGuidance })
    $buttons.Controls.Add($privacyButton)

    $dialog.AcceptButton = $ok
    $dialog.CancelButton = $cancel
    $result = $dialog.ShowDialog($form)
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) { return $false }

    try {
        $ownerText = $ownerBox.Text.Trim()
        $repoText = $repoBox.Text.Trim()
        $protocolText = [string]$protocolBox.SelectedItem
        $remoteUrl = Get-GitHubRemoteUrlSafe -Owner $ownerText -Repository $repoText -Protocol $protocolText
        Set-ConfigValue -Name 'DefaultGitHubOwner' -Value $ownerText
        Set-ConfigValue -Name 'DefaultGitHubProtocol' -Value $protocolText
        Set-ConfigValue -Name 'GitHubRepositoryDescription' -Value $descBox.Text
        Save-Config -Config $script:Config
        if ($private.Checked -or $copilot.Checked) { Show-GitHubPrivacyGuidance }
        return (Invoke-RemoteSetup -RemoteName ([string]$script:Config.DefaultRemoteName) -RemoteUrl $remoteUrl -PushAfter:([bool]$push.Checked))
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'GitHub publish setup failed', 'OK', 'Error') | Out-Null
        return $false
    }
}

function Invoke-RemoteSetup {
    param(
        [string]$RemoteName,
        [string]$RemoteUrl,
        [switch]$PushAfter
    )

    if (-not (Test-GitRepository)) {
        [void](Ensure-RepositorySelected)
        if (-not (Test-GitRepository)) { return $false }
    }

    $RemoteName = ([string]$RemoteName).Trim()
    $RemoteUrl = ([string]$RemoteUrl).Trim()
    if ([string]::IsNullOrWhiteSpace($RemoteName)) { $RemoteName = 'origin' }
    $remoteNameValid = $RemoteName -match '^[A-Za-z0-9._-]+$'
    try {
        $cmd = Get-Command Test-GggRemoteName -ErrorAction SilentlyContinue
        if ($cmd) { $remoteNameValid = [bool](Test-GggRemoteName -RemoteName $RemoteName) }
    } catch {}
    if (-not $remoteNameValid) {
        [System.Windows.Forms.MessageBox]::Show('Remote name may contain letters, numbers, dot, underscore, and hyphen only.', 'Invalid remote name', 'OK', 'Warning') | Out-Null
        return $false
    }
    if ([string]::IsNullOrWhiteSpace($RemoteUrl)) {
        [System.Windows.Forms.MessageBox]::Show('Enter a remote URL first.', 'Missing remote URL', 'OK', 'Warning') | Out-Null
        return $false
    }

    $existing = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'remote', 'get-url', $RemoteName) -Caption ("git remote get-url $RemoteName") -AllowFailure -QuietOutput
    if ($existing.ExitCode -eq 0) {
        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "Remote '$RemoteName' already exists.`r`n`r`nCurrent URL:`r`n$($existing.StdOut.Trim())`r`n`r`nUpdate it to:`r`n$RemoteUrl ?",
            'Update existing remote?',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return $false }
        [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'remote', 'set-url', $RemoteName, $RemoteUrl) -Caption ("git remote set-url $RemoteName <url>") -ShowProgress)
    } else {
        [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'remote', 'add', $RemoteName, $RemoteUrl) -Caption ("git remote add $RemoteName <url>") -ShowProgress)
    }

    Set-ConfigValue -Name 'DefaultRemoteName' -Value $RemoteName
    Save-Config -Config $script:Config
    Write-AuditLog -Message ("REMOTE_CONFIGURED | RepoRoot='{0}' | Remote='{1}'" -f $script:RepoRoot, $RemoteName)

    if ($PushAfter) {
        if (-not (Test-GitHasCommits)) {
            [System.Windows.Forms.MessageBox]::Show('Create the first commit before pushing to a remote.', 'No commits yet', 'OK', 'Information') | Out-Null
        } else {
            $pushResult = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'push', '-u', $RemoteName, 'HEAD') -Caption ("git push -u $RemoteName HEAD") -AllowFailure -ShowProgress
            if ($pushResult.ExitCode -ne 0) { Show-GitHubRemoteFailureGuidance -Result $pushResult -Operation 'push with upstream' -RemoteName $RemoteName }
        }
    }

    Set-SuggestedNextAction -Text 'Remote is configured. Push when the branch is ready to share.'
    Refresh-Status
    return $true
}

function Show-RemoteSetupDialog {
    if (-not (Test-GitRepository)) {
        [void](Ensure-RepositorySelected)
        if (-not (Test-GitRepository)) { return $false }
    }

    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = 'Add or update remote'
    $dialog.StartPosition = 'CenterParent'
    $dialog.Width = 620
    $dialog.Height = 250
    $dialog.MinimizeBox = $false
    $dialog.MaximizeBox = $false
    $dialog.FormBorderStyle = 'FixedDialog'

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = 'Fill'
    $layout.Padding = New-Object System.Windows.Forms.Padding(12)
    $layout.ColumnCount = 2
    $layout.RowCount = 5
    [void]$layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize)))
    [void]$layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $dialog.Controls.Add($layout)

    $nameLabel = New-Object System.Windows.Forms.Label
    $nameLabel.Text = 'Remote name:'
    $nameLabel.AutoSize = $true
    $nameLabel.Margin = New-Object System.Windows.Forms.Padding(4, 8, 8, 4)
    $layout.Controls.Add($nameLabel, 0, 0)

    $nameBox = New-Object System.Windows.Forms.TextBox
    $nameBox.Text = if ([string]::IsNullOrWhiteSpace([string]$script:Config.DefaultRemoteName)) { 'origin' } else { [string]$script:Config.DefaultRemoteName }
    $nameBox.Dock = 'Fill'
    $layout.Controls.Add($nameBox, 1, 0)

    $urlLabel = New-Object System.Windows.Forms.Label
    $urlLabel.Text = 'Remote URL:'
    $urlLabel.AutoSize = $true
    $urlLabel.Margin = New-Object System.Windows.Forms.Padding(4, 8, 8, 4)
    $layout.Controls.Add($urlLabel, 0, 1)

    $urlBox = New-Object System.Windows.Forms.TextBox
    $urlBox.Dock = 'Fill'
    $layout.Controls.Add($urlBox, 1, 1)

    $push = New-Object System.Windows.Forms.CheckBox
    $push.Text = 'Push current branch and set upstream after adding/updating remote'
    $push.AutoSize = $true
    $push.Checked = $false
    $push.Margin = New-Object System.Windows.Forms.Padding(4, 8, 4, 4)
    $layout.Controls.Add($push, 1, 2)

    $help = New-WrappingLabel -Text 'Use this after creating an empty repository on GitHub, GitLab, Bitbucket, Azure DevOps, or another Git server.' -Height 42
    $layout.Controls.Add($help, 0, 3)
    $layout.SetColumnSpan($help, 2)

    $buttons = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttons.FlowDirection = 'RightToLeft'
    $buttons.Dock = 'Fill'
    $layout.Controls.Add($buttons, 0, 4)
    $layout.SetColumnSpan($buttons, 2)

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'Save remote'
    $ok.Width = 110
    $ok.Height = 32
    $ok.Add_Click({ $dialog.DialogResult = [System.Windows.Forms.DialogResult]::OK; $dialog.Close() })
    $buttons.Controls.Add($ok)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Cancel'
    $cancel.Width = 90
    $cancel.Height = 32
    $cancel.Add_Click({ $dialog.DialogResult = [System.Windows.Forms.DialogResult]::Cancel; $dialog.Close() })
    $buttons.Controls.Add($cancel)

    $result = $dialog.ShowDialog($form)
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return (Invoke-RemoteSetup -RemoteName $nameBox.Text -RemoteUrl $urlBox.Text -PushAfter:([bool]$push.Checked))
    }
    return $false
}

function Invoke-FirstCommitWizard {
    if (-not (Test-GitRepository)) {
        [void](Ensure-RepositorySelected)
        if (-not (Test-GitRepository)) { return $false }
    }

    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = 'First commit wizard'
    $dialog.StartPosition = 'CenterParent'
    $dialog.Width = 680
    $dialog.Height = 430
    $dialog.MinimizeBox = $false
    $dialog.MaximizeBox = $false
    $dialog.FormBorderStyle = 'FixedDialog'

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = 'Fill'
    $layout.Padding = New-Object System.Windows.Forms.Padding(12)
    $layout.ColumnCount = 2
    $layout.RowCount = 8
    [void]$layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize)))
    [void]$layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $dialog.Controls.Add($layout)

    $subjectLabel = New-Object System.Windows.Forms.Label
    $subjectLabel.Text = 'Subject:'
    $subjectLabel.AutoSize = $true
    $subjectLabel.Margin = New-Object System.Windows.Forms.Padding(4, 8, 8, 4)
    $layout.Controls.Add($subjectLabel, 0, 0)

    $subjectBox = New-Object System.Windows.Forms.TextBox
    $subjectBox.Text = 'Initial commit'
    $subjectBox.Dock = 'Fill'
    $layout.Controls.Add($subjectBox, 1, 0)

    $bodyLabel = New-Object System.Windows.Forms.Label
    $bodyLabel.Text = 'Body:'
    $bodyLabel.AutoSize = $true
    $bodyLabel.Margin = New-Object System.Windows.Forms.Padding(4, 8, 8, 4)
    $layout.Controls.Add($bodyLabel, 0, 1)

    $bodyBox = New-Object System.Windows.Forms.RichTextBox
    $bodyBox.Height = 70
    $bodyBox.Dock = 'Fill'
    $bodyBox.Text = 'Initialize repository structure.'
    $layout.Controls.Add($bodyBox, 1, 1)

    $templateLabel = New-Object System.Windows.Forms.Label
    $templateLabel.Text = '.gitignore:'
    $templateLabel.AutoSize = $true
    $templateLabel.Margin = New-Object System.Windows.Forms.Padding(4, 8, 8, 4)
    $layout.Controls.Add($templateLabel, 0, 2)

    $templatePanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $templatePanel.Dock = 'Fill'
    $templatePanel.WrapContents = $false
    $layout.Controls.Add($templatePanel, 1, 2)

    $useGitIgnore = New-Object System.Windows.Forms.CheckBox
    $useGitIgnore.Text = 'Create/update'
    $useGitIgnore.Checked = $true
    $useGitIgnore.AutoSize = $true
    $templatePanel.Controls.Add($useGitIgnore)

    $templateCombo = New-Object System.Windows.Forms.ComboBox
    $templateCombo.DropDownStyle = 'DropDownList'
    $templateCombo.Width = 230
    [void]$templateCombo.Items.AddRange((Get-GitIgnoreTemplateNames))
    $preferred = [string]$script:Config.DefaultGitIgnoreTemplate
    if (-not [string]::IsNullOrWhiteSpace($preferred) -and $templateCombo.Items.Contains($preferred)) { $templateCombo.SelectedItem = $preferred } else { $templateCombo.SelectedIndex = 0 }
    $templatePanel.Controls.Add($templateCombo)

    $remoteLabel = New-Object System.Windows.Forms.Label
    $remoteLabel.Text = 'Remote URL:'
    $remoteLabel.AutoSize = $true
    $remoteLabel.Margin = New-Object System.Windows.Forms.Padding(4, 8, 8, 4)
    $layout.Controls.Add($remoteLabel, 0, 3)

    $remoteBox = New-Object System.Windows.Forms.TextBox
    $remoteBox.Dock = 'Fill'
    $layout.Controls.Add($remoteBox, 1, 3)

    $push = New-Object System.Windows.Forms.CheckBox
    $push.Text = 'Push to remote after first commit and set upstream'
    $push.Checked = $false
    $push.AutoSize = $true
    $layout.Controls.Add($push, 1, 4)

    $stage = New-Object System.Windows.Forms.CheckBox
    $stage.Text = 'Stage all files before committing'
    $stage.Checked = $true
    $stage.AutoSize = $true
    $layout.Controls.Add($stage, 1, 5)

    $help = New-WrappingLabel -Text 'Recommended for a new repository: create .gitignore, stage the intended files, make the initial commit, then optionally add a remote and push.' -Height 45
    $layout.Controls.Add($help, 0, 6)
    $layout.SetColumnSpan($help, 2)

    $buttons = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttons.FlowDirection = 'RightToLeft'
    $buttons.Dock = 'Fill'
    $layout.Controls.Add($buttons, 0, 7)
    $layout.SetColumnSpan($buttons, 2)

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'Create first commit'
    $ok.Width = 145
    $ok.Height = 32
    $ok.Add_Click({ $dialog.DialogResult = [System.Windows.Forms.DialogResult]::OK; $dialog.Close() })
    $buttons.Controls.Add($ok)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Cancel'
    $cancel.Width = 90
    $cancel.Height = 32
    $cancel.Add_Click({ $dialog.DialogResult = [System.Windows.Forms.DialogResult]::Cancel; $dialog.Close() })
    $buttons.Controls.Add($cancel)

    $result = $dialog.ShowDialog($form)
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) { return $false }

    $subject = $subjectBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($subject)) {
        [System.Windows.Forms.MessageBox]::Show('Commit subject cannot be empty.', 'Invalid commit message', 'OK', 'Warning') | Out-Null
        return $false
    }

    if (Test-GitHasCommits) {
        $confirm = [System.Windows.Forms.MessageBox]::Show('This repository already has commits. Continue and create another commit?', 'Repository already has commits', [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return $false }
    }

    if ($useGitIgnore.Checked) {
        [void](Write-GitIgnoreTemplate -TemplateName ([string]$templateCombo.SelectedItem) -Append)
    }

    if ($stage.Checked) {
        [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'add', '-A') -Caption 'git add -A' -ShowProgress)
    }

    $message = $subject
    if (-not [string]::IsNullOrWhiteSpace($bodyBox.Text)) { $message += "`r`n`r`n" + $bodyBox.Text.TrimEnd() }

    $tempFile = [System.IO.Path]::GetTempFileName()
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    try {
        [System.IO.File]::WriteAllText($tempFile, $message, $utf8NoBom)
        $commitResult = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'commit', '-F', $tempFile) -Caption 'git commit -F <temp-commit-message-file>' -AllowFailure -ShowProgress
        if ($commitResult.ExitCode -ne 0) {
            Set-SuggestedNextAction -Text 'First commit failed. Check whether there are staged files and review the Output tab.'
            return $false
        }
    } finally {
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }

    if (-not [string]::IsNullOrWhiteSpace($remoteBox.Text)) {
        [void](Invoke-RemoteSetup -RemoteName ([string]$script:Config.DefaultRemoteName) -RemoteUrl $remoteBox.Text -PushAfter:([bool]$push.Checked))
    }

    Set-SuggestedNextAction -Text 'First commit created. Push when ready, or create your first feature branch.' -Action 'branch-tab'
    Refresh-Status
    return $true
}

function Show-RepositoryStartupChoiceDialog {
    param([string]$CurrentPath)

    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = 'Choose repository action'
    $dialog.StartPosition = 'CenterParent'
    $dialog.Width = 960
    $dialog.Height = 540
    $dialog.MinimumSize = New-Object System.Drawing.Size(820, 460)
    $dialog.MinimizeBox = $false
    $dialog.MaximizeBox = $false
    $dialog.FormBorderStyle = 'Sizable'
    $dialog.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
    $dialog.Tag = 'continue'
    $script:RepositoryStartupChoiceDialogResult = 'abort'
    $script:RepositoryStartupChoiceDialogForm = $dialog

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = 'Fill'
    $layout.Padding = New-Object System.Windows.Forms.Padding(16)
    $layout.ColumnCount = 1
    $layout.RowCount = 3
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
    $dialog.Controls.Add($layout)

    $title = New-WrappingLabel -Text ("Git Glide GUI is not currently pointed at a Git repository.`r`nCurrent path: $CurrentPath`r`nChoose the intention that matches what you want to do next:") -Height 58
    $title.Font = $script:UiFontBold
    $layout.Controls.Add($title, 0, 0)

    $choiceGrid = New-Object System.Windows.Forms.TableLayoutPanel
    $choiceGrid.Dock = 'Fill'
    $choiceGrid.ColumnCount = 3
    $choiceGrid.RowCount = 1
    $choiceGrid.Margin = New-Object System.Windows.Forms.Padding(0, 10, 0, 10)
    [void]$choiceGrid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 33.3)))
    [void]$choiceGrid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 33.3)))
    [void]$choiceGrid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 33.4)))
    $layout.Controls.Add($choiceGrid, 0, 1)

    function New-StartupChoiceCard {
        param(
            [string]$Title,
            [string]$Description,
            [string]$Examples,
            [string]$Choice,
            [int]$Column
        )

        $panel = New-Object System.Windows.Forms.Panel
        $panel.Dock = 'Fill'
        $panel.Margin = New-Object System.Windows.Forms.Padding(6)
        $panel.Padding = New-Object System.Windows.Forms.Padding(10)
        $panel.BorderStyle = 'FixedSingle'
        $choiceGrid.Controls.Add($panel, $Column, 0)

        $inner = New-Object System.Windows.Forms.TableLayoutPanel
        $inner.Dock = 'Fill'
        $inner.ColumnCount = 1
        $inner.RowCount = 3
        [void]$inner.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
        [void]$inner.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
        [void]$inner.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
        $panel.Controls.Add($inner)

        $button = New-Object System.Windows.Forms.Button
        $button.Text = $Title
        $button.Dock = 'Top'
        $button.Height = 38
        $button.Font = $script:UiFontBold
        switch ($Choice) {
            'open' { $button.DialogResult = [System.Windows.Forms.DialogResult]::Yes }
            'init' { $button.DialogResult = [System.Windows.Forms.DialogResult]::No }
            default { $button.DialogResult = [System.Windows.Forms.DialogResult]::Ignore }
        }
        # Important: do not use a Click handler here. WinForms automatically closes
        # modal dialogs when a button has DialogResult set. This avoids PowerShell
        # nested-closure scope issues seen in v2.7/v2.8.1.
        $inner.Controls.Add($button, 0, 0)

        $body = New-WrappingLabel -Text ($Description + "`r`n`r`n" + $Examples) -Height 140
        $body.Dock = 'Fill'
        $inner.Controls.Add($body, 0, 1)

        $hint = New-WrappingLabel -Text ('Hover help: ' + $Description) -Height 45
        $hint.ForeColor = [System.Drawing.Color]::DimGray
        $inner.Controls.Add($hint, 0, 2)

        if ($script:ToolTip) {
            $script:ToolTip.SetToolTip($button, (New-TooltipText -Title $Title -Description ($Description + "`r`n`r`nExamples:`r`n" + $Examples) -Commands 'No Git command is run until you confirm/select a folder.'))
            $script:ToolTip.SetToolTip($panel, ($Title + "`r`n`r`n" + $Description))
        }
        return $button
    }

    $open = New-StartupChoiceCard -Title 'Open existing repo' -Description 'Use this when the project already has Git history or a .git folder. Best for normal daily work on an existing repository.' -Examples 'Examples: PersonalCloud_v33_3_9, cloned project, company repository.' -Choice 'open' -Column 0
    [void](New-StartupChoiceCard -Title 'Init new repo' -Description 'Use this when this is a new or existing normal folder that should become a Git repository now.' -Examples 'Examples: new prototype, script collection, local project that has never used Git.' -Choice 'init' -Column 1)
    $continue = New-StartupChoiceCard -Title 'Continue without repo' -Description 'Use this to inspect the UI, read help, change appearance, or delay repository selection. Repository commands stay guarded.' -Examples 'Examples: evaluating the tool, opening the package folder accidentally, reading documentation first.' -Choice 'continue' -Column 2

    $note = New-WrappingLabel -Text 'Tip: if you extracted Git Glide GUI into its own folder, choose Open existing repo and point it to your real project folder. Choose Init new repo only when you intentionally want to create a .git folder.' -Height 48
    $layout.Controls.Add($note, 0, 2)

    $dialog.AcceptButton = $open
    # X/Esc means abort startup. The explicit Continue button uses DialogResult.Ignore.
    $dialog.CancelButton = $null
    $dialogResult = $dialog.ShowDialog($form)
    $script:RepositoryStartupChoiceDialogForm = $null

    if ($dialogResult -eq [System.Windows.Forms.DialogResult]::Yes) { return 'open' }
    if ($dialogResult -eq [System.Windows.Forms.DialogResult]::No) { return 'init' }
    if ($dialogResult -eq [System.Windows.Forms.DialogResult]::Ignore) { return 'continue' }
    return 'abort'
}

function Build-FirstCommitPreview {
    try {
        $cmd = Get-Command Get-GggFirstCommitCommandPreview -ErrorAction SilentlyContinue
        if ($cmd) { return (Get-GggFirstCommitCommandPreview -RemoteName ([string]$script:Config.DefaultRemoteName) -WithGitIgnore -WithRemote -PushAfter) }
    } catch {}
    return "create or update .gitignore`r`ngit add -A`r`ngit commit -F <temp-commit-message-file>`r`noptional: git remote add origin <url>`r`noptional: git push -u origin HEAD"
}

function Build-GitIgnorePreview {
    return "create or update .gitignore using selected template`r`ngit add .gitignore"
}

function Build-RemoteSetupPreview {
    return "git remote add origin <url>`r`noptional: git push -u origin HEAD"
}

function Show-NewRepositoryPicker {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Select the folder where Git Glide GUI should initialize a new Git repository.'
    $dialog.ShowNewFolderButton = $true

    foreach ($candidate in @([string]$script:Config.LastRepositoryRoot, (Get-Location).Path, (Join-Path $PSScriptRoot '..\..'))) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) {
            try { $dialog.SelectedPath = (Resolve-Path -LiteralPath $candidate).Path; break } catch {}
        }
    }

    $result = $dialog.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return (Initialize-NewRepository -Path $dialog.SelectedPath -Refresh)
    }

    Set-SuggestedNextAction -Text 'Open existing repo, init new repo, or continue without repository commands.' -Action 'choose-repo'
    return $false
}

function Show-RepositoryPicker {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Select an existing Git repository folder. If the selected folder is not a repository, Git Glide GUI can initialize it.'
    $dialog.ShowNewFolderButton = $true

    foreach ($candidate in @($script:RepoRoot, [string]$script:Config.LastRepositoryRoot, (Get-Location).Path)) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) {
            try { $dialog.SelectedPath = (Resolve-Path -LiteralPath $candidate).Path; break } catch {}
        }
    }

    $result = $dialog.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return (Set-RepositoryRoot -Path $dialog.SelectedPath -Refresh -OfferInitialize)
    }

    Set-SuggestedNextAction -Text 'Open existing repo, init new repo, or continue without repository commands.' -Action 'choose-repo'
    return $false
}

function Ensure-RepositorySelected {
    param([switch]$InitialStartup)
    if (Test-GitRepository) { return $true }

    $packagePath = try { (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path } catch { $PSScriptRoot }
    $choice = Show-RepositoryStartupChoiceDialog -CurrentPath $packagePath
    if ($choice -eq 'open') { return (Show-RepositoryPicker) }
    if ($choice -eq 'init') { return (Show-NewRepositoryPicker) }
    if ($choice -eq 'abort') {
        if ($InitialStartup) { $script:StartupAborted = $true }
        return $false
    }

    if ($script:RepoPathValueLabel) { $script:RepoPathValueLabel.Text = '(no repository selected)' }
    if ($script:BranchValueLabel) { $script:BranchValueLabel.Text = '-' }
    if ($script:UpstreamValueLabel) { $script:UpstreamValueLabel.Text = '-' }
    if ($script:BranchStateValueLabel) { $script:BranchStateValueLabel.Text = '-' }
    if ($script:WorkingTreeValueLabel) { $script:WorkingTreeValueLabel.Text = 'not a repository' }
    if ($script:ChangedCountValueLabel) { $script:ChangedCountValueLabel.Text = '0' }
    Set-SuggestedNextAction -Text 'Open existing repo, init new repo, or continue without repository commands.' -Action 'choose-repo'
    return $false
}

function Test-CleanWorkingTree {
    param(
        [switch]$Silent,
        [switch]$AllowContinue,
        [string]$Operation = 'this action'
    )

    $result = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'status', '--porcelain=v1') -Caption 'git status --porcelain=v1' -AllowFailure -QuietOutput

    if ($result.ExitCode -ne 0) {
        if (-not $Silent) {
            [System.Windows.Forms.MessageBox]::Show('Could not verify working tree status before ' + $Operation + '.', 'Git Error', 'OK', 'Warning') | Out-Null
        }
        return $false
    }

    $rawLines = @($result.StdOut -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if (@($rawLines).Count -eq 0) { return $true }

    if (-not $Silent) {
        $message = 'Working tree is not clean. Commit, stash, or restore your changes before this action.'
        $title = 'Working tree not clean'

        try {
            if (Get-Command ConvertFrom-GfgPorcelainStatusLine -ErrorAction SilentlyContinue) {
                $items = @($rawLines | ForEach-Object { ConvertFrom-GfgPorcelainStatusLine -Line $_ } | Where-Object { $_ })
                $summary = Get-GfgRepositoryStatusSummary -Items $items
                if (Get-Command Get-GgbDirtyWorkingTreeGuidance -ErrorAction SilentlyContinue) {
                    $guidance = Get-GgbDirtyWorkingTreeGuidance -Summary $summary -Operation $Operation
                    $title = [string]$guidance.Title
                    $message = ([string]$guidance.Message) + "`r`n`r`n" + ([string]$guidance.Details) + "`r`n`r`nRecommended next step: review, stage and commit, or stash your work before continuing."
                }
            }
        } catch {}

        if ($AllowContinue) {
            $message = $message + "`r`n`r`nGit may still allow this switch when your changes do not overlap with the target branch. Choose Yes to let Git attempt the switch anyway. Git will stop if the switch would overwrite your work."
            $answer = [System.Windows.Forms.MessageBox]::Show($message, "$title - switch anyway?", 'YesNo', 'Warning')
            return ($answer -eq [System.Windows.Forms.DialogResult]::Yes)
        }

        [System.Windows.Forms.MessageBox]::Show($message, $title, 'OK', 'Warning') | Out-Null
    }
    return $false
}
function Test-BranchExists {
    param([string]$BranchName)

    try {
        $result = & git -C $script:RepoRoot rev-parse --verify "refs/heads/$BranchName" 2>$null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function Get-GitConfig {
    param([string]$Key)

    try {
        $result = & git -C $script:RepoRoot config --get $Key 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $result
        }
    } catch {}
    return $null
}

#endregion

#region Command Execution

function Run-External {
    param(
        [string]$FileName,
        [string[]]$Arguments,
        [string]$WorkingDirectory = $script:RepoRoot,
        [string]$Caption = $null,
        [switch]$AllowFailure,
        [switch]$ShowProgress,
        [switch]$QuietOutput
    )

    $argLine = ($Arguments | ForEach-Object { Quote-Arg $_ }) -join ' '
    $commandText = if ($Caption) { $Caption } else { "$FileName $argLine" }
    $operationStartedAt = Get-Date
    Write-AuditLog -Message ("START | WorkDir='{0}' | Command={1}" -f $WorkingDirectory, $commandText)
    $script:LastCommandSummary = $commandText
    $script:LastCommandArgs = @($FileName) + @($Arguments)
    $script:CancelRequested = $false

    Set-StatusBar("Running: $commandText")
    Append-Log -Text ("[{0}] ------------------------------------------------------------" -f (New-LogTimestamp)) -Color ([System.Drawing.Color]::DarkGray)
    Append-Log -Text ("[{0}] >>> {1}" -f (New-LogTimestamp), $commandText) -Color ([System.Drawing.Color]::DarkBlue)

    if ($ShowProgress -and $script:ProgressBar) {
        $script:ProgressBar.Style = 'Marquee'
        $script:ProgressBar.Visible = $true
        $script:CancelButton.Enabled = $true
    }

    if ($FileName -eq 'git' -and ($Arguments -contains '-C') -and -not (Test-GitRepository)) {
        $message = 'No Git repository is selected. Use Open existing... for an existing repository or Init new... to initialize a folder.'
        Append-Log -Text $message -Color ([System.Drawing.Color]::Firebrick)
        Write-AuditLog -Message ("BLOCKED | Reason='No repository selected' | Command={0}" -f $commandText)
        return [pscustomobject]@{ ExitCode = 128; StdOut = ''; StdErr = $message }
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FileName
    $psi.Arguments = $argLine
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    $script:CurrentProcess = $proc

    try {
        [void]$proc.Start()

        $stdoutBuilder = New-Object System.Text.StringBuilder
        $stderrBuilder = New-Object System.Text.StringBuilder

        while (-not $proc.HasExited -and -not $script:CancelRequested) {
            while (-not $proc.StandardOutput.EndOfStream) {
                $line = $proc.StandardOutput.ReadLine()
                if ($null -ne $line) {
                    [void]$stdoutBuilder.AppendLine($line)
                    if (-not $QuietOutput) { Append-Log -Text $line -Color ([System.Drawing.Color]::Black) }
                }
            }
            while (-not $proc.StandardError.EndOfStream) {
                $line = $proc.StandardError.ReadLine()
                if ($null -ne $line) {
                    [void]$stderrBuilder.AppendLine($line)
                    if (-not $QuietOutput) { Append-Log -Text $line -Color ([System.Drawing.Color]::Firebrick) }
                }
            }
            [System.Windows.Forms.Application]::DoEvents()
            [System.Threading.Thread]::Sleep(25)
        }

        if ($script:CancelRequested) {
            try {
                $proc.Kill()
                Append-Log -Text ("[{0}] Command cancelled by user" -f (New-LogTimestamp)) -Color ([System.Drawing.Color]::DarkOrange)
                Set-StatusBar("Cancelled: $commandText")
            } catch {
                Append-Log -Text ("[{0}] Failed to cancel: {1}" -f (New-LogTimestamp), $_.Exception.Message) -Color ([System.Drawing.Color]::DarkRed)
            }
            $durationMs = [int](((Get-Date) - $operationStartedAt).TotalMilliseconds)
            Write-AuditLog -Message ("CANCELLED | DurationMs={0} | Command={1}" -f $durationMs, $commandText)
            return @{ ExitCode = -1; StdOut = ''; StdErr = 'Cancelled by user'; Cancelled = $true }
        }

        # Read remaining output
        while (-not $proc.StandardOutput.EndOfStream) {
            $line = $proc.StandardOutput.ReadLine()
            if ($null -ne $line) {
                [void]$stdoutBuilder.AppendLine($line)
                if (-not $QuietOutput) { Append-Log -Text $line -Color ([System.Drawing.Color]::Black) }
            }
        }
        while (-not $proc.StandardError.EndOfStream) {
            $line = $proc.StandardError.ReadLine()
            if ($null -ne $line) {
                [void]$stderrBuilder.AppendLine($line)
                if (-not $QuietOutput) { Append-Log -Text $line -Color ([System.Drawing.Color]::Firebrick) }
            }
        }
        $proc.WaitForExit()

        $stdout = $stdoutBuilder.ToString()
        $stderr = $stderrBuilder.ToString()

        if ($proc.ExitCode -eq 0) {
            Append-Log -Text ("[{0}] Exit code: {1}" -f (New-LogTimestamp), $proc.ExitCode) -Color ([System.Drawing.Color]::DarkGreen)
            Set-StatusBar("Completed: $commandText")
        } else {
            Append-Log -Text ("[{0}] Exit code: {1}" -f (New-LogTimestamp), $proc.ExitCode) -Color ([System.Drawing.Color]::DarkRed)
            Set-StatusBar("Failed: $commandText")
        }

        $durationMs = [int](((Get-Date) - $operationStartedAt).TotalMilliseconds)
        Write-AuditLog -Message ("END | ExitCode={0} | DurationMs={1} | Command={2}" -f $proc.ExitCode, $durationMs, $commandText)

        if (-not $AllowFailure -and $proc.ExitCode -ne 0) {
            throw "Command failed with exit code $($proc.ExitCode): $commandText"
        }

        return @{
            ExitCode = $proc.ExitCode
            StdOut = $stdout
            StdErr = $stderr
            Cancelled = $false
        }
    } finally {
        $script:CurrentProcess = $null
        if ($ShowProgress -and $script:ProgressBar) {
            $script:ProgressBar.Visible = $false
            $script:ProgressBar.Style = 'Continuous'
            $script:CancelButton.Enabled = $false
        }
    }
}

function Cancel-CurrentOperation {
    if ($script:CurrentProcess -and -not $script:CurrentProcess.HasExited) {
        $script:CancelRequested = $true
        Append-Log -Text 'Cancellation requested...' -Color ([System.Drawing.Color]::DarkOrange)
    }
}

#endregion

#region Selection and Preview Helper Functions

function Get-StatusItemAtIndex {
    param([int]$Index)

    if ($Index -ge 0 -and $Index -lt @($script:StatusItems).Count) {
        return $script:StatusItems[$Index]
    }
    return $null
}

function Resolve-StatusItemFromListBoxItem {
    param($ListItem)

    if ($null -eq $ListItem) { return $null }

    # v1.3: list entries now carry their parsed status object directly.
    # This avoids a fragile dependency on SelectedIndices, which can fail or lag
    # with MultiExtended list boxes and refresh-driven selection changes.
    try {
        $property = $ListItem.PSObject.Properties['StatusItem']
        if ($property -and $null -ne $property.Value) { return $property.Value }
    } catch {}

    # Backwards compatibility for older string-only list entries.
    $displayText = [string]$ListItem
    if ($displayText -match '^\[(?<status>.{2})\]\s+(?<path>.+)$') {
        $status = $matches['status']
        $rawPath = $matches['path']
        foreach ($candidate in @($script:StatusItems)) {
            if ($candidate.Status -eq $status -and ($candidate.RawPath -eq $rawPath -or $candidate.Path -eq $rawPath)) {
                return $candidate
            }
        }
    }

    return $null
}

function Get-SelectedStatusItems {
    $items = New-Object System.Collections.Generic.List[object]
    $seen = @{}
    if (-not $script:ChangedFilesList) { return @() }

    # Prefer the selected item payload. It is the most reliable source and does not
    # depend on the ListBox index collection being synchronized yet.
    foreach ($selected in @($script:ChangedFilesList.SelectedItems)) {
        $item = Resolve-StatusItemFromListBoxItem -ListItem $selected
        if ($item) {
            $key = if ($item.RawPath) { [string]$item.RawPath } else { [string]$item.Path }
            if (-not $seen.ContainsKey($key)) {
                $seen[$key] = $true
                [void]$items.Add($item)
            }
        }
    }

    # Fallback for WinForms versions where SelectedItems is temporarily empty during
    # a SelectedIndexChanged event.
    if ($items.Count -eq 0) {
        foreach ($indexValue in @($script:ChangedFilesList.SelectedIndices)) {
            try { $index = [int]$indexValue } catch { continue }
            $item = Get-StatusItemAtIndex -Index $index
            if ($item) {
                $key = if ($item.RawPath) { [string]$item.RawPath } else { [string]$item.Path }
                if (-not $seen.ContainsKey($key)) {
                    $seen[$key] = $true
                    [void]$items.Add($item)
                }
            }
        }
    }

    # Final single-selection fallback. This is what makes the Show diff button useful
    # even when the list visually shows a focused row but the collection has not been
    # updated in time for the click handler.
    if ($items.Count -eq 0 -and $script:ChangedFilesList.SelectedIndex -ge 0) {
        $item = Get-StatusItemAtIndex -Index ([int]$script:ChangedFilesList.SelectedIndex)
        if ($item) { [void]$items.Add($item) }
    }

    return @($items.ToArray())
}

function Get-SelectedStatusItem {
    $items = Get-SelectedStatusItems
    if (@($items).Count -gt 0) { return @($items)[0] }
    return $null
}

function Get-SelectedStatusPath {
    $item = Get-SelectedStatusItem
    if ($item) { return $item.Path }
    return '<selected-file>'
}

function New-CleanTrackedStatusItem {
    param([string]$Path)
    return [pscustomobject]@{ Status = '  '; IndexStatus = ' '; WorkTreeStatus = ' '; Path = [string]$Path; RawPath = [string]$Path; OriginalPath = $null; IsTracked = $true; IsCleanTracked = $true }
}

function Get-TrackedFileItemsFromGit {
    if (-not (Test-GitRepository)) { return @() }
    $result = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'ls-files', '--cached', '--full-name') -Caption 'git ls-files --cached --full-name' -AllowFailure -QuietOutput
    if ($result.ExitCode -ne 0) {
        $message = if (-not [string]::IsNullOrWhiteSpace($result.StdErr)) { $result.StdErr.Trim() } else { 'git ls-files failed.' }
        throw $message
    }
    if (Get-Command ConvertFrom-GggTrackedFileList -ErrorAction SilentlyContinue) { return @(ConvertFrom-GggTrackedFileList -Text $result.StdOut) }
    $items = @()
    foreach ($line in @($result.StdOut -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $items += (New-CleanTrackedStatusItem -Path $line.Trim())
    }
    return @($items)
}

function Get-TrackedFileDialogDisplayText {
    param($Item)
    if ($null -eq $Item) { return '[tracked] <file>' }
    $path = if ($Item.Path) { [string]$Item.Path } else { '<file>' }
    return ('[tracked] ' + $path)
}

function Build-RemoveFromGitPreviewForItems {
    param([object[]]$Items)
    $items = @($Items | Where-Object { $_ })
    if (Get-Command Get-GggRemoveFromGitCommandPlan -ErrorAction SilentlyContinue) { return (ConvertTo-GggCommandPreview -Plans (Get-GggRemoveFromGitCommandPlan -Items $items)) }
    if ($items.Count -eq 0) { return 'git rm -- <selected-file>' }
    return ($items | ForEach-Object { 'git rm -- ' + (Quote-Arg $_.Path) }) -join "`r`n"
}

function Build-StopTrackingPreviewForItems {
    param([object[]]$Items)
    $items = @($Items | Where-Object { $_ })
    if (Get-Command Get-GggStopTrackingCommandPlan -ErrorAction SilentlyContinue) { return (ConvertTo-GggCommandPreview -Plans (Get-GggStopTrackingCommandPlan -Items $items)) }
    if ($items.Count -eq 0) { return 'git rm --cached -- <selected-file>' }
    return ($items | ForEach-Object { 'git rm --cached -- ' + (Quote-Arg $_.Path) }) -join "`r`n"
}


function Get-SelectedBranchName {
    $targetBranch = ''
    if ($script:BranchSwitchComboBox) {
        $targetBranch = $script:BranchSwitchComboBox.Text.Trim()
    }
    if ([string]::IsNullOrWhiteSpace($targetBranch)) {
        return '<branch>'
    }
    return $targetBranch
}

function Get-CurrentBranchNameOrPlaceholder {
    if ($script:CurrentBranch) { return $script:CurrentBranch }
    return '<current-branch>'
}

function Convert-GitPorcelainStatusLine {
    param([string]$Line)

    if ([string]::IsNullOrWhiteSpace($Line) -or $Line.Length -lt 4) { return $null }

    $status = $Line.Substring(0, 2)
    $rawPath = $Line.Substring(3)
    $path = $rawPath
    $originalPath = $null

    # Porcelain v1 represents renames/copies as: old/path -> new/path.
    # Keep the raw display path, but use the new path for path-specific git diff calls.
    if ($rawPath -match '^(?<old>.+) -> (?<new>.+)$') {
        $originalPath = $matches['old']
        $path = $matches['new']
    }

    return [pscustomobject]@{
        Status = $status
        IndexStatus = $status.Substring(0,1)
        WorkTreeStatus = $status.Substring(1,1)
        Path = $path
        RawPath = $rawPath
        OriginalPath = $originalPath
    }
}

function Get-StatusMeaning {
    param([string]$Status)

    if (Get-Command Get-GggStatusMeaning -ErrorAction SilentlyContinue) {
        return (Get-GggStatusMeaning -Status $Status)
    }

    switch ($Status) {
        '??' { return 'Untracked file. Git has not staged or compared it yet.' }
        default {
            $x = if ($Status.Length -ge 1) { $Status.Substring(0,1) } else { ' ' }
            $y = if ($Status.Length -ge 2) { $Status.Substring(1,1) } else { ' ' }
            $parts = New-Object System.Collections.Generic.List[string]

            switch ($x) {
                'M' { [void]$parts.Add('staged modification') }
                'A' { [void]$parts.Add('staged addition') }
                'D' { [void]$parts.Add('staged deletion') }
                'R' { [void]$parts.Add('staged rename') }
                'C' { [void]$parts.Add('staged copy') }
                'U' { [void]$parts.Add('staged conflict marker') }
            }
            switch ($y) {
                'M' { [void]$parts.Add('unstaged modification') }
                'D' { [void]$parts.Add('unstaged deletion') }
                'U' { [void]$parts.Add('working-tree conflict marker') }
            }

            if ($parts.Count -eq 0) { return 'Changed file.' }
            return ($parts -join '; ') + '.'
        }
    }
}

function Get-DiffTargetPaths {
    param($Item)

    if (Get-Command Get-GggDiffTargetPaths -ErrorAction SilentlyContinue) {
        return @(Get-GggDiffTargetPaths -Item $Item)
    }

    $paths = New-Object System.Collections.Generic.List[string]
    if ($Item -and $Item.OriginalPath) { [void]$paths.Add([string]$Item.OriginalPath) }
    if ($Item -and $Item.Path) { [void]$paths.Add([string]$Item.Path) }
    return @($paths | Select-Object -Unique)
}

function Invoke-GitDiffText {
    param(
        [string[]]$DiffArguments,
        [string]$Caption
    )

    $args = @('-C', $script:RepoRoot) + $DiffArguments
    $result = Run-External -FileName 'git' -Arguments $args -Caption $Caption -AllowFailure -QuietOutput
    if ($result.ExitCode -ne 0 -and -not [string]::IsNullOrWhiteSpace($result.StdErr)) {
        return $result.StdErr
    }
    return $result.StdOut
}

function Add-DiffSection {
    param(
        [System.Collections.Generic.List[string]]$Sections,
        [string]$Title,
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) { return }
    [void]$Sections.Add(("==== {0} ====" -f $Title))
    [void]$Sections.Add($Text.TrimEnd())
    [void]$Sections.Add('')
}

function Get-UntrackedFilePreview {
    param([string]$RelativePath)

    $fullPath = Join-Path $script:RepoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $fullPath)) {
        return "Untracked file is no longer present on disk:`r`n$RelativePath"
    }

    $item = Get-Item -LiteralPath $fullPath -ErrorAction SilentlyContinue
    if ($item -and $item.PSIsContainer) {
        return "Untracked directory:`r`n$RelativePath`r`n`r`nUse 'Stage selected' to add the directory contents."
    }

    try {
        $maxBytes = 65536
        $bytes = [System.IO.File]::ReadAllBytes($fullPath)
        $probeLength = [Math]::Min($bytes.Length, 4096)
        $isBinary = $false
        for ($i = 0; $i -lt $probeLength; $i++) {
            if ($bytes[$i] -eq 0) { $isBinary = $true; break }
        }
        if ($isBinary) {
            return "Untracked binary file:`r`n$RelativePath`r`n`r`nSize: $($bytes.Length) bytes`r`n`r`nBinary content is not shown in the diff preview."
        }

        $content = [System.Text.Encoding]::UTF8.GetString($bytes, 0, [Math]::Min($bytes.Length, $maxBytes))
        $suffix = if ($bytes.Length -gt $maxBytes) { "`r`n`r`n... preview truncated at $maxBytes bytes ..." } else { '' }
        return "Untracked file preview:`r`n$RelativePath`r`n`r`nThis file is not tracked yet. Use 'Stage selected' to include it in the next commit.`r`n`r`n$content$suffix"
    } catch {
        return "Untracked file:`r`n$RelativePath`r`n`r`nCould not preview content: $($_.Exception.Message)"
    }
}

#endregion
