# Git Glide GUI - Enhanced Version
# Improvements:
# - Fixed Quote-Arg escaping bug
# - Added input validation
# - Configuration file support
# - Async command execution with progress
# - Improved error handling
# - Stash management
# - Better git state verification
# - Modularized structure
# - Cancel operation support
# - v1.2: robust diff preview, richer tooltips, and persisted splitter/window layout
# - v1.3: fixed changed-file selection binding so diff preview loads reliably
# - v1.4: removed C# Add-Type helper to avoid compiler failures from broken LIB paths
# - v1.5: stash command buttons, custom git command tab, resizable action/log areas, wrapped help text
# - v1.6: discoverable splitter grips, stronger stash/custom-command UX, top progress/status splitter
# - v1.7: persistent user-selectable theme colors for sections, buttons, text, lists, outputs, and splitters
# - v1.8: fixed Appearance splitter startup crash and persisted Appearance splitter layout
# - v1.9: stronger stash/custom-git tabs, visible main work splitter, adaptive footer/header spacing
# - v2.1: functional release/tag management tab, soft undo last commit, audit logging, and stricter custom-command safety
# - v2.2: extracted testable Git command safety module, quality-check scripts, and Pester/static test suite
# - v2.3: renamed to Git Glide GUI, added repository-status service, suggested next action, and temporary-repo integration tests
# - v2.4: fixed startup outside a repository, added repository picker/open-repo workflow, and clearer non-repo guidance
# - v2.5: added initialize-new-repository workflow for folders that intentionally are not Git repositories yet
# - v2.6: intention-based startup choices, first-commit wizard, .gitignore templates, and remote setup
# - v2.7: richer onboarding tooltips, cleaner startup layout, clickable safe suggestions, beginner/advanced mode, onboarding module, and broader integration tests
# - v2.8: extracted staging/changed-file command planning, improved beginner guidance, and added staging workflow tests
# - v2.8.2: hotfix startup repository choices and strict-mode single-item staging previews
# - v2.9: branch-operation module extraction, branch workflow tests, dirty-tree guidance, and more clickable safe suggestions
# - v3.0: hotfix v2.9 parser regression, extracted stash operations, stash workflow tests, stash recovery guidance, and Windows smoke launch script
# - v3.1: extracted tag/release operations, tag workflow tests, and mandatory Windows smoke-launch packaging gate
# - v3.2: extracted commit operations, commit workflow tests, Conventional Commits guidance, and history model scaffold
# - v3.5: conflict/recovery guidance module, recovery panel, and cherry-pick command planning
# - v3.6: resolved/unresolved conflict state, stage resolved file, operation-aware continue guidance, merge tool config, and improved graph-action coupling
# - v3.6.6: GitHub publish guidance with private-repository and Copilot-training privacy reminders
# - v3.6.8: tracked-file browser for clean file replacement/remove workflows
# - v3.6.9: restored and extended Git Flow merge/publish workflow guidance
# - v3.6.10.1: protected-branch commit warning and merge guide formatting hotfix
# - v3.6.11: branch context banner, protected-branch workflow guards, and package/version consistency
# - v3.6.12: UI organization with Simple/Workflow/Expert modes, mode-aware tabs, command palette, and Changed Files context banner to reduce visual overload without removing functionality.
# - v3.6.13: workflow checklist and branch cleanup guidance with release consistency smoke checks.
# - v3.8: repository state doctor, conflict marker scanner, dynamic banner sizing, branch relationships, and local quality checks.

param(
    [string]$RepositoryPath = '',
    [switch]$SmokeTest
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing


[System.Windows.Forms.Application]::EnableVisualStyles()

# v2.3: import pure, UI-free helpers when packaged with the GUI.
# The script keeps fallback implementations below so the GUI still starts if a module is missing.
$script:CoreModulePath = Join-Path $PSScriptRoot '..\..\modules\GitGlideGUI.Core\GitCommandSafety.psm1'
$script:StatusModulePath = Join-Path $PSScriptRoot '..\..\modules\GitGlideGUI.Core\GitRepositoryStatus.psm1'
$script:OnboardingModulePath = Join-Path $PSScriptRoot '..\..\modules\GitGlideGUI.Core\GitRepositoryOnboarding.psm1'
$script:StagingModulePath = Join-Path $PSScriptRoot '..\..\modules\GitGlideGUI.Core\GitStagingOperations.psm1'
$script:BranchModulePath = Join-Path $PSScriptRoot '..\..\modules\GitGlideGUI.Core\GitBranchOperations.psm1'
$script:StashModulePath = Join-Path $PSScriptRoot '..\..\modules\GitGlideGUI.Core\GitStashOperations.psm1'
$script:TagModulePath = Join-Path $PSScriptRoot '..\..\modules\GitGlideGUI.Core\GitTagOperations.psm1'
$script:CommitModulePath = Join-Path $PSScriptRoot '..\..\modules\GitGlideGUI.Core\GitCommitOperations.psm1'
$script:HistoryModulePath = Join-Path $PSScriptRoot '..\..\modules\GitGlideGUI.Core\GitHistoryOperations.psm1'
$script:RecoveryModulePath = Join-Path $PSScriptRoot '..\..\modules\GitGlideGUI.Core\GitConflictRecovery.psm1'
$script:CherryPickModulePath = Join-Path $PSScriptRoot '..\..\modules\GitGlideGUI.Core\GitCherryPickOperations.psm1'
$script:LearningModulePath = Join-Path $PSScriptRoot '..\..\modules\GitGlideGUI.Core\GitLearningGuidance.psm1'
$script:GitHubModulePath = Join-Path $PSScriptRoot '..\..\modules\GitGlideGUI.Core\GitHubOperations.psm1'
foreach ($modulePath in @($script:CoreModulePath, $script:StatusModulePath, $script:OnboardingModulePath, $script:StagingModulePath, $script:BranchModulePath, $script:StashModulePath, $script:TagModulePath, $script:CommitModulePath, $script:HistoryModulePath, $script:RecoveryModulePath, $script:CherryPickModulePath, $script:LearningModulePath, $script:GitHubModulePath)) {
    if (Test-Path -LiteralPath $modulePath) {
        try { Import-Module -Name $modulePath -Force -DisableNameChecking -ErrorAction Stop }
        catch { Write-Warning "Failed to import Git Glide GUI core module '$modulePath': $_" }
    }
}


# v1.4 note:
# Do not compile helper C# types with Add-Type here. Some developer machines inherit
# broken LIB/INCLUDE paths from GTK/Visual Studio/toolchain installs, and PowerShell's
# C# compiler may treat those path warnings as fatal. Changed-file rows therefore use
# pure PowerShell objects with Display/StatusItem/Path properties.

#region Configuration Management

$script:ConfigPath = Join-Path $PSScriptRoot 'GitGlideGUI-Config.json'
$script:AuditLogPath = Join-Path $PSScriptRoot 'GitGlideGUI-Audit.log'
$script:MaxAuditLogBytes = 2MB
$script:IsShuttingDown = $false
$script:ShutdownCleanupStarted = $false
$script:DefaultConfig = @{
    BaseBranch = 'develop'
    MainBranch = 'main'
    FeatureBranchPrefix = 'feature/'
    HotfixBranchPrefix = 'hotfix/'
    ReleaseBranchPrefix = 'release/'
    RefactorBranchPrefix = 'refactor/'
    AutoStageAll = $true
    AutoPushAfterCommit = $false
    UseForceWithLease = $true
    MaxHistoryLines = 40
    CommitSubjectMaxLength = 72
    WindowWidth = 1580
    WindowHeight = 1080
    TopSplitDistance = 650
    TopLeftSplitDistance = 185
    CommitPreviewSplitDistance = 470
    ContentSplitDistance = 430
    RightSplitDistance = 250
    RootTopSplitDistance = 38
    MainWorkSplitDistance = 470
    HeaderTopAreaSplitDistance = 120
    ChangedFilesActionSplitDistance = 520
    LogActionSplitDistance = 245
    AppearanceSplitDistance = 280
    TagManagementSplitDistance = 300
    SuggestedActionVisible = $true
    LastRepositoryRoot = ''
    DefaultGitIgnoreTemplate = 'General / Windows'
    DefaultRemoteName = 'origin'
    DefaultGitHubOwner = ''
    DefaultGitHubProtocol = 'HTTPS'
    LastPullRequestUrl = ''
    GitHubRepositoryDescription = 'Git Glide GUI is a lightweight, privacy-first Windows Git interface for safer human and AI-assisted software development. It turns fast coding changes into clear versioning choices, helping developers stay in control and use their judgment with command previews, visual staging, recovery guidance, custom actions, and code & documentation checks.'
    ExternalMergeToolCommand = 'git mergetool'
    BeginnerMode = $true
    UiMode = 'Simple'
    BeginnerGuidanceVisible = $true
    EnableAuditLog = $true
    ConfirmDestructiveActions = $true
    SafeCustomGitSubcommands = @(
        'status', 'log', 'diff', 'show', 'branch', 'checkout', 'switch',
        'add', 'reset', 'restore', 'stash', 'push', 'pull', 'fetch',
        'merge', 'rebase', 'cherry-pick', 'tag', 'remote', 'reflog',
        'blame', 'clean', 'mv', 'rm'
    )
    DefaultStashMessagePrefix = 'wip'
    CustomGitButtons = @(
        @{ Label = 'Short status'; Arguments = 'status -sb' },
        @{ Label = 'Last commits'; Arguments = 'log --oneline --decorate -n 12' },
        @{ Label = 'Remote verbose'; Arguments = 'remote -v' }
    )
    ThemeColors = @{
        FormBackground = '#F5F7FA'
        TextColor = '#111827'
        MutedTextColor = '#4B5563'
        HeaderBackground = '#FFFFFF'
        HeaderText = '#111827'
        BranchBackground = '#FFFFFF'
        BranchText = '#111827'
        ActionsBackground = '#FFFFFF'
        ActionsText = '#111827'
        StashBackground = '#FFFFFF'
        StashText = '#111827'
        CustomGitBackground = '#FFFFFF'
        CustomGitText = '#111827'
        FooterBackground = '#F8FAFC'
        FooterText = '#111827'
        CommitBackground = '#FFFFFF'
        CommitText = '#111827'
        ChangedFilesBackground = '#FFFFFF'
        ChangedFilesText = '#111827'
        ListBackground = '#FFFFFF'
        ListText = '#111827'
        DiffBackground = '#FFFFFF'
        DiffText = '#111827'
        DiffAddedText = '#166534'
        DiffRemovedText = '#991B1B'
        DiffHunkText = '#1D4ED8'
        DiffMetadataText = '#4B5563'
        DiffWarningText = '#B45309'
        LogBackground = '#FFFFFF'
        LogText = '#111827'
        PreviewBackground = '#FFFFFF'
        PreviewText = '#111827'
        HelpBackground = '#FFFFFF'
        HelpText = '#111827'
        TextBoxBackground = '#FFFFFF'
        TextBoxText = '#111827'
        ButtonBackground = '#F3F4F6'
        ButtonText = '#111827'
        AccentBackground = '#DCEBFA'
        AccentText = '#111827'
        SplitterBackground = '#D9E6F2'
        SplitterGrip = '#697C92'
        StatusBackground = '#EEF2F7'
        StatusText = '#111827'
        SuccessText = '#166534'
        WarningText = '#B45309'
        ErrorText = '#991B1B'
    }
    AutoPreviewDiffOnSelection = $true
    RememberWindowLayout = $true
}

function Load-Config {
    # Start from defaults, then overlay the user file. This lets newer script versions
    # add config keys without breaking older GitGlideGUI-Config.json files.
    $config = $script:DefaultConfig.Clone()

    if (Test-Path $script:ConfigPath) {
        try {
            $json = Get-Content $script:ConfigPath -Raw | ConvertFrom-Json
            $json.PSObject.Properties | ForEach-Object { $config[$_.Name] = $_.Value }
        } catch {
            Write-Warning "Failed to load config, using defaults: $_"
        }
    }

    return $config
}

function Save-Config {
    param([hashtable]$Config)
    try {
        $Config | ConvertTo-Json -Depth 6 | Set-Content -Path $script:ConfigPath -Encoding UTF8
    } catch {
        Write-Warning "Failed to save config: $_"
    }
}

$script:Config = Load-Config

function Refresh-HistoryVisualGraph {
    try {
        if (-not (Test-GitRepository)) { return }
        if (-not $script:HistoryVisualListView) { return }
        $max = [int]$script:Config.MaxHistoryLines
        if ($script:HistoryMaxCountUpDown) { $max = [int]$script:HistoryMaxCountUpDown.Value }
        if (-not (Get-Command Get-GghHistoryModelCommandPlan -ErrorAction SilentlyContinue)) { return }
        $plan = Get-GghHistoryModelCommandPlan -MaxCount ([Math]::Max($max, 80))
        $result = Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($plan.Arguments)) -Caption $plan.Display -AllowFailure -QuietOutput
        if ($result.ExitCode -ne 0) { return }
        $lines = @($result.StdOut -split '`r?`n' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        $commits = ConvertFrom-GghCommitLog -Lines $lines
        $rows = if (Get-Command ConvertTo-GghVisualGraphRows -ErrorAction SilentlyContinue) { ConvertTo-GghVisualGraphRows -Commits $commits } else { @() }
        $script:HistoryVisualListView.BeginUpdate()
        $script:HistoryVisualListView.Items.Clear()
        foreach ($row in @($rows)) {
            $branches = if ($row.PSObject.Properties['Branches']) { [string]$row.Branches } else { '' }
            $tags = if ($row.PSObject.Properties['Tags']) { [string]$row.Tags } else { '' }
            $remotes = if ($row.PSObject.Properties['Remotes']) { [string]$row.Remotes } else { '' }
            $hint = if ($row.PSObject.Properties['Hint']) { [string]$row.Hint } else { [string]$row.Refs }
            $fullHash = if ($row.PSObject.Properties['FullHash'] -and -not [string]::IsNullOrWhiteSpace([string]$row.FullHash)) { [string]$row.FullHash } else { [string]$row.Hash }
            $item = New-Object System.Windows.Forms.ListViewItem([string]$row.Lane)
            [void]$item.SubItems.Add([string]$row.Kind)
            [void]$item.SubItems.Add([string]$row.Hash)
            [void]$item.SubItems.Add($branches)
            [void]$item.SubItems.Add($tags)
            [void]$item.SubItems.Add($remotes)
            [void]$item.SubItems.Add([string]$row.Subject)
            [void]$item.SubItems.Add([string]$row.Author)
            [void]$item.SubItems.Add([string]$row.Date)
            $item.Tag = $fullHash
            $item.ToolTipText = $hint
            if ([string]$row.Kind -eq 'merge') { $item.ForeColor = [System.Drawing.Color]::DarkBlue }
            elseif (-not [string]::IsNullOrWhiteSpace($tags)) { $item.ForeColor = [System.Drawing.Color]::DarkGreen }
            elseif (-not [string]::IsNullOrWhiteSpace($branches)) { $item.ForeColor = [System.Drawing.Color]::DarkGoldenrod }
            [void]$script:HistoryVisualListView.Items.Add($item)
        }
        $script:HistoryVisualListView.EndUpdate()
        Update-HistorySelectionPreview
    } catch { if ($script:HistorySummaryLabel) { $script:HistorySummaryLabel.Text = 'Visual graph unavailable. Text graph is still safe to use.' } }
}

#endregion

#region Utility Functions

function Resolve-GitRepositoryRoot {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }

    try {
        if (-not (Test-Path -LiteralPath $Path)) { return $null }
        $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
        $resolved = & git -C $resolvedPath rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and $resolved) {
            return ($resolved | Select-Object -First 1).Trim()
        }
    } catch {}

    return $null
}


function Resolve-ExistingDirectoryPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    try {
        if (-not (Test-Path -LiteralPath $Path)) { return $null }
        $item = Get-Item -LiteralPath $Path -ErrorAction Stop
        if (-not $item.PSIsContainer) { return $null }
        return $item.FullName
    } catch {
        return $null
    }
}

function Test-DirectoryHasUserFiles {
    param([string]$Path)

    try {
        $first = Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne '.git' } |
            Select-Object -First 1
        return $null -ne $first
    } catch {
        return $false
    }
}

function Get-NearbyGitRepositoryCandidates {
    param(
        [string]$ScriptRoot,
        [string]$RequestedRepositoryPath
    )

    $candidates = New-Object System.Collections.Generic.List[string]
    function Add-Candidate([string]$CandidatePath) {
        if ([string]::IsNullOrWhiteSpace($CandidatePath)) { return }
        try {
            if (Test-Path -LiteralPath $CandidatePath) {
                $resolvedCandidate = (Resolve-Path -LiteralPath $CandidatePath).Path
                if (-not $candidates.Contains($resolvedCandidate)) { [void]$candidates.Add($resolvedCandidate) }
            }
        } catch {}
    }

    Add-Candidate $RequestedRepositoryPath
    Add-Candidate ([string]$script:Config.LastRepositoryRoot)
    Add-Candidate ((Get-Location).Path)
    Add-Candidate (Join-Path $ScriptRoot '..\..')

    # Common case: the tool package is extracted beside the actual repository.
    # Look one level below nearby parent folders, but cap the scan to avoid slow startup.
    $packageRoot = $null
    try { $packageRoot = (Resolve-Path -LiteralPath (Join-Path $ScriptRoot '..\..')).Path } catch {}
    $parents = New-Object System.Collections.Generic.List[string]
    foreach ($base in @($packageRoot, (Get-Location).Path)) {
        if ([string]::IsNullOrWhiteSpace($base)) { continue }
        try {
            $p1 = Split-Path -Path $base -Parent
            $p2 = if ($p1) { Split-Path -Path $p1 -Parent } else { $null }
            foreach ($p in @($p1, $p2)) {
                if ($p -and (Test-Path -LiteralPath $p) -and -not $parents.Contains($p)) { [void]$parents.Add($p) }
            }
        } catch {}
    }

    foreach ($parent in $parents) {
        Add-Candidate $parent
        try {
            $children = @(Get-ChildItem -LiteralPath $parent -Directory -ErrorAction SilentlyContinue | Select-Object -First 80)
            foreach ($child in $children) { Add-Candidate $child.FullName }
        } catch {}
    }

    return @($candidates)
}

function Get-RepoRoot {
    param(
        [string]$ScriptRoot,
        [string]$RequestedRepositoryPath = ''
    )

    foreach ($candidate in (Get-NearbyGitRepositoryCandidates -ScriptRoot $ScriptRoot -RequestedRepositoryPath $RequestedRepositoryPath)) {
        $root = Resolve-GitRepositoryRoot -Path $candidate
        if ($root) { return $root }
    }

    return $null
}


function Quote-Arg([string]$value) {
    try {
        $cmd = Get-Command ConvertTo-GfgQuotedArgument -ErrorAction SilentlyContinue
        if ($cmd) { return ConvertTo-GfgQuotedArgument -Value $value }
    } catch {}

    if ($null -eq $value) { return '""' }
    if ($value.Length -eq 0) { return '""' }
    if ($value -notmatch '[\s"]') { return $value }

    # Windows command-line quoting. Backslashes before quotes and before the
    # final closing quote are doubled so git receives the intended argument.
    $builder = New-Object System.Text.StringBuilder
    [void]$builder.Append('"')
    $backslashes = 0
    foreach ($ch in $value.ToCharArray()) {
        if ($ch -eq '\') { $backslashes++; continue }
        if ($ch -eq '"') {
            if ($backslashes -gt 0) { [void]$builder.Append(('\' * ($backslashes * 2))) }
            [void]$builder.Append('\"')
            $backslashes = 0
            continue
        }
        if ($backslashes -gt 0) { [void]$builder.Append(('\' * $backslashes)); $backslashes = 0 }
        [void]$builder.Append($ch)
    }
    if ($backslashes -gt 0) { [void]$builder.Append(('\' * ($backslashes * 2))) }
    [void]$builder.Append('"')
    return $builder.ToString()
}

function Validate-BranchName([string]$name) {
    if ([string]::IsNullOrWhiteSpace($name)) {
        return @{ Valid = $false; Error = 'Branch name cannot be empty' }
    }
    if ($name -match '[\\:*?"<>|]') {
        return @{ Valid = $false; Error = 'Branch name contains invalid characters' }
    }
    if ($name -match '\.\.|^\.|\.$|@{|^/|/$|//|\.lock$') {
        return @{ Valid = $false; Error = 'Branch name format is invalid' }
    }
    if ($name.Length -gt 255) {
        return @{ Valid = $false; Error = 'Branch name too long (max 255 characters)' }
    }
    return @{ Valid = $true }
}

function Validate-CommitSubject([string]$subject) {
    $enableConventional = $false
    try {
        if ($script:CommitConventionalGuidanceCheckBox) { $enableConventional = [bool]$script:CommitConventionalGuidanceCheckBox.Checked }
        elseif ($script:Config -and $script:Config.ContainsKey('ConventionalCommitGuidanceEnabled')) { $enableConventional = [bool]$script:Config.ConventionalCommitGuidanceEnabled }
    } catch {}

    if (Get-Command Test-GgcCommitMessage -ErrorAction SilentlyContinue) {
        $result = Test-GgcCommitMessage -Subject $subject -MaxSubjectLength ([int]$script:Config.CommitSubjectMaxLength) -ConventionalCommits:$enableConventional
        return @{ Valid = [bool]$result.Valid; Error = [string]$result.Error; Warning = [string]$result.Warning; Guidance = [string]$result.Guidance }
    }

    if ([string]::IsNullOrWhiteSpace($subject)) {
        return @{ Valid = $false; Error = 'Commit subject cannot be empty'; Warning = ''; Guidance = '' }
    }
    if ($subject.Length -gt $script:Config.CommitSubjectMaxLength) {
        return @{ Valid = $true; Error = ''; Warning = "Subject is long (${subject.Length} chars, recommended max: $($script:Config.CommitSubjectMaxLength))"; Guidance = '' }
    }
    return @{ Valid = $true; Error = ''; Warning = ''; Guidance = '' }
}

function New-LogTimestamp {
    return (Get-Date).ToString('HH:mm:ss.fff')
}

function Get-ConfigInt {
    param([string]$Name, [int]$DefaultValue)
    try {
        if ($script:Config.ContainsKey($Name) -and $null -ne $script:Config[$Name]) { return [int]$script:Config[$Name] }
    } catch {}
    return $DefaultValue
}

function Set-ConfigValue {
    param([string]$Name, $Value)
    $script:Config[$Name] = $Value
}

function Get-ConfigBool {
    param([string]$Name, [bool]$DefaultValue)
    try {
        if ($script:Config.ContainsKey($Name) -and $null -ne $script:Config[$Name]) { return [System.Convert]::ToBoolean($script:Config[$Name]) }
    } catch {}
    return $DefaultValue
}

function Write-AuditLog {
    param([string]$Message)
    try {
        if ($script:Config -and $script:Config.ContainsKey('EnableAuditLog') -and -not [System.Convert]::ToBoolean($script:Config.EnableAuditLog)) { return }
    } catch {}
    try {
        if ((Test-Path $script:AuditLogPath) -and (Get-Item $script:AuditLogPath).Length -gt $script:MaxAuditLogBytes) {
            $archivePath = $script:AuditLogPath -replace '\.log$', ('.' + (Get-Date).ToString('yyyyMMdd-HHmmss') + '.log')
            Move-Item -Path $script:AuditLogPath -Destination $archivePath -Force
        }
        $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
        Add-Content -Path $script:AuditLogPath -Value ("[$timestamp] $Message") -Encoding UTF8
    } catch {}
}

function Confirm-GuiAction {
    param(
        [string]$Title,
        [string]$Message,
        [System.Windows.Forms.MessageBoxIcon]$Icon = [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    $confirm = Get-ConfigBool -Name 'ConfirmDestructiveActions' -DefaultValue $true
    if (-not $confirm) { return $true }
    $result = [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::YesNo, $Icon)
    return $result -eq [System.Windows.Forms.DialogResult]::Yes
}

function Test-CustomGitArgsAllowed {
    param([object[]]$Arguments)
    $arr = @($Arguments)
    $allowed = @()
    try { $allowed = @($script:Config.SafeCustomGitSubcommands) } catch {}

    try {
        $cmd = Get-Command Test-GfgCustomGitArgsAllowed -ErrorAction SilentlyContinue
        if ($cmd) { return (Test-GfgCustomGitArgsAllowed -Arguments $arr -AllowedSubcommands $allowed) }
    } catch { throw }

    if ($arr.Count -eq 0) { return $true }
    $subcommand = ([string]$arr[0]).ToLowerInvariant()
    if ($allowed.Count -eq 0) {
        $allowed = @('status','log','diff','show','branch','checkout','switch','add','reset','restore','stash','push','pull','fetch','merge','rebase','cherry-pick','tag','remote','reflog','blame','clean','mv','rm')
    }
    if (@($allowed | ForEach-Object { ([string]$_).ToLowerInvariant() }) -notcontains $subcommand) {
        throw "Custom Git subcommand '$subcommand' is not enabled. Use a supported git subcommand or add it deliberately to SafeCustomGitSubcommands in GitGlideGUI-Config.json."
    }
    return $true
}

function Test-GitArgsPotentiallyDestructive {
    param([object[]]$Arguments)
    try {
        $cmd = Get-Command Test-GfgGitArgsPotentiallyDestructive -ErrorAction SilentlyContinue
        if ($cmd) { return (Test-GfgGitArgsPotentiallyDestructive -Arguments @($Arguments)) }
    } catch { throw }

    $arr = @($Arguments | ForEach-Object { [string]$_ })
    if ($arr.Count -eq 0) { return $false }
    $sub = $arr[0].ToLowerInvariant()
    $joined = ' ' + (($arr | ForEach-Object { $_.ToLowerInvariant() }) -join ' ') + ' '
    if ($sub -eq 'reset' -and ($joined -match ' --hard( |$)' -or $joined -match ' --merge( |$)' -or $joined -match ' --keep( |$)')) { return $true }
    if ($sub -eq 'clean') { return $true }
    if ($sub -eq 'push' -and ($joined -match ' --force( |$)' -or $joined -match ' -f( |$)' -or $joined -match ' --delete( |$)' -or $joined -match ' :')) { return $true }
    if ($sub -eq 'branch' -and ($joined -match ' -d( |$)' -or $joined -match ' -d ' -or $joined -match ' --delete( |$)')) { return $true }
    if ($sub -eq 'tag' -and ($joined -match ' -d( |$)' -or $joined -match ' --delete( |$)' -or $joined -match ' -f( |$)' -or $joined -match ' --force( |$)')) { return $true }
    if ($sub -eq 'stash' -and ($joined -match ' drop( |$)' -or $joined -match ' clear( |$)' -or $joined -match ' pop( |$)')) { return $true }
    if ($sub -eq 'checkout' -and ($joined -match ' -f( |$)' -or $joined -match ' --force( |$)')) { return $true }
    if ($sub -eq 'switch' -and ($joined -match ' -f( |$)' -or $joined -match ' --force( |$)')) { return $true }
    if ($sub -eq 'restore') { return $true }
    if ($sub -eq 'rm') { return $true }
    if ($sub -eq 'rebase') { return $true }
    return $false
}

function ConvertTo-PlainHashtable {
    param($Value)

    $hash = @{}
    if ($null -eq $Value) { return $hash }

    if ($Value -is [hashtable]) {
        foreach ($key in $Value.Keys) { $hash[[string]$key] = $Value[$key] }
        return $hash
    }

    if ($Value -is [System.Collections.IDictionary]) {
        foreach ($key in $Value.Keys) { $hash[[string]$key] = $Value[$key] }
        return $hash
    }

    try {
        foreach ($prop in $Value.PSObject.Properties) {
            if ($null -ne $prop.Name) { $hash[[string]$prop.Name] = $prop.Value }
        }
    } catch {}

    return $hash
}

function Get-MergedThemeColors {
    $defaults = ConvertTo-PlainHashtable -Value $script:DefaultConfig.ThemeColors
    $current = @{}
    if ($script:Config.ContainsKey('ThemeColors')) {
        $current = ConvertTo-PlainHashtable -Value $script:Config['ThemeColors']
    }

    $theme = @{}
    foreach ($key in $defaults.Keys) { $theme[[string]$key] = [string]$defaults[$key] }
    foreach ($key in $current.Keys) {
        $value = [string]$current[$key]
        if (-not [string]::IsNullOrWhiteSpace($value)) { $theme[[string]$key] = $value }
    }
    return $theme
}

function ConvertTo-ThemeColor {
    param(
        [string]$Value,
        [string]$Fallback = '#FFFFFF'
    )

    $candidate = if ([string]::IsNullOrWhiteSpace($Value)) { $Fallback } else { $Value.Trim() }
    try {
        return [System.Drawing.ColorTranslator]::FromHtml($candidate)
    } catch {
        try { return [System.Drawing.ColorTranslator]::FromHtml($Fallback) } catch { return [System.Drawing.Color]::White }
    }
}

function ConvertFrom-ThemeColor {
    param([System.Drawing.Color]$Color)
    return ('#{0:X2}{1:X2}{2:X2}' -f $Color.R, $Color.G, $Color.B)
}

function Get-ThemeColor {
    param(
        [string]$Key,
        [string]$Fallback = '#FFFFFF'
    )

    if (-not $script:ThemeColors) { $script:ThemeColors = Get-MergedThemeColors }
    if ($script:ThemeColors.ContainsKey($Key)) {
        return ConvertTo-ThemeColor -Value ([string]$script:ThemeColors[$Key]) -Fallback $Fallback
    }
    return ConvertTo-ThemeColor -Value $Fallback -Fallback $Fallback
}

function Set-ThemeColorValue {
    param(
        [string]$Key,
        [string]$Hex
    )

    if (-not $script:ThemeColors) { $script:ThemeColors = Get-MergedThemeColors }
    [void](ConvertTo-ThemeColor -Value $Hex -Fallback '#FFFFFF')
    $script:ThemeColors[$Key] = $Hex.ToUpperInvariant()
    Set-ConfigValue -Name 'ThemeColors' -Value $script:ThemeColors
    Save-Config -Config $script:Config
}

function Get-ThemeColorCatalog {
    return @(
        @{ Section = 'Global'; Key = 'FormBackground'; Name = 'Window background' },
        @{ Section = 'Global'; Key = 'TextColor'; Name = 'Default text color' },
        @{ Section = 'Repository status'; Key = 'HeaderBackground'; Name = 'Background' },
        @{ Section = 'Repository status'; Key = 'HeaderText'; Name = 'Text color' },
        @{ Section = 'Feature branch'; Key = 'BranchBackground'; Name = 'Background' },
        @{ Section = 'Feature branch'; Key = 'BranchText'; Name = 'Text color' },
        @{ Section = 'Common actions'; Key = 'ActionsBackground'; Name = 'Background' },
        @{ Section = 'Common actions'; Key = 'ActionsText'; Name = 'Text color' },
        @{ Section = 'Stash tab'; Key = 'StashBackground'; Name = 'Background' },
        @{ Section = 'Stash tab'; Key = 'StashText'; Name = 'Text color' },
        @{ Section = 'Custom Git tab'; Key = 'CustomGitBackground'; Name = 'Background' },
        @{ Section = 'Custom Git tab'; Key = 'CustomGitText'; Name = 'Text color' },
        @{ Section = 'Action footers'; Key = 'FooterBackground'; Name = 'Footer background' },
        @{ Section = 'Action footers'; Key = 'FooterText'; Name = 'Footer text color' },
        @{ Section = 'Commit / preview'; Key = 'CommitBackground'; Name = 'Commit panel background' },
        @{ Section = 'Commit / preview'; Key = 'CommitText'; Name = 'Commit panel text' },
        @{ Section = 'Changed files'; Key = 'ChangedFilesBackground'; Name = 'Section background' },
        @{ Section = 'Changed files'; Key = 'ChangedFilesText'; Name = 'Section text' },
        @{ Section = 'Lists'; Key = 'ListBackground'; Name = 'List background' },
        @{ Section = 'Lists'; Key = 'ListText'; Name = 'List text' },
        @{ Section = 'Diff preview'; Key = 'DiffBackground'; Name = 'Background' },
        @{ Section = 'Diff preview'; Key = 'DiffText'; Name = 'Text color' },
        @{ Section = 'Diff preview'; Key = 'DiffAddedText'; Name = 'Added lines' },
        @{ Section = 'Diff preview'; Key = 'DiffRemovedText'; Name = 'Removed lines' },
        @{ Section = 'Diff preview'; Key = 'DiffHunkText'; Name = 'Hunk headers' },
        @{ Section = 'Diff preview'; Key = 'DiffMetadataText'; Name = 'Metadata lines' },
        @{ Section = 'Diff preview'; Key = 'DiffWarningText'; Name = 'Warnings and conflicts' },
        @{ Section = 'Live output'; Key = 'LogBackground'; Name = 'Background' },
        @{ Section = 'Live output'; Key = 'LogText'; Name = 'Text color' },
        @{ Section = 'Command preview'; Key = 'PreviewBackground'; Name = 'Background' },
        @{ Section = 'Command preview'; Key = 'PreviewText'; Name = 'Text color' },
        @{ Section = 'Help'; Key = 'HelpBackground'; Name = 'Background' },
        @{ Section = 'Help'; Key = 'HelpText'; Name = 'Text color' },
        @{ Section = 'Text input'; Key = 'TextBoxBackground'; Name = 'Input background' },
        @{ Section = 'Text input'; Key = 'TextBoxText'; Name = 'Input text' },
        @{ Section = 'Buttons'; Key = 'ButtonBackground'; Name = 'Button background' },
        @{ Section = 'Buttons'; Key = 'ButtonText'; Name = 'Button text' },
        @{ Section = 'Accent'; Key = 'AccentBackground'; Name = 'Accent background' },
        @{ Section = 'Accent'; Key = 'AccentText'; Name = 'Accent text' },
        @{ Section = 'Splitters'; Key = 'SplitterBackground'; Name = 'Visible splitter background' },
        @{ Section = 'Splitters'; Key = 'SplitterGrip'; Name = 'Visible splitter grip lines' },
        @{ Section = 'Status bar'; Key = 'StatusBackground'; Name = 'Background' },
        @{ Section = 'Status bar'; Key = 'StatusText'; Name = 'Text color' },
        @{ Section = 'Output semantic colors'; Key = 'SuccessText'; Name = 'Success text' },
        @{ Section = 'Output semantic colors'; Key = 'WarningText'; Name = 'Warning text' },
        @{ Section = 'Output semantic colors'; Key = 'ErrorText'; Name = 'Error text' }
    )
}

function Invoke-ForEachControl {
    param(
        [System.Windows.Forms.Control]$Control,
        [scriptblock]$Action
    )
    if (-not $Control) { return }
    & $Action $Control
    foreach ($child in @($Control.Controls)) {
        Invoke-ForEachControl -Control $child -Action $Action
    }
}

function Set-ControlColorSafe {
    param(
        [System.Windows.Forms.Control]$Control,
        [System.Drawing.Color]$BackColor,
        [System.Drawing.Color]$ForeColor
    )
    if (-not $Control) { return }
    try { $Control.BackColor = $BackColor } catch {}
    try { $Control.ForeColor = $ForeColor } catch {}
}

function Set-SectionTheme {
    param(
        [System.Windows.Forms.Control]$Root,
        [string]$BackKey,
        [string]$ForeKey,
        [string]$BackFallback = '#FFFFFF',
        [string]$ForeFallback = '#111827'
    )
    if (-not $Root) { return }
    $back = Get-ThemeColor -Key $BackKey -Fallback $BackFallback
    $fore = Get-ThemeColor -Key $ForeKey -Fallback $ForeFallback
    Invoke-ForEachControl -Control $Root -Action {
        param($control)
        if ($control -is [System.Windows.Forms.Button]) { return }
        if ($control -is [System.Windows.Forms.RichTextBox]) { return }
        if ($control -is [System.Windows.Forms.TextBox]) { return }
        if ($control -is [System.Windows.Forms.ListBox]) { return }
        if ($control -is [System.Windows.Forms.ComboBox]) { return }
        Set-ControlColorSafe -Control $control -BackColor $back -ForeColor $fore
    }
}

function Apply-ButtonTheme {
    param([System.Windows.Forms.Control]$Root)
    if (-not $Root) { return }
    $back = Get-ThemeColor -Key 'ButtonBackground' -Fallback '#F3F4F6'
    $fore = Get-ThemeColor -Key 'ButtonText' -Fallback '#111827'
    $border = Get-ThemeColor -Key 'SplitterGrip' -Fallback '#697C92'
    Invoke-ForEachControl -Control $Root -Action {
        param($control)
        if ($control -is [System.Windows.Forms.Button]) {
            try { $control.UseVisualStyleBackColor = $false } catch {}
            try { $control.BackColor = $back } catch {}
            try { $control.ForeColor = $fore } catch {}
            try { $control.FlatStyle = [System.Windows.Forms.FlatStyle]::Standard } catch {}
            try { $control.FlatAppearance.BorderColor = $border } catch {}
        }
    }
}

function Apply-InputTheme {
    param([System.Windows.Forms.Control]$Root)
    if (-not $Root) { return }
    $textBack = Get-ThemeColor -Key 'TextBoxBackground' -Fallback '#FFFFFF'
    $textFore = Get-ThemeColor -Key 'TextBoxText' -Fallback '#111827'
    $listBack = Get-ThemeColor -Key 'ListBackground' -Fallback '#FFFFFF'
    $listFore = Get-ThemeColor -Key 'ListText' -Fallback '#111827'
    Invoke-ForEachControl -Control $Root -Action {
        param($control)
        if ($control -is [System.Windows.Forms.TextBox]) {
            Set-ControlColorSafe -Control $control -BackColor $textBack -ForeColor $textFore
        } elseif ($control -is [System.Windows.Forms.ListBox] -or $control -is [System.Windows.Forms.ComboBox]) {
            Set-ControlColorSafe -Control $control -BackColor $listBack -ForeColor $listFore
        }
    }
}

function Apply-SplitterTheme {
    param([System.Windows.Forms.Control]$Root)
    if (-not $Root) { return }
    $back = Get-ThemeColor -Key 'SplitterBackground' -Fallback '#D9E6F2'
    Invoke-ForEachControl -Control $Root -Action {
        param($control)
        if ($control -is [System.Windows.Forms.SplitContainer]) {
            try { $control.BackColor = $back } catch {}
            try { $control.Invalidate() } catch {}
        }
    }
}

function Apply-Theme {
    if (-not $form) { return }

    $formBack = Get-ThemeColor -Key 'FormBackground' -Fallback '#F5F7FA'
    $text = Get-ThemeColor -Key 'TextColor' -Fallback '#111827'
    Set-ControlColorSafe -Control $form -BackColor $formBack -ForeColor $text

    if ($script:HeaderGroup) { Set-SectionTheme -Root $script:HeaderGroup -BackKey 'HeaderBackground' -ForeKey 'HeaderText' }
    if ($script:BranchGroup) { Set-SectionTheme -Root $script:BranchGroup -BackKey 'BranchBackground' -ForeKey 'BranchText' }
    if ($script:ActionsGroup) { Set-SectionTheme -Root $script:ActionsGroup -BackKey 'ActionsBackground' -ForeKey 'ActionsText' }
    if ($script:StashTabPage) { Set-SectionTheme -Root $script:StashTabPage -BackKey 'StashBackground' -ForeKey 'StashText' }
    if ($script:CustomGitTabPage) { Set-SectionTheme -Root $script:CustomGitTabPage -BackKey 'CustomGitBackground' -ForeKey 'CustomGitText' }
    if ($script:AppearanceTabPage) { Set-SectionTheme -Root $script:AppearanceTabPage -BackKey 'ActionsBackground' -ForeKey 'ActionsText' }
    if ($script:TagsTabPage) { Set-SectionTheme -Root $script:TagsTabPage -BackKey 'ActionsBackground' -ForeKey 'ActionsText' }
    if ($script:HistoryTabPage) { Set-SectionTheme -Root $script:HistoryTabPage -BackKey 'ActionsBackground' -ForeKey 'ActionsText' }
    if ($script:LearningTabPage) { Set-SectionTheme -Root $script:LearningTabPage -BackKey 'ActionsBackground' -ForeKey 'ActionsText' }
    if ($script:LeftActionsLayout) { Set-SectionTheme -Root $script:LeftActionsLayout -BackKey 'FooterBackground' -ForeKey 'FooterText' }
    if ($script:LogButtonsLayout) { Set-SectionTheme -Root $script:LogButtonsLayout -BackKey 'FooterBackground' -ForeKey 'FooterText' }
    if ($script:CommitPreviewGroup) { Set-SectionTheme -Root $script:CommitPreviewGroup -BackKey 'CommitBackground' -ForeKey 'CommitText' }
    if ($script:ChangedFilesGroup) { Set-SectionTheme -Root $script:ChangedFilesGroup -BackKey 'ChangedFilesBackground' -ForeKey 'ChangedFilesText' }
    if ($script:DiffGroup) { Set-SectionTheme -Root $script:DiffGroup -BackKey 'DiffBackground' -ForeKey 'DiffText' }
    if ($script:LogGroup) { Set-SectionTheme -Root $script:LogGroup -BackKey 'LogBackground' -ForeKey 'LogText' }

    Apply-InputTheme -Root $form
    Apply-ButtonTheme -Root $form
    Apply-SplitterTheme -Root $form

    if ($script:ChangedFilesList) { Set-ControlColorSafe -Control $script:ChangedFilesList -BackColor (Get-ThemeColor -Key 'ListBackground') -ForeColor (Get-ThemeColor -Key 'ListText') }
    if ($script:StashListBox) { Set-ControlColorSafe -Control $script:StashListBox -BackColor (Get-ThemeColor -Key 'ListBackground') -ForeColor (Get-ThemeColor -Key 'ListText') }
    if ($script:CustomGitButtonsListBox) { Set-ControlColorSafe -Control $script:CustomGitButtonsListBox -BackColor (Get-ThemeColor -Key 'ListBackground') -ForeColor (Get-ThemeColor -Key 'ListText') }

    if ($script:DiffTextBox) { Set-ControlColorSafe -Control $script:DiffTextBox -BackColor (Get-ThemeColor -Key 'DiffBackground') -ForeColor (Get-ThemeColor -Key 'DiffText') }
    if ($script:LogTextBox) { Set-ControlColorSafe -Control $script:LogTextBox -BackColor (Get-ThemeColor -Key 'LogBackground') -ForeColor (Get-ThemeColor -Key 'LogText') }
    if ($script:PreviewTextBox) { Set-ControlColorSafe -Control $script:PreviewTextBox -BackColor (Get-ThemeColor -Key 'PreviewBackground') -ForeColor (Get-ThemeColor -Key 'PreviewText') }
    if ($script:HelpTextBox) { Set-ControlColorSafe -Control $script:HelpTextBox -BackColor (Get-ThemeColor -Key 'HelpBackground') -ForeColor (Get-ThemeColor -Key 'HelpText') }

    if ($statusStrip) {
        try { $statusStrip.BackColor = Get-ThemeColor -Key 'StatusBackground' -Fallback '#EEF2F7' } catch {}
        try { $statusStrip.ForeColor = Get-ThemeColor -Key 'StatusText' -Fallback '#111827' } catch {}
        if ($script:StatusValueLabel) { try { $script:StatusValueLabel.ForeColor = Get-ThemeColor -Key 'StatusText' -Fallback '#111827' } catch {} }
    }

    if ($script:ThemePreviewPanel) {
        $accentBack = Get-ThemeColor -Key 'AccentBackground' -Fallback '#DCEBFA'
        $accentFore = Get-ThemeColor -Key 'AccentText' -Fallback '#111827'
        try { $script:ThemePreviewPanel.BackColor = $accentBack } catch {}
        try { $script:ThemePreviewPanel.ForeColor = $accentFore } catch {}
        Invoke-ForEachControl -Control $script:ThemePreviewPanel -Action {
            param($control)
            try { $control.BackColor = $accentBack } catch {}
            try { $control.ForeColor = $accentFore } catch {}
        }
    }

    try { if ($form) { $form.Invalidate($true) } } catch {}
}

function Refresh-ThemeColorList {
    if (-not $script:ThemeColorListBox) { return }
    $script:ThemeCatalog = Get-ThemeColorCatalog
    $script:ThemeColorListBox.BeginUpdate()
    $script:ThemeColorListBox.Items.Clear()
    foreach ($entry in @($script:ThemeCatalog)) {
        $hex = if ($script:ThemeColors.ContainsKey($entry.Key)) { [string]$script:ThemeColors[$entry.Key] } else { '' }
        [void]$script:ThemeColorListBox.Items.Add(('{0} / {1}  =  {2}' -f $entry.Section, $entry.Name, $hex))
    }
    $script:ThemeColorListBox.EndUpdate()
    if ($script:ThemeColorListBox.Items.Count -gt 0 -and $script:ThemeColorListBox.SelectedIndex -lt 0) {
        $script:ThemeColorListBox.SelectedIndex = 0
    }
}

function Get-SelectedThemeEntry {
    if (-not $script:ThemeColorListBox) { return $null }
    $idx = [int]$script:ThemeColorListBox.SelectedIndex
    $catalog = @($script:ThemeCatalog)
    if ($idx -lt 0 -or $idx -ge $catalog.Count) { return $null }
    return $catalog[$idx]
}

function Update-ThemeEditorSelection {
    $entry = Get-SelectedThemeEntry
    if ($null -eq $entry) { return }
    $hex = if ($script:ThemeColors.ContainsKey($entry.Key)) { [string]$script:ThemeColors[$entry.Key] } else { '#FFFFFF' }
    if ($script:ThemeHexTextBox) { $script:ThemeHexTextBox.Text = $hex }
    if ($script:ThemeCurrentColorPanel) { $script:ThemeCurrentColorPanel.BackColor = ConvertTo-ThemeColor -Value $hex -Fallback '#FFFFFF' }
    if ($script:ThemeSelectedLabel) { $script:ThemeSelectedLabel.Text = ('Selected: {0} / {1}' -f $entry.Section, $entry.Name) }
}

function Choose-SelectedThemeColor {
    $entry = Get-SelectedThemeEntry
    if ($null -eq $entry) { return }
    $dialog = New-Object System.Windows.Forms.ColorDialog
    $dialog.FullOpen = $true
    $dialog.Color = Get-ThemeColor -Key ([string]$entry.Key)
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        Set-ThemeColorValue -Key ([string]$entry.Key) -Hex (ConvertFrom-ThemeColor -Color $dialog.Color)
        Refresh-ThemeColorList
        Update-ThemeEditorSelection
        Apply-Theme
    }
}

function Apply-ThemeHexFromEditor {
    $entry = Get-SelectedThemeEntry
    if ($null -eq $entry -or -not $script:ThemeHexTextBox) { return }
    $hex = $script:ThemeHexTextBox.Text.Trim()
    if ($hex -notmatch '^#[0-9A-Fa-f]{6}$') {
        [System.Windows.Forms.MessageBox]::Show('Use #RRGGBB format, for example #F5F7FA.', 'Invalid color', 'OK', 'Information') | Out-Null
        return
    }
    Set-ThemeColorValue -Key ([string]$entry.Key) -Hex $hex
    Refresh-ThemeColorList
    Update-ThemeEditorSelection
    Apply-Theme
}

function Reset-SelectedThemeColor {
    $entry = Get-SelectedThemeEntry
    if ($null -eq $entry) { return }
    $defaults = ConvertTo-PlainHashtable -Value $script:DefaultConfig.ThemeColors
    if ($defaults.ContainsKey($entry.Key)) {
        Set-ThemeColorValue -Key ([string]$entry.Key) -Hex ([string]$defaults[$entry.Key])
        Refresh-ThemeColorList
        Update-ThemeEditorSelection
        Apply-Theme
    }
}

function Reset-AllThemeColors {
    $answer = [System.Windows.Forms.MessageBox]::Show('Reset all saved GUI colors to the built-in defaults?', 'Reset theme colors', 'YesNo', 'Question')
    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    $defaults = ConvertTo-PlainHashtable -Value $script:DefaultConfig.ThemeColors

    $script:ThemeColors = @{}
    foreach ($key in $defaults.Keys) { $script:ThemeColors[$key] = [string]$defaults[$key] }
    Set-ConfigValue -Name 'ThemeColors' -Value $script:ThemeColors
    Save-Config -Config $script:Config
    Refresh-ThemeColorList
    Update-ThemeEditorSelection
    Apply-Theme
}

function New-WrappingLabel {
    param(
        [string]$Text,
        [int]$Height = 42,
        [bool]$Bold = $false
    )
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.AutoSize = $false
    $label.Dock = 'Fill'
    $label.Height = $Height
    $label.MinimumSize = New-Object System.Drawing.Size(0, $Height)
    $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $label.Margin = New-Object System.Windows.Forms.Padding(4, 6, 4, 6)
    if ($Bold) { $label.Font = $script:UiFontBold }
    return $label
}


function Enable-VisibleSplitter {
    param(
        [System.Windows.Forms.SplitContainer]$Splitter,
        [string]$Tooltip = 'Drag this visible splitter to resize adjacent sections. The position is saved when you close the window.'
    )
    if (-not $Splitter) { return }

    $Splitter.BackColor = Get-ThemeColor -Key 'SplitterBackground' -Fallback '#D9E6F2'
    if ($script:ToolTip) {
        $script:ToolTip.SetToolTip($Splitter, $Tooltip)
    }

    $Splitter.Add_Paint({
        param($sender, $e)
        try {
            $splitter = [System.Windows.Forms.SplitContainer]$sender
            $rect = $splitter.SplitterRectangle
            if ($rect.Width -le 0 -or $rect.Height -le 0) { return }

            $backBrush = New-Object System.Drawing.SolidBrush((Get-ThemeColor -Key 'SplitterBackground' -Fallback '#D9E6F2'))
            $linePen = New-Object System.Drawing.Pen((Get-ThemeColor -Key 'SplitterGrip' -Fallback '#697C92'))
            try {
                $e.Graphics.FillRectangle($backBrush, $rect)
                if ($splitter.Orientation -eq [System.Windows.Forms.Orientation]::Horizontal) {
                    $centerY = $rect.Top + [Math]::Floor($rect.Height / 2)
                    for ($i = -1; $i -le 1; $i++) {
                        $y = $centerY + ($i * 2)
                        $e.Graphics.DrawLine($linePen, $rect.Left + 12, $y, $rect.Right - 12, $y)
                    }
                } else {
                    $centerX = $rect.Left + [Math]::Floor($rect.Width / 2)
                    for ($i = -1; $i -le 1; $i++) {
                        $x = $centerX + ($i * 2)
                        $e.Graphics.DrawLine($linePen, $x, $rect.Top + 12, $x, $rect.Bottom - 12)
                    }
                }
            } finally {
                $backBrush.Dispose()
                $linePen.Dispose()
            }
        } catch {}
    })

    # Do not attach a PowerShell SplitterMoved scriptblock here.
    # WinForms can fire SplitterMoved during resize/shutdown while the hosting
    # PowerShell pipeline is stopping, which may surface as a JIT dialog with
    # System.Management.Automation.PipelineStoppedException. The splitter is
    # already repainted by normal WinForms layout/paint invalidation.
}

function Convert-GitCommandTextToArgs {
    param([string]$CommandText)

    if ([string]::IsNullOrWhiteSpace($CommandText)) { return @() }

    try {
        $cmd = Get-Command Convert-GfgGitCommandTextToArgs -ErrorAction SilentlyContinue
        if ($cmd) {
            $arr = @(Convert-GfgGitCommandTextToArgs -CommandText $CommandText)
            if ($arr.Count -gt 0) { [void](Test-CustomGitArgsAllowed -Arguments $arr) }
            return $arr
        }
    } catch { throw }

    $text = $CommandText.Trim()
    if ($text -match "[`r`n]") {
        throw 'Enter one git command only. Multi-line shell scripts are intentionally not supported here.'
    }

    $args = New-Object System.Collections.Generic.List[string]
    $buffer = New-Object System.Text.StringBuilder
    $quote = [char]0
    $escaped = $false

    foreach ($ch in $text.ToCharArray()) {
        if ($escaped) {
            [void]$buffer.Append($ch)
            $escaped = $false
            continue
        }
        if ($quote -eq '"' -and $ch -eq '\') {
            $escaped = $true
            continue
        }
        if ($quote -ne [char]0) {
            if ($ch -eq $quote) {
                $quote = [char]0
            } else {
                [void]$buffer.Append($ch)
            }
            continue
        }
        if ($ch -eq '"' -or $ch -eq "'") {
            $quote = $ch
            continue
        }
        if ([char]::IsWhiteSpace($ch)) {
            if ($buffer.Length -gt 0) {
                [void]$args.Add($buffer.ToString())
                [void]$buffer.Clear()
            }
            continue
        }
        [void]$buffer.Append($ch)
    }

    if ($quote -ne [char]0) { throw 'Unclosed quote in custom git command.' }
    if ($escaped) { [void]$buffer.Append('\') }
    if ($buffer.Length -gt 0) { [void]$args.Add($buffer.ToString()) }

    $arr = @($args.ToArray())
    if ($arr.Count -gt 0 -and $arr[0] -ieq 'git') { $arr = @($arr | Select-Object -Skip 1) }
    if ($arr.Count -ge 2 -and $arr[0] -eq '-C') { $arr = @($arr | Select-Object -Skip 2) }

    if ($arr.Count -eq 0) { return @() }
    foreach ($token in $arr) {
        if ($token -in @('&&','||',';','|','>','>>','<')) {
            throw 'Shell operators are intentionally not supported. Enter only git arguments, for example: status -sb'
        }
    }
    [void](Test-CustomGitArgsAllowed -Arguments $arr)
    return $arr
}

function Format-GitCommandArgs {
    param([object[]]$Arguments)
    try {
        $cmd = Get-Command Format-GfgGitCommandArgs -ErrorAction SilentlyContinue
        if ($cmd) { return Format-GfgGitCommandArgs -Arguments @($Arguments) }
    } catch {}
    if (-not $Arguments -or @($Arguments).Count -eq 0) { return 'git <arguments>' }
    return 'git ' + (($Arguments | ForEach-Object { Quote-Arg ([string]$_) }) -join ' ')
}

function Get-CustomGitButtonDefinitions {
    $defs = @()
    try {
        if ($script:Config.ContainsKey('CustomGitButtons') -and $null -ne $script:Config.CustomGitButtons) {
            $defs = @($script:Config.CustomGitButtons)
        }
    } catch {}
    return @($defs | Where-Object { $_ -and $_.Label -and $_.Arguments })
}

function Save-CustomGitButtonDefinitions {
    param([object[]]$Definitions)
    $clean = @()
    foreach ($def in @($Definitions)) {
        if ($def -and -not [string]::IsNullOrWhiteSpace([string]$def.Label) -and -not [string]::IsNullOrWhiteSpace([string]$def.Arguments)) {
            $clean += @{ Label = [string]$def.Label; Arguments = [string]$def.Arguments }
        }
    }
    $script:CustomGitButtons = @($clean)
    Set-ConfigValue -Name 'CustomGitButtons' -Value @($clean)
    Save-Config -Config $script:Config
}

$script:ThemeColors = Get-MergedThemeColors

#endregion
