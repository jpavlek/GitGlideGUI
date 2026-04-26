# This file is part of Git Glide GUI v3.7.0 split-script architecture.
# It is dot-sourced by GitGlideGUI-v3.7.0.ps1.

#region UI Setup

$form = New-Object System.Windows.Forms.Form
$script:AppVersion = '3.7.0'
$form.Text = "Git Glide GUI v$script:AppVersion - safer visual Git workflows"
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

function Get-UiMode {
    try {
        if ($script:Config.ContainsKey('UiMode') -and -not [string]::IsNullOrWhiteSpace([string]$script:Config.UiMode)) {
            $mode = [string]$script:Config.UiMode
            if ($mode -in @('Simple','Workflow','Expert')) { return $mode }
        }
    } catch {}
    if (Get-ConfigBool -Name 'BeginnerMode' -DefaultValue $true) { return 'Simple' }
    return 'Expert'
}

function Set-UiMode {
    param([ValidateSet('Simple','Workflow','Expert')][string]$Mode)
    Set-ConfigValue -Name 'UiMode' -Value $Mode
    Set-ConfigValue -Name 'BeginnerMode' -Value ($Mode -eq 'Simple')
    Save-Config -Config $script:Config
}

function Get-UiModeTabPages {
    param([ValidateSet('Simple','Workflow','Expert')][string]$Mode)
    switch ($Mode) {
        'Simple' {
            return @($script:SetupTabPage, $script:StageTabPage, $script:BranchTabPage, $script:StashTabPage, $script:InspectTabPage)
        }
        'Workflow' {
            return @($script:SetupTabPage, $script:StageTabPage, $script:BranchTabPage, $script:IntegrateTabPage, $script:RecoveryTabPage, $script:HistoryTabPage, $script:StashTabPage, $script:TagsTabPage, $script:LearningTabPage)
        }
        default {
            return @($script:AllActionTabs)
        }
    }
}

function Apply-UiMode {
    $mode = Get-UiMode
    if (-not $script:ActionsTabs -or -not $script:AllActionTabs) { return }

    $script:ActionsTabs.SuspendLayout()
    try {
        $current = $script:ActionsTabs.SelectedTab
        $script:ActionsTabs.TabPages.Clear()
        foreach ($tab in @(Get-UiModeTabPages -Mode $mode)) {
            if ($null -eq $tab) { continue }
            if (-not $script:ActionsTabs.TabPages.Contains($tab)) { [void]$script:ActionsTabs.TabPages.Add($tab) }
        }
        if ($current -and $script:ActionsTabs.TabPages.Contains($current)) {
            $script:ActionsTabs.SelectedTab = $current
        } elseif ($script:SetupTabPage -and $script:ActionsTabs.TabPages.Contains($script:SetupTabPage)) {
            $script:ActionsTabs.SelectedTab = $script:SetupTabPage
        }
    } finally {
        $script:ActionsTabs.ResumeLayout()
    }

    if ($script:ActionsGroup) {
        $script:ActionsGroup.Text = ('Actions - {0} mode' -f $mode)
    }
    if ($script:ModeToggleButton) {
        $next = if ($mode -eq 'Simple') { 'Workflow' } elseif ($mode -eq 'Workflow') { 'Expert' } else { 'Simple' }
        $script:ModeToggleButton.Text = ('Switch to {0} mode' -f $next)
    }
    if ($script:ModeValueLabel) { $script:ModeValueLabel.Text = $mode }
    Update-ChangedFilesContextBanner
}

function Toggle-UiMode {
    $mode = Get-UiMode
    $next = if ($mode -eq 'Simple') { 'Workflow' } elseif ($mode -eq 'Workflow') { 'Expert' } else { 'Simple' }
    Set-UiMode -Mode $next
    Apply-UiMode
    Set-SuggestedNextAction -Text ("$next mode enabled. Simple reduces visible choices, Workflow shows guided Git Flow, Expert shows every tab.")
}

function Build-ModeTogglePreview {
    $mode = Get-UiMode
    if ($mode -eq 'Simple') {
        return 'switch UI mode to Workflow; show guided Git Flow, Recovery, History, Tags, and Learning while keeping everyday actions visible'
    }
    if ($mode -eq 'Workflow') {
        return 'switch UI mode to Expert; show every tab including Custom Git and Appearance without changing repository state'
    }
    return 'switch UI mode to Simple; keep everyday work actions visible and hide advanced tabs behind the mode switch and command palette'
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


function Get-CommandPaletteItems {
    $items = @(
        @{ Name='Refresh status'; Group='Inspect'; Tab=$script:InspectTabPage; Preview='git status --porcelain=v1 --branch'; Notes='Refresh branch, upstream, changed files, and suggestions.' },
        @{ Name='Stage selected'; Group='Work'; Tab=$script:StageTabPage; Preview=(Build-StageSelectedPreview); Notes='Add selected changes to the next commit.' },
        @{ Name='Unstage selected'; Group='Work'; Tab=$script:StageTabPage; Preview=(Build-UnstageSelectedPreview); Notes='Remove selected changes from the next commit without losing them.' },
        @{ Name='Stop tracking selected'; Group='Work'; Tab=$script:StageTabPage; Preview=(Build-StopTrackingPreviewForItems -Items (Get-SelectedStatusItems)); Notes='Use git rm --cached to keep a local file but stop versioning it.' },
        @{ Name='Commit'; Group='Commit'; Tab=$script:SetupTabPage; Preview=(Build-CommitPreview); Notes='Review staged changes and commit on the current branch.' },
        @{ Name='Push current branch'; Group='Sync'; Tab=$script:IntegrateTabPage; Preview='git push -u origin HEAD'; Notes='Share the current branch and set upstream if needed.' },
        @{ Name='Merge feature into develop'; Group='Workflow'; Tab=$script:IntegrateTabPage; Preview=(Build-MergeSelectedFeatureIntoDevelopPreview); Notes='Integrate selected feature/fix work into develop.' },
        @{ Name='Run quality checks'; Group='Workflow'; Tab=$script:IntegrateTabPage; Preview='scripts\windows\run-quality-checks.bat'; Notes='Run smoke, launch, Pester, and optional ScriptAnalyzer checks before shipping.' },
        @{ Name='Merge develop into main'; Group='Workflow'; Tab=$script:IntegrateTabPage; Preview=(Build-MergeDevelopPreview); Notes='Promote tested develop work back to the release branch.' },
        @{ Name='GitHub diagnostics'; Group='GitHub'; Tab=$script:SetupTabPage; Preview=(Build-GitHubDiagnosticsPreview); Notes='Inspect remotes, upstream, remote reachability, and GitHub repository access.' },
        @{ Name='Recovery'; Group='Recover'; Tab=$script:RecoveryTabPage; Preview=(Build-RecoveryStatusPreview); Notes='Inspect conflicts and continue/abort merge, rebase, cherry-pick, or revert operations.' },
        @{ Name='History graph'; Group='Inspect'; Tab=$script:HistoryTabPage; Preview=(Build-HistoryPreview); Notes='Inspect branch graph, merges, tags, and commits.' },
        @{ Name='Custom Git'; Group='Expert'; Tab=$script:CustomGitTabPage; Preview='git <allowlisted command>'; Notes='Run an allowlisted custom Git command with preview and safety checks.' }
        @{ Name='Workflow checklist'; Group='Workflow'; Tab=$script:IntegrateTabPage; Preview=(Build-MergeWorkflowChecklistPreview); Notes='Review the feature -> develop -> quality checks -> main checklist before promoting work.' },
        @{ Name='Clean merged branch'; Group='Workflow'; Tab=$script:IntegrateTabPage; Preview=(Build-CleanupSelectedFeatureBranchPreview); Notes='Delete a merged feature/fix branch locally and remotely after confirmation.' }
    )
    return @($items | ForEach-Object { [pscustomobject]$_ })
}

function Show-CommandPalette {
    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = 'Command palette - find Git Glide actions'
    $dialog.Size = New-Object System.Drawing.Size(820, 560)
    $dialog.StartPosition = 'CenterParent'
    $dialog.MinimizeBox = $false
    $dialog.MaximizeBox = $false
    $dialog.Font = $script:UiFont

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = 'Fill'
    $layout.Padding = New-Object System.Windows.Forms.Padding(12)
    $layout.ColumnCount = 1
    $layout.RowCount = 4
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 55)))
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 45)))
    [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
    $dialog.Controls.Add($layout)

    $search = New-Object System.Windows.Forms.TextBox
    $search.Dock = 'Top'
    $search.Margin = New-Object System.Windows.Forms.Padding(0,0,0,8)
    $search.Text = ''
    $layout.Controls.Add($search,0,0)

    $list = New-Object System.Windows.Forms.ListBox
    $list.Dock = 'Fill'
    $list.DisplayMember = 'Display'
    $layout.Controls.Add($list,0,1)

    $details = New-Object System.Windows.Forms.TextBox
    $details.Dock = 'Fill'
    $details.Multiline = $true
    $details.ReadOnly = $true
    $details.ScrollBars = 'Vertical'
    $details.Font = $script:FontMono
    $layout.Controls.Add($details,0,2)

    $buttons = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttons.Dock = 'Bottom'
    $buttons.FlowDirection = 'RightToLeft'
    $buttons.AutoSize = $true
    $layout.Controls.Add($buttons,0,3)
    $close = New-Object System.Windows.Forms.Button; $close.Text='Close'; $close.Width=90; $close.DialogResult=[System.Windows.Forms.DialogResult]::Cancel; $buttons.Controls.Add($close)
    $focus = New-Object System.Windows.Forms.Button; $focus.Text='Show action area'; $focus.Width=130; $buttons.Controls.Add($focus)
    $copy = New-Object System.Windows.Forms.Button; $copy.Text='Copy preview'; $copy.Width=110; $buttons.Controls.Add($copy)

    $all = @(Get-CommandPaletteItems | ForEach-Object {
        $_ | Add-Member -NotePropertyName Display -NotePropertyValue ('[{0}] {1}' -f $_.Group, $_.Name) -Force
        $_
    })
    function Update-PaletteList {
        $needle = $search.Text.Trim().ToLowerInvariant()
        $list.Items.Clear()
        foreach ($item in $all) {
            $hay = (($item.Name + ' ' + $item.Group + ' ' + $item.Notes) -as [string]).ToLowerInvariant()
            if ([string]::IsNullOrWhiteSpace($needle) -or $hay.Contains($needle)) { [void]$list.Items.Add($item) }
        }
        if ($list.Items.Count -gt 0) { $list.SelectedIndex = 0 }
    }
    $search.Add_TextChanged({ Update-PaletteList })
    $list.Add_SelectedIndexChanged({
        $item = $list.SelectedItem
        if (-not $item) { $details.Text = ''; return }
        $details.Text = ("{0}`r`n`r`n{1}`r`n`r`nPreview:`r`n{2}" -f $item.Display, $item.Notes, $item.Preview)
    })
    $copy.Add_Click({ if ($list.SelectedItem) { [System.Windows.Forms.Clipboard]::SetText([string]$list.SelectedItem.Preview) } })
    $focus.Add_Click({
        $item = $list.SelectedItem
        if ($item -and $item.Tab -and $script:ActionsTabs) {
            if (-not $script:ActionsTabs.TabPages.Contains($item.Tab)) {
                Set-UiMode -Mode 'Expert'
                Apply-UiMode
            }
            if ($script:ActionsTabs.TabPages.Contains($item.Tab)) { $script:ActionsTabs.SelectedTab = $item.Tab }
            Set-CommandPreview -Title $item.Name -Commands ([string]$item.Preview) -Notes ([string]$item.Notes)
            $dialog.Close()
        }
    })
    Update-PaletteList
    [void]$dialog.ShowDialog($form)
}

# Setup actions
[void](New-ActionGuidance -ParentPanel $setupActionsPanel -Title 'Progressive disclosure' -Text 'Start here. Simple mode keeps everyday work visible, Workflow mode shows Git Flow steps, and Expert mode exposes every tool. Use Command palette to find hidden actions without crowding the screen.')
$script:ModeToggleButton = New-ActionButton -ParentPanel $setupActionsPanel -Text 'Switch to Workflow mode' -Width 190 -Handler { Toggle-UiMode } -PreviewBuilder { Build-ModeTogglePreview } -PreviewTitle 'Simple / Workflow / Expert mode' -Notes 'Progressive disclosure reduces overwhelm without removing features. Simple shows everyday actions, Workflow shows guided Git Flow, Expert shows everything.'
[void](New-ActionButton -ParentPanel $setupActionsPanel -Text 'Command palette...' -Width 165 -Handler { Show-CommandPalette } -PreviewBuilder { 'open searchable action palette; no Git command runs until you choose an action area and review the preview' } -PreviewTitle 'Command palette' -Notes 'Find actions that are hidden in the current mode without crowding the main screen. Useful when Simple mode hides advanced tabs.')
[void](New-ActionButton -ParentPanel $setupActionsPanel -Text 'Open existing repo' -Width 160 -Handler { Show-RepositoryPicker } -PreviewBuilder { 'select an existing Git repository folder and refresh status' } -PreviewTitle 'Open existing repository' -Notes 'Use this when the project already has a .git folder.')
[void](New-ActionButton -ParentPanel $setupActionsPanel -Text 'Init new repo' -Width 130 -Handler { Show-NewRepositoryPicker } -PreviewBuilder { 'git init -b <main-branch>' } -PreviewTitle 'Initialize new repository' -Notes 'Use this when the selected project folder intentionally does not have a Git repository yet.')
[void](New-ActionButton -ParentPanel $setupActionsPanel -Text 'First commit...' -Width 135 -Handler { Invoke-FirstCommitWizard } -PreviewBuilder { Build-FirstCommitPreview } -PreviewTitle 'First commit wizard' -Notes 'Creates or updates .gitignore, stages files, creates the first commit, and optionally configures/pushes to a remote.')
[void](New-ActionButton -ParentPanel $setupActionsPanel -Text 'Add .gitignore...' -Width 140 -Handler { Show-GitIgnoreTemplateDialog } -PreviewBuilder { Build-GitIgnorePreview } -PreviewTitle 'Create or update .gitignore' -Notes 'Adds a starter .gitignore template before committing generated files by accident.')
[void](New-ActionButton -ParentPanel $setupActionsPanel -Text 'Add remote...' -Width 125 -Handler { Show-RemoteSetupDialog } -PreviewBuilder { Build-RemoteSetupPreview } -PreviewTitle 'Add or update remote' -Notes 'Adds or updates origin and can optionally push the current branch with upstream tracking.')
[void](New-ActionButton -ParentPanel $setupActionsPanel -Text 'GitHub publish...' -Width 145 -Handler { Show-GitHubPublishDialog } -PreviewBuilder { Build-GitHubPublishPreview } -PreviewTitle 'GitHub publish workflow' -Notes 'Guides private GitHub repository creation, privacy/Copilot settings review, remote setup, and optional push.')
[void](New-ActionButton -ParentPanel $setupActionsPanel -Text 'GitHub diagnostics...' -Width 165 -Handler { Show-GitHubRemoteDiagnosticsDialog } -PreviewBuilder { Build-GitHubDiagnosticsPreview } -PreviewTitle 'GitHub remote diagnostics' -Notes 'Shows remotes, current branch, missing upstream, remote access checks, GitHub repository opening, and push-with-upstream guidance.')

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
$recoveryLayout.RowCount = 6
[void]$recoveryLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$recoveryLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$recoveryLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 28)))
[void]$recoveryLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 27)))
[void]$recoveryLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 45)))
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

$stateDoctorButton = New-Object System.Windows.Forms.Button
$stateDoctorButton.Text = 'State doctor'
$stateDoctorButton.Width = 115
$stateDoctorButton.Height = 32
$stateDoctorButton.Margin = New-Object System.Windows.Forms.Padding(4)
$stateDoctorButton.Add_Click({ Show-RepositoryStateDoctor })
$recoveryControls.Controls.Add($stateDoctorButton)

$markerScanButton = New-Object System.Windows.Forms.Button
$markerScanButton.Text = 'Find markers'
$markerScanButton.Width = 110
$markerScanButton.Height = 32
$markerScanButton.Margin = New-Object System.Windows.Forms.Padding(4)
$markerScanButton.Add_Click({ Show-ConflictMarkerScan })
$recoveryControls.Controls.Add($markerScanButton)

$validateGuiScriptButton = New-Object System.Windows.Forms.Button
$validateGuiScriptButton.Text = 'Validate GUI script'
$validateGuiScriptButton.Width = 145
$validateGuiScriptButton.Height = 32
$validateGuiScriptButton.Margin = New-Object System.Windows.Forms.Padding(4)
$validateGuiScriptButton.Add_Click({ Test-GuiScriptSyntax })
$recoveryControls.Controls.Add($validateGuiScriptButton)

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

$stateDoctorGroup = New-Object System.Windows.Forms.GroupBox
$stateDoctorGroup.Text = 'Repository State Doctor'
$stateDoctorGroup.Dock = 'Fill'
$stateDoctorGroup.Padding = New-Object System.Windows.Forms.Padding(6)
$stateDoctorLayout = New-Object System.Windows.Forms.TableLayoutPanel
$stateDoctorLayout.Dock = 'Fill'
$stateDoctorLayout.ColumnCount = 1
$stateDoctorLayout.RowCount = 2
[void]$stateDoctorLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$stateDoctorLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$stateDoctorGroup.Controls.Add($stateDoctorLayout)
$script:RepositoryStateDoctorSummaryLabel = New-Object System.Windows.Forms.Label
$script:RepositoryStateDoctorSummaryLabel.Text = 'Click State doctor to inspect branch sync, detached HEAD, in-progress operations, and conflict markers.'
$script:RepositoryStateDoctorSummaryLabel.AutoSize = $true
$script:RepositoryStateDoctorSummaryLabel.Margin = New-Object System.Windows.Forms.Padding(2, 0, 2, 4)
$stateDoctorLayout.Controls.Add($script:RepositoryStateDoctorSummaryLabel, 0, 0)
$script:RepositoryStateDoctorTextBox = New-Object System.Windows.Forms.RichTextBox
$script:RepositoryStateDoctorTextBox.Dock = 'Fill'
$script:RepositoryStateDoctorTextBox.ReadOnly = $true
$script:RepositoryStateDoctorTextBox.WordWrap = $true
$script:RepositoryStateDoctorTextBox.Font = $script:FontMono
$script:RepositoryStateDoctorTextBox.BackColor = [System.Drawing.Color]::AliceBlue
$script:RepositoryStateDoctorTextBox.Text = 'Repository State Doctor output appears here.'
$stateDoctorLayout.Controls.Add($script:RepositoryStateDoctorTextBox, 0, 1)
$recoveryLayout.Controls.Add($stateDoctorGroup, 0, 2)

$conflictFilesGroup = New-Object System.Windows.Forms.GroupBox
$conflictFilesGroup.Text = 'Unresolved conflict files'
$conflictFilesGroup.Dock = 'Fill'
$conflictFilesGroup.Padding = New-Object System.Windows.Forms.Padding(6)
$script:ConflictFilesListBox = New-Object System.Windows.Forms.ListBox
$script:ConflictFilesListBox.Dock = 'Fill'
$script:ConflictFilesListBox.HorizontalScrollbar = $true
$script:ConflictFilesListBox.Add_DoubleClick({ Open-SelectedConflictFile })
$conflictFilesGroup.Controls.Add($script:ConflictFilesListBox)
$recoveryLayout.Controls.Add($conflictFilesGroup, 0, 3)

$recoveryStatusPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$recoveryStatusPanel.Dock = 'Fill'
$recoveryStatusPanel.AutoSize = $true
$recoveryStatusPanel.WrapContents = $true
$recoveryStatusPanel.Margin = New-Object System.Windows.Forms.Padding(0, 4, 0, 0)
$recoveryLayout.Controls.Add($recoveryStatusPanel, 0, 5)

$script:RecoverySummaryLabel = New-Object System.Windows.Forms.Label
$script:RecoverySummaryLabel.Text = 'No active recovery guidance.'
$script:RecoverySummaryLabel.AutoSize = $true
$script:RecoverySummaryLabel.Margin = New-Object System.Windows.Forms.Padding(4)
$recoveryStatusPanel.Controls.Add($script:RecoverySummaryLabel)

$script:ConflictStateLabel = New-Object System.Windows.Forms.Label
$script:ConflictStateLabel.Text = 'Conflict state not inspected yet.'
$script:ConflictStateLabel.AutoSize = $true
$script:ConflictStateLabel.Margin = New-Object System.Windows.Forms.Padding(12, 4, 4, 4)
$recoveryStatusPanel.Controls.Add($script:ConflictStateLabel)

$script:RecoveryTextBox = New-Object System.Windows.Forms.RichTextBox
$script:RecoveryTextBox.Dock = 'Fill'
$script:RecoveryTextBox.ReadOnly = $true
$script:RecoveryTextBox.Font = $script:FontMono
$script:RecoveryTextBox.WordWrap = $true
$script:RecoveryTextBox.ScrollBars = 'Both'
$script:RecoveryTextBox.Text = 'Recovery guidance appears here after a failed merge, pull, stash apply/pop, or cherry-pick. You can also click Refresh recovery status.'
$recoveryLayout.Controls.Add($script:RecoveryTextBox, 0, 4)

Set-ControlPreview -Control $stateDoctorButton -Builder { $snapshot = Get-RepositoryStateDoctorSnapshot; if ($snapshot) { [string]$snapshot.Preview } else { 'git status -sb' } } -Title 'Repository State Doctor' -Notes 'Explains detached HEAD, branch divergence, in-progress operations, conflict markers, and the next safe action.'
Set-ControlPreview -Control $markerScanButton -Builder { "git status -sb`r`ngit diff --name-only --diff-filter=U" } -Title 'Find conflict markers' -Notes 'Scans changed and unmerged files for <<<<<<<, =======, and >>>>>>> marker lines.'
Set-ControlPreview -Control $validateGuiScriptButton -Builder { "powershell -NoProfile -ExecutionPolicy Bypass -Command `"`$ErrorActionPreference='Stop'; [scriptblock]::Create((Get-Content -Raw 'scripts/windows/GitGlideGUI-v3.7.0.ps1')) > `$null; 'PowerShell parse OK'`"" } -Title 'Validate GUI script' -Notes 'Parses the current GUI PowerShell script without running a second GUI instance.'
Set-ControlPreview -Control $recoveryRefreshButton -Builder { Build-RecoveryStatusPreview } -Title 'Refresh recovery status' -Notes 'Runs a safe read-only status command and updates the Recovery panel.'
Set-ControlPreview -Control $conflictRefreshButton -Builder { if (Get-Command Get-GgrUnmergedFilesCommandPlan -ErrorAction SilentlyContinue) { (Get-GgrUnmergedFilesCommandPlan).Display } else { 'git diff --name-only --diff-filter=U' } } -Title 'List conflicted files' -Notes 'Runs a read-only command that lists files with unresolved merge conflicts.'
Set-ControlPreview -Control $stageResolvedConflictButton -Builder { $path = if ($script:ConflictFilesListBox -and $script:ConflictFilesListBox.SelectedItem) { [string]$script:ConflictFilesListBox.SelectedItem } else { '<resolved-file>' }; if (Get-Command Get-GgrStageResolvedFileCommandPlan -ErrorAction SilentlyContinue) { (Get-GgrStageResolvedFileCommandPlan -Path $path).Display } else { 'git add -- ' + (Quote-Arg $path) } } -Title 'Stage resolved conflict file' -Notes 'Use after editing a conflicted file and removing conflict markers.'
Set-ControlPreview -Control $script:ContinueOperationButton -Builder { $state = Get-RecoveryStateSnapshot; if ($state -and $state.CherryPickInProgress) { 'git cherry-pick --continue' } elseif ($state -and $state.RebaseInProgress) { 'git rebase --continue' } elseif ($state -and $state.MergeInProgress) { 'git commit --no-edit' } else { 'git status --short' } } -Title 'Continue interrupted operation' -Notes 'Chooses merge, cherry-pick, or rebase continuation based on repository state markers.'
Set-ControlPreview -Control $launchMergeToolButton -Builder { Build-ExternalMergeToolPreview } -Title 'Launch external merge tool' -Notes 'Default is git mergetool. Configure Git merge.tool globally or edit the command here.'
if ($script:ToolTip) {
    $script:ToolTip.SetToolTip($stateDoctorButton, 'Inspect repository safety state and get the next safe action.')
    $script:ToolTip.SetToolTip($markerScanButton, 'Find leftover conflict markers in changed/unmerged files before staging.')
    $script:ToolTip.SetToolTip($validateGuiScriptButton, 'Parse-check the currently running PowerShell GUI script.')
    $script:ToolTip.SetToolTip($script:ConflictFilesListBox, 'Double-click a conflicted file to open it. Resolve markers, save, then stage the file.')
}
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
[void](New-ActionGuidance -ParentPanel $stageActionsPanel -Text 'Stage means choose what goes into the next commit. Clean tracked files are not listed as changed; use Browse tracked files when replacing, removing, or stop-tracking an unchanged file.')
[void](New-ActionButton -ParentPanel $stageActionsPanel -Text 'Stage selected' -Width 125 -Handler { Stage-SelectedFile } -PreviewBuilder { Build-StageSelectedPreview } -PreviewTitle 'Stage selected file(s)' -Notes 'Adds the selected file(s) to the Git index so they will be included in the next commit.')
[void](New-ActionButton -ParentPanel $stageActionsPanel -Text 'Unstage selected' -Width 135 -Handler { Unstage-SelectedFile } -PreviewBuilder { Build-UnstageSelectedPreview } -PreviewTitle 'Unstage selected file(s)' -Notes 'Removes the selected file(s) from the Git index while keeping your working-tree edits.')
[void](New-ActionButton -ParentPanel $stageActionsPanel -Text 'Stage all' -Width 110 -Handler { Stage-AllChanges } -PreviewBuilder { if (Get-Command Get-GggStageAllCommandPlan -ErrorAction SilentlyContinue) { ConvertTo-GggCommandPreview -Plans (Get-GggStageAllCommandPlan) } else { 'git add -A' } } -PreviewTitle 'Stage all changes' -Notes 'Stages everything in the repository.')
[void](New-ActionButton -ParentPanel $stageActionsPanel -Text 'Stop tracking' -Width 125 -Handler { Stop-TrackingSelectedFilesKeepLocal } -PreviewBuilder { Build-StopTrackingSelectedPreview } -PreviewTitle 'Stop tracking selected file(s)' -Notes 'Runs git rm --cached so the file stays on disk but is removed from Git tracking. Useful for accidental config/log/build output commits.')
[void](New-ActionButton -ParentPanel $stageActionsPanel -Text 'Remove file' -Width 115 -Handler { Remove-SelectedFilesFromGitAndDisk } -PreviewBuilder { Build-RemoveSelectedFromGitPreview } -PreviewTitle 'Remove selected file(s) from Git and disk' -Notes 'Runs git rm. This deletes the selected file from disk and stages the deletion, after confirmation.')
[void](New-ActionButton -ParentPanel $stageActionsPanel -Text 'Browse tracked files' -Width 155 -Handler { Show-TrackedFilesDialog } -PreviewBuilder { 'git ls-files --cached --full-name' } -PreviewTitle 'Browse clean tracked files' -Notes 'Lists tracked files even when they are clean, so you can remove or stop tracking a file before replacing it.')

# Branch actions
[void](New-ActionGuidance -ParentPanel $branchActionsPanel -Text 'Branches isolate work. Create feature branches for focused changes, switch only when your working tree is clean or safely stashed, and push when ready to share.')
[void](New-ActionButton -ParentPanel $branchActionsPanel -Text 'Push current branch' -Width 145 -Handler { Push-CurrentBranch } -PreviewBuilder { Build-PushPreview } -PreviewTitle 'Push current branch' -Notes 'Pushes the current branch to origin and sets upstream if needed.')
[void](New-ActionButton -ParentPanel $branchActionsPanel -Text 'Pull current branch' -Width 145 -Handler { Pull-CurrentBranch -ConfirmBeforePull } -PreviewBuilder { Build-PullPreview } -PreviewTitle 'Pull current branch safely' -Notes 'Runs git pull --ff-only after a clean-working-tree check. This avoids surprise merge commits and gives clearer guidance when local changes are present.')

# Integrate actions
[void](New-ActionGuidance -ParentPanel $integrateActionsPanel -Text 'Merge & Publish guides the full Git Flow path with checklist support: inspect branch tracking, push branches with upstream, sync main into develop, merge selected features into develop, run quality checks, promote develop back to main, then clean up merged feature branches.')
$featureMergeLabel = New-Object System.Windows.Forms.Label
$featureMergeLabel.Text = 'Feature branch to merge:'
$featureMergeLabel.Width = 150
$featureMergeLabel.Height = 26
$featureMergeLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$featureMergeLabel.Margin = New-Object System.Windows.Forms.Padding(4, 8, 4, 4)
$integrateActionsPanel.Controls.Add($featureMergeLabel)
$script:IntegrationFeatureBranchComboBox = New-Object System.Windows.Forms.ComboBox
$script:IntegrationFeatureBranchComboBox.Width = 260
$script:IntegrationFeatureBranchComboBox.DropDownStyle = 'DropDown'
$script:IntegrationFeatureBranchComboBox.Margin = New-Object System.Windows.Forms.Padding(4, 4, 12, 4)
$script:IntegrationFeatureBranchComboBox.Add_TextChanged({ Set-CommandPreview -Title "Merge selected feature into $($script:Config.BaseBranch)" -Commands (Build-MergeSelectedFeatureIntoDevelopPreview) -Notes 'Choose or type the feature branch to merge while staying on develop.' })
$integrateActionsPanel.Controls.Add($script:IntegrationFeatureBranchComboBox)
[void](New-ActionButton -ParentPanel $integrateActionsPanel -Text 'Refresh branches' -Width 135 -Handler { Load-LocalBranches; Show-BranchTrackingOverview } -PreviewBuilder { Build-BranchTrackingPreview } -PreviewTitle 'Refresh branch list and tracking' -Notes 'Updates branch selectors and shows git branch -vv so upstream state is visible.')
[void](New-ActionButton -ParentPanel $integrateActionsPanel -Text 'Show tracking' -Width 125 -Handler { Show-BranchTrackingOverview } -PreviewBuilder { Build-BranchTrackingPreview } -PreviewTitle 'Show branch tracking' -Notes 'Runs git branch -vv to show local branches, upstream branches, and ahead/behind state.')
[void](New-ActionButton -ParentPanel $integrateActionsPanel -Text 'Push upstream' -Width 125 -Handler { Push-CurrentBranch -ConfirmBeforePush } -PreviewBuilder { Build-PushPreview } -PreviewTitle 'Push current branch with upstream' -Notes 'Runs git push -u origin HEAD. Use after creating a new feature/develop/main branch locally.')
[void](New-ActionButton -ParentPanel $integrateActionsPanel -Text "$($script:Config.MainBranch) -> $($script:Config.BaseBranch)" -Width 165 -Handler { Sync-MainIntoDevelop } -PreviewBuilder { Build-SyncMainIntoDevelopPreview } -PreviewTitle "Sync $($script:Config.MainBranch) into $($script:Config.BaseBranch)" -Notes 'Useful when main received hotfixes or release corrections that develop should contain before feature integration.')
[void](New-ActionButton -ParentPanel $integrateActionsPanel -Text "Selected feature -> $($script:Config.BaseBranch)" -Width 205 -Handler { Merge-SelectedFeatureIntoDevelop } -PreviewBuilder { Build-MergeSelectedFeatureIntoDevelopPreview } -PreviewTitle "Merge selected feature into $($script:Config.BaseBranch)" -Notes 'Merges the selected feature branch into develop with --no-ff, even when you are currently on develop.')
[void](New-ActionButton -ParentPanel $integrateActionsPanel -Text "Current feature -> $($script:Config.BaseBranch)" -Width 200 -Handler { Merge-CurrentFeatureIntoDevelop } -PreviewBuilder { Build-MergeFeaturePreview } -PreviewTitle "Merge current feature into $($script:Config.BaseBranch)" -Notes 'Legacy/current-branch merge path. Requires that the current branch is the feature branch.')
[void](New-ActionButton -ParentPanel $integrateActionsPanel -Text 'Run quality checks' -Width 150 -Handler { Run-QualityChecksForMergeGate } -PreviewBuilder { Build-RunQualityChecksPreview } -PreviewTitle 'Run quality checks before promoting to main' -Notes 'Runs the project quality gate before you merge develop into main.')
[void](New-ActionButton -ParentPanel $integrateActionsPanel -Text "$($script:Config.BaseBranch) -> $($script:Config.MainBranch)" -Width 165 -Handler { Merge-DevelopIntoMain } -PreviewBuilder { Build-MergeDevelopPreview } -PreviewTitle "Merge $($script:Config.BaseBranch) into $($script:Config.MainBranch)" -Notes 'Requires a clean working tree. Recommended after quality checks pass.')
[void](New-ActionButton -ParentPanel $integrateActionsPanel -Text 'Workflow guide' -Width 130 -Handler { Show-MergeWorkflowGuide } -PreviewBuilder { Build-MergeWorkflowGuidePreview } -PreviewTitle 'Git Flow merge/publish workflow' -Notes 'Shows the full intended sequence: feature push, develop integration, quality gate, main promotion, push/tag.')
[void](New-ActionButton -ParentPanel $integrateActionsPanel -Text 'Workflow checklist' -Width 155 -Handler { Show-MergeWorkflowChecklist } -PreviewBuilder { Build-MergeWorkflowChecklistPreview } -PreviewTitle 'Git Flow merge/publish checklist' -Notes 'Shows an advisory checklist for feature branch push, develop integration, quality checks, main promotion, and release readiness.')
[void](New-ActionButton -ParentPanel $integrateActionsPanel -Text 'Clean merged branch' -Width 160 -Handler { Cleanup-SelectedFeatureBranch } -PreviewBuilder { Build-CleanupSelectedFeatureBranchPreview } -PreviewTitle 'Clean up merged feature branch' -Notes 'Deletes a merged feature/fix branch locally and remotely after confirmation. Do this only after merge and push are complete.')
[void](New-ActionButton -ParentPanel $integrateActionsPanel -Text 'Open PR URL' -Width 120 -Handler { Open-LastPullRequestUrl } -PreviewBuilder { if ($script:Config.ContainsKey('LastPullRequestUrl') -and -not [string]::IsNullOrWhiteSpace([string]$script:Config.LastPullRequestUrl)) { [string]$script:Config.LastPullRequestUrl } else { 'push a feature branch to GitHub to detect a pull request URL' } } -PreviewTitle 'Open last detected pull request URL' -Notes 'When GitHub prints a pull/new URL after push, Git Glide stores it for quick opening.')

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
$leftGroup.Text = 'Work area / Changed files'
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

function Resize-ChangedFilesContextBanner {
    if (-not $script:ChangedFilesContextLabel) { return }

    try {
        $label = $script:ChangedFilesContextLabel
        $parentWidth = if ($label.Parent) { [int]$label.Parent.ClientSize.Width } else { [int]$label.ClientSize.Width }
        $availableWidth = [Math]::Max(120, $parentWidth - $label.Margin.Left - $label.Margin.Right - $label.Padding.Left - $label.Padding.Right - 8)

        $proposedSize = New-Object System.Drawing.Size($availableWidth, 1000)
        $flags =
            [System.Windows.Forms.TextFormatFlags]::WordBreak -bor
            [System.Windows.Forms.TextFormatFlags]::TextBoxControl

        $measured = [System.Windows.Forms.TextRenderer]::MeasureText(
            $label.Text,
            $label.Font,
            $proposedSize,
            $flags
        )

        $newHeight = $measured.Height + $label.Padding.Top + $label.Padding.Bottom + 8
        $newHeight = [Math]::Max(30, [Math]::Min($newHeight, 120))
        $label.Height = $newHeight

        if ($script:ChangedFilesListLayout -and $script:ChangedFilesListLayout.RowStyles.Count -gt 0) {
            $script:ChangedFilesListLayout.RowStyles[0].SizeType = [System.Windows.Forms.SizeType]::Absolute
            $script:ChangedFilesListLayout.RowStyles[0].Height = $newHeight
        }
    } catch {}
}

$changedFilesListLayout = New-Object System.Windows.Forms.TableLayoutPanel
$script:ChangedFilesListLayout = $changedFilesListLayout
$changedFilesListLayout.Dock = 'Fill'
$changedFilesListLayout.ColumnCount = 1
$changedFilesListLayout.RowCount = 2
$changedFilesListLayout.ColumnStyles.Clear()
[void]$changedFilesListLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
[void]$changedFilesListLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 34)))
[void]$changedFilesListLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$leftActionSplit.Panel1.Controls.Add($changedFilesListLayout)

$script:ChangedFilesContextLabel = New-Object System.Windows.Forms.Label
$script:ChangedFilesContextLabel.AutoSize = $false
$script:ChangedFilesContextLabel.AutoEllipsis = $false
$script:ChangedFilesContextLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
$script:ChangedFilesContextLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$script:ChangedFilesContextLabel.MaximumSize = New-Object System.Drawing.Size(0, 0)
$script:ChangedFilesContextLabel.MinimumSize = New-Object System.Drawing.Size(0, 30)
$script:ChangedFilesContextLabel.Padding = New-Object System.Windows.Forms.Padding(6, 4, 6, 4)
$script:ChangedFilesContextLabel.Text = 'Branch context will appear here after Refresh.'
$script:ChangedFilesContextLabel.Add_TextChanged({ Resize-ChangedFilesContextBanner })
$script:ChangedFilesContextLabel.Add_FontChanged({ Resize-ChangedFilesContextBanner })
$changedFilesListLayout.Add_SizeChanged({ Resize-ChangedFilesContextBanner })
$changedFilesListLayout.Controls.Add($script:ChangedFilesContextLabel, 0, 0)
Resize-ChangedFilesContextBanner

$script:ChangedFilesList = New-Object System.Windows.Forms.ListBox
$script:ChangedFilesList.Dock = [System.Windows.Forms.DockStyle]::Fill
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
        Set-CommandPreview -Title 'Selected file diff preview' -Commands (Build-ShowDiffPreview) -Notes 'Use Stage selected, Unstage selected, Stop tracking, or Remove file to move this file between index, working tree, and Git tracking.'
    }
})
$changedFilesListLayout.Controls.Add($script:ChangedFilesList, 0, 1)

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

$stopTrackingButton = New-Object System.Windows.Forms.Button
$stopTrackingButton.Text = 'Stop tracking'
$stopTrackingButton.Width = 115
$stopTrackingButton.Height = 32
$stopTrackingButton.Margin = New-Object System.Windows.Forms.Padding(4)
$stopTrackingButton.Add_Click({ Stop-TrackingSelectedFilesKeepLocal })
$leftButtons.Controls.Add($stopTrackingButton)

$removeFileButton = New-Object System.Windows.Forms.Button
$removeFileButton.Text = 'Remove file'
$removeFileButton.Width = 105
$removeFileButton.Height = 32
$removeFileButton.Margin = New-Object System.Windows.Forms.Padding(4)
$removeFileButton.Add_Click({ Remove-SelectedFilesFromGitAndDisk })
$leftButtons.Controls.Add($removeFileButton)

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
$script:ToolTip.SetToolTip($script:BranchSwitchComboBox, 'Choose an existing local branch or type one. If work is dirty, Git Glide warns but can let Git attempt the switch anyway.')
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
Set-ControlPreview -Control $switchBranchButton -Builder { Build-SwitchBranchPreview } -Title 'Switch branch' -Notes 'Switches to the selected or typed branch. Dirty work shows a warning, but you can choose to let Git attempt the switch anyway.'
Set-ControlPreview -Control $showDiffButton -Builder { Build-ShowDiffPreview } -Title 'Show diff for selected file' -Notes 'Reloads the preview for the first selected changed file. Handles staged, unstaged, renamed, deleted, conflicted, and untracked files.'
Set-ControlPreview -Control $stageSelectedButton -Builder { Build-StageSelectedPreview } -Title 'Stage selected file' -Notes 'Adds the selected file(s) to the Git index so they will be included in the next commit.'
Set-ControlPreview -Control $unstageSelectedButton -Builder { Build-UnstageSelectedPreview } -Title 'Unstage selected file' -Notes 'Removes the selected file(s) from the Git index while keeping your working-tree edits.'
Set-ControlPreview -Control $stopTrackingButton -Builder { Build-StopTrackingSelectedPreview } -Title 'Stop tracking selected file(s)' -Notes 'Removes the selected file(s) from Git tracking but keeps local files on disk.'
Set-ControlPreview -Control $removeFileButton -Builder { Build-RemoveSelectedFromGitPreview } -Title 'Remove selected file(s)' -Notes 'Deletes the selected tracked file(s) from disk and stages the deletion after confirmation.'
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
