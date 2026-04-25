# Git Glide GUI - Enhanced Version v3.6.4
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
foreach ($modulePath in @($script:CoreModulePath, $script:StatusModulePath, $script:OnboardingModulePath, $script:StagingModulePath, $script:BranchModulePath, $script:StashModulePath, $script:TagModulePath, $script:CommitModulePath, $script:HistoryModulePath, $script:RecoveryModulePath, $script:CherryPickModulePath, $script:LearningModulePath)) {
    if (Test-Path -LiteralPath $modulePath) {
        try { Import-Module -Name $modulePath -Force -DisableNameChecking -ErrorAction Stop }
        catch { Write-Warning "Failed to import Git Glide GUI core module '$modulePath': $_" }
    }
}

if ($SmokeTest) {
    Write-Host 'Git Glide GUI v3.6.4 smoke launch OK. Script parsed and modules were importable when present.'
    exit 0
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
    ExternalMergeToolCommand = 'git mergetool'
    BeginnerMode = $true
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
            [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'push', '-u', $RemoteName, 'HEAD') -Caption ("git push -u $RemoteName HEAD") -ShowProgress)
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

#region Command Preview Builders

function Build-FeatureBranchCommandPreview {
    $name = if ($script:FeatureBranchTextBox) { $script:FeatureBranchTextBox.Text.Trim() } else { '' }
    if ([string]::IsNullOrWhiteSpace($name)) { $name = $script:Config.FeatureBranchPrefix + 'your-name' }

    $baseFromBase = (($script:BaseFromDevelopCheckBox) -and $script:BaseFromDevelopCheckBox.Checked)
    if (Get-Command Get-GgbCreateFeatureBranchCommandPlan -ErrorAction SilentlyContinue) {
        return (ConvertTo-GgbCommandPreview -Plans (Get-GgbCreateFeatureBranchCommandPlan -Name $name -BaseBranch $script:Config.BaseBranch -BaseFromBaseBranch:$baseFromBase))
    }

    if ($baseFromBase) {
        return @(
            "git switch $($script:Config.BaseBranch)"
            'git pull --ff-only'
            ('git switch -c ' + $name)
        ) -join "`r`n"
    }
    return ('git switch -c ' + $name)
}

function Build-SwitchBranchPreview {
    $targetBranch = Get-SelectedBranchName
    if (Get-Command Get-GgbSwitchBranchCommandPlan -ErrorAction SilentlyContinue) {
        return (ConvertTo-GgbCommandPreview -Plans (Get-GgbSwitchBranchCommandPlan -TargetBranch $targetBranch))
    }
    return ('git switch ' + $targetBranch)
}

function Build-PullPreview {
    if (Get-Command Get-GgbPullCurrentBranchCommandPlan -ErrorAction SilentlyContinue) {
        return (ConvertTo-GgbCommandPreview -Plans (Get-GgbPullCurrentBranchCommandPlan))
    }
    return 'git pull --ff-only'
}

function Build-BuildPreview([switch]$WithWeb) {
    $args = @('build-test-run.bat', '--force', '--yes', '--stop-running')
    if (-not $WithWeb) { $args += '--no-web' }
    return ($args -join ' ')
}

function Build-PushPreview {
    if ($script:Config.UseForceWithLease -and $script:CommitAmendCheckBox -and $script:CommitAmendCheckBox.Checked) {
        return 'git push --force-with-lease'
    }
    if (Get-Command Get-GgbPushCurrentBranchCommandPlan -ErrorAction SilentlyContinue) {
        return (ConvertTo-GgbCommandPreview -Plans (Get-GgbPushCurrentBranchCommandPlan))
    }
    return 'git push -u origin HEAD'
}

function Build-MergeFeaturePreview {
    $featureBranch = Get-CurrentBranchNameOrPlaceholder
    if (Get-Command Get-GgbMergeFeatureIntoBaseCommandPlan -ErrorAction SilentlyContinue) {
        return (ConvertTo-GgbCommandPreview -Plans (Get-GgbMergeFeatureIntoBaseCommandPlan -FeatureBranch $featureBranch -BaseBranch $script:Config.BaseBranch))
    }
    return @(
        "git switch $($script:Config.BaseBranch)"
        'git pull --ff-only'
        ('git merge --no-ff ' + $featureBranch)
        "git push origin $($script:Config.BaseBranch)"
    ) -join "`r`n"
}

function Build-MergeDevelopPreview {
    if (Get-Command Get-GgbMergeBaseIntoMainCommandPlan -ErrorAction SilentlyContinue) {
        return (ConvertTo-GgbCommandPreview -Plans (Get-GgbMergeBaseIntoMainCommandPlan -BaseBranch $script:Config.BaseBranch -MainBranch $script:Config.MainBranch))
    }
    return @(
        "git switch $($script:Config.MainBranch)"
        'git pull --ff-only'
        "git merge --no-ff $($script:Config.BaseBranch)"
        "git push origin $($script:Config.MainBranch)"
    ) -join "`r`n"
}

function Build-StageSelectedPreview {
    $items = Get-SelectedStatusItems
    if (Get-Command Get-GggStageSelectedCommandPlan -ErrorAction SilentlyContinue) {
        return (ConvertTo-GggCommandPreview -Plans (Get-GggStageSelectedCommandPlan -Items $items))
    }
    if ($items.Count -le 1) { 
        return ('git add -- ' + (Quote-Arg (Get-SelectedStatusPath))) 
    }
    return ($items | ForEach-Object { 
        'git add -- ' + (Quote-Arg $_.Path) 
    }) -join "`r`n"
}

function Build-UnstageSelectedPreview {
    $items = Get-SelectedStatusItems
    $hasCommits = Test-GitHasCommits
    if (Get-Command Get-GggUnstageSelectedCommandPlan -ErrorAction SilentlyContinue) {
        return (ConvertTo-GggCommandPreview -Plans (Get-GggUnstageSelectedCommandPlan -Items $items -RepositoryHasNoCommits:(-not $hasCommits)))
    }
    if ($items.Count -le 1) {
        $path = Get-SelectedStatusPath
        $gitArgs = Get-UnstageGitArgumentsForPath -Path $path
        return ('git ' + (($gitArgs | ForEach-Object { Quote-Arg ([string]$_) }) -join ' '))
    }
    return ($items | ForEach-Object {
        $gitArgs = Get-UnstageGitArgumentsForPath -Path $_.Path
        'git ' + (($gitArgs | ForEach-Object { Quote-Arg ([string]$_) }) -join ' ')
    }) -join "`r`n"
}

function Build-ShowDiffPreview {
    $item = Get-SelectedStatusItem
    if (Get-Command Get-GggShowDiffCommandPreview -ErrorAction SilentlyContinue) {
        return (Get-GggShowDiffCommandPreview -Item $item)
    }
    if (-not $item) { return 'git diff HEAD -- <selected-file>' }

    $paths = Get-DiffTargetPaths -Item $item
    $quotedPaths = ($paths | ForEach-Object { Quote-Arg $_ }) -join ' '

    if ($item.Status -eq '??') {
        return "# untracked file preview for $quotedPaths"
    }

    $commands = New-Object System.Collections.Generic.List[string]
    if ($item.IndexStatus -ne ' ' -and $item.IndexStatus -ne '?') {
        [void]$commands.Add('git diff --no-ext-diff --no-color --find-renames --cached -- ' + $quotedPaths)
    }
    if ($item.WorkTreeStatus -ne ' ' -and $item.WorkTreeStatus -ne '?') {
        [void]$commands.Add('git diff --no-ext-diff --no-color --find-renames -- ' + $quotedPaths)
    }
    if ($commands.Count -eq 0) {
        [void]$commands.Add('git diff --no-ext-diff --no-color --find-renames HEAD -- ' + $quotedPaths)
    }
    return ($commands -join "`r`n")
}

function Build-StashPushPreview {
    $message = if ($script:StashMessageTextBox) { $script:StashMessageTextBox.Text.Trim() } else { '' }
    $includeUntracked = ($script:StashIncludeUntrackedCheckBox -and $script:StashIncludeUntrackedCheckBox.Checked)
    $keepIndex = ($script:StashKeepIndexCheckBox -and $script:StashKeepIndexCheckBox.Checked)
    if (Get-Command Get-GgsStashPushCommandPlan -ErrorAction SilentlyContinue) {
        return (ConvertTo-GgsCommandPreview -Plan (Get-GgsStashPushCommandPlan -Message $message -IncludeUntracked:$includeUntracked -KeepIndex:$keepIndex))
    }
    $parts = New-Object System.Collections.Generic.List[string]
    [void]$parts.Add('git stash push')
    if ($includeUntracked) { [void]$parts.Add('-u') }
    if ($keepIndex) { [void]$parts.Add('--keep-index') }
    if (-not [string]::IsNullOrWhiteSpace($message)) {
        [void]$parts.Add('-m')
        [void]$parts.Add((Quote-Arg $message))
    }
    return ($parts -join ' ')
}

function Build-StashPushIncludeUntrackedPreview {
    $message = if ($script:StashMessageTextBox) { $script:StashMessageTextBox.Text.Trim() } else { '' }
    if (Get-Command Get-GgsStashPushCommandPlan -ErrorAction SilentlyContinue) {
        return (ConvertTo-GgsCommandPreview -Plan (Get-GgsStashPushCommandPlan -Message $message -IncludeUntracked))
    }
    if ([string]::IsNullOrWhiteSpace($message)) { return 'git stash push -u' }
    return 'git stash push -u -m ' + (Quote-Arg $message)
}

function Build-StashPushKeepIndexPreview {
    $message = if ($script:StashMessageTextBox) { $script:StashMessageTextBox.Text.Trim() } else { '' }
    if (Get-Command Get-GgsStashPushCommandPlan -ErrorAction SilentlyContinue) {
        return (ConvertTo-GgsCommandPreview -Plan (Get-GgsStashPushCommandPlan -Message $message -KeepIndex))
    }
    if ([string]::IsNullOrWhiteSpace($message)) { return 'git stash push --keep-index' }
    return 'git stash push --keep-index -m ' + (Quote-Arg $message)
}

function Build-StashListPreview {
    if (Get-Command Get-GgsStashListCommandPlan -ErrorAction SilentlyContinue) { return (ConvertTo-GgsCommandPreview -Plan (Get-GgsStashListCommandPlan)) }
    return 'git stash list'
}

function Build-StashShowPreview {
    $stashRef = Get-SelectedStashRef -DefaultLatest
    if (-not $stashRef) { $stashRef = 'stash@{0}' }
    if (Get-Command Get-GgsStashShowPatchCommandPlan -ErrorAction SilentlyContinue) { return (ConvertTo-GgsCommandPreview -Plan (Get-GgsStashShowPatchCommandPlan -StashRef $stashRef)) }
    return "git stash show --stat --patch $stashRef"
}

function Build-StashApplyPreview {
    param([switch]$RestoreIndex)
    $stashRef = Get-SelectedStashRef
    if (-not $stashRef) { $stashRef = '<selected-stash>' }
    if ((Get-Command Get-GgsStashApplyCommandPlan -ErrorAction SilentlyContinue) -and (Get-Command Test-GgsStashRef -ErrorAction SilentlyContinue) -and (Test-GgsStashRef $stashRef)) {
        return (ConvertTo-GgsCommandPreview -Plan (Get-GgsStashApplyCommandPlan -StashRef $stashRef -RestoreIndex:$RestoreIndex))
    }
    $indexPart = if ($RestoreIndex) { ' --index' } else { '' }
    return "git stash apply$indexPart $stashRef"
}

function Build-StashApplyIndexPreview { return (Build-StashApplyPreview -RestoreIndex) }

function Build-StashNameStatusPreview {
    $stashRef = Get-SelectedStashRef -DefaultLatest
    if (-not $stashRef) { $stashRef = 'stash@{0}' }
    if (Get-Command Get-GgsStashShowNameStatusCommandPlan -ErrorAction SilentlyContinue) { return (ConvertTo-GgsCommandPreview -Plan (Get-GgsStashShowNameStatusCommandPlan -StashRef $stashRef)) }
    return "git stash show --name-status $stashRef"
}

function Build-StashPopPreview {
    param([switch]$RestoreIndex)
    $stashRef = Get-SelectedStashRef -DefaultLatest
    if (-not $stashRef) { $stashRef = 'stash@{0}' }
    if ((Get-Command Get-GgsStashPopCommandPlan -ErrorAction SilentlyContinue) -and (Get-Command Test-GgsStashRef -ErrorAction SilentlyContinue) -and (Test-GgsStashRef $stashRef)) {
        return (ConvertTo-GgsCommandPreview -Plan (Get-GgsStashPopCommandPlan -StashRef $stashRef -RestoreIndex:$RestoreIndex))
    }
    $indexPart = if ($RestoreIndex) { ' --index' } else { '' }
    return "git stash pop$indexPart $stashRef"
}

function Build-StashPopIndexPreview { return (Build-StashPopPreview -RestoreIndex) }

function Build-StashDropPreview {
    $stashRef = Get-SelectedStashRef
    if (-not $stashRef) { $stashRef = '<selected-stash>' }
    if ((Get-Command Get-GgsStashDropCommandPlan -ErrorAction SilentlyContinue) -and (Get-Command Test-GgsStashRef -ErrorAction SilentlyContinue) -and (Test-GgsStashRef $stashRef)) {
        return (ConvertTo-GgsCommandPreview -Plan (Get-GgsStashDropCommandPlan -StashRef $stashRef))
    }
    return "git stash drop $stashRef"
}

function Build-StashBranchPreview {
    $stashRef = Get-SelectedStashRef -DefaultLatest
    if (-not $stashRef) { $stashRef = 'stash@{0}' }
    $branchName = if ($script:StashBranchTextBox -and -not [string]::IsNullOrWhiteSpace($script:StashBranchTextBox.Text)) { $script:StashBranchTextBox.Text.Trim() } else { '<new-branch>' }
    if ((Get-Command Get-GgsStashBranchCommandPlan -ErrorAction SilentlyContinue) -and (Get-Command Test-GgsStashRef -ErrorAction SilentlyContinue) -and (Test-GgsStashRef $stashRef) -and $branchName -ne '<new-branch>') {
        return (ConvertTo-GgsCommandPreview -Plan (Get-GgsStashBranchCommandPlan -BranchName $branchName -StashRef $stashRef))
    }
    return "git stash branch $(Quote-Arg $branchName) $stashRef"
}

function Build-CustomGitPreview {

    $cmd = if ($script:CustomGitCommandTextBox) { $script:CustomGitCommandTextBox.Text.Trim() } else { '' }
    if ([string]::IsNullOrWhiteSpace($cmd)) { return 'git <custom arguments>' }
    try {
        return (Format-GitCommandArgs -Arguments (Convert-GitCommandTextToArgs -CommandText $cmd))
    } catch {
        return "git <invalid custom command>`r`n# $($_.Exception.Message)"
    }
}

function Build-StatusPreview {
    return 'git status'
}

function Build-HistoryPreview {
    $max = [int]$script:Config.MaxHistoryLines
    if ($script:HistoryMaxCountUpDown) { $max = [int]$script:HistoryMaxCountUpDown.Value }
    if (Get-Command Get-GghGraphCommandPlan -ErrorAction SilentlyContinue) { return (ConvertTo-GghCommandPreview -Plans (Get-GghGraphCommandPlan -MaxCount $max)) }
    return "git log --graph --decorate --oneline --all -n $max"
}

function Build-HistoryModelPreview {
    $max = [int]$script:Config.MaxHistoryLines
    if ($script:HistoryMaxCountUpDown) { $max = [int]$script:HistoryMaxCountUpDown.Value }
    if (Get-Command Get-GghHistoryModelCommandPlan -ErrorAction SilentlyContinue) { return (ConvertTo-GghCommandPreview -Plans (Get-GghHistoryModelCommandPlan -MaxCount ([Math]::Max($max, 80)))) }
    return 'git log --date=iso-strict --format=<graph-model-fields> --all'
}

#endregion

#region Commit Functions

function Get-CommitPlan {
    $subject = if ($script:CommitSubjectTextBox) { 
        $script:CommitSubjectTextBox.Text.Trim() 
    } else { '' }
    
    $body = if ($script:CommitBodyTextBox) { 
        $script:CommitBodyTextBox.Text 
    } else { '' }
    
    $amend = if ($script:CommitAmendCheckBox) { 
        [bool]$script:CommitAmendCheckBox.Checked 
    } else { $false }
    
    $stageAll = if ($script:CommitStageAllCheckBox) { 
        [bool]$script:CommitStageAllCheckBox.Checked 
    } else { $false }
    
    $pushAfter = if ($script:CommitPushAfterCheckBox) { 
        [bool]$script:CommitPushAfterCheckBox.Checked 
    } else { $false }

    $enableConventional = if ($script:CommitConventionalGuidanceCheckBox) { [bool]$script:CommitConventionalGuidanceCheckBox.Checked } else { [bool]$script:Config.ConventionalCommitGuidanceEnabled }

    if (Get-Command Get-GgcCommitCommandPlan -ErrorAction SilentlyContinue) {
        return Get-GgcCommitCommandPlan -Subject $subject -Body $body -StageAll:$stageAll -Amend:$amend -PushAfter:$pushAfter -UseForceWithLease:([bool]$script:Config.UseForceWithLease) -DefaultRemoteName ([string]$script:Config.DefaultRemoteName) -MaxSubjectLength ([int]$script:Config.CommitSubjectMaxLength) -ConventionalCommits:$enableConventional
    }

    $messageText = if ([string]::IsNullOrWhiteSpace($subject)) {
        '<missing-subject>'
    } else {
        $msg = $subject
        if (-not [string]::IsNullOrWhiteSpace($body)) {
            $msg += "`r`n`r`n" + $body.TrimEnd()
        }
        $msg
    }

    $commands = New-Object System.Collections.Generic.List[string]
    if ($stageAll) { [void]$commands.Add('git add -A') }
    
    $commitParts = New-Object System.Collections.Generic.List[string]
    [void]$commitParts.Add('git commit')

    if ($amend) {
        [void]$commitParts.Add('--amend')
    }

    [void]$commitParts.Add('-F')
    [void]$commitParts.Add('<temp-commit-message-file>')
    [void]$commands.Add(($commitParts -join ' '))
    
    if ($pushAfter) {
        if ($amend -and $script:Config.UseForceWithLease) {
            [void]$commands.Add('git push --force-with-lease')
        } else {
            [void]$commands.Add('git push -u origin HEAD')
        }
    }

    return [pscustomobject]@{
        Subject = $subject
        Body = $body
        Amend = $amend
        StageAll = $stageAll
        PushAfter = $pushAfter
        MessageText = $messageText
        Commands = @($commands)
        Validation = (Validate-CommitSubject $subject)
        Plans = @()
    }
}

function Build-CommitMessageText {
    return (Get-CommitPlan).MessageText
}

function Build-CommitPreview {
    $plan = Get-CommitPlan
    $commandsText = if ($plan.Commands) { @($plan.Commands) -join "`r`n" } else { 'git commit -F <temp-commit-message-file>' }
    $guidance = ''
    try {
        if ($plan.Validation) {
            $validation = $plan.Validation
            if (-not [string]::IsNullOrWhiteSpace([string]$validation.Warning)) { $guidance += "`r`nWarning: $($validation.Warning)" }
            if (-not [string]::IsNullOrWhiteSpace([string]$validation.Guidance)) { $guidance += "`r`nGuidance: $($validation.Guidance)" }
        }
    } catch {}
    return $commandsText + "`r`n`r`nCommit message file content:`r`n--------------------------------`r`n" + $plan.MessageText + $guidance
}

function Update-CommitPreview {
    Set-CommandPreview -Title 'Commit preview' -Commands (Build-CommitPreview) -Notes 'Edit the subject/body or options to update this preview.'
}

#endregion

#region Preview Helper Functions

function Invoke-PreviewBuilder {
    param(
        [scriptblock]$Builder,
        [string]$Fallback = '(preview unavailable)'
    )

    try {
        $result = & $Builder
        if ([string]::IsNullOrWhiteSpace([string]$result)) {
            return $Fallback
        }
        return [string]$result
    } catch {
        return "$Fallback`r`nError: $($_.Exception.Message)"
    }
}

function New-TooltipText {
    param(
        [string]$Title,
        [string]$Description = '',
        [string]$Commands = ''
    )

    $parts = New-Object System.Collections.Generic.List[string]
    if ($Title) { [void]$parts.Add($Title) }
    if ($Description) {
        [void]$parts.Add('')
        [void]$parts.Add($Description)
    }
    if ($Commands) {
        [void]$parts.Add('')
        [void]$parts.Add('Git command preview:')
        [void]$parts.Add($Commands)
    }
    return ($parts -join "`r`n")
}

function Set-ControlPreview {
    param(
        [System.Windows.Forms.Control]$Control,
        [scriptblock]$Builder,
        [string]$Title,
        [string]$Notes = ''
    )
    if (-not $Control) { return }
    if (-not $script:ToolTip) { return }
    
    $initialCommands = Invoke-PreviewBuilder -Builder $Builder
    $script:ToolTip.SetToolTip($Control, (New-TooltipText -Title $Title -Description $Notes -Commands $initialCommands))
    
    $Control.Add_MouseEnter({
        $commands = Invoke-PreviewBuilder -Builder $Builder
        Set-CommandPreview -Title $Title -Commands $commands -Notes $Notes
        if ($script:ToolTip -and $Control) {
            $script:ToolTip.SetToolTip($Control, (New-TooltipText -Title $Title -Description $Notes -Commands $commands))
        }
    }.GetNewClosure())
}

#endregion

#region Git Operations

function Load-LocalBranches {
    if (-not (Test-GitRepository)) { return }
    try {
        $result = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'for-each-ref', '--format=%(refname:short)', 'refs/heads') -Caption 'git for-each-ref --format=%(refname:short) refs/heads' -AllowFailure
        
        if ($result.ExitCode -ne 0) { return }
        
        $branches = @($result.StdOut -split "`r?`n" | Where-Object { 
            -not [string]::IsNullOrWhiteSpace($_) 
        })
        
        $currentText = if ($script:BranchSwitchComboBox) { 
            $script:BranchSwitchComboBox.Text 
        } else { '' }
        
        if ($script:BranchSwitchComboBox) {
            $script:BranchSwitchComboBox.BeginUpdate()
            $script:BranchSwitchComboBox.Items.Clear()
            foreach ($branch in $branches) { 
                [void]$script:BranchSwitchComboBox.Items.Add($branch.Trim()) 
            }
            
            if ($script:CurrentBranch -and $script:BranchSwitchComboBox.Items.Contains($script:CurrentBranch)) {
                $script:BranchSwitchComboBox.SelectedItem = $script:CurrentBranch
            } elseif ($currentText -and $script:BranchSwitchComboBox.Items.Contains($currentText)) {
                $script:BranchSwitchComboBox.SelectedItem = $currentText
            } elseif ($script:BranchSwitchComboBox.Items.Count -gt 0) {
                $script:BranchSwitchComboBox.SelectedIndex = 0
            }
            
            $script:BranchSwitchComboBox.EndUpdate()
        }
    } catch {
        Append-Log -Text ('Branch list refresh failed: ' + $_.Exception.Message) -Color ([System.Drawing.Color]::Firebrick)
    }
}

function Load-StashList {
    if (-not (Test-GitRepository)) {
        $script:StashList = @()
        if ($script:StashListBox) { $script:StashListBox.Items.Clear(); [void]$script:StashListBox.Items.Add('(Open a Git repository first)') }
        if ($script:StashCountLabel) { $script:StashCountLabel.Text = '0' }
        return
    }
    try {
        $result = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'stash', 'list') -Caption 'git stash list' -AllowFailure
        
        if ($result.ExitCode -ne 0) { return }
        
        $stashes = @($result.StdOut -split "`r?`n" | Where-Object { 
            -not [string]::IsNullOrWhiteSpace($_) 
        })
        
        $script:StashList = $stashes
        
        if ($script:StashListBox) {
            $script:StashListBox.BeginUpdate()
            $script:StashListBox.Items.Clear()
            foreach ($stash in $stashes) {
                [void]$script:StashListBox.Items.Add($stash)
            }
            $script:StashListBox.EndUpdate()
        }
        
        if ($script:StashCountLabel) {
            $script:StashCountLabel.Text = [string]$stashes.Count
        }
    } catch {
        Append-Log -Text ('Stash list refresh failed: ' + $_.Exception.Message) -Color ([System.Drawing.Color]::Firebrick)
    }
}

function ConvertTo-RepositoryStatusSnapshotFallback {
    $statusResult = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'status', '--porcelain=v1', '--branch') -Caption 'git status --porcelain=v1 --branch' -AllowFailure
    if ($statusResult.ExitCode -ne 0) {
        return [pscustomobject]@{
            Success = $false
            ExitCode = $statusResult.ExitCode
            Error = $statusResult.StdErr
            Branch = '(unknown)'
            Upstream = '(none)'
            BranchState = 'unknown'
            Items = @()
            Summary = [pscustomobject]@{ Total = 0; Staged = 0; Unstaged = 0; Untracked = 0; Conflicted = 0; IsClean = $true }
            Suggestion = 'Git status failed. Check that this folder is a Git repository and that Git is available.'
        }
    }

    $lines = @($statusResult.StdOut -split "`r?`n" | Where-Object { $_ -ne '' })
    $branchLine = $lines | Select-Object -First 1
    $rawItems = @($lines | Select-Object -Skip 1)

    $branch = '(detached?)'
    $upstream = '(none)'
    $state = 'unknown'
    if ($branchLine -match '^##\s+No commits yet on (?<newbranch>.+)$') {
        $branch = $matches['newbranch']
        $upstream = '(none)'
        $state = 'no commits yet'
    } elseif ($branchLine -match '^##\s+(?<branch>[^\.\s]+)(?:\.\.\.(?<upstream>[^\s]+))?(?:\s+(?<state>\[[^\]]+\]))?') {
        $branch = $matches['branch']
        if ($matches['upstream']) { $upstream = $matches['upstream'] }
        if ($matches['state']) { $state = $matches['state'].Trim('[',']') }
        elseif ($matches['upstream']) { $state = 'up to date' }
    }

    $items = @($rawItems | ForEach-Object { Convert-GitPorcelainStatusLine -Line $_ } | Where-Object { $_ })
    $staged = 0; $unstaged = 0; $untracked = 0; $conflicted = 0
    foreach ($item in $items) {
        if ($item.Status -eq '??') { $untracked++; continue }
        if ($item.Status -match 'U' -or $item.Status -in @('AA','DD')) { $conflicted++ }
        if ($item.IndexStatus -ne ' ' -and $item.IndexStatus -ne '?') { $staged++ }
        if ($item.WorkTreeStatus -ne ' ' -and $item.WorkTreeStatus -ne '?') { $unstaged++ }
    }
    $summary = [pscustomobject]@{ Total = $items.Count; Staged = $staged; Unstaged = $unstaged; Untracked = $untracked; Conflicted = $conflicted; IsClean = ($items.Count -eq 0) }
    $suggestion = Get-SuggestedNextAction -Branch $branch -Upstream $upstream -BranchState $state -Summary $summary

    return [pscustomobject]@{
        Success = $true
        ExitCode = 0
        Error = ''
        Branch = $branch
        Upstream = $upstream
        BranchState = $state
        Items = $items
        Summary = $summary
        Suggestion = $suggestion
    }
}

function Get-RepositoryStatusSnapshot {
    try {
        $cmd = Get-Command Get-GfgRepositoryStatus -ErrorAction SilentlyContinue
        if ($cmd) { return Get-GfgRepositoryStatus -RepositoryPath $script:RepoRoot }
    } catch {
        Append-Log -Text ('Repository status service failed, using fallback parser: ' + $_.Exception.Message) -Color ([System.Drawing.Color]::DarkOrange)
    }
    return ConvertTo-RepositoryStatusSnapshotFallback
}

function Get-SuggestedNextAction {
    param(
        [string]$Branch,
        [string]$Upstream,
        [string]$BranchState,
        [object]$Summary
    )

    try {
        $cmd = Get-Command Get-GfgRepositoryStatusSuggestion -ErrorAction SilentlyContinue
        if ($cmd) { return Get-GfgRepositoryStatusSuggestion -Branch $Branch -Upstream $Upstream -BranchState $BranchState -Summary $Summary }
    } catch {}

    if ($BranchState -eq 'no commits yet') {
        return 'This repository has no commits yet. Use Setup > First commit... to create .gitignore, stage files, and create the initial commit.'
    }
    if ($Branch -eq '(detached?)') { return 'You are in detached HEAD. Create a branch from this commit or switch back before making normal commits.' }
    if ($Summary -and [int]$Summary.Conflicted -gt 0) { return 'Resolve merge conflicts first, then stage the resolved files and continue the merge/rebase.' }
    if ($Summary -and [int]$Summary.Staged -gt 0) { return 'Review the staged changes and commit them. Use the preview/output panes before pushing.' }
    if ($Summary -and ([int]$Summary.Unstaged -gt 0 -or [int]$Summary.Untracked -gt 0)) { return 'Stage the intended files, or stash the work-in-progress before switching branches.' }
    if ($BranchState -match 'ahead') { return 'Your branch has local commits. Push with normal push or force-with-lease only when intentionally rewriting remote history.' }
    if ($BranchState -match 'behind') { return 'Your branch is behind upstream. Pull/rebase before new work to reduce conflict risk.' }
    if ([string]::IsNullOrWhiteSpace($Upstream) -or $Upstream -eq '(none)') { return 'No upstream is configured. Push and set upstream when this branch is ready to share.' }
    return 'Working tree is clean. Start a feature branch, fetch updates, or create a release/tag when appropriate.'
}

function Set-SuggestedNextAction {
    param(
        [string]$Text,
        [string]$Action = ''
    )
    if ([string]::IsNullOrWhiteSpace($Text)) { $Text = 'Refresh repository status to get a suggestion.' }
    $script:SuggestedNextActionKind = $Action
    if ($script:SuggestedNextActionLabel) {
        $script:SuggestedNextActionLabel.Text = $Text
    }
    if ($script:SuggestedNextActionButton) {
        if ([string]::IsNullOrWhiteSpace($Action)) {
            $script:SuggestedNextActionButton.Enabled = $false
            $script:SuggestedNextActionButton.Text = 'Do it'
        } else {
            $script:SuggestedNextActionButton.Enabled = $true
            $script:SuggestedNextActionButton.Text = 'Do it'
        }
    }
}

function Set-SuggestedNextActionFromSnapshot {
    param([object]$Snapshot)

    if (-not $Snapshot) {
        Set-SuggestedNextAction -Text 'Refresh repository status to get a suggestion.'
        return
    }

    $text = [string]$Snapshot.Suggestion
    $action = ''
    $summary = $Snapshot.Summary
    $branchState = [string]$Snapshot.BranchState
    $branch = [string]$Snapshot.Branch
    $upstream = [string]$Snapshot.Upstream

    if ($branchState -eq 'no commits yet') {
        $action = 'first-commit'
    } elseif ($summary -and [int]$summary.Conflicted -gt 0) {
        $action = 'show-diff'
    } elseif ($summary -and [int]$summary.Staged -gt 0) {
        $action = 'focus-commit'
    } elseif ($summary -and ([int]$summary.Unstaged -gt 0 -or [int]$summary.Untracked -gt 0)) {
        $stashSuggestion = $null
        if (Get-Command Get-GgsDirtyWorkTreeStashSuggestion -ErrorAction SilentlyContinue) { $stashSuggestion = Get-GgsDirtyWorkTreeStashSuggestion -Summary $summary }
        if ($stashSuggestion) {
            $text = [string]$stashSuggestion.Message
            $action = [string]$stashSuggestion.Action
        } else {
            $action = 'stage-tab'
        }
    } elseif ($branchState -match 'ahead') {
        $action = 'push-current'
    } elseif ($branchState -match 'behind') {
        $action = 'pull-current'
    } elseif (([string]::IsNullOrWhiteSpace($upstream) -or $upstream -eq '(none)') -and -not [string]::IsNullOrWhiteSpace($branch) -and $branch -ne '(detached?)') {
        $action = 'remote-setup'
    } elseif ($summary -and [int]$summary.Total -eq 0) {
        $action = 'branch-tab'
    }

    Set-SuggestedNextAction -Text $text -Action $action
}
function Invoke-SuggestedNextAction {
    $action = [string]$script:SuggestedNextActionKind
    switch ($action) {
        'choose-repo' { [void](Ensure-RepositorySelected); break }
        'first-commit' { [void](Invoke-FirstCommitWizard); break }
        'focus-commit' {
            if ($script:CommitSubjectTextBox) { $script:CommitSubjectTextBox.Focus() }
            Update-CommitPreview
            break
        }
        'stage-tab' {
            if ($script:ActionsTabs -and $script:StageTabPage) { $script:ActionsTabs.SelectedTab = $script:StageTabPage }
            if ($script:ChangedFilesList -and $script:ChangedFilesList.Items.Count -gt 0) { $script:ChangedFilesList.Focus() }
            break
        }
        'branch-tab' {
            if ($script:ActionsTabs -and $script:BranchTabPage) { $script:ActionsTabs.SelectedTab = $script:BranchTabPage }
            if ($script:FeatureBranchTextBox) { $script:FeatureBranchTextBox.Focus() }
            break
        }
        'push-current' { Push-CurrentBranch -ConfirmBeforePush; break }
        'recovery-tab' {
            if ($script:ActionsTabs -and $script:RecoveryTabPage) { $script:ActionsTabs.SelectedTab = $script:RecoveryTabPage }
            break
        }
        'history-tab' {
            if ($script:ActionsTabs -and $script:HistoryTabPage) { $script:ActionsTabs.SelectedTab = $script:HistoryTabPage }
            break
        }
        'pull-current' { Pull-CurrentBranch -ConfirmBeforePull; break }
        'stash-dirty-work' { Invoke-StashDirtyWorkSuggestedAction; break }
        'remote-setup' { [void](Show-RemoteSetupDialog); break }
        'show-diff' { Show-SelectedDiff; break }
        default {
            Set-CommandPreview -Title 'Suggested next action' -Commands '(no safe one-click action is available for this state)' -Notes 'The suggestion is informational because automatically executing this Git workflow could surprise the user.'
        }
    }
}

function Refresh-Status {
    try {
        if (-not (Test-GitRepository)) {
            if ($script:RepoPathValueLabel) { $script:RepoPathValueLabel.Text = if ([string]::IsNullOrWhiteSpace($script:RepoRoot)) { '(no repository selected)' } else { $script:RepoRoot } }
            if ($script:BranchValueLabel) { $script:BranchValueLabel.Text = '-' }
            if ($script:UpstreamValueLabel) { $script:UpstreamValueLabel.Text = '-' }
            if ($script:BranchStateValueLabel) { $script:BranchStateValueLabel.Text = '-' }
            if ($script:WorkingTreeValueLabel) { $script:WorkingTreeValueLabel.Text = 'not a repository' }
            if ($script:ChangedCountValueLabel) { $script:ChangedCountValueLabel.Text = '0' }
            if ($script:ChangedFilesList) { $script:ChangedFilesList.Items.Clear() }
            $script:StatusItems = @()
            Set-SuggestedNextAction -Text 'Open existing repo or init new repo before running Git operations.' -Action 'choose-repo'
            return
        }

        $script:BranchValueLabel.Text = 'loading...'
        $script:WorkingTreeValueLabel.Text = 'loading...'
        Set-SuggestedNextAction -Text 'Refreshing repository status...'
        $script:ChangedFilesList.Items.Clear()
        $script:StatusItems = @()

        $snapshot = Get-RepositoryStatusSnapshot
        if (-not $snapshot -or -not $snapshot.Success) {
            $message = if ($snapshot -and $snapshot.Error) { $snapshot.Error } else { 'git status failed.' }
            Append-Log -Text ('Refresh failed: ' + $message) -Color ([System.Drawing.Color]::Firebrick)
            Set-SuggestedNextAction -Text 'Git status failed. Check that this folder is a Git repository and that Git is available.'
            return
        }

        $items = @($snapshot.Items)
        $script:CurrentBranch = [string]$snapshot.Branch
        $script:CurrentUpstream = [string]$snapshot.Upstream
        $script:CurrentBranchState = [string]$snapshot.BranchState

        $script:BranchValueLabel.Text = $script:CurrentBranch
        $script:UpstreamValueLabel.Text = $script:CurrentUpstream
        $script:BranchStateValueLabel.Text = $script:CurrentBranchState
        $script:WorkingTreeValueLabel.Text = if ($items.Count -gt 0) { 'changed' } else { 'clean' }
        $script:RepoPathValueLabel.Text = $script:RepoRoot
        $script:ChangedCountValueLabel.Text = [string]$items.Count
        Set-SuggestedNextActionFromSnapshot -Snapshot $snapshot

        Load-LocalBranches
        Load-StashList

        $script:SuppressDiffPreview = $true
        $script:ChangedFilesList.BeginUpdate()
        try {
            foreach ($parsed in $items) {
                if (-not $parsed) { continue }
                $display = ('[{0}] {1}' -f $parsed.Status, $parsed.RawPath)
                # Pure PowerShell row payload. DisplayMember shows Display, while
                # StatusItem keeps the parsed git status available for diff/stage/unstage.
                $listItem = [pscustomobject]@{
                    Display = $display
                    StatusItem = $parsed
                    Path = [string]$parsed.Path
                    RawPath = [string]$parsed.RawPath
                    Status = [string]$parsed.Status
                }
                [void]$script:ChangedFilesList.Items.Add($listItem)
                $script:StatusItems += $parsed
            }
        } finally {
            $script:ChangedFilesList.EndUpdate()
            $script:SuppressDiffPreview = $false
        }

        if ($script:StatusItems.Count -eq 0) {
            $script:DiffTextBox.Text = '(Working tree is clean. No file diff to preview.)'
        } else {
            if ($script:ChangedFilesList.SelectedIndex -lt 0) { $script:ChangedFilesList.SelectedIndex = 0 }
            if (Get-ConfigBool -Name 'AutoPreviewDiffOnSelection' -DefaultValue $true) { Show-SelectedDiff }
        }

        Set-StatusBar("Ready. Branch: $($script:CurrentBranch)")
    } catch {
        Append-Log -Text ('Refresh failed: ' + $_.Exception.Message) -Color ([System.Drawing.Color]::Firebrick)
        Set-SuggestedNextAction -Text 'Refresh failed. Check the Output tab for details.'
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Refresh failed', 'OK', 'Error') | Out-Null
    }
}

function Show-SelectedDiff {
    if ($script:SuppressDiffPreview) { return }

    if ($script:ChangedFilesList -and $script:ChangedFilesList.Items.Count -gt 0 -and $script:ChangedFilesList.SelectedIndex -lt 0) {
        # Make the Show diff button forgiving: if there are changed files but no
        # selected item according to WinForms, use the first row instead of showing
        # the unhelpful placeholder.
        $script:ChangedFilesList.SelectedIndex = 0
    }

    $item = Get-SelectedStatusItem
    if (-not $item) {
        $debug = ''
        if ($script:ChangedFilesList) {
            $debug = "`r`n`r`nDebug: Items=$($script:ChangedFilesList.Items.Count), SelectedIndex=$($script:ChangedFilesList.SelectedIndex), StatusItems=$(@($script:StatusItems).Count). Click Refresh, then select a row."
        }
        $script:DiffTextBox.Text = "(Select a changed file to preview its diff.)$debug"
        return
    }
    
    $oldCursor = $form.Cursor
    try {
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        Set-StatusBar('Loading diff preview...')

        $path = [string]$item.Path
        $paths = Get-DiffTargetPaths -Item $item
        $sections = New-Object System.Collections.Generic.List[string]

        $header = New-Object System.Collections.Generic.List[string]
        [void]$header.Add(('File:   ' + $item.RawPath))
        [void]$header.Add(('Status: [{0}] {1}' -f $item.Status, (Get-StatusMeaning -Status $item.Status)))
        if ($item.OriginalPath) { [void]$header.Add(('Rename: ' + $item.OriginalPath + ' -> ' + $item.Path)) }
        [void]$header.Add('')

        if ($item.Status -eq '??') {
            [void]$header.Add((Get-UntrackedFilePreview -RelativePath $path))
            $script:DiffTextBox.Text = ($header -join "`r`n")
            Set-StatusBar('Ready. Untracked file preview loaded.')
            return
        }

        if ($item.Status -match 'U') {
            $ccArgs = @('diff', '--no-ext-diff', '--no-color', '--cc', '--') + $paths
            $ccText = Invoke-GitDiffText -DiffArguments $ccArgs -Caption ('git diff --cc -- ' + ($paths -join ' '))
            Add-DiffSection -Sections $sections -Title 'Conflict diff' -Text $ccText
        } else {
            if ($item.IndexStatus -ne ' ' -and $item.IndexStatus -ne '?') {
                $cachedArgs = @('diff', '--no-ext-diff', '--no-color', '--find-renames', '--cached', '--') + $paths
                $cachedText = Invoke-GitDiffText -DiffArguments $cachedArgs -Caption ('git diff --cached -- ' + ($paths -join ' '))
                Add-DiffSection -Sections $sections -Title 'Staged changes (index)' -Text $cachedText
            }

            if ($item.WorkTreeStatus -ne ' ' -and $item.WorkTreeStatus -ne '?') {
                $workArgs = @('diff', '--no-ext-diff', '--no-color', '--find-renames', '--') + $paths
                $workText = Invoke-GitDiffText -DiffArguments $workArgs -Caption ('git diff -- ' + ($paths -join ' '))
                Add-DiffSection -Sections $sections -Title 'Unstaged changes (working tree)' -Text $workText
            }
        }

        if ($sections.Count -eq 0) {
            $headArgs = @('diff', '--no-ext-diff', '--no-color', '--find-renames', 'HEAD', '--') + $paths
            $headText = Invoke-GitDiffText -DiffArguments $headArgs -Caption ('git diff HEAD -- ' + ($paths -join ' '))
            Add-DiffSection -Sections $sections -Title 'Changes compared with HEAD' -Text $headText
        }

        if ($sections.Count -eq 0) {
            [void]$sections.Add('(No textual diff output for selected file. This can happen for binary files, mode-only changes, or a clean path after refresh.)')
        }

        $script:DiffTextBox.Text = (@($header.ToArray()) + @($sections.ToArray()) -join "`r`n")
        Set-CommandPreview -Title 'Selected file diff preview' -Commands (Build-ShowDiffPreview) -Notes 'The preview separates staged and unstaged changes so you can see exactly what will be committed.'
        Set-StatusBar('Ready. Diff preview loaded.')
    } catch {
        Append-Log -Text ('Diff failed: ' + $_.Exception.Message) -Color ([System.Drawing.Color]::Firebrick)
        $script:DiffTextBox.Text = "Diff failed:`r`n$($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Diff failed', 'OK', 'Error') | Out-Null
    } finally {
        $form.Cursor = $oldCursor
    }
}

function Stage-SelectedFile {
    $items = Get-SelectedStatusItems
    if ($items.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('Select one or more changed files first.', 'No file selected', 'OK', 'Information') | Out-Null
        return
    }
    
    try {
        if (Get-Command Get-GggStageSelectedCommandPlan -ErrorAction SilentlyContinue) {
            foreach ($plan in @(Get-GggStageSelectedCommandPlan -Items $items)) {
                $gitArgs = @('-C', $script:RepoRoot) + @($plan.Arguments)
                [void](Run-External -FileName 'git' -Arguments $gitArgs -Caption $plan.Display)
            }
            Refresh-Status
            return
        }
        foreach ($item in $items) {
            [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'add', '--', $item.Path) -Caption ('git add -- ' + $item.Path))
        }
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Stage failed', 'OK', 'Error') | Out-Null
    }
}

function Unstage-SelectedFile {
    $items = Get-SelectedStatusItems
    if ($items.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('Select one or more changed files first.', 'No file selected', 'OK', 'Information') | Out-Null
        return
    }

    try {
        $hasCommits = Test-GitHasCommits
        if (Get-Command Get-GggUnstageSelectedCommandPlan -ErrorAction SilentlyContinue) {
            foreach ($plan in @(Get-GggUnstageSelectedCommandPlan -Items $items -RepositoryHasNoCommits:(-not $hasCommits))) {
                $gitArgs = @('-C', $script:RepoRoot) + @($plan.Arguments)
                [void](Run-External -FileName 'git' -Arguments $gitArgs -Caption $plan.Display -AllowFailure)
            }
            Refresh-Status
            return
        }
        foreach ($item in $items) {
            $unstageArgs = Get-UnstageGitArgumentsForPath -Path $item.Path
            [void](Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($unstageArgs)) -Caption ('git ' + (($unstageArgs | ForEach-Object { Quote-Arg ([string]$_) }) -join ' ')) -AllowFailure)
        }
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Unstage failed', 'OK', 'Error') | Out-Null
    }
}

function Stage-AllChanges {
    try {
        if (Get-Command Get-GggStageAllCommandPlan -ErrorAction SilentlyContinue) {
            foreach ($plan in @(Get-GggStageAllCommandPlan)) {
                $gitArgs = @('-C', $script:RepoRoot) + @($plan.Arguments)
                [void](Run-External -FileName 'git' -Arguments $gitArgs -Caption $plan.Display)
            }
            Refresh-Status
            return
        }
        [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'add', '-A') -Caption 'git add -A')
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Stage all failed', 'OK', 'Error') | Out-Null
    }
}

function Show-GitStatus {
    try {
        $result = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'status') -Caption 'git status' -AllowFailure
        
        if ($result.ExitCode -eq 0) {
            $script:DiffTextBox.Text = if ([string]::IsNullOrWhiteSpace($result.StdOut)) { 
                '(No status output.)' 
            } else { 
                $result.StdOut 
            }
        }
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'git status failed', 'OK', 'Error') | Out-Null
    }
}

function Show-GitHistoryGraph {
    try {
        if (-not (Test-GitRepository)) {
            Set-SuggestedNextAction -Text 'Open or initialize a repository before loading history.' -Action 'choose-repo'
            return
        }

        $max = [int]$script:Config.MaxHistoryLines
        if ($script:HistoryMaxCountUpDown) { $max = [int]$script:HistoryMaxCountUpDown.Value }
        $plan = $null
        if (Get-Command Get-GghGraphCommandPlan -ErrorAction SilentlyContinue) { $plan = Get-GghGraphCommandPlan -MaxCount $max }
        $args = if ($plan) { @('-C', $script:RepoRoot) + @($plan.Arguments) } else { @('-C', $script:RepoRoot, 'log', '--graph', '--decorate', '--oneline', '--all', '-n', [string]$max) }
        $caption = if ($plan) { [string]$plan.Display } else { "git log --graph --decorate --oneline --all -n $max" }
        $result = Run-External -FileName 'git' -Arguments $args -Caption $caption -AllowFailure -QuietOutput

        $text = if ($result.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($result.StdOut)) { $result.StdOut } else { '(No history output.)' }
        if ($script:HistoryGraphTextBox) { $script:HistoryGraphTextBox.Text = $text }
        if ($script:DiffTextBox) { $script:DiffTextBox.Text = $text }
        if ($script:HistorySummaryLabel) { $script:HistorySummaryLabel.Text = "Read-only graph loaded: $max commits requested." }
        Refresh-HistoryVisualGraph
        Set-CommandPreview -Title 'History / Graph' -Commands (Build-HistoryPreview) -Notes 'Read-only command. It does not modify the repository.'
        Set-SuggestedNextAction -Text 'History graph loaded. Inspect branch tips, tags, and merges before risky operations.'
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'git log failed', 'OK', 'Error') | Out-Null
    }
}

function Refresh-HistoryModelSummary {
    try {
        if (-not (Test-GitRepository)) { return }
        $max = [int]$script:Config.MaxHistoryLines
        if ($script:HistoryMaxCountUpDown) { $max = [int]$script:HistoryMaxCountUpDown.Value }
        if (-not (Get-Command Get-GghHistoryModelCommandPlan -ErrorAction SilentlyContinue)) { return }
        $plan = Get-GghHistoryModelCommandPlan -MaxCount ([Math]::Max($max, 80))
        $result = Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($plan.Arguments)) -Caption $plan.Display -AllowFailure -QuietOutput
        if ($result.ExitCode -ne 0) { return }
        $lines = @($result.StdOut -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        $commits = ConvertFrom-GghCommitLog -Lines $lines
        $summary = Format-GghHistorySummary -Commits $commits
        if ($script:HistorySummaryLabel) { $script:HistorySummaryLabel.Text = $summary }
        Refresh-HistoryVisualGraph
    } catch {
        if ($script:HistorySummaryLabel) { $script:HistorySummaryLabel.Text = 'History model summary unavailable. The graph text can still be used.' }
    }
}

#endregion

#region Branch Operations

function Create-FeatureBranch {
    $name = $script:FeatureBranchTextBox.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($name)) {
        [System.Windows.Forms.MessageBox]::Show('Enter a feature branch name first.', 'Missing branch name', 'OK', 'Warning') | Out-Null
        return
    }

    $validation = if (Get-Command Test-GgbBranchName -ErrorAction SilentlyContinue) { Test-GgbBranchName -Name $name } else { Validate-BranchName $name }
    if (-not $validation.Valid) {
        [System.Windows.Forms.MessageBox]::Show($validation.Error, 'Invalid branch name', 'OK', 'Warning') | Out-Null
        return
    }

    if (Test-BranchExists $name) {
        [System.Windows.Forms.MessageBox]::Show("Branch '$name' already exists.", 'Branch exists', 'OK', 'Warning') | Out-Null
        return
    }

    try {
        $baseFromBase = (($script:BaseFromDevelopCheckBox) -and $script:BaseFromDevelopCheckBox.Checked)
        if ($baseFromBase -and -not (Test-CleanWorkingTree -Operation "switch/pull before creating branch '$name'")) { return }

        if (Get-Command Get-GgbCreateFeatureBranchCommandPlan -ErrorAction SilentlyContinue) {
            foreach ($plan in @(Get-GgbCreateFeatureBranchCommandPlan -Name $name -BaseBranch $script:Config.BaseBranch -BaseFromBaseBranch:$baseFromBase)) {
                $gitArgs = @('-C', $script:RepoRoot) + @($plan.Arguments)
                [void](Run-External -FileName 'git' -Arguments $gitArgs -Caption $plan.Display -ShowProgress)
            }
        } elseif ($baseFromBase) {
            [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'switch', $script:Config.BaseBranch) -Caption "git switch $($script:Config.BaseBranch)" -ShowProgress)
            [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'pull', '--ff-only') -Caption 'git pull --ff-only' -ShowProgress)
            [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'switch', '-c', $name) -Caption ('git switch -c ' + $name))
        } else {
            [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'switch', '-c', $name) -Caption ('git switch -c ' + $name))
        }
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Create branch failed', 'OK', 'Error') | Out-Null
    }
}

function Switch-SelectedBranch {
    $targetBranch = $script:BranchSwitchComboBox.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($targetBranch)) {
        [System.Windows.Forms.MessageBox]::Show('Choose or enter a branch name first.', 'Missing branch', 'OK', 'Warning') | Out-Null
        return
    }

    try {
        if (-not (Test-CleanWorkingTree -Operation "switch to branch '$targetBranch'")) { return }

        $msg = "This will run:`r`n`r`n$(Build-SwitchBranchPreview)`r`n`r`nContinue?"
        $answer = [System.Windows.Forms.MessageBox]::Show($msg, 'Confirm branch switch', 'YesNo', 'Question')
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }

        if (Get-Command Get-GgbSwitchBranchCommandPlan -ErrorAction SilentlyContinue) {
            foreach ($plan in @(Get-GgbSwitchBranchCommandPlan -TargetBranch $targetBranch)) {
                $gitArgs = @('-C', $script:RepoRoot) + @($plan.Arguments)
                [void](Run-External -FileName 'git' -Arguments $gitArgs -Caption $plan.Display -ShowProgress)
            }
        } else {
            [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'switch', $targetBranch) -Caption ('git switch ' + $targetBranch) -ShowProgress)
        }
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Branch switch failed', 'OK', 'Error') | Out-Null
    }
}

function Pull-CurrentBranch {
    param([switch]$ConfirmBeforePull)
    try {
        if (-not (Test-CleanWorkingTree -Operation 'pull current branch')) { return }

        if ($ConfirmBeforePull) {
            $msg = "This will run:`r`n`r`n$(Build-PullPreview)`r`n`r`nContinue?"
            $answer = [System.Windows.Forms.MessageBox]::Show($msg, 'Confirm pull current branch', 'YesNo', 'Question')
            if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        }

        if (Get-Command Get-GgbPullCurrentBranchCommandPlan -ErrorAction SilentlyContinue) {
            foreach ($plan in @(Get-GgbPullCurrentBranchCommandPlan)) {
                $gitArgs = @('-C', $script:RepoRoot) + @($plan.Arguments)
                $result = Run-External -FileName 'git' -Arguments $gitArgs -Caption $plan.Display -ShowProgress -AllowFailure
                if ($result.ExitCode -ne 0) { Show-GitFailureGuidance -Result $result -Operation 'pull current branch' -ShowDialog; Refresh-Status; return }
            }
        } else {
            $result = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'pull', '--ff-only') -Caption 'git pull --ff-only' -ShowProgress -AllowFailure
            if ($result.ExitCode -ne 0) { Show-GitFailureGuidance -Result $result -Operation 'pull current branch' -ShowDialog; Refresh-Status; return }
        }
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Pull failed', 'OK', 'Error') | Out-Null
    }
}
#endregion
#region Build Operations

function Run-Build {
    param([switch]$WithWeb)
    
    try {
        $args = @('/c', 'build-test-run.bat', '--force', '--yes', '--stop-running')
        if (-not $WithWeb) { $args += '--no-web' }
        
        [void](Run-External -FileName 'cmd.exe' -Arguments $args -WorkingDirectory $script:RepoRoot -Caption ('build-test-run.bat ' + (($args | Select-Object -Skip 2) -join ' ')) -ShowProgress)
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Build failed', 'OK', 'Error') | Out-Null
    }
}

#endregion

#region Recovery and Cherry-pick Operations

function Set-RecoveryGuidancePanel {
    param(
        [AllowNull()][object]$Guidance,
        [string]$FallbackText = ''
    )

    try {
        $text = $FallbackText
        if ($Guidance) {
            if (Get-Command Format-GgrRecoveryGuidance -ErrorAction SilentlyContinue) {
                $text = Format-GgrRecoveryGuidance -Guidance $Guidance
            } else {
                $steps = (@($Guidance.RecoverySteps) | ForEach-Object { '- ' + [string]$_ }) -join "`r`n"
                $text = [string]$Guidance.Title + "`r`n`r`n" + [string]$Guidance.Message + "`r`n`r`n" + $steps + "`r`n`r`nGit output:`r`n" + [string]$Guidance.Details
            }
            $script:LastRecoveryGuidance = $Guidance
        }
        if ([string]::IsNullOrWhiteSpace($text)) { $text = 'No recovery guidance is available yet. Run Refresh recovery status after a failed merge, pull, stash, or cherry-pick operation.' }
        if ($script:RecoveryTextBox) { $script:RecoveryTextBox.Text = $text }
        if ($script:RecoverySummaryLabel -and $Guidance) { $script:RecoverySummaryLabel.Text = ([string]$Guidance.Title + ' [' + [string]$Guidance.Kind + ']') }
        elseif ($script:RecoverySummaryLabel) { $script:RecoverySummaryLabel.Text = 'No active recovery guidance.' }
    } catch {
        Append-Log -Text ('Failed to update recovery panel: ' + $_.Exception.Message) -Color ([System.Drawing.Color]::Firebrick)
    }
}

function Show-GitFailureGuidance {
    param(
        [object]$Result,
        [string]$Operation = 'Git operation',
        [switch]$ShowDialog
    )

    try {
        $stdout = if ($Result -and $Result.StdOut) { [string]$Result.StdOut } else { '' }
        $stderr = if ($Result -and $Result.StdErr) { [string]$Result.StdErr } else { '' }
        $exitCode = if ($Result) { try { [int]$Result.ExitCode } catch { 1 } } else { 1 }
        if (Get-Command Get-GgrRecoveryGuidance -ErrorAction SilentlyContinue) {
            $guidance = Get-GgrRecoveryGuidance -Operation $Operation -ExitCode $exitCode -StdOut $stdout -StdErr $stderr
        } else {
            $guidance = [pscustomobject]@{
                Operation = $Operation
                ExitCode = $exitCode
                Kind = 'unknown-failure'
                Severity = 'warning'
                Title = 'Git operation failed'
                Message = "The $Operation command failed. Run git status and inspect the output."
                Details = (($stdout + "`n" + $stderr).Trim())
                RecoverySteps = @('Run git status --short.', 'Resolve conflicts or protect local changes.', 'Retry only when the working tree state is clear.')
                RecommendedAction = 'recovery-tab'
                Plans = @()
                Preview = 'git status --short'
            }
        }
        Set-RecoveryGuidancePanel -Guidance $guidance
        Set-CommandPreview -Title ('Recovery after failed ' + $Operation) -Commands ([string]$guidance.Preview) -Notes ([string]$guidance.Message)
        Set-SuggestedNextAction -Text ([string]$guidance.Message) -Action ([string]$guidance.RecommendedAction)
        Append-Log -Text ('Recovery guidance: ' + [string]$guidance.Message) -Color ([System.Drawing.Color]::DarkOrange)
        foreach ($step in @($guidance.RecoverySteps)) { Append-Log -Text ('  - ' + [string]$step) -Color ([System.Drawing.Color]::DarkOrange) }
        if ($ShowDialog) {
            [System.Windows.Forms.MessageBox]::Show(([string]$guidance.Message + "`r`n`r`n" + ((@($guidance.RecoverySteps) | ForEach-Object { '- ' + [string]$_ }) -join "`r`n")), 'Recovery guidance', 'OK', 'Warning') | Out-Null
        }
    } catch {
        Append-Log -Text ('Failed to build recovery guidance: ' + $_.Exception.Message) -Color ([System.Drawing.Color]::Firebrick)
    }
}

function Refresh-ConflictFiles {
    try {
        if (-not (Test-GitRepository)) { return }
        $plan = if (Get-Command Get-GgrUnmergedFilesCommandPlan -ErrorAction SilentlyContinue) { Get-GgrUnmergedFilesCommandPlan } else { [pscustomobject]@{ Arguments=@('diff','--name-only','--diff-filter=U'); Display='git diff --name-only --diff-filter=U' } }
        $result = Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($plan.Arguments)) -Caption ([string]$plan.Display) -AllowFailure -QuietOutput
        $files = if (Get-Command ConvertFrom-GgrConflictFileList -ErrorAction SilentlyContinue) { ConvertFrom-GgrConflictFileList -Text ([string]$result.StdOut) } else { @(([string]$result.StdOut) -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) }
        if ($script:ConflictFilesListBox) {
            $script:ConflictFilesListBox.Items.Clear()
            foreach ($file in @($files)) { [void]$script:ConflictFilesListBox.Items.Add([string]$file) }
        }
        if (@($files).Count -gt 0) {
            $msg = if (Get-Command Format-GgrConflictFileGuidance -ErrorAction SilentlyContinue) { Format-GgrConflictFileGuidance -Files $files } else { 'Unresolved conflict files found.' }
            Set-RecoveryGuidancePanel -FallbackText $msg
        }
        Update-RecoveryStatePanel -State (Get-RecoveryStateSnapshot)
    } catch {
        Append-Log -Text ('Failed to refresh conflict files: ' + $_.Exception.Message) -Color ([System.Drawing.Color]::Firebrick)
    }
}

function Get-SelectedConflictFilePath {
    if (-not $script:ConflictFilesListBox -or $script:ConflictFilesListBox.SelectedItem -eq $null) { return '' }
    $relative = [string]$script:ConflictFilesListBox.SelectedItem
    if ([string]::IsNullOrWhiteSpace($relative)) { return '' }
    return (Join-Path $script:RepoRoot $relative)
}

function Open-SelectedConflictFile {
    try {
        $path = Get-SelectedConflictFilePath
        if ([string]::IsNullOrWhiteSpace($path)) { [System.Windows.Forms.MessageBox]::Show('Select a conflicted file first.', 'No conflicted file selected', 'OK', 'Information') | Out-Null; return }
        if (-not (Test-Path -LiteralPath $path)) { [System.Windows.Forms.MessageBox]::Show("The selected file was not found:`r`n$path", 'File not found', 'OK', 'Warning') | Out-Null; return }
        Start-Process -FilePath $path | Out-Null
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Open conflicted file failed', 'OK', 'Error') | Out-Null }
}

function Open-SelectedConflictFolder {
    try {
        $path = Get-SelectedConflictFilePath
        if ([string]::IsNullOrWhiteSpace($path)) { [System.Windows.Forms.MessageBox]::Show('Select a conflicted file first.', 'No conflicted file selected', 'OK', 'Information') | Out-Null; return }
        $folder = Split-Path -Parent $path
        if (-not (Test-Path -LiteralPath $folder)) { $folder = $script:RepoRoot }
        Start-Process -FilePath explorer.exe -ArgumentList @($folder) | Out-Null
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Open conflict folder failed', 'OK', 'Error') | Out-Null }
}

function Get-GitPathForMarker {
    param([string]$Marker)
    try {
        if (-not (Test-GitRepository)) { return '' }
        $value = & git -C $script:RepoRoot rev-parse --git-path $Marker 2>$null | Select-Object -First 1
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace([string]$value)) { return [string]$value }
    } catch {}
    return ''
}

function Test-GitMarkerPath {
    param([string]$Marker)
    $path = Get-GitPathForMarker -Marker $Marker
    if ([string]::IsNullOrWhiteSpace($path)) { return $false }
    try { return (Test-Path -LiteralPath $path) } catch { return $false }
}

function Get-RecoveryOperationMarkers {
    $merge = Test-GitMarkerPath -Marker 'MERGE_HEAD'
    $cherry = Test-GitMarkerPath -Marker 'CHERRY_PICK_HEAD'
    $rebase = (Test-GitMarkerPath -Marker 'REBASE_HEAD') -or (Test-GitMarkerPath -Marker 'rebase-merge') -or (Test-GitMarkerPath -Marker 'rebase-apply')
    return [pscustomobject]@{
        MergeInProgress = [bool]$merge
        CherryPickInProgress = [bool]$cherry
        RebaseInProgress = [bool]$rebase
        AnyOperationInProgress = [bool]($merge -or $cherry -or $rebase)
    }
}

function Get-RecoveryStateSnapshot {
    try {
        if (-not (Test-GitRepository)) { return $null }
        $statusResult = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'status', '--porcelain=v1') -Caption 'git status --porcelain=v1' -AllowFailure -QuietOutput
        $unmergedResult = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'diff', '--name-only', '--diff-filter=U') -Caption 'git diff --name-only --diff-filter=U' -AllowFailure -QuietOutput
        $markers = Get-RecoveryOperationMarkers
        if (Get-Command ConvertFrom-GgrConflictState -ErrorAction SilentlyContinue) {
            return ConvertFrom-GgrConflictState -StatusPorcelain ([string]$statusResult.StdOut) -UnmergedText ([string]$unmergedResult.StdOut) -MergeInProgress:([bool]$markers.MergeInProgress) -CherryPickInProgress:([bool]$markers.CherryPickInProgress) -RebaseInProgress:([bool]$markers.RebaseInProgress)
        }
        $unresolved = @(([string]$unmergedResult.StdOut) -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        return [pscustomobject]@{ UnresolvedFiles=@($unresolved); ResolvedCandidateFiles=@(); UnresolvedCount=@($unresolved).Count; ResolvedCandidateCount=0; MergeInProgress=$markers.MergeInProgress; CherryPickInProgress=$markers.CherryPickInProgress; RebaseInProgress=$markers.RebaseInProgress; AnyOperationInProgress=$markers.AnyOperationInProgress; ContinueCommandKind='' }
    } catch {
        Append-Log -Text ('Failed to read recovery state: ' + $_.Exception.Message) -Color ([System.Drawing.Color]::Firebrick)
        return $null
    }
}

function Update-RecoveryStatePanel {
    param([AllowNull()][object]$State)
    try {
        if (-not $State) { $State = Get-RecoveryStateSnapshot }
        if (-not $State) { return }
        if ($script:ConflictStateLabel) {
            if (Get-Command Format-GgrConflictState -ErrorAction SilentlyContinue) { $script:ConflictStateLabel.Text = Format-GgrConflictState -State $State }
            else { $script:ConflictStateLabel.Text = ('Unresolved: {0}; staged/resolved candidates: {1}' -f [int]$State.UnresolvedCount, [int]$State.ResolvedCandidateCount) }
        }
        if ($script:RecoverySummaryLabel -and $State.AnyOperationInProgress) {
            $kind = if ($State.CherryPickInProgress) { 'cherry-pick' } elseif ($State.RebaseInProgress) { 'rebase' } elseif ($State.MergeInProgress) { 'merge' } else { 'recovery' }
            if ($State.UnresolvedCount -gt 0) { $script:RecoverySummaryLabel.Text = "In-progress ${kind}: resolve $($State.UnresolvedCount) unresolved file(s), stage them, then continue or abort." }
            else { $script:RecoverySummaryLabel.Text = "In-progress ${kind}: no unresolved files detected. Stage any resolved files, then continue or abort." }
        }
        if ($script:ContinueOperationButton) { $script:ContinueOperationButton.Enabled = [bool]$State.AnyOperationInProgress }
    } catch {}
}

function Stage-SelectedConflictFileAsResolved {
    try {
        if (-not (Test-GitRepository)) { [void](Ensure-RepositorySelected); return }
        $path = Get-SelectedConflictFilePath
        if ([string]::IsNullOrWhiteSpace($path)) { [System.Windows.Forms.MessageBox]::Show('Select a conflicted file first.', 'No conflicted file selected', 'OK', 'Information') | Out-Null; return }
        $relative = [string]$script:ConflictFilesListBox.SelectedItem
        $ok = Confirm-GuiAction -Title 'Stage resolved file' -Message ("This will run:`r`n`r`ngit add -- $relative`r`n`r`nOnly do this after you have resolved conflict markers and saved the file.") -Icon ([System.Windows.Forms.MessageBoxIcon]::Question)
        if (-not $ok) { return }
        $plan = if (Get-Command Get-GgrStageResolvedFileCommandPlan -ErrorAction SilentlyContinue) { Get-GgrStageResolvedFileCommandPlan -Path $relative } else { [pscustomobject]@{ Arguments=@('add','--',$relative); Display=('git add -- ' + (Quote-Arg $relative)) } }
        $result = Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($plan.Arguments)) -Caption ([string]$plan.Display) -AllowFailure -ShowProgress
        if ($result.ExitCode -ne 0) { Show-GitFailureGuidance -Result $result -Operation 'stage resolved conflict file' -ShowDialog; return }
        Refresh-Status
        Refresh-RecoveryStatus
        Set-CommandPreview -Title 'Stage resolved file' -Commands ([string]$plan.Display) -Notes 'The file is staged. If all conflicts are resolved, use Continue operation.'
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Stage resolved file failed', 'OK', 'Error') | Out-Null }
}

function Invoke-ContinueCurrentRecoveryOperation {
    try {
        if (-not (Test-GitRepository)) { [void](Ensure-RepositorySelected); return }
        $state = Get-RecoveryStateSnapshot
        if (-not $state -or -not $state.AnyOperationInProgress) { [System.Windows.Forms.MessageBox]::Show('No merge, cherry-pick, or rebase operation appears to be in progress.', 'Nothing to continue', 'OK', 'Information') | Out-Null; return }
        if ($state.UnresolvedCount -gt 0) { [System.Windows.Forms.MessageBox]::Show("There are still $($state.UnresolvedCount) unresolved conflict file(s). Resolve and stage them before continuing.", 'Unresolved conflicts remain', 'OK', 'Warning') | Out-Null; return }
        $kind = if ($state.CherryPickInProgress) { 'cherry-pick-continue' } elseif ($state.RebaseInProgress) { 'rebase-continue' } elseif ($state.MergeInProgress) { 'merge-continue' } else { 'status' }
        Invoke-RecoveryCommandPlan -Kind $kind
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Continue operation failed', 'OK', 'Error') | Out-Null }
}

function Save-ExternalMergeToolCommand {
    try {
        $value = if ($script:ExternalMergeToolTextBox) { $script:ExternalMergeToolTextBox.Text.Trim() } else { '' }
        if ([string]::IsNullOrWhiteSpace($value)) { $value = 'git mergetool' }
        Set-ConfigValue -Name 'ExternalMergeToolCommand' -Value $value
        Save-Config -Config $script:Config
        Append-Log -Text ('External merge tool command saved: ' + $value) -Color ([System.Drawing.Color]::DarkGreen)
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Save merge tool failed', 'OK', 'Error') | Out-Null }
}

function Build-ExternalMergeToolPreview {
    $value = if ($script:ExternalMergeToolTextBox) { $script:ExternalMergeToolTextBox.Text.Trim() } else { [string]$script:Config.ExternalMergeToolCommand }
    if ([string]::IsNullOrWhiteSpace($value)) { $value = 'git mergetool' }
    if (Get-Command Get-GgrExternalMergeToolCommandPlan -ErrorAction SilentlyContinue) {
        try { return (Get-GgrExternalMergeToolCommandPlan -ToolCommand $value).Display } catch {}
    }
    return $value
}

function Launch-ExternalMergeTool {
    try {
        if (-not (Test-GitRepository)) { [void](Ensure-RepositorySelected); return }
        Save-ExternalMergeToolCommand
        $command = [string]$script:Config.ExternalMergeToolCommand
        if ([string]::IsNullOrWhiteSpace($command)) { $command = 'git mergetool' }
        $ok = Confirm-GuiAction -Title 'Launch merge tool' -Message ("Launch the configured merge tool?`r`n`r`n$command`r`n`r`nThis may open an external application. Use it to resolve conflicted files, then return here to stage and continue.") -Icon ([System.Windows.Forms.MessageBoxIcon]::Question)
        if (-not $ok) { return }
        $plan = if (Get-Command Get-GgrExternalMergeToolCommandPlan -ErrorAction SilentlyContinue) { Get-GgrExternalMergeToolCommandPlan -ToolCommand $command } else { [pscustomobject]@{ FileName='git'; Arguments=@('mergetool'); Display='git mergetool' } }
        if ([string]$plan.FileName -eq 'git') {
            $result = Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($plan.Arguments)) -Caption ([string]$plan.Display) -AllowFailure -ShowProgress
            if ($result.ExitCode -ne 0) { Show-GitFailureGuidance -Result $result -Operation 'external merge tool' -ShowDialog }
            else { Refresh-RecoveryStatus }
        } else {
            Start-Process -FilePath ([string]$plan.FileName) -ArgumentList @($plan.Arguments) -WorkingDirectory $script:RepoRoot | Out-Null
        }
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Launch merge tool failed', 'OK', 'Error') | Out-Null }
}

function Refresh-RecoveryStatus {
    try {
        if (-not (Test-GitRepository)) { [void](Ensure-RepositorySelected); return }
        $result = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'status', '--short') -Caption 'git status --short' -AllowFailure -QuietOutput
        $stdout = if ($result.StdOut) { [string]$result.StdOut } else { '' }
        $stderr = if ($result.StdErr) { [string]$result.StdErr } else { '' }
        $guidance = if (Get-Command Get-GgrRecoveryGuidance -ErrorAction SilentlyContinue) { Get-GgrRecoveryGuidance -Operation 'status/recovery inspection' -ExitCode $result.ExitCode -StdOut $stdout -StdErr $stderr } else { $null }
        if ($guidance -and -not [string]::IsNullOrWhiteSpace($stdout)) {
            Set-RecoveryGuidancePanel -Guidance $guidance
        } else {
            Set-RecoveryGuidancePanel -FallbackText ("Current git status --short:`r`n" + $(if ([string]::IsNullOrWhiteSpace($stdout)) { '(working tree appears clean or no short status output)' } else { $stdout }))
        }
        Refresh-ConflictFiles
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Recovery status failed', 'OK', 'Error') | Out-Null
    }
}

function Invoke-RecoveryCommandPlan {
    param(
        [string]$Kind = 'status'
    )

    try {
        if (-not (Test-GitRepository)) { [void](Ensure-RepositorySelected); return }
        $plan = $null
        switch ($Kind) {
            'merge-abort' { if (Get-Command Get-GgrAbortMergeCommandPlan -ErrorAction SilentlyContinue) { $plan = Get-GgrAbortMergeCommandPlan } else { $plan = [pscustomobject]@{ Arguments=@('merge','--abort'); Display='git merge --abort' } } }
            'cherry-pick-abort' { if (Get-Command Get-GgcpCherryPickAbortCommandPlan -ErrorAction SilentlyContinue) { $plan = Get-GgcpCherryPickAbortCommandPlan } elseif (Get-Command Get-GgrAbortCherryPickCommandPlan -ErrorAction SilentlyContinue) { $plan = Get-GgrAbortCherryPickCommandPlan } else { $plan = [pscustomobject]@{ Arguments=@('cherry-pick','--abort'); Display='git cherry-pick --abort' } } }
            'cherry-pick-continue' { if (Get-Command Get-GgcpCherryPickContinueCommandPlan -ErrorAction SilentlyContinue) { $plan = Get-GgcpCherryPickContinueCommandPlan } elseif (Get-Command Get-GgrContinueCherryPickCommandPlan -ErrorAction SilentlyContinue) { $plan = Get-GgrContinueCherryPickCommandPlan } else { $plan = [pscustomobject]@{ Arguments=@('cherry-pick','--continue'); Display='git cherry-pick --continue' } } }
            'merge-continue' { if (Get-Command Get-GgrContinueMergeCommandPlan -ErrorAction SilentlyContinue) { $plan = Get-GgrContinueMergeCommandPlan } else { $plan = [pscustomobject]@{ Arguments=@('commit','--no-edit'); Display='git commit --no-edit' } } }
            'rebase-continue' { if (Get-Command Get-GgrContinueRebaseCommandPlan -ErrorAction SilentlyContinue) { $plan = Get-GgrContinueRebaseCommandPlan } else { $plan = [pscustomobject]@{ Arguments=@('rebase','--continue'); Display='git rebase --continue' } } }
            default { if (Get-Command Get-GgrConflictStatusCommandPlan -ErrorAction SilentlyContinue) { $plan = Get-GgrConflictStatusCommandPlan } else { $plan = [pscustomobject]@{ Arguments=@('status','--short'); Display='git status --short' } } }
        }
        if ($Kind -match 'abort') {
            $ok = Confirm-GuiAction -Title 'Confirm recovery command' -Message ("Run recovery command?`r`n`r`n" + [string]$plan.Display + "`r`n`r`nAbort commands usually return the repository to the state before the interrupted operation, but review the Output tab afterwards.") -Icon ([System.Windows.Forms.MessageBoxIcon]::Warning)
            if (-not $ok) { return }
        }
        $result = Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($plan.Arguments)) -Caption ([string]$plan.Display) -AllowFailure -ShowProgress
        if ($result.ExitCode -ne 0) { Show-GitFailureGuidance -Result $result -Operation ([string]$plan.Display) -ShowDialog }
        else { Refresh-Status; Refresh-RecoveryStatus }
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Recovery command failed', 'OK', 'Error') | Out-Null
    }
}

function Get-SelectedHistoryCommitish {
    if ($script:CherryPickCommitTextBox -and -not [string]::IsNullOrWhiteSpace($script:CherryPickCommitTextBox.Text)) { return $script:CherryPickCommitTextBox.Text.Trim() }
    if ($script:HistoryVisualListView -and $script:HistoryVisualListView.SelectedItems.Count -gt 0) {
        $tag = [string]$script:HistoryVisualListView.SelectedItems[0].Tag
        if (-not [string]::IsNullOrWhiteSpace($tag)) { return $tag }
    }
    if ($script:HistoryGraphTextBox -and -not [string]::IsNullOrWhiteSpace($script:HistoryGraphTextBox.SelectedText)) {
        $selected = $script:HistoryGraphTextBox.SelectedText.Trim()
        if (Get-Command Get-GgcpSelectedCommitFromHistoryLine -ErrorAction SilentlyContinue) {
            $hash = Get-GgcpSelectedCommitFromHistoryLine -Line $selected
            if (-not [string]::IsNullOrWhiteSpace($hash)) { return $hash }
        }
    }
    $line = Get-CurrentHistoryLine
    if (-not [string]::IsNullOrWhiteSpace($line)) {
        if (Get-Command Get-GgcpSelectedCommitFromHistoryLine -ErrorAction SilentlyContinue) {
            $hash = Get-GgcpSelectedCommitFromHistoryLine -Line $line
            if (-not [string]::IsNullOrWhiteSpace($hash)) { return $hash }
        }
    }
    return ''
}
function Get-CurrentHistoryLine {
    if (-not $script:HistoryGraphTextBox) { return '' }
    $idx = $script:HistoryGraphTextBox.SelectionStart
    try {
        $lineIndex = $script:HistoryGraphTextBox.GetLineFromCharIndex($idx)
        if ($lineIndex -ge 0 -and $lineIndex -lt @($script:HistoryGraphTextBox.Lines).Count) { return [string]$script:HistoryGraphTextBox.Lines[$lineIndex] }
    } catch {}
    return ''
}

function Set-CherryPickCommitFromHistorySelection {
    try {
        $commitish = Get-SelectedHistoryCommitish
        if ([string]::IsNullOrWhiteSpace($commitish)) { [System.Windows.Forms.MessageBox]::Show('Select or click a commit line in History / Graph first.', 'No commit selected', 'OK', 'Information') | Out-Null; return }
        if ($script:CherryPickCommitTextBox) { $script:CherryPickCommitTextBox.Text = $commitish }
        if ($script:ActionsTabs -and $script:RecoveryTabPage) { $script:ActionsTabs.SelectedTab = $script:RecoveryTabPage }
        Set-CommandPreview -Title 'Cherry-pick selected history commit' -Commands (Build-CherryPickPreview) -Notes 'Review the target branch and working tree before running cherry-pick.'
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'History selection failed', 'OK', 'Error') | Out-Null }
}

function Update-HistorySelectionPreview {
    try {
        $commitish = Get-SelectedHistoryCommitish
        if ([string]::IsNullOrWhiteSpace($commitish)) {
            Set-CommandPreview -Title 'History / Graph selection' -Commands (Build-HistoryPreview) -Notes 'Select a commit row to preview cherry-pick and show commands that can use the selected commit.'
            return
        }
        $noCommitSuffix = if ($script:CherryPickNoCommitCheckBox -and $script:CherryPickNoCommitCheckBox.Checked) { ' --no-commit' } else { '' }
        $commands = @(
            ('git show --stat ' + (Quote-Arg $commitish)),
            ('git cherry-pick' + $noCommitSuffix + ' ' + (Quote-Arg $commitish))
        ) -join "`r`n"
        Set-CommandPreview -Title ('Selected history commit: ' + $commitish) -Commands $commands -Notes 'Use Show/stat to inspect the commit. Use cherry-pick only when you deliberately want to copy this change onto the current branch.'
    } catch {}
}

function Show-SelectedHistoryCommitDetails {
    try {
        if (-not (Test-GitRepository)) { [void](Ensure-RepositorySelected); return }
        $commitish = Get-SelectedHistoryCommitish
        if ([string]::IsNullOrWhiteSpace($commitish)) { [System.Windows.Forms.MessageBox]::Show('Select a commit in History / Graph first.', 'No commit selected', 'OK', 'Information') | Out-Null; return }
        $result = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'show', '--stat', '--decorate', '--no-renames', $commitish) -Caption ('git show --stat --decorate ' + (Quote-Arg $commitish)) -AllowFailure -QuietOutput
        $text = if ($result.StdOut) { [string]$result.StdOut } else { [string]$result.StdErr }
        if ($script:HistoryGraphTextBox) { $script:HistoryGraphTextBox.Text = $text }
        if ($script:DiffTextBox) { $script:DiffTextBox.Text = $text }
        Set-CommandPreview -Title ('Show selected commit: ' + $commitish) -Commands ('git show --stat --decorate ' + (Quote-Arg $commitish)) -Notes 'Read-only inspection command.'
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Show selected commit failed', 'OK', 'Error') | Out-Null }
}

function Build-CherryPickPreview {
    $commitish = Get-SelectedHistoryCommitish
    if ([string]::IsNullOrWhiteSpace($commitish)) { $commitish = '<commit-hash-or-ref>' }
    try {
        $plan = Get-GgcpCherryPickCommandPlan -Commitish $commitish -NoCommit:($script:CherryPickNoCommitCheckBox -and $script:CherryPickNoCommitCheckBox.Checked)
        return $plan.Display
    } catch {
        return 'git cherry-pick ' + (Quote-Arg $commitish)
    }
}

function CherryPick-SelectedOrTypedCommit {
    try {
        if (-not (Test-GitRepository)) { [void](Ensure-RepositorySelected); return }
        if (-not (Test-CleanWorkingTree -Operation 'cherry-pick selected commit')) { return }
        $commitish = Get-SelectedHistoryCommitish
        if ([string]::IsNullOrWhiteSpace($commitish)) { [System.Windows.Forms.MessageBox]::Show('Enter a commit hash/ref or select/copy one from History / Graph first.', 'No commit selected', 'OK', 'Information') | Out-Null; return }
        $noCommit = ($script:CherryPickNoCommitCheckBox -and $script:CherryPickNoCommitCheckBox.Checked)
        if (Get-Command Test-GgcpCommitish -ErrorAction SilentlyContinue) {
            $validation = Test-GgcpCommitish -Commitish $commitish
            if (-not $validation.Valid) { [System.Windows.Forms.MessageBox]::Show($validation.Error, 'Invalid commit/ref', 'OK', 'Warning') | Out-Null; return }
        }
        $plan = if (Get-Command Get-GgcpCherryPickCommandPlan -ErrorAction SilentlyContinue) { Get-GgcpCherryPickCommandPlan -Commitish $commitish -NoCommit:$noCommit } else { [pscustomobject]@{ Arguments=@('cherry-pick', $commitish); Display=('git cherry-pick ' + (Quote-Arg $commitish)) } }
        $ok = Confirm-GuiAction -Title 'Cherry-pick commit' -Message ("Run cherry-pick?`r`n`r`n" + [string]$plan.Display + "`r`n`r`nCherry-pick applies one commit onto the current branch. It can create conflicts, so review the current branch and working tree first.") -Icon ([System.Windows.Forms.MessageBoxIcon]::Question)
        if (-not $ok) { return }
        $result = Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($plan.Arguments)) -Caption ([string]$plan.Display) -AllowFailure -ShowProgress
        if ($result.ExitCode -ne 0) { Show-GitFailureGuidance -Result $result -Operation 'cherry-pick' -ShowDialog; Refresh-Status; return }
        Set-SuggestedNextAction -Text 'Cherry-pick completed. Review the result and run tests before pushing.' -Action 'show-diff'
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Cherry-pick failed', 'OK', 'Error') | Out-Null
    }
}

function Build-CherryPickContinuePreview { if (Get-Command Get-GgcpCherryPickContinueCommandPlan -ErrorAction SilentlyContinue) { return (Get-GgcpCherryPickContinueCommandPlan).Display } return 'git cherry-pick --continue' }
function Build-CherryPickAbortPreview { if (Get-Command Get-GgcpCherryPickAbortCommandPlan -ErrorAction SilentlyContinue) { return (Get-GgcpCherryPickAbortCommandPlan).Display } return 'git cherry-pick --abort' }
function Build-RecoveryStatusPreview { if (Get-Command Get-GgrConflictStatusCommandPlan -ErrorAction SilentlyContinue) { return (Get-GgrConflictStatusCommandPlan).Display } return 'git status --short' }

#endregion
#region Push and Merge Operations

function Push-CurrentBranch {
    param([switch]$ConfirmBeforePush)
    try {
        if (-not $script:CurrentBranch) { Refresh-Status }

        if ($ConfirmBeforePush) {
            $msg = "This will run:`r`n`r`n$(Build-PushPreview)`r`n`r`nContinue?"
            $answer = [System.Windows.Forms.MessageBox]::Show($msg, 'Confirm push current branch', 'YesNo', 'Question')
            if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        }

        if ((Get-Command Get-GgbPushCurrentBranchCommandPlan -ErrorAction SilentlyContinue) -and -not ($script:Config.UseForceWithLease -and $script:CommitAmendCheckBox -and $script:CommitAmendCheckBox.Checked)) {
            foreach ($plan in @(Get-GgbPushCurrentBranchCommandPlan)) {
                $gitArgs = @('-C', $script:RepoRoot) + @($plan.Arguments)
                [void](Run-External -FileName 'git' -Arguments $gitArgs -Caption $plan.Display -AllowFailure -ShowProgress)
            }
        } else {
            $args = @('-C', $script:RepoRoot, 'push', '-u', 'origin', 'HEAD')
            $caption = 'git push -u origin HEAD'
            if ($script:Config.UseForceWithLease -and $script:CommitAmendCheckBox -and $script:CommitAmendCheckBox.Checked) {
                $args = @('-C', $script:RepoRoot, 'push', '--force-with-lease')
                $caption = 'git push --force-with-lease'
            }
            [void](Run-External -FileName 'git' -Arguments $args -Caption $caption -AllowFailure -ShowProgress)
        }
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Push failed', 'OK', 'Error') | Out-Null
    }
}

function Invoke-GitPlansWithRecovery {
    param(
        [Parameter(Mandatory=$true)][object[]]$Plans,
        [string]$Operation = 'Git operation'
    )

    foreach ($plan in @($Plans)) {
        $gitArgs = @('-C', $script:RepoRoot) + @($plan.Arguments)
        $result = Run-External -FileName 'git' -Arguments $gitArgs -Caption ([string]$plan.Display) -ShowProgress -AllowFailure
        if ($result.ExitCode -ne 0) { Show-GitFailureGuidance -Result $result -Operation $Operation -ShowDialog; Refresh-Status; return $false }
    }
    return $true
}

function Merge-CurrentFeatureIntoDevelop {
    try {
        if (-not $script:CurrentBranch) { Refresh-Status }
        $featureBranch = $script:CurrentBranch
        if ($featureBranch -eq $script:Config.BaseBranch -or $featureBranch -eq $script:Config.MainBranch) {
            [System.Windows.Forms.MessageBox]::Show('Switch to a feature branch first.', 'Invalid source branch', 'OK', 'Warning') | Out-Null
            return
        }
        if (-not (Test-CleanWorkingTree -Operation "merge '$featureBranch' into $($script:Config.BaseBranch)")) { return }
        $msg = "This will run:`r`n`r`n$(Build-MergeFeaturePreview)`r`n`r`nContinue?"
        $answer = [System.Windows.Forms.MessageBox]::Show($msg, 'Confirm merge: feature -> develop', 'YesNo', 'Question')
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        if (Get-Command Get-GgbMergeFeatureIntoBaseCommandPlan -ErrorAction SilentlyContinue) {
            $ok = Invoke-GitPlansWithRecovery -Plans @(Get-GgbMergeFeatureIntoBaseCommandPlan -FeatureBranch $featureBranch -BaseBranch $script:Config.BaseBranch) -Operation "merge '$featureBranch' into $($script:Config.BaseBranch)"
            if (-not $ok) { return }
        } else {
            $plans = @(
                [pscustomobject]@{ Arguments=@('switch', $script:Config.BaseBranch); Display="git switch $($script:Config.BaseBranch)" },
                [pscustomobject]@{ Arguments=@('pull','--ff-only'); Display='git pull --ff-only' },
                [pscustomobject]@{ Arguments=@('merge','--no-ff',$featureBranch); Display=('git merge --no-ff ' + (Quote-Arg $featureBranch)) },
                [pscustomobject]@{ Arguments=@('push','origin',$script:Config.BaseBranch); Display="git push origin $($script:Config.BaseBranch)" }
            )
            $ok = Invoke-GitPlansWithRecovery -Plans $plans -Operation "merge '$featureBranch' into $($script:Config.BaseBranch)"
            if (-not $ok) { return }
        }
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Merge to develop failed', 'OK', 'Error') | Out-Null
    }
}

function Merge-DevelopIntoMain {
    try {
        if (-not (Test-CleanWorkingTree -Operation "merge $($script:Config.BaseBranch) into $($script:Config.MainBranch)")) { return }
        $msg = "This will run:`r`n`r`n$(Build-MergeDevelopPreview)`r`n`r`nContinue?"
        $answer = [System.Windows.Forms.MessageBox]::Show($msg, 'Confirm merge: develop -> main', 'YesNo', 'Question')
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        if (Get-Command Get-GgbMergeBaseIntoMainCommandPlan -ErrorAction SilentlyContinue) {
            $ok = Invoke-GitPlansWithRecovery -Plans @(Get-GgbMergeBaseIntoMainCommandPlan -BaseBranch $script:Config.BaseBranch -MainBranch $script:Config.MainBranch) -Operation "merge $($script:Config.BaseBranch) into $($script:Config.MainBranch)"
            if (-not $ok) { return }
        } else {
            $plans = @(
                [pscustomobject]@{ Arguments=@('switch', $script:Config.MainBranch); Display="git switch $($script:Config.MainBranch)" },
                [pscustomobject]@{ Arguments=@('pull','--ff-only'); Display='git pull --ff-only' },
                [pscustomobject]@{ Arguments=@('merge','--no-ff',$script:Config.BaseBranch); Display="git merge --no-ff $($script:Config.BaseBranch)" },
                [pscustomobject]@{ Arguments=@('push','origin',$script:Config.MainBranch); Display="git push origin $($script:Config.MainBranch)" }
            )
            $ok = Invoke-GitPlansWithRecovery -Plans $plans -Operation "merge $($script:Config.BaseBranch) into $($script:Config.MainBranch)"
            if (-not $ok) { return }
        }
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Merge to main failed', 'OK', 'Error') | Out-Null
    }
}
#endregion
#region Stash Operations

function Show-StashFailureGuidance {
    param(
        [object]$Result,
        [string]$Operation = 'stash operation'
    )

    Show-GitFailureGuidance -Result $Result -Operation $Operation -ShowDialog
}

function Invoke-StashDirtyWorkSuggestedAction {
    try {
        if (-not (Test-GitRepository)) { [void](Ensure-RepositorySelected); return }
        $message = if ($script:StashMessageTextBox) { $script:StashMessageTextBox.Text.Trim() } else { '' }
        if ([string]::IsNullOrWhiteSpace($message)) {
            if (Get-Command Get-GgsDefaultStashMessage -ErrorAction SilentlyContinue) {
                $message = Get-GgsDefaultStashMessage -Prefix ([string]$script:Config.DefaultStashMessagePrefix)
            } else {
                $message = ('wip: {0:yyyy-MM-dd HH:mm}' -f (Get-Date))
            }
        }
        $answer = [System.Windows.Forms.MessageBox]::Show("Stash current unstaged and untracked work?`r`n`r`nMessage: $message`r`n`r`nThis is recoverable from the Stash tab, but it changes the working tree.", 'Confirm stash dirty work', 'YesNo', 'Question')
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        if ($script:StashMessageTextBox) { $script:StashMessageTextBox.Text = $message }
        Stash-ChangesPreset -IncludeUntracked
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Suggested stash failed', 'OK', 'Error') | Out-Null
    }
}


function Stash-Changes {
    try {
        $message = if ($script:StashMessageTextBox) { $script:StashMessageTextBox.Text.Trim() } else { '' }
        $includeUntracked = ($script:StashIncludeUntrackedCheckBox -and $script:StashIncludeUntrackedCheckBox.Checked)
        $keepIndex = ($script:StashKeepIndexCheckBox -and $script:StashKeepIndexCheckBox.Checked)
        if (Get-Command Get-GgsStashPushCommandPlan -ErrorAction SilentlyContinue) {
            $plan = Get-GgsStashPushCommandPlan -Message $message -IncludeUntracked:$includeUntracked -KeepIndex:$keepIndex
            $args = @('-C', $script:RepoRoot) + @($plan.Arguments)
            $caption = [string]$plan.Display
        } else {
            $args = @('-C', $script:RepoRoot, 'stash', 'push')
            if ($includeUntracked) { $args += '-u' }
            if ($keepIndex) { $args += '--keep-index' }
            if (-not [string]::IsNullOrWhiteSpace($message)) { $args += @('-m', $message) }
            $caption = Build-StashPushPreview
        }
        [void](Run-External -FileName 'git' -Arguments $args -Caption $caption)
        if ($script:StashMessageTextBox) { $script:StashMessageTextBox.Clear() }
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Stash failed', 'OK', 'Error') | Out-Null
    }
}

function Stash-ChangesPreset {
    param(
        [switch]$IncludeUntracked,
        [switch]$KeepIndex
    )
    try {
        $message = if ($script:StashMessageTextBox) { $script:StashMessageTextBox.Text.Trim() } else { '' }
        if (Get-Command Get-GgsStashPushCommandPlan -ErrorAction SilentlyContinue) {
            $plan = Get-GgsStashPushCommandPlan -Message $message -IncludeUntracked:$IncludeUntracked -KeepIndex:$KeepIndex
            $args = @('-C', $script:RepoRoot) + @($plan.Arguments)
            $caption = [string]$plan.Display
        } else {
            $args = @('-C', $script:RepoRoot, 'stash', 'push')
            if ($IncludeUntracked) { $args += '-u' }
            if ($KeepIndex) { $args += '--keep-index' }
            if (-not [string]::IsNullOrWhiteSpace($message)) { $args += @('-m', $message) }
            $caption = if ($IncludeUntracked) { Build-StashPushIncludeUntrackedPreview } elseif ($KeepIndex) { Build-StashPushKeepIndexPreview } else { Build-StashPushPreview }
        }
        [void](Run-External -FileName 'git' -Arguments $args -Caption $caption)
        if ($script:StashMessageTextBox) { $script:StashMessageTextBox.Clear() }
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Stash failed', 'OK', 'Error') | Out-Null
    }
}

function Pop-Stash {
    param([switch]$RestoreIndex)
    try {
        $stashRef = Get-SelectedStashRef -DefaultLatest
        if (-not $stashRef) {
            [System.Windows.Forms.MessageBox]::Show('No stash entries found.', 'No stashes', 'OK', 'Information') | Out-Null
            return
        }
        if (Get-Command Get-GgsStashPopCommandPlan -ErrorAction SilentlyContinue) {
            $plan = Get-GgsStashPopCommandPlan -StashRef $stashRef -RestoreIndex:$RestoreIndex
            $args = @('-C', $script:RepoRoot) + @($plan.Arguments)
            $caption = [string]$plan.Display
        } else {
            $args = @('-C', $script:RepoRoot, 'stash', 'pop')
            if ($RestoreIndex) { $args += '--index' }
            $args += $stashRef
            $caption = Build-StashPopPreview -RestoreIndex:$RestoreIndex
        }
        $result = Run-External -FileName 'git' -Arguments $args -Caption $caption -AllowFailure
        if ($result.ExitCode -ne 0) { Show-StashFailureGuidance -Result $result -Operation 'stash pop'; Refresh-Status; return }
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Stash pop failed', 'OK', 'Error') | Out-Null
    }
}

function Apply-Stash {
    param([switch]$RestoreIndex)
    try {
        $stashRef = Get-SelectedStashRef
        if (-not $stashRef) {
            [System.Windows.Forms.MessageBox]::Show('Select a stash entry first.', 'No stash selected', 'OK', 'Information') | Out-Null
            return
        }
        if (Get-Command Get-GgsStashApplyCommandPlan -ErrorAction SilentlyContinue) {
            $plan = Get-GgsStashApplyCommandPlan -StashRef $stashRef -RestoreIndex:$RestoreIndex
            $args = @('-C', $script:RepoRoot) + @($plan.Arguments)
            $caption = [string]$plan.Display
        } else {
            $args = @('-C', $script:RepoRoot, 'stash', 'apply')
            if ($RestoreIndex) { $args += '--index' }
            $args += $stashRef
            $caption = Build-StashApplyPreview -RestoreIndex:$RestoreIndex
        }
        $result = Run-External -FileName 'git' -Arguments $args -Caption $caption -AllowFailure
        if ($result.ExitCode -ne 0) { Show-StashFailureGuidance -Result $result -Operation 'stash apply'; Refresh-Status; return }
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Stash apply failed', 'OK', 'Error') | Out-Null
    }
}

function Drop-Stash {

    try {
        $stashRef = Get-SelectedStashRef
        if (-not $stashRef) {
            [System.Windows.Forms.MessageBox]::Show('Select a stash entry first.', 'No stash selected', 'OK', 'Information') | Out-Null
            return
        }
        
        $answer = [System.Windows.Forms.MessageBox]::Show("Drop ${stashRef}?`r`n`r`nThis cannot be undone.", 'Confirm drop', 'YesNo', 'Warning')
        
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        
        if (Get-Command Get-GgsStashDropCommandPlan -ErrorAction SilentlyContinue) { $plan = Get-GgsStashDropCommandPlan -StashRef $stashRef; $dropArgs = @('-C', $script:RepoRoot) + @($plan.Arguments); $dropCaption = [string]$plan.Display } else { $dropArgs = @('-C', $script:RepoRoot, 'stash', 'drop', $stashRef); $dropCaption = "git stash drop $stashRef" }; [void](Run-External -FileName 'git' -Arguments $dropArgs -Caption $dropCaption)
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Stash drop failed', 'OK', 'Error') | Out-Null
    }
}

function Get-SelectedStashRef {
    param([switch]$DefaultLatest)

    if ($script:StashListBox -and $script:StashListBox.SelectedIndex -ge 0) {
        $selected = [string]$script:StashListBox.SelectedItem
        if ($selected -match 'stash@\{\d+\}') { return $matches[0] }
        return ('stash@{' + [string]$script:StashListBox.SelectedIndex + '}')
    }
    if ($DefaultLatest -and @($script:StashList).Count -gt 0) { return 'stash@{0}' }
    return $null
}

function Refresh-StashPanel {
    Load-StashList
    $count = @($script:StashList).Count
    if ($script:DiffTextBox) {
        $script:DiffTextBox.Text = "Stash list refreshed.`r`n`r`n$count stash entr$(if ($count -eq 1) { 'y' } else { 'ies' }) found."
    }
    Set-StatusBar("Ready. Stashes: $count")
}

function Show-SelectedStashDiff {
    try {
        $stashRef = Get-SelectedStashRef -DefaultLatest
        if (-not $stashRef) {
            $script:DiffTextBox.Text = '(No stash entries found.)'
            return
        }
        $result = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'stash', 'show', '--stat', '--patch', $stashRef) -Caption "git stash show --stat --patch $stashRef" -AllowFailure -QuietOutput
        $script:DiffTextBox.Text = if ([string]::IsNullOrWhiteSpace($result.StdOut)) { "(No stash diff output for $stashRef.)" } else { $result.StdOut }
        Set-CommandPreview -Title 'Show selected stash diff' -Commands (Build-StashShowPreview) -Notes 'Displays the selected stash patch without applying it.'
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Show stash diff failed', 'OK', 'Error') | Out-Null
    }
}


function Show-SelectedStashNameStatus {
    try {
        $stashRef = Get-SelectedStashRef -DefaultLatest
        if (-not $stashRef) {
            $script:DiffTextBox.Text = '(No stash entries found.)'
            return
        }
        $result = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'stash', 'show', '--name-status', $stashRef) -Caption "git stash show --name-status $stashRef" -AllowFailure -QuietOutput
        $script:DiffTextBox.Text = if ([string]::IsNullOrWhiteSpace($result.StdOut)) { "(No changed-file list for $stashRef.)" } else { $result.StdOut }
        Set-CommandPreview -Title 'Show files in selected stash' -Commands (Build-StashNameStatusPreview) -Notes 'Lists files captured in the selected stash without applying it.'
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Show stash files failed', 'OK', 'Error') | Out-Null
    }
}

function Create-BranchFromStash {
    try {
        $stashRef = Get-SelectedStashRef -DefaultLatest
        if (-not $stashRef) {
            [System.Windows.Forms.MessageBox]::Show('Select a stash entry first.', 'No stash selected', 'OK', 'Information') | Out-Null
            return
        }
        $branchName = if ($script:StashBranchTextBox) { $script:StashBranchTextBox.Text.Trim() } else { '' }
        if ([string]::IsNullOrWhiteSpace($branchName)) {
            [System.Windows.Forms.MessageBox]::Show('Enter a branch name for the stash branch first.', 'Missing branch name', 'OK', 'Warning') | Out-Null
            return
        }
        $validation = Validate-BranchName $branchName
        if (-not $validation.Valid) {
            [System.Windows.Forms.MessageBox]::Show($validation.Error, 'Invalid branch name', 'OK', 'Warning') | Out-Null
            return
        }
        if (Test-BranchExists $branchName) {
            [System.Windows.Forms.MessageBox]::Show("Branch '$branchName' already exists.", 'Branch exists', 'OK', 'Warning') | Out-Null
            return
        }
        [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'stash', 'branch', $branchName, $stashRef) -Caption "git stash branch $branchName $stashRef" -ShowProgress)
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Create branch from stash failed', 'OK', 'Error') | Out-Null
    }
}

function Clear-AllStashes {
    try {
        if (@($script:StashList).Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show('No stashes to clear.', 'No stashes', 'OK', 'Information') | Out-Null
            return
        }
        $answer = [System.Windows.Forms.MessageBox]::Show("Clear all stash entries?`r`n`r`nThis cannot be undone.", 'Confirm clear all stashes', 'YesNo', 'Warning')
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'stash', 'clear') -Caption 'git stash clear')
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Clear stashes failed', 'OK', 'Error') | Out-Null
    }
}

function Run-CustomGitCommand {
    param([string]$CommandText)

    try {
        $args = Convert-GitCommandTextToArgs -CommandText $CommandText
        if (@($args).Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show('Enter a git command, for example: status -sb', 'Missing command', 'OK', 'Information') | Out-Null
            return
        }
        if (Test-GitArgsPotentiallyDestructive -Arguments $args) {
            $ok = Confirm-GuiAction -Title 'Confirm potentially destructive custom Git command' -Message ("This custom command may change, remove, or rewrite repository state:`r`n`r`n{0}`r`n`r`nContinue?" -f (Format-GitCommandArgs -Arguments $args))
            if (-not $ok) {
                Append-Log -Text 'Custom Git command cancelled by user.' -Color ([System.Drawing.Color]::DarkOrange)
                return
            }
        }

        $result = Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($args)) -Caption (Format-GitCommandArgs -Arguments $args) -AllowFailure -ShowProgress
        $text = @()
        if (-not [string]::IsNullOrWhiteSpace($result.StdOut)) { $text += $result.StdOut.TrimEnd() }
        if (-not [string]::IsNullOrWhiteSpace($result.StdErr)) { $text += ''; $text += 'stderr:'; $text += $result.StdErr.TrimEnd() }
        if ($text.Count -eq 0) { $text += '(Command completed without output.)' }
        $script:DiffTextBox.Text = ($text -join "`r`n")
        Set-CommandPreview -Title 'Custom git command' -Commands (Format-GitCommandArgs -Arguments $args) -Notes 'Custom commands run as git arguments in the current repository, without shell operators.'
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Custom git command failed', 'OK', 'Error') | Out-Null
    }
}

function Add-CustomGitButtonFromFields {
    try {
        $label = if ($script:CustomGitLabelTextBox) { $script:CustomGitLabelTextBox.Text.Trim() } else { '' }
        $arguments = if ($script:CustomGitCommandTextBox) { $script:CustomGitCommandTextBox.Text.Trim() } else { '' }
        if ([string]::IsNullOrWhiteSpace($label)) {
            [System.Windows.Forms.MessageBox]::Show('Enter a button label first.', 'Missing label', 'OK', 'Information') | Out-Null
            return
        }
        [void](Convert-GitCommandTextToArgs -CommandText $arguments)
        $defs = @($script:CustomGitButtons)
        $defs += @{ Label = $label; Arguments = $arguments }
        Save-CustomGitButtonDefinitions -Definitions $defs
        Refresh-CustomGitButtonsPanel
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Add custom button failed', 'OK', 'Error') | Out-Null
    }
}


function Update-SelectedCustomGitButtonFromFields {
    try {
        if (-not $script:CustomGitButtonsListBox -or $script:CustomGitButtonsListBox.SelectedIndex -lt 0) {
            [System.Windows.Forms.MessageBox]::Show('Select a saved custom button first, then edit the label or arguments.', 'No button selected', 'OK', 'Information') | Out-Null
            return
        }
        $label = if ($script:CustomGitLabelTextBox) { $script:CustomGitLabelTextBox.Text.Trim() } else { '' }
        $arguments = if ($script:CustomGitCommandTextBox) { $script:CustomGitCommandTextBox.Text.Trim() } else { '' }
        if ([string]::IsNullOrWhiteSpace($label)) {
            [System.Windows.Forms.MessageBox]::Show('Enter a button label first.', 'Missing label', 'OK', 'Information') | Out-Null
            return
        }
        [void](Convert-GitCommandTextToArgs -CommandText $arguments)

        $idx = [int]$script:CustomGitButtonsListBox.SelectedIndex
        $defs = @($script:CustomGitButtons)
        if ($idx -lt 0 -or $idx -ge $defs.Count) { return }
        $defs[$idx] = @{ Label = $label; Arguments = $arguments }
        Save-CustomGitButtonDefinitions -Definitions $defs
        Refresh-CustomGitButtonsPanel
        if ($script:CustomGitButtonsListBox.Items.Count -gt $idx) { $script:CustomGitButtonsListBox.SelectedIndex = $idx }
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Update custom button failed', 'OK', 'Error') | Out-Null
    }
}

function Remove-SelectedCustomGitButton {
    if (-not $script:CustomGitButtonsListBox -or $script:CustomGitButtonsListBox.SelectedIndex -lt 0) {
        [System.Windows.Forms.MessageBox]::Show('Select a saved custom button first.', 'No button selected', 'OK', 'Information') | Out-Null
        return
    }
    $idx = [int]$script:CustomGitButtonsListBox.SelectedIndex
    $defs = @($script:CustomGitButtons)
    if ($idx -lt 0 -or $idx -ge $defs.Count) { return }
    $remaining = @()
    for ($i = 0; $i -lt $defs.Count; $i++) {
        if ($i -ne $idx) { $remaining += $defs[$i] }
    }
    Save-CustomGitButtonDefinitions -Definitions $remaining
    Refresh-CustomGitButtonsPanel
}


function New-CustomGitButtonDraft {
    if ($script:CustomGitLabelTextBox) { $script:CustomGitLabelTextBox.Text = 'My git command' }
    if ($script:CustomGitCommandTextBox) { $script:CustomGitCommandTextBox.Text = 'status -sb' }
    if ($script:CustomGitButtonsListBox) { try { $script:CustomGitButtonsListBox.ClearSelected() } catch {} }
    Set-CommandPreview -Title 'New custom Git button draft' -Commands 'git status -sb' -Notes 'Edit the label and Git arguments, then click Save as new button.'
}

function Add-RecommendedCustomGitButtons {
    $recommended = @(
        @{ Label = 'Short status'; Arguments = 'status -sb' },
        @{ Label = 'Changed file summary'; Arguments = 'diff --stat' },
        @{ Label = 'Staged summary'; Arguments = 'diff --cached --stat' },
        @{ Label = 'Recent commits'; Arguments = 'log --oneline --decorate -n 20' },
        @{ Label = 'Branch graph'; Arguments = 'log --graph --decorate --oneline --all -n 30' },
        @{ Label = 'List stashes'; Arguments = 'stash list --date=local' }
    )

    $defs = @($script:CustomGitButtons)
    foreach ($entry in $recommended) {
        $exists = $false
        foreach ($def in $defs) {
            if ([string]$def.Label -eq [string]$entry.Label -or [string]$def.Arguments -eq [string]$entry.Arguments) { $exists = $true; break }
        }
        if (-not $exists) { $defs += $entry }
    }
    Save-CustomGitButtonDefinitions -Definitions $defs
    Refresh-CustomGitButtonsPanel
    Set-StatusBar('Recommended custom Git buttons added or already present.')
}

function Refresh-CustomGitButtonsPanel {
    if (-not $script:CustomGitButtonsPanel) { return }

    $script:CustomGitButtonsPanel.Controls.Clear()
    if ($script:CustomGitButtonsListBox) {
        $script:CustomGitButtonsListBox.BeginUpdate()
        $script:CustomGitButtonsListBox.Items.Clear()
    }

    $script:CustomGitButtons = Get-CustomGitButtonDefinitions
    foreach ($def in @($script:CustomGitButtons)) {
        $label = [string]$def.Label
        $command = [string]$def.Arguments

        if ($script:CustomGitButtonsListBox) {
            [void]$script:CustomGitButtonsListBox.Items.Add(('{0}  ->  git {1}' -f $label, $command))
        }

        $btn = New-Object System.Windows.Forms.Button
        $btn.Text = $label
        $btn.Width = 145
        $btn.Height = 34
        $btn.Margin = New-Object System.Windows.Forms.Padding(4)
        $localCommand = $command
        $localLabel = $label
        $btn.Add_Click({ Run-CustomGitCommand -CommandText $localCommand }.GetNewClosure())
        Set-ControlPreview -Control $btn -Builder { 'git ' + $localCommand }.GetNewClosure() -Title ("Custom: $localLabel") -Notes 'Runs this saved custom git command in the current repository. Commands are passed to git directly, not through a shell.'
        $script:CustomGitButtonsPanel.Controls.Add($btn)
    }

    if ($script:CustomGitButtonsListBox) { $script:CustomGitButtonsListBox.EndUpdate() }
}

#endregion


#region Release Tag and Safety Functions

function Validate-TagName {
    param([string]$Name)
    try {
        $cmd = Get-Command Test-GgtTagName -ErrorAction SilentlyContinue
        if ($cmd) { return (Test-GgtTagName -Name $Name) }
        $legacyCmd = Get-Command Test-GfgGitRefName -ErrorAction SilentlyContinue
        if ($legacyCmd) { return (Test-GfgGitRefName -Name $Name -Kind 'Tag') }
    } catch { throw }
    if ([string]::IsNullOrWhiteSpace($Name)) { return @{ Valid = $false; Error = 'Tag name cannot be empty.' } }
    if ($Name -match '\s') { return @{ Valid = $false; Error = 'Tag name cannot contain spaces.' } }
    if ($Name -match '[~^:?*\[\]\\]') { return @{ Valid = $false; Error = 'Tag name contains invalid Git reference characters.' } }
    if ($Name -match '\.\.|^\.|\.$|/$|//|\.lock$|^-' ) { return @{ Valid = $false; Error = 'Tag name format is invalid for a Git reference.' } }
    return @{ Valid = $true; Error = '' }
}

function Build-UndoLastCommitPreview {
    if (Get-Command Get-GgcSoftUndoLastCommitCommandPlan -ErrorAction SilentlyContinue) { return (ConvertTo-GgcCommandPreview -Plans (Get-GgcSoftUndoLastCommitCommandPlan)) }
    return "git log -1 --oneline`r`ngit reset --soft HEAD~1"
}

function Undo-LastCommitSoft {
    try {
        $last = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'log', '-1', '--oneline') -Caption 'git log -1 --oneline' -AllowFailure -QuietOutput
        if ($last.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($last.StdOut)) {
            [System.Windows.Forms.MessageBox]::Show('No commit was found to undo in this repository.', 'Undo last commit', 'OK', 'Information') | Out-Null
            return
        }
        $parent = Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'rev-parse', '--verify', 'HEAD~1') -Caption 'git rev-parse --verify HEAD~1' -AllowFailure -QuietOutput
        if ($parent.ExitCode -ne 0) {
            [System.Windows.Forms.MessageBox]::Show('The current commit has no parent. Soft undo is not available for the first commit.', 'Undo last commit', 'OK', 'Warning') | Out-Null
            return
        }
        $ok = Confirm-GuiAction -Title 'Undo last commit, keep changes staged' -Message ("This will run:`r`n`r`ngit reset --soft HEAD~1`r`n`r`nLast commit:`r`n{0}`r`n`r`nThe commit object is removed from the current branch tip, but its file changes stay staged so you can edit and recommit. Continue?" -f $last.StdOut.Trim())
        if (-not $ok) { return }
        [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'reset', '--soft', 'HEAD~1') -Caption 'git reset --soft HEAD~1' -ShowProgress)
        Append-Log -Text 'Last commit was undone with --soft; changes remain staged.' -Color ([System.Drawing.Color]::DarkGreen)
        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Undo last commit failed', 'OK', 'Error') | Out-Null
    }
}

function Get-SelectedTagName {
    if (-not $script:TagListBox -or $script:TagListBox.SelectedIndex -lt 0) { return '' }
    $item = [string]$script:TagListBox.SelectedItem
    try {
        $cmd = Get-Command Get-GgtSelectedTagNameFromDisplayLine -ErrorAction SilentlyContinue
        if ($cmd) { return (Get-GgtSelectedTagNameFromDisplayLine -DisplayLine $item) }
    } catch {}
    if ([string]::IsNullOrWhiteSpace($item) -or $item.StartsWith('(')) { return '' }
    return (($item -split '\s+', 2)[0]).Trim()
}

function Build-SelectedTagPreview {
    param([string]$Action)
    $tag = Get-SelectedTagName
    if ([string]::IsNullOrWhiteSpace($tag)) { $tag = '<selected-tag>' }
    try {
        switch ($Action) {
            'Details' { $plan = Get-GgtShowTagDetailsCommandPlan -TagName $tag; return $plan.Display }
            'Push' { $plan = Get-GgtPushTagCommandPlan -TagName $tag; return $plan.Display }
            'Delete' { $plan = Get-GgtDeleteLocalTagCommandPlan -TagName $tag; return $plan.Display }
            'Checkout' { $plan = Get-GgtCheckoutTagCommandPlan -TagName $tag; return $plan.Display }
            default { $plan = Get-GgtTagListCommandPlan; return $plan.Display }
        }
    } catch {
        switch ($Action) {
            'Details' { return 'git show --no-patch --decorate --format=fuller ' + (Quote-Arg $tag) }
            'Push' { return 'git push origin ' + (Quote-Arg $tag) }
            'Delete' { return 'git tag -d ' + (Quote-Arg $tag) }
            'Checkout' { return 'git checkout ' + (Quote-Arg $tag) }
            default { return 'git tag --list --sort=-creatordate' }
        }
    }
}

function Load-TagList {
    if (-not $script:TagListBox) { return }
    $script:TagListBox.BeginUpdate()
    try {
        $script:TagListBox.Items.Clear()
        if (-not (Test-GitRepository)) { [void]$script:TagListBox.Items.Add('(Open a Git repository first)'); return }
        $tagListPlan = Get-GgtTagListCommandPlan
        $result = Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($tagListPlan.Arguments)) -Caption $tagListPlan.Display -AllowFailure -QuietOutput
        if ($result.ExitCode -ne 0) { [void]$script:TagListBox.Items.Add('(Could not load tags)'); return }
        $lines = @($result.StdOut -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($lines.Count -eq 0) { [void]$script:TagListBox.Items.Add('(No tags found)'); return }
        foreach ($line in $lines) { [void]$script:TagListBox.Items.Add($line.Trim()) }
    } finally { $script:TagListBox.EndUpdate() }
}

function Show-SelectedTagDetails {
    $tag = Get-SelectedTagName
    if ([string]::IsNullOrWhiteSpace($tag)) {
        if ($script:TagDetailsTextBox) { $script:TagDetailsTextBox.Text = 'Select a tag first.' }
        return
    }
    $detailsPlan = Get-GgtShowTagDetailsCommandPlan -TagName $tag
    $result = Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($detailsPlan.Arguments)) -Caption $detailsPlan.Display -AllowFailure -QuietOutput
    if ($script:TagDetailsTextBox) {
        $lines = @()
        if (-not [string]::IsNullOrWhiteSpace($result.StdOut)) { $lines += $result.StdOut.TrimEnd() }
        if (-not [string]::IsNullOrWhiteSpace($result.StdErr)) { $lines += ''; $lines += 'stderr:'; $lines += $result.StdErr.TrimEnd() }
        if ($lines.Count -eq 0) { $lines += '(No details returned.)' }
        $script:TagDetailsTextBox.Text = ($lines -join "`r`n")
    }
}

function Create-GitFlowTag {
    try {
        $tag = if ($script:TagNameTextBox) { $script:TagNameTextBox.Text.Trim() } else { '' }
        $message = if ($script:TagMessageTextBox) { $script:TagMessageTextBox.Text.Trim() } else { '' }
        $annotated = if ($script:TagAnnotatedCheckBox) { [bool]$script:TagAnnotatedCheckBox.Checked } else { $true }
        $pushAfter = if ($script:TagPushAfterCreateCheckBox) { [bool]$script:TagPushAfterCreateCheckBox.Checked } else { $false }
        $validation = Validate-TagName -Name $tag
        if (-not $validation.Valid) { [System.Windows.Forms.MessageBox]::Show($validation.Error, 'Invalid tag name', 'OK', 'Warning') | Out-Null; return }
        $existsPlan = Get-GgtVerifyTagDoesNotExistCommandPlan -TagName $tag
        $exists = Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($existsPlan.Arguments)) -Caption $existsPlan.Display -AllowFailure -QuietOutput
        if ($exists.ExitCode -eq 0) { [System.Windows.Forms.MessageBox]::Show("Tag '$tag' already exists. Delete it deliberately before recreating it.", 'Tag already exists', 'OK', 'Warning') | Out-Null; return }
        $createPlan = Get-GgtCreateTagCommandPlan -TagName $tag -Message $message -Annotated:([bool]$annotated)
        [void](Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($createPlan.Arguments)) -Caption $createPlan.Display -ShowProgress)
        if ($pushAfter) { Push-SelectedOrNamedTag -TagName $tag }
        Load-TagList
        if ($script:TagNameTextBox) { $script:TagNameTextBox.Clear() }
        if ($script:TagMessageTextBox) { $script:TagMessageTextBox.Clear() }
        Append-Log -Text ("Created tag '$tag'.") -Color ([System.Drawing.Color]::DarkGreen)
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Create tag failed', 'OK', 'Error') | Out-Null }
}

function Push-SelectedOrNamedTag {
    param([string]$TagName = '')
    $tag = if ([string]::IsNullOrWhiteSpace($TagName)) { Get-SelectedTagName } else { $TagName }
    if ([string]::IsNullOrWhiteSpace($tag)) { [System.Windows.Forms.MessageBox]::Show('Select a tag first, or create one with Push after create enabled.', 'No tag selected', 'OK', 'Information') | Out-Null; return }
    $ok = Confirm-GuiAction -Title 'Push tag to origin' -Message ("Push tag '$tag' to origin?`r`n`r`nTags are shared release markers. Only push tags that are intentional and ready for teammates or automation.") -Icon ([System.Windows.Forms.MessageBoxIcon]::Question)
    if (-not $ok) { return }
    $pushPlan = Get-GgtPushTagCommandPlan -TagName $tag
    [void](Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($pushPlan.Arguments)) -Caption $pushPlan.Display -ShowProgress)
    Append-Log -Text ("Pushed tag '$tag' to origin.") -Color ([System.Drawing.Color]::DarkGreen)
}

function Push-AllTags {
    $ok = Confirm-GuiAction -Title 'Push all tags to origin' -Message "This will run:`r`n`r`ngit push origin --tags`r`n`r`nUse this only when all local tags are intentional release markers. Continue?" -Icon ([System.Windows.Forms.MessageBoxIcon]::Warning)
    if (-not $ok) { return }
    $pushAllPlan = Get-GgtPushAllTagsCommandPlan
    [void](Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($pushAllPlan.Arguments)) -Caption $pushAllPlan.Display -ShowProgress)
}

function Delete-SelectedTag {
    $tag = Get-SelectedTagName
    if ([string]::IsNullOrWhiteSpace($tag)) { [System.Windows.Forms.MessageBox]::Show('Select a tag to delete.', 'No tag selected', 'OK', 'Information') | Out-Null; return }
    $deleteRemote = if ($script:TagDeleteRemoteCheckBox) { [bool]$script:TagDeleteRemoteCheckBox.Checked } else { $false }
    $guidance = Get-GgtTagDeleteSafetyGuidance -TagName $tag -DeleteRemote:([bool]$deleteRemote)
    $ok = Confirm-GuiAction -Title 'Delete selected tag' -Message ($guidance.Message + "`r`n`r`n" + $guidance.Details + "`r`n`r`nCommands:`r`n" + $guidance.Preview + "`r`n`r`nContinue?")
    if (-not $ok) { return }
    foreach ($plan in @($guidance.Plans)) {
        [void](Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($plan.Arguments)) -Caption $plan.Display -ShowProgress -AllowFailure:($plan.Verb -eq 'delete-remote-tag'))
    }
    Load-TagList
    if ($script:TagDetailsTextBox) { $script:TagDetailsTextBox.Clear() }
}

function Checkout-SelectedTag {
    $tag = Get-SelectedTagName
    if ([string]::IsNullOrWhiteSpace($tag)) { [System.Windows.Forms.MessageBox]::Show('Select a tag first.', 'No tag selected', 'OK', 'Information') | Out-Null; return }
    if (-not (Test-CleanWorkingTree)) { return }
    $branch = if ($script:TagBranchTextBox) { $script:TagBranchTextBox.Text.Trim() } else { '' }
    if (-not [string]::IsNullOrWhiteSpace($branch)) {
        $validation = Validate-BranchName $branch
        if (-not $validation.Valid) { [System.Windows.Forms.MessageBox]::Show($validation.Error, 'Invalid branch name', 'OK', 'Warning') | Out-Null; return }
        $branchPlan = Get-GgtBranchFromTagCommandPlan -BranchName $branch -TagName $tag
        [void](Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($branchPlan.Arguments)) -Caption $branchPlan.Display -ShowProgress)
    } else {
        $ok = Confirm-GuiAction -Title 'Checkout tag in detached HEAD' -Message ("Checking out tag '$tag' without a branch puts Git into detached HEAD state.`r`n`r`nFor experiments or fixes, enter a branch name first. Continue with detached checkout?")
        if (-not $ok) { return }
        $checkoutPlan = Get-GgtCheckoutTagCommandPlan -TagName $tag
        [void](Run-External -FileName 'git' -Arguments (@('-C', $script:RepoRoot) + @($checkoutPlan.Arguments)) -Caption $checkoutPlan.Display -ShowProgress)
    }
    Refresh-Status
}

#endregion

#region Commit Template Functions

function Get-CommitTemplateValues {
    $choice = if ($script:CommitTemplateComboBox) { 
        $script:CommitTemplateComboBox.Text 
    } else { 'Custom' }
    
    $branch = Get-CurrentBranchNameOrPlaceholder
    
    switch ($choice) {
        'Feature' {
            return @{
                Subject = 'feat: summarize feature work'
                Body = "- implement the planned feature changes`r`n- keep existing behavior stable`r`n- add or update tests where needed"
            }
        }
        'Hotfix' {
            return @{
                Subject = 'fix: resolve targeted regression'
                Body = "- fix the identified regression`r`n- keep the existing workflow intact`r`n- update coverage for the failing path"
            }
        }
        'Release' {
            return @{
                Subject = 'release: prepare next version'
                Body = "- finalize implementation for the release`r`n- update docs and versioning`r`n- confirm build and test validation"
            }
        }
        'Refactor' {
            return @{
                Subject = 'refactor: simplify workflow and improve maintainability'
                Body = "- extract focused helpers/modules`r`n- preserve current behavior and contracts`r`n- add or update tests for refactored paths"
            }
        }
        'Docs' {
            return @{
                Subject = 'docs: update workflow guidance'
                Body = "- update help and examples`r`n- clarify recommended Git flow usage`r`n- align examples with current branch/release naming"
            }
        }
        'Test' {
            return @{
                Subject = 'test: strengthen coverage for current workflow'
                Body = "- add or update regression coverage`r`n- verify expected command flow`r`n- keep behavior unchanged"
            }
        }
        default {
            return @{
                Subject = ('chore: update ' + $branch)
                Body = "- summarize the change in one line`r`n- add technical details if useful`r`n- mention tests or validation"
            }
        }
    }
}

function Insert-CommitTemplate {
    $template = Get-CommitTemplateValues
    $script:CommitSubjectTextBox.Text = $template.Subject
    $script:CommitBodyTextBox.Text = $template.Body
    Update-CommitPreview
}

#endregion

#region Commit Operations

function Commit-Changes {
    param([switch]$PushAfterOverride)

    $plan = Get-CommitPlan
    $subject = $plan.Subject
    $stageAll = $plan.StageAll
    $amend = $plan.Amend
    $pushAfter = $PushAfterOverride.IsPresent -or $plan.PushAfter

    # Validate commit subject
    $validation = Validate-CommitSubject $subject
    if (-not $validation.Valid) {
        [System.Windows.Forms.MessageBox]::Show($validation.Error, 'Invalid commit message', 'OK', 'Warning') | Out-Null
        return
    }
    
    if ($validation.Warning) {
        $answer = [System.Windows.Forms.MessageBox]::Show($validation.Warning + "`r`n`r`nContinue anyway?", 'Commit message warning', 'YesNo', 'Warning')
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    }

    $tempFile = [System.IO.Path]::GetTempFileName()
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    try {
        if ($stageAll) {
            [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'add', '-A') -Caption 'git add -A')
        }

        [System.IO.File]::WriteAllText($tempFile, $plan.MessageText, $utf8NoBom)

        $commitArgs = @('-C', $script:RepoRoot, 'commit')
        if ($amend) { $commitArgs += '--amend' }
        $commitArgs += @('-F', $tempFile)

        $commitCaption = if ($amend) { 
            'git commit --amend -F <temp-commit-message-file>' 
        } else { 
            'git commit -F <temp-commit-message-file>' 
        }
        
        [void](Run-External -FileName 'git' -Arguments $commitArgs -Caption $commitCaption -ShowProgress)

        if ($pushAfter) {
            if ($amend -and $script:Config.UseForceWithLease) {
                [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'push', '--force-with-lease') -Caption 'git push --force-with-lease' -ShowProgress)
            } else {
                [void](Run-External -FileName 'git' -Arguments @('-C', $script:RepoRoot, 'push', '-u', 'origin', 'HEAD') -Caption 'git push -u origin HEAD' -ShowProgress)
            }
        }

        Refresh-Status
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Commit failed', 'OK', 'Error') | Out-Null
    } finally {
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }
}

#endregion

#region Utility Functions

function Save-LogToFile {
    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.Filter = 'Text files (*.txt)|*.txt|Log files (*.log)|*.log|All files (*.*)|*.*'
    $dialog.FileName = ('git-glide-gui-log-' + (Get-Date).ToString('yyyyMMdd-HHmmss') + '.txt')
    
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
    
    [System.IO.File]::WriteAllText($dialog.FileName, $script:LogTextBox.Text)
    Append-Log -Text ('Saved log to ' + $dialog.FileName) -Color ([System.Drawing.Color]::DarkGreen)
}

function Copy-LastCommand {
    if (-not [string]::IsNullOrWhiteSpace($script:LastCommandSummary)) {
        [System.Windows.Forms.Clipboard]::SetText($script:LastCommandSummary)
        Append-Log -Text 'Copied last command summary to clipboard.' -Color ([System.Drawing.Color]::DarkGreen)
    }
}

function Set-HelpExamples {
    if (-not $script:HelpTextBox) { return }
    
    $script:HelpTextBox.Text = @"
Git Glide GUI - Enhanced Version v3.1
====================================

Configuration
-------------
Settings are stored in: $script:ConfigPath

Current settings:
- Base branch: $($script:Config.BaseBranch)
- Main branch: $($script:Config.MainBranch)
- Feature prefix: $($script:Config.FeatureBranchPrefix)
- Max history lines: $($script:Config.MaxHistoryLines)
- Commit subject max: $($script:Config.CommitSubjectMaxLength)

Typical workflow
----------------
1. Create feature branch from $($script:Config.BaseBranch)
2. Make changes
3. Stage selected or stage all
4. Write a commit subject and optional multiline body
5. Commit or Commit + push
6. Merge feature -> $($script:Config.BaseBranch)
7. Optionally merge $($script:Config.BaseBranch) -> $($script:Config.MainBranch)
8. Tag release outside this GUI or in a later iteration

Suggested branch names
----------------------
$($script:Config.FeatureBranchPrefix)v34-3-trust-observability-local-first
$($script:Config.HotfixBranchPrefix)v34-1-httpserver-logger-build-fix
$($script:Config.RefactorBranchPrefix)v34-2-3-restore-controller

Suggested commit subjects
-------------------------
v34.3: add trust, observability, and local-first foundation
v34.2.3: extract restore live-job orchestration into restoreController
v34.1.1: fix HttpServer logger calls for MinGW build

Suggested commit body style
---------------------------
- add restoreController.js
- move restore stream and polling orchestration out of app.js
- keep restore UI behavior unchanged
- add focused JS tests for restore controller behavior

Keyboard shortcuts
------------------
F5           - Refresh status
Ctrl+D       - Show diff
Ctrl+S       - Stage selected
Ctrl+U       - Unstage selected
Ctrl+Shift+S - Stage all
Ctrl+Enter   - Commit
Ctrl+P       - Push

New features in this version
-----------------------------
✓ Input validation for branch names and commits
✓ Configuration file support
✓ Progress indicators for long operations
✓ Cancel button for running operations
✓ Stash management panel with show/apply/pop/drop/branch/clear buttons
✓ Improved error messages
✓ Fixed Quote-Arg escaping bug
✓ Better git state verification
✓ Configurable branch names
✓ Commit subject length warnings
✓ Robust diff preview for staged, unstaged, renamed, deleted, conflicted, and untracked files
✓ Saved window size and splitter positions between sessions
✓ Richer tooltips with explanation before command preview
✓ Custom Git tab with visible create/update/remove controls and saved user-defined command buttons
✓ Appearance tab with persistent per-section colors
✓ Resizable repository/header, main work area, changed-file action, and log action sections
✓ Adaptive repository status rows and proportional action footers
✓ Functional Tags / Release tab for annotated tags, push, delete, checkout, and branch-from-tag
✓ Undo last commit safely with git reset --soft HEAD~1
✓ Audit log written to GitGlideGUI-Audit.log with command, exit code, and duration
✓ Safer custom Git command validation and confirmation for potentially destructive commands

Notes
-----
- Hover a button to see what it does first, then the exact commands in the Preview tab.
- The Output tab shows live stdout/stderr and exit codes.
- If you use Amend + Push, the GUI uses:
  git push --force-with-lease
  for safety (configurable).
- You can cancel long-running operations using the Cancel button.
- Use the Stash tab to save and restore work in progress.
- Drag visible splitters vertically or horizontally; the layout is saved on close and restored next time. The splitter between the upper workflow area and lower changed-files/diff/log area is now visible and persistent.
"@
}

function Set-SafeSplitterDistance {
    param(
        [System.Windows.Forms.SplitContainer]$Splitter,
        [int]$Distance,
        [int]$FallbackDistance = 300
    )
    if (-not $Splitter) { return }

    try {
        $available = if ($Splitter.Orientation -eq [System.Windows.Forms.Orientation]::Vertical) { $Splitter.Width } else { $Splitter.Height }
        if ($available -le 0) { return }

        $min = [Math]::Max(0, $Splitter.Panel1MinSize)
        $max = [Math]::Max($min, $available - $Splitter.Panel2MinSize - $Splitter.SplitterWidth)
        if ($max -lt $min) { return }

        $candidate = if ($Distance -gt 0) { $Distance } else { $FallbackDistance }
        $candidate = [Math]::Max($min, [Math]::Min($candidate, $max))
        $Splitter.SplitterDistance = $candidate
    } catch {
        Append-Log -Text ('Could not apply saved splitter distance: ' + $_.Exception.Message) -Color ([System.Drawing.Color]::DarkOrange)
    }
}

function Apply-SavedLayout {
    if (-not (Get-ConfigBool -Name 'RememberWindowLayout' -DefaultValue $true)) { return }

    Set-SafeSplitterDistance -Splitter $script:MainWorkSplit -Distance (Get-ConfigInt -Name 'MainWorkSplitDistance' -DefaultValue 470) -FallbackDistance 470
    Set-SafeSplitterDistance -Splitter $script:RootTopSplit -Distance (Get-ConfigInt -Name 'RootTopSplitDistance' -DefaultValue 38) -FallbackDistance 38
    Set-SafeSplitterDistance -Splitter $script:HeaderTopAreaSplit -Distance (Get-ConfigInt -Name 'HeaderTopAreaSplitDistance' -DefaultValue 120) -FallbackDistance 120
    Set-SafeSplitterDistance -Splitter $script:TopSplit -Distance (Get-ConfigInt -Name 'TopSplitDistance' -DefaultValue 650) -FallbackDistance 650
    Set-SafeSplitterDistance -Splitter $script:TopLeftSplit -Distance (Get-ConfigInt -Name 'TopLeftSplitDistance' -DefaultValue 185) -FallbackDistance 185
    Set-SafeSplitterDistance -Splitter $script:CommitPreviewSplit -Distance (Get-ConfigInt -Name 'CommitPreviewSplitDistance' -DefaultValue 470) -FallbackDistance 470
    Set-SafeSplitterDistance -Splitter $script:ContentSplit -Distance (Get-ConfigInt -Name 'ContentSplitDistance' -DefaultValue 430) -FallbackDistance 430
    Set-SafeSplitterDistance -Splitter $script:RightSplit -Distance (Get-ConfigInt -Name 'RightSplitDistance' -DefaultValue 250) -FallbackDistance 250
    Set-SafeSplitterDistance -Splitter $script:ChangedFilesActionSplit -Distance (Get-ConfigInt -Name 'ChangedFilesActionSplitDistance' -DefaultValue 520) -FallbackDistance 520
    Set-SafeSplitterDistance -Splitter $script:LogActionSplit -Distance (Get-ConfigInt -Name 'LogActionSplitDistance' -DefaultValue 245) -FallbackDistance 245
    Set-SafeSplitterDistance -Splitter $script:AppearanceMainSplit -Distance (Get-ConfigInt -Name 'AppearanceSplitDistance' -DefaultValue 280) -FallbackDistance 280
}

function Save-LayoutConfig {
    if (-not (Get-ConfigBool -Name 'RememberWindowLayout' -DefaultValue $true)) { return }

    try {
        if ($form.WindowState -eq [System.Windows.Forms.FormWindowState]::Normal) {
            Set-ConfigValue -Name 'WindowWidth' -Value ([int]$form.Width)
            Set-ConfigValue -Name 'WindowHeight' -Value ([int]$form.Height)
        }
        if ($script:RootTopSplit) { Set-ConfigValue -Name 'RootTopSplitDistance' -Value ([int]$script:RootTopSplit.SplitterDistance) }
        if ($script:MainWorkSplit) { Set-ConfigValue -Name 'MainWorkSplitDistance' -Value ([int]$script:MainWorkSplit.SplitterDistance) }
        if ($script:HeaderTopAreaSplit) { Set-ConfigValue -Name 'HeaderTopAreaSplitDistance' -Value ([int]$script:HeaderTopAreaSplit.SplitterDistance) }
        if ($script:TopSplit) { Set-ConfigValue -Name 'TopSplitDistance' -Value ([int]$script:TopSplit.SplitterDistance) }
        if ($script:TopLeftSplit) { Set-ConfigValue -Name 'TopLeftSplitDistance' -Value ([int]$script:TopLeftSplit.SplitterDistance) }
        if ($script:CommitPreviewSplit) { Set-ConfigValue -Name 'CommitPreviewSplitDistance' -Value ([int]$script:CommitPreviewSplit.SplitterDistance) }
        if ($script:ContentSplit) { Set-ConfigValue -Name 'ContentSplitDistance' -Value ([int]$script:ContentSplit.SplitterDistance) }
        if ($script:RightSplit) { Set-ConfigValue -Name 'RightSplitDistance' -Value ([int]$script:RightSplit.SplitterDistance) }
        if ($script:ChangedFilesActionSplit) { Set-ConfigValue -Name 'ChangedFilesActionSplitDistance' -Value ([int]$script:ChangedFilesActionSplit.SplitterDistance) }
        if ($script:LogActionSplit) { Set-ConfigValue -Name 'LogActionSplitDistance' -Value ([int]$script:LogActionSplit.SplitterDistance) }
        if ($script:AppearanceMainSplit) { Set-ConfigValue -Name 'AppearanceSplitDistance' -Value ([int]$script:AppearanceMainSplit.SplitterDistance) }
        Save-Config -Config $script:Config
    } catch {
        Write-Warning "Failed to save layout config: $_"
    }
}

#endregion

#region UI Setup

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Git Glide GUI v3.6.4 - safer visual Git workflows'
$form.Size = New-Object System.Drawing.Size -ArgumentList @((Get-ConfigInt -Name 'WindowWidth' -DefaultValue 1580), (Get-ConfigInt -Name 'WindowHeight' -DefaultValue 1080))
$form.StartPosition = 'CenterScreen'
$form.MinimumSize = New-Object System.Drawing.Size(1320, 860)
$form.Font = $script:UiFont
$form.KeyPreview = $true

$rootLayout = New-Object System.Windows.Forms.TableLayoutPanel
$rootLayout.Dock = 'Fill'
$rootLayout.ColumnCount = 1
$rootLayout.RowCount = 2
[void]$rootLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
[void]$rootLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
$form.Controls.Add($rootLayout)

# Main work split: top workflow area above changed-files/diff/log area.
# This replaces fixed percent table rows with a visible, saved splitter.
$mainWorkSplit = New-Object System.Windows.Forms.SplitContainer
$script:MainWorkSplit = $mainWorkSplit
$mainWorkSplit.Dock = 'Fill'
$mainWorkSplit.Orientation = 'Horizontal'
$mainWorkSplit.SplitterWidth = 11
$mainWorkSplit.Panel1MinSize = 120
$mainWorkSplit.Panel2MinSize = 120
$rootLayout.Controls.Add($mainWorkSplit, 0, 0)

# Top shell: progress bar above repository status, separated by a visible splitter.
# This makes the progress/status boundary discoverable and also lets users give
# more or less room to the top area on smaller screens.
$rootTopSplit = New-Object System.Windows.Forms.SplitContainer
$script:RootTopSplit = $rootTopSplit
$rootTopSplit.Dock = 'Fill'
$rootTopSplit.Orientation = 'Horizontal'
$rootTopSplit.SplitterWidth = 9
$rootTopSplit.Panel1MinSize = 32
$rootTopSplit.Panel2MinSize = 120
$mainWorkSplit.Panel1.Controls.Add($rootTopSplit)

# Progress bar and cancel button
$progressPanel = New-Object System.Windows.Forms.Panel
$progressPanel.Dock = 'Fill'
$progressPanel.Padding = New-Object System.Windows.Forms.Padding(5)
$rootTopSplit.Panel1.Controls.Add($progressPanel)

$script:ProgressBar = New-Object System.Windows.Forms.ProgressBar
$script:ProgressBar.Dock = 'Fill'
$script:ProgressBar.Style = 'Continuous'
$script:ProgressBar.Visible = $false
$progressPanel.Controls.Add($script:ProgressBar)

$script:CancelButton = New-Object System.Windows.Forms.Button
$script:CancelButton.Text = 'Cancel'
$script:CancelButton.Dock = 'Right'
$script:CancelButton.Width = 80
$script:CancelButton.Enabled = $false
$script:CancelButton.Add_Click({ Cancel-CurrentOperation })
$progressPanel.Controls.Add($script:CancelButton)

# Top area: repository status above branch/actions and commit/preview.
# A horizontal splitter lets users decide how much vertical room the repository
# status should use. The distance is saved on close and restored next session.
$topAreaSplit = New-Object System.Windows.Forms.SplitContainer
$script:HeaderTopAreaSplit = $topAreaSplit
$topAreaSplit.Dock = 'Fill'
$topAreaSplit.Orientation = 'Horizontal'
$topAreaSplit.SplitterWidth = 9
$topAreaSplit.Panel1MinSize = 25
$topAreaSplit.Panel2MinSize = 25
$rootTopSplit.Panel2.Controls.Add($topAreaSplit)

# Header group
$headerGroup = New-Object System.Windows.Forms.GroupBox
$headerGroup.Text = 'Repository status'
$headerGroup.Dock = 'Fill'
$headerGroup.AutoSize = $false
$headerGroup.Padding = New-Object System.Windows.Forms.Padding(10)
$topAreaSplit.Panel1.Controls.Add($headerGroup)
$script:HeaderGroup = $headerGroup

$topSplit = New-Object System.Windows.Forms.SplitContainer
$script:TopSplit = $topSplit
$topSplit.Dock = 'Fill'
$topSplit.Orientation = 'Vertical'
$topSplit.SplitterWidth = 9
$topSplit.Panel1MinSize = 25
$topSplit.Panel2MinSize = 25
$topAreaSplit.Panel2.Controls.Add($topSplit)

$topLeftSplit = New-Object System.Windows.Forms.SplitContainer
$script:TopLeftSplit = $topLeftSplit
$topLeftSplit.Dock = 'Fill'
$topLeftSplit.Orientation = 'Horizontal'
$topLeftSplit.SplitterWidth = 9
$topLeftSplit.Panel1MinSize = 25
$topLeftSplit.Panel2MinSize = 25
$topSplit.Panel1.Controls.Add($topLeftSplit)

$headerLayout = New-Object System.Windows.Forms.TableLayoutPanel
$headerLayout.Dock = 'Fill'
$headerLayout.ColumnCount = 4
$headerLayout.RowCount = 5
$headerLayout.AutoSize = $false
[void]$headerLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$headerLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
[void]$headerLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$headerLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize)))
for ($i = 0; $i -lt 5; $i++) {
    [void]$headerLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 20)))
}
$headerGroup.Controls.Add($headerLayout)

function Add-HeaderLabel($row, $col, $text, $bold=$false) {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $text
    $label.AutoSize = $false
    $label.Dock = 'Fill'
    $label.AutoEllipsis = $true
    $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    if ($bold) { $label.Font = $script:UiFontBold }
    $label.Margin = New-Object System.Windows.Forms.Padding(4, 2, 8, 2)
    $headerLayout.Controls.Add($label, $col, $row)
    return $label
}

[void](Add-HeaderLabel 0 0 'Repo:' $true)
$script:RepoPathValueLabel = Add-HeaderLabel 0 1 '-' $false
$script:RepoPathValueLabel.AutoEllipsis = $true
[void](Add-HeaderLabel 0 2 'Changed files:' $true)
$script:ChangedCountValueLabel = Add-HeaderLabel 0 3 '0'

$openRepositoryButton = New-Object System.Windows.Forms.Button
$openRepositoryButton.Text = 'Open existing...'
$openRepositoryButton.Dock = 'Fill'
$openRepositoryButton.Margin = New-Object System.Windows.Forms.Padding(4, 2, 4, 2)
$openRepositoryButton.Height = 24
$headerLayout.Controls.Add($openRepositoryButton, 2, 3)
$script:OpenRepositoryButton = $openRepositoryButton


$newRepositoryButton = New-Object System.Windows.Forms.Button
$newRepositoryButton.Text = 'Init new...'
$newRepositoryButton.Dock = 'Fill'
$newRepositoryButton.Margin = New-Object System.Windows.Forms.Padding(4, 2, 4, 2)
$newRepositoryButton.Height = 24
$headerLayout.Controls.Add($newRepositoryButton, 3, 3)
$script:NewRepositoryButton = $newRepositoryButton

[void](Add-HeaderLabel 1 0 'Current branch:' $true)
$script:BranchValueLabel = Add-HeaderLabel 1 1 '-'
[void](Add-HeaderLabel 1 2 'Upstream:' $true)
$script:UpstreamValueLabel = Add-HeaderLabel 1 3 '-'

[void](Add-HeaderLabel 2 0 'Branch status:' $true)
$script:BranchStateValueLabel = Add-HeaderLabel 2 1 '-'
[void](Add-HeaderLabel 2 2 'Working tree:' $true)
$script:WorkingTreeValueLabel = Add-HeaderLabel 2 3 '-'

[void](Add-HeaderLabel 3 0 'Stash count:' $true)
$script:StashCountLabel = Add-HeaderLabel 3 1 '0'

[void](Add-HeaderLabel 4 0 'Suggested next action:' $true)
$script:SuggestedNextActionLabel = Add-HeaderLabel 4 1 'Refresh repository status to get a suggestion.'
$headerLayout.SetColumnSpan($script:SuggestedNextActionLabel, 2)
$script:SuggestedNextActionButton = New-Object System.Windows.Forms.Button
$script:SuggestedNextActionButton.Text = 'Do it'
$script:SuggestedNextActionButton.Dock = 'Fill'
$script:SuggestedNextActionButton.Margin = New-Object System.Windows.Forms.Padding(4, 2, 4, 2)
$script:SuggestedNextActionButton.Height = 24
$script:SuggestedNextActionButton.Enabled = $false
$script:SuggestedNextActionButton.Add_Click({ Invoke-SuggestedNextAction })
$headerLayout.Controls.Add($script:SuggestedNextActionButton, 3, 4)

# Branch group
$branchGroup = New-Object System.Windows.Forms.GroupBox
$branchGroup.Text = 'Feature branch'
$branchGroup.Dock = 'Fill'
$branchGroup.AutoSize = $false
$branchGroup.Padding = New-Object System.Windows.Forms.Padding(10)
$topLeftSplit.Panel1.Controls.Add($branchGroup)
$script:BranchGroup = $branchGroup

$branchLayout = New-Object System.Windows.Forms.TableLayoutPanel
$branchLayout.Dock = 'Fill'
$branchLayout.ColumnCount = 4
$branchLayout.RowCount = 3
$branchLayout.AutoSize = $true
[void]$branchLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$branchLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
[void]$branchLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$branchLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize)))
$branchGroup.Controls.Add($branchLayout)

$branchNameLabel = New-Object System.Windows.Forms.Label
$branchNameLabel.Text = 'New feature branch:'
$branchNameLabel.AutoSize = $true
$branchNameLabel.Margin = New-Object System.Windows.Forms.Padding(4, 6, 8, 6)
$branchLayout.Controls.Add($branchNameLabel, 0, 0)

$script:FeatureBranchTextBox = New-Object System.Windows.Forms.TextBox
$script:FeatureBranchTextBox.Dock = 'Fill'
$script:FeatureBranchTextBox.Text = $script:Config.FeatureBranchPrefix
$script:FeatureBranchTextBox.Margin = New-Object System.Windows.Forms.Padding(4)
$branchLayout.Controls.Add($script:FeatureBranchTextBox, 1, 0)

$script:BaseFromDevelopCheckBox = New-Object System.Windows.Forms.CheckBox
$script:BaseFromDevelopCheckBox.Text = "Base from $($script:Config.BaseBranch) (switch + pull first)"
$script:BaseFromDevelopCheckBox.AutoSize = $true
$script:BaseFromDevelopCheckBox.Checked = $true
$script:BaseFromDevelopCheckBox.Margin = New-Object System.Windows.Forms.Padding(8, 6, 8, 6)
$branchLayout.Controls.Add($script:BaseFromDevelopCheckBox, 2, 0)

$createBranchButton = New-Object System.Windows.Forms.Button
$createBranchButton.Text = 'Create feature branch'
$createBranchButton.AutoSize = $true
$createBranchButton.Padding = New-Object System.Windows.Forms.Padding(10, 4, 10, 4)
$createBranchButton.Margin = New-Object System.Windows.Forms.Padding(4)
$createBranchButton.Add_Click({ Create-FeatureBranch })
$branchLayout.Controls.Add($createBranchButton, 3, 0)

$switchBranchLabel = New-Object System.Windows.Forms.Label
$switchBranchLabel.Text = 'Switch to branch:'
$switchBranchLabel.AutoSize = $true
$switchBranchLabel.Margin = New-Object System.Windows.Forms.Padding(4, 6, 8, 6)
$branchLayout.Controls.Add($switchBranchLabel, 0, 1)

$script:BranchSwitchComboBox = New-Object System.Windows.Forms.ComboBox
$script:BranchSwitchComboBox.Dock = 'Fill'
$script:BranchSwitchComboBox.DropDownStyle = 'DropDown'
$script:BranchSwitchComboBox.Margin = New-Object System.Windows.Forms.Padding(4)
$branchLayout.Controls.Add($script:BranchSwitchComboBox, 1, 1)
$branchLayout.SetColumnSpan($script:BranchSwitchComboBox, 2)

$switchBranchButton = New-Object System.Windows.Forms.Button
$switchBranchButton.Text = 'Switch branch'
$switchBranchButton.AutoSize = $true
$switchBranchButton.Padding = New-Object System.Windows.Forms.Padding(10, 4, 10, 4)
$switchBranchButton.Margin = New-Object System.Windows.Forms.Padding(4)
$switchBranchButton.Add_Click({ Switch-SelectedBranch })
$branchLayout.Controls.Add($switchBranchButton, 3, 1)

$branchHelpLabel = New-WrappingLabel -Text 'Enhanced: input validation, progress indicators, cancel support, saved splitter layout, and hover command previews.' -Height 36
$branchLayout.Controls.Add($branchHelpLabel, 0, 2)
$branchLayout.SetColumnSpan($branchHelpLabel, 4)

# Actions group
$actionsGroup = New-Object System.Windows.Forms.GroupBox
$actionsGroup.Text = 'Common actions'
$actionsGroup.Dock = 'Fill'
$actionsGroup.AutoSize = $false
$actionsGroup.Padding = New-Object System.Windows.Forms.Padding(10)
$topLeftSplit.Panel2.Controls.Add($actionsGroup)
$script:ActionsGroup = $actionsGroup

$actionsTabs = New-Object System.Windows.Forms.TabControl
$actionsTabs.Dock = 'Fill'
$actionsTabs.Multiline = $true
$actionsTabs.Padding = New-Object System.Drawing.Point(12, 5)
$actionsGroup.Controls.Add($actionsTabs)
$script:ActionsTabs = $actionsTabs

function New-ActionTab {
    param([string]$Title)
    $tab = New-Object System.Windows.Forms.TabPage
    $tab.Text = $Title
    $tab.Padding = New-Object System.Windows.Forms.Padding(6)
    $panel = New-Object System.Windows.Forms.FlowLayoutPanel
    $panel.Dock = 'Fill'
    $panel.WrapContents = $true
    $panel.AutoScroll = $true
    $panel.Padding = New-Object System.Windows.Forms.Padding(4)
    $panel.Margin = New-Object System.Windows.Forms.Padding(0)
    $tab.Controls.Add($panel)
    [void]$actionsTabs.TabPages.Add($tab)
    return $panel
}

$setupActionsPanel = New-ActionTab 'Setup'
$inspectActionsPanel = New-ActionTab 'Inspect / Build'
$historyActionsPanel = New-ActionTab 'History / Graph'
$recoveryActionsPanel = New-ActionTab 'Recovery'
$learningActionsPanel = New-ActionTab 'Learning'
$stageActionsPanel = New-ActionTab 'Stage'
$branchActionsPanel = New-ActionTab 'Branch'
$integrateActionsPanel = New-ActionTab 'Integrate'
$stashActionsPanel = New-ActionTab 'Stash'
$customGitActionsPanel = New-ActionTab 'Custom Git'
$appearanceActionsPanel = New-ActionTab 'Appearance'
$tagsActionsPanel = New-ActionTab 'Tags / Release'
$script:SetupTabPage = $setupActionsPanel.Parent
$script:InspectTabPage = $inspectActionsPanel.Parent
$script:HistoryTabPage = $historyActionsPanel.Parent
$script:RecoveryTabPage = $recoveryActionsPanel.Parent
$script:LearningTabPage = $learningActionsPanel.Parent
$script:StageTabPage = $stageActionsPanel.Parent
$script:BranchTabPage = $branchActionsPanel.Parent
$script:IntegrateTabPage = $integrateActionsPanel.Parent
$script:StashTabPage = $stashActionsPanel.Parent
$script:CustomGitTabPage = $customGitActionsPanel.Parent
$script:AppearanceTabPage = $appearanceActionsPanel.Parent
$script:TagsTabPage = $tagsActionsPanel.Parent
$script:AllActionTabs = @($script:SetupTabPage, $script:InspectTabPage, $script:HistoryTabPage, $script:RecoveryTabPage, $script:LearningTabPage, $script:StageTabPage, $script:BranchTabPage, $script:IntegrateTabPage, $script:StashTabPage, $script:CustomGitTabPage, $script:AppearanceTabPage, $script:TagsTabPage)
$script:AdvancedActionTabs = @($script:IntegrateTabPage, $script:CustomGitTabPage, $script:AppearanceTabPage, $script:TagsTabPage)

function Apply-UiMode {
    $beginner = Get-ConfigBool -Name 'BeginnerMode' -DefaultValue $true
    if (-not $script:ActionsTabs -or -not $script:AllActionTabs) { return }

    $script:ActionsTabs.SuspendLayout()
    try {
        $current = $script:ActionsTabs.SelectedTab
        $script:ActionsTabs.TabPages.Clear()
        foreach ($tab in $script:AllActionTabs) {
            if ($null -eq $tab) { continue }
            if ($beginner -and ($script:AdvancedActionTabs -contains $tab)) { continue }
            [void]$script:ActionsTabs.TabPages.Add($tab)
        }
        if ($current -and $script:ActionsTabs.TabPages.Contains($current)) {
            $script:ActionsTabs.SelectedTab = $current
        } elseif ($script:SetupTabPage -and $script:ActionsTabs.TabPages.Contains($script:SetupTabPage)) {
            $script:ActionsTabs.SelectedTab = $script:SetupTabPage
        }
    } finally {
        $script:ActionsTabs.ResumeLayout()
    }

    if ($script:ModeToggleButton) {
        if ($beginner) {
            $script:ModeToggleButton.Text = 'Switch to Advanced mode'
        } else {
            $script:ModeToggleButton.Text = 'Switch to Beginner mode'
        }
    }

    if ($script:ModeValueLabel) {
        $script:ModeValueLabel.Text = if ($beginner) { 'Beginner' } else { 'Advanced' }
    }
}

function Toggle-UiMode {
    $beginner = Get-ConfigBool -Name 'BeginnerMode' -DefaultValue $true
    Set-ConfigValue -Name 'BeginnerMode' -Value (-not $beginner)
    Save-Config -Config $script:Config
    Apply-UiMode
    $mode = if (Get-ConfigBool -Name 'BeginnerMode' -DefaultValue $true) { 'Beginner' } else { 'Advanced' }
    Set-SuggestedNextAction -Text ("$mode mode enabled. Use Setup to switch modes again.")
}

function Build-ModeTogglePreview {
    if (Get-ConfigBool -Name 'BeginnerMode' -DefaultValue $true) {
        return 'show advanced tabs: Integrate, Custom Git, Appearance, Tags / Release'
    }
    return 'hide advanced tabs and keep Setup, Inspect / Build, History / Graph, Recovery, Learning, Stage, Branch, and Stash visible'
}

function New-ActionButton {
    param(
        [System.Windows.Forms.Control]$ParentPanel,
        [string]$Text,
        [int]$Width,
        [scriptblock]$Handler,
        [scriptblock]$PreviewBuilder,
        [string]$PreviewTitle,
        [string]$Notes = ''
    )
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $Text
    $btn.Width = $Width
    $btn.Height = 34
    $btn.Margin = New-Object System.Windows.Forms.Padding(4)
    $btn.Add_Click($Handler)
    Set-ControlPreview -Control $btn -Builder $PreviewBuilder -Title $PreviewTitle -Notes $Notes
    $ParentPanel.Controls.Add($btn)
    return $btn
}

function New-ActionGuidance {
    param(
        [System.Windows.Forms.Control]$ParentPanel,
        [string]$Text,
        [string]$Title = 'Beginner guidance'
    )
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Width = 920
    $label.Height = 44
    $label.AutoSize = $false
    $label.Margin = New-Object System.Windows.Forms.Padding(4, 4, 4, 8)
    $label.Padding = New-Object System.Windows.Forms.Padding(8, 4, 8, 4)
    $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $label.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    if ($script:ToolTip) { $script:ToolTip.SetToolTip($label, ($Title + "`r`n`r`n" + $Text)) }
    $ParentPanel.Controls.Add($label)
    return $label
}

# Setup actions
[void](New-ActionGuidance -ParentPanel $setupActionsPanel -Text 'Start here: open an existing repository, initialize a new project folder, create the first commit, or add a remote. Hover buttons to see what will happen before anything runs.')
$script:ModeToggleButton = New-ActionButton -ParentPanel $setupActionsPanel -Text 'Switch to Advanced mode' -Width 190 -Handler { Toggle-UiMode } -PreviewBuilder { Build-ModeTogglePreview } -PreviewTitle 'Beginner / Advanced mode' -Notes 'Beginner mode hides less common tabs. Advanced mode shows every workflow tab without changing repository state.'
[void](New-ActionButton -ParentPanel $setupActionsPanel -Text 'Open existing repo' -Width 160 -Handler { Show-RepositoryPicker } -PreviewBuilder { 'select an existing Git repository folder and refresh status' } -PreviewTitle 'Open existing repository' -Notes 'Use this when the project already has a .git folder.')
[void](New-ActionButton -ParentPanel $setupActionsPanel -Text 'Init new repo' -Width 130 -Handler { Show-NewRepositoryPicker } -PreviewBuilder { 'git init -b <main-branch>' } -PreviewTitle 'Initialize new repository' -Notes 'Use this when the selected project folder intentionally does not have a Git repository yet.')
[void](New-ActionButton -ParentPanel $setupActionsPanel -Text 'First commit...' -Width 135 -Handler { Invoke-FirstCommitWizard } -PreviewBuilder { Build-FirstCommitPreview } -PreviewTitle 'First commit wizard' -Notes 'Creates or updates .gitignore, stages files, creates the first commit, and optionally configures/pushes to a remote.')
[void](New-ActionButton -ParentPanel $setupActionsPanel -Text 'Add .gitignore...' -Width 140 -Handler { Show-GitIgnoreTemplateDialog } -PreviewBuilder { Build-GitIgnorePreview } -PreviewTitle 'Create or update .gitignore' -Notes 'Adds a starter .gitignore template before committing generated files by accident.')
[void](New-ActionButton -ParentPanel $setupActionsPanel -Text 'Add remote...' -Width 125 -Handler { Show-RemoteSetupDialog } -PreviewBuilder { Build-RemoteSetupPreview } -PreviewTitle 'Add or update remote' -Notes 'Adds or updates origin and can optionally push the current branch with upstream tracking.')

# Inspect/Build actions
[void](New-ActionGuidance -ParentPanel $inspectActionsPanel -Text 'Inspect first when unsure: refresh status, read git status, preview diffs, or inspect the branch graph before committing, pushing, merging, or stashing.')
[void](New-ActionButton -ParentPanel $inspectActionsPanel -Text 'Refresh status' -Width 130 -Handler { Refresh-Status } -PreviewBuilder { 'git status --porcelain=v1 --branch' } -PreviewTitle 'Refresh repository status' -Notes 'Refreshes branch name, upstream, changed files, stash list, and working tree state.')
[void](New-ActionButton -ParentPanel $inspectActionsPanel -Text 'Git status' -Width 120 -Handler { Show-GitStatus } -PreviewBuilder { Build-StatusPreview } -PreviewTitle 'Show git status' -Notes 'Runs git status and shows the output in the upper preview pane.')
[void](New-ActionButton -ParentPanel $inspectActionsPanel -Text 'Show diff' -Width 120 -Handler { Show-SelectedDiff } -PreviewBuilder { Build-ShowDiffPreview } -PreviewTitle 'Show diff for selected file' -Notes 'Reloads the preview for the first selected changed file. Handles staged, unstaged, renamed, deleted, conflicted, and untracked files.')
[void](New-ActionButton -ParentPanel $inspectActionsPanel -Text 'Show graph' -Width 120 -Handler { Show-GitHistoryGraph } -PreviewBuilder { Build-HistoryPreview } -PreviewTitle 'Show branch/history graph' -Notes 'Useful for seeing branch tips, tags, and merges with minimal clicks.')
[void](New-ActionButton -ParentPanel $inspectActionsPanel -Text 'Build + Test' -Width 130 -Handler { Run-Build } -PreviewBuilder { Build-BuildPreview } -PreviewTitle 'Build and test (no web UI)' -Notes 'Runs the project build/test script without starting the web UI.')
[void](New-ActionButton -ParentPanel $inspectActionsPanel -Text 'Build + Test + Run' -Width 150 -Handler { Run-Build -WithWeb } -PreviewBuilder { Build-BuildPreview -WithWeb } -PreviewTitle 'Build, test, and run' -Notes 'Runs the full build/test script and starts the Release web UI.')
[void](New-ActionButton -ParentPanel $inspectActionsPanel -Text 'Undo last commit' -Width 145 -Handler { Undo-LastCommitSoft } -PreviewBuilder { Build-UndoLastCommitPreview } -PreviewTitle 'Undo last commit but keep changes staged' -Notes 'Runs git reset --soft HEAD~1 after confirmation. Useful when the last commit message or content needs correction before pushing.')

# History / Graph tab
$script:HistoryTabPage = $historyActionsPanel.Parent
$script:RecoveryTabPage = $recoveryActionsPanel.Parent
$script:LearningTabPage = $learningActionsPanel.Parent
$script:HistoryTabPage.Controls.Clear()
$script:HistoryTabPage.Padding = New-Object System.Windows.Forms.Padding(6)
$historyLayout = New-Object System.Windows.Forms.TableLayoutPanel
$historyLayout.Dock = 'Fill'
$historyLayout.ColumnCount = 1
$historyLayout.RowCount = 4
[void]$historyLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$historyLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$historyLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 55)))
[void]$historyLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 45)))
$script:HistoryTabPage.Controls.Add($historyLayout)

$historyGuidance = New-WrappingLabel -Text 'Read-only history view: inspect branch tips, remote tips, tags, and merges before pulling, merging, rebasing, deleting tags, cherry-picking, or undoing commits. This tab only runs git log/show commands.' -Height 42
$historyLayout.Controls.Add($historyGuidance, 0, 0)

$historyControls = New-Object System.Windows.Forms.FlowLayoutPanel
$historyControls.Dock = 'Fill'
$historyControls.AutoSize = $true
$historyControls.WrapContents = $true
$historyControls.Margin = New-Object System.Windows.Forms.Padding(0, 4, 0, 6)
$historyLayout.Controls.Add($historyControls, 0, 1)

$historyRefreshButton = New-Object System.Windows.Forms.Button
$historyRefreshButton.Text = 'Refresh graph'
$historyRefreshButton.Width = 125
$historyRefreshButton.Height = 32
$historyRefreshButton.Margin = New-Object System.Windows.Forms.Padding(4)
$historyRefreshButton.Add_Click({ Show-GitHistoryGraph; Refresh-HistoryModelSummary })
$historyControls.Controls.Add($historyRefreshButton)

$historySummaryButton = New-Object System.Windows.Forms.Button
$historySummaryButton.Text = 'Refresh summary'
$historySummaryButton.Width = 135
$historySummaryButton.Height = 32
$historySummaryButton.Margin = New-Object System.Windows.Forms.Padding(4)
$historySummaryButton.Add_Click({ Refresh-HistoryModelSummary })
$historyControls.Controls.Add($historySummaryButton)
$historyCherryPickButton = New-Object System.Windows.Forms.Button
$historyCherryPickButton.Text = 'Use selected for cherry-pick'
$historyCherryPickButton.Width = 185
$historyCherryPickButton.Height = 32
$historyCherryPickButton.Margin = New-Object System.Windows.Forms.Padding(4)
$historyCherryPickButton.Add_Click({ Set-CherryPickCommitFromHistorySelection })
$historyControls.Controls.Add($historyCherryPickButton)

$historyShowCommitButton = New-Object System.Windows.Forms.Button
$historyShowCommitButton.Text = 'Show selected commit'
$historyShowCommitButton.Width = 155
$historyShowCommitButton.Height = 32
$historyShowCommitButton.Margin = New-Object System.Windows.Forms.Padding(4)
$historyShowCommitButton.Add_Click({ Show-SelectedHistoryCommitDetails })
$historyControls.Controls.Add($historyShowCommitButton)

$historyMaxLabel = New-Object System.Windows.Forms.Label
$historyMaxLabel.Text = 'Max commits:'
$historyMaxLabel.AutoSize = $true
$historyMaxLabel.Margin = New-Object System.Windows.Forms.Padding(12, 10, 4, 4)
$historyControls.Controls.Add($historyMaxLabel)

$script:HistoryMaxCountUpDown = New-Object System.Windows.Forms.NumericUpDown
$script:HistoryMaxCountUpDown.Minimum = 10
$script:HistoryMaxCountUpDown.Maximum = 1000
$script:HistoryMaxCountUpDown.Value = [Math]::Min([Math]::Max([int]$script:Config.MaxHistoryLines, 10), 1000)
$script:HistoryMaxCountUpDown.Width = 75
$script:HistoryMaxCountUpDown.Margin = New-Object System.Windows.Forms.Padding(4)
$script:HistoryMaxCountUpDown.Add_ValueChanged({ Set-CommandPreview -Title 'History / Graph' -Commands (Build-HistoryPreview) -Notes 'Read-only command. It does not modify the repository.' })
$historyControls.Controls.Add($script:HistoryMaxCountUpDown)

$script:HistorySummaryLabel = New-Object System.Windows.Forms.Label
$script:HistorySummaryLabel.Text = 'History not loaded yet.'
$script:HistorySummaryLabel.AutoSize = $true
$script:HistorySummaryLabel.Margin = New-Object System.Windows.Forms.Padding(12, 10, 4, 4)
$historyControls.Controls.Add($script:HistorySummaryLabel)

$script:HistoryGraphTextBox = New-Object System.Windows.Forms.RichTextBox
$script:HistoryGraphTextBox.Dock = 'Fill'
$script:HistoryGraphTextBox.ReadOnly = $true
$script:HistoryGraphTextBox.Font = $script:FontMono
$script:HistoryGraphTextBox.WordWrap = $false
$script:HistoryGraphTextBox.ScrollBars = 'Both'
$script:HistoryGraphTextBox.Text = 'Click Refresh graph to load a read-only git log --graph view.'
$historyLayout.Controls.Add($script:HistoryGraphTextBox, 0, 2)
$script:HistoryVisualListView = New-Object System.Windows.Forms.ListView
$script:HistoryVisualListView.Dock = 'Fill'
$script:HistoryVisualListView.View = 'Details'
$script:HistoryVisualListView.FullRowSelect = $true
$script:HistoryVisualListView.GridLines = $true
$script:HistoryVisualListView.HideSelection = $false
$script:HistoryVisualListView.ShowItemToolTips = $true
[void]$script:HistoryVisualListView.Columns.Add('Graph', 60)
[void]$script:HistoryVisualListView.Columns.Add('Type', 70)
[void]$script:HistoryVisualListView.Columns.Add('Hash', 100)
[void]$script:HistoryVisualListView.Columns.Add('Branches', 180)
[void]$script:HistoryVisualListView.Columns.Add('Tags', 130)
[void]$script:HistoryVisualListView.Columns.Add('Remotes', 180)
[void]$script:HistoryVisualListView.Columns.Add('Subject', 360)
[void]$script:HistoryVisualListView.Columns.Add('Author', 130)
[void]$script:HistoryVisualListView.Columns.Add('Date', 170)
$script:HistoryVisualListView.Add_SelectedIndexChanged({ Update-HistorySelectionPreview })
$script:HistoryVisualListView.Add_DoubleClick({ Set-CherryPickCommitFromHistorySelection })
$historyLayout.Controls.Add($script:HistoryVisualListView, 0, 3)

if ($script:ToolTip) {
    $script:ToolTip.SetToolTip($historyRefreshButton, 'Run a read-only git log --graph command and display the branch/history graph.')
    $script:ToolTip.SetToolTip($historySummaryButton, 'Parse compact git log data and summarize commit count, merge count, and decorated commits.')
    $script:ToolTip.SetToolTip($historyCherryPickButton, 'Copies the selected visual/text history commit hash to the Recovery tab for cherry-pick preview.')
    $script:ToolTip.SetToolTip($historyShowCommitButton, 'Runs git show --stat for the selected commit without modifying the repository.')
    $script:ToolTip.SetToolTip($script:HistoryVisualListView, 'Visual history model: Graph column uses ASCII badges (H*=HEAD, B*=branch, R*=remote, T*=tag, M*=merge). Select a row to preview git show/cherry-pick commands; double-click to prepare cherry-pick.')
    $script:ToolTip.SetToolTip($script:HistoryMaxCountUpDown, 'Limit how many commits are shown. Large repositories can be slower.')
}

# Recovery tab
$script:RecoveryTabPage.Controls.Clear()
$script:RecoveryTabPage.Padding = New-Object System.Windows.Forms.Padding(6)
$recoveryLayout = New-Object System.Windows.Forms.TableLayoutPanel
$recoveryLayout.Dock = 'Fill'
$recoveryLayout.ColumnCount = 1
$recoveryLayout.RowCount = 5
[void]$recoveryLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$recoveryLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$recoveryLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 35)))
[void]$recoveryLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 65)))
[void]$recoveryLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
$script:RecoveryTabPage.Controls.Add($recoveryLayout)

$recoveryGuidance = New-WrappingLabel -Text 'Recovery guidance helps after failed pull, merge, stash pop/apply, or cherry-pick operations. It explains the likely cause, shows safe status commands, and provides explicit abort/continue buttons where appropriate.' -Height 46
$recoveryLayout.Controls.Add($recoveryGuidance, 0, 0)

$recoveryControls = New-Object System.Windows.Forms.FlowLayoutPanel
$recoveryControls.Dock = 'Fill'
$recoveryControls.AutoSize = $true
$recoveryControls.WrapContents = $true
$recoveryControls.Margin = New-Object System.Windows.Forms.Padding(0, 4, 0, 6)
$recoveryLayout.Controls.Add($recoveryControls, 0, 1)

$recoveryRefreshButton = New-Object System.Windows.Forms.Button
$recoveryRefreshButton.Text = 'Refresh recovery status'
$recoveryRefreshButton.Width = 170
$recoveryRefreshButton.Height = 32
$recoveryRefreshButton.Margin = New-Object System.Windows.Forms.Padding(4)
$recoveryRefreshButton.Add_Click({ Refresh-RecoveryStatus })
$recoveryControls.Controls.Add($recoveryRefreshButton)
$conflictRefreshButton = New-Object System.Windows.Forms.Button
$conflictRefreshButton.Text = 'List conflicted files'
$conflictRefreshButton.Width = 150
$conflictRefreshButton.Height = 32
$conflictRefreshButton.Margin = New-Object System.Windows.Forms.Padding(4)
$conflictRefreshButton.Add_Click({ Refresh-ConflictFiles })
$recoveryControls.Controls.Add($conflictRefreshButton)

$openConflictFileButton = New-Object System.Windows.Forms.Button
$openConflictFileButton.Text = 'Open file'
$openConflictFileButton.Width = 90
$openConflictFileButton.Height = 32
$openConflictFileButton.Margin = New-Object System.Windows.Forms.Padding(4)
$openConflictFileButton.Add_Click({ Open-SelectedConflictFile })
$recoveryControls.Controls.Add($openConflictFileButton)

$openConflictFolderButton = New-Object System.Windows.Forms.Button
$openConflictFolderButton.Text = 'Open folder'
$openConflictFolderButton.Width = 100
$openConflictFolderButton.Height = 32
$openConflictFolderButton.Margin = New-Object System.Windows.Forms.Padding(4)
$openConflictFolderButton.Add_Click({ Open-SelectedConflictFolder })
$recoveryControls.Controls.Add($openConflictFolderButton)

$stageResolvedConflictButton = New-Object System.Windows.Forms.Button
$stageResolvedConflictButton.Text = 'Stage resolved file'
$stageResolvedConflictButton.Width = 145
$stageResolvedConflictButton.Height = 32
$stageResolvedConflictButton.Margin = New-Object System.Windows.Forms.Padding(4)
$stageResolvedConflictButton.Add_Click({ Stage-SelectedConflictFileAsResolved })
$recoveryControls.Controls.Add($stageResolvedConflictButton)

$script:ContinueOperationButton = New-Object System.Windows.Forms.Button
$script:ContinueOperationButton.Text = 'Continue operation'
$script:ContinueOperationButton.Width = 145
$script:ContinueOperationButton.Height = 32
$script:ContinueOperationButton.Margin = New-Object System.Windows.Forms.Padding(4)
$script:ContinueOperationButton.Enabled = $false
$script:ContinueOperationButton.Add_Click({ Invoke-ContinueCurrentRecoveryOperation })
$recoveryControls.Controls.Add($script:ContinueOperationButton)

$abortMergeButton = New-Object System.Windows.Forms.Button
$abortMergeButton.Text = 'Abort merge'
$abortMergeButton.Width = 115
$abortMergeButton.Height = 32
$abortMergeButton.Margin = New-Object System.Windows.Forms.Padding(4)
$abortMergeButton.Add_Click({ Invoke-RecoveryCommandPlan -Kind 'merge-abort' })
$recoveryControls.Controls.Add($abortMergeButton)

$continueCherryPickButton = New-Object System.Windows.Forms.Button
$continueCherryPickButton.Text = 'Continue cherry-pick'
$continueCherryPickButton.Width = 145
$continueCherryPickButton.Height = 32
$continueCherryPickButton.Margin = New-Object System.Windows.Forms.Padding(4)
$continueCherryPickButton.Add_Click({ Invoke-RecoveryCommandPlan -Kind 'cherry-pick-continue' })
$recoveryControls.Controls.Add($continueCherryPickButton)

$abortCherryPickButton = New-Object System.Windows.Forms.Button
$abortCherryPickButton.Text = 'Abort cherry-pick'
$abortCherryPickButton.Width = 135
$abortCherryPickButton.Height = 32
$abortCherryPickButton.Margin = New-Object System.Windows.Forms.Padding(4)
$abortCherryPickButton.Add_Click({ Invoke-RecoveryCommandPlan -Kind 'cherry-pick-abort' })
$recoveryControls.Controls.Add($abortCherryPickButton)

$cherryPickLabel = New-Object System.Windows.Forms.Label
$cherryPickLabel.Text = 'Cherry-pick commit/ref:'
$cherryPickLabel.AutoSize = $true
$cherryPickLabel.Margin = New-Object System.Windows.Forms.Padding(12, 10, 4, 4)
$recoveryControls.Controls.Add($cherryPickLabel)

$script:CherryPickCommitTextBox = New-Object System.Windows.Forms.TextBox
$script:CherryPickCommitTextBox.Width = 185
$script:CherryPickCommitTextBox.Margin = New-Object System.Windows.Forms.Padding(4)
$recoveryControls.Controls.Add($script:CherryPickCommitTextBox)

$script:CherryPickNoCommitCheckBox = New-Object System.Windows.Forms.CheckBox
$script:CherryPickNoCommitCheckBox.Text = '--no-commit'
$script:CherryPickNoCommitCheckBox.AutoSize = $true
$script:CherryPickNoCommitCheckBox.Margin = New-Object System.Windows.Forms.Padding(4, 8, 4, 4)
$recoveryControls.Controls.Add($script:CherryPickNoCommitCheckBox)

$cherryPickButton = New-Object System.Windows.Forms.Button
$cherryPickButton.Text = 'Cherry-pick'
$cherryPickButton.Width = 105
$cherryPickButton.Height = 32
$cherryPickButton.Margin = New-Object System.Windows.Forms.Padding(4)
$cherryPickButton.Add_Click({ CherryPick-SelectedOrTypedCommit })
$recoveryControls.Controls.Add($cherryPickButton)

$mergeToolLabel = New-Object System.Windows.Forms.Label
$mergeToolLabel.Text = 'Merge tool:'
$mergeToolLabel.AutoSize = $true
$mergeToolLabel.Margin = New-Object System.Windows.Forms.Padding(12, 10, 4, 4)
$recoveryControls.Controls.Add($mergeToolLabel)

$script:ExternalMergeToolTextBox = New-Object System.Windows.Forms.TextBox
$script:ExternalMergeToolTextBox.Width = 210
$script:ExternalMergeToolTextBox.Margin = New-Object System.Windows.Forms.Padding(4)
$script:ExternalMergeToolTextBox.Text = if ($script:Config.ContainsKey('ExternalMergeToolCommand')) { [string]$script:Config.ExternalMergeToolCommand } else { 'git mergetool' }
$script:ExternalMergeToolTextBox.Add_TextChanged({ Set-CommandPreview -Title 'External merge tool' -Commands (Build-ExternalMergeToolPreview) -Notes 'Configured merge tool command. Default is git mergetool.' })
$recoveryControls.Controls.Add($script:ExternalMergeToolTextBox)

$saveMergeToolButton = New-Object System.Windows.Forms.Button
$saveMergeToolButton.Text = 'Save tool'
$saveMergeToolButton.Width = 90
$saveMergeToolButton.Height = 32
$saveMergeToolButton.Margin = New-Object System.Windows.Forms.Padding(4)
$saveMergeToolButton.Add_Click({ Save-ExternalMergeToolCommand })
$recoveryControls.Controls.Add($saveMergeToolButton)

$launchMergeToolButton = New-Object System.Windows.Forms.Button
$launchMergeToolButton.Text = 'Launch tool'
$launchMergeToolButton.Width = 100
$launchMergeToolButton.Height = 32
$launchMergeToolButton.Margin = New-Object System.Windows.Forms.Padding(4)
$launchMergeToolButton.Add_Click({ Launch-ExternalMergeTool })
$recoveryControls.Controls.Add($launchMergeToolButton)

$conflictFilesGroup = New-Object System.Windows.Forms.GroupBox
$conflictFilesGroup.Text = 'Unresolved conflict files'
$conflictFilesGroup.Dock = 'Fill'
$conflictFilesGroup.Padding = New-Object System.Windows.Forms.Padding(6)
$script:ConflictFilesListBox = New-Object System.Windows.Forms.ListBox
$script:ConflictFilesListBox.Dock = 'Fill'
$script:ConflictFilesListBox.HorizontalScrollbar = $true
$script:ConflictFilesListBox.Add_DoubleClick({ Open-SelectedConflictFile })
$conflictFilesGroup.Controls.Add($script:ConflictFilesListBox)
$recoveryLayout.Controls.Add($conflictFilesGroup, 0, 2)

$script:RecoverySummaryLabel = New-Object System.Windows.Forms.Label
$script:RecoverySummaryLabel.Text = 'No active recovery guidance.'
$script:RecoverySummaryLabel.AutoSize = $true
$script:RecoverySummaryLabel.Margin = New-Object System.Windows.Forms.Padding(4)
$recoveryLayout.Controls.Add($script:RecoverySummaryLabel, 0, 4)

$script:ConflictStateLabel = New-Object System.Windows.Forms.Label
$script:ConflictStateLabel.Text = 'Conflict state not inspected yet.'
$script:ConflictStateLabel.AutoSize = $true
$script:ConflictStateLabel.Margin = New-Object System.Windows.Forms.Padding(4, 0, 4, 4)
$recoveryLayout.Controls.Add($script:ConflictStateLabel, 0, 4)

$script:RecoveryTextBox = New-Object System.Windows.Forms.RichTextBox
$script:RecoveryTextBox.Dock = 'Fill'
$script:RecoveryTextBox.ReadOnly = $true
$script:RecoveryTextBox.Font = $script:FontMono
$script:RecoveryTextBox.WordWrap = $true
$script:RecoveryTextBox.ScrollBars = 'Both'
$script:RecoveryTextBox.Text = 'Recovery guidance appears here after a failed merge, pull, stash apply/pop, or cherry-pick. You can also click Refresh recovery status.'
$recoveryLayout.Controls.Add($script:RecoveryTextBox, 0, 3)

Set-ControlPreview -Control $recoveryRefreshButton -Builder { Build-RecoveryStatusPreview } -Title 'Refresh recovery status' -Notes 'Runs a safe read-only status command and updates the Recovery panel.'
Set-ControlPreview -Control $conflictRefreshButton -Builder { if (Get-Command Get-GgrUnmergedFilesCommandPlan -ErrorAction SilentlyContinue) { (Get-GgrUnmergedFilesCommandPlan).Display } else { 'git diff --name-only --diff-filter=U' } } -Title 'List conflicted files' -Notes 'Runs a read-only command that lists files with unresolved merge conflicts.'
Set-ControlPreview -Control $stageResolvedConflictButton -Builder { $path = if ($script:ConflictFilesListBox -and $script:ConflictFilesListBox.SelectedItem) { [string]$script:ConflictFilesListBox.SelectedItem } else { '<resolved-file>' }; if (Get-Command Get-GgrStageResolvedFileCommandPlan -ErrorAction SilentlyContinue) { (Get-GgrStageResolvedFileCommandPlan -Path $path).Display } else { 'git add -- ' + (Quote-Arg $path) } } -Title 'Stage resolved conflict file' -Notes 'Use after editing a conflicted file and removing conflict markers.'
Set-ControlPreview -Control $script:ContinueOperationButton -Builder { $state = Get-RecoveryStateSnapshot; if ($state -and $state.CherryPickInProgress) { 'git cherry-pick --continue' } elseif ($state -and $state.RebaseInProgress) { 'git rebase --continue' } elseif ($state -and $state.MergeInProgress) { 'git commit --no-edit' } else { 'git status --short' } } -Title 'Continue interrupted operation' -Notes 'Chooses merge, cherry-pick, or rebase continuation based on repository state markers.'
Set-ControlPreview -Control $launchMergeToolButton -Builder { Build-ExternalMergeToolPreview } -Title 'Launch external merge tool' -Notes 'Default is git mergetool. Configure Git merge.tool globally or edit the command here.'
if ($script:ToolTip) { $script:ToolTip.SetToolTip($script:ConflictFilesListBox, 'Double-click a conflicted file to open it. Resolve markers, save, then stage the file.') }
Set-ControlPreview -Control $abortMergeButton -Builder { if (Get-Command Get-GgrAbortMergeCommandPlan -ErrorAction SilentlyContinue) { (Get-GgrAbortMergeCommandPlan).Display } else { 'git merge --abort' } } -Title 'Abort in-progress merge' -Notes 'Use only when a merge is in progress and you want to return to the pre-merge state.'
Set-ControlPreview -Control $continueCherryPickButton -Builder { Build-CherryPickContinuePreview } -Title 'Continue cherry-pick' -Notes 'Use after resolving conflicts and staging the resolved files.'
Set-ControlPreview -Control $abortCherryPickButton -Builder { Build-CherryPickAbortPreview } -Title 'Abort cherry-pick' -Notes 'Use when a cherry-pick is in progress and you want to return to the pre-cherry-pick state.'
Set-ControlPreview -Control $cherryPickButton -Builder { Build-CherryPickPreview } -Title 'Cherry-pick selected commit' -Notes 'Applies one commit onto the current branch. Requires a clean working tree and asks for confirmation.'

# Learning tab
$script:LearningTabPage = $learningActionsPanel.Parent
$script:LearningTabPage.Controls.Clear()
$script:LearningTabPage.Padding = New-Object System.Windows.Forms.Padding(6)
$learningLayout = New-Object System.Windows.Forms.TableLayoutPanel
$learningLayout.Dock = 'Fill'
$learningLayout.ColumnCount = 1
$learningLayout.RowCount = 4
[void]$learningLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$learningLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$learningLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 42)))
[void]$learningLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 58)))
$script:LearningTabPage.Controls.Add($learningLayout)

$learningGuidance = New-WrappingLabel -Text 'Learning mode explains what Git operations mean, what they do, when they are useful, and how typical software-development workflows fit together.' -Height 42
$learningLayout.Controls.Add($learningGuidance, 0, 0)

$learningControls = New-Object System.Windows.Forms.FlowLayoutPanel
$learningControls.Dock = 'Fill'
$learningControls.AutoSize = $true
$learningControls.WrapContents = $true
$learningControls.Margin = New-Object System.Windows.Forms.Padding(0, 4, 0, 6)
$learningLayout.Controls.Add($learningControls, 0, 1)

$operationLabel = New-Object System.Windows.Forms.Label
$operationLabel.Text = 'Operation:'
$operationLabel.AutoSize = $true
$operationLabel.Margin = New-Object System.Windows.Forms.Padding(4, 8, 4, 4)
$learningControls.Controls.Add($operationLabel)

$script:LearningOperationComboBox = New-Object System.Windows.Forms.ComboBox
$script:LearningOperationComboBox.DropDownStyle = 'DropDownList'
$script:LearningOperationComboBox.Width = 240
$script:LearningOperationComboBox.Margin = New-Object System.Windows.Forms.Padding(4)
$operationNames = if (Get-Command Get-GglOperationGuidanceNames -ErrorAction SilentlyContinue) { Get-GglOperationGuidanceNames } else { @('Stage selected','Commit','Push current branch','Pull current branch','Merge','Cherry-pick','Resolve conflicts','History / Graph') }
foreach ($name in @($operationNames)) { [void]$script:LearningOperationComboBox.Items.Add([string]$name) }
if ($script:LearningOperationComboBox.Items.Count -gt 0) { $script:LearningOperationComboBox.SelectedIndex = 0 }
$learningControls.Controls.Add($script:LearningOperationComboBox)

$learningShowButton = New-Object System.Windows.Forms.Button
$learningShowButton.Text = 'Explain operation'
$learningShowButton.Width = 140
$learningShowButton.Height = 32
$learningShowButton.Margin = New-Object System.Windows.Forms.Padding(4)
$learningControls.Controls.Add($learningShowButton)

$learningWorkflowButton = New-Object System.Windows.Forms.Button
$learningWorkflowButton.Text = 'Show typical workflow'
$learningWorkflowButton.Width = 160
$learningWorkflowButton.Height = 32
$learningWorkflowButton.Margin = New-Object System.Windows.Forms.Padding(4)
$learningControls.Controls.Add($learningWorkflowButton)

$script:LearningOperationTextBox = New-Object System.Windows.Forms.RichTextBox
$script:LearningOperationTextBox.Dock = 'Fill'
$script:LearningOperationTextBox.ReadOnly = $true
$script:LearningOperationTextBox.Font = $script:UiFont
$script:LearningOperationTextBox.WordWrap = $true
$script:LearningOperationTextBox.ScrollBars = 'Vertical'
$learningLayout.Controls.Add($script:LearningOperationTextBox, 0, 2)

$script:LearningWorkflowTextBox = New-Object System.Windows.Forms.RichTextBox
$script:LearningWorkflowTextBox.Dock = 'Fill'
$script:LearningWorkflowTextBox.ReadOnly = $true
$script:LearningWorkflowTextBox.Font = $script:UiFont
$script:LearningWorkflowTextBox.WordWrap = $true
$script:LearningWorkflowTextBox.ScrollBars = 'Vertical'
$learningLayout.Controls.Add($script:LearningWorkflowTextBox, 0, 3)

function Update-LearningOperationText {
    try {
        $name = if ($script:LearningOperationComboBox -and $script:LearningOperationComboBox.SelectedItem) { [string]$script:LearningOperationComboBox.SelectedItem } else { 'Stage selected' }
        $text = if (Get-Command Get-GglOperationGuidance -ErrorAction SilentlyContinue) { Get-GglOperationGuidance -Name $name } else { 'Select an operation to learn what it does.' }
        if ($script:LearningOperationTextBox) { $script:LearningOperationTextBox.Text = $text }
    } catch { if ($script:LearningOperationTextBox) { $script:LearningOperationTextBox.Text = 'Learning guidance is unavailable: ' + $_.Exception.Message } }
}

function Update-LearningWorkflowText {
    try {
        $text = if (Get-Command Get-GglTypicalWorkflowGuide -ErrorAction SilentlyContinue) { Get-GglTypicalWorkflowGuide } else { 'Typical workflow: open/init repo, branch, edit, stage, commit, pull, push, merge, tag.' }
        if ($script:LearningWorkflowTextBox) { $script:LearningWorkflowTextBox.Text = $text }
    } catch { if ($script:LearningWorkflowTextBox) { $script:LearningWorkflowTextBox.Text = 'Workflow guidance is unavailable: ' + $_.Exception.Message } }
}

$script:LearningOperationComboBox.Add_SelectedIndexChanged({ Update-LearningOperationText })
$learningShowButton.Add_Click({ Update-LearningOperationText })
$learningWorkflowButton.Add_Click({ Update-LearningWorkflowText })
Update-LearningOperationText
Update-LearningWorkflowText

if ($script:ToolTip) {
    $script:ToolTip.SetToolTip($script:LearningOperationComboBox, 'Choose a Git operation to see a beginner-friendly explanation.')
    $script:ToolTip.SetToolTip($learningWorkflowButton, 'Shows a typical branch/stage/commit/sync/release workflow.')
}

# Stage actions
[void](New-ActionGuidance -ParentPanel $stageActionsPanel -Text 'Stage means choose what goes into the next commit. Use Stage selected for intentional commits; Stage all is faster but should be used only after reviewing the diff.')
[void](New-ActionButton -ParentPanel $stageActionsPanel -Text 'Stage selected' -Width 125 -Handler { Stage-SelectedFile } -PreviewBuilder { Build-StageSelectedPreview } -PreviewTitle 'Stage selected file(s)' -Notes 'Adds the selected file(s) to the Git index so they will be included in the next commit.')
[void](New-ActionButton -ParentPanel $stageActionsPanel -Text 'Unstage selected' -Width 135 -Handler { Unstage-SelectedFile } -PreviewBuilder { Build-UnstageSelectedPreview } -PreviewTitle 'Unstage selected file(s)' -Notes 'Removes the selected file(s) from the Git index while keeping your working-tree edits.')
[void](New-ActionButton -ParentPanel $stageActionsPanel -Text 'Stage all' -Width 110 -Handler { Stage-AllChanges } -PreviewBuilder { if (Get-Command Get-GggStageAllCommandPlan -ErrorAction SilentlyContinue) { ConvertTo-GggCommandPreview -Plans (Get-GggStageAllCommandPlan) } else { 'git add -A' } } -PreviewTitle 'Stage all changes' -Notes 'Stages everything in the repository.')

# Branch actions
[void](New-ActionGuidance -ParentPanel $branchActionsPanel -Text 'Branches isolate work. Create feature branches for focused changes, switch only when your working tree is clean or safely stashed, and push when ready to share.')
[void](New-ActionButton -ParentPanel $branchActionsPanel -Text 'Push current branch' -Width 145 -Handler { Push-CurrentBranch } -PreviewBuilder { Build-PushPreview } -PreviewTitle 'Push current branch' -Notes 'Pushes the current branch to origin and sets upstream if needed.')
[void](New-ActionButton -ParentPanel $branchActionsPanel -Text 'Pull current branch' -Width 145 -Handler { Pull-CurrentBranch -ConfirmBeforePull } -PreviewBuilder { Build-PullPreview } -PreviewTitle 'Pull current branch safely' -Notes 'Runs git pull --ff-only after a clean-working-tree check. This avoids surprise merge commits and gives clearer guidance when local changes are present.')

# Integrate actions
[void](New-ActionButton -ParentPanel $integrateActionsPanel -Text "Merge feature -> $($script:Config.BaseBranch)" -Width 175 -Handler { Merge-CurrentFeatureIntoDevelop } -PreviewBuilder { Build-MergeFeaturePreview } -PreviewTitle "Merge current feature into $($script:Config.BaseBranch)" -Notes 'Requires a clean working tree. You still get a confirmation dialog before execution.')
[void](New-ActionButton -ParentPanel $integrateActionsPanel -Text "$($script:Config.BaseBranch) -> $($script:Config.MainBranch)" -Width 165 -Handler { Merge-DevelopIntoMain } -PreviewBuilder { Build-MergeDevelopPreview } -PreviewTitle "Merge $($script:Config.BaseBranch) into $($script:Config.MainBranch)" -Notes 'Requires a clean working tree. You still get a confirmation dialog before execution.')

# Stash panel
$stashLayout = New-Object System.Windows.Forms.TableLayoutPanel
$stashLayout.Dock = 'Fill'
$stashLayout.ColumnCount = 1
$stashLayout.RowCount = 4
[void]$stashLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$stashLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$stashLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
[void]$stashLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
$script:StashTabPage = $stashActionsPanel.Parent
$script:StashTabPage.Controls.Clear()
$script:StashTabPage.Padding = New-Object System.Windows.Forms.Padding(6)
$stashLayout.Dock = 'Fill'
$script:StashTabPage.Controls.Add($stashLayout)

$stashHelp = New-WrappingLabel -Text 'Stash commands save unfinished work so you can switch, pull, or merge safely. Select a stash below, then inspect, apply, pop, branch, or drop it. Hover each button to see the exact Git command.' -Height 46
$stashLayout.Controls.Add($stashHelp, 0, 0)

$stashInputPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$stashInputPanel.Dock = 'Fill'
$stashInputPanel.WrapContents = $true
$stashInputPanel.AutoScroll = $true
$stashInputPanel.AutoSize = $true
$stashLayout.Controls.Add($stashInputPanel, 0, 1)

$stashLabel = New-Object System.Windows.Forms.Label
$stashLabel.Text = 'Message:'
$stashLabel.AutoSize = $true
$stashLabel.Margin = New-Object System.Windows.Forms.Padding(4, 6, 8, 6)
$stashInputPanel.Controls.Add($stashLabel)

$script:StashMessageTextBox = New-Object System.Windows.Forms.TextBox
$script:StashMessageTextBox.Width = 300
$script:StashMessageTextBox.Margin = New-Object System.Windows.Forms.Padding(4)
$stashInputPanel.Controls.Add($script:StashMessageTextBox)

$script:StashIncludeUntrackedCheckBox = New-Object System.Windows.Forms.CheckBox
$script:StashIncludeUntrackedCheckBox.Text = 'Include untracked (-u)'
$script:StashIncludeUntrackedCheckBox.AutoSize = $true
$script:StashIncludeUntrackedCheckBox.Margin = New-Object System.Windows.Forms.Padding(8, 6, 8, 6)
$stashInputPanel.Controls.Add($script:StashIncludeUntrackedCheckBox)

$script:StashKeepIndexCheckBox = New-Object System.Windows.Forms.CheckBox
$script:StashKeepIndexCheckBox.Text = 'Keep staged (--keep-index)'
$script:StashKeepIndexCheckBox.AutoSize = $true
$script:StashKeepIndexCheckBox.Margin = New-Object System.Windows.Forms.Padding(8, 6, 8, 6)
$stashInputPanel.Controls.Add($script:StashKeepIndexCheckBox)

$stashButton = New-Object System.Windows.Forms.Button
$stashButton.Text = 'Stash changes'
$stashButton.Width = 120
$stashButton.Height = 28
$stashButton.Margin = New-Object System.Windows.Forms.Padding(4)
$stashButton.Add_Click({ Stash-Changes })
$stashInputPanel.Controls.Add($stashButton)

$stashUntrackedButton = New-Object System.Windows.Forms.Button
$stashUntrackedButton.Text = 'Stash + untracked'
$stashUntrackedButton.Width = 140
$stashUntrackedButton.Height = 28
$stashUntrackedButton.Margin = New-Object System.Windows.Forms.Padding(4)
$stashUntrackedButton.Add_Click({ Stash-ChangesPreset -IncludeUntracked })
$stashInputPanel.Controls.Add($stashUntrackedButton)

$stashKeepIndexQuickButton = New-Object System.Windows.Forms.Button
$stashKeepIndexQuickButton.Text = 'Stash unstaged only'
$stashKeepIndexQuickButton.Width = 145
$stashKeepIndexQuickButton.Height = 28
$stashKeepIndexQuickButton.Margin = New-Object System.Windows.Forms.Padding(4)
$stashKeepIndexQuickButton.Add_Click({ Stash-ChangesPreset -KeepIndex })
$stashInputPanel.Controls.Add($stashKeepIndexQuickButton)

$script:StashListBox = New-Object System.Windows.Forms.ListBox
$script:StashListBox.Dock = 'Fill'
$script:StashListBox.Font = $script:FontMono
$script:StashListBox.HorizontalScrollbar = $true
$stashLayout.Controls.Add($script:StashListBox, 0, 2)

$stashButtonPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$stashButtonPanel.Dock = 'Fill'
$stashButtonPanel.WrapContents = $true
$stashButtonPanel.AutoScroll = $true
$stashButtonPanel.AutoSize = $false
$stashLayout.Controls.Add($stashButtonPanel, 0, 3)

$popStashButton = New-Object System.Windows.Forms.Button
$popStashButton.Text = 'Pop (apply + drop)'
$popStashButton.Width = 140
$popStashButton.Height = 32
$popStashButton.Margin = New-Object System.Windows.Forms.Padding(4)
$popStashButton.Add_Click({ Pop-Stash })
$stashButtonPanel.Controls.Add($popStashButton)

$applyStashButton = New-Object System.Windows.Forms.Button
$applyStashButton.Text = 'Apply (keep stash)'
$applyStashButton.Width = 140
$applyStashButton.Height = 32
$applyStashButton.Margin = New-Object System.Windows.Forms.Padding(4)
$applyStashButton.Add_Click({ Apply-Stash })
$stashButtonPanel.Controls.Add($applyStashButton)

$dropStashButton = New-Object System.Windows.Forms.Button
$dropStashButton.Text = 'Drop'
$dropStashButton.Width = 80
$dropStashButton.Height = 32
$dropStashButton.Margin = New-Object System.Windows.Forms.Padding(4)
$dropStashButton.Add_Click({ Drop-Stash })
$stashButtonPanel.Controls.Add($dropStashButton)

$refreshStashesButton = New-Object System.Windows.Forms.Button
$refreshStashesButton.Text = 'Refresh stashes'
$refreshStashesButton.Width = 125
$refreshStashesButton.Height = 32
$refreshStashesButton.Margin = New-Object System.Windows.Forms.Padding(4)
$refreshStashesButton.Add_Click({ Refresh-StashPanel })
$stashButtonPanel.Controls.Add($refreshStashesButton)

$showStashDiffButton = New-Object System.Windows.Forms.Button
$showStashDiffButton.Text = 'Show stash diff'
$showStashDiffButton.Width = 125
$showStashDiffButton.Height = 32
$showStashDiffButton.Margin = New-Object System.Windows.Forms.Padding(4)
$showStashDiffButton.Add_Click({ Show-SelectedStashDiff })
$stashButtonPanel.Controls.Add($showStashDiffButton)

$showStashFilesButton = New-Object System.Windows.Forms.Button
$showStashFilesButton.Text = 'Show stash files'
$showStashFilesButton.Width = 130
$showStashFilesButton.Height = 32
$showStashFilesButton.Margin = New-Object System.Windows.Forms.Padding(4)
$showStashFilesButton.Add_Click({ Show-SelectedStashNameStatus })
$stashButtonPanel.Controls.Add($showStashFilesButton)

$applyStashIndexButton = New-Object System.Windows.Forms.Button
$applyStashIndexButton.Text = 'Apply --index'
$applyStashIndexButton.Width = 115
$applyStashIndexButton.Height = 32
$applyStashIndexButton.Margin = New-Object System.Windows.Forms.Padding(4)
$applyStashIndexButton.Add_Click({ Apply-Stash -RestoreIndex })
$stashButtonPanel.Controls.Add($applyStashIndexButton)

$popStashIndexButton = New-Object System.Windows.Forms.Button
$popStashIndexButton.Text = 'Pop --index'
$popStashIndexButton.Width = 105
$popStashIndexButton.Height = 32
$popStashIndexButton.Margin = New-Object System.Windows.Forms.Padding(4)
$popStashIndexButton.Add_Click({ Pop-Stash -RestoreIndex })
$stashButtonPanel.Controls.Add($popStashIndexButton)

$stashBranchLabel = New-Object System.Windows.Forms.Label
$stashBranchLabel.Text = 'Branch from stash:'
$stashBranchLabel.AutoSize = $true
$stashBranchLabel.Margin = New-Object System.Windows.Forms.Padding(10, 8, 4, 4)
$stashButtonPanel.Controls.Add($stashBranchLabel)

$script:StashBranchTextBox = New-Object System.Windows.Forms.TextBox
$script:StashBranchTextBox.Width = 210
$script:StashBranchTextBox.Margin = New-Object System.Windows.Forms.Padding(4)
$script:StashBranchTextBox.Text = 'feature/recover-stash'
$stashButtonPanel.Controls.Add($script:StashBranchTextBox)

$stashBranchButton = New-Object System.Windows.Forms.Button
$stashBranchButton.Text = 'Create branch'
$stashBranchButton.Width = 120
$stashBranchButton.Height = 32
$stashBranchButton.Margin = New-Object System.Windows.Forms.Padding(4)
$stashBranchButton.Add_Click({ Create-BranchFromStash })
$stashButtonPanel.Controls.Add($stashBranchButton)

$clearStashesButton = New-Object System.Windows.Forms.Button
$clearStashesButton.Text = 'Clear all stashes'
$clearStashesButton.Width = 130
$clearStashesButton.Height = 32
$clearStashesButton.Margin = New-Object System.Windows.Forms.Padding(4)
$clearStashesButton.Add_Click({ Clear-AllStashes })
$stashButtonPanel.Controls.Add($clearStashesButton)

# Custom Git command panel
$customGitLayout = New-Object System.Windows.Forms.TableLayoutPanel
$customGitLayout.Dock = 'None'
$customGitLayout.ColumnCount = 1
$customGitLayout.RowCount = 5
[void]$customGitLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$customGitLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$customGitLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$customGitLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 50)))
[void]$customGitLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 50)))
$script:CustomGitTabPage = $customGitActionsPanel.Parent
$script:CustomGitTabPage.Controls.Clear()
$script:CustomGitTabPage.Padding = New-Object System.Windows.Forms.Padding(6)
$customGitLayout.Dock = 'Fill'
$script:CustomGitTabPage.Controls.Add($customGitLayout)

$customGitHelp = New-WrappingLabel -Text 'Create reusable Git buttons: type a label, type Git arguments, then click Save as new button. Use New blank draft to start from scratch or Add recommended buttons to seed useful commands. The leading git word is optional; shell operators are intentionally blocked for safety.' -Height 58
$customGitLayout.Controls.Add($customGitHelp, 0, 0)

$customGitInput = New-Object System.Windows.Forms.TableLayoutPanel
$customGitInput.Dock = 'Fill'
$customGitInput.ColumnCount = 4
$customGitInput.RowCount = 2
[void]$customGitInput.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$customGitInput.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 40)))
[void]$customGitInput.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$customGitInput.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 60)))
$customGitLayout.Controls.Add($customGitInput, 0, 1)

$customLabelLabel = New-Object System.Windows.Forms.Label
$customLabelLabel.Text = 'Button label:'
$customLabelLabel.AutoSize = $true
$customLabelLabel.Margin = New-Object System.Windows.Forms.Padding(4, 6, 8, 6)
$customGitInput.Controls.Add($customLabelLabel, 0, 0)

$script:CustomGitLabelTextBox = New-Object System.Windows.Forms.TextBox
$script:CustomGitLabelTextBox.Dock = 'Fill'
$script:CustomGitLabelTextBox.Text = 'My git command'
$script:CustomGitLabelTextBox.Margin = New-Object System.Windows.Forms.Padding(4)
$customGitInput.Controls.Add($script:CustomGitLabelTextBox, 1, 0)

$customCommandLabel = New-Object System.Windows.Forms.Label
$customCommandLabel.Text = 'Git arguments:'
$customCommandLabel.AutoSize = $true
$customCommandLabel.Margin = New-Object System.Windows.Forms.Padding(4, 6, 8, 6)
$customGitInput.Controls.Add($customCommandLabel, 2, 0)

$script:CustomGitCommandTextBox = New-Object System.Windows.Forms.TextBox
$script:CustomGitCommandTextBox.Dock = 'Fill'
$script:CustomGitCommandTextBox.Text = 'status -sb'
$script:CustomGitCommandTextBox.Margin = New-Object System.Windows.Forms.Padding(4)
$customGitInput.Controls.Add($script:CustomGitCommandTextBox, 3, 0)

$customGitButtonRow = New-Object System.Windows.Forms.FlowLayoutPanel
$customGitButtonRow.Dock = 'Fill'
$customGitButtonRow.WrapContents = $true
$customGitLayout.Controls.Add($customGitButtonRow, 0, 2)

$runCustomGitButton = New-Object System.Windows.Forms.Button
$runCustomGitButton.Text = 'Run typed command'
$runCustomGitButton.Width = 145
$runCustomGitButton.Height = 32
$runCustomGitButton.Margin = New-Object System.Windows.Forms.Padding(4)
$runCustomGitButton.Add_Click({ Run-CustomGitCommand -CommandText $script:CustomGitCommandTextBox.Text })
$customGitButtonRow.Controls.Add($runCustomGitButton)

$addCustomGitButton = New-Object System.Windows.Forms.Button
$addCustomGitButton.Text = 'Save as new button'
$addCustomGitButton.Width = 145
$addCustomGitButton.Height = 32
$addCustomGitButton.Margin = New-Object System.Windows.Forms.Padding(4)
$addCustomGitButton.Add_Click({ Add-CustomGitButtonFromFields })
$customGitButtonRow.Controls.Add($addCustomGitButton)

$updateCustomGitButton = New-Object System.Windows.Forms.Button
$updateCustomGitButton.Text = 'Update selected'
$updateCustomGitButton.Width = 135
$updateCustomGitButton.Height = 32
$updateCustomGitButton.Margin = New-Object System.Windows.Forms.Padding(4)
$updateCustomGitButton.Add_Click({ Update-SelectedCustomGitButtonFromFields })
$customGitButtonRow.Controls.Add($updateCustomGitButton)

$removeCustomGitButton = New-Object System.Windows.Forms.Button
$removeCustomGitButton.Text = 'Remove selected button'
$removeCustomGitButton.Width = 165
$removeCustomGitButton.Height = 32
$removeCustomGitButton.Margin = New-Object System.Windows.Forms.Padding(4)
$removeCustomGitButton.Add_Click({ Remove-SelectedCustomGitButton })
$customGitButtonRow.Controls.Add($removeCustomGitButton)

$newCustomGitDraftButton = New-Object System.Windows.Forms.Button
$newCustomGitDraftButton.Text = 'New blank draft'
$newCustomGitDraftButton.Width = 130
$newCustomGitDraftButton.Height = 32
$newCustomGitDraftButton.Margin = New-Object System.Windows.Forms.Padding(4)
$newCustomGitDraftButton.Add_Click({ New-CustomGitButtonDraft })
$customGitButtonRow.Controls.Add($newCustomGitDraftButton)

$addRecommendedCustomGitButton = New-Object System.Windows.Forms.Button
$addRecommendedCustomGitButton.Text = 'Add recommended buttons'
$addRecommendedCustomGitButton.Width = 175
$addRecommendedCustomGitButton.Height = 32
$addRecommendedCustomGitButton.Margin = New-Object System.Windows.Forms.Padding(4)
$addRecommendedCustomGitButton.Add_Click({ Add-RecommendedCustomGitButtons })
$customGitButtonRow.Controls.Add($addRecommendedCustomGitButton)

$script:CustomGitButtonsPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$script:CustomGitButtonsPanel.Dock = 'Fill'
$script:CustomGitButtonsPanel.WrapContents = $true
$script:CustomGitButtonsPanel.AutoScroll = $true
$customGitLayout.Controls.Add($script:CustomGitButtonsPanel, 0, 3)

$script:CustomGitButtonsListBox = New-Object System.Windows.Forms.ListBox
$script:CustomGitButtonsListBox.Dock = 'Fill'
$script:CustomGitButtonsListBox.Font = $script:FontMono
$script:CustomGitButtonsListBox.HorizontalScrollbar = $true
$script:CustomGitButtonsListBox.Add_DoubleClick({
    $idx = [int]$script:CustomGitButtonsListBox.SelectedIndex
    $defs = @($script:CustomGitButtons)
    if ($idx -ge 0 -and $idx -lt $defs.Count) { Run-CustomGitCommand -CommandText ([string]$defs[$idx].Arguments) }
})
$customGitLayout.Controls.Add($script:CustomGitButtonsListBox, 0, 4)

# Appearance / theme panel
$appearanceLayout = New-Object System.Windows.Forms.TableLayoutPanel
$appearanceLayout.Dock = 'None'
$appearanceLayout.ColumnCount = 1
$appearanceLayout.RowCount = 4
[void]$appearanceLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$appearanceLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
[void]$appearanceLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$appearanceLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
$script:AppearanceTabPage = $appearanceActionsPanel.Parent
$script:AppearanceTabPage.Controls.Clear()
$script:AppearanceTabPage.Padding = New-Object System.Windows.Forms.Padding(6)
$appearanceLayout.Dock = 'Fill'
$script:AppearanceTabPage.Controls.Add($appearanceLayout)

$appearanceHelp = New-WrappingLabel -Text 'Pick colors for each GUI section. Select a row, choose a color or type #RRGGBB, then apply. Drag the visible splitter between the color list and editor to adjust this tab. Colors and layout are saved to GitGlideGUI-Config.json and restored next session.' -Height 54
$appearanceLayout.Controls.Add($appearanceHelp, 0, 0)

$appearanceMainSplit = New-Object System.Windows.Forms.SplitContainer
$script:AppearanceMainSplit = $appearanceMainSplit
$appearanceMainSplit.Dock = 'Fill'
$appearanceMainSplit.Orientation = 'Vertical'
$appearanceMainSplit.SplitterWidth = 9
# Keep construction-time minimums conservative. WinForms validates Panel2MinSize
# against the current temporary width before docking/layout has finished; larger
# values can crash startup on some screens or DPI settings. The saved splitter
# distance still gives the Appearance editor a comfortable default once shown.
$appearanceMainSplit.Panel1MinSize = 25
$appearanceMainSplit.Panel2MinSize = 25
$appearanceLayout.Controls.Add($appearanceMainSplit, 0, 1)

$script:ThemeColorListBox = New-Object System.Windows.Forms.ListBox
$script:ThemeColorListBox.Dock = 'Fill'
$script:ThemeColorListBox.Font = $script:FontMono
$script:ThemeColorListBox.HorizontalScrollbar = $true
$script:ThemeColorListBox.Add_SelectedIndexChanged({ Update-ThemeEditorSelection })
$appearanceMainSplit.Panel1.Controls.Add($script:ThemeColorListBox)

$themeDetailsLayout = New-Object System.Windows.Forms.TableLayoutPanel
$themeDetailsLayout.Dock = 'Fill'
$themeDetailsLayout.ColumnCount = 2
$themeDetailsLayout.RowCount = 5
[void]$themeDetailsLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$themeDetailsLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
[void]$themeDetailsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$themeDetailsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$themeDetailsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$themeDetailsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$themeDetailsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$appearanceMainSplit.Panel2.Controls.Add($themeDetailsLayout)

$script:ThemeSelectedLabel = New-WrappingLabel -Text 'Selected color' -Height 34 -Bold $true
$themeDetailsLayout.Controls.Add($script:ThemeSelectedLabel, 0, 0)
$themeDetailsLayout.SetColumnSpan($script:ThemeSelectedLabel, 2)

$themeHexLabel = New-Object System.Windows.Forms.Label
$themeHexLabel.Text = 'Hex color:'
$themeHexLabel.AutoSize = $true
$themeHexLabel.Margin = New-Object System.Windows.Forms.Padding(4, 7, 8, 6)
$themeDetailsLayout.Controls.Add($themeHexLabel, 0, 1)

$script:ThemeHexTextBox = New-Object System.Windows.Forms.TextBox
$script:ThemeHexTextBox.Dock = 'Fill'
$script:ThemeHexTextBox.Margin = New-Object System.Windows.Forms.Padding(4)
$themeDetailsLayout.Controls.Add($script:ThemeHexTextBox, 1, 1)

$themeSwatchLabel = New-Object System.Windows.Forms.Label
$themeSwatchLabel.Text = 'Current:'
$themeSwatchLabel.AutoSize = $true
$themeSwatchLabel.Margin = New-Object System.Windows.Forms.Padding(4, 7, 8, 6)
$themeDetailsLayout.Controls.Add($themeSwatchLabel, 0, 2)

$script:ThemeCurrentColorPanel = New-Object System.Windows.Forms.Panel
$script:ThemeCurrentColorPanel.Height = 32
$script:ThemeCurrentColorPanel.Dock = 'Top'
$script:ThemeCurrentColorPanel.BorderStyle = 'FixedSingle'
$script:ThemeCurrentColorPanel.Margin = New-Object System.Windows.Forms.Padding(4)
$themeDetailsLayout.Controls.Add($script:ThemeCurrentColorPanel, 1, 2)

$themeButtonRow = New-Object System.Windows.Forms.FlowLayoutPanel
$themeButtonRow.Dock = 'Fill'
$themeButtonRow.WrapContents = $true
$themeDetailsLayout.Controls.Add($themeButtonRow, 0, 3)
$themeDetailsLayout.SetColumnSpan($themeButtonRow, 2)

$chooseThemeColorButton = New-Object System.Windows.Forms.Button
$chooseThemeColorButton.Text = 'Choose color...'
$chooseThemeColorButton.Width = 125
$chooseThemeColorButton.Height = 32
$chooseThemeColorButton.Margin = New-Object System.Windows.Forms.Padding(4)
$chooseThemeColorButton.Add_Click({ Choose-SelectedThemeColor })
$themeButtonRow.Controls.Add($chooseThemeColorButton)

$applyThemeHexButton = New-Object System.Windows.Forms.Button
$applyThemeHexButton.Text = 'Apply hex'
$applyThemeHexButton.Width = 95
$applyThemeHexButton.Height = 32
$applyThemeHexButton.Margin = New-Object System.Windows.Forms.Padding(4)
$applyThemeHexButton.Add_Click({ Apply-ThemeHexFromEditor })
$themeButtonRow.Controls.Add($applyThemeHexButton)

$resetSelectedThemeButton = New-Object System.Windows.Forms.Button
$resetSelectedThemeButton.Text = 'Reset selected'
$resetSelectedThemeButton.Width = 120
$resetSelectedThemeButton.Height = 32
$resetSelectedThemeButton.Margin = New-Object System.Windows.Forms.Padding(4)
$resetSelectedThemeButton.Add_Click({ Reset-SelectedThemeColor })
$themeButtonRow.Controls.Add($resetSelectedThemeButton)

$resetAllThemeButton = New-Object System.Windows.Forms.Button
$resetAllThemeButton.Text = 'Reset all colors'
$resetAllThemeButton.Width = 125
$resetAllThemeButton.Height = 32
$resetAllThemeButton.Margin = New-Object System.Windows.Forms.Padding(4)
$resetAllThemeButton.Add_Click({ Reset-AllThemeColors })
$themeButtonRow.Controls.Add($resetAllThemeButton)

$applyThemeNowButton = New-Object System.Windows.Forms.Button
$applyThemeNowButton.Text = 'Apply now'
$applyThemeNowButton.Width = 95
$applyThemeNowButton.Height = 32
$applyThemeNowButton.Margin = New-Object System.Windows.Forms.Padding(4)
$applyThemeNowButton.Add_Click({ Apply-Theme })
$themeButtonRow.Controls.Add($applyThemeNowButton)

$script:ThemePreviewPanel = New-Object System.Windows.Forms.Panel
$script:ThemePreviewPanel.Dock = 'Fill'
$script:ThemePreviewPanel.BorderStyle = 'FixedSingle'
$script:ThemePreviewPanel.Margin = New-Object System.Windows.Forms.Padding(4)
$themeDetailsLayout.Controls.Add($script:ThemePreviewPanel, 0, 4)
$themeDetailsLayout.SetColumnSpan($script:ThemePreviewPanel, 2)

$themePreviewLabel = New-Object System.Windows.Forms.Label
$themePreviewLabel.Text = 'Accent preview: this panel uses Accent background/text. Buttons, lists, text fields, splitters, sections, diff, log, preview, help and status bar can each be customized above.'
$themePreviewLabel.Dock = 'Fill'
$themePreviewLabel.AutoSize = $false
$themePreviewLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$themePreviewLabel.Padding = New-Object System.Windows.Forms.Padding(10)
$script:ThemePreviewPanel.Controls.Add($themePreviewLabel)

$themePersistenceLabel = New-WrappingLabel -Text 'Saved color settings live in the ThemeColors object inside GitGlideGUI-Config.json. Delete that object or use Reset all colors to return to defaults.' -Height 42
$appearanceLayout.Controls.Add($themePersistenceLabel, 0, 2)


# Tags / Release panel
$script:TagsTabPage = $tagsActionsPanel.Parent
$script:TagsTabPage.Controls.Clear()
$script:TagsTabPage.Padding = New-Object System.Windows.Forms.Padding(6)

$tagsLayout = New-Object System.Windows.Forms.TableLayoutPanel
$tagsLayout.Dock = 'Fill'
$tagsLayout.ColumnCount = 1
$tagsLayout.RowCount = 4
[void]$tagsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$tagsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$tagsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 55)))
[void]$tagsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 45)))
$script:TagsTabPage.Controls.Add($tagsLayout)

$tagsHelp = New-WrappingLabel -Text 'Release tags mark stable states. Create annotated tags for releases, inspect tags before checkout, push deliberately, and delete only with confirmation.' -Height 44
$tagsLayout.Controls.Add($tagsHelp, 0, 0)

$tagInputPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$tagInputPanel.Dock = 'Fill'
$tagInputPanel.WrapContents = $true
$tagInputPanel.AutoScroll = $true
$tagInputPanel.AutoSize = $true
$tagsLayout.Controls.Add($tagInputPanel, 0, 1)

$tagNameLabel = New-Object System.Windows.Forms.Label
$tagNameLabel.Text = 'Tag:'
$tagNameLabel.AutoSize = $true
$tagNameLabel.Margin = New-Object System.Windows.Forms.Padding(4, 8, 4, 4)
$tagInputPanel.Controls.Add($tagNameLabel)

$script:TagNameTextBox = New-Object System.Windows.Forms.TextBox
$script:TagNameTextBox.Width = 145
$script:TagNameTextBox.Margin = New-Object System.Windows.Forms.Padding(4)
$script:TagNameTextBox.Text = 'v'
$tagInputPanel.Controls.Add($script:TagNameTextBox)

$tagMessageLabel = New-Object System.Windows.Forms.Label
$tagMessageLabel.Text = 'Message:'
$tagMessageLabel.AutoSize = $true
$tagMessageLabel.Margin = New-Object System.Windows.Forms.Padding(8, 8, 4, 4)
$tagInputPanel.Controls.Add($tagMessageLabel)

$script:TagMessageTextBox = New-Object System.Windows.Forms.TextBox
$script:TagMessageTextBox.Width = 260
$script:TagMessageTextBox.Margin = New-Object System.Windows.Forms.Padding(4)
$tagInputPanel.Controls.Add($script:TagMessageTextBox)

$script:TagAnnotatedCheckBox = New-Object System.Windows.Forms.CheckBox
$script:TagAnnotatedCheckBox.Text = 'Annotated (-a)'
$script:TagAnnotatedCheckBox.Checked = $true
$script:TagAnnotatedCheckBox.AutoSize = $true
$script:TagAnnotatedCheckBox.Margin = New-Object System.Windows.Forms.Padding(8, 7, 4, 4)
$tagInputPanel.Controls.Add($script:TagAnnotatedCheckBox)

$script:TagPushAfterCreateCheckBox = New-Object System.Windows.Forms.CheckBox
$script:TagPushAfterCreateCheckBox.Text = 'Push after create'
$script:TagPushAfterCreateCheckBox.AutoSize = $true
$script:TagPushAfterCreateCheckBox.Margin = New-Object System.Windows.Forms.Padding(8, 7, 4, 4)
$tagInputPanel.Controls.Add($script:TagPushAfterCreateCheckBox)

$createTagButton = New-Object System.Windows.Forms.Button
$createTagButton.Text = 'Create tag'
$createTagButton.Width = 105
$createTagButton.Height = 30
$createTagButton.Margin = New-Object System.Windows.Forms.Padding(4)
$createTagButton.Add_Click({ Create-GitFlowTag })
$tagInputPanel.Controls.Add($createTagButton)

$refreshTagsButton = New-Object System.Windows.Forms.Button
$refreshTagsButton.Text = 'Refresh tags'
$refreshTagsButton.Width = 110
$refreshTagsButton.Height = 30
$refreshTagsButton.Margin = New-Object System.Windows.Forms.Padding(4)
$refreshTagsButton.Add_Click({ Load-TagList })
$tagInputPanel.Controls.Add($refreshTagsButton)

$tagMainPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$tagMainPanel.Dock = 'Fill'
$tagMainPanel.WrapContents = $true
$tagMainPanel.AutoScroll = $true
$tagsLayout.Controls.Add($tagMainPanel, 0, 2)

$script:TagListBox = New-Object System.Windows.Forms.ListBox
$script:TagListBox.Width = 470
$script:TagListBox.Height = 160
$script:TagListBox.Font = $script:FontMono
$script:TagListBox.HorizontalScrollbar = $true
$script:TagListBox.Margin = New-Object System.Windows.Forms.Padding(4)
$tagMainPanel.Controls.Add($script:TagListBox)

$tagButtonPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$tagButtonPanel.Width = 470
$tagButtonPanel.Height = 160
$tagButtonPanel.WrapContents = $true
$tagButtonPanel.AutoScroll = $true
$tagButtonPanel.Margin = New-Object System.Windows.Forms.Padding(4)
$tagMainPanel.Controls.Add($tagButtonPanel)

$showTagButton = New-Object System.Windows.Forms.Button
$showTagButton.Text = 'Show details'
$showTagButton.Width = 115
$showTagButton.Height = 30
$showTagButton.Margin = New-Object System.Windows.Forms.Padding(4)
$showTagButton.Add_Click({ Show-SelectedTagDetails })
$tagButtonPanel.Controls.Add($showTagButton)

$pushTagButton = New-Object System.Windows.Forms.Button
$pushTagButton.Text = 'Push selected'
$pushTagButton.Width = 115
$pushTagButton.Height = 30
$pushTagButton.Margin = New-Object System.Windows.Forms.Padding(4)
$pushTagButton.Add_Click({ Push-SelectedOrNamedTag })
$tagButtonPanel.Controls.Add($pushTagButton)

$pushAllTagsButton = New-Object System.Windows.Forms.Button
$pushAllTagsButton.Text = 'Push all tags'
$pushAllTagsButton.Width = 115
$pushAllTagsButton.Height = 30
$pushAllTagsButton.Margin = New-Object System.Windows.Forms.Padding(4)
$pushAllTagsButton.Add_Click({ Push-AllTags })
$tagButtonPanel.Controls.Add($pushAllTagsButton)

$deleteTagButton = New-Object System.Windows.Forms.Button
$deleteTagButton.Text = 'Delete selected'
$deleteTagButton.Width = 120
$deleteTagButton.Height = 30
$deleteTagButton.Margin = New-Object System.Windows.Forms.Padding(4)
$deleteTagButton.Add_Click({ Delete-SelectedTag })
$tagButtonPanel.Controls.Add($deleteTagButton)

$script:TagDeleteRemoteCheckBox = New-Object System.Windows.Forms.CheckBox
$script:TagDeleteRemoteCheckBox.Text = 'Also delete remote tag'
$script:TagDeleteRemoteCheckBox.AutoSize = $true
$script:TagDeleteRemoteCheckBox.Margin = New-Object System.Windows.Forms.Padding(8, 8, 4, 4)
$tagButtonPanel.Controls.Add($script:TagDeleteRemoteCheckBox)

$tagBranchLabel = New-Object System.Windows.Forms.Label
$tagBranchLabel.Text = 'Branch from tag:'
$tagBranchLabel.AutoSize = $true
$tagBranchLabel.Margin = New-Object System.Windows.Forms.Padding(4, 10, 4, 4)
$tagButtonPanel.Controls.Add($tagBranchLabel)

$script:TagBranchTextBox = New-Object System.Windows.Forms.TextBox
$script:TagBranchTextBox.Width = 190
$script:TagBranchTextBox.Margin = New-Object System.Windows.Forms.Padding(4)
$script:TagBranchTextBox.Text = 'release/from-tag'
$tagButtonPanel.Controls.Add($script:TagBranchTextBox)

$checkoutTagButton = New-Object System.Windows.Forms.Button
$checkoutTagButton.Text = 'Checkout / branch'
$checkoutTagButton.Width = 130
$checkoutTagButton.Height = 30
$checkoutTagButton.Margin = New-Object System.Windows.Forms.Padding(4)
$checkoutTagButton.Add_Click({ Checkout-SelectedTag })
$tagButtonPanel.Controls.Add($checkoutTagButton)

$script:TagDetailsTextBox = New-Object System.Windows.Forms.TextBox
$script:TagDetailsTextBox.Multiline = $true
$script:TagDetailsTextBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
$script:TagDetailsTextBox.WordWrap = $false
$script:TagDetailsTextBox.Dock = 'Fill'
$script:TagDetailsTextBox.Font = $script:FontMono
$script:TagDetailsTextBox.ReadOnly = $true
$tagsLayout.Controls.Add($script:TagDetailsTextBox, 0, 3)

# Commit/Preview group
$commitPreviewGroup = New-Object System.Windows.Forms.GroupBox
$commitPreviewGroup.Text = 'Commit / preview / help'
$commitPreviewGroup.Dock = 'Fill'
$commitPreviewGroup.AutoSize = $false
$commitPreviewGroup.Padding = New-Object System.Windows.Forms.Padding(10)
$topSplit.Panel2.Controls.Add($commitPreviewGroup)
$script:CommitPreviewGroup = $commitPreviewGroup

$commitPreviewSplit = New-Object System.Windows.Forms.SplitContainer
$script:CommitPreviewSplit = $commitPreviewSplit
$commitPreviewSplit.Dock = 'Fill'
$commitPreviewSplit.Orientation = 'Vertical'
$commitPreviewSplit.SplitterWidth = 9
$commitPreviewSplit.Panel1MinSize = 25
$commitPreviewSplit.Panel2MinSize = 25
$commitPreviewGroup.Controls.Add($commitPreviewSplit)

# Commit group
$commitGroup = New-Object System.Windows.Forms.GroupBox
$commitGroup.Text = 'Commit'
$commitGroup.Dock = 'Fill'
$commitGroup.Padding = New-Object System.Windows.Forms.Padding(10)
$commitPreviewSplit.Panel1.Controls.Add($commitGroup)

$commitLayout = New-Object System.Windows.Forms.TableLayoutPanel
$commitLayout.Dock = 'Fill'
$commitLayout.ColumnCount = 4
$commitLayout.RowCount = 7
$commitLayout.AutoSize = $true
[void]$commitLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$commitLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
[void]$commitLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$commitLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize)))
$commitGroup.Controls.Add($commitLayout)

$commitTemplateLabel = New-Object System.Windows.Forms.Label
$commitTemplateLabel.Text = 'Template:'
$commitTemplateLabel.AutoSize = $true
$commitTemplateLabel.Margin = New-Object System.Windows.Forms.Padding(4, 6, 8, 6)
$commitLayout.Controls.Add($commitTemplateLabel, 0, 0)

$script:CommitTemplateComboBox = New-Object System.Windows.Forms.ComboBox
$script:CommitTemplateComboBox.DropDownStyle = 'DropDownList'
[void]$script:CommitTemplateComboBox.Items.AddRange(@('Custom','Feature','Hotfix','Release','Refactor','Docs','Test'))
$script:CommitTemplateComboBox.SelectedIndex = 0
$script:CommitTemplateComboBox.Margin = New-Object System.Windows.Forms.Padding(4)
$commitLayout.Controls.Add($script:CommitTemplateComboBox, 1, 0)

$insertTemplateButton = New-Object System.Windows.Forms.Button
$insertTemplateButton.Text = 'Insert example'
$insertTemplateButton.Width = 120
$insertTemplateButton.Height = 30
$insertTemplateButton.Margin = New-Object System.Windows.Forms.Padding(4)
$insertTemplateButton.Add_Click({ Insert-CommitTemplate })
$commitLayout.Controls.Add($insertTemplateButton, 2, 0)

$copyPreviewButton = New-Object System.Windows.Forms.Button
$copyPreviewButton.Text = 'Copy preview'
$copyPreviewButton.Width = 110
$copyPreviewButton.Height = 30
$copyPreviewButton.Margin = New-Object System.Windows.Forms.Padding(4)
$copyPreviewButton.Add_Click({ 
    if ($script:PreviewTextBox.TextLength -gt 0) { 
        [System.Windows.Forms.Clipboard]::SetText($script:PreviewTextBox.Text) 
    } 
})
$commitLayout.Controls.Add($copyPreviewButton, 3, 0)

$commitSubjectLabel = New-Object System.Windows.Forms.Label
$commitSubjectLabel.Text = 'Subject:'
$commitSubjectLabel.AutoSize = $true
$commitSubjectLabel.Margin = New-Object System.Windows.Forms.Padding(4, 6, 8, 6)
$commitLayout.Controls.Add($commitSubjectLabel, 0, 1)

$script:CommitSubjectTextBox = New-Object System.Windows.Forms.TextBox
$script:CommitSubjectTextBox.Dock = 'Fill'
$script:CommitSubjectTextBox.Margin = New-Object System.Windows.Forms.Padding(4)
$commitLayout.Controls.Add($script:CommitSubjectTextBox, 1, 1)
$commitLayout.SetColumnSpan($script:CommitSubjectTextBox, 3)

$commitBodyLabel = New-Object System.Windows.Forms.Label
$commitBodyLabel.Text = 'Body:'
$commitBodyLabel.AutoSize = $true
$commitBodyLabel.Margin = New-Object System.Windows.Forms.Padding(4, 6, 8, 6)
$commitLayout.Controls.Add($commitBodyLabel, 0, 2)

$script:CommitBodyTextBox = New-Object System.Windows.Forms.RichTextBox
$script:CommitBodyTextBox.Dock = 'Fill'
$script:CommitBodyTextBox.Height = 120
$script:CommitBodyTextBox.Margin = New-Object System.Windows.Forms.Padding(4)
$script:CommitBodyTextBox.Font = $script:FontMono
$script:CommitBodyTextBox.WordWrap = $true
$script:CommitBodyTextBox.AcceptsTab = $true
$commitLayout.Controls.Add($script:CommitBodyTextBox, 1, 2)
$commitLayout.SetColumnSpan($script:CommitBodyTextBox, 3)

$script:CommitStageAllCheckBox = New-Object System.Windows.Forms.CheckBox
$script:CommitStageAllCheckBox.Text = 'Stage all before commit'
$script:CommitStageAllCheckBox.AutoSize = $true
$script:CommitStageAllCheckBox.Checked = $script:Config.AutoStageAll
$script:CommitStageAllCheckBox.Margin = New-Object System.Windows.Forms.Padding(4, 6, 12, 6)
$commitLayout.Controls.Add($script:CommitStageAllCheckBox, 1, 3)

$script:CommitAmendCheckBox = New-Object System.Windows.Forms.CheckBox
$script:CommitAmendCheckBox.Text = 'Amend last commit'
$script:CommitAmendCheckBox.AutoSize = $true
$script:CommitAmendCheckBox.Margin = New-Object System.Windows.Forms.Padding(4, 6, 12, 6)
$commitLayout.Controls.Add($script:CommitAmendCheckBox, 2, 3)

$script:CommitPushAfterCheckBox = New-Object System.Windows.Forms.CheckBox
$script:CommitPushAfterCheckBox.Text = 'Push after commit'
$script:CommitPushAfterCheckBox.AutoSize = $true
$script:CommitPushAfterCheckBox.Checked = $script:Config.AutoPushAfterCommit
$script:CommitPushAfterCheckBox.Margin = New-Object System.Windows.Forms.Padding(4, 6, 12, 6)
$commitLayout.Controls.Add($script:CommitPushAfterCheckBox, 3, 3)

$script:CommitConventionalGuidanceCheckBox = New-Object System.Windows.Forms.CheckBox
$script:CommitConventionalGuidanceCheckBox.Text = 'Conventional guidance'
$script:CommitConventionalGuidanceCheckBox.AutoSize = $true
$script:CommitConventionalGuidanceCheckBox.Checked = [bool]$script:Config.ConventionalCommitGuidanceEnabled
$script:CommitConventionalGuidanceCheckBox.Margin = New-Object System.Windows.Forms.Padding(4, 6, 12, 6)
$commitLayout.Controls.Add($script:CommitConventionalGuidanceCheckBox, 1, 4)

$commitHintLabel = New-WrappingLabel -Text "Subject max: $($script:Config.CommitSubjectMaxLength) chars. Amend + Push uses force-with-lease. Optional Conventional guidance checks type(scope): subject style." -Height 34
$commitLayout.Controls.Add($commitHintLabel, 1, 5)
$commitLayout.SetColumnSpan($commitHintLabel, 3)

$commitButtonsPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$commitButtonsPanel.Dock = 'Fill'
$commitButtonsPanel.WrapContents = $true
$commitLayout.Controls.Add($commitButtonsPanel, 1, 6)
$commitLayout.SetColumnSpan($commitButtonsPanel, 3)

$commitButton = New-Object System.Windows.Forms.Button
$commitButton.Text = 'Commit'
$commitButton.Width = 110
$commitButton.Height = 32
$commitButton.Margin = New-Object System.Windows.Forms.Padding(4)
$commitButton.Add_Click({ Commit-Changes })
$commitButtonsPanel.Controls.Add($commitButton)

$commitPushButton = New-Object System.Windows.Forms.Button
$commitPushButton.Text = 'Commit + Push'
$commitPushButton.Width = 130
$commitPushButton.Height = 32
$commitPushButton.Margin = New-Object System.Windows.Forms.Padding(4)
$commitPushButton.Add_Click({ Commit-Changes -PushAfterOverride })
$commitButtonsPanel.Controls.Add($commitPushButton)

# Preview/Help tabs
$previewHelpTabs = New-Object System.Windows.Forms.TabControl
$previewHelpTabs.Dock = 'Fill'
$commitPreviewSplit.Panel2.Controls.Add($previewHelpTabs)

$previewTab = New-Object System.Windows.Forms.TabPage
$previewTab.Text = 'Command preview'
$previewHelpTabs.TabPages.Add($previewTab)

$previewLayout = New-Object System.Windows.Forms.TableLayoutPanel
$previewLayout.Dock = 'Fill'
$previewLayout.ColumnCount = 1
$previewLayout.RowCount = 2
[void]$previewLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
[void]$previewLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
$previewTab.Controls.Add($previewLayout)

$script:PreviewTextBox = New-Object System.Windows.Forms.RichTextBox
$script:PreviewTextBox.Dock = 'Fill'
$script:PreviewTextBox.ReadOnly = $true
$script:PreviewTextBox.WordWrap = $false
$script:PreviewTextBox.Font = $script:FontMono
$script:PreviewTextBox.BackColor = [System.Drawing.Color]::White
$previewLayout.Controls.Add($script:PreviewTextBox, 0, 0)

$previewButtons = New-Object System.Windows.Forms.FlowLayoutPanel
$previewButtons.Dock = 'Fill'
$previewLayout.Controls.Add($previewButtons, 0, 1)

$copyLastCommandButton = New-Object System.Windows.Forms.Button
$copyLastCommandButton.Text = 'Copy last command'
$copyLastCommandButton.Width = 140
$copyLastCommandButton.Height = 30
$copyLastCommandButton.Margin = New-Object System.Windows.Forms.Padding(4)
$copyLastCommandButton.Add_Click({ Copy-LastCommand })
$previewButtons.Controls.Add($copyLastCommandButton)

$helpTab = New-Object System.Windows.Forms.TabPage
$helpTab.Text = 'Help / examples'
$previewHelpTabs.TabPages.Add($helpTab)

$script:HelpTextBox = New-Object System.Windows.Forms.RichTextBox
$script:HelpTextBox.Dock = 'Fill'
$script:HelpTextBox.ReadOnly = $true
$script:HelpTextBox.WordWrap = $true
$script:HelpTextBox.Font = $script:UiFont
$script:HelpTextBox.BackColor = [System.Drawing.Color]::White
$helpTab.Controls.Add($script:HelpTextBox)

# Main content split
$contentSplit = New-Object System.Windows.Forms.SplitContainer
$script:ContentSplit = $contentSplit
$contentSplit.Dock = 'Fill'
$contentSplit.Orientation = 'Vertical'
$contentSplit.SplitterWidth = 9
$contentSplit.Panel1MinSize = 25
$contentSplit.Panel2MinSize = 25
$mainWorkSplit.Panel2.Controls.Add($contentSplit)

# Changed files group
$leftGroup = New-Object System.Windows.Forms.GroupBox
$leftGroup.Text = 'Changed files'
$leftGroup.Dock = 'Fill'
$leftGroup.Padding = New-Object System.Windows.Forms.Padding(10)
$contentSplit.Panel1.Controls.Add($leftGroup)
$script:ChangedFilesGroup = $leftGroup

$leftActionSplit = New-Object System.Windows.Forms.SplitContainer
$script:ChangedFilesActionSplit = $leftActionSplit
$leftActionSplit.Dock = 'Fill'
$leftActionSplit.Orientation = 'Horizontal'
$leftActionSplit.SplitterWidth = 9
$leftActionSplit.Panel1MinSize = 25
$leftActionSplit.Panel2MinSize = 45
$leftGroup.Controls.Add($leftActionSplit)

$script:ChangedFilesList = New-Object System.Windows.Forms.ListBox
$script:ChangedFilesList.Dock = 'Fill'
$script:ChangedFilesList.Font = $script:FontMono
$script:ChangedFilesList.HorizontalScrollbar = $true
$script:ChangedFilesList.SelectionMode = 'MultiExtended'
$script:ChangedFilesList.DisplayMember = 'Display'
$script:ChangedFilesList.ValueMember = 'Path'
$script:ChangedFilesList.Add_DoubleClick({ Show-SelectedDiff })
$script:ChangedFilesList.Add_SelectedIndexChanged({
    if (-not $script:SuppressDiffPreview) {
        if (Get-ConfigBool -Name 'AutoPreviewDiffOnSelection' -DefaultValue $true) {
            Show-SelectedDiff
        }
        Set-CommandPreview -Title 'Selected file diff preview' -Commands (Build-ShowDiffPreview) -Notes 'Use Stage selected or Unstage selected to move this file between index and working tree.'
    }
})
$leftActionSplit.Panel1.Controls.Add($script:ChangedFilesList)

$leftActionsLayout = New-Object System.Windows.Forms.TableLayoutPanel
$leftActionsLayout.Dock = 'Fill'
$script:LeftActionsLayout = $leftActionsLayout
$leftActionsLayout.ColumnCount = 1
$leftActionsLayout.RowCount = 2
[void]$leftActionsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 45)))
[void]$leftActionsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 55)))
$leftActionSplit.Panel2.Controls.Add($leftActionsLayout)

$leftHintLabel = New-WrappingLabel -Text 'Select a file to preview its diff automatically, or click Show diff. Multi-select is for stage/unstage; the diff preview uses the first selected file. Drag this splitter to give more room to files or buttons.' -Height 48
$leftActionsLayout.Controls.Add($leftHintLabel, 0, 0)

$leftButtons = New-Object System.Windows.Forms.FlowLayoutPanel
$leftButtons.Dock = 'Fill'
$leftButtons.WrapContents = $true
$leftButtons.AutoScroll = $true
$leftActionsLayout.Controls.Add($leftButtons, 0, 1)

$showDiffButton = New-Object System.Windows.Forms.Button
$showDiffButton.Text = 'Show diff'
$showDiffButton.Width = 110
$showDiffButton.Height = 32
$showDiffButton.Margin = New-Object System.Windows.Forms.Padding(4)
$showDiffButton.Add_Click({ Show-SelectedDiff })
$leftButtons.Controls.Add($showDiffButton)

$stageSelectedButton = New-Object System.Windows.Forms.Button
$stageSelectedButton.Text = 'Stage selected'
$stageSelectedButton.Width = 120
$stageSelectedButton.Height = 32
$stageSelectedButton.Margin = New-Object System.Windows.Forms.Padding(4)
$stageSelectedButton.Add_Click({ Stage-SelectedFile })
$leftButtons.Controls.Add($stageSelectedButton)

$unstageSelectedButton = New-Object System.Windows.Forms.Button
$unstageSelectedButton.Text = 'Unstage selected'
$unstageSelectedButton.Width = 125
$unstageSelectedButton.Height = 32
$unstageSelectedButton.Margin = New-Object System.Windows.Forms.Padding(4)
$unstageSelectedButton.Add_Click({ Unstage-SelectedFile })
$leftButtons.Controls.Add($unstageSelectedButton)

$refreshButton2 = New-Object System.Windows.Forms.Button
$refreshButton2.Text = 'Refresh'
$refreshButton2.Width = 100
$refreshButton2.Height = 32
$refreshButton2.Margin = New-Object System.Windows.Forms.Padding(4)
$refreshButton2.Add_Click({ Refresh-Status })
$leftButtons.Controls.Add($refreshButton2)

# Diff/Log split
$rightSplit = New-Object System.Windows.Forms.SplitContainer
$script:RightSplit = $rightSplit
$rightSplit.Dock = 'Fill'
$rightSplit.Orientation = 'Horizontal'
$rightSplit.SplitterWidth = 9
$rightSplit.Panel1MinSize = 25
$rightSplit.Panel2MinSize = 25
$contentSplit.Panel2.Controls.Add($rightSplit)

# Diff group
$diffGroup = New-Object System.Windows.Forms.GroupBox
$diffGroup.Text = 'Diff preview / selected command output'
$diffGroup.Dock = 'Fill'
$diffGroup.Padding = New-Object System.Windows.Forms.Padding(10)
$rightSplit.Panel1.Controls.Add($diffGroup)
$script:DiffGroup = $diffGroup

$script:DiffTextBox = New-Object System.Windows.Forms.RichTextBox
$script:DiffTextBox.Dock = 'Fill'
$script:DiffTextBox.ReadOnly = $true
$script:DiffTextBox.WordWrap = $false
$script:DiffTextBox.Font = $script:FontMono
$script:DiffTextBox.BackColor = [System.Drawing.Color]::White
$script:DiffTextBox.Text = '(Select a changed file to preview its diff, or click Git status / Show graph.)'
$diffGroup.Controls.Add($script:DiffTextBox)

# Log group
$logGroup = New-Object System.Windows.Forms.GroupBox
$logGroup.Text = 'Live output / command log'
$logGroup.Dock = 'Fill'
$logGroup.Padding = New-Object System.Windows.Forms.Padding(10)
$rightSplit.Panel2.Controls.Add($logGroup)
$script:LogGroup = $logGroup

$logActionSplit = New-Object System.Windows.Forms.SplitContainer
$script:LogActionSplit = $logActionSplit
$logActionSplit.Dock = 'Fill'
$logActionSplit.Orientation = 'Horizontal'
$logActionSplit.SplitterWidth = 9
$logActionSplit.Panel1MinSize = 25
$logActionSplit.Panel2MinSize = 36
$logGroup.Controls.Add($logActionSplit)

$script:LogTextBox = New-Object System.Windows.Forms.RichTextBox
$script:LogTextBox.Dock = 'Fill'
$script:LogTextBox.ReadOnly = $true
$script:LogTextBox.WordWrap = $false
$script:LogTextBox.Font = $script:FontMono
$script:LogTextBox.BackColor = [System.Drawing.Color]::White
$logActionSplit.Panel1.Controls.Add($script:LogTextBox)

$logButtonsLayout = New-Object System.Windows.Forms.TableLayoutPanel
$logButtonsLayout.Dock = 'Fill'
$script:LogButtonsLayout = $logButtonsLayout
$logButtonsLayout.ColumnCount = 1
$logButtonsLayout.RowCount = 2
[void]$logButtonsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 45)))
[void]$logButtonsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 55)))
$logActionSplit.Panel2.Controls.Add($logButtonsLayout)

$logHintLabel = New-WrappingLabel -Text 'Live command output is shown above. Drag this splitter to give more room to the log or the log action buttons.' -Height 40
$logButtonsLayout.Controls.Add($logHintLabel, 0, 0)

$logButtons = New-Object System.Windows.Forms.FlowLayoutPanel
$logButtons.Dock = 'Fill'
$logButtons.WrapContents = $true
$logButtons.AutoScroll = $true
$logButtonsLayout.Controls.Add($logButtons, 0, 1)

$clearOutputButton = New-Object System.Windows.Forms.Button
$clearOutputButton.Text = 'Clear output'
$clearOutputButton.Width = 120
$clearOutputButton.Height = 30
$clearOutputButton.Margin = New-Object System.Windows.Forms.Padding(4)
$clearOutputButton.Add_Click({ 
    $script:LogTextBox.Clear()
    Append-Log -Text 'Output cleared.' -Color ([System.Drawing.Color]::DarkGray) 
})
$logButtons.Controls.Add($clearOutputButton)

$copyOutputButton = New-Object System.Windows.Forms.Button
$copyOutputButton.Text = 'Copy output'
$copyOutputButton.Width = 120
$copyOutputButton.Height = 30
$copyOutputButton.Margin = New-Object System.Windows.Forms.Padding(4)
$copyOutputButton.Add_Click({ 
    if ($script:LogTextBox.TextLength -gt 0) { 
        [System.Windows.Forms.Clipboard]::SetText($script:LogTextBox.Text) 
    } 
})
$logButtons.Controls.Add($copyOutputButton)

$saveOutputButton = New-Object System.Windows.Forms.Button
$saveOutputButton.Text = 'Save log'
$saveOutputButton.Width = 110
$saveOutputButton.Height = 30
$saveOutputButton.Margin = New-Object System.Windows.Forms.Padding(4)
$saveOutputButton.Add_Click({ Save-LogToFile })
$logButtons.Controls.Add($saveOutputButton)

# Status strip
$statusStrip = New-Object System.Windows.Forms.StatusStrip
$script:StatusValueLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$script:StatusValueLabel.Spring = $true
$script:StatusValueLabel.TextAlign = 'MiddleLeft'
$script:StatusValueLabel.Text = 'Ready.'
$statusStrip.Items.Add($script:StatusValueLabel) | Out-Null
$rootLayout.Controls.Add($statusStrip, 0, 1)


# Make every resizable splitter visibly discoverable. WinForms splitters are
# otherwise easy to miss until the user happens to hover over the exact pixels.
Enable-VisibleSplitter -Splitter $script:MainWorkSplit -Tooltip 'Drag this visible splitter to resize the upper workflow area versus Changed files / Diff preview / Live output. Saved on close.'
Enable-VisibleSplitter -Splitter $script:RootTopSplit -Tooltip 'Drag this visible splitter to resize the progress bar area versus the repository/status work area. Saved on close.'
Enable-VisibleSplitter -Splitter $script:HeaderTopAreaSplit -Tooltip 'Drag this visible splitter to resize Repository status versus Feature branch / Common actions / Commit panels. Saved on close.'
Enable-VisibleSplitter -Splitter $script:TopSplit -Tooltip 'Drag this visible splitter to resize left workflow controls versus Commit / preview / help. Saved on close.'
Enable-VisibleSplitter -Splitter $script:TopLeftSplit -Tooltip 'Drag this visible splitter to resize Feature branch versus Common actions. Saved on close.'
Enable-VisibleSplitter -Splitter $script:CommitPreviewSplit -Tooltip 'Drag this visible splitter to resize Commit editor versus Command preview / Help. Saved on close.'
Enable-VisibleSplitter -Splitter $script:ContentSplit -Tooltip 'Drag this visible splitter to resize Changed files versus Diff preview and command log. Saved on close.'
Enable-VisibleSplitter -Splitter $script:RightSplit -Tooltip 'Drag this visible splitter to resize Diff preview versus Live output / command log. Saved on close.'
Enable-VisibleSplitter -Splitter $script:ChangedFilesActionSplit -Tooltip 'Drag this visible splitter to resize Changed files list versus file action buttons. Saved on close.'
Enable-VisibleSplitter -Splitter $script:LogActionSplit -Tooltip 'Drag this visible splitter to resize Live output / command log versus log action buttons. Saved on close.'
Enable-VisibleSplitter -Splitter $script:AppearanceMainSplit -Tooltip 'Drag this visible splitter to resize the Appearance color list versus the selected color editor. Saved on close.'

# Set up tooltips
$script:ToolTip.SetToolTip($script:FeatureBranchTextBox, "Enter a new feature branch name. Branch names are validated before creation.")
$script:ToolTip.SetToolTip($script:BaseFromDevelopCheckBox, "When checked, the tool switches to $($script:Config.BaseBranch), pulls, then creates the new feature branch. Requires a clean working tree.")
$script:ToolTip.SetToolTip($script:BranchSwitchComboBox, 'Choose an existing local branch or type one, then click Switch branch.')
$script:ToolTip.SetToolTip($script:ChangedFilesList, 'Changed files from git status --porcelain. Each row keeps its parsed Git status internally, so selecting a row should immediately load its diff. Multi-select is supported for stage/unstage; the diff preview uses the first selected file.')
$script:ToolTip.SetToolTip($script:DiffTextBox, 'Shows selected file diff output. Staged and unstaged changes are separated when possible; untracked text files show a safe content preview.')
$script:ToolTip.SetToolTip($script:LogTextBox, 'Shows live standard output and standard error from Git and build commands.')
$script:ToolTip.SetToolTip($script:CommitSubjectTextBox, "Short commit subject (max $($script:Config.CommitSubjectMaxLength) chars recommended). Example: v34.3: add trust, observability, and local-first foundation")
$script:ToolTip.SetToolTip($script:CommitBodyTextBox, 'Optional body. Use bullet-style lines for details and validation notes.')
$script:ToolTip.SetToolTip($script:CancelButton, 'Cancel the currently running operation.')
$script:ToolTip.SetToolTip($script:StashMessageTextBox, 'Optional message for the stash entry.')
$script:ToolTip.SetToolTip($script:StashIncludeUntrackedCheckBox, 'Include untracked files in the stash by using git stash push -u.')
$script:ToolTip.SetToolTip($script:StashKeepIndexCheckBox, 'Stash only unstaged changes and keep already staged changes in the index by using --keep-index.')
$script:ToolTip.SetToolTip($script:StashListBox, 'Select a stash entry, then apply, pop, drop, inspect, or create a branch from it.')
$script:ToolTip.SetToolTip($script:StashBranchTextBox, 'Branch name used by git stash branch. This recovers a stash on a new branch.')
$script:ToolTip.SetToolTip($script:CustomGitLabelTextBox, 'Label for a saved custom Git button.')
$script:ToolTip.SetToolTip($script:CustomGitCommandTextBox, 'Git arguments only, for example: status -sb or log --oneline -n 10. The leading git word is optional.')
$script:ToolTip.SetToolTip($newCustomGitDraftButton, 'Clear the selected saved command and start a fresh custom Git button draft.')
$script:ToolTip.SetToolTip($addRecommendedCustomGitButton, 'Add a small set of useful custom Git buttons, without duplicating existing labels or commands.')
$script:ToolTip.SetToolTip($insertTemplateButton, 'Insert an example commit subject/body based on the selected template. You can edit the generated text before committing.')
$script:ToolTip.SetToolTip($copyPreviewButton, 'Copy the command preview text to the clipboard for review, debugging, or sharing.')
$script:ToolTip.SetToolTip($copyLastCommandButton, 'Copy the last command summary that was executed by this GUI.')
$script:ToolTip.SetToolTip($clearOutputButton, 'Clear the live command output area. This does not affect Git state.')
$script:ToolTip.SetToolTip($copyOutputButton, 'Copy the live command output to the clipboard.')
$script:ToolTip.SetToolTip($saveOutputButton, 'Save the live command output to a text or log file for troubleshooting.')
$script:ToolTip.SetToolTip($script:ThemeColorListBox, 'Select a GUI color role to edit. Each row maps to a saved ThemeColors key in GitGlideGUI-Config.json.')
$script:ToolTip.SetToolTip($script:ThemeHexTextBox, 'Type a color as #RRGGBB, then click Apply hex.')
$script:ToolTip.SetToolTip($chooseThemeColorButton, 'Open a color picker for the selected GUI color role.')
$script:ToolTip.SetToolTip($applyThemeHexButton, 'Apply the typed #RRGGBB color to the selected GUI color role and save it.')
$script:ToolTip.SetToolTip($resetSelectedThemeButton, 'Reset only the selected GUI color role to the built-in default.')
$script:ToolTip.SetToolTip($resetAllThemeButton, 'Reset all GUI colors to the built-in defaults.')
$script:ToolTip.SetToolTip($applyThemeNowButton, 'Reapply the currently saved theme colors to the open window.')
$script:ToolTip.SetToolTip($openRepositoryButton, 'Select an existing Git repository folder. Use Init new... when you intentionally want to create a repository.')
$script:ToolTip.SetToolTip($newRepositoryButton, 'Initialize a selected normal folder as a new Git repository for a new project.')
$script:ToolTip.SetToolTip($script:SuggestedNextActionButton, 'Runs only safe suggested actions, such as opening a wizard, focusing a panel, showing a diff, or selecting a setup workflow. It does not silently run destructive Git commands.')


# Set up control previews
Set-ControlPreview -Control $createBranchButton -Builder { Build-FeatureBranchCommandPreview } -Title 'Create feature branch' -Notes 'Creates a branch using the current feature branch textbox and base-from-develop option.'
Set-ControlPreview -Control $switchBranchButton -Builder { Build-SwitchBranchPreview } -Title 'Switch branch' -Notes 'Switches to the selected or typed branch.'
Set-ControlPreview -Control $showDiffButton -Builder { Build-ShowDiffPreview } -Title 'Show diff for selected file' -Notes 'Reloads the preview for the first selected changed file. Handles staged, unstaged, renamed, deleted, conflicted, and untracked files.'
Set-ControlPreview -Control $stageSelectedButton -Builder { Build-StageSelectedPreview } -Title 'Stage selected file' -Notes 'Adds the selected file(s) to the Git index so they will be included in the next commit.'
Set-ControlPreview -Control $unstageSelectedButton -Builder { Build-UnstageSelectedPreview } -Title 'Unstage selected file' -Notes 'Removes the selected file(s) from the Git index while keeping your working-tree edits.'
Set-ControlPreview -Control $refreshButton2 -Builder { 'git status --porcelain=v1 --branch' } -Title 'Refresh repository status'
Set-ControlPreview -Control $commitButton -Builder { Build-CommitPreview } -Title 'Commit staged changes' -Notes 'If Stage all is checked, the GUI stages everything first. Validates commit message before executing.'
Set-ControlPreview -Control $commitPushButton -Builder { Build-CommitPreview } -Title 'Commit and push' -Notes 'If Amend is checked, push uses --force-with-lease.'
Set-ControlPreview -Control $stashButton -Builder { Build-StashPushPreview } -Title 'Stash changes' -Notes 'Saves current work-in-progress so you can switch branches or pull safely. Optional flags include untracked files and keeping the staged index.'
Set-ControlPreview -Control $stashUntrackedButton -Builder { Build-StashPushIncludeUntrackedPreview } -Title 'Stash changes including untracked files' -Notes 'Convenience button for git stash push -u. Useful when new files are part of your unfinished work.'
Set-ControlPreview -Control $stashKeepIndexQuickButton -Builder { Build-StashPushKeepIndexPreview } -Title 'Stash unstaged changes only' -Notes 'Convenience button for git stash push --keep-index. Useful when staged changes should stay staged for a commit.'
Set-ControlPreview -Control $popStashButton -Builder { Build-StashPopPreview } -Title 'Pop stash' -Notes 'Applies the selected stash and removes it from the stash list. If nothing is selected, uses the latest stash.'
Set-ControlPreview -Control $applyStashButton -Builder { Build-StashApplyPreview } -Title 'Apply stash' -Notes 'Applies the selected stash but keeps it in the stash list.'
Set-ControlPreview -Control $dropStashButton -Builder { Build-StashDropPreview } -Title 'Drop stash' -Notes 'Deletes the selected stash. This is destructive and asks for confirmation.'
Set-ControlPreview -Control $refreshStashesButton -Builder { Build-StashListPreview } -Title 'Refresh stashes' -Notes 'Reloads the stash list and stash count.'
Set-ControlPreview -Control $showStashDiffButton -Builder { Build-StashShowPreview } -Title 'Show stash diff' -Notes 'Shows the selected stash patch in the diff preview pane without applying it.'
Set-ControlPreview -Control $showStashFilesButton -Builder { Build-StashNameStatusPreview } -Title 'Show files in stash' -Notes 'Shows only the file list captured in the selected stash. Useful before applying or popping.'
Set-ControlPreview -Control $applyStashIndexButton -Builder { Build-StashApplyIndexPreview } -Title 'Apply stash and restore index' -Notes 'Runs git stash apply --index. Attempts to restore both working tree and staged/index state from the stash.'
Set-ControlPreview -Control $popStashIndexButton -Builder { Build-StashPopIndexPreview } -Title 'Pop stash and restore index' -Notes 'Runs git stash pop --index. Applies the stash, restores staged/index state, then drops the stash if successful.'
Set-ControlPreview -Control $stashBranchButton -Builder { Build-StashBranchPreview } -Title 'Create branch from stash' -Notes 'Creates a new branch from the selected stash and applies it there.'
Set-ControlPreview -Control $clearStashesButton -Builder { 'git stash clear' } -Title 'Clear all stashes' -Notes 'Deletes all stash entries after confirmation. Use carefully.'
Set-ControlPreview -Control $runCustomGitButton -Builder { Build-CustomGitPreview } -Title 'Run typed custom git command' -Notes 'Runs the command typed in the Custom Git tab as git arguments in the current repository.'
Set-ControlPreview -Control $addCustomGitButton -Builder { Build-CustomGitPreview } -Title 'Save typed command as a new button' -Notes 'Saves the typed command into GitGlideGUI-Config.json and renders it as a reusable button.'
Set-ControlPreview -Control $updateCustomGitButton -Builder { Build-CustomGitPreview } -Title 'Update selected custom button' -Notes 'Replaces the selected saved button with the current label and Git arguments.'
Set-ControlPreview -Control $removeCustomGitButton -Builder { 'remove selected custom button from GitGlideGUI-Config.json' } -Title 'Remove selected custom button' -Notes 'Removes only the saved GUI button definition. It does not run a git command.'
Set-ControlPreview -Control $newCustomGitDraftButton -Builder { 'git status -sb' } -Title 'Start a new custom Git button draft' -Notes 'Clears selection and places a safe example in the input fields.'
Set-ControlPreview -Control $addRecommendedCustomGitButton -Builder { 'save recommended custom Git buttons to GitGlideGUI-Config.json' } -Title 'Add recommended custom Git buttons' -Notes 'Adds commonly useful commands such as status, diff summaries, recent commits, branch graph and stash list.'
Set-ControlPreview -Control $createTagButton -Builder { 'git tag -a <tag> -m <message>' } -Title 'Create release tag' -Notes 'Creates an annotated tag by default. Lightweight tags are available by unchecking Annotated.'
Set-ControlPreview -Control $refreshTagsButton -Builder { 'git tag --list --sort=-creatordate' } -Title 'Refresh tag list'
Set-ControlPreview -Control $showTagButton -Builder { Build-SelectedTagPreview -Action 'Details' } -Title 'Show selected tag details'
Set-ControlPreview -Control $pushTagButton -Builder { Build-SelectedTagPreview -Action 'Push' } -Title 'Push selected tag' -Notes 'Asks for confirmation because tags are shared release markers.'
Set-ControlPreview -Control $pushAllTagsButton -Builder { 'git push origin --tags' } -Title 'Push all local tags' -Notes 'Asks for confirmation. Use only when all local tags are intentional.'
Set-ControlPreview -Control $deleteTagButton -Builder { Build-SelectedTagPreview -Action 'Delete' } -Title 'Delete selected tag' -Notes 'Deletes the selected local tag after confirmation. Optional remote deletion is also explicit.'
Set-ControlPreview -Control $checkoutTagButton -Builder { Build-SelectedTagPreview -Action 'Checkout' } -Title 'Checkout selected tag or create branch from tag' -Notes 'Creates a branch when Branch from tag has a name; otherwise warns before detached HEAD checkout.'
Set-ControlPreview -Control $openRepositoryButton -Builder { 'select an existing Git repository folder and refresh status' } -Title 'Open repository' -Notes 'Use this when Git Glide GUI was launched from the extracted tool folder instead of the repository.'
Set-ControlPreview -Control $newRepositoryButton -Builder { 'git init -b <main-branch>' } -Title 'Initialize new repository' -Notes 'Use this when the selected project folder intentionally does not have a Git repository yet.'

Refresh-CustomGitButtonsPanel
Refresh-ThemeColorList
Update-ThemeEditorSelection
Load-TagList
Apply-Theme

# Event handlers for preview updates
$script:FeatureBranchTextBox.Add_TextChanged({ 
    Set-CommandPreview -Title 'Create feature branch' -Commands (Build-FeatureBranchCommandPreview) -Notes 'Preview updates as you type.' 
})

$script:BaseFromDevelopCheckBox.Add_CheckedChanged({ 
    Set-CommandPreview -Title 'Create feature branch' -Commands (Build-FeatureBranchCommandPreview) -Notes 'Preview updates as you change the base-from-develop option.' 
})

$script:BranchSwitchComboBox.Add_TextChanged({ 
    Set-CommandPreview -Title 'Switch branch' -Commands (Build-SwitchBranchPreview) -Notes 'Preview updates as you select or type a branch.' 
})

$script:CommitTemplateComboBox.Add_SelectedIndexChanged({ Update-CommitPreview })
$script:CommitSubjectTextBox.Add_TextChanged({ Update-CommitPreview })
$script:CommitBodyTextBox.Add_TextChanged({ Update-CommitPreview })
$script:CommitStageAllCheckBox.Add_CheckedChanged({ Update-CommitPreview })
$script:CommitAmendCheckBox.Add_CheckedChanged({ Update-CommitPreview })
$script:CommitPushAfterCheckBox.Add_CheckedChanged({ Update-CommitPreview })
if ($script:CommitConventionalGuidanceCheckBox) { $script:CommitConventionalGuidanceCheckBox.Add_CheckedChanged({ Update-CommitPreview }) }
$script:StashMessageTextBox.Add_TextChanged({ Set-CommandPreview -Title 'Stash changes' -Commands (Build-StashPushPreview) -Notes 'Preview updates as you edit the stash message.' })
$script:StashIncludeUntrackedCheckBox.Add_CheckedChanged({ Set-CommandPreview -Title 'Stash changes' -Commands (Build-StashPushPreview) -Notes 'Preview updates as you toggle untracked-file handling.' })
$script:StashKeepIndexCheckBox.Add_CheckedChanged({ Set-CommandPreview -Title 'Stash changes' -Commands (Build-StashPushPreview) -Notes 'Preview updates as you toggle keep-index handling.' })
$script:StashListBox.Add_SelectedIndexChanged({ Set-CommandPreview -Title 'Selected stash' -Commands (Build-StashShowPreview) -Notes 'Use Show stash diff, Apply, Pop, Drop, or Create branch.' })
$script:StashBranchTextBox.Add_TextChanged({ Set-CommandPreview -Title 'Create branch from stash' -Commands (Build-StashBranchPreview) -Notes 'Preview updates as you type the recovery branch name.' })
$script:CustomGitCommandTextBox.Add_TextChanged({ Set-CommandPreview -Title 'Custom git command' -Commands (Build-CustomGitPreview) -Notes 'Preview updates as you type. Custom commands are passed to git directly, not through cmd.exe.' })
$script:CustomGitButtonsListBox.Add_SelectedIndexChanged({
    $idx = [int]$script:CustomGitButtonsListBox.SelectedIndex
    $defs = @($script:CustomGitButtons)
    if ($idx -ge 0 -and $idx -lt $defs.Count) {
        $script:CustomGitLabelTextBox.Text = [string]$defs[$idx].Label
        $script:CustomGitCommandTextBox.Text = [string]$defs[$idx].Arguments
        Set-CommandPreview -Title 'Saved custom git command' -Commands ('git ' + [string]$defs[$idx].Arguments) -Notes 'Double-click the saved command or use Run typed command.'
    }
})


$script:TagListBox.Add_SelectedIndexChanged({
    Set-CommandPreview -Title 'Selected release tag' -Commands (Build-SelectedTagPreview -Action 'Details') -Notes 'Use Show details, Push selected, Delete selected, or Checkout / branch.'
    Show-SelectedTagDetails
})
$script:TagNameTextBox.Add_TextChanged({
    $candidate = $script:TagNameTextBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($candidate)) { $candidate = '<tag>' }
    Set-CommandPreview -Title 'Create release tag' -Commands ('git tag -a ' + (Quote-Arg $candidate) + ' -m <message>') -Notes 'Preview updates as you type. Annotated tags are recommended for releases.'
})
$script:TagBranchTextBox.Add_TextChanged({
    Set-CommandPreview -Title 'Checkout selected tag' -Commands (Build-SelectedTagPreview -Action 'Checkout') -Notes 'If Branch from tag is not empty, the GUI creates a branch from the selected tag.'
})

$openRepositoryButton.Add_Click({ Show-RepositoryPicker | Out-Null })
$newRepositoryButton.Add_Click({ Show-NewRepositoryPicker | Out-Null })

# Keyboard shortcuts
$form.Add_KeyDown({
    if ($_.KeyCode -eq [System.Windows.Forms.Keys]::F5) {
        Refresh-Status
        $_.Handled = $true
        return
    }
    if ($_.Control -and $_.KeyCode -eq [System.Windows.Forms.Keys]::D) {
        Show-SelectedDiff
        $_.Handled = $true
        return
    }
    if ($_.Control -and $_.KeyCode -eq [System.Windows.Forms.Keys]::S) {
        Stage-SelectedFile
        $_.Handled = $true
        return
    }
    if ($_.Control -and $_.KeyCode -eq [System.Windows.Forms.Keys]::U) {
        Unstage-SelectedFile
        $_.Handled = $true
        return
    }
    if ($_.Control -and $_.Shift -and $_.KeyCode -eq [System.Windows.Forms.Keys]::S) {
        Stage-AllChanges
        $_.Handled = $true
        return
    }
    if ($_.Control -and $_.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
        Commit-Changes
        $_.Handled = $true
        return
    }
    if ($_.Control -and $_.KeyCode -eq [System.Windows.Forms.Keys]::P) {
        Push-CurrentBranch
        $_.Handled = $true
        return
    }
    if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
        Cancel-CurrentOperation
        $_.Handled = $true
        return
    }
})

$form.Add_Shown({
    Apply-SavedLayout
})

$form.Add_FormClosing({
    # v3.5: WinForms can invoke FormClosing while the hosting PowerShell
    # pipeline is already stopping. Letting PipelineStoppedException escape
    # from this event handler produces a .NET JIT/debugging dialog instead of
    # a normal shutdown. Keep close-time cleanup best-effort and non-throwing.
    $script:IsShuttingDown = $true
    if ($script:ShutdownCleanupStarted) { return }
    $script:ShutdownCleanupStarted = $true

    try {
        Save-LayoutConfig
    } catch [System.Management.Automation.PipelineStoppedException] {
        # Host is stopping; do not write to the pipeline and do not rethrow.
    } catch {
        # Closing must remain reliable even if layout persistence fails.
        try { Write-AuditLog -Message ("SHUTDOWN_CLEANUP_WARNING | {0}" -f $_.Exception.Message) } catch {}
    } finally {
        try { Cancel-CurrentOperation } catch {}
    }
})

#endregion

# Initialize and show
Set-HelpExamples
Append-Log -Text 'Git Glide GUI - Enhanced Version v3.6.4 ready.' -Color ([System.Drawing.Color]::DarkGreen)
Append-Log -Text "Config: $script:ConfigPath" -Color ([System.Drawing.Color]::DarkGray)
Append-Log -Text "Audit log: $script:AuditLogPath" -Color ([System.Drawing.Color]::DarkGray)
Write-AuditLog -Message ("STARTUP | RepoRoot='{0}' | Version=v3.6.4" -f $script:RepoRoot)

$repositoryReady = Ensure-RepositorySelected -InitialStartup

if ($script:StartupAborted) {
    Write-AuditLog -Message 'STARTUP_ABORTED | User closed repository choice dialog'
    exit 0
}

Apply-UiMode
Set-CommandPreview -Title 'Welcome to Git Glide GUI v3.6.4' -Commands 'Hover a button to preview its commands.' -Notes 'Use Setup for Open existing repo, Init new repo, First commit, .gitignore and Remote setup. Use History / Graph for read-only branch/merge inspection and command previews, Recovery for resolved/unresolved conflicts, stage resolved files, continue/abort operations, merge tools, and cherry-pick workflows. Use Learning for workflow explanations. Press ESC to cancel running operations.'
if ($repositoryReady) { Refresh-Status } else { Set-SuggestedNextAction -Text 'Open existing repo or init new repo before running Git operations.' -Action 'choose-repo' }

try {
    [void]$form.ShowDialog()
} catch [System.Management.Automation.PipelineStoppedException] {
    # Normal host/pipeline shutdown path. Avoid showing a crash dialog.
    exit 0
} catch {
    $message = 'Git Glide GUI crashed: ' + $_.Exception.Message
    try { 
        Append-Log -Text $message -Color ([System.Drawing.Color]::Firebrick) 
    } catch {}
    try {
        [System.Windows.Forms.MessageBox]::Show($message, 'Git Glide GUI failed', 'OK', 'Error') | Out-Null
    } catch {}
    exit 1
}
